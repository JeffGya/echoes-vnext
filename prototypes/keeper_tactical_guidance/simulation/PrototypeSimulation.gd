class_name PrototypeSimulation
extends RefCounted

## Isolated deterministic tactical simulation for the Keeper Guidance prototype.
## The service owns all mutable battle state and consumes board data through CONTRACTS.md.

signal state_changed

const MAX_PING_CHARGE: int = 5
const DIRECTIVE_IDS: Array[String] = [
	"scout_carefully", "seek_signs", "press_the_path", "hold_the_circle",
]
const DIRECTIVE_LABELS: Dictionary = {
	"scout_carefully": "Scout Carefully",
	"seek_signs": "Seek Signs",
	"press_the_path": "Press the Path",
	"hold_the_circle": "Hold the Circle",
}
const PING_DEFINITIONS: Dictionary = {
	"hold_ground": {
		"label": "Hold Ground", "recipient_mode": "echo_specific", "cost": 2,
		"suggestion": "Ask one Echo to defend this nearby position and protect allies within reach.",
		"mechanical_influence": "Prefers guarding, protecting nearby allies, and remaining in or returning to the anchor.",
		"targeting_instruction": "Select one living Echo, then an anchor no more than 1 tile away.",
	},
	"break_through": {
		"label": "Break Through", "recipient_mode": "area_based", "cost": 3,
		"suggestion": "Mark a short lane and ask nearby Echoes to push through it and confront blockers.",
		"mechanical_influence": "Prefers movement through the lane and engagement with enemies obstructing it.",
		"targeting_instruction": "Select the lane start and end; maximum 5 contiguous tiles.",
	},
	"focus_threat": {
		"label": "Focus Threat", "recipient_mode": "party_wide", "cost": 5,
		"suggestion": "Ask the whole party to treat one visible enemy as the urgent threat.",
		"mechanical_influence": "Raises the marked enemy's priority while rescue, survival, Calling, and objective pressure may still override.",
		"targeting_instruction": "Select one living visible enemy or enemy totem carrier.",
	},
	"regroup": {
		"label": "Regroup", "recipient_mode": "area_based", "cost": 3,
		"suggestion": "Call Echoes already near this point to gather, protect one another, and leave danger.",
		"mechanical_influence": "Prefers the rally point, affected allies, mutual protection, and leaving hazards.",
		"targeting_instruction": "Select a rally tile; the radius-3 footprint determines recipients.",
	},
	"secure_objective": {
		"label": "Secure Objective", "recipient_mode": "party_wide", "cost": 5,
		"suggestion": "Ask the whole party to prioritize the current RECOVER or PROTECT objective.",
		"mechanical_influence": "Prefers entering, interacting with, holding, or defending the objective according to its mode rules.",
		"targeting_instruction": "The current objective is selected automatically.",
	},
}
const HAZARD_ORDER: Array[String] = ["unstable_ground", "binding_growth", "burning_ground"]
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _state: Dictionary = {}


func _init() -> void:
	_reset_state()


func setup_battle(seed: int, mode: String, board: Dictionary) -> void:
	_reset_state()
	_state["seed"] = seed
	_state["mode"] = mode if mode in ["recover", "protect"] else "recover"
	_state["phase"] = "preparation"
	_state["board"] = board.duplicate(true)
	_normalize_board()
	_state["actors"] = _build_fixture_actors()
	_state["objective"] = _build_objective()
	_place_initial_actors()
	_state["initiative_order"] = _build_initiative_order()
	_append_event("battle.prepared", "Board and fixture actors prepared", {
		"mode": _state["mode"], "seed": seed,
	})
	state_changed.emit()


func set_directive(id: String) -> bool:
	if str(_state.get("phase", "")) != "preparation" or not id in DIRECTIVE_IDS:
		return false
	_state["directive_id"] = id
	_append_event("directive.selected", DIRECTIVE_LABELS[id], {"directive_id": id})
	state_changed.emit()
	return true


func set_deployment(actor_id: String, pos: Dictionary) -> bool:
	if str(_state.get("phase", "")) != "preparation":
		return false
	var actor: Dictionary = _actor_by_id(actor_id)
	if actor.is_empty() or str(actor.get("faction", "")) != "echo":
		return false
	if not _contains_pos(_state["board"].get("deployment_slots", []), pos):
		return false
	var displaced_actor: Dictionary = {}
	var previous_pos: Dictionary = actor.get("grid_pos", {}).duplicate(true)
	for other_v: Variant in _state["actors"]:
		var other: Dictionary = other_v as Dictionary
		if str(other.get("id", "")) != actor_id and _same_pos(other.get("grid_pos", {}), pos):
			if str(other.get("faction", "")) != "echo":
				return false
			displaced_actor = other
			break
	if not displaced_actor.is_empty():
		displaced_actor["grid_pos"] = previous_pos
	actor["grid_pos"] = _copy_pos(pos)
	_append_event("deployment.changed", "%s assigned to a deployment slot" % actor.get("name", "Echo"), {
		"actor_id": actor_id, "position": _copy_pos(pos),
		"swapped_actor_id": displaced_actor.get("id", ""), "swapped_position": previous_pos,
	})
	state_changed.emit()
	return true


func start_combat() -> bool:
	if str(_state.get("phase", "")) != "preparation":
		return false
	if str(_state.get("directive_id", "")) == "":
		return false
	if not _deployment_is_valid():
		return false
	_state["phase"] = "combat"
	_state["round"] = 1
	_state["initiative_index"] = 0
	_append_event("combat.started", "Autonomous combat began", {
		"directive_id": _state["directive_id"], "initiative": _state["initiative_order"].duplicate(),
	})
	state_changed.emit()
	return true


func resolve_next_turn() -> Dictionary:
	if str(_state.get("phase", "")) != "combat" or bool(_state.get("combat_over", false)):
		return {}
	var order: Array = _state.get("initiative_order", [])
	if order.is_empty():
		_finish_battle(false, "no_living_actors")
		return {}

	var checked: int = 0
	var actor: Dictionary = {}
	while checked < order.size():
		var idx: int = int(_state.get("initiative_index", 0)) % order.size()
		_state["initiative_index"] = idx
		actor = _actor_by_id(str(order[idx]))
		if not actor.is_empty() and not bool(actor.get("is_dead", false)) and not bool(actor.get("is_structure", false)):
			break
		_advance_initiative()
		checked += 1
	if checked >= order.size() or actor.is_empty():
		_check_end_condition()
		return {}

	_state["tick"] = int(_state.get("tick", 0)) + 1
	var turn_result: Dictionary = _resolve_actor_turn(actor)
	# Atomic-boundary order: action -> hazards -> custody -> end conditions -> initiative/round end.
	_resolve_end_turn_hazards(actor, turn_result)
	_update_carried_totem_position()
	_check_end_condition()
	turn_result = _finalize_turn_result(turn_result)
	_advance_initiative()
	# Publish only after any round-end objective/custody/charge work has also completed.
	_state["last_turn_result"] = turn_result.duplicate(true)
	state_changed.emit()
	return turn_result.duplicate(true)


func preview_ping(ping_id: String, subject: Dictionary) -> Dictionary:
	var preview: Dictionary = _empty_ping(ping_id, subject)
	if not PING_DEFINITIONS.has(ping_id):
		preview["availability_state"] = "invalid_subject"
		preview["invalid_reason"] = "Unknown ping."
		return preview

	match ping_id:
		"hold_ground":
			_preview_hold_ground(preview, subject)
		"break_through":
			_preview_break_through(preview, subject)
		"focus_threat":
			_preview_focus_threat(preview, subject)
		"regroup":
			_preview_regroup(preview, subject)
		"secure_objective":
			preview["subject"] = {"kind": "objective", "position": _state["objective"].get("position", {}).duplicate()}
			preview["eligible_recipient_ids"] = _living_echo_ids()
			preview["footprint"] = [_state["objective"].get("position", {}).duplicate()]
			_validate_recipient_preview(preview)
	_finalize_ping_availability(preview)
	return preview


func confirm_ping(preview: Dictionary) -> bool:
	var ping_id: String = str(preview.get("id", ""))
	if not PING_DEFINITIONS.has(ping_id):
		return false
	# Confirmation is an atomic-boundary commit: rebuild against current positions and
	# charge rather than trusting a preview captured during the preceding animation.
	var subject_v: Variant = preview.get("subject", {})
	var subject: Dictionary = subject_v if subject_v is Dictionary else {}
	var current_preview: Dictionary = preview_ping(ping_id, subject)
	if not bool(current_preview.get("valid", false)):
		return false
	var expected_mode: String = str(PING_DEFINITIONS[ping_id]["recipient_mode"])
	if str(current_preview.get("recipient_mode", "")) != expected_mode:
		return false
	var cost: int = int(PING_DEFINITIONS[ping_id]["cost"])
	if int(_state["ping_charge"].get("current", 0)) < cost:
		return false
	var recipients: Array[String] = []
	for id_v: Variant in current_preview.get("eligible_recipient_ids", []):
		var id: String = str(id_v)
		var actor: Dictionary = _actor_by_id(id)
		if not actor.is_empty() and str(actor.get("faction", "")) == "echo" and not bool(actor.get("is_dead", false)):
			recipients.append(id)
	if recipients.is_empty() or (expected_mode == "echo_specific" and recipients.size() != 1):
		return false

	var confirmed: Dictionary = current_preview.duplicate(true)
	confirmed["recipient_ids"] = recipients.duplicate()
	confirmed["remaining_recipient_ids"] = recipients.duplicate()
	confirmed["confirmed_round"] = int(_state.get("round", 1))
	confirmed["activation_round"] = int(_state.get("round", 1)) + 1
	confirmed["expires_after_round"] = confirmed["activation_round"]
	confirmed["valid"] = true
	confirmed["invalid_reason"] = ""
	_state["unresolved_ping"] = confirmed
	_state["ping_charge"]["current"] = 0
	for recipient_id: String in recipients:
		var recipient: Dictionary = _actor_by_id(recipient_id)
		if not recipient.is_empty():
			recipient["guidance_state"] = "pending"
	_state["metrics"]["pings_confirmed"] = int(_state["metrics"].get("pings_confirmed", 0)) + 1
	_append_event("ping.confirmed", "%s confirmed" % confirmed.get("label", "Ping"), {
		"ping": confirmed.duplicate(true), "charge_consumed": cost, "stored_charge_consumed": "all",
	})
	state_changed.emit()
	return true


