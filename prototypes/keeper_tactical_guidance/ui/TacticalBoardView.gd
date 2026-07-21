class_name KeeperTacticalBoardView
extends Control

signal cell_selected(pos: Dictionary)
signal subject_selected(subject: Dictionary)

# The production combat board uses a 128x64 isometric TileSet. The prototype keeps the
# same 2:1 projection and clay/ink language while drawing its generated irregular topology.
const ISO_RATIO: float = 0.5
const COLOR_VOID := Color("#0b100f")
const COLOR_VOID_GRID := Color("#17201d")
const COLOR_CELL := Color("#8b4b35")
const COLOR_CELL_ALT := Color("#99533a")
const COLOR_CELL_EDGE := Color("#48271f")
const COLOR_CELL_EDGE_LIT := Color("#643328")
const COLOR_CELL_INK := Color("#321d18")
const COLOR_DEPLOYMENT := Color("#50b5c8")
const COLOR_ENEMY_ENTRY := Color("#df6256")
const COLOR_OBJECTIVE := Color("#e1b83f")
const COLOR_BURNING := Color("#ed633f")
const COLOR_UNSTABLE := Color("#a983c7")
const COLOR_BINDING := Color("#73a657")
const COLOR_ROUTE_A := Color("#65c3ce")
const COLOR_ROUTE_B := Color("#e2ad49")
const COLOR_CHOKE := Color("#e06fc5")
const COLOR_PREVIEW := Color("#f4df72")
const COLOR_PENDING := Color("#f0cf58")
const COLOR_LISTENING := Color("#63d3a1")
const COLOR_RESISTING := Color("#efa94f")
const COLOR_REJECTING := Color("#e45c58")
const COLOR_ECHO := Color("#69cddd")
const COLOR_ENEMY := Color("#ef7165")
const COLOR_STRUCTURE := Color("#e4c255")
const COLOR_TOKEN_INK := Color("#101716")
const DRAG_THRESHOLD: float = 8.0
const ZOOM_MIN: float = 0.55
const ZOOM_MAX: float = 2.2
const MOVE_SECONDS_PER_TILE: float = 0.18
const RESPONSE_REVEAL_SECONDS: float = 0.50
const ATTACK_ANTICIPATION_SECONDS: float = 0.14
const ATTACK_LUNGE_SECONDS: float = 0.10
const ATTACK_IMPACT_SECONDS: float = 0.16
const ATTACK_RECOVERY_SECONDS: float = 0.12
const DAMAGE_FLOAT_SECONDS: float = 0.45
const HAZARD_FEEDBACK_SECONDS: float = 0.22
const SPEED_MULTIPLIERS := {"slow": 0.6, "normal": 1.0, "fast": 1.8}

var _board: Dictionary = {}
var _actors: Array = []
var _ping_preview: Dictionary = {}
var _selected_cell: Dictionary = {}
var _deployment_assignments: Dictionary = {}
var _debug_visible: bool = false
var _view_phase: String = "briefing"
var _unresolved_ping: Dictionary = {}
var _last_turn_result: Dictionary = {}
var _response_feedback: Array = []
var _playback_speed_id: String = "normal"
var _show_routes: bool = false
var _show_chokepoints: bool = false
var _presented_tick: int = -1
var _animation_elapsed: float = 0.0
var _animation_duration: float = 0.0
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_origin: Vector2 = Vector2.ZERO
var _pan_origin: Vector2 = Vector2.ZERO
var _tile_width: float = 96.0
var _tile_height: float = 48.0
var _board_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	resized.connect(_recalculate_view)
	set_process(false)


func set_content(
		board: Dictionary,
		actors: Array,
		ping_preview: Dictionary = {},
		deployment_assignments: Dictionary = {},
		debug_visible: bool = false,
		view_phase: String = "briefing",
		unresolved_ping: Dictionary = {},
		last_turn_result: Dictionary = {},
		playback_speed_id: String = "normal",
		response_feedback: Array = []
	) -> void:
	_board = board.duplicate(true)
	_actors = actors.duplicate(true)
	_ping_preview = ping_preview.duplicate(true)
	_deployment_assignments = deployment_assignments.duplicate(true)
	_debug_visible = debug_visible
	_view_phase = view_phase
	_unresolved_ping = unresolved_ping.duplicate(true)
	_response_feedback = response_feedback.duplicate(true)
	_playback_speed_id = playback_speed_id if SPEED_MULTIPLIERS.has(playback_speed_id) else "normal"
	_accept_presentation_event(last_turn_result)
	set_process(is_animating() or _has_pulsing_guidance())
	_recalculate_view()
	queue_redraw()


func set_overlay_visibility(show_routes: bool, show_chokepoints: bool) -> void:
	_show_routes = show_routes
	_show_chokepoints = show_chokepoints
	queue_redraw()


func is_animating() -> bool:
	return _animation_duration > 0.0 and _animation_elapsed < _animation_duration


func get_animation_duration() -> float:
	return _animation_duration


func _process(delta: float) -> void:
	if not is_animating() and not _has_pulsing_guidance():
		set_process(false)
		return
	if is_animating():
		_animation_elapsed = minf(_animation_duration, _animation_elapsed + maxf(0.0, delta))
	queue_redraw()
	if not is_animating() and not _has_pulsing_guidance():
		set_process(false)


func _has_pulsing_guidance() -> bool:
	return not (_ping_preview.get("footprint", []) as Array).is_empty() \
		or not (_unresolved_ping.get("remaining_recipient_ids", []) as Array).is_empty()


func set_selected_cell(pos: Dictionary) -> void:
	_selected_cell = pos.duplicate(true)
	queue_redraw()


func recenter() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_recalculate_view()
	queue_redraw()


func zoom_in() -> void:
	_zoom = clampf(_zoom + 0.15, ZOOM_MIN, ZOOM_MAX)
	_recalculate_view()
	queue_redraw()


