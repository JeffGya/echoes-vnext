# res://tests/SkillUnlockTests.gd
# V2-PROG-009: Tests for skill unlock loop, constellation data, save repair, and party toggle fix.
#
# T1: All skill definitions in balance.json have unlock_conditions + type + description.
# T2: _build_skill_entries_for_echo returns ward/root/break entries for okofor (not path/veil).
# T3: Uncalled echo (calling="") returns [] — no calling_origin fallback.
# T4: SaveService repairs unlocked_skills:[] on echoes that lack the field.
# T5: sanctum.unlock_skill spends 40 Ase and writes skill_id to unlocked_skills.
# T6: sanctum.unlock_skill denied when skill already in unlocked_skills.
# T7: sanctum.unlock_skill denied when echo has no confirmed calling.
# T8: sanctum.party.toggle works from flow.sanctum without navigating to echo_party.

class_name SkillUnlockTests
extends RefCounted


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("skill_unlock/all_defs_have_unlock_conditions",     Callable(SkillUnlockTests, "_t_unlock_conditions_on_all_definitions"))
	runner.register_test("skill_unlock/okofor_families_present",             Callable(SkillUnlockTests, "_t_skill_families_for_okofor"))
	runner.register_test("skill_unlock/uncalled_echo_returns_empty",         Callable(SkillUnlockTests, "_t_uncalled_echo_returns_empty"))
	runner.register_test("skill_unlock/unlocked_skills_repaired",            Callable(SkillUnlockTests, "_t_unlocked_skills_after_repair"))
	runner.register_test("skill_unlock/unlock_spends_ase_and_writes",        Callable(SkillUnlockTests, "_t_unlock_skill_spends_ase"))
	runner.register_test("skill_unlock/unlock_denied_when_already_done",     Callable(SkillUnlockTests, "_t_unlock_denied_when_already_unlocked"))
	runner.register_test("skill_unlock/unlock_denied_when_uncalled",         Callable(SkillUnlockTests, "_t_unlock_denied_when_uncalled"))
	runner.register_test("skill_unlock/unlock_denied_wrong_family",          Callable(SkillUnlockTests, "_t_unlock_denied_wrong_family"))
	runner.register_test("skill_unlock/party_toggle_works_from_sanctum",     Callable(SkillUnlockTests, "_t_party_toggle_from_sanctum"))
	runner.register_test("skill_unlock/party_prep_filters_to_unlocked_only", Callable(SkillUnlockTests, "_t_party_prep_only_shows_unlocked_skills"))
	runner.register_test("skill_unlock/unlock_keeps_sanctum_projection",     Callable(SkillUnlockTests, "_t_unlock_keeps_sanctum_projection"))
	runner.register_test("skill_unlock/toggle_keeps_sanctum_projection",     Callable(SkillUnlockTests, "_t_toggle_keeps_sanctum_projection"))


# ---------------------------------------------------------------------------
# T1: All skill definitions in balance.json have unlock_conditions, type, description
# ---------------------------------------------------------------------------

static func _t_unlock_conditions_on_all_definitions() -> Dictionary:
	var f := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if f == null:
		return { "ok": false, "error": "Cannot open res://data/balance.json" }
	var raw := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return { "ok": false, "error": "Failed to parse balance.json as Dictionary" }

	var data_v: Variant = (parsed as Dictionary).get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var skills_v: Variant = data.get("skills", {})
	var skills: Dictionary = skills_v if skills_v is Dictionary else {}
	var defs_v: Variant = skills.get("definitions", {})
	var defs: Dictionary = defs_v if defs_v is Dictionary else {}

	if defs.is_empty():
		return { "ok": false, "error": "data.skills.definitions is empty in balance.json" }

	var uc_required: Array = ["min_standing", "storyweight_threshold", "ase_cost", "lived_condition"]

	for skill_id in defs:
		var defn_v: Variant = defs[skill_id]
		if not (defn_v is Dictionary):
			return { "ok": false, "error": "Definition for '%s' is not a Dictionary" % skill_id }
		var defn: Dictionary = defn_v as Dictionary

		if not defn.has("type") or not (defn["type"] is String):
			return { "ok": false, "error": "'%s' missing required string field 'type'" % skill_id }
		if not defn.has("description") or not (defn["description"] is String):
			return { "ok": false, "error": "'%s' missing required string field 'description'" % skill_id }
		if not defn.has("unlock_conditions") or not (defn["unlock_conditions"] is Dictionary):
			return { "ok": false, "error": "'%s' missing 'unlock_conditions' Dictionary" % skill_id }

		var uc: Dictionary = defn["unlock_conditions"] as Dictionary
		for key in uc_required:
			if not uc.has(key):
				return { "ok": false, "error": "'%s'.unlock_conditions missing key '%s'" % [skill_id, key] }

	return { "ok": true }


