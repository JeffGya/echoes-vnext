# res://tests/FlowFingerprintTests.gd
# V2-INFRA-003 — CHARACTERIZATION harness for the seven encounter resolution modes.
#
# Purpose: record CURRENT combat behaviour (bugs included) as a set of stable, deterministic
# fingerprints (sha256 hashes over a canonical JSON projection), so a later phase can prove its
# refactor is byte-identical. This file fixes nothing — it only observes and hashes.
#
# Determinism:
#   - Each mode gets its own isolated save file under /tmp/echoes-vnext-tests/, deleted before
#     every run so a leftover file from a prior suite run can never leak state across runs
#     (lesson: docs/LESSONS.md #12 — never touch the production save).
#   - A brand-new save always gets root_seed 12346 (SaveService.make_new_save literal — see
#     FlowRuntime.boot()), so the campaign seed is pinned without this file needing to touch it.
#   - Starting Ase/Ekwan are set DIRECTLY on the save dict (tests/AGENTS.md rule) — never via
#     EconomyService.add_ase()/spend_ase().
#   - Each of the seven modes is forced via FlowContext.dev_combat_objective (and, for
#     GUIDE_SPIRIT, dev_guide_mode/dev_guide_joins). These are draw-then-override: the seeded
#     RNG draw always runs first, so forcing the mode does not shift any RNG draw order.
#
# KNOWN GAP (documented, not fabricated):
#   The task spec asks for "goal id, option id" per round. Neither is exposed anywhere outside
#   FlowRuntime._resolve_next_actor()'s private locals: the selected MovementIntent (which
#   carries goal_id/option_id) is a local variable, never written to EncounterContext, and no
#   logger call in core/runtime/FlowRuntime.gd or core/movement/*.gd emits those two fields for
#   the general per-actor turn (grep confirms core/movement/*.gd and core/actors/behaviors/*.gd
#   take no logger at all). The two files this story may touch do not include FlowRuntime.gd, so
#   this cannot be instrumented without violating the touch-list. What IS captured instead, per
#   round, per actor turn: the resolved action_type, target_id, damage, is_kill (from
#   EncounterContext.last_round_results, which resets each round) and movement facts (from_pos/
#   to_pos per acting actor, plus every actor's grid_pos at round end) — the full externally
#   observable behaviour surface. GUIDE_SPIRIT's spirit-only goal_id is the one exception: its
#   value is fully determined by combat_state flags (escort_started/destination_reached/
#   spirit_joins_battle), which ARE captured in mode_state, so that mode's decision path is
#   still faithfully fingerprinted even though the literal string "guide.escort" is not.
#
# Stability proof: run the suite twice (see BUILD report) and diff the FlowFingerprintTests
# lines of console output — byte-identical across runs proves the fingerprints are stable.
#
# FIX (post-initial-record): the final fingerprint originally omitted the "objective_state"
# field of the flow.resolve snapshot data. objective_state.type IS combat_state["objective"]
# (the resolution_mode string itself), plus mode-specific progress counters (contain_progress,
# protect_progress, guide_mode, etc.) — the actual mode-discriminating surface. Without it,
# two structurally different modes that both happen to conclude via the universal
# "all_enemies_defeated" win condition (observed for COMBAT and PURSUE, where the quarry can
# simply die like any other enemy before the contain/escape window ever fires) hashed
# identically. _final_fingerprint() now includes objective_state so the final hash can no
# longer fail to distinguish two modes.
#
# FIX (V2-COMBAT-003 Phase 2a): combat.confirm_round resolves the FIRST actor of the round
# itself (FlowRuntime.gd:1279, via _resolve_next_actor called from _handle_combat_confirm_round)
# and resets ectx.last_round_results = [] immediately before doing so (FlowRuntime.gd:1269).
# _drive_and_capture() dispatched confirm_round and then only sampled combat.next_actor, so the
# first actor of every single round was resolved by the real simulation but never appeared in
# any captured trace — measured: one Echo was first in initiative every round of a four-round
# trace and appeared in ZERO captured turns. _drive_and_capture() now reads
# ectx.last_round_results immediately after the confirm_round dispatch and records that first
# turn before entering the next_actor loop. No production file changed; no dispatch was added
# or removed on the path into any encounter (see FlowRuntime.gd's own comment at the
# CombatTurnActionService call site: "Exactly one last_round_results entry is still appended per
# call" — so the read added here can only ever pick up the one turn confirm_round itself just
# resolved).
#
# What moved and the additive proof are recorded immediately above the seven per-mode hash
# blocks below, next to the constants themselves, once the actual before/after values were in
# hand — not asserted here ahead of measuring them.

class_name FlowFingerprintTests
extends RefCounted



static func register(runner) -> void:
	runner.register_test("fingerprint/combat", func(): return test_combat())
	runner.register_test("fingerprint/purify_shrine", func(): return test_purify_shrine())
	runner.register_test("fingerprint/recover", func(): return test_recover())
	runner.register_test("fingerprint/protect", func(): return test_protect())
	runner.register_test("fingerprint/endure", func(): return test_endure())
	runner.register_test("fingerprint/pursue", func(): return test_pursue())
	runner.register_test("fingerprint/guide_spirit", func(): return test_guide_spirit())
	# Mechanical proof of same-process determinism for all seven modes, on every suite run:
	# each mode's setup+drive runs twice back-to-back and is diffed round-by-round, turn-by-turn.
	# Complements (does not replace) the "run the whole suite twice externally" stability proof.
	runner.register_test("fingerprint/determinism_self_check", func(): return test_determinism_self_check())


# ---------------------------------------------------------------------------
# Shared harness
# ---------------------------------------------------------------------------

