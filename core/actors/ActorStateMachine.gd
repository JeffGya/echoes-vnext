# res://core/actors/ActorStateMachine.gd
# Per-actor behavior host. Stores the actor dict, owns a BehaviorModule, and
# drives one turn of intent selection per advance_turn() call.
#
# Rules:
# - No RNG, no OS time, no side effects.
# - get_stat() reads base stats from actor_dict.stats (the 6 PROG-002-derived fields).
# - Top-level runtime fields (current_hp, speed, morale, fear) are accessed
#   directly from the actor dict by behavior modules — no wrapper in MVP.
# - advance_turn() is the single choke point for intent selection each combat turn.
# - select_intent() is pure: same context → same intent every call.
#
# GRID-STUB: position { x, y } will be added to the actor context when
# core/grid/ lands (GRID stories). Not present in MVP.

class_name ActorStateMachine
extends RefCounted

const MaturityExpressionService = preload("res://core/actors/MaturityExpressionService.gd")
const LeadershipEmotionService = preload("res://core/combat/LeadershipEmotionService.gd")
const SocialGraphService = preload("res://core/sanctum/SocialGraphService.gd")
const DivergenceDetector = preload("res://core/actors/DivergenceDetector.gd")

var _actor: Dictionary
var _behavior_module: BehaviorModule
var _last_intent: Dictionary = {}
var _last_action: Dictionary = {}
var _movement_skipped: bool = false  # ACTOR-006: true when actor is_structure; no movement phase
var _last_morale_tier: String = "steady"  # ACTOR-007: morale tier of the winning intent
var _last_morale_modifier: int = 0        # ACTOR-007: flat score modifier applied by morale tier

# V2-PROG-006: per-turn computed state (reset each advance_turn)
var _expression_band: String = "nascent"
var _calling_behavior: Dictionary = {}
var _active_leadership: String = ""
var _bark_line: String = ""
var _bark_context: String = ""
var _bark_tier: String = ""
var _bark_target_id: String = ""
var _bark_is_response: bool = false  # V2-VOICE-001: true when this bark is a reaction to an ally's bark


## actor_dict: the actor's full dict (from EchoActor.from_echo or EnemyActor.from_definition).
## behavior_module: the AI module to query each turn. Explicit injection wins; used by tests and
##   non-echo actors that need a specific module. Defaults to BehaviorArbiter for echo actors.
## actor_cfg: the data.actor block from balance.json; passed through to BehaviorArbiter.
## movement_cfg: the data.combat.movement block from balance.json; required only
##   when FlowRuntime supplies movement contracts for select_movement_intent().
##   Pass {} (default) to use BehaviorArbiter's hardcoded defaults — safe for all existing callers.
func _init(actor_dict: Dictionary, behavior_module: BehaviorModule = null,
		actor_cfg: Dictionary = {}, movement_cfg: Dictionary = {}) -> void:
	_actor = actor_dict
	if behavior_module != null:
		_behavior_module = behavior_module
	elif actor_dict.get("actor_type", "") in ["echo", "enemy"]:
		_behavior_module = BehaviorArbiter.new(actor_cfg, movement_cfg)  # ACTOR-005: echo + enemy actors use weighted arbiter
	else:
		_behavior_module = IdleBehaviorModule.new()
	_last_intent = {}


## Returns the value of a base stat from actor_dict.stats[stat_name].
## Covers: max_hp, atk, def, agi, int, cha.
## Returns null if stat_name is not found — caller must guard against null.
## Note: top-level runtime fields (current_hp, speed, morale, fear) are not
## in the stats sub-dict; access them directly via actor_dict["field_name"].
func get_stat(stat_name: String) -> Variant:
	var stats: Dictionary = _actor.get("stats", {})
	if stats.has(stat_name):
		return stats[stat_name]
	return null