func zoom_out() -> void:
	_zoom = clampf(_zoom - 0.15, ZOOM_MIN, ZOOM_MAX)
	_recalculate_view()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_WHEEL_UP and button_event.pressed:
			zoom_in()
			accept_event()
		elif button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and button_event.pressed:
			zoom_out()
			accept_event()
		elif button_event.button_index == MOUSE_BUTTON_LEFT:
			if button_event.pressed:
				_dragging = true
				_drag_origin = button_event.position
				_pan_origin = _pan
			else:
				var was_drag := button_event.position.distance_to(_drag_origin) > DRAG_THRESHOLD
				_dragging = false
				if not was_drag:
					_select_at(button_event.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_pan = _pan_origin + motion.position - _drag_origin
		_recalculate_view()
		queue_redraw()
		accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dragging = true
			_drag_origin = touch.position
			_pan_origin = _pan
		else:
			var was_drag := touch.position.distance_to(_drag_origin) > DRAG_THRESHOLD
			_dragging = false
			if not was_drag:
				_select_at(touch.position)
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		var drag := event as InputEventScreenDrag
		_pan += drag.relative
		_recalculate_view()
		queue_redraw()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_VOID)
	_draw_void_grid()
	if _board.is_empty():
		_draw_empty_state()
		return
	_draw_cells()
	if _show_routes and _view_phase != "combat":
		_draw_routes()
	_draw_hazards()
	_draw_zones()
	_draw_preview()
	_draw_actors()
	_draw_combat_feedback()
	# Raised topology is the final world-space layer. Actors and objective tokens remain
	# logically selectable at their grid cells, but terrain in front now occludes them.
	_draw_obstacles()
	_draw_debug_marks()


func _draw_void_grid() -> void:
	var spacing := maxf(24.0, _tile_height)
	var offset := fposmod(_pan.x * 0.12, spacing)
	var x := -size.y + offset
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x + size.y, size.y), COLOR_VOID_GRID, 1.0)
		x += spacing


func _draw_empty_state() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(24.0, 42.0), "Generate a board to begin.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("#c9c5b7"))


func _draw_cells() -> void:
	var cells := _walkable_cells()
	cells.sort_custom(_sort_cell_depth)
	for cell_v in cells:
		var cell: Dictionary = cell_v if cell_v is Dictionary else {}
		var checker := (int(cell.get("col", 0)) + int(cell.get("row", 0))) % 2
		_draw_cell(cell, COLOR_CELL if checker == 0 else COLOR_CELL_ALT)


func _draw_routes() -> void:
	var routes: Array = _board.get("routes", [])
	for route_index in routes.size():
		var route: Dictionary = routes[route_index] if routes[route_index] is Dictionary else {}
		var color := COLOR_ROUTE_A if route_index % 2 == 0 else COLOR_ROUTE_B
		var route_cells: Array = route.get("cells", [])
		var points := PackedVector2Array()
		for cell_v in route_cells:
			if cell_v is Dictionary:
				draw_colored_polygon(_diamond(cell_v, _tile_width * 0.13), Color(color, 0.26))
				points.append(_cell_center(cell_v))
		if points.size() > 1:
			draw_polyline(points, Color(color, 0.92), maxf(3.0, _tile_height * 0.09), true)
			_draw_arrowhead(points[points.size() - 2], points[points.size() - 1], color)
		if not points.is_empty():
			var badge_center: Vector2 = points[mini(1, points.size() - 1)] + Vector2(0.0, -_tile_height * 0.28)
			var label := "ROUTE %s" % String.chr(65 + route_index)
			draw_string(ThemeDB.fallback_font, badge_center + Vector2(-36.0, 0.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, 72.0, maxi(10, int(_tile_height * 0.22)), Color.WHITE)


func _draw_arrowhead(from: Vector2, to: Vector2, color: Color) -> void:
	var direction := from.direction_to(to)
	if direction == Vector2.ZERO:
		return
	var side := direction.rotated(PI * 0.5)
	var length := maxf(7.0, _tile_width * 0.10)
	draw_colored_polygon(PackedVector2Array([
		to + direction * length * 0.35,
		to - direction * length + side * length * 0.55,
		to - direction * length - side * length * 0.55,
	]), color)


func _draw_obstacles() -> void:
	var obstacles: Array = _board.get("obstacles", [])
	if obstacles.is_empty():
		obstacles = _inferred_obstacles()
	var cells: Array = []
	for obstacle_v in obstacles:
		var obstacle: Dictionary = obstacle_v if obstacle_v is Dictionary else {}
		var kind := str(obstacle.get("kind", "rock"))
		for cell_v in (obstacle.get("cells", []) as Array):
			if cell_v is Dictionary:
				cells.append({"pos": cell_v, "kind": kind})
	cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_cell_depth(a.get("pos", {}), b.get("pos", {}))
	)
	for entry_v in cells:
		var entry: Dictionary = entry_v if entry_v is Dictionary else {}
		_draw_obstacle_mass(entry.get("pos", {}), str(entry.get("kind", "rock")))


func _draw_obstacle_mass(pos: Dictionary, kind: String) -> void:
	var center := _cell_center(pos)
	var half_w := _tile_width * 0.43
	var half_h := _tile_height * 0.43
	var height := _tile_height * (0.72 if kind in ["ruin", "landmark"] else 0.54)
	var top_center := center - Vector2(0.0, height)
	var top := top_center + Vector2(0.0, -half_h)
	var right := top_center + Vector2(half_w, 0.0)
	var bottom := top_center + Vector2(0.0, half_h)
	var left := top_center + Vector2(-half_w, 0.0)
	var ground_right := center + Vector2(half_w, 0.0)
	var ground_bottom := center + Vector2(0.0, half_h)
	var ground_left := center + Vector2(-half_w, 0.0)
	var top_color := Color("#657354") if kind == "vegetation" else (Color("#9a7958") if kind == "ruin" else Color("#70675d"))
	if kind == "landmark":
		top_color = Color("#b1884e")
	draw_colored_polygon(PackedVector2Array([left, bottom, ground_bottom, ground_left]), top_color.darkened(0.42))
	draw_colored_polygon(PackedVector2Array([right, bottom, ground_bottom, ground_right]), top_color.darkened(0.28))
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), top_color)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color("#211d19"), maxf(1.5, _tile_width * 0.018), true)
	var glyph := "♣" if kind == "vegetation" else ("▥" if kind == "ruin" else ("◆" if kind == "landmark" else "●"))
	var font_size := maxi(12, int(_tile_height * 0.34))
	draw_string(ThemeDB.fallback_font, top_center + Vector2(-font_size * 0.45, font_size * 0.35), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.95, 0.82, 0.9))


