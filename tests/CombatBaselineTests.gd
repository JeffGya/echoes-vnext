# res://tests/CombatBaselineTests.gd
# V2-INFRA-003 — CHARACTERIZATION baseline for the parts of the combat spine that the seven
# mode fingerprints in tests/FlowFingerprintTests.gd leave unguarded.
#
# Phase 6 will move core/runtime/FlowRuntime.gd::_resolve_next_actor (:2132–:2699) and
# ::_end_round (:2700–:3779) into services. The mode fingerprints already pin per-turn actions,
# damage, positions and the final resolve snapshot. They pin NOTHING about:
#
#   A. Emotion. No `fear` and no `morale` value appears anywhere in a mode fingerprint, so
#      _end_round()'s seven-term emotion block (:2765–:2998) has no guard at all — and it is the
#      cleanest extraction seam in the function, so it moves first. Terms, as measured:
#         A) ally-KO fear spread      :2768–:2800  writes actor.fear
#         B) per-round fear tick      :2801–:2813  writes actor.fear
#         C) morale decay every N     :2814–:2828  writes actor.morale
#         D) outnumber relief         :2829–:2880  writes actor.fear
#         E) witness-refuse           :2881–:2946  writes actor.fear + _witness_fear_taken
#         F) overwhelmed              :2947–:2969  writes actor.fear
#         G) no-damage streak         :2970–:2998  writes actor.morale + _no_damage_streak
#      Pinned here per mode, per round, per actor: fear, morale, _witness_fear_taken,
#      _no_damage_streak (plus is_dead / faction / is_structure, which gate every term).
#
#   B. Transition sequence. Which state machines transition, in what order, with what reason,
#      over one full encounter. A restructure that expresses a mid-function transition as a
#      returned outcome must not change this list. Nothing pins it today.
#
#   C. Save flush count + reason for the three combat dispatches. tests/FlowTransactionTests.gd
#      proves the general "at most one flush per dispatch" invariant on non-combat actions and
#      counts dispatch()'s match labels; it never dispatches combat.init / combat.confirm_round /
#      combat.next_actor. This file pins the exact count AND the reason string for each.
#
#   D. encounter.retreat's roll is TICK-BOUND: the seed path is
#      "encounter.retreat." + encounter_id + "." + str(t) (:1015), so the outcome depends on how
#      many dispatches preceded it. A refactor that adds or removes one dispatch silently
#      re-rolls every retreat. Pinned as (tick, outcome) pairs.
#
#   E. "encounter.advance" (:389–:395) and "encounter.complete" (:403–:411) are registered and
#      functional but unreachable from any shipped snapshot, and NO test in the repository
#      dispatched either before this file. Nine lines each, with zero guard.
#
# CHARACTERIZATION, NOT CORRECTION. Every assertion records what the code does TODAY, defects
# included. Where a pinned behaviour looks wrong it carries
#   # CHARACTERIZATION — current behaviour, not necessarily correct
# and is reported, never fixed. Inverting one of these is the job of the slice that fixes it.
#
# ISOLATION (AGENTS.md #21/#22, tests/AGENTS.md):
#   - Every runtime boots against its own file under /tmp/echoes-vnext-tests/ via
#     TestSaveHarness, which clears the primary save AND SaveService's whole backup chain, so
#     boot() always mints a brand-new save with the pinned literal root_seed 12346.
#   - "flow.new_game" is never dispatched (AGENTS.md #17 — Crypto.generate_random_bytes()).
#   - Balances are written directly onto the save dict, never through "economy.ase.add".
#
# HARNESS REUSE: sections A–E all build their encounter through
# FlowFingerprintTests._setup_encounter(), the proven mode-forcing setup, rather than a second
# copy of it. Only the round-driving loop is local, because the fingerprint driver captures
# turns/positions and returns no emotion — the exact gap this file exists to close.
#
# EMOTION HASHES RE-RECORDED ONCE, WITH ATTRIBUTION — D01, the near-death trigger
#
# The near-death trigger in CombatTurnActionService read max_hp at the top level of the actor
# dict, where no builder writes it, so the guard default of 1 made `current_hp * 4 <= max_hp`
# unsatisfiable and the branch never ran. It now reads stats.max_hp. That turns on two authored
# keys that had never paid: data.combat.emotion.morale_on_near_death (7) and
# .fear_on_near_death (8).
#
# 7 of the 34 emotion constants moved. Nothing else in this file moved — no round count, no
# transition sequence, no flush count or reason, no retreat (tick, outcome) pair — and NOT ONE
# of the seven mode fingerprints in FlowFingerprintTests moved either.
#
#   COMBAT          idx 3, 4    enemy.dust_wanderer_1  morale 50 → 57, fear +8
#   PURIFY_SHRINE   idx 3       enemy.dust_wanderer_1  morale 50 → 57, fear +8
#   ENDURE          idx 3, 4    enemy.dust_wanderer_1  morale 50 → 57, fear +8
#   PURSUE          idx 3, 4    pursue_quarry_01       morale 50 → 57, fear +8
#   RECOVER, PROTECT, GUIDE_SPIRIT — byte-identical: no actor is left alive at or below a
#   quarter of its max HP in those traces.
#
# The whole delta is one actor per mode, once, at exactly +7 morale and +8 fear — the two
# authored values, unscaled. In all four modes the actor is the enemy, crossing the quarter-HP
# line in round 4 and dying in round 5; the +8 and +7 then carry unchanged into the idx-4
# round. No Echo crosses the line in any recorded trace. Because the affected actor dies the
# following round in every mode, its raised fear changes no decision here, which is why the
# mode fingerprints are unmoved — that is a property of these fixtures, not of the mechanic.
#
# PERMANENT GAP (cannot be closed without a production change, so it is not attempted):
# the movement decision (goal_id / option_id) chosen inside _resolve_next_actor is a private
# local on the selected MovementIntent. It is never written to EncounterContext and never
# logged. Capturing it would require adding logging to production code, which this slice may
# not do. It stays unguarded through the Phase 6 move.

