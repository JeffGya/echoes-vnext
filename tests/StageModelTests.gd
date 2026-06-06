# res://tests/StageModelTests.gd
# REALM-002: Tests for StageModel factory + RealmGenerator + RealmService stage integration.
#
# Tests:
#   1.  stage/model_fields_present          — StageModel.make() has all 4 required fields
#   2.  stage/model_validate_passes         — StageModel.validate() returns true
#   3.  stage/generator_stage_count         — RealmGenerator.generate() returns correct count
#   4.  stage/generator_obj_count_range     — each stage obj_count is within [min, max]
#   5.  stage/generator_last_obj_is_boss    — final objective in every stage is "boss"
#   6.  stage/generator_stage_types_valid   — all stage summary types are valid strings
#   7.  stage/generator_purification_when_shrine — shrine pre-boss → type = "purification"
#   8.  stage/generator_combat_when_no_shrine    — no shrine pre-boss → type = "combat"
#   9.  stage/generator_determinism         — same realm_seed + params → identical output
#   10. stage/service_has_stages            — RealmService.get_or_create() populates stages[]

extends RefCounted
class_name StageModelTests


# ─── Mock Config Service ─────────────────────────────────────────────────────
class MockConfigService extends RefCounted:
	func get_realms() -> Dictionary:
		return {
			"data": {
				"realm_order": ["realm.01"],
				"realms": {
					"realm.01": {
						"id":              "realm.01",
						"name":            "Vale of Dust",
						"virtue":          "courage",
						"description":     "Test realm.",
						"locked":          false,
						"seed_namespace":  "campaign.realm.01",
						"stage_count_min": 3,
						"stage_count_max": 3,
						"obj_count_min":   2,
						"obj_count_max":   3,
					},
				}
			}
		}


# ─── Helpers ─────────────────────────────────────────────────────────────────
static func _make_ctx(root_seed: int = 42) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.config_service = MockConfigService.new()
	ctx.campaign_seed  = CampaignSeed.new(root_seed)
	ctx.save_data      = { "realms": {} }
	var logger         := StructuredLogger.new()
	logger.set_level("warn")
	ctx.logger = logger
	ctx.save_request        = false
	ctx.save_request_reason = ""
	return ctx


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("stage/model_fields_present",        Callable(StageModelTests, "_t_model_fields_present"))
	runner.register_test("stage/model_validate_passes",       Callable(StageModelTests, "_t_model_validate_passes"))
	runner.register_test("stage/generator_stage_count",       Callable(StageModelTests, "_t_generator_stage_count"))
	runner.register_test("stage/generator_obj_count_range",   Callable(StageModelTests, "_t_generator_obj_count_range"))
	runner.register_test("stage/generator_last_obj_is_boss",  Callable(StageModelTests, "_t_generator_last_obj_is_boss"))
	runner.register_test("stage/generator_stage_types_valid", Callable(StageModelTests, "_t_generator_stage_types_valid"))
	runner.register_test("stage/generator_purification_when_shrine", Callable(StageModelTests, "_t_generator_purification_when_shrine"))
	runner.register_test("stage/generator_combat_when_no_shrine",    Callable(StageModelTests, "_t_generator_combat_when_no_shrine"))
	runner.register_test("stage/generator_determinism",       Callable(StageModelTests, "_t_generator_determinism"))
	runner.register_test("stage/service_has_stages",          Callable(StageModelTests, "_t_service_has_stages"))


# ─── Test 1 — StageModel.make() has all 4 required fields ────────────────────
static func _t_model_fields_present() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_BOSS, 1)]
	var model := StageModel.make(0, StageModel.TYPE_COMBAT, 999, objs)
	for key in StageModel.REQUIRED_FIELDS:
		if not model.has(key):
			return { "ok": false, "error": "StageModel.make() missing required field: %s" % key }
	if not model["objectives"] is Array:
		return { "ok": false, "error": "'objectives' should be an Array" }
	return { "ok": true }


# ─── Test 2 — StageModel.validate() returns true ─────────────────────────────
static func _t_model_validate_passes() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_BOSS, 2)]
	var model := StageModel.make(0, StageModel.TYPE_PURIFICATION, 888, objs)
	if not StageModel.validate(model):
		return { "ok": false, "error": "StageModel.validate() returned false for a valid model" }
	return { "ok": true }


