extends SceneTree
## Capture the real standalone scene. Crowded modes are synthetic layout stress only.

const Gate2Suite = preload("res://prototypes/sanctum_systems_exploration/tests/PrototypeGate2Tests.gd")
const Gate3Suite = preload("res://prototypes/sanctum_systems_exploration/tests/PrototypeGate3Tests.gd")
const PRIMARY_SIZE := Vector2i(1920, 1080)
const CAPTURE_MATRIX := [
	{"profile": "primary", "size": Vector2i(1920, 1080), "modes": ["overview", "social_engagement", "reaction_exchange",
		"incident_warning_midpoint", "incident_private_open", "incident_open_midpoint", "incident_appeal_open",
		"incident_joined", "incident_deferred",
		"incident_resolved_aftermath", "incident_post_release", "echo_relationship", "crowded_incident",
		"focus_person", "focus_place", "gate3_ready", "gate3_confirm", "gate3_manifestation", "gate3_welcome",
		"gate3_completion", "visual_incident_result", "nine_echo_crowd", "practice_witness_warning"]},
	{"profile": "secondary", "size": Vector2i(1600, 900), "modes": ["overview", "incident_warning_midpoint",
		"incident_resolved_aftermath", "echo_relationship", "focus_person", "focus_place",
		"gate3_welcome", "visual_incident_result", "nine_echo_crowd", "practice_witness_warning"]},
	{"profile": "secondary", "size": Vector2i(1280, 720), "modes": ["overview", "incident_warning_midpoint",
		"incident_resolved_aftermath", "echo_relationship", "focus_person", "focus_place",
		"gate3_welcome", "visual_incident_result", "nine_echo_crowd", "practice_witness_warning"]},
	{"profile": "edge", "size": Vector2i(960, 540), "modes": ["overview", "incident_warning_midpoint",
		"incident_resolved_aftermath", "echo_relationship", "focus_person", "focus_place",
		"gate3_welcome", "visual_incident_result", "nine_echo_crowd", "practice_witness_warning"]},
]


static func capture_matrix() -> Array:
	return CAPTURE_MATRIX.duplicate(true)


static func capture_metadata(controller: Node, mode: String, width: int, height: int) -> Dictionary:
	return _capture_metadata(controller, mode, width, height)

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var width := PRIMARY_SIZE.x
	var height := PRIMARY_SIZE.y
	var mode := "setup"
	var output := "/tmp/sanctum_prototype.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--width="): width = int(argument.trim_prefix("--width="))
		elif argument.begins_with("--height="): height = int(argument.trim_prefix("--height="))
		elif argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	root.size = Vector2i(width, height)
	var scene: PackedScene = load("res://prototypes/sanctum_systems_exploration/SanctumLivingHouse.tscn")
	if scene == null:
		push_error("Could not load prototype capture scene")
		quit(1)
		return
	var controller: Node = scene.instantiate()
	if controller == null or not controller.has_method("get_snapshot") or not controller.has_method("advance_elapsed") or not controller.has_method("set_application_focused"):
		if controller != null:
			controller.free()
		push_error("Prototype capture controller did not load its required API")
		quit(1)
		return
	controller.set_process(false)
	root.add_child(controller)
	await process_frame
	controller.set_application_focused(true)
	controller.advance_elapsed(0.0)
	_prepare(controller, mode)
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	var captured: Image = root.get_texture().get_image()
	if captured == null or captured.is_empty() or captured.save_png(output) != OK:
		push_error("Could not capture prototype viewport")
		quit(1)
		return
	var metadata := FileAccess.open(output + ".json", FileAccess.WRITE)
	if metadata == null:
		push_error("Could not write capture metadata")
		quit(1)
		return
	metadata.store_string(JSON.stringify(_capture_metadata(controller, mode, width, height), "  "))
	metadata.close()
	quit(0)