## Fresh, isolated FlowRuntime + 5-echo party for one resolution mode.
## Deletes any leftover save file at this path first — guarantees root_seed 12346 every run
## (SaveService.make_new_save literal seed on a genuinely missing save) regardless of how many
## times the suite has already run against this same path.
## rank_overrides: OPTIONAL, {roster_index: int -> target_rank: int}. Default {} — every
## existing call site keeps generating five rank-1 Echoes exactly as before, so no recorded
## fingerprint moves. When present, the named roster index is raised to target_rank through the
## real production rank-up function (ProgressionService.execute_rank_up), looped one Standing at
## a time exactly as sanctum.rank_up would drive it — NOT by writing echo["rank"] directly. The
## one synthetic step: is_rank_up_eligible() gates on echo["level"], and reaching max_level_per_rank
## through real combat XP would take many encounters, so level is set directly to max_level_per_rank
## before each iteration rather than earned. (V2-COMBAT-003 Phase 3 — see
## tests/CombatMaturityBaselineTests.gd for why this exists: no recorded fixture anywhere in the
## suite previously held a Whole-band Echo.)
static func _setup_encounter(
	mode: String,
	seed_tag: String,
	guide_mode: String = "",
	guide_joins: String = "",
	rank_overrides: Dictionary = {}
) -> Dictionary:
	# Shared harness: clears the primary save AND SaveService's backup chain beside it.
	# Primary-only deletion let boot() recover a previous run's campaign. See
	# tests/TestSaveHarness.gd.
	var save_path: String = TestSaveHarness.fresh_save_path("flow_fingerprint_%s.json" % seed_tag)

	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, save_path)
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, t)
	if rm.is_empty():
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.%s" % seed_tag

	# Isolated, deterministic starting balances — set DIRECTLY on the save dict.
	# Never EconomyService.add_ase()/spend_ase() here (that adds on top of whatever the save
	# already holds — non-deterministic across repeated suite runs against the same tmp file).
	flow_ctx.save_data["economy"]["ase"]   = 0
	flow_ctx.save_data["economy"]["ekwan"] = 0

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var vec_cfg: Dictionary = bal.get("data", {}).get("vectors", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(seed_tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		# V2-COMBAT-003 Phase 2b: production-shaped fixture. EchoFactory.generate() deliberately
		# leaves emotion/vector_scores/dominant_vector unpopulated (see EchoFactory.gd:98-101) —
		# the real summon path (SanctumController.gd:223-225, OnboardingController.gd:237-238)
		# always calls these two immediately afterwards. Skipping them (as this fixture did
		# before) gives every Echo dominant_vector="" and vector_scores={}, which silently
		# disables the vector half of BehaviorArbiter._score() (ANSWERS.md #50).
		EmotionService.init_echo(echo, logger, t)
		VectorService.init_vectors(echo, vec_cfg, logger, t)
		if rank_overrides.has(i):
			_promote_echo_rank(echo, int(rank_overrides[i]), bal, flow_ctx.campaign_seed, logger, t)
		roster.append(echo)
		party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	# Force the mode. Draw-then-override: FlowEncounterState.enter() still runs the seeded
	# mode roll and only swaps the result afterward, so RNG draw order is unshifted.
	flow_ctx.dev_combat_objective = mode
	if not guide_mode.is_empty():
		flow_ctx.dev_guide_mode = guide_mode
	if not guide_joins.is_empty():
		flow_ctx.dev_guide_joins = guide_joins
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	if flow_ctx.encounter_ctx == null:
		return {}

	return {
		"runtime":   runtime,
		"flow_ctx":  flow_ctx,
		"ectx":      flow_ctx.encounter_ctx,
		"party_ids": party_ids,
	}


## Raises one echo dict's Standing to target_rank through the real production rank-up path,
## ProgressionService.execute_rank_up(), called once per Standing exactly as sanctum.rank_up
## drives it (core/runtime/controllers/ProgressionController.gd:handle_rank_up). Mutates echo
## in place. No-op if target_rank <= current rank.
##
## The one non-production step: is_rank_up_eligible() reads echo["level"], and earning
## max_level_per_rank through real combat XP would take many played encounters, so level is set
## directly to max_level_per_rank before each iteration instead of earned via
## ProgressionService.award_post_combat_xp(). Rank itself is never written directly — every
## Standing gain, trait drift, calling_eligible flag and derived-stat recompute goes through
## execute_rank_up() unmodified.
static func _promote_echo_rank(
	echo: Dictionary,
	target_rank: int,
	bal: Dictionary,
	campaign_seed,
	logger,
	t: int
) -> void:
	var data: Dictionary = bal.get("data", {})
	var prog_cfg: Dictionary    = data.get("progression", {})
	var birth_stats_cfg: Dictionary = data.get("summoning", {}).get("birth_stats", {})
	var calling_cfg: Dictionary = data.get("calling", {})
	var max_level: int = int(prog_cfg.get("max_level_per_rank", 5))
	while int(echo.get("rank", 1)) < target_rank:
		echo["level"] = max_level
		ProgressionService.execute_rank_up(echo, campaign_seed, prog_cfg, birth_stats_cfg, calling_cfg, logger, t)


## id → grid_pos snapshot for every actor currently on the board.
static func _positions_snapshot(actors: Array) -> Dictionary:
	var out: Dictionary = {}
	for a_v in actors:
		if a_v is Dictionary:
			var a: Dictionary = a_v
			out[str(a.get("id", ""))] = (a.get("grid_pos", {}) as Dictionary).duplicate()
	return out


## Curated, mode-agnostic slice of combat_state — every key defaults safely for modes that
## never touch it, so the fingerprint shape is identical across all seven modes.
static func _mode_state_snapshot(cs: Dictionary) -> Dictionary:
	return {
		"round_counter":           int(cs.get("round_counter", 0)),
		"round_phase":             str(cs.get("round_phase", "")),
		"combat_over":             bool(cs.get("combat_over", false)),
		"contain_counter":         int(cs.get("contain_counter", 0)),
		"quarry_escaped":          bool(cs.get("quarry_escaped", false)),
		"hold_counter":            int(cs.get("hold_counter", 0)),
		"recover_holder_id":       str(cs.get("recover_holder_id", "")),
		"recover_reinforce_count": int(cs.get("recover_reinforce_count", 0)),
		"waves_spawned":           int(cs.get("waves_spawned", 0)),
		"all_waves_spawned":       bool(cs.get("all_waves_spawned", false)),
		"protect_counter":         int(cs.get("protect_counter", 0)),
		"totem_stolen":            bool(cs.get("totem_stolen", false)),
		"totem_carrier_id":        str(cs.get("totem_carrier_id", "")),
		"escort_started":          bool(cs.get("escort_started", false)),
		"destination_reached":     bool(cs.get("destination_reached", false)),
		"guide_protect_counter":   int(cs.get("guide_protect_counter", 0)),
		"guide_mode":              str(cs.get("guide_mode", "")),
	}


## Drives the real FlowRuntime round loop (combat.init → confirm_round → next_actor*) up to
## max_rounds, capturing a per-round fingerprint dict at each round boundary. Stops early once
## combat_over is set by the real _end_round() logic.
static func _drive_and_capture(runtime: FlowRuntime, ectx: EncounterContext, max_rounds: int) -> Dictionary:
	var rounds: Array = []
	runtime.dispatch({ "type": "combat.init" })
	for _r in range(max_rounds):
		# V2-COMBAT-003 Phase 2a FIX: combat.confirm_round resolves the FIRST actor of the round
		# itself (FlowRuntime.gd:1279, _resolve_next_actor called from _handle_combat_confirm_round),
		# and resets ectx.last_round_results = [] immediately before doing so (FlowRuntime.gd:1269).
		# Previously this harness dispatched confirm_round and only sampled combat.next_actor
		# afterward, so the first actor of every round was resolved but never captured — a whole
		# turn per round silently missing from the fingerprint. Capture it here, before the
		# next_actor loop below.
		var before_positions_first: Dictionary = _positions_snapshot(ectx.actors)
		runtime.dispatch({ "type": "combat.confirm_round" })
		var turns: Array = []
		var confirm_results: Array = ectx.last_round_results as Array
		if confirm_results.size() > 0:
			var after_positions_first: Dictionary = _positions_snapshot(ectx.actors)
			for i in range(confirm_results.size()):
				var first_entry: Dictionary = confirm_results[i] as Dictionary
				var first_sid: String = str(first_entry.get("source_id", ""))
				turns.append({
					"actor_id":    first_sid,
					"action_type": str(first_entry.get("action_type", "")),
					"target_id":   str(first_entry.get("target_id", "")),
					"damage":      int(first_entry.get("damage", 0)),
					"is_kill":     bool(first_entry.get("is_kill", false)),
					"from_pos":    before_positions_first.get(first_sid, {}),
					"to_pos":      after_positions_first.get(first_sid, {}),
				})
		var guard: int = 0
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)):
				break
			if str(cs.get("round_phase", "")) != "in_round":
				break
			var before_count: int = (ectx.last_round_results as Array).size()
			var before_positions: Dictionary = _positions_snapshot(ectx.actors)
			runtime.dispatch({ "type": "combat.next_actor" })
			var after_count: int = (ectx.last_round_results as Array).size()
			# Only a genuine new turn resolution appends to last_round_results — a dispatch
			# that merely discovers "no next living actor" and runs _end_round() housekeeping
			# does not, so this guard never records a spurious/duplicate turn entry.
			if after_count > before_count:
				var after_positions: Dictionary = _positions_snapshot(ectx.actors)
				var entry: Dictionary = ectx.last_round_results[after_count - 1] as Dictionary
				var sid: String = str(entry.get("source_id", ""))
				turns.append({
					"actor_id":    sid,
					"action_type": str(entry.get("action_type", "")),
					"target_id":   str(entry.get("target_id", "")),
					"damage":      int(entry.get("damage", 0)),
					"is_kill":     bool(entry.get("is_kill", false)),
					"from_pos":    before_positions.get(sid, {}),
					"to_pos":      after_positions.get(sid, {}),
				})
		rounds.append({
			"round":                  int(ectx.combat_state.get("round_counter", 0)),
			"turns":                  turns,
			"positions_end_of_round": _positions_snapshot(ectx.actors),
			"mode_state":             _mode_state_snapshot(ectx.combat_state),
		})
		if bool(ectx.combat_state.get("combat_over", false)):
			break
	return {
		"rounds":      rounds,
		"combat_over": bool(ectx.combat_state.get("combat_over", false)),
	}


