# res://tests/DirectiveCharacterizationTests.gd
# V2-DIRECTIVE-002 phase A: Directive accessor, readers, registry-driven lists, integrity guard,
# synthetic third Directive, and the no-literal-id scan of core/.
# Filter: `tests directive_char` (or `tests directive`, which matches these too).

extends RefCounted
class_name DirectiveCharacterizationTests

const ContactModelScript := preload("res://core/realms/ContactModel.gd")
const SEEK := "directive.seek_signs"
const SCOUT := "directive.scout_carefully"
const THIRD := "directive.test_third"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("directive_char/seek_signs_reaches_contact_bids", Callable(DirectiveCharacterizationTests, "_t_bids_follow_seek_signs"))
	runner.register_test("directive_char/seek_signs_reaches_encounter_approach", Callable(DirectiveCharacterizationTests, "_t_approach_follows_seek_signs"))
	runner.register_test("directive_char/scout_contrast_bids_and_approach", Callable(DirectiveCharacterizationTests, "_t_scout_contrast"))
	runner.register_test("directive_char/registry_known_id_survives_load", Callable(DirectiveCharacterizationTests, "_t_known_id_survives_load"))
	runner.register_test("directive_char/registry_unknown_id_resets_on_load", Callable(DirectiveCharacterizationTests, "_t_unknown_id_resets_on_load"))
	runner.register_test("directive_char/legacy_ids_map_on_load", Callable(DirectiveCharacterizationTests, "_t_legacy_ids_map_on_load"))
	runner.register_test("directive_char/no_config_keeps_shipped_ids_on_load", Callable(DirectiveCharacterizationTests, "_t_no_config_keeps_shipped_ids"))
	runner.register_test("directive_char/third_directive_in_snapshot_lists", Callable(DirectiveCharacterizationTests, "_t_third_in_lists"))
	runner.register_test("directive_char/third_directive_drives_bids_and_approach", Callable(DirectiveCharacterizationTests, "_t_third_drives_bids_and_approach"))
	runner.register_test("directive_char/accessor_reads_canonical_key_only", Callable(DirectiveCharacterizationTests, "_t_accessor"))
	runner.register_test("directive_char/entry_schema_guard", Callable(DirectiveCharacterizationTests, "_t_entry_schema_guard"))
	runner.register_test("directive_char/degenerate_weights_warn_only", Callable(DirectiveCharacterizationTests, "_t_degenerate_weights_warn_only"))
	runner.register_test("directive_char/picker_description_matches_config", Callable(DirectiveCharacterizationTests, "_t_picker_description"))
	runner.register_test("directive_char/synthetic_directive_reaches_acceptance", Callable(DirectiveCharacterizationTests, "_t_synthetic_directive_reaches_acceptance"))
	runner.register_test("directive_char/synthetic_directive_reaches_stop_cause", Callable(DirectiveCharacterizationTests, "_t_synthetic_directive_reaches_stop_cause"))
	runner.register_test("directive_char/no_directive_id_literal_in_core", Callable(DirectiveCharacterizationTests, "_t_no_id_literal_in_core"))


# Same production path as ConversationRepairTests: real boot, then the controlled save swapped in.
# The party Echo has calling "onyamesu": Scout Carefully boosts it, Seek Signs authors no boost,
# and "witness" does not align with it. So bid_type "alignment" can only come from Scout's table.
static func _make_env(directive_id: String, sit_type: String) -> Dictionary:
	var contact := ContactModelScript.make("contact.dc", "witness", "courage", "wisdom", 24, 68, "bold", "Nana Adwoa", 2)
	var save := ConversationRepairTests._make_save_with_contact_situation(contact)
	save["stage_context"]["active_directive_id"] = directive_id
	var roster: Array = save["sanctum"]["roster"]
	(roster[0] as Dictionary)["calling"] = "onyamesu"
	if sit_type != "npc":
		var sit: Dictionary = save["realms"]["realm.01"]["stages"][0]["explore_map"]["situations"][0]
		sit["type"] = sit_type
		sit.erase("contact")
	var runtime := ConversationRepairTests._make_runtime(save, ConversationRepairTests._make_logger("off"))
	return { "runtime": runtime, "save": save }


