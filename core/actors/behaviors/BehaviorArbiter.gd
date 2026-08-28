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
var _movement_cfg: Dictionary

const MovementContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const MovementProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")
const MovementGoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const MovementOptionContract = preload("res://core/movement/contracts/MovementOption.gd")
const MovementIntentContract = preload("res://core/movement/contracts/MovementIntent.gd")
const MovementActionPlanContract = preload("res://core/movement/contracts/MovementActionPlan.gd")

const _MOVEMENT_STYLE_ORDER: Array = [
	"direct", "safe", "cohesive", "lateral", "screen", "intercept", "conservative",
]
const _SPATIAL_UTILITY_FIELDS: Array = [
	"cap",
	"urgency_weight",
	"objective_progress_weight",
	"cohesion_weight",
	"exposure_weight",
	"congestion_weight",
	"commitment_weight",
	"directive_objective_advance_weight",
	"directive_avoid_overcommit_weight",
	"directive_exposure_acceptance_weight",
	"directive_ally_protection_weight",
	"directive_threat_interception_weight",
]

# Hardcoded defaults — mirrors data/balance.json data.actor block.
# Used when _cfg is empty (no balance.json block passed in).
const _DEFAULTS := {
	"intent_weights_by_calling_origin": {
		"okofor":      { "melee_attack": 20, "protect_ally": 65, "actor.guard": 45, "actor.idle":  5, "actor.move": 25 },
		"aduro":       { "melee_attack": 65, "protect_ally": 10, "actor.guard": 15, "actor.idle":  3, "actor.move": 55 },
		"kra_soro":    { "melee_attack": 40, "protect_ally": 10, "actor.guard": 15, "actor.idle":  3, "actor.move": 55 },
		"onyamesu":    { "melee_attack": 35, "protect_ally": 30, "actor.guard": 55, "actor.idle":  8, "actor.move": 20 },
		"okomfo":      { "melee_attack": 25, "protect_ally": 20, "actor.guard": 30, "actor.idle": 12, "actor.move": 35 },
		"sum_okwanfo": { "melee_attack": 40, "protect_ally":  5, "actor.guard": 10, "actor.idle":  5, "actor.move": 55 },
		"uncalled":    { "melee_attack": 50, "protect_ally": 15, "actor.guard": 25, "actor.idle":  8, "actor.move": 44 },
		# Enemy baseline: aggressive. protect_ally=0 (enemies don't protect each other in MVP).
		# guard/idle stay low so enemies almost never passively hold unless situationally forced.
		"enemy":       { "melee_attack": 70, "protect_ally":  0, "actor.guard": 10, "actor.idle":  2, "actor.move": 60 },
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
	"fear_active_dampen":    0.45,
	"fear_passive_actions":  ["actor.idle", "actor.guard"],
	"threat_threshold":      0.50,  # 0.50 = ally must be below 50% HP to qualify as threatened
	"guard_range":           1,     # enemy must be adjacent for guard to be a candidate (melee-only MVP)
	# V2-PROG-006: expression-band-based scoring defaults
	# V2-PROG-010: identity weight scaling + composure tables
	# V2-PROG-012 Phase 6 Item 2: identity_weight_scale and directive_interpretation_mul
	# are the two halves of ONE budgeted axis (interpretation_width, driven by
	# judgment) — see data.maturity_expression's matching _comment for the swing
	# budget these two keys are jointly checked against (config-integrity test:
	# tests/BehaviorArbiterTests.gd's arbiter/interpretation_swing_within_declared_budget).
	# {trait: 0.35, vector: 0.35} against directive_interpretation_mul.low=0.75 gives
	# (1.0+0.35)/0.75 = 1.80 <= interpretation_swing_max (2.0). directive_band_mul
	# (the old per-band table) is REMOVED, not kept dead — see _directive_bonus()'s
	# doc comment.
	"identity_weight_scale":  { "trait": 0.35, "vector": 0.35 },
	"composure_dampen_scale": { "value": 0.4 },  # V2-PROG-012 Phase 2 (renamed from presence_dampen_scale)
	"directive_interpretation_mul": { "low": 0.75, "high": 1.30 },
	"interpretation_swing_max": { "value": 2.0 },

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
		# COMBAT-BUG-002: score pressure that fires on the SAME condition as candidate suppression
		# (last_intent == guard, enemy adjacent, echo).
		# Primary role: on the suppressed turn, guard is not in the pool but idle/protect_ally
		# still compete with melee_attack. The +15 melee bonus ensures melee beats idle even
		# under last_echo_standing or high-fear states where idle would otherwise win.
		# Secondary role: when guard IS in the pool (HP critical exception), reduces guard's score
		# so a critically-wounded echo doesn't guard as reflexively as a healthy one.
		# Values are intentionally moderate — candidate suppression is the hard guarantee.
		"repeated_guard_penalty": {
			"melee_attack": 15, "protect_ally": 0, "actor.guard": -20, "actor.idle": -5, "actor.move": 0,
		},
	},
}


## actor_cfg: the data.actor block from balance.json, or {} to use hardcoded defaults.
## Tests and non-echo actors may pass {} safely — behaviour is identical to balance.json values.
## movement_cfg: the data.combat.movement block. It is consumed by
## select_movement_intent() — live since V2-COMBAT-002 Slice 6B/6C and now the
## dominant movement-selection path (see that function's doc comment).
func _init(actor_cfg: Dictionary = {}, movement_cfg: Dictionary = {}) -> void:
	_cfg = actor_cfg
	_movement_cfg = movement_cfg


func get_module_id() -> String:
	return "arbiter"


