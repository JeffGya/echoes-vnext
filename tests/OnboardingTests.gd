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
	runner.register_test("onboarding/keeper_trial_victory_routes_resolve", Callable(OnboardingTests, "_t_keeper_trial_victory_routes_resolve"))
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
	# V2-INFRA-003 Phase 8C — the opening proof spine.
	runner.register_test("onboarding/flame_lights_at_awakening_and_arms_modal", Callable(OnboardingTests, "_t_flame_lights_at_awakening_and_arms_modal"))
	runner.register_test("onboarding/awakening_modal_shows_once_on_first_sanctum", Callable(OnboardingTests, "_t_awakening_modal_shows_once_on_first_sanctum"))
	runner.register_test("onboarding/opening_realm_opens_after_awakening_and_weave", Callable(OnboardingTests, "_t_opening_realm_opens_after_awakening_and_weave"))
	runner.register_test("onboarding/normal_realms_locked_until_prologue_complete", Callable(OnboardingTests, "_t_normal_realms_locked_until_prologue_complete"))
	runner.register_test("onboarding/prologue_does_not_inflate_first_realm_run_index", Callable(OnboardingTests, "_t_prologue_does_not_inflate_first_realm_run_index"))
	runner.register_test("onboarding/prologue_pays_exactly_one_thread", Callable(OnboardingTests, "_t_prologue_pays_exactly_one_thread"))

static func _make_logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	return logger

static func _make_runtime() -> FlowRuntime:
	var logger := _make_logger()
	var config := ConfigService.new()
	config.load_balance(logger, 0)
	# V2-INFRA-003 Phase 8C: realms.json too. This harness builds its FlowRuntime by hand and so
	# skips FlowRuntime.boot(), which is where load_realms() normally runs — leaving get_realms()
	# empty. Harmless until the keeper intro started opening the prologue Realm at its end.
	config.load_realms(logger, 0)
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.dir() + "onboarding_slot.json")
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
	runtime.dispatch({ "type": "flow.new_game" })
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
	runtime.dispatch({ "type": "flow.new_game" })
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	var virtue := str(frag.get("virtue", ""))
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_CHOOSE_NAME, runtime.flow_ctx, runtime.logger, 3, "test")
	runtime.dispatch({ "type": "onboarding.fragment.hear", "virtue": virtue })
	runtime.dispatch({ "type": "onboarding.fragment.select", "virtue": virtue })
	var data: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	if not virtue in (data.get("heard_fragments", []) as Array):
		return { "ok": false, "error": "Expected heard fragment in snapshot" }
	if str(data.get("selected_fragment", "")) != virtue:
		return { "ok": false, "error": "Expected selected fragment %s" % virtue }
	return { "ok": true }

static func _t_confirm_fragment_creates_one_starter() -> Dictionary:
	var runtime := _make_runtime()
	runtime.dispatch({ "type": "flow.new_game" })
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(frag.get("virtue", "")))
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })
	var roster: Array = runtime.flow_ctx.save_data.get("sanctum", {}).get("roster", [])
	if roster.size() != 1:
		return { "ok": false, "error": "Expected exactly one starter Echo, got %d" % roster.size() }
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.ONBOARDING_MEETING:
		return { "ok": false, "error": "Expected meeting snapshot after confirm" }
	return { "ok": true }

static func _t_starter_virtue_matches() -> Dictionary:
	var runtime := _make_runtime()
	runtime.dispatch({ "type": "flow.new_game" })
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	var virtue := str(frag.get("virtue", ""))
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, virtue)
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })
	var echo: Dictionary = OnboardingService.get_starter_echo(runtime.flow_ctx.save_data)
	var dominant := str(echo.get("dominant_vector", ""))
	var mapped := str(OnboardingService.get_vector_to_virtue(cfg).get(dominant, ""))
	if mapped != virtue:
		return { "ok": false, "error": "Expected dominant virtue %s, got %s via %s" % [virtue, mapped, dominant] }
	return { "ok": true }