func cancel_ping() -> void:
	# Cancelling placement never changes stored charge or an already-confirmed ping.
	_append_event("ping.cancelled", "Ping placement cancelled", {})
	state_changed.emit()


func get_state() -> Dictionary:
	return _state.duplicate(true)


func build_snapshot_data() -> Dictionary:
	var current_actor_id: String = ""
	var order: Array = _state.get("initiative_order", [])
	if not order.is_empty():
		current_actor_id = str(order[int(_state.get("initiative_index", 0)) % order.size()])
	return {
		"phase": _state.get("phase", "briefing"),
		"mode": _state.get("mode", "recover"),
		"board": _state.get("board", {}).duplicate(true),
		"actors": _state.get("actors", []).duplicate(true),
		"objective": _state.get("objective", {}).duplicate(true),
		"directive_id": _state.get("directive_id", ""),
		"directive_label": DIRECTIVE_LABELS.get(_state.get("directive_id", ""), "Not selected"),
		"initiative_order": order.duplicate(),
		"initiative_index": _state.get("initiative_index", 0),
		"current_actor_id": current_actor_id,
		"round": _state.get("round", 0),
		"ping_charge": _state.get("ping_charge", {}).duplicate(true),
		"ping_requirements": {"echo_specific": 2, "area_based": 3, "party_wide": 5},
		"ping_library": _build_ping_library(),
		"unresolved_ping": _state.get("unresolved_ping", {}).duplicate(true),
		"last_turn_result": _state.get("last_turn_result", {}).duplicate(true),
		"response_feedback": _state.get("response_feedback", []).duplicate(true),
		"attention_cues": _state.get("attention_cues", []).duplicate(),
		"combat_over": _state.get("combat_over", false),
		"result": _state.get("result", {}).duplicate(true),
		"timeline_tail": _timeline_tail(16),
		"timeline": _state.get("timeline", []).duplicate(true),
		"metrics": _state.get("metrics", {}).duplicate(true),
	}


func _reset_state() -> void:
	_state = {
		"seed": 0, "mode": "recover", "phase": "briefing", "tick": 0, "round": 0,
		"directive_id": "", "board": {}, "actors": [], "initiative_order": [], "initiative_index": 0,
		"objective": {}, "ping_charge": {"current": 0, "maximum": MAX_PING_CHARGE, "gain_per_completed_round": 1},
		"unresolved_ping": {}, "last_turn_result": {},
		"combat_over": false, "result": {"victory": false, "reason": ""}, "timeline": [],
		"response_feedback": [], "attention_cues": [],
		"metrics": {
			"turns_completed": 0, "rounds_completed": 0, "pings_confirmed": 0,
			"response_count": 0, "hazard_events": 0, "echoes_downed": 0,
			"responses": {"align": 0, "interpret": 0, "hesitate": 0, "object": 0, "refuse": 0},
			"hazard_damage": 0, "hazard_forced_moves": 0, "objective_events": 0,
		},
	}


func _normalize_board() -> void:
	var board: Dictionary = _state["board"]
	var bounds: Dictionary = board.get("bounds", {"w": 10, "h": 10})
	board["bounds"] = {"w": maxi(1, int(bounds.get("w", 10))), "h": maxi(1, int(bounds.get("h", 10)))}
	if not board.has("walkable") or not board["walkable"] is Dictionary or (board["walkable"] as Dictionary).is_empty():
		board["walkable"] = {}
		for row: int in range(int(board["bounds"]["h"])):
			for col: int in range(int(board["bounds"]["w"])):
				board["walkable"][_pos_key({"col": col, "row": row})] = true
	for key: String in ["deployment_slots", "enemy_slots", "hazards", "cells", "chokepoints", "routes"]:
		if not board.has(key) or not board[key] is Array:
			board[key] = []
	if (board["deployment_slots"] as Array).size() < 4:
		board["deployment_slots"] = _first_walkable_cells(4, false)
	if (board["enemy_slots"] as Array).size() < 4:
		board["enemy_slots"] = _first_walkable_cells(4, true)
	if not board.has("objective_pos") or not board["objective_pos"] is Dictionary:
		board["objective_pos"] = _first_walkable_cells(1, true)[0]


func _build_fixture_actors() -> Array[Dictionary]:
	var actors: Array[Dictionary] = []
	actors.append(_make_echo("echo_adwoa", "Adwoa", "okofor", 4, "grounded", 52, 76,
		{"max_hp": 48, "atk": 10, "def": 8, "agi": 7, "speed": 7},
		{"protector": 68, "devoted": 22, "vanguard": 10}, "steady protector"))
	actors.append(_make_echo("echo_kwame", "Kwame", "aduro", 3, "grounded", 30, 72,
		{"max_hp": 43, "atk": 13, "def": 5, "agi": 10, "speed": 10},
		{"vanguard": 66, "opportunist": 24, "protector": 10}, "bold pursuer"))
	actors.append(_make_echo("echo_esi", "Esi", "sum_okwanfo", 3, "grounded", 22, 65,
		{"max_hp": 39, "atk": 9, "def": 6, "agi": 11, "speed": 9},
		{"seeker": 62, "strategist": 28, "protector": 10}, "cautious seeker"))
	actors.append(_make_echo("echo_kofi", "Kofi", "kra_soro", 2, "forming", 61, 38,
		{"max_hp": 41, "atk": 12, "def": 5, "agi": 9, "speed": 8},
		{"opportunist": 45, "vanguard": 35, "skeptic": 20}, "volatile under pressure"))
	# Deliberate bonds make protective reinterpretation observable.
	actors[0]["bonds"] = {"echo_kofi": 55, "echo_esi": 32}
	actors[1]["bonds"] = {"echo_esi": -22}
	actors[2]["bonds"] = {"echo_adwoa": 32, "echo_kwame": -22}
	actors[3]["bonds"] = {"echo_adwoa": 55}
	for i: int in range(4):
		actors.append(_make_enemy("enemy_%02d" % (i + 1), "Realm Hunter %d" % (i + 1), i))
	return actors


func _make_echo(id: String, display_name: String, calling: String, standing: int,
		expression: String, fear: int, morale: int, stats: Dictionary,
		vectors: Dictionary, tendency: String) -> Dictionary:
	return {
		"id": id, "name": display_name, "actor_type": "echo", "faction": "echo",
		"is_structure": false, "is_dead": false, "grid_pos": {"col": -1, "row": -1},
		"current_hp": int(stats["max_hp"]), "stats": stats.duplicate(true), "speed": int(stats["speed"]),
		"fear": fear, "morale": morale, "calling_origin": calling, "standing": standing,
		"expression_band": expression,
		"traits": {"courage": vectors.get("vanguard", 35), "wisdom": vectors.get("seeker", 35), "faith": vectors.get("protector", 35)},
		"vector_scores": vectors.duplicate(true), "bonds": {}, "tendency": tendency,
		"guard_state": false, "movement_remaining": 1, "last_response": {}, "guidance_state": "unaffected",
	}


func _make_enemy(id: String, display_name: String, index: int) -> Dictionary:
	return {
		"id": id, "name": display_name, "actor_type": "enemy", "faction": "enemy",
		"is_structure": false, "is_dead": false, "grid_pos": {"col": -1, "row": -1},
		"current_hp": 30 + index * 2,
		"stats": {"max_hp": 30 + index * 2, "atk": 10 + index, "def": 4 + index / 2, "agi": 6 + index, "speed": 6 + index},
		"speed": 6 + index, "fear": 8, "morale": 55, "calling_origin": "enemy",
		"standing": 1, "expression_band": "nascent", "traits": {}, "vector_scores": {}, "bonds": {},
		"tendency": "pressure the objective", "guard_state": false, "movement_remaining": 1, "last_response": {},
		"guidance_state": "unaffected",
	}


func _build_objective() -> Dictionary:
	var pos: Dictionary = _state["board"].get("objective_pos", {}).duplicate()
	var mode: String = str(_state["mode"])
	var carryable: bool = false
	if mode == "protect":
		carryable = _rng("prototype.keeper.protect.carryable").randf() < 0.60
	var objective: Dictionary = {
		"mode": mode, "structure_id": "objective_relic" if mode == "recover" else "objective_totem",
		"position": pos, "hold_counter": 0, "hold_required": 2,
		"protect_counter": 0, "protect_required": 4, "guard_radius": 2,
		"carryable": carryable, "holder_id": "", "totem_stolen": false, "totem_carrier_id": "",
		"hp": 9999 if mode == "recover" else 70, "max_hp": 9999 if mode == "recover" else 70,
		"status": "unsecured" if mode == "recover" else "guarded",
	}
	var structure: Dictionary = {
		"id": objective["structure_id"], "name": "Severed Relic" if mode == "recover" else "The Charge",
		"actor_type": "structure", "faction": "structure", "is_structure": true, "is_dead": false,
		"grid_pos": pos.duplicate(), "current_hp": objective["hp"],
		"stats": {"max_hp": objective["max_hp"], "atk": 0, "def": 2, "agi": 0, "speed": 0},
		"speed": 0, "fear": 0, "morale": 0, "calling_origin": "", "standing": 0,
		"expression_band": "", "traits": {}, "vector_scores": {}, "bonds": {}, "tendency": "objective",
		"guard_state": false, "movement_remaining": 0, "last_response": {}, "guidance_state": "unaffected",
	}
	_state["actors"].append(structure)
	return objective


