class_name StageExploreModel

extends RefCounted

# V2-STAGE-001: Pure data factory for the exploration map dict.
# Each stage carries one explore_map (stored as stages[i]["explore_map"]).
#
# Map dimensions are deterministically random and asymmetric:
#   - Minimum MIN_WIDTH × MIN_HEIGHT tiles
#   - Derived from per-realm config in realms.json (map_width_min/max, map_height_min/max)
#   - Earlier realms get smaller ranges; later realms get larger
#   - Stage index bumps the range slightly so stage 2 is bigger than stage 1
#
# locked: false until the party first enters the stage.
# Once locked, the same situation layout is always used for that run.
# A new run (realm replay) regenerates the map at RealmService.get_or_create.
#
# party_state transitions:
#   "exploring" → "escaped" (return_home success) or "complete" (all objectives found)

const REQUIRED_FIELDS: Array = [
	"width", "height", "party_pos", "situations",
	"locked", "party_state", "turn_count",
	"objectives_found", "objectives_total", "last_situation_id"
]

# Party state constants
const STATE_EXPLORING := "exploring"
const STATE_ESCAPED   := "escaped"
const STATE_COMPLETE  := "complete"

# Minimum map dimensions — never go below these
const MIN_WIDTH:  int = 30
const MIN_HEIGHT: int = 30


# Build a new StageExploreModel dict.
# width, height: deterministic random dimensions (caller derives from config + seed).
# situations: pre-built Array of SituationModel dicts (from RealmGenerator).
# objectives_total: count of is_objective=true situations.
static func make(width: int, height: int, situations: Array) -> Dictionary:
	var obj_total := 0
	for sit_v in situations:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if sit.get("is_objective", false):
			obj_total += 1

	return {
		"width":            max(width,  MIN_WIDTH),
		"height":           max(height, MIN_HEIGHT),
		"party_pos":        { "col": 0, "row": max(height, MIN_HEIGHT) / 2 },
		"situations":       situations,
		"locked":           false,
		"party_state":      STATE_EXPLORING,
		"turn_count":       0,
		"objectives_found": 0,
		"objectives_total": obj_total,
		"last_situation_id": "",
	}


# Build a safe empty default — used by SaveService repair for saves that pre-date this model.
static func make_default() -> Dictionary:
	return {
		"width":            MIN_WIDTH,
		"height":           MIN_HEIGHT,
		"party_pos":        { "col": 0, "row": MIN_HEIGHT / 2 },
		"situations":       [],
		"locked":           false,
		"party_state":      STATE_EXPLORING,
		"turn_count":       0,
		"objectives_found": 0,
		"objectives_total": 0,
		"last_situation_id": "",
	}


# Returns true if all required fields are present.
static func validate(model: Dictionary) -> bool:
	for key in REQUIRED_FIELDS:
		if not model.has(key):
			return false
	return true
