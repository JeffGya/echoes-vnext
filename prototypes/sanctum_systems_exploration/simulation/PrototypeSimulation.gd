extends RefCounted
## Local experiment only. No campaign state, saves, scene tree, or wall-clock time.
## Every mutation is either an accepted command at the current step or a 250 ms step.

const SeedScript = preload("res://core/CampaignSeed.gd")
const ArchetypeScript = preload("res://core/echoes/PersonalityArchetype.gd")
const EmotionScript = preload("res://core/emotion/EmotionService.gd")
const SocialGraphScript = preload("res://core/sanctum/SocialGraphService.gd")
const HOUSE_PATH := "res://prototypes/sanctum_systems_exploration/data/house.json"
const ECHO_PATH := "res://prototypes/sanctum_systems_exploration/data/fixture_echoes.json"
const STEP_MS := 250
const EVENT_LIMIT := 512
const BEAT_LIMIT := 64
const RELEASE_MS := 1500
const ARRIVAL_STAGE_MS := 1000
const FAMILIES: Array[String] = ["rest", "company", "purpose"]
const DAY_PHASES: Array[String] = ["morning", "afternoon", "evening", "night"]
const ARCHETYPE_WEIGHTS := {
	"loyal": {"rest": 0.0, "company": 1.0, "purpose": 2.0},
	"proud": {"rest": -1.0, "company": 0.0, "purpose": 3.0},
	"reflective": {"rest": 2.0, "company": -1.0, "purpose": 1.0},
	"empathic": {"rest": 0.0, "company": 3.0, "purpose": 0.0},
	"canny": {"rest": 0.0, "company": 2.0, "purpose": 1.0},
	"stoic": {"rest": 2.0, "company": -2.0, "purpose": 0.0},
	"valiant": {"rest": -1.0, "company": 0.0, "purpose": 2.0},
	"devout": {"rest": 0.0, "company": 1.0, "purpose": 2.0},
	"ambitious": {"rest": 0.0, "company": 0.0, "purpose": 2.0}
}

var _definition: Dictionary
var _fixtures: Array
var _state: Dictionary = {}


func _init() -> void:
	_definition = JSON.parse_string(FileAccess.get_file_as_string(HOUSE_PATH))
	_fixtures = JSON.parse_string(FileAccess.get_file_as_string(ECHO_PATH))
	reset(int(_definition.default_seed))


func reset(seed_value: int, placements: Dictionary = {}, tuning: Dictionary = {}) -> void:
	_state = {
		"seed": seed_value, "step": 0, "elapsed_ms": 0, "phase": "setup",
		"day": 1, "cycle_elapsed_ms": 0.0, "placements": {},
		"tuning": _definition.tuning.duplicate(true), "echoes": [],
		"conversation": {}, "events": [], "event_serial": 0,
		"beats": [], "beat_serial": 0, "reaction_cues": [], "commands": [],
		"bonds": [], "encounters": [], "encounter_counts": {}, "bond_last_events": {},
		"impressions": [], "cooldowns": {},
		"social_engagements": [], "social_serial": 0, "incidents": [],
		"incident_serial": 0, "joined_incident_id": "",
		"ase": int(_definition.summoning.start_ase), "ase_recovery_days": [],
		"newcomer_order": _newcomer_order(seed_value), "newcomers_consumed": [], "arrival": {},
		"metrics": {"routines": 0, "conversations": 0, "accept": 0,
			"reinterpret": 0, "decline": 0, "repeated": 0, "social_exchanges": 0,
			"warnings": 0, "incidents_resolved": 0, "interventions": 0}
	}
	for key: String in tuning:
		_set_tuning(key, float(tuning[key]))
	for institution: String in placements:
		_place(institution, str(placements[institution]))
	for fixture: Dictionary in _fixtures:
		var echo: Dictionary = fixture.duplicate(true)
		var traits: Dictionary = echo.traits
		echo["archetype"] = ArchetypeScript.from_traits(int(traits.courage), int(traits.wisdom), int(traits.faith))
		var rng: RandomNumberGenerator = _rng("initial.%s" % echo.id)
		echo.merge({"family": "rest", "activity": "idle", "reason": "Finding a place in the village.",
			"destination": "", "path": [], "position": _position(echo.node), "facing": [0.0, 1.0],
			"moving": false, "remaining_ms": rng.randi_range(1, 12) * STEP_MS,
			"duration_ms": 0, "decisions": 0, "candidates": [], "competing_reason": "",
			"exchanges": {}, "last_response": "", "reserved": false, "engagement_id": "",
			"incident_id": "", "behavior": {},
			"emotional_status": _emotional_status(echo)})
		_state.echoes.append(echo)
	_state["initial"] = {"seed": seed_value, "placements": _state.placements.duplicate(true),
		"tuning": _state.tuning.duplicate(true), "ase": _state.ase,
		"newcomer_order": _state.newcomer_order.duplicate()}


func get_step() -> int:
	return int(_state.step)


func is_living() -> bool:
	return _state.phase == "living"


func get_state() -> Dictionary:
	return _state.duplicate(true)


func get_definition() -> Dictionary:
	return _definition.duplicate(true)


func place_node(place_id: String) -> String:
	if not _definition.places.has(place_id):
		return ""
	return str(_state.placements.get(place_id, _definition.places[place_id].node))


func route(from_node: String, to_node: String) -> Array:
	if from_node == to_node or not _definition.waypoints.has(from_node) or not _definition.waypoints.has(to_node):
		return []
	# Shortest authored world-distance path, with lexical tie-breaking.
	var pending: Array = _definition.waypoints.keys()
	pending.sort()
	var distances: Dictionary = {from_node: 0.0}
	var previous: Dictionary = {}
	while not pending.is_empty():
		var current := ""
		var nearest: float = INF
		for candidate: String in pending:
			var candidate_distance: float = float(distances.get(candidate, INF))
			if candidate_distance < nearest:
				nearest = candidate_distance
				current = candidate
		if current.is_empty():
			break
		pending.erase(current)
		if current == to_node:
			var result: Array = []
			while current != from_node:
				result.push_front(current)
				current = str(previous[current])
			return result
		var links: Array = _definition.waypoints[current].links.duplicate()
		links.sort()
		for next_node: String in links:
			var distance: float = nearest + _node_vector(current).distance_to(_node_vector(next_node))
			if distance < float(distances.get(next_node, INF)):
				distances[next_node] = distance
				previous[next_node] = current
	return []


func apply_action(action: Dictionary, t: int) -> bool:
	if t != get_step():
		return false
	var payload: Dictionary = action.get("payload", {})
	var accepted := false
	match str(action.get("type", "")):
		"prototype.house.place":
			accepted = _state.phase == "setup" and _place(str(payload.get("institution", "")), str(payload.get("site", "")))
		"prototype.house.start":
			if _state.phase == "setup" and _state.placements.size() == 2:
				_state.phase = "living"
				accepted = true
		"prototype.tuning.set":
			accepted = _set_tuning(str(payload.get("key", "")), float(payload.get("value", 0)))
		"prototype.conversation.begin":
			var echo: Dictionary = _echo(str(payload.get("echo_id", "")))
			if is_living() and not _arrival_blocks_interactions() and _state.conversation.is_empty() and str(_state.joined_incident_id).is_empty() and not echo.is_empty() and not bool(echo.reserved) and echo.engagement_id.is_empty() and echo.incident_id.is_empty() and echo.behavior.is_empty():
				echo.reserved = true
				_state.conversation = {"echo_id": echo.id, "topic": "", "status": "approaching" if echo.moving else "choosing"}
				if not echo.moving:
					_acknowledge(echo)
				accepted = true
		"prototype.conversation.topic":
			var topic: Dictionary = _topic(str(payload.get("topic", "")))
			if not _state.conversation.is_empty() and _state.conversation.status == "choosing" and not topic.is_empty():
				_state.conversation.topic = topic.id
				accepted = true
		"prototype.conversation.reply":
			accepted = _reply(str(payload.get("reply", "")))
		"prototype.conversation.cancel":
			if not _state.conversation.is_empty() and _state.conversation.status in ["approaching", "choosing"]:
				_release_conversation(false)
				accepted = true
		"prototype.incident.join":
			accepted = _join_incident(str(payload.get("incident_id", "")))
		"prototype.incident.reply":
			accepted = _reply_incident(str(payload.get("incident_id", "")), str(payload.get("reply_id", "")))
		"prototype.incident.defer":
			accepted = _defer_incident(str(payload.get("incident_id", "")))
		"prototype.summon.confirm":
			accepted = _begin_summon_confirmation()
		"prototype.summon.cancel":
			accepted = _cancel_summon_confirmation()
		"prototype.summon.commit":
			accepted = _commit_summon()
		"prototype.summon.welcome":
			accepted = _welcome_newcomer(str(payload.get("welcome_id", "")))
		"prototype.summon.dismiss":
			accepted = _dismiss_arrival()
	if accepted:
		_state.commands.append({"step": t, "order": _state.commands.size(), "action": action.duplicate(true)})
	return accepted


func advance_step(t: int) -> bool:
	if not is_living() or t != get_step() + 1:
		return false
	_state.step = t
	_state.elapsed_ms += STEP_MS
	_state.cycle_elapsed_ms += STEP_MS
	var day_ms: float = float(_state.tuning.day_minutes) * 60000.0
	while float(_state.cycle_elapsed_ms) >= day_ms:
		_state.cycle_elapsed_ms -= day_ms
		_state.day += 1
		_recover_ase_for_day()
	var meaningful := false
	meaningful = _advance_reaction_cues() or meaningful
	meaningful = _advance_arrival() or meaningful
	meaningful = _expire_impressions() or meaningful
	var behavior_releases: Dictionary = _advance_behaviors()
	meaningful = _advance_social_commitments() or meaningful
	meaningful = _advance_incidents() or meaningful
	var released_ids: Dictionary = behavior_releases.duplicate()
	if not _state.conversation.is_empty() and _state.conversation.status == "resolved":
		if int(_state.elapsed_ms) >= int(_state.conversation.release_at_ms):
			released_ids[_state.conversation.echo_id] = {}
			_release_conversation(true)
			meaningful = true
	# Finish everyone's travel first. Decisions then share post-travel occupancy,
	# so fixture ordering cannot make a neighbour arrive "too late" to be noticed.
	var traveled: Dictionary = {}
	for echo: Dictionary in _state.echoes:
		if released_ids.has(echo.id):
			continue
		if echo.reserved:
			if not _state.conversation.is_empty() and _state.conversation.echo_id == echo.id and _state.conversation.status == "approaching":
				meaningful = _travel(echo, true) or meaningful
		elif echo.moving:
			traveled[echo.id] = true
			meaningful = _travel(echo, false) or meaningful
	var occupied: Dictionary = _occupancy()
	for echo: Dictionary in _state.echoes:
		if echo.reserved or released_ids.has(echo.id):
			continue # Waiting/approaching grants neither pressure, relief nor routine progress.
		_update_pressures(echo, float(STEP_MS) / 1000.0, not traveled.has(echo.id) and echo.activity != "idle")
		if not traveled.has(echo.id):
			echo.remaining_ms = maxi(0, int(echo.remaining_ms) - STEP_MS)
	for echo: Dictionary in _state.echoes:
		if behavior_releases.has(echo.id):
			echo.reserved = false
			_choose_after_behavior(echo, occupied, behavior_releases[echo.id])
			meaningful = true
			continue
		if echo.reserved or released_ids.has(echo.id) or traveled.has(echo.id):
			continue
		if int(echo.remaining_ms) == 0:
			if echo.activity != "idle":
				_record_event("routine_completed", echo, "%s finished %s at %s." % [echo.name, echo.activity, _location_name(echo.node)], echo.reason, "Ready to choose what comes next.")
			_choose_intent(echo, occupied)
			meaningful = true
	meaningful = _try_social_exchange() or meaningful
	return meaningful


