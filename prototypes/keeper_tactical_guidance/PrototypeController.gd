class_name KeeperTacticalPrototypeController
extends Node

## Lead-owned integration boundary for the isolated Keeper Tactical Guidance prototype.
## It translates scene actions into board/simulation calls and publishes deep-copied snapshots.

const PrototypeSimulationScript := preload("res://prototypes/keeper_tactical_guidance/simulation/PrototypeSimulation.gd")
const TacticalBoardGeneratorScript := preload("res://prototypes/keeper_tactical_guidance/board/TacticalBoardGenerator.gd")

const DEFAULT_SEED: int = 24051987
const BASE_PLAYBACK_SECONDS: float = 0.75
const PLAYBACK_SPEED_OPTIONS: Array[Dictionary] = [
	{"id": "slow", "label": "Slow", "multiplier": 0.6},
	{"id": "normal", "label": "Normal", "multiplier": 1.0},
	{"id": "fast", "label": "Fast", "multiplier": 1.8},
]

@onready var _ui: KeeperTacticalPrototypeUI = %PrototypeUI
@onready var _playback_timer: Timer = %PlaybackTimer

var _simulation: PrototypeSimulation
var _seed: int = DEFAULT_SEED
var _mode: String = "recover"
var _phase: String = "briefing"
var _playback_speed_id: String = "normal"
var _ping_preview: Dictionary = {}
var _queued_ping_confirmation: Dictionary = {}
var _deployment_assignments: Dictionary = {}
var _selected_deployment_actor_id: String = ""


func _ready() -> void:
	_simulation = PrototypeSimulationScript.new()
	_simulation.state_changed.connect(_on_simulation_state_changed)
	_ui.action_requested.connect(handle_action)
	_update_playback_interval()
	_playback_timer.timeout.connect(_on_playback_timer_timeout)
	_generate_battle(_seed, _mode, "briefing")


func handle_action(action: Dictionary) -> void:
	var action_type: String = str(action.get("type", ""))
	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	match action_type:
		"prototype.seed.set":
			_generate_battle(int(payload.get("seed", DEFAULT_SEED)), _mode, "briefing")
		"prototype.mode.select":
			var requested_mode: String = str(payload.get("mode", "recover"))
			_generate_battle(_seed, requested_mode, "briefing")
		"prototype.board.reroll":
			_generate_battle(_next_seed(_seed), _mode, "briefing")
		"prototype.phase.prepare":
			_enter_preparation()
		"prototype.directive.select":
			_simulation.set_directive(str(payload.get("directive_id", "")))
		"prototype.deployment.select_echo":
			_select_deployment_echo(str(payload.get("actor_id", "")))
		"prototype.deployment.assign_slot":
			_assign_deployment(int(payload.get("slot_index", -1)))
		"prototype.combat.start":
			_start_combat()
		"prototype.playback.speed":
			_set_playback_speed(str(payload.get("speed_id", "normal")))
		"prototype.ping.select":
			_preview_ping(str(payload.get("ping_id", "")), {})
		"prototype.ping.preview":
			_preview_ping(str(payload.get("ping_id", "")), payload.get("subject", {}))
		"prototype.ping.confirm":
			_confirm_ping(str(payload.get("ping_id", "")), payload.get("subject", {}))
		"prototype.ping.cancel":
			_ping_preview = {}
			_queued_ping_confirmation = {}
			_simulation.cancel_ping()
		"prototype.restart.same_seed":
			_generate_battle(_seed, _mode, "briefing")
		"prototype.restart.new_seed":
			_generate_battle(_next_seed(_seed), _mode, "briefing")
		_:
			push_warning("Keeper prototype ignored unknown action: %s" % action_type)


func get_snapshot() -> Dictionary:
	return _build_snapshot()


func _generate_battle(seed: int, mode: String, phase: String) -> void:
	_playback_timer.stop()
	_playback_speed_id = "normal"
	_update_playback_interval()
	_ping_preview = {}
	_queued_ping_confirmation = {}
	_deployment_assignments = {}
	_selected_deployment_actor_id = ""
	_seed = seed
	_mode = mode if mode in ["recover", "protect"] else "recover"
	_phase = phase
	var board: Dictionary = TacticalBoardGeneratorScript.generate(_seed, _mode)
	_simulation.setup_battle(_seed, _mode, board)
	_publish_snapshot()


