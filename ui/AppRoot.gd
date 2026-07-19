extends Control

const SaveIntegrityTestsScript := preload("res://tests/SaveIntegrityTests.gd")
const LeadershipEmotionTestsScript := preload("res://tests/LeadershipEmotionTests.gd")
const SanctumPulseTestsScript := preload("res://tests/SanctumPulseTests.gd")
const FoundationUITestsScript := preload("res://tests/FoundationUITests.gd")
const MovementContractTestsScript := preload("res://tests/MovementContractTests.gd")
const MovementPathTestsScript := preload("res://tests/MovementPathTests.gd")
const MovementSlice2ContractTestsScript := preload("res://tests/MovementSlice2ContractTests.gd")
const CombatPressureTestsScript := preload("res://tests/CombatPressureTests.gd")
const MovementOptionTestsScript := preload("res://tests/MovementOptionTests.gd")
const MovementArbitrationTestsScript := preload("res://tests/MovementArbitrationTests.gd")
const MovementProfileTestsScript := preload("res://tests/MovementProfileTests.gd")
const MovementHazardTestsScript := preload("res://tests/MovementHazardTests.gd")
const MovementExecutorTestsScript := preload("res://tests/MovementExecutorTests.gd")
const CombatActivationTestsScript := preload("res://tests/CombatActivationTests.gd")

@onready var snapshot_view: RichTextLabel = %SnapshotView
@onready var renderer: UISnapshotRenderer = %UISnapshotRenderer
@onready var debug_overlay: Control = %DebugOverlay
@onready var debug_panel: DebugPanel = %DebugPanel
@onready var actions_container: Control = %ActionsContainer
@onready var fallback_root: Control = %FallbackRoot
@onready var econ_bank_timer: Timer = $EconBankTimer
@onready var screen_host: Control = %ScreenHost
@onready var modal_host: Control = %ModalHost
@onready var responsive_layout: Node = %ResponsiveLayoutController
@onready var save_recovery_notice: Control = %SaveRecoveryNotice
@onready var save_recovery_message: Label = %SaveRecoveryMessage
@onready var save_recovery_timer: Timer = %SaveRecoveryTimer

var runtime: FlowRuntime

var _last_log_index: int = 0
var _current_layout: Dictionary = {}
var _modal_owner: Control = null

var _econ_timer_started: bool = false

var logger: StructuredLogger
var config_service: ConfigService

# Flow-owned runtime
var flow_ctx: FlowContext
var flow_machine: FlowStateMachine

# INFRA-001: Two-shell router. All bespoke screens live inside their respective shell.
# SanctumShell — flow.sanctum, flow.summon, flow.echo_party, flow.realm_select
# RealmShell   — flow.stage_map, flow.stage, flow.encounter, flow.resolve
var _sanctum_shell: SanctumShell
var _sanctum_shell_scene := preload("res://ui/shells/SanctumShell.tscn")

var _realm_shell: RealmShell
var _realm_shell_scene := preload("res://ui/shells/RealmShell.tscn")

var _active_onboarding_screen: Control
var _save_error_screen: Control
var _save_error_scene := preload("res://ui/screens/boot/SaveErrorScreen.tscn")
var _onboarding_scene_by_type: Dictionary = {
	"flow.onboarding_invocation": preload("res://ui/screens/onboarding/InvocationScreen.tscn"),
	"flow.onboarding_anansi": preload("res://ui/screens/onboarding/AnansiWebScreen.tscn"),
	"flow.onboarding_choose_name": preload("res://ui/screens/onboarding/ForgottenNameScreen.tscn"),
	"flow.onboarding_meeting": preload("res://ui/screens/onboarding/ForgottenNameScreen.tscn"),
	"flow.onboarding_empty_sanctum": preload("res://ui/screens/onboarding/FirstSanctumEncounterScreen.tscn"),
	"flow.onboarding_name_sanctum": preload("res://ui/screens/onboarding/SanctumNamingScreen.tscn"),
	"flow.keeper_call": preload("res://ui/screens/onboarding/KeeperIntroScreen.tscn"),
	"flow.keeper_rewind": preload("res://ui/screens/onboarding/KeeperIntroScreen.tscn"),
	"flow.keeper_thread_return": preload("res://ui/screens/onboarding/KeeperIntroScreen.tscn"),
	"flow.keeper_awakening": preload("res://ui/screens/onboarding/KeeperIntroScreen.tscn"),
	"flow.keeper_weaving": preload("res://ui/screens/onboarding/KeeperIntroScreen.tscn"),
	"flow.keeper_keeping": preload("res://ui/screens/onboarding/KeeperIntroScreen.tscn"),
}

