extends Node
## Prototype dispatch boundary and wall-time scheduler. The simulation owns time and outcomes.

const Simulation = preload("res://prototypes/sanctum_systems_exploration/simulation/PrototypeSimulation.gd")
const Metrics = preload("res://prototypes/sanctum_systems_exploration/tests/PlaytestMetrics.gd")
const MAX_STEPS_PER_FRAME := 32
const HISTORY_PAGE_SIZE := 12
const STEP_SECONDS := float(Simulation.STEP_MS) / 1000.0
const PORTRAIT_PATHS := {
	"abena": "res://prototypes/sanctum_systems_exploration/assets/portraits/abena.png", "adwoa": "res://prototypes/sanctum_systems_exploration/assets/portraits/adwoa.png",
	"ama": "res://prototypes/sanctum_systems_exploration/assets/portraits/ama.png", "esi": "res://prototypes/sanctum_systems_exploration/assets/portraits/esi.png",
	"kojo": "res://prototypes/sanctum_systems_exploration/assets/portraits/kojo.png", "kweku": "res://prototypes/sanctum_systems_exploration/assets/portraits/kweku.png",
	"mensah": "res://prototypes/sanctum_systems_exploration/assets/portraits/mensah.png", "sena": "res://prototypes/sanctum_systems_exploration/assets/portraits/sena.png",
	"yaw": "res://prototypes/sanctum_systems_exploration/assets/portraits/yaw.png"
}

@onready var _ui: Control = %PrototypeUI
var _simulation = Simulation.new()
var _metrics = Metrics.new()
var _selected: Dictionary = {}
var _panel_mode := ""
var _history_page := 0
var _observing := false
var _observation_serial := 0
var _speed := "paused"
var _reduced_motion := false
var _elapsed := 0.0
var _application_focused := true
var _skip_focus_delta := false
var _session_serial := 0
var _notice := "Choose a site for the Hearth and Training Grounds. Both are free."
var _pending_result_overlay: Dictionary = {}


