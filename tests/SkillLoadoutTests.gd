# res://tests/SkillLoadoutTests.gd
# V2-PROG-005: Validates skill loadout logic in FlowStageMapState party_prep.
# calling_requirement removed; filter is now family-based.
#
# Tests:
#   1. Family filter: filter_skills_for_calling returns skills in the calling's aligned families.
#   2. Equipped skill default: equipped_skill_id reads from pending first, falls back to empty.
#   3. Snapshot shape: flow.stage_map has party_prep with required keys incl. calling_families.
#   4. SkillDefinition.validate() passes for all 8 V2-PROG-005 skill definitions.
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

## Returns the canonical calling_family_alignment config used in tests.
static func _families_cfg() -> Dictionary:
	return {
		"calling_family_alignment": {
			"okofor":      { "strong": ["ward", "root"],  "light": ["break"] },
			"aduro":       { "strong": ["break", "ward"], "light": ["veil"] },
			"sum_okwanfo": { "strong": ["veil", "break"], "light": ["path"] },
			"kra_soro":    { "strong": ["path", "veil"],  "light": ["rite"] },
			"okomfo":      { "strong": ["rite", "path"],  "light": ["root"] },
			"onyamesu":    { "strong": ["root", "ward"],  "light": ["rite"] },
		}
	}

## Returns a minimal skills definitions dict — one break skill (aduro strong) and one ward skill (aduro strong).
## V2-PROG-005: calling_requirement removed; skill_family is the axis.
static func _mini_skill_defs() -> Dictionary:
	return {
		"blade_resolve": {
			"skill_id":          "blade_resolve",
			"skill_family":      "break",
			"display_name":      "Blade's Resolve",
			"target_type":       "enemy",
			"action_type":       "actor.press",
			"cooldown_rounds":   0,
			"scaling_source":    "atk",
			"intent_weight_tag": "melee_attack",
			"tier_gate":         "",
		},
		"warders_vigil": {
			"skill_id":          "warders_vigil",
			"skill_family":      "ward",
			"display_name":      "Warder's Vigil",
			"target_type":       "ally",
			"action_type":       "actor.interpose",
			"cooldown_rounds":   0,
			"scaling_source":    "def",
			"intent_weight_tag": "protect_ally",
			"tier_gate":         "",
		},
		"rangers_mark": {
			"skill_id":          "rangers_mark",
			"skill_family":      "path",
			"display_name":      "Ranger's Mark",
			"target_type":       "enemy",
			"action_type":       "actor.mark",
			"cooldown_rounds":   0,
			"scaling_source":    "agi",
			"intent_weight_tag": "melee_attack",
			"tier_gate":         "",
		},
	}

