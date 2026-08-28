# res://core/state/flow/PendingResultService.gd
# V2-INFRA-003 Phase 8B — the DURABLE RUN RESULT.
#
# WHY THIS FILE EXISTS
# --------------------
# `save.flow.pending_result` has existed since the Phase 8 groundwork (SaveSchema.gd:31-46,
# repaired at SaveService.gd:515-532) and NOTHING read or wrote it. A run outcome lived only in
# `flow_ctx.last_snapshot` — in memory. Quit on the Resolve screen and the whole outcome was
# gone: the Ase was already banked (Phase 8A moved the stage payment to `flow.complete_stage`,
# so on a victory the stage was not even settled yet), but the card that told the player what
# happened, what the party felt, and which action advances the stage had evaporated. Continue
# put them back in the Sanctum with a half-finished realm and no explanation.
#
# The withdrawal half was worse. `encounter.retreat` and `stage.return_home` stored their whole
# result in two VOLATILE FlowContext ints — `pending_scout_return_ase` and
# `pending_scout_return_intel_count` (FlowContext.gd:123-124, explicitly "never persisted to
# save") — consumed one dispatch later by the closure at the end of `FlowRuntime.dispatch()`.
# A quit between the retreat and the tap on "Return to Sanctum" lost both.
#
# WHAT THIS FILE DOES
# -------------------
#   capture_or_consume()  ONE call, at the end of every dispatch, before the save flush.
#                         Publishing a `flow.resolve` snapshot that carries a run outcome
#                         WRITES the durable result. Publishing anything else CONSUMES it.
#   build_snapshot()      Producer G — rebuilds the resolve card from the durable result,
#                         composing through ResolveSnapshotBuilder's existing block library.
#
# FOUR OUTCOMES, ONE WRITER. victory / partial / defeat come from the combat resolve (producer
# A); withdrawal comes from the scout-return card (producer C, both of its call sites). They
# are classified from the PUBLISHED SNAPSHOT rather than from each handler, so there is exactly
# one writer and no handler had to grow a second responsibility. See classify().
#
# CONTRACT (the StageSettlementService / EmotionConsequenceService service contract):
#   - Typed RefCounted, static functions only. No autoloads, no service locator.
#   - No `flow_machine` reference — it cannot transition or refresh a snapshot.
#   - Never calls SaveService directly and never calls a controller. Saves are requested
#     through `flow_ctx.request_save(reason)`.
#   - No UI or scene-tree reference.
#
# PLACED IN core/state/flow/ beside FlowContext.gd and FlowStateIds.gd, because
# `save.flow.pending_result` is the FLOW domain's save subtree and the result spans venture,
# economy, emotion, vow and Thread data without belonging to any one of them. It is not in
# core/state/flow/states/venture/ with the six resolve producers: three of those producers
# (contact, situation, keeper trial) deliberately do NOT write a durable result, so this is not
# a venture-only concern.
#
# WHY THE CAPTURE SITE IS BEFORE THE SAVE FLUSH, NOT IN THE POST-PUBLISH CLOSURE
# -----------------------------------------------------------------------------
# The two established one-shot consumers — `pending_awakening_banner` (FlowRuntime.gd:653-656)
# and the scout-return pair (`:667-676`) — run AFTER the flush, because they only zero VOLATILE
# FlowContext fields and therefore request no save. This one writes SAVE DATA, so it must sit
# inside the dispatch's save boundary. A save queued after the flush is not written until the
# NEXT dispatch, and its reason string then joins that dispatch's reason with a vertical bar —
# `FlowContext.request_save()` accumulates pipe-joined (`:133-140`). The gate is otherwise
# identical to the two precedents: one call, gated on the type of the snapshot this dispatch
# published, reading `flow_ctx.last_snapshot`, which is exactly the value `dispatch()` is about
# to return.
#
# BOND AND THREAD — register D84, fixed.
# Both keys used to be empty: the three bond hooks and `RealmService.contribute_segment` ran in
# `VentureController.handle_complete_stage`, the dispatch AFTER the card is shown and the one
# that CONSUMES this result, so at capture time neither outcome existed anywhere in the process.
# The bond hooks are ENCOUNTER cadence and now run in `FlowRuntime._end_round()`, in the
# dispatch that publishes the card. The Thread segment is STAGE cadence — one entry per
# stage_index — so it is contributed there only on the fight that clears the stage, and
# `contribute_segment` carries a per-stage receipt so the later `flow.complete_stage` call
# cannot append a second one.

