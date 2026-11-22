class_name PickupSnapshotBuilder
extends RefCounted

## The `flow.pickup` snapshot (design document sections 5, 6, 9; D-37, D-43, D-44, D-45, D-58).
## Static and pure: reads the saved `stage.pickup` record, the save and the config; writes nothing.
## Core emits keys and ids, never player text. `flow.pickup` is a snapshot type only: no machine state.
##
## `session` is the volatile part the saved record cannot hold (a reload resumes at idle, D-58):
## { phase, swap_origin, swap_target, selected }. Phase "intro" = the first publish (finds hidden, D-37). Missing
## or unknown = "idle". A swap phase that the record cannot support falls back to "idle".
## `swap_origin` is a left find id OR a pack slot id (D-25: a swap starts from either side); `swap_target` is the
## other side. `selected` = the id of the item whose details show (`pickup.select` writes it, `pickup.swap.start`
## reads it as the origin). The snapshot key `selected` is { id, side: "find"|"pack" }, or {} when the id is not
## valid now (a hidden find in the intro, an id of no find and no pack slot).
## Board tiles (D-72, `PickupPlacement`, derived on every build, never saved): `row[].tile` and `finds[].tile` are
## { col, row }. `finds[].cell` stays the index in the record. `camera_frame` is the camera tunables (D-73).
## `pointer_look` is the feel values of the pointer mote (D-77): { path, tables, mote, items, reduced, buttons, timing, reasons, tempo }, see `pointer_look`.
## `swap.targets` is keyed by BOTH sides: left find id -> legal pack ids, pack id -> legal left find ids.
##
## Actions (slot-keyed; no `nav.back`, the event has no way out except Continue):
##   intro        overlay.skip
##   idle         cta.continue, cta.swap (only when the swap is offered)
##   swap_pick    back
##   swap_preview cta.confirm, back
## Per-row actions are NOT in `snapshot.actions`; the UI dispatches them itself:
##   `pickup.select` { find_id | pack_id } (details), `pickup.swap.pick` { id } (the other item of the swap).

# UNWIRED (target: NEW "Pickup intro short forms"): the intro has Skip only; short and brief forms need a feel pass
const PHASE_INTRO := "intro"
const PHASE_IDLE := "idle"
const PHASE_SWAP_PICK := "swap_pick"
const PHASE_SWAP_PREVIEW := "swap_preview"

const STATUS_TAKEN := "taken"
const STATUS_LEFT := "left"
const STATUS_TRIED := "tried"
const STATUS_LOST := "lost"

const TONE_PLAIN := "plain"
const TONE_NEAR := "near"
const TONE_FULL := "full"


