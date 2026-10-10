extends SceneTree

const Suite = preload("res://prototypes/sanctum_systems_exploration/tests/PrototypeTestSuite.gd")
const Gate2Suite = preload("res://prototypes/sanctum_systems_exploration/tests/PrototypeGate2Tests.gd")
const Gate3Suite = preload("res://prototypes/sanctum_systems_exploration/tests/PrototypeGate3Tests.gd")
const Capture = preload("res://prototypes/sanctum_systems_exploration/tests/VisualCapture.gd")
const LoggerScript = preload("res://core/log/StructuredLogger.gd")
var _controller_completed := false
var _sections: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var backend_only := "--backend-only" in OS.get_cmdline_user_args()
	var results: Array[Dictionary] = Suite.run_all()
	results.append_array(Gate2Suite.run_all())
	results.append_array(Gate3Suite.run_all())
	if not backend_only:
		results.append_array(await _controller_checks())
		Suite._check(results, "harness/controller_checks_reached_end", _controller_completed)
		Suite._check(results, "harness/all_integration_sections_reached_end", _sections.size() == 9)
	var failed := 0
	var logger = LoggerScript.new()
	for result: Dictionary in results:
		logger.info(0, "prototype.test", result.name, result)
		if not result.ok:
			failed += 1
			push_error("FAILED: " + str(result.name))
	var report := {"mode": "backend" if backend_only else "integration", "total": results.size(), "passed": results.size() - failed, "failed": failed, "results": results}
	var report_path := "/tmp/sanctum_prototype_backend_tests.json" if backend_only else "/tmp/sanctum_prototype_tests.json"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write prototype verification report: " + report_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	quit(0 if failed == 0 else 1)


func _controller_checks() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var packed: PackedScene = load("res://prototypes/sanctum_systems_exploration/SanctumLivingHouse.tscn")
	var controller: Node = packed.instantiate()
	controller.set_process(false)
	root.add_child(controller)
	await process_frame
	var ready := controller.has_method("advance_elapsed") and controller.has_method("set_application_focused")
	Suite._check(results, "controller/fixed_step_scheduler_seams_available", ready)
	if not ready:
		controller.queue_free()
		return results
	var ui: Control = controller.get_node("PrototypeUI")
	var world: Control = ui.get_node("HouseView")
	var snap: Dictionary = controller.get_snapshot()
	Suite._check(results, "scene/standalone_setup_and_slot_dictionary", snap.type == "prototype.sanctum.setup" and snap.actions is Dictionary)
	_capture_matrix_contract(results)
	_command(controller, "subject.select", {"kind": "site", "id": "hearth_near"})
	ui.get_node("%Choice0").pressed.emit()
	_command(controller, "subject.select", {"kind": "site", "id": "training_far"})
	ui.get_node("%Choice0").pressed.emit()
	ui.get_node("%Start").pressed.emit()
	snap = controller.get_snapshot()
	Suite._check(results, "ui/site_controls_reach_living_start", snap.data.placements.size() == 2 and snap.data.phase == "living" and snap.data.speed == "normal")
	controller.advance_elapsed(0.1)
	_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
	ui.get_node("%Choice0").pressed.emit()
	controller.advance_elapsed(0.15)
	snap = controller.get_snapshot()
	Suite._check(results, "controller/selection_observe_preserve_time_without_reservation", snap.meta.t == 1 and snap.data.speed == "normal" and snap.data.observing and snap.data.conversation.is_empty())
	_scheduler_checks(results, controller)
	_conversation_checks(results, controller, ui)
	await _gate2_controller_checks(results, controller, ui, world)
	await _gate3_controller_checks(results, controller, ui, world)
	await _reaction_voice_ui_checks(results, controller, ui, world)
	await _inspection_checks(results, controller, ui, world)
	controller.queue_free()
	await process_frame
	_controller_completed = true
	return results


func _capture_matrix_contract(results: Array[Dictionary]) -> void:
	var matrix: Array = Capture.capture_matrix()
	var expected_primary := ["overview", "social_engagement", "reaction_exchange", "incident_warning_midpoint", "incident_private_open",
		"incident_open_midpoint", "incident_appeal_open", "incident_joined", "incident_deferred", "incident_resolved_aftermath", "incident_post_release",
		"echo_relationship", "crowded_incident", "focus_person", "focus_place", "gate3_ready", "gate3_confirm",
		"gate3_manifestation", "gate3_welcome", "gate3_completion", "visual_incident_result", "nine_echo_crowd", "practice_witness_warning"]
	var exact_profiles: bool = matrix.size() == 4
	if exact_profiles:
		exact_profiles = matrix[0].profile == "primary" and matrix[0]["size"] == Vector2i(1920, 1080) and matrix[0].modes == expected_primary
		exact_profiles = exact_profiles and matrix[1].profile == "secondary" and matrix[1]["size"] == Vector2i(1600, 900)
		exact_profiles = exact_profiles and matrix[2].profile == "secondary" and matrix[2]["size"] == Vector2i(1280, 720)
		exact_profiles = exact_profiles and matrix[3].profile == "edge" and matrix[3]["size"] == Vector2i(960, 540)
		for index: int in range(1, 4):
			exact_profiles = exact_profiles and matrix[index].modes.has("gate3_welcome") \
				and matrix[index].modes.has("visual_incident_result") and matrix[index].modes.has("nine_echo_crowd") \
				and matrix[index].modes.has("practice_witness_warning")
	Suite._check(results, "capture/1920_story_sequence_precedes_secondary_and_edge_profiles", exact_profiles)


func _reset_live(controller: Node) -> void:
	_command(controller, "session.reset")
	controller.set_application_focused(true)
	controller.advance_elapsed(0.0)


func _scheduler_checks(results: Array[Dictionary], controller: Node) -> void:
	_reset_live(controller)
	for index: int in range(8):
		controller.advance_elapsed(0.25)
	var partitioned: Dictionary = _state(controller)
	_reset_live(controller)
	controller.advance_elapsed(2.0)
	Suite._check(results, "controller/frame_partitions_preserve_complete_simulation", _state(controller) == partitioned and controller.get_snapshot().meta.t == 8)
	_reset_live(controller)
	_command(controller, "playback.speed", {"speed": "fast"})
	controller.advance_elapsed(2.0)
	var fast: Dictionary = _state(controller)
	_reset_live(controller)
	for index: int in range(24):
		controller.advance_elapsed(0.25)
	Suite._check(results, "controller/fast_three_times_normal_identical_outcomes", _state(controller) == fast and controller.get_snapshot().meta.t == 24)
	_reset_live(controller)
	controller.advance_elapsed(0.1)
	_command(controller, "playback.speed", {"speed": "fast"})
	controller.advance_elapsed(0.05)
	Suite._check(results, "controller/speed_switch_preserves_fraction", controller.get_snapshot().meta.t == 1)
	_reset_live(controller)
	controller.advance_elapsed(20.0)
	var capped: int = controller.get_snapshot().meta.t
	for index: int in range(10):
		controller.advance_elapsed(0.0)
	Suite._check(results, "controller/work_cap_retains_backlog", capped > 0 and capped <= 32 and controller.get_snapshot().meta.t == 80)
	_reset_live(controller)
	controller.advance_elapsed(0.2)
	_command(controller, "playback.speed", {"speed": "paused"})
	controller.advance_elapsed(100.0)
	_command(controller, "playback.speed", {"speed": "normal"})
	controller.advance_elapsed(0.05)
	Suite._check(results, "controller/pause_discards_fraction_and_wall_catchup", controller.get_snapshot().meta.t == 0)
	controller.advance_elapsed(0.2)
	Suite._check(results, "controller/unpause_uses_new_elapsed_only", controller.get_snapshot().meta.t == 1)
	_reset_live(controller)
	controller.advance_elapsed(0.2)
	controller.set_application_focused(false)
	controller.advance_elapsed(100.0)
	controller.set_application_focused(true)
	controller.advance_elapsed(20.0)
	controller.advance_elapsed(0.05)
	Suite._check(results, "controller/focus_discards_catchup_and_regain_delta", controller.get_snapshot().meta.t == 0)
	controller.advance_elapsed(0.2)
	Suite._check(results, "controller/focus_resume_uses_fresh_fraction", controller.get_snapshot().meta.t == 1)
	_reset_live(controller)
	var oracle = Suite.Simulation.new()
	oracle.set("_state", _state(controller))
	var advanced := 0
	for index: int in range(240):
		advanced += 1
		if oracle.advance_step(oracle.get_step() + 1):
			break
	_command(controller, "playback.next")
	Suite._check(results, "controller/next_beat_matches_first_meaningful_step", _state(controller) == oracle.get_state() and controller.get_snapshot().meta.t == advanced and advanced <= 240 and controller.get_snapshot().data.speed == "paused")
	var before: Dictionary = _state(controller)
	controller.advance_elapsed(10.0)
	Suite._check(results, "controller/next_beat_stays_paused", _state(controller) == before)
	_sections["scheduler"] = true


func _state(controller: Node) -> Dictionary:
	return controller.get("_simulation").get_state()


func _conversation_checks(results: Array[Dictionary], controller: Node, ui: Control) -> void:
	_reset_live(controller)
	controller.advance_elapsed(4.0)
	var moving: Dictionary = {}
	for person: Dictionary in controller.get_snapshot().data.echoes:
		if person.moving:
			moving = person
			break
	Suite._check(results, "controller/moving_fixture_available", not moving.is_empty())
	if moving.is_empty():
		return
	_command(controller, "subject.select", {"kind": "echo", "id": moving.id})
	ui.get_node("%Choice1").pressed.emit()
	Suite._check(results, "ui/speak_mover_enters_approach", controller.get_snapshot().data.conversation.get("status", "") == "approaching" and ui.get_node("%NextBeat").disabled)
	var step_before: int = controller.get_snapshot().meta.t
	_command(controller, "playback.next")
	Suite._check(results, "controller/next_blocked_during_approach", controller.get_snapshot().meta.t == step_before)
	var topics_disabled := true
	for index: int in range(4):
		var choice: Button = ui.get_node("%Choice" + str(index))
		var choice_action: Dictionary = controller.get_snapshot().actions.get("cta.choice_%d" % index, {})
		if choice.visible and "topic" in str(choice_action.get("type", "")):
			topics_disabled = topics_disabled and choice.disabled
	Suite._check(results, "ui/topics_unavailable_during_approach", topics_disabled)
	for index: int in range(400):
		if controller.get_snapshot().data.conversation.get("status", "") == "choosing":
			break
		controller.advance_elapsed(0.25)
	Suite._check(results, "controller/approach_holds_at_next_node", controller.get_snapshot().data.conversation.get("status", "") == "choosing" and Suite._echo(controller.get_snapshot().data, moving.id).node == moving.path[0])
	ui.get_node("%Choice0").pressed.emit()
	Suite._check(results, "ui/topic_control_reaches_simulation", controller.get_snapshot().data.conversation.topic == "feelings")
	step_before = controller.get_snapshot().meta.t
	_command(controller, "playback.next")
	Suite._check(results, "controller/next_blocked_during_choice", controller.get_snapshot().meta.t == step_before)
	ui.get_node("%Back").pressed.emit()
	Suite._check(results, "ui/back_cancels_uncommitted_conversation", controller.get_snapshot().data.conversation.is_empty())
	for reduced: bool in [false, true]:
		_reset_live(controller)
		ui.get_node("%Lab").pressed.emit()
		ui.get_node("%ReducedMotion").set_pressed(reduced)
		ui.get_node("%Back").pressed.emit()
		_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
		ui.get_node("%Choice1").pressed.emit()
		ui.get_node("%Choice0").pressed.emit()
		ui.get_node("%Choice0").pressed.emit()
		var committed: Dictionary = controller.get_snapshot()
		Suite._check(results, "ui/real_reply_commits_reduced_%s" % reduced, committed.data.conversation.get("status", "") == "resolved")
		ui.get_node("%Pause").pressed.emit()
		controller.advance_elapsed(100.0)
		ui.get_node("%Back").pressed.emit()
		_command(controller, "subject.select", {"kind": "echo", "id": "kojo"})
		_command(controller, "playback.next")
		_command(controller, "conversation.reply", {"reply": "space"})
		Suite._check(results, "controller/paused_commit_cannot_expire_or_discard_reduced_%s" % reduced, controller.get_snapshot().meta.t == committed.meta.t and controller.get_snapshot().data.conversation == committed.data.conversation)
		ui.get_node("%Normal").pressed.emit()
		controller.advance_elapsed(1.25)
		Suite._check(results, "controller/reply_visible_five_steps_reduced_%s" % reduced, controller.get_snapshot().data.conversation.get("status", "") == "resolved")
		controller.advance_elapsed(0.25)
		Suite._check(results, "controller/release_sixth_step_reduced_%s" % reduced, controller.get_snapshot().data.conversation.is_empty() and controller.get_snapshot().meta.t == committed.meta.t + 6)
	_sections["conversation"] = true