class_name CombatBaselineTests
extends RefCounted

## Set true to print the observed baselines instead of asserting them (used once, to record
## the constants below). Left in place so a future re-record is a one-line change rather than
## a rewrite. MUST be false in a committed tree — a recording run asserts nothing.
const RECORD_MODE := false

const MAX_ROUNDS := 30


static func register(runner) -> void:
	# A — emotion per actor per round, all seven modes
	runner.register_test("combat_baseline/emotion_trace_combat", func(): return _t_emotion(EncounterResolutionModes.COMBAT, "fp_combat", "", "", COMBAT_EMOTION_HASHES, "COMBAT"))
	runner.register_test("combat_baseline/emotion_trace_purify_shrine", func(): return _t_emotion(EncounterResolutionModes.PURIFY_SHRINE, "fp_purify_shrine", "", "", PURIFY_SHRINE_EMOTION_HASHES, "PURIFY_SHRINE"))
	runner.register_test("combat_baseline/emotion_trace_recover", func(): return _t_emotion(EncounterResolutionModes.RECOVER, "fp_recover", "", "", RECOVER_EMOTION_HASHES, "RECOVER"))
	runner.register_test("combat_baseline/emotion_trace_protect", func(): return _t_emotion(EncounterResolutionModes.PROTECT, "fp_protect", "", "", PROTECT_EMOTION_HASHES, "PROTECT"))
	runner.register_test("combat_baseline/emotion_trace_endure", func(): return _t_emotion(EncounterResolutionModes.ENDURE, "fp_endure", "", "", ENDURE_EMOTION_HASHES, "ENDURE"))
	runner.register_test("combat_baseline/emotion_trace_pursue", func(): return _t_emotion(EncounterResolutionModes.PURSUE, "fp_pursue", "", "", PURSUE_EMOTION_HASHES, "PURSUE"))
	runner.register_test("combat_baseline/emotion_trace_guide_spirit", func(): return _t_emotion(EncounterResolutionModes.GUIDE_SPIRIT, "fp_guide_spirit", "protect", "nojoin", GUIDE_SPIRIT_EMOTION_HASHES, "GUIDE_SPIRIT"))
	# A' — the emotion block must actually move values, or the hashes above pin nothing
	runner.register_test("combat_baseline/emotion_block_actually_moves_values", func(): return _t_emotion_is_non_trivial())
	# B — transition sequence per mode
	runner.register_test("combat_baseline/transition_sequence_combat", func(): return _t_transitions(EncounterResolutionModes.COMBAT, "cb_tr_combat", "", "", COMBAT_TRANSITIONS, "COMBAT"))
	runner.register_test("combat_baseline/transition_sequence_purify_shrine", func(): return _t_transitions(EncounterResolutionModes.PURIFY_SHRINE, "cb_tr_purify", "", "", PURIFY_SHRINE_TRANSITIONS, "PURIFY_SHRINE"))
	runner.register_test("combat_baseline/transition_sequence_guide_spirit", func(): return _t_transitions(EncounterResolutionModes.GUIDE_SPIRIT, "cb_tr_guide", "protect", "nojoin", GUIDE_SPIRIT_TRANSITIONS, "GUIDE_SPIRIT"))
	# C — save flush count + reason per combat dispatch
	runner.register_test("combat_baseline/flush_reasons_per_combat_dispatch", func(): return _t_flush_reasons())
	runner.register_test("combat_baseline/no_combat_dispatch_ever_flushes_twice", func(): return _t_flush_never_exceeds_one())
	# D — encounter.retreat randomness is tick-bound
	runner.register_test("combat_baseline/retreat_roll_is_tick_bound", func(): return _t_retreat_tick_bound())
	runner.register_test("combat_baseline/retreat_uses_seeded_branch_not_fallback", func(): return _t_retreat_branch())
	# E — the two dormant actions
	runner.register_test("combat_baseline/dormant_encounter_advance", func(): return _t_encounter_advance())
	runner.register_test("combat_baseline/dormant_encounter_advance_without_context", func(): return _t_encounter_advance_no_ctx())
	runner.register_test("combat_baseline/dormant_encounter_complete", func(): return _t_encounter_complete())


# ---------------------------------------------------------------------------
# Shared harness
# ---------------------------------------------------------------------------

static func _hash(v: Variant) -> String:
	return JSON.stringify(v, "", true).sha256_text()


## Reuses the proven mode-forcing setup from tests/FlowFingerprintTests.gd rather than keeping a
## second copy of it: same isolated save path, same pinned root_seed 12346, same draw-then-
## override forcing of the resolution mode (so no RNG draw order shifts).
static func _setup(mode: String, seed_tag: String, guide_mode: String = "", guide_joins: String = "") -> Dictionary:
	return FlowFingerprintTests._setup_encounter(mode, seed_tag, guide_mode, guide_joins)


