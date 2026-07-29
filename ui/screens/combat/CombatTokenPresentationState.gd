class_name CombatTokenPresentationState
extends RefCounted

var _entries: Dictionary = {}


func reset() -> void:
	_entries.clear()


func has_actor(actor_id: String) -> bool:
	return _entries.has(actor_id)


func get_actor_ids() -> Array[String]:
	var ids: Array[String] = []
	for actor_id_v in _entries.keys():
		ids.append(str(actor_id_v))
	return ids


func get_entry(actor_id: String) -> Dictionary:
	if not _entries.has(actor_id):
		return {}
	return (_entries[actor_id] as Dictionary).duplicate(true)


func get_display_position(actor_id: String, fallback: Vector2) -> Vector2:
	if not _entries.has(actor_id):
		return fallback
	return (_entries[actor_id] as Dictionary).get("display_pos", fallback)


## V2-COMBAT-002 Slice 6D: `move_path` is a list of ALREADY-CONVERTED pixel waypoints —
## one per entry of `last_actor_action.path`, same order, ORIGIN EXCLUDED (the origin is
## the token's current display_pos). This class stays pure pixel-space: it never sees a
## grid cell, a board, or the scene tree. Empty `move_path` reproduces the single-lerp
## behaviour exactly.
func apply_snapshot(tokens: Array[Dictionary], last_actor_action: Dictionary, telegraph_lead_time: float, move_path: Array[Vector2] = []) -> Dictionary:
	var seen: Dictionary = {}
	var telegraph_event: Dictionary = {}
	var is_move_action: bool = str(last_actor_action.get("action_type", "")) == "actor.move"
	var move_source_id: String = str(last_actor_action.get("source_id", ""))

	for token in tokens:
		var actor_id: String = str(token.get("actor_id", ""))
		if actor_id.is_empty():
			continue

		seen[actor_id] = true
		var next_draw_pos: Vector2 = token.get("draw_pos", Vector2.ZERO)
		var next_grid_pos: Dictionary = _duplicate_grid_pos(token.get("grid_pos", {}))
		var next_duration: float = max(float(token.get("move_duration", 0.0)), 0.001)

		if not _entries.has(actor_id):
			_entries[actor_id] = {
				"grid_pos":         next_grid_pos,
				"display_pos":      next_draw_pos,
				"start_pos":        next_draw_pos,
				"target_pos":       next_draw_pos,
				"move_duration":    next_duration,
				"move_elapsed":     next_duration,
				"delay_remaining":  0.0,
				"path_queue":       [] as Array[Vector2],
				"path_index":       0,
				"seg_elapsed":      0.0,
				"seg_duration":     next_duration,
			}
			continue

		var entry: Dictionary = _entries[actor_id]
		var current_display: Vector2 = entry.get("display_pos", next_draw_pos)
		var previous_grid_pos: Dictionary = _duplicate_grid_pos(entry.get("grid_pos", {}))
		var cell_changed: bool = _grid_key(previous_grid_pos) != _grid_key(next_grid_pos)
		var target_changed: bool = current_display.distance_to(next_draw_pos) > 0.01 or cell_changed

		entry["grid_pos"] = next_grid_pos
		entry["move_duration"] = next_duration

		if target_changed:
			# Slice 6D: arm the waypoint walk ONLY on a real cell transition for the
			# actor that actually moved. A snapshot refresh that re-emits an UNCHANGED
			# last_actor_action leaves cell_changed false, so the queue never re-fires.
			var arm_walk: bool = (
				not move_path.is_empty()
				and cell_changed
				and not move_source_id.is_empty()
				and actor_id == move_source_id
			)
			# A mid-walk refresh (same cell, same destination) must not restart the
			# walk or snap the token back onto the straight line.
			var previous_target: Vector2 = entry.get("target_pos", next_draw_pos)
			var keeps_walk: bool = (
				not arm_walk
				and not cell_changed
				and not (entry.get("path_queue", []) as Array).is_empty()
				and previous_target.distance_to(next_draw_pos) <= 0.01
			)
			if keeps_walk:
				entry["target_pos"] = next_draw_pos
				_entries[actor_id] = entry
				continue

			entry["display_pos"] = current_display
			entry["start_pos"] = current_display
			entry["target_pos"] = next_draw_pos
			entry["move_elapsed"] = 0.0
			entry["delay_remaining"] = 0.0
			entry["path_index"] = 0
			entry["seg_elapsed"] = 0.0
			if arm_walk:
				var queue: Array[Vector2] = []
				for waypoint in move_path:
					queue.append(waypoint)
				entry["path_queue"] = queue
				# Total-duration clamp BY CONSTRUCTION: divide, never multiply. Total
				# animation time is invariant to path length, so the board's step
				# timer margins are preserved exactly.
				entry["seg_duration"] = next_duration / float(queue.size())
			else:
				entry["path_queue"] = [] as Array[Vector2]
				entry["seg_duration"] = next_duration

			if is_move_action and actor_id == move_source_id and cell_changed:
				var lead_time: float = max(telegraph_lead_time, 0.0)
				entry["delay_remaining"] = lead_time
				telegraph_event = {
					"actor_id": actor_id,
					"grid_pos": next_grid_pos,
					"cell_pos": token.get("cell_pos", Vector2.ZERO),
					"duration": lead_time,
				}
		else:
			entry["target_pos"] = next_draw_pos
			if current_display.distance_to(next_draw_pos) <= 0.01:
				entry["display_pos"] = next_draw_pos
				entry["start_pos"] = next_draw_pos
				entry["move_elapsed"] = next_duration
				entry["path_queue"] = [] as Array[Vector2]
				entry["path_index"] = 0
				entry["seg_elapsed"] = 0.0

		_entries[actor_id] = entry

	var stale_ids: Array[String] = []
	for actor_id_v in _entries.keys():
		var actor_id: String = str(actor_id_v)
		if not seen.has(actor_id):
			stale_ids.append(actor_id)
	for actor_id in stale_ids:
		_entries.erase(actor_id)

	return telegraph_event