func _draw_hazards() -> void:
	for hazard_v in (_board.get("hazards", []) as Array):
		var hazard: Dictionary = hazard_v if hazard_v is Dictionary else {}
		var hazard_type := str(hazard.get("type", ""))
		var color := COLOR_BINDING
		if hazard_type == "burning_ground":
			color = COLOR_BURNING
		elif hazard_type == "unstable_ground":
			color = COLOR_UNSTABLE
		for cell_v in (hazard.get("cells", []) as Array):
			if not cell_v is Dictionary:
				continue
			var inset := maxf(2.0, _tile_width * 0.035)
			draw_colored_polygon(_diamond(cell_v, inset), Color(color, 0.78))
			_draw_outline(cell_v, Color.WHITE.lerp(color, 0.45), maxf(2.0, _tile_width * 0.025), inset)
			var center := _cell_center(cell_v)
			var glyph := "▲" if hazard_type == "burning_ground" else ("↝" if hazard_type == "unstable_ground" else "✣")
			var font_size := maxi(11, int(_tile_height * 0.35))
			draw_string(ThemeDB.fallback_font, center + Vector2(-font_size * 0.42, font_size * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)
			_draw_hazard_pattern(center, hazard_type, color)


func _draw_hazard_pattern(center: Vector2, hazard_type: String, color: Color) -> void:
	var span := _tile_width * 0.20
	if hazard_type == "burning_ground":
		for offset in [-0.5, 0.0, 0.5]:
			var x: float = center.x + span * offset
			draw_line(Vector2(x - 3.0, center.y + 7.0), Vector2(x + 2.0, center.y - 7.0), Color.WHITE, 1.5)
	elif hazard_type == "unstable_ground":
		draw_line(center - Vector2(span, 0.0), center + Vector2(span, 0.0), Color.WHITE, 1.5)
		draw_line(center, center - Vector2(0.0, _tile_height * 0.24), Color.WHITE, 1.5)
	else:
		draw_arc(center, span, 0.0, TAU, 16, Color.WHITE, 1.5, true)


func _draw_zones() -> void:
	var deployment_index := 0
	for slot_v in (_board.get("deployment_slots", []) as Array):
		if slot_v is Dictionary:
			deployment_index += 1
			draw_colored_polygon(_diamond(slot_v, _tile_width * 0.07), Color(COLOR_DEPLOYMENT, 0.34))
			_draw_outline(slot_v, COLOR_DEPLOYMENT, maxf(2.0, _tile_width * 0.03), _tile_width * 0.08)
			var center := _cell_center(slot_v)
			draw_string(ThemeDB.fallback_font, center + Vector2(-12.0, 5.0), str(deployment_index),
				HORIZONTAL_ALIGNMENT_CENTER, 24.0, maxi(10, int(_tile_height * 0.25)), Color.WHITE)
	for slot_v in (_board.get("enemy_slots", []) as Array):
		if slot_v is Dictionary:
			draw_colored_polygon(_diamond(slot_v, _tile_width * 0.11), Color(COLOR_ENEMY_ENTRY, 0.18))
			_draw_outline(slot_v, COLOR_ENEMY_ENTRY, maxf(2.0, _tile_width * 0.03), _tile_width * 0.08)
	if _show_chokepoints and _view_phase != "combat":
		for choke_v in (_board.get("chokepoints", []) as Array):
			var choke: Dictionary = choke_v if choke_v is Dictionary else {}
			for cell_v in (choke.get("cells", []) as Array):
				if cell_v is Dictionary:
					_draw_chokepoint_gate(cell_v)
	if not _selected_cell.is_empty():
		_draw_outline(_selected_cell, Color.WHITE, maxf(3.0, _tile_width * 0.04), _tile_width * 0.04)


func _draw_preview() -> void:
	var pulse_alpha := 0.20 + 0.10 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
	for cell_v in (_unresolved_ping.get("footprint", []) as Array):
		if cell_v is Dictionary:
			draw_colored_polygon(_diamond(cell_v, _tile_width * 0.055), Color(COLOR_PENDING, pulse_alpha))
			_draw_outline(cell_v, Color(COLOR_PENDING, 0.85), maxf(2.0, _tile_width * 0.022), _tile_width * 0.055)
	for cell_v in (_ping_preview.get("footprint", []) as Array):
		if cell_v is Dictionary:
			draw_colored_polygon(_diamond(cell_v, _tile_width * 0.035), Color(COLOR_PREVIEW, pulse_alpha + 0.12))
			_draw_outline(cell_v, COLOR_PREVIEW, maxf(2.0, _tile_width * 0.03), _tile_width * 0.035)


func _draw_chokepoint_gate(pos: Dictionary) -> void:
	var center := _cell_center(pos)
	var half_w := _tile_width * 0.34
	var half_h := _tile_height * 0.30
	draw_colored_polygon(_diamond(pos, _tile_width * 0.12), Color(COLOR_CHOKE, 0.22))
	draw_line(center + Vector2(-half_w, -half_h), center + Vector2(-half_w, half_h), COLOR_CHOKE, 4.0)
	draw_line(center + Vector2(half_w, -half_h), center + Vector2(half_w, half_h), COLOR_CHOKE, 4.0)
	draw_line(center + Vector2(-half_w, -half_h), center + Vector2(-half_w * 0.55, -half_h), COLOR_CHOKE, 4.0)
	draw_line(center + Vector2(half_w, -half_h), center + Vector2(half_w * 0.55, -half_h), COLOR_CHOKE, 4.0)


func _draw_objective() -> void:
	var objective_pos: Dictionary = _board.get("objective_pos", {})
	if objective_pos.is_empty():
		return
	var ground_center := _cell_center(objective_pos)
	var pedestal_center := ground_center + Vector2(0.0, -_tile_height * 0.18)
	var base_w := maxf(14.0, _tile_width * 0.21)
	var base_h := maxf(7.0, _tile_height * 0.2)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([
		ground_center + Vector2(0.0, -base_h), ground_center + Vector2(base_w, 0.0),
		ground_center + Vector2(0.0, base_h), ground_center + Vector2(-base_w, 0.0)
	]), Color("#2b2417"))
	var radius := maxf(8.0, _tile_width * 0.105)
	draw_circle(pedestal_center + Vector2(2.0, 4.0), radius + 3.0, Color(0.02, 0.03, 0.03, 0.68))
	draw_circle(pedestal_center, radius, Color("#352c18"))
	draw_arc(pedestal_center, radius, 0.0, TAU, 32, COLOR_OBJECTIVE, maxf(2.0, _tile_width * 0.035), true)
	draw_string(ThemeDB.fallback_font, pedestal_center + Vector2(-radius * 0.48, radius * 0.43), "◆", HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(12, int(radius * 1.2)), COLOR_OBJECTIVE)


