# res://tools/PursueTimingProbe.gd
#
# INVESTIGATION TOOL — not a test. Registered only under `-- tests pursueprobe`.
#
# Drives REAL FlowRuntime encounters (PURSUE vs plain COMBAT) and times the actor-turn
# path to measure — not guess at — why PURSUE encounters reportedly freeze before the
# first actor moves.
#
# MEASURE ONLY. This probe calls no private setter, mutates no production file, and adds
# no caching. Every "real" number (per-turn wall clock, setup time) comes from an
# unmodified `FlowRuntime.dispatch()` call, exactly the path the player drives. To get a
# breakdown INSIDE `PursueEscapeService.cutoff_cells()` (which FlowRuntime does not itself
# time), this probe makes ONE EXTRA call into the same pure, side-effect-free static
# functions production calls (PursueEscapeService.escape_graph/cutoff_cells,
# MovementPathService.reachable_cost_region), using the exact real inputs read back off
# the live encounter just before the real dispatch. Per PursueEscapeService's own header
# ("PURE... no RNG, no OS time, no mutation of any input, no live actor/combat_state"),
# calling it an extra time cannot change what the real dispatch subsequently computes —
# it only doubles the cost of that one seam for the duration of this probe run, which is
# the price of visibility into a black box we were told not to modify.
#
# Why: FlowRuntime.gd:1627/2742 -> CombatPressureService.build_goals ->
# CombatPressureService._add_pursue -> _cutoff_region -> PursueEscapeService.cutoff_cells
# is reached once per HUNTER actor turn in a PURSUE encounter (quarry's own turn returns
# early — CombatPressureService.gd:265-267). Reading the code suggested O(escape-band-size)
# full-grid flood fills per call, each an O(V^2) linear-frontier-scan BFS
# (MovementPathService._take_lowest_cost_cell has no priority queue). This probe measures
# real counts instead of assuming them.

class_name PursueTimingProbe
extends RefCounted


const REPORT_PATH := "user://pursue_timing_probe_report.txt"
static var _sink: FileAccess = null
## Hard wall-clock budget for the whole probe (this does real flood fills on a
## potentially large board — see the board-size finding in the report below).
const BUDGET_MS := 240000
const ROUNDS_TO_DRIVE := 3


static func register(runner) -> void:
	runner.register_test("pursue_timing_probe/run", func(): return run_all())


static func _say(line: String) -> void:
	print(line)
	if _sink != null:
		_sink.store_line(line)
		_sink.flush()


# ── Top-level driver ─────────────────────────────────────────────────────────

