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
const LeadershipEmotionServiceScript = preload("res://core/combat/LeadershipEmotionService.gd")
const ReachAuthority = preload("res://core/movement/CombatActivationService.gd")
const GuidanceContributionScript = preload("res://core/actors/behaviors/GuidanceContribution.gd")
const MovementStyleServiceScript = preload("res://core/actors/behaviors/MovementStyleService.gd")
const BoardAssessmentServiceScript = preload("res://core/actors/behaviors/BoardAssessmentService.gd")
const ActionCandidateGeneratorScript = preload("res://core/actors/behaviors/ActionCandidateGenerator.gd")

## ROUTE-shape validation order (mirrors MovementOptionService.STYLE_ORDER / OptionContract.STYLES).
## Most of these words also appear in the separate `movement_style` vocabulary
## (docs/movement-model.md §9) — but the two lists mean different things even where the
## words coincide: this one is route-SHAPE mechanics (how the path is built), the other is
## expressive style (how the move reads to the player).
const _ROUTE_STYLE_ORDER: Array = [
	"direct", "safe", "cohesive", "lateral", "screen", "intercept", "conservative", "retreating",
	"forceful", "overcommitted", "low_exposure",
]
# Whole-band leadership traits that modify DECISION SCORES rather than morale/fear.
# The morale/fear half of the same trait set is owned by LeadershipEmotionService and
# ActorStateMachine._apply_leadership; this table is the scoring half.
#   effect_key — the key read out of data.maturity_expression.leadership_trait_effects
#   target     — an action_type (additive score term) or a "_"-prefixed derived lever
#   mode       — add / sub (summed across distinct traits) or mul (strongest wins)
const _LEADERSHIP_SCORE_TRAITS: Dictionary = {
	"aggression_field":  {"effect_key": "melee_score_bonus",           "target": "melee_attack",  "mode": "add"},
	"mark_target":       {"effect_key": "attack_score_bonus",          "target": "melee_attack",  "mode": "add"},
	"challenge_call":    {"effect_key": "taunt_attack_bonus",          "target": "actor.taunt",   "mode": "add"},
	"safe_path_read":    {"effect_key": "move_score_bonus",            "target": "actor.move",    "mode": "add"},
	"hold_formation":    {"effect_key": "move_score_reduction",        "target": "actor.move",    "mode": "sub"},
	"threat_read":       {"effect_key": "retreat_threshold_reduction", "target": "_retreat_threshold_reduction", "mode": "add"},
	"cover_positioning": {"effect_key": "cover_move_score_bonus",      "target": "_cover_move_bonus",            "mode": "add"},
	"directive_amplify": {"effect_key": "directive_mul",               "target": "_directive_mul", "mode": "mul"},
	"directive_echo":    {"effect_key": "directive_bonus_mul",         "target": "_directive_mul", "mode": "mul"},
}

