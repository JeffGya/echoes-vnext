extends Control
## Snapshot-only village drawing, authoritative-position interpolation and camera.

signal subject_selected(subject: Dictionary)

@export var ink := Color("172522")
@export var gold := Color("e8c47b")
@export var paper := Color("f0e2c7")
@export var earth := Color("79513b")
@export var earth_edge := Color("4f5140")
@export var path_color := Color("aa825a")
@export var canopy := Color("6f8766")
@export var canopy_light := Color("8a9c73")
@export var wall_color := Color("b86f49")
@export var roof_color := Color("d1a575")
@export var flame_color := Color("edac60")
@export var social_cue_color := Color("8fd4bd")
@export var warning_color := Color("e5b65c")
@export var open_incident_color := Color("ef8b58")
@export var private_incident_color := Color("6f8d7d")
@export var appeal_incident_color := Color("f1d27f")
@export var joined_incident_color := Color("f1d27f")
@export var resolved_incident_color := Color("a5d6a7")
@export var iso_units := Vector2(48, 24)
@export var shared_focus_multiplier := 1.35
@export var grove_positions := PackedVector2Array()
@export var morning_tint := Color.WHITE
@export var afternoon_tint := Color.WHITE
@export var evening_tint := Color.WHITE
@export var night_tint := Color.WHITE
var _data: Dictionary = {}
var _positions: Dictionary = {}
var _tracks: Dictionary = {}
var _crowd_offsets: Dictionary = {}
var _crowd_targets: Dictionary = {}
var _last_step := -1
var _session_serial := -1
var _observation_serial := -1
var _clock := 0.0
var _pan := Vector2.ZERO
var _pan_target := Vector2.ZERO
var _zoom := 1.0
var _zoom_target := 1.0
var _zoom_user := 1.0
var _overview_zoom := 1.0
var _world_centre := Vector2.ZERO
var _reserved_width := 0.0
var _hover: Dictionary = {}
var _keyboard_index := -1
var _drag_start := Vector2.ZERO
var _drag_pan := Vector2.ZERO
var _pressed := false
var _dragged := false
var _selection_key := ""
var _click_cycle := 0
var _last_click := Vector2(-1000, -1000)
var _manual_camera := false
var _label_boxes: Array[Rect2] = []
var _token_boxes: Array[Rect2] = []
var _reaction_cue_bounds: Array[Rect2] = []
var _phase_tint := Color.WHITE
var _phase_tint_target := Color.WHITE


func _ready() -> void:
	resized.connect(_fit_camera)


func set_snapshot(data: Dictionary, reserved_width: float) -> void:
	var reset: bool = int(data.session_serial) != _session_serial
	_reserved_width = reserved_width
	_data = data.duplicate(true)
	_phase_tint_target = _phase_color(float(data.clock.progress))
	if reset:
		_tracks.clear()
		_positions.clear()
		_crowd_offsets.clear()
		_crowd_targets.clear()
		_last_step = -1
		_session_serial = int(data.session_serial)
		_selection_key = ""
		_manual_camera = false
		_zoom_user = 1.0
		_keyboard_index = -1
		_hover = {}
	var step_changed: bool = int(data.step) != _last_step
	for echo: Dictionary in data.echoes:
		var target: Vector2 = _world_position(echo.position)
		if not _positions.has(echo.id) or data.speed == "paused":
			_positions[echo.id] = target
			_tracks.erase(echo.id)
		elif step_changed:
			# Blend only consecutive authoritative samples; beats and waypoint IDs
			# never invent positions or grant movement. Duplicate snapshots do not restart.
			_tracks[echo.id] = {"from": _positions[echo.id], "to": target, "elapsed": 0.0,
				"duration": float(data.step_ms) / 1000.0 / (3.0 if data.speed == "fast" else 1.0)}
		_crowd_targets[echo.id] = _crowd_offset(echo)
		if not _crowd_offsets.has(echo.id):
			_crowd_offsets[echo.id] = _crowd_targets[echo.id]
	_last_step = int(data.step)
	var key: String = str(data.selection)
	if key != _selection_key:
		_selection_key = key
		_manual_camera = false
		_zoom_user = 1.0
	if int(data.observation_serial) != _observation_serial:
		_observation_serial = int(data.observation_serial)
		_manual_camera = false
	_fit_camera()
	if reset:
		_zoom = _zoom_target
		_pan = _pan_target
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	for id: String in _tracks.keys():
		var track: Dictionary = _tracks[id]
		track.elapsed += delta
		var progress: float = clampf(float(track.elapsed) / maxf(0.001, float(track.duration)), 0, 1)
		_positions[id] = (track.from as Vector2).lerp(track.to, progress)
		if progress >= 1:
			_tracks.erase(id)
	var reduced: bool = _data.get("reduced_motion", false)
	var blend: float = 1.0 if reduced else 1.0 - exp(-delta * 16.0)
	_phase_tint = _phase_tint.lerp(_phase_tint_target, 1.0 - exp(-delta * 1.8))
	_zoom = lerpf(_zoom, _zoom_target, blend)
	for echo: Dictionary in _data.get("echoes", []):
		_crowd_targets[echo.id] = _crowd_offset(echo)
		_crowd_offsets[echo.id] = (_crowd_offsets[echo.id] as Vector2).lerp(_crowd_targets[echo.id], blend)
	if not _data.is_empty() and not _pressed and not _manual_camera:
		var camera_subject: Dictionary = _camera_subject()
		_pan_target = _focus_pan(camera_subject) if not camera_subject.is_empty() else -_world_centre * _zoom
	_pan = _pan.lerp(_pan_target, blend)
	queue_redraw()


func _fit_camera() -> void:
	if _data.is_empty():
		return
	var bounds := Rect2()
	var first := true
	for waypoint: Dictionary in _data.waypoints.values():
		var point: Vector2 = _world_position(waypoint.pos)
		bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
		first = false
	bounds = bounds.grow(130.0)
	_world_centre = bounds.get_center()
	_overview_zoom = minf(maxf(100, size.x - _reserved_width - 80) / bounds.size.x, maxf(100, size.y - 90) / bounds.size.y)
	var camera_subject: Dictionary = _camera_subject()
	var focused: bool = not camera_subject.is_empty()
	var base: float = _focus_zoom(camera_subject) if focused else _overview_zoom
	_zoom_target = clampf(base * _zoom_user, 0.15, 2.6)
	if not _manual_camera:
		_pan_target = _focus_pan(camera_subject) if focused else -_world_centre * _zoom
	queue_redraw()


func _world_position(value: Array) -> Vector2:
	return _iso(Vector2(float(value[0]), float(value[1])))


func _node_position(id: String) -> Vector2:
	if not _data.get("waypoints", {}).has(id):
		return Vector2.ZERO
	return _world_position(_data.waypoints[id].pos)


func _iso(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * iso_units.x, (p.x + p.y) * iso_units.y)