class_name PendingResultService
extends RefCounted

const RESULT_VERSION: int = 1

## The four run outcomes the schema documents (SaveSchema.gd:37).
const OUTCOME_VICTORY:    String = "victory"
const OUTCOME_DEFEAT:     String = "defeat"
const OUTCOME_PARTIAL:    String = "partial"
const OUTCOME_WITHDRAWAL: String = "withdrawal"

## `status` values the schema documents. Only pending_resolve is produced today —
## pending_return is reserved for a result the player must act on from the Sanctum, which no
## path creates. Writing a value nothing sets would be an invention.
const STATUS_PENDING_RESOLVE: String = "pending_resolve"

## `run_type` of the two resolve cards that are MID-STAGE incidents, not run outcomes. A
## contact conversation and an in-explore situation both return the player straight to
## flow.stage_explore and neither ends a venture, so neither writes a durable result.
const _NON_OUTCOME_RUN_TYPES: Array = ["contact_result", "situation_result"]

## `run_type` of the withdrawal card (producer C).
const _RUN_TYPE_SCOUT_RETURN: String = "scout_return"


# ---------------------------------------------------------------------------
# Store — read / write / clear
# ---------------------------------------------------------------------------

## The durable result, or {} when none is pending. Never constructs anything.
static func read(save_data: Dictionary) -> Dictionary:
	var flow_v: Variant = save_data.get("flow", {})
	if not (flow_v is Dictionary):
		return {}
	var pr_v: Variant = (flow_v as Dictionary).get("pending_result", {})
	return pr_v if pr_v is Dictionary else {}


static func has_pending(save_data: Dictionary) -> bool:
	return not read(save_data).is_empty()


## Restores the realm/stage context the pending result belongs to.
##
## WHY THIS IS NEEDED. `FlowRuntime.boot()` restores `realm_id` from the save (`:106-112`,
## "survives Continue") but has never restored `stage_id` — nothing needed it, because before
## this slice a run in progress could not be resumed at its Resolve card at all. It is needed
## now: the victory card's `cta.next_stage` dispatches `flow.complete_stage`, and both
## StageSettlementService and RealmService.advance_stage locate the stage through
## `flow_ctx.stage_id`. With it empty the settlement would return {} and the player would
## complete a stage they were never paid for.
##
## ONLY FILLS EMPTY FIELDS. A live FlowContext always wins — this must never overwrite the
## realm or stage of a session that is still running.
static func restore_run_context(flow_ctx: FlowContext) -> void:
	var result := read(flow_ctx.save_data)
	if result.is_empty():
		return
	if flow_ctx.realm_id.is_empty():
		flow_ctx.realm_id = str(result.get("realm_id", ""))
	if flow_ctx.stage_id.is_empty():
		flow_ctx.stage_id = str(result.get("stage_id", ""))


## The `save.flow` dict, created with the schema defaults when a legacy save lacks it.
## Mirrors SaveService's repair branch (SaveService.gd:519-526) rather than inventing a shape.
static func _flow_dict(save_data: Dictionary) -> Dictionary:
	var flow_v: Variant = save_data.get("flow", {})
	if flow_v is Dictionary:
		return flow_v
	var flow: Dictionary = {
		"state":          "flow.splash",
		"context":        {},
		"pending_result": {},
	}
	save_data["flow"] = flow
	return flow


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