static func build(flow_ctx: FlowContext, t: int, session: Dictionary = {}) -> Dictionary:
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	var record := PickupEventService.record_of(stage).duplicate(true)
	if record.is_empty():
		return { "type": FlowStateIds.PICKUP, "data": { "error": "no_pickup_event" }, "actions": {}, "meta": { "t": t } }

	var save := flow_ctx.save_data
	var inv_cfg := ConfigService.get_inventory_cfg(flow_ctx.config_service)
	var finds: Array = record.get("finds", [])
	var swap_spent := PickupEventService.swap_used(stage)
	var entries := PickupSwapRules.pack_entries(save, stage)
	var offer := PickupSwapRules.offer(record, finds, entries, swap_spent)
	var offered := bool(offer["ok"])

	var left_ids: Array = record.get("left", [])
	var targets := {}
	if offered:
		for fid in left_ids:
			targets[str(fid)] = PickupSwapRules.targets(record, finds, entries, swap_spent, str(fid))
		for e: Dictionary in entries:
			var legal: Array = []
			for fid in left_ids:
				if bool(PickupSwapRules.pair(record, finds, entries, swap_spent, str(fid), str(e["id"]))["ok"]):
					legal.append(str(fid))
			targets[str(e["id"])] = legal
	var phase := _phase(session, targets)
	var origin := str(session.get("swap_origin", "")) if phase in [PHASE_SWAP_PICK, PHASE_SWAP_PREVIEW] else ""
	var target := str(session.get("swap_target", "")) if phase == PHASE_SWAP_PREVIEW else ""
	var twins: Array = []
	if not origin.is_empty():
		var origin_type := PickupSwapRules.type_of(finds, "find_id", origin)
		if origin_type.is_empty():
			origin_type = PickupSwapRules.type_of(entries, "id", origin)
		var field_side := not PickupSwapRules.type_of(finds, "find_id", origin).is_empty()
		for fid in (entries.map(func(e: Dictionary) -> String: return str(e["id"])) if field_side else left_ids):
			var other_type := PickupSwapRules.type_of(entries if field_side else finds, "id" if field_side else "find_id", str(fid))
			if other_type == origin_type:
				twins.append(str(fid))

	var standing: Array = record.get("standing_ids", [])
	var chooser_id := str(record.get("chooser", ""))
	var party := SanctumService.get_party_actors_static(save)
	var row: Array = []
	for id in standing:
		for a: Dictionary in party:
			if str(a.get("id", "")) == str(id):
				row.append(_row_entry(a, str(id) == chooser_id))
	var chooser: Dictionary = {}
	for r: Dictionary in row:
		if bool(r["is_chooser"]):
			chooser = { "id": r["id"], "name": r["name"], "standing": r["standing"] }

	var directives_cfg := ConfigService.get_directives_cfg(flow_ctx.config_service)
	var pack := _pack(save, inv_cfg, entries, record, stage)
	var data := {
		"phase": phase,
		"situation_id": str(record.get("situation_id", "")),
		"run_count": int(record.get("run_count", 0)),
		"return_to": str(record.get("return_to", "")),
		"chooser": chooser, "row": row, "fallen": record.get("fallen_names", []),
		"order": record.get("order", []),
		"selected": _selected(str(session.get("selected", "")), phase, record, pack),
		"reason": str(record.get("reason", "")), "case": str(record.get("case", "")),
		"frozen": bool(record.get("frozen", false)), "reaction": str(record.get("reaction", "")),
		"finds": _find_rows(record, phase),
		"pack": pack,
		"swap_left": 0 if swap_spent else 1,
		"destroy_left": 0 if InventoryRules.discard_used(flow_ctx) else 1,
		"swap": { "offered": offered, "reason_key": str(offer["reason_key"]), "spent": swap_spent,
			"origin": origin, "target": target, "twins": twins, "targets": targets, "dropped": _dropped(record) },
		"confirm_leave_items": DirectiveService.confirms_leave_items(directives_cfg, DirectiveService.active_id(save)),
		"camera_frame": camera_frame(inv_cfg),
		"pointer_look": pointer_look(inv_cfg),
	}
	data.merge(_board(flow_ctx))
	_add_tiles(data, inv_cfg)
	return { "type": FlowStateIds.PICKUP, "data": data, "actions": _actions(phase, offered), "meta": { "t": t } }


## `data.camera_frame` { floor_zoom, margin_px, tween_seconds } from `inv_cfg.pickup.camera` (D-73): the framing the UI
## applies at event start. A missing key reads as 0.75, 48 and 0.45; floor_zoom is clamped to 0.05..2.2, the other two
## to 0 or more.
static func camera_frame(inv_cfg: Dictionary) -> Dictionary:
	var pk_v: Variant = inv_cfg.get("pickup", {})
	var pk: Dictionary = pk_v if pk_v is Dictionary else {}
	var cam_v: Variant = pk.get("camera", {})
	var cam: Dictionary = cam_v if cam_v is Dictionary else {}
	return { "floor_zoom": clampf(float(cam.get("floor_zoom", 0.75)), 0.05, 2.2),
		"margin_px": maxf(0.0, float(cam.get("margin_px", 48))),
		"tween_seconds": maxf(0.0, float(cam.get("tween_seconds", 0.45))) }