func select_intent(context: Dictionary) -> Dictionary:
	var actor: Dictionary     = context.get("actor", {})
	var all_actors: Array     = context.get("all_actors", [])
	var directive: Dictionary = context.get("directive", {})

	# V2-PROG-006: read expression band + calling behavior injected by ActorStateMachine
	var expression_band: String      = str(context.get("expression_band", "nascent"))
	var calling_behavior: Dictionary = context.get("calling_behavior", {})
	# V2-PROG-010: rank-strength and presence_strength for identity scaling + composure
	var presence_strength: float = float(context.get("presence_strength", 0.1))
	var rank_strength: float     = float(context.get("rank_strength", 0.0))
	# V2-PROG-012 Phase 2: composure — the actual fear-dampening driver (see _score()).
	var composure: float         = float(context.get("composure", 0.4))
	# V2-PROG-012 Phase 6 (DEFECT 2 fix): judgment — drives interpretation_width, the
	# single continuous axis both identity weighting and directive literalism now key
	# on (see _score() and _directive_bonus()). Threaded exactly as composure was in
	# Phase 2. Default 0.3 mirrors composure's default derivation above: under the
	# balance.json judgment weights (rank_strength_weight 0.25 + storyweight_maturity_weight
	# 0.2 + identity_coherence_weight 0.2 at ~0.5 each, no calling accent confirmed, no
	# bond support, no fear spike ≈ 0.325, rounded to 0.3) — a "mid-band" fallback, not
	# the floor (0.0, most literal) or the ceiling (1.0, most self-directed).
	var judgment: float          = float(context.get("judgment", 0.3))
	# V2-PROG-012 Phase 6: the single continuous axis — see _score()'s doc comment
	# on why this replaces both rank_strength (identity) and expression_band
	# (directive) as the shared driver.
	var interpretation_width: float = clampf(judgment, 0.0, 1.0)

	# Build board summary once — passed to _score() for every candidate to avoid re-computation.
	var board_summary: Dictionary = _build_board_summary(actor, all_actors, context.get("board_cfg", {}), expression_band, context.get("resolution_mode", ""), context.get("objective_modes_cfg", {}))

	var candidates: Array[Dictionary] = _generate_candidates(actor, all_actors, context, expression_band, calling_behavior)

	# Score each candidate, then sort by the same four-key order used by the
	# movement-aware selector: score, action type, target id, target cell.
	for c: Dictionary in candidates:
		c["_score"] = _score(c["action_type"], actor, directive, board_summary, expression_band, calling_behavior, c, presence_strength, rank_strength, composure, judgment)

	# VOW-001: apply vow bias additively after base scoring.
	# Vow bias is always additive, never overrides. Enemies are unaffected (faction != "echo").
	var active_vow: Dictionary = context.get("active_vow", {})
	if not active_vow.is_empty() and str(actor.get("faction", "")) == "echo":
		var party_size: int = int(context.get("party_size", 0))
		_apply_vow_bias(candidates, active_vow, party_size)

	# BOND-002: apply bond bias additively after vow bias. Echo faction only.
	var bonds_ctx: Array = context.get("bonds", []) as Array
	var bond_thresholds_ctx: Dictionary = context.get("bond_thresholds", {})
	var bond_behavior_cfg: Dictionary = context.get("bond_behavior_cfg", {})
	if not bonds_ctx.is_empty() and str(actor.get("faction", "")) == "echo":
		_apply_bond_bias(candidates, actor, bonds_ctx, bond_thresholds_ctx, bond_behavior_cfg)

	# COMBAT-006: actor.purify_shrine override — injected AFTER scoring so 9999 is never overwritten.
	# Fires when shrine HP drops below 50%, the purifier is adjacent, and cooldown is 0.
	# HP gate is intentional: purifying at full shrine HP wastes a turn that should be spent
	# intercepting the enemy. The purifier moves toward the enemy while shrine HP is healthy
	# and purifies only when the shrine is actually taking meaningful drain damage.
	# Adjacency check added (COMBAT-BUG-001): prevents a wasted no-op purify from far away.
	if context.get("is_purifier", false) \
			and context.get("shrine_alive", false) \
			and float(context.get("shrine_hp_ratio", 1.0)) < 0.5 \
			and int(actor.get("purify_cooldown", 0)) == 0:
		var my_pos_pu: Dictionary = actor.get("grid_pos", {})
		for a_v in all_actors:
			if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
				if GridService.is_adjacent(my_pos_pu, a_v.get("grid_pos", {})):
					candidates.append({
						"action_type": "actor.purify_shrine",
						"target_id":   "",
						"priority":    1.0,
						"_score":      9999.0,
					})
				break

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["_score"] != b["_score"]:
			return a["_score"] > b["_score"]
		if str(a["action_type"]) != str(b["action_type"]):
			return str(a["action_type"]) < str(b["action_type"])
		if str(a.get("target_id", "")) != str(b.get("target_id", "")):
			return str(a.get("target_id", "")) < str(b.get("target_id", ""))
		return _candidate_target_key(a) < _candidate_target_key(b)
	)

	# V2-PROG-012 Phase 4: locate D, the Directive-preferred candidate — the one
	# maximizing _directive_bonus() for its action_type. _directive_bonus() depends
	# only on action_type (given a fixed directive/band/calling_behavior this turn),
	# so candidates sharing an action_type share the identical value; caching by
	# action_type avoids redundant recomputation. Tie-break: `candidates` is already
	# sorted in the exact four-key order used above (score, action_type, target_id,
	# _candidate_target_key), so scanning forward and keeping strict `>` gives the
	# same tie-break the winner sort would give — no second sort needed.
	# V2-PROG-012 Phase 4 fix: also track `decision_scale` — the spread of
	# self_score (= _score - directive_bonus, the Echo's own judgment with the
	# Directive's voice subtracted out) across every regularly-scored candidate.
	# This is the denominator DivergenceDetector.gd uses to turn `directive_pull`
	# into a proportion (contest_ratio) instead of a raw number dominated by how
	# much better acting is than idling. Hard-override sentinels (actor.purify_shrine's
	# 9999.0) ARE already present in `candidates` by this point (appended before the
	# sort above) — excluded here for the same reason the winner-side probe below
	# skips them entirely: a mechanical certainty isn't a tactical option she weighed,
	# and including it would blow the spread out to a meaningless ~9999.
	# V2-PROG-012 Phase 4 fix — Part B (fall-through, not suppression): track
	# `_repr_by_type`, the highest-scoring candidate seen for each action_type
	# (`candidates` is already score-sorted, so the FIRST candidate of a given
	# type encountered here is that type's best). Below, this feeds a full
	# directive_bonus-descending ranking (`_rank_directive_candidates()`), not
	# just a single top D — measurement showed the top D is
	# directive.scout_carefully's actor.idle on ~100% of turns (idle carries 6
	# directive_action_muls keys, more than any other action), so a detector
	# that SUPPRESSES whenever D is actor.idle (per this story's Part B, naive
	# reading) went silent for the entire encounter — a dormant seam, explicitly
	# called out as a failure condition in the story brief. DivergenceDetector.gd
	# instead falls through this ranked list to the next-best NON-ignored
	# action_type; BehaviorArbiter still doesn't know or care what "ignored"
	# means (that policy stays in DivergenceDetector.gd) — it just reports the
	# full ranking. (There is deliberately no separate "single top D" variable
	# here — an earlier draft kept one alongside the ranking and it went dead,
	# unread by anything once the ranking replaced it; see the story brief on
	# not shipping config or variables that only look live.)
	# V2-PROG-012 Phase 5 fix: divergence detection only makes sense for an actor
	# that actually receives the Directive. Gate is faction == "echo", NOT
	# actor_type == "echo" — V2-STAGE-004 temporary allies are built by
	# ContactActorBuilder.gd via EnemyActor.from_definition (which always sets
	# actor_type "enemy") with faction overridden to "echo"; actor_type would
	# wrongly exclude them from a party they fight in and are subject to the
	# Directive alongside. True enemies (faction "enemy") never receive the
	# Directive at all — measured production run: 7 of 8 actor.divergence events
	# were logged for an enemy actor against directive.scout_carefully, which is
	# meaningless (an enemy has no Directive to diverge from) and — because Phase
	# 4's min_contest_ratio=0.35 was calibrated against a contest_ratio sample
	# drawn from ALL actors, not Echoes only — invalidated that calibration (see
	# data.maturity_expression.divergence._comment's re-measurement note). Same
	# pattern this file already uses for VOW-001/BOND-002 bias above. Gated here,
	# before the per-candidate accumulation loop, so non-echo actors skip the
	# whole probe — not just the eventual divergence log — at zero extra cost.
	var _is_echo_faction: bool = str(actor.get("faction", "")) == "echo"
	var _dbonus_by_type: Dictionary = {}
	var _repr_by_type: Dictionary = {}
	var _decision_scale: float = 0.0
	if _is_echo_faction:
		var _self_score_min: float = INF
		var _self_score_max: float = -INF
		for c: Dictionary in candidates:
			var _atype: String = str(c.get("action_type", ""))
			if not _dbonus_by_type.has(_atype):
				_dbonus_by_type[_atype] = _directive_bonus(_atype, directive, interpretation_width, calling_behavior)
				_repr_by_type[_atype] = c
			var _cbonus: float = float(_dbonus_by_type[_atype])
			var _cscore: float = float(c.get("_score", 0.0))
			if _cscore < 9999.0:
				var _cself_score: float = _cscore - _cbonus
				if _cself_score < _self_score_min:
					_self_score_min = _cself_score
				if _cself_score > _self_score_max:
					_self_score_max = _cself_score
		_decision_scale = (_self_score_max - _self_score_min) if _self_score_max >= _self_score_min else 0.0

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

	# V2-PROG-012 Phase 4: expose divergence-detection inputs on the winner. This
	# is pure REPORTING — BehaviorArbiter never decides what counts as divergence
	# (that policy lives in DivergenceDetector.gd, called by ActorStateMachine).
	# Skipped when the winner is a hard score override (e.g. actor.purify_shrine's
	# 9999.0 sentinel at ~:333): that is a mechanical certainty, not the Echo's
	# judgment outvoting the Directive, so it is not a candidate for divergence.
	var _winner_score: float = float(candidates[0].get("_score", 0.0))
	if _is_echo_faction and _winner_score < 9999.0:
		var _w_action_type: String = str(candidates[0].get("action_type", ""))
		var _w_components: Dictionary = {}
		# Recompute is deterministic/pure — identical inputs to the call already made
		# in the scoring loop above, so this reproduces `_winner_score` exactly while
		# also capturing the term breakdown _score() didn't have anywhere to put
		# the first time (see DivergenceDetectorTests for the no-score-drift pin).
		_score(_w_action_type, actor, directive, board_summary, expression_band, calling_behavior,
			candidates[0], presence_strength, rank_strength, composure, judgment, _w_components)
		winner["_divergence_probe"] = {
			"chosen": {
				"action_type":             _w_action_type,
				"target_id":               str(candidates[0].get("target_id", "")),
				"score":                   _winner_score,
				"directive_bonus":         float(_dbonus_by_type.get(_w_action_type, 0.0)),
				# V2-PROG-012 Phase 6: interpretation_width=0.0 is the new "most literal"
				# floor (was band string "nascent" — see _directive_bonus()'s doc comment).
				"directive_bonus_nascent": _directive_bonus(_w_action_type, directive, 0.0, calling_behavior),
				"components":              _w_components,
			},
			# V2-PROG-012 Phase 4 fix: the FULL directive_bonus-descending ranking
			# (not just the single top D) — see `_repr_by_type` above for why.
			# DivergenceDetector.gd falls through this list past any ignored
			# action_type (data.maturity_expression.divergence.divergence_ignored_directive_actions)
			# to find the effective directive_preferred candidate.
			"directive_candidates": _rank_directive_candidates(
				_dbonus_by_type, _repr_by_type, directive, calling_behavior
			),
			# V2-PROG-012 Phase 4 fix: see `_decision_scale` above — DivergenceDetector.gd
			# divides `directive_pull` by this to get a proportion instead of a raw number.
			"decision_scale": _decision_scale,
		}

	return winner


