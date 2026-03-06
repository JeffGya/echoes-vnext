# res://core/actors/ActorSchema.gd
# Unified Actor data contract for Echoes vNext.
#
# Actors are the shared base for any entity that participates in combat or
# fills a party slot: Echoes now; enemies, NPCs, structures in future stories.
#
# Rules:
# - No RNG, no OS time, no side effects.
# - Actor dicts are READ-ONLY views of save data — mutating one must not
#   mutate the underlying save (callers must deep-copy; see EchoActor.from_echo).
# - validate() checks presence and non-null only, not value ranges.
#   Enemy/NPC actors may use zero/empty values for Echo-specific fields.
#
# GRID-STUB: position { "x": int, "y": int } will be added to the contract
# when core/grid/ lands (GRID stories). Not a required field in MVP.
#
# ACTOR-SM-STUB: ActorStateMachine (per-round behavior selection) will be
# scaffolded in a future story once core/combat/ and core/grid/ exist.

class_name ActorSchema
extends RefCounted

## Canonical list of required field names for any Actor dict.
## All fields must be present and non-null. Value ranges are not enforced here.
const REQUIRED_FIELDS: Array = [
	"id",
	"name",
	"rarity",
	"rank",
	"calling_origin",
	"stats",
	"traits",
	"xp_total",
	"level",
	"actor_type",
]

## Returns false if actor is missing any required field or has a null value.
static func validate(actor: Dictionary) -> bool:
	for field in REQUIRED_FIELDS:
		if not actor.has(field):
			return false
		if actor[field] == null:
			return false
	return true

## Returns a fully populated Actor dict with safe zero/empty defaults.
## Returned dict always passes validate(). Used as fallback in EchoActor.from_echo().
static func get_defaults() -> Dictionary:
	return {
		"id":             "",
		"name":           "",
		"rarity":         "uncalled",
		"rank":           1,
		"calling_origin": "uncalled",
		"stats":          { "max_hp": 0, "atk": 0, "def": 0, "agi": 0, "int": 0, "cha": 0 },
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"xp_total":       0,
		"level":          1,
		"actor_type":     "echo",
	}
