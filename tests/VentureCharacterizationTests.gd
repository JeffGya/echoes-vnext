# res://tests/VentureCharacterizationTests.gd
# V2-INFRA-003 — characterization guard for the venture-side FlowRuntime handlers that are
# about to be moved out of core/runtime/FlowRuntime.gd.
#
# SCOPE. These handlers had ZERO dispatch-level coverage before this file:
#   A. "flow.complete_stage"      → FlowRuntime._handle_complete_stage()        (:742–:858)
#   B. "encounter.retreat"        → FlowRuntime._handle_encounter_retreat()     (:1076–:1141)
#   C. FlowRuntime._build_scout_return_snapshot()                               (:4326–:4381)
#      — reached from BOTH call sites: encounter.retreat (:1134) and
#        _handle_stage_return_home (:4869)
#   D. "stage.confirm_return_home" (:562–:563) and "stage.dismiss_overlay" (:565–:571)
#   E. ContactController._build_contact_resolve_snapshot()
#      — shape guard only; the SITUATION side of the same merge is already covered by
#        tests/UnifiedResolveTests.gd and is deliberately NOT duplicated here.
#
# CHARACTERIZATION, NOT CORRECTION. Every assertion records what the code does TODAY. Where
# today's behaviour is wrong, the test still asserts the wrong behaviour and carries a
#   # CHARACTERIZATION — current behaviour, not necessarily correct
# marker. Inverting one of these is the job of the slice that fixes it, never of a later agent
# trying to make its own test pass. Frozen defects, all in core/runtime/FlowRuntime.gd:
#   D1 FIXED by V2-INFRA-003 Phase 5 Slice B — the scout-return snapshot's meta carried
#              "sim_tick", not "t", so it tripped FlowStateMachine._validate_snapshot()'s
#              assert(false) on every successful retreat and return-home in a debug build.
#              The fix was product-owner approved; the three assertions that pinned the defect
#              are INVERTED below (never deleted) and now pin the corrected contract.
#   D2 FIXED by V2-INFRA-003 Phase 5 Slice B — _build_scout_return_snapshot() zeroed the two
#              FlowContext fields it reads, so it consumed its own input and a second build
#              silently degraded to 0 Ase / 0 crossings. The one-shot consumption moved to the
#              gated closure at the end of FlowRuntime.dispatch(), beside the
#              pending_awakening_banner precedent. Assertion inverted below.
#   D3 FIXED by V2-INFRA-003 Phase 5 Slice B — the same builder constructed
#              SanctumService.new(flow_ctx.save_data) purely to read the party, and that
#              constructor can WRITE to save_data (SanctumState._ensure_sanctum_dict_exists) —
#              AGENTS.md "Common Mistakes" #18. It now calls the static
#              SanctumService.get_party_actors_static(). Assertion inverted below; the probe
#              that the CONSTRUCTOR still writes is kept, because that is the standing reason
#              the static reader has to exist.
#   D4 :744–:749 — _handle_complete_stage() with NO encounter_ctx defaults outcome to "loss",
#              so completing a stage without a fight pays the full defeat emotion drift.
#   D5 :855–:857 — when the destination override is flow.sanctum, run emotion modifiers are
#              applied with the literal string "victory" regardless of the real outcome.
#
# ISOLATION (docs/LESSONS.md #12 + tests/AGENTS.md):
#   - every runtime boots against its own file under /tmp/echoes-vnext-tests/venture_char/,
#     created with DirAccess.make_dir_recursive_absolute() and deleted first, so boot() always
#     mints a brand-new save with the pinned literal root_seed 12346.
#   - "flow.new_game" is never dispatched (AGENTS.md "Common Mistakes" #17 — it draws a random
#     campaign seed via Crypto.generate_random_bytes()). Onboarding is driven from boot() the
#     same way tests/FlowSnapshotFingerprintTests.gd does it.
#   - balances are written directly onto the save dict, never through "economy.ase.add".
#   - save_data is mutated IN PLACE, never replaced: FlowRuntime.boot() binds EconomyService and
#     DirectiveService to that exact Dictionary, so swapping the reference would silently
#     detach econ from the data under test.

class_name VentureCharacterizationTests
extends RefCounted

const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")


static func register(runner) -> void:
	# A — flow.complete_stage
	runner.register_test("venture_char/complete_stage_no_encounter_advances_and_pays_nothing", func(): return _t_complete_stage_no_encounter())
	runner.register_test("venture_char/complete_stage_no_encounter_records_loss_flavour", func(): return _t_complete_stage_no_encounter_loss_flavour())
	runner.register_test("venture_char/complete_stage_flushes_at_most_once", func(): return _t_complete_stage_flush_count())
	runner.register_test("venture_char/complete_stage_realm_complete_crystallizes_threads", func(): return _t_complete_stage_realm_complete())
	runner.register_test("venture_char/complete_stage_sanctum_override_applies_victory_modifiers", func(): return _t_complete_stage_sanctum_override())
	# B — encounter.retreat
	runner.register_test("venture_char/retreat_success_spends_ase_and_awards_intel", func(): return _t_retreat_success())
	runner.register_test("venture_char/retreat_success_snapshot_is_scout_return", func(): return _t_retreat_snapshot())
	runner.register_test("venture_char/retreat_without_ase_awards_intel_but_spends_nothing", func(): return _t_retreat_no_ase())
	# C — _build_scout_return_snapshot, both call sites
	# D1/D2/D3 inverted by V2-INFRA-003 Phase 5 Slice B — the three defects these pinned are fixed.
	runner.register_test("venture_char/scout_return_meta_carries_t", func(): return _t_scout_return_meta_t())
	runner.register_test("venture_char/scout_return_builder_is_pure_dispatch_consumes_once", func(): return _t_scout_return_pure_dispatch_consumes())
	runner.register_test("venture_char/return_home_call_site_builds_scout_return", func(): return _t_return_home_scout_return())
	runner.register_test("venture_char/scout_return_builder_uses_static_party_reader", func(): return _t_scout_return_static_party_reader())
	# D — stage.confirm_return_home / stage.dismiss_overlay
	runner.register_test("venture_char/confirm_return_home_transitions_to_stage_map", func(): return _t_confirm_return_home())
	runner.register_test("venture_char/dismiss_overlay_rebuilds_stage_explore", func(): return _t_dismiss_overlay())
	# E — contact resolve snapshot shape
	runner.register_test("venture_char/contact_resolve_shape_back_to_stage", func(): return _t_contact_resolve_to_stage())
	runner.register_test("venture_char/contact_resolve_shape_back_to_sanctum", func(): return _t_contact_resolve_to_sanctum())


# ---------------------------------------------------------------------------
# Shared harness
# ---------------------------------------------------------------------------

static func _fresh_save_path(tag: String) -> String:
	# Shared harness: the local loop missed ".pending_a"/".pending_b", which SaveService also
	# writes, so boot() could still recover a previous run. See tests/TestSaveHarness.gd.
	return TestSaveHarness.fresh_save_path("venture_char_%s.json" % tag, "venture_char")


## DEBUG level so the "save.flush" events FlowRuntime emits from its real SaveService call site
## are visible — the same flush-counting technique tests/FlowTransactionTests.gd uses.
static func _make_logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	logger.set_level(StructuredLogger.LEVEL_DEBUG)
	return logger


## Fresh runtime → starter Echo granted through the real onboarding dispatch → keeper intro
## forced complete → landed on flow.sanctum. Mirrors
## tests/FlowSnapshotFingerprintTests.gd::_setup_sanctum_env (deliberately duplicated rather
## than cross-called: that suite pins its logger to "off", and this one needs DEBUG to count
## save flushes).
static func _setup_sanctum_env(tag: String) -> Dictionary:
	var save_path := _fresh_save_path(tag)
	var logger := _make_logger()
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, save_path)
	runtime.boot()

	var cfg: Dictionary = runtime.config_service.get_balance()
	var options: Array = OnboardingService.build_fragment_options(runtime.flow_ctx.save_data, cfg)
	if options.is_empty():
		return { "ok": false, "error": "Could not create deterministic starter fragment options" }
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(options[0].get("virtue", "")))
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })

	var onboarding_v: Variant = runtime.get_save_data().get("onboarding", {})
	if onboarding_v is Dictionary:
		var ob: Dictionary = onboarding_v as Dictionary
		ob["keeper_intro_complete"] = true
		ob["keeper_intro_step"]     = "complete"

	runtime.dispatch({ "type": "flow.go_state", "to": "flow.sanctum" })
	return { "ok": true, "runtime": runtime, "logger": logger }


