# res://tests/FearReachabilityProbe.gd
#
# INVESTIGATION TOOL — not a test. Registered only under `-- tests fearprobe`.
#
# Drives REAL FlowRuntime encounters and prints a per-source fear ledger so the
# Absolute Fear Rule's reachability can be measured instead of reasoned about.
#
# Why: `actor.refuse` (ActorStateMachine ~:197) never fires in natural play —
# 0 refusals in 439 measured rounds (V2-PROG-012 Phase 7). This probe quantifies
# accumulation vs recovery per round and re-measures candidate config changes.
#
# Every number printed comes from a live `combat.confirm_round` / `combat.next_actor`
# loop through FlowRuntime — the same path the player drives.

class_name FearReachabilityProbe
extends RefCounted


## Report sink — written incrementally so a slow/hung scenario still leaves
## every completed scenario's numbers on disk.
const REPORT_PATH := "user://fear_probe_report.txt"
static var _sink: FileAccess = null
## Hard wall-clock budget for the whole probe. Checked between scenarios so the
## run always terminates on its own, independent of the shell watchdog.
const BUDGET_MS := 150000


static func register(runner) -> void:
	runner.register_test("fear_probe/run", func(): return run_all_scenarios())


static func _say(line: String) -> void:
	print(line)
	if _sink != null:
		_sink.store_line(line)
		_sink.flush()


# ── Scenario table ───────────────────────────────────────────────────────────
# Each entry: label + party shape + enemy shape + balance overrides.
# `overrides` is a list of [path_array, value] applied to config_service._balance.

static func run_all_scenarios() -> Dictionary:
	var scenarios: Array = [
		# ── Baseline: what the game actually ships today ──────────────────
		{"label": "A1 shipped default (5 echoes v 1 enemy, rank 1)",
		 "rank": 1, "fear0": 0, "enemies": 1, "group": "group.vale_patrol_sm"},
		{"label": "A2 shipped hardest (5 v 4, rank 1)",
		 "rank": 1, "fear0": 0, "enemies": 4, "group": "group.vale_totem_assault"},
		{"label": "A3 veteran, shipped hardest (5 v 4, rank 5, fear_base 25)",
		 "rank": 5, "fear0": 25, "enemies": 4, "group": "group.vale_totem_assault"},

		# ── Beyond-shipped pressure: an actually losing fight ─────────────
		{"label": "B1 outnumbered (5 v 10, rank 1)",
		 "rank": 1, "fear0": 0, "enemies": 10, "group": "probe.swarm"},
		{"label": "B2 outnumbered + unkillable enemies (5 v 10, rank 1)",
		 "rank": 1, "fear0": 0, "enemies": 10, "group": "probe.swarm", "enemy_hp_mul": 20},
		{"label": "B3 outnumbered + unkillable, veteran (5 v 10, rank 5, fear_base 25)",
		 "rank": 5, "fear0": 25, "enemies": 10, "group": "probe.swarm", "enemy_hp_mul": 20},
	]

	_sink = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_say("")
	_say("================================================================")
	_say(" ABSOLUTE FEAR RULE — REACHABILITY PROBE (live FlowRuntime)")
	_say("================================================================")

	# Optional filter: `-- tests fearprobe B2` runs only labels starting with B2.
	var filter: String = ""
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	if argv.size() > 2:
		filter = str(argv[2])

	var t_start: int = Time.get_ticks_msec()
	for sc_v in scenarios:
		var sc: Dictionary = sc_v
		if not filter.is_empty() and not str(sc.get("label", "")).begins_with(filter):
			continue
		if Time.get_ticks_msec() - t_start > BUDGET_MS:
			_say("")
			_say("--- BUDGET EXHAUSTED (%d ms) — remaining scenarios skipped." % BUDGET_MS)
			break
		var report: Dictionary = _run_scenario(sc)
		_print_report(sc, report)

	_say("")
	_say("================================================================")
	if _sink != null:
		_sink.close()
		_sink = null
	return {"ok": true, "error": ""}


# ── One scenario ─────────────────────────────────────────────────────────────