static func _t_name_confirm_completes() -> Dictionary:
	var runtime := _make_runtime()
	runtime.dispatch({ "type": "flow.new_game" })
	OnboardingService.set_step(runtime.flow_ctx.save_data, runtime.config_service.get_balance(), OnboardingService.STEP_NAME_SANCTUM)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_NAME_SANCTUM, runtime.flow_ctx, runtime.logger, 3, "test")
	runtime.dispatch({ "type": "onboarding.name.confirm", "name": "House Test" })
	if str(runtime.flow_ctx.save_data.get("sanctum", {}).get("name", "")) != "House Test":
		return { "ok": false, "error": "Expected sanctum name saved" }
	if not OnboardingService.is_chapter_one_complete(runtime.flow_ctx.save_data):
		return { "ok": false, "error": "Expected Chapter I complete" }
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.KEEPER_CALL:
		return { "ok": false, "error": "Expected Keeper intro route after name confirm" }
	return { "ok": true }

static func _prepare_named_runtime() -> FlowRuntime:
	var runtime := _make_runtime()
	runtime.dispatch({ "type": "flow.new_game" })
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(frag.get("virtue", "")))
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_NAME_SANCTUM)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_NAME_SANCTUM, runtime.flow_ctx, runtime.logger, 4, "test")
	runtime.dispatch({ "type": "onboarding.name.confirm", "name": "House Test" })
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
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
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
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
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
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	var lethal_ids: Array[String] = ["echo_0001"]
	# V2-INFRA-003 Phase 4 Slice 9: _handle_keeper_intro_trial_rewind moved to
	# KeeperIntroService.apply_trial_rewind() (a service, so it does not transition itself —
	# see that function's header note). This reflection call site (the one dispatch route with
	# no action reaching this method, per the story brief) is rewritten to call the service
	# directly and then perform the same KEEPER_REWIND transition FlowRuntime's combat-path
	# caller (_resolve_next_actor) performs immediately afterward.
	KeeperIntroServiceScript.apply_trial_rewind(runtime.flow_ctx, runtime.config_service.get_balance(), runtime.logger, 7, lethal_ids)
	runtime.flow_machine.transition(FlowStateIds.KEEPER_REWIND, runtime.flow_ctx, runtime.logger, 7, "keeper_intro.trial.rewind")
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.KEEPER_REWIND:
		return { "ok": false, "error": "Expected Anansi rewind screen after lethal first trial hit" }
	var onboarding: Dictionary = runtime.flow_ctx.save_data.get("onboarding", {})
	if not bool(onboarding.get("keeper_trial_rewind_used", false)):
		return { "ok": false, "error": "Expected rewind_used saved" }
	runtime.dispatch({ "type": "keeper_intro.rewind.continue" })
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.KEEPER_TRIAL:
		return { "ok": false, "error": "Expected trial to restart after rewind exposition" }
	var actors: Array = runtime.flow_ctx.last_snapshot.get("data", {}).get("actors", [])
	if actors.size() != 2:
		return { "ok": false, "error": "Expected restarted Echo plus Wound" }
	var wound: Dictionary = actors[1]
	if int(wound.get("max_hp", 0)) >= 28:
		return { "ok": false, "error": "Expected rewound Wound max_hp debuffed" }
	return { "ok": true }

