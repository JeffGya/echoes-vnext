# res://tests/FlowSnapshotFingerprintTests.gd
# V2-INFRA-003 — Phase 3 entry gate + Phase 3 Slice A.
#
# This file originally shipped as the Phase 3 entry gate, ahead of moving snapshot building
# into pure builders. Phase 3 Slice A now performs that move for flow.sanctum
# (SanctumSnapshotBuilder — core/state/flow/states/sanctum/SanctumSnapshotBuilder.gd), so this
# file provides two things:
#
# TASK 1 — a regression guard (deterministic fingerprint) for the two snapshot domains that had
# none: flow.sanctum and flow.stage_explore. Same technique as tests/FlowFingerprintTests.gd:
# hash a canonical JSON projection of the snapshot, hardcode the expected hash, fail loudly with
# expected-vs-actual on drift. Isolated /tmp save path, DirAccess.make_dir_recursive_absolute()
# before use, pinned seed (SaveService.make_new_save literal root_seed on a fresh save — the same
# guarantee FlowFingerprintTests relies on), balances/state built entirely through the real
# production dispatch chain (never hand-poked to fake a scenario the game cannot reach on its
# own for these two domains).
#
# Stability proof: run the suite twice against a cold /tmp (see BUILD report) — a wrong or
# drifted hash fails loudly, so two green runs prove these two fingerprints are stable.
#
# TASK 2 — snapshot purity probes. Several code paths mutate state WHILE building a snapshot.
# Two of the six original probes (the flow.sanctum one-shot flags, and the generic double-build
# probe that rode on them) have been fixed by Slice A and inverted accordingly — no longer
# tagged KNOWN DEFECT. A third probe was added: proof that FlowRuntime.dispatch() clears the
# two flags exactly once, after publishing, so "shown exactly once" still holds end to end now
# that the builder itself never clears them.
#
# Slice B2 resolved two more of the four remaining sites:
#   - EncounterSnapshotBuilder._project_actor() no longer writes actor["_bark_line"] = "" back onto
#     the actor dict it projects — that consume moved to its two callers (build_round_snapshot()
#     and build_final_snapshot(), both in the same file), which is the real lifecycle step where
#     each round's snapshot is produced. _project_actor() is now provably pure — see
#     snapshot_purity/project_actor_does_not_mutate below (no longer tagged KNOWN DEFECT) — and
#     snapshot_purity/bark_line_fires_once_per_round proves the one-shot display behaviour still
#     holds end to end through the new call sites.
#   - SanctumLayoutService.ensure_layout() gained an optional `ctx: FlowContext = null` parameter.
#     Its write to save_data["sanctum"]["layout"] was always legitimate lifecycle work (not a
#     purity defect — it was never tagged as one needing inversion), but it had no way to request
#     a save; calling ctx.request_save("sanctum.layout") is now available whenever a caller
#     passes ctx (FlowSanctumState.enter() does). snapshot_purity/ensure_layout_writes_save_data
#     is left asserting the write happens — that assertion was always correct — with its comment
#     updated to record the new seam.
#
# The remaining two original probes (FlowEncounterState.build_final_snapshot() and
# FlowSanctumState.enter() calling VowService.release_vow_if_due()) are still tagged:
#   # KNOWN DEFECT — Phase 3 inverts this assertion to "must not mutate".
# and are untouched — out of scope for this slice, accepted lifecycle behaviour. None of these
# probes fix anything on their own beyond what is documented above. If a listed site turns out
# NOT to mutate on inspection, that finding is reported in the BUILD report instead of a
# fabricated probe.
#
# Slice C finishes the _bark_line purity fix that Slice B2 started. Slice B2 moved the clear out
# of _project_actor() into its two callers (build_round_snapshot()/build_final_snapshot()) — an
# improvement, but those two loops were still mutating the source they were projecting, which
# left the BUILDERS themselves impure. Slice C moves the clear one step further out, to
# FlowRuntime.dispatch()'s closure (the same choke point already used for
# pending_awakening_banner/pending_return_notification), gated to flow.encounter /
# flow.keeper_trial / flow.resolve snapshots. This changes two things here:
#   - snapshot_purity/bark_line_fires_once_per_round used to call build_round_snapshot()
#     directly and assert the SOURCE was cleared immediately after that direct call — true under
#     the old (Slice B2) architecture, where the builder did the clearing. It is no longer true:
#     a direct builder call is now byte-identical on repeat (see the new purity probe below), and
#     the source is only cleared by dispatch()'s closure. The test is rewritten to drive real
#     dispatch() calls (combat.init/confirm_round/next_actor — the same production entry points
#     FlowFingerprintTests._drive_and_capture() uses) so it proves the SAME end-to-end contract
#     ("shown exactly once") through the new call site instead of the old one.
#   - snapshot_purity/build_round_snapshot_and_final_snapshot_do_not_mutate_bark is new: it
#     extends the proof in snapshot_purity/project_actor_does_not_mutate up one level, showing
#     the two builders that call _project_actor() are now themselves pure w.r.t. _bark_line too
#     (two direct calls in a row are byte-identical — no clear either fires internally).

class_name FlowSnapshotFingerprintTests
extends RefCounted



static func register(runner) -> void:
	# TASK 1 — snapshot fingerprints
	runner.register_test("snapshot_fingerprint/sanctum", func(): return test_sanctum_fingerprint())
	runner.register_test("snapshot_fingerprint/stage_explore", func(): return test_stage_explore_fingerprint())
	# TASK 2 — snapshot purity probes (record current behaviour; fix nothing)
	runner.register_test("snapshot_purity/build_does_not_consume_pending_flags", func(): return test_purity_build_does_not_consume_pending_flags())
	runner.register_test("snapshot_purity/build_final_snapshot_pays_rewards", func(): return test_purity_build_final_snapshot_pays_rewards())
	runner.register_test("snapshot_purity/sanctum_enter_releases_vow", func(): return test_purity_sanctum_enter_releases_vow())
	runner.register_test("snapshot_purity/project_actor_does_not_mutate", func(): return test_purity_project_actor_does_not_mutate())
	runner.register_test("snapshot_purity/bark_line_fires_once_per_round", func(): return test_purity_bark_line_fires_once_per_round())
	runner.register_test("snapshot_purity/build_round_snapshot_and_final_snapshot_do_not_mutate_bark", func(): return test_purity_snapshot_builders_do_not_mutate_bark())
	runner.register_test("snapshot_purity/ensure_layout_writes_save_data", func(): return test_purity_ensure_layout_writes_save_data())
	runner.register_test("snapshot_purity/generic_double_build_is_stable", func(): return test_purity_generic_double_build_is_stable())
	runner.register_test("snapshot_purity/dispatch_clears_pending_flags_after_publish", func(): return test_purity_dispatch_clears_pending_flags_after_publish())
	runner.register_test("snapshot_purity/dispatch_preserves_pending_return_notification_until_sanctum", func(): return test_purity_dispatch_preserves_pending_return_notification_until_sanctum())
	# V2-INFRA-003 Phase 5 Slice B — ResolveSnapshotBuilder's own purity guard.
	runner.register_test("snapshot_purity/resolve_builder_double_build_is_stable", func(): return test_purity_resolve_builder_double_build_is_stable())


# ---------------------------------------------------------------------------
# Shared harness
# ---------------------------------------------------------------------------