static func _run_scenario(sc: Dictionary) -> Dictionary:
	var seed_tag: String = str(sc.get("label", "probe")).substr(0, 2)
	var logger := StructuredLogger.new()
	logger.set_level("debug")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, "/tmp/echoes-vnext-tests/fear_probe_slot.json")
	runtime.boot()

	# ── Config surgery (in-memory only; data/balance.json is never touched) ──
	var bal_root: Dictionary = config._balance
	var bal: Dictionary = bal_root.get("data", {})
	var spawn_cfg: Dictionary = bal.get("combat", {}).get("enemy_spawn_config", {})
	var want_enemies: int = int(sc.get("enemies", 1))
	spawn_cfg["default_base_count"] = want_enemies
	spawn_cfg["base_count_by_completion_index"] = {"0": want_enemies}
	spawn_cfg["max_count"] = want_enemies
	spawn_cfg["mid_count_bonus"] = 0
	spawn_cfg["late_count_bonus"] = 0
	spawn_cfg["default_group"] = str(sc.get("group", "group.vale_patrol_sm"))
	spawn_cfg["group_by_completion_index"] = {"0": str(sc.get("group", "group.vale_patrol_sm"))}

	for ov_v in sc.get("overrides", []):
		var ov: Array = ov_v
		_set_path(bal, ov[0] as Array, ov[1])

	# A synthetic group large enough to actually outnumber a 5-echo party.
	var actors_root: Dictionary = config._actors
	var actors_data: Dictionary = actors_root.get("data", {})
	var groups: Dictionary = actors_data.get("groups", {})
	groups["probe.swarm"] = {
		"id": "probe.swarm", "tier": 1, "description": "probe-only swarm",
		"spawns": [{"template_id": "enemy.dust_wanderer", "count": 20}],
	}

	# ── Realm + party ────────────────────────────────────────────────────────
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0
	flow_ctx.realm_id = "realm.01"
	if RealmService.get_or_create("realm.01", flow_ctx, t).is_empty():
		return {"error": "realm setup failed"}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.fearprobe." + seed_tag

	var summ_cfg: Dictionary = bal.get("summoning", {})
	var expr_cfg: Dictionary = bal.get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(
			seed_tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		echo["rank"] = int(sc.get("rank", 1))
		# NOTE: `echo.get("emotion", {}) is Dictionary` is always true (the default IS a
		# Dictionary), so the key can still be absent here — check `has()` explicitly.
		if not echo.has("emotion") or not (echo["emotion"] is Dictionary):
			echo["emotion"] = {}
		(echo["emotion"] as Dictionary)["fear_current"] = int(sc.get("fear0", 0))
		roster.append(echo)
		party_ids.append(str(echo["id"]))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx == null:
		return {"error": "encounter setup failed"}

	# Optional: make enemies effectively unkillable so the party cannot farm the
	# −15 kill / −5 ripple recovery. This is the "losing fight" condition.
	var hp_mul: int = int(sc.get("enemy_hp_mul", 1))
	if hp_mul > 1:
		for a_v in ectx.actors:
			if a_v is Dictionary and str((a_v as Dictionary).get("faction", "")) == "enemy":
				var a: Dictionary = a_v
				a["max_hp"] = int(a.get("max_hp", 10)) * hp_mul
				a["current_hp"] = int(a.get("current_hp", 10)) * hp_mul

	var echo_ids: Dictionary = {}
	var enemy_n: int = 0
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) == "echo":
			echo_ids[str(a.get("id", ""))] = true
		elif str(a.get("faction", "")) == "enemy":
			enemy_n += 1

	# ── Drive the real round loop ────────────────────────────────────────────
	var max_rounds: int = int(sc.get("max_rounds", 20))
	var start_fear: Dictionary = {}
	for id in echo_ids:
		start_fear[id] = int(_find(ectx, str(id)).get("fear", 0))

	# `st` carries the running log cursor + peak across every tracked dispatch, so
	# attribution is reconciled PER DISPATCH rather than per round: each window's
	# observed fear delta minus its logged delta is that window's UNLOGGED remainder,
	# labelled by whichever echo action ran in it. That surfaces the fear mutations
	# that emit no log line at all — passive tick (ActorStateMachine ~:309), Seer
	# idle_fear_aura (~:834), Steward steady_call (~:930) — instead of burying them
	# in one opaque "residual" number.
	var tally: Dictionary = {}
	var st: Dictionary = {"cursor": logger.get_logs().size(), "peak": 0}
	_dispatch_tracked(runtime, ectx, {"type": "combat.init"}, echo_ids, tally, logger, st)

	var rounds_run: int = 0
	var per_round_net: Array = []
	## How many echo-rounds ended with fear pinned at the 0 floor — the single
	## clearest signal that recovery is not merely winning but overshooting.
	var zero_echo_rounds: int = 0

	for _r in range(max_rounds):
		if bool(ectx.combat_state.get("combat_over", false)):
			break
		var before: Dictionary = {}
		for id in echo_ids:
			before[id] = int(_find(ectx, str(id)).get("fear", 0))

		_dispatch_tracked(runtime, ectx, {"type": "combat.confirm_round"}, echo_ids, tally, logger, st)
		var guard: int = 0
		while guard < 80:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)):
				break
			if str(cs.get("round_phase", "")) != "in_round":
				break
			_dispatch_tracked(runtime, ectx, {"type": "combat.next_actor"}, echo_ids, tally, logger, st)
		rounds_run += 1

		var net: int = 0
		var living: int = 0
		for id in echo_ids:
			var a: Dictionary = _find(ectx, str(id))
			if a.is_empty() or bool(a.get("is_dead", false)):
				continue
			living += 1
			net += int(a.get("fear", 0)) - int(before.get(id, 0))
			if int(a.get("fear", 0)) == 0:
				zero_echo_rounds += 1
		per_round_net.append(0.0 if living == 0 else float(net) / float(living))

	var peak_fear: int = int(st["peak"])

	# Fear actually observed at the end + how far each Echo got.
	var end_fear: Dictionary = {}
	var dead: int = 0
	for id in echo_ids:
		var a: Dictionary = _find(ectx, str(id))
		end_fear[id] = int(a.get("fear", 0))
		if bool(a.get("is_dead", false)):
			dead += 1

	# Total logged delta vs total observed delta → unlogged residual
	# (the passive per-turn tick at ActorStateMachine ~:309 is the only fear
	#  mutation with no log line; clamping at 0/100 also lands here).
	var logged_sum: int = _points_sum(tally, false)
	var unlogged_sum: int = _points_sum(tally, true)
	var observed_sum: int = 0
	for id in echo_ids:
		observed_sum += int(end_fear[id]) - int(start_fear[id])

	return {
		"rounds": rounds_run,
		"enemies": enemy_n,
		"echoes": echo_ids.size(),
		"dead": dead,
		"start_fear": start_fear,
		"end_fear": end_fear,
		"peak_fear": peak_fear,
		"tally": tally,
		"logged_sum": logged_sum,
		"observed_sum": observed_sum,
		"unlogged_sum": unlogged_sum,
		# Should be 0 — if it is not, some fear path escaped BOTH the log tally and
		# the per-dispatch window reconciliation (i.e. it happened outside a dispatch).
		"unreconciled": observed_sum - logged_sum - unlogged_sum,
		"per_round_net": per_round_net,
		"zero_echo_rounds": zero_echo_rounds,
		"refusals": int(tally.get("!refusals", 0)),
		"threshold_note": _threshold_for(ectx, expr_cfg),
		"combat_over": bool(ectx.combat_state.get("combat_over", false)),
		"victory": bool(ectx.combat_result.get("victory", false)),
	}


