extends Control

const PAPER := Color("f0e2c7")
const GOLD := Color("e8c47b")
const QUIET := Color("527064")
var _model: Dictionary = {}

func set_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	%Empty.visible = _model.get("relationships", []).is_empty()
	queue_redraw()

func _draw() -> void:
	if _model.is_empty():
		return
	var centre := Vector2(size.x * 0.5, 72)
	_draw_person(centre, str(_model.get("name", "Echo")), GOLD, 18)
	var relations: Array = _model.get("relationships", [])
	for index: int in range(relations.size()):
		var relation: Dictionary = relations[index]
		var x: float = 42.0 + float(index % 3) * maxf(90.0, (size.x - 84.0) / 2.0)
		var y: float = 176.0 + float(index / 3) * 82.0
		var point := Vector2(clampf(x, 70.0, size.x - 70.0), y)
		var tier: int = clampi(int(relation.get("tier", 0)), 0, 10)
		var line_color: Color = GOLD.lerp(QUIET, 1.0 - float(tier) / 10.0)
		draw_line(centre + Vector2(0, 22), point - Vector2(0, 22), line_color, 2.0 + float(tier) * 0.35, true)
		_draw_person(point, str(relation.get("name", "Echo")), line_color, 13)
		var pennant: String = str(relation.get("impression", ""))
		if not pennant.is_empty():
			var font := get_theme_default_font()
			draw_string(font, point + Vector2(-55, -28), pennant, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PAPER)

func _draw_person(point: Vector2, label: String, color: Color, radius: float) -> void:
	draw_circle(point, radius + 4, Color("172522"))
	draw_circle(point, radius, color)
	var font := get_theme_default_font()
	draw_string(font, point + Vector2(-60, radius + 22), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, PAPER)
