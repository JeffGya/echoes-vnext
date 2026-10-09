extends RefCounted
class_name CombatTokenPresentationTests

const PresentationStateScript := preload("res://ui/screens/combat/CombatTokenPresentationState.gd")
const BoardScreenScript := preload("res://ui/screens/combat/CombatBoardScreen.gd")
const TelegraphScript := preload("res://ui/screens/combat/CombatMoveTelegraphLayer.gd")
const TokenLayerScript := preload("res://ui/screens/combat/CombatTokenLayer.gd")
const MotionScript := preload("res://ui/screens/combat/CombatStopShortMotion.gd")

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
	runner.register_test("combat_ui/stop_short_screen_unselected_holds_then_shows", Callable(CombatTokenPresentationTests, "_t_screen_unselected"))
	runner.register_test("combat_ui/stop_short_screen_selected_gets_bubble_no_hop", Callable(CombatTokenPresentationTests, "_t_screen_selected"))
	for name in ["settle_clock_fires_once_after_walk", "settle_skips_unperformed_and_fast_is_instant", "settle_jumps_on_new_snapshot_without_event", "settle_does_not_rearm_on_repeat_snapshot", "selection_gate_and_hop_lift", "badge_only_for_decisive_source", "reason_and_row_text_come_from_bank", "nearest_enemy_angle_and_full_ring_fallback", "settle_diamond_gate_and_switch", "stance_arc_flag_gated_and_cleared", "ordinary_guard_clears_stop_flag", "row_text_fallback_unchanged", "motion_times_and_lift", "hop_curve_shape", "after_landing_windows", "guard_arc_is_continuous", "marker_shapes_and_scale", "pose_rises_holds_and_returns", "pose_fast_snaps_and_angle_freezes"]:
		runner.register_test("combat_ui/stop_short_" + name, Callable(CombatTokenPresentationTests, "_t_" + name))


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



static func _stop_action(performed: bool = true) -> Dictionary:
	return { "action_type": "actor.guard", "source_id": "echo_01", "stop_short": { "benefit": "guard", "performed": performed } }


## Walk 0.3 s from col 0 to col 1, then `settle` seconds. Returns the state mid-armed.
static func _armed_state(settle: float, performed: bool = true):
	var state = PresentationStateScript.new()
	state.apply_snapshot([_token("echo_01", 0, 0, false, 0.3)], {}, 0.0)
	state.apply_snapshot([_token("echo_01", 1, 0, false, 0.3)], _stop_action(performed), 0.0, [], settle)
	return state


static func _t_settle_clock_fires_once_after_walk() -> Dictionary:
	var state = _armed_state(0.24)
	if state.is_settled("echo_01"):
		return { "ok": false, "error": "Token must not be settled at the start of the step" }
	state.advance(0.3)
	state.advance(0.1)
	var mid: float = state.settle_progress("echo_01")
	if mid <= 0.0 or mid >= 1.0 or not state.take_settled().is_empty():
		return { "ok": false, "error": "Expected progress in (0,1) and no event mid-settle, got %s" % str(mid) }
	state.advance(0.1)
	state.advance(0.1)
	if not state.is_settled("echo_01") or state.take_settled() != ["echo_01"]:
		return { "ok": false, "error": "Expected exactly one settled event for echo_01" }
	if not state.take_settled().is_empty() or state.settle_progress("echo_01") != -1.0:
		return { "ok": false, "error": "The event must not repeat and progress must reset" }
	return { "ok": true }


static func _t_settle_skips_unperformed_and_fast_is_instant() -> Dictionary:
	var unperformed = _armed_state(0.24, false)
	if not unperformed.is_settled("echo_01"):
		return { "ok": false, "error": "A stop-short that was not performed must not settle-gate any picture" }
	var fast = _armed_state(0.0)
	fast.advance(0.3)
	fast.advance(0.01)
	if fast.take_settled() != ["echo_01"]:
		return { "ok": false, "error": "At settle 0 the event must fire as soon as the walk ends" }
	return { "ok": true }


