# res://core/combat/CombatState.gd
# COMBAT-001: Centralized combat state container.
# COMBAT-002: Initiative order added — composite scoring mirroring GridService._placement_score().
#
# Shape: {
#   "actors":                  Array,   # deep copy of placed actors at combat start
#   "objective":               String,  # from EncounterContext.resolution_mode
#   "round_counter":           int,     # starts at 0
#   "initiative_order":        Array,   # [{ "id": String, "name": String }, ...] descending score
#   "active_initiative_index": int,     # whose turn it is; always 0 at init; COMBAT-004 advances
# }

class_name CombatState

extends RefCounted

const REQUIRED_FIELDS := [
	"actors",
	"objective",
	"round_counter",
	"initiative_order",
	"active_initiative_index",
]

## Returns a new CombatState dictionary.
## actors is deep-copied so mutations to the source do not propagate.
## initiative_seed: derived from ectx.placement_seed (pass 0 in tests for seed-agnostic checks).
## init_cfg: data.combat.initiative_modifiers from balance.json (pass {} for modifier-free checks).
static func create(actors: Array, objective: String,
		initiative_seed: int = 0, init_cfg: Dictionary = {}) -> Dictionary:
	return {
		"actors":                  actors.duplicate(true),
		"objective":               objective,
		"round_counter":           0,
		"initiative_order":        _calc_initiative(actors, initiative_seed, init_cfg),
		"active_initiative_index": 0,
		# COMBAT-SEQ: sequential resolution fields — runtime only, not in REQUIRED_FIELDS.
		"current_actor_index":     0,     # pointer into initiative_order for the current round
		"round_phase":             "idle", # "idle" (between rounds) | "in_round" (round active)
	}


## Returns true if all required fields are present in the dictionary.
static func validate(state: Dictionary) -> bool:
	for f in REQUIRED_FIELDS:
		if not state.has(f):
			return false
	return true


## Calculates initiative order for all actors.
##
## Formula (per actor):
##   score = (speed * 3 + agi * 2)
##           + archetype_mod + calling_mod + trait_mod + vector_mod
##           + seed_nudge
##
## seed_nudge = CampaignSeed.derive_from(seed, actor_id) % 10
## Ensures same speeds + same seed -> identical order (determinism).
##
## Sort: descending by score.
## Tiebreak: original list position (stable — echoes before enemies = party list order).
##
## Returns: [{ "id": String, "name": String }, ...]
static func _calc_initiative(actors: Array, seed: int, cfg: Dictionary) -> Array:
	var arch_table: Dictionary  = cfg.get("by_archetype",       {})
	var call_table: Dictionary  = cfg.get("by_calling_origin",  {})
	var trait_table: Dictionary = cfg.get("by_dominant_trait",  {})
	var vec_table: Dictionary   = cfg.get("by_dominant_vector", {})

	# Build scored list with original index for stable tiebreak.
	var scored: Array = []
	for i in range(actors.size()):
		var actor_v: Variant = actors[i]
		if not actor_v is Dictionary:
			continue
		var actor := actor_v as Dictionary

		var spd: int = int(actor.get("speed", 5))
		var stats_v: Variant = actor.get("stats", {})
		var stats: Dictionary = stats_v if stats_v is Dictionary else {}
		var agi: int = int(stats.get("agi", 0))
		var base: int = spd * 3 + agi * 2

		# Archetype modifier.
		var arch_mod: int = int(arch_table.get(str(actor.get("archetype_birth", "")), 0))

		# Calling modifier.
		var call_mod: int = int(call_table.get(str(actor.get("calling_origin", "")), 0))

		# Dominant trait modifier — courage > faith > wisdom tiebreak.
		var traits_v: Variant = actor.get("traits", {})
		var traits: Dictionary = traits_v if traits_v is Dictionary else {}
		var dom_trait: String = _dominant_key(traits, ["courage", "faith", "wisdom"])
		var trait_mod: int = int(trait_table.get(dom_trait, 0))

		# Dominant vector modifier — vanguard > seeker > protector > pillar tiebreak.
		var vec_v: Variant = actor.get("vector_scores", {})
		var vectors: Dictionary = vec_v if vec_v is Dictionary else {}
		var dom_vec: String = _dominant_key(vectors, ["vanguard", "seeker", "protector", "pillar"])
		var vec_mod: int = int(vec_table.get(dom_vec, 0))

		# Deterministic seed nudge (0-9) for remaining ties.
		var actor_id: String = str(actor.get("id", ""))
		var nudge: int = int(CampaignSeed.derive_from(seed, actor_id) % 10)

		var score: int = base + arch_mod + call_mod + trait_mod + vec_mod + nudge

		scored.append({
			"id":    actor_id,
			"name":  str(actor.get("name", "??")),
			"score": score,
			"index": i,
		})

	# Stable descending sort: primary = score DESC, tiebreak = original index ASC.
	scored.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["index"] < b["index"]
	)

	# Strip internal fields — return only { id, name }.
	var order: Array = []
	for entry in scored:
		order.append({ "id": entry["id"], "name": entry["name"] })
	return order


## COMBAT-004: Returns { "over": bool, "reason": String }.
## "reason" is "" when not over. MVP: checks "all_enemies_dead" only.
## COMBAT-005/006 will extend this with shrine and other objective checks.
static func check_end_condition(actors: Array, _objective: String) -> Dictionary:
	var living_enemies := actors.filter(func(a: Dictionary) -> bool:
		return a.get("faction", "") == "enemy" and not a.get("is_dead", false))
	if living_enemies.is_empty():
		return { "over": true, "reason": "all_enemies_dead" }
	return { "over": false, "reason": "" }


## Returns the key with the highest integer value in a Dictionary.
## tiebreak_order defines which key wins when values are equal (first in list wins).
## Returns "" if the dict is empty.
## (Mirrors GridService._dominant_key() — kept inline to avoid coupling.)
static func _dominant_key(scores: Dictionary, tiebreak_order: Array) -> String:
	if scores.is_empty():
		return ""
	var best_key: String = ""
	var best_val: int = -9999999
	for key in tiebreak_order:
		if not scores.has(key):
			continue
		var val: int = int(scores[key])
		if val > best_val:
			best_val = val
			best_key = key
	return best_key
