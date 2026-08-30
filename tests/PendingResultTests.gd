# res://tests/PendingResultTests.gd
# V2-INFRA-003 Phase 8B — the durable run result (`save.flow.pending_result`).
#
# WHAT THIS SUITE PROVES, and how.
#
#   1. CLASSIFICATION. All four outcomes — victory / partial / defeat / withdrawal — and the
#      three resolve cards that deliberately produce NO durable result (contact, situation,
#      the "Result unavailable." fallback scaffold). Direct calls to
#      PendingResultService.classify(), on payload shapes taken from the measured key matrix in
#      docs/resolve-snapshot-block-spec.md §1.2.
#
#   2. SURVIVES A QUIT — the headline, and it is proved the only way that means anything: a
#      SECOND FlowRuntime is constructed on the SAME save file and booted. That reads the JSON
#      back off disk through SaveService.load_from_file() and its repair pass, in a runtime
#      whose FlowContext is brand new and shares not one Dictionary with the first. Nothing is
#      carried over in memory. If the result were volatile, the second runtime could not see it.
#      Both halves are covered: the WITHDRAWAL path (stage.return_home, whose result lived in
#      two FlowContext ints documented "never persisted to save") and a REAL COMBAT driven to
#      its end through the production dispatch loop.
#
#   3. ROUTING AND CONSUMPTION. flow.continue routes a booted runtime with a pending result
#      back to flow.resolve instead of the Sanctum, the replayed card carries the same data
#      keys and the same figures as the card the player saw, and pressing its cta.continue
#      consumes the result so the NEXT flow.continue goes to the Sanctum.
#
#   4. FIRST WRITE WINS. Republishing the same card does not re-stamp result_id or created_t.
#
# ISOLATION follows tests/VentureCharacterizationTests.gd exactly: every runtime boots against
# its own file under /tmp/echoes-vnext-tests/ via TestSaveHarness.fresh_save_path(), and
# "flow.new_game" is never dispatched (AGENTS.md common mistake #17). The reboot tests
# deliberately do NOT clear the save path between the two runtimes — that is the whole point.

class_name PendingResultTests
extends RefCounted

const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")


static func register(runner) -> void:
	# 1 — classification
	runner.register_test("pending_result/classify_covers_four_outcomes", func(): return _t_classify_outcomes())
	runner.register_test("pending_result/classify_excludes_non_outcome_cards", func(): return _t_classify_exclusions())
	# 2/3 — withdrawal end to end, across a real process-level quit
	runner.register_test("pending_result/withdrawal_is_captured", func(): return _t_withdrawal_captured())
	runner.register_test("pending_result/withdrawal_survives_a_quit", func(): return _t_withdrawal_survives_quit())
	runner.register_test("pending_result/continue_consumes_and_then_reaches_sanctum", func(): return _t_consumed_on_leaving_resolve())
	# 2 — combat end to end, across a real process-level quit
	runner.register_test("pending_result/combat_result_survives_a_quit", func(): return _t_combat_survives_quit())
	# 4 — idempotency of the capture
	runner.register_test("pending_result/capture_is_first_write_wins", func(): return _t_first_write_wins())
	# 5 — D84: the run's own bond and Thread movement is on the card
	runner.register_test("pending_result/bond_and_thread_are_on_the_card", func(): return _t_bond_and_thread_cadence())


# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

static func _fresh_save_path(tag: String) -> String:
	return TestSaveHarness.fresh_save_path("pending_result_%s.json" % tag, "pending_result")


static func _logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level(StructuredLogger.LEVEL_DEBUG)
	return l


## A brand-new FlowRuntime booted against an EXISTING save file. This is the quit: nothing from
## the first runtime is passed in — not the FlowContext, not the save Dictionary, not the
## EconomyService. The data has to come back off disk.
static func _reboot(save_path: String) -> FlowRuntime:
	var runtime := FlowRuntime.new(_logger(), ConfigService.new(), save_path)
	runtime.boot()
	return runtime


static func _data_of(snap: Dictionary) -> Dictionary:
	var v: Variant = snap.get("data", {})
	return v if v is Dictionary else {}


static func _sorted_keys(d: Dictionary) -> Array:
	var k: Array = d.keys()
	k.sort()
	return k


