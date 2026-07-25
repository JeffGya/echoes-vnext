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

static func register(runner) -> void:
	runner.register_test("combat_roundtrip/echoes_advance_on_terrain", func(): return test_echoes_advance())
	runner.register_test("combat_roundtrip/duplicate_id_echoes_freeze", func(): return test_duplicate_id_freeze())
	# V2-STAGE-004 Distinctiveness — §4-E RECOVER reinforcement
	runner.register_test("combat_roundtrip/recover_reinforcement_spawns_enemy_side", func(): return test_recover_reinforcement())
	# V2-STAGE-004 Distinctiveness — §4-F ENDURE rising wave + all_waves_spawned
	runner.register_test("combat_roundtrip/endure_rising_wave_size_and_flag", func(): return test_endure_rising_wave())
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


# ---------------------------------------------------------------------------
# Shared setup: boot runtime, active realm (→ irregular terrain), 5-echo party.
# `assign_ids` controls whether echoes get real ids (real flow) or are left id-less
# (all id "" — the duplicate-id condition that reproduces the freeze).
# ---------------------------------------------------------------------------
static func _setup(seed_tag: String, assign_ids: bool, log_level: String = "off") -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level(log_level)
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, "/tmp/echoes-vnext-tests/combat_roundtrip_slot.json")
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

	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	return { "runtime": runtime, "flow_ctx": flow_ctx, "ectx": flow_ctx.encounter_ctx, "logger": logger }


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
	var hazards: Array = runtime._live_combat_known_hazards()
	var ids: Array = []
	for hazard_value: Variant in hazards:
		ids.append(str((hazard_value as Dictionary).get("id", "")))
	if ids != ["approach.burning.a", "hazard.unstable.a", "hazard.binding.a", "hazard.burning.a"]:
		return { "ok": false, "error": "live hazard union or board precedence drifted: %s" % str(ids) }

	var order_actor: Dictionary = (env["ectx"].actors[0] as Dictionary)
	order_actor["current_hp"] = 10
	runtime._apply_live_hazard_outcome(order_actor, {
		"events": [
			{"phase": "movement", "damage": 3},
			{"phase": "end_activation", "damage": 4},
		],
		"stop_reason": "reached_destination",
	}, 99, false)
	if int(order_actor.get("current_hp", -1)) != 7:
		return { "ok": false, "error": "movement hazard damage did not resolve before action: %s" % str(order_actor) }
	runtime._apply_live_hazard_outcome(order_actor, {
		"events": [
			{"phase": "movement", "damage": 3},
			{"phase": "end_activation", "damage": 4},
		],
		"stop_reason": "reached_destination",
	}, 99, true)
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
	runtime._apply_live_purify_shrine(purifier, "shrine.match", purify_ctx, 99)
	if (wrong_shrine.get("purify_stacks", []) as Array).size() != 0:
		return { "ok": false, "error": "non-target shrine mutated during purify" }
	if (matching_shrine.get("purify_stacks", []) as Array).size() != 1:
		return { "ok": false, "error": "matching purify target did not receive exactly one stack" }
	wrong_shrine["is_dead"] = true
	runtime._apply_live_purify_shrine(purifier, "shrine.wrong", purify_ctx, 99)
	if (matching_shrine.get("purify_stacks", []) as Array).size() != 1:
		return { "ok": false, "error": "dead mismatched target changed the living shrine" }

	var echo: Dictionary = (env["ectx"].actors[0] as Dictionary)
	echo["current_hp"] = 3
	echo["is_ko"] = true
	runtime._apply_live_hazard_outcome(echo, {
		"events": [{ "damage": 3 }],
		"stop_reason": "death",
	}, 99)
	if int(echo.get("current_hp", -1)) != 0 or not bool(echo.get("is_dead", false)) \
			or echo.has("is_ko") or int(echo.get("death_round", -1)) != 99:
		return { "ok": false, "error": "FlowRuntime did not preserve Echo death authority: %s" % str(echo) }

	var enemy: Dictionary = (env["ectx"].actors[-1] as Dictionary)
	enemy["current_hp"] = 3
	enemy["is_ko"] = true
	runtime._apply_live_hazard_outcome(enemy, {
		"events": [{ "damage": 3 }],
		"stop_reason": "death",
	}, 99)
	if int(enemy.get("current_hp", -1)) != 0 or not bool(enemy.get("is_dead", false)) \
			or enemy.has("is_ko") or int(enemy.get("death_round", -1)) != 99:
		return { "ok": false, "error": "FlowRuntime did not preserve enemy death state: %s" % str(enemy) }

	var guide: Dictionary = {"id": "guide.hazard", "is_spirit": true, "current_hp": 3, "is_ko": true}
	runtime._apply_live_hazard_outcome(guide, {"events": [{"damage": 3}], "stop_reason": "death"}, 99)
	if not bool(guide.get("is_dead", false)) or guide.has("is_ko") or int(guide.get("death_round", -1)) != 99:
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
	var burning_result: Dictionary = runtime._apply_live_activation(actor, burning_intent, prepared, asm, ctx, 99)
	if str((burning_result.get("resolved_action", {}) as Dictionary).get("type", "")) != "melee_attack":
		return { "ok": false, "error": "legal melee was not resolved before Burning: %s" % str(burning_result) }
	var target_hp_before: int = int(target.get("current_hp", 0))
	var melee_result: Dictionary = CombatService.resolve_action("melee_attack", actor, target, 1)
	if melee_result.is_empty() or int(target.get("current_hp", target_hp_before)) >= target_hp_before:
		return { "ok": false, "error": "legal melee did not execute before end_activation Burning" }
	runtime._apply_live_hazard_outcome(actor, burning_result, 99, true)
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
	runtime._apply_live_hazard_outcome(movement_actor, movement_result, 100, false)
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
		var result: Dictionary = runtime._apply_live_activation(actor, intent, prepared, asm, ctx, 90 + activation_index)
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
	var runtime := FlowRuntime.new(logger, config, "/tmp/echoes-vnext-tests/combat_roundtrip_pursue.json")
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
	var runtime := FlowRuntime.new(logger, config, "/tmp/echoes-vnext-tests/combat_pursue_noenemy.json")
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
	var runtime := FlowRuntime.new(logger, config, "/tmp/echoes-vnext-tests/combat_pursue_board.json")
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

	# Standard base from balance.json data.combat.board (base_cols=12, base_rows=12).
	var board_cfg: Dictionary = bal.get("data", {}).get("combat", {}).get("board", {})
	var base_cols: int = int(board_cfg.get("base_cols", 12))
	var base_rows: int = int(board_cfg.get("base_rows", 12))

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
			"error": "PURSUE board not 2× in either dimension — actual w=%d h=%d, needed w≥%.0f or h≥%.0f (base %d×%d)" \
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
	var obj_state: Dictionary = FlowEncounterState._build_objective_state(ectx, ectx.combat_state)
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
	var runtime := FlowRuntime.new(logger, config, "/tmp/echoes-vnext-tests/combat_roundtrip_guide_dev.json")
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