func _prepare(controller: Node, mode: String) -> void:
	if mode == "setup":
		return
	_command(controller, "house.place", {"institution": "hearth", "site": "hearth_near"})
	_command(controller, "house.place", {"institution": "training", "site": "training_far"})
	_command(controller, "house.start")
	if mode == "visual_incident_result":
		_prepare_visual_incident_result(controller)
		return
	if mode in ["gate3_ready", "gate3_confirm", "gate3_manifestation", "gate3_welcome", "gate3_completion", "nine_echo_crowd"]:
		_prepare_gate3(controller, mode)
		return
	if mode in ["social_engagement", "reaction_exchange", "practice_witness_warning", "echo_relationship", "incident_warning", "incident_warning_midpoint",
		"incident_open", "incident_private_open", "incident_open_midpoint", "incident_appeal_open", "incident_joined", "incident_deferred", "incident_resolved",
		"incident_resolved_aftermath", "incident_post_release", "crowded_incident", "flame_recent", "gate2_lab"]:
		_prepare_gate2(controller, mode)
		return
	var phase_seconds := {"morning": 0, "afternoon": 45, "evening": 90, "night": 135}
	if phase_seconds.has(mode):
		_command(controller, "tuning.set", {"key": "day_minutes", "value": 3})
		for index: int in range(int(phase_seconds[mode])):
			controller.advance_elapsed(1.0)
	elif mode != "overview":
		for index: int in range(30):
			controller.advance_elapsed(1.0)
	_command(controller, "playback.speed", {"speed": "paused"})
	if mode in ["person", "focus", "focus_person", "history", "bundled_history", "dialogue", "conversation", "reply", "lab"]:
		_command(controller, "subject.select", {"kind": "echo", "id": "abena"})
	if mode in ["place", "focus_place"]:
		_command(controller, "subject.select", {"kind": "place", "id": "quiet"})
	elif mode == "lab":
		_command(controller, "view.lab")
	elif mode in ["history", "bundled_history", "place_history"]:
		_command(controller, "tuning.set", {"key": "routine_seconds", "value": 10})
		_command(controller, "playback.speed", {"speed": "normal"})
		for index: int in range(80):
			controller.advance_elapsed(4.0)
		_command(controller, "playback.speed", {"speed": "paused"})
		if mode == "place_history":
			_command(controller, "subject.select", {"kind": "place", "id": "quiet"})
		_command(controller, "view.history")
	elif mode in ["dialogue", "conversation", "reply"]:
		_command(controller, "conversation.begin", {"echo_id": "abena"})
		_command(controller, "playback.speed", {"speed": "normal"})
		for index: int in range(400):
			if controller.get_snapshot().data.conversation.get("status", "") == "choosing":
				break
			controller.advance_elapsed(0.25)
		_command(controller, "playback.speed", {"speed": "paused"})
		_command(controller, "conversation.topic", {"topic": "activity"})
		if mode == "reply":
			_command(controller, "conversation.reply", {"reply": "pause"})
	elif mode in ["crowded", "stress9"]:
		_prepare_stress(controller, 9 if mode == "stress9" else 6)


