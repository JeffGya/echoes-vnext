# res://core/actors/behaviors/FleeBehaviorModule.gd
# V2-STAGE-004 P3b: Quarry flee behavior. Pure, deterministic. No RNG.
class_name FleeBehaviorModule
extends BehaviorModule

var _board_cfg: Dictionary

func _init(board_cfg: Dictionary) -> void:
	_board_cfg = board_cfg

func get_module_id() -> String:
	return "flee_behavior"

func select_intent(context: Dictionary) -> Dictionary:
	var actor: Dictionary  = context.get("actor", {})
	var all_actors: Array  = context.get("all_actors", [])

	var my_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 })
	var board_cols: int    = int(_board_cfg.get("board_cols", 10))
	var board_rows: int    = int(_board_cfg.get("board_rows", 10))
	var max_col: int       = maxi(0, board_cols - 1)
	var max_row: int       = maxi(0, board_rows - 1)

	# Collect living echo positions.
	var echo_positions: Array = []
	for a_v in all_actors:
		if not (a_v is Dictionary): continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) == "echo" and not bool(a.get("is_dead", false)):
			echo_positions.append(a.get("grid_pos", { "col": 0, "row": 0 }))

	# 8 candidate exit points: 4 corners + 4 mid-edges.
	var candidates: Array[Dictionary] = [
		{ "col": 0,            "row": 0            },
		{ "col": max_col,      "row": 0            },
		{ "col": 0,            "row": max_row       },
		{ "col": max_col,      "row": max_row       },
		{ "col": max_col / 2,  "row": 0            },
		{ "col": max_col / 2,  "row": max_row       },
		{ "col": 0,            "row": max_row / 2   },
		{ "col": max_col,      "row": max_row / 2   },
	]

	# Score each candidate: farthest from all echoes, closest to quarry.
	# score = sum_chebyshev(cand, each_echo) - 2 * chebyshev(quarry, cand)
	var best_target: Dictionary = {}
	var best_score: float = -9999999.0

	for cand in candidates:
		var dist_to_cand: int = GridService.chebyshev_distance(my_pos, cand)
		var echo_dist_sum: float = 0.0
		for ep in echo_positions:
			echo_dist_sum += float(GridService.chebyshev_distance(cand, ep))
		var score: float = echo_dist_sum - 2.0 * float(dist_to_cand)
		if score > best_score:
			best_score = score
			best_target = cand

	if best_target.is_empty():
		return { "action_type": "actor.idle", "target_id": "", "priority": 0.0 }

	return {
		"action_type": "actor.move",
		"target_pos":  best_target,
		"target_id":   "",
		"priority":    1.0,
	}
