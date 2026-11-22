class_name PickupDetailsPlan
extends RefCounted

## Pure: on which side of its item the pickup details card sits (V2-ITEM-001b U7, D-84). No node, no state; all rects are screen px.
## The card lies fully to one side of the item: left, right, above or below, `gap` away from the item, so it never covers the item.
## A side whose card would leave `usable` does not count. Each side is scored by the weighted area of the obstacles the card covers.
## The first side in the order with no coverage wins; if every side covers something, the side with the least covered area wins; ties keep the order.
## The card keeps the side it had (`prev`) while that side still fits, unless it covers something and another side covers nothing.

const SIDES: Array[String] = ["left", "right", "above", "below"]
## Order of the sides for a find on the board and for a tile of the pack strip. A pack tile has left only as the first tile and right only
## as the last, so the first tile takes left, a middle tile takes above, over the strip header, and the last tile takes above (right is its fallback).
const ORDER_FIND: Array[String] = ["left", "right", "above", "below"]
const ORDER_PACK: Array[String] = ["left", "above", "right", "below"]
## Covering a bark costs half of covering a token. A presentation preference (Jeff, 2026-11-22) that the pick rule never reads;
## that is the documented reason it is not in data/balance.json (ANSWERS #83).
const BARK_WEIGHT := 0.5
const EPS := 0.0001


static func obstacle(rect: Rect2, weight: float = 1.0) -> Dictionary:
	return { "rect": rect, "weight": weight }


## `anchor` is the item (the arrow points at it). `kind` is "find" or "pack". `first` and `last` tell whether a pack tile is the first or
## the last of the strip (left needs the first, right the last; a find is both). `prev` is the side the card had, or "".
## `arrow_inset` keeps the arrow off the card corners.
## Returns { side, position, arrow_at (the arrow centre inside the card), covered (side -> weighted area), valid }.
static func plan(anchor: Rect2, size: Vector2, usable: Rect2, obstacles: Array, kind: String, gap: float, arrow_inset: float,
		first: bool = true, last: bool = true, prev: String = "") -> Dictionary:
	var order: Array[String] = ORDER_PACK if kind == "pack" else ORDER_FIND
	var covered := {}
	var fits := {}
	for side in order:
		var pos := _position(side, anchor, size, usable, gap)
		if pos == Vector2.INF or (side == "left" and not first) or (side == "right" and not last):
			continue
		fits[side] = pos
		covered[side] = coverage(Rect2(pos, size), obstacles)
	var best := ""
	var best_area := INF
	for side in order:
		if not covered.has(side):
			continue
		if float(covered[side]) < best_area - EPS:
			best = side
			best_area = float(covered[side])
	if best.is_empty():
		var fallback := Vector2(clampf(anchor.get_center().x - size.x * 0.5, usable.position.x, maxf(usable.position.x, usable.end.x - size.x)),
			clampf(anchor.end.y + gap, usable.position.y, maxf(usable.position.y, usable.end.y - size.y)))
		return { "side": "below", "position": fallback, "arrow_at": _arrow("below", fallback, size, anchor, arrow_inset), "covered": covered, "valid": false }
	if covered.has(prev) and (float(covered[prev]) <= EPS or best_area > EPS):
		best = prev
	return { "side": best, "position": fits[best], "arrow_at": _arrow(best, fits[best], size, anchor, arrow_inset), "covered": covered, "valid": true }


## The weighted area of `obstacles` ({ rect, weight }) that `card` covers.
static func coverage(card: Rect2, obstacles: Array) -> float:
	var total := 0.0
	for o_v: Variant in obstacles:
		var o: Dictionary = o_v
		var hit := card.intersection(o["rect"] as Rect2)
		total += float(o.get("weight", 1.0)) * maxf(hit.size.x, 0.0) * maxf(hit.size.y, 0.0)
	return total


## The card's top-left for a side, or Vector2.INF when that side does not fit. Only the sliding along the item is clamped; the distance from
## the item is never reduced.
static func _position(side: String, anchor: Rect2, size: Vector2, usable: Rect2, gap: float) -> Vector2:
	var cx := anchor.get_center().x - size.x * 0.5
	var cy := anchor.get_center().y - size.y * 0.5
	var slide_x := clampf(cx, usable.position.x, maxf(usable.position.x, usable.end.x - size.x))
	var slide_y := clampf(cy, usable.position.y, maxf(usable.position.y, usable.end.y - size.y))
	var pos := Vector2.INF
	match side:
		"left":
			pos = Vector2(anchor.position.x - gap - size.x, slide_y)
		"right":
			pos = Vector2(anchor.end.x + gap, slide_y)
		"above":
			pos = Vector2(slide_x, anchor.position.y - gap - size.y)
		"below":
			pos = Vector2(slide_x, anchor.end.y + gap)
	if pos.x < usable.position.x - 0.01 or pos.y < usable.position.y - 0.01 or pos.x + size.x > usable.end.x + 0.01 or pos.y + size.y > usable.end.y + 0.01:
		return Vector2.INF
	return pos


static func _arrow(side: String, pos: Vector2, size: Vector2, anchor: Rect2, inset: float) -> Vector2:
	var along_x := clampf(anchor.get_center().x - pos.x, inset, maxf(inset, size.x - inset))
	var along_y := clampf(anchor.get_center().y - pos.y, inset, maxf(inset, size.y - inset))
	match side:
		"left":
			return Vector2(size.x, along_y)
		"right":
			return Vector2(0.0, along_y)
		"above":
			return Vector2(along_x, size.y)
	return Vector2(along_x, 0.0)