# ---------------------------------------------------------------------------
# T2: _build_skill_entries_for_echo returns ward/root/break for okofor
# ---------------------------------------------------------------------------

static func _t_skill_families_for_okofor() -> Dictionary:
	var cfg_result := _load_real_skills_cfg()
	if not bool(cfg_result.get("ok", false)):
		return cfg_result

	var skills_cfg: Dictionary = cfg_result["skills_cfg"] as Dictionary
	var echo := {
		"calling":         "okofor",
		"calling_origin":  "",
		"unlocked_skills": [],
	}

	var entries: Array = FlowSanctumState._build_skill_entries_for_echo(echo, skills_cfg, 100)

	if entries.is_empty():
		return { "ok": false, "error": "Expected skill entries for called okofor echo, got empty Array" }

	var families: Array = []
	for e_v in entries:
		if not (e_v is Dictionary):
			continue
		var fam := str((e_v as Dictionary).get("family_id", ""))
		if not fam.is_empty() and not families.has(fam):
			families.append(fam)

	for expected_fam in ["ward", "root", "break"]:
		if not families.has(expected_fam):
			return {
				"ok":    false,
				"error": "Expected family '%s' in okofor entries. Found: %s" % [expected_fam, str(families)],
			}

	for unexpected_fam in ["path", "veil", "rite"]:
		if families.has(unexpected_fam):
			return {
				"ok":    false,
				"error": "Family '%s' should NOT appear for okofor (only ward/root/break)" % unexpected_fam,
			}

	return { "ok": true }


# ---------------------------------------------------------------------------
# T3: Uncalled echo returns [] — calling_origin must not be used as fallback
# ---------------------------------------------------------------------------

static func _t_uncalled_echo_returns_empty() -> Dictionary:
	var cfg_result := _load_real_skills_cfg()
	if not bool(cfg_result.get("ok", false)):
		return cfg_result

	var skills_cfg: Dictionary = cfg_result["skills_cfg"] as Dictionary
	var echo := {
		"calling":         "",
		"calling_origin":  "aduro",   # must NOT be used as a fallback
		"unlocked_skills": [],
	}

	var entries: Array = FlowSanctumState._build_skill_entries_for_echo(echo, skills_cfg, 0)

	if not entries.is_empty():
		return {
			"ok":    false,
			"error": "Expected [] for uncalled echo (calling=''), got %d entries — calling_origin must not be a fallback" % entries.size(),
		}

	return { "ok": true }


# ---------------------------------------------------------------------------
# T4: SaveService repairs unlocked_skills:[] on echoes that lack the field
# ---------------------------------------------------------------------------

static func _t_unlocked_skills_after_repair() -> Dictionary:
	var logger := _make_logger()

	var save: Dictionary = {
		"schema_version":  1,
		"first_boot":      false,
		"meta": {
			"created_at_unix":   1000000,
			"last_saved_at_unix": 1000000,
			"app_version":       "vNext-test",
		},
		"campaign": {
			"root_seed":   1,
			"tick":        0,
			"seed_root":   "test:1",
			"seed_source": "test",
		},
		"flow": { "state": "flow.sanctum", "context": {} },
		"economy": {
			"ase":               0,
			"ekwan":             0,
			"last_settle_unix":  1000000,
			"last_offline_unix": 1000000,
		},
		"sanctum": {
			"ase": 0,
			"roster": [
				{
					"id":            "echo_repair_test",
					"name":          "Repair Echo",
					"calling":       "",
					"rank":          1,
					"level":         1,
					"xp_total":      0,
					"traits":        {},
					"archetype":     "wanderer",
					"emotion":       { "morale": 70, "fear": 0 },
					# unlocked_skills intentionally absent — repair must add it
				}
			],
			"active_party_ids": [],
			"name":              "Test Sanctum",
			"continuity":        0,
			"rejection_counts":  {},
		},
		"stage_context": {},
	}

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after repair" }

	var echo_v: Variant = roster[0]
	if not (echo_v is Dictionary):
		return { "ok": false, "error": "roster[0] is not a Dictionary after repair" }
	var echo: Dictionary = echo_v as Dictionary

	if not echo.has("unlocked_skills"):
		return { "ok": false, "error": "repair did not add 'unlocked_skills' to echo" }

	var ul_v: Variant = echo["unlocked_skills"]
	if not (ul_v is Array):
		return { "ok": false, "error": "unlocked_skills is not an Array after repair" }

	if not (ul_v as Array).is_empty():
		return { "ok": false, "error": "unlocked_skills should default to [], got: %s" % str(ul_v) }

	return { "ok": true }