func _enter_preparation() -> void:
	_phase = "preparation"
	_ping_preview = {}
	_queued_ping_confirmation = {}
	_deployment_assignments = {}
	_selected_deployment_actor_id = ""
	var state: Dictionary = _simulation.get_state()
	var slots: Array = state.get("board", {}).get("deployment_slots", [])
	var next_slot: int = 0
	for actor_v: Variant in state.get("actors", []):
		if not actor_v is Dictionary:
			continue
		var actor: Dictionary = actor_v as Dictionary
		if str(actor.get("faction", "")) != "echo" or next_slot >= slots.size():
			continue
		var actor_id: String = str(actor.get("id", ""))
		_deployment_assignments[actor_id] = next_slot
		next_slot += 1
	_publish_snapshot()


func _select_deployment_echo(actor_id: String) -> void:
	if _phase != "preparation" or not _deployment_assignments.has(actor_id):
		return
	_selected_deployment_actor_id = actor_id
	_publish_snapshot()


func _assign_deployment(slot_index: int) -> void:
	var actor_id: String = _selected_deployment_actor_id
	var state: Dictionary = _simulation.get_state()
	var slots: Array = state.get("board", {}).get("deployment_slots", [])
	if actor_id.is_empty() or slot_index < 0 or slot_index >= slots.size():
		return
	var displaced_actor_id: String = ""
	for other_id_v: Variant in _deployment_assignments.keys():
		if str(other_id_v) != actor_id and int(_deployment_assignments[other_id_v]) == slot_index:
			displaced_actor_id = str(other_id_v)
			break
	var position_v: Variant = slots[slot_index]
	if position_v is Dictionary:
		var previous_slot: Variant = _deployment_assignments.get(actor_id, null)
		_deployment_assignments[actor_id] = slot_index
		if not displaced_actor_id.is_empty() and previous_slot != null:
			_deployment_assignments[displaced_actor_id] = int(previous_slot)
		if not _simulation.set_deployment(actor_id, position_v as Dictionary):
			_deployment_assignments[actor_id] = int(previous_slot)
			if not displaced_actor_id.is_empty():
				_deployment_assignments[displaced_actor_id] = slot_index
			return
		_publish_snapshot()


func _start_combat() -> void:
	# start_combat emits state_changed synchronously. Set the owning scene phase first so
	# every emitted snapshot routes to the combat panel without a preparation-frame flash.
	var previous_phase: String = _phase
	_phase = "combat"
	_queued_ping_confirmation = {}
	if _simulation.start_combat():
		_ping_preview = {}
		_publish_snapshot()
		_playback_timer.start()
	else:
		_phase = previous_phase
		_publish_snapshot()


func _resolve_one_turn() -> void:
	if _phase != "combat":
		return
	_simulation.resolve_next_turn()
	_update_playback_interval(_simulation.get_state().get("last_turn_result", {}))
	_refresh_ping_preview()
	_sync_phase_from_simulation()
	_publish_snapshot()


func _set_playback_speed(speed_id: String) -> void:
	if not speed_id in ["slow", "normal", "fast"]:
		return
	_playback_speed_id = speed_id
	_update_playback_interval(_simulation.get_state().get("last_turn_result", {}))
	if _phase == "combat" and not bool(_simulation.get_state().get("combat_over", false)):
		_playback_timer.start()
	_publish_snapshot()


func _preview_ping(ping_id: String, subject_v: Variant) -> void:
	var subject: Dictionary = subject_v if subject_v is Dictionary else {}
	# The board UI reports one clicked cell at a time. Preserve the first Break Through
	# anchor and use subsequent clicks as its endpoint, producing the specified 1-5-cell lane.
	if ping_id == "break_through" and str(_ping_preview.get("id", "")) == ping_id:
		var previous_subject: Dictionary = _ping_preview.get("subject", {})
		var previous_start_v: Variant = previous_subject.get("start", null)
		var clicked_end_v: Variant = subject.get("end", subject.get("start", null))
		if previous_start_v is Dictionary and clicked_end_v is Dictionary:
			subject = {
				"type": "lane",
				"start": (previous_start_v as Dictionary).duplicate(true),
				"end": (clicked_end_v as Dictionary).duplicate(true),
			}
	_ping_preview = _simulation.preview_ping(ping_id, subject)
	_publish_snapshot()