# ── One tracked dispatch ─────────────────────────────────────────────────────
# Wraps `FlowRuntime.dispatch` so every fear point that moves inside the call is
# either attributed to a named log source or booked to a labelled "~ unlogged"
# bucket. `st` = { "cursor": int, "peak": int }, mutated in place.

static func _dispatch_tracked(
	runtime, ectx: EncounterContext, action: Dictionary,
	echo_ids: Dictionary, tally: Dictionary, logger, st: Dictionary
) -> void:
	var before: Dictionary = {}
	for id in echo_ids:
		before[id] = int(_find(ectx, str(id)).get("fear", 0))

	runtime.dispatch(action)

	var logs: Array = logger.get_logs()
	var from_i: int = int(st["cursor"])
	var to_i: int = logs.size()
	var living_echoes: int = 0
	for id in echo_ids:
		if not bool(_find(ectx, str(id)).get("is_dead", false)):
			living_echoes += 1

	var logged_before: int = _points_sum(tally, false)
	_tally_logs(logs, from_i, to_i, echo_ids, tally, living_echoes)
	var logged_delta: int = _points_sum(tally, false) - logged_before

	var observed: int = 0
	for id in echo_ids:
		var now: int = int(_find(ectx, str(id)).get("fear", 0))
		observed += now - int(before[id])
		st["peak"] = maxi(int(st["peak"]), now)

	var resid: int = observed - logged_delta
	if resid != 0:
		# A POSITIVE remainder means nominal recovery was booked that the actor never
		# actually received — i.e. it was thrown away against the fear-0 floor.
		# A NEGATIVE remainder is a real unlogged reduction (passive tick / Seer
		# idle_fear_aura / Steward steady_call), or leadership dampening on a gain.
		_add(tally, "~ clamp/unlogged: %s" % _window_label(logs, from_i, to_i, echo_ids), resid)
	st["cursor"] = to_i