# Runs one engagement and returns { bid, approach_id }. Optional hook edits the runtime before dispatch.
static func _engage(directive_id: String, sit_type: String, hook: Callable = Callable()) -> Dictionary:
	var bak := ConversationRepairTests._capture_save()
	var env := _make_env(directive_id, sit_type)
	var runtime: FlowRuntime = env["runtime"]
	if hook.is_valid():
		hook.call(runtime)
	runtime.dispatch({ "type": "stage.engage_situation", "situation_id": "sit.t1" })
	var out := { "bid": "?", "approach_id": "?" }
	if sit_type == "npc":
		var stage: Dictionary = FlowStageExploreState._get_current_stage(runtime.flow_ctx)
		var responses: Array = stage.get("explore_map", {}).get("contact_responses", [])
		if responses.size() == 1:
			out["bid"] = str((responses[0] as Dictionary).get("bid_type", "?"))
	else:
		var ea_v: Variant = runtime.flow_ctx.save_data.get("stage_context", {}).get("encounter_approach", null)
		if ea_v is Dictionary:
			out["approach_id"] = str((ea_v as Dictionary).get("directive_id", "?"))
	ConversationRepairTests._restore_save(bak)
	return out


static func _t_bids_follow_seek_signs() -> Dictionary:
	# Seek Signs authors no bid boost and "witness" does not align with onyamesu, so no bid.
	var bid := str(_engage(SEEK, "npc")["bid"])
	if bid != "":
		return { "ok": false, "error": "expected no bid under seek_signs, got '%s'" % bid }
	return { "ok": true }


static func _t_approach_follows_seek_signs() -> Dictionary:
	var got := str(_engage(SEEK, "combat")["approach_id"])
	if got != SEEK:
		return { "ok": false, "error": "expected encounter_approach.directive_id '%s', got '%s'" % [SEEK, got] }
	return { "ok": true }


static func _t_scout_contrast() -> Dictionary:
	var bid := str(_engage(SCOUT, "npc")["bid"])
	if bid != "alignment":
		return { "ok": false, "error": "expected Scout boost bid 'alignment', got '%s'" % bid }
	var got := str(_engage(SCOUT, "combat")["approach_id"])
	if got != SCOUT:
		return { "ok": false, "error": "expected encounter_approach.directive_id '%s', got '%s'" % [SCOUT, got] }
	return { "ok": true }


static func _cfg_with_third() -> Dictionary:
	var cs := ConfigService.new()
	if not cs.load_balance():
		return {}
	var cfg := ConfigService.get_directives_cfg(cs)
	cfg[THIRD] = _third_entry(cfg)
	return cfg


# Runs the load repair on a save holding `id`. Returns { id, notes } (notes of save.schema.repair).
static func _repair_id(id: Variant, cfg: Dictionary) -> Dictionary:
	var save := { "stage_context": { "active_directive_id": id } }
	var logger := ConversationRepairTests._make_logger("info")
	SaveService._apply_additive_defaults_and_repairs(save, logger, 0, cfg)
	var notes: Array = []
	for e_v in logger.get_logs():
		if str((e_v as Dictionary).get("type", "")) == "save.schema.repair":
			notes.append_array((e_v as Dictionary).get("data", {}).get("notes", []))
	return { "id": str(save["stage_context"].get("active_directive_id", "")), "notes": " | ".join(PackedStringArray(notes)) }


