extends RefCounted
class_name CombatTokenPresentationTests

const PresentationStateScript := preload("res://ui/screens/combat/CombatTokenPresentationState.gd")

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat_ui/move_snapshot_emits_telegraph", Callable(CombatTokenPresentationTests, "_t_move_snapshot_emits_telegraph"))
	runner.register_test("combat_ui/sequential_snapshots_preserve_visual_state", Callable(CombatTokenPresentationTests, "_t_sequential_snapshots_preserve_visual_state"))
	runner.register_test("combat_ui/mid_motion_retarget_uses_current_display_pos", Callable(CombatTokenPresentationTests, "_t_mid_motion_retarget_uses_current_display_pos"))
	runner.register_test("combat_ui/non_move_actions_do_not_emit_telegraph", Callable(CombatTokenPresentationTests, "_t_non_move_actions_do_not_emit_telegraph"))
	runner.register_test("combat_ui/removing_actor_cleans_only_removed_state", Callable(CombatTokenPresentationTests, "_t_removing_actor_cleans_only_removed_state"))
	runner.register_test("combat_ui/waypoint_walk_follows_l_shaped_path", Callable(CombatTokenPresentationTests, "_t_waypoint_walk_follows_l_shaped_path"))
	runner.register_test("combat_ui/waypoint_walk_total_duration_is_invariant", Callable(CombatTokenPresentationTests, "_t_waypoint_walk_total_duration_is_invariant"))
	runner.register_test("combat_ui/oversized_delta_lands_on_final_waypoint", Callable(CombatTokenPresentationTests, "_t_oversized_delta_lands_on_final_waypoint"))
	runner.register_test("combat_ui/empty_move_path_keeps_straight_lerp", Callable(CombatTokenPresentationTests, "_t_empty_move_path_keeps_straight_lerp"))
	runner.register_test("combat_ui/repeated_snapshot_does_not_rearm_walk", Callable(CombatTokenPresentationTests, "_t_repeated_snapshot_does_not_rearm_walk"))
	runner.register_test("combat_ui/telegraph_delay_gates_waypoint_walk", Callable(CombatTokenPresentationTests, "_t_telegraph_delay_gates_waypoint_walk"))


static func _t_move_snapshot_emits_telegraph() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0)], {}, 0.10)
	var telegraph: Dictionary = state.apply_snapshot(
		[_token("echo_01", 1, 0)],
		{ "action_type": "actor.move", "source_id": "echo_01" },
		0.10
	)

	if str(telegraph.get("actor_id", "")) != "echo_01":
		return { "ok": false, "error": "Expected telegraph actor_id=echo_01, got %s" % str(telegraph.get("actor_id", "")) }
	if int(telegraph.get("grid_pos", {}).get("col", -1)) != 1:
		return { "ok": false, "error": "Expected telegraph grid_pos.col=1" }
	if absf(float(telegraph.get("duration", 0.0)) - 0.10) > 0.001:
		return { "ok": false, "error": "Expected telegraph duration=0.10, got %s" % str(telegraph.get("duration", 0.0)) }

	return { "ok": true }


static func _t_sequential_snapshots_preserve_visual_state() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0)], {}, 0.10)
	state.apply_snapshot(
		[_token("echo_01", 1, 0)],
		{ "action_type": "actor.move", "source_id": "echo_01" },
		0.10
	)

	var display_pos: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if display_pos != Vector2.ZERO:
		return { "ok": false, "error": "Expected display_pos to stay at the old location before movement starts, got %s" % str(display_pos) }

	return { "ok": true }


static func _t_mid_motion_retarget_uses_current_display_pos() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0, false, 1.0)], {}, 0.0)
	state.apply_snapshot(
		[_token("echo_01", 10, 0, false, 1.0)],
		{ "action_type": "actor.move", "source_id": "echo_01" },
		0.0
	)
	state.advance(0.5)

	var midway: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if absf(midway.x - 5.0) > 0.01:
		return { "ok": false, "error": "Expected midway display position x=5.0, got %s" % str(midway.x) }

	state.apply_snapshot(
		[_token("echo_01", 20, 0, false, 1.0)],
		{ "action_type": "actor.move", "source_id": "echo_01" },
		0.0
	)
	var entry: Dictionary = state.get_entry("echo_01")
	var start_pos: Vector2 = entry.get("start_pos", Vector2.ZERO)
	if absf(start_pos.x - 5.0) > 0.01:
		return { "ok": false, "error": "Expected retarget start_pos.x=5.0, got %s" % str(start_pos.x) }

	state.advance(0.5)
	var retarget_midway: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if absf(retarget_midway.x - 12.5) > 0.01:
		return { "ok": false, "error": "Expected retarget midway x=12.5, got %s" % str(retarget_midway.x) }

	return { "ok": true }


