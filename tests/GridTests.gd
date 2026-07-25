# res://tests/GridTests.gd
# Tests for the GRID-001 Board Configuration system + GRID-002 grid_pos assignment
# + GRID-003 deterministic placement + GRID-004 Manhattan distance
# + GRID-ADJ Chebyshev distance and adjacency:
#   1. GridService returns the defaults (10 cols, 10 rows) when called with no config.
#   2. GridService reads board_cols and board_rows from a config dict.
#   3. GridService.is_valid_pos() accepts cells inside the board.
#   4. GridService.is_valid_pos() rejects cells outside the board.
#   5. GridService.assign_grid_pos() sets col and row on the actor dict.               (GRID-002)
#   6. GridService.assign_grid_pos() overwrites the placeholder {col:0,row:0}.         (GRID-002)
#   7. ActorSchema.get_defaults() includes a grid_pos field with col+row keys.         (GRID-002)
#   8. An assigned position is valid per GridService.is_valid_pos().                   (GRID-002)
#   9. Same seed produces identical grid_pos for all actors.                           (GRID-003)
#  10. Higher placement score → more forward column at spawn.                          (GRID-003)
#  11. All placed positions are valid per is_valid_pos().                              (GRID-003)
#  12. Echo actors stay in left half; enemy actors stay in right half.                 (GRID-003)
#  13. manhattan_distance returns 0 for identical positions.                           (GRID-004)
#  14. manhattan_distance returns 1 for adjacent column cells.                         (GRID-004)
#  15. manhattan_distance returns 2 for a one-step diagonal move.                      (GRID-004)
#  16. manhattan_distance returns correct value for a multi-step cross-board path.     (GRID-004)
#  17. get_board_config() returns default dimensions without config.
#  18. is_valid_pos() rejects negative coordinates.
#  19. chebyshev_distance returns 0 for identical positions.                          (GRID-ADJ)
#  20. is_adjacent returns false for the same cell.                                   (GRID-ADJ)
#  21. chebyshev_distance returns 1 for an orthogonal neighbour.                      (GRID-ADJ)
#  22. chebyshev_distance returns 1 for a diagonal neighbour.                         (GRID-ADJ)
#  23. chebyshev_distance returns 2 for a two-step orthogonal distance.               (GRID-ADJ)
#  24. is_adjacent returns true for a diagonal neighbour.                             (GRID-ADJ)
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name GridTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("grid/defaults_are_10x10",            Callable(GridTests, "_t_defaults_are_10x10"))
	runner.register_test("grid/reads_board_dims_from_config",  Callable(GridTests, "_t_reads_board_dims_from_config"))
	runner.register_test("grid/valid_pos_inside_board",        Callable(GridTests, "_t_valid_pos_inside_board"))
	runner.register_test("grid/invalid_pos_outside_board",     Callable(GridTests, "_t_invalid_pos_outside_board"))
	runner.register_test("grid/assign_grid_pos_sets_col_row",         Callable(GridTests, "_t_assign_grid_pos_sets_col_row"))
	runner.register_test("grid/assign_grid_pos_overwrites_default",   Callable(GridTests, "_t_assign_grid_pos_overwrites_default"))
	runner.register_test("grid/actor_defaults_include_grid_pos",      Callable(GridTests, "_t_actor_defaults_include_grid_pos"))
	runner.register_test("grid/assign_pos_is_valid",                  Callable(GridTests, "_t_assign_pos_is_valid"))
	# GRID-003
	runner.register_test("grid/placement_same_seed_same_positions",   Callable(GridTests, "_t_placement_same_seed_same_positions"))
	runner.register_test("grid/placement_score_places_forward",       Callable(GridTests, "_t_placement_score_places_forward"))
	runner.register_test("grid/placement_all_positions_valid",        Callable(GridTests, "_t_placement_all_positions_valid"))
	runner.register_test("grid/placement_faction_halves",             Callable(GridTests, "_t_placement_faction_halves"))
	# GRID-004
	runner.register_test("grid/distance_same_cell_is_zero",          Callable(GridTests, "_t_distance_same_cell_is_zero"))
	runner.register_test("grid/distance_adjacent_col_is_one",        Callable(GridTests, "_t_distance_adjacent_col_is_one"))
	runner.register_test("grid/distance_diagonal_step_is_two",       Callable(GridTests, "_t_distance_diagonal_step_is_two"))
	runner.register_test("grid/distance_multi_step_cross_board",     Callable(GridTests, "_t_distance_multi_step_cross_board"))
	runner.register_test("grid/default_board_config_shape",          Callable(GridTests, "_t_default_board_config_shape"))
	runner.register_test("grid/valid_pos_rejects_negative",          Callable(GridTests, "_t_valid_pos_rejects_negative"))
	runner.register_test("grid/chebyshev_same_cell_is_zero",         Callable(GridTests, "_t_chebyshev_same_cell_is_zero"))
	runner.register_test("grid/is_adjacent_same_cell_false",         Callable(GridTests, "_t_is_adjacent_same_cell_false"))
	# GRID-ADJ
	runner.register_test("grid/chebyshev_orthogonal_is_one",         Callable(GridTests, "_t_chebyshev_orthogonal_is_one"))
	runner.register_test("grid/chebyshev_diagonal_is_one",           Callable(GridTests, "_t_chebyshev_diagonal_is_one"))
	runner.register_test("grid/chebyshev_two_steps_is_two",          Callable(GridTests, "_t_chebyshev_two_steps_is_two"))
	runner.register_test("grid/is_adjacent_diagonal",                Callable(GridTests, "_t_is_adjacent_diagonal"))


