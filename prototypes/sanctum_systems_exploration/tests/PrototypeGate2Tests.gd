extends RefCounted
## Gate 2 relationship, social exchange, impression and incident contracts.
## All controlled fixtures mutate only one prototype Simulation instance.

const Simulation = preload("res://prototypes/sanctum_systems_exploration/simulation/PrototypeSimulation.gd")
const SocialGraph = preload("res://core/sanctum/SocialGraphService.gd")
const Emotion = preload("res://core/emotion/EmotionService.gd")
const PLACEMENTS := {"hearth": "hearth_near", "training": "training_far"}
const SIGNIFICANT_KINDS := ["social_exchange", "impression", "emotion_change", "bond_change",
	"incident_warning", "incident_open", "incident_mutation", "incident_intervention", "incident_resolved"]


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var sim = Simulation.new()
	var state: Dictionary = sim.get_state()
	var required := ["bonds", "encounters", "impressions", "cooldowns", "social_engagements",
		"incidents", "joined_incident_id", "social_serial", "incident_serial"]
	var ready := state.has_all(required)
	_check(results, "gate2/authoritative_state_contract_available", ready)
	if not ready:
		return results
	_definition_contract(results)
	_empty_and_canonical_projection(results)
	_social_exchange_contracts(results)
	_reaction_voice_contracts(results)
	_default_pacing_contracts(results)
	_impression_contracts(results)
	_incident_contracts(results)
	_focused_revision_contracts(results)
	_structured_history_projection(results)
	_projection_independence_and_reset(results)
	return results


static func _reaction_voice_contracts(results: Array[Dictionary]) -> void:
	var practice = _social_pair(["kojo", "esi"], "training", {
		"kojo": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
		"esi": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}})
	var enacted: Dictionary = _await_social(practice, "shared_practice")
	var event: Dictionary = enacted.get("event", {})
	var cues: Array = event.get("reaction_cues", [])
	var valid_cues: bool = cues.size() == 2
	for cue: Dictionary in cues:
		valid_cues = valid_cues and cue.has_all(["echo_id", "kind", "target_id", "motion", "started_ms", "duration_ms"])
		valid_cues = valid_cues and cue.keys().size() == 6
		valid_cues = valid_cues and cue.kind in ["welcomed", "appreciative", "uncomfortable", "crowded", "challenged", "hurt"]
		valid_cues = valid_cues and cue.motion in ["closer", "acknowledge", "angle_away", "step_back", "square_up", "withdraw"]
		valid_cues = valid_cues and cue.echo_id in event.get("participants", []) and cue.target_id in event.get("participants", []) and cue.echo_id != cue.target_id
		valid_cues = valid_cues and int(cue.duration_ms) > 0 and int(cue.started_ms) == int(event.elapsed_ms)
	_check(results, "reaction_voice/social_exchange_authors_two_exact_timed_reaction_cues", valid_cues)

	var definition: Dictionary = practice.get_definition()
	var voice: Dictionary = definition.reaction_voice.social.shared_practice
	var authored_reactions: Array[Dictionary] = []
	_collect_reaction_specs(definition.reaction_voice, authored_reactions)
	var authored_kind_set: Dictionary = {}
	for reaction: Dictionary in authored_reactions:
		authored_kind_set[str(reaction.kind)] = true
	var authored_kinds: Array = authored_kind_set.keys()
	authored_kinds.sort()
	_check(results, "reaction_voice/authored_surface_uses_all_and_only_six_reaction_kinds",
		authored_kinds == ["appreciative", "challenged", "crowded", "hurt", "uncomfortable", "welcomed"]
		and authored_reactions.all(func(reaction: Dictionary) -> bool: return reaction.motion in ["closer", "acknowledge", "angle_away", "step_back", "square_up", "withdraw"]))
	var snapshot: Dictionary = practice.build_snapshot_data()
	var engagement: Dictionary = snapshot.social_engagements[0] if snapshot.social_engagements.size() == 1 else {}
	var views: Array = event.get("participant_views", [])
	var memories: Dictionary = event.get("personal_memories", {})
	var kojo: Dictionary = _echo(snapshot, "kojo")
	var esi: Dictionary = _echo(snapshot, "esi")
	var participants: Array = event.get("participants", [])
	var initiator: Dictionary = _echo(snapshot, str(participants[0])) if participants.size() == 2 else {}
	var receiver: Dictionary = _echo(snapshot, str(participants[1])) if participants.size() == 2 else {}
	var place_name: String = str(snapshot.places.get(event.get("place", ""), {}).get("name", ""))
	var expected_history: String = str(voice.history_text).replace("{initiator}", str(initiator.get("name", ""))) \
		.replace("{receiver}", str(receiver.get("name", ""))).replace("{place}", place_name)
	var expected_live: String = str(voice.live_text).replace("{initiator}", str(initiator.get("name", ""))) \
		.replace("{receiver}", str(receiver.get("name", ""))).replace("{place}", place_name)
	var voice_ok: bool = not initiator.is_empty() and not receiver.is_empty() and not place_name.is_empty()
	voice_ok = voice_ok and event.get("text", "") == expected_history and engagement.get("cue", "") == expected_live
	voice_ok = voice_ok and snapshot.reaction_cues == cues
	voice_ok = voice_ok and kojo.reaction_cues.size() == 1 and esi.reaction_cues.size() == 1
	voice_ok = voice_ok and views.size() == 2 and views.all(func(view: Dictionary) -> bool: return str(view.get("view_of_other", "")).begins_with("I "))
	voice_ok = voice_ok and str(views[0].view_of_other) != str(views[1].view_of_other)
	voice_ok = voice_ok and memories.size() == 2 and memories.values().all(func(memory: String) -> bool: return memory.begins_with("I "))
	voice_ok = voice_ok and memories.kojo != memories.esi
	voice_ok = voice_ok and str(kojo.get("current", "")).begins_with("I ") and str(esi.get("current", "")).begins_with("I ")
	voice_ok = voice_ok and str(kojo.get("recent", "")) == memories.kojo and str(esi.get("recent", "")) == memories.esi
	_check(results, "reaction_voice/live_history_current_recent_keep_authored_tense_and_distinct_first_person_views", voice_ok)

	_act(practice, "tuning.set", {"key": "social_frequency", "value": 0})
	var end_ms: int = int(cues[0].started_ms) + int(cues[0].duration_ms) if not cues.is_empty() else int(practice.get_state().elapsed_ms)
	_advance_to(practice, maxi(int(practice.get_state().elapsed_ms), end_ms - 250))
	var present_before_expiry: bool = practice.get_state().reaction_cues.size() == 2
	practice.advance_step(practice.get_step() + 1)
	_check(results, "reaction_voice/cues_expire_only_at_authored_simulation_deadline", present_before_expiry and practice.get_state().reaction_cues.is_empty())
	practice.reset(41, PLACEMENTS)
	_check(results, "reaction_voice/reset_clears_transient_reactions", practice.get_state().reaction_cues.is_empty() and practice.build_snapshot_data().reaction_cues.is_empty())

	var cue_only = Simulation.new()
	_start(cue_only)
	var cue_before: Dictionary = cue_only.get_state()
	var injected: Dictionary = cue_only._add_reaction_cue("kojo", "esi", {"kind": "appreciative", "motion": "acknowledge"})
	var cue_after: Dictionary = cue_only.get_state()
	var cue_values: Array = cue_after.reaction_cues.duplicate(true)
	cue_before.reaction_cues = []
	cue_after.reaction_cues = []
	_check(results, "reaction_voice/cue_alone_changes_no_bond_need_or_simulation_state", not injected.is_empty() and cue_values.size() == 1 and cue_after == cue_before)

	var replay = _social_pair(["kojo", "esi"], "training", {
		"kojo": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
		"esi": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}})
	var replay_event: Dictionary = _await_social(replay, "shared_practice").get("event", {})
	_check(results, "reaction_voice/reaction_and_voice_projection_replays_deterministically",
		event.get("reaction_cues", []) == replay_event.get("reaction_cues", [])
		and event.get("participant_views", []) == replay_event.get("participant_views", [])
		and event.get("personal_memories", {}) == replay_event.get("personal_memories", {}))

	var witness_sim = _practice_warning_witness_fixture()
	var witness_result: Dictionary = _await_social(witness_sim, "competitive_practice")
	var witness_event: Dictionary = witness_result.get("event", {})
	var witness_state: Dictionary = witness_result.get("after", {})
	var witnesses: Array = witness_event.get("witnesses", [])
	var incident: Dictionary = witness_state.incidents[0] if witness_state.get("incidents", []).size() == 1 else {}
	var witness_ids: Array = witnesses.map(func(witness: Dictionary) -> String: return str(witness.get("echo_id", "")))
	var witness_shape_ok: bool = witnesses.size() > 0 and witnesses.size() <= 3
	for witness: Dictionary in witnesses:
		var reaction: Dictionary = witness.get("reaction", {})
		witness_shape_ok = witness_shape_ok and witness.has_all(["echo_id", "role", "target_id", "reaction", "perspective"])
		witness_shape_ok = witness_shape_ok and witness.role in ["support", "side", "watch", "leave"]
		witness_shape_ok = witness_shape_ok and witness.target_id in witness_event.participants
		witness_shape_ok = witness_shape_ok and reaction.has_all(["kind", "target_id", "motion", "started_ms", "duration_ms"])
		witness_shape_ok = witness_shape_ok and str(witness.perspective).begins_with("I ")
	var witness_causality_ok: bool = not incident.is_empty() and incident.family == "practice" and incident.witnesses == witnesses
	witness_causality_ok = witness_causality_ok and witness_event.participants.size() == 2 and witness_ids.all(func(id: String) -> bool: return not witness_event.participants.has(id))
	witness_causality_ok = witness_causality_ok and witness_state.bonds.size() == 1 and int(witness_event.shared_bond.delta) == 1
	witness_causality_ok = witness_causality_ok and witness_state.impressions.all(func(impression: Dictionary) -> bool: return witness_event.participants.has(impression.owner_id) and witness_event.participants.has(impression.other_id))
	for witness_id: String in witness_ids:
		var witness_echo: Dictionary = _echo(witness_state, witness_id)
		witness_causality_ok = witness_causality_ok and not witness_echo.reserved and str(witness_echo.incident_id).is_empty() and str(witness_echo.engagement_id).is_empty()
		var witness_projection: Dictionary = _echo(witness_sim.build_snapshot_data(), witness_id)
		witness_causality_ok = witness_causality_ok and witness_projection.witness_memories.size() == 1
		witness_causality_ok = witness_causality_ok and witness_projection.witness_memories[0].has_all(["source_event_id", "elapsed_ms", "role", "target_id", "perspective"])
		witness_causality_ok = witness_causality_ok and str(witness_projection.witness_memories[0].perspective).begins_with("I ")
	_check(results, "reaction_voice/practice_warning_has_bounded_structured_nonparticipant_witnesses", witness_shape_ok)
	_check(results, "reaction_voice/witnesses_stay_unreserved_and_create_memory_without_proximity_rewards_or_extra_bonds", witness_causality_ok)

	var companionship: Dictionary = _warning_fixture(15.0, 45.0)
	_check(results, "reaction_voice/non_practice_warning_never_recruits_witnesses", companionship.incident.get("witnesses", []).is_empty())


