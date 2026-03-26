# res://ui/screens/combat/CombatDistanceLayer.gd
# GRID-004: Debug overlay that draws per-cell Manhattan distance labels on the combat board.
#
# Developer-facing only — never shown to the player.
# Shows distances radiating outward from actors[0] (first actor in snapshot list).
# The reference actor will be replaced by the "active actor" once COMBAT stories
# introduce turn order.
#
# Mirrors the CombatTokenLayer pattern:
# - Stores data, calls queue_redraw(), renders via _draw().
# - CombatBoardScreen syncs _distance_layer.position = _board.position after centering.

class_name CombatDistanceLayer
extends Node2D

const FONT_SIZE: int = 10
const LABEL_COLOR: Color = Color(1.0, 1.0, 0.2, 0.85)  # yellow, semi-opaque

# Each entry: { "pixel_pos": Vector2, "distance": int }
var _entries: Array = []


## Computes Manhattan distance from ref_actor to every cell on the board
## and stores pixel positions for _draw(). Triggers a redraw.
##
## ref_actor  — the actor whose grid_pos is used as the distance origin (actors[0]).
## board_ref  — the TileMapLayer; used to convert grid cells to pixel positions.
## board_cfg  — snapshot data dict containing board_cols and board_rows.
func update_distances(ref_actor: Dictionary, board_ref: TileMapLayer,
		board_cfg: Dictionary) -> void:
	_entries.clear()
	var ref_pos: Dictionary = ref_actor.get("grid_pos", { "col": 0, "row": 0 })
	var cols: int = GridService.get_board_cols(board_cfg)
	var rows: int = GridService.get_board_rows(board_cfg)
	for col in range(cols):
		for row in range(rows):
			var cell_pos: Dictionary = { "col": col, "row": row }
			var dist: int = GridService.manhattan_distance(ref_pos, cell_pos)
			var pixel: Vector2 = board_ref.map_to_local(Vector2i(col, row))
			_entries.append({ "pixel_pos": pixel, "distance": dist })
	queue_redraw()


## Clears all distance labels and triggers a redraw.
func clear_distances() -> void:
	_entries.clear()
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for entry in _entries:
		var pos: Vector2  = entry["pixel_pos"]
		var dist_str: String = str(entry["distance"])
		# Centre the label on the cell.
		var label_width: float = float(FONT_SIZE) * dist_str.length() * 0.6
		draw_string(
			font,
			Vector2(pos.x - label_width * 0.5, pos.y + FONT_SIZE * 0.35),
			dist_str,
			HORIZONTAL_ALIGNMENT_CENTER,
			label_width * 2.0,
			FONT_SIZE,
			LABEL_COLOR
		)