# -------------------------
# Tests
# -------------------------

# Test 1: defaults_are_10x10
# Expected: get_board_cols({}) == 10 and get_board_rows({}) == 10 (hardcoded fallbacks).
# GRID-002: default changed from 6×3 (GRID-001) to 10×10 for MVP. Balance.json updated to match.
static func _t_defaults_are_10x10() -> Dictionary:
	var cols: int = GridService.get_board_cols({})
	var rows: int = GridService.get_board_rows({})

	if cols != 10:
		return { "ok": false, "error": "Expected default board_cols=10, got: %d" % cols }
	if rows != 10:
		return { "ok": false, "error": "Expected default board_rows=10, got: %d" % rows }

	return { "ok": true }


# Test 2: reads_board_dims_from_config
# Expected: GridService reads board_cols and board_rows from the supplied config dict.
static func _t_reads_board_dims_from_config() -> Dictionary:
	var cfg := { "board_cols": 8, "board_rows": 4 }

	var cols: int = GridService.get_board_cols(cfg)
	var rows: int = GridService.get_board_rows(cfg)

	if cols != 8:
		return { "ok": false, "error": "Expected board_cols=8 from cfg, got: %d" % cols }
	if rows != 4:
		return { "ok": false, "error": "Expected board_rows=4 from cfg, got: %d" % rows }

	var board_cfg: Dictionary = GridService.get_board_config(cfg)
	if int(board_cfg.get("board_cols", 0)) != 8:
		return { "ok": false, "error": "get_board_config() board_cols mismatch" }
	if int(board_cfg.get("board_rows", 0)) != 4:
		return { "ok": false, "error": "get_board_config() board_rows mismatch" }

	return { "ok": true }


# Test 3: valid_pos_inside_board
# Expected: is_valid_pos() returns true for all four corners of a 6x3 board.
static func _t_valid_pos_inside_board() -> Dictionary:
	var cfg := { "board_cols": 6, "board_rows": 3 }

	var corners := [
		{ "col": 0, "row": 0 },
		{ "col": 5, "row": 0 },
		{ "col": 0, "row": 2 },
		{ "col": 5, "row": 2 },
	]

	for pos in corners:
		if not GridService.is_valid_pos(pos, cfg):
			return {
				"ok": false,
				"error": "is_valid_pos() returned false for valid cell col=%d row=%d" % [pos["col"], pos["row"]]
			}

	return { "ok": true }


# Test 4: invalid_pos_outside_board
# Expected: is_valid_pos() returns false for cells beyond the board bounds.
static func _t_invalid_pos_outside_board() -> Dictionary:
	var cfg := { "board_cols": 6, "board_rows": 3 }

	var invalid_positions := [
		{ "col": -1, "row":  0 },   # col below 0
		{ "col":  0, "row": -1 },   # row below 0
		{ "col":  6, "row":  0 },   # col == board_cols (out of bounds)
		{ "col":  0, "row":  3 },   # row == board_rows (out of bounds)
	]

	for pos in invalid_positions:
		if GridService.is_valid_pos(pos, cfg):
			return {
				"ok": false,
				"error": "is_valid_pos() returned true for out-of-bounds cell col=%d row=%d" % [pos["col"], pos["row"]]
			}

	return { "ok": true }


