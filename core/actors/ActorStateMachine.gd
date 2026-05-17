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
##   Pass {} (default) to use BehaviorArbiter's hardcoded defaults — safe for all existing callers.
func _init(actor_dict: Dictionary, behavior_module: BehaviorModule = null, actor_cfg: Dictionary = {}) -> void:
	_actor = actor_dict
	if behavior_module != null:
		_behavior_module = behavior_module
	elif actor_dict.get("actor_type", "") in ["echo", "enemy"]:
		_behavior_module = BehaviorArbiter.new(actor_cfg)  # ACTOR-005: echo + enemy actors use weighted arbiter
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

	# V2-PROG-006: compute maturity-expression band + calling behavior
	var cfg_data: Dictionary = context.get("cfg", {}).get("data", {})
	var expr_cfg: Dictionary = cfg_data.get("maturity_expression", {})
	var band_by_standing: Dictionary = expr_cfg.get("band_by_standing", {})
	var calling_cfg: Dictionary = expr_cfg.get("calling_behavior", {})
	_expression_band = MaturityExpressionService.get_expression_band(int(_actor.get("rank", 1)), band_by_standing)
	_calling_behavior = MaturityExpressionService.get_calling_behavior(_actor, calling_cfg)

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

	# COMBAT-003 + V2-PROG-006: Absolute Fear Rule — dynamic threshold based on expression band + last stand.
	# PROG-009: per-calling override from calling_behavior.absolute_fear_threshold.
	# GDD: "fear_current drives refusal/guard/retreat; can override ALL at extreme threshold."
	var fear_threshold: int = int(_calling_behavior.get("absolute_fear_threshold", \
		cfg_data.get("emotion", {}).get("fear_threshold", 80)))
	if last_echo_standing:
		var ls_thresholds: Dictionary = expr_cfg.get("last_stand_fear_threshold", {})
		if _expression_band == "whole":
			fear_threshold = int(ls_thresholds.get("whole", 95))
		elif _expression_band == "grounded":
			fear_threshold = int(ls_thresholds.get("grounded", 88))
	# suppress_panic_spiral: raises threshold +5 on top of band bonus
	if "suppress_panic_spiral" in resilience_traits \
			and (_expression_band == "grounded" or _expression_band == "whole"):
		fear_threshold = min(fear_threshold + 5, 100)

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
	var augmented_context := context.duplicate()
	augmented_context["expression_band"]  = _expression_band
	augmented_context["calling_behavior"] = _calling_behavior
	augmented_context["resilience_traits"] = resilience_traits
	augmented_context["leadership_traits"] = leadership_traits

	# PROG-009: inject equipped_skills + skills_cfg into context for BehaviorArbiter.
	# equipped_skills: slot → skill_id dict set by FlowSkillLoadoutState at encounter start.
	augmented_context["equipped_skills"] = _actor.get("equipped_skills", {})
	augmented_context["skills_cfg"]      = cfg_data.get("skills", {})

	var intent: Dictionary = _behavior_module.select_intent(augmented_context)
	_last_intent = intent
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
	_select_bark(arch, calling, action_type, start_fear, end_fear, start_morale_tier, end_morale_tier,
		last_echo_standing, resilience_fired, intent.get("target_id", ""), variation_key, t)
	# V2-VOICE-001: check if this actor should react to an ally's high-signal bark
	_check_reactive_bark(augmented_context, variation_key)
	# V2-VOICE-001: write bark fields to actor dict so round_bark_events pipeline can read them
	_actor["_bark_line"]        = _bark_line
	_actor["_bark_context"]     = _bark_context
	_actor["_bark_tier"]        = _bark_tier
	_actor["_bark_target_id"]   = _bark_target_id
	_actor["_bark_is_response"] = _bark_is_response
	# PROG-009: Ranger passive — threat-minimising move.
	# When a Ranger chooses actor.move (or actor.withdraw), redirect target_pos
	# away from the nearest enemy so they reposition rather than advance.
	var _calling_p: String = str(_actor.get("calling_origin", ""))
	if _calling_p == "ranger" and str(intent.get("action_type", "")) == "actor.move" \
			and not _movement_skipped:
		var _my_pos_r: Dictionary = _actor.get("grid_pos", {})
		var _ne_r: Dictionary = ActorService.get_nearest_enemy(_actor, context.get("all_actors", []))
		if not _ne_r.is_empty() and not _my_pos_r.is_empty():
			var _e_col: int = int(_ne_r.get("grid_pos", {}).get("col", 0))
			var _e_row: int = int(_ne_r.get("grid_pos", {}).get("row", 0))
			var _mc: int    = int(_my_pos_r.get("col", 0))
			var _mr: int    = int(_my_pos_r.get("row", 0))
			var _nx: int    = 0 if _mc == _e_col else (1 if _mc > _e_col else -1)
			var _ny: int    = 0 if _mr == _e_row else (1 if _mr > _e_row else -1)
			var _bc: Dictionary = context.get("board_cfg", {})
			var _bc_w: int  = int(_bc.get("board_cols", 10))
			var _bc_h: int  = int(_bc.get("board_rows", 10))
			intent["target_pos"] = {
				"col": clampi(_mc + _nx * 3, 0, _bc_w - 1),
				"row": clampi(_mr + _ny * 3, 0, _bc_h - 1),
			}

	# GRID-005: resolve movement when the behavior module requests a move.
	if intent.get("action_type", "") == "actor.move" and not _movement_skipped:
		var target_pos: Dictionary = intent.get("target_pos", {})
		if not target_pos.is_empty():
			# Build occupied set: all living actors except self (1 actor per cell).
			var my_id: String = str(_actor.get("id", ""))
			var occupied: Array = []
			for a_v in context.get("all_actors", []):
				if a_v is Dictionary \
						and str(a_v.get("id", "")) != my_id \
						and not a_v.get("is_dead", false):
					occupied.append(a_v.get("grid_pos", {}))
			var move_result: Dictionary = GridService.move_toward(
					_actor, target_pos, context.get("board_cfg", {}), occupied)
			logger.info(t, "actor.moved", "Actor moved", {
				"actor_id": _actor.get("id", ""),
				"from_pos": move_result["from_pos"],
				"to_pos":   move_result["to_pos"],
			})

	# COMBAT-006: resolve purify shrine action — applies a drain-reduction stack to the shrine.
	if intent.get("action_type", "") == "actor.purify_shrine":
		var shrine_cfg_data: Dictionary = \
			context.get("cfg", {}).get("data", {}).get("combat", {}).get("shrine", {})
		var shrine_ref: Dictionary = {}
		for a_v in context.get("all_actors", []):
			if a_v is Dictionary and a_v.get("is_structure", false) \
					and not a_v.get("is_dead", false):
				shrine_ref = a_v
				break
		if not shrine_ref.is_empty():
			ShrineService.apply_purify_stack(shrine_ref, _actor, shrine_cfg_data)
			logger.info(t, "actor.purified_shrine", "Purify applied to shrine", {
				"actor_id":     _actor.get("id", ""),
				"shrine_id":    shrine_ref.get("id", ""),
				"stacks_count": shrine_ref.get("purify_stacks", []).size(),
				"cooldown_set": _actor.get("purify_cooldown", 0),
			})
			# Trigger 4: shrine purify morale — purifier gains boost; allies receive ripple.
			var emo_cfg_sh: Dictionary = context.get("cfg", {}).get("data", {}).get("combat", {}).get("emotion", {})
			var shrine_morale: int = int(emo_cfg_sh.get("morale_on_shrine_purify", 5))
			var shrine_ripple: int = int(emo_cfg_sh.get("morale_ripple_shrine_purify", 2))
			_actor["morale"] = mini(100, int(_actor.get("morale", 50)) + shrine_morale)
			for rp_v in context.get("all_actors", []):
				if not (rp_v is Dictionary): continue
				var rp_a: Dictionary = rp_v
				if str(rp_a.get("id", "")) != str(_actor.get("id", "")) \
						and str(rp_a.get("faction", "")) == "echo" \
						and not rp_a.get("is_dead", false):
					rp_a["morale"] = mini(100, int(rp_a.get("morale", 50)) + shrine_ripple)

	# PROG-009: update per-round passive counters and skill state flags.
	_update_passive_state(intent, context, t)

	return intent


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
	t: int = 0
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
	if not _HIGH_PRIORITY_BARK.has(context_key):
		if t < int(_actor.get("_bark_next_t", 0)):
			return

	_bark_context = context_key
	_bark_tier = _expression_band

	# Try expression-shout first (emotion × band × archetype × calling); V2-VOICE-001: variation_key
	var line := ShoutBank.get_expression_shout(context_key, arch, _expression_band, calling, variation_key)
	if line.is_empty() or line == ShoutBank._FALLBACK:
		# Fall back to legacy get_shout for tier-based contexts (arrival, combat stubs)
		var trait_tier := ShoutBank.get_tier(
			int(_actor.get("traits", {}).get("courage", 50)),
			int(_actor.get("traits", {}).get("wisdom",  50)),
			int(_actor.get("traits", {}).get("faith",   50))
		)
		var legacy := ShoutBank.get_shout(context_key, arch, trait_tier, variation_key)
		if not legacy.is_empty() and legacy != ShoutBank._FALLBACK:
			line = legacy
	if not line.is_empty() and line != ShoutBank._FALLBACK:
		_bark_line = line
		_actor["_bark_next_t"] = t + _compute_bark_cooldown()


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