static func _t_settle_jumps_on_new_snapshot_without_event() -> Dictionary:
	var state = _armed_state(0.4)
	state.advance(0.05)
	state.apply_snapshot([_token("echo_01", 1, 0, false, 0.3)], {}, 0.0)
	if not state.is_settled("echo_01") or not state.take_settled().is_empty():
		return { "ok": false, "error": "A new snapshot must end the settle at once and emit no event" }
	if state.settled_age("echo_01") < 1.0:
		return { "ok": false, "error": "A jumped settle must show the badge at once" }
	return { "ok": true }


static func _t_settle_does_not_rearm_on_repeat_snapshot() -> Dictionary:
	var state = _armed_state(0.24)
	for i in range(6):
		state.advance(0.1)
	state.take_settled()
	state.apply_snapshot([_token("echo_01", 1, 0, false, 0.3)], _stop_action(), 0.0, [], 0.24)
	if not state.is_settled("echo_01"):
		return { "ok": false, "error": "A repeated snapshot without a cell change must not replay the settle (or the hop)" }
	return { "ok": true }


static func _t_selection_gate_and_hop_lift() -> Dictionary:
	var follow: int = BoardCameraController.Mode.FOLLOW_ACTOR
	if not BoardScreenScript.is_actor_selected(follow, "a", "a") or BoardScreenScript.is_actor_selected(follow, "b", "a"):
		return { "ok": false, "error": "Selected needs FOLLOW_ACTOR and a matching target" }
	if BoardScreenScript.is_actor_selected(BoardCameraController.Mode.FREE, "a", "a"):
		return { "ok": false, "error": "A free camera selects nobody" }
	if BoardScreenScript.stop_short_hop_lift("guard", true, true, 1.3, 1.0) != 0.0 or BoardScreenScript.stop_short_hop_lift("guard", false, false, 1.3, 1.0) != 0.0 or BoardScreenScript.stop_short_hop_lift("guard", false, true, 1.3, 0.0) != 0.0:
		return { "ok": false, "error": "No hop when selected, not performed, or at Fast" }
	var guard_lift: float = BoardScreenScript.stop_short_hop_lift("guard", false, true, 1.3, 1.0)
	if absf(guard_lift - 22.0 / 1.3) > 0.01 or BoardScreenScript.stop_short_hop_lift("guard", false, true, 0.35, 1.0) != 28.0 or BoardScreenScript.stop_short_hop_lift("guard", false, true, 2.2, 1.6) != 16.0:
		return { "ok": false, "error": "Guard lift is 22 / zoom, clamped to 16..28" }
	if absf(BoardScreenScript.stop_short_hop_lift("hold", false, true, 2.2, 1.0) - 14.0) > 0.001 or BoardScreenScript.stop_short_hop_lift("observe", false, true, 0.35, 1.0) != 10.0:
		return { "ok": false, "error": "Hold lifts 0.875 of Guard; Observe lifts 10 at any zoom" }
	return { "ok": true }


static func _t_badge_only_for_decisive_source() -> Dictionary:
	var cases := { "emotion": "fear", "calling": "identity", "vector": "identity", "movement_style": "", "directive": "", "": "" }
	for source in cases:
		var report := { "trace": { "message_args": { "source": source } } }
		if BoardScreenScript.stop_short_badge(report) != cases[source]:
			return { "ok": false, "error": "Badge for source '%s' must be '%s'" % [source, cases[source]] }
	if BoardScreenScript.stop_short_badge({ "trace": { "message_args": { "purpose": "escort" } } }) != "" or BoardScreenScript.stop_short_badge({}) != "":
		return { "ok": false, "error": "A trace with no source (vague) must give no badge" }
	return { "ok": true }