func _draw_actors() -> void:
	var actors := _actors.duplicate(true)
	actors.sort_custom(_sort_actor_depth)
	var objective_pos: Dictionary = _board.get("objective_pos", {})
	var objective_drawn := objective_pos.is_empty()
	var objective_depth := _cell_center(objective_pos).y
	for actor_v in actors:
		var actor: Dictionary = actor_v if actor_v is Dictionary else {}
		if bool(actor.get("is_dead", false)) and not _should_present_dead_actor(str(actor.get("id", ""))):
			continue
		var pos: Dictionary = actor.get("grid_pos", {})
		if pos.is_empty():
			continue
		var actor_depth := _actor_display_ground(actor).y
		if not objective_drawn and objective_depth <= actor_depth:
			_draw_objective()
			objective_drawn = true
		var faction := str(actor.get("faction", ""))
		var is_structure := bool(actor.get("is_structure", false))
		var color := COLOR_STRUCTURE if is_structure else (COLOR_ECHO if faction == "echo" else COLOR_ENEMY)
		var ground_center := _actor_display_ground(actor)
		ground_center += _hit_reaction_offset(str(actor.get("id", "")))
		var token_center := ground_center + Vector2(0.0, -_tile_height * (0.12 if is_structure else 0.34))
		var radius := maxf(7.0, _tile_width * (0.105 if is_structure else 0.12))
		_draw_token_shadow(ground_center, radius)
		if is_structure:
			_draw_structure_token(token_center, radius, color)
		else:
			draw_circle(token_center, radius + 2.5, COLOR_TOKEN_INK)
			draw_circle(token_center, radius, color)
			draw_arc(token_center, radius - 2.0, PI * 1.05, PI * 1.8, 12, Color(1, 1, 1, 0.28), 1.5, true)
		var label := str(actor.get("name", "?")).left(1).to_upper()
		var font_size := maxi(11, int(radius * 1.15))
		draw_string(ThemeDB.fallback_font, token_center + Vector2(-radius, font_size * 0.34), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, COLOR_TOKEN_INK)
		_draw_actor_hp(actor, token_center, radius)
		var actor_id := str(actor.get("id", ""))
		if _ping_preview.get("eligible_recipient_ids", []).has(actor_id):
			draw_arc(ground_center, radius + 6.0, 0.0, TAU, 32, COLOR_PREVIEW, maxf(2.0, _tile_width * 0.03), true)
		_draw_guidance_marker(actor, ground_center, radius)
	if not objective_drawn:
		_draw_objective()


func _draw_guidance_marker(actor: Dictionary, center: Vector2, radius: float) -> void:
	var actor_id := str(actor.get("id", ""))
	var pending: Array = _unresolved_ping.get("remaining_recipient_ids", [])
	var guidance_state := str(actor.get("guidance_state", "unaffected"))
	if actor_id in pending:
		guidance_state = "pending"
	var color := Color.TRANSPARENT
	var glyph := ""
	match guidance_state:
		"pending":
			color = COLOR_PENDING
			glyph = "?"
		"listening":
			color = COLOR_LISTENING
			glyph = "✓"
		"resisting":
			color = COLOR_RESISTING
			glyph = "!"
		"rejecting":
			color = COLOR_REJECTING
			glyph = "×"
	if glyph.is_empty():
		return
	var pulse := 1.0 + 0.07 * sin(Time.get_ticks_msec() * 0.008) if guidance_state == "pending" else 1.0
	draw_arc(center, (radius + 8.0) * pulse, 0.0, TAU, 32, color, maxf(3.0, _tile_width * 0.035), true)
	var badge := center + Vector2(radius + 5.0, -radius - 8.0)
	draw_circle(badge, maxf(7.0, radius * 0.42), Color("#101716"))
	draw_circle(badge, maxf(5.0, radius * 0.34), color)
	draw_string(ThemeDB.fallback_font, badge + Vector2(-6.0, 5.0), glyph,
		HORIZONTAL_ALIGNMENT_CENTER, 12.0, maxi(10, int(radius * 0.75)), Color("#101716"))


func _draw_token_shadow(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius * 1.15, sin(angle) * radius * 0.38))
	draw_colored_polygon(points, Color(0.01, 0.02, 0.02, 0.62))


