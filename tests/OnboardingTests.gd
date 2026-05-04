class_name OnboardingTests
extends RefCounted

const KeeperIntroServiceScript := preload("res://core/onboarding/KeeperIntroService.gd")

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("onboarding/start_routes_to_invocation", Callable(OnboardingTests, "_t_start_routes_to_invocation"))
	runner.register_test("onboarding/fragments_are_seed_deterministic", Callable(OnboardingTests, "_t_fragments_are_seed_deterministic"))
	runner.register_test("onboarding/hear_and_select_updates_snapshot_data", Callable(OnboardingTests, "_t_hear_select_updates_snapshot"))
	runner.register_test("onboarding/confirm_fragment_creates_one_starter", Callable(OnboardingTests, "_t_confirm_fragment_creates_one_starter"))
	runner.register_test("onboarding/starter_dominant_virtue_matches_fragment", Callable(OnboardingTests, "_t_starter_virtue_matches"))
	runner.register_test("onboarding/name_confirm_completes_and_routes_keeper_intro", Callable(OnboardingTests, "_t_name_confirm_completes"))
	runner.register_test("onboarding/keeper_call_assigns_starter_party", Callable(OnboardingTests, "_t_keeper_call_assigns_party"))
	runner.register_test("onboarding/keeper_trial_uses_real_combat", Callable(OnboardingTests, "_t_keeper_trial_real_combat"))
	runner.register_test("onboarding/keeper_trial_rewind_restarts_debuffed", Callable(OnboardingTests, "_t_keeper_trial_rewind_restarts_debuffed"))
	runner.register_test("onboarding/keeper_trial_returns_rewards", Callable(OnboardingTests, "_t_keeper_trial_rewards"))
	runner.register_test("onboarding/awakening_starts_flame_and_emotion", Callable(OnboardingTests, "_t_awakening_starts_flame"))
	runner.register_test("onboarding/first_weave_consumes_thread_and_grows_echo", Callable(OnboardingTests, "_t_first_weave_growth"))
	runner.register_test("onboarding/keeper_complete_unlocks_sanctum", Callable(OnboardingTests, "_t_keeper_complete_unlocks_sanctum"))
	runner.register_test("onboarding/continue_resume_incomplete_skip_complete", Callable(OnboardingTests, "_t_continue_resume_logic"))
	runner.register_test("onboarding/starter_layout_has_nine_tiles", Callable(OnboardingTests, "_t_starter_layout_has_nine_tiles"))
	runner.register_test("onboarding/starter_layout_is_centered_3x3", Callable(OnboardingTests, "_t_starter_layout_is_centered_3x3"))
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
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.KEEPER_CALL:
		return { "ok": false, "error": "Expected Keeper intro route after name confirm" }
	return { "ok": true }

static func _prepare_named_runtime() -> FlowRuntime:
	var runtime := _make_runtime()
	runtime.call("_handle_new_game", 2)
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(frag.get("virtue", "")))
	runtime.call("_handle_onboarding_fragment_confirm", 3)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_NAME_SANCTUM)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_NAME_SANCTUM, runtime.flow_ctx, runtime.logger, 4, "test")
	runtime.call("_handle_onboarding_name_confirm", { "name": "House Test" }, 5)
	return runtime

static func _defeat_trial_wound(runtime: FlowRuntime) -> void:
	if runtime.flow_ctx.encounter_ctx == null:
		return
	for actor_v in runtime.flow_ctx.encounter_ctx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("faction", "")) == "enemy":
			actor["current_hp"] = 0
			actor["is_dead"] = true
			return

static func _t_keeper_call_assigns_party() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.call("_handle_keeper_intro_call_answer", 6)
	var sanctum: Dictionary = runtime.flow_ctx.save_data.get("sanctum", {})
	var active: Array = sanctum.get("active_party_ids", [])
	var echo: Dictionary = OnboardingService.get_starter_echo(runtime.flow_ctx.save_data)
	if not str(echo.get("id", "")) in active:
		return { "ok": false, "error": "Expected starter Echo in active_party_ids" }
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.KEEPER_TRIAL:
		return { "ok": false, "error": "Expected Keeper trial snapshot" }
	var data: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	if int(data.get("board_cols", 0)) != 5 or int(data.get("board_rows", 0)) != 5:
		return { "ok": false, "error": "Expected 5x5 keeper trial board" }
	return { "ok": true }