## Every field the seven emotion terms in _end_round() read or write, for one actor.
## `fear` / `morale` / the two scratch counters are captured with a -1 sentinel when the key is
## absent, so the ABSENCE of a field is pinned too (structures never receive an emotion tick).
static func _actor_emotion(a: Dictionary) -> Dictionary:
	return {
		"id":                  str(a.get("id", "")),
		"faction":             str(a.get("faction", "")),
		"is_dead":             bool(a.get("is_dead", false)),
		"is_structure":        bool(a.get("is_structure", false)),
		"fear":                int(a.get("fear", -1)),
		"morale":              int(a.get("morale", -1)),
		"witness_fear_taken":  int(a.get("_witness_fear_taken", -1)),
		"no_damage_streak":    int(a.get("_no_damage_streak", -1)),
	}


## id-sorted emotion projection of the whole board — stable regardless of initiative order.
static func _emotion_snapshot(actors: Array) -> Array:
	var rows: Array = []
	for a_v in actors:
		if a_v is Dictionary:
			rows.append(_actor_emotion(a_v as Dictionary))
	rows.sort_custom(func(x, y): return str(x["id"]) < str(y["id"]))
	return rows


## Drives the real round loop exactly the way FlowFingerprintTests._drive_and_capture does
## (combat.init → confirm_round → next_actor*), but captures the emotion projection at each
## round boundary instead of turns/positions. Same guards, same early stop on combat_over.
static func _drive_emotion(runtime: FlowRuntime, ectx: EncounterContext, max_rounds: int) -> Dictionary:
	var rounds: Array = []
	runtime.dispatch({ "type": "combat.init" })
	for _r in range(max_rounds):
		runtime.dispatch({ "type": "combat.confirm_round" })
		var guard: int = 0
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)):
				break
			if str(cs.get("round_phase", "")) != "in_round":
				break
			runtime.dispatch({ "type": "combat.next_actor" })
		rounds.append({
			"round":   int(ectx.combat_state.get("round_counter", 0)),
			"emotion": _emotion_snapshot(ectx.actors),
		})
		if bool(ectx.combat_state.get("combat_over", false)):
			break
	return {
		"rounds":      rounds,
		"combat_over": bool(ectx.combat_state.get("combat_over", false)),
	}


static func _flush_events(logger: StructuredLogger) -> Array:
	var out: Array = []
	for event_v in logger.get_logs():
		var event: Dictionary = event_v as Dictionary
		if str(event.get("type", "")) == "save.flush":
			out.append(str((event.get("data", {}) as Dictionary).get("reason", "")))
	return out


## Every state.transition the machines logged, as "machine_id|from|to|reason" strings in order.
static func _transition_events(logger: StructuredLogger) -> Array:
	var out: Array = []
	for event_v in logger.get_logs():
		var event: Dictionary = event_v as Dictionary
		if str(event.get("type", "")) != "state.transition":
			continue
		var d: Dictionary = event.get("data", {}) as Dictionary
		out.append("%s|%s|%s|%s" % [
			str(d.get("machine_id", "")),
			str(d.get("from_state", "")),
			str(d.get("to_state", "")),
			str(d.get("reason", "")),
		])
	return out


## RealmService.get_or_create() runs OUTSIDE dispatch() during setup, so it leaves a save
## queued under the reason "realm_create" that the NEXT dispatch flushes — and
## FlowRuntime._mark_save_requested() concatenates reasons with "|", so an unrelated setup
## reason would otherwise be glued onto the combat reason under test ("realm_create|combat.init").
## Draining it first is a harness concern, not a production one: in play the dispatch that
## created the realm flushed it. Returns false if the drain did not clear the queue.
static func _drain_pending_save(runtime: FlowRuntime) -> bool:
	# "debug.seed.show" only reads and logs (pinned flush-free by FlowTransactionTests), so it
	# adds nothing of its own to the queue.
	runtime.dispatch({ "type": "debug.seed.show" })
	return not runtime.flow_ctx.save_request


static func _has_log(logger: StructuredLogger, type: String) -> bool:
	for event_v in logger.get_logs():
		if str((event_v as Dictionary).get("type", "")) == type:
			return true
	return false


# ---------------------------------------------------------------------------
# A — emotion values per actor per round
# ---------------------------------------------------------------------------
#
# One constant per mode: the ordered list of per-round emotion hashes. A single whole-trace hash
# would be one byte cheaper and useless in a failure — this shape lets the assertion name the
# mode AND the round index that first diverged, which is what a Phase 6 debugging session needs.

