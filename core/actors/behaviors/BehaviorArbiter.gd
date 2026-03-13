# res://core/actors/behaviors/BehaviorArbiter.gd
# ACTOR-005: Data-driven weighted intent scoring engine.
# Replaces the single hard-coded BehaviorModule per echo role with a system
# where calling_origin, traits, vector_scores, fear (emotion), and directive
# alignment all compete to determine what action an echo takes each turn.
#
# Key design principles:
# - Roles weight, not determine: calling_origin gives a strong base tendency
#   (guardian → protect_ally: 65) but traits and vectors can override it.
#   Any echo can guard if their faith/protector vector is high enough.
# - Extensibility: _score() loops over config table rows generically.
#   Adding new actions, callings, vectors, or directives requires only
#   balance.json additions — no GDScript changes to _score().
# - Central tuning: all multipliers live in _cfg (data.actor from balance.json).
#   Pass {} to use hardcoded defaults (safe for tests and future enemy/NPC routing).
# - Actor-agnostic: reads calling_origin, traits, vector_scores, fear from any
#   actor dict — enemies and NPCs can receive the same arbiter with a different
#   config dict (ACTOR-006/ENEMY-001).
#
# Score formula (per candidate):
#   score = (base + trait_bonus + vector_bonus) * fear_factor + directive_bonus
#   - base: intent_weights_by_calling_origin[calling_origin][action_type]
#   - trait_bonus: sum(trait_value × trait_action_muls[action_type][trait_key])
#   - vector_bonus: sum(vector_score × vector_action_muls[action_type][vector_key])
#   - fear_factor: clamp(1.0 - fear/100 × fear_active_dampen, 0, 1) for active intents only
#   - directive_bonus: sum(dir_weight × directive_action_muls[action_type][key]) × directive_base_bonus
#
# Tiebreak: alphabetically smallest action_type string (deterministic).

class_name BehaviorArbiter
extends BehaviorModule

var _cfg: Dictionary

# Hardcoded defaults — mirrors data/balance.json data.actor block.
# Used when _cfg is empty (no balance.json block passed in).
const _DEFAULTS := {
	"intent_weights_by_calling_origin": {
		"guardian": { "melee_attack": 20, "protect_ally": 65, "actor.idle": 10 },
		"warrior":  { "melee_attack": 65, "protect_ally": 10, "actor.idle": 10 },
		"archer":   { "melee_attack": 45, "protect_ally": 10, "actor.idle": 10 },
		"uncalled": { "melee_attack": 40, "protect_ally": 15, "actor.idle": 20 },
	},
	"default_intent_weight": 5.0,
	"trait_action_muls": {
		"melee_attack": { "courage": 0.35, "wisdom": 0.05, "faith": 0.00 },
		"protect_ally": { "courage": 0.10, "wisdom": 0.05, "faith": 0.50 },
		"actor.idle":   { "courage": 0.00, "wisdom": 0.20, "faith": 0.05 },
	},
	"vector_action_muls": {
		"melee_attack": { "vanguard": 0.40, "protector": 0.00, "seeker": 0.15, "pillar": 0.00 },
		"protect_ally": { "vanguard": 0.00, "protector": 0.45, "seeker": 0.00, "pillar": 0.15 },
		"actor.idle":   { "vanguard": 0.00, "protector": 0.00, "seeker": 0.10, "pillar": 0.20 },
	},
	"directive_action_muls": {
		"melee_attack": { "objective_advance_priority": 1.0, "engage_only_blockers": 1.0 },
		"protect_ally": { "ally_protection_bias": 1.0, "threat_interception": 1.0 },
		"actor.idle":   { "survival_bias": 1.0, "prefer_disengage": 1.0, "resource_efficiency": 1.0 },
	},
	"directive_base_bonus":  20.0,
	"fear_active_dampen":    0.6,
	"fear_passive_actions":  ["actor.idle"],
	"threat_threshold":      0.5,
}


## actor_cfg: the data.actor block from balance.json, or {} to use hardcoded defaults.
## Tests and non-echo actors may pass {} safely — behaviour is identical to balance.json values.
func _init(actor_cfg: Dictionary = {}) -> void:
	_cfg = actor_cfg


func get_module_id() -> String:
	return "arbiter"


func select_intent(context: Dictionary) -> Dictionary:
	var actor: Dictionary     = context.get("actor", {})
	var all_actors: Array     = context.get("all_actors", [])
	var directive: Dictionary = context.get("directive", {})

	var candidates: Array[Dictionary] = _generate_candidates(actor, all_actors)

	# Score each candidate, then sort: highest score first; tiebreak alphabetically.
	for c: Dictionary in candidates:
		c["_score"] = _score(c["action_type"], actor, directive)

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["_score"] != b["_score"]:
			return a["_score"] > b["_score"]
		return str(a["action_type"]) < str(b["action_type"])
	)

	var winner: Dictionary = candidates[0].duplicate()
	winner.erase("_score")
	return winner


# -------------------------
# Private helpers
# -------------------------

