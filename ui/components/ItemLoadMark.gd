extends Control

## The satchel mark of the party pack, level 0..3 (bands filled). No gold. `light` draws it cream for dark
## surfaces, ink for light ones. Presentation only.

var level := 0:
	set(v):
		level = clampi(v, 0, 3)
		queue_redraw()
var light := true:
	set(v):
		light = v
		queue_redraw()


func _draw() -> void:
	var col := get_theme_color("cream" if light else "ink", "ItemGlyphs")
	var k := minf(size.x / 32.0, size.y / 28.0)
	var wide := level >= 2
	var body: PackedVector2Array
	if wide:
		body = PackedVector2Array([Vector2(8, 9), Vector2(24, 9), Vector2(29.6, 25.2), Vector2(28, 26.8), Vector2(4, 26.8), Vector2(2.4, 25.2)])
	else:
		body = PackedVector2Array([Vector2(8, 9), Vector2(24, 9), Vector2(27, 25.2), Vector2(25.6, 26.8), Vector2(6.4, 26.8), Vector2(5, 25.2)])
	var handle := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		handle.append(Vector2(10.0 + 12.0 * t, 9.5 - 5.5 * sin(PI * t)))
	for i in handle.size():
		handle[i] *= k
	draw_polyline(handle, col, 2.0 * k)
	var left_top := body[0]
	var left_bot := body[5]
	for band in 3:
		var filled := level >= 3 - band
		var y0: float = [11.4, 16.2, 21.0][band]
		var y1 := y0 + 3.0 if filled else y0 + 0.6
		var t0 := clampf((y0 - 9.0) / 17.8, 0.0, 1.0)
		var t1 := clampf((y1 - 9.0) / 17.8, 0.0, 1.0)
		var lx0 := lerpf(left_top.x, left_bot.x, t0)
		var lx1 := lerpf(left_top.x, left_bot.x, t1)
		var poly := PackedVector2Array([Vector2(lx0, y0), Vector2(32.0 - lx0, y0), Vector2(32.0 - lx1, y1), Vector2(lx1, y1)])
		for i in poly.size():
			poly[i] *= k
		if filled:
			draw_colored_polygon(poly, col)
		else:
			draw_line(poly[0], poly[1], col, 1.0 * k)
	var outline := body.duplicate()
	outline.append(body[0])
	for i in outline.size():
		outline[i] *= k
	draw_polyline(outline, col, 2.0 * k)