# ---------------------------------------------------------------------------
# T5: sanctum.unlock_skill spends 40 Ase and writes skill_id to unlocked_skills
# ---------------------------------------------------------------------------

static func _t_unlock_skill_spends_ase() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var save: Dictionary = runtime.get_save_data()
	var roster := _get_roster(save)
	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot" }

	var echo := _first_echo(roster)
	if echo.is_empty():
		return { "ok": false, "error": "roster[0] is not a Dictionary" }

	echo["calling"]         = "okofor"
	echo["unlocked_skills"] = []
	var echo_id := str(echo.get("id", ""))

	# Set Ase to 100 and stamp last_settle_unix to now to suppress internal settle
	var econ := _get_economy(save)
	econ["ase"]              = 100
	econ["last_settle_unix"] = int(Time.get_unix_time_from_system())

	runtime.dispatch({
		"type":    "sanctum.unlock_skill",
		"payload": { "echo_id": echo_id, "skill_id": "warders_vigil" },
	})

	var save_after: Dictionary = runtime.get_save_data()
	var echo_after := _find_echo(save_after, echo_id)
	if echo_after.is_empty():
		return { "ok": false, "error": "Echo not found in roster after unlock (id=%s)" % echo_id }

	var ul_v: Variant = echo_after.get("unlocked_skills", [])
	var ul: Array = ul_v if ul_v is Array else []
	if not ul.has("warders_vigil"):
		return { "ok": false, "error": "warders_vigil not in unlocked_skills after unlock. Got: %s" % str(ul) }

	var econ_after := _get_economy(save_after)
	var ase_after := int(econ_after.get("ase", -1))
	if ase_after != 60:
		return {
			"ok":    false,
			"error": "Expected ase=60 after spending 40 from 100, got %d" % ase_after,
		}

	return { "ok": true }


# ---------------------------------------------------------------------------
# T6: sanctum.unlock_skill denied when skill already in unlocked_skills
# ---------------------------------------------------------------------------

static func _t_unlock_denied_when_already_unlocked() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var save: Dictionary = runtime.get_save_data()
	var roster := _get_roster(save)
	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot" }

	var echo := _first_echo(roster)
	if echo.is_empty():
		return { "ok": false, "error": "roster[0] is not a Dictionary" }

	echo["calling"]         = "okofor"
	echo["unlocked_skills"] = ["warders_vigil"]   # already unlocked
	var echo_id := str(echo.get("id", ""))

	var econ := _get_economy(save)
	econ["ase"]              = 100
	econ["last_settle_unix"] = int(Time.get_unix_time_from_system())

	runtime.dispatch({
		"type":    "sanctum.unlock_skill",
		"payload": { "echo_id": echo_id, "skill_id": "warders_vigil" },
	})

	var save_after: Dictionary = runtime.get_save_data()
	var econ_after := _get_economy(save_after)
	var ase_after := int(econ_after.get("ase", -1))
	if ase_after != 100:
		return {
			"ok":    false,
			"error": "Ase should be unchanged when skill already unlocked. Expected 100, got %d" % ase_after,
		}

	var echo_after := _find_echo(save_after, echo_id)
	var ul_v: Variant = echo_after.get("unlocked_skills", [])
	var ul: Array = ul_v if ul_v is Array else []
	if ul.count("warders_vigil") > 1:
		return {
			"ok":    false,
			"error": "'warders_vigil' appears %d times — duplicate unlock not prevented" % ul.count("warders_vigil"),
		}

	return { "ok": true }


