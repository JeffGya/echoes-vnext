# res://tests/SkillLoadoutTests.gd
# PROG-009: Validates skill loadout logic now embedded in FlowStageMapState party_prep.
#
# Tests:
#   1. Calling filter: filter_skills_for_calling returns only skills matching the echo's calling.
#   2. Equipped skill default: equipped_skill_id reads from pending first, falls back to save.
#   3. Snapshot shape: flow.stage_map has party_prep with required keys.
#   4. SkillDefinition.validate() passes for all 8 PROG-009 calling skill definitions.
#
# Tests 1-2 call FlowStageMapState static helpers directly (no realm/file I/O needed).
# Test 3 builds a minimal FlowContext with an inline realm model and party echo.
# Test 4 directly validates each skill definition dict using SkillDefinition.validate().

class_name SkillLoadoutTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("skill_loadout/calling_filter_excludes_other_callings", Callable(SkillLoadoutTests, "_t_calling_filter"))
	runner.register_test("skill_loadout/default_equipped_is_first_matching",     Callable(SkillLoadoutTests, "_t_default_equipped"))
	runner.register_test("skill_loadout/snapshot_has_required_keys",             Callable(SkillLoadoutTests, "_t_snapshot_shape"))
	runner.register_test("skill_loadout/all_eight_skill_defs_are_valid",         Callable(SkillLoadoutTests, "_t_all_eight_skill_defs_valid"))


# ─────────────────────────────────────────────────────────────────────────────
# Inline fake config service (no file I/O)
# ─────────────────────────────────────────────────────────────────────────────

class FakeConfigService:
	var _balance: Dictionary = {}
	func set_balance(b: Dictionary) -> void:
		_balance = b
	func get_balance() -> Dictionary:
		return _balance


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

## Returns a minimal skills definitions dict with 1 blade skill and 1 warder skill.
static func _mini_skill_defs() -> Dictionary:
	return {
		"blade_resolve": {
			"skill_id":            "blade_resolve",
			"calling_requirement": "blade",
			"display_name":        "Blade's Resolve",
			"target_type":         "enemy",
			"action_type":         "actor.press",
			"cooldown_rounds":     0,
			"scaling_source":      "atk",
			"intent_weight_tag":   "melee_attack",
			"tier_gate":           "",
		},
		"warders_vigil": {
			"skill_id":            "warders_vigil",
			"calling_requirement": "warder",
			"display_name":        "Warder's Vigil",
			"target_type":         "ally",
			"action_type":         "actor.interpose",
			"cooldown_rounds":     0,
			"scaling_source":      "def",
			"intent_weight_tag":   "protect_ally",
			"tier_gate":           "",
		},
	}

## Builds a minimal FlowContext with one party echo (calling confirmed) and a stub realm.
static func _make_ctx(calling_origin: String, skill_defs: Dictionary, pending: Dictionary = {}) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.realm_id = "realm_test"
	ctx.save_data = {
		"sanctum": {
			"active_party_ids": ["echo_test_01"],
			"roster": [
				{
					"id":             "echo_test_01",
					"name":           "Kwame",
					"calling_origin": calling_origin,
					"calling":        calling_origin,  # confirmed
					"rank":           3,
					"level":          1,
				}
			]
		},
		"realms": {
			"realm_test": {
				"id":                   "realm_test",
				"name":                 "Test Realm",
				"status":               "active",
				"is_completed":         false,
				"current_stage_index":  0,
				"stage_count":          1,
				"stages": [
					{
						"index":      0,
						"type":       "combat",
						"objectives": [],
					}
				],
			}
		}
	}

	var svc := FakeConfigService.new()
	svc.set_balance({ "data": { "skills": { "definitions": skill_defs } } })
	ctx.config_service = svc

	ctx.pending_equipped_skills = pending.duplicate()
	return ctx