static func _collect_reaction_specs(value: Variant, output: Array[Dictionary]) -> void:
	if value is Dictionary:
		if value.has("kind") and value.has("motion"):
			output.append(value)
		for child: Variant in value.values():
			_collect_reaction_specs(child, output)
	elif value is Array:
		for child: Variant in value:
			_collect_reaction_specs(child, output)


static func _definition_contract(results: Array[Dictionary]) -> void:
	var definition: Dictionary = Simulation.new().get_definition()
	var expected_templates := ["welcome_company", "quiet_company", "unwanted_attention",
		"accepted_support", "declined_help", "protective_response", "caregiver_strain",
		"shared_practice", "competitive_practice", "encouragement", "recognition", "impatience", "rivalry"]
	var template_ids: Array = definition.social.templates.map(func(template: Dictionary) -> String: return str(template.id))
	var templates_structured: bool = definition.social.templates.all(func(template: Dictionary) -> bool:
		return (template.has_all(["id", "family", "label", "cue_text", "bond_delta", "duration_ms", "cooldown_ms", "warning", "participant_effects", "impressions"])
			and template.family in ["companionship", "care", "practice"]
			and template.participant_effects.has_all(["initiator", "receiver"])
			and template.impressions.has_all(["initiator", "receiver"]))
	)
	_check(results, "gate2/data_owns_all_social_templates_effects_durations_and_cooldowns", template_ids == expected_templates and templates_structured)
	var competitive_matches: Array = definition.social.templates.filter(func(template: Dictionary) -> bool: return template.id == "competitive_practice")
	var competitive: Dictionary = competitive_matches[0] if competitive_matches.size() == 1 else {}
	var competitive_impressions: bool = not competitive.is_empty() and competitive.impressions.initiator.tag == "challenged" and competitive.impressions.receiver.tag == "challenged" and competitive.impressions.initiator.influence.keys() == ["purpose"] and competitive.impressions.receiver.influence.keys() == ["purpose"] and is_equal_approx(float(competitive.impressions.initiator.influence.purpose), 2.0) and is_equal_approx(float(competitive.impressions.receiver.influence.purpose), 2.0)
	_check(results, "gate2/data_owns_productive_competitive_practice_outcome", not competitive.is_empty() and competitive.label == "Friendly competition" and competitive.family == "practice" and competitive.bond_delta == 1 and competitive.warning and competitive.duration_ms == 2500 and competitive.cooldown_ms == 60000 and competitive.participant_effects.initiator.purpose_delta == -3 and competitive.participant_effects.receiver.purpose_delta == -3 and competitive_impressions)
	var exact_tuning: bool = definition.tuning.keys().size() == 8 and definition.tuning_ranges.keys().size() == 8
	for key: String in ["social_frequency", "warning_seconds", "intervention_seconds"]:
		exact_tuning = exact_tuning and definition.tuning.has(key) and definition.tuning_ranges.has(key)
	_check(results, "gate2/three_social_tuning_controls_have_data_ranges", exact_tuning and definition.tuning.social_frequency == 1 and definition.tuning.warning_seconds == 60 and definition.tuning.intervention_seconds == 45)
	var reply_ids: Array = []
	var authored_behavior_data := true
	for family: String in ["companionship", "care", "practice"]:
		authored_behavior_data = authored_behavior_data and not str(definition.social.incidents[family].get("issue_activity", "")).is_empty()
		for reply: Dictionary in definition.social.incidents[family].replies:
			reply_ids.append(reply.id)
			authored_behavior_data = authored_behavior_data and _authored_aftermath_shape(reply.get("aftermath_behavior", {}))
	_check(results, "gate2/data_owns_exact_incident_reply_set", reply_ids == ["give_space", "name_harm", "respect_boundary", "share_care", "set_terms", "cool_down"])
	for autonomous: Dictionary in definition.social.autonomous_results.values():
		authored_behavior_data = authored_behavior_data and _authored_aftermath_shape(autonomous.get("aftermath_behavior", {}))
	_check(results, "gate2_revision/data_authors_issue_activity_and_every_reply_or_autonomous_aftermath", authored_behavior_data)