static func _t_reason_and_row_text_come_from_bank() -> Dictionary:
	for benefit in ["guard", "observe", "hold"]:
		if not StopShortText.has_key(["row_word", benefit]):
			return { "ok": false, "error": "Missing row word for %s" % benefit }
		var plain: String = BoardScreenScript.stop_short_reason({ "benefit": benefit })
		if plain != StopShortText.reason_line(benefit) or plain.is_empty():
			return { "ok": false, "error": "Plain reason for %s must come from the bank" % benefit }
	var fear: String = BoardScreenScript.stop_short_reason({ "benefit": "guard", "trace": { "message_args": { "code": "fear" } } })
	if fear != StopShortText.reason_line("guard", "fear") or fear == StopShortText.reason_line("guard"):
		return { "ok": false, "error": "A fear code must pick the fear line" }
	var unknown: String = BoardScreenScript.stop_short_reason({ "benefit": "guard", "trace": { "message_args": { "code": "values" } } })
	if unknown != StopShortText.reason_line("guard"):
		return { "ok": false, "error": "A code with no own line must fall back to the plain line" }
	return { "ok": true }


static func _t_nearest_enemy_angle_and_full_ring_fallback() -> Dictionary:
	var me := _token("echo_01", 0, 0)
	var far := _token("enemy_far", 3, 0)
	var near := _token("enemy_near", 0, 1)
	var dead := _token("enemy_dead", 1, 0)
	for t in [far, near, dead]:
		t["faction"] = "enemy"
	dead["status"] = "dead"
	me["faction"] = "echo"
	var angle: float = TokenLayerScript.nearest_enemy_angle([me, far, dead, near], "echo_01")
	if absf(angle - (near["draw_pos"] - me["draw_pos"]).angle()) > 0.001:
		return { "ok": false, "error": "Arc must face the nearest living enemy, got %s" % str(angle) }
	if not is_nan(TokenLayerScript.nearest_enemy_angle([me, dead], "echo_01")):
		return { "ok": false, "error": "With no living enemy the angle is NAN (full ring)" }
	return { "ok": true }



static func _stop_snap(col: int, with_step: bool) -> Dictionary:
	var actor := {
		"id": "echo_01", "name": "Kweku", "faction": "echo", "grid_pos": { "col": col, "row": 0 },
		"hp": 10, "max_hp": 10, "status": "guarding", "emotional_status": "steady",
		"bark_line": "Not yet." if with_step else "", "bark_context": "combat_guard", "bark_tier": "", "bark_priority": 2,
	}
	var step := {}
	var results: Array = []
	if with_step:
		var report := { "benefit": "guard", "performed": true, "subject_actor_id": "", "trace": { "message_args": { "source": "emotion", "code": "fear" } } }
		step = { "action_type": "actor.guard", "source_id": "echo_01", "stop_short": report, "path": [{ "col": col, "row": 0 }] }
		results = [{ "action_type": "actor.guard", "source_id": "echo_01", "source_name": "Kweku", "stop_short": report }]
	return {
		"type": "flow.encounter", "meta": { "t": 1 },
		"data": {
			"encounter_id": "stop_ui", "board_cols": 4, "board_rows": 4, "round": 1,
			"round_phase": "actor_turn", "combat_over": false, "actors": [actor],
			"initiative_order": [{ "id": "echo_01", "name": "Kweku" }], "active_initiative_index": 0,
			"current_actor_id": "echo_01", "objective_state": {}, "last_actor_action": step, "action_results": results,
		},
		"actions": {},
	}


static func _first_row(screen: Node) -> Node:
	for child in screen.get_node("InitiativePanel/InitiativeList").get_children():
		if not child.is_queued_for_deletion():
			return child
	return null


static func _run_settle(screen: Node) -> void:
	for i in range(12):
		screen.get_node("%TokenLayer")._process(0.1)


