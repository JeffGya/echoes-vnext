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
#   score = (base + trait_bonus + vector_bonus + archetype_bonus + morale_bonus) * fear_factor + directive_bonus
#   - base: intent_weights_by_calling_origin[calling_origin][action_type]
#   - trait_bonus: sum(trait_value × trait_action_muls[action_type][trait_key])
#   - vector_bonus: sum(vector_score × vector_action_muls[action_type][vector_key])
#   - archetype_bonus: flat constant from archetype_action_muls[action_type][archetype_birth]
#   - morale_bonus: morale_action_muls[action_type][morale_tier] (ACTOR-007; steady tier = 0)
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
		"guardian": { "melee_attack": 20, "protect_ally": 65, "actor.guard": 45, "actor.idle": 10, "actor.move": 25 },
		"warrior":  { "melee_attack": 65, "protect_ally": 10, "actor.guard": 15, "actor.idle": 10, "actor.move": 55 },
		"archer":   { "melee_attack": 45, "protect_ally": 10, "actor.guard": 20, "actor.idle": 10, "actor.move": 40 },
		"uncalled": { "melee_attack": 40, "protect_ally": 15, "actor.guard": 25, "actor.idle": 20, "actor.move": 35 },
		# Enemy baseline: aggressive. protect_ally=0 (enemies don't protect each other in MVP).
		# guard/idle stay low so enemies almost never passively hold unless situationally forced.
		"enemy":    { "melee_attack": 70, "protect_ally":  0, "actor.guard": 10, "actor.idle":  5, "actor.move": 60 },
	},
	"default_intent_weight": 5.0,
	"trait_action_muls": {
		"melee_attack": { "courage": 0.35, "wisdom": 0.05, "faith": 0.00 },
		"protect_ally": { "courage": 0.10, "wisdom": 0.05, "faith": 0.50 },
		"actor.guard":  { "courage": 0.20, "wisdom": 0.10, "faith": 0.30 },
		"actor.idle":   { "courage": 0.00, "wisdom": 0.20, "faith": 0.05 },
		"actor.move":   { "courage": 0.35, "wisdom": 0.05, "faith": 0.00 },
	},
	"vector_action_muls": {
		"melee_attack": { "vanguard": 0.40, "protector": 0.00, "seeker": 0.15, "pillar": 0.00 },
		"protect_ally": { "vanguard": 0.00, "protector": 0.45, "seeker": 0.00, "pillar": 0.15 },
		"actor.guard":  { "vanguard": 0.00, "protector": 0.15, "seeker": 0.00, "pillar": 0.10 },
		"actor.idle":   { "vanguard": 0.00, "protector": 0.00, "seeker": 0.10, "pillar": 0.20 },
		"actor.move":   { "vanguard": 0.40, "protector": 0.05, "seeker": 0.10, "pillar": 0.00 },
	},
	# Flat archetype bonus — direct lookup by archetype_birth string (not a score, just a constant).
	# Mirrors combat_bias() from PersonalityArchetype: aggressive→melee/move, steadfast→guard,
	# supportive→protect_ally, cautious→guard+idle, balanced→no strong bias.
	"archetype_action_muls": {
		"melee_attack": { "valiant": 25, "proud": 20, "ambitious": 12, "canny": 8, "loyal": 4,
		                  "stoic": 0, "devout": 0, "empathic": -8, "reflective": -12 },
		"actor.move":   { "valiant": 20, "canny": 12, "ambitious": 8, "proud": 8, "loyal": -4,
		                  "stoic": 0, "devout": 0, "empathic": 0, "reflective": -8 },
		"actor.guard":  { "stoic": 25, "loyal": 16, "reflective": 16, "devout": 12, "empathic": 8,
		                  "canny": 4, "ambitious": 0, "valiant": -8, "proud": -8 },
		"protect_ally": { "empathic": 32, "loyal": 20, "devout": 12, "stoic": 8, "reflective": 4,
		                  "canny": 0, "ambitious": 0, "valiant": 0, "proud": -4 },
		"actor.idle":   { "reflective": 12, "stoic": 4, "devout": 4, "canny": 4, "loyal": 0,
		                  "empathic": 0, "ambitious": -4, "valiant": -8, "proud": -8 },
	},
	"directive_action_muls": {
		"melee_attack": { "objective_advance_priority": 1.0, "engage_only_blockers": 1.0 },
		"protect_ally": { "ally_protection_bias": 1.0, "threat_interception": 1.0 },
		"actor.guard":  { "ally_protection_bias": 1.0, "survival_bias": 1.0 },
		"actor.idle":   { "survival_bias": 1.0, "prefer_disengage": 1.0, "resource_efficiency": 1.0 },
		"actor.move":   { "objective_advance_priority": 1.0, "engage_only_blockers": 1.0 },
	},
	"morale_action_muls": {
		"melee_attack": { "broken": -20, "shaken": -8, "steady": 0, "inspired": 12 },
		"protect_ally": { "broken": -8,  "shaken": -3, "steady": 0, "inspired": 6  },
		"actor.guard":  { "broken": 20,  "shaken": 10, "steady": 0, "inspired": -5 },
		"actor.idle":   { "broken": 15,  "shaken": 6,  "steady": 0, "inspired": -5 },
		"actor.move":   { "broken": -20, "shaken": -8, "steady": 0, "inspired": 10 },
	},
	"directive_base_bonus":  20.0,
	"fear_active_dampen":    0.6,
	"fear_passive_actions":  ["actor.idle", "actor.guard"],
	"threat_threshold":      1.0,   # 1.0 = any HP damage qualifies; lower to tighten the gate
	"guard_range":           2,     # enemy must be within this many tiles for guard to be a candidate

	# -------------------------
	# Situational modifier tables
	# Flat bonuses added to the final score per active board condition.
	# Positive = boost, negative = penalty.
	# Each active condition key is looked up here; its per-action value is summed into situational_bonus.
	# Stub keys (_stub_*) are never added to active_conditions, so their zero values have no effect.
	# To activate a stub: remove _stub_ prefix, set values, implement the condition in _build_board_summary().
	# -------------------------
	"situational_muls": {
		# --- Active conditions (computed every turn) ---
		"own_hp_low": {
			# hp_ratio < threshold. Injured echo pulls back. Applies to both echo and enemy.
			"threshold":    0.35,
			"melee_attack": -8, "protect_ally":  0, "actor.guard": 12, "actor.idle":  8, "actor.move": -5,
		},
		"own_hp_critical": {
			# hp_ratio < threshold. Near death — stacks with own_hp_low for stronger effect.
			"threshold":    0.20,
			"melee_attack": -12, "protect_ally": -5, "actor.guard": 18, "actor.idle": 12, "actor.move": -10,
		},
		"outnumbered": {
			# living enemies > living allies (requires living_allies > 0 so 1v1 / solo don't trigger).
			"melee_attack": -10, "protect_ally":  8, "actor.guard": 10, "actor.idle":  6, "actor.move": -6,
		},
		"overwhelming_advantage": {
			# living allies >= living enemies * 2. Push the advantage.
			"melee_attack": 10, "protect_ally": -3, "actor.guard": -5, "actor.idle": -6, "actor.move":  8,
		},
		"last_echo_standing": {
			# All allies dead (dead_allies > 0). Final survivor — survival mode.
			"melee_attack": -15, "protect_ally":  0, "actor.guard": 20, "actor.idle": 15, "actor.move": -10,
		},
		"enemy_far": {
			# Nearest enemy distance > threshold tiles. Guard is pointless — advance.
			"threshold":    5,
			"melee_attack":  0, "protect_ally":  0, "actor.guard": -12, "actor.idle": -5, "actor.move":  8,
		},
		# Enemy-type only conditions (gated by actor_type == "enemy" in _build_board_summary).
		"enemy_engaged": {
			# Adjacent to an echo — maintain pressure, don't retreat.
			"melee_attack": 15, "protect_ally":  0, "actor.guard": -8, "actor.idle": -10, "actor.move":  0,
		},
		"enemy_advancing": {
			# Not yet adjacent — close the gap aggressively.
			"melee_attack":  0, "protect_ally":  0, "actor.guard": -10, "actor.idle":  -8, "actor.move": 15,
		},

		# --- Stub conditions (zero values — no effect until implemented) ---
		# To activate: remove _stub_ prefix, tune values, add condition check to _build_board_summary().
		"near_friendly_structure": {
			# A living friendly structure (shrine/totem) exists on the board. Soft defensive bonus — only for echo actors.
			# No move penalty: echoes must still advance freely to intercept enemies heading for the shrine.
			"melee_attack": -5, "protect_ally": 8, "actor.guard": 3, "actor.idle": 0, "actor.move": 0, "actor.purify_shrine": 10,
		},
		"near_hostile_structure": {
			# Enemy actor: shrine is alive — push toward it aggressively.
			"melee_attack": 10, "protect_ally": 0, "actor.guard": -5, "actor.idle": -5, "actor.move": 10,
		},
		"_stub_ally_adjacent": {
			# A living ally is in an adjacent cell. Formation/support bonus.
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 0, "actor.idle": 0, "actor.move": 0,
		},
		"_stub_flanked": {
			# Enemies on 2+ cardinal sides of actor. Defensive pressure.
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 0, "actor.idle": 0, "actor.move": 0,
		},
		"_stub_surrounded": {
			# Enemies on 3+ sides. Severe defensive/survival override.
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 0, "actor.idle": 0, "actor.move": 0,
		},
		"_stub_in_formation": {
			# 2+ allies adjacent (shield wall). Boost guard for formation play.
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 0, "actor.idle": 0, "actor.move": 0,
		},
		"_stub_actor_has_ranged_skill": {
			# Actor has a ranged skill equipped. Move to optimal range instead of melee.
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 0, "actor.idle": 0, "actor.move": 0,
		},
		"_stub_weapon_extended_reach": {
			# Spear/halberd type weapon. Attack at dist=2 (also changes candidate generation).
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 0, "actor.idle": 0, "actor.move": 0,
		},
		"_stub_enemy_type_ranged": {
			# Nearest enemy is an archer/ranged type. Close gap or shield up.
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 0, "actor.idle": 0, "actor.move": 0,
		},
		"_stub_objective_in_range": {
			# Combat objective target is within N tiles. Intensify toward goal.
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 0, "actor.idle": 0, "actor.move": 0,
		},
		"_stub_enemy_bodyguard": {
			# Enemy-type actor protecting a priority target. Intercept aggression.
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 0, "actor.idle": 0, "actor.move": 0,
		},
	},
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

	# Build board summary once — passed to _score() for every candidate to avoid re-computation.
	var board_summary: Dictionary = _build_board_summary(actor, all_actors, context.get("board_cfg", {}))

	var candidates: Array[Dictionary] = _generate_candidates(actor, all_actors, context)

	# Score each candidate, then sort: highest score first; tiebreak alphabetically.
	for c: Dictionary in candidates:
		c["_score"] = _score(c["action_type"], actor, directive, board_summary)

	# COMBAT-006: actor.purify_shrine override — injected AFTER scoring so 9999 is never overwritten.
	# Same pattern as Absolute Fear Rule: deterministic always-win when all conditions are met.
	if context.get("is_purifier", false) \
			and context.get("shrine_alive", false) \
			and float(context.get("shrine_hp_ratio", 1.0)) < 0.5 \
			and int(actor.get("purify_cooldown", 0)) == 0:
		candidates.append({
			"action_type": "actor.purify_shrine",
			"target_id":   "",
			"priority":    1.0,
			"_score":      9999.0,
		})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["_score"] != b["_score"]:
			return a["_score"] > b["_score"]
		return str(a["action_type"]) < str(b["action_type"])
	)

	var winner: Dictionary = candidates[0].duplicate()
	winner.erase("_score")

	# ACTOR-007: attach morale metadata to winner for ActorStateMachine to log and snapshot.
	var winner_tier: String  = EmotionService.get_morale_tier(int(actor.get("morale", 50)))
	var m_tables: Dictionary = _cfg_get("morale_action_muls")
	var w_row: Dictionary    = m_tables.get(str(winner.get("action_type", "")), {})
	winner["morale_tier"]     = winner_tier
	winner["morale_modifier"] = int(w_row.get(winner_tier, 0))

	# Archetype metadata — for ActorStateMachine logging.
	var winner_arch: String       = str(actor.get("archetype_birth", ""))
	var winner_a_row: Dictionary  = _cfg_get("archetype_action_muls").get(str(winner.get("action_type", "")), {})
	winner["archetype_birth"]    = winner_arch
	winner["archetype_modifier"] = int(winner_a_row.get(winner_arch, 0))

	return winner