## Extends the Sanctum env: stages the starter Echo, then drives the SAME production chain a
## player uses — flow.select_realm → flow.select_stage — so realm.01/stage.0 are real generated
## data, never hand-injected. Leaves the flow machine on flow.stage.
static func _setup_stage_env(tag: String) -> Dictionary:
	var env := _setup_sanctum_env(tag)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var echo_id := _first_roster_id(runtime)
	if echo_id.is_empty():
		return { "ok": false, "error": "Roster empty after onboarding — cannot stage a party" }

	runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })
	runtime.dispatch({ "type": "flow.select_realm", "realm_id": "realm.01" })
	runtime.dispatch({ "type": "flow.select_stage", "stage_id": "stage.0" })

	env["echo_id"] = echo_id
	return env


## _setup_stage_env + the real go_state into exploration.
static func _setup_explore_env(tag: String) -> Dictionary:
	var env := _setup_stage_env(tag)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.stage_explore" })
	return env


static func _first_roster_id(runtime: FlowRuntime) -> String:
	var sanctum: Dictionary = _sanctum(runtime.get_save_data())
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty() or not (roster[0] is Dictionary):
		return ""
	return str((roster[0] as Dictionary).get("id", ""))


static func _sanctum(save_data: Dictionary) -> Dictionary:
	var v: Variant = save_data.get("sanctum", {})
	return v if v is Dictionary else {}


static func _economy(save_data: Dictionary) -> Dictionary:
	var v: Variant = save_data.get("economy", {})
	return v if v is Dictionary else {}


static func _realm(save_data: Dictionary, realm_id: String) -> Dictionary:
	var realms_v: Variant = save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	var r_v: Variant = realms.get(realm_id, {})
	return r_v if r_v is Dictionary else {}


static func _roster_echo(save_data: Dictionary, echo_id: String) -> Dictionary:
	var roster_v: Variant = _sanctum(save_data).get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for e_v in roster:
		if e_v is Dictionary and str((e_v as Dictionary).get("id", "")) == echo_id:
			return e_v
	return {}


static func _emotion_of(save_data: Dictionary, echo_id: String) -> Dictionary:
	var e := _roster_echo(save_data, echo_id)
	var emo_v: Variant = e.get("emotion", {})
	return emo_v if emo_v is Dictionary else {}


static func _sorted_action_keys(snap: Dictionary) -> Array:
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var keys: Array = actions.keys()
	keys.sort()
	return keys


static func _flush_count(logger: StructuredLogger) -> int:
	var n := 0
	for event_v in logger.get_logs():
		if str((event_v as Dictionary).get("type", "")) == "save.flush":
			n += 1
	return n


static func _rewards_cfg(runtime: FlowRuntime) -> Dictionary:
	var bal: Dictionary = runtime.config_service.get_balance()
	var data_v: Variant = bal.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var r_v: Variant = data.get("rewards", {})
	return r_v if r_v is Dictionary else {}


# ---------------------------------------------------------------------------
# A — "flow.complete_stage" (FlowRuntime._handle_complete_stage, :742)
# ---------------------------------------------------------------------------

