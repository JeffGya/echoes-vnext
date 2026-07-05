# res://ui/screens/combat/CombatTokenLayer.gd
# GRID-002: Draws faction-coloured placeholder actor tokens on the combat board.

class_name CombatTokenLayer
extends Node2D

const CombatTokenVisualConfigScript := preload("res://ui/screens/combat/CombatTokenVisualConfig.gd")
const CombatTokenPresentationStateScript := preload("res://ui/screens/combat/CombatTokenPresentationState.gd")
const FONT_SIZE: int = 14

const FACTION_COLORS: Dictionary = {
	"echo":      Color(0.20, 0.45, 0.90),
	"enemy":     Color(0.90, 0.20, 0.20),
	"structure": Color(0.50, 0.50, 0.50),
	"npc":       Color(0.20, 0.70, 0.35),
}

@export var visual_config = CombatTokenVisualConfigScript.new()

var _tokens: Array[Dictionary] = []
var _active_actor_id: String = ""
var _presentation_state = CombatTokenPresentationStateScript.new()


func _ready() -> void:
	if visual_config == null:
		visual_config = CombatTokenVisualConfigScript.new()


func apply_snapshot(tokens: Array[Dictionary], active_actor_id: String = "", last_actor_action: Dictionary = {}) -> Dictionary:
	if visual_config == null:
		visual_config = CombatTokenVisualConfigScript.new()

	_tokens = _normalize_tokens(tokens)
	_active_actor_id = active_actor_id
	var telegraph_event: Dictionary = _presentation_state.apply_snapshot(
		_tokens,
		last_actor_action,
		visual_config.telegraph_lead_time
	)
	queue_redraw()
	return telegraph_event


## Raw fear/morale are intentionally absent from player-facing combat snapshots.
## Keep the debug command callable, but do not fabricate diagnostic defaults.
func set_emotion_debug(_enabled: bool) -> void:
	pass


func clear_tokens() -> void:
	_tokens = []
	_active_actor_id = ""
	queue_redraw()


func reset_presentation() -> void:
	clear_tokens()
	_presentation_state.reset()


