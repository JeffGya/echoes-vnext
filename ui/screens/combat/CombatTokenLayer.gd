# res://ui/screens/combat/CombatTokenLayer.gd
# GRID-002: Draws faction-coloured placeholder actor tokens on the combat board.

class_name CombatTokenLayer
extends Node2D

const CombatTokenVisualConfigScript := preload("res://ui/screens/combat/CombatTokenVisualConfig.gd")
const CombatTokenPresentationStateScript := preload("res://ui/screens/combat/CombatTokenPresentationState.gd")
const MotionScript := preload("res://ui/screens/combat/CombatStopShortMotion.gd")
const FONT_SIZE: int = 14

signal actor_settled(actor_id: String)

const FACTION_COLORS: Dictionary = {
	"echo":      Color(0.20, 0.45, 0.90),
	"enemy":     Color(0.90, 0.20, 0.20),
	"structure": Color(0.50, 0.50, 0.50),
	"npc":       Color(0.20, 0.70, 0.35),
}

@export var visual_config = CombatTokenVisualConfigScript.new()

var _tokens: Array[Dictionary] = []
var _active_actor_id: String = ""
var _presentation_state = CombatTokenPresentationStateScript.new()
var _last_zoom: float = 1.0


func _ready() -> void:
	if visual_config == null:
		visual_config = CombatTokenVisualConfigScript.new()


## V2-COMBAT-002 Slice 6D: `move_path_cells` are board-local cell centres (the exact
## `_board.map_to_local()` output the caller already uses for each token's `cell_pos`).
## They are converted to pixel waypoints here through `_draw_pos`, the same function
## that produces every token's `draw_pos`, so a waypoint for cell X is pixel-identical
## to the `draw_pos` a token standing on X receives.
func apply_snapshot(tokens: Array[Dictionary], active_actor_id: String = "", last_actor_action: Dictionary = {}, move_path_cells: Array[Vector2] = []) -> Dictionary:
	if visual_config == null:
		visual_config = CombatTokenVisualConfigScript.new()

	_tokens = _normalize_tokens(tokens)
	_active_actor_id = active_actor_id
	_presentation_state.motion_scale = visual_config.motion_scale
	var benefit: String = str((last_actor_action.get("stop_short", {}) as Dictionary).get("benefit", ""))
	var telegraph_event: Dictionary = _presentation_state.apply_snapshot(
		_tokens,
		last_actor_action,
		visual_config.telegraph_lead_time,
		_path_draw_positions(move_path_cells, str(last_actor_action.get("source_id", ""))),
		MotionScript.settle_time(benefit, visual_config.motion_scale)
	)
	for tok in _tokens:
		var actor_id: String = str(tok.get("actor_id", ""))
		if _presentation_state.stop_pose(actor_id) == "guard" and not _presentation_state.has_pose_angle(actor_id):
			_presentation_state.set_pose_angle(actor_id, nearest_enemy_angle(_tokens, actor_id))
	queue_redraw()
	return telegraph_event


func clear_tokens() -> void:
	_tokens = []
	_active_actor_id = ""
	queue_redraw()


func reset_presentation() -> void:
	clear_tokens()
	_presentation_state.reset()


## The token's drawn position in board space, with the feet offset removed, so it compares with
## map_to_local() of a cell. Vector2.INF when the actor has no token.
func display_cell_position(actor_id: String) -> Vector2:
	if not _presentation_state.has_actor(actor_id):
		return Vector2.INF
	var drawn: Vector2 = _presentation_state.get_display_position(actor_id, Vector2.ZERO)
	for tok in _tokens:
		if str(tok.get("actor_id", "")) == actor_id:
			return drawn if bool(tok.get("is_structure", false)) else drawn - Vector2(0.0, visual_config.feet_offset_y)
	return drawn


func is_settled(actor_id: String) -> bool:
	return _presentation_state.is_settled(actor_id)


