class_name RadarStatChart
extends Control

const AXIS_KEYS := ["atk", "def", "int", "agi", "cha", "speed"]
const AXIS_LABELS := {
	"atk": "ATK",
	"def": "DEF",
	"int": "INT",
	"agi": "AGI",
	"cha": "CHA",
	"speed": "SPD",
}
const RING_COUNT: int = 4
const TRANSITION_DURATION: float = 0.18
const GRID_COLOR: Color = Color(0.40, 0.29, 0.18, 0.34)
const LABEL_COLOR: Color = Color(0.24, 0.16, 0.09, 0.92)
const PRIMARY_FILL: Color = Color(0.82, 0.67, 0.18, 0.28)
const PRIMARY_LINE: Color = Color(0.73, 0.52, 0.10, 0.96)
const COMP_FILL: Color = Color(0.46, 0.56, 0.43, 0.18)
const COMP_LINE: Color = Color(0.33, 0.43, 0.31, 0.86)

var _axis_maxima: Dictionary = {}
var _display_primary: Dictionary = {}
var _display_comparison: Dictionary = {}
var _anim_from_primary: Dictionary = {}
var _anim_to_primary: Dictionary = {}
var _anim_from_comparison: Dictionary = {}
var _anim_to_comparison: Dictionary = {}
var _comparison_target_visible: bool = false
var _show_comparison_display: bool = false
var _transition_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260, 260)


func set_chart_data(
	primary_stats: Dictionary,
	comparison_stats: Dictionary,
	axis_maxima: Dictionary,
	show_comparison: bool
) -> void:
	_axis_maxima = axis_maxima.duplicate(true)

	var normalized_primary: Dictionary = normalize_stats(primary_stats, _axis_maxima)
	var normalized_comparison: Dictionary = normalize_stats(comparison_stats, _axis_maxima)
	var zero_values: Dictionary = _zero_values()

	if _display_primary.is_empty():
		_display_primary = normalized_primary.duplicate(true)
	if _display_comparison.is_empty():
		_display_comparison = zero_values.duplicate(true)

	_anim_from_primary = _display_primary.duplicate(true)
	_anim_to_primary = normalized_primary.duplicate(true)
	_anim_from_comparison = _display_comparison.duplicate(true)
	_anim_to_comparison = normalized_comparison.duplicate(true) if show_comparison and not comparison_stats.is_empty() else zero_values

	_comparison_target_visible = show_comparison and not comparison_stats.is_empty()
	_show_comparison_display = _show_comparison_display or _comparison_target_visible or _has_non_zero_values(_display_comparison)
	_start_transition()


func clear_chart() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	_axis_maxima.clear()
	_display_primary.clear()
	_display_comparison.clear()
	_anim_from_primary.clear()
	_anim_to_primary.clear()
	_anim_from_comparison.clear()
	_anim_to_comparison.clear()
	_comparison_target_visible = false
	_show_comparison_display = false
	queue_redraw()