func _phase_color(progress: float) -> Color:
	var anchors: Array[Color] = [morning_tint, afternoon_tint, evening_tint, night_tint]
	var phase_position: float = fposmod(progress, 1.0) * 4.0
	var index: int = mini(3, int(phase_position))
	var transition: float = clampf((phase_position - index - 0.72) / 0.28, 0.0, 1.0)
	transition = transition * transition * (3.0 - 2.0 * transition)
	return anchors[index].lerp(anchors[(index + 1) % anchors.size()], transition)


func _tone(base: Color) -> Color:
	return Color(clampf(base.r * _phase_tint.r, 0.0, 1.0), clampf(base.g * _phase_tint.g, 0.0, 1.0),
		clampf(base.b * _phase_tint.b, 0.0, 1.0), base.a)


func _screen(p: Vector2) -> Vector2:
	return Vector2((size.x - _reserved_width) * 0.5, size.y * 0.50) + p * _zoom + _pan


func _camera_subject() -> Dictionary:
	if not _data.get("summoning", {}).get("arrival", {}).is_empty():
		return {"kind": "place", "id": "flame"}
	return _data.get("selection", {})


func _subject_position(subject: Dictionary) -> Vector2:
	var id: String = subject.get("id", "")
	match str(subject.get("kind", "")):
		"echo": return _positions.get(id, Vector2.ZERO)
		"site": return _node_position(id)
		"place": return _node_position(_data.places.get(id, {}).get("node", ""))
		"incident":
			var incident: Dictionary = _incident(id)
			var points: Array[Vector2] = []
			for participant_id: String in incident.get("participants", []):
				var participant := _echo(participant_id)
				if not participant.is_empty():
					points.append(_echo_world_position(participant))
			if not points.is_empty():
				var centre := Vector2.ZERO
				for point: Vector2 in points:
					centre += point
				return centre / points.size()
			return _node_position(_data.get("places", {}).get(incident.get("place", ""), {}).get("node", ""))
	return Vector2.ZERO


func _focus_pan(subject: Dictionary) -> Vector2:
	return -_focus_bounds(subject).get_center() * _zoom


func _focus_zoom(subject: Dictionary) -> float:
	# Selection only changes where the world is centred. Every subject uses the
	# same responsive camera amount so its authored scale stays comparable.
	return _overview_zoom * shared_focus_multiplier


func _focus_bounds(subject: Dictionary) -> Rect2:
	var points: Array[Vector2] = []
	var padding := Vector2(112.0, 96.0)
	var kind: String = str(subject.get("kind", ""))
	if kind == "echo":
		var echo := _echo(str(subject.get("id", "")))
		if not echo.is_empty():
			points.append(_echo_world_position(echo))
			var node: String = str(echo.get("node", ""))
			points.append(_node_position(node))
			_append_place_occupants(points, node)
			_append_connected_context(points, node)
	elif kind == "place":
		var place: Dictionary = _data.get("places", {}).get(str(subject.get("id", "")), {})
		var node: String = str(place.get("node", ""))
		points.append(_node_position(node))
		_append_place_occupants(points, node)
	elif kind == "incident":
		var incident := _incident(str(subject.get("id", "")))
		if not incident.is_empty():
			for participant_id: String in incident.get("participants", []):
				var participant := _echo(participant_id)
				if not participant.is_empty():
					points.append(_echo_world_position(participant))
			var place: Dictionary = _data.get("places", {}).get(str(incident.get("place", "")), {})
			points.append(_node_position(str(place.get("node", ""))))
			points.append(_incident_world_position(incident))
			padding = Vector2(126.0, 118.0)
	else:
		points.append(_subject_position(subject))
	var bounds := Rect2(points[0] if not points.is_empty() else Vector2.ZERO, Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	bounds = bounds.grow_individual(padding.x, padding.y, padding.x, padding.y)
	var minimum := Vector2(330.0, 250.0)
	if bounds.size.x < minimum.x:
		bounds.position.x -= (minimum.x - bounds.size.x) * 0.5
		bounds.size.x = minimum.x
	if bounds.size.y < minimum.y:
		bounds.position.y -= (minimum.y - bounds.size.y) * 0.5
		bounds.size.y = minimum.y
	return bounds


func _append_place_occupants(points: Array[Vector2], node: String) -> void:
	for echo: Dictionary in _data.get("echoes", []):
		if not echo.get("moving", false) and str(echo.get("node", "")) == node:
			points.append(_echo_world_position(echo))


func _append_connected_context(points: Array[Vector2], node: String) -> void:
	var waypoint: Dictionary = _data.get("waypoints", {}).get(node, {})
	for connected: String in waypoint.get("links", []):
		points.append(_node_position(connected))


func _echo_world_position(echo: Dictionary) -> Vector2:
	return (_positions.get(echo.get("id", ""), _world_position(echo.get("position", [0, 0]))) as Vector2) + (_crowd_offsets.get(echo.get("id", ""), Vector2.ZERO) as Vector2) + Vector2(0, -16)


func _incident_world_position(incident: Dictionary) -> Vector2:
	var centre := _subject_position({"kind": "incident", "id": incident.get("id", "")})
	var same_place: Array = _data.get("incidents", []).filter(func(other: Dictionary) -> bool: return other.get("place", "") == incident.get("place", ""))
	var index: int = same_place.find(incident)
	return centre + Vector2((float(index) - float(same_place.size() - 1) * 0.5) * 58.0, -82.0)


func _echo_scale(_echo_id: String = "") -> float:
	# Kept as a geometry seam for the prototype verifier. All world subjects share
	# the camera zoom; focus never scales an Echo independently.
	return _zoom


func _stationary_peers(echo: Dictionary) -> Array:
	if echo.moving:
		return []
	return _data.echoes.filter(func(other: Dictionary) -> bool: return not other.moving and other.node == echo.node)


func _crowd_offset(echo: Dictionary) -> Vector2:
	var peers: Array = _stationary_peers(echo)
	var offset := Vector2.ZERO
	if peers.size() > 1:
		var index := 0
		for i: int in range(peers.size()):
			if peers[i].id == echo.id:
				index = i
		var angle: float = TAU * index / peers.size() - PI * 0.5
		offset = Vector2(cos(angle), sin(angle)) * (38 if peers.size() <= 3 else maxi(65, peers.size() * 10))
	return offset


func _echo_screen(echo: Dictionary) -> Vector2:
	return _screen(_echo_world_position(echo))


func _place_scale(id: String) -> float:
	return _zoom


func _incident_screen(incident: Dictionary) -> Vector2:
	return _screen(_incident_world_position(incident))


func _draw() -> void:
	if _data.is_empty():
		return
	_label_boxes.clear()
	_token_boxes.clear()
	_reaction_cue_bounds.clear()
	for echo: Dictionary in _data.echoes:
		var radius: float = 40 * _zoom
		var token_bounds := Rect2(_echo_screen(echo) - Vector2.ONE * radius, Vector2.ONE * radius * 2)
		_token_boxes.append(token_bounds)
		_label_boxes.append(token_bounds)
	_draw_landscape()
	for id: String in _data.waypoints:
		for target: String in _data.waypoints[id].links:
			if id < target:
				draw_line(_screen(_node_position(id)), _screen(_node_position(target)), _tone(path_color), 35 * _zoom, true)
	for id: String in _data.places:
		var place: Dictionary = _data.places[id]
		if not str(place.node).is_empty():
			_draw_place(id, place)
	_draw_summoning()
	_draw_social_engagements()
	_draw_behavior_cues()
	if _data.phase == "setup":
		for site: Dictionary in _data.sites:
			var p: Vector2 = _screen(_node_position(site.id))
			var selected: bool = _data.placements.get(site.institution, "") == site.id
			if not selected:
				draw_arc(p, 30 * _zoom, 0, TAU, 36, gold, 2 * _zoom, true)
				draw_line(p - Vector2(8, 0) * _zoom, p + Vector2(8, 0) * _zoom, gold, 2 * _zoom)
				draw_line(p - Vector2(0, 8) * _zoom, p + Vector2(0, 8) * _zoom, gold, 2 * _zoom)
				_label(site.name, p + Vector2(0, 46) * _zoom, roundi(16 * _zoom), paper)
	var ordered: Array = _data.echoes.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _echo_screen(a).y < _echo_screen(b).y)
	for echo: Dictionary in ordered:
		_draw_echo(echo)
	_draw_incidents()
	var focus: Dictionary = _hover
	var subjects: Array[Dictionary] = _subjects()
	if has_focus() and _keyboard_index >= 0 and _keyboard_index < subjects.size():
		focus = subjects[_keyboard_index]
	if not focus.is_empty() and focus.get("kind") not in ["echo", "incident"]:
		draw_arc(_screen(_subject_position(focus)), 48 * _zoom, 0, TAU, 40, paper, 2 * _zoom, true)
	if not _data.selection.is_empty() and _data.selection.get("kind") not in ["echo", "incident"]:
		draw_arc(_screen(_subject_position(_data.selection)), 51 * _zoom, 0, TAU, 40, gold, 3 * _zoom, true)


