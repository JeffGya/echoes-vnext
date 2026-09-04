extends RefCounted
## Gate 3 summoning, newcomer, and incident-access contracts. All fixture changes stay in-memory.

const Simulation = preload("res://prototypes/sanctum_systems_exploration/simulation/PrototypeSimulation.gd")
const Gate2Suite = preload("res://prototypes/sanctum_systems_exploration/tests/PrototypeGate2Tests.gd")
const PLACEMENTS := {"hearth": "hearth_near", "training": "training_far"}


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_definition_and_reset(results)
	_payment_recovery_and_capacity(results)
	_arrival_lifecycle(results)
	_determinism_and_routes(results)
	_incident_access_contracts(results)
	_incident_autonomy_and_premise(results)
	return results


static func _definition_and_reset(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	var definition: Dictionary = sim.get_definition()
	var newcomers: Array = definition.summoning.newcomers
	var distinct := newcomers.size() == 3
	var ids: Dictionary = {}
	var marks: Dictionary = {}
	var portraits: Dictionary = {}
	for newcomer: Dictionary in newcomers:
		distinct = distinct and newcomer.has_all(["id", "name", "mark", "portrait", "traits", "preferences", "arrival_options"])
		ids[newcomer.id] = true
		marks[str(newcomer.mark)] = true
		portraits[str(newcomer.portrait.bust_id)] = true
	_check(results, "gate3/data_has_three_distinct_authored_newcomers", distinct and ids.size() == 3 and marks.size() == 3 and portraits.size() == 3)
	var state: Dictionary = sim.get_state()
	_check(results, "gate3/reset_starts_six_with_ase_and_seeded_unconsumed_order", state.echoes.size() == 6 and state.ase == 60 and state.newcomers_consumed.is_empty() and state.arrival.is_empty() and state.newcomer_order.size() == 3)
	var projection: Dictionary = sim.build_snapshot_data()
	var portrait_ids: Dictionary = {}
	for echo: Dictionary in projection.echoes:
		portrait_ids[str(echo.portrait.bust_id)] = true
	_check(results, "gate3/starting_six_project_distinct_mock_portraits", portrait_ids.size() == 6)


static func _payment_recovery_and_capacity(results: Array[Dictionary]) -> void:
	var sim = _started()
	_check(results, "gate3/confirmation_cancel_spends_nothing", _act(sim, "summon.confirm") and _act(sim, "summon.cancel") and sim.get_state().ase == 60 and sim.get_state().arrival.is_empty())
	_check(results, "gate3/atomic_commit_and_repeated_click_are_idempotent", _act(sim, "summon.confirm") and _act(sim, "summon.commit") and sim.get_state().ase == 0 and sim.get_state().newcomers_consumed.size() == 1 and not _act(sim, "summon.commit"))
	var recovery = _started({"day_minutes": 3, "social_frequency": 0})
	_act(recovery, "summon.confirm")
	_act(recovery, "summon.commit")
	_steps(recovery, 720)
	_check(results, "gate3/ase_recovers_sixty_once_per_completed_village_day_to_cap", recovery.get_state().ase == 60 and recovery.get_state().ase_recovery_days == [2])
	var full = _started({"social_frequency": 0})
	for index: int in range(3):
		var full_state: Dictionary = full.get_state()
		full_state.ase = 120
		full.set("_state", full_state)
		if not _act(full, "summon.confirm") or not _act(full, "summon.commit"):
			break
		_steps(full, 12)
		var welcome: Dictionary = full.get_state().arrival
		_act(full, "summon.welcome", {"welcome_id": welcome.welcome_choices[0].id})
		_steps(full, 160)
	_check(results, "gate3/capacity_blocks_a_tenth_echo", full.get_state().echoes.size() == 9 and not _act(full, "summon.confirm"))


static func _arrival_lifecycle(results: Array[Dictionary]) -> void:
	var sim = _started({"social_frequency": 0})
	var before: Dictionary = sim.get_state()
	_check(results, "gate3/stale_welcome_and_incident_join_are_rejected_outside_arrival", not _act(sim, "summon.welcome", {"welcome_id": "make_room"}) and not _act(sim, "incident.join", {"incident_id": "missing"}))
	_act(sim, "summon.confirm")
	_act(sim, "summon.commit")
	var committed: Dictionary = sim.get_state()
	var witnesses: Array = committed.arrival.witnesses
	var valid_witnesses: bool = not witnesses.is_empty() and witnesses.all(func(witness: Dictionary) -> bool:
		return witness.has_all(["echo_id", "response", "from_node", "route", "reason"]) and witness.response in ["approach", "watch", "avoid"])
	_check(results, "gate3/commit_uses_structured_identity_based_witness_reactions", valid_witnesses and committed.echoes.size() == before.echoes.size())
	_steps(sim, 12)
	var welcome_state: Dictionary = sim.get_state()
	var newcomer: Dictionary = _echo(welcome_state, str(welcome_state.arrival.newcomer_id))
	_check(results, "gate3/staged_manifest_requires_untimed_welcome_with_empty_social_state", welcome_state.arrival.stage == "welcome" and not newcomer.is_empty() and newcomer.reserved and welcome_state.bonds.is_empty() and welcome_state.encounters.is_empty() and welcome_state.impressions.is_empty())
	var choices: Array = sim.build_snapshot_data().summoning.arrival.welcome_choices
	_check(results, "gate3/welcome_choices_carry_authored_qualitative_cues", choices.size() == 2 and choices.all(func(choice: Dictionary) -> bool: return choice.has_all(["id", "label", "cue", "direction", "result"])))
	var background_before: Dictionary = _echo(welcome_state, "kojo").duplicate(true)
	_steps(sim, 4)
	var background_after: Dictionary = _echo(sim.get_state(), "kojo")
	_check(results, "gate3/background_life_continues_while_welcome_waits", welcome_state.arrival.stage == "welcome" and background_after.pressures != background_before.pressures)
	var welcome_id: String = str(choices[0].id)
	_check(results, "gate3/welcome_resolves_once_and_stale_repeat_does_nothing", _act(sim, "summon.welcome", {"welcome_id": welcome_id}) and not _act(sim, "summon.welcome", {"welcome_id": welcome_id}))
	_steps(sim, 160)
	var final_state: Dictionary = sim.get_state()
	var history: Array = final_state.events.filter(func(event: Dictionary) -> bool: return event.kind == "newcomer_arrival")
	var memory: Dictionary = history[0].arrival_memory if history.size() == 1 else {}
	_check(results, "gate3/first_destination_arrives_with_one_folded_structured_memory", final_state.arrival.stage == "complete" and history.size() == 1 and memory.has_all(["newcomer_id", "witnesses", "welcome", "first_intention", "arrival_node"]) and not str(memory.first_intention.place).is_empty())
	_check(results, "gate3/dismiss_and_reset_clear_pending_arrival_without_erasing_population", _act(sim, "summon.dismiss") and sim.get_state().arrival.is_empty())
	sim.reset(41, PLACEMENTS)
	_check(results, "gate3/reset_restores_initial_ase_order_and_population", sim.get_state().echoes.size() == 6 and sim.get_state().ase == 60 and sim.get_state().newcomers_consumed.is_empty() and sim.get_state().arrival.is_empty())


static func _determinism_and_routes(results: Array[Dictionary]) -> void:
	var first: Dictionary = _arrival_signature(77)
	var second: Dictionary = _arrival_signature(77)
	_check(results, "gate3/seed_replays_order_witnesses_welcome_and_first_route", first == second and first.order.size() == 3)
	var routes_valid := true
	for hearth: String in ["hearth_near", "hearth_far"]:
		for training: String in ["training_near", "training_far"]:
			var sim = Simulation.new()
			sim.reset(83, {"hearth": hearth, "training": training}, {"social_frequency": 0})
			_act(sim, "house.start")
			_act(sim, "summon.confirm")
			_act(sim, "summon.commit")
			_steps(sim, 12)
			_act(sim, "summon.welcome", {"welcome_id": sim.get_state().arrival.welcome_choices[0].id})
			var route_value: Array = sim.get_state().arrival.first_intention.route
			routes_valid = routes_valid and not route_value.is_empty()
	_check(results, "gate3/every_placement_combination_has_reachable_first_arrival_route", routes_valid)


static func _incident_access_contracts(results: Array[Dictionary]) -> void:
	var fixtures: Dictionary = {}
	var access_reachable := true
	var replay_stable := true
	for expected_access: String in ["private", "open", "appeal"]:
		var fixture: Dictionary = _incident_access_fixture(expected_access)
		var replay: Dictionary = _incident_access_fixture(expected_access)
		fixtures[expected_access] = fixture
		var incident: Dictionary = fixture.get("incident", {})
		var replay_incident: Dictionary = replay.get("incident", {})
		access_reachable = access_reachable and not incident.is_empty() \
			and str(incident.get("keeper_access", "")) == expected_access \
			and (expected_access == "appeal") == (not str(incident.get("appeal_echo_id", "")).is_empty()) \
			and not str(incident.get("access_reason", "")).is_empty()
		replay_stable = replay_stable and incident == replay_incident
	_check(results, "incident_access/controlled_fixtures_reach_private_open_and_appeal", access_reachable)
	_check(results, "incident_access/equal_seed_and_state_replay_access_appeal_speaker_and_exchange", replay_stable)
	var definition: Dictionary = Simulation.new().get_definition().social.get("incident_access", {})
	_check(results, "incident_access/local_thresholds_family_and_archetype_biases_remain_debug_visible",
		definition.has_all(["thresholds", "family_bias", "archetype_bias", "reasons"])
		and definition.thresholds.has_all(["private_max", "appeal_min", "fear_weight", "rest_weight", "courage_weight", "wisdom_weight", "bond_weight", "impression_weight"]))

	var private_fixture: Dictionary = fixtures.get("private", {})
	var private_sim = private_fixture.get("sim")
	var private_incident: Dictionary = private_fixture.get("incident", {})
	if private_sim == null or private_incident.is_empty():
		_check(results, "incident_access/private_open_projection_and_rejected_joins_are_byte_stable", false)
		return
	Gate2Suite._act(private_sim, "tuning.set", {"key": "social_frequency", "value": 0})
	Gate2Suite._advance_to(private_sim, int(private_incident.stage_deadline_ms))
	var private_open: Dictionary = Gate2Suite._incident(private_sim.build_snapshot_data(), str(private_incident.id))
	var before_rejections: Dictionary = private_sim.get_state()
	var direct_rejected: bool = not _act(private_sim, "incident.join", {"incident_id": private_incident.id})
	var after_direct: Dictionary = private_sim.get_state()
	var stale_action := {"type": "prototype.incident.join", "payload": {"incident_id": private_incident.id}}
	var stale_rejected: bool = not private_sim.apply_action(stale_action, private_sim.get_step() - 1)
	var after_stale: Dictionary = private_sim.get_state()
	var fabricated_rejected: bool = not _act(private_sim, "incident.join", {"incident_id": "incident.fabricated"})
	var after_fabricated: Dictionary = private_sim.get_state()
	_check(results, "incident_access/private_open_projection_and_rejected_joins_are_byte_stable",
		private_open.get("status", "") == "open" and not bool(private_open.get("can_join", true))
		and direct_rejected and stale_rejected and fabricated_rejected
		and before_rejections == after_direct and after_direct == after_stale and after_stale == after_fabricated)


static func _incident_autonomy_and_premise(results: Array[Dictionary]) -> void:
	var autonomous_optional := true
	var worsening_changes_behavior := false
	for access: String in ["open", "appeal"]:
		var fixture: Dictionary = _incident_access_fixture(access)
		var sim = fixture.get("sim")
		var warning: Dictionary = fixture.get("incident", {})
		if sim == null or warning.is_empty():
			autonomous_optional = false
			continue
		Gate2Suite._act(sim, "tuning.set", {"key": "social_frequency", "value": 0})
		Gate2Suite._advance_to(sim, int(warning.stage_deadline_ms))
		var open_projection: Dictionary = Gate2Suite._incident(sim.build_snapshot_data(), str(warning.id))
		var bond_before: int = _pair_bond(sim.get_state(), warning.participants)
		Gate2Suite._advance_to(sim, int(warning.incident_deadline_ms))
		var resolved: Dictionary = Gate2Suite._incident(sim.get_state(), str(warning.id))
		var result: Dictionary = resolved.get("result", {})
		var resolved_events: Array = sim.get_state().events.filter(func(event: Dictionary) -> bool:
			return event.kind == "incident_resolved" and event.get("incident_id", "") == warning.id)
		autonomous_optional = autonomous_optional and bool(open_projection.get("can_join", false)) \
			and resolved.get("status", "") == "resolved" and result.get("response", "") in ["settled", "frustrated"] \
			and result.get("keeper_reactions", []).is_empty() and str(sim.get_state().joined_incident_id).is_empty() \
			and resolved_events.size() == 1 and resolved_events[0].get("keeper_reactions", []).is_empty()
		if result.get("response", "") == "frustrated":
			var aftermaths: Array = result.get("aftermath_behaviors", [])
			var bond_after: int = _pair_bond(sim.get_state(), warning.participants)
			var authored_distance: bool = aftermaths.size() == 2 and aftermaths.all(func(behavior: Dictionary) -> bool:
				return behavior.get("activity", "") == "keeping their distance" and behavior.get("next_intention", {}) == {"family": "rest"})
			Gate2Suite._steps(sim, 24)
			var later_rest: bool = warning.participants.all(func(echo_id: String) -> bool:
				return Gate2Suite._echo(sim.get_state(), echo_id).get("family", "") == "rest")
			worsening_changes_behavior = bond_after < bond_before and authored_distance and later_rest
	_check(results, "incident_access/ignored_open_and_appeal_remain_optional_and_resolve_without_keeper_reaction", autonomous_optional)
	_check(results, "incident_access/ignored_worsening_outcome_changes_bond_and_subsequent_behavior", worsening_changes_behavior)

	var appeal_fixture: Dictionary = _incident_access_fixture("appeal")
	var appeal_sim = appeal_fixture.get("sim")
	var appeal_warning: Dictionary = appeal_fixture.get("incident", {})
	if appeal_sim == null or appeal_warning.is_empty():
		_check(results, "incident_access/premise_and_appeal_identity_persist_warning_join_result_and_history", false)
		return
	Gate2Suite._act(appeal_sim, "tuning.set", {"key": "social_frequency", "value": 0})
	var premise: Array = appeal_warning.get("exchange_lines", []).duplicate(true)
	var premise_readable: bool = premise.size() == 2 and premise.all(func(line: Dictionary) -> bool:
		return line.has_all(["speaker_id", "text"]) and appeal_warning.participants.has(line.speaker_id) \
			and str(line.text).begins_with("I ") and not str(line.text).contains("keeper_access"))
	var access_signature := {"keeper_access": appeal_warning.get("keeper_access", ""),
		"appeal_echo_id": appeal_warning.get("appeal_echo_id", ""), "access_reason": appeal_warning.get("access_reason", "")}
	var warning_events: Array = appeal_sim.get_state().events.filter(func(event: Dictionary) -> bool:
		return event.kind == "incident_warning" and event.get("incident_id", "") == appeal_warning.id)
	Gate2Suite._advance_to(appeal_sim, int(appeal_warning.stage_deadline_ms))
	var appeal_open: Dictionary = Gate2Suite._incident(appeal_sim.get_state(), str(appeal_warning.id))
	var joined_ok: bool = _act(appeal_sim, "incident.join", {"incident_id": appeal_warning.id})
	var joined: Dictionary = Gate2Suite._incident(appeal_sim.get_state(), str(appeal_warning.id))
	var replied_ok: bool = _act(appeal_sim, "incident.reply", {"incident_id": appeal_warning.id, "reply_id": "give_space"})
	var resolved: Dictionary = Gate2Suite._incident(appeal_sim.get_state(), str(appeal_warning.id))
	var resolved_events: Array = appeal_sim.get_state().events.filter(func(event: Dictionary) -> bool:
		return event.kind == "incident_resolved" and event.get("incident_id", "") == appeal_warning.id)
	var history: Array = appeal_sim.build_snapshot_data().village_history.filter(func(event: Dictionary) -> bool:
		return event.get("kind", "") == "incident_resolved" and event.get("incident_id", "") == appeal_warning.id)
	var stable_access: bool = [appeal_open, joined, resolved].all(func(incident: Dictionary) -> bool:
		return incident.get("keeper_access", "") == access_signature.keeper_access \
			and incident.get("appeal_echo_id", "") == access_signature.appeal_echo_id \
			and incident.get("access_reason", "") == access_signature.access_reason)
	var persistent_premise: bool = warning_events.size() == 1 and warning_events[0].get("exchange_lines", []) == premise \
		and appeal_open.get("exchange_lines", []) == premise and joined.get("exchange_lines", []) == premise \
		and resolved.get("exchange_lines", []) == premise and resolved.get("result", {}).get("exchange_lines", []) == premise \
		and resolved_events.size() == 1 and resolved_events[0].get("exchange_lines", []) == premise \
		and history.size() == 1 and history[0].get("exchange_lines", []) == premise
	_check(results, "incident_access/premise_and_appeal_identity_persist_warning_join_result_and_history",
		premise_readable and joined_ok and replied_ok and stable_access and persistent_premise)


static func _incident_access_fixture(access: String) -> Dictionary:
	var access_values := {
		"private": {"fear": 0, "rest": 0.0},
		"open": {"fear": -1, "rest": -1.0},
		"appeal": {"fear": 100, "rest": 30.0},
	}
	var values: Dictionary = access_values.get(access, access_values.open)
	if access == "open":
		return Gate2Suite._warning_fixture(15.0, 45.0)
	var sim = Gate2Suite._social_pair(["kweku", "yaw"], "flame", {
		"kweku": {"family": "company", "fear": values.fear,
			"pressures": {"rest": values.rest, "company": 18.0, "purpose": 4.0}},
		"yaw": {"family": "rest", "fear": values.fear,
			"pressures": {"rest": values.rest, "company": 10.0, "purpose": 4.0}}},
		3.0, {"warning_seconds": 15.0, "intervention_seconds": 45.0})
	var social: Dictionary = Gate2Suite._await_social(sim, "unwanted_attention")
	var incidents: Array = social.get("after", {}).get("incidents", [])
	return {"sim": sim, "incident": incidents[0] if not incidents.is_empty() else {}}


static func _pair_bond(state: Dictionary, participants: Array) -> int:
	if participants.size() != 2:
		return 0
	for bond: Dictionary in state.get("bonds", []):
		if [str(bond.get("actor_a", "")), str(bond.get("actor_b", ""))].all(func(id: String) -> bool: return participants.has(id)):
			return int(bond.get("strength", 0))
	return 0


static func _arrival_signature(seed_value: int) -> Dictionary:
	var sim = Simulation.new()
	sim.reset(seed_value, PLACEMENTS, {"social_frequency": 0})
	_act(sim, "house.start")
	_act(sim, "summon.confirm")
	_act(sim, "summon.commit")
	_steps(sim, 12)
	var arrival: Dictionary = sim.get_state().arrival
	_act(sim, "summon.welcome", {"welcome_id": arrival.welcome_choices[0].id})
	return {"order": sim.get_state().newcomer_order, "newcomer_id": arrival.newcomer_id,
		"witnesses": arrival.witnesses, "welcome": sim.get_state().arrival.welcome,
		"route": sim.get_state().arrival.first_intention.route}


static func _started(tuning: Dictionary = {}):
	var sim = Simulation.new()
	sim.reset(41, PLACEMENTS, tuning)
	_act(sim, "house.start")
	return sim


static func _act(sim, suffix: String, payload: Dictionary = {}) -> bool:
	return sim.apply_action({"type": "prototype." + suffix, "payload": payload}, sim.get_step())


static func _steps(sim, count: int) -> void:
	for index: int in range(count):
		sim.advance_step(sim.get_step() + 1)


static func _echo(state: Dictionary, id: String) -> Dictionary:
	for echo: Dictionary in state.echoes:
		if echo.id == id:
			return echo
	return {}


static func _check(results: Array[Dictionary], name: String, ok: bool) -> void:
	results.append({"name": name, "ok": ok})
