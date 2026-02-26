# res://core/sanctum/EchoFactory.gd
extends RefCounted

class_name EchoFactory

# EchoFactory - deterministic Echo generation for the sanctum
#
# Contract:
# - Pure generator: No OS time
# - Deterministic RNG comes ONLY from (seed_root, seed_path) CampaignSeed.
# - RNG draw order MUST remain stable. If we ever change it, we must version it.
#
# RNG draw order v1 (do not change without schema/version decision):
# (1) rarity roll (uncalled/called/chosen) -> MVP clamps output to "uncalled" but still consumes draw
# (2) calling_origin (weighted; includes "uncalled" at 90%)
# (3) gender bit (50/50)
# (4) name (first, last)
# (5) traits: courage, wisdom, faith
# (6) archetype_birth derived from traits (simple mapping v1)
# (7) derived stats computed from traits (balance.json birth_stats).
#
# Output: a Dictionary suitable to store in sanctum.roster[].

static func generate(
	seed_root: String,
	seed_path: String,
	summon_index: int,
	origin: String,
	summoning_cfg: Dictionary
) -> Dictionary:
	# Convert seed_root string -> deterministic int parent seed.
	# NOTE: String.hash() is stable within Godot for deterministic use in this project.
	var parent_seed: int = int(seed_root.hash())
	var rng := CampaignSeed.get_rng_from(parent_seed, seed_path)
	
	# ---- (1) rarity tier roll (consumed, then MVP clamp) --- 
	var rarity_raw := _roll_rarity_tier(rng, summoning_cfg)
	var rarity := "uncalled" # MVP policy: always uncalled for now. Post MVP we will add called and chosen. User will be able to select which one in UI.
	
	# ---- (2) calling_origin roll ----
	var calling_origin := _roll_weighted_key(
		rng,
		summoning_cfg.get("calling_weights", {})
	)
	if calling_origin.is_empty():
		calling_origin = "uncalled"
		
	# ---- (3) gender bit (50/50) ----
	var gender := "female" if ((rng.randi() & 1) == 0) else "male"
	
	# ---- (4) name ----
	var full_name := NameBank.build_full_name(gender, rng)
	
	# ---- (5) trait rolls ----
	var trait_min := int(summoning_cfg.get("trait_min", 30))
	var trait_max := int(summoning_cfg.get("trait_max", 70))
	
	var courage := rng.randi_range(trait_min, trait_max)
	var wisdom := rng.randi_range(trait_min, trait_max)
	var faith := rng.randi_range(trait_min, trait_max)
	
	# ---- (6) archetype_birth derived from traits ----
	var archetype_birth := _derive_archetype_birth(courage, wisdom, faith)
	
	# ---- (7) derived stats ---
	var stats := _compute_birth_stats(courage, wisdom, faith, summoning_cfg.get("birth_stats", {}))
	
	# Keep vectors empty at birth (spec: vectors accumulate over time)
	var vector_scores := {}
	
	# generation_context: reserved for future emotion/rarity modifiers.
	# Keep minimal + stable (additive only),
	var generation_context := {
		"version": 1,
		"rarity_raw": rarity_raw,
		"seed_root": seed_root,
		"seed_path": seed_path,
		"modifiers": {}
	}
	
	return {
		# NOTE: id is assigned by the caller (FlowRuntime / future Actor system).
		# We keep generation deterministic independent of id.
		"id": "",
		"name": full_name,
		"gender": gender,
		
		"seed_path": seed_path,
		"summon_index": summon_index,
		"origin": origin,
		
		# prgression-facing stable identity
		"rarity": rarity,
		"calling_origin": calling_origin,
		"archetype_birth": archetype_birth,
		
		"traits": {
			"courage": courage,
			"wisdom": wisdom,
			"faith": faith
		},
		"stats": stats,
		
		#progression reserves
		"xp_total": 0,
		"rank": 1,
		"vector_scores": vector_scores,
		
		"generation_context": generation_context
	}
	
# -------------------------
# Helpers
# -------------------------

static func _roll_rarity_tier(rng: RandomNumberGenerator, summoning_cfg: Dictionary) -> String:
	# If we add rarity weights later, we can read them here:
	# summoning_cfg["rarity_weights"] = { "uncalled": 0.9, "called": 0.09, "chosen": 0.01 }
	# For now, consume a deterministic draw so future enabling doesn't reshuffle streams.
	var weights = summoning_cfg.get("rarity_weights", {})
	if typeof(weights) == TYPE_DICTIONARY and not weights.is_empty():
		return _roll_weighted_key(rng, weights)
	# default: 3-tier draw, even though MVP clamps output
	var r := int(rng.randi_range(0, 99))
	if r < 90:
		return "uncalled"
	elif r < 99:
		return "called"
	return "chosen"