func _draw_landscape() -> void:
	var corners := PackedVector2Array()
	for waypoint: Dictionary in _data.waypoints.values():
		var point := Vector2(float(waypoint.pos[0]), float(waypoint.pos[1]))
		for offset: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]:
			corners.append(_screen(_iso(point + offset)))
	var border: PackedVector2Array = Geometry2D.convex_hull(corners)
	if border.size() >= 3:
		draw_colored_polygon(border, _tone(earth))
		draw_polyline(border, _tone(earth_edge), 16 * _zoom, true)
	for point: Vector2 in grove_positions:
		var p: Vector2 = _screen(_iso(point))
		draw_line(p, p + Vector2(0, -65) * _zoom, ink, maxf(3, 12 * _zoom), true)
		draw_circle(p + Vector2(-20, -65) * _zoom, 35 * _zoom, _tone(canopy))
		draw_circle(p + Vector2(17, -84) * _zoom, 42 * _zoom, _tone(canopy_light))


func _draw_place(id: String, place: Dictionary) -> void:
	var p: Vector2 = _screen(_node_position(place.node))
	var scale_value: float = _place_scale(id)
	var base := PackedVector2Array([p + Vector2(-46, 0) * scale_value, p + Vector2(0, -23) * scale_value, p + Vector2(46, 0) * scale_value, p + Vector2(0, 23) * scale_value])
	draw_colored_polygon(base, _tone(path_color))
	match id:
		"flame":
			draw_arc(p, 55 * scale_value, 0, TAU, 48, gold, 3, true)
			var flicker: float = 0 if _data.reduced_motion else sin(_clock * 3) * 3
			draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -5) * scale_value, p + Vector2(-8, -33) * scale_value, p + Vector2(3, -55 - flicker) * scale_value, p + Vector2(17, -9) * scale_value, p + Vector2(4, 1) * scale_value]), _tone(flame_color))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -4) * scale_value, p + Vector2(2, -32) * scale_value, p + Vector2(8, -4) * scale_value]), paper)
		"hearth":
			draw_rect(Rect2(p + Vector2(-42, -36) * scale_value, Vector2(84, 36) * scale_value), _tone(wall_color))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-57, -36) * scale_value, p + Vector2(-7, -86) * scale_value, p + Vector2(55, -36) * scale_value]), _tone(roof_color))
			draw_circle(p + Vector2(0, -12) * scale_value, 9 * scale_value, _tone(flame_color))
		"training":
			for offset: int in [-26, 26]:
				draw_line(p + Vector2(offset, -3) * scale_value, p + Vector2(offset, -48) * scale_value, ink, 6 * scale_value)
				draw_line(p + Vector2(offset - 13, -32) * scale_value, p + Vector2(offset + 13, -32) * scale_value, gold, 4 * scale_value)
		"quiet":
			draw_line(p, p + Vector2(0, -68) * scale_value, ink, 10 * scale_value)
			draw_circle(p + Vector2(-20, -64) * scale_value, 33 * scale_value, _tone(canopy))
			draw_circle(p + Vector2(18, -77) * scale_value, 37 * scale_value, _tone(canopy_light))
		"threshold":
			draw_line(p + Vector2(-32, 4) * scale_value, p + Vector2(-32, -57) * scale_value, _tone(roof_color), 10 * scale_value)
			draw_line(p + Vector2(32, 4) * scale_value, p + Vector2(32, -57) * scale_value, _tone(roof_color), 10 * scale_value)
			draw_line(p + Vector2(-40, -57) * scale_value, p + Vector2(40, -57) * scale_value, paper, 8 * scale_value)
		_:
			draw_arc(p, 30 * scale_value, 0, TAU, 32, gold, 2, true)
	var crowd_size: int = _data.echoes.filter(func(e: Dictionary) -> bool: return not e.moving and e.node == place.node).size()
	if crowd_size < 4 or _data.selection == {"kind": "place", "id": id} or _hover == {"kind": "place", "id": id}:
		_label(place.name, p + Vector2(0, 40 * scale_value), 16, paper)