## Rules of `data.inventory.pickup.pointer_look`, group -> key -> [default, lowest, highest, whole]. `ConfigValidator` reads
## the same table. A lowest of 0.001 means "above 0": the UI divides by the key, or zero means nothing.
## The `mote` sizes are pixels at 1280x720 with a 128 px wide tile. The scene has five trail sprites: more samples show no more.
const POINTER_LOOK_RULES := {
	"path": {
		"pointer_start": [0.5, 0.0, INF, false], "pointer_lead": [0.30, 0.001, INF, false],
		"hold": [0.60, 0.0, INF, false], "hold_reduced": [0.2, 0.0, INF, false],
		"pointer_reduced": [0.5, 0.001, INF, false],
		"walk_time_scale": [1.13, 0.001, INF, false], "walk_ease": [0.7, 0.0, 1.0, false],
		"path_pace": [0.19, 0.001, INF, false], "path_first_k": [1.5, 0.001, INF, false],
		"path_slow_n": [5, 1, INF, true], "path_slow_k": [1.25, 0.001, INF, false],
		"path_final_k": [1.6, 0.001, INF, false], "path_turn_min": [0.26, 0.001, INF, false],
		"path_turn_max": [0.64, 0.001, INF, false], "path_arc_fast": [0.18, 0.0, INF, false],
		"path_arc_span": [0.72, 0.001, INF, false],
	},
	"mote": {
		"rise": [16.0, 0.0, INF, false], "fade_scale_from": [0.5, 0.0, INF, false],
		"above_head": [36.0, 0.0, INF, false], "arc_min": [6.0, 0.0, INF, false], "arc_max": [14.0, 0.001, INF, false],
		"trail_count": [5, 0, 16, true], "trail_dt": [0.035, 0.0, INF, false], "trail_alpha": [0.30, 0.0, 1.0, false],
		"trail_scale": [0.9, 0.0, INF, false], "trail_scale_step": [0.08, 0.0, INF, false],
		"mote_radius": [30.0, 0.001, INF, false], "wind_up": [4.0, 0.0, INF, false],
		"wind_up_len": [0.08, 0.001, INF, false], "sink": [20.0, 0.0, INF, false], "sink_len": [0.28, 0.001, INF, false],
		"sink_scale": [0.4, 0.0, 1.0, false], "sink_fade_from": [0.4, 0.0, 0.99, false],
		"halo_diameter_tiles": [0.703, 0.001, INF, false], "halo_alpha": [0.55, 0.0, 1.0, false],
		"halo_start_alpha": [0.2, 0.0, 1.0, false], "halo_open": [0.30, 0.001, INF, false],
		"halo_breath": [0.08, 0.0, 1.0, false], "halo_breath_period": [1.6, 0.001, INF, false],
		"halo_fade_out": [0.30, 0.001, INF, false],
		"brighten": [0.20, 0.0, INF, false], "brighten_len": [0.15, 0.001, INF, false],
		"shadow_scale_y": [0.4, 0.001, INF, false], "shadow_alpha_drop": [0.4, 0.0, 1.0, false],
		"shadow_scale_drop": [0.3, 0.0, 1.0, false], "shadow_radius": [14.0, 0.001, INF, false],
		"skip_fade": [0.18, 0.001, INF, false],
	},
	"items": {
		"reveal_len": [0.34, 0.001, INF, false], "carry_len": [0.34, 0.001, INF, false], "carry_hold": [0.19, 0.0, INF, false],
		"carry_above": [28.0, 0.0, INF, false], "fly_len": [0.49, 0.001, INF, false], "step_gap": [0.26, 0.0, INF, false],
		"arc_px": [34.0, 0.0, INF, false], "shadow_scale_drop": [0.3, 0.0, 1.0, false], "try_lift_extra": [0.1, 0.0, INF, false],
		"try_bark_gap": [0.05, 0.0, INF, false], "bark_after_last": [0.15, 0.001, INF, false], "lit_fade": [0.25, 0.001, INF, false],
	},
	"buttons": {
		"skip_in_from": [0.2, 0.0, INF, false], "skip_in_to": [0.35, 0.0, INF, false], "skip_out_len": [0.1, 0.0, INF, false],
		"cont_in_len": [0.25, 0.0, INF, false],
	},
	"timing": {
		"step_len": [0.45, 0.001, INF, false],
		"walk_cap": [3.4, 0.001, INF, false],
		"type_cps": [24.0, 0.001, INF, false],
		"dist_scale_min": [0.6, 0.001, INF, false],
		"dist_scale_max": [1.35, 0.001, INF, false],
		"worth_dwell": [0.45, 0.0, INF, false],
		"safe_pre_extra": [0.25, 0.0, INF, false],
		"frozen_step": [0.35, 0.0, INF, false],
		"frozen_wait": [1.35, 0.0, INF, false],
		"idle_after_bark": [0.3, 0.0, INF, false],
		"idle_after_deposit": [0.45, 0.0, INF, false],
		"pulse_len": [0.4, 0.001, INF, false],
		"ref_tiles_first": [3.0, 0.001, INF, false],
		"ref_tiles_next": [2.0, 0.001, INF, false],
	},
	"reasons": {
		"likes_walk_first": [0.7, 0.001, INF, false], "likes_walk_next": [0.6, 0.001, INF, false], "likes_touch": [0.1, 0.0, INF, false], "likes_ease_back": [1, 0, 1, true],
		"worth_walk_first": [0.6, 0.001, INF, false], "worth_walk_next": [0.6, 0.001, INF, false], "worth_touch": [0.1, 0.0, INF, false], "worth_ease_back": [0, 0, 1, true],
		"safe_walk_first": [0.95, 0.001, INF, false], "safe_walk_next": [0.7, 0.001, INF, false], "safe_touch": [0.1, 0.0, INF, false], "safe_ease_back": [0, 0, 1, true],
		"bold_walk_first": [0.5, 0.001, INF, false], "bold_walk_next": [0.4, 0.001, INF, false], "bold_touch": [0.1, 0.0, INF, false], "bold_ease_back": [1, 0, 1, true],
		"fit_walk_first": [0.45, 0.001, INF, false], "fit_walk_next": [0.45, 0.001, INF, false], "fit_touch": [0.0, 0.0, INF, false], "fit_ease_back": [0, 0, 1, true],
	},
	"tempo": {
		"pre_1": [0.6, 0.0, INF, false],
		"pre_5": [0.35, 0.0, INF, false],
		"pre_9": [0.1, 0.0, INF, false],
		"hitch_1": [0.12, 0.0, INF, false],
		"hitch_5": [0.06, 0.0, INF, false],
		"hitch_9": [0.0, 0.0, INF, false],
		"pace_1": [0.8, 0.001, INF, false],
		"pace_5": [0.95, 0.001, INF, false],
		"pace_9": [1.0, 0.001, INF, false],
		"delay_1": [0.2, 0.0, INF, false],
		"delay_5": [0.1, 0.0, INF, false],
		"delay_9": [0.0, 0.0, INF, false],
	},
	"reduced": {
		"step_len": [0.15, 0.001, INF, false], "reveal_len": [0.15, 0.001, INF, false], "leg_len": [0.15, 0.001, INF, false],
		"carry_len": [0.15, 0.001, INF, false], "fly_len": [0.15, 0.001, INF, false], "frozen_wait": [0.4, 0.0, INF, false],
	},
}
## Authored arrival times of the racetrack by "n:land_index" (seconds after the path clock starts). A table is used only when
## its length is the move count, 3n - 1 - land_index; any other row gets the slow-down law of the `path` keys.
const POINTER_LOOK_TABLES := {
	"5:2": [0.58, 0.78, 0.96, 1.14, 1.40, 1.58, 1.77, 2.01, 2.31, 2.81, 3.19, 3.79],
	"3:1": [0.68, 0.96, 1.42, 1.72, 2.06, 2.70, 3.60],
}


