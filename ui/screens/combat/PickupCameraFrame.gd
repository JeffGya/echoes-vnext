class_name PickupCameraFrame
extends RefCounted

## Pure camera framing for the pickup event (D-73). World points in, `{ valid, zoom, position }` out. No node, no state.
## The box is the points grown by one tile in total (half a tile on each side). Zoom fits the box inside `usable` minus
## `margin_px`. It never rises above the current zoom, except when the current zoom is below `floor_zoom`: then it rises
## to `floor_zoom`. The fit wins when the box does not fit at the floor. `position` puts the box centre on the centre of `usable`.


static func frame(points: PackedVector2Array, tile_size: Vector2, view_size: Vector2, usable: Rect2, current_zoom: float,
		zoom_min: float, zoom_max: float, floor_zoom: float, margin_px: float) -> Dictionary:
	var current := current_zoom if is_finite(current_zoom) else 0.0
	var kept := PackedVector2Array()
	for p in points:
		if is_finite(p.x) and is_finite(p.y):
			kept.append(p)
	var lo := zoom_min if is_finite(zoom_min) else 0.0
	var hi := maxf(zoom_max if is_finite(zoom_max) else 0.0, lo)
	var sizes_ok := tile_size.x > 0.0 and tile_size.y > 0.0 and usable.size.x > 0.0 and usable.size.y > 0.0 \
		and is_finite(tile_size.x) and is_finite(tile_size.y) and is_finite(usable.size.x) and is_finite(usable.size.y) \
		and is_finite(usable.position.x) and is_finite(usable.position.y) and is_finite(view_size.x) and is_finite(view_size.y)
	if kept.is_empty() or not sizes_ok:
		return { "valid": false, "zoom": clampf(current, lo, hi), "position": Vector2.ZERO }
	var box := _box(kept, tile_size)
	var margin := maxf(margin_px if is_finite(margin_px) else 0.0, 0.0)
	var fit := minf((usable.size.x - 2.0 * margin) / box.size.x, (usable.size.y - 2.0 * margin) / box.size.y)
	if not is_finite(fit) or fit <= 0.0:
		fit = lo
	var floor_z := floor_zoom if is_finite(floor_zoom) else 0.0
	var zoom := clampf(minf(fit, maxf(current, floor_z)), lo, hi)
	if zoom <= 0.0:
		return { "valid": false, "zoom": clampf(current, lo, hi), "position": Vector2.ZERO }
	var position := box.get_center() - (usable.get_center() - view_size * 0.5) / zoom
	if not is_finite(zoom) or not is_finite(position.x) or not is_finite(position.y):
		return { "valid": false, "zoom": clampf(current, lo, hi), "position": Vector2.ZERO }
	return { "valid": true, "zoom": zoom, "position": position }


## The zoom at which the box of `points` just fits inside `usable` minus `margin_px`; 0 when it cannot be worked out.
static func fit_zoom(points: PackedVector2Array, tile_size: Vector2, usable: Rect2, margin_px: float) -> float:
	if points.is_empty() or tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return 0.0
	var box := _box(points, tile_size)
	var margin := maxf(margin_px if is_finite(margin_px) else 0.0, 0.0)
	var fit := minf((usable.size.x - 2.0 * margin) / box.size.x, (usable.size.y - 2.0 * margin) / box.size.y)
	return fit if is_finite(fit) and fit > 0.0 else 0.0


## The points grown by half a tile on each side.
static func _box(points: PackedVector2Array, tile_size: Vector2) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box.grow_individual(tile_size.x * 0.5, tile_size.y * 0.5, tile_size.x * 0.5, tile_size.y * 0.5)