static func _empty_and_canonical_projection(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	var setup_state: Dictionary = sim.get_state()
	var setup_data: Dictionary = sim.build_snapshot_data()
	var empty_state: bool = setup_state.bonds.is_empty() and setup_state.encounters.is_empty() and setup_state.impressions.is_empty() and setup_state.cooldowns.is_empty() and setup_state.social_engagements.is_empty() and setup_state.incidents.is_empty() and str(setup_state.joined_incident_id).is_empty()
	var empty_projection: bool = setup_data.bonds.is_empty() and setup_data.social_engagements.is_empty() and setup_data.incidents.is_empty() and str(setup_data.joined_incident_id).is_empty() and setup_data.village_history.is_empty()
	empty_projection = empty_projection and setup_data.echoes.all(func(echo: Dictionary) -> bool: return echo.bonds.is_empty() and echo.impressions.is_empty() and str(echo.engagement_id).is_empty())
	_check(results, "gate2/fixtures_start_without_relationship_or_incident_state", empty_state and empty_projection)
	_start(sim)
	var state: Dictionary = sim.get_state()
	state.bonds = [{"actor_a": "abena", "actor_b": "kojo", "strength": 30}]
	state.encounters = [["abena", "kojo"]]
	state.encounter_counts = {"abena|kojo": 2}
	state.bond_last_events = {"abena|kojo": 77}
	sim.set("_state", state)
	var data: Dictionary = sim.build_snapshot_data()
	var shared: Dictionary = data.bonds[0] if data.bonds.size() == 1 else {}
	var abena: Dictionary = _echo(data, "abena")
	var kojo: Dictionary = _echo(data, "kojo")
	var from_abena: Dictionary = _bond_to(abena, "kojo")
	var from_kojo: Dictionary = _bond_to(kojo, "abena")
	var shared_keys := ["actor_a", "actor_b", "strength", "tier", "tier_name", "bond_type", "encounter_count", "last_event_id"]
	var exact_shared: bool = not shared.is_empty() and shared.has_all(shared_keys) and shared.size() == shared_keys.size()
	var expected_tier := SocialGraph.get_tier(30)
	_check(results, "gate2/bond_projection_is_one_canonical_shared_edge", exact_shared and shared.actor_a == "abena" and shared.actor_b == "kojo" and shared.strength == 30 and shared.tier == expected_tier and shared.tier_name == SocialGraph.get_tier_name(expected_tier) and shared.bond_type == "friend" and shared.encounter_count == 2 and shared.last_event_id == 77)
	_check(results, "gate2/bond_lookup_from_both_echoes_shares_strength_and_tier", from_abena.other_id == "kojo" and from_kojo.other_id == "abena" and from_abena.strength == from_kojo.strength and from_abena.tier == from_kojo.tier and from_abena.tier_name == from_kojo.tier_name and from_abena.bond_type == from_kojo.bond_type and from_abena.encounter_count == 2 and from_kojo.last_event_id == 77)


static func _social_exchange_contracts(results: Array[Dictionary]) -> void:
	var practice = _social_pair(["kojo", "esi"], "training", {
		"kojo": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
		"esi": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}})
	var practice_result: Dictionary = _await_social(practice, "shared_practice")
	var event: Dictionary = practice_result.get("event", {})
	var after: Dictionary = practice_result.get("after", {})
	var effects: Array = event.get("participant_effects", [])
	var shared: Dictionary = event.get("shared_bond", {})
	var edge: Dictionary = SocialGraph.get_edge(after.get("bonds", []), "kojo", "esi")
	var engagement_projection: Dictionary = practice.build_snapshot_data().social_engagements[0] if practice.build_snapshot_data().social_engagements.size() == 1 else {}
	var engagement_keys := ["id", "family", "template_id", "participants", "place", "cue", "started_ms", "duration_ms", "remaining_ms"]
	_check(results, "gate2/productive_practice_has_two_explicit_participant_reactions", not event.is_empty() and event.family == "practice" and effects.size() == 2 and effects.all(func(effect: Dictionary) -> bool: return effect.has_all(["echo_id", "reaction", "rest_delta", "company_delta", "purpose_delta", "fear_delta", "morale_delta"])) and effects.all(func(effect: Dictionary) -> bool: return float(effect.purpose_delta) < 0.0))
	_check(results, "gate2/social_exchange_applies_one_shared_bond_delta", shared == {"delta": 2, "before": 0, "after": 2, "bond_type_before": "neutral", "bond_type_after": "neutral"} and edge.get("strength", 999) == 2)
	_check(results, "gate2/productive_practice_satisfies_purpose_and_creates_challenge", after.impressions.size() == 2 and after.impressions.all(func(impression: Dictionary) -> bool: return impression.family == "practice" and impression.tag == "challenged"))
	_check(results, "gate2/social_engagement_is_authoritative_bounded_world_cue", engagement_projection.has_all(engagement_keys) and engagement_projection.size() == engagement_keys.size() and engagement_projection.template_id == "shared_practice" and engagement_projection.remaining_ms > 0 and after.echoes.all(func(echo: Dictionary) -> bool: return echo.reserved and echo.engagement_id == engagement_projection.id) and not _act(practice, "conversation.begin", {"echo_id": "kojo"}))
	var grouped_raw: Array = after.events.filter(func(raw: Dictionary) -> bool: return raw.id == event.id or raw.get("source_event_id", 0) == event.id)
	var grouped_ids: Array = grouped_raw.map(func(raw: Dictionary) -> int: return int(raw.id))
	var folded_data: Dictionary = practice.build_snapshot_data()
	var folded_flame: Array = folded_data.village_history.filter(func(summary: Dictionary) -> bool: return summary.source_ids.has(event.id))
	var folded_place: Array = folded_data.place_history.training.filter(func(summary: Dictionary) -> bool: return summary.source_ids.has(event.id))
	var folded_people: bool = true
	for participant_id: String in event.participants:
		var visible: Array = _echo(folded_data, participant_id).history.filter(func(summary: Dictionary) -> bool: return summary.source_ids.has(event.id))
		folded_people = folded_people and visible.size() == 1 and visible[0].kind == "social_exchange" and visible[0].source_ids == grouped_ids
	var auxiliaries_valid: bool = grouped_raw.size() > 1 and grouped_raw.slice(1).all(func(raw: Dictionary) -> bool: return raw.kind in ["impression", "emotion_change", "bond_change"] and raw.source_event_id == event.id)
	var folded_summary: Dictionary = folded_flame[0] if folded_flame.size() == 1 else {}
	_check(results, "gate2/actual_social_history_keeps_structured_effects_and_shared_bond", event.significant and not str(event.title).is_empty() and not folded_summary.is_empty() and folded_summary.participant_effects == effects and folded_summary.shared_bond == shared and folded_summary.source_ids.has(event.id))
	_check(results, "gate2/social_auxiliary_records_reference_retained_parent", auxiliaries_valid)
	_check(results, "gate2/one_social_exchange_is_one_folded_visible_row_everywhere", folded_people and folded_flame.size() == 1 and folded_place.size() == 1 and folded_summary.kind == "social_exchange" and folded_summary.source_ids == grouped_ids and folded_summary.source_count == grouped_ids.size() and folded_summary.has_all(["participant_effects", "impression_changes", "shared_bond"]))
	var reversed = _social_pair(["esi", "kojo"], "training", {
		"kojo": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
		"esi": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}})
	var reversed_event: Dictionary = _await_social(reversed, "shared_practice").get("event", {})
	_check(results, "gate2/reactions_use_stable_prestate_not_fixture_order", not event.is_empty() and event == reversed_event)
	var competitive = _social_pair(["abena", "kweku"], "training", {
		"abena": {"family": "purpose", "fear": 50, "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
		"kweku": {"family": "purpose", "fear": 50, "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}},
		3.0, {"warning_seconds": 15})
	var competitive_result: Dictionary = _await_social(competitive, "competitive_practice")
	var competitive_event: Dictionary = competitive_result.get("event", {})
	var competitive_after: Dictionary = competitive_result.get("after", {})
	var competitive_warning: Dictionary = competitive_after.incidents[0] if competitive_after.get("incidents", []).size() == 1 else {}
	var productive_effects: bool = competitive_event.get("participant_effects", []).size() == 2 and competitive_event.participant_effects.all(func(effect: Dictionary) -> bool: return is_equal_approx(float(effect.purpose_delta), -3.0))
	var productive_impressions: bool = competitive_after.get("impressions", []).size() == 2 and competitive_after.impressions.all(func(impression: Dictionary) -> bool: return impression.family == "practice" and impression.tag == "challenged" and impression.influence == {"purpose": 2.0})
	_check(results, "gate2/neutral_proud_practice_creates_productive_tension", competitive_event.get("template_id", "") == "competitive_practice" and competitive_event.shared_bond == {"delta": 1, "before": 0, "after": 1, "bond_type_before": "neutral", "bond_type_after": "neutral"} and productive_effects and productive_impressions and not competitive_warning.is_empty() and competitive_warning.status == "warning")
	var first_warning_id: String = competitive_warning.get("id", "")
	_act(competitive, "tuning.set", {"key": "social_frequency", "value": 0})
	_advance_to(competitive, int(competitive_warning.stage_deadline_ms))
	var opened_competitive: Dictionary = _incident(competitive.get_state(), first_warning_id)
	_check(results, "gate2/competitive_practice_warning_reaches_keeper_open_stage", opened_competitive.get("status", "") == "open" and competitive.get_state().events.filter(func(raw: Dictionary) -> bool: return raw.kind == "incident_open" and raw.incident_id == first_warning_id).size() == 1)
	_act(competitive, "incident.join", {"incident_id": first_warning_id})
	_act(competitive, "incident.reply", {"incident_id": first_warning_id, "reply_id": "set_terms"})
	_steps(competitive, 24)
	_act(competitive, "tuning.set", {"key": "social_frequency", "value": 3})
	var followup_result: Dictionary = _await_social(competitive, "shared_practice")
	var followup_event: Dictionary = followup_result.get("event", {})
	var followup_state: Dictionary = followup_result.get("after", {})
	_check(results, "gate2/positive_bond_practice_falls_back_without_warning_farming", followup_event.get("template_id", "") == "shared_practice" and int(followup_event.get("shared_bond", {}).get("before", 0)) > 0 and int(followup_event.get("shared_bond", {}).get("after", 0)) > int(followup_event.get("shared_bond", {}).get("before", 0)) and _social_events(followup_state, "competitive_practice").size() == 1 and followup_state.events.filter(func(raw: Dictionary) -> bool: return raw.kind == "incident_warning" and raw.incident_id == first_warning_id).size() == 1 and followup_state.incidents.is_empty())
	var rival = _social_pair(["kojo", "esi"], "training", {
		"kojo": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}},
		"esi": {"family": "purpose", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 16.0}}})
	var rival_state: Dictionary = rival.get_state()
	rival_state.bonds = [{"actor_a": "esi", "actor_b": "kojo", "strength": -10}]
	rival.set("_state", rival_state)
	_check(results, "gate2/shared_bond_changes_actual_later_reaction", _await_social(rival, "rivalry").get("event", {}).get("template_id", "") == "rivalry")
	var baseline_emotion: Dictionary = _emotion_choice(false)
	var severe_emotion: Dictionary = _emotion_choice(true)
	_check(results, "gate2/canonical_emotional_status_changes_actual_social_participation", baseline_emotion.get("family", "") == "companionship" and severe_emotion.get("family", "") == "care")

	var declined = _social_pair(["ama", "abena"], "flame", {
		"ama": {"family": "rest", "pressures": {"rest": 5.0, "company": 4.0, "purpose": 4.0}},
		"abena": {"family": "rest", "pressures": {"rest": 12.0, "company": 4.0, "purpose": 4.0}}})
	var declined_result: Dictionary = _await_social(declined, "declined_help")
	var declined_event: Dictionary = declined_result.get("event", {})
	var declined_after: Dictionary = declined_result.get("after", {})
	var declined_projection: Dictionary = declined.build_snapshot_data()
	_check(results, "gate2/respectful_care_decline_records_encounter_without_bond_edge", not declined_event.is_empty() and declined_event.shared_bond.delta == 0 and declined_after.bonds.is_empty() and declined_after.encounters == [["abena", "ama"]] and declined_projection.bonds.size() == 1 and declined_projection.bonds[0].strength == 0 and declined_projection.bonds[0].encounter_count == 1)
	var count_before := _social_events(declined_after, "declined_help").size()
	_steps(declined, 100)
	var count_during_cooldown := _social_events(declined.get_state(), "declined_help").size()
	_check(results, "gate2/pair_template_cooldown_prevents_repeat_farming", count_before == 1 and count_during_cooldown == count_before)

	var strained = _social_pair(["ama", "abena"], "flame", {
		"ama": {"family": "rest", "pressures": {"rest": 16.0, "company": 4.0, "purpose": 4.0}},
		"abena": {"family": "rest", "pressures": {"rest": 12.0, "company": 4.0, "purpose": 4.0}}})
	var strain_result: Dictionary = _await_social(strained, "caregiver_strain")
	var strain_event: Dictionary = strain_result.get("event", {})
	var giver_effect: Dictionary = _effect_for(strain_event, "ama")
	var receiver_effect: Dictionary = _effect_for(strain_event, "abena")
	_check(results, "gate2/caregiver_strain_tires_giver_while_helping_receiver", not strain_event.is_empty() and float(giver_effect.get("rest_delta", 0)) > 0.0 and float(receiver_effect.get("rest_delta", 0)) < 0.0)

	var no_social = _social_pair(["kweku", "yaw"], "flame", {
		"kweku": {"family": "company", "pressures": {"rest": 4.0, "company": 18.0, "purpose": 4.0}},
		"yaw": {"family": "rest", "pressures": {"rest": 18.0, "company": 10.0, "purpose": 4.0}}}, 0.0)
	var before_no_social: Dictionary = no_social.get_state()
	_steps(no_social, 400)
	var after_no_social: Dictionary = no_social.get_state()
	_check(results, "gate2/proximity_alone_creates_no_relationship_reward_or_social_history", before_no_social.bonds.is_empty() and after_no_social.bonds.is_empty() and after_no_social.encounters.is_empty() and after_no_social.impressions.is_empty() and after_no_social.incidents.is_empty() and _social_events(after_no_social).is_empty())
	var frequent = _social_pair(["kweku", "yaw"], "flame", {
		"kweku": {"family": "company", "pressures": {"rest": 4.0, "company": 18.0, "purpose": 4.0}},
		"yaw": {"family": "rest", "pressures": {"rest": 18.0, "company": 10.0, "purpose": 4.0}}}, 3.0)
	var frequent_result: Dictionary = _await_social(frequent, "unwanted_attention")
	_check(results, "gate2/social_frequency_reaches_actual_exchange_consumer", not frequent_result.get("event", {}).is_empty())