## Called by the combat loop once per turn. Selects intent via the behavior module,
## stores it internally, and logs actor.intent.
##
## context shape (ACTOR-003, locked):
##   { "actor": Dictionary, "all_actors": Array, "t": int }
##   Grid fields (position, adjacency) added when core/grid/ lands.
##
## Returns the selected intent dict:
##   { "action_type": String, "target_id": String, "priority": float }
func advance_turn(context: Dictionary, logger: StructuredLogger, t: int) -> Dictionary:
	# ACTOR-008: Guard 1 — actor was already killed in a previous turn; skip silently.
	if _actor.get("is_dead", false):
		_last_intent = { "action_type": "actor.dead", "actor_id": _actor.get("id", "") }
		_last_action = _last_intent
		return _last_intent

	# ACTOR-008: Guard 2 — actor dies this turn (hp <= 0 integer check, no float).
	if int(_actor.get("current_hp", 1)) <= 0:
		_actor["is_dead"]     = true
		_actor["death_round"] = int(context.get("round", t))
		logger.info(t, "actor.died", "Actor KO'd", {
			"actor_id":     _actor.get("id", ""),
			"round_number": _actor["death_round"],
		})
		_last_intent = { "action_type": "actor.dead", "actor_id": _actor.get("id", "") }
		_last_action = _last_intent
		return _last_intent

	# ACTOR-006: structures never move — log the skip before intent selection.
	_movement_skipped = _actor.get("is_structure", false)
	if _movement_skipped:
		logger.info(t, "actor.turn", "Movement skipped (structure)", {
			"actor_id":         _actor.get("id", ""),
			"is_structure":     true,
			"movement_skipped": true,
		})

	# V2-PROG-006/V2-PROG-012: compute maturity-expression band, calling behavior,
	# and the four hidden autonomy outputs (judgment/presence/composure/legibility)
	# via one derive_expression() call.
	var cfg_data: Dictionary = context.get("cfg", {}).get("data", {})
	var expr_cfg: Dictionary = cfg_data.get("maturity_expression", {})

	# V2-PROG-012: assemble ctx_inputs from context this actor already has access to.
	# FIX (Opus review): defensive coercion (MaturityExpressionService._as_dict/_as_array)
	# instead of hard `as` casts — this read runs unconditionally for EVERY actor (echo,
	# enemy, structure), unlike BehaviorArbiter.gd's read of the same "bonds" context key,
	# which gates on faction == "echo". A hard cast here would be a new crash surface for
	# non-echo actors or malformed test fixtures; a type mismatch now degrades to {}/[] like
	# it does everywhere else in derive_expression()'s input assembly.
	var calling_defs: Dictionary = cfg_data.get("calling", {}).get("definitions", {})
	var calling_id_for_family: String = str(_actor.get("calling", ""))
	if calling_id_for_family.is_empty():
		calling_id_for_family = str(_actor.get("calling_origin", ""))
	var calling_family: String = str(MaturityExpressionService._as_dict(
		calling_defs.get(calling_id_for_family, {})).get("family", ""))

	var raw_bonds: Array = MaturityExpressionService._as_array(context.get("bonds", []))
	var actor_id_str: String = str(_actor.get("id", ""))
	var actor_bonds: Array = SocialGraphService.get_bonds_for_actor(raw_bonds, actor_id_str)
	# Only bonds to currently-living party members count — a bond to a fallen
	# ally shouldn't keep pressing on judgment/presence mid-encounter.
	var living_party_ids: Dictionary = {}
	for a_v in MaturityExpressionService._as_array(context.get("all_actors", [])):
		if a_v is Dictionary:
			var a: Dictionary = a_v
			if str(a.get("faction", "")) == "echo" and not bool(a.get("is_dead", false)):
				living_party_ids[str(a.get("id", ""))] = true
	var living_bonds: Array = []
	for edge_v in actor_bonds:
		if not (edge_v is Dictionary):
			continue
		var edge: Dictionary = edge_v
		var other_id: String = str(edge.get("actor_b", "")) if str(edge.get("actor_a", "")) == actor_id_str \
			else str(edge.get("actor_a", ""))
		if living_party_ids.has(other_id):
			living_bonds.append(edge)

	# FIX (Opus review, autonomy_outputs.fear_base_max de-dup): thread the canonical
	# fear_base_max (data.emotion.drift.fear_base_max — what actually enforces the cap,
	# see FlowRuntime._apply_encounter_emotion_drift()) through ctx_inputs so it can't
	# silently desync from the autonomy_outputs fallback copy.
	var emotion_cfg: Dictionary = MaturityExpressionService._as_dict(cfg_data.get("emotion", {}))
	var drift_cfg: Dictionary   = MaturityExpressionService._as_dict(emotion_cfg.get("drift", {}))

	var ctx_inputs: Dictionary = {
		"bonds":            living_bonds,
		"bond_thresholds":  context.get("bond_thresholds", {}),
		"active_vow":       context.get("active_vow", {}),
		"calling_family":   calling_family,
		"instability":      float(context.get("instability", 0.0)),  # V2-PROG-012: reserved seam, no system yet
		"level_thresholds": MaturityExpressionService._as_dict(cfg_data.get("progression", {})).get("level_thresholds", []),
		"fear_base_max":    float(drift_cfg.get("fear_base_max", 40.0)),
	}

	var expr_result: Dictionary = MaturityExpressionService.derive_expression(_actor, ctx_inputs, expr_cfg)
	_expression_band = str(expr_result.get("expression_band", "nascent"))
	_calling_behavior = expr_result.get("calling_behavior", {}) as Dictionary
	var rank_strength: float = float(expr_result.get("rank_strength", 0.0))
	var judgment: float      = float(expr_result.get("judgment", 0.0))
	var presence: float      = float(expr_result.get("presence", 0.0))
	var composure: float     = float(expr_result.get("composure", 0.0))
	var legibility: float    = float(expr_result.get("legibility", 0.0))
	# V2-PROG-012: presence (derived) replaces get_presence_strength() as the source of
	# _presence_strength. The old band-only value was passed to BehaviorArbiter._score()
	# and never read there, and projected into the snapshot but read by no UI — this
	# retires that dead path without removing the key any existing reader relies on.
	var presence_strength: float = presence
	# Write back to actor dict so _project_actor() can include them in snapshots
	_actor["_expression_band"]   = _expression_band
	_actor["_presence_strength"] = presence_strength
	_actor["_rank_strength"]     = rank_strength
	_actor["_judgment"]          = judgment
	_actor["_presence"]          = presence
	_actor["_composure"]         = composure
	_actor["_legibility"]        = legibility

	# PROG-010: read resilience + leadership traits
	var resilience_traits: Array = _actor.get("resilience_traits", []) as Array
	var leadership_traits: Array = _actor.get("leadership_traits", []) as Array

	# PROG-010: reset per-turn state
	_active_leadership = ""
	_bark_line = ""
	_bark_context = ""
	_bark_tier = ""
	_bark_target_id = ""
	_bark_is_response = false  # V2-VOICE-001
	if _actor.has("emotion"):
		(_actor["emotion"] as Dictionary).erase("_resilience_fired")

	# PROG-010: capture emotional state at turn start (for event detection)
	var start_fear: int = int(_actor.get("fear", 0))
	var start_morale: int = int(_actor.get("morale", 50))
	var start_morale_tier: String = EmotionService.get_morale_tier(start_morale)

	# PROG-010: check last_echo_standing
	var last_echo_standing := _is_last_echo_standing(context)

	# PROG-009: tick per-round runtime cooldown counters before candidate generation.
	if _actor.has("_read_field_cooldown"):
		_actor["_read_field_cooldown"] = maxi(0, int(_actor["_read_field_cooldown"]) - 1)
	if _actor.has("_withdraw_cooldown"):
		_actor["_withdraw_cooldown"] = maxi(0, int(_actor["_withdraw_cooldown"]) - 1)

	# COMBAT-003 + V2-PROG-006 + V2-PROG-010 + V2-PROG-012 Phase 7: Absolute Fear Rule — dynamic threshold.
	# Band base from refusal_thresholds_by_band (nascent=65, forming=72, grounded=80, whole=90) is now
	# genuinely load-bearing: the calling value composes as an OFFSET on top of the band baseline
	# instead of replacing it outright, so "nascent breaks sooner, whole holds longer" (GDD:1422) holds
	# for every calling, not just uncalled.
	# Priority chain:
	#   1. calling_behavior.absolute_fear_offset present → threshold = clamp(band_base + offset, 0, 100)
	#   2. else → threshold = band base (global fallback 80 if band itself is unconfigured)
	# V2-PROG-012 Phase 7 review-fix: the legacy flat `absolute_fear_threshold` override
	# (pre-Phase-7 config shape) is no longer read here — every calling_behavior entry in
	# data/balance.json now authors absolute_fear_offset, and AGENTS.md's additive-schema
	# exception for this story requires migrating every consumer rather than keeping a
	# silent fallback alive. See tests/MaturityExpressionTests.gd's
	# expr/legacy_absolute_fear_threshold_key_ignored for the regression guard.
	var refusal_by_band: Dictionary = expr_cfg.get("refusal_thresholds_by_band", {})
	var band_base_threshold: int    = int(refusal_by_band.get(_expression_band, \
		cfg_data.get("emotion", {}).get("fear_threshold", 80)))
	var fear_threshold: int
	# V2-PROG-012 Phase 4: track WHICH rule set the final threshold so a refusal
	# carries evidence of why the threshold sat where it did (combat.action_refused).
	var fear_threshold_reason: String
	if _calling_behavior.has("absolute_fear_offset"):
		var fear_offset: int = int(_calling_behavior.get("absolute_fear_offset", 0))
		fear_threshold = clampi(band_base_threshold + fear_offset, 0, 100)
		fear_threshold_reason = "expression band + calling offset"
	else:
		fear_threshold = band_base_threshold
		fear_threshold_reason = "expression band"
	if last_echo_standing:
		var ls_thresholds: Dictionary = expr_cfg.get("last_stand_fear_threshold", {})
		if _expression_band == "whole":
			fear_threshold = int(ls_thresholds.get("whole", 95))
			fear_threshold_reason = "last stand"
		elif _expression_band == "grounded":
			fear_threshold = int(ls_thresholds.get("grounded", 88))
			fear_threshold_reason = "last stand"
	# suppress_panic_spiral: raises threshold +5 on top of band bonus
	if "suppress_panic_spiral" in resilience_traits \
			and (_expression_band == "grounded" or _expression_band == "whole"):
		fear_threshold = min(fear_threshold + 5, 100)
		fear_threshold_reason += " (steadied)"
	_actor["_fear_threshold"]        = fear_threshold
	_actor["_fear_threshold_reason"] = fear_threshold_reason

	# V2-PROG-006: self_regulate tick — Grounded+ +3 morale per round
	if (_expression_band == "grounded" or _expression_band == "whole") \
			and "self_regulate" in resilience_traits:
		_actor["morale"] = clampi(int(_actor.get("morale", 50)) + 3, 0, 100)

	# V2-PROG-006: Whole last-stand morale tick +5
	if _expression_band == "whole" and last_echo_standing:
		_actor["morale"] = clampi(int(_actor.get("morale", 50)) + int(expr_cfg.get("last_stand_whole_morale_tick", 5)), 0, 100)
		logger.info(t, "actor.last_stand_morale_tick", "Whole-band last-stand morale tick", {
			"actor_id": _actor.get("id", ""),
			"morale":   _actor["morale"],
		})

	# V2-PROG-006: Whole-band leadership activation — apply radius effects to nearby allies
	if _expression_band == "whole" and not leadership_traits.is_empty():
		_active_leadership = _apply_leadership(leadership_traits, expr_cfg, context, logger, t)

	# Consequence bands (three named tiers — do not collapse):
	#   Normal     (fear < 40):              full intent scoring; no modifier.
	#   Hesitating (40 <= fear < threshold): fear_factor degrades aggressive scoring in BehaviorArbiter;
	#                                         _derive_status() returns "hesitating". Note: threshold
	#                                         here is the dynamic per-actor value; display boundary
	#                                         in FlowEncounterState._derive_status() uses base value (80).
	#   Refusing   (fear >= threshold):      Absolute Fear Rule fires; actor.refuse returned
	#                                         before behavior module is called.
	if int(_actor.get("fear", 0)) >= fear_threshold:
		var refuse_intent: Dictionary = {
			"action_type": "actor.refuse",
			"target_id":   "",
			"actor_id":    str(_actor.get("id", "")),
			"priority":    0.0,
		}
		_last_intent = refuse_intent
		_last_action = refuse_intent.duplicate()
		# V2-PROG-006: bark for refuse
		var arch_r: String = str(_actor.get("archetype_birth", ""))
		var vk_r: int = (t + str(_actor.get("id", "")).hash()) % 997
		_bark_context = "combat_refuse"
		_bark_tier = _expression_band
		_bark_line = ShoutBank.get_expression_shout("combat_refuse", arch_r, _expression_band,
			str(_actor.get("calling_origin", "")), vk_r)
		if _bark_line.is_empty():
			_bark_line = ShoutBank.get_shout("combat_refuse", arch_r, ShoutBank.get_tier(
				int(_actor.get("traits", {}).get("courage", 50)),
				int(_actor.get("traits", {}).get("wisdom",  50)),
				int(_actor.get("traits", {}).get("faith",   50))
			), vk_r)
		logger.info(t, "actor.refused", "Absolute Fear Rule triggered", {
			"actor_id": str(_actor.get("id", "")),
			"fear":     int(_actor.get("fear", 0)),
			"threshold": fear_threshold,
			"bark_line": _bark_line,
		})
		return refuse_intent

	# V2-PROG-006: inject expression band + traits into context so BehaviorArbiter can use them
	# V2-PROG-010: also inject presence_strength + rank_strength for identity scaling and composure
	var augmented_context := context.duplicate()
	augmented_context["expression_band"]   = _expression_band
	augmented_context["calling_behavior"]  = _calling_behavior
	augmented_context["presence_strength"] = presence_strength
	augmented_context["rank_strength"]     = rank_strength
	augmented_context["resilience_traits"] = resilience_traits
	augmented_context["leadership_traits"] = leadership_traits
	# V2-PROG-012 Phase 1: hidden autonomy outputs. `composure` has been read by
	# BehaviorArbiter._score() since Phase 2; `judgment` has been read since Phase 6
	# (drives interpretation_width — see BehaviorArbiter._score()'s doc comment).
	# `presence` and `legibility` still have no BehaviorArbiter consumer (presence
	# feeds LeadershipEmotionService, legibility feeds DivergenceDetector's
	# primary_reason specificity — both read this actor's own _presence/_legibility
	# fields directly, not this context key).
	augmented_context["judgment"]          = judgment
	augmented_context["presence"]          = presence
	augmented_context["composure"]         = composure
	augmented_context["legibility"]        = legibility

	# PROG-009: inject equipped_skills + skills_cfg into context for BehaviorArbiter.
	# equipped_skills: slot → skill_id dict set by FlowSkillLoadoutState at encounter start.
	augmented_context["equipped_skills"] = _actor.get("equipped_skills", {})
	augmented_context["skills_cfg"]      = cfg_data.get("skills", {})

	var intent: Dictionary = {}
	if augmented_context.has("movement_context") \
			and augmented_context.has("movement_profile") \
			and augmented_context.has("movement_goals") \
			and augmented_context.has("movement_options") \
			and _behavior_module.has_method("select_movement_intent"):
		var movement_selection: Dictionary = _behavior_module.call(
			"select_movement_intent",
			augmented_context,
			augmented_context["movement_context"],
			augmented_context["movement_profile"],
			augmented_context["movement_goals"],
			augmented_context["movement_options"]
		)
		if bool(movement_selection.get("valid", false)):
			intent = movement_selection.get("intent", {}) as Dictionary
			var planned_action: Dictionary = intent.get("planned_action", {}) as Dictionary
			intent["action_type"] = str(planned_action.get("type", ""))
			intent["target_id"] = str(planned_action.get("target_id", ""))
			var selected_path: Array = intent.get("path", []) as Array
			intent["target_pos"] = selected_path.back() if not selected_path.is_empty() else _actor.get("grid_pos", {})
			intent["target_distance"] = GridService.chebyshev_distance(_actor.get("grid_pos", {}), intent["target_pos"] as Dictionary)
			# V2-PROG-012 Phase 4: select_movement_intent() cannot attach this onto
			# `intent` itself — MovementIntentContract.validate() enforces an EXACT
			# field set there, so any extra key would fail validation and discard the
			# whole board. It travels on the outer selection dict instead; pull it
			# across here now that `intent` is a plain working Dictionary again.
			intent["_divergence_probe"] = movement_selection.get("_divergence_probe", {})
		else:
			intent = _behavior_module.select_intent(augmented_context)
	else:
		intent = _behavior_module.select_intent(augmented_context)
	_last_intent = intent
	# Persist last_intent to actor dict so _build_board_summary() can read it next turn.
	# ActorStateMachine is recreated each turn (FlowRuntime.new per actor), so _last_intent
	# would otherwise reset to {} on every turn — meaning situational conditions that depend
	# on the previous action (repeated_move_penalty, repeated_guard_penalty) never fire.
	_actor["last_intent"] = { "action_type": str(intent.get("action_type", "")) }
	# ACTOR-007: read morale metadata annotated by BehaviorArbiter onto the winner.
	_last_morale_tier     = str(intent.get("morale_tier",     "steady"))
	_last_morale_modifier = int(intent.get("morale_modifier", 0))
	logger.debug(t, "actor.intent", "Intent selected", {
		"module_id": _behavior_module.get_module_id(),
		"action_type": intent.get("action_type", ""),
		"target_id": intent.get("target_id", ""),
		"actor_id": _actor.get("id", ""),
		"expression_band": _expression_band,
	})
	# ACTOR-004: store last_action for snapshot and log actor.action
	_last_action = {
		"action_type":    intent.get("action_type", ""),
		"target_id":      intent.get("target_id", ""),
		"target_distance": intent.get("target_distance", -1),  # GRID-004
		"target_pos":     intent.get("target_pos", {}),        # GRID-005
	}
	logger.debug(t, "actor.action", "Action resolved", {
		"action_type":            _last_action["action_type"],
		"source_id":              _actor.get("id", ""),
		"target_id":              _last_action["target_id"],
		"target_distance":        _last_action["target_distance"],  # GRID-004
		"damage":                 0,  # placeholder — real damage in COMBAT-001+
		"morale_tier":            _last_morale_tier,                     # ACTOR-007
		"action_weight_modifier": _last_morale_modifier,                 # ACTOR-007
		"archetype_birth":        str(intent.get("archetype_birth", "")),
		"archetype_modifier":     int(intent.get("archetype_modifier", 0)),
	})

	# V2-PROG-012 Phase 4: divergence detection — purely observational (no score
	# is touched; see DivergenceDetector.gd). BehaviorArbiter reports raw score
	# components on `intent["_divergence_probe"]` (both select_intent() and
	# select_movement_intent() attach it — see that file); ActorStateMachine
	# owns the threshold POLICY decision and reads data.maturity_expression.divergence
	# directly, never through BehaviorArbiter._cfg (that config stays out of the arbiter).
	# V2-PROG-012 Phase 5: also drives the combat_divergence bark below — see
	# _select_bark()'s Tier 2 branch.
	var diverged_this_turn: bool = false
	var divergence_probe: Dictionary = intent.get("_divergence_probe", {}) as Dictionary
	if not divergence_probe.is_empty():
		var divergence_cfg: Dictionary = expr_cfg.get("divergence", {})
		var directive: Dictionary = context.get("directive", {}) as Dictionary
		var divergence_result: Dictionary = DivergenceDetector.detect(
			divergence_probe.get("chosen", {}) as Dictionary,
			divergence_probe.get("directive_candidates", []) as Array,
			float(divergence_probe.get("decision_scale", 0.0)),
			composure,
			legibility,
			divergence_cfg
		)
		# Diagnostic-only, filtered out at the default INFO level (see StructuredLogger):
		# every turn's contest_ratio, not just the ones that cross the threshold. This is
		# what a playtest-ratification pass reads to (re)calibrate min_contest_ratio — see
		# the measurement methodology in the V2-PROG-012 Phase 4 fix story.
		logger.debug(t, "actor.divergence_probe", "Divergence contest computed", {
			"actor_id":         str(_actor.get("id", "")),
			"round":            int(context.get("round", t)),
			"chosen_action":    str(divergence_result.get("chosen_action", "")),
			"directive_action": str(divergence_result.get("directive_action", "")),
			"directive_pull":   float(divergence_result.get("directive_pull", 0.0)),
			"decision_scale":   float(divergence_result.get("decision_scale", 0.0)),
			"contest_ratio":    float(divergence_result.get("contest_ratio", 0.0)),
			"overrule_strength": float(divergence_result.get("overrule_strength", 0.0)),
			"diverged":         bool(divergence_result.get("diverged", false)),
		})
		if bool(divergence_result.get("diverged", false)):
			diverged_this_turn = true
			logger.info(t, "actor.divergence", "Echo's judgment diverged from the Directive", {
				"actor_id":          str(_actor.get("id", "")),
				"actor_name":        str(_actor.get("name", "")),
				"round":             int(context.get("round", t)),
				"expression_band":   _expression_band,
				"judgment":          judgment,
				"presence":          presence,
				"composure":         composure,
				"legibility":        legibility,
				"directive_id":      str(directive.get("id", "")),
				"directive_action":  str(divergence_result.get("directive_action", "")),
				"chosen_action":     str(divergence_result.get("chosen_action", "")),
				"chosen_target_id":  str((divergence_probe.get("chosen", {}) as Dictionary).get("target_id", "")),
				"directive_pull":    float(divergence_result.get("directive_pull", 0.0)),
				"self_margin":       float(divergence_result.get("self_margin", 0.0)),
				"overrule_strength": float(divergence_result.get("overrule_strength", 0.0)),
				"decision_scale":    float(divergence_result.get("decision_scale", 0.0)),
				"contest_ratio":     float(divergence_result.get("contest_ratio", 0.0)),
				"threshold":         float(divergence_result.get("threshold", 0.0)),
				"severity":          float(divergence_result.get("severity", 0.0)),
				"divergence_kind":   str(divergence_result.get("divergence_kind", "")),
				"primary_reason":    str(divergence_result.get("primary_reason", "")),
			})

	# V2-PROG-010: passive fear tick — small per-round fear reduction for echo faction, rank-scaled.
	var recovery_cfg: Dictionary = expr_cfg.get("fear_self_recovery", {})
	var passive_max: int = int(recovery_cfg.get("passive_max", 3))
	if str(_actor.get("actor_type", "")) == "echo" and passive_max > 0:
		var passive_tick: int = int(round(float(passive_max) * rank_strength))
		if passive_tick > 0:
			var pt_before: int = int(_actor.get("fear", 0))
			_actor["fear"] = clampi(pt_before - passive_tick, 0, 100)
			# Every other fear mutation emits a log line; this one did not, which made
			# the recovery budget impossible to audit. Effective (post-clamp) delta.
			logger.debug(t, "actor.fear_passive_tick", "Passive rank-scaled fear tick", {
				"actor_id": str(_actor.get("id", "")),
				"delta":    int(_actor["fear"]) - pt_before,
				"new_fear": int(_actor["fear"]),
			})

	# V2-PROG-010: active fear spike — fires when intent is identity-consistent (calling ∩ dominant_vector).
	_actor["_fear_spike_fired"] = false
	if str(_actor.get("actor_type", "")) == "echo":
		var spike: int = _compute_identity_fear_spike(intent, rank_strength, expr_cfg, cfg_data.get("actor", {}))
		if spike > 0:
			_actor["fear"] = clampi(int(_actor.get("fear", 0)) - spike, 0, 100)
			_actor["_fear_spike_fired"] = true
			logger.info(t, "actor.fear_spike", "Identity-consistent action reduced fear", {
				"actor_id":    str(_actor.get("id", "")),
				"action_type": str(intent.get("action_type", "")),
				"spike":       spike,
			})

	# PROG-010 / V2-VOICE-001: emotional event detection + bark selection
	var end_fear: int = int(_actor.get("fear", 0))
	var end_morale: int = int(_actor.get("morale", 50))
	var end_morale_tier: String = EmotionService.get_morale_tier(end_morale)
	var resilience_fired: bool = (_actor.get("emotion", {}) as Dictionary).get("_resilience_fired", false)
	var action_type: String = str(intent.get("action_type", ""))
	var arch: String = str(_actor.get("archetype_birth", ""))
	var calling: String = str(_actor.get("calling_origin", ""))
	# V2-VOICE-001: deterministic variation key — no RNG, same inputs → same line
	var variation_key: int = (t + str(_actor.get("id", "")).hash()) % 997
	# V2-PROG-012 Phase 11 playtest fix: config-driven divergence bark cooldown
	# — see data.maturity_expression.divergence.bark_cooldown_ticks.
	var divergence_bark_cooldown: int = int(expr_cfg.get("divergence", {}).get("bark_cooldown_ticks", 10))
	_select_bark(arch, calling, action_type, start_fear, end_fear, start_morale_tier, end_morale_tier,
		last_echo_standing, resilience_fired, intent.get("target_id", ""), variation_key, t, diverged_this_turn,
		divergence_bark_cooldown)
	# V2-VOICE-001: check if this actor should react to an ally's high-signal bark
	_check_reactive_bark(augmented_context, variation_key)
	# V2-VOICE-001: write bark fields to actor dict so round_bark_events pipeline can read them
	_actor["_bark_line"]        = _bark_line
	_actor["_bark_context"]     = _bark_context
	_actor["_bark_tier"]        = _bark_tier
	_actor["_bark_target_id"]   = _bark_target_id
	_actor["_bark_is_response"] = _bark_is_response
	# PROG-009: update per-round passive counters and skill state flags. Live
	# movement cutover defers this until FlowRuntime knows actual traversal.
	if not context.has("movement_context"):
		_update_passive_state(intent, context, t, null, logger)

	return intent


