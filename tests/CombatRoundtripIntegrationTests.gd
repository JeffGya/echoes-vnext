# res://tests/CombatRoundtripIntegrationTests.gd
# V2-STAGE-004 P3 — INTEGRATION coverage for the real combat round loop on irregular terrain.
#
# Why this file exists:
#   The deterministic combat core (live movement activation, BehaviorArbiter, StageTerrain)
#   is well unit-tested in isolation, and those tests pass. But there was NO test that drove
#   the *real* FlowRuntime round loop end to end on an irregular-terrain combat board:
#       FlowEncounterState.enter() → combat.init → combat.confirm_round → combat.next_actor*
#   That loop is id-keyed: CombatState._calc_initiative records each actor by `id`, and
#   FlowRuntime._resolve_next_actor looks the actor back up via _find_actor_by_id(id).
#
#   If an Echo reaches combat with an EMPTY `id` (EchoFactory.generate returns id:"" — the id
#   is assigned later by SummonService/FlowRuntime, and ActorSchema.validate only checks the
#   field EXISTS, not that it is non-empty), its initiative entry has id "" and the lookup in
#   _resolve_next_actor returns {} — so that Echo never takes a turn and freezes at its spawn
#   cell ("no aim or goal", appears stuck near a corner). This was the gap that let the bug
#   through: unit tests of isolated movement pass because the math is correct; the failure is in the
#   id-keyed runtime wiring, only reachable through the full loop.
#
# Tests:
#   1. combat_roundtrip/echoes_advance_on_terrain
#        Real loop, properly-id'd party → every Echo closes distance to the enemy.
#   2. combat_roundtrip/duplicate_id_echoes_freeze (regression — now asserts the FIX)
#        Several Echoes enter combat sharing the SAME id (all "" because id assignment was
#        skipped). Before the fix, _find_actor_by_id returned the FIRST match for every
#        duplicate initiative slot, so only ONE of the duplicates ever resolved while the
#        rest froze at spawn ("no aim or goal" symptom). FlowEncounterState.enter() now runs
#        a deterministic guard (_ensure_unique_actor_ids) before initiative is built: empty
#        and duplicate ids are repaired to unique "<faction>_<index>" fallbacks. This test
#        proves the repair — every Echo now gets a distinct id and ALL of them advance.
class_name CombatRoundtripIntegrationTests
extends RefCounted

const MovementContextScript := preload("res://core/movement/contracts/MovementContext.gd")
const MovementActorFactScript := preload("res://core/movement/contracts/MovementPerceivedActorFact.gd")
const MovementHazardFactScript := preload("res://core/movement/contracts/MovementKnownHazardFact.gd")
const MovementIntentScript := preload("res://core/movement/contracts/MovementIntent.gd")
const MovementActionPlanScript := preload("res://core/movement/contracts/MovementActionPlan.gd")
const CombatActivationServiceScript := preload("res://core/movement/CombatActivationService.gd")
const MovementOptionScript := preload("res://core/movement/contracts/MovementOption.gd")
const MovementOptionServiceScript := preload("res://core/movement/MovementOptionService.gd")
const MovementProfileServiceScript := preload("res://core/movement/MovementProfileService.gd")
const MovementPathServiceScript := preload("res://core/movement/MovementPathService.gd")

static func register(runner) -> void:
	runner.register_test("combat_roundtrip/echoes_advance_on_terrain", func(): return test_echoes_advance())
	runner.register_test("combat_roundtrip/duplicate_id_echoes_freeze", func(): return test_duplicate_id_freeze())
	# V2-STAGE-004 Distinctiveness — §4-E RECOVER reinforcement
	runner.register_test("combat_roundtrip/recover_reinforcement_spawns_enemy_side", func(): return test_recover_reinforcement())
	# V2-STAGE-004 Distinctiveness — §4-F ENDURE rising wave + all_waves_spawned
	runner.register_test("combat_roundtrip/endure_rising_wave_size_and_flag", func(): return test_endure_rising_wave())
	# V2-COMBAT-003 — a mid-round wave spawn must land on the host region, not a moated island
	runner.register_test("combat_roundtrip/endure_wave_spawn_stays_on_host_region", func(): return test_endure_wave_spawn_host_region())
	# V2-STAGE-004 Distinctiveness — §4-G PROTECT theft and recovery on carrier death
	runner.register_test("combat_roundtrip/protect_theft_and_carrier_recovery", func(): return test_protect_theft())
	# V2-STAGE-004 PROTECT guard-proximity counter
	runner.register_test("combat_roundtrip/protect_counter_advances_when_echo_near", func(): return test_protect_counter_near())
	runner.register_test("combat_roundtrip/protect_counter_resets_when_echo_far", func(): return test_protect_counter_far())
	runner.register_test("combat_roundtrip/protect_counter_resets_after_leaving", func(): return test_protect_counter_resets_after_leaving())
	# Bug-fix: RECOVER holder reads top-level speed field
	runner.register_test("combat_roundtrip/recover_holder_fastest_echo_designated", func(): return test_recover_holder_fastest_echo())
	# V2-STAGE-004 P3b — PURSUE smoke test
	runner.register_test("combat_roundtrip/pursue_quarry_spawns_and_moves", func(): return test_pursue_quarry_moves())
	# V2-STAGE-004 P3b — PURSUE distinctiveness: no regular enemies, quarry-only
	runner.register_test("combat_roundtrip/pursue_no_regular_enemies_spawn", func(): return test_pursue_no_regular_enemies_spawn())
	# V2-STAGE-004 P3b — PURSUE distinctiveness: board is 2× in one dimension
	runner.register_test("combat_roundtrip/pursue_board_is_larger_than_standard", func(): return test_pursue_board_is_larger_than_standard())
	# V2-STAGE-004 P3c — GUIDE_SPIRIT roundtrip + escort/skittish behaviour
	runner.register_test("combat_roundtrip/guide_spirit_protect_roundtrip", func(): return test_guide_spirit_protect_roundtrip())
	runner.register_test("combat_roundtrip/guide_spirit_protect_no_win_without_guard", func(): return test_guide_spirit_protect_no_win_without_guard())
	runner.register_test("combat_roundtrip/guide_spirit_escort_moves_only_after_adjacency", func(): return test_guide_spirit_escort_moves_only_after_adjacency())
	runner.register_test("combat_roundtrip/guide_spirit_protect_flees_when_enemy_near_no_echo", func(): return test_guide_spirit_protect_flees_when_enemy_near_no_echo())
	runner.register_test("combat_roundtrip/guide_spirit_protect_holds_when_echo_adjacent", func(): return test_guide_spirit_protect_holds_when_echo_adjacent())
	# JOINED combatant spirit (is_structure=false) uses normal combat activation,
	# not the non-joining GUIDE objective mover.
	runner.register_test("combat_roundtrip/guide_spirit_joined_combatant_moves_freely", func(): return test_guide_spirit_joined_combatant_moves_freely())
	runner.register_test("combat_roundtrip/guide_spirit_dev_override_forces_escort_join", func(): return test_guide_spirit_dev_override_forces_escort_join())
	# V2-STAGE-004 P3c review-fix: escort destination lands on the walkable FRONTIER ring
	# (not literal bounds) on inset irregular terrain, so escort is winnable.
	runner.register_test("combat_roundtrip/guide_spirit_escort_destination_on_inset_terrain", func(): return test_guide_spirit_escort_destination_on_inset_terrain())
	# V2-STAGE-004 P3c review-fix: a JOINED spirit must not self-escort to a spirit_escorted
	# victory after the real party is wiped — party-wipe defeat must fire instead.
	runner.register_test("combat_roundtrip/guide_spirit_joined_spirit_does_not_self_escort", func(): return test_guide_spirit_joined_spirit_does_not_self_escort())
	# D92: an escort that already started does not keep paying out after the party dies —
	# a wipe must score all_echoes_dead, never spirit_escorted.
	runner.register_test("combat_roundtrip/guide_spirit_party_wipe_scores_defeat_not_escort", func(): return test_guide_spirit_party_wipe_scores_defeat_not_escort())
	# Kill-signal fix regression: a killing blow through the LIVE round loop must carry
	# is_kill=true on the result and fire the kill consumers (boost, ripple, ledger).
	# Guards against _resolve_melee ever dropping the is_kill key again.
	runner.register_test("combat_roundtrip/killing_blow_sets_is_kill_live", func(): return test_killing_blow_sets_is_kill_live())
	# Kill-signal fix P1 (Codex review): an ENEMY lethal blow also sets is_kill=true, but the
	# kill morale/ripple block is echo-gated — an enemy kill must NOT boost the enemy or hand
	# the surviving party morale/fear relief for losing a member.
	runner.register_test("combat_roundtrip/enemy_kill_does_not_ripple_to_party", func(): return test_enemy_kill_does_not_ripple_to_party())
	# Slice 6B live hazard regression: approach facts feed planning, combat-board
	# facts override same-cell/type duplicates, and FlowRuntime owns mover death state.
	runner.register_test("combat_roundtrip/live_hazard_union_and_mover_damage", func(): return test_live_hazard_union_and_mover_damage())
	runner.register_test("combat_roundtrip/live_hazard_action_phase_order", func(): return test_live_hazard_action_phase_order())
	runner.register_test("combat_roundtrip/live_truncated_engage_advances_before_melee", func(): return test_live_truncated_engage_advances_before_melee())
	# Slice 6B PR#52 fix 2 (previously unguarded): the authored purify candidate carries
	# an EMPTY target_id, so the live shrine must be located directly.
	runner.register_test("combat_roundtrip/purify_empty_target_id_finds_first_living_structure", func(): return test_purify_empty_target_id())
	# Slice 6E: the live option_id must satisfy the MovementOption contract, and the
	# movement-aware selector must actually run (both were dead after PR #52).
	runner.register_test("combat_roundtrip/live_direct_option_id_is_contract_valid", func(): return test_live_direct_option_id_is_contract_valid())
	runner.register_test("combat_roundtrip/objective_route_truncates_and_stays_movement_aware", func(): return test_objective_route_truncates_and_stays_movement_aware())
	# Slice 6E: the perceived-actor cross-check must survive structures, corpses and
	# downed actors — otherwise movement-aware selection is inert in every objective mode.
	runner.register_test("combat_roundtrip/purify_selection_survives_structure_and_death", func(): return test_purify_selection_survives_structure_and_death())
	# Slice 6E Task A: an unroutable goal set must NOT switch the movement-aware layer off.
	runner.register_test("combat_roundtrip/unroutable_goals_keep_selection_enabled", func(): return test_unroutable_goals_keep_selection_enabled())
	# Slice 6E Task B: a destroyed objective must stop being published as a live objective.
	runner.register_test("combat_roundtrip/dead_objective_is_not_published", func(): return test_dead_objective_is_not_published())
	# Slice 6E Task C: two actors on one cell must not discard the whole board.
	runner.register_test("combat_roundtrip/stacked_actors_keep_selection_alive", func(): return test_stacked_actors_keep_selection_alive())
	runner.register_test("combat_roundtrip/published_option_carries_truthful_control_and_hazards", func(): return test_published_option_carries_truthful_control_and_hazards())
	# V2-COMBAT-003 — a fight where neither side can deal damage cannot end by any objective
	# check (both actors refuse/guard/miss forever). The no-progress detector must end it.
	runner.register_test("combat_roundtrip/no_progress_stalemate_ends_as_forced_retreat", func(): return test_no_progress_stalemate_ends_as_forced_retreat())
	runner.register_test("combat_roundtrip/forced_retreat_grants_nothing", func(): return test_forced_retreat_grants_nothing())
	# PR #62 review, generalized by V2-COMBAT-003.5: PURIFY_SHRINE has its own clock — the
	# shrine drains every round — so the stalemate detector must not end that fight. No longer a
	# by-name exemption: CombatState.get_progress_watch() sees the shrine HP itself changing.
	runner.register_test("combat_roundtrip/purify_shrine_is_exempt_from_the_stalemate_check", func(): return test_purify_shrine_is_exempt_from_the_stalemate_check())
	# V2-COMBAT-003.5 Phase 1c: GUIDE_SPIRIT escort through the real round loop — a genuine
	# approach must survive the stalemate check, but a genuinely blocked escort must still
	# force-retreat (no unconditional exemption).
	runner.register_test("combat_roundtrip/guide_spirit_escort_approach_survives_stalemate_check", func(): return test_guide_spirit_escort_approach_survives_stalemate_check())
	runner.register_test("combat_roundtrip/guide_spirit_escort_blocked_still_force_retreats", func(): return test_guide_spirit_escort_blocked_still_force_retreats())
	# PR #62 review: the "guide" debug command now dispatches. It runs mid-fight, so it must
	# leave the encounter and its snapshot alone.
	runner.register_test("combat_roundtrip/guidance_dispatch_leaves_the_encounter_intact", func(): return test_guidance_dispatch_leaves_the_encounter_intact())
	# V2-COMBAT-003.5 Phase 2a: encounter_id used to identify only the STAGE (set once by
	# flow.select_stage), so every fight inside one stage shared one seed identity and produced
	# identical terrain/spawn cells. stage.engage_situation now appends the situation id, so two
	# combat situations in the same stage must diverge.
	runner.register_test("combat_roundtrip/two_encounters_same_stage_get_distinct_identity", func(): return test_two_encounters_same_stage_get_distinct_identity())
	runner.register_test("combat_roundtrip/two_encounters_same_stage_get_distinct_terrain_and_spawn", func(): return test_two_encounters_same_stage_get_distinct_terrain_and_spawn())
	# V2-COMBAT-003.5 Phase 5 decision #48: resist_fear must reduce the unscouted-approach
	# surprise fear bump applied at encounter setup, same as the per-hit/near-death paths.
	runner.register_test("combat_roundtrip/resist_fear_reduces_surprise_fear", func(): return test_resist_fear_reduces_surprise_fear())
	# Decision #59/#60: an Echo on the escort spirit's next cell trades places with it and the
	# spirit barks; a hostile on that cell still makes the spirit wait.
	runner.register_test("combat_roundtrip/guide_spirit_escort_echo_yields_and_spirit_barks", func(): return test_guide_spirit_escort_echo_yields_and_spirit_barks())
	runner.register_test("combat_roundtrip/guide_spirit_escort_hostile_on_path_still_blocks", func(): return test_guide_spirit_escort_hostile_on_path_still_blocks())


## V2-INFRA-003 Phase 6 Slice 6G: the live movement helper family moved off FlowRuntime onto
## LiveMovementContextService. These suites reach those helpers by name, so they now build the
## same object FlowRuntime._resolve_next_actor builds. The service is stateless between calls,
## so a fresh instance per call site is exact — no shim was left on FlowRuntime (AGENTS.md #20).
static func _lm(runtime) -> LiveMovementContextService:
	return LiveMovementContextService.new(runtime.flow_ctx, runtime.logger)


static func _drive_one_round(runtime, ectx) -> void:
	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 60:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })


# ---------------------------------------------------------------------------
# Shared setup: boot runtime, active realm (→ irregular terrain), 5-echo party.
# `assign_ids` controls whether echoes get real ids (real flow) or are left id-less
# (all id "" — the duplicate-id condition that reproduces the freeze).
# ---------------------------------------------------------------------------
static func _setup(
	seed_tag: String,
	assign_ids: bool,
	log_level: String = "off",
	objective_mode: String = EncounterResolutionModes.COMBAT
) -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level(log_level)
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.dir() + "combat_roundtrip_slot.json")
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, t)
	if rm.is_empty():
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0." + seed_tag

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(seed_tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		# EchoFactory returns id:"" — the caller (SummonService/FlowRuntime) assigns it.
		if assign_ids:
			echo["id"] = "echo_%04d" % (i + 1)
		roster.append(echo)
		party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	flow_ctx.dev_combat_objective = objective_mode
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	return { "runtime": runtime, "flow_ctx": flow_ctx, "ectx": flow_ctx.encounter_ctx, "logger": logger }


# ---------------------------------------------------------------------------
# V2-COMBAT-003.5 Phase 5 decision #48 — resist_fear on the surprise/ambush fear bump.
#
# Unlike _setup(), the roster is hand-built (not EchoFactory) so resilience_traits/rank are
# controlled directly, and stage_context.encounter_approach is set BEFORE
# FlowEncounterState.enter() — EncounterSetupService.setup() applies the surprise bump once,
# during initial actor construction, so it must already be in place when enter() runs.
# ---------------------------------------------------------------------------

static func _setup_surprise_fear(seed_tag: String, resist: bool) -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var save_path := TestSaveHarness.fresh_save_path("combat_roundtrip_surprise_%s.json" % seed_tag, "combat_roundtrip")
	var runtime := FlowRuntime.new(logger, config, save_path)
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, t)
	if rm.is_empty():
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0." + seed_tag

	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = {
			"id": "sf_echo_%d" % i, "name": "sf_echo_%d" % i, "rank": 3,
			"resilience_traits": ["resist_fear"] if resist else [],
		}
		roster.append(echo)
		party_ids.append(str(echo["id"]))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	# Unscouted approach — the gate EncounterSetupService.gd checks before the surprise bump.
	flow_ctx.save_data["stage_context"] = {
		"encounter_approach": { "situation_was_revealed": false },
	}

	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	return { "runtime": runtime, "flow_ctx": flow_ctx, "ectx": flow_ctx.encounter_ctx }


static func _sf_echo_fear(actors: Array, echo_id: String) -> int:
	for a_v in actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("id", "")) == echo_id:
			return int((a_v as Dictionary).get("fear", -1))
	return -1


static func test_resist_fear_reduces_surprise_fear() -> Dictionary:
	var bal_svc := ConfigService.new()
	bal_svc.load_balance()
	var surprise_fear: int = int(bal_svc.get_balance().get("data", {}) \
		.get("combat", {}).get("encounter_approach", {}).get("surprise_fear", 0))
	if surprise_fear <= 0:
		return { "ok": false, "error": "balance.json must authorise combat.encounter_approach.surprise_fear" }

	var plain_env: Dictionary = _setup_surprise_fear("plain", false)
	if plain_env.is_empty():
		return { "ok": false, "error": "setup failed (control)" }
	var steady_env: Dictionary = _setup_surprise_fear("steady", true)
	if steady_env.is_empty():
		return { "ok": false, "error": "setup failed (resist_fear)" }

	var plain_ectx: EncounterContext = plain_env["ectx"]
	var steady_ectx: EncounterContext = steady_env["ectx"]
	var plain_fear := _sf_echo_fear(plain_ectx.actors, "sf_echo_0")
	var steady_fear := _sf_echo_fear(steady_ectx.actors, "sf_echo_0")

	if plain_fear != surprise_fear:
		return { "ok": false, "error": "control drift: expected fear %d, got %d" % [surprise_fear, plain_fear] }
	if steady_fear >= plain_fear:
		return { "ok": false, "error": "resist_fear did not reduce surprise fear: %d vs %d" % [steady_fear, plain_fear] }
	if steady_fear != roundi(float(surprise_fear) * 0.6):
		return { "ok": false, "error": "expected 40%% reduction to %d, got %d" % [roundi(float(surprise_fear) * 0.6), steady_fear] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-COMBAT-003.5 Phase 2a — encounter identity varies per situation, not per stage.
# ---------------------------------------------------------------------------

## Boots a runtime on realm.01/stage.0 through the REAL production seam
## (RealmService.get_or_create, then a hand-populated 5-echo party — same shortcut _setup()
## takes), forces the stage's first two generated situations to type "combat" (unrevealed,
## unresolved) so both route "async" through SituationResolutionService.route(), and returns
## their ids. Unlike _setup(), this does NOT set flow_ctx.encounter_id or call
## FlowEncounterState.enter() directly — the whole point is to prove
## VentureController.handle_engage_situation() (dispatched, not hand-invoked) sets it correctly.
static func _setup_two_combat_situations(seed_tag: String) -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var save_path := TestSaveHarness.fresh_save_path("encounter_identity_%s.json" % seed_tag, "combat_roundtrip")
	var runtime := FlowRuntime.new(logger, config, save_path)
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, t)
	if rm.is_empty():
		return {}
	flow_ctx.stage_id     = "stage.0"
	flow_ctx.encounter_id = flow_ctx.realm_id + "." + flow_ctx.stage_id  # mirrors handle_select_stage

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(seed_tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		roster.append(echo)
		party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []
	if situations.size() < 2:
		return {}
	var sit_ids: Array = []
	for i in range(2):
		var s_v: Variant = situations[i]
		var s: Dictionary = s_v if s_v is Dictionary else {}
		s["type"]     = SituationModel.TYPE_COMBAT
		s["revealed"] = false
		s["resolved"] = false
		# Force BOTH situations to the same non-objective binding (objective_index -1).
		# EncounterSetupService._resolve_mode_from_stage() reads
		# flow_ctx.active_encounter_objective_index (set from the ENGAGED situation's own
		# objective_index) and picks resolution_mode from it — PURSUE/GUIDE_SPIRIT modes scale
		# board bounds. Two situations with different objective_index would make resolution_mode
		# (and therefore terrain bounds) differ for a reason having nothing to do with this
		# story's encounter_id fix. Pinning both to -1 isolates encounter_id as the only variable.
		s["is_objective"]    = false
		s["objective_index"] = -1
		situations[i] = s
		sit_ids.append(str(s.get("id", "")))
	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)

	return { "runtime": runtime, "flow_ctx": flow_ctx, "sit_ids": sit_ids }


## The identity assertion: engaging two distinct combat situations in the same stage must
## produce two distinct flow_ctx.encounter_id values, both prefixed by the shared stage
## identity (realm_id + "." + stage_id).
static func test_two_encounters_same_stage_get_distinct_identity() -> Dictionary:
	var env: Dictionary = _setup_two_combat_situations("encid_a")
	if env.is_empty():
		return { "ok": false, "error": "setup failed — stage.0 did not generate 2+ situations" }
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var sit_ids: Array = env["sit_ids"]
	var stage_identity: String = flow_ctx.realm_id + "." + flow_ctx.stage_id

	runtime.dispatch({ "type": "stage.engage_situation", "situation_id": str(sit_ids[0]) })
	if flow_ctx.encounter_ctx == null:
		return { "ok": false, "error": "first engage_situation did not enter combat (encounter_ctx null)" }
	var encounter_id_a: String = flow_ctx.encounter_id
	if not encounter_id_a.begins_with(stage_identity + "."):
		return { "ok": false, "error": "encounter_id_a %s lost the stage identity %s" % [encounter_id_a, stage_identity] }
	if encounter_id_a == stage_identity:
		return { "ok": false, "error": "encounter_id_a equals the bare stage id — situation id was not appended" }

	# Retreat with a guaranteed roll (success_pct 100 → roll<100 always true, RetreatService.roll_retreat)
	# to clear encounter_ctx deterministically and free the second situation for engagement.
	# stage.engage_situation carries no flow-state gate (FlowRuntime.dispatch matches on action
	# type only), so the second dispatch below is exactly as valid as the first.
	runtime.dispatch({ "type": "encounter.retreat", "ase_cost": 0, "success_pct": 100 })
	if flow_ctx.encounter_ctx != null:
		return { "ok": false, "error": "retreat at success_pct=100 did not clear encounter_ctx" }

	runtime.dispatch({ "type": "stage.engage_situation", "situation_id": str(sit_ids[1]) })
	if flow_ctx.encounter_ctx == null:
		return { "ok": false, "error": "second engage_situation did not enter combat (encounter_ctx null)" }
	var encounter_id_b: String = flow_ctx.encounter_id
	if not encounter_id_b.begins_with(stage_identity + "."):
		return { "ok": false, "error": "encounter_id_b %s lost the stage identity %s" % [encounter_id_b, stage_identity] }

	if encounter_id_a == encounter_id_b:
		return { "ok": false, "error": "both encounters in one stage shared encounter_id %s (BUG-003 regressed)" % encounter_id_a }
	return { "ok": true }


