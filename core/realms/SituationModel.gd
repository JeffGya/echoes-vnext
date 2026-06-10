class_name SituationModel

extends RefCounted

# V2-STAGE-001: Pure data factory for situation model dicts.
# A situation is a content node scattered across the stage exploration map.
# Some situations are main objectives (is_objective: true) — the party must
# find and resolve all objectives to complete the stage.
#
# Hidden by default: revealed = false means the UI shows only a '?' marker.
# The reveal check (stub in V2-STAGE-001) happens when the party arrives.
#
# intel_clues is always [] in V2-STAGE-001 — the slot exists for V2-INTEL-001
# to read from and write to without requiring a schema change.
#
# Do NOT reorder type pool entries — determinism rule.

const REQUIRED_FIELDS: Array = [
	"id", "type", "pos", "seed", "revealed",
	"is_objective", "resolved", "intel_clues",
	"objective_index",  # V2-STAGE-002: -1 for non-objective situations
	"role",             # contact role for NPC situations; "" for non-NPC types
]

# Situation type constants
const TYPE_COMBAT := "combat"
const TYPE_NPC    := "npc"
const TYPE_LOOT   := "loot"
const TYPE_MONEY  := "money"

const VALID_TYPES: Array = [TYPE_COMBAT, TYPE_NPC, TYPE_LOOT, TYPE_MONEY]

# Weighted type pool for random situation generation.
# Do NOT reorder — determinism guarantee. Append new types at end only.
const SITUATION_TYPE_POOL: Array = [
	TYPE_COMBAT,  # weight 3
	TYPE_COMBAT,
	TYPE_COMBAT,
	TYPE_NPC,     # weight 2
	TYPE_NPC,
	TYPE_LOOT,    # weight 2
	TYPE_LOOT,
	TYPE_MONEY,   # weight 1
]

# Short player-facing descriptions (revealed situations only).
const TYPE_DESCRIPTIONS: Dictionary = {
	"combat": "Signs of conflict ahead.",
	"npc":    "A presence lingers here.",
	"loot":   "Something left behind.",
	"money":  "A trace of offering.",
}


# Build a new SituationModel dict.
# col, row: grid position on the exploration map.
# seed: derived from CampaignSeed — deterministic per situation.
# is_objective: true if this situation is a main stage objective.
static func make(
	id: String,
	sit_type: String,
	col: int,
	row: int,
	seed: int,
	is_objective: bool,
	objective_index: int = -1  # V2-STAGE-002: index into stage.objectives[]; -1 if not an objective
) -> Dictionary:
	return {
		"id":              id,
		"type":            sit_type,
		"pos":             { "col": col, "row": row },
		"seed":            seed,
		"revealed":        false,
		"is_objective":    is_objective,
		"resolved":        false,
		"intel_clues":     [],  # V2-INTEL-001 extensibility slot
		"objective_index": objective_index,
		"role":            "",
	}


# Returns true if all required fields are present.
static func validate(model: Dictionary) -> bool:
	for key in REQUIRED_FIELDS:
		if not model.has(key):
			return false
	return true
