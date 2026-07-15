# res://core/sanctum/RecruitmentService.gd
# V2-STAGE-004 Phase 4 (S14) — "Earned Return" recruitment.
#
# Turns a surviving `temporary_ally` contact into a permanent roster Echo.
# See ANSWERS.md #28 (mechanic + formula), #30 (companion identity + bond debuff),
# #31 (survival+victory gate — enforced by the CALLER, not this service).
#
# Contract:
# - Pure static. No RNG anywhere except `roll()`, which takes an already-seeded
#   RandomNumberGenerator from the caller (append-only namespace) — this service
#   never derives its own seed.
# - No hard-coded magic numbers: every tunable lives in data.contact.recruitment
#   (passed in as `cfg` to compute_recruit_chance; passed in as part of `cfg_data`
#   to promote_ally_to_echo).
# - promote_ally_to_echo() is a direct builder, NOT EchoFactory — EchoFactory's RNG
#   draw order is immutable (Lesson #5) and a recruited companion has no RNG-driven
#   birth to begin with; every field is derived from the ally's battle build + the
#   source contact's fields.
#
# compute_recruit_chance() formula (additive, base 0, never guaranteed):
#   chance = clampi(conversation + combat + fit, 0, cfg.cap)
#   conversation ∈ [0, cfg.conversation_max] — quality of the talk (final morale/fear
#     vs. the same "good" thresholds ConversationService uses, duplicated locally in
#     cfg) blended with conv_score_sum / winning_turns engagement.
#   combat ∈ [0, cfg.combat_max] — remaining-HP ratio, rounds-survived ratio, and
#     offensive output (damage_dealt + kills, normalized against a cfg baseline).
#   fit ∈ [0, cfg.fit_max] — vector-profile cosine similarity (contact virtue wheel →
#     vector_scores keyspace via cfg.vector_to_virtue_primary), archetype match/rival
#     bonus (SocialGraphService.is_rival_archetype_pair), and derived-stat closeness.
#   Each component's sub-weights are POINT allocations (not fractions) that sum to
#   that component's max, so summing the three returned ints always reproduces `chance`.

class_name RecruitmentService
extends RefCounted

const STAT_KEYS: Array = ["max_hp", "atk", "def", "agi", "int", "cha", "speed"]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Additive earned recruit chance. Never guaranteed (see cfg.cap).
## ally_actor: joined ally combat actor at battle end (current_hp, max_hp, is_dead,
##             death_round, archetype_birth/class_origin, stats, traits, ...).
## source_contact: the temporary_ally ContactModel dict (conv_score_sum, winning_turns,
##             morale, fear, virtue_primary, virtue_secondary, name, turn_count, ...).
## party_echoes: roster/party echo dicts (vector_scores, archetype_birth, stats).
## contribution_entry: ledger entry for this ally { damage_dealt, damage_taken, kills }.
## rounds_total: battle length, for the rounds-survived ratio.
## cfg: data.contact.recruitment block.
## Returns { chance:int, conversation:int, combat:int, fit:int }.
static func compute_recruit_chance(
	ally_actor: Dictionary,
	source_contact: Dictionary,
	party_echoes: Array,
	contribution_entry: Dictionary,
	rounds_total: int,
	cfg: Dictionary
) -> Dictionary:
	var cap: int = int(cfg.get("cap", 75))
	var conversation_max: float = float(cfg.get("conversation_max", 30.0))
	var combat_max: float = float(cfg.get("combat_max", 35.0))
	var fit_max: float = float(cfg.get("fit_max", 30.0))

	var conv: Dictionary = _conversation_component(source_contact, cfg)
	var combat: Dictionary = _combat_component(ally_actor, contribution_entry, rounds_total, cfg)
	var fit: Dictionary = _fit_component(ally_actor, source_contact, party_echoes, cfg)

	var conversation_pts: int = int(round(clampf(float(conv.get("points", 0.0)), 0.0, conversation_max)))
	var combat_pts: int = int(round(clampf(float(combat.get("points", 0.0)), 0.0, combat_max)))
	var fit_pts: int = int(round(clampf(float(fit.get("points", 0.0)), 0.0, fit_max)))

	var raw_sum: int = conversation_pts + combat_pts + fit_pts
	var chance: int = clampi(raw_sum, 0, cap)

	# Invariant: conversation + combat + fit must always sum to exactly `chance`.
	# When the raw sum exceeds the cap, proportionally scale the three components DOWN
	# using the largest-remainder method: floor each component's exact share, then hand
	# out the (small, < component-count) leftover one unit at a time to the components
	# with the largest fractional remainder. Because ratio = chance / raw_sum < 1
	# strictly whenever raw_sum > cap, floor(x * ratio) + 1 <= x for every x > 0, so no
	# rescaled component can ever exceed its pre-rescale value. At/below cap, components
	# are left untouched.
	if raw_sum > cap and raw_sum > 0:
		var ratio: float = float(chance) / float(raw_sum)
		var exact_conversation: float = float(conversation_pts) * ratio
		var exact_combat: float = float(combat_pts) * ratio
		var exact_fit: float = float(fit_pts) * ratio
		var scaled_conversation: int = int(floor(exact_conversation))
		var scaled_combat: int = int(floor(exact_combat))
		var scaled_fit: int = int(floor(exact_fit))
		var remainder: int = chance - (scaled_conversation + scaled_combat + scaled_fit)
		var fracs: Array = [
			{"key": "conversation", "frac": exact_conversation - scaled_conversation},
			{"key": "combat", "frac": exact_combat - scaled_combat},
			{"key": "fit", "frac": exact_fit - scaled_fit},
		]
		fracs.sort_custom(func(a, b): return a["frac"] > b["frac"])
		for i in range(remainder):
			match fracs[i]["key"]:
				"conversation": scaled_conversation += 1
				"combat": scaled_combat += 1
				"fit": scaled_fit += 1
		conversation_pts = scaled_conversation
		combat_pts = scaled_combat
		fit_pts = scaled_fit

	return {
		"chance": chance,
		"conversation": conversation_pts,
		"combat": combat_pts,
		"fit": fit_pts,
	}


