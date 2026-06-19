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