func _place_initial_actors() -> void:
	var echo_slots: Array = _state["board"].get("deployment_slots", [])
	var enemy_slots: Array = _state["board"].get("enemy_slots", [])
	var echo_i: int = 0
	var enemy_i: int = 0
	for actor_v: Variant in _state["actors"]:
		var actor: Dictionary = actor_v as Dictionary
		if str(actor.get("faction", "")) == "echo":
			actor["grid_pos"] = _copy_pos(echo_slots[echo_i % echo_slots.size()])
			echo_i += 1
		elif str(actor.get("faction", "")) == "enemy":
			actor["grid_pos"] = _copy_pos(enemy_slots[enemy_i % enemy_slots.size()])
			enemy_i += 1


func _build_initiative_order() -> Array[String]:
	var scored: Array[Dictionary] = []
	for actor_v: Variant in _state["actors"]:
		var actor: Dictionary = actor_v as Dictionary
		if bool(actor.get("is_structure", false)):
			continue
		var morale_mod: int = 4 if int(actor.get("morale", 50)) >= 75 else (0 if int(actor.get("morale", 50)) >= 50 else (-3 if int(actor.get("morale", 50)) >= 25 else -6))
		var nudge: int = int(_rng("prototype.keeper.initiative.%s" % actor.get("id", "")).randi() % 10)
		var score: int = int(actor.get("speed", 5)) * 3 + int(actor.get("stats", {}).get("agi", 0)) * 2 + morale_mod + nudge
		scored.append({"id": str(actor.get("id", "")), "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) == int(b["score"]):
			return str(a["id"]) < str(b["id"])
		return int(a["score"]) > int(b["score"])
	)
	var result: Array[String] = []
	for entry: Dictionary in scored:
		result.append(str(entry["id"]))
	return result


func _resolve_actor_turn(actor: Dictionary) -> Dictionary:
	actor["guard_state"] = false
	actor["movement_remaining"] = 1
	var response: Dictionary = {}
	if str(actor.get("faction", "")) == "echo":
		response = _resolve_pending_response(actor)
	var influence: float = float(response.get("influence", 0.0))
	var target: Dictionary = _select_target(actor, influence)
	var result: Dictionary = {
		"actor_id": actor.get("id", ""), "actor_name": actor.get("name", ""),
		"round": _state.get("round", 1), "action_type": "wait", "ping_response": response,
		"from_pos": actor.get("grid_pos", {}).duplicate(), "to_pos": actor.get("grid_pos", {}).duplicate(),
		"path": [], "target_id": "", "damage": 0, "hit": false,
		"hazard_events": [], "objective_events": [], "follow_up": [],
	}

	if str(actor.get("faction", "")) == "echo" and int(actor.get("fear", 0)) >= _fear_refusal_threshold(actor):
		result["action_type"] = "wait"
		_append_event("actor.refused", "%s could not act through the fear" % actor.get("name", "Echo"), {
			"actor_id": actor.get("id", ""), "fear": actor.get("fear", 0),
		})
	elif _should_guard(actor, response):
		actor["guard_state"] = true
		result["action_type"] = "guard"
		_append_event("actor.guarded", "%s guarded" % actor.get("name", "Actor"), {"actor_id": actor.get("id", "")})
	elif not target.is_empty() and _is_adjacent(actor.get("grid_pos", {}), target.get("grid_pos", {})):
		result.merge(_resolve_attack(actor, target), true)
	else:
		var destination: Dictionary = _choose_destination(actor, target, response)
		if not destination.is_empty():
			var step: Dictionary = _best_step(actor, destination)
			if not step.is_empty() and not _same_pos(step, actor.get("grid_pos", {})):
				var before: Dictionary = actor.get("grid_pos", {}).duplicate()
				actor["grid_pos"] = step
				actor["_previous_grid_pos"] = before.duplicate()
				var visited: Dictionary = actor.get("_visited_cells", {})
				visited[_pos_key(step)] = int(visited.get(_pos_key(step), 0)) + 1
				actor["_visited_cells"] = visited
				result["action_type"] = "move"
				result["from_pos"] = before
				result["to_pos"] = step.duplicate()
				result["path"] = [step.duplicate()]
				_append_event("actor.moved", "%s moved" % actor.get("name", "Actor"), {
					"actor_id": actor.get("id", ""), "from": before, "to": step.duplicate(),
				})
				_resolve_entry_hazards(actor, before, result)
			else:
				result["action_type"] = "wait"
		else:
			result["action_type"] = "wait"

	# A carried objective follows its holder after normal and forced movement.
	_update_carried_totem_position()
	# After movement, attack if the autonomous route ended in reach and the actor did not already act.
	if result["action_type"] == "move" and not target.is_empty() \
			and _is_adjacent(actor.get("grid_pos", {}), target.get("grid_pos", {})) \
			and not bool(actor.get("is_dead", false)):
		var attack_result: Dictionary = _resolve_attack(actor, target)
		result["follow_up"] = [{
			"type": "attack", "source_id": actor.get("id", ""),
			"target_id": attack_result.get("target_id", ""),
			"from_pos": actor.get("grid_pos", {}).duplicate(true),
			"to_pos": target.get("grid_pos", {}).duplicate(true),
			"damage": attack_result.get("damage", 0), "label": "Follow-up strike",
		}]

	_handle_objective_interaction(actor, response)
	actor["last_intent"] = {"action_type": str(result.get("action_type", "wait"))}
	_state["metrics"]["turns_completed"] = int(_state["metrics"].get("turns_completed", 0)) + 1
	_append_event("turn.completed", "%s completed a turn" % actor.get("name", "Actor"), result)
	var ping: Dictionary = _state.get("unresolved_ping", {})
	if not response.is_empty() and not ping.is_empty() and (ping.get("remaining_recipient_ids", []) as Array).is_empty():
		_expire_ping("all_recipients_acted")
	return result


func _resolve_pending_response(actor: Dictionary) -> Dictionary:
	var ping: Dictionary = _state.get("unresolved_ping", {})
	if ping.is_empty():
		return {}
	var actor_id: String = str(actor.get("id", ""))
	var remaining: Array = ping.get("remaining_recipient_ids", [])
	if not actor_id in remaining:
		return {}
	if int(_state.get("round", 0)) != int(ping.get("activation_round", -1)):
		return {}
	var response: Dictionary = _evaluate_response(actor, ping)
	actor["last_response"] = response.duplicate(true)
	actor["guidance_state"] = _guidance_state_for_outcome(str(response.get("outcome", "align")))
	_state["response_feedback"].append(response.duplicate(true))
	if _state["response_feedback"].size() > 12:
		_state["response_feedback"].pop_front()
	remaining.erase(actor_id)
	ping["remaining_recipient_ids"] = remaining
	var outcomes: Dictionary = _state["metrics"]["responses"]
	var outcome: String = str(response.get("outcome", "align"))
	outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
	_state["metrics"]["response_count"] = int(_state["metrics"].get("response_count", 0)) + 1
	_append_event("ping.response", response.get("explanation", "Echo response"), response)
	return response


func _evaluate_response(actor: Dictionary, ping: Dictionary) -> Dictionary:
	var ping_id: String = str(ping.get("id", ""))
	var fear: int = int(actor.get("fear", 0))
	var morale: int = int(actor.get("morale", 50))
	var hp_max: int = maxi(1, int(actor.get("stats", {}).get("max_hp", 1)))
	var hp_ratio: float = float(actor.get("current_hp", 0)) / float(hp_max)
	var nearby_threats: int = _living_opponents_within(actor, 2).size()
	var hazardous_now: bool = not _hazards_at(actor.get("grid_pos", {})).is_empty()
	var hazardous_subject: bool = _footprint_has_hazard(ping.get("footprint", []))
	var fit: int = _calling_ping_fit(str(actor.get("calling_origin", "")), ping_id)
	var bond_pressure: int = _bond_pressure(actor)
	var objective_pressure: int = _objective_pressure()
	var standing: int = int(actor.get("standing", 1))
	var expression: String = str(actor.get("expression_band", "nascent"))
	var mature_assertion: int = 0
	if expression == "whole":
		mature_assertion = 8
	elif expression == "grounded":
		mature_assertion = 4
	var danger: int = (20 if hp_ratio <= 0.30 else (8 if hp_ratio <= 0.55 else 0)) + nearby_threats * 4
	if hazardous_now:
		danger += 10
	if hazardous_subject and ping_id in ["break_through", "hold_ground"]:
		danger += 12
	var score: int = 60 + fit + int((morale - 50) * 0.35) - int(fear * 0.38) - danger
	if ping_id in ["regroup", "hold_ground"]:
		score += bond_pressure
	if ping_id == "secure_objective":
		score += objective_pressure
	# Standing creates coherent self-judgment. It helps a fitting request, but amplifies contradiction.
	if fit >= 0:
		score += mini(6, standing)
	else:
		score -= mature_assertion
	var nudge: int = _rng("prototype.keeper.response.%s.%d.%s" % [ping_id, int(ping.get("confirmed_round", 0)), actor.get("id", "")]).randi_range(-3, 3)
	score += nudge

	var outcome: String
	var influence: float
	if fear >= _fear_refusal_threshold(actor) or score < 16:
		outcome = "refuse"
		influence = 0.0
	elif score < 32:
		outcome = "object"
		influence = 0.20
	elif score < 47:
		outcome = "hesitate"
		influence = 0.40
	elif score < 68 or (standing >= 4 and fit < 8):
		outcome = "interpret"
		influence = 0.70
	else:
		outcome = "align"
		influence = 1.0

	var reasons: Array[String] = []
	if fear >= 60:
		reasons.append("fear is high")
	if hp_ratio <= 0.30:
		reasons.append("survival is immediately at risk")
	if hazardous_subject and ping_id in ["break_through", "hold_ground"]:
		reasons.append("the marked ground is hazardous")
	if objective_pressure >= 12 and ping_id != "secure_objective":
		reasons.append("the objective is close to being lost")
	if bond_pressure >= 8 and ping_id not in ["regroup", "hold_ground"]:
		reasons.append("a bonded ally needs protection")
	if fit < 0:
		reasons.append("the request conflicts with %s's Calling" % actor.get("name", "the Echo"))
	if morale < 35:
		reasons.append("morale is low")
	if standing >= 4 and fit < 8:
		reasons.append("mature judgment favors a different approach")
	if reasons.is_empty() and outcome != "align":
		reasons.append("current danger outweighs the marked priority")
	var primary: String = "" if outcome == "align" else reasons[0]
	var secondary: String = "" if reasons.size() < 2 else reasons[1]
	var explanation: String
	if outcome == "align":
		explanation = "%s aligned with %s." % [actor.get("name", "Echo"), ping.get("label", "the ping")]
	else:
		explanation = "%s %s: %s." % [actor.get("name", "Echo"), outcome, primary]
	return {
		"actor_id": actor.get("id", ""), "ping_id": ping_id, "outcome": outcome,
		"influence": influence, "primary_reason": primary, "secondary_reason": secondary,
		"explanation": explanation, "score": score,
		"factors": {"fear": fear, "morale": morale, "danger": danger, "calling_fit": fit,
			"bond_pressure": bond_pressure, "standing": standing, "expression_band": expression,
			"objective_pressure": objective_pressure},
	}


func _select_target(actor: Dictionary, ping_influence: float) -> Dictionary:
	var faction: String = str(actor.get("faction", ""))
	if faction == "enemy":
		if str(_state.get("mode", "")) == "protect":
			var objective_actor: Dictionary = _actor_by_id(str(_state["objective"].get("structure_id", "")))
			if not objective_actor.is_empty() and not bool(objective_actor.get("is_dead", false)):
				return objective_actor
		return _nearest_actor(actor, "echo")

	var ping: Dictionary = _state.get("unresolved_ping", {})
	if not ping.is_empty() and str(ping.get("id", "")) == "focus_threat" and ping_influence > 0.0:
		var subject: Dictionary = ping.get("subject", {})
		var focus: Dictionary = _actor_by_id(str(subject.get("enemy_id", subject.get("actor_id", ""))))
		if not focus.is_empty() and not bool(focus.get("is_dead", false)):
			return focus
	return _nearest_actor(actor, "enemy")


func _choose_destination(actor: Dictionary, target: Dictionary, response: Dictionary) -> Dictionary:
	var faction: String = str(actor.get("faction", ""))
	if faction == "enemy":
		return target.get("grid_pos", {}).duplicate() if not target.is_empty() else {}
	var ping: Dictionary = _state.get("unresolved_ping", {})
	var influence: float = float(response.get("influence", 0.0))
	if not ping.is_empty() and influence > 0.0:
		match str(ping.get("id", "")):
			"hold_ground":
				return _subject_pos(ping.get("subject", {}), ["anchor", "position"])
			"break_through":
				var footprint: Array = ping.get("footprint", [])
				if not footprint.is_empty():
					return _copy_pos(footprint[footprint.size() - 1])
			"regroup":
				return _subject_pos(ping.get("subject", {}), ["rally", "position"])
			"secure_objective":
				return _state["objective"].get("position", {}).duplicate()
			"focus_threat":
				if not target.is_empty():
					return target.get("grid_pos", {}).duplicate()

	var directive: String = str(_state.get("directive_id", ""))
	if directive == "press_the_path":
		return _state["objective"].get("position", {}).duplicate()
	if directive == "hold_the_circle":
		var vulnerable: Dictionary = _most_vulnerable_echo(actor)
		if not vulnerable.is_empty():
			return vulnerable.get("grid_pos", {}).duplicate()
	if directive == "scout_carefully" and _position_is_hazardous(_state["objective"].get("position", {})):
		return _nearest_safe_cell(actor.get("grid_pos", {}))
	if str(_state.get("mode", "")) == "recover":
		return _state["objective"].get("position", {}).duplicate()
	if str(_state.get("mode", "")) == "protect" and _objective_pressure() >= 8:
		return _state["objective"].get("position", {}).duplicate()
	return target.get("grid_pos", {}).duplicate() if not target.is_empty() else _state["objective"].get("position", {}).duplicate()


func _should_guard(actor: Dictionary, response: Dictionary) -> bool:
	if str(actor.get("faction", "")) != "echo":
		return false
	if str(actor.get("last_intent", {}).get("action_type", "")) == "guard":
		return false
	var hp_ratio: float = float(actor.get("current_hp", 0)) / float(maxi(1, int(actor.get("stats", {}).get("max_hp", 1))))
	if hp_ratio <= 0.25:
		return true
	var ping: Dictionary = _state.get("unresolved_ping", {})
	if not ping.is_empty() and str(ping.get("id", "")) == "hold_ground" and float(response.get("influence", 0.0)) >= 0.4:
		var anchor: Dictionary = _subject_pos(ping.get("subject", {}), ["anchor", "position"])
		return _chebyshev(actor.get("grid_pos", {}), anchor) <= 1
	if str(_state.get("directive_id", "")) == "hold_the_circle" and _living_opponents_within(actor, 2).size() > 0:
		return str(actor.get("calling_origin", "")) in ["okofor", "onyamesu"]
	return false


func _resolve_attack(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var atk: int = int(attacker.get("stats", {}).get("atk", 8))
	var defense: int = int(defender.get("stats", {}).get("def", 3))
	if bool(defender.get("guard_state", false)):
		defense *= 2
	var morale_bonus: int = (int(attacker.get("morale", 50)) - 50) / 10
	var fear_penalty: int = int(attacker.get("fear", 0)) / 20
	var damage: int = maxi(1, atk - defense + morale_bonus - fear_penalty)
	var objective: Dictionary = _state["objective"]
	if str(attacker.get("id", "")) == str(objective.get("totem_carrier_id", "")):
		damage *= 2
	if str(attacker.get("id", "")) == str(objective.get("holder_id", "")):
		damage = maxi(1, damage - 2)
	var before: int = int(defender.get("current_hp", 0))
	defender["current_hp"] = maxi(0, before - damage)
	if int(defender["current_hp"]) <= 0:
		defender["is_dead"] = true
		defender["death_round"] = int(_state.get("round", 1))
		_state["attention_cues"].append("%s was downed." % defender.get("name", "An actor"))
		if str(defender.get("faction", "")) == "echo":
			_state["metrics"]["echoes_downed"] = int(_state["metrics"].get("echoes_downed", 0)) + 1
		_append_event("actor.downed", "%s was downed" % defender.get("name", "Actor"), {
			"actor_id": defender.get("id", ""), "by_actor_id": attacker.get("id", ""),
		})
	if str(defender.get("faction", "")) == "echo" and damage > 0:
		defender["fear"] = mini(100, int(defender.get("fear", 0)) + 4)
	if str(defender.get("id", "")) == str(_state.get("objective", {}).get("structure_id", "")):
		_state["objective"]["hp"] = int(defender["current_hp"])
	var result: Dictionary = {
		"action_type": "attack", "attacker_id": attacker.get("id", ""),
		"target_id": defender.get("id", ""), "damage": damage,
		"hit": damage > 0,
		"defender_hp_before": before, "defender_hp_after": defender["current_hp"],
	}
	_append_event("combat.damage", "%s struck %s for %d" % [attacker.get("name", "Actor"), defender.get("name", "target"), damage], result)
	return result


func _resolve_entry_hazards(actor: Dictionary, from_pos: Dictionary, turn_result: Dictionary) -> void:
	if bool(actor.get("is_dead", false)):
		return
	var triggered: Dictionary = {}
	for hazard_type: String in HAZARD_ORDER:
		for hazard: Dictionary in _hazards_at(actor.get("grid_pos", {}), hazard_type):
			var hazard_id: String = str(hazard.get("id", hazard_type))
			if triggered.has(hazard_id):
				continue
			triggered[hazard_id] = true
			if hazard_type == "unstable_ground":
				_resolve_unstable_ground(actor, hazard, from_pos, turn_result)
			elif hazard_type == "binding_growth":
				actor["movement_remaining"] = 0
				(turn_result["hazard_events"] as Array).append({
					"type": "binding_growth", "source_id": hazard_id, "target_id": actor.get("id", ""),
					"from_pos": actor.get("grid_pos", {}).duplicate(true), "to_pos": actor.get("grid_pos", {}).duplicate(true),
					"damage": 0, "label": "Binding Growth stopped movement",
				})
				_append_event("hazard.binding_growth", "%s was caught by Binding Growth" % actor.get("name", "Actor"), {
					"actor_id": actor.get("id", ""), "hazard_id": hazard_id,
				})


func _resolve_unstable_ground(actor: Dictionary, hazard: Dictionary, from_pos: Dictionary, turn_result: Dictionary) -> void:
	var pos: Dictionary = actor.get("grid_pos", {})
	var center: Dictionary = hazard.get("center", pos)
	var dx: int = signi(int(pos.get("col", 0)) - int(center.get("col", 0)))
	var dy: int = signi(int(pos.get("row", 0)) - int(center.get("row", 0)))
	if dx == 0 and dy == 0:
		dx = signi(int(pos.get("col", 0)) - int(from_pos.get("col", 0)))
		dy = signi(int(pos.get("row", 0)) - int(from_pos.get("row", 0)))
	if dx == 0 and dy == 0:
		dx = 1
	var pushed: Dictionary = {"col": int(pos.get("col", 0)) + dx, "row": int(pos.get("row", 0)) + dy}
	if _is_walkable(pushed) and not _is_occupied(pushed, str(actor.get("id", ""))):
		actor["grid_pos"] = pushed
		turn_result["forced_move"] = {"from": pos.duplicate(), "to": pushed.duplicate()}
		(turn_result["hazard_events"] as Array).append({
			"type": "unstable_ground", "source_id": hazard.get("id", ""), "target_id": actor.get("id", ""),
			"from_pos": pos.duplicate(true), "to_pos": pushed.duplicate(true), "damage": 0,
			"label": "Unstable Ground displaced the actor",
		})
		_state["metrics"]["hazard_forced_moves"] = int(_state["metrics"].get("hazard_forced_moves", 0)) + 1
		_state["attention_cues"].append("Unstable Ground displaced %s." % actor.get("name", "an actor"))
		_append_event("hazard.unstable_ground.push", "%s was displaced" % actor.get("name", "Actor"), {
			"actor_id": actor.get("id", ""), "from": pos.duplicate(), "to": pushed.duplicate(),
		})
	else:
		_apply_hazard_damage(actor, int(hazard.get("damage", 4)), "unstable_ground", hazard)
		(turn_result["hazard_events"] as Array).append({
			"type": "unstable_ground", "source_id": hazard.get("id", ""), "target_id": actor.get("id", ""),
			"from_pos": pos.duplicate(true), "to_pos": pos.duplicate(true), "damage": int(hazard.get("damage", 4)),
			"label": "Unstable Ground dealt damage",
		})


func _resolve_end_turn_hazards(actor: Dictionary, turn_result: Dictionary) -> void:
	if bool(actor.get("is_dead", false)):
		return
	for hazard: Dictionary in _hazards_at(actor.get("grid_pos", {}), "burning_ground"):
		_apply_hazard_damage(actor, int(hazard.get("damage", 4)), "burning_ground", hazard)
		turn_result["burning_ground_damage"] = int(hazard.get("damage", 4))
		(turn_result["hazard_events"] as Array).append({
			"type": "burning_ground", "source_id": hazard.get("id", ""), "target_id": actor.get("id", ""),
			"from_pos": actor.get("grid_pos", {}).duplicate(true), "to_pos": actor.get("grid_pos", {}).duplicate(true),
			"damage": int(hazard.get("damage", 4)), "label": "Burning Ground dealt damage",
		})
		break


func _apply_hazard_damage(actor: Dictionary, damage: int, hazard_type: String, hazard: Dictionary) -> void:
	var before: int = int(actor.get("current_hp", 0))
	actor["current_hp"] = maxi(0, before - maxi(0, damage))
	_state["metrics"]["hazard_damage"] = int(_state["metrics"].get("hazard_damage", 0)) + maxi(0, damage)
	_state["metrics"]["hazard_events"] = int(_state["metrics"].get("hazard_events", 0)) + 1
	if int(actor["current_hp"]) <= 0:
		actor["is_dead"] = true
		actor["death_round"] = int(_state.get("round", 1))
	_append_event("hazard.%s.damage" % hazard_type, "%s took %d hazard damage" % [actor.get("name", "Actor"), damage], {
		"actor_id": actor.get("id", ""), "hazard_id": hazard.get("id", ""), "damage": damage,
		"hp_before": before, "hp_after": actor["current_hp"],
	})


func _handle_objective_interaction(actor: Dictionary, response: Dictionary) -> void:
	if bool(actor.get("is_dead", false)) or str(_state.get("mode", "")) != "protect":
		return
	var objective: Dictionary = _state["objective"]
	var objective_pos: Dictionary = objective.get("position", {})
	if str(actor.get("faction", "")) == "echo" and bool(objective.get("totem_stolen", false)):
		var carrier: Dictionary = _actor_by_id(str(objective.get("totem_carrier_id", "")))
		if carrier.is_empty() or bool(carrier.get("is_dead", false)):
			objective["totem_stolen"] = false
			objective["totem_carrier_id"] = ""
			objective["status"] = "recovered"
			_append_objective_event("combat.protect.recovered", "The Charge was recovered", {"actor_id": actor.get("id", "")})
	elif str(actor.get("faction", "")) == "echo" and bool(objective.get("carryable", false)) \
			and str(objective.get("holder_id", "")) == "" and not bool(objective.get("totem_stolen", false)) \
			and _is_adjacent(actor.get("grid_pos", {}), objective_pos):
		var ping_id: String = str((_state.get("unresolved_ping", {}) as Dictionary).get("id", ""))
		if ping_id == "secure_objective" and float(response.get("influence", 0.0)) > 0.0 \
				or str(actor.get("calling_origin", "")) == "okofor":
			objective["holder_id"] = str(actor.get("id", ""))
			objective["status"] = "carried"
			_update_carried_totem_position()
			_append_objective_event("combat.protect.carried", "%s took custody of the Charge" % actor.get("name", "Echo"), {
				"holder_id": actor.get("id", ""), "holder_debuff": "-2 outgoing damage",
			})


func _update_carried_totem_position() -> void:
	if str(_state.get("mode", "")) != "protect":
		return
	var objective: Dictionary = _state["objective"]
	var carrier_id: String = str(objective.get("totem_carrier_id", "")) if bool(objective.get("totem_stolen", false)) else str(objective.get("holder_id", ""))
	if carrier_id == "":
		return
	var carrier: Dictionary = _actor_by_id(carrier_id)
	if carrier.is_empty() or bool(carrier.get("is_dead", false)):
		if bool(objective.get("totem_stolen", false)):
			objective["totem_stolen"] = false
			objective["totem_carrier_id"] = ""
			objective["status"] = "recovered"
		else:
			objective["holder_id"] = ""
			objective["status"] = "unguarded"
		return
	objective["position"] = carrier.get("grid_pos", {}).duplicate()
	var structure: Dictionary = _actor_by_id(str(objective.get("structure_id", "")))
	if not structure.is_empty():
		structure["grid_pos"] = objective["position"].duplicate()


func _advance_initiative() -> void:
	var order: Array = _state.get("initiative_order", [])
	if order.is_empty():
		return
	var next_index: int = int(_state.get("initiative_index", 0)) + 1
	if next_index >= order.size():
		next_index = 0
		_resolve_round_end()
	_state["initiative_index"] = next_index


func _resolve_round_end() -> void:
	if bool(_state.get("combat_over", false)):
		return
	var objective: Dictionary = _state["objective"]
	var round_number: int = int(_state.get("round", 1))
	if str(_state.get("mode", "")) == "recover":
		var adjacent: bool = false
		for id: String in _living_echo_ids():
			if _is_adjacent(_actor_by_id(id).get("grid_pos", {}), objective.get("position", {})):
				adjacent = true
				break
		objective["hold_counter"] = int(objective.get("hold_counter", 0)) + 1 if adjacent else 0
		objective["status"] = "holding" if adjacent else "unsecured"
		_append_objective_event("combat.recover.hold", "Relic hold %d/%d" % [objective["hold_counter"], objective["hold_required"]], {
			"adjacent": adjacent, "hold_counter": objective["hold_counter"],
		})
	else:
		_resolve_protect_theft(round_number)
		var guarded: bool = false
		for id: String in _living_echo_ids():
			if _chebyshev(_actor_by_id(id).get("grid_pos", {}), objective.get("position", {})) <= int(objective.get("guard_radius", 2)):
				guarded = true
				break
		objective["protect_counter"] = int(objective.get("protect_counter", 0)) + 1 if guarded else 0
		if not bool(objective.get("totem_stolen", false)):
			objective["status"] = "guarded" if guarded else "unguarded"
		_append_objective_event("combat.protect.guard", "Protection %d/%d" % [objective["protect_counter"], objective["protect_required"]], {
			"guarded": guarded, "protect_counter": objective["protect_counter"],
		})
	_state["metrics"]["rounds_completed"] = int(_state["metrics"].get("rounds_completed", 0)) + 1
	_check_end_condition()
	# Exactly one charge is earned for a fully completed round, independent of actor count.
	var charge: Dictionary = _state["ping_charge"]
	var charge_before: int = int(charge.get("current", 0))
	charge["current"] = mini(MAX_PING_CHARGE, charge_before + 1)
	if int(charge["current"]) != charge_before:
		_append_event("ping.charge_gained", "Round completed: Ping Charge increased", {
			"completed_round": round_number, "current": charge["current"],
		})
		if int(charge["current"]) in [2, 3, 5]:
			_state["attention_cues"].append("Round %d completed: a new ping scope is available." % round_number)
	# The activation round is the hard duration cap; dead recipients cannot keep it alive.
	var ping: Dictionary = _state.get("unresolved_ping", {})
	if not ping.is_empty():
		var remaining: Array = ping.get("remaining_recipient_ids", [])
		for id_v: Variant in remaining.duplicate():
			var recipient: Dictionary = _actor_by_id(str(id_v))
			if recipient.is_empty() or bool(recipient.get("is_dead", false)):
				remaining.erase(id_v)
		ping["remaining_recipient_ids"] = remaining
		if remaining.is_empty() or round_number >= int(ping.get("expires_after_round", round_number + 1)):
			_expire_ping("round_duration_elapsed" if not remaining.is_empty() else "no_living_recipients")
	_state["round"] = round_number + 1


func _resolve_protect_theft(round_number: int) -> void:
	var objective: Dictionary = _state["objective"]
	if bool(objective.get("totem_stolen", false)):
		var carrier: Dictionary = _actor_by_id(str(objective.get("totem_carrier_id", "")))
		if carrier.is_empty() or bool(carrier.get("is_dead", false)):
			objective["totem_stolen"] = false
			objective["totem_carrier_id"] = ""
			objective["status"] = "recovered"
			_append_objective_event("combat.protect.theft_cleared", "Enemy carrier fell; the Charge can be recovered", {})
		return
	var adjacent_echo: bool = false
	for id: String in _living_echo_ids():
		if _is_adjacent(_actor_by_id(id).get("grid_pos", {}), objective.get("position", {})):
			adjacent_echo = true
			break
	if adjacent_echo:
		return
	var candidates: Array[Dictionary] = []
	for id: String in _living_enemy_ids():
		var enemy: Dictionary = _actor_by_id(id)
		if _is_adjacent(enemy.get("grid_pos", {}), objective.get("position", {})):
			candidates.append(enemy)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", "")) < str(b.get("id", "")))
	if _rng("prototype.keeper.protect.theft.round.%d" % round_number).randf() < 0.50:
		var thief: Dictionary = candidates[0]
		objective["totem_stolen"] = true
		objective["totem_carrier_id"] = str(thief.get("id", ""))
		objective["holder_id"] = ""
		objective["status"] = "stolen"
		_update_carried_totem_position()
		_state["attention_cues"].append("The Charge was stolen.")
		_append_objective_event("combat.protect.theft", "%s stole the Charge" % thief.get("name", "An enemy"), {
			"carrier_id": thief.get("id", ""), "double_damage": true,
		})


func _check_end_condition() -> void:
	if bool(_state.get("combat_over", false)):
		return
	if _living_enemy_ids().is_empty():
		_finish_battle(true, "all_enemies_defeated")
		return
	if _living_echo_ids().is_empty():
		_finish_battle(false, "all_echoes_dead")
		return
	var objective: Dictionary = _state["objective"]
	if str(_state.get("mode", "")) == "recover" and int(objective.get("hold_counter", 0)) >= int(objective.get("hold_required", 2)):
		_finish_battle(true, "relic_secured")
	elif str(_state.get("mode", "")) == "protect":
		var structure: Dictionary = _actor_by_id(str(objective.get("structure_id", "")))
		if int(objective.get("hp", 0)) <= 0 or (not structure.is_empty() and bool(structure.get("is_dead", false))):
			_finish_battle(false, "entity_lost")
		elif int(objective.get("protect_counter", 0)) >= int(objective.get("protect_required", 4)):
			if bool(objective.get("totem_stolen", false)):
				_finish_battle(false, "totem_taken")
			else:
				_finish_battle(true, "protected")


func _finish_battle(victory: bool, reason: String) -> void:
	_state["combat_over"] = true
	_state["phase"] = "review"
	_state["result"] = {"victory": victory, "reason": reason}
	_append_event("combat.finished", "Victory" if victory else "Defeat", {"victory": victory, "reason": reason})


func _expire_ping(reason: String) -> void:
	var ping: Dictionary = _state.get("unresolved_ping", {})
	if ping.is_empty():
		return
	_append_event("ping.expired", "%s resolved" % ping.get("label", "Ping"), {"ping_id": ping.get("id", ""), "reason": reason})
	for recipient_id_v: Variant in ping.get("recipient_ids", []):
		var recipient: Dictionary = _actor_by_id(str(recipient_id_v))
		if not recipient.is_empty() and str(recipient.get("guidance_state", "")) == "pending":
			recipient["guidance_state"] = "unaffected"
	_state["unresolved_ping"] = {}


func _empty_ping(ping_id: String, subject: Dictionary) -> Dictionary:
	var definition: Dictionary = PING_DEFINITIONS.get(ping_id, {})
	var required: int = int(definition.get("cost", 0))
	var current: int = int(_state.get("ping_charge", {}).get("current", 0))
	return {
		"id": ping_id, "label": definition.get("label", "Unknown Ping"),
		"suggestion": definition.get("suggestion", ""),
		"mechanical_influence": definition.get("mechanical_influence", ""),
		"targeting_instruction": definition.get("targeting_instruction", ""),
		"recipient_mode": definition.get("recipient_mode", ""),
		"charge_required": required, "subject": subject.duplicate(true),
		"footprint": [], "eligible_recipient_ids": [], "recipient_ids": [],
		"remaining_recipient_ids": [], "confirmed_round": 0,
		"activation_round": int(_state.get("round", 0)) + 1, "expires_after_round": 0,
		"availability_state": "invalid_subject",
		"rounds_until_charge": maxi(0, required - current),
		"expected_duration": "Activates next round; resolves on each recipient's first living turn.",
		"valid": false, "invalid_reason": "Select a valid subject.",
	}


func _preview_hold_ground(preview: Dictionary, subject: Dictionary) -> void:
	var actor_id: String = str(subject.get("actor_id", subject.get("echo_id", "")))
	var actor: Dictionary = _actor_by_id(actor_id)
	var anchor: Dictionary = _subject_pos(subject, ["anchor", "position", "pos"])
	if actor.is_empty() and not anchor.is_empty():
		var nearby: Array[String] = []
		for living_id: String in _living_echo_ids():
			if _same_pos(_actor_by_id(living_id).get("grid_pos", {}), anchor):
				nearby.append(living_id)
		if nearby.is_empty():
			for living_id: String in _living_echo_ids():
				if _chebyshev(_actor_by_id(living_id).get("grid_pos", {}), anchor) <= 1:
					nearby.append(living_id)
		if nearby.size() == 1:
			actor_id = nearby[0]
			actor = _actor_by_id(actor_id)
	if actor.is_empty() or str(actor.get("faction", "")) != "echo" or bool(actor.get("is_dead", false)):
		preview["invalid_reason"] = "Select exactly one living Echo."
		return
	if anchor.is_empty():
		anchor = actor.get("grid_pos", {}).duplicate()
	if not _is_walkable(anchor):
		preview["invalid_reason"] = "The anchor is not walkable."
		return
	if _chebyshev(anchor, actor.get("grid_pos", {})) > 1:
		preview["invalid_reason"] = "The anchor must be within 1 tile of the selected Echo."
		return
	preview["subject"] = {"kind": "anchor", "actor_id": actor_id, "anchor": anchor.duplicate()}
	preview["footprint"] = [anchor.duplicate()]
	preview["eligible_recipient_ids"] = [actor_id]
	_validate_recipient_preview(preview)


func _preview_break_through(preview: Dictionary, subject: Dictionary) -> void:
	var lane: Array[Dictionary] = []
	var raw_cells: Variant = subject.get("cells", subject.get("lane", []))
	if raw_cells is Array and not (raw_cells as Array).is_empty():
		for cell_v: Variant in raw_cells:
			if cell_v is Dictionary and lane.size() < 5:
				lane.append(_copy_pos(cell_v as Dictionary))
	else:
		var start: Dictionary = _subject_pos(subject, ["start", "position"])
		var end: Dictionary = _subject_pos(subject, ["end"])
		if not start.is_empty() and not end.is_empty():
			lane = _straight_lane(start, end, 5)
	if lane.is_empty():
		preview["invalid_reason"] = "Select a contiguous lane up to 5 tiles long."
		return
	for i: int in range(lane.size()):
		if not _is_walkable(lane[i]):
			preview["invalid_reason"] = "Every lane tile must be walkable."
			return
		if i > 0 and not _is_adjacent(lane[i - 1], lane[i]):
			preview["invalid_reason"] = "The lane must be contiguous."
			return
	var recipients: Array[String] = []
	var start_pos: Dictionary = lane[0]
	for id: String in _living_echo_ids():
		var pos: Dictionary = _actor_by_id(id).get("grid_pos", {})
		if _contains_pos(lane, pos) or _chebyshev(pos, start_pos) <= 1:
			recipients.append(id)
	preview["subject"] = {"kind": "lane", "start": start_pos.duplicate(), "end": lane[lane.size() - 1].duplicate()}
	preview["footprint"] = lane
	preview["eligible_recipient_ids"] = recipients
	_validate_recipient_preview(preview)


func _preview_focus_threat(preview: Dictionary, subject: Dictionary) -> void:
	var enemy_id: String = str(subject.get("enemy_id", subject.get("actor_id", "")))
	if enemy_id == "" and bool(_state["objective"].get("totem_stolen", false)):
		enemy_id = str(_state["objective"].get("totem_carrier_id", ""))
	var enemy: Dictionary = _actor_by_id(enemy_id)
	if enemy.is_empty() or str(enemy.get("faction", "")) != "enemy" or bool(enemy.get("is_dead", false)):
		preview["invalid_reason"] = "Select one visible living enemy or enemy totem carrier."
		return
	preview["subject"] = {"kind": "enemy", "enemy_id": enemy_id, "position": enemy.get("grid_pos", {}).duplicate()}
	preview["footprint"] = [enemy.get("grid_pos", {}).duplicate()]
	preview["eligible_recipient_ids"] = _living_echo_ids()
	_validate_recipient_preview(preview)


func _preview_regroup(preview: Dictionary, subject: Dictionary) -> void:
	var rally: Dictionary = _subject_pos(subject, ["rally", "position", "pos"])
	if rally.is_empty() or not _is_walkable(rally):
		preview["invalid_reason"] = "Select a walkable rally tile."
		return
	var footprint: Array[Dictionary] = []
	for key_v: Variant in (_state["board"].get("walkable", {}) as Dictionary).keys():
		var pos: Dictionary = _key_pos(str(key_v))
		if _chebyshev(pos, rally) <= 3:
			footprint.append(pos)
	var recipients: Array[String] = []
	for id: String in _living_echo_ids():
		if _chebyshev(_actor_by_id(id).get("grid_pos", {}), rally) <= 3:
			recipients.append(id)
	preview["subject"] = {"kind": "rally", "rally": rally.duplicate(), "radius": 3}
	preview["footprint"] = footprint
	preview["eligible_recipient_ids"] = recipients
	_validate_recipient_preview(preview)


func _validate_recipient_preview(preview: Dictionary) -> void:
	var recipients: Array = preview.get("eligible_recipient_ids", [])
	if recipients.is_empty():
		preview["valid"] = false
		preview["invalid_reason"] = "No living Echo is eligible for this ping."
		return
	if str(preview.get("recipient_mode", "")) == "echo_specific" and recipients.size() != 1:
		preview["valid"] = false
		preview["invalid_reason"] = "Echo-specific guidance requires exactly one recipient."
		return
	preview["valid"] = true
	preview["invalid_reason"] = ""


func _finalize_ping_availability(preview: Dictionary) -> void:
	var subject_valid: bool = bool(preview.get("valid", false))
	var subject_reason: String = str(preview.get("invalid_reason", "Select a valid subject."))
	var recipients: Array = preview.get("eligible_recipient_ids", [])
	var required: int = int(preview.get("charge_required", 0))
	var current: int = int(_state.get("ping_charge", {}).get("current", 0))
	preview["rounds_until_charge"] = maxi(0, required - current)
	preview["activation_round"] = int(_state.get("round", 0)) + 1
	if not (_state.get("unresolved_ping", {}) as Dictionary).is_empty():
		preview["availability_state"] = "blocked_unresolved"
		preview["valid"] = false
		preview["invalid_reason"] = "The previous ping is still resolving."
	elif not subject_valid:
		preview["availability_state"] = "no_eligible_recipients" if recipients.is_empty() and subject_reason.begins_with("No living Echo") else "invalid_subject"
		preview["valid"] = false
		preview["invalid_reason"] = subject_reason
	elif current < required:
		preview["availability_state"] = "insufficient_charge"
		preview["valid"] = false
		preview["invalid_reason"] = "Requires %d Ping Charge; %d more completed round%s." % [required, required - current, "" if required - current == 1 else "s"]
	else:
		preview["availability_state"] = "available"
		preview["valid"] = true
		preview["invalid_reason"] = ""


func _build_ping_library() -> Dictionary:
	var library: Dictionary = {}
	for ping_id_v: Variant in PING_DEFINITIONS.keys():
		var ping_id: String = str(ping_id_v)
		var definition: Dictionary = PING_DEFINITIONS[ping_id]
		library[ping_id] = {
			"id": ping_id,
			"label": definition.get("label", ping_id),
			"suggestion": definition.get("suggestion", ""),
			"mechanical_influence": definition.get("mechanical_influence", ""),
			"targeting_instruction": definition.get("targeting_instruction", ""),
			"recipient_mode": definition.get("recipient_mode", ""),
			"charge_required": int(definition.get("cost", 0)),
		}
	return library


func _guidance_state_for_outcome(outcome: String) -> String:
	match outcome:
		"align", "interpret":
			return "listening"
		"hesitate", "object":
			return "resisting"
		"refuse":
			return "rejecting"
		_:
			return "unaffected"


func _finalize_turn_result(result: Dictionary) -> Dictionary:
	result["tick"] = int(_state.get("tick", 0))
	result["round"] = int(result.get("round", _state.get("round", 0)))
	var actor: Dictionary = _actor_by_id(str(result.get("actor_id", "")))
	var response_v: Variant = result.get("ping_response", result.get("response", {}))
	var response: Dictionary = response_v if response_v is Dictionary else {}
	result.erase("response")
	result["ping_response"] = response.duplicate(true)
	var outcome: String = str(response.get("outcome", ""))
	match outcome:
		"align": result["guidance_expression"] = "follow"
		"interpret": result["guidance_expression"] = "interpret"
		"hesitate", "object": result["guidance_expression"] = "resist"
		"refuse": result["guidance_expression"] = "reject"
		_: result["guidance_expression"] = "unaffected"
	var action_type: String = str(result.get("action_type", "wait"))
	if action_type in ["actor.move", "move"]:
		result["action_type"] = "move"
	elif action_type in ["melee_attack", "actor.attack", "attack"]:
		result["action_type"] = "attack"
	elif action_type in ["actor.guard", "guard"]:
		result["action_type"] = "guard"
	elif action_type in ["objective", "actor.objective"]:
		result["action_type"] = "objective"
	else:
		result["action_type"] = "wait"
	if not result.get("path", null) is Array:
		result["path"] = []
	if not result.get("hazard_events", null) is Array:
		result["hazard_events"] = []
	if not result.get("objective_events", null) is Array:
		result["objective_events"] = []
	if not result.get("follow_up", null) is Array:
		result["follow_up"] = []
	result["target_id"] = str(result.get("target_id", ""))
	result["damage"] = int(result.get("damage", 0))
	result["hit"] = bool(result.get("hit", int(result["damage"]) > 0))
	if not str(result["target_id"]).is_empty():
		var target: Dictionary = _actor_by_id(str(result["target_id"]))
		if not target.is_empty() and str(result.get("action_type", "")) == "attack":
			result["to_pos"] = target.get("grid_pos", {}).duplicate(true)
	if not actor.is_empty() and not result.has("to_pos"):
		result["to_pos"] = actor.get("grid_pos", {}).duplicate(true)
	return result


func _best_step(actor: Dictionary, destination: Dictionary) -> Dictionary:
	var start: Dictionary = actor.get("grid_pos", {})
	if _same_pos(start, destination):
		return start.duplicate()
	var candidates: Array[Dictionary] = []
	for delta: Vector2i in NEIGHBORS:
		var pos: Dictionary = {"col": int(start.get("col", 0)) + delta.x, "row": int(start.get("row", 0)) + delta.y}
		if not _is_walkable(pos) or _is_occupied(pos, str(actor.get("id", ""))):
			continue
		# Plan through temporarily occupied cells; only the immediate step must be free.
		# This prevents autonomous parties from treating one another as permanent walls at chokepoints.
		var path_distance: int = _shortest_distance(pos, destination, "*")
		if path_distance >= 9999:
			continue
		var hazard_cost: int = _movement_hazard_cost(actor, pos)
		var cohesion_cost: int = 0
		if str(actor.get("faction", "")) == "echo" and str(_state.get("directive_id", "")) == "hold_the_circle":
			cohesion_cost = _distance_to_nearest_ally(actor, pos) * 2
		var fan_out_bonus: int = 0
		if str(actor.get("faction", "")) == "echo" and str(_state.get("directive_id", "")) == "press_the_path":
			fan_out_bonus = -mini(2, _distance_to_nearest_ally(actor, pos))
		var backtrack_cost: int = 25 if _same_pos(pos, actor.get("_previous_grid_pos", {})) else 0
		var visit_cost: int = int((actor.get("_visited_cells", {}) as Dictionary).get(_pos_key(pos), 0)) * 30
		candidates.append({"pos": pos, "score": path_distance * 10 + hazard_cost + cohesion_cost + fan_out_bonus + backtrack_cost + visit_cost})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) == int(b["score"]):
			return _pos_key(a["pos"]) < _pos_key(b["pos"])
		return int(a["score"]) < int(b["score"])
	)
	return (candidates[0]["pos"] as Dictionary).duplicate()


