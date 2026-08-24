# res://tests/SnapshotContractTests.gd
# V2-INFRA-003 Phase 3 Slice B1 — snapshot contract.
#
# Proves the universal snapshot shape (CONVENTIONS.md → "Snapshot Shape"):
#   { "type": String, "meta": Dictionary, "data": Dictionary, "actions": Dictionary }
# with "actions" always a slot-keyed Dictionary (never an Array) and "meta" always
# carrying a "t" key.
#
# Covers, directly:
#   - flow.splash          (both is_first_boot branches, via a real boot())
#   - flow.main_menu       (both is_first_boot branches, via direct enter())
#   - flow.vow_manage      (via the static build_snapshot() builder)
#   - flow.config_error    (the boot-time config-load-failure snapshot, via the
#                           extracted FlowRuntime._build_config_error_snapshot()
#                           helper — there is no deterministic way to force a real
#                           res://data/*.json load failure from a test without
#                           touching ConfigService or the data files themselves,
#                           both out of this slice's file boundary, so the helper
#                           is unit-tested directly instead)
#
# Plus a broad sweep: boots a real runtime and walks it through onboarding into
# flow.sanctum, asserting the contract on every snapshot produced along the way.
# FlowStateMachine._validate_snapshot() already asserts this same contract on every
# transition for every registered state (see FlowStateMachine.gd), so the full test
# suite is independent corroborating evidence — this file exists to make the specific
# boot-family states (this slice's scope) directly, individually provable.

class_name SnapshotContractTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("snapshot_contract/splash_first_boot", Callable(SnapshotContractTests, "_t_splash_first_boot"))
	runner.register_test("snapshot_contract/splash_returning", Callable(SnapshotContractTests, "_t_splash_returning"))
	runner.register_test("snapshot_contract/main_menu_first_boot", Callable(SnapshotContractTests, "_t_main_menu_first_boot"))
	runner.register_test("snapshot_contract/main_menu_returning", Callable(SnapshotContractTests, "_t_main_menu_returning"))
	runner.register_test("snapshot_contract/vow_manage", Callable(SnapshotContractTests, "_t_vow_manage"))
	runner.register_test("snapshot_contract/boot_config_error", Callable(SnapshotContractTests, "_t_boot_config_error"))
	runner.register_test("snapshot_contract/sweep_boot_through_sanctum", Callable(SnapshotContractTests, "_t_sweep_boot_through_sanctum"))


# ---------------------------------------------------------------------------
# Shared harness (mirrors tests/OnboardingTests.gd's pattern)
# ---------------------------------------------------------------------------

static func _make_logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	return logger

static func _make_runtime(save_suffix: String) -> FlowRuntime:
	var logger := _make_logger()
	var config := ConfigService.new()
	config.load_balance(logger, 0)
	config.load_actors(logger, 0)
	config.load_realms(logger, 0)
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.dir() + "snapshot_contract_%s.json" % save_suffix)
	runtime.flow_ctx = FlowContext.new()
	runtime.flow_ctx.sim_tick = 0
	runtime.flow_ctx.config_service = config
	runtime.flow_ctx.logger = logger
	runtime.flow_ctx.save_data = SaveSchema.make_new_save(12346)
	runtime.flow_ctx.campaign_seed = CampaignSeed.new(12346)
	runtime.econ = EconomyService.new(runtime.flow_ctx.save_data)
	runtime.directive_service = DirectiveService.new(runtime.flow_ctx.save_data)
	runtime.flow_machine = FlowStateMachine.new()
	runtime.flow_machine.register_default_states()
	runtime.flow_machine.start(runtime.flow_ctx, logger, 1)
	return runtime


# ---------------------------------------------------------------------------
# Contract assertion
# ---------------------------------------------------------------------------

## Returns "" when snap conforms; otherwise a human-readable reason, prefixed with
## label so failures identify which snapshot broke the contract.
static func _contract_violation(snap: Dictionary, label: String) -> String:
	if not snap.has("type") or str(snap.get("type", "")).is_empty():
		return "%s: type missing or empty" % label

	var meta_v: Variant = snap.get("meta")
	if typeof(meta_v) != TYPE_DICTIONARY:
		return "%s: meta is not a Dictionary" % label
	var meta: Dictionary = meta_v
	if not meta.has("t"):
		return "%s: meta missing 't'" % label

	if not snap.has("data") or typeof(snap.get("data")) != TYPE_DICTIONARY:
		return "%s: data missing or not a Dictionary" % label

	var actions_v: Variant = snap.get("actions")
	if typeof(actions_v) != TYPE_DICTIONARY:
		return "%s: actions is not a Dictionary (type=%d) — Array actions are legacy/forbidden" % [label, typeof(actions_v)]

	return ""


# ---------------------------------------------------------------------------
# Direct: flow.splash
# ---------------------------------------------------------------------------

static func _t_splash_first_boot() -> Dictionary:
	var ctx := FlowContext.new()
	ctx.save_data = { "first_boot": true }
	FlowSplashState.new().enter(ctx, 7)
	var snap: Dictionary = ctx.last_snapshot
	var err := _contract_violation(snap, "flow.splash (first_boot)")
	if not err.is_empty():
		return { "ok": false, "error": err }
	if str(snap.get("type", "")) != FlowStateIds.SPLASH:
		return { "ok": false, "error": "Expected type flow.splash, got %s" % str(snap.get("type", "")) }
	var actions: Dictionary = snap.get("actions", {})
	if not actions.has("main.cta_primary"):
		return { "ok": false, "error": "Expected actions slot main.cta_primary" }
	if str((actions["main.cta_primary"] as Dictionary).get("type", "")) != "flow.new_game":
		return { "ok": false, "error": "Expected first_boot splash CTA to be flow.new_game" }
	return { "ok": true }

static func _t_splash_returning() -> Dictionary:
	var ctx := FlowContext.new()
	ctx.save_data = { "first_boot": false }
	FlowSplashState.new().enter(ctx, 9)
	var snap: Dictionary = ctx.last_snapshot
	var err := _contract_violation(snap, "flow.splash (returning)")
	if not err.is_empty():
		return { "ok": false, "error": err }
	var actions: Dictionary = snap.get("actions", {})
	var cta: Dictionary = actions.get("main.cta_primary", {})
	if str(cta.get("type", "")) != "flow.advance":
		return { "ok": false, "error": "Expected returning splash CTA to be flow.advance" }
	if str(cta.get("to", "")) != FlowStateIds.MAIN_MENU:
		return { "ok": false, "error": "Expected returning splash CTA to route to flow.main_menu" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Direct: flow.main_menu
# ---------------------------------------------------------------------------

static func _t_main_menu_first_boot() -> Dictionary:
	var ctx := FlowContext.new()
	ctx.save_data = { "first_boot": true }
	FlowMainMenuState.new().enter(ctx, 11)
	var snap: Dictionary = ctx.last_snapshot
	var err := _contract_violation(snap, "flow.main_menu (first_boot)")
	if not err.is_empty():
		return { "ok": false, "error": err }
	var actions: Dictionary = snap.get("actions", {})
	var expected_slots := ["main.cta_primary", "main.settings", "main.quit"]
	for slot in expected_slots:
		if not actions.has(slot):
			return { "ok": false, "error": "Expected actions slot %s" % slot }
	if str((actions["main.cta_primary"] as Dictionary).get("type", "")) != "flow.new_game":
		return { "ok": false, "error": "Expected first_boot main_menu CTA to be flow.new_game" }
	return { "ok": true }

static func _t_main_menu_returning() -> Dictionary:
	var ctx := FlowContext.new()
	ctx.save_data = { "first_boot": false }
	FlowMainMenuState.new().enter(ctx, 13)
	var snap: Dictionary = ctx.last_snapshot
	var err := _contract_violation(snap, "flow.main_menu (returning)")
	if not err.is_empty():
		return { "ok": false, "error": err }
	var actions: Dictionary = snap.get("actions", {})
	if str((actions.get("main.cta_primary", {}) as Dictionary).get("type", "")) != "flow.continue":
		return { "ok": false, "error": "Expected returning main_menu CTA to be flow.continue" }
	if actions.size() != 3:
		return { "ok": false, "error": "Expected exactly 3 action slots, got %d" % actions.size() }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Direct: flow.vow_manage (static build_snapshot() builder — no enter() call)
# ---------------------------------------------------------------------------

static func _t_vow_manage() -> Dictionary:
	var logger := _make_logger()
	var config := ConfigService.new()
	config.load_balance(logger, 0)
	var ctx := FlowContext.new()
	ctx.config_service = config
	ctx.save_data = SaveSchema.make_new_save(555)
	var snap: Dictionary = FlowVowState.build_snapshot(ctx, 15)
	var err := _contract_violation(snap, "flow.vow_manage")
	if not err.is_empty():
		return { "ok": false, "error": err }
	if str(snap.get("type", "")) != FlowStateIds.VOW_MANAGE:
		return { "ok": false, "error": "Expected type flow.vow_manage" }
	var meta: Dictionary = snap.get("meta", {})
	if meta.has("sim_tick"):
		return { "ok": false, "error": "Expected 'sim_tick' key retired in favour of 't'" }
	if int(meta.get("t", -1)) != 15:
		return { "ok": false, "error": "Expected meta.t == 15, got %s" % str(meta.get("t", null)) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Direct: flow.config_error (boot-time config-load-failure snapshot)
# ---------------------------------------------------------------------------

static func _t_boot_config_error() -> Dictionary:
	var snap: Dictionary = FlowRuntime._build_config_error_snapshot(3)
	var err := _contract_violation(snap, "flow.config_error")
	if not err.is_empty():
		return { "ok": false, "error": err }
	if str(snap.get("type", "")) != "flow.config_error":
		return { "ok": false, "error": "Expected type flow.config_error, got %s" % str(snap.get("type", "")) }
	# flow.config_error must not collide with any registered flow state id — transition()
	# returns false for an unregistered id without mutating the (unstarted) machine.
	var machine := FlowStateMachine.new()
	machine.register_default_states()
	var logger := _make_logger()
	var probe_ctx := FlowContext.new()
	if machine.transition("flow.config_error", probe_ctx, logger, 0, "collision_probe"):
		return { "ok": false, "error": "flow.config_error collides with a registered FlowStateIds entry" }
	var actions: Dictionary = snap.get("actions", {})
	if not actions.is_empty():
		return { "ok": false, "error": "Expected empty slot-keyed actions dict for the boot error snapshot" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Sweep: boot → main_menu → onboarding → keeper intro → flow.sanctum
# ---------------------------------------------------------------------------

static func _t_sweep_boot_through_sanctum() -> Dictionary:
	var runtime := _make_runtime("sweep")

	var err := _contract_violation(runtime.flow_ctx.last_snapshot, "boot() initial (%s)" % str(runtime.flow_ctx.last_snapshot.get("type", "")))
	if not err.is_empty():
		return { "ok": false, "error": err }

	runtime.dispatch({ "type": "flow.new_game" })
	err = _contract_violation(runtime.flow_ctx.last_snapshot, "post new_game (%s)" % str(runtime.flow_ctx.last_snapshot.get("type", "")))
	if not err.is_empty():
		return { "ok": false, "error": err }

	var cfg := runtime.config_service.get_balance()
	var onboarding := OnboardingService.ensure_onboarding(runtime.flow_ctx.save_data, cfg)
	var opts: Array = onboarding.get("fragment_options", [])
	if opts.is_empty() or not (opts[0] is Dictionary):
		return { "ok": false, "error": "Expected at least one fragment option" }
	var frag: Dictionary = opts[0]

	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(frag.get("virtue", "")))
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })
	err = _contract_violation(runtime.flow_ctx.last_snapshot, "post fragment.confirm (%s)" % str(runtime.flow_ctx.last_snapshot.get("type", "")))
	if not err.is_empty():
		return { "ok": false, "error": err }

	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_NAME_SANCTUM)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_NAME_SANCTUM, runtime.flow_ctx, runtime.logger, runtime.flow_ctx.sim_tick + 1, "test")
	err = _contract_violation(runtime.flow_ctx.last_snapshot, "post transition to name_sanctum (%s)" % str(runtime.flow_ctx.last_snapshot.get("type", "")))
	if not err.is_empty():
		return { "ok": false, "error": err }

	runtime.dispatch({ "type": "onboarding.name.confirm", "name": "House Test" })
	err = _contract_violation(runtime.flow_ctx.last_snapshot, "post name.confirm (%s)" % str(runtime.flow_ctx.last_snapshot.get("type", "")))
	if not err.is_empty():
		return { "ok": false, "error": err }

	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	err = _contract_violation(runtime.flow_ctx.last_snapshot, "post keeper_intro.call.answer (%s)" % str(runtime.flow_ctx.last_snapshot.get("type", "")))
	if not err.is_empty():
		return { "ok": false, "error": err }

	runtime.dispatch({ "type": "keeper_intro.complete" })
	err = _contract_violation(runtime.flow_ctx.last_snapshot, "post keeper_intro.complete (%s)" % str(runtime.flow_ctx.last_snapshot.get("type", "")))
	if not err.is_empty():
		return { "ok": false, "error": err }
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.SANCTUM:
		return { "ok": false, "error": "Expected to land on flow.sanctum after keeper_intro.complete" }

	return { "ok": true }
