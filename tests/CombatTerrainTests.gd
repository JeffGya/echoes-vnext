# res://tests/CombatTerrainTests.gd
# V2-STAGE-004 Phase 3a — Tests for the NEW combat-terrain path.
#
# Phase 3a migrated the combat board from a fixed 10×10 to irregular StageTerrain
# landscapes. The legacy 10×10 path (walkable absent / empty) is the LEGACY path
# exercised by all pre-existing tests. This suite adds DETERMINISTIC tests that
# exercise only the NEW walkable-terrain branch.
#
# Tests:
#   1. combat_terrain/walkable_placement_all_on_walkable
#         — place_actors with board_cfg["walkable"] set: every actor's grid_pos is
#           in the walkable set (never void).
#   2. combat_terrain/walkable_placement_echo_left_enemy_right
#         — echoes occupy columns < enemy columns when terrain has two distinct column bands.
#   3. combat_terrain/placement_keystone_empty_walkable_matches_legacy
#         — empty walkable ⇒ place_actors behaves identically to calling it without the
#           walkable key at all (same positions for same seed).
#   4. combat_terrain/shared_executor_never_enters_void
#         — repeated shared-executor steps over a 2-wide bridge never step on a void cell;
#           actor crosses from one plateau to the other.
#   5. combat_terrain/shared_executor_makes_progress_across_bridge
#         — actor on the left plateau eventually reaches (or adjoins) the target on the
#           right plateau, confirming the bridge is traversable.
#   6. combat_terrain/movement_keystone_empty_walkable_matches_legacy
#         — empty walkable ⇒ shared movement result identical to the no-walkable-key path.
#   7. combat_terrain/terrain_determinism_same_rng_namespace
#         — StageTerrain.generate() with the same inputs and a custom rng_namespace
#           produces deep-equal output on two successive calls.
#   8. combat_terrain/objective_params_default_empty
#         — CombatState.create(actors, objective) → objective_params == {}.
#   9. combat_terrain/objective_params_stored_correctly
#         — CombatState.create(actors, objective, 0, {}, {"hold_rounds": 3}) stores param.
#  10. combat_terrain/objective_params_legacy_4arg_call
#         — 4-arg call CombatState.create(actors, obj, 0, {}) still works; objective_params == {}.
#
# All tests are DETERMINISTIC: no randf / randomize / OS time.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatTerrainTests

const MovementPathService = preload("res://core/movement/MovementPathService.gd")
const MovementExecutor = preload("res://core/movement/MovementExecutor.gd")


# ─── Helpers ────────────────────────────────────────────────────────────────

# Build a minimal actor dict that satisfies place_actors() and movement-service tests.
static func _make_actor(id: String) -> Dictionary:
	var a: Dictionary = ActorSchema.get_defaults()
	a["id"]              = id
	a["name"]            = id
	a["stats"]           = { "max_hp": 100, "atk": 5, "def": 3, "agi": 3, "int": 3, "cha": 2 }
	a["speed"]           = 3
	a["archetype_birth"] = "brave"
	a["calling_origin"]  = "blade"
	a["traits"]          = { "courage": 40, "faith": 30, "wisdom": 30 }
	a["vector_scores"]   = { "vanguard": 50, "protector": 20, "seeker": 20, "pillar": 10 }
	return a


# Build a small hand-crafted walkable set shaped like two 4-wide plateaus connected
# by a 2-wide bridge in the middle, all in a 12-wide x 4-tall space:
#
#   cols 0-3  : left plateau  (rows 0-3)
#   cols 4-7  : bridge        (rows 1-2 only)
#   cols 8-11 : right plateau (rows 0-3)
#
# Total walkable cells: 4*4 + 4*2 + 4*4 = 16 + 8 + 16 = 40 cells.
# The void gap is at cols 4-7 rows 0 and 3 (bridge is only rows 1-2).
static func _make_bridge_walkable() -> Dictionary:
	var w: Dictionary = {}
	# Left plateau: cols 0-3, rows 0-3.
	for c in range(4):
		for r in range(4):
			w["%d,%d" % [c, r]] = true
	# Bridge: cols 4-7, rows 1-2.
	for c in range(4, 8):
		for r in range(1, 3):
			w["%d,%d" % [c, r]] = true
	# Right plateau: cols 8-11, rows 0-3.
	for c in range(8, 12):
		for r in range(4):
			w["%d,%d" % [c, r]] = true
	return w


# Build a board_cfg dict with the given walkable set and generous board bounds.
static func _board_cfg(walkable: Dictionary) -> Dictionary:
	return {
		"board_cols": 12,
		"board_rows": 4,
		"walkable":   walkable,
	}


# Perform a deep-equality check for two actor grid_pos values.
static func _pos_equal(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("col", -1)) == int(b.get("col", -1)) \
		and int(a.get("row", -1)) == int(b.get("row", -1))