func build_snapshot_data(debug_enabled: bool = false) -> Dictionary:
	var data: Dictionary = {
		"seed": _state.seed, "step": _state.step, "elapsed_ms": _state.elapsed_ms,
		"step_ms": STEP_MS, "next_beat_steps": 240, "phase": _state.phase, "clock": _clock(),
		"placements": _state.placements.duplicate(true), "tuning": _state.tuning.duplicate(true),
		"echoes": [], "conversation": _state.conversation.duplicate(true),
		"events": _state.events.duplicate(true), "beats": _state.beats.duplicate(true), "beat_serial": _state.beat_serial,
		"reaction_cues": _state.reaction_cues.duplicate(true),
		"metrics": _state.metrics.duplicate(true), "place_history": {},
		"social_engagements": _project_social_engagements(), "bonds": _project_shared_bonds(),
		"incidents": _project_incidents(), "joined_incident_id": _state.joined_incident_id,
		"summoning": _project_summoning(),
		"village_history": _build_village_history(_state.events),
		"places": _definition.places.duplicate(true), "waypoints": _definition.waypoints.duplicate(true),
		"sites": _definition.sites.duplicate(true), "topics": _definition.topics.duplicate(true),
		"tuning_ranges": _definition.tuning_ranges.duplicate(true)
	}
	for id: String in data.places:
		data.places[id].node = place_node(id)
		data.place_history[id] = []
	for source: Dictionary in _state.echoes:
		var echo: Dictionary = source.duplicate(true)
		if not echo.has("portrait"):
			echo["portrait"] = {"bust_id": "%s_mark_%d" % [echo.id, int(echo.mark)],
				"silhouette": "distinct marked Echo", "marking": "Story patch mark %d" % int(echo.mark)}
		echo["needs"] = {}
		for family: String in FAMILIES:
			echo.needs[family] = {"value": source.pressures[family], "max": _definition.rules.pressure_max,
				"label": _need_label(float(source.pressures[family])),
				"display_name": "Something to do" if family == "purpose" else family.capitalize()}
		echo["emotional_status_label"] = _emotion_display(str(source.emotional_status))
		echo["current"] = _current_voice(source)
		echo["reaction_cues"] = _reaction_cues_for(source.id)
		echo["witness_memories"] = _witness_memories_for(source.id)
		echo["recent_memories"] = _personal_memories_for(source.id)
		echo["history"] = []
		echo["bonds"] = _project_echo_bonds(source.id)
		echo["impressions"] = _impressions_for(source.id)
		if not debug_enabled:
			for key: String in ["fear", "morale", "pressures", "bias", "preferences", "sociability", "candidates", "competing_reason", "exchanges", "decisions", "duration_ms"]:
				echo.erase(key)
		data.echoes.append(echo)
	var histories: Dictionary = _build_visit_histories(_state.events)
	for echo: Dictionary in data.echoes:
		echo.history = histories.echoes.get(echo.id, []).duplicate(true)
		echo["recent"] = _recent_voice(echo.get("witness_memories", []) + echo.get("recent_memories", []), echo.history)
	for place: String in data.place_history:
		data.place_history[place] = histories.places.get(place, []).duplicate(true)
	if debug_enabled:
		data["commands"] = _state.commands.duplicate(true)
		data["initial"] = _state.initial.duplicate(true)
	return data


func _build_visit_histories(events: Array) -> Dictionary:
	# Projection only: raw enacted events remain authoritative and untouched.
	var echo_histories: Dictionary = {}
	var open_visits: Dictionary = {}
	var auxiliaries: Dictionary = _history_auxiliaries(events)
	for event: Dictionary in events:
		if _is_history_auxiliary(event):
			continue
		for echo_id: String in event.participants:
			if not echo_histories.has(echo_id):
				echo_histories[echo_id] = []
			if event.kind in ["arrival", "activity_started", "routine_completed"]:
				var visit: Dictionary = open_visits.get(echo_id, {})
				if visit.is_empty() or visit.place != event.place:
					visit = _new_history_summary(event, "visit", echo_id)
					echo_histories[echo_id].append(visit)
					open_visits[echo_id] = visit
				else:
					_extend_visit_summary(visit, event)
			else:
				# Keeper responses and later significant records remain visible on their own.
				var standalone: Dictionary = _new_history_summary(event, str(event.kind), echo_id)
				_fold_history_auxiliaries(standalone, auxiliaries.get(event.id, []))
				echo_histories[echo_id].append(standalone)
	var place_histories: Dictionary = {}
	var place_source_ids: Dictionary = {}
	for echo_id: String in echo_histories:
		var summaries: Array = echo_histories[echo_id]
		summaries.sort_custom(_history_newest_first)
		for summary: Dictionary in summaries:
			var place: String = str(summary.place)
			if place.is_empty():
				continue
			if not place_histories.has(place):
				place_histories[place] = []
				place_source_ids[place] = {}
			# Shared social/incident summaries appear once in a place view, even
			# though the same value belongs in every participant's personal view.
			if place_source_ids[place].has(summary.id):
				continue
			place_histories[place].append(summary.duplicate(true))
			place_source_ids[place][summary.id] = true
	for place: String in place_histories:
		place_histories[place].sort_custom(_history_newest_first)
	return {"echoes": echo_histories, "places": place_histories}


func _new_history_summary(event: Dictionary, kind: String, echo_id: String) -> Dictionary:
	# A retained completion may be the first surviving record after history pruning;
	# it still proves one actual activity occurred during this visit.
	var activity_count := 1 if kind == "visit" else 0
	var summary: Dictionary = event.duplicate(true)
	summary.merge({"kind": kind,
		"participants": [echo_id] if kind == "visit" else event.participants.duplicate(),
		"source_ids": [event.id], "source_count": 1, "activity_count": activity_count,
		"first_step": event.step, "first_elapsed_ms": event.elapsed_ms,
		"first_day": event.day, "first_day_phase": event.day_phase,
		"latest_step": event.step, "latest_elapsed_ms": event.elapsed_ms,
		"latest_day": event.day, "latest_day_phase": event.day_phase}, true)
	return summary


func _history_auxiliaries(events: Array) -> Dictionary:
	var result: Dictionary = {}
	for event: Dictionary in events:
		if not _is_history_auxiliary(event):
			continue
		var source_id: int = int(event.source_event_id)
		if not result.has(source_id):
			result[source_id] = []
		result[source_id].append(event)
	return result


func _is_history_auxiliary(event: Dictionary) -> bool:
	return event.kind in ["impression", "emotion_change", "bond_change"] and event.has("source_event_id")


func _fold_history_auxiliaries(summary: Dictionary, auxiliaries: Array) -> void:
	for event: Dictionary in auxiliaries:
		summary.source_ids.append(event.id)
		summary.source_count = summary.source_ids.size()
		summary.id = event.id
		summary.latest_step = event.step
		summary.latest_elapsed_ms = event.elapsed_ms
		summary.latest_day = event.day
		summary.latest_day_phase = event.day_phase
		summary.step = event.step
		summary.elapsed_ms = event.elapsed_ms
		summary.day = event.day
		summary.day_phase = event.day_phase


func _extend_visit_summary(summary: Dictionary, event: Dictionary) -> void:
	summary.id = event.id
	summary.source_ids.append(event.id)
	summary.source_count = summary.source_ids.size()
	if event.kind in ["arrival", "activity_started"]:
		summary.activity_count += 1
	summary.text = event.text
	summary.cause = event.cause
	summary.aftermath = event.aftermath
	summary.significant = bool(summary.significant) or bool(event.significant)
	summary.latest_step = event.step
	summary.latest_elapsed_ms = event.elapsed_ms
	summary.latest_day = event.day
	summary.latest_day_phase = event.day_phase
	summary.step = event.step
	summary.elapsed_ms = event.elapsed_ms
	summary.day = event.day
	summary.day_phase = event.day_phase


func _history_newest_first(a: Dictionary, b: Dictionary) -> bool:
	if int(a.latest_step) == int(b.latest_step):
		return int(a.id) > int(b.id)
	return int(a.latest_step) > int(b.latest_step)


func _place(institution: String, site: String) -> bool:
	for candidate: Dictionary in _definition.sites:
		if candidate.id == site and candidate.institution == institution:
			_state.placements[institution] = site
			return true
	return false


func _set_tuning(key: String, value: float) -> bool:
	if not _definition.tuning_ranges.has(key) or not is_finite(value):
		return false
	var bounds: Array = _definition.tuning_ranges[key]
	var result: float = snappedf(clampf(value, float(bounds[0]), float(bounds[1])), float(bounds[2]))
	if key == "day_minutes":
		_state.cycle_elapsed_ms = float(_state.cycle_elapsed_ms) * result / float(_state.tuning.day_minutes)
	_state.tuning[key] = result
	return true


func _echo(id: String) -> Dictionary:
	for echo: Dictionary in _state.echoes:
		if echo.id == id:
			return echo
	return {}


func _topic(id: String) -> Dictionary:
	for topic: Dictionary in _definition.topics:
		if topic.id == id:
			return topic
	return {}


func _rng(path: String) -> RandomNumberGenerator:
	return SeedScript.new(int(_state.seed)).get_rng("prototype.sanctum." + path)


func _reaction_voice(section: String, id: String) -> Dictionary:
	return _definition.get("reaction_voice", {}).get(section, {}).get(id, {}).duplicate(true)


func _format_voice(text: String, values: Dictionary) -> String:
	var result := text
	for key: String in values:
		result = result.replace("{%s}" % key, str(values[key]))
	return result


func _add_reaction_cue(echo_id: String, target_id: String, authored: Dictionary, duration_ms: int = 0) -> Dictionary:
	var kind: String = str(authored.get("kind", ""))
	var motion: String = str(authored.get("motion", ""))
	if kind not in ["welcomed", "appreciative", "uncomfortable", "crowded", "challenged", "hurt"] or motion not in ["closer", "acknowledge", "angle_away", "step_back", "square_up", "withdraw"]:
		return {}
	var duration: int = duration_ms if duration_ms > 0 else int(_definition.get("reaction_voice", {}).get("cue_duration_ms", 2000))
	var cue: Dictionary = {"echo_id": echo_id, "kind": kind, "target_id": target_id,
		"motion": motion, "started_ms": int(_state.elapsed_ms), "duration_ms": maxi(STEP_MS, duration)}
	_state.reaction_cues.append(cue)
	return cue.duplicate(true)


func _advance_reaction_cues() -> bool:
	var expired: Array = []
	for cue: Dictionary in _state.reaction_cues:
		if int(cue.started_ms) + int(cue.duration_ms) <= int(_state.elapsed_ms):
			expired.append(cue)
	for cue: Dictionary in expired:
		_state.reaction_cues.erase(cue)
	# Presentation cleanup must not stop the next meaningful simulation beat.
	return false


func _reaction_cues_for(echo_id: String) -> Array:
	var result: Array = []
	for cue: Dictionary in _state.reaction_cues:
		if str(cue.echo_id) == echo_id:
			result.append(cue.duplicate(true))
	return result


func _current_voice(echo: Dictionary) -> String:
	if bool(echo.moving):
		var destination: String = str(echo.destination)
		return "I am heading to %s." % str(_definition.places.get(destination, {}).get("name", "the village path"))
	if not echo.behavior.is_empty():
		return "I am %s." % str(echo.activity)
	var dialogue: Dictionary = echo.get("dialogue", {})
	return str(dialogue.get("activity", dialogue.get("feelings", "I am taking in the village.")))


func _recent_voice(witness_memories: Array, history: Array) -> String:
	var memories: Array = witness_memories.duplicate(true)
	memories.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("elapsed_ms", 0)) == int(b.get("elapsed_ms", 0)):
			return int(a.get("source_event_id", 0)) > int(b.get("source_event_id", 0))
		return int(a.get("elapsed_ms", 0)) > int(b.get("elapsed_ms", 0)))
	if not memories.is_empty():
		return str(memories[0].get("perspective", ""))
	for summary: Dictionary in history:
		var fallback: String = str(summary.get("personal_memory", ""))
		if not fallback.is_empty():
			return fallback
	return ""


func _witness_memories_for(echo_id: String) -> Array:
	var result: Array = []
	for index: int in range(_state.events.size() - 1, -1, -1):
		var event: Dictionary = _state.events[index]
		if event.kind != "social_exchange":
			continue
		for witness: Dictionary in event.get("witnesses", []):
			if str(witness.get("echo_id", "")) == echo_id:
				result.append({"source_event_id": event.id, "elapsed_ms": event.elapsed_ms,
					"role": witness.get("role", "watch"), "target_id": witness.get("target_id", ""),
					"perspective": witness.get("perspective", "")})
	return result


func _personal_memories_for(echo_id: String) -> Array:
	var result: Array = []
	for index: int in range(_state.events.size() - 1, -1, -1):
		var event: Dictionary = _state.events[index]
		var perspective: String = str(event.get("personal_memories", {}).get(echo_id, ""))
		if not perspective.is_empty():
			result.append({"source_event_id": event.id, "elapsed_ms": event.elapsed_ms, "perspective": perspective})
	return result