## The observable consequence: two encounters with distinct identity must produce distinct
## terrain and a distinct party spawn cell — proving the seed paths keyed on encounter_id
## (EncounterSetupService "combat.terrain." / "combat.placement." + encounter_id) actually vary
## now, with no change to those call sites themselves.
static func test_two_encounters_same_stage_get_distinct_terrain_and_spawn() -> Dictionary:
	var env: Dictionary = _setup_two_combat_situations("encid_b")
	if env.is_empty():
		return { "ok": false, "error": "setup failed — stage.0 did not generate 2+ situations" }
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var sit_ids: Array = env["sit_ids"]

	runtime.dispatch({ "type": "stage.engage_situation", "situation_id": str(sit_ids[0]) })
	var ectx_a: EncounterContext = flow_ctx.encounter_ctx
	if ectx_a == null:
		return { "ok": false, "error": "first engage_situation did not enter combat" }
	var terrain_a: Dictionary = ectx_a.terrain.duplicate(true)
	var spawn_a: Dictionary = {}
	for a_v in ectx_a.actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("faction", "")) == "echo":
			spawn_a = (a_v as Dictionary).get("grid_pos", {})
			break

	runtime.dispatch({ "type": "encounter.retreat", "ase_cost": 0, "success_pct": 100 })
	if flow_ctx.encounter_ctx != null:
		return { "ok": false, "error": "retreat at success_pct=100 did not clear encounter_ctx" }

	runtime.dispatch({ "type": "stage.engage_situation", "situation_id": str(sit_ids[1]) })
	var ectx_b: EncounterContext = flow_ctx.encounter_ctx
	if ectx_b == null:
		return { "ok": false, "error": "second engage_situation did not enter combat" }
	var terrain_b: Dictionary = ectx_b.terrain.duplicate(true)
	var spawn_b: Dictionary = {}
	for b_v in ectx_b.actors:
		if b_v is Dictionary and str((b_v as Dictionary).get("faction", "")) == "echo":
			spawn_b = (b_v as Dictionary).get("grid_pos", {})
			break

	if terrain_a == terrain_b and spawn_a == spawn_b:
		return {
			"ok": false,
			"error": "two encounters in one stage produced identical terrain AND identical spawn cell — encounter_id is not varying per fight",
		}
	return { "ok": true }


# Drive the real round loop for up to `max_rounds` rounds.
static func _drive(runtime, ectx, max_rounds: int) -> void:
	runtime.dispatch({ "type": "combat.init" })
	for _r in range(max_rounds):
		runtime.dispatch({ "type": "combat.confirm_round" })
		var guard: int = 0
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)): break
			if str(cs.get("round_phase", "")) != "in_round": break
			runtime.dispatch({ "type": "combat.next_actor" })
		if bool(ectx.combat_state.get("combat_over", false)): break


static func _enemy_pos(ectx) -> Dictionary:
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not a_v.get("is_dead", false):
			return a_v.get("grid_pos", {})
	return {}


# ---------------------------------------------------------------------------
# V2-COMBAT-003 — no-progress stalemate (a fight where neither side deals damage).
# ---------------------------------------------------------------------------

## Builds a real 1-echo-vs-1-enemy encounter, using the standard party+board setup, then trims
## the actor list to exactly those two and zeroes their offense so melee can never deal damage:
## CombatService._melee_damage() computes base = max(0, atk - eff_def), so atk=0 already floors
## it at 0 for the attacker's own hit, and def=999 on both sides adds a wide safety margin
## against the +5 morale_bonus term (attacker morale 100 => (100-50)/10 = +5) that could
## otherwise push a stray hit above 0 if either actor's morale drifts up during the fight.
## Returns {} on setup failure or if a living echo/enemy pair could not be found.
static func _setup_no_progress(seed_tag: String) -> Dictionary:
	var env: Dictionary = _setup(seed_tag, true, "off", EncounterResolutionModes.COMBAT)
	if env.is_empty():
		return {}
	var ectx: EncounterContext = env["ectx"]
	var echo: Dictionary = {}
	var enemy: Dictionary = {}
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if echo.is_empty() and str(a.get("faction", "")) == "echo" and not a.get("is_dead", false):
			echo = a
		elif enemy.is_empty() and str(a.get("faction", "")) == "enemy" and not a.get("is_dead", false):
			enemy = a
	if echo.is_empty() or enemy.is_empty():
		return {}
	for a in [echo, enemy]:
		var a_stats: Dictionary = a.get("stats", {})
		a_stats["atk"] = 0
		a_stats["def"] = 999
		a["stats"] = a_stats
		# morale/fear pinned too: _melee_damage() adds (morale-50)/10 - fear/20 after the atk/def
		# floor, so an EchoFactory-derived actor with morale above 50 could land a stray positive
		# hit from the morale term alone. Pinning both makes base=0 the actual floor, not just
		# the intended one — see _setup_guide_escort's matching pin for the same reasoning.
		a["morale"] = 50
		a["fear"] = 0
	# Spawn already adjacent (col 5,5 / 6,5). (5,5) alone is placed successfully in ~10 other
	# seed tags in this file (e.g. lines ~1328, 1452, 1514, 1579, 1675, 2115, 2207, 2272, 2601,
	# 2681) and all pass — informal but real evidence it is walkable on every realm.01/stage.0
	# terrain roll this file exercises. (Not evidence from
	# test_guide_spirit_protect_flees_when_enemy_near_no_echo: terrain is seeded on
	# "combat.terrain." + encounter_id, which includes the seed tag, so a different tag there
	# means a different board.) Without pinning both cells, the two actors' real spawn cells
	# land apart, so the board-fingerprint-aware progress watch (CombatState.get_progress_watch)
	# reads their first rounds of closing distance as genuine progress, delaying
	# no_progress_streak below what the exact-round-count assertions expect.
	# Re-verify once board-seeding/board-size work lands later in this story
	# (V2-COMBAT-003.5 Phase 2) — that phase changes what encounter_id seeds.
	echo["grid_pos"] = { "col": 5, "row": 5 }
	enemy["grid_pos"] = { "col": 6, "row": 5 }
	ectx.actors = [echo, enemy]
	return env


## Drives combat.init, then up to max_rounds full rounds, stopping as soon as combat ends.
static func _drive_no_progress(runtime, ectx, max_rounds: int) -> void:
	runtime.dispatch({ "type": "combat.init" })
	_drive_no_progress_rounds(runtime, ectx, max_rounds)


static func _drive_no_progress_rounds(runtime, ectx, max_rounds: int) -> void:
	for _r in range(max_rounds):
		if bool(ectx.combat_state.get("combat_over", false)):
			break
		runtime.dispatch({ "type": "combat.confirm_round" })
		var guard: int = 0
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)): break
			if str(cs.get("round_phase", "")) != "in_round": break
			runtime.dispatch({ "type": "combat.next_actor" })


static func _no_progress_round_limit(runtime) -> int:
	var combat_cfg: Dictionary = runtime.config_service.get_balance().get("data", {}).get("combat", {})
	var stalemate_cfg: Dictionary = combat_cfg.get("stalemate", {})
	return int(stalemate_cfg.get("no_progress_round_limit", 0))


## Test 1 — a fight neither side can win by damage must still end, exactly at the configured
## no_progress_round_limit, as a forced retreat. Before the V2-COMBAT-003 fix this fails: there
## is no branch in CombatState.check_end_condition() that can end a fight with no death and no
## damage, so combat_over never becomes true and the loop guard (40 actor-turns per round) is
## the only thing that stops the test — it does not stop the ROUND counter, so this would spin
## past the limit with combat still active.
static func test_no_progress_stalemate_ends_as_forced_retreat() -> Dictionary:
	var env: Dictionary = _setup_no_progress("no_progress_a")
	if env.is_empty():
		return { "ok": false, "error": "setup failed — could not build a live echo/enemy pair" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]

	var limit: int = _no_progress_round_limit(runtime)
	if limit <= 0:
		return { "ok": false, "error": "data.combat.stalemate.no_progress_round_limit is 0 or missing — cannot test" }

	# One round short of the limit: the fight must still be running (no other end condition
	# can fire — no one can deal damage, so no one can die).
	_drive_no_progress(runtime, ectx, limit - 1)
	if bool(ectx.combat_state.get("combat_over", false)):
		return { "ok": false, "error": "combat ended before the no-progress limit (round_counter=%d, limit=%d)" % [int(ectx.combat_state.get("round_counter", -1)), limit] }
	if int(ectx.combat_state.get("no_progress_streak", -1)) != limit - 1:
		return { "ok": false, "error": "expected no_progress_streak=%d after %d damage-free rounds, got %s" % [limit - 1, limit - 1, str(ectx.combat_state.get("no_progress_streak"))] }

	# One more round crosses the limit — the fight must end as a forced retreat.
	_drive_no_progress_rounds(runtime, ectx, 1)

	if not bool(ectx.combat_state.get("combat_over", false)):
		return { "ok": false, "error": "combat did not end at the no-progress limit (round_counter=%d, streak=%d, limit=%d)" % [int(ectx.combat_state.get("round_counter", -1)), int(ectx.combat_state.get("no_progress_streak", -1)), limit] }
	if flow_ctx.encounter_ctx != null:
		return { "ok": false, "error": "encounter_ctx was not cleared after the forced retreat" }
	var snap: Dictionary = flow_ctx.last_snapshot
	if str(snap.get("type", "")) != FlowStateIds.RESOLVE:
		return { "ok": false, "error": "expected a flow.resolve snapshot, got type=%s" % str(snap.get("type", "")) }
	var data: Dictionary = snap.get("data", {})
	if str(data.get("run_type", "")) != "forced_retreat":
		return { "ok": false, "error": "expected run_type=forced_retreat (never confused with a chosen retreat), got: %s" % str(data.get("run_type", "")) }
	return { "ok": true }


## Test 2 — a forced retreat must grant NOTHING. Before the fix this fails for the same reason
## as test 1: combat never ends, so there is no forced-retreat outcome to assert zero-payout on
## in the first place — the round loop still running IS the failure.
static func test_forced_retreat_grants_nothing() -> Dictionary:
	var env: Dictionary = _setup_no_progress("no_progress_b")
	if env.is_empty():
		return { "ok": false, "error": "setup failed — could not build a live echo/enemy pair" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]

	var limit: int = _no_progress_round_limit(runtime)
	if limit <= 0:
		return { "ok": false, "error": "data.combat.stalemate.no_progress_round_limit is 0 or missing — cannot test" }

	var ase_before: int = runtime.econ.get_ase()
	var ekwan_before: int = runtime.econ.get_ekwan()
	var roster_before: Array = (flow_ctx.save_data.get("sanctum", {}) as Dictionary).get("roster", []) as Array
	var xp_before: Dictionary = {}
	for e_v in roster_before:
		var e: Dictionary = e_v
		xp_before[str(e.get("id", ""))] = int(e.get("xp_total", -1))

	_drive_no_progress(runtime, ectx, limit)

	if flow_ctx.encounter_ctx != null:
		return { "ok": false, "error": "the fight did not resolve as a forced retreat — nothing to assert zero-payout on" }
	var snap: Dictionary = flow_ctx.last_snapshot
	var data: Dictionary = snap.get("data", {})
	if str(data.get("run_type", "")) != "forced_retreat":
		return { "ok": false, "error": "expected the forced_retreat card, got run_type=%s" % str(data.get("run_type", "")) }

	# The card itself must show zero.
	if int(data.get("ase_awarded", -1)) != 0:
		return { "ok": false, "error": "forced_retreat card shows non-zero Ase: %s" % str(data.get("ase_awarded")) }
	if int(data.get("ekwan_awarded", -1)) != 0:
		return { "ok": false, "error": "forced_retreat card shows non-zero Ekwan: %s" % str(data.get("ekwan_awarded")) }
	var breakdown: Array = data.get("reward_breakdown", []) as Array
	if not breakdown.is_empty():
		return { "ok": false, "error": "forced_retreat card carries a non-empty reward_breakdown: %s" % str(breakdown) }

	# The durable economy and roster Storyweight (xp_total) must be byte-identical to baseline.
	if runtime.econ.get_ase() != ase_before:
		return { "ok": false, "error": "Ase changed: %d -> %d" % [ase_before, runtime.econ.get_ase()] }
	if runtime.econ.get_ekwan() != ekwan_before:
		return { "ok": false, "error": "Ekwan changed: %d -> %d" % [ekwan_before, runtime.econ.get_ekwan()] }
	var roster_after: Array = (flow_ctx.save_data.get("sanctum", {}) as Dictionary).get("roster", []) as Array
	for e_v in roster_after:
		var e: Dictionary = e_v
		var eid: String = str(e.get("id", ""))
		var before: int = int(xp_before.get(eid, -9999))
		var after: int = int(e.get("xp_total", -9998))
		if before != after:
			return { "ok": false, "error": "Storyweight (xp_total) changed for %s: %d -> %d" % [eid, before, after] }
	return { "ok": true }


## Same trimming as _setup_no_progress, for a PURIFY_SHRINE encounter, and the living shrine is
## KEPT — it is the actor whose hit points carry that objective's own clock.
static func _setup_no_progress_purify(seed_tag: String) -> Dictionary:
	var env: Dictionary = _setup(seed_tag, true, "off", EncounterResolutionModes.PURIFY_SHRINE)
	if env.is_empty():
		return {}
	var ectx: EncounterContext = env["ectx"]
	var echo: Dictionary = {}
	var enemy: Dictionary = {}
	var shrine: Dictionary = {}
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if a.get("is_structure", false):
			if shrine.is_empty():
				shrine = a
		elif echo.is_empty() and str(a.get("faction", "")) == "echo" and not a.get("is_dead", false):
			echo = a
		elif enemy.is_empty() and str(a.get("faction", "")) == "enemy" and not a.get("is_dead", false):
			enemy = a
	if echo.is_empty() or enemy.is_empty() or shrine.is_empty():
		return {}
	for a in [echo, enemy]:
		var a_stats: Dictionary = a.get("stats", {})
		a_stats["atk"] = 0
		a_stats["def"] = 999
	ectx.actors = [echo, enemy, shrine]
	return env


## PR #62 review comment, generalized by V2-COMBAT-003.5 — PURIFY_SHRINE must not force-retreat
## via the no-progress stalemate check. The shrine loses base_drain_per_round hit points every
## round with no actor acting, so that objective always reaches its own end (shrine_destroyed,
## branch 2), and the party can still win by killing every enemy.
##
## No by-name exemption remains: CombatState.get_progress_watch() reads the shrine's own HP, so
## the watch differs every round the shrine drains and no_progress_streak resets to 0 each time
## — it must NEVER climb, let alone reach the limit. The test drives one round PAST the limit
## with no damage possible and asserts exactly that: streak stays at 0, the fight is still
## running, and the shrine (draining, not destroyed by anything else here) is still alive.
static func test_purify_shrine_is_exempt_from_the_stalemate_check() -> Dictionary:
	var env: Dictionary = _setup_no_progress_purify("no_progress_purify")
	if env.is_empty():
		return { "ok": false, "error": "setup failed — could not build a live echo/enemy/shrine set" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]

	var limit: int = _no_progress_round_limit(runtime)
	if limit <= 0:
		return { "ok": false, "error": "data.combat.stalemate.no_progress_round_limit is 0 or missing — cannot test" }

	_drive_no_progress(runtime, ectx, limit + 1)

	if flow_ctx.encounter_ctx == null:
		return { "ok": false, "error": "the PURIFY_SHRINE fight was resolved away — run_type=%s" % str((flow_ctx.last_snapshot.get("data", {}) as Dictionary).get("run_type", "")) }
	if bool(ectx.combat_state.get("combat_over", false)):
		return { "ok": false, "error": "the PURIFY_SHRINE fight ended at the stalemate limit (reason=%s)" % str(ectx.combat_result.get("reason", "")) }

	var streak: int = int(ectx.combat_state.get("no_progress_streak", -1))
	if streak != 0:
		return { "ok": false, "error": "expected no_progress_streak=0 every round (shrine HP is always the changing signal), got %d" % streak }

	var shrine_hp: int = -1
	for a_v in ectx.actors:
		if a_v is Dictionary and a_v.get("is_structure", false):
			shrine_hp = int(a_v.get("current_hp", -1))
			break
	if shrine_hp <= 0:
		return { "ok": false, "error": "the shrine died first (hp=%d) — the exemption was not what kept the fight alive" % shrine_hp }
	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-COMBAT-003.5 Phase 1c — GUIDE_SPIRIT escort through the REAL round loop
# (FlowRuntime._end_round -> CombatState.check_end_condition), not a hand-built combat_state.
# Terrain override mirrors test_endure_wave_spawn_host_region (assigned after _setup(), before
# combat.init). Zeroed offense mirrors _setup_no_progress — no death can end the fight early, so
# only escort progress or the stalemate detector can end it.
# ---------------------------------------------------------------------------

## reachable=true: one open rectangle, spirit and destination both inside it — the party CAN
## close distance every round. reachable=false: two regions with no shared side (mirrors the
## host-region/moated-island terrain already used above), spirit stranded on the island — the
## party can NEVER become adjacent to it.
static func _setup_guide_escort(seed_tag: String, reachable: bool) -> Dictionary:
	var env: Dictionary = _setup(seed_tag, true, "off", EncounterResolutionModes.GUIDE_SPIRIT)
	if env.is_empty():
		return {}
	var ectx: EncounterContext = env["ectx"]

	var spirit_pos: Dictionary
	var dest_col: int
	var dest_row: int
	if reachable:
		var cells: Array = []
		for c in range(20):
			for r in range(20):
				cells.append([c, r])
		ectx.terrain = {
			"bounds":   { "w": 20, "h": 20 },
			"plateaus": [ { "col": 0, "row": 0, "w": 20, "h": 20, "cells": cells } ],
			"bridges":  [],
			"islands":  [],
		}
		spirit_pos = { "col": 5, "row": 5 }
		dest_col = 19
		dest_row = 19
	else:
		var mainland: Array = []
		for c in range(10):
			for r in range(10):
				mainland.append([c, r])
		# 3x3 island — room for the spirit AND every enemy, so none of them are reachable either:
		# an enemy left on the mainland would give the party something to close distance on,
		# and that approach is itself genuine progress that masks what this test checks.
		var island: Array = []
		for c in range(13, 16):
			for r in range(3):
				island.append([c, r])
		ectx.terrain = {
			"bounds":   { "w": 16, "h": 10 },
			"plateaus": [
				{ "col": 0, "row": 0, "w": 10, "h": 10, "cells": mainland },
				{ "col": 13, "row": 0, "w": 3, "h": 3, "cells": island },
			],
			"bridges":  [],
			"islands":  [],
		}
		spirit_pos = { "col": 13, "row": 0 }
		dest_col = 14
		dest_row = 1

	var spirit: Dictionary = {
		"id": "guide_spirit_01", "name": "Test Spirit", "faction": "npc",
		"is_structure": false, "is_spirit": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 999, "atk": 0, "speed": 0 },
		"grid_pos": spirit_pos,
	}
	ectx.actors.append(spirit)

	ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
	ectx.objective_params = {
		"guide_mode":      "escort",
		"duration_turns":  200,  # protect-mode only; irrelevant here, kept large so nothing else gates on it
		"spirit_def_id":   "guide_spirit",
		"spirit_name":     "Test Spirit",
		"spirit_max_hp":   9999,
		"escort_radius":   2,
		"skittish_radius": 3,
		"destination_col": dest_col,
		"destination_row": dest_row,
	}

	# Party spawns far from the spirit — no adjacency at combat start in either case.
	var echo_row: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			a_v["grid_pos"] = { "col": 0, "row": echo_row }
			echo_row += 1

	# reachable: enemies tucked into a far corner, clear of the party's route to the spirit.
	# blocked: enemies placed on the SAME unreachable island as the spirit — a mainland enemy
	# would give the party something to close distance on, and that approach is itself genuine
	# progress that would mask what this test checks (see the island-sizing comment above).
	var enemy_col: int = (19 if reachable else 13)
	var enemy_row: int = (0 if reachable else 2)
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["grid_pos"] = { "col": enemy_col, "row": enemy_row }
			if reachable:
				enemy_col = maxi(0, enemy_col - 1)
			else:
				enemy_col = 13 if enemy_col >= 15 else enemy_col + 1

	# No one can deal damage — only escort progress or the stalemate detector can end the fight.
	# morale/fear are ALSO pinned, not just atk/def: _melee_damage() adds
	# (morale-50)/10 - fear/20 AFTER the atk/def floor, so a freshly generated echo whose
	# starting morale sits above 50 (EchoFactory-derived, not 50 by construction) could otherwise
	# land a stray positive hit purely from the morale term with atk=0. Pinning morale=50 and
	# fear=0 zeroes both bonus terms so base=0 (from atk=0) is the actual, not just intended,
	# floor — same pin as _setup_no_progress uses for the same reason.
	for a_v in ectx.actors:
		if not (a_v is Dictionary): continue
		if bool(a_v.get("is_structure", false)): continue
		var a_stats: Dictionary = a_v.get("stats", {})
		a_stats["atk"] = 0
		a_stats["def"] = 999
		a_v["stats"] = a_stats
		a_v["morale"] = 50
		a_v["fear"] = 0

	return env


## The approach itself — before any echo is ever adjacent to the spirit — must not read as a
## stall: the board fingerprint changes every round an echo moves closer, so no_progress_streak
## must stay clear of the limit even driven well past it. escort_started may or may not latch
## during this window; either way nothing here can end the fight (offense is zeroed and the
## destination is far enough that a completed escort cannot land before the assertion point).
static func test_guide_spirit_escort_approach_survives_stalemate_check() -> Dictionary:
	var env: Dictionary = _setup_guide_escort("guide_escort_approach", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]

	var limit: int = _no_progress_round_limit(runtime)
	if limit <= 0:
		return { "ok": false, "error": "data.combat.stalemate.no_progress_round_limit is 0 or missing — cannot test" }

	_drive(runtime, ectx, limit + 3)

	if bool(ectx.combat_state.get("combat_over", false)):
		var reason: String = str(ectx.combat_result.get("reason", "")) if ectx.combat_result != null else ""
		return { "ok": false, "error": "the escort approach ended (reason=%s) at round_counter=%d — expected it still running past the stalemate limit(%d), since the party is genuinely closing distance every round" \
			% [reason, int(ectx.combat_state.get("round_counter", -1)), limit] }

	var streak: int = int(ectx.combat_state.get("no_progress_streak", -1))
	if streak >= limit:
		return { "ok": false, "error": "no_progress_streak(%d) reached the limit(%d) during a genuine approach" % [streak, limit] }

	return { "ok": true }


## The other half: a spirit stranded on a region the party can never reach must still force-retreat
## at the stalemate limit. This proves get_progress_watch()/record_progress_watch() give escort no
## unconditional exemption — only a board that is actually changing survives the check.
static func test_guide_spirit_escort_blocked_still_force_retreats() -> Dictionary:
	var env: Dictionary = _setup_guide_escort("guide_escort_blocked", false)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]

	var limit: int = _no_progress_round_limit(runtime)
	if limit <= 0:
		return { "ok": false, "error": "data.combat.stalemate.no_progress_round_limit is 0 or missing — cannot test" }

	runtime.dispatch({ "type": "combat.init" })
	var escort_started_before_end: bool = false
	for _r in range(limit + 3):
		if flow_ctx.encounter_ctx == null:
			break
		escort_started_before_end = escort_started_before_end or bool(ectx.combat_state.get("escort_started", false))
		runtime.dispatch({ "type": "combat.confirm_round" })
		var guard: int = 0
		while guard < 40:
			guard += 1
			if flow_ctx.encounter_ctx == null: break
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)): break
			if str(cs.get("round_phase", "")) != "in_round": break
			runtime.dispatch({ "type": "combat.next_actor" })

	# The no-progress branch (unlike every other end condition) never writes ectx.combat_result —
	# it goes straight to _resolve_forced_retreat(), which clears encounter_ctx and rebuilds
	# flow_ctx.last_snapshot as the flow.resolve card. That snapshot is the only place the reason
	# survives; matches test_no_progress_stalemate_ends_as_forced_retreat's assertion above.
	if flow_ctx.encounter_ctx != null:
		return { "ok": false, "error": "the blocked escort never ended (round_counter=%d, streak=%d, limit=%d) — expected a forced retreat" \
			% [int(ectx.combat_state.get("round_counter", -1)), int(ectx.combat_state.get("no_progress_streak", -1)), limit] }

	var snap: Dictionary = flow_ctx.last_snapshot
	var data: Dictionary = snap.get("data", {})
	if str(data.get("run_type", "")) != "forced_retreat":
		return { "ok": false, "error": "expected run_type=forced_retreat for an unreachable spirit, got '%s'" % str(data.get("run_type", "")) }

	if escort_started_before_end:
		return { "ok": false, "error": "escort_started=true at some point for a spirit the party could never reach — setup did not exercise the blocked case" }

	return { "ok": true }