func _shortest_distance(start: Dictionary, goal: Dictionary, ignore_actor_id: String = "") -> int:
	if _same_pos(start, goal):
		return 0
	var frontier: Array[Dictionary] = [start.duplicate()]
	var distance: Dictionary = {_pos_key(start): 0}
	var index: int = 0
	while index < frontier.size():
		var current: Dictionary = frontier[index]
		index += 1
		var current_distance: int = int(distance[_pos_key(current)])
		for delta: Vector2i in NEIGHBORS:
			var next: Dictionary = {"col": int(current.get("col", 0)) + delta.x, "row": int(current.get("row", 0)) + delta.y}
			var key: String = _pos_key(next)
			if distance.has(key) or not _is_walkable(next):
				continue
			if ignore_actor_id != "*" and _is_occupied(next, ignore_actor_id) and not _same_pos(next, goal):
				continue
			distance[key] = current_distance + 1
			if _same_pos(next, goal):
				return current_distance + 1
			frontier.append(next)
	return 9999


func _movement_hazard_cost(actor: Dictionary, pos: Dictionary) -> int:
	var cost: int = 0
	for hazard: Dictionary in _hazards_at(pos):
		match str(hazard.get("type", "")):
			"burning_ground": cost += 22
			"unstable_ground": cost += 16
			"binding_growth": cost += 10
	var directive: String = str(_state.get("directive_id", ""))
	if directive == "press_the_path" or directive == "seek_signs":
		cost = int(cost * 0.55)
	if directive == "scout_carefully":
		cost = int(cost * 1.45)
	if str(actor.get("tendency", "")).contains("cautious"):
		cost *= 2
	if int(actor.get("fear", 0)) >= 55:
		cost += 12
	return cost