## The run outcome a published flow.resolve snapshot represents, or "" when the snapshot is not
## a run outcome at all.
##
## Read off the snapshot, not off the handler, so all four outcomes have ONE writer:
##   run_type "scout_return"                      -> withdrawal   (producer C, both call sites)
##   run_type "contact_result"/"situation_result"  -> ""            (mid-stage card)
##   no run_type, no encounter_id                  -> ""            (producer F, see below)
##   no run_type, victory false                    -> defeat       (producer A)
##   no run_type, victory true, objectives left    -> partial      (producer A, stage unfinished)
##   no run_type, victory true, none left          -> victory      (producer A, stage clear)
##
## THE `encounter_id` TEST IS WHAT EXCLUDES PRODUCER F. The fallback scaffold
## (FlowResolveState.enter, step 3) emits `victory: false` and would otherwise classify as a
## defeat — but it is the card that says "Result unavailable.", reached only when a resolve was
## entered with no result to show. Making that durable would persist an error card as a real
## defeat, and Continue would then serve it back. F omits the combat-stats block, and producers
## A and B always call it (docs/resolve-snapshot-block-spec.md §4.3), so the presence of
## `encounter_id` is the exact, measured line between "a fight happened" and "we do not know".
##
## `objectives_remaining` is producer A's own routing input — it is what decides whether the
## card offers `cta.next_stage` (flow.complete_stage) or only a return to exploration
## (EncounterSnapshotBuilder._build_resolve_actions). Partial is therefore not a new concept
## invented here; it is the distinction the action set already draws, named.
static func classify(snapshot: Dictionary) -> String:
	if str(snapshot.get("type", "")) != FlowStateIds.RESOLVE:
		return ""
	var data_v: Variant = snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var run_type := str(data.get("run_type", ""))
	if run_type == _RUN_TYPE_SCOUT_RETURN:
		return OUTCOME_WITHDRAWAL
	if run_type in _NON_OUTCOME_RUN_TYPES:
		return ""
	if not run_type.is_empty():
		return ""
	if not data.has("encounter_id"):
		return ""
	if not bool(data.get("victory", false)):
		return OUTCOME_DEFEAT
	if int(data.get("objectives_remaining", 0)) > 0:
		return OUTCOME_PARTIAL
	return OUTCOME_VICTORY


# ---------------------------------------------------------------------------
# The single capture / consume call
# ---------------------------------------------------------------------------

## Called once per dispatch, from FlowRuntime.dispatch(), immediately before the save flush.
##
## `snapshot` is the snapshot this dispatch is about to publish (flow_ctx.last_snapshot).
## Returns "captured", "consumed" or "" so the caller can log one line without re-deriving it.
##
## FIRST WRITE WINS. While a result is pending, republishing the same resolve card (a refresh,
## a snapshot rebuild, a second validation pass) must not re-stamp it — `created_t` and
## `result_id` identify the moment the run ended, and a re-stamp would move them every time the
## screen redrew. This is the same shape as StageSettlementService's `settled` receipt.
##
## GATED ON A REALM. A durable run result belongs to a realm run. The keeper-intro trial sets
## `flow_ctx.realm_id = ""` (KeeperIntroService.gd:318) and so does the fallback scaffold's
## situation, which is what keeps producer B and the onboarding path out of this entirely —
## no save write, no routing change, nothing moved in the onboarding suites.
static func capture_or_consume(flow_ctx: FlowContext, snapshot: Dictionary, t: int) -> String:
	var outcome := classify(snapshot)

	if outcome.is_empty():
		# Not a run-outcome snapshot. If one is pending, the player has left the Resolve
		# screen and the result is spent. This is the one-shot consumption, gated on the
		# published snapshot's type exactly like the pending_awakening_banner precedent.
		if not has_pending(flow_ctx.save_data):
			return ""
		_flow_dict(flow_ctx.save_data)["pending_result"] = {}
		flow_ctx.request_save("flow.pending_result.consumed")
		if flow_ctx.logger != null:
			flow_ctx.logger.info(t, "flow.pending_result.consumed", "Pending result consumed", {
				"published_type": str(snapshot.get("type", "")),
			})
		return "consumed"

	if flow_ctx.realm_id.is_empty():
		return ""
	if has_pending(flow_ctx.save_data):
		return ""

	_flow_dict(flow_ctx.save_data)["pending_result"] = _build_result(flow_ctx, snapshot, outcome, t)
	flow_ctx.request_save("flow.pending_result")
	if flow_ctx.logger != null:
		flow_ctx.logger.info(t, "flow.pending_result.captured", "Run result made durable", {
			"outcome":  outcome,
			"realm_id": flow_ctx.realm_id,
			"stage_id": flow_ctx.stage_id,
		})
	return "captured"


