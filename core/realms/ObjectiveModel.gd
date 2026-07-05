class_name ObjectiveModel

extends RefCounted

# REALM-002: Pure data factory for objective model dicts.
# An objective is the atomic unit within a stage — typed, seeded, sequential.
# No logic, no imports, no side effects.
#
# Extension point: objective_params (not in REQUIRED_FIELDS) carries type-specific config.
# Post-MVP types (escort, defend, roaming intel) populate params without schema changes.
#
# V2-STAGE-002: Expanded taxonomy + completion tracking.
# completed: bool — set true when the linked situation is resolved on victory.
# required:  bool — required objectives block stage advance; optional ones do not.
# params shapes per type (documented for V2-STAGE-004 runtime wiring):
#   recover: { "target_id": String, "target_description": String }
#   protect: { "entity_id": String, "duration_turns": int }
#   endure:  { "duration_turns": int, "pressure_source": String }
#   pursue:  { "target_id": String, "window_turns": int }

const REQUIRED_FIELDS: Array = ["index", "type", "seed"]

const TYPE_COMBAT  := "combat"
const TYPE_SHRINE  := "shrine"
const TYPE_BOSS    := "boss"    # Stub — no encounter logic yet. REALM-002+.
# V2-STAGE-002: expanded taxonomy
const TYPE_RECOVER := "recover"
const TYPE_PROTECT := "protect"
const TYPE_ENDURE  := "endure"
const TYPE_PURSUE  := "pursue"
const TYPE_GUIDE_SPIRIT := "guide_spirit"

const VALID_TYPES: Array = [
	TYPE_COMBAT, TYPE_SHRINE, TYPE_BOSS,
	TYPE_RECOVER, TYPE_PROTECT, TYPE_ENDURE, TYPE_PURSUE, TYPE_GUIDE_SPIRIT,
]

# Short player-facing descriptions keyed by type.
# Extend this dict when adding new objective types — no other code changes required.
const TYPE_DESCRIPTIONS: Dictionary = {
	"combat":  "Defeat all enemies to proceed.",
	"shrine":  "Purify the corrupted shrine.",
	"boss":    "A powerful foe guards this stage.",
	"recover": "Find and retrieve what was taken.",
	"protect": "Keep the presence here safe.",
	"endure":  "Hold your ground through the pressure.",
	"pursue":  "Track and intercept before the window closes.",
	"guide_spirit": "Find the spirit and see it to safety.",
}


# Build a new ObjectiveModel dict.
# params:    optional type-specific config (empty by default).
#   Future types populate this — callers always use .get("params", {}) to read it.
# completed: false by default; set true when the linked situation is resolved on victory.
# required:  true by default; false marks an optional (bonus) objective.
static func make(
	index: int, type: String, seed: int,
	params: Dictionary = {},
	completed: bool = false,
	required: bool = true
) -> Dictionary:
	return {
		"index":     index,
		"type":      type,
		"seed":      seed,
		"params":    params,
		"completed": completed,
		"required":  required,
	}


# Returns true if all required fields are present.
static func validate(model: Dictionary) -> bool:
	for key in REQUIRED_FIELDS:
		if not model.has(key):
			return false
	return true