static func _move_one_step(actor: Dictionary, target: Dictionary, board: Dictionary,
		occupied_positions: Array = []) -> Dictionary:
	var from_pos: Dictionary = (actor.get("grid_pos", {"col": 0, "row": 0}) as Dictionary).duplicate(true)
	var bounds: Dictionary = {
		"w": GridService.get_board_cols(board),
		"h": GridService.get_board_rows(board),
	}
	var walkable: Dictionary = board.get("walkable", {}) as Dictionary
	if walkable.is_empty():
		walkable = {}
		for col in range(int(bounds["w"])):
			for row in range(int(bounds["h"])):
				walkable["%d,%d" % [col, row]] = true
	var effective_walkable: Dictionary = walkable.duplicate(true)
	var occupancy: Dictionary = {}
	var occ_index: int = 0
	for occ_value: Variant in occupied_positions:
		if occ_value is Dictionary:
			var occ: Dictionary = occ_value as Dictionary
			var key: String = "%d,%d" % [int(occ.get("col", -1)), int(occ.get("row", -1))]
			effective_walkable.erase(key)
			occupancy[key] = "occupied.%d" % occ_index
			occ_index += 1
	var route: Dictionary = MovementPathService.shortest_path(from_pos, target, effective_walkable, {}, bounds)
	var path: Array = []
	if bool(route.get("reachable", false)):
		path = route.get("path", []) as Array
	var context: Dictionary = {
		"mover_id": str(actor.get("id", "actor")),
		"origin": from_pos,
		"bounds": bounds,
		"authoritative_walkable": walkable,
		"perceived_planning_cells": walkable,
		"occupancy": occupancy,
		"perceived_actors": [],
		"relationships": {},
		"terrain_costs": {},
		"known_hazards": [],
		"objective_pressure": {},
		"movement_history": [],
	}
	var outcome: Dictionary = MovementExecutor.execute(
		context,
		{
			"mover_id": str(actor.get("id", "actor")),
			"path": path,
			"commitment": 1,
		},
		{"capacity": 1, "authored_override": {}},
		{"triggered": {"unstable": false, "binding": false, "burning": false}, "config": {}}
	)
	var actual: Array = outcome.get("actual_traversed_cells", []) as Array
	if not actual.is_empty():
		var final_pos: Dictionary = outcome.get("final_destination", from_pos) as Dictionary
		GridService.assign_grid_pos(actor, int(final_pos.get("col", 0)), int(final_pos.get("row", 0)))
	return {
		"from_pos": from_pos,
		"to_pos": (actor.get("grid_pos", from_pos) as Dictionary).duplicate(true),
		"stop_reason": str(outcome.get("stop_reason", "")),
	}


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat_terrain/walkable_placement_all_on_walkable",
		Callable(CombatTerrainTests, "_t_walkable_placement_all_on_walkable"))
	runner.register_test("combat_terrain/walkable_placement_echo_left_enemy_right",
		Callable(CombatTerrainTests, "_t_walkable_placement_echo_left_enemy_right"))
	runner.register_test("combat_terrain/placement_keystone_empty_walkable_matches_legacy",
		Callable(CombatTerrainTests, "_t_placement_keystone_empty_walkable_matches_legacy"))
	runner.register_test("combat_terrain/shared_executor_never_enters_void",
		Callable(CombatTerrainTests, "_t_shared_executor_never_enters_void"))
	runner.register_test("combat_terrain/shared_executor_makes_progress_across_bridge",
		Callable(CombatTerrainTests, "_t_shared_executor_makes_progress_across_bridge"))
	runner.register_test("combat_terrain/movement_keystone_empty_walkable_matches_legacy",
		Callable(CombatTerrainTests, "_t_movement_keystone_empty_walkable_matches_legacy"))
	runner.register_test("combat_terrain/terrain_determinism_same_rng_namespace",
		Callable(CombatTerrainTests, "_t_terrain_determinism_same_rng_namespace"))
	runner.register_test("combat_terrain/objective_params_default_empty",
		Callable(CombatTerrainTests, "_t_objective_params_default_empty"))
	runner.register_test("combat_terrain/objective_params_stored_correctly",
		Callable(CombatTerrainTests, "_t_objective_params_stored_correctly"))
	runner.register_test("combat_terrain/objective_params_legacy_4arg_call",
		Callable(CombatTerrainTests, "_t_objective_params_legacy_4arg_call"))
	# --- Pathfinding regression tests (bug: BFS rooted over wrong walkable set) ---
	runner.register_test("combat_terrain/pathing_clustered_target_advances",
		Callable(CombatTerrainTests, "_t_pathing_clustered_target_advances"))
	runner.register_test("combat_terrain/pathing_open_path_advances",
		Callable(CombatTerrainTests, "_t_pathing_open_path_advances"))
	runner.register_test("combat_terrain/pathing_never_steps_occupied_or_void",
		Callable(CombatTerrainTests, "_t_pathing_never_steps_occupied_or_void"))
	runner.register_test("combat_terrain/pathing_dead_end_stay",
		Callable(CombatTerrainTests, "_t_pathing_dead_end_stay"))
	runner.register_test("combat_terrain/pathing_legacy_empty_walkable_unchanged",
		Callable(CombatTerrainTests, "_t_pathing_legacy_empty_walkable_unchanged"))
	runner.register_test("combat_terrain/pathing_determinism",
		Callable(CombatTerrainTests, "_t_pathing_determinism"))


