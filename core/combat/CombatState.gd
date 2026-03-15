# res://core/combat/CombatState.gd
# COMBAT-001: Centralized combat state container.
# CombatState is a plain Dictionary — created via the static factory,
# stored on EncounterContext.combat_state, read by FlowEncounterState.build_snapshot().
#
# Shape: { "actors": Array, "objective": String, "round_counter": int }

class_name CombatState

extends RefCounted

const REQUIRED_FIELDS := ["actors", "objective", "round_counter"]

## Returns a new CombatState dictionary seeded from the placed actors array
## and the encounter's resolution mode (objective).
## actors is deep-copied so mutations to the source do not propagate.
static func create(actors: Array, objective: String) -> Dictionary:
	return {
		"actors":        actors.duplicate(true),
		"objective":     objective,
		"round_counter": 0,
	}

## Returns true if all required fields are present in the dictionary.
static func validate(state: Dictionary) -> bool:
	for f in REQUIRED_FIELDS:
		if not state.has(f):
			return false
	return true