static func _default_pacing_contracts(results: Array[Dictionary]) -> void:
	var practice_events: Array = []
	var practice_by_placement: Dictionary = {}
	var open_by_placement: Dictionary = {}
	for placements: Dictionary in [
		{"hearth": "hearth_near", "training": "training_near"},
		{"hearth": "hearth_near", "training": "training_far"},
		{"hearth": "hearth_far", "training": "training_near"},
		{"hearth": "hearth_far", "training": "training_far"}]:
		var sim = Simulation.new()
		var placement_key := "%s|%s" % [placements.hearth, placements.training]
		sim.reset(int(sim.get_definition().default_seed), placements)
		_act(sim, "house.start")
		var seen: Dictionary = {}
		# Four placement combinations at the authored default seed and default
		# twelve-minute day length total 48 aggregate minutes.
		# Sample once per minute so bounded retention cannot hide an earlier event.
		for minute: int in range(12):
			_steps(sim, 240)
			for event: Dictionary in sim.get_state().events:
				if seen.has(event.id):
					continue
				seen[event.id] = true
				if event.kind == "social_exchange" and event.get("family", "") == "practice":
					practice_events.append(event)
					if not practice_by_placement.has(placement_key):
						practice_by_placement[placement_key] = event
				elif event.kind == "incident_open" and not open_by_placement.has(placement_key):
					open_by_placement[placement_key] = event
	_check(results, "gate2/default_fixtures_reach_practice_within_48_aggregate_minutes", practice_by_placement.size() == 4 and practice_events.all(func(event: Dictionary) -> bool: return event.place == "training" and event.participants.size() == 2) and practice_by_placement.values().all(func(event: Dictionary) -> bool: return int(event.elapsed_ms) <= 300000))
	_check(results, "gate2/default_placements_open_keeper_opportunity_by_five_minutes", open_by_placement.size() == 4 and open_by_placement.values().all(func(event: Dictionary) -> bool: return int(event.elapsed_ms) <= 300000 and event.participants.size() == 2 and not str(event.cause).is_empty()))

	var near_trip: Dictionary = _first_default_training_trip("training_near")
	var far_trip: Dictionary = _first_default_training_trip("training_far")
	var actual_routes: bool = not near_trip.is_empty() and not far_trip.is_empty()
	if actual_routes:
		actual_routes = near_trip.echo_id == far_trip.echo_id and near_trip.from_node == far_trip.from_node
		actual_routes = actual_routes and near_trip.path[-1] == "training_near" and far_trip.path[-1] == "training_far"
		actual_routes = actual_routes and not is_equal_approx(float(near_trip.distance), float(far_trip.distance))
	_check(results, "gate2/training_placement_changes_actual_default_route_opportunity", actual_routes)


static func _impression_contracts(results: Array[Dictionary]) -> void:
	var baseline_scores: Dictionary = _intent_scores([])
	var influenced_scores: Dictionary = _intent_scores([{"owner_id": "kojo", "other_id": "abena",
		"family": "companionship", "tag": "mixed_memory", "cause_event_id": 5,
		"cause": "A remembered exchange changes several current motives.", "created_ms": 0,
		"expires_ms": 720000, "influence": {"rest": 2.0, "company": -3.0, "purpose": 4.0}}])
	_check(results, "gate2/directional_social_impression_reaches_all_current_need_scores", is_equal_approx(float(influenced_scores.rest) - float(baseline_scores.rest), 2.0) and is_equal_approx(float(influenced_scores.company) - float(baseline_scores.company), -3.0) and is_equal_approx(float(influenced_scores.purpose) - float(baseline_scores.purpose), 4.0))
	var base_overrides := {
		"kweku": {"family": "company", "pressures": {"rest": 4.0, "company": 18.0, "purpose": 4.0}},
		"yaw": {"family": "rest", "pressures": {"rest": 6.0, "company": 10.0, "purpose": 4.0}}}
	var plain = _social_pair(["kweku", "yaw"], "flame", base_overrides)
	var plain_result: Dictionary = _await_social(plain, "quiet_company")
	var influenced = _social_pair(["kweku", "yaw"], "flame", base_overrides)
	var influenced_state: Dictionary = influenced.get_state()
	influenced_state.impressions = [{"owner_id": "yaw", "other_id": "kweku", "family": "companionship",
		"tag": "crowded", "cause_event_id": 700, "cause": "A retained concrete boundary.",
		"created_ms": 0, "expires_ms": 720000, "influence": {"company": -2}}]
	influenced.set("_state", influenced_state)
	var influenced_result: Dictionary = _await_social(influenced, "unwanted_attention")
	_check(results, "gate2/directional_impression_changes_behavior_without_changing_bond", not plain_result.get("event", {}).is_empty() and not influenced_result.get("event", {}).is_empty() and plain.get_state().bonds[0].strength > 0 and influenced_result.before.bonds.is_empty())
	var after: Dictionary = influenced_result.after
	var pair_impressions: Array = after.impressions.filter(func(impression: Dictionary) -> bool: return impression.owner_id == "yaw" and impression.other_id == "kweku" and impression.family == "companionship")
	_check(results, "gate2/later_family_impression_replaces_directional_entry", pair_impressions.size() == 1 and pair_impressions[0].cause_event_id == influenced_result.event.id and pair_impressions[0].cause != "A retained concrete boundary.")
	var expiry_before: int = int(pair_impressions[0].expires_ms)
	_act(influenced, "tuning.set", {"key": "day_minutes", "value": 3})
	_check(results, "gate2/day_tuning_does_not_rescale_existing_impression_expiry", int(influenced.get_state().impressions.filter(func(impression: Dictionary) -> bool: return impression.owner_id == "yaw")[0].expires_ms) == expiry_before)
	var expiry_state: Dictionary = influenced.get_state()
	for impression: Dictionary in expiry_state.impressions:
		impression.expires_ms = int(expiry_state.elapsed_ms) + 250
	expiry_state.events = []
	expiry_state.event_serial = 0
	influenced.set("_state", expiry_state)
	_steps(influenced, 1)
	var expired: Dictionary = influenced.get_state()
	_check(results, "gate2/impressions_expire_by_simulation_time_but_leave_history", expired.impressions.is_empty() and expired.events.any(func(event: Dictionary) -> bool: return event.kind == "impression" and event.title == "An impression faded"))
	var retained_state: Dictionary = plain.get_state()
	var retained_bonds: Array = retained_state.bonds.duplicate(true)
	var retained_encounters: Array = retained_state.encounters.duplicate(true)
	var retained_impressions: Array = retained_state.impressions.duplicate(true)
	retained_state.events = []
	for id: int in range(1000, 1512):
		retained_state.events.append(_event(id, "activity_started", false))
	retained_state.event_serial = 1511
	plain.set("_state", retained_state)
	var retained_projection: Dictionary = plain.build_snapshot_data()
	_check(results, "gate2/history_pruning_does_not_reset_relationship_knowledge", plain.get_state().bonds == retained_bonds and plain.get_state().encounters == retained_encounters and retained_projection.bonds.size() == 1)
	_check(results, "gate2/pruned_impression_retains_copied_explanatory_cause", plain.get_state().impressions == retained_impressions and retained_projection.echoes.any(func(echo: Dictionary) -> bool: return echo.impressions.any(func(impression: Dictionary) -> bool: return not str(impression.cause).is_empty() and not retained_state.events.any(func(raw: Dictionary) -> bool: return raw.id == impression.cause_event_id))))


