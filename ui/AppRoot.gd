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

# Summon related variables
var _summon_screen: SummonScreen
var _summon_scene := preload("res://ui/screens/SummonScreen.tscn")

# Sanctum shell (Phase B - Spatial visualization)
var _sanctum_shell: SanctumShell
var _sanctum_shell_scene := preload("res://ui/shells/SanctumShell.tscn")

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
	# seed shortcuts (SANCTUM-002 / debug only)
	# -------------------------
	if head == "seed":
		_run_seed_command(parts)
		return

	# -------------------------
	# economy shortcuts
	# -------------------------
	if head == "ase" or head == "ekwan":
		_run_currency_command(head, parts)
		return

	# -------------------------
	# echo shortcuts (SANCTUM-002 / debug only)
	# -------------------------
	if head == "echo":
		_run_echo_command(parts)
		return
		
	# -------------------------
	# summon shortcut (SANCTUM-002 / debug only)
	# -------------------------
	if head == "summon":
		_run_summon_command(parts)
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
	SanctumSummonTests.register(runner)
	PartyTests.register(runner)

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

func _run_echo_command(parts: Array) -> void:
	# Usage:
	#   echo gentest
	if parts.size() < 2:
		_debug_print("Usage: echo gentest")
		return

	var op := str(parts[1]).to_lower()
	if op != "gentest":
		_debug_print("Unknown echo op: %s (use gentest)" % op)
		return

	# Capture log window so we can print the structured payload to the debug panel.
	var start_idx := _last_log_index

	var snap := runtime.dispatch({ "type": "debug.echo.gen_test" })
	_render_snapshot(snap)

	# Print payload from the debug.echo.gen_test log (if present)
	var logs := logger.get_logs()
	for i in range(start_idx, logs.size()):
		var e: Dictionary = logs[i]
		if str(e.get("type", "")) == "debug.echo.gen_test":
			# now extract payload, but we’ll discover its key next
			var p_v: Variant = e.get("data", {})
			var p: Dictionary = p_v if p_v is Dictionary else {}

			_debug_print("EchoFactory gen test:")
			_debug_print("seed_root = %s" % str(p.get("seed_root", "")))
			_debug_print("path_a = %s" % str(p.get("path_a", "")))
			_debug_print("path_b = %s" % str(p.get("path_b", "")))
			_debug_print("fp1 = %s" % str(p.get("fingerprint_1", "")))
			_debug_print("fp2 = %s" % str(p.get("fingerprint_2", "")))
			_debug_print("fp3 = %s" % str(p.get("fingerprint_3", "")))
			_debug_print("same_path_equal = %s" % str(p.get("same_path_equal", false)))
			_debug_print("diff_path_differs = %s" % str(p.get("diff_path_differs", false)))
			break

	_flush_logs_to_console()

