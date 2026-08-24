# res://core/sanctum/BondConsequenceService.gd
# V2-INFRA-003 Phase 4 Slice 4: flow-level bond (BOND-002) consequence orchestration extracted
# out of FlowRuntime.gd, following the WeaveController/VowConsequenceService extraction pattern
# (see core/runtime/controllers/WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly — requests saves via flow_ctx.request_save(reason),
#     the same choke point FlowRuntime._mark_save_requested() itself calls.
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot.
#
# THIS IS A SERVICE, NOT A CONTROLLER. All three methods are combat-teardown consequence hooks,
# called from two different call sites — _apply_victory_return_to_explore (non-final-objective
# victory) and _handle_complete_stage (stage completion, any outcome) — both of which must run
# these BEFORE flow_ctx.encounter_ctx is nulled (they read ectx.actors + echo_action_logs).
# Putting them on a controller would force those call sites' controllers to call into this one —
# and controller-to-controller calls are forbidden. A service has no such restriction.
#
# core/sanctum/SocialGraphService.gd already exists and stays exactly as it is — it holds bond
# DOMAIN rules (score deltas, edge/bond-type lookup, rival-pair classification). This class
# holds the FLOW-level orchestration that decides WHEN those domain rules run against live
# encounter/roster state and how results are threaded into save_data for the UI to read.
#
# Moved verbatim (behaviour unchanged) from FlowRuntime.gd:
#   _apply_combat_bond_triggers    → apply_combat_bond_triggers
#   _apply_bond_aftermath_modifiers → apply_bond_aftermath_modifiers
#   _seed_rival_stage_incidents    → seed_rival_stage_incidents
#
# CONFIG GETTERS — corrected from the story brief: the brief listed four "_get_*_cfg" helpers
# (_get_bond_triggers_cfg, _get_bond_behavior_cfg, _get_rival_archetypes_cfg,
# _get_bond_recovery_cfg) as methods to move onto this service. All four are plain "read a
# named subtree of balance.json" reads — three are direct siblings of
# ConfigService.get_bond_thresholds_cfg under data.sanctum, and the fourth
# (get_bond_recovery_cfg) is nested under the same data.emotion.recovery parent as
# get_emotion_recovery_cfg (see EmotionConsequenceService's header for that one). Per the
# established config-getter rule they now live on ConfigService as get_bond_triggers_cfg,
# get_bond_behavior_cfg, get_rival_archetypes_cfg and get_bond_recovery_cfg instead — not
# duplicated here. (get_bond_behavior_cfg has a second caller too: FlowRuntime's per-turn
# ActorStateMachine ctx builder, at the "bond_behavior_cfg" key — another reason it belongs on
# the shared owner rather than this service.)
#
# _voice_service() below is the same "service calling a service, builds its own scoped
# instance" pattern VowConsequenceService uses for its own _voice_service() helper — not a
# duplicate, since NarrativeVoiceService is the one real owner of the bark-selection logic it
# calls into.

class_name BondConsequenceService
extends RefCounted

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


