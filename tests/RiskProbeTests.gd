# res://tests/RiskProbeTests.gd
#
# V2-ECONOMY-004 Phase 5 PROBE (decisions.md D-52). Measures; asserts no design number.
# Question: does a player choice change how fast a fight ends (pace_state) or how many Echoes die?
# Each fight is driven to its end through the production path of FlowFingerprintTests
# (FlowRuntime, FlowEncounterState.enter, combat.init / confirm_round / next_actor).
# The seed is the seed_tag of the harness (campaign seed is pinned to 12346), so one
# (mode, seed index) pair is the same party and board in every lever row: the rows are paired.
#
# Size. The default is a smoke run (recover mode, four rows, one seed). A fight costs about
# 0.3 s per actor turn, so the full matrix is long and belongs to the main chat.
#   RISK_PROBE_SEEDS       seeds per mode and row (default 1)
#   RISK_PROBE_SEED_START  first seed index (default 0)
#   RISK_PROBE_MODES       comma list of combat,purify_shrine,recover,pursue,guide_escort, or "all"
#   RISK_PROBE_ROWS        comma list of row ids, or "all"
# Reading guide: docs/stories/v2-economy-004/phase5-risk-probe.md.

class_name RiskProbeTests
extends RefCounted

const _DEFAULT_SEEDS := 1
const _MAX_ROUNDS := 60
const _DEFAULT_MODES := ["recover"]
const _DEFAULT_ROWS := ["directive.scout_carefully", "directive.seek_signs", "guidance.engage", "party.size_3"]

const _MODES := {
	"combat":         {"mode": EncounterResolutionModes.COMBAT,        "guide_mode": "",       "joins": ""},
	"purify_shrine":  {"mode": EncounterResolutionModes.PURIFY_SHRINE, "guide_mode": "",       "joins": ""},
	"recover":        {"mode": EncounterResolutionModes.RECOVER,       "guide_mode": "",       "joins": ""},
	"pursue":         {"mode": EncounterResolutionModes.PURSUE,        "guide_mode": "",       "joins": ""},
	"guide_escort":   {"mode": EncounterResolutionModes.GUIDE_SPIRIT,  "guide_mode": "escort", "joins": "nojoin"},
}

# The same five suggestions as the debug command `guide` (ui/AppRoot.gd _GUIDE_PRESETS).
# Copied, not read: AppRoot cannot be instantiated in a test (AGENTS.md mistake 30).
const _GUIDE_PRESETS := {
	"hold":     {"purpose": "hold",     "action_type": "actor.guard"},
	"advance":  {"purpose": "advance",  "action_type": "actor.move"},
	"protect":  {"purpose": "protect",  "action_type": "protect_ally"},
	"withdraw": {"purpose": "withdraw", "action_type": "actor.move"},
	"engage":   {"purpose": "engage",   "action_type": "melee_attack"},
}

# One lever changes per row; every other value stays at the baseline (first row).
const _ROWS := [
	{"id": "directive.scout_carefully", "directive": "directive.scout_carefully", "guidance": "", "size": 5, "standing": 1},
	{"id": "directive.seek_signs",      "directive": "directive.seek_signs",      "guidance": "", "size": 5, "standing": 1},
	{"id": "guidance.hold",     "directive": "directive.scout_carefully", "guidance": "hold",     "size": 5, "standing": 1},
	{"id": "guidance.advance",  "directive": "directive.scout_carefully", "guidance": "advance",  "size": 5, "standing": 1},
	{"id": "guidance.protect",  "directive": "directive.scout_carefully", "guidance": "protect",  "size": 5, "standing": 1},
	{"id": "guidance.withdraw", "directive": "directive.scout_carefully", "guidance": "withdraw", "size": 5, "standing": 1},
	{"id": "guidance.engage",   "directive": "directive.scout_carefully", "guidance": "engage",   "size": 5, "standing": 1},
	{"id": "party.size_3",      "directive": "directive.scout_carefully", "guidance": "", "size": 3, "standing": 1},
	{"id": "party.standing_3",  "directive": "directive.scout_carefully", "guidance": "", "size": 5, "standing": 3},
]