static func _t_keeper_trial_victory_routes_resolve() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	_defeat_trial_wound(runtime)
	var result := {
		"victory": true,
		"reason": "all_enemies_defeated",
		"round_ended": 1,
	}
	runtime.flow_ctx.encounter_ctx.combat_result = result
	runtime.flow_ctx.encounter_ctx.combat_state["combat_over"] = true
	runtime.flow_ctx.last_snapshot = FlowEncounterState.build_final_snapshot(runtime.flow_ctx, 7)
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.RESOLVE:
		return { "ok": false, "error": "Expected first trial to use normal resolve snapshot" }
	var data: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	var actors: Array = data.get("actors", [])
	var echo_count := 0
	for actor_v in actors:
		if actor_v is Dictionary and str((actor_v as Dictionary).get("faction", "")) == "echo":
			echo_count += 1
	if echo_count != 1:
		return { "ok": false, "error": "Expected resolve actors to include starter Echo for EchoBar" }
	var actions: Dictionary = runtime.flow_ctx.last_snapshot.get("actions", {})
	var continue_action: Dictionary = actions.get("cta.continue", {})
	if str(continue_action.get("type", "")) != "keeper_intro.trial.finish":
		return { "ok": false, "error": "Expected resolve continue to enter thread return beat" }

	# V2-INFRA-003 / defect register D73 — pins the keeper trial's OMISSION of ekwan_awarded.
	# This asymmetry (it sets ase_awarded but not ekwan_awarded) is the entire reason `ekwan` is
	# block #8 of ResolveSnapshotBuilder rather than a flag on `ledger`. It was expressed only as
	# the ABSENCE of an add_ekwan() call, which nothing could catch. Producer A (combat) does set
	# it, so a future "tidy-up" that adds the block here would look harmless and would silently
	# make block #8 pointless.
	if data.has("ekwan_awarded"):
		return { "ok": false, "error": "Keeper trial resolve must NOT carry ekwan_awarded (register D73); got %s" % str(data.get("ekwan_awarded")) }
	if not data.has("ase_awarded"):
		return { "ok": false, "error": "Keeper trial resolve must carry ase_awarded (register D73)" }
	return { "ok": true }

static func _t_keeper_trial_rewards() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	_defeat_trial_wound(runtime)
	runtime.dispatch({ "type": "keeper_intro.trial.finish" })
	var econ: Dictionary = runtime.flow_ctx.save_data.get("economy", {})
	if int(econ.get("ase", 0)) != 40:
		return { "ok": false, "error": "Expected 40 Ase after first trial, got %d" % int(econ.get("ase", 0)) }
	var sanctum: Dictionary = runtime.flow_ctx.save_data.get("sanctum", {})
	var threads: Dictionary = sanctum.get("threads", {})
	if not threads.has(KeeperIntroServiceScript.FIRST_THREAD_ID):
		return { "ok": false, "error": "Expected First Thread in reserve" }
	var prologue_count := 0
	for thread_id_v in threads.keys():
		if str(thread_id_v).begins_with("thread.prologue.first."):
			prologue_count += 1
	if prologue_count != 1:
		return { "ok": false, "error": "Expected exactly one prologue First Thread, got %d" % prologue_count }
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.KEEPER_THREAD_RETURN:
		return { "ok": false, "error": "Expected thread return route" }
	return { "ok": true }

static func _t_awakening_starts_flame() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	_defeat_trial_wound(runtime)
	runtime.dispatch({ "type": "keeper_intro.trial.finish" })
	runtime.dispatch({ "type": "keeper_intro.thread.continue" })
	var echo_before: Dictionary = OnboardingService.get_starter_echo(runtime.flow_ctx.save_data)
	var emo_before := EmotionService.get_emotion(echo_before)
	var morale_before := int(emo_before.get("morale_current", 50))
	var fear_before := int(emo_before.get("fear_current", 0))
	runtime.dispatch({ "type": "keeper_intro.awakening.choose", "choice": "guard" })
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
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	_defeat_trial_wound(runtime)
	runtime.dispatch({ "type": "keeper_intro.trial.finish" })
	runtime.dispatch({ "type": "keeper_intro.thread.continue" })
	runtime.dispatch({ "type": "keeper_intro.awakening.choose", "choice": "guard" })
	var cfg := runtime.config_service.get_balance()
	var vector := KeeperIntroServiceScript.get_selected_vector(runtime.flow_ctx.save_data, cfg)
	var echo_before: Dictionary = OnboardingService.get_starter_echo(runtime.flow_ctx.save_data)
	var story_before := int(echo_before.get("storyweight", 0))
	var vector_before := int(echo_before.get("vector_scores", {}).get(vector, 0))
	runtime.dispatch({ "type": "keeper_intro.weave.complete" })
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
	runtime.dispatch({ "type": "keeper_intro.complete" })
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
	# Layout is now 5×5 main (25) + 3×3 party staging (9) + 1 ase_flame = 35
	if tiles.size() != 35:
		return { "ok": false, "error": "Expected 35 starter Sanctum tiles, got %d" % tiles.size() }
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
	runtime.dispatch({ "type": "flow.new_game" })
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(frag.get("virtue", "")))
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })
	var occupants: Array = SanctumLayoutService.snapshot_occupants(runtime.flow_ctx.save_data)
	# ase_flame is always the first occupant; echo is placed after it.
	if occupants.size() < 2:
		return { "ok": false, "error": "Expected ase_flame + at least one echo occupant, got %d" % occupants.size() }
	var echo_occupant: Dictionary = {}
	for occ_v in occupants:
		if not (occ_v is Dictionary):
			continue
		var occ: Dictionary = occ_v
		if str(occ.get("kind", "")) != "ase_flame" and str(occ.get("kind", "")) != "institution":
			echo_occupant = occ
			break
	if echo_occupant.is_empty():
		return { "ok": false, "error": "Expected an echo occupant after fragment confirm" }
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
	# 34 floor tiles plus the permanent Ase Flame tile at the origin.
	if tiles.size() != 35:
		return { "ok": false, "error": "Expected repaired layout with 35 tiles, got %d" % tiles.size() }
	return { "ok": true }