## The "complete a stage without a fight" branch: encounter_ctx is null, so the handler never
## reads a combat result. Pins the whole observable footprint of one dispatch:
## snapshot type + action slots, Ase/Ekwan, Storyweight, the realm's stage index (advanced by
## exactly one), and thread crystallization (none — the realm is not complete).
##
## ASSERTION INVERTED, V2-INFRA-003 Phase 8 (defect D05 + D36). This test used to assert that a
## no-encounter stage completion pays NOTHING — Ase, Ekwan and Storyweight all untouched —
## because the only payer was FlowEncounterState.build_final_snapshot(), which a stage finished
## without a fight never reaches. That was the defect, recorded here as observed behaviour:
## "Player completes content, receives no reward."
##
## The stage settlement now runs in this dispatch (StageSettlementService.settle(), called from
## VentureController.handle_complete_stage ahead of RealmService.advance_stage), and it does not
## care whether an encounter happened. So the three "untouched" assertions become "paid": the
## stage's base objective weights + the realm-virtue bonus in Ase, the Ekwan share of that, and
## xp_stage_clear_base of Storyweight per party echo. The exact figures are not hard-coded — the
## test asserts each moved in the right direction, which is what the defect was about.
static func _t_complete_stage_no_encounter() -> Dictionary:
	var env := _setup_stage_env("cs_no_enc")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var echo_id: String = env["echo_id"]
	var save_data: Dictionary = runtime.get_save_data()

	# Force a multi-stage realm so this dispatch cannot complete the realm.
	var realm := _realm(save_data, "realm.01")
	if int(realm.get("stage_count", 0)) < 2:
		realm["stage_count"] = 2
	realm["current_stage_index"] = 0

	var ase_before := int(_economy(save_data).get("ase", -1))
	var ekwan_before := int(_economy(save_data).get("ekwan", -1))
	var echo_before := _roster_echo(save_data, echo_id)
	var story_before := int(echo_before.get("storyweight", echo_before.get("xp_total", 0)))
	var xp_before := int(echo_before.get("xp_total", 0))
	var index_before := int(realm.get("current_stage_index", -1))
	var segments_before := (realm.get("realm_recovery_segments", []) as Array).size()

	var mismatches: Array = []
	if runtime.flow_ctx.encounter_ctx != null:
		mismatches.append("test setup failed: expected no encounter_ctx on the no-fight branch")

	var out: Dictionary = runtime.dispatch({ "type": "flow.complete_stage" })

	var realm_after := _realm(save_data, "realm.01")
	var echo_after := _roster_echo(save_data, echo_id)

	if str(out.get("type", "")) != FlowStateIds.STAGE_MAP:
		mismatches.append("expected the dispatch to publish %s, got %s" % [FlowStateIds.STAGE_MAP, str(out.get("type", ""))])
	var keys := _sorted_action_keys(out)
	# FlowStageMapState.build_snapshot() emits exactly two slots: "nav.back" unconditionally and
	# "cta.enter_stage" only while the realm is incomplete (core/state/flow/states/venture/
	# FlowStageMapState.gd:97-113). There is no "nav.skills" slot anywhere in core/ or ui/ —
	# `git log -S"nav.skills"` finds no commit that ever added one. The earlier expectation was
	# invented, not observed; corrected here rather than reported as a missing action.
	var expected_keys := ["cta.enter_stage", "nav.back"]
	if keys != expected_keys:
		mismatches.append("flow.stage_map action slots changed: expected %s, got %s" % [str(expected_keys), str(keys)])
	if int(_economy(save_data).get("ase", -1)) <= ase_before:
		mismatches.append("expected the stage settlement to PAY Ase on a no-encounter complete_stage: %d -> %d" % [ase_before, int(_economy(save_data).get("ase", -1))])
	if int(_economy(save_data).get("ekwan", -1)) <= ekwan_before:
		mismatches.append("expected the stage settlement to PAY Ekwan on a no-encounter complete_stage: %d -> %d" % [ekwan_before, int(_economy(save_data).get("ekwan", -1))])
	if int(echo_after.get("storyweight", echo_after.get("xp_total", 0))) <= story_before:
		mismatches.append("expected the stage settlement to award Storyweight (xp_stage_clear_base): %d -> %d" \
			% [story_before, int(echo_after.get("storyweight", echo_after.get("xp_total", 0)))])
	if int(echo_after.get("xp_total", 0)) <= xp_before:
		mismatches.append("expected xp_total to rise with the stage-clear award: %d -> %d" % [xp_before, int(echo_after.get("xp_total", 0))])
	if int(realm_after.get("current_stage_index", -1)) != index_before + 1:
		mismatches.append("expected current_stage_index %d -> %d, got %d" \
			% [index_before, index_before + 1, int(realm_after.get("current_stage_index", -1))])
	if bool(realm_after.get("is_completed", true)):
		mismatches.append("expected the realm NOT completed with stage_count=2 and index 0 -> 1")
	# No Thread crystallizes unless the realm completes.
	var threads_v: Variant = _sanctum(save_data).get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	if not threads.is_empty():
		mismatches.append("expected 0 Threads crystallized on a non-completing stage, got %d" % threads.size())
	if runtime.flow_ctx.last_realm_threads_earned.size() != 0:
		mismatches.append("expected last_realm_threads_earned empty, got %d" % runtime.flow_ctx.last_realm_threads_earned.size())
	# One recovery segment is contributed per completed stage, graded from last_snapshot.data.rank.
	var segments_v: Variant = realm_after.get("realm_recovery_segments", [])
	var segments: Array = segments_v if segments_v is Array else []
	if segments.size() != segments_before + 1:
		mismatches.append("expected exactly one recovery segment appended, got %d -> %d" % [segments_before, segments.size()])
	elif segments[segments.size() - 1] is Dictionary:
		var seg: Dictionary = segments[segments.size() - 1]
		if int(seg.get("stage_index", -1)) != index_before:
			mismatches.append("expected the segment tagged with the stage just completed (%d), got %d" % [index_before, int(seg.get("stage_index", -1))])

	# IDEMPOTENCY (V2-INFRA-003 Phase 8, defects D36/D77). Runs LAST because it dispatches a
	# SECOND time and would otherwise disturb every single-dispatch count asserted above.
	# The first dispatch stamped this stage's settlement_receipt; a second flow.complete_stage
	# aimed back at the SAME stage must pay no Ase and award no Storyweight. Without that stamp
	# the quit-at-Resolve loop D36 describes pays on every pass.
	var ase_once := int(_economy(save_data).get("ase", -1))
	var xp_once := int(_roster_echo(save_data, echo_id).get("xp_total", 0))
	runtime.flow_ctx.stage_id = "stage.0"
	_realm(save_data, "realm.01")["current_stage_index"] = 0
	runtime.dispatch({ "type": "flow.complete_stage" })
	if int(_economy(save_data).get("ase", -1)) != ase_once:
		mismatches.append("settlement is not idempotent: a second complete_stage paid again, Ase %d -> %d" % [ase_once, int(_economy(save_data).get("ase", -1))])
	if int(_roster_echo(save_data, echo_id).get("xp_total", 0)) != xp_once:
		mismatches.append("settlement is not idempotent: a second complete_stage awarded Storyweight again, %d -> %d" % [xp_once, int(_roster_echo(save_data, echo_id).get("xp_total", 0))])

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## ASSERTION INVERTED, V2-INFRA-003 Phase 8 (defect D05). The old body is preserved in shape
## and drives the same production dispatch; only what it expects has flipped.
##
## WAS: outcome was seeded to "loss" and upgraded only when encounter_ctx was non-null, so a
## stage completed WITHOUT a fight took the full defeat emotion drift — morale down by
## combat_exit_loss_morale, fear up by combat_exit_loss_fear, loss_streak incremented, fear_base
## pushed up. Nothing about the no-fight path is a defeat, and this test said so while pinning
## the wrong behaviour in place.
##
## NOW: the four encounter-consequence hooks (emotion drift + the three bond hooks) are skipped
## outright when there was no encounter — they take a combat outcome as their subject and there
## is none. So morale, fear and both streaks must be UNCHANGED. Note this is deliberately not a
## win either: the party is not paid a victory it did not fight, it is only not punished for a
## defeat that never happened.
static func _t_complete_stage_no_encounter_loss_flavour() -> Dictionary:
	var env := _setup_stage_env("cs_loss_flavour")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var echo_id: String = env["echo_id"]
	var save_data: Dictionary = runtime.get_save_data()

	var realm := _realm(save_data, "realm.01")
	if int(realm.get("stage_count", 0)) < 2:
		realm["stage_count"] = 2
	realm["current_stage_index"] = 0

	var emo_before := _emotion_of(save_data, echo_id).duplicate(true)
	var morale_before := int(emo_before.get("morale_current", 50))
	var fear_before := int(emo_before.get("fear_current", 0))
	var loss_streak_before := int(emo_before.get("loss_streak", 0))

	runtime.dispatch({ "type": "flow.complete_stage" })

	var emo_after := _emotion_of(save_data, echo_id)
	var morale_after := int(emo_after.get("morale_current", 50))
	var fear_after := int(emo_after.get("fear_current", 0))
	var loss_streak_after := int(emo_after.get("loss_streak", 0))

	var mismatches: Array = []
	if morale_after != morale_before:
		mismatches.append("expected morale_current UNCHANGED with no encounter (%d -> %d)" % [morale_before, morale_after])
	if fear_after != fear_before:
		mismatches.append("expected fear_current UNCHANGED with no encounter (%d -> %d)" % [fear_before, fear_after])
	if loss_streak_after != loss_streak_before:
		mismatches.append("expected loss_streak UNCHANGED with no encounter (%d -> %d)" % [loss_streak_before, loss_streak_after])
	if int(emo_after.get("win_streak", 0)) != int(emo_before.get("win_streak", 0)):
		mismatches.append("expected win_streak UNCHANGED with no encounter (%d -> %d)" \
			% [int(emo_before.get("win_streak", 0)), int(emo_after.get("win_streak", 0))])

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## One dispatch → at most one real save flush, even though _handle_complete_stage requests a
## save from several places (stage.combat_resolved, realm.stage_advance, thread.crystallize,
## encounter.emotion_drift…). Same invariant tests/FlowTransactionTests.gd proves generically,
## asserted here for the specific handler that is about to move.
static func _t_complete_stage_flush_count() -> Dictionary:
	var env := _setup_stage_env("cs_flush")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]
	var save_data: Dictionary = runtime.get_save_data()

	var realm := _realm(save_data, "realm.01")
	if int(realm.get("stage_count", 0)) < 2:
		realm["stage_count"] = 2
	realm["current_stage_index"] = 0

	logger.clear()
	runtime.dispatch({ "type": "flow.complete_stage" })
	var flushes := _flush_count(logger)

	if flushes != 1:
		return { "ok": false, "error": "expected exactly 1 save flush for one flow.complete_stage dispatch, got %d" % flushes }
	if runtime.flow_ctx.save_request:
		return { "ok": false, "error": "save_request left true after the flush" }
	return { "ok": true }


