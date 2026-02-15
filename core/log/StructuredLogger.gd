# StructuredLogger
# - Stores deterministic, structured LogEvent dictionaries.
# - IMPORTANT: This logger does NOT own time.
#   `t` must be injected by the caller (Approach 1: AppRoot sim_tick for now).
# - When Flow/Encounter state machines exist, they become the authoritative sim_tick owner
#   and AppRoot ticking must be removed (see CONVENTIONS.md "Logging").

class_name StructuredLogger

extends RefCounted

var _logs: Array[Dictionary] = []
const LEVEL_OFF := "off"
const LEVEL_INFO := "info"
const LEVEL_DEBUG := "debug"

var _level: String = LEVEL_INFO

func clear() -> void:
	_logs.clear()
	
	
func set_level(level: String) -> void:
	# Accept only known levels (fails closed to INFO)
	if level != LEVEL_OFF and level != LEVEL_INFO and level != LEVEL_DEBUG:
		_level = LEVEL_INFO
		return
	_level = level

func get_level() -> String:
	return _level

func _should_log(sev: String) -> bool:
	if _level == LEVEL_OFF:
		return false
	if _level == LEVEL_INFO:
		return sev == LEVEL_INFO
	# LEVEL_DEBUG logs both
	return true

func info(t: int, type: String, msg: String, data: Dictionary = {}) -> void:
	log_event(t, LEVEL_INFO, type, msg, data)

func debug(t: int, type: String, msg: String, data: Dictionary = {}) -> void:
	log_event(t, LEVEL_DEBUG, type, msg, data)

func get_logs() -> Array[Dictionary]:
	# Return a shallow copy so callers don't accidentally mutate our internal array.
	# Note: individual dictionaries are stored as deep-copied payloads already.
	return _logs.duplicate(false)
	
func log_event(t: int, sev: String, type: String, msg: String, data: Dictionary = {}) -> void:	
	# Enforce JSON-safe dictionary shape (LogEvent contract in CONVENTIONS.md).
	if not _should_log(sev):
		return
	# We keep enforcement lightweight: we ensure keys exist and deep-copy payload.
	var event: Dictionary = {
		"t": t,
		"sev": sev,
		"type": type,
		"msg": msg,
		"data": data.duplicate(true) # deep copy to prevent mutations
	}
	_logs.append(event)
	
# Convenient helpers
func log_state_transition(t: int, from_state: String, to_state: String, reason: String, extra: Dictionary = {}) -> void:
	var payload :={
		"from": from_state,
		"to": to_state,
		"reason": reason
	}
	# Merge extra fields without mutating input
	for k in extra.keys():
		payload[k] = extra[k]
	info(t, "state.transition", "%s → %s" % [from_state, to_state], payload)

func log_combat_event(t: int, event_type: String, payload: Dictionary, msg: String = "") -> void:
	var safe_msg := msg
	if safe_msg == "":
		safe_msg = "combat.%s" % event_type
	debug(t, "combat.%s" % event_type, safe_msg, payload)