func _confirm_ping(ping_id: String, subject_v: Variant) -> void:
	if not _queued_ping_confirmation.is_empty():
		return
	var subject: Dictionary = subject_v if subject_v is Dictionary else {}
	if _ping_preview.is_empty() or str(_ping_preview.get("id", "")) != ping_id:
		_ping_preview = _simulation.preview_ping(ping_id, subject)
	if not bool(_ping_preview.get("valid", false)):
		_publish_snapshot()
		return
	# UI input can arrive while the previous turn result is animating. Preserve the exact
	# preview as an acknowledgement, then rebuild and commit it at the next timer boundary.
	_queued_ping_confirmation = _ping_preview.duplicate(true)
	_publish_snapshot()


func _on_playback_timer_timeout() -> void:
	if _phase != "combat":
		_playback_timer.stop()
		return
	var state: Dictionary = _simulation.get_state()
	if bool(state.get("combat_over", false)):
		_playback_timer.stop()
		return
	_commit_queued_ping()
	_resolve_one_turn()


func _commit_queued_ping() -> void:
	if _queued_ping_confirmation.is_empty():
		return
	var attempted: Dictionary = _queued_ping_confirmation.duplicate(true)
	_queued_ping_confirmation = {}
	var ping_id: String = str(attempted.get("id", ""))
	var subject_v: Variant = attempted.get("subject", {})
	var subject: Dictionary = subject_v if subject_v is Dictionary else {}
	var revalidated: Dictionary = _simulation.preview_ping(ping_id, subject)
	if _simulation.confirm_ping(revalidated):
		_ping_preview = {}
	else:
		_ping_preview = revalidated


func _refresh_ping_preview() -> void:
	if _ping_preview.is_empty() or not _queued_ping_confirmation.is_empty():
		return
	var ping_id: String = str(_ping_preview.get("id", ""))
	var subject_v: Variant = _ping_preview.get("subject", {})
	var subject: Dictionary = subject_v if subject_v is Dictionary else {}
	_ping_preview = _simulation.preview_ping(ping_id, subject)


func _update_playback_interval(last_turn_v: Variant = {}) -> void:
	var multiplier: float = 1.0
	for option: Dictionary in PLAYBACK_SPEED_OPTIONS:
		if str(option.get("id", "")) == _playback_speed_id:
			multiplier = float(option.get("multiplier", 1.0))
			break
	var duration: float = BASE_PLAYBACK_SECONDS
	if last_turn_v is Dictionary and not (last_turn_v as Dictionary).is_empty():
		var last_turn: Dictionary = last_turn_v as Dictionary
		duration = 0.35
		duration += (last_turn.get("path", []) as Array).size() * 0.18
		if not (last_turn.get("ping_response", {}) as Dictionary).is_empty():
			duration += 0.50
		if str(last_turn.get("action_type", "")) == "attack":
			duration += 0.52
			if int(last_turn.get("damage", 0)) > 0:
				duration += 0.45
		for beat_v: Variant in last_turn.get("follow_up", []):
			if beat_v is Dictionary:
				duration += 0.52 if str((beat_v as Dictionary).get("type", "")) == "attack" else 0.18
		for hazard_v: Variant in last_turn.get("hazard_events", []):
			if hazard_v is Dictionary and not _same_position(
					(hazard_v as Dictionary).get("from_pos", {}), (hazard_v as Dictionary).get("to_pos", {})):
				duration += 0.18
	_playback_timer.wait_time = duration / maxf(0.1, multiplier)


func _same_position(a_v: Variant, b_v: Variant) -> bool:
	if not a_v is Dictionary or not b_v is Dictionary:
		return false
	var a: Dictionary = a_v as Dictionary
	var b: Dictionary = b_v as Dictionary
	return int(a.get("col", -999)) == int(b.get("col", -998)) \
		and int(a.get("row", -999)) == int(b.get("row", -998))


func _on_simulation_state_changed() -> void:
	_sync_phase_from_simulation()
	_publish_snapshot()


func _sync_phase_from_simulation() -> void:
	var sim_phase: String = str(_simulation.get_state().get("phase", ""))
	if sim_phase == "review":
		_phase = "review"
		_playback_timer.stop()


func _publish_snapshot() -> void:
	if not is_instance_valid(_ui) or _simulation == null:
		return
	_ui.set_snapshot(_build_snapshot())