static func run_all() -> Dictionary:
	_sink = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_say("")
	_say("================================================================")
	_say(" PURSUE FREEZE — TIMING PROBE (live FlowRuntime, measure only)")
	_say("================================================================")

	var scenarios: Array = [
		{"label": "PU pursue (5 echoes v 1 fleeing quarry, rank 1)",
		 "mode": EncounterResolutionModes.PURSUE, "enemies": 1, "group": "group.vale_patrol_sm"},
		{"label": "CB plain combat (5 echoes v 4 enemies, rank 1)",
		 "mode": EncounterResolutionModes.COMBAT, "enemies": 4, "group": "group.vale_totem_assault"},
	]

	var t_start: int = Time.get_ticks_msec()
	var reports: Array = []
	for sc_v in scenarios:
		var sc: Dictionary = sc_v
		if Time.get_ticks_msec() - t_start > BUDGET_MS:
			_say("")
			_say("--- BUDGET EXHAUSTED (%d ms) — remaining scenarios skipped." % BUDGET_MS)
			break
		var report: Dictionary = _run_scenario(sc)
		reports.append({"sc": sc, "report": report})
		_print_report(sc, report)

	if reports.size() == 2 and not reports[0]["report"].has("error") and not reports[1]["report"].has("error"):
		_print_headline_comparison(reports[0]["report"], reports[1]["report"])

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
	logger.set_level("info")  # PURSUE on a large board can emit a LOT of debug log volume.
	var config := ConfigService.new()

	# Scenario-specific slot, cleared before boot (including .bak1/.bak2/.bak3 — a bare
	# `rm -f *.json` glob misses those; see SaveService.gd:62-66 for the rotation scheme).
	var slot_path: String = "/tmp/echoes-vnext-tests/pursue_probe_%s.json" % seed_tag
	_clear_slot(slot_path)
	var runtime := FlowRuntime.new(logger, config, slot_path)
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

	# ── Realm + party ────────────────────────────────────────────────────────
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	# PIN THE CAMPAIGN SEED (see FearReachabilityProbe.gd:148-158 for why this matters:
	# an unpinned seed drew a different campaign — and therefore different board
	# generation and party — on every run, making numbers non-reproducible).
	var pinned_root: String = "pursuetimingprobe:%s" % seed_tag
	var pinned_seed: int = absi(pinned_root.hash())
	if not (flow_ctx.save_data.get("campaign", {}) is Dictionary):
		flow_ctx.save_data["campaign"] = {}
	var camp: Dictionary = flow_ctx.save_data["campaign"]
	camp["seed_root"] = pinned_root
	camp["root_seed"] = pinned_seed
	flow_ctx.campaign_seed = CampaignSeed.new(pinned_seed)

	flow_ctx.realm_id = "realm.01"
	if RealmService.get_or_create("realm.01", flow_ctx, t).is_empty():
		return {"error": "realm setup failed"}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.pursuetimingprobe." + seed_tag

	var summ_cfg: Dictionary = bal.get("summoning", {})
	var expr_cfg: Dictionary = bal.get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(
			seed_tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		echo["rank"] = 1
		EmotionService.init_echo(echo, logger, t)
		VectorService.init_vectors(echo, bal.get("vectors", {}), logger, t)
		if not echo.has("emotion") or not (echo["emotion"] is Dictionary):
			echo["emotion"] = {}
		roster.append(echo)
		party_ids.append(str(echo["id"]))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	flow_ctx.dev_combat_objective = str(sc.get("mode", EncounterResolutionModes.COMBAT))
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	# ── Encounter setup — timed separately from the first actor's turn, so a stall can
	# be attributed to one or the other (this is exactly what the report claims: "freezes
	# BEFORE the first actor moves"). ──
	var enc_state := FlowEncounterState.new()
	var t_setup0: int = Time.get_ticks_usec()
	enc_state.enter(flow_ctx, t)
	var t_setup1: int = Time.get_ticks_usec()
	var setup_usec: int = t_setup1 - t_setup0

	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx == null:
		return {"error": "encounter setup failed"}

	# ── Board size actually used — item 6. NOT assumed. ──
	var board_w: int = 10
	var board_h: int = 10
	if not ectx.terrain.is_empty():
		var b: Dictionary = ectx.terrain.get("bounds", {})
		board_w = int(b.get("w", 10))
		board_h = int(b.get("h", 10))
	var capacity: int = board_w * board_h

	var quarry_id: String = ""
	for a_v in ectx.actors:
		if a_v is Dictionary and bool((a_v as Dictionary).get("is_quarry", false)):
			quarry_id = str((a_v as Dictionary).get("id", ""))

	# ── Drive the real round loop, timing every real dispatch. ──
	var breakdown: Dictionary = _new_breakdown()
	var per_turn: Array = []  # [{round, actor_id, is_quarry, ms}]
	var first_turn_ms: float = -1.0

	var t0_init: int = Time.get_ticks_usec()
	runtime.dispatch({"type": "combat.init"})
	var init_usec: int = Time.get_ticks_usec() - t0_init

	var rounds_run: int = 0
	for r in range(ROUNDS_TO_DRIVE):
		if bool(ectx.combat_state.get("combat_over", false)):
			break
		var t0_confirm: int = Time.get_ticks_usec()
		runtime.dispatch({"type": "combat.confirm_round"})
		var confirm_usec: int = Time.get_ticks_usec() - t0_confirm
		if r == 0:
			breakdown["first_confirm_round_usec"] = confirm_usec

		var guard: int = 0
		while guard < 80:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)):
				break
			if str(cs.get("round_phase", "")) != "in_round":
				break

			# Predict who is about to act (replicates FlowRuntime._find_next_living_actor_idx
			# read-only — does not mutate combat_state) so the extra measurement pass below
			# can be taken with the identical actor BEFORE the real dispatch mutates anything.
			var acting: Dictionary = _predict_next_actor(ectx)
			var acting_id: String = str(acting.get("id", ""))
			var acting_is_echo: bool = str(acting.get("faction", "")) == "echo" \
				and not bool(acting.get("is_quarry", false))

			# EXTRA measurement pass — pure, side-effect-free, does not affect what the real
			# dispatch computes a moment later. Only taken for PURSUE hunter turns, which is
			# the ONLY branch that reaches PursueEscapeService.cutoff_cells
			# (CombatPressureService.gd:268 `alignment == "party"`; quarry returns early).
			# EXTRA measurement pass — pure, side-effect-free, does not affect what the real
			# dispatch computes a moment later. Only taken for PURSUE hunter turns, which is
			# the ONLY branch that reaches PursueEscapeService.cutoff_cells
			# (CombatPressureService.gd:268 `alignment == "party"`; quarry returns early).
			var records_before: int = (breakdown["per_actor_records"] as Array).size()
			if str(sc.get("mode", "")) == EncounterResolutionModes.PURSUE and acting_is_echo \
					and not acting.is_empty():
				_measure_prepare_seam(runtime, ectx, acting, r, board_w, board_h, capacity, t, breakdown)

			var t0: int = Time.get_ticks_usec()
			runtime.dispatch({"type": "combat.next_actor"})
			var elapsed_usec: int = Time.get_ticks_usec() - t0
			var ms: float = float(elapsed_usec) / 1000.0
			per_turn.append({"round": r, "actor_id": acting_id, "is_quarry": acting_id == quarry_id, "ms": ms})
			if first_turn_ms < 0.0:
				first_turn_ms = ms
			# Fold the REAL dispatch time onto the record the measurement pass above just
			# appended (same actor, same round). Guarded on the array having actually GROWN
			# this turn — _measure_prepare_seam can return early (e.g. invalid movement
			# context) without appending, and patching a stale record from an earlier turn
			# would silently corrupt the Q2 table.
			var records: Array = breakdown["per_actor_records"]
			if records.size() > records_before:
				(records.back() as Dictionary)["turn_ms"] = ms
		rounds_run += 1

	_sink_flush_safety()

	return {
		"setup_usec": setup_usec,
		"init_usec": init_usec,
		"board_w": board_w,
		"board_h": board_h,
		"capacity": capacity,
		"rounds_run": rounds_run,
		"per_turn": per_turn,
		"first_turn_ms": first_turn_ms,
		"breakdown": breakdown,
		"combat_over": bool(ectx.combat_state.get("combat_over", false)),
		"quarry_id": quarry_id,
	}


static func _sink_flush_safety() -> void:
	if _sink != null:
		_sink.flush()


# ── The extra measurement pass ───────────────────────────────────────────────
# Q1 (full seam breakdown) and Q2 (per-actor outlier data) are gathered in ONE pass
# per hunter turn, using only extra calls into pure, side-effect-free production
# functions with the SAME real inputs the live dispatch is about to use a moment
# later (identical methodology to the pre-existing cutoff breakdown below):
#   A. the FULL _prepare_live_movement_context() seam, called once as a black-box
#      cross-check (this is the "total" every granular step below must sum to)
#   B. a GRANULAR replica of that same function's body — every internal step
#      (_movement_occupancy, _movement_actor_facts, _movement_relationships,
#      _movement_pressure_snapshot, _live_combat_known_hazards, MovementContext.build,
#      _movement_planning_walkable, MovementOptionService._build_control,
#      MovementProfileService.derive_profile, CombatPressureService.build_goals,
#      _movement_live_direct_options) — each timed individually, so the sum of B
#      should land close to A. Any gap is reported, not hidden in a residual bucket.
#   C. escape_graph() / per-escape-cell loop / per-pursuer loop / cutoff_cells() —
#      the pre-existing breakdown of the piece build_goals() spends on cutoff.
#   D. a Q2 per-actor record: capacity, position, distance-to-quarry, goal count/
#      kinds, option count, reachable_cost_region calls this turn, and the actor's
#      agi/calling/dominant_vector — enough to correlate the 10x outlier.
# Every individual MovementPathService.reachable_cost_region() call is timed
# separately and folded into a running total/count (item 4 in the task).