# -------------------------
# GRID-002 Tests
# -------------------------

# Test 5: assign_grid_pos_sets_col_row
# Expected: assign_grid_pos() mutates actor["grid_pos"] to { col: 3, row: 2 }.
static func _t_assign_grid_pos_sets_col_row() -> Dictionary:
	var actor: Dictionary = ActorSchema.get_defaults()

	GridService.assign_grid_pos(actor, 3, 2)

	var gp: Dictionary = actor.get("grid_pos", {})
	if not gp.has("col"):
		return { "ok": false, "error": "grid_pos missing 'col' key after assign_grid_pos" }
	if not gp.has("row"):
		return { "ok": false, "error": "grid_pos missing 'row' key after assign_grid_pos" }
	if int(gp["col"]) != 3:
		return { "ok": false, "error": "Expected grid_pos.col=3, got: %d" % int(gp["col"]) }
	if int(gp["row"]) != 2:
		return { "ok": false, "error": "Expected grid_pos.row=2, got: %d" % int(gp["row"]) }

	return { "ok": true }


# Test 6: assign_grid_pos_overwrites_default
# Expected: assign_grid_pos() overwrites the placeholder {col:0,row:0} with the given values.
static func _t_assign_grid_pos_overwrites_default() -> Dictionary:
	var actor: Dictionary = ActorSchema.get_defaults()

	# Confirm placeholder before overwrite.
	var before: Dictionary = actor.get("grid_pos", {})
	if int(before.get("col", -1)) != 0 or int(before.get("row", -1)) != 0:
		return { "ok": false, "error": "Expected placeholder grid_pos={0,0} before assign" }

	GridService.assign_grid_pos(actor, 5, 1)

	var after: Dictionary = actor.get("grid_pos", {})
	if int(after.get("col", -1)) != 5:
		return { "ok": false, "error": "Expected grid_pos.col=5 after overwrite, got: %d" % int(after.get("col", -1)) }
	if int(after.get("row", -1)) != 1:
		return { "ok": false, "error": "Expected grid_pos.row=1 after overwrite, got: %d" % int(after.get("row", -1)) }

	return { "ok": true }


# Test 7: actor_defaults_include_grid_pos
# Expected: ActorSchema.get_defaults() includes a "grid_pos" dict with "col" and "row" keys.
static func _t_actor_defaults_include_grid_pos() -> Dictionary:
	var defaults: Dictionary = ActorSchema.get_defaults()

	if not defaults.has("grid_pos"):
		return { "ok": false, "error": "ActorSchema.get_defaults() missing 'grid_pos' field" }

	var gp = defaults["grid_pos"]
	if not (gp is Dictionary):
		return { "ok": false, "error": "'grid_pos' in defaults is not a Dictionary" }
	if not gp.has("col"):
		return { "ok": false, "error": "defaults.grid_pos missing 'col' key" }
	if not gp.has("row"):
		return { "ok": false, "error": "defaults.grid_pos missing 'row' key" }

	return { "ok": true }


# Test 8: assign_pos_is_valid
# Expected: a position assigned by assign_grid_pos() passes is_valid_pos() on the same board config.
static func _t_assign_pos_is_valid() -> Dictionary:
	var actor: Dictionary = ActorSchema.get_defaults()
	var cfg := { "board_cols": 10, "board_rows": 10 }

	GridService.assign_grid_pos(actor, 5, 5)

	var gp: Dictionary = actor.get("grid_pos", {})
	if not GridService.is_valid_pos(gp, cfg):
		return {
			"ok": false,
			"error": "Position {col:5,row:5} should be valid on 10x10 board"
		}

	return { "ok": true }


# -------------------------
# GRID-003 Tests
# -------------------------