func _nearest_actor(actor: Dictionary, target_faction: String) -> Dictionary:
	var nearest: Dictionary = {}
	var best: int = 9999
	for candidate_v: Variant in _state.get("actors", []):
		var candidate: Dictionary = candidate_v as Dictionary
		if str(candidate.get("faction", "")) != target_faction or bool(candidate.get("is_dead", false)):
			continue
		var distance: int = _shortest_distance(actor.get("grid_pos", {}), candidate.get("grid_pos", {}), "*")
		if distance < best or distance == best and str(candidate.get("id", "")) < str(nearest.get("id", "~")):
			nearest = candidate
			best = distance
	return nearest


func _most_vulnerable_echo(actor: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var lowest_ratio: float = 2.0
	for id: String in _living_echo_ids():
		if id == str(actor.get("id", "")):
			continue
		var candidate: Dictionary = _actor_by_id(id)
		var ratio: float = float(candidate.get("current_hp", 0)) / float(maxi(1, int(candidate.get("stats", {}).get("max_hp", 1))))
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			result = candidate
	return result


func _calling_ping_fit(calling: String, ping_id: String) -> int:
	var preferred: Dictionary = {
		"okofor": ["hold_ground", "regroup", "secure_objective"],
		"aduro": ["break_through", "focus_threat"],
		"sum_okwanfo": ["break_through", "secure_objective"],
		"kra_soro": ["focus_threat", "break_through"],
		"onyamesu": ["hold_ground", "regroup"],
		"okomfo": ["regroup", "secure_objective"],
	}
	if ping_id in preferred.get(calling, []):
		return 15
	if calling == "aduro" and ping_id == "hold_ground":
		return -13
	if calling == "okofor" and ping_id == "break_through":
		return -7
	if calling == "sum_okwanfo" and ping_id == "focus_threat":
		return -5
	return 2


func _fear_refusal_threshold(actor: Dictionary) -> int:
	match str(actor.get("expression_band", "nascent")):
		"whole": return 90
		"grounded": return 80
		"forming": return 72
		_: return 65


func _objective_pressure() -> int:
	var objective: Dictionary = _state.get("objective", {})
	if str(_state.get("mode", "")) == "recover":
		return 12 if int(objective.get("hold_counter", 0)) > 0 else 4
	if bool(objective.get("totem_stolen", false)):
		return 24
	var hp_ratio: float = float(objective.get("hp", 0)) / float(maxi(1, int(objective.get("max_hp", 1))))
	if hp_ratio <= 0.35:
		return 20
	var enemies_near: int = 0
	for id: String in _living_enemy_ids():
		if _chebyshev(_actor_by_id(id).get("grid_pos", {}), objective.get("position", {})) <= 3:
			enemies_near += 1
	return enemies_near * 4


func _bond_pressure(actor: Dictionary) -> int:
	var bonds: Dictionary = actor.get("bonds", {})
	var pressure: int = 0
	for other_id_v: Variant in bonds.keys():
		if int(bonds[other_id_v]) < 30:
			continue
		var other: Dictionary = _actor_by_id(str(other_id_v))
		if other.is_empty() or bool(other.get("is_dead", false)):
			continue
		var hp_ratio: float = float(other.get("current_hp", 0)) / float(maxi(1, int(other.get("stats", {}).get("max_hp", 1))))
		if hp_ratio <= 0.50 or _living_opponents_within(other, 2).size() >= 2:
			pressure = maxi(pressure, 10)
	return pressure


func _living_opponents_within(actor: Dictionary, radius: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target_faction: String = "enemy" if str(actor.get("faction", "")) == "echo" else "echo"
	for candidate_v: Variant in _state.get("actors", []):
		var candidate: Dictionary = candidate_v as Dictionary
		if str(candidate.get("faction", "")) == target_faction and not bool(candidate.get("is_dead", false)) \
				and _chebyshev(actor.get("grid_pos", {}), candidate.get("grid_pos", {})) <= radius:
			result.append(candidate)
	return result


func _hazards_at(pos: Dictionary, only_type: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hazard_v: Variant in _state.get("board", {}).get("hazards", []):
		if not hazard_v is Dictionary:
			continue
		var hazard: Dictionary = hazard_v as Dictionary
		if only_type != "" and str(hazard.get("type", "")) != only_type:
			continue
		if _contains_pos(hazard.get("cells", []), pos):
			result.append(hazard)
	return result


func _footprint_has_hazard(footprint: Array) -> bool:
	for pos_v: Variant in footprint:
		if pos_v is Dictionary and not _hazards_at(pos_v as Dictionary).is_empty():
			return true
	return false


func _position_is_hazardous(pos: Dictionary) -> bool:
	return not _hazards_at(pos).is_empty()


func _nearest_safe_cell(start: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for key_v: Variant in (_state["board"].get("walkable", {}) as Dictionary).keys():
		var pos: Dictionary = _key_pos(str(key_v))
		if not _position_is_hazardous(pos) and not _is_occupied(pos):
			candidates.append({"pos": pos, "distance": _chebyshev(start, pos)})
	if candidates.is_empty():
		return start.duplicate()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["distance"]) == int(b["distance"]): return _pos_key(a["pos"]) < _pos_key(b["pos"])
		return int(a["distance"]) < int(b["distance"])
	)
	return (candidates[0]["pos"] as Dictionary).duplicate()


func _distance_to_nearest_ally(actor: Dictionary, from_pos: Dictionary) -> int:
	var best: int = 99
	for candidate_v: Variant in _state.get("actors", []):
		var candidate: Dictionary = candidate_v as Dictionary
		if str(candidate.get("id", "")) == str(actor.get("id", "")) or str(candidate.get("faction", "")) != str(actor.get("faction", "")) \
				or bool(candidate.get("is_dead", false)) or bool(candidate.get("is_structure", false)):
			continue
		best = mini(best, _chebyshev(from_pos, candidate.get("grid_pos", {})))
	return best if best < 99 else 0


func _straight_lane(start: Dictionary, end: Dictionary, max_length: int) -> Array[Dictionary]:
	var lane: Array[Dictionary] = [start.duplicate()]
	var current: Dictionary = start.duplicate()
	while lane.size() < max_length and not _same_pos(current, end):
		var dx: int = signi(int(end.get("col", 0)) - int(current.get("col", 0)))
		var dy: int = signi(int(end.get("row", 0)) - int(current.get("row", 0)))
		current = {"col": int(current.get("col", 0)) + dx, "row": int(current.get("row", 0)) + dy}
		lane.append(current.duplicate())
	return lane


func _subject_pos(subject: Dictionary, keys: Array[String]) -> Dictionary:
	for key: String in keys:
		var value: Variant = subject.get(key, null)
		if value is Dictionary and (value as Dictionary).has("col") and (value as Dictionary).has("row"):
			return _copy_pos(value as Dictionary)
	return {}


func _first_walkable_cells(count: int, reverse: bool) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for key_v: Variant in (_state["board"].get("walkable", {}) as Dictionary).keys():
		cells.append(_key_pos(str(key_v)))
	cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("col", 0)) == int(b.get("col", 0)):
			return int(a.get("row", 0)) > int(b.get("row", 0)) if reverse else int(a.get("row", 0)) < int(b.get("row", 0))
		return int(a.get("col", 0)) > int(b.get("col", 0)) if reverse else int(a.get("col", 0)) < int(b.get("col", 0))
	)
	return cells.slice(0, mini(count, cells.size()))


