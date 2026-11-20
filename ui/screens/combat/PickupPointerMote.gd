class_name PickupPointerMote
extends Node2D

## The pointer of the pickup intro (D-76): a small ivory mote that drifts above the Echoes' heads along the racetrack of
## `PickupEventPlan.pointer_pose`, and sinks into the chooser, where a soft halo opens behind the token. No ring, outline,
## stroke or board scrim. The sprites and their soft radial gradients are authored in the scene; this script only sets values.
## Every look value (sizes, times, alphas) comes from `plan.pointer.mote`, i.e. `data.pointer_look.mote` of the snapshot
## (`data.inventory.pickup.pointer_look` in balance.json, D-77); this script holds no tunable number. `pose_at` is pure. The nodes are world-space children of BoardRoot, so the camera zoom scales the mote like the tokens.
## Order in the tree: the halo layer sits below the token layer (the Echo stands in front of its halo); this node sits above it.

## Living Grove ivory (`docs/art-direction.md`, #F5F0E8). Not in the theme file, so the constant is tested against the hex.
const IVORY := Color(0.9607843, 0.9411765, 0.9098039)

## Radius in pixels of the authored gradient textures (half their width; a test checks it).
const TEXTURE_RADIUS := 32.0

@export var visual_config: CombatTokenVisualConfig

@onready var _halo_layer: Node2D = %PickupPointerHalo
@onready var _halo: Sprite2D = %Halo
@onready var _shadow: Sprite2D = %Shadow
@onready var _mote: Sprite2D = %Mote
@onready var _trail: Array[Sprite2D] = [%Trail1, %Trail2, %Trail3, %Trail4, %Trail5]


static func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


## One grid step toward the camera, perpendicular to the row, in board pixels; the fallback when the row is not a straight line of
## adjacent tiles. Spacing is the mean distance of two neighbours.
static func screen_lateral(positions: Array) -> Vector2:
	if positions.size() < 2:
		return Vector2(0.0, 1.0)
	var d: Vector2 = (positions[positions.size() - 1] as Vector2) - (positions[0] as Vector2)
	var perp := Vector2(-d.y, d.x).normalized() * spacing_of(positions)
	return perp if perp.y >= 0.0 else -perp


static func spacing_of(positions: Array) -> float:
	if positions.size() < 2:
		return 1.0
	var sum := 0.0
	for i in positions.size() - 1:
		sum += ((positions[i + 1] as Vector2) - (positions[i] as Vector2)).length()
	return sum / float(positions.size() - 1)


## The board point of path coordinates: `pos_row` along the row (it runs past both ends on a turn) and `side` steps of `lateral`.
static func path_point(positions: Array, lateral: Vector2, pos_row: float, side: float) -> Vector2:
	if positions.is_empty():
		return Vector2.ZERO
	if positions.size() == 1:
		return (positions[0] as Vector2) + lateral * side
	var i := clampi(int(floor(pos_row)), 0, positions.size() - 2)
	var base: Vector2 = (positions[i] as Vector2).lerp(positions[i + 1] as Vector2, pos_row - float(i))
	return base + lateral * side


static func _hidden(chooser: Vector2) -> Dictionary:
	return { "visible": false, "mote": Vector2.ZERO, "alpha": 0.0, "scale": 1.0, "ground": Vector2.ZERO, "shadow_alpha": 0.0,
		"shadow_scale": 1.0, "trail": [], "halo_pos": chooser, "halo_alpha": 0.0, "halo_scale": 0.0, "brighten": 0.0, "phase": "gone" }


