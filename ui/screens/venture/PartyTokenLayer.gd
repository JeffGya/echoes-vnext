# res://ui/screens/venture/PartyTokenLayer.gd
# Single-token Node2D drawn via _draw() with smooth lerp animation.
# Visual style and animation pattern match CombatTokenLayer / CombatTokenPresentationState.
# Must be a child of the Board TileMapLayer so its draw coordinates are in board-local space.

extends Node2D

const CombatTokenPresentationStateScript := preload("res://ui/screens/combat/CombatTokenPresentationState.gd")

const ACTOR_ID      := "party"
const TOKEN_RADIUS  := 18.0
const TOKEN_COLOR   := Color(0.20, 0.45, 0.90)   # echo-faction blue — matches combat echo tokens
const SHADOW_OFFSET := Vector2(3.0, 5.0)
const SHADOW_COLOR  := Color(0.0, 0.0, 0.0, 0.38)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.65)
const LABEL_COLOR   := Color.WHITE
const MOVE_DURATION := 0.45
const FONT_SIZE     := 13

var _pstate = CombatTokenPresentationStateScript.new()


## Instantly place the token without animation (used on screen entry / preview mode).
func init_position(draw_pos: Vector2) -> void:
	_pstate.reset()
	var token: Array[Dictionary] = [{
		"actor_id":      ACTOR_ID,
		"draw_pos":      draw_pos,
		"grid_pos":      { "col": 0, "row": 0 },
		"move_duration": 0.001,
	}]
	_pstate.apply_snapshot(token, {}, 0.0)
	queue_redraw()


## Animate the token from its current display position to draw_pos.
func set_party_position(draw_pos: Vector2) -> void:
	var token: Array[Dictionary] = [{
		"actor_id":      ACTOR_ID,
		"draw_pos":      draw_pos,
		"grid_pos":      { "col": 0, "row": 0 },
		"move_duration": MOVE_DURATION,
	}]
	_pstate.apply_snapshot(token, {}, 0.0)


func _process(delta: float) -> void:
	if _pstate.advance(delta):
		queue_redraw()


func _draw() -> void:
	var pos: Vector2 = _pstate.get_display_position(ACTOR_ID, Vector2.ZERO)
	# Shadow
	draw_circle(pos + SHADOW_OFFSET, TOKEN_RADIUS * 0.85, SHADOW_COLOR)
	# Body
	draw_circle(pos, TOKEN_RADIUS, TOKEN_COLOR)
	# Outline
	draw_arc(pos, TOKEN_RADIUS, 0.0, TAU, 32, OUTLINE_COLOR, 2.0, true)
	# Label
	draw_string(
		ThemeDB.fallback_font,
		Vector2(pos.x - TOKEN_RADIUS, pos.y + FONT_SIZE * 0.35),
		"P",
		HORIZONTAL_ALIGNMENT_CENTER,
		TOKEN_RADIUS * 2.0,
		FONT_SIZE,
		LABEL_COLOR
	)