const COMBAT_EMOTION_HASHES: Array = [
	"02d98695226aa349d3bc0d290d080c0d7c51bf17232a4b61e4c4888d894f4942",
	"23810625aee23d5f719c087ed23f641c138c59bfe7a6b74af453a4c2c19d2f01",
	"65856aeb0f5db7fe4b8a1e91268dc3a54e8d73729ac9ffb132c680db9d5e2e77",
	"b147bce40ca61bb578e538c62a9186328fd7a8c22c83aad3f3f9fd3272fdae8e",
	"0a4883070509f21c99ffe7713fa26d6c1383e79a65309ba7e56c84e97b973d21",
]
const PURIFY_SHRINE_EMOTION_HASHES: Array = [
	"b0a1a28cf5fab4efd04c78e8d88bdb61e86df8d366e860c6798e3cd4b78cf1a1",
	"acf21c63cdf575d95485ad060ed487195746239883255c4b5646cbefcf887d24",
	"017ccd83f41d75a0727193b559d2298a3baea3162f0ebd4fa4d51f2067b83f9c",
	"0a0ef8747ac8eae256da7f8de4ad43ea0adb7a10d39bf225d9a0bb9e5b6ba5e7",
]
const RECOVER_EMOTION_HASHES: Array = [
	"628671286fc1023cc80ec893d441c0b1164184228ebf46fe25fe3191f5378207",
	"e61b7e66d74f550214718c123d126cbcb7e8b40cdf0a8ae67b9e36e345472ee1",
]
const PROTECT_EMOTION_HASHES: Array = [
	"6cdb4efc892487a0753668ceda93ebc3b2b5e4c7938184326c50796d990c28eb",
	"a8cd3cbfe61d3b2ff91389b92252e1923a67ec1a15c7f3a5d3336c5cc983ea06",
	"314165cda4be77ea72311a0c440b4a14ea6a9954050511b7550a56b55b57beda",
	"97babd0655c972c41ceac61d5e21956435ba594d2385e312c79e05d4600e6ab8",
]
const ENDURE_EMOTION_HASHES: Array = [
	"02d98695226aa349d3bc0d290d080c0d7c51bf17232a4b61e4c4888d894f4942",
	"6a991e4303d99b2687bf1a19cc7b4346e05d19dd9c0c793a7cfefb6bab1a4651",
	"0c8b079cac30bb014d7c241303dbb7baa1efdc004da0f6cf1c5224a74844ed1a",
	"59697cc76fa36c80a25c08b032b3ea4c97653b6a8ea36af4ffa57dfcbd36f7c8",
	"12c9dda6e60997c12f9010e850f4e7dacacb1b9ee5b681ea38119ab8db021f17",
]
const PURSUE_EMOTION_HASHES: Array = [
	"5e6f15383743a09765793993107a3a42e183d4d98927eba0084f9c73755b8d77",
	"72a6bcc3ef7e082d6ff2176923a1bb24c34305d269c33c5439bfee1430d27c06",
	"355eba76db716818dd2dbcba1282aca1dae6617e63a922081c0ec47bf417baff",
	"766b8b1d278fb39800b7e49e9816bf7b12398de0f120589f95db8373cf87fbd4",
	"bc7febd30a33fff204ec63763b68cd78860eb3e40212ff429e1fa2fb6eb873fb",
]
const GUIDE_SPIRIT_EMOTION_HASHES: Array = [
	"1763e7b0005ec4f959d3154cbaf62d510fb1420c607f7c05eb330dd808c691b6",
	"9436b6ffdbc13f9fbf655165842baefcdff75667adc6ae2cc94539c5a9b76118",
	"256d8100669e359645a690217d8ee2337716d284d8d5ee7612febc83b4015128",
	"75d52c6def312b12921a8aec4830ad3f66a8732a6036a416d946265ad9926ea2",
	"aa28e139148d95d951e42dc66c15449035bf54f1fa6576423d3da30999e1d579",
	"ea87f2931bda7495deeac1f838bc38934096f7bc1ca427377b74c50f0bcf6d2e",
	"23f5d1d6eb49a4f310d759483eb57df84b08205bb06d4a0d2aa43b61d202614f",
	"13c902de0b0a85a0ab273d68d57738420f8c698c471e11eb909453bb6b8be414",
	"16db26d34cbf646994183bab84bb60719d18debd6a663e5ad6aeec53b90c5e23",
]


static func _emotion_trace(mode: String, seed_tag: String, guide_mode: String, guide_joins: String) -> Dictionary:
	var env: Dictionary = _setup(mode, seed_tag, guide_mode, guide_joins)
	if env.is_empty():
		return { "ok": false, "error": "setup failed for mode %s" % mode }
	var drive: Dictionary = _drive_emotion(env["runtime"], env["ectx"], MAX_ROUNDS)
	if not bool(drive.get("combat_over", false)):
		return { "ok": false, "error": "mode %s did not reach combat_over within %d rounds — refusing to record a baseline" % [mode, MAX_ROUNDS] }
	var rounds: Array = drive["rounds"]
	var hashes: Array = []
	for r_v in rounds:
		hashes.append(_hash(r_v))
	return { "ok": true, "hashes": hashes, "rounds": rounds }


static func _t_emotion(mode: String, seed_tag: String, guide_mode: String, guide_joins: String, expected: Array, label: String) -> Dictionary:
	var r: Dictionary = _emotion_trace(mode, seed_tag, guide_mode, guide_joins)
	if not bool(r.get("ok", false)):
		return r
	var actual: Array = r["hashes"]
	if RECORD_MODE or expected.is_empty():
		print("CB_RECORD emotion %s = %s" % [label, JSON.stringify(actual)])
		if RECORD_MODE:
			return { "ok": true }
		return { "ok": false, "error": "%s: no recorded emotion baseline — constant is empty (see CB_RECORD output)" % label }
	if actual.size() != expected.size():
		return { "ok": false, "error": "%s emotion trace: expected %d rounds, got %d (actual=%s)" % [label, expected.size(), actual.size(), JSON.stringify(actual)] }
	for i in range(actual.size()):
		if str(actual[i]) != str(expected[i]):
			var round_no: int = int((r["rounds"][i] as Dictionary).get("round", -1))
			return { "ok": false, "error": "%s emotion trace diverged at round index %d (round_counter=%d): expected=%s actual=%s | full actual trace=%s" \
				% [label, i, round_no, str(expected[i]), str(actual[i]), JSON.stringify(actual)] }
	return { "ok": true }


