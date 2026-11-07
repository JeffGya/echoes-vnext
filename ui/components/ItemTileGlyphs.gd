extends Control

## The drawn inside of one item tile: placeholder hatch, kind shape, grade pips, twin notch, source leaf,
## at-risk brackets and the dashed outline of the lost state. Presentation only. The plate, bed and count
## capsule are styled nodes of ItemTile.tscn. Colours come from theme type "ItemGlyphs".
## `lost` runs 0..1: the art goes to 35 percent, the marks to 60 percent, the dashed outline appears.
## Dashed lines are used for the lost state only.

const KIND_GEAR := "gear"
const KIND_RELIC := "relic"
const KIND_CONSUMABLE := "consumable"
const KIND_MATERIAL := "material"
const _HATCH_PITCH := 6.0
const _LOST_ART_ALPHA := 0.35
const _LOST_MARK_ALPHA := 0.6

var kind := "":
	set(v):
		kind = v
		queue_redraw()
var is_stack := false:
	set(v):
		is_stack = v
		queue_redraw()
var pips := 0:
	set(v):
		pips = v
		queue_redraw()
## Twin notch shape 0..5, or -1 for none.
var mark := -1:
	set(v):
		mark = v
		queue_redraw()
## "", "held" (open leaf) or "gathered" (whole leaf).
var leaf := "":
	set(v):
		leaf = v
		queue_redraw()
var at_risk := false:
	set(v):
		at_risk = v
		queue_redraw()
## Draws only the leaf, filling the control (the at-stake mark beside a line of text). `leaf_tone` is the theme colour.
var leaf_only := false:
	set(v):
		leaf_only = v
		queue_redraw()
var leaf_tone := "ink":
	set(v):
		leaf_tone = v
		queue_redraw()
var lost := 0.0:
	set(v):
		lost = clampf(v, 0.0, 1.0)
		queue_redraw()


func _plate_rect() -> Rect2:
	var s := minf(size.x, size.y)
	if is_stack:
		return Rect2(2.0, 2.0, s - 8.0, s - 8.0)
	return Rect2(4.0, 4.0, s - 8.0, s - 8.0)


func _color(name: String, alpha: float = 1.0) -> Color:
	var c := get_theme_color(name, "ItemGlyphs")
	c.a *= alpha
	return c


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	if leaf_only:
		_draw_leaf(Vector2.ZERO, s, 1.0)
		return
	var plate := _plate_rect()
	var art_alpha := lerpf(1.0, _LOST_ART_ALPHA, lost)
	var mark_alpha := lerpf(1.0, _LOST_MARK_ALPHA, lost)
	_draw_art(plate, art_alpha, mark_alpha)
	var unit := roundf(s / 12.0)
	if not is_stack:
		_draw_pips(plate, unit, mark_alpha)
		if mark >= 0:
			_draw_notch(plate, unit * 2.0, mark_alpha)
	if not leaf.is_empty():
		_draw_leaf(Vector2(plate.position.x + 5.0, plate.position.y + 5.0), 14.0, mark_alpha)
	if at_risk and lost <= 0.0:
		_draw_brackets(s)
	if lost > 0.0:
		_dashed_outline(plate, 10.0, _color("bronze", 0.8 * lost))
		if is_stack:
			_dashed_outline(Rect2(plate.position + Vector2(4.0, 4.0), plate.size), 10.0, _color("bronze", 0.8 * lost))


func _draw_art(plate: Rect2, hatch_alpha_factor: float, shape_alpha: float) -> void:
	var a := plate.size.x * 0.625
	var center := plate.get_center()
	var art := Rect2(center - Vector2(a, a) * 0.5, Vector2(a, a))
	var bronze_hatch := _color("bronze", 0.25 * hatch_alpha_factor)
	var d := -a
	var step := _HATCH_PITCH * 1.41421356
	while d < a:
		var x0 := maxf(0.0, -d)
		var x1 := minf(a, a - d)
		if x1 > x0:
			draw_line(art.position + Vector2(x0, x0 + d), art.position + Vector2(x1, x1 + d), bronze_hatch, 1.0)
		d += step
	var bronze := _color("bronze", shape_alpha)
	match kind:
		KIND_GEAR:
			var w := a * 0.4
			var h := a * 0.8
			draw_rect(Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h)), bronze)
		KIND_RELIC:
			var w2 := a * 0.72
			var h2 := a * 0.8
			var o := center - Vector2(w2, h2) * 0.5
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(w2 * 0.5, 0.0), o + Vector2(w2, h2 * 0.25), o + Vector2(w2, h2 * 0.75),
				o + Vector2(w2 * 0.5, h2), o + Vector2(0.0, h2 * 0.75), o + Vector2(0.0, h2 * 0.25)]), bronze)
		KIND_CONSUMABLE:
			var w3 := a * 0.8
			var h3 := a * 0.7
			var o3 := center - Vector2(w3, h3) * 0.5 + Vector2(0.0, a * 0.01)
			draw_colored_polygon(PackedVector2Array([
				o3 + Vector2(w3 * 0.5, 0.0), o3 + Vector2(w3, h3), o3 + Vector2(0.0, h3)]), bronze)
		KIND_MATERIAL:
			var w4 := a * 0.7
			var h4 := a * 0.46
			var o4 := center - Vector2(w4, h4) * 0.5
			draw_rect(Rect2(o4, Vector2(w4, h4 * 0.4)), bronze)
			draw_rect(Rect2(o4 + Vector2(0.0, h4 * 0.6), Vector2(w4, h4 * 0.4)), bronze)