# BOND-002: Fires all stage-level bond score deltas after a combat stage ends.
# Must be called BEFORE encounter_ctx is nulled (reads ectx.actors + echo_action_logs).
func apply_combat_bond_triggers(t: int, outcome: String) -> void:
	if flow_ctx.encounter_ctx == null:
		return
	var ectx: EncounterContext = flow_ctx.encounter_ctx

	var bond_cfg := ConfigService.get_bond_triggers_cfg(config_service)
	var thresholds := ConfigService.get_bond_thresholds_cfg(config_service)
	var rival_pairs_cfg := ConfigService.get_rival_archetypes_cfg(config_service)

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []

	# V2-VOICE-001: snapshot pre-combat friend pairs (before any deltas are applied).
	# Used at end of function to detect newly-formed bonds.
	var _pre_friend_pair_keys: Dictionary = {}  # "id_a|id_b" → true

	var is_victory := outcome == "win"

	# Collect echo actors + classify KO'd vs surviving
	var echo_actors: Array = []
	var ko_echo_ids: Array = []
	var surviving_echo_ids: Array = []
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) != "echo":
			continue
		echo_actors.append(a)
		var aid := str(a.get("id", ""))
		if a.get("is_dead", false):
			ko_echo_ids.append(aid)
		else:
			surviving_echo_ids.append(aid)

	# Near-wipe: victory AND at least one echo KO'd (party survived but took losses)
	var near_wipe := is_victory and not ko_echo_ids.is_empty()

	# V2-VOICE-001: snapshot pre-combat friend pairs (before any bond deltas are applied).
	# Bonds array is mutated in place by apply_score_delta, so we must capture this BEFORE the loop.
	for _pre_i in range(echo_actors.size()):
		for _pre_j in range(_pre_i + 1, echo_actors.size()):
			var _pre_a_id := str((echo_actors[_pre_i] as Dictionary).get("id", ""))
			var _pre_b_id := str((echo_actors[_pre_j] as Dictionary).get("id", ""))
			var _pre_edge := SocialGraphService.get_edge(bonds, _pre_a_id, _pre_b_id)
			if not _pre_edge.is_empty():
				var _pre_str := int(_pre_edge.get("strength", 0))
				if SocialGraphService.get_bond_type(_pre_str, thresholds) == "friend":
					var _pair_key: String = _pre_a_id + "|" + _pre_b_id if _pre_a_id < _pre_b_id else _pre_b_id + "|" + _pre_a_id
					_pre_friend_pair_keys[_pair_key] = true

	# Iterate all canonical pairs of echo actors
	for i in range(echo_actors.size()):
		for j in range(i + 1, echo_actors.size()):
			var a: Dictionary = echo_actors[i]
			var b: Dictionary = echo_actors[j]
			var a_id := str(a.get("id", ""))
			var b_id := str(b.get("id", ""))

			var a_arch := str(a.get("archetype_birth", ""))
			var b_arch := str(b.get("archetype_birth", ""))
			var is_incompat := SocialGraphService.is_rival_archetype_pair(a_arch, b_arch, rival_pairs_cfg)

			# shared_combat_proximity: +1 for all pairs that shared the board
			var proximity_delta := int(bond_cfg.get("shared_combat_proximity", 1))
			bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, proximity_delta, thresholds, logger, t)

			# shared_stage_win (+3) or stage_defeat_shared (-3): all pairs, every stage
			if is_victory:
				var win_delta := int(bond_cfg.get("shared_stage_win", 3))
				bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, win_delta, thresholds, logger, t)
			else:
				var loss_delta := int(bond_cfg.get("stage_defeat_shared", -3))
				bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, loss_delta, thresholds, logger, t)

			# archetype_incompatible_shared_stage: -5 for incompatible archetype pairs
			if is_incompat:
				var incompat_delta := int(bond_cfg.get("archetype_incompatible_shared_stage", -5))
				bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, incompat_delta, thresholds, logger, t)

			# ko_incompatible_no_protect: -10 if incompatible pair, one KO'd, neither guarded
			var a_ko := a_id in ko_echo_ids
			var b_ko := b_id in ko_echo_ids
			if is_incompat and (a_ko or b_ko):
				var a_guards := int(ectx.echo_action_logs.get(a_id, {}).get("guard_count", 0))
				var b_guards := int(ectx.echo_action_logs.get(b_id, {}).get("guard_count", 0))
				if a_guards == 0 and b_guards == 0:
					var incompat_ko_delta := int(bond_cfg.get("ko_incompatible_no_protect", -10))
					bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, incompat_ko_delta, thresholds, logger, t)

			# protect_action_for_ally: +8 if friend-tier pair and either guarded during stage
			var edge_now := SocialGraphService.get_edge(bonds, a_id, b_id)
			var strength_now := int(edge_now.get("strength", 0))
			var bond_type_now := SocialGraphService.get_bond_type(strength_now, thresholds)
			if bond_type_now == "friend":
				var a_guards_p := int(ectx.echo_action_logs.get(a_id, {}).get("guard_count", 0))
				var b_guards_p := int(ectx.echo_action_logs.get(b_id, {}).get("guard_count", 0))
				if a_guards_p > 0 or b_guards_p > 0:
					var protect_delta := int(bond_cfg.get("protect_action_for_ally", 8))
					bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, protect_delta, thresholds, logger, t)

			# witnessed_ally_sacrifice: +12 when one bonded (non-neutral) echo was KO'd
			if (a_ko or b_ko) and not (a_ko and b_ko):
				var edge_sac := SocialGraphService.get_edge(bonds, a_id, b_id)
				if not edge_sac.is_empty():
					var strength_sac := int(edge_sac.get("strength", 0))
					var bond_type_sac := SocialGraphService.get_bond_type(strength_sac, thresholds)
					if bond_type_sac != "neutral":
						var sac_delta := int(bond_cfg.get("witnessed_ally_sacrifice", 12))
						bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, sac_delta, thresholds, logger, t)

			# near_wipe_survival_together: +10 if victory, ≥1 KO'd elsewhere, both in this pair survived
			if near_wipe and not a_ko and not b_ko:
				var nw_delta := int(bond_cfg.get("near_wipe_survival_together", 10))
				bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, nw_delta, thresholds, logger, t)

	# V2-VOICE-001: detect newly-formed friend bonds (crossed threshold this combat).
	# Compare post-combat friend pairs against the pre-combat snapshot captured above.
	var _new_friend_pairs: Array = []
	for _i in range(echo_actors.size()):
		for _j in range(_i + 1, echo_actors.size()):
			var _fa: Dictionary = echo_actors[_i]
			var _fb: Dictionary = echo_actors[_j]
			var _fa_id := str(_fa.get("id", ""))
			var _fb_id := str(_fb.get("id", ""))
			var _edge := SocialGraphService.get_edge(bonds, _fa_id, _fb_id)
			if _edge.is_empty():
				continue
			var _str_now := int(_edge.get("strength", 0))
			var _bond_now := SocialGraphService.get_bond_type(_str_now, thresholds)
			if _bond_now == "friend":
				var _pair_key: String = _fa_id + "|" + _fb_id if _fa_id < _fb_id else _fb_id + "|" + _fa_id
				if not _pre_friend_pair_keys.has(_pair_key):
					_new_friend_pairs.append([_fa, _fb])

	sanctum["bonds"] = bonds
	flow_ctx.save_data["sanctum"] = sanctum
	flow_ctx.request_save("bond.combat_triggers")

	logger.info(t, "bond.combat_triggers.applied", "Combat bond triggers fired", {
		"outcome":           outcome,
		"echo_count":        echo_actors.size(),
		"ko_count":          ko_echo_ids.size(),
		"near_wipe":         near_wipe,
	})

	# V2-VOICE-001: write bond_formed barks for newly-formed friend pairs.
	var _roster_v2: Variant = (flow_ctx.save_data.get("sanctum", {}) as Dictionary).get("roster", [])
	var _roster_arr: Array = _roster_v2 if _roster_v2 is Array else []
	for _pair_v in _new_friend_pairs:
		var _pair: Array = _pair_v
		if _pair.size() < 2:
			continue
		_voice_service().select_sanctum_bark_for_actor_and_write(_pair[0], "sanctum.bond_formed", t, _roster_arr)
		_voice_service().select_sanctum_bark_for_actor_and_write(_pair[1], "sanctum.bond_formed", t, _roster_arr)
		logger.debug(t, "voice.bond_formed_bark", "Bond formed bark written", {
			"actor_a": str((_pair[0] as Dictionary).get("id", "")),
			"actor_b": str((_pair[1] as Dictionary).get("id", "")),
		})
	if not _new_friend_pairs.is_empty():
		var _sanctum_mut: Variant = flow_ctx.save_data.get("sanctum", {})
		if _sanctum_mut is Dictionary:
			(_sanctum_mut as Dictionary)["roster"] = _roster_arr