static func _measure_prepare_seam(
	runtime, ectx: EncounterContext, actor: Dictionary, round_idx: int,
	board_w: int, board_h: int, capacity: int, t: int, breakdown: Dictionary
) -> void:
	# V2-INFRA-003 Phase 6 Slice 6G: the live movement helper family moved off FlowRuntime
	# onto LiveMovementContextService. Build the same object FlowRuntime._resolve_next_actor
	# builds (stateless, so a fresh instance is exact) instead of reaching into the runtime.
	var lm := LiveMovementContextService.new(runtime.flow_ctx, runtime.logger)

	# Replicate FlowRuntime._resolve_next_actor's board_cfg construction
	# (FlowRuntime.gd:2600-2649) exactly, read-only.
	var balance: Dictionary = runtime.config_service.get_balance()
	var bdata: Dictionary = balance.get("data", {})
	var grid_cfg: Dictionary = bdata.get("grid", {})
	var movement_board_cfg: Dictionary = grid_cfg
	if not ectx.terrain.is_empty():
		var mv_walkable: Dictionary = StageTerrain.walkable_set(ectx.terrain)
		var mv_bounds: Dictionary = ectx.terrain.get("bounds", {})
		movement_board_cfg = grid_cfg.duplicate(true)
		movement_board_cfg["walkable"] = mv_walkable
		if mv_bounds.has("w"):
			movement_board_cfg["board_cols"] = int(mv_bounds["w"])
		if mv_bounds.has("h"):
			movement_board_cfg["board_rows"] = int(mv_bounds["h"])
	var combat_state: Dictionary = ectx.combat_state

	# A. FULL seam, exactly as FlowRuntime calls it (FlowRuntime.gd:2742) — the
	# cross-check total every granular step in (B) below must sum close to.
	var t_prep0: int = Time.get_ticks_usec()
	var movement_prepared: Dictionary = lm.prepare_live_movement_context(
		actor, ectx, combat_state, movement_board_cfg, bdata, t)
	var t_prep1: int = Time.get_ticks_usec()
	breakdown["prep_calls"] = int(breakdown["prep_calls"]) + 1
	breakdown["prep_usec"] = int(breakdown["prep_usec"]) + (t_prep1 - t_prep0)
	var _per_actor: Dictionary = breakdown["per_actor_prep_usec"]
	var _aid: String = str(actor.get("id", ""))
	if not _per_actor.has(_aid):
		_per_actor[_aid] = []
	(_per_actor[_aid] as Array).append(t_prep1 - t_prep0)

	if not bool(movement_prepared.get("valid", false)):
		return

	# Quarry position, read straight off the live actor list — needed for both the
	# cutoff breakdown (C) and the Q2 distance-to-quarry record (D).
	var quarry_cell: Dictionary = {}
	for a_v0 in ectx.actors:
		if a_v0 is Dictionary and bool((a_v0 as Dictionary).get("is_quarry", false)):
			var qa: Dictionary = a_v0
			if not bool(qa.get("is_dead", false)):
				quarry_cell = qa.get("grid_pos", {}) as Dictionary
			break

	# ── B. Granular replica of _prepare_live_movement_context's own body. Same
	# inputs, same order, each step timed on its own. This is what actually answers
	# "where is the other 76%" instead of only cross-checking build_goals/cutoff. ──
	var movement_cfg: Dictionary = bdata.get("combat", {}).get("movement", {}) as Dictionary
	var capacity_cfg: Dictionary = movement_cfg.get("capacity", {}) as Dictionary
	var pressure_cfg: Dictionary = movement_cfg.get("pressure", {}) as Dictionary
	var bounds: Dictionary = {
		"w": int(movement_board_cfg.get("board_cols", board_w)),
		"h": int(movement_board_cfg.get("board_rows", board_h)),
	}
	var walkable: Dictionary = movement_board_cfg.get("walkable", {}) as Dictionary
	if walkable.is_empty():
		walkable = lm.movement_rect_walkable(bounds)

	var t_occ0: int = Time.get_ticks_usec()
	var occupancy: Dictionary = lm._movement_occupancy(ectx.actors)
	var mover_origin: Dictionary = actor.get("grid_pos", {}) as Dictionary
	if not mover_origin.is_empty():
		occupancy[lm._movement_cell_key_runtime(mover_origin)] = str(actor.get("id", ""))
	var t_occ1: int = Time.get_ticks_usec()
	breakdown["occupancy_calls"] = int(breakdown["occupancy_calls"]) + 1
	breakdown["occupancy_usec"] = int(breakdown["occupancy_usec"]) + (t_occ1 - t_occ0)

	var t_pf0: int = Time.get_ticks_usec()
	var perceived: Array = lm._movement_actor_facts(ectx.actors)
	var t_pf1: int = Time.get_ticks_usec()
	breakdown["actor_facts_calls"] = int(breakdown["actor_facts_calls"]) + 1
	breakdown["actor_facts_usec"] = int(breakdown["actor_facts_usec"]) + (t_pf1 - t_pf0)

	var t_rel0: int = Time.get_ticks_usec()
	var relationships: Dictionary = lm._movement_relationships(actor, perceived)
	var t_rel1: int = Time.get_ticks_usec()
	breakdown["relationships_calls"] = int(breakdown["relationships_calls"]) + 1
	breakdown["relationships_usec"] = int(breakdown["relationships_usec"]) + (t_rel1 - t_rel0)

	var t_pr0: int = Time.get_ticks_usec()
	var pressure: Dictionary = lm._movement_pressure_snapshot(actor, ectx, combat_state, bounds, walkable)
	var t_pr1: int = Time.get_ticks_usec()
	breakdown["pressure_snapshot_calls"] = int(breakdown["pressure_snapshot_calls"]) + 1
	breakdown["pressure_snapshot_usec"] = int(breakdown["pressure_snapshot_usec"]) + (t_pr1 - t_pr0)

	var t_hz0: int = Time.get_ticks_usec()
	var known_hazards: Array = lm._live_combat_known_hazards()
	var t_hz1: int = Time.get_ticks_usec()
	breakdown["known_hazards_calls"] = int(breakdown["known_hazards_calls"]) + 1
	breakdown["known_hazards_usec"] = int(breakdown["known_hazards_usec"]) + (t_hz1 - t_hz0)

	var t_ctx0: int = Time.get_ticks_usec()
	var movement_context: Dictionary = MovementContext.build(
		str(actor.get("id", "")),
		"combat.%s.%s.%d" % [str(ectx.encounter_id), str(actor.get("id", "")), t],
		actor.get("grid_pos", {}) as Dictionary,
		bounds,
		walkable,
		walkable,
		occupancy,
		perceived,
		relationships,
		{},
		known_hazards,
		pressure,
		[]
	)
	var t_ctx1: int = Time.get_ticks_usec()
	breakdown["context_build_calls"] = int(breakdown["context_build_calls"]) + 1
	breakdown["context_build_usec"] = int(breakdown["context_build_usec"]) + (t_ctx1 - t_ctx0)

	var t_pw0: int = Time.get_ticks_usec()
	var planning_walkable_ec: Dictionary = lm._movement_planning_walkable(movement_context)
	var t_pw1: int = Time.get_ticks_usec()
	breakdown["planning_walkable_calls"] = int(breakdown["planning_walkable_calls"]) + 1
	breakdown["planning_walkable_usec"] = int(breakdown["planning_walkable_usec"]) + (t_pw1 - t_pw0)

	var t_cb0: int = Time.get_ticks_usec()
	var control_build: Dictionary = MovementOptionService._build_control(movement_context, planning_walkable_ec)
	var edge_costs: Dictionary = control_build["edge_costs"] as Dictionary
	var edge_sources: Dictionary = control_build["edge_sources"] as Dictionary
	var t_cb1: int = Time.get_ticks_usec()
	breakdown["control_build_calls"] = int(breakdown["control_build_calls"]) + 1
	breakdown["control_build_usec"] = int(breakdown["control_build_usec"]) + (t_cb1 - t_cb0)

	var t_prof0: int = Time.get_ticks_usec()
	var profile: Dictionary = MovementProfileService.derive_profile(actor, capacity_cfg, {})
	var t_prof1: int = Time.get_ticks_usec()
	breakdown["profile_calls"] = int(breakdown["profile_calls"]) + 1
	breakdown["profile_usec"] = int(breakdown["profile_usec"]) + (t_prof1 - t_prof0)

	# build_goals() (contains cutoff_cells) — same bucket the pre-existing breakdown used.
	var t_bg0: int = Time.get_ticks_usec()
	var goals_result: Dictionary = CombatPressureService.build_goals(movement_context, pressure_cfg)
	var t_bg1: int = Time.get_ticks_usec()
	breakdown["build_goals_calls"] = int(breakdown["build_goals_calls"]) + 1
	breakdown["build_goals_usec"] = int(breakdown["build_goals_usec"]) + (t_bg1 - t_bg0)
	var goals_arr: Array = goals_result.get("goals", []) as Array
	(breakdown["goals_count_samples"] as Array).append(goals_arr.size())
	var goal_kinds: Array = []
	var goal_region_sizes: Dictionary = {}   # purpose -> destination_region.size(), THIS turn
	var shortest_path_calls_estimate: int = 0
	var mc_origin: Dictionary = movement_context.get("origin", {}) as Dictionary
	for goal_v in goals_arr:
		var goal: Dictionary = goal_v as Dictionary
		var purpose: String = str(goal.get("purpose", "?"))
		goal_kinds.append(purpose)
		var gkc: Dictionary = breakdown["goal_kind_counts"]
		gkc[purpose] = int(gkc.get(purpose, 0)) + 1
		var dest_region: Array = goal.get("destination_region", []) as Array
		goal_region_sizes[purpose] = dest_region.size()
		# Mirrors _movement_direct_option_for_goal's own early-return: no shortest_path
		# calls for a "hold" goal whose region already contains the mover's origin.
		if dest_region.has(mc_origin) and purpose == "hold":
			continue
		shortest_path_calls_estimate += dest_region.size()
	breakdown["option_gen_shortest_path_calls_total"] = \
		int(breakdown["option_gen_shortest_path_calls_total"]) + shortest_path_calls_estimate

	# Option generation for those goals — the part of the seam build_goals does NOT
	# cover: shortest-path search PER destination cell PER goal.
	var options: Array = []
	var option_gen_usec_this_turn: int = 0
	if bool(goals_result.get("valid", false)) and not bool(actor.get("is_quarry", false)) \
			and not goals_arr.is_empty():
		var t_opt0: int = Time.get_ticks_usec()
		options = lm._movement_live_direct_options(movement_context, profile, goals_arr, edge_costs, edge_sources)
		var t_opt1: int = Time.get_ticks_usec()
		option_gen_usec_this_turn = t_opt1 - t_opt0
		breakdown["option_gen_calls"] = int(breakdown["option_gen_calls"]) + 1
		breakdown["option_gen_usec"] = int(breakdown["option_gen_usec"]) + option_gen_usec_this_turn

	# ── D. Q2 per-actor record — capacity, position, distance-to-quarry, goals,
	# options, and the actor's own stats. region_calls_this_turn is filled in after
	# section C below runs (it needs the region-call counter's before/after delta). ──
	var stats: Dictionary = actor.get("stats", {}) as Dictionary
	var dist_to_quarry: int = -1
	if not quarry_cell.is_empty() and not mover_origin.is_empty():
		dist_to_quarry = maxi(
			absi(int(mover_origin.get("col", 0)) - int(quarry_cell.get("col", 0))),
			absi(int(mover_origin.get("row", 0)) - int(quarry_cell.get("row", 0)))
		)
	var record: Dictionary = {
		"round": round_idx,
		"actor_id": _aid,
		"turn_ms": -1.0,  # filled in by the caller right after the real dispatch
		"capacity": int(profile.get("capacity", -1)),
		"pos": mover_origin.duplicate(true),
		"dist_to_quarry": dist_to_quarry,
		"goals_count": goals_arr.size(),
		"goal_kinds": goal_kinds,
		"options_count": options.size(),
		"region_calls_this_turn": 0,  # patched below, after (C)
		"agi": int(stats.get("agi", -1)),
		"calling": str(actor.get("calling", actor.get("calling_origin", ""))),
		"dominant_vector": str(actor.get("dominant_vector", "")),
		# THIS turn's own split of the two biggest Q1 buckets — proves (not infers)
		# which step actually dominates THIS actor's time, rather than relying only
		# on the aggregate breakdown across all actors.
		"build_goals_ms_this_turn": float(t_bg1 - t_bg0) / 1000.0,
		"option_gen_ms_this_turn": float(option_gen_usec_this_turn) / 1000.0,
		"shortest_path_calls_this_turn": shortest_path_calls_estimate,
		"pursue_region_size": int(goal_region_sizes.get("pursue", 0)),
		"cut_off_region_size": int(goal_region_sizes.get("cut_off", 0)),
	}
	(breakdown["per_actor_records"] as Array).append(record)

	if quarry_cell.is_empty():
		return  # Quarry dead/gone — cutoff_cells would not be meaningfully called either.
	var mc: Dictionary = movement_context
	var origin: Dictionary = mc.get("origin", {})
	var region_calls_before: int = int(breakdown["region_calls_total"])

	# Structure blockers — CombatPressureService._structure_blockers scans
	# perceived actors for is_structure && !is_dead. A PURSUE encounter spawns no shrine
	# (FlowEncounterState.gd:141-143 clears the regular enemy group and adds only the
	# quarry), so this is expected to be empty; verified directly off live actors rather
	# than assumed.
	var blockers: Array = []
	for a_v2 in ectx.actors:
		if a_v2 is Dictionary and bool((a_v2 as Dictionary).get("is_structure", false)) \
				and not bool((a_v2 as Dictionary).get("is_dead", false)):
			blockers.append(((a_v2 as Dictionary).get("grid_pos", {}) as Dictionary).duplicate(true))

	# 2. escape_graph() alone.
	var t_g0: int = Time.get_ticks_usec()
	var graph: Dictionary = PursueEscapeService.escape_graph(quarry_cell, bounds, walkable, blockers)
	var t_g1: int = Time.get_ticks_usec()
	breakdown["graph_calls"] = int(breakdown["graph_calls"]) + 1
	breakdown["graph_usec"] = int(breakdown["graph_usec"]) + (t_g1 - t_g0)
	breakdown["region_calls_total"] = int(breakdown["region_calls_total"]) + 1
	breakdown["region_usec_total"] = int(breakdown["region_usec_total"]) + (t_g1 - t_g0)

	var raw_escape_cells: Array = PursueEscapeService.escape_cells(bounds, walkable)
	(breakdown["escape_cells_raw_samples"] as Array).append(raw_escape_cells.size())

	if not bool(graph.get("reachable", false)):
		(breakdown["escape_cells_reachable_samples"] as Array).append(0)
		record["region_calls_this_turn"] = int(breakdown["region_calls_total"]) - region_calls_before
		return
	var escapes: Array = graph.get("escape_cells", [])
	(breakdown["escape_cells_reachable_samples"] as Array).append(escapes.size())

	var eff_walkable: Dictionary = PursueEscapeService._effective_walkable(walkable, blockers, bounds)

	# 3. Per-escape-cell loop — each individual reachable_cost_region call timed and
	# folded into the running total separately from the loop's own bookkeeping overhead.
	var t_loop0: int = Time.get_ticks_usec()
	for ec_v in escapes:
		var ec: Dictionary = ec_v if ec_v is Dictionary else {}
		var t_r0: int = Time.get_ticks_usec()
		MovementPathService.reachable_cost_region(ec, capacity, eff_walkable, {}, bounds, {})
		var t_r1: int = Time.get_ticks_usec()
		breakdown["region_calls_total"] = int(breakdown["region_calls_total"]) + 1
		breakdown["region_usec_total"] = int(breakdown["region_usec_total"]) + (t_r1 - t_r0)
	var t_loop1: int = Time.get_ticks_usec()
	breakdown["escape_loop_calls"] = int(breakdown["escape_loop_calls"]) + 1
	breakdown["escape_loop_usec"] = int(breakdown["escape_loop_usec"]) + (t_loop1 - t_loop0)
	breakdown["escape_loop_region_calls"] = int(breakdown["escape_loop_region_calls"]) + escapes.size()

	# 4. Per-pursuer loop — production ALWAYS passes exactly ONE pursuer here:
	# `[context["origin"] as Dictionary]` at CombatPressureService.gd:509, i.e. the
	# CURRENT actor's own cell. It does NOT pass the whole party. Measured, not assumed.
	var pursuers: Array = [origin]
	(breakdown["pursuer_count_samples"] as Array).append(pursuers.size())
	var t_pur0: int = Time.get_ticks_usec()
	for p_v in pursuers:
		var p_cell: Dictionary = p_v if p_v is Dictionary else {}
		var t_r2: int = Time.get_ticks_usec()
		MovementPathService.reachable_cost_region(p_cell, capacity, eff_walkable, {}, bounds, {})
		var t_r3: int = Time.get_ticks_usec()
		breakdown["region_calls_total"] = int(breakdown["region_calls_total"]) + 1
		breakdown["region_usec_total"] = int(breakdown["region_usec_total"]) + (t_r3 - t_r2)
	var t_pur1: int = Time.get_ticks_usec()
	breakdown["pursuer_loop_calls"] = int(breakdown["pursuer_loop_calls"]) + 1
	breakdown["pursuer_loop_usec"] = int(breakdown["pursuer_loop_usec"]) + (t_pur1 - t_pur0)
	breakdown["pursuer_loop_region_calls"] = int(breakdown["pursuer_loop_region_calls"]) + pursuers.size()

	# 5. Full cutoff_cells() as one unit — cross-check against (2)+(3)+(4).
	var t_c0: int = Time.get_ticks_usec()
	PursueEscapeService.cutoff_cells(quarry_cell, bounds, walkable, pursuers, blockers)
	var t_c1: int = Time.get_ticks_usec()
	breakdown["cutoff_calls"] = int(breakdown["cutoff_calls"]) + 1
	breakdown["cutoff_usec"] = int(breakdown["cutoff_usec"]) + (t_c1 - t_c0)

	# Patch the Q2 record now that every region call this turn has been counted
	# (escape_graph + per-escape-cell loop + per-pursuer loop; cutoff_cells() itself
	# is the (5) cross-check above and is NOT double-counted into region_calls_total).
	record["region_calls_this_turn"] = int(breakdown["region_calls_total"]) - region_calls_before