static func _t_sanctum_snapshots_share_layout() -> Dictionary:
	var runtime := _make_runtime()
	runtime.dispatch({ "type": "flow.new_game" })
	var cfg := runtime.config_service.get_balance()
	var frag := _first_fragment(runtime.flow_ctx.save_data, cfg)
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_CHOOSE_NAME)
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(frag.get("virtue", "")))
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_EMPTY_SANCTUM)
	runtime.flow_machine.transition(FlowStateIds.ONBOARDING_EMPTY_SANCTUM, runtime.flow_ctx, runtime.logger, 4, "test")
	var encounter_data: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	var encounter_layout := JSON.stringify(encounter_data.get("sanctum_layout", {}))
	var encounter_occupants := JSON.stringify(encounter_data.get("sanctum_occupants", []))
	OnboardingService.set_step(runtime.flow_ctx.save_data, cfg, OnboardingService.STEP_NAME_SANCTUM)
	runtime.dispatch({ "type": "onboarding.name.confirm", "name": "House Test" })
	runtime.dispatch({ "type": "keeper_intro.complete" })
	var hub_data: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	if JSON.stringify(hub_data.get("sanctum_layout", {})) != encounter_layout:
		return { "ok": false, "error": "Expected encounter and hub layouts to match" }
	if JSON.stringify(hub_data.get("sanctum_occupants", [])) != encounter_occupants:
		return { "ok": false, "error": "Expected encounter and hub occupants to match" }
	return { "ok": true }


# ═════════════════════════════════════════════════════════════════════════════════════════════
# V2-INFRA-003 Phase 8C — THE OPENING PROOF SPINE
#
# These drive the real dispatch chain, never hand-injected save state, and assert the four
# claims the slice exists to make:
#   1. the Ase Flame lights at the awakening rite and NOT at the end of Chapter I (D42 / D63)
#   2. the awakening modal is armed there and spent by the first Sanctum snapshot
#   3. the opening Realm opens from awakening + first Weave, as one real generated Stage built
#      around the player's own starter virtue
#   4. it stays invisible to everything that measures how far into the game the player is —
#      Realm Select, the Realm locks, and above all `run_index`
# ═════════════════════════════════════════════════════════════════════════════════════════════

## Drives the whole keeper intro to the Sanctum. Returns the runtime, parked on flow.sanctum with
## the prologue Realm open.
static func _run_full_keeper_intro() -> FlowRuntime:
	var runtime := _prepare_named_runtime()
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	_defeat_trial_wound(runtime)
	runtime.dispatch({ "type": "keeper_intro.trial.finish" })
	runtime.dispatch({ "type": "keeper_intro.thread.continue" })
	runtime.dispatch({ "type": "keeper_intro.awakening.choose", "choice": "guard" })
	runtime.dispatch({ "type": "keeper_intro.weave.complete" })
	runtime.dispatch({ "type": "keeper_intro.complete" })
	return runtime