## `data.pointer_look` { path, tables, mote, items, reduced, buttons, timing, reasons, tempo } from `inv_cfg.pickup.pointer_look` (D-77). Presentation only. A missing or
## non-number key reads its default; a number is clamped into its range; whole keys are ints. turn_max and arc_max never
## read below turn_min and arc_min. A missing `tables` reads the defaults; a given `tables` replaces them, and an entry that
## is not an Array of numbers, or whose times do not rise from above `pointer_lead`, is dropped.
static func pointer_look(inv_cfg: Dictionary) -> Dictionary:
	var pk_v: Variant = inv_cfg.get("pickup", {})
	var pk: Dictionary = pk_v if pk_v is Dictionary else {}
	var pl_v: Variant = pk.get("pointer_look", {})
	var pl: Dictionary = pl_v if pl_v is Dictionary else {}
	var out := {}
	for group: String in POINTER_LOOK_RULES:
		var src_v: Variant = pl.get(group, {})
		var src: Dictionary = src_v if src_v is Dictionary else {}
		var vals := {}
		for key: String in POINTER_LOOK_RULES[group]:
			var rule: Array = POINTER_LOOK_RULES[group][key]
			var v: Variant = src.get(key, null)
			var x := float(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v)) else float(rule[0])
			x = clampf(x, float(rule[1]), float(rule[2]))
			vals[key] = int(x) if bool(rule[3]) else x
		out[group] = vals
	out["path"]["path_turn_max"] = maxf(out["path"]["path_turn_max"], out["path"]["path_turn_min"])
	out["mote"]["arc_max"] = maxf(out["mote"]["arc_max"], out["mote"]["arc_min"])
	out["timing"]["dist_scale_max"] = maxf(out["timing"]["dist_scale_max"], out["timing"]["dist_scale_min"])
	var tables: Dictionary = POINTER_LOOK_TABLES.duplicate(true)
	if pl.get("tables", null) is Dictionary:
		tables = {}
		for key: Variant in pl["tables"]:
			var arr_v: Variant = pl["tables"][key]
			if arr_v is Array and (arr_v as Array).all(func(x: Variant) -> bool:
					return (typeof(x) == TYPE_INT or typeof(x) == TYPE_FLOAT) and is_finite(float(x))):
				var times: Array = (arr_v as Array).map(func(x: Variant) -> float: return float(x))
				var prev: float = out["path"]["pointer_lead"]
				var rising := true
				for t: float in times:
					rising = rising and t > prev
					prev = t
				if rising:
					tables[str(key)] = times
	out["tables"] = tables
	return out


