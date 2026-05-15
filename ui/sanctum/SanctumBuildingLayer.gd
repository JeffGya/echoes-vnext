extends Node2D

class_name SanctumBuildingLayer

# Draws Ase Flame marker and institution markers (established + candidate).
# Pixel positions (px, py) are pre-computed by SanctumSpatialRenderer before
# calling set_buildings() — this layer never reads from TileMapLayer directly.

var _buildings: Array = []

# --- Colors ---
const COLOR_ASE_FLAME_FILL   := Color(0.85, 0.62, 0.18, 0.35)
const COLOR_ASE_FLAME_RING   := Color(0.831, 0.686, 0.216, 1.0)   # #D4AF37
const COLOR_ASE_FLAME_RAY    := Color(0.831, 0.686, 0.216, 0.70)
const COLOR_ASE_FLAME_LABEL  := Color(0.784, 0.722, 0.588, 1.0)   # #C8B896

const COLOR_CANDIDATE_FILL   := Color(0.102, 0.102, 0.180, 0.25)
const COLOR_CANDIDATE_BORDER := Color(0.659, 0.525, 0.353, 0.40)  # #A8865A 40%
const COLOR_CANDIDATE_LABEL  := Color(0.416, 0.353, 0.290, 1.0)   # #6A5A4A
const COLOR_CANDIDATE_PLUS   := Color(0.831, 0.686, 0.216, 0.50)

const COLOR_INST_HEALTHY_FILL    := Color(0.102, 0.169, 0.133, 1.0)  # #1A2B22
const COLOR_INST_HEALTHY_BORDER  := Color(0.831, 0.686, 0.216, 1.0)  # #D4AF37
const COLOR_INST_STRAINED_FILL   := COLOR_INST_HEALTHY_FILL
const COLOR_INST_STRAINED_BORDER := Color(0.784, 0.475, 0.255, 1.0)  # #C87941
const COLOR_INST_NEGLECTED_FILL  := Color(0.102, 0.133, 0.094, 1.0)  # #1A2218
const COLOR_INST_NEGLECTED_BORDER:= Color(0.353, 0.353, 0.416, 1.0)  # #5A5A6A
const COLOR_INST_LABEL           := Color(0.784, 0.722, 0.588, 1.0)  # #C8B896
const COLOR_INST_DOT_HEALTHY     := Color(0.831, 0.686, 0.216, 1.0)
const COLOR_INST_DOT_STRAINED    := Color(0.784, 0.475, 0.255, 1.0)
const COLOR_INST_DOT_NEGLECTED   := Color(0.353, 0.353, 0.416, 1.0)


func set_buildings(occupants: Array) -> void:
	_buildings = []
	for o_v in occupants:
		if not (o_v is Dictionary):
			continue
		var o: Dictionary = o_v
		var kind := str(o.get("kind", ""))
		if kind in ["ase_flame", "institution"]:
			_buildings.append(o)
	queue_redraw()


func _draw() -> void:
	for b_v in _buildings:
		if not (b_v is Dictionary):
			continue
		var b: Dictionary = b_v
		var pos_v: Variant = b.get("position", Vector2.ZERO)
		var pos: Vector2 = pos_v if pos_v is Vector2 else Vector2.ZERO
		match str(b.get("kind", "")):
			"ase_flame":   _draw_ase_flame(pos)
			"institution": _draw_institution_marker(b, pos)


func _draw_ase_flame(pos: Vector2) -> void:
	var center := pos + Vector2(0, -6)

	# Base amber fill
	draw_circle(center, 14.0, COLOR_ASE_FLAME_FILL)

	# Outer gold ring
	draw_arc(center, 18.0, 0.0, TAU, 48, COLOR_ASE_FLAME_RING, 2.0, true)

	# 4 upward rays fanning from ring top
	var ray_angles := [-60.0, -30.0, 0.0, 30.0, 60.0]
	for deg in ray_angles:
		var rad := deg_to_rad(deg - 90.0)
		var start := center + Vector2(cos(rad), sin(rad)) * 18.0
		var end   := center + Vector2(cos(rad), sin(rad)) * 26.0
		draw_line(start, end, COLOR_ASE_FLAME_RAY, 1.5, true)

	# Label
	draw_string(
		ThemeDB.fallback_font,
		pos + Vector2(-20.0, 18.0),
		"Ase Flame",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1, 10,
		COLOR_ASE_FLAME_LABEL
	)


func _draw_institution_marker(b: Dictionary, pos: Vector2) -> void:
	var is_unlocked := bool(b.get("is_unlocked", false))
	var condition   := str(b.get("condition", "neglected"))
	var name_str    := str(b.get("name", ""))

	var rect_size := Vector2(28.0, 18.0)
	var top_left  := pos + Vector2(-rect_size.x * 0.5, -rect_size.y - 6.0)
	var rect      := Rect2(top_left, rect_size)

	if is_unlocked:
		var fill_col: Color
		var border_col: Color
		var dot_col: Color
		match condition:
			"healthy":
				fill_col   = COLOR_INST_HEALTHY_FILL
				border_col = COLOR_INST_HEALTHY_BORDER
				dot_col    = COLOR_INST_DOT_HEALTHY
			"strained":
				fill_col   = COLOR_INST_STRAINED_FILL
				border_col = COLOR_INST_STRAINED_BORDER
				dot_col    = COLOR_INST_DOT_STRAINED
			_:
				fill_col   = COLOR_INST_NEGLECTED_FILL
				border_col = COLOR_INST_NEGLECTED_BORDER
				dot_col    = COLOR_INST_DOT_NEGLECTED

		draw_rect(rect, fill_col)
		draw_rect(rect, border_col, false, 2.0)

		# Condition dot top-right
		draw_circle(top_left + Vector2(rect_size.x - 4.0, 4.0), 3.0, dot_col)

		# Label
		draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(-14.0, 14.0),
			name_str,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 10,
			COLOR_INST_LABEL
		)
	else:
		# Candidate marker — hollow dim rect with "+" hint
		draw_rect(rect, COLOR_CANDIDATE_FILL)
		draw_rect(rect, COLOR_CANDIDATE_BORDER, false, 1.5)

		var center := rect.get_center()
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-3.0, 4.0),
			"+",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 10,
			COLOR_CANDIDATE_PLUS
		)

		draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(-14.0, 14.0),
			name_str,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 10,
			COLOR_CANDIDATE_LABEL
		)
