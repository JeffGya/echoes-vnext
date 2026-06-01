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
	runner.register_test("skill_unlock/all_defs_have_unlock_conditions", Callable(SkillUnlockTests, "_t_unlock_conditions_on_all_definitions"))
	runner.register_test("skill_unlock/okofor_families_present",         Callable(SkillUnlockTests, "_t_skill_families_for_okofor"))
	runner.register_test("skill_unlock/uncalled_echo_returns_empty",     Callable(SkillUnlockTests, "_t_uncalled_echo_returns_empty"))
	runner.register_test("skill_unlock/unlocked_skills_repaired",        Callable(SkillUnlockTests, "_t_unlocked_skills_after_repair"))
	runner.register_test("skill_unlock/unlock_spends_ase_and_writes",    Callable(SkillUnlockTests, "_t_unlock_skill_spends_ase"))
	runner.register_test("skill_unlock/unlock_denied_when_already_done", Callable(SkillUnlockTests, "_t_unlock_denied_when_already_unlocked"))
	runner.register_test("skill_unlock/unlock_denied_when_uncalled",     Callable(SkillUnlockTests, "_t_unlock_denied_when_uncalled"))
	runner.register_test("skill_unlock/unlock_denied_wrong_family",     Callable(SkillUnlockTests, "_t_unlock_denied_wrong_family"))
	runner.register_test("skill_unlock/party_toggle_works_from_sanctum", Callable(SkillUnlockTests, "_t_party_toggle_from_sanctum"))


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
# Helpers
# ---------------------------------------------------------------------------

## Loads ConfigService and returns { "ok": true, "skills_cfg": Dictionary }
## V2-PROG-009 fix: load_balance() must be called explicitly; ConfigService.new() does not auto-load.
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
	var runtime = FlowRuntimeScript.new(logger, config)
	runtime.boot()

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