## Generates all candidate intents for this turn:
## - actor.idle: always available (safe fallback, never absent)
## - melee_attack: if nearest enemy is at Manhattan distance == 1
## - protect_ally: if a threatened same-faction ally exists (below threat_threshold)
##
## Adding new action types: add candidate generation here + rows in balance.json tables.
## _score() needs no changes.
func _generate_candidates(actor: Dictionary, all_actors: Array) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []

	# actor.idle is always a candidate — the unconditional safe fallback.
	candidates.append({ "action_type": "actor.idle", "target_id": "", "priority": 0.0 })

	# melee_attack: only when an enemy is adjacent (dist == 1).
	var nearest_enemy: Dictionary = ActorService.get_nearest_enemy(actor, all_actors)
	if not nearest_enemy.is_empty():
		var my_pos: Dictionary  = actor.get("grid_pos", { "col": 0, "row": 0 })
		var t_pos: Dictionary   = nearest_enemy.get("grid_pos", { "col": 0, "row": 0 })
		var dist: int = abs(my_pos.get("col", 0) - t_pos.get("col", 0)) \
					  + abs(my_pos.get("row", 0) - t_pos.get("row", 0))
		if dist == 1:
			candidates.append({
				"action_type": "melee_attack",
				"target_id":   str(nearest_enemy.get("id", "")),
				"distance":    dist,
				"priority":    1.0,
			})

	# protect_ally: only when a threatened same-faction ally exists.
	var threshold: float = _get("threat_threshold")
	var threatened: Dictionary = ActorService.get_threatened_ally(actor, all_actors, threshold)
	if not threatened.is_empty():
		var ally_id: String = str(threatened.get("id", ""))
		candidates.append({
			"action_type":       "protect_ally",
			"target_id":         ally_id,
			"protected_actor_id": ally_id,
			"priority":          1.0,
		})

	return candidates


## Generic data-driven score for action_type given this actor's state and active directive.
## Does NOT contain action-type-specific conditionals — new actions require only
## balance.json row additions, not changes here.
func _score(action_type: String, actor: Dictionary, directive: Dictionary) -> float:
	var calling_origin: String = str(actor.get("calling_origin", "uncalled"))
	var traits: Dictionary     = actor.get("traits", {})
	var vectors: Dictionary    = actor.get("vector_scores", {})
	var fear: float            = float(actor.get("fear", 0))

	# 1. Base weight from calling_origin table.
	var origin_table: Dictionary = _get("intent_weights_by_calling_origin")
	var calling_row: Dictionary  = origin_table.get(calling_origin, origin_table.get("uncalled", {}))
	var default_weight: float    = _get("default_intent_weight")
	var base: float              = float(calling_row.get(action_type, default_weight))

	# 2. Trait bonus — generic loop: new traits picked up automatically from balance.json.
	var trait_tables: Dictionary = _get("trait_action_muls")
	var t_row: Dictionary        = trait_tables.get(action_type, {})
	var trait_bonus: float       = 0.0
	for trait_key: String in t_row:
		trait_bonus += float(traits.get(trait_key, 0)) * float(t_row[trait_key])

	# 3. Vector bonus — generic loop: new vectors picked up automatically from balance.json.
	var vector_tables: Dictionary = _get("vector_action_muls")
	var v_row: Dictionary         = vector_tables.get(action_type, {})
	var vector_bonus: float       = 0.0
	for vector_key: String in v_row:
		vector_bonus += float(vectors.get(vector_key, 0)) * float(v_row[vector_key])

	# 4. Fear factor: dampens active intents; passive intents (actor.idle) are unaffected.
	var passive_actions: Array = _get("fear_passive_actions")
	var fear_factor: float     = 1.0
	if action_type not in passive_actions:
		var dampen: float  = float(_get("fear_active_dampen"))
		fear_factor        = clamp(1.0 - (fear / 100.0) * dampen, 0.0, 1.0)

	# 5. Directive bonus — generic loop over intent_weights (semantic keys).
	var directive_bonus: float = _directive_bonus(action_type, directive)

	return (base + trait_bonus + vector_bonus) * fear_factor + directive_bonus


## Maps directive semantic intent_weights keys → action bonus.
## Uses directive_action_muls translation table (balance.json) so new directive keys
## and new action types can be added without touching this function.
func _directive_bonus(action_type: String, directive: Dictionary) -> float:
	if directive.is_empty():
		return 0.0

	var dir_weights: Dictionary  = directive.get("intent_weights", {})
	if dir_weights.is_empty():
		return 0.0

	var dir_muls_table: Dictionary = _get("directive_action_muls")
	var d_row: Dictionary          = dir_muls_table.get(action_type, {})
	var base_bonus: float          = float(_get("directive_base_bonus"))
	var bonus: float               = 0.0

	# Generic loop: for each semantic key that boosts this action_type,
	# add the directive's weight for that key × directive_base_bonus.
	for semantic_key: String in d_row:
		var dir_weight: float = float(dir_weights.get(semantic_key, 0.0))
		bonus += dir_weight * float(d_row[semantic_key]) * base_bonus

	return bonus


## Config accessor — falls back to _DEFAULTS when _cfg is empty or key is missing.
func _get(key: String) -> Variant:
	if _cfg.has(key):
		return _cfg[key]
	return _DEFAULTS[key]