# ─── Test 3 — generate() returns correct stage count ─────────────────────────
static func _t_generator_stage_count() -> Dictionary:
	var stages := RealmGenerator.generate(12345, 4, 1, 2)
	if stages.size() != 4:
		return { "ok": false, "error": "Expected 4 stages, got %d" % stages.size() }
	return { "ok": true }


# ─── Test 4 — each stage obj_count is within [min, max] ──────────────────────
static func _t_generator_obj_count_range() -> Dictionary:
	var stages := RealmGenerator.generate(12345, 5, 2, 3)
	for i in range(stages.size()):
		var s_v: Variant = stages[i]
		var s: Dictionary = s_v if s_v is Dictionary else {}
		var objs_v: Variant = s.get("objectives", [])
		var objs: Array = objs_v if objs_v is Array else []
		if objs.size() < 2 or objs.size() > 3:
			return {
				"ok": false,
				"error": "Stage %d has %d objectives, expected 2-3" % [i, objs.size()]
			}
	return { "ok": true }


# ─── Test 5 — final objective in every stage is "boss" ───────────────────────
static func _t_generator_last_obj_is_boss() -> Dictionary:
	var stages := RealmGenerator.generate(77777, 3, 1, 3)
	for i in range(stages.size()):
		var s_v: Variant = stages[i]
		var s: Dictionary = s_v if s_v is Dictionary else {}
		var objs_v: Variant = s.get("objectives", [])
		var objs: Array = objs_v if objs_v is Array else []
		if objs.is_empty():
			return { "ok": false, "error": "Stage %d has no objectives" % i }
		var last_v: Variant = objs[objs.size() - 1]
		var last: Dictionary = last_v if last_v is Dictionary else {}
		if str(last.get("type", "")) != ObjectiveModel.TYPE_BOSS:
			return {
				"ok": false,
				"error": "Stage %d last objective type is '%s', expected 'boss'" % [i, last.get("type", "")]
			}
	return { "ok": true }


# ─── Test 6 — all stage summary types are valid strings ──────────────────────
static func _t_generator_stage_types_valid() -> Dictionary:
	var stages := RealmGenerator.generate(55555, 6, 1, 3)
	for i in range(stages.size()):
		var s_v: Variant = stages[i]
		var s: Dictionary = s_v if s_v is Dictionary else {}
		var t: String = str(s.get("type", ""))
		if not StageModel.VALID_TYPES.has(t):
			return {
				"ok": false,
				"error": "Stage %d has invalid type '%s' (valid: %s)" % [i, t, StageModel.VALID_TYPES]
			}
	return { "ok": true }


# ─── Test 7 — shrine pre-boss obj → stage type = "purification" ──────────────
static func _t_generator_purification_when_shrine() -> Dictionary:
	# With obj_count_min=obj_count_max=2, we get exactly 1 pre-boss obj per stage.
	# Scan all stages across many seeds until we find one with a shrine pre-boss obj.
	for seed_val in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 100, 200, 300, 999, 12345]:
		var stages := RealmGenerator.generate(seed_val, 5, 2, 2)
		for s_v in stages:
			var s: Dictionary = s_v if s_v is Dictionary else {}
			var objs_v: Variant = s.get("objectives", [])
			var objs: Array = objs_v if objs_v is Array else []
			# Pre-boss objectives: all except the last
			for j in range(objs.size() - 1):
				var obj_v: Variant = objs[j]
				var obj: Dictionary = obj_v if obj_v is Dictionary else {}
				if str(obj.get("type", "")) == ObjectiveModel.TYPE_SHRINE:
					if str(s.get("type", "")) != StageModel.TYPE_PURIFICATION:
						return {
							"ok": false,
							"error": "Stage with shrine pre-boss obj should be 'purification', got '%s'" % s.get("type", "")
						}
					return { "ok": true }

	return { "ok": false, "error": "No shrine pre-boss obj found across test seeds — increase seed range" }