## Final mode result + shape of the "flow.resolve" snapshot FlowRuntime._end_round() publishes.
## KNOWN DEFECT (V2-INFRA-003 will change this): _end_round() writes this snapshot directly onto
## flow_ctx.last_snapshot without going through a formal flow.go_state(RESOLVE) transition, so
## FlowStateMachine.refresh_snapshot() logs "snapshot.mismatch" on every single fight. Captured
## here as observed behaviour, not fixed.
static func _final_fingerprint(flow_ctx: FlowContext, ectx: EncounterContext) -> Dictionary:
	var snap: Dictionary = flow_ctx.last_snapshot
	var data: Dictionary = snap.get("data", {}) as Dictionary
	var actions: Dictionary = snap.get("actions", {}) as Dictionary
	var data_keys: Array = data.keys()
	data_keys.sort()
	var action_keys: Array = actions.keys()
	action_keys.sort()
	return {
		"snapshot_type":          str(snap.get("type", "")),
		"data_keys":              data_keys,
		"action_keys":            action_keys,
		"victory":                bool(data.get("victory", false)),
		"reason":                 str(data.get("reason", "")),
		"round_ended":            int(data.get("round_ended", 0)),
		"enemies_defeated":       int(data.get("enemies_defeated", 0)),
		"echoes_survived":        int(data.get("echoes_survived", 0)),
		"ase_awarded":            int(data.get("ase_awarded", 0)),
		"ekwan_awarded":          int(data.get("ekwan_awarded", 0)),
		"rank":                   str(data.get("rank", "")),
		"objectives_remaining":   int(data.get("objectives_remaining", 0)),
		"surface":                str(data.get("surface", "")),
		"guide_spirit_protected": bool(data.get("guide_spirit_protected", false)),
		# V2-INFRA-003 FIX: objective_state is the mode's actual decision surface —
		# combat_state["objective"] (the resolution_mode string itself) plus mode-specific
		# progress counters (contain_progress, protect_progress, guide_mode, etc.). Without
		# it, two structurally different modes that both happen to end via the universal
		# "all_enemies_defeated" win condition (e.g. COMBAT, and a PURSUE fight where the
		# quarry simply dies like any other enemy before the contain/escape window fires)
		# hash identically on every OTHER field above too — a fingerprint that cannot tell
		# two modes apart cannot guard a refactor. Captured as its own Dictionary (JSON-safe:
		# only String/int/bool/Dictionary leaves) since data_keys above only records the
		# top-level key NAME, which is identical across all seven modes by construction.
		"objective_state":        (data.get("objective_state", {}) as Dictionary),
		"combat_result": {
			"victory":     bool(ectx.combat_result.get("victory", false)),
			"reason":      str(ectx.combat_result.get("reason", "")),
			"round_ended": int(ectx.combat_result.get("round_ended", 0)),
			"shrine_hp":   int(ectx.combat_result.get("shrine_hp", -1)),
		},
	}


## Post-encounter save-state fingerprint.
## The KNOWN DEFECT this used to carry — "build_final_snapshot() pays Ase/Ekwan/XP with no
## idempotency guard" — was FIXED in V2-INFRA-003 Phase 8 (D36/D77). The stage-cadence half of
## that payment now settles once per stage behind the stage's settlement_receipt, in the
## flow.complete_stage dispatch; what this fingerprint still observes is the ENCOUNTER-cadence
## half, which is per-fight by definition and has nothing to be idempotent about.
static func _save_fingerprint(flow_ctx: FlowContext, party_ids: Array) -> Dictionary:
	var econ: Dictionary = flow_ctx.save_data.get("economy", {}) as Dictionary
	var sanctum: Dictionary = flow_ctx.save_data.get("sanctum", {}) as Dictionary
	var roster: Array = sanctum.get("roster", []) as Array
	var party_snapshot: Array = []
	for pid_v in party_ids:
		var pid: String = str(pid_v)
		for e_v in roster:
			if e_v is Dictionary and str((e_v as Dictionary).get("id", "")) == pid:
				var e: Dictionary = e_v
				party_snapshot.append({
					"id":       pid,
					"xp_total": int(e.get("xp_total", 0)),
					"level":    int(e.get("level", 0)),
					"rank":     str(e.get("rank", "")),
				})
				break
	return {
		"ase":   int(econ.get("ase", 0)),
		"ekwan": int(econ.get("ekwan", 0)),
		"party": party_snapshot,
	}