static func _t_screen_unselected() -> Dictionary:
	var m := PaceUITests._mount(PaceUITests.CombatScene)
	var screen: Node = m[1]
	screen.set_snapshot(_stop_snap(0, false))
	screen.set_snapshot(_stop_snap(1, true))
	var layer: Node = screen.get_node("%TokenLayer")
	var row := _first_row(screen)
	var popups: Dictionary = screen.get_node("%BarkPopupLayer")._active_popups
	var err := ""
	if layer.is_settled("echo_01") or screen._pending_row.size() != 1:
		err = "Step start: the token must be unsettled and one row pending"
	elif (row.get_node("%ActionLabel") as Label).text != "Moves" or (row.get_node("%EmotionLabel") as Control).visible:
		err = "T0 row must show the plain move word and no emotion label"
	elif screen._held_barks.size() != 1 or popups.has("echo_01"):
		err = "The Echo's own bark must be held, not shown, before the settle"
	elif float(layer._tokens[0].get("hop_lift", 0.0)) <= 0.0 or str(layer._tokens[0].get("cause_badge", "")) != "fear":
		err = "An unselected performed stop must carry a hop lift and the fear badge"
	if err.is_empty():
		_run_settle(screen)
		if not layer.is_settled("echo_01") or not screen._pending_row.is_empty():
			err = "After the settle time the token must be settled and the pending row used"
		elif (row.get_node("%ActionLabel") as Label).text != StopShortText.row_word("guard"):
			err = "At settle the row must show the benefit word from the bank"
		elif not screen._held_barks.is_empty() or not popups.has("echo_01"):
			err = "At settle the held bark must be released and shown"
	m[0].free()
	return { "ok": err.is_empty(), "error": err }


static func _t_screen_selected() -> Dictionary:
	var m := PaceUITests._mount(PaceUITests.CombatScene)
	var screen: Node = m[1]
	screen.set_snapshot(_stop_snap(0, false))
	screen.select_board_target("echo_01")
	screen.set_snapshot(_stop_snap(1, true))
	var layer: Node = screen.get_node("%TokenLayer")
	var popups: Dictionary = screen.get_node("%BarkPopupLayer")._active_popups
	var err := ""
	if float(layer._tokens[0].get("hop_lift", 0.0)) != 0.0:
		err = "A selected Echo must not hop"
	else:
		_run_settle(screen)
		if not screen._held_barks.is_empty() or not popups.has("echo_01"):
			err = "At settle the held bark must be dropped and the bubble shown"
	m[0].free()
	return { "ok": err.is_empty(), "error": err }


static func _t_settle_diamond_gate_and_switch() -> Dictionary:
	var layer = TelegraphScript.new()
	var shown: bool = false
	var default_off: bool = not layer.visual_config.settle_diamond_enabled
	layer.visual_config.settle_diamond_enabled = true
	layer.show_settle_diamond(Vector2.ONE, _stop_action(true)["stop_short"])
	shown = layer._settle_cell != null
	layer.clear_telegraph()
	var cleared: bool = layer._settle_cell == null
	layer.show_settle_diamond(Vector2.ONE, _stop_action(false)["stop_short"])
	var unperformed: bool = layer._settle_cell != null
	layer.show_settle_diamond(Vector2.ONE, {})
	var plain_move: bool = layer._settle_cell != null
	layer.visual_config.settle_diamond_enabled = false
	layer.show_settle_diamond(Vector2.ONE, _stop_action(true)["stop_short"])
	var switched_off: bool = layer._settle_cell != null
	layer.visual_config.settle_diamond_enabled = true
	layer.show_settle_diamond(Vector2.ONE, _stop_action(true)["stop_short"])
	layer.show_move_telegraph({ "cell_pos": Vector2.ZERO })
	var move_clears: bool = layer._settle_cell == null
	layer.free()
	var move := PresentationStateScript.new()
	move.apply_snapshot([_token("echo_01", 0, 0)], {}, 0.10)
	var event: Dictionary = move.apply_snapshot([_token("echo_01", 1, 0)], { "action_type": "actor.move", "source_id": "echo_01" }, 0.10)
	if not default_off:
		return { "ok": false, "error": "The settle diamond must be off by default" }
	if not shown or not cleared or unperformed or plain_move or switched_off or not move_clears:
		return { "ok": false, "error": "Diamond gate: performed and enabled only; clear and move telegraph remove it" }
	if event.is_empty():
		return { "ok": false, "error": "A plain move must still emit its gold telegraph" }
	return { "ok": true }