func _gate2_controller_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	var controller_sim = controller.get("_simulation")
	var social = Gate2Suite._social_pair(["kweku", "yaw"], "flame", {
		"kweku": {"family": "company", "pressures": {"rest": 4.0, "company": 18.0, "purpose": 4.0}},
		"yaw": {"family": "rest", "pressures": {"rest": 18.0, "company": 10.0, "purpose": 4.0}}}, 3.0)
	controller_sim.set("_state", social.get_state())
	controller.set("_elapsed", 0.0)
	_command(controller, "playback.speed", {"speed": "normal"})
	_command(controller, "playback.next")
	var social_stop: Dictionary = controller.get_snapshot()
	var stopped_events: Array = social_stop.data.events.filter(func(event: Dictionary) -> bool: return event.kind in ["social_exchange", "incident_warning"])
	Suite._check(results, "controller/next_beat_stops_on_enacted_social_warning", social_stop.data.speed == "paused" and social_stop.meta.t <= 240 and stopped_events.any(func(event: Dictionary) -> bool: return event.kind == "social_exchange") and stopped_events.any(func(event: Dictionary) -> bool: return event.kind == "incident_warning"))

	var fixture: Dictionary = Gate2Suite._warning_fixture(15.0, 45.0)
	var warning_id: String = fixture.incident.id
	var warning_state: Dictionary = _settled_incident_state(fixture.sim.get_state())
	controller_sim.set("_state", warning_state.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "playback.speed", {"speed": "normal"})
	_command(controller, "subject.select", {"kind": "place", "id": "quiet"})
	var warning_snapshot: Dictionary = controller.get_snapshot()
	var selection_before: Dictionary = warning_snapshot.data.selection
	var incident_subject := {"kind": "incident", "id": warning_id}
	var warning_projection: Dictionary = Gate2Suite._incident(warning_snapshot.data, warning_id)
	var incident_hits: Array = world._hits(world._incident_screen(warning_projection))
	Suite._check(results, "world/warning_is_selectable_real_incident_subject", world._subjects().has(incident_subject) and incident_hits.has(incident_subject) and world._incident_color("warning") != world._incident_color("open"))
	_command(controller, "subject.select", incident_subject)
	world._process(0.25)
	var warning_world: Dictionary = world.capture_metrics(incident_subject)
	var warning_ui: Dictionary = ui.presentation_metrics()
	var warning_metadata: Dictionary = Capture.capture_metadata(controller, "incident_warning_midpoint", 1920, 1080)
	Suite._check(results, "world/warning_uses_compact_notification_without_incident_standard",
		str(warning_world.incident_signature) == "warning:compact_notification" and not str(warning_world.incident_signature).contains("standard"))
	var shared_incident_zoom: float = float(world.get("_zoom_target"))
	_command(controller, "subject.select", {"kind": "echo", "id": warning_projection.participants[0]})
	var shared_echo_zoom: float = float(world.get("_zoom_target"))
	_command(controller, "subject.select", {"kind": "place", "id": warning_projection.place})
	var shared_place_zoom: float = float(world.get("_zoom_target"))
	_command(controller, "subject.select", incident_subject)
	Suite._check(results, "camera/echo_place_incident_share_identical_focus_zoom_amount",
		absf(shared_echo_zoom - shared_place_zoom) <= 0.000001 and absf(shared_echo_zoom - shared_incident_zoom) <= 0.000001)
	Suite._check(results, "ui/warning_uses_authored_incident_component_without_raw_normal_values", warning_ui.minimum_font_size >= 16 and warning_ui.normal_surface == "incident" and warning_ui.components.incident and not _visual_has_forbidden_raw_keys(controller.get_snapshot().data.panel.visual) and not _normal_surface_has_raw_values(ui))
	var warning_metadata_ok: bool = warning_metadata.minimum_visible_font_size >= 16 and warning_metadata.participants.size() == 2 and not warning_metadata.issue_state.is_empty() and warning_metadata.subject_bounds is Rect2 and warning_metadata.usable_world_rect is Rect2 and warning_metadata.occupancy is Vector2
	results.append({"name": "capture/warning_metadata_records_real_people_issue_fonts_and_geometry", "ok": warning_metadata_ok,
		"details": {"minimum_visible_font_size": warning_metadata.minimum_visible_font_size,
			"participant_count": warning_metadata.participants.size(), "issue_present": not warning_metadata.issue_state.is_empty(),
			"subject_bounds": warning_metadata.subject_bounds, "usable_world_rect": warning_metadata.usable_world_rect,
			"occupancy": warning_metadata.occupancy}})
	Suite._check(results, "keyboard/warning_without_choices_focuses_back", ui.get_node("%Back").has_focus())
	_command(controller, "subject.select", selection_before)
	for index: int in range(60):
		controller.advance_elapsed(0.25)
	var open_snapshot: Dictionary = controller.get_snapshot()
	var open_incident: Dictionary = Gate2Suite._incident(open_snapshot.data, warning_id)
	Suite._check(results, "controller/warning_open_transition_preserves_focus_and_playback", open_incident.status == "open" and open_snapshot.data.selection == selection_before and open_snapshot.data.speed == "normal")
	_command(controller, "subject.select", incident_subject)
	world._process(0.25)
	var open_signature: String = str(world.capture_metrics(incident_subject).incident_signature)
	_command(controller, "subject.select", selection_before)

	controller_sim.set("_state", warning_state.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "playback.next")
	var open_from_next: Dictionary = controller.get_snapshot()
	var next_open_incident: Dictionary = Gate2Suite._incident(open_from_next.data, warning_id)
	Suite._check(results, "controller/next_beat_stops_on_incident_open", next_open_incident.status == "open" and open_from_next.data.speed == "paused" and open_from_next.data.events.any(func(event: Dictionary) -> bool: return event.kind == "incident_open" and event.incident_id == warning_id))
	var open_state: Dictionary = _state(controller).duplicate(true)

	controller_sim.set("_state", warning_state.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "playback.speed", {"speed": "paused"})
	var paused_warning: Dictionary = _state(controller)
	controller.advance_elapsed(100.0)
	Suite._check(results, "controller/pause_freezes_incident_deadline", _state(controller) == paused_warning)
	_command(controller, "playback.speed", {"speed": "fast"})
	controller.advance_elapsed(1.0)
	var fast_warning: Dictionary = _state(controller)
	controller_sim.set("_state", warning_state.duplicate(true))
	_command(controller, "playback.speed", {"speed": "paused"})
	_command(controller, "playback.speed", {"speed": "normal"})
	controller.advance_elapsed(3.0)
	Suite._check(results, "controller/fast_advances_incident_deadline_exactly_three_times_normal", _state(controller) == fast_warning)

	controller_sim.set("_state", open_state.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "playback.speed", {"speed": "normal"})
	var observation_before: int = controller.get_snapshot().data.observation_serial
	_command(controller, "incident.join", {"incident_id": warning_id})
	var joined_snapshot: Dictionary = controller.get_snapshot()
	var joined_incident: Dictionary = Gate2Suite._incident(joined_snapshot.data, warning_id)
	world._process(0.25)
	var incident_focus := {"kind": "incident", "id": warning_id}
	var joined_choices: Array = joined_snapshot.data.panel.choices
	var joined_state: Dictionary = _state(controller)
	Suite._check(results, "ui/incident_replies_show_authored_qualitative_direction_before_commitment",
		joined_incident.reply_choices.size() == 2 and _reply_choices_have_qualitative_cues(joined_incident.reply_choices))
	Suite._check(results, "controller/join_selects_and_refocuses_incident_camera", joined_snapshot.data.selection == incident_focus and joined_snapshot.data.observation_serial == observation_before + 1 and world.get("_pan_target").is_equal_approx(world._focus_pan(incident_focus)))
	var joined_world: Dictionary = world.capture_metrics(incident_focus)
	Suite._check(results, "ui/joined_incident_exposes_reply_and_explicit_defer_actions", joined_snapshot.data.panel.kind == "incident" and joined_snapshot.data.panel.context_key == "%s|joined" % warning_id and joined_choices.size() == 3 and joined_choices.slice(0, 2).all(func(choice: Dictionary) -> bool: return choice.type == "prototype.incident.reply") and joined_choices[-1].type == "prototype.incident.defer" and ui.get_node("%Choice0").has_focus())
	Suite._check(results, "controller/joined_incident_disables_next_and_blocks_speak", joined_snapshot.actions["cta.next"].disabled and not controller_sim.apply_action({"type": "prototype.conversation.begin", "payload": {"echo_id": joined_incident.participants[0]}}, controller_sim.get_step()))
	ui.get_node("%Back").pressed.emit()
	var closed_joined: Dictionary = controller.get_snapshot()
	Suite._check(results, "ui/back_closes_joined_panel_without_deferring_or_releasing", closed_joined.data.selection.is_empty() and _state(controller) == joined_state and closed_joined.data.joined_incident_id == warning_id)
	_command(controller, "subject.select", incident_focus)
	var reopened_remaining: int = int(Gate2Suite._incident(controller.get_snapshot().data, warning_id).remaining_ms)
	_click_empty(world)
	Suite._check(results, "world/empty_click_closes_joined_panel_without_replenishing", controller.get_snapshot().data.selection.is_empty() and _state(controller) == joined_state and int(Gate2Suite._incident(controller.get_snapshot().data, warning_id).remaining_ms) == reopened_remaining)
	_command(controller, "subject.select", incident_focus)
	ui.get_node("%Choice0").pressed.emit()
	var resolved_snapshot: Dictionary = controller.get_snapshot()
	var resolved_state: Dictionary = _state(controller)
	var resolved_visual: Dictionary = resolved_snapshot.data.panel.visual
	var resolved_result: Dictionary = resolved_visual.get("result", {})
	var resolved_raw_result: Dictionary = Gate2Suite._incident(resolved_snapshot.data, warning_id).get("result", {})
	var resolved_history: Array = resolved_snapshot.data.village_history.filter(func(item: Dictionary) -> bool:
		return item.get("kind", "") == "incident_resolved" and item.get("incident_id", "") == warning_id)
	var resolved_world: Dictionary = world.capture_metrics(incident_focus)
	Suite._check(results, "ui/incident_reply_renders_structured_visual_response_and_aftermath", Gate2Suite._incident(resolved_snapshot.data, warning_id).status == "resolved" and resolved_visual.get("type", "") == "incident" and resolved_result.get("effects", []).size() == 2 and not str(resolved_result.get("aftermath", "")).is_empty() and resolved_result.get("bond", {}).has_all(["before", "after"]) and ui.presentation_metrics().components.incident)
	Suite._check(results, "ui/resolved_current_retains_exchange_status_why_action_and_scannable_outcome",
		resolved_visual.has_all(["exchange_lines", "why", "status_text", "action", "result"])
		and resolved_visual.exchange_lines.size() == 2
		and ["now", "why", "status_text", "action"].all(func(key: String) -> bool: return not str(resolved_visual.get(key, "")).is_empty())
		and resolved_result.has_all(["aftermath", "effects", "bond", "participant_views", "keeper_reactions", "next_behaviors"]))
	Suite._check(results, "incident/keeper_resolution_retains_structured_views_and_reactions_in_result_and_history",
		_incident_views_are_structured(resolved_raw_result.get("participant_views", []), "view_of_other")
		and _incident_views_are_structured(resolved_raw_result.get("keeper_reactions", []), "reaction")
		and resolved_raw_result.get("participant_views", []).size() == 2
		and resolved_raw_result.get("keeper_reactions", []).size() == 2
		and resolved_history.size() == 1
		and _incident_views_are_structured(resolved_history[0].get("participant_views", []), "view_of_other")
		and _incident_views_are_structured(resolved_history[0].get("keeper_reactions", []), "reaction"))
	Suite._check(results, "ui/resolved_incident_humanizes_reply_without_raw_values", resolved_result.get("response_label", "") == "Give Space" and not JSON.stringify(resolved_visual).contains("give_space") and not _visual_has_forbidden_raw_keys(resolved_visual) and not _normal_surface_has_raw_values(ui))
	Suite._check(results, "world/incident_standard_begins_at_open_and_later_stages_remain_distinct",
		str(warning_world.incident_signature) == "warning:compact_notification"
		and [open_signature, str(joined_world.incident_signature), str(resolved_world.incident_signature)].all(func(signature: String) -> bool: return signature.contains("standard+tether+connectors"))
		and {str(warning_world.incident_signature): true, open_signature: true, str(joined_world.incident_signature): true, str(resolved_world.incident_signature): true}.size() == 4)
	var pending_overlay: Dictionary = resolved_snapshot.data.incident_result_overlay
	Suite._check(results, "ui/keeper_resolution_opens_persistent_full_screen_result",
		not pending_overlay.is_empty() and pending_overlay.has_all(["incident_id", "participants", "outcome", "views",
			"keeper_reactions", "bond", "effects", "next_behaviors", "cause_summary", "cause_eased", "recurrence_possible"])
		and ui.get_node("%IncidentResultOverlay").visible and resolved_snapshot.actions.has("overlay.continue"))
	var result_overlay: Control = ui.get_node("%IncidentResultOverlay")
	var portrait_a: TextureRect = result_overlay.get_node("%PortraitA")
	var portrait_b: TextureRect = result_overlay.get_node("%PortraitB")
	Suite._check(results, "gate3_ui/incident_result_leads_with_portrait_pair_relationship_axis_and_outcome_emblem",
		portrait_a.visible and portrait_b.visible and portrait_a.texture != null and portrait_b.texture != null
		and portrait_a.texture.resource_path != portrait_b.texture.resource_path
		and not str(result_overlay.get_node("%NameA").text).is_empty() and not str(result_overlay.get_node("%NameB").text).is_empty()
		and not str(result_overlay.get_node("%AxisOutcome").text).is_empty()
		and not str(result_overlay.get_node("%Outcome").text).is_empty()
		and (str(result_overlay.get_node("%CauseState").text).begins_with("✓") or str(result_overlay.get_node("%CauseState").text).begins_with("○")))
	for overlay_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = overlay_size
		await process_frame
		await process_frame
		var overlay_card: Rect2 = result_overlay.get_node("%Card").get_global_rect()
		var overlay_fit: bool = Rect2(Vector2.ZERO, ui.size).encloses(overlay_card)
		var overlay_target_failures: Array[String] = []
		_collect_actionable_target_failures(result_overlay, overlay_target_failures)
		results.append({"name": "gate3_ui/incident_result_fits_%dx%d" % [overlay_size.x, overlay_size.y],
			"ok": overlay_fit and overlay_target_failures.is_empty() and Capture._minimum_visible_font_size(result_overlay) >= 16,
			"details": {"card": overlay_card, "viewport": ui.size, "target_failures": overlay_target_failures}})
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	controller.advance_elapsed(1.5)
	var continued_behind_overlay: Dictionary = controller.get_snapshot()
	Suite._check(results, "controller/result_overlay_does_not_pause_or_extend_incident_release",
		int(_state(controller).elapsed_ms) > int(resolved_state.elapsed_ms)
		and Gate2Suite._incident(continued_behind_overlay.data, warning_id).is_empty()
		and str(continued_behind_overlay.data.joined_incident_id).is_empty()
		and continued_behind_overlay.data.incident_result_overlay == pending_overlay)
	_command(controller, "incident.result.dismiss", {"incident_id": "stale"})
	Suite._check(results, "controller/stale_result_dismissal_does_nothing", controller.get_snapshot().data.incident_result_overlay == pending_overlay)
	var state_before_dismiss: Dictionary = _state(controller)
	_command(controller, "view.back")
	var dismissed_snapshot: Dictionary = controller.get_snapshot()
	var dismiss_ok: bool = dismissed_snapshot.data.incident_result_overlay.is_empty() and _state(controller) == state_before_dismiss \
		and not pending_overlay.is_empty() \
		and dismissed_snapshot.data.selection == {"kind": "place", "id": str(pending_overlay.get("place_id", ""))}
	results.append({"name": "ui/back_dismisses_result_without_sim_mutation_and_returns_to_place", "ok": dismiss_ok,
		"details": {"overlay": dismissed_snapshot.data.incident_result_overlay, "selection": dismissed_snapshot.data.selection,
			"expected_place": pending_overlay.get("place_id", ""), "sim_unchanged": _state(controller) == state_before_dismiss}})

	controller_sim.set("_state", open_state.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "incident.join", {"incident_id": warning_id})
	ui.get_node("%Choice2").pressed.emit()
	var deferred: Dictionary = Gate2Suite._incident(controller.get_snapshot().data, warning_id)
	Suite._check(results, "ui/defer_is_explicit_joined_choice_and_keeps_issue", deferred.status == "open" and not deferred.can_join and str(controller.get_snapshot().data.joined_incident_id).is_empty() and controller.get_snapshot().data.panel.context_key == "%s|open" % warning_id)

	var practice = Gate2Suite._social_pair(["kojo", "esi"], "training", {
		"kojo": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
		"esi": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}})
	var practice_result: Dictionary = Gate2Suite._await_social(practice, "shared_practice")
	controller_sim.set("_state", practice_result.after.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "subject.select", {"kind": "echo", "id": "kojo"})
	world._process(0.25)
	var echo_snapshot: Dictionary = controller.get_snapshot()
	var echo_visual: Dictionary = echo_snapshot.data.panel.visual
	var echo_ui: Dictionary = ui.presentation_metrics()
	Suite._check(results, "ui/echo_current_uses_qualitative_needs_relationship_map_and_player_purpose_label", echo_visual.get("type", "") == "echo" and echo_visual.get("needs", {}).keys() == ["rest", "company", "purpose"] and echo_visual.needs.values().all(func(need: Dictionary) -> bool: return need.has_all(["name", "level", "state"]) and not str(need.state).is_empty()) and echo_visual.needs.purpose.name == "Something to do" and not echo_visual.get("relationships", []).is_empty() and echo_visual.relationships.all(func(relationship: Dictionary) -> bool: return relationship.has_all(["name", "tier", "tier_name", "bond_type", "impression"])) and echo_ui.normal_surface == "echo" and echo_ui.components.needs and echo_ui.components.relationships)
	Suite._check(results, "ui/echo_normal_surface_has_no_raw_need_bond_encounter_or_score_values", not _visual_has_forbidden_raw_keys(echo_visual) and not _normal_surface_has_raw_values(ui))
	_command(controller, "subject.select", {"kind": "place", "id": "flame"})
	world._process(0.25)
	ui.get_node("%Recent").pressed.emit()
	var flame_snapshot: Dictionary = controller.get_snapshot()
	var social_rows: Array = flame_snapshot.data.panel.history_entries.filter(func(entry: Dictionary) -> bool: return entry.kind == "social_exchange")
	var history_visual: Dictionary = flame_snapshot.data.panel.visual
	var history_checks := {
		"matches_village_slice": flame_snapshot.data.panel.history_entries == flame_snapshot.data.village_history.slice(0, 12),
		"social_row_count": social_rows.size(),
		"social_row_folded": social_rows.size() == 1 and int(social_rows[0].get("source_count", 0)) > 1,
		"visual_type": history_visual.get("type", ""),
		"card_count": history_visual.get("cards", []).size(),
		"entry_count": flame_snapshot.data.panel.history_entries.size(),
		"has_relationship_consequence": history_visual.get("cards", []).any(func(card: Dictionary) -> bool: return card.get("consequences", []).any(func(text: String) -> bool: return text.begins_with("Relationship:"))),
		"leaks_source_ids": JSON.stringify(history_visual).contains("source_ids"),
		"component_visible": ui.presentation_metrics().components.history,
		"cards_have_glance_structure": history_visual.get("cards", []).all(func(card: Dictionary) -> bool: return _history_card_has_glance_structure(card)),
	}
	var history_ok: bool = bool(history_checks.matches_village_slice) and int(history_checks.social_row_count) == 1 and bool(history_checks.social_row_folded) and history_checks.visual_type == "history" and int(history_checks.card_count) == int(history_checks.entry_count) and bool(history_checks.has_relationship_consequence) and not bool(history_checks.leaks_source_ids) and bool(history_checks.component_visible) and bool(history_checks.cards_have_glance_structure)
	results.append({"name": "ui/flame_recent_uses_village_history_with_one_folded_visual_card", "ok": history_ok, "details": history_checks})
	Suite._check(results, "ui/history_cards_use_qualitative_consequences_without_raw_values", not _visual_has_forbidden_raw_keys(history_visual) and not _normal_surface_has_raw_values(ui))
	var engagement: Dictionary = flame_snapshot.data.social_engagements[0] if flame_snapshot.data.social_engagements.size() == 1 else {}
	Suite._check(results, "world/social_cue_uses_authoritative_engagement_projection", not engagement.is_empty() and world._engagement(engagement.id) == engagement and engagement.participants.all(func(id: String) -> bool: return Suite._echo(flame_snapshot.data, id).engagement_id == engagement.id))
	await _incident_access_ui_checks(results, controller, ui, world)
	_blocking_camera_contract_checks(results, controller, world)
	_sections["gate2"] = true