func _draw_structure_token(center: Vector2, radius: float, color: Color) -> void:
	var half_h := radius * 0.62
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -half_h), center + Vector2(radius, 0.0),
		center + Vector2(0.0, half_h), center + Vector2(-radius, 0.0)
	]), color)
	draw_polyline(PackedVector2Array([
		center + Vector2(0.0, -half_h), center + Vector2(radius, 0.0),
		center + Vector2(0.0, half_h), center + Vector2(-radius, 0.0),
		center + Vector2(0.0, -half_h)
	]), COLOR_TOKEN_INK, 2.0, true)


func _draw_actor_hp(actor: Dictionary, center: Vector2, radius: float) -> void:
	if bool(actor.get("is_structure", false)) and int(actor.get("current_hp", 0)) <= 0:
		return
	var stats: Dictionary = actor.get("stats", {})
	var max_hp := maxf(1.0, float(stats.get("max_hp", actor.get("max_hp", 1))))
	var ratio := clampf(float(actor.get("current_hp", max_hp)) / max_hp, 0.0, 1.0)
	var bar_size := Vector2(radius * 2.15, maxf(3.0, _tile_height * 0.07))
	var bar_rect := Rect2(center + Vector2(-bar_size.x * 0.5, -radius - bar_size.y - 4.0), bar_size)
	draw_rect(bar_rect, Color(0.03, 0.04, 0.04, 0.9), true)
	var hp_color := Color("#63bf73") if ratio > 0.5 else (Color("#e5ad45") if ratio > 0.25 else Color("#e25c51"))
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), hp_color, true)


func _accept_presentation_event(event: Dictionary) -> void:
	_last_turn_result = event.duplicate(true)
	if _view_phase != "combat" or event.is_empty():
		return
	var tick := int(event.get("tick", -1))
	if tick < 0 or tick == _presented_tick:
		return
	_presented_tick = tick
	_animation_elapsed = 0.0
	_animation_duration = _calculate_animation_duration(event)
	set_process(_animation_duration > 0.0)


func _calculate_animation_duration(event: Dictionary) -> float:
	var scale := _duration_scale()
	var total := RESPONSE_REVEAL_SECONDS * scale if not (event.get("ping_response", {}) as Dictionary).is_empty() else 0.0
	var path := _presentation_path(event)
	total += maxf(0.0, float(path.size() - 1) * MOVE_SECONDS_PER_TILE * scale)
	if not (event.get("hazard_events", []) as Array).is_empty():
		total += HAZARD_FEEDBACK_SECONDS * scale
	if _event_has_attack(event):
		var attack_sequence := ATTACK_ANTICIPATION_SECONDS + ATTACK_LUNGE_SECONDS \
			+ ATTACK_IMPACT_SECONDS + ATTACK_RECOVERY_SECONDS
		var damage_readability := ATTACK_ANTICIPATION_SECONDS + ATTACK_LUNGE_SECONDS + DAMAGE_FLOAT_SECONDS
		total += maxf(attack_sequence, damage_readability) * scale
	var follow_ups := _follow_up_beats(event)
	var action_type := str(event.get("action_type", ""))
	var attack_beats_seen := 1 if action_type in ["attack", "melee_attack", "actor.attack"] \
		or not str(event.get("target_id", "")).is_empty() else 0
	for beat_v in follow_ups:
		var beat: Dictionary = beat_v if beat_v is Dictionary else {}
		if str(beat.get("type", "")).contains("attack") or int(beat.get("damage", 0)) > 0:
			if attack_beats_seen >= 1:
				total += (ATTACK_LUNGE_SECONDS + ATTACK_IMPACT_SECONDS) * scale
			attack_beats_seen += 1
	return maxf(total, 0.01)


func _duration_scale() -> float:
	var speed_multiplier := float(SPEED_MULTIPLIERS.get(_playback_speed_id, 1.0))
	return 1.0 / maxf(0.01, speed_multiplier)


func _presentation_path(event: Dictionary) -> Array:
	var result: Array = []
	var from_pos: Dictionary = event.get("from_pos", {})
	if not from_pos.is_empty():
		result.append(from_pos.duplicate())
	for pos_v in (event.get("path", []) as Array):
		if pos_v is Dictionary and (result.is_empty() or result[result.size() - 1] != pos_v):
			result.append(pos_v.duplicate())
	var to_pos: Dictionary = event.get("to_pos", {})
	if not to_pos.is_empty() and (result.is_empty() or result[result.size() - 1] != to_pos):
		result.append(to_pos.duplicate())
	return result


func _actor_display_ground(actor: Dictionary) -> Vector2:
	var logical_pos: Dictionary = actor.get("grid_pos", {})
	var actor_id := str(actor.get("id", ""))
	if not is_animating() or actor_id != str(_last_turn_result.get("actor_id", "")):
		return _cell_center(logical_pos)
	var elapsed := _animation_elapsed
	if not (_last_turn_result.get("ping_response", {}) as Dictionary).is_empty():
		elapsed -= RESPONSE_REVEAL_SECONDS * _duration_scale()
	if elapsed <= 0.0:
		return _cell_center(_last_turn_result.get("from_pos", logical_pos))
	var path := _presentation_path(_last_turn_result)
	var move_duration := maxf(0.0, float(path.size() - 1) * MOVE_SECONDS_PER_TILE * _duration_scale())
	var ground := _cell_center(logical_pos)
	if path.size() >= 2 and elapsed < move_duration:
		var segment_duration := MOVE_SECONDS_PER_TILE * _duration_scale()
		var segment := mini(path.size() - 2, int(elapsed / maxf(segment_duration, 0.001)))
		var local_ratio := fposmod(elapsed, segment_duration) / segment_duration
		ground = _cell_center(path[segment]).lerp(_cell_center(path[segment + 1]), ease(local_ratio, -1.5))
	elif not path.is_empty():
		ground = _cell_center(path[path.size() - 1])
	var hazard_duration := HAZARD_FEEDBACK_SECONDS * _duration_scale() \
		if not (_last_turn_result.get("hazard_events", []) as Array).is_empty() else 0.0
	var attack_elapsed := elapsed - move_duration - hazard_duration
	if attack_elapsed >= 0.0 and _event_has_attack(_last_turn_result):
		ground += _attacker_lunge_offset(actor_id, attack_elapsed)
	return ground