static func _t_non_move_actions_do_not_emit_telegraph() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0)], {}, 0.10)
	var telegraph: Dictionary = state.apply_snapshot(
		[_token("echo_01", 1, 0)],
		{ "action_type": "actor.guard", "source_id": "echo_01" },
		0.10
	)

	if not telegraph.is_empty():
		return { "ok": false, "error": "Expected no telegraph for actor.guard, got %s" % str(telegraph) }

	return { "ok": true }


static func _t_removing_actor_cleans_only_removed_state() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([
		_token("echo_01", 0, 0),
		_token("echo_02", 1, 0),
	], {}, 0.10)
	state.apply_snapshot([
		_token("echo_02", 1, 0),
	], {}, 0.10)

	if state.has_actor("echo_01"):
		return { "ok": false, "error": "Expected removed actor echo_01 to be pruned from presentation state" }
	if not state.has_actor("echo_02"):
		return { "ok": false, "error": "Expected echo_02 to remain in presentation state" }

	return { "ok": true }


## V2-COMBAT-002 Slice 6D — waypoint walk.
## The `_token` helper maps cell (col,row) to pixel (col,row), so waypoints below are
## written in the same 1:1 space.

static func _t_waypoint_walk_follows_l_shaped_path() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0, false, 0.9)], {}, 0.0)
	state.apply_snapshot(
		[_token("echo_01", 2, 1, false, 0.9)],
		_move_action(),
		0.0,
		_l_path()
	)

	# 18 samples of 0.05 == 0.9 total; segments are 0.9 / 3 == 0.3 each.
	for step in range(1, 19):
		state.advance(0.05)
		var pos: Vector2 = state.get_display_position("echo_01", Vector2(-99.0, -99.0))
		if not _on_l_polyline(pos):
			return { "ok": false, "error": "Step %d left the path polyline at %s (token cut a corner)" % [step, str(pos)] }
		if step == 6 and pos.distance_to(Vector2(1.0, 0.0)) > 0.01:
			return { "ok": false, "error": "Expected waypoint 1 (1,0) at step 6, got %s" % str(pos) }
		if step == 12 and pos.distance_to(Vector2(2.0, 0.0)) > 0.01:
			return { "ok": false, "error": "Expected waypoint 2 (2,0) at step 12, got %s" % str(pos) }
		if step == 18 and pos.distance_to(Vector2(2.0, 1.0)) > 0.01:
			return { "ok": false, "error": "Expected final waypoint (2,1) at step 18, got %s" % str(pos) }

	return { "ok": true }


static func _t_waypoint_walk_total_duration_is_invariant() -> Dictionary:
	var short_state = PresentationStateScript.new()
	short_state.apply_snapshot([_token("echo_01", 0, 0, false, 1.0)], {}, 0.0)
	# Cell spacing of 100px keeps "1% of the animation remaining" well clear of the
	# 0.01px arrival tolerance.
	var short_path: Array[Vector2] = [Vector2(100.0, 0.0)]
	short_state.apply_snapshot([_token("echo_01", 100, 0, false, 1.0)], _move_action(), 0.0, short_path)

	var long_state = PresentationStateScript.new()
	long_state.apply_snapshot([_token("echo_01", 0, 0, false, 1.0)], {}, 0.0)
	var long_path: Array[Vector2] = [
		Vector2(100.0, 0.0), Vector2(200.0, 0.0), Vector2(300.0, 0.0), Vector2(400.0, 0.0),
	]
	long_state.apply_snapshot([_token("echo_01", 400, 0, false, 1.0)], _move_action(), 0.0, long_path)

	# Just before move_duration elapses, neither has arrived.
	short_state.advance(0.99)
	long_state.advance(0.99)
	if short_state.get_display_position("echo_01", Vector2.ZERO).distance_to(Vector2(100.0, 0.0)) <= 0.01:
		return { "ok": false, "error": "1-cell path finished before move_duration elapsed" }
	if long_state.get_display_position("echo_01", Vector2.ZERO).distance_to(Vector2(400.0, 0.0)) <= 0.01:
		return { "ok": false, "error": "4-cell path finished before move_duration elapsed" }

	# Just after move_duration elapses, both have arrived — total time is invariant
	# to path length, which is what keeps the board's step-timer margins intact.
	short_state.advance(0.02)
	long_state.advance(0.02)
	var short_pos: Vector2 = short_state.get_display_position("echo_01", Vector2.ZERO)
	var long_pos: Vector2 = long_state.get_display_position("echo_01", Vector2.ZERO)
	if short_pos.distance_to(Vector2(100.0, 0.0)) > 0.01:
		return { "ok": false, "error": "1-cell path did not finish within move_duration, at %s" % str(short_pos) }
	if long_pos.distance_to(Vector2(400.0, 0.0)) > 0.01:
		return { "ok": false, "error": "4-cell path did not finish within move_duration, at %s" % str(long_pos) }

	return { "ok": true }