func _incident_access_ui_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	_reset_live(controller)
	var warning_ctas_absent := true
	var open_ctas_exact := true
	var selected_order_exact := true
	var incident_context: Control = ui.get_node("%IncidentContext")
	var ordered_nodes: Array[Node] = [incident_context.get_node("NowHeading"), incident_context.get_node("UrgencyRow"),
		incident_context.get_node("CauseHeading"), incident_context.get_node("ActionHeading")]
	for index: int in range(1, ordered_nodes.size()):
		selected_order_exact = selected_order_exact and ordered_nodes[index - 1].get_index() < ordered_nodes[index].get_index()
	for access: String in ["private", "open", "appeal"]:
		var fixture: Dictionary = Gate3Suite._incident_access_fixture(access)
		var source = fixture.get("sim")
		var incident: Dictionary = fixture.get("incident", {})
		if source == null or incident.is_empty():
			warning_ctas_absent = false
			open_ctas_exact = false
			continue
		Gate2Suite._act(source, "tuning.set", {"key": "social_frequency", "value": 0})
		_set_controller_sim_state(controller, _settled_incident_state(source.get_state()))
		var subject := {"kind": "incident", "id": str(incident.id)}
		_command(controller, "subject.select", subject)
		world._process(0.01)
		world.queue_redraw()
		await process_frame
		var warning: Dictionary = controller.get_snapshot()
		var warning_projection: Dictionary = Gate2Suite._incident(warning.data, str(incident.id))
		var warning_visual: Dictionary = warning.data.panel.get("visual", {})
		var warning_choices: Array = warning.data.panel.get("choices", [])
		var warning_has_choice_slot: bool = warning.actions.keys().any(func(slot: String) -> bool: return slot.begins_with("cta.choice_"))
		var warning_exchange_text: String = str(incident_context.get_node("Now").text)
		var warning_exchange_visible: bool = warning_visual.get("exchange_lines", []).size() == 2
		for line: Dictionary in warning_visual.get("exchange_lines", []):
			warning_exchange_visible = warning_exchange_visible and warning_exchange_text.contains(str(line.get("speaker", ""))) \
				and warning_exchange_text.contains(str(line.get("text", "")))
		warning_ctas_absent = warning_ctas_absent and warning_projection.get("status", "") == "warning" \
			and not bool(warning_projection.get("can_join", true)) and warning_choices.is_empty() \
			and not warning_has_choice_slot and warning_exchange_visible \
			and str(world.capture_metrics(subject).get("incident_signature", "")) == "warning:compact_notification"

		Gate2Suite._advance_to(source, int(incident.stage_deadline_ms))
		_set_controller_sim_state(controller, _settled_incident_state(source.get_state()))
		_command(controller, "subject.select", subject)
		world._process(0.01)
		world.queue_redraw()
		await process_frame
		var opened: Dictionary = controller.get_snapshot()
		var projected: Dictionary = Gate2Suite._incident(opened.data, str(incident.id))
		var choices: Array = opened.data.panel.get("choices", [])
		var appeal_name: String = str(opened.data.panel.get("visual", {}).get("appeal_name", ""))
		var expected_label := "" if access == "private" else "Step in" if access == "open" else "Answer %s" % appeal_name
		var expected_status := "They are handling this" if access == "private" else "You can step in" if access == "open" else "%s is asking for help" % appeal_name
		var access_cta_ok: bool = choices.size() == (0 if access == "private" else 1) \
			and (choices.is_empty() or (choices[0].get("label", "") == expected_label and not bool(choices[0].get("disabled", true)))) \
			and bool(projected.get("can_join", false)) == (access != "private") \
			and opened.data.panel.visual.get("status_text", "") == expected_status \
			and (ui.get_node("%Back").has_focus() if access == "private" else ui.get_node("%Choice0").has_focus())
		open_ctas_exact = open_ctas_exact and access_cta_ok
		var world_metrics: Dictionary = world.capture_metrics(subject)
		var expected_signature := "open:private_compact" if access == "private" else "open:standard+tether+connectors" if access == "open" else "open:appeal+standard+tether+connectors"
		results.append({"name": "incident_access_ui/world_%s_open_has_distinct_visual_weight" % access,
			"ok": str(world_metrics.get("incident_signature", "")) == expected_signature,
			"details": {"expected": expected_signature, "actual": world_metrics.get("incident_signature", "")}})
		root.size = Vector2i(960, 540)
		await process_frame
		await process_frame
		world._process(0.01)
		var panel_rect: Rect2 = ui.get_node("%ContextPanel").get_global_rect()
		var target_failures: Array[String] = []
		_collect_actionable_target_failures(ui, target_failures)
		results.append({"name": "incident_access_ui/%s_open_panel_fits_960x540" % access,
			"ok": Rect2(Vector2.ZERO, ui.size).encloses(panel_rect) and target_failures.is_empty() \
				and Capture._minimum_visible_font_size(ui.get_node("%ContextPanel")) >= 16,
			"details": {"panel": panel_rect, "viewport": ui.size, "target_failures": target_failures}})
		root.size = Vector2i(1920, 1080)
		await process_frame
		await process_frame
	Suite._check(results, "incident_access_ui/warning_never_exposes_intervention_cta_and_premise_is_readable", warning_ctas_absent)
	Suite._check(results, "incident_access_ui/private_open_appeal_cta_wording_gating_and_focus_are_exact", open_ctas_exact)
	Suite._check(results, "incident_access_ui/selected_incident_orders_exchange_status_why_then_action", selected_order_exact)
	var private_color: Color = world._incident_color("open", "private")
	var open_color: Color = world._incident_color("open", "open")
	var appeal_color: Color = world._incident_color("open", "appeal")
	Suite._check(results, "incident_access_ui/private_open_and_appeal_use_three_distinct_world_tones",
		private_color != open_color and private_color != appeal_color and open_color != appeal_color)

	var appeal_fixture: Dictionary = Gate3Suite._incident_access_fixture("appeal")
	var appeal_sim = appeal_fixture.get("sim")
	var appeal_incident: Dictionary = appeal_fixture.get("incident", {})
	if appeal_sim == null or appeal_incident.is_empty():
		Suite._check(results, "incident_access_ui/reduced_motion_preserves_speaker_order_access_and_action", false)
		Suite._check(results, "incident_access_ui/autonomous_resolution_never_opens_keeper_result_overlay", false)
		return
	Gate2Suite._act(appeal_sim, "tuning.set", {"key": "social_frequency", "value": 0})
	Gate2Suite._advance_to(appeal_sim, int(appeal_incident.stage_deadline_ms))
	_set_controller_sim_state(controller, _settled_incident_state(appeal_sim.get_state()))
	var appeal_subject := {"kind": "incident", "id": str(appeal_incident.id)}
	_command(controller, "subject.select", appeal_subject)
	var before_motion: Dictionary = controller.get_snapshot()
	var before_motion_incident: Dictionary = Gate2Suite._incident(before_motion.data, str(appeal_incident.id))
	var before_motion_choices: Array = before_motion.data.panel.choices.duplicate(true)
	_command(controller, "view.motion", {"reduced": true})
	var reduced: Dictionary = controller.get_snapshot()
	_command(controller, "view.motion", {"reduced": false})
	var restored: Dictionary = controller.get_snapshot()
	Suite._check(results, "incident_access_ui/reduced_motion_preserves_speaker_order_access_and_action",
		Gate2Suite._incident(reduced.data, str(appeal_incident.id)) == before_motion_incident \
		and Gate2Suite._incident(restored.data, str(appeal_incident.id)) == before_motion_incident \
		and reduced.data.panel.choices == before_motion_choices and restored.data.panel.choices == before_motion_choices)

	Gate2Suite._advance_to(appeal_sim, int(appeal_incident.incident_deadline_ms) - 250)
	_set_controller_sim_state(controller, _settled_incident_state(appeal_sim.get_state()))
	_command(controller, "subject.select", appeal_subject)
	_command(controller, "playback.next")
	var autonomous: Dictionary = controller.get_snapshot()
	var autonomous_incident: Dictionary = Gate2Suite._incident(autonomous.data, str(appeal_incident.id))
	Suite._check(results, "incident_access_ui/autonomous_resolution_never_opens_keeper_result_overlay",
		autonomous_incident.get("status", "") == "resolved" and autonomous_incident.get("result", {}).get("keeper_reactions", []).is_empty() \
		and autonomous.data.incident_result_overlay.is_empty() and not ui.get_node("%IncidentResultOverlay").visible \
		and not autonomous.actions.has("overlay.continue"))