## Adds `row[].tile` and `finds[].tile` (board tiles, `PickupPlacement`; derived on every build, never saved).
## `cell` stays the index of a find in the record.
static func _add_tiles(data: Dictionary, inv_cfg: Dictionary) -> void:
	var row: Array = data["row"]
	var finds: Array = data["finds"]
	var placed := PickupPlacement.place(data["terrain"] as Dictionary, int(data["board_cols"]), int(data["board_rows"]),
		int(data["placement_seed"]), str(data["situation_id"]), int(data["run_count"]), data["actors"] as Array,
		row.map(func(r: Dictionary) -> String: return str(r["id"])),
		finds.map(func(f: Dictionary) -> String: return str(f["find_id"])), inv_cfg)
	for r: Dictionary in row:
		r["tile"] = (placed["row"] as Dictionary)[str(r["id"])]
	for f: Dictionary in finds:
		f["tile"] = (placed["finds"] as Dictionary)[str(f["find_id"])]


static func _selected(id: String, phase: String, record: Dictionary, pack: Dictionary) -> Dictionary:
	if id.is_empty():
		return {}
	for f: Dictionary in record.get("finds", []):
		if str(f.get("find_id", "")) == id:
			return {} if phase == PHASE_INTRO else { "id": id, "side": "find" }
	for slot: Dictionary in pack["slots"]:
		if str(slot["id"]) == id:
			return { "id": id, "side": "pack" }
	return {}


## The final items of an event for the Resolve card (`data.pickup_result`): { taken, left, lost, dropped, swap_used }.
## Rows are { type_id, name, kind, grade, quantity }, no ids. The buckets are the snapshot statuses: a tried find
## is `left`, every find of a frozen chooser is `lost` (D-43). `dropped` is the pack item the swap lost, or {}.
## {} for no record.
static func result_of(record: Dictionary) -> Dictionary:
	if record.is_empty():
		return {}
	var out := { "taken": [], "left": [], "lost": [], "dropped": {},
		"swap_used": not (record.get("swap", {}) as Dictionary).is_empty() }
	for f: Dictionary in _find_rows(record, PHASE_IDLE):
		var bucket := str(f["status"]) if str(f["status"]) != STATUS_TRIED else STATUS_LEFT
		(out[bucket] as Array).append(_item_row(f))
	var dropped := _dropped(record)
	if not dropped.is_empty():
		out["dropped"] = _item_row(dropped)
	return out


static func _item_row(v: Dictionary) -> Dictionary:
	return { "type_id": v["type_id"], "name": v["name"], "kind": v["kind"], "grade": v["grade"],
		"quantity": v["quantity"] }


## The pack item the saved swap dropped (`PickupEventService.commit_swap`), or {}.
static func _dropped(record: Dictionary) -> Dictionary:
	var sw_v: Variant = record.get("swap", {})
	var d_v: Variant = (sw_v as Dictionary).get("dropped", {}) if sw_v is Dictionary else {}
	if not (d_v is Dictionary) or (d_v as Dictionary).is_empty():
		return {}
	var d: Dictionary = d_v
	return { "id": str(d.get("id", "")), "type_id": str(d.get("type_id", "")), "name": str(d.get("name", "")),
		"kind": str(d.get("kind", "")), "grade": str(d.get("grade", "")), "quantity": int(d.get("quantity", 1)) }