func update_passive_state_from_activation(intent: Dictionary, context: Dictionary, t: int,
		actual_moved: bool, logger: StructuredLogger = null) -> void:
	# Live activation can replace a planned move with its bounded fallback. Persist
	# that resolved action for next-turn repetition scoring, not the pre-activation plan.
	_last_intent = intent.duplicate(true)
	_actor["last_intent"] = { "action_type": str(intent.get("action_type", "")) }
	_update_passive_state(intent, context, t, actual_moved, logger)


## Returns a debug-friendly snapshot of this actor's current behavior state.
## Used by debug overlays and tests to verify module assignment, last intent, and vectors.
##
## Shape:
##   {
##     "actor_id": String,
##     "name": String,
##     "behavior_module": String,
##     "last_intent": Dictionary,
##     "vectors": { "scores": Dictionary<String,int>, "dominant_vector": String }
##   }
## vectors.scores contains all keys from actor_dict.vector_scores (any N keys — no hardcoded list).
func get_snapshot() -> Dictionary:
	return {
		"actor_id": _actor.get("id", ""),
		"name": _actor.get("name", ""),
		"behavior_module": _behavior_module.get_module_id(),
		"last_intent": _last_intent.duplicate(),
		"last_action": _last_action.duplicate(),  # ACTOR-004: post-resolution action snapshot
		# PROG-005: Layer 2 vector data for intent pipeline and debug display
		"vectors": VectorService.get_snapshot_data(_actor),
		# ACTOR-006: structure identity fields
		"is_structure":     _actor.get("is_structure", false),
		"movement_skipped": _movement_skipped,
		# ACTOR-007: morale influence fields
		"morale_tier":           _last_morale_tier,
		"action_weight_modifier": _last_morale_modifier,
		# ACTOR-008: death state fields
		"status":      "dead" if _actor.get("is_dead", false) else "alive",
		"death_round": int(_actor.get("death_round", 0)),
		# V2-PROG-006: expression band + identity traits
		"expression_band":   _expression_band,
		"resilience_traits": (_actor.get("resilience_traits", []) as Array).duplicate(),
		"leadership_traits": (_actor.get("leadership_traits", []) as Array).duplicate(),
		"active_leadership": _active_leadership,
		# PROG-010 / V2-VOICE-001: bark fields
		"bark_line":        _bark_line,
		"bark_context":     _bark_context,
		"bark_tier":        _bark_tier,
		"bark_target_id":   _bark_target_id,
		"bark_is_response": _bark_is_response,
	}


