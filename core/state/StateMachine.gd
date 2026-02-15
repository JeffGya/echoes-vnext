class_name StateMachine

extends RefCounted

var _machine_id: String
var _states: Dictionary = {}
var _current_state: State = null
var _current_state_id: String = ""

func _init(machine_id: String) -> void:
	_machine_id = machine_id
	
func register_state(state: State) -> void:
	_states[state.get_id()] = state
	
func set_initial(state_id: String, ctx: RefCounted, logger: StructuredLogger, t: int) -> void:
	if _current_state != null:
		# already initialized - deterministic ignore
		return
	
	if not _states.has(state_id):
		logger.debug(
			t,
			"state.transition.invalid",
			"%s invalid → %s" % [_machine_id, state_id],
			{
				"machine_id": _machine_id,
				"to_state": state_id,
				"reason": "initial_missing"
			}
		)
		return
	
	_current_state = _states[state_id]
	_current_state_id = state_id
	
	_current_state.enter(ctx, t)

	logger.info(
		t,
		"state.transition",
		"%s ∅ → %s" % [_machine_id, state_id],
		{
			"machine_id": _machine_id,
			"from_state": "",
			"to_state": state_id,
			"reason": "initial"
		}
	)


func transition(to_state_id: String, ctx: RefCounted, logger: StructuredLogger, t: int, reason: String = "") -> bool:
	
	# Missing state
	if not _states.has(to_state_id):
		logger.debug(
			t,
			"state.transition.invalid",
			"%s invalid → %s" % [_machine_id, to_state_id],
			{
				"machine_id": _machine_id,
				"to_state": to_state_id,
				"reason": reason
			}
		)
		return false
	
	# No-op
	if to_state_id == _current_state_id:
		logger.debug(
			t,
			"state.transition.noop",
			"%s noop %s" % [_machine_id, to_state_id],
			{
				"machine_id": _machine_id,
				"state_id": to_state_id,
				"reason": reason
			}
		)
		return false
		
	var from_id := _current_state_id
	
	if _current_state != null:
		_current_state.exit(ctx, t)
		
	_current_state = _states[to_state_id]
	_current_state_id = to_state_id
	
	_current_state.enter(ctx, t)
	
	logger.info(
		t,
		"state.transition",
		"%s %s → %s" % [_machine_id, from_id, to_state_id],
		{
			"machine_id": _machine_id,
			"from_state": from_id,
			"to_state": to_state_id,
			"reason": reason
		}
	)

	return true