# Activates the first applicable leadership trait and applies radius effects.
# Returns the trait ID that fired, or "" if none.
func _apply_leadership(
	leadership_traits: Array,
	expr_cfg: Dictionary,
	context: Dictionary,
	logger: StructuredLogger,
	t: int
) -> String:
	var my_pos: Dictionary = _actor.get("grid_pos", { "col": 0, "row": 0 })
	var leadership_radius: int = int(_calling_behavior.get("leadership_radius", 3))
	var effects_cfg: Dictionary = expr_cfg.get("leadership_trait_effects", {})

	# Gather living allies within radius
	var nearby_allies: Array = []
	for a_v in context.get("all_actors", []):
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v as Dictionary
		if a.get("actor_type", "") != "echo":
			continue
		if a.get("is_dead", false):
			continue
		if str(a.get("id", "")) == str(_actor.get("id", "")):
			continue
		var apos: Dictionary = a.get("grid_pos", {})
		if GridService.chebyshev_distance(my_pos, apos) <= leadership_radius:
			nearby_allies.append(a)

	# Try each leadership trait in order; fire the first one that has an effect
	for trait_id in leadership_traits:
		var effect: Dictionary = effects_cfg.get(trait_id, {})
		if effect.is_empty():
			continue
		var effect_type: String = str(effect.get("type", ""))
		match effect_type:
			"morale_tick":
				var tick_val: int = int(effect.get("value", 3))
				for ally in nearby_allies:
					ally["morale"] = clampi(int(ally.get("morale", 50)) + tick_val, 0, 100)
				logger.info(t, "actor.leadership.morale_tick", "Leadership morale tick", {
					"actor_id":       _actor.get("id", ""),
					"trait_id":       trait_id,
					"tick_value":     tick_val,
					"allies_affected": nearby_allies.size(),
				})
				return trait_id
			"fear_reduce":
				# calm_fear: reduce the most-feared ally's fear
				var reduce_val: int = int(effect.get("value", 15))
				var most_feared: Dictionary = {}
				var highest_fear: int = -1
				for ally in nearby_allies:
					if int(ally.get("fear", 0)) > highest_fear:
						highest_fear = int(ally.get("fear", 0))
						most_feared = ally
				if not most_feared.is_empty():
					most_feared["fear"] = clampi(int(most_feared.get("fear", 0)) - reduce_val, 0, 100)
					logger.info(t, "actor.leadership.fear_reduce", "Leadership fear reduce", {
						"actor_id":  _actor.get("id", ""),
						"trait_id":  trait_id,
						"target_id": most_feared.get("id", ""),
						"new_fear":  most_feared["fear"],
					})
					return trait_id
	return ""


