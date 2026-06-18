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

	# PROG-005: deep-copy vector_scores so mutations on the actor dict cannot
	# bleed back into save data. Any future vector keys are carried through automatically.
	var echo_vector_scores: Dictionary = echo.get("vector_scores", {})

	# PROG-010: deep-copy identity trait arrays so combat mutations don't bleed into save data.
	var echo_resilience: Array = (echo.get("resilience_traits", []) as Array).duplicate()
	var echo_leadership: Array = (echo.get("leadership_traits", []) as Array).duplicate()

	var actor := {
		"id":             echo.get("id",             defaults["id"]),
		"name":           echo.get("name",           defaults["name"]),
		"rarity":         echo.get("rarity",         defaults["rarity"]),
		"rank":           echo.get("rank",           defaults["rank"]),
		"calling_origin":  echo.get("calling_origin",  defaults["calling_origin"]),
		"calling":         echo.get("calling",         ""),  # V2-PROG-002: confirmed runtime identity (empty until Standing-3)
		"archetype_birth": echo.get("archetype_birth", ""),  # V2-VOICE-001: bark lookup key
		"stats":          echo_stats.duplicate(true),
		"traits":         echo_traits.duplicate(true),
		"xp_total":       echo.get("xp_total",       defaults["xp_total"]),
		"level":          echo.get("level",          1),
		"actor_type":     "echo",
		"is_structure":   false,   # ACTOR-006: Echoes are never structures
		# ACTOR-008: death state — always starts alive at spawn; ActorSM sets is_dead on KO
		"is_dead":        false,
		"death_round":    0,
		# ACTOR-002: runtime fields — not stored in save data; set fresh on each actor creation
		"current_hp":     echo_stats.get("max_hp", 0),  # = max_hp at spawn; mutable in combat
		"speed":          echo_stats.get("speed", 5),  # formula-derived; fallback 5 for saves pre-BALANCE-001
		"morale":         int(echo.get("emotion", {}).get("morale_current", 50)),  # EMOTION-001
		"fear":           int(echo.get("emotion", {}).get("fear_current",   0)),  # EMOTION-001
		"fear_base":      int(echo.get("emotion", {}).get("fear_base",      0)),  # EMOTION-003
		# PROG-005: vector data — read-only view of save data; deep copy for isolation
		"vector_scores":   echo_vector_scores.duplicate(true),
		"dominant_vector": str(echo.get("dominant_vector", "")),
		# ACTOR-004: faction + grid_pos placeholder until GRID-001 places actors on board
		"faction":  "echo",
		"grid_pos": { "col": 0, "row": 0 },
		# PROG-010: identity traits — deep copy from echo save
		"resilience_traits": echo_resilience,
		"leadership_traits": echo_leadership,
		# PROG-008: active skill slots — deep copy; [""] = 1 empty slot at MVP; grows with callings
		"skill_slots": (echo.get("skill_slots", [""]) as Array).duplicate(),
		# PROG-009: equipped skills dict — slot_index_str → skill_id. Deep copy for isolation.
		"equipped_skills": (echo.get("equipped_skills", {}) as Dictionary).duplicate(true),
	}

	# Structural guard: every required field must be present + non-null. We deliberately do
	# NOT abort here on an empty `id`: an Echo can legitimately reach this mapper with a blank
	# id (degraded/legacy data). Id-uniqueness for the id-keyed combat round loop is enforced
	# downstream by FlowEncounterState._ensure_unique_actor_ids() before initiative is built,
	# so aborting here would only hide the actor (and break that guard). ActorSchema.validate()
	# still rejects empty ids elsewhere (e.g. save repair, enemy/structure mappers).
	assert(ActorSchema.has_all_required_fields(actor), \
		"EchoActor.from_echo() produced an invalid actor dict — check required fields")

	return actor