# ---------------------------------------------------------------------------
# T7: sanctum.unlock_skill denied when echo has no confirmed calling
# ---------------------------------------------------------------------------

## T7b: sanctum.unlock_skill denied when skill family is not accessible for calling.
## okofor (ward/root strong, break light) must not unlock a path family skill.
static func _t_unlock_denied_wrong_family() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var save: Dictionary = runtime.get_save_data()
	var roster := _get_roster(save)
	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot" }

	var echo := _first_echo(roster)
	if echo.is_empty():
		return { "ok": false, "error": "roster[0] is not a Dictionary" }

	echo["calling"]         = "okofor"   # okofor: strong=ward/root, light=break — path is inaccessible
	echo["unlocked_skills"] = []
	var echo_id := str(echo.get("id", ""))

	var econ := _get_economy(save)
	econ["ase"]              = 100
	econ["last_settle_unix"] = int(Time.get_unix_time_from_system())

	# rangers_mark has skill_family=path — NOT in okofor's families
	runtime.dispatch({
		"type":    "sanctum.unlock_skill",
		"payload": { "echo_id": echo_id, "skill_id": "rangers_mark" },
	})

	var save_after: Dictionary = runtime.get_save_data()
	var econ_after := _get_economy(save_after)
	var ase_after := int(econ_after.get("ase", -1))
	if ase_after != 100:
		return {
			"ok":    false,
			"error": "Ase should be unchanged when skill family is inaccessible. Expected 100, got %d" % ase_after,
		}

	var echo_after := _find_echo(save_after, echo_id)
	var ul_v: Variant = echo_after.get("unlocked_skills", [])
	var ul: Array = ul_v if ul_v is Array else []
	if ul.has("rangers_mark"):
		return { "ok": false, "error": "rangers_mark (path) should not be unlockable for okofor calling" }

	return { "ok": true }


static func _t_unlock_denied_when_uncalled() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var save: Dictionary = runtime.get_save_data()
	var roster := _get_roster(save)
	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot" }

	var echo := _first_echo(roster)
	if echo.is_empty():
		return { "ok": false, "error": "roster[0] is not a Dictionary" }

	echo["calling"]         = ""   # uncalled
	echo["unlocked_skills"] = []
	var echo_id := str(echo.get("id", ""))

	var econ := _get_economy(save)
	econ["ase"]              = 100
	econ["last_settle_unix"] = int(Time.get_unix_time_from_system())

	runtime.dispatch({
		"type":    "sanctum.unlock_skill",
		"payload": { "echo_id": echo_id, "skill_id": "warders_vigil" },
	})

	var save_after: Dictionary = runtime.get_save_data()
	var econ_after := _get_economy(save_after)
	var ase_after := int(econ_after.get("ase", -1))
	if ase_after != 100:
		return {
			"ok":    false,
			"error": "Ase should not change for uncalled echo. Expected 100, got %d" % ase_after,
		}

	return { "ok": true }


# ---------------------------------------------------------------------------
# T8: sanctum.party.toggle works from flow.sanctum (not echo_party)
# ---------------------------------------------------------------------------

static func _t_party_toggle_from_sanctum() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	# Runtime starts at flow.sanctum after boot — do NOT navigate to echo_party
	var save: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}

	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot" }

	# Pick an echo not already in the active party
	var current_active_v: Variant = sanctum.get("active_party_ids", [])
	var current_active: Array = current_active_v if current_active_v is Array else []
	var echo_id := ""
	for e_v in roster:
		if not (e_v is Dictionary):
			continue
		var eid := str((e_v as Dictionary).get("id", ""))
		if not eid.is_empty() and not current_active.has(eid):
			echo_id = eid
			break

	if echo_id.is_empty():
		return { "ok": false, "error": "No roster echo outside active_party_ids — cannot test add-toggle" }

	var snap: Dictionary = runtime.dispatch({
		"type":    "sanctum.party.toggle",
		"payload": { "echo_id": echo_id },
	})

	var snap_type := str(snap.get("type", ""))
	if snap_type != "flow.sanctum":
		return {
			"ok":    false,
			"error": "Snapshot type should remain 'flow.sanctum' after toggle. Got '%s'" % snap_type,
		}

	var save_after: Dictionary = runtime.get_save_data()
	var sanctum_after_v: Variant = save_after.get("sanctum", {})
	var sanctum_after: Dictionary = sanctum_after_v if sanctum_after_v is Dictionary else {}
	var active_v: Variant = sanctum_after.get("active_party_ids", [])
	var active: Array = active_v if active_v is Array else []
	if not active.has(echo_id):
		return {
			"ok":    false,
			"error": "active_party_ids does not contain echo_id=%s after toggle from flow.sanctum" % echo_id,
		}

	return { "ok": true }