## Delegates to the shared harness: deleting only the PRIMARY file left SaveService's backup
## chain on disk, so boot() recovered a previous run's campaign instead of minting a new save.
## See tests/TestSaveHarness.gd.
static func _fresh_save_path(seed_tag: String) -> String:
	return TestSaveHarness.fresh_save_path("flow_snap_fp_%s.json" % seed_tag)


## Fresh runtime → grant the Chapter I starter Echo → force keeper-intro complete → land on
## flow.sanctum. Deletes any leftover save file at this path first, so a brand-new save always
## gets root_seed 12346 (SaveService.make_new_save literal — see FlowRuntime.boot()), pinning the
## campaign seed without this file touching it directly.
##
## Deliberately does NOT dispatch "flow.new_game": that action calls
## CampaignSeed.generate_seed_root_string() to pick a genuinely random campaign seed_root for a
## real player's new campaign (by design — every playthrough should be unique), which made an
## early version of this harness non-deterministic across process runs (roster identity, stats,
## and derived emotion all differed run to run). boot() alone already leaves a freshly-created
## save on disk with the pinned literal seed when none exists, so onboarding is driven from there
## directly (OnboardingService.select_fragment() + dispatching "onboarding.fragment.confirm",
## which is what actually grants the starter Echo via FlowRuntime._grant_starter_echo_for_fragment)
## — no dispatch in this path touches the seed or reads wall-clock time.
## Mirrors tests/SkillUnlockTests.gd _make_runtime_env() / tests/PartyTests.gd _make_runtime_env()
## in spirit, duplicated here (not cross-called) so this file has no dependency on another test
## suite's helpers — but corrected to skip flow.new_game for the reason above.
static func _setup_sanctum_env(seed_tag: String) -> Dictionary:
	var save_path := _fresh_save_path(seed_tag)
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, save_path)
	runtime.boot()

	var cfg: Dictionary = runtime.config_service.get_balance()
	var options: Array = OnboardingService.build_fragment_options(runtime.flow_ctx.save_data, cfg)
	if options.is_empty():
		return { "ok": false, "error": "Could not create deterministic starter fragment options" }
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(options[0].get("virtue", "")))
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })

	var save_ref: Dictionary = runtime.get_save_data()
	var onboarding_v: Variant = save_ref.get("onboarding", {})
	if onboarding_v is Dictionary:
		var ob: Dictionary = onboarding_v as Dictionary
		ob["keeper_intro_complete"] = true
		ob["keeper_intro_step"]     = "complete"

	# _gate_state_for_keeper_intro allows flow.sanctum once keeper_intro_complete=true.
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.sanctum" })

	return { "ok": true, "runtime": runtime }


## Extends _setup_sanctum_env: stages the starter Echo into the active party, then drives the
## SAME production dispatch chain a player uses to reach exploration — flow.select_realm →
## flow.select_stage → flow.go_state(STAGE_EXPLORE) — never hand-injecting a synthetic stage.
static func _setup_stage_explore_env(seed_tag: String) -> Dictionary:
	var env := _setup_sanctum_env(seed_tag)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]

	var sanctum_v: Variant = runtime.get_save_data().get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty() or not (roster[0] is Dictionary):
		return { "ok": false, "error": "Roster empty after onboarding — cannot stage a party" }
	var echo_id := str((roster[0] as Dictionary).get("id", ""))
	if echo_id.is_empty():
		return { "ok": false, "error": "Starter echo has no id" }

	runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })
	runtime.dispatch({ "type": "flow.select_realm", "realm_id": "realm.01" })
	runtime.dispatch({ "type": "flow.select_stage", "stage_id": "stage.0" })
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.stage_explore" })

	return { "ok": true, "runtime": runtime }


## Canonical fingerprint projection: the full `data` payload plus sorted `actions` slot keys.
## Deliberately excludes `meta` (carries only the sim tick `t`, which is not part of the
## documented contract for this task and is otherwise deterministic-but-irrelevant scaffolding).
## No field inside `data` is wall-clock-derived for either flow.sanctum or flow.stage_explore —
## verified by reading both builders end to end (FlowSanctumState.gd, FlowStateMachine.gd's
## SANCTUM enrichment branch, FlowStageExploreState.gd): no Time.* call reaches either snapshot's
## `data` dict, so nothing needed to be excluded here.
static func _fingerprint_projection(snap: Dictionary) -> Dictionary:
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var action_keys: Array = actions.keys()
	action_keys.sort()
	return {
		"data":        data,
		"action_keys": action_keys,
	}


static func _hash(v: Variant) -> String:
	return JSON.stringify(v, "", true).sha256_text()


# ---------------------------------------------------------------------------
# TASK 1 — snapshot fingerprints
# ---------------------------------------------------------------------------

## V2-INFRA-003 Phase 3 Slice B2: this hash was re-derived after making
## valid_placement_cells / placement_floor_cells / placement_occupied_cells JSON-safe
## ({"x": int, "y": int} dicts instead of Vector2i — see SanctumSnapshotBuilder.gd). The change
## is representation-only: same cells, same order, same count. A hash drift here is expected and
## intended — the whole point of the fix was to change this payload's representation so the
## central null-scan validator can inspect it; a stable Vector2i-shaped hash would mean the fix
## didn't take. Previous value (Vector2i-shaped cells): 1230cd5be4d3642b0737bf042287d1de2a5abd6db34e945caed0d8b75fe45c9e.
##
## DIAGNOSTIC re-derivation (2026-08-15): the value that briefly stood here,
## 4238be8a427fcaa76f7e3bbd67a450ba2be9cb7e2029c87aa5bf44ba580710fb, was recorded by an agent that
## did not rebuild the Godot script class cache first, so it does not reflect the real output of
## this code. On a rebuilt cache the suite fails with actual=cbcc7992a21be3b5e85fe3a558320d0501e-
## 75b7f6311a85876ce9c32e834b0e1 (full: see below). Audited the full `data` payload (dumped via a
## throwaway --script harness calling _setup_sanctum_env directly, never checked into the repo)
## against `git show HEAD:core/state/flow/states/sanctum/FlowSanctumState.gd` and
## `git show HEAD:core/state/flow/FlowStateMachine.gd` (the pre-Slice-A/B2 originals — this
## refactor's other files are untracked, so HEAD is the true "before"): every field the builder
## produces is byte-for-byte the same construction as before, including the helper functions
## (_build_echo_detail_roster, _build_active_effects, etc., diffed line-for-line, identical) and
## SanctumLayoutService.ensure_layout()'s tile computation (diff shows only the additive optional
## `ctx` param + request_save call — no change to tiles or their order). The ONLY delta anywhere
## in the payload is the three placement-cell arrays switching from Vector2i to {"x","y"} dicts —
## same cells, same order, same count, confirmed via a full non-JSON-safe-type scan (zero
## offenders) and by inspecting the first elements of each array. No save-schema field
## (opening_realm_id, opening_realm_status, pending_result, etc.) leaked into the projection.
## Verdict: (a) representation-only change, so this constant is the correct re-derivation, not a
## fresh guess overwriting a legitimate regression.
const SANCTUM_FINGERPRINT_HASH := "cbcc7992a21be3b5e85fe3a558320d0501e75b7f6311a85876ce9c32e834b0e1"