static func _prologue_entry(runtime: FlowRuntime) -> Dictionary:
	var realms_v: Variant = runtime.flow_ctx.save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	var e_v: Variant = realms.get(RealmService.PROLOGUE_REALM_ID, {})
	return e_v if e_v is Dictionary else {}


## Step 4 of the first session: the Flame lights at the awakening, not a chapter earlier, and the
## one-shot modal flag is armed with it. The dark half is pinned by economy/name_confirm_leaves_flame_dark.
static func _t_flame_lights_at_awakening_and_arms_modal() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	_defeat_trial_wound(runtime)
	runtime.dispatch({ "type": "keeper_intro.trial.finish" })
	runtime.dispatch({ "type": "keeper_intro.thread.continue" })
	if KeeperIntroServiceScript.is_ase_flame_awakened(runtime.flow_ctx.save_data):
		return { "ok": false, "error": "Flame must still be dark on the Thread Return step" }
	if runtime.flow_ctx.pending_awakening_banner:
		return { "ok": false, "error": "Awakening modal must not be armed before the awakening" }
	runtime.dispatch({ "type": "keeper_intro.awakening.choose", "choice": "guard" })
	if not KeeperIntroServiceScript.is_ase_flame_awakened(runtime.flow_ctx.save_data):
		return { "ok": false, "error": "Flame must be lit by the awakening rite" }
	if not runtime.flow_ctx.pending_awakening_banner:
		return { "ok": false, "error": "Awakening modal must be armed at the awakening rite" }
	return { "ok": true }


## The modal survives the two intervening dispatches, reaches the first Sanctum snapshot, and is
## spent there — the established one-shot contract, exercised for the first time.
static func _t_awakening_modal_shows_once_on_first_sanctum() -> Dictionary:
	var runtime := _run_full_keeper_intro()
	var snap: Dictionary = runtime.flow_ctx.last_snapshot
	if str(snap.get("type", "")) != FlowStateIds.SANCTUM:
		return { "ok": false, "error": "Expected Sanctum after keeper_intro.complete" }
	var data: Dictionary = snap.get("data", {})
	if not bool(data.get("show_awakening_overlay", false)):
		return { "ok": false, "error": "First Sanctum snapshot must carry show_awakening_overlay" }
	if runtime.flow_ctx.pending_awakening_banner:
		return { "ok": false, "error": "Awakening flag must be consumed after the Sanctum snapshot is published" }
	# And exactly once: leave Sanctum and come back, so a genuinely NEW Sanctum snapshot is built
	# (re-entering the state you are already in does not rebuild one).
	runtime.dispatch({ "type": "flow.go_state", "to": FlowStateIds.ECHO_PARTY })
	runtime.dispatch({ "type": "flow.go_state", "to": FlowStateIds.SANCTUM })
	var data2: Dictionary = runtime.flow_ctx.last_snapshot.get("data", {})
	if bool(data2.get("show_awakening_overlay", false)):
		return { "ok": false, "error": "Awakening overlay must show exactly once" }
	return { "ok": true }


