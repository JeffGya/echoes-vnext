# res://core/progression/SkillDefinition.gd
# PROG-008: Active skill data contract and validator.
# PROG-009: Added tier_gate as a recognised optional field (empty in PROG-009; PROG-011 populates).
#
# Skill slots hold ACTIVE skills only — skills that fire as intent actions in combat.
# Passive skills (always-on trait effects) and stat bumps are never placed in slots.
#
# Rules:
# - No RNG, no OS time, no side effects.
# - validate() checks presence and String/int/float type only — not value ranges.
# - validate() accepts (but does not require) optional fields: tier_gate, once_per_combat,
#   read_field_max_streak, read_field_cooldown_rounds. Unknown extra fields are silently ignored.
# - MAX_SKILL_SLOTS is the canonical loadout capacity constant for compile-time use.
# - get_slot_count() is the single choke point for slot entitlement logic; future
#   rank 6 / second-calling expansion updates this function only.

class_name SkillDefinition
extends RefCounted

## Canonical loadout capacity for compile-time use in GDScript callsites.
## balance.json data.skills.max_skill_slots is the data-layer source of truth;
## this constant mirrors it. Both must be kept in sync.
const MAX_SKILL_SLOTS: int = 1

## All 7 required fields for a valid SkillDefinition entry.
## Any definition loaded from balance.json data.skills.definitions must contain all of these.
const REQUIRED_FIELDS: Array = [
	"skill_id",
	"calling_requirement",
	"target_type",
	"action_type",
	"cooldown_rounds",
	"scaling_source",
	"intent_weight_tag",
]


## Returns true when defn contains all 7 required fields with correct types.
## String fields must be String. cooldown_rounds must be int or float
## (JSON.parse_string returns numeric values as float in Godot 4).
## Fails fast on the first missing or wrong-type field.
static func validate(defn: Dictionary) -> bool:
	if defn.is_empty():
		return false
	var string_fields: Array = [
		"skill_id",
		"calling_requirement",
		"target_type",
		"action_type",
		"scaling_source",
		"intent_weight_tag",
	]
	for f in string_fields:
		if not defn.has(f):
			return false
		if not (defn[f] is String):
			return false
	if not defn.has("cooldown_rounds"):
		return false
	var cr = defn["cooldown_rounds"]
	if not (cr is int or cr is float):
		return false
	return true


## Returns the number of active skill slots this echo is entitled to.
## MVP: 1 slot when calling is confirmed (calling field non-empty); 0 otherwise.
##
## This is the single choke point for slot entitlement — future rank 6 / second-calling
## expansion updates this function only (append a second slot when a second calling is confirmed).
##
## echo:       the echo save dict (must have "calling" key)
## skills_cfg: the data.skills block from balance.json (reserved for future threshold config)
static func get_slot_count(echo: Dictionary, _skills_cfg: Dictionary) -> int:
	if str(echo.get("calling", "")).is_empty():
		return 0
	return 1