static func _incident_contracts(results: Array[Dictionary]) -> void:
	var warning_fixture: Dictionary = _warning_fixture(15.0, 15.0)
	var sim = warning_fixture.sim
	var warning: Dictionary = warning_fixture.incident
	var warning_projection: Dictionary = _incident(sim.build_snapshot_data(), warning.id)
	var incident_keys := ["id", "family", "template_id", "label", "status", "participants", "place", "cause",
		"created_ms", "stage_started_ms", "stage_deadline_ms", "intervention_deadline_ms",
		"remaining_ms", "keeper_access", "appeal_echo_id", "access_reason", "exchange_lines",
		"can_join", "reply_choices", "result", "release_at_ms"]
	_check(results, "gate2/tense_exchange_creates_exact_warning_projection", warning_projection.has_all(incident_keys) and warning_projection.size() == incident_keys.size() and warning_projection.status == "warning" and not warning_projection.can_join and warning_projection.reply_choices.is_empty() and warning_projection.result.is_empty() and warning_projection.stage_deadline_ms == warning_projection.created_ms + 15000)
	_check(results, "gate2/warning_cannot_be_joined", not _act(sim, "incident.join", {"incident_id": warning.id}))
	_act(sim, "tuning.set", {"key": "social_frequency", "value": 0})
	_advance_to(sim, int(warning.stage_deadline_ms))
	var open: Dictionary = _incident(sim.get_state(), warning.id)
	_check(results, "gate2/warning_expiry_opens_without_silent_resolution", open.status == "open" and open.result.is_empty() and sim.get_state().events.any(func(event: Dictionary) -> bool: return event.kind == "incident_open" and event.incident_id == warning.id))
	var original_deadline: int = int(open.incident_deadline_ms)
	var joined_at: int = int(sim.get_state().elapsed_ms)
	_check(results, "gate2/open_incident_join_succeeds", _act(sim, "incident.join", {"incident_id": warning.id}))
	var joined: Dictionary = _incident(sim.get_state(), warning.id)
	var joined_projection: Dictionary = _incident(sim.build_snapshot_data(), warning.id)
	var participant_reservations: bool = joined.participants.all(func(id: String) -> bool: return _echo(sim.get_state(), id).reserved)
	_check(results, "gate2/join_is_single_idempotent_keeper_ownership", joined.status == "joined" and sim.get_state().joined_incident_id == warning.id and participant_reservations and joined.intervention_deadline_ms == mini(original_deadline, joined_at + 15000) and joined_projection.reply_choices.map(func(reply: Dictionary) -> String: return reply.id) == ["give_space", "name_harm"] and not _act(sim, "incident.join", {"incident_id": warning.id}))
	_check(results, "gate2/joined_incident_blocks_keeper_conversation", not _act(sim, "conversation.begin", {"echo_id": joined.participants[0]}))
	var donor = Simulation.new()
	_start(donor)
	var unrelated: Dictionary = _echo(donor.get_state(), "kojo").duplicate(true)
	unrelated.merge({"node": "quiet", "position": donor.get_definition().waypoints.quiet.pos.duplicate(),
		"moving": false, "path": [], "activity": "idle", "remaining_ms": 100000000,
		"duration_ms": 100000000, "reserved": false, "engagement_id": ""}, true)
	var joined_state: Dictionary = sim.get_state()
	joined_state.echoes.append(unrelated)
	sim.set("_state", joined_state)
	var unrelated_before: Dictionary = _echo(sim.get_state(), "kojo")
	_steps(sim, 4)
	var unrelated_after: Dictionary = _echo(sim.get_state(), "kojo")
	_check(results, "gate2/joined_incident_holds_only_participants_while_background_continues", unrelated_after.pressures != unrelated_before.pressures and not unrelated_after.reserved and _incident(sim.get_state(), warning.id).status == "joined")
	var commands_before_reply: int = sim.get_state().commands.size()
	_check(results, "gate2/joined_reply_commits_once", _act(sim, "incident.reply", {"incident_id": warning.id, "reply_id": "give_space"}))
	var resolved: Dictionary = _incident(sim.get_state(), warning.id)
	var resolved_projection: Dictionary = _incident(sim.build_snapshot_data(), warning.id)
	var result: Dictionary = resolved.result
	_check(results, "gate2/resolved_incident_has_structured_result_and_protected_release", resolved.status == "resolved" and result.has_all(["response", "participant_effects", "shared_bond", "aftermath"]) and result.response == "give_space" and result.participant_effects.size() == 2 and result.shared_bond.has_all(["delta", "before", "after", "bond_type_before", "bond_type_after"]) and resolved.release_at_ms == sim.get_state().elapsed_ms + 1500 and resolved_projection.remaining_ms == 1500)
	_check(results, "gate2/resolved_incident_retains_sole_keeper_ownership_and_reservations", sim.get_state().joined_incident_id == warning.id and resolved.participants.all(func(id: String) -> bool: return _echo(sim.get_state(), id).reserved) and not _act(sim, "conversation.begin", {"echo_id": resolved.participants[0]}) and not _act(sim, "incident.reply", {"incident_id": warning.id, "reply_id": "name_harm"}) and sim.get_state().commands.size() == commands_before_reply + 1)
	_steps(sim, 5)
	_check(results, "gate2/resolved_incident_remains_owned_for_first_five_steps", _incident(sim.get_state(), warning.id).status == "resolved" and sim.get_state().joined_incident_id == warning.id)
	_steps(sim, 1)
	var released_state: Dictionary = sim.get_state()
	_check(results, "gate2/incident_releases_once_after_sixth_step_into_bounded_aftermath", _incident(released_state, warning.id).is_empty() and str(released_state.joined_incident_id).is_empty() and resolved.participants.all(func(id: String) -> bool:
		var echo: Dictionary = _echo(released_state, id)
		return echo.reserved and echo.get("incident_id", "") == warning.id and echo.get("behavior", {}).get("kind", "") == "aftermath"))

	var defer_fixture: Dictionary = _warning_fixture(15.0, 45.0)
	var defer_sim = defer_fixture.sim
	_act(defer_sim, "tuning.set", {"key": "social_frequency", "value": 0})
	_advance_to(defer_sim, int(defer_fixture.incident.stage_deadline_ms))
	var defer_open: Dictionary = _incident(defer_sim.get_state(), defer_fixture.incident.id)
	var defer_deadline: int = int(defer_open.incident_deadline_ms)
	_act(defer_sim, "incident.join", {"incident_id": defer_open.id})
	_check(results, "gate2/defer_is_explicit_joined_only_action", _act(defer_sim, "incident.defer", {"incident_id": defer_open.id}))
	var deferred: Dictionary = _incident(defer_sim.get_state(), defer_open.id)
	_check(results, "gate2/defer_relinquishes_keeper_without_clearing_replenishing_or_releasing_issue", deferred.status == "open" and deferred.deferred and deferred.incident_deadline_ms == defer_deadline and str(defer_sim.get_state().joined_incident_id).is_empty() and deferred.participants.all(func(id: String) -> bool:
		var echo: Dictionary = _echo(defer_sim.get_state(), id)
		return echo.reserved and echo.get("incident_id", "") == deferred.id and echo.get("behavior", {}).get("kind", "") == "issue") and not _act(defer_sim, "incident.defer", {"incident_id": deferred.id}) and not _act(defer_sim, "incident.join", {"incident_id": deferred.id}))
	_advance_to(defer_sim, defer_deadline)
	var autonomous: Dictionary = _incident(defer_sim.get_state(), deferred.id)
	var autonomous_events: Array = defer_sim.get_state().events.filter(func(event: Dictionary) -> bool:
		return event.kind == "incident_resolved" and event.incident_id == deferred.id)
	var autonomous_event: Dictionary = autonomous_events[0] if autonomous_events.size() == 1 else {}
	_check(results, "gate2/deferred_issue_expires_to_structured_autonomous_views_without_keeper_reactions",
		autonomous.status == "resolved" and autonomous.result.response in ["settled", "frustrated"]
		and autonomous.result.has_all(["participant_effects", "shared_bond", "aftermath", "participant_views", "keeper_reactions"])
		and autonomous.result.participant_views.size() == 2
		and autonomous.result.participant_views.all(func(view: Dictionary) -> bool:
			return view.has_all(["echo_id", "other_id", "role", "view_of_other"]) and not str(view.view_of_other).is_empty())
		and autonomous.result.keeper_reactions.is_empty() and not autonomous_event.is_empty()
		and autonomous_event.get("participant_views", []).size() == 2
		and autonomous_event.get("keeper_reactions", []).is_empty())
	var lifecycle_kinds: Array = defer_sim.build_snapshot_data().village_history.map(func(summary: Dictionary) -> String: return str(summary.kind))
	_check(results, "gate2/incident_lifecycle_stages_remain_separately_visible", lifecycle_kinds.has("incident_warning") and lifecycle_kinds.has("incident_open") and lifecycle_kinds.has("incident_intervention") and lifecycle_kinds.has("incident_mutation") and lifecycle_kinds.has("incident_resolved"))

	var long_warning: Dictionary = _warning_fixture(180.0, 90.0)
	_check(results, "gate2/warning_seconds_reaches_actual_deadline_consumer", int(long_warning.incident.stage_deadline_ms) - int(long_warning.incident.created_ms) == 180000)
	var long_intervention: Dictionary = _warning_fixture(15.0, 90.0)
	var long_sim = long_intervention.sim
	_act(long_sim, "tuning.set", {"key": "social_frequency", "value": 0})
	_advance_to(long_sim, int(long_intervention.incident.stage_deadline_ms))
	var long_open: Dictionary = _incident(long_sim.get_state(), long_intervention.incident.id)
	var long_joined_at: int = int(long_sim.get_state().elapsed_ms)
	_act(long_sim, "incident.join", {"incident_id": long_open.id})
	_check(results, "gate2/intervention_seconds_reaches_actual_joined_deadline_consumer", _incident(long_sim.get_state(), long_open.id).intervention_deadline_ms == mini(int(long_open.incident_deadline_ms), long_joined_at + 90000))
	_check(results, "gate2/social_warning_intervention_replay_is_deterministic", _resolved_warning_state() == _resolved_warning_state())


