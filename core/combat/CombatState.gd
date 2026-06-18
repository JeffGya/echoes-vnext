# res://core/combat/CombatState.gd
# COMBAT-001: Centralized combat state container.
# COMBAT-002: Initiative order added — composite readiness scoring mirroring GridService._placement_score().
# V2-COMBAT-001: "initiative score" renamed to "readiness score" — reflects tactical attributes + emotional readiness.
#
# Readiness formula (per actor):
#   score = (speed * 3 + agi * 2)
#           + archetype_mod + calling_mod + trait_mod + vector_mod
#           + morale_mod    (by_morale_tier — inspired +4, steady 0, shaken -3, broken -6)
#           + seed_nudge
#
# Calculated ONCE at combat start. Mid-combat morale recovery does not re-sort.
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
		initiative_seed: int = 0, init_cfg: Dictionary = {},
		objective_params: Dictionary = {}) -> Dictionary:
	return {
		"actors":                  actors.duplicate(true),
		"objective":               objective,
		"objective_params":        objective_params,
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


## Calculates readiness order for all actors.
##
## Formula (per actor):
##   score = (speed * 3 + agi * 2)
##           + archetype_mod + calling_mod + trait_mod + vector_mod
##           + morale_mod + seed_nudge
##
## morale_mod = by_morale_tier[_morale_tier_from_score(actor.morale)] (default 0)
## seed_nudge = CampaignSeed.derive_from(seed, actor_id) % 10
## Calculated once at combat start — mid-combat morale recovery does not re-sort.
##
## Sort: descending by score.
## Tiebreak: original list position (stable — echoes before enemies = party list order).
##
## Returns: [{ "id": String, "name": String }, ...]
static func _calc_initiative(actors: Array, seed: int, cfg: Dictionary) -> Array:
	var arch_table: Dictionary   = cfg.get("by_archetype",       {})
	var call_table: Dictionary   = cfg.get("by_calling_origin",  {})
	var trait_table: Dictionary  = cfg.get("by_dominant_trait",  {})
	var vec_table: Dictionary    = cfg.get("by_dominant_vector", {})
	var morale_table: Dictionary = cfg.get("by_morale_tier",     {})

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

		# Calling modifier — V2-PROG-002: prefer confirmed calling over birth origin.
		var _act_confirmed: String = str(actor.get("calling", ""))
		var _call_key: String = _act_confirmed \
			if not _act_confirmed.is_empty() and _act_confirmed != "uncalled" \
			else str(actor.get("calling_origin", ""))
		var call_mod: int = int(call_table.get(_call_key, 0))

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

		# Morale-tier readiness modifier — emotional state at combat start.
		var morale_val: int = int(actor.get("morale", 50))
		var morale_mod: int = int(morale_table.get(_morale_tier_from_score(morale_val), 0))

		# Deterministic seed nudge (0-9) for remaining ties.
		var actor_id: String = str(actor.get("id", ""))
		var nudge: int = int(CampaignSeed.derive_from(seed, actor_id) % 10)

		var score: int = base + arch_mod + call_mod + trait_mod + vec_mod + morale_mod + nudge

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


## COMBAT-005/006: Returns { "over": bool, "victory": bool, "reason": String }.
## "reason" is "" when not over. Check priority (locked):
##   1. all_enemies_defeated → victory  (runs first — echoes that kill the last enemy win
##      even if the shrine falls the same round)
##   2. shrine_destroyed (purify_shrine objective only) → defeat
##   3. PROTECT entity lost → defeat  (structure actor dead)
##   4. all_echoes_dead → defeat
##   5. RECOVER secured → victory  (hold_counter >= hold_rounds)
##   6. PROTECT survived → victory  (round_counter >= duration_turns)
##   7. ENDURE survived → victory   (round_counter >= duration_turns)
##
## combat_state carries round_counter, objective_params, and hold_counter.
## Callers that omit combat_state (COMBAT / PURIFY_SHRINE) receive byte-identical results
## to the previous 2-arg signature — no new branches fire for those modes.
static func check_end_condition(actors: Array, objective: String,
		combat_state: Dictionary = {}) -> Dictionary:
	# Read combat_state fields with safe defaults.
	var round_counter: int     = int(combat_state.get("round_counter", 0))
	var obj_params: Dictionary = combat_state.get("objective_params", {})
	var hold_counter: int      = int(combat_state.get("hold_counter", 0))

	# 1. Victory: all enemies dead (universal, unchanged).
	var living_enemies := actors.filter(func(a: Dictionary) -> bool:
		return a.get("faction", "") == "enemy" and not a.get("is_dead", false))
	if living_enemies.is_empty():
		return { "over": true, "victory": true, "reason": "all_enemies_defeated" }

	# 2. Shrine destroyed (purify_shrine objective only, unchanged).
	if objective == EncounterResolutionModes.PURIFY_SHRINE:
		var shrine: Dictionary = _find_shrine(actors)
		if not shrine.is_empty() and shrine.get("is_dead", false):
			return { "over": true, "victory": false, "reason": "shrine_destroyed" }

	# 3. PROTECT: guarded entity destroyed → immediate defeat.
	#    Uses same structure-finder as PURIFY_SHRINE; RECOVER's relic is also is_structure
	#    but this branch is gated on the PROTECT objective string so it cannot misfire.
	if objective == EncounterResolutionModes.PROTECT:
		var entity: Dictionary = _find_shrine(actors)
		if not entity.is_empty() and entity.get("is_dead", false):
			return { "over": true, "victory": false, "reason": "entity_lost" }

	# 4. Defeat: all echoes dead (unchanged).
	var living_echoes := actors.filter(func(a: Dictionary) -> bool:
		return a.get("faction", "") == "echo" and not a.get("is_dead", false))
	if living_echoes.is_empty():
		return { "over": true, "victory": false, "reason": "all_echoes_dead" }

	# 5. RECOVER: relic held for required number of rounds → victory.
	if objective == EncounterResolutionModes.RECOVER:
		var hold_rounds: int = int(obj_params.get("hold_rounds", 2))
		if hold_counter >= hold_rounds:
			return { "over": true, "victory": true, "reason": "relic_secured" }

	# 6. PROTECT: survived the required wave duration → victory.
	if objective == EncounterResolutionModes.PROTECT:
		var duration_turns: int = int(obj_params.get("duration_turns", 4))
		if round_counter >= duration_turns:
			return { "over": true, "victory": true, "reason": "protected" }

	# 7. ENDURE: survived the required wave duration → victory.
	if objective == EncounterResolutionModes.ENDURE:
		var duration_turns: int = int(obj_params.get("duration_turns", 5))
		if round_counter >= duration_turns:
			return { "over": true, "victory": true, "reason": "endured" }

	return { "over": false, "victory": false, "reason": "" }


## Returns the first structure actor (is_structure == true) from the list, or {} if none found.
static func _find_shrine(actors: Array) -> Dictionary:
	for actor_v in actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if actor.get("is_structure", false):
			return actor
	return {}


## Maps a raw morale value to a tier string.
## Mirrors EmotionService.get_morale_tier() thresholds — kept inline to avoid
## coupling CombatState (pure static RefCounted) to a service dependency.
static func _morale_tier_from_score(morale: int) -> String:
	if morale >= 75: return "inspired"
	if morale >= 50: return "steady"
	if morale >= 25: return "shaken"
	return "broken"


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
