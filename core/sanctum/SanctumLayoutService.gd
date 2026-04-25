extends RefCounted

class_name SanctumLayoutService

const LAYOUT_VERSION := 1
const CENTER_CELL := Vector2i(0, 0)


static func make_starter_layout() -> Dictionary:
	var tiles: Array = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			tiles.append({
				"x": x,
				"y": y,
				"kind": "floor",
			})
	return {
		"version": LAYOUT_VERSION,
		"origin": { "x": 0, "y": 0 },
		"tiles": tiles,
	}


static func ensure_layout(save_data: Dictionary) -> Dictionary:
	var sanctum := _ensure_sanctum(save_data)
	if not sanctum.has("layout") or not (sanctum["layout"] is Dictionary):
		sanctum["layout"] = make_starter_layout()
	else:
		var layout: Dictionary = sanctum["layout"]
		if not layout.has("version") or (typeof(layout["version"]) != TYPE_INT and typeof(layout["version"]) != TYPE_FLOAT):
			layout["version"] = LAYOUT_VERSION
		else:
			layout["version"] = int(layout["version"])
		if not layout.has("origin") or not (layout["origin"] is Dictionary):
			layout["origin"] = { "x": 0, "y": 0 }
		if not layout.has("tiles") or not (layout["tiles"] is Array) or (layout["tiles"] as Array).is_empty():
			layout["tiles"] = make_starter_layout()["tiles"]
	return sanctum["layout"] as Dictionary


static func ensure_starter_occupant(save_data: Dictionary) -> Array:
	var sanctum := _ensure_sanctum(save_data)
	ensure_layout(save_data)
	var occupants: Array = []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if not roster.is_empty() and roster[0] is Dictionary:
		var echo: Dictionary = roster[0]
		var echo_id := str(echo.get("id", ""))
		if not echo_id.is_empty():
			occupants.append({
				"id": echo_id,
				"name": str(echo.get("name", "")),
				"kind": "echo",
				"x": CENTER_CELL.x,
				"y": CENTER_CELL.y,
			})
	sanctum["occupants"] = occupants
	return occupants


static func snapshot_layout(save_data: Dictionary) -> Dictionary:
	return ensure_layout(save_data).duplicate(true)


static func snapshot_occupants(save_data: Dictionary) -> Array:
	return ensure_starter_occupant(save_data).duplicate(true)


static func _ensure_sanctum(save_data: Dictionary) -> Dictionary:
	if not save_data.has("sanctum") or not (save_data["sanctum"] is Dictionary):
		save_data["sanctum"] = {}
	return save_data["sanctum"] as Dictionary