func _attacker_lunge_offset(actor_id: String, attack_elapsed: float) -> Vector2:
	var target_id := str(_last_turn_result.get("target_id", ""))
	if target_id.is_empty():
		for beat_v in _follow_up_beats(_last_turn_result):
			if beat_v is Dictionary and str(beat_v.get("source_id", "")) == actor_id:
				target_id = str(beat_v.get("target_id", ""))
				break
	var target := _actor_by_id(target_id)
	var source := _actor_by_id(actor_id)
	if target.is_empty() or source.is_empty():
		return Vector2.ZERO
	var scale := _duration_scale()
	var anticipation := ATTACK_ANTICIPATION_SECONDS * scale
	var lunge := ATTACK_LUNGE_SECONDS * scale
	var impact := ATTACK_IMPACT_SECONDS * scale
	if attack_elapsed < anticipation or attack_elapsed > anticipation + lunge + impact:
		return Vector2.ZERO
	var ratio := clampf((attack_elapsed - anticipation) / maxf(lunge + impact, 0.001), 0.0, 1.0)
	var direction := _cell_center(source.get("grid_pos", {})).direction_to(_cell_center(target.get("grid_pos", {})))
	return direction * sin(ratio * PI) * _tile_width * 0.22


func _hit_reaction_offset(actor_id: String) -> Vector2:
	if not is_animating() or actor_id != _attack_target_id():
		return Vector2.ZERO
	var impact_progress := _impact_progress()
	if impact_progress < 0.0 or impact_progress > 1.0:
		return Vector2.ZERO
	var amplitude := _tile_width * 0.055 * (1.0 - impact_progress)
	return Vector2(sin(impact_progress * TAU * 3.0) * amplitude, 0.0)


func _draw_combat_feedback() -> void:
	if not is_animating():
		return
	var response: Dictionary = _last_turn_result.get("ping_response", {})
	var response_duration := RESPONSE_REVEAL_SECONDS * _duration_scale()
	if not response.is_empty() and _animation_elapsed <= response_duration:
		_draw_response_callout(response)
	_draw_hazard_feedback()
	var target_id := _attack_target_id()
	var damage := _attack_damage()
	var impact_progress := _impact_progress()
	if target_id.is_empty() or damage <= 0 or impact_progress < 0.0:
		return
	var target := _actor_by_id(target_id)
	if target.is_empty():
		return
	var center := _cell_center(target.get("grid_pos", {})) + Vector2(0.0, -_tile_height * 0.45)
	if impact_progress <= 1.0:
		draw_circle(center, maxf(8.0, _tile_width * 0.16) * (1.0 - impact_progress * 0.35), Color(1.0, 0.92, 0.72, 0.48 * (1.0 - impact_progress)))
		var slash := Vector2(_tile_width * 0.18, _tile_height * 0.28)
		draw_line(center - slash, center + slash, Color.WHITE, maxf(3.0, _tile_width * 0.04))
	var float_ratio := clampf(impact_progress * (ATTACK_IMPACT_SECONDS / DAMAGE_FLOAT_SECONDS), 0.0, 1.0)
	var damage_pos := center + Vector2(0.0, -12.0 - _tile_height * 0.65 * float_ratio)
	draw_string(ThemeDB.fallback_font, damage_pos + Vector2(-24.0, 0.0), "-%d" % damage,
		HORIZONTAL_ALIGNMENT_CENTER, 48.0, maxi(16, int(_tile_height * 0.42)), Color(1.0, 0.86, 0.66, 1.0 - float_ratio * 0.7))


func _draw_hazard_feedback() -> void:
	var hazards: Array = _last_turn_result.get("hazard_events", [])
	if hazards.is_empty():
		return
	var elapsed := _animation_elapsed
	if not (_last_turn_result.get("ping_response", {}) as Dictionary).is_empty():
		elapsed -= RESPONSE_REVEAL_SECONDS * _duration_scale()
	var path := _presentation_path(_last_turn_result)
	elapsed -= maxf(0.0, float(path.size() - 1) * MOVE_SECONDS_PER_TILE * _duration_scale())
	var duration := HAZARD_FEEDBACK_SECONDS * _duration_scale()
	if elapsed < 0.0 or elapsed > duration:
		return
	var ratio := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	for event_v in hazards:
		var event: Dictionary = event_v if event_v is Dictionary else {}
		var pos: Dictionary = event.get("final_pos", event.get("entered_pos", event.get("position", event.get("cell", {}))))
		if pos.is_empty():
			pos = _last_turn_result.get("to_pos", {})
		var center := _cell_center(pos)
		var hazard_type := str(event.get("hazard_type", event.get("type", "hazard")))
		var color := COLOR_BURNING if hazard_type.contains("burn") else (COLOR_UNSTABLE if hazard_type.contains("unstable") else COLOR_BINDING)
		draw_arc(center, _tile_width * (0.14 + ratio * 0.18), 0.0, TAU, 32, Color(color, 1.0 - ratio), maxf(3.0, _tile_width * 0.04), true)
		var label := "HAZARD" if hazard_type == "hazard" else hazard_type.replace("_", " ").to_upper()
		draw_string(ThemeDB.fallback_font, center + Vector2(-48.0, -_tile_height * 0.45), label,
			HORIZONTAL_ALIGNMENT_CENTER, 96.0, maxi(10, int(_tile_height * 0.22)), Color.WHITE)


