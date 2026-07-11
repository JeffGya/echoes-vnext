# res://ui/screens/venture/GhostFootprintLayer.gd
# V2-STAGE-004 Phase 5 (P5 UI/UX fix): board-local ghost footprints for explore travel.
#
# Ghosts are dropped at cells the party has just vacated during the travel scroll, so the
# traversal reads as a fading trail glued to the terrain. This node is parented to the Board
# TileMapLayer, so its draw coordinates are board-LOCAL and it inherits the board's transform
# (position + scale) automatically — ghosts scroll and zoom WITH the terrain, mirroring how
# SituationLayer stays synced to the board.
#
# Ghosts are only ever created via drop_ghost() (called from the travel-tween segment chain),
# so screen resize / re-entry / preview→explore transitions never spawn a stray ghost. Each
# ghost's alpha decays to 0 over GHOST_FADE seconds, then it is dropped. Purely visual.

extends Node2D

const GHOST_FADE   := 1.5
const GHOST_RADIUS := 18.0 * 0.9
const GHOST_COLOR  := Color(0.20, 0.45, 0.90, 1.0)   # echo-faction blue — alpha animated

# Each ghost: { "pos": Vector2 (board-local), "life": float } — life counts down to 0.
var _ghosts: Array = []


## Drop a fading ghost footprint at a board-local pixel position (from map_to_local).
func drop_ghost(local_pos: Vector2) -> void:
	_ghosts.append({ "pos": local_pos, "life": GHOST_FADE })
	queue_redraw()


## Clear all ghosts immediately (e.g. when leaving explore for preview).
func clear_all() -> void:
	if _ghosts.is_empty():
		return
	_ghosts.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _ghosts.is_empty():
		return
	var survivors: Array = []
	for g_v in _ghosts:
		var g: Dictionary = g_v
		g["life"] = float(g.get("life", 0.0)) - delta
		if float(g["life"]) > 0.0:
			survivors.append(g)
	_ghosts = survivors
	queue_redraw()


func _draw() -> void:
	for g_v in _ghosts:
		var g: Dictionary = g_v
		var alpha: float = clampf(float(g.get("life", 0.0)) / GHOST_FADE, 0.0, 1.0)
		var gpos: Vector2 = g.get("pos", Vector2.ZERO)
		draw_circle(gpos, GHOST_RADIUS, Color(GHOST_COLOR.r, GHOST_COLOR.g, GHOST_COLOR.b, alpha * 0.35))
