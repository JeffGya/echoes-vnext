# res://tests/ContactModelTests.gd
# Tests for ContactModel factory and validation.
#
# Tests:
#   1. contact/make_returns_dict              — make() returns a Dictionary
#   2. contact/make_has_all_required_fields   — all 12 REQUIRED_FIELDS present in output
#   3. contact/make_sets_initial_state_pending — state == "pending"
#   4. contact/make_sets_turn_current_zero    — turn_current == 0
#   5. contact/make_sets_empty_outcome        — outcome == ""
#   6. contact/make_empty_arrays_on_create    — consulted_echo_ids, speaking_echo_ids, consulted_ids_this_turn all == []
#   7. contact/make_empty_dict_on_create      — ignored_bid_counts == {}
#   8. contact/validate_passes_for_valid      — validate(make(...)) returns true
#   9. contact/validate_fails_missing_role    — contact with role erased fails validate
#  10. contact/validate_fails_missing_name    — contact with name erased fails validate
#  11. contact/valid_roles_contains_five      — VALID_ROLES.size() == 5
#  12. contact/valid_dispositions_contains_six — VALID_DISPOSITIONS.size() == 6

extends RefCounted
class_name ContactModelTests


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("contact/make_returns_dict",               Callable(ContactModelTests, "_t_make_returns_dict"))
	runner.register_test("contact/make_has_all_required_fields",    Callable(ContactModelTests, "_t_make_has_all_required_fields"))
	runner.register_test("contact/make_sets_initial_state_pending", Callable(ContactModelTests, "_t_make_sets_initial_state_pending"))
	runner.register_test("contact/make_sets_turn_current_zero",     Callable(ContactModelTests, "_t_make_sets_turn_current_zero"))
	runner.register_test("contact/make_sets_empty_outcome",         Callable(ContactModelTests, "_t_make_sets_empty_outcome"))
	runner.register_test("contact/make_empty_arrays_on_create",     Callable(ContactModelTests, "_t_make_empty_arrays_on_create"))
	runner.register_test("contact/make_empty_dict_on_create",       Callable(ContactModelTests, "_t_make_empty_dict_on_create"))
	runner.register_test("contact/validate_passes_for_valid",       Callable(ContactModelTests, "_t_validate_passes_for_valid"))
	runner.register_test("contact/validate_fails_missing_role",     Callable(ContactModelTests, "_t_validate_fails_missing_role"))
	runner.register_test("contact/validate_fails_missing_name",     Callable(ContactModelTests, "_t_validate_fails_missing_name"))
	runner.register_test("contact/valid_roles_contains_five",       Callable(ContactModelTests, "_t_valid_roles_contains_five"))
	runner.register_test("contact/valid_dispositions_contains_six", Callable(ContactModelTests, "_t_valid_dispositions_contains_six"))


# ─── Helpers ─────────────────────────────────────────────────────────────────

static func _make_valid() -> Dictionary:
	return ContactModel.make("c_001", "witness", "Courage", "Wisdom", 10, 60, "bold", "Kofi", 3)


# ─── Test 1 — make() returns a Dictionary ────────────────────────────────────
static func _t_make_returns_dict() -> Dictionary:
	var contact := _make_valid()
	if not contact is Dictionary:
		return { "ok": false, "error": "ContactModel.make() did not return a Dictionary" }
	return { "ok": true }


# ─── Test 2 — All 12 REQUIRED_FIELDS present ─────────────────────────────────
static func _t_make_has_all_required_fields() -> Dictionary:
	var contact := _make_valid()
	for key in ContactModel.REQUIRED_FIELDS:
		if not contact.has(key):
			return { "ok": false, "error": "ContactModel.make() missing required field: %s" % key }
	return { "ok": true }


# ─── Test 3 — state initialised to "pending" ─────────────────────────────────
static func _t_make_sets_initial_state_pending() -> Dictionary:
	var contact := _make_valid()
	if contact.get("state") != "pending":
		return { "ok": false, "error": "Expected state == 'pending', got: %s" % contact.get("state") }
	return { "ok": true }