## Step 6: the opening Realm opens, unlocked by awakening + rite, as ONE real generated Stage
## carrying the player's own starter virtue — and the Sanctum offers a way into it.
static func _t_opening_realm_opens_after_awakening_and_weave() -> Dictionary:
	var runtime := _prepare_named_runtime()
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	_defeat_trial_wound(runtime)
	runtime.dispatch({ "type": "keeper_intro.trial.finish" })
	runtime.dispatch({ "type": "keeper_intro.thread.continue" })
	if OpeningRealmService.get_status(runtime.flow_ctx.save_data) != OpeningRealmService.STATUS_LOCKED:
		return { "ok": false, "error": "Opening Realm must be locked before the awakening" }
	runtime.dispatch({ "type": "keeper_intro.awakening.choose", "choice": "guard" })
	if OpeningRealmService.get_status(runtime.flow_ctx.save_data) != OpeningRealmService.STATUS_LOCKED:
		return { "ok": false, "error": "Awakening alone must not unlock the opening Realm — the rite is the second half" }
	runtime.dispatch({ "type": "keeper_intro.weave.complete" })
	if OpeningRealmService.get_status(runtime.flow_ctx.save_data) != OpeningRealmService.STATUS_REALM_READY:
		return { "ok": false, "error": "Awakening + first Weave must arm the opening Realm" }
	if OpeningRealmService.get_realm_id(runtime.flow_ctx.save_data) != RealmService.PROLOGUE_REALM_ID:
		return { "ok": false, "error": "opening_realm_id must name the prologue Realm" }
	if not _prologue_entry(runtime).is_empty():
		return { "ok": false, "error": "The prologue run must not exist before keeper_intro.complete" }

	runtime.dispatch({ "type": "keeper_intro.complete" })
	if OpeningRealmService.get_status(runtime.flow_ctx.save_data) != OpeningRealmService.STATUS_ACTIVE:
		return { "ok": false, "error": "Opening Realm must be active after keeper_intro.complete" }
	var entry := _prologue_entry(runtime)
	if entry.is_empty():
		return { "ok": false, "error": "Expected a prologue Realm run in save_data.realms" }
	if str(entry.get("status", "")) != RealmModel.STATUS_ACTIVE:
		return { "ok": false, "error": "Prologue Realm must be active, got '%s'" % str(entry.get("status", "")) }
	if int(entry.get("stage_count", 0)) != 1:
		return { "ok": false, "error": "Prologue Realm must have exactly one stage, got %d" % int(entry.get("stage_count", 0)) }
	var stages_v: Variant = entry.get("stages", [])
	var stages: Array = stages_v if stages_v is Array else []
	if stages.size() != 1:
		return { "ok": false, "error": "Expected one generated Stage, got %d" % stages.size() }
	# A real generated stage: it carries an explore map with hidden situations to scout.
	var stage0: Dictionary = stages[0] if stages[0] is Dictionary else {}
	var emap_v: Variant = stage0.get("explore_map", {})
	var emap: Dictionary = emap_v if emap_v is Dictionary else {}
	var sits_v: Variant = emap.get("situations", [])
	var sits: Array = sits_v if sits_v is Array else []
	if sits.is_empty():
		return { "ok": false, "error": "Prologue Stage must be a real generated stage with situations" }
	var revealed_count := 0
	for s_v in sits:
		if s_v is Dictionary and bool((s_v as Dictionary).get("revealed", false)):
			revealed_count += 1
	if revealed_count >= sits.size():
		return { "ok": false, "error": "Prologue Stage must hold hidden information — every situation starts revealed" }
	# Built around the player's own starter virtue, not a value authored in realms.json.
	var cfg := runtime.config_service.get_balance()
	var starter_virtue := KeeperIntroServiceScript.get_selected_virtue(runtime.flow_ctx.save_data, cfg)
	if str(entry.get("virtue", "")) != starter_virtue:
		return { "ok": false, "error": "Prologue virtue '%s' must be the starter virtue '%s'" % [str(entry.get("virtue", "")), starter_virtue] }
	if int(entry.get("run_index", -1)) != 0:
		return { "ok": false, "error": "Prologue run_index must be 0" }
	if runtime.flow_ctx.realm_id != RealmService.PROLOGUE_REALM_ID:
		return { "ok": false, "error": "flow_ctx.realm_id must point at the prologue Realm" }
	# The Sanctum must offer a way in.
	var actions: Dictionary = runtime.flow_ctx.last_snapshot.get("actions", {})
	var enter_v: Variant = actions.get("cta.enter_stage", {})
	var enter: Dictionary = enter_v if enter_v is Dictionary else {}
	if enter.is_empty() or bool(enter.get("disabled", true)):
		return { "ok": false, "error": "cta.enter_stage must be enabled while the opening Realm is open" }
	# And that way in actually reaches the prologue's one stage.
	runtime.dispatch({ "type": "flow.go_state", "to": FlowStateIds.STAGE_MAP })
	var map_snap: Dictionary = runtime.flow_ctx.last_snapshot
	if str(map_snap.get("type", "")) != FlowStateIds.STAGE_MAP:
		return { "ok": false, "error": "cta.enter_stage must reach the stage map" }
	var listed_v: Variant = map_snap.get("data", {}).get("stages", [])
	var listed: Array = listed_v if listed_v is Array else []
	if listed.size() != 1:
		return { "ok": false, "error": "Prologue stage map must offer exactly one stage, got %d" % listed.size() }
	return { "ok": true }