## The realm-completing branch: index advances past the last stage, so the realm is marked
## complete, Threads crystallize (ThreadService guarantees a floor of one per completed realm),
## and realm/stage context is cleared before routing to flow.realm_select.
static func _t_complete_stage_realm_complete() -> Dictionary:
	var env := _setup_stage_env("cs_realm_complete")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]
	var save_data: Dictionary = runtime.get_save_data()

	var realm := _realm(save_data, "realm.01")
	var stage_count := int(realm.get("stage_count", 1))
	realm["current_stage_index"] = stage_count - 1

	var threads_before_v: Variant = _sanctum(save_data).get("threads", {})
	var threads_before: int = (threads_before_v as Dictionary).size() if threads_before_v is Dictionary else 0

	logger.clear()
	var out: Dictionary = runtime.dispatch({ "type": "flow.complete_stage" })
	var flushes := _flush_count(logger)

	var realm_after := _realm(save_data, "realm.01")
	var threads_after_v: Variant = _sanctum(save_data).get("threads", {})
	var threads_after: Dictionary = threads_after_v if threads_after_v is Dictionary else {}

	var mismatches: Array = []
	if str(out.get("type", "")) != FlowStateIds.REALM_SELECT:
		mismatches.append("expected realm completion to publish %s, got %s" % [FlowStateIds.REALM_SELECT, str(out.get("type", ""))])
	if int(realm_after.get("current_stage_index", -1)) != stage_count:
		mismatches.append("expected current_stage_index == stage_count (%d), got %d" % [stage_count, int(realm_after.get("current_stage_index", -1))])
	if not bool(realm_after.get("is_completed", false)):
		mismatches.append("expected the realm marked is_completed")
	# RE-RECORDED 1 -> 2, V2-INFRA-003 Phase 8 (defect D05). This env has NO encounter, so the
	# recovery segment this dispatch contributes used to be graded "F" — the absent-`rank`
	# default — which data.threads.segment_quality_by_grade maps to "broken", scoring ~0 and
	# leaving ThreadService's max(1, ...) floor as the only reason a Thread appeared at all.
	# The segment is now graded VentureController.NO_COMBAT_GRADE ("C" -> "compromised"), so
	# _derive_quality clears the next count threshold and 2 Threads crystallize. The floor is no
	# longer what is being observed, which is the point: a stage the party COMPLETED now
	# contributes to Thread recovery instead of a broken segment.
	if threads_after.size() - threads_before != 2:
		mismatches.append("expected exactly 2 Threads crystallized from a compromised segment, got %d new" % (threads_after.size() - threads_before))
	if runtime.flow_ctx.last_realm_threads_earned.size() != 2:
		mismatches.append("expected last_realm_threads_earned to carry the 2 crystallized Threads, got %d" \
			% runtime.flow_ctx.last_realm_threads_earned.size())
	if not runtime.flow_ctx.realm_id.is_empty():
		mismatches.append("expected flow_ctx.realm_id cleared on realm completion, got '%s'" % runtime.flow_ctx.realm_id)
	if not runtime.flow_ctx.stage_id.is_empty():
		mismatches.append("expected flow_ctx.stage_id cleared on realm completion, got '%s'" % runtime.flow_ctx.stage_id)
	if flushes != 1:
		mismatches.append("expected exactly 1 save flush for the realm-completing dispatch, got %d" % flushes)

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## CHARACTERIZATION — current behaviour, not necessarily correct.
## FlowRuntime.gd:855–:857 — when the caller passes destination="flow.sanctum", the handler
## applies apply_run_emotion_modifiers("victory") and checks the vow release condition. The
## literal "victory" is used even here, where encounter_ctx is null and the very same handler
## has already classified this stage as a "loss" three lines earlier (:744). One dispatch
## therefore pays BOTH the defeat drift and the victory run modifiers.
static func _t_complete_stage_sanctum_override() -> Dictionary:
	var env := _setup_stage_env("cs_sanctum_override")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var save_data: Dictionary = runtime.get_save_data()

	var realm := _realm(save_data, "realm.01")
	if int(realm.get("stage_count", 0)) < 2:
		realm["stage_count"] = 2
	realm["current_stage_index"] = 0

	var out: Dictionary = runtime.dispatch({
		"type": "flow.complete_stage",
		"destination": FlowStateIds.SANCTUM,
	})

	var mismatches: Array = []
	if str(out.get("type", "")) != FlowStateIds.SANCTUM:
		mismatches.append("expected the destination override to publish %s, got %s" % [FlowStateIds.SANCTUM, str(out.get("type", ""))])
	if int(_realm(save_data, "realm.01").get("current_stage_index", -1)) != 1:
		mismatches.append("expected the override to still advance the stage index to 1, got %d" \
			% int(_realm(save_data, "realm.01").get("current_stage_index", -1)))

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# B — "encounter.retreat" (FlowRuntime._handle_encounter_retreat, :1076)
# ---------------------------------------------------------------------------
#
# tests/RetreatTests.gd covers only RetreatService.roll_retreat()/compute_*, never the
# handler. success_pct=100 makes the seeded roll deterministic (roll_retreat compares
# randi_range(0, 99) < success_pct), so these tests exercise the success branch without
# depending on the campaign seed.

## Encounter env with a controllable intel count. Built like
## tests/FlowFingerprintTests.gd::_setup_encounter (realm via RealmService.get_or_create, a
## real generated party, FlowEncounterState.enter() to mint the encounter context), but with a
## DEBUG logger and a directly-set balance, and with `revealed_count` situations flipped to
## revealed so the intel-gated partial award is a known quantity.
static func _setup_retreat_env(tag: String, starting_ase: int, revealed_count: int) -> Dictionary:
	var save_path := _fresh_save_path(tag)
	var logger := _make_logger()
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, save_path)
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, 0)
	if rm.is_empty():
		return { "ok": false, "error": "could not create realm.01" }
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.%s" % tag

	# Balances set DIRECTLY on the save dict (tests/AGENTS.md) — never via economy.ase.add.
	flow_ctx.save_data["economy"]["ase"]   = starting_ase
	flow_ctx.save_data["economy"]["ekwan"] = 0

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		roster.append(echo)
		party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	# Control the intel count read by FlowRuntime._count_revealed_situations().
	var stage_v: Variant = (rm.get("stages", []) as Array)[0] if (rm.get("stages", []) as Array).size() > 0 else null
	var actually_revealed := 0
	if stage_v is Dictionary:
		var stage: Dictionary = stage_v
		var emap_v: Variant = stage.get("explore_map", {})
		var emap: Dictionary = emap_v if emap_v is Dictionary else {}
		var sits_v: Variant = emap.get("situations", [])
		var sits: Array = sits_v if sits_v is Array else []
		for i in range(sits.size()):
			if not (sits[i] is Dictionary):
				continue
			var s: Dictionary = sits[i]
			s["revealed"] = actually_revealed < revealed_count
			if actually_revealed < revealed_count:
				actually_revealed += 1

	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	FlowEncounterState.new().enter(flow_ctx, 0)
	if flow_ctx.encounter_ctx == null:
		return { "ok": false, "error": "encounter setup failed" }

	return {
		"ok": true,
		"runtime": runtime,
		"logger": logger,
		"intel_count": actually_revealed,
	}


## Expected intel-partial award, computed the same way the handler does (:1116–:1117):
## roundi(stage_base_reward * rewards.partial_intel_reward_factor).
static func _expected_intel_partial(runtime: FlowRuntime, intel_count: int) -> int:
	if intel_count <= 0:
		return 0
	var rewards := _rewards_cfg(runtime)
	var factor := float(rewards.get("partial_intel_reward_factor", 0.12))
	var weights_v: Variant = rewards.get("objective_weights", {})
	var weights: Dictionary = weights_v if weights_v is Dictionary else {}
	var realm := _realm(runtime.get_save_data(), "realm.01")
	var stages_v: Variant = realm.get("stages", [])
	var stages: Array = stages_v if stages_v is Array else []
	# V2-INFRA-003 Phase 8 (defect D39): the stage base is the SUM of the stage's objective
	# weights, read under the key ObjectiveModel actually writes ("type", never "obj_type").
	# This helper used to mirror get_stage_base_reward()'s two faults — first objective only,
	# wrong key — and so expected the flat "combat" default (30) for every stage. It is
	# recomputed here from the same rule the production single definition
	# (RewardCalc.base_reward) uses, but independently, so this stays a characterization
	# expectation rather than a restatement of the code under test.
	var base := 0
	if stages.size() > 0 and stages[0] is Dictionary:
		var objs_v: Variant = (stages[0] as Dictionary).get("objectives", [])
		var objs: Array = objs_v if objs_v is Array else []
		for obj_v in objs:
			if obj_v is Dictionary:
				base += int(weights.get(str((obj_v as Dictionary).get("type", "")), 0))
	return roundi(float(base) * factor)