func _set_controller_sim_state(controller: Node, state: Dictionary) -> void:
	controller.get("_simulation").set("_state", state.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "playback.speed", {"speed": "paused"})


func _gate3_controller_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	_reset_live(controller)
	_command(controller, "tuning.set", {"key": "social_frequency", "value": 0})
	_command(controller, "view.motion", {"reduced": true})
	_command(controller, "subject.select", {"kind": "place", "id": "flame"})
	world._process(0.01)
	var sim = controller.get("_simulation")
	var arrival_reveal: Control = ui.get_node("%ArrivalReveal")
	var arrival_portrait: TextureRect = arrival_reveal.get_node("%Portrait")
	var ready: Dictionary = controller.get_snapshot()
	var initial_order: Array = ready.data.summoning.newcomer_order.duplicate()
	var portrait_paths: Dictionary = {}
	var all_portraits_exist := true
	var all_ids: Array[String] = []
	for echo: Dictionary in ready.data.echoes:
		all_ids.append(str(echo.id))
	for newcomer: Dictionary in sim.get_definition().summoning.newcomers:
		all_ids.append(str(newcomer.id))
	for echo_id: String in all_ids:
		var portrait_path: String = str(controller._portrait_path(echo_id))
		all_portraits_exist = all_portraits_exist and not portrait_path.is_empty() and FileAccess.file_exists(portrait_path)
		portrait_paths[portrait_path] = true
	Suite._check(results, "gate3_ui/flame_ready_exposes_charge_cost_confirm_and_nine_distinct_portraits",
		ready.data.summoning.ase == 60 and ready.data.summoning.cost == 60 and ready.data.summoning.flame_state == "ready"
		and ready.data.panel.choices.size() == 1 and ready.data.panel.choices[0].type == "prototype.summon.confirm"
		and ready.data.panel.body.contains("60 Ase") and not arrival_reveal.visible
		and all_ids.size() == 9 and portrait_paths.size() == 9 and all_portraits_exist)

	ui.get_node("%Choice0").pressed.emit()
	var confirming: Dictionary = controller.get_snapshot()
	var confirm_background_before: Dictionary = Suite._echo(_state(controller), "kojo").pressures.duplicate(true)
	controller.advance_elapsed(0.25)
	var confirming_after_time: Dictionary = controller.get_snapshot()
	Suite._check(results, "gate3_ui/confirmation_is_compact_cancelable_and_background_life_continues",
		confirming.data.summoning.arrival.stage == "confirming" and confirming.data.summoning.ase == 60
		and confirming.data.panel.choices.size() == 2
		and confirming.data.panel.choices[0].type == "prototype.summon.commit"
		and confirming.data.panel.choices[1].type == "prototype.summon.cancel"
		and confirming.data.panel.body.contains("Nothing is spent") and not arrival_portrait.visible
		and confirming_after_time.meta.t == confirming.meta.t + 1
		and confirming_after_time.data.summoning.arrival.stage == "confirming"
		and Suite._echo(_state(controller), "kojo").pressures != confirm_background_before)
	ui.get_node("%Choice1").pressed.emit()
	var canceled: Dictionary = controller.get_snapshot()
	var canceled_state: Dictionary = _state(controller)
	_command(controller, "summon.cancel")
	Suite._check(results, "gate3_ui/cancel_spends_nothing_and_stale_cancel_is_inert",
		canceled.data.summoning.ase == 60 and canceled.data.summoning.arrival.is_empty()
		and canceled.data.summoning.consumed_ids.is_empty() and canceled.data.echoes.size() == 6
		and _state(controller) == canceled_state)

	ui.get_node("%Choice0").pressed.emit()
	ui.get_node("%Choice0").pressed.emit()
	var committed: Dictionary = controller.get_snapshot()
	var committed_state: Dictionary = _state(controller)
	_command(controller, "summon.commit")
	Suite._check(results, "gate3_ui/commit_atomically_spends_once_and_stages_manifestation",
		committed.data.summoning.ase == 0 and committed.data.summoning.consumed_ids.size() == 1
		and committed.data.summoning.arrival.stage == "approach" and committed.data.summoning.flame_state == "committing"
		and committed.data.echoes.size() == 6 and arrival_reveal.visible and not arrival_portrait.visible
		and _state(controller) == committed_state)
	var interactions_blocked: bool = not sim.apply_action({"type": "prototype.summon.confirm", "payload": {}}, sim.get_step()) \
		and not sim.apply_action({"type": "prototype.conversation.begin", "payload": {"echo_id": "kojo"}}, sim.get_step())
	var conflict_fixture: Dictionary = Gate2Suite._warning_fixture(15.0, 45.0)
	Gate2Suite._advance_to(conflict_fixture.sim, int(conflict_fixture.incident.stage_deadline_ms))
	var conflict_source: Dictionary = conflict_fixture.sim.get_state()
	var conflict_probe: Dictionary = committed_state.duplicate(true)
	conflict_probe.incidents = conflict_source.incidents.duplicate(true)
	for participant_id: String in conflict_probe.incidents[0].participants:
		var target_echo: Dictionary = Suite._echo(conflict_probe, participant_id)
		var source_echo: Dictionary = Suite._echo(conflict_source, participant_id)
		for key: String in ["reserved", "incident_id", "behavior"]:
			target_echo[key] = source_echo[key].duplicate(true) if source_echo[key] is Dictionary else source_echo[key]
	sim.set("_state", conflict_probe)
	var incident_join_blocked: bool = not sim.apply_action({"type": "prototype.incident.join", "payload": {"incident_id": conflict_probe.incidents[0].id}}, sim.get_step())
	conflict_probe.arrival = {}
	sim.set("_state", conflict_probe)
	var incident_join_would_otherwise_work: bool = sim.apply_action({"type": "prototype.incident.join", "payload": {"incident_id": conflict_probe.incidents[0].id}}, sim.get_step())
	sim.set("_state", committed_state.duplicate(true))
	_command(controller, "view.current")
	Suite._check(results, "gate3_ui/arrival_blocks_conflicting_summon_conversation_and_joinable_incident", interactions_blocked and incident_join_blocked and incident_join_would_otherwise_work)

	controller.advance_elapsed(1.0)
	var gather: Dictionary = controller.get_snapshot()
	var gather_hidden: bool = gather.data.summoning.arrival.stage == "gather" and not arrival_portrait.visible
	controller.advance_elapsed(1.0)
	var perform: Dictionary = controller.get_snapshot()
	var perform_hidden: bool = perform.data.summoning.arrival.stage == "perform" and not arrival_portrait.visible
	controller.advance_elapsed(1.0)
	var welcome: Dictionary = controller.get_snapshot()
	var newcomer_id: String = str(welcome.data.summoning.arrival.newcomer_id)
	var newcomer: Dictionary = Suite._echo(welcome.data, newcomer_id)
	var newcomer_subject := {"kind": "echo", "id": newcomer_id}
	var portrait_path: String = str(welcome.data.arrival_presentation.portrait_path)
	Suite._check(results, "gate3_ui/portrait_stays_hidden_until_emergence_then_matches_manifested_newcomer",
		gather_hidden and perform_hidden and welcome.data.summoning.arrival.stage == "welcome"
		and welcome.data.echoes.size() == 7 and not newcomer.is_empty() and newcomer.reserved
		and arrival_portrait.visible and arrival_portrait.texture != null and arrival_portrait.texture.resource_path == portrait_path
		and portrait_path.ends_with("/%s.png" % newcomer_id) and world._subjects().has(newcomer_subject)
		and world._hits(world._echo_screen(newcomer)).has(newcomer_subject)
		and newcomer.get("bonds", []).is_empty() and newcomer.get("impressions", []).is_empty())
	var welcome_choices: Array = welcome.data.summoning.arrival.welcome_choices
	Suite._check(results, "gate3_ui/welcome_is_required_untimed_and_choices_are_qualitative",
		welcome_choices.size() == 2 and welcome.data.panel.choices.size() == 2
		and welcome.data.panel.choices.all(_panel_welcome_choice_is_qualitative)
		and welcome_choices.all(_welcome_choice_is_qualitative)
		and arrival_reveal.get_node("%WelcomeCues").visible and not str(arrival_reveal.get_node("%WelcomeCues").text).is_empty())
	var welcome_step: int = int(welcome.meta.t)
	var welcome_background_before: Dictionary = Suite._echo(_state(controller), "kojo").pressures.duplicate(true)
	controller.advance_elapsed(1.0)
	var welcome_waited: Dictionary = controller.get_snapshot()
	Suite._check(results, "gate3_ui/background_simulation_continues_while_required_welcome_waits",
		welcome_waited.meta.t == welcome_step + 4 and welcome_waited.data.summoning.arrival.stage == "welcome"
		and Suite._echo(_state(controller), "kojo").pressures != welcome_background_before
		and Suite._echo(welcome_waited.data, newcomer_id).reserved)

	for profile_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = profile_size
		await process_frame
		await process_frame
		world._process(0.01)
		var reveal_rect: Rect2 = arrival_reveal.get_global_rect()
		var flame_centre: Vector2 = world._screen(world._subject_position({"kind": "place", "id": "flame"}))
		var profile_failures: Array[String] = []
		_collect_actionable_target_failures(ui, profile_failures)
		results.append({"name": "gate3_ui/welcome_fits_and_preserves_circle_%dx%d" % [profile_size.x, profile_size.y],
			"ok": Rect2(Vector2.ZERO, ui.size).encloses(reveal_rect) and not reveal_rect.has_point(flame_centre)
				and profile_failures.is_empty() and Capture._minimum_visible_font_size(ui) >= 16,
			"details": {"reveal": reveal_rect, "flame_centre": flame_centre, "viewport": ui.size, "target_failures": profile_failures}})
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame

	var welcome_id: String = str(welcome_choices[0].id)
	_command(controller, "summon.welcome", {"welcome_id": welcome_id})
	var traveling: Dictionary = controller.get_snapshot()
	var after_welcome_state: Dictionary = _state(controller)
	_command(controller, "summon.welcome", {"welcome_id": welcome_id})
	Suite._check(results, "gate3_ui/welcome_commits_once_and_exposes_reaction_destination_and_route",
		traveling.data.summoning.arrival.stage in ["travel", "complete"]
		and traveling.data.summoning.arrival.welcome.id == welcome_id
		and not str(traveling.data.arrival_presentation.welcome.get("result", "")).is_empty()
		and not str(traveling.data.arrival_presentation.destination).is_empty()
		and not traveling.data.arrival_presentation.route.is_empty()
		and arrival_reveal.get_node("%Reaction").visible and arrival_reveal.get_node("%Destination").visible
		and _state(controller) == after_welcome_state)
	var completed_ok: bool = _advance_controller_until_arrival_stage(controller, "complete", 240)
	var completed: Dictionary = controller.get_snapshot()
	var arrival_cards: Array = completed.data.village_history.filter(func(item: Dictionary) -> bool: return item.get("kind", "") == "newcomer_arrival")
	var arrival_memory: Dictionary = arrival_cards[0].get("arrival_memory", {}) if arrival_cards.size() == 1 else {}
	Suite._check(results, "gate3_ui/completion_routes_newcomer_and_folds_one_structured_arrival_memory",
		completed_ok and completed.data.echoes.size() == 7 and completed.data.summoning.arrival.stage == "complete"
		and completed.data.arrival_presentation.complete and not str(completed.data.arrival_presentation.destination).is_empty()
		and completed.data.panel.choices.size() == 1 and completed.data.panel.choices[0].type == "prototype.summon.dismiss"
		and arrival_cards.size() == 1 and arrival_memory.has_all(["newcomer_id", "witnesses", "welcome", "first_intention", "arrival_node"])
		and arrival_memory.newcomer_id == newcomer_id and not str(arrival_memory.first_intention.get("place", "")).is_empty())
	var complete_state: Dictionary = _state(controller)
	_command(controller, "summon.welcome", {"welcome_id": welcome_id})
	var stale_welcome_inert: bool = _state(controller) == complete_state
	ui.get_node("%Choice0").pressed.emit()
	var dismissed: Dictionary = controller.get_snapshot()
	var dismissed_state: Dictionary = _state(controller)
	_command(controller, "summon.dismiss")
	Suite._check(results, "gate3_ui/completion_dismisses_once_and_stale_welcome_or_dismiss_are_inert",
		stale_welcome_inert and dismissed.data.summoning.arrival.is_empty() and dismissed.data.echoes.size() == 7
		and not arrival_reveal.visible and _state(controller) == dismissed_state)

	for arrival_index: int in range(2):
		var funded: Dictionary = _state(controller).duplicate(true)
		funded.ase = 120
		sim.set("_state", funded)
		_command(controller, "view.current")
		_command(controller, "summon.confirm")
		_command(controller, "summon.commit")
		_advance_controller_until_arrival_stage(controller, "welcome", 20)
		var next_welcome: Dictionary = controller.get_snapshot().data.summoning.arrival
		_command(controller, "summon.welcome", {"welcome_id": next_welcome.welcome_choices[0].id})
		_advance_controller_until_arrival_stage(controller, "complete", 240)
		_command(controller, "summon.dismiss")
	_command(controller, "subject.select", {})
	world._process(0.01)
	var nine: Dictionary = controller.get_snapshot()
	Suite._check(results, "gate3_ui/three_authored_arrivals_reach_real_nine_echo_population", nine.data.echoes.size() == 9 and nine.data.summoning.remaining == 0 and nine.data.summoning.arrival.is_empty())
	for crowd_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = crowd_size
		await process_frame
		await process_frame
		world._process(0.01)
		var crowd_ok := true
		var usable: Rect2 = _usable_world_rect(world).grow(-40.0)
		for echo: Dictionary in controller.get_snapshot().data.echoes:
			var centre: Vector2 = world._echo_screen(echo)
			crowd_ok = crowd_ok and usable.has_point(centre) and world._hits(centre).has({"kind": "echo", "id": echo.id})
		results.append({"name": "gate3_ui/nine_echo_crowd_visible_selectable_%dx%d" % [crowd_size.x, crowd_size.y], "ok": crowd_ok})
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	_command(controller, "session.reset")
	var reset: Dictionary = controller.get_snapshot()
	var reset_state: Dictionary = _state(controller)
	_command(controller, "summon.welcome", {"welcome_id": welcome_id})
	_command(controller, "summon.dismiss")
	Suite._check(results, "gate3_ui/reset_restores_six_ase_order_and_clears_pending_or_stale_arrival",
		reset.data.echoes.size() == 6 and reset.data.summoning.ase == 60 and reset.data.summoning.newcomer_order == initial_order
		and reset.data.summoning.consumed_ids.is_empty() and reset.data.summoning.arrival.is_empty()
		and not arrival_reveal.visible and _state(controller) == reset_state)
	_sections["gate3"] = true