func _build_snapshot() -> Dictionary:
	var data: Dictionary = _simulation.build_snapshot_data()
	data["phase"] = _phase
	data["seed"] = _seed
	data["mode"] = _mode
	data["playback_speed_id"] = _playback_speed_id
	data["playback_speed_options"] = PLAYBACK_SPEED_OPTIONS.duplicate(true)
	data["playback_interval_seconds"] = _playback_timer.wait_time
	data["ping_preview"] = _ping_preview.duplicate(true)
	data["queued_ping_confirmation"] = _queued_ping_confirmation.duplicate(true)
	data["deployment_assignments"] = _deployment_assignments.duplicate(true)
	data["selected_deployment_actor_id"] = _selected_deployment_actor_id
	data["party_roster"] = _build_party_roster(data.get("actors", []))
	# The simulation retains response counts by outcome for instrumentation. The current
	# review UI expects a scalar `responses`, so adapt only the UI projection and preserve
	# the detailed breakdown under an explicit key.
	var metrics: Dictionary = data.get("metrics", {})
	if metrics.get("responses", null) is Dictionary:
		metrics["response_outcomes"] = (metrics["responses"] as Dictionary).duplicate(true)
		metrics["responses"] = int(metrics.get("response_count", 0))
	data["metrics"] = metrics
	return {
		"type": "prototype.%s" % _phase,
		"meta": {"t": int(_simulation.get_state().get("tick", 0)), "seed": _seed},
		"data": data,
		"actions": _build_actions(),
	}


func _build_actions() -> Dictionary:
	var actions: Dictionary = {}
	match _phase:
		"briefing":
			actions = {
				"cta.generate": _action("prototype.seed.set", "Generate"),
				"cta.reroll": _action("prototype.board.reroll", "New Seed"),
				"cta.prepare": _action("prototype.phase.prepare", "Prepare"),
				"mode.recover": _action("prototype.mode.select", "RECOVER"),
				"mode.protect": _action("prototype.mode.select", "PROTECT"),
			}
		"preparation":
			actions = {"cta.start": _action("prototype.combat.start", "Start Combat")}
			for directive_id: String in PrototypeSimulation.DIRECTIVE_IDS:
				actions["directive.%s" % directive_id] = _action("prototype.directive.select", "Select")
		"combat":
			actions = {
				"ping.select": _action("prototype.ping.select", "Select Ping"),
				"ping.preview": _action("prototype.ping.preview", "Preview"),
				"ping.confirm": _action("prototype.ping.confirm", "Confirm"),
				"ping.cancel": _action("prototype.ping.cancel", "Cancel"),
				"playback.speed": _action("prototype.playback.speed", "Playback Speed"),
			}
		"review":
			actions = {
				"cta.restart_same": _action("prototype.restart.same_seed", "Restart Same Seed"),
				"cta.new_seed": _action("prototype.restart.new_seed", "New Seed"),
			}
	for slot_v: Variant in actions.keys():
		var slot: String = str(slot_v)
		var action: Dictionary = actions[slot]
		action["slot"] = slot
	return actions


func _action(type: String, label: String) -> Dictionary:
	return {"type": type, "slot": "", "label": label, "disabled": false, "payload": {}}


func _build_party_roster(actors_v: Variant) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	if not actors_v is Array:
		return roster
	for actor_v: Variant in actors_v:
		if not actor_v is Dictionary:
			continue
		var actor: Dictionary = actor_v as Dictionary
		if str(actor.get("faction", "")) != "echo":
			continue
		var actor_id: String = str(actor.get("id", ""))
		roster.append({
			"id": actor_id, "name": actor.get("name", "Echo"),
			"calling_origin": actor.get("calling_origin", ""), "standing": actor.get("standing", 0),
			"expression_band": actor.get("expression_band", ""), "fear": actor.get("fear", 0),
			"morale": actor.get("morale", 0), "tendency": actor.get("tendency", ""),
			"assigned_slot": int(_deployment_assignments.get(actor_id, -1)),
			"guidance_state": actor.get("guidance_state", "unaffected"),
			"last_response": actor.get("last_response", {}).duplicate(true),
		})
	return roster


func _next_seed(seed: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("prototype.keeper.next_seed.%d" % seed)
	return rng.randi_range(1, 2147483646)