static func _t_retreat_success() -> Dictionary:
	var env := _setup_retreat_env("retreat_success", 500, 3)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]
	var intel_count: int = env["intel_count"]
	var save_data: Dictionary = runtime.get_save_data()

	var ase_before := int(_economy(save_data).get("ase", -1))
	var expected_award := _expected_intel_partial(runtime, intel_count)
	var ase_cost := 40

	logger.clear()
	runtime.dispatch({
		"type":        "encounter.retreat",
		"ase_cost":    ase_cost,
		"success_pct": 100,
	})
	var flushes := _flush_count(logger)

	var ase_after := int(_economy(save_data).get("ase", -1))

	var mismatches: Array = []
	if intel_count <= 0:
		mismatches.append("test setup failed: expected at least one revealed situation, got %d" % intel_count)
	if expected_award <= 0:
		mismatches.append("test setup failed: expected a positive intel partial award, got %d" % expected_award)
	if ase_after != ase_before - ase_cost + expected_award:
		mismatches.append("expected Ase %d - %d(cost) + %d(intel partial) = %d, got %d" \
			% [ase_before, ase_cost, expected_award, ase_before - ase_cost + expected_award, ase_after])
	if runtime.flow_ctx.encounter_ctx != null:
		mismatches.append("expected encounter_ctx nulled on a successful retreat")
	if runtime.flow_ctx.encounter_machine != null:
		mismatches.append("expected encounter_machine nulled on a successful retreat")
	if flushes != 1:
		mismatches.append("expected exactly 1 save flush for one encounter.retreat dispatch, got %d" % flushes)

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## The published snapshot for a successful retreat is the scout-return resolve card, whose
## whole `data` payload and single CTA slot are pinned explicitly here (no hash — a future
## failure should name the field that changed).
static func _t_retreat_snapshot() -> Dictionary:
	var env := _setup_retreat_env("retreat_snapshot", 500, 2)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var intel_count: int = env["intel_count"]
	var expected_award := _expected_intel_partial(runtime, intel_count)

	var out: Dictionary = runtime.dispatch({
		"type":        "encounter.retreat",
		"ase_cost":    0,
		"success_pct": 100,
	})

	var data_v: Variant = out.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actions_v: Variant = out.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var cta_v: Variant = actions.get("cta.continue", {})
	var cta: Dictionary = cta_v if cta_v is Dictionary else {}

	var mismatches: Array = []
	if str(out.get("type", "")) != FlowStateIds.RESOLVE:
		mismatches.append("expected type %s, got %s" % [FlowStateIds.RESOLVE, str(out.get("type", ""))])
	var data_keys: Array = data.keys()
	data_keys.sort()
	var expected_data_keys := [
		"actors", "ase_awarded", "ekwan_awarded", "intel_count", "rank",
		"reward_breakdown", "run_type", "summary_line", "surface", "verdict", "victory",
	]
	if data_keys != expected_data_keys:
		mismatches.append("scout_return data keys changed: expected %s, got %s" % [str(expected_data_keys), str(data_keys)])
	if str(data.get("run_type", "")) != "scout_return":
		mismatches.append("expected run_type 'scout_return', got '%s'" % str(data.get("run_type", "")))
	if str(data.get("surface", "")) != "scout_return":
		mismatches.append("expected surface 'scout_return', got '%s'" % str(data.get("surface", "")))
	if str(data.get("verdict", "x")) != "":
		mismatches.append("expected an empty verdict on the scout-return card, got '%s'" % str(data.get("verdict", "")))
	if str(data.get("rank", "x")) != "":
		mismatches.append("expected an empty rank on the scout-return card, got '%s'" % str(data.get("rank", "")))
	if bool(data.get("victory", true)):
		mismatches.append("expected victory=false on the scout-return card")
	if int(data.get("ase_awarded", -1)) != expected_award:
		mismatches.append("expected ase_awarded=%d, got %d" % [expected_award, int(data.get("ase_awarded", -1))])
	if int(data.get("ekwan_awarded", -1)) != 0:
		mismatches.append("expected ekwan_awarded=0, got %d" % int(data.get("ekwan_awarded", -1)))
	if int(data.get("intel_count", -1)) != intel_count:
		mismatches.append("expected intel_count=%d, got %d" % [intel_count, int(data.get("intel_count", -1))])
	var plural := "s" if intel_count != 1 else ""
	var expected_line := "%d crossing%s mapped." % [intel_count, plural]
	if str(data.get("summary_line", "")) != expected_line:
		mismatches.append("expected summary_line '%s', got '%s'" % [expected_line, str(data.get("summary_line", ""))])
	var breakdown_v: Variant = data.get("reward_breakdown", [])
	var breakdown: Array = breakdown_v if breakdown_v is Array else []
	if expected_award > 0:
		if breakdown.size() != 1:
			mismatches.append("expected one reward_breakdown row for a positive award, got %d" % breakdown.size())
		elif breakdown[0] is Dictionary:
			var row: Dictionary = breakdown[0]
			if str(row.get("label", "")) != "Scout return" or str(row.get("currency", "")) != "ase" or int(row.get("delta", -1)) != expected_award:
				mismatches.append("reward_breakdown row changed: %s" % JSON.stringify(row))
	var actors_v: Variant = data.get("actors", [])
	var actors: Array = actors_v if actors_v is Array else []
	if actors.size() != 5:
		mismatches.append("expected the 5-echo party projected into data.actors, got %d" % actors.size())
	elif actors[0] is Dictionary:
		var a_keys: Array = (actors[0] as Dictionary).keys()
		a_keys.sort()
		var expected_a_keys := ["calling_origin", "emotional_status", "id", "name"]
		if a_keys != expected_a_keys:
			mismatches.append("scout_return actor projection keys changed: expected %s, got %s" % [str(expected_a_keys), str(a_keys)])
	var keys := _sorted_action_keys(out)
	if keys != ["cta.continue"]:
		mismatches.append("expected exactly one action slot cta.continue, got %s" % str(keys))
	if str(cta.get("type", "")) != "flow.go_state":
		mismatches.append("expected cta.continue.type 'flow.go_state', got '%s'" % str(cta.get("type", "")))
	if str(cta.get("to", "")) != FlowStateIds.SANCTUM:
		mismatches.append("expected cta.continue.to %s, got '%s'" % [FlowStateIds.SANCTUM, str(cta.get("to", ""))])
	if str(cta.get("label", "")) != "Return to Sanctum":
		mismatches.append("expected cta.continue.label 'Return to Sanctum', got '%s'" % str(cta.get("label", "")))
	if str(cta.get("slot", "")) != "cta.continue":
		mismatches.append("expected cta.continue.slot 'cta.continue', got '%s'" % str(cta.get("slot", "")))

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## The affordability guard at :1086–:1092: when the player cannot pay the retreat cost the
## spend is skipped entirely — but the retreat still succeeds and the intel partial is still
## awarded. Pinned so the "free retreat when broke" behaviour cannot move silently.
static func _t_retreat_no_ase() -> Dictionary:
	var env := _setup_retreat_env("retreat_no_ase", 0, 2)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var intel_count: int = env["intel_count"]
	var save_data: Dictionary = runtime.get_save_data()
	var expected_award := _expected_intel_partial(runtime, intel_count)

	var out: Dictionary = runtime.dispatch({
		"type":        "encounter.retreat",
		"ase_cost":    999999,
		"success_pct": 100,
	})

	var mismatches: Array = []
	if int(_economy(save_data).get("ase", -1)) != expected_award:
		mismatches.append("expected an unaffordable cost to be skipped, leaving 0 + %d(intel) = %d Ase, got %d" \
			% [expected_award, expected_award, int(_economy(save_data).get("ase", -1))])
	if str(out.get("type", "")) != FlowStateIds.RESOLVE:
		mismatches.append("expected the retreat to succeed anyway and publish %s, got %s" % [FlowStateIds.RESOLVE, str(out.get("type", ""))])

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# C — FlowRuntime._build_scout_return_snapshot() (:4326), both call sites
# ---------------------------------------------------------------------------