func _process(delta: float) -> void:
	_presentation_state.motion_scale = visual_config.motion_scale
	var zoom: float = _view_zoom()
	if _presentation_state.advance(delta) or not is_equal_approx(zoom, _last_zoom):
		_last_zoom = zoom
		queue_redraw()
	for settled_id in _presentation_state.take_settled():
		actor_settled.emit(settled_id)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var zoom: float = _view_zoom()

	for tok in _tokens:
		var actor_id: String = str(tok.get("actor_id", ""))
		var is_structure: bool = bool(tok.get("is_structure", false))
		var extent: float = _token_extent(tok)
		var base_pos: Vector2 = _presentation_state.get_display_position(actor_id, tok.get("draw_pos", Vector2.ZERO))
		# Hop and rest pose move the body; the shadow keeps the ground (the pose offset only).
		var body: Dictionary = _body_motion(actor_id, float(tok.get("hop_lift", 0.0)), zoom)
		var pos: Vector2 = base_pos + (body["rest"] as Vector2) + Vector2(float(body["shake"]), -float(body["rise"]))
		var body_k: float = float(body["scale"])
		var fill_color: Color = _faction_color(str(tok.get("faction", "")))

		if not is_structure:
			var air: float = float(body["air"])
			draw_ellipse(
				base_pos + (body["rest"] as Vector2) + visual_config.shadow_offset,
				visual_config.shadow_size.x * 0.5 * body_k * (1.0 - 0.3 * air),
				visual_config.shadow_size.y * 0.5 * body_k,
				Color(visual_config.shadow_color, visual_config.shadow_color.a + 0.12 * maxf(air, 0.0))
			)
			draw_circle(pos, extent * body_k, fill_color)
			draw_arc(pos, extent * body_k, 0.0, TAU, 32, Color(0, 0, 0, 0.7), 2.0, true)
		else:
			draw_rect(
				Rect2(
					pos - Vector2(extent, extent),
					Vector2(extent * 2.0, extent * 2.0)
				),
				fill_color
			)

		draw_string(
			font,
			Vector2(pos.x - extent, pos.y + FONT_SIZE * 0.35),
			str(tok.get("label", "??")),
			HORIZONTAL_ALIGNMENT_CENTER,
			extent * 2.0,
			FONT_SIZE,
			Color.WHITE
		)

		if not _active_actor_id.is_empty() and actor_id == _active_actor_id:
			draw_arc(
				pos,
				extent + visual_config.active_ring_padding,
				0.0,
				TAU,
				32,
				visual_config.active_ring_color,
				visual_config.active_ring_width,
				true
			)

		# V2-STAGE-004 P3b: Quarry gets a gold diamond badge so it's immediately identifiable.
		if bool(tok.get("is_quarry", false)):
			var badge_size: float = visual_config.token_radius * 0.55
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0.0, -badge_size),
				pos + Vector2(badge_size, 0.0),
				pos + Vector2(0.0, badge_size),
				pos + Vector2(-badge_size, 0.0),
			]), Color(1.0, 0.7, 0.0, 0.9))

		# V2-STAGE-004 P3c: GUIDE_SPIRIT gets a soft radiant gold halo — a sacred nimbus
		# ringing the token — so the escorted spirit reads distinctly from party echoes
		# (blue circles) and enemies. Deliberately NOT the quarry's solid diamond: a ring,
		# not a filled shape. Draws over both the structure square and the joined echo circle.
		if bool(tok.get("is_spirit", false)):
			var halo_r: float = extent + visual_config.spirit_halo_padding
			# Faint filled glow disc behind the token for presence at small sizes.
			draw_circle(pos, halo_r, visual_config.spirit_halo_inner_color)
			# Two concentric gold rings form the nimbus (bright inner, softer outer).
			draw_arc(pos, halo_r, 0.0, TAU, 40,
				visual_config.spirit_halo_color, visual_config.spirit_halo_width, true)
			draw_arc(pos, halo_r + visual_config.spirit_halo_width + 1.5, 0.0, TAU, 40,
				Color(visual_config.spirit_halo_color.r, visual_config.spirit_halo_color.g,
					visual_config.spirit_halo_color.b, visual_config.spirit_halo_color.a * 0.45),
				visual_config.spirit_halo_width * 0.7, true)

		# V2-STAGE-004 Phase 4 (S15 UI-B): joined-ally token ring — a single crisp Mist
		# Blue ring (no fill), distinct from the spirit's soft filled gold nimbus above
		# and the quarry's solid gold diamond below. Faction colour (echo blue) already
		# distinguishes an ally from enemies; this ring further distinguishes the ally
		# from ordinary joined echoes.
		if bool(tok.get("is_ally", false)):
			var ally_ring_r: float = extent + visual_config.ally_ring_padding
			draw_arc(pos, ally_ring_r, 0.0, TAU, 36,
				visual_config.ally_ring_color, visual_config.ally_ring_width, true)

		var damage_text: String = str(tok.get("damage_text", ""))
		if not damage_text.is_empty():
			draw_string(
				font,
				Vector2(pos.x - extent, pos.y - extent - 16.0),
				damage_text,
				HORIZONTAL_ALIGNMENT_CENTER,
				extent * 2.0,
				FONT_SIZE,
				Color.RED
			)

	# Second pass: a neighbour drawn later must not cover a stance marker.
	for tok in _tokens:
		_draw_stance(tok, font, zoom)
	# Third pass: the HP bar stays readable on top of any marker.
	for tok in _tokens:
		_draw_hp_bar(tok, zoom)