# ─── PROG-010 private helpers ────────────────────────────────────────────────

# V2-PROG-010: Computes active fear spike when winning intent is identity-consistent.
# Identity-consistent = calling base weight >= call_threshold AND dominant_vector mul >= vector_threshold.
# Returns 0 if conditions not met. Scales spike linearly from spike_min (rank 1) to spike_max (rank 9).
func _compute_identity_fear_spike(intent: Dictionary, rank_strength: float, expr_cfg: Dictionary, actor_cfg: Dictionary) -> int:
	var recovery_cfg: Dictionary  = expr_cfg.get("fear_self_recovery", {})
	var call_threshold: float     = float(recovery_cfg.get("identity_threshold_calling", 30))
	var vector_threshold: float   = float(recovery_cfg.get("identity_threshold_vector", 0.15))
	var spike_min: int            = int(recovery_cfg.get("active_spike_min", 3))
	var spike_max: int            = int(recovery_cfg.get("active_spike_max", 12))

	var action_type: String       = str(intent.get("action_type", ""))
	var calling_origin: String    = str(_actor.get("calling_origin", "uncalled"))
	var dominant_vector: String   = str(_actor.get("dominant_vector", ""))

	# Calling alignment — base weight in intent_weights_by_calling_origin
	var origin_table: Dictionary  = actor_cfg.get("intent_weights_by_calling_origin", {})
	var call_row: Dictionary      = origin_table.get(calling_origin, {})
	var calling_aligned: bool     = float(call_row.get(action_type, 0.0)) >= call_threshold

	# Vector alignment — dominant_vector multiplier in vector_action_muls
	var vector_aligned: bool = false
	if not dominant_vector.is_empty():
		var vec_table: Dictionary = actor_cfg.get("vector_action_muls", {})
		var v_row: Dictionary     = vec_table.get(action_type, {})
		vector_aligned = float(v_row.get(dominant_vector, 0.0)) >= vector_threshold

	if not (calling_aligned and vector_aligned):
		return 0
	return int(round(float(spike_min) + float(spike_max - spike_min) * rank_strength))


