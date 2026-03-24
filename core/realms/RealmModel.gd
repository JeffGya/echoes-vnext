class_name RealmModel

extends RefCounted

# REALM-001: Pure data factory for realm model dicts.
# No logic, no imports, no side effects.
# All realm models are plain Dictionaries — consistent with vNext's dict-centric data patterns.

const REQUIRED_FIELDS: Array = [
	"id", "name", "virtue", "description", "seed", "stage_count",
	"current_stage_index", "is_completed", "status", "run_index", "run_count"
]

# Status constants
const STATUS_NOT_STARTED := "not_started"
const STATUS_ACTIVE      := "active"
const STATUS_COMPLETED   := "completed"


# Build a new RealmModel dict.
# status is always "active" at creation — the player just selected this realm.
# run_count: 0 = first ever run; 1+ = re-run after completion (drives seed derivation).
static func make(
	id: String,
	name: String,
	virtue: String,
	description: String,
	seed: int,
	stage_count: int,
	run_index: int,
	run_count: int = 0
) -> Dictionary:
	return {
		"id":                   id,
		"name":                 name,
		"virtue":               virtue,
		"description":          description,
		"seed":                 seed,
		"stage_count":          stage_count,
		"current_stage_index":  0,
		"is_completed":         false,
		"status":               STATUS_ACTIVE,
		"run_index":            run_index,
		"run_count":            run_count,
	}


# Returns true if all required fields are present.
static func validate(model: Dictionary) -> bool:
	for key in REQUIRED_FIELDS:
		if not model.has(key):
			return false
	return true