const _SPATIAL_UTILITY_FIELDS: Array = [
	"cap",
	"urgency_weight",
	"urgency_progress_gain",
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
	# To activate a stub: remove _stub_ prefix, set values, implement the condition in BoardAssessmentService.build_board_summary().
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
		# Enemy-type only conditions (gated by actor_type == "enemy" in BoardAssessmentService.build_board_summary).
		"enemy_engaged": {
			# Adjacent to an echo — maintain pressure, don't retreat.
			"melee_attack": 15, "protect_ally":  0, "actor.guard": -8, "actor.idle": -10, "actor.move":  0,
		},
		"enemy_advancing": {
			# Not yet adjacent — close the gap aggressively.
			"melee_attack":  0, "protect_ally":  0, "actor.guard": -10, "actor.idle":  -8, "actor.move": 15,
		},

		# --- Stub conditions (zero values — no effect until implemented) ---
		# To activate: remove _stub_ prefix, tune values, add condition check to BoardAssessmentService.build_board_summary().
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
	# V2-COMBAT-003.5 Phase 3b. {} is a true no-op: every candidate's style-alignment
	# term is 0.0, so the ordinary candidate sort decides alone. Real weights live in
	# data.actor.movement_style_weights (balance.json). Purpose-ineligible styles are
	# still penalised — that gate is code, not config.
	"movement_style_weights": {},
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
	var board_summary: Dictionary = BoardAssessmentServiceScript.build_board_summary(actor, all_actors, context.get("board_cfg", {}), expression_band, context.get("resolution_mode", ""), context.get("objective_modes_cfg", {}), _cfg_get("situational_muls"))

	# V2-INFRA-003 pass 8: Whole-band leadership score effects from nearby leaders.
	# Computed once per turn, before candidate generation — threat_read moves the
	# retreat gate, which decides whether actor.retreat is even generated.
	var leadership_mods: Dictionary = _leadership_score_mods(
		actor, all_actors, context.get("expression_cfg", {}) as Dictionary)
	var leadership_dir_mul: float = float(leadership_mods.get("_directive_mul", 1.0))

	var candidates: Array[Dictionary] = ActionCandidateGeneratorScript.generate_candidates(
		actor, all_actors, context, expression_band, calling_behavior, leadership_mods,
		int(_cfg_get("guard_range")), float(_cfg_get("threat_threshold")), _cfg_get("situational_muls"),
		{
			"intent_weights_by_calling_origin": _cfg_get("intent_weights_by_calling_origin"),
			"default_intent_weight":            _cfg_get("default_intent_weight"),
		}
	)

	# Score each candidate, then sort by the same four-key order used by the
	# movement-aware selector: score, action type, target id, target cell.
	for c: Dictionary in candidates:
		# The per-term breakdown is kept on the candidate instead of being discarded:
		# DecisionTrace needs the RUNNER-UP's terms as well as the winner's to answer
		# "would removing this contribution have changed the winner?". Reporting only —
		# `_score()` fills it after computing the value it returns.
		var components: Dictionary = {}
		c["_score"] = _score(c["action_type"], actor, directive, board_summary, expression_band, calling_behavior, c, presence_strength, rank_strength, composure, judgment, components, leadership_mods)
		c["_score_components"] = components

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

	# V2-COMBAT-003: the Keeper's suggestion, and the Echo's answer to it. Last of the
	# post-scoring biases and before the purifier override, so it can never outrank a
	# mechanical certainty. This path publishes no movement goal, so a purpose-only
	# suggestion cannot reach it — see _guidance_entries().
	var guidance_response: Dictionary = _apply_guidance(candidates, context, actor, false, 0)

	# COMBAT-006: actor.purify_shrine override — injected AFTER scoring so 9999 is never overwritten.
	# Fires when the purifier is in reach of a living shrine and its cooldown is spent.
	#
	# There is deliberately NO shrine-health condition. It used to require the shrine below
	# half health, which a 200-hp shrine draining 5 a round reaches at round 20 while these
	# encounters end near round 5 — so purify never fired at all. `purify_cooldown` is the
	# throttle that stops the purifier spending every turn here; shrine health scales the
	# pressure layer's urgency instead (CombatPressureService._shrine_urgency).
	if context.get("is_purifier", false) \
			and context.get("shrine_alive", false) \
			and int(actor.get("purify_cooldown", 0)) == 0:
		var my_pos_pu: Dictionary = actor.get("grid_pos", {})
		for a_v in all_actors:
			if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
				if ReachAuthority.in_reach(my_pos_pu, a_v.get("grid_pos", {}), "actor.purify_shrine"):
					candidates.append({
						"action_type":    "actor.purify_shrine",
						"target_id":      "",
						"priority":       1.0,
						"_score":         9999.0,
						"_hard_override": "purify_shrine_in_reach",
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
	# pattern this file already uses for VOW-001/BOND-002 bias above. The gate is
	# on the PROBE below, not on this accumulation loop: DecisionTrace bands a
	# contribution's strength against `_decision_scale` for every mover, not only
	# Echoes, and computing it once here beats a second spread computation elsewhere.
	var _is_echo_faction: bool = str(actor.get("faction", "")) == "echo"
	var _dbonus_by_type: Dictionary = {}
	var _repr_by_type: Dictionary = {}
	var _decision_scale: float = 0.0
	var _self_score_min: float = INF
	var _self_score_max: float = -INF
	for c: Dictionary in candidates:
		var _atype: String = str(c.get("action_type", ""))
		if not _dbonus_by_type.has(_atype):
			_dbonus_by_type[_atype] = _directive_bonus(_atype, directive, interpretation_width, calling_behavior, leadership_dir_mul)
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
		# Read, not recomputed: the scoring loop above now keeps each candidate's own
		# breakdown on the candidate. This used to be a second _score() call with
		# identical arguments — a duplicate computation of a value the arbiter already
		# had (see DivergenceDetectorTests for the no-score-drift pin, which still holds).
		var _w_components: Dictionary = candidates[0].get("_score_components", {}) as Dictionary
		winner["_divergence_probe"] = {
			"chosen": {
				"action_type":             _w_action_type,
				"target_id":               str(candidates[0].get("target_id", "")),
				"score":                   _winner_score,
				"directive_bonus":         float(_dbonus_by_type.get(_w_action_type, 0.0)),
				# V2-PROG-012 Phase 6: interpretation_width=0.0 is the new "most literal"
				# floor (was band string "nascent" — see _directive_bonus()'s doc comment).
				"directive_bonus_nascent": _directive_bonus(_w_action_type, directive, 0.0, calling_behavior, leadership_dir_mul),
				"components":              _w_components,
			},
			# V2-PROG-012 Phase 4 fix: the FULL directive_bonus-descending ranking
			# (not just the single top D) — see `_repr_by_type` above for why.
			# DivergenceDetector.gd falls through this list past any ignored
			# action_type (data.maturity_expression.divergence.divergence_ignored_directive_actions)
			# to find the effective directive_preferred candidate.
			"directive_candidates": _rank_directive_candidates(
				_dbonus_by_type, _repr_by_type, directive, calling_behavior, leadership_dir_mul
			),
			# V2-PROG-012 Phase 4 fix: see `_decision_scale` above — DivergenceDetector.gd
			# divides `directive_pull` by this to get a proportion instead of a raw number.
			"decision_scale": _decision_scale,
		}

	# The raw material DecisionTrace reads. Reporting only — every value here was
	# computed by the scoring pass above. This path has no movement goal, so there is
	# no purpose and no commitment to report.
	winner["_decision_inputs"] = {
		"winner":         _decision_entry(candidates[0], str(candidates[0].get("action_type", ""))),
		"runner_up":      _decision_entry(
			candidates[1] if candidates.size() > 1 else {},
			str((candidates[1] as Dictionary).get("action_type", "")) if candidates.size() > 1 else ""
		),
		"decision_scale": _decision_scale,
		"purpose":        "",
		"subject_id":     str(candidates[0].get("target_id", "")),
		"commitment":     0,
		"capacity":       0,
		"hard_override":  str(candidates[0].get("_hard_override", "")),
	}
	if not guidance_response.is_empty():
		winner["_guidance_response"] = guidance_response

	return winner


## The Keeper's suggestion, and this Echo's answer to it (V2-COMBAT-003).
##
## GuidanceContribution owns every decision here; this function only normalizes the two
## candidate shapes into one, hands the request over, and applies the contribution it
## gets back through _apply_bias — so the guidance is reconstructible from the recorded
## parts exactly as vow and bond are.
##
## Returns {} and touches nothing when no suggestion is active, which is what makes
## "behaviour is identical without guidance" exact rather than approximate.
func _apply_guidance(
	candidates: Array,
	context: Dictionary,
	actor: Dictionary,
	is_movement: bool,
	capacity: int
) -> Dictionary:
	var request: Dictionary = context.get("guidance", {}) as Dictionary
	if request.is_empty():
		return {}
	var entries: Array = _guidance_entries(candidates, is_movement, capacity)
	var response: Dictionary = GuidanceContributionScript.resolve(
		request,
		entries,
		actor,
		float(context.get("judgment", 0.3)),
		float(context.get("composure", 0.4))
	)
	if response.is_empty():
		return {}
	var deltas: Dictionary = response.get("deltas", {}) as Dictionary
	for index: int in range(candidates.size()):
		var delta: float = float(deltas.get(_guidance_key(index), 0.0))
		if delta != 0.0:
			_apply_bias(candidates[index] as Dictionary, "guidance", delta)
	return response


## Both arbitration paths reduced to the one shape GuidanceContribution reads. `purpose`
## and `commitment` exist only on the movement path; on the legacy path they are "" and
## 0, which makes a purpose-only suggestion unmatched there and the hesitation
## commitment charge zero — stated rather than hidden, because the legacy path publishes
## no goal to have a purpose about.
func _guidance_entries(candidates: Array, is_movement: bool, capacity: int) -> Array:
	var entries: Array = []
	for index: int in range(candidates.size()):
		var candidate: Dictionary = candidates[index] as Dictionary
		var action_type: String = str((candidate["_movement_plan"] as Dictionary)["type"]) if is_movement \
			else str(candidate.get("action_type", ""))
		var goal: Dictionary = candidate.get("_movement_goal", {}) as Dictionary
		var entry: Dictionary = _decision_entry(candidate, action_type)
		entry["key"]        = _guidance_key(index)
		entry["purpose"]    = str(goal.get("purpose", ""))
		entry["commitment"] = int(candidate.get("_movement_commitment", 0))
		entry["capacity"]   = capacity
		entries.append(entry)
	return entries


static func _guidance_key(index: int) -> String:
	return "c%04d" % index


## One candidate's recorded score decomposition, for DecisionTrace. Every field is
## read off the candidate — nothing here is computed a second time.
static func _decision_entry(candidate: Dictionary, action_type: String) -> Dictionary:
	if candidate.is_empty():
		return {}
	var entry: Dictionary = {
		"action_type": action_type,
		"target_id":   str(candidate.get("target_id", "")),
		"score":       float(candidate.get("_score", 0.0)),
		"components":  candidate.get("_score_components", {}) as Dictionary,
		"spatial":     candidate.get("_spatial_components", {}) as Dictionary,
		"bias":        candidate.get("_score_bias", {}) as Dictionary,
	}
	if candidate.has("_stop_short"):
		entry["stop_short"] = StopShortContextService.trace_tag(candidate)
	return entry


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
	var board_summary: Dictionary = BoardAssessmentServiceScript.build_board_summary(
		actor,
		all_actors,
		context.get("board_cfg", {}),
		expression_band,
		context.get("resolution_mode", ""),
		context.get("objective_modes_cfg", {}),
		_cfg_get("situational_muls")
	)

	# V2-INFRA-003 pass 8: see select_intent()'s equivalent block.
	var leadership_mods: Dictionary = _leadership_score_mods(
		actor, all_actors, context.get("expression_cfg", {}) as Dictionary)
	var leadership_dir_mul: float = float(leadership_mods.get("_directive_mul", 1.0))
	var cover_move_bonus: float = float(leadership_mods.get("_cover_move_bonus", 0.0))

	var legacy_candidates: Array[Dictionary] = ActionCandidateGeneratorScript.generate_candidates(
		actor, all_actors, context, expression_band, calling_behavior, leadership_mods,
		int(_cfg_get("guard_range")), float(_cfg_get("threat_threshold")), _cfg_get("situational_muls"),
		{
			"intent_weights_by_calling_origin": _cfg_get("intent_weights_by_calling_origin"),
			"default_intent_weight":            _cfg_get("default_intent_weight"),
		}
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
			candidates.append(ActionCandidateGeneratorScript.stationary_candidate(legacy, movement_context, profile))

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
			candidates.append(ActionCandidateGeneratorScript.route_candidate({}, plan, goal, option, movement_context, profile))
		else:
			for match_value: Variant in matches:
				candidates.append(ActionCandidateGeneratorScript.route_candidate(
					match_value as Dictionary,
					plan,
					goal,
					option,
					movement_context,
					profile
				))

	var active_vow: Dictionary = context.get("active_vow", {}) as Dictionary
	var bonds_ctx: Array = context.get("bonds", []) as Array
	var is_echo_faction: bool = str(actor.get("faction", "")) == "echo"

	# V2-COMBAT-003.5 Phase 3b — movement_style (docs/movement-model.md §9/§10.4,
	# decision #18). Assembled once; `bond_pressure` is the one input that varies per
	# candidate, so `_style_alignment()` resolves it there.
	# ASSUMED: only one vow (tikoro_nko_agyina) exists and it is protective/cohesion-
	# themed, so "a vow is active" reads as fully Ward-leaning until a vow carries its
	# own Ward/Break strain signal. See the story report's OPEN block.
	var style_inputs: Dictionary = {
		"actor":            actor,
		"bonds":            bonds_ctx if is_echo_faction else [],
		"bond_thresholds":  context.get("bond_thresholds", {}) as Dictionary,
		"vector_scores":    actor.get("vector_scores", {}) as Dictionary,
		"calling_family":   str(context.get("calling_family", "")),
		"traits":           actor.get("traits", {}) as Dictionary,
		"fear":             maxf(float(actor.get("fear", 0)), float(actor.get("fear_base", 0))),
		"morale_tier":      EmotionService.get_morale_tier(int(actor.get("morale", 50))),
		"vow_lean":         0.0 if active_vow.is_empty() else -1.0,
		"cfg":              _cfg_get("movement_style_weights") as Dictionary,
	}

	var stop_short_vetoes: Array = StopShortContextService.screen(
		candidates, actor, all_actors, context, movement_context, options,
		int(profile["capacity"]), Callable(self, "_route_style_of"), _cfg.get("stop_short", {}) as Dictionary)
	var spatial_cfg: Dictionary = _movement_cfg["spatial_utility"] as Dictionary
	for candidate: Dictionary in candidates:
		var plan: Dictionary = candidate["_movement_plan"] as Dictionary
		# See select_intent()'s scoring loop for why the breakdown is kept.
		var components: Dictionary = {}
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
			judgment,
			components,
			leadership_mods
		)
		candidate["_score_components"] = components
		var cover_bonus_applied: float = 0.0
		if bool(candidate.get("_movement_route", false)):
			var spatial_parts: Dictionary = {}
			score += _spatial_utility(
				candidate["_movement_goal"] as Dictionary,
				candidate["_movement_option"] as Dictionary,
				directive,
				spatial_cfg,
				spatial_parts
			)
			candidate["_spatial_components"] = spatial_parts
			# V2-INFRA-003 pass 8: cover_positioning — a Whole leader in range teaches
			# its allies to end a route behind terrain. Route candidates only: a
			# stationary candidate is not a repositioning choice.
			if cover_move_bonus > 0.0 and BoardAssessmentServiceScript.is_cover_destination(
				candidate["_movement_path"] as Array, movement_context
			):
				score += cover_move_bonus
				cover_bonus_applied = cover_move_bonus
			# Flat additive, applied here rather than inside _score() so it stays
			# OUTSIDE the fear/calling bracket — the placement `self_score = _score -
			# directive_bonus` depends on (see _score()'s own comment).
			# INELIGIBLE_ALIGNMENT is 0.0 (decision #21, neutral not a veto), so a
			# purpose-ineligible style is indistinguishable here from "no style
			# counterpart" — both add nothing and need no separate bookkeeping.
			var style_alignment: float = _style_alignment(candidate, style_inputs) * _style_urgency_factor(
				candidate["_movement_goal"] as Dictionary, style_inputs["cfg"] as Dictionary
			)
			if style_alignment != 0.0:
				score += style_alignment
				var style_bias: Dictionary = candidate.get("_score_bias", {}) as Dictionary
				style_bias["movement_style"] = style_alignment
				candidate["_score_bias"] = style_bias
			score += StopShortContextService.record_bias(candidate)
		if not is_finite(score):
			return _movement_failure("non_finite_candidate_score", "candidates")
		candidate["_score"] = score
		if cover_bonus_applied != 0.0:
			# Recorded, not re-applied — `score` above already carries it.
			var bias: Dictionary = candidate.get("_score_bias", {}) as Dictionary
			bias["leadership_cover"] = cover_bonus_applied
			candidate["_score_bias"] = bias

	if not active_vow.is_empty() and is_echo_faction:
		_apply_vow_bias(candidates, active_vow, int(context.get("party_size", 0)))
	if not bonds_ctx.is_empty() and is_echo_faction:
		_apply_bond_bias(
			candidates,
			actor,
			bonds_ctx,
			context.get("bond_thresholds", {}) as Dictionary,
			context.get("bond_behavior_cfg", {}) as Dictionary
		)

	# V2-COMBAT-003: see select_intent()'s equivalent call. This is the path where a
	# purpose-only suggestion is meaningful, because these candidates carry goals.
	var guidance_response: Dictionary = _apply_guidance(
		candidates, context, actor, true, int(profile["capacity"]))

	# Hard purifier authority remains last and exact after vow/bond adjustments.
	var purifier_ready: bool = bool(context.get("is_purifier", false)) \
		and bool(context.get("shrine_alive", false)) \
		and int(actor.get("purify_cooldown", 0)) == 0
	if purifier_ready:
		for candidate: Dictionary in candidates:
			var plan: Dictionary = candidate["_movement_plan"] as Dictionary
			if str(plan["type"]) == "actor.purify_shrine":
				candidate["_score"] = 9999.0
				candidate["_hard_override"] = "purify_shrine_in_reach"
	ActionCandidateGeneratorScript.append_legacy_purifier_candidate(candidates, context, actor, all_actors, movement_context, profile)
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
	# (actor_type "enemy", faction "echo") reasoning, the miscalibration it fixes,
	# and why the gate sits on the probe rather than on this accumulation loop.
	var _dbonus_by_type: Dictionary = {}
	var _repr_by_type: Dictionary = {}
	var _decision_scale: float = 0.0
	var _self_score_min: float = INF
	var _self_score_max: float = -INF
	for c: Dictionary in candidates:
		var _atype: String = str((c["_movement_plan"] as Dictionary)["type"])
		if not _dbonus_by_type.has(_atype):
			_dbonus_by_type[_atype] = _directive_bonus(_atype, directive, interpretation_width, calling_behavior, leadership_dir_mul)
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

	# The stop-short screen can veto every route candidate it is given.
	if candidates.is_empty():
		return _movement_failure("no_candidates", "candidates")
	var winner: Dictionary = candidates[0]

	# V2-COMBAT-003.5 Phase 3b — the winner's own route-shape, read back into the §9
	# movement_style vocabulary. Style already influenced the sort (see
	# `_style_alignment()` in the scoring loop), so this is a read, never a second
	# selection: `winner` is genuinely the highest-scored candidate. A stationary
	# winner, or a `screen` route, has no style word and gets "".
	var _selected_movement_style: String = ""
	if bool(winner.get("_movement_route", false)):
		var _winner_style: String = MovementStyleServiceScript.movement_style_for(
			_route_style_of(
				str(winner.get("_movement_option_id", "")), str(winner["_movement_goal_id"])
			)
		)
		# Winning on mechanical merit alone (decision #21) does not make the style
		# truthful to say aloud: a purpose-ineligible style stays unpublished, same as
		# the "no preference" case, rather than naming a style the purpose cannot
		# express (decision #23 gate).
		var _winner_purpose: String = str((winner.get("_movement_goal", {}) as Dictionary).get("purpose", ""))
		if not _winner_style.is_empty() \
				and MovementStyleServiceScript.eligible_styles(_winner_purpose).has(_winner_style):
			_selected_movement_style = _winner_style

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
		winner["_movement_pressure_sources"] as Array,
		_selected_movement_style
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
	if is_echo_faction and _winner_score < 9999.0:
		var _w_plan: Dictionary = winner["_movement_plan"] as Dictionary
		var _w_action_type: String = str(_w_plan["type"])
		# Read, not recomputed — see select_intent()'s equivalent block.
		var _w_components: Dictionary = winner.get("_score_components", {}) as Dictionary
		_divergence_probe = {
			"chosen": {
				"action_type":             _w_action_type,
				"target_id":               str(winner.get("target_id", "")),
				"score":                   _winner_score,
				"directive_bonus":         float(_dbonus_by_type.get(_w_action_type, 0.0)),
				# V2-PROG-012 Phase 6: interpretation_width=0.0 is the new "most literal"
				# floor (was band string "nascent" — see _directive_bonus()'s doc comment).
				"directive_bonus_nascent": _directive_bonus(_w_action_type, directive, 0.0, calling_behavior, leadership_dir_mul),
				"components":              _w_components,
			},
			# V2-PROG-012 Phase 4 fix: see select_intent()'s equivalent block for why
			# this is the full ranking, not just the single top D.
			"directive_candidates": _rank_directive_candidates(
				_dbonus_by_type, _repr_by_type, directive, calling_behavior, leadership_dir_mul
			),
			# V2-PROG-012 Phase 4 fix: see `_decision_scale` above.
			"decision_scale": _decision_scale,
		}

	# The raw material DecisionTrace reads — see select_intent()'s equivalent block.
	# Travels beside `intent` for the same reason `_divergence_probe` does:
	# MovementIntentContract.validate() enforces an exact field set on `intent`.
	var _runner_up: Dictionary = candidates[1] if candidates.size() > 1 else {}
	var _winner_goal: Dictionary = winner.get("_movement_goal", {}) as Dictionary
	var _decision_inputs: Dictionary = {
		"winner":         _decision_entry(winner, str((winner["_movement_plan"] as Dictionary)["type"])),
		"runner_up":      _decision_entry(
			_runner_up,
			str((_runner_up["_movement_plan"] as Dictionary)["type"]) if not _runner_up.is_empty() else ""
		),
		"decision_scale": _decision_scale,
		"purpose":        str(_winner_goal.get("purpose", "")),
		# The goal names who or what the movement is ABOUT; a stationary candidate has
		# no goal, so the planned action's own target is the subject instead.
		"subject_id":     str(_winner_goal.get("subject_id", "")) if not str(_winner_goal.get("subject_id", "")).is_empty() \
			else str(winner.get("target_id", "")),
		"commitment":     int(winner["_movement_commitment"]),
		"capacity":       int(profile["capacity"]),
		"hard_override":  str(winner.get("_hard_override", "")),
	}

	return {
		"valid": true,
		"intent": intent,
		"reason": "",
		"field": "",
		"_divergence_probe": _divergence_probe,
		"_decision_inputs": _decision_inputs,
		"_guidance_response": guidance_response,
		"_stop_short": winner.get("_stop_short", {}),
		"_stop_short_vetoes": stop_short_vetoes,
	}


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
		var style_index: int = _ROUTE_STYLE_ORDER.find(style)
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
		# One option per route-shape is the ceiling, matching MovementOptionService's own
		# dedup cap. A lower number here silently discards the WHOLE board (not the extra
		# options) the moment a producer emits more, which is how it stayed at 4 after the
		# generator's cap was raised to the full style set — the live path was still
		# publishing one option per goal, so nothing could reach the limit.
		if int(option_counts_by_goal[counted_goal_id]) > _ROUTE_STYLE_ORDER.size():
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
	var facts_by_id: Dictionary = MovementContextContract.facts_by_id(movement_context)
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
	if not is_equal_approx(ActorService.health_ratio(actor), float(fact["health_ratio"])):
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


## `out_parts`, when a non-null Dictionary is passed, receives this call's own
## decomposition: {parts: {term → weighted value}, raw, cap, value}. Purely additive
## reporting — the returned float is unchanged. `raw` and `cap` travel with the parts
## because the return is CLAMPED: a consumer asking "what would this score be without
## term X" must re-apply the same clamp to `raw - X`, which it cannot do from the
## clamped value alone.
func _spatial_utility(
	goal: Dictionary,
	option: Dictionary,
	directive: Dictionary,
	config: Dictionary,
	out_parts: Dictionary = {}
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
	# V2-COMBAT-003.5 Phase 3c: the "commitment" scoring term normalizes against the SAME
	# distance objective_progress uses, not capacity — a capacity-normalized commitment
	# term shrank at a different rate than progress, producing a distance cliff past which
	# every actor's best move dropped to 1 cell regardless of capacity. commitment_ratio
	# (capacity-normalized) is kept unchanged for directive_avoid_overcommit below.
	# "commitment" is a cost the hostile-control surcharge can inflate; progress_origin_distance
	# is a pure cell count that never carries that surcharge. path.size() keeps both terms of
	# the ratio in the same unit without a new computation.
	var route_cell_distance: int = (option.get("path", []) as Array).size()
	var commitment_progress_ratio: float = clampf(
		float(route_cell_distance) / maxf(1.0, float(option.get("progress_origin_distance", 1.0))), 0.0, 1.0
	)
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
	var parts: Dictionary = {
		"urgency":                       float(config["urgency_weight"]) * urgency,
		"objective_progress":            float(config["objective_progress_weight"]) * progress * (1.0 + maxf(float(config["urgency_progress_gain"]), 0.0) * urgency),
		"cohesion":                      float(config["cohesion_weight"]) * cohesion,
		"exposure":                      float(config["exposure_weight"]) * exposure,
		"congestion":                    float(config["congestion_weight"]) * congestion,
		"commitment":                    float(config["commitment_weight"]) * commitment_progress_ratio,
		"directive_objective_advance":   float(config["directive_objective_advance_weight"]) * objective_advance * progress,
		"directive_avoid_overcommit":    float(config["directive_avoid_overcommit_weight"]) * avoid_overcommit * (1.0 - commitment_ratio),
		"directive_exposure_acceptance": float(config["directive_exposure_acceptance_weight"]) * exposure_acceptance * exposure,
		"directive_ally_protection":     float(config["directive_ally_protection_weight"]) * ally_protection * protects,
		"directive_threat_interception": float(config["directive_threat_interception_weight"]) * threat_interception * intercepts,
	}
	var raw: float = (
		float(parts["urgency"])
		+ float(parts["objective_progress"])
		+ float(parts["cohesion"])
		+ float(parts["exposure"])
		+ float(parts["congestion"])
		+ float(parts["commitment"])
		+ float(parts["directive_objective_advance"])
		+ float(parts["directive_avoid_overcommit"])
		+ float(parts["directive_exposure_acceptance"])
		+ float(parts["directive_ally_protection"])
		+ float(parts["directive_threat_interception"])
	)
	var cap: float = float(config["cap"])
	var value: float = clampf(raw, -cap, cap)
	out_parts["parts"] = parts
	out_parts["raw"]   = raw
	out_parts["cap"]   = cap
	out_parts["value"] = value
	return value


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

## Whole-band leadership SCORE effects pressing on `actor` from nearby leaders.
## Same idiom as LeadershipEmotionService.apply_fear_gain()/apply_morale_loss():
## a leader never affects itself, the radius comes from
## LeadershipEmotionService.get_trait_radius() so Presence grades it, and one leader's
## strongest instance of a trait applies rather than several leaders stacking it.
## Distinct traits DO sum (safe_path_read +8 and hold_formation -5 net to +3 on
## actor.move); the multiplicative directive lever takes the strongest instead.
##
## expr_cfg is data.maturity_expression, supplied per turn through
## context["expression_cfg"] — this class holds no ConfigService by design.
##
## position_lock and anchor_presence are absent here on purpose: they grant
## displacement immunity, which MovementHazardService resolves, not a score.
func _leadership_score_mods(actor: Dictionary, all_actors: Array, expr_cfg: Dictionary) -> Dictionary:
	var mods: Dictionary = {}
	if expr_cfg.is_empty() or actor.get("is_dead", false):
		return mods
	var actor_id: String = str(actor.get("id", ""))
	if actor_id.is_empty():
		return mods
	# Strongest instance per trait across every leader on the board.
	var per_trait: Dictionary = {}
	for leader_v: Variant in all_actors:
		if not (leader_v is Dictionary):
			continue
		var leader: Dictionary = leader_v
		if str(leader.get("id", "")) == actor_id:
			continue
		if not LeadershipEmotionServiceScript.is_whole_leader(leader, expr_cfg):
			continue
		for trait_v: Variant in (leader.get("leadership_traits", []) as Array):
			var trait_id: String = str(trait_v)
			if not _LEADERSHIP_SCORE_TRAITS.has(trait_id):
				continue
			var row: Dictionary = _LEADERSHIP_SCORE_TRAITS[trait_id]
			var effect: Dictionary = LeadershipEmotionServiceScript.get_trait_effect(trait_id, expr_cfg)
			var value: float = float(effect.get(str(row["effect_key"]), 0.0))
			if value == 0.0:
				continue
			if value <= float(per_trait.get(trait_id, 0.0)):
				continue
			var radius: int = LeadershipEmotionServiceScript.get_trait_radius(leader, trait_id, expr_cfg)
			if not BoardAssessmentServiceScript.is_in_leader_radius(leader, actor_id, all_actors, radius):
				continue
			per_trait[trait_id] = value
	for trait_id_v: Variant in per_trait:
		var trait_id_2: String = str(trait_id_v)
		var row_2: Dictionary = _LEADERSHIP_SCORE_TRAITS[trait_id_2]
		var target: String = str(row_2["target"])
		var value_2: float = float(per_trait[trait_id_2])
		match str(row_2["mode"]):
			"add":
				mods[target] = float(mods.get(target, 0.0)) + value_2
			"sub":
				mods[target] = float(mods.get(target, 0.0)) - value_2
			"mul":
				mods[target] = maxf(float(mods.get(target, 1.0)), value_2)
	return mods


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
	out_components: Dictionary = {},
	# V2-INFRA-003 pass 8: Whole-band leadership score modifiers pressing on this
	# actor, from _leadership_score_mods(). Action-type keys are additive terms on
	# `base`; "_directive_mul" scales the directive term. Empty {} = no leader in range.
	leadership_mods: Dictionary = {}
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
	var directive_bonus: float = _directive_bonus(action_type, directive, interpretation_width,
		calling_behavior, float(leadership_mods.get("_directive_mul", 1.0)))

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

	# V2-INFRA-003 pass 8: Whole-band leadership score traits (aggression_field,
	# mark_target, challenge_call, safe_path_read, hold_formation). Added to `base`
	# like the mark/reveal bonuses above, so fear and the calling multiplier still
	# reach it — a terrified Echo does not get the leader's full push.
	base += float(leadership_mods.get(action_type, 0.0))

	var situational_bonus: float = BoardAssessmentServiceScript.situational_bonus(action_type, board_summary, _cfg_get("situational_muls"))

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
## V2-INFRA-003 pass 8: `leadership_directive_mul` is the Whole-band directive_amplify /
## directive_echo lever (see _leadership_score_mods()). It scales the whole directive term
## and nothing else, so the algebraic separability the divergence probe depends on holds:
## every caller that subtracts a directive_bonus must pass the same multiplier it scored with.
func _directive_bonus(action_type: String, directive: Dictionary, interpretation_width: float = 0.0, calling_behavior: Dictionary = {}, leadership_directive_mul: float = 1.0) -> float:
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
	base_bonus = base_bonus * call_dir_mul * dir_mul * leadership_directive_mul

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
	calling_behavior: Dictionary,
	leadership_directive_mul: float = 1.0
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
			"directive_bonus_nascent": _directive_bonus(atype, directive, 0.0, calling_behavior,
				leadership_directive_mul),
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


# VOW-001: Apply vow-specific intent bias additively to all candidates.
# Each vow may boost or penalise specific action_types based on context.
# Echo actors only — call site already guards faction == "echo".
## Applies one post-scoring adjustment to a candidate AND records it under `key` in
## `_score_bias`. Every term added to `_score` after `_score()` returns must go through
## here, or DecisionTrace cannot reconstruct the final score from its parts (the
## reconstruction is pinned by DecisionTraceTests).
static func _apply_bias(candidate: Dictionary, key: String, delta: float) -> void:
	candidate["_score"] = float(candidate.get("_score", 0.0)) + delta
	var bias: Dictionary = candidate.get("_score_bias", {}) as Dictionary
	bias[key] = float(bias.get(key, 0.0)) + delta
	candidate["_score_bias"] = bias


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
						_apply_bias(c, "vow", protect_bonus)
					elif at == "actor.guard":
						_apply_bias(c, "vow", guard_bonus)
			else:
				# Fear bias: active intents depressed (actor prefers idle/guard under doctrine strain)
				var fear_bias := 6.0 * mul
				for c: Dictionary in candidates:
					var at: String = str(c.get("action_type", ""))
					if at == "melee_attack" or at == "actor.move":
						_apply_bias(c, "vow", -fear_bias)


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
			_apply_bias(c, "bond", friend_bonus)
		elif bond_type == "rival":
			_apply_bias(c, "bond", rival_penalty)


## How well ONE route candidate's own route-shape reads as this actor's identity
## (docs/movement-model.md §9/§10.4). Called from the movement scoring loop, so style
## is part of the score the winner-sort compares — no candidate is ever re-pointed
## after the sort. `inputs` is the per-actor dict that loop assembles once.
func _style_alignment(candidate: Dictionary, inputs: Dictionary) -> float:
	var goal_id: String = str(candidate.get("_movement_goal_id", ""))
	var route_style: String = _route_style_of(
		str(candidate.get("_movement_option_id", "")), goal_id
	)
	if route_style.is_empty():
		return 0.0
	var goal: Dictionary = candidate.get("_movement_goal", {}) as Dictionary
	var subject_id: String = str(goal.get("subject_id", ""))
	if subject_id.is_empty():
		subject_id = str(candidate.get("target_id", ""))
	return MovementStyleServiceScript.style_alignment_score(
		route_style,
		str(goal.get("purpose", "")),
		inputs["vector_scores"] as Dictionary,
		str(inputs["calling_family"]),
		inputs["traits"] as Dictionary,
		float(inputs["fear"]),
		str(inputs["morale_tier"]),
		_movement_style_bond_pressure(
			inputs["bonds"] as Array,
			inputs["actor"] as Dictionary,
			subject_id,
			inputs["bond_thresholds"] as Dictionary
		),
		float(inputs["vow_lean"]),
		inputs["cfg"] as Dictionary
	)


## Urgency damps how much style OUTRANKS the board, never what the style is. How she
## prefers to move is constant; whether that preference should beat closing a chase is
## not. Without this, a CRITICAL pursue and an idle reposition weigh manners identically.
static func _style_urgency_factor(goal: Dictionary, cfg: Dictionary) -> float:
	var urgency: float = clampf(float(goal.get("urgency", 0.0)), 0.0, 1.0)
	var damping: float = clampf(float(cfg.get("urgency_style_damping", 0.0)), 0.0, 1.0)
	return 1.0 - damping * urgency


## MovementStyleService's `bond_pressure` input, scoped to ONE subject (the scored
## candidate's own goal subject) rather than swept over every candidate the way
## `_apply_bond_bias` is — this is about one candidate's style reading, not a score
## adjustment applied across the whole candidate set.
## SIMPLIFICATION: a "friend" bond alone returns full pressure (1.0); this does not
## yet read the subject's health/danger state ("harmed/endangered" per the design
## brief) — see report's OPEN block.
func _movement_style_bond_pressure(
	bonds: Array,
	actor: Dictionary,
	subject_id: String,
	thresholds: Dictionary
) -> float:
	if subject_id.is_empty():
		return 0.0
	var edge: Dictionary = SocialGraphService.get_edge(bonds, str(actor.get("id", "")), subject_id)
	if edge.is_empty():
		return 0.0
	var bond_type: String = SocialGraphService.get_bond_type(int(edge.get("strength", 0)), thresholds)
	return 1.0 if bond_type == "friend" else 0.0


## Route-shape token (MovementOptionService.STYLE_ORDER vocabulary) a candidate's
## `option_id` was tagged with — same extraction `_validate_movement_inputs()` already
## does against `_ROUTE_STYLE_ORDER`, kept local rather than reaching into
## MovementOptionService's private helper of the same purpose.
func _route_style_of(option_id: String, goal_id: String) -> String:
	var option_prefix: String = "option.%s." % goal_id.trim_prefix("goal.")
	if not option_id.begins_with(option_prefix):
		return ""
	return option_id.trim_prefix(option_prefix).get_slice(".", 0)