static func _t_keeper_trial_real_combat() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.call("_handle_keeper_intro_call_answer", 6)
	var snap: Dictionary = runtime.flow_ctx.last_snapshot
	var data: Dictionary = snap.get("data", {})
	var actions: Dictionary = snap.get("actions", {})
	if not actions.has("cta.combat_init"):
		return { "ok": false, "error": "Expected real combat.init action for Keeper trial" }
	var actors: Array = data.get("actors", [])
	if actors.size() != 2:
		return { "ok": false, "error": "Expected starter Echo plus Fragment Wound actors" }
	var echo_pos: Dictionary = actors[0].get("grid_pos", {})
	var wound_pos: Dictionary = actors[1].get("grid_pos", {})
	if int(echo_pos.get("col", -1)) != 0 or int(echo_pos.get("row", -1)) != 2:
		return { "ok": false, "error": "Expected Echo at left center of 5x5 trial" }
	if int(wound_pos.get("col", -1)) != 4 or int(wound_pos.get("row", -1)) != 2:
		return { "ok": false, "error": "Expected Fragment Wound at right center of 5x5 trial" }
	if str(actors[0].get("bark_line", "")).is_empty():
		return { "ok": false, "error": "Expected starter Echo battle bark" }
	if data.has("directive"):
		return { "ok": false, "error": "First trial should not teach normal run directives" }
	return { "ok": true }

static func _t_keeper_trial_rewind_restarts_debuffed() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.call("_handle_keeper_intro_call_answer", 6)
	var lethal_ids: Array[String] = ["echo_0001"]
	runtime.call("_handle_keeper_intro_trial_rewind", 7, lethal_ids)
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.KEEPER_REWIND:
		return { "ok": false, "error": "Expected Anansi rewind screen after lethal first trial hit" }
	var onboarding: Dictionary = runtime.flow_ctx.save_data.get("onboarding", {})
	if not bool(onboarding.get("keeper_trial_rewind_used", false)):
		return { "ok": false, "error": "Expected rewind_used saved" }
	runtime.call("_handle_keeper_intro_rewind_continue", 8)
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.KEEPER_TRIAL:
		return { "ok": false, "error": "Expected trial to restart after rewind exposition" }
	var actors: Array = runtime.flow_ctx.last_snapshot.get("data", {}).get("actors", [])
	if actors.size() != 2:
		return { "ok": false, "error": "Expected restarted Echo plus Wound" }
	var wound: Dictionary = actors[1]
	if int(wound.get("max_hp", 0)) >= 28:
		return { "ok": false, "error": "Expected rewound Wound max_hp debuffed" }
	return { "ok": true }

static func _t_keeper_trial_rewards() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.call("_handle_keeper_intro_call_answer", 6)
	_defeat_trial_wound(runtime)
	runtime.call("_handle_keeper_intro_trial_finish", 7)
	var econ: Dictionary = runtime.flow_ctx.save_data.get("economy", {})
	if int(econ.get("ase", 0)) != 40:
		return { "ok": false, "error": "Expected 40 Ase after first trial, got %d" % int(econ.get("ase", 0)) }
	var sanctum: Dictionary = runtime.flow_ctx.save_data.get("sanctum", {})
	var threads: Dictionary = sanctum.get("threads", {})
	if not threads.has(KeeperIntroServiceScript.FIRST_THREAD_ID):
		return { "ok": false, "error": "Expected First Thread in reserve" }
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.KEEPER_THREAD_RETURN:
		return { "ok": false, "error": "Expected thread return route" }
	return { "ok": true }

static func _t_awakening_starts_flame() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.call("_handle_keeper_intro_call_answer", 6)
	_defeat_trial_wound(runtime)
	runtime.call("_handle_keeper_intro_trial_finish", 7)
	runtime.call("_handle_keeper_intro_thread_continue", 8)
	var echo_before: Dictionary = OnboardingService.get_starter_echo(runtime.flow_ctx.save_data)
	var emo_before := EmotionService.get_emotion(echo_before)
	var morale_before := int(emo_before.get("morale_current", 50))
	var fear_before := int(emo_before.get("fear_current", 0))
	runtime.call("_handle_keeper_intro_awakening", { "choice": "guard" }, 9)
	var sanctum: Dictionary = runtime.flow_ctx.save_data.get("sanctum", {})
	var flame: Dictionary = sanctum.get("ase_flame", {})
	if not bool(flame.get("awakened", false)):
		return { "ok": false, "error": "Expected Ase flame awakened" }
	if int(flame.get("boost_remaining_seconds", 0)) != 600:
		return { "ok": false, "error": "Expected 600s boost remaining" }
	var echo_after: Dictionary = OnboardingService.get_starter_echo(runtime.flow_ctx.save_data)
	var emo_after := EmotionService.get_emotion(echo_after)
	if int(emo_after.get("morale_current", 50)) != morale_before + 1:
		return { "ok": false, "error": "Expected guard vow morale +1" }
	if int(emo_after.get("fear_current", 0)) != maxi(0, fear_before - 2):
		return { "ok": false, "error": "Expected guard vow fear -2 clamped" }
	return { "ok": true }