## Movement-intent arbitration: scores every generated movement candidate for
## `actor` against the board/directive/expression context and returns the
## winning intent. Introduced dormant as V2-COMBAT-002 Slice 2 complete-candidate
## arbitration; V2-COMBAT-002 Slice 6B/6C cut movement over to live, and this is
## now the dominant selection path — V2-PROG-012 Phase 4 measured it firing 230
## times vs. 122 for select_intent() across the test suite.
func select_movement_intent(
	context: Dictionary,
	movement_context: Dictionary,
	profile: Dictionary,
	goals: Array,
	options: Array
) -> Dictionary:
	var validated: Dictionary = _validate_movement_inputs(
		context, movement_context, profile, goals, options
	)
	if not bool(validated["valid"]):
		return validated

	var actor: Dictionary = context["actor"] as Dictionary
	var all_actors: Array = _canonical_perceived_actors(context, movement_context)
	var directive: Dictionary = context.get("directive", {}) as Dictionary
	var expression_band: String = str(context.get("expression_band", "nascent"))
	var calling_behavior: Dictionary = context.get("calling_behavior", {}) as Dictionary
	var presence_strength: float = float(context.get("presence_strength", 0.1))
	var rank_strength: float = float(context.get("rank_strength", 0.0))
	# V2-PROG-012 Phase 2: composure — the actual fear-dampening driver (see _score()).
	var composure: float = float(context.get("composure", 0.4))
	# V2-PROG-012 Phase 6: judgment — see select_intent()'s equivalent block for the
	# default derivation and why this drives interpretation_width.
	var judgment: float = float(context.get("judgment", 0.3))
	var interpretation_width: float = clampf(judgment, 0.0, 1.0)
	var board_summary: Dictionary = _build_board_summary(
		actor,
		all_actors,
		context.get("board_cfg", {}),
		expression_band,
		context.get("resolution_mode", ""),
		context.get("objective_modes_cfg", {})
	)

	var legacy_candidates: Array[Dictionary] = _generate_candidates(
		actor, all_actors, context, expression_band, calling_behavior
	)
	var legacy_by_plan: Dictionary = {}
	var candidates: Array[Dictionary] = []
	for legacy: Dictionary in legacy_candidates:
		var legacy_key: String = _plan_key(
			str(legacy.get("action_type", "")), str(legacy.get("target_id", ""))
		)
		if not legacy_by_plan.has(legacy_key):
			legacy_by_plan[legacy_key] = []
		(legacy_by_plan[legacy_key] as Array).append(legacy)
		if str(legacy.get("action_type", "")) != "actor.move":
			candidates.append(_stationary_candidate(legacy, movement_context, profile))

	var goals_by_id: Dictionary = {}
	for goal_value: Variant in goals:
		var goal: Dictionary = goal_value as Dictionary
		goals_by_id[str(goal["goal_id"])] = goal
	for option_value: Variant in options:
		var option: Dictionary = option_value as Dictionary
		var goal: Dictionary = goals_by_id[str(option["goal_id"])] as Dictionary
		var plan: Dictionary = option["planned_action"] as Dictionary
		var matches: Array = legacy_by_plan.get(
			_plan_key(str(plan["type"]), str(plan["target_id"])), []
		) as Array
		if matches.is_empty():
			candidates.append(_route_candidate({}, plan, goal, option, movement_context, profile))
		else:
			for match_value: Variant in matches:
				candidates.append(_route_candidate(
					match_value as Dictionary,
					plan,
					goal,
					option,
					movement_context,
					profile
				))

	var spatial_cfg: Dictionary = _movement_cfg["spatial_utility"] as Dictionary
	for candidate: Dictionary in candidates:
		var plan: Dictionary = candidate["_movement_plan"] as Dictionary
		var score: float = _score(
			str(plan["type"]),
			actor,
			directive,
			board_summary,
			expression_band,
			calling_behavior,
			candidate,
			presence_strength,
			rank_strength,
			composure,
			judgment
		)
		if bool(candidate.get("_movement_route", false)):
			score += _spatial_utility(
				candidate["_movement_goal"] as Dictionary,
				candidate["_movement_option"] as Dictionary,
				directive,
				spatial_cfg
			)
		if not is_finite(score):
			return _movement_failure("non_finite_candidate_score", "candidates")
		candidate["_score"] = score

	var active_vow: Dictionary = context.get("active_vow", {}) as Dictionary
	if not active_vow.is_empty() and str(actor.get("faction", "")) == "echo":
		_apply_vow_bias(candidates, active_vow, int(context.get("party_size", 0)))
	var bonds_ctx: Array = context.get("bonds", []) as Array
	if not bonds_ctx.is_empty() and str(actor.get("faction", "")) == "echo":
		_apply_bond_bias(
			candidates,
			actor,
			bonds_ctx,
			context.get("bond_thresholds", {}) as Dictionary,
			context.get("bond_behavior_cfg", {}) as Dictionary
		)

	# Hard purifier authority remains last and exact after vow/bond adjustments.
	var purifier_ready: bool = bool(context.get("is_purifier", false)) \
		and bool(context.get("shrine_alive", false)) \
		and float(context.get("shrine_hp_ratio", 1.0)) < 0.5 \
		and int(actor.get("purify_cooldown", 0)) == 0
	if purifier_ready:
		for candidate: Dictionary in candidates:
			var plan: Dictionary = candidate["_movement_plan"] as Dictionary
			if str(plan["type"]) == "actor.purify_shrine":
				candidate["_score"] = 9999.0
	_append_legacy_purifier_candidate(candidates, context, actor, all_actors, movement_context, profile)
	for candidate: Dictionary in candidates:
		var final_score: Variant = candidate.get("_score", null)
		if not (final_score is int or final_score is float) or not is_finite(float(final_score)):
			return _movement_failure("non_finite_final_candidate_score", "candidates")

	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if float(left["_score"]) != float(right["_score"]):
			return float(left["_score"]) > float(right["_score"])
		var left_plan: Dictionary = left["_movement_plan"] as Dictionary
		var right_plan: Dictionary = right["_movement_plan"] as Dictionary
		if str(left_plan["type"]) != str(right_plan["type"]):
			return str(left_plan["type"]) < str(right_plan["type"])
		if str(left["_movement_goal_id"]) != str(right["_movement_goal_id"]):
			return str(left["_movement_goal_id"]) < str(right["_movement_goal_id"])
		return str(left["_movement_option_id"]) < str(right["_movement_option_id"])
	)

	# V2-PROG-012 Phase 4 fix: decision_scale + the directive_bonus-descending
	# ranking — same reasoning as select_intent()'s equivalent block above (see
	# `_rank_directive_candidates()` and its callers there for why there is no
	# separate "single top D" variable). `c["_score"]` here already includes
	# spatial_utility (route candidates) — that IS part of "how much the options
	# actually differed to her", so no special-casing is needed beyond excluding
	# the 9999.0 hard purifier override (set on candidates just above, before
	# this loop).
	# V2-PROG-012 Phase 5 fix: same faction == "echo" gate as select_intent()'s
	# equivalent block above — see that comment for the temporary-ally
	# (actor_type "enemy", faction "echo") reasoning and the miscalibration this
	# fixes. Gated before the per-candidate accumulation loop so non-echo actors
	# skip the whole probe at zero extra cost.
	var _is_echo_faction: bool = str(actor.get("faction", "")) == "echo"
	var _dbonus_by_type: Dictionary = {}
	var _repr_by_type: Dictionary = {}
	var _decision_scale: float = 0.0
	if _is_echo_faction:
		var _self_score_min: float = INF
		var _self_score_max: float = -INF
		for c: Dictionary in candidates:
			var _atype: String = str((c["_movement_plan"] as Dictionary)["type"])
			if not _dbonus_by_type.has(_atype):
				_dbonus_by_type[_atype] = _directive_bonus(_atype, directive, interpretation_width, calling_behavior)
				_repr_by_type[_atype] = c
			var _cbonus: float = float(_dbonus_by_type[_atype])
			var _cscore: float = float(c.get("_score", 0.0))
			if _cscore < 9999.0:
				var _cself_score: float = _cscore - _cbonus
				if _cself_score < _self_score_min:
					_self_score_min = _cself_score
				if _cself_score > _self_score_max:
					_self_score_max = _cself_score
		_decision_scale = (_self_score_max - _self_score_min) if _self_score_max >= _self_score_min else 0.0

	var winner: Dictionary = candidates[0]
	var intent: Dictionary = MovementIntentContract.build(
		str(movement_context["mover_id"]),
		str(movement_context["activation_id"]),
		str(winner["_movement_goal_id"]),
		str(winner["_movement_option_id"]),
		winner["_movement_path"] as Array,
		int(profile["capacity"]),
		int(winner["_movement_commitment"]),
		winner["_movement_plan"] as Dictionary,
		winner["_movement_fallback"] as Dictionary,
		winner["_movement_pressure_sources"] as Array
	)
	var intent_result: Dictionary = MovementIntentContract.validate(
		intent, movement_context["origin"] as Dictionary
	)
	if not bool(intent_result["valid"]):
		return _movement_failure(
			"invalid_selected_intent.%s" % str(intent_result["reason"]),
			str(intent_result["field"])
		)

	# V2-PROG-012 Phase 4: expose divergence-detection inputs alongside (NOT inside)
	# `intent` — MovementIntentContract.validate() enforces an EXACT field set on
	# `intent`, so any extra key attached there would fail validation and discard
	# the whole board (see select_movement_intent()'s doc comment on that hazard
	# class elsewhere in this file). `winner["_score"]` here already includes
	# spatial_utility/purifier-override adjustments applied above — that IS the
	# value this function's own winner-sort compared, so it is the correct `score`
	# to hand the detector. Skipped for hard score overrides (9999.0 sentinel).
	var _divergence_probe: Dictionary = {}
	var _winner_score: float = float(winner.get("_score", 0.0))
	if _is_echo_faction and _winner_score < 9999.0:
		var _w_plan: Dictionary = winner["_movement_plan"] as Dictionary
		var _w_action_type: String = str(_w_plan["type"])
		var _w_components: Dictionary = {}
		_score(_w_action_type, actor, directive, board_summary, expression_band, calling_behavior,
			winner, presence_strength, rank_strength, composure, judgment, _w_components)
		_divergence_probe = {
			"chosen": {
				"action_type":             _w_action_type,
				"target_id":               str(winner.get("target_id", "")),
				"score":                   _winner_score,
				"directive_bonus":         float(_dbonus_by_type.get(_w_action_type, 0.0)),
				# V2-PROG-012 Phase 6: interpretation_width=0.0 is the new "most literal"
				# floor (was band string "nascent" — see _directive_bonus()'s doc comment).
				"directive_bonus_nascent": _directive_bonus(_w_action_type, directive, 0.0, calling_behavior),
				"components":              _w_components,
			},
			# V2-PROG-012 Phase 4 fix: see select_intent()'s equivalent block for why
			# this is the full ranking, not just the single top D.
			"directive_candidates": _rank_directive_candidates(
				_dbonus_by_type, _repr_by_type, directive, calling_behavior
			),
			# V2-PROG-012 Phase 4 fix: see `_decision_scale` above.
			"decision_scale": _decision_scale,
		}

	return {"valid": true, "intent": intent, "reason": "", "field": "", "_divergence_probe": _divergence_probe}