## Step 10, first half: normal Realms stay shut until the prologue is done — and the prologue is
## never offered as a choice.
static func _t_normal_realms_locked_until_prologue_complete() -> Dictionary:
	var runtime := _run_full_keeper_intro()
	runtime.dispatch({ "type": "flow.go_state", "to": FlowStateIds.REALM_SELECT })
	var listed: Array = runtime.flow_ctx.last_snapshot.get("data", {}).get("realms", [])
	for r_v in listed:
		if r_v is Dictionary and str((r_v as Dictionary).get("id", "")) == RealmService.PROLOGUE_REALM_ID:
			return { "ok": false, "error": "The prologue Realm must never appear in Realm Select" }
	if listed.is_empty():
		return { "ok": false, "error": "Expected the normal Realms to be listed" }
	for r_v in listed:
		if r_v is Dictionary and bool((r_v as Dictionary).get("locked", true)):
			return { "ok": false, "error": "Normal Realm cards must not read as hard-locked; the gate is on selection" }

	runtime.dispatch({ "type": "flow.select_realm", "realm_id": "realm.01" })
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) == FlowStateIds.STAGE_MAP:
		return { "ok": false, "error": "flow.select_realm must be denied before the prologue is complete" }
	var realms_v: Variant = runtime.flow_ctx.save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	if realms.has("realm.01"):
		return { "ok": false, "error": "A denied selection must not create the realm" }

	# Selecting the prologue by hand is refused too — it is opened by the intro, never chosen.
	runtime.dispatch({ "type": "flow.select_realm", "realm_id": RealmService.PROLOGUE_REALM_ID })
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) == FlowStateIds.STAGE_MAP:
		return { "ok": false, "error": "The prologue Realm must not be selectable" }
	return { "ok": true }