static func _t_first_weave_growth() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.call("_handle_keeper_intro_call_answer", 6)
	_defeat_trial_wound(runtime)
	runtime.call("_handle_keeper_intro_trial_finish", 7)
	runtime.call("_handle_keeper_intro_thread_continue", 8)
	runtime.call("_handle_keeper_intro_awakening", { "choice": "guard" }, 9)
	var cfg := runtime.config_service.get_balance()
	var vector := KeeperIntroServiceScript.get_selected_vector(runtime.flow_ctx.save_data, cfg)
	var echo_before: Dictionary = OnboardingService.get_starter_echo(runtime.flow_ctx.save_data)
	var story_before := int(echo_before.get("storyweight", 0))
	var vector_before := int(echo_before.get("vector_scores", {}).get(vector, 0))
	runtime.call("_handle_keeper_intro_weave", 10)
	var sanctum: Dictionary = runtime.flow_ctx.save_data.get("sanctum", {})
	var threads: Dictionary = sanctum.get("threads", {})
	if threads.has(KeeperIntroServiceScript.FIRST_THREAD_ID):
		return { "ok": false, "error": "Expected First Thread consumed by weave" }
	var echo_after: Dictionary = OnboardingService.get_starter_echo(runtime.flow_ctx.save_data)
	var woven: Array = echo_after.get("woven_threads", [])
	if woven.is_empty():
		return { "ok": false, "error": "Expected woven thread on starter Echo" }
	if int(echo_after.get("storyweight", 0)) != story_before + 10:
		return { "ok": false, "error": "Expected +10 Storyweight" }
	if int(echo_after.get("vector_scores", {}).get(vector, 0)) != vector_before + 1:
		return { "ok": false, "error": "Expected selected virtue vector +1" }
	return { "ok": true }

static func _t_keeper_complete_unlocks_sanctum() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.call("_handle_keeper_intro_complete", 6)
	if not KeeperIntroServiceScript.is_complete(runtime.flow_ctx.save_data):
		return { "ok": false, "error": "Expected keeper intro complete" }
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.SANCTUM:
		return { "ok": false, "error": "Expected Sanctum after Into the Keeping" }
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

static func _t_starter_layout_has_nine_tiles() -> Dictionary:
	var save := SaveSchema.make_new_save(321)
	var layout := SanctumLayoutService.snapshot_layout(save)
	var tiles: Array = layout.get("tiles", [])
	if tiles.size() != 9:
		return { "ok": false, "error": "Expected nine starter Sanctum tiles, got %d" % tiles.size() }
	return { "ok": true }

static func _t_starter_layout_is_centered_3x3() -> Dictionary:
	var save := SaveSchema.make_new_save(322)
	var layout := SanctumLayoutService.snapshot_layout(save)
	var tiles: Array = layout.get("tiles", [])
	var cells := {}
	for tile_v in tiles:
		if not (tile_v is Dictionary):
			return { "ok": false, "error": "Expected layout tile dictionaries" }
		var tile: Dictionary = tile_v
		cells["%d,%d" % [int(tile.get("x", 99)), int(tile.get("y", 99))]] = true
	for y in range(-1, 2):
		for x in range(-1, 2):
			var key := "%d,%d" % [x, y]
			if not cells.has(key):
				return { "ok": false, "error": "Expected centered 3x3 layout to include %s" % key }
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
	if tiles.size() != 9:
		return { "ok": false, "error": "Expected repaired layout with nine 3x3 starter tiles, got %d" % tiles.size() }
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
	runtime.call("_handle_keeper_intro_complete", 6)
	var hub_data: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	if JSON.stringify(hub_data.get("sanctum_layout", {})) != encounter_layout:
		return { "ok": false, "error": "Expected encounter and hub layouts to match" }
	if JSON.stringify(hub_data.get("sanctum_occupants", [])) != encounter_occupants:
		return { "ok": false, "error": "Expected encounter and hub occupants to match" }
	return { "ok": true }
