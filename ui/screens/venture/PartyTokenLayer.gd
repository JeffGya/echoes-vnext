# res://ui/screens/venture/PartyTokenLayer.gd
# Single-token Node2D drawn via _draw() with smooth lerp animation.
# Visual style and animation pattern match CombatTokenLayer / CombatTokenPresentationState.
#
# This layer is a child of BoardRoot, so it draws in board space and moves cell by cell while the
# camera follows it. In preview BoardRoot is scaled to fit; set_token_scale keeps the token at its
# screen size there. The traveled-path trail lives in GhostFootprintLayer.

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
var _token_scale := 1.0


## Multiplies the drawn size of the token. 1.0 in explore; 1 / BoardRoot scale in preview.
func set_token_scale(value: float) -> void:
	_token_scale = value
	queue_redraw()


## Where the token is drawn now, in this layer's space.
func display_position() -> Vector2:
	return _pstate.get_display_position(ACTOR_ID, Vector2.ZERO)


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
func set_party_position(draw_pos: Vector2, duration: float = MOVE_DURATION) -> void:
	var token: Array[Dictionary] = [{
		"actor_id":      ACTOR_ID,
		"draw_pos":      draw_pos,
		"grid_pos":      { "col": 0, "row": 0 },
		"move_duration": duration,
	}]
	_pstate.apply_snapshot(token, {}, 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	if _pstate.advance(delta):
		queue_redraw()


func _draw() -> void:
	var pos: Vector2 = display_position()
	draw_set_transform(pos, 0.0, Vector2(_token_scale, _token_scale))
	# Shadow
	draw_circle(SHADOW_OFFSET, TOKEN_RADIUS * 0.85, SHADOW_COLOR)
	# Body
	draw_circle(Vector2.ZERO, TOKEN_RADIUS, TOKEN_COLOR)
	# Outline
	draw_arc(Vector2.ZERO, TOKEN_RADIUS, 0.0, TAU, 32, OUTLINE_COLOR, 2.0, true)
	# Label
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-TOKEN_RADIUS, FONT_SIZE * 0.35),
		"P",
		HORIZONTAL_ALIGNMENT_CENTER,
		TOKEN_RADIUS * 2.0,
		FONT_SIZE,
		LABEL_COLOR
	)