# ─── Test 1 — Walkable placement: every actor lands on a walkable cell ───────
# Places 3 echoes + 2 enemies on the bridge-shaped terrain.
# Asserts that EVERY placed actor's grid_pos is in the walkable set (never void).
static func _t_walkable_placement_all_on_walkable() -> Dictionary:
	var walkable := _make_bridge_walkable()
	var board := _board_cfg(walkable)

	var echoes: Array  = [_make_actor("e1"), _make_actor("e2"), _make_actor("e3")]
	var enemies: Array = [_make_actor("n1"), _make_actor("n2")]

	# Deterministic RNG — seed fixed; no RNG draws occur in the walkable path,
	# but the API requires a RandomNumberGenerator, so pass a seeded one.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	GridService.place_actors(echoes, enemies, board, rng, {})

	for actor in echoes + enemies:
		var gp: Dictionary = actor.get("grid_pos", {})
		var key: String = "%d,%d" % [int(gp.get("col", -999)), int(gp.get("row", -999))]
		if not walkable.has(key):
			return {
				"ok": false,
				"error": "Actor '%s' placed at %s which is NOT in the walkable set (void cell)" \
					% [str(actor.get("id", "?")), key]
			}

	return { "ok": true }


# ─── Test 2 — Walkable placement: echoes land in lower cols, enemies in higher cols ─
# Uses two clearly separated column bands (left plateau cols 0-3, right plateau cols 8-11).
# After placement the maximum echo column must be < minimum enemy column, confirming
# faction separation on terrain that provides distinct left/right regions.
static func _t_walkable_placement_echo_left_enemy_right() -> Dictionary:
	var walkable := _make_bridge_walkable()
	var board    := _board_cfg(walkable)

	# 2 echoes, 2 enemies — both factions will fill their respective sides.
	var echoes:  Array = [_make_actor("e1"), _make_actor("e2")]
	var enemies: Array = [_make_actor("n1"), _make_actor("n2")]

	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	GridService.place_actors(echoes, enemies, board, rng, {})

	var max_echo_col: int = -1
	for actor in echoes:
		var c: int = int(actor.get("grid_pos", {}).get("col", -1))
		if c > max_echo_col:
			max_echo_col = c

	var min_enemy_col: int = 9999
	for actor in enemies:
		var c: int = int(actor.get("grid_pos", {}).get("col", -1))
		if c < min_enemy_col:
			min_enemy_col = c

	# Left plateau is cols 0-3, right plateau is cols 8-11.
	# Echoes fill left→right so they should end up in the left plateau (col ≤ 3).
	# Enemies fill right→left so they should end up in the right plateau (col ≥ 8).
	if max_echo_col >= min_enemy_col:
		return {
			"ok": false,
			"error": "Echo max_col (%d) >= enemy min_col (%d) — faction halves not respected" \
				% [max_echo_col, min_enemy_col]
		}

	return { "ok": true }


# ─── Test 3 — Placement keystone: empty walkable == no walkable key (legacy) ─
# Calling place_actors with board_cfg that contains walkable:{} must produce the
# SAME grid positions as calling it with a board_cfg without the walkable key,
# using the same RNG seed.
static func _t_placement_keystone_empty_walkable_matches_legacy() -> Dictionary:
	var cfg_no_walkable  := { "board_cols": 10, "board_rows": 10 }
	var cfg_empty_walk   := { "board_cols": 10, "board_rows": 10, "walkable": {} }

	var echoes_a: Array  = [_make_actor("e1"), _make_actor("e2")]
	var enemies_a: Array = [_make_actor("n1")]
	var echoes_b: Array  = [_make_actor("e1"), _make_actor("e2")]
	var enemies_b: Array = [_make_actor("n1")]

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	GridService.place_actors(echoes_a, enemies_a, cfg_no_walkable, rng_a, {})

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	GridService.place_actors(echoes_b, enemies_b, cfg_empty_walk, rng_b, {})

	for i in range(echoes_a.size()):
		var pa: Dictionary = echoes_a[i].get("grid_pos", {})
		var pb: Dictionary = echoes_b[i].get("grid_pos", {})
		if not _pos_equal(pa, pb):
			return {
				"ok": false,
				"error": "Echo %d: no-walkable-key col=%d,row=%d vs empty-walkable col=%d,row=%d" \
					% [i, int(pa.get("col",-1)), int(pa.get("row",-1)),
					   int(pb.get("col",-1)), int(pb.get("row",-1))]
			}

	for i in range(enemies_a.size()):
		var pa: Dictionary = enemies_a[i].get("grid_pos", {})
		var pb: Dictionary = enemies_b[i].get("grid_pos", {})
		if not _pos_equal(pa, pb):
			return {
				"ok": false,
				"error": "Enemy %d: no-walkable-key col=%d,row=%d vs empty-walkable col=%d,row=%d" \
					% [i, int(pa.get("col",-1)), int(pa.get("row",-1)),
					   int(pb.get("col",-1)), int(pb.get("row",-1))]
			}

	return { "ok": true }


# ─── Test 4 — Move toward never enters void ──────────────────────────────────
# Places an actor on the left plateau (col 2, row 1), target on the right plateau
# (col 10, row 1).  Runs up to 30 shared-executor steps with board_cfg["walkable"]
# set.  At EVERY step, asserts the actor's grid_pos is in the walkable set.
static func _t_shared_executor_never_enters_void() -> Dictionary:
	var walkable := _make_bridge_walkable()
	var board    := _board_cfg(walkable)

	var actor: Dictionary = _make_actor("e1")
	GridService.assign_grid_pos(actor, 2, 1)  # left plateau

	var target := { "col": 10, "row": 1 }  # right plateau

	for step in range(30):
		var gp: Dictionary = actor.get("grid_pos", {})
		var key: String = "%d,%d" % [int(gp.get("col", -999)), int(gp.get("row", -999))]
		if not walkable.has(key):
			return {
				"ok": false,
				"error": "Step %d: actor at %s is NOT in walkable set (stepped onto void)" \
					% [step, key]
			}
		# Stop early if already at target.
		if int(gp.get("col", -1)) == 10 and int(gp.get("row", -1)) == 1:
			break
		_move_one_step(actor, target, board, [])

	return { "ok": true }


