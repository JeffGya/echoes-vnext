# res://tests/GridTests.gd
# Tests for the GRID-001 Board Configuration system + GRID-002 grid_pos assignment:
#   1. GridService returns the defaults (10 cols, 10 rows) when called with no config.
#   2. GridService reads board_cols and board_rows from a config dict.
#   3. GridService.is_valid_pos() accepts cells inside the board.
#   4. GridService.is_valid_pos() rejects cells outside the board.
#   5. GridService.assign_grid_pos() sets col and row on the actor dict.         (GRID-002)
#   6. GridService.assign_grid_pos() overwrites the placeholder {col:0,row:0}.   (GRID-002)
#   7. ActorSchema.get_defaults() includes a grid_pos field with col+row keys.   (GRID-002)
#   8. An assigned position is valid per GridService.is_valid_pos().             (GRID-002)
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