func _panel_welcome_choice_is_qualitative(choice: Dictionary) -> bool:
	var label: String = str(choice.get("label", ""))
	return choice.get("type", "") == "prototype.summon.welcome" and label.contains("\n") and not label.contains("+") and not label.contains("%")


func _welcome_choice_is_qualitative(choice: Dictionary) -> bool:
	return choice.has_all(["id", "label", "cue", "direction", "result"]) \
		and not str(choice.cue.get("text", "")).is_empty() and not str(choice.direction).is_empty()


func _advance_controller_until_arrival_stage(controller: Node, target_stage: String, max_steps: int) -> bool:
	for index: int in range(max_steps):
		if str(controller.get_snapshot().data.summoning.arrival.get("stage", "")) == target_stage:
			return true
		controller.advance_elapsed(0.25)
	return str(controller.get_snapshot().data.summoning.arrival.get("stage", "")) == target_stage


func _reaction_voice_ui_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	var practice = Gate2Suite._social_pair(["kojo", "esi"], "training", {
		"kojo": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
		"esi": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}})
	var enacted: Dictionary = Gate2Suite._await_social(practice, "shared_practice")
	var controller_sim = controller.get("_simulation")
	controller_sim.set("_state", enacted.after.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "playback.speed", {"speed": "paused"})
	_command(controller, "view.motion", {"reduced": false})
	_command(controller, "subject.select", {})
	world._process(0.01)
	world.queue_redraw()
	await process_frame
	await process_frame
	var active: Dictionary = controller.get_snapshot()
	var paused_state: Dictionary = _state(controller)
	var paused_cues: Array = active.data.get("reaction_cues", []).duplicate(true)
	controller.advance_elapsed(20.0)
	Suite._check(results, "reaction_voice_ui/pause_preserves_reaction_state_and_authored_deadline",
		_state(controller) == paused_state and controller.get_snapshot().data.get("reaction_cues", []) == paused_cues
		and paused_cues.size() == 2 and paused_cues.all(func(cue: Dictionary) -> bool: return int(cue.started_ms) + int(cue.duration_ms) > int(active.data.elapsed_ms)))
	var live_metrics: Dictionary = world.capture_metrics()
	var exact_world_reactions: bool = paused_cues.all(func(cue: Dictionary) -> bool:
		return world._reaction_for(Suite._echo(active.data, str(cue.echo_id))) == cue)
	results.append({"name": "reaction_voice_ui/world_reads_exact_authored_reactions_without_inference",
		"ok": int(live_metrics.get("reaction_cue_count", 0)) > 0 and exact_world_reactions,
		"details": {"authored": paused_cues, "drawn": live_metrics.get("reaction_cue_count", 0), "exact_bindings": exact_world_reactions}})

	var player_text: Array[String] = []
	_command(controller, "subject.select", {"kind": "echo", "id": "kojo"})
	_command(controller, "view.current")
	var kojo_current: String = str(controller.get_snapshot().data.panel.body)
	_collect_visible_text(ui.get_node("%ContextPanel"), player_text)
	ui.get_node("%Recent").pressed.emit()
	var kojo_recent: Dictionary = controller.get_snapshot()
	var kojo_memory: String = _first_history_card_text(kojo_recent)
	_collect_visible_text(ui.get_node("%ContextPanel"), player_text)
	_command(controller, "subject.select", {"kind": "echo", "id": "esi"})
	_command(controller, "view.current")
	var esi_current: String = str(controller.get_snapshot().data.panel.body)
	_collect_visible_text(ui.get_node("%ContextPanel"), player_text)
	ui.get_node("%Recent").pressed.emit()
	var esi_recent: Dictionary = controller.get_snapshot()
	var esi_memory: String = _first_history_card_text(esi_recent)
	_collect_visible_text(ui.get_node("%ContextPanel"), player_text)
	Suite._check(results, "reaction_voice_ui/participants_have_distinct_first_person_current_and_recent_surfaces",
		kojo_current.contains("I ") and esi_current.contains("I ") and kojo_current != esi_current
		and kojo_memory.begins_with("I ") and esi_memory.begins_with("I ") and kojo_memory != esi_memory)
	var recent_cards: VBoxContainer = ui.get_node("%HistoryCards")
	var long_memory := "I remember making room for the practice, then watching the others settle into a clearer rhythm without leaving anyone behind."
	for index: int in mini(3, recent_cards.get_child_count()):
		recent_cards.get_child(index).set_model({"type_label": "RECENT", "glyph": "•", "title": "I REMEMBER", "text": long_memory})
	var recent_layout_ok := true
	for profile_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = profile_size
		await process_frame
		await process_frame
		for index: int in mini(3, recent_cards.get_child_count()):
			var card: Control = recent_cards.get_child(index)
			var memory_label: Label = card.get_node("%MomentText")
			recent_layout_ok = recent_layout_ok and (memory_label.visible
				and memory_label.size.y >= memory_label.get_combined_minimum_size().y
				and not (card.get_node("%MomentBadge") as Label).visible
				and not (card.get_node("%MomentMeta") as Label).visible)
	Suite._check(results, "ui/recent_cards_wrap_authored_memory_without_empty_header_spacing_across_profiles", recent_layout_ok)

	var witness_sim = Gate2Suite._practice_warning_witness_fixture()
	var witness_result: Dictionary = Gate2Suite._await_social(witness_sim, "competitive_practice")
	var witness_state: Dictionary = witness_result.after.duplicate(true)
	var warning: Dictionary = witness_state.incidents[0] if witness_state.incidents.size() == 1 else {}
	while witness_state.echoes.size() < 9:
		var extra: Dictionary = witness_state.echoes[witness_state.echoes.size() % 6].duplicate(true)
		extra.id = "reaction_layout_%d" % witness_state.echoes.size()
		extra.name = "Reaction layout guest %d" % (witness_state.echoes.size() + 1)
		extra.reserved = false
		extra.engagement_id = ""
		extra.incident_id = ""
		extra.behavior = {}
		witness_state.echoes.append(extra)
	controller_sim.set("_state", witness_state)
	controller.set("_elapsed", 0.0)
	_command(controller, "view.motion", {"reduced": false})
	_command(controller, "playback.speed", {"speed": "paused"})
	_command(controller, "subject.select", {"kind": "incident", "id": warning.get("id", "")})
	_collect_visible_text(ui.get_node("%ContextPanel"), player_text)
	_command(controller, "subject.select", {})
	var normal_state: Dictionary = _state(controller)
	var normal_cues: Array = controller.get_snapshot().data.get("reaction_cues", [])
	var normal_has_displacement: bool = normal_cues.any(func(cue: Dictionary) -> bool:
		return not world._reaction_pose_offset(cue, Vector2.RIGHT).is_zero_approx())
	_command(controller, "view.motion", {"reduced": true})
	var reduced_state_unchanged: bool = _state(controller) == normal_state
	var reduced_has_no_displacement: bool = normal_cues.all(func(cue: Dictionary) -> bool:
		return world._reaction_pose_offset(cue, Vector2.RIGHT).is_zero_approx())
	Suite._check(results, "reaction_voice_ui/reduced_motion_preserves_cues_but_removes_world_displacement",
		normal_has_displacement and reduced_has_no_displacement and reduced_state_unchanged)

	for profile_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = profile_size
		await process_frame
		await process_frame
		world._process(0.01)
		world.queue_redraw()
		await process_frame
		await process_frame
		var metrics: Dictionary = world.capture_metrics()
		var usable: Rect2 = metrics.get("usable_rect", Rect2())
		var bounds: Array = metrics.get("reaction_cue_bounds", [])
		var drawn_cue_count: int = int(metrics.get("reaction_cue_count", 0))
		var cues_inside: bool = drawn_cue_count > 0 and drawn_cue_count <= normal_cues.size() and bounds.size() == drawn_cue_count
		for cue_bounds: Rect2 in bounds:
			cues_inside = cues_inside and usable.encloses(cue_bounds)
			for echo: Dictionary in controller.get_snapshot().data.echoes:
				var echo_radius: float = 34.0 * float(world.get("_zoom"))
				var echo_bounds := Rect2(world._echo_screen(echo) - Vector2.ONE * echo_radius, Vector2.ONE * echo_radius * 2.0)
				cues_inside = cues_inside and not cue_bounds.intersects(echo_bounds)
		var all_selectable := true
		for echo: Dictionary in controller.get_snapshot().data.echoes:
			var centre: Vector2 = world._echo_screen(echo)
			all_selectable = all_selectable and usable.has_point(centre) \
				and world._hits(centre).has({"kind": "echo", "id": echo.id})
		results.append({"name": "reaction_voice_ui/cues_bounded_and_nine_echoes_selectable_%dx%d" % [profile_size.x, profile_size.y],
			"ok": cues_inside and all_selectable,
			"details": {"expected_cues": normal_cues.size(), "drawn_cues": metrics.get("reaction_cue_count", 0),
				"cue_bounds": bounds, "usable": usable, "all_selectable": all_selectable}})
	Suite._check(results, "reaction_voice_ui/player_surfaces_hide_internal_and_gdd_terms_outside_lab",
		not _player_text_has_internal_terms(player_text))
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	_reset_live(controller)
	_command(controller, "playback.speed", {"speed": "normal"})
	_sections["reaction_voice"] = true


func _first_history_card_text(snapshot: Dictionary) -> String:
	var cards: Array = snapshot.get("data", {}).get("panel", {}).get("visual", {}).get("cards", [])
	return str(cards[0].get("text", "")) if not cards.is_empty() else ""


func _player_text_has_internal_terms(lines: Array[String]) -> bool:
	var joined: String = "\n".join(lines).to_lower()
	for forbidden: String in ["template_id", "participant_effect", "reaction_cue", "source_event", "social exchange",
		"engagement_id", "incident_id", "bond delta", "pressure", "initiator", "receiver", "purpose need"]:
		if joined.contains(forbidden):
			return true
	return false


