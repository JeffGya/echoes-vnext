extends Node2D

class_name SanctumOccupantLayer

const SILHOUETTE_FILL := Color("#2D1F1A")
const SILHOUETTE_EDGE := Color("#D4AF37")
const NAME_COLOR := Color("#F5E6D3")
const FEATURE_GLOW := Color(0.95686275, 0.9019608, 0.7294118, 0.2)
const FEATURE_RING := Color(0.83137256, 0.6862745, 0.21568628, 0.9)

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
		var pos_v: Variant = occupant.get("position", Vector2.ZERO)
		var pos: Vector2 = pos_v if pos_v is Vector2 else Vector2.ZERO
		var name := str(occupant.get("name", ""))
		var occupant_id := str(occupant.get("id", ""))

		if not _featured_id.is_empty() and occupant_id == _featured_id:
			draw_circle(pos + Vector2(0.0, -6.0), 28.0, FEATURE_GLOW)
			draw_arc(pos + Vector2(0.0, -6.0), 28.0, 0.0, TAU, 40, FEATURE_RING, 2.0, true)

		draw_ellipse(pos + Vector2(-18.0, 10.0), 18.0, 8.0, Color(0, 0, 0, 0.28))
		draw_circle(pos + Vector2(0.0, -22.0), 12.0, SILHOUETTE_FILL)
		draw_arc(pos + Vector2(0.0, -22.0), 12.0, 0.0, TAU, 32, SILHOUETTE_EDGE, 1.5, true)
		draw_ellipse(pos + Vector2(-14.0, -10.0), 14.0, 22.0, SILHOUETTE_FILL)
		draw_arc(pos + Vector2(0.0, 12.0), 18.0, PI, TAU, 24, SILHOUETTE_EDGE, 1.25, true)

		if not name.is_empty():
			draw_string(
				font,
				pos + Vector2(-54.0, 44.0),
				name,
				HORIZONTAL_ALIGNMENT_CENTER,
				108.0,
				12,
				NAME_COLOR
			)