static func _phase(session: Dictionary, targets: Dictionary) -> String:
	var want := str(session.get("phase", PHASE_IDLE))
	if want == PHASE_INTRO:
		return PHASE_INTRO
	var origin := str(session.get("swap_origin", ""))
	if want == PHASE_SWAP_PICK or want == PHASE_SWAP_PREVIEW:
		if not targets.has(origin) or (targets[origin] as Array).is_empty():
			return PHASE_IDLE
		if want == PHASE_SWAP_PREVIEW and (targets[origin] as Array).has(str(session.get("swap_target", ""))):
			return PHASE_SWAP_PREVIEW
		return PHASE_SWAP_PICK
	return PHASE_IDLE


static func _actions(phase: String, offered: bool) -> Dictionary:
	var out := {}
	match phase:
		PHASE_INTRO:
			out["overlay.skip"] = { "type": "pickup.skip", "slot": "overlay.skip" }
		PHASE_IDLE:
			out["cta.continue"] = { "type": "pickup.continue", "slot": "cta.continue" }
			if offered:
				out["cta.swap"] = { "type": "pickup.swap.start", "slot": "cta.swap" }
		PHASE_SWAP_PICK:
			out["back"] = { "type": "pickup.swap.cancel", "slot": "back" }
		PHASE_SWAP_PREVIEW:
			out["cta.confirm"] = { "type": "pickup.swap.confirm", "slot": "cta.confirm" }
			out["back"] = { "type": "pickup.swap.cancel", "slot": "back" }
	return out


## Status: taken (in the pack), tried (held up, did not fit), left, lost. A frozen chooser loses every find
## (D-43). A hidden find (intro) is not selectable (D-45), so `revealed` is the whole rule. `pick_index` = the
## place in the taken list (pick order), -1 when not taken. Ints are cast: a JSON reload turns them into floats.
static func _find_rows(record: Dictionary, phase: String) -> Array:
	var taken: Array = record.get("taken", [])
	var frozen := bool(record.get("frozen", false))
	var out: Array = []
	for f: Dictionary in record.get("finds", []):
		var fid := str(f.get("find_id", ""))
		var status := STATUS_LEFT
		if taken.has(fid):
			status = STATUS_TAKEN
		elif frozen:
			status = STATUS_LOST
		elif fid == str(record.get("tried", "")):
			status = STATUS_TRIED
		out.append({ "find_id": fid, "type_id": str(f.get("type_id", "")), "name": str(f.get("name", "")),
			"kind": str(f.get("kind", "")), "grade": str(f.get("grade", "")), "quantity": int(f.get("quantity", 1)),
			"cell": int(f.get("cell", 0)), "status": status, "revealed": phase != PHASE_INTRO,
			"pick_index": taken.find(fid) })
	return out


## Every listed pack entry (held pieces and stacks, then the open item rows of this stage). `free` and `tone`
## count the open rows of every stage, so entries listed can be fewer than slots used.
static func _pack(save: Dictionary, inv_cfg: Dictionary, entries: Array, record: Dictionary,
		stage: Dictionary) -> Dictionary:
	var held := {}
	for h: Dictionary in InventoryService.held_pieces(save):
		held[str(h["id"])] = h
	var prefix := "item:%s:" % str(record.get("situation_id", ""))
	var slots: Array = []
	for e: Dictionary in entries:
		var id := str(e["id"])
		var type_id := str(e["type_id"])
		# UNWIRED (target: V2-ITEM-002): real item names, grades, images and descriptions come with the catalogue; placeholder names show until then
		var slot := { "id": id, "type_id": type_id, "name": InventoryService.name_of(inv_cfg, type_id),
			"find_id": id.trim_prefix(prefix) if id.begins_with(prefix) else "" }
		if held.has(id):
			var h: Dictionary = held[id]
			slot.merge({ "kind": str(h["kind"]), "grade": str(h.get("grade", "")), "quantity": int(h.get("quantity", 1)),
				"source": "stack" if id.begins_with(InventoryService.STACK_ID_PREFIX) else "held",
				"mark_index": InventoryService.mark_index_of(inv_cfg, id) })
		else:
			var items: Array = EarningsService.row_of(stage, id).get("items", [])
			var item: Dictionary = items[0] if not items.is_empty() and items[0] is Dictionary else {}
			slot.merge({ "kind": str(item.get("kind", "")), "grade": str(item.get("grade", "")),
				"quantity": int(item.get("quantity", 1)), "source": "gathered", "mark_index": -1 })
		slots.append(slot)
	var load_info := PickupCase.pack_room(save, inv_cfg)
	var carried := int(load_info["carried"])
	var capacity := int(load_info["capacity"])
	var gathered := slots.filter(func(s: Dictionary) -> bool: return str(s["find_id"]) != "").size()
	var before := InventoryService.level_of(maxi(0, carried - gathered), capacity,
		int(inv_cfg.get("warn_pack_free_at", 0)))
	return { "slots": slots, "free": int(load_info["free"]), "capacity": capacity, "carried": carried,
		"tone": _tone_of(int(load_info["level"])), "tone_before": _tone_of(before) }


