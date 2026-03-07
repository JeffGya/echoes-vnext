# res://core/actors/EchoActor.gd
# Maps a raw Echo save dictionary into a unified Actor dictionary.
#
# Rules:
# - No RNG, no OS time. Purely deterministic field mapping.
# - Returns a DEEP COPY — mutating the returned actor dict must not
#   mutate the original echo in save data.
# - Uses ActorSchema.get_defaults() as fallback for any missing Echo field.
# - Always calls ActorSchema.validate() via assert before returning.
#
# Future actor types (enemies, NPCs) will have their own mapper files
# following this same pattern (e.g. EnemyActor.gd).

class_name EchoActor
extends RefCounted

## Maps an Echo save dict → a valid Actor dict (read-only view).
## The returned dict is a deep copy — safe to store/pass without risk
## of mutating save data.
##
## Missing Echo fields fall back to ActorSchema defaults.
static func from_echo(echo: Dictionary) -> Dictionary:
	var defaults := ActorSchema.get_defaults()

	# Nested dicts must be duplicated individually to guarantee deep copy.
	var echo_stats: Dictionary = echo.get("stats", defaults["stats"])
	var echo_traits: Dictionary = echo.get("traits", defaults["traits"])

	var actor := {
		"id":             echo.get("id",             defaults["id"]),
		"name":           echo.get("name",           defaults["name"]),
		"rarity":         echo.get("rarity",         defaults["rarity"]),
		"rank":           echo.get("rank",           defaults["rank"]),
		"calling_origin": echo.get("calling_origin", defaults["calling_origin"]),
		"stats":          echo_stats.duplicate(true),
		"traits":         echo_traits.duplicate(true),
		"xp_total":       echo.get("xp_total",       defaults["xp_total"]),
		"level":          echo.get("level",          1),
		"actor_type":     "echo",
	}

	assert(ActorSchema.validate(actor), \
		"EchoActor.from_echo() produced an invalid actor dict — check required fields")

	return actor