static func _focused_revision_contracts(results: Array[Dictionary]) -> void:
	var fixture: Dictionary = _warning_fixture(15.0, 45.0)
	var sim = fixture.sim
	var warning: Dictionary = fixture.incident
	var fixture_ready: bool = not warning.is_empty() and warning.get("participants", []).size() == 2
	_check(results, "gate2_revision/warning_fixture_reaches_two_participant_issue", fixture_ready)
	if not fixture_ready:
		return
	_act(sim, "tuning.set", {"key": "social_frequency", "value": 0})
	var incident_id: String = str(warning.id)
	var definition: Dictionary = sim.get_definition()
	var issue_activity: String = str(definition.social.incidents.get(warning.family, {}).get("issue_activity", ""))
	var warning_start: Dictionary = sim.get_state()
	var start_positions: Dictionary = _participant_values(warning_start, warning.participants, "position")
	var start_pressures: Dictionary = _participant_values(warning_start, warning.participants, "pressures")
	var start_remaining: Dictionary = _participant_values(warning_start, warning.participants, "remaining_ms")
	var donor = Simulation.new()
	_start(donor)
	var unrelated: Dictionary = _echo(donor.get_state(), "kojo").duplicate(true)
	unrelated.merge({"node": "quiet", "position": donor.get_definition().waypoints.quiet.pos.duplicate(),
		"moving": false, "path": [], "activity": "idle", "remaining_ms": 100000000,
		"duration_ms": 100000000, "reserved": false, "engagement_id": "", "incident_id": "", "behavior": {}}, true)
	var with_unrelated: Dictionary = sim.get_state()
	with_unrelated.echoes.append(unrelated)
	sim.set("_state", with_unrelated)
	var unrelated_before: Dictionary = _echo(sim.get_state(), unrelated.id).duplicate(true)
	var warning_midpoint: int = int(warning.created_ms) + int((int(warning.stage_deadline_ms) - int(warning.created_ms)) / 2)
	_advance_to(sim, warning_midpoint)
	var midpoint: Dictionary = sim.get_state()
	var midpoint_projection: Dictionary = sim.build_snapshot_data()
	var unrelated_after: Dictionary = _echo(midpoint, unrelated.id)
	_check(results, "gate2_revision/issue_owns_participants_after_short_social_cue", midpoint.social_engagements.is_empty() and _participants_have_behavior(midpoint, warning.participants, incident_id, "issue", issue_activity, 0) and _participant_values(midpoint, warning.participants, "position") == start_positions)
	_check(results, "gate2_revision/issue_freezes_participant_pressures_and_routines_while_unrelated_echo_progresses", _participant_values(midpoint, warning.participants, "pressures") == start_pressures and _participant_values(midpoint, warning.participants, "remaining_ms") == start_remaining and unrelated_after.pressures != unrelated_before.pressures and not unrelated_after.reserved)
	_check(results, "gate2_revision/same_position_issue_participants_face_in_stable_opposite_directions", _same_position_opposite_facing(midpoint, warning.participants))
	_check(results, "gate2_revision/issue_behavior_state_and_snapshot_are_exact_independent_projections", _participant_behaviors_match_projection(midpoint, midpoint_projection, warning.participants, "issue"))

	_advance_to(sim, int(warning.stage_deadline_ms))
	var opened: Dictionary = _incident(sim.get_state(), incident_id)
	var open_midpoint: int = int(opened.stage_started_ms) + int((int(opened.incident_deadline_ms) - int(opened.stage_started_ms)) / 2)
	_advance_to(sim, open_midpoint)
	var open_state: Dictionary = sim.get_state()
	var original_deadline: int = int(_incident(open_state, incident_id).incident_deadline_ms)
	_check(results, "gate2_revision/open_midpoint_keeps_original_people_place_and_issue_ownership", _incident(open_state, incident_id).status == "open" and _participants_have_behavior(open_state, warning.participants, incident_id, "issue", issue_activity, 0) and _participant_values(open_state, warning.participants, "position") == start_positions)
	_check(results, "gate2_revision/already_reserved_issue_participants_can_be_joined", _act(sim, "incident.join", {"incident_id": incident_id}))
	var joined_state: Dictionary = sim.get_state()
	var joined_behaviors: Dictionary = _participant_values(joined_state, warning.participants, "behavior")
	_check(results, "gate2_revision/defer_preserves_people_behavior_and_original_deadline", _act(sim, "incident.defer", {"incident_id": incident_id}))
	var deferred_state: Dictionary = sim.get_state()
	var deferred: Dictionary = _incident(deferred_state, incident_id)
	_check(results, "gate2_revision/deferred_open_relinquishes_only_keeper_ownership", deferred.status == "open" and deferred.deferred and int(deferred.incident_deadline_ms) == original_deadline and str(deferred_state.joined_incident_id).is_empty() and _participant_values(deferred_state, warning.participants, "behavior") == joined_behaviors and _participants_have_behavior(deferred_state, warning.participants, incident_id, "issue", issue_activity, 0))

	var resolution: Dictionary = _resolved_aftermath_fixture()
	var resolved_sim = resolution.get("sim")
	var resolved_id: String = str(resolution.get("incident_id", ""))
	var before_reply: Dictionary = resolution.get("before", {})
	var after_reply: Dictionary = resolution.get("after", {})
	var resolved_incident: Dictionary = _incident(after_reply, resolved_id)
	var result: Dictionary = resolved_incident.get("result", {})
	var resolved_ready: bool = resolved_sim != null and not result.is_empty()
	_check(results, "gate2_revision/reply_reaches_structured_aftermath_fixture", resolved_ready)
	if not resolved_ready:
		return
	var aftermaths: Array = result.get("aftermath_behaviors", [])
	var result_shape: bool = aftermaths.size() == 2 and aftermaths.all(func(behavior: Dictionary) -> bool:
		return behavior.size() == 11 and behavior.has_all(["echo_id", "role", "kind", "source_id", "partner_id", "activity", "orientation", "started_ms", "duration_ms", "remaining_ms", "next_intention"]) and behavior.kind == "aftermath" and behavior.source_id == resolved_id and int(behavior.duration_ms) == 6000 and int(behavior.remaining_ms) == 6000 and behavior.next_intention is Dictionary and behavior.next_intention.size() == 1 and behavior.next_intention.has("family"))
	_check(results, "gate2_revision/result_has_one_exact_6000ms_authored_aftermath_per_participant", result_shape and _aftermaths_match_authored_definition(resolved_sim.get_definition(), resolved_incident, aftermaths))
	_check(results, "gate2_revision/participant_effects_report_exact_before_after_pressures_and_emotional_status", _effects_match_exact_state(result.get("participant_effects", []), before_reply, after_reply))
	_check(results, "gate2_revision/shared_bond_reports_exact_canonical_before_after_tiers", _shared_bond_has_exact_tiers(result.get("shared_bond", {})))
	_check(results, "gate2_revision/resolution_assigns_equal_authoritative_and_projected_aftermath_behavior", _aftermaths_match_echoes(after_reply, resolved_sim.build_snapshot_data(), aftermaths))

	var consequences_at_reply: Dictionary = _resolved_consequences(after_reply, resolved_incident.participants, resolved_id)
	var resolved_events_at_reply: int = _resolved_event_count(after_reply, resolved_id)
	_steps(resolved_sim, 6)
	var protected_end: Dictionary = resolved_sim.get_state()
	_check(results, "gate2_revision/protected_result_end_removes_incident_but_keeps_aftermath_ownership", _incident(protected_end, resolved_id).is_empty() and str(protected_end.joined_incident_id).is_empty() and _participants_have_behavior(protected_end, resolved_incident.participants, resolved_id, "aftermath", "", 4500))
	_check(results, "gate2_revision/resolution_consequences_apply_exactly_once_through_protected_release", _resolved_consequences(protected_end, resolved_incident.participants, resolved_id) == consequences_at_reply and _resolved_event_count(protected_end, resolved_id) == resolved_events_at_reply)
	_steps(resolved_sim, 17)
	var before_expiry: Dictionary = resolved_sim.get_state()
	var intentions: Dictionary = _participant_next_families(before_expiry, resolved_incident.participants)
	var before_expiry_pressures: Dictionary = _participant_values(before_expiry, resolved_incident.participants, "pressures")
	var before_expiry_decisions: Dictionary = _participant_values(before_expiry, resolved_incident.participants, "decisions")
	_check(results, "gate2_revision/aftermath_remains_visible_reserved_until_final_250ms", _participants_have_behavior(before_expiry, resolved_incident.participants, resolved_id, "aftermath", "", 250))
	_steps(resolved_sim, 1)
	var expired: Dictionary = resolved_sim.get_state()
	_check(results, "gate2_revision/aftermath_expiry_commits_each_configured_next_intention_without_pressure_tick", _aftermath_expiry_committed(expired, resolved_incident.participants, intentions, before_expiry_decisions) and _participant_values(expired, resolved_incident.participants, "pressures") == before_expiry_pressures)
	_check(results, "gate2_revision/aftermath_creates_no_extra_significant_resolution_or_hidden_consequence", _resolved_event_count(expired, resolved_id) == resolved_events_at_reply and _resolved_consequences(expired, resolved_incident.participants, resolved_id) == consequences_at_reply)

	var pause_fixture: Dictionary = _resolved_aftermath_fixture()
	var pause_sim = pause_fixture.sim
	_steps(pause_sim, 6)
	var paused_before: Dictionary = pause_sim.get_state()
	for index: int in range(4):
		pause_sim.build_snapshot_data()
	_check(results, "gate2_revision/simulation_time_only_aftermath_survives_paused_snapshot_polling", pause_sim.get_state() == paused_before)
	_check(results, "gate2_revision/full_issue_reply_aftermath_replay_is_deterministic", _resolved_aftermath_replay_state() == _resolved_aftermath_replay_state())
	var isolated_expected: Dictionary = resolved_sim.build_snapshot_data()
	var isolated_mutation: Dictionary = resolved_sim.build_snapshot_data()
	for echo: Dictionary in isolated_mutation.echoes:
		echo["behavior"] = {"kind": "mutated"}
	isolated_mutation.incidents.clear()
	_check(results, "gate2_revision/behavior_and_incident_snapshots_are_deep_copies", resolved_sim.build_snapshot_data() == isolated_expected)
	resolved_sim.reset(41, PLACEMENTS)
	var reset: Dictionary = resolved_sim.get_state()
	_check(results, "gate2_revision/reset_clears_issue_and_aftermath_ownership", reset.incidents.is_empty() and str(reset.joined_incident_id).is_empty() and reset.echoes.all(func(echo: Dictionary) -> bool: return not echo.reserved and str(echo.get("incident_id", "")).is_empty() and echo.get("behavior", {}).is_empty()))


static func _participant_values(state: Dictionary, participant_ids: Array, key: String) -> Dictionary:
	var values: Dictionary = {}
	for participant_id: String in participant_ids:
		values[participant_id] = _echo(state, participant_id).get(key, null)
	return values.duplicate(true)


static func _authored_aftermath_shape(behavior: Dictionary) -> bool:
	if behavior.size() != 4 or not behavior.has_all(["duration_ms", "orientation", "activities", "next_families"]):
		return false
	if int(behavior.duration_ms) != 6000 or not str(behavior.orientation) in ["toward", "away"]:
		return false
	for mapping_key: String in ["activities", "next_families"]:
		var mapping: Dictionary = behavior[mapping_key]
		if mapping.size() != 2 or not mapping.has_all(["initiator", "receiver"]) or mapping.values().any(func(value: Variant) -> bool: return str(value).is_empty()):
			return false
	return true