func _draw_summoning() -> void:
	var summoning: Dictionary = _data.get("summoning", {})
	if summoning.is_empty() or not _data.get("places", {}).has("flame"):
		return
	var p: Vector2 = _screen(_node_position(str(_data.places.flame.node)))
	var state: String = str(summoning.get("flame_state", "unavailable"))
	var arrival: Dictionary = summoning.get("arrival", {})
	var stage: String = str(arrival.get("stage", ""))
	var s: float = _zoom
	var charge_color: Color = gold if state == "ready" else flame_color if state == "committing" else Color("607166")
	draw_arc(p, 70 * s, 0, TAU, 48, Color(charge_color, 0.86), 4 * s, true)
	if state == "ready":
		draw_arc(p, 82 * s, 0, TAU, 48, Color(gold, 0.44), 2 * s, true)
		_label("Ase Flame · ready", p + Vector2(0, 96 * s), roundi(16 * s), paper, 220 * s)
	elif state in ["recovering", "unavailable"]:
		_label("Ase Flame · gathering", p + Vector2(0, 96 * s), roundi(16 * s), paper, 220 * s)
	if stage.is_empty():
		return
	for witness: Dictionary in arrival.get("witnesses", []):
		var echo: Dictionary = _echo(str(witness.get("echo_id", "")))
		if echo.is_empty():
			continue
		var witness_p: Vector2 = _echo_screen(echo)
		var response: String = str(witness.get("response", "watch"))
		var response_color: Color = social_cue_color if response == "approach" else paper if response == "watch" else warning_color
		var direction: Vector2 = (p - witness_p).normalized()
		if response == "approach":
			draw_line(witness_p + direction * 34 * s, p - direction * 86 * s, Color(response_color, 0.7), 3 * s, true)
		elif response == "watch":
			draw_arc(witness_p, 44 * s, 0, TAU, 28, Color(response_color, 0.72), 2 * s, true)
		else:
			draw_line(witness_p, witness_p - direction * 34 * s, Color(response_color, 0.72), 4 * s, true)
		_label("coming closer" if response == "approach" else "watching" if response == "watch" else "keeping distance", witness_p + Vector2(0, -48 * s), roundi(16 * s), response_color, 190 * s)
	if stage in ["gather", "perform", "welcome"]:
		draw_arc(p, 108 * s, 0, TAU, 64, Color(flame_color, 0.52), 3 * s, true)
	if stage == "perform":
		var pulse: float = 0.0 if _data.get("reduced_motion", false) else sin(_clock * 4.0) * 10.0
		draw_circle(p + Vector2(0, -64 * s), (26.0 + pulse) * s, Color(flame_color, 0.5))
		_label("A return is taking shape", p + Vector2(0, -118 * s), roundi(16 * s), paper, 260 * s)
	var first: Dictionary = arrival.get("first_intention", {})
	if stage in ["travel", "complete"] and not first.is_empty():
		var route: Array = first.get("route", [])
		var previous := _node_position(str(_data.places.flame.node))
		for node_id: String in route:
			var next := _node_position(node_id)
			draw_line(_screen(previous), _screen(next), Color(social_cue_color, 0.56), 4 * s, true)
			previous = next
		_label("first way into the village", _screen(previous) + Vector2(0, -30 * s), roundi(16 * s), social_cue_color, 240 * s)


func _draw_social_engagements() -> void:
	for engagement: Dictionary in _data.get("social_engagements", []):
		var participants: Array = engagement.get("participants", [])
		if participants.size() < 2:
			continue
		var first: Dictionary = _echo(str(participants[0]))
		var second: Dictionary = _echo(str(participants[1]))
		if first.is_empty() or second.is_empty():
			continue
		var a: Vector2 = _echo_screen(first)
		var b: Vector2 = _echo_screen(second)
		var midpoint: Vector2 = (a + b) * 0.5
		draw_line(a, b, Color(social_cue_color, 0.42), 3 * _zoom, true)
		draw_circle(midpoint, 4 * _zoom, social_cue_color)
		for reaction: Dictionary in _reactions_between(participants):
			var owner: Dictionary = _echo(str(reaction.get("echo_id", "")))
			var target: Dictionary = _echo(str(reaction.get("target_id", "")))
			if not owner.is_empty() and not target.is_empty():
				_draw_reaction_cue(reaction, _echo_screen(owner), _echo_screen(target))
	_draw_practice_witnesses()


func _draw_practice_witnesses() -> void:
	for incident: Dictionary in _data.get("incidents", []):
		if str(incident.get("family", "")) != "practice":
			continue
		for witness: Dictionary in incident.get("witnesses", []):
			var reaction: Dictionary = witness.get("reaction", {})
			if not _is_visible_reaction(reaction):
				continue
			reaction = reaction.duplicate(true)
			reaction["echo_id"] = str(witness.get("echo_id", ""))
			var echo: Dictionary = _echo(str(reaction.echo_id))
			var target: Dictionary = _echo(str(reaction.target_id))
			if echo.is_empty() or target.is_empty():
				continue
			var p: Vector2 = _echo_screen(echo)
			var direction: Vector2 = (_echo_screen(target) - p).normalized()
			var color: Color = _reaction_color(str(reaction.kind))
			var role: String = str(witness.get("role", "watch"))
			if role == "support":
				draw_arc(p, 36 * _zoom, -1.1, 1.1, 12, Color(color, 0.82), 2 * _zoom, true)
			elif role == "side":
				draw_line(p + direction.orthogonal() * 28 * _zoom, p + direction.orthogonal() * 42 * _zoom, color, 3 * _zoom, true)
			elif role == "leave":
				draw_line(p - direction * 29 * _zoom, p - direction * 45 * _zoom, Color(color, 0.75), 3 * _zoom, true)
			else:
				draw_arc(p + direction * 29 * _zoom, 8 * _zoom, 0, TAU, 12, Color(color, 0.82), 2 * _zoom, true)
			_draw_reaction_cue(reaction, p, _echo_screen(target))


func _draw_behavior_cues() -> void:
	var grouped: Dictionary = {}
	for echo: Dictionary in _data.get("echoes", []):
		var behavior: Dictionary = echo.get("behavior", {})
		if behavior.is_empty(): continue
		var source_id: String = str(behavior.get("source_id", ""))
		if not grouped.has(source_id): grouped[source_id] = []
		grouped[source_id].append(echo)
	for source_id: String in grouped:
		var pair: Array = grouped[source_id]
		if pair.size() < 2: continue
		var a: Vector2 = _echo_screen(pair[0])
		var b: Vector2 = _echo_screen(pair[1])
		var kind: String = str(pair[0].get("behavior", {}).get("kind", "issue"))
		var color: Color = resolved_incident_color if kind == "aftermath" else open_incident_color
		draw_line(a, b, Color(color, 0.38), (12 if kind == "aftermath" else 5) * _zoom, true)
		if kind == "aftermath":
			var direction: Vector2 = (b - a).normalized()
			for point: Vector2 in [a, b]:
				draw_line(point, point - direction * 34 * _zoom, color, 5 * _zoom, true)