func _draw_hp_bar(tok: Dictionary, zoom: float) -> void:
	# V2-STAGE-004: suppress HP bar for the invulnerable RECOVER relic.
	# The destructible PROTECT totem keeps its HP bar (is_objective_relic is false for it).
	if bool(tok.get("is_objective_relic", false)):
		return
	var actor_id: String = str(tok.get("actor_id", ""))
	var extent: float = _token_extent(tok)
	var body: Dictionary = _body_motion(actor_id, float(tok.get("hop_lift", 0.0)), zoom)
	var base_pos: Vector2 = _presentation_state.get_display_position(actor_id, tok.get("draw_pos", Vector2.ZERO))
	# The bar rides the hop and the lean but not the landing shake.
	var bar_pos: Vector2 = base_pos + (body["rest"] as Vector2) - Vector2(0.0, float(body["rise"]))
	var hp_ratio: float = clampf(float(tok.get("hp_ratio", 1.0)), 0.0, 1.0)
	var bar_w: float = extent * 2.0
	var bar_x: float = bar_pos.x - extent
	var bar_y: float = bar_pos.y - extent - visual_config.hp_bar_offset_y
	draw_rect(Rect2(bar_x, bar_y, bar_w, visual_config.hp_bar_height), visual_config.hp_bar_background_color)
	if hp_ratio > 0.0:
		draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, visual_config.hp_bar_height), _hp_color(hp_ratio))


func _view_zoom() -> float:
	return maxf(get_global_transform_with_canvas().get_scale().x, 0.01) if is_inside_tree() else 1.0


## Seconds after the landing in Normal-speed time; -1 while settling, before any settle, or at Fast.
func _landing_clock(actor_id: String) -> float:
	var age: float = _presentation_state.settled_age(actor_id)
	return age / visual_config.motion_scale if visual_config.motion_scale > 0.0 and age >= 0.0 else -1.0


## The body's offsets: hop (dip, lift), landing shake (Guard) or rebound (Hold), then the rest pose.
## No hop_lift (selected, Fast) means no hop motion at all; the rest pose still shows.
func _body_motion(actor_id: String, lift: float, zoom: float) -> Dictionary:
	var benefit: String = _presentation_state.stop_benefit(actor_id)
	var progress: float = _presentation_state.settle_progress(actor_id)
	var rise: float = MotionScript.hop_height(benefit, progress, lift)
	var shake: float = 0.0
	if lift > 0.0 and progress < 0.0:
		var since: float = _landing_clock(actor_id)
		rise = MotionScript.rebound_y(since) if benefit == "hold" else 0.0
		shake = MotionScript.shake_x(since) if benefit == "guard" else 0.0
	var rest := Vector2.ZERO
	var body_k: float = 1.0
	var amount: float = _presentation_state.pose_amount(actor_id)
	var angle: float = _presentation_state.pose_angle(actor_id)
	match _presentation_state.pose_shape(actor_id):
		"guard":
			if not is_nan(angle):
				rest = -Vector2.from_angle(angle) * MotionScript.lean_distance(zoom) * amount
		"hold":
			body_k = lerpf(1.0, MotionScript.hold_body_scale(zoom), amount)
	return { "rest": rest, "shake": shake, "rise": rise, "scale": body_k, "air": rise / lift if lift > 0.0 else 0.0 }


