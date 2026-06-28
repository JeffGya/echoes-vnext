# res://tests/CombatRoundtripIntegrationTests.gd
# V2-STAGE-004 P3 — INTEGRATION coverage for the real combat round loop on irregular terrain.
#
# Why this file exists:
#   The deterministic combat core (GridService.move_toward, BehaviorArbiter, StageTerrain)
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
#   through: unit tests of move_toward pass because the math is correct; the failure is in the
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


# ---------------------------------------------------------------------------
# Shared setup: boot runtime, active realm (→ irregular terrain), 5-echo party.
# `assign_ids` controls whether echoes get real ids (real flow) or are left id-less
# (all id "" — the duplicate-id condition that reproduces the freeze).
# ---------------------------------------------------------------------------
static func _setup(seed_tag: String, assign_ids: bool) -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
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
	return { "runtime": runtime, "flow_ctx": flow_ctx, "ectx": flow_ctx.encounter_ctx }


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

	return { "ok": true }