# -------------------------
# Private helpers
# -------------------------

## Generates all candidate intents for this turn:
## - actor.idle: always available (safe fallback, never absent)
## - actor.guard: only when nearest enemy is within guard_range tiles (balance.json data.actor.guard_range)
## - melee_attack: only when nearest enemy is at Manhattan distance == 1
## - actor.move: when nearest enemy exists but is not yet adjacent (dist > 1)
## - protect_ally: only when a same-faction ally has taken any damage (current_hp < max_hp)
##
## Guard and protect_ally are situation-gated — they only enter the pool when the board
## state makes them meaningful. Scoring still determines the winner among candidates.
##
## Adding new action types: add candidate generation here + rows in balance.json tables.
## _score() needs no changes.
func _generate_candidates(actor: Dictionary, all_actors: Array, context: Dictionary = {}) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []

	# actor.idle is always a candidate — the unconditional safe fallback.
	candidates.append({ "action_type": "actor.idle", "target_id": "", "priority": 0.0 })

	# COMBAT-006: enemy actors in purify_shrine encounter prioritise the shrine target.
	# prefer_objective_target is set by FlowRuntime for enemy actors when objective is purify_shrine.
	var shrine_override: Dictionary = {}
	if context.get("prefer_objective_target", false):
		for a_v in all_actors:
			if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
				shrine_override = a_v
				break

	# Compute nearest enemy and distance upfront — used by melee, move, and guard.
	var nearest_enemy: Dictionary = shrine_override if not shrine_override.is_empty() \
			else ActorService.get_nearest_enemy(actor, all_actors)
	var my_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 })
	var enemy_dist: int = 999999
	var t_pos: Dictionary = {}
	if not nearest_enemy.is_empty():
		t_pos = nearest_enemy.get("grid_pos", { "col": 0, "row": 0 })
		enemy_dist = GridService.chebyshev_distance(my_pos, t_pos)

	# melee_attack: adjacent enemy (Chebyshev distance == 1, all 8 neighbours).
	# actor.move: enemy exists but not adjacent.
	if not nearest_enemy.is_empty():
		if GridService.is_adjacent(my_pos, t_pos):
			candidates.append({
				"action_type": "melee_attack",
				"target_id":   str(nearest_enemy.get("id", "")),
				"distance":    enemy_dist,
				"priority":    1.0,
			})
		else:
			candidates.append({
				"action_type":    "actor.move",
				"target_id":      str(nearest_enemy.get("id", "")),
				"target_pos":     t_pos,
				"target_distance": enemy_dist,
				"priority":       1.0,
			})

	# actor.guard — only meaningful when an enemy is within guard_range tiles.
	# No nearby threat → guarding is pointless; omit so scorer never picks it.
	var guard_range: int = int(_cfg_get("guard_range"))
	if not nearest_enemy.is_empty() and enemy_dist <= guard_range:
		candidates.append({ "action_type": "actor.guard", "target_id": "", "priority": 0.0 })

	# protect_ally — only when a same-faction ally has taken any damage (current_hp < max_hp).
	# threshold=1.0 in balance.json ensures any HP loss qualifies; tune down to tighten the gate.
	var threshold: float = _cfg_get("threat_threshold")
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


## Computes a read-only snapshot of the current board state for this actor.
## Called once in select_intent() before the scoring loop so the computation runs
## once per turn, not once per candidate.
##
## HP sentinel: if current_hp key is absent OR stats.max_hp == 0, hp_ratio = 1.0.
## This ensures test actors (which don't carry full schema) never trigger HP conditions.
##
## last_echo_standing sentinel: requires dead_allies > 0 so a designed 1v1 scenario
## (all_actors contains only enemies) never fires the condition.
func _build_board_summary(actor: Dictionary, all_actors: Array, _board_cfg: Dictionary) -> Dictionary:
	var my_id:      String = str(actor.get("id", ""))
	var my_faction: String = str(actor.get("faction", ""))
	var actor_type: String = str(actor.get("actor_type", "echo"))

	# Count living/dead allies and enemies in a single pass.
	var living_allies: int  = 0
	var living_enemies: int = 0
	var dead_allies: int    = 0
	for a_v in all_actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("id", "")) == my_id:
			continue  # skip self
		var is_dead: bool = a.get("is_dead", false)
		if str(a.get("faction", "")) == my_faction:
			if is_dead:
				dead_allies += 1
			else:
				living_allies += 1
		else:
			if not is_dead:
				living_enemies += 1

	# HP ratio — sentinel 1.0 when data is absent.
	var max_hp: int    = int(actor.get("stats", {}).get("max_hp", 0))
	var hp_ratio: float = 1.0
	if max_hp > 0 and actor.has("current_hp"):
		hp_ratio = clampf(float(actor["current_hp"]) / float(max_hp), 0.0, 1.0)

	# Distance to nearest enemy.
	var nearest_enemy: Dictionary = ActorService.get_nearest_enemy(actor, all_actors)
	var my_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 })
	var enemy_dist: int = 999999
	if not nearest_enemy.is_empty():
		enemy_dist = GridService.chebyshev_distance(my_pos, nearest_enemy.get("grid_pos", { "col": 0, "row": 0 }))

	# Evaluate active conditions.
	var sit_cfg: Dictionary = _cfg_get("situational_muls")
	var active: Array[String] = []

	# own_hp_low / own_hp_critical — HP-based; only fire when real HP data exists.
	var low_threshold:  float = float(sit_cfg.get("own_hp_low",      {}).get("threshold", 0.35))
	var crit_threshold: float = float(sit_cfg.get("own_hp_critical",  {}).get("threshold", 0.20))
	if max_hp > 0 and actor.has("current_hp"):
		if hp_ratio < crit_threshold:
			active.append("own_hp_critical")
		if hp_ratio < low_threshold:
			active.append("own_hp_low")

	# outnumbered: enemies outnumber allies; requires at least 1 living ally so 1v1 doesn't trigger.
	if living_enemies > living_allies and living_allies > 0:
		active.append("outnumbered")

	# overwhelming_advantage: allies are at least 2× enemies.
	if living_enemies > 0 and living_allies >= living_enemies * 2:
		active.append("overwhelming_advantage")

	# last_echo_standing: all allies fallen; dead_allies > 0 distinguishes real rout from scripted solo.
	if living_allies == 0 and dead_allies > 0:
		active.append("last_echo_standing")

	# enemy_far: nearest enemy beyond far threshold.
	var far_threshold: int = int(sit_cfg.get("enemy_far", {}).get("threshold", 5))
	if enemy_dist > far_threshold and enemy_dist < 999999:
		active.append("enemy_far")

	# Enemy-type-only conditions — gated so echo actors never receive them.
	if actor_type == "enemy" and enemy_dist < 999999:
		var n_pos: Dictionary = nearest_enemy.get("grid_pos", { "col": 0, "row": 0 })
		if GridService.is_adjacent(my_pos, n_pos):
			active.append("enemy_engaged")
		else:
			active.append("enemy_advancing")

	# COMBAT-006: near_friendly_structure / near_hostile_structure based on actor faction.
	# Echoes get a soft defensive bonus near the shrine; enemies get an aggression boost toward it.
	for a_v in all_actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if a.get("is_structure", false) and not a.get("is_dead", false):
			if str(a.get("faction", "")) == "structure":
				if actor_type != "enemy":
					active.append("near_friendly_structure")
				else:
					active.append("near_hostile_structure")
			break

	return {
		"hp_ratio":          hp_ratio,
		"enemy_dist":        enemy_dist,
		"living_allies":     living_allies,
		"living_enemies":    living_enemies,
		"dead_allies":       dead_allies,
		"actor_type":        actor_type,
		"active_conditions": active,
	}


## Flat bonus from all currently active situational conditions.
## Loops over active_conditions and sums per-action bonuses from situational_muls.
## Keys starting with "_stub_" are never placed in active_conditions, so stub rows
## in balance.json have zero effect regardless of their values.
## Returns 0.0 when board_summary is empty (backward-compatible; existing tests unaffected).
func _situational_bonus(action_type: String, board_summary: Dictionary) -> float:
	var conditions: Array = board_summary.get("active_conditions", [])
	if conditions.is_empty():
		return 0.0
	var sit_cfg: Dictionary = _cfg_get("situational_muls")
	var bonus: float = 0.0
	for cond_key: String in conditions:
		var cond_row: Dictionary = sit_cfg.get(cond_key, {})
		bonus += float(cond_row.get(action_type, 0.0))
	return bonus


## Generic data-driven score for action_type given this actor's state and active directive.
## Does NOT contain action-type-specific conditionals — new actions require only
## balance.json row additions, not changes here.
func _score(action_type: String, actor: Dictionary, directive: Dictionary, board_summary: Dictionary = {}) -> float:
	var calling_origin: String = str(actor.get("calling_origin", "uncalled"))
	var traits: Dictionary     = actor.get("traits", {})
	var vectors: Dictionary    = actor.get("vector_scores", {})
	var fear: float            = float(actor.get("fear", 0))

	# 1. Base weight from calling_origin table.
	var origin_table: Dictionary = _cfg_get("intent_weights_by_calling_origin")
	var calling_row: Dictionary  = origin_table.get(calling_origin, origin_table.get("uncalled", {}))
	var default_weight: float    = _cfg_get("default_intent_weight")
	var base: float              = float(calling_row.get(action_type, default_weight))

	# 2. Trait bonus — generic loop: new traits picked up automatically from balance.json.
	var trait_tables: Dictionary = _cfg_get("trait_action_muls")
	var t_row: Dictionary        = trait_tables.get(action_type, {})
	var trait_bonus: float       = 0.0
	for trait_key: String in t_row:
		trait_bonus += float(traits.get(trait_key, 0)) * float(t_row[trait_key])

	# 3. Vector bonus — generic loop: new vectors picked up automatically from balance.json.
	var vector_tables: Dictionary = _cfg_get("vector_action_muls")
	var v_row: Dictionary         = vector_tables.get(action_type, {})
	var vector_bonus: float       = 0.0
	for vector_key: String in v_row:
		vector_bonus += float(vectors.get(vector_key, 0)) * float(v_row[vector_key])

	# 3b. Archetype bonus — flat constant lookup by archetype_birth string (not a continuous score).
	#     Encodes personality combat tendency (combat_bias): aggressive→melee/move, steadfast→guard, etc.
	var arch_tables: Dictionary = _cfg_get("archetype_action_muls")
	var a_row: Dictionary       = arch_tables.get(action_type, {})
	var archetype: String       = str(actor.get("archetype_birth", ""))
	var archetype_bonus: float  = float(a_row.get(archetype, 0.0))

	# 4. Fear factor: dampens active intents; passive intents (actor.idle) are unaffected.
	var passive_actions: Array = _cfg_get("fear_passive_actions")
	var fear_factor: float     = 1.0
	if action_type not in passive_actions:
		var dampen: float  = float(_cfg_get("fear_active_dampen"))
		fear_factor        = clamp(1.0 - (fear / 100.0) * dampen, 0.0, 1.0)

	# 5. Morale bonus — flat integer modifier based on tier; steady tier = 0 (neutral baseline).
	#    Lives inside the pre-fear bracket so fear can dampen morale-influenced scores too.
	var morale_tables: Dictionary = _cfg_get("morale_action_muls")
	var morale_tier: String       = EmotionService.get_morale_tier(int(actor.get("morale", 50)))
	var ml_row: Dictionary        = morale_tables.get(action_type, {})
	var morale_bonus: float       = float(ml_row.get(morale_tier, 0.0))

	# 6. Directive bonus — generic loop over intent_weights (semantic keys).
	var directive_bonus: float = _directive_bonus(action_type, directive)

	return (base + trait_bonus + vector_bonus + archetype_bonus + morale_bonus) * fear_factor + directive_bonus + _situational_bonus(action_type, board_summary)


## Maps directive semantic intent_weights keys → action bonus.
## Uses directive_action_muls translation table (balance.json) so new directive keys
## and new action types can be added without touching this function.
func _directive_bonus(action_type: String, directive: Dictionary) -> float:
	if directive.is_empty():
		return 0.0

	var dir_weights: Dictionary  = directive.get("intent_weights", {})
	if dir_weights.is_empty():
		return 0.0

	var dir_muls_table: Dictionary = _cfg_get("directive_action_muls")
	var d_row: Dictionary          = dir_muls_table.get(action_type, {})
	var base_bonus: float          = float(_cfg_get("directive_base_bonus"))
	var bonus: float               = 0.0

	# Generic loop: for each semantic key that boosts this action_type,
	# add the directive's weight for that key × directive_base_bonus.
	for semantic_key: String in d_row:
		var dir_weight: float = float(dir_weights.get(semantic_key, 0.0))
		bonus += dir_weight * float(d_row[semantic_key]) * base_bonus

	return bonus


## Config accessor — falls back to _DEFAULTS when _cfg is empty or key is missing.
func _cfg_get(key: String) -> Variant:
	if _cfg.has(key):
		return _cfg[key]
	return _DEFAULTS[key]