## Step 10, second half — and the whole point of the exclusion work. Once the prologue is
## finished the normal Realms open in any order, and the FIRST of them is still the player's
## first Realm: run_index 0, no inflated virtue bonus, no inflated reward or XP multiplier.
static func _t_prologue_does_not_inflate_first_realm_run_index() -> Dictionary:
	var runtime := _run_full_keeper_intro()
	# Finish the prologue the way the game does: the realm's own completion stamp.
	runtime.flow_ctx.save_data["realms"][RealmService.PROLOGUE_REALM_ID]["status"] = RealmModel.STATUS_COMPLETED
	runtime.flow_ctx.save_data["realms"][RealmService.PROLOGUE_REALM_ID]["is_completed"] = true
	OpeningRealmService.mark_complete(runtime.flow_ctx.save_data, runtime.logger, 1)
	if not OpeningRealmService.normal_realms_unlocked(runtime.flow_ctx.save_data):
		return { "ok": false, "error": "Normal Realms must open once the prologue is complete" }
	runtime.flow_ctx.realm_id = ""

	runtime.dispatch({ "type": "flow.select_realm", "realm_id": "realm.02" })
	if str(runtime.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.STAGE_MAP:
		return { "ok": false, "error": "Normal Realms must be selectable in any order after the prologue" }
	var realms_v: Variant = runtime.flow_ctx.save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	var first: Dictionary = realms.get("realm.02", {})
	if first.is_empty():
		return { "ok": false, "error": "Expected realm.02 to be created" }
	if int(first.get("run_index", -1)) != 0:
		return { "ok": false, "error": "First real Realm must have run_index 0, got %d — the prologue is inflating it" % int(first.get("run_index", -1)) }
	return { "ok": true }


static func _thread_count(runtime: FlowRuntime) -> int:
	var sanctum_v: Variant = runtime.flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var threads_v: Variant = sanctum.get("threads", {})
	return (threads_v as Dictionary).size() if threads_v is Dictionary else 0


## The opening Realm pays exactly ONE Thread — and pinning it does not leak into normal Realms.
##
## Thread count is derived from the AVERAGE segment weight, so a one-stage Realm cleared cleanly
## reads the same as a ten-stage Realm cleared cleanly and takes the top count. The prologue has
## exactly one stage, so it was paying the maximum a full Realm can pay. Both halves are pinned
## here: the prologue is fixed at RealmService.PROLOGUE_THREAD_COUNT, and a normal Realm still
## takes its count from data.threads.count_thresholds.
static func _t_prologue_pays_exactly_one_thread() -> Dictionary:
	var runtime := _run_full_keeper_intro()
	var mismatches: Array = []

	var before := _thread_count(runtime)
	runtime.dispatch({ "type": "flow.go_state", "to": FlowStateIds.STAGE_MAP })
	runtime.dispatch({ "type": "flow.select_stage", "stage_id": "stage.0" })
	runtime.dispatch({ "type": "flow.complete_stage" })

	var prologue := _prologue_entry(runtime)
	if not bool(prologue.get("is_completed", false)):
		return { "ok": false, "error": "Test setup failed: the prologue Realm did not complete" }

	var earned: Array = runtime.flow_ctx.last_realm_threads_earned
	if earned.size() != 1:
		mismatches.append("Prologue must pay exactly 1 Thread, paid %d" % earned.size())
	if _thread_count(runtime) - before != 1:
		mismatches.append("Prologue must add exactly 1 Thread to the Sanctum, added %d" % (_thread_count(runtime) - before))
	# Only the COUNT is pinned. Virtue and quality tier must still come from the run.
	if not earned.is_empty():
		var thread: Dictionary = earned[0] if earned[0] is Dictionary else {}
		var starter_virtue := KeeperIntroServiceScript.get_selected_virtue(
			runtime.flow_ctx.save_data, runtime.config_service.get_balance()
		)
		if str(thread.get("virtue", "")) != starter_virtue:
			mismatches.append("Prologue Thread virtue must be the starter virtue '%s', got '%s'" \
				% [starter_virtue, str(thread.get("virtue", ""))])
		var segments_v: Variant = prologue.get("realm_recovery_segments", [])
		var segments: Array = segments_v if segments_v is Array else []
		var expected_tier := str((segments[0] as Dictionary).get("quality_tier", "")) if (not segments.is_empty() and segments[0] is Dictionary) else ""
		if str(thread.get("quality_tier", "")) != expected_tier:
			mismatches.append("Prologue Thread tier must come from the run ('%s'), got '%s'" \
				% [expected_tier, str(thread.get("quality_tier", ""))])

	# The other half: a normal Realm is untouched by the pin. Its last stage is completed the
	# same way, and its count still comes from count_thresholds — here, more than one.
	runtime.dispatch({ "type": "flow.select_realm", "realm_id": "realm.02" })
	var realms_v: Variant = runtime.flow_ctx.save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	var realm: Dictionary = realms.get("realm.02", {})
	if realm.is_empty():
		return { "ok": false, "error": "Test setup failed: realm.02 was not created | %s" % " | ".join(mismatches) }
	var stage_count := int(realm.get("stage_count", 1))
	realm["current_stage_index"] = stage_count - 1

	var before_normal := _thread_count(runtime)
	runtime.dispatch({ "type": "flow.select_stage", "stage_id": "stage.%d" % (stage_count - 1) })
	runtime.dispatch({ "type": "flow.complete_stage" })
	var normal_earned: int = runtime.flow_ctx.last_realm_threads_earned.size()
	if normal_earned <= 1:
		mismatches.append("A normal Realm must still take its count from count_thresholds (>1 here), got %d" % normal_earned)
	if _thread_count(runtime) - before_normal != normal_earned:
		mismatches.append("Normal Realm added %d Threads to the Sanctum but reported %d" \
			% [_thread_count(runtime) - before_normal, normal_earned])

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }
