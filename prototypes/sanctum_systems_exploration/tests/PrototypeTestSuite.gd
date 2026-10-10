extends RefCounted
## Gate 1 contract tests. Fixture mutation is confined to this test harness.

const Simulation = preload("res://prototypes/sanctum_systems_exploration/simulation/PrototypeSimulation.gd")
const Archetypes = preload("res://core/echoes/PersonalityArchetype.gd")
const Emotion = preload("res://core/emotion/EmotionService.gd")
const PLACEMENTS := {"hearth": "hearth_near", "training": "training_far"}
const FAMILIES := ["rest", "company", "purpose"]
const ARCHETYPES := ["loyal", "proud", "reflective", "empathic", "canny", "stoic"]
const EMOTIONS := [[72, 15], [78, 12], [58, 28], [62, 22], [74, 10], [35, 68]]


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var sim = Simulation.new()
	var ready: bool = sim.has_method("advance_step") and sim.has_method("get_step") and sim.has_method("is_living")
	_check(results, "contract/fixed_step_api_available", ready)
	if not ready:
		return results
	_setup_and_projection(results)
	_calendar(results)
	_travel(results)
	_occupancy(results)
	_tuning_and_traits(results)
	_conversation(results)
	_replay_and_reset(results)
	_history_bundling(results)
	_history(results)
	_isolation(results)
	return results


static func _isolation(results: Array[Dictionary]) -> void:
	var isolated := true
	for path: String in ["PrototypeController.gd", "SanctumLivingHouse.tscn", "simulation/PrototypeSimulation.gd", "ui/PrototypeUI.gd", "ui/PrototypeUI.tscn", "ui/PrototypeHouseView.gd"]:
		var source := FileAccess.get_file_as_string("res://prototypes/sanctum_systems_exploration/" + path)
		for forbidden: String in ["SaveService", "FlowRuntime", "FlowContext", "res://core/save/", "user://"]:
			isolated = isolated and not source.contains(forbidden)
	_check(results, "isolation/prototype_does_not_reference_production_save_or_runtime", isolated)


static func _setup_and_projection(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	_check(results, "setup/requires_both_places", not _act(sim, "house.start"))
	_check(results, "setup/rejects_mismatched_site", not _act(sim, "house.place", {"institution": "hearth", "site": "training_far"}))
	var setup: Dictionary = sim.get_state()
	_check(results, "step/setup_does_not_advance", not sim.advance_step(1) and sim.get_state() == setup)
	var connected := true
	var lengths: Array[float] = []
	for hearth: String in ["hearth_near", "hearth_far"]:
		for training: String in ["training_near", "training_far"]:
			sim.reset(41, {"hearth": hearth, "training": training})
			var nodes: Dictionary = sim.get_definition().waypoints
			for from_node: String in nodes:
				for to_node: String in nodes:
					var path: Array = sim.route(from_node, to_node)
					connected = connected and (from_node == to_node or not path.is_empty())
					var previous := from_node
					for node: String in path:
						connected = connected and nodes[previous].links.has(node)
						previous = node
			lengths.append(_route_distance(sim, "courtyard", sim.place_node("hearth")))
	_check(results, "layout/all_four_placements_use_connected_authored_routes", connected)
	_check(results, "layout/placement_changes_actual_travel_distance", not is_equal_approx(lengths[0], lengths[2]))
	_start(sim)
	_check(results, "setup/living_query_and_no_relocation", sim.is_living() and not _act(sim, "house.place", {"institution": "hearth", "site": "hearth_far"}))
	var before: Dictionary = sim.get_state()
	_check(results, "step/rejects_wrong_index_without_mutation", not sim.advance_step(9) and sim.get_state() == before)
	_check(results, "action/rejects_wrong_step", not sim.apply_action({"type": "prototype.tuning.set", "payload": {"key": "rest_weight", "value": 2}}, 9))
	var data: Dictionary = sim.build_snapshot_data()
	var all_identity: bool = data.echoes.size() == 6
	for index: int in range(data.echoes.size()):
		var echo: Dictionary = data.echoes[index]
		var traits: Dictionary = echo.get("traits", {})
		var derived := Archetypes.from_traits(int(traits.get("courage", 0)), int(traits.get("wisdom", 0)), int(traits.get("faith", 0)))
		all_identity = all_identity and derived == ARCHETYPES[index] and echo.get("archetype", "") == derived
		all_identity = all_identity and echo.get("emotional_status", "") == Emotion.get_emotional_status(EMOTIONS[index][0], EMOTIONS[index][1])
	_check(results, "fixture/canonical_traits_archetypes_and_original_emotions", all_identity)
	_check(results, "snapshot/step_contract", data.get("step_ms", 0) == 250 and data.get("next_beat_steps", 0) == 240 and data.get("elapsed_ms", -1) == 0)
	data.echoes[0].name = "mutated"
	data.waypoints.clear()
	var state_copy: Dictionary = sim.get_state()
	state_copy.echoes.clear()
	var definition_copy: Dictionary = sim.get_definition()
	definition_copy.waypoints.clear()
	_check(results, "snapshot/state_and_definition_are_independent_copies", sim.get_state().echoes[0].name == "Kojo" and sim.get_definition().waypoints.size() > 0)
	_steps(sim, 16)
	var normal: Dictionary = sim.build_snapshot_data()
	var debug: Dictionary = sim.build_snapshot_data(true)
	var private_hidden := not normal.has("commands") and not normal.has("initial")
	var needs_valid := true
	var debug_valid := true
	for echo: Dictionary in normal.echoes:
		for key: String in ["fear", "morale", "pressures", "bias", "preferences", "candidates", "competing_reason", "exchanges"]:
			private_hidden = private_hidden and not echo.has(key)
		for family: String in FAMILIES:
			var need: Dictionary = echo.get("needs", {}).get(family, {})
			needs_valid = needs_valid and float(need.get("value", -1)) >= 0 and float(need.get("value", INF)) <= float(need.get("max", -1)) and not str(need.get("label", "")).is_empty()
	for echo: Dictionary in debug.echoes:
		debug_valid = debug_valid and not str(echo.get("reason", "")).is_empty() and not str(echo.get("competing_reason", "")).is_empty()
		var candidates: Array = echo.get("candidates", [])
		debug_valid = debug_valid and candidates.size() == 3
		for candidate: Dictionary in candidates:
			debug_valid = debug_valid and candidate.has_all(["family", "place", "score", "reason"]) and is_finite(float(candidate.score)) and not candidate.get("factors", []).is_empty()
	_check(results, "snapshot/normal_hides_internal_state", private_hidden)
	_check(results, "snapshot/need_values_bounded_and_labeled", needs_valid)
	_check(results, "intent/debug_exposes_three_real_explained_candidates", debug_valid)


static func _calendar(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	_start(sim)
	_check(results, "calendar/starts_day_one_morning_twelve_minutes", sim.build_snapshot_data().clock.day == 1 and sim.build_snapshot_data().clock.phase == "morning" and sim.build_snapshot_data().clock.day_minutes == 12)
	_steps(sim, 720)
	var clock: Dictionary = sim.build_snapshot_data().clock
	_check(results, "calendar/quarter_day_is_afternoon", clock.day == 1 and clock.phase == "afternoon" and is_equal_approx(float(clock.progress), 0.25))
	var old_state: Dictionary = sim.get_state()
	_act(sim, "tuning.set", {"key": "day_minutes", "value": 3})
	var new_clock: Dictionary = sim.build_snapshot_data().clock
	_check(results, "calendar/live_tuning_preserves_fraction_and_monotonic_time", is_equal_approx(float(new_clock.progress), float(clock.progress)) and sim.get_state().elapsed_ms == old_state.elapsed_ms)
	_check(results, "calendar/tuning_does_not_rescale_travel_or_commitments", sim.get_state().echoes == old_state.echoes)
	_steps(sim, 180)
	clock = sim.build_snapshot_data().clock
	_check(results, "calendar/new_length_changes_only_future_speed", clock.phase == "evening" and is_equal_approx(float(clock.progress), 0.5))
	_steps(sim, 360)
	clock = sim.build_snapshot_data().clock
	_check(results, "calendar/cycle_wrap_increments_day", clock.day == 2 and clock.phase == "morning" and is_zero_approx(float(clock.progress)) and sim.get_state().elapsed_ms == 315000)


static func _travel(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	_start(sim)
	var nodes: Dictionary = sim.get_definition().waypoints
	var legal := true
	var interior := false
	var stable_node := false
	var arrival_seen := false
	var routine_starts_on_arrival := true
	var arrival_events_real := true
	var bounded_distance := true
	var step_distance: float = float(sim.get_definition().rules.travel_units_per_second) * 0.25
	for index: int in range(320):
		var before: Dictionary = sim.build_snapshot_data()
		_steps(sim, 1)
		var after: Dictionary = sim.build_snapshot_data()
		for echo: Dictionary in after.echoes:
			var previous := _echo(before, echo.id)
			var p := _vector(echo.position)
			bounded_distance = bounded_distance and _vector(previous.position).distance_to(p) <= step_distance + 0.0001
			var node_position := _vector(nodes[echo.node].pos)
			if echo.moving:
				legal = legal and not echo.path.is_empty()
				if not echo.path.is_empty():
					var target: String = echo.path[0]
					legal = legal and nodes[echo.node].links.has(target) and _on_segment(p, node_position, _vector(nodes[target].pos))
					interior = interior or (p.distance_to(node_position) > 0.00001 and p.distance_to(_vector(nodes[target].pos)) > 0.00001)
				stable_node = stable_node or (previous.node == echo.node and _vector(previous.position).distance_to(p) > 0.00001)
				if previous.moving and previous.destination == echo.destination:
					routine_starts_on_arrival = routine_starts_on_arrival and int(echo.remaining_ms) == int(previous.remaining_ms)
			else:
				legal = legal and p.distance_to(node_position) < 0.0001
				if previous.moving:
					arrival_seen = true
					routine_starts_on_arrival = routine_starts_on_arrival and int(echo.remaining_ms) > 0
		for event: Dictionary in after.events:
			if event.step == after.step and event.kind == "arrival":
				var previous := _echo(before, event.participants[0])
				var current := _echo(after, event.participants[0])
				arrival_events_real = arrival_events_real and previous.moving and previous.node != current.node
	_check(results, "travel/continuous_positions_follow_authored_edges", legal and interior and stable_node)
	_check(results, "travel/distance_per_step_is_bounded_by_speed", bounded_distance)
	_check(results, "travel/arrival_starts_routine_not_travel", arrival_seen and routine_starts_on_arrival)
	_check(results, "history/arrival_events_require_actual_travel", arrival_events_real and arrival_seen)
	var different = Simulation.new()
	different.reset(73, PLACEMENTS)
	_act(different, "house.start")
	_steps(different, 16)
	var same = Simulation.new()
	_start(same)
	_steps(same, 16)
	_check(results, "routine/seed_changes_stagger_or_duration", _behavior_signature(same.get_state()) != _behavior_signature(different.get_state()))


static func _occupancy(results: Array[Dictionary]) -> void:
	var arriving = _occupancy_fixture(true, false)
	var reverse = _occupancy_fixture(true, true)
	var departing = _occupancy_fixture(false, false)
	for sim in [arriving, reverse, departing]:
		_steps(sim, 1)
	var a := _echo(arriving.get_state(), "chooser")
	var r := _echo(reverse.get_state(), "chooser")
	var d := _echo(departing.get_state(), "chooser")
	_check(results, "occupancy/decisions_consume_same_step_arrivals", is_equal_approx(_factor_score(a, "company", "occupancy"), 2.0))
	_check(results, "occupancy/travelers_last_node_is_not_here_now", is_zero_approx(_factor_score(d, "company", "occupancy")))
	_check(results, "occupancy/roster_order_does_not_change_candidate_context", a.candidates == r.candidates and a.destination == r.destination)
	_check(results, "occupancy/real_crowding_changes_candidate_score", _score(a, "company") > _score(d, "company"))


static func _occupancy_fixture(arriving: bool, reverse: bool):
	var sim = Simulation.new()
	_start(sim)
	var state: Dictionary = sim.get_state()
	var chooser: Dictionary = state.echoes[0].duplicate(true)
	chooser.merge({"id": "chooser", "node": "flame", "position": sim.get_definition().waypoints.flame.pos.duplicate(), "remaining_ms": 250,
		"sociability": 1.0, "preferences": {"rest": ["flame"], "company": ["quiet"], "purpose": ["flame"]}}, true)
	var visitor: Dictionary = state.echoes[1].duplicate(true)
	var nodes: Dictionary = sim.get_definition().waypoints
	var quiet := _vector(nodes.quiet.pos)
	var west := _vector(nodes.west.pos)
	var position := quiet.move_toward(west, 0.1)
	visitor.merge({"id": "visitor", "node": "west" if arriving else "quiet", "position": [position.x, position.y],
		"moving": true, "path": ["quiet"] if arriving else ["west"], "destination": "quiet", "family": "rest", "activity": "roaming", "duration_ms": 30000, "remaining_ms": 0}, true)
	state.echoes = [visitor, chooser] if reverse else [chooser, visitor]
	sim.set("_state", state)
	return sim


static func _tuning_and_traits(results: Array[Dictionary]) -> void:
	for family: String in FAMILIES:
		var low = _fixture_sim({"traits": {"courage": 55, "wisdom": 55, "faith": 55}}, {family + "_weight": 0})
		var high = _fixture_sim({"traits": {"courage": 55, "wisdom": 55, "faith": 55}}, {family + "_weight": 3})
		_steps(low, 16)
		_steps(high, 16)
		_check(results, "tuning/%s_weight_changes_actual_candidate_score" % family, _score(high.get_state().echoes[0], family) > _score(low.get_state().echoes[0], family))
		_check(results, "tuning/%s_weight_changes_real_choice" % family, _find_choice_boundary("weight", family))
	for trait_key: String in ["courage", "wisdom", "faith"]:
		var low_traits := {"courage": 55, "wisdom": 55, "faith": 55}
		var high_traits := low_traits.duplicate()
		low_traits[trait_key] = 30
		high_traits[trait_key] = 80
		var low = _fixture_sim({"traits": low_traits})
		var high = _fixture_sim({"traits": high_traits})
		_steps(low, 16)
		_steps(high, 16)
		var differs := false
		for family: String in FAMILIES:
			differs = differs or not is_equal_approx(_score(low.get_state().echoes[0], family), _score(high.get_state().echoes[0], family))
		_check(results, "traits/%s_reaches_real_scores" % trait_key, differs)
		_check(results, "traits/%s_changes_real_choice" % trait_key, _find_choice_boundary("trait", trait_key))
	var short = _fixture_sim({}, {"routine_seconds": 10})
	var long = _fixture_sim({}, {"routine_seconds": 90})
	_await_routine(short)
	_await_routine(long)
	_check(results, "tuning/routine_seconds_reaches_commitment", int(long.get_state().echoes[0].remaining_ms) > int(short.get_state().echoes[0].remaining_ms))
	var faith_low = _fixture_sim({"traits": {"courage": 55, "wisdom": 55, "faith": 30}})
	var faith_high = _fixture_sim({"traits": {"courage": 55, "wisdom": 55, "faith": 80}})
	_await_routine(faith_low)
	_await_routine(faith_high)
	_check(results, "traits/faith_changes_actual_routine_persistence", int(faith_high.get_state().echoes[0].remaining_ms) > int(faith_low.get_state().echoes[0].remaining_ms))
	_check(results, "emotion/fear_changes_real_choice_without_new_rewards", _find_choice_boundary("emotion", "fear"))
	_check(results, "tuning/rejects_unknown_nan_and_obsolete_keys", not _act(long, "tuning.set", {"key": "unknown", "value": 1}) and not _act(long, "tuning.set", {"key": "rest_weight", "value": NAN}) and not _act(long, "tuning.set", {"key": "pulse_seconds", "value": 3}) and not _act(long, "tuning.set", {"key": "routine_pulses", "value": 4}))
	var instant_before: Dictionary = long.get_state().echoes[0]
	_act(long, "tuning.set", {"key": "routine_seconds", "value": 10})
	_check(results, "tuning/active_commitment_is_not_rescaled", long.get_state().echoes[0] == instant_before)


static func _find_choice_boundary(kind: String, key: String) -> bool:
	# Small plausible pressure grid; never alter production data or assert only arithmetic.
	for rest: int in [6, 10, 14]:
		for company: int in [6, 10, 14]:
			for purpose: int in [6, 10, 14]:
				var overrides := {"pressures": {"rest": rest, "company": company, "purpose": purpose},
					"bias": {"rest": 0, "company": 0, "purpose": 0}, "traits": {"courage": 55, "wisdom": 55, "faith": 55},
					"morale": 50, "fear": 20}
				var high_overrides: Dictionary = overrides.duplicate(true)
				var low_tuning: Dictionary = {}
				var high_tuning: Dictionary = {}
				if kind == "trait":
					overrides.traits[key] = 30
					high_overrides.traits[key] = 80
				elif kind == "emotion":
					overrides[key] = 0
					high_overrides[key] = 80
				else:
					low_tuning[key + "_weight"] = 0
					high_tuning[key + "_weight"] = 3
				var low = _fixture_sim(overrides, low_tuning)
				var high = _fixture_sim(high_overrides, high_tuning)
				_steps(low, 16)
				_steps(high, 16)
				var left: Dictionary = low.get_state().echoes[0]
				var right: Dictionary = high.get_state().echoes[0]
				if left.family != right.family or left.destination != right.destination:
					return true
	return false


static func _conversation(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	_start(sim)
	var stationary: Dictionary = sim.get_state().echoes[0]
	_act(sim, "conversation.begin", {"echo_id": stationary.id})
	_check(results, "conversation/stationary_enters_choosing", sim.get_state().conversation.status == "choosing")
	_check(results, "conversation/only_one_reservation", sim.get_state().echoes.filter(func(e: Dictionary) -> bool: return e.reserved).size() == 1 and not _act(sim, "conversation.begin", {"echo_id": "yaw"}))
	var held_before := _echo(sim.get_state(), stationary.id)
	_steps(sim, 240)
	var held_after := _echo(sim.get_state(), stationary.id)
	_check(results, "conversation/held_echo_accumulates_no_pressure_or_reward", held_after.pressures == held_before.pressures and held_after.position == held_before.position and held_after.fear == held_before.fear and held_after.morale == held_before.morale)
	_check(results, "conversation/others_continue", sim.get_state().echoes[1].position != stationary.position or int(sim.get_state().echoes[1].decisions) > 0)
	_act(sim, "conversation.cancel")
	_check(results, "conversation/cancel_has_no_intervention", not _echo(sim.get_state(), stationary.id).reserved and _echo(sim.get_state(), stationary.id).exchanges.is_empty())
	_check(results, "conversation/cancel_idle_restores_idle_until_decision", _echo(sim.get_state(), stationary.id).activity == "idle" and _echo(sim.get_state(), stationary.id).remaining_ms == held_before.remaining_ms)
	_start(sim)
	var mover := _find_mover(sim)
	_check(results, "conversation/moving_fixture_reached", not mover.is_empty())
	if mover.is_empty():
		return
	var target: String = mover.path[0]
	_act(sim, "conversation.begin", {"echo_id": mover.id})
	_check(results, "conversation/moving_enters_approaching_without_teleport", sim.get_state().conversation.status == "approaching" and _echo(sim.get_state(), mover.id).position == mover.position)
	_check(results, "conversation/approach_disables_topic_and_reply", not _act(sim, "conversation.topic", {"topic": "feelings"}) and not _act(sim, "conversation.reply", {"reply": "company"}))
	var approaching_pressures: Dictionary = _echo(sim.get_state(), mover.id).pressures
	var reached := _await_choosing(sim)
	var arrived := _echo(sim.get_state(), mover.id)
	_check(results, "conversation/approach_holds_at_next_waypoint", reached and arrived.node == target and not arrived.moving and arrived.pressures == approaching_pressures)
	_act(sim, "conversation.topic", {"topic": "feelings"})
	_check(results, "conversation/reply_commits", _act(sim, "conversation.reply", {"reply": "company"}))
	var committed: Dictionary = sim.get_state()
	_check(results, "conversation/result_has_reason_line_and_deadline", committed.conversation.status == "resolved" and committed.conversation.release_at_ms == committed.elapsed_ms + 1500 and not str(committed.conversation.get("reason", "")).is_empty() and not str(committed.conversation.get("line", "")).is_empty())
	_check(results, "conversation/commit_cannot_cancel_repeat_or_external_release", not _act(sim, "conversation.cancel") and not _act(sim, "conversation.reply", {"reply": "space"}) and not _act(sim, "conversation.release"))
	_act(sim, "tuning.set", {"key": "day_minutes", "value": 3})
	_check(results, "conversation/day_tuning_preserves_release_deadline", sim.get_state().conversation.release_at_ms == committed.conversation.release_at_ms)
	_steps(sim, 5)
	_check(results, "conversation/result_remains_for_first_five_steps", sim.get_state().conversation.status == "resolved")
	_steps(sim, 1)
	_check(results, "conversation/simulation_releases_at_six_steps", sim.get_state().conversation.is_empty() and not _echo(sim.get_state(), mover.id).reserved)
	_act(sim, "conversation.begin", {"echo_id": mover.id})
	_await_choosing(sim)
	_act(sim, "conversation.topic", {"topic": "feelings"})
	var repeat_before := _echo(sim.get_state(), mover.id)
	var events_before: Array = sim.get_state().events
	_act(sim, "conversation.reply", {"reply": "company"})
	var repeat_after := _echo(sim.get_state(), mover.id)
	_check(results, "conversation/repeated_reply_cannot_farm_or_add_history", sim.get_state().conversation.outcome == "repeated" and repeat_before.pressures == repeat_after.pressures and repeat_before.fear == repeat_after.fear and repeat_before.morale == repeat_after.morale and events_before == sim.get_state().events)
	_steps(sim, 6)
	var decision_before: int = _echo(sim.get_state(), mover.id).decisions
	for index: int in range(800):
		if int(_echo(sim.get_state(), mover.id).decisions) > decision_before:
			break
		_steps(sim, 1)
	_act(sim, "conversation.begin", {"echo_id": mover.id})
	_await_choosing(sim)
	_act(sim, "conversation.topic", {"topic": "feelings"})
	var response_count: int = sim.get_state().events.filter(func(e: Dictionary) -> bool: return e.kind == "response").size()
	_act(sim, "conversation.reply", {"reply": "company"})
	_check(results, "conversation/new_autonomous_context_reevaluates_same_offer", int(_echo(sim.get_state(), mover.id).decisions) > decision_before and sim.get_state().conversation.outcome != "repeated" and sim.get_state().events.filter(func(e: Dictionary) -> bool: return e.kind == "response").size() == response_count + 1)
	_start(sim)
	mover = _find_mover(sim)
	_act(sim, "conversation.begin", {"echo_id": mover.id})
	var cancel_before := _echo(sim.get_state(), mover.id)
	_act(sim, "conversation.cancel")
	var cancelled := _echo(sim.get_state(), mover.id)
	_check(results, "conversation/cancel_approach_resumes_without_intervention", sim.get_state().conversation.is_empty() and not cancelled.reserved and cancelled.position == cancel_before.position and cancelled.pressures == cancel_before.pressures and cancelled.exchanges.is_empty())


static func _replay_and_reset(results: Array[Dictionary]) -> void:
	var a = Simulation.new()
	_start(a)
	_act(a, "tuning.set", {"key": "company_weight", "value": 2.3})
	_act(a, "conversation.begin", {"echo_id": "yaw"})
	_act(a, "conversation.topic", {"topic": "feelings"})
	_act(a, "conversation.reply", {"reply": "company"})
	for t: int in range(1, 321):
		a.advance_step(t)
		if t == 27:
			_act(a, "tuning.set", {"key": "day_minutes", "value": 3})
			_act(a, "tuning.set", {"key": "routine_seconds", "value": 15})
		if t == 80:
			_act(a, "tuning.set", {"key": "purpose_weight", "value": 0.2})
	var recording: Dictionary = a.get_state()
	var b = Simulation.new()
	b.reset(recording.initial.seed, recording.initial.placements, recording.initial.tuning)
	var ordered := true
	var last_order := -1
	for t: int in range(321):
		if t > 0:
			b.advance_step(t)
		for command: Dictionary in recording.commands:
			if command.step == t:
				ordered = ordered and int(command.order) > last_order
				last_order = int(command.order)
				b.apply_action(command.action, t)
	_check(results, "replay/ordered_commands_tuning_events_and_positions_match", ordered and a.get_state() == b.get_state())
	b.reset(recording.seed, recording.placements, recording.tuning)
	var reset: Dictionary = b.get_state()
	var reset_data: Dictionary = b.build_snapshot_data()
	_check(results, "reset/clears_history_commands_reservations_and_time", reset.step == 0 and reset.elapsed_ms == 0 and reset.commands.is_empty() and reset.events.is_empty() and reset.beats.is_empty() and reset.conversation.is_empty() and reset.echoes.all(func(e: Dictionary) -> bool: return not e.reserved and e.exchanges.is_empty()) and reset_data.echoes.all(func(e: Dictionary) -> bool: return e.history.is_empty()) and reset_data.place_history.values().all(func(history: Array) -> bool: return history.is_empty()))
	_check(results, "reset/preserves_explicit_setup_and_tuning", reset.placements == recording.placements and reset.tuning == recording.tuning)
	var independent = Simulation.new()
	_check(results, "reset/repeated_fixture_ids_have_no_cross_instance_history", independent.get_state().events.is_empty())


static func _history_bundling(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	_start(sim)
	var state: Dictionary = sim.get_state()
	state.events = [
		_history_event(101, 1, "arrival", "kojo", "quiet", "Kojo arrived at the Quiet Grove."),
		_history_event(102, 2, "routine_completed", "kojo", "quiet", "Kojo finished resting."),
		_history_event(103, 3, "response", "kojo", "quiet", "Kojo accepted the Keeper's suggestion."),
		_history_event(104, 4, "activity_started", "kojo", "quiet", "Kojo began reflecting."),
		_history_event(105, 5, "arrival", "kojo", "courtyard", "Kojo arrived at the Courtyard."),
		_history_event(106, 6, "activity_started", "ama", "quiet", "Ama began resting."),
		_history_event(107, 7, "routine_completed", "kojo", "courtyard", "Kojo finished keeping company.")
	]
	sim.set("_state", state)
	var data: Dictionary = sim.build_snapshot_data()
	var kojo_history: Array = _echo(data, "kojo").history
	var quiet_history: Array = data.place_history.quiet
	var courtyard_history: Array = data.place_history.courtyard
	var kojo_quiet: Dictionary = _summary_with_sources(kojo_history, [101, 102, 104])
	var response: Dictionary = _summary_with_sources(kojo_history, [103])
	var kojo_courtyard: Dictionary = _summary_with_sources(kojo_history, [105, 107])
	_check(results, "history/raw_events_remain_unbundled_and_authoritative", data.events.size() == 7 and data.events.map(func(event: Dictionary) -> int: return int(event.id)) == [101, 102, 103, 104, 105, 106, 107])
	_check(results, "history/same_place_activity_bundles_across_standalone_reply", not kojo_quiet.is_empty() and kojo_quiet.kind == "visit" and kojo_quiet.activity_count == 2 and kojo_quiet.source_count == 3)
	_check(results, "history/new_place_starts_new_visit_summary", not kojo_courtyard.is_empty() and kojo_courtyard.kind == "visit" and kojo_courtyard.place == "courtyard" and kojo_history.size() == 3)
	_check(results, "history/keeper_reply_remains_standalone", not response.is_empty() and response.kind == "response" and response.activity_count == 0 and response.source_count == 1)
	_check(results, "history/person_and_place_share_identical_visit_values", quiet_history.has(kojo_quiet) and quiet_history.has(response) and courtyard_history.has(kojo_courtyard))
	var raw_before: Array = data.events.duplicate(true)
	kojo_quiet.source_ids.clear()
	data.events[0].text = "mutated"
	var fresh: Dictionary = sim.build_snapshot_data()
	_check(results, "history/raw_and_summary_projection_are_deep_copies", fresh.events == raw_before and _summary_with_sources(_echo(fresh, "kojo").history, [101, 102, 104]).source_count == 3)


static func _history_event(id: int, step: int, kind: String, echo_id: String, place: String, text: String) -> Dictionary:
	return {"id": id, "step": step, "elapsed_ms": step * 250, "day": 1,
		"day_phase": "morning", "kind": kind, "participants": [echo_id], "place": place,
		"text": text, "cause": "Tested enacted cause %d." % id,
		"aftermath": "Tested enacted aftermath %d." % id, "significant": kind == "response"}


static func _summary_with_sources(history: Array, source_ids: Array) -> Dictionary:
	for summary: Dictionary in history:
		if summary.get("source_ids", []) == source_ids:
			return summary
	return {}


static func _history(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	_start(sim, {"routine_seconds": 10, "day_minutes": 3})
	var valid := true
	var actual_place := true
	var previous_ids: Dictionary = {}
	var first_id: Variant = null
	var saw_complete := false
	var completion_aftermath_valid := true
	for index: int in range(12000):
		_steps(sim, 1)
		# Inspect every early event and periodically after that; motion must not flood retention.
		if index > 400 and index % 40 != 0:
			continue
		var state: Dictionary = sim.get_state()
		for event: Dictionary in state.events:
			valid = valid and event.has_all(["id", "step", "elapsed_ms", "day", "day_phase", "kind", "participants", "place", "text", "cause", "aftermath", "significant"])
			if not event.has("id"):
				continue
			if first_id == null:
				first_id = event.id
			valid = valid and int(event.step) <= sim.get_step() and int(event.elapsed_ms) == int(event.step) * 250 and not str(event.text).is_empty() and not event.participants.is_empty()
			valid = valid and not str(event.kind) in ["move", "movement", "conversation_started", "conversation_cancelled"]
			saw_complete = saw_complete or "complete" in str(event.kind)
			if event.kind == "routine_completed":
				completion_aftermath_valid = completion_aftermath_valid and event.aftermath == "Ready to choose what comes next."
			if int(event.step) == sim.get_step() and not previous_ids.has(event.id):
				# An impression expiry is a directional state change at its owner's
				# current location; the remembered counterpart need not still be there.
				var located_participants: Array = [event.participants[0]] if event.kind == "impression" and event.get("title", "") == "An impression faded" else event.participants
				for id: String in located_participants:
					var person := _echo(state, id)
					if not str(event.place).is_empty():
						actual_place = actual_place and not person.is_empty() and person.node == sim.place_node(event.place)
			previous_ids[event.id] = true
		if state.events.size() == 512 and first_id != null and not state.events.any(func(e: Dictionary) -> bool: return e.id == first_id):
			break
	var data: Dictionary = sim.build_snapshot_data()
	var retained: Dictionary = {}
	for event: Dictionary in data.events:
		retained[event.id] = event
	var projections_valid := true
	for echo: Dictionary in data.echoes:
		projections_valid = projections_valid and _history_subset(echo.history, retained, echo.id, "")
	for place: String in data.place_history:
		projections_valid = projections_valid and _history_subset(data.place_history[place], retained, "", place)
	var shared_values := true
	for echo: Dictionary in data.echoes:
		for summary: Dictionary in echo.history:
			if not str(summary.place).is_empty():
				shared_values = shared_values and data.place_history.get(summary.place, []).has(summary)
	_check(results, "history/real_schema_times_and_no_motion_spam", valid and saw_complete and data.events.size() > 20)
	_check(results, "history/completion_aftermath_describes_finished_commitment", saw_complete and completion_aftermath_valid)
	_check(results, "history/events_record_actual_location", actual_place)
	var no_pruned_sources := true
	for echo: Dictionary in data.echoes:
		for summary: Dictionary in echo.history:
			no_pruned_sources = no_pruned_sources and not summary.source_ids.has(first_id)
	_check(results, "history/retention_bounded_and_old_records_pruned", data.events.size() <= 512 and first_id != null and not retained.has(first_id) and no_pruned_sources)
	_check(results, "history/person_and_place_views_share_retained_summaries_newest_first", projections_valid and shared_values)


static func _history_subset(history: Array, retained: Dictionary, echo_id: String, place: String) -> bool:
	var last_step := 2147483647
	for summary: Dictionary in history:
		if not summary.has_all(["id", "kind", "participants", "place", "text", "cause", "aftermath", "significant", "source_ids", "source_count", "activity_count", "first_step", "first_elapsed_ms", "first_day", "first_day_phase", "latest_step", "latest_elapsed_ms", "latest_day", "latest_day_phase", "step", "elapsed_ms", "day", "day_phase"]):
			return false
		var source_ids: Array = summary.source_ids
		if source_ids.is_empty() or int(summary.source_count) != source_ids.size() or int(summary.id) != int(source_ids[-1]) or int(summary.latest_step) > last_step:
			return false
		if summary.step != summary.latest_step or summary.elapsed_ms != summary.latest_elapsed_ms or summary.day != summary.latest_day or summary.day_phase != summary.latest_day_phase:
			return false
		if not echo_id.is_empty() and not summary.participants.has(echo_id):
			return false
		if not place.is_empty() and summary.place != place:
			return false
		for source_index: int in range(source_ids.size()):
			var source_id: int = source_ids[source_index]
			if not retained.has(source_id):
				return false
			var raw: Dictionary = retained[source_id]
			if raw.place != summary.place:
				return false
			if source_index == 0 and (not echo_id.is_empty() and not raw.participants.has(echo_id) or not summary.participants.all(func(participant: String) -> bool: return raw.participants.has(participant))):
				return false
			if source_index > 0 and not raw.participants.all(func(participant: String) -> bool: return summary.participants.has(participant)):
				return false
		if summary.kind == "visit":
			if int(summary.activity_count) < 1 or not source_ids.all(func(source_id: int) -> bool: return retained[source_id].kind in ["arrival", "activity_started", "routine_completed"]):
				return false
		elif summary.kind == "response":
			if source_ids.size() != 1 or int(summary.activity_count) != 0 or retained[source_ids[0]].kind != "response":
				return false
		else:
			# Gate 2 significant social/incident records remain standalone just like
			# Keeper responses. Consequence records may fold into one retained parent;
			# the Gate 2 suite enforces their exact kind allowlist and structure.
			if int(summary.activity_count) != 0 or retained[source_ids[0]].kind != summary.kind or not bool(summary.significant):
				return false
			for index: int in range(1, source_ids.size()):
				var auxiliary: Dictionary = retained[source_ids[index]]
				if auxiliary.kind not in ["impression", "emotion_change", "bond_change"] or auxiliary.get("source_event_id", 0) != source_ids[0]:
					return false
		var first: Dictionary = retained[source_ids[0]]
		var latest: Dictionary = retained[source_ids[-1]]
		if summary.first_step != first.step or summary.first_elapsed_ms != first.elapsed_ms or summary.first_day != first.day or summary.first_day_phase != first.day_phase:
			return false
		if summary.latest_step != latest.step or summary.latest_elapsed_ms != latest.elapsed_ms or summary.latest_day != latest.day or summary.latest_day_phase != latest.day_phase:
			return false
		last_step = int(summary.latest_step)
	return true


static func _fixture_sim(overrides: Dictionary = {}, tuning: Dictionary = {}):
	var sim = Simulation.new()
	var fixtures: Array = sim.get("_fixtures").duplicate(true)
	var fixture: Dictionary = fixtures[0]
	fixture.merge(overrides, true)
	sim.set("_fixtures", [fixture])
	sim.reset(41, PLACEMENTS, tuning)
	_act(sim, "house.start")
	return sim


static func _start(sim, tuning: Dictionary = {}) -> void:
	sim.reset(41, {}, tuning)
	_act(sim, "house.place", {"institution": "hearth", "site": "hearth_near"})
	_act(sim, "house.place", {"institution": "training", "site": "training_far"})
	_act(sim, "house.start")


static func _act(sim, suffix: String, payload: Dictionary = {}) -> bool:
	return sim.apply_action({"type": "prototype." + suffix, "payload": payload}, sim.get_step())


static func _steps(sim, count: int) -> void:
	for index: int in range(count):
		sim.advance_step(sim.get_step() + 1)


static func _echo(data: Dictionary, id: String) -> Dictionary:
	for echo: Dictionary in data.echoes:
		if echo.id == id:
			return echo
	return {}


static func _find_mover(sim) -> Dictionary:
	for index: int in range(200):
		_steps(sim, 1)
		for echo: Dictionary in sim.get_state().echoes:
			if echo.get("moving", false):
				return echo
	return {}


static func _await_choosing(sim) -> bool:
	for index: int in range(400):
		if sim.get_state().conversation.get("status", "") == "choosing":
			return true
		_steps(sim, 1)
	return false


static func _score(echo: Dictionary, family: String) -> float:
	for candidate: Dictionary in echo.get("candidates", []):
		if candidate.family == family:
			return float(candidate.score)
	return -INF


static func _factor_score(echo: Dictionary, family: String, source: String) -> float:
	for candidate: Dictionary in echo.get("candidates", []):
		if candidate.family != family:
			continue
		for factor: Dictionary in candidate.get("factors", []):
			if factor.get("source", "") == source:
				return float(factor.score)
	return NAN


static func _await_routine(sim) -> void:
	for index: int in range(800):
		var echo: Dictionary = sim.get_state().echoes[0]
		if int(echo.decisions) > 0 and not echo.moving and int(echo.remaining_ms) > 0:
			return
		_steps(sim, 1)


static func _behavior_signature(state: Dictionary) -> Array:
	var result: Array = []
	for echo: Dictionary in state.echoes:
		result.append([echo.position, echo.remaining_ms, echo.family, echo.destination])
	return result


static func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _on_segment(point: Vector2, start: Vector2, finish: Vector2) -> bool:
	return Geometry2D.get_closest_point_to_segment(point, start, finish).distance_to(point) < 0.0001


static func _route_distance(sim, from_node: String, to_node: String) -> float:
	var nodes: Dictionary = sim.get_definition().waypoints
	var previous := from_node
	var distance := 0.0
	for node: String in sim.route(from_node, to_node):
		distance += _vector(nodes[previous].pos).distance_to(_vector(nodes[node].pos))
		previous = node
	return distance


static func _has_occupant(occupants: Array, id: String) -> bool:
	for occupant: Variant in occupants:
		if (occupant is String and occupant == id) or (occupant is Dictionary and occupant.get("id", occupant.get("echo_id", "")) == id):
			return true
	return false


static func _check(results: Array[Dictionary], name: String, ok: bool) -> void:
	results.append({"name": name, "ok": ok})