# Returns true if this echo is the only living echo on the board.
func _is_last_echo_standing(context: Dictionary) -> bool:
	if _actor.get("actor_type", "") != "echo":
		return false
	var my_id: String = str(_actor.get("id", ""))
	for a_v in context.get("all_actors", []):
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v as Dictionary
		if str(a.get("id", "")) == my_id:
			continue
		if a.get("actor_type", "") == "echo" and not a.get("is_dead", false):
			return false
	return true


# Selects and stores the highest-priority bark for this turn.
# Emotion-first priority system (see plan §Subtask 8 priority table).
func _select_bark(
	arch: String,
	calling: String,
	action_type: String,
	start_fear: int,
	end_fear: int,
	start_morale_tier: String,
	end_morale_tier: String,
	last_echo_standing: bool,
	resilience_fired: bool,
	target_id: Variant,
	variation_key: int = 0,
	t: int = 0,
	diverged: bool = false,
	divergence_cooldown_ticks: int = 10
) -> void:
	var context_key := ""
	var target := str(target_id) if target_id != null else ""

	# Priority 1: combat_last_stand
	if last_echo_standing:
		context_key = "combat_last_stand"
	# Priority 2: combat_resilient
	elif resilience_fired:
		context_key = "combat_resilient"
	# Priority 3: combat_fear_extreme (fear crossed 80)
	elif end_fear >= 80 and start_fear < 80:
		context_key = "combat_fear_extreme"
	# Priority 4: combat_fear_rising (fear crossed 60 or 40)
	elif (end_fear >= 60 and start_fear < 60) or (end_fear >= 40 and start_fear < 40):
		context_key = "combat_fear_rising"
	# Priority 5: combat_morale_falling (morale dropped a tier)
	elif start_morale_tier != end_morale_tier and _morale_tier_rank(end_morale_tier) < _morale_tier_rank(start_morale_tier):
		context_key = "combat_morale_falling"
	# Priority 5.5: combat_divergence — V2-PROG-012 Phase 5: her judgment out-voted
	# the Directive this turn (see DivergenceDetector.gd). Tier 2 priority — rarer
	# than the emotional-crisis contexts above it, but more narratively important
	# than a routine taunt/attack bark.
	# V2-PROG-012 Phase 11 playtest fix: Phase 5 kept this OUT of
	# _HIGH_PRIORITY_BARK on the belief that divergence fires often enough (~33
	# per encounter, measured across all actors including enemies) that routine
	# suppression was needed. Post-Phase-6 recalibration + faction gating, the
	# measured real rate for Echoes alone is ~0.73 events/encounter, and Phase 5's
	# own measurement found only 2 of 7 such events actually surfaced a bark —
	# i.e. the general _bark_next_t cooldown was silencing the single rarest,
	# most narratively meaningful bark in the game almost every time it earned
	# one. combat_divergence is now exempt from _bark_next_t (same treatment as
	# the Tier 1 contexts above) and instead gated by its own, shorter,
	# divergence-specific cooldown (_divergence_bark_next_t, set below) so the
	# same Echo still can't narrate divergence on two consecutive turns, without
	# the routine-chatter gate swallowing a later, genuinely separate one.
	elif diverged:
		context_key = "combat_divergence"
	# Priority 6: combat_taunt
	elif action_type == "actor.taunt":
		context_key = "combat_taunt"
		_bark_target_id = target
	# Priority 7: combat_inspired — morale inspired + aggressive action
	elif end_morale_tier == "inspired" and action_type == "melee_attack":
		context_key = "combat_inspired"
		_bark_target_id = target
	# Priority 8: combat_banter — low fear + steady/inspired morale
	elif int(_actor.get("fear", 0)) < 30 \
			and (end_morale_tier == "steady" or end_morale_tier == "inspired"):
		context_key = "combat_banter"
	# Priority 8.5: combat_calling_skill — actor used a calling-specific skill action
	elif action_type in ["actor.interpose", "actor.hold_ground", "actor.steady_call",
			"actor.mark", "actor.withdraw", "actor.read_field", "actor.reveal"]:
		context_key = "combat_calling_skill"
	# Priority 8.6: combat_identity_spike — V2-PROG-010: identity-consistent action reduced fear
	elif bool(_actor.get("_fear_spike_fired", false)):
		context_key = "combat_identity_spike"
		_actor["_fear_spike_fired"] = false
	# Priority 9: combat_attack
	elif action_type == "melee_attack":
		context_key = "combat_attack"
		_bark_target_id = target
	# Priority 10: combat_guard
	elif action_type == "actor.guard":
		context_key = "combat_guard"
	# Else: silent (move, idle, etc.)

	if context_key.is_empty():
		return

	# V2-VOICE-002: cooldown gate — routine barks suppressed until _bark_next_t.
	# High-priority contexts always fire and reset the cooldown.
	const _HIGH_PRIORITY_BARK: Array = [
		"combat_last_stand", "combat_resilient",
		"combat_fear_extreme", "combat_fear_rising", "combat_morale_falling"
	]
	# V2-PROG-012 Phase 11 playtest fix: combat_divergence is exempt from the
	# routine _bark_next_t gate (see the Priority 5.5 comment above) but is not
	# unconditional like Tier 1 — it gets its own, separate, shorter cooldown so
	# the same Echo cannot voice divergence on two consecutive turns.
	if context_key == "combat_divergence":
		if t < int(_actor.get("_divergence_bark_next_t", 0)):
			return
	elif not _HIGH_PRIORITY_BARK.has(context_key):
		if t < int(_actor.get("_bark_next_t", 0)):
			return

	_bark_context = context_key
	_bark_tier = _expression_band

	# Try expression-shout first (emotion × band × archetype × calling); V2-VOICE-001: variation_key
	var line := ShoutBank.get_expression_shout(context_key, arch, _expression_band, calling, variation_key)
	if line.is_empty() or line == ShoutBank._FALLBACK:
		# Fall back to legacy get_shout for tier-based contexts (arrival, combat stubs)
		var traits_v: Variant = _actor.get("traits", {})
		var traits: Dictionary = traits_v as Dictionary if traits_v is Dictionary else {}
		var trait_tier := ShoutBank.get_tier(
			int(traits.get("courage", 50)),
			int(traits.get("wisdom",  50)),
			int(traits.get("faith",   50))
		)
		var legacy := ShoutBank.get_shout(context_key, arch, trait_tier, variation_key)
		if not legacy.is_empty() and legacy != ShoutBank._FALLBACK:
			line = legacy
	if not line.is_empty() and line != ShoutBank._FALLBACK:
		_bark_line = line
		_actor["_bark_next_t"] = t + _compute_bark_cooldown()
		# V2-PROG-012 Phase 11 playtest fix: divergence-specific cooldown —
		# transient-only, same pattern as _bark_next_t (no new save field).
		if context_key == "combat_divergence":
			_actor["_divergence_bark_next_t"] = t + divergence_cooldown_ticks