# BOND-002: Applies EmotionRecoveryService modifiers to surviving roster echoes after combat.
# Grief: bonded echo (non-neutral) was KO'd → slowed morale recovery, heightened fear recovery.
# Shared survival bonus: near-wipe victory AND bonded friend also survived → improved recovery.
# Must be called BEFORE encounter_ctx is nulled.
func apply_bond_aftermath_modifiers(t: int, outcome: String) -> void:
	if flow_ctx.encounter_ctx == null:
		return
	var ectx: EncounterContext = flow_ctx.encounter_ctx

	var thresholds := ConfigService.get_bond_thresholds_cfg(config_service)
	var bond_rec_cfg := ConfigService.get_bond_recovery_cfg(config_service)
	if bond_rec_cfg.is_empty():
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var is_victory := outcome == "win"

	# Collect KO'd and surviving echo IDs from encounter actors
	var ko_ids: Array = []
	var surviving_ids: Array = []
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) != "echo":
			continue
		var aid := str(a.get("id", ""))
		if a.get("is_dead", false):
			ko_ids.append(aid)
		else:
			surviving_ids.append(aid)

	var near_wipe := is_victory and not ko_ids.is_empty()

	# Apply modifiers to surviving roster echoes (not runtime actor dicts)
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var echo_id := str(echo.get("id", ""))
		if not (echo_id in surviving_ids):
			continue

		# Grief: check if any bonded (non-neutral) echo was KO'd
		var bonded_ko := false
		for ko_id in ko_ids:
			var edge := SocialGraphService.get_edge(bonds, echo_id, ko_id)
			if edge.is_empty():
				continue
			var strength := int(edge.get("strength", 0))
			if SocialGraphService.get_bond_type(strength, thresholds) != "neutral":
				bonded_ko = true
				break

		if bonded_ko:
			var grief_morale_mul := float(bond_rec_cfg.get("grief_morale_mul", 0.5))
			var grief_fear_mul   := float(bond_rec_cfg.get("grief_fear_mul",   1.5))
			var grief_ticks      := int(bond_rec_cfg.get("grief_ticks",        3))
			EmotionRecoveryService.set_modifier(echo, grief_morale_mul, grief_fear_mul, grief_ticks, logger, t)
		elif near_wipe:
			# Shared survival bonus: bonded friend also survived the near-wipe
			var bonded_friend_survived := false
			for surv_id in surviving_ids:
				if surv_id == echo_id:
					continue
				var edge := SocialGraphService.get_edge(bonds, echo_id, surv_id)
				if edge.is_empty():
					continue
				var strength := int(edge.get("strength", 0))
				if SocialGraphService.get_bond_type(strength, thresholds) == "friend":
					bonded_friend_survived = true
					break
			if bonded_friend_survived:
				var surv_morale_mul := float(bond_rec_cfg.get("shared_survival_morale_mul", 1.5))
				var surv_fear_mul   := float(bond_rec_cfg.get("shared_survival_fear_mul",   0.7))
				var surv_ticks      := int(bond_rec_cfg.get("shared_survival_ticks",         2))
				EmotionRecoveryService.set_modifier(echo, surv_morale_mul, surv_fear_mul, surv_ticks, logger, t)