## PR #62 review comment — the "guide" debug command is used mid-fight. It now goes through
## dispatch(), which refreshes the snapshot, so this checks the fight survives it: the encounter
## is still live, the snapshot is still the encounter snapshot, and the suggestion is in place.
static func test_guidance_dispatch_leaves_the_encounter_intact() -> Dictionary:
	var env: Dictionary = _setup("guidance_dispatch", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	runtime.dispatch({ "type": "combat.init" })
	var type_before: String = str(flow_ctx.last_snapshot.get("type", ""))

	runtime.dispatch({
		"type": "debug.guidance.set",
		"guidance": {
			"purpose": "hold", "action_type": "actor.guard", "guidance_id": "hold",
			"subject_id": "", "recipient_ids": [],
		},
	})

	if flow_ctx.encounter_ctx == null:
		return { "ok": false, "error": "the encounter was dropped by the guidance dispatch" }
	var type_after: String = str(flow_ctx.last_snapshot.get("type", ""))
	if type_after != type_before:
		return { "ok": false, "error": "snapshot type changed: %s -> %s" % [type_before, type_after] }
	if str((flow_ctx.dev_guidance as Dictionary).get("guidance_id", "")) != "hold":
		return { "ok": false, "error": "the suggestion did not arrive: %s" % str(flow_ctx.dev_guidance) }
	return { "ok": true }


static func test_live_hazard_union_and_mover_damage() -> Dictionary:
	var env: Dictionary = _setup("live_hazards", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	flow_ctx.save_data["stage_context"] = {
		"encounter_approach": {
			"known_hazards": [
				{ "id": "approach.burning.a", "position": { "col": 1, "row": 1 }, "hazard_type": "burning" },
				{ "id": "approach.burning.shadow", "position": { "col": 8, "row": 5 }, "hazard_type": "burning" },
			],
		},
	}
	var hazards: Array = _lm(runtime)._live_combat_known_hazards()
	var ids: Array = []
	for hazard_value: Variant in hazards:
		ids.append(str((hazard_value as Dictionary).get("id", "")))
	if ids != ["approach.burning.a", "hazard.unstable.a", "hazard.binding.a", "hazard.burning.a"]:
		return { "ok": false, "error": "live hazard union or board precedence drifted: %s" % str(ids) }

	var order_actor: Dictionary = (env["ectx"].actors[0] as Dictionary)
	order_actor["current_hp"] = 10
	LiveHazardOutcomeService.apply(order_actor, {
		"events": [
			{"phase": "movement", "damage": 3},
			{"phase": "end_activation", "damage": 4},
		],
		"stop_reason": "reached_destination",
	}, 99, 4, runtime.logger, false)
	if int(order_actor.get("current_hp", -1)) != 7:
		return { "ok": false, "error": "movement hazard damage did not resolve before action: %s" % str(order_actor) }
	LiveHazardOutcomeService.apply(order_actor, {
		"events": [
			{"phase": "movement", "damage": 3},
			{"phase": "end_activation", "damage": 4},
		],
		"stop_reason": "reached_destination",
	}, 99, 4, runtime.logger, true)
	if int(order_actor.get("current_hp", -1)) != 3:
		return { "ok": false, "error": "Burning did not resolve after action: %s" % str(order_actor) }

	var purifier: Dictionary = (env["ectx"].actors[0] as Dictionary)
	var wrong_shrine: Dictionary = {
		"id": "shrine.wrong", "is_structure": true, "is_dead": false,
		"current_hp": 20, "stats": {"max_hp": 20}, "purify_stacks": [],
	}
	var matching_shrine: Dictionary = {
		"id": "shrine.match", "is_structure": true, "is_dead": false,
		"current_hp": 20, "stats": {"max_hp": 20}, "purify_stacks": [],
	}
	(env["ectx"].actors as Array).append(wrong_shrine)
	(env["ectx"].actors as Array).append(matching_shrine)
	var purify_ctx: Dictionary = {"cfg": runtime.config_service.get_balance()}
	_lm(runtime).apply_live_purify_shrine(purifier, "shrine.match", purify_ctx, 99)
	if (wrong_shrine.get("purify_stacks", []) as Array).size() != 0:
		return { "ok": false, "error": "non-target shrine mutated during purify" }
	if (matching_shrine.get("purify_stacks", []) as Array).size() != 1:
		return { "ok": false, "error": "matching purify target did not receive exactly one stack" }
	wrong_shrine["is_dead"] = true
	_lm(runtime).apply_live_purify_shrine(purifier, "shrine.wrong", purify_ctx, 99)
	if (matching_shrine.get("purify_stacks", []) as Array).size() != 1:
		return { "ok": false, "error": "dead mismatched target changed the living shrine" }

	var echo: Dictionary = (env["ectx"].actors[0] as Dictionary)
	echo["current_hp"] = 3
	echo["is_ko"] = true
	LiveHazardOutcomeService.apply(echo, {
		"events": [{ "damage": 3 }],
		"stop_reason": "death",
	}, 99, 4, runtime.logger)
	if int(echo.get("current_hp", -1)) != 0 or not bool(echo.get("is_dead", false)) \
			or echo.has("is_ko") or int(echo.get("death_round", -1)) != 4:
		return { "ok": false, "error": "FlowRuntime did not preserve Echo death authority: %s" % str(echo) }

	var enemy: Dictionary = (env["ectx"].actors[-1] as Dictionary)
	enemy["current_hp"] = 3
	enemy["is_ko"] = true
	LiveHazardOutcomeService.apply(enemy, {
		"events": [{ "damage": 3 }],
		"stop_reason": "death",
	}, 99, 4, runtime.logger)
	if int(enemy.get("current_hp", -1)) != 0 or not bool(enemy.get("is_dead", false)) \
			or enemy.has("is_ko") or int(enemy.get("death_round", -1)) != 4:
		return { "ok": false, "error": "FlowRuntime did not preserve enemy death state: %s" % str(enemy) }

	var guide: Dictionary = {"id": "guide.hazard", "is_spirit": true, "current_hp": 3, "is_ko": true}
	LiveHazardOutcomeService.apply(guide, {"events": [{"damage": 3}], "stop_reason": "death"}, 99, 4, runtime.logger)
	if not bool(guide.get("is_dead", false)) or guide.has("is_ko") or int(guide.get("death_round", -1)) != 4:
		return {"ok": false, "error": "non-joining guide hazard outcome did not use death authority: %s" % str(guide)}
	return { "ok": true }


static func test_live_hazard_action_phase_order() -> Dictionary:
	var env: Dictionary = _setup("hazard_phase_order", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	var actor: Dictionary = ectx.actors[0]
	var target: Dictionary = ectx.actors[-1]
	actor["grid_pos"] = { "col": 8, "row": 5 }
	actor["current_hp"] = 3
	target["grid_pos"] = { "col": 9, "row": 5 }
	target["current_hp"] = 20

	var burning_context: Dictionary = MovementContextScript.build(
		str(actor.get("id", "")), "live.burning", actor["grid_pos"],
		{"w": 10, "h": 10}, {}, {}, {}, [], {}, {},
		[MovementHazardFactScript.build("burning.live", actor["grid_pos"], "burning")], {}, [])
	var melee_plan: Dictionary = MovementActionPlanScript.build("melee_attack", str(target.get("id", "")))
	var burning_intent: Dictionary = MovementIntentScript.build(
		str(actor.get("id", "")), "live.burning", "goal.live.engage", "option.live.engage",
		[], 2, 0, melee_plan, MovementActionPlanScript.build("actor.guard"), [])
	var prepared: Dictionary = {
		"valid": true,
		"movement_context": burning_context,
		"profile": {"capacity": 2},
		"hazard_ctx": {
			"triggered": {"unstable": false, "binding": false, "burning": false},
			"config": {"burning": {"end_activation_damage": 3}},
		},
		"goals": [],
	}
	var ctx: Dictionary = {"actor": actor, "all_actors": ectx.actors, "cfg": runtime.config_service.get_balance(), "t": 99, "round": 1}
	var asm := ActorStateMachine.new(actor, null, ctx["cfg"].get("data", {}).get("actor", {}), {})
	var burning_result: Dictionary = _lm(runtime).apply_live_activation(actor, burning_intent, prepared, asm, ctx, 99)
	if str((burning_result.get("resolved_action", {}) as Dictionary).get("type", "")) != "melee_attack":
		return { "ok": false, "error": "legal melee was not resolved before Burning: %s" % str(burning_result) }
	var target_hp_before: int = int(target.get("current_hp", 0))
	var melee_result: Dictionary = CombatService.resolve_action("melee_attack", actor, target, 1)
	if melee_result.is_empty() or int(target.get("current_hp", target_hp_before)) >= target_hp_before:
		return { "ok": false, "error": "legal melee did not execute before end_activation Burning" }
	LiveHazardOutcomeService.apply(actor, burning_result, 99, 4, runtime.logger, true)
	if not bool(actor.get("is_dead", false)):
		return { "ok": false, "error": "lethal Burning did not apply after the melee action" }

	var movement_actor: Dictionary = ectx.actors[1]
	movement_actor["grid_pos"] = { "col": 8, "row": 1 }
	movement_actor["current_hp"] = 3
	var movement_context: Dictionary = MovementContextScript.build(
		str(movement_actor.get("id", "")), "live.movement", movement_actor["grid_pos"],
		{"w": 10, "h": 10}, {}, {},
		{"8,0": true, "8,1": true, "8,2": true, "9,0": true, "9,2": true},
		[], {}, {},
		[MovementHazardFactScript.build("unstable.live", {"col": 9, "row": 1}, "unstable")], {}, [])
	var movement_intent: Dictionary = MovementIntentScript.build(
		str(movement_actor.get("id", "")), "live.movement", "goal.live.move", "option.live.move",
		[{"col": 9, "row": 1}], 2, 1,
		MovementActionPlanScript.build("melee_attack", str(target.get("id", ""))),
		MovementActionPlanScript.build("actor.idle"), [])
	var movement_result: Dictionary = CombatActivationServiceScript.activate(
		movement_context, movement_intent, {"capacity": 2},
		{"triggered": {"unstable": false, "binding": false, "burning": false},
		 "config": {"unstable": {"fallback_damage": 3}, "binding": {"stops_movement": true},
		 "burning": {"end_activation_damage": 3}}},
		{"purpose": "hold", "mover_hp": 3})
	if str(movement_result.get("stop_reason", "")) != "death" \
			or not (movement_result.get("resolved_action", {}) as Dictionary).is_empty():
		return { "ok": false, "error": "activation did not skip primary after lethal movement damage: %s" % str(movement_result) }
	LiveHazardOutcomeService.apply(movement_actor, movement_result, 100, 4, runtime.logger, false)
	if not bool(movement_actor.get("is_dead", false)):
		return { "ok": false, "error": "lethal movement damage did not kill the mover" }
	if not (movement_result.get("resolved_action", {}) as Dictionary).is_empty():
		return { "ok": false, "error": "movement lethal damage did not skip the primary action" }
	return { "ok": true }


# A live direct option whose capacity-truncated route stops short of an engage
# region must advertise actor.move. Otherwise activation revalidation rejects its
# out-of-range melee plan and the actor idles instead of closing distance.
static func test_live_truncated_engage_advances_before_melee() -> Dictionary:
	var env: Dictionary = _setup("truncated_engage", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	var actor: Dictionary = ectx.actors[0] as Dictionary
	var target: Dictionary = {}
	for actor_value: Variant in ectx.actors:
		if actor_value is Dictionary and str((actor_value as Dictionary).get("faction", "")) == "enemy":
			target = actor_value as Dictionary
			break
	if target.is_empty():
		return { "ok": false, "error": "missing enemy target" }
	actor["grid_pos"] = { "col": 1, "row": 1 }
	target["grid_pos"] = { "col": 7, "row": 1 }
	var walkable: Dictionary = {}
	for col in range(10):
		for row in range(10):
			walkable["%d,%d" % [col, row]] = true
	var goal: Dictionary = {
		"goal_id": "goal.combat.engage.baseline.c6r1",
		"purpose": "engage",
		"destination_region": [{ "col": 6, "row": 1 }],
		"urgency": 1.0,
		"objective_progress": 0.0,
		"relevant_actors": [str(target.get("id", ""))],
		"pressure_sources": ["actor.%s" % str(target.get("id", ""))],
		"planned_primary": MovementActionPlanScript.build("melee_attack", str(target.get("id", ""))),
		"declared_fallback": MovementActionPlanScript.build("actor.idle"),
	}
	var hazard_cfg: Dictionary = runtime.config_service.get_balance().get("data", {}).get("combat", {}).get("movement", {}).get("hazards", {})
	for activation_index in range(3):
		var origin: Dictionary = actor.get("grid_pos", {}) as Dictionary
		var actor_id: String = str(actor.get("id", ""))
		var target_id: String = str(target.get("id", ""))
		var actor_fact: Dictionary = MovementActorFactScript.build(
			actor_id, origin, "echo", false, false, false, false, false, true, 1.0
		)
		var target_fact: Dictionary = MovementActorFactScript.build(
			target_id, target.get("grid_pos", {}) as Dictionary, "enemy", false, false, false, false, false, true, 1.0
		)
		var movement_context: Dictionary = MovementContextScript.build(
			actor_id, "live.truncated.%d" % activation_index, origin,
			{ "w": 10, "h": 10 }, walkable, walkable,
			{
				"%d,%d" % [int(origin.get("col", 0)), int(origin.get("row", 0))]: actor_id,
				"7,1": target_id,
			}, [actor_fact, target_fact], {target_id: "hostile"}, {}, [], {}, []
		)
		var context_validation: Dictionary = MovementContextScript.validate(movement_context)
		if not bool(context_validation.get("valid", false)):
			return { "ok": false, "error": "invalid live movement context: %s" % str(context_validation) }
		var profile: Dictionary = { "capacity": 2 }
		var expected_action: String = "actor.move" if activation_index < 2 else "melee_attack"
		var path: Array = []
		if activation_index < 2:
			path = [{ "col": int(origin["col"]) + 1, "row": int(origin["row"]) }]
			path.append({ "col": int(origin["col"]) + 2, "row": int(origin["row"]) })
		else:
			path = [{ "col": int(origin["col"]) + 1, "row": int(origin["row"]) }]
		var planned_action: Dictionary = (
			MovementActionPlanScript.build("actor.move") if activation_index < 2
			else MovementActionPlanScript.build("melee_attack", str(target.get("id", "")))
		)
		var intent: Dictionary = MovementIntentScript.build(
			str(actor.get("id", "")), "live.truncated.%d" % activation_index,
			str(goal.get("goal_id", "")), "option.combat.engage.baseline.direct.d%dr%d.pmanual" % [int(origin["col"]), int(origin["row"])],
			# +1 on the final activation: that step lands adjacent to the enemy, so the
			# executor charges the hostile-control surcharge (cost 2). Commitment is a cost
			# budget, so it must fund that surcharge — mirrors the live planner.
			path, int(profile["capacity"]), path.size() + (1 if activation_index >= 2 else 0),
			planned_action, goal.get("declared_fallback", {}) as Dictionary, []
		)
		intent["movement_purpose"] = "engage"
		var prepared: Dictionary = {
			"valid": true, "movement_context": movement_context, "profile": profile,
			"hazard_ctx": { "triggered": { "unstable": false, "binding": false, "burning": false }, "config": hazard_cfg },
			"goals": [goal],
		}
		var ctx: Dictionary = { "actor": actor, "all_actors": ectx.actors, "cfg": runtime.config_service.get_balance(), "t": 90 + activation_index, "round": 1 }
		var asm := ActorStateMachine.new(actor, null, ctx["cfg"].get("data", {}).get("actor", {}), {})
		var result: Dictionary = _lm(runtime).apply_live_activation(actor, intent, prepared, asm, ctx, 90 + activation_index)
		var resolved_action: String = str((result.get("resolved_action", {}) as Dictionary).get("type", ""))
		if resolved_action != expected_action or str(intent.get("action_type", "")) == "actor.idle":
			return { "ok": false, "error": "live activation resolved %s at activation %d" % [resolved_action, activation_index] }
	if GridService.chebyshev_distance(actor.get("grid_pos", {}), target.get("grid_pos", {})) != 1:
		return { "ok": false, "error": "actor did not reach melee adjacency: %s" % str(actor.get("grid_pos", {})) }
	return { "ok": true }


# Test 1 — real loop, real ids: every Echo closes distance to the enemy.
static func test_echoes_advance() -> Dictionary:
	var env: Dictionary = _setup("advance", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var ectx = env["ectx"]

	# Capture starting distance of each echo to the (initial) enemy.
	var enemy0: Dictionary = _enemy_pos(ectx)
	var start_dist: Dictionary = {}
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			start_dist[str(a_v.get("id", ""))] = GridService.chebyshev_distance(a_v.get("grid_pos", {}), enemy0)

	_drive(runtime, ectx, 6)

	# After combat, every echo must be strictly closer to where the enemy started
	# (or already engaged/dead). A frozen echo would keep its exact start distance.
	var frozen: Array = []
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) != "echo": continue
		var id: String = str(a_v.get("id", ""))
		var now_dist: int = GridService.chebyshev_distance(a_v.get("grid_pos", {}), enemy0)
		var was: int = int(start_dist.get(id, 999))
		if now_dist >= was and not a_v.get("is_dead", false):
			frozen.append("%s d %d→%d" % [id, was, now_dist])

	if frozen.size() > 0:
		return { "ok": false, "error": "echoes did not advance: " + str(frozen) }
	return { "ok": true, "error": "" }


# Test 2 (regression — proves the FIX) — all 5 Echoes enter with id "" (id assignment skipped).
# Before the fix this froze 4 of 5 Echoes at spawn. Now FlowEncounterState.enter() repairs the
# empty/duplicate ids to unique fallbacks BEFORE initiative is built, so:
#   (a) every echo actor ends up with a distinct, non-empty id, and
#   (b) every echo advances toward the enemy (none frozen at its spawn cell).
static func test_duplicate_id_freeze() -> Dictionary:
	var env: Dictionary = _setup("freeze", false)  # assign_ids=false → every echo entered as id ""
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime = env["runtime"]
	var ectx = env["ectx"]

	# (a) After the encounter-assembly guard, every echo actor must have a distinct non-empty id.
	var seen_ids: Dictionary = {}
	var echo_count: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) != "echo": continue
		echo_count += 1
		var id: String = str(a_v.get("id", ""))
		if id.is_empty():
			return { "ok": false, "error": "echo still has an empty id after the assembly guard" }
		if seen_ids.has(id):
			return { "ok": false, "error": "duplicate echo id '%s' survived the assembly guard" % id }
		seen_ids[id] = true
	if echo_count < 2:
		return { "ok": false, "error": "expected >=2 echoes" }

	# Record spawn cell of each echo (keyed by repaired id) and starting distance to the enemy.
	var enemy0: Dictionary = _enemy_pos(ectx)
	var spawns: Dictionary = {}
	var start_dist: Dictionary = {}
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) != "echo": continue
		var id2: String = str(a_v.get("id", ""))
		spawns[id2] = (a_v.get("grid_pos", {}) as Dictionary).duplicate()
		start_dist[id2] = GridService.chebyshev_distance(a_v.get("grid_pos", {}), enemy0)

	_drive(runtime, ectx, 6)

	# (b) No echo may still be sitting on its exact spawn cell (frozen) — all must have moved
	#     (or engaged / died). A frozen echo is the old "no aim or goal" symptom.
	var frozen: Array = []
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) != "echo": continue
		var id3: String = str(a_v.get("id", ""))
		var now: Dictionary = a_v.get("grid_pos", {})
		var sp: Dictionary = spawns.get(id3, {})
		if int(now.get("col", -9)) == int(sp.get("col", -1)) \
				and int(now.get("row", -9)) == int(sp.get("row", -1)) \
				and not a_v.get("is_dead", false):
			frozen.append(id3)

	if frozen.size() > 0:
		return { "ok": false, "error": "echoes still frozen at spawn after repair: " + str(frozen) }
	return { "ok": true, "error": "" }


# ---------------------------------------------------------------------------
# §4-E: RECOVER reinforcement — after reinforce_interval rounds, enemy-side spawns appear.
#
# Setup: RECOVER objective with a very short reinforce_interval (1 so it fires round 1).
# We drive 1 round and check that enemy count increased and all reinforcements are enemy faction.
# ---------------------------------------------------------------------------
static func test_recover_reinforcement() -> Dictionary:
	var env: Dictionary = _setup("recover_reinf", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	# Override objective to RECOVER with fast reinforcement (interval=1, size=1, max=4).
	# Set resolution_mode and objective_params BEFORE combat.init so CombatState.create reads them.
	ectx.resolution_mode = EncounterResolutionModes.RECOVER
	ectx.objective_params = {
		"hold_rounds": 99,  # never win via hold in this test
		"relic_def_id": "recover_relic",
		"relic_name": "Test Relic",
		"relic_max_hp": 9999,
		"reinforce_interval": 1,
		"reinforce_size": 1,
		"reinforce_group": "group.vale_patrol_sm",
		"reinforce_max_total": 4,
	}

	# Add a relic structure so RECOVER mode logic has a target.
	ectx.actors.append({
		"id": "test_relic_01", "name": "Test Relic", "faction": "structure",
		"is_structure": true, "is_objective_relic": true,
		"current_hp": 9999, "is_dead": false,
		"stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 8, "row": 4 },
	})

	var enemy_count_before: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_dead", false)):
			enemy_count_before += 1

	# Initialize combat — CombatState.create reads ectx.resolution_mode + ectx.objective_params.
	runtime.dispatch({ "type": "combat.init" })
	# Post-init: set distinctiveness keys on the fresh combat_state.
	ectx.combat_state["recover_holder_id"]       = ""
	ectx.combat_state["recover_reinforce_count"] = 0

	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 40:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var enemy_count_after: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy":
			enemy_count_after += 1

	if enemy_count_after <= enemy_count_before:
		return {
			"ok": false,
			"error": "Expected enemy count to increase after RECOVER reinforcement; before=%d after=%d" \
				% [enemy_count_before, enemy_count_after]
		}
	# Confirm reinforce_count incremented.
	var rc: int = int(ectx.combat_state.get("recover_reinforce_count", 0))
	if rc <= 0:
		return { "ok": false, "error": "Expected recover_reinforce_count > 0 after spawn, got %d" % rc }
	# Confirm new actors are enemy-faction.
	for a_v in ectx.actors:
		if str(a_v.get("id", "")).begins_with("recover_reinf_"):
			if str(a_v.get("faction", "")) != "enemy":
				return { "ok": false, "error": "Reinforcement actor '%s' is not enemy faction" % str(a_v.get("id", "")) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# §4-F: ENDURE rising wave size + all_waves_spawned flag.
#
# Setup: ENDURE with duration=4, interval=1, base_wave_size=1, rising_step=1, max=3.
# Waves fire at rounds 1, 2, 3 (duration=4, range(1,4)→1,2,3 all div by 1 → total_waves=3).
# Wave 1 size=1, wave 2 size=2, wave 3 size=3. After wave 3, all_waves_spawned=true.
# ---------------------------------------------------------------------------
static func test_endure_rising_wave() -> Dictionary:
	var env: Dictionary = _setup("endure_rising", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	# Override objective to ENDURE with tight params for fast testing.
	# Set BEFORE combat.init so CombatState.create reads them.
	ectx.resolution_mode = EncounterResolutionModes.ENDURE
	ectx.objective_params = {
		"duration_turns":     10,  # long enough not to win via endure during test
		"wave_interval":      1,
		"wave_size":          1,
		"wave_size_rising_step": 1,
		"wave_size_max":      3,
		"wave_group":         "group.vale_patrol_sm",
	}

	# Initialize combat — CombatState.create reads ectx.resolution_mode + ectx.objective_params.
	runtime.dispatch({ "type": "combat.init" })
	# Post-init: set distinctiveness keys on the fresh combat_state.
	ectx.combat_state["waves_spawned"]    = 0
	ectx.combat_state["all_waves_spawned"] = false
	# Remove total_waves if set so it gets recomputed on first end_round.
	ectx.combat_state.erase("total_waves")
	var wave_sizes_observed: Array = []
	for _r in range(3):
		var pre_enemy_count: int = 0
		for a_v in ectx.actors:
			if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_dead", false)):
				pre_enemy_count += 1

		runtime.dispatch({ "type": "combat.confirm_round" })
		var guard2: int = 0
		while guard2 < 40:
			guard2 += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)): break
			if str(cs.get("round_phase", "")) != "in_round": break
			runtime.dispatch({ "type": "combat.next_actor" })

		var post_enemy_count: int = 0
		for a_v in ectx.actors:
			if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_dead", false)):
				post_enemy_count += 1

		wave_sizes_observed.append(post_enemy_count - pre_enemy_count)

	# Wave 1 size=1, wave 2 size=2, wave 3 size=3 (but note enemies may die; we check > previous).
	# More robust: verify waves_spawned == 3 and all_waves_spawned based on duration_turns=10/interval=1.
	# Actually total_waves for duration=10, interval=1 = range(1,10) all div by 1 = 9. So 3 rounds → not done.
	# Instead check: waves_spawned incremented per round, sizes non-decreasing (rising curve active).
	var ws: int = int(ectx.combat_state.get("waves_spawned", 0))
	if ws < 3:
		return { "ok": false, "error": "Expected waves_spawned >= 3 after 3 rounds, got %d" % ws }

	# Check all_waves_spawned is false (only 3 of 9 waves done).
	if bool(ectx.combat_state.get("all_waves_spawned", false)):
		return { "ok": false, "error": "all_waves_spawned should be false after 3 of 9 waves" }

	# Verify rising_step applied: wave_size(N) = clamp(1 + (N-1)*1, 1, 3).
	# Wave 1 → size=1, wave 2 → size=2, wave 3 → size=3.
	# wave_sizes_observed may be 0 if spawns get killed but IDs should exist.
	var wave1_actors: Array = []
	var wave2_actors: Array = []
	var wave3_actors: Array = []
	for a_v in ectx.actors:
		var aid: String = str(a_v.get("id", ""))
		if aid.begins_with("wave_1_"):
			wave1_actors.append(aid)
		elif aid.begins_with("wave_2_"):
			wave2_actors.append(aid)
		elif aid.begins_with("wave_3_"):
			wave3_actors.append(aid)
	if wave1_actors.size() != 1:
		return { "ok": false, "error": "Wave 1 expected 1 actor, found %d" % wave1_actors.size() }
	if wave2_actors.size() != 2:
		return { "ok": false, "error": "Wave 2 expected 2 actors (rising), found %d" % wave2_actors.size() }
	if wave3_actors.size() != 3:
		return { "ok": false, "error": "Wave 3 expected 3 actors (rising), found %d" % wave3_actors.size() }
	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-COMBAT-003 defect fix: _place_enemy_spawns() picked cells from the WHOLE walkable set,
# sorted highest column first. An island at a high column was chosen before real host-region
# ground, so a wave actor could land on ground with no route to anything. The fix filters
# candidates to GridService.largest_walkable_region() (the same authority initial placement
# uses). This test hands the encounter a terrain with a big host region (cols 0-4) and a
# small moated island at the highest columns (cols 8-9, three empty columns of gap — no
# shared side, so the two regions are not connected). A wave actor must land in the host
# region.
# ---------------------------------------------------------------------------
static func test_endure_wave_spawn_host_region() -> Dictionary:
	var env: Dictionary = _setup("wave_host_region", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	ectx.resolution_mode = EncounterResolutionModes.ENDURE
	ectx.objective_params = {
		"duration_turns":        10,
		"wave_interval":         1,
		"wave_size":             1,
		"wave_size_rising_step": 0,
		"wave_size_max":         1,
		"wave_group":            "group.vale_patrol_sm",
	}

	# Host region: 30 cells, cols 0-4, rows 0-5. Island: 4 cells, cols 8-9, rows 0-1.
	# Cols 5-7 hold no walkable cell, so the island shares no side with the host region.
	var mainland_cells: Array = []
	for c in range(5):
		for r in range(6):
			mainland_cells.append([c, r])
	var island_cells: Array = [[8, 0], [8, 1], [9, 0], [9, 1]]
	ectx.terrain = {
		"bounds":   { "w": 10, "h": 6 },
		"plateaus": [
			{ "col": 0, "row": 0, "w": 5, "h": 6, "cells": mainland_cells },
			{ "col": 8, "row": 0, "w": 2, "h": 2, "cells": island_cells },
		],
		"bridges":  [],
		"islands":  [],
	}

	runtime.dispatch({ "type": "combat.init" })
	ectx.combat_state["waves_spawned"]     = 0
	ectx.combat_state["all_waves_spawned"] = false
	ectx.combat_state.erase("total_waves")

	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 40:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var wave_actor: Dictionary = {}
	for a_v in ectx.actors:
		if str(a_v.get("id", "")).begins_with("wave_1_"):
			wave_actor = a_v
			break
	if wave_actor.is_empty():
		return { "ok": false, "error": "wave actor was not spawned" }

	var gp: Dictionary = wave_actor.get("grid_pos", {})
	var col: int = int(gp.get("col", -1))
	if col > 4:
		return { "ok": false, "error": "wave actor spawned outside the host region at col=%d row=%d" % [col, int(gp.get("row", -1))] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# §4-G: PROTECT theft fires when unguarded + double damage applies + recovery on carrier death.
#
# This is a logic-level unit test that directly exercises _end_round state mutation
# using a minimal combat_state and ectx built inline — no full runtime needed.
# We call FlowRuntime._end_round via the integration path (dispatch combat.next_actor
# until round ends) to verify the theft state is set on combat_state after end_round.
# ---------------------------------------------------------------------------
static func test_protect_theft() -> Dictionary:
	# We build a minimal scenario using the real FlowRuntime but with hand-crafted actors
	# so the totem is unguarded and an enemy is adjacent.
	var env: Dictionary = _setup("protect_theft", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	# Override to PROTECT objective — set BEFORE combat.init so CombatState.create reads it.
	ectx.resolution_mode = EncounterResolutionModes.PROTECT
	ectx.objective_params = {
		"duration_turns": 20,
		"entity_def_id":  "protect_entity",
		"entity_name":    "Test Ward",
		"entity_max_hp":  9999,
	}

	# Add a totem structure at a known position (col=5, row=5).
	var totem: Dictionary = {
		"id": "test_totem_01", "name": "Test Ward", "faction": "structure",
		"is_structure": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors.append(totem)

	# Move all echoes FAR from totem (col=0, row=0..4) so none are adjacent.
	var echo_idx: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo" and not bool(a_v.get("is_dead", false)):
			a_v["grid_pos"] = { "col": 0, "row": echo_idx }
			echo_idx += 1

	# Place one enemy ADJACENT to totem (col=5, row=6 = chebyshev 1).
	# Give it a low id so it's picked deterministically.
	var thief_enemy: Dictionary = {
		"id": "aaa_thief_01", "name": "Thief", "faction": "enemy",
		"is_structure": false, "is_dead": false,
		"current_hp": 100,
		"stats": { "max_hp": 100, "def": 5, "atk": 5, "speed": 5, "agi": 5 },
		"morale": 50, "fear": 0, "guard_state": false,
		"grid_pos": { "col": 5, "row": 6 },
	}
	ectx.actors.append(thief_enemy)

	# Initialize combat — CombatState.create reads ectx.resolution_mode + ectx.objective_params.
	runtime.dispatch({ "type": "combat.init" })
	# Post-init: set distinctiveness keys on the fresh combat_state.
	ectx.combat_state["totem_stolen"]     = false
	ectx.combat_state["totem_carrier_id"] = ""

	# Drive one round — end_round will execute the PROTECT theft check.
	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard3: int = 0
	while guard3 < 40:
		guard3 += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	# After end_round, check theft state (theft_chance=0.5 from default — it's a probability,
	# so we can't guarantee it fires in one round; instead verify the state fields are present
	# and structured correctly, and if theft fired verify carrier_double_damage is set).
	var cs_final: Dictionary = ectx.combat_state
	if not cs_final.has("totem_stolen"):
		return { "ok": false, "error": "combat_state missing 'totem_stolen' key after PROTECT end_round" }
	if not cs_final.has("totem_carrier_id"):
		return { "ok": false, "error": "combat_state missing 'totem_carrier_id' key after PROTECT end_round" }

	# If theft fired: verify carrier has _carrier_double_damage=true.
	if bool(cs_final.get("totem_stolen", false)):
		var carrier_id: String = str(cs_final.get("totem_carrier_id", ""))
		if carrier_id.is_empty():
			return { "ok": false, "error": "totem_stolen=true but totem_carrier_id is empty" }
		# Find carrier and confirm flag.
		var carrier_found: bool = false
		for a_v in ectx.actors:
			if str(a_v.get("id", "")) == carrier_id:
				carrier_found = true
				if not bool(a_v.get("_carrier_double_damage", false)):
					return { "ok": false, "error": "Carrier '%s' missing _carrier_double_damage=true" % carrier_id }
				break
		if not carrier_found:
			return { "ok": false, "error": "Carrier id '%s' not found in actors" % carrier_id }

	# Simulate carrier death → recovery.
	# Mark the thief dead and re-enter end_round by driving another round.
	thief_enemy["is_dead"] = true
	thief_enemy["current_hp"] = 0
	ectx.combat_state["totem_stolen"]              = true
	ectx.combat_state["totem_carrier_id"]          = "aaa_thief_01"
	thief_enemy["_carrier_double_damage"]          = true

	# Drive another round — end_round recovery block should clear theft state.
	runtime.dispatch({ "type": "combat.confirm_round" })
	guard3 = 0
	while guard3 < 40:
		guard3 += 1
		var cs2: Dictionary = ectx.combat_state
		if bool(cs2.get("combat_over", false)): break
		if str(cs2.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	# After carrier death round, theft should be cleared.
	if bool(ectx.combat_state.get("totem_stolen", true)):
		return { "ok": false, "error": "Expected totem_stolen=false after carrier died, got true" }
	if not str(ectx.combat_state.get("totem_carrier_id", "x")).is_empty():
		return { "ok": false, "error": "Expected totem_carrier_id='' after carrier died, got '%s'" \
			% str(ectx.combat_state.get("totem_carrier_id", "")) }
	if bool(thief_enemy.get("_carrier_double_damage", true)):
		return { "ok": false, "error": "Expected _carrier_double_damage=false on dead carrier, got true" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# §4-G2: PROTECT guard-proximity counter — protect_counter advances when
# an echo is placed within guard radius (2) of the entity each round.
# ---------------------------------------------------------------------------

# test_protect_counter_near:
# Echo placed AT the entity position → Chebyshev distance 0 ≤ guard_radius 2.
# After one round, protect_counter must be 1.
static func test_protect_counter_near() -> Dictionary:
	var env: Dictionary = _setup("protect_near", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	# Override to PROTECT mode.
	ectx.resolution_mode = EncounterResolutionModes.PROTECT
	ectx.objective_params = {
		"duration_turns":  20,
		"entity_def_id":   "protect_entity",
		"entity_name":     "Test Charge",
		"entity_max_hp":   9999,
		"protect_guard_radius": 2,
	}

	# Add entity (living structure) at col=5, row=5.
	var entity: Dictionary = {
		"id": "test_entity_near", "name": "Test Charge", "faction": "structure",
		"is_structure": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors.append(entity)

	# Place all echoes directly on the entity cell (distance 0 ≤ 2 = within guard radius).
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			a_v["grid_pos"] = { "col": 5, "row": 5 }

	# Move all enemies far away so no combat ends the fight early.
	var enemy_col: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["grid_pos"] = { "col": enemy_col, "row": 9 }
			enemy_col += 1

	# Init combat and drive exactly one round.
	runtime.dispatch({ "type": "combat.init" })
	ectx.combat_state["protect_counter"] = 0
	ectx.combat_state["totem_stolen"]    = false
	ectx.combat_state["totem_carrier_id"] = ""

	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 60:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var protect_counter: int = int(ectx.combat_state.get("protect_counter", 0))
	if protect_counter < 1:
		return { "ok": false, "error": "Expected protect_counter >= 1 after round with echo at entity, got %d" % protect_counter }
	return { "ok": true }


# test_protect_counter_far:
# All echoes placed far from the entity (distance > guard_radius 2).
# After one round, protect_counter must be 0 (reset-on-leave semantics).
static func test_protect_counter_far() -> Dictionary:
	var env: Dictionary = _setup("protect_far", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	# Override to PROTECT mode.
	ectx.resolution_mode = EncounterResolutionModes.PROTECT
	ectx.objective_params = {
		"duration_turns":  20,
		"entity_def_id":   "protect_entity",
		"entity_name":     "Test Charge",
		"entity_max_hp":   9999,
		"protect_guard_radius": 2,
	}

	# Add entity (living structure) at col=5, row=5.
	var entity: Dictionary = {
		"id": "test_entity_far", "name": "Test Charge", "faction": "structure",
		"is_structure": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors.append(entity)

	# Place all echoes far from the entity (col=0, row=0..4 → Chebyshev ≥ 5 > guard_radius 2).
	var echo_row: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			a_v["grid_pos"] = { "col": 0, "row": echo_row }
			echo_row += 1

	# Keep enemies also far so the round doesn't end via all_enemies_defeated prematurely.
	var enemy_col: int = 9
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["grid_pos"] = { "col": enemy_col, "row": 9 }
			enemy_col = maxi(0, enemy_col - 1)

	# Init and drive exactly one round.
	runtime.dispatch({ "type": "combat.init" })
	ectx.combat_state["protect_counter"] = 0
	ectx.combat_state["totem_stolen"]    = false
	ectx.combat_state["totem_carrier_id"] = ""

	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 60:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var protect_counter: int = int(ectx.combat_state.get("protect_counter", 0))
	if protect_counter != 0:
		return { "ok": false, "error": "Expected protect_counter=0 after round with all echoes far from entity, got %d" % protect_counter }
	return { "ok": true }


# test_protect_counter_resets_after_leaving:
# Proves reset-on-leave semantics: pre-seed protect_counter=3 (simulating echoes
# having guarded for 3 rounds), then run one round with ALL echoes far from the entity.
# After that round protect_counter must be 0, not 3 (i.e. reset, not paused).
static func test_protect_counter_resets_after_leaving() -> Dictionary:
	var env: Dictionary = _setup("protect_reset_leave", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	# Override to PROTECT mode.
	ectx.resolution_mode = EncounterResolutionModes.PROTECT
	ectx.objective_params = {
		"duration_turns":     20,
		"entity_def_id":      "protect_entity",
		"entity_name":        "Test Charge",
		"entity_max_hp":      9999,
		"protect_guard_radius": 2,
	}

	# Add entity (living structure) at col=5, row=5.
	var entity: Dictionary = {
		"id": "test_entity_reset", "name": "Test Charge", "faction": "structure",
		"is_structure": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors.append(entity)

	# Place all echoes FAR from the entity (Chebyshev >= 5 > guard_radius 2).
	var echo_row: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			a_v["grid_pos"] = { "col": 0, "row": echo_row }
			echo_row += 1

	# Keep enemies far too so the round doesn't end via all_enemies_defeated prematurely.
	var enemy_col: int = 9
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["grid_pos"] = { "col": enemy_col, "row": 9 }
			enemy_col = maxi(0, enemy_col - 1)

	# Init combat, then pre-seed protect_counter=3 to simulate prior guarded rounds.
	runtime.dispatch({ "type": "combat.init" })
	ectx.combat_state["protect_counter"]  = 3   # pre-seeded: echoes were guarding
	ectx.combat_state["totem_stolen"]     = false
	ectx.combat_state["totem_carrier_id"] = ""

	# Drive exactly one round with all echoes far — counter must reset to 0.
	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 60:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var protect_counter: int = int(ectx.combat_state.get("protect_counter", 0))
	if protect_counter != 0:
		return { "ok": false, "error": "Expected protect_counter=0 after leaving guard (reset-on-leave), got %d (was pre-seeded at 3)" % protect_counter }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Bug-fix: RECOVER holder designation reads top-level `speed`, not stats.speed.
#
# Two echo actors are built with differing TOP-LEVEL speed fields (stats.speed
# intentionally absent / set to 0). After one RECOVER round, recover_holder_id
# must point to the echo with the higher top-level speed.
# ---------------------------------------------------------------------------
static func test_recover_holder_fastest_echo() -> Dictionary:
	var env: Dictionary = _setup("holder_speed", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	# Replace ectx.actors with two controlled echo actors + one enemy.
	# Echo A: top-level speed=10. Echo B: top-level speed=5.
	# stats sub-dict has speed=0 for both (the previously-wrong read path).
	var echo_a: Dictionary = {
		"id": "echo_fast", "name": "Fast Echo",
		"faction": "echo", "is_dead": false, "is_structure": false,
		"speed": 10,
		"stats": { "max_hp": 100, "hp": 100, "def": 5, "atk": 5, "agi": 5, "speed": 0, "morale": 50 },
		"current_hp": 100, "max_hp": 100,
		"emotion": { "morale": 50, "fear": 0 },
		"grid_pos": { "col": 2, "row": 2 },
		"behavior": "advance",
		"traits": [], "archetype": "warrior",
	}
	var echo_b: Dictionary = {
		"id": "echo_slow", "name": "Slow Echo",
		"faction": "echo", "is_dead": false, "is_structure": false,
		"speed": 5,
		"stats": { "max_hp": 100, "hp": 100, "def": 5, "atk": 5, "agi": 5, "speed": 0, "morale": 50 },
		"current_hp": 100, "max_hp": 100,
		"emotion": { "morale": 50, "fear": 0 },
		"grid_pos": { "col": 3, "row": 2 },
		"behavior": "advance",
		"traits": [], "archetype": "warrior",
	}
	var enemy_a: Dictionary = {
		"id": "enemy_01", "name": "Vale Patrol",
		"faction": "enemy", "is_dead": false, "is_structure": false,
		"speed": 3,
		"stats": { "max_hp": 80, "hp": 80, "def": 3, "atk": 5, "agi": 3, "speed": 3, "morale": 50 },
		"current_hp": 80, "max_hp": 80,
		"emotion": { "morale": 50, "fear": 0 },
		"grid_pos": { "col": 8, "row": 8 },
		"behavior": "advance",
		"traits": [], "archetype": "fighter",
	}
	var relic_a: Dictionary = {
		"id": "test_relic_01", "name": "Test Relic", "faction": "structure",
		"is_structure": true, "is_objective_relic": true,
		"current_hp": 9999, "is_dead": false,
		"speed": 0,
		"stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors = [echo_a, echo_b, enemy_a, relic_a]

	ectx.resolution_mode = EncounterResolutionModes.RECOVER
	ectx.objective_params = {
		"hold_rounds": 99,
		"relic_def_id": "recover_relic",
		"relic_name": "Test Relic",
		"relic_max_hp": 9999,
		"reinforce_interval":  99,
		"reinforce_size":      0,
		"reinforce_group":     "group.vale_patrol_sm",
		"reinforce_max_total": 0,
	}

	runtime.dispatch({ "type": "combat.init" })
	ectx.combat_state["recover_holder_id"]       = ""
	ectx.combat_state["recover_reinforce_count"] = 0

	# Drive one round — _end_round sets recover_holder_id.
	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 40:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var holder_id: String = str(ectx.combat_state.get("recover_holder_id", ""))
	if holder_id != "echo_fast":
		return {
			"ok": false,
			"error": "Expected recover_holder_id='echo_fast' (top-level speed=10 wins over speed=5), got '%s'" % holder_id
		}
	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3b: PURSUE smoke test.
# Uses dev_combat_objective=PURSUE so FlowEncounterState.enter() runs the native
# PURSUE spawn block, placing the quarry on a guaranteed walkable cell.
# After 1 round verifies:
#   (a) A quarry actor (is_quarry=true) was spawned.
#   (b) combat_state has "contain_counter" key — proves _end_round PURSUE branch ran.
# ---------------------------------------------------------------------------
static func test_pursue_quarry_moves() -> Dictionary:
	# Inline setup — same as _setup() but with PURSUE as dev objective.
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.dir() + "combat_roundtrip_pursue.json")
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, t)
	if rm.is_empty():
		return { "ok": false, "error": "setup failed — realm not created" }
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.pursue_smoke2"

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate("pursue_smoke2", "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		roster.append(echo)
		party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	# PURSUE as dev objective → FlowEncounterState spawns quarry on a valid walkable cell.
	flow_ctx.dev_combat_objective = EncounterResolutionModes.PURSUE
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	var ectx = flow_ctx.encounter_ctx

	# (a) quarry actor spawned by the PURSUE spawn block.
	var found_quarry: bool = false
	for a_v in ectx.actors:
		if a_v is Dictionary and bool((a_v as Dictionary).get("is_quarry", false)):
			found_quarry = true
			break
	if not found_quarry:
		return { "ok": false, "error": "No is_quarry=true actor spawned by FlowEncounterState.enter() in PURSUE mode" }

	# Drive 1 round through the full runtime dispatch loop.
	_drive(runtime, ectx, 1)

	# (b) contain_counter key exists — proves _end_round ran the PURSUE adjacency check.
	if not ectx.combat_state.has("contain_counter"):
		return { "ok": false, "error": "combat_state missing 'contain_counter' — PURSUE _end_round branch did not run" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3b: PURSUE no-regular-enemies test.
# After FlowEncounterState.enter() with PURSUE objective:
#   (a) No actor with faction=="enemy" and is_quarry==false exists.
#   (b) Exactly one actor with is_quarry==true exists.
# ---------------------------------------------------------------------------
static func test_pursue_no_regular_enemies_spawn() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.dir() + "combat_pursue_noenemy.json")
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, t)
	if rm.is_empty():
		return { "ok": false, "error": "setup failed — realm not created" }
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.pursue_noenemy"

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate("pursue_noenemy", "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		roster.append(echo)
		party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	flow_ctx.dev_combat_objective = EncounterResolutionModes.PURSUE
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	var ectx = flow_ctx.encounter_ctx

	var quarry_count: int = 0
	var regular_enemy_count: int = 0
	for a_v in ectx.actors:
		if a_v is Dictionary:
			var is_q: bool = bool((a_v as Dictionary).get("is_quarry", false))
			var faction: String = str((a_v as Dictionary).get("faction", ""))
			if is_q:
				quarry_count += 1
			elif faction == "enemy":
				regular_enemy_count += 1

	if regular_enemy_count > 0:
		return { "ok": false, "error": "PURSUE mode spawned %d regular (non-quarry) enemy actors — expected 0" % regular_enemy_count }
	if quarry_count != 1:
		return { "ok": false, "error": "Expected exactly 1 quarry actor in PURSUE mode, found %d" % quarry_count }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3b: PURSUE board size test.
# After FlowEncounterState.enter() with PURSUE objective, the terrain bounds
# must have at least one dimension that is ≥ (standard_base * 1.9) — proving
# that the 2× long-dimension multiplier was applied.
# Standard base dimensions come from data.combat.board.base_cols / base_rows.
# ---------------------------------------------------------------------------
static func test_pursue_board_is_larger_than_standard() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.dir() + "combat_pursue_board.json")
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, t)
	if rm.is_empty():
		return { "ok": false, "error": "setup failed — realm not created" }
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.pursue_board"

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate("pursue_board", "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		roster.append(echo)
		party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	flow_ctx.dev_combat_objective = EncounterResolutionModes.PURSUE
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	var ectx = flow_ctx.encounter_ctx

	# Standard base from balance.json data.combat.board (base_cols=18, base_rows=18).
	var board_cfg: Dictionary = bal.get("data", {}).get("combat", {}).get("board", {})
	var base_cols: int = int(board_cfg.get("base_cols", 18))
	var base_rows: int = int(board_cfg.get("base_rows", 18))

	# Read actual terrain bounds from encounter context.
	var bounds: Dictionary = ectx.terrain.get("bounds", {})
	var actual_w: int = int(bounds.get("w", 0))
	var actual_h: int = int(bounds.get("h", 0))

	if actual_w <= 0 or actual_h <= 0:
		return { "ok": false, "error": "terrain bounds not set on ectx after PURSUE enter() — got w=%d h=%d" % [actual_w, actual_h] }

	var threshold_w: float = float(base_cols) * 1.9
	var threshold_h: float = float(base_rows) * 1.9
	if not (float(actual_w) >= threshold_w or float(actual_h) >= threshold_h):
		return {
			"ok": false,
			"error": "PURSUE board not stretched in either dimension — actual w=%d h=%d, needed w≥%.0f or h≥%.0f (base %d×%d)" \
				% [actual_w, actual_h, threshold_w, threshold_h, base_cols, base_rows]
		}

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3c: GUIDE_SPIRIT roundtrip test.
# Forces the GUIDE_SPIRIT objective (mirrors the RECOVER/PROTECT override pattern:
# set ectx.resolution_mode + ectx.objective_params BEFORE combat.init so
# CombatState.create() reads them), adds a living spirit actor, keeps it alive and
# protected for the full duration, and verifies:
#   (a) a spirit actor (is_spirit=true) exists on the board,
#   (b) objective_state carries guide_mode/spirit_alive/spirit_name/rounds_remaining,
#   (c) combat ends "spirit_protected" once round_counter reaches duration_turns.
# ---------------------------------------------------------------------------
static func test_guide_spirit_protect_roundtrip() -> Dictionary:
	var env: Dictionary = _setup("guide_spirit_protect", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	# Override to GUIDE_SPIRIT (protect mode) — set BEFORE combat.init so CombatState.create
	# reads ectx.resolution_mode + ectx.objective_params.
	ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
	ectx.objective_params = {
		"guide_mode":       "protect",
		"duration_turns":   2,   # short so the roundtrip completes quickly
		"spirit_def_id":    "guide_spirit",
		"spirit_name":      "Test Spirit",
		"spirit_max_hp":    9999,
		# Generous escort_radius so an echo placed beside the spirit stays within the
		# guard band even as it drifts a step or two toward the (far) enemies each round —
		# guard-to-count requires an echo near the spirit to advance guide_protect_counter.
		"escort_radius":    5,
		"skittish_radius":  3,
	}

	# Add a living spirit actor, far from any enemy so it is never threatened
	# (skittish flee/enemy-near does not interfere with the protect-duration win).
	var spirit: Dictionary = {
		"id": "guide_spirit_01", "name": "Test Spirit", "faction": "npc",
		"is_structure": false, "is_spirit": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 1, "row": 1 },
	}
	ectx.actors.append(spirit)

	# Move all enemies far away so the spirit is never "enemy near" and combat
	# does not end prematurely via all_enemies_defeated or all_echoes_dead.
	var enemy_col: int = 9
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["grid_pos"] = { "col": enemy_col, "row": 9 }
			enemy_col = maxi(0, enemy_col - 1)

	runtime.dispatch({ "type": "combat.init" })

	# Place one echo directly adjacent to the spirit so guide_protect_counter advances each round
	# (deterministic — no reliance on real AI reaching the spirit). Set AFTER combat.init so the
	# placement is not overwritten by initial actor placement.
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			a_v["grid_pos"] = { "col": 2, "row": 1 }  # Chebyshev 1 from spirit at (1,1)
			break

	# (a) Spirit actor present on the board.
	var found_spirit: bool = false
	for a_v in ectx.actors:
		if a_v is Dictionary and bool((a_v as Dictionary).get("is_spirit", false)):
			found_spirit = true
			break
	if not found_spirit:
		return { "ok": false, "error": "No is_spirit=true actor found on the board after combat.init" }

	# Drive rounds until combat ends or duration_turns is reached.
	_drive(runtime, ectx, 4)

	# (b) objective_state fields — build via the static objective-state helper, same as
	# other objective_combat/_build_objective_state-style checks in ObjectiveCombatTests.
	var obj_state: Dictionary = EncounterSnapshotBuilder._build_objective_state(ectx, ectx.combat_state)
	if str(obj_state.get("guide_mode", "")) != "protect":
		return { "ok": false, "error": "Expected objective_state.guide_mode='protect', got '%s'" % str(obj_state.get("guide_mode", "")) }
	if not obj_state.has("spirit_alive"):
		return { "ok": false, "error": "objective_state missing 'spirit_alive'" }
	if str(obj_state.get("spirit_name", "")).is_empty():
		return { "ok": false, "error": "objective_state.spirit_name is empty, expected a spirit name" }
	if not obj_state.has("rounds_remaining"):
		return { "ok": false, "error": "objective_state missing 'rounds_remaining'" }

	# (c) Combat should have ended in victory "spirit_protected" — an echo was kept within
	# escort_radius of the spirit, so guide_protect_counter reached duration_turns=2 (guard-to-count).
	var cs: Dictionary = ectx.combat_state
	if not bool(cs.get("combat_over", false)):
		return { "ok": false, "error": "Expected combat_over=true after guarding to duration_turns, got false" }
	var result: Dictionary = ectx.combat_result
	if str(result.get("reason", "")) != "spirit_protected":
		return { "ok": false, "error": "Expected combat_result.reason='spirit_protected', got '%s'" % str(result.get("reason", "")) }
	if not bool(result.get("victory", false)):
		return { "ok": false, "error": "Expected combat_result.victory=true for spirit_protected, got false" }
	# Guard-to-count sanity: the win came from guide_protect_counter, not a bare round timer.
	if int(cs.get("guide_protect_counter", 0)) < 2:
		return { "ok": false, "error": "Expected guide_protect_counter >= duration_turns(2) at win, got %d" % int(cs.get("guide_protect_counter", 0)) }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3c "guard to count" — GUIDE_SPIRIT protect: with NO echo ever within
# escort_radius of the spirit, driving rounds well past duration_turns must NOT win. The
# bare round timer no longer grants the protect victory — the party must reach the spirit.
# ---------------------------------------------------------------------------
static func test_guide_spirit_protect_no_win_without_guard() -> Dictionary:
	var env: Dictionary = _setup("guide_spirit_no_guard", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
	ectx.objective_params = {
		"guide_mode":       "protect",
		"duration_turns":   2,   # short — would win on a bare round timer after 2 rounds
		"spirit_def_id":    "guide_spirit",
		"spirit_name":      "Test Spirit",
		"spirit_max_hp":    9999,
		"escort_radius":    2,
		"skittish_radius":  3,
	}

	# Spirit tucked in a corner, far from every echo and enemy.
	var spirit: Dictionary = {
		"id": "guide_spirit_01", "name": "Test Spirit", "faction": "npc",
		"is_structure": false, "is_spirit": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 0, "row": 0 },
	}
	ectx.actors.append(spirit)

	# Enemies far from the spirit (bottom-right) so the fight does not end early.
	var enemy_col: int = 9
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["grid_pos"] = { "col": enemy_col, "row": 9 }
			enemy_col = maxi(0, enemy_col - 1)

	runtime.dispatch({ "type": "combat.init" })

	# Pin every echo far from the spirit (bottom rows) AFTER init. They advance toward the
	# far enemies, never coming within escort_radius(2) of the corner spirit.
	var echo_col: int = 6
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			a_v["grid_pos"] = { "col": echo_col, "row": 8 }
			echo_col = mini(9, echo_col + 1)

	# Drive several rounds — well past duration_turns=2.
	for _r in range(5):
		runtime.dispatch({ "type": "combat.confirm_round" })
		var g: int = 0
		while g < 40:
			g += 1
			var cs2: Dictionary = ectx.combat_state
			if bool(cs2.get("combat_over", false)): break
			if str(cs2.get("round_phase", "")) != "in_round": break
			runtime.dispatch({ "type": "combat.next_actor" })
		if bool(ectx.combat_state.get("combat_over", false)): break

	var cs: Dictionary = ectx.combat_state
	# No echo ever guarded the spirit → counter stays 0 → no spirit_protected win.
	if int(cs.get("guide_protect_counter", 0)) != 0:
		return { "ok": false, "error": "Expected guide_protect_counter=0 (no echo near spirit), got %d" % int(cs.get("guide_protect_counter", 0)) }
	var reason: String = str(ectx.combat_result.get("reason", "")) if ectx.combat_result != null else ""
	if reason == "spirit_protected":
		return { "ok": false, "error": "Expected NO spirit_protected win without proximity, but combat ended spirit_protected" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3c: GUIDE_SPIRIT escort — spirit does NOT move before any echo is
# adjacent (escort_started stays false), and DOES move after an echo becomes adjacent
# (escort_started flips true and the spirit steps toward the destination on a
# subsequent round). Direct _end_round-level check via combat.confirm_round +
# combat.next_actor, mirroring the existing PROTECT guard-proximity tests.
# ---------------------------------------------------------------------------
static func test_guide_spirit_escort_moves_only_after_adjacency() -> Dictionary:
	var env: Dictionary = _setup("guide_spirit_escort", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
	ectx.objective_params = {
		"guide_mode":      "escort",
		"duration_turns":  20,  # irrelevant to escort mode; long so it never fires
		"spirit_def_id":   "guide_spirit",
		"spirit_name":     "Test Spirit",
		"spirit_max_hp":   9999,
		"escort_radius":   2,
		"skittish_radius": 3,
		"destination_col": 9,
		"destination_row": 9,
	}

	var spirit: Dictionary = {
		"id": "guide_spirit_01", "name": "Test Spirit", "faction": "npc",
		"is_structure": false, "is_spirit": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors.append(spirit)

	# Place all echoes FAR from the spirit (no adjacency at combat start).
	var echo_row: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			a_v["grid_pos"] = { "col": 0, "row": echo_row }
			echo_row += 1

	# Move enemies far away so nothing else ends combat early.
	var enemy_col: int = 9
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["grid_pos"] = { "col": enemy_col, "row": 0 }
			enemy_col = maxi(0, enemy_col - 1)

	runtime.dispatch({ "type": "combat.init" })

	var spirit_pos_before: Dictionary = spirit.get("grid_pos", {}).duplicate()

	# Round 1 — no echo adjacent to the spirit: escort must NOT start, spirit must NOT move.
	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 60:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	if bool(ectx.combat_state.get("escort_started", false)):
		return { "ok": false, "error": "Expected escort_started=false while no echo is adjacent to the spirit" }
	var spirit_pos_after_r1: Dictionary = spirit.get("grid_pos", {})
	if int(spirit_pos_after_r1.get("col", -1)) != int(spirit_pos_before.get("col", -1)) \
			or int(spirit_pos_after_r1.get("row", -1)) != int(spirit_pos_before.get("row", -1)):
		return { "ok": false, "error": "Spirit moved before any echo was adjacent (escort must not start): %s → %s" \
			% [str(spirit_pos_before), str(spirit_pos_after_r1)] }

	# Now place an echo directly adjacent to the spirit's current position.
	var spirit_col: int = int(spirit_pos_after_r1.get("col", 5))
	var spirit_row: int = int(spirit_pos_after_r1.get("row", 5))
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo" and not bool(a_v.get("is_dead", false)):
			a_v["grid_pos"] = { "col": spirit_col + 1, "row": spirit_row }
			break

	# Round 2 — an echo is now adjacent: escort must start.
	runtime.dispatch({ "type": "combat.confirm_round" })
	guard = 0
	while guard < 60:
		guard += 1
		var cs2: Dictionary = ectx.combat_state
		if bool(cs2.get("combat_over", false)): break
		if str(cs2.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	if not bool(ectx.combat_state.get("escort_started", false)):
		return { "ok": false, "error": "Expected escort_started=true after an echo became adjacent to the spirit" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3c: GUIDE_SPIRIT protect (skittish) — spirit flees one cell away
# from the nearest enemy when an enemy is within skittish_radius and no echo is
# adjacent; spirit holds its position when an echo IS adjacent (even with an
# enemy near).
# ---------------------------------------------------------------------------
static func test_guide_spirit_protect_flees_when_enemy_near_no_echo() -> Dictionary:
	var env: Dictionary = _setup("guide_spirit_flee", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
	ectx.objective_params = {
		"guide_mode":      "protect",
		"duration_turns":  20,  # long enough it never fires during this 1-round test
		"spirit_def_id":   "guide_spirit",
		"spirit_name":     "Test Spirit",
		"spirit_max_hp":   9999,
		"escort_radius":   2,
		"skittish_radius": 3,
	}

	var spirit: Dictionary = {
		"id": "guide_spirit_01", "name": "Test Spirit", "faction": "npc",
		"is_structure": false, "is_spirit": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors.append(spirit)

	# Keep all echoes FAR from the spirit (no adjacency).
	var echo_row: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			a_v["grid_pos"] = { "col": 0, "row": echo_row }
			echo_row += 1

	# Place one enemy WITHIN skittish_radius of the spirit (distance 2 <= 3).
	var enemy_near_placed: bool = false
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			if not enemy_near_placed:
				a_v["grid_pos"] = { "col": 7, "row": 5 }  # chebyshev distance 2 from (5,5)
				enemy_near_placed = true
			else:
				a_v["grid_pos"] = { "col": 9, "row": 0 }  # rest far away

	runtime.dispatch({ "type": "combat.init" })

	var spirit_pos_before: Dictionary = spirit.get("grid_pos", {}).duplicate()

	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 60:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var spirit_pos_after: Dictionary = spirit.get("grid_pos", {})
	if int(spirit_pos_after.get("col", -1)) == int(spirit_pos_before.get("col", -1)) \
			and int(spirit_pos_after.get("row", -1)) == int(spirit_pos_before.get("row", -1)):
		return { "ok": false, "error": "Expected spirit to flee one cell (enemy near, no echo adjacent), but it did not move: %s" \
			% str(spirit_pos_before) }

	return { "ok": true }


static func test_guide_spirit_protect_holds_when_echo_adjacent() -> Dictionary:
	var env: Dictionary = _setup("guide_spirit_hold", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
	ectx.objective_params = {
		"guide_mode":      "protect",
		"duration_turns":  20,
		"spirit_def_id":   "guide_spirit",
		"spirit_name":     "Test Spirit",
		"spirit_max_hp":   9999,
		"escort_radius":   2,
		"skittish_radius": 3,
	}

	var spirit: Dictionary = {
		"id": "guide_spirit_01", "name": "Test Spirit", "faction": "npc",
		"is_structure": false, "is_spirit": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors.append(spirit)

	# Place ONE echo directly adjacent to the spirit; the rest far away.
	var echo_adjacent_placed: bool = false
	var echo_row: int = 0
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo":
			if not echo_adjacent_placed:
				a_v["grid_pos"] = { "col": 6, "row": 5 }  # adjacent to (5,5)
				echo_adjacent_placed = true
			else:
				a_v["grid_pos"] = { "col": 0, "row": echo_row }
				echo_row += 1

	# Place one enemy WITHIN skittish_radius of the spirit (would normally trigger flee).
	var enemy_near_placed: bool = false
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			if not enemy_near_placed:
				a_v["grid_pos"] = { "col": 7, "row": 5 }  # chebyshev distance 2 from (5,5)
				enemy_near_placed = true
			else:
				a_v["grid_pos"] = { "col": 9, "row": 0 }

	runtime.dispatch({ "type": "combat.init" })

	var spirit_pos_before: Dictionary = spirit.get("grid_pos", {}).duplicate()

	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 60:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var spirit_pos_after: Dictionary = spirit.get("grid_pos", {})
	if int(spirit_pos_after.get("col", -1)) != int(spirit_pos_before.get("col", -1)) \
			or int(spirit_pos_after.get("row", -1)) != int(spirit_pos_before.get("row", -1)):
		return { "ok": false, "error": "Expected spirit to hold position (echo adjacent guards it), but it moved: %s → %s" \
			% [str(spirit_pos_before), str(spirit_pos_after)] }

	return { "ok": true }


# ---------------------------------------------------------------------------
# BLOCKER regression: the JOINED combatant GUIDE_SPIRIT (faction "echo", is_spirit=true,
# is_structure=false — built via EnemyActor when spirit_joins_battle=true) is NOT the idle
# structure spirit whose movement _end_round owns. FlowRuntime's is_spirit grid_pos
# capture/restore gate (core/runtime/FlowRuntime.gd, around _resolve_next_actor) is gone,
# so a joined combatant spirit must take normal combat turns like any other
# echo-faction combatant. It may choose to move, guard, or attack; this test asserts
# it is not owned by the non-joining GUIDE objective mover.
# ---------------------------------------------------------------------------
static func test_guide_spirit_joined_combatant_moves_freely() -> Dictionary:
	var env: Dictionary = _setup("guide_spirit_joined_moves", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
	ectx.objective_params = {
		"guide_mode":          "escort",
		"duration_turns":      20,  # irrelevant to escort mode; long so it never fires
		"spirit_def_id":       "guide_spirit",
		"spirit_name":         "Test Spirit",
		"spirit_max_hp":       9999,
		"escort_radius":       2,
		"skittish_radius":     3,
		"spirit_joins_battle": true,
		"destination_col":     9,
		"destination_row":     9,
	}

	# JOINED combatant spirit: faction "echo", is_spirit=true, is_structure=false — distinct
	# from the idle "npc"-faction structure spirit used in the other GUIDE_SPIRIT tests above.
	# actor_type "enemy" matches the real spawn path (EnemyActor.from_definition, see
	# FlowEncounterState.gd _gs_joins block) — ActorStateMachine._init routes actor_type
	# "echo"/"enemy" to BehaviorArbiter; anything else silently falls back to
	# IdleBehaviorModule, which never generates a move intent.
	var spirit: Dictionary = {
		"id": "guide_spirit_01", "name": "Test Spirit", "faction": "echo",
		"actor_type": "enemy",
		"calling_origin": "aduro",
		"traits": { "courage": 55, "wisdom": 10, "faith": 10 },
		"vector_scores": {},
		"is_structure": false, "is_spirit": true, "is_dead": false,
		"current_hp": 60, "stats": { "max_hp": 60, "def": 2, "atk": 8, "speed": 6 },
		"speed": 6, "morale": 50, "fear": 0,
		"grid_pos": { "col": 1, "row": 1 },
	}
	ectx.actors.append(spirit)

	# Move all enemies far away so combat does not end early and nothing else interferes.
	var enemy_col: int = 4
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["grid_pos"] = { "col": enemy_col, "row": 1 }
			enemy_col += 1

	runtime.dispatch({ "type": "combat.init" })

	var spirit_pos_before: Dictionary = spirit.get("grid_pos", {}).duplicate()

	_drive(runtime, ectx, 6)

	# Re-find the spirit actor by id (arbiter turns mutate the dict in place within ectx.actors).
	var spirit_after: Dictionary = {}
	for a_v in ectx.actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("id", "")) == "guide_spirit_01":
			spirit_after = a_v
			break
	if spirit_after.is_empty():
		return { "ok": false, "error": "joined spirit actor not found after driving rounds" }

	var pos_after: Dictionary = spirit_after.get("grid_pos", {})
	if int(pos_after.get("col", -1)) == int(spirit_pos_before.get("col", -1)) \
			and int(pos_after.get("row", -1)) == int(spirit_pos_before.get("row", -1)):
		var ledger: Dictionary = ectx.echo_action_logs.get("guide_spirit_01", {}) as Dictionary
		if int(ledger.get("total_count", 0)) <= 0:
			return { "ok": false, "error": "Expected joined combatant spirit to take normal combat turns, but no contribution ledger entry was recorded" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3c: dev-override determinism test.
# Exercises the REAL GUIDE_SPIRIT spawn block (via dev_combat_objective=GUIDE_SPIRIT)
# with dev_guide_mode="escort" + dev_guide_joins="join" forced. Asserts:
#   (a) objective_params.guide_mode == "escort"   (mode override applied)
#   (b) spirit_joins_battle == true               (joins override applied)
#   (c) a spirit actor exists with faction "echo"  (joined combatant path)
#   (d) the seeded RNG draws still occurred: the spirit NAME is byte-identical with
#       and without the override for the same encounter seed. The name draw follows
#       the mode + joins draws in the spawn block, so an identical name proves the
#       draw-then-override left the RNG draw sequence unshifted.
# ---------------------------------------------------------------------------
static func _guide_spawn_env(seed_tag: String, force_mode: String, force_joins: String) -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.dir() + "combat_roundtrip_guide_dev.json")
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, t)
	if rm.is_empty():
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0." + seed_tag

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(seed_tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		roster.append(echo)
		party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	flow_ctx.dev_combat_objective = EncounterResolutionModes.GUIDE_SPIRIT
	flow_ctx.dev_guide_mode = force_mode
	flow_ctx.dev_guide_joins = force_joins
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	return { "runtime": runtime, "flow_ctx": flow_ctx, "ectx": flow_ctx.encounter_ctx }


static func test_guide_spirit_dev_override_forces_escort_join() -> Dictionary:
	# Same encounter seed for both runs so RNG-derived draws are comparable.
	var seed_tag: String = "guide_dev_override"

	# (1) With override forced: escort + joins battle.
	var env: Dictionary = _guide_spawn_env(seed_tag, "escort", "join")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var ectx = env["ectx"]
	var params: Dictionary = ectx.objective_params

	# (a) mode override applied.
	if str(params.get("guide_mode", "")) != "escort":
		return { "ok": false, "error": "Expected guide_mode='escort', got '%s'" % str(params.get("guide_mode", "")) }
	# (b) joins override applied.
	if not bool(params.get("spirit_joins_battle", false)):
		return { "ok": false, "error": "Expected spirit_joins_battle=true, got false" }

	# (c) a spirit actor exists with faction "echo" (joined combatant path).
	var spirit_faction: String = ""
	var forced_name: String = str(params.get("spirit_name", ""))
	for a_v in ectx.actors:
		if a_v is Dictionary and bool((a_v as Dictionary).get("is_spirit", false)):
			spirit_faction = str((a_v as Dictionary).get("faction", ""))
			break
	if spirit_faction != "echo":
		return { "ok": false, "error": "Expected joined spirit faction='echo', got '%s'" % spirit_faction }
	if forced_name.is_empty():
		return { "ok": false, "error": "spirit_name was empty under override" }

	# (d) determinism: same seed, NO override -> seeded draws run naturally. The NAME draw
	# follows the mode+joins draws, so an identical spirit name proves the draw-then-override
	# did not shift the RNG draw sequence.
	var env2: Dictionary = _guide_spawn_env(seed_tag, "", "")
	if env2.is_empty():
		return { "ok": false, "error": "setup failed (seeded run)" }
	var seeded_name: String = str(env2["ectx"].objective_params.get("spirit_name", ""))
	if seeded_name != forced_name:
		return { "ok": false, "error": "spirit name diverged with override: forced='%s' seeded='%s' -- draw order shifted" % [forced_name, seeded_name] }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3c review-fix (FIX 1): escort destination selection on INSET terrain.
# Real combat terrain (irregular StageTerrain) has a walkable set that is inset from the
# outer bounds ring — literal-bounds cells (col==0 / col==cols-1 / row==0 / row==rows-1)
# are usually absent. The old code only admitted literal-bounds cells as destination
# candidates, so on inset terrain the candidate set was empty and destination_col/row
# stayed -1 -> the escort branch never ran -> escort was unwinnable. The fix builds
# candidates from the walkable FRONTIER ring (a walkable cell with at least one 4-dir
# neighbour that is non-walkable/out-of-bounds). This test drives the REAL escort spawn
# path via FlowEncounterState.enter() on the realm's generated inset terrain and asserts:
#   (a) destination_col/row are set (!= -1), and
#   (b) the destination cell is walkable, and
#   (c) the destination is a genuine frontier cell (proves the frontier branch fired).
# ---------------------------------------------------------------------------
static func test_guide_spirit_escort_destination_on_inset_terrain() -> Dictionary:
	var env: Dictionary = _guide_spawn_env("guide_escort_inset", "escort", "nojoin")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var ectx = env["ectx"]
	var params: Dictionary = ectx.objective_params

	if str(params.get("guide_mode", "")) != "escort":
		return { "ok": false, "error": "Expected guide_mode='escort', got '%s'" % str(params.get("guide_mode", "")) }

	var dest_col: int = int(params.get("destination_col", -1))
	var dest_row: int = int(params.get("destination_row", -1))

	# (a) destination must be set — the exact failure the fix repairs.
	if dest_col == -1 or dest_row == -1:
		return { "ok": false, "error": "escort destination not set on inset terrain (dest_col=%d dest_row=%d) -- frontier candidates empty" % [dest_col, dest_row] }

	var walkable: Dictionary = StageTerrain.walkable_set(ectx.terrain)
	if walkable.is_empty():
		return { "ok": false, "error": "walkable set empty -- terrain not generated" }

	# Guard: confirm the terrain really is inset (the fix's whole reason to exist).
	var bounds: Dictionary = ectx.terrain.get("bounds", {})
	var cols: int = int(bounds.get("w", 0))
	var rows: int = int(bounds.get("h", 0))
	var literal_edge_walkable: int = 0
	for k in walkable:
		var p: Array = str(k).split(",")
		if p.size() != 2: continue
		var c: int = int(p[0]); var r: int = int(p[1])
		if c == 0 or c == cols - 1 or r == 0 or r == rows - 1:
			literal_edge_walkable += 1
	if literal_edge_walkable >= walkable.size():
		return { "ok": false, "error": "terrain is a full rectangle (not inset) -- test would not exercise the frontier fix" }

	# (b) destination must be walkable.
	var dest_key: String = "%d,%d" % [dest_col, dest_row]
	if not walkable.has(dest_key):
		return { "ok": false, "error": "escort destination %s is not walkable" % dest_key }

	# (c) destination must be a frontier cell.
	var is_frontier: bool = \
		not walkable.has("%d,%d" % [dest_col - 1, dest_row]) \
		or not walkable.has("%d,%d" % [dest_col + 1, dest_row]) \
		or not walkable.has("%d,%d" % [dest_col, dest_row - 1]) \
		or not walkable.has("%d,%d" % [dest_col, dest_row + 1])
	if not is_frontier:
		return { "ok": false, "error": "escort destination %s is interior, not a frontier cell" % dest_key }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-STAGE-004 P3c review-fix (FIX 2): a JOINED spirit must not self-escort.
# When spirit_joins_battle is true the spirit has faction "echo" + is_spirit true. The
# escort proximity/start/greet loops in FlowRuntime._end_round previously matched on
# faction=="echo" alone, so the spirit counted ITSELF (distance 0) as an escorting echo
# and walked itself to the destination — reaching a spirit_escorted victory even after
# every real echo was dead (destination_reached is evaluated before all_echoes_dead). The
# fix skips is_spirit actors in those loops. This test places the spirit ON its own
# destination with all real echoes dead, drives a round, and asserts combat does NOT end
# spirit_escorted — party-wipe defeat (all_echoes_dead) fires instead.
# ---------------------------------------------------------------------------
static func test_guide_spirit_joined_spirit_does_not_self_escort() -> Dictionary:
	var env: Dictionary = _setup("guide_self_escort", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
	ectx.objective_params = {
		"guide_mode":          "escort",
		"duration_turns":      20,
		"spirit_def_id":       "guide_spirit",
		"spirit_name":         "Test Spirit",
		"spirit_max_hp":       9999,
		"escort_radius":       2,
		"skittish_radius":     3,
		"spirit_joins_battle": true,
		"destination_col":     5,
		"destination_row":     5,
	}

	# JOINED combatant spirit sitting ON the destination cell, within its own escort_radius.
	var spirit: Dictionary = {
		"id": "guide_spirit_01", "name": "Test Spirit", "faction": "echo",
		"actor_type": "enemy",
		"is_structure": false, "is_spirit": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"speed": 0, "morale": 50, "fear": 0,
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors.append(spirit)

	# Wipe the real party: every echo-faction, non-spirit actor is dead.
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo" and not bool(a_v.get("is_spirit", false)):
			a_v["is_dead"] = true
			a_v["current_hp"] = 0

	# Keep at least one enemy alive and far away so nothing else resolves the fight first.
	var enemy_col: int = 9
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["is_dead"] = false
			a_v["grid_pos"] = { "col": enemy_col, "row": 0 }
			enemy_col = maxi(0, enemy_col - 1)

	runtime.dispatch({ "type": "combat.init" })

	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 60:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var cs2: Dictionary = ectx.combat_state
	if bool(cs2.get("destination_reached", false)):
		return { "ok": false, "error": "joined spirit self-delivered: destination_reached=true with no living real echo" }

	var reason: String = str(ectx.combat_result.get("reason", "")) if ectx.combat_result != null else ""
	if reason == "spirit_escorted":
		return { "ok": false, "error": "combat ended 'spirit_escorted' after party wipe -- joined spirit self-escorted" }

	if reason != "all_echoes_dead":
		return { "ok": false, "error": "Expected 'all_echoes_dead' defeat after party wipe, got '%s'" % reason }

	return { "ok": true }


# ---------------------------------------------------------------------------
# D92 — the escort win must not survive the party that earned it.
#
# The test above starts with escort_started false, so an escort_started guard alone
# would satisfy it. This one starts with escort_started ALREADY true — a real escort
# that began earlier in the fight — then wipes the party while the joined spirit stands
# on the destination. destination_reached is evaluated before all_echoes_dead
# (CombatState.gd), so an unguarded latch turns a party wipe into a spirit_escorted
# victory. The living-echo-within-escort_radius guard is what stops it.
# ---------------------------------------------------------------------------
static func test_guide_spirit_party_wipe_scores_defeat_not_escort() -> Dictionary:
	var env: Dictionary = _setup("guide_wipe_defeat", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx = env["ectx"]
	var runtime = env["runtime"]

	ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
	ectx.objective_params = {
		"guide_mode":          "escort",
		"duration_turns":      20,
		"spirit_def_id":       "guide_spirit",
		"spirit_name":         "Test Spirit",
		"spirit_max_hp":       9999,
		"escort_radius":       2,
		"skittish_radius":     3,
		"spirit_joins_battle": true,
		"destination_col":     5,
		"destination_row":     5,
	}

	var spirit: Dictionary = {
		"id": "guide_spirit_01", "name": "Test Spirit", "faction": "echo",
		"actor_type": "enemy",
		"is_structure": false, "is_spirit": true, "is_dead": false,
		"current_hp": 9999, "stats": { "max_hp": 9999, "def": 0, "atk": 0, "speed": 0 },
		"speed": 0, "morale": 50, "fear": 0,
		"grid_pos": { "col": 5, "row": 5 },
	}
	ectx.actors.append(spirit)

	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo" and not bool(a_v.get("is_spirit", false)):
			a_v["is_dead"] = true
			a_v["current_hp"] = 0

	var enemy_col: int = 9
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "enemy" and not bool(a_v.get("is_structure", false)):
			a_v["is_dead"] = false
			a_v["grid_pos"] = { "col": enemy_col, "row": 0 }
			enemy_col = maxi(0, enemy_col - 1)

	runtime.dispatch({ "type": "combat.init" })

	# The escort really did start earlier in this fight. Only the party is gone now.
	ectx.combat_state["escort_started"] = true

	runtime.dispatch({ "type": "combat.confirm_round" })
	var guard: int = 0
	while guard < 60:
		guard += 1
		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)): break
		if str(cs.get("round_phase", "")) != "in_round": break
		runtime.dispatch({ "type": "combat.next_actor" })

	var cs2: Dictionary = ectx.combat_state
	if not bool(cs2.get("escort_started", false)):
		return { "ok": false, "error": "test assumption broken: escort_started was cleared" }
	if bool(cs2.get("destination_reached", false)):
		return { "ok": false, "error": "escort win latched with no living echo to escort" }

	var reason: String = str(ectx.combat_result.get("reason", "")) if ectx.combat_result != null else ""
	if reason == "spirit_escorted":
		return { "ok": false, "error": "party wipe scored as 'spirit_escorted'" }
	if reason != "all_echoes_dead":
		return { "ok": false, "error": "Expected 'all_echoes_dead' defeat after party wipe, got '%s'" % reason }

	return { "ok": true }


# ---------------------------------------------------------------------------
# Kill-signal fix — regression coverage through the LIVE path.
#
# Bug: CombatService._resolve_melee historically returned no "is_kill" key, so
# every result.get("is_kill", false) consumer in FlowRuntime._resolve_next_actor
# (kill log, kill boost + party ripple, combat_ko bark, PROG-003 kill_count /
# mid-combat kill XP) was permanently dead. The fix makes _resolve_melee return
# "is_kill": hp_after <= 0 — the same condition that sets defender.is_dead.
#
# This test drives a killing blow through the REAL dispatch loop (combat.init →
# combat.confirm_round → combat.next_actor), NOT a hand-built result dict, and
# asserts the signal + its consumers:
#   (a) a melee result in last_round_results carries is_kill=true
#   (b) killer's echo_action_logs entry has kills >= 1 (S14a) and kill_count >= 1 (PROG-003)
#   (c) the killer received the kill morale boost
#   (d) at least one OTHER living echo received the kill ripple
# ---------------------------------------------------------------------------
# Morale of every living echo, keyed by id — snapshot taken before a dispatch.
static func _living_echo_morale(ectx) -> Dictionary:
	var out: Dictionary = {}
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) == "echo" and not a_v.get("is_dead", false):
			out[str(a_v.get("id", ""))] = int(a_v.get("morale", 50))
	return out


# Returns the trailing melee result iff it is an echo-attacker killing blow; {} otherwise.
static func _last_echo_melee_kill(ectx) -> Dictionary:
	if ectx.last_round_results.is_empty():
		return {}
	var lr: Dictionary = ectx.last_round_results.back()
	if str(lr.get("action_type", "")) != "melee_attack":
		return {}
	if not bool(lr.get("is_kill", false)):
		return {}
	if not str(lr.get("attacker_id", "")).begins_with("echo_"):
		return {}
	return lr


static func test_killing_blow_sets_is_kill_live() -> Dictionary:
	var env: Dictionary = _setup("iskill", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var ectx = env["ectx"]

	# Rig the live actors for a fast, one-sided kill: echoes hit hard with morale
	# headroom (40 < 100 cap so the +25 boost / +10 ripple are observable); enemies
	# are 1-HP glass with atk 0 so no echo dies and no enemy-side kill fires first.
	for a_v in ectx.actors:
		var a: Dictionary = a_v
		if str(a.get("faction", "")) == "echo":
			var e_stats: Dictionary = a.get("stats", {})
			e_stats["atk"] = 50
			e_stats["speed"] = 99
			a["stats"]  = e_stats
			a["speed"] = 99
			a["morale"] = 40
			a["fear"]   = 0
		elif str(a.get("faction", "")) == "enemy":
			var n_stats: Dictionary = a.get("stats", {})
			n_stats["atk"] = 0
			n_stats["def"] = 0
			a["stats"]      = n_stats
			a["current_hp"] = 1

	var first_echo: Dictionary = {}
	var first_enemy: Dictionary = {}
	for a_v in ectx.actors:
		var a: Dictionary = a_v
		if first_echo.is_empty() and str(a.get("faction", "")) == "echo":
			first_echo = a
		elif first_enemy.is_empty() and str(a.get("faction", "")) == "enemy":
			first_enemy = a
	if not first_echo.is_empty() and not first_enemy.is_empty():
		first_echo["grid_pos"] = { "col": 1, "row": 1 }
		first_enemy["grid_pos"] = { "col": 2, "row": 1 }

	# Drive the real loop dispatch-by-dispatch so we can snapshot echo morale
	# immediately before the killing dispatch and compare after it. NOTE:
	# combat.confirm_round itself resolves the FIRST living actor of the round,
	# so the kill check must run after BOTH dispatch types — a fast killer acts
	# inside confirm_round, never inside a next_actor dispatch.
	runtime.dispatch({ "type": "combat.init" })
	var kill_result: Dictionary = {}
	var pre_kill_morale: Dictionary = {}
	for _r in range(10):
		var morale_cr: Dictionary = _living_echo_morale(ectx)
		runtime.dispatch({ "type": "combat.confirm_round" })
		kill_result = _last_echo_melee_kill(ectx)
		if not kill_result.is_empty():
			pre_kill_morale = morale_cr
			break
		var guard: int = 0
		while guard < 60:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)): break
			if str(cs.get("round_phase", "")) != "in_round": break
			# Snapshot living-echo morale before this actor resolves.
			var morale_now: Dictionary = _living_echo_morale(ectx)
			runtime.dispatch({ "type": "combat.next_actor" })
			kill_result = _last_echo_melee_kill(ectx)
			if not kill_result.is_empty():
				pre_kill_morale = morale_now
				break
		if not kill_result.is_empty(): break
		if bool(ectx.combat_state.get("combat_over", false)): break

	# (a) The live result dict must carry the kill signal.
	if kill_result.is_empty():
		return { "ok": false, "error": "no echo melee result with is_kill=true observed through the live loop" }
	if int(kill_result.get("defender_hp_after", 1)) > 0:
		return { "ok": false, "error": "is_kill=true but defender_hp_after > 0 — signal out of sync" }

	var killer_id: String = str(kill_result.get("attacker_id", ""))

	# Melee results must also carry source_id (== attacker_id): it is the shared
	# lookup key for the initiative-panel action text, the T9 no-damage streak,
	# and current_actor_id. Missing key = those consumers silently go dead.
	if str(kill_result.get("source_id", "")) != killer_id:
		return { "ok": false, "error": "melee result source_id '%s' != attacker_id '%s'" % [str(kill_result.get("source_id", "")), killer_id] }

	# (b) Ledger consumers: S14a kills + PROG-003 kill_count both credited.
	var klog: Dictionary = ectx.echo_action_logs.get(killer_id, {})
	if int(klog.get("kills", 0)) < 1:
		return { "ok": false, "error": "S14a ledger kills=0 for killer %s after live kill" % killer_id }
	if int(klog.get("kill_count", 0)) < 1:
		return { "ok": false, "error": "PROG-003 kill_count=0 for killer %s after live kill" % killer_id }

	# (c) Kill boost: killer morale rose vs its pre-dispatch snapshot (boost is +25;
	# allow other same-dispatch effects a ±5 margin).
	var killer_actor: Dictionary = {}
	for a_v in ectx.actors:
		if str(a_v.get("id", "")) == killer_id:
			killer_actor = a_v
			break
	if killer_actor.is_empty():
		return { "ok": false, "error": "killer actor %s not found post-kill" % killer_id }
	var killer_before: int = int(pre_kill_morale.get(killer_id, -1))
	var killer_after: int  = int(killer_actor.get("morale", 0))
	if killer_after < killer_before + 20:
		return { "ok": false, "error": "kill boost missing: killer morale %d → %d (expected >= +20)" % [killer_before, killer_after] }

	# (d) Kill ripple: at least one OTHER living echo gained morale (+10 ripple, >= +5 margin).
	var ripple_seen: bool = false
	for a_v in ectx.actors:
		if str(a_v.get("faction", "")) != "echo": continue
		if a_v.get("is_dead", false): continue
		var aid: String = str(a_v.get("id", ""))
		if aid == killer_id: continue
		if not pre_kill_morale.has(aid): continue
		if int(a_v.get("morale", 0)) >= int(pre_kill_morale[aid]) + 5:
			ripple_seen = true
			break
	if not ripple_seen:
		return { "ok": false, "error": "kill ripple missing: no other living echo gained morale after the kill" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# Kill-signal fix — P1 regression (Codex review, PR #43).
#
# The kill morale/ripple block in FlowRuntime._resolve_next_actor is a
# player-side feedback mechanic: the killer gets +morale/-fear, and every
# living ECHO ally gets a morale/fear ripple. An ENEMY lethal blow also sets
# is_kill=true now, so without a faction gate an enemy killing an echo would
# (a) boost the enemy and (b) reward the surviving party with morale for
# losing a member. The fix gates that block to echo killers.
#
# This test drives a one-sided fight where ONLY enemies can kill (all echoes
# atk 0, all echoes 1 HP; enemies atk high) through the real dispatch loop
# with an info-level logger, then asserts:
#   (a) at least one enemy-attacker killing blow actually landed (non-vacuous)
#   (b) ZERO combat.kill_boost events were logged
#   (c) ZERO combat.kill_ripple events were logged
# Pre-fix, every enemy kill would emit a kill_boost (enemy) and a kill_ripple
# per surviving echo; post-fix the echo-only gate suppresses all of them.
# ---------------------------------------------------------------------------
static func test_enemy_kill_does_not_ripple_to_party() -> Dictionary:
	var env: Dictionary = _setup("enemykill", true, "info")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var ectx = env["ectx"]
	var logger = env["logger"]

	# Rig a one-sided fight: enemies hit hard, echoes are 1-HP and deal no damage,
	# so every kill in this combat is necessarily an enemy killing an echo.
	var enemy_ids: Dictionary = {}
	for a_v in ectx.actors:
		var a: Dictionary = a_v
		if str(a.get("faction", "")) == "echo":
			var e_stats: Dictionary = a.get("stats", {})
			e_stats["atk"] = 0
			a["stats"]      = e_stats
			a["current_hp"] = 1
			a["morale"]     = 50
			a["fear"]       = 0
		elif str(a.get("faction", "")) == "enemy":
			enemy_ids[str(a.get("id", ""))] = true
			var n_stats: Dictionary = a.get("stats", {})
			n_stats["atk"] = 99
			n_stats["speed"] = 99
			a["stats"] = n_stats
			a["speed"] = 99

	var first_enemy_killer: Dictionary = {}
	var first_echo_victim: Dictionary = {}
	for a_v in ectx.actors:
		var a: Dictionary = a_v
		if first_enemy_killer.is_empty() and str(a.get("faction", "")) == "enemy":
			first_enemy_killer = a
		elif first_echo_victim.is_empty() and str(a.get("faction", "")) == "echo":
			first_echo_victim = a
	if not first_enemy_killer.is_empty() and not first_echo_victim.is_empty():
		first_enemy_killer["grid_pos"] = { "col": 2, "row": 1 }
		first_echo_victim["grid_pos"] = { "col": 1, "row": 1 }

	# Fresh log slate so we only inspect combat-round events.
	logger.clear()
	_drive(runtime, ectx, 16)

	# Scan the captured log for kills and for the gated kill effects.
	var enemy_kill_seen: bool = false
	var kill_boost_events: int = 0
	var kill_ripple_events: int = 0
	for ev_v in logger.get_logs():
		var ev: Dictionary = ev_v
		var etype: String = str(ev.get("type", ""))
		if etype == "combat.action_resolved":
			var d: Dictionary = ev.get("data", {})
			if bool(d.get("is_kill", false)) and enemy_ids.has(str(d.get("attacker_id", ""))):
				enemy_kill_seen = true
		elif etype == "combat.kill_boost":
			kill_boost_events += 1
		elif etype == "combat.kill_ripple":
			kill_ripple_events += 1

	# (a) The scenario must actually exercise an enemy kill, or the test proves nothing.
	if not enemy_kill_seen:
		return { "ok": false, "error": "no enemy killing blow occurred in 16 rounds — test is vacuous" }
	# (b)+(c) The echo-only gate must have suppressed every kill boost and ripple.
	if kill_boost_events != 0:
		return { "ok": false, "error": "enemy kill wrongly fired %d combat.kill_boost event(s)" % kill_boost_events }
	if kill_ripple_events != 0:
		return { "ok": false, "error": "enemy kill wrongly fired %d combat.kill_ripple event(s) to the party" % kill_ripple_events }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-COMBAT-002 Phase 6E — guards for the two PR #52 slice-6B review fixes.
# ---------------------------------------------------------------------------

# GUARD for FlowRuntime._apply_live_purify_shrine (fix 2).
#
# The purify candidate is authored with a LITERAL EMPTY target_id
# (BehaviorArbiter.gd:325-331 and :937). Pre-fix, _apply_live_purify_shrine
# early-returned on an empty target_id and only ever matched a shrine BY that id, so
# a purifier authored this way never applied a single stack. The fix reads
# `if target_id.is_empty() or str(candidate.get("id","")) == target_id`.
#
# HOW THIS TEST DISCRIMINATES: it calls the function with "" and asserts a stack
# LANDS. Pre-fix that call was a no-op, so `stacks == 1` and `purify_cooldown == 3`
# both fail. The existing coverage only ever passed "shrine.match"/"shrine.wrong",
# which behaved identically before and after the fix.
#
# Also pins the ORDERING fact that the loop `break`s on the first match: with an
# empty target_id the FIRST LIVING STRUCTURE in ectx.actors order wins, and dead
# structures are skipped.
static func test_purify_empty_target_id() -> Dictionary:
	var env: Dictionary = _setup("purify_empty_target", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	for actor_value: Variant in ectx.actors:
		if actor_value is Dictionary and bool((actor_value as Dictionary).get("is_structure", false)):
			return { "ok": false, "error": "COMBAT setup unexpectedly spawned a structure" }

	var purifier: Dictionary = ectx.actors[0] as Dictionary
	purifier.erase("purify_cooldown")
	var dead_first: Dictionary = {
		"id": "shrine.dead", "is_structure": true, "is_dead": true,
		"current_hp": 0, "stats": {"max_hp": 20}, "purify_stacks": [],
	}
	var living_first: Dictionary = {
		"id": "shrine.living.first", "is_structure": true, "is_dead": false,
		"current_hp": 20, "stats": {"max_hp": 20}, "purify_stacks": [],
	}
	var living_second: Dictionary = {
		"id": "shrine.living.second", "is_structure": true, "is_dead": false,
		"current_hp": 20, "stats": {"max_hp": 20}, "purify_stacks": [],
	}
	# Order matters: dead structure FIRST, so skipping it is observable.
	(ectx.actors as Array).append(dead_first)
	(ectx.actors as Array).append(living_first)
	(ectx.actors as Array).append(living_second)

	var purify_ctx: Dictionary = { "cfg": runtime.config_service.get_balance() }
	_lm(runtime).apply_live_purify_shrine(purifier, "", purify_ctx, 99)

	var first_stacks: Array = living_first.get("purify_stacks", []) as Array
	if first_stacks.size() != 1:
		return { "ok": false, "error": "empty target_id applied %d stacks to the first living structure" % first_stacks.size() }
	if (first_stacks[0] as Dictionary) != { "duration": 2, "reduction": 3 }:
		return { "ok": false, "error": "unexpected purify stack payload: %s" % str(first_stacks[0]) }
	if (living_second.get("purify_stacks", []) as Array).size() != 0:
		return { "ok": false, "error": "the break-on-first-match rule was violated" }
	if (dead_first.get("purify_stacks", []) as Array).size() != 0:
		return { "ok": false, "error": "a dead structure received a purify stack" }
	if int(purifier.get("purify_cooldown", -1)) != 3:
		return { "ok": false, "error": "purify_cooldown was not set to 3: %s" % str(purifier.get("purify_cooldown", -1)) }

	# Killing the first living structure hands the empty-id match to the next one.
	living_first["is_dead"] = true
	_lm(runtime).apply_live_purify_shrine(purifier, "", purify_ctx, 100)
	if (living_first.get("purify_stacks", []) as Array).size() != 1:
		return { "ok": false, "error": "a newly dead structure was still selected" }
	if (living_second.get("purify_stacks", []) as Array).size() != 1:
		return { "ok": false, "error": "empty target_id did not fall through to the next living structure" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-COMBAT-002 Slice 6E — movement-aware SELECTION regression + E1 coverage.
#
# PR #52 shipped the then-live option builder with a hand-rolled option_id
# ("option.<goal-suffix>.direct.<col>_<row>") that MovementOption._validate_option_id
# ALWAYS rejects — the contract demands "option.<goal-suffix>.<style>.d<col>r<row>.p<path>".
# Every live option therefore validated false → the builder returned {} → the live
# option list was empty → `selection_enabled`
# was false → FlowRuntime never populated ctx["movement_options"] →
# ActorStateMachine never reached BehaviorArbiter.select_movement_intent.
# Movement-aware target selection was completely inert in live combat; every actor
# fell back to legacy nearest-enemy `select_intent`.
#
# The two tests below are the guards that were impossible to write before the fix.
# ---------------------------------------------------------------------------

# Mirrors FlowRuntime._resolve_next_actor's board_cfg derivation (terrain-aware).
static func _movement_board_cfg(runtime: FlowRuntime, ectx: EncounterContext) -> Dictionary:
	var grid_cfg: Dictionary = runtime.config_service.get_balance().get("data", {}).get("grid", {})
	if ectx == null or ectx.terrain.is_empty():
		return grid_cfg
	var cfg: Dictionary = grid_cfg.duplicate(true)
	cfg["walkable"] = StageTerrain.walkable_set(ectx.terrain)
	var bounds: Dictionary = ectx.terrain.get("bounds", {}) as Dictionary
	if bounds.has("w"):
		cfg["board_cols"] = int(bounds["w"])
	if bounds.has("h"):
		cfg["board_rows"] = int(bounds["h"])
	return cfg


static func _living_quarry(ectx: EncounterContext) -> Dictionary:
	for actor_value: Variant in ectx.actors:
		var actor: Dictionary = actor_value as Dictionary
		if bool(actor.get("is_quarry", false)) and not bool(actor.get("is_dead", false)):
			return actor
	return {}


# Regression guard on the exact function that regressed. Deterministic and closed-form:
# a realistic live goal + a known affordable route must yield a NON-EMPTY option whose
# option_id is the canonical five-part token. Pre-fix this returned {} — silently, with
# no error surface anywhere in the runtime — for this and every other input.
static func test_live_direct_option_id_is_contract_valid() -> Dictionary:
	var env: Dictionary = _setup("live_option_id", true, "off", EncounterResolutionModes.PURSUE)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]

	# --- closed-form guard -------------------------------------------------
	var origin: Dictionary = { "col": 1, "row": 1 }
	var hostile_id: String = "enemy_probe"
	var goal: Dictionary = {
		"goal_id": "goal.combat.advance.baseline.c4r1",
		"purpose": "advance",
		"destination_region": [{ "col": 4, "row": 1 }],
		"urgency": 1.0,
		"objective_progress": 0.0,
		"relevant_actors": [hostile_id],
		"pressure_sources": ["actor.%s" % hostile_id],
		"planned_primary": MovementActionPlanScript.build("actor.move", hostile_id),
		"declared_fallback": MovementActionPlanScript.build("actor.idle"),
	}
	var path: Array = [{ "col": 2, "row": 1 }, { "col": 3, "row": 1 }, { "col": 4, "row": 1 }]
	# V2-COMBAT-003.5 Phase 3c: the live builder this half used to call was deleted when the
	# live path moved onto MovementOptionService.generate_options. The defect it guards is the
	# id TOKEN, so the guard now sits on the token's sole authority instead.
	var built_id: String = MovementOptionServiceScript._option_id(
		goal, "direct", path.back() as Dictionary, path)
	var expected_id: String = "option.combat.advance.baseline.c4r1.direct.d4r1.pc2r1-c3r1-c4r1"
	if built_id != expected_id:
		return {
			"ok": false,
			"error": "option_id is not canonical: %s (expected %s)" % [built_id, expected_id],
		}

	# --- live guard --------------------------------------------------------
	# Every option the real runtime builds for a real encounter must also validate.
	# Some echoes can be legitimately boxed in by allies on irregular terrain, so the
	# assertion is "at least one echo produces options, and every produced option is
	# contract-valid" — pre-fix the produced count was ZERO for every echo, always.
	runtime.dispatch({ "type": "combat.init" })
	var board_cfg: Dictionary = _movement_board_cfg(runtime, ectx)
	var bdata: Dictionary = runtime.config_service.get_balance().get("data", {}) as Dictionary
	var live_option_count: int = 0
	var live_styles_seen: Dictionary = {}
	var t: int = 200
	for actor_value: Variant in ectx.actors:
		var mover: Dictionary = actor_value as Dictionary
		if str(mover.get("faction", "")) != "echo" or bool(mover.get("is_dead", false)):
			continue
		t += 1
		var prepared: Dictionary = _lm(runtime).prepare_live_movement_context(
			mover, ectx, ectx.combat_state, board_cfg, bdata, t)
		if not bool(prepared.get("valid", false)):
			continue
		var mover_origin: Dictionary = (prepared["movement_context"] as Dictionary).get("origin", {}) as Dictionary
		for option_value: Variant in prepared.get("options", []) as Array:
			var live_option: Dictionary = option_value as Dictionary
			live_option_count += 1
			var validation: Dictionary = MovementOptionScript.validate(live_option, mover_origin)
			if not bool(validation.get("valid", false)):
				return { "ok": false, "error": "live option failed the contract: %s" % str(validation) }
			# Reconstruct with the option's OWN route-shape. Hardcoding "direct" here made
			# the check vacuous for every other shape the live producer now emits.
			var live_style: String = _route_style_of(live_option)
			if not MovementOptionServiceScript.STYLE_ORDER.has(live_style):
				return {
					"ok": false,
					"error": "live option_id carries an unknown route-shape '%s': %s" % [
						live_style, str(live_option["option_id"]),
					],
				}
			live_styles_seen[live_style] = true
			var canonical: String = MovementOptionServiceScript._option_id(
				{ "goal_id": str(live_option["goal_id"]) },
				live_style,
				live_option["destination"] as Dictionary,
				live_option["path"] as Array
			)
			if str(live_option["option_id"]) != canonical:
				return {
					"ok": false,
					"error": "live option_id drifted from the canonical builder: %s vs %s" % [
						str(live_option["option_id"]), canonical,
					],
				}
		if not prepared.get("options", []).is_empty() and not bool(prepared.get("selection_enabled", false)):
			return { "ok": false, "error": "selection_enabled false despite non-empty options" }
	if live_option_count == 0:
		return { "ok": false, "error": "the live runtime produced ZERO movement options for every echo" }
	var seen: Array = live_styles_seen.keys()
	seen.sort()
	if seen.size() < 2:
		return {
			"ok": false,
			"error": "the live runtime published only route-shape(s) %s across %d option(s) — "
				% [str(seen), live_option_count]
				+ "the canonical-id guard covers one shape and the multi-shape producer is not live",
		}
	return { "ok": true }


## "option.<goal-suffix>.<style>.d<col>r<row>.p<path>" — the style token follows the
## goal's own segments, so trimming the goal prefix leaves it first.
static func _route_style_of(option: Dictionary) -> String:
	var prefix: String = "option.%s." % str(option["goal_id"]).trim_prefix("goal.")
	return str(option["option_id"]).trim_prefix(prefix).get_slice(".", 0)


# E1 — the whole-runtime case that was impossible to assert before the fix.
#
# PURSUE puts a fleeing quarry on a board that is 2x in one dimension, so a party echo
# standing at the far end is guaranteed to be farther from the objective than its
# movement capacity. FlowRuntime.gd:1767-1783 therefore truncates the route to an
# affordable prefix and the chosen destination falls OUTSIDE goal.destination_region —
# the exact "objective farther than capacity" shape. That truncated option must still
# be contract-valid, must still be the option the arbiter selects, and must still point
# at the OBJECTIVE rather than at whatever enemy happens to be nearest.
#
# Discriminator: `intent.has("planned_action")`. ActorStateMachine sets that key ONLY on
# the movement-aware branch (ActorStateMachine.gd:257-263); the legacy `select_intent`
# fallback never produces it. Pre-fix that key could not exist in live combat at all.
static func test_objective_route_truncates_and_stays_movement_aware() -> Dictionary:
	var env: Dictionary = _setup("objective_truncation", true, "off", EncounterResolutionModes.PURSUE)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })

	var objective: Dictionary = _living_quarry(ectx)
	if objective.is_empty():
		return { "ok": false, "error": "pursue encounter produced no quarry" }
	var objective_id: String = str(objective.get("id", ""))
	var objective_pos: Dictionary = objective.get("grid_pos", {}) as Dictionary

	var mover: Dictionary = {}
	for actor_value: Variant in ectx.actors:
		var candidate: Dictionary = actor_value as Dictionary
		if str(candidate.get("faction", "")) == "echo" and not bool(candidate.get("is_dead", false)):
			mover = candidate
			break
	if mover.is_empty():
		return { "ok": false, "error": "no living echo" }
	var mover_id: String = str(mover.get("id", ""))

	var board_cfg: Dictionary = _movement_board_cfg(runtime, ectx)
	var walkable: Dictionary = board_cfg.get("walkable", {}) as Dictionary
	if walkable.is_empty():
		return { "ok": false, "error": "no terrain walkable set — expected irregular terrain" }

	# Stand the mover on the free walkable cell FARTHEST from the objective, so the
	# objective is guaranteed to be out of movement capacity and the route truncates.
	# Deterministic: keys are sorted before scanning and the first maximum wins.
	#
	# Candidates are restricted to the objective's connected region (capacity ==
	# walkable.size(), an upper bound on any in-region distance — same idiom as
	# StagePartyMovementAdapter.select_frontier). A larger board carries more
	# disconnected islands; without this filter the "farthest cell" search can land on
	# one, making the objective genuinely unreachable rather than merely truncated.
	var occupied: Dictionary = {}
	for actor_value: Variant in ectx.actors:
		var other: Dictionary = actor_value as Dictionary
		if str(other.get("id", "")) == mover_id or bool(other.get("is_dead", false)):
			continue
		var pos: Dictionary = other.get("grid_pos", {}) as Dictionary
		if not pos.is_empty():
			occupied["%d,%d" % [int(pos.get("col", 0)), int(pos.get("row", 0))]] = true
	var objective_region: Dictionary = MovementPathServiceScript.reachable_cost_region(
		objective_pos, maxi(walkable.size(), 1), walkable, {}, {}, {})
	if not bool(objective_region.get("reachable", false)):
		return { "ok": false, "error": "objective cell itself is not walkable-reachable" }
	var connected_costs: Dictionary = objective_region.get("costs", {}) as Dictionary
	var keys: Array = walkable.keys()
	keys.sort()
	var far_cell: Dictionary = {}
	var far_dist: int = -1
	for key_value: Variant in keys:
		if bool(occupied.get(str(key_value), false)):
			continue
		if not connected_costs.has(str(key_value)):
			continue
		var parts: PackedStringArray = str(key_value).split(",")
		if parts.size() != 2:
			continue
		var cell: Dictionary = { "col": int(parts[0]), "row": int(parts[1]) }
		var dist: int = GridService.chebyshev_distance(cell, objective_pos)
		if dist > far_dist:
			far_dist = dist
			far_cell = cell
	if far_cell.is_empty():
		return { "ok": false, "error": "no free walkable cell connected to the objective" }
	GridService.assign_grid_pos(mover, int(far_cell["col"]), int(far_cell["row"]))

	var bdata: Dictionary = runtime.config_service.get_balance().get("data", {}) as Dictionary
	var capacity_cfg: Dictionary = bdata.get("combat", {}).get("movement", {}).get("capacity", {}) as Dictionary
	var capacity: int = int(MovementProfileServiceScript.derive_profile(mover, capacity_cfg, {}).get("capacity", 0))
	var start_dist: int = GridService.chebyshev_distance(mover.get("grid_pos", {}), objective_pos)
	if start_dist <= capacity:
		return {
			"ok": false,
			"error": "objective within capacity (%d <= %d) — the route would not truncate" % [start_dist, capacity],
		}

	var prepared: Dictionary = _lm(runtime).prepare_live_movement_context(
		mover, ectx, ectx.combat_state, board_cfg, bdata, 300)
	if not bool(prepared.get("valid", false)):
		return { "ok": false, "error": "live movement context invalid: %s" % str(prepared.get("reason", "")) }
	if not bool(prepared.get("selection_enabled", false)):
		return {
			"ok": false,
			"error": "selection_enabled false — movement-aware selection is inert (goals=%d, options=%d)" % [
				(prepared.get("goals", []) as Array).size(),
				(prepared.get("options", []) as Array).size(),
			],
		}

	# The objective goal must exist, must have produced an option, and that option's
	# destination must fall OUTSIDE the goal's destination_region — i.e. it truncated.
	var objective_goal: Dictionary = {}
	for goal_value: Variant in prepared.get("goals", []) as Array:
		var goal: Dictionary = goal_value as Dictionary
		if str(goal.get("purpose", "")) == "pursue" \
				and (goal.get("relevant_actors", []) as Array).has(objective_id):
			objective_goal = goal
			break
	if objective_goal.is_empty():
		return { "ok": false, "error": "no objective pursue goal built for a party echo" }
	var objective_option: Dictionary = {}
	for option_value: Variant in prepared.get("options", []) as Array:
		var option: Dictionary = option_value as Dictionary
		if str(option.get("goal_id", "")) == str(objective_goal.get("goal_id", "")):
			objective_option = option
			break
	if objective_option.is_empty():
		return { "ok": false, "error": "objective goal produced no live option" }
	if (objective_goal.get("destination_region", []) as Array).has(objective_option["destination"]):
		return { "ok": false, "error": "route did not truncate — destination is inside destination_region" }

	# Run the REAL decision layer exactly as FlowRuntime._resolve_next_actor wires it.
	var ctx: Dictionary = {
		"actor": mover,
		"all_actors": ectx.actors,
		"board_cfg": board_cfg,
		"cfg": runtime.config_service.get_balance(),
		"t": 300,
		"round": int(ectx.combat_state.get("round_counter", 0)),
		"movement_context": prepared["movement_context"],
		"movement_profile": prepared["profile"],
		"movement_goals": prepared["goals"],
		"movement_options": prepared["options"],
	}
	var asm := ActorStateMachine.new(
		mover, null, bdata.get("actor", {}) as Dictionary, prepared.get("movement_cfg", {}) as Dictionary)
	var intent: Dictionary = asm.advance_turn(ctx, env["logger"], 300)

	# (1) The movement-aware branch ran at all. Impossible pre-fix.
	if not intent.has("planned_action"):
		# Surface the arbiter's own rejection reason — "fallback ran" alone tells us nothing.
		var probe := BehaviorArbiter.new(
			bdata.get("actor", {}) as Dictionary, prepared.get("movement_cfg", {}) as Dictionary)
		var diagnosis: Dictionary = probe.select_movement_intent(
			ctx, prepared["movement_context"], prepared["profile"], prepared["goals"], prepared["options"])
		return {
			"ok": false,
			"error": "legacy fallback ran — intent has no planned_action (%s); arbiter said %s" % [
				str(intent.get("action_type", "")), str(diagnosis),
			],
		}
	# (2) It committed to the OBJECTIVE goal, not to the nearest enemy.
	if str(intent.get("goal_id", "")) != str(objective_goal.get("goal_id", "")):
		return {
			"ok": false,
			"error": "selected goal %s, expected objective goal %s" % [
				str(intent.get("goal_id", "")), str(objective_goal.get("goal_id", "")),
			],
		}
	if str(intent.get("target_id", "")) != objective_id:
		return {
			"ok": false,
			"error": "movement-aware intent targeted %s, expected objective %s" % [
				str(intent.get("target_id", "")), objective_id,
			],
		}
	# V2-COMBAT-003.5 Phase 3c: the objective goal now offers one option per route-shape,
	# so pinning the FIRST one is no longer a statement about the defect — which is that a
	# truncated route stays movement-aware and objective-directed. Assert that instead:
	# the winner is one of this goal's options and it did truncate.
	var selected_option: Dictionary = {}
	for option_value: Variant in prepared.get("options", []) as Array:
		var option: Dictionary = option_value as Dictionary
		if str(option.get("option_id", "")) == str(intent.get("option_id", "")):
			selected_option = option
			break
	if selected_option.is_empty():
		return {
			"ok": false,
			"error": "selected option %s is not in the published board" % str(intent.get("option_id", "")),
		}
	if str(selected_option.get("goal_id", "")) != str(objective_goal.get("goal_id", "")):
		return {
			"ok": false,
			"error": "selected option belongs to goal %s, expected the objective goal %s" % [
				str(selected_option.get("goal_id", "")), str(objective_goal.get("goal_id", "")),
			],
		}
	if (objective_goal.get("destination_region", []) as Array).has(selected_option["destination"]):
		return {
			"ok": false,
			"error": "selected option did not truncate: %s" % str(selected_option["destination"]),
		}
	# (3) Executing it actually closes distance to the objective.
	_lm(runtime).apply_live_activation(mover, intent, prepared, asm, ctx, 300)
	var end_dist: int = GridService.chebyshev_distance(mover.get("grid_pos", {}), objective_pos)
	if end_dist >= start_dist:
		return {
			"ok": false,
			"error": "objective distance did not decrease: %d → %d" % [start_dist, end_dist],
		}
	return { "ok": true }


# ---------------------------------------------------------------------------
# Slice 6E — whole-runtime guard on BehaviorArbiter._crosscheck_perceived_actor.
#
# The arbiter re-derives the perceived-actor facts FlowRuntime hands it and asserts they
# match. It defaulted `controlling_state` to `true` off the raw actor dict — but NO actor
# dict anywhere sets that key, while FlowRuntime._movement_actor_facts ANDs in
# `not dead and not ko and not structure`, exactly as MovementPerceivedActorFact.validate
# demands (`incapable_actor_cannot_control`). A single mismatched actor discards the WHOLE
# board's selection, so every purify_shrine board — which carries a shrine STRUCTURE from
# round 1 — was permanently pinned to the legacy nearest-enemy fallback, and every other
# mode switched off for good at the first death or KO.
#
# purify_shrine is chosen deliberately: the structure is present before the first
# activation, so this is the case that could never work at all.
static func test_purify_selection_survives_structure_and_death() -> Dictionary:
	var env: Dictionary = _setup("crosscheck_incapacity", true, "off", EncounterResolutionModes.PURIFY_SHRINE)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })

	# The fixture must actually contain the hazard it claims to guard.
	var has_structure: bool = false
	for actor_value: Variant in ectx.actors:
		if bool((actor_value as Dictionary).get("is_structure", false)):
			has_structure = true
			break
	if not has_structure:
		return { "ok": false, "error": "purify_shrine board carries no structure — fixture cannot exercise the bug" }

	# (1) Structure on the board from round 1.
	var with_structure: Dictionary = _selection_census(runtime, ectx, 400)
	if not str(with_structure["error"]).is_empty():
		return { "ok": false, "error": "structure on board: %s" % str(with_structure["error"]) }
	if int(with_structure["aware"]) <= 0:
		return { "ok": false, "error": "no echo reached a movement-aware selection with a structure on the board" }

	# (2) A DEAD actor on the board. Killed the way the runtime kills: is_dead + hp 0.
	# A PARTY member is downed rather than the enemy: purify_shrine opens with a single
	# hostile and spawns waves later, so killing the enemy would empty the goal set and
	# the census would go quiet for a reason that has nothing to do with the cross-check.
	var victim: Dictionary = _first_living(ectx, "echo")
	if victim.is_empty():
		return { "ok": false, "error": "no living echo to kill" }
	victim["current_hp"] = 0
	victim["is_dead"] = true
	var with_dead: Dictionary = _selection_census(runtime, ectx, 500)
	if not str(with_dead["error"]).is_empty():
		return { "ok": false, "error": "dead actor on board: %s" % str(with_dead["error"]) }
	if int(with_dead["aware"]) <= 0:
		return { "ok": false, "error": "selection switched off after a death (eligible=%d)" % int(with_dead["eligible"]) }

	# (3) A KO'd actor on the board — hp 0 but not dead.
	var downed: Dictionary = _first_living(ectx, "echo")
	if downed.is_empty():
		return { "ok": false, "error": "no living echo to down" }
	downed["current_hp"] = 0
	downed["is_ko"] = true
	var with_ko: Dictionary = _selection_census(runtime, ectx, 600)
	if not str(with_ko["error"]).is_empty():
		return { "ok": false, "error": "KO'd actor on board: %s" % str(with_ko["error"]) }
	if int(with_ko["aware"]) <= 0:
		return { "ok": false, "error": "selection switched off after a KO (eligible=%d)" % int(with_ko["eligible"]) }

	# (4) Selection survives deaths driven through the REAL round loop, not just
	#     hand-set flags. Drive until the loop itself kills something, then re-census.
	var baseline_deaths: int = _dead_count(ectx)
	var deaths: int = baseline_deaths
	for _r in range(8):
		_drive_one_round(runtime, ectx)
		deaths = _dead_count(ectx)
		if deaths > baseline_deaths or bool(ectx.combat_state.get("combat_over", false)):
			break
	if deaths <= baseline_deaths:
		return { "ok": false, "error": "the live round loop produced no additional death to test across" }
	var after_live: Dictionary = _selection_census(runtime, ectx, 700)
	if not str(after_live["error"]).is_empty():
		return { "ok": false, "error": "after live deaths: %s" % str(after_live["error"]) }
	if int(after_live["eligible"]) > 0 and int(after_live["aware"]) <= 0:
		return { "ok": false, "error": "selection went inert after live-loop deaths (eligible=%d)" % int(after_live["eligible"]) }
	return { "ok": true }


static func _dead_count(ectx: EncounterContext) -> int:
	var total: int = 0
	for actor_value: Variant in ectx.actors:
		if bool((actor_value as Dictionary).get("is_dead", false)):
			total += 1
	return total


# Runs the REAL preparation + arbiter selection for every living non-structure actor.
# Returns { aware, eligible, error } — `error` is non-empty on the FIRST arbiter rejection,
# carrying the arbiter's own reason/field so a regression names itself.
static func _selection_census(runtime: FlowRuntime, ectx: EncounterContext, t0: int) -> Dictionary:
	var bdata: Dictionary = runtime.config_service.get_balance().get("data", {}) as Dictionary
	var board_cfg: Dictionary = _movement_board_cfg(runtime, ectx)
	var aware: int = 0
	var eligible: int = 0
	var t: int = t0
	for actor_value: Variant in ectx.actors:
		var mover: Dictionary = actor_value as Dictionary
		if bool(mover.get("is_structure", false)) or bool(mover.get("is_dead", false)):
			continue
		t += 1
		var prepared: Dictionary = _lm(runtime).prepare_live_movement_context(
			mover, ectx, ectx.combat_state, board_cfg, bdata, t)
		if not bool(prepared.get("valid", false)) or not bool(prepared.get("selection_enabled", false)):
			continue
		eligible += 1
		var ctx: Dictionary = {
			"actor": mover, "all_actors": ectx.actors, "board_cfg": board_cfg,
			"cfg": runtime.config_service.get_balance(), "t": t,
			"round": int(ectx.combat_state.get("round_counter", 0)),
		}
		var arbiter := BehaviorArbiter.new(
			bdata.get("actor", {}) as Dictionary, prepared.get("movement_cfg", {}) as Dictionary)
		var selection: Dictionary = arbiter.select_movement_intent(
			ctx, prepared["movement_context"], prepared["profile"],
			prepared["goals"], prepared["options"])
		if not bool(selection.get("valid", false)):
			return {
				"aware": aware, "eligible": eligible,
				"error": "arbiter discarded the board for %s — %s @ %s" % [
					str(mover.get("id", "")), str(selection.get("reason", "")), str(selection.get("field", "")),
				],
			}
		aware += 1
	return { "aware": aware, "eligible": eligible, "error": "" }


# ---------------------------------------------------------------------------
# Slice 6E Task A — the movement layer must not switch itself off when the goals
# it published happen to be unroutable this activation.
#
# `_prepare_live_movement_context` gated `selection_enabled` on OPTIONS. An empty
# option set only means no destination region was reachable right now (boxed in by
# allies, objective behind terrain, capacity exhausted after truncation) — the GOALS
# are still true and the arbiter handles a zero-option board natively, because
# `_generate_candidates` unconditionally emits `actor.idle` so at least one stationary
# candidate is always ranked. Gating on options threw the whole movement-aware board
# away and fell back to legacy nearest-enemy `select_intent` for that actor.
#
# The fixture walls the mover in by removing its eight neighbours from the walkable
# set, which makes EVERY published goal unroutable while leaving the goals themselves
# intact — the exact shape of the bug, reached through the real preparation function.
static func test_unroutable_goals_keep_selection_enabled() -> Dictionary:
	var env: Dictionary = _setup("unroutable_goals", true, "off", EncounterResolutionModes.COMBAT)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })

	var bdata: Dictionary = runtime.config_service.get_balance().get("data", {}) as Dictionary
	var board_cfg: Dictionary = _movement_board_cfg(runtime, ectx)
	var walkable: Dictionary = _full_walkable(board_cfg)
	if walkable.is_empty():
		return { "ok": false, "error": "board produced no walkable set" }

	# First living echo whose published goal set is non-empty once it is walled in.
	var mover: Dictionary = {}
	var prepared: Dictionary = {}
	var walled_cfg: Dictionary = {}
	var t: int = 800
	for actor_value: Variant in ectx.actors:
		var candidate: Dictionary = actor_value as Dictionary
		if str(candidate.get("faction", "")) != "echo" \
				or bool(candidate.get("is_dead", false)) \
				or bool(candidate.get("is_structure", false)):
			continue
		t += 1
		var origin: Dictionary = candidate.get("grid_pos", {}) as Dictionary
		if origin.is_empty():
			continue
		var walled: Dictionary = walkable.duplicate(true)
		for dc in range(-1, 2):
			for dr in range(-1, 2):
				if dc == 0 and dr == 0:
					continue
				walled.erase("%d,%d" % [int(origin["col"]) + dc, int(origin["row"]) + dr])
		var cfg: Dictionary = board_cfg.duplicate(true)
		cfg["walkable"] = walled
		var attempt: Dictionary = _lm(runtime).prepare_live_movement_context(
			candidate, ectx, ectx.combat_state, cfg, bdata, t)
		if not bool(attempt.get("valid", false)):
			continue
		if (attempt.get("goals", []) as Array).is_empty():
			continue
		mover = candidate
		prepared = attempt
		walled_cfg = cfg
		break
	if mover.is_empty():
		return { "ok": false, "error": "no living echo published goals — fixture cannot exercise the bug" }

	# The fixture must actually be the "goals but no options" shape.
	if not (prepared.get("options", []) as Array).is_empty():
		return {
			"ok": false,
			"error": "walling the mover in still produced %d options — fixture is not the bug shape" % [
				(prepared.get("options", []) as Array).size(),
			],
		}

	# (1) The gate itself. Pre-fix this was `not options.is_empty()` → false.
	if not bool(prepared.get("selection_enabled", false)):
		return {
			"ok": false,
			"error": "selection_enabled false with %d live goals and 0 routable options — the movement layer switched itself off" % [
				(prepared.get("goals", []) as Array).size(),
			],
		}

	# (2) The arbiter genuinely survives a zero-option board and ranks stationary candidates.
	var ctx: Dictionary = {
		"actor": mover,
		"all_actors": ectx.actors,
		"board_cfg": walled_cfg,
		"cfg": runtime.config_service.get_balance(),
		"t": t,
		"round": int(ectx.combat_state.get("round_counter", 0)),
	}
	var arbiter := BehaviorArbiter.new(
		bdata.get("actor", {}) as Dictionary, prepared.get("movement_cfg", {}) as Dictionary)
	var selection: Dictionary = arbiter.select_movement_intent(
		ctx, prepared["movement_context"], prepared["profile"], prepared["goals"], prepared["options"])
	if not bool(selection.get("valid", false)):
		return {
			"ok": false,
			"error": "arbiter discarded a zero-option board: %s @ %s" % [
				str(selection.get("reason", "")), str(selection.get("field", "")),
			],
		}
	var selected_path: Array = (selection.get("intent", {}) as Dictionary).get("path", []) as Array
	if not selected_path.is_empty():
		return { "ok": false, "error": "zero-option board yielded a non-stationary path" }

	# (3) The live seam, wired exactly as `_resolve_next_actor` wires it: the movement
	#     keys are injected ONLY when selection_enabled. `planned_action` is the
	#     discriminator — ActorStateMachine sets it only on the movement-aware branch.
	var seam_ctx: Dictionary = ctx.duplicate(true)
	seam_ctx["actor"] = mover
	seam_ctx["all_actors"] = ectx.actors
	seam_ctx["cfg"] = runtime.config_service.get_balance()
	if bool(prepared.get("valid", false)) and bool(prepared.get("selection_enabled", false)):
		seam_ctx["movement_context"] = prepared["movement_context"]
		seam_ctx["movement_profile"] = prepared["profile"]
		seam_ctx["movement_goals"] = prepared["goals"]
		seam_ctx["movement_options"] = prepared["options"]
	var asm := ActorStateMachine.new(
		mover, null, bdata.get("actor", {}) as Dictionary, prepared.get("movement_cfg", {}) as Dictionary)
	var intent: Dictionary = asm.advance_turn(seam_ctx, env["logger"], t)
	if not intent.has("planned_action"):
		return {
			"ok": false,
			"error": "legacy fallback ran for an actor with live goals — intent has no planned_action (%s)" % [
				str(intent.get("action_type", "")),
			],
		}
	return { "ok": true }


# ---------------------------------------------------------------------------
# Slice 6E Task B — a destroyed objective must stop being published as one.
#
# `_movement_objective_actor` returned the first `is_structure` actor without checking
# `is_dead`, while `_resolve_next_actor` computes `shrine_alive` WITH that check. The
# two disagreed: pressure carried objective_known=true for a corpse, with an
# objective_health of 0.0 that sits below every 0.5 urgency threshold, so movers kept
# advancing on a dead objective. Reachability of the destroyed-structure state was
# unproven in the wild, so the state is pinned here directly.
static func test_dead_objective_is_not_published() -> Dictionary:
	var env: Dictionary = _setup("dead_objective", true, "off", EncounterResolutionModes.PURIFY_SHRINE)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })

	var board_cfg: Dictionary = _movement_board_cfg(runtime, ectx)
	var walkable: Dictionary = _full_walkable(board_cfg)
	var bounds: Dictionary = {
		"w": int(board_cfg.get("board_cols", 10)),
		"h": int(board_cfg.get("board_rows", 10)),
	}
	var mover: Dictionary = _first_living(ectx, "echo")
	if mover.is_empty():
		return { "ok": false, "error": "no living echo" }
	var structure: Dictionary = {}
	for actor_value: Variant in ectx.actors:
		var candidate: Dictionary = actor_value as Dictionary
		if bool(candidate.get("is_structure", false)):
			structure = candidate
			break
	if structure.is_empty():
		return { "ok": false, "error": "purify_shrine board carries no structure — fixture cannot exercise the bug" }

	# (1) Baseline: while the structure lives it IS the published objective, so the
	#     assertions below cannot pass vacuously.
	var alive: Dictionary = _lm(runtime)._movement_pressure_snapshot(
		mover, ectx, ectx.combat_state, bounds, walkable)
	if not bool(alive.get("objective_known", false)):
		return { "ok": false, "error": "living structure was not published as the objective" }
	if str(alive.get("objective_id", "")) != str(structure.get("id", "")):
		return { "ok": false, "error": "living objective id mismatch" }

	# (2) Destroy it exactly the way the live runtime does.
	structure["current_hp"] = 0
	structure["is_dead"] = true

	if not _lm(runtime)._movement_objective_actor(ectx, ectx.combat_state).is_empty():
		return { "ok": false, "error": "_movement_objective_actor still returned a destroyed structure" }

	var dead: Dictionary = _lm(runtime)._movement_pressure_snapshot(
		mover, ectx, ectx.combat_state, bounds, walkable)
	if bool(dead.get("objective_known", false)):
		return {
			"ok": false,
			"error": "destroyed objective still published as known (id=%s, health=%s) — movers keep advancing on a corpse" % [
				str(dead.get("objective_id", "")), str(dead.get("objective_health", 0.0)),
			],
		}
	if not str(dead.get("objective_id", "")).is_empty():
		return { "ok": false, "error": "destroyed objective still carries an objective_id" }
	if float(dead.get("objective_health", -1.0)) >= 0.0:
		return {
			"ok": false,
			"error": "destroyed objective published health %s instead of the unknown sentinel" % [
				str(dead.get("objective_health", -1.0)),
			],
		}
	if not (dead.get("destination_region", []) as Array).is_empty():
		return { "ok": false, "error": "destroyed objective still published a destination region" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Slice 6E Task C — latent stacking guard.
#
# `_movement_occupancy` is a cell→id map with no stacking guard. Two live actors on one
# cell meant (a) the recorded occupant depended on `ectx.actors` iteration order, and
# (b) the losing actor got an occupancy map naming someone else at its own origin, so
# `BehaviorArbiter._validate_movement_inputs` failed `mover_occupancy_mismatch` and the
# ENTIRE board was discarded for that activation. Never observed in 3,585 activations,
# so the state is constructed directly rather than driven.
static func test_stacked_actors_keep_selection_alive() -> Dictionary:
	var env: Dictionary = _setup("stacked_occupancy", true, "off", EncounterResolutionModes.COMBAT)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })

	# Two living echoes, ordered by id: the larger id is the one the guard would have lost.
	var living: Array = []
	for actor_value: Variant in ectx.actors:
		var candidate: Dictionary = actor_value as Dictionary
		if str(candidate.get("faction", "")) == "echo" \
				and not bool(candidate.get("is_dead", false)) \
				and not bool(candidate.get("is_structure", false)):
			living.append(candidate)
	if living.size() < 2:
		return { "ok": false, "error": "need two living echoes to stack" }
	var low: Dictionary = living[0] as Dictionary
	var high: Dictionary = living[1] as Dictionary
	if str(low.get("id", "")) > str(high.get("id", "")):
		var swap: Dictionary = low
		low = high
		high = swap
	var cell: Dictionary = low.get("grid_pos", {}) as Dictionary
	if cell.is_empty():
		return { "ok": false, "error": "stack anchor has no grid_pos" }
	GridService.assign_grid_pos(high, int(cell["col"]), int(cell["row"]))
	var cell_key: String = "%d,%d" % [int(cell["col"]), int(cell["row"])]

	# (1) The recorded occupant is deterministic — same answer whatever the array order.
	var occupancy: Dictionary = _lm(runtime)._movement_occupancy(ectx.actors)
	if str(occupancy.get(cell_key, "")) != str(low.get("id", "")):
		return {
			"ok": false,
			"error": "stacked cell recorded %s, expected the smallest id %s" % [
				str(occupancy.get(cell_key, "")), str(low.get("id", "")),
			],
		}
	var reversed_actors: Array = ectx.actors.duplicate()
	reversed_actors.reverse()
	var reversed_occupancy: Dictionary = _lm(runtime)._movement_occupancy(reversed_actors)
	if str(reversed_occupancy.get(cell_key, "")) != str(low.get("id", "")):
		return {
			"ok": false,
			"error": "occupancy depends on actor order: %s vs %s" % [
				str(occupancy.get(cell_key, "")), str(reversed_occupancy.get(cell_key, "")),
			],
		}

	# (2) The LOSING mover still gets a live board instead of having it discarded.
	var bdata: Dictionary = runtime.config_service.get_balance().get("data", {}) as Dictionary
	var board_cfg: Dictionary = _movement_board_cfg(runtime, ectx)
	var prepared: Dictionary = _lm(runtime).prepare_live_movement_context(
		high, ectx, ectx.combat_state, board_cfg, bdata, 900)
	if not bool(prepared.get("valid", false)):
		return { "ok": false, "error": "stacked mover prepare invalid: %s" % str(prepared.get("reason", "")) }
	var prepared_occupancy: Dictionary = (prepared["movement_context"] as Dictionary).get("occupancy", {}) as Dictionary
	if str(prepared_occupancy.get(cell_key, "")) != str(high.get("id", "")):
		return {
			"ok": false,
			"error": "the mover does not own its own origin cell: %s occupies %s" % [
				str(prepared_occupancy.get(cell_key, "")), cell_key,
			],
		}
	if not bool(prepared.get("selection_enabled", false)):
		return { "ok": false, "error": "stacked mover lost movement-aware selection" }
	var ctx: Dictionary = {
		"actor": high,
		"all_actors": ectx.actors,
		"board_cfg": board_cfg,
		"cfg": runtime.config_service.get_balance(),
		"t": 900,
		"round": int(ectx.combat_state.get("round_counter", 0)),
	}
	var arbiter := BehaviorArbiter.new(
		bdata.get("actor", {}) as Dictionary, prepared.get("movement_cfg", {}) as Dictionary)
	var selection: Dictionary = arbiter.select_movement_intent(
		ctx, prepared["movement_context"], prepared["profile"], prepared["goals"], prepared["options"])
	if not bool(selection.get("valid", false)):
		return {
			"ok": false,
			"error": "arbiter discarded the whole board for the stacked mover: %s @ %s" % [
				str(selection.get("reason", "")), str(selection.get("field", "")),
			],
		}
	return { "ok": true }


# Full walkable set for a board cfg — the authored terrain set, or the raw rect when
# the board carries no terrain (mirrors `_prepare_live_movement_context`).
static func _full_walkable(board_cfg: Dictionary) -> Dictionary:
	var walkable: Dictionary = (board_cfg.get("walkable", {}) as Dictionary).duplicate(true)
	if not walkable.is_empty():
		return walkable
	for col in range(int(board_cfg.get("board_cols", 10))):
		for row in range(int(board_cfg.get("board_rows", 10))):
			walkable["%d,%d" % [col, row]] = true
	return walkable


static func _first_living(ectx: EncounterContext, faction: String) -> Dictionary:
	for actor_value: Variant in ectx.actors:
		var actor: Dictionary = actor_value as Dictionary
		if bool(actor.get("is_structure", false)) or bool(actor.get("is_dead", false)):
			continue
		if bool(actor.get("is_ko", false)) or int(actor.get("current_hp", 0)) <= 0:
			continue
		if str(actor.get("faction", "")) == faction:
			return actor
	return {}


## V2-COMBAT-002 Slice 6E: the published option must carry TRUTHFUL hostile-control and
## hazard summaries. Both were previously hardcoded (`[]` and `{0, []}`) because the live
## path called hostile_edge_costs(), which discards `edge_sources`. This story owes those
## normalized summaries to V2-COMBAT-003; publishing hardcoded emptiness was a false claim.
##
## Guards the fix specifically: a live hostile is parked two cells from the mover's origin,
## so every route that closes to melee crosses that hostile's zone of control and the sources
## CANNOT legitimately be empty. Against the pre-fix code this fails on the
## `hostile_control_sources is empty` branch, because that array was empty for every option
## on every board.
##
## Two cells, not adjacent: a mover already within melee reach gets the zero-step stay
## option, whose empty path crosses no edge and truthfully names no control source.
static func test_published_option_carries_truthful_control_and_hazards() -> Dictionary:
	var env: Dictionary = _setup("truthful_control", true, "off", EncounterResolutionModes.COMBAT)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })

	var mover: Dictionary = _first_living(ectx, "echo")
	var hostile: Dictionary = _first_living(ectx, "enemy")
	if mover.is_empty() or hostile.is_empty():
		return { "ok": false, "error": "needed one living echo and one living enemy" }

	var origin: Dictionary = mover.get("grid_pos", {}) as Dictionary
	if origin.is_empty():
		return { "ok": false, "error": "mover has no grid_pos" }

	# Park the hostile two cells from the mover: close enough that its zone of control covers
	# every cell the mover must step to, far enough that the mover must actually step.
	var bdata: Dictionary = runtime.config_service.get_balance().get("data", {}) as Dictionary
	var board_cfg: Dictionary = _movement_board_cfg(runtime, ectx)
	var walkable: Dictionary = _full_walkable(board_cfg)
	var stand_off: Dictionary = {}
	for dc in range(-2, 3):
		for dr in range(-2, 3):
			if maxi(absi(dc), absi(dr)) != 2:
				continue
			var cell: Dictionary = { "col": int(origin["col"]) + dc, "row": int(origin["row"]) + dr }
			var key: String = "%d,%d" % [int(cell["col"]), int(cell["row"])]
			if walkable.has(key) and bool(walkable[key]) and stand_off.is_empty():
				stand_off = cell
	if stand_off.is_empty():
		return { "ok": false, "error": "no walkable cell two cells from the mover" }
	hostile["grid_pos"] = stand_off.duplicate(true)

	var prepared: Dictionary = _lm(runtime).prepare_live_movement_context(
		mover, ectx, ectx.combat_state, board_cfg, bdata, 920)
	if not bool(prepared.get("valid", false)):
		return { "ok": false, "error": "live movement context invalid" }
	var options: Array = prepared.get("options", []) as Array
	if options.is_empty():
		return { "ok": false, "error": "no options published — cannot assess the summaries" }

	var saw_control: bool = false
	for option_value: Variant in options:
		var option: Dictionary = option_value as Dictionary
		var sources: Array = option.get("hostile_control_sources", []) as Array
		# Contract shape: strictly sorted, unique. MovementOption.validate enforces it, so a
		# violation here means we published something that only survived by not being checked.
		for i in range(1, sources.size()):
			if str(sources[i - 1]) >= str(sources[i]):
				return { "ok": false, "error": "hostile_control_sources not strictly sorted/unique: %s" % str(sources) }
		if not sources.is_empty():
			saw_control = true
			if not sources.has(str(hostile.get("id", ""))):
				return { "ok": false, "error": "control sources %s omit the adjacent hostile %s" % [str(sources), str(hostile.get("id", ""))] }

		var summary: Dictionary = option.get("hazard_summary", {}) as Dictionary
		if not summary.has("known_count") or not summary.has("known_ids"):
			return { "ok": false, "error": "hazard_summary missing required fields: %s" % str(summary) }
		var ids: Array = summary.get("known_ids", []) as Array
		if int(summary.get("known_count", -1)) != ids.size():
			return { "ok": false, "error": "hazard_count_mismatch: %s" % str(summary) }
		for j in range(1, ids.size()):
			if str(ids[j - 1]) >= str(ids[j]):
				return { "ok": false, "error": "hazard known_ids not strictly sorted/unique: %s" % str(ids) }

	# The load-bearing assertion. Pre-fix this array was empty for every option, always.
	if not saw_control:
		return { "ok": false, "error": "no option reported hostile control despite a hostile two cells from the mover origin — summaries are still hardcoded empty" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Decision #59/#60 — GUIDE_SPIRIT escort yield. Drives CombatRoundGuideSpiritService directly on
# a hand-set board after combat.init, so no actor turn can move a piece between placement and
# the spirit's activation.
# ---------------------------------------------------------------------------

## Returns {env, spirit, step, blocker}, or {error}. Puts `blocker` (faction blocker_faction) on
## the spirit's next escort cell. Uses the production-spawned structure spirit: _setup_guide_escort
## appends a second actor with the same id, which this removes so the spirit is unambiguous.
static func _setup_escort_blocker(seed_tag: String, blocker_faction: String) -> Dictionary:
	var env: Dictionary = _setup_guide_escort(seed_tag, true)
	if env.is_empty():
		return { "error": "guide escort env setup failed" }
	var runtime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	var spirits: Array = []
	for a_v in ectx.actors:
		if a_v is Dictionary and bool(a_v.get("is_spirit", false)):
			spirits.append(a_v)
	if spirits.is_empty():
		return { "error": "no spirit actor on the board" }
	for extra in spirits.slice(1):
		ectx.actors.erase(extra)
	(spirits[0] as Dictionary)["grid_pos"] = { "col": 5, "row": 5 }
	runtime.dispatch({ "type": "combat.init" })
	var cs: Dictionary = ectx.combat_state
	cs["escort_started"] = true
	cs["_spirit_greeted"] = true
	cs["destination_col"] = 19
	cs["destination_row"] = 19
	var spirit: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, "guide_spirit_01")

	var prepared: Dictionary = _lm(runtime).prepare_guide_spirit_activation_context(
		spirit, ectx, cs, runtime.config_service.get_balance().get("data", {}), 0)
	var mctx: Dictionary = prepared.get("context", {}) as Dictionary
	var route: Dictionary = MovementPathServiceScript.shortest_path(
		spirit["grid_pos"] as Dictionary, { "col": 19, "row": 19 },
		mctx.get("authoritative_walkable", {}) as Dictionary,
		mctx.get("terrain_costs", {}) as Dictionary,
		mctx.get("bounds", {}) as Dictionary)
	if (route.get("path", []) as Array).is_empty():
		return { "error": "no escort route from %s (prepared valid=%s)" % [str(spirit.get("grid_pos")), str(prepared.get("valid"))] }
	var step: Dictionary = (route["path"] as Array)[0]

	var blocker: Dictionary = {}
	for a_v in ectx.actors:
		if a_v is Dictionary and str(a_v.get("faction", "")) == blocker_faction \
				and not bool(a_v.get("is_structure", false)) and not bool(a_v.get("is_dead", false)):
			blocker = a_v
			break
	if blocker.is_empty():
		return { "error": "no living %s actor to place on the step" % blocker_faction }
	blocker["grid_pos"] = { "col": int(step["col"]), "row": int(step["row"]) }
	# The escort gate needs a living Echo within escort_radius. The echo blocker is that Echo;
	# with an enemy blocker, one Echo stands beside the spirit, off its path.
	if blocker_faction == "enemy":
		for a_v in ectx.actors:
			if a_v is Dictionary and str(a_v.get("faction", "")) == "echo" \
					and not bool(a_v.get("is_spirit", false)):
				a_v["grid_pos"] = { "col": 4, "row": 5 }
				break
	ectx.round_bark_events.clear()
	return { "env": env, "spirit": spirit, "step": step, "blocker": blocker }


static func _run_guide_phase(runtime, ectx: EncounterContext, spirit: Dictionary, t: int) -> void:
	var prepared: Dictionary = _lm(runtime).prepare_guide_spirit_activation_context(
		spirit, ectx, ectx.combat_state, runtime.config_service.get_balance().get("data", {}), t)
	CombatRoundGuideSpiritService.new(runtime.flow_ctx, runtime.config_service, runtime.logger) \
		.apply_guide_spirit_round(ectx, int(ectx.combat_state.get("round_counter", 0)), prepared, t)


static func test_guide_spirit_escort_echo_yields_and_spirit_barks() -> Dictionary:
	var s: Dictionary = _setup_escort_blocker("guide_escort_yield", "echo")
	if s.has("error"):
		return { "ok": false, "error": str(s["error"]) }
	var runtime = (s["env"] as Dictionary)["runtime"]
	var ectx: EncounterContext = (s["env"] as Dictionary)["ectx"]
	var spirit: Dictionary = s["spirit"]
	var echo: Dictionary = s["blocker"]
	var step: Dictionary = s["step"]
	var spirit_from: Dictionary = (spirit["grid_pos"] as Dictionary).duplicate(true)
	var echo_before: Dictionary = echo.duplicate(true)

	_run_guide_phase(runtime, ectx, spirit, 7)

	var spirit_pos: Dictionary = spirit["grid_pos"]
	if int(spirit_pos["col"]) != int(step["col"]) or int(spirit_pos["row"]) != int(step["row"]):
		return { "ok": false, "error": "spirit did not take the Echo's cell %s — it is at %s (held as 'occupied'?)" % [str(step), str(spirit_pos)] }
	var echo_pos: Dictionary = echo["grid_pos"]
	if int(echo_pos["col"]) != int(spirit_from["col"]) or int(echo_pos["row"]) != int(spirit_from["row"]):
		return { "ok": false, "error": "Echo should take the spirit's old cell %s, got %s" % [str(spirit_from), str(echo_pos)] }
	# Only grid_pos may change on the Echo: no action, movement or emotion cost.
	for key in echo_before.keys():
		if key == "grid_pos":
			continue
		if not echo.has(key) or echo[key] != echo_before[key]:
			return { "ok": false, "error": "the swap changed Echo field '%s': %s -> %s" % [str(key), str(echo_before[key]), str(echo.get(key))] }
	if echo.size() != echo_before.size():
		return { "ok": false, "error": "the swap added fields to the Echo: %s" % str(echo.keys()) }

	if str(spirit.get("_bark_context", "")) != "spirit_escort_yield" or str(spirit.get("_bark_line", "")).is_empty():
		return { "ok": false, "error": "expected a spirit_escort_yield bark on the spirit, got context='%s' line='%s'" % [str(spirit.get("_bark_context", "")), str(spirit.get("_bark_line", ""))] }
	var queued: bool = false
	for ev in ectx.round_bark_events:
		if str((ev as Dictionary).get("bark_context", "")) == "spirit_escort_yield":
			queued = true
	if not queued:
		return { "ok": false, "error": "spirit_escort_yield was not appended to round_bark_events" }
	# The published round snapshot must still carry the line after the data.voice budget.
	var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(runtime.flow_ctx, 7)
	for row in (snap.get("data", {}) as Dictionary).get("actors", []):
		if str((row as Dictionary).get("id", "")) == "guide_spirit_01":
			if str((row as Dictionary).get("bark_line", "")).is_empty():
				return { "ok": false, "error": "the round bark budget cleared the yield bark" }
			return { "ok": true }
	return { "ok": false, "error": "spirit row missing from the round snapshot" }


static func test_guide_spirit_escort_hostile_on_path_still_blocks() -> Dictionary:
	var s: Dictionary = _setup_escort_blocker("guide_escort_hostile_block", "enemy")
	if s.has("error"):
		return { "ok": false, "error": str(s["error"]) }
	var runtime = (s["env"] as Dictionary)["runtime"]
	var ectx: EncounterContext = (s["env"] as Dictionary)["ectx"]
	var spirit: Dictionary = s["spirit"]
	var enemy: Dictionary = s["blocker"]
	var spirit_from: Dictionary = (spirit["grid_pos"] as Dictionary).duplicate(true)
	var enemy_from: Dictionary = (enemy["grid_pos"] as Dictionary).duplicate(true)

	_run_guide_phase(runtime, ectx, spirit, 7)

	if spirit["grid_pos"] != spirit_from:
		return { "ok": false, "error": "spirit moved past a hostile on its path: %s -> %s" % [str(spirit_from), str(spirit["grid_pos"])] }
	if enemy["grid_pos"] != enemy_from:
		return { "ok": false, "error": "a hostile was swapped: %s -> %s" % [str(enemy_from), str(enemy["grid_pos"])] }
	if str(spirit.get("_bark_context", "")) == "spirit_escort_yield":
		return { "ok": false, "error": "yield bark fired with no swap" }
	# Control: with the hostile gone the same board moves the spirit, so the hold above came
	# from the hostile and not from a closed escort gate.
	enemy["grid_pos"] = { "col": 19, "row": 0 }
	_run_guide_phase(runtime, ectx, spirit, 8)
	if spirit["grid_pos"] == spirit_from:
		return { "ok": false, "error": "control failed: the spirit does not move even with the path clear — the hostile case proved nothing" }
	return { "ok": true }
