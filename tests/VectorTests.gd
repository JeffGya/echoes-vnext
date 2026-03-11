# res://tests/VectorTests.gd
# Tests for VectorService interface (PROG-005):
#   1. Margin rule — below threshold: challenger does NOT become dominant
#   2. Margin rule — above threshold: challenger DOES become dominant
#   3. init_vectors reads archetype_init config and seeds vector_scores + dominant_vector correctly
#   4. accumulate() clamps at CLAMP_MAX (1000)
#   5. vector.dominant.changed log fires when dominant switches during accumulate()
#
# All tests use generic key names where possible (not hardcoded MVP vector names)
# so they remain valid if additional vectors are added post-MVP.
#
# All tests are pure unit tests (no runtime or save file needed).
# Run via Debug Panel: tests

extends RefCounted
class_name VectorTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("vector/no_switch_below_margin",    Callable(VectorTests, "_t_no_switch_below_margin"))
	runner.register_test("vector/switch_above_margin",       Callable(VectorTests, "_t_switch_above_margin"))
	runner.register_test("vector/archetype_init_from_config",Callable(VectorTests, "_t_archetype_init_from_config"))
	runner.register_test("vector/accumulate_clamps_at_1000", Callable(VectorTests, "_t_accumulate_clamps_at_1000"))
	runner.register_test("vector/dominant_changed_log_fires",Callable(VectorTests, "_t_dominant_changed_log_fires"))


# -------------------------
# Tests
# -------------------------

# Test 1: no_switch_below_margin
# Challenger at 63, current dominant at 60, total = 123.
# margin_threshold = 123 * 0.03 = 3.69. diff = 3. 3 is NOT > 3.69 → no switch.
# Generic key names ("alpha", "beta") to avoid coupling to MVP vector taxonomy.
static func _t_no_switch_below_margin() -> Dictionary:
	var scores := { "alpha": 60, "beta": 63, "gamma": 0, "delta": 0 }
	var current := "alpha"

	var result: String = VectorService.compute_dominant(scores, current)

	if result != "alpha":
		return { "ok": false, "error": "Expected dominant to stay 'alpha' (diff=3, threshold=3.69), got: '%s'" % result }

	return { "ok": true }


# Test 2: switch_above_margin
# Challenger at 64, current dominant at 60, total = 124.
# margin_threshold = 124 * 0.03 = 3.72. diff = 4. 4 IS > 3.72 → switch.
static func _t_switch_above_margin() -> Dictionary:
	var scores := { "alpha": 60, "beta": 64, "gamma": 0, "delta": 0 }
	var current := "alpha"

	var result: String = VectorService.compute_dominant(scores, current)

	if result != "beta":
		return { "ok": false, "error": "Expected dominant to switch to 'beta' (diff=4, threshold=3.72), got: '%s'" % result }

	return { "ok": true }


# Test 3: archetype_init_from_config
# init_vectors must read archetype_init weights for the given class_origin from vec_cfg,
# populate echo.vector_scores with those weights, and set echo.dominant_vector to the
# key with the highest weight.
# Uses a custom config dict with arbitrary key names — not hardcoded MVP vectors.
static func _t_archetype_init_from_config() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("info")  # must be "info" — test verifies vector.init log event fires

	# Arbitrary archetype with 4 generic vector keys — simulates real archetype_init structure.
	var mock_weights := { "x_vec": 60, "y_vec": 20, "z_vec": 10, "w_vec": 10 }
	var vec_cfg := {
		"archetype_init": {
			"testarch": mock_weights.duplicate()
		}
	}
	var echo := { "id": "echo_init_test", "class_origin": "testarch",
		"vector_scores": {}, "dominant_vector": "" }

	VectorService.init_vectors(echo, vec_cfg, logger, 1)

	# vector_scores must match the config weights exactly
	for key in mock_weights:
		if not echo["vector_scores"].has(key):
			return { "ok": false, "error": "vector_scores missing key '%s' after init_vectors" % key }
		if int(echo["vector_scores"][key]) != int(mock_weights[key]):
			return { "ok": false, "error": "vector_scores['%s'] = %d, expected %d" % [
				key, int(echo["vector_scores"][key]), int(mock_weights[key]) ] }

	# dominant_vector must be the highest-weight key (x_vec = 60)
	if echo["dominant_vector"] != "x_vec":
		return { "ok": false, "error": "Expected dominant_vector='x_vec' (weight=60), got: '%s'" % echo["dominant_vector"] }

	# Verify vector.init log event fired
	var logs: Array = logger.get_logs()
	var found := false
	for entry in logs:
		if str(entry.get("type", "")) == "vector.init":
			found = true
			break
	if not found:
		return { "ok": false, "error": "No vector.init log event found after init_vectors()" }

	return { "ok": true }


# Test 4: accumulate_clamps_at_1000
# Starting at 990, adding 50 must result in 1000 (CLAMP_MAX), not 1040.
static func _t_accumulate_clamps_at_1000() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := {
		"id": "echo_clamp_test",
		"vector_scores": { "alpha": 990 },
		"dominant_vector": "alpha"
	}

	VectorService.accumulate(echo, "alpha", 50, logger, 1)

	var val: int = int(echo["vector_scores"].get("alpha", -1))
	if val != 1000:
		return { "ok": false, "error": "Expected alpha=1000 after accumulate(990+50 clamped), got: %d" % val }

	return { "ok": true }


# Test 5: dominant_changed_log_fires
# After accumulating enough on "beta" to exceed "alpha" by > 3% of total,
# vector.dominant.changed must be logged and echo.dominant_vector must update.
static func _t_dominant_changed_log_fires() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("info")

	# alpha=60, beta=0, total=60. Current dominant="alpha".
	# Accumulate beta by 70 → beta=70, alpha=60, total=130.
	# margin_threshold = 130 * 0.03 = 3.9. diff = 10 > 3.9 → dominant switches to "beta".
	var echo := {
		"id": "echo_switch_test",
		"vector_scores": { "alpha": 60, "beta": 0 },
		"dominant_vector": "alpha"
	}

	VectorService.accumulate(echo, "beta", 70, logger, 1)

	if echo["dominant_vector"] != "beta":
		return { "ok": false, "error": "Expected dominant_vector='beta' after accumulate triggered switch, got: '%s'" % echo["dominant_vector"] }

	var logs: Array = logger.get_logs()
	var found := false
	for entry in logs:
		if str(entry.get("type", "")) == "vector.dominant.changed":
			found = true
			break
	if not found:
		return { "ok": false, "error": "No vector.dominant.changed log event found after dominant switch" }

	return { "ok": true }