static func _new_breakdown() -> Dictionary:
	return {
		"prep_calls": 0, "prep_usec": 0,
		# ── Q1: granular replica of _prepare_live_movement_context's own body ──
		"occupancy_calls": 0, "occupancy_usec": 0,
		"actor_facts_calls": 0, "actor_facts_usec": 0,
		"relationships_calls": 0, "relationships_usec": 0,
		"pressure_snapshot_calls": 0, "pressure_snapshot_usec": 0,
		"known_hazards_calls": 0, "known_hazards_usec": 0,
		"context_build_calls": 0, "context_build_usec": 0,
		"planning_walkable_calls": 0, "planning_walkable_usec": 0,
		"control_build_calls": 0, "control_build_usec": 0,
		"profile_calls": 0, "profile_usec": 0,
		"build_goals_calls": 0, "build_goals_usec": 0,
		"option_gen_calls": 0, "option_gen_usec": 0,
		"option_gen_shortest_path_calls_total": 0,
		"goal_kind_counts": {},   # purpose -> count, aggregate across all measured turns
		# ── cutoff_cells() internal breakdown (pre-existing) ──
		"graph_calls": 0, "graph_usec": 0,
		"escape_loop_calls": 0, "escape_loop_usec": 0, "escape_loop_region_calls": 0,
		"pursuer_loop_calls": 0, "pursuer_loop_usec": 0, "pursuer_loop_region_calls": 0,
		"cutoff_calls": 0, "cutoff_usec": 0,
		"region_calls_total": 0, "region_usec_total": 0,
		"escape_cells_raw_samples": [],
		"escape_cells_reachable_samples": [],
		"pursuer_count_samples": [],
		"goals_count_samples": [],
		"per_actor_prep_usec": {},   # actor_id -> [usec, usec, ...] — to correlate outliers
		"per_actor_records": [],    # Q2: one record per measured turn — see _measure_prepare_seam
		"first_confirm_round_usec": 0,
	}