static func register(runner) -> void:
	runner.register_test("risk_probe/matrix", func(): return test_matrix())
	runner.register_test("risk_probe/deterministic", func(): return test_deterministic())
	runner.register_test("risk_probe/mirrors_fingerprint_harness", func(): return test_mirrors_harness())


## Same construction as FlowFingerprintTests._setup_encounter, plus party size, Standing and
## Directive. A copy: the harness cannot change the party size, and this file may not edit it.
## test_mirrors_harness proves the copy stays equal to the harness.
static func _setup(mode_key: String, seed_tag: String, row: Dictionary) -> Dictionary:
	var spec: Dictionary = _MODES[mode_key]
	var save_path: String = TestSaveHarness.fresh_save_path("risk_probe_%s.json" % seed_tag)
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, save_path)
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	var directive_id := str(row.get("directive", ""))
	if not directive_id.is_empty():
		runtime.dispatch({ "type": "directive.select", "directive_id": directive_id })

	flow_ctx.realm_id = "realm.01"
	if RealmService.get_or_create("realm.01", flow_ctx, t).is_empty():
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.%s" % seed_tag
	flow_ctx.save_data["economy"]["ase"] = 0
	flow_ctx.save_data["economy"]["ekwan"] = 0

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var vec_cfg: Dictionary = bal.get("data", {}).get("vectors", {})
	var standing := int(row.get("standing", 1))
	var size := int(row.get("size", 5))
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(seed_tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		EmotionService.init_echo(echo, logger, t)
		VectorService.init_vectors(echo, vec_cfg, logger, t)
		if standing > 1:
			FlowFingerprintTests._promote_echo_rank(echo, standing, bal, flow_ctx.campaign_seed, logger, t)
		if i < size:
			roster.append(echo)
			party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	flow_ctx.dev_combat_objective = spec["mode"]
	if not str(spec["guide_mode"]).is_empty():
		flow_ctx.dev_guide_mode = spec["guide_mode"]
	if not str(spec["joins"]).is_empty():
		flow_ctx.dev_guide_joins = spec["joins"]
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	flow_ctx.active_encounter_objective_index = 0

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	if flow_ctx.encounter_ctx == null:
		return {}

	var guidance_id := str(row.get("guidance", ""))
	if not guidance_id.is_empty():
		var g: Dictionary = (_GUIDE_PRESETS[guidance_id] as Dictionary).duplicate()
		g["guidance_id"] = guidance_id
		g["subject_id"] = ""
		g["recipient_ids"] = []
		runtime.dispatch({ "type": "debug.guidance.set", "guidance": g })

	return { "runtime": runtime, "flow_ctx": flow_ctx, "ectx": flow_ctx.encounter_ctx, "party_ids": party_ids }


## One fight to its end. Returns the measured record; "ok" false only when the fight did not finish.
static func _fight(mode_key: String, seed_idx: int, row: Dictionary) -> Dictionary:
	var seed_tag := "rp_%s_%d" % [mode_key, seed_idx]
	var env: Dictionary = _setup(mode_key, seed_tag, row)
	if env.is_empty():
		return { "ok": false, "error": "setup failed: %s %s" % [mode_key, row["id"]] }
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]
	var answers := {}
	if not _drive(env["runtime"], ectx, answers):
		return { "ok": false, "error": "no end within %d rounds: %s %s seed %d" % [_MAX_ROUNDS, mode_key, row["id"], seed_idx] }

	var cs: Dictionary = ectx.combat_state
	var data: Dictionary = flow_ctx.last_snapshot.get("data", {}) as Dictionary
	var win := bool(ectx.combat_result.get("victory", false))
	var rounds := int(ectx.combat_result.get("round_ended", 0))
	var started := 0
	var dead := 0
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) == "echo" and not bool(a.get("is_ally", false)) and not bool(a.get("is_spirit", false)):
			started += 1
			if bool(a.get("is_dead", false)):
				dead += 1
	# pace_state is in the resolve data on a pace-mode win only. The fraction is not exposed,
	# so it is rebuilt from the same inputs the reward uses.
	var par := float(cs.get("par_rounds", 0.0))
	var pace_state := str(data.get("pace_state", "")) if win else ""
	var frac := -1.0
	if win and par > 0.0:
		frac = PaceService.bonus_fraction(rounds, par, float(cs.get("pace_full_ratio", 0.0)),
			float(cs.get("pace_zero_ratio", 0.0)))
	return {
		"ok": true, "mode": mode_key, "row": str(row["id"]), "seed": seed_idx,
		"win": win, "reason": str(ectx.combat_result.get("reason", "")), "rounds": rounds,
		"par": par, "pace_state": pace_state, "fraction": frac,
		"started": started, "dead": dead, "survivors": started - dead,
		"answers": JSON.stringify(answers, "", true),
	}


