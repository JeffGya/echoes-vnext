class_name OnboardingTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("onboarding/start_routes_to_invocation", Callable(OnboardingTests, "_t_start_routes_to_invocation"))
	runner.register_test("onboarding/fragments_are_seed_deterministic", Callable(OnboardingTests, "_t_fragments_are_seed_deterministic"))
	runner.register_test("onboarding/hear_and_select_updates_snapshot_data", Callable(OnboardingTests, "_t_hear_select_updates_snapshot"))
	runner.register_test("onboarding/confirm_fragment_creates_one_starter", Callable(OnboardingTests, "_t_confirm_fragment_creates_one_starter"))
	runner.register_test("onboarding/starter_dominant_virtue_matches_fragment", Callable(OnboardingTests, "_t_starter_virtue_matches"))
	runner.register_test("onboarding/name_confirm_completes_and_routes_sanctum", Callable(OnboardingTests, "_t_name_confirm_completes"))
	runner.register_test("onboarding/continue_resume_incomplete_skip_complete", Callable(OnboardingTests, "_t_continue_resume_logic"))
	runner.register_test("onboarding/starter_layout_has_thirteen_tiles", Callable(OnboardingTests, "_t_starter_layout_has_thirteen_tiles"))
	runner.register_test("onboarding/starter_layout_is_diamond", Callable(OnboardingTests, "_t_starter_layout_is_diamond"))
	runner.register_test("onboarding/starter_occupant_centered", Callable(OnboardingTests, "_t_starter_occupant_centered"))
	runner.register_test("onboarding/missing_layout_repairs_to_starter", Callable(OnboardingTests, "_t_missing_layout_repairs"))
	runner.register_test("onboarding/sanctum_snapshots_share_layout", Callable(OnboardingTests, "_t_sanctum_snapshots_share_layout"))

static func _make_logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	return logger

static func _make_runtime() -> FlowRuntime:
	var logger := _make_logger()
	var config := ConfigService.new()
	config.load_balance(logger, 0)
	var runtime := FlowRuntime.new(logger, config)
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

static func _cfg() -> Dictionary:
	var logger := _make_logger()
	var config := ConfigService.new()
	config.load_balance(logger, 0)
	return config.get_balance()

static func _first_fragment(save_data: Dictionary, cfg: Dictionary) -> Dictionary:
	var onboarding := OnboardingService.ensure_onboarding(save_data, cfg)
	var opts: Array = onboarding.get("fragment_options", [])
	if opts.is_empty() or not (opts[0] is Dictionary):
		return {}
	return opts[0]

static func _t_start_routes_to_invocation() -> Dictionary:
	var runtime := _make_runtime()
	runtime.call("_handle_new_game", 2)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_INVOCATION, runtime.flow_ctx, runtime.logger, 2, "test")
	var snap := runtime.flow_ctx.last_snapshot
	if str(snap.get("type", "")) != FlowStateIds.ONBOARDING_INVOCATION:
		return { "ok": false, "error": "Expected onboarding invocation, got %s" % str(snap.get("type", "")) }
	if bool(runtime.flow_ctx.save_data.get("first_boot", true)):
		return { "ok": false, "error": "Expected first_boot false after new game" }
	return { "ok": true }

static func _t_fragments_are_seed_deterministic() -> Dictionary:
	var cfg := _cfg()
	var a := SaveSchema.make_new_save(456)
	var b := SaveSchema.make_new_save(456)
	var opts_a := OnboardingService.build_fragment_options(a, cfg)
	var opts_b := OnboardingService.build_fragment_options(b, cfg)
	if JSON.stringify(opts_a) != JSON.stringify(opts_b):
		return { "ok": false, "error": "Expected deterministic fragment options" }
	if opts_a.size() != 3:
		return { "ok": false, "error": "Expected 3 fragment options, got %d" % opts_a.size() }
	return { "ok": true }

static func _t_hear_select_updates_snapshot() -> Dictionary:
	var runtime := _make_runtime()
	runtime.call("_handle_new_game", 2)
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	var virtue := str(frag.get("virtue", ""))
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_CHOOSE_NAME, runtime.flow_ctx, runtime.logger, 3, "test")
	runtime.call("_handle_onboarding_fragment_hear", { "virtue": virtue }, 4)
	runtime.call("_handle_onboarding_fragment_select", { "virtue": virtue }, 5)
	var data: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	if not virtue in (data.get("heard_fragments", []) as Array):
		return { "ok": false, "error": "Expected heard fragment in snapshot" }
	if str(data.get("selected_fragment", "")) != virtue:
		return { "ok": false, "error": "Expected selected fragment %s" % virtue }
	return { "ok": true }

static func _t_confirm_fragment_creates_one_starter() -> Dictionary:
	var runtime := _make_runtime()
	runtime.call("_handle_new_game", 2)
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(frag.get("virtue", "")))
	runtime.call("_handle_onboarding_fragment_confirm", 3)
	var roster: Array = runtime.flow_ctx.save_data.get("sanctum", {}).get("roster", [])
	if roster.size() != 1:
		return { "ok": false, "error": "Expected exactly one starter Echo, got %d" % roster.size() }
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.ONBOARDING_MEETING:
		return { "ok": false, "error": "Expected meeting snapshot after confirm" }
	return { "ok": true }

static func _t_starter_virtue_matches() -> Dictionary:
	var runtime := _make_runtime()
	runtime.call("_handle_new_game", 2)
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	var virtue := str(frag.get("virtue", ""))
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, virtue)
	runtime.call("_handle_onboarding_fragment_confirm", 3)
	var echo: Dictionary = OnboardingService.get_starter_echo(runtime.flow_ctx.save_data)
	var dominant := str(echo.get("dominant_vector", ""))
	var mapped := str(OnboardingService.get_vector_to_virtue(cfg).get(dominant, ""))
	if mapped != virtue:
		return { "ok": false, "error": "Expected dominant virtue %s, got %s via %s" % [virtue, mapped, dominant] }
	return { "ok": true }