## Read-only replica of FlowRuntime._find_next_living_actor_idx + the actor lookup —
## does not touch combat_state.
static func _predict_next_actor(ectx: EncounterContext) -> Dictionary:
	var order: Array = ectx.combat_state.get("initiative_order", [])
	var start: int = int(ectx.combat_state.get("current_actor_index", 0))
	for i in range(start, order.size()):
		var aid: String = str((order[i] as Dictionary).get("id", ""))
		for a_v in ectx.actors:
			if a_v is Dictionary and str((a_v as Dictionary).get("id", "")) == aid \
					and not bool((a_v as Dictionary).get("is_dead", false)):
				return a_v
	return {}


static func _clear_slot(path: String) -> void:
	for suffix: String in ["", ".tmp", ".bak", ".bak1", ".bak2", ".bak3"]:
		var target: String = path + suffix
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)


# ── Reporting ────────────────────────────────────────────────────────────────

static func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s: float = 0.0
	for v in arr:
		s += float(v)
	return s / float(arr.size())


static func _print_report(sc: Dictionary, r: Dictionary) -> void:
	_say("")
	_say("--- %s" % str(sc.get("label", "?")))
	if r.has("error"):
		_say("    ERROR: %s" % str(r["error"]))
		return

	_say("    board actually used: %dx%d (capacity %d cells)" % [int(r["board_w"]), int(r["board_h"]), int(r["capacity"])])
	_say("    setup (FlowEncounterState.enter): %.2f ms" % (float(r["setup_usec"]) / 1000.0))
	_say("    combat.init dispatch: %.2f ms" % (float(r["init_usec"]) / 1000.0))
	_say("    rounds actually run: %d   combat_over=%s" % [int(r["rounds_run"]), str(r["combat_over"])])

	var per_turn: Array = r["per_turn"]
	if per_turn.is_empty():
		_say("    (no actor turns were driven)")
		return

	var all_ms: Array = []
	for e_v in per_turn:
		all_ms.append(float((e_v as Dictionary)["ms"]))
	_say("    turns driven: %d   first turn: %.2f ms   avg turn: %.2f ms   max turn: %.2f ms"
		% [all_ms.size(), float(r["first_turn_ms"]), _avg(all_ms), all_ms.max()])

	var lines: Array = []
	for e_v in per_turn:
		var e: Dictionary = e_v
		lines.append("r%d/%s%s=%.1fms" % [int(e["round"]), str(e["actor_id"]),
			(" (quarry)" if bool(e["is_quarry"]) else ""), float(e["ms"])])
	_say("    per-turn: %s" % ", ".join(PackedStringArray(lines)))

	var bd: Dictionary = r["breakdown"]
	if int(bd.get("cutoff_calls", 0)) == 0:
		_say("    (no cutoff_cells breakdown — mode does not reach PursueEscapeService)")
		return

	_say("")
	_say("    --- cutoff_cells() breakdown (measured via an extra, pure, side-effect-free")
	_say("        call using the SAME real inputs the live dispatch used) ---")
	_say("    cutoff_cells() calls this run: %d   total: %.2f ms   avg/call: %.3f ms"
		% [int(bd["cutoff_calls"]), float(bd["cutoff_usec"]) / 1000.0,
		   float(bd["cutoff_usec"]) / 1000.0 / maxf(1.0, float(bd["cutoff_calls"]))])
	_say("    full _prepare_live_movement_context() seam: %d calls, total %.2f ms, avg %.3f ms"
		% [int(bd["prep_calls"]), float(bd["prep_usec"]) / 1000.0,
		   float(bd["prep_usec"]) / 1000.0 / maxf(1.0, float(bd["prep_calls"]))])
	_say("")
	_say("    real counts (not assumed):")
	_say("        escape_cells() raw band size:        avg %.1f  (samples: %s)"
		% [_avg(bd["escape_cells_raw_samples"]), str(bd["escape_cells_raw_samples"])])
	_say("        reachable escape cells (used by cutoff): avg %.1f  (samples: %s)"
		% [_avg(bd["escape_cells_reachable_samples"]), str(bd["escape_cells_reachable_samples"])])
	_say("        pursuers passed to cutoff_cells:     avg %.1f  (samples: %s)"
		% [_avg(bd["pursuer_count_samples"]), str(bd["pursuer_count_samples"])])
	_say("        reachable_cost_region calls per cutoff_cells call: %.1f (1 escape_graph + escape-cell loop + pursuer loop)"
		% (float(bd["region_calls_total"]) / maxf(1.0, float(bd["cutoff_calls"]))))

	_say("")
	_say("    three-way time split (per cutoff_cells call, averaged):")
	var n: float = maxf(1.0, float(bd["cutoff_calls"]))
	var g_ms: float = float(bd["graph_usec"]) / 1000.0 / n
	var el_ms: float = float(bd["escape_loop_usec"]) / 1000.0 / n
	var pl_ms: float = float(bd["pursuer_loop_usec"]) / 1000.0 / n
	var total_ms: float = g_ms + el_ms + pl_ms
	_say("        escape_graph()        : %6.3f ms/call  (%.0f%% of the 3 groups)" % [g_ms, 100.0 * g_ms / maxf(0.001, total_ms)])
	_say("        per-escape-cell loop  : %6.3f ms/call  (%.0f%% of the 3 groups)  [%d region calls total, %.1f/call]"
		% [el_ms, 100.0 * el_ms / maxf(0.001, total_ms), int(bd["escape_loop_region_calls"]),
		   float(bd["escape_loop_region_calls"]) / n])
	_say("        per-pursuer loop      : %6.3f ms/call  (%.0f%% of the 3 groups)  [%d region calls total, %.1f/call]"
		% [pl_ms, 100.0 * pl_ms / maxf(0.001, total_ms), int(bd["pursuer_loop_region_calls"]),
		   float(bd["pursuer_loop_region_calls"]) / n])

	_say("")
	_say("    reachable_cost_region() itself: %d calls, total %.2f ms, avg %.4f ms/call"
		% [int(bd["region_calls_total"]), float(bd["region_usec_total"]) / 1000.0,
		   float(bd["region_usec_total"]) / 1000.0 / maxf(1.0, float(bd["region_calls_total"]))])

	_print_q1_full_breakdown(bd)
	_print_q2_outlier_table(bd)


## Q1 — full breakdown of _prepare_live_movement_context(), summing to the measured
## total. Every named bucket below is an INDIVIDUAL extra call into the exact same
## pure production step the black-box call (A) makes internally, using the SAME real
## inputs, so the sum should land close to the black-box total. The gap (if any) is
## printed explicitly rather than folded into a residual bucket.
static func _print_q1_full_breakdown(bd: Dictionary) -> void:
	_say("")
	_say("    ================================================================")
	_say("    Q1 — full _prepare_live_movement_context() breakdown")
	_say("    (black-box total (A) vs sum of every granular step (B), same inputs)")
	_say("    ================================================================")
	var prep_calls: float = maxf(1.0, float(bd["prep_calls"]))
	var total_ms: float = float(bd["prep_usec"]) / 1000.0
	_say("    (A) black-box _prepare_live_movement_context(): %d calls, total %.2f ms, avg %.3f ms/call"
		% [int(bd["prep_calls"]), total_ms, total_ms / prep_calls])

	var buckets: Array = [
		["_movement_occupancy",              "occupancy_usec"],
		["_movement_actor_facts",             "actor_facts_usec"],
		["_movement_relationships",           "relationships_usec"],
		["_movement_pressure_snapshot",       "pressure_snapshot_usec"],
		["_live_combat_known_hazards",        "known_hazards_usec"],
		["MovementContext.build",             "context_build_usec"],
		["_movement_planning_walkable",       "planning_walkable_usec"],
		["MovementOptionService._build_control (hostile edge costs)", "control_build_usec"],
		["MovementProfileService.derive_profile", "profile_usec"],
		["CombatPressureService.build_goals (incl. cutoff_cells)", "build_goals_usec"],
		["_movement_live_direct_options (option gen)", "option_gen_usec"],
	]
	var granular_sum_usec: int = 0
	for b_v in buckets:
		granular_sum_usec += int(bd[str(b_v[1])])
	var granular_sum_ms: float = float(granular_sum_usec) / 1000.0

	_say("    (B) sum of every granular step below: %.2f ms  (%.1f%% of the black-box total)"
		% [granular_sum_ms, 100.0 * granular_sum_ms / maxf(0.001, total_ms)])
	var gap_ms: float = total_ms - granular_sum_ms
	if absf(gap_ms) > maxf(1.0, 0.05 * total_ms):
		_say("    GAP: %.2f ms (%.1f%%) of the black-box total is NOT accounted for by any"
			% [gap_ms, 100.0 * gap_ms / maxf(0.001, total_ms)])
		_say("         named step below — real, not hidden in a residual bucket. Likely causes:")
		_say("         double-measurement variance between the two extra calls (A and B run")
		_say("         back-to-back on identical inputs so should be close), or a step this")
		_say("         probe did not name.")
	else:
		_say("    GAP: %.2f ms (%.1f%%) — within measurement noise of the two extra calls." % [gap_ms, 100.0 * gap_ms / maxf(0.001, total_ms)])

	_say("")
	_say("    per-step breakdown (each row = one extra, pure, side-effect-free call per")
	_say("    hunter turn; % is of the granular sum (B), not of the black-box total (A)):")
	for b_v in buckets:
		var label: String = str(b_v[0])
		var key: String = str(b_v[1])
		var usec: int = int(bd[key])
		var calls: int = int(bd[key.replace("_usec", "_calls")]) if bd.has(key.replace("_usec", "_calls")) else int(prep_calls)
		var ms: float = float(usec) / 1000.0
		var pct: float = 100.0 * ms / maxf(0.001, granular_sum_ms)
		_say("        %-58s %8.2f ms  %5.1f%%  (%d calls, %.4f ms/call)"
			% [label, ms, pct, calls, ms / maxf(1.0, float(calls))])

	_say("")
	_say("    build_goals() itself contains cutoff_cells() — cutoff_usec (%.2f ms) is a"
		% (float(bd["cutoff_usec"]) / 1000.0))
	_say("    SUBSET of build_goals_usec (%.2f ms) above, not an additional cost."
		% (float(bd["build_goals_usec"]) / 1000.0))

	_say("")
	_say("    goal kinds seen across all measured hunter turns (purpose -> count):")
	var gkc: Dictionary = bd["goal_kind_counts"]
	var kinds: Array = gkc.keys()
	kinds.sort()
	for k_v in kinds:
		_say("        %-12s %d" % [str(k_v), int(gkc[k_v])])
	_say("    estimated shortest_path() calls inside option generation (sum of every goal's")
	_say("    destination_region size, mirroring _movement_direct_option_for_goal's own loop):")
	_say("        %d calls total across all measured hunter turns" % int(bd["option_gen_shortest_path_calls_total"]))


## Q2 — per-actor table to find what tracks the 10x outlier.
static func _print_q2_outlier_table(bd: Dictionary) -> void:
	var records: Array = bd["per_actor_records"]
	if records.is_empty():
		return
	_say("")
	_say("    ================================================================")
	_say("    Q2 — per-actor outlier table (one row per measured hunter turn)")
	_say("    ================================================================")
	_say("    %-4s %-10s %8s %6s %8s %10s %6s %6s %6s %5s %-10s %-12s %s"
		% ["rnd", "actor", "turn_ms", "cap", "pos", "dist2qry", "goals", "opts", "rgncal", "agi", "calling", "dom_vector", "goal_kinds"])
	for rec_v in records:
		var rec: Dictionary = rec_v
		var pos: Dictionary = rec.get("pos", {}) as Dictionary
		var pos_str: String = "%d,%d" % [int(pos.get("col", -1)), int(pos.get("row", -1))]
		var kinds_str: String = ",".join(PackedStringArray(rec.get("goal_kinds", []) as Array))
		_say("    %-4d %-10s %8.1f %6d %8s %10d %6d %6d %6d %5d %-10s %-12s %s"
			% [int(rec["round"]), str(rec["actor_id"]), float(rec["turn_ms"]), int(rec["capacity"]),
			   pos_str, int(rec["dist_to_quarry"]), int(rec["goals_count"]), int(rec["options_count"]),
			   int(rec["region_calls_this_turn"]), int(rec["agi"]), str(rec["calling"]), str(rec["dominant_vector"]),
			   kinds_str])

	# This turn's own split between the two biggest Q1 buckets (build_goals/cutoff vs
	# option generation) — proves, per actor, which step actually dominates rather than
	# relying only on the aggregate Q1 breakdown across every actor combined.
	_say("")
	_say("    per-turn split of the two dominant Q1 buckets (proves WHICH step dominates")
	_say("    for THIS actor, not just in aggregate):")
	_say("    %-4s %-10s %10s %14s %14s %10s %12s %12s" % ["rnd", "actor", "dist2qry", "build_goals_ms",
		"option_gen_ms", "sp_calls", "pursue_rgn", "cutoff_rgn"])
	for rec_v in records:
		var rec: Dictionary = rec_v
		_say("    %-4d %-10s %10d %14.2f %14.2f %10d %12d %12d"
			% [int(rec["round"]), str(rec["actor_id"]), int(rec["dist_to_quarry"]),
			   float(rec["build_goals_ms_this_turn"]), float(rec["option_gen_ms_this_turn"]),
			   int(rec["shortest_path_calls_this_turn"]), int(rec["pursue_region_size"]), int(rec["cut_off_region_size"])])

	# Correlation check: does turn_ms track dist_to_quarry (or any other column) more
	# than it tracks anything else? Reported as sorted extremes, not a forced story.
	var by_ms: Array = records.duplicate()
	by_ms.sort_custom(func(a, b): return float((a as Dictionary)["turn_ms"]) > float((b as Dictionary)["turn_ms"]))
	_say("")
	_say("    slowest measured turns, fastest first correlate column to eyeball:")
	var top_n: int = mini(6, by_ms.size())
	for i in range(top_n):
		var rec: Dictionary = by_ms[i]
		_say("        #%d  %s  turn=%.1fms  dist_to_quarry=%d  cap=%d  options=%d  region_calls=%d  agi=%d  option_gen_ms=%.1f  build_goals_ms=%.1f"
			% [i + 1, str(rec["actor_id"]), float(rec["turn_ms"]), int(rec["dist_to_quarry"]),
			   int(rec["capacity"]), int(rec["options_count"]), int(rec["region_calls_this_turn"]), int(rec["agi"]),
			   float(rec["option_gen_ms_this_turn"]), float(rec["build_goals_ms_this_turn"])])


