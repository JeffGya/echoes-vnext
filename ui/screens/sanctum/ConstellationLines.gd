# res://ui/screens/sanctum/ConstellationLines.gd
# V2-PROG-009: Custom Node2D that draws the constellation web connecting lines and orbital
# guide rings for the Skills tab. Uses Godot's canonical _draw() / draw_line() / draw_arc()
# pattern for dynamic geometry — not a UI creation pattern.
#
# Data is pushed from SanctumScreen.gd via set_data() + queue_redraw().
# Line data: Array of { pos: Vector2, tier: int, family: String, alignment: String }
# Centre is the calling node position in ConstellationMap local coordinates.

extends Node2D

var _line_data: Array = []
var _centre: Vector2 = Vector2(180.0, 160.0)

# Ring radii matching the constellation tiers (S3=70, S6=120, S9=165)
const RING_RADII: Array = [70.0, 120.0, 165.0]

# Line colours
const COLOR_STRONG_LINE  := Color(0.788, 0.659, 0.298, 0.55)  # Akan Gold, opaque
const COLOR_LIGHT_LINE   := Color(0.627, 0.659, 0.753, 0.35)  # Silver-blue, lighter
const COLOR_GHOST_LINE   := Color(0.239, 0.255, 0.333, 0.4)   # Dark ghost
const COLOR_RING         := Color(0.788, 0.659, 0.298, 0.08)  # Akan Gold, very faint

const WIDTH_STRONG: float = 2.5
const WIDTH_LIGHT:  float = 1.5


func set_data(data: Array, centre: Vector2) -> void:
	_line_data = data
	_centre    = centre


func _draw() -> void:
	# --- Orbital guide rings ---
	for r in RING_RADII:
		draw_arc(_centre, r, 0.0, TAU, 64, COLOR_RING, 1.0, false)

	if _line_data.is_empty():
		return

	# --- Build per-family tier → positions map ---
	var by_family: Dictionary = {}
	for entry_v in _line_data:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var fam    := str(entry.get("family", ""))
		var tier   := int(entry.get("tier", 3))
		var pos_v: Variant = entry.get("pos", _centre)
		var pos: Vector2   = pos_v if pos_v is Vector2 else _centre
		var align  := str(entry.get("alignment", "strong"))

		if not by_family.has(fam):
			by_family[fam] = {
				"alignment": align,
				"tiers": {}
			}
		var tiers_v: Variant = (by_family[fam] as Dictionary).get("tiers", {})
		var tiers: Dictionary = tiers_v if tiers_v is Dictionary else {}
		if not tiers.has(tier):
			tiers[tier] = []
		(tiers[tier] as Array).append(pos)
		(by_family[fam] as Dictionary)["tiers"] = tiers

	# --- Draw connecting lines per family ---
	for fam in by_family:
		var fam_data: Dictionary = by_family[fam] as Dictionary
		var is_strong := str(fam_data.get("alignment", "strong")) == "strong"
		var tiers: Dictionary = fam_data.get("tiers", {}) as Dictionary
		var line_color := COLOR_STRONG_LINE if is_strong else COLOR_LIGHT_LINE
		var width      := WIDTH_STRONG      if is_strong else WIDTH_LIGHT

		# Centre → S3 nodes
		var s3_nodes: Array = tiers.get(3, []) as Array
		for pos_v in s3_nodes:
			var pos: Vector2 = pos_v if pos_v is Vector2 else _centre
			draw_line(_centre, pos, line_color, width)

		# S3 → S6 ghost connections
		_draw_tier_connections(tiers, 3, 6, COLOR_GHOST_LINE, width)

		# S6 → S9 ghost connections
		_draw_tier_connections(tiers, 6, 9, COLOR_GHOST_LINE, width)


# Connects each node at from_tier to its nearest node at to_tier using ghost colour.
func _draw_tier_connections(tiers: Dictionary, from_tier: int, to_tier: int,
		color: Color, width: float) -> void:
	var from_nodes: Array = tiers.get(from_tier, []) as Array
	var to_nodes:   Array = tiers.get(to_tier,   []) as Array
	if from_nodes.is_empty() or to_nodes.is_empty():
		return
	for fp_v in from_nodes:
		var fp: Vector2 = fp_v if fp_v is Vector2 else _centre
		var nearest: Vector2 = to_nodes[0] if to_nodes[0] is Vector2 else _centre
		var best_dist := fp.distance_to(nearest)
		for tp_v in to_nodes:
			if not (tp_v is Vector2):
				continue
			var tp: Vector2 = tp_v
			var d := fp.distance_to(tp)
			if d < best_dist:
				best_dist = d
				nearest = tp
		draw_line(fp, nearest, color, width)