static func test_sanctum_fingerprint() -> Dictionary:
	var env := _setup_sanctum_env("fp_sanctum")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var snap: Dictionary = runtime.flow_ctx.last_snapshot
	if str(snap.get("type", "")) != FlowStateIds.SANCTUM:
		return { "ok": false, "error": "Expected flow.sanctum snapshot, got type=%s" % str(snap.get("type", "")) }

	var actual := _hash(_fingerprint_projection(snap))
	if actual != SANCTUM_FINGERPRINT_HASH:
		return {
			"ok": false,
			"error": "sanctum fingerprint drifted: expected=%s actual=%s" % [SANCTUM_FINGERPRINT_HASH, actual],
		}
	return { "ok": true }


const STAGE_EXPLORE_FINGERPRINT_HASH := "528b8d5a584bb06dcc199340d99a78e06776e3ab79d364519701bd169e707e54"

static func test_stage_explore_fingerprint() -> Dictionary:
	var env := _setup_stage_explore_env("fp_stage_explore")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var snap: Dictionary = runtime.flow_ctx.last_snapshot
	if str(snap.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
		return { "ok": false, "error": "Expected flow.stage_explore snapshot, got type=%s" % str(snap.get("type", "")) }

	var actual := _hash(_fingerprint_projection(snap))
	print("SE_DEBUG hash=%s payload=%s" % [actual, JSON.stringify(_fingerprint_projection(snap))])
	if actual != STAGE_EXPLORE_FINGERPRINT_HASH:
		return {
			"ok": false,
			"error": "stage_explore fingerprint drifted: expected=%s actual=%s" % [STAGE_EXPLORE_FINGERPRINT_HASH, actual],
		}
	return { "ok": true }


# ---------------------------------------------------------------------------
# TASK 2 — snapshot purity probes
# Each probe records TODAY's behaviour (bug included) and fixes nothing.
# ---------------------------------------------------------------------------

## Site 1: SanctumSnapshotBuilder.build() (core/state/flow/states/sanctum/SanctumSnapshotBuilder.gd)
## is the pure projection introduced in V2-INFRA-003 Phase 3. It READS
## FlowContext.pending_awakening_banner and pending_return_notification to derive
## show_awakening_overlay / return_notification into the `data` payload, but must NEVER write
## to FlowContext — no field mutation of any kind. Clearing the two flags now happens exactly
## once, in FlowRuntime.dispatch()'s closure, AFTER the snapshot this build() produced has
## been published (see test_purity_dispatch_clears_pending_flags_after_publish below).
## Formerly KNOWN DEFECT (FlowStateMachine._rebuild_snapshot() used to consume these flags
## while "building" the snapshot) — Phase 3 fixed it; this probe now asserts purity directly.
static func test_purity_build_does_not_consume_pending_flags() -> Dictionary:
	var env := _setup_sanctum_env("purity_pending_flags")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var ctx: FlowContext = runtime.flow_ctx

	ctx.pending_awakening_banner = true
	ctx.pending_return_notification = { "ase_earned": 7, "situations_revealed": 2 }

	var before_banner: bool = ctx.pending_awakening_banner
	var before_notif: Dictionary = ctx.pending_return_notification.duplicate()

	var snap: Dictionary = SanctumSnapshotBuilder.build(ctx, ctx.sim_tick)

	var after_banner: bool = ctx.pending_awakening_banner
	var after_notif: Dictionary = ctx.pending_return_notification

	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var mismatches: Array = []
	if not before_banner:
		mismatches.append("test setup failed: expected pending_awakening_banner=true before build")
	if before_notif.is_empty():
		mismatches.append("test setup failed: expected pending_return_notification non-empty before build")
	if after_banner != true:
		mismatches.append("expected build() to leave pending_awakening_banner untouched (still true), got %s" % after_banner)
	if after_notif.is_empty():
		mismatches.append("expected build() to leave pending_return_notification untouched (still non-empty), got empty")
	if bool(data.get("show_awakening_overlay", false)) != true:
		mismatches.append("expected the built snapshot to reflect show_awakening_overlay=true (read, not consumed)")
	var notif_out_v: Variant = data.get("return_notification", {})
	if not ((notif_out_v is Dictionary) and (notif_out_v as Dictionary).has("ase_earned")):
		mismatches.append("expected the built snapshot to carry return_notification.ase_earned")

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## Site 2: FlowEncounterState.build_final_snapshot()
## (core/state/flow/states/venture/FlowEncounterState.gd).
##
## ASSERTION INVERTED — V2-INFRA-003 Phase 8, per defect-register D76. The PRODUCTION DRIVE IS
## UNCHANGED and deliberately so: this probe reuses FlowFingerprintTests._setup_encounter /
## _drive_and_capture, which dispatch only combat.init / combat.confirm_round /
## combat.next_actor and NEVER flow.complete_stage. Observing across that dispatch boundary is
## the entire point — a direct build_final_snapshot() call could not see it.
##
## WAS: the builder paid the WHOLE reward — the stage's base objective weights, the realm-virtue
## bonus, the stage-clear Storyweight — plus request_save("stage.reward"), all while "building"
## a snapshot, once per ENCOUNTER, in a dispatch that never advanced the stage. This test
## asserted that it mutated economy OR xp OR emotion, i.e. it pinned the impurity.
##
## NOW: the stage-cadence half is gone from the builder. D76's revised action said to invert to
## "must NOT mutate"; that is TOO STRONG and this probe would have passed vacuously under it,
## because two mutations correctly REMAIN and are not defects:
##   - the ENCOUNTER payout (enemies defeated / echoes survived / speed, and the once-per-
##     situation defeat consolation) — this fight's own reward, paid in the dispatch that ends
##     this fight, so economy still moves here;
##   - the roster emotion write-back — the fear/morale THIS encounter accumulated.
## What LEFT is the STAGE-CLEAR Storyweight award. The inverted assertion is therefore specific,
## and it is NOT "xp_total must not move": per-kill Storyweight is applied mid-combat, per kill,
## and is encounter cadence — one echo in this fight ends the drive with a kill bonus, correctly.
## The precise observable is the resolve snapshot's own `xp_events` array: that array IS the
## return value of ProgressionService.award_post_combat_xp(), the call that moved. It must now be
## EMPTY at combat end, and refill only after a flow.complete_stage dispatch. Meanwhile economy
## and emotion MUST still move here. A non-empty xp_events would mean the stage-clear award had
## crept back into the builder; an economy or emotion freeze would mean the encounter-cadence
## half had wrongly followed it out.
static func test_purity_build_final_snapshot_pays_rewards() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "purity_probe_combat")
	if env.is_empty():
		return { "ok": false, "error": "encounter setup failed for COMBAT mode" }
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]
	var party_ids: Array = env["party_ids"]

	var econ_before: Dictionary = flow_ctx.save_data.get("economy", {})
	var ase_before := int(econ_before.get("ase", -1))
	var ekwan_before := int(econ_before.get("ekwan", -1))
	var xp_before: Dictionary = {}
	var emotion_before: Dictionary = {}
	var roster_before_v: Variant = (flow_ctx.save_data.get("sanctum", {}) as Dictionary).get("roster", [])
	for e_v in (roster_before_v if roster_before_v is Array else []):
		if e_v is Dictionary and str((e_v as Dictionary).get("id", "")) in party_ids:
			var e: Dictionary = e_v
			var eid := str(e.get("id", ""))
			xp_before[eid] = int(e.get("xp_total", 0))
			var emo_v: Variant = e.get("emotion", {})
			emotion_before[eid] = (emo_v as Dictionary).duplicate() if emo_v is Dictionary else {}

	var drive: Dictionary = FlowFingerprintTests._drive_and_capture(runtime, ectx, 30)
	if not bool(drive.get("combat_over", false)):
		return { "ok": false, "error": "combat did not conclude within 30 rounds — cannot observe build_final_snapshot()" }

	var econ_after: Dictionary = flow_ctx.save_data.get("economy", {})
	var ase_after := int(econ_after.get("ase", -1))
	var ekwan_after := int(econ_after.get("ekwan", -1))
	var xp_after: Dictionary = {}
	var emotion_after: Dictionary = {}
	var roster_after_v: Variant = (flow_ctx.save_data.get("sanctum", {}) as Dictionary).get("roster", [])
	for e_v2 in (roster_after_v if roster_after_v is Array else []):
		if e_v2 is Dictionary and str((e_v2 as Dictionary).get("id", "")) in party_ids:
			var e2: Dictionary = e_v2
			var eid2 := str(e2.get("id", ""))
			xp_after[eid2] = int(e2.get("xp_total", 0))
			var emo_v2: Variant = e2.get("emotion", {})
			emotion_after[eid2] = (emo_v2 as Dictionary).duplicate() if emo_v2 is Dictionary else {}

	var xp_changed: bool = JSON.stringify(xp_before, "", true) != JSON.stringify(xp_after, "", true)
	var emotion_changed: bool = JSON.stringify(emotion_before, "", true) != JSON.stringify(emotion_after, "", true)
	var economy_changed: bool = ase_before != ase_after or ekwan_before != ekwan_after

	# `xp_changed` is deliberately computed but NOT asserted on: mid-combat per-kill Storyweight
	# legitimately moves xp_total during this drive. See the header.
	var _xp_moved_by_kills := xp_changed
	var final_data_v: Variant = flow_ctx.last_snapshot.get("data", {})
	var final_data: Dictionary = final_data_v if final_data_v is Dictionary else {}
	var xp_events_v: Variant = final_data.get("xp_events", [])
	var xp_events: Array = xp_events_v if xp_events_v is Array else []

	var mismatches: Array = []
	if not xp_events.is_empty():
		mismatches.append("the stage-clear Storyweight award is back inside build_final_snapshot(): %d xp_events at combat end with no flow.complete_stage dispatch (xp %s -> %s)" \
			% [xp_events.size(), JSON.stringify(xp_before), JSON.stringify(xp_after)])
	if not economy_changed:
		mismatches.append("the ENCOUNTER payout stopped paying at combat end: ase %d->%d ekwan %d->%d" \
			% [ase_before, ase_after, ekwan_before, ekwan_after])
	if not emotion_changed:
		mismatches.append("the roster emotion write-back stopped running at combat end")
	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## Site 3: FlowSanctumState.enter() (core/state/flow/states/sanctum/FlowSanctumState.gd) calls
