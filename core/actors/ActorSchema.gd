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
# GRID-002: grid_pos { col, row } is now a required field.
# Assigned by GridService.assign_grid_pos() during encounter entry.
#
# ActorStateMachine (core/actors/ActorStateMachine.gd) is scaffolded in ACTOR-002.
# It stores the actor dict and exposes get_stat() for behavior modules.
# ACTOR-003+ adds state phases and behavior module wiring.

class_name ActorSchema
extends RefCounted

## Canonical list of required field names for any Actor dict.
## All fields must be present and non-null. Value ranges are not enforced here.
##
## ACTOR-002 additions (top-level runtime fields — not saved in sanctum.roster[]):
##   current_hp  — mutable during combat; set to stats.max_hp at spawn by EchoActor/EnemyActor
##   speed       — turn order input for COMBAT-002 (actor.speed XOR seed); flat default 5
##   morale      — flat placeholder (50); EMOTION-001 supersedes with emotion.morale_current
##   fear        — flat placeholder (0);  EMOTION-001 supersedes with emotion.fear_current
## ACTOR-006 addition:
##   is_structure — true only for Shrine/Totem/Hazard actors; set at spawn, immutable by convention.
##                  Prevents movement phase and any callings that require mobility.
## ACTOR-008 additions:
##   is_dead      — set to true when current_hp <= 0; immutable once true.
##                  Echo dicts are preserved intact on death (future relic system).
##   death_round  — sim tick (t) at which the actor died; 0 = never died.
## GRID-002 addition:
##   grid_pos     — spawn position on the combat board; { col: int, row: int }.
##                  Assigned by GridService.assign_grid_pos() during encounter entry.
##                  Default { col: 0, row: 0 } is a safe placeholder until assigned.
## PROG-010 additions:
##   resilience_traits  — Array of trait IDs active at Veteran+. Default [].
##   leadership_traits  — Array of trait IDs active at Elite tier. Default [].
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
	"current_hp",
	"speed",
	"morale",
	"fear",
	"is_structure",
	"is_dead",
	"death_round",
	"grid_pos",
	"resilience_traits",
	"leadership_traits",
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
		"calling":        "",  # V2-PROG-002: confirmed calling id (empty until Standing-3); not in REQUIRED_FIELDS — enemies have none
		"stats":          { "max_hp": 0, "atk": 0, "def": 0, "agi": 0, "int": 0, "cha": 0 },
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"xp_total":       0,
		"level":          1,
		"actor_type":     "echo",
		# ACTOR-002: top-level runtime fields (not saved in sanctum.roster[])
		"current_hp":     0,
		"speed":          5,
		"morale":         50,
		"fear":           0,
		# ACTOR-006: structure flag — false for Echoes/Enemies; true only for structure actors
		"is_structure":   false,
		# ACTOR-008: death state — immutable once is_dead=true; death_round=0 means alive
		"is_dead":        false,
		"death_round":    0,
		# GRID-002: combat board position — assigned by GridService.assign_grid_pos()
		"grid_pos":       { "col": 0, "row": 0 },
		# COMBAT-003: runtime defensive stance — cleared at round start; NOT persisted.
		"guard_state":    false,
		# PROG-010: identity traits (seeded at generation; active from Veteran+/Elite tier)
		"resilience_traits": [],
		"leadership_traits": [],
	}
