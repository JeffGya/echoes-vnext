class_name ObjectiveModel

extends RefCounted

# REALM-002: Pure data factory for objective model dicts.
# An objective is the atomic unit within a stage — typed, seeded, sequential.
# No logic, no imports, no side effects.
#
# Extension point: objective_params (not in REQUIRED_FIELDS) carries type-specific config.
# Post-MVP types (escort, defend, roaming intel) populate params without schema changes.

const REQUIRED_FIELDS: Array = ["index", "type", "seed"]

const TYPE_COMBAT := "combat"
const TYPE_SHRINE := "shrine"
const TYPE_BOSS   := "boss"   # Stub — no encounter logic yet. REALM-002+.
const VALID_TYPES: Array = [TYPE_COMBAT, TYPE_SHRINE, TYPE_BOSS]

# Short player-facing descriptions keyed by type.
# Extend this dict when adding new objective types post-MVP — no other code changes required.
const TYPE_DESCRIPTIONS: Dictionary = {
	"combat": "Defeat all enemies to proceed.",
	"shrine": "Purify the corrupted shrine.",
	"boss":   "A powerful foe guards this stage.",
}


# Build a new ObjectiveModel dict.
# params: optional type-specific config (empty by default).
#   Future types populate this — callers always use .get("params", {}) to read it.
static func make(index: int, type: String, seed: int, params: Dictionary = {}) -> Dictionary:
	return {
		"index":  index,
		"type":   type,
		"seed":   seed,
		"params": params,
	}


# Returns true if all required fields are present.
static func validate(model: Dictionary) -> bool:
	for key in REQUIRED_FIELDS:
		if not model.has(key):
			return false
	return true
