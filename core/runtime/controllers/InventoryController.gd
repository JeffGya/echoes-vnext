# res://core/runtime/controllers/InventoryController.gd
# V2-ITEM-001a step 5: the Sanctum inventory actions. Same contract as WeaveController: typed
# RefCounted, explicit dependencies, no flow_machine, never calls another controller, never calls
# SaveService (save intent goes on the returned FlowActionOutcome and FlowRuntime.dispatch() applies it).
#
# Owns 1 action: inventory.discard.apply, payload { item_id: String }.
#   - Allowed only while the last snapshot is flow.sanctum (the party is in the Sanctum; the path may still be open,
#     see path_open below).
#   - Success: the piece leaves `inventory.items` or `inventory.pack`, held pieces move in while room
#     exists, one save request ("inventory.discard"), and a reenter so the Sanctum snapshot is rebuilt.
#   - Refusal: nothing changes. The outcome carries the reason key in `error_code`. No save, no snapshot.
#   - Refusal keys (InventoryService.discard): not_in_sanctum, not_unique, not_found, equipped, bad_state.
#     The controller adds bad_payload (item_id missing or not a String) and path_open
#     (`ActiveStageService.discard_block_reason`: an open item row anywhere in the save, or an entered,
#     unsettled path whose pack holds a piece; a discard then would dodge the early-leave draw).

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
	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var id_v: Variant = payload.get("item_id", null)
	if not (id_v is String) or (id_v as String).is_empty():
		logger.info(t, "inventory.discard.denied", "Discard denied", { "reason_key": "bad_payload" })
		return FlowActionOutcome.error_outcome("bad_payload")

	var in_sanctum := str(flow_ctx.last_snapshot.get("type", "")) == FlowStateIds.SANCTUM
	var blocked := ActiveStageService.discard_block_reason(flow_ctx) if in_sanctum else ""
	if not blocked.is_empty():
		logger.info(t, "inventory.discard.denied", "Discard denied", { "reason_key": blocked, "item_id": id_v })
		return FlowActionOutcome.error_outcome(blocked)
	var cfg := ConfigService.get_inventory_cfg(config_service)
	var res := InventoryService.discard(flow_ctx.save_data, cfg, id_v as String, in_sanctum, logger, t)
	if str(res["result"]) != "discarded":
		logger.info(t, "inventory.discard.denied", "Discard denied", {
			"reason_key": str(res["reason_key"]), "item_id": id_v })
		return FlowActionOutcome.error_outcome(str(res["reason_key"]))
	return FlowActionOutcome.reenter_outcome().with_save_reason("inventory.discard")