## A minimal snapshot in the shape a given producer emits. Only the keys classify() reads are
## present — that is the point: it must classify on those and nothing else.
static func _resolve_snap(data: Dictionary) -> Dictionary:
	return { "type": FlowStateIds.RESOLVE, "meta": { "t": 1 }, "data": data, "actions": {} }


# ---------------------------------------------------------------------------
# 1 — classification
# ---------------------------------------------------------------------------

## Producer A emits no run_type and always calls the combat-stats block, so `encounter_id` is
## present on every combat card. victory + no objectives left = the stage is clear; victory with
## objectives left is the "partial" the action set already distinguishes (that case offers no
## cta.next_stage); victory false is a defeat. Producer C's card is the withdrawal.
static func _t_classify_outcomes() -> Dictionary:
	var cases: Array = [
		{ "name": "victory",    "data": { "encounter_id": "e1", "victory": true,  "objectives_remaining": 0 }, "want": PendingResultService.OUTCOME_VICTORY },
		{ "name": "partial",    "data": { "encounter_id": "e1", "victory": true,  "objectives_remaining": 2 }, "want": PendingResultService.OUTCOME_PARTIAL },
		{ "name": "defeat",     "data": { "encounter_id": "e1", "victory": false, "objectives_remaining": 1 }, "want": PendingResultService.OUTCOME_DEFEAT },
		{ "name": "withdrawal", "data": { "run_type": "scout_return", "victory": false, "intel_count": 3 },    "want": PendingResultService.OUTCOME_WITHDRAWAL },
	]
	var mismatches: Array = []
	for c_v in cases:
		var c: Dictionary = c_v
		var got := PendingResultService.classify(_resolve_snap(c["data"]))
		if got != str(c["want"]):
			mismatches.append("%s: expected '%s', got '%s'" % [str(c["name"]), str(c["want"]), got])
	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## The three resolve cards that must NOT become durable, and one non-resolve snapshot.
##
## The fallback scaffold is the important one. Producer F emits victory:false and nothing else,
## so it would otherwise read as a defeat — and it is reached only when Resolve was entered with
## nothing to show. Persisting it would turn an error card into a real recorded defeat that
## flow.continue then served back. It is excluded by the absence of the combat-stats block,
## which producers A and B always emit and F never does.
static func _t_classify_exclusions() -> Dictionary:
	var cases: Array = [
		{ "name": "contact card",     "snap": _resolve_snap({ "run_type": "contact_result", "verdict": "passed" }) },
		{ "name": "situation card",   "snap": _resolve_snap({ "run_type": "situation_result", "ase_awarded": 12 }) },
		{ "name": "fallback scaffold","snap": _resolve_snap({ "victory": false }) },
		{ "name": "sanctum snapshot", "snap": { "type": FlowStateIds.SANCTUM, "meta": { "t": 1 }, "data": { "victory": false }, "actions": {} } },
	]
	var mismatches: Array = []
	for c_v in cases:
		var c: Dictionary = c_v
		var got := PendingResultService.classify(c["snap"] as Dictionary)
		if not got.is_empty():
			mismatches.append("%s must not classify as a run outcome, got '%s'" % [str(c["name"]), got])
	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 2/3 — withdrawal, end to end
# ---------------------------------------------------------------------------