# BOND-002: Seeds rival_incidents[] for V2-SANCTUM-005 (incident system).
# For each rival-tier pair among encounter actors: appends canonical [a_id, b_id] if not present.
# Must be called BEFORE encounter_ctx is nulled.
func seed_rival_stage_incidents(t: int) -> void:
	if flow_ctx.encounter_ctx == null:
		return
	var ectx: EncounterContext = flow_ctx.encounter_ctx

	var thresholds := ConfigService.get_bond_thresholds_cfg(config_service)

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var incidents_v: Variant = sanctum.get("rival_incidents", [])
	var incidents: Array = incidents_v if incidents_v is Array else []

	# Collect echo actor IDs from this encounter
	var echo_ids: Array = []
	for a_v in ectx.actors:
		if a_v is Dictionary and str(a_v.get("faction", "")) == "echo":
			echo_ids.append(str(a_v.get("id", "")))

	var added := 0
	for i in range(echo_ids.size()):
		for j in range(i + 1, echo_ids.size()):
			var a_id: String = echo_ids[i]
			var b_id: String = echo_ids[j]
			var edge := SocialGraphService.get_edge(bonds, a_id, b_id)
			if edge.is_empty():
				continue
			var strength := int(edge.get("strength", 0))
			if SocialGraphService.get_bond_type(strength, thresholds) != "rival":
				continue
			# Canonical pair (alphabetical)
			var pair: Array = [a_id, b_id] if a_id < b_id else [b_id, a_id]
			var already_seeded := false
			for inc_v in incidents:
				if (inc_v is Array) and (inc_v as Array).size() >= 2:
					var inc: Array = inc_v
					if str(inc[0]) == pair[0] and str(inc[1]) == pair[1]:
						already_seeded = true
						break
			if not already_seeded:
				incidents.append(pair)
				added += 1

	if added > 0:
		sanctum["rival_incidents"] = incidents
		flow_ctx.save_data["sanctum"] = sanctum
		flow_ctx.request_save("bond.rival_incidents")
		logger.info(t, "bond.rival_incidents.seeded", "Rival incident seeds written", {
			"added": added,
			"total": incidents.size(),
		})


## V2-INFRA-003 Phase 4 Slice 4: builds a fresh NarrativeVoiceService scoped to the current
## flow_ctx/config_service/logger. Same per-call construction rationale as
## VowConsequenceService._voice_service() — cheap RefCounted, always correct even if flow_ctx
## is replaced after construction. NarrativeVoiceService is the one real owner of the bark-
## selection logic; this is a service calling a service (no restriction on that, unlike
## controller-to-controller calls).
func _voice_service() -> NarrativeVoiceService:
	return NarrativeVoiceService.new(flow_ctx, config_service, logger)