static func _hash(v: Variant) -> String:
	return JSON.stringify(v, "", true).sha256_text()


## Runs one full mode encounter and returns its three fingerprint hashes.
## Returns {"ok": false, "error": ...} — never a fabricated hash — if combat does not conclude
## within max_rounds (nothing in the seven modes' authored durations should ever hit this; if it
## does, that is itself a finding to report, not paper over).
static func _run_mode_fingerprint(
	mode: String,
	seed_tag: String,
	guide_mode: String = "",
	guide_joins: String = "",
	max_rounds: int = 30
) -> Dictionary:
	var env: Dictionary = _setup_encounter(mode, seed_tag, guide_mode, guide_joins)
	if env.is_empty():
		return { "ok": false, "error": "setup failed for mode %s (realm/encounter_ctx not created)" % mode }
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]
	var party_ids: Array = env["party_ids"]

	var drive: Dictionary = _drive_and_capture(runtime, ectx, max_rounds)
	if not bool(drive.get("combat_over", false)):
		return {
			"ok": false,
			"error": "mode %s did not reach combat_over within %d rounds — refusing to fabricate a fingerprint" \
				% [mode, max_rounds],
		}

	var rounds_fp: Array = drive["rounds"]
	var final_fp: Dictionary = _final_fingerprint(flow_ctx, ectx)
	var save_fp: Dictionary = _save_fingerprint(flow_ctx, party_ids)

	print("FP_DEBUG %s final=%s" % [seed_tag, JSON.stringify(final_fp)])
	print("FP_DEBUG %s save=%s" % [seed_tag, JSON.stringify(save_fp)])
	var _dbg_snap: Dictionary = flow_ctx.last_snapshot
	var _dbg_data: Dictionary = _dbg_snap.get("data", {}) as Dictionary
	print("FP_DEBUG %s objective_state=%s" % [seed_tag, JSON.stringify(_dbg_data.get("objective_state", {}))])

	return {
		"ok":          true,
		"rounds_hash": _hash(rounds_fp),
		"final_hash":  _hash(final_fp),
		"save_hash":   _hash(save_fp),
	}


# ---------------------------------------------------------------------------
# Per-mode fingerprint tests. Expected hashes are the recorded characterization of current
# behaviour — any drift fails loudly with expected-vs-actual in the error string.
# ---------------------------------------------------------------------------
#
# RE-RECORDED ONCE, V2-INFRA-003 Phase 8 — the settlement split (defects D36 / D77 / D05).
# Fourteen constants moved: the FINAL and SAVE hash of all seven modes. NOT ONE ROUNDS HASH
# MOVED, which is the headline: no combat behaviour changed, only where the reward is paid.
#
# WHAT MOVED, AND WHY — measured from this file's own FP_DEBUG payloads, before and after:
#
#   ase_awarded / save.ase   −70 in EVERY mode (COMBAT 125→55, PURIFY_SHRINE 134→64,
#                            RECOVER 129→59, PROTECT 129→59, ENDURE 125→55, PURSUE 125→55,
#                            GUIDE_SPIRIT 120→50). 70 = the stage's base (two combat
#                            objectives × objective_weights.combat 30 = 60, redo_multiplier 1.0
#                            at run_count 0) + the realm.01 courage virtue bonus (10). Both are
#                            STAGE cadence and are now paid by StageSettlementService in the
#                            flow.complete_stage dispatch. This harness drives only
#                            combat.init / confirm_round / next_actor and never dispatches
#                            flow.complete_stage, so it cannot see that payment — the Ase is
#                            deferred, not deleted. The identical −70 across seven modes is the
#                            proof that only the stage-cadence component left: the per-fight
#                            bonuses, which differ per mode, are untouched.
#   ekwan_awarded / save.ekwan  falls with it, because Ekwan is a fraction of the Ase actually
#                            awarded (COMBAT 15→7; the missing 8 = roundi(70 × 0.12) now lands
#                            with the stage payout).
#   party xp_total           every party echo loses ~40–50 and lands on 0, EXCEPT the one echo
#                            per mode that scored a kill, which lands on exactly 25. That is
#                            xp_kill_bonus, applied mid-combat, per kill — encounter cadence,
#                            and it did NOT move. What left is xp_stage_clear_base (40) × the
#                            per-echo virtue multiplier, awarded to every party member on a
#                            clear: stage cadence, now in StageSettlementService.
#   party level              unchanged (nobody crossed a threshold either way).
#   rank / victory / reason / round_ended / enemies_defeated / echoes_survived /
#   objective_state / data_keys / action_keys / combat_result — ALL UNCHANGED in all seven
#                            modes. RewardCalc.compute() was not touched, so the grade is
#                            computed from the same numbers as before.

#
# RE-RECORDED ONCE, V2-INFRA-003 connect pass — the dead `title` key deleted (defects D18/D19).
# Seven constants moved: the FINAL hash of all seven modes. NO ROUNDS HASH AND NO SAVE HASH
# MOVED, which is the whole claim: a snapshot key was removed, and nothing else was touched.
#
# WHAT MOVED, AND WHY — measured by diffing this file's own FP_DEBUG payloads field by field,
# before and after, across all fourteen (seven modes × final/save):
#
#   data_keys    the ONLY field that differs in any of the fourteen payloads, and the only
#                difference within it is the removal of "title". Producer A's sorted key list
#                goes from 24 entries to 23; the other 23 are unchanged and in the same order.
#   everything   snapshot_type, action_keys, victory, reason, round_ended, enemies_defeated,
#   else         echoes_survived, ase_awarded, ekwan_awarded, rank, objectives_remaining,
#                surface, guide_spirit_protected, objective_state, combat_result — byte-identical
#                in all seven modes. `title` was a constant string no consumer read, so removing
#                it can only shorten the key list.
#
# `title` was emitted by producers A, B and F and read by nothing in ui/, core/ or tests/. Only A
# is fingerprinted, so only these seven constants could move — and only through data_keys.

#
# RE-RECORDED ONCE, V2-COMBAT-003 Phase 2a — the missing-first-actor harness fix (see the file
# header FIX note above). Seven constants moved: the ROUNDS hash of all seven modes. NO FINAL
# HASH AND NO SAVE HASH MOVED, which is the whole claim: the harness started capturing a turn
# it was already simulating but not recording, and nothing about the simulation itself changed.
#
# PROOF OF ADDITIVITY — measured by re-running both the pre-fix and post-fix harness in the same
# process, printing the full `rounds` array (not just its hash) for all seven modes, and diffing
# turn-by-turn:
#   - every round's `turns` array in the post-fix trace contains the entire pre-fix `turns` array
#     as an exact, order-preserving subsequence — no previously-captured turn changed, moved, or
#     was dropped.
#   - the only turns added are exactly one per round: the first-actor-of-round turn that
#     `combat.confirm_round` resolves internally (FlowRuntime.gd _handle_combat_confirm_round →
#     _resolve_next_actor) and that the old harness never sampled.
#   - `mode_state`, `positions_end_of_round` and the `round` counter are byte-identical per round
#     in both traces.
#   - turns gained, measured per mode: COMBAT +5 (5 rounds), PURIFY_SHRINE +4 (4 rounds),
#     RECOVER +2 (2 rounds), PROTECT +4 (4 rounds), ENDURE +5 (5 rounds), PURSUE +5 (5 rounds),
#     GUIDE_SPIRIT +9 (9 rounds) — exactly one gained turn per round in every mode, matching the
#     "confirm_round resolves exactly one actor" comment at FlowRuntime.gd's
#     CombatTurnActionService call site.
#
# No production file changed. No dispatch was added or removed: this harness still dispatches
# exactly `combat.init`, one `combat.confirm_round` per round, and `combat.next_actor` per
# subsequent turn — identically to before. FINAL_HASH and SAVE_HASH constants for all seven
# modes are therefore untouched by this change.