static func _guard_token(status: String) -> Dictionary:
	var t := _token("echo_01", 1, 0, false, 0.3)
	t["status"] = status
	return t


static func _t_stance_arc_flag_gated_and_cleared() -> Dictionary:
	var off = PresentationStateScript.new()
	off.apply_snapshot([_token("echo_01", 0, 0, false, 0.3)], {}, 0.0)
	off.apply_snapshot([_guard_token("guarding")], { "action_type": "actor.guard", "source_id": "echo_01" }, 0.0, [], 0.24)
	if off.stop_pose("echo_01") != "":
		return { "ok": false, "error": "An ordinary guard must not set the stop-short flag" }
	var on = _armed_state(0.24)
	on.apply_snapshot([_guard_token("guarding")], _stop_action(), 0.0, [], 0.24)
	if not on.stop_pose("echo_01") != "":
		return { "ok": false, "error": "A performed stop-short guard must set the flag" }
	on.apply_snapshot([_guard_token("guarding")], { "action_type": "actor.idle", "source_id": "enemy_01" }, 0.0, [], 0.24)
	if not on.stop_pose("echo_01") != "":
		return { "ok": false, "error": "Another actor's turn must keep the flag while the guard lasts" }
	on.apply_snapshot([_guard_token("idle")], { "action_type": "actor.idle", "source_id": "enemy_01" }, 0.0, [], 0.24)
	if on.stop_pose("echo_01") != "":
		return { "ok": false, "error": "The flag must clear when the status is no longer guarding" }
	var fast = _armed_state(0.0)
	fast.apply_snapshot([_guard_token("guarding")], _stop_action(), 0.0, [], 0.0)
	if not fast.stop_pose("echo_01") != "" or not fast.is_settled("echo_01"):
		return { "ok": false, "error": "At Fast the flag is set and the token is settled at once" }
	on.reset()
	if on.stop_pose("echo_01") != "":
		return { "ok": false, "error": "Reset must clear the flag" }
	return { "ok": true }


static func _t_ordinary_guard_clears_stop_flag() -> Dictionary:
	var state = _armed_state(0.24)
	state.apply_snapshot([_guard_token("guarding")], _stop_action(), 0.0, [], 0.24)
	if not state.stop_pose("echo_01") != "":
		return { "ok": false, "error": "Setup: a performed stop-short guard must set the flag" }
	state.apply_snapshot([_guard_token("guarding")], { "action_type": "actor.guard", "source_id": "echo_01", "stop_short": {} }, 0.0, [], 0.24)
	if state.stop_pose("echo_01") != "":
		return { "ok": false, "error": "The same actor's later ordinary guard must clear the flag" }
	return { "ok": true }


static func _t_row_text_fallback_unchanged() -> Dictionary:
	var screen = BoardScreenScript.new()
	var cases: Array = [
		[{ "action_type": "melee_attack", "target_name": "Yaw", "damage": 7 }, "Attacks Yaw (7)"],
		[{ "action_type": "melee_attack", "damage": 3 }, "Attacks ? (3)"],
		[{ "action_type": "melee_attack", "target_name": "Yaw", "is_kill": true }, "Kills Yaw"],
		[{ "action_type": "melee_attack", "is_kill": true }, "Kills ?"],
		[{ "action_type": "actor.guard", "stop_short": {} }, "Guards"],
		[{ "action_type": "actor.move", "target_name": "Yaw", "stop_short": {} }, "Move \u2192 Yaw"],
		[{ "action_type": "actor.move", "stop_short": {} }, "Moves"],
		[{ "action_type": "actor.idle", "stop_short": {} }, "Idle"],
		[{ "action_type": "actor.refuse", "stop_short": {} }, "Refuses"],
		[{ "action_type": "actor.dead", "stop_short": {} }, ""],
		[{ "action_type": "actor.mystery", "stop_short": {} }, "actor.mystery"],
		[{ "action_type": "actor.mystery" }, "actor.mystery"],
		[{}, ""],
	]
	var err: String = ""
	for c in cases:
		var got: String = screen._format_action(c[0])
		if got != c[1]:
			err = "%s returned '%s', HEAD returns '%s'" % [str(c[0]), got, c[1]]
			break
	var observe: String = screen._format_action({ "action_type": "actor.observe" })
	screen.free()
	if not err.is_empty():
		return { "ok": false, "error": err }
	if observe.is_empty() or observe == "actor.observe":
		return { "ok": false, "error": "actor.observe must return the benefit word" }
	return { "ok": true }