## A hash over values that never move would look like protection and provide none. This proves
## the emotion block writes real, changing values in the mode the fingerprints call baseline.
static func _t_emotion_is_non_trivial() -> Dictionary:
	var r: Dictionary = _emotion_trace(EncounterResolutionModes.COMBAT, "cb_emo_nontrivial", "", "")
	if not bool(r.get("ok", false)):
		return r
	var rounds: Array = r["rounds"]
	if rounds.size() < 2:
		return { "ok": false, "error": "expected at least 2 rounds to compare emotion movement, got %d" % rounds.size() }
	var first: Array = (rounds[0] as Dictionary)["emotion"]
	var last: Array = (rounds[rounds.size() - 1] as Dictionary)["emotion"]
	var fear_moved := false
	var morale_moved := false
	for i in range(mini(first.size(), last.size())):
		var a: Dictionary = first[i]
		var b: Dictionary = last[i]
		if str(a["id"]) != str(b["id"]):
			continue
		if int(a["fear"]) != int(b["fear"]):
			fear_moved = true
		if int(a["morale"]) != int(b["morale"]):
			morale_moved = true
	if not fear_moved:
		return { "ok": false, "error": "no actor's fear changed across the whole encounter — the emotion hashes pin nothing" }
	# CHARACTERIZATION — current behaviour, not necessarily correct.
	# morale is NOT asserted to move: terms C and G are gated (every morale_decay_n rounds;
	# a >= 2-round no-damage streak) and a short fight can legitimately end before either
	# fires. Recorded as an observation, not a requirement.
	var _morale_observed := morale_moved
	return { "ok": true }


# ---------------------------------------------------------------------------
# B — transition sequence
# ---------------------------------------------------------------------------
#
# Captured from combat.init to combat_over, so the list is exactly what the round loop produces.
# The setup transitions before combat.init (boot → splash → … → flow.encounter) belong to the
# encounter-entry path, not to the two functions Phase 6 moves, and are deliberately excluded.

const COMBAT_TRANSITIONS: Array = [
	"state.encounter||encounter.setup|initial",
	"state.encounter|encounter.setup|encounter.rounds|combat.init",
]
const PURIFY_SHRINE_TRANSITIONS: Array = [
	"state.encounter||encounter.setup|initial",
	"state.encounter|encounter.setup|encounter.rounds|combat.init",
]
const GUIDE_SPIRIT_TRANSITIONS: Array = [
	"state.encounter||encounter.setup|initial",
	"state.encounter|encounter.setup|encounter.rounds|combat.init",
]


