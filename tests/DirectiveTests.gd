# res://tests/DirectiveTests.gd
# Tests for DirectiveService (V2-DIRECTIVE-001):
#   1. registry_shape           — get_registry() returns exactly 2 V2 directives; each has all 7 required keys;
#                                  pros/cons are Arrays of size 2; spot-checks V2 intent_weight keys.
#   2. set_and_get_active       — set_active_directive("directive.scout_carefully") persists;
#                                  get_active_directive() returns full definition including pros/cons.
#   3. selected_log_fires       — set_active_directive emits directive.selected log event with correct directive_id.
#   4. available_filters_locked — get_available_directives() returns exactly the 2 V2 IDs; no V1 IDs present.
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
	return { "stage_context": { "active_directive_id": "directive.scout_carefully" } }


# -------------------------
# Tests
# -------------------------

# Test 1: registry_shape
# get_registry() must return exactly 2 V2 directives.
# Each must have all 7 required keys. pros/cons must be Arrays of size 2.
# Spot-checks V2 intent_weight keys on each directive.
static func _t_registry_shape() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	var registry: Dictionary = svc.get_registry()

	var expected_ids := ["directive.scout_carefully", "directive.seek_signs"]

	if registry.size() != expected_ids.size():
		return { "ok": false, "error": "Expected %d directives in registry, got %d" % [
			expected_ids.size(), registry.size() ] }

	var required_keys := ["id", "label", "description", "pros", "cons", "intent_weights", "unlock_condition"]

	for id in expected_ids:
		if not registry.has(id):
			return { "ok": false, "error": "Registry missing expected directive: '%s'" % id }

		var defn: Dictionary = registry[id]
		for k in required_keys:
			if not defn.has(k):
				return { "ok": false, "error": "Directive '%s' missing required key '%s'" % [id, k] }
			if defn[k] == null:
				return { "ok": false, "error": "Directive '%s' key '%s' is null" % [id, k] }

		# pros and cons must each be an Array of size 2
		if not (defn["pros"] is Array) or (defn["pros"] as Array).size() != 2:
			return { "ok": false, "error": "Directive '%s' pros must be an Array of size 2" % id }
		if not (defn["cons"] is Array) or (defn["cons"] as Array).size() != 2:
			return { "ok": false, "error": "Directive '%s' cons must be an Array of size 2" % id }

	# Spot-check directive.scout_carefully intent_weights
	var sc: Dictionary = registry["directive.scout_carefully"]
	var sc_weights: Dictionary = sc["intent_weights"]
	for wk in ["survival_bias", "avoid_overcommit", "prefer_disengage", "resource_efficiency"]:
		if not sc_weights.has(wk):
			return { "ok": false, "error": "directive.scout_carefully.intent_weights missing key '%s'" % wk }

	# Spot-check directive.seek_signs intent_weights
	var ss: Dictionary = registry["directive.seek_signs"]
	var ss_weights: Dictionary = ss["intent_weights"]
	for wk in ["clue_seeking_priority", "reporting_priority", "exposure_acceptance", "survival_bias"]:
		if not ss_weights.has(wk):
			return { "ok": false, "error": "directive.seek_signs.intent_weights missing key '%s'" % wk }

	return { "ok": true }


# Test 2: set_and_get_active
# set_active_directive("directive.scout_carefully") must persist the ID to stage_context.
# get_active_directive() must return the full definition dict including pros/cons.
static func _t_set_and_get_active() -> Dictionary:
	var save_data := _make_save()
	var svc := DirectiveService.new(save_data)
	var logger := StructuredLogger.new()
	logger.set_level("off")

	svc.set_active_directive("directive.scout_carefully", logger, 1)

	# Verify persisted to save_data
	var stored_id: String = str(save_data.get("stage_context", {}).get("active_directive_id", ""))
	if stored_id != "directive.scout_carefully":
		return { "ok": false, "error": "Expected save_data.stage_context.active_directive_id='directive.scout_carefully', got: '%s'" % stored_id }

	# Verify get_active_directive returns full definition
	var defn: Dictionary = svc.get_active_directive()
	if defn.is_empty():
		return { "ok": false, "error": "get_active_directive() returned empty dict after set" }

	if str(defn.get("id", "")) != "directive.scout_carefully":
		return { "ok": false, "error": "Expected defn.id='directive.scout_carefully', got: '%s'" % str(defn.get("id", "")) }

	# Confirm it's a full definition including V2 fields
	for k in ["label", "description", "pros", "cons", "intent_weights", "unlock_condition"]:
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

	svc.set_active_directive("directive.seek_signs", logger, 5)

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

	if found_id != "directive.seek_signs":
		return { "ok": false, "error": "directive.selected event had directive_id='%s', expected 'directive.seek_signs'" % found_id }

	return { "ok": true }


# Test 4: available_filters_locked
# get_available_directives() must return exactly ["directive.scout_carefully", "directive.seek_signs"].
# No V1 IDs (directive.none, directive.scout, directive.protect, etc.) should appear.
static func _t_available_filters_locked() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	var available: Array = svc.get_available_directives()

	if available.size() != 2:
		return { "ok": false, "error": "Expected 2 available directives, got %d: %s" % [
			available.size(), str(available) ] }

	for expected_id in ["directive.scout_carefully", "directive.seek_signs"]:
		if not available.has(expected_id):
			return { "ok": false, "error": "Expected '%s' in available_directives, not found. Got: %s" % [
				expected_id, str(available) ] }

	for old_id in ["directive.none", "directive.scout", "directive.protect", "directive.push", "directive.preserve", "directive.focus"]:
		if available.has(old_id):
			return { "ok": false, "error": "V1 directive '%s' must NOT appear in available_directives" % old_id }

	return { "ok": true }