## VowService.release_vow_if_due() while building the flow.sanctum snapshot — if the release
## condition is already met, the active vow is cleared as a side effect of "building" the
## snapshot, not by any explicit player action. (enter() also calls
## SanctumLayoutService.ensure_layout() on the same line-range; that function's own mutation is
## probed independently and unconditionally below, since ensure_layout() has no ctx parameter
## and so cannot be probed "through" a save-request seam here.)
## KNOWN DEFECT — Phase 3 inverts this assertion to "must not mutate".
static func test_purity_sanctum_enter_releases_vow() -> Dictionary:
	var env := _setup_sanctum_env("purity_vow_release")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = runtime.flow_ctx

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	# Pledged outside any realm (pledged_at_realm == ""), so the release condition is
	# "current total run_count > runs_at_pledge". One completed run against runs_at_pledge=0
	# satisfies it (VowService.release_vow_if_due, "Pledged from Sanctum" branch).
	sanctum["active_vow"] = {
		"vow_id":           "tikoro_nko_agyina",
		"tier":             1,
		"pledged_at_realm": "",
		"runs_at_pledge":   0,
		"compliance_count": 0,
	}
	flow_ctx.save_data["sanctum"] = sanctum
	flow_ctx.save_data["realms"] = { "realm.01": { "run_count": 1, "status": "complete" } }

	var before_active: Dictionary = VowService.get_active_vow(flow_ctx.save_data)

	FlowSanctumState.new().enter(flow_ctx, flow_ctx.sim_tick)

	var after_active: Dictionary = VowService.get_active_vow(flow_ctx.save_data)

	var mismatches: Array = []
	if before_active.is_empty():
		mismatches.append("test setup failed: expected an active vow before enter()")
	if not after_active.is_empty():
		mismatches.append("expected active_vow cleared by FlowSanctumState.enter(), got %s" % JSON.stringify(after_active))

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## Site 4: EncounterSnapshotBuilder._project_actor() (~line 1212 of
## core/state/flow/states/venture/FlowEncounterState.gd) used to mutate the live actor dict it
## was projecting — it read actor["_bark_line"] into the returned projection, then wrote
## actor["_bark_line"] = "" back onto the SAME dict. Since actor dicts are shared references
## into EncounterContext.actors (not deep-copied per projection), that was a read-consumes-the-
## source side effect on the actor the encounter was still simulating.
## FIXED in Slice B2: _project_actor() now only reads "_bark_line" — it never writes to `actor`.
## Slice B2 moved the consume to its two callers, build_round_snapshot() and
## build_final_snapshot() (both in FlowEncounterState.gd); Slice C moved it again, out of those
## two loops entirely and into FlowRuntime.dispatch()'s closure, so both builders are now ALSO
## provably pure — see snapshot_purity/build_round_snapshot_and_final_snapshot_do_not_mutate_bark
## below for that proof, and snapshot_purity/bark_line_fires_once_per_round for proof the
## one-shot display behaviour still holds end to end through the new clear site.
static func test_purity_project_actor_does_not_mutate() -> Dictionary:
	var actor := {
		"id":       "echo_test_0001",
		"name":     "Test Echo",
		"stats":    { "max_hp": 20 },
		"current_hp": 20,
		"fear":     0,
		"morale":   50,
		"faction":  "echo",
		"grid_pos": { "col": 0, "row": 0 },
		"_bark_line": "The wound knows us.",
	}
	var before := actor.duplicate(true)

	var before_bark := str(actor.get("_bark_line", ""))
	var proj: Dictionary = EncounterSnapshotBuilder._project_actor(actor)
	var after_bark := str(actor.get("_bark_line", ""))

	var mismatches: Array = []
	if before_bark.is_empty():
		mismatches.append("test setup failed: expected a non-empty _bark_line before projection")
	if str(proj.get("bark_line", "")) != before_bark:
		mismatches.append("expected the projection to carry the actor's current bark line")
	if after_bark != before_bark:
		mismatches.append("expected _project_actor() to leave actor[\"_bark_line\"] untouched (still %s), got %s" \
			% [before_bark, after_bark])
	if JSON.stringify(actor, "", true) != JSON.stringify(before, "", true):
		mismatches.append("expected _project_actor() to leave the actor dict byte-identical to its input, got a diff")

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## Companion to the purity probe above: proves the bark still fires exactly once, end to end,
## through the REAL production dispatch chain — updated for Slice C, which moved the clear out
## of build_round_snapshot()'s loop and into FlowRuntime.dispatch()'s closure (see the gate near
## the end of dispatch() in core/runtime/FlowRuntime.gd). A direct build_round_snapshot() call no
## longer clears anything (proven by
## snapshot_purity/build_round_snapshot_and_final_snapshot_do_not_mutate_bark below), so this
## probe can no longer prove "shown once" by calling the builder directly three times — it has to
## drive real dispatch() calls, the same production entry points
## FlowFingerprintTests._drive_and_capture() uses (combat.init → combat.confirm_round →
## combat.next_actor), and read the bark off the snapshot each dispatch() call *returns*.
##
## Target selection: pick the LAST actor in initiative_order as the bark target. Regular
## per-actor bark writes (ActorStateMachine.advance_turn()) only ever touch the actor whose turn
## is currently resolving — never a bystander (the only writers that touch a non-acting actor,
## _fire_spirit_bark()/_fire_ally_bark() in FlowRuntime.gd, are gated to is_spirit/is_ally actors,
## which this COMBAT-mode encounter has none of). Targeting the actor who acts LAST guarantees
## the three combat.next_actor dispatches below (which resolve the actors immediately after
## index 0, in order) never resolve the target's own turn, so nothing but the dispatch()-closure
## clear under test can touch the manually-injected bark:
##   dispatch 1 (combat.next_actor): a bark fires for the target → must appear in the snapshot
##     THIS dispatch() call publishes, then be cleared on the source once dispatch() returns.
##   dispatch 2 (combat.next_actor): a NEW bark fires → must appear in dispatch 2's published
##     snapshot (not dispatch 1's stale line).
##   dispatch 3 (combat.next_actor): no bark fires → must NOT resurrect dispatch 2's line.
static func test_purity_bark_line_fires_once_per_round() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "purity_bark_once")
	if env.is_empty():
		return { "ok": false, "error": "encounter setup failed for COMBAT mode" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]

	runtime.dispatch({ "type": "combat.init" })
	var order: Array = ectx.combat_state.get("initiative_order", [])
	# Need at least 5 actors so the target (last in order) is never reached by the 3
	# combat.next_actor dispatches below (which resolve order[1], order[2], order[3] — order[0]
	# is resolved by combat.confirm_round itself).
	if order.size() < 5:
		return { "ok": false, "error": "test setup failed: expected at least 5 actors in initiative order, got %d" % order.size() }
	var target_id := str((order[order.size() - 1] as Dictionary).get("id", ""))
	if target_id.is_empty():
		return { "ok": false, "error": "test setup failed: could not resolve a target actor id" }

	var mismatches: Array = []

	runtime.dispatch({ "type": "combat.confirm_round" })

	_set_actor_bark(ectx, target_id, "Dispatch one: the wound knows us.")
	var out1: Dictionary = runtime.dispatch({ "type": "combat.next_actor" })
	var bark1 := _find_projected_bark(out1, target_id)
	if bark1 != "Dispatch one: the wound knows us.":
		mismatches.append("dispatch 1: expected the fresh bark in the snapshot PUBLISHED by dispatch(), got \"%s\"" % bark1)
	if not _get_actor_bark(ectx, target_id).is_empty():
		mismatches.append("dispatch 1: expected the source actor's _bark_line consumed to \"\" once dispatch() returns (cleared by dispatch()'s closure, not the builder)")

	_set_actor_bark(ectx, target_id, "Dispatch two: still here. Finish it.")
	var out2: Dictionary = runtime.dispatch({ "type": "combat.next_actor" })
	var bark2 := _find_projected_bark(out2, target_id)
	if bark2 != "Dispatch two: still here. Finish it.":
		mismatches.append("dispatch 2: expected the NEW bark in the published snapshot (not dispatch 1's stale line), got \"%s\"" % bark2)

	# Dispatch 3: no new bark fires (ActorStateMachine would have written "" for this turn).
	var out3: Dictionary = runtime.dispatch({ "type": "combat.next_actor" })
	var bark3 := _find_projected_bark(out3, target_id)
	if bark3 != "":
		mismatches.append("dispatch 3: expected no bark (dispatch 2's line must not resurface), got \"%s\"" % bark3)

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## New in Slice C: extends snapshot_purity/project_actor_does_not_mutate up one level. Proves
## build_round_snapshot() and build_final_snapshot() — the two callers that used to consume
## _bark_line themselves right after calling the now-pure _project_actor() — are themselves now
## pure projections: two direct calls in a row are byte-identical, and neither clears the source
## actor's _bark_line. Uses the same minimal-FlowContext harness style as
## tests/CombatSnapshotTests.gd (_make_pre_combat_ctx/_make_combat_over_ctx) rather than the full
## FlowFingerprintTests encounter harness — no config/combat AI needed to observe whether these
## two functions write back to the actor dicts they read.
static func test_purity_snapshot_builders_do_not_mutate_bark() -> Dictionary:
	var mismatches: Array = []

	# --- build_round_snapshot() (pre_combat phase) ---
	var round_ctx := FlowContext.new()
	round_ctx.config_service = null
	var round_ectx := EncounterContext.new()
	round_ectx.encounter_id = "purity_bark_round_001"
	round_ectx.placement_seed = 1
	round_ectx.combat_state = {}  # empty → pre_combat
	var round_actor := {
		"id": "echo_bark_probe_round", "name": "Bark Probe",
		"stats": { "max_hp": 20 }, "current_hp": 20, "fear": 0, "morale": 50,
		"faction": "echo", "grid_pos": { "col": 0, "row": 0 }, "is_dead": false,
		"_bark_line": "The wound knows us.",
	}
	round_ectx.actors = [round_actor]
	round_ctx.encounter_ctx = round_ectx

	var round_before := str(round_actor.get("_bark_line", ""))
	var round_build1: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(round_ctx, 1)
	var round_after1 := str(round_actor.get("_bark_line", ""))
	var round_bark1 := _find_projected_bark(round_build1, "echo_bark_probe_round")
	var round_build2: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(round_ctx, 1)
	var round_after2 := str(round_actor.get("_bark_line", ""))
	var round_bark2 := _find_projected_bark(round_build2, "echo_bark_probe_round")

	if round_before.is_empty():
		mismatches.append("round: test setup failed — expected a non-empty _bark_line before build")
	if round_bark1 != round_before:
		mismatches.append("round: expected build 1 to project the current bark line, got \"%s\"" % round_bark1)
	if round_after1 != round_before:
		mismatches.append("round: expected build_round_snapshot() to leave actor[\"_bark_line\"] untouched after build 1 (still \"%s\"), got \"%s\"" % [round_before, round_after1])
	if round_bark2 != round_before:
		mismatches.append("round: expected a second direct call to project the SAME still-unconsumed bark line, got \"%s\"" % round_bark2)
	if round_after2 != round_before:
		mismatches.append("round: expected the bark line to remain unconsumed after two direct build_round_snapshot() calls")

	# --- build_final_snapshot() (combat_over phase) ---
	var final_ctx := FlowContext.new()
	final_ctx.config_service = null
	var final_ectx := EncounterContext.new()
	final_ectx.encounter_id = "purity_bark_final_001"
	final_ectx.placement_seed = 1
	final_ectx.combat_state = { "combat_over": true, "objective": "defeat_enemies", "round_counter": 1 }
	final_ectx.combat_result = { "victory": true, "reason": "all_enemies_defeated", "round_ended": 1 }
	var final_actor := {
		"id": "echo_bark_probe_final", "name": "Bark Probe",
		"stats": { "max_hp": 20 }, "current_hp": 20, "fear": 0, "morale": 50,
		"faction": "echo", "grid_pos": { "col": 0, "row": 0 }, "is_dead": false,
		"_bark_line": "Still here. Finish it.",
	}
	final_ectx.actors = [final_actor]
	final_ctx.encounter_ctx = final_ectx

	var final_before := str(final_actor.get("_bark_line", ""))
	var final_build1: Dictionary = FlowEncounterState.build_final_snapshot(final_ctx, 1)
	var final_after1 := str(final_actor.get("_bark_line", ""))
	var final_bark1 := _find_projected_bark(final_build1, "echo_bark_probe_final")

	if final_before.is_empty():
		mismatches.append("final: test setup failed — expected a non-empty _bark_line before build")
	if final_bark1 != final_before:
		mismatches.append("final: expected build_final_snapshot() to project the current bark line, got \"%s\"" % final_bark1)
	if final_after1 != final_before:
		mismatches.append("final: expected build_final_snapshot() to leave actor[\"_bark_line\"] untouched (still \"%s\"), got \"%s\"" % [final_before, final_after1])

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


