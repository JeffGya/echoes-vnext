extends SceneTree

const PrototypeTestSuite = preload("res://prototypes/keeper_tactical_guidance/tests/PrototypeTestSuite.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result: Dictionary = PrototypeTestSuite.run_all()
	var controller_checks: Array[Dictionary] = await _run_controller_checks()
	for controller_result: Dictionary in controller_checks:
		(result["results"] as Array).append(controller_result)
		result["total"] = int(result["total"]) + 1
		if bool(controller_result["ok"]):
			result["passed"] = int(result["passed"]) + 1
		else:
			result["failed"] = int(result["failed"]) + 1
	print("\nKeeper Tactical Guidance prototype tests")
	for entry_value: Variant in result.get("results", []):
		var entry: Dictionary = entry_value as Dictionary
		var status: String = "PASS" if bool(entry.get("ok", false)) else "FAIL"
		print("[%s] %s%s" % [status, entry.get("name", "unnamed"),
			"" if bool(entry.get("ok", false)) else ": " + str(entry.get("error", ""))])
	print("Result: %d/%d passed; %d failed" % [
		result.get("passed", 0), result.get("total", 0), result.get("failed", 0)])
	quit(0 if int(result.get("failed", 0)) == 0 else 1)


func _run_controller_checks() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var packed: PackedScene = load("res://prototypes/keeper_tactical_guidance/KeeperTacticalGuidance.tscn")
	if packed == null:
		return [{"name": "controller/entry_scene_load", "ok": false, "error": "entry scene did not load"}]
	var controller: Node = packed.instantiate()
	root.add_child(controller)
	await process_frame
	var initial: Dictionary = controller.call("get_snapshot")
	if str(initial.get("type", "")) != "prototype.briefing":
		controller.queue_free()
		return [{"name": "controller/entry_scene_load", "ok": false, "error": "entry scene did not publish briefing"}]
	results.append({"name": "controller/entry_scene_load", "ok": true, "error": ""})
	controller.call("handle_action", {"type": "prototype.phase.prepare", "payload": {}})
	var prep: Dictionary = controller.call("get_snapshot")
	var roster: Array = prep.get("data", {}).get("party_roster", [])
	var assignments: Dictionary = prep.get("data", {}).get("deployment_assignments", {})
	var prep_ok: bool = roster.size() == 4 and assignments.size() == 4
	var prep_error: String = ""
	if not prep_ok:
		prep_error = "preparation did not expose one four-Echo roster and one assignment map"
	else:
		var first_id: String = str((roster[0] as Dictionary).get("id", ""))
		var second_id: String = str((roster[1] as Dictionary).get("id", ""))
		var first_slot: int = int(assignments.get(first_id, -1))
		var second_slot: int = int(assignments.get(second_id, -1))
		controller.call("handle_action", {"type": "prototype.deployment.select_echo", "payload": {"actor_id": first_id}})
		controller.call("handle_action", {"type": "prototype.deployment.assign_slot", "payload": {"slot_index": second_slot}})
		var swapped: Dictionary = (controller.call("get_snapshot") as Dictionary).get("data", {}).get("deployment_assignments", {})
		if int(swapped.get(first_id, -1)) != second_slot or int(swapped.get(second_id, -1)) != first_slot:
			prep_ok = false
			prep_error = "single roster selection to occupied board slot did not swap assignments"
		var prep_actions: Dictionary = prep.get("actions", {})
		for action_v: Variant in prep_actions.values():
			var action: Dictionary = action_v if action_v is Dictionary else {}
			if str(action.get("type", "")).contains("actor_token"):
				prep_ok = false
				prep_error = "preparation exposed a duplicate board-token Echo selection action"
	results.append({"name": "controller/single_roster_slot_swap", "ok": prep_ok, "error": prep_error})
	controller.call("handle_action", {"type": "prototype.directive.select", "payload": {"directive_id": "press_the_path"}})
	controller.call("handle_action", {"type": "prototype.combat.start", "payload": {}})
	var combat: Dictionary = controller.call("get_snapshot")
	var combat_actions: Dictionary = combat.get("actions", {})
	var forbidden: Array[String] = ["prototype.combat.next", "prototype.combat.pause", "prototype.combat.resume", "prototype.ping.request", "prototype.playback.step", "prototype.playback.toggle"]
	var action_types: Array[String] = []
	for action_v: Variant in combat_actions.values():
		var action: Dictionary = action_v if action_v is Dictionary else {}
		action_types.append(str(action.get("type", "")))
	var surface_ok: bool = not action_types.any(func(type: String) -> bool: return type in forbidden) \
		and action_types.has("prototype.playback.speed") and action_types.has("prototype.ping.select") \
		and not (controller.get_node("PlaybackTimer") as Timer).is_stopped() \
		and not (controller.get_node("PrototypeUI").get_node("%RoutesToggle") as CheckButton).visible \
		and not (controller.get_node("PrototypeUI").get_node("%ChokepointsToggle") as CheckButton).visible
	results.append({"name": "controller/automatic_only_action_surface", "ok": surface_ok,
		"error": "combat exposed pause/manual controls, analysis overlays, or failed to start automatic timer" if not surface_ok else ""})

	var timer: Timer = controller.get_node("PlaybackTimer") as Timer
	var intervals: Dictionary = {}
	for speed_id: String in ["slow", "normal", "fast"]:
		controller.call("handle_action", {"type": "prototype.playback.speed", "payload": {"speed_id": speed_id}})
		intervals[speed_id] = timer.wait_time
	var speed_ok: bool = float(intervals["slow"]) > float(intervals["normal"]) \
		and float(intervals["normal"]) > float(intervals["fast"])
	results.append({"name": "controller/slow_normal_fast_intervals", "ok": speed_ok,
		"error": "speed controls did not produce ordered presentation intervals" if not speed_ok else ""})

	controller.call("handle_action", {"type": "prototype.playback.speed", "payload": {"speed_id": "fast"}})
	var tick_before: int = int((controller.call("get_snapshot") as Dictionary).get("meta", {}).get("t", 0))
	await create_timer(timer.wait_time + 0.15).timeout
	var tick_after: int = int((controller.call("get_snapshot") as Dictionary).get("meta", {}).get("t", 0))
	results.append({"name": "controller/timer_advances_automatically", "ok": tick_after > tick_before,
		"error": "automatic timer did not advance combat" if tick_after <= tick_before else ""})

	var simulation: RefCounted = controller.get("_simulation")
	var sim_state: Dictionary = simulation.call("get_state")
	sim_state["ping_charge"]["current"] = 5
	simulation.set("_state", sim_state)
	var echo: Dictionary = _first_actor(sim_state, "echo")
	var echo_pos: Dictionary = echo.get("grid_pos", {}).duplicate(true)
	controller.call("handle_action", {"type": "prototype.ping.select", "payload": {"ping_id": "hold_ground"}})
	controller.call("handle_action", {"type": "prototype.ping.preview", "payload": {"ping_id": "hold_ground", "subject": {"actor_id": echo.get("id", ""), "anchor": echo_pos}}})
	var preview_snapshot: Dictionary = controller.call("get_snapshot")
	var preview: Dictionary = preview_snapshot.get("data", {}).get("ping_preview", {})
	var live_preview_ok: bool = not timer.is_stopped() and not preview.is_empty() \
		and not str(preview.get("suggestion", "")).is_empty() and not (preview.get("footprint", []) as Array).is_empty()
	controller.call("handle_action", {"type": "prototype.ping.confirm", "payload": {"ping_id": "hold_ground", "subject": preview.get("subject", {})}})
	var queued: Dictionary = (controller.call("get_snapshot") as Dictionary).get("data", {}).get("queued_ping_confirmation", {})
	if queued.is_empty() or timer.is_stopped():
		live_preview_ok = false
	controller.call("_on_playback_timer_timeout")
	var committed_data: Dictionary = (controller.call("get_snapshot") as Dictionary).get("data", {})
	if not (committed_data.get("queued_ping_confirmation", {}) as Dictionary).is_empty() \
			or (committed_data.get("unresolved_ping", {}) as Dictionary).is_empty():
		live_preview_ok = false
	results.append({"name": "controller/live_ping_browse_preview_confirm", "ok": live_preview_ok,
		"error": "ping interaction paused playback or failed atomic-boundary commit" if not live_preview_ok else ""})

	# Drive the same automatic timer callback used by playback, without injecting a player
	# step action. This keeps the full journey bounded in headless verification.
	timer.stop()
	for _turn: int in range(500):
		var snapshot: Dictionary = controller.call("get_snapshot")
		if str(snapshot.get("type", "")) == "prototype.review":
			var timeline: Array = snapshot.get("data", {}).get("timeline", [])
			controller.queue_free()
			results.append({"name": "controller/automatic_briefing_to_review", "ok": not timeline.is_empty(),
				"error": "review omitted timeline" if timeline.is_empty() else ""})
			return results
		controller.call("_on_playback_timer_timeout")
	controller.queue_free()
	results.append({"name": "controller/automatic_briefing_to_review", "ok": false,
		"error": "automatic controller journey did not reach review"})
	return results


func _first_actor(state: Dictionary, faction: String) -> Dictionary:
	for actor_v: Variant in state.get("actors", []):
		var actor: Dictionary = actor_v if actor_v is Dictionary else {}
		if str(actor.get("faction", "")) == faction and not bool(actor.get("is_dead", false)):
			return actor
	return {}