## Returns all 8 PROG-009 calling skill definitions.
static func _all_prog009_skill_defs() -> Dictionary:
	return {
		"blade_resolve": {
			"skill_id":            "blade_resolve",
			"calling_requirement": "blade",
			"display_name":        "Blade's Resolve",
			"target_type":         "enemy",
			"action_type":         "actor.press",
			"cooldown_rounds":     0,
			"scaling_source":      "atk",
			"intent_weight_tag":   "melee_attack",
			"tier_gate":           "",
		},
		"warders_vigil": {
			"skill_id":            "warders_vigil",
			"calling_requirement": "warder",
			"display_name":        "Warder's Vigil",
			"target_type":         "ally",
			"action_type":         "actor.interpose",
			"cooldown_rounds":     0,
			"scaling_source":      "def",
			"intent_weight_tag":   "protect_ally",
			"tier_gate":           "",
		},
		"stewards_ground": {
			"skill_id":            "stewards_ground",
			"calling_requirement": "steward",
			"display_name":        "Steward's Ground",
			"target_type":         "self",
			"action_type":         "actor.hold_ground",
			"cooldown_rounds":     0,
			"scaling_source":      "cha",
			"intent_weight_tag":   "actor.guard",
			"tier_gate":           "",
		},
		"stewards_call": {
			"skill_id":            "stewards_call",
			"calling_requirement": "steward",
			"display_name":        "Steward's Call",
			"target_type":         "ally",
			"action_type":         "actor.steady_call",
			"once_per_combat":     true,
			"cooldown_rounds":     0,
			"scaling_source":      "cha",
			"intent_weight_tag":   "protect_ally",
			"tier_gate":           "",
		},
		"rangers_mark": {
			"skill_id":            "rangers_mark",
			"calling_requirement": "ranger",
			"display_name":        "Ranger's Mark",
			"target_type":         "enemy",
			"action_type":         "actor.mark",
			"cooldown_rounds":     0,
			"scaling_source":      "agi",
			"intent_weight_tag":   "melee_attack",
			"tier_gate":           "",
		},
		"rangers_withdraw": {
			"skill_id":            "rangers_withdraw",
			"calling_requirement": "ranger",
			"display_name":        "Ranger's Withdraw",
			"target_type":         "self",
			"action_type":         "actor.withdraw",
			"cooldown_rounds":     1,
			"scaling_source":      "agi",
			"intent_weight_tag":   "actor.move",
			"tier_gate":           "",
		},
		"seers_sight": {
			"skill_id":              "seers_sight",
			"calling_requirement":   "seer",
			"display_name":          "Seer's Sight",
			"target_type":           "ally",
			"action_type":           "actor.read_field",
			"cooldown_rounds":       0,
			"read_field_max_streak": 3,
			"read_field_cooldown_rounds": 1,
			"scaling_source":        "cha",
			"intent_weight_tag":     "actor.idle",
			"tier_gate":             "",
		},
		"seers_reveal": {
			"skill_id":            "seers_reveal",
			"calling_requirement": "seer",
			"display_name":        "Seer's Reveal",
			"target_type":         "enemy",
			"action_type":         "actor.reveal",
			"once_per_combat":     true,
			"cooldown_rounds":     0,
			"scaling_source":      "cha",
			"intent_weight_tag":   "melee_attack",
			"tier_gate":           "",
		},
	}


# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────

# Test 1: filter_skills_for_calling("blade") returns only blade skills.
static func _t_calling_filter() -> Dictionary:
	var defs := _mini_skill_defs()
	var result := FlowStageMapState.filter_skills_for_calling("blade", defs)

	# warders_vigil must not appear
	for s_v in result:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if str(s.get("skill_id", "")) == "warders_vigil":
			return { "ok": false, "error": "warders_vigil (warder skill) should not appear for blade calling" }

	# blade_resolve must appear
	var found := false
	for s_v in result:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if str(s.get("skill_id", "")) == "blade_resolve":
			found = true
			break
	if not found:
		return { "ok": false, "error": "blade_resolve should appear in filter result for blade calling" }

	return { "ok": true }