## Deterministic single draw. success = one roll in 1..100 <= chance.
## `rng` must already be seeded by the caller (append-only namespace) — this
## function never creates or seeds its own RandomNumberGenerator.
static func roll(chance: int, rng: RandomNumberGenerator) -> bool:
	var draw: int = rng.randi_range(1, 100)
	return draw <= chance


## Mints a roster Echo from a surviving temporary_ally + its source contact, seeds
## the companion bond debuff against every existing roster echo, and returns the
## new echo id. Deterministic — no RNG (gender falls back to a stable hash of the
## contact id when absent from ally_actor/source_contact; never a coin-flip draw).
## cfg_data: the full balance `data` dict (recruitment/summoning/sanctum sub-blocks).
static func promote_ally_to_echo(
	ally_actor: Dictionary,
	source_contact: Dictionary,
	save_data: Dictionary,
	cfg_data: Dictionary,
	logger: StructuredLogger,
	t: int
) -> String:
	if not save_data.has("sanctum") or typeof(save_data["sanctum"]) != TYPE_DICTIONARY:
		save_data["sanctum"] = {}
	var sanctum: Dictionary = save_data["sanctum"]

	if not sanctum.has("roster") or typeof(sanctum["roster"]) != TYPE_ARRAY:
		sanctum["roster"] = []
	var roster: Array = sanctum["roster"] as Array

	# Snapshot existing roster ids BEFORE appending — these are the echoes that
	# receive the companion bond debuff against the new arrival.
	var existing_ids: Array = []
	for r_v in roster:
		if r_v is Dictionary:
			var existing_id: String = str((r_v as Dictionary).get("id", ""))
			if not existing_id.is_empty():
				existing_ids.append(existing_id)

	var contact_cfg_v: Variant = cfg_data.get("contact", {})
	var contact_cfg: Dictionary = contact_cfg_v if contact_cfg_v is Dictionary else {}
	var recruit_cfg_v: Variant = contact_cfg.get("recruitment", {})
	var recruit_cfg: Dictionary = recruit_cfg_v if recruit_cfg_v is Dictionary else {}

	var summoning_cfg_v: Variant = cfg_data.get("summoning", {})
	var summoning_cfg: Dictionary = summoning_cfg_v if summoning_cfg_v is Dictionary else {}
	var stat_cfg_v: Variant = summoning_cfg.get("birth_stats", {})
	var stat_cfg: Dictionary = stat_cfg_v if stat_cfg_v is Dictionary else {}

	# ---- traits + archetype (from the ally's battle build) ----
	var traits_in_v: Variant = ally_actor.get("traits", {})
	var traits_in: Dictionary = traits_in_v if traits_in_v is Dictionary else {}
	var courage: int = int(traits_in.get("courage", 50))
	var wisdom: int = int(traits_in.get("wisdom", 50))
	var faith: int = int(traits_in.get("faith", 50))
	var traits: Dictionary = { "courage": courage, "wisdom": wisdom, "faith": faith }

	var archetype_birth: String = _resolve_archetype_birth(ally_actor)

	# ---- identity ----
	var echo_id: String = "echo_%04d" % (roster.size() + 1)

	var contact_name: String = str(source_contact.get("name", "")).strip_edges()
	if contact_name.is_empty():
		contact_name = "Unnamed Companion"

	var gender: String = str(ally_actor.get("gender", str(source_contact.get("gender", ""))))
	if gender.is_empty():
		# No RNG draw here (no seed_path for a promotion event) — deterministic hash
		# of the contact's stable id, matching the codebase's established use of
		# String.hash() for deterministic-without-RNG derivation (see EchoFactory.gd).
		var gender_key: String = str(source_contact.get("id", echo_id))
		gender = "female" if (int(gender_key.hash()) % 2 == 0) else "male"

	# ---- stats: re-derived fresh at rank 1 / level 1 (the battle template was for one fight) ----
	var stats: Dictionary = DerivedStatService.compute_stats(traits, 1, 1, stat_cfg)

	# ---- vector_scores: contact virtue_primary(higher)/virtue_secondary(lower) mapped
	#      onto the vector_scores keyspace via recruit_cfg.vector_to_virtue_primary ----
	var vector_profile: Dictionary = _build_ally_vector_profile(source_contact, recruit_cfg)

	var class_origin: String = str(ally_actor.get("class_origin", ""))
	var dominant_vector: String = VectorService.compute_dominant(vector_profile, class_origin)
	if class_origin.is_empty():
		class_origin = dominant_vector
	if class_origin.is_empty():
		class_origin = "protector"

	var generation_context: Dictionary = {
		"version": 1,
		"source": "recruited_ally",
		"recruited_from_contact_id": str(source_contact.get("id", "")),
		"modifiers": {},
	}

	var echo: Dictionary = {
		"id": echo_id,
		"name": contact_name,
		"gender": gender,

		"seed_path": "",
		"summon_index": -1,
		"origin": "recruited_ally",  # durable companion marker (ANSWERS.md #30)

		"rarity": "uncalled",  # canonical tier (SaveService repairs legacy "common" -> "uncalled")
		"calling_origin": "",
		"archetype_birth": archetype_birth,
		"class_origin": class_origin,
		"level": 1,

		"traits": traits,
		"stats": stats,

		"xp_total": 0,
		"rank": 1,
		"vector_scores": vector_profile,
		"dominant_vector": dominant_vector,

		"resilience_traits": [],
		"leadership_traits": [],

		"generation_context": generation_context,
	}

	EmotionService.init_echo(echo, logger, t)

	roster.append(echo)

	# ---- companion bond debuff: seed a below-neutral edge against every existing roster echo ----
	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []

	var sanctum_cfg_v: Variant = cfg_data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_cfg_v if sanctum_cfg_v is Dictionary else {}
	var bond_thresholds_v: Variant = sanctum_cfg.get("bond_thresholds", {})
	var bond_thresholds: Dictionary = bond_thresholds_v if bond_thresholds_v is Dictionary else {}

	var debuff: int = int(recruit_cfg.get("companion_bond_debuff", -30))
	for other_id in existing_ids:
		bonds = SocialGraphService.apply_score_delta(bonds, echo_id, str(other_id), debuff, bond_thresholds, logger, t)
	sanctum["bonds"] = bonds

	logger.info(t, "sanctum.ally_recruited", "Temporary ally recruited into roster", {
		"echo_id": echo_id,
		"contact_id": str(source_contact.get("id", "")),
		"name": contact_name,
		"archetype_birth": archetype_birth,
		"class_origin": class_origin,
		"dominant_vector": dominant_vector,
		"companion_bond_debuff": debuff,
		"existing_roster_count": existing_ids.size(),
		"roster_count_after": roster.size(),
	})

	return echo_id


