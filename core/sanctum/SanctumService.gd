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

## Static, pure-read twin of get_party_actors() above.
## V2-INFRA-003 Phase 5 Slice B — added so FlowRuntime's scout-return producer can build its
## party preview without SanctumService.new(save_data), whose SanctumState constructor can
## write to save_data via _ensure_sanctum_dict_exists() (AGENTS.md: "Constructing a service
## can mutate. Prefer static reads.").
##
## Reproduces get_party_actors() line for line, INCLUDING ITERATION ORDER: it walks
## active_party_ids and looks each one up in the roster, so results are in PARTY order.
## Do NOT substitute get_active_party_echoes() below — that walks the ROSTER (different
## order) and returns raw roster dicts rather than EchoActor.from_echo() views. That
## substitution is exactly the lookalike-API mistake AGENTS.md #19 warns about.
## Order-equality with the instance method is pinned by
## tests/PartyTests.gd party/get_party_actors_static_matches_instance.
static func get_party_actors_static(save_data: Dictionary) -> Array:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	var result: Array = []
	for eid in party_ids:
		var found := false
		for echo in roster:
			if echo.get("id", "") == eid:
				result.append(EchoActor.from_echo(echo))
				found = true
				break
		if not found:
			push_warning("SanctumService.get_party_actors_static: id '%s' not found in roster" % eid)
	return result


## Returns an Array of Actor dicts for every Echo in the roster.
## Each dict is a deep-copy view — mutating it does not affect save data.
## Returns [] when the roster is empty.
func get_roster_actors() -> Array:
	var result: Array = []
	for echo in get_roster():
		result.append(EchoActor.from_echo(echo))
	return result


## Returns the save_data roster entry for the given echo_id, or {} if not found.
## Static + explicit save_data param (V2-INFRA-003 Phase 4 Slice 1b — moved out
## of FlowRuntime/WeaveController, which had duplicated this) rather than an
## instance method: it's a pure read, unlike the façade above, which would
## mutate save_data via SanctumState._ensure_sanctum_dict_exists() on
## construction if "sanctum" were missing.
static func find_roster_echo(save_data: Dictionary, echo_id: String) -> Dictionary:
	if echo_id.is_empty():
		return {}
	var sanc_v: Variant = save_data.get("sanctum", {})
	if not sanc_v is Dictionary:
		return {}
	var roster_v: Variant = (sanc_v as Dictionary).get("roster", [])
	if not roster_v is Array:
		return {}
	for entry_v in roster_v:
		if entry_v is Dictionary and str(entry_v.get("id", "")) == echo_id:
			return entry_v as Dictionary
	return {}


## Returns the raw roster entries (echo dicts, not EchoActor views) whose "id" appears in
## sanctum.active_party_ids. Iterates the roster and filters by membership, so results are
## in ROSTER order (not active_party_ids order — matches the FlowRuntime helper this replaces).
## Static + explicit save_data param (V2-INFRA-003 — moved out of FlowRuntime, which had this
## as _get_active_party_echoes()) rather than an instance method: it's a pure read, unlike the
## façade above, which would mutate save_data via SanctumState._ensure_sanctum_dict_exists() on
## construction if "sanctum" were missing.
static func get_active_party_echoes(save_data: Dictionary) -> Array:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	var result: Array = []
	for echo_v in roster:
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}
		if str(echo.get("id", "")) in party_ids:
			result.append(echo)
	return result


## PROG-001: one-time repair pass for echo fields added after draw-order v1. Moved from
## FlowRuntime._repair_echo_schema (V2-INFRA-003 Phase 4 Slice 8) — its only call site is
## flow.continue, which is not one of SanctumController's dispatched actions, so this stays a
## plain static helper (static + explicit save_data param, matching find_roster_echo's shape)
## rather than living on a controller. Patches roster echoes missing class_origin / level.
## Returns true when any echo was patched, so the caller can decide whether to request a save
## (this function never calls SaveService or FlowContext.request_save() itself — pure read +
## in-place mutation of the passed-in save_data, plus logging).
static func repair_echo_schema(save_data: Dictionary, logger: StructuredLogger, t: int) -> bool:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var patched_count := 0
	for e_v in roster:
		if e_v is Dictionary:
			if EchoFactory.repair_echo_fields(e_v):
				patched_count += 1

	if patched_count > 0:
		logger.info(t, "sanctum.schema.repair", "Repaired old echo fields", {
			"patched": patched_count,
			"roster_size": roster.size()
		})
		return true
	return false