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