# ---------------------------------------------------------------------------
# T9: party_prep available_skills filters to unlocked skills only
# ---------------------------------------------------------------------------
# Verifies the PROG-009 fix: filter_skills_for_calling returns ALL calling-accessible
# skills, but build_snapshot must apply a second filter so only skills in echo.unlocked_skills
# appear in party_prep. Tests both the positive case (one unlocked skill) and the negative
# (no unlocked skills → empty list + has_unlocked_skills:false).

static func _t_party_prep_only_shows_unlocked_skills() -> Dictionary:
	var cfg_result := _load_real_skills_cfg()
	if not bool(cfg_result.get("ok", false)):
		return cfg_result

	var skills_cfg: Dictionary = cfg_result["skills_cfg"] as Dictionary
	var defs_v: Variant = skills_cfg.get("definitions", {})
	var skill_defs: Dictionary = defs_v if defs_v is Dictionary else {}

	if skill_defs.is_empty():
		return { "ok": false, "error": "skills.definitions is empty — cannot build test" }

	# --- Positive case: okofor echo with one unlocked skill ---
	var all_accessible: Array = FlowStageMapState.filter_skills_for_calling("okofor", skill_defs, skills_cfg)
	if all_accessible.is_empty():
		return { "ok": false, "error": "filter_skills_for_calling returned [] for okofor — check balance.json" }

	# Pick the first accessible skill as the "unlocked" one
	var target_skill := str((all_accessible[0] as Dictionary).get("skill_id", ""))
	if target_skill.is_empty():
		return { "ok": false, "error": "First accessible skill has empty skill_id" }

	var unlocked_ids: Array = [target_skill]
	var filtered_positive: Array = all_accessible.filter(
		func(s: Dictionary) -> bool: return unlocked_ids.has(str(s.get("skill_id", "")))
	)

	if filtered_positive.size() != 1:
		return {
			"ok":    false,
			"error": "Expected 1 skill after filtering to unlocked=[%s], got %d" % [target_skill, filtered_positive.size()],
		}
	if str((filtered_positive[0] as Dictionary).get("skill_id", "")) != target_skill:
		return {
			"ok":    false,
			"error": "Filtered skill_id mismatch. Expected '%s', got '%s'" % [target_skill, (filtered_positive[0] as Dictionary).get("skill_id", "")],
		}

	# --- Negative case: no unlocked skills → empty ---
	var filtered_negative: Array = all_accessible.filter(
		func(s: Dictionary) -> bool: return [].has(str(s.get("skill_id", "")))
	)
	if not filtered_negative.is_empty():
		return {
			"ok":    false,
			"error": "Expected empty Array when unlocked_skills=[], got %d entries" % filtered_negative.size(),
		}

	# --- has_unlocked_skills flag ---
	var has_positive: bool = not filtered_positive.is_empty()   # should be true
	var has_negative: bool = not filtered_negative.is_empty()   # should be false

	if not has_positive:
		return { "ok": false, "error": "has_unlocked_skills should be true when one skill is unlocked" }
	if has_negative:
		return { "ok": false, "error": "has_unlocked_skills should be false when unlocked_skills=[]" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Loads ConfigService and returns { "ok": true, "skills_cfg": Dictionary }
## V2-PROG-009 fix: load_balance() must be called explicitly; ConfigService.new() does not auto-load.
# ---------------------------------------------------------------------------
# T10 / T11: Sanctum snapshot projection survives reenter()
# ---------------------------------------------------------------------------
# Regression guard. ase_balance, sanctum_name and party_slots are produced ONLY by
# FlowStateMachine._rebuild_snapshot()'s Sanctum enrichment block — FlowSanctumState.enter()
# does not build them. reenter() re-runs enter() and REPLACES last_snapshot wholesale, so any
# handler that calls reenter() without a following refresh_snapshot() emits a snapshot missing
# all three. The UI then renders 0 Ase, no house name, and "No departure party is set."
# while the save itself is intact.
#
# Both handlers below previously called reenter() bare. The assertion is snapshot-vs-save:
# the projection must agree with authoritative save data after the dispatch.


# Asserts the emitted Sanctum snapshot projects the authoritative save state.
static func _assert_sanctum_projection(snap: Dictionary, save: Dictionary, label: String) -> Dictionary:
	var snap_type := str(snap.get("type", ""))
	if snap_type != "flow.sanctum":
		return { "ok": false, "error": "%s: expected type 'flow.sanctum', got '%s'" % [label, snap_type] }

	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var econ_v: Variant = save.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}

	if not data.has("ase_balance"):
		return { "ok": false, "error": "%s: snapshot data is missing 'ase_balance' (enrichment block did not run)" % label }
	var want_ase := int(econ.get("ase", 0))
	var got_ase := int(data.get("ase_balance", -1))
	if got_ase != want_ase:
		return { "ok": false, "error": "%s: ase_balance %d does not match save ase %d" % [label, got_ase, want_ase] }

	if not data.has("sanctum_name"):
		return { "ok": false, "error": "%s: snapshot data is missing 'sanctum_name' (enrichment block did not run)" % label }
	var want_name := str(sanctum.get("name", ""))
	var got_name := str(data.get("sanctum_name", ""))
	if got_name != want_name:
		return { "ok": false, "error": "%s: sanctum_name '%s' does not match save name '%s'" % [label, got_name, want_name] }

	if not data.has("party_slots"):
		return { "ok": false, "error": "%s: snapshot data is missing 'party_slots' (enrichment block did not run)" % label }
	var active_v: Variant = sanctum.get("active_party_ids", [])
	var active: Array = active_v if active_v is Array else []
	var slots_v: Variant = data.get("party_slots", [])
	var slots: Array = slots_v if slots_v is Array else []
	if slots.size() != active.size():
		return {
			"ok": false,
			"error": "%s: party_slots size %d does not match active_party_ids size %d" % [label, slots.size(), active.size()],
		}

	return { "ok": true }