func _ready():
	if responsive_layout.has_method("current_layout"):
		var layout_v: Variant = responsive_layout.call("current_layout")
		_current_layout = layout_v if layout_v is Dictionary else {}
	if responsive_layout.has_signal("layout_changed"):
		responsive_layout.connect("layout_changed", Callable(self, "_on_layout_changed"))
	if modal_host.has_signal("action_requested"):
		modal_host.connect("action_requested", Callable(self, "_on_ui_action_selected"))
	if modal_host.has_signal("modal_dismissed"):
		modal_host.connect("modal_dismissed", Callable(self, "_on_modal_dismissed"))

	var cmdline_args := OS.get_cmdline_user_args()
	var is_test_run := cmdline_args.size() > 0 and cmdline_args[0].to_lower() in ["tests", "test"]
	var runtime_save_path := "/tmp/echoes-vnext-tests/headless_runtime_slot.json" if is_test_run else SaveSchema.DEFAULT_SAVE_PATH

	# Bind renderer to UI elements it can update.
	renderer.bind_view(snapshot_view, actions_container)
	renderer.action_selected.connect(_on_ui_action_selected)
	
	logger = StructuredLogger.new()
	# TEMP: debug by default until DebugPanel controls log level
	logger.set_level("debug")
	
	config_service = ConfigService.new()
	runtime = FlowRuntime.new(logger, config_service, runtime_save_path)
	var snap := runtime.boot()
	_render_snapshot(snap)
	_show_save_recovery_notice(snap)
	
	var interval := _get_sanctum_bank_interval_seconds()
	econ_bank_timer.wait_time = float(interval)
	econ_bank_timer.timeout.connect(_on_econ_bank_timer_timeout)
	save_recovery_timer.timeout.connect(_hide_save_recovery_notice)
	_maybe_start_econ_timer_from_snapshot(snap)
	_maybe_stop_econ_timer_from_snapshot(snap)
	
	# Connect debug panel to AppRoot
	debug_panel.command_submitted.connect(_on_debug_command)

	_flush_logs_to_console()

	# Headless CI: run tests when launched with `-- tests` argument
	if is_test_run:
		_run_tests(cmdline_args)
		get_tree().quit()

func _show_save_recovery_notice(snap: Dictionary) -> void:
	var meta_v: Variant = snap.get("meta", {})
	var meta: Dictionary = meta_v if meta_v is Dictionary else {}
	var recovery_v: Variant = meta.get("save_recovery", {})
	if not (recovery_v is Dictionary) or (recovery_v as Dictionary).is_empty():
		return
	var recovery: Dictionary = recovery_v
	save_recovery_message.text = str(recovery.get(
		"message",
		"Your campaign was recovered from a verified backup."
	))
	save_recovery_notice.visible = true
	save_recovery_timer.start()

func _hide_save_recovery_notice() -> void:
	save_recovery_notice.visible = false

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