# Returns an ordinal rank for morale tiers (higher = better).
static func _morale_tier_rank(tier: String) -> int:
	match tier:
		"inspired": return 3
		"steady":   return 2
		"shaken":   return 1
	return 0  # broken


# V2-VOICE-002: Tick gap before next routine bark (~3–6 rounds at 7 ticks/round).
func _compute_bark_cooldown() -> int:
	var morale: String = str(_actor.get("morale", "steady"))
	var fear: int = int(_actor.get("fear", 0))
	if morale == "inspired" or fear >= 60:
		return 14   # ~2 rounds
	elif morale == "broken":
		return 35   # ~5 rounds
	elif morale == "shaken" or fear >= 40:
		return 21   # ~3 rounds
	return 28       # ~4 rounds (default steady)


## V2-VOICE-001: Called by FlowRuntime after CombatService.resolve_action() resolves.
## Overrides bark with combat_ko when this turn's attack was a kill — unless a Tier 1
## bark (last_stand / fear_extreme / resilient) is already set for this actor.
func finalize_combat_bark(is_kill: bool, variation_key: int) -> void:
	if not is_kill:
		return
	# Tier 1 barks are never overridden by ko
	const _TIER1: Array = ["combat_last_stand", "combat_fear_extreme", "combat_resilient"]
	if _bark_context in _TIER1:
		return
	var arch: String = str(_actor.get("archetype_birth", ""))
	var calling: String = str(_actor.get("calling_origin", ""))
	_bark_context = "combat_ko"
	_bark_tier    = _expression_band
	var line := ShoutBank.get_expression_shout("combat_ko", arch, _expression_band, calling, variation_key)
	if line.is_empty() or line == ShoutBank._FALLBACK:
		line = ShoutBank.get_shout("combat_ko", arch, ShoutBank.get_tier(
			int(_actor.get("traits", {}).get("courage", 50)),
			int(_actor.get("traits", {}).get("wisdom",  50)),
			int(_actor.get("traits", {}).get("faith",   50))
		), variation_key)
	_bark_line = line
	# Mirror back to actor dict so FlowRuntime sees the updated bark
	_actor["_bark_line"]    = _bark_line
	_actor["_bark_context"] = _bark_context
	_actor["_bark_tier"]    = _bark_tier


## V2-VOICE-001: Check if this actor should respond to a high-signal bark from a same-faction ally.
## Only fires for forming+ expression bands. Does NOT override Tier 1 own barks.
## Sets _bark_is_response = true and uses combat_rally_ally context when triggered.
func _check_reactive_bark(context: Dictionary, variation_key: int) -> void:
	# Nascent actors don't react
	if _expression_band == "nascent":
		return
	# Tier 1 own barks are never overridden
	const _TIER1_R: Array = ["combat_last_stand", "combat_fear_extreme", "combat_resilient", "combat_ko"]
	if _bark_context in _TIER1_R:
		return
	var round_bark_events: Array = context.get("round_bark_events", [])
	if round_bark_events.is_empty():
		return
	var voice_cfg: Dictionary = context.get("cfg", {}).get("data", {}).get("voice", {})
	var reactive_range: int   = int(voice_cfg.get("reactive_range", 4))
	var high_signal: Array    = voice_cfg.get("reactive_high_signal_contexts", [
		"combat_last_stand", "combat_fear_extreme", "combat_resilient", "combat_taunt", "combat_ko"
	])
	var my_faction: String    = str(_actor.get("faction", ""))
	var my_pos: Dictionary    = _actor.get("grid_pos", {})
	for event_v in round_bark_events:
		if not (event_v is Dictionary):
			continue
		var event := event_v as Dictionary
		if not (str(event.get("bark_context", "")) in high_signal):
			continue
		if str(event.get("faction", "")) != my_faction:
			continue
		var their_pos_v: Variant = event.get("grid_pos")
		if not (their_pos_v is Dictionary):
			continue
		var their_pos := their_pos_v as Dictionary
		var dc: int = absi(int(my_pos.get("col", 0)) - int(their_pos.get("col", 0)))
		var dr: int = absi(int(my_pos.get("row", 0)) - int(their_pos.get("row", 0)))
		if maxi(dc, dr) > reactive_range:
			continue
		# Qualifying event — fire rally_ally reaction
		var arch: String    = str(_actor.get("archetype_birth", ""))
		var calling: String = str(_actor.get("calling_origin", ""))
		var line := ShoutBank.get_expression_shout("combat_rally_ally", arch, _expression_band, calling, variation_key)
		if not line.is_empty() and line != ShoutBank._FALLBACK:
			_bark_context     = "combat_rally_ally"
			_bark_tier        = _expression_band
			_bark_line        = line
			_bark_target_id   = str(event.get("actor_id", ""))
			_bark_is_response = true
		break  # React to first qualifying event only