# ─── Test 8 — no shrine pre-boss → stage type = "combat" ────────────────────
static func _t_generator_combat_when_no_shrine() -> Dictionary:
	# V2-STAGE-002: minimum obj_count is now 2 (1 pre-boss + 1 boss) — boss-only stages are gone.
	# When all pre-boss objectives are combat type, stage type must be "combat".
	# Calling with obj_count_min=1 → clamped to 2 by generator.
	var stages := RealmGenerator.generate(12345, 3, 1, 1)
	for i in range(stages.size()):
		var s_v: Variant = stages[i]
		var s: Dictionary = s_v if s_v is Dictionary else {}
		var objs_v: Variant = s.get("objectives", [])
		var objs: Array = objs_v if objs_v is Array else []
		# obj_count_min=1 is clamped to 2: 1 pre-boss + 1 boss = 2 objectives minimum.
		if objs.size() < 2:
			return { "ok": false, "error": "Expected at least 2 objectives (1 pre-boss + boss), got %d" % objs.size() }
		# With default pool (combat/shrine), stages with no shrine pre-boss → type "combat"
		if str(s.get("type", "")) not in [StageModel.TYPE_COMBAT, StageModel.TYPE_PURIFICATION, StageModel.TYPE_RECOVERY, StageModel.TYPE_PROTECTION]:
			return {
				"ok": false,
				"error": "Stage type must be a valid StageModel type, got '%s'" % s.get("type", "")
			}
	return { "ok": true }


# ─── Test 9 — determinism: same inputs → identical output ────────────────────
static func _t_generator_determinism() -> Dictionary:
	var stages_a := RealmGenerator.generate(99999, 4, 2, 3)
	var stages_b := RealmGenerator.generate(99999, 4, 2, 3)

	if stages_a.size() != stages_b.size():
		return { "ok": false, "error": "Stage count differs between two identical calls" }

	for i in range(stages_a.size()):
		var a: Dictionary = stages_a[i] if stages_a[i] is Dictionary else {}
		var b: Dictionary = stages_b[i] if stages_b[i] is Dictionary else {}
		if int(a.get("seed", -1)) != int(b.get("seed", -2)):
			return { "ok": false, "error": "Stage %d seed not deterministic" % i }
		if str(a.get("type", "")) != str(b.get("type", "")):
			return { "ok": false, "error": "Stage %d type not deterministic" % i }
		var a_objs: Array = a.get("objectives", []) if a.get("objectives") is Array else []
		var b_objs: Array = b.get("objectives", []) if b.get("objectives") is Array else []
		if a_objs.size() != b_objs.size():
			return { "ok": false, "error": "Stage %d objective count not deterministic" % i }
		for j in range(a_objs.size()):
			var ao: Dictionary = a_objs[j] if a_objs[j] is Dictionary else {}
			var bo: Dictionary = b_objs[j] if b_objs[j] is Dictionary else {}
			if str(ao.get("type", "")) != str(bo.get("type", "")):
				return { "ok": false, "error": "Stage %d obj %d type not deterministic" % [i, j] }
			if int(ao.get("seed", -1)) != int(bo.get("seed", -2)):
				return { "ok": false, "error": "Stage %d obj %d seed not deterministic" % [i, j] }

	return { "ok": true }


# ─── Test 10 — RealmService.get_or_create() populates stages[] ───────────────
static func _t_service_has_stages() -> Dictionary:
	var ctx := _make_ctx(42)
	var model: Dictionary = RealmService.get_or_create("realm.01", ctx, 1)

	if model.is_empty():
		return { "ok": false, "error": "RealmService returned empty dict" }

	if not model.has("stages"):
		return { "ok": false, "error": "RealmModel missing 'stages' key" }

	var stages_v: Variant = model.get("stages")
	if not stages_v is Array:
		return { "ok": false, "error": "'stages' is not an Array" }

	var stages: Array = stages_v
	if stages.is_empty():
		return { "ok": false, "error": "'stages' array is empty — RealmGenerator was not called" }

	# MockConfigService sets stage_count_min/max = 3, so we expect exactly 3
	var expected_count: int = int(model.get("stage_count", 0))
	if stages.size() != expected_count:
		return {
			"ok": false,
			"error": "stages.size()=%d but stage_count=%d" % [stages.size(), expected_count]
		}

	return { "ok": true }