## Drives a real, successful stage.return_home. The escape roll is seeded from
## (realm seed, stage id, turn_count); the helper derives the same stream and picks the first
## turn_count that rolls a success, so no production value is nudged — the same technique
## tests/VentureCharacterizationTests.gd::_t_return_home_scout_return uses.
static func _drive_withdrawal(tag: String) -> Dictionary:
	var save_path := _fresh_save_path(tag)
	var runtime := FlowRuntime.new(_logger(), ConfigService.new(), save_path)
	runtime.boot()

	var cfg: Dictionary = runtime.config_service.get_balance()
	var options: Array = OnboardingService.build_fragment_options(runtime.flow_ctx.save_data, cfg)
	if options.is_empty():
		return { "ok": false, "error": "could not create deterministic starter fragment options" }
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(options[0].get("virtue", "")))
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })
	# Both prologues are marked complete IN SAVE DATA, not just in memory. The sibling suites
	# only force the keeper flag, because they never reboot; this one does, and flow.continue
	# checks Chapter One first (FlowRuntime.gd, the "flow.continue" arm). A player who has run
	# a realm has finished both, so this is the honest resumed state, not a shortcut around the
	# routing order.
	var ob_v: Variant = runtime.get_save_data().get("onboarding", {})
	if ob_v is Dictionary:
		(ob_v as Dictionary)["chapter_one_complete"]  = true
		(ob_v as Dictionary)["chapter_one_step"]      = OnboardingService.STEP_COMPLETE
		(ob_v as Dictionary)["keeper_intro_complete"] = true
		(ob_v as Dictionary)["keeper_intro_step"]     = "complete"
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.sanctum" })

	var sanctum_v: Variant = runtime.get_save_data().get("sanctum", {})
	var roster_v: Variant = (sanctum_v as Dictionary).get("roster", []) if sanctum_v is Dictionary else []
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty() or not (roster[0] is Dictionary):
		return { "ok": false, "error": "roster empty after onboarding" }
	var echo_id := str((roster[0] as Dictionary).get("id", ""))

	runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })
	runtime.dispatch({ "type": "flow.select_realm", "realm_id": "realm.01" })
	runtime.dispatch({ "type": "flow.select_stage", "stage_id": "stage.0" })
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.stage_explore" })

	var flow_ctx: FlowContext = runtime.flow_ctx
	var realms_v: Variant = runtime.get_save_data().get("realms", {})
	var realm: Dictionary = (realms_v as Dictionary).get("realm.01", {}) if realms_v is Dictionary else {}
	var realm_seed := int(realm.get("seed", 0))
	var directive: Dictionary = runtime.directive_service.get_active_directive()
	var escape_threshold: int = maxi(0, 40 - int(directive.get("escape_bonus", 0)))

	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return { "ok": false, "error": "no active stage after entering exploration" }
	var emap_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = emap_v if emap_v is Dictionary else {}

	var chosen_turn := -1
	for candidate in range(0, 200):
		var probe := CampaignSeed.get_rng_from(realm_seed, "stage.escape.%s.%d" % [flow_ctx.stage_id, candidate])
		if probe.randi_range(0, 100) > escape_threshold:
			chosen_turn = candidate
			break
	if chosen_turn < 0:
		return { "ok": false, "error": "no turn_count in 0..199 produced a successful escape roll" }
	explore_map["turn_count"] = chosen_turn
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)

	var card: Dictionary = runtime.dispatch({ "type": "stage.return_home" })
	if str(card.get("type", "")) != FlowStateIds.RESOLVE:
		return { "ok": false, "error": "return_home did not publish a resolve card, got '%s'" % str(card.get("type", "")) }
	return { "ok": true, "runtime": runtime, "save_path": save_path, "card": card }


## The withdrawal result is written, and it carries the two values that used to live ONLY in
## FlowContext.pending_scout_return_ase / _intel_count — fields the file itself documents as
## "never persisted to save" and which the dispatch closure zeroes one dispatch later.
static func _t_withdrawal_captured() -> Dictionary:
	var env := _drive_withdrawal("wd_cap")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var card: Dictionary = env["card"]
	var card_data := _data_of(card)

	var pr := PendingResultService.read(runtime.get_save_data())
	var mismatches: Array = []
	if pr.is_empty():
		return { "ok": false, "error": "no durable result written for a successful withdrawal" }
	if str(pr.get("outcome", "")) != PendingResultService.OUTCOME_WITHDRAWAL:
		mismatches.append("expected outcome '%s', got '%s'" % [PendingResultService.OUTCOME_WITHDRAWAL, str(pr.get("outcome", ""))])
	if int(pr.get("version", 0)) != PendingResultService.RESULT_VERSION:
		mismatches.append("expected version %d, got %s" % [PendingResultService.RESULT_VERSION, str(pr.get("version", ""))])
	if str(pr.get("source", "")) != "scout_return":
		mismatches.append("expected source 'scout_return', got '%s'" % str(pr.get("source", "")))
	if str(pr.get("realm_id", "")) != "realm.01":
		mismatches.append("expected realm_id 'realm.01', got '%s'" % str(pr.get("realm_id", "")))
	var intel_v: Variant = pr.get("intel", {})
	var intel: Dictionary = intel_v if intel_v is Dictionary else {}
	if int(intel.get("intel_count", -1)) != int(card_data.get("intel_count", -2)):
		mismatches.append("durable intel_count %s does not match the card's %s" % [str(intel.get("intel_count", "")), str(card_data.get("intel_count", ""))])
	var econ_v: Variant = pr.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	if int(econ.get("ase_awarded", -1)) != int(card_data.get("ase_awarded", -2)):
		mismatches.append("durable ase_awarded %s does not match the card's %s" % [str(econ.get("ase_awarded", "")), str(card_data.get("ase_awarded", ""))])
	# The volatile source of those two numbers is already gone by the end of the dispatch —
	# which is exactly why the durable copy had to be taken inside it.
	if runtime.flow_ctx.pending_scout_return_ase != 0 or runtime.flow_ctx.pending_scout_return_intel_count != 0:
		mismatches.append("expected the volatile scout one-shots consumed by the end of the dispatch")
	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## THE QUIT. A second FlowRuntime is constructed on the same file and booted — the result has