# Helper: builds a minimal actor dict with the fields place_actors() needs.
static func _make_actor(id: String, agi: int, speed: int, archetype: String,
		calling: String, traits: Dictionary, vectors: Dictionary) -> Dictionary:
	var a: Dictionary = ActorSchema.get_defaults()
	a["id"] = id
	a["name"] = id
	a["stats"] = { "max_hp": 100, "atk": 5, "def": 3, "agi": agi, "int": 4, "cha": 2 }
	a["speed"] = speed
	a["archetype_birth"] = archetype
	a["calling_origin"] = calling
	a["traits"] = traits
	a["vector_scores"] = vectors
	return a


# Test 9: placement_same_seed_same_positions
# Expected: calling place_actors() twice with an RNG seeded to the same value produces
# identical grid_pos for every actor.
static func _t_placement_same_seed_same_positions() -> Dictionary:
	var cfg := { "board_cols": 10, "board_rows": 10 }
	var place_cfg := {}  # no modifiers — pure base score

	var echo_a := _make_actor("e1", 3, 4, "brave",  "blade",    { "courage": 50, "wisdom": 30, "faith": 20 }, { "vanguard": 60, "protector": 10, "seeker": 20, "pillar": 10 })
	var echo_b := _make_actor("e2", 2, 3, "devout", "uncalled", { "courage": 20, "wisdom": 25, "faith": 55 }, { "vanguard": 10, "protector": 40, "seeker": 30, "pillar": 20 })
	var enemy_a := _make_actor("n1", 2, 5, "sage",   "warder",   { "courage": 30, "wisdom": 50, "faith": 20 }, { "vanguard": 20, "protector": 60, "seeker": 10, "pillar": 10 })

	# First run.
	var echoes1 := [echo_a.duplicate(true), echo_b.duplicate(true)]
	var enemies1 := [enemy_a.duplicate(true)]
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	GridService.place_actors(echoes1, enemies1, cfg, rng1, place_cfg)

	# Second run — same seed.
	var echoes2 := [echo_a.duplicate(true), echo_b.duplicate(true)]
	var enemies2 := [enemy_a.duplicate(true)]
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	GridService.place_actors(echoes2, enemies2, cfg, rng2, place_cfg)

	for i in range(echoes1.size()):
		if echoes1[i]["grid_pos"] != echoes2[i]["grid_pos"]:
			return { "ok": false, "error": "Echo %d position differed between identical seeds" % i }
	for i in range(enemies1.size()):
		if enemies1[i]["grid_pos"] != enemies2[i]["grid_pos"]:
			return { "ok": false, "error": "Enemy %d position differed between identical seeds" % i }

	return { "ok": true }


# Test 10: placement_score_places_forward
# Expected: a brave+warrior actor (high score) ends up in a higher col than a
# devout+archer actor (low score) when placed on the same side.
# board_rows=1 forces each actor into its own column, making the score → col
# relationship directly visible (with board_rows=10 both actors fit in col=1).
static func _t_placement_score_places_forward() -> Dictionary:
	var cfg := { "board_cols": 10, "board_rows": 1 }
	# Use the confirmed modifier tables.
	var place_cfg := {
		"by_archetype":        { "brave": 2, "devout": -2 },
		"by_calling_origin":   { "blade": 2, "ranger": -2 },
		"by_dominant_trait":   { "courage": 1, "wisdom": -1, "faith": 0 },
		"by_dominant_vector":  { "vanguard": 2, "pillar": -2, "seeker": 0, "protector": -1 },
	}

	# High-score echo: brave + blade + courage-dominant + vanguard-dominant.
	var fast := _make_actor("fast", 5, 5, "brave",  "blade",
		{ "courage": 60, "wisdom": 20, "faith": 20 },
		{ "vanguard": 70, "protector": 10, "seeker": 10, "pillar": 10 })
	# Low-score echo: devout + ranger + faith-dominant + pillar-dominant.
	var slow := _make_actor("slow", 1, 1, "devout", "ranger",
		{ "courage": 15, "wisdom": 20, "faith": 65 },
		{ "vanguard": 5, "protector": 15, "seeker": 20, "pillar": 60 })

	var echoes := [fast.duplicate(true), slow.duplicate(true)]
	var enemies: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	GridService.place_actors(echoes, enemies, cfg, rng, place_cfg)

	var fast_col: int = int(echoes[0]["grid_pos"]["col"])
	var slow_col: int = int(echoes[1]["grid_pos"]["col"])

	if fast_col <= slow_col:
		return {
			"ok": false,
			"error": "Expected high-score 'fast' (col=%d) > low-score 'slow' (col=%d)" % [fast_col, slow_col]
		}

	return { "ok": true }


