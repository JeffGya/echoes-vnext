class_name InventoryRules
extends RefCounted

## Where the inventory actions are allowed, and what the inventory snapshot says about a path.
## Pure statics on a FlowContext; the only write is the saved one-discard-per-path mark on the stage record.
##
## Mode of an action, from the screen (the last snapshot type), never from the saved path:
##   `flow.sanctum`, `flow.echo_party`: MODE_SANCTUM, also when a saved path is still live (the encounter Back
##     route, Continue into a live path). Moves and discards are free and the one-discard mark is not spent.
##   `flow.stage_explore` (the path view): MODE_PATH.   Any other type: MODE_NONE.
## MODE_PATH: no move; one discard per path, on a pack entry only.
## The one-discard mark is `stage.discard_used` (absent = not used), on the active Realm's current stage
## (`current_stage_index`, read from saved state). The path ends clear it: a successful leave, a defeat and the
## path-end settlement.

const MODE_NONE := ""
const MODE_SANCTUM := "sanctum"
const MODE_PATH := "path"
const STAGE_KEY := "discard_used"


## The stage record of the active Realm at `current_stage_index` (the live Dictionary), or {}.
static func saved_stage(ctx: FlowContext) -> Dictionary:
	var realm_model := RealmService.get_active(ctx)
	return FlowStageExploreState.stage_by_index(realm_model, int(realm_model.get("current_stage_index", 0)))


static func mode(ctx: FlowContext) -> String:
	var type := str(ctx.last_snapshot.get("type", ""))
	if type == FlowStateIds.STAGE_EXPLORE:
		return MODE_PATH
	if type == FlowStateIds.SANCTUM or type == FlowStateIds.ECHO_PARTY:
		return MODE_SANCTUM
	return MODE_NONE


## "" when a move is allowed, else `not_in_sanctum` (wrong screen) or `path_open`.
static func move_block_reason(ctx: FlowContext) -> String:
	match mode(ctx):
		MODE_SANCTUM:
			return ""
		MODE_PATH:
			return "path_open"
	return "not_in_sanctum"


## "" when a discard from container `box` is allowed, else `not_in_sanctum` (wrong screen), `not_in_pack`
## (a Sanctum entry on a path), `path_used` (the one discard of this path is spent) or `no_stage` (no stage
## record can hold the mark).
static func discard_block_reason(ctx: FlowContext, box: String) -> String:
	match mode(ctx):
		MODE_SANCTUM:
			return ""
		MODE_PATH:
			if box != InventoryService.BOX_PACK:
				return "not_in_pack"
			if saved_stage(ctx).is_empty():
				return "no_stage"
			return "path_used" if discard_used(ctx) else ""
	return "not_in_sanctum"


static func discard_used(ctx: FlowContext) -> bool:
	return bool(saved_stage(ctx).get(STAGE_KEY, false))


## Records the one discard of this path on the stage record. False when there is no stage record.
static func mark_discard_used(ctx: FlowContext) -> bool:
	var stage := saved_stage(ctx)
	if stage.is_empty():
		return false
	stage[STAGE_KEY] = true
	return true


## Ends the one-discard window of a path. No-op when the mark is absent.
static func clear_discard_used(stage: Dictionary) -> void:
	stage.erase(STAGE_KEY)


## `data.inventory` for the Sanctum, party prep and the path view: `InventoryService.snapshot` with `reserved`
## = the open item rows of the whole save. With `force_path` (the path view) it adds
## `path: { move_reason, discard_used, discard_pack_reason, discard_sanctum_reason }`. A reason is "" when the
## action is allowed. Outside the path view there is no `path` key.
static func projection(ctx: FlowContext, force_path: bool = false) -> Dictionary:
	var save: Dictionary = ctx.save_data if ctx.save_data != null else {}
	var cfg := ConfigService.get_inventory_cfg(ctx.config_service) if ctx.config_service != null else {}
	var inv := InventoryService.snapshot(save, cfg, EarningsService.open_item_rows_in_save(save))
	if force_path:
		var used := discard_used(ctx)
		inv["path"] = {
			"move_reason": "path_open",
			"discard_used": used,
			"discard_pack_reason": "path_used" if used else "",
			"discard_sanctum_reason": "not_in_pack",
		}
	return inv