func _validate_movement_inputs(
	context: Dictionary,
	movement_context: Dictionary,
	profile: Dictionary,
	goals: Array,
	options: Array
) -> Dictionary:
	if not context.get("actor", {}) is Dictionary:
		return _movement_failure("invalid_actor", "context.actor")
	if not context.get("all_actors", []) is Array:
		return _movement_failure("invalid_all_actors", "context.all_actors")
	if not context.get("directive", {}) is Dictionary:
		return _movement_failure("invalid_directive", "context.directive")
	if not context.get("calling_behavior", {}) is Dictionary:
		return _movement_failure("invalid_calling_behavior", "context.calling_behavior")
	for numeric_field: String in ["presence_strength", "rank_strength", "composure", "judgment"]:
		if context.has(numeric_field):
			var numeric_value: Variant = context[numeric_field]
			if not (numeric_value is int or numeric_value is float) or not is_finite(float(numeric_value)):
				return _movement_failure("invalid_context_number", "context.%s" % numeric_field)

	var movement_result: Dictionary = MovementContextContract.validate(movement_context)
	if not bool(movement_result["valid"]):
		return _movement_failure(
			"invalid_movement_context.%s" % str(movement_result["reason"]),
			str(movement_result["field"])
		)
	var profile_result: Dictionary = MovementProfileContract.validate(profile)
	if not bool(profile_result["valid"]):
		return _movement_failure(
			"invalid_profile.%s" % str(profile_result["reason"]),
			str(profile_result["field"])
		)
	if int(profile["capacity"]) <= 0:
		return _movement_failure("non_positive_capacity", "profile.capacity")
	var utility_result: Dictionary = _validate_spatial_utility_cfg()
	if not bool(utility_result["valid"]):
		return utility_result

	var actor: Dictionary = context["actor"] as Dictionary
	var actor_id: String = str(actor.get("id", ""))
	if actor_id.is_empty() or actor_id != str(movement_context["mover_id"]):
		return _movement_failure("mover_id_mismatch", "context.actor.id")
	if not actor.get("grid_pos", {}) is Dictionary \
			or (actor.get("grid_pos", {}) as Dictionary) != (movement_context["origin"] as Dictionary):
		return _movement_failure("mover_origin_mismatch", "context.actor.grid_pos")
	var mover_fact: Dictionary = {}
	for actor_value: Variant in movement_context["perceived_actors"] as Array:
		var fact: Dictionary = actor_value as Dictionary
		if str(fact["id"]) == actor_id:
			mover_fact = fact
			break
	if mover_fact.is_empty() or (mover_fact["position"] as Dictionary) != (movement_context["origin"] as Dictionary):
		return _movement_failure("mover_fact_mismatch", "movement_context.perceived_actors")
	var origin_key: String = _movement_cell_key(movement_context["origin"] as Dictionary)
	if str((movement_context["occupancy"] as Dictionary).get(origin_key, "")) != actor_id:
		return _movement_failure("mover_occupancy_mismatch", "movement_context.occupancy.%s" % origin_key)

	var spatial_result: Dictionary = _validate_spatial_config()
	if not bool(spatial_result["valid"]):
		return spatial_result
	var directive_result: Dictionary = _validate_spatial_directive(context.get("directive", {}) as Dictionary)
	if not bool(directive_result["valid"]):
		return directive_result

	var actor_context_result: Dictionary = _validate_perceived_actor_context(context, movement_context)
	if not bool(actor_context_result["valid"]):
		return actor_context_result

	var goals_by_id: Dictionary = {}
	var previous_goal: Dictionary = {}
	for goal_index: int in range(goals.size()):
		if not goals[goal_index] is Dictionary:
			return _movement_failure("invalid_goal_type", "goals.%d" % goal_index)
		var goal: Dictionary = goals[goal_index] as Dictionary
		var goal_result: Dictionary = MovementGoalContract.validate(
			goal, movement_context["origin"] as Dictionary
		)
		if not bool(goal_result["valid"]):
			return _movement_failure(
				"invalid_goal.%s" % str(goal_result["reason"]),
				"goals.%d.%s" % [goal_index, str(goal_result["field"])]
			)
		var goal_id: String = str(goal["goal_id"])
		if not goal_id.begins_with("goal."):
			return _movement_failure("invalid_goal_id", "goals.%d.goal_id" % goal_index)
		if goals_by_id.has(goal_id):
			return _movement_failure("duplicate_goal_id", "goals.%d.goal_id" % goal_index)
		if not previous_goal.is_empty() and _movement_goal_before(goal, previous_goal):
			return _movement_failure("non_canonical_goal_order", "goals.%d" % goal_index)
		for relevant_value: Variant in goal["relevant_actors"] as Array:
			if not _perceived_actor_ids(movement_context).has(str(relevant_value)):
				return _movement_failure("unknown_relevant_actor", "goals.%d.relevant_actors" % goal_index)
		for plan_field: String in ["planned_primary", "declared_fallback"]:
			var plan: Dictionary = goal[plan_field] as Dictionary
			if not plan.is_empty():
				var target_id: String = str(plan["target_id"])
				if not target_id.is_empty() and not _perceived_actor_ids(movement_context).has(target_id):
					return _movement_failure("unknown_plan_target", "goals.%d.%s.target_id" % [goal_index, plan_field])
		goals_by_id[goal_id] = goal
		previous_goal = goal

	var option_ids: Dictionary = {}
	var mechanics: Dictionary = {}
	var previous_goal_index: int = -1
	var previous_style_index: int = -1
	var previous_option_id: String = ""
	var option_counts_by_goal: Dictionary = {}
	for option_index: int in range(options.size()):
		if not options[option_index] is Dictionary:
			return _movement_failure("invalid_option_type", "options.%d" % option_index)
		var option: Dictionary = options[option_index] as Dictionary
		var option_result: Dictionary = MovementOptionContract.validate(
			option, movement_context["origin"] as Dictionary
		)
		if not bool(option_result["valid"]):
			return _movement_failure(
				"invalid_option.%s" % str(option_result["reason"]),
				"options.%d.%s" % [option_index, str(option_result["field"])]
			)
		var option_id: String = str(option["option_id"])
		if option_ids.has(option_id):
			return _movement_failure("duplicate_option_id", "options.%d.option_id" % option_index)
		option_ids[option_id] = true
		var goal_id: String = str(option["goal_id"])
		if not goals_by_id.has(goal_id):
			return _movement_failure("unknown_option_goal", "options.%d.goal_id" % option_index)
		option_counts_by_goal[goal_id] = int(option_counts_by_goal.get(goal_id, 0)) + 1
		var goal: Dictionary = goals_by_id[goal_id] as Dictionary
		if str(option["purpose"]) != str(goal["purpose"]):
			return _movement_failure("option_purpose_mismatch", "options.%d.purpose" % option_index)
		if int(option["capacity"]) != int(profile["capacity"]):
			return _movement_failure("option_capacity_mismatch", "options.%d.capacity" % option_index)
		if (option["planned_action"] as Dictionary) != (goal["planned_primary"] as Dictionary):
			return _movement_failure("option_action_mismatch", "options.%d.planned_action" % option_index)
		if (option["fallback"] as Dictionary) != (goal["declared_fallback"] as Dictionary):
			return _movement_failure("option_fallback_mismatch", "options.%d.fallback" % option_index)

		var goal_suffix: String = goal_id.trim_prefix("goal.")
		var option_prefix: String = "option.%s." % goal_suffix
		if not option_id.begins_with(option_prefix):
			return _movement_failure("option_id_goal_mismatch", "options.%d.option_id" % option_index)
		var option_remainder: String = option_id.trim_prefix(option_prefix)
		var style: String = option_remainder.get_slice(".", 0)
		var style_index: int = _MOVEMENT_STYLE_ORDER.find(style)
		if style_index < 0:
			return _movement_failure("invalid_option_style", "options.%d.option_id" % option_index)
		var goal_order_index: int = _goal_index(goals, goal_id)
		if goal_order_index < previous_goal_index \
				or (goal_order_index == previous_goal_index and style_index < previous_style_index) \
				or (goal_order_index == previous_goal_index and style_index == previous_style_index \
					and option_id < previous_option_id):
			return _movement_failure("non_canonical_option_order", "options.%d" % option_index)
		previous_goal_index = goal_order_index
		previous_style_index = style_index
		previous_option_id = option_id

		var mechanics_key: String = "%s|%s|%s" % [
			goal_id,
			_movement_cell_key(option["destination"] as Dictionary),
			_movement_path_key(option["path"] as Array),
		]
		if mechanics.has(mechanics_key) and (mechanics[mechanics_key] as Dictionary) != option:
			return _movement_failure("conflicting_duplicate_mechanics", "options.%d" % option_index)
		mechanics[mechanics_key] = option
	if goals.size() > 3:
		return _movement_failure("goal_cap_exceeded", "goals")
	var counted_goal_ids: Array = option_counts_by_goal.keys()
	counted_goal_ids.sort()
	for goal_id_value: Variant in counted_goal_ids:
		var counted_goal_id: String = str(goal_id_value)
		if int(option_counts_by_goal[counted_goal_id]) > 4:
			return _movement_failure("option_cap_exceeded", "options")
	return {"valid": true, "intent": {}, "reason": "", "field": ""}


