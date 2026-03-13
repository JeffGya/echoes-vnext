# res://core/actors/StructureActor.gd
# Maps a structure definition dict into a unified Actor dictionary.
# ACTOR-006: Structures (Shrines, Totems, Hazards) participate in targeting and
# HP tracking without ever moving.
#
# Rules:
# - Pure static factory — no logger param (caller logs if needed; same pattern as EnemyActor).
# - No RNG, no OS time. Purely deterministic field mapping.
# - is_structure is always true — immutable by convention after spawn.
# - actor_type is always "structure" — routes to IdleBehaviorModule in ActorStateMachine.
# - Always calls ActorSchema.validate() via assert before returning.
#
# `t` is accepted for API consistency (matches EnemyActor.from_definition signature)
# but is not used internally — StructureActor is a pure mapping function.

class_name StructureActor
extends RefCounted


## Maps a structure definition dict → a valid Actor dict.
## defn keys (all optional with safe defaults):
##   id, name, faction, max_hp, grid_pos
## t: current sim tick — accepted for API consistency, not used internally.
static func from_definition(defn: Dictionary, t: int) -> Dictionary:
	@warning_ignore("unused_parameter")
	var _t: int = t  # API consistency; not used in pure mapping

	var max_hp: int = max(1, int(defn.get("max_hp", 100)))

	var actor := {
		"id":             str(defn.get("id",   "structure_unknown")),
		"name":           str(defn.get("name", "Unknown Structure")),
		"rarity":         "uncalled",
		"rank":           1,
		"calling_origin": "uncalled",
		"actor_type":     "structure",
		"is_structure":   true,
		# ACTOR-008: death state — always starts alive at spawn
		"is_dead":        false,
		"death_round":    0,
		"level":          1,
		"xp_total":       0,
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"stats":          { "max_hp": max_hp, "atk": 0, "def": 0, "agi": 0, "int": 0, "cha": 0 },
		"current_hp":     max_hp,
		"speed":          0,
		"morale":         50,
		"fear":           0,
		"faction":        str(defn.get("faction", "structure")),
		"grid_pos":       defn.get("grid_pos", { "col": 0, "row": 0 }),
	}

	assert(ActorSchema.validate(actor), \
		"StructureActor.from_definition() produced an invalid actor dict — check required fields")

	return actor