func _prepare_gate2(controller: Node, mode: String) -> void:
	if mode in ["incident_private_open", "incident_appeal_open"]:
		var access: String = "private" if mode == "incident_private_open" else "appeal"
		var access_fixture: Dictionary = Gate3Suite._incident_access_fixture(access)
		var access_sim = access_fixture.get("sim")
		var access_incident: Dictionary = access_fixture.get("incident", {})
		if access_sim == null or access_incident.is_empty():
			return
		Gate2Suite._act(access_sim, "tuning.set", {"key": "social_frequency", "value": 0})
		Gate2Suite._advance_to(access_sim, int(access_incident.stage_deadline_ms))
		var opened: Dictionary = Gate2Suite._incident(access_sim.get_state(), str(access_incident.id))
		var open_midpoint: int = int(opened.stage_started_ms) + int((int(opened.incident_deadline_ms) - int(opened.stage_started_ms)) / 2)
		Gate2Suite._advance_to(access_sim, open_midpoint)
		_install_gate2_state(controller, access_sim.get_state())
		_command(controller, "subject.select", {"kind": "incident", "id": access_incident.id})
		return
	if mode == "practice_witness_warning":
		var witness_sim = Gate2Suite._practice_warning_witness_fixture()
		var witness_result: Dictionary = Gate2Suite._await_social(witness_sim, "competitive_practice")
		_install_gate2_state(controller, witness_sim.get_state())
		var incidents: Array = witness_result.get("after", {}).get("incidents", [])
		var incident_id: String = str(incidents[0].get("id", "")) if not incidents.is_empty() else ""
		_command(controller, "subject.select", {"kind": "incident", "id": incident_id})
		return
	if mode in ["social_engagement", "reaction_exchange", "echo_relationship", "flame_recent", "gate2_lab"]:
		var practice = Gate2Suite._social_pair(["kojo", "esi"], "training", {
			"kojo": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
			"esi": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}})
		Gate2Suite._await_social(practice, "shared_practice")
		_install_gate2_state(controller, practice.get_state())
		if mode == "reaction_exchange":
			_command(controller, "subject.select", {})
		elif mode == "echo_relationship":
			_command(controller, "subject.select", {"kind": "echo", "id": "kojo"})
		elif mode == "flame_recent":
			_command(controller, "subject.select", {"kind": "place", "id": "flame"})
			_command(controller, "view.history")
		elif mode == "gate2_lab":
			_command(controller, "subject.select", {"kind": "echo", "id": "kojo"})
			_command(controller, "view.lab")
		return
	var fixture: Dictionary = Gate2Suite._warning_fixture(15.0, 45.0)
	var source = fixture.sim
	var incident_id: String = fixture.incident.id
	Gate2Suite._act(source, "tuning.set", {"key": "social_frequency", "value": 0})
	if mode in ["incident_warning_midpoint", "crowded_incident"]:
		var warning_midpoint: int = int(fixture.incident.created_ms) + int((int(fixture.incident.stage_deadline_ms) - int(fixture.incident.created_ms)) / 2)
		Gate2Suite._advance_to(source, warning_midpoint)
	elif mode not in ["incident_warning"]:
		Gate2Suite._advance_to(source, int(fixture.incident.stage_deadline_ms))
		if mode == "incident_open_midpoint":
			var opened: Dictionary = Gate2Suite._incident(source.get_state(), incident_id)
			var open_midpoint: int = int(opened.stage_started_ms) + int((int(opened.incident_deadline_ms) - int(opened.stage_started_ms)) / 2)
			Gate2Suite._advance_to(source, open_midpoint)
		elif mode in ["incident_joined", "incident_deferred", "incident_resolved", "incident_resolved_aftermath", "incident_post_release"]:
			Gate2Suite._act(source, "incident.join", {"incident_id": incident_id})
			if mode == "incident_deferred":
				Gate2Suite._act(source, "incident.defer", {"incident_id": incident_id})
			elif mode in ["incident_resolved", "incident_resolved_aftermath", "incident_post_release"]:
				Gate2Suite._act(source, "incident.reply", {"incident_id": incident_id, "reply_id": "give_space"})
				if mode == "incident_post_release":
					Gate2Suite._steps(source, 6)
	if mode == "crowded_incident":
		var crowded_state: Dictionary = source.get_state()
		while crowded_state.echoes.size() < 9:
			var extra: Dictionary = crowded_state.echoes[crowded_state.echoes.size() % 2].duplicate(true)
			extra.id = "incident_stress_%d" % crowded_state.echoes.size()
			extra.name = "Incident stress guest %d" % (crowded_state.echoes.size() + 1)
			extra.reserved = false
			extra.engagement_id = ""
			extra.incident_id = ""
			extra.behavior = {}
			crowded_state.echoes.append(extra)
		source.set("_state", crowded_state)
	_install_gate2_state(controller, source.get_state())
	if mode == "crowded_incident":
		controller.get_node("PrototypeUI/%Status").text = "SYNTHETIC INCIDENT STRESS · 9 duplicated Echoes"
	if mode == "incident_post_release":
		_command(controller, "subject.select", {"kind": "echo", "id": fixture.incident.participants[0]})
	else:
		_command(controller, "subject.select", {"kind": "incident", "id": incident_id})