static func _set_actor_bark(ectx: EncounterContext, actor_id: String, line: String) -> void:
	for a_v in ectx.actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("id", "")) == actor_id:
			(a_v as Dictionary)["_bark_line"] = line
			return


static func _get_actor_bark(ectx: EncounterContext, actor_id: String) -> String:
	for a_v in ectx.actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("id", "")) == actor_id:
			return str((a_v as Dictionary).get("_bark_line", ""))
	return ""


static func _find_projected_bark(snap: Dictionary, actor_id: String) -> String:
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actors_v: Variant = data.get("actors", [])
	var actors: Array = actors_v if actors_v is Array else []
	for a_v in actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("id", "")) == actor_id:
			return str((a_v as Dictionary).get("bark_line", ""))
	return ""


## Site 5: SanctumLayoutService.ensure_layout() (core/sanctum/SanctumLayoutService.gd) writes
## save_data["sanctum"]["layout"] unconditionally — creating it on first call, and rewriting
## layout["tiles"] with a freshly built Array on every call thereafter, regardless of whether
## anything actually changed. This is legitimate lifecycle work (repairing/deriving the layout
## before the snapshot projects it), not a purity defect — it was never tagged KNOWN DEFECT, and
## this probe still asserts the write happens rather than asserting purity.
## FIXED in Slice B2 (the actual gap here): the signature used to be
## `ensure_layout(save_data, inst_snapshot)` — no FlowContext/ctx parameter at all — so it
## structurally could NOT call request_save() itself, and its write relied on some later,
## unrelated action to flush it. It now takes an optional third parameter,
## `ctx: FlowContext = null`; when a caller passes one, ensure_layout() calls
## ctx.request_save("sanctum.layout") itself after writing. FlowSanctumState.enter() passes
## flow_ctx at its call site. This probe calls ensure_layout(save_data, []) — no ctx, exactly as
## every other caller in this file (compute_valid_placement_cells(), ensure_starter_occupant(),
## snapshot_layout()) still does — so it continues to prove the write happens with the new
## parameter fully optional; it does not exercise the ctx branch, which is production-covered by
## snapshot_fingerprint/sanctum (FlowSanctumState.enter() runs on every setup that test drives).
static func test_purity_ensure_layout_writes_save_data() -> Dictionary:
	var save_data: Dictionary = {}

	var had_sanctum_before: bool = save_data.has("sanctum")
	var had_layout_before: bool = (save_data.get("sanctum", {}) as Dictionary).has("layout")

	var layout: Dictionary = SanctumLayoutService.ensure_layout(save_data, [])

	var has_layout_after: bool = (save_data.get("sanctum", {}) as Dictionary).has("layout")
	var tiles_v: Variant = (save_data.get("sanctum", {}) as Dictionary).get("layout", {}).get("tiles", [])
	var tile_count: int = (tiles_v as Array).size() if tiles_v is Array else 0

	var mismatches: Array = []
	if had_sanctum_before or had_layout_before:
		mismatches.append("test setup failed: expected an empty save_data with no sanctum.layout before ensure_layout()")
	if not has_layout_after:
		mismatches.append("expected save_data[\"sanctum\"][\"layout\"] to be written in place by ensure_layout()")
	if tile_count <= 0:
		mismatches.append("expected a non-empty tile list written into save_data, got %d tiles" % tile_count)
	if layout.get("tiles", []) != (save_data.get("sanctum", {}) as Dictionary).get("layout", {}).get("tiles", []):
		mismatches.append("expected the returned layout's tiles to match what ensure_layout() wrote into save_data")
	# This call passes no ctx (third parameter, added in Slice B2, defaults to null), so no save
	# is requested here — confirmed by the signature
	# (static func ensure_layout(save_data: Dictionary, inst_snapshot: Array = [], ctx: FlowContext = null)).
	# The ctx branch is exercised by production callers (FlowSanctumState.enter()), not this probe.

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## Generic probe: build the SAME flow.sanctum snapshot twice in a row, calling
## SanctumSnapshotBuilder.build() directly, with no player action, no dispatch(), and no other
## mutation between the two calls — and diff the two `data` payloads byte-for-byte. A pure
## builder produces identical output both times.
## Formerly KNOWN DEFECT ("build1 != build2", because the old _rebuild_snapshot() consumed the
## one-shot flags on build 1, so build 2 saw them already cleared). Phase 3 inverted this: the
## builder now only READS the flags, so build 1 and build 2 are byte-identical, including
## show_awakening_overlay staying true on BOTH — it is the fix, not the probe, that makes this
## true; nothing here special-cases the flags to force a match.
static func test_purity_generic_double_build_is_stable() -> Dictionary:
	var env := _setup_sanctum_env("purity_double_build")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var ctx: FlowContext = runtime.flow_ctx

	ctx.pending_awakening_banner = true
	ctx.pending_return_notification = { "ase_earned": 3 }

	var build1: Dictionary = SanctumSnapshotBuilder.build(ctx, ctx.sim_tick)
	var build1_data: Dictionary = (build1.get("data", {}) as Dictionary).duplicate(true)

	var build2: Dictionary = SanctumSnapshotBuilder.build(ctx, ctx.sim_tick)
	var build2_data: Dictionary = (build2.get("data", {}) as Dictionary).duplicate(true)

	var build1_json := JSON.stringify(build1_data, "", true)
	var build2_json := JSON.stringify(build2_data, "", true)

	var mismatches: Array = []
	if build1_json != build2_json:
		mismatches.append("expected build1 == build2 (pure builder) but the payloads diverged — the builder is mutating something between calls")
	if bool(build1_data.get("show_awakening_overlay", false)) != true:
		mismatches.append("expected build1.show_awakening_overlay=true")
	if bool(build2_data.get("show_awakening_overlay", false)) != true:
		mismatches.append("expected build2.show_awakening_overlay=true (NOT consumed by build1 — that would be the old defect)")

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## New in V2-INFRA-003 Phase 3: SanctumSnapshotBuilder.build() reads-but-never-clears the two
## one-shot flags (proven by the two probes above), so FlowRuntime.dispatch() must be the place
## that clears them — exactly once, in the closure, AFTER the snapshot is published — for
## "shown exactly once" to still hold end to end. This drives a REAL dispatch() through a
## production action that actually triggers FlowSanctumState.enter() (sanctum.party.toggle,
## dispatched while snap_type == flow.sanctum, calls flow_machine.reenter() then
## refresh_snapshot() — see FlowRuntime._handle_sanctum_party_toggle()). A bare no-transition
## action such as ui.dismiss_summon_reveals would NOT do: refresh_snapshot() alone no longer
## rebuilds anything for flow.sanctum (Lesson 9 — it just re-validates ctx.last_snapshot as-is
## now that FlowStateMachine._rebuild_snapshot() has no Sanctum-specific branch left).
static func test_purity_dispatch_clears_pending_flags_after_publish() -> Dictionary:
	var env := _setup_sanctum_env("purity_dispatch_clears_flags")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var ctx: FlowContext = runtime.flow_ctx

	var sanctum_v: Variant = ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty() or not (roster[0] is Dictionary):
		return { "ok": false, "error": "Roster empty after onboarding — cannot drive a real reenter" }
	var echo_id := str((roster[0] as Dictionary).get("id", ""))
	if echo_id.is_empty():
		return { "ok": false, "error": "Starter echo has no id" }

	ctx.pending_awakening_banner = true
	ctx.pending_return_notification = { "ase_earned": 5, "situations_revealed": 1 }

	var out: Dictionary = runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })

	var data_v: Variant = out.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var mismatches: Array = []
	if bool(data.get("show_awakening_overlay", false)) != true:
		mismatches.append("expected the snapshot PUBLISHED by this dispatch() to show the overlay once")
	var notif_out_v: Variant = data.get("return_notification", {})
	if not ((notif_out_v is Dictionary) and (notif_out_v as Dictionary).has("ase_earned")):
		mismatches.append("expected the snapshot PUBLISHED by this dispatch() to carry return_notification.ase_earned")
	if ctx.pending_awakening_banner != false:
		mismatches.append("expected pending_awakening_banner cleared to false after dispatch() returns")
	if not ctx.pending_return_notification.is_empty():
		mismatches.append("expected pending_return_notification emptied after dispatch() returns")

	# A second real reenter (another toggle) must NOT show the overlay again — the flags were
	# cleared by the first dispatch()'s closure, and build() only reads them, never re-arms them.
	var out2: Dictionary = runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })
	var data2_v: Variant = out2.get("data", {})
	var data2: Dictionary = data2_v if data2_v is Dictionary else {}
	if bool(data2.get("show_awakening_overlay", false)) != false:
		mismatches.append("expected the SECOND dispatch()'s snapshot to NOT show the overlay again")
	if data2.has("return_notification"):
		mismatches.append("expected the SECOND dispatch()'s snapshot to NOT carry return_notification again")

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


