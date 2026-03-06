# res://core/sanctum/SanctumService.gd
# Thin façade over SanctumState for future-proofing.

class_name SanctumService
extends RefCounted

var _state: SanctumState

func _init(save_ref: Dictionary) -> void:
	_state = SanctumState.new(save_ref)

func get_roster() -> Array:
	return _state.get_roster()

func set_roster(roster: Array) -> void:
	_state.set_roster(roster)

func get_active_party_ids() -> Array:
	return _state.get_active_party_ids()

func set_active_party_ids(ids: Array) -> void:
	_state.set_active_party_ids(ids)

## Returns an Array of Actor dicts for the current active party.
## Each dict is a deep-copy view — mutating it does not affect save data.
## Skips any ID not found in the roster (logs a warning; does not crash).
## Returns [] when party is empty or roster is empty.
func get_party_actors() -> Array:
	var party_ids := get_active_party_ids()
	var roster    := get_roster()
	var result: Array = []
	for eid in party_ids:
		var found := false
		for echo in roster:
			if echo.get("id", "") == eid:
				result.append(EchoActor.from_echo(echo))
				found = true
				break
		if not found:
			push_warning("SanctumService.get_party_actors: id '%s' not found in roster" % eid)
	return result

## Returns an Array of Actor dicts for every Echo in the roster.
## Each dict is a deep-copy view — mutating it does not affect save data.
## Returns [] when the roster is empty.
func get_roster_actors() -> Array:
	var result: Array = []
	for echo in get_roster():
		result.append(EchoActor.from_echo(echo))
	return result