func _draw_response_callout(response: Dictionary) -> void:
	var actor := _actor_by_id(str(response.get("actor_id", "")))
	if actor.is_empty():
		return
	var center := _cell_center(_last_turn_result.get("from_pos", actor.get("grid_pos", {}))) + Vector2(0.0, -_tile_height * 0.92)
	var outcome := str(response.get("outcome", "")).capitalize()
	var reason := str(response.get("primary_reason", ""))
	var text := outcome if reason.is_empty() else "%s — %s" % [outcome, reason]
	var color := COLOR_LISTENING if str(response.get("outcome", "")) in ["align", "interpret"] else (COLOR_REJECTING if str(response.get("outcome", "")) == "refuse" else COLOR_RESISTING)
	var width := minf(260.0, maxf(120.0, text.length() * 6.5))
	var rect := Rect2(center + Vector2(-width * 0.5, -26.0), Vector2(width, 30.0))
	draw_rect(rect, Color("#101716"), true)
	draw_rect(rect, color, false, 2.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-width * 0.5 + 8.0, -6.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, width - 16.0, maxi(11, int(_tile_height * 0.24)), Color.WHITE)


func _draw_debug_marks() -> void:
	if not _debug_visible:
		return
	for choke_v in (_board.get("chokepoints", []) as Array):
		var choke: Dictionary = choke_v if choke_v is Dictionary else {}
		for cell_v in (choke.get("cells", []) as Array):
			if cell_v is Dictionary:
				var center := _cell_center(cell_v)
				var mark_size := maxf(6.0, _tile_width * 0.08)
				draw_line(center + Vector2(-mark_size, -mark_size * ISO_RATIO), center + Vector2(mark_size, mark_size * ISO_RATIO), Color.MAGENTA, 3.0)
				draw_line(center + Vector2(mark_size, -mark_size * ISO_RATIO), center + Vector2(-mark_size, mark_size * ISO_RATIO), Color.MAGENTA, 3.0)


func _draw_cell(pos: Dictionary, color: Color) -> void:
	var center := _cell_center(pos)
	var half_w := _tile_width * 0.5
	var half_h := _tile_height * 0.5
	var depth := maxf(3.0, _tile_height * 0.16)
	var top := center + Vector2(0.0, -half_h)
	var right := center + Vector2(half_w, 0.0)
	var bottom := center + Vector2(0.0, half_h)
	var left := center + Vector2(-half_w, 0.0)
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + Vector2(0.0, depth), left + Vector2(0.0, depth)]), COLOR_CELL_EDGE)
	draw_colored_polygon(PackedVector2Array([right, bottom, bottom + Vector2(0.0, depth), right + Vector2(0.0, depth)]), COLOR_CELL_EDGE_LIT)
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), color)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(COLOR_CELL_INK, 0.78), maxf(1.0, _tile_width * 0.012), true)


func _draw_outline(pos: Dictionary, color: Color, width: float, inset: float = 2.0) -> void:
	var points := _diamond(pos, inset)
	points.append(points[0])
	draw_polyline(points, color, width, true)


func _select_at(local_pos: Vector2) -> void:
	if _tile_width <= 0.0 or _tile_height <= 0.0:
		return
	var pos := _screen_to_cell(local_pos)
	var key := "%d,%d" % [int(pos.get("col", -1)), int(pos.get("row", -1))]
	var walkable: Dictionary = _board.get("walkable", {})
	if not walkable.is_empty() and not bool(walkable.get(key, false)):
		return
	for actor_v in _actors:
		var actor: Dictionary = actor_v if actor_v is Dictionary else {}
		if actor.get("grid_pos", {}) == pos and not bool(actor.get("is_dead", false)):
			# Preparation has one assignment interaction: roster Echo, then deployment cell.
			# Board Echoes are positional display only. The underlying slot remains a valid
			# destination so roster-selected Echoes can swap assignments deterministically.
			if _view_phase == "preparation" and str(actor.get("faction", "")) == "echo":
				_selected_cell = pos
				queue_redraw()
				cell_selected.emit(pos.duplicate(true))
				return
			_selected_cell = pos
			queue_redraw()
			cell_selected.emit(pos.duplicate(true))
			subject_selected.emit({"type": "actor", "actor_id": str(actor.get("id", "")), "pos": pos.duplicate(true)})
			return
	_selected_cell = pos
	queue_redraw()
	cell_selected.emit(pos.duplicate(true))
	subject_selected.emit({"type": "cell", "pos": pos.duplicate(true)})


func _screen_to_cell(screen_pos: Vector2) -> Dictionary:
	var delta := screen_pos - _board_origin
	var half_w := _tile_width * 0.5
	var half_h := _tile_height * 0.5
	var projected_col := 0.5 * (delta.x / half_w + delta.y / half_h)
	var projected_row := 0.5 * (delta.y / half_h - delta.x / half_w)
	return {"col": int(round(projected_col)), "row": int(round(projected_row))}


func _recalculate_view() -> void:
	var bounds: Dictionary = _board.get("bounds", {})
	var columns := maxi(1, int(bounds.get("w", 12)))
	var rows := maxi(1, int(bounds.get("h", 10)))
	var diagonal_span := float(columns + rows)
	var fit_width := maxf(32.0, (size.x * 1.82) / diagonal_span)
	var fit_height := maxf(32.0, (size.y * 3.25) / diagonal_span)
	_tile_width = clampf(minf(fit_width, fit_height) * _zoom, 32.0, 132.0)
	_tile_height = _tile_width * ISO_RATIO
	var board_mid := {"col": (float(columns) - 1.0) * 0.5, "row": (float(rows) - 1.0) * 0.5}
	var mid_projection := _project_raw(float(board_mid["col"]), float(board_mid["row"]))
	_board_origin = size * 0.5 - mid_projection + _pan


