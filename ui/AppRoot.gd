extends Control

@onready var snapshot_view: RichTextLabel = %SnapshotView
@onready var renderer: UISnapshotRenderer = %UISnapshotRenderer
@onready var debug_overlay: Control = %DebugOverlay
@onready var debug_panel: DebugPanel = %DebugPanel
@onready var actions_container: Control = %ActionsContainer
@onready var econ_bank_timer: Timer = $EconBankTimer
@onready var screen_host: Control = %ScreenHost

var runtime: FlowRuntime

var _last_log_index: int = 0

var _econ_timer_started: bool = false

# current_snapshot to be deleted after STATE-002 has been implemented properly.
var current_snapshot: Dictionary = {}
var current_save: Dictionary = {}

var logger: StructuredLogger
var config_service: ConfigService

# Flow-owned runtime
var flow_ctx: FlowContext
var flow_machine: FlowStateMachine

# Sanctum related variables
var _sanctum_screen: SanctumScreen
var _sanctum_scene := preload("res://ui/screens/SanctumScreen.tscn")

func _ready():
	# Bind renderer to UI elements it can update.
	renderer.bind_view(snapshot_view, actions_container)
	renderer.action_selected.connect(_on_ui_action_selected)
	
	logger = StructuredLogger.new()
	# TEMP: debug by default until DebugPanel controls log level
	logger.set_level("debug")
	
	config_service = ConfigService.new()
	runtime = FlowRuntime.new(logger, config_service)
	var snap := runtime.boot()
	_render_snapshot(snap)
	
	var interval := _get_sanctum_bank_interval_seconds()
	econ_bank_timer.wait_time = float(interval)
	econ_bank_timer.timeout.connect(_on_econ_bank_timer_timeout)
	_maybe_start_econ_timer_from_snapshot(snap)
	_maybe_stop_econ_timer_from_snapshot(snap)
	
	# Connect debug panel to AppRoot
	debug_panel.command_submitted.connect(_on_debug_command)
	
	_flush_logs_to_console()

# Economy bank timer.
func _on_econ_bank_timer_timeout() -> void:
	# Capture authoritative balance BEFORE settle
	var save_ref: Dictionary = runtime.get_save_data()
	var econ_before := EconomyService.new(save_ref)
	var before := econ_before.get_ase()

	# Perform settlement
	var snap := _dispatch_settle_now("bank.interval")
	_render_snapshot(snap)

	# Read authoritative balance AFTER settle
	var econ_after := EconomyService.new(runtime.get_save_data())
	var after := econ_after.get_ase()

	var delta := after - before

	_debug_print("[bank.interval] +%d Ase → total = %d" % [delta, after])

	_flush_logs_to_console()
	
func _get_sanctum_bank_interval_seconds() -> int:
	var balance: Dictionary = config_service.get_balance()
	var data_v = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var econ_v = data.get("economy", {})
	var econ_cfg: Dictionary = econ_v as Dictionary if econ_v is Dictionary else {}
	return int(econ_cfg.get("sanctum_bank_interval_seconds", 300))

func _flush_logs_to_console() -> void:
	var logs := logger.get_logs()
	for i in range(_last_log_index, logs.size()):
		print(LogFormatter.format(logs[i]))
	_last_log_index = logs.size()
	
func _on_ui_action_selected(action: Dictionary) -> void:
	var snap := runtime.dispatch(action)
	_render_snapshot(snap)
	
	_maybe_start_econ_timer_from_snapshot(snap)
	_maybe_stop_econ_timer_from_snapshot(snap)
	_flush_logs_to_console()
	
func _maybe_start_econ_timer_from_snapshot(snap: Dictionary) -> void:
	if _econ_timer_started:
		return

	var snap_type := str(snap.get("type", ""))

	# Only start once we’re past splash/menu.
	if snap_type == "flow.splash" or snap_type == "flow.main_menu" or snap_type == "":
		return

	_econ_timer_started = true
	econ_bank_timer.start()

	logger.debug(-1, "economy.bank_timer.started", "Bank timer started", {
		"snapshot_type": snap_type,
		"interval_seconds": econ_bank_timer.wait_time
	})
	
func _maybe_stop_econ_timer_from_snapshot(snap: Dictionary) -> void:
	if not _econ_timer_started:
		return

	var snap_type := str(snap.get("type", ""))
	if snap_type == "flow.main_menu" or snap_type == "flow.splash":
		_econ_timer_started = false
		econ_bank_timer.stop()
		logger.debug(-1, "economy.bank_timer.stopped", "Bank timer stopped", { "snapshot_type": snap_type })
	
func _on_debug_command(command: String) -> void:
	var cmd := command.strip_edges()
	_log_debug_cmd_in(cmd)
	if cmd.is_empty():
		return

	var parts := cmd.split(" ", false)
	if parts.is_empty():
		return

	var head := parts[0].to_lower()

	# -------------------------
	# tests
	# -------------------------
	if head == "tests" or head == "test":
		_run_tests(parts)
		return

	# -------------------------
	# economy shortcuts
	# -------------------------
	if head == "ase" or head == "ekwan":
		_run_currency_command(head, parts)
		return

	_debug_print("Unknown command: " + cmd)
	_debug_print("Try: tests | ase show | ase add 10 [reason] | ase spend 5 [reason] | ekwan show | ekwan add 1 | ekwan spend 1")
	
	_flush_logs_to_console()
	
func _toggle_debug_overlay() -> void:
	debug_overlay.visible = not debug_overlay.visible

func _debug_print(line: String) -> void:
	debug_panel.output.append_text(line + "\n")
	_log_debug_cmd_out(line)