# PROG-009: Update per-round passive state counters after each turn.
# Warder: tracks anchor_rounds for guard/protect_ally bonus (+8 per round, cap 3 rounds = +24).
# Steward: tracks stationary_rounds for soft-taunt eligibility.
# Skill once-per-combat flags are set here when the skill fires.
# Skill cooldowns (read_field, withdraw) are ticked at turn START instead.
func _update_passive_state(intent: Dictionary, context: Dictionary, t: int) -> void:
	var action: String         = str(intent.get("action_type", ""))
	var calling_origin: String = str(_actor.get("calling_origin", ""))
	var moved: bool            = (action == "actor.move" or action == "actor.withdraw")

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
								a_s["fear"] = clampi(int(a_s.get("fear", 0)) - aura_val, 0, 100)
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
		if not my_pos_hg.is_empty():
			for hg_av in context.get("all_actors", []):
				if not (hg_av is Dictionary): continue
				var hg_a: Dictionary = hg_av
				if hg_a.get("is_dead", false): continue
				if str(hg_a.get("faction", "")) == str(_actor.get("faction", "")) \
						and str(hg_a.get("id", "")) != str(_actor.get("id", "")):
					var hg_pos: Dictionary = hg_a.get("grid_pos", {})
					if not hg_pos.is_empty() and GridService.chebyshev_distance(my_pos_hg, hg_pos) <= hg_radius:
						hg_a["morale"] = clampi(int(hg_a.get("morale", 50)) + hg_morale_bonus, 0, 100)

	# Apply steady_call effects (Steward)
	if action == "actor.steady_call":
		var sc_radius: int    = int(_calling_behavior.get("leadership_radius", 4))
		var sc_fear_red: int  = 20
		var my_pos_sc: Dictionary = _actor.get("grid_pos", {})
		if not my_pos_sc.is_empty():
			for sc_av in context.get("all_actors", []):
				if not (sc_av is Dictionary): continue
				var sc_a: Dictionary = sc_av
				if sc_a.get("is_dead", false): continue
				if str(sc_a.get("faction", "")) == str(_actor.get("faction", "")):
					var sc_pos: Dictionary = sc_a.get("grid_pos", {})
					if not sc_pos.is_empty() and GridService.chebyshev_distance(my_pos_sc, sc_pos) <= sc_radius:
						sc_a["fear"] = clampi(int(sc_a.get("fear", 0)) - sc_fear_red, 0, 100)

	# Guard: set guard_state on self (interpose sets it on the protected ally below).
	if action == "actor.guard":
		_actor["guard_state"] = true

	# Apply interpose effects (Warder — grant guard_state to protected ally + morale boost to interposer).
	if action == "actor.interpose":
		var emo_cfg_ip: Dictionary = context.get("cfg", {}).get("data", {}).get("combat", {}).get("emotion", {})
		var interpose_morale: int = int(emo_cfg_ip.get("morale_on_interpose", 5))
		var interpose_target: String = str(intent.get("target_id", ""))
		if not interpose_target.is_empty():
			for ip_v in context.get("all_actors", []):
				if not (ip_v is Dictionary): continue
				var ip_a: Dictionary = ip_v
				if str(ip_a.get("id", "")) == interpose_target:
					ip_a["guard_state"] = true
					break
		_actor["morale"] = mini(100, int(_actor.get("morale", 50)) + interpose_morale)

	if t > 0:  # suppress unused-variable warning for t in Godot
		pass