## RE-RECORDED, V2-COMBAT-003 Phase 2b — production-shaped fixtures (ANSWERS.md #50). See the
## detailed cause note above CombatBaselineTests.COMBAT_EMOTION_HASHES: GridService's
## _placement_score() vec_mod term went live once vector_scores stopped being {}, reordering
## the five Echoes' starting columns and cascading into every round from round 1 onward.
## FINAL_HASH did not move for any of the seven modes (same win condition, same round count).
##
## RE-RECORDED AGAIN, V2-COMBAT-003 — GridService._dominant_key() now examines every key in the
## scores dict instead of only the four keys in its tiebreak_order argument. THIS IS THE ONLY
## CONSTANT IN THE SUITE THAT MOVED: one hash, in one mode. COMBAT_FINAL_HASH, COMBAT_SAVE_HASH,
## the ROUNDS/FINAL/SAVE hashes of the other six modes, and every CombatBaselineTests emotion
## trace are all untouched.
##
## WHAT MOVED, AND WHY — measured by running this file's own harness with a temporary probe that
## printed, per Echo, the full vector_scores, the dominant key under BOTH the old and the new
## rule, GridService._placement_score(), and the starting cell; once with the fix in the tree and
## once with core/grid/GridService.gd reverted, in two separate processes.
##
## On the fp_combat board two Echoes change dominant vector, and both for the same reason —
## `devoted` is their highest score by a wide margin and the old rule never looked at it:
##   echo_0001  scores {devoted 60, pillar 15, nurturer 15, mediator 5, protector 5}
##              OLD dominant "pillar" (15!) -> by_dominant_vector -2.0 -> int -2
##              NEW dominant "devoted" (60) -> by_dominant_vector -1.5 -> int -1   score 5 -> 6
##   echo_0005  identical scores, identical move                                   score 8 -> 9
## (echo_0004 also switches, "seeker" -> "skeptic", but 0.0 and -0.5 both truncate to 0, so its
## score is unchanged at 7. echo_0002 "pillar" and echo_0003 "vanguard" do not switch.)
##
## Placement sorts ascending by score with an id tiebreak, so the five scores fully predict both
## observed row orders in column 1:
##   before  e1=5 e4=7 e2=8 e5=8 e3=9  ->  rows 1..5 = e1, e4, e2, e5, e3   (measured)
##   after   e1=6 e4=7 e2=8 e3=9 e5=9  ->  rows 1..5 = e1, e4, e2, e3, e5   (measured)
## echo_0005 rising 8 -> 9 lifts it into a tie with echo_0003, and "echo_0003" < "echo_0005"
## puts it last. echo_0001 rising 5 -> 6 changes no ordering. The starting cell SET is identical
## ({(1,1),(1,2),(1,3),(1,4),(1,5)}); only the echo_0003/echo_0005 assignment swapped.
##
## Round one's five destination cells are likewise the SAME SET before and after —
## {(3,1),(3,2),(3,3),(3,4),(4,6)} — with echo_0003 and echo_0005 swapped between (3,3) and
## (3,4), which is exactly what a swapped starting slot produces and confirms the terrain and
## movement layers are untouched. That swap cascades through the remaining rounds (who reaches
## the enemy first, who takes the counter-attack), which is why the rounds hash moves.
##
## WHY THE OTHER SIX MODES DID NOT MOVE — measured, not assumed. Ten more dominant switches occur
## across them (e.g. fp_recover echo_0002 "protector" -> "nurturer", fp_guide_spirit echo_0002
## "vanguard" -> "opportunist"), but in every one of those modes the ascending sort order of the
## five placement scores is unchanged, and the probe confirmed every starting cell is
## byte-identical before and after. A changed modifier that does not change the sort order
## changes no placement.
## V2-COMBAT-003: by_calling_origin re-migrated to V2 initiative ids. fp_combat's party has
## echo_0002 (aduro, unrecognized under V1 keys -> was 0, now +3.0) and echo_0005 (kra_soro,
## same -> now +1.0). This reorders who acts first each round, on top of the dominant-vector
## move above, so all three hashes move again.
# V2-COMBAT-003 Phase 5 re-record — attributed. apply_live_activation() now relabels
# actor.idle as actor.move when the turn traversed cells. Verified turn-by-turn against
# the pre-fix trace: only action_type changed on affected turns; every other field
# (actor_id, target_id, damage, is_kill, positions, mode_state) is byte-identical.
# FINAL_HASH and SAVE_HASH did not move.
# V2-COMBAT-003 Phase 6 re-record — attributed. The live producer now fills exposure, congestion
# and cohesion from MovementOptionService, so BehaviorArbiter._spatial_utility scores routes it
# previously scored as if every cell were equally safe. COMBAT ends in 5 rounds instead of 6:
# echo_0002 attacks from 6,3 in r04 instead of retreating to 5,3, echo_0004 lands the killing
# blow in r05 from 7,4, and round 6 no longer happens. FINAL moves only on round_ended 6 -> 5;
# SAVE moves only because the 25 kill XP is now echo_0004's instead of echo_0003's — ase 55 and
# ekwan 7 are unchanged. The other five modes' hashes did not move at all.
# V2-COMBAT-003 Phase 7a re-record — attributed. A mover already within ranges[melee_attack]
# now gets a zero-step stay option. FIRST divergence: r03 enemy.dust_wanderer_1 hits echo_0003
# from 7,1 instead of stepping to 7,2 — same target, same damage 3. The fight runs 6 rounds
# instead of 5, so FINAL and SAVE move with it.
const COMBAT_ROUNDS_HASH := "6312819e097d22c780a93774c3fa513db9b9ee3322cdd38f634d5cb9b3eaf264"
const COMBAT_FINAL_HASH  := "acd5c49a3496616010028fdcdf8851eba11865a9596203e3d99db39e88da2c21"
const COMBAT_SAVE_HASH   := "bbe140a53a33fcc97220ce3f9c8c172e2cb1f4ce4a281094a78f9733b40b50a4"


