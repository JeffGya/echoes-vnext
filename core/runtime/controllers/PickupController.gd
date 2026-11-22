# res://core/runtime/controllers/PickupController.gd
# The pickup event actions (V2-ITEM-001b, D-25, D-27, D-45, D-58). Same contract as InventoryController: typed
# RefCounted, explicit dependencies, never calls another controller, never calls SaveService. Where a swap is
# legal is owned by `PickupSwapRules`; the swap write is owned by `PickupEventService.commit_swap`; what the
# player sees is owned by `PickupSnapshotBuilder`.
#
# The session { phase, swap_origin, swap_target, selected } lives in `FlowContext.pickup_session` and is never
# saved. Every action is refused (nothing changes, one log line `inventory.pickup.denied`, error_code = the
# reason key) when no event is open ("no_event"), the live snapshot is not `flow.pickup` ("not_pickup") or the event has ended ("ended").
# `commit_swap` trusts its caller, so the phase checks here are the only guard against a swap outside the event.
# The phase is read from the built snapshot, not the raw session: the builder already falls back to idle for a
# swap phase the record cannot support.
#
# pickup.skip          intro -> idle. Clears `selected` (the mockup's skipIntro closes the details).
# pickup.select        { find_id | pack_id }, intro or idle. A hidden find is not selectable (D-45). Both ids empty
#                      or absent closes the details (clears `selected`).
# pickup.swap.start    idle. Needs the swap offered and a selected item with a legal partner. Clears `selected`.
#                      A taken find selected by find_id starts from its pack id (`item:<situation_id>:<find_id>`).
# pickup.swap.pick     { id }, swap_pick -> swap_preview. The id must be a legal partner of the origin.
# pickup.swap.confirm  swap_preview. Commits the one swap, back to idle. The save request is made inside
#                      `commit_swap` through `flow_ctx.request_save`, not on the outcome.
# pickup.swap.cancel   swap_pick or swap_preview -> idle (the mockup's Cancel and Back are the same step).
# pickup.continue      idle. Ends the event through `finish` (durable end mark) and publishes the held Resolve card
#                      with `data.pickup_result`: live from `ectx.final_snapshot`, after a reload from the pending
#                      result. The result is also attached to the pending result, so a reload on Resolve shows it.
# Refusal keys: no_event, ended, not_pickup, bad_payload, wrong_phase, not_selectable, no_target, not_partner,
# bad_pair, plus the `PickupSwapRules` keys (swap not offered or refused at commit).

class_name PickupController
extends RefCounted

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


func handle_skip(action: Dictionary, t: int) -> FlowActionOutcome:
	var gate := _gate()
	if not gate.is_empty():
		return _deny(action, gate, t)
	if _phase(t) != PickupSnapshotBuilder.PHASE_INTRO:
		return _deny(action, "wrong_phase", t)
	_set_session(PickupSnapshotBuilder.PHASE_IDLE, "", "", "")
	return _published(t)


func handle_select(action: Dictionary, t: int) -> FlowActionOutcome:
	var gate := _gate()
	if not gate.is_empty():
		return _deny(action, gate, t)
	var p := _payload(action)
	var find_v: Variant = p.get("find_id", "")
	var pack_v: Variant = p.get("pack_id", "")
	if not (find_v is String) or not (pack_v is String) or (not (find_v as String).is_empty() and not (pack_v as String).is_empty()):
		return _deny(action, "bad_payload", t)
	var by_find := not (find_v as String).is_empty()
	var id: String = find_v if by_find else pack_v
	var phase := _phase(t)
	if phase != PickupSnapshotBuilder.PHASE_INTRO and phase != PickupSnapshotBuilder.PHASE_IDLE:
		return _deny(action, "wrong_phase", t)
	if id.is_empty():
		_set_session(phase, "", "", "")
		return _published(t)
	var probe := flow_ctx.pickup_session.duplicate()
	probe["selected"] = id
	var shown: Dictionary = PickupSnapshotBuilder.build(flow_ctx, t, probe)["data"]["selected"]
	if shown.is_empty() or str(shown["id"]) != id or str(shown["side"]) != ("find" if by_find else "pack"):
		return _deny(action, "not_selectable", t)
	_set_session(phase, "", "", id)
	return _published(t)