func _blocking_camera_contract_checks(results: Array[Dictionary], controller: Node, world: Control) -> void:
	var controller_sim = controller.get("_simulation")
	var fixture: Dictionary = Gate2Suite._warning_fixture(15.0, 45.0)
	var incident_id: String = fixture.incident.id
	var warning_state: Dictionary = _settled_incident_state(fixture.sim.get_state())
	controller_sim.set("_state", warning_state.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "view.motion", {"reduced": true})
	_command(controller, "subject.select", {})
	world._process(0.01)
	var baseline_data: Dictionary = controller.get_snapshot().data
	var baseline_frame: Dictionary = _camera_geometry_frame(world, baseline_data)

	var flame_subject := {"kind": "place", "id": "flame"}
	_camera_select_and_snap(controller, world, flame_subject)
	var flame_data: Dictionary = controller.get_snapshot().data
	var flame_frame: Dictionary = _camera_geometry_frame(world, flame_data)
	var flame_geometry_ok: bool = _camera_frames_preserve_authored_geometry(baseline_frame, flame_frame)
	var flame_context: Dictionary = _place_focus_context(world, flame_data, "flame")
	results.append({"name": "camera_blocking/place_focus_uses_uniform_transform_without_giant_marker_or_displacement",
		"ok": flame_geometry_ok, "details": {"baseline": baseline_frame, "focused": flame_frame}})
	results.append({"name": "camera_blocking/flame_focus_keeps_marker_and_all_occupants_visible_selectable",
		"ok": bool(flame_context.ok), "details": flame_context})

	var incident_subject := {"kind": "incident", "id": incident_id}
	_camera_select_and_snap(controller, world, incident_subject)
	var incident_data: Dictionary = controller.get_snapshot().data
	var incident_frame: Dictionary = _camera_geometry_frame(world, incident_data)
	var incident_geometry_ok: bool = _camera_frames_preserve_authored_geometry(baseline_frame, incident_frame)
	var incident_context: Dictionary = _incident_focus_context(world, incident_data, incident_id)
	results.append({"name": "camera_blocking/incident_focus_does_not_enlarge_or_displace_participants_or_cue",
		"ok": incident_geometry_ok, "details": {"baseline": baseline_frame, "focused": incident_frame}})
	results.append({"name": "camera_blocking/incident_focus_keeps_participants_cue_and_place_visible_selectable",
		"ok": bool(incident_context.ok), "details": incident_context})

	var practice = Gate2Suite._social_pair(["kojo", "esi"], "training", {
		"kojo": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
		"esi": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}})
	Gate2Suite._await_social(practice, "shared_practice")
	controller_sim.set("_state", practice.get_state().duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "subject.select", {})
	world._process(0.01)
	baseline_data = controller.get_snapshot().data
	baseline_frame = _camera_geometry_frame(world, baseline_data)
	var echo_subject := {"kind": "echo", "id": "kojo"}
	_camera_select_and_snap(controller, world, echo_subject)
	var echo_data: Dictionary = controller.get_snapshot().data
	var echo_frame: Dictionary = _camera_geometry_frame(world, echo_data)
	var echo_geometry_ok: bool = _camera_frames_preserve_authored_geometry(baseline_frame, echo_frame)
	var echo_context: Dictionary = _echo_focus_context(world, echo_data, "kojo")
	results.append({"name": "camera_blocking/echo_focus_preserves_every_subject_relative_size_and_position",
		"ok": echo_geometry_ok, "details": {"baseline": baseline_frame, "focused": echo_frame}})
	results.append({"name": "camera_blocking/echo_focus_keeps_echo_place_and_all_occupants_visible_selectable",
		"ok": bool(echo_context.ok), "details": echo_context})

	var script_source := FileAccess.get_file_as_string("res://prototypes/sanctum_systems_exploration/ui/PrototypeHouseView.gd")
	Suite._check(results, "camera_blocking/no_selected_only_incident_scale_or_focused_place_renderer",
		not script_source.contains("1.45 if selected") and not script_source.contains("_draw_focused_place(id, place, p)"))
	_manual_zoom_anchor_check(results, controller, world)
	_reduced_motion_endpoint_check(results, controller, world)


func _camera_geometry_frame(world: Control, data: Dictionary) -> Dictionary:
	var zoom: float = float(world.get("_zoom"))
	var echo_positions: Dictionary = {}
	var echo_scale_factors: Dictionary = {}
	for echo: Dictionary in data.get("echoes", []):
		echo_positions[str(echo.id)] = _screen_to_camera_world(world, world._echo_screen(echo))
		var echo_metrics: Dictionary = world.capture_metrics({"kind": "echo", "id": echo.id})
		echo_scale_factors[str(echo.id)] = float(echo_metrics.get("subject_bounds", Rect2()).size.x) / maxf(0.0001, zoom)
	var place_positions: Dictionary = {}
	var place_scale_factors: Dictionary = {}
	for id: String in data.get("places", {}):
		if str(data.places[id].get("node", "")).is_empty():
			continue
		place_positions[id] = _screen_to_camera_world(world, world._screen(world._subject_position({"kind": "place", "id": id})))
		place_scale_factors[id] = float(world._place_scale(id)) / maxf(0.0001, zoom)
	var incident_positions: Dictionary = {}
	for incident: Dictionary in data.get("incidents", []):
		incident_positions[str(incident.id)] = _screen_to_camera_world(world, world._incident_screen(incident))
	return {"echo_positions": echo_positions, "echo_scale_factors": echo_scale_factors,
		"place_positions": place_positions, "place_scale_factors": place_scale_factors,
		"incident_positions": incident_positions}


func _screen_to_camera_world(world: Control, point: Vector2) -> Vector2:
	var zoom: float = maxf(0.0001, float(world.get("_zoom")))
	var screen_centre := Vector2((world.size.x - float(world.get("_reserved_width"))) * 0.5, world.size.y * 0.5)
	return (point - screen_centre - (world.get("_pan") as Vector2)) / zoom


func _camera_frames_preserve_authored_geometry(baseline: Dictionary, focused: Dictionary) -> bool:
	const CAMERA_RECOVERY_EPSILON := 0.001
	for collection: String in ["echo_positions", "place_positions", "incident_positions"]:
		if baseline[collection].keys() != focused[collection].keys():
			return false
		for id: String in baseline[collection]:
			if (baseline[collection][id] as Vector2).distance_to(focused[collection][id] as Vector2) > CAMERA_RECOVERY_EPSILON:
				return false
	for collection: String in ["echo_scale_factors", "place_scale_factors"]:
		if baseline[collection].keys() != focused[collection].keys():
			return false
		for id: String in baseline[collection]:
			if absf(float(baseline[collection][id]) - float(focused[collection][id])) > CAMERA_RECOVERY_EPSILON:
				return false
	return true


func _camera_select_and_snap(controller: Node, world: Control, subject: Dictionary) -> void:
	_command(controller, "view.motion", {"reduced": true})
	_command(controller, "subject.select", subject)
	world._process(0.01)


func _echo_focus_context(world: Control, data: Dictionary, echo_id: String) -> Dictionary:
	var selected: Dictionary = Suite._echo(data, echo_id)
	var place_id := _place_for_node(data, str(selected.get("node", "")))
	var occupants: Array = _occupants_at_node(data, str(selected.get("node", "")))
	var missing: Array[String] = []
	if not _place_is_visible_selectable(world, place_id):
		missing.append("place:" + place_id)
	for occupant: Dictionary in occupants:
		if not _echo_is_visible_selectable(world, occupant):
			missing.append("echo:" + str(occupant.id))
	return {"ok": not place_id.is_empty() and occupants.any(func(echo: Dictionary) -> bool: return echo.id == echo_id) and missing.is_empty(),
		"place": place_id, "occupants": occupants.map(func(echo: Dictionary) -> String: return str(echo.id)), "missing": missing}


func _place_focus_context(world: Control, data: Dictionary, place_id: String) -> Dictionary:
	var node_id: String = str(data.get("places", {}).get(place_id, {}).get("node", ""))
	var occupants: Array = _occupants_at_node(data, node_id)
	var missing: Array[String] = []
	if not _place_is_visible_selectable(world, place_id):
		missing.append("place:" + place_id)
	for occupant: Dictionary in occupants:
		if not _echo_is_visible_selectable(world, occupant):
			missing.append("echo:" + str(occupant.id))
	return {"ok": not node_id.is_empty() and not occupants.is_empty() and missing.is_empty(),
		"place": place_id, "occupants": occupants.map(func(echo: Dictionary) -> String: return str(echo.id)), "missing": missing}


func _incident_focus_context(world: Control, data: Dictionary, incident_id: String) -> Dictionary:
	var incident: Dictionary = Gate2Suite._incident(data, incident_id)
	var missing: Array[String] = []
	for participant_id: String in incident.get("participants", []):
		if not _echo_is_visible_selectable(world, Suite._echo(data, participant_id)):
			missing.append("participant:" + participant_id)
	var cue: Vector2 = world._incident_screen(incident)
	var usable := _usable_world_rect(world).grow(-24.0)
	if not usable.has_point(cue) or not world._hits(cue).has({"kind": "incident", "id": incident_id}):
		missing.append("incident:" + incident_id)
	var place_id: String = str(incident.get("place", ""))
	if not _place_is_visible_selectable(world, place_id):
		missing.append("place:" + place_id)
	return {"ok": incident.get("participants", []).size() == 2 and missing.is_empty(),
		"participants": incident.get("participants", []).duplicate(), "place": place_id, "missing": missing}


func _occupants_at_node(data: Dictionary, node_id: String) -> Array:
	return data.get("echoes", []).filter(func(echo: Dictionary) -> bool:
		return not bool(echo.get("moving", false)) and str(echo.get("node", "")) == node_id)


func _place_for_node(data: Dictionary, node_id: String) -> String:
	for id: String in data.get("places", {}):
		if str(data.places[id].get("node", "")) == node_id:
			return id
	return ""


func _echo_is_visible_selectable(world: Control, echo: Dictionary) -> bool:
	if echo.is_empty():
		return false
	var centre: Vector2 = world._echo_screen(echo)
	var radius: float = 40.0 * float(world.get("_zoom"))
	var bounds := Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return _usable_world_rect(world).encloses(bounds) and world._hits(centre).has({"kind": "echo", "id": echo.id})


func _place_is_visible_selectable(world: Control, place_id: String) -> bool:
	if place_id.is_empty():
		return false
	var subject := {"kind": "place", "id": place_id}
	var centre: Vector2 = world._screen(world._subject_position(subject))
	return _usable_world_rect(world).grow(-24.0).has_point(centre) and world._hits(centre).has(subject)


func _usable_world_rect(world: Control) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(maxf(0.0, world.size.x - float(world.get("_reserved_width"))), world.size.y))


func _manual_zoom_anchor_check(results: Array[Dictionary], controller: Node, world: Control) -> void:
	const CAMERA_ANCHOR_EPSILON := 0.001
	_camera_select_and_snap(controller, world, {"kind": "place", "id": "training"})
	var cursor := Vector2(310, 260)
	var before_world: Vector2 = _screen_to_camera_world(world, cursor)
	var zoom_before: float = float(world.get("_zoom"))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = cursor
	world._gui_input(wheel)
	world._process(0.01)
	var after_world: Vector2 = _screen_to_camera_world(world, cursor)
	var anchor_error: float = before_world.distance_to(after_world)
	results.append({
		"name": "camera_blocking/manual_zoom_out_preserves_world_point_without_recentering",
		"ok": bool(world.get("_manual_camera")) and float(world.get("_zoom")) < zoom_before and anchor_error <= CAMERA_ANCHOR_EPSILON,
		"details": {"before_world": before_world, "after_world": after_world, "anchor_error": anchor_error,
			"zoom_before": zoom_before, "zoom_after": float(world.get("_zoom")), "manual_camera": bool(world.get("_manual_camera"))},
	})


func _reduced_motion_endpoint_check(results: Array[Dictionary], controller: Node, world: Control) -> void:
	const CAMERA_ENDPOINT_EPSILON := 0.001
	_reset_live(controller)
	_command(controller, "view.motion", {"reduced": false})
	_command(controller, "subject.select", {})
	world._process(1.0)
	_command(controller, "subject.select", {"kind": "place", "id": "quiet"})
	world._process(2.0)
	var normal_target_zoom: float = float(world.get("_zoom_target"))
	var normal_target_pan: Vector2 = world.get("_pan_target")
	var normal_zoom: float = float(world.get("_zoom"))
	var normal_pan: Vector2 = world.get("_pan")
	_command(controller, "subject.select", {})
	_command(controller, "view.motion", {"reduced": true})
	_command(controller, "subject.select", {"kind": "place", "id": "quiet"})
	world._process(0.01)
	var reduced_target_zoom: float = float(world.get("_zoom_target"))
	var reduced_target_pan: Vector2 = world.get("_pan_target")
	var reduced_zoom: float = float(world.get("_zoom"))
	var reduced_pan: Vector2 = world.get("_pan")
	var endpoint_errors := {
		"target_zoom": absf(reduced_target_zoom - normal_target_zoom),
		"target_pan": reduced_target_pan.distance_to(normal_target_pan),
		"normal_zoom_to_target": absf(normal_zoom - normal_target_zoom),
		"normal_pan_to_target": normal_pan.distance_to(normal_target_pan),
		"reduced_zoom_to_target": absf(reduced_zoom - reduced_target_zoom),
		"reduced_pan_to_target": reduced_pan.distance_to(reduced_target_pan),
		"endpoint_zoom": absf(reduced_zoom - normal_zoom),
		"endpoint_pan": reduced_pan.distance_to(normal_pan),
	}
	results.append({
		"name": "camera_blocking/reduced_motion_snaps_to_same_uniform_camera_endpoint",
		"ok": endpoint_errors.values().all(func(error: float) -> bool: return error <= CAMERA_ENDPOINT_EPSILON),
		"details": {"normal_target_zoom": normal_target_zoom, "normal_target_pan": normal_target_pan,
			"normal_zoom": normal_zoom, "normal_pan": normal_pan,
			"reduced_target_zoom": reduced_target_zoom, "reduced_target_pan": reduced_target_pan,
			"reduced_zoom": reduced_zoom, "reduced_pan": reduced_pan, "errors": endpoint_errors},
	})