static func _t_motion_times_and_lift() -> Dictionary:
	for case in [["guard", 0.34], ["hold", 0.36], ["observe", 0.34]]:
		if absf(MotionScript.settle_time(case[0], 1.0) - case[1]) > 0.0001 or absf(MotionScript.settle_time(case[0], 1.6) - case[1] * 1.6) > 0.0001:
			return { "ok": false, "error": "%s landing time must be %s at Normal and x1.6 at Slow" % [case[0], str(case[1])] }
	if MotionScript.settle_time("guard", 0.0) != 0.0 or MotionScript.settle_time("mystery", 1.0) != 0.0:
		return { "ok": false, "error": "Fast and an unknown benefit have no settle time" }
	if MotionScript.view_scale(1.3) != 1.0 or MotionScript.view_scale(0.5) != 2.0 or MotionScript.view_scale(0.35) != 2.0 or absf(MotionScript.view_scale(0.8) - 1.25) > 0.0001:
		return { "ok": false, "error": "Marker scale is 1 / zoom clamped to 1..2" }
	if absf(MotionScript.lean_distance(1.3) - 8.0 / 1.3) > 0.0001 or MotionScript.lean_distance(2.2) != 6.0 or MotionScript.lean_distance(0.35) != 8.0 or MotionScript.lean_distance(0.9) != 8.0:
		return { "ok": false, "error": "Lean is 8 / zoom clamped to 6..8" }
	if MotionScript.hold_body_scale(1.0) != 0.85 or MotionScript.hold_body_scale(0.6) != 0.85 or MotionScript.hold_body_scale(0.59) != 0.78:
		return { "ok": false, "error": "Hold body scale is 0.85, and 0.78 below zoom 0.6" }
	if MotionScript.pose_return_time(1.0) != 0.12 or MotionScript.pose_return_time(1.6) != 0.20 or MotionScript.pose_return_time(0.0) != 0.06:
		return { "ok": false, "error": "Pose return is 0.12 s Normal, 0.20 s Slow" }
	return { "ok": true }


static func _t_hop_curve_shape() -> Dictionary:
	for benefit in ["guard", "hold", "observe"]:
		var total: float = MotionScript.settle_time(benefit, 1.0)
		var dip: float = float(MotionScript.DIP_UNITS[benefit])
		var steps: Array = MotionScript.HOP_STEPS[benefit]
		if MotionScript.hop_height(benefit, 0.0, 17.0) != 0.0 or absf(MotionScript.hop_height(benefit, 1.0, 17.0)) > 0.0001:
			return { "ok": false, "error": "%s hop must start and end on the ground" % benefit }
		var bottom: float = (float(steps[0]) + float(steps[1]) * 0.5) / total
		if absf(MotionScript.hop_height(benefit, bottom, 17.0) + dip) > 0.0001:
			return { "ok": false, "error": "%s must sit %s units down before the rise" % [benefit, str(dip)] }
		var peak: float = (float(steps[0]) + float(steps[1]) + float(steps[2])) / total
		if absf(MotionScript.hop_height(benefit, peak + 0.0001, 17.0) - 17.0) > 0.05:
			return { "ok": false, "error": "%s must reach the full lift at the end of the rise" % benefit }
		if MotionScript.hop_height(benefit, 0.5, 0.0) != 0.0:
			return { "ok": false, "error": "No lift (selected, Fast) means no hop and no dip" }
	return { "ok": true }