static func _t_known_id_survives_load() -> Dictionary:
	var cfg := _cfg_with_third()
	if cfg.is_empty():
		return { "ok": false, "error": "could not load balance.json" }
	var r := _repair_id(THIRD, cfg)
	if r["id"] != THIRD or "directive" in r["notes"]:
		return { "ok": false, "error": "registry-known id was repaired: %s" % r }
	# Round trip through the real file path, where _read_candidate also runs the repair.
	var path := TestSaveHarness.dir() + "directive_char_slot.json"
	var save := SaveSchema.make_new_save(4300, "directive-char-test")
	save["stage_context"]["active_directive_id"] = THIRD
	var logger := ConversationRepairTests._make_logger("off")
	var wrote := SaveService.save_to_file(path, save, logger, 0)
	var loaded: Dictionary = SaveService.load_from_file(path, logger, 1, cfg)
	for suffix in ["", ".pending_a", ".pending_b", ".tmp", ".bak1", ".bak2", ".bak3", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	if not wrote:
		return { "ok": false, "error": "save_to_file failed" }
	var got := DirectiveService.active_id(loaded.get("data", {}))
	if got != THIRD:
		return { "ok": false, "error": "round trip lost the id: got '%s' (status %s)" % [got, loaded.get("status", "")] }
	return { "ok": true }


static func _t_unknown_id_resets_on_load() -> Dictionary:
	var cfg := _cfg_with_third()
	if cfg.is_empty():
		return { "ok": false, "error": "could not load balance.json" }
	var r := _repair_id("directive.removed", cfg)
	if r["id"] != SCOUT or not ("unknown directive 'directive.removed'" in r["notes"]):
		return { "ok": false, "error": "registry-unknown id must reset to default with a note: %s" % r }
	return { "ok": true }


static func _t_legacy_ids_map_on_load() -> Dictionary:
	var cfg := _cfg_with_third()
	if cfg.is_empty():
		return { "ok": false, "error": "could not load balance.json" }
	for legacy in ["directive.scout", "directive.protect", "directive.push", "directive.preserve", "directive.focus"]:
		for c in [cfg, {}]:
			var r := _repair_id(legacy, c)
			if r["id"] != SCOUT or not ("directive V1→V2: %s" % legacy in r["notes"]):
				return { "ok": false, "error": "legacy id '%s' did not map to default: %s" % [legacy, r] }
	var missing := _repair_id(7, cfg)
	if missing["id"] != SCOUT:
		return { "ok": false, "error": "non-string id must default: %s" % missing }
	return { "ok": true }


# No config (empty dict): the built-in registry keeps the two shipped ids.
static func _t_no_config_keeps_shipped_ids() -> Dictionary:
	for id in [SCOUT, SEEK]:
		var r := _repair_id(id, {})
		if r["id"] != id or "directive" in r["notes"]:
			return { "ok": false, "error": "shipped id '%s' was repaired without config: %s" % [id, r] }
	var r3 := _repair_id(THIRD, {})
	if r3["id"] != SCOUT or not ("unknown directive" in r3["notes"]):
		return { "ok": false, "error": "id unknown to the built-in registry must reset: %s" % r3 }
	return { "ok": true }


# Test-only third Directive: a copy of Scout with its own id and a bid boost for onyamesu.
static func _third_entry(cfg: Dictionary) -> Dictionary:
	var e: Dictionary = (cfg[SCOUT] as Dictionary).duplicate(true)
	e["id"] = THIRD
	e["contact_effects"] = { "bid_boost": ["onyamesu"] }
	return e


# Production balance goes through config_service; ConfigService.get_balance() returns a copy,
# so the synthetic entry is planted in its backing dict.
static func _plant_third(runtime: FlowRuntime) -> void:
	var dirs: Dictionary = runtime.config_service._balance["data"]["directives"]
	dirs[THIRD] = _third_entry(dirs)
	runtime.directive_service.load_from_config(runtime.config_service.get_balance())


static func _t_third_in_lists() -> Dictionary:
	var bak := ConversationRepairTests._capture_save()
	var env := _make_env(SCOUT, "npc")
	var runtime: FlowRuntime = env["runtime"]
	_plant_third(runtime)
	if not (THIRD in runtime.directive_service.get_available_directives()):
		ConversationRepairTests._restore_save(bak)
		return { "ok": false, "error": "service registry does not list the third directive" }
	var ctx: FlowContext = runtime.flow_ctx
	var sanctum_list: Array = SanctumSnapshotBuilder.build(ctx, 0).get("data", {}).get("available_directives", [])
	var picker: Array = FlowStageState.build_snapshot(ctx, 0).get("data", {}).get("directive", {}).get("directives", [])
	ConversationRepairTests._restore_save(bak)
	var picker_ids: Array = []
	for d_v in picker:
		picker_ids.append(str((d_v as Dictionary).get("id", "")))
	if sanctum_list != [SCOUT, SEEK, THIRD] or picker_ids != [SCOUT, SEEK, THIRD]:
		return { "ok": false, "error": "expected [scout, seek, third] in both lists, got sanctum=%s picker=%s" % [sanctum_list, picker_ids] }
	return { "ok": true }


static func _t_third_drives_bids_and_approach() -> Dictionary:
	var bid := str(_engage(THIRD, "npc", Callable(DirectiveCharacterizationTests, "_plant_third"))["bid"])
	if bid != "alignment":
		return { "ok": false, "error": "third directive contact_effects.bid_boost did not drive the bid, got '%s'" % bid }
	var got := str(_engage(THIRD, "combat", Callable(DirectiveCharacterizationTests, "_plant_third"))["approach_id"])
	if got != THIRD:
		return { "ok": false, "error": "expected encounter_approach.directive_id '%s', got '%s'" % [THIRD, got] }
	return { "ok": true }


# A data-only Directive: a new tolerance reaches route acceptance with no logic change.
static func _t_synthetic_directive_reaches_acceptance() -> Dictionary:
	var cs := ConfigService.new()
	if not cs.load_balance():
		return { "ok": false, "error": "could not load balance.json" }
	var movement: Dictionary = cs.get_balance()["data"]["combat"]["movement"]
	var cfg: Dictionary = movement["spatial_utility"]
	var offset: float = float(movement["exposure_acceptance"]["offset"])
	var third := _third_entry(ConfigService.get_directives_cfg(cs))
	third["exposure_tolerance"] = 0.65
	var arbiter := BehaviorArbiter.new({}, movement)
	var option := { "objective_progress": 0.0, "cohesion": 0.0, "exposure": 1.0, "congestion": 0.0, "commitment": 0, "capacity": 4 }
	var parts := {}
	arbiter._spatial_utility({ "urgency": 0.0, "purpose": "advance" }, option, third, cfg, parts)
	var expected: float = float(cfg["directive_exposure_acceptance_weight"]) * (0.65 - offset)
	var got: float = float((parts["parts"] as Dictionary)["directive_exposure_acceptance"])
	if not is_equal_approx(got, expected):
		return { "ok": false, "error": "synthetic tolerance 0.65 gave term %s, expected %s" % [got, expected] }
	return { "ok": true }


# Same for the stop cause, through the real screen.
static func _t_synthetic_directive_reaches_stop_cause() -> Dictionary:
	var cs := ConfigService.new()
	if not cs.load_balance():
		return { "ok": false, "error": "could not load balance.json" }
	var third := _third_entry(ConfigService.get_directives_cfg(cs))
	third["exposure_tolerance"] = 0.5
	var cfg: Dictionary = StopShortContextService.with_judgment_scale(
		cs.get_balance()["data"]["actor"]["stop_short"] as Dictionary,
		cs.get_balance()["data"]["combat"]["movement"] as Dictionary).duplicate(true)
	cfg["enabled"] = true
	var cands: Array = [StopShortWiringTests._candidate("option.a.conservative")]
	var vetoes: Array = StopShortContextService.screen(
		cands, StopShortWiringTests._actor({ "fear": 0 }), StopShortWiringTests._hostiles(5),
		{ "calling_family": "", "judgment": 0.0, "directive": third },
		{ "relationships": { "enemy_1": "hostile" } }, [], 2, Callable(StopShortWiringTests, "_style_of"), cfg)
	if not vetoes.is_empty() or cands.size() != 1:
		return { "ok": false, "error": "the synthetic Directive did not give a legal stop: %s" % str(vetoes) }
	var tag: Dictionary = StopShortContextService.trace_tag(cands[0] as Dictionary)
	if str(tag.get("cause_id", "")) != "directive" or not is_equal_approx(float((cands[0]["_stop_short"] as Dictionary)["strength"]), 0.5):
		return { "ok": false, "error": "wrong tag or strength: %s" % str(cands[0]) }
	return { "ok": true }


static func _t_accessor() -> Dictionary:
	var cs := ConfigService.new()
	if not cs.load_balance():
		return { "ok": false, "error": "could not load balance.json" }
	var cfg := ConfigService.get_directives_cfg(cs)
	cfg[THIRD] = _third_entry(cfg)
	if DirectiveService.active_id({}) != SCOUT:
		return { "ok": false, "error": "missing stage_context must give the default id" }
	# The legacy key must never be read.
	var legacy := { "flow": { "active_directive": SEEK } }
	if str(DirectiveService.resolve(legacy, cfg).get("id", "")) != SCOUT:
		return { "ok": false, "error": "legacy flow.active_directive was read" }
	for id in [SCOUT, SEEK, THIRD]:
		var save := { "stage_context": { "active_directive_id": id } }
		if str(DirectiveService.resolve(save, cfg).get("id", "")) != id:
			return { "ok": false, "error": "resolve did not return '%s'" % id }
	var unknown := { "stage_context": { "active_directive_id": "directive.nope" } }
	if str(DirectiveService.resolve(unknown, cfg).get("id", "")) != SCOUT:
		return { "ok": false, "error": "unknown id must resolve to the default Directive" }
	if str(DirectiveService.resolve(unknown, {}).get("id", "")) != SCOUT:
		return { "ok": false, "error": "empty config must fall back to the built-in registry" }
	return { "ok": true }


static func _t_entry_schema_guard() -> Dictionary:
	var cs := ConfigService.new()
	if not cs.load_balance():
		return { "ok": false, "error": "could not load balance.json (shipped Directives must pass the guard)" }
	var cfg: Dictionary = ConfigService.get_directives_cfg(cs)
	if not DirectiveService.validate_entry_schema(cfg, null, 0):
		return { "ok": false, "error": "shipped Directives failed the entry schema guard" }
	cfg[THIRD] = _third_entry(cfg)
	if not DirectiveService.validate_entry_schema(cfg, null, 0):
		return { "ok": false, "error": "well-formed third Directive failed the guard" }
	var bad := {
		"missing key": func(e): e.erase("step_budget"),
		"unknown key": func(e): e["bogus"] = 1,
		"bad unlock_condition": func(e): e["unlock_condition"] = "never",
		"wrong type": func(e): e["step_budget"] = "3",
		"id mismatch": func(e): e["id"] = "directive.other",
		"pros with 1 entry": func(e): e["pros"] = ["only one"],
		"cons with a non-string": func(e): e["cons"] = ["fine", 7],
		"pros with an empty string": func(e): e["pros"] = ["fine", ""],
	}
	for name in bad:
		var e: Dictionary = _third_entry(cfg)
		(bad[name] as Callable).call(e)
		if DirectiveService.validate_entry_schema({ THIRD: e }, null, 0):
			return { "ok": false, "error": "guard accepted a Directive with: %s" % name }
	# _comment keys are accepted at block, entry and contact_effects level.
	var ok_cfg := { "_comment_x": "note", THIRD: _third_entry(cfg) }
	(ok_cfg[THIRD] as Dictionary)["_comment_y"] = "note"
	((ok_cfg[THIRD] as Dictionary)["contact_effects"] as Dictionary)["_comment_z"] = "note"
	if not DirectiveService.validate_entry_schema(ok_cfg, null, 0):
		return { "ok": false, "error": "a _comment key was rejected" }
	var bad_fx := {
		"unknown effect key": func(e): e["contact_effects"]["bid_boots"] = ["x"],
		"bid_* not an array": func(e): e["contact_effects"]["bid_boost"] = "onyamesu",
		"*_bonus not a number": func(e): e["contact_effects"]["guide_reveal_bonus"] = "1",
	}
	for name in bad_fx:
		var e: Dictionary = _third_entry(cfg)
		(bad_fx[name] as Callable).call(e)
		if DirectiveService.validate_entry_schema({ THIRD: e }, null, 0):
			return { "ok": false, "error": "guard accepted contact_effects with: %s" % name }
	return { "ok": true }


static func _t_degenerate_weights_warn_only() -> Dictionary:
	var cs := ConfigService.new()
	if not cs.load_balance():
		return { "ok": false, "error": "could not load balance.json" }
	var bal := cs.get_balance()
	var cfg: Dictionary = ConfigService.get_directives_cfg(cs)
	var actor_cfg: Dictionary = bal.get("data", {}).get("actor", {})
	if not ConfigService.directives_block_is_loadable(cfg, actor_cfg, null, 0):
		return { "ok": false, "error": "shipped Directives must be loadable" }
	var degenerate := _third_entry(cfg)
	degenerate["intent_weights"] = {}
	var dcfg := { THIRD: degenerate }
	if not DirectiveService.validate_entry_schema(dcfg, null, 0):
		return { "ok": false, "error": "degenerate weights must pass the entry schema" }
	if DirectiveService.validate_config_integrity(dcfg, actor_cfg, null, 0):
		return { "ok": false, "error": "integrity guard must still flag empty intent_weights" }
	if not ConfigService.directives_block_is_loadable(dcfg, actor_cfg, null, 0):
		return { "ok": false, "error": "degenerate weights alone must not abort the load" }
	var malformed := _third_entry(cfg)
	malformed.erase("step_budget")
	if ConfigService.directives_block_is_loadable({ THIRD: malformed }, actor_cfg, null, 0):
		return { "ok": false, "error": "malformed entry must abort the load" }
	return { "ok": true }


static func _t_picker_description() -> Dictionary:
	var bak := ConversationRepairTests._capture_save()
	var env := _make_env(SCOUT, "npc")
	var runtime: FlowRuntime = env["runtime"]
	var cfg: Dictionary = ConfigService.get_directives_cfg(runtime.config_service)
	var picker: Array = FlowStageState.build_snapshot(runtime.flow_ctx, 0).get("data", {}).get("directive", {}).get("directives", [])
	ConversationRepairTests._restore_save(bak)
	if picker.size() != cfg.size() or picker.is_empty():
		return { "ok": false, "error": "picker lists %d Directives, config has %d" % [picker.size(), cfg.size()] }
	for d_v in picker:
		var d: Dictionary = d_v
		var want := str((cfg[str(d.get("id", ""))] as Dictionary).get("description", ""))
		if want == "" or str(d.get("description", "")) != want:
			return { "ok": false, "error": "picker description for '%s' differs from config" % d.get("id", "") }
	return { "ok": true }


# Directive ids are data. Only DirectiveService (registry and constants) may hold them. The floor is
# well under the real file count in core/, so a broken walk cannot pass silently.
const _LITERAL_ALLOW := ["res://core/directives/DirectiveService.gd"]
const _MIN_FILES_SCANNED := 100
const _ID_PATTERN := "directive\\.(scout_carefully|seek_signs)|[\"'](scout_carefully|seek_signs)[\"']|Seek Signs|Scout Carefully"
# A substring test on a Directive-id variable with a short token, e.g. `"signs" in directive_id`.
const _IN_PATTERN := "[\"'](signs|scout|seek)\\w*[\"']\\s+in\\s+\\w*(dir|directive)\\w*"

static func _t_no_id_literal_in_core() -> Dictionary:
	var re_id := RegEx.create_from_string(_ID_PATTERN)
	var re_in := RegEx.create_from_string(_IN_PATTERN)
	if DirAccess.open("res://core") == null:
		return { "ok": false, "error": "cannot open res://core" }
	var hits: Array = []
	var counter := { "files": 0 }
	_scan_dir("res://core", hits, counter, re_id, re_in)
	if counter["files"] < _MIN_FILES_SCANNED:
		return { "ok": false, "error": "scan read only %d .gd files (floor %d)" % [counter["files"], _MIN_FILES_SCANNED] }
	if not hits.is_empty():
		return { "ok": false, "error": "Directive id literal outside the allow-list: %s" % [hits] }
	return { "ok": true }


static func _scan_dir(dir_path: String, hits: Array, counter: Dictionary, re_id: RegEx, re_in: RegEx) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan_dir(dir_path + "/" + sub, hits, counter, re_id, re_in)
	for fname in dir.get_files():
		var path := dir_path + "/" + fname
		if not fname.ends_with(".gd"):
			continue
		counter["files"] += 1
		if path in _LITERAL_ALLOW:
			continue
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := _strip_comment(line)
			if re_id.search(code) != null or re_in.search(code) != null:
				hits.append("%s:%d" % [path, n])


# Cuts a line at the first '#' that is outside a string literal.
static func _strip_comment(line: String) -> String:
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote != "":
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.substr(0, i)
		i += 1
	return line