static func _t_name_confirm_completes() -> Dictionary:
	var runtime := _make_runtime()
	runtime.call("_handle_new_game", 2)
	OnboardingService.set_step(runtime.flow_ctx.save_data, runtime.config_service.get_balance(), OnboardingService.STEP_NAME_SANCTUM)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_NAME_SANCTUM, runtime.flow_ctx, runtime.logger, 3, "test")
	runtime.call("_handle_onboarding_name_confirm", { "name": "House Test" }, 4)
	if str(runtime.flow_ctx.save_data.get("sanctum", {}).get("name", "")) != "House Test":
		return { "ok": false, "error": "Expected sanctum name saved" }
	if not OnboardingService.is_chapter_one_complete(runtime.flow_ctx.save_data):
		return { "ok": false, "error": "Expected Chapter I complete" }
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.SANCTUM:
		return { "ok": false, "error": "Expected Sanctum route after name confirm" }
	return { "ok": true }

static func _t_continue_resume_logic() -> Dictionary:
	var cfg := _cfg()
	var save := SaveSchema.make_new_save(789)
	OnboardingService.set_step(save, cfg, OnboardingService.STEP_MEETING)
	var step := OnboardingService.current_step(save, cfg)
	if OnboardingService.step_to_flow_id(step) != FlowStateIds.ONBOARDING_MEETING:
		return { "ok": false, "error": "Expected incomplete onboarding to resume meeting" }
	OnboardingService.mark_complete(save, cfg)
	if not OnboardingService.is_chapter_one_complete(save):
		return { "ok": false, "error": "Expected completed onboarding to skip resume" }
	return { "ok": true }

static func _t_starter_layout_has_thirteen_tiles() -> Dictionary:
	var save := SaveSchema.make_new_save(321)
	var layout := SanctumLayoutService.snapshot_layout(save)
	var tiles: Array = layout.get("tiles", [])
	if tiles.size() != 13:
		return { "ok": false, "error": "Expected 13 starter diamond tiles, got %d" % tiles.size() }
	return { "ok": true }

static func _t_starter_layout_is_diamond() -> Dictionary:
	var save := SaveSchema.make_new_save(322)
	var layout := SanctumLayoutService.snapshot_layout(save)
	var tiles: Array = layout.get("tiles", [])
	var row_counts: Dictionary = {}
	for tile_v in tiles:
		if not (tile_v is Dictionary):
			continue
		var tile: Dictionary = tile_v
		var y := int(tile.get("y", 0))
		row_counts[y] = int(row_counts.get(y, 0)) + 1
	var expected := { -2: 1, -1: 3, 0: 5, 1: 3, 2: 1 }
	if JSON.stringify(row_counts) != JSON.stringify(expected):
		return { "ok": false, "error": "Expected diamond row counts %s, got %s" % [JSON.stringify(expected), JSON.stringify(row_counts)] }
	return { "ok": true }

static func _t_starter_occupant_centered() -> Dictionary:
	var runtime := _make_runtime()
	runtime.call("_handle_new_game", 2)
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(frag.get("virtue", "")))
	runtime.call("_handle_onboarding_fragment_confirm", 3)
	var occupants: Array = SanctumLayoutService.snapshot_occupants(runtime.flow_ctx.save_data)
	if occupants.size() != 1:
		return { "ok": false, "error": "Expected one starter occupant, got %d" % occupants.size() }
	var occupant: Dictionary = occupants[0]
	if int(occupant.get("x", 99)) != 0 or int(occupant.get("y", 99)) != 0:
		return { "ok": false, "error": "Expected occupant at center, got %s,%s" % [str(occupant.get("x", "?")), str(occupant.get("y", "?"))] }
	return { "ok": true }

static func _t_missing_layout_repairs() -> Dictionary:
	var save := SaveSchema.make_new_save(654)
	var sanctum: Dictionary = save["sanctum"]
	sanctum.erase("layout")
	var repaired := SaveService._apply_additive_defaults_and_repairs(save)
	if not repaired:
		return { "ok": false, "error": "Expected missing layout repair to report repaired" }
	var layout: Dictionary = save.get("sanctum", {}).get("layout", {})
	var tiles: Array = layout.get("tiles", [])
	if tiles.size() != 13:
		return { "ok": false, "error": "Expected repaired layout with 13 diamond tiles, got %d" % tiles.size() }
	return { "ok": true }

static func _t_sanctum_snapshots_share_layout() -> Dictionary:
	var runtime := _make_runtime()
	runtime.call("_handle_new_game", 2)
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(frag.get("virtue", "")))
	runtime.call("_handle_onboarding_fragment_confirm", 3)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_EMPTY_SANCTUM)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_EMPTY_SANCTUM, runtime.flow_ctx, runtime.logger, 4, "test")
	var encounter_data: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	var encounter_layout := JSON.stringify(encounter_data.get("sanctum_layout", {}))
	var encounter_occupants := JSON.stringify(encounter_data.get("sanctum_occupants", []))
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_NAME_SANCTUM)
	runtime.call("_handle_onboarding_name_confirm", { "name": "House Test" }, 5)
	var hub_data: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	if JSON.stringify(hub_data.get("sanctum_layout", {})) != encounter_layout:
		return { "ok": false, "error": "Expected encounter and hub layouts to match" }
	if JSON.stringify(hub_data.get("sanctum_occupants", [])) != encounter_occupants:
		return { "ok": false, "error": "Expected encounter and hub occupants to match" }
	return { "ok": true }