# Applies every configured Whole-band morale/fear leadership trait.
# Returns the first trait ID that fired for active_leadership snapshot compatibility.
func _apply_leadership(
	leadership_traits: Array,
	expr_cfg: Dictionary,
	context: Dictionary,
	logger: StructuredLogger,
	t: int
) -> String:
	var all_actors: Array = context.get("all_actors", [])
	var first_active := ""
	var round_number := int(context.get("round", 0))
	for trait_v in leadership_traits:
		var trait_id := str(trait_v)
		var effect := LeadershipEmotionService.get_trait_effect(trait_id, expr_cfg)
		if effect.is_empty():
			continue
		var radius := LeadershipEmotionService.get_trait_radius(
			_actor, trait_id, expr_cfg, _calling_behavior)
		var allies := LeadershipEmotionService.get_nearby_living_echo_allies(
			_actor, all_actors, radius)
		if allies.is_empty():
			continue
		# Passive aura/event traits are resolved only by their combat emotion choke points.
		if trait_id in ["kill_momentum", "fearless_example", "morale_anchor", \
				"calm_transmission", "block_contagion"]:
			continue
		var fired := false
		match trait_id:
			"inspire_aura", "steady_presence":
				var morale_tick := int(effect.get("morale_per_round", 0))
				var allies_affected := 0
				if morale_tick > 0:
					for ally_v in allies:
						var ally: Dictionary = ally_v
						var previous_morale := int(ally.get("morale", 50))
						ally["morale"] = clampi(previous_morale + morale_tick, 0, 100)
						if int(ally["morale"]) != previous_morale:
							allies_affected += 1
						# S14b Tier 2 (support): effective morale delivered to this ally.
						_credit_support_tally("morale_given", int(ally["morale"]) - previous_morale)
					fired = allies_affected > 0
				if fired:
					_credit_support_tally("support_actions", 1)
					logger.info(t, "actor.leadership.morale_tick", "Leadership morale tick", {
						"actor_id": _actor.get("id", ""), "trait_id": trait_id,
						"tick_value": morale_tick, "allies_affected": allies_affected,
					})
			"calm_fear", "fear_read":
				var fear_reduction := int(effect.get("fear_reduction",
					effect.get("fear_reduction_per_round", 0)))
				var most_feared := _get_most_feared_ally(allies)
				if fear_reduction > 0 and not most_feared.is_empty():
					var previous_fear := int(most_feared.get("fear", 0))
					most_feared["fear"] = clampi(previous_fear - fear_reduction, 0, 100)
					fired = int(most_feared["fear"]) != previous_fear
					# S14b Tier 2 (support): fear relieved on the most-feared ally.
					_credit_support_tally("fear_relieved", previous_fear - int(most_feared["fear"]))
				if fired:
					_credit_support_tally("support_actions", 1)
					logger.info(t, "actor.leadership.fear_reduce", "Leadership fear reduced", {
						"actor_id": _actor.get("id", ""), "trait_id": trait_id,
						"target_id": most_feared.get("id", ""),
						"fear_reduction": fear_reduction, "new_fear": most_feared["fear"],
					})
			"rally_call":
				var rally_once := bool(effect.get("once_per_combat", false))
				if not rally_once or not _actor.get("_rally_call_used", false):
					var morale_boost := int(effect.get("morale_boost", 0))
					var allies_affected := 0
					if morale_boost > 0:
						for ally_v in allies:
							var ally: Dictionary = ally_v
							var previous_morale := int(ally.get("morale", 50))
							ally["morale"] = clampi(previous_morale + morale_boost, 0, 100)
							if int(ally["morale"]) != previous_morale:
								allies_affected += 1
							# S14b Tier 2 (support): effective morale delivered to this ally.
							_credit_support_tally("morale_given", int(ally["morale"]) - previous_morale)
					fired = allies_affected > 0
					if fired:
						_credit_support_tally("support_actions", 1)
						if rally_once:
							_actor["_rally_call_used"] = true
						logger.info(t, "actor.leadership.rally_call", "Leadership rally fired", {
							"actor_id": _actor.get("id", ""), "morale_boost": morale_boost,
							"allies_affected": allies_affected,
						})
			"morale_forecast":
				var forecast_once := bool(effect.get("once_per_combat", false))
				if not forecast_once or not _actor.get("_morale_forecast_used", false):
					var lock_rounds := maxi(0, int(effect.get("morale_lock_rounds", 0)))
					fired = lock_rounds > 0
					if fired:
						_actor["_morale_forecast_until_round"] = round_number + lock_rounds - 1
						if forecast_once:
							_actor["_morale_forecast_used"] = true
						logger.info(t, "actor.leadership.morale_forecast", "Leadership morale forecast activated", {
							"actor_id": _actor.get("id", ""), "rounds": lock_rounds,
							"until_round": _actor["_morale_forecast_until_round"],
						})
		if fired and first_active.is_empty():
			first_active = trait_id
	return first_active


## S14b Tier 2: accumulate a support metric onto _actor's transient _support_tally dict.
## FlowRuntime._resolve_next_actor folds this into EncounterContext.echo_action_logs once per
## turn (echo-gated) and erases it. Additive bookkeeping only — never influences a decision.
## amount == 0 is a no-op (e.g. an ally already at the morale/fear clamp).
func _credit_support_tally(field: String, amount: int) -> void:
	if amount == 0:
		return
	var st: Dictionary = _actor.get("_support_tally", {})
	st[field] = int(st.get(field, 0)) + amount
	_actor["_support_tally"] = st


func _get_most_feared_ally(allies: Array) -> Dictionary:
	var most_feared: Dictionary = {}
	var highest_fear := -1
	for ally_v in allies:
		if not (ally_v is Dictionary):
			continue
		var ally: Dictionary = ally_v
		var ally_fear := int(ally.get("fear", 0))
		if ally_fear > highest_fear:
			highest_fear = ally_fear
			most_feared = ally
	return most_feared