## Shared expected-vs-actual assertion for the three hashes of one mode.
## Reports EVERY mismatch (rounds/final/save) in one failure message, not just the first —
## the drive through a mode is expensive, so a single run must surface every wrong constant
## instead of fail-fast forcing one re-run per drifted hash.
static func _assert_hashes(
	mode_label: String,
	r: Dictionary,
	rounds_expected: String,
	final_expected: String,
	save_expected: String
) -> Dictionary:
	if not bool(r.get("ok", false)):
		return r
	var mismatches: Array = []
	if str(r.get("rounds_hash", "")) != rounds_expected:
		mismatches.append("rounds fingerprint drifted: expected=%s actual=%s" \
			% [rounds_expected, r.get("rounds_hash", "")])
	if str(r.get("final_hash", "")) != final_expected:
		mismatches.append("final fingerprint drifted: expected=%s actual=%s" \
			% [final_expected, r.get("final_hash", "")])
	if str(r.get("save_hash", "")) != save_expected:
		mismatches.append("save fingerprint drifted: expected=%s actual=%s" \
			% [save_expected, r.get("save_hash", "")])
	if not mismatches.is_empty():
		return { "ok": false, "error": "%s: %s" % [mode_label, " | ".join(mismatches)] }
	return { "ok": true }


static func test_combat() -> Dictionary:
	var r: Dictionary = _run_mode_fingerprint(EncounterResolutionModes.COMBAT, "fp_combat")
	return _assert_hashes("COMBAT", r, COMBAT_ROUNDS_HASH, COMBAT_FINAL_HASH, COMBAT_SAVE_HASH)


## RE-RECORDED, V2-COMBAT-003 Phase 2b — production-shaped fixtures (ANSWERS.md #50). Same
## cause as COMBAT above: GridService placement's vec_mod term.
# V2-COMBAT-003 Phase 5 re-record — same cause as COMBAT_ROUNDS_HASH above.
# V2-COMBAT-003 Phase 6 re-record — attributed. Same cause as COMBAT above, one turn wide:
# echo_0003 no longer advances 5,2 -> 6,3 to attack in r03, because that single step runs
# through the enemy's control (exposure 1.0 x -6.0). The fight still ends in 4 rounds, so
# FINAL and SAVE did not move.
# V2-COMBAT-003 Phase 7a re-record — attributed. FIRST divergence: r03 echo_0004 hits
# enemy.dust_wanderer_1 from 6,3 instead of stepping to 6,4 — same target, same damage 18. Its
# candidate set changed from one route (d6r4, exposure 1.0, one control source) to the stay
# (d6r3, exposure 0.0, none). Still 4 rounds, so FINAL and SAVE did not move.
# V2-COMBAT-003 Phase 7b re-record — attributed, and the only mode that moved. The purifier
# is now anchored on the shrine at every level of shrine health, not only below 0.5.
# FIRST divergence: r01 echo_0005 (the purifier) takes goal.purify_shrine.advance.purifier and
# walks 1,4 → 4,6, beside shrine_01 at 4,5, instead of 1,4 → 4,3 towards the enemy. From r02 it
# holds that cell on actor.guard every round instead of attacking. The enemy therefore loses
# ~17 damage a round from r03 and the fight runs 6 rounds instead of 4.
# FINAL and SAVE moved with it: round_ended 4 → 6; shrine_hp 180 → 170 (two more rounds at the
# unchanged 5-per-round drain — no purify fires, see the two gates named in
# docs/v2-combat-003-handoff.md §18); ase_awarded 64 → 55 and ekwan 8 → 7 on the slower clear;
# and the 25 kill XP moves from echo_0005 to echo_0001, who lands the last blow in r06.
# V2-COMBAT-003 Phase 7c re-record — attributed, and again the only mode that moved. The
# purifier can finally act on the cell 7b walked it to: two turns changed, one per gate opened.
# FIRST divergence: r01 echo_0005 resolves actor.purify_shrine (target shrine_01) on the same
# 1,4 → 4,6 walk that used to resolve actor.move — the movement layer's advance plan. Then r04
# is actor.purify_shrine instead of actor.guard, once purify_cooldown (3 rounds) is spent —
# the arbiter's override. Every other turn of every round is unchanged, and the fight still
# runs 6 rounds, so SAVE did not move.
# FINAL moved with shrine_hp 170 → 172: two purify stacks (-3 drain for 2 rounds each, +2 on
# expiry) net 2 HP back over six rounds.
const PURIFY_SHRINE_ROUNDS_HASH := "2ebf9494c643704fd1ff06924a197f6780c44e6df89ef618e25051936caadcc4"
const PURIFY_SHRINE_FINAL_HASH  := "c65a3be16d812a37e9d225dc78df330c0f1d81bb4a9bf3c39b4b9d863bf092f9"
const PURIFY_SHRINE_SAVE_HASH   := "cca434e9c009c6ba5607c102d12b1d87883fe6899dbffe4214c9a0cb0934eff7"

static func test_purify_shrine() -> Dictionary:
	var r: Dictionary = _run_mode_fingerprint(EncounterResolutionModes.PURIFY_SHRINE, "fp_purify_shrine")
	return _assert_hashes("PURIFY_SHRINE", r, PURIFY_SHRINE_ROUNDS_HASH, PURIFY_SHRINE_FINAL_HASH, PURIFY_SHRINE_SAVE_HASH)


## RE-RECORDED, V2-COMBAT-003 Phase 2b — production-shaped fixtures (ANSWERS.md #50). Same
## cause as COMBAT above: GridService placement's vec_mod term. FINAL_HASH and SAVE_HASH did
## not move for this mode.
# V2-COMBAT-003 Phase 5 re-record — same cause as COMBAT_ROUNDS_HASH above.
const RECOVER_ROUNDS_HASH := "99f84509ba567b9066e9af4f97a524d2685739f19c7fba02ff90f6243eff60e5"
const RECOVER_FINAL_HASH  := "09e38fdf70259c9a647c6dd053caa9e1518e5f830364ac5f96fac5dbceb92780"
const RECOVER_SAVE_HASH   := "bffa34aa225afe79818ec0b15931d59f495930337b8d07b33a997208e0d46c35"

static func test_recover() -> Dictionary:
	var r: Dictionary = _run_mode_fingerprint(EncounterResolutionModes.RECOVER, "fp_recover")
	return _assert_hashes("RECOVER", r, RECOVER_ROUNDS_HASH, RECOVER_FINAL_HASH, RECOVER_SAVE_HASH)