# ---------------------------------------------------------------------------
# Private — component formulas
# ---------------------------------------------------------------------------

## conversation ∈ [0, cfg.conversation_max]
static func _conversation_component(source_contact: Dictionary, cfg: Dictionary) -> Dictionary:
	var fear: int = int(source_contact.get("fear", 50))
	var morale: int = int(source_contact.get("morale", 50))

	var good_fear_max: int = int(cfg.get("conversation_good_fear_max", 35))
	var good_morale_min: int = int(cfg.get("conversation_good_morale_min", 60))

	# How deep into "good" the final talk state landed — 0 at the good threshold, 1 at the cap.
	var morale_component: float = 0.0
	if good_morale_min < 100:
		morale_component = clampf(float(morale - good_morale_min) / float(100 - good_morale_min), 0.0, 1.0)
	var fear_component: float = 0.0
	if good_fear_max > 0:
		fear_component = clampf(float(good_fear_max - fear) / float(good_fear_max), 0.0, 1.0)
	var quality: float = clampf((morale_component + fear_component) / 2.0, 0.0, 1.0)

	# Engagement: accumulated conversation score + share of turns "won".
	var conv_score_sum: float = float(source_contact.get("conv_score_sum", 0.0))
	var conv_baseline: float = maxf(0.0001, float(cfg.get("conv_score_baseline", 3.0)))
	var conv_norm: float = clampf(conv_score_sum / conv_baseline, 0.0, 1.0)

	var winning_turns: int = int(source_contact.get("winning_turns", 0))
	var turn_count: int = int(source_contact.get("turn_count", 0))
	var win_ratio: float = 0.0
	if turn_count > 0:
		win_ratio = clampf(float(winning_turns) / float(turn_count), 0.0, 1.0)

	var engagement: float = clampf((conv_norm + win_ratio) / 2.0, 0.0, 1.0)

	var subw_v: Variant = cfg.get("conversation_subweights", {})
	var subw: Dictionary = subw_v if subw_v is Dictionary else {}
	var w_quality: float = float(subw.get("outcome_quality", 18.0))
	var w_engagement: float = float(subw.get("engagement", 12.0))

	var points: float = quality * w_quality + engagement * w_engagement
	return { "points": points, "quality": quality, "engagement": engagement }