## V2-INFRA-003 Phase 3 slice A follow-up FIX: the dispatch() closure used to clear
## pending_awakening_banner / pending_return_notification unconditionally on EVERY dispatch,
## not only when the published snapshot was flow.sanctum. pending_return_notification is set
## in exactly one place, OfflineAccrualService.apply_if_needed() (reached from "flow.continue"), but
## "flow.continue" does NOT always land on flow.sanctum: if keeper intro is incomplete it routes
## to the current keeper step instead (see the "flow.continue" case in dispatch()). The Ase
## Flame lights mid keeper-intro (onboarding.name.confirm awakens it — see
## FlowRuntime._handle_onboarding_name_confirm), so a real sequence is: reach the awakening,
## quit, continue (offline accrual queues the notice), land on a keeper step instead of
## Sanctum — and the old unconditional clear discarded the notice before the player ever saw
## it.
##
## This probe drives the real production sequence (fragment confirm → name confirm, which
## marks chapter one complete, awakens the Ase Flame, and starts keeper intro landing on
## flow.keeper_call — never flow.sanctum) up to the point where a notice could be queued, then:
##  1) dispatches "keeper_intro.call.answer" (a real keeper-intro action that transitions to
##     flow.keeper_trial, NOT flow.sanctum, and never touches pending_return_notification) and
##     asserts the flag survives — this is the exact bug the gate fixes.
##  2) forces keeper intro complete (same hack _setup_sanctum_env uses — no deterministic
##     in-game path short of playing the full first trial reaches this) and dispatches to
##     flow.sanctum for real, asserting the notice is carried on that snapshot and THEN cleared.
static func test_purity_dispatch_preserves_pending_return_notification_until_sanctum() -> Dictionary:
	var save_path := _fresh_save_path("purity_preserve_return_notif")
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, save_path)
	runtime.boot()

	var cfg: Dictionary = runtime.config_service.get_balance()
	var options: Array = OnboardingService.build_fragment_options(runtime.flow_ctx.save_data, cfg)
	if options.is_empty():
		return { "ok": false, "error": "Could not create deterministic starter fragment options" }
	OnboardingService.select_fragment(runtime.flow_ctx.save_data, cfg, str(options[0].get("virtue", "")))
	runtime.dispatch({ "type": "onboarding.fragment.confirm" })

	# onboarding.name.confirm marks chapter one complete and starts the keeper intro — landing on
	# flow.keeper_call, never flow.sanctum. This is the real production sequence that makes the
	# defect reachable.
	var landed: Dictionary = runtime.dispatch({ "type": "onboarding.name.confirm" })

	var ctx: FlowContext = runtime.flow_ctx
	var mismatches: Array = []

	if str(landed.get("type", "")) == FlowStateIds.SANCTUM:
		mismatches.append("test setup failed: expected onboarding.name.confirm to land on a keeper step, not flow.sanctum")
	# V2-INFRA-003 Phase 8C (D42 / D63): this setup used to assert the Ase Flame was LIT here.
	# It no longer is — name confirm is the end of Chapter I, and the Flame lights a chapter
	# later at the awakening rite. The assertion is inverted rather than dropped, because it is
	# still worth pinning that this scaffolding reaches the state it claims to.
	#
	# THE SUBJECT OF THIS TEST IS UNAFFECTED. It exercises the dispatch() closure's gate on
	# pending_return_notification, and the notice below is INJECTED directly on the context — it
	# never travels through OfflineAccrualService, so whether the Flame is lit is scaffolding,
	# not a precondition.
	var sanctum_setup_v: Variant = ctx.save_data.get("sanctum", {})
	var sanctum_setup: Dictionary = sanctum_setup_v if sanctum_setup_v is Dictionary else {}
	var flame_setup_v: Variant = sanctum_setup.get("ase_flame", {})
	var flame_setup: Dictionary = flame_setup_v if flame_setup_v is Dictionary else {}
	if bool(flame_setup.get("awakened", false)):
		mismatches.append("test setup failed: the Ase Flame must still be dark after onboarding.name.confirm")

	# Simulate a return notice already queued — the shape a real
	# OfflineAccrualService.apply_if_needed() call leaves behind on a flow.continue while the
	# keeper intro is still incomplete.
	ctx.pending_return_notification = { "ase_earned": 9, "situations_revealed": 4 }

	# "keeper_intro.call.answer" is a real keeper-intro action: it transitions to
	# flow.keeper_trial (not flow.sanctum) and never reads or writes
	# pending_return_notification, so this isolates the dispatch()-closure gate from
	# OfflineAccrualService.apply_if_needed's own logic.
	var out_non_sanctum: Dictionary = runtime.dispatch({ "type": "keeper_intro.call.answer" })

	if str(out_non_sanctum.get("type", "")) == FlowStateIds.SANCTUM:
		mismatches.append("test setup failed: expected keeper_intro.call.answer to land on flow.keeper_trial, not flow.sanctum")
	if ctx.pending_return_notification.is_empty():
		mismatches.append("BUG: pending_return_notification was cleared by a dispatch() that did not publish flow.sanctum")
	elif int(ctx.pending_return_notification.get("ase_earned", -1)) != 9:
		mismatches.append("pending_return_notification was mutated by a non-sanctum dispatch (expected untouched)")

	# Force keeper intro complete (same technique _setup_sanctum_env uses) and land on
	# flow.sanctum for real via flow.go_state.
	var onboarding_v: Variant = ctx.save_data.get("onboarding", {})
	if onboarding_v is Dictionary:
		var ob: Dictionary = onboarding_v as Dictionary
		ob["keeper_intro_complete"] = true
		ob["keeper_intro_step"]     = "complete"

	var out_sanctum: Dictionary = runtime.dispatch({ "type": "flow.go_state", "to": "flow.sanctum" })
	var data_v: Variant = out_sanctum.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var notif_v: Variant = data.get("return_notification", {})

	if str(out_sanctum.get("type", "")) != FlowStateIds.SANCTUM:
		mismatches.append("expected the third dispatch to land on flow.sanctum")
	if not ((notif_v is Dictionary) and int((notif_v as Dictionary).get("ase_earned", -1)) == 9):
		mismatches.append("expected the flow.sanctum snapshot to carry the preserved return_notification (ase_earned=9)")
	if not ctx.pending_return_notification.is_empty():
		mismatches.append("expected pending_return_notification cleared after the flow.sanctum snapshot was published")

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-INFRA-003 Phase 5 Slice B — ResolveSnapshotBuilder double-build purity
# ---------------------------------------------------------------------------

