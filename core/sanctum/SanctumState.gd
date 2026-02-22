# res://core/sanctum/SanctumState.gd
# MVP: Save-backed, JSON-safe hub state wrapper.
# No UI refs, no RNG, no OS time.

class_name SanctumState
extends RefCounted

const KEY_SANCTUM := "sanctum"
const KEY_ROSTER := "roster"
const KEY_ACTIVE_PARTY_IDS := "active_party_ids"

var _save: Dictionary

func _init(save_ref: Dictionary) -> void:
	_save = save_ref
	_ensure_sanctum_dict_exists()

func get_roster() -> Array:
	var s: Dictionary = _save[KEY_SANCTUM]
	var v = s.get(KEY_ROSTER, [])
	return v if v is Array else []

func set_roster(roster: Array) -> void:
	_ensure_sanctum_dict_exists()
	var s: Dictionary = _save[KEY_SANCTUM]
	s[KEY_ROSTER] = roster

func get_active_party_ids() -> Array:
	var s: Dictionary = _save[KEY_SANCTUM]
	var v = s.get(KEY_ACTIVE_PARTY_IDS, [])
	return v if v is Array else []

func set_active_party_ids(ids: Array) -> void:
	_ensure_sanctum_dict_exists()
	var s: Dictionary = _save[KEY_SANCTUM]
	s[KEY_ACTIVE_PARTY_IDS] = ids

func _ensure_sanctum_dict_exists() -> void:
	if not _save.has(KEY_SANCTUM) or typeof(_save[KEY_SANCTUM]) != TYPE_DICTIONARY:
		_save[KEY_SANCTUM] = {
			KEY_ROSTER: [],
			KEY_ACTIVE_PARTY_IDS: []
		}
		return

	var s: Dictionary = _save[KEY_SANCTUM]
	if not s.has(KEY_ROSTER) or not (s[KEY_ROSTER] is Array):
		s[KEY_ROSTER] = []
	if not s.has(KEY_ACTIVE_PARTY_IDS) or not (s[KEY_ACTIVE_PARTY_IDS] is Array):
		s[KEY_ACTIVE_PARTY_IDS] = []