static func normalize_stats(stats: Dictionary, axis_maxima: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key in AXIS_KEYS:
		var raw_value: float = float(stats.get(key, 0.0))
		var axis_max: float = max(1.0, float(axis_maxima.get(key, 0.0)))
		normalized[key] = clampf(raw_value / axis_max, 0.0, 1.0)
	return normalized


func _start_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.tween_method(_apply_transition, 0.0, 1.0, TRANSITION_DURATION)
	_transition_tween.finished.connect(_finish_transition)


func _finish_transition() -> void:
	_display_primary = _anim_to_primary.duplicate(true)
	_display_comparison = _anim_to_comparison.duplicate(true)
	_show_comparison_display = _comparison_target_visible
	_transition_tween = null
	queue_redraw()


func _apply_transition(weight: float) -> void:
	_display_primary = _lerp_values(_anim_from_primary, _anim_to_primary, weight)
	_display_comparison = _lerp_values(_anim_from_comparison, _anim_to_comparison, weight)
	_show_comparison_display = _comparison_target_visible or _has_non_zero_values(_display_comparison)
	queue_redraw()


func _draw() -> void:
	var chart_center: Vector2 = Vector2(size.x * 0.5, size.y * 0.56)
	var radius: float = max(24.0, min(size.x, size.y) * 0.31)
	var font: Font = ThemeDB.fallback_font

	_draw_grid(chart_center, radius)
	_draw_axis_labels(chart_center, radius, font)

	if _show_comparison_display and _has_non_zero_values(_display_comparison):
		_draw_shape(chart_center, radius, _display_comparison, COMP_FILL, COMP_LINE)
	if not _display_primary.is_empty():
		_draw_shape(chart_center, radius, _display_primary, PRIMARY_FILL, PRIMARY_LINE)


func _draw_grid(chart_center: Vector2, radius: float) -> void:
	var axis_count: int = AXIS_KEYS.size()
	for ring_index in range(1, RING_COUNT + 1):
		var ratio: float = float(ring_index) / float(RING_COUNT)
		var ring_points := PackedVector2Array()
		for axis_index in range(axis_count):
			ring_points.append(_axis_point(chart_center, radius * ratio, axis_index, axis_count))
		_draw_closed_polyline(ring_points, GRID_COLOR, 1.5)

	for axis_index in range(axis_count):
		draw_line(chart_center, _axis_point(chart_center, radius, axis_index, axis_count), GRID_COLOR, 1.0)

func _draw_axis_labels(chart_center: Vector2, radius: float, font: Font) -> void:
	var axis_count: int = AXIS_KEYS.size()
	var label_radius: float = radius + 28.0
	for axis_index in range(axis_count):
		var point := _axis_point(chart_center, label_radius, axis_index, axis_count)
		var label: String = str(AXIS_LABELS.get(AXIS_KEYS[axis_index], AXIS_KEYS[axis_index])).to_upper()
		var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(
			font,
			point - Vector2(label_size.x * 0.5, -label_size.y * 0.35),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14,
			LABEL_COLOR
		)


func _draw_shape(chart_center: Vector2, radius: float, values: Dictionary, fill_color: Color, line_color: Color) -> void:
	var points := PackedVector2Array()
	var axis_count: int = AXIS_KEYS.size()
	for axis_index in range(axis_count):
		var key: String = str(AXIS_KEYS[axis_index])
		var value: float = clampf(float(values.get(key, 0.0)), 0.0, 1.0)
		points.append(_axis_point(chart_center, radius * value, axis_index, axis_count))

	if points.size() < 3:
		return

	draw_colored_polygon(points, fill_color)
	_draw_closed_polyline(points, line_color, 2.5)

	for point in points:
		draw_circle(point, 3.0, line_color)


func _axis_point(chart_center: Vector2, length: float, axis_index: int, axis_count: int) -> Vector2:
	var angle: float = -PI * 0.5 + TAU * float(axis_index) / float(axis_count)
	return chart_center + Vector2.RIGHT.rotated(angle) * length


func _draw_closed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.is_empty():
		return
	for i in range(points.size()):
		var from_point: Vector2 = points[i]
		var to_point: Vector2 = points[(i + 1) % points.size()]
		draw_line(from_point, to_point, color, width)


func _lerp_values(from_values: Dictionary, to_values: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary = {}
	for key in AXIS_KEYS:
		result[key] = lerpf(float(from_values.get(key, 0.0)), float(to_values.get(key, 0.0)), weight)
	return result


func _has_non_zero_values(values: Dictionary) -> bool:
	for key in AXIS_KEYS:
		if float(values.get(key, 0.0)) > 0.001:
			return true
	return false


func _zero_values() -> Dictionary:
	var values: Dictionary = {}
	for key in AXIS_KEYS:
		values[key] = 0.0
	return values