## Everything the nodes show at time `t`. `positions`: board centre of every row token by row index. `token_radius`: the token's radius
## (the mote rests `above_head` above the token's top). `lateral`: one step toward the camera, in board pixels.
static func pose_at(plan: Dictionary, positions: Array, lateral: Vector2, t: float, token_radius: float) -> Dictionary:
	var pp := PickupEventPlan.pointer_pose(plan, t)
	if not bool(pp["visible"]) or positions.is_empty():
		return _hidden(Vector2.ZERO)
	var land := int((plan["pointer"] as Dictionary)["land_index"])
	if land >= positions.size():
		return _hidden(Vector2.ZERO)
	var mc: Dictionary = (plan["pointer"] as Dictionary)["mote"]
	var head := token_radius + float(mc["above_head"])
	var chooser: Vector2 = positions[land]
	var lead := float((plan["pointer"] as Dictionary)["lead"])
	var tp := t - float((plan["times"] as Dictionary)["pointer0"])
	var fin := _ease_out(tp / lead)
	var alpha := fin
	var scale := lerpf(float(mc["fade_scale_from"]), 1.0, fin)
	var base := path_point(positions, lateral, float(pp["pos_row"]), float(pp["side"]))
	var arc_min := float(mc["arc_min"])
	var arc_max := float(mc["arc_max"])
	var arc := (arc_min + (arc_max - arc_min) * float(pp["arc_k"])) * float(pp["arc"])
	var mote := base + Vector2(0.0, -head - arc + float(mc["rise"]) * (1.0 - fin))
	var out := _hidden(chooser)
	out["visible"] = true
	out["phase"] = pp["phase"]
	var lt := float(pp["lt"])
	var wind_len := float(mc["wind_up_len"])
	var sink_len := float(mc["sink_len"])
	if lt > 0.0:
		var lift := float(mc["wind_up"]) * _ease_out(lt / wind_len)
		var u := clampf((lt - wind_len) / sink_len, 0.0, 1.0)
		var fade_from := float(mc["sink_fade_from"])
		mote += Vector2(0.0, -lift + float(mc["sink"]) * u * u)
		alpha *= 1.0 - clampf((u - fade_from) / (1.0 - fade_from), 0.0, 1.0)
		scale *= 1.0 - float(mc["sink_scale"]) * u
		var open_len := float(mc["halo_open"])
		var opened := _ease_out((lt - wind_len) / open_len)
		if lt > wind_len:
			var breath := 1.0
			if lt > wind_len + open_len:
				breath += float(mc["halo_breath"]) * sin(TAU * (lt - wind_len - open_len) / float(mc["halo_breath_period"]))
			out["halo_alpha"] = float(mc["halo_alpha"]) * minf(1.0, opened + float(mc["halo_start_alpha"])) * breath
			out["halo_scale"] = maxf(opened, 0.01)
		out["brighten"] = float(mc["brighten"]) * clampf((lt - wind_len - sink_len) / float(mc["brighten_len"]), 0.0, 1.0)
	var high := arc / arc_max
	out["mote"] = mote
	out["alpha"] = alpha
	out["scale"] = scale
	out["ground"] = base
	out["shadow_alpha"] = alpha * (1.0 - float(mc["shadow_alpha_drop"]) * high)
	out["shadow_scale"] = 1.0 - float(mc["shadow_scale_drop"]) * high
	var trail: Array = []
	if (pp["phase"] == "glide" or pp["phase"] == "turn") and float(pp["speed"]) > 0.01:
		var count := int(mc["trail_count"])
		for k in range(1, count + 1):
			var q := PickupEventPlan.pointer_pose(plan, t - float(mc["trail_dt"]) * float(k))
			if not bool(q["visible"]):
				break
			var qa := (arc_min + (arc_max - arc_min) * float(q["arc_k"])) * float(q["arc"])
			trail.append({ "pos": path_point(positions, lateral, float(q["pos_row"]), float(q["side"])) + Vector2(0.0, -head - qa),
				"alpha": float(mc["trail_alpha"]) * (1.0 - float(k) / float(count + 1)) * alpha,
				"scale": float(mc["trail_scale"]) - float(mc["trail_scale_step"]) * float(k) })
	out["trail"] = trail
	return out


func hide_all() -> void:
	visible = false
	if _halo_layer != null:
		_halo_layer.visible = false


## `look` is `plan.pointer.mote` (sizes in pixels). The scene has five trail sprites: a longer trail shows no more.
func apply_pose(pose: Dictionary, look: Dictionary, tile_width: float) -> void:
	visible = bool(pose["visible"])
	_halo_layer.visible = visible and float(pose["halo_alpha"]) > 0.0
	if not visible:
		return
	var ivory := Color(IVORY, 1.0)
	var radius := float(look["mote_radius"])
	_halo.position = pose["halo_pos"]
	_halo.scale = Vector2.ONE * (float(look["halo_diameter_tiles"]) * tile_width * 0.5 * float(pose["halo_scale"]) / TEXTURE_RADIUS)
	_halo.modulate = Color(ivory, float(pose["halo_alpha"]))
	_shadow.position = (pose["ground"] as Vector2) + visual_config.shadow_offset
	_shadow.scale = Vector2(1.0, float(look["shadow_scale_y"])) * (float(look["shadow_radius"]) * float(pose["shadow_scale"]) / TEXTURE_RADIUS)
	_shadow.modulate = Color(visual_config.shadow_color, visual_config.shadow_color.a * float(pose["shadow_alpha"]))
	_mote.position = pose["mote"]
	_mote.scale = Vector2.ONE * (radius * float(pose["scale"]) / TEXTURE_RADIUS)
	_mote.modulate = Color(ivory, float(pose["alpha"]))
	var trail: Array = pose["trail"]
	for i in _trail.size():
		_trail[i].visible = i < trail.size()
		if i < trail.size():
			_trail[i].position = trail[i]["pos"]
			_trail[i].scale = Vector2.ONE * (radius * float(trail[i]["scale"]) / TEXTURE_RADIUS)
			_trail[i].modulate = Color(ivory, float(trail[i]["alpha"]))