## `tone_before` is the tone without the finds of this event, for the intro phase.
static func _tone_of(level: int) -> String:
	return TONE_FULL if level >= 3 else (TONE_NEAR if level == 2 else TONE_PLAIN)


static func _row_entry(actor: Dictionary, is_chooser: bool) -> Dictionary:
	return { "id": str(actor.get("id", "")), "name": str(actor.get("name", "")),
		"standing": int(actor.get("rank", 1)),
		"status": EmotionStatusLean.status_of(actor), "is_chooser": is_chooser }


## Board keys as `EncounterSnapshotBuilder.build_round_snapshot` carries them (board_cols, board_rows, terrain,
## placement_seed, encounter_id, actors, via its `_project_actor`), so the board redraws. Actor source, in order:
## the encounter context; else the durable result's `resolve_data` (`PendingResultService`); else the held
## `flow.resolve` snapshot; else []. After a reload `terrain`, `placement_seed` and `bounds` come from the durable
## result's top-level keys (D-66); a result captured without them gives {}, 0 and the grid config size. Only
## `bark_line` is cleared on the actors: the event shows its own reaction, and a stale bark would pop again.
static func _board(flow_ctx: FlowContext) -> Dictionary:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var data := ConfigService.get_balance_data(flow_ctx.config_service)
	var grid_v: Variant = data.get("grid", {})
	var grid_cfg: Dictionary = grid_v if grid_v is Dictionary else {}
	var pending := PendingResultService.read(flow_ctx.save_data)
	var stored_v: Variant = pending.get("resolve_data", {})
	var stored: Dictionary = stored_v if stored_v is Dictionary else {}
	var terrain: Dictionary = {}
	var actors: Array = []
	var bounds_v: Variant = {}
	if ectx != null:
		terrain = ectx.terrain
		for a_v in ectx.actors:
			if a_v is Dictionary:
				actors.append(EncounterSnapshotBuilder._project_actor(a_v))
	else:
		var terrain_v: Variant = pending.get("terrain", {})
		terrain = terrain_v if terrain_v is Dictionary else {}
		bounds_v = pending.get("bounds", {})
		var held_v: Variant = stored.get("actors", null)
		if not (held_v is Array) and str(flow_ctx.last_snapshot.get("type", "")) == FlowStateIds.RESOLVE:
			var last_v: Variant = flow_ctx.last_snapshot.get("data", {})
			held_v = (last_v as Dictionary).get("actors", []) if last_v is Dictionary else []
		if held_v is Array:
			actors = (held_v as Array).duplicate(true)
	for a: Variant in actors:
		if a is Dictionary:
			(a as Dictionary)["bark_line"] = ""
	bounds_v = terrain.get("bounds", bounds_v)
	var bounds: Dictionary = bounds_v if bounds_v is Dictionary else {}
	return {
		"board_cols": int(bounds["w"]) if bounds.has("w") else GridService.get_board_cols(grid_cfg),
		"board_rows": int(bounds["h"]) if bounds.has("h") else GridService.get_board_rows(grid_cfg),
		"terrain": terrain.duplicate(true),
		"placement_seed": ectx.placement_seed if ectx != null else str(pending.get("placement_seed", "0")).to_int(),
		"encounter_id": ectx.encounter_id if ectx != null else str(stored.get("encounter_id", pending.get("encounter_id", ""))),
		"actors": actors,
	}