static func _capture_metadata(controller: Node, mode: String, width: int, height: int) -> Dictionary:
	var snapshot: Dictionary = controller.get_snapshot()
	var ui: Control = controller.get_node("PrototypeUI")
	var world: Control = ui.get_node("HouseView")
	var selection: Dictionary = snapshot.data.get("selection", {})
	var subject_metrics: Dictionary = world.capture_metrics(selection) if world.has_method("capture_metrics") else {}
	var incident: Dictionary = {}
	if selection.get("kind", "") == "incident":
		incident = Gate2Suite._incident(snapshot.data, str(selection.get("id", "")))
	elif not snapshot.data.get("incidents", []).is_empty():
		incident = snapshot.data.incidents[0]
	var participant_ids: Array = incident.get("participants", [])
	if participant_ids.is_empty() and not snapshot.data.get("social_engagements", []).is_empty():
		participant_ids = snapshot.data.social_engagements[0].participants
	var participants: Array = []
	for participant_id: String in participant_ids:
		var echo: Dictionary = Gate2Suite._echo(snapshot.data, participant_id)
		participants.append({"id": participant_id, "position": echo.get("position", []).duplicate(),
			"facing": echo.get("facing", []).duplicate(), "activity": echo.get("activity", ""),
			"incident_id": echo.get("incident_id", ""), "behavior": echo.get("behavior", {}).duplicate(true)})
	var relationship_descriptors: Array = []
	for echo: Dictionary in snapshot.data.get("echoes", []):
		if selection.get("kind", "") == "echo" and selection.get("id", "") != echo.id:
			continue
		if not echo.get("bonds", []).is_empty() or not echo.get("impressions", []).is_empty():
			relationship_descriptors.append({"echo_id": echo.id, "bonds": echo.get("bonds", []).duplicate(true),
				"impressions": echo.get("impressions", []).duplicate(true)})
	var minimum_control_font: int = _minimum_visible_font_size(ui)
	var minimum_world_font: int = int(subject_metrics.get("minimum_world_font_size", minimum_control_font))
	return {"mode": mode, "matrix_index": _matrix_index(width, height, mode),
		"profile": _profile_for(width, height), "synthetic_stress": mode in ["crowded", "stress9", "crowded_incident"],
		"viewport": [width, height], "snapshot": snapshot, "selection": selection,
		"subject_bounds": subject_metrics.get("subject_bounds", {}),
		"usable_world_rect": subject_metrics.get("usable_rect", {}),
		"occupancy": subject_metrics.get("occupancy", 0.0),
		"minimum_visible_font_size": mini(minimum_control_font, minimum_world_font),
		"participants": participants, "issue_state": incident.duplicate(true),
		"relationship_descriptors": relationship_descriptors,
		"summoning": snapshot.data.get("summoning", {}).duplicate(true),
		"arrival_presentation": snapshot.data.get("arrival_presentation", {}).duplicate(true),
		"incident_result_overlay": snapshot.data.get("incident_result_overlay", {}).duplicate(true),
		"world_presentation": subject_metrics.duplicate(true)}


static func _minimum_visible_font_size(node: Node) -> int:
	var minimum := 1000000
	if node is Control and node.is_visible_in_tree() and (node is Label or node is Button or node is RichTextLabel):
		minimum = (node as Control).get_theme_font_size("font_size")
	for child: Node in node.get_children():
		var child_minimum := _minimum_visible_font_size(child)
		if child_minimum > 0:
			minimum = mini(minimum, child_minimum)
	return 0 if minimum == 1000000 else minimum


static func _matrix_index(width: int, height: int, mode: String) -> int:
	var index := 0
	for group: Dictionary in CAPTURE_MATRIX:
		for candidate: String in group.modes:
			if group["size"] == Vector2i(width, height) and candidate == mode:
				return index
			index += 1
	return -1


