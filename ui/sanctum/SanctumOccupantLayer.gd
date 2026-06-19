extends Node2D

class_name SanctumOccupantLayer

const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")

# Echoes only. Circle tokens matching combat board style.
# Fill color is driven by the canonical emotional_status supplied per Echo.

const COLOR_OUTLINE      := Color("#D4AF37")          # Akan Gold
const COLOR_NAME         := Color("#F5E6D3")          # cream
const COLOR_SHADOW       := Color(0.0, 0.0, 0.0, 0.28)
const COLOR_FEATURE_GLOW := Color(0.957, 0.902, 0.729, 0.2)
const COLOR_FEATURE_RING := Color(0.831, 0.686, 0.216, 0.9)

const ECHO_RADIUS := 14.0
const FEATURE_RADIUS := 18.0
const SHADOW_OFFSET := Vector2(0.0, 10.0)
const TOKEN_OFFSET  := Vector2(0.0, -6.0)

var _occupants: Array = []
var _featured_id: String = ""


func set_occupants(occupants: Array) -> void:
	_occupants = occupants.duplicate(true)
	queue_redraw()


func set_featured_occupant(occupant_id: String) -> void:
	_featured_id = occupant_id
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for occupant_v in _occupants:
		if not (occupant_v is Dictionary):
			continue
		var occupant: Dictionary = occupant_v

		# Skip non-echo kinds — buildings/ase_flame drawn by SanctumBuildingLayer
		if str(occupant.get("kind", "echo")) != "echo":
			continue

		var pos_v: Variant = occupant.get("position", Vector2.ZERO)
		var pos: Vector2 = pos_v if pos_v is Vector2 else Vector2.ZERO
		var echo_id := str(occupant.get("id", ""))
		var name    := str(occupant.get("name", ""))
		var emotional_status := str(occupant.get("emotional_status", ""))
		var is_featured := (not _featured_id.is_empty() and echo_id == _featured_id)

		var center := pos + TOKEN_OFFSET
		var fill_col := fill_for_emotional_status(emotional_status)

		# Featured glow ring (drawn first, behind token)
		if is_featured:
			draw_circle(center, FEATURE_RADIUS + 4.0, COLOR_FEATURE_GLOW)
			draw_arc(center, FEATURE_RADIUS, 0.0, TAU, 40, COLOR_FEATURE_RING, 2.0, true)

		# Shadow ellipse
		draw_ellipse(pos + SHADOW_OFFSET, 10.0, 4.0, COLOR_SHADOW)

		# Filled circle with emotion color
		draw_circle(center, ECHO_RADIUS, fill_col)

		# Gold arc outline
		draw_arc(center, ECHO_RADIUS, 0.0, TAU, 40, COLOR_OUTLINE, 1.5, true)

		# Name label below token
		if not name.is_empty():
			draw_string(
				font,
				pos + Vector2(-40.0, 22.0),
				name,
				HORIZONTAL_ALIGNMENT_CENTER,
				80.0,
				10,
				COLOR_NAME
			)


static func fill_for_emotional_status(status: String) -> Color:
	var fill := EmotionPresentation.color(status)
	fill.a = 0.9
	return fill