func _validate_perceived_actor_context(context: Dictionary, movement_context: Dictionary) -> Dictionary:
	var all_actors: Array = context["all_actors"] as Array
	var canonical_actors: Array[Dictionary] = []
	var context_ids: Dictionary = {}
	var has_invalid_type: bool = false
	var has_empty_id: bool = false
	for actor_value: Variant in all_actors:
		if not actor_value is Dictionary:
			has_invalid_type = true
			continue
		var context_actor: Dictionary = actor_value as Dictionary
		var context_id: String = str(context_actor.get("id", ""))
		if context_id.is_empty():
			has_empty_id = true
			continue
		canonical_actors.append(context_actor)
		context_ids[context_id] = int(context_ids.get(context_id, 0)) + 1
	if has_invalid_type:
		return _movement_failure("invalid_all_actor_type", "context.all_actors")
	if has_empty_id:
		return _movement_failure("empty_all_actor_id", "context.all_actors.id")
	var actor_ids: Array = context_ids.keys()
	actor_ids.sort()
	for id_value: Variant in actor_ids:
		var context_id: String = str(id_value)
		if int(context_ids[context_id]) > 1:
			return _movement_failure("duplicate_all_actor_id", "context.all_actors.%s.id" % context_id)
	canonical_actors.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["id"]) < str(right["id"])
	)
	var facts_by_id: Dictionary = _perceived_facts_by_id(movement_context)
	var mover: Dictionary = context["actor"] as Dictionary
	var mover_result: Dictionary = _crosscheck_perceived_actor(mover, facts_by_id[str(mover["id"])] as Dictionary, "context.actor")
	if not bool(mover_result["valid"]):
		return mover_result
	for context_actor: Dictionary in canonical_actors:
		var context_id: String = str(context_actor["id"])
		if not facts_by_id.has(context_id):
			continue
		var result: Dictionary = _crosscheck_perceived_actor(
			context_actor,
			facts_by_id[context_id] as Dictionary,
			"context.all_actors.%s" % context_id
		)
		if not bool(result["valid"]):
			return result
	return {"valid": true, "intent": {}, "reason": "", "field": ""}


func _crosscheck_perceived_actor(actor: Dictionary, fact: Dictionary, field: String) -> Dictionary:
	if not actor.get("grid_pos", {}) is Dictionary or (actor.get("grid_pos", {}) as Dictionary) != (fact["position"] as Dictionary):
		return _movement_failure("perceived_actor_position_mismatch", "%s.grid_pos" % field)
	var actor_is_dead: bool = bool(actor.get("is_dead", false))
	var actor_is_ko: bool = bool(actor.get("is_ko", false))
	if not actor.has("is_ko") and actor.has("current_hp"):
		actor_is_ko = int(actor["current_hp"]) <= 0 and not actor_is_dead
	for state_pair: Array in [
		["is_dead", actor_is_dead],
		["is_ko", actor_is_ko],
		["is_structure", bool(actor.get("is_structure", false))],
		["is_spirit", bool(actor.get("is_spirit", false))],
		["is_quarry", bool(actor.get("is_quarry", false))],
		# MovementPerceivedActorFact.validate rejects `incapable_actor_cannot_control`:
		# a dead/KO'd/structure actor may never assert controlling_state. Mirror the same
		# conjunction FlowRuntime._movement_actor_facts derives, or every board containing
		# a structure or a downed actor fails the cross-check.
		[
			"controlling_state",
			bool(actor.get("controlling_state", true)) \
				and not actor_is_dead \
				and not actor_is_ko \
				and not bool(actor.get("is_structure", false)),
		],
	]:
		if bool(fact[str(state_pair[0])]) != bool(state_pair[1]):
			return _movement_failure("perceived_actor_state_mismatch", "%s.%s" % [field, str(state_pair[0])])
	var actor_kind: String = "structure" if bool(actor.get("is_structure", false)) else str(actor.get("kind", actor.get("actor_type", "")))
	if actor_kind != str(fact["kind"]):
		return _movement_failure("perceived_actor_kind_mismatch", "%s.kind" % field)
	if not is_equal_approx(_hp_ratio(actor), float(fact["health_ratio"])):
		return _movement_failure("perceived_actor_health_mismatch", "%s.health_ratio" % field)
	return {"valid": true, "intent": {}, "reason": "", "field": ""}


func _canonical_perceived_actors(context: Dictionary, movement_context: Dictionary) -> Array:
	var perceived_ids: Dictionary = _perceived_actor_ids(movement_context)
	var result: Array = []
	for actor_value: Variant in context["all_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		if perceived_ids.has(str(actor["id"])):
			result.append(actor)
	result.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary)["id"]) < str((right as Dictionary)["id"])
	)
	return result