## INVERTED by V2-INFRA-003 Phase 5 Slice B (was: scout_return_meta_carries_sim_tick_not_t).
## This builder emitted `"meta": { "sim_tick": t }` while every other snapshot in the game
## emits `{ "t": t }`. FlowStateMachine._validate_snapshot() requires meta["t"] and calls
## assert(false) otherwise, so every successful retreat and return-home tripped an assertion in
## a debug build; tests/SnapshotContractTests.gd separately pins "sim_tick" as a RETIRED key.
## The fix was product-owner approved and applied as its own step. The three assertions that
## pinned the defect are inverted here rather than deleted, so the contract stays guarded.
static func _t_scout_return_meta_t() -> Dictionary:
	var env := _setup_retreat_env("scout_meta", 200, 1)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	# FlowRuntime.dispatch() opens with `var t := _next_tick()`, and _next_tick() returns the
	# PRE-increment value (core/runtime/FlowRuntime.gd:51-54, :183). The tick this dispatch runs
	# on is therefore flow_ctx.sim_tick as read BEFORE the call; reading it afterwards yields
	# that value + 1. The earlier expectation compared against the post-dispatch counter, so it
	# was the test that was off by one — the snapshot tick is not lagging.
	var expected_tick: int = runtime.flow_ctx.sim_tick

	var out: Dictionary = runtime.dispatch({
		"type":        "encounter.retreat",
		"ase_cost":    0,
		"success_pct": 100,
	})
	var meta_v: Variant = out.get("meta", {})
	var meta: Dictionary = meta_v if meta_v is Dictionary else {}

	var mismatches: Array = []
	if not meta.has("t"):
		mismatches.append("expected meta to carry 't' (the universal contract), got keys %s" % str(meta.keys()))
	if meta.has("sim_tick"):
		mismatches.append("expected meta to NOT carry the retired 'sim_tick' key — got keys %s" % str(meta.keys()))
	if int(meta.get("t", -1)) != expected_tick:
		mismatches.append("expected meta.t to equal the dispatch tick %d, got %d" \
			% [expected_tick, int(meta.get("t", -1))])
	if runtime.flow_ctx.sim_tick != expected_tick + 1:
		mismatches.append("expected dispatch to consume exactly one tick: %d -> %d" \
			% [expected_tick, runtime.flow_ctx.sim_tick])

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## INVERTED by V2-INFRA-003 Phase 5 Slice B (was: scout_return_is_self_consuming).
## The builder used to zero flow_ctx.pending_scout_return_ase / pending_scout_return_intel_count
## as part of "building", so it consumed its own input and any second build of the same card
## silently degraded to 0 Ase / 0 crossings. The one-shot consumption moved into the gated
## closure at the end of FlowRuntime.dispatch(), following the pending_awakening_banner
## precedent: consume once, AFTER the snapshot has been published and logged, gated on the
## PUBLISHED snapshot being flow.resolve with run_type == "scout_return".
##
## This probe now proves all three halves of that contract:
##   1. the values still reach the published card (consumption is not premature);
##   2. the builder is PURE — with the one-shots restored, two direct builds in a row are
##      byte-identical and neither clears the source;
##   3. the closure runs exactly once per dispatch and only on a scout-return resolve — a
##      dispatch that publishes any other snapshot type leaves the one-shots untouched, so a
##      combat resolve can never discard an award the player has not been shown.
static func _t_scout_return_pure_dispatch_consumes() -> Dictionary:
	var env := _setup_retreat_env("scout_consume", 200, 3)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var ctx: FlowContext = runtime.flow_ctx
	var intel_count: int = env["intel_count"]

	var first: Dictionary = runtime.dispatch({
		"type":        "encounter.retreat",
		"ase_cost":    0,
		"success_pct": 100,
	})
	var first_data: Dictionary = (first.get("data", {}) as Dictionary).duplicate(true)
	var awarded := int(first_data.get("ase_awarded", -1))

	var mismatches: Array = []

	# 1 — the published card carries the real values, i.e. nothing consumed them too early.
	if int(first_data.get("intel_count", -1)) != intel_count:
		mismatches.append("expected the published card to carry intel_count=%d, got %d" \
			% [intel_count, int(first_data.get("intel_count", -1))])
	# ...and the closure has consumed them by the time dispatch() returns.
	if ctx.pending_scout_return_ase != 0 or ctx.pending_scout_return_intel_count != 0:
		mismatches.append("expected dispatch()'s closure to consume both pending_scout_return_* fields")

	# 2 — restore the one-shots and build twice directly. A pure builder must be byte-identical
	#     and must leave the source fields alone.
	ctx.pending_scout_return_ase         = awarded
	ctx.pending_scout_return_intel_count = intel_count
	# V2-INFRA-003 Phase 5 Slice D: producer C moved off FlowRuntime to
	# VentureResolveSnapshotBuilder.build_scout_return_snapshot() (static, explicit FlowContext) —
	# it has two callers in two domains and reads FlowContext, so ResolveSnapshotBuilder's
	# no-FlowContext purity contract disqualified that file. Repointed here in the same change,
	# with no delegating shim left on FlowRuntime.
	var build1: Dictionary = VentureResolveSnapshotBuilder.build_scout_return_snapshot(ctx, ctx.sim_tick)
	var build2: Dictionary = VentureResolveSnapshotBuilder.build_scout_return_snapshot(ctx, ctx.sim_tick)
	if JSON.stringify(build1, "", true) != JSON.stringify(build2, "", true):
		mismatches.append("expected two direct builds to be byte-identical — the builder is no longer allowed to consume its own input")
	if ctx.pending_scout_return_ase != awarded or ctx.pending_scout_return_intel_count != intel_count:
		mismatches.append("expected the builder to leave both pending_scout_return_* fields untouched (it is pure now)")
	if int((build2.get("data", {}) as Dictionary).get("intel_count", -1)) != intel_count:
		mismatches.append("expected the second direct build to still report intel_count=%d, got %d" \
			% [intel_count, int((build2.get("data", {}) as Dictionary).get("intel_count", -1))])

	# 3 — the closure's gate. This dispatch publishes flow.stage_map, not a scout-return
	#     resolve, so it must NOT touch the one-shots.
	var out_other: Dictionary = runtime.dispatch({ "type": "stage.confirm_return_home" })
	if str(out_other.get("type", "")) == FlowStateIds.RESOLVE:
		mismatches.append("test setup failed: expected stage.confirm_return_home to publish a non-resolve snapshot")
	if ctx.pending_scout_return_ase != awarded or ctx.pending_scout_return_intel_count != intel_count:
		mismatches.append("expected a dispatch that publishes a non-scout snapshot to leave the one-shots intact — the closure's run_type gate is missing or broken")

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## The SECOND call site: _handle_stage_return_home (:4869) on a successful escape roll. Same
## builder, so the same scout-return card shape must come out of a completely different action.
## The escape roll is seeded from (realm seed, stage id, turn_count) — the test derives the
## same RNG stream itself and picks the first turn_count that rolls a success, so no production
## value is nudged and nothing depends on which turn the party happens to be on.
static func _t_return_home_scout_return() -> Dictionary:
	var env := _setup_explore_env("return_home")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = runtime.flow_ctx
	var save_data: Dictionary = runtime.get_save_data()

	var realm := _realm(save_data, "realm.01")
	var realm_seed := int(realm.get("seed", 0))
	var directive: Dictionary = runtime.directive_service.get_active_directive()
	var escape_threshold: int = maxi(0, 40 - int(directive.get("escape_bonus", 0)))

	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return { "ok": false, "error": "test setup failed: no active stage" }
	var emap_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = emap_v if emap_v is Dictionary else {}

	# Find a turn_count whose seeded roll clears the escape threshold.
	var chosen_turn := -1
	for candidate in range(0, 200):
		var probe := CampaignSeed.get_rng_from(realm_seed, "stage.escape.%s.%d" % [flow_ctx.stage_id, candidate])
		if probe.randi_range(0, 100) > escape_threshold:
			chosen_turn = candidate
			break
	if chosen_turn < 0:
		return { "ok": false, "error": "test setup failed: no turn_count in 0..199 produced a successful escape roll" }
	explore_map["turn_count"] = chosen_turn
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)

	var out: Dictionary = runtime.dispatch({ "type": "stage.return_home" })

	var data_v: Variant = out.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var meta_v: Variant = out.get("meta", {})
	var meta: Dictionary = meta_v if meta_v is Dictionary else {}
	var actions_v: Variant = out.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var cta_v: Variant = actions.get("cta.continue", {})
	var cta: Dictionary = cta_v if cta_v is Dictionary else {}

	var mismatches: Array = []
	if str(out.get("type", "")) != FlowStateIds.RESOLVE:
		mismatches.append("expected a successful return_home to publish %s, got %s" % [FlowStateIds.RESOLVE, str(out.get("type", ""))])
	if str(data.get("run_type", "")) != "scout_return":
		mismatches.append("expected run_type 'scout_return' from the return_home call site, got '%s'" % str(data.get("run_type", "")))
	if str(data.get("surface", "")) != "scout_return":
		mismatches.append("expected surface 'scout_return', got '%s'" % str(data.get("surface", "")))
	# INVERTED by V2-INFRA-003 Phase 5 Slice B — the sim_tick/t defect was shared by BOTH call
	# sites, so both now have to prove the corrected contract.
	if not meta.has("t") or meta.has("sim_tick"):
		mismatches.append("expected the return_home call site to emit meta { t: ... } with no retired 'sim_tick', got keys %s" % str(meta.keys()))
	if str(cta.get("to", "")) != FlowStateIds.SANCTUM:
		mismatches.append("expected cta.continue.to %s, got '%s'" % [FlowStateIds.SANCTUM, str(cta.get("to", ""))])
	if str(cta.get("type", "")) != "flow.go_state":
		mismatches.append("expected cta.continue.type 'flow.go_state', got '%s'" % str(cta.get("type", "")))
	# The party state is written back as ESCAPED before the card is built.
	var stage_after := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	var emap_after_v: Variant = stage_after.get("explore_map", {})
	var emap_after: Dictionary = emap_after_v if emap_after_v is Dictionary else {}
	if str(emap_after.get("party_state", "")) != StageExploreModel.STATE_ESCAPED:
		mismatches.append("expected party_state '%s' after a successful escape, got '%s'" \
			% [StageExploreModel.STATE_ESCAPED, str(emap_after.get("party_state", ""))])
	# The one-shots are consumed by the gated closure at the end of dispatch(), not by the
	# builder — but from outside a completed dispatch the observable end state is the same.
	if runtime.flow_ctx.pending_scout_return_ase != 0 or runtime.flow_ctx.pending_scout_return_intel_count != 0:
		mismatches.append("expected both pending_scout_return_* fields consumed by the end of the dispatch")

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## INVERTED by V2-INFRA-003 Phase 5 Slice B (was: scout_return_builder_constructs_writing_service).
## _build_scout_return_snapshot() used to do `SanctumService.new(flow_ctx.save_data)` purely to
## read the party. That constructor runs SanctumState._ensure_sanctum_dict_exists(), which
## WRITES into the dict it was handed (AGENTS.md "Common Mistakes" #18). It now calls the
## static SanctumService.get_party_actors_static() instead.
##
## The constructor-write probe is KEPT, not deleted: it is the standing reason the static
## reader has to exist, and the day it stops being true is the day someone will be tempted to
## put the construction back. The new half proves the replacement is genuinely a pure read.
## Order-equality between the two readers is pinned separately by
## tests/PartyTests.gd sanctum.party/get_party_actors_static_matches_instance.
static func _t_scout_return_static_party_reader() -> Dictionary:
	var mismatches: Array = []

	# STILL TRUE — constructing the service writes. Do not construct one merely to read.
	var bare: Dictionary = {}
	var _svc := SanctumService.new(bare)
	if not bare.has("sanctum"):
		mismatches.append("expected SanctumService.new() to WRITE a 'sanctum' block into the dict it was given")
	else:
		var s_v: Variant = bare.get("sanctum", {})
		var s_dict: Dictionary = s_v if s_v is Dictionary else {}
		if not s_dict.has("roster") or not s_dict.has("active_party_ids"):
			mismatches.append("expected the constructor-written sanctum block to carry roster + active_party_ids, got %s" % str(s_dict.keys()))

	# And a partially-formed block is repaired in place by the same constructor.
	var partial: Dictionary = { "sanctum": { "roster": "not-an-array" } }
	var _svc2 := SanctumService.new(partial)
	var p_v: Variant = partial.get("sanctum", {})
	var p: Dictionary = p_v if p_v is Dictionary else {}
	if not (p.get("roster", null) is Array):
		mismatches.append("expected the constructor to repair a malformed roster in place")

	# NEW — the static reader the scout-return producer uses writes NOTHING, on a bare dict and
	# on a malformed one alike.
	var bare_static: Dictionary = {}
	var out_bare: Array = SanctumService.get_party_actors_static(bare_static)
	if not bare_static.is_empty():
		mismatches.append("expected get_party_actors_static() to leave a bare dict untouched, got keys %s" % str(bare_static.keys()))
	if not out_bare.is_empty():
		mismatches.append("expected get_party_actors_static() to return [] for a bare dict, got %d entries" % out_bare.size())

	var malformed: Dictionary = { "sanctum": { "roster": "not-an-array" } }
	var before := JSON.stringify(malformed, "", true)
	var out_malformed: Array = SanctumService.get_party_actors_static(malformed)
	if JSON.stringify(malformed, "", true) != before:
		mismatches.append("expected get_party_actors_static() to leave a malformed sanctum block untouched (no repair write)")
	if not out_malformed.is_empty():
		mismatches.append("expected get_party_actors_static() to return [] for a malformed roster, got %d entries" % out_malformed.size())

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# D — "stage.confirm_return_home" (:562) and "stage.dismiss_overlay" (:565)
# ---------------------------------------------------------------------------

