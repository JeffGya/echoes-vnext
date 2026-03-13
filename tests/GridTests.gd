# res://tests/GridTests.gd
# Tests for the GRID-001 Board Configuration system:
#   1. GridService returns the defaults (6 cols, 3 rows) when called with no config.
#   2. GridService reads board_cols and board_rows from a config dict.
#   3. GridService.is_valid_pos() accepts cells inside the board.
#   4. GridService.is_valid_pos() rejects cells outside the board.
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name GridTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("grid/defaults_are_6x3",             Callable(GridTests, "_t_defaults_are_6x3"))
	runner.register_test("grid/reads_board_dims_from_config", Callable(GridTests, "_t_reads_board_dims_from_config"))
	runner.register_test("grid/valid_pos_inside_board",       Callable(GridTests, "_t_valid_pos_inside_board"))
	runner.register_test("grid/invalid_pos_outside_board",    Callable(GridTests, "_t_invalid_pos_outside_board"))


# -------------------------
# Tests
# -------------------------

# Test 1: defaults_are_6x3
# Expected: get_board_cols({}) == 6 and get_board_rows({}) == 3 (hardcoded fallbacks).
static func _t_defaults_are_6x3() -> Dictionary:
	var cols: int = GridService.get_board_cols({})
	var rows: int = GridService.get_board_rows({})

	if cols != 6:
		return { "ok": false, "error": "Expected default board_cols=6, got: %d" % cols }
	if rows != 3:
		return { "ok": false, "error": "Expected default board_rows=3, got: %d" % rows }

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