func _on_layout_changed(layout: Dictionary) -> void:
	_current_layout = layout.duplicate(true)
	if _active_onboarding_screen != null and _active_onboarding_screen.has_method("set_layout"):
		_active_onboarding_screen.call("set_layout", _current_layout)
	if _save_error_screen != null and _save_error_screen.has_method("set_layout"):
		_save_error_screen.call("set_layout", _current_layout)
	if _sanctum_shell != null and _sanctum_shell.has_method("set_layout"):
		_sanctum_shell.set_layout(_current_layout)
	if _realm_shell != null and _realm_shell.has_method("set_layout"):
		_realm_shell.set_layout(_current_layout)
	
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

	# -------------------------
	# emotion (EMOTION-001)
	# -------------------------
	if head == "emotion":
		_run_emotion_command(parts)
		return

	# -------------------------
	# hero_info (archetype system)
	# -------------------------
	if head == "hero_info" or head == "hero":
		_run_hero_info_command(parts)
		return

	# -------------------------
	# combat_objective dev toggle (COMBAT-006)
	# -------------------------
	if head == "combat_objective":
		_run_combat_objective_command(parts)
		return

	# -------------------------
	# combat_emotion debug overlay toggle
	# -------------------------
	if head == "combat_emotion" or head == "combat_em":
		_run_combat_emotion_command()
		return

	# -------------------------
	# vow shortcuts (VOW-001 / debug only)
	# -------------------------
	if head == "vow":
		_run_vow_command(parts)
		return

	# -------------------------
	# spawn_ally dev command (V2-STAGE-004 Phase 4 S12 / debug only)
	# -------------------------
	if head == "spawn_ally":
		_run_spawn_ally_command()
		return

	# -------------------------
	# force_claimant_combat dev command (V2-STAGE-004 Phase 4 S13 / debug only)
	# -------------------------
	if head == "force_claimant_combat":
		_run_force_claimant_combat_command()
		return

	# -------------------------
	# force_charge_pressure dev command (V2-STAGE-004 Phase 4 S13 / debug only)
	# -------------------------
	if head == "force_charge_pressure":
		_run_force_charge_pressure_command(parts)
		return

	# -------------------------
	# force_recruit dev toggle (V2-STAGE-004 Phase 4 S14 / debug only)
	# -------------------------
	if head == "force_recruit":
		_run_force_recruit_command(parts)
		return

	# -------------------------
	# institution shortcuts (V2-SANCTUM-002 / debug only)
	# -------------------------
	if head == "institution" or head == "inst":
		_run_institution_command(parts)
		return

	_debug_print("Unknown command: " + cmd)
	_debug_print("Try: tests | ase show | ase add 10 [reason] | ase spend 5 [reason] | ekwan show | ekwan add 1 | ekwan spend 1 | emotion [echo_id] | hero_info <echo_id> | combat_objective [purify_shrine|defeat_enemies|guide_spirit [protect|escort] [join|nojoin]] | combat_emotion | vow unlock <vow_id> | institution unlock <hearth|training_grounds|all> | spawn_ally | force_claimant_combat | force_charge_pressure [on|off] | force_recruit <success|fail|clear>")
	
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
	ActorTests.register(runner)
	EchoSchemaTests.register(runner)
	ActorStatInitTests.register(runner)
	DerivedStatTests.register(runner)
	BehaviorModuleTests.register(runner)
	MeleeTests.register(runner)  # ACTOR-004
	BehaviorArbiterTests.register(runner)  # ACTOR-005
	StructureTests.register(runner)        # ACTOR-006
	MoraleInfluenceTests.register(runner)  # ACTOR-007
	KODeathTests.register(runner)          # ACTOR-008
	EmotionTests.register(runner)
	LeadershipEmotionTestsScript.register(runner)
	SanctumPulseTestsScript.register(runner)
	FoundationUITestsScript.register(runner)
	VectorTests.register(runner)
	DirectiveTests.register(runner)  # DIRECTIVE-001
	GridTests.register(runner)       # GRID-001
	# V2-COMBAT-002 slice 1: shared movement contracts + weighted path primitives
	MovementContractTestsScript.register(runner)
	MovementPathTestsScript.register(runner)
	# V2-COMBAT-002 slice 2: dormant pressure, route options, and complete-candidate arbitration
	MovementSlice2ContractTestsScript.register(runner)
	CombatPressureTestsScript.register(runner)
	MovementOptionTestsScript.register(runner)
	MovementArbitrationTestsScript.register(runner)
	# V2-COMBAT-002 slice 3: dormant movement capacity profile derivation
	MovementProfileTestsScript.register(runner)
	# V2-COMBAT-002 slice 3: dormant fixed-hazard behavior (unstable/binding/burning)
	MovementHazardTestsScript.register(runner)
	# V2-COMBAT-002 slice 3: dormant edge-by-edge movement executor
	MovementExecutorTestsScript.register(runner)
	CombatActivationTestsScript.register(runner)  # V2-COMBAT-002 Slice 3: activation coordinator
	CombatStateTests.register(runner)        # COMBAT-001 + COMBAT-002
	CombatInitiativeTests.register(runner)   # V2-COMBAT-001: readiness score (morale-tier)
	CombatConsequenceTests.register(runner)  # V2-COMBAT-001: guard routing, hesitation band
	CombatSupportLedgerTests.register(runner) # V2-COMBAT-00x (S14b): support/defensive attribution
	CombatServiceTests.register(runner) # COMBAT-003
	CombatRoundTests.register(runner)     # COMBAT-004
	CombatSnapshotTests.register(runner) # COMBAT-007
	CombatTokenPresentationTests.register(runner)
	RetreatTests.register(runner)        # UI-004
	ArchetypeTests.register(runner)      # 9-archetype personality system
	MaturityExpressionTests.register(runner)  # V2-PROG-006
	RealmModelTests.register(runner)     # REALM-001
	ObjectiveModelTests.register(runner) # REALM-002
	StageModelTests.register(runner)     # REALM-002
	EconomyRewardTests.register(runner)  # ECONOMY-004
	StageProgressionTests.register(runner)  # REALM-004
	RealmRewardTests.register(runner)       # REALM-005
	ProgressionTests.register(runner)       # PROG-003
	EchoPartyRadarTests.register(runner)  # UI stat profile
	CallingTests.register(runner)           # PROG-007
	SkillDefinitionTests.register(runner)   # PROG-008
	CallingBehaviorTests.register(runner)   # PROG-009
	ExclusiveActionTests.register(runner)   # PROG-009
	CooldownTests.register(runner)          # PROG-009
	PassiveIdentityTests.register(runner)   # PROG-009
	SkillLoadoutTests.register(runner)      # PROG-009
	SocialGraphTests.register(runner)  # BOND-001
	BondTriggerTests.register(runner)  # BOND-002
	VowServiceTests.register(runner)  # VOW-001
	SaveBridgeTests.register(runner)  # V2-MIG-002
	SaveIntegrityTestsScript.register(runner)
	ThreadServiceTests.register(runner)                      # V2-WEAVE-001
	WeavingRiteTests.register(runner)  # V2-WEAVE-002
	StageExploreTests.register(runner)    # V2-STAGE-001
	StageObjectiveTests.register(runner)  # V2-STAGE-002
	IntelPersistenceTests.register(runner) # V2-INTEL-001
	OnboardingTests.register(runner)
	VoiceTests.register(runner)           # V2-VOICE-001
	InstitutionTests.register(runner)     # V2-SANCTUM-002
	SanctumLayoutTests.register(runner)  # V2-SANCTUM-002: layout + occupant placement
	ContinuityTests.register(runner)     # V2-CONTINUITY-001
	SkillUnlockTests.register(runner)    # V2-PROG-009
	ContactModelTests.register(runner)  # V2-STAGE-003
	SituationResolutionServiceTests.register(runner)  # V2-STAGE-004
	UnifiedResolveTests.register(runner)              # V2-STAGE-004 unified resolve snapshot
	# V2-STAGE-004 Phase 2
	StageTerrainTests.register(runner)       # V2-STAGE-004-P2: terrain generation + connectivity
	DirectiveConfigTests.register(runner)    # V2-STAGE-004-P2: directive traversal config
	TraversalModelTests.register(runner)     # V2-STAGE-004-P2: party traversal + step_budget
	# V2-STAGE-004 Phase 3a
	CombatTerrainTests.register(runner)      # V2-STAGE-004-P3a: combat-terrain placement + movement
	# V2-STAGE-004 Phase 3 — per-mode win/lose (RECOVER / PROTECT / ENDURE)
	ObjectiveCombatTests.register(runner)    # V2-STAGE-004-P3: objective win/lose conditions
	CombatRoundtripIntegrationTests.register(runner)  # V2-STAGE-004-P3: real combat round loop on irregular terrain (id-keyed wiring)
	# V2-STAGE-004 Phase 5
	StageExploreP5Tests.register(runner)     # V2-STAGE-004-P5: directive composite, party_preview emotional_status, situation_pending.choices, travel-beat
	# V2-STAGE-004 Phase 4 (S16a) — recruitment + contact-actor unit tests
	RecruitmentServiceTests.register(runner)     # V2-STAGE-004-P4 S14: earned-return recruit chance + promotion
	ContactActorBuilderTests.register(runner)    # V2-STAGE-004-P4 S12: temporary-ally combat actor builder
	# V2-STAGE-004 Phase 4 (S16b) — seam + exclusion tests (ally auto-join, claimant-forced
	# combat, charge-pressure bump, ally recruit offer compute-once, projection shapes)
	Stage004SeamTests.register(runner)

	var result: Dictionary = runner.run_all()
	_debug_print("Tests: %d total, %d passed, %d failed" % [
		int(result.get("total", 0)),
		int(result.get("passed", 0)),
		int(result.get("failed", 0))
	])

	var results: Array = result.get("results", [])

	# Group by suite prefix (text before first "/") for compact, scannable output.
	var suite_order: Array = []
	var suite_map: Dictionary = {}  # suite → { passed, failed, failures[] }
	for r in results:
		var rname := str(r.get("name", "unnamed"))
		var slash_idx := rname.find("/")
		var suite := rname.substr(0, slash_idx) if slash_idx >= 0 else rname
		if not suite_map.has(suite):
			suite_order.append(suite)
			suite_map[suite] = { "passed": 0, "failed": 0, "failures": [] }
		if bool(r.get("ok", false)):
			suite_map[suite]["passed"] += 1
		else:
			suite_map[suite]["failed"] += 1
			(suite_map[suite]["failures"] as Array).append(
				"  ❌ " + rname + " — " + str(r.get("error", "unknown error"))
			)

	for suite in suite_order:
		var s: Dictionary = suite_map[suite]
		var n_pass := int(s.get("passed", 0))
		var n_fail := int(s.get("failed", 0))
		if n_fail == 0:
			_debug_print("✅ %s — %d passed" % [suite, n_pass])
		else:
			_debug_print("❌ %s — %d passed, %d failed" % [suite, n_pass, n_fail])
			for fail_line in (s.get("failures", []) as Array):
				_debug_print(str(fail_line))
			
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

