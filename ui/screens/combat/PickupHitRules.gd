class_name PickupHitRules
extends RefCounted

## Pure rules of the pickup event input (V2-ITEM-001b U7). No node, no state.
## A find is a round target of TARGET px (screen) round its centre. Two finds keep GAP px between their targets when the camera
## zoom is at least `min_zoom`. The nearer find in draw order (the later one) wins a tap that hits two targets.

const TARGET := 48.0
const GAP := 8.0
const FIND_STATUSES: Array[String] = ["left", "tried", "lost"]


## Nothing opens in the intro (B2): the only action there is Skip. Taken finds are in the pack and have no mark.
static func can_select(phase: String, side: String, status: String) -> bool:
	if phase != "idle":
		return false
	return side == "pack" or (side == "find" and FIND_STATUSES.has(status))


## The index of the target hit by `point`, or -1. `centers` are screen points in draw order, so the last hit wins.
static func hit(point: Vector2, centers: Array, radius: float = TARGET * 0.5) -> int:
	for i in range(centers.size() - 1, -1, -1):
		if point.distance_to(centers[i] as Vector2) <= radius:
			return i
	return -1


## The lowest camera zoom at which the two nearest points (board px) are `target + gap` apart on screen. 0 for fewer than two.
## Two points on one spot (a pile) are one target and are skipped.
static func min_zoom(points: Array, target: float = TARGET, gap: float = GAP) -> float:
	var nearest := INF
	for i in points.size():
		for j in range(i + 1, points.size()):
			var d := (points[i] as Vector2).distance_to(points[j] as Vector2)
			if d > 0.0001:
				nearest = minf(nearest, d)
	return 0.0 if nearest == INF else (target + gap) / nearest


static func select_action(side: String, id: String) -> Dictionary:
	return { "type": "pickup.select", "payload": { "find_id" if side == "find" else "pack_id": id } }


## Both ids absent closes the details (PickupController.handle_select).
static func close_action() -> Dictionary:
	return { "type": "pickup.select", "payload": {} }


## What the card shows: { id, side, row, status } of `data.selected`, or {} when nothing is selected or the row is gone.
static func selection(data: Dictionary) -> Dictionary:
	var sel_v: Variant = data.get("selected", {})
	if not (sel_v is Dictionary) or (sel_v as Dictionary).is_empty():
		return {}
	var sel: Dictionary = sel_v
	var side := str(sel.get("side", ""))
	var id := str(sel.get("id", ""))
	if side == "find":
		for f_v: Variant in data.get("finds", []) as Array:
			if f_v is Dictionary and str((f_v as Dictionary).get("find_id", "")) == id:
				return { "id": id, "side": side, "row": f_v, "status": str((f_v as Dictionary).get("status", "")) }
	elif side == "pack":
		var pack_v: Variant = data.get("pack", {})
		for s_v: Variant in ((pack_v as Dictionary).get("slots", []) if pack_v is Dictionary else []) as Array:
			if s_v is Dictionary and str((s_v as Dictionary).get("id", "")) == id:
				return { "id": id, "side": side, "row": s_v, "status": "" }
	return {}
