# res://tests/ObjectiveModelTests.gd
# REALM-002: Tests for ObjectiveModel factory.
#
# Tests:
#   1. objective/model_fields_present  — ObjectiveModel.make() returns dict with all 3 required keys
#   2. objective/model_validate_passes — ObjectiveModel.validate() returns true for a valid model
#   3. objective/model_has_params      — result always has "params" key (even with default {})

extends RefCounted
class_name ObjectiveModelTests


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("objective/model_fields_present",  Callable(ObjectiveModelTests, "_t_model_fields_present"))
	runner.register_test("objective/model_validate_passes", Callable(ObjectiveModelTests, "_t_model_validate_passes"))
	runner.register_test("objective/model_has_params",      Callable(ObjectiveModelTests, "_t_model_has_params"))


# ─── Test 1 — All required fields present ────────────────────────────────────
static func _t_model_fields_present() -> Dictionary:
	var model := ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 12345)
	for key in ObjectiveModel.REQUIRED_FIELDS:
		if not model.has(key):
			return { "ok": false, "error": "ObjectiveModel.make() missing required field: %s" % key }
	return { "ok": true }


# ─── Test 2 — validate() returns true ────────────────────────────────────────
static func _t_model_validate_passes() -> Dictionary:
	var model := ObjectiveModel.make(0, ObjectiveModel.TYPE_SHRINE, 99999)
	if not ObjectiveModel.validate(model):
		return { "ok": false, "error": "ObjectiveModel.validate() returned false for a valid model" }
	return { "ok": true }


# ─── Test 3 — params key always present (defaults to {}) ─────────────────────
static func _t_model_has_params() -> Dictionary:
	var model_default := ObjectiveModel.make(0, ObjectiveModel.TYPE_BOSS, 1)
	if not model_default.has("params"):
		return { "ok": false, "error": "ObjectiveModel.make() with default params missing 'params' key" }
	if not model_default["params"] is Dictionary:
		return { "ok": false, "error": "'params' should be a Dictionary, got: %s" % typeof(model_default["params"]) }

	var custom_params := { "wave_count": 3 }
	var model_custom := ObjectiveModel.make(1, ObjectiveModel.TYPE_BOSS, 2, custom_params)
	if int(model_custom["params"].get("wave_count", 0)) != 3:
		return { "ok": false, "error": "Custom params not stored correctly" }

	return { "ok": true }
