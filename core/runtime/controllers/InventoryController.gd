# res://core/runtime/controllers/InventoryController.gd
# The inventory actions. Same contract as WeaveController: typed RefCounted, explicit dependencies, no
# flow_machine, never calls another controller, never calls SaveService (save intent goes on the returned
# FlowActionOutcome and FlowRuntime.dispatch() applies it). Where an action is allowed is owned by
# `InventoryRules`; the container work is owned by `InventoryService`.
#
# Owns 2 actions. An entry is addressed by container and slot: `from` ("sanctum"|"pack") and `slot` (int).
# A piece may also be addressed by `item_id` in a discard.
#
# inventory.discard.apply  payload { item_id } or { from, slot }, plus optional { count }.
#   - Sanctum or party prep screen (also while a saved path is live, D-40): free, any entry, either container.
#     A stack takes `count` (1 to its quantity; absent = the whole stack); a smaller count keeps the slot. A
#     piece takes no count. The one-discard mark is neither read nor written there.
#   - Path view (`flow.stage_explore`): ONE discard per path, on a pack entry only. A stack discard counts as the
#     one. The mark is saved on the stage record.
#   - `item_id` wins over `from`/`slot` when both are sent.
#   - Refusal keys: not_in_sanctum, not_in_pack, path_used, no_stage (rules); bad_payload (controller);
#     not_found, not_unique, unknown_entry, count_range, equipped, bad_box, bad_state (service).
# inventory.move.apply     payload { from, slot, to, to_slot? }.
#   - Moves, reorders into an empty slot, or merges onto a same-type stack. `to_slot` absent = lowest free slot.
#   - Sanctum or party prep screen, whatever the saved path. Refused in the path view. Refusal keys:
#     not_in_sanctum, path_open (rules); bad_payload
#     (controller); unknown_entry, bad_slot, no_change, slot_taken, type_mismatch, stack_limit, container_full,
#     bad_box, bad_state (service).
# A refusal changes nothing: the outcome carries the reason key in `error_code`; no save, no snapshot.
# A success rebuilds the snapshot of the screen it came from and requests one save.

class_name InventoryController
extends RefCounted

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


func handle_discard(action: Dictionary, t: int) -> FlowActionOutcome:
	var p := _payload(action)
	var count_v: Variant = _whole(p.get("count", -1))
	var id_v: Variant = p.get("item_id", null)
	var by_id := p.has("item_id")
	var slot_v: Variant = _whole(p.get("slot", null))
	var box_v: Variant = p.get("from", null)
	if count_v == null or (by_id and (not (id_v is String) or (id_v as String).is_empty())) \
			or (not by_id and (slot_v == null or int(slot_v) < 0 or not (box_v is String))):
		return _deny("inventory.discard.denied", "bad_payload", t)
	if InventoryRules.mode(flow_ctx) == InventoryRules.MODE_NONE:
		return _deny("inventory.discard.denied", "not_in_sanctum", t)
	var save := flow_ctx.save_data
	var cfg := ConfigService.get_inventory_cfg(config_service)
	var box := str(box_v)
	var slot := -1
	if by_id:
		var at := InventoryService.locate_piece(save, id_v as String)
		if at.is_empty():
			# No such piece: the service names the reason (not_found, or not_unique for a stack type id).
			var res := InventoryService.discard(save, cfg, id_v as String, true, logger, t)
			return _deny("inventory.discard.denied", str(res["reason_key"]), t, { "item_id": id_v })
		box = str(at["box"])
		slot = int(at["slot"])
	else:
		slot = int(slot_v)
		if not InventoryService.BOXES.has(box):
			return _deny("inventory.discard.denied", "bad_box", t)
		if InventoryService.entry_at(save, box, slot).is_empty():
			return _deny("inventory.discard.denied", "unknown_entry", t, { "box": box, "slot": slot })
	var blocked := InventoryRules.discard_block_reason(flow_ctx, box)
	if not blocked.is_empty():
		return _deny("inventory.discard.denied", blocked, t, { "box": box, "slot": slot })
	var on_path := InventoryRules.mode(flow_ctx) == InventoryRules.MODE_PATH
	var res2 := InventoryService.discard_entry(save, cfg, box, slot, int(count_v), logger, t)
	if str(res2["result"]) != "discarded":
		return _deny("inventory.discard.denied", str(res2["reason_key"]), t, { "box": box, "slot": slot })
	if on_path:
		InventoryRules.mark_discard_used(flow_ctx)
	return _rebuilt(t).with_save_reason("inventory.discard")


func handle_move(action: Dictionary, t: int) -> FlowActionOutcome:
	var p := _payload(action)
	var slot_v: Variant = _whole(p.get("slot", null))
	var to_slot_v: Variant = _whole(p.get("to_slot", -1))
	var from_v: Variant = p.get("from", null)
	var to_v: Variant = p.get("to", null)
	if slot_v == null or int(slot_v) < 0 or to_slot_v == null or not (from_v is String) or not (to_v is String):
		return _deny("inventory.move.denied", "bad_payload", t)
	var blocked := InventoryRules.move_block_reason(flow_ctx)
	if not blocked.is_empty():
		return _deny("inventory.move.denied", blocked, t)
	var res := InventoryService.move_entry(flow_ctx.save_data, ConfigService.get_inventory_cfg(config_service),
		from_v as String, int(slot_v), to_v as String, int(to_slot_v), logger, t,
		EarningsService.open_item_rows_in_save(flow_ctx.save_data))
	if str(res["result"]) == "refused":
		return _deny("inventory.move.denied", str(res["reason_key"]), t,
			{ "from": from_v, "slot": slot_v, "to": to_v, "to_slot": to_slot_v })
	return _rebuilt(t).with_save_reason("inventory.move")


## The snapshot of the screen the action came from, rebuilt. The Sanctum re-enters; party prep and the path view
## rebuild in place (re-entering the path view would wipe its session state).
func _rebuilt(t: int) -> FlowActionOutcome:
	match str(flow_ctx.last_snapshot.get("type", "")):
		FlowStateIds.SANCTUM:
			return FlowActionOutcome.reenter_outcome()
		FlowStateIds.ECHO_PARTY:
			return FlowActionOutcome.snapshot_outcome(FlowEchoPartyState.build_snapshot(flow_ctx, t))
		FlowStateIds.STAGE_EXPLORE:
			return FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t))
	return FlowActionOutcome.handled_outcome()


func _deny(log_type: String, reason: String, t: int, extra: Dictionary = {}) -> FlowActionOutcome:
	var data := extra.duplicate()
	data["reason_key"] = reason
	logger.info(t, log_type, "Inventory action denied", data)
	return FlowActionOutcome.error_outcome(reason)


static func _payload(action: Dictionary) -> Dictionary:
	var v: Variant = action.get("payload", {})
	return v if v is Dictionary else {}


## An int from an int or a whole float (a JSON round trip), else null.
static func _whole(v: Variant) -> Variant:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v) and absf(v) < 1.0e9:
		return int(v)
	return null