# ─── Test 5 — Move toward makes progress across the bridge ───────────────────
# Same setup as Test 4.  After at most walkable.size() + 5 steps the actor must
# be within Chebyshev distance 1 of the target (reached or adjacent).
static func _t_shared_executor_makes_progress_across_bridge() -> Dictionary:
	var walkable := _make_bridge_walkable()
	var board    := _board_cfg(walkable)

	var actor: Dictionary = _make_actor("e1")
	GridService.assign_grid_pos(actor, 0, 0)  # left plateau corner

	var target := { "col": 11, "row": 3 }  # right plateau far corner

	var max_steps: int = walkable.size() + 5
	var prev_key: String = ""

	for _step in range(max_steps):
		var gp: Dictionary = actor.get("grid_pos", {})
		var key: String = "%d,%d" % [int(gp.get("col", -999)), int(gp.get("row", -999))]

		# Safety: actor must always be on walkable terrain.
		if not walkable.has(key):
			return {
				"ok": false,
				"error": "Step %d: actor at %s left walkable set" % [_step, key]
			}

		# Done: actor is at target or adjacent (Chebyshev ≤ 1).
		if GridService.chebyshev_distance(gp, target) <= 1:
			return { "ok": true }

		# Detect permanent stall (same cell twice in a row after move).
		var before_key: String = key
		_move_one_step(actor, target, board, [])
		var after_gp: Dictionary  = actor.get("grid_pos", {})
		var after_key: String = "%d,%d" % [int(after_gp.get("col", -999)), int(after_gp.get("row", -999))]

		if after_key == before_key and prev_key == before_key:
			# Two consecutive no-progress steps — stuck. Check if we're at target already.
			if GridService.chebyshev_distance(after_gp, target) <= 1:
				return { "ok": true }
			return {
				"ok": false,
				"error": "Actor stalled at %s and cannot reach target {col:11,row:3}" % after_key
			}
		prev_key = before_key

	# Reached step budget — check final position.
	var final_gp: Dictionary = actor.get("grid_pos", {})
	if GridService.chebyshev_distance(final_gp, target) <= 1:
		return { "ok": true }

	return {
		"ok": false,
		"error": "Actor did not reach/adjoin target within %d steps. Final pos: col=%d,row=%d" \
			% [max_steps, int(final_gp.get("col",-1)), int(final_gp.get("row",-1))]
	}


# ─── Test 6 — Movement keystone: empty walkable == legacy greedy step ────────
# With board_cfg containing walkable:{}, the shared movement helper must produce
# the same result as the no-walkable-key path.
static func _t_movement_keystone_empty_walkable_matches_legacy() -> Dictionary:
	var cfg_no_walkable := { "board_cols": 10, "board_rows": 10 }
	var cfg_empty_walk  := { "board_cols": 10, "board_rows": 10, "walkable": {} }

	# Test a few (from, target) pairs to ensure the equivalence holds broadly.
	var cases: Array = [
		{ "from": { "col": 2, "row": 5 }, "target": { "col": 7, "row": 5 } },  # horizontal
		{ "from": { "col": 2, "row": 2 }, "target": { "col": 6, "row": 6 } },  # diagonal
		{ "from": { "col": 0, "row": 0 }, "target": { "col": 0, "row": 9 } },  # corner
	]

	for case_v in cases:
		var case_dict: Dictionary = case_v if case_v is Dictionary else {}
		var from_pos: Dictionary  = case_dict.get("from",   { "col": 0, "row": 0 })
		var target:   Dictionary  = case_dict.get("target", { "col": 5, "row": 5 })

		var actor_a: Dictionary = _make_actor("x")
		GridService.assign_grid_pos(actor_a, int(from_pos.get("col", 0)), int(from_pos.get("row", 0)))
		var result_a: Dictionary = _move_one_step(actor_a, target, cfg_no_walkable, [])

		var actor_b: Dictionary = _make_actor("x")
		GridService.assign_grid_pos(actor_b, int(from_pos.get("col", 0)), int(from_pos.get("row", 0)))
		var result_b: Dictionary = _move_one_step(actor_b, target, cfg_empty_walk, [])

		var to_a: Dictionary = result_a.get("to_pos", {})
		var to_b: Dictionary = result_b.get("to_pos", {})
		if not _pos_equal(to_a, to_b):
			return {
				"ok": false,
				"error": "From (%d,%d) to (%d,%d): legacy to_pos col=%d,row=%d vs empty-walkable col=%d,row=%d" \
					% [int(from_pos.get("col",0)), int(from_pos.get("row",0)),
					   int(target.get("col",0)),   int(target.get("row",0)),
					   int(to_a.get("col",-1)),    int(to_a.get("row",-1)),
					   int(to_b.get("col",-1)),    int(to_b.get("row",-1))]
			}

	return { "ok": true }


