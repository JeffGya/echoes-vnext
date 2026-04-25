# res://core/actors/EnemyActor.gd
# Maps an enemy definition dict → a valid Actor dict.
#
# BALANCE-001: Enemies now use DerivedStatService with per-type trait values from
# balance.json data.actor.enemy_types — same formula as echoes. This ensures stats
# scale properly as levels are introduced and allows varied enemy archetypes.
#
# Rules:
# - No RNG, no OS time. Purely deterministic field mapping.
# - Returns a dict that always passes ActorSchema.validate().
# - Stats are computed via DerivedStatService using enemy type traits + level.
# - caller is responsible for logging actor.stats_init (this is a pure static function).
#
# defn keys:
#   "id"      String  — required; use a stable enemy id (e.g. "enemy.dust_wanderer")
#   "name"    String  — display name
#   "type"    String  — enemy type key matching data.actor.enemy_types in balance.json
#   "level"   int     — defaults to 1
#   "faction" String  — optional; defaults to "enemy" if omitted (ACTOR-004)
#
# cfg keys (passed from FlowEncounterState):
#   "birth_stats"  Dictionary  — from balance.json data.summoning.birth_stats
#   "enemy_types"  Dictionary  — from balance.json data.actor.enemy_types

class_name EnemyActor
extends RefCounted

## Maps an enemy definition dict → a valid Actor dict.
## The returned dict passes ActorSchema.validate().
## cfg must contain "birth_stats" and "enemy_types" from balance.json.
## t is accepted for future use (caller logs actor.stats_init with t).
static func from_definition(defn: Dictionary, t: int, cfg: Dictionary = {}) -> Dictionary:
	var level: int = max(1, int(defn.get("level", 1)))

	# Look up per-type trait values from balance.json data.actor.enemy_types.
	var enemy_type: String      = str(defn.get("type", ""))
	var enemy_types: Dictionary = cfg.get("enemy_types", {})
	var type_def: Dictionary    = enemy_types.get(enemy_type, {})
	var type_traits: Dictionary = type_def.get("traits", {})

	# Traits for this enemy type; fall back to neutral (50) if type is unknown.
	var traits: Dictionary = {
		"courage": int(type_traits.get("courage", 50)),
		"wisdom":  int(type_traits.get("wisdom",  50)),
		"faith":   int(type_traits.get("faith",   50)),
	}

	# Compute stats via DerivedStatService — same pipeline as echoes.
	var stat_cfg: Dictionary    = cfg.get("birth_stats", {})
	var computed: Dictionary    = DerivedStatService.compute_stats(traits, 1, level, stat_cfg)

	var actor := {
		"id":             defn.get("id",   "enemy_unknown"),
		"name":           defn.get("name", "Unknown Enemy"),
		"rarity":         "uncalled",
		"rank":           1,
		"calling_origin": "enemy",
		"actor_type":     "enemy",
		"is_structure":   false,
		# ACTOR-008: death state — always starts alive at spawn
		"is_dead":        false,
		"death_round":    0,
		"level":          level,
		"xp_total":       0,
		"traits":         traits,
		"stats":          computed,
		# ACTOR-002: top-level runtime fields
		"current_hp": computed.get("max_hp", 60),  # = max_hp at spawn; mutable during combat
		"speed":      computed.get("speed",  5),   # formula-derived via DerivedStatService
		"morale":     50,                           # flat placeholder — EMOTION-001 supersedes this
		"fear":       0,                            # flat placeholder — EMOTION-001 supersedes this
		"fear_base":  0,                            # EMOTION-003: enemies have no resting fear floor
		# ACTOR-004: faction + grid_pos placeholder until GRID-001 places actors on board
		"faction":  defn.get("faction", "enemy"),
		"grid_pos": { "col": 0, "row": 0 },
		# PROG-010: enemies have no identity traits (empty arrays satisfy schema)
		"resilience_traits": [],
		"leadership_traits": [],
	}

	assert(ActorSchema.validate(actor),
		"EnemyActor.from_definition() produced an invalid actor dict — check REQUIRED_FIELDS")

	return actor