## The dispatch sequence of FlowFingerprintTests._drive_and_capture without its per-turn capture.
## Also counts how often an Echo answered the guidance, per consent value, so a row that shows no
## effect can be told apart from a row where the guidance never arrived.
static func _drive(runtime: FlowRuntime, ectx: EncounterContext, answers: Dictionary) -> bool:
	var seen := {}
	runtime.dispatch({ "type": "combat.init" })
	for _r in range(_MAX_ROUNDS):
		runtime.dispatch({ "type": "combat.confirm_round" })
		_tally_answers(ectx, seen, answers)
		var guard := 0
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)) or str(cs.get("round_phase", "")) != "in_round":
				break
			runtime.dispatch({ "type": "combat.next_actor" })
			_tally_answers(ectx, seen, answers)
		if bool(ectx.combat_state.get("combat_over", false)):
			return true
	return false


static func _tally_answers(ectx: EncounterContext, seen: Dictionary, answers: Dictionary) -> void:
	var round_no := int(ectx.combat_state.get("round_counter", 0))
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var resp: Variant = (a_v as Dictionary).get("_guidance_response", {})
		if not (resp is Dictionary) or (resp as Dictionary).is_empty():
			continue
		var key := "%s@%d" % [str((a_v as Dictionary).get("id", "")), round_no]
		if seen.has(key):
			continue
		seen[key] = true
		var consent := str((resp as Dictionary).get("consent", "?"))
		answers[consent] = int(answers.get(consent, 0)) + 1


static func _seeds() -> int:
	var v := OS.get_environment("RISK_PROBE_SEEDS")
	return maxi(1, int(v)) if v != "" else _DEFAULT_SEEDS


static func _seed_start() -> int:
	var v := OS.get_environment("RISK_PROBE_SEED_START")
	return maxi(0, int(v)) if v != "" else 0


static func _csv_env(name: String, all: Array, default: Array) -> Array:
	var v := OS.get_environment(name)
	if v == "":
		return default
	if v == "all":
		return all
	var out: Array = []
	for p in v.split(",", false):
		out.append(p.strip_edges())
	return out


static func _selected_modes() -> Array:
	return _csv_env("RISK_PROBE_MODES", _MODES.keys(), _DEFAULT_MODES)


static func _selected_rows() -> Array:
	var ids: Array = []
	for r in _ROWS:
		ids.append(r["id"])
	var want: Array = _csv_env("RISK_PROBE_ROWS", ids, _DEFAULT_ROWS)
	var out: Array = []
	for r in _ROWS:
		if r["id"] in want:
			out.append(r)
	return out


static func test_matrix() -> Dictionary:
	var modes: Array = _selected_modes()
	var rows: Array = _selected_rows()
	for m in modes:
		if not _MODES.has(m):
			return { "ok": false, "error": "unknown mode in RISK_PROBE_MODES: %s" % m }
	if rows.is_empty():
		return { "ok": false, "error": "RISK_PROBE_ROWS matched no row" }
	var seeds := _seeds()
	var start := _seed_start()
	var cells := {}
	var total := 0
	for row_v in rows:
		var row: Dictionary = row_v
		for m in modes:
			var recs: Array = []
			for s in range(start, start + seeds):
				var rec: Dictionary = _fight(m, s, row)
				if not bool(rec.get("ok", false)):
					return rec
				recs.append(rec)
				total += 1
				print("RISK_FIGHT %s | %s | seed=%d | win=%s | reason=%s | rounds=%d | par=%.2f | pace=%s | frac=%.2f | started=%d | dead=%d | answers=%s" % [
					row["id"], m, s, str(rec["win"]), rec["reason"], rec["rounds"], rec["par"],
					rec["pace_state"] if rec["pace_state"] != "" else "-", rec["fraction"], rec["started"], rec["dead"], rec["answers"]])
			cells["%s|%s" % [row["id"], m]] = recs
	_print_table(rows, modes, cells)
	print("RISK_PROBE total fights: %d" % total)
	return { "ok": true }