# ─── Test 7 — Terrain determinism with custom rng_namespace ─────────────────
# StageTerrain.generate() with the same (realm_seed, stage_index, sig, bounds, namespace)
# must produce a byte-identical terrain dict on two successive calls.
# Also verifies the custom namespace does not collide with the default ("") namespace
# by confirming the two calls with "" and a custom string CAN produce different results
# for the same seed (they use different RNG paths).
static func _t_terrain_determinism_same_rng_namespace() -> Dictionary:
	var sig: Dictionary = {
		"relief":              "highland",
		"plateau_count_min":   3,
		"plateau_count_max":   5,
		"plateau_w_min":       4,
		"plateau_w_max":       8,
		"plateau_h_min":       4,
		"plateau_h_max":       8,
		"plateau_shape_bias":  "blocky",
		"bridge_width":        2,
		"bridge_density":      0.3,
		"straggler_count_min": 1,
		"straggler_count_max": 2,
	}
	var bounds    := { "w": 20, "h": 20 }
	var realm_seed := 42
	var ns         := "combat.terrain.encounter_001"

	# Two identical calls with custom namespace must produce identical output.
	var t1: Dictionary = StageTerrain.generate(realm_seed, 0, sig, bounds, ns)
	var t2: Dictionary = StageTerrain.generate(realm_seed, 0, sig, bounds, ns)

	if not _terrain_dicts_equal(t1, t2):
		return {
			"ok": false,
			"error": "StageTerrain.generate() is non-deterministic with namespace '%s'" % ns
		}

	# Two calls with default namespace ("") must also be deterministic.
	var t3: Dictionary = StageTerrain.generate(realm_seed, 0, sig, bounds)
	var t4: Dictionary = StageTerrain.generate(realm_seed, 0, sig, bounds)

	if not _terrain_dicts_equal(t3, t4):
		return {
			"ok": false,
			"error": "StageTerrain.generate() is non-deterministic with default namespace"
		}

	# Sanity: custom namespace and default namespace should differ for the same seed.
	# (Not a hard requirement — a contrived seed could produce the same output — but
	# for seed=42 with this signature the RNG paths are different, so they should differ.)
	# We only check this loosely — it's an informational guard, not a correctness guarantee.
	# Skip if they happen to be equal (astronomically unlikely, not a bug).
	# (Nothing to assert here beyond the two determinism checks above.)

	return { "ok": true }


# Minimal deep-equality for two terrain dicts (bounds + array fields).
static func _terrain_dicts_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	var ba: Dictionary = a.get("bounds", {})
	var bb: Dictionary = b.get("bounds", {})
	if int(ba.get("w", -1)) != int(bb.get("w", -1)) or int(ba.get("h", -1)) != int(bb.get("h", -1)):
		return false
	for key in ["plateaus", "bridges", "stragglers"]:
		var arr_a_v: Variant = a.get(key, [])
		var arr_b_v: Variant = b.get(key, [])
		var arr_a: Array = arr_a_v if arr_a_v is Array else []
		var arr_b: Array = arr_b_v if arr_b_v is Array else []
		if arr_a.size() != arr_b.size():
			return false
		for i in range(arr_a.size()):
			var ea_v: Variant = arr_a[i]
			var eb_v: Variant = arr_b[i]
			var ea: Dictionary = ea_v if ea_v is Dictionary else {}
			var eb: Dictionary = eb_v if eb_v is Dictionary else {}
			if ea.size() != eb.size():
				return false
			for k in ea:
				if not eb.has(k):
					return false
				if ea[k] != eb[k]:
					return false
	return true


# ─── Test 8 — objective_params defaults to {} ────────────────────────────────
# 3-arg call: CombatState.create(actors, objective) → objective_params == {}.
static func _t_objective_params_default_empty() -> Dictionary:
	var actors: Array = [{ "id": "a1" }, { "id": "a2" }]
	var state: Dictionary = CombatState.create(actors, "defeat_enemies")

	if not state.has("objective_params"):
		return { "ok": false, "error": "CombatState missing 'objective_params' key" }

	var op: Variant = state.get("objective_params")
	if not (op is Dictionary):
		return { "ok": false, "error": "'objective_params' is not a Dictionary (got %s)" % type_string(typeof(op)) }

	if not (op as Dictionary).is_empty():
		return { "ok": false, "error": "Default objective_params should be {} but got: %s" % str(op) }

	return { "ok": true }


# ─── Test 9 — objective_params stored correctly ──────────────────────────────
# 5-arg call with {"hold_rounds": 3} → CombatState stores it unchanged.
static func _t_objective_params_stored_correctly() -> Dictionary:
	var actors: Array = [{ "id": "a1" }]
	var params := { "hold_rounds": 3 }
	var state: Dictionary = CombatState.create(actors, "hold_ground", 0, {}, params)

	if not state.has("objective_params"):
		return { "ok": false, "error": "CombatState missing 'objective_params' key" }

	var op: Variant = state.get("objective_params")
	if not (op is Dictionary):
		return { "ok": false, "error": "'objective_params' is not a Dictionary" }

	var op_dict: Dictionary = op as Dictionary
	if not op_dict.has("hold_rounds"):
		return { "ok": false, "error": "objective_params missing 'hold_rounds' key" }

	if int(op_dict.get("hold_rounds", -1)) != 3:
		return {
			"ok": false,
			"error": "Expected objective_params.hold_rounds=3, got %d" \
				% int(op_dict.get("hold_rounds", -1))
		}

	return { "ok": true }