func _draw_stance(tok: Dictionary, font: Font, zoom: float) -> void:
	var actor_id: String = str(tok.get("actor_id", ""))
	if not _presentation_state.is_settled(actor_id):
		return
	var extent: float = _token_extent(tok)
	var base_pos: Vector2 = _presentation_state.get_display_position(actor_id, tok.get("draw_pos", Vector2.ZERO))
	var s: float = MotionScript.view_scale(zoom)
	if str(tok.get("mark_kind", "")) == "observe" and str(tok.get("status", "")) != "dead":
		for edge_pass in [true, false]:
			var bracket_w: float = 3.0 * s + (2.0 if edge_pass else 0.0)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var c: Vector2 = base_pos + Vector2(sx, sy) * (extent + 7.0 * s)
					draw_line(c, c - Vector2(sx * 9.0 * s, 0.0), _stance_pass_color(edge_pass, 1.0), bracket_w)
					draw_line(c, c - Vector2(0.0, sy * 9.0 * s), _stance_pass_color(edge_pass, 1.0), bracket_w)
	var subject: String = str(tok.get("observe_target", ""))
	var kind: String = _presentation_state.stop_pose(actor_id) if str(tok.get("status", "")) == "guarding" else ""
	if kind.is_empty() and not subject.is_empty() and _presentation_state.has_actor(subject):
		kind = "observe"
	if kind.is_empty():
		return
	var since: float = _landing_clock(actor_id)
	var pop: Vector2 = MotionScript.pop(since)
	var ring_r: float = (extent + 9.0 * s) * pop.x
	var center: Vector2 = base_pos + ((_body_motion(actor_id, 0.0, zoom)["rest"] as Vector2) if kind == "guard" else Vector2.ZERO)
	var angle: float = _presentation_state.pose_angle(actor_id) if kind == "guard" else NAN
	var spans: Array[Vector2] = MotionScript.shape_spans(kind, angle, ring_r, 6.0)
	var width: float = maxf(4.0, 4.0 / zoom) if kind == "hold" else maxf(2.5, 3.0 / zoom)
	_stroke_spans(center, ring_r, spans, width, pop.y, kind == "guard" and not MotionScript.is_full_ring(spans))
	var ripple: Vector2 = MotionScript.ripple(since)
	if ripple.y > 0.0:
		_stroke_spans(base_pos, lerpf(extent, extent + 15.0 * s, ripple.x), [Vector2(0.0, TAU)], 2.0, ripple.y, false)
	if kind == "observe":
		_draw_observe_line(base_pos, subject, extent, s)
		_draw_cause_badge(tok, actor_id, base_pos + Vector2(28.0 * s, 0.0), 6.0 * s)
	if zoom >= visual_config.chip_min_zoom:
		_draw_chip(base_pos, kind, s, font)


func _stance_pass_color(edge_pass: bool, alpha: float) -> Color:
	var color: Color = visual_config.stance_edge_color if edge_pass else visual_config.stance_color
	color.a = alpha
	return color


## Charcoal under-stroke first, then cream, so the cream stays readable on any tile.
func _stroke_spans(center: Vector2, radius: float, spans: Array, width: float, alpha: float, caps: bool) -> void:
	for edge_pass in [true, false]:
		var color: Color = _stance_pass_color(edge_pass, alpha)
		var line_w: float = width + 2.0 if edge_pass else width
		for span_v in spans:
			var span: Vector2 = span_v
			draw_arc(center, radius, span.x, span.y, 36, color, line_w, true)
			if caps:
				for end_angle in [span.x, span.y]:
					var out := Vector2.from_angle(end_angle)
					draw_line(center + out * (radius - 3.5), center + out * (radius + 3.5), color, line_w)


func _draw_observe_line(base_pos: Vector2, subject: String, extent: float, s: float) -> void:
	var to_target: Vector2 = _presentation_state.get_display_position(subject, base_pos) - base_pos
	var dir: Vector2 = to_target.normalized()
	var from_r: float = extent + 11.5 * s
	var to_r: float = to_target.length() - (extent + 7.0 * s)
	if to_r <= from_r:
		return
	for edge_pass in [true, false]:
		draw_dashed_line(base_pos + dir * from_r, base_pos + dir * to_r, _stance_pass_color(edge_pass, 1.0), 2.0 + (2.0 if edge_pass else 0.0), 5.0 * s)