func _settled_incident_state(state: Dictionary) -> Dictionary:
	var settled: Dictionary = state.duplicate(true)
	settled.social_engagements = []
	settled.tuning.social_frequency = 0.0
	for echo: Dictionary in settled.echoes:
		echo.engagement_id = ""
		echo.reserved = not str(echo.get("incident_id", "")).is_empty()
	return settled


func _incident_views_are_structured(entries: Array, text_key: String) -> bool:
	if entries.is_empty():
		return false
	for entry: Dictionary in entries:
		if not entry.has_all(["echo_id", "role", text_key]):
			return false
		if str(entry.get("echo_id", "")).is_empty():
			return false
		if str(entry.get("role", "")) not in ["initiator", "receiver"]:
			return false
		if str(entry.get(text_key, "")).is_empty():
			return false
	return true


func _reply_choices_have_qualitative_cues(replies: Array) -> bool:
	for reply: Dictionary in replies:
		var cue: Dictionary = reply.get("consequence_cue", {})
		if not cue.has_all(["tone", "text"]) or str(cue.get("text", "")).is_empty():
			return false
		if JSON.stringify(cue).contains("delta"):
			return false
	return true


func _history_card_has_glance_structure(card: Dictionary) -> bool:
	if not card.has_all(["type_label", "glyph", "tone", "people", "title", "badge", "meta", "changes"]):
		return false
	for key: String in ["type_label", "glyph", "people", "title", "badge", "meta"]:
		if str(card.get(key, "")).is_empty():
			return false
	return card.get("changes", []) is Array and str(card.get("meta", "")).contains(" · ")


func _visual_has_forbidden_raw_keys(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value.keys():
			var normalized := str(key).to_lower()
			if normalized in ["value", "max", "strength", "encounter_count", "score", "candidate_score",
				"remaining_ms", "duration_ms", "stage_deadline_ms", "intervention_deadline_ms"]:
				return true
			if normalized == "delta" or normalized.ends_with("_delta"):
				return true
			if _visual_has_forbidden_raw_keys(value[key]):
				return true
	elif value is Array:
		for item: Variant in value:
			if _visual_has_forbidden_raw_keys(item):
				return true
	return false


func _normal_surface_has_raw_values(ui: Control) -> bool:
	var panel: Control = ui.get_node("%ContextPanel")
	if not panel.is_visible_in_tree():
		return false
	var visible_text: Array[String] = []
	_collect_visible_text(panel, visible_text)
	var raw_pattern := RegEx.new()
	raw_pattern.compile("(?i)(rest|company|purpose|need|bond|strength|encounter|score|remaining|duration|timer)[^\\n]{0,24}(?:[+-]\\s*\\d|\\d+\\.\\d+)")
	var signed_pattern := RegEx.new()
	signed_pattern.compile("(?:^|[\\s:,(])(?:\\+|-)[0-9]+(?:\\.[0-9]+)?(?:$|[\\s),])")
	for line: String in visible_text:
		if raw_pattern.search(line) != null or signed_pattern.search(line) != null:
			return true
	return false


func _collect_visible_text(node: Node, output: Array[String]) -> void:
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is Label or node is Button or node is RichTextLabel:
		var text_value: String = str(node.get("text"))
		if not text_value.is_empty():
			output.append(text_value)
	for child: Node in node.get_children():
		_collect_visible_text(child, output)


func _subject_is_central_and_unclipped(metrics: Dictionary) -> bool:
	var bounds: Rect2 = metrics.get("subject_bounds", Rect2())
	var usable: Rect2 = metrics.get("usable_rect", Rect2())
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or usable.size.x <= 0.0 or usable.size.y <= 0.0:
		return false
	var central := Rect2(usable.position + usable.size * 0.2, usable.size * 0.6)
	return usable.encloses(bounds) and central.has_point(bounds.get_center())


func _command(controller: Node, suffix: String, payload: Dictionary = {}) -> void:
	controller.handle_action({"type": "prototype." + suffix, "payload": payload})


func _inspection_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	_reset_live(controller)
	controller.advance_elapsed(2.0)
	_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
	ui.get_node("%Lab").pressed.emit()
	var slider: HSlider = ui.get_node("%Tuning0")
	var command_count: int = _state(controller).commands.size()
	var fraction_before: float = controller.get_snapshot().data.clock.progress
	slider.drag_started.emit()
	slider.value = 6
	slider.value = 4
	slider.value = 5
	Suite._check(results, "ui/slider_drag_previews_without_simulation_commands", _state(controller).commands.size() == command_count and controller.get_snapshot().data.tuning.day_minutes == 12)
	slider.drag_ended.emit(true)
	Suite._check(results, "ui/slider_drag_commits_once_preserving_day_fraction", _state(controller).commands.size() == command_count + 1 and controller.get_snapshot().data.tuning.day_minutes == 5 and is_equal_approx(float(controller.get_snapshot().data.clock.progress), fraction_before))
	ui.get_node("%Tuning0").value = 3
	Suite._check(results, "ui/day_slider_reaches_simulation", is_equal_approx(float(controller.get_snapshot().data.tuning.day_minutes), 3.0))
	ui.get_node("%Tuning1").value = 10
	Suite._check(results, "ui/routine_slider_reaches_simulation", is_equal_approx(float(controller.get_snapshot().data.tuning.routine_seconds), 10.0))
	for index: int in range(2, 5):
		ui.get_node("%Tuning" + str(index)).value = 1.7
		var tuning_key: String = ["rest_weight", "company_weight", "purpose_weight"][index - 2]
		Suite._check(results, "ui/weight_slider_%d_reaches_simulation" % index, is_equal_approx(float(controller.get_snapshot().data.tuning[tuning_key]), 1.7))
	for tuning_entry: Array in [[5, "social_frequency", 2.4], [6, "warning_seconds", 35.0], [7, "intervention_seconds", 25.0]]:
		var tuning_index: int = tuning_entry[0]
		var tuning_key: String = tuning_entry[1]
		var tuning_value: float = tuning_entry[2]
		ui.get_node("%Tuning" + str(tuning_index)).value = tuning_value
		Suite._check(results, "ui/gate2_slider_%d_reaches_simulation" % tuning_index, is_equal_approx(float(controller.get_snapshot().data.tuning[tuning_key]), tuning_value) and ui.get_node("%TuningLabel" + str(tuning_index)).text.contains(str(tuning_value)))
	ui.get_node("%Back").pressed.emit()
	for index: int in range(80):
		controller.advance_elapsed(4.0)
	ui.get_node("%Pause").pressed.emit()
	var history_snapshot: Dictionary = controller.get_snapshot()
	var recent_echo: Dictionary = {}
	for echo: Dictionary in history_snapshot.data.echoes:
		if recent_echo.is_empty() or echo.get("recent_memories", []).size() > recent_echo.get("recent_memories", []).size():
			recent_echo = echo
	var projected_memories: Array = recent_echo.get("recent_memories", []).duplicate(true)
	_command(controller, "subject.select", {"kind": "echo", "id": recent_echo.get("id", "")})
	ui.get_node("%Recent").pressed.emit()
	var recent: Dictionary = controller.get_snapshot().data.panel
	var expected_first_page: Array = projected_memories.slice(0, 12)
	Suite._check(results, "ui/recent_shows_exact_authored_first_person_memory_page",
		not projected_memories.is_empty() and controller.get_snapshot().data.panel_mode == "history"
		and recent.history_total == projected_memories.size() and recent.history_entries == expected_first_page
		and recent.history_page == 0)
	var recent_cards: Array = recent.get("visual", {}).get("cards", [])
	var authored_cards: bool = recent_cards.size() == recent.history_entries.size()
	for card_index: int in recent_cards.size():
		authored_cards = authored_cards and str(recent_cards[card_index].get("text", "")) == str(recent.history_entries[card_index].get("perspective", "")) \
			and str(recent_cards[card_index].get("text", "")).begins_with("I ")
	Suite._check(results, "ui/recent_cards_use_authored_perspective_without_internal_event_rows",
		authored_cards and not str(recent.body).contains("source_event_id"))
	ui.get_node("%HistoryNext").pressed.emit()
	var page_two: Dictionary = controller.get_snapshot().data.panel
	var expected_page: int = 1 if projected_memories.size() > 12 else 0
	var expected_page_entries: Array = projected_memories.slice(expected_page * 12, (expected_page + 1) * 12)
	Suite._check(results, "ui/history_next_stays_within_authored_echo_memory_pages",
		page_two.history_page == expected_page and page_two.history_entries == expected_page_entries)
	ui.get_node("%HistoryPrev").pressed.emit()
	Suite._check(results, "ui/history_previous_returns_first_page", controller.get_snapshot().data.panel.history_entries == recent.history_entries)
	ui.get_node("%Current").pressed.emit()
	Suite._check(results, "ui/current_recent_separate_views", controller.get_snapshot().data.panel_mode == "" and ui.get_node("%Current").visible and ui.get_node("%Recent").visible)
	_command(controller, "subject.select", {"kind": "place", "id": "quiet"})
	ui.get_node("%Recent").pressed.emit()
	var place_history: Array = controller.get_snapshot().data.panel.history_entries
	Suite._check(results, "ui/place_history_uses_real_place_events", not place_history.is_empty() and place_history.all(func(e: Dictionary) -> bool: return e.place == "quiet"))
	ui.get_node("%Current").pressed.emit()
	var serial_before: int = controller.get_snapshot().data.session_serial
	ui.get_node("%Reset").pressed.emit()
	Suite._check(results, "controller/reset_invalidates_session_history", controller.get_snapshot().data.session_serial != serial_before and controller.get_snapshot().data.events.is_empty() and controller.get_snapshot().meta.t == 0)
	Suite._check(results, "controller/reset_keeps_live_tuning", controller.get_snapshot().data.tuning.day_minutes == 3 and controller.get_snapshot().data.tuning.routine_seconds == 10)
	await _layout_camera_checks(results, controller, ui, world)
	_crowded_checks(results, controller, ui, world)
	_sections["inspection"] = true


func _layout_camera_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	_command(controller, "view.motion", {"reduced": true})
	_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
	var profile_sizes := [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080)]
	for profile_index: int in profile_sizes.size():
		var size_value: Vector2i = profile_sizes[profile_index]
		root.size = size_value
		await process_frame
		await process_frame
		world._process(0.01)
		var rect: Rect2 = ui.get_node("%ContextPanel").get_global_rect()
		Suite._check(results, "layout/panel_inside_%dx%d" % [size_value.x, size_value.y], rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= ui.size.x + 0.1 and rect.end.y <= ui.size.y + 0.1)
		var targets_fit := true
		for id: String in ["Pause", "Normal", "Fast", "NextBeat", "Lab", "Back", "Current", "Recent", "Choice0", "Choice1"]:
			var target: Control = ui.get_node("%" + id)
			if target.is_visible_in_tree():
				var target_rect := target.get_global_rect()
				targets_fit = targets_fit and target.size.x >= 48 and target.size.y >= 48 and target_rect.position.x >= 0 and target_rect.end.x <= ui.size.x + 0.1 and target_rect.position.y >= 0 and target_rect.end.y <= ui.size.y + 0.1
		Suite._check(results, "layout/targets_fit_minimum_48_%dx%d" % [size_value.x, size_value.y], targets_fit)
		var target_failures: Array[String] = []
		_collect_actionable_target_failures(ui, target_failures)
		Suite._check(results, "layout/all_visible_actionable_targets_minimum_48_%dx%d" % [size_value.x, size_value.y], target_failures.is_empty())
		Suite._check(results, "layout/actual_visible_fonts_minimum_16_%dx%d" % [size_value.x, size_value.y], Capture._minimum_visible_font_size(ui) >= 16)
		if profile_index < 4:
			var echo_context: Dictionary = _echo_focus_context(world, controller.get_snapshot().data, "yaw")
			results.append({"name": "camera_responsive/echo_place_occupants_visible_selectable_%dx%d" % [size_value.x, size_value.y],
				"ok": bool(echo_context.ok), "details": echo_context})
			_camera_select_and_snap(controller, world, {"kind": "place", "id": "quiet"})
			var place_context: Dictionary = _place_focus_context(world, controller.get_snapshot().data, "quiet")
			results.append({"name": "camera_responsive/place_marker_occupants_visible_selectable_%dx%d" % [size_value.x, size_value.y],
				"ok": bool(place_context.ok), "details": place_context})
			_camera_select_and_snap(controller, world, {"kind": "echo", "id": "yaw"})
		if size_value == Vector2i(960, 540):
			var selected: Dictionary = Suite._echo(controller.get_snapshot().data, "yaw")
			var body: String = controller.get_snapshot().data.panel.body
			Suite._check(results, "layout/compact_current_uses_two_column_choices", int(ui.get_node("%Choices").columns) == 2)
			var why_index: int = body.find("\n\nWHY\n")
			var action_index: int = body.find("\n\nWHAT YOU CAN DO\n")
			var support_index: int = body.find("\n\nABOUT %s\n" % selected.name)
			Suite._check(results, "layout/compact_current_leads_with_now_why_and_action_before_supporting_detail",
				body.begins_with("NOW\n") and why_index > 0 and action_index > why_index and support_index > action_index
				and body.find(str(selected.reason)) >= why_index and body.find("\n\nUNMET NEEDS\n") > support_index)
	Suite._check(results, "keyboard/people_places_reachable", world._subjects().size() >= 12)
	world.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	world._gui_input(key)
	key.keycode = KEY_ENTER
	world._gui_input(key)
	Suite._check(results, "keyboard/world_selection_routes_to_controller", controller.get_snapshot().data.selection.kind == "echo")
	ui.get_node("%Current").grab_focus()
	var next_focus: Control = ui.get_node("%Current").find_next_valid_focus()
	Suite._check(results, "keyboard/context_focus_navigation", next_focus != null and next_focus != ui.get_node("%Current"))
	_camera_checks(results, controller, ui, world)
	_empty_world_checks(results, controller, ui, world)
	_palette_checks(results, controller, ui, world)
	ui.get_node("%Back").pressed.emit()
	await process_frame
	Suite._check(results, "keyboard/back_closing_context_restores_world_focus", not ui.get_node("%ContextPanel").visible and world.has_focus())
	_sections["layout"] = true