func _newcomer_order(seed_value: int) -> Array:
	var order: Array = []
	for newcomer: Dictionary in _definition.summoning.newcomers:
		order.append(str(newcomer.id))
	order.sort()
	var rng: RandomNumberGenerator = SeedScript.get_rng_from(seed_value, "prototype.sanctum.summoning.newcomer_order")
	for index: int in range(order.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var swapped: String = order[index]
		order[index] = order[swap_index]
		order[swap_index] = swapped
	return order


func _newcomer_definition(id: String) -> Dictionary:
	for newcomer: Dictionary in _definition.summoning.newcomers:
		if newcomer.id == id:
			return newcomer.duplicate(true)
	return {}


func _arrival_blocks_interactions() -> bool:
	return not _state.arrival.is_empty() and str(_state.arrival.get("stage", "")) != "complete"


func _has_pending_incident_result() -> bool:
	for incident: Dictionary in _state.incidents:
		if incident.status == "resolved":
			return true
	return false


func _next_newcomer_id() -> String:
	for id: String in _state.newcomer_order:
		if not _state.newcomers_consumed.has(id):
			return id
	return ""


func _recover_ase_for_day() -> void:
	var before: int = int(_state.ase)
	_state.ase = mini(int(_definition.summoning.ase_cap), before + int(_definition.summoning.ase_per_day))
	_state.ase_recovery_days.append(_state.day)


func _begin_summon_confirmation() -> bool:
	if not is_living() or _has_pending_incident_result() or _arrival_blocks_interactions() or _state.echoes.size() >= int(_definition.summoning.max_population):
		return false
	if int(_state.ase) < int(_definition.summoning.cost) or _next_newcomer_id().is_empty():
		return false
	_state.arrival = {"stage": "confirming", "started_ms": _state.elapsed_ms}
	return true


func _cancel_summon_confirmation() -> bool:
	if str(_state.arrival.get("stage", "")) != "confirming":
		return false
	_state.arrival = {}
	return true


func _commit_summon() -> bool:
	if str(_state.arrival.get("stage", "")) != "confirming" or _has_pending_incident_result():
		return false
	var newcomer_id: String = _next_newcomer_id()
	var newcomer: Dictionary = _newcomer_definition(newcomer_id)
	var cost: int = int(_definition.summoning.cost)
	if newcomer.is_empty() or _state.echoes.size() >= int(_definition.summoning.max_population) or int(_state.ase) < cost:
		return false
	_state.ase -= cost
	_state.newcomers_consumed.append(newcomer_id)
	_state.arrival = {"id": "arrival.%d" % (_state.newcomers_consumed.size()), "stage": "approach",
		"started_ms": _state.elapsed_ms, "stage_started_ms": _state.elapsed_ms,
		"newcomer_id": newcomer_id, "newcomer": newcomer, "witnesses": _arrival_witnesses(newcomer_id),
		"welcome_choices": _definition.summoning.welcome_choices.duplicate(true), "welcome": {}, "first_intention": {}}
	return true


func _arrival_witnesses(newcomer_id: String) -> Array:
	var witnesses: Array = []
	var newcomer: Dictionary = _newcomer_definition(newcomer_id)
	var witness_reactions: Dictionary = _definition.get("reaction_voice", {}).get("summoning", {}).get("witness_reactions", {})
	var candidates: Array = _state.echoes.duplicate()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for echo: Dictionary in candidates:
		var response := "watch"
		if not echo.moving and not echo.reserved and float(echo.sociability) >= 0.2 and float(echo.pressures.rest) < 14.0:
			response = "approach"
		elif float(echo.sociability) < -0.4 or float(echo.pressures.rest) >= 16.0 or echo.reserved:
			response = "avoid"
		var route_to_flame: Array = route(echo.node, place_node("flame")) if response == "approach" else []
		var reaction: Dictionary = witness_reactions.get(response, {}).duplicate(true)
		var perspective: String = _format_voice(str(reaction.get("perspective", "")), {"newcomer": newcomer.get("name", "the return")})
		reaction.erase("perspective")
		witnesses.append({"echo_id": echo.id, "response": response, "from_node": echo.node,
			"route": route_to_flame, "reason": "They are available to welcome someone." if response == "approach" else "They keep watch from where they are." if response == "watch" else "They need space from the gathering.",
			"reaction": reaction, "perspective": perspective})
		if witnesses.size() == 3:
			break
	return witnesses


func _advance_arrival() -> bool:
	if _state.arrival.is_empty() or str(_state.arrival.get("stage", "")) in ["confirming", "welcome", "travel", "complete"]:
		return false
	if int(_state.elapsed_ms) - int(_state.arrival.stage_started_ms) < ARRIVAL_STAGE_MS:
		return false
	match str(_state.arrival.stage):
		"approach": _set_arrival_stage("gather")
		"gather": _set_arrival_stage("perform")
		"perform":
			_manifest_newcomer()
			_set_arrival_stage("welcome")
	return true


func _set_arrival_stage(stage: String) -> void:
	_state.arrival.stage = stage
	_state.arrival.stage_started_ms = _state.elapsed_ms


func _manifest_newcomer() -> void:
	var newcomer: Dictionary = _state.arrival.newcomer.duplicate(true)
	newcomer.node = place_node("flame")
	newcomer["archetype"] = ArchetypeScript.from_traits(int(newcomer.traits.courage), int(newcomer.traits.wisdom), int(newcomer.traits.faith))
	newcomer.merge({"family": "rest", "activity": "waiting at the Flame", "reason": "Arriving in the village.",
		"destination": "", "path": [], "position": _position(newcomer.node), "facing": [0.0, 1.0],
		"moving": false, "remaining_ms": 0, "duration_ms": 0, "decisions": 0, "candidates": [], "competing_reason": "",
		"exchanges": {}, "last_response": "", "reserved": true, "engagement_id": "", "incident_id": "", "behavior": {},
		"arrival_id": _state.arrival.id, "emotional_status": _emotional_status(newcomer)}, true)
	_state.echoes.append(newcomer)
	_state.arrival.newcomer_id = newcomer.id
	_state.arrival.manifested_ms = _state.elapsed_ms
	for witness: Dictionary in _state.arrival.witnesses:
		_add_reaction_cue(str(witness.echo_id), newcomer.id, witness.get("reaction", {}))
	var live_text: String = _format_voice(str(_definition.get("reaction_voice", {}).get("summoning", {}).get("manifest_live", "{newcomer} steps from the Flame.")), {"newcomer": newcomer.name})
	_emit("arrival_manifested", newcomer, {"participants": [newcomer.id], "place": "flame", "text": live_text})


func _welcome_newcomer(welcome_id: String) -> bool:
	if str(_state.arrival.get("stage", "")) != "welcome":
		return false
	var choice: Dictionary = {}
	for candidate: Dictionary in _state.arrival.welcome_choices:
		if candidate.id == welcome_id:
			choice = candidate
	if choice.is_empty():
		return false
	var newcomer: Dictionary = _echo(str(_state.arrival.newcomer_id))
	if newcomer.is_empty():
		return false
	_state.arrival.welcome = choice.duplicate(true)
	_state.arrival.welcome["chosen_ms"] = _state.elapsed_ms
	_add_reaction_cue(newcomer.id, "flame", choice.get("reaction_cue", {}))
	var intention: Dictionary = _choose_first_intention(newcomer, choice)
	_state.arrival.first_intention = intention.duplicate(true)
	newcomer.reserved = false
	newcomer.destination = intention.place
	newcomer.family = str(intention.family)
	newcomer.reason = str(intention.cause)
	newcomer.path = route(newcomer.node, place_node(newcomer.destination))
	newcomer.moving = not newcomer.path.is_empty()
	newcomer.activity = "heading to %s" % _location_name(place_node(newcomer.destination))
	newcomer.remaining_ms = 0
	_set_arrival_stage("travel")
	_emit("arrival_welcome", newcomer, {"participants": [newcomer.id], "place": "flame",
		"text": _format_voice(str(choice.get("live_text", "{newcomer} accepts the welcome.")), {"newcomer": newcomer.name})})
	if not newcomer.moving:
		_complete_first_arrival(newcomer)
	return true


func _choose_first_intention(newcomer: Dictionary, choice: Dictionary) -> Dictionary:
	var options: Array = newcomer.arrival_options.duplicate(true)
	var rng: RandomNumberGenerator = _rng("arrival.%s.%s.first_intention" % [_state.arrival.id, choice.id])
	var option: Dictionary = options[rng.randi_range(0, options.size() - 1)]
	var place: String = str(option.get("place", "quiet"))
	var target_id: String = str(option.get("target_id", ""))
	if str(option.get("kind", "")) == "person":
		var target: Dictionary = _echo(target_id)
		if not target.is_empty():
			place = _place_at(target.node)
		else:
			place = "hearth"
	return {"kind": str(option.kind), "target_id": target_id, "place": place,
		"family": str(option.family), "cause": str(option.cause), "route": route(place_node("flame"), place_node(place))}


func _complete_first_arrival(newcomer: Dictionary) -> void:
	if str(_state.arrival.get("stage", "")) != "travel" or newcomer.get("arrival_id", "") != _state.arrival.get("id", ""):
		return
	var memory: Dictionary = {"newcomer_id": newcomer.id, "manifested_ms": _state.arrival.manifested_ms,
		"witnesses": _state.arrival.witnesses.duplicate(true), "welcome": _state.arrival.welcome.duplicate(true),
		"first_intention": _state.arrival.first_intention.duplicate(true), "arrival_node": newcomer.node}
	var arrival_history: String = _format_voice(str(_definition.get("reaction_voice", {}).get("summoning", {}).get("arrival_history", "{newcomer} reached {place}.")), {"newcomer": newcomer.name, "place": _location_name(newcomer.node)})
	_record_event("newcomer_arrival", newcomer, arrival_history,
		str(_state.arrival.first_intention.cause), "Their first arrival is remembered by the village.", true,
		{"title": "%s's first arrival" % newcomer.name, "arrival_memory": memory,
			"personal_memories": {newcomer.id: str(_state.arrival.welcome.get("memory", ""))}})
	_state.arrival.stage = "complete"
	_state.arrival.completed_ms = _state.elapsed_ms
	newcomer.erase("arrival_id")


func _dismiss_arrival() -> bool:
	if str(_state.arrival.get("stage", "")) != "complete":
		return false
	_state.arrival = {}
	return true


func _project_summoning() -> Dictionary:
	var arrival: Dictionary = _state.arrival.duplicate(true)
	if arrival.has("newcomer"):
		arrival.newcomer.erase("pressures")
		arrival.newcomer.erase("bias")
		arrival.newcomer.erase("preferences")
	var stage: String = str(arrival.get("stage", ""))
	var available: bool = is_living() and not _has_pending_incident_result() and not _arrival_blocks_interactions() and _state.echoes.size() < int(_definition.summoning.max_population) and int(_state.ase) >= int(_definition.summoning.cost) and not _next_newcomer_id().is_empty()
	var actions: Dictionary = {}
	if available:
		actions["confirm"] = {"type": "prototype.summon.confirm"}
	if stage == "confirming":
		actions["commit"] = {"type": "prototype.summon.commit"}
		actions["cancel"] = {"type": "prototype.summon.cancel"}
	if stage == "welcome":
		actions["welcome"] = {"type": "prototype.summon.welcome"}
	if stage == "complete":
		actions["dismiss"] = {"type": "prototype.summon.dismiss"}
	return {"ase": _state.ase, "ase_cap": _definition.summoning.ase_cap, "cost": _definition.summoning.cost,
		"flame_state": "committing" if _arrival_blocks_interactions() else "ready" if available else "recovering" if int(_state.ase) < int(_definition.summoning.cost) else "unavailable",
		"newcomer_order": _state.newcomer_order.duplicate(), "consumed_ids": _state.newcomers_consumed.duplicate(),
		"remaining": int(_definition.summoning.max_population) - _state.echoes.size(), "arrival": arrival, "actions": actions}


func _position(node_id: String) -> Array:
	return _definition.waypoints[node_id].pos.duplicate()


func _node_vector(node_id: String) -> Vector2:
	var pos: Array = _definition.waypoints[node_id].pos
	return Vector2(float(pos[0]), float(pos[1]))


func _clock() -> Dictionary:
	var progress: float = float(_state.cycle_elapsed_ms) / (float(_state.tuning.day_minutes) * 60000.0)
	var phase_index: int = mini(3, int(progress * 4.0))
	return {"day": _state.day, "phase": DAY_PHASES[phase_index], "progress": progress,
		"phase_progress": progress * 4.0 - phase_index, "day_minutes": _state.tuning.day_minutes}


func _emotional_status(echo: Dictionary) -> String:
	return EmotionScript.get_emotional_status(int(echo.morale), int(echo.fear))


func _emotion_display(status: String) -> String:
	match status:
		"radiant": return "bright and hopeful"
		"whole": return "at ease"
		"grounded": return "steady"
		"uncertain": return "unsure"
		"hesitant": return "holding back"
		"burdened": return "carrying a lot"
		"pressed": return "under strain"
		"strained": return "worn thin"
		"fraying": return "close to breaking"
		"hollow": return "empty and exhausted"
	return "unsure"


func _occupancy() -> Dictionary:
	var occupied: Dictionary = {}
	for echo: Dictionary in _state.echoes:
		if not echo.moving:
			occupied[echo.node] = int(occupied.get(echo.node, 0)) + 1
	return occupied


func _update_pressures(echo: Dictionary, seconds: float, active: bool) -> void:
	for family: String in FAMILIES:
		var rate: float = float(_definition.rules.pressure_gain_per_second)
		if active and echo.family == family:
			rate = -float(_definition.rules.pressure_relief_per_second)
		echo.pressures[family] = clampf(float(echo.pressures[family]) + rate * seconds, 0.0, float(_definition.rules.pressure_max))


func _need_label(value: float) -> String:
	if value >= 16.0:
		return "Strong"
	if value >= 12.0:
		return "Pressing"
	if value >= 5.0:
		return "Building"
	return "Low"


func _choose_intent(echo: Dictionary, occupied: Dictionary, reason_prefix: String = "") -> void:
	var candidates: Array[Dictionary] = []
	var rng: RandomNumberGenerator = _rng("intent.%s.%d" % [echo.id, echo.decisions])
	for family: String in FAMILIES:
		var candidate: Dictionary = _candidate(echo, family, occupied)
		candidate.score += rng.randf_range(0.0, 0.25)
		candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	var chosen: Dictionary = candidates[0]
	echo.candidates = candidates
	echo.competing_reason = candidates[1].reason
	_commit_intent(echo, chosen, reason_prefix)


func _choose_after_behavior(echo: Dictionary, occupied: Dictionary, behavior: Dictionary) -> void:
	var family: String = str(behavior.next_intention.get("family", "autonomous"))
	var reason_prefix := "After %s" % str(behavior.activity)
	if family == "autonomous":
		_choose_intent(echo, occupied, reason_prefix)
		return
	var chosen: Dictionary = _candidate(echo, family, occupied)
	echo.candidates = [chosen]
	echo.competing_reason = ""
	_commit_intent(echo, chosen, reason_prefix)


func _commit_intent(echo: Dictionary, chosen: Dictionary, reason_prefix: String = "") -> void:
	echo.family = chosen.family
	echo.destination = chosen.place
	echo.reason = "%s; %s" % [reason_prefix, chosen.reason] if not reason_prefix.is_empty() else chosen.reason
	echo.path = route(echo.node, place_node(chosen.place))
	echo.decisions += 1
	echo.duration_ms = _duration_ms(echo)
	echo.remaining_ms = 0
	echo.moving = not echo.path.is_empty()
	echo.activity = "roaming" if echo.moving else _activity(echo)
	_state.metrics.routines += 1
	_emit("routine", echo, {"text": chosen.reason, "destination": chosen.place, "path": [echo.node] + echo.path.duplicate()})
	if not echo.moving:
		echo.remaining_ms = echo.duration_ms
		_record_event("activity_started", echo, "%s began %s at %s." % [echo.name, echo.activity, _location_name(echo.node)], echo.reason, echo.activity)


func _duration_ms(echo: Dictionary) -> int:
	var rng: RandomNumberGenerator = _rng("duration.%s.%d" % [echo.id, echo.decisions])
	# Faith contributes at most ±5% persistence, distinct from seeded ±20% variation.
	var persistence: float = clampf((float(echo.traits.faith) - 50.0) / 400.0, -0.05, 0.05)
	return maxi(STEP_MS, int(round(float(_state.tuning.routine_seconds) * 1000.0 * (rng.randf_range(0.8, 1.2) + persistence) / STEP_MS)) * STEP_MS)


func _candidate(echo: Dictionary, family: String, occupied: Dictionary) -> Dictionary:
	var choices: Array = echo.preferences[family]
	var chosen_place: String = choices[0]
	var best_place_score: float = -INF
	var place_factors: Array = []
	for index: int in range(choices.size()):
		var place: String = choices[index]
		var node_id: String = place_node(place)
		if node_id.is_empty():
			continue
		var others: int = int(occupied.get(node_id, 0)) - (1 if not echo.moving and echo.node == node_id else 0)
		var preference: float = float(choices.size() - index) * float(_definition.rules.preference_score)
		var crowd: float = others * float(_definition.rules.crowd_score) * (float(echo.sociability) if family != "rest" else -1.0)
		var distance := 0.0
		var previous: String = echo.node
		for waypoint: String in route(echo.node, node_id):
			distance += _node_vector(previous).distance_to(_node_vector(waypoint))
			previous = waypoint
		var wisdom: float = (float(echo.traits.wisdom) - 50.0) * 0.06 if place in ["quiet", "flame"] else 0.0
		var faith: float = (float(echo.traits.faith) - 50.0) * 0.06 if place == "flame" else 0.0
		var score: float = preference + crowd - distance * 0.08 + wisdom + faith
		if score > best_place_score:
			best_place_score = score
			chosen_place = place
			place_factors = [
				_factor("preference", preference, "%s is a familiar preference" % _definition.places[place].name),
				_factor("occupancy", crowd, "The company already here suits this intention" if family != "rest" else "Space away from others suits rest"),
				_factor("distance", -distance * 0.08, "The walk takes time"),
				_factor("wisdom_place", wisdom, "Wisdom draws attention to a quieter place"),
				_factor("faith_place", faith, "Faith draws attention to the Ase Flame")]
	var factors: Array = _family_factors(echo, family)
	factors.append_array(place_factors)
	var total := 0.0
	for factor: Dictionary in factors:
		total += float(factor.score)
	var strongest: Dictionary = factors[0]
	for factor: Dictionary in factors:
		if float(factor.score) > float(strongest.score):
			strongest = factor
	var reason: String = "%s; choosing %s." % [strongest.reason, _definition.places[chosen_place].name]
	return {"family": family, "place": chosen_place, "score": total, "reason": reason, "factors": factors}


func _family_factors(echo: Dictionary, family: String) -> Array:
	var courage: float = float(echo.traits.courage) - 50.0
	var wisdom: float = float(echo.traits.wisdom) - 50.0
	var faith: float = float(echo.traits.faith) - 50.0
	var c_score: float = courage * (0.10 if family == "purpose" else -0.08 if family == "rest" else 0.0)
	var w_score: float = wisdom * (0.08 if family in ["rest", "purpose"] else -0.04)
	var f_score: float = faith * (0.10 if family == "company" else 0.06 if family == "purpose" else 0.0)
	var emotion_score := 0.0
	var emotion_reason := ""
	if family == "rest":
		emotion_score = float(echo.fear) * float(_definition.rules.emotion_score)
		emotion_reason = "Feeling %s makes a little safety appealing" % echo.emotional_status
	elif family == "purpose":
		emotion_score = float(echo.morale) * float(_definition.rules.emotion_score)
		emotion_reason = "Current morale supports following a purpose"
	var phase: String = _clock().phase
	var phase_score := 0.0
	if (phase == "morning" and family == "purpose") or (phase == "evening" and family == "company") or (phase == "night" and family == "rest"):
		phase_score = 2.0
	var impression_score: float = _need_impression_influence(echo.id, family)
	return [
		_factor("need", float(echo.pressures[family]) * float(_state.tuning[family + "_weight"]), "%s need is %s" % [family.capitalize(), _need_label(float(echo.pressures[family])).to_lower()]),
		_factor("preference_family", float(echo.bias[family]), "A familiar inclination toward %s matters" % family),
		_factor("courage", c_score, "Courage shapes the wish for %s" % family),
		_factor("wisdom", w_score, "Wisdom shapes the wish for %s" % family),
		_factor("faith", f_score, "Faith shapes the wish for %s" % family),
		_factor("archetype", float(ARCHETYPE_WEIGHTS[echo.archetype][family]), "A %s disposition favors %s" % [echo.archetype, family]),
		_factor("emotion", emotion_score, emotion_reason),
		_factor("day_phase", phase_score, "%s lends itself to %s" % [phase.capitalize(), family]),
		_factor("impression", impression_score, "Recent encounters shape the wish for %s" % family)]


func _factor(source: String, score: float, reason: String) -> Dictionary:
	return {"source": source, "score": score, "reason": reason}


func _travel(echo: Dictionary, approaching: bool) -> bool:
	var budget: float = float(_definition.rules.travel_units_per_second) * float(STEP_MS) / 1000.0
	var meaningful := false
	while budget > 0.0 and not echo.path.is_empty():
		var next_node: String = echo.path[0]
		var current := Vector2(float(echo.position[0]), float(echo.position[1]))
		var target: Vector2 = _node_vector(next_node)
		var direction: Vector2 = current.direction_to(target)
		var distance: float = current.distance_to(target)
		echo.facing = [direction.x, direction.y]
		if distance > budget + 0.000001:
			var next_position: Vector2 = current + direction * budget
			echo.position = [next_position.x, next_position.y]
			break
		budget -= distance
		echo.node = next_node
		echo.position = _position(next_node)
		echo.path.pop_front()
		if echo.path.is_empty():
			echo.moving = false
			_arrive(echo)
			meaningful = true
		if approaching:
			echo.moving = false
			_state.conversation.status = "choosing"
			_acknowledge(echo)
			return true
	return meaningful


func _arrive(echo: Dictionary) -> void:
	echo.remaining_ms = echo.duration_ms
	echo.activity = _activity(echo)
	var text: String = "%s started %s at %s." % [echo.name, echo.activity, _location_name(echo.node)]
	_record_event("arrival", echo, text, echo.reason, echo.activity)
	_emit("arrive", echo, {"text": text, "aftermath": echo.activity})
	_complete_first_arrival(echo)


func _activity(echo: Dictionary) -> String:
	if echo.destination.is_empty():
		return "idle"
	if echo.family == "rest":
		return "resting"
	if echo.family == "company":
		return "looking for company"
	return "practicing" if echo.destination == "training" else "reflecting" if echo.destination in ["flame", "quiet"] else "watching"


func _acknowledge(echo: Dictionary) -> void:
	_emit("acknowledge", echo, {"text": "%s turns to hear you." % echo.name})


func _reply(reply_id: String) -> bool:
	var conversation: Dictionary = _state.conversation
	if conversation.is_empty() or conversation.status != "choosing":
		return false
	var topic: Dictionary = _topic(conversation.topic)
	if topic.is_empty():
		return false
	var reply: Dictionary = {}
	for candidate: Dictionary in topic.replies:
		if candidate.id == reply_id:
			reply = candidate
	if reply.is_empty():
		return false
	var echo: Dictionary = _echo(conversation.echo_id)
	var exchange_key: String = "%s.%s" % [topic.id, reply_id]
	var outcome := "accept"
	var family: String = reply.family
	var destination: String = echo.destination if not str(echo.destination).is_empty() else _place_at(echo.node)
	if family in ["current", "stay"]:
		family = echo.family
	elif family == "alternative":
		family = echo.family
		for place: String in echo.preferences[family]:
			if place_node(place) != echo.node:
				destination = place
				break
	else:
		destination = echo.preferences[family][0]
	if reply.id == "stay":
		destination = _place_at(echo.node)
	var reason := "Your suggestion fits what I need now."
	# An autonomous decision opens a new context; reopening the same exchange
	# within the current intention must not repeatedly reset or reward it.
	if int(echo.exchanges.get(exchange_key, -1)) == int(echo.decisions):
		outcome = "repeated"
		reason = "We already talked about that. Nothing has changed."
	elif family == "company" and (float(echo.sociability) < 0.0 or float(echo.pressures.rest) >= 16.0):
		outcome = "reinterpret"
		family = "rest"
		destination = "hearth" if float(echo.sociability) >= 0.0 else "quiet"
		reason = "A little space would help more than company."
	elif reply.id == "pause" and float(echo.bias.purpose) >= 4.0 and float(echo.pressures.rest) < 12.0:
		outcome = "decline"
		reason = "Finishing this matters more than a pause right now."
	elif reply.id == "stay" and float(echo.pressures[family]) < 4.0:
		outcome = "decline"
		reason = "I have had what I need here; I am ready to move on."
	if outcome in ["accept", "reinterpret"]:
		var node_id: String = echo.node if reply.id == "stay" or destination.is_empty() else place_node(destination)
		echo.family = family
		echo.destination = destination
		echo.path = route(echo.node, node_id)
		echo.reason = reason
		echo.duration_ms = _duration_ms(echo)
		echo.remaining_ms = int(echo.duration_ms) if echo.path.is_empty() else 0
		echo.activity = _activity(echo)
	echo.exchanges[exchange_key] = int(echo.decisions)
	echo.last_response = outcome
	conversation.status = "resolved"
	conversation["outcome"] = outcome
	conversation["reason"] = reason
	conversation["line"] = _definition.response_lines[outcome]
	conversation["release_at_ms"] = int(_state.elapsed_ms) + RELEASE_MS
	_state.metrics.conversations += 1
	_state.metrics[outcome] += 1
	var text: String = "%s: %s %s" % [echo.name, conversation.line, reason]
	if outcome != "repeated":
		_record_event("response", echo, text, reason, echo.activity, true, {"title": "Keeper response"})
	_emit("response", echo, {"response": outcome, "text": text, "aftermath": echo.activity,
		"destination": destination, "path": [echo.node] + echo.path.duplicate()})
	return true


func _release_conversation(committed: bool) -> void:
	var echo: Dictionary = _echo(_state.conversation.echo_id)
	echo.reserved = false
	echo.moving = not echo.path.is_empty()
	echo.activity = "roaming" if echo.moving else _activity(echo)
	if committed:
		_emit("release", echo, {"text": echo.reason, "aftermath": echo.activity})
	_state.conversation = {}


func _place_at(node_id: String) -> String:
	for place: String in _definition.places:
		if place_node(place) == node_id:
			return place
	return ""


func _location_name(node_id: String) -> String:
	var place: String = _place_at(node_id)
	return _definition.places[place].name if not place.is_empty() else "the village path"


func _record_event(kind: String, echo: Dictionary, text: String, cause: String, aftermath: String, significant: bool = false, extra: Dictionary = {}) -> int:
	_state.event_serial += 1
	var event: Dictionary = {"id": _state.event_serial, "step": _state.step,
		"elapsed_ms": _state.elapsed_ms, "day": _state.day, "day_phase": _clock().phase,
		"kind": kind, "participants": [echo.id], "place": "" if echo.moving else _place_at(echo.node),
		"text": text, "cause": cause, "aftermath": aftermath, "significant": significant}
	event.merge(extra, true)
	_state.events.append(event)
	if _state.events.size() > EVENT_LIMIT:
		_state.events.pop_front()
	return int(event.id)


func _event_by_id(id: int) -> Dictionary:
	for event: Dictionary in _state.events:
		if int(event.id) == id:
			return event
	return {}


func _emit(kind: String, echo: Dictionary, extra: Dictionary) -> void:
	_state.beat_serial += 1
	var beat: Dictionary = {"id": _state.beat_serial, "step": _state.step,
		"kind": kind, "participants": [echo.id], "place": "" if echo.moving else _place_at(echo.node), "node": echo.node}
	beat.merge(extra, true)
	_state.beats.append(beat)
	if _state.beats.size() > BEAT_LIMIT:
		_state.beats.pop_front()


func _try_social_exchange() -> bool:
	if float(_state.tuning.social_frequency) <= 0.0:
		return false
	var echoes: Array = _state.echoes.duplicate()
	echoes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	var candidates: Array[Dictionary] = []
	for ai: int in range(echoes.size()):
		var a: Dictionary = echoes[ai]
		if a.moving or a.reserved or not str(a.engagement_id).is_empty():
			continue
		var place: String = _place_at(a.node)
		if place.is_empty():
			continue
		for bi: int in range(ai + 1, echoes.size()):
			var b: Dictionary = echoes[bi]
			if b.moving or b.reserved or not str(b.engagement_id).is_empty() or b.node != a.node:
				continue
			for family: String in _eligible_social_families(a, b, place):
				var roles: Array = _social_roles(a, b, family)
				var template_id: String = _social_outcome(roles[0], roles[1], family)
				var key: String = _cooldown_key(a.id, b.id, template_id)
				if int(_state.cooldowns.get(key, 0)) > int(_state.elapsed_ms):
					continue
				var score: float = _social_score(roles[0], roles[1], family, place)
				var rng: RandomNumberGenerator = _rng("social.check.%d.%s.%s.%s" % [_state.step, a.id, b.id, template_id])
				score += rng.randf_range(0.0, 0.01)
				candidates.append({"a": roles[0], "b": roles[1], "family": family,
					"template_id": template_id, "place": place, "score": score, "key": key})
	if candidates.is_empty():
		return false
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) > float(b.score)
		return "%s|%s|%s" % [a.a.id, a.b.id, a.template_id] < "%s|%s|%s" % [b.a.id, b.b.id, b.template_id])
	var chosen: Dictionary = candidates[0]
	var chance: float = float(_definition.social.check_chance_per_second) * float(_state.tuning.social_frequency) * float(STEP_MS) / 1000.0
	var chance_rng: RandomNumberGenerator = _rng("social.enact.%d.%s.%s.%s" % [_state.step, chosen.a.id, chosen.b.id, chosen.template_id])
	if chance_rng.randf() >= clampf(chance, 0.0, 1.0):
		return false
	_enact_social_exchange(chosen)
	return true


func _eligible_social_families(a: Dictionary, b: Dictionary, place: String) -> Array[String]:
	var result: Array[String] = []
	if a.family == "company" or b.family == "company":
		result.append("companionship")
	if (float(a.pressures.rest) >= 10.0 and b.archetype in ["empathic", "loyal", "devout"]) or (float(b.pressures.rest) >= 10.0 and a.archetype in ["empathic", "loyal", "devout"]):
		result.append("care")
	if place == "training" and (a.family == "purpose" or b.family == "purpose"):
		result.append("practice")
	return result


func _social_roles(a: Dictionary, b: Dictionary, family: String) -> Array:
	var a_value: float
	var b_value: float
	if family == "companionship":
		a_value = float(a.pressures.company) + float(a.sociability)
		b_value = float(b.pressures.company) + float(b.sociability)
	elif family == "care":
		a_value = float(a.traits.faith) + (10.0 if a.archetype == "empathic" else 0.0)
		b_value = float(b.traits.faith) + (10.0 if b.archetype == "empathic" else 0.0)
	else:
		a_value = float(a.pressures.purpose) + float(a.traits.courage) * 0.1
		b_value = float(b.pressures.purpose) + float(b.traits.courage) * 0.1
	if is_equal_approx(a_value, b_value):
		return [a, b] if str(a.id) < str(b.id) else [b, a]
	return [a, b] if a_value > b_value else [b, a]


func _social_outcome(initiator: Dictionary, receiver: Dictionary, family: String) -> String:
	var bond: int = _bond_strength(initiator.id, receiver.id)
	var impression: float = _impression_influence(receiver.id, initiator.id, family)
	match family:
		"companionship":
			if float(receiver.sociability) < 0.0 and (float(receiver.pressures.rest) >= 10.0 or impression < 0.0):
				return "unwanted_attention"
			if float(receiver.sociability) < 0.0 or receiver.archetype in ["reflective", "stoic"]:
				return "quiet_company"
			return "welcome_company"
		"care":
			if float(initiator.pressures.rest) >= 14.0:
				return "caregiver_strain"
			if int(receiver.fear) >= 55 and int(initiator.traits.courage) >= 55:
				return "protective_response"
			if receiver.archetype in ["proud", "stoic"] and float(receiver.pressures.rest) < 14.0 and bond < 10:
				return "declined_help"
			return "accepted_support"
		_:
			if bond <= -10 or (initiator.archetype in ["proud", "valiant"] and receiver.archetype in ["proud", "valiant"]):
				return "rivalry"
			if absf(float(initiator.traits.wisdom) - float(receiver.traits.wisdom)) >= 18.0:
				return "impatience"
			if bond == 0 and (initiator.archetype == "proud" or receiver.archetype == "proud"):
				return "competitive_practice"
			if abs(int(initiator.standing) - int(receiver.standing)) >= 2:
				return "recognition"
			if int(receiver.morale) < 50:
				return "encouragement"
			return "shared_practice"


func _social_score(a: Dictionary, b: Dictionary, family: String, place: String) -> float:
	var needs: float = (float(a.pressures.company) + float(b.pressures.company)) * 0.25
	var trait_score: float = (float(a.traits.faith) + float(b.traits.faith)) * 0.01
	if family == "care":
		needs = maxf(float(a.pressures.rest), float(b.pressures.rest)) * 0.5
		trait_score = (float(a.traits.faith) + float(b.traits.faith)) * 0.015
	elif family == "practice":
		needs = (float(a.pressures.purpose) + float(b.pressures.purpose)) * 0.3
		trait_score = (float(a.traits.courage) + float(b.traits.wisdom)) * 0.012
	var archetype_score := 1.0 if a.archetype == b.archetype else 0.0
	var emotion_score: float = (float(a.fear) + float(b.fear)) * 0.01 if family == "care" else (float(a.morale) + float(b.morale)) * 0.005
	if family == "care" and (a.emotional_status in ["burdened", "pressed", "strained", "fraying", "hollow"] or b.emotional_status in ["burdened", "pressed", "strained", "fraying", "hollow"]):
		emotion_score += 2.0
	var location_score := 2.0 if (family == "practice" and place == "training") or (family != "practice" and place == "hearth") else 0.5
	var bond_score: float = float(_bond_strength(a.id, b.id)) * 0.02
	return needs + trait_score + archetype_score + emotion_score + location_score + bond_score + _impression_influence(a.id, b.id, family) + _impression_influence(b.id, a.id, family)


func _enact_social_exchange(chosen: Dictionary) -> void:
	var a: Dictionary = chosen.a
	var b: Dictionary = chosen.b
	var template: Dictionary = _social_template(chosen.template_id)
	var voice: Dictionary = _reaction_voice("social", str(template.id))
	var voice_values: Dictionary = {"initiator": a.name, "receiver": b.name,
		"place": str(_definition.places.get(chosen.place, {}).get("name", "the village"))}
	_set_pair_orientation(a, b, "toward")
	var status_before: Dictionary = {a.id: a.emotional_status, b.id: b.emotional_status}
	var participant_effects: Array = [
		_apply_social_effect(a, template.participant_effects.initiator, "initiator"),
		_apply_social_effect(b, template.participant_effects.receiver, "receiver")]
	var bond_before: int = _bond_strength(a.id, b.id)
	var thresholds: Dictionary = _definition.social.bond_thresholds
	_state.bonds = SocialGraphScript.apply_score_delta(_state.bonds, a.id, b.id, int(template.bond_delta), thresholds, null, _state.step)
	var bond_after: int = _bond_strength(a.id, b.id)
	_state.encounters = SocialGraphScript.record_encounter(_state.encounters, a.id, b.id)
	var pair_key: String = _pair_key(a.id, b.id)
	_state.encounter_counts[pair_key] = int(_state.encounter_counts.get(pair_key, 0)) + 1
	var shared_bond: Dictionary = {"delta": bond_after - bond_before, "before": bond_before, "after": bond_after,
		"bond_type_before": SocialGraphScript.get_bond_type(bond_before, thresholds),
		"bond_type_after": SocialGraphScript.get_bond_type(bond_after, thresholds)}
	var cause: String = _social_cause(a, b, str(template.family), str(template.label))
	var reaction_cues: Array = _participant_reaction_cues(voice.get("reactions", {}), a, b, int(template.duration_ms))
	var witness_entries: Array = _practice_warning_witnesses(template, a, b) if bool(template.warning) and str(template.family) == "practice" else []
	var history_text: String = _format_voice(str(voice.get("history_text", template.cue_text)), voice_values)
	var live_text: String = _format_voice(str(voice.get("live_text", template.cue_text)), voice_values)
	var event_id: int = _record_event("social_exchange", a, history_text, cause, str(template.label), true,
		{"title": str(template.label), "participants": [a.id, b.id], "place": chosen.place,
		"family": template.family, "template_id": template.id,
		"participant_effects": participant_effects, "shared_bond": shared_bond,
		"participant_views": _participant_views(voice.get("views", {}), a, b),
		"personal_memories": _role_memories(voice.get("memories", {}), a, b),
		"reaction_cues": reaction_cues.duplicate(true), "witnesses": witness_entries.duplicate(true)})
	_state.bond_last_events[pair_key] = event_id
	var impression_changes: Array = []
	impression_changes.append(_replace_impression(a, b, template, "initiator", event_id, cause))
	impression_changes.append(_replace_impression(b, a, template, "receiver", event_id, cause))
	_event_by_id(event_id)["impression_changes"] = impression_changes.duplicate(true)
	_record_event("impression", a, "That meeting stays with them.", cause, "It may affect what they do later.", true,
		{"title": "A meeting stays with them", "participants": [a.id, b.id], "place": chosen.place,
			"family": template.family, "impression_changes": impression_changes, "source_event_id": event_id})
	if bond_after != bond_before:
		_record_event("bond_change", a, "They see each other differently now.", cause, SocialGraphScript.get_tier_name(SocialGraphScript.get_tier(bond_after)), true,
			{"title": "Their relationship changed", "participants": [a.id, b.id], "place": chosen.place,
				"shared_bond": shared_bond, "source_event_id": event_id})
	var emotion_changes: Array = _record_emotion_changes([a, b], status_before, cause, chosen.place, event_id)
	_event_by_id(event_id)["emotion_changes"] = emotion_changes
	_state.social_serial += 1
	var engagement_id := "social.%d" % _state.social_serial
	var duration_ms: int = int(template.duration_ms)
	_state.social_engagements.append({"id": engagement_id, "family": template.family,
		"template_id": template.id, "participants": [a.id, b.id], "place": chosen.place,
		"cue": live_text, "started_ms": _state.elapsed_ms,
		"duration_ms": duration_ms, "release_at_ms": int(_state.elapsed_ms) + duration_ms})
	for echo: Dictionary in [a, b]:
		echo.reserved = true
		echo.engagement_id = engagement_id
	_state.cooldowns[chosen.key] = int(_state.elapsed_ms) + int(template.cooldown_ms)
	_state.metrics.social_exchanges += 1
	_emit("social_exchange", a, {"participants": [a.id, b.id], "place": chosen.place, "text": live_text,
		"reaction_cues": reaction_cues.duplicate(true), "witnesses": witness_entries.duplicate(true)})
	if bool(template.warning):
		_create_warning(template, a, b, chosen.place, cause, event_id, witness_entries)


func _participant_views(authored: Dictionary, a: Dictionary, b: Dictionary) -> Array:
	var views: Array = []
	for role_pair: Array in [["initiator", a, b], ["receiver", b, a]]:
		var role: String = role_pair[0]
		var echo: Dictionary = role_pair[1]
		var other: Dictionary = role_pair[2]
		var text: String = str(authored.get(role, ""))
		if not text.is_empty():
			views.append({"echo_id": echo.id, "other_id": other.id, "role": role, "view_of_other": text})
	return views


func _role_memories(authored: Dictionary, a: Dictionary, b: Dictionary) -> Dictionary:
	return {a.id: str(authored.get("initiator", "")), b.id: str(authored.get("receiver", ""))}


func _participant_reaction_cues(authored: Dictionary, a: Dictionary, b: Dictionary, duration_ms: int) -> Array:
	var cues: Array = []
	for role_pair: Array in [["initiator", a, b], ["receiver", b, a]]:
		var role: String = role_pair[0]
		var echo: Dictionary = role_pair[1]
		var other: Dictionary = role_pair[2]
		var cue: Dictionary = _add_reaction_cue(echo.id, other.id, authored.get(role, {}), duration_ms)
		if not cue.is_empty():
			cues.append(cue)
	return cues


func _practice_warning_witnesses(template: Dictionary, a: Dictionary, b: Dictionary) -> Array:
	var config: Dictionary = _definition.get("reaction_voice", {}).get("warning_witnesses", {})
	var max_witnesses: int = int(config.get("max", 0))
	if max_witnesses <= 0:
		return []
	var candidates: Array = _state.echoes.duplicate()
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.id) < str(right.id))
	var witnesses: Array = []
	var used_roles: Dictionary = {}
	for witness: Dictionary in candidates:
		if witness.id in [a.id, b.id] or bool(witness.moving) or bool(witness.reserved) or not str(witness.engagement_id).is_empty() or not str(witness.incident_id).is_empty():
			continue
		var role: Dictionary = _practice_witness_role(config.get("roles", []), witness, used_roles)
		if role.is_empty():
			continue
		var role_id: String = str(role.id)
		var target: Dictionary = a if str(role.get("target", "receiver")) == "initiator" else b
		var reaction: Dictionary = _add_reaction_cue(witness.id, target.id, role.get("reaction", {}), int(template.duration_ms))
		if reaction.is_empty():
			continue
		used_roles[role_id] = true
		witnesses.append({"echo_id": witness.id, "role": role_id, "target_id": target.id,
			"reaction": reaction, "perspective": _format_voice(str(role.get("perspective", "")), {"initiator": a.name, "receiver": b.name})})
		if witnesses.size() == max_witnesses:
			break
	return witnesses