func handle_swap_start(action: Dictionary, t: int) -> FlowActionOutcome:
	var gate := _gate()
	if not gate.is_empty():
		return _deny(action, gate, t)
	var data := _data(t)
	if str(data["phase"]) != PickupSnapshotBuilder.PHASE_IDLE:
		return _deny(action, "wrong_phase", t)
	var swap: Dictionary = data["swap"]
	if not bool(swap["offered"]):
		return _deny(action, str(swap["reason_key"]), t)
	var selected: Dictionary = data["selected"]
	if selected.is_empty():
		return _deny(action, "not_selectable", t)
	var origin := str(selected["id"])
	if str(selected["side"]) == "find":
		# A taken find is in the pack: the swap rules know it by its pack id.
		var record := PickupEventService.record_of(FlowStageExploreState._get_current_stage(flow_ctx))
		if (record.get("taken", []) as Array).has(origin):
			origin = EarningsService.item_id(str(record.get("situation_id", "")), origin)
	var legal: Array = (swap["targets"] as Dictionary).get(origin, [])
	if legal.is_empty():
		return _deny(action, "no_target", t)
	_set_session(PickupSnapshotBuilder.PHASE_SWAP_PICK, origin, "", "")
	return _published(t)


func handle_swap_pick(action: Dictionary, t: int) -> FlowActionOutcome:
	var gate := _gate()
	if not gate.is_empty():
		return _deny(action, gate, t)
	var id_v: Variant = _payload(action).get("id", "")
	if not (id_v is String) or (id_v as String).is_empty():
		return _deny(action, "bad_payload", t)
	var id: String = id_v
	var data := _data(t)
	if str(data["phase"]) != PickupSnapshotBuilder.PHASE_SWAP_PICK:
		return _deny(action, "wrong_phase", t)
	var swap: Dictionary = data["swap"]
	var legal: Array = (swap["targets"] as Dictionary).get(str(swap["origin"]), [])
	if not legal.has(id):
		return _deny(action, "not_partner", t)
	_set_session(PickupSnapshotBuilder.PHASE_SWAP_PREVIEW, str(swap["origin"]), id, "")
	return _published(t)


func handle_swap_confirm(action: Dictionary, t: int) -> FlowActionOutcome:
	var gate := _gate()
	if not gate.is_empty():
		return _deny(action, gate, t)
	var data := _data(t)
	if str(data["phase"]) != PickupSnapshotBuilder.PHASE_SWAP_PREVIEW:
		return _deny(action, "wrong_phase", t)
	var swap: Dictionary = data["swap"]
	var origin := str(swap["origin"])
	var target := str(swap["target"])
	var field_ids: Array = (data["finds"] as Array).map(func(f: Dictionary) -> String: return str(f["find_id"]))
	var find_id := origin if field_ids.has(origin) else target
	var pack_id := target if find_id == origin else origin
	if not field_ids.has(find_id) or field_ids.has(pack_id):
		return _deny(action, "bad_pair", t)
	var res := PickupEventService.commit_swap(flow_ctx, find_id, pack_id, t)
	if not bool(res["ok"]):
		return _deny(action, str(res["reason_key"]), t)
	_set_session(PickupSnapshotBuilder.PHASE_IDLE, "", "", "")
	return _published(t)


func handle_swap_cancel(action: Dictionary, t: int) -> FlowActionOutcome:
	var gate := _gate()
	if not gate.is_empty():
		return _deny(action, gate, t)
	var phase := _phase(t)
	if phase != PickupSnapshotBuilder.PHASE_SWAP_PICK and phase != PickupSnapshotBuilder.PHASE_SWAP_PREVIEW:
		return _deny(action, "wrong_phase", t)
	_set_session(PickupSnapshotBuilder.PHASE_IDLE, "", "", "")
	return _published(t)