# EMOTION-001: emotion debug command
# Usage:
#   emotion          — print emotion block for all roster echoes
#   emotion <echo_id> — print emotion block for a specific echo by id
func _run_emotion_command(parts: Array) -> void:
	var save_ref: Dictionary = runtime.get_save_data()
	var sanctum: Dictionary = (save_ref.get("sanctum", {}) as Dictionary)
	var roster: Array = sanctum.get("roster", []) as Array

	if roster.is_empty():
		_debug_print("emotion: roster is empty")
		_flush_logs_to_console()
		return

	var target_id := ""
	if parts.size() >= 2:
		target_id = str(parts[1]).strip_edges()

	var found := false
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v as Dictionary
		var eid := str(echo.get("id", ""))

		if target_id != "" and eid != target_id:
			continue

		var _emo := EmotionService.get_emotion(echo)
		_debug_print("emotion | id=%s name=%s faith=%d morale_base=%d morale_current=%d tier=%s fear=%d" % [
			eid,
			str(echo.get("name", "?")),
			int(_emo.get("faith",          50)),
			int(_emo.get("morale_base",    50)),
			int(_emo.get("morale_current", 50)),
			EmotionService.get_morale_tier(int(_emo.get("morale_current", 50))),
			int(_emo.get("fear_current",   0))
		])
		found = true

		if target_id != "":
			break

	if target_id != "" and not found:
		_debug_print("emotion: echo_id '%s' not found in roster" % target_id)

	_flush_logs_to_console()

# Usage:
#   hero_info <echo_id> — print archetype, bias, dialogue key, bark, traits, vectors, stats
func _run_hero_info_command(parts: Array) -> void:
	if parts.size() < 2:
		_debug_print("Usage: hero_info <echo_id>")
		_flush_logs_to_console()
		return

	var target_id := str(parts[1]).strip_edges()
	var save_ref: Dictionary = runtime.get_save_data()
	var sanctum: Dictionary  = save_ref.get("sanctum", {}) as Dictionary
	var roster: Array        = sanctum.get("roster", []) as Array

	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v as Dictionary
		if str(echo.get("id", "")) != target_id:
			continue

		var arch  := str(echo.get("archetype_birth", ""))
		var bias  := PersonalityArchetype.combat_bias(arch)
		var dkey  := PersonalityArchetype.dialogue_key(arch)
		var t_v   := echo.get("traits", {}) as Dictionary
		var tier  := ShoutBank.get_tier(int(t_v.get("courage", 0)), int(t_v.get("wisdom", 0)), int(t_v.get("faith", 0)))
		var bark  := ShoutBank.get_shout("arrival", arch, tier)
		var stats := echo.get("stats", {}) as Dictionary
		var vs    := echo.get("vector_scores", {}) as Dictionary
		var dom_v := str(echo.get("dominant_vector", "?"))

		_debug_print("[hero_info] id=%s  name=%s  arch=%s  bias=%s  dialogue=%s" % [
			target_id, str(echo.get("name", "?")), arch, bias, dkey
		])
		_debug_print("  traits: courage=%d wisdom=%d faith=%d" % [
			int(t_v.get("courage", 0)), int(t_v.get("wisdom", 0)), int(t_v.get("faith", 0))
		])
		_debug_print("  vectors: dominant=%s  (vanguard=%d protector=%d seeker=%d pillar=%d)" % [
			dom_v,
			int(vs.get("vanguard", 0)), int(vs.get("protector", 0)),
			int(vs.get("seeker", 0)),   int(vs.get("pillar", 0))
		])
		_debug_print("  stats: hp=%d atk=%d def=%d agi=%d speed=%d" % [
			int(stats.get("max_hp", 0)), int(stats.get("atk", 0)), int(stats.get("def", 0)),
			int(stats.get("agi", 0)),    int(stats.get("speed", 0))
		])
		_debug_print("  Bark: \"%s\"" % bark)
		_flush_logs_to_console()
		return

	_debug_print("hero_info: echo_id '%s' not found in roster" % target_id)
	_flush_logs_to_console()


