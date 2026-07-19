# res://core/movement/MovementProfileService.gd
# V2-COMBAT-002 Slice 3 (DORMANT): movement CAPACITY profile derivation.
#
# Pure, deterministic, stateless. No RNG, no OS time, no mutation of inputs.
# NOT wired into live combat/flow — consumed at slice-6 cutover.
#
# derive_profile(actor, capacity_cfg, options) -> validated MovementProfile dict.
#   capacity_cfg is INJECTED by the caller (never read ConfigService inside core,
#   for determinism). Shape: data.combat.movement.capacity from balance.json.
#
#   options is an OPTIONAL caller-owned override channel:
#     options.authored_override = {"source": String, "capacity": int}
#       Builds a 1-capacity authored MOVER profile (e.g. the non-joining GUIDE
#       spirit's authored one-cell/round pace). The join/no-join distinction is a
#       pressure-context decision owned by the caller at slice-6 wiring — it is
#       NOT inferrable from the actor dict (a JOINED combatant spirit is also
#       is_spirit == true), so it must be passed explicitly here. Never modeled
#       as a structure (capacity stays 1, actor_kind is the actor's own kind).
#
# Capacity formula (FROZEN — Jeff-approved this session):
#   standing_capacity  = capacity of the HIGHEST standing_bands entry whose
#                        min_standing <= actor Standing (ceiling 4; S>=9 stays 4).
#   aptitude_capacity  = aptitude_base
#                        + (agi >= agi_threshold_1 ? 1 : 0)
#                        + (agi >= agi_threshold_2 ? 1 : 0)
#                        + calling_bonus[<confirmed calling id>]   (0 if none)
#                        + skill_bonus  (+1 per equipped skill id present as a
#                                        skill_bonus key; sum_okwanfo_shadow_step
#                                        is intentionally NOT a key → not counted)
#   final              = clamp(max(standing_capacity, aptitude_capacity), floor, cap)
#
# Special actor kinds:
#   structure (is_structure == true)   -> capacity 0, actor_kind "structure".
#   authored override (options.authored_override) -> capacity 1 MOVER with the
#                                         given authored one-cell/round pace.
#                                         Non-controlling. Never a structure.
#
# Actor field sources (verified against ActorSchema/EchoActor/ProgressionService):
#   Standing        : actor["standing"] (V2), fallback actor["rank"] (V1 alias).
#   agility         : actor["stats"]["agi"] (nested, per ActorSchema defaults).
#   confirmed Calling: actor["calling"] (V2-PROG-002; "" until Standing 3).
#   equipped skills : actor["equipped_skills"] (PROG-009; slot_key -> skill_id).

class_name MovementProfileService
extends RefCounted

const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")