## Only idle ends the event. The final items, and on a stage-clearing card the stage payout and `items` blocks,
## are read AFTER any swap, so the card shows what the party carries.
## A debug "event now" record (`debug_event`) has no fight behind it: a plain win card with the final items is built
## and the machine moves to RESOLVE, so the card's own Continue (`flow.go_state`) is not a no-op on the path view.
## With no held card (no fight behind the event and no pending result) it publishes nothing.
func handle_continue(action: Dictionary, t: int) -> FlowActionOutcome:
	var gate := _gate()
	if not gate.is_empty():
		return _deny(action, gate, t)
	if _phase(t) != PickupSnapshotBuilder.PHASE_IDLE:
		return _deny(action, "wrong_phase", t)
	var record := PickupEventService.record_of(FlowStageExploreState._get_current_stage(flow_ctx))
	var pickup_result := PickupSnapshotBuilder.result_of(record)
	finish(t)
	if bool(record.get("debug_event", false)):
		return _event_now_card(record, pickup_result, t)
	PendingResultService.attach_pickup_result(flow_ctx, int(record.get("win_t", -1)), pickup_result)
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var resolve: Dictionary = {}
	if ectx != null and not ectx.final_snapshot.is_empty():
		resolve = ectx.final_snapshot.duplicate(true)
		(resolve["meta"] as Dictionary)["t"] = t
		ResolveSnapshotBuilder.add_pickup_result(resolve["data"], pickup_result)
		StageSettlementService.refresh_card(flow_ctx, resolve["data"])
	else:
		resolve = PendingResultService.build_snapshot(flow_ctx, t)
	if resolve.is_empty():
		return FlowActionOutcome.handled_outcome()
	return FlowActionOutcome.snapshot_outcome(resolve)


## The Continue of this card runs the real stage-entry steps (vow stage entry, explore session reset), as after a
## won fight. That is the cost of going back through RESOLVE; it is not a bug of the debug scene.
func _event_now_card(record: Dictionary, pickup_result: Dictionary, t: int) -> FlowActionOutcome:
	var actions := { "cta.continue": { "type": "flow.go_state", "to": str(record.get("return_to", FlowStateIds.STAGE_EXPLORE)),
		"label": "Back to the path", "slot": "cta.continue" } }
	var card := ResolveSnapshotBuilder.build(t, actions)
	ResolveSnapshotBuilder.add_victory_flag(card["data"], true)
	ResolveSnapshotBuilder.add_grade_rank(card["data"], str(record.get("rank", "")))
	ResolveSnapshotBuilder.add_pickup_result(card["data"], pickup_result)
	var outcome := FlowActionOutcome.snapshot_outcome(card)
	outcome.transition_to = FlowStateIds.RESOLVE
	outcome.transition_reason = "debug.pickup.event_now"
	return outcome


## Ends the event: writes the durable end mark (`phase` "done"), requests a save, clears the session and returns
## what the caller needs to route on.
func finish(t: int) -> Dictionary:
	var record := PickupEventService.record_of(FlowStageExploreState._get_current_stage(flow_ctx))
	var result := { "situation_id": str(record.get("situation_id", "")), "run_count": int(record.get("run_count", 0)),
		"return_to": str(record.get("return_to", "")), "swap_used": not (record.get("swap", {}) as Dictionary).is_empty() }
	if not record.is_empty():
		record["phase"] = PickupEventService.PHASE_DONE
		flow_ctx.request_save("inventory.pickup.finish")
	flow_ctx.pickup_session = {}
	logger.info(t, "inventory.pickup.finish", "Pickup event finished", result)
	return result


## "" when the event is open and the live snapshot is the pickup one, else the refusal key.
func _gate() -> String:
	var record := PickupEventService.record_of(FlowStageExploreState._get_current_stage(flow_ctx))
	if record.is_empty():
		return "no_event"
	if PickupEventService.is_ended(record):
		return "ended"
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.PICKUP:
		return "not_pickup"
	return ""


func _data(t: int) -> Dictionary:
	return PickupSnapshotBuilder.build(flow_ctx, t, flow_ctx.pickup_session)["data"]


func _phase(t: int) -> String:
	return str(_data(t)["phase"])


func _set_session(phase: String, origin: String, target: String, selected: String) -> void:
	flow_ctx.pickup_session = { "phase": phase, "swap_origin": origin, "swap_target": target, "selected": selected }


## Same session, same record: `situation_id` and `run_count` do not change, so the UI keeps its intro state.
func _published(t: int) -> FlowActionOutcome:
	return FlowActionOutcome.snapshot_outcome(PickupSnapshotBuilder.build(flow_ctx, t, flow_ctx.pickup_session))


func _deny(action: Dictionary, reason: String, t: int) -> FlowActionOutcome:
	logger.info(t, "inventory.pickup.denied", "Pickup action denied", {
		"action": str(action.get("type", "")), "reason_key": reason })
	return FlowActionOutcome.error_outcome(reason)


static func _payload(action: Dictionary) -> Dictionary:
	var v: Variant = action.get("payload", {})
	return v if v is Dictionary else {}