static func _participants_have_behavior(state: Dictionary, participant_ids: Array, source_id: String, kind: String, activity: String, remaining_ms: int) -> bool:
	if participant_ids.size() != 2:
		return false
	for index: int in range(participant_ids.size()):
		var participant_id: String = str(participant_ids[index])
		var echo: Dictionary = _echo(state, participant_id)
		var behavior: Dictionary = echo.get("behavior", {})
		var expected_partner: String = str(participant_ids[1 - index])
		if not echo.get("reserved", false) or str(echo.get("incident_id", "")) != source_id:
			return false
		if behavior.size() != 9 or not behavior.has_all(["kind", "source_id", "partner_id", "activity", "orientation", "started_ms", "duration_ms", "remaining_ms", "next_intention"]):
			return false
		if behavior.kind != kind or behavior.source_id != source_id or behavior.partner_id != expected_partner:
			return false
		if kind == "issue" and behavior.orientation != "toward":
			return false
		if not activity.is_empty() and behavior.activity != activity:
			return false
		if remaining_ms > 0 and int(behavior.remaining_ms) != remaining_ms:
			return false
	return true


static func _same_position_opposite_facing(state: Dictionary, participant_ids: Array) -> bool:
	if participant_ids.size() != 2:
		return false
	var first: Dictionary = _echo(state, str(participant_ids[0]))
	var second: Dictionary = _echo(state, str(participant_ids[1]))
	if first.get("position", []) != second.get("position", []):
		return false
	var a := Vector2(float(first.facing[0]), float(first.facing[1]))
	var b := Vector2(float(second.facing[0]), float(second.facing[1]))
	return a.length() > 0.99 and b.length() > 0.99 and a.dot(b) < -0.99


static func _participant_behaviors_match_projection(state: Dictionary, projection: Dictionary, participant_ids: Array, kind: String) -> bool:
	for participant_id: String in participant_ids:
		var authoritative: Dictionary = _echo(state, participant_id)
		var projected: Dictionary = _echo(projection, participant_id)
		if authoritative.get("incident_id", "") != projected.get("incident_id", "") or authoritative.get("behavior", {}) != projected.get("behavior", {}) or authoritative.get("behavior", {}).get("kind", "") != kind:
			return false
	return true


static func _resolved_aftermath_fixture() -> Dictionary:
	var fixture: Dictionary = _warning_fixture(15.0, 45.0)
	var sim = fixture.sim
	if fixture.incident.is_empty():
		return {}
	_act(sim, "tuning.set", {"key": "social_frequency", "value": 0})
	_advance_to(sim, int(fixture.incident.stage_deadline_ms))
	if not _act(sim, "incident.join", {"incident_id": fixture.incident.id}):
		return {}
	var before: Dictionary = sim.get_state()
	if not _act(sim, "incident.reply", {"incident_id": fixture.incident.id, "reply_id": "give_space"}):
		return {}
	return {"sim": sim, "incident_id": fixture.incident.id, "before": before, "after": sim.get_state()}


static func _aftermaths_match_authored_definition(definition: Dictionary, incident: Dictionary, aftermaths: Array) -> bool:
	var replies: Array = definition.social.incidents.get(incident.get("family", ""), {}).get("replies", [])
	var matches: Array = replies.filter(func(reply: Dictionary) -> bool: return reply.get("id", "") == incident.get("result", {}).get("response", ""))
	if matches.size() != 1:
		return false
	var authored: Dictionary = matches[0].get("aftermath_behavior", {})
	if authored.get("duration_ms", 0) != 6000 or not authored.has_all(["orientation", "activities", "next_families"]):
		return false
	for aftermath: Dictionary in aftermaths:
		var role: String = str(aftermath.get("role", ""))
		if not role in ["initiator", "receiver"]:
			return false
		if aftermath.get("activity", "") != authored.activities.get(role, "") or aftermath.get("orientation", "") != authored.orientation or aftermath.get("next_intention", {}) != {"family": authored.next_families.get(role, "")}:
			return false
	return true


static func _effects_match_exact_state(effects: Array, before_state: Dictionary, after_state: Dictionary) -> bool:
	if effects.size() != 2:
		return false
	for effect: Dictionary in effects:
		var echo_id: String = str(effect.get("echo_id", ""))
		var before_echo: Dictionary = _echo(before_state, echo_id)
		var after_echo: Dictionary = _echo(after_state, echo_id)
		var before: Dictionary = effect.get("before", {})
		var after: Dictionary = effect.get("after", {})
		if before.size() != 4 or after.size() != 4 or not before.has_all(["rest", "company", "purpose", "emotional_status"]) or not after.has_all(["rest", "company", "purpose", "emotional_status"]):
			return false
		for family: String in ["rest", "company", "purpose"]:
			if not is_equal_approx(float(before[family]), float(before_echo.pressures[family])) or not is_equal_approx(float(after[family]), float(after_echo.pressures[family])):
				return false
			if not is_equal_approx(float(effect[family + "_delta"]), float(after[family]) - float(before[family])):
				return false
		if before.emotional_status != before_echo.emotional_status or after.emotional_status != after_echo.emotional_status:
			return false
		if not is_equal_approx(float(effect.fear_delta), float(after_echo.fear) - float(before_echo.fear)) or not is_equal_approx(float(effect.morale_delta), float(after_echo.morale) - float(before_echo.morale)):
			return false
	return true


static func _shared_bond_has_exact_tiers(shared: Dictionary) -> bool:
	if not shared.has_all(["before", "after", "tier_before", "tier_after", "tier_name_before", "tier_name_after"]):
		return false
	var before_tier: int = SocialGraph.get_tier(int(shared.before))
	var after_tier: int = SocialGraph.get_tier(int(shared.after))
	return int(shared.tier_before) == before_tier and int(shared.tier_after) == after_tier and shared.tier_name_before == SocialGraph.get_tier_name(before_tier) and shared.tier_name_after == SocialGraph.get_tier_name(after_tier)


static func _aftermaths_match_echoes(state: Dictionary, projection: Dictionary, aftermaths: Array) -> bool:
	for entry: Dictionary in aftermaths:
		var expected: Dictionary = entry.duplicate(true)
		var echo_id: String = str(expected.get("echo_id", ""))
		expected.erase("echo_id")
		expected.erase("role")
		if _echo(state, echo_id).get("behavior", {}) != expected or _echo(projection, echo_id).get("behavior", {}) != expected:
			return false
	return true


static func _resolved_consequences(state: Dictionary, participant_ids: Array, incident_id: String) -> Dictionary:
	var participants: Dictionary = {}
	for participant_id: String in participant_ids:
		var echo: Dictionary = _echo(state, participant_id)
		participants[participant_id] = {"pressures": echo.pressures.duplicate(true), "fear": echo.fear,
			"morale": echo.morale, "emotional_status": echo.emotional_status}
	return {"participants": participants, "bonds": state.bonds.duplicate(true),
		"impressions": state.impressions.duplicate(true), "resolved_events": _resolved_event_count(state, incident_id)}


static func _resolved_event_count(state: Dictionary, incident_id: String) -> int:
	return state.events.filter(func(event: Dictionary) -> bool: return event.kind == "incident_resolved" and event.get("incident_id", "") == incident_id).size()