static func _roll_weighted_key(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	if typeof(weights) != TYPE_DICTIONARY or weights.is_empty():
		return ""
	
	# Deterministic weighted pick with float weights.
	# We compute total weight then draw in [0, total].
	var keys := weights.keys()
	var total := 0.0
	for k in keys:
		var w = weights.get(k, 0.0)
		if typeof(w) == TYPE_INT or typeof(w) == TYPE_FLOAT:
			if float(w) > 0.0:
				total += float(w)
	
	if total <= 0.0:
		return ""
	
	var roll := rng.randf() * total
	var acc := 0.0
	for k in keys:
		var w = weights.get(k, 0.0)
		if typeof(w) == TYPE_INT or typeof(w) == TYPE_FLOAT:
			var wf := float(w)
			if wf <= 0.0:
				continue
			acc += wf
			if roll <= acc:
				return str(k)
	
	# fallbak (should not happen, but deterministic)
	return str(keys[keys.size() - 1])
	
static func _derive_archetype_birth(courage: int, wisdom: int, faith: int) -> String:
	# v1 mapping: dominant trait decides archetype label.
	# This is intentionally simple and deterministic; later we can replace with a config-driven matrix.
	if courage >= wisdom and courage >= faith:
		return "brave"
	if wisdom >= courage and wisdom >= faith:
		return "sage"
	return "devout"

static func _compute_birth_stats(courage: int, wisdom: int, faith: int, birth_cfg: Dictionary) -> Dictionary:
	# Actor progression spec MVP keys: max_hp, atk, def, agi, int, cha
	var hp_base := float(birth_cfg.get("hp_base", 100))
	var hp_cour_mul := float(birth_cfg.get("hp_courage_mul", 0.25))
	var hp_faith_mul := float(birth_cfg.get("hp_faith_mul", 0.15))
	var hp_min := int(birth_cfg.get("hp_min", 15))
	
	var atk_base := float(birth_cfg.get("atk_base", 4))
	var atk_cour_mul := float(birth_cfg.get("atk_courage_mul", 0.12))
	var atk_faith_mul := float(birth_cfg.get("atk_faith_mul", 0.05))

	var def_base := float(birth_cfg.get("def_base", 2))
	var def_wis_mul := float(birth_cfg.get("def_wisdom_mul", 0.12))
	var def_faith_mul := float(birth_cfg.get("def_faith_mul", 0.08))

	var agi_base := float(birth_cfg.get("agi_base", 2))
	var agi_wis_mul := float(birth_cfg.get("agi_wisdom_mul", 0.08))
	var agi_cour_mul := float(birth_cfg.get("agi_courage_mul", 0.08))

	var int_base := float(birth_cfg.get("int_base", 4))
	var int_wis_mul := float(birth_cfg.get("int_wisdom_mul", 0.22))
	var int_cour_mul := float(birth_cfg.get("int_courage_mul", 0.04))

	var cha_base := float(birth_cfg.get("cha_base", 1))
	var cha_faith_mul := float(birth_cfg.get("cha_faith_mul", 0.08))
	var cha_wis_mul := float(birth_cfg.get("cha_wisdom_mul", 0.08))
	
	var max_hp := int(round(hp_base + hp_cour_mul * float(courage) + hp_faith_mul * float(faith)))
	if max_hp < hp_min:
		max_hp = hp_min
	
	var atk := int(round(atk_base + atk_cour_mul * float(courage) + atk_faith_mul * float(faith)))
	if atk < 1:
		atk = 1

	var def := int(round(def_base + def_wis_mul * float(wisdom) + def_faith_mul * float(faith)))
	if def < 0:
		def = 0

	var agi := int(round(agi_base + agi_wis_mul * float(wisdom) + agi_cour_mul * float(courage)))
	if agi < 0:
		agi = 0

	var intel := int(round(int_base + int_wis_mul * float(wisdom) + int_cour_mul * float(courage)))
	if intel < 0:
		intel = 0

	var cha := int(round(cha_base + cha_faith_mul * float(faith) + cha_wis_mul * float(wisdom)))
	if cha < 0:
		cha = 0
	return {
		"max_hp": max_hp,
		"atk": atk,
		"def": def,
		"agi": agi,
		"int": intel,
		"cha": cha
	}
	
	
	