static func _print_headline_comparison(pursue_r: Dictionary, combat_r: Dictionary) -> void:
	_say("")
	_say("================================================================")
	_say(" HEADLINE: PURSUE vs COMBAT, one actor turn")
	_say("================================================================")
	var p_all: Array = []
	for e_v in (pursue_r["per_turn"] as Array):
		p_all.append(float((e_v as Dictionary)["ms"]))
	var c_all: Array = []
	for e_v in (combat_r["per_turn"] as Array):
		c_all.append(float((e_v as Dictionary)["ms"]))
	_say("    PURSUE  board %dx%d  first turn %.2f ms  avg turn %.2f ms  max turn %.2f ms"
		% [int(pursue_r["board_w"]), int(pursue_r["board_h"]), float(pursue_r["first_turn_ms"]), _avg(p_all),
		   (p_all.max() if not p_all.is_empty() else 0.0)])
	_say("    COMBAT  board %dx%d  first turn %.2f ms  avg turn %.2f ms  max turn %.2f ms"
		% [int(combat_r["board_w"]), int(combat_r["board_h"]), float(combat_r["first_turn_ms"]), _avg(c_all),
		   (c_all.max() if not c_all.is_empty() else 0.0)])
	if _avg(c_all) > 0.0:
		_say("    PURSUE avg turn is %.1fx COMBAT avg turn" % (_avg(p_all) / _avg(c_all)))
