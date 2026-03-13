# res://core/actors/EnemyActor.gd
# Maps an enemy definition dict → a valid Actor dict.
#
# Rules:
# - No RNG, no OS time. Purely deterministic field mapping.
# - Returns a dict that always passes ActorSchema.validate().
# - Flat defaults scaled by level; PROG-002 will replace with trait-derived formulas.
# - caller is responsible for logging actor.stats_init (this is a pure static function).
#
# defn keys:
#   "id"      String  — required; use a stable enemy id (e.g. "enemy.dust_wanderer")
#   "name"    String  — display name
#   "level"   int     — defaults to 1
#   "faction" String  — optional; defaults to "enemy" if omitted (ACTOR-004)

class_name EnemyActor
extends RefCounted

## Maps an enemy definition dict → a valid Actor dict.
## The returned dict passes ActorSchema.validate().
## t is accepted for future use (caller logs actor.stats_init with t).
static func from_definition(defn: Dictionary, t: int) -> Dictionary:
	var level: int = max(1, int(defn.get("level", 1)))

	var max_hp: int = 50 + (level * 10)
	var atk:    int = 5  + (level * 2)
	var def_v:  int = 2  + level
	var agi:    int = 3  + level

	var actor := {
		"id":             defn.get("id",   "enemy_unknown"),
		"name":           defn.get("name", "Unknown Enemy"),
		"rarity":         "uncalled",
		"rank":           1,
		"calling_origin": "uncalled",
		"actor_type":     "enemy",
		"is_structure":   false,
		"level":          level,
		"xp_total":       0,
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"stats": {
			"max_hp": max_hp,
			"atk":    atk,
			"def":    def_v,
			"agi":    agi,
			"int":    1,
			"cha":    0,
		},
		# ACTOR-002: top-level runtime fields
		"current_hp": max_hp,   # = max_hp at spawn; mutable during combat
		"speed":      5,        # flat default — COMBAT-002 derives formula later
		"morale":     50,       # flat placeholder — EMOTION-001 supersedes this
		"fear":       0,        # flat placeholder — EMOTION-001 supersedes this
		# ACTOR-004: faction + grid_pos placeholder until GRID-001 places actors on board
		"faction":  defn.get("faction", "enemy"),
		"grid_pos": { "col": 0, "row": 0 },
	}

	assert(ActorSchema.validate(actor),
		"EnemyActor.from_definition() produced an invalid actor dict — check REQUIRED_FIELDS")

	return actor