# COMBAT-006: dev toggle for encounter objective.
# Usage: combat_objective <combat|purify_shrine|recover|protect|endure|pursue|guide_spirit|show>
# V2-STAGE-004 P3c: for guide_spirit, optional 3rd/4th tokens force the two seeded rolls:
#   combat_objective guide_spirit [protect|escort] [join|nojoin]
# Omitting them clears both dev fields to "" (seeded). Any non-guide mode also clears both.
func _run_combat_objective_command(parts: Array) -> void:
	var valid_modes: Array = [
		EncounterResolutionModes.COMBAT,
		EncounterResolutionModes.PURIFY_SHRINE,
		EncounterResolutionModes.RECOVER,
		EncounterResolutionModes.PROTECT,
		EncounterResolutionModes.ENDURE,
		EncounterResolutionModes.PURSUE,
		EncounterResolutionModes.GUIDE_SPIRIT,
	]
	if parts.size() < 2:
		_debug_print("Usage: combat_objective <combat|purify_shrine|recover|protect|endure|pursue|guide_spirit|show> | guide_spirit [protect|escort] [join|nojoin]")
		return
	var op: String = parts[1].to_lower()
	if op == "show":
		var current: String = runtime.flow_ctx.dev_combat_objective
		if current.is_empty():
			_debug_print("combat_objective: using default (resolved from stage objective)")
		else:
			_debug_print("combat_objective: override = %s" % current)
		var gm: String = runtime.flow_ctx.dev_guide_mode
		var gj: String = runtime.flow_ctx.dev_guide_joins
		_debug_print("guide_mode override: %s | guide_joins override: %s" % [
			("seeded" if gm.is_empty() else gm), ("seeded" if gj.is_empty() else gj)])
		return
	if op in valid_modes:
		runtime.flow_ctx.dev_combat_objective = op
		# V2-STAGE-004 P3c: guide_spirit sub-tokens force the two seeded rolls; any other
		# mode clears both back to "" (seeded).
		if op == EncounterResolutionModes.GUIDE_SPIRIT:
			var forced_mode: String = ""
			var forced_joins: String = ""
			if parts.size() >= 3:
				var m: String = str(parts[2]).to_lower()
				if m == "protect" or m == "escort":
					forced_mode = m
				else:
					_debug_print("Ignoring unknown guide mode token '%s' (use protect|escort)" % m)
			if parts.size() >= 4:
				var j: String = str(parts[3]).to_lower()
				if j == "join" or j == "nojoin":
					forced_joins = j
				else:
					_debug_print("Ignoring unknown guide joins token '%s' (use join|nojoin)" % j)
			runtime.flow_ctx.dev_guide_mode = forced_mode
			runtime.flow_ctx.dev_guide_joins = forced_joins
			_debug_print("guide overrides: mode=%s joins=%s" % [
				("seeded" if forced_mode.is_empty() else forced_mode),
				("seeded" if forced_joins.is_empty() else forced_joins)])
		else:
			runtime.flow_ctx.dev_guide_mode = ""
			runtime.flow_ctx.dev_guide_joins = ""
		# Reset encounter state so next entry uses the new objective.
		runtime.flow_ctx.encounter_ctx = null
		runtime.flow_ctx.encounter_machine = null
		_debug_print("combat_objective set to: %s — encounter reset, re-enter combat to apply" % op)
	else:
		_debug_print("Unknown mode '%s'. Use: combat|purify_shrine|recover|protect|endure|pursue|guide_spirit" % op)
	_flush_logs_to_console()


# Toggle the emotion debug overlay on the active CombatBoardScreen.
# Shows F:<fear> and M:<morale> above each actor token.
# No-ops gracefully when CombatBoardScreen is not active.
func _run_combat_emotion_command() -> void:
	# CombatBoardScreen now lives inside RealmShell — access it via the active overlay.
	var combat_screen: CombatBoardScreen = null
	if _realm_shell != null and _realm_shell.visible:
		var overlay: Control = _realm_shell._active_overlay
		if overlay is CombatBoardScreen:
			combat_screen = overlay as CombatBoardScreen

	if combat_screen == null:
		_debug_print("combat_emotion: CombatBoardScreen not active — command ignored")
		_flush_logs_to_console()
		return
	# Toggle the flag. Read current state from the token layer directly.
	var currently_on: bool = combat_screen._token_layer._emotion_debug
	combat_screen.set_emotion_debug(not currently_on)
	var state_label: String = "ON" if not currently_on else "OFF"
	_debug_print("Emotion debug: %s" % state_label)
	_flush_logs_to_console()


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-004 Phase 4 dev commands — manual testing aids for the conversation-RNG-
# gated combat seams. Dev-only; each command guards the "must be exploring a stage"
# precondition here (before dispatching) so the player-facing message always reaches
# the debug panel, mirroring the guide_spirit dev-override precedent's determinism.
# ────────────────────────────────────────────────────────────────────────────

# S12: stages a synthetic temporary_ally contact so the next encounter fought in this
# stage auto-joins it. Usage: spawn_ally
func _run_spawn_ally_command() -> void:
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != "flow.stage_explore":
		_debug_print("spawn_ally: only usable while exploring a stage (flow.stage_explore).")
		_flush_logs_to_console()
		return
	var snap := runtime.dispatch({ "type": "debug.ally.spawn" })
	_render_snapshot(snap)
	_debug_print("Ally staged — it will join the next encounter.")
	_flush_logs_to_console()


# S13: replicates the claimant-hostile branch — forces immediate combat with
# combat_intro_reason="claimant_hostile". Usage: force_claimant_combat
func _run_force_claimant_combat_command() -> void:
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != "flow.stage_explore":
		_debug_print("force_claimant_combat: only usable while exploring a stage (flow.stage_explore).")
		_flush_logs_to_console()
		return
	var snap := runtime.dispatch({ "type": "debug.claimant.force_combat" })
	_render_snapshot(snap)
	_debug_print("Hostile Claimant combat forced — entering flow.encounter.")
	_flush_logs_to_console()


