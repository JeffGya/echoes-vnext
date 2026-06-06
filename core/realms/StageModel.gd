class_name StageModel

extends RefCounted

# REALM-002: Pure data factory for stage model dicts.
# A stage is a container of sequential objectives with a derived summary type.
# No logic, no imports, no side effects.
#
# Stage type is derived by RealmGenerator at generation time from pre-boss objectives:
#   - Any pre-boss objective is "shrine" → stage type = "purification"
#   - All pre-boss objectives are "combat"  → stage type = "combat"

const REQUIRED_FIELDS: Array = ["index", "type", "seed", "objectives", "explore_map"]

# Stage summary type constants (derived at generation — never set manually).
# V2-STAGE-002: expanded to cover new objective compositions.
# NOTE: stage.type is a DISPLAY-ONLY summary. FlowEncounterState reads the specific
# objective type (via objective_index), not stage.type, to determine resolution_mode.
const TYPE_COMBAT       := "combat"
const TYPE_PURIFICATION := "purification"
const TYPE_RECOVERY     := "recovery"    # V2-STAGE-002: stages primarily focused on recover/retrieve
const TYPE_PROTECTION   := "protection"  # V2-STAGE-002: stages primarily focused on protect/escort
const VALID_TYPES: Array = [TYPE_COMBAT, TYPE_PURIFICATION, TYPE_RECOVERY, TYPE_PROTECTION]

# Stage-level summary descriptions for UI display.
# Extend when new stage configurations emerge post-MVP.
const TYPE_DESCRIPTIONS: Dictionary = {
	"combat":       "A series of battles awaits.",
	"purification": "Corruption must be cleansed along the way.",
	"recovery":     "Something must be retrieved from this place.",
	"protection":   "A presence here must not be lost.",
}


# Build a new StageModel dict.
# objectives:   pre-built Array of ObjectiveModel dicts (created by RealmGenerator).
# explore_map:  V2-STAGE-001 StageExploreModel dict (created by RealmGenerator). Default {} for legacy.
static func make(index: int, type: String, seed: int, objectives: Array, explore_map: Dictionary = {}) -> Dictionary:
	return {
		"index":       index,
		"type":        type,
		"seed":        seed,
		"objectives":  objectives,
		"explore_map": explore_map,
	}


# Returns true if all required fields are present.
static func validate(model: Dictionary) -> bool:
	for key in REQUIRED_FIELDS:
		if not model.has(key):
			return false
	return true