func _practice_witness_role(roles: Array, witness: Dictionary, used_roles: Dictionary) -> Dictionary:
	for role: Dictionary in roles:
		if used_roles.has(str(role.get("id", ""))):
			continue
		var archetypes: Array = role.get("eligible_archetypes", [])
		if not archetypes.is_empty() and not archetypes.has(str(witness.archetype)):
			continue
		if role.has("rest_at_least") and float(witness.pressures.rest) < float(role.rest_at_least):
			continue
		return role.duplicate(true)
	return {}


func _participant_effect_state(echo: Dictionary) -> Dictionary:
	return {"rest": float(echo.pressures.rest), "company": float(echo.pressures.company),
		"purpose": float(echo.pressures.purpose), "emotional_status": str(echo.emotional_status)}


func _apply_incident_effect(echo: Dictionary, configured: Dictionary, reaction: String) -> Dictionary:
	var before: Dictionary = _participant_effect_state(echo)
	var result: Dictionary = _apply_social_effect(echo, configured, reaction)
	result["before"] = before
	result["after"] = _participant_effect_state(echo)
	return result


func _apply_social_effect(echo: Dictionary, configured: Dictionary, reaction: String) -> Dictionary:
	var result: Dictionary = {"echo_id": echo.id, "reaction": reaction}
	for family: String in FAMILIES:
		var key: String = family + "_delta"
		var before: float = float(echo.pressures[family])
		echo.pressures[family] = clampf(before + float(configured.get(key, 0.0)), 0.0, float(_definition.rules.pressure_max))
		result[key] = float(echo.pressures[family]) - before
	var fear_before: int = int(echo.fear)
	var morale_before: int = int(echo.morale)
	echo.fear = clampi(fear_before + int(configured.get("fear_delta", 0)), 0, 100)
	echo.morale = clampi(morale_before + int(configured.get("morale_delta", 0)), 0, 100)
	result["fear_delta"] = int(echo.fear) - fear_before
	result["morale_delta"] = int(echo.morale) - morale_before
	echo.emotional_status = _emotional_status(echo)
	return result


func _record_emotion_changes(echoes: Array, before: Dictionary, cause: String, place: String, source_event_id: int) -> Array:
	var changes: Array = []
	for echo: Dictionary in echoes:
		if str(before.get(echo.id, "")) == echo.emotional_status:
			continue
		var change: Dictionary = {"echo_id": echo.id, "status_before": before.get(echo.id, ""), "status_after": echo.emotional_status}
		changes.append(change)
		_record_event("emotion_change", echo, "%s seems %s now." % [echo.name, _emotion_display(str(echo.emotional_status))], cause, _emotion_display(str(echo.emotional_status)), true,
			{"title": "An emotional change", "place": place, "status_before": before.get(echo.id, ""),
				"status_after": echo.emotional_status, "source_event_id": source_event_id})
	return changes


func _replace_impression(owner: Dictionary, other: Dictionary, template: Dictionary, role: String, event_id: int, cause: String) -> Dictionary:
	for index: int in range(_state.impressions.size() - 1, -1, -1):
		var old: Dictionary = _state.impressions[index]
		if old.owner_id == owner.id and old.other_id == other.id and old.family == template.family:
			_state.impressions.remove_at(index)
	var spec: Dictionary = template.impressions[role]
	var impression: Dictionary = {"owner_id": owner.id, "other_id": other.id,
		"family": template.family, "tag": spec.tag, "cause_event_id": event_id,
		"cause": cause, "created_ms": _state.elapsed_ms,
		"expires_ms": int(_state.elapsed_ms) + int(float(_state.tuning.day_minutes) * 60000.0),
		"influence": spec.influence.duplicate(true)}
	_state.impressions.append(impression)
	return impression.duplicate(true)


func _expire_impressions() -> bool:
	var expired: Array = []
	for impression: Dictionary in _state.impressions:
		if int(impression.expires_ms) <= int(_state.elapsed_ms):
			expired.append(impression)
	for impression: Dictionary in expired:
		_state.impressions.erase(impression)
		var owner: Dictionary = _echo(impression.owner_id)
		_record_event("impression", owner, "The feeling from that meeting has eased.", impression.cause, "It is no longer shaping what they do next.", true,
			{"title": "An impression faded", "participants": [impression.owner_id, impression.other_id],
				"place": _place_at(owner.node), "family": impression.family,
				"impression_changes": [impression]})
	return not expired.is_empty()


func _advance_behaviors() -> Dictionary:
	var releases: Dictionary = {}
	for echo: Dictionary in _state.echoes:
		var behavior: Dictionary = echo.behavior
		if behavior.is_empty():
			continue
		if behavior.kind == "issue":
			var incident: Dictionary = _incident(str(behavior.source_id))
			if not incident.is_empty():
				var deadline: int = int(incident.intervention_deadline_ms) if incident.status == "joined" else int(incident.incident_deadline_ms)
				behavior.remaining_ms = maxi(0, deadline - int(_state.elapsed_ms))
			continue
		behavior.remaining_ms = maxi(0, int(behavior.started_ms) + int(behavior.duration_ms) - int(_state.elapsed_ms))
		if int(behavior.remaining_ms) == 0:
			releases[echo.id] = behavior.duplicate(true)
			echo.behavior = {}
			echo.incident_id = ""
	return releases


func _advance_social_commitments() -> bool:
	var completed: Array = []
	for engagement: Dictionary in _state.social_engagements:
		if int(engagement.release_at_ms) <= int(_state.elapsed_ms):
			completed.append(engagement)
	for engagement: Dictionary in completed:
		for echo_id: String in engagement.participants:
			var echo: Dictionary = _echo(echo_id)
			if echo.engagement_id == engagement.id:
				echo.engagement_id = ""
				if echo.incident_id.is_empty() and echo.behavior.is_empty():
					echo.reserved = false
		_state.social_engagements.erase(engagement)
		var first: Dictionary = _echo(engagement.participants[0])
		_emit("social_release", first, {"participants": engagement.participants, "place": engagement.place, "text": engagement.cue})
	return not completed.is_empty()


func _social_template(id: String) -> Dictionary:
	for template: Dictionary in _definition.social.templates:
		if template.id == id:
			return template
	return {}


func _pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func _cooldown_key(a: String, b: String, template_id: String) -> String:
	return "%s|%s" % [_pair_key(a, b), template_id]


func _incident_cooldown_key(a: String, b: String, family: String) -> String:
	return "%s|incident.%s" % [_pair_key(a, b), family]


func _bond_strength(a: String, b: String) -> int:
	var edge: Dictionary = SocialGraphScript.get_edge(_state.bonds, a, b)
	return int(edge.get("strength", 0))


func _impression_influence(owner_id: String, other_id: String, family: String) -> float:
	var total := 0.0
	for impression: Dictionary in _state.impressions:
		if impression.owner_id == owner_id and impression.other_id == other_id and impression.family == family:
			for value: Variant in impression.influence.values():
				total += float(value)
	return total


func _need_impression_influence(owner_id: String, need_family: String) -> float:
	var total := 0.0
	for impression: Dictionary in _state.impressions:
		if impression.owner_id == owner_id:
			total += float(impression.influence.get(need_family, 0.0))
	return total


func _social_cause(a: Dictionary, b: Dictionary, family: String, label: String) -> String:
	var need: String = "company" if family == "companionship" else "a breather" if family == "care" else "something to do"
	return "%s and %s met at %s. They both had %s on their minds." % [a.name, b.name,
		_location_name(a.node), need]


func _set_pair_orientation(a: Dictionary, b: Dictionary, orientation: String) -> void:
	var a_position := Vector2(float(a.position[0]), float(a.position[1]))
	var b_position := Vector2(float(b.position[0]), float(b.position[1]))
	var direction: Vector2 = a_position.direction_to(b_position)
	if direction.is_zero_approx():
		var first: Dictionary = a if str(a.id) < str(b.id) else b
		var second: Dictionary = b if first == a else a
		var first_direction := Vector2.RIGHT if orientation == "toward" else Vector2.LEFT
		first.facing = [first_direction.x, first_direction.y]
		second.facing = [-first_direction.x, -first_direction.y]
		return
	if orientation == "away":
		direction = -direction
	a.facing = [direction.x, direction.y]
	b.facing = [-direction.x, -direction.y]


func _assign_issue_behaviors(incident: Dictionary, a: Dictionary, b: Dictionary, activity: String) -> void:
	_set_pair_orientation(a, b, "toward")
	var duration_ms: int = int(incident.incident_deadline_ms) - int(incident.created_ms)
	for pair: Array in [[a, b], [b, a]]:
		var echo: Dictionary = pair[0]
		var partner: Dictionary = pair[1]
		echo.incident_id = incident.id
		echo.reserved = true
		echo.moving = false
		echo.path = []
		echo.destination = incident.place
		echo.activity = activity
		echo.reason = incident.cause
		echo.behavior = {"kind": "issue", "source_id": incident.id,
			"partner_id": partner.id, "activity": activity, "orientation": "toward",
			"started_ms": incident.created_ms, "duration_ms": duration_ms,
			"remaining_ms": duration_ms, "next_intention": {}}


func _assign_aftermath_behaviors(incident: Dictionary, configured: Dictionary, a: Dictionary, b: Dictionary) -> Array:
	var spec: Dictionary = configured.aftermath_behavior
	var duration_ms: int = int(spec.duration_ms)
	var orientation: String = str(spec.orientation)
	_set_pair_orientation(a, b, orientation)
	var result: Array = []
	for role_pair: Array in [["initiator", a, b], ["receiver", b, a]]:
		var role: String = role_pair[0]
		var echo: Dictionary = role_pair[1]
		var partner: Dictionary = role_pair[2]
		var behavior: Dictionary = {"kind": "aftermath", "source_id": incident.id,
			"partner_id": partner.id, "activity": str(spec.activities[role]),
			"orientation": orientation, "started_ms": int(_state.elapsed_ms),
			"duration_ms": duration_ms, "remaining_ms": duration_ms,
			"next_intention": {"family": str(spec.next_families[role])}}
		echo.behavior = behavior
		echo.activity = behavior.activity
		echo.reason = str(configured.aftermath)
		echo.reserved = true
		var projected: Dictionary = behavior.duplicate(true)
		projected["echo_id"] = echo.id
		projected["role"] = role
		result.append(projected)
	return result


func _incident_access(a: Dictionary, b: Dictionary, family: String) -> Dictionary:
	var access_config: Dictionary = _definition.social.get("incident_access", {})
	var thresholds: Dictionary = access_config.get("thresholds", {})
	var average_fear: float = (float(a.fear) + float(b.fear)) * 0.5
	var average_rest: float = (float(a.pressures.rest) + float(b.pressures.rest)) * 0.5
	var average_courage: float = (float(a.traits.courage) + float(b.traits.courage)) * 0.5
	var average_wisdom: float = (float(a.traits.wisdom) + float(b.traits.wisdom)) * 0.5
	var score: float = (average_fear - float(thresholds.get("fear_center", 0.0))) * float(thresholds.get("fear_weight", 0.0))
	score += (average_rest - float(thresholds.get("rest_center", 0.0))) * float(thresholds.get("rest_weight", 0.0))
	score -= (average_courage - float(thresholds.get("courage_center", 0.0))) * float(thresholds.get("courage_weight", 0.0))
	score -= (average_wisdom - float(thresholds.get("wisdom_center", 0.0))) * float(thresholds.get("wisdom_weight", 0.0))
	score -= float(_bond_strength(a.id, b.id)) * float(thresholds.get("bond_weight", 0.0))
	score += (_impression_influence(a.id, b.id, family) + _impression_influence(b.id, a.id, family)) * float(thresholds.get("impression_weight", 0.0))
	var archetype_biases: Dictionary = access_config.get("archetype_bias", {})
	score += (float(archetype_biases.get(str(a.archetype), 0.0)) + float(archetype_biases.get(str(b.archetype), 0.0))) * 0.5
	score += float(access_config.get("family_bias", {}).get(family, 0.0))
	var keeper_access := "open"
	if score <= float(thresholds.get("private_max", -INF)):
		keeper_access = "private"
	elif score >= float(thresholds.get("appeal_min", INF)):
		keeper_access = "appeal"
	var appeal_echo_id := ""
	if keeper_access == "appeal":
		appeal_echo_id = _appeal_echo_id(a, b, family, thresholds, archetype_biases)
	var appeal: Dictionary = _echo(appeal_echo_id)
	var reason_values := {"appeal": str(appeal.get("name", "They"))}
	var access_reason: String = _format_voice(str(access_config.get("reasons", {}).get(keeper_access, "")), reason_values)
	return {"keeper_access": keeper_access, "appeal_echo_id": appeal_echo_id, "access_reason": access_reason}


func _appeal_echo_id(a: Dictionary, b: Dictionary, family: String, thresholds: Dictionary, archetype_biases: Dictionary) -> String:
	var first_score: float = _appeal_score(a, b, family, thresholds, archetype_biases)
	var second_score: float = _appeal_score(b, a, family, thresholds, archetype_biases)
	if first_score > second_score or (is_equal_approx(first_score, second_score) and str(a.id) < str(b.id)):
		return str(a.id)
	return str(b.id)


func _appeal_score(echo: Dictionary, other: Dictionary, family: String, thresholds: Dictionary, archetype_biases: Dictionary) -> float:
	var score: float = (float(echo.fear) - float(thresholds.get("fear_center", 0.0))) * float(thresholds.get("fear_weight", 0.0))
	score += (float(echo.pressures.rest) - float(thresholds.get("rest_center", 0.0))) * float(thresholds.get("rest_weight", 0.0))
	score -= (float(echo.traits.courage) - float(thresholds.get("courage_center", 0.0))) * float(thresholds.get("courage_weight", 0.0))
	score -= (float(echo.traits.wisdom) - float(thresholds.get("wisdom_center", 0.0))) * float(thresholds.get("wisdom_weight", 0.0))
	score += _impression_influence(echo.id, other.id, family) * float(thresholds.get("impression_weight", 0.0))
	score += float(archetype_biases.get(str(echo.archetype), 0.0))
	return score


func _incident_exchange_lines(voice: Dictionary, a: Dictionary, b: Dictionary, values: Dictionary) -> Array:
	var exchange_lines: Array = []
	for authored: Dictionary in voice.get("exchange_lines", []):
		var role: String = str(authored.get("speaker", ""))
		if role not in ["initiator", "receiver"]:
			continue
		var speaker: Dictionary = a if role == "initiator" else b
		exchange_lines.append({"speaker_id": speaker.id, "text": _format_voice(str(authored.get("text", "")), values)})
	return exchange_lines


func _create_warning(template: Dictionary, a: Dictionary, b: Dictionary, place: String, cause: String, source_event_id: int, witnesses: Array = []) -> void:
	for existing: Dictionary in _state.incidents:
		if existing.status != "resolved" and existing.family == template.family and _pair_key(existing.participants[0], existing.participants[1]) == _pair_key(a.id, b.id):
			return
	if int(_state.cooldowns.get(_incident_cooldown_key(a.id, b.id, str(template.family)), 0)) > int(_state.elapsed_ms):
		return
	_state.incident_serial += 1
	var warning_ms: int = int(float(_state.tuning.warning_seconds) * 1000.0)
	var open_ms: int = int(float(_definition.social.open_incident_seconds) * 1000.0)
	var definition: Dictionary = _definition.social.incidents[template.family]
	var voice: Dictionary = _reaction_voice("incident_families", str(template.family))
	var voice_values: Dictionary = {"initiator": a.name, "receiver": b.name,
		"place": str(_definition.places.get(place, {}).get("name", "the village"))}
	var access: Dictionary = _incident_access(a, b, str(template.family))
	var exchange_lines: Array = _incident_exchange_lines(voice, a, b, voice_values)
	var incident: Dictionary = {"id": "incident.%d" % _state.incident_serial,
		"family": template.family, "template_id": template.id, "label": definition.label,
		"status": "warning", "participants": [a.id, b.id], "place": place,
		"cause": cause, "created_ms": _state.elapsed_ms, "stage_started_ms": _state.elapsed_ms,
		"stage_deadline_ms": int(_state.elapsed_ms) + warning_ms,
		"incident_deadline_ms": int(_state.elapsed_ms) + warning_ms + open_ms,
		"intervention_deadline_ms": 0, "result": {}, "release_at_ms": 0,
		"deferred": false, "source_event_id": source_event_id, "witnesses": witnesses.duplicate(true),
		"keeper_access": access.keeper_access, "appeal_echo_id": access.appeal_echo_id,
		"access_reason": access.access_reason, "exchange_lines": exchange_lines.duplicate(true)}
	_state.incidents.append(incident)
	_assign_issue_behaviors(incident, a, b, str(definition.issue_activity))
	_state.metrics.warnings += 1
	_record_event("incident_warning", a, _format_voice(str(voice.get("warning_history", "%s began." % definition.label)), voice_values), cause,
		"The moment was still unfolding.", true,
		{"title": definition.label, "participants": incident.participants, "place": place,
			"incident_id": incident.id, "family": incident.family, "template_id": incident.template_id,
			"keeper_access": incident.keeper_access, "appeal_echo_id": incident.appeal_echo_id,
			"access_reason": incident.access_reason, "exchange_lines": incident.exchange_lines.duplicate(true),
			"witnesses": witnesses.duplicate(true)})
	_emit("incident_warning", a, {"participants": incident.participants, "place": place, "text": _format_voice(str(voice.get("warning_live", definition.label)), voice_values),
		"keeper_access": incident.keeper_access, "appeal_echo_id": incident.appeal_echo_id,
		"access_reason": incident.access_reason, "exchange_lines": incident.exchange_lines.duplicate(true),
		"witnesses": witnesses.duplicate(true)})


func _advance_incidents() -> bool:
	var meaningful := false
	var remove: Array = []
	for incident: Dictionary in _state.incidents:
		match str(incident.status):
			"warning":
				if int(_state.elapsed_ms) >= int(incident.stage_deadline_ms):
					incident.status = "open"
					incident.stage_started_ms = _state.elapsed_ms
					incident.stage_deadline_ms = incident.incident_deadline_ms
					var first: Dictionary = _echo(incident.participants[0])
					var voice: Dictionary = _reaction_voice("incident_families", str(incident.family))
					var second: Dictionary = _echo(incident.participants[1])
					var voice_values: Dictionary = {"initiator": first.name, "receiver": second.name,
						"place": str(_definition.places.get(incident.place, {}).get("name", "the village"))}
					_record_event("incident_open", first, "%s needed a clear word before it grew." % incident.label, incident.cause,
						"The moment remained unresolved.", true,
						{"title": incident.label, "participants": incident.participants, "place": incident.place,
							"incident_id": incident.id, "family": incident.family, "template_id": incident.template_id,
							"keeper_access": incident.keeper_access, "appeal_echo_id": incident.appeal_echo_id,
							"access_reason": incident.access_reason, "exchange_lines": incident.exchange_lines.duplicate(true),
							"witnesses": incident.get("witnesses", []).duplicate(true)})
					_emit("incident_open", first, {"participants": incident.participants, "place": incident.place, "text": _format_voice(str(voice.get("open_live", incident.label)), voice_values),
						"keeper_access": incident.keeper_access, "appeal_echo_id": incident.appeal_echo_id,
						"access_reason": incident.access_reason, "exchange_lines": incident.exchange_lines.duplicate(true),
						"witnesses": incident.get("witnesses", []).duplicate(true)})
					meaningful = true
			"open":
				if int(_state.elapsed_ms) >= int(incident.incident_deadline_ms):
					_resolve_incident_autonomously(incident)
					meaningful = true
			"joined":
				if int(_state.elapsed_ms) >= int(incident.intervention_deadline_ms):
					_resolve_incident_autonomously(incident)
					meaningful = true
			"resolved":
				if int(_state.elapsed_ms) >= int(incident.release_at_ms):
					_release_incident_participants(incident)
					remove.append(incident)
					meaningful = true
	for incident: Dictionary in remove:
		_state.incidents.erase(incident)
	return meaningful


func _join_incident(id: String) -> bool:
	if not is_living() or _arrival_blocks_interactions() or not _state.conversation.is_empty() or not str(_state.joined_incident_id).is_empty():
		return false
	var incident: Dictionary = _incident(id)
	if not _can_join_incident(incident):
		return false
	incident.status = "joined"
	incident.stage_started_ms = _state.elapsed_ms
	incident.intervention_deadline_ms = mini(int(incident.incident_deadline_ms), int(_state.elapsed_ms) + int(float(_state.tuning.intervention_seconds) * 1000.0))
	incident.stage_deadline_ms = incident.intervention_deadline_ms
	_state.joined_incident_id = incident.id
	for echo_id: String in incident.participants:
		var echo: Dictionary = _echo(echo_id)
		echo.reserved = true
		echo.behavior.remaining_ms = maxi(0, int(incident.intervention_deadline_ms) - int(_state.elapsed_ms))
	var first: Dictionary = _echo(incident.participants[0])
	_record_event("incident_intervention", first, "You step into %s." % incident.label, incident.cause,
		"Choose what to say.", true,
		{"title": "Keeper intervention", "participants": incident.participants, "place": incident.place,
			"incident_id": incident.id, "response": "joined", "keeper_access": incident.keeper_access,
			"appeal_echo_id": incident.appeal_echo_id, "access_reason": incident.access_reason,
			"exchange_lines": incident.exchange_lines.duplicate(true)})
	_emit("incident_joined", first, {"participants": incident.participants, "place": incident.place, "text": incident.label,
		"keeper_access": incident.keeper_access, "appeal_echo_id": incident.appeal_echo_id,
		"access_reason": incident.access_reason, "exchange_lines": incident.exchange_lines.duplicate(true)})
	return true


func _reply_incident(id: String, reply_id: String) -> bool:
	var incident: Dictionary = _incident(id)
	if incident.is_empty() or incident.status != "joined" or _state.joined_incident_id != id:
		return false
	var reply: Dictionary = _incident_reply(str(incident.family), reply_id)
	if reply.is_empty():
		return false
	_resolve_incident(incident, reply, reply_id)
	_state.metrics.interventions += 1
	return true


func _defer_incident(id: String) -> bool:
	var incident: Dictionary = _incident(id)
	if incident.is_empty() or incident.status != "joined" or _state.joined_incident_id != id:
		return false
	incident.status = "open"
	incident.deferred = true
	incident.intervention_deadline_ms = 0
	incident.stage_started_ms = _state.elapsed_ms
	incident.stage_deadline_ms = incident.incident_deadline_ms
	_state.joined_incident_id = ""
	for echo_id: String in incident.participants:
		var echo: Dictionary = _echo(echo_id)
		echo.behavior.remaining_ms = maxi(0, int(incident.incident_deadline_ms) - int(_state.elapsed_ms))
	var first: Dictionary = _echo(incident.participants[0])
	_record_event("incident_intervention", first, "You step away from %s." % incident.label, incident.cause,
		"They will have to sort it out themselves.", true,
		{"title": "Intervention deferred", "participants": incident.participants,
			"place": incident.place, "incident_id": incident.id, "response": "defer"})
	return true


func _resolve_incident_autonomously(incident: Dictionary) -> void:
	var a: Dictionary = _echo(incident.participants[0])
	var b: Dictionary = _echo(incident.participants[1])
	var strain: float = maxf(float(a.pressures.rest), float(b.pressures.rest))
	strain += float(a.fear + b.fear) * 0.08
	strain -= float(a.traits.wisdom + b.traits.wisdom) * 0.06
	strain -= float(_bond_strength(a.id, b.id)) * 0.1
	strain -= _impression_influence(a.id, b.id, incident.family)
	strain -= _impression_influence(b.id, a.id, incident.family)
	var response := "frustrated" if strain >= 12.0 else "settled"
	var result: Dictionary = _definition.social.autonomous_results[response]
	_record_event("incident_mutation", a, "They were left to handle it themselves.", incident.cause,
		str(_reaction_voice("autonomous", response).get("history_text", result.aftermath)), true, {"title": "They handled it themselves",
			"participants": incident.participants, "place": incident.place,
			"incident_id": incident.id, "response": response, "keeper_access": incident.keeper_access,
			"appeal_echo_id": incident.appeal_echo_id, "access_reason": incident.access_reason,
			"exchange_lines": incident.exchange_lines.duplicate(true)})
	_resolve_incident(incident, result, response)