func _run_seed_command(parts: Array) -> void:
	# Usage:
	#   seed show
	#   seed set <seed_string>
	#   seed reset <seed_string>
	if parts.size() < 2:
		_debug_print("Usage: seed show | seed set <seed> | seed reset <seed>")
		return

	var op := str(parts[1]).to_lower()

	if op == "show":
		var snap := runtime.dispatch({ "type": "debug.seed.show" })
		_render_snapshot(snap)

		# Print the seed values explicitly (do not rely on LogFormatter payload rendering)
		var save_ref: Dictionary = runtime.get_save_data()
		var camp_v : Variant = save_ref.get("campaign", {})
		var camp: Dictionary = camp_v if camp_v is Dictionary else {}
		var seed_root := str(camp.get("seed_root", ""))
		var seed_source := str(camp.get("seed_source", ""))
		var root_seed := int(camp.get("root_seed", 0))

		_debug_print("seed_root = %s" % seed_root)
		_debug_print("seed_source = %s" % seed_source)
		_debug_print("root_seed = %d" % root_seed)

		_flush_logs_to_console()
		return

	if op != "set" and op != "reset":
		_debug_print("Unknown seed op: %s (use show/set/reset)" % op)
		return

	if parts.size() < 3:
		_debug_print("Missing seed string. Example: seed %s my-seed-123" % op)
		return

	var seed_str := str(parts[2]).strip_edges()
	if seed_str.is_empty():
		_debug_print("Seed cannot be empty.")
		return

	var action_type := "debug.seed.set" if op == "set" else "debug.seed.reset"
	var snap := runtime.dispatch({
		"type": action_type,
		"seed_root": seed_str
	})

	_render_snapshot(snap)

	# Print updated seed values explicitly
	var save_ref: Dictionary = runtime.get_save_data()
	var camp_v : Variant = save_ref.get("campaign", {})
	var camp: Dictionary = camp_v if camp_v is Dictionary else {}
	var seed_root2 := str(camp.get("seed_root", ""))
	var seed_source2 := str(camp.get("seed_source", ""))
	var root_seed2 := int(camp.get("root_seed", 0))

	_debug_print("seed_root = %s" % seed_root2)
	_debug_print("seed_source = %s" % seed_source2)
	_debug_print("root_seed = %d" % root_seed2)

	_flush_logs_to_console()

func _run_summon_command(parts: Array) -> void:
	# Usage: summon [count]
	var count := 1
	if parts.size() >= 2:
		count = max(1, int(parts[1]))
	count = min(count, 10)

	var now_unix := int(Time.get_unix_time_from_system())
	var snap := runtime.dispatch({
		"type": "sanctum.summon",
		"count": count,
		"now_unix": now_unix
	})
	_render_snapshot(snap)

	# print result
	var save_ref: Dictionary = runtime.get_save_data()
	var sanctum: Dictionary = (save_ref.get("sanctum", {}) as Dictionary)
	var roster: Array = sanctum.get("roster", [])
	var summon_count := int(sanctum.get("summon_count", 0))
	var econ_after := EconomyService.new(save_ref)

	_debug_print("Summon x%d → roster=%d summon_count=%d ase=%d" % [
		count, roster.size(), summon_count, econ_after.get_ase()
	])

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
# We will move to a ScreenRouter pattern. This is a halfway house to keep things manageable.
func _render_snapshot(snap: Dictionary) -> void:
	var snap_type := str(snap.get("type", ""))
	var is_sanctum_family := (
		snap_type == "flow.sanctum"
		or snap_type == "flow.summon"
		or snap_type == "flow.party_manage"
		#or snap_type == "flow.echo_manage"
		#or snap_type == "flow.realm_select"
	)

	if is_sanctum_family:
		if _sanctum_shell == null:
			_sanctum_shell = _sanctum_shell_scene.instantiate() as SanctumShell
			screen_host.add_child(_sanctum_shell)
			_sanctum_shell.action_requested.connect(_on_ui_action_selected)

		_show_screen(_sanctum_shell)
		_sanctum_shell.set_snapshot(snap)
		return

		_show_screen(_summon_screen)
		_summon_screen.set_snapshot(snap)
		return

	_hide_bespoke_screens()
	renderer.render(snap)

func _show_screen(screen: Control) -> void:
	screen_host.visible = true
	snapshot_view.visible = false
	actions_container.visible = false

	# Hide all bespoke screens, then show the active one.
	if _sanctum_screen != null:
		_sanctum_screen.visible = false
	if _summon_screen != null:
		_summon_screen.visible = false

	if _sanctum_shell != null:
		_sanctum_shell.visible = false

	screen.visible = true

func _hide_bespoke_screens() -> void:
	screen_host.visible = false
	snapshot_view.visible = true
	actions_container.visible = true
	if _sanctum_screen != null:
		_sanctum_screen.visible = false
	if _summon_screen != null:
		_summon_screen.visible = false
		
	if _sanctum_shell != null:
		_sanctum_shell.visible = false