# T10: sanctum.unlock_skill must not strip the Sanctum projection.
static func _t_unlock_keeps_sanctum_projection() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var save: Dictionary = runtime.get_save_data()
	var roster := _get_roster(save)
	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot" }

	var echo := _first_echo(roster)
	if echo.is_empty():
		return { "ok": false, "error": "roster[0] is not a Dictionary" }

	echo["calling"]         = "okofor"
	echo["unlocked_skills"] = []
	var echo_id := str(echo.get("id", ""))

	# Give the house a name and a departure party so an empty projection is unambiguous.
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	sanctum["name"]             = "Test House"
	sanctum["active_party_ids"] = [echo_id]

	# Set balance directly and stamp last_settle_unix to suppress internal settle drift.
	var econ := _get_economy(save)
	econ["ase"]              = 100
	econ["last_settle_unix"] = int(Time.get_unix_time_from_system())

	var snap: Dictionary = runtime.dispatch({
		"type":    "sanctum.unlock_skill",
		"payload": { "echo_id": echo_id, "skill_id": "warders_vigil" },
	})

	# Sanity: the unlock must actually have happened, otherwise the projection check is vacuous.
	var save_after: Dictionary = runtime.get_save_data()
	var echo_after := _find_echo(save_after, echo_id)
	var ul_v: Variant = echo_after.get("unlocked_skills", [])
	var ul: Array = ul_v if ul_v is Array else []
	if not ul.has("warders_vigil"):
		return { "ok": false, "error": "Precondition failed: skill was not unlocked, so projection check is vacuous" }

	return _assert_sanctum_projection(snap, save_after, "after sanctum.unlock_skill")