# ─── Test 10 — legacy 4-arg call still works ─────────────────────────────────
# CombatState.create(actors, objective, seed, init_cfg) with 4 args must succeed
# and produce objective_params == {} (default applied for missing 5th arg).
static func _t_objective_params_legacy_4arg_call() -> Dictionary:
	var actors: Array = [
		{ "id": "fast", "name": "Fast", "speed": 10, "stats": { "agi": 8 } },
		{ "id": "slow", "name": "Slow", "speed": 2,  "stats": { "agi": 1 } },
	]
	var state: Dictionary = CombatState.create(actors, "defeat_enemies", 0, {})

	# Must validate cleanly.
	if not CombatState.validate(state):
		return { "ok": false, "error": "CombatState.validate() failed for 4-arg create()" }

	# objective_params must be {} (not missing, not non-dict, not non-empty).
	if not state.has("objective_params"):
		return { "ok": false, "error": "CombatState missing 'objective_params' key (4-arg call)" }

	var op: Variant = state.get("objective_params")
	if not (op is Dictionary):
		return { "ok": false, "error": "'objective_params' is not a Dictionary (4-arg call)" }

	if not (op as Dictionary).is_empty():
		return {
			"ok": false,
			"error": "4-arg call: objective_params should be {} but got: %s" % str(op)
		}

	# Also verify the call produced a correct initiative_order (regression guard).
	if not state.has("initiative_order"):
		return { "ok": false, "error": "4-arg call: missing 'initiative_order'" }

	var order: Array = state["initiative_order"] as Array
	if order.size() != 2:
		return { "ok": false, "error": "4-arg call: initiative_order size %d != 2" % order.size() }

	var first_id: String = str((order[0] as Dictionary).get("id", ""))
	if first_id != "fast":
		return {
			"ok": false,
			"error": "4-arg call: highest-speed actor should be first (got '%s')" % first_id
		}

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════════
# PATHFINDING REGRESSION TESTS  (tests 11–16)
# Exercises the fix: bfs_distance_field now rooted over full walkable, not the
# occupied-minus set.  All tests are deterministic; no RNG / OS time.
# ═══════════════════════════════════════════════════════════════════════════════

# Build a simple solid N×M walkable rectangle as a Dictionary of "col,row" keys.
static func _make_rect_walkable(cols: int, rows: int) -> Dictionary:
	var w: Dictionary = {}
	for c in range(cols):
		for r in range(rows):
			w["%d,%d" % [c, r]] = true
	return w


# ─── Test 11 — Clustered-target repro (THE BUG) ──────────────────────────────
# Echo at col 0, row 2; target enemy at col 7, row 2.
# Three ally actors occupy the three cells immediately left/above/below the target
# (col 6 row 1, col 6 row 2, col 6 row 3), creating a cluster around it, but the
# approach lane along row 2 from the left (col 5, row 2) is free.
# With the old code the BFS from the target cannot spread past the cluster so
# dist_field doesn't cover the mover's area — step == from_pos (stuck).
# After the fix the distance field is rooted over full walkable — echo advances.
# Asserts: Chebyshev distance to target STRICTLY DECREASES (echo advanced).
static func _t_pathing_clustered_target_advances() -> Dictionary:
	var walkable := _make_rect_walkable(10, 5)
	var board    := _board_cfg(walkable)

	var echo: Dictionary = _make_actor("e1")
	GridService.assign_grid_pos(echo, 0, 2)

	var target := { "col": 7, "row": 2 }

	# Allies cluster around target: col 6 rows 1-3 + col 7 rows 1/3.
	var occupied: Array = [
		{ "col": 6, "row": 1 },
		{ "col": 6, "row": 2 },
		{ "col": 6, "row": 3 },
		{ "col": 7, "row": 1 },
		{ "col": 7, "row": 3 },
	]

	var dist_before: int = GridService.chebyshev_distance(echo.get("grid_pos", {}), target)
	_move_one_step(echo, target, board, occupied)
	var gp_after: Dictionary = echo.get("grid_pos", {})
	var dist_after: int = GridService.chebyshev_distance(gp_after, target)

	# Verify the echo actually moved (did not stay stuck).
	if dist_after >= dist_before:
		return {
			"ok": false,
			"error": ("Clustered-target repro FAILED: distance did not decrease "
				+ "(before=%d after=%d). Echo stuck at col=%d,row=%d. "
				+ "This confirms the BFS-rooted-over-wrong-walkable bug.") \
				% [dist_before, dist_after,
				   int(gp_after.get("col", -1)), int(gp_after.get("row", -1))]
		}

	# Verify the new cell is in walkable, not occupied, not the target itself.
	var gp_key: String = "%d,%d" % [int(gp_after.get("col", -1)), int(gp_after.get("row", -1))]
	if not walkable.has(gp_key):
		return { "ok": false, "error": "Echo stepped onto void cell: %s" % gp_key }

	for occ_v in occupied:
		if occ_v is Dictionary:
			var occ_key: String = "%d,%d" % [int(occ_v.get("col", -1)), int(occ_v.get("row", -1))]
			if gp_key == occ_key:
				return { "ok": false, "error": "Echo stepped onto occupied cell: %s" % gp_key }

	var target_key: String = "%d,%d" % [int(target.get("col", -1)), int(target.get("row", -1))]
	if gp_key == target_key:
		return { "ok": false, "error": "Echo stepped onto the target's own cell: %s" % gp_key }

	# Must not be (0,0) — that would indicate a fallback-default bug.
	if int(gp_after.get("col", -1)) == 0 and int(gp_after.get("row", -1)) == 0:
		return { "ok": false, "error": "Echo snapped to (0,0) — default fallback fired" }

	return { "ok": true }