func _collect_actionable_target_failures(node: Node, failures: Array[String]) -> void:
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is BaseButton or node is Slider or node is LineEdit:
		var target := node as Control
		if target.size.x < 48.0 or target.size.y < 48.0:
			failures.append("%s=%sx%s" % [str(target.get_path()), target.size.x, target.size.y])
	for child: Node in node.get_children():
		_collect_actionable_target_failures(child, failures)


func _camera_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	_reset_live(controller)
	_command(controller, "view.motion", {"reduced": false})
	_command(controller, "subject.select", {})
	world._process(0.25)
	var overview_zoom: float = float(world.get("_overview_zoom"))
	var overview_pan: Vector2 = world.get("_pan_target")
	var playback_before: String = controller.get_snapshot().data.speed
	var state_before_focus: Dictionary = _state(controller)
	_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
	var echo_zoom: float = float(world.get("_zoom_target"))
	var echo_pan: Vector2 = world.get("_pan_target")
	Suite._check(results, "camera/echo_selection_materially_zooms_and_reframes", echo_zoom > overview_zoom * 1.15 and echo_pan != overview_pan and echo_pan.is_equal_approx(world._focus_pan({"kind": "echo", "id": "yaw"})))
	_command(controller, "subject.select", {"kind": "place", "id": "quiet"})
	var place_zoom: float = float(world.get("_zoom_target"))
	var place_pan: Vector2 = world.get("_pan_target")
	Suite._check(results, "camera/place_selection_materially_zooms_and_reframes", place_zoom > overview_zoom * 1.15 and place_pan != overview_pan and place_pan.is_equal_approx(world._focus_pan({"kind": "place", "id": "quiet"})))
	Suite._check(results, "camera/selection_does_not_change_playback_or_simulation", controller.get_snapshot().data.speed == playback_before and _state(controller) == state_before_focus)
	_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
	_command(controller, "subject.observe")
	var simulation_before: Dictionary = _state(controller)
	var pan_before: Vector2 = world.get("_pan")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(150, 220)
	world._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(230, 250)
	drag.relative = Vector2(80, 30)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	world._gui_input(drag)
	press.pressed = false
	press.position = drag.position
	world._gui_input(press)
	world._process(0.25)
	Suite._check(results, "camera/manual_pan_overrides_without_sim_mutation", bool(world.get("_manual_camera")) and world.get("_pan") != pan_before and _state(controller) == simulation_before)
	var observe_serial: int = controller.get_snapshot().data.observation_serial
	ui.get_node("%Choice0").pressed.emit()
	Suite._check(results, "camera/refocus_reacquires_without_pause_or_mutation", not bool(world.get("_manual_camera")) and controller.get_snapshot().data.observation_serial > observe_serial and _state(controller) == simulation_before and controller.get_snapshot().data.speed == "normal")
	ui.get_node("%Lab").pressed.emit()
	ui.get_node("%ReducedMotion").set_pressed(true)
	ui.get_node("%Back").pressed.emit()
	_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
	world._process(0.25)
	var selected_screen: Vector2 = world._echo_screen(Suite._echo(controller.get_snapshot().data, "yaw"))
	Suite._check(results, "camera/selected_echo_clear_of_panel", selected_screen.x >= 24 and selected_screen.x < ui.get_node("%ContextPanel").get_global_rect().position.x - 24 and selected_screen.y >= 70 and selected_screen.y <= ui.size.y - 60)
	_reset_live(controller)
	_command(controller, "view.motion", {"reduced": false})
	_command(controller, "subject.select", {})
	world._process(1.0)
	_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
	world._process(0.01)
	var eased_zoom: float = float(world.get("_zoom"))
	var target_zoom: float = float(world.get("_zoom_target"))
	var transition_state: Dictionary = _state(controller)
	var phase_target: Color = world.get("_phase_tint_target")
	_command(controller, "view.motion", {"reduced": true})
	world._process(0.01)
	Suite._check(results, "camera/reduced_motion_changes_only_presentation_transition", not is_equal_approx(eased_zoom, target_zoom) and is_equal_approx(float(world.get("_zoom")), float(world.get("_zoom_target"))) and world.get("_phase_tint_target") == phase_target and _state(controller) == transition_state)
	_sections["camera"] = true


func _empty_world_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	_reset_live(controller)
	_command(controller, "playback.speed", {"speed": "paused"})
	var unchanged: Dictionary = _state(controller)
	for subject: Dictionary in [{"kind": "echo", "id": "yaw"}, {"kind": "place", "id": "quiet"}]:
		_command(controller, "subject.select", subject)
		_click_empty(world)
		Suite._check(results, "world/empty_click_closes_%s_context" % subject.kind, controller.get_snapshot().data.selection.is_empty() and not ui.get_node("%ContextPanel").visible and _state(controller) == unchanged)
	_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
	_command(controller, "conversation.begin", {"echo_id": "yaw"})
	Suite._check(results, "world/choosing_fixture_available_for_empty_click", controller.get_snapshot().data.conversation.get("status", "") == "choosing")
	_click_empty(world)
	Suite._check(results, "world/empty_click_cancels_choosing_without_intervention", controller.get_snapshot().data.selection.is_empty() and controller.get_snapshot().data.conversation.is_empty() and not Suite._echo(_state(controller), "yaw").reserved)
	_reset_live(controller)
	var moving: Dictionary = {}
	for index: int in range(20):
		controller.advance_elapsed(0.25)
		for echo: Dictionary in controller.get_snapshot().data.echoes:
			if echo.moving:
				moving = echo
				break
		if not moving.is_empty():
			break
	Suite._check(results, "world/approaching_fixture_available_for_empty_click", not moving.is_empty())
	if not moving.is_empty():
		_command(controller, "subject.select", {"kind": "echo", "id": moving.id})
		_command(controller, "conversation.begin", {"echo_id": moving.id})
		var approach_before: Dictionary = Suite._echo(_state(controller), moving.id)
		_click_empty(world)
		var approach_after: Dictionary = Suite._echo(_state(controller), moving.id)
		Suite._check(results, "world/empty_click_cancels_approach_without_intervention", controller.get_snapshot().data.selection.is_empty() and controller.get_snapshot().data.conversation.is_empty() and not approach_after.reserved and approach_after.position == approach_before.position and approach_after.pressures == approach_before.pressures)
	_reset_live(controller)
	_command(controller, "playback.speed", {"speed": "paused"})
	_command(controller, "subject.select", {"kind": "echo", "id": "yaw"})
	_command(controller, "conversation.begin", {"echo_id": "yaw"})
	_command(controller, "conversation.topic", {"topic": "feelings"})
	_command(controller, "conversation.reply", {"reply": "company"})
	var committed: Dictionary = controller.get_snapshot()
	var committed_state: Dictionary = _state(controller)
	_click_empty(world)
	Suite._check(results, "world/empty_click_cannot_discard_committed_reply", committed.data.conversation.get("status", "") == "resolved" and controller.get_snapshot().data.selection == committed.data.selection and controller.get_snapshot().data.conversation == committed.data.conversation and _state(controller) == committed_state)


func _click_empty(world: Control) -> void:
	var point := Vector2(-1, -1)
	for y: int in range(8, int(world.size.y) - 7, 24):
		for x: int in range(8, int(world.size.x) - 7, 24):
			var candidate := Vector2(x, y)
			if world._hits(candidate).is_empty():
				point = candidate
				break
		if point.x >= 0:
			break
	assert(point.x >= 0, "Focused world must retain at least one empty click target")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.pressed = true
	world._gui_input(click)
	click.pressed = false
	world._gui_input(click)


func _palette_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	_reset_live(controller)
	_command(controller, "playback.speed", {"speed": "paused"})
	var sim = controller.get("_simulation")
	var baseline: Dictionary = _state(controller)
	var tints: Array[String] = []
	var backgrounds: Array[String] = []
	var phases: Array[String] = []
	var outcomes_unchanged := true
	for progress: float in [0.0, 0.25, 0.5, 0.75]:
		var state: Dictionary = baseline.duplicate(true)
		state.cycle_elapsed_ms = int(float(state.tuning.day_minutes) * 60000.0 * progress)
		state.day = 1
		sim.set("_state", state)
		_command(controller, "view.current")
		var snap: Dictionary = controller.get_snapshot()
		tints.append((world.get("_phase_tint_target") as Color).to_html())
		backgrounds.append((ui.get_node("%Background").color as Color).to_html())
		phases.append(str(snap.data.clock.phase))
		var observed: Dictionary = _state(controller)
		outcomes_unchanged = outcomes_unchanged and observed.echoes == baseline.echoes and observed.events == baseline.events and observed.beats == baseline.beats and observed.conversation == baseline.conversation and observed.metrics == baseline.metrics
	Suite._check(results, "palette/four_day_phases_have_distinct_world_and_ui_palettes", phases == ["morning", "afternoon", "evening", "night"] and _all_distinct(tints) and _all_distinct(backgrounds))
	Suite._check(results, "palette/calendar_presentation_does_not_change_simulation_outcomes", outcomes_unchanged)


func _all_distinct(values: Array[String]) -> bool:
	var seen: Dictionary = {}
	for value: String in values:
		seen[value] = true
	return seen.size() == values.size()


func _crowded_checks(results: Array[Dictionary], controller: Node, ui: Control, world: Control) -> void:
	var sim = controller.get("_simulation")
	var fixtures: Array = sim.get("_fixtures").duplicate(true)
	for fixture: Dictionary in fixtures:
		fixture.node = "flame"
		fixture.name += " of the Returning Story"
	sim.set("_fixtures", fixtures)
	_command(controller, "session.reset")
	_command(controller, "playback.speed", {"speed": "paused"})
	_command(controller, "subject.select", {"kind": "echo", "id": "kojo"})
	world._process(0.25)
	var all_selectable := true
	for person: Dictionary in controller.get_snapshot().data.echoes:
		var hits: Array = world._hits(world._echo_screen(person))
		all_selectable = all_selectable and hits.any(func(hit: Dictionary) -> bool: return hit.get("kind") == "echo" and hit.id == person.id)
	Suite._check(results, "world/six_crowded_fixture_echoes_selectable", all_selectable)
	var settled_state: Dictionary = sim.get_state()
	var courtyard_position: Array = sim.get_definition().waypoints.courtyard.pos.duplicate()
	for person: Dictionary in settled_state.echoes:
		person.merge({"position": courtyard_position.duplicate(), "node": "courtyard", "path": [], "moving": false}, true)
	sim.set("_state", settled_state)
	_command(controller, "subject.select", {"kind": "place", "id": "courtyard"})
	var here: String = controller.get_snapshot().data.panel.body
	var moving_state: Dictionary = sim.get_state()
	var moving: Dictionary = moving_state.echoes[0]
	var start := Suite._vector(sim.get_definition().waypoints.courtyard.pos)
	var target := Suite._vector(sim.get_definition().waypoints.north.pos)
	var position := start.move_toward(target, 0.5)
	moving.merge({"position": [position.x, position.y], "node": "courtyard", "path": ["north"], "moving": true}, true)
	sim.set("_state", moving_state)
	_command(controller, "view.current")
	var without_mover: String = controller.get_snapshot().data.panel.body
	var here_now_ok: bool = here.contains(moving.name) and not without_mover.contains(moving.name)
	results.append({"name": "ui/here_now_excludes_moving_last_node", "ok": here_now_ok,
		"details": {"echo_name": moving.name, "stationary_body": here, "moving_body": without_mover}})
	ui.get_node("%Setup").pressed.emit()
	Suite._check(results, "controller/setup_reset_clears_places", controller.get_snapshot().data.placements.is_empty())
	_sections["crowded"] = true
