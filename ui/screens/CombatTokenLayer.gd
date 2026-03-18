# res://ui/screens/CombatTokenLayer.gd
# GRID-002: Draws faction-coloured placeholder actor tokens on the combat board.
#
# This Node2D is a child of CombatBoardScreen and shares the board's coordinate
# space — CombatBoardScreen sets _token_layer.position = _board.position after
# centering, so map_to_local() positions passed in are already in the right space.
#
# _draw() is called by Godot whenever queue_redraw() is triggered.
# Each token is a coloured circle (or gray rounded square for structures)
# with a 2-letter name abbreviation centred inside.
#
# Token design is stable across all GRID stories; replaced by actor art
# when art assets are ready (COMBAT phase or later).

class_name CombatTokenLayer
extends Node2D

# Token geometry
const TOKEN_RADIUS: float = 22.0   # fits inside 64px narrow face of isometric cell
const TOKEN_HALF: float   = 22.0   # half-extent for square (structure) tokens
const FONT_SIZE: int      = 14

# Faction → fill colour mapping.
# echo=blue, enemy=red, structure=gray, npc/ally=green.
# White is the fallback for unknown factions.
const FACTION_COLORS: Dictionary = {
	"echo":      Color(0.20, 0.45, 0.90),
	"enemy":     Color(0.90, 0.20, 0.20),
	"structure": Color(0.50, 0.50, 0.50),
	"npc":       Color(0.20, 0.70, 0.35),
}

# Internal token list.
# Each entry: { pos: Vector2, color: Color, shape: String, label: String,
#               hp_ratio: float, hp_color: Color, damage_text: String, actor_id: String }
# hp_ratio/hp_color/damage_text added in COMBAT-003 for HP bars and damage floats.
# actor_id + active_actor_id added in COMBAT-SEQ for the yellow active-turn ring.
var _tokens: Array[Dictionary] = []
# COMBAT-SEQ: id of the actor whose turn it is; "" between turns / rounds.
var _active_actor_id: String = ""


## Replace the token list and trigger a redraw.
## active_actor_id: the actor currently acting — draws a yellow ring on their token.
## Call this from CombatBoardScreen._render() after computing cell positions.
func update_tokens(tokens: Array[Dictionary], active_actor_id: String = "") -> void:
	_tokens = tokens
	_active_actor_id = active_actor_id
	queue_redraw()


## Clear all tokens and trigger a redraw.
## Call this from CombatBoardScreen._clear().
func clear_tokens() -> void:
	_tokens = []
	_active_actor_id = ""
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font

	for tok in _tokens:
		var pos: Vector2   = tok["pos"]
		var color: Color   = tok["color"]
		var shape: String  = tok.get("shape", "circle")
		var label: String  = tok.get("label", "??")

		# Draw shape
		if shape == "circle":
			draw_circle(pos, TOKEN_RADIUS, color)
		else:
			# Rounded square for structure actors
			draw_rect(
				Rect2(pos - Vector2(TOKEN_HALF, TOKEN_HALF),
					  Vector2(TOKEN_HALF * 2.0, TOKEN_HALF * 2.0)),
				color
			)

		# Draw 2-letter abbreviation centred on the token.
		# HORIZONTAL_ALIGNMENT_CENTER requires x = left edge of the bounding box.
		draw_string(
			font,
			Vector2(pos.x - TOKEN_RADIUS, pos.y + FONT_SIZE * 0.35),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			TOKEN_RADIUS * 2.0,
			FONT_SIZE,
			Color.WHITE
		)

		# COMBAT-SEQ: Yellow ring around the active actor's token while their turn plays out.
		if not _active_actor_id.is_empty() and tok.get("actor_id", "") == _active_actor_id:
			draw_arc(pos, TOKEN_RADIUS + 4.0, 0.0, TAU, 32, Color.YELLOW, 2.5)

		# COMBAT-003: HP bar — 44×4 px strip below the token.
		var bar_w: float  = TOKEN_RADIUS * 2.0
		var bar_y: float  = pos.y + TOKEN_RADIUS + 3.0
		var bar_x: float  = pos.x - TOKEN_RADIUS
		var hp_ratio: float = clampf(tok.get("hp_ratio", 1.0), 0.0, 1.0)
		var hp_color: Color = tok.get("hp_color", Color.GREEN)
		draw_rect(Rect2(bar_x, bar_y, bar_w, 4.0), Color(0.15, 0.15, 0.15))
		if hp_ratio > 0.0:
			draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, 4.0), hp_color)

		# COMBAT-003: Damage float — red text above the token.
		var dmg_text: String = tok.get("damage_text", "")
		if not dmg_text.is_empty():
			draw_string(
				font,
				Vector2(pos.x - TOKEN_RADIUS, pos.y - TOKEN_RADIUS - 2.0),
				dmg_text,
				HORIZONTAL_ALIGNMENT_CENTER,
				TOKEN_RADIUS * 2.0,
				FONT_SIZE,
				Color.RED
			)