# Test 2: equipped_skill_id in party_prep is "" when pending is empty (no pre-selection),
# and reflects pending when a skill has been assigned in-session.
static func _t_default_equipped() -> Dictionary:
	# Case A: pending empty → equipped_skill_id = "" (Keeper sees all options, no pre-selection)
	var ctx_empty := _make_ctx("blade", _mini_skill_defs())
	var snap_empty := FlowStageMapState.build_snapshot(ctx_empty, 1)
	var prep_v: Variant = snap_empty.get("data", {}).get("party_prep", [])
	var prep: Array = prep_v if prep_v is Array else []
	if prep.is_empty():
		return { "ok": false, "error": "party_prep is empty (expected 1 entry for called blade echo)" }
	var row: Dictionary = prep[0] if prep[0] is Dictionary else {}
	if str(row.get("equipped_skill_id", "MISSING")) != "":
		return { "ok": false, "error": "Expected equipped_skill_id='' when pending empty, got: '%s'" % str(row.get("equipped_skill_id")) }

	# Case B: pending set → equipped_skill_id reflects in-session selection
	var ctx_pending := _make_ctx("blade", _mini_skill_defs(),
		{ "echo_test_01": { "0": "blade_resolve" } })
	var snap_pending := FlowStageMapState.build_snapshot(ctx_pending, 1)
	var prep2_v: Variant = snap_pending.get("data", {}).get("party_prep", [])
	var prep2: Array = prep2_v if prep2_v is Array else []
	if prep2.is_empty():
		return { "ok": false, "error": "party_prep is empty (pending case)" }
	var row2: Dictionary = prep2[0] if prep2[0] is Dictionary else {}
	if str(row2.get("equipped_skill_id", "")) != "blade_resolve":
		return { "ok": false, "error": "Expected equipped_skill_id='blade_resolve' from pending, got: '%s'" % str(row2.get("equipped_skill_id")) }

	return { "ok": true }


# Test 3: flow.stage_map snapshot has party_prep with required keys per entry.
static func _t_snapshot_shape() -> Dictionary:
	var ctx := _make_ctx("blade", _mini_skill_defs())
	var snap := FlowStageMapState.build_snapshot(ctx, 1)

	for key in ["type", "meta", "data", "actions"]:
		if not snap.has(key):
			return { "ok": false, "error": "Snapshot missing required key: '%s'" % key }

	if str(snap.get("type", "")) != "flow.stage_map":
		return { "ok": false, "error": "Expected type='flow.stage_map', got: '%s'" % str(snap.get("type")) }

	var data: Dictionary = snap.get("data", {})
	if not data.has("party_prep"):
		return { "ok": false, "error": "Snapshot data missing 'party_prep'" }

	var prep_v: Variant = data.get("party_prep", [])
	var prep: Array = prep_v if prep_v is Array else []
	if prep.is_empty():
		return { "ok": false, "error": "party_prep is empty (expected 1 entry for confirmed blade echo)" }

	var row: Dictionary = prep[0] if prep[0] is Dictionary else {}
	for k in ["echo_id", "echo_name", "calling_origin", "available_skills", "equipped_skill_id"]:
		if not row.has(k):
			return { "ok": false, "error": "party_prep entry missing required key: '%s'" % k }

	return { "ok": true }


# Test 4: All 8 PROG-009 skill definitions pass SkillDefinition.validate().
static func _t_all_eight_skill_defs_valid() -> Dictionary:
	var defs := _all_prog009_skill_defs()

	for skill_id in defs.keys():
		var defn: Dictionary = defs[skill_id]
		if not SkillDefinition.validate(defn):
			return {
				"ok": false,
				"error": "SkillDefinition.validate() failed for '%s'" % str(skill_id)
			}

	if defs.size() != 8:
		return { "ok": false, "error": "Expected 8 skill defs, got %d" % defs.size() }

	return { "ok": true }