# T11: sanctum.party.toggle from flow.sanctum must not strip the Sanctum projection.
static func _t_toggle_keeps_sanctum_projection() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var save: Dictionary = runtime.get_save_data()
	var roster := _get_roster(save)
	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot" }

	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	sanctum["name"] = "Test House"

	# Start from an empty party and add one echo, so party_slots must become non-empty.
	sanctum["active_party_ids"] = []
	var echo := _first_echo(roster)
	if echo.is_empty():
		return { "ok": false, "error": "roster[0] is not a Dictionary" }
	var echo_id := str(echo.get("id", ""))

	var econ := _get_economy(save)
	econ["last_settle_unix"] = int(Time.get_unix_time_from_system())

	var snap: Dictionary = runtime.dispatch({
		"type":    "sanctum.party.toggle",
		"payload": { "echo_id": echo_id },
	})

	var save_after: Dictionary = runtime.get_save_data()
	var sanctum_after_v: Variant = save_after.get("sanctum", {})
	var sanctum_after: Dictionary = sanctum_after_v if sanctum_after_v is Dictionary else {}
	var active_v: Variant = sanctum_after.get("active_party_ids", [])
	var active: Array = active_v if active_v is Array else []
	if not active.has(echo_id):
		return { "ok": false, "error": "Precondition failed: toggle did not add echo to party, projection check is vacuous" }

	return _assert_sanctum_projection(snap, save_after, "after sanctum.party.toggle")


static func _load_real_skills_cfg() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()   # required — _balance is {} until this is called
	var balance := config.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var skills_v: Variant = data.get("skills", {})
	if not (skills_v is Dictionary):
		return { "ok": false, "error": "data.skills is not a Dictionary in balance.json" }
	return { "ok": true, "skills_cfg": skills_v as Dictionary }


static func _make_logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level("off")
	return l


static func _make_runtime_env() -> Dictionary:
	var FlowRuntimeScript := load("res://core/runtime/FlowRuntime.gd")
	var ConfigServiceScript := load("res://core/config/ConfigService.gd")
	var StructuredLoggerScript := load("res://core/log/StructuredLogger.gd")

	if FlowRuntimeScript == null:
		return { "ok": false, "error": "FlowRuntime script not found" }
	if ConfigServiceScript == null:
		return { "ok": false, "error": "ConfigService script not found" }
	if StructuredLoggerScript == null:
		return { "ok": false, "error": "StructuredLogger script not found" }

	var logger = StructuredLoggerScript.new()
	logger.set_level("off")
	var config = ConfigServiceScript.new()
	var runtime = FlowRuntimeScript.new(logger, config, "/tmp/echoes-vnext-tests/skill_unlock_slot.json")
	runtime.boot()
	runtime.call("_handle_new_game", 2)
	var cfg: Dictionary = runtime.config_service.get_balance()
	var options: Array = OnboardingService.build_fragment_options(runtime.flow_ctx.save_data, cfg)
	if options.is_empty():
		return { "ok": false, "error": "Could not create deterministic starter options" }
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(options[0].get("virtue", "")))
	runtime.call("_handle_onboarding_fragment_confirm", 3)

	if not runtime.has_method("get_save_data"):
		return { "ok": false, "error": "FlowRuntime.get_save_data() missing" }

	# Mark onboarding complete so tests are not blocked by intro state.
	# Must happen before navigating to sanctum so _gate_state_for_keeper_intro allows it.
	var save_ref: Dictionary = runtime.get_save_data()
	var onboarding_v: Variant = save_ref.get("onboarding", {})
	if onboarding_v is Dictionary:
		var ob: Dictionary = onboarding_v as Dictionary
		ob["keeper_intro_complete"] = true
		ob["keeper_intro_step"]     = "complete"

	# Navigate to flow.sanctum — boot may have landed on flow.splash if save was fresh.
	# _gate_state_for_keeper_intro allows sanctum once keeper_intro_complete=true.
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.sanctum" })

	return { "ok": true, "runtime": runtime }


static func _get_roster(save: Dictionary) -> Array:
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	return roster_v if roster_v is Array else []


static func _first_echo(roster: Array) -> Dictionary:
	if roster.is_empty():
		return {}
	var e_v: Variant = roster[0]
	return e_v if e_v is Dictionary else {}


static func _find_echo(save: Dictionary, echo_id: String) -> Dictionary:
	var roster := _get_roster(save)
	for e_v in roster:
		if e_v is Dictionary:
			var e: Dictionary = e_v as Dictionary
			if str(e.get("id", "")) == echo_id:
				return e
	return {}


static func _get_economy(save: Dictionary) -> Dictionary:
	var econ_v: Variant = save.get("economy", {})
	return econ_v if econ_v is Dictionary else {}