## The whole handler is one transition line: RESOLVE/EXPLORE → flow.stage_map. No save is
## requested, so this dispatch must flush nothing.
static func _t_confirm_return_home() -> Dictionary:
	var env := _setup_explore_env("confirm_return")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]

	logger.clear()
	var out: Dictionary = runtime.dispatch({ "type": "stage.confirm_return_home" })
	var flushes := _flush_count(logger)

	var mismatches: Array = []
	if str(out.get("type", "")) != FlowStateIds.STAGE_MAP:
		mismatches.append("expected %s, got %s" % [FlowStateIds.STAGE_MAP, str(out.get("type", ""))])
	var keys := _sorted_action_keys(out)
	# FlowStageMapState.build_snapshot() emits exactly two slots: "nav.back" unconditionally and
	# "cta.enter_stage" only while the realm is incomplete (core/state/flow/states/venture/
	# FlowStageMapState.gd:97-113). There is no "nav.skills" slot anywhere in core/ or ui/ —
	# `git log -S"nav.skills"` finds no commit that ever added one. The earlier expectation was
	# invented, not observed; corrected here rather than reported as a missing action.
	var expected_keys := ["cta.enter_stage", "nav.back"]
	if keys != expected_keys:
		mismatches.append("flow.stage_map action slots changed: expected %s, got %s" % [str(expected_keys), str(keys)])
	if flushes != 0:
		mismatches.append("expected 0 save flushes for a pure transition, got %d" % flushes)

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## stage.dismiss_overlay rebuilds the flow.stage_explore snapshot from save_data (rather than
## calling refresh_snapshot() alone, which would just re-validate the stale snapshot — Lesson
## 9), so overlay-only fields injected into the previous snapshot are dropped.
static func _t_dismiss_overlay() -> Dictionary:
	var env := _setup_explore_env("dismiss_overlay")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]

	# Inject the two overlay payloads the real handlers attach to the explore snapshot.
	var stale: Dictionary = runtime.flow_ctx.last_snapshot
	var stale_data_v: Variant = stale.get("data", {})
	var stale_data: Dictionary = stale_data_v if stale_data_v is Dictionary else {}
	stale_data["return_home_result"] = { "success": false, "message": "The way is blocked." }
	stale_data["situation_overlay"] = { "panel_kind": "choice", "choices": [] }
	stale["data"] = stale_data
	runtime.flow_ctx.last_snapshot = stale

	var baseline_keys := _sorted_action_keys(stale)

	logger.clear()
	var out: Dictionary = runtime.dispatch({ "type": "stage.dismiss_overlay" })
	var flushes := _flush_count(logger)

	var data_v: Variant = out.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var mismatches: Array = []
	if str(out.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
		mismatches.append("expected %s, got %s" % [FlowStateIds.STAGE_EXPLORE, str(out.get("type", ""))])
	if data.has("return_home_result"):
		mismatches.append("expected return_home_result stripped by the rebuild")
	if data.has("situation_overlay"):
		mismatches.append("expected situation_overlay stripped by the rebuild")
	if _sorted_action_keys(out) != baseline_keys:
		mismatches.append("expected the rebuilt explore snapshot to keep the same action slots %s, got %s" \
			% [str(baseline_keys), str(_sorted_action_keys(out))])
	if flushes != 0:
		mismatches.append("expected 0 save flushes for a publication-only rebuild, got %d" % flushes)

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# E — ContactController._build_contact_resolve_snapshot() shape guard
# ---------------------------------------------------------------------------
#
# The SITUATION resolve card (_build_situation_resolve_snapshot, :6124) is already covered by
# tests/UnifiedResolveTests.gd — surface/verdict/summary_line/effects/emotion_summary/
# ase_awarded/reward_breakdown and the cta.continue target. Only the CONTACT card was
# unguarded, so only that side is pinned here. Both builders are private instance methods,
# called directly (not through call("…")) so --check-only still sees the call site if they
# move — AGENTS.md extraction rule "tests that reach in by string name break silently".

static func _contact_fixture() -> Dictionary:
	return {
		"id":     "sit.contact.1",
		"role":   "witness",
		"state":  "concluded",
		"outcome": "good",
	}


static func _t_contact_resolve_to_stage() -> Dictionary:
	var env := _setup_explore_env("contact_stage")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var snap: Dictionary = runtime._contact_controller()._build_contact_resolve_snapshot(_contact_fixture(), "good", true, 77)

	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var meta_v: Variant = snap.get("meta", {})
	var meta: Dictionary = meta_v if meta_v is Dictionary else {}
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var cta_v: Variant = actions.get("cta.continue", {})
	var cta: Dictionary = cta_v if cta_v is Dictionary else {}

	var mismatches: Array = []
	if str(snap.get("type", "")) != FlowStateIds.RESOLVE:
		mismatches.append("expected type %s, got %s" % [FlowStateIds.RESOLVE, str(snap.get("type", ""))])
	var data_keys: Array = data.keys()
	data_keys.sort()
	var expected_data_keys := ["outcome", "outcome_text", "role", "role_label", "run_type", "summary_line", "surface", "verdict"]
	if data_keys != expected_data_keys:
		mismatches.append("contact resolve data keys changed: expected %s, got %s" % [str(expected_data_keys), str(data_keys)])
	if str(data.get("run_type", "")) != "contact_result":
		mismatches.append("expected run_type 'contact_result', got '%s'" % str(data.get("run_type", "")))
	if str(data.get("surface", "")) != "npc_contact":
		mismatches.append("expected surface 'npc_contact', got '%s'" % str(data.get("surface", "")))
	if str(data.get("role", "")) != "witness":
		mismatches.append("expected role 'witness', got '%s'" % str(data.get("role", "")))
	if str(data.get("role_label", "")) != "Witness":
		mismatches.append("expected role_label 'Witness' (role.capitalize()), got '%s'" % str(data.get("role_label", "")))
	if str(data.get("outcome", "")) != "good":
		mismatches.append("expected outcome 'good', got '%s'" % str(data.get("outcome", "")))
	if str(data.get("outcome_text", "")).is_empty():
		mismatches.append("expected a non-empty outcome_text")
	if str(data.get("summary_line", "")) != str(data.get("outcome_text", "")):
		mismatches.append("expected summary_line to mirror outcome_text on the contact card")
	# CHARACTERIZATION — current behaviour, not necessarily correct.
	# The contact card DOES carry a "verdict", mapped good/partial/failed → good/partial/missed
	# (core/runtime/FlowRuntime.gd:6088-6105). It is written and never read: the only consumer,
	# ResolveScreen._render_situation_result(), is reached exclusively by run_type
	# "situation_result"; the contact branch _render_contact_result() ignores "verdict" and
	# hard-hides the badge that would display it (ui/screens/venture/ResolveScreen.gd:463-485).
	# Pin the write so the merge cannot silently drop or repurpose the field.
	if str(data.get("verdict", "")) != "good":
		mismatches.append("expected the contact card verdict for outcome 'good' to be 'good', got '%s'" % str(data.get("verdict", "")))
	# meta on the contact card DOES use the canonical "t" (unlike the scout-return card).
	if meta.keys() != ["t"]:
		mismatches.append("expected meta to be exactly { t }, got %s" % str(meta.keys()))
	if int(meta.get("t", -1)) != 77:
		mismatches.append("expected meta.t == 77, got %d" % int(meta.get("t", -1)))
	var keys := _sorted_action_keys(snap)
	if keys != ["cta.continue"]:
		mismatches.append("expected exactly one action slot cta.continue, got %s" % str(keys))
	if str(cta.get("type", "")) != "flow.go_state":
		mismatches.append("expected cta.continue.type 'flow.go_state', got '%s'" % str(cta.get("type", "")))
	if str(cta.get("to", "")) != FlowStateIds.STAGE_EXPLORE:
		mismatches.append("expected cta.continue.to %s for go_back_to_stage=true, got '%s'" % [FlowStateIds.STAGE_EXPLORE, str(cta.get("to", ""))])
	if str(cta.get("label", "")) != "Return to Stage":
		mismatches.append("expected cta.continue.label 'Return to Stage', got '%s'" % str(cta.get("label", "")))
	if str(cta.get("slot", "")) != "cta.continue":
		mismatches.append("expected cta.continue.slot 'cta.continue', got '%s'" % str(cta.get("slot", "")))

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## go_back_to_stage=false is the other branch (:6085–:6086) — the only thing it changes is the
## CTA target and label. Everything else must stay identical.
static func _t_contact_resolve_to_sanctum() -> Dictionary:
	var env := _setup_explore_env("contact_sanctum")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var to_stage: Dictionary = runtime._contact_controller()._build_contact_resolve_snapshot(_contact_fixture(), "failed", true, 5)
	var to_sanctum: Dictionary = runtime._contact_controller()._build_contact_resolve_snapshot(_contact_fixture(), "failed", false, 5)

	var cta_v: Variant = (to_sanctum.get("actions", {}) as Dictionary).get("cta.continue", {})
	var cta: Dictionary = cta_v if cta_v is Dictionary else {}

	var mismatches: Array = []
	if str(cta.get("to", "")) != FlowStateIds.SANCTUM:
		mismatches.append("expected cta.continue.to %s for go_back_to_stage=false, got '%s'" % [FlowStateIds.SANCTUM, str(cta.get("to", ""))])
	if str(cta.get("label", "")) != "Return to Sanctum":
		mismatches.append("expected cta.continue.label 'Return to Sanctum', got '%s'" % str(cta.get("label", "")))
	if JSON.stringify(to_stage.get("data", {}), "", true) != JSON.stringify(to_sanctum.get("data", {}), "", true):
		mismatches.append("expected the go_back_to_stage flag to change the CTA only — the data payload diverged")
	if JSON.stringify(to_stage.get("meta", {}), "", true) != JSON.stringify(to_sanctum.get("meta", {}), "", true):
		mismatches.append("expected identical meta for both branches")

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }
