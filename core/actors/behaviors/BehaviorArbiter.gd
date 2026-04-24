# res://core/actors/behaviors/BehaviorArbiter.gd
# ACTOR-005: Data-driven weighted intent scoring engine.
# Replaces the single hard-coded BehaviorModule per echo role with a system
# where calling_origin, traits, vector_scores, fear (emotion), and directive
# alignment all compete to determine what action an echo takes each turn.
#
# Key design principles:
# - Roles weight, not determine: calling_origin gives a strong base tendency
#   (warder → protect_ally: 65) but traits and vectors can override it.
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
		"okofor":      { "melee_attack": 20, "protect_ally": 65, "actor.guard": 45, "actor.idle": 10, "actor.move": 25 },
		"aduro":       { "melee_attack": 65, "protect_ally": 10, "actor.guard": 15, "actor.idle": 10, "actor.move": 55 },
		"kra_soro":    { "melee_attack": 40, "protect_ally": 10, "actor.guard": 15, "actor.idle":  5, "actor.move": 55 },
		"onyamesu":    { "melee_attack": 35, "protect_ally": 30, "actor.guard": 55, "actor.idle": 25, "actor.move": 20 },
		"okomfo":      { "melee_attack": 25, "protect_ally": 20, "actor.guard": 30, "actor.idle": 40, "actor.move": 35 },
		"sum_okwanfo": { "melee_attack": 40, "protect_ally":  5, "actor.guard": 10, "actor.idle": 25, "actor.move": 55 },
		"uncalled":    { "melee_attack": 50, "protect_ally": 15, "actor.guard": 25, "actor.idle": 20, "actor.move": 44 },
		# Enemy baseline: aggressive. protect_ally=0 (enemies don't protect each other in MVP).
		# guard/idle stay low so enemies almost never passively hold unless situationally forced.
		"enemy":       { "melee_attack": 70, "protect_ally":  0, "actor.guard": 10, "actor.idle":  5, "actor.move": 60 },
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
		"melee_attack": { "vanguard": 0.40, "protector": 0.00, "seeker": 0.15, "pillar": 0.00, "strategist": 0.05, "skeptic": 0.00, "devoted": 0.00, "opportunist": 0.25, "mediator": 0.00, "nurturer": 0.00 },
		"protect_ally": { "vanguard": 0.00, "protector": 0.45, "seeker": 0.00, "pillar": 0.15, "strategist": 0.05, "skeptic": 0.00, "devoted": 0.30, "opportunist": 0.00, "mediator": 0.25, "nurturer": 0.20 },
		"actor.guard":  { "vanguard": 0.00, "protector": 0.15, "seeker": 0.00, "pillar": 0.10, "strategist": 0.10, "skeptic": 0.15, "devoted": 0.10, "opportunist": 0.00, "mediator": 0.05, "nurturer": 0.05 },
		"actor.idle":   { "vanguard": 0.00, "protector": 0.00, "seeker": 0.10, "pillar": 0.20, "strategist": 0.15, "skeptic": 0.20, "devoted": 0.10, "opportunist": 0.05, "mediator": 0.15, "nurturer": 0.20 },
		"actor.move":   { "vanguard": 0.40, "protector": 0.05, "seeker": 0.10, "pillar": 0.00, "strategist": 0.15, "skeptic": 0.05, "devoted": 0.00, "opportunist": 0.30, "mediator": 0.05, "nurturer": 0.00 },
	},
	# Flat archetype bonus — direct lookup by archetype_birth string (not a score, just a constant).
	# Mirrors combat_bias() from PersonalityArchetype: aggressive→melee/move, steadfast→guard,
	# supportive→protect_ally, cautious→guard+idle, balanced→no strong bias.
	"archetype_action_muls": {
		"melee_attack": { "valiant": 25, "proud": 20, "ambitious": 12, "canny": 8, "loyal": 4,
		                  "stoic": 0, "devout": 0, "empathic": -8, "reflective": -12 },
		"actor.move":   { "valiant": 20, "canny": 12, "ambitious": 8, "proud": 8, "loyal": -4,
		                  "stoic": 0, "devout": 0, "empathic": 0, "reflective": -8 },
		"actor.guard":  { "stoic": 14, "loyal": 16, "reflective": 8, "devout": 12, "empathic": 8,
		                  "canny": 4, "ambitious": 0, "valiant": -8, "proud": -8 },
		"protect_ally": { "empathic": 18, "loyal": 20, "devout": 12, "stoic": 8, "reflective": 4,
		                  "canny": 0, "ambitious": 0, "valiant": 0, "proud": -4 },
		"actor.idle":   { "reflective": 12, "stoic": 4, "devout": 4, "canny": 4, "loyal": 0,
		                  "empathic": 0, "ambitious": -4, "valiant": -8, "proud": -8 },
	},
	"directive_action_muls": {
		"melee_attack": { "objective_advance_priority": 1.0, "engage_only_blockers": 1.0, "avoid_overcommit": -0.5, "exposure_acceptance": 0.4 },
		"protect_ally": { "ally_protection_bias": 1.0, "threat_interception": 1.0 },
		"actor.guard":  { "ally_protection_bias": 1.0, "survival_bias": 1.0, "avoid_overcommit": 0.5, "exposure_acceptance": -0.3 },
		"actor.idle":   { "survival_bias": 1.0, "prefer_disengage": 1.0, "resource_efficiency": 1.0, "exposure_acceptance": -0.2, "clue_seeking_priority": 0.5, "reporting_priority": 0.3 },
		"actor.move":   { "objective_advance_priority": 1.0, "engage_only_blockers": 1.0, "clue_seeking_priority": 1.0, "reporting_priority": 1.0 },
	},
	"morale_action_muls": {
		"melee_attack": { "broken": -20, "shaken": -3, "steady": 0, "inspired": 12 },
		"protect_ally": { "broken": -8,  "shaken": -3, "steady": 0, "inspired": 6  },
		"actor.guard":  { "broken": 20,  "shaken":  4, "steady": 0, "inspired": -5 },
		"actor.idle":   { "broken": 15,  "shaken":  2, "steady": 0, "inspired": -5 },
		"actor.move":   { "broken": -20, "shaken": -3, "steady": 0, "inspired": 10 },
	},
	"directive_base_bonus":  20.0,
	"fear_active_dampen":    0.6,
	"fear_passive_actions":  ["actor.idle", "actor.guard"],
	"threat_threshold":      0.50,  # 0.50 = ally must be below 50% HP to qualify as threatened
	"guard_range":           1,     # enemy must be adjacent for guard to be a candidate (melee-only MVP)
	# V2-PROG-006: expression-band-based scoring defaults
	"wound_chase_mul":              15.0,  # Forming+ finish-wounded score bonus multiplier
	"surrounded_move_penalty":     -18.0, # Forming+ penalty for move into surrounded position
	"formation_distance":            6,   # Grounded+ formation pull threshold (tiles)
	"press_hp_threshold":            0.5, # Grounded+ calling bonus HP gate (target < 50%)
	"press_attack_bonus":           15.0, # Grounded aduro melee bonus vs wounded target
	"protect_ally_grounded_mul":     1.3, # Grounded okofor protect_ally score multiplier
	"protect_ally_grounded_hp_threshold": 0.50, # HP gate for okofor Grounded+ protect_ally mul

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
		# Echo-type only: adjacent to an enemy — fight, don't idle.
		"echo_in_melee": {
			"melee_attack": 18, "actor.press": 18, "protect_ally": -3, "actor.guard": -5, "actor.idle": -12, "actor.move": -5,
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
		# PROG-009: Seer directive aura — nearby allies receive a small bonus to strategic actions.
		# Fires when a Seer ally is within 3 tiles.
		"seer_directive_aura": {
			"melee_attack": 0, "protect_ally": 3, "actor.guard": 3, "actor.idle": 4, "actor.move": 0,
		},
		# PROG-009: discourages echo move spam when close to enemy but not yet adjacent.
		# Fires when echo moved last round AND enemy is within 1-3 tiles but not adjacent.
		"repeated_move_penalty": {
			"melee_attack": 0, "protect_ally": 0, "actor.guard": 5, "actor.idle": 5, "actor.move": -12,
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

	# V2-PROG-006: read expression band + calling behavior injected by ActorStateMachine
	var expression_band: String    = str(context.get("expression_band", "nascent"))
	var calling_behavior: Dictionary = context.get("calling_behavior", {})

	# Build board summary once — passed to _score() for every candidate to avoid re-computation.
	var board_summary: Dictionary = _build_board_summary(actor, all_actors, context.get("board_cfg", {}), expression_band)

	var candidates: Array[Dictionary] = _generate_candidates(actor, all_actors, context, expression_band, calling_behavior)

	# Score each candidate, then sort: highest score first; tiebreak alphabetically.
	for c: Dictionary in candidates:
		c["_score"] = _score(c["action_type"], actor, directive, board_summary, expression_band, calling_behavior, c)

	# VOW-001: apply vow bias additively after base scoring.
	# Vow bias is always additive, never overrides. Enemies are unaffected (faction != "echo").
	var active_vow: Dictionary = context.get("active_vow", {})
	if not active_vow.is_empty() and str(actor.get("faction", "")) == "echo":
		var party_size: int = int(context.get("party_size", 0))
		_apply_vow_bias(candidates, active_vow, party_size)

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
func _generate_candidates(
	actor: Dictionary,
	all_actors: Array,
	context: Dictionary = {},
	expression_band: String = "nascent",
	calling_behavior: Dictionary = {}
) -> Array[Dictionary]:
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

	var actor_type: String = str(actor.get("actor_type", "echo"))
	# V2-PROG-002: prefer confirmed calling (runtime identity) over birth origin.
	# Once an Echo has confirmed a calling, that identity drives behavior — not the birth weight.
	var _confirmed_calling: String = str(actor.get("calling", ""))
	var calling_origin: String = _confirmed_calling \
		if not _confirmed_calling.is_empty() and _confirmed_calling != "uncalled" \
		else str(actor.get("calling_origin", "uncalled"))
	var my_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 })

	# V2-PROG-006: Enemy Forming+ focus fire — prefer most-wounded echo over nearest.
	# Echo actors use standard nearest-enemy selection.
	var nearest_enemy: Dictionary
	if shrine_override.is_empty():
		if actor_type == "enemy" \
				and (expression_band == "forming" or expression_band == "grounded" or expression_band == "whole"):
			nearest_enemy = _get_most_wounded_enemy(actor, all_actors)
			if nearest_enemy.is_empty():
				nearest_enemy = ActorService.get_nearest_enemy(actor, all_actors)
		else:
			nearest_enemy = ActorService.get_nearest_enemy(actor, all_actors)
	else:
		nearest_enemy = shrine_override

	var enemy_dist: int = 999999
	var t_pos: Dictionary = {}
	if not nearest_enemy.is_empty():
		t_pos = nearest_enemy.get("grid_pos", { "col": 0, "row": 0 })
		enemy_dist = GridService.chebyshev_distance(my_pos, t_pos)

	# melee_attack: adjacent enemy (Chebyshev distance == 1, all 8 neighbours).
	# actor.move: enemy exists but not adjacent.
	# PROG-009: pre-compute mark/reveal bonuses for melee_attack candidates.
	var _mark_bonus: float   = 0.0
	var _reveal_bonus: float = 0.0
	if not nearest_enemy.is_empty():
		if not str(nearest_enemy.get("marked_by", "")).is_empty():
			_mark_bonus = 10.0
		if not str(nearest_enemy.get("revealed_by_seer", "")).is_empty():
			_reveal_bonus = 15.0

	if not nearest_enemy.is_empty():
		var target_hp_ratio: float = _hp_ratio(nearest_enemy)
		if GridService.is_adjacent(my_pos, t_pos):
			candidates.append({
				"action_type":     "melee_attack",
				"target_id":       str(nearest_enemy.get("id", "")),
				"distance":        enemy_dist,
				"target_hp_ratio": target_hp_ratio,
				"priority":        1.0,
				"_mark_bonus":     _mark_bonus,
				"_reveal_bonus":   _reveal_bonus,
			})
		else:
			candidates.append({
				"action_type":     "actor.move",
				"target_id":       str(nearest_enemy.get("id", "")),
				"target_pos":      t_pos,
				"target_distance": enemy_dist,
				"target_hp_ratio": target_hp_ratio,
				"priority":        1.0,
			})

	# actor.guard — only meaningful when an enemy is within guard_range tiles.
	# No nearby threat → guarding is pointless; omit so scorer never picks it.
	var guard_range: int = int(_cfg_get("guard_range"))
	if not nearest_enemy.is_empty() and enemy_dist <= guard_range:
		candidates.append({ "action_type": "actor.guard", "target_id": "", "priority": 0.0 })

	# protect_ally — only when a same-faction ally has taken any damage (current_hp < max_hp).
	# threshold=0.50 means ally must be below 50% HP (missing ≥50% HP) to qualify as threatened.
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

	# V2-PROG-006: actor.retreat — calling-aware, Forming+ only. Aduro never retreats.
	# Only echo actors can retreat.
	if actor_type == "echo" \
			and (expression_band == "forming" or expression_band == "grounded" or expression_band == "whole"):
		var retreat_threshold: Variant = calling_behavior.get("retreat_threshold", null)
		if retreat_threshold != null and calling_origin != "aduro":
			var hp_r: float = _hp_ratio(actor)
			if hp_r < float(retreat_threshold):
				candidates.append({
					"action_type": "actor.retreat",
					"target_id":   "",
					"priority":    1.0,
				})

	# V2-PROG-006: actor.taunt — Aduro calling Grounded+ only.
	# Mechanical effect applied by combat loop (taunted_by set on enemy).
	if actor_type == "echo" and calling_origin == "aduro" \
			and (expression_band == "grounded" or expression_band == "whole") \
			and not nearest_enemy.is_empty():
		candidates.append({
			"action_type": "actor.taunt",
			"target_id":   str(nearest_enemy.get("id", "")),
			"priority":    1.0,
		})

	# PROG-009: Skill-gated action candidates.
	# Each echo may have equipped_skills (slot → skill_id). For each equipped skill whose
	# condition is met this turn, generate a typed candidate with a pre-resolved skill_base_bonus
	# so _score() doesn't need intent weight rows for every calling skill action_type.
	if actor_type == "echo":
		var skills_cfg: Dictionary = context.get("skills_cfg", {})
		var skill_defs: Dictionary = skills_cfg.get("definitions", {})
		var equipped: Dictionary   = actor.get("equipped_skills", {})
		for _slot_key in equipped:
			var skill_id: String = str(equipped[_slot_key])
			if skill_id.is_empty():
				continue
			var defn: Dictionary = skill_defs.get(skill_id, {})
			if defn.is_empty():
				continue
			var action_t: String = str(defn.get("action_type", ""))
			if action_t.is_empty():
				continue
			var weight_tag: String = str(defn.get("intent_weight_tag", "melee_attack"))
			match action_t:
				"actor.press":
					# Condition: hit same target last round AND still adjacent.
					var press_li_v: Variant = actor.get("last_intent", {})
					var press_li: Dictionary = press_li_v if press_li_v is Dictionary else {}
					if str(press_li.get("action_type", "")) == "melee_attack" \
							and not str(press_li.get("target_id", "")).is_empty() \
							and not nearest_enemy.is_empty() \
							and str(press_li.get("target_id", "")) == str(nearest_enemy.get("id", "")) \
							and not t_pos.is_empty() \
							and GridService.is_adjacent(my_pos, t_pos):
						candidates.append({
							"action_type":      "actor.press",
							"target_id":        str(nearest_enemy.get("id", "")),
							"target_hp_ratio":  _hp_ratio(nearest_enemy),
							"skill_id":         skill_id,
							"skill_base_bonus": _resolve_skill_base(calling_origin, weight_tag, 15.0),
							"priority":         1.0,
						})
				"actor.interpose":
					# Condition: ally threatened.
					var interpose_ally: Dictionary = ActorService.get_threatened_ally(actor, all_actors, threshold)
					if not interpose_ally.is_empty():
						candidates.append({
							"action_type":      "actor.interpose",
							"target_id":        str(interpose_ally.get("id", "")),
							"skill_id":         skill_id,
							"skill_base_bonus": _resolve_skill_base(calling_origin, weight_tag, 0.0),
							"priority":         1.0,
						})
				"actor.hold_ground":
					# Condition: adjacent to shrine OR 2+ faction allies within 2 tiles.
					var hg_shrine: bool = false
					var hg_allies: int  = 0
					for hg_av in all_actors:
						if not (hg_av is Dictionary): continue
						var hg_a: Dictionary = hg_av
						if hg_a.get("is_dead", false): continue
						var hg_pos: Dictionary = hg_a.get("grid_pos", {})
						if hg_pos.is_empty(): continue
						if hg_a.get("is_structure", false):
							if GridService.chebyshev_distance(my_pos, hg_pos) <= 1:
								hg_shrine = true
						elif str(hg_a.get("faction", "")) == str(actor.get("faction", "")) \
								and str(hg_a.get("id", "")) != str(actor.get("id", "")):
							if GridService.chebyshev_distance(my_pos, hg_pos) <= 2:
								hg_allies += 1
					if hg_shrine or hg_allies >= 2:
						candidates.append({
							"action_type":      "actor.hold_ground",
							"target_id":        "",
							"skill_id":         skill_id,
							"skill_base_bonus": _resolve_skill_base(calling_origin, weight_tag, 0.0),
							"priority":         1.0,
						})
				"actor.steady_call":
					# Once per combat; no other condition required.
					if not bool(actor.get("_steady_call_used", false)):
						candidates.append({
							"action_type":      "actor.steady_call",
							"target_id":        "",
							"skill_id":         skill_id,
							"skill_base_bonus": _resolve_skill_base(calling_origin, weight_tag, 10.0),
							"priority":         1.0,
						})
				"actor.mark":
					# Condition: enemy within 3 tiles AND not already marked.
					if not nearest_enemy.is_empty() and enemy_dist <= 3 \
							and str(nearest_enemy.get("marked_by", "")).is_empty():
						candidates.append({
							"action_type":      "actor.mark",
							"target_id":        str(nearest_enemy.get("id", "")),
							"skill_id":         skill_id,
							"skill_base_bonus": _resolve_skill_base(calling_origin, weight_tag, 5.0),
							"priority":         1.0,
						})
				"actor.withdraw":
					# Condition: adjacent to 2+ enemies AND not on cooldown.
					if int(actor.get("_withdraw_cooldown", 0)) <= 0:
						var wd_count: int = 0
						for wd_av in all_actors:
							if not (wd_av is Dictionary): continue
							var wd_a: Dictionary = wd_av
							if wd_a.get("is_dead", false) or wd_a.get("is_structure", false): continue
							if str(wd_a.get("faction", "")) != str(actor.get("faction", "")):
								var wd_pos: Dictionary = wd_a.get("grid_pos", {})
								if not wd_pos.is_empty() and GridService.is_adjacent(my_pos, wd_pos):
									wd_count += 1
						if wd_count >= 2:
							candidates.append({
								"action_type":      "actor.withdraw",
								"target_id":        "",
								"skill_id":         skill_id,
								"skill_base_bonus": _resolve_skill_base(calling_origin, weight_tag, 0.0),
								"priority":         1.0,
							})
				"actor.read_field":
					# Condition: _read_field_cooldown == 0.
					if int(actor.get("_read_field_cooldown", 0)) == 0:
						candidates.append({
							"action_type":      "actor.read_field",
							"target_id":        "",
							"skill_id":         skill_id,
							"skill_base_bonus": _resolve_skill_base(calling_origin, weight_tag, 10.0),
							"priority":         1.0,
						})
				"actor.reveal":
					# Once per combat; condition: nearest enemy not yet revealed by seer.
					if not bool(actor.get("_reveal_used", false)) \
							and not nearest_enemy.is_empty() \
							and str(nearest_enemy.get("revealed_by_seer", "")).is_empty():
						candidates.append({
							"action_type":      "actor.reveal",
							"target_id":        str(nearest_enemy.get("id", "")),
							"skill_id":         skill_id,
							"skill_base_bonus": _resolve_skill_base(calling_origin, weight_tag, 10.0),
							"priority":         1.0,
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
func _build_board_summary(actor: Dictionary, all_actors: Array, _board_cfg: Dictionary, expression_band: String = "nascent") -> Dictionary:
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

	# Echo-type: in_melee — adjacent to an enemy, push to attack.
	if actor_type == "echo" and enemy_dist <= 1:
		active.append("echo_in_melee")

	# Enemy-type-only conditions — gated so echo actors never receive them.
	if actor_type == "enemy" and enemy_dist < 999999:
		var n_pos: Dictionary = nearest_enemy.get("grid_pos", { "col": 0, "row": 0 })
		if GridService.is_adjacent(my_pos, n_pos):
			active.append("enemy_engaged")
		else:
			active.append("enemy_advancing")

	# V2-PROG-006: echo_retreating — enemy Forming+ pursuit.
	# Active when this enemy is Forming+ and any echo is retreating (last_intent == actor.retreat).
	if actor_type == "enemy" \
			and (expression_band == "forming" or expression_band == "grounded" or expression_band == "whole"):
		for a_v in all_actors:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v as Dictionary
			if a.get("actor_type", "") == "echo" and not a.get("is_dead", false):
				var li_v: Variant = a.get("last_intent", {})
				if li_v is Dictionary and str((li_v as Dictionary).get("action_type", "")) == "actor.retreat":
					active.append("echo_retreating")
					break

	# PROG-009: Okomfo directive aura — any echo ally within 3 tiles of a living Okomfo gets a bonus.
	if actor_type == "echo":
		for sa_v in all_actors:
			if not (sa_v is Dictionary): continue
			var sa: Dictionary = sa_v
			if sa.get("is_dead", false): continue
			if str(sa.get("id", "")) == my_id: continue
			if str(sa.get("faction", "")) == my_faction \
					and str(sa.get("calling_origin", "")) == "okomfo":
				var sa_pos: Dictionary = sa.get("grid_pos", {})
				if not sa_pos.is_empty() and GridService.chebyshev_distance(my_pos, sa_pos) <= 3:
					active.append("seer_directive_aura")
					break

	# PROG-009: repeated_move_penalty — echo moved last round AND enemy is nearby but not adjacent.
	# Fires in the 2-3 tile band: too close to keep running, close enough to act.
	if actor_type == "echo" and enemy_dist > 1 and enemy_dist <= 3:
		var last_i_v: Variant = actor.get("last_intent", {})
		var last_i: Dictionary = last_i_v if last_i_v is Dictionary else {}
		if str(last_i.get("action_type", "")) == "actor.move":
			active.append("repeated_move_penalty")

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
func _score(
	action_type: String,
	actor: Dictionary,
	directive: Dictionary,
	board_summary: Dictionary = {},
	expression_band: String = "nascent",
	calling_behavior: Dictionary = {},
	candidate: Dictionary = {}
) -> float:
	var calling_origin: String = str(actor.get("calling_origin", "uncalled"))
	var traits: Dictionary     = actor.get("traits", {})
	var vectors: Dictionary    = actor.get("vector_scores", {})
	# EMOTION-003: floor blend — background dread can't be suppressed below fear_base even by a kill
	var fear_current_val: float = float(actor.get("fear", 0))
	var fear_base_val: float    = float(actor.get("fear_base", 0))
	var fear: float             = maxf(fear_current_val, fear_base_val)

	# 1. Base weight from calling_origin table.
	# Skill-gated candidates carry skill_base_bonus (pre-resolved via intent_weight_tag + bonus);
	# use that directly so unknown action types don't fall through to the default weight.
	var origin_table: Dictionary = _cfg_get("intent_weights_by_calling_origin")
	var calling_row: Dictionary  = origin_table.get(calling_origin, origin_table.get("uncalled", {}))
	var default_weight: float    = _cfg_get("default_intent_weight")
	var base: float
	if candidate.has("skill_base_bonus"):
		base = float(candidate["skill_base_bonus"])
	else:
		base = float(calling_row.get(action_type, default_weight))

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
	# PROG-009: Aduro passive — broken morale → aggression override (override the default penalty).
	if morale_tier == "broken" and calling_origin == "aduro":
		var bmo: Dictionary = calling_behavior.get("broken_morale_override", {})
		if bmo.has(action_type):
			morale_bonus = float(bmo[action_type])
	# PROG-009: Okofor passive — anchor bonus on guard/protect_ally per stationary round.
	if calling_origin == "okofor" and (action_type == "actor.guard" or action_type == "protect_ally"):
		var anchor_rounds: int = int(actor.get("_anchor_rounds", 0))
		base += float(mini(anchor_rounds * 8, 24))

	# 6. Directive bonus — generic loop over intent_weights (semantic keys).
	var directive_bonus: float = _directive_bonus(action_type, directive)

	# V2-PROG-006: calling-aware score multipliers (Grounded+ only)
	var calling_mul: float = 1.0
	if expression_band == "grounded" or expression_band == "whole":
		var actor_type_str: String = str(actor.get("actor_type", "echo"))
		var calling_str: String = str(actor.get("calling_origin", "uncalled"))
		if actor_type_str == "echo":
			var press_threshold: float = float(_cfg_get("press_hp_threshold") if _cfg.has("press_hp_threshold") \
				else 0.5)
			var target_hp: float = float(candidate.get("target_hp_ratio", 1.0))
			match calling_str:
				"okofor":
					if action_type == "protect_ally":
						var protect_mul: float = float(_cfg_get("protect_ally_grounded_mul") \
							if _cfg.has("protect_ally_grounded_mul") else 1.3)
						var protect_hp_gate: float = float(_cfg_get("protect_ally_grounded_hp_threshold") \
							if _cfg.has("protect_ally_grounded_hp_threshold") else 0.50)
						if target_hp <= protect_hp_gate:
							calling_mul = protect_mul
				"aduro":
					if action_type == "melee_attack" and target_hp <= press_threshold:
						base += float(_cfg_get("press_attack_bonus") if _cfg.has("press_attack_bonus") else 15.0)

	# V2-PROG-006: Forming+ finish-the-wounded — melee_attack bonus for wounded targets
	if action_type == "melee_attack" \
			and (expression_band == "forming" or expression_band == "grounded" or expression_band == "whole"):
		var target_hp_r: float = float(candidate.get("target_hp_ratio", 1.0))
		var wound_mul: float = float(_cfg_get("wound_chase_mul") if _cfg.has("wound_chase_mul") else 15.0)
		base += (1.0 - target_hp_r) * wound_mul

	# PROG-010: taunted_by — enemy strongly prefers the taunt-source echo (+25 attack score)
	if action_type == "melee_attack":
		var taunted_by: String = str(actor.get("taunted_by", ""))
		if not taunted_by.is_empty() and str(candidate.get("target_id", "")) == taunted_by:
			base += 25.0
		# PROG-009: marked_by (+10 for all echoes) + revealed_by_seer (+15 for all echoes)
		base += float(candidate.get("_mark_bonus",   0.0))
		base += float(candidate.get("_reveal_bonus", 0.0))

	# PROG-009: Calling emotional signatures — fear amplifies calling-specific tendencies.
	if fear > 0.0:
		match calling_origin:
			"kra_soro":
				# Fear → movement bonus (threat-sensitive repositioning); idle suppressed.
				if action_type == "actor.move":
					base += float(calling_behavior.get("fear_move_bonus", 0.0))
				elif action_type == "actor.idle":
					base -= 8.0
			"okomfo":
				# Fear → idle rises (Okomfo retreats into perception, not action).
				if action_type == "actor.idle":
					base += fear * 0.15
			"onyamesu":
				# Fear → move penalty (Onyamesu holds ground under pressure).
				if action_type == "actor.move":
					base -= fear * 0.15
			"okofor":
				# Fear → protect_ally bonus (defensive surge under pressure).
				if action_type == "protect_ally":
					base += fear * 0.1

	return (base + trait_bonus + vector_bonus + archetype_bonus + morale_bonus) * fear_factor * calling_mul + directive_bonus + _situational_bonus(action_type, board_summary)


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


# PROG-010: Returns the most wounded (lowest hp_ratio) enemy relative to this actor.
# Used for enemy Adept+ focus fire. Falls back to empty if no enemies exist.
func _get_most_wounded_enemy(actor: Dictionary, all_actors: Array) -> Dictionary:
	var my_faction: String = str(actor.get("faction", "echo"))
	var best: Dictionary = {}
	var best_ratio: float = 2.0
	for a_v in all_actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v as Dictionary
		if str(a.get("faction", "")) == my_faction:
			continue
		if a.get("is_dead", false) or a.get("is_structure", false):
			continue
		var r: float = _hp_ratio(a)
		if r < best_ratio:
			best_ratio = r
			best = a
	return best


# PROG-009: Resolve base score for a skill candidate.
# Looks up calling_origin's weight for intent_weight_tag (the action type this skill resembles),
# then adds a skill-specific bonus. Stored as skill_base_bonus in the candidate dict so
# _score() can use it in place of the normal action_type table lookup.
func _resolve_skill_base(calling_origin: String, intent_weight_tag: String, bonus: float) -> float:
	var origin_table: Dictionary = _cfg_get("intent_weights_by_calling_origin")
	var calling_row: Dictionary  = origin_table.get(calling_origin, origin_table.get("uncalled", {}))
	var default_weight: float    = float(_cfg_get("default_intent_weight"))
	return float(calling_row.get(intent_weight_tag, default_weight)) + bonus


# VOW-001: Apply vow-specific intent bias additively to all candidates.
# Each vow may boost or penalise specific action_types based on context.
# Echo actors only — call site already guards faction == "echo".
func _apply_vow_bias(candidates: Array, active_vow: Dictionary, party_size: int) -> void:
	var vow_id := str(active_vow.get("vow_id", ""))
	var tier   := int(active_vow.get("tier", 1))
	var mul    := float(tier)  # tier 1=1×, tier 2=2×, … (raw; tuned per-vow below)

	match vow_id:
		"tikoro_nko_agyina":
			# "One head does not constitute a council"
			# Benefit: party ≥3 → protect_ally and actor.guard get a boost (cohesion)
			# Tradeoff: party <3 → fear bias (solo disadvantage)
			if party_size >= 3:
				var protect_bonus := 8.0 * mul
				var guard_bonus   := 4.0 * mul
				for c: Dictionary in candidates:
					var at: String = str(c.get("action_type", ""))
					if at == "protect_ally":
						c["_score"] = float(c.get("_score", 0.0)) + protect_bonus
					elif at == "actor.guard":
						c["_score"] = float(c.get("_score", 0.0)) + guard_bonus
			else:
				# Fear bias: active intents depressed (actor prefers idle/guard under doctrine strain)
				var fear_bias := 6.0 * mul
				for c: Dictionary in candidates:
					var at: String = str(c.get("action_type", ""))
					if at == "melee_attack" or at == "actor.move":
						c["_score"] = float(c.get("_score", 0.0)) - fear_bias


# PROG-010: Compute hp_ratio for any actor dict. Returns 1.0 if stats unavailable.
static func _hp_ratio(actor: Dictionary) -> float:
	var max_hp: int = int(actor.get("stats", {}).get("max_hp", 0))
	if max_hp <= 0 or not actor.has("current_hp"):
		return 1.0
	return clampf(float(actor["current_hp"]) / float(max_hp), 0.0, 1.0)