func _draw_incidents() -> void:
	var subjects: Array[Dictionary] = _subjects()
	var keyboard_subject: Dictionary = {}
	if has_focus() and _keyboard_index >= 0 and _keyboard_index < subjects.size():
		keyboard_subject = subjects[_keyboard_index]
	for incident: Dictionary in _data.get("incidents", []):
		var subject := {"kind": "incident", "id": incident.get("id", "")}
		var p: Vector2 = _incident_screen(incident)
		var status: String = str(incident.get("status", "warning"))
		var access: String = str(incident.get("keeper_access", "private"))
		var color: Color = _incident_color(status, access)
		var selected: bool = _data.selection == subject
		var highlighted: bool = selected or _hover == subject or keyboard_subject == subject
		if status == "warning":
			_draw_warning_notification(p, str(incident.get("label", "A tense moment")), color, highlighted)
			_draw_incident_exchange(incident)
			continue
		if status == "open" and access == "private":
			_draw_private_incident(p, color, highlighted)
			_label("They are handling this", p + Vector2(0, 38 * _zoom), roundi(16 * _zoom), paper, 220 * _zoom)
			_draw_incident_exchange(incident)
			continue
		var standard_scale: float = _zoom
		var ground: Vector2 = _screen(_node_position(_data.get("places", {}).get(incident.get("place", ""), {}).get("node", "")))
		draw_line(ground, p + Vector2(0, 42 * standard_scale), Color(color, 0.48), 5 * standard_scale, true)
		for participant_id: String in incident.get("participants", []):
			var echo: Dictionary = _echo(participant_id)
			if not echo.is_empty(): draw_line(_echo_screen(echo), p, Color(color, 0.62), 4 * standard_scale, true)
		if highlighted:
			draw_rect(Rect2(p - Vector2(34, 56) * standard_scale, Vector2(68, 112) * standard_scale), Color(ink, 0.45), false, 4 * _zoom)
		_draw_incident_standard(p, status, color, standard_scale)
		if status == "open" and access == "appeal":
			draw_arc(p, 58 * standard_scale, 0, TAU, 36, Color(appeal_incident_color, 0.72), 4 * standard_scale, true)
			draw_arc(p, 70 * standard_scale, 0, TAU, 36, Color(appeal_incident_color, 0.32), 2 * standard_scale, true)
			var appeal_name: String = _echo(str(incident.get("appeal_echo_id", ""))).get("name", "Someone")
			_label("%s asks for help" % appeal_name, p + Vector2(0, 69 * standard_scale), roundi(17 * _zoom), appeal_incident_color, 260 * _zoom)
		else:
			_label("%s · %s" % [str(incident.get("label", "Village tension")), status.capitalize()],
			p + Vector2(0, 69 * standard_scale), roundi(16 * _zoom), paper, 260 * _zoom)
		_draw_incident_exchange(incident)


func _draw_warning_notification(p: Vector2, label: String, color: Color, highlighted: bool) -> void:
	var s: float = _zoom
	if highlighted:
		draw_circle(p, 21 * s, Color(ink, 0.52))
	draw_circle(p, 14 * s, color)
	draw_line(p + Vector2(0, -6) * s, p + Vector2(0, 2) * s, ink, 3 * s, true)
	draw_circle(p + Vector2(0, 7) * s, 2 * s, ink)
	_label(label + " is starting", p + Vector2(0, -26 * s), roundi(16 * s), paper, 230 * s)


func _draw_incident_standard(p: Vector2, status: String, color: Color, scale_value: float) -> void:
	var top: Vector2 = p + Vector2(0, -52) * scale_value
	var bottom: Vector2 = p + Vector2(0, 48) * scale_value
	draw_line(top, bottom, ink, 9 * scale_value, true)
	match status:
		"warning":
			var blades := PackedVector2Array([p + Vector2(-30, -34) * scale_value, p + Vector2(-8, 0) * scale_value,
				p + Vector2(-28, 34) * scale_value, p + Vector2(0, 13) * scale_value,
				p + Vector2(28, 34) * scale_value, p + Vector2(8, 0) * scale_value, p + Vector2(30, -34) * scale_value])
			draw_polyline(blades, color, 10 * scale_value, true)
		"open":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-42, -40) * scale_value, p + Vector2(-10, -10) * scale_value, p + Vector2(-42, 40) * scale_value, p + Vector2(-18, 0) * scale_value]), color)
			draw_colored_polygon(PackedVector2Array([p + Vector2(42, -40) * scale_value, p + Vector2(10, -10) * scale_value, p + Vector2(42, 40) * scale_value, p + Vector2(18, 0) * scale_value]), color)
		"joined":
			draw_line(p + Vector2(-43, -8) * scale_value, p + Vector2(43, -8) * scale_value, color, 13 * scale_value, true)
			draw_colored_polygon(PackedVector2Array([top, p + Vector2(16, -29) * scale_value, p + Vector2(0, -18) * scale_value, p + Vector2(-16, -29) * scale_value]), color)
		"resolved":
			draw_line(p + Vector2(-38, -34) * scale_value, p + Vector2(38, 34) * scale_value, color, 11 * scale_value, true)
			draw_line(p + Vector2(38, -34) * scale_value, p + Vector2(-38, 34) * scale_value, color, 11 * scale_value, true)
			draw_line(p + Vector2(-38, 34) * scale_value, p + Vector2(-52, 52) * scale_value, color, 5 * scale_value, true)
			draw_line(p + Vector2(38, 34) * scale_value, p + Vector2(52, 52) * scale_value, color, 5 * scale_value, true)


func _draw_private_incident(p: Vector2, color: Color, highlighted: bool) -> void:
	var scale_value: float = _zoom
	if highlighted:
		draw_circle(p, 24 * scale_value, Color(ink, 0.45))
	draw_circle(p, 13 * scale_value, color)
	draw_arc(p, 20 * scale_value, 0, TAU, 20, Color(color, 0.55), 2 * scale_value, true)


func _draw_incident_exchange(incident: Dictionary) -> void:
	if str(incident.get("status", "")) not in ["warning", "open"]:
		return
	var exchange: Array = incident.get("exchange_lines", [])
	for index: int in range(exchange.size()):
		var line: Dictionary = exchange[index]
		var speaker: Dictionary = _echo(str(line.get("speaker_id", "")))
		var text: String = str(line.get("text", ""))
		if speaker.is_empty() or text.is_empty():
			continue
		var name: String = str(speaker.get("name", "Echo")).get_slice(" ", 0)
		_draw_exchange_label("%s: “%s”" % [name, text], _echo_screen(speaker), index)


func _draw_exchange_label(text: String, speaker: Vector2, index: int) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(16, roundi(16 * _zoom))
	var max_width: float = clampf((size.x - _reserved_width) * 0.25, 190.0, 300.0)
	var lines: Array[String] = _wrap_exchange_text(font, text, max_width, font_size)
	var line_height: float = float(font_size + 5)
	var text_width := 0.0
	for line: String in lines:
		text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var bounds_size := Vector2(text_width + 16.0, float(lines.size()) * line_height + 12.0)
	var side: float = -1.0 if index % 2 == 0 else 1.0
	var usable := Rect2(Vector2.ZERO, Vector2(maxf(0.0, size.x - _reserved_width), size.y))
	var fallback := Rect2()
	for offset: Vector2 in [Vector2(side * (bounds_size.x * 0.36 + 18.0), -96.0 * _zoom),
		Vector2(side * (bounds_size.x * 0.36 + 18.0), -150.0 * _zoom), Vector2(-side * (bounds_size.x * 0.36 + 18.0), -96.0 * _zoom),
		Vector2(-side * (bounds_size.x * 0.36 + 18.0), -150.0 * _zoom), Vector2(side * (bounds_size.x * 0.28 + 28.0), 42.0 * _zoom),
		Vector2(-side * (bounds_size.x * 0.28 + 28.0), 42.0 * _zoom), Vector2(0, -176.0 * _zoom), Vector2(0, -226.0 * _zoom)]:
		var centre := speaker + offset
		var bounds := Rect2(centre - bounds_size * 0.5, bounds_size)
		if not usable.encloses(bounds) or _token_boxes.any(func(box: Rect2) -> bool: return box.intersects(bounds)):
			continue
		if fallback.size.is_zero_approx():
			fallback = bounds
		if _label_boxes.any(func(box: Rect2) -> bool: return box.intersects(bounds)):
			continue
		_render_exchange_label(font, lines, font_size, line_height, speaker, bounds)
		return
	if not fallback.size.is_zero_approx():
		_render_exchange_label(font, lines, font_size, line_height, speaker, fallback)