# ---------------------------------------------------------------------------
# The result payload
# ---------------------------------------------------------------------------

## Builds the durable result from the published snapshot plus the FlowContext that produced it.
## Every value is copied, never referenced: the snapshot's dictionaries stay live in
## flow_ctx.last_snapshot and later dispatches mutate some of them (the roster emotion
## write-back, the objective marks). A durable record of what happened must not move afterwards.
static func _build_result(
	flow_ctx: FlowContext,
	snapshot: Dictionary,
	outcome: String,
	t: int
) -> Dictionary:
	var data_v: Variant = snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actions_v: Variant = snapshot.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}

	var realm_model: Dictionary = RealmService.get_active(flow_ctx)
	var stage_index := _stage_index(flow_ctx.stage_id)
	var run_type := str(data.get("run_type", ""))

	var segments_v: Variant = realm_model.get("realm_recovery_segments", [])
	var segments: Array = segments_v if segments_v is Array else []

	return {
		"version":   RESULT_VERSION,
		"result_id": "%s.%s.%s.%d" % [flow_ctx.realm_id, flow_ctx.stage_id, outcome, t],
		"status":    STATUS_PENDING_RESOLVE,
		# The producer that made the card: its run_type, or "combat" for the three producers
		# that emit none and fall through to ResolveScreen's combat renderer.
		"source":    run_type if not run_type.is_empty() else "combat",
		"outcome":   outcome,
		"created_t": t,

		"realm_id":        flow_ctx.realm_id,
		"realm_run_count": int(realm_model.get("run_count", 0)),
		"stage_id":        flow_ctx.stage_id,
		"stage_index":     stage_index,
		"encounter_id":    str(data.get("encounter_id", "")),
		"objective_index": flow_ctx.active_encounter_objective_index,

		# stage_complete is the routing fact the Resolve card already encodes: only a victory
		# with no required objective left offers cta.next_stage (flow.complete_stage).
		"stage_complete":       outcome == OUTCOME_VICTORY,
		"objectives_remaining": int(data.get("objectives_remaining", 0)),

		# INTEL — the withdrawal card's payload. 0 on every combat resolve, which is the
		# measured shape: producer A emits no intel_count key at all.
		"intel": {
			"intel_count": int(data.get("intel_count", 0)),
		},

		# ECONOMY — what this ENCOUNTER paid. On a victory the STAGE payment has deliberately
		# not happened yet: Phase 8A moved it to the flow.complete_stage dispatch, which is the
		# dispatch this result routes the player back to. So a quit here loses no money, and
		# the figures below are the ones the card showed.
		"economy": {
			"ase_awarded":      int(data.get("ase_awarded", 0)),
			"ekwan_awarded":    int(data.get("ekwan_awarded", 0)),
			"reward_breakdown": _copy_array(data.get("reward_breakdown", [])),
			"rank":             str(data.get("rank", "")),
		},

		# PROGRESSION — formula_inputs is display only (the stage formula the player is about
		# to be paid by); xp_events is empty on the combat card since Phase 8A moved the
		# stage-clear Storyweight to the settlement, and is copied rather than assumed empty.
		"progression": {
			"formula_inputs": _copy_dict(data.get("formula_inputs", {})),
			"relics":         _copy_array(data.get("relics", [])),
			"xp_events":      _copy_array(data.get("xp_events", [])),
		},

		# EMOTION — the per-echo arc the card rendered.
		"emotion_summary": _copy_array(data.get("emotion_summary", [])),

		# BOND — what this fight did to the party's bonds. The three hooks now run in
		# FlowRuntime._end_round(), in the dispatch that publishes this card, and leave their
		# summary on flow_ctx.bond_outcome for this read. Empty on a withdrawal: a retreat is
		# not a fought encounter and fires no bond hook.
		"bond_outcome": {} if outcome == OUTCOME_WITHDRAWAL else _copy_dict(flow_ctx.bond_outcome),

		# VOW — the break/benefit/compliance outcome and the vows discovered this run. Both are
		# real at capture time: VowConsequenceService writes them during the encounter and, on
		# the withdrawal path, before the scout-return card is built.
		"vow_outcome": {
			"outcome":             _copy_dict(data.get("vow_outcome", {})),
			"newly_unlocked_vows": _copy_array(data.get("newly_unlocked_vows", [])),
		},

		# THREAD — the realm's recovery track including this run's own segment. On the fight
		# that clears a stage, _end_round() contributes the segment before this capture, so
		# `segment` names what this run added and `segments` counts it. Empty on a partial or a
		# defeat, which clear no stage and contribute nothing.
		#
		# `threads_earned` still fills only when a later flow.complete_stage completes the
		# realm: crystallization is realm cadence and needs RealmService.advance_stage.
		"thread_outcome": {
			"realm_id":       flow_ctx.realm_id,
			"segments":       segments.size(),
			"segment":        _segment_for_stage(segments, stage_index),
			"threads_earned": _copy_array(flow_ctx.last_realm_threads_earned),
		},

		# The card itself. resolve_data + next_action are what producer G replays; every other
		# field above is the durable RECORD, readable without reconstructing a snapshot.
		"resolve_data": _copy_dict(data),
		"next_action":  _copy_dict(actions),
	}


