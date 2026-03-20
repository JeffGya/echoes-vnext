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

	# COMBAT-003: Absolute Fear Rule — fires pre-arbiter when fear >= threshold (default 80).
	# GDD: "fear_current drives refusal/guard/retreat; can override ALL at extreme threshold."
	var fear_threshold: int = int(context.get("cfg", {}).get("data", {}).get("emotion", {}).get("fear_threshold", 80))
	if int(_actor.get("fear", 0)) >= fear_threshold:
		var refuse_intent: Dictionary = {
			"action_type": "actor.refuse",
			"target_id":   "",
			"actor_id":    str(_actor.get("id", "")),
			"priority":    0.0,
		}
		_last_intent = refuse_intent
		_last_action = refuse_intent.duplicate()
		logger.info(t, "actor.refused", "Absolute Fear Rule triggered", {
			"actor_id": str(_actor.get("id", "")),
			"fear":     int(_actor.get("fear", 0)),
			"threshold": fear_threshold,
		})
		return refuse_intent

	var intent: Dictionary = _behavior_module.select_intent(context)
	_last_intent = intent
	# ACTOR-007: read morale metadata annotated by BehaviorArbiter onto the winner.
	_last_morale_tier     = str(intent.get("morale_tier",     "steady"))
	_last_morale_modifier = int(intent.get("morale_modifier", 0))
	logger.debug(t, "actor.intent", "Intent selected", {
		"module_id": _behavior_module.get_module_id(),
		"action_type": intent.get("action_type", ""),
		"target_id": intent.get("target_id", ""),
		"actor_id": _actor.get("id", "")
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
	}