# S13: sets/clears explore_map.hostile_charge_sit_id, consumed by the next protect/endure
# objective combat. Usage: force_charge_pressure [on|off]  (default on)
func _run_force_charge_pressure_command(parts: Array) -> void:
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != "flow.stage_explore":
		_debug_print("force_charge_pressure: only usable while exploring a stage (flow.stage_explore).")
		_flush_logs_to_console()
		return
	var op := "on"
	if parts.size() >= 2:
		op = str(parts[1]).to_lower()
	if op != "on" and op != "off":
		_debug_print("Usage: force_charge_pressure [on|off]")
		_flush_logs_to_console()
		return
	var on := (op == "on")
	var snap := runtime.dispatch({ "type": "debug.charge_pressure.set", "on": on })
	_render_snapshot(snap)
	if on:
		_debug_print("Charge pressure ON — next protect/endure objective combat is harder.")
	else:
		_debug_print("Charge pressure OFF.")
	_flush_logs_to_console()


# S14: forces the ally recruit-offer roll outcome via flow_ctx.dev_force_recruit
# (draw-then-override, honored in FlowRuntime._compute_ally_recruit_offer_if_eligible).
# Usage: force_recruit <success|fail|clear>
func _run_force_recruit_command(parts: Array) -> void:
	if parts.size() < 2:
		_debug_print("Usage: force_recruit <success|fail|clear>")
		_flush_logs_to_console()
		return
	var op := str(parts[1]).to_lower()
	match op:
		"success":
			runtime.flow_ctx.dev_force_recruit = "success"
			_debug_print("force_recruit: override = success — next earned-return ally offer rolls a guaranteed success.")
		"fail":
			runtime.flow_ctx.dev_force_recruit = "fail"
			_debug_print("force_recruit: override = fail — next earned-return ally offer rolls a guaranteed failure (no offer).")
		"clear":
			runtime.flow_ctx.dev_force_recruit = ""
			_debug_print("force_recruit: override cleared — using seeded roll.")
		_:
			_debug_print("Unknown force_recruit op '%s'. Use: success|fail|clear" % op)
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

# INFRA-001: Two-branch router. Sanctum-family → SanctumShell, venture-family → RealmShell.
# All screen preloading and routing lives inside each shell.
const SANCTUM_FAMILY: Array = [
	"flow.sanctum",
	"flow.summon",
	"flow.echo_party",
	"flow.realm_select",   # REALM-001
	"flow.vow_manage",     # VOW-001
	"flow.weaving_rite",   # V2-WEAVE-002
]
const VENTURE_FAMILY: Array = [
	"flow.stage_map",
	"flow.stage",
	"flow.stage_explore",  # V2-STAGE-001
	"flow.encounter",
	"flow.keeper_trial",
	"flow.resolve",
]
const ONBOARDING_FAMILY: Array = [
	"flow.onboarding_invocation",
	"flow.onboarding_anansi",
	"flow.onboarding_choose_name",
	"flow.onboarding_meeting",
	"flow.onboarding_empty_sanctum",
	"flow.onboarding_name_sanctum",
	"flow.keeper_call",
	"flow.keeper_rewind",
	"flow.keeper_thread_return",
	"flow.keeper_awakening",
	"flow.keeper_weaving",
	"flow.keeper_keeping",
]

func _render_snapshot(snap: Dictionary) -> void:
	var snap_type := str(snap.get("type", ""))
	if snap_type == "flow.save_error":
		if _save_error_screen == null:
			_save_error_screen = _save_error_scene.instantiate() as Control
			screen_host.add_child(_save_error_screen)
			if _save_error_screen.has_method("set_layout"):
				_save_error_screen.call("set_layout", _current_layout)
		_show_screen(_save_error_screen)
		_save_error_screen.call("set_snapshot", snap)
		return

	if snap_type in ONBOARDING_FAMILY:
		var packed_v: Variant = _onboarding_scene_by_type.get(snap_type, null)
		var packed: PackedScene = packed_v if packed_v is PackedScene else null
		if packed == null:
			push_warning("AppRoot: no onboarding scene mapped for snapshot type: " + snap_type)
			return
		if _active_onboarding_screen == null or _active_onboarding_screen.scene_file_path != packed.resource_path:
			if _active_onboarding_screen != null:
				_active_onboarding_screen.queue_free()
				_active_onboarding_screen = null
			_active_onboarding_screen = packed.instantiate() as Control
			screen_host.add_child(_active_onboarding_screen)
			if _active_onboarding_screen.has_method("set_layout"):
				_active_onboarding_screen.call("set_layout", _current_layout)
			if _active_onboarding_screen.has_signal("action_requested"):
				_active_onboarding_screen.connect("action_requested", Callable(self, "_on_ui_action_selected"))
		_show_screen(_active_onboarding_screen)
		if _active_onboarding_screen.has_method("set_snapshot"):
			_active_onboarding_screen.call("set_snapshot", snap)
		return

	if snap_type in SANCTUM_FAMILY:
		if _sanctum_shell == null:
			_sanctum_shell = _sanctum_shell_scene.instantiate() as SanctumShell
			screen_host.add_child(_sanctum_shell)
			_sanctum_shell.set_blocking_modal_active_check(Callable(modal_host, "has_active_modal"))
			_sanctum_shell.action_requested.connect(_on_ui_action_selected)
			if _sanctum_shell.has_signal("modal_requested"):
				_sanctum_shell.connect("modal_requested", Callable(self, "_on_shell_modal_requested").bind(_sanctum_shell))
			_sanctum_shell.set_layout(_current_layout)
		_show_screen(_sanctum_shell)
		_sanctum_shell.set_snapshot(snap)
		return

	if snap_type in VENTURE_FAMILY:
		if _realm_shell == null:
			_realm_shell = _realm_shell_scene.instantiate() as RealmShell
			screen_host.add_child(_realm_shell)
			_realm_shell.action_requested.connect(_on_ui_action_selected)
			if _realm_shell.has_signal("modal_requested"):
				_realm_shell.connect("modal_requested", Callable(self, "_on_shell_modal_requested").bind(_realm_shell))
			_realm_shell.set_layout(_current_layout)
		_show_screen(_realm_shell)
		_realm_shell.set_snapshot(snap)
		return

	# No bespoke screen found for this snapshot type — fall back to UISnapshotRenderer.
	_hide_bespoke_screens()
	renderer.render(snap)