static func _t_after_landing_windows() -> Dictionary:
	if MotionScript.shake_x(-1.0) != 0.0 or MotionScript.shake_x(0.10) != 0.0 or MotionScript.rebound_y(-1.0) != 0.0 or MotionScript.rebound_y(0.08) != 0.0:
		return { "ok": false, "error": "Shake and rebound are zero outside their windows (and with no clock)" }
	if absf(MotionScript.shake_x(0.025) - 3.0) > 0.0001 or absf(MotionScript.shake_x(0.075) + 1.5) > 0.0001:
		return { "ok": false, "error": "Guard shake is 3 units, then 1.5 units the other way" }
	if absf(MotionScript.rebound_y(0.04) - 2.0) > 0.0001:
		return { "ok": false, "error": "Hold rebound peaks at 2 units" }
	if MotionScript.pop(-1.0) != Vector2.ONE or MotionScript.pop(0.16) != Vector2.ONE or MotionScript.pop(0.0).x != 0.5 or MotionScript.pop(0.0).y != 0.0:
		return { "ok": false, "error": "Pop starts at half size, invisible, and is steady after 0.16 s" }
	var peak: float = 0.0
	for i in range(0, 160):
		peak = maxf(peak, MotionScript.pop(i * 0.001).x)
	if absf(peak - 1.08) > 0.01:
		return { "ok": false, "error": "Pop peaks at 1.08, got %s" % str(peak) }
	if MotionScript.ripple(-1.0).y != 0.0 or MotionScript.ripple(0.30).y != 0.0 or absf(MotionScript.ripple(0.0).y - 0.7) > 0.0001 or MotionScript.ripple(0.15).x <= 0.5:
		return { "ok": false, "error": "Ripple starts at alpha 0.7, eases out, and ends at 0.30 s" }
	return { "ok": true }


static func _t_guard_arc_is_continuous() -> Dictionary:
	var full: Array[Vector2] = MotionScript.shape_spans("guard", NAN, 29.0, 6.0)
	if not MotionScript.is_full_ring(full):
		return { "ok": false, "error": "Guard with no enemy is a full ring" }
	var angle: float = -PI
	while angle <= PI:
		var spans: Array[Vector2] = MotionScript.shape_spans("guard", angle, 29.0, 6.0)
		if spans.size() != 1 or absf(spans[0].x - (angle - PI * 0.5)) > 0.0001 or absf(spans[0].y - (angle + PI * 0.5)) > 0.0001:
			return { "ok": false, "error": "Enemy angle %s: the Guard arc is one span from a-90 to a+90 degrees, got %s" % [str(angle), str(spans)] }
		angle += 0.1
	return { "ok": true }


static func _t_marker_shapes_and_scale() -> Dictionary:
	var hold: Array[Vector2] = MotionScript.shape_spans("hold", 0.0, 29.0, 6.0)
	var observe: Array[Vector2] = MotionScript.shape_spans("observe", NAN, 29.0, 6.0)
	if not MotionScript.is_full_ring(hold) or MotionScript.is_full_ring(observe):
		return { "ok": false, "error": "Hold is a closed ring; Observe is not" }
	if observe.size() != 4:
		return { "ok": false, "error": "Observe is four dashes" }
	for i in range(4):
		var middle: float = (observe[i].x + observe[i].y) * 0.5
		if absf(middle - (1.0 + 2.0 * i) * PI * 0.25) > 0.0001 or absf((observe[i].y - observe[i].x) * 29.0 - 12.0) > 0.0001:
			return { "ok": false, "error": "Dash %d must sit on a diagonal and be 12 units long" % i }
	return { "ok": true }


static func _pose_state(benefit: String, settle: float = 0.34):
	var state = PresentationStateScript.new()
	var step := { "action_type": "actor.guard", "source_id": "echo_01", "stop_short": { "benefit": benefit, "performed": true } }
	state.apply_snapshot([_token("echo_01", 0, 0, false, 0.3)], {}, 0.0)
	state.apply_snapshot([_guard_token("guarding")], step, 0.0, [], settle)
	return state