func _deployment_is_valid() -> bool:
	var seen: Dictionary = {}
	for id: String in _living_echo_ids():
		var pos: Dictionary = _actor_by_id(id).get("grid_pos", {})
		var key: String = _pos_key(pos)
		if not _contains_pos(_state["board"].get("deployment_slots", []), pos) or seen.has(key):
			return false
		seen[key] = true
	return seen.size() == 4


func _actor_by_id(id: String) -> Dictionary:
	for actor_v: Variant in _state.get("actors", []):
		var actor: Dictionary = actor_v as Dictionary
		if str(actor.get("id", "")) == id:
			return actor
	return {}


func _living_echo_ids() -> Array[String]:
	return _living_ids_for_faction("echo")


func _living_enemy_ids() -> Array[String]:
	return _living_ids_for_faction("enemy")


func _living_ids_for_faction(faction: String) -> Array[String]:
	var result: Array[String] = []
	for actor_v: Variant in _state.get("actors", []):
		var actor: Dictionary = actor_v as Dictionary
		if str(actor.get("faction", "")) == faction and not bool(actor.get("is_dead", false)):
			result.append(str(actor.get("id", "")))
	return result


func _is_walkable(pos: Dictionary) -> bool:
	return bool((_state.get("board", {}).get("walkable", {}) as Dictionary).get(_pos_key(pos), false))