# Test 11: placement_all_positions_valid
# Expected: every grid_pos assigned by place_actors() passes is_valid_pos().
static func _t_placement_all_positions_valid() -> Dictionary:
	var cfg := { "board_cols": 10, "board_rows": 10 }
	var echoes: Array = []
	var enemies: Array = []
	for i in range(5):
		echoes.append(_make_actor("e%d" % i, i, i + 1, "brave", "blade",
			{ "courage": 50, "wisdom": 25, "faith": 25 },
			{ "vanguard": 60, "protector": 10, "seeker": 20, "pillar": 10 }))
		enemies.append(_make_actor("n%d" % i, i, i + 1, "sage", "warder",
			{ "courage": 20, "wisdom": 55, "faith": 25 },
			{ "vanguard": 10, "protector": 50, "seeker": 30, "pillar": 10 }))

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	GridService.place_actors(echoes, enemies, cfg, rng, {})

	for actor in echoes + enemies:
		var gp: Dictionary = actor.get("grid_pos", {})
		if not GridService.is_valid_pos(gp, cfg):
			return {
				"ok": false,
				"error": "Actor '%s' has invalid grid_pos {col:%d,row:%d}" % [
					actor["id"], int(gp.get("col", -1)), int(gp.get("row", -1))]
			}

	return { "ok": true }


# Test 12: placement_faction_halves
# Expected: echo actors land in col < board_cols/2; enemy actors in col >= board_cols/2.
static func _t_placement_faction_halves() -> Dictionary:
	var cfg := { "board_cols": 10, "board_rows": 10 }
	var half: int = 5  # board_cols / 2

	var echoes: Array = []
	var enemies: Array = []
	for i in range(4):
		echoes.append(_make_actor("e%d" % i, 2, 3, "sage", "uncalled",
			{ "courage": 33, "wisdom": 34, "faith": 33 },
			{ "vanguard": 25, "protector": 25, "seeker": 25, "pillar": 25 }))
		enemies.append(_make_actor("n%d" % i, 2, 3, "sage", "uncalled",
			{ "courage": 33, "wisdom": 34, "faith": 33 },
			{ "vanguard": 25, "protector": 25, "seeker": 25, "pillar": 25 }))

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	GridService.place_actors(echoes, enemies, cfg, rng, {})

	for actor in echoes:
		var col: int = int(actor["grid_pos"]["col"])
		if col >= half:
			return { "ok": false, "error": "Echo '%s' landed in right half (col=%d)" % [actor["id"], col] }

	for actor in enemies:
		var col: int = int(actor["grid_pos"]["col"])
		if col < half:
			return { "ok": false, "error": "Enemy '%s' landed in left half (col=%d)" % [actor["id"], col] }

	return { "ok": true }


# -------------------------
# GRID-004 Tests
# -------------------------

# Test 13: distance_same_cell_is_zero
# Expected: manhattan_distance of a position to itself is 0.
static func _t_distance_same_cell_is_zero() -> Dictionary:
	var pos := { "col": 3, "row": 4 }
	var dist: int = GridService.manhattan_distance(pos, pos)
	if dist != 0:
		return { "ok": false, "error": "Expected distance(same,same)=0, got: %d" % dist }
	return { "ok": true }


# Test 14: distance_adjacent_col_is_one
# Expected: cells that differ by exactly one column have distance 1.
static func _t_distance_adjacent_col_is_one() -> Dictionary:
	var a := { "col": 0, "row": 0 }
	var b := { "col": 1, "row": 0 }
	var dist: int = GridService.manhattan_distance(a, b)
	if dist != 1:
		return { "ok": false, "error": "Expected distance(adjacent col)=1, got: %d" % dist }
	return { "ok": true }


# Test 15: distance_diagonal_step_is_two
# Expected: a move of +1 col and +1 row has Manhattan distance 2 (not sqrt(2)).
static func _t_distance_diagonal_step_is_two() -> Dictionary:
	var a := { "col": 0, "row": 0 }
	var b := { "col": 1, "row": 1 }
	var dist: int = GridService.manhattan_distance(a, b)
	if dist != 2:
		return { "ok": false, "error": "Expected distance(diagonal step)=2, got: %d" % dist }
	return { "ok": true }