# PROG-009: Update per-round passive state counters after each turn.
# Warder: tracks anchor_rounds for guard/protect_ally bonus (+8 per round, cap 3 rounds = +24).
# Steward: tracks stationary_rounds for soft-taunt eligibility.
# Skill once-per-combat flags are set here when the skill fires.
# Skill cooldowns (read_field, withdraw) are ticked at turn START instead.
## `logger` is optional so existing direct-drive test callers keep their signature.
## When present, the two fear-relieving passives below emit an audit line — without
## it the Steward/Seer fear relief is invisible to the ledger.
func _update_passive_state(intent: Dictionary, context: Dictionary, t: int,
		actual_moved_override: Variant = null, logger: StructuredLogger = null) -> void:
	var action: String         = str(intent.get("action_type", ""))
	var calling_origin: String = str(_actor.get("calling_origin", ""))
	var moved: bool = bool(actual_moved_override) if actual_moved_override != null \
		else (action == "actor.move" or action == "actor.withdraw")

	match calling_origin:
		"warder":
			if moved:
				_actor["_anchor_rounds"] = 0
			else:
				_actor["_anchor_rounds"] = mini(int(_actor.get("_anchor_rounds", 0)) + 1, 3)
		"steward":
			if moved:
				_actor["_stationary_rounds"] = 0
			else:
				_actor["_stationary_rounds"] = int(_actor.get("_stationary_rounds", 0)) + 1
		"seer":
			if action == "actor.read_field":
				var streak: int     = int(_actor.get("_read_field_streak", 0)) + 1
				var max_streak: int = 3
				_actor["_read_field_streak"] = streak
				if streak >= max_streak:
					_actor["_read_field_streak"]  = 0
					_actor["_read_field_cooldown"] = 1
			else:
				_actor["_read_field_streak"] = 0  # streak resets on any other action
			# Seer idle_fear_aura — when idle wins, reduce fear of nearby allies
			if action == "actor.idle":
				var aura_val: int     = int(_calling_behavior.get("idle_fear_aura", 3))
				var aura_radius: int  = int(_calling_behavior.get("leadership_radius", 5))
				var my_pos_s: Dictionary = _actor.get("grid_pos", {})
				var ifa_fired: bool = false
				var ifa_count: int = 0
				var ifa_total: int = 0
				if not my_pos_s.is_empty():
					for a_sv in context.get("all_actors", []):
						if not (a_sv is Dictionary): continue
						var a_s: Dictionary = a_sv
						if a_s.get("is_dead", false): continue
						if str(a_s.get("id", "")) == str(_actor.get("id", "")): continue
						if str(a_s.get("faction", "")) == str(_actor.get("faction", "")):
							var a_s_pos: Dictionary = a_s.get("grid_pos", {})
							if not a_s_pos.is_empty() and \
									GridService.chebyshev_distance(my_pos_s, a_s_pos) <= aura_radius:
								var ifa_before: int = int(a_s.get("fear", 0))
								a_s["fear"] = clampi(ifa_before - aura_val, 0, 100)
								# S14b Tier 2 (support): Seer idle aura relieves ally fear.
								_credit_support_tally("fear_relieved", ifa_before - int(a_s["fear"]))
								ifa_total += ifa_before - int(a_s["fear"])
								ifa_count += 1
								ifa_fired = true
				if ifa_fired:
					_credit_support_tally("support_actions", 1)
					if logger != null:
						logger.debug(t, "actor.fear_idle_aura", "Seer idle aura relieved ally fear", {
							"actor_id":       str(_actor.get("id", "")),
							"affected_count": ifa_count,
							"total_delta":    -ifa_total,
						})
		"ranger":
			if action == "actor.withdraw":
				_actor["_withdraw_cooldown"] = 1

	# Once-per-combat flags
	if action == "actor.steady_call":
		_actor["_steady_call_used"] = true
	if action == "actor.reveal":
		_actor["_reveal_used"] = true

	# Apply mark to target for 2 rounds
	if action == "actor.mark":
		var mark_target: String = str(intent.get("target_id", ""))
		if not mark_target.is_empty():
			for ma_v in context.get("all_actors", []):
				if not (ma_v is Dictionary): continue
				var ma: Dictionary = ma_v
				if str(ma.get("id", "")) == mark_target:
					ma["marked_by"]       = str(_actor.get("id", ""))
					ma["_mark_duration"]  = 2
					break

	# Tick mark duration — decrement on the marked actor's turn (we do it each round here)
	if _actor.has("_mark_duration"):
		var dur: int = int(_actor["_mark_duration"]) - 1
		if dur <= 0:
			_actor.erase("marked_by")
			_actor.erase("_mark_duration")
		else:
			_actor["_mark_duration"] = dur

	# Apply revealed_by_seer to target for 3 rounds
	if action == "actor.reveal":
		var reveal_target: String = str(intent.get("target_id", ""))
		if not reveal_target.is_empty():
			for rv_v in context.get("all_actors", []):
				if not (rv_v is Dictionary): continue
				var rv: Dictionary = rv_v
				if str(rv.get("id", "")) == reveal_target:
					rv["revealed_by_seer"]    = str(_actor.get("id", ""))
					rv["_reveal_duration"]    = 3
					break

	# Tick reveal duration
	if _actor.has("_reveal_duration"):
		var rdur: int = int(_actor["_reveal_duration"]) - 1
		if rdur <= 0:
			_actor.erase("revealed_by_seer")
			_actor.erase("_reveal_duration")
		else:
			_actor["_reveal_duration"] = rdur

	# Apply hold_ground effects (Steward)
	if action == "actor.hold_ground":
		var hg_radius: int       = 2
		var hg_morale_bonus: int = 3
		var my_pos_hg: Dictionary = _actor.get("grid_pos", {})
		var hg_fired: bool = false
		if not my_pos_hg.is_empty():
			for hg_av in context.get("all_actors", []):
				if not (hg_av is Dictionary): continue
				var hg_a: Dictionary = hg_av
				if hg_a.get("is_dead", false): continue
				if str(hg_a.get("faction", "")) == str(_actor.get("faction", "")) \
						and str(hg_a.get("id", "")) != str(_actor.get("id", "")):
					var hg_pos: Dictionary = hg_a.get("grid_pos", {})
					if not hg_pos.is_empty() and GridService.chebyshev_distance(my_pos_hg, hg_pos) <= hg_radius:
						var hg_before: int = int(hg_a.get("morale", 50))
						hg_a["morale"] = clampi(hg_before + hg_morale_bonus, 0, 100)
						# S14b Tier 2 (support): effective morale delivered to this ally.
						_credit_support_tally("morale_given", int(hg_a["morale"]) - hg_before)
						hg_fired = true
		if hg_fired:
			_credit_support_tally("support_actions", 1)

	# Apply steady_call effects (Steward)
	if action == "actor.steady_call":
		var sc_radius: int    = int(_calling_behavior.get("leadership_radius", 4))
		# Was a bare literal 20 — the largest single fear value anywhere in the system,
		# and invisible to both config and the log. Default preserves current behaviour.
		var sc_fear_red: int  = int(_calling_behavior.get("steady_call_fear_reduction", 20))
		var my_pos_sc: Dictionary = _actor.get("grid_pos", {})
		var sc_fired: bool = false
		var sc_count: int = 0
		var sc_total: int = 0
		if not my_pos_sc.is_empty():
			for sc_av in context.get("all_actors", []):
				if not (sc_av is Dictionary): continue
				var sc_a: Dictionary = sc_av
				if sc_a.get("is_dead", false): continue
				if str(sc_a.get("faction", "")) == str(_actor.get("faction", "")):
					var sc_pos: Dictionary = sc_a.get("grid_pos", {})
					if not sc_pos.is_empty() and GridService.chebyshev_distance(my_pos_sc, sc_pos) <= sc_radius:
						var sc_before: int = int(sc_a.get("fear", 0))
						sc_a["fear"] = clampi(sc_before - sc_fear_red, 0, 100)
						# S14b Tier 2 (support): credit fear relieved on ALLIES only (exclude self).
						if str(sc_a.get("id", "")) != str(_actor.get("id", "")):
							_credit_support_tally("fear_relieved", sc_before - int(sc_a["fear"]))
							sc_total += sc_before - int(sc_a["fear"])
							sc_count += 1
							sc_fired = true
		if sc_fired:
			_credit_support_tally("support_actions", 1)
			if logger != null:
				logger.debug(t, "actor.fear_steady_call", "Steward steady_call relieved ally fear", {
					"actor_id":       str(_actor.get("id", "")),
					"affected_count": sc_count,
					"total_delta":    -sc_total,
					"per_ally":       sc_fear_red,
				})

	# Guard: set guard_state on self (interpose sets it on the protected ally below).
	if action == "actor.guard":
		_actor["guard_state"] = true

	# Apply interpose effects (Warder — grant guard_state to protected ally + morale boost to interposer).
	if action == "actor.interpose":
		var emo_cfg_ip: Dictionary = context.get("cfg", {}).get("data", {}).get("combat", {}).get("emotion", {})
		var interpose_morale: int = int(emo_cfg_ip.get("morale_on_interpose", 5))
		var interpose_target: String = str(intent.get("target_id", ""))
		var ip_granted: bool = false
		if not interpose_target.is_empty():
			for ip_v in context.get("all_actors", []):
				if not (ip_v is Dictionary): continue
				var ip_a: Dictionary = ip_v
				if str(ip_a.get("id", "")) == interpose_target:
					ip_a["guard_state"] = true
					ip_granted = true
					break
		# S14b Tier 2 (support): count the guard granted to an ally + the support action.
		# The interposer's own +morale is a self-credit, excluded from morale_given.
		if ip_granted:
			_credit_support_tally("guards_granted", 1)
			_credit_support_tally("support_actions", 1)
		_actor["morale"] = mini(100, int(_actor.get("morale", 50)) + interpose_morale)

	if t > 0:  # suppress unused-variable warning for t in Godot
		pass