## combat ∈ [0, cfg.combat_max]
static func _combat_component(
	ally_actor: Dictionary,
	contribution_entry: Dictionary,
	rounds_total: int,
	cfg: Dictionary
) -> Dictionary:
	var current_hp: float = float(ally_actor.get("current_hp", 0))
	var max_hp: float = _resolve_max_hp(ally_actor)
	var hp_ratio: float = clampf(current_hp / maxf(1.0, max_hp), 0.0, 1.0)

	var death_round: int = int(ally_actor.get("death_round", 0))
	var rounds_ratio: float = 1.0
	if death_round > 0:
		rounds_ratio = clampf(float(death_round) / float(maxi(1, rounds_total)), 0.0, 1.0)

	var subw_v: Variant = cfg.get("combat_subweights", {})
	var subw: Dictionary = subw_v if subw_v is Dictionary else {}
	var baseline: float = maxf(0.0001, float(subw.get("offensive_damage_baseline", 40.0)))

	var damage_dealt: float = float(contribution_entry.get("damage_dealt", 0))
	var kills: float = float(contribution_entry.get("kills", 0))
	var offensive_norm: float = clampf((damage_dealt + kills * baseline) / (baseline * 2.0), 0.0, 1.0)

	var w_hp: float = float(subw.get("remaining_hp", 14.0))
	var w_rounds: float = float(subw.get("rounds_survived", 9.0))
	var w_off: float = float(subw.get("offensive", 12.0))

	var points: float = hp_ratio * w_hp + rounds_ratio * w_rounds + offensive_norm * w_off
	return {
		"points": points,
		"remaining_hp_ratio": hp_ratio,
		"rounds_survived_ratio": rounds_ratio,
		"offensive_norm": offensive_norm,
	}