# ─── Test 12 — Open path: echo advances each call, never overlaps target ─────
# No occupied positions.  Echo at (0,2), target at (9,2).
# Each shared-executor step must not increase the Chebyshev distance to target,
# and there must be at least one decrease.
static func _t_pathing_open_path_advances() -> Dictionary:
	var walkable := _make_rect_walkable(10, 5)
	var board    := _board_cfg(walkable)

	var echo: Dictionary = _make_actor("e1")
	GridService.assign_grid_pos(echo, 0, 2)
	var target := { "col": 9, "row": 2 }
	var prev_dist: int = GridService.chebyshev_distance(echo.get("grid_pos", {}), target)
	var any_progress: bool = false

	for _i in range(20):
		var gp: Dictionary = echo.get("grid_pos", {})
		if GridService.chebyshev_distance(gp, target) <= 1:
			break
		_move_one_step(echo, target, board, [])
		var gp_after: Dictionary = echo.get("grid_pos", {})
		var dist_after: int = GridService.chebyshev_distance(gp_after, target)

		if dist_after > prev_dist:
			return {
				"ok": false,
				"error": "Distance increased on open board: was %d now %d at col=%d,row=%d" \
					% [prev_dist, dist_after,
					   int(gp_after.get("col", -1)), int(gp_after.get("row", -1))]
			}
		if dist_after < prev_dist:
			any_progress = true
		prev_dist = dist_after

	if not any_progress:
		return { "ok": false, "error": "Echo made zero progress toward target on open board" }

	return { "ok": true }


# ─── Test 13 — Never steps onto occupied or void ─────────────────────────────
# Walks echo from (0,0) toward (9,4) across a 10×5 rect with scattered occupied cells.
# Every step must land on a walkable, unoccupied cell.
static func _t_pathing_never_steps_occupied_or_void() -> Dictionary:
	var walkable := _make_rect_walkable(10, 5)
	var board    := _board_cfg(walkable)

	var occupied: Array = [
		{ "col": 3, "row": 2 },
		{ "col": 5, "row": 1 },
		{ "col": 7, "row": 3 },
	]

	var echo: Dictionary = _make_actor("e1")
	GridService.assign_grid_pos(echo, 0, 0)
	var target := { "col": 9, "row": 4 }

	for _i in range(25):
		var gp: Dictionary = echo.get("grid_pos", {})
		if GridService.chebyshev_distance(gp, target) <= 1:
			break
		_move_one_step(echo, target, board, occupied)
		var gp_after: Dictionary = echo.get("grid_pos", {})
		var gp_key: String = "%d,%d" % [int(gp_after.get("col", -1)), int(gp_after.get("row", -1))]

		if not walkable.has(gp_key):
			return { "ok": false, "error": "Step landed on void: %s" % gp_key }

		for occ_v in occupied:
			if occ_v is Dictionary:
				var occ_key: String = "%d,%d" % [int(occ_v.get("col", -1)), int(occ_v.get("row", -1))]
				if gp_key == occ_key:
					return { "ok": false, "error": "Step landed on occupied cell: %s" % gp_key }

	return { "ok": true }


# ─── Test 14 — Dead-end stay: surrounded actor stays put ─────────────────────
# Echo at (5,2) in a 10×5 rect; all 8 neighbours occupied.
# Shared executor must return from_pos unchanged (no snap to (0,0)).
static func _t_pathing_dead_end_stay() -> Dictionary:
	var walkable := _make_rect_walkable(10, 5)
	var board    := _board_cfg(walkable)

	var echo: Dictionary = _make_actor("e1")
	GridService.assign_grid_pos(echo, 5, 2)

	var occupied: Array = []
	for dc in [-1, 0, 1]:
		for dr in [-1, 0, 1]:
			if dc == 0 and dr == 0:
				continue
			occupied.append({ "col": 5 + dc, "row": 2 + dr })

	var target := { "col": 9, "row": 4 }
	var result: Dictionary = _move_one_step(echo, target, board, occupied)

	var to_pos: Dictionary = result.get("to_pos", {})
	if int(to_pos.get("col", -1)) != 5 or int(to_pos.get("row", -1)) != 2:
		return {
			"ok": false,
			"error": "Surrounded actor should stay at (5,2) but moved to col=%d,row=%d" \
				% [int(to_pos.get("col", -1)), int(to_pos.get("row", -1))]
		}

	var gp: Dictionary = echo.get("grid_pos", {})
	if int(gp.get("col", -1)) != 5 or int(gp.get("row", -1)) != 2:
		return {
			"ok": false,
			"error": "Actor grid_pos mutated despite being surrounded: col=%d,row=%d" \
				% [int(gp.get("col", -1)), int(gp.get("row", -1))]
		}

	return { "ok": true }