## to come back through SaveService's JSON round trip. flow.continue must then land on the card
## rather than the Sanctum, and the replayed card must carry the same keys and the same figures.
static func _t_withdrawal_survives_quit() -> Dictionary:
	var env := _drive_withdrawal("wd_quit")
	if not bool(env.get("ok", false)):
		return env
	var card: Dictionary = env["card"]
	var card_data := _data_of(card)
	var save_path: String = env["save_path"]

	var rebooted := _reboot(save_path)
	var mismatches: Array = []
	if not PendingResultService.has_pending(rebooted.get_save_data()):
		return { "ok": false, "error": "the durable result did not survive the reboot — save.flow.pending_result is empty in a runtime booted from the file" }

	var replayed: Dictionary = rebooted.dispatch({ "type": "flow.continue" })
	if str(replayed.get("type", "")) != FlowStateIds.RESOLVE:
		return { "ok": false, "error": "flow.continue with a pending result published '%s', expected %s" % [str(replayed.get("type", "")), FlowStateIds.RESOLVE] }

	var replayed_data := _data_of(replayed)
	if _sorted_keys(replayed_data) != _sorted_keys(card_data):
		mismatches.append("replayed card data keys %s differ from the original %s" % [str(_sorted_keys(replayed_data)), str(_sorted_keys(card_data))])
	if str(replayed_data.get("run_type", "")) != "scout_return":
		mismatches.append("expected the replayed card to keep run_type 'scout_return', got '%s'" % str(replayed_data.get("run_type", "")))
	if int(replayed_data.get("intel_count", -1)) != int(card_data.get("intel_count", -2)):
		mismatches.append("replayed intel_count %s != original %s" % [str(replayed_data.get("intel_count", "")), str(card_data.get("intel_count", ""))])
	if int(replayed_data.get("ase_awarded", -1)) != int(card_data.get("ase_awarded", -2)):
		mismatches.append("replayed ase_awarded %s != original %s" % [str(replayed_data.get("ase_awarded", "")), str(card_data.get("ase_awarded", ""))])
	# meta.t is this dispatch's tick, never the stored one — the snapshot contract requires it.
	var meta_v: Variant = replayed.get("meta", {})
	var meta: Dictionary = meta_v if meta_v is Dictionary else {}
	if not meta.has("t"):
		mismatches.append("replayed card has no meta.t")
	# The realm/stage context the card acts on must come back too, or its cta could not settle.
	if rebooted.flow_ctx.realm_id != "realm.01":
		mismatches.append("expected realm_id restored to 'realm.01', got '%s'" % rebooted.flow_ctx.realm_id)
	if rebooted.flow_ctx.stage_id.is_empty():
		mismatches.append("expected stage_id restored from the durable result, got ''")
	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## Pressing the card's cta.continue publishes a non-resolve snapshot, which consumes the result.
## A LATER flow.continue must then behave normally and reach the Sanctum. Without the
## consumption the player would be trapped on the resolve card forever.
static func _t_consumed_on_leaving_resolve() -> Dictionary:
	var env := _drive_withdrawal("wd_consume")
	if not bool(env.get("ok", false)):
		return env
	var save_path: String = env["save_path"]

	var rebooted := _reboot(save_path)
	rebooted.dispatch({ "type": "flow.continue" })

	var mismatches: Array = []
	var left: Dictionary = rebooted.dispatch({ "type": "flow.go_state", "to": FlowStateIds.SANCTUM })
	if str(left.get("type", "")) != FlowStateIds.SANCTUM:
		mismatches.append("cta.continue did not reach the Sanctum, got '%s'" % str(left.get("type", "")))
	if PendingResultService.has_pending(rebooted.get_save_data()):
		mismatches.append("the durable result was not consumed on leaving the resolve card")

	# And it stays consumed across another quit: the next session goes to the Sanctum.
	var again := _reboot(save_path)
	if PendingResultService.has_pending(again.get_save_data()):
		mismatches.append("the consumption was not persisted — a rebooted runtime still sees a pending result")
	var next_snap: Dictionary = again.dispatch({ "type": "flow.continue" })
	if str(next_snap.get("type", "")) != FlowStateIds.SANCTUM:
		mismatches.append("after consumption flow.continue should reach the Sanctum, got '%s'" % str(next_snap.get("type", "")))
	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 2 — combat, end to end
