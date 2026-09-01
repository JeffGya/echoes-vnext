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
#  25. An isolated walkable cell (StageTerrain.legal_neighbors empty) is skipped      (V2-COMBAT-003
#      while a legal cell remains unfilled.                                           phase 2c)
#  26. place_actors makes zero RNG draws on the walkable branch, even when the        (V2-COMBAT-003
#      candidate set contains an isolated cell (rng.state unchanged before/after).    phase 2c)
#  27. When every walkable cell is isolated, every actor is still placed — nobody     (V2-COMBAT-003
#      is dropped from the encounter.                                                 phase 2c)
#  28. On a board with no isolated cells, the placement guard changes nothing —       (V2-COMBAT-003
#      positions are identical to the pre-guard ordered-fill algorithm.               phase 2c)
#  29. A cut-off REGION of two or more cells (each cell has a legal neighbour —       (V2-COMBAT-003
#      the other cell in the group — so the old per-cell guard cannot see it) is      phase 2c-region)
#      excluded from placement; actors land in the board's largest region instead.
#      FAILS against 1b3badc (the per-cell-only guard).
#  30. Both factions are restricted to the SAME largest region, even when a           (V2-COMBAT-003
#      second, smaller connected region exists on the board.                         phase 2c-region)
#  31. The region guard makes zero RNG draws.                                        (V2-COMBAT-003
#                                                                                      phase 2c-region)
#  32. echo_outside_region_fallback fires (and walkable_exhausted does not) when      (V2-COMBAT-003
#      a faction's region runs out but the full walkable set still has room.         phase 2c-region)
#  33. echo_walkable_exhausted_fallback fires (and outside_region does not) when      (V2-COMBAT-003
#      a faction simply has more actors than the board has walkable cells, with      phase 2c-region)
#      zero cut-off cells anywhere on the board.
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
	# V2-COMBAT-003 phase 2c — the placement guard
	runner.register_test("grid/isolated_cell_skipped_while_legal_remains",
		Callable(GridTests, "_t_isolated_cell_skipped_while_legal_remains"))
	runner.register_test("grid/isolated_cell_placement_zero_rng_draws",
		Callable(GridTests, "_t_isolated_cell_placement_zero_rng_draws"))
	runner.register_test("grid/isolated_only_board_drops_nobody",
		Callable(GridTests, "_t_isolated_only_board_drops_nobody"))
	runner.register_test("grid/no_isolated_cells_placement_unchanged",
		Callable(GridTests, "_t_no_isolated_cells_placement_unchanged"))
	# V2-COMBAT-003 phase 2c-region — the region guard
	runner.register_test("grid/cutoff_region_of_two_excluded_from_placement",
		Callable(GridTests, "_t_cutoff_region_of_two_excluded_from_placement"))
	runner.register_test("grid/both_factions_land_in_same_region",
		Callable(GridTests, "_t_both_factions_land_in_same_region"))
	runner.register_test("grid/region_zero_rng_draws",
		Callable(GridTests, "_t_region_zero_rng_draws"))
	runner.register_test("grid/outside_region_fallback_cause",
		Callable(GridTests, "_t_outside_region_fallback_cause"))
	runner.register_test("grid/walkable_exhausted_fallback_cause",
		Callable(GridTests, "_t_walkable_exhausted_fallback_cause"))


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


# ─────────────────────────────────────────────────────────────────────────────
# V2-COMBAT-003 phase 2c — the placement guard
#
# GridService.place_actors can place an actor on a walkable cell that has no legal
# edge (StageTerrain.is_legal_edge rejects a diagonal whose two orthogonal side
# cells are both solid, or the cell simply has no walkable neighbour at all). The
# actor is then stranded: the movement layer truthfully reports zero options and
# the actor idles forever.
#
# _assign_walkable_faction now runs a three-pass fill:
#   1. ordered pass, skipping any cell outside the board's largest connected region
#      (V2-COMBAT-003 phase 2c-region: a cut-off GROUP of 2+ cells is invisible to a
#      per-cell "has any legal neighbour" test, since each cell in the group has a
#      legal neighbour — the other cells in the same group. The region test replaces
#      the per-cell test entirely.)
#   2. sorted drain, same region filter
#   3. unfiltered final pass over the FULL walkable set — reached only when that
#      faction's share of the main region is exhausted, so an actor is never dropped
#      from the encounter
# ─────────────────────────────────────────────────────────────────────────────