## fit ∈ [0, cfg.fit_max]
static func _fit_component(
	ally_actor: Dictionary,
	source_contact: Dictionary,
	party_echoes: Array,
	cfg: Dictionary
) -> Dictionary:
	var subw_v: Variant = cfg.get("fit_subweights", {})
	var subw: Dictionary = subw_v if subw_v is Dictionary else {}
	var w_vector: float = float(subw.get("vector", 15.0))
	var w_archetype: float = float(subw.get("archetype", 8.0))
	var w_stat: float = float(subw.get("stat", 7.0))

	# Guard: empty party has no basis for a similarity/rivalry judgement — neutral fit.
	if party_echoes.is_empty():
		var neutral_points: float = 0.5 * w_vector + 0.5 * w_archetype + 0.5 * w_stat
		return { "points": neutral_points, "vector_sim": 0.5, "archetype_component": 0.5, "stat_sim": 0.5 }

	# ---- vector-profile similarity ----
	var ally_vec: Dictionary = _build_ally_vector_profile(source_contact, cfg)
	var party_avg_vec: Dictionary = _party_avg_vector_scores(party_echoes)
	var vector_sim: float = _cosine_similarity(ally_vec, party_avg_vec)

	# ---- archetype compatibility ----
	var ally_archetype: String = _resolve_archetype_birth(ally_actor)
	var rival_pairs_v: Variant = cfg.get("rival_archetype_pairs", [])
	var rival_pairs: Array = rival_pairs_v if rival_pairs_v is Array else []
	var match_bonus: float = float(cfg.get("archetype_match_bonus", 0.3))
	var rival_penalty: float = float(cfg.get("rival_archetype_penalty", -0.4))

	var has_match: bool = false
	var has_rival: bool = false
	for pe_v in party_echoes:
		var pe: Dictionary = pe_v if pe_v is Dictionary else {}
		var pe_arch: String = str(pe.get("archetype_birth", ""))
		if pe_arch.is_empty():
			continue
		if pe_arch == ally_archetype:
			has_match = true
		if SocialGraphService.is_rival_archetype_pair(ally_archetype, pe_arch, rival_pairs):
			has_rival = true

	var archetype_component: float = clampf(
		0.5 + (match_bonus if has_match else 0.0) + (rival_penalty if has_rival else 0.0),
		0.0, 1.0
	)

	# ---- derived-stat closeness ----
	var ally_stats_v: Variant = ally_actor.get("stats", {})
	var ally_stats: Dictionary = ally_stats_v if ally_stats_v is Dictionary else {}
	var party_avg_stats: Dictionary = _party_avg_stats(party_echoes)
	var scale: float = maxf(0.0001, float(cfg.get("stat_similarity_scale", 50.0)))

	var diff_sum: float = 0.0
	for k in STAT_KEYS:
		var av: float = float(ally_stats.get(k, 0))
		var pv: float = float(party_avg_stats.get(k, 0))
		diff_sum += clampf(absf(av - pv) / scale, 0.0, 1.0)
	var stat_sim: float = clampf(1.0 - diff_sum / float(STAT_KEYS.size()), 0.0, 1.0)

	var points: float = vector_sim * w_vector + archetype_component * w_archetype + stat_sim * w_stat
	return {
		"points": points,
		"vector_sim": vector_sim,
		"archetype_component": archetype_component,
		"stat_sim": stat_sim,
	}


# ---------------------------------------------------------------------------
# Private — shared helpers
# ---------------------------------------------------------------------------

## Resolves max_hp from an ally_actor dict, whose shape may carry max_hp at the
## top level or only nested under "stats" (ContactActorBuilder-built actors).
static func _resolve_max_hp(ally_actor: Dictionary) -> float:
	if ally_actor.has("max_hp"):
		return float(ally_actor.get("max_hp"))
	var stats_v: Variant = ally_actor.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}
	return float(stats.get("max_hp", 60))


## archetype_birth is deterministic from traits (no RNG) — prefer whatever the
## caller already attached to the ally_actor; fall back to PersonalityArchetype's
## pure trait-derivation (same rule EchoFactory itself uses at birth).
static func _resolve_archetype_birth(ally_actor: Dictionary) -> String:
	var arch: String = str(ally_actor.get("archetype_birth", ""))
	if not arch.is_empty():
		return arch
	var traits_v: Variant = ally_actor.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	var courage: int = int(traits.get("courage", 50))
	var wisdom: int = int(traits.get("wisdom", 50))
	var faith: int = int(traits.get("faith", 50))
	return PersonalityArchetype.from_traits(courage, wisdom, faith)