## The benefit word under the token, with the marker's shape as a small glyph.
func _draw_chip(base_pos: Vector2, kind: String, s: float, font: Font) -> void:
	var word: String = StopShortText.row_word(kind)
	var font_size: int = roundi(10.0 * s)
	var chip := Vector2(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 24.0 * s, 15.0 * s)
	var rect := Rect2(base_pos + Vector2(-chip.x * 0.5, 36.0 * s), chip)
	var cream: Color = visual_config.stance_color
	draw_rect(rect, Color(visual_config.stance_edge_color, 0.88))
	draw_rect(rect, cream, false, s)
	var glyph_c: Vector2 = rect.position + Vector2(10.0 * s, chip.y * 0.5)
	for span_v in MotionScript.shape_spans(kind, 0.0, 4.0 * s, 1.6 * s):
		var span: Vector2 = span_v
		draw_arc(glyph_c, 4.0 * s, span.x, span.y, 12, cream, 1.8 * s, true)
	draw_string(font, rect.position + Vector2(17.0 * s, chip.y * 0.5 + font_size * 0.35), word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, cream)


func _draw_cause_badge(tok: Dictionary, actor_id: String, bc: Vector2, r: float) -> void:
	var badge: String = str(tok.get("cause_badge", ""))
	if badge.is_empty() or _presentation_state.settled_age(actor_id) < visual_config.badge_delay:
		return
	if badge == "fear":
		var tri := PackedVector2Array([bc + Vector2(-r, -r * 0.8), bc + Vector2(r, -r * 0.8), bc + Vector2(0.0, r)])
		draw_colored_polygon(tri, visual_config.cause_fear_badge_color)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), visual_config.stance_color, 1.5, true)
	else:
		draw_arc(bc, r * 0.85, 0.0, TAU, 20, visual_config.cause_identity_badge_color, 2.5, true)
		draw_circle(bc, r * 0.3, visual_config.cause_identity_badge_color)


## Angle (radians, token space) to the nearest living enemy token; NAN when none (caller draws a full ring).
static func nearest_enemy_angle(tokens: Array, actor_id: String) -> float:
	var me: Dictionary = {}
	for tok in tokens:
		if str(tok.get("actor_id", "")) == actor_id:
			me = tok
	if me.is_empty():
		return NAN
	var best: float = NAN
	var best_d: int = -1
	var mg: Dictionary = me.get("grid_pos", {})
	for tok in tokens:
		if str(tok.get("faction", "")) != "enemy" or str(tok.get("status", "")) == "dead":
			continue
		var g: Dictionary = tok.get("grid_pos", {})
		var d: int = maxi(absi(int(g.get("col", 0)) - int(mg.get("col", 0))), absi(int(g.get("row", 0)) - int(mg.get("row", 0))))
		if best_d < 0 or d < best_d:
			best_d = d
			best = ((tok.get("draw_pos", Vector2.ZERO) as Vector2) - (me.get("draw_pos", Vector2.ZERO) as Vector2)).angle()
	return best


func _normalize_tokens(tokens: Array[Dictionary]) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for token in tokens:
		var norm: Dictionary = token.duplicate(true)
		norm["draw_pos"] = _draw_pos(norm)
		norm["move_duration"] = max(float(norm.get("move_duration", visual_config.move_duration)), 0.001)
		normalized.append(norm)
	return normalized


## Converts traversed cell centres into token draw positions using the mover's own
## structure flag, so the waypoints share the feet offset applied to its draw_pos.
func _path_draw_positions(move_path_cells: Array[Vector2], source_id: String) -> Array[Vector2]:
	var waypoints: Array[Vector2] = []
	if move_path_cells.is_empty() or source_id.is_empty():
		return waypoints

	var is_structure: bool = false
	for tok in _tokens:
		if str(tok.get("actor_id", "")) == source_id:
			is_structure = bool(tok.get("is_structure", false))
			break

	for cell_pos in move_path_cells:
		waypoints.append(_draw_pos({ "cell_pos": cell_pos, "is_structure": is_structure }))
	return waypoints


func _draw_pos(token: Dictionary) -> Vector2:
	var cell_pos: Vector2 = token.get("cell_pos", Vector2.ZERO)
	if bool(token.get("is_structure", false)):
		return cell_pos
	return cell_pos + Vector2(0.0, visual_config.feet_offset_y)


func _token_extent(token: Dictionary) -> float:
	if bool(token.get("is_structure", false)):
		return visual_config.structure_half_size
	return visual_config.token_radius


func _faction_color(faction: String) -> Color:
	return FACTION_COLORS.get(faction, Color.WHITE)


func _hp_color(hp_ratio: float) -> Color:
	if hp_ratio > 0.5:
		return Color.GREEN
	if hp_ratio > 0.25:
		return Color.YELLOW
	return Color.RED