func _render_exchange_label(font: Font, lines: Array[String], font_size: int, line_height: float, speaker: Vector2, bounds: Rect2) -> void:
	_label_boxes.append(bounds)
	draw_rect(bounds, Color(ink, 0.88), true)
	draw_rect(bounds, Color(paper, 0.36), false, 1.0, true)
	draw_line(speaker + Vector2(0, -27.0 * _zoom), bounds.get_center(), Color(paper, 0.38), 1.0, true)
	var origin := bounds.position + Vector2(8.0, float(font_size) + 5.0)
	for line: String in lines:
		draw_string_outline(font, origin, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, ink)
		draw_string(font, origin, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, paper)
		origin.y += line_height


func _wrap_exchange_text(font: Font, text: String, max_width: float, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word: String in text.split(" ", false):
		var candidate: String = word if current.is_empty() else current + " " + word
		if not current.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
			lines.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	return lines


func _incident_color(status: String, access: String = "") -> Color:
	if status in ["warning", "open"]:
		if access == "private": return private_incident_color
		if access == "appeal": return appeal_incident_color
	match status:
		"open": return open_incident_color
		"joined": return joined_incident_color
		"resolved": return resolved_incident_color
	return warning_color


func _draw_echo(echo: Dictionary) -> void:
	var reaction: Dictionary = _reaction_for(echo)
	var p: Vector2 = _echo_screen(echo)
	var s: float = _zoom
	var arrival: Dictionary = _data.get("summoning", {}).get("arrival", {})
	var newly_arrived: bool = str(arrival.get("newcomer_id", "")) == str(echo.get("id", "")) and str(arrival.get("stage", "")) in ["welcome", "travel", "complete"]
	var selected: bool = _data.selection.get("kind") == "echo" and _data.selection.get("id") == echo.id
	var hovered: bool = _hover.get("kind") == "echo" and _hover.get("id") == echo.id
	var subjects: Array[Dictionary] = _subjects()
	var keyboard: bool = has_focus() and _keyboard_index >= 0 and _keyboard_index < subjects.size() and subjects[_keyboard_index] == {"kind": "echo", "id": echo.id}
	var facing: Vector2 = _iso(Vector2(float(echo.facing[0]), float(echo.facing[1]))).normalized()
	var engagement: Dictionary = _engagement(str(echo.get("engagement_id", "")))
	if not engagement.is_empty():
		for participant_id: String in engagement.get("participants", []):
			if participant_id != echo.id:
				var other: Dictionary = _echo(participant_id)
				if not other.is_empty() and not _echo_screen(other).is_equal_approx(p):
					facing = (_echo_screen(other) - p).normalized()
				break
	var behavior: Dictionary = echo.get("behavior", {})
	if not behavior.is_empty():
		var partner: Dictionary = _echo(str(behavior.get("partner_id", "")))
		if not partner.is_empty() and not _echo_screen(partner).is_equal_approx(p):
			facing = (_echo_screen(partner) - p).normalized()
			if behavior.get("orientation", "toward") == "away": facing *= -1.0
	if not reaction.is_empty():
		var reaction_target: Dictionary = _echo(str(reaction.get("target_id", "")))
		if not reaction_target.is_empty() and not _echo_screen(reaction_target).is_equal_approx(p):
			facing = (_echo_screen(reaction_target) - p).normalized()
			if str(reaction.get("motion", "")) in ["angle_away", "step_back", "withdraw"]:
				facing *= -1.0
		p += _reaction_pose_offset(reaction, facing)
	draw_circle(p + Vector2(0, 8) * s, 35 * s, Color(ink, 0.55))
	if newly_arrived:
		draw_arc(p, 48 * s, 0, TAU, 40, flame_color, 4 * s, true)
	if selected or hovered or keyboard:
		draw_arc(p, 39 * s, 0, TAU, 40, gold if selected else paper, 3.0 * _zoom, true)
	draw_circle(p, 32 * s, ink)
	draw_circle(p, 26 * s, Color(echo.color))
	_draw_mark(int(echo.mark), p, s)
	var side: Vector2 = facing.orthogonal()
	draw_colored_polygon(PackedVector2Array([p + facing * 40 * s, p + (facing * 30 + side * 6) * s, p + (facing * 30 - side * 6) * s]), paper)
	if not reaction.is_empty():
		_draw_reaction_pose(reaction, p, facing)
	_label(str(echo.name).get_slice(" ", 0), p + Vector2(0, 50 * s), roundi(16 * _zoom), paper, 130 * _zoom)
	if selected or hovered or keyboard:
		var label: String = str(echo.activity).capitalize()
		if echo.reserved:
			label = "Approaching" if _data.conversation.get("status") == "approaching" else "Listening"
		_label(label, p + Vector2(0, -48 * s), roundi(16 * _zoom), gold)
	if not _data.conversation.is_empty() and _data.conversation.echo_id == echo.id and _data.conversation.status == "resolved":
		_label(str(_data.conversation.outcome).capitalize(), p + Vector2(0, -58 * s), roundi(16 * _zoom), paper)
	elif echo.activity == "practicing" and not _data.reduced_motion:
		draw_arc(p, 30 * s, _clock * 2, _clock * 2 + 0.6, 12, Color(echo.color), 2 * _zoom, true)
	elif echo.activity == "resting":
		draw_line(p + Vector2(-8, -24) * s, p + Vector2(8, -24) * s, Color(echo.color), 2 * _zoom, true)


func _reaction_for(echo: Dictionary) -> Dictionary:
	var echo_id: String = str(echo.get("id", ""))
	var projected := _reaction_for_echo(_reaction_cues(_data.get("reaction_cues", [])), echo_id)
	if not projected.is_empty():
		return projected
	var echo_cues := _reaction_for_echo(_reaction_cues(echo.get("reaction_cues", [])), echo_id)
	if not echo_cues.is_empty():
		return echo_cues
	for incident: Dictionary in _data.get("incidents", []):
		for witness: Dictionary in incident.get("witnesses", []):
			if str(witness.get("echo_id", "")) != echo_id:
				continue
			var witness_reaction: Dictionary = witness.get("reaction", {})
			if _is_visible_reaction(witness_reaction):
				witness_reaction = witness_reaction.duplicate(true)
				witness_reaction["echo_id"] = echo_id
				return witness_reaction
	return {}


func _reactions_between(participants: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reaction: Dictionary in _reaction_cues(_data.get("reaction_cues", [])):
		if participants.has(str(reaction.get("echo_id", ""))) and participants.has(str(reaction.get("target_id", ""))):
			result.append(reaction)
	return result


func _reaction_cues(raw: Array) -> Array[Dictionary]:
	var reactions: Array[Dictionary] = []
	for reaction: Dictionary in raw:
		if _is_visible_reaction(reaction):
			reactions.append(reaction.duplicate(true))
	return reactions


func _reaction_for_echo(reactions: Array[Dictionary], echo_id: String) -> Dictionary:
	for reaction: Dictionary in reactions:
		if str(reaction.get("echo_id", "")) == echo_id:
			return reaction
	return {}


func _is_visible_reaction(reaction: Dictionary) -> bool:
	if not reaction.has_all(["kind", "target_id", "motion", "started_ms", "duration_ms"]):
		return false
	if str(reaction.kind) not in ["welcomed", "appreciative", "uncomfortable", "crowded", "challenged", "hurt"]:
		return false
	if str(reaction.motion) not in ["closer", "acknowledge", "angle_away", "step_back", "square_up", "withdraw"]:
		return false
	var end_ms: int = int(reaction.started_ms) + int(reaction.duration_ms)
	return int(_data.get("elapsed_ms", 0)) < end_ms


func _reaction_color(kind: String) -> Color:
	match kind:
		"welcomed": return Color("a5d6a7")
		"appreciative": return social_cue_color
		"uncomfortable": return Color("d7c17a")
		"crowded": return warning_color
		"challenged": return Color("dd8e72")
		"hurt": return Color("c9878d")
	return paper


func _reaction_pose_offset(reaction: Dictionary, facing: Vector2) -> Vector2:
	if bool(_data.get("reduced_motion", false)):
		return Vector2.ZERO
	var amount: float = 5.0 * _zoom
	match str(reaction.get("motion", "")):
		"closer": return facing * amount
		"angle_away": return facing.orthogonal() * amount
		"step_back", "withdraw": return -facing * amount
	return Vector2.ZERO


func _draw_reaction_pose(reaction: Dictionary, p: Vector2, facing: Vector2) -> void:
	var s: float = _zoom
	var color: Color = _reaction_color(str(reaction.kind))
	var side: Vector2 = facing.orthogonal()
	match str(reaction.motion):
		"closer": draw_arc(p + facing * 28 * s, 9 * s, -0.9, 0.9, 10, color, 2 * s, true)
		"acknowledge": draw_line(p + side * 28 * s, p + side * 37 * s, color, 3 * s, true)
		"angle_away": draw_line(p - facing * 27 * s, p - facing * 38 * s, color, 3 * s, true)
		"step_back":
			draw_line(p - facing * 27 * s + side * 5 * s, p - facing * 40 * s + side * 5 * s, color, 2 * s, true)
			draw_line(p - facing * 27 * s - side * 5 * s, p - facing * 40 * s - side * 5 * s, color, 2 * s, true)
		"square_up": draw_line(p + side * 30 * s, p - side * 30 * s, color, 3 * s, true)
		"withdraw": draw_arc(p - facing * 28 * s, 8 * s, 0, TAU, 10, Color(color, 0.78), 2 * s, true)


func _draw_reaction_cue(reaction: Dictionary, owner: Vector2, target: Vector2) -> void:
	if owner.is_equal_approx(target):
		return
	var direction: Vector2 = (target - owner).normalized()
	var midpoint: Vector2 = (owner + target) * 0.5
	var s: float = _zoom
	var cue_size := Vector2(18, 18) * s
	for candidate: Vector2 in [
		midpoint + Vector2(0, -72) * s,
		midpoint + Vector2(0, -102) * s,
		midpoint + direction.orthogonal() * 70 * s + Vector2(0, -34) * s,
		midpoint - direction.orthogonal() * 70 * s + Vector2(0, -34) * s,
		midpoint + direction.orthogonal() * 96 * s,
		midpoint - direction.orthogonal() * 96 * s
	]:
		var bounds := Rect2(candidate - cue_size * 0.5, cue_size)
		if not Rect2(Vector2.ZERO, size).encloses(bounds) or _label_boxes.any(func(box: Rect2) -> bool: return box.intersects(bounds)):
			continue
		_label_boxes.append(bounds)
		_reaction_cue_bounds.append(bounds)
		var color: Color = _reaction_color(str(reaction.kind))
		match str(reaction.kind):
			"welcomed": draw_arc(candidate, 8 * s, 0, TAU, 12, color, 2 * s, true)
			"appreciative":
				draw_circle(candidate, 5 * s, color)
				draw_circle(candidate, 2 * s, ink)
			"uncomfortable": draw_line(candidate + Vector2(-7, 0) * s, candidate + Vector2(7, 0) * s, color, 3 * s, true)
			"crowded":
				draw_line(candidate + Vector2(-7, -5) * s, candidate + Vector2(-7, 5) * s, color, 2 * s, true)
				draw_line(candidate + Vector2(7, -5) * s, candidate + Vector2(7, 5) * s, color, 2 * s, true)
			"challenged": draw_polyline(PackedVector2Array([candidate + Vector2(0, -8) * s, candidate + Vector2(8, 0) * s, candidate + Vector2(0, 8) * s, candidate + Vector2(-8, 0) * s, candidate + Vector2(0, -8) * s]), color, 2 * s, true)
			"hurt": draw_line(candidate + Vector2(0, -7) * s, candidate + Vector2(0, 7) * s, color, 3 * s, true)
		return


func _draw_mark(mark: int, p: Vector2, scale_value: float) -> void:
	match mark:
		0: draw_colored_polygon(PackedVector2Array([p + Vector2(0, -10) * scale_value, p + Vector2(9, 7) * scale_value, p + Vector2(-9, 7) * scale_value]), ink)
		1: draw_rect(Rect2(p - Vector2(8, 8) * scale_value, Vector2(16, 16) * scale_value), ink, false, 2 * scale_value)
		2: draw_colored_polygon(PackedVector2Array([p + Vector2(0, -11) * scale_value, p + Vector2(8, 0) * scale_value, p + Vector2(0, 11) * scale_value, p + Vector2(-8, 0) * scale_value]), ink)
		3:
			draw_line(p - Vector2(9, 0) * scale_value, p + Vector2(9, 0) * scale_value, ink, 3 * scale_value)
			draw_line(p - Vector2(0, 9) * scale_value, p + Vector2(0, 9) * scale_value, ink, 3 * scale_value)
		4: draw_arc(p, 9 * scale_value, 0, TAU, 20, ink, 3 * scale_value, true)
		5:
			draw_line(p + Vector2(-5, -9) * scale_value, p + Vector2(-5, 9) * scale_value, ink, 3 * scale_value)
			draw_line(p + Vector2(5, -9) * scale_value, p + Vector2(5, 9) * scale_value, ink, 3 * scale_value)


func _label(text: String, p: Vector2, font_size: int, color: Color, max_width: float = 170) -> void:
	font_size = maxi(16, font_size)
	var font: Font = get_theme_default_font()
	var original: String = text
	while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width and text.length() > 4:
		text = text.left(text.length() - 2)
	if text != original:
		text += "…"
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin: Vector2 = p - Vector2(width * 0.5, 0)
	var placed := false
	for shift: Vector2 in [Vector2.ZERO, Vector2(0, 20), Vector2(0, -20), Vector2(48, 0), Vector2(-48, 0), Vector2(0, 40), Vector2(0, -40), Vector2(48, 24), Vector2(-48, 24), Vector2(0, 64), Vector2(0, -64), Vector2(80, 0), Vector2(-80, 0)]:
		var candidate := Rect2(origin + shift + Vector2(-3, -font_size), Vector2(width + 6, font_size + 9))
		if not _label_boxes.any(func(rect: Rect2) -> bool: return rect.intersects(candidate)) and Rect2(Vector2.ZERO, size).encloses(candidate):
			origin += shift
			_label_boxes.append(candidate)
			placed = true
			if shift.length() > 25:
				draw_line(p - Vector2(0, font_size * 0.5), origin + Vector2(width * 0.5, -font_size * 0.5), Color(color, 0.4), 1, true)
			break
	if not placed:
		return # Suppress a passive label instead of covering a person or another label.
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, ink)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _echo(id: String) -> Dictionary:
	for echo: Dictionary in _data.get("echoes", []):
		if echo.get("id", "") == id:
			return echo
	return {}


func _engagement(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for engagement: Dictionary in _data.get("social_engagements", []):
		if engagement.get("id", "") == id:
			return engagement
	return {}


func _incident(id: String) -> Dictionary:
	for incident: Dictionary in _data.get("incidents", []):
		if incident.get("id", "") == id:
			return incident
	return {}


func _subjects() -> Array[Dictionary]:
	var subjects: Array[Dictionary] = []
	for echo: Dictionary in _data.get("echoes", []):
		subjects.append({"kind": "echo", "id": echo.id})
	for incident: Dictionary in _data.get("incidents", []):
		subjects.append({"kind": "incident", "id": incident.id})
	for id: String in _data.get("places", {}):
		if not str(_data.places[id].node).is_empty():
			subjects.append({"kind": "place", "id": id})
	if _data.get("phase") == "setup":
		for site: Dictionary in _data.sites:
			subjects.append({"kind": "site", "id": site.id})
	return subjects


func _hits(point: Vector2) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for incident: Dictionary in _data.get("incidents", []):
		if point.distance_to(_incident_screen(incident)) <= 60 * _zoom:
			hits.append({"kind": "incident", "id": incident.id})
	for echo: Dictionary in _data.get("echoes", []):
		if point.distance_to(_echo_screen(echo)) <= 39 * _zoom:
			hits.append({"kind": "echo", "id": echo.id})
	for subject: Dictionary in _subjects():
		if subject.kind not in ["echo", "incident"] and point.distance_to(_screen(_subject_position(subject))) <= 48 * _zoom:
			if subject.kind == "site":
				hits.push_front(subject)
			else:
				hits.append(subject)
	return hits


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var screen_centre := Vector2((size.x - _reserved_width) * 0.5, size.y * 0.5)
			var world_point: Vector2 = (event.position - screen_centre - _pan) / maxf(0.01, _zoom)
			var base_zoom: float = _focus_zoom(_data.selection) if not _data.selection.is_empty() else _overview_zoom
			var requested_zoom: float = clampf(_zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.89), 0.15, 2.6)
			# Normalize against the active camera base so a wheel-down notch still
			# escapes the ceiling when a focused composition is already clamped.
			_zoom_user = clampf(requested_zoom / maxf(0.001, base_zoom), 0.01, 2.0)
			_fit_camera()
			_manual_camera = true
			_pan_target = event.position - screen_centre - world_point * _zoom_target
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				_pressed = true
				_dragged = false
				_drag_start = event.position
				_drag_pan = _pan
			else:
				_pressed = false
				if not _dragged:
					var hits: Array[Dictionary] = _hits(event.position)
					if not hits.is_empty():
						_click_cycle = (_click_cycle + 1) % hits.size() if event.position.distance_to(_last_click) < 8 else 0
						_last_click = event.position
						subject_selected.emit(hits[_click_cycle])
					else:
						subject_selected.emit({})
			accept_event()
	elif event is InputEventMouseMotion:
		var hits: Array[Dictionary] = _hits(event.position)
		_hover = hits[0] if not hits.is_empty() else {}
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if not _hover.is_empty() else CURSOR_DRAG
		if _pressed and event.position.distance_to(_drag_start) > 7:
			_dragged = true
			_manual_camera = true
			_pan_target = _drag_pan + event.position - _drag_start
	elif event is InputEventKey and event.pressed and not event.echo:
		var subjects: Array[Dictionary] = _subjects()
		if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and not subjects.is_empty():
			_manual_camera = true
			_keyboard_index = posmod(_keyboard_index + (-1 if event.keycode in [KEY_LEFT, KEY_UP] else 1), subjects.size())
			_pan_target = _focus_pan(subjects[_keyboard_index])
			accept_event()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and _keyboard_index >= 0 and _keyboard_index < subjects.size():
				subject_selected.emit(subjects[_keyboard_index])
				accept_event()


func capture_metrics(subject: Dictionary = {}) -> Dictionary:
	var target: Dictionary = subject if not subject.is_empty() else _data.get("selection", {})
	var usable := Rect2(Vector2.ZERO, Vector2(maxf(0.0, size.x - _reserved_width), size.y))
	var bounds := Rect2()
	var signature := "none"
	match str(target.get("kind", "")):
		"echo":
			var echo: Dictionary = _echo(str(target.get("id", "")))
			if not echo.is_empty():
				var diameter: float = 64.0 * _zoom
				bounds = Rect2(_echo_screen(echo) - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
		"place":
			var id: String = str(target.get("id", ""))
			var centre: Vector2 = _screen(_subject_position(target))
			var place_size := Vector2(112.0 * _zoom, 120.0 * _zoom)
			bounds = Rect2(centre - place_size * 0.5, place_size)
		"incident":
			var incident: Dictionary = _incident(str(target.get("id", "")))
			var points: Array[Vector2] = []
			for participant_id: String in incident.get("participants", []):
				var echo: Dictionary = _echo(participant_id)
				if not echo.is_empty(): points.append(_echo_screen(echo))
			if not points.is_empty():
				bounds = Rect2(points[0], Vector2.ZERO)
				for point: Vector2 in points: bounds = bounds.expand(point)
				bounds = bounds.grow(64.0 * _zoom)
			var status: String = str(incident.get("status", "warning"))
			var access: String = str(incident.get("keeper_access", "private"))
			if status == "warning":
				signature = "warning:compact_notification"
			elif status == "open" and access == "private":
				signature = "open:private_compact"
			elif status == "open" and access == "appeal":
				signature = "open:appeal+standard+tether+connectors"
			else:
				signature = status + ":standard+tether+connectors"
	var occupancy := Vector2(bounds.size.x / maxf(1.0, usable.size.x), bounds.size.y / maxf(1.0, usable.size.y))
	return {"usable_rect": usable, "subject_bounds": bounds, "occupancy": occupancy,
		"overview_echo_diameter": 64.0, "incident_standard_size": Vector2(84, 112),
		"incident_signature": signature, "minimum_world_font_size": 16, "manual_camera": _manual_camera,
		"reaction_cue_count": _reaction_cue_bounds.size(), "reaction_cue_bounds": _reaction_cue_bounds.duplicate()}
