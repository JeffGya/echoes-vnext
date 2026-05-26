# res://tests/SkillDefinitionTests.gd
# V2-PROG-005: Unit tests for SkillDefinition contract validator.
# calling_requirement removed from REQUIRED_FIELDS; skill_family is the V2 axis.
#
# All tests are pure static — no save file, no FlowRuntime, no OS time.
# Tests cover: valid definition, missing fields, wrong types, field count.
class_name SkillDefinitionTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("skill/valid_definition_passes",         Callable(SkillDefinitionTests, "_test_valid_definition_passes"))
	runner.register_test("skill/missing_required_field_fails",    Callable(SkillDefinitionTests, "_test_missing_required_field_fails"))
	runner.register_test("skill/wrong_type_on_field_fails",       Callable(SkillDefinitionTests, "_test_wrong_type_on_field_fails"))
	runner.register_test("skill/required_fields_count_is_nine",   Callable(SkillDefinitionTests, "_test_required_fields_count_is_nine"))


# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

## Returns a valid skill definition with all 9 required fields.
## V2-PROG-005: uses skill_family instead of calling_requirement.
## V2-PROG-009: added type (active/passive/utility) and description.
static func _valid_defn() -> Dictionary:
	return {
		"skill_id":          "skill.shield_bash",
		"skill_family":      "ward",
		"target_type":       "enemy",
		"action_type":       "melee.bash",
		"cooldown_rounds":   2,
		"scaling_source":    "atk",
		"intent_weight_tag": "aggressive",
		"type":              "active",
		"description":       "A forceful bash that rattles the enemy's defences.",
	}


# ────────────────────────────────────────────────────────────────────────────
# Tests
# ────────────────────────────────────────────────────────────────────────────

static func _test_valid_definition_passes() -> Dictionary:
	var defn := _valid_defn()
	if not SkillDefinition.validate(defn):
		return { "ok": false, "error": "validate() returned false for a fully valid definition" }
	return { "ok": true }


static func _test_missing_required_field_fails() -> Dictionary:
	for field in SkillDefinition.REQUIRED_FIELDS:
		var defn := _valid_defn()
		defn.erase(field)
		if SkillDefinition.validate(defn):
			return { "ok": false, "error": "validate() should return false when '%s' is missing" % field }
	return { "ok": true }


static func _test_wrong_type_on_field_fails() -> Dictionary:
	# String field given a non-String value
	var defn_bad_string := _valid_defn()
	defn_bad_string["skill_id"] = 999
	if SkillDefinition.validate(defn_bad_string):
		return { "ok": false, "error": "validate() should return false when skill_id is an int (999)" }

	# Numeric field given a String value
	var defn_bad_numeric := _valid_defn()
	defn_bad_numeric["cooldown_rounds"] = "three"
	if SkillDefinition.validate(defn_bad_numeric):
		return { "ok": false, "error": "validate() should return false when cooldown_rounds is a String ('three')" }

	return { "ok": true }


static func _test_required_fields_count_is_nine() -> Dictionary:
	if SkillDefinition.REQUIRED_FIELDS.size() != 9:
		return {
			"ok": false,
			"error": "Expected REQUIRED_FIELDS.size()==9, got %d. V2-PROG-009 added 'type' and 'description'." % SkillDefinition.REQUIRED_FIELDS.size()
		}
	var expected: Array = [
		"skill_id", "skill_family", "target_type",
		"action_type", "cooldown_rounds", "scaling_source", "intent_weight_tag",
		"type", "description",
	]
	for f in expected:
		if not SkillDefinition.REQUIRED_FIELDS.has(f):
			return { "ok": false, "error": "REQUIRED_FIELDS is missing expected field: '%s'" % f }
	return { "ok": true }