func _show_screen(screen: Control) -> void:
	screen_host.visible = true
	fallback_root.visible = false
	snapshot_view.visible = false
	actions_container.visible = false

	if _sanctum_shell != null:
		_sanctum_shell.visible = false
	if _realm_shell != null:
		_realm_shell.visible = false
	if _active_onboarding_screen != null:
		_active_onboarding_screen.visible = false
	if _save_error_screen != null:
		_save_error_screen.visible = false

	screen.visible = true

func _on_shell_modal_requested(modal_id: StringName, payload: Dictionary, shell: Control) -> void:
	_present_shell_modal(modal_id, payload, shell)

func _present_shell_modal(modal_id: StringName, payload: Dictionary, shell: Control) -> bool:
	if shell == null or not is_instance_valid(shell) or not shell.has_method("modal_scene_for"):
		return false
	var scene_v: Variant = shell.call("modal_scene_for", modal_id)
	var scene: PackedScene = scene_v if scene_v is PackedScene else null
	if scene == null:
		return false
	if not modal_host.has_method("present_modal_for_id"):
		return false
	var previous_id := &""
	if modal_host.has_method("active_modal_id"):
		previous_id = modal_host.call("active_modal_id")
	if previous_id != &"" and (_modal_owner == null or not is_instance_valid(_modal_owner) or _modal_owner != shell):
		return false
	var accepted := bool(modal_host.call("present_modal_for_id", modal_id, scene, payload))
	if accepted and previous_id == &"":
		_modal_owner = shell
	if accepted and shell.has_method("on_modal_accepted"):
		shell.call("on_modal_accepted", modal_id, payload)
	return accepted

func _on_modal_dismissed(modal_id: StringName) -> void:
	if _modal_owner != null and is_instance_valid(_modal_owner) and _modal_owner.has_method("on_modal_dismissed"):
		_modal_owner.call("on_modal_dismissed", modal_id)
	_modal_owner = null

func _run_vow_command(parts: Array) -> void:
	# Usage (VOW-001 debug only):
	#   vow unlock <vow_id>      — unlock a vow at tier 1
	#   vow pledge <vow_id>      — force-pledge a vow at tier 1 (bypasses realm check)
	#   vow break                — force-break the active vow
	#   vow status               — show active vow, unlocked list, realm block state
	if parts.size() < 2:
		_debug_print("Usage: vow unlock <vow_id> | vow pledge <vow_id> | vow break | vow status")
		_flush_logs_to_console()
		return

	var op := str(parts[1]).to_lower()
	var save_ref: Dictionary = runtime.get_save_data()
	var t := 0
	if runtime.has_method("get_tick"):
		t = int(runtime.get_tick())

	if op == "unlock":
		if parts.size() < 3:
			_debug_print("Usage: vow unlock <vow_id>  |  known: tikoro_nko_agyina")
			_flush_logs_to_console()
			return
		var vow_id := str(parts[2])
		var snap := runtime.dispatch({ "type": "debug.vow.unlock", "vow_id": vow_id })
		_render_snapshot(snap)
		_debug_print("Vow unlocked (tier 1): %s" % vow_id)
		_debug_print("  Use 'vow pledge %s' to pledge it." % vow_id)

	elif op == "pledge":
		# Force-pledge: bypasses realm_in_progress check for testing.
		if parts.size() < 3:
			_debug_print("Usage: vow pledge <vow_id>  |  known: tikoro_nko_agyina")
			_flush_logs_to_console()
			return
		var vow_id := str(parts[2])
		var cfg: Dictionary = runtime.flow_ctx.config_service.get_balance()
		var ok := VowService.pledge_vow(vow_id, 1, cfg, save_ref, runtime.flow_ctx, logger, t)
		if ok:
			var snap := runtime.dispatch({ "type": "debug.vow.unlock", "vow_id": vow_id })  # refresh snapshot
			_render_snapshot(snap)
			_debug_print("Vow pledged (tier 1): %s" % vow_id)
		else:
			_debug_print("Pledge failed — vow may not be unlocked yet or one is already active. Try 'vow unlock %s' first." % vow_id)

	elif op == "break":
		var cfg: Dictionary = runtime.flow_ctx.config_service.get_balance()
		var summary := VowService.break_vow(cfg, save_ref, runtime.flow_ctx, runtime.econ, logger, t)
		if summary.is_empty():
			_debug_print("No active vow to break.")
		else:
			var snap := runtime.dispatch({ "type": "debug.vow.unlock", "vow_id": "" })  # refresh snapshot
			_render_snapshot(snap)
			_debug_print("Vow broken: %s (tier %d)" % [str(summary.get("vow_id", "?")), int(summary.get("tier", 1))])
			_debug_print("  Ase lost: %d | Morale delta: %d | Fear delta: %d" % [
				int(summary.get("ase_spent", 0)),
				int(summary.get("morale_delta", 0)),
				int(summary.get("fear_delta", 0))
			])

	elif op == "status":
		var active := VowService.get_active_vow(save_ref)
		var unlocked := VowService.get_unlocked_vows(save_ref)
		if active.is_empty():
			_debug_print("Active vow: none")
		else:
			_debug_print("Active vow: %s (tier %d, pledged at realm '%s')" % [
				str(active.get("vow_id", "?")),
				int(active.get("tier", 1)),
				str(active.get("pledged_at_realm", "?"))
			])
		if unlocked.is_empty():
			_debug_print("Unlocked vows: none")
		else:
			for entry_v in unlocked:
				if not (entry_v is Dictionary):
					continue
				var entry: Dictionary = entry_v
				_debug_print("  - %s (max tier %d, found at '%s')" % [
					str(entry.get("vow_id", "?")),
					int(entry.get("max_tier_unlocked", 1)),
					str(entry.get("discovered_realm", "?"))
				])
		# Show whether pledging is currently blocked
		var realm_blocked := false
		var realms_v: Variant = save_ref.get("realms", {})
		if realms_v is Dictionary:
			var realms: Dictionary = realms_v
			for rid in realms:
				var rm_v: Variant = realms[rid]
				if rm_v is Dictionary and str((rm_v as Dictionary).get("status", "")) == "active":
					_debug_print("  ⚠ Realm '%s' is active — pledging blocked (use 'vow pledge <id>' to bypass)" % rid)
					realm_blocked = true
					break
		if not realm_blocked and active.is_empty():
			_debug_print("  Pledging is open.")
	else:
		_debug_print("Unknown vow op: %s" % op)
		_debug_print("Usage: vow unlock <vow_id> | vow pledge <vow_id> | vow break | vow status")

	_flush_logs_to_console()