## The resolve builder is stronger than SanctumSnapshotBuilder: it takes NO FlowContext, so
## every input is a plain value the producer computed first. This probe pins the property the
## whole composition model rests on — two calls with the same arguments produce byte-identical
## payloads. It follows the snapshot_purity/generic_double_build_is_stable idiom above, but
## needs no runtime env at all, which is exactly the point.
##
## It exercises ALL SEVENTEEN blocks plus the base, including the eight only producers A
## (combat) and B (keeper trial) will call once they migrate in Phase 6. Phase 6 therefore
## inherits this guard without editing the builder.
static func test_purity_resolve_builder_double_build_is_stable() -> Dictionary:
	var mismatches: Array = []

	# Shared, producer-computed inputs. Passed to BOTH builds, and checked for mutation after.
	var actors_in: Array          = [{ "id": "e1", "name": "Kofi" }]
	var breakdown_in: Array       = [{ "label": "Scout return", "delta": 4, "currency": "ase" }]
	var emotion_in: Array         = [{ "id": "e1", "direction": "up", "tag": "" }]
	var effects_in: Array         = [{ "label": "Found", "kind": "ase" }]
	var vow_outcome_in: Dictionary = { "vow_id": "v1", "kept": true }
	var newly_unlocked_in: Array  = ["v2"]
	var objective_state_in: Dictionary = { "primary": "cleared" }
	var formula_inputs_in: Dictionary  = { "base": 10 }
	var relics_in: Array          = []
	var xp_events_in: Array       = [{ "id": "e1", "xp": 12 }]

	var actors_before := JSON.stringify(actors_in, "", true)
	var vow_before    := JSON.stringify(vow_outcome_in, "", true)

	var built: Array = []
	for _pass in 2:
		var actions: Dictionary = {
			"cta.continue": {
				"type":  "flow.go_state",
				"to":    FlowStateIds.SANCTUM,
				"label": "Return to Sanctum",
				"slot":  "cta.continue",
			}
		}
		var snap: Dictionary = ResolveSnapshotBuilder.build(7, actions, "scout_return")
		var data: Dictionary = snap["data"]
		ResolveSnapshotBuilder.add_banner(data, "scout_return", "2 crossings mapped.")
		ResolveSnapshotBuilder.add_victory_flag(data, false)
		ResolveSnapshotBuilder.add_grade_rank(data, "")
		ResolveSnapshotBuilder.add_grade_verdict(data, "")
		ResolveSnapshotBuilder.add_combat_stats(data, "enc.1", "all_enemies_defeated", 3, 2, 2, objective_state_in)
		ResolveSnapshotBuilder.add_actors(data, actors_in)
		ResolveSnapshotBuilder.add_ledger(data, 4, breakdown_in)
		ResolveSnapshotBuilder.add_ekwan(data, 0)
		ResolveSnapshotBuilder.add_emotion(data, emotion_in)
		ResolveSnapshotBuilder.add_vows(data, vow_outcome_in, newly_unlocked_in)
		ResolveSnapshotBuilder.add_effects(data, effects_in)
		ResolveSnapshotBuilder.add_progression(data, formula_inputs_in, relics_in, xp_events_in)
		ResolveSnapshotBuilder.add_combat_seams(data, 0, false, "")
		ResolveSnapshotBuilder.add_scout_intel(data, 2)
		ResolveSnapshotBuilder.add_contact_outcome(data, "elder", "Elder", "good", "The elder nods.")
		ResolveSnapshotBuilder.add_legacy_title(data, "Result")
		ResolveSnapshotBuilder.add_legacy_note(data, "Result unavailable.")
		built.append(JSON.stringify(snap, "", true))

	if built[0] != built[1]:
		mismatches.append("expected build1 == build2 (pure builder) but the payloads diverged — the builder is mutating something between calls")

	# The builder stores Arrays/Dictionaries by reference by design; it must never WRITE into them.
	if JSON.stringify(actors_in, "", true) != actors_before:
		mismatches.append("expected add_actors() to leave the caller's Array untouched")
	if JSON.stringify(vow_outcome_in, "", true) != vow_before:
		mismatches.append("expected add_vows() to leave the caller's Dictionary untouched")

	# Contract shape (AGENTS.md snapshot shape + FlowStateMachine._validate_snapshot):
	# meta must be a Dictionary carrying "t" — NOT "sim_tick". Producer C emitted sim_tick
	# before this slice and tripped assert(false) on every retreat / return-home.
	var probe: Dictionary = ResolveSnapshotBuilder.build(11, {}, "")
	if str(probe.get("type", "")) != FlowStateIds.RESOLVE:
		mismatches.append("expected build() type == flow.resolve")
	var probe_meta_v: Variant = probe.get("meta", {})
	if not (probe_meta_v is Dictionary and int((probe_meta_v as Dictionary).get("t", -1)) == 11):
		mismatches.append("expected build() meta == { t: <tick> }")
	if not (probe.get("actions", null) is Dictionary):
		mismatches.append("expected build() actions to be a slot-keyed Dictionary, never an Array")
	if (probe.get("data", {}) as Dictionary).has("run_type"):
		mismatches.append("expected an empty run_type to be OMITTED, not written as \"\" — A/B/F rely on the key being absent")

	if not mismatches.is_empty():
		return { "ok": false, "error": " | ".join(mismatches) }
	return { "ok": true }