## Maps the contact's virtue_primary (higher weight) / virtue_secondary (lower
## weight) onto the vector_scores keyspace via cfg.vector_to_virtue_primary
## (inverted: virtue -> vector_key). Unknown/blank virtues are skipped safely.
static func _build_ally_vector_profile(source_contact: Dictionary, cfg: Dictionary) -> Dictionary:
	var v2v_v: Variant = cfg.get("vector_to_virtue_primary", {})
	var v2v: Dictionary = v2v_v if v2v_v is Dictionary else {}
	var virtue_to_vector: Dictionary = {}
	for vk in v2v:
		virtue_to_vector[str(v2v[vk])] = str(vk)

	var vp: String = str(source_contact.get("virtue_primary", ""))
	var vs: String = str(source_contact.get("virtue_secondary", ""))
	var seed_primary: float = float(cfg.get("vector_seed_primary", 60.0))
	var seed_secondary: float = float(cfg.get("vector_seed_secondary", 20.0))

	var profile: Dictionary = {}
	var key_p: String = str(virtue_to_vector.get(vp, ""))
	if not key_p.is_empty():
		profile[key_p] = float(profile.get(key_p, 0.0)) + seed_primary
	var key_s: String = str(virtue_to_vector.get(vs, ""))
	if not key_s.is_empty():
		profile[key_s] = float(profile.get(key_s, 0.0)) + seed_secondary

	return profile


## Averages vector_scores across party_echoes. Dynamic key union (no hardcoded
## keys) — matches VectorService's own convention. Returns {} for an empty party.
static func _party_avg_vector_scores(party_echoes: Array) -> Dictionary:
	var n: int = party_echoes.size()
	if n <= 0:
		return {}
	var sums: Dictionary = {}
	for pe_v in party_echoes:
		var pe: Dictionary = pe_v if pe_v is Dictionary else {}
		var vs_v: Variant = pe.get("vector_scores", {})
		var vs: Dictionary = vs_v if vs_v is Dictionary else {}
		for k in vs:
			sums[k] = float(sums.get(k, 0.0)) + float(vs[k])
	var avg: Dictionary = {}
	for k in sums:
		avg[k] = float(sums[k]) / float(n)
	return avg


## Averages the 6 derived combat stats + speed across party_echoes.
## Returns {} for an empty party.
static func _party_avg_stats(party_echoes: Array) -> Dictionary:
	var n: int = party_echoes.size()
	if n <= 0:
		return {}
	var sums: Dictionary = {}
	for k in STAT_KEYS:
		sums[k] = 0.0
	for pe_v in party_echoes:
		var pe: Dictionary = pe_v if pe_v is Dictionary else {}
		var st_v: Variant = pe.get("stats", {})
		var st: Dictionary = st_v if st_v is Dictionary else {}
		for k in STAT_KEYS:
			sums[k] = float(sums[k]) + float(st.get(k, 0))
	var avg: Dictionary = {}
	for k in STAT_KEYS:
		avg[k] = float(sums[k]) / float(n)
	return avg


## Cosine similarity over the union of keys present in either dict, clamped to
## [0, 1] (all inputs here are non-negative weights, so cosine is naturally >= 0).
## Returns a neutral 0.5 when either side carries no usable signal (zero norm).
static func _cosine_similarity(a: Dictionary, b: Dictionary) -> float:
	var keys: Dictionary = {}
	for k in a:
		keys[k] = true
	for k in b:
		keys[k] = true
	if keys.is_empty():
		return 0.5

	var dot: float = 0.0
	var norm_a: float = 0.0
	var norm_b: float = 0.0
	for k in keys:
		var va: float = float(a.get(k, 0.0))
		var vb: float = float(b.get(k, 0.0))
		dot += va * vb
		norm_a += va * va
		norm_b += vb * vb

	if norm_a <= 0.0 or norm_b <= 0.0:
		return 0.5

	return clampf(dot / (sqrt(norm_a) * sqrt(norm_b)), 0.0, 1.0)