func _run_institution_command(parts: Array) -> void:
	# Usage (V2-SANCTUM-002 debug only):
	#   institution unlock <hearth|training_grounds|all>
	#   institution lock   <hearth|training_grounds|all>
	#   institution status
	const KNOWN_IDS := ["hearth", "training_grounds"]
	if parts.size() < 2:
		_debug_print("Usage: institution unlock <hearth|training_grounds|all> | institution lock <id|all> | institution status")
		_flush_logs_to_console()
		return

	var op := str(parts[1]).to_lower()
	var save_ref: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save_ref.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var institutions_v: Variant = sanctum.get("institutions", {})
	var institutions: Dictionary = institutions_v if institutions_v is Dictionary else {}

	var target := str(parts[2]).to_lower() if parts.size() >= 3 else ""
	var targets: Array = KNOWN_IDS if target == "all" or target.is_empty() else [target]

	if op == "unlock":
		# "unlock" means make it a candidate — Continuity threshold met, not yet placed.
		# The player still goes through the full Establish → placement flow.
		if target.is_empty():
			_debug_print("Usage: institution unlock <hearth|training_grounds|all>")
			_flush_logs_to_console()
			return
		# Set Continuity high enough for all requested institutions.
		# training_grounds needs 2; hearth needs 1.
		var needed_continuity := 1
		for iid in targets:
			if iid == "training_grounds":
				needed_continuity = 2
		var current_continuity := int(sanctum.get("continuity", 0))
		if current_continuity < needed_continuity:
			sanctum["continuity"] = needed_continuity
			_debug_print("Continuity set to %d (was %d)" % [needed_continuity, current_continuity])
		for iid in targets:
			if not institutions.has(iid):
				_debug_print("Unknown institution: %s  (known: %s)" % [iid, ", ".join(KNOWN_IDS)])
				continue
			_debug_print("Institution now a candidate: %s — tap Establish in the panel to place it." % iid)
		var snap := runtime.dispatch({ "type": "flow.go_state", "to": "flow.sanctum" })
		_render_snapshot(snap)

	elif op == "lock":
		if target.is_empty():
			_debug_print("Usage: institution lock <hearth|training_grounds|all>")
			_flush_logs_to_console()
			return
		for iid in targets:
			if not institutions.has(iid):
				_debug_print("Unknown institution: %s" % iid)
				continue
			institutions[iid]["unlocked"] = false
			_debug_print("Institution locked: %s" % iid)
		var snap := runtime.dispatch({ "type": "flow.go_state", "to": "flow.sanctum" })
		_render_snapshot(snap)

	elif op == "status":
		for iid in KNOWN_IDS:
			if institutions.has(iid):
				var inst: Dictionary = institutions[iid]
				var pos_v: Variant = inst.get("position", {})
				var pos: Dictionary = pos_v if pos_v is Dictionary else {}
				_debug_print("  %s — unlocked=%s condition=%s pos=(%d,%d)" % [
					iid,
					str(inst.get("unlocked", false)),
					str(inst.get("condition", "neglected")),
					int(pos.get("x", 0)),
					int(pos.get("y", 0))
				])
			else:
				_debug_print("  %s — not in save_data" % iid)
	else:
		_debug_print("Unknown institution op: %s" % op)
		_debug_print("Usage: institution unlock <hearth|training_grounds|all> | institution lock <id|all> | institution status")

	_flush_logs_to_console()


func _hide_bespoke_screens() -> void:
	screen_host.visible = false
	fallback_root.visible = true
	snapshot_view.visible = true
	actions_container.visible = true
	if _sanctum_shell != null:
		_sanctum_shell.visible = false
	if _realm_shell != null:
		_realm_shell.visible = false
	if _active_onboarding_screen != null:
		_active_onboarding_screen.visible = false
	if _save_error_screen != null:
		_save_error_screen.visible = false