static func _profile_for(width: int, height: int) -> String:
	for group: Dictionary in CAPTURE_MATRIX:
		if group["size"] == Vector2i(width, height):
			return str(group.profile)
	return "custom"


func _install_gate2_state(controller: Node, state: Dictionary) -> void:
	controller.get("_simulation").set("_state", state.duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "playback.speed", {"speed": "paused"})


func _prepare_gate3(controller: Node, mode: String) -> void:
	_command(controller, "tuning.set", {"key": "social_frequency", "value": 0})
	_command(controller, "view.motion", {"reduced": true})
	_command(controller, "subject.select", {"kind": "place", "id": "flame"})
	if mode == "gate3_ready":
		return
	_command(controller, "summon.confirm")
	if mode == "gate3_confirm":
		return
	_command(controller, "summon.commit")
	if mode == "gate3_manifestation":
		controller.advance_elapsed(2.0)
		return
	controller.advance_elapsed(3.0)
	if mode == "gate3_welcome":
		return
	if mode == "gate3_completion":
		_complete_current_arrival(controller)
		return
	for index: int in range(3):
		if index > 0:
			var funded: Dictionary = controller.get("_simulation").get_state().duplicate(true)
			funded.ase = 120
			controller.get("_simulation").set("_state", funded)
			_command(controller, "view.current")
			_command(controller, "summon.confirm")
			_command(controller, "summon.commit")
			controller.advance_elapsed(3.0)
		_complete_current_arrival(controller)
		_command(controller, "summon.dismiss")
	_command(controller, "subject.select", {})
	controller.get_node("PrototypeUI/%Status").text = "NINE ECHO VILLAGE · three authored arrivals"


func _complete_current_arrival(controller: Node) -> void:
	var arrival: Dictionary = controller.get_snapshot().data.summoning.arrival
	if str(arrival.get("stage", "")) == "welcome":
		_command(controller, "summon.welcome", {"welcome_id": arrival.welcome_choices[0].id})
	for index: int in range(240):
		if str(controller.get_snapshot().data.summoning.arrival.get("stage", "")) == "complete":
			return
		controller.advance_elapsed(0.25)


func _prepare_visual_incident_result(controller: Node) -> void:
	var fixture: Dictionary = Gate2Suite._warning_fixture(15.0, 45.0)
	Gate2Suite._act(fixture.sim, "tuning.set", {"key": "social_frequency", "value": 0})
	Gate2Suite._advance_to(fixture.sim, int(fixture.incident.stage_deadline_ms))
	controller.get("_simulation").set("_state", fixture.sim.get_state().duplicate(true))
	controller.set("_elapsed", 0.0)
	_command(controller, "playback.speed", {"speed": "normal"})
	_command(controller, "incident.join", {"incident_id": fixture.incident.id})
	_command(controller, "incident.reply", {"incident_id": fixture.incident.id, "reply_id": "give_space"})


func _prepare_stress(controller: Node, count: int) -> void:
	var sim = controller.get("_simulation")
	var fixtures: Array = sim.get("_fixtures").duplicate(true)
	while fixtures.size() < count:
		var extra: Dictionary = fixtures[fixtures.size() - 6].duplicate(true)
		extra.id = "layout_extra_%d" % fixtures.size()
		extra.name = "Layout guest %d" % (fixtures.size() + 1)
		fixtures.append(extra)
	for fixture: Dictionary in fixtures:
		fixture.node = "flame"
		fixture.name += " of the Returning Story"
	sim.set("_fixtures", fixtures)
	_command(controller, "session.reset")
	_command(controller, "playback.speed", {"speed": "paused"})
	_command(controller, "subject.select", {"kind": "place", "id": "flame"})
	controller.get_node("PrototypeUI/%Status").text = "SYNTHETIC LAYOUT STRESS · %d duplicated Echoes" % count


func _command(controller: Node, suffix: String, payload: Dictionary = {}) -> void:
	controller.handle_action({"type": "prototype." + suffix, "payload": payload})