func _is_occupied(pos: Dictionary, ignore_actor_id: String = "") -> bool:
	for actor_v: Variant in _state.get("actors", []):
		var actor: Dictionary = actor_v as Dictionary
		if str(actor.get("id", "")) == ignore_actor_id or bool(actor.get("is_dead", false)):
			continue
		# A carried structure shares the carrier's cell by design and should not block it.
		if bool(actor.get("is_structure", false)) and (str(_state.get("objective", {}).get("holder_id", "")) != "" \
				or str(_state.get("objective", {}).get("totem_carrier_id", "")) != ""):
			continue
		if _same_pos(actor.get("grid_pos", {}), pos):
			return true
	return false


func _living_actor_at(pos: Dictionary, ignore_actor_id: String = "") -> Dictionary:
	for actor_v: Variant in _state.get("actors", []):
		var actor: Dictionary = actor_v as Dictionary
		if str(actor.get("id", "")) == ignore_actor_id or bool(actor.get("is_dead", false)):
			continue
		if _same_pos(actor.get("grid_pos", {}), pos):
			return actor
	return {}


func _contains_pos(positions: Array, pos: Dictionary) -> bool:
	for candidate_v: Variant in positions:
		if candidate_v is Dictionary and _same_pos(candidate_v as Dictionary, pos):
			return true
	return false