static func _perceived_facts_by_id(movement_context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for fact_value: Variant in movement_context["perceived_actors"] as Array:
		var fact: Dictionary = fact_value as Dictionary
		result[str(fact["id"])] = fact
	return result


static func _perceived_actor_ids(movement_context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for fact_value: Variant in movement_context["perceived_actors"] as Array:
		result[str((fact_value as Dictionary)["id"])] = true
	return result


func _validate_spatial_config() -> Dictionary:
	if not _movement_cfg.has("spatial_utility") or not _movement_cfg["spatial_utility"] is Dictionary:
		return _movement_failure("missing_spatial_utility", "movement_cfg.spatial_utility")
	var config: Dictionary = _movement_cfg["spatial_utility"] as Dictionary
	for field: String in _SPATIAL_UTILITY_FIELDS:
		if not config.has(field):
			return _movement_failure("missing_spatial_config_field", "movement_cfg.spatial_utility.%s" % field)
		var value: Variant = config[field]
		if not (value is int or value is float):
			return _movement_failure("invalid_spatial_config_type", "movement_cfg.spatial_utility.%s" % field)
		if not is_finite(float(value)):
			return _movement_failure("non_finite_spatial_config", "movement_cfg.spatial_utility.%s" % field)
	var keys: Array = config.keys()
	keys.sort()
	for key_value: Variant in keys:
		var key: String = str(key_value)
		if not _SPATIAL_UTILITY_FIELDS.has(key):
			return _movement_failure("unexpected_spatial_config_field", "movement_cfg.spatial_utility.%s" % key)
	if float(config["cap"]) <= 0.0:
		return _movement_failure("non_positive_spatial_cap", "movement_cfg.spatial_utility.cap")
	return {"valid": true, "intent": {}, "reason": "", "field": ""}


func _validate_spatial_directive(directive: Dictionary) -> Dictionary:
	if not directive.has("intent_weights"):
		return {"valid": true, "intent": {}, "reason": "", "field": ""}
	if not directive["intent_weights"] is Dictionary:
		return _movement_failure("invalid_directive_weights", "context.directive.intent_weights")
	var weights: Dictionary = directive["intent_weights"] as Dictionary
	for key: String in [
		"objective_advance_priority", "avoid_overcommit", "exposure_acceptance",
		"ally_protection_bias", "threat_interception",
	]:
		if not weights.has(key):
			continue
		var value: Variant = weights[key]
		if not (value is int or value is float) or not is_finite(float(value)):
			return _movement_failure("invalid_directive_weight", "context.directive.intent_weights.%s" % key)
	return {"valid": true, "intent": {}, "reason": "", "field": ""}


func _stationary_candidate(
	legacy: Dictionary,
	movement_context: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var plan: Dictionary = MovementActionPlanContract.from_legacy_candidate(legacy)
	var result: Dictionary = legacy.duplicate(true)
	_apply_stationary_identity(result, plan, movement_context, profile)
	return result


func _route_candidate(
	legacy: Dictionary,
	plan: Dictionary,
	goal: Dictionary,
	option: Dictionary,
	movement_context: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var candidate: Dictionary = legacy.duplicate(true)
	if candidate.is_empty():
		candidate = (plan["payload"] as Dictionary).duplicate(true)
	candidate["action_type"] = str(plan["type"])
	candidate["target_id"] = str(plan["target_id"])
	if legacy.is_empty():
		_add_perceived_target_health(candidate, movement_context)
	candidate["_movement_plan"] = plan.duplicate(true)
	candidate["_movement_goal"] = goal
	candidate["_movement_option"] = option
	candidate["_movement_route"] = true
	candidate["_movement_goal_id"] = str(goal["goal_id"])
	candidate["_movement_option_id"] = str(option["option_id"])
	candidate["_movement_path"] = (option["path"] as Array).duplicate(true)
	candidate["_movement_commitment"] = int(option["commitment"])
	candidate["_movement_fallback"] = (option["fallback"] as Dictionary).duplicate(true)
	candidate["_movement_pressure_sources"] = (goal["pressure_sources"] as Array).duplicate(true)
	if (option["path"] as Array).is_empty():
		_apply_stationary_identity(candidate, plan, movement_context, profile)
	return candidate


func _add_perceived_target_health(candidate: Dictionary, movement_context: Dictionary) -> void:
	var target_id: String = str(candidate.get("target_id", ""))
	if target_id.is_empty():
		return
	var facts: Dictionary = _perceived_facts_by_id(movement_context)
	if facts.has(target_id):
		candidate["target_hp_ratio"] = float((facts[target_id] as Dictionary)["health_ratio"])


func _apply_stationary_identity(
	candidate: Dictionary,
	plan: Dictionary,
	movement_context: Dictionary,
	profile: Dictionary
) -> void:
	var origin: Dictionary = movement_context["origin"] as Dictionary
	var action_token: String = str(plan["type"]).replace(".", "_")
	var anchor: String = "c%dr%d" % [int(origin["col"]), int(origin["row"])]
	var goal_id: String = "goal.legacy.stationary.%s.%s" % [action_token, anchor]
	candidate["_movement_plan"] = plan.duplicate(true)
	candidate["_movement_goal"] = {}
	candidate["_movement_option"] = {}
	candidate["_movement_route"] = false
	candidate["_movement_goal_id"] = goal_id
	candidate["_movement_option_id"] = "%s.stationary.d%dr%d.pstay" % [
		goal_id, int(origin["col"]), int(origin["row"]),
	]
	candidate["_movement_path"] = []
	candidate["_movement_commitment"] = 0
	candidate["_movement_fallback"] = {}
	candidate["_movement_pressure_sources"] = []
	candidate["capacity"] = int(profile["capacity"])


func _append_legacy_purifier_candidate(
	candidates: Array[Dictionary],
	context: Dictionary,
	actor: Dictionary,
	all_actors: Array,
	movement_context: Dictionary,
	profile: Dictionary
) -> void:
	if not context.get("is_purifier", false) \
			or not context.get("shrine_alive", false) \
			or float(context.get("shrine_hp_ratio", 1.0)) >= 0.5 \
			or int(actor.get("purify_cooldown", 0)) != 0:
		return
	var my_pos: Dictionary = actor.get("grid_pos", {}) as Dictionary
	for actor_value: Variant in all_actors:
		if actor_value is Dictionary:
			var other: Dictionary = actor_value as Dictionary
			if other.get("is_structure", false) and not other.get("is_dead", false):
				if GridService.is_adjacent(my_pos, other.get("grid_pos", {})):
					var candidate: Dictionary = _stationary_candidate(
						{"action_type": "actor.purify_shrine", "target_id": "", "priority": 1.0},
						movement_context,
						profile
					)
					candidate["_score"] = 9999.0
					candidates.append(candidate)
				return


func _spatial_utility(
	goal: Dictionary,
	option: Dictionary,
	directive: Dictionary,
	config: Dictionary
) -> float:
	var urgency: float = clampf(float(goal["urgency"]), 0.0, 1.0)
	var progress: float = clampf(float(option["objective_progress"]), 0.0, 1.0)
	var cohesion: float = clampf(float(option["cohesion"]), 0.0, 1.0)
	var exposure: float = clampf(float(option["exposure"]), 0.0, 1.0)
	var congestion: float = clampf(float(option["congestion"]), 0.0, 1.0)
	# V2-COMBAT-002 Slice 6E: guard the capacity division. capacity == 0 with
	# commitment == 0 yields 0.0/0.0 = NAN, which propagates through the weighted sum
	# and fails `non_finite_candidate_score` — discarding the WHOLE board, not just this
	# option. Latent today (balance.json pins capacity.floor = 2 and structures are
	# excluded upstream), but it is a data-shape assumption enforced by config rather
	# than by code. A zero-capacity mover can commit nothing, so the ratio is 0.0.
	var option_capacity: float = float(option["capacity"])
	var commitment_ratio: float = 0.0
	if option_capacity > 0.0:
		commitment_ratio = clampf(float(option["commitment"]) / option_capacity, 0.0, 1.0)
	var weights: Dictionary = directive.get("intent_weights", {}) as Dictionary
	var objective_advance: float = clampf(
		float(weights.get("objective_advance_priority", 0.0)), -1.0, 1.0
	)
	var avoid_overcommit: float = clampf(
		float(weights.get("avoid_overcommit", 0.0)), -1.0, 1.0
	)
	var exposure_acceptance: float = clampf(
		float(weights.get("exposure_acceptance", 0.0)), -1.0, 1.0
	)
	var ally_protection: float = clampf(
		float(weights.get("ally_protection_bias", 0.0)), -1.0, 1.0
	)
	var threat_interception: float = clampf(
		float(weights.get("threat_interception", 0.0)), -1.0, 1.0
	)
	var purpose: String = str(goal["purpose"])
	var protects: float = 1.0 if purpose in ["protect", "intercept", "escort"] else 0.0
	var intercepts: float = 1.0 if purpose in ["intercept", "cut_off"] else 0.0
	var raw: float = (
		float(config["urgency_weight"]) * urgency
		+ float(config["objective_progress_weight"]) * progress
		+ float(config["cohesion_weight"]) * cohesion
		+ float(config["exposure_weight"]) * exposure
		+ float(config["congestion_weight"]) * congestion
		+ float(config["commitment_weight"]) * commitment_ratio
		+ float(config["directive_objective_advance_weight"]) * objective_advance * progress
		+ float(config["directive_avoid_overcommit_weight"]) * avoid_overcommit * (1.0 - commitment_ratio)
		+ float(config["directive_exposure_acceptance_weight"]) * exposure_acceptance * exposure
		+ float(config["directive_ally_protection_weight"]) * ally_protection * protects
		+ float(config["directive_threat_interception_weight"]) * threat_interception * intercepts
	)
	var cap: float = float(config["cap"])
	return clampf(raw, -cap, cap)


static func _movement_goal_before(left: Dictionary, right: Dictionary) -> bool:
	if float(left["urgency"]) != float(right["urgency"]):
		return float(left["urgency"]) > float(right["urgency"])
	return str(left["goal_id"]) < str(right["goal_id"])


static func _goal_index(goals: Array, goal_id: String) -> int:
	for index: int in range(goals.size()):
		if str((goals[index] as Dictionary)["goal_id"]) == goal_id:
			return index
	return -1


static func _plan_key(action_type: String, target_id: String) -> String:
	return "%s\u001f%s" % [action_type, target_id]


static func _movement_cell_key(position: Dictionary) -> String:
	return "%d,%d" % [int(position["col"]), int(position["row"])]


static func _movement_path_key(path: Array) -> String:
	var keys: Array[String] = []
	for cell_value: Variant in path:
		keys.append(_movement_cell_key(cell_value as Dictionary))
	return ">".join(keys)


static func _movement_failure(reason: String, field: String) -> Dictionary:
	return {"valid": false, "intent": {}, "reason": reason, "field": field}


static func _candidate_target_key(candidate: Dictionary) -> String:
	var target: Dictionary = candidate.get("target_pos", {}) as Dictionary
	if target.is_empty():
		return ""
	return _movement_cell_key(target)


func _validate_spatial_utility_cfg() -> Dictionary:
	if not _movement_cfg.has("spatial_utility"):
		return _movement_failure("missing_spatial_utility_config", "movement_cfg.spatial_utility")
	var spatial: Variant = _movement_cfg["spatial_utility"]
	if not (spatial is Dictionary):
		return _movement_failure("invalid_spatial_utility_config", "movement_cfg.spatial_utility")
	var spatial_cfg: Dictionary = spatial as Dictionary
	for field_value: Variant in _SPATIAL_UTILITY_FIELDS:
		var field: String = str(field_value)
		if not spatial_cfg.has(field):
			return _movement_failure("missing_spatial_utility_field", "movement_cfg.spatial_utility.%s" % field)
		var value: Variant = spatial_cfg[field]
		if not (value is int or value is float) or not is_finite(float(value)):
			return _movement_failure("invalid_spatial_utility_field", "movement_cfg.spatial_utility.%s" % field)
	return {"valid": true, "intent": {}, "reason": "", "field": ""}


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

	# V2-COMBAT-002 Slice 6B: exact-cell PURIFY/PROTECT/PURSUE redirects were
	# retired. Pressure regions now describe objective movement; this candidate
	# generator only supplies ordinary action-score vocabulary.
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
	if actor_type == "enemy" \
			and (expression_band == "forming" or expression_band == "grounded" or expression_band == "whole"):
		nearest_enemy = _get_most_wounded_enemy(actor, all_actors)
		if nearest_enemy.is_empty():
			nearest_enemy = ActorService.get_nearest_enemy(actor, all_actors)
	else:
		nearest_enemy = ActorService.get_nearest_enemy(actor, all_actors)

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
	#
	# COMBAT-BUG-002: guard candidate suppression after consecutive guard turns.
	# Guard is a passive action (fear never dampens it), and broken morale adds +20 guard / -20 melee.
	# Under sustained hits that add fear but deal 0 damage (guard doubles def), the score gap
	# widens every round until guard wins permanently → combat never resolves → actor.refuse.
	# Score-based penalties alone are insufficient: for high-guard callings (onyamesu base=55)
	# the morale swing (+40 net) cannot be reliably overcome without over-correcting for other echoes.
	#
	# Hard rule: if the echo guarded last round and HP is not critical (> 20%), suppress guard.
	# This works for ALL callings and morale/fear states. At critical HP (≤ 20%) guard remains
	# available so a dying echo can try to survive rather than being forced to attack.
	var guard_range: int = int(_cfg_get("guard_range"))
	if not nearest_enemy.is_empty() and enemy_dist <= guard_range:
		var allow_guard: bool = true
		if actor_type == "echo":
			var last_i_g_v: Variant = actor.get("last_intent", {})
			var last_i_g: Dictionary = last_i_g_v if last_i_g_v is Dictionary else {}
			if str(last_i_g.get("action_type", "")) == "actor.guard":
				# Suppress unless critically wounded — dying echoes may legitimately need to guard.
				var crit_threshold: float = float(
					(_cfg_get("situational_muls") as Dictionary).get("own_hp_critical", {}).get("threshold", 0.20)
				)
				allow_guard = _hp_ratio(actor) <= crit_threshold
		if allow_guard:
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
## objective_modes_cfg: data.combat.objective_modes, supplied per turn through
## context["objective_modes_cfg"] (this class holds no ConfigService by design). Empty {} falls
## back to the hardcoded defaults below.
func _build_board_summary(actor: Dictionary, all_actors: Array, _board_cfg: Dictionary, expression_band: String = "nascent", resolution_mode: String = "", objective_modes_cfg: Dictionary = {}) -> Dictionary:
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

	# COMBAT-BUG-002: repeated_guard_penalty — fires when echo guarded last round AND enemy is adjacent.
	# Works in tandem with candidate suppression in _generate_candidates():
	# - Suppression (hard): guard removed from candidate pool → echo cannot guard again consecutively.
	# - This penalty (soft): on the suppressed turn, melee_attack gets +15 over idle/protect_ally,
	#   ensuring the echo attacks rather than idling. Also fires when guard re-enters the pool
	#   (HP critical exception) to moderately discourage it vs melee.
	if actor_type == "echo" and enemy_dist <= 1:
		var last_i_rg_v: Variant = actor.get("last_intent", {})
		var last_i_rg: Dictionary = last_i_rg_v if last_i_rg_v is Dictionary else {}
		if str(last_i_rg.get("action_type", "")) == "actor.guard":
			active.append("repeated_guard_penalty")


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

	# §5-A: objective_in_range — RECOVER holder dig-in.
	# Fires when: mode==recover, actor is echo, AND actor is adjacent (Chebyshev==1) to a living
	# is_structure actor (the relic). Config row down-weights move/idle so the holder stays put.
	if resolution_mode == "recover" and actor_type == "echo":
		for a_v in all_actors:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v
			if a.get("is_structure", false) and not a.get("is_dead", false):
				if GridService.is_adjacent(my_pos, a.get("grid_pos", {})):
					active.append("objective_in_range")
				break

	# §5-B: objective_threatened — PROTECT interpose.
	# Fires when: mode==protect, actor is echo, AND a living is_structure totem exists with
	# a living enemy within objective_threatened_radius (Chebyshev, default 3).
	if resolution_mode == "protect" and actor_type == "echo":
		var protect_radius: int = 3  # default when no objective_modes config is supplied
		var om_protect_v: Variant = objective_modes_cfg.get("protect", {})
		var om_protect: Dictionary = om_protect_v if om_protect_v is Dictionary else {}
		if om_protect.has("objective_threatened_radius"):
			protect_radius = int(om_protect["objective_threatened_radius"])
		var totem_pos_pt: Dictionary = {}
		for a_v in all_actors:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v
			if a.get("is_structure", false) and not a.get("is_dead", false):
				totem_pos_pt = a.get("grid_pos", {})
				break
		if not totem_pos_pt.is_empty():
			for a_v in all_actors:
				if not (a_v is Dictionary):
					continue
				var a: Dictionary = a_v
				if a.get("is_dead", false) or a.get("is_structure", false):
					continue
				if str(a.get("faction", "")) == "enemy":
					if GridService.chebyshev_distance(totem_pos_pt, a.get("grid_pos", {})) <= protect_radius:
						active.append("objective_threatened")
						break

	# §5-C: quarry_near_exit — PURSUE interception urgency.
	# Fires when: mode==pursue, actor is echo, AND the living quarry is within threshold of a board edge.
	if resolution_mode == "pursue" and actor_type == "echo":
		var _qne_threshold: int = 3  # default when no objective_modes config is supplied
		var _om_pursue_v: Variant = objective_modes_cfg.get("pursue", {})
		var _om_pursue: Dictionary = _om_pursue_v if _om_pursue_v is Dictionary else {}
		if _om_pursue.has("quarry_near_exit_threshold"):
			_qne_threshold = int(_om_pursue["quarry_near_exit_threshold"])
		var _qne_board_w: int = int(_board_cfg.get("board_cols", 10))
		var _qne_board_h: int = int(_board_cfg.get("board_rows", 10))
		for a_v in all_actors:
			if not (a_v is Dictionary): continue
			var a_qne: Dictionary = a_v
			if bool(a_qne.get("is_quarry", false)) and not bool(a_qne.get("is_dead", false)):
				var _qne_p: Dictionary = a_qne.get("grid_pos", {})
				var _qne_col: int = int(_qne_p.get("col", 0))
				var _qne_row: int = int(_qne_p.get("row", 0))
				var _qne_dist: int = mini(
					mini(_qne_col, _qne_row),
					mini(_qne_board_w - 1 - _qne_col, _qne_board_h - 1 - _qne_row)
				)
				if _qne_dist <= _qne_threshold:
					active.append("quarry_near_exit")
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
	candidate: Dictionary = {},
	presence_strength: float = 0.1,  # V2-PROG-010
	# V2-PROG-010; DEAD as of V2-PROG-012 Phase 6 — identity weight scaling below now
	# reads `judgment` (via interpretation_width), not rank_strength (see DEFECT 2:
	# rank_strength and expression_band were two independently-authored levers that
	# both derived from raw rank alone, silently doubling the identity-vs-directive
	# swing). Kept in the signature for positional-call compatibility with existing
	# callers (same retirement pattern as presence_strength above, which BehaviorArbiter
	# has never read in _score()'s body).
	rank_strength: float = 0.0,
	# V2-PROG-012 Phase 2: default approximates a mid-band actor under the
	# balance.json composure weights (rank_strength_weight 0.36 + trait_balance_weight
	# 0.37 at ~0.5 each, no vow, no fear spike ≈ 0.365, rounded to 0.4) — an omitted
	# argument degrades to "average composure" rather than the floor (0.0, full
	# dampen) or the ceiling (1.0, no dampen).
	composure: float = 0.4,
	# V2-PROG-012 Phase 6 (DEFECT 2 fix): judgment — the sole driver of
	# interpretation_width, computed just below. See select_intent()'s doc comment
	# on this parameter for the default's derivation; threaded identically here.
	judgment: float = 0.3,
	# V2-PROG-012 Phase 4: optional out-param — when a non-null Dictionary is
	# passed, this call fills it with the raw per-term breakdown (base, trait_bonus,
	# vector_bonus, archetype_bonus, morale_bonus, fear_factor, calling_mul,
	# directive_bonus, situational_bonus) used to compute the returned float.
	# Purely additive reporting: does not alter the returned score. Consumed by
	# DivergenceDetector (via select_intent()/select_movement_intent()) to name the
	# dominant term as `primary_reason` — never read by anything inside this file.
	out_components: Dictionary = {}
) -> float:
	var _confirmed_calling: String = str(actor.get("calling", ""))
	var calling_origin: String = _confirmed_calling \
		if not _confirmed_calling.is_empty() and _confirmed_calling != "uncalled" \
		else str(actor.get("calling_origin", "uncalled"))
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

	# V2-PROG-012 Phase 6 (DEFECT 2 fix): interpretation_width is the SINGLE continuous
	# axis both identity weighting (here) and directive literalism (_directive_bonus(),
	# Section 6 below) now key on — derived from `judgment` (Phase 1, continuous 0-1,
	# GDD:1360's "how strongly the Echo can hold, interpret, and assert self under
	# pressure"). Previously these were two independently-authored levers that BOTH
	# derived from raw rank (rank_strength here, expression_band in Section 6) with no
	# knowledge of each other — since expression_band is itself rank-derived
	# (band_by_standing), the two moved in lockstep and silently doubled the
	# identity-vs-directive swing (~2.8x from Rank 1 to Whole; see data.maturity_expression
	# identity_weight_scale/directive_interpretation_mul _comment for the budget this
	# now respects). Keying on judgment instead of the band string also fixes the
	# rank 6-9 saturation: band_by_standing pins everything above rank 5 to "whole"
	# while rank_strength kept climbing to rank 9 — judgment has no such plateau.
	var interpretation_width: float = clampf(judgment, 0.0, 1.0)
	# V2-PROG-010: identity weight scaling — trait and vector contributions amplify
	# with interpretation_width. At interpretation_width=0.0: scale=1.0x (baseline).
	# At interpretation_width=1.0: scale=1.0+identity_weight_scale.
	var id_scale: Dictionary = _cfg_get("identity_weight_scale")
	trait_bonus  *= 1.0 + interpretation_width * float(id_scale.get("trait",  0.6))
	vector_bonus *= 1.0 + interpretation_width * float(id_scale.get("vector", 0.6))

	# 3b. Archetype bonus — flat constant lookup by archetype_birth string (not a continuous score).
	#     Encodes personality combat tendency (combat_bias): aggressive→melee/move, steadfast→guard, etc.
	var arch_tables: Dictionary = _cfg_get("archetype_action_muls")
	var a_row: Dictionary       = arch_tables.get(action_type, {})
	var archetype: String       = str(actor.get("archetype_birth", ""))
	var archetype_bonus: float  = float(a_row.get(archetype, 0.0))

	# 4. Fear factor: dampens active intents; passive intents (actor.idle) are unaffected.
	# V2-PROG-012 Phase 2: composure — fear disrupts scoring less for more composed
	# Echoes (lower effective dampen). Composure blends rank, vow state, trait balance,
	# and both fear dimensions (GDD:1369) — it is the real driver, not raw rank alone.
	var passive_actions: Array = _cfg_get("fear_passive_actions")
	var fear_factor: float     = 1.0
	if action_type not in passive_actions:
		var dampen: float   = float(_cfg_get("fear_active_dampen"))
		var d_scale: float  = float((_cfg_get("composure_dampen_scale") as Dictionary).get("value", 0.4))
		var eff_dampen: float = dampen * (1.0 - composure * d_scale)
		fear_factor = clamp(1.0 - (fear / 100.0) * eff_dampen, 0.0, 1.0)

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
	# V2-PROG-012 Phase 6: pass interpretation_width (not expression_band — see the
	# doc comment above the identity-weight-scaling block) + calling_behavior for mul
	# modulation.
	var directive_bonus: float = _directive_bonus(action_type, directive, interpretation_width, calling_behavior)

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

	var situational_bonus: float = _situational_bonus(action_type, board_summary)

	# V2-PROG-012 Phase 4: directive_bonus is a FLAT ADDITIVE term OUTSIDE the
	# fear/calling bracket — this is what makes the Directive's entire contribution
	# to this candidate's score algebraically separable at zero cost:
	# self_score(c) = c._score - directive_bonus(c) recovers "the Echo's own
	# judgment with the Directive's voice removed" by simple subtraction, with no
	# re-scoring needed. DivergenceDetector.gd depends on this exact placement.
	# Do NOT "tidy" directive_bonus inside the bracket — that would destroy the
	# separability this phase's detection (V2-PROG-012 Phase 4) is built on.
	out_components["base"]              = base
	out_components["trait_bonus"]       = trait_bonus
	out_components["vector_bonus"]      = vector_bonus
	out_components["archetype_bonus"]   = archetype_bonus
	out_components["morale_bonus"]      = morale_bonus
	out_components["fear_factor"]       = fear_factor
	out_components["calling_mul"]       = calling_mul
	out_components["directive_bonus"]   = directive_bonus
	out_components["situational_bonus"] = situational_bonus

	return (base + trait_bonus + vector_bonus + archetype_bonus + morale_bonus) * fear_factor * calling_mul + directive_bonus + situational_bonus


## Maps directive semantic intent_weights keys → action bonus.
## Uses directive_action_muls translation table (balance.json) so new directive keys
## and new action types can be added without touching this function.
## V2-PROG-010: expression_band and calling_behavior modulate the effective bonus.
## V2-PROG-012 Phase 6 (DEFECT 2 fix): `interpretation_width` (0.0-1.0, derived from
## `judgment` — see _score()'s doc comment on the identity-weight-scaling block)
## replaces `expression_band` as the directive-literalism driver. At
## interpretation_width=0.0 (lowest judgment) the directive is followed most
## literally (dir_mul_high); at 1.0 (highest judgment) it is weighted least
## (dir_mul_low) — a straight lerp between the two bounds, preserving the exact
## endpoints the old per-band table used at its extremes (nascent 1.30, whole
## 0.75). The old `directive_band_mul` per-band table is REMOVED (not kept as a
## documented-but-dead equivalence table) — see data.maturity_expression's
## `directive_interpretation_mul` _comment for why band-keyed steps were retired
## outright rather than shimmed: continuous interpretation_width is what fixes
## both the unbudgeted swing AND the rank 6-9 saturation (band_by_standing pins
## everything above rank 5 to "whole", so a band-keyed table would still plateau
## there even after this rename).
func _directive_bonus(action_type: String, directive: Dictionary, interpretation_width: float = 0.0, calling_behavior: Dictionary = {}) -> float:
	if directive.is_empty():
		return 0.0

	var dir_weights: Dictionary  = directive.get("intent_weights", {})
	if dir_weights.is_empty():
		return 0.0

	var dir_muls_table: Dictionary = _cfg_get("directive_action_muls")
	var d_row: Dictionary          = dir_muls_table.get(action_type, {})
	var base_bonus: float          = float(_cfg_get("directive_base_bonus"))

	# V2-PROG-010: calling directive_mul (wiring existing config — was declared but never applied)
	var call_dir_mul: float = float(calling_behavior.get("directive_mul", 1.0))
	# V2-PROG-012 Phase 6: continuous interpretation-width directive modulation —
	# low judgment follows literally (dir_mul_high), high judgment interprets
	# independently (dir_mul_low). Replaces the old per-band table (directive_band_mul).
	var interp_cfg: Dictionary  = _cfg_get("directive_interpretation_mul") as Dictionary
	var dir_mul_low: float      = float(interp_cfg.get("low", 0.75))
	var dir_mul_high: float     = float(interp_cfg.get("high", 1.30))
	var dir_mul: float          = lerpf(dir_mul_high, dir_mul_low, clampf(interpretation_width, 0.0, 1.0))
	base_bonus = base_bonus * call_dir_mul * dir_mul

	var bonus: float = 0.0

	# Generic loop: for each semantic key that boosts this action_type,
	# add the directive's weight for that key × directive_base_bonus.
	for semantic_key: String in d_row:
		var dir_weight: float = float(dir_weights.get(semantic_key, 0.0))
		bonus += dir_weight * float(d_row[semantic_key]) * base_bonus

	return bonus


## V2-PROG-012 Phase 4 fix: turns the per-type directive_bonus cache built by
## select_intent()/select_movement_intent()'s D-search loop into a full ranking,
## descending by directive_bonus, deterministic tie-break by action_type string.
## Pure reporting — this function has no notion of "ignored" action types; that
## POLICY decision (Part B — a passive directive preference like actor.idle isn't
## something an acting Echo can defy, so DivergenceDetector.gd falls through past
## it to the next entry here) stays entirely inside DivergenceDetector.gd.
func _rank_directive_candidates(
	dbonus_by_type: Dictionary,
	repr_by_type: Dictionary,
	directive: Dictionary,
	calling_behavior: Dictionary
) -> Array:
	var type_keys: Array = dbonus_by_type.keys()
	type_keys.sort_custom(func(a, b) -> bool:
		var ba: float = float(dbonus_by_type[a])
		var bb: float = float(dbonus_by_type[b])
		if ba != bb:
			return ba > bb
		return str(a) < str(b)
	)
	var ranked: Array = []
	for atype_v: Variant in type_keys:
		var atype: String = str(atype_v)
		var repr_candidate: Dictionary = repr_by_type[atype] as Dictionary
		ranked.append({
			"action_type":             atype,
			"target_id":               str(repr_candidate.get("target_id", "")),
			"score":                   float(repr_candidate.get("_score", 0.0)),
			"directive_bonus":         float(dbonus_by_type[atype]),
			# V2-PROG-012 Phase 6: interpretation_width=0.0 is the new "most literal"
			# floor (was band string "nascent" — see _directive_bonus()'s doc comment).
			"directive_bonus_nascent": _directive_bonus(atype, directive, 0.0, calling_behavior),
		})
	return ranked


## Config accessor — falls back to _DEFAULTS when _cfg is empty or key is missing.
func _cfg_get(key: String) -> Variant:
	if _cfg.has(key):
		return _cfg[key]
	return _DEFAULTS[key]


## V2-PROG-012 Phase 6 Item 2 — config-integrity helper (DEFECT 2's actual fix
## mechanism): computes the authored identity:directive ratio AT interpretation_width
## = 1.0, the point where both terms hit their extreme (identity's amplification
## ceiling, directive's literalism floor) and the ratio is largest. Pure — no
## BehaviorArbiter instance needed, so a test can call this directly against
## data/balance.json's raw config dicts without spinning up an actor/candidate/
## score pipeline.
##
##   identity_mul_at_1  = 1.0 + max(identity_weight_scale.trait, identity_weight_scale.vector)
##   directive_mul_at_1 = directive_interpretation_mul.low (the lerp's low bound —
##                        reached exactly at interpretation_width=1.0)
##   ratio = identity_mul_at_1 / directive_mul_at_1
##
## This is what silently doubled under the pre-fix defect: identity_weight_scale
## and directive_interpretation_mul (nee directive_band_mul) were both authored
## independently by rank/band, with nothing checking their COMBINED effect. The
## companion test (tests/BehaviorArbiterTests.gd) fails loudly if a future tuning
## pass raises identity_weight_scale or lowers directive_interpretation_mul.low
## without also raising interpretation_swing_max to match — the two config blocks
## can no longer drift apart unnoticed.
static func compute_interpretation_swing(
	identity_weight_scale: Dictionary,
	directive_interpretation_mul: Dictionary
) -> float:
	var max_identity_scale: float = maxf(
		float(identity_weight_scale.get("trait", 0.0)),
		float(identity_weight_scale.get("vector", 0.0))
	)
	var identity_mul_at_1: float = 1.0 + max_identity_scale
	var directive_mul_at_1: float = float(directive_interpretation_mul.get("low", 1.0))
	if directive_mul_at_1 <= 0.0:
		return INF
	return identity_mul_at_1 / directive_mul_at_1


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


# BOND-002: Additive bond score bias for protect_ally candidates.
# Friend target: boost protect_ally score. Rival target: penalise protect_ally score.
# Mirrors _apply_vow_bias pattern — never overwrites _score, always +=.
# Only called for echo faction actors when bonds array is non-empty.
# all_actors param reserved for future guard bias; not used in MVP (protect_ally has explicit target_id).
func _apply_bond_bias(
	candidates: Array,
	actor: Dictionary,
	bonds: Array,
	thresholds: Dictionary,
	bond_cfg: Dictionary
) -> void:
	var actor_id := str(actor.get("id", ""))
	var friend_bonus := float(bond_cfg.get("friend_protect_weight_bonus", 12.0))
	var rival_penalty := float(bond_cfg.get("rival_protect_penalty", -10.0))
	for c: Dictionary in candidates:
		var at: String = str(c.get("action_type", ""))
		var target_id: String = str(c.get("target_id", ""))
		if at != "protect_ally" or target_id.is_empty():
			continue
		var edge := SocialGraphService.get_edge(bonds, actor_id, target_id)
		if edge.is_empty():
			continue
		var strength := int(edge.get("strength", 0))
		var bond_type := SocialGraphService.get_bond_type(strength, thresholds)
		if bond_type == "friend":
			c["_score"] = float(c.get("_score", 0.0)) + friend_bonus
		elif bond_type == "rival":
			c["_score"] = float(c.get("_score", 0.0)) + rival_penalty


# PROG-010: Compute hp_ratio for any actor dict. Returns 1.0 if stats unavailable.
static func _hp_ratio(actor: Dictionary) -> float:
	var max_hp: int = int(actor.get("stats", {}).get("max_hp", 0))
	if max_hp <= 0 or not actor.has("current_hp"):
		return 1.0
	return clampf(float(actor["current_hp"]) / float(max_hp), 0.0, 1.0)