func advance(delta: float) -> bool:
	var changed: bool = false
	for actor_id_v in _entries.keys():
		var actor_id: String = str(actor_id_v)
		var entry: Dictionary = _entries[actor_id]
		var remaining_delta: float = max(delta, 0.0)
		var delay_remaining: float = max(float(entry.get("delay_remaining", 0.0)), 0.0)

		if delay_remaining > 0.0:
			if remaining_delta < delay_remaining:
				entry["delay_remaining"] = delay_remaining - remaining_delta
				_entries[actor_id] = entry
				continue
			remaining_delta -= delay_remaining
			entry["delay_remaining"] = 0.0

		var start_pos: Vector2 = entry.get("start_pos", Vector2.ZERO)
		var target_pos: Vector2 = entry.get("target_pos", start_pos)
		var current_display: Vector2 = entry.get("display_pos", start_pos)
		var duration: float = max(float(entry.get("move_duration", 0.0)), 0.001)
		var queue: Array = entry.get("path_queue", []) as Array

		if not queue.is_empty():
			# Slice 6D: sequential waypoint walk. Leftover delta from a completed
			# segment carries into the next one, so a single oversized delta lands
			# exactly on the final waypoint instead of one segment along.
			var index: int = int(entry.get("path_index", 0))
			var seg_duration: float = max(float(entry.get("seg_duration", duration)), 0.0001)
			var seg_elapsed: float = max(float(entry.get("seg_elapsed", 0.0)), 0.0)
			var seg_start: Vector2 = start_pos if index <= 0 else queue[index - 1]
			var next_walk_display: Vector2 = current_display
			var carry: float = remaining_delta

			while index < queue.size():
				var seg_target: Vector2 = queue[index]
				var seg_available: float = seg_duration - seg_elapsed
				if carry >= seg_available:
					carry -= seg_available
					seg_elapsed = 0.0
					index += 1
					seg_start = seg_target
					next_walk_display = seg_target
					continue
				seg_elapsed += carry
				carry = 0.0
				next_walk_display = seg_start.lerp(seg_target, clampf(seg_elapsed / seg_duration, 0.0, 1.0))
				break

			if index >= queue.size():
				# Queue exhausted: snap to the snapshot's draw_pos so the token can
				# never finish off-position.
				next_walk_display = target_pos
				entry["path_queue"] = [] as Array[Vector2]
				entry["path_index"] = 0
				entry["seg_elapsed"] = 0.0
				entry["start_pos"] = target_pos
				entry["move_elapsed"] = duration
			else:
				entry["path_index"] = index
				entry["seg_elapsed"] = seg_elapsed

			if next_walk_display != current_display:
				entry["display_pos"] = next_walk_display
				changed = true
			_entries[actor_id] = entry
			continue

		if current_display.distance_to(target_pos) <= 0.01:
			entry["display_pos"] = target_pos
			entry["start_pos"] = target_pos
			entry["move_elapsed"] = duration
			_entries[actor_id] = entry
			continue

		var next_elapsed: float = float(entry.get("move_elapsed", 0.0)) + remaining_delta
		var ratio: float = clampf(next_elapsed / duration, 0.0, 1.0)
		var next_display: Vector2 = start_pos.lerp(target_pos, ratio)
		if next_display.distance_to(target_pos) <= 0.01:
			next_display = target_pos

		if next_display != current_display:
			entry["display_pos"] = next_display
			changed = true

		entry["move_elapsed"] = next_elapsed
		_entries[actor_id] = entry

	return changed


func _grid_key(grid_pos: Dictionary) -> String:
	return "%d:%d" % [int(grid_pos.get("col", 0)), int(grid_pos.get("row", 0))]


func _duplicate_grid_pos(grid_pos: Dictionary) -> Dictionary:
	return {
		"col": int(grid_pos.get("col", 0)),
		"row": int(grid_pos.get("row", 0)),
	}