# Helper: builds a walkable set with a 2x2 legal clump at cols 5-6, rows 5-6
# (every cell there has an orthogonal walkable neighbour, so legal_neighbors is
# always non-empty) plus one isolated singleton cell at (0,0) — no walkable cell
# is adjacent to it in any of the 8 directions, so StageTerrain.legal_neighbors
# for (0,0) is empty. Column 0 sorts before columns 5-6, so the ordered fill visits
# the isolated cell FIRST — this is what makes the pre-fix code strand an actor
# there while legal ground remains.
static func _make_clump_plus_isolated_walkable() -> Dictionary:
	return {
		"0,0": true,  # isolated — no walkable neighbour at all
		"5,5": true, "6,5": true,
		"5,6": true, "6,6": true,
	}


# Test 25: isolated_cell_skipped_while_legal_remains
# Expected: with 4 actors and 5 walkable cells (4 legal + 1 isolated), every actor
# lands on the legal 2x2 clump and (0,0) — the isolated cell — is never used, even
# though it sorts first in fill order.
#
# Against the pre-fix code (a single unfiltered ordered pass) this test FAILS:
# actor "e1" is assigned to (0,0) because it is first in echo_cells order, and the
# clump cell (6,6) is left unused. See the phase 2c report for the captured
# failure output.
static func _t_isolated_cell_skipped_while_legal_remains() -> Dictionary:
	var walkable := _make_clump_plus_isolated_walkable()
	var board := { "board_cols": 10, "board_rows": 10, "walkable": walkable }

	var echoes: Array = [
		_make_actor("e1", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e2", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e3", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e4", 2, 2, "brave", "blade", {}, {}),
	]
	var enemies: Array = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	GridService.place_actors(echoes, enemies, board, rng, {})

	var legal_keys: Dictionary = { "5,5": true, "6,5": true, "5,6": true, "6,6": true }
	var used: Dictionary = {}
	for actor in echoes:
		var gp: Dictionary = actor.get("grid_pos", {})
		var key: String = "%d,%d" % [int(gp.get("col", -999)), int(gp.get("row", -999))]
		if key == "0,0":
			return {
				"ok": false,
				"error": ("Actor '%s' was placed on the isolated cell (0,0) while a legal " + \
					"clump cell remained — StageTerrain.legal_neighbors('0,0') is empty") \
					% str(actor.get("id", "?"))
			}
		if not legal_keys.has(key):
			return {
				"ok": false,
				"error": "Actor '%s' placed at %s, outside the legal clump" \
					% [str(actor.get("id", "?")), key]
			}
		used[key] = true

	if used.size() != 4:
		return { "ok": false, "error": "Expected all 4 legal clump cells used, got: %s" % [used.keys()] }

	return { "ok": true }


# Test 26: isolated_cell_placement_zero_rng_draws
# Expected: place_actors on the walkable branch makes ZERO RNG draws, even when the
# candidate set includes an isolated cell that the new filter must skip. Asserted
# directly via rng.state, per CONVENTIONS.md's guarantee for the walkable path.
static func _t_isolated_cell_placement_zero_rng_draws() -> Dictionary:
	var walkable := _make_clump_plus_isolated_walkable()
	var board := { "board_cols": 10, "board_rows": 10, "walkable": walkable }

	var echoes: Array = [
		_make_actor("e1", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e2", 2, 2, "brave", "blade", {}, {}),
	]
	var enemies: Array = [
		_make_actor("n1", 2, 2, "sage", "warder", {}, {}),
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var state_before: int = rng.state

	GridService.place_actors(echoes, enemies, board, rng, {})

	var state_after: int = rng.state
	if state_after != state_before:
		return {
			"ok": false,
			"error": "rng.state changed across place_actors (walkable branch): before=%d after=%d — the placement guard must make zero RNG draws" \
				% [state_before, state_after]
		}

	return { "ok": true }


# Test 27: isolated_only_board_drops_nobody
# Expected: when every walkable cell is isolated (no legal edge exists anywhere on
# the board), pass 3 (the unfiltered fallback) still places every actor. Placing an
# actor on unreachable ground is bad; dropping it from the encounter is worse.
static func _t_isolated_only_board_drops_nobody() -> Dictionary:
	# Two singleton cells, far enough apart that neither is adjacent to the other or
	# to anything else — both are fully isolated (legal_neighbors empty for both).
	var walkable := { "0,0": true, "5,5": true }
	var board := { "board_cols": 10, "board_rows": 10, "walkable": walkable }

	var echoes: Array = [
		_make_actor("e1", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e2", 2, 2, "brave", "blade", {}, {}),
	]
	var enemies: Array = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	GridService.place_actors(echoes, enemies, board, rng, {})

	var seen: Dictionary = {}
	for actor in echoes:
		var gp: Dictionary = actor.get("grid_pos", {})
		var key: String = "%d,%d" % [int(gp.get("col", -999)), int(gp.get("row", -999))]
		if not walkable.has(key):
			return {
				"ok": false,
				"error": "Actor '%s' was not placed on any walkable cell (got %s) — an actor was dropped" \
					% [str(actor.get("id", "?")), key]
			}
		seen[key] = true

	if seen.size() != 2:
		return {
			"ok": false,
			"error": "Expected both isolated cells used (one per actor), got: %s" % [seen.keys()]
		}

	return { "ok": true }


# Test 28: no_isolated_cells_placement_unchanged
# Expected: on a board where every cell is legally reachable, the placement guard's
# filter never rejects anything, so the result is byte-identical to the pre-guard
# ordered-fill algorithm — a plain col-major, row-ascending consumption of
# echo_cells. Verified against hand-computed expected positions for a fully solid
# 3-wide x 2-tall rectangle (no isolated cells exist on it).
static func _t_no_isolated_cells_placement_unchanged() -> Dictionary:
	var walkable: Dictionary = {}
	for c in range(3):
		for r in range(2):
			walkable["%d,%d" % [c, r]] = true

	var board := { "board_cols": 3, "board_rows": 2, "walkable": walkable }

	var echoes: Array = [
		_make_actor("e1", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e2", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e3", 2, 2, "brave", "blade", {}, {}),
	]
	var enemies: Array = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	GridService.place_actors(echoes, enemies, board, rng, {})

	# Col-major, row-ascending order over the whole 3x2 rectangle is:
	# (0,0), (0,1), (1,0), (1,1), (2,0), (2,1) — same-score actors keep input order
	# (e1, e2, e3) via the id tiebreak, so the ordered pass assigns the first three.
	var expected: Array = [
		{ "col": 0, "row": 0 },
		{ "col": 0, "row": 1 },
		{ "col": 1, "row": 0 },
	]
	for i in range(echoes.size()):
		var gp: Dictionary = echoes[i].get("grid_pos", {})
		if not _pos_equal_grid(gp, expected[i]):
			return {
				"ok": false,
				"error": "Actor '%s' expected at %s, got %s — placement guard changed behaviour on an isolation-free board" \
					% [str(echoes[i].get("id", "?")), str(expected[i]), str(gp)]
			}

	return { "ok": true }


# Helper: exact col+row equality for two grid_pos-shaped dicts.
static func _pos_equal_grid(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("col", -1)) == int(b.get("col", -1)) \
		and int(a.get("row", -1)) == int(b.get("row", -1))


# ─────────────────────────────────────────────────────────────────────────────
# V2-COMBAT-003 phase 2c-region — the region guard.
#
# The phase 2c per-cell guard (StageTerrain.legal_neighbors empty ⇒ skip) only sees a
# cut-off SINGLE cell. A cut-off GROUP of two or more cells passes that guard, because
# every cell in the group has a legal neighbour — the other cells in the same group.
# Measured on generated boards: cut-off regions reaching 86-115 cells, stranding real
# Echoes and enemies with the phase 2c guard already in place.
#
# The fix computes the walkable set's connected regions ONCE per place_actors() call
# (StageTerrain.legal_neighbors as the sole adjacency rule — the same authority the
# movement layer uses) and restricts BOTH factions to the single largest region.
# ─────────────────────────────────────────────────────────────────────────────

# Helper: a 3x3 fully-connected "main" region at cols 5-7, rows 5-7 (9 cells), plus a
# 2-cell cut-off region at (0,0)/(1,0). The two cut-off cells are legal neighbours of
# EACH OTHER (orthogonally adjacent), so StageTerrain.legal_neighbors is non-empty for
# both — the phase 2c per-cell guard cannot see this cut-off group. Column 0 sorts
# before columns 5-7, so the ordered fill visits the cut-off group FIRST, exactly the
# condition that let 1b3badc strand actors there.
static func _make_main_region_plus_cutoff_pair() -> Dictionary:
	var w: Dictionary = {
		"0,0": true, "1,0": true,  # cut-off pair — connected to each other only
	}
	for c in range(5, 8):
		for r in range(5, 8):
			w["%d,%d" % [c, r]] = true
	return w


# Test 29: cutoff_region_of_two_excluded_from_placement
# Expected: with 2 echo actors and the fixture above, neither echo lands on the 2-cell
# cut-off pair — both land inside the 9-cell main region instead.
#
# Against 1b3badc (the per-cell-only guard) this test FAILS: e1 is assigned (0,0) and
# e2 is assigned (1,0), because StageTerrain.legal_neighbors is non-empty for both
# (each is a legal neighbour of the other) — the per-cell guard has nothing to skip.
static func _t_cutoff_region_of_two_excluded_from_placement() -> Dictionary:
	var walkable := _make_main_region_plus_cutoff_pair()
	var board := { "board_cols": 10, "board_rows": 10, "walkable": walkable }

	var echoes: Array = [
		_make_actor("e1", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e2", 2, 2, "brave", "blade", {}, {}),
	]
	var enemies: Array = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 314

	GridService.place_actors(echoes, enemies, board, rng, {})

	var cutoff_keys: Dictionary = { "0,0": true, "1,0": true }
	var main_region_keys: Dictionary = {}
	for c in range(5, 8):
		for r in range(5, 8):
			main_region_keys["%d,%d" % [c, r]] = true

	for actor in echoes:
		var gp: Dictionary = actor.get("grid_pos", {})
		var key: String = "%d,%d" % [int(gp.get("col", -999)), int(gp.get("row", -999))]
		if cutoff_keys.has(key):
			return {
				"ok": false,
				"error": ("Actor '%s' was placed on the 2-cell cut-off region at %s — a " + \
					"cut-off GROUP (not a single isolated cell) was not excluded from " + \
					"placement") % [str(actor.get("id", "?")), key]
			}
		if not main_region_keys.has(key):
			return {
				"ok": false,
				"error": "Actor '%s' placed at %s, outside the 9-cell main region" \
					% [str(actor.get("id", "?")), key]
			}

	return { "ok": true }


# Test 30: both_factions_land_in_same_region
# Expected: given a 6-cell main region and a separate 4-cell region, both echoes AND
# both enemies land inside the 6-cell main region — never the smaller one, and never
# split across the two. A battle with the party and the enemies in different regions
# cannot happen; that is worse than a single stranded actor.
static func _t_both_factions_land_in_same_region() -> Dictionary:
	var walkable: Dictionary = {}
	# Main region: cols 5-6, rows 5-7 (6 cells).
	for c in range(5, 7):
		for r in range(5, 8):
			walkable["%d,%d" % [c, r]] = true
	# Smaller, separate region: cols 0-1, rows 0-1 (4 cells).
	for c in range(0, 2):
		for r in range(0, 2):
			walkable["%d,%d" % [c, r]] = true

	var board := { "board_cols": 10, "board_rows": 10, "walkable": walkable }

	var echoes: Array = [
		_make_actor("e1", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e2", 2, 2, "brave", "blade", {}, {}),
	]
	var enemies: Array = [
		_make_actor("n1", 2, 2, "sage", "warder", {}, {}),
		_make_actor("n2", 2, 2, "sage", "warder", {}, {}),
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 271

	GridService.place_actors(echoes, enemies, board, rng, {})

	var main_region_keys: Dictionary = {}
	for c in range(5, 7):
		for r in range(5, 8):
			main_region_keys["%d,%d" % [c, r]] = true

	for actor in echoes + enemies:
		var gp: Dictionary = actor.get("grid_pos", {})
		var key: String = "%d,%d" % [int(gp.get("col", -999)), int(gp.get("row", -999))]
		if not main_region_keys.has(key):
			return {
				"ok": false,
				"error": ("Actor '%s' placed at %s, outside the shared 6-cell main region " + \
					"— the two factions split across regions") \
					% [str(actor.get("id", "?")), key]
			}

	return { "ok": true }


# Test 31: region_zero_rng_draws
# Expected: place_actors on the walkable branch makes ZERO RNG draws when the region
# computation runs (a board with both a main region and a cut-off pair), asserted
# directly via rng.state per CONVENTIONS.md's guarantee for the walkable path.
static func _t_region_zero_rng_draws() -> Dictionary:
	var walkable := _make_main_region_plus_cutoff_pair()
	var board := { "board_cols": 10, "board_rows": 10, "walkable": walkable }

	var echoes: Array = [
		_make_actor("e1", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e2", 2, 2, "brave", "blade", {}, {}),
	]
	var enemies: Array = [
		_make_actor("n1", 2, 2, "sage", "warder", {}, {}),
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var state_before: int = rng.state

	GridService.place_actors(echoes, enemies, board, rng, {})

	var state_after: int = rng.state
	if state_after != state_before:
		return {
			"ok": false,
			"error": "rng.state changed across place_actors (region guard): before=%d after=%d — the region guard must make zero RNG draws" \
				% [state_before, state_after]
		}

	return { "ok": true }


# Test 32: outside_region_fallback_cause
# Expected: a 3-cell main region (row 5, cols 5-7) plus one isolated singleton at
# (0,0) — total walkable = 4 cells, one region of 3. With 4 echo actors, the main
# region runs out after 3, so the 4th falls to pass 3 and lands at (0,0) — outside
# the main region. The full walkable set (4 cells) is NOT smaller than the actor
# count (4), so this is NOT a walkable shortage: echo_outside_region_fallback must
# be true and echo_walkable_exhausted_fallback must be false.
static func _t_outside_region_fallback_cause() -> Dictionary:
	var walkable: Dictionary = { "0,0": true, "5,5": true, "6,5": true, "7,5": true }
	var board := { "board_cols": 10, "board_rows": 10, "walkable": walkable }

	var echoes: Array = [
		_make_actor("e1", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e2", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e3", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e4", 2, 2, "brave", "blade", {}, {}),
	]
	var enemies: Array = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 8080

	var result: Dictionary = GridService.place_actors(echoes, enemies, board, rng, {})

	if not bool(result.get("echo_outside_region_fallback", false)):
		return {
			"ok": false,
			"error": "Expected echo_outside_region_fallback=true (main region of 3 ran " + \
				"out for 4 actors, though the full 4-cell walkable set had room) — got %s" \
				% [str(result)]
		}
	if bool(result.get("echo_walkable_exhausted_fallback", false)):
		return {
			"ok": false,
			"error": "Expected echo_walkable_exhausted_fallback=false (4 actors, 4 " + \
				"walkable cells total — not a shortage) — got %s" % [str(result)]
		}

	return { "ok": true }


# Test 33: walkable_exhausted_fallback_cause
# Expected: a single fully-connected 2x2 block (4 cells, ZERO cut-off cells anywhere
# on the board — the whole walkable set IS the one region) with 6 echo actors. The
# board has fewer walkable cells than actors, a plain shortage unrelated to
# connectivity: echo_walkable_exhausted_fallback must be true and
# echo_outside_region_fallback must be false.
#
# This is the proven false-alarm case: before this fix, the single collapsed
# "unfiltered_fallback" flag could not distinguish this shortage from a real
# connectivity defect, and a board with zero cut-off cells still reported
# "no legal edge" — a false diagnosis.
static func _t_walkable_exhausted_fallback_cause() -> Dictionary:
	var walkable: Dictionary = {}
	for c in range(5, 7):
		for r in range(5, 7):
			walkable["%d,%d" % [c, r]] = true
	var board := { "board_cols": 10, "board_rows": 10, "walkable": walkable }

	var echoes: Array = [
		_make_actor("e1", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e2", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e3", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e4", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e5", 2, 2, "brave", "blade", {}, {}),
		_make_actor("e6", 2, 2, "brave", "blade", {}, {}),
	]
	var enemies: Array = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 9001

	var result: Dictionary = GridService.place_actors(echoes, enemies, board, rng, {})

	if not bool(result.get("echo_walkable_exhausted_fallback", false)):
		return {
			"ok": false,
			"error": "Expected echo_walkable_exhausted_fallback=true (6 actors, 4 " + \
				"walkable cells total, zero cut-off cells) — got %s" % [str(result)]
		}
	if bool(result.get("echo_outside_region_fallback", false)):
		return {
			"ok": false,
			"error": "Expected echo_outside_region_fallback=false (there is only one " + \
				"region — the whole walkable set — so nothing can be 'outside' it) — " + \
				"got %s" % [str(result)]
		}

	return { "ok": true }