static func _t_oversized_delta_lands_on_final_waypoint() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0, false, 0.9)], {}, 0.0)
	state.apply_snapshot([_token("echo_01", 2, 1, false, 0.9)], _move_action(), 0.0, _l_path())

	state.advance(10.0)
	var pos: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if pos.distance_to(Vector2(2.0, 1.0)) > 0.01:
		return { "ok": false, "error": "Expected oversized delta to land on final waypoint (2,1), got %s" % str(pos) }

	return { "ok": true }


static func _t_empty_move_path_keeps_straight_lerp() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0, false, 1.0)], {}, 0.0)
	state.apply_snapshot([_token("echo_01", 10, 0, false, 1.0)], _move_action(), 0.0)

	state.advance(0.5)
	var midway: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if absf(midway.x - 5.0) > 0.01 or absf(midway.y) > 0.01:
		return { "ok": false, "error": "Expected straight-lerp midpoint (5,0) with empty move_path, got %s" % str(midway) }

	state.advance(0.5)
	var final_pos: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if final_pos.distance_to(Vector2(10.0, 0.0)) > 0.01:
		return { "ok": false, "error": "Expected straight lerp to finish at (10,0), got %s" % str(final_pos) }

	return { "ok": true }


static func _t_repeated_snapshot_does_not_rearm_walk() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0, false, 0.9)], {}, 0.0)
	state.apply_snapshot([_token("echo_01", 2, 1, false, 0.9)], _move_action(), 0.0, _l_path())

	state.advance(0.3)
	var after_first: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if after_first.distance_to(Vector2(1.0, 0.0)) > 0.01:
		return { "ok": false, "error": "Expected first waypoint (1,0) after 0.3s, got %s" % str(after_first) }

	# A refresh that resolves no actor re-emits an UNCHANGED last_actor_action.
	state.apply_snapshot([_token("echo_01", 2, 1, false, 0.9)], _move_action(), 0.0, _l_path())
	var after_refresh: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if after_refresh.distance_to(Vector2(1.0, 0.0)) > 0.01:
		return { "ok": false, "error": "Refresh moved the token to %s instead of holding (1,0)" % str(after_refresh) }

	state.advance(0.3)
	var after_second: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if after_second.distance_to(Vector2(2.0, 0.0)) > 0.01:
		return { "ok": false, "error": "Expected walk to continue to (2,0); the queue re-armed and returned to %s" % str(after_second) }

	return { "ok": true }


static func _t_telegraph_delay_gates_waypoint_walk() -> Dictionary:
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0, false, 0.9)], {}, 0.5)
	state.apply_snapshot([_token("echo_01", 2, 1, false, 0.9)], _move_action(), 0.5, _l_path())

	state.advance(0.4)
	var during_delay: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if during_delay.distance_to(Vector2.ZERO) > 0.01:
		return { "ok": false, "error": "Expected token to hold at origin during telegraph delay, got %s" % str(during_delay) }

	# 0.1s of delay left, so 0.1s of the 0.3s first segment is consumed.
	state.advance(0.2)
	var after_delay: Vector2 = state.get_display_position("echo_01", Vector2.ZERO)
	if absf(after_delay.x - (1.0 / 3.0)) > 0.01 or absf(after_delay.y) > 0.01:
		return { "ok": false, "error": "Expected leftover delta to carry into segment 0 (x≈0.333), got %s" % str(after_delay) }

	return { "ok": true }


static func _move_action() -> Dictionary:
	return { "action_type": "actor.move", "source_id": "echo_01" }


static func _l_path() -> Array[Vector2]:
	var path: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(2.0, 0.0), Vector2(2.0, 1.0)]
	return path


## True when p sits on the L polyline (0,0)->(2,0)->(2,1).
static func _on_l_polyline(p: Vector2) -> bool:
	if absf(p.y) <= 0.01 and p.x >= -0.01 and p.x <= 2.01:
		return true
	if absf(p.x - 2.0) <= 0.01 and p.y >= -0.01 and p.y <= 1.01:
		return true
	return false


static func _token(actor_id: String, col: int, row: int, is_structure: bool = false, move_duration: float = 0.18) -> Dictionary:
	var draw_pos := Vector2(float(col), float(row))
	return {
		"actor_id": actor_id,
		"grid_pos": { "col": col, "row": row },
		"cell_pos": draw_pos,
		"draw_pos": draw_pos,
		"is_structure": is_structure,
		"move_duration": move_duration,
	}