## One line per (row, mode). pace counts are over wins in pace modes; "-" marks a no-pace result.
static func _print_table(rows: Array, modes: Array, cells: Dictionary) -> void:
	print("RISK_TABLE row | mode | fights | win_rate | mean_rounds | pace full/partial/none | mean_dead | mean_frac")
	for row_v in rows:
		for m in modes:
			var recs: Array = cells["%s|%s" % [(row_v as Dictionary)["id"], m]]
			var n := recs.size()
			var wins := 0
			var rounds_sum := 0
			var dead_sum := 0
			var full := 0
			var partial := 0
			var none := 0
			var frac_sum := 0.0
			var frac_n := 0
			for r_v in recs:
				var r: Dictionary = r_v
				wins += 1 if bool(r["win"]) else 0
				rounds_sum += int(r["rounds"])
				dead_sum += int(r["dead"])
				match str(r["pace_state"]):
					"full": full += 1
					"partial": partial += 1
					"none": none += 1
				if float(r["fraction"]) >= 0.0:
					frac_sum += float(r["fraction"])
					frac_n += 1
			print("RISK_TABLE %s | %s | %d | %.2f | %.1f | %d/%d/%d | %.2f | %s" % [
				(row_v as Dictionary)["id"], m, n, float(wins) / float(n), float(rounds_sum) / float(n),
				full, partial, none, float(dead_sum) / float(n),
				("%.2f" % (frac_sum / float(frac_n))) if frac_n > 0 else "-"])


## The same cell run twice in one process must give the same record. Guidance is the lever
## with the most new state (flow_ctx.dev_guidance), so it is the cell that is repeated.
static func test_deterministic() -> Dictionary:
	for row_id in ["guidance.withdraw"]:
		var row: Dictionary = _row_by_id(row_id)
		var a: Dictionary = _fight("recover", 0, row)
		var b: Dictionary = _fight("recover", 0, row)
		if not bool(a.get("ok", false)) or not bool(b.get("ok", false)):
			return { "ok": false, "error": "determinism cell did not finish: %s" % row_id }
		if JSON.stringify(a, "", true) != JSON.stringify(b, "", true):
			return { "ok": false, "error": "two runs of %s differ: %s vs %s" % [row_id, JSON.stringify(a), JSON.stringify(b)] }
	return { "ok": true }


## The probe copy of the setup must equal the harness: same rounds hash and same result for the
## baseline row on RECOVER (the cheapest mode).
static func test_mirrors_harness() -> Dictionary:
	var row: Dictionary = _row_by_id("directive.scout_carefully")
	var mine: Dictionary = _setup("recover", "rp_mirror", row)
	var theirs: Dictionary = FlowFingerprintTests._setup_encounter(
		EncounterResolutionModes.RECOVER, "rp_mirror", "", "", {}, "directive.scout_carefully")
	if mine.is_empty() or theirs.is_empty():
		return { "ok": false, "error": "mirror setup failed" }
	if not _drive(mine["runtime"], mine["ectx"], {}):
		return { "ok": false, "error": "mirror fight did not finish" }
	var db: Dictionary = FlowFingerprintTests._drive_and_capture(theirs["runtime"], theirs["ectx"], _MAX_ROUNDS)
	var fa: Dictionary = FlowFingerprintTests._final_fingerprint(mine["flow_ctx"], mine["ectx"])
	var fb: Dictionary = FlowFingerprintTests._final_fingerprint(theirs["flow_ctx"], theirs["ectx"])
	if not bool(db.get("combat_over", false)) or FlowFingerprintTests._hash(fa) != FlowFingerprintTests._hash(fb) \
			or JSON.stringify(mine["ectx"].actors, "", true) != JSON.stringify(theirs["ectx"].actors, "", true):
		return { "ok": false, "error": "probe setup or driver no longer equals the FlowFingerprintTests harness" }
	return { "ok": true }


static func _row_by_id(id: String) -> Dictionary:
	for r in _ROWS:
		if r["id"] == id:
			return r
	return {}
