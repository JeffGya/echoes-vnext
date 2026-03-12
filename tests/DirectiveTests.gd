# res://tests/DirectiveTests.gd
# Tests for DirectiveService (DIRECTIVE-001):
#   1. registry_shape          — get_registry() returns all 6 directives; each has the 5 required keys
#   2. set_and_get_active      — set_active_directive("directive.scout") persists; get_active_directive() returns full definition
#   3. selected_log_fires      — set_active_directive emits directive.selected log event with correct directive_id
#   4. available_filters_locked — get_available_directives() returns only the 2 "always" directives
#
# All tests are pure unit tests (no file I/O or runtime needed).
# Run via Debug Panel: tests

extends RefCounted
class_name DirectiveTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("directive/registry_shape",           Callable(DirectiveTests, "_t_registry_shape"))
	runner.register_test("directive/set_and_get_active",       Callable(DirectiveTests, "_t_set_and_get_active"))
	runner.register_test("directive/selected_log_fires",       Callable(DirectiveTests, "_t_selected_log_fires"))
	runner.register_test("directive/available_filters_locked", Callable(DirectiveTests, "_t_available_filters_locked"))


# -------------------------
# Helpers
# -------------------------

static func _make_save() -> Dictionary:
	return { "stage_context": { "active_directive_id": "directive.none" } }


# -------------------------
# Tests
# -------------------------

# Test 1: registry_shape
# get_registry() must return all 6 directives, each with the 5 required definition keys.
# Spot-checks that directive.scout and directive.protect have the expected intent_weights keys.
static func _t_registry_shape() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	var registry: Dictionary = svc.get_registry()

	var expected_ids := ["directive.none", "directive.scout", "directive.protect",
						 "directive.push", "directive.preserve", "directive.focus"]

	if registry.size() != expected_ids.size():
		return { "ok": false, "error": "Expected %d directives in registry, got %d" % [
			expected_ids.size(), registry.size() ] }

	var required_keys := ["id", "label", "description", "intent_weights", "unlock_condition"]

	for id in expected_ids:
		if not registry.has(id):
			return { "ok": false, "error": "Registry missing expected directive: '%s'" % id }

		var defn: Dictionary = registry[id]
		for k in required_keys:
			if not defn.has(k):
				return { "ok": false, "error": "Directive '%s' missing required key '%s'" % [id, k] }
			if defn[k] == null:
				return { "ok": false, "error": "Directive '%s' key '%s' is null" % [id, k] }

	# Spot-check directive.scout intent_weights
	var scout: Dictionary = registry["directive.scout"]
	var scout_weights: Dictionary = scout["intent_weights"]
	for wk in ["survival_bias", "avoid_overcommit", "prefer_disengage", "reporting_priority"]:
		if not scout_weights.has(wk):
			return { "ok": false, "error": "directive.scout.intent_weights missing key '%s'" % wk }

	# Spot-check directive.protect intent_weights
	var protect: Dictionary = registry["directive.protect"]
	var protect_weights: Dictionary = protect["intent_weights"]
	if not protect_weights.has("ally_protection_bias"):
		return { "ok": false, "error": "directive.protect.intent_weights missing 'ally_protection_bias'" }

	return { "ok": true }


# Test 2: set_and_get_active
# set_active_directive("directive.scout") must persist the ID to stage_context.
# get_active_directive() must return the full definition dict (not just the ID string).
static func _t_set_and_get_active() -> Dictionary:
	var save_data := _make_save()
	var svc := DirectiveService.new(save_data)
	var logger := StructuredLogger.new()
	logger.set_level("off")

	svc.set_active_directive("directive.scout", logger, 1)

	# Verify persisted to save_data
	var stored_id: String = str(save_data.get("stage_context", {}).get("active_directive_id", ""))
	if stored_id != "directive.scout":
		return { "ok": false, "error": "Expected save_data.stage_context.active_directive_id='directive.scout', got: '%s'" % stored_id }

	# Verify get_active_directive returns full definition
	var defn: Dictionary = svc.get_active_directive()
	if defn.is_empty():
		return { "ok": false, "error": "get_active_directive() returned empty dict after set" }

	if str(defn.get("id", "")) != "directive.scout":
		return { "ok": false, "error": "Expected defn.id='directive.scout', got: '%s'" % str(defn.get("id", "")) }

	# Confirm it's a full definition (not just an ID string)
	for k in ["label", "description", "intent_weights", "unlock_condition"]:
		if not defn.has(k):
			return { "ok": false, "error": "get_active_directive() result missing key '%s'" % k }

	return { "ok": true }


# Test 3: selected_log_fires
# set_active_directive must emit a directive.selected log event with the correct directive_id.
static func _t_selected_log_fires() -> Dictionary:
	var save_data := _make_save()
	var svc := DirectiveService.new(save_data)
	var logger := StructuredLogger.new()
	logger.set_level("info")  # must be info to capture the log event

	svc.set_active_directive("directive.scout", logger, 5)

	var logs: Array = logger.get_logs()
	var found_event := false
	var found_id := ""
	for entry in logs:
		if str(entry.get("type", "")) == "directive.selected":
			found_event = true
			found_id = str(entry.get("data", {}).get("directive_id", ""))
			break

	if not found_event:
		return { "ok": false, "error": "No directive.selected log event found after set_active_directive()" }

	if found_id != "directive.scout":
		return { "ok": false, "error": "directive.selected event had directive_id='%s', expected 'directive.scout'" % found_id }

	return { "ok": true }


# Test 4: available_filters_locked
# get_available_directives() must return only directives with unlock_condition == "always".
# MVP: ["directive.none", "directive.scout"]. All others are "locked" and must be excluded.
static func _t_available_filters_locked() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	var available: Array = svc.get_available_directives()

	if available.size() != 2:
		return { "ok": false, "error": "Expected 2 available directives (always), got %d: %s" % [
			available.size(), str(available) ] }

	for expected_id in ["directive.none", "directive.scout"]:
		if not available.has(expected_id):
			return { "ok": false, "error": "Expected '%s' in available_directives, not found. Got: %s" % [
				expected_id, str(available) ] }

	for locked_id in ["directive.protect", "directive.push", "directive.preserve", "directive.focus"]:
		if available.has(locked_id):
			return { "ok": false, "error": "Locked directive '%s' should NOT appear in available_directives" % locked_id }

	return { "ok": true }