static func _participant_next_families(state: Dictionary, participant_ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for participant_id: String in participant_ids:
		result[participant_id] = _echo(state, participant_id).get("behavior", {}).get("next_intention", {}).get("family", "")
	return result


static func _aftermath_expiry_committed(state: Dictionary, participant_ids: Array, intentions: Dictionary, decisions_before: Dictionary) -> bool:
	for participant_id: String in participant_ids:
		var echo: Dictionary = _echo(state, participant_id)
		if echo.get("reserved", true) or not str(echo.get("incident_id", "")).is_empty() or not echo.get("behavior", {}).is_empty():
			return false
		if echo.family != intentions.get(participant_id, "") or int(echo.decisions) != int(decisions_before.get(participant_id, -1)) + 1:
			return false
	return true


static func _resolved_aftermath_replay_state() -> Dictionary:
	var fixture: Dictionary = _resolved_aftermath_fixture()
	if fixture.is_empty():
		return {}
	_steps(fixture.sim, 24)
	return fixture.sim.get_state()


static func _structured_history_projection(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	_start(sim)
	var state: Dictionary = sim.get_state()
	var events: Array = []
	var id := 1
	for kind: String in SIGNIFICANT_KINDS:
		events.append(_event(id, kind, true))
		id += 1
	events.append(_event(id, "activity_started", false))
	state.events = events
	state.event_serial = id
	sim.set("_state", state)
	var data: Dictionary = sim.build_snapshot_data()
	var ids: Array = data.village_history.map(func(event: Dictionary) -> int: return int(event.id))
	var exact: bool = data.village_history.size() == SIGNIFICANT_KINDS.size()
	for summary: Dictionary in data.village_history:
		exact = exact and summary.kind in SIGNIFICANT_KINDS and summary.significant and not str(summary.title).is_empty() and summary.has_all(["participants", "place", "cause", "aftermath", "source_ids"])
	_check(results, "gate2/flame_history_uses_exact_significant_kinds_and_titles", exact and ids == [9, 8, 7, 6, 5, 4, 3, 2, 1])
	_check(results, "gate2/flame_history_excludes_ordinary_visit_sources", not ids.has(id))


static func _projection_independence_and_reset(results: Array[Dictionary]) -> void:
	var sim = Simulation.new()
	_start(sim)
	var state: Dictionary = sim.get_state()
	state.bonds = [{"actor_a": "abena", "actor_b": "kojo", "strength": -30}]
	state.encounters = [["abena", "kojo"]]
	state.encounter_counts = {"abena|kojo": 1}
	state.bond_last_events = {"abena|kojo": 4}
	state.impressions = [{"owner_id": "kojo", "other_id": "abena", "family": "practice",
		"tag": "challenged", "cause_event_id": 4, "cause": "Abena raised the standard.",
		"created_ms": 1000, "expires_ms": 721000, "influence": {"purpose": 1.5}}]
	state.cooldowns = {"abena|kojo|shared_practice": 9000}
	state.social_engagements = [{"id": "social.4", "family": "practice", "template_id": "shared_practice",
		"participants": ["abena", "kojo"], "place": "flame", "cue": "They practice together.",
		"started_ms": 1000, "duration_ms": 1500, "release_at_ms": 2000}]
	state.echoes[0].engagement_id = "social.4"
	state.echoes[1].engagement_id = "social.4"
	sim.set("_state", state)
	var first: Dictionary = sim.build_snapshot_data()
	var expected: Dictionary = first.duplicate(true)
	first.bonds.clear()
	first.social_engagements[0].participants.clear()
	first.echoes[0].impressions[0].cause = "mutated"
	var fresh: Dictionary = sim.build_snapshot_data()
	_check(results, "gate2/bonds_impressions_and_engagement_projection_are_deep_copies", fresh == expected)
	sim.reset(41, PLACEMENTS)
	var reset: Dictionary = sim.get_state()
	var reset_data: Dictionary = sim.build_snapshot_data()
	var cleared: bool = reset.bonds.is_empty() and reset.encounters.is_empty() and reset.impressions.is_empty() and reset.cooldowns.is_empty() and reset.social_engagements.is_empty() and reset.incidents.is_empty() and str(reset.joined_incident_id).is_empty()
	cleared = cleared and reset_data.bonds.is_empty() and reset_data.social_engagements.is_empty() and reset_data.incidents.is_empty() and reset_data.village_history.is_empty() and reset_data.echoes.all(func(echo: Dictionary) -> bool: return echo.bonds.is_empty() and echo.impressions.is_empty() and str(echo.engagement_id).is_empty())
	_check(results, "gate2/reset_clears_all_relationship_social_and_incident_state", cleared)


static func _event(id: int, kind: String, significant: bool) -> Dictionary:
	var event := {"id": id, "step": id, "elapsed_ms": id * 250, "day": 1,
		"day_phase": "morning", "kind": kind, "title": "Structured %s" % kind,
		"participants": ["abena", "kojo"], "place": "flame", "text": "An enacted event.",
		"cause": "A concrete cause.", "aftermath": "A concrete aftermath.", "significant": significant}
	if kind.begins_with("social") or kind in ["bond_change", "incident_mutation", "incident_intervention", "incident_resolved"]:
		event["participant_effects"] = []
		event["shared_bond"] = {"delta": 0, "before": 0, "after": 0,
			"bond_type_before": "neutral", "bond_type_after": "neutral"}
	return event


static func _social_pair(ids: Array[String], place: String, overrides: Dictionary, frequency: float = 3.0, tuning: Dictionary = {}):
	var sim = Simulation.new()
	var fixtures: Array = []
	for wanted: String in ids:
		for fixture: Dictionary in sim.get("_fixtures"):
			if fixture.id == wanted:
				fixtures.append(fixture.duplicate(true))
	sim.set("_fixtures", fixtures)
	var live_tuning := {"social_frequency": frequency, "routine_seconds": 90}
	live_tuning.merge(tuning, true)
	sim.reset(41, PLACEMENTS, live_tuning)
	_act(sim, "house.start")
	var state: Dictionary = sim.get_state()
	var node: String = sim.place_node(place)
	var position: Array = sim.get_definition().waypoints[node].pos.duplicate()
	for echo: Dictionary in state.echoes:
		echo.merge({"node": node, "position": position.duplicate(), "moving": false, "path": [],
			"destination": place, "activity": "idle", "remaining_ms": 100000000,
			"duration_ms": 100000000, "reserved": false, "engagement_id": ""}, true)
		echo.merge(overrides.get(echo.id, {}), true)
	sim.set("_state", state)
	return sim


static func _practice_warning_witness_fixture():
	return _social_pair(["abena", "kweku", "ama", "esi", "kojo", "yaw"], "training", {
		"abena": {"family": "purpose", "pressures": {"rest": 4.0, "company": 0.0, "purpose": 20.0}},
		"kweku": {"family": "purpose", "pressures": {"rest": 4.0, "company": 0.0, "purpose": 20.0}},
		"ama": {"family": "rest", "pressures": {"rest": 4.0, "company": 0.0, "purpose": 0.0}},
		"esi": {"family": "rest", "pressures": {"rest": 4.0, "company": 0.0, "purpose": 0.0}},
		"kojo": {"family": "rest", "pressures": {"rest": 16.0, "company": 0.0, "purpose": 0.0}},
		"yaw": {"family": "rest", "pressures": {"rest": 4.0, "company": 0.0, "purpose": 0.0}}},
		3.0, {"warning_seconds": 15})


static func _warning_fixture(warning_seconds: float, intervention_seconds: float) -> Dictionary:
	var sim = _social_pair(["kweku", "yaw"], "flame", {
		"kweku": {"family": "company", "pressures": {"rest": 4.0, "company": 18.0, "purpose": 4.0}},
		"yaw": {"family": "rest", "pressures": {"rest": 18.0, "company": 10.0, "purpose": 4.0}}},
		3.0, {"warning_seconds": warning_seconds, "intervention_seconds": intervention_seconds})
	var social: Dictionary = _await_social(sim, "unwanted_attention")
	var incidents: Array = social.get("after", {}).get("incidents", [])
	return {"sim": sim, "incident": incidents[0] if not incidents.is_empty() else {}}


static func _resolved_warning_state() -> Dictionary:
	var fixture: Dictionary = _warning_fixture(15.0, 15.0)
	var sim = fixture.sim
	_act(sim, "tuning.set", {"key": "social_frequency", "value": 0})
	_advance_to(sim, int(fixture.incident.stage_deadline_ms))
	_act(sim, "incident.join", {"incident_id": fixture.incident.id})
	_act(sim, "incident.reply", {"incident_id": fixture.incident.id, "reply_id": "give_space"})
	_steps(sim, 6)
	return sim.get_state()


static func _await_social(sim, template_id: String, limit: int = 800) -> Dictionary:
	for index: int in range(limit):
		var before: Dictionary = sim.get_state()
		sim.advance_step(sim.get_step() + 1)
		var after: Dictionary = sim.get_state()
		for event: Dictionary in after.events:
			if event.kind == "social_exchange" and event.get("template_id", "") == template_id and not before.events.any(func(old: Dictionary) -> bool: return old.id == event.id):
				return {"before": before, "after": after, "event": event}
	return {}


static func _await_any_social(sim, limit: int = 800) -> Dictionary:
	for index: int in range(limit):
		var before_ids: Array = sim.get_state().events.map(func(event: Dictionary) -> int: return int(event.id))
		sim.advance_step(sim.get_step() + 1)
		for event: Dictionary in sim.get_state().events:
			if event.kind == "social_exchange" and not before_ids.has(event.id):
				return event
	return {}


static func _social_events(state: Dictionary, template_id: String = "") -> Array:
	return state.events.filter(func(event: Dictionary) -> bool:
		return event.kind == "social_exchange" and (template_id.is_empty() or event.get("template_id", "") == template_id))


static func _effect_for(event: Dictionary, echo_id: String) -> Dictionary:
	for effect: Dictionary in event.get("participant_effects", []):
		if effect.echo_id == echo_id:
			return effect
	return {}


static func _emotion_choice(severe: bool) -> Dictionary:
	var overrides := {
		"ama": {"family": "rest", "pressures": {"rest": 4.0, "company": 4.0, "purpose": 4.0}},
		"abena": {"family": "rest", "pressures": {"rest": 10.0, "company": 4.0, "purpose": 4.0}},
		"kweku": {"family": "company", "pressures": {"rest": 4.0, "company": 18.0, "purpose": 4.0}}}
	if severe:
		overrides.abena["fear"] = 90
		overrides.abena["morale"] = 20
		overrides.abena["emotional_status"] = Emotion.get_emotional_status(20, 90)
	var sim = _social_pair(["ama", "abena", "kweku"], "flame", overrides)
	return _await_any_social(sim)


static func _incident(data: Dictionary, id: String) -> Dictionary:
	for incident: Dictionary in data.get("incidents", []):
		if incident.id == id:
			return incident
	return {}


static func _advance_to(sim, elapsed_ms: int) -> void:
	while int(sim.get_state().elapsed_ms) < elapsed_ms:
		sim.advance_step(sim.get_step() + 1)


static func _intent_scores(impressions: Array) -> Dictionary:
	var sim = Simulation.new()
	var fixture: Dictionary = sim.get("_fixtures")[0].duplicate(true)
	sim.set("_fixtures", [fixture])
	sim.reset(41, PLACEMENTS, {"social_frequency": 0})
	_act(sim, "house.start")
	var state: Dictionary = sim.get_state()
	state.impressions = impressions.duplicate(true)
	state.echoes[0].remaining_ms = 0
	state.echoes[0].activity = "idle"
	sim.set("_state", state)
	sim.advance_step(1)
	var scores: Dictionary = {}
	for candidate: Dictionary in sim.get_state().echoes[0].candidates:
		scores[candidate.family] = candidate.score
	return scores


static func _first_default_training_trip(training_site: String) -> Dictionary:
	var sim = Simulation.new()
	sim.reset(int(sim.get_definition().default_seed), {"hearth": "hearth_near", "training": training_site})
	_act(sim, "house.start")
	for index: int in range(1200):
		sim.advance_step(sim.get_step() + 1)
		for echo: Dictionary in sim.get_state().echoes:
			if not echo.moving or echo.destination != "training" or echo.path.is_empty():
				continue
			var previous := Vector2(float(echo.position[0]), float(echo.position[1]))
			var distance := 0.0
			for node_id: String in echo.path:
				var point_data: Array = sim.get_definition().waypoints[node_id].pos
				var point := Vector2(float(point_data[0]), float(point_data[1]))
				distance += previous.distance_to(point)
				previous = point
			return {"echo_id": echo.id, "from_node": echo.node,
				"path": echo.path.duplicate(), "distance": distance}
	return {}


static func _start(sim) -> void:
	sim.reset(41, PLACEMENTS)
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


static func _bond_to(echo: Dictionary, other_id: String) -> Dictionary:
	for bond: Dictionary in echo.get("bonds", []):
		if bond.other_id == other_id:
			return bond
	return {}


static func _check(results: Array[Dictionary], name: String, ok: bool) -> void:
	results.append({"name": name, "ok": ok})