# Test 16: distance_multi_step_cross_board
# Expected: distance from (0,0) to (4,3) = |4-0| + |3-0| = 7.
static func _t_distance_multi_step_cross_board() -> Dictionary:
	var a := { "col": 0, "row": 0 }
	var b := { "col": 4, "row": 3 }
	var dist: int = GridService.manhattan_distance(a, b)
	if dist != 7:
		return { "ok": false, "error": "Expected distance((0,0)→(4,3))=7, got: %d" % dist }
	return { "ok": true }


static func _t_default_board_config_shape() -> Dictionary:
	var cfg: Dictionary = GridService.get_board_config({})
	if int(cfg.get("board_cols", 0)) != 10:
		return { "ok": false, "error": "Expected default board_cols=10, got: %d" % int(cfg.get("board_cols", 0)) }
	if int(cfg.get("board_rows", 0)) != 10:
		return { "ok": false, "error": "Expected default board_rows=10, got: %d" % int(cfg.get("board_rows", 0)) }
	return { "ok": true }


static func _t_valid_pos_rejects_negative() -> Dictionary:
	var cfg := { "board_cols": 10, "board_rows": 10 }
	if GridService.is_valid_pos({ "col": -1, "row": 0 }, cfg):
		return { "ok": false, "error": "Negative col accepted as valid" }
	if GridService.is_valid_pos({ "col": 0, "row": -1 }, cfg):
		return { "ok": false, "error": "Negative row accepted as valid" }
	return { "ok": true }


static func _t_chebyshev_same_cell_is_zero() -> Dictionary:
	var pos := { "col": 4, "row": 4 }
	var dist: int = GridService.chebyshev_distance(pos, pos)
	if dist != 0:
		return { "ok": false, "error": "Expected chebyshev(same cell)=0, got: %d" % dist }
	return { "ok": true }


static func _t_is_adjacent_same_cell_false() -> Dictionary:
	var pos := { "col": 4, "row": 4 }
	if GridService.is_adjacent(pos, pos):
		return { "ok": false, "error": "Same cell reported adjacent" }
	return { "ok": true }


# -------------------------
# GRID-ADJ Tests
# -------------------------

# Test 21: chebyshev_orthogonal_is_one
# Expected: chebyshev_distance of an orthogonal neighbour is 1.
static func _t_chebyshev_orthogonal_is_one() -> Dictionary:
	var a := { "col": 0, "row": 0 }
	var b := { "col": 1, "row": 0 }
	var dist: int = GridService.chebyshev_distance(a, b)
	if dist != 1:
		return { "ok": false, "error": "Expected chebyshev(orthogonal)=1, got: %d" % dist }
	return { "ok": true }


# Test 22: chebyshev_diagonal_is_one
# Expected: chebyshev_distance of a diagonal neighbour is 1 (not 2).
# This is the key difference from Manhattan — diagonal costs the same as orthogonal.
static func _t_chebyshev_diagonal_is_one() -> Dictionary:
	var a := { "col": 0, "row": 0 }
	var b := { "col": 1, "row": 1 }
	var dist: int = GridService.chebyshev_distance(a, b)
	if dist != 1:
		return { "ok": false, "error": "Expected chebyshev(diagonal)=1, got: %d" % dist }
	return { "ok": true }


# Test 23: chebyshev_two_steps_is_two
# Expected: chebyshev_distance of a two-step orthogonal position is 2.
static func _t_chebyshev_two_steps_is_two() -> Dictionary:
	var a := { "col": 0, "row": 0 }
	var b := { "col": 2, "row": 0 }
	var dist: int = GridService.chebyshev_distance(a, b)
	if dist != 2:
		return { "ok": false, "error": "Expected chebyshev(two steps)=2, got: %d" % dist }
	return { "ok": true }


# Test 24: is_adjacent_diagonal
# Expected: is_adjacent() returns true for a diagonal neighbour.
# Confirms that melee range now covers all 8 surrounding cells.
static func _t_is_adjacent_diagonal() -> Dictionary:
	var a := { "col": 0, "row": 0 }
	var b := { "col": 1, "row": 1 }
	if not GridService.is_adjacent(a, b):
		return { "ok": false, "error": "Expected is_adjacent({0,0},{1,1})=true (diagonal neighbour)" }
	return { "ok": true }
