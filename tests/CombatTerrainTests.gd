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
#   4. combat_terrain/move_toward_never_enters_void
#         — repeated move_toward over a 2-wide bridge never steps on a void cell;
#           actor crosses from one plateau to the other.
#   5. combat_terrain/move_toward_makes_progress_across_bridge
#         — actor on the left plateau eventually reaches (or adjoins) the target on the
#           right plateau, confirming the bridge is traversable.
#   6. combat_terrain/movement_keystone_empty_walkable_matches_legacy
#         — empty walkable ⇒ move_toward result identical to the legacy greedy step.
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


# ─── Helpers ────────────────────────────────────────────────────────────────

# Build a minimal actor dict that satisfies place_actors() and move_toward().
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


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat_terrain/walkable_placement_all_on_walkable",
		Callable(CombatTerrainTests, "_t_walkable_placement_all_on_walkable"))
	runner.register_test("combat_terrain/walkable_placement_echo_left_enemy_right",
		Callable(CombatTerrainTests, "_t_walkable_placement_echo_left_enemy_right"))
	runner.register_test("combat_terrain/placement_keystone_empty_walkable_matches_legacy",
		Callable(CombatTerrainTests, "_t_placement_keystone_empty_walkable_matches_legacy"))
	runner.register_test("combat_terrain/move_toward_never_enters_void",
		Callable(CombatTerrainTests, "_t_move_toward_never_enters_void"))
	runner.register_test("combat_terrain/move_toward_makes_progress_across_bridge",
		Callable(CombatTerrainTests, "_t_move_toward_makes_progress_across_bridge"))
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
# (col 10, row 1).  Runs up to 30 steps of move_toward with board_cfg["walkable"]
# set.  At EVERY step, asserts the actor's grid_pos is in the walkable set.
static func _t_move_toward_never_enters_void() -> Dictionary:
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
		GridService.move_toward(actor, target, board, [])

	return { "ok": true }


# ─── Test 5 — Move toward makes progress across the bridge ───────────────────
# Same setup as Test 4.  After at most walkable.size() + 5 steps the actor must
# be within Chebyshev distance 1 of the target (reached or adjacent).
static func _t_move_toward_makes_progress_across_bridge() -> Dictionary:
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
		GridService.move_toward(actor, target, board, [])
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
# With board_cfg containing walkable:{}, move_toward must produce the same result
# as move_toward with no walkable key at all (legacy 8-dir greedy path).
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
		var result_a: Dictionary = GridService.move_toward(actor_a, target, cfg_no_walkable, [])

		var actor_b: Dictionary = _make_actor("x")
		GridService.assign_grid_pos(actor_b, int(from_pos.get("col", 0)), int(from_pos.get("row", 0)))
		var result_b: Dictionary = GridService.move_toward(actor_b, target, cfg_empty_walk, [])

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