# ---------------------------------------------------------------------------

## A REAL encounter driven to its end through the production dispatch loop, then quit and
## resumed. Reuses tests/FlowFingerprintTests.gd's setup and driver rather than keeping a second
## copy of them — the same cross-call tests/CombatBaselineTests.gd already makes.
##
## The outcome is not hard-coded: whichever of victory/partial/defeat this seed produces, the
## durable record must match the card, survive the reboot, and replay with the same keys.
static func _t_combat_survives_quit() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "pr_combat")
	if env.is_empty():
		return { "ok": false, "error": "encounter setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	var save_path: String = runtime.save_path
	# Same reason as _drive_withdrawal: this test reboots, and flow.continue checks the two
	# prologues before anything else. Set before the drive so the flush carries them.
	var ob_v: Variant = runtime.get_save_data().get("onboarding", {})
	if ob_v is Dictionary:
		(ob_v as Dictionary)["chapter_one_complete"]  = true
		(ob_v as Dictionary)["chapter_one_step"]      = OnboardingService.STEP_COMPLETE
		(ob_v as Dictionary)["keeper_intro_complete"] = true
		(ob_v as Dictionary)["keeper_intro_step"]     = "complete"

	FlowFingerprintTests._drive_and_capture(runtime, ectx, 30)

	var card: Dictionary = runtime.flow_ctx.last_snapshot
	if str(card.get("type", "")) != FlowStateIds.RESOLVE:
		return { "ok": false, "error": "combat did not conclude on a resolve card, got '%s'" % str(card.get("type", "")) }
	var card_data := _data_of(card)

	var pr := PendingResultService.read(runtime.get_save_data())
	var mismatches: Array = []
	if pr.is_empty():
		return { "ok": false, "error": "no durable result written at the end of a real combat" }
	var outcome := str(pr.get("outcome", ""))
	if not (outcome in [PendingResultService.OUTCOME_VICTORY, PendingResultService.OUTCOME_PARTIAL, PendingResultService.OUTCOME_DEFEAT]):
		mismatches.append("combat produced outcome '%s', expected one of victory/partial/defeat" % outcome)
	if str(pr.get("source", "")) != "combat":
		mismatches.append("expected source 'combat', got '%s'" % str(pr.get("source", "")))
	if str(pr.get("encounter_id", "")) != str(card_data.get("encounter_id", "")):
		mismatches.append("durable encounter_id '%s' != card's '%s'" % [str(pr.get("encounter_id", "")), str(card_data.get("encounter_id", ""))])
	var econ_v: Variant = pr.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	if int(econ.get("ase_awarded", -1)) != int(card_data.get("ase_awarded", -2)):
		mismatches.append("durable ase_awarded %s != card's %s" % [str(econ.get("ase_awarded", "")), str(card_data.get("ase_awarded", ""))])
	if str(econ.get("rank", "")) != str(card_data.get("rank", "")):
		mismatches.append("durable rank '%s' != card's '%s'" % [str(econ.get("rank", "")), str(card_data.get("rank", ""))])
	var emo_v: Variant = pr.get("emotion_summary", [])
	var emo: Array = emo_v if emo_v is Array else []
	var card_emo_v: Variant = card_data.get("emotion_summary", [])
	var card_emo: Array = card_emo_v if card_emo_v is Array else []
	if emo.size() != card_emo.size():
		mismatches.append("durable emotion_summary has %d rows, card has %d" % [emo.size(), card_emo.size()])

	# THE QUIT.
	var rebooted := _reboot(save_path)
	if not PendingResultService.has_pending(rebooted.get_save_data()):
		mismatches.append("the combat result did not survive the reboot")
	else:
		var replayed: Dictionary = rebooted.dispatch({ "type": "flow.continue" })
		if str(replayed.get("type", "")) != FlowStateIds.RESOLVE:
			mismatches.append("flow.continue after a combat quit published '%s', expected %s" % [str(replayed.get("type", "")), FlowStateIds.RESOLVE])
		else:
			var replayed_data := _data_of(replayed)
			if _sorted_keys(replayed_data) != _sorted_keys(card_data):
				mismatches.append("replayed combat card keys %s differ from the original %s" % [str(_sorted_keys(replayed_data)), str(_sorted_keys(card_data))])
			if bool(replayed_data.get("victory", not bool(card_data.get("victory", false)))) != bool(card_data.get("victory", false)):
				mismatches.append("replayed victory flag does not match the original")
			var r_actions_v: Variant = replayed.get("actions", {})
			var r_actions: Dictionary = r_actions_v if r_actions_v is Dictionary else {}
			var c_actions_v: Variant = card.get("actions", {})
			var c_actions: Dictionary = c_actions_v if c_actions_v is Dictionary else {}
			if _sorted_keys(r_actions) != _sorted_keys(c_actions):
				mismatches.append("replayed action slots %s differ from the original %s" % [str(_sorted_keys(r_actions)), str(_sorted_keys(c_actions))])

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 4 — first write wins
# ---------------------------------------------------------------------------

## `result_id` and `created_t` name the moment the run ended. Republishing the card — a refresh,
## a rebuild, a second validation pass — must not move them. Same shape as
## StageSettlementService's `settled` receipt, and the reason the capture is safe to run on
## EVERY dispatch.
static func _t_first_write_wins() -> Dictionary:
	var env := _drive_withdrawal("wd_once")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var card: Dictionary = env["card"]

	var before := PendingResultService.read(runtime.get_save_data()).duplicate(true)
	if before.is_empty():
		return { "ok": false, "error": "nothing captured to re-capture" }

	var again := PendingResultService.capture_or_consume(runtime.flow_ctx, card, 99999)
	var after := PendingResultService.read(runtime.get_save_data())

	var mismatches: Array = []
	if not again.is_empty():
		mismatches.append("a second capture of the same card reported '%s', expected no action" % again)
	if str(after.get("result_id", "")) != str(before.get("result_id", "")):
		mismatches.append("result_id was re-stamped: '%s' -> '%s'" % [str(before.get("result_id", "")), str(after.get("result_id", ""))])
	if int(after.get("created_t", -1)) != int(before.get("created_t", -2)):
		mismatches.append("created_t was re-stamped: %s -> %s" % [str(before.get("created_t", "")), str(after.get("created_t", ""))])
	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 5 — D84: the consequences of the run are captured WITH the card
# ---------------------------------------------------------------------------

## THE CADENCE PIN. The bond hooks and the Thread segment used to run in the
## `flow.complete_stage` dispatch — after this card was published, and in the dispatch that
## consumes it — so `bond_outcome` was always `{}` and `thread_outcome` never named this run's
## segment. They now run in the dispatch that ends the fight.
##
## Three claims, all on one real combat driven through the production dispatch loop:
##   1. `bond_outcome` is populated on a victory, at capture time, with THIS fight's figures
##      (its echo count must match the card's own actor rows).
##   2. On a stage-clearing victory `thread_outcome.segment` names the segment this run added.
##   3. The Thread segment is still STAGE cadence: the `flow.complete_stage` that follows must
##      not append a second segment for the same stage.
static func _t_bond_and_thread_cadence() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "pr_d84")
	if env.is_empty():
		return { "ok": false, "error": "encounter setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]

	# The shared harness builds a generated multi-objective stage, so its fight classifies as
	# "partial" and clears no stage. Mark the stage's other objectives done so this fight is the
	# LAST one — that is the only card that offers cta.next_stage, and therefore the only card a
	# Thread segment belongs to. Read at snapshot time only
	# (EncounterSnapshotBuilder._count_remaining_required_objectives); nothing about the fight,
	# the rewards or the RNG draw order depends on it.
	var _stage_ref := _first_stage(runtime.flow_ctx)
	if _stage_ref.is_empty():
		return { "ok": false, "error": "harness stage not found — cannot force a stage-clearing victory" }
	var _objs_v: Variant = _stage_ref.get("objectives", [])
	var _objs: Array = _objs_v if _objs_v is Array else []
	for _o_v in _objs:
		if _o_v is Dictionary:
			(_o_v as Dictionary)["completed"] = true

	FlowFingerprintTests._drive_and_capture(runtime, ectx, 30)

	var card: Dictionary = runtime.flow_ctx.last_snapshot
	if str(card.get("type", "")) != FlowStateIds.RESOLVE:
		return { "ok": false, "error": "combat did not conclude on a resolve card, got '%s'" % str(card.get("type", "")) }

	var pr := PendingResultService.read(runtime.get_save_data())
	if pr.is_empty():
		return { "ok": false, "error": "no durable result written at the end of a real combat" }

	var outcome := str(pr.get("outcome", ""))
	var bond_v: Variant = pr.get("bond_outcome", {})
	var bond: Dictionary = bond_v if bond_v is Dictionary else {}
	var thread_v: Variant = pr.get("thread_outcome", {})
	var thread: Dictionary = thread_v if thread_v is Dictionary else {}
	var mismatches: Array = []

	if outcome == PendingResultService.OUTCOME_DEFEAT:
		# A defeat fires no bond hook and clears no stage — the same reachable set the two old
		# call sites had. Nothing to record, and recording something would be an invention.
		if not bond.is_empty():
			mismatches.append("a defeat recorded a bond_outcome: %s" % JSON.stringify(bond))
	else:
		if bond.is_empty():
			mismatches.append("bond_outcome is empty on a %s — the hooks did not run before the capture" % outcome)
		else:
			var trig_v: Variant = bond.get("triggers", {})
			var trig: Dictionary = trig_v if trig_v is Dictionary else {}
			if str(trig.get("outcome", "")) != "win":
				mismatches.append("bond_outcome.triggers.outcome expected 'win', got '%s'" % str(trig.get("outcome", "")))
			var card_actors_v: Variant = _data_of(card).get("actors", [])
			var card_actors: Array = card_actors_v if card_actors_v is Array else []
			var card_echoes := 0
			for a_v in card_actors:
				if a_v is Dictionary and str((a_v as Dictionary).get("faction", "")) == "echo":
					card_echoes += 1
			if int(trig.get("echo_count", -1)) != card_echoes:
				mismatches.append("bond_outcome counted %s echoes, the card shows %d — it is not this fight" \
					% [str(trig.get("echo_count", "")), card_echoes])
			if not bond.has("aftermath") or not bond.has("rivals"):
				mismatches.append("bond_outcome is missing a hook: keys %s" % str(bond.keys()))

	var seg_v: Variant = thread.get("segment", {})
	var seg: Dictionary = seg_v if seg_v is Dictionary else {}
	if outcome == PendingResultService.OUTCOME_VICTORY:
		if seg.is_empty():
			mismatches.append("a stage-clearing victory recorded no thread_outcome.segment")
		elif int(thread.get("segments", 0)) < 1:
			mismatches.append("thread_outcome.segments did not count the segment just contributed")

		# STAGE CADENCE HOLDS. The card's own cta.next_stage dispatch must not add a second
		# segment for the stage the fight already contributed.
		var realm_before: Dictionary = RealmService.get_active(runtime.flow_ctx)
		var segs_before: int = (realm_before.get("realm_recovery_segments", []) as Array).size()
		runtime.dispatch({ "type": "flow.complete_stage" })
		var realms_v: Variant = runtime.get_save_data().get("realms", {})
		var realms: Dictionary = realms_v if realms_v is Dictionary else {}
		var realm_after_v: Variant = realms.get("realm.01", {})
		var realm_after: Dictionary = realm_after_v if realm_after_v is Dictionary else {}
		var segs_after: int = (realm_after.get("realm_recovery_segments", []) as Array).size()
		if segs_after != segs_before:
			mismatches.append("flow.complete_stage appended a SECOND recovery segment for the same stage: %d -> %d" \
				% [segs_before, segs_after])
	else:
		if not seg.is_empty():
			mismatches.append("a %s contributed a recovery segment: %s" % [outcome, JSON.stringify(seg)])

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## stage index 0 of the harness realm, by reference into save_data.
static func _first_stage(flow_ctx: FlowContext) -> Dictionary:
	var model := RealmService.get_active(flow_ctx)
	var stages_v: Variant = model.get("stages", [])
	var stages: Array = stages_v if stages_v is Array else []
	for s_v in stages:
		if s_v is Dictionary and int((s_v as Dictionary).get("index", -1)) == 0:
			return s_v
	return {}