## RE-RECORDED, V2-COMBAT-003 Phase 2b — production-shaped fixtures (ANSWERS.md #50). Same
## cause as COMBAT above: GridService placement's vec_mod term. FINAL_HASH and SAVE_HASH did
## not move for this mode.
# V2-COMBAT-003 Phase 5 re-record — same cause as COMBAT_ROUNDS_HASH above.
# V2-COMBAT-003 Phase 7a re-record — attributed. FIRST divergence: r04 enemy.dust_wanderer_1
# stops walking off 6,4 to swing at echo_0001 for 0 and instead breaks protect_entity_01 for 11
# from where it stands. The mode is genuinely harder, which is the fix working, not a defect.
const PROTECT_ROUNDS_HASH := "28938ae1aae8733614b7b3941b2ece412ed2726facc4e0e59135534e5dd5bca2"
const PROTECT_FINAL_HASH  := "443b49a8c8bfd83a739b0636e6eacc71ebd38e646eb7da9af9b0445d21374ce2"
const PROTECT_SAVE_HASH   := "bffa34aa225afe79818ec0b15931d59f495930337b8d07b33a997208e0d46c35"

static func test_protect() -> Dictionary:
	var r: Dictionary = _run_mode_fingerprint(EncounterResolutionModes.PROTECT, "fp_protect")
	return _assert_hashes("PROTECT", r, PROTECT_ROUNDS_HASH, PROTECT_FINAL_HASH, PROTECT_SAVE_HASH)


## RE-RECORDED, V2-COMBAT-003 Phase 2b — production-shaped fixtures (ANSWERS.md #50). Same
## cause as COMBAT above: GridService placement's vec_mod term. FINAL_HASH and SAVE_HASH did
## not move for this mode.
# V2-COMBAT-003 Phase 5 re-record — same cause as COMBAT_ROUNDS_HASH above.
# V2-COMBAT-003 Phase 7a re-record — attributed. FIRST divergence: r03, echo_0001 at 6,2.
# FINAL and SAVE did not move.
const ENDURE_ROUNDS_HASH := "26c56e0097c17aa190ed040d262459b668ba702577d87c9e2d934adf4f8ca14d"
const ENDURE_FINAL_HASH  := "106b216e990ac3e55653976f0bf0506f7f96f2d361a1183e87241c3948f7554e"
const ENDURE_SAVE_HASH   := "cca434e9c009c6ba5607c102d12b1d87883fe6899dbffe4214c9a0cb0934eff7"

static func test_endure() -> Dictionary:
	var r: Dictionary = _run_mode_fingerprint(EncounterResolutionModes.ENDURE, "fp_endure")
	return _assert_hashes("ENDURE", r, ENDURE_ROUNDS_HASH, ENDURE_FINAL_HASH, ENDURE_SAVE_HASH)


## RE-RECORDED, V2-COMBAT-003 Phase 2b — production-shaped fixtures (ANSWERS.md #50). Same
## cause as COMBAT above: GridService placement's vec_mod term.
# V2-COMBAT-003 Phase 5 re-record — same cause as COMBAT_ROUNDS_HASH above.
const PURSUE_ROUNDS_HASH := "d3b7d31ec0b0cdf0185ccffc883dfe08e5846caf33273d9fe45289904bd05f5c"
const PURSUE_FINAL_HASH  := "678b39327b47e4999322d24d3b07d280e48e475ed89fc2e1475f89bc6b8fbedb"
const PURSUE_SAVE_HASH   := "f3e41850d026469d228e8c1d30c57e87a9e38279f323fc49f96bc480b1355d05"

static func test_pursue() -> Dictionary:
	var r: Dictionary = _run_mode_fingerprint(EncounterResolutionModes.PURSUE, "fp_pursue")
	return _assert_hashes("PURSUE", r, PURSUE_ROUNDS_HASH, PURSUE_FINAL_HASH, PURSUE_SAVE_HASH)


# GUIDE_SPIRIT is forced to guide_mode="protect", guide_joins="nojoin" — the dedicated
# non-joining spirit mover (GuideSpiritActivationService via FlowRuntime._end_round()), not the
# joined-combatant path. A joined spirit uses ordinary combat activation and is behaviourally
# indistinguishable from COMBAT (see CombatRoundtripIntegrationTests
# test_guide_spirit_joined_combatant_moves_freely's docstring) — "protect"+"nojoin" is the one
# mode-specific decision surface (escort/skittish movement, guide_protect_counter) worth its own
# fingerprint.
#
# V2-COMBAT-003 phase 2c re-record — attributed, not blind. GridService.place_actors now skips
# any walkable cell whose StageTerrain.legal_neighbors is empty (the placement guard; see
# core/grid/GridService.gd's _assign_walkable_faction). This board — the 60x12 GUIDE_SPIRIT
# long board for encounter_id "realm.01.stage.0.fp_guide_spirit", root_seed 12346 — generates
# exactly ONE isolated cell: (8,0). Before the guard, echo_0003 landed on (8,0) and was
# stranded there for the whole fight (a real instance of the section 5.1 defect, not a
# hypothetical). After the guard, (8,0) is skipped and the ordered fill shifts every
# subsequent echo one legal cell along:
#   before: e1@9,6  e2@9,2  e3@8,0  e4@9,5  e5@9,1
#   after:  e1@9,8  e2@9,5  e3@9,1  e4@9,6  e5@9,2
# (enemy and guide_spirit positions are unaffected — the isolated cell sits in the echo
# column band). Measured with a throwaway probe test that dumped ectx.terrain's walkable set,
# ran StageTerrain.legal_neighbors over every cell, and printed ectx.actors' grid_pos before
# and after the fix, on an otherwise-unmodified tree (probe deleted after use, not committed).
# ROUNDS_HASH is the only one of the three that moved — FINAL_HASH and SAVE_HASH are unchanged,
# because the fight's outcome (round 9, spirit_protected, same rewards) does not depend on
# which specific legal cell echo_0003 started the fight on.
#
# V2-COMBAT-003 terrain commit 2 re-record — attributed, not blind. StageTerrain now judges
# region connectivity by a full SHARED SIDE and anchors the repair on the HOST region (the
# largest, ties by numerically lowest col,row) instead of on whichever component the
# walkable Dictionary happened to yield first, scanning cells in numeric order. This board —
# 60x12, prefix "combat.terrain.realm.01.stage.0.fp_guide_spirit" — has two plateaus that
# are disconnected under BOTH the old and the new rule, so the repair ran in both cases and
# the bridge COUNT did not change. What changed is which cell pair the repair picked, and
# therefore where the L-bridge sits. Measured with a temporary print inside
# StageTerrain.generate, run on this branch and on 8739d55, and removed afterwards:
#   before: bridges=[{col:17,row:1,w:2,h:5}, {col:18,row:4,w:15,h:2}]  walkable=216
#   after:  bridges=[{col:31,row:1,w:2,h:5}, {col:18,row:0,w:15,h:2}]  walkable=224
# A different walkable set means a different ordered fill in GridService.place_actors, so the
# echoes start the fight on different cells and the per-round trace differs. ROUNDS_HASH is
# again the only one of the three that moved: FINAL_HASH and SAVE_HASH are unchanged, because
# the outcome (round 9, spirit_protected, same rewards) does not depend on the starting cells.
# This is the ONLY fingerprint in the suite that moved — the other six modes run on 12x12
# combat boards whose repair choice happened not to change.
# RE-RECORDED AGAIN, V2-COMBAT-003 terrain commit 5, and this time the TERRAIN DID NOT MOVE.
# Measured with a temporary print in _run_mode_fingerprint, run on this tree and on b4dd797
# and removed afterwards: walkable 223 cells both, identical plateaus, identical bridges
# ([{col:31,row:1,w:2,h:5},{col:18,row:0,w:15,h:2}]), identical islands, and no
# objective_site_built key, so decision 25 never fired. Every Echo keeps its cell (col 9,
# rows 8/5/1/6/2) and so does the enemy (47,3). ONE actor moved: the guide spirit, (23,1) to
# (17,5). The cause is decision 24 alone — (23,1) does not have eight walkable neighbours and
# (17,5) does. The host-region filter is inert on this board: the host region is all 223
# walkable cells. SAVE_HASH did not move; the outcome is still spirit_protected.
#
# RE-RECORDED AGAIN, V2-COMBAT-003 Phase 2b — production-shaped fixtures (ANSWERS.md #50).
# Same cause as COMBAT above (see the detailed note there and above
# CombatBaselineTests.COMBAT_EMOTION_HASHES): GridService._placement_score()'s vec_mod term
# went live once vector_scores stopped being {}, reordering the party's starting columns.
# FINAL_HASH and SAVE_HASH did not move — the outcome is still spirit_protected.
# V2-COMBAT-003 Phase 5 re-record — same cause as COMBAT_ROUNDS_HASH above.
const GUIDE_SPIRIT_ROUNDS_HASH := "5de726e78f5ecaed7959dd1df767305a91de3cc77f086b6b2ce921f0c0d7bcb0"
const GUIDE_SPIRIT_FINAL_HASH  := "13b4753677246bdc095ceea1416aba2816581db36c5963d75975a69f56471b3f"
const GUIDE_SPIRIT_SAVE_HASH   := "f05e407a918d10027a255eddfc722fd893177dddfaf2148aae2de8fb17943e38"

