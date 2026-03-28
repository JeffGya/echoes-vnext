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

var _actor: Dictionary
var _behavior_module: BehaviorModule
var _last_intent: Dictionary = {}
var _last_action: Dictionary = {}
var _movement_skipped: bool = false  # ACTOR-006: true when actor is_structure; no movement phase
var _last_morale_tier: String = "steady"  # ACTOR-007: morale tier of the winning intent
var _last_morale_modifier: int = 0        # ACTOR-007: flat score modifier applied by morale tier

# PROG-010: per-turn computed state (reset each advance_turn)
var _smartness_tier: String = "novice"
var _calling_behavior: Dictionary = {}
var _active_leadership: String = ""
var _bark_line: String = ""
var _bark_context: String = ""
var _bark_tier: String = ""
var _bark_target_id: String = ""


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

	# PROG-010: compute smartness tier + calling behavior
	var cfg_data: Dictionary = context.get("cfg", {}).get("data", {})
	var smart_cfg: Dictionary = cfg_data.get("smartness", {})
	var tier_by_rank: Dictionary = smart_cfg.get("tier_by_rank", {})
	var calling_cfg: Dictionary = smart_cfg.get("calling_behavior", {})
	_smartness_tier = SmartnessTierService.get_tier(int(_actor.get("rank", 1)), tier_by_rank)
	_calling_behavior = SmartnessTierService.get_calling_behavior(_actor, calling_cfg)

	# PROG-010: read resilience + leadership traits
	var resilience_traits: Array = _actor.get("resilience_traits", []) as Array
	var leadership_traits: Array = _actor.get("leadership_traits", []) as Array

	# PROG-010: reset per-turn state
	_active_leadership = ""
	_bark_line = ""
	_bark_context = ""
	_bark_tier = ""
	_bark_target_id = ""
	if _actor.has("emotion"):
		(_actor["emotion"] as Dictionary).erase("_resilience_fired")

	# PROG-010: capture emotional state at turn start (for event detection)
	var start_fear: int = int(_actor.get("fear", 0))
	var start_morale: int = int(_actor.get("morale", 50))
	var start_morale_tier: String = EmotionService.get_morale_tier(start_morale)

	# PROG-010: check last_echo_standing
	var last_echo_standing := _is_last_echo_standing(context)

	# COMBAT-003 + PROG-010: Absolute Fear Rule — dynamic threshold based on tier + last stand.
	# GDD: "fear_current drives refusal/guard/retreat; can override ALL at extreme threshold."
	var fear_threshold: int = int(cfg_data.get("emotion", {}).get("fear_threshold", 80))
	if last_echo_standing:
		var ls_thresholds: Dictionary = smart_cfg.get("last_stand_fear_threshold", {})
		if _smartness_tier == "elite":
			fear_threshold = int(ls_thresholds.get("elite", 95))
		elif _smartness_tier == "veteran":
			fear_threshold = int(ls_thresholds.get("veteran", 88))
	# suppress_panic_spiral: raises threshold +5 on top of tier bonus
	if "suppress_panic_spiral" in resilience_traits \
			and (_smartness_tier == "veteran" or _smartness_tier == "elite"):
		fear_threshold = min(fear_threshold + 5, 100)

	# PROG-010: self_regulate tick — Veteran+ +3 morale per round
	if (_smartness_tier == "veteran" or _smartness_tier == "elite") \
			and "self_regulate" in resilience_traits:
		_actor["morale"] = clampi(int(_actor.get("morale", 50)) + 3, 0, 100)

	# PROG-010: Elite last-stand morale tick +5
	if _smartness_tier == "elite" and last_echo_standing:
		_actor["morale"] = clampi(int(_actor.get("morale", 50)) + int(smart_cfg.get("last_stand_elite_morale_tick", 5)), 0, 100)
		logger.info(t, "actor.last_stand_morale_tick", "Elite last-stand morale tick", {
			"actor_id": _actor.get("id", ""),
			"morale":   _actor["morale"],
		})

	# PROG-010: Elite leadership activation — apply radius effects to nearby allies
	if _smartness_tier == "elite" and not leadership_traits.is_empty():
		_active_leadership = _apply_leadership(leadership_traits, smart_cfg, context, logger, t)

	if int(_actor.get("fear", 0)) >= fear_threshold:
		var refuse_intent: Dictionary = {
			"action_type": "actor.refuse",
			"target_id":   "",
			"actor_id":    str(_actor.get("id", "")),
			"priority":    0.0,
		}
		_last_intent = refuse_intent
		_last_action = refuse_intent.duplicate()
		# PROG-010: bark for refuse
		var arch_r: String = str(_actor.get("archetype_birth", ""))
		_bark_context = "combat_refuse"
		_bark_tier = _smartness_tier
		_bark_line = ShoutBank.get_tier_shout("combat_refuse", arch_r, _smartness_tier,
			str(_actor.get("calling_origin", "")))
		if _bark_line.is_empty():
			_bark_line = ShoutBank.get_shout("combat_refuse", arch_r, ShoutBank.get_tier(
				int(_actor.get("traits", {}).get("courage", 50)),
				int(_actor.get("traits", {}).get("wisdom",  50)),
				int(_actor.get("traits", {}).get("faith",   50))
			))
		logger.info(t, "actor.refused", "Absolute Fear Rule triggered", {
			"actor_id": str(_actor.get("id", "")),
			"fear":     int(_actor.get("fear", 0)),
			"threshold": fear_threshold,
			"bark_line": _bark_line,
		})
		return refuse_intent

	# PROG-010: inject tier + traits into context so BehaviorArbiter can use them
	var augmented_context := context.duplicate()
	augmented_context["smartness_tier"]   = _smartness_tier
	augmented_context["calling_behavior"] = _calling_behavior
	augmented_context["resilience_traits"] = resilience_traits
	augmented_context["leadership_traits"] = leadership_traits

	# PROG-008: Layer 5 — inject active skill slots into intent pipeline context (stub).
	# BehaviorArbiter will read this in future skill stories; for now we log and pass through.
	var skill_slots: Array = (_actor.get("skill_slots", [""]) as Array).duplicate()
	augmented_context["skill_slots"] = skill_slots
	logger.debug(t, "actor.skill_slots", "Skill slots read", {
		"actor_id":   str(_actor.get("id", "")),
		"skill_slots": skill_slots,
		"slot_count":  skill_slots.size(),
	})

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
		"smartness_tier": _smartness_tier,
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

	# PROG-010: emotional event detection + bark selection
	var end_fear: int = int(_actor.get("fear", 0))
	var end_morale: int = int(_actor.get("morale", 50))
	var end_morale_tier: String = EmotionService.get_morale_tier(end_morale)
	var resilience_fired: bool = (_actor.get("emotion", {}) as Dictionary).get("_resilience_fired", false)
	var action_type: String = str(intent.get("action_type", ""))
	var arch: String = str(_actor.get("archetype_birth", ""))
	var calling: String = str(_actor.get("calling_origin", ""))
	_select_bark(arch, calling, action_type, start_fear, end_fear, start_morale_tier, end_morale_tier,
		last_echo_standing, resilience_fired, intent.get("target_id", ""))
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
		# PROG-010: smartness tier + identity traits
		"smartness_tier":    _smartness_tier,
		"resilience_traits": (_actor.get("resilience_traits", []) as Array).duplicate(),
		"leadership_traits": (_actor.get("leadership_traits", []) as Array).duplicate(),
		"active_leadership": _active_leadership,
		# PROG-010: bark fields (surfaceable to UI via VOICE-002)
		"bark_line":      _bark_line,
		"bark_context":   _bark_context,
		"bark_tier":      _bark_tier,
		"bark_target_id": _bark_target_id,
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
	target_id: Variant
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

	_bark_context = context_key
	_bark_tier = _smartness_tier

	# Try tier-shout first (emotion × tier × archetype × calling)
	var line := ShoutBank.get_tier_shout(context_key, arch, _smartness_tier, calling)
	if line.is_empty() or line == "I'll do my part.":
		# Fall back to legacy get_shout for existing contexts
		var trait_tier := ShoutBank.get_tier(
			int(_actor.get("traits", {}).get("courage", 50)),
			int(_actor.get("traits", {}).get("wisdom",  50)),
			int(_actor.get("traits", {}).get("faith",   50))
		)
		var legacy := ShoutBank.get_shout(context_key, arch, trait_tier)
		if not legacy.is_empty():
			line = legacy
	_bark_line = line


# Returns an ordinal rank for morale tiers (higher = better).
static func _morale_tier_rank(tier: String) -> int:
	match tier:
		"inspired": return 3
		"steady":   return 2
		"shaken":   return 1
	return 0  # broken


# Activates the first applicable leadership trait and applies radius effects.
# Returns the trait ID that fired, or "" if none.
func _apply_leadership(
	leadership_traits: Array,
	smart_cfg: Dictionary,
	context: Dictionary,
	logger: StructuredLogger,
	t: int
) -> String:
	var my_pos: Dictionary = _actor.get("grid_pos", { "col": 0, "row": 0 })
	var leadership_radius: int = int(_calling_behavior.get("leadership_radius", 3))
	var effects_cfg: Dictionary = smart_cfg.get("leadership_trait_effects", {})

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