func _walkable_cells() -> Array:
	var cells: Array = _board.get("cells", [])
	if not cells.is_empty():
		return cells.duplicate(true)
	var result: Array = []
	for key_v in (_board.get("walkable", {}) as Dictionary).keys():
		var bits: PackedStringArray = str(key_v).split(",")
		if bits.size() == 2:
			result.append({"col": int(bits[0]), "row": int(bits[1])})
	return result


func _inferred_obstacles() -> Array:
	var bounds: Dictionary = _board.get("bounds", {})
	var columns := int(bounds.get("w", 0))
	var rows := int(bounds.get("h", 0))
	var walkable: Dictionary = _board.get("walkable", {})
	var cells: Array = []
	for row in range(rows):
		for col in range(columns):
			var key := "%d,%d" % [col, row]
			if bool(walkable.get(key, false)):
				continue
			var adjacent_count := 0
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var neighbor_key := "%d,%d" % [col + offset.x, row + offset.y]
				if bool(walkable.get(neighbor_key, false)):
					adjacent_count += 1
			if adjacent_count >= 2:
				cells.append({"col": col, "row": row})
	if cells.is_empty():
		return []
	return [{"id": "inferred_topology", "kind": "rock", "label": "Blocked ground", "cells": cells}]


func _event_has_attack(event: Dictionary) -> bool:
	var action_type := str(event.get("action_type", ""))
	if action_type in ["attack", "melee_attack", "actor.attack"] or not str(event.get("target_id", "")).is_empty():
		return true
	for beat_v in _follow_up_beats(event):
		if beat_v is Dictionary:
			var beat: Dictionary = beat_v
			if str(beat.get("type", "")).contains("attack") or int(beat.get("damage", 0)) > 0:
				return true
	return false


func _follow_up_beats(event: Dictionary) -> Array:
	var raw: Variant = event.get("follow_up", [])
	if raw is Array:
		return raw
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		return [raw]
	return []


func _attack_target_id() -> String:
	var target_id := str(_last_turn_result.get("target_id", ""))
	if not target_id.is_empty():
		return target_id
	for beat_v in _follow_up_beats(_last_turn_result):
		if beat_v is Dictionary and int(beat_v.get("damage", 0)) > 0:
			return str(beat_v.get("target_id", ""))
	return ""


func _attack_damage() -> int:
	var damage := int(_last_turn_result.get("damage", 0))
	if damage > 0:
		return damage
	for beat_v in _follow_up_beats(_last_turn_result):
		if beat_v is Dictionary and int(beat_v.get("damage", 0)) > 0:
			return int(beat_v.get("damage", 0))
	return 0


func _impact_progress() -> float:
	if not is_animating() or not _event_has_attack(_last_turn_result):
		return -1.0
	var elapsed := _animation_elapsed
	if not (_last_turn_result.get("ping_response", {}) as Dictionary).is_empty():
		elapsed -= RESPONSE_REVEAL_SECONDS * _duration_scale()
	var path := _presentation_path(_last_turn_result)
	elapsed -= maxf(0.0, float(path.size() - 1) * MOVE_SECONDS_PER_TILE * _duration_scale())
	if not (_last_turn_result.get("hazard_events", []) as Array).is_empty():
		elapsed -= HAZARD_FEEDBACK_SECONDS * _duration_scale()
	elapsed -= (ATTACK_ANTICIPATION_SECONDS + ATTACK_LUNGE_SECONDS) * _duration_scale()
	if elapsed < 0.0:
		return -1.0
	return elapsed / maxf(ATTACK_IMPACT_SECONDS * _duration_scale(), 0.001)


func _actor_by_id(actor_id: String) -> Dictionary:
	if actor_id.is_empty():
		return {}
	for actor_v in _actors:
		if actor_v is Dictionary and str(actor_v.get("id", "")) == actor_id:
			return actor_v
	return {}


func _should_present_dead_actor(actor_id: String) -> bool:
	return is_animating() and actor_id == _attack_target_id()


func _project_raw(col: float, row: float) -> Vector2:
	return Vector2((col - row) * _tile_width * 0.5, (col + row) * _tile_height * 0.5)


func _cell_center(pos: Dictionary) -> Vector2:
	return _board_origin + _project_raw(float(pos.get("col", 0)), float(pos.get("row", 0)))


func _diamond(pos: Dictionary, inset: float = 0.0) -> PackedVector2Array:
	var center := _cell_center(pos)
	var half_w := maxf(2.0, _tile_width * 0.5 - inset)
	var half_h := maxf(1.0, _tile_height * 0.5 - inset * ISO_RATIO)
	return PackedVector2Array([
		center + Vector2(0.0, -half_h), center + Vector2(half_w, 0.0),
		center + Vector2(0.0, half_h), center + Vector2(-half_w, 0.0)
	])


func _sort_cell_depth(a: Variant, b: Variant) -> bool:
	var cell_a: Dictionary = a if a is Dictionary else {}
	var cell_b: Dictionary = b if b is Dictionary else {}
	var depth_a := int(cell_a.get("col", 0)) + int(cell_a.get("row", 0))
	var depth_b := int(cell_b.get("col", 0)) + int(cell_b.get("row", 0))
	if depth_a == depth_b:
		return int(cell_a.get("col", 0)) < int(cell_b.get("col", 0))
	return depth_a < depth_b


func _sort_actor_depth(a: Variant, b: Variant) -> bool:
	var actor_a: Dictionary = a if a is Dictionary else {}
	var actor_b: Dictionary = b if b is Dictionary else {}
	var pos_a: Dictionary = actor_a.get("grid_pos", {})
	var pos_b: Dictionary = actor_b.get("grid_pos", {})
	var depth_a := _actor_display_ground(actor_a).y
	var depth_b := _actor_display_ground(actor_b).y
	if depth_a == depth_b:
		return int(pos_a.get("col", 0)) < int(pos_b.get("col", 0))
	return depth_a < depth_b