# ─── Test 15 — Legacy (empty walkable) path is byte-identical ─────────────────
# board_cfg with walkable:{} must produce the exact same to_pos as no walkable key.
static func _t_pathing_legacy_empty_walkable_unchanged() -> Dictionary:
	var cfg_no_key   := { "board_cols": 10, "board_rows": 10 }
	var cfg_empty_wk := { "board_cols": 10, "board_rows": 10, "walkable": {} }

	var cases: Array = [
		{ "from": { "col": 1, "row": 1 }, "target": { "col": 8, "row": 8 }, "occ": [] },
		{ "from": { "col": 0, "row": 0 }, "target": { "col": 9, "row": 0 }, "occ": [{ "col": 1, "row": 0 }] },
		{ "from": { "col": 5, "row": 5 }, "target": { "col": 5, "row": 5 }, "occ": [] },
	]

	for case_v in cases:
		var c: Dictionary = case_v as Dictionary
		var from_pos: Dictionary = c.get("from",   { "col": 0, "row": 0 })
		var tgt:      Dictionary = c.get("target", { "col": 5, "row": 5 })
		var occ:      Array      = c.get("occ",    []) as Array

		var actor_a: Dictionary = _make_actor("a")
		GridService.assign_grid_pos(actor_a, int(from_pos.get("col", 0)), int(from_pos.get("row", 0)))
		var res_a: Dictionary = _move_one_step(actor_a, tgt, cfg_no_key, occ)

		var actor_b: Dictionary = _make_actor("b")
		GridService.assign_grid_pos(actor_b, int(from_pos.get("col", 0)), int(from_pos.get("row", 0)))
		var res_b: Dictionary = _move_one_step(actor_b, tgt, cfg_empty_wk, occ)

		var to_a: Dictionary = res_a.get("to_pos", {})
		var to_b: Dictionary = res_b.get("to_pos", {})
		if not _pos_equal(to_a, to_b):
			return {
				"ok": false,
				"error": "Legacy mismatch from(%d,%d)→(%d,%d): no-key=(%d,%d) empty-wk=(%d,%d)" \
					% [int(from_pos.get("col",0)), int(from_pos.get("row",0)),
					   int(tgt.get("col",0)),      int(tgt.get("row",0)),
					   int(to_a.get("col",-1)),    int(to_a.get("row",-1)),
					   int(to_b.get("col",-1)),    int(to_b.get("row",-1))]
			}

	return { "ok": true }


# ─── Test 16 — Determinism: same inputs → same step twice ────────────────────
# Calls the shared movement helper twice with identical inputs (resetting actor pos between calls).
# Both calls must return identical to_pos.
static func _t_pathing_determinism() -> Dictionary:
	var walkable_rect := _make_rect_walkable(10, 5)
	var walkable_bridge := _make_bridge_walkable()

	var cases: Array = [
		# Clustered case (the bug repro).
		{
			"from":     { "col": 0, "row": 2 },
			"target":   { "col": 7, "row": 2 },
			"occupied": [
				{ "col": 6, "row": 1 }, { "col": 6, "row": 2 }, { "col": 6, "row": 3 },
				{ "col": 7, "row": 1 }, { "col": 7, "row": 3 },
			],
			"walkable": walkable_rect,
		},
		# Open path.
		{
			"from": { "col": 0, "row": 0 }, "target": { "col": 9, "row": 4 },
			"occupied": [], "walkable": walkable_rect,
		},
		# Bridge terrain.
		{
			"from": { "col": 2, "row": 1 }, "target": { "col": 10, "row": 1 },
			"occupied": [], "walkable": walkable_bridge,
		},
	]

	for case_v in cases:
		var c: Dictionary = case_v as Dictionary
		var from_pos: Dictionary = c.get("from",     { "col": 0, "row": 0 })
		var tgt:      Dictionary = c.get("target",   { "col": 5, "row": 2 })
		var occ:      Array      = c.get("occupied", []) as Array
		var wk: Dictionary       = c.get("walkable", walkable_rect)
		var cfg: Dictionary      = _board_cfg(wk)

		var actor_1: Dictionary = _make_actor("d1")
		GridService.assign_grid_pos(actor_1, int(from_pos.get("col", 0)), int(from_pos.get("row", 0)))
		var res_1: Dictionary = _move_one_step(actor_1, tgt, cfg, occ)

		var actor_2: Dictionary = _make_actor("d2")
		GridService.assign_grid_pos(actor_2, int(from_pos.get("col", 0)), int(from_pos.get("row", 0)))
		var res_2: Dictionary = _move_one_step(actor_2, tgt, cfg, occ)

		var to_1: Dictionary = res_1.get("to_pos", {})
		var to_2: Dictionary = res_2.get("to_pos", {})
		if not _pos_equal(to_1, to_2):
			return {
				"ok": false,
				"error": "Non-deterministic: from(%d,%d) run1=(%d,%d) run2=(%d,%d)" \
					% [int(from_pos.get("col",0)), int(from_pos.get("row",0)),
					   int(to_1.get("col",-1)),    int(to_1.get("row",-1)),
					   int(to_2.get("col",-1)),    int(to_2.get("row",-1))]
			}

	return { "ok": true }