static func _t_transitions(mode: String, seed_tag: String, guide_mode: String, guide_joins: String, expected: Array, label: String) -> Dictionary:
	var env: Dictionary = _setup(mode, seed_tag, guide_mode, guide_joins)
	if env.is_empty():
		return { "ok": false, "error": "setup failed for mode %s" % mode }
	var runtime: FlowRuntime = env["runtime"]
	runtime.logger.set_level(StructuredLogger.LEVEL_INFO)
	runtime.logger.clear()
	var drive: Dictionary = _drive_emotion(runtime, env["ectx"], MAX_ROUNDS)
	if not bool(drive.get("combat_over", false)):
		return { "ok": false, "error": "mode %s did not reach combat_over within %d rounds" % [mode, MAX_ROUNDS] }
	var actual: Array = _transition_events(runtime.logger)
	if RECORD_MODE or expected.is_empty():
		print("CB_RECORD transitions %s = %s" % [label, JSON.stringify(actual)])
		if RECORD_MODE:
			return { "ok": true }
		return { "ok": false, "error": "%s: no recorded transition baseline — constant is empty (see CB_RECORD output)" % label }
	if JSON.stringify(actual) != JSON.stringify(expected):
		return { "ok": false, "error": "%s transition sequence changed:\n  expected=%s\n  actual  =%s" % [label, JSON.stringify(expected), JSON.stringify(actual)] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# C — save flush count + reason per combat dispatch
# ---------------------------------------------------------------------------
#
# tests/FlowTransactionTests.gd owns the general invariant ("a dispatch flushes at most once")
# and the dispatch() action-label census. Neither of its tests touches a combat action. What is
# new here is the exact count AND the reason string each of the three combat dispatches
# produces, because a Phase 6 controller that requests a save under a different reason — or an
# extra time — would pass every existing test.

const FLUSH_INIT_REASONS: Array = ["combat.init"]
const FLUSH_CONFIRM_ROUND_REASONS: Array = []
const FLUSH_NEXT_ACTOR_REASONS: Array = []


static func _t_flush_reasons() -> Dictionary:
	var env: Dictionary = _setup(EncounterResolutionModes.COMBAT, "cb_flush")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	var logger: StructuredLogger = runtime.logger
	logger.set_level(StructuredLogger.LEVEL_DEBUG)
	if not _drain_pending_save(runtime):
		return { "ok": false, "error": "setup's queued save did not drain — the measured reasons would carry a harness prefix" }

	logger.clear()
	runtime.dispatch({ "type": "combat.init" })
	var init_reasons: Array = _flush_events(logger)

	logger.clear()
	runtime.dispatch({ "type": "combat.confirm_round" })
	var confirm_reasons: Array = _flush_events(logger)

	logger.clear()
	runtime.dispatch({ "type": "combat.next_actor" })
	var next_reasons: Array = _flush_events(logger)
	# Keep ectx referenced so a future edit cannot silently drop the encounter under test.
	var _phase: String = str(ectx.combat_state.get("round_phase", ""))

	if RECORD_MODE or FLUSH_INIT_REASONS.is_empty():
		print("CB_RECORD flush init=%s confirm=%s next=%s phase=%s" % [
			JSON.stringify(init_reasons), JSON.stringify(confirm_reasons), JSON.stringify(next_reasons), _phase])
		if RECORD_MODE:
			return { "ok": true }
		return { "ok": false, "error": "no recorded flush baseline — constants are empty (see CB_RECORD output)" }

	var mismatches: Array = []
	if JSON.stringify(init_reasons) != JSON.stringify(FLUSH_INIT_REASONS):
		mismatches.append("combat.init flushes: expected %s got %s" % [JSON.stringify(FLUSH_INIT_REASONS), JSON.stringify(init_reasons)])
	if JSON.stringify(confirm_reasons) != JSON.stringify(FLUSH_CONFIRM_ROUND_REASONS):
		mismatches.append("combat.confirm_round flushes: expected %s got %s" % [JSON.stringify(FLUSH_CONFIRM_ROUND_REASONS), JSON.stringify(confirm_reasons)])
	if JSON.stringify(next_reasons) != JSON.stringify(FLUSH_NEXT_ACTOR_REASONS):
		mismatches.append("combat.next_actor flushes: expected %s got %s" % [JSON.stringify(FLUSH_NEXT_ACTOR_REASONS), JSON.stringify(next_reasons)])
	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## Extends FlowTransactionTests' "at most one flush per dispatch" to every dispatch of a whole
## combat, including the final one that runs _end_round() and publishes the resolve snapshot.
static func _t_flush_never_exceeds_one() -> Dictionary:
	var env: Dictionary = _setup(EncounterResolutionModes.COMBAT, "cb_flush_seq")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	var logger: StructuredLogger = runtime.logger
	logger.set_level(StructuredLogger.LEVEL_DEBUG)

	# No lambda here on purpose: GDScript lambdas capture locals BY VALUE, so a closure that
	# incremented these counters would leave them at zero and the test would always pass.
	var worst: int = 0
	var worst_action: String = ""
	var dispatches: int = 0
	var pending: Array = [{ "type": "combat.init" }]

	while not pending.is_empty():
		var action: Dictionary = pending.pop_front()
		logger.clear()
		runtime.dispatch(action)
		var n: int = _flush_events(logger).size()
		dispatches += 1
		if n > worst:
			worst = n
			worst_action = str(action.get("type", ""))

		var cs: Dictionary = ectx.combat_state
		if bool(cs.get("combat_over", false)):
			break
		if dispatches > MAX_ROUNDS * 41:
			return { "ok": false, "error": "combat drive exceeded its dispatch budget without concluding" }
		if str(cs.get("round_phase", "")) == "in_round":
			pending.append({ "type": "combat.next_actor" })
		else:
			pending.append({ "type": "combat.confirm_round" })

	if not bool(ectx.combat_state.get("combat_over", false)):
		return { "ok": false, "error": "combat did not conclude within %d rounds" % MAX_ROUNDS }
	if dispatches < 3:
		return { "ok": false, "error": "expected the drive to issue at least 3 combat dispatches, issued %d" % dispatches }
	if worst > 1:
		return { "ok": false, "error": "a single '%s' dispatch produced %d save flushes" % [worst_action, worst] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# D — encounter.retreat randomness is tick-bound
# ---------------------------------------------------------------------------
#
# FlowRuntime._handle_encounter_retreat (:1013–:1017):
#     if flow_ctx.campaign_seed != null:
#         rng = flow_ctx.campaign_seed.get_rng("encounter.retreat." + encounter_id + "." + str(t))
#     else:
#         rng.seed = hash("encounter.retreat." + encounter_id + str(t))
#
# CHARACTERIZATION — current behaviour, not necessarily correct. Two findings pinned, neither
# fixed:
#   D-1 The seed path contains the dispatch tick, so the retreat outcome for one encounter is a
#       function of how many dispatches happened first. Any Phase 6 change to the dispatch count
#       on the way into an encounter re-rolls every retreat in the game. The pairs below make
#       that visible instead of silent.
#   D-2 The fallback branch (:1017) builds a DIFFERENT string from the primary path — no dot
#       before the tick ("...stage.0.cb_retreat3" vs "...stage.0.cb_retreat.3"). Two seed
#       namespaces for one concept. It is also unreachable in normal play, because boot()
#       always populates flow_ctx.campaign_seed; the test below forces it to prove which branch
#       production actually takes.

const RETREAT_TICK_OUTCOMES: Array = [
	{ "pad": 0, "snapshot_type": "flow.resolve",   "success": true,  "tick": 7 },
	{ "pad": 1, "snapshot_type": "flow.resolve",   "success": true,  "tick": 8 },
	{ "pad": 2, "snapshot_type": "flow.encounter", "success": false, "tick": 9 },
	{ "pad": 3, "snapshot_type": "flow.encounter", "success": false, "tick": 10 },
]
const RETREAT_FALLBACK_OUTCOME: Dictionary = { "snapshot_type": "flow.resolve", "success": true }

## A retreat that has a real chance of failing (success_pct 100 short-circuits the roll's
## observable effect and would pin nothing about the tick).
const RETREAT_SUCCESS_PCT := 50


## Runs one retreat at a controlled tick offset. Returns the tick it landed on and the outcome.
static func _retreat_probe(tag: String, padding_dispatches: int, null_seed: bool) -> Dictionary:
	var env: Dictionary = _setup(EncounterResolutionModes.COMBAT, tag)
	if env.is_empty():
		return { "ok": false, "error": "setup failed for %s" % tag }
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	flow_ctx.save_data["economy"]["ase"] = 500

	# "debug.seed.show" only reads and logs (FlowTransactionTests pins it as flush-free), so it
	# is a pure tick pump: it advances sim_tick and changes nothing else.
	for _i in range(padding_dispatches):
		runtime.dispatch({ "type": "debug.seed.show" })

	if null_seed:
		flow_ctx.campaign_seed = null

	var tick_at_dispatch: int = int(flow_ctx.sim_tick)
	runtime.dispatch({
		"type":        "encounter.retreat",
		"ase_cost":    0,
		"success_pct": RETREAT_SUCCESS_PCT,
	})
	# Success clears the encounter and publishes the scout-return resolve snapshot; failure
	# falls through to _handle_combat_init and leaves the context in place.
	var success: bool = flow_ctx.encounter_ctx == null
	return {
		"ok":               true,
		"tick":             tick_at_dispatch,
		"success":          success,
		"snapshot_type":    str((flow_ctx.last_snapshot as Dictionary).get("type", "")),
	}


static func _t_retreat_tick_bound() -> Dictionary:
	var observed: Array = []
	for pad in [0, 1, 2, 3]:
		var p: Dictionary = _retreat_probe("cb_retreat_pad%d" % pad, pad, false)
		if not bool(p.get("ok", false)):
			return p
		observed.append({ "pad": pad, "tick": int(p["tick"]), "success": bool(p["success"]), "snapshot_type": str(p["snapshot_type"]) })

	if RECORD_MODE or RETREAT_TICK_OUTCOMES.is_empty():
		print("CB_RECORD retreat_tick = %s" % JSON.stringify(observed))
		if RECORD_MODE:
			return { "ok": true }
		return { "ok": false, "error": "no recorded retreat baseline — constant is empty (see CB_RECORD output)" }

	if JSON.stringify(observed) != JSON.stringify(RETREAT_TICK_OUTCOMES):
		return { "ok": false, "error": "retreat tick/outcome table changed — a dispatch was added or removed on the way into the encounter, or the roll moved:\n  expected=%s\n  actual  =%s" \
			% [JSON.stringify(RETREAT_TICK_OUTCOMES), JSON.stringify(observed)] }

	# The point of the table: the tick is part of the seed, so at least one padding offset must
	# produce a different outcome from another. If they were all equal, the tick would be
	# decorative and this whole section would be pinning nothing.
	var successes: Dictionary = {}
	for row_v in RETREAT_TICK_OUTCOMES:
		successes[bool((row_v as Dictionary).get("success", false))] = true
	if successes.size() < 2:
		return { "ok": false, "error": "every padding offset produced the same retreat outcome — the recorded table cannot demonstrate tick-binding (table=%s)" % JSON.stringify(RETREAT_TICK_OUTCOMES) }
	return { "ok": true }


static func _t_retreat_branch() -> Dictionary:
	# Production always takes the seeded branch: boot() populates campaign_seed.
	var env: Dictionary = _setup(EncounterResolutionModes.COMBAT, "cb_retreat_branch")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var flow_ctx: FlowContext = env["flow_ctx"]
	if flow_ctx.campaign_seed == null:
		return { "ok": false, "error": "campaign_seed was null after boot() — the primary seeded branch would not be the one production takes" }

	# CHARACTERIZATION — current behaviour, not necessarily correct: the fallback at
	# FlowRuntime.gd:1017 hashes a string WITHOUT the dot separator, a different seed namespace
	# from the primary path one line above. Forced here purely to prove it is reachable code
	# with an observable, deterministic outcome — not to endorse it.
	var p: Dictionary = _retreat_probe("cb_retreat_fallback", 0, true)
	if not bool(p.get("ok", false)):
		return p
	var observed: Dictionary = { "success": bool(p["success"]), "snapshot_type": str(p["snapshot_type"]) }
	if RECORD_MODE or RETREAT_FALLBACK_OUTCOME.is_empty():
		print("CB_RECORD retreat_fallback = %s" % JSON.stringify(observed))
		if RECORD_MODE:
			return { "ok": true }
		return { "ok": false, "error": "no recorded retreat fallback baseline — constant is empty (see CB_RECORD output)" }
	if JSON.stringify(observed) != JSON.stringify(RETREAT_FALLBACK_OUTCOME):
		return { "ok": false, "error": "retreat fallback branch outcome changed: expected=%s actual=%s" % [JSON.stringify(RETREAT_FALLBACK_OUTCOME), JSON.stringify(observed)] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# E — the two dormant actions
# ---------------------------------------------------------------------------

const ADVANCE_RESULT: Dictionary = {
	"encounter_alive": true,
	"flushes":         [],
	"snapshot_type":   "flow.encounter",
	# from_state is "encounter.setup", not "": dispatch()'s common closure bootstraps the
	# encounter machine on the FIRST dispatch after an encounter context exists (the same
	# closure tests/FlowTransactionTests.gd documents), so by the time this action lands the
	# machine has already been started into SETUP. encounter.advance then jumps straight to
	# BLESSING with no phase guard of its own.
	"transitions":     ["state.encounter|encounter.setup|encounter.blessing|ui.encounter.advance"],
}
const COMPLETE_RESULT: Dictionary = {
	"encounter_ctx_null":     true,
	"encounter_machine_null": true,
	"flushes":                ["encounter.emotion_drift"],
	"snapshot_type":          "flow.resolve",
	"transitions":            ["state.flow|flow.splash|flow.resolve|ui.encounter.complete"],
}


## "encounter.advance" (FlowRuntime.gd:389). Registered, functional, and unreachable from any
## shipped snapshot — no snapshot builder emits an action of this type. Before this test no test
## in the repository dispatched it, so a Phase 6 edit to those nine lines had no guard at all.
static func _t_encounter_advance() -> Dictionary:
	var env: Dictionary = _setup(EncounterResolutionModes.COMBAT, "cb_advance")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var logger: StructuredLogger = runtime.logger
	logger.set_level(StructuredLogger.LEVEL_DEBUG)
	if not _drain_pending_save(runtime):
		return { "ok": false, "error": "setup's queued save did not drain" }
	logger.clear()

	var out: Dictionary = runtime.dispatch({ "type": "encounter.advance", "to": EncounterStateIds.BLESSING })

	var observed: Dictionary = {
		"snapshot_type":   str(out.get("type", "")),
		"transitions":     _transition_events(logger),
		"flushes":         _flush_events(logger),
		"encounter_alive": flow_ctx.encounter_ctx != null,
	}
	if RECORD_MODE or ADVANCE_RESULT.is_empty():
		print("CB_RECORD advance = %s" % JSON.stringify(observed))
		if RECORD_MODE:
			return { "ok": true }
		return { "ok": false, "error": "no recorded encounter.advance baseline — constant is empty (see CB_RECORD output)" }
	if JSON.stringify(observed) != JSON.stringify(ADVANCE_RESULT):
		return { "ok": false, "error": "encounter.advance behaviour changed:\n  expected=%s\n  actual  =%s" % [JSON.stringify(ADVANCE_RESULT), JSON.stringify(observed)] }
	return { "ok": true }


## The guard arm of the same nine lines: with no encounter context the handler logs and does
## nothing. Pinned so a restructure cannot turn a no-op into a crash or a transition.
static func _t_encounter_advance_no_ctx() -> Dictionary:
	var env: Dictionary = _setup(EncounterResolutionModes.COMBAT, "cb_advance_noctx")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var logger: StructuredLogger = runtime.logger
	logger.set_level(StructuredLogger.LEVEL_DEBUG)

	if not _drain_pending_save(runtime):
		return { "ok": false, "error": "setup's queued save did not drain" }
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	var before: String = JSON.stringify(flow_ctx.last_snapshot)
	logger.clear()

	var out: Dictionary = runtime.dispatch({ "type": "encounter.advance", "to": EncounterStateIds.BLESSING })

	var mismatches: Array = []
	if not _has_log(logger, "ui.encounter.advance"):
		mismatches.append("expected a ui.encounter.advance debug log for the uninitialized-encounter arm")
	if not _transition_events(logger).is_empty():
		mismatches.append("uninitialized encounter.advance transitioned a state machine: %s" % JSON.stringify(_transition_events(logger)))
	if not _flush_events(logger).is_empty():
		mismatches.append("uninitialized encounter.advance requested a save: %s" % JSON.stringify(_flush_events(logger)))
	if JSON.stringify(flow_ctx.last_snapshot) != before:
		mismatches.append("uninitialized encounter.advance changed the published snapshot")
	if JSON.stringify(out) != before:
		mismatches.append("dispatch() did not return the unchanged snapshot")
	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## "encounter.complete" (FlowRuntime.gd:403). Same story: registered, functional, unreachable,
## and never dispatched by any test. It applies encounter emotion drift, clears the ally fields,
## nulls the encounter context and transitions the FLOW machine to RESOLVE — four side effects
## in nine lines, previously unguarded.
static func _t_encounter_complete() -> Dictionary:
	var env: Dictionary = _setup(EncounterResolutionModes.COMBAT, "cb_complete")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var logger: StructuredLogger = runtime.logger
	logger.set_level(StructuredLogger.LEVEL_DEBUG)
	if not _drain_pending_save(runtime):
		return { "ok": false, "error": "setup's queued save did not drain" }
	logger.clear()

	var out: Dictionary = runtime.dispatch({ "type": "encounter.complete", "outcome": "victory" })

	var observed: Dictionary = {
		"snapshot_type":       str(out.get("type", "")),
		"transitions":         _transition_events(logger),
		"flushes":             _flush_events(logger),
		"encounter_ctx_null":     flow_ctx.encounter_ctx == null,
		"encounter_machine_null": flow_ctx.encounter_machine == null,
	}
	if RECORD_MODE or COMPLETE_RESULT.is_empty():
		print("CB_RECORD complete = %s" % JSON.stringify(observed))
		if RECORD_MODE:
			return { "ok": true }
		return { "ok": false, "error": "no recorded encounter.complete baseline — constant is empty (see CB_RECORD output)" }
	if JSON.stringify(observed) != JSON.stringify(COMPLETE_RESULT):
		return { "ok": false, "error": "encounter.complete behaviour changed:\n  expected=%s\n  actual  =%s" % [JSON.stringify(COMPLETE_RESULT), JSON.stringify(observed)] }
	return { "ok": true }