func _same_pos(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("col", -999)) == int(b.get("col", -998)) and int(a.get("row", -999)) == int(b.get("row", -998))


func _is_adjacent(a: Dictionary, b: Dictionary) -> bool:
	return _chebyshev(a, b) == 1


func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(absi(int(a.get("col", 0)) - int(b.get("col", 0))), absi(int(a.get("row", 0)) - int(b.get("row", 0))))


func _copy_pos(pos: Dictionary) -> Dictionary:
	return {"col": int(pos.get("col", 0)), "row": int(pos.get("row", 0))}


func _pos_key(pos: Dictionary) -> String:
	return "%d,%d" % [int(pos.get("col", 0)), int(pos.get("row", 0))]


func _key_pos(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return {"col": 0, "row": 0}
	return {"col": int(parts[0]), "row": int(parts[1])}


func _rng(rng_namespace: String) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_text: String = "%d:%s" % [int(_state.get("seed", 0)), rng_namespace]
	rng.seed = seed_text.hash()
	return rng


func _append_objective_event(type: String, message: String, data: Dictionary) -> void:
	_state["metrics"]["objective_events"] = int(_state["metrics"].get("objective_events", 0)) + 1
	_append_event(type, message, data)


func _append_event(type: String, message: String, data: Dictionary) -> void:
	_state["timeline"].append({
		"tick": int(_state.get("tick", 0)), "round": int(_state.get("round", 0)),
		"type": type, "message": message, "data": data.duplicate(true),
	})


func _timeline_tail(count: int) -> Array:
	var timeline: Array = _state.get("timeline", [])
	var start: int = maxi(0, timeline.size() - count)
	return timeline.slice(start).duplicate(true)