## Builds a minimal FlowContext with one party echo (calling confirmed) and a stub realm.
static func _make_ctx(calling_id: String, skill_defs: Dictionary, pending: Dictionary = {}) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.realm_id = "realm_test"
	ctx.save_data = {
		"sanctum": {
			"active_party_ids": ["echo_test_01"],
			"roster": [
				{
					"id":             "echo_test_01",
					"name":           "Kwame",
					"calling_origin": calling_id,
					"calling":        calling_id,  # confirmed
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
	# Embed families_cfg alongside definitions so build_snapshot can load both
	var skills_block := _families_cfg().duplicate()
	skills_block["definitions"] = skill_defs
	svc.set_balance({ "data": { "skills": skills_block } })
	ctx.config_service = svc

	ctx.pending_equipped_skills = pending.duplicate()
	return ctx

## Returns all 8 V2-PROG-005 skill definitions (calling_requirement removed; skill_family added).
static func _all_eight_skill_defs() -> Dictionary:
	return {
		"blade_resolve": {
			"skill_id":          "blade_resolve",
			"skill_family":      "break",
			"display_name":      "Blade's Resolve",
			"target_type":       "enemy",
			"action_type":       "actor.press",
			"cooldown_rounds":   0,
			"scaling_source":    "atk",
			"intent_weight_tag": "melee_attack",
			"tier_gate":         "",
		},
		"warders_vigil": {
			"skill_id":          "warders_vigil",
			"skill_family":      "ward",
			"display_name":      "Warder's Vigil",
			"target_type":       "ally",
			"action_type":       "actor.interpose",
			"cooldown_rounds":   0,
			"scaling_source":    "def",
			"intent_weight_tag": "protect_ally",
			"tier_gate":         "",
		},
		"stewards_ground": {
			"skill_id":          "stewards_ground",
			"skill_family":      "ward",
			"display_name":      "Steward's Ground",
			"target_type":       "area",
			"action_type":       "actor.hold_ground",
			"cooldown_rounds":   0,
			"scaling_source":    "cha",
			"intent_weight_tag": "actor.guard",
			"tier_gate":         "",
		},
		"stewards_call": {
			"skill_id":          "stewards_call",
			"skill_family":      "root",
			"display_name":      "Steward's Call",
			"target_type":       "area",
			"action_type":       "actor.steady_call",
			"once_per_combat":   true,
			"cooldown_rounds":   0,
			"scaling_source":    "cha",
			"intent_weight_tag": "protect_ally",
			"tier_gate":         "",
		},
		"rangers_mark": {
			"skill_id":          "rangers_mark",
			"skill_family":      "path",
			"display_name":      "Ranger's Mark",
			"target_type":       "enemy",
			"action_type":       "actor.mark",
			"cooldown_rounds":   0,
			"scaling_source":    "agi",
			"intent_weight_tag": "melee_attack",
			"tier_gate":         "",
		},
		"rangers_withdraw": {
			"skill_id":          "rangers_withdraw",
			"skill_family":      "veil",
			"display_name":      "Ranger's Withdraw",
			"target_type":       "self",
			"action_type":       "actor.withdraw",
			"cooldown_rounds":   1,
			"scaling_source":    "agi",
			"intent_weight_tag": "actor.move",
			"tier_gate":         "",
		},
		"seers_sight": {
			"skill_id":                   "seers_sight",
			"skill_family":               "rite",
			"display_name":               "Seer's Sight",
			"target_type":                "area",
			"action_type":                "actor.read_field",
			"cooldown_rounds":            0,
			"read_field_max_streak":      3,
			"read_field_cooldown_rounds": 1,
			"scaling_source":             "cha",
			"intent_weight_tag":          "actor.idle",
			"tier_gate":                  "",
		},
		"seers_reveal": {
			"skill_id":          "seers_reveal",
			"skill_family":      "rite",
			"display_name":      "Seer's Reveal",
			"target_type":       "enemy",
			"action_type":       "actor.reveal",
			"once_per_combat":   true,
			"cooldown_rounds":   0,
			"scaling_source":    "cha",
			"intent_weight_tag": "melee_attack",
			"tier_gate":         "",
		},
	}


# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────

# Test 1: Family filter — aduro (strong: break, ward; light: veil) gets break + ward skills.
# rangers_mark (path family) must NOT appear for aduro.
static func _t_calling_filter() -> Dictionary:
	var defs      := _mini_skill_defs()
	var fam_cfg   := _families_cfg()
	var result    := FlowStageMapState.filter_skills_for_calling("aduro", defs, fam_cfg)

	# rangers_mark (path) must not appear — path is not in aduro's families
	for s_v in result:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if str(s.get("skill_id", "")) == "rangers_mark":
			return { "ok": false, "error": "rangers_mark (path) should not appear for aduro calling" }

	# blade_resolve (break) must appear — break is aduro strong
	var found_blade := false
	for s_v in result:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if str(s.get("skill_id", "")) == "blade_resolve":
			found_blade = true
			if str(s.get("family_alignment", "")) != "strong":
				return { "ok": false, "error": "blade_resolve should have family_alignment='strong' for aduro" }

	if not found_blade:
		return { "ok": false, "error": "blade_resolve (break, aduro strong) should appear for aduro calling" }

	# warders_vigil (ward) must appear — ward is aduro strong
	var found_ward := false
	for s_v in result:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if str(s.get("skill_id", "")) == "warders_vigil":
			found_ward = true
	if not found_ward:
		return { "ok": false, "error": "warders_vigil (ward, aduro strong) should appear for aduro calling" }

	return { "ok": true }


# Test 2: equipped_skill_id in party_prep is "" when pending is empty,
# and reflects pending when a skill has been assigned in-session.
static func _t_default_equipped() -> Dictionary:
	# Case A: pending empty → equipped_skill_id = ""
	var ctx_empty := _make_ctx("aduro", _mini_skill_defs())
	var snap_empty := FlowStageMapState.build_snapshot(ctx_empty, 1)
	var prep_v: Variant = snap_empty.get("data", {}).get("party_prep", [])
	var prep: Array = prep_v if prep_v is Array else []
	if prep.is_empty():
		return { "ok": false, "error": "party_prep is empty (expected 1 entry for called aduro echo)" }
	var row: Dictionary = prep[0] if prep[0] is Dictionary else {}
	if str(row.get("equipped_skill_id", "MISSING")) != "":
		return { "ok": false, "error": "Expected equipped_skill_id='' when pending empty, got: '%s'" % str(row.get("equipped_skill_id")) }

	# Case B: pending set → equipped_skill_id reflects in-session selection
	var ctx_pending := _make_ctx("aduro", _mini_skill_defs(),
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


# Test 3: flow.stage_map snapshot has party_prep with all required V2-PROG-005 keys.
static func _t_snapshot_shape() -> Dictionary:
	var ctx  := _make_ctx("aduro", _mini_skill_defs())
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
		return { "ok": false, "error": "party_prep is empty (expected 1 entry for confirmed aduro echo)" }

	var row: Dictionary = prep[0] if prep[0] is Dictionary else {}
	# V2-PROG-005: calling_id (not calling_origin); calling_families added
	for k in ["echo_id", "echo_name", "calling_id", "calling_families", "available_skills", "equipped_skill_id"]:
		if not row.has(k):
			return { "ok": false, "error": "party_prep entry missing required key: '%s'" % k }

	# Verify calling_families shape
	var cf_v: Variant = row.get("calling_families", {})
	var cf: Dictionary = cf_v if cf_v is Dictionary else {}
	if not cf.has("strong") or not cf.has("light"):
		return { "ok": false, "error": "calling_families must have 'strong' and 'light' keys" }

	# Verify available_skills entries carry skill_family and family_alignment
	var skills_v: Variant = row.get("available_skills", [])
	var skills: Array = skills_v if skills_v is Array else []
	for sv in skills:
		var s: Dictionary = sv if sv is Dictionary else {}
		for k in ["skill_id", "display_name", "action_type", "skill_family", "family_alignment"]:
			if not s.has(k):
				return { "ok": false, "error": "available_skills entry missing key: '%s'" % k }

	return { "ok": true }


# Test 4: All 8 V2-PROG-005 skill definitions pass SkillDefinition.validate().
static func _t_all_eight_skill_defs_valid() -> Dictionary:
	var defs := _all_eight_skill_defs()

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