static func _t_pose_rises_holds_and_returns() -> Dictionary:
	var state = _pose_state("hold", 0.36)
	state.advance(0.2)
	state.advance(0.2)
	if state.pose_amount("echo_01") != 0.0 or state.pose_shape("echo_01") != "hold" or state.stop_benefit("echo_01") != "hold":
		return { "ok": false, "error": "No pose while the token is still settling; shape and benefit are known" }
	state.advance(0.2)
	state.advance(0.1)
	state.advance(0.15)
	if state.take_settled() != ["echo_01"] or state.pose_amount("echo_01") != 0.0:
		return { "ok": false, "error": "The pose waits 0.08 s after the landing" }
	state.advance(0.1)
	var mid: float = state.pose_amount("echo_01")
	state.advance(0.2)
	if mid <= 0.0 or mid >= 1.0 or state.pose_amount("echo_01") != 1.0:
		return { "ok": false, "error": "The pose rises over 0.20 s, got %s then %s" % [str(mid), str(state.pose_amount("echo_01"))] }
	for i in range(30):
		state.apply_snapshot([_guard_token("guarding")], { "action_type": "actor.idle", "source_id": "enemy_01" }, 0.0, [], 0.0)
		state.advance(0.5)
	if state.pose_amount("echo_01") != 1.0 or state.stop_pose("echo_01") != "hold":
		return { "ok": false, "error": "The pose lasts the whole guarding status, not one snapshot" }
	state.apply_snapshot([_guard_token("idle")], { "action_type": "actor.idle", "source_id": "enemy_01" }, 0.0, [], 0.0)
	state.advance(0.06)
	var returning: float = state.pose_amount("echo_01")
	if returning <= 0.0 or returning >= 1.0 or state.stop_pose("echo_01") != "" or state.pose_shape("echo_01") != "hold":
		return { "ok": false, "error": "When the status ends the pose eases back and keeps its shape meanwhile, got %s" % str(returning) }
	state.advance(0.07)
	if state.pose_amount("echo_01") != 0.0 or state.pose_shape("echo_01") != "":
		return { "ok": false, "error": "The pose is gone 0.12 s after the status ended" }
	var slow = _pose_state("guard", 0.544)
	slow.motion_scale = 1.6
	for i in range(20):
		slow.advance(0.1)
	slow.apply_snapshot([_guard_token("idle")], { "action_type": "actor.idle", "source_id": "enemy_01" }, 0.0, [], 0.0)
	slow.advance(0.15)
	if slow.pose_amount("echo_01") <= 0.0:
		return { "ok": false, "error": "At Slow the return takes 0.20 s" }
	return { "ok": true }


static func _t_pose_fast_snaps_and_angle_freezes() -> Dictionary:
	var fast = _pose_state("guard", 0.0)
	fast.motion_scale = 0.0
	fast.advance(0.3)
	fast.advance(0.01)
	if fast.pose_amount("echo_01") != 1.0:
		return { "ok": false, "error": "At Fast the pose snaps in when the walk ends" }
	if fast.has_pose_angle("echo_01"):
		return { "ok": false, "error": "No angle is frozen until the layer sets one" }
	fast.set_pose_angle("echo_01", 1.0)
	fast.apply_snapshot([_guard_token("guarding")], { "action_type": "actor.idle", "source_id": "enemy_01" }, 0.0, [], 0.0)
	if fast.pose_angle("echo_01") != 1.0:
		return { "ok": false, "error": "The frozen angle survives later snapshots" }
	var again := { "action_type": "actor.guard", "source_id": "echo_01", "stop_short": { "benefit": "guard", "performed": true } }
	fast.apply_snapshot([_guard_token("guarding")], again, 0.0, [], 0.0)
	if not fast.has_pose_angle("echo_01"):
		return { "ok": false, "error": "A repeated snapshot of the same step must keep the angle" }
	var ordinary = _pose_state("observe")
	if ordinary.stop_pose("echo_01") != "" or ordinary.pose_shape("echo_01") != "":
		return { "ok": false, "error": "An Observe step gives no rest pose" }
	return { "ok": true }