static func derive_profile(actor: Dictionary, capacity_cfg: Dictionary, options: Dictionary = {}) -> Dictionary:
	# --- Structures never move: capacity 0, actor_kind "structure". Intrinsic. ---
	if bool(actor.get("is_structure", false)):
		return ProfileContract.build(
			0,
			[{"source": "structure", "capacity": 0}],
			false,
			"structure",
			{}
		)

	# --- Caller-driven authored override (e.g. non-joining GUIDE spirit). ---
	# The join/no-join distinction is a pressure-context decision the caller owns
	# at slice-6 wiring; it is NOT inferrable from the actor dict. Modeled as a
	# 1-capacity MOVER (never a structure), non-controlling.
	if options.has("authored_override"):
		var authored: Dictionary = options["authored_override"] as Dictionary
		var authored_capacity: int = int(authored.get("capacity", 1))
		var mover_kind: String = str(actor.get("kind", actor.get("actor_type", "npc")))
		if mover_kind == "structure":
			mover_kind = "npc"  # authored override is a mover, never a structure
		return ProfileContract.build(
			authored_capacity,
			[{"source": str(authored.get("source", "authored_override")), "capacity": authored_capacity}],
			false,
			mover_kind,
			{"source": str(authored.get("source", "authored_override")), "capacity": authored_capacity}
		)

	# --- Ordinary derivation (bare is_spirit actors derive normally here). ---
	var standing: int = int(actor.get("standing", actor.get("rank", 1)))
	var stats: Dictionary = actor.get("stats", {}) as Dictionary
	var agi: int = int(stats.get("agi", 0))
	var calling: String = str(actor.get("calling", ""))
	var equipped_skills: Dictionary = actor.get("equipped_skills", {}) as Dictionary

	var floor_cap: int = int(capacity_cfg.get("floor", 0))
	var system_cap: int = int(capacity_cfg.get("cap", 6))
	var aptitude_base: int = int(capacity_cfg.get("aptitude_base", 0))
	var agi_threshold_1: int = int(capacity_cfg.get("agi_threshold_1", 0))
	var agi_threshold_2: int = int(capacity_cfg.get("agi_threshold_2", 0))
	var calling_bonus_cfg: Dictionary = capacity_cfg.get("calling_bonus", {}) as Dictionary
	var skill_bonus_cfg: Dictionary = capacity_cfg.get("skill_bonus", {}) as Dictionary
	var standing_bands: Array = capacity_cfg.get("standing_bands", []) as Array

	var source_terms: Array = []

	# Standing capacity: highest band whose min_standing <= standing.
	var standing_capacity: int = 0
	var best_min_standing: int = -1
	for band_value: Variant in standing_bands:
		var band: Dictionary = band_value as Dictionary
		var band_min: int = int(band.get("min_standing", 0))
		if standing >= band_min and band_min > best_min_standing:
			best_min_standing = band_min
			standing_capacity = int(band.get("capacity", 0))
	source_terms.append({"source": "standing_band", "capacity": standing_capacity})

	# Aptitude capacity: base + agi thresholds + calling + equipped-skill bonuses.
	var aptitude_capacity: int = aptitude_base
	source_terms.append({"source": "aptitude_base", "capacity": aptitude_base})

	if agi >= agi_threshold_1:
		aptitude_capacity += 1
		source_terms.append({"source": "agi_threshold_1", "capacity": 1})
	if agi >= agi_threshold_2:
		aptitude_capacity += 1
		source_terms.append({"source": "agi_threshold_2", "capacity": 1})

	if not calling.is_empty() and calling_bonus_cfg.has(calling):
		var calling_bonus: int = int(calling_bonus_cfg[calling])
		if calling_bonus != 0:
			aptitude_capacity += calling_bonus
			source_terms.append({"source": "calling:%s" % calling, "capacity": calling_bonus})

	# Skill bonus: +1 per equipped skill id present as a skill_bonus key.
	# Iterate skill_bonus keys (sorted) for deterministic source_terms ordering;
	# sum_okwanfo_shadow_step is absent from the config, so it never counts.
	var equipped_ids: Dictionary = {}
	for slot_key: Variant in equipped_skills.keys():
		equipped_ids[str(equipped_skills[slot_key])] = true
	var skill_keys: Array = skill_bonus_cfg.keys()
	skill_keys.sort()
	for skill_key_value: Variant in skill_keys:
		var skill_id: String = str(skill_key_value)
		if equipped_ids.has(skill_id):
			var skill_bonus: int = int(skill_bonus_cfg[skill_id])
			if skill_bonus != 0:
				aptitude_capacity += skill_bonus
				source_terms.append({"source": "skill:%s" % skill_id, "capacity": skill_bonus})

	var raw_capacity: int = max(standing_capacity, aptitude_capacity)
	var final_capacity: int = clampi(raw_capacity, floor_cap, system_cap)

	var actor_kind: String = str(actor.get("kind", actor.get("actor_type", "echo")))
	var controlling_state: bool = _projects_control(actor)

	return ProfileContract.build(
		final_capacity,
		source_terms,
		controlling_state,
		actor_kind,
		{}
	)


# Whether this actor projects a controlling state (alive, conscious, not a
# structure). Mirrors the KO fallback used by BehaviorArbiter._crosscheck_perceived_actor.
static func _projects_control(actor: Dictionary) -> bool:
	if bool(actor.get("is_structure", false)):
		return false
	if bool(actor.get("is_dead", false)):
		return false
	var is_ko: bool = bool(actor.get("is_ko", false))
	if not actor.has("is_ko") and actor.has("current_hp"):
		is_ko = int(actor["current_hp"]) <= 0 and not bool(actor.get("is_dead", false))
	if is_ko:
		return false
	return bool(actor.get("controlling_state", true))