func _log_debug_cmd_in(cmd: String) -> void:
	logger.info(-1, "debug.cmd.in", "Debug command", { "cmd": cmd })

func _log_debug_cmd_out(line: String) -> void:
	logger.info(-1, "debug.cmd.out", "Debug output", { "line": line })
	
func _log_debug_cmd_err(line: String) -> void:
	logger.info(-1, "debug.cmd.err", "Debug error", { "line": line })

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# F1 is consistent. You can add backtick later if you want.
		if event.keycode == KEY_F1:
			_toggle_debug_overlay()
			get_viewport().set_input_as_handled()

func _dispatch_settle_now(source: String) -> Dictionary:
	var now_unix := int(Time.get_unix_time_from_system())
	var settle_action: Dictionary = {
		"type": "economy.settle_time",
		"now_unix": now_unix,
		"source": source
	}
	# We don't need the returned snapshot right now for debug,
	# but dispatch ensures Core settles and logs deterministically.
	return runtime.dispatch(settle_action)

func _run_tests(parts: Array) -> void:
	# Optional: allow "tests economy" later; for now run all.
	var runner := CoreTestRunner.new()
	EconomyTests.register(runner)

	var result: Dictionary = runner.run_all()
	_debug_print("Tests: %d total, %d passed, %d failed" % [
		int(result.get("total", 0)),
		int(result.get("passed", 0)),
		int(result.get("failed", 0))
	])

	var results: Array = result.get("results", [])
	for r in results:
		var ok := bool(r.get("ok", false))
		var name := str(r.get("name", "unnamed"))
		if ok:
			_debug_print("✅ " + name)
		else:
			_debug_print("❌ " + name + " — " + str(r.get("error", "unknown error")))
			
	_flush_logs_to_console()

func _run_currency_command(currency: String, parts: Array) -> void:
	# Usage:
	#   ase show
	#   ase add <amount> [reason...]
	#   ase spend <amount> [reason...]
	# Same for ekwan.
	if parts.size() < 2:
		_debug_print("Usage: %s show | %s add <amount> [reason] | %s spend <amount> [reason]" % [currency, currency, currency])
		return

	var op := str(parts[1]).to_lower()

	# We need the authoritative save dictionary to mutate.
	# Add this method in FlowRuntime if it doesn't exist yet: runtime.get_save_data()
	var save_ref: Dictionary = runtime.get_save_data()
	var econ := EconomyService.new(save_ref)

	# Use runtime tick if available; otherwise fall back to 0 (still deterministic but less informative).
	var t := 0
	if runtime.has_method("get_tick"):
		t = int(runtime.get_tick())

	if op == "show":
		if currency == "ase":
			_dispatch_settle_now("debug.before_show")
			_debug_print("Ase = %d" % econ.get_ase())
		else:
			_debug_print("Ekwan = %d" % econ.get_ekwan())
		return

	if op != "add" and op != "spend":
		_debug_print("Unknown %s op: %s (use show/add/spend)" % [currency, op])
		return

	if parts.size() < 3:
		_debug_print("Missing amount. Example: %s %s 10" % [currency, op])
		return

	var amount := int(parts[2])

	# Reason: everything after amount joined with spaces; optional.
	var reason := ""
	if parts.size() > 3:
		reason = " ".join(parts.slice(3))
	else:
		reason = "debug.%s.%s" % [currency, op]

	if currency == "ase":
		if op == "add":
			var snap := runtime.dispatch({
				"type": "economy.ase.add",
				"amount": amount,
				"reason": reason
			})
			_render_snapshot(snap)
			var econ_after := EconomyService.new(runtime.get_save_data())
			_debug_print("Ase now = %d" % econ_after.get_ase())
		else:
			var now_unix := int(Time.get_unix_time_from_system())
			var snap := runtime.dispatch({
				"type": "economy.ase.spend",
				"amount": amount,
				"reason": reason,
				"now_unix": now_unix
			})
			_render_snapshot(snap)
			
			var econ_after := EconomyService.new(runtime.get_save_data())
			_debug_print("Ase now = %d" % econ_after.get_ase())
			
	else:
		if op == "add":
			econ.add_ekwan(amount, reason, logger, t)
			_debug_print("Ekwan now = %d" % econ.get_ekwan())
		else:
			var ok2 := econ.spend_ekwan(amount, reason, logger, t)
			_debug_print("Spend ok = %s | Ekwan now = %d" % [str(ok2), econ.get_ekwan()])

	# Optional: if you have a safe “refresh snapshot without transition” method later, call it here.
	_flush_logs_to_console()

# Snapshot renderer that keeps external screens in mind and snapshots within Approot.
# Goal is to eventually go to a screen only model and make Approot thinner.
func _render_snapshot(snap: Dictionary) -> void:
	var snap_type := str(snap.get("type", ""))
	
	if snap_type == "flow.sanctum":
		# Ensure Sanctum screen exists once
		if _sanctum_screen == null:
			_sanctum_screen = _sanctum_scene.instantiate() as SanctumScreen
			screen_host.add_child(_sanctum_screen)
			_sanctum_screen.set_dispatch(Callable(self, "_on_ui_action_selected"))
			
		# Show bespoke screen; hide gener snapshot UI
		screen_host.visible = true
		snapshot_view.visible = false
		actions_container.visible = false
		
		_sanctum_screen.set_snapshot(snap)
		return
	
	# Fallback: existing renderer path for all other states
	screen_host.visible = false
	snapshot_view.visible = true
	actions_container.visible = true
	renderer.render(snap)