func _resolve_incident(incident: Dictionary, configured: Dictionary, response: String) -> void:
	var a: Dictionary = _echo(incident.participants[0])
	var b: Dictionary = _echo(incident.participants[1])
	var is_autonomous: bool = response in ["settled", "frustrated"] and configured.get("keeper_reactions", {}).is_empty()
	var voice_section := "autonomous"
	var voice_id := response
	if not is_autonomous:
		voice_section = "incident_replies"
		voice_id = "%s.%s" % [incident.family, response]
	var voice: Dictionary = _reaction_voice(voice_section, voice_id)
	var status_before: Dictionary = {a.id: a.emotional_status, b.id: b.emotional_status}
	var participant_effects: Array = []
	for effect: Dictionary in configured.get("participant_effects", []):
		var target: Dictionary = a if effect.get("role", "initiator") == "initiator" else b
		participant_effects.append(_apply_incident_effect(target, effect, str(effect.get("role", ""))))
	var before: int = _bond_strength(a.id, b.id)
	var thresholds: Dictionary = _definition.social.bond_thresholds
	_state.bonds = SocialGraphScript.apply_score_delta(_state.bonds, a.id, b.id, int(configured.get("bond_delta", 0)), thresholds, null, _state.step)
	var after: int = _bond_strength(a.id, b.id)
	var tier_before: int = SocialGraphScript.get_tier(before)
	var tier_after: int = SocialGraphScript.get_tier(after)
	var shared_bond: Dictionary = {"delta": after - before, "before": before, "after": after,
		"bond_type_before": SocialGraphScript.get_bond_type(before, thresholds),
		"bond_type_after": SocialGraphScript.get_bond_type(after, thresholds),
		"tier_before": tier_before, "tier_after": tier_after,
		"tier_name_before": SocialGraphScript.get_tier_name(tier_before),
		"tier_name_after": SocialGraphScript.get_tier_name(tier_after)}
	var aftermath_behaviors: Array = _assign_aftermath_behaviors(incident, configured, a, b)
	var participant_views: Array = _incident_participant_views(voice.get("views", configured.get("participant_views", {})), a, b)
	var keeper_reactions: Array = [] if is_autonomous else _incident_keeper_reactions(configured, a, b)
	var reaction_cues: Array = _participant_reaction_cues(voice.get("reactions", {}), a, b, int(_definition.get("reaction_voice", {}).get("cue_duration_ms", 2000)))
	var cause_resolution: Dictionary = _incident_cause_resolution(configured, participant_effects, str(incident.cause))
	var result: Dictionary = {"response": response, "participant_effects": participant_effects,
		"shared_bond": shared_bond, "aftermath": str(configured.aftermath),
		"aftermath_behaviors": aftermath_behaviors,
		"participant_views": participant_views.duplicate(true),
		"keeper_reactions": keeper_reactions.duplicate(true),
		"cause_resolution": cause_resolution.duplicate(true), "reaction_cues": reaction_cues.duplicate(true),
		"witnesses": incident.get("witnesses", []).duplicate(true),
		"keeper_access": incident.keeper_access, "appeal_echo_id": incident.appeal_echo_id,
		"access_reason": incident.access_reason, "exchange_lines": incident.exchange_lines.duplicate(true)}
	incident.status = "resolved"
	incident.result = result.duplicate(true)
	var incident_definition: Dictionary = _definition.social.incidents[incident.family]
	_state.cooldowns[_incident_cooldown_key(a.id, b.id, str(incident.family))] = int(_state.elapsed_ms) + int(incident_definition.get("post_resolution_cooldown_ms", 0))
	incident.release_at_ms = int(_state.elapsed_ms) + RELEASE_MS
	incident.stage_started_ms = _state.elapsed_ms
	incident.stage_deadline_ms = incident.release_at_ms
	incident.intervention_deadline_ms = 0
	var event_id: int = _record_event("incident_resolved", a, str(voice.get("history_text", configured.aftermath)), incident.cause,
		str(configured.aftermath), true, {"title": "Incident resolved", "participants": incident.participants,
			"place": incident.place, "incident_id": incident.id, "response": response,
			"participant_effects": participant_effects, "shared_bond": shared_bond,
			"aftermath_behaviors": aftermath_behaviors,
			"participant_views": participant_views.duplicate(true),
			"keeper_reactions": keeper_reactions.duplicate(true),
			"cause_resolution": cause_resolution.duplicate(true), "reaction_cues": reaction_cues.duplicate(true),
			"keeper_access": incident.keeper_access, "appeal_echo_id": incident.appeal_echo_id,
			"access_reason": incident.access_reason, "exchange_lines": incident.exchange_lines.duplicate(true),
			"personal_memories": _role_memories(voice.get("memories", {}), a, b),
			"witnesses": incident.get("witnesses", []).duplicate(true)})
	_state.bond_last_events[_pair_key(a.id, b.id)] = event_id
	if after != before:
		_record_event("bond_change", a, "They see each other differently now.", incident.cause,
			SocialGraphScript.get_tier_name(SocialGraphScript.get_tier(after)), true,
			{"title": "A relationship changed", "participants": incident.participants,
				"place": incident.place, "shared_bond": shared_bond, "source_event_id": event_id})
	var emotion_changes: Array = _record_emotion_changes([a, b], status_before, incident.cause, incident.place, event_id)
	_event_by_id(event_id)["emotion_changes"] = emotion_changes
	_state.metrics.incidents_resolved += 1
	_emit("incident_resolved", a, {"participants": incident.participants, "place": incident.place,
		"text": str(voice.get("live_text", configured.aftermath)), "aftermath_behaviors": aftermath_behaviors,
		"reaction_cues": reaction_cues.duplicate(true), "keeper_access": incident.keeper_access,
		"appeal_echo_id": incident.appeal_echo_id, "access_reason": incident.access_reason,
		"exchange_lines": incident.exchange_lines.duplicate(true), "witnesses": incident.get("witnesses", []).duplicate(true)})


func _incident_participant_views(configured: Dictionary, a: Dictionary, b: Dictionary) -> Array:
	var authored: Dictionary = configured.get("participant_views", configured)
	var views: Array = []
	for role_pair: Array in [["initiator", a, b], ["receiver", b, a]]:
		var role: String = role_pair[0]
		var echo: Dictionary = role_pair[1]
		var other: Dictionary = role_pair[2]
		var view_of_other: String = str(authored.get(role, ""))
		if not view_of_other.is_empty():
			views.append({"echo_id": echo.id, "other_id": other.id, "role": role,
				"view_of_other": view_of_other})
	return views


func _incident_keeper_reactions(configured: Dictionary, a: Dictionary, b: Dictionary) -> Array:
	var authored: Dictionary = configured.get("keeper_reactions", {})
	var reactions: Array = []
	for role_pair: Array in [["initiator", a], ["receiver", b]]:
		var role: String = role_pair[0]
		var echo: Dictionary = role_pair[1]
		var reaction: String = str(authored.get(role, ""))
		if not reaction.is_empty():
			reactions.append({"echo_id": echo.id, "role": role, "reaction": reaction})
	return reactions


func _incident_cause_resolution(configured: Dictionary, participant_effects: Array, original_cause: String) -> Dictionary:
	var authored: Dictionary = configured.get("cause_resolution", {})
	var intended: String = str(authored.get("status", "remains"))
	var effect_applied := false
	for effect: Dictionary in participant_effects:
		for key: String in ["rest_delta", "company_delta", "purpose_delta", "fear_delta", "morale_delta"]:
			if not is_zero_approx(float(effect.get(key, 0.0))):
				effect_applied = true
				break
		if effect_applied:
			break
	var status := "eased" if intended == "eased" and effect_applied else "remains"
	var summary: String = str(authored.get("eased_text" if status == "eased" else "remaining_text", original_cause))
	var recurrence_cause := str(authored.get("surviving_cause", original_cause)) if status == "remains" else ""
	return {"status": status, "summary": summary, "recurrence_possible": status == "remains",
		"recurrence_cause": recurrence_cause}


func _release_incident_participants(incident: Dictionary) -> void:
	for echo_id: String in incident.participants:
		var echo: Dictionary = _echo(echo_id)
		if echo.incident_id == incident.id and echo.behavior.is_empty():
			echo.incident_id = ""
		if str(echo.engagement_id).is_empty() and echo.behavior.is_empty():
			echo.reserved = false
	if _state.joined_incident_id == incident.id:
		_state.joined_incident_id = ""


func _incident(id: String) -> Dictionary:
	for incident: Dictionary in _state.incidents:
		if incident.id == id:
			return incident
	return {}


func _incident_reply(family: String, id: String) -> Dictionary:
	for reply: Dictionary in _definition.social.incidents[family].replies:
		if reply.id == id:
			return reply
	return {}


func _incident_participants_available(incident: Dictionary) -> bool:
	for echo_id: String in incident.participants:
		var echo: Dictionary = _echo(echo_id)
		if echo.is_empty() or echo.moving or not bool(echo.reserved) or not str(echo.engagement_id).is_empty() or echo.incident_id != incident.id or echo.behavior.get("kind", "") != "issue":
			return false
	return true


func _can_join_incident(incident: Dictionary) -> bool:
	if incident.is_empty() or str(incident.status) != "open" or bool(incident.deferred):
		return false
	if str(incident.get("keeper_access", "private")) not in ["open", "appeal"]:
		return false
	if not _state.conversation.is_empty() or not str(_state.joined_incident_id).is_empty():
		return false
	return _incident_participants_available(incident)


func _project_social_engagements() -> Array:
	var result: Array = []
	for engagement: Dictionary in _state.social_engagements:
		result.append({"id": engagement.id, "family": engagement.family,
			"template_id": engagement.template_id, "participants": engagement.participants.duplicate(),
			"place": engagement.place, "cue": engagement.cue,
			"started_ms": engagement.started_ms, "duration_ms": engagement.duration_ms,
			"remaining_ms": maxi(0, int(engagement.release_at_ms) - int(_state.elapsed_ms))})
	return result


func _project_shared_bonds() -> Array:
	var thresholds: Dictionary = _definition.social.bond_thresholds
	var result: Array = []
	var pairs: Dictionary = {}
	for encounter: Array in _state.encounters:
		pairs[_pair_key(str(encounter[0]), str(encounter[1]))] = [str(encounter[0]), str(encounter[1])]
	for edge: Dictionary in _state.bonds:
		pairs[_pair_key(edge.actor_a, edge.actor_b)] = [edge.actor_a, edge.actor_b]
	for key: String in pairs:
		var pair: Array = pairs[key]
		var strength: int = _bond_strength(pair[0], pair[1])
		result.append({"actor_a": pair[0], "actor_b": pair[1],
			"strength": strength, "tier": SocialGraphScript.get_tier(strength),
			"tier_name": SocialGraphScript.get_tier_name(SocialGraphScript.get_tier(strength)),
			"bond_type": SocialGraphScript.get_bond_type(strength, thresholds),
			"encounter_count": int(_state.encounter_counts.get(key, 0)),
			"last_event_id": int(_state.bond_last_events.get(key, 0))})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return "%s|%s" % [a.actor_a, a.actor_b] < "%s|%s" % [b.actor_a, b.actor_b])
	return result


func _project_echo_bonds(actor_id: String) -> Array:
	var thresholds: Dictionary = _definition.social.bond_thresholds
	var partner_ids: Array = SocialGraphScript.get_encounters_for_actor(_state.encounters, actor_id)
	var result: Array = []
	for other_id: String in partner_ids:
		var other: Dictionary = _echo(other_id)
		var strength: int = _bond_strength(actor_id, other_id)
		var key: String = _pair_key(actor_id, other_id)
		result.append({"other_id": other_id, "name": other.get("name", "Unknown Echo"),
			"strength": strength, "tier": SocialGraphScript.get_tier(strength),
			"tier_name": SocialGraphScript.get_tier_name(SocialGraphScript.get_tier(strength)),
			"bond_type": SocialGraphScript.get_bond_type(strength, thresholds),
			"encounter_count": int(_state.encounter_counts.get(key, 0)),
			"last_event_id": int(_state.bond_last_events.get(key, 0))})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.tier) != int(b.tier):
			return int(a.tier) < int(b.tier)
		if str(a.name) != str(b.name):
			return str(a.name) < str(b.name)
		return str(a.other_id) < str(b.other_id))
	return result


func _impressions_for(owner_id: String) -> Array:
	var result: Array = []
	for impression: Dictionary in _state.impressions:
		if impression.owner_id == owner_id:
			result.append(impression.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.expires_ms) != int(b.expires_ms):
			return int(a.expires_ms) < int(b.expires_ms)
		return "%s|%s" % [a.other_id, a.family] < "%s|%s" % [b.other_id, b.family])
	return result


func _project_incidents() -> Array:
	var result: Array = []
	for incident: Dictionary in _state.incidents:
		var deadline: int = int(incident.release_at_ms) if incident.status == "resolved" else int(incident.intervention_deadline_ms) if incident.status == "joined" else int(incident.stage_deadline_ms)
		var choices: Array = []
		if incident.status == "joined":
			for reply: Dictionary in _definition.social.incidents[incident.family].replies:
				choices.append({"id": reply.id, "label": reply.label,
					"consequence_cue": reply.consequence_cue.duplicate(true)})
		var projected: Dictionary = {"id": incident.id, "family": incident.family,
			"template_id": incident.template_id, "label": incident.label,
			"status": incident.status, "participants": incident.participants.duplicate(),
			"place": incident.place, "cause": incident.cause, "created_ms": incident.created_ms,
			"stage_started_ms": incident.stage_started_ms,
			"stage_deadline_ms": incident.stage_deadline_ms,
			"intervention_deadline_ms": incident.intervention_deadline_ms,
			"remaining_ms": maxi(0, deadline - int(_state.elapsed_ms)),
			"keeper_access": incident.get("keeper_access", "private"),
			"appeal_echo_id": incident.get("appeal_echo_id", ""),
			"access_reason": incident.get("access_reason", ""),
			"exchange_lines": incident.get("exchange_lines", []).duplicate(true),
			"can_join": _can_join_incident(incident),
			"reply_choices": choices, "result": incident.result.duplicate(true),
			"release_at_ms": incident.release_at_ms}
		if not incident.get("witnesses", []).is_empty():
			projected["witnesses"] = incident.witnesses.duplicate(true)
		result.append(projected)
	return result


func _build_village_history(events: Array) -> Array:
	var result: Array = []
	var auxiliaries: Dictionary = _history_auxiliaries(events)
	for index: int in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if not bool(event.significant) or _is_history_auxiliary(event):
			continue
		var summary: Dictionary = event.duplicate(true)
		summary["source_ids"] = [event.id]
		summary["source_count"] = 1
		summary["activity_count"] = 0
		summary["first_step"] = event.step
		summary["first_elapsed_ms"] = event.elapsed_ms
		summary["first_day"] = event.day
		summary["first_day_phase"] = event.day_phase
		summary["latest_step"] = event.step
		summary["latest_elapsed_ms"] = event.elapsed_ms
		summary["latest_day"] = event.day
		summary["latest_day_phase"] = event.day_phase
		_fold_history_auxiliaries(summary, auxiliaries.get(event.id, []))
		result.append(summary)
	return result
