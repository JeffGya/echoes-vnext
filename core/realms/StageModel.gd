class_name StageModel

extends RefCounted

# REALM-002: Pure data factory for stage model dicts.
# A stage is a container of sequential objectives with a derived summary type.
# No logic, no imports, no side effects.
#
# Stage type is derived by RealmGenerator at generation time from pre-boss objectives:
#   - Any pre-boss objective is "shrine" → stage type = "purification"
#   - All pre-boss objectives are "combat"  → stage type = "combat"

const REQUIRED_FIELDS: Array = ["index", "type", "seed", "objectives"]

# Stage summary type constants (derived at generation — never set manually)
const TYPE_COMBAT       := "combat"
const TYPE_PURIFICATION := "purification"
const VALID_TYPES: Array = [TYPE_COMBAT, TYPE_PURIFICATION]

# Stage-level summary descriptions for UI display.
# Extend when new stage configurations emerge post-MVP.
const TYPE_DESCRIPTIONS: Dictionary = {
	"combat":       "A series of battles awaits.",
	"purification": "Corruption must be cleansed along the way.",
}


# Build a new StageModel dict.
# objectives: pre-built Array of ObjectiveModel dicts (created by RealmGenerator).
static func make(index: int, type: String, seed: int, objectives: Array) -> Dictionary:
	return {
		"index":      index,
		"type":       type,
		"seed":       seed,
		"objectives": objectives,
	}


# Returns true if all required fields are present.
static func validate(model: Dictionary) -> bool:
	for key in REQUIRED_FIELDS:
		if not model.has(key):
			return false
	return true
