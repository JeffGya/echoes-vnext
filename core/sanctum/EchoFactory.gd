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
# RNG draw order v1 — draws 1-5 (IMMUTABLE — never reorder or insert between existing draws):
# (1) rarity roll (uncalled/called/chosen) -> MVP clamps output to "uncalled" but still consumes draw
# (2) calling_origin (weighted; includes "uncalled" at 90%)
# (3) gender bit (50/50)
# (4) name (first, last)
# (5) traits: courage, wisdom, faith
# [post-draw derivations, no RNG]: archetype_birth from traits; stats from traits + birth_stats
#
# RNG draw order v2 — PROG-001 addition (appended after all v1 draws):
# (6) class_origin — birth Vector bias (protector/vanguard/seeker/pillar).
#     Values always mirror the active Vector taxonomy.
#     Expand post-MVP by adding new Vectors to balance.json data.summoning.class_origin_weights.
#     class_origin_weights is the single Vector type registry for the entire system.
#     No code change needed when expanding — balance.json only.
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

	# ---- v2 draw (6): class_origin — birth Vector bias ----
	# Values mirror the active Vector taxonomy. Expand via balance.json only — no code change needed.
	var class_origin_weights: Dictionary = summoning_cfg.get("class_origin_weights", {
		"protector": 1.0, "vanguard": 1.0, "seeker": 1.0, "pillar": 1.0
	})
	var class_origin: String = _roll_weighted_key(rng, class_origin_weights)
	if class_origin.is_empty():
		class_origin = "protector"

	# ---- archetype_birth derived from traits (no RNG draw) ----
	var archetype_birth := _derive_archetype_birth(courage, wisdom, faith)
	
	# ---- (7) derived stats ---
	var stats := _compute_birth_stats(courage, wisdom, faith, summoning_cfg.get("birth_stats", {}))
	
	# Keep vectors empty at birth — VectorService.init_vectors() populates these
	# from archetype_init config immediately after summon (called by FlowRuntime).
	var vector_scores := {}
	var dominant_vector := ""  # populated by VectorService.init_vectors()
	
	# generation_context: reserved for future emotion/rarity modifiers.
	# Keep minimal + stable (additive only).
	var generation_context := {
		"version": 1,
		"rng_draw_order_version": "v2",
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
		
		# progression-facing stable identity
		"rarity": rarity,
		"calling_origin": calling_origin,
		"archetype_birth": archetype_birth,
		"class_origin": class_origin,  # birth Vector bias — same taxonomy as Vectors (v2)
		"level": 1,                    # static at generation; updated by progression systems later
		
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
		"dominant_vector": dominant_vector,  # PROG-005: populated by VectorService.init_vectors()

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

## Applies safe defaults for Echo fields introduced after draw-order v1.
## Returns true if any field was patched (caller should mark save_request = true).
## Safe to call repeatedly — no-op if all fields already present and non-null.
static func repair_echo_fields(echo: Dictionary) -> bool:
	var patched := false

	if not echo.has("level") or echo["level"] == null:
		echo["level"] = 1
		patched = true

	if not echo.has("class_origin") or echo["class_origin"] == null:
		# Best available approximation from calling_origin (always present in v1 echoes).
		# Mapping: summoning lineage → nearest birth Vector bias.
		var calling := str(echo.get("calling_origin", "uncalled"))
		var class_map := {
			"guardian": "protector",
			"warrior":  "vanguard",
			"archer":   "seeker",
			"uncalled": "pillar"
		}
		echo["class_origin"] = class_map.get(calling, "protector")
		patched = true

	# PROG-005: vector fields — additive-only, no hardcoded key names
	if not echo.has("vector_scores") or typeof(echo["vector_scores"]) != TYPE_DICTIONARY:
		# Ensure field exists as empty dict. Config unavailable here so we cannot
		# use archetype_init weights — VectorService.init_vectors() will handle
		# new summons; old echoes get neutral empty scores with class_origin as dominant.
		echo["vector_scores"] = {}
		patched = true

	if not echo.has("dominant_vector") or echo["dominant_vector"] == null \
			or str(echo["dominant_vector"]).is_empty():
		# Best fallback without config: class_origin is the birth Vector bias.
		# compute_dominant() safely returns current_dominant when total == 0.
		echo["dominant_vector"] = str(echo.get("class_origin", ""))
		patched = true

	return patched


static func _compute_birth_stats(courage: int, wisdom: int, faith: int, birth_cfg: Dictionary) -> Dictionary:
	# PROG-002: Delegates to DerivedStatService with rank=1, level=1 (birth values).
	# At birth, (rank-1) and (level-1) are both 0, so growth terms add nothing.
	# Formula and defaults are identical to the pre-PROG-002 inline code.
	var traits := { "courage": courage, "wisdom": wisdom, "faith": faith }
	return DerivedStatService.compute_stats(traits, 1, 1, birth_cfg)
	
	
	