static func test_guide_spirit() -> Dictionary:
	var r: Dictionary = _run_mode_fingerprint(
		EncounterResolutionModes.GUIDE_SPIRIT, "fp_guide_spirit", "protect", "nojoin")
	return _assert_hashes("GUIDE_SPIRIT", r, GUIDE_SPIRIT_ROUNDS_HASH, GUIDE_SPIRIT_FINAL_HASH, GUIDE_SPIRIT_SAVE_HASH)


# ---------------------------------------------------------------------------
# Determinism self-check — mechanical proof, not just an external "run twice" check.
# ---------------------------------------------------------------------------

## Runs one mode's setup+drive twice in the SAME process and diffs round-by-round, turn-by-turn.
## Pinpoints exactly where two "identical input" runs would first disagree, if they ever did.
static func _probe_mode_same_process(
	mode: String, seed_tag: String, guide_mode: String = "", guide_joins: String = ""
) -> Dictionary:
	var env_a: Dictionary = _setup_encounter(mode, seed_tag + "_a", guide_mode, guide_joins)
	var env_b: Dictionary = _setup_encounter(mode, seed_tag + "_a", guide_mode, guide_joins)
	if env_a.is_empty() or env_b.is_empty():
		return { "ok": false, "error": "probe setup failed for %s" % mode }

	# Sanity: same seed_tag must produce identical rosters before any combat logic runs.
	var roster_a: Array = (env_a["flow_ctx"] as FlowContext).save_data["sanctum"]["roster"]
	var roster_b: Array = (env_b["flow_ctx"] as FlowContext).save_data["sanctum"]["roster"]
	if JSON.stringify(roster_a, "", true) != JSON.stringify(roster_b, "", true):
		return { "ok": false, "error": "%s: roster generation itself is non-deterministic for the same seed_tag" % mode }

	var actors_a: Array = (env_a["ectx"] as EncounterContext).actors
	var actors_b: Array = (env_b["ectx"] as EncounterContext).actors
	if JSON.stringify(actors_a, "", true) != JSON.stringify(actors_b, "", true):
		return { "ok": false, "error": "%s: post-enter() actor placement/build already diverges before combat.init: a=%s b=%s" \
			% [mode, JSON.stringify(actors_a), JSON.stringify(actors_b)] }

	var drive_a: Dictionary = _drive_and_capture(env_a["runtime"], env_a["ectx"], 30)
	var drive_b: Dictionary = _drive_and_capture(env_b["runtime"], env_b["ectx"], 30)
	var rounds_a: Array = drive_a.get("rounds", [])
	var rounds_b: Array = drive_b.get("rounds", [])
	var n: int = mini(rounds_a.size(), rounds_b.size())
	for i in range(n):
		var ra: Dictionary = rounds_a[i]
		var rb: Dictionary = rounds_b[i]
		if JSON.stringify(ra, "", true) != JSON.stringify(rb, "", true):
			var turns_a: Array = ra.get("turns", [])
			var turns_b: Array = rb.get("turns", [])
			var m: int = mini(turns_a.size(), turns_b.size())
			for j in range(m):
				if JSON.stringify(turns_a[j], "", true) != JSON.stringify(turns_b[j], "", true):
					return { "ok": false, "error": "%s round %d turn %d diverged: a=%s b=%s" \
						% [mode, i, j, JSON.stringify(turns_a[j]), JSON.stringify(turns_b[j])] }
			return { "ok": false, "error": "%s round %d diverged outside turns (mode_state/positions): a=%s b=%s" \
				% [mode, i, JSON.stringify(ra), JSON.stringify(rb)] }
	if rounds_a.size() != rounds_b.size():
		return { "ok": false, "error": "%s round counts differ: a=%d b=%d" % [mode, rounds_a.size(), rounds_b.size()] }
	return { "ok": true }


static func test_determinism_self_check() -> Dictionary:
	var modes: Array = [
		[EncounterResolutionModes.COMBAT, "fp_probe_combat", "", ""],
		[EncounterResolutionModes.PURIFY_SHRINE, "fp_probe_purify_shrine", "", ""],
		[EncounterResolutionModes.RECOVER, "fp_probe_recover", "", ""],
		[EncounterResolutionModes.PROTECT, "fp_probe_protect", "", ""],
		[EncounterResolutionModes.ENDURE, "fp_probe_endure", "", ""],
		[EncounterResolutionModes.PURSUE, "fp_probe_pursue", "", ""],
		[EncounterResolutionModes.GUIDE_SPIRIT, "fp_probe_guide_spirit", "protect", "nojoin"],
	]
	for m in modes:
		var r: Dictionary = _probe_mode_same_process(m[0], m[1], m[2], m[3])
		if not bool(r.get("ok", false)):
			return r
	return { "ok": true }