func _draw_pips(plate: Rect2, unit: float, alpha: float) -> void:
	var ink := _color("ink", alpha)
	var p := unit
	var gap := 3.0
	var y := plate.end.y - 6.0 - p
	for i in clampi(pips, 0, 3):
		var x := plate.position.x + 6.0 + float(i) * (p + gap)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + p * 0.5, y), Vector2(x + p, y + p * 0.5), Vector2(x + p * 0.5, y + p), Vector2(x, y + p * 0.5)]), ink)


## Six shapes tell twins apart without colour: square, corner, half disc, two bars, plus, stair.
func _draw_notch(plate: Rect2, n: float, alpha: float) -> void:
	var ink := _color("ink", alpha)
	var o := Vector2(plate.end.x - n - 5.0, plate.position.y + 5.0)
	match mark:
		0:
			draw_rect(Rect2(o, Vector2(n, n)), ink)
		1:
			draw_colored_polygon(PackedVector2Array([o, o + Vector2(n, 0.0), o + Vector2(n, n)]), ink)
		2:
			var pts := PackedVector2Array([o + Vector2(n * 0.25, 0.0)])
			for i in 9:
				var ang := -PI * 0.5 + PI * float(i) / 8.0
				pts.append(o + Vector2(n * 0.25 + n * 0.5 * cos(ang), n * 0.5 + n * 0.5 * sin(ang)))
			pts.append(o + Vector2(n * 0.25, n))
			draw_colored_polygon(pts, ink)
		3:
			draw_rect(Rect2(o, Vector2(n * 0.333, n)), ink)
			draw_rect(Rect2(o + Vector2(n * 0.667, 0.0), Vector2(n * 0.333, n)), ink)
		4:
			draw_rect(Rect2(o + Vector2(n * 0.33, 0.0), Vector2(n * 0.34, n)), ink)
			draw_rect(Rect2(o + Vector2(0.0, n * 0.33), Vector2(n, n * 0.34)), ink)
		5:
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(0.0, n), o + Vector2(0.0, n * 0.5), o + Vector2(n * 0.5, n * 0.5),
				o + Vector2(n * 0.5, 0.0), o + Vector2(n, 0.0), o + Vector2(n, n)]), ink)


## The loose leaf: the at-stake mark of a carried piece. Open outline = carried from before; whole = found this path.
func _draw_leaf(origin: Vector2, side: float, alpha: float) -> void:
	var k := side / 14.0
	var ink := _color(leaf_tone if leaf_only else "ink", alpha)
	var outline := PackedVector2Array()
	_bezier(outline, Vector2(3.3, 10.7), Vector2(0.6, 6.4), Vector2(4.2, 0.9), Vector2(13.0, 1.0), 10)
	_bezier(outline, Vector2(13.0, 1.0), Vector2(13.1, 9.6), Vector2(8.2, 13.4), Vector2(3.3, 10.7), 10)
	for i in outline.size():
		outline[i] = origin + outline[i] * k
	if leaf == "gathered":
		draw_colored_polygon(outline, ink)
		draw_line(origin + Vector2(4.8, 9.4) * k, origin + Vector2(9.4, 4.8) * k, _color("plate", alpha), 1.4 * k)
	else:
		var open := PackedVector2Array()
		for i in int(float(outline.size()) * 0.84):
			open.append(outline[i])
		draw_polyline(open, ink, 1.5 * k)
		draw_line(origin + Vector2(4.8, 9.4) * k, origin + Vector2(9.4, 4.8) * k, ink, 1.2 * k)
	draw_line(origin + Vector2(3.5, 10.5) * k, origin + Vector2(1.8, 12.3) * k, ink, 1.5 * k)


func _draw_brackets(s: float) -> void:
	var ink := _color("ink")
	var m := 22.0 * s / 72.0
	var t := 2.0
	for corner in 4:
		var cx := 1.0 if corner % 2 == 0 else s - 1.0
		var cy := 1.0 if corner < 2 else s - 1.0
		var dx := 1.0 if corner % 2 == 0 else -1.0
		var dy := 1.0 if corner < 2 else -1.0
		draw_line(Vector2(cx, cy), Vector2(cx + dx * m, cy), ink, t)
		draw_line(Vector2(cx, cy), Vector2(cx, cy + dy * m), ink, t)


static func _bezier(out: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> void:
	for i in n:
		var t := float(i) / float(n)
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)


## Dashed rounded rectangle: 4 on, 3 off. Used by the lost state only.
func _dashed_outline(r: Rect2, radius: float, color: Color) -> void:
	if color.a <= 0.0:
		return
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI * 0.5],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI * 0.5],
		[Vector2(r.position.x + radius, r.position.y + radius), PI]]
	for c in corners:
		var center: Vector2 = c[0]
		var a0: float = c[1]
		for i in 7:
			var ang := a0 + (PI * 0.5) * float(i) / 6.0
			pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	pts.append(pts[0])
	var on := true
	var left := 4.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var remaining := a.distance_to(b)
		var pos := a
		while remaining > 0.0:
			var take := minf(left, remaining)
			var nxt := pos.move_toward(b, take)
			if on:
				draw_line(pos, nxt, color, 2.0)
			pos = nxt
			remaining -= take
			left -= take
			if left <= 0.0:
				on = not on
				left = 4.0 if on else 3.0