## The recovery segment recorded for `stage_index`, or {} when this run contributed none.
## The track holds at most one entry per stage (RealmService.contribute_segment's receipt).
static func _segment_for_stage(segments: Array, stage_index: int) -> Dictionary:
	for seg_v in segments:
		if seg_v is Dictionary and int((seg_v as Dictionary).get("stage_index", -1)) == stage_index:
			return (seg_v as Dictionary).duplicate(true)
	return {}


static func _copy_dict(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


static func _copy_array(v: Variant) -> Array:
	return (v as Array).duplicate(true) if v is Array else []


## Zero-based index of the stage named by a stage_id ("stage.N", or "realm.x.stage.N").
## Same derivation as StageSettlementService._stage_index() and producer A's inline copy.
static func _stage_index(stage_id: String) -> int:
	if stage_id.contains("."):
		var parts := stage_id.split(".")
		return int(parts[parts.size() - 1])
	return 0


# ---------------------------------------------------------------------------
# Producer G — the resolve card, rebuilt from the durable result
# ---------------------------------------------------------------------------

## The seventh flow.resolve producer (docs/resolve-snapshot-block-spec.md names A–F).
##
## It composes through ResolveSnapshotBuilder's SEVENTEEN-BLOCK LIBRARY, which needed no edit
## to accept it — the same claim the spec made for producers A and B (§5) and the same way it
## held. G is unusual only in that it does not know in advance which producer's card it is
## replaying, so it calls each block if and only if the stored payload carries that block's
## keys. That is the composition model working as designed: a block is all-or-nothing per
## producer, so key presence IS the block list.
##
## PURE, and pure in the builder's strong sense: no save write, no FlowContext mutation, no
## request_save(), no service constructed. It reads flow_ctx only to reach save_data, exactly
## as VentureResolveSnapshotBuilder.build_scout_return_snapshot() does.
##
## `meta.t` is the CURRENT tick, not the stored `created_t`. The snapshot contract requires
## meta.t to be this dispatch's tick (FlowStateMachine._validate_snapshot asserts on a missing
## t), and `created_t` is preserved inside the durable result for anything that needs the
## original moment.
##
## Returns {} when nothing is pending, so the caller can fall through.
static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	var result := read(flow_ctx.save_data)
	if result.is_empty():
		return {}

	var stored := _copy_dict(result.get("resolve_data", {}))
	var actions := _copy_dict(result.get("next_action", {}))
	if actions.is_empty():
		# A stored card with no actions would strand the player. The fallback is producer F's
		# own action set, which is the one every resolve card can always honour.
		actions = {
			"cta.continue": {
				"type":  "flow.go_state",
				"to":    FlowStateIds.SANCTUM,
				"label": "Return to Sanctum",
				"slot":  "cta.continue",
			},
		}

	var snap: Dictionary = ResolveSnapshotBuilder.build(t, actions, str(stored.get("run_type", "")))
	var data: Dictionary = snap["data"]

	# Blocks 1–17, in the spec's numbering. Each gated on the key(s) that block writes.
	if stored.has("surface"):
		ResolveSnapshotBuilder.add_banner(data, str(stored.get("surface", "")), str(stored.get("summary_line", "")))
	if stored.has("victory"):
		ResolveSnapshotBuilder.add_victory_flag(data, bool(stored.get("victory", false)))
	if stored.has("rank"):
		ResolveSnapshotBuilder.add_grade_rank(data, str(stored.get("rank", "")))
	if stored.has("verdict"):
		ResolveSnapshotBuilder.add_grade_verdict(data, str(stored.get("verdict", "")))
	if stored.has("encounter_id"):
		ResolveSnapshotBuilder.add_combat_stats(
			data,
			str(stored.get("encounter_id", "")),
			str(stored.get("reason", "")),
			int(stored.get("round_ended", 0)),
			int(stored.get("enemies_defeated", 0)),
			int(stored.get("echoes_survived", 0)),
			_copy_dict(stored.get("objective_state", {}))
		)
	if stored.has("actors"):
		ResolveSnapshotBuilder.add_actors(data, _copy_array(stored.get("actors", [])))
	if stored.has("ase_awarded"):
		ResolveSnapshotBuilder.add_ledger(
			data,
			int(stored.get("ase_awarded", 0)),
			_copy_array(stored.get("reward_breakdown", []))
		)
	if stored.has("ekwan_awarded"):
		ResolveSnapshotBuilder.add_ekwan(data, int(stored.get("ekwan_awarded", 0)))
	if stored.has("emotion_summary"):
		ResolveSnapshotBuilder.add_emotion(data, _copy_array(stored.get("emotion_summary", [])))
	if stored.has("vow_outcome"):
		ResolveSnapshotBuilder.add_vows(
			data,
			_copy_dict(stored.get("vow_outcome", {})),
			_copy_array(stored.get("newly_unlocked_vows", []))
		)
	if stored.has("effects"):
		ResolveSnapshotBuilder.add_effects(data, _copy_array(stored.get("effects", [])))
	if stored.has("formula_inputs"):
		ResolveSnapshotBuilder.add_progression(
			data,
			_copy_dict(stored.get("formula_inputs", {})),
			_copy_array(stored.get("relics", [])),
			_copy_array(stored.get("xp_events", []))
		)
	if stored.has("objectives_remaining"):
		ResolveSnapshotBuilder.add_combat_seams(
			data,
			int(stored.get("objectives_remaining", 0)),
			bool(stored.get("guide_spirit_protected", false)),
			str(stored.get("combat_intro_line", ""))
		)
	if stored.has("intel_count"):
		ResolveSnapshotBuilder.add_scout_intel(data, int(stored.get("intel_count", 0)))
	if stored.has("role"):
		ResolveSnapshotBuilder.add_contact_outcome(
			data,
			str(stored.get("role", "")),
			str(stored.get("role_label", "")),
			str(stored.get("outcome", "")),
			str(stored.get("outcome_text", ""))
		)

	return snap