# ─── Test 4 — turn_current initialised to 0 ──────────────────────────────────
static func _t_make_sets_turn_current_zero() -> Dictionary:
	var contact := _make_valid()
	if contact.get("turn_current") != 0:
		return { "ok": false, "error": "Expected turn_current == 0, got: %s" % contact.get("turn_current") }
	return { "ok": true }


# ─── Test 5 — outcome initialised to "" ──────────────────────────────────────
static func _t_make_sets_empty_outcome() -> Dictionary:
	var contact := _make_valid()
	if contact.get("outcome") != "":
		return { "ok": false, "error": "Expected outcome == '', got: %s" % contact.get("outcome") }
	return { "ok": true }


# ─── Test 6 — echo/speaking/turn arrays initialised to [] ────────────────────
static func _t_make_empty_arrays_on_create() -> Dictionary:
	var contact := _make_valid()
	for key in ["consulted_echo_ids", "speaking_echo_ids", "consulted_ids_this_turn"]:
		if not contact.has(key):
			return { "ok": false, "error": "ContactModel.make() missing array field: %s" % key }
		if not contact[key] is Array:
			return { "ok": false, "error": "Expected '%s' to be Array, got type %s" % [key, typeof(contact[key])] }
		if contact[key].size() != 0:
			return { "ok": false, "error": "Expected '%s' to be empty Array, size was %d" % [key, contact[key].size()] }
	return { "ok": true }


# ─── Test 7 — ignored_bid_counts initialised to {} ───────────────────────────
static func _t_make_empty_dict_on_create() -> Dictionary:
	var contact := _make_valid()
	if not contact.has("ignored_bid_counts"):
		return { "ok": false, "error": "ContactModel.make() missing 'ignored_bid_counts' field" }
	if not contact["ignored_bid_counts"] is Dictionary:
		return { "ok": false, "error": "Expected 'ignored_bid_counts' to be Dictionary" }
	if contact["ignored_bid_counts"].size() != 0:
		return { "ok": false, "error": "Expected 'ignored_bid_counts' to be empty Dictionary" }
	return { "ok": true }


# ─── Test 8 — validate() passes for a valid contact ──────────────────────────
static func _t_validate_passes_for_valid() -> Dictionary:
	var contact := _make_valid()
	if not ContactModel.validate(contact):
		return { "ok": false, "error": "ContactModel.validate() returned false for a valid contact" }
	return { "ok": true }


# ─── Test 9 — validate() fails when role is missing ──────────────────────────
static func _t_validate_fails_missing_role() -> Dictionary:
	var contact := _make_valid()
	contact.erase("role")
	if ContactModel.validate(contact):
		return { "ok": false, "error": "ContactModel.validate() should return false when 'role' is missing" }
	return { "ok": true }


# ─── Test 10 — validate() fails when name is missing ─────────────────────────
static func _t_validate_fails_missing_name() -> Dictionary:
	var contact := _make_valid()
	contact.erase("name")
	if ContactModel.validate(contact):
		return { "ok": false, "error": "ContactModel.validate() should return false when 'name' is missing" }
	return { "ok": true }


# ─── Test 11 — VALID_ROLES has exactly 5 entries ─────────────────────────────
static func _t_valid_roles_contains_five() -> Dictionary:
	var count := ContactModel.VALID_ROLES.size()
	if count != 5:
		return { "ok": false, "error": "Expected VALID_ROLES.size() == 5, got %d" % count }
	return { "ok": true }


# ─── Test 12 — VALID_DISPOSITIONS has exactly 6 entries ──────────────────────
static func _t_valid_dispositions_contains_six() -> Dictionary:
	var count := ContactModel.VALID_DISPOSITIONS.size()
	if count != 6:
		return { "ok": false, "error": "Expected VALID_DISPOSITIONS.size() == 6, got %d" % count }
	return { "ok": true }