func _ready() -> void:
	get_window().title = "Sanctum · Living Village Prototype"
	get_window().min_size = Vector2i(960, 540)
	get_window().content_scale_size = Vector2i.ZERO
	_ui.action_requested.connect(handle_action)
	_publish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_application_focused(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_application_focused(true)


func _process(delta: float) -> void:
	if _application_focused:
		_metrics.sample(delta, "reference" if _panel_mode in ["lab", "history"] else "context" if not _selected.is_empty() else "world")
	advance_elapsed(delta)


func set_application_focused(focused: bool) -> void:
	if focused == _application_focused:
		return
	_application_focused = focused
	_elapsed = 0.0
	_skip_focus_delta = focused


func advance_elapsed(delta: float) -> int:
	if not _application_focused or _speed == "paused" or not _simulation.is_living():
		return 0
	if _skip_focus_delta:
		_skip_focus_delta = false
		return 0
	if not is_finite(delta) or delta < 0:
		return 0
	_elapsed += delta * (3.0 if _speed == "fast" else 1.0)
	var advanced := 0
	while _elapsed + 0.0000001 >= STEP_SECONDS and advanced < MAX_STEPS_PER_FRAME:
		_elapsed = maxf(0.0, _elapsed - STEP_SECONDS)
		_step()
		advanced += 1
	if advanced > 0:
		_publish()
	return advanced


func handle_action(action: Dictionary) -> void:
	var type: String = action.get("type", "")
	var payload: Dictionary = action.get("payload", {})
	var conversation: Dictionary = _simulation.build_snapshot_data().conversation
	var resolving: bool = conversation.get("status", "") == "resolved"
	if not _pending_result_overlay.is_empty() and type not in ["prototype.incident.result.dismiss", "prototype.view.back", "prototype.session.reset", "prototype.session.setup", "prototype.seed.set"]:
		return
	match type:
		"prototype.subject.select":
			if resolving:
				return
			_apply("prototype.conversation.cancel")
			_selected = payload.duplicate(true)
			_panel_mode = ""
			_history_page = 0
			_observing = false
			if not payload.is_empty():
				_metrics.record_action(type)
		"prototype.subject.observe":
			_observing = true
			_observation_serial += 1
			_metrics.record_action(type)
		"prototype.view.back":
			if not _pending_result_overlay.is_empty():
				_dismiss_pending_result(str(_pending_result_overlay.get("incident_id", "")))
				_publish()
				return
			if resolving:
				return
			if not _panel_mode.is_empty():
				_panel_mode = ""
			elif not conversation.is_empty():
				_apply("prototype.conversation.cancel")
			elif _observing:
				_observing = false
			else:
				_selected = {}
		"prototype.view.lab":
			if not resolving:
				_panel_mode = "" if _panel_mode == "lab" else "lab"
		"prototype.view.current":
			_panel_mode = ""
		"prototype.view.history":
			if conversation.is_empty():
				_panel_mode = "history"
				_history_page = 0
		"prototype.view.history.page":
			if _panel_mode == "history":
				_history_page = maxi(0, int(payload.get("page", 0)))
		"prototype.view.motion":
			_reduced_motion = bool(payload.get("reduced", false))
		"prototype.playback.speed":
			var requested: String = payload.get("speed", "paused")
			if requested in ["paused", "normal", "fast"]:
				_speed = requested
				if requested == "paused":
					_elapsed = 0.0
		"prototype.playback.next":
			var current_data: Dictionary = _simulation.build_snapshot_data()
			if _simulation.is_living() and conversation.is_empty() and not _joined_incident_pending(current_data):
				_speed = "paused"
				_elapsed = 0.0
				var limit: int = _simulation.build_snapshot_data().next_beat_steps
				var advanced := 0
				var found := false
				for index: int in range(limit):
					advanced += 1
					if _step():
						found = true
						break
				_notice = "Paused · %.2f seconds to %s" % [advanced * STEP_SECONDS, "the next activity." if found else "the observation limit."]
		"prototype.session.reset", "prototype.session.setup", "prototype.seed.set":
			var current: Dictionary = _simulation.build_snapshot_data()
			var seed_value: int = int(payload.get("seed", current.seed))
			var placements: Dictionary = {} if type == "prototype.session.setup" else current.placements
			_simulation.reset(seed_value, placements, current.tuning)
			_metrics = Metrics.new()
			_session_serial += 1
			_selected = {}
			_history_page = 0
			_observing = false
			_elapsed = 0.0
			_speed = "paused"
			_panel_mode = ""
			_pending_result_overlay.clear()
			_notice = "Fresh village session. Place both anchors, then start."
			if type == "prototype.session.reset" and placements.size() == 2:
				_apply("prototype.house.start")
				_speed = "normal"
		"prototype.house.start":
			if _apply(type, payload):
				_speed = "normal"
				_selected = {}
				_notice = "Life continues while you inspect. Speak to hold one Echo; Pause stops the village."
		"prototype.conversation.begin":
			if _apply(type, payload):
				_selected = {"kind": "echo", "id": payload.get("echo_id", "")}
				_panel_mode = ""
				_observing = false
		"prototype.conversation.reply":
			if _apply(type, payload):
				_metrics.record_action(type)
		"prototype.incident.join":
			if _apply(type, payload):
				_selected = {"kind": "incident", "id": payload.get("incident_id", "")}
				_panel_mode = ""
				_observing = false
				_observation_serial += 1
		"prototype.incident.reply":
			if _apply(type, payload):
				_capture_pending_result(str(payload.get("incident_id", "")))
		"prototype.incident.defer":
			_apply(type, payload)
		"prototype.incident.result.dismiss":
			_dismiss_pending_result(str(payload.get("incident_id", "")))
		"prototype.summon.confirm", "prototype.summon.commit", "prototype.summon.cancel", "prototype.summon.dismiss":
			if _apply(type, payload):
				_selected = {"kind": "place", "id": "flame"}
				_panel_mode = ""
				_observing = false
				_observation_serial += 1
		"prototype.summon.welcome":
			if _apply(type, payload):
				_selected = {"kind": "place", "id": "flame"}
				_panel_mode = ""
		_:
			_apply(type, payload)
	_publish()


func _apply(type: String, payload: Dictionary = {}) -> bool:
	return _simulation.apply_action({"type": type, "payload": payload}, _simulation.get_step())


func _step() -> bool:
	return _simulation.advance_step(_simulation.get_step() + 1)


func get_snapshot() -> Dictionary:
	var data: Dictionary = _simulation.build_snapshot_data(_panel_mode == "lab")
	if _selected.get("kind", "") == "incident" and _find_incident(data, str(_selected.get("id", ""))).is_empty():
		_selected = {}
	data.merge({"selection": _selected.duplicate(true), "panel_mode": _panel_mode, "observing": _observing,
		"speed": _speed, "reduced_motion": _reduced_motion, "notice": _notice,
		"session_serial": _session_serial, "observation_serial": _observation_serial, "playtest": _metrics.report(),
		"incident_result_overlay": _pending_result_overlay.duplicate(true)})
	data["arrival_presentation"] = _arrival_visual(data)
	data["panel"] = _build_panel(data)
	var actions: Dictionary = {}
	for speed: String in ["paused", "normal", "fast"]:
		actions["cta." + speed] = _action("prototype.playback.speed", "Fast 3×" if speed == "fast" else "Pause" if speed == "paused" else "Normal", {"speed": speed}, data.phase != "living")
	actions["cta.next"] = _action("prototype.playback.next", "Next beat", {}, data.phase != "living" or not data.conversation.is_empty() or _joined_incident_pending(data))
	actions["cta.start"] = _action("prototype.house.start", "Let the village live", {}, data.placements.size() != 2)
	for index: int in range(data.panel.choices.size()):
		actions["cta.choice_%d" % index] = data.panel.choices[index]
	if not _pending_result_overlay.is_empty():
		actions["overlay.continue"] = _action("prototype.incident.result.dismiss", "Continue", {"incident_id": _pending_result_overlay.incident_id})
		actions["overlay.back"] = _action("prototype.incident.result.dismiss", "Back", {"incident_id": _pending_result_overlay.incident_id})
	for slot: String in actions:
		actions[slot]["slot"] = slot
	return {"type": "prototype.sanctum." + str(data.phase), "meta": {"t": data.step, "seed": data.seed}, "data": data, "actions": actions}


func _portrait_path(echo_id: String) -> String:
	return str(PORTRAIT_PATHS.get(echo_id, ""))


func _arrival_visual(data: Dictionary) -> Dictionary:
	var arrival: Dictionary = data.get("summoning", {}).get("arrival", {})
	var stage: String = str(arrival.get("stage", ""))
	if stage.is_empty():
		return {}
	var newcomer_id: String = str(arrival.get("newcomer_id", arrival.get("newcomer", {}).get("id", "")))
	var newcomer: Dictionary = {}
	for echo: Dictionary in data.get("echoes", []):
		if str(echo.get("id", "")) == newcomer_id:
			newcomer = echo
	if newcomer.is_empty():
		newcomer = arrival.get("newcomer", {})
	var witnesses: Array = []
	for witness: Dictionary in arrival.get("witnesses", []):
		var witness_id: String = str(witness.get("echo_id", ""))
		witnesses.append({"id": witness_id, "name": _echo_name(data, witness_id), "response": str(witness.get("response", "watch")),
			"portrait_path": _portrait_path(witness_id), "reason": str(witness.get("reason", ""))})
	var first: Dictionary = arrival.get("first_intention", {})
	var destination: String = str(first.get("place", ""))
	return {"stage": stage, "manifested": stage in ["welcome", "travel", "complete"], "newcomer_id": newcomer_id, "name": str(newcomer.get("name", "A returning Echo")),
		"portrait_path": _portrait_path(newcomer_id), "archetype": str(newcomer.get("archetype", "Unknown")).capitalize(),
		"emotion": _plain_emotion(str(newcomer.get("emotional_status_label", newcomer.get("emotional_status", "unsure")))),
		"marking": str(newcomer.get("portrait", {}).get("marking", "A marked return")),
		"tendencies": _arrival_tendencies(newcomer), "witnesses": witnesses,
		"welcome": arrival.get("welcome", {}).duplicate(true), "welcome_choices": arrival.get("welcome_choices", []).duplicate(true), "destination": data.get("places", {}).get(destination, {}).get("name", ""),
		"route": first.get("route", []).duplicate(), "cause": str(first.get("cause", "")), "complete": stage == "complete"}


func _arrival_tendencies(newcomer: Dictionary) -> Array[String]:
	var tendencies: Array[String] = []
	var dialogue: Dictionary = newcomer.get("dialogue", {})
	if not str(dialogue.get("feelings", "")).is_empty(): tendencies.append(str(dialogue.get("feelings", "")))
	if not str(dialogue.get("activity", "")).is_empty(): tendencies.append(str(dialogue.get("activity", "")))
	return tendencies.slice(0, 2)


func _capture_pending_result(incident_id: String) -> void:
	if not _pending_result_overlay.is_empty():
		return
	var data: Dictionary = _simulation.build_snapshot_data()
	var incident: Dictionary = _find_incident(data, incident_id)
	if incident.is_empty() or str(incident.get("status", "")) != "resolved":
		return
	var result: Dictionary = incident.get("result", {})
	if result.is_empty():
		return
	var visual: Dictionary = _incident_result_visual(result, data)
	var cause_resolution: Dictionary = result.get("cause_resolution", {})
	_pending_result_overlay = {"incident_id": incident_id, "place_id": str(incident.get("place", "")),
		"title": str(incident.get("label", "A difficult moment")),
		"participants": _participant_names(data, incident.get("participants", [])),
		"people": _incident_result_people(data, incident.get("participants", []), visual.get("effects", [])),
		"place": str(data.get("places", {}).get(incident.get("place", ""), {}).get("name", "Village path")),
		"outcome": str(visual.get("aftermath", "The moment settled.")),
		"response": str(visual.get("response_label", "The moment was answered")),
		"views": visual.get("participant_views", []).duplicate(), "keeper_reactions": visual.get("keeper_reactions", []).duplicate(),
		"bond": visual.get("bond", {}).duplicate(), "effects": visual.get("effects", []).duplicate(),
		"next_behaviors": visual.get("next_behaviors", []).duplicate(),
		"cause_summary": str(cause_resolution.get("summary", incident.get("cause", ""))),
		"cause_eased": str(cause_resolution.get("status", "remains")) == "eased",
		"recurrence_cause": str(cause_resolution.get("recurrence_cause", "")),
		"recurrence_possible": bool(cause_resolution.get("recurrence_possible", false))}


func _incident_result_people(data: Dictionary, ids: Array, effects: Array) -> Array:
	var people: Array = []
	for echo_id: String in ids:
		var emotion := "Steady"
		for effect: Dictionary in effects:
			if str(effect.get("id", "")) == echo_id:
				emotion = str(effect.get("emotion_change", "Steady"))
		people.append({"id": echo_id, "name": _echo_name(data, echo_id), "portrait_path": _portrait_path(echo_id), "emotion": emotion})
	return people


func _dismiss_pending_result(incident_id: String) -> void:
	if incident_id != str(_pending_result_overlay.get("incident_id", "")):
		return
	var return_place: String = str(_pending_result_overlay.get("place_id", ""))
	_pending_result_overlay.clear()
	var incident: Dictionary = _find_incident(_simulation.build_snapshot_data(), incident_id)
	if incident.is_empty():
		_selected = {"kind": "place", "id": return_place} if not return_place.is_empty() else {}


func _publish() -> void:
	if is_instance_valid(_ui):
		_ui.set_snapshot(get_snapshot())


func _action(type: String, label: String, payload: Dictionary = {}, disabled: bool = false) -> Dictionary:
	return {"type": type, "label": label, "payload": payload, "disabled": disabled}


func _build_panel(data: Dictionary) -> Dictionary:
	var panel: Dictionary = {"visible": not _selected.is_empty() or not _panel_mode.is_empty(), "title": "", "subtitle": "", "body": "", "choices": [],
		"tabs_visible": false, "history_page": 0, "history_pages": 1, "history_entries": [], "history_total": 0,
		"kind": "", "context_key": "", "visual": {}}
	var id: String = _selected.get("id", "")
	var echo: Dictionary = {}
	for candidate: Dictionary in data.echoes:
		if candidate.id == id and _selected.get("kind") == "echo":
			echo = candidate
	if _panel_mode == "lab":
		panel.title = "Prototype lab"
		panel.subtitle = "Shared tuning · applied live"
		panel.body = "Day length preserves the current day fraction. Routine duration and need weights affect the next decision. Reset keeps tuning and placements."
		if not echo.is_empty():
			panel.body += "\n\n%s · %s\n" % [echo.name, echo.reason]
			for candidate: Dictionary in echo.candidates:
				var place_name: String = data.places.get(candidate.place, {}).get("name", candidate.place)
				panel.body += "%s · %s: %.1f\n%s\n" % [str(candidate.family).capitalize(), place_name, float(candidate.score), candidate.reason]
			panel.body += "Competing: " + str(echo.competing_reason)
		panel.body += "\n\nWorld selections %d · Observe %d · Replies %d\nReference %.0fs / world %.0fs / context %.0fs\nCommands recorded %d" % [
			data.playtest.counts.world_selections, data.playtest.counts.observe_requests, data.playtest.counts.keeper_replies,
			data.playtest.seconds.reference, data.playtest.seconds.world, data.playtest.seconds.context, data.commands.size()]
		return panel
	if _selected.get("kind") == "incident":
		var incident: Dictionary = _find_incident(data, id)
		if not incident.is_empty():
			_build_incident_panel(panel, data, incident)
		return panel
	if not echo.is_empty():
		panel.kind = "echo"
		panel.title = echo.name
		panel.subtitle = "%s · %s · Standing %d" % [str(echo.archetype).capitalize(), str(echo.calling).capitalize(), echo.standing]
		panel.tabs_visible = data.conversation.is_empty()
		if _panel_mode == "history":
			var memories: Array = echo.get("recent_memories", []).duplicate(true)
			if memories.is_empty() and not str(echo.get("recent", "")).is_empty():
				memories.append({"perspective": str(echo.recent)})
			_fill_history(panel, memories, data, true)
		elif not data.conversation.is_empty() and data.conversation.echo_id == id:
			_build_conversation(panel, data, echo)
		else:
			panel.body = _echo_current_body(echo)
			panel.visual = _echo_visual(echo, data)
			panel.choices = [_action("prototype.subject.observe", "Refocus" if _observing else "Observe"),
				_action("prototype.conversation.begin", "Speak", {"echo_id": id}, data.phase != "living" or not str(data.joined_incident_id).is_empty())]
		return panel
	if _selected.get("kind") == "site":
		for site: Dictionary in data.sites:
			if site.id != id:
				continue
			panel.title = site.name
			panel.subtitle = "Free starting place"
			panel.body = site.description
			var already: bool = data.placements.get(site.institution, "") == id
			panel.choices = [_action("prototype.house.place", "Placed here" if already else "Place here", {"institution": site.institution, "site": id}, already or data.phase != "setup")]
	elif _selected.get("kind") == "place" and data.places.has(id):
		panel.title = data.places[id].name
		panel.subtitle = "A place in the village"
		panel.tabs_visible = true
		if _panel_mode == "history":
			_fill_history(panel, data.village_history if id == "flame" else data.place_history.get(id, []), data)
		elif id == "flame":
			_build_flame_panel(panel, data)
		else:
			panel.body = ("NOW\nThe Ase Flame keeps the village's shared memory.\n\nWHAT YOU CAN DO\nOpen Recent to follow the moments people will remember." if id == "flame" else "NOW\n" + str(data.places[id].description))
			var present: Array[String] = []
			for person: Dictionary in data.echoes:
				if not person.moving and person.node == data.places[id].node:
					present.append("%s · %s" % [person.name, _display_activity(str(person.activity))])
			panel.body += "\n\nHERE NOW\n" + ("\n".join(present) if not present.is_empty() else "No one is resting here right now.")
	return panel


func _echo_current_body(echo: Dictionary) -> String:
	return "NOW\n%s\n\nWHY\n%s\n\nWHAT YOU CAN DO\nObserve their place in the village or speak with them.\n\nABOUT %s\n%s\n%s\n\nUNMET NEEDS\nA qualitative reading appears below." % [
		str(echo.get("current", "")), str(echo.get("reason", "")), str(echo.get("name", "")),
		str(echo.get("description", "")), _plain_emotion(str(echo.get("emotional_status", "")))]


func _build_flame_panel(panel: Dictionary, data: Dictionary) -> void:
	var summoning: Dictionary = data.get("summoning", {})
	var arrival: Dictionary = summoning.get("arrival", {})
	var stage: String = str(arrival.get("stage", ""))
	panel.context_key = "flame|" + stage
	if stage.is_empty():
		var state: String = str(summoning.get("flame_state", "unavailable"))
		panel.subtitle = "Ase Flame · " + state.capitalize()
		panel.body = "CHARGE\n%s\n\nA RETURN\nA new Echo costs %d Ase. The circle is watched by those who can make room." % [
			"Ready to call someone home." if state == "ready" else "The Flame is gathering itself again.", int(summoning.get("cost", 0))]
		if summoning.get("actions", {}).has("confirm"):
			panel.choices.append(_action("prototype.summon.confirm", "Call someone home"))
		return
	if stage == "confirming":
		panel.subtitle = "Ase Flame · confirm the return"
		panel.body = "A RETURN IS WAITING\nCommit %d Ase to begin. Nothing is spent unless you continue." % int(summoning.get("cost", 0))
		panel.choices = [_action("prototype.summon.commit", "Commit the return"), _action("prototype.summon.cancel", "Not yet")]
		return
	var arrival_visual: Dictionary = data.get("arrival_presentation", {})
	panel.subtitle = "Ase Flame · " + stage.capitalize()
	panel.body = "THE CIRCLE\n%s" % _arrival_stage_copy(stage, arrival_visual)
	panel.tabs_visible = false
	if stage == "welcome":
		panel.body += "\n\nWELCOME\nChoose one way to meet them. They will answer in their own way."
		for choice: Dictionary in arrival.get("welcome_choices", []):
			var cue: Dictionary = choice.get("cue", {})
			panel.choices.append(_action("prototype.summon.welcome", str(choice.get("label", "Welcome them")) + "\n" + str(cue.get("text", "")), {"welcome_id": choice.get("id", "")}))
	elif stage == "complete":
		panel.choices.append(_action("prototype.summon.dismiss", "Let the village carry on"))


func _arrival_stage_copy(stage: String, visual: Dictionary) -> String:
	match stage:
		"approach": return "People nearby decide whether to draw closer, watch, or give the circle room."
		"gather": return "The Flame holds a clear space for the return."
		"perform": return "Light gathers in the marks on the ground."
		"welcome": return "%s has arrived and is waiting to see how this house receives them." % str(visual.get("name", "Someone"))
		"travel": return "%s is choosing their first way into village life." % str(visual.get("name", "The newcomer"))
		"complete": return "%s has reached their first destination." % str(visual.get("name", "The newcomer"))
	return "The circle is holding a return."


func _build_conversation(panel: Dictionary, data: Dictionary, echo: Dictionary) -> void:
	var conversation: Dictionary = data.conversation
	match str(conversation.status):
		"approaching":
			panel.subtitle = "Making room to listen"
			panel.body = "%s is finishing this stretch of path.\n\nThe other Echoes carry on. %s" % [echo.name, "Resume time to let them approach." if _speed == "paused" else "You can leave without interrupting their intention."]
			for topic: Dictionary in data.topics:
				panel.choices.append(_action("prototype.conversation.topic", topic.label, {"topic": topic.id}, true))
		"resolved":
			panel.subtitle = str(conversation.outcome).capitalize()
			panel.body = "“%s”\n\n%s\n\n%s" % [conversation.line, conversation.reason, "Paused · resume time to let this moment finish." if _speed == "paused" else "A moment to respond, then life carries on."]
		"choosing":
			if str(conversation.topic).is_empty():
				panel.body = "“I am listening.”\n\nThe rest of the village carries on."
				for topic: Dictionary in data.topics:
					panel.choices.append(_action("prototype.conversation.topic", topic.label, {"topic": topic.id}))
			else:
				panel.body = "“%s”\n\n%s" % [echo.dialogue[conversation.topic], echo.reason]
				for topic: Dictionary in data.topics:
					if topic.id == conversation.topic:
						for reply: Dictionary in topic.replies:
							panel.choices.append(_action("prototype.conversation.reply", reply.label, {"reply": reply.id}))


func _build_incident_panel(panel: Dictionary, data: Dictionary, incident: Dictionary) -> void:
	var names: Array[String] = _participant_names(data, incident.participants)
	var place_name: String = data.places.get(incident.place, {}).get("name", "Village path")
	var status: String = str(incident.status)
	var access: String = str(incident.get("keeper_access", "private"))
	var appeal_id: String = str(incident.get("appeal_echo_id", ""))
	var appeal_name: String = _echo_name(data, appeal_id) if not appeal_id.is_empty() else ""
	panel.kind = "incident"
	panel.context_key = "%s|%s" % [incident.id, status]
	panel.title = str(incident.label)
	panel.subtitle = ("%s asks for help · " % appeal_name if access == "appeal" and not appeal_name.is_empty() else "") + "%s · %s" % [status.capitalize(), " & ".join(names)]
	panel.body = ""
	panel.visual = _incident_visual(incident, data, place_name)
	match status:
		"warning":
			pass
		"open":
			if access == "open":
				panel.choices.append(_action("prototype.incident.join", "Step in", {"incident_id": incident.id}, not bool(incident.can_join)))
			elif access == "appeal":
				panel.choices.append(_action("prototype.incident.join", "Answer %s" % appeal_name, {"incident_id": incident.id}, not bool(incident.can_join)))
		"joined":
			for reply: Dictionary in incident.reply_choices:
				panel.choices.append(_action("prototype.incident.reply", reply.label,
					{"incident_id": incident.id, "reply_id": reply.id}))
			panel.choices.append(_action("prototype.incident.defer", "Step back", {"incident_id": incident.id}))
		"resolved":
			pass


func _impression_text(impression: Dictionary, data: Dictionary) -> String:
	return "%s now reads %s as %s in %s moments" % [
		_echo_name(data, str(impression.get("owner_id", ""))),
		_echo_name(data, str(impression.get("other_id", ""))),
		str(impression.get("tag", "changed")).replace("_", " ").capitalize(),
		str(impression.get("family", "shared")).replace("_", " ").capitalize()]


func _trait_band(value: float) -> String:
	if value >= 7.0: return "Defining"
	if value >= 4.0: return "Steady"
	return "Quiet"


func _need_name(family: String) -> String:
	return "Something to do" if family == "purpose" else family.capitalize()


func _plain_emotion(status: String) -> String:
	match status.to_lower():
		"steady": return "Calm"
		"uneasy": return "Uneasy"
		"worried": return "Worried"
		"tense": return "Tense"
		"guarded": return "Guarded"
		"frustrated": return "Frustrated"
		"hurt": return "Hurt"
		"relieved": return "Relieved"
		"hopeful": return "Hopeful"
		"warm": return "Warm"
		_: return status.replace("_", " ").capitalize()


func _display_activity(activity: String) -> String:
	return activity.replace("_", " ").capitalize()


func _pressure_band(value: float, maximum: float) -> Dictionary:
	var ratio: float = clampf(value / maxf(0.001, maximum), 0.0, 1.0)
	var level: int = clampi(ceili(ratio * 5.0), 0, 5)
	var state := "Settled"
	if ratio >= 0.8: state = "Pressing"
	elif ratio >= 0.55: state = "Stirring"
	elif ratio >= 0.3: state = "Present"
	return {"level": level, "state": state}


func _echo_visual(echo: Dictionary, data: Dictionary) -> Dictionary:
	var needs: Dictionary = {}
	for family: String in ["rest", "company", "purpose"]:
		var need: Dictionary = echo.needs.get(family, {})
		var band: Dictionary = _pressure_band(float(need.get("value", 0.0)), float(need.get("max", 1.0)))
		band["name"] = _need_name(family)
		needs[family] = band
	var impression_by_other: Dictionary = {}
	for impression: Dictionary in echo.get("impressions", []):
		impression_by_other[str(impression.get("other_id", ""))] = str(impression.get("tag", "")).replace("_", " ").capitalize()
	var relationships: Array = []
	for bond: Dictionary in echo.get("bonds", []):
		relationships.append({"name": str(bond.get("name", _echo_name(data, str(bond.get("other_id", ""))))),
			"tier": int(bond.get("tier", 0)), "tier_name": str(bond.get("tier_name", "Unformed")),
			"bond_type": str(bond.get("bond_type", "neutral")).capitalize(),
			"impression": impression_by_other.get(str(bond.get("other_id", "")), "")})
	for other_id: String in impression_by_other:
		var exists: bool = relationships.any(func(item: Dictionary) -> bool: return item.name == _echo_name(data, other_id))
		if not exists:
			relationships.append({"name": _echo_name(data, other_id), "tier": 0, "tier_name": "Unformed",
				"bond_type": "Neutral", "impression": impression_by_other[other_id]})
	return {"type": "echo", "name": str(echo.name), "needs": needs, "relationships": relationships}


func _incident_visual(incident: Dictionary, data: Dictionary, place_name: String) -> Dictionary:
	var duration: int = maxi(1, int(incident.get("stage_deadline_ms", 0)) - int(incident.get("stage_started_ms", 0)))
	var ratio: float = clampf(float(incident.get("remaining_ms", 0)) / float(duration), 0.0, 1.0)
	var status: String = str(incident.get("status", "warning"))
	var urgency_label := "Forming"
	if status == "open": urgency_label = "Waiting for a choice"
	elif status == "joined": urgency_label = "Your response is pending"
	elif status == "resolved": urgency_label = "Settled"
	elif ratio < 0.34: urgency_label = "Nearly clear"
	var result: Dictionary = incident.get("result", {})
	var participants: Array[String] = _participant_names(data, incident.get("participants", []))
	var reply_cues: Array = []
	for reply: Dictionary in incident.get("reply_choices", []):
		var cue: Dictionary = reply.get("consequence_cue", {})
		if not cue.is_empty():
			reply_cues.append({"label": str(reply.get("label", "Respond")), "tone": str(cue.get("tone", "quiet")), "text": str(cue.get("text", ""))})
	var people: String = " and ".join(participants)
	var access: String = str(incident.get("keeper_access", "private"))
	var appeal_id: String = str(incident.get("appeal_echo_id", ""))
	var appeal_name: String = _echo_name(data, appeal_id) if not appeal_id.is_empty() else ""
	var access_reason: String = str(incident.get("access_reason", ""))
	if access_reason.is_empty():
		access_reason = str(incident.get("cause", ""))
	var now := "%s are having a hard moment together." % people
	var status_text := "Watching"
	var action := "Nothing to choose yet."
	match status:
		"warning":
			if access == "appeal" and not appeal_name.is_empty():
				status_text = "%s is asking for help" % appeal_name
			elif access == "open":
				status_text = "You can step in soon"
			else:
				status_text = "They are handling this"
			action = "They are still speaking."
		"open":
			if access == "appeal" and not appeal_name.is_empty():
				now = "%s is asking you to join them." % appeal_name
				status_text = "%s is asking for help" % appeal_name
				action = "Answer %s if you want to help." % appeal_name
			elif access == "open":
				now = "%s have left room for you to join them." % people
				status_text = "You can step in"
				action = "Step in if you want to help."
			else:
				now = "%s are working through this themselves." % people
				status_text = "They are handling this"
				action = "They are handling this."
		"joined":
			now = "%s are waiting for your reply." % people
			status_text = "Waiting for the Keeper"
			action = "Choose how to respond."
		"resolved":
			now = str(result.get("aftermath", "They have found a way through it."))
			status_text = "Settled"
	return {"type": "incident", "status": status, "place": place_name, "cause": str(incident.get("cause", "")),
		"urgency_level": clampi(ceili((1.0 - ratio) * 5.0), 1, 5), "urgency_label": urgency_label,
		"participants": participants, "now": now, "why": access_reason,
		"status_text": status_text, "action": action, "reply_cues": reply_cues, "result": _incident_result_visual(result, data),
		"keeper_access": access, "appeal_name": appeal_name, "exchange_lines": _incident_exchange_visual(incident, data)}


func _incident_exchange_visual(incident: Dictionary, data: Dictionary) -> Array:
	var exchange: Array = []
	for line: Dictionary in incident.get("exchange_lines", []):
		var speaker_id: String = str(line.get("speaker_id", ""))
		exchange.append({"speaker": _echo_name(data, speaker_id), "text": str(line.get("text", ""))})
	return exchange


func _incident_result_visual(result: Dictionary, data: Dictionary) -> Dictionary:
	if result.is_empty(): return {}
	var effects: Array = []
	for effect: Dictionary in result.get("participant_effects", []):
		var before: Dictionary = effect.get("before", {})
		var after: Dictionary = effect.get("after", {})
		var changed: Array[String] = []
		for family: String in ["rest", "company", "purpose"]:
			var difference: float = float(after.get(family, 0.0)) - float(before.get(family, 0.0))
			if difference < -0.01: changed.append(_need_name(family) + " eased")
			elif difference > 0.01: changed.append(_need_name(family) + " grew")
		var before_emotion: String = _plain_emotion(str(before.get("emotional_status", "steady")))
		var after_emotion: String = _plain_emotion(str(after.get("emotional_status", before_emotion)))
		effects.append({"id": str(effect.get("echo_id", "")), "portrait_path": _portrait_path(str(effect.get("echo_id", ""))), "name": _echo_name(data, str(effect.get("echo_id", ""))),
			"need_change": ", ".join(changed) if not changed.is_empty() else "Needs held steady",
			"emotion_change": before_emotion + " → " + after_emotion if before_emotion != after_emotion else after_emotion + " held steady"})
	var bond_source: Dictionary = result.get("shared_bond", {})
	var bond: Dictionary = {}
	if not bond_source.is_empty():
		bond = {"before": str(bond_source.get("tier_name_before", "Unformed")), "after": str(bond_source.get("tier_name_after", "Unformed")),
			"direction": "%s → %s" % [str(bond_source.get("bond_type_before", "neutral")).capitalize(), str(bond_source.get("bond_type_after", "neutral")).capitalize()]}
	var views: Array[String] = []
	for view: Dictionary in result.get("participant_views", []):
		views.append("%s, about %s: %s" % [_echo_name(data, str(view.get("echo_id", ""))), _echo_name(data, str(view.get("other_id", ""))), str(view.get("view_of_other", "Their view changed.")).replace("_", " ")])
	var keeper_reactions: Array[String] = []
	for reaction: Dictionary in result.get("keeper_reactions", []):
		keeper_reactions.append("%s: %s" % [_echo_name(data, str(reaction.get("echo_id", ""))), str(reaction.get("reaction", "")).replace("_", " ")])
	var next_behaviors: Array[String] = []
	for behavior: Dictionary in result.get("aftermath_behaviors", []):
		var next_family: String = str(behavior.get("next_intention", {}).get("family", ""))
		var next_text := _display_activity(str(behavior.get("activity", "")))
		if not next_family.is_empty(): next_text += " · then " + _need_name(next_family).to_lower()
		next_behaviors.append("%s: %s" % [_echo_name(data, str(behavior.get("echo_id", ""))), next_text])
	return {"response_label": str(result.get("response", "The moment is answered")).replace("_", " ").capitalize(),
		"aftermath": str(result.get("aftermath", "The moment settles.")), "effects": effects, "bond": bond,
		"participant_views": views, "keeper_reactions": keeper_reactions, "next_behaviors": next_behaviors}


func _find_incident(data: Dictionary, id: String) -> Dictionary:
	for incident: Dictionary in data.get("incidents", []):
		if incident.id == id:
			return incident
	return {}


func _joined_incident_pending(data: Dictionary) -> bool:
	var incident: Dictionary = _find_incident(data, str(data.get("joined_incident_id", "")))
	return not incident.is_empty() and incident.status == "joined"


func _echo_name(data: Dictionary, id: String) -> String:
	for echo: Dictionary in data.get("echoes", []):
		if echo.id == id:
			return str(echo.name)
	return "Unknown Echo"


func _participant_names(data: Dictionary, ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id: String in ids:
		result.append(_echo_name(data, id))
	return result


func _fill_history(panel: Dictionary, history: Array, data: Dictionary, first_person: bool = false) -> void:
	panel.kind = "history"
	panel.subtitle = "Recent moments · this village session"
	panel.history_total = history.size()
	panel.history_pages = maxi(1, ceili(float(history.size()) / HISTORY_PAGE_SIZE))
	_history_page = clampi(_history_page, 0, int(panel.history_pages) - 1)
	panel.history_page = _history_page
	panel.history_entries = history.slice(_history_page * HISTORY_PAGE_SIZE, (_history_page + 1) * HISTORY_PAGE_SIZE).duplicate(true)
	var cards: Array = []
	for item: Dictionary in panel.history_entries:
		if first_person:
			var perspective: String = str(item.get("perspective", ""))
			if perspective.is_empty():
				continue
			cards.append({"type_label": "RECENT", "title": "I REMEMBER", "meta": "", "text": perspective,
				"cause": "", "aftermath": "", "consequences": [], "glyph": "•", "tone": "quiet",
				"people": "", "badge": "", "changes": []})
			continue
		var place_name: String = data.places.get(item.place, {}).get("name", "Village path")
		var names: Array[String] = _participant_names(data, item.get("participants", []))
		var title: String = _history_headline(item, names)
		var meta: String = _history_time(item) + " · " + place_name
		var consequences: Array[String] = []
		for effect: Dictionary in item.get("participant_effects", []):
			var visual: Dictionary = _incident_result_visual({"participant_effects": [effect]}, data)
			if not visual.effects.is_empty(): consequences.append("%s · %s · %s" % [visual.effects[0].name, visual.effects[0].need_change, visual.effects[0].emotion_change])
		for impression: Dictionary in item.get("impression_changes", []):
			consequences.append(_impression_text(impression, data))
		var bond: Dictionary = item.get("shared_bond", {})
		if not bond.is_empty():
			consequences.push_front("Relationship: %s → %s" % [str(bond.get("tier_name_before", "Unformed")), str(bond.get("tier_name_after", "Unformed"))])
		var arrival_memory: Dictionary = item.get("arrival_memory", {})
		if not arrival_memory.is_empty():
			var welcome: Dictionary = arrival_memory.get("welcome", {})
			var first: Dictionary = arrival_memory.get("first_intention", {})
			if not welcome.is_empty(): consequences.push_front("Welcome: " + str(welcome.get("result", "A place was made.")))
			if not first.is_empty(): consequences.append("First way: " + str(data.places.get(first.get("place", ""), {}).get("name", "a village path")))
		cards.append({"type_label": str(item.get("kind", "village moment")).replace("_", " ").to_upper(), "title": title,
			"meta": meta, "text": str(item.get("text", "")), "cause": str(item.get("cause", "")),
			"aftermath": str(item.get("aftermath", "")).capitalize(), "consequences": consequences.slice(0, 2),
			"glyph": _history_glyph(str(item.get("kind", ""))), "tone": _history_tone(str(item.get("kind", ""))),
			"people": " & ".join(names), "badge": _history_badge(item), "changes": consequences.slice(0, 2)})
	panel.body = "No remembered activity here yet." if cards.is_empty() else ""
	panel.visual = {"type": "history", "cards": cards}


func _history_headline(item: Dictionary, names: Array[String]) -> String:
	var people := " and ".join(names)
	match str(item.get("kind", "")):
		"social_exchange": return (people + " spent time together.") if not people.is_empty() else "A shared moment stayed with them."
		"incident_warning": return (people + " began to clash.") if not people.is_empty() else "A difficult moment started."
		"incident_open": return (people + " needed a response.") if not people.is_empty() else "A difficult moment needed a response."
		"incident_resolved": return "They found a way through it."
		"newcomer_arrival": return (people + " found a first place in the village.") if not people.is_empty() else "A newcomer found a first place."
		"bond_change": return (people + " see each other differently.") if not people.is_empty() else "A relationship shifted."
		"visit": return (people + " spent time here.") if not people.is_empty() else "Someone spent time here."
		_: return str(item.get("title", "A village moment"))


func _history_glyph(kind: String) -> String:
	match kind:
		"social_exchange": return "↔"
		"incident_warning": return "!"
		"incident_open": return "?"
		"incident_resolved": return "✓"
		"newcomer_arrival": return "✦"
		"bond_change": return "↗"
		_: return "•"


func _history_tone(kind: String) -> String:
	if kind in ["incident_warning", "incident_open"]: return "warning"
	if kind == "incident_resolved": return "settled"
	if kind == "newcomer_arrival": return "connection"
	if kind in ["social_exchange", "bond_change"]: return "connection"
	return "quiet"


func _history_badge(item: Dictionary) -> String:
	var kind: String = str(item.get("kind", ""))
	if kind in ["incident_warning", "incident_open", "incident_joined"]: return "UNRESOLVED"
	if not str(item.get("aftermath", "")).is_empty() or kind == "incident_resolved": return "SETTLED"
	if kind == "newcomer_arrival": return "ARRIVED"
	return "REMEMBERED"


func _history_time(item: Dictionary) -> String:
	var first_day: int = int(item.get("first_day", item.get("day", 1)))
	var latest_day: int = int(item.get("latest_day", item.get("day", first_day)))
	var first_phase: String = str(item.get("first_day_phase", item.get("day_phase", "morning"))).capitalize()
	var latest_phase: String = str(item.get("latest_day_phase", item.get("day_phase", first_phase))).capitalize()
	var first: String = "Day %d · %s" % [first_day, first_phase]
	if first_day == latest_day and first_phase == latest_phase:
		return first
	return "%s → Day %d · %s" % [first, latest_day, latest_phase]
