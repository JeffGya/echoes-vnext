# res://core/grid/GridService.gd
# Pure static service for grid configuration and spatial helpers.
# GRID-001: Board configuration — board_cols and board_rows owned here.
#
# Rules:
# - No RNG, no OS time. All methods are pure and deterministic.
# - Board config is immutable mid-combat; read from balance.json data.grid block.
# - GridService is the single source of truth for all grid math.
# - Caller logs LOG_COMBAT_INIT with the dimensions returned here.
#
# Future stories extend this file:
#   GRID-002 — assign_grid_pos(), spawn positions
#   GRID-003 — place_actors() with seeded RNG
#   GRID-004 — manhattan_distance()
#   GRID-005 — move_toward()

class_name GridService
extends RefCounted


# -------------------------
# Board configuration
# -------------------------

## Returns the number of columns on the combat board.
## Reads from balance.json data.grid.board_cols; falls back to 6.
static func get_board_cols(cfg: Dictionary = {}) -> int:
	return int(cfg.get("board_cols", 6))


## Returns the number of rows on the combat board.
## Reads from balance.json data.grid.board_rows; falls back to 3.
static func get_board_rows(cfg: Dictionary = {}) -> int:
	return int(cfg.get("board_rows", 3))


## Returns the full board config dict { board_cols, board_rows }.
## Convenience wrapper — callers can pass this to snapshot builders.
static func get_board_config(cfg: Dictionary = {}) -> Dictionary:
	return {
		"board_cols": get_board_cols(cfg),
		"board_rows": get_board_rows(cfg),
	}


## Returns true if the given grid_pos { col, row } is inside the board bounds.
static func is_valid_pos(pos: Dictionary, cfg: Dictionary = {}) -> bool:
	var col: int = int(pos.get("col", -1))
	var row: int = int(pos.get("row", -1))
	return col >= 0 and col < get_board_cols(cfg) \
		and row >= 0 and row < get_board_rows(cfg)