## Names the window by whichever echo action ran in it, so an unlogged remainder
## can be traced to the ActorStateMachine branch that produced it.
static func _window_label(logs: Array, from_i: int, to_i: int, echo_ids: Dictionary) -> String:
	var seen: Dictionary = {}
	for i in range(from_i, to_i):
		var e: Dictionary = logs[i]
		if str(e.get("type", "")) != "actor.action":
			continue
		var d: Dictionary = e.get("data", {})
		if not echo_ids.has(str(d.get("source_id", ""))):
			continue
		seen[str(d.get("action_type", "?"))] = true
	if seen.is_empty():
		return "round tick / no echo action"
	var keys: Array = seen.keys()
	keys.sort()
	return ",".join(PackedStringArray(keys))


## Sums fear POINTS only. `!`-prefixed keys are counts, not points.
## `unlogged_only` selects the `~` buckets instead of the named `+`/`-` sources.
static func _points_sum(tally: Dictionary, unlogged_only: bool) -> int:
	var out: int = 0
	for k in tally:
		var ks: String = str(k)
		if ks.begins_with("!"):
			continue
		var is_unlogged: bool = ks.begins_with("~")
		if is_unlogged == unlogged_only:
			out += int(tally[k])
	return out


# ── Per-source attribution from the structured log ───────────────────────────
# Echo-faction only. Signs are as applied to the Echo's fear.

static func _tally_logs(
	logs: Array, from_i: int, to_i: int, echo_ids: Dictionary, tally: Dictionary,
	living_echoes: int
) -> void:
	for i in range(from_i, to_i):
		var e: Dictionary = logs[i]
		var type: String = str(e.get("type", ""))
		var d: Dictionary = e.get("data", {})
		match type:
			"combat.fear.hit":
				if echo_ids.has(str(d.get("actor_id", ""))):
					_add(tally, "+ hit taken (fear_per_hit)", int(d.get("delta", 0)))
			"actor.near_death":
				if echo_ids.has(str(d.get("actor_id", ""))):
					_add(tally, "+ near death", int(d.get("fear_delta", 0)))
			"combat.fear.ally_ko":
				# Logged once per KO with the nominal per-actor delta + affected count.
				# The spread is SAME-FACTION only, so an ENEMY KO must not be booked as
				# echo accumulation — gate on whether the fallen actor was one of ours.
				if echo_ids.has(str(d.get("ko_actor_id", ""))):
					var n: int = int(d.get("affected_count", 0))
					_add(tally, "+ ally KO spread", int(d.get("delta", 0)) * n)
			"combat.emotion.tick":
				# Logged once per round with the nominal delta; applied to every LIVING
				# non-structure actor. Only the living echoes are ours to count.
				_add(tally, "+ per-round tick", int(d.get("fear_delta", 0)) * living_echoes)
			"combat.emotion.witness_refuse":
				if echo_ids.has(str(d.get("observer_id", ""))):
					_add(tally, "+ witness refuse", int(d.get("delta", 0)))
			"combat.emotion.overwhelmed":
				if echo_ids.has(str(d.get("actor_id", ""))):
					_add(tally, "+ overwhelmed", int(d.get("delta", 0)))
			"combat.kill_boost":
				if echo_ids.has(str(d.get("actor_id", ""))):
					_add(tally, "- kill (killer)", int(d.get("fear_delta", 0)))
			"combat.kill_ripple":
				if echo_ids.has(str(d.get("ally_id", ""))):
					_add(tally, "- kill ripple (allies)", int(d.get("fear_delta", 0)))
			"combat.emotion.outnumber":
				_add(tally, "- outnumbering enemies", int(d.get("delta", 0)) * int(d.get("echo_count", 0)))
			"actor.fear_spike":
				if echo_ids.has(str(d.get("actor_id", ""))):
					_add(tally, "- identity spike", -int(d.get("spike", 0)))
			"actor.leadership.fear_reduce":
				# `actor_id` is the LEADER; the fear lands on `target_id`.
				if echo_ids.has(str(d.get("target_id", ""))):
					_add(tally, "- leadership calm", -int(d.get("fear_reduction", 0)))
			"actor.refused":
				_add(tally, "!refusals", 1)


static func _add(tally: Dictionary, key: String, v: int) -> void:
	tally[key] = int(tally.get(key, 0)) + v


static func _set_path(root: Dictionary, path: Array, value: Variant) -> void:
	var cur: Dictionary = root
	for i in range(path.size() - 1):
		var k: String = str(path[i])
		if not (cur.get(k, null) is Dictionary):
			cur[k] = {}
		cur = cur[k]
	cur[str(path[path.size() - 1])] = value


static func _find(ectx: EncounterContext, id: String) -> Dictionary:
	for a_v in ectx.actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("id", "")) == id:
			return a_v
	return {}


static func _threshold_for(ectx: EncounterContext, expr_cfg: Dictionary) -> String:
	var by_band: Dictionary = expr_cfg.get("refusal_thresholds_by_band", {})
	var out: Array = []
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) != "echo":
			continue
		var band: String = MaturityExpressionService.get_expression_band(
			int(a.get("rank", 1)), expr_cfg.get("band_by_standing", {}))
		var base: int = int(by_band.get(band, 80))
		var calling: String = str(a.get("calling_origin", "uncalled"))
		var cb: Dictionary = expr_cfg.get("calling_behavior", {}).get(calling, {})
		var thr: int = int(cb.get("absolute_fear_threshold", base))
		out.append("%s/%s=%d" % [band, calling, thr])
	return ", ".join(PackedStringArray(out))


# ── Reporting ────────────────────────────────────────────────────────────────

static func _print_report(sc: Dictionary, r: Dictionary) -> void:
	_say("")
	_say("--- %s" % str(sc.get("label", "?")))
	if r.has("error"):
		_say("    ERROR: %s" % str(r["error"]))
		return
	_say("    %d echoes v %d enemies | %d rounds | over=%s victory=%s | echo deaths=%d"
		% [int(r["echoes"]), int(r["enemies"]), int(r["rounds"]),
		   str(r["combat_over"]), str(r["victory"]), int(r["dead"])])
	_say("    refusal thresholds: %s" % str(r["threshold_note"]))
	var sf: Dictionary = r["start_fear"]
	var ef: Dictionary = r["end_fear"]
	var keys: Array = ef.keys()
	keys.sort()
	var line: Array = []
	for k in keys:
		line.append("%s %d→%d" % [str(k), int(sf.get(k, 0)), int(ef.get(k, 0))])
	_say("    fear: %s" % ", ".join(PackedStringArray(line)))
	_say("    PEAK fear reached by any echo: %d    REFUSALS: %d"
		% [int(r["peak_fear"]), int(r["refusals"])])

	_say("    ledger (party total across run, points of fear):")
	var tkeys: Array = (r["tally"] as Dictionary).keys()
	tkeys.sort()
	var acc: int = 0
	var rec: int = 0
	var denom: float = maxf(1.0, float(int(r["rounds"]) * int(r["echoes"])))
	for k in tkeys:
		if str(k) == "!refusals":
			continue
		var v: int = int((r["tally"] as Dictionary)[k])
		if not str(k).begins_with("~"):
			if v > 0:
				acc += v
			else:
				rec += v
		_say("        %-42s %+6d   (%+.2f / echo / round)" % [str(k), v, float(v) / denom])
	_say("        (unreconciled %+d — must be 0)" % int(r["unreconciled"]))
	_say("    NOMINAL  accumulation %+d (%+.2f/e/r)   recovery %+d (%+.2f/e/r)   headroom %+d"
		% [acc, float(acc) / denom, rec, float(rec) / denom, acc + rec])
	# Positive → nominal RECOVERY was thrown away against the fear-0 floor.
	# Negative → nominal ACCUMULATION was thrown away against the fear-100 ceiling
	#            (plus any genuinely unlogged reduction: passive tick / Seer aura /
	#            Steward steady_call / leadership dampening on a gain).
	var clamp: int = int(r["unlogged_sum"])
	if clamp >= 0:
		var pct: float = 0.0 if rec == 0 else (100.0 * float(clamp) / float(-rec))
		_say("    CLAMP    +%d pts of nominal RECOVERY never landed — %.0f%% of it hit the fear-0 floor"
			% [clamp, pct])
	else:
		var pct2: float = 0.0 if acc == 0 else (100.0 * float(-clamp) / float(acc))
		_say("    CLAMP    %d pts of nominal ACCUMULATION never landed — %.0f%% of it hit the fear-100 ceiling (or unlogged reduction)"
			% [clamp, pct2])
	_say("    OBSERVED net %+d (%+.2f/e/r)   echo-rounds pinned at fear 0: %d / %d (%.0f%%)"
		% [int(r["observed_sum"]), float(int(r["observed_sum"])) / denom,
		   int(r["zero_echo_rounds"]), int(r["rounds"]) * int(r["echoes"]),
		   100.0 * float(int(r["zero_echo_rounds"])) / denom])