func _process(delta: float) -> void:
	if _presentation_state.advance(delta):
		queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font

	for tok in _tokens:
		var actor_id: String = str(tok.get("actor_id", ""))
		var is_structure: bool = bool(tok.get("is_structure", false))
		var extent: float = _token_extent(tok)
		var pos: Vector2 = _presentation_state.get_display_position(actor_id, tok.get("draw_pos", Vector2.ZERO))
		var fill_color: Color = _faction_color(str(tok.get("faction", "")))
		var hp_ratio: float = clampf(float(tok.get("hp_ratio", 1.0)), 0.0, 1.0)

		if not is_structure:
			draw_ellipse(
				pos + visual_config.shadow_offset,
				visual_config.shadow_size.x * 0.5,
				visual_config.shadow_size.y * 0.5,
				visual_config.shadow_color
			)
			draw_circle(pos, extent, fill_color)
			draw_arc(pos, extent, 0.0, TAU, 32, Color(0, 0, 0, 0.7), 2.0, true)
		else:
			draw_rect(
				Rect2(
					pos - Vector2(extent, extent),
					Vector2(extent * 2.0, extent * 2.0)
				),
				fill_color
			)

		draw_string(
			font,
			Vector2(pos.x - extent, pos.y + FONT_SIZE * 0.35),
			str(tok.get("label", "??")),
			HORIZONTAL_ALIGNMENT_CENTER,
			extent * 2.0,
			FONT_SIZE,
			Color.WHITE
		)

		if not _active_actor_id.is_empty() and actor_id == _active_actor_id:
			draw_arc(
				pos,
				extent + visual_config.active_ring_padding,
				0.0,
				TAU,
				32,
				visual_config.active_ring_color,
				visual_config.active_ring_width,
				true
			)

		# V2-STAGE-004: suppress HP bar for the invulnerable RECOVER relic.
		# The destructible PROTECT totem keeps its HP bar (is_objective_relic is false for it).
		var is_objective_relic: bool = bool(tok.get("is_objective_relic", false))
		if not is_objective_relic:
			var bar_w: float = extent * 2.0
			var bar_x: float = pos.x - extent
			var bar_y: float = pos.y - extent - visual_config.hp_bar_offset_y
			draw_rect(
				Rect2(bar_x, bar_y, bar_w, visual_config.hp_bar_height),
				visual_config.hp_bar_background_color
			)
			if hp_ratio > 0.0:
				draw_rect(
					Rect2(bar_x, bar_y, bar_w * hp_ratio, visual_config.hp_bar_height),
					_hp_color(hp_ratio)
				)

		# V2-STAGE-004 P3b: Quarry gets a gold diamond badge so it's immediately identifiable.
		if bool(tok.get("is_quarry", false)):
			var badge_size: float = visual_config.token_radius * 0.55
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0.0, -badge_size),
				pos + Vector2(badge_size, 0.0),
				pos + Vector2(0.0, badge_size),
				pos + Vector2(-badge_size, 0.0),
			]), Color(1.0, 0.7, 0.0, 0.9))

		# V2-STAGE-004 P3c: GUIDE_SPIRIT gets a soft radiant gold halo — a sacred nimbus
		# ringing the token — so the escorted spirit reads distinctly from party echoes
		# (blue circles) and enemies. Deliberately NOT the quarry's solid diamond: a ring,
		# not a filled shape. Draws over both the structure square and the joined echo circle.
		if bool(tok.get("is_spirit", false)):
			var halo_r: float = extent + visual_config.spirit_halo_padding
			# Faint filled glow disc behind the token for presence at small sizes.
			draw_circle(pos, halo_r, visual_config.spirit_halo_inner_color)
			# Two concentric gold rings form the nimbus (bright inner, softer outer).
			draw_arc(pos, halo_r, 0.0, TAU, 40,
				visual_config.spirit_halo_color, visual_config.spirit_halo_width, true)
			draw_arc(pos, halo_r + visual_config.spirit_halo_width + 1.5, 0.0, TAU, 40,
				Color(visual_config.spirit_halo_color.r, visual_config.spirit_halo_color.g,
					visual_config.spirit_halo_color.b, visual_config.spirit_halo_color.a * 0.45),
				visual_config.spirit_halo_width * 0.7, true)

		var damage_text: String = str(tok.get("damage_text", ""))
		if not damage_text.is_empty():
			draw_string(
				font,
				Vector2(pos.x - extent, pos.y - extent - 16.0),
				damage_text,
				HORIZONTAL_ALIGNMENT_CENTER,
				extent * 2.0,
				FONT_SIZE,
				Color.RED
			)

func _normalize_tokens(tokens: Array[Dictionary]) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for token in tokens:
		var norm: Dictionary = token.duplicate(true)
		norm["draw_pos"] = _draw_pos(norm)
		norm["move_duration"] = max(float(norm.get("move_duration", visual_config.move_duration)), 0.001)
		normalized.append(norm)
	return normalized


func _draw_pos(token: Dictionary) -> Vector2:
	var cell_pos: Vector2 = token.get("cell_pos", Vector2.ZERO)
	if bool(token.get("is_structure", false)):
		return cell_pos
	return cell_pos + Vector2(0.0, visual_config.feet_offset_y)


func _token_extent(token: Dictionary) -> float:
	if bool(token.get("is_structure", false)):
		return visual_config.structure_half_size
	return visual_config.token_radius


func _faction_color(faction: String) -> Color:
	return FACTION_COLORS.get(faction, Color.WHITE)


func _hp_color(hp_ratio: float) -> Color:
	if hp_ratio > 0.5:
		return Color.GREEN
	if hp_ratio > 0.25:
		return Color.YELLOW
	return Color.RED
