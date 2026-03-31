extends RefCounted
class_name CombatTokenPresentationTests

const PresentationStateScript := preload("res://ui/screens/combat/CombatTokenPresentationState.gd")

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat_ui/move_snapshot_emits_telegraph", Callable(CombatTokenPresentationTests, "_t_move_snapshot_emits_telegraph"))
	runner.register_test("combat_ui/sequential_snapshots_preserve_visual_state", Callable(CombatTokenPresentationTests, "_t_sequential_snapshots_preserve_visual_state"))
	runner.register_test("combat_ui/mid_motion_retarget_uses_current_display_pos", Callable(CombatTokenPresentationTests, "_t_mid_motion_retarget_uses_current_display_pos"))
	runner.register_test("combat_ui/non_move_actions_do_not_emit_telegraph", Callable(CombatTokenPresentationTests, "_t_non_move_actions_do_not_emit_telegraph"))
	runner.register_test("combat_ui/removing_actor_cleans_only_removed_state", Callable(CombatTokenPresentationTests, "_t_removing_actor_cleans_only_removed_state"))


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
