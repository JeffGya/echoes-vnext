class_name PickupEventService
extends RefCounted

## The pickup event after a won fight (design document sections 4 to 6; D-05, D-39, D-43, D-49, D-51).
## Static. Writes only `stage.pickup` (the event record, also the exactly-once stamp), `stage.swap_used`,
## and, through the seam and `commit_swap`, item rows and held-piece fates. Both stage keys are lazy:
## absent until an event opens or a swap commits. `InventoryRules.clear_path_marks` erases them at a path end.
##
## Record `stage.pickup`: { situation_id, run_count, win_t, phase, return_to, chooser, standing_ids,
## fallen_names, frozen, reason, case, reaction, rank, realm_scale, finds[{ find_id, type_id, name, kind,
## grade, quantity, cell }], order, taken, left, tried, free, swap }. `order`, `taken`, `left` hold find ids.
## `free` = free pack slots before the seam call, saved in the record (the swap gate needs it).
## `swap` = {} until a swap commits, then { find_id, dropped_id, dropped_type_id, dropped, t }.
## `phase` = "idle" while the event is open, "done" after Continue (the durable end mark: no action, no resume).

const STAGE_KEY := "pickup"
const SWAP_KEY := "swap_used"
const PHASE_IDLE := "idle"
const PHASE_DONE := "done"


static func record_of(stage: Dictionary) -> Dictionary:
	var v: Variant = stage.get(STAGE_KEY, {})
	return v if v is Dictionary else {}


static func swap_used(stage: Dictionary) -> bool:
	return bool(stage.get(SWAP_KEY, false))


static func is_ended(record: Dictionary) -> bool:
	return str(record.get("phase", "")) == PHASE_DONE


## True when `stage` holds an open event of the win that made `pending` (`win_t == created_t`, D-58). Ints are
## cast: a JSON reload turns them into floats.
static func is_open_for(stage: Dictionary, pending: Dictionary) -> bool:
	var record := record_of(stage)
	return not record.is_empty() and not pending.is_empty() and not is_ended(record) \
		and int(record.get("win_t", -1)) == int(pending.get("created_t", -2))


## Party Echo ids that fell in this stage: the stage's one answer (`lost_echo_names_with`, names) over the active
## party, so an Echo that fell in an earlier fight and is still in the party counts as fallen.
static func fallen_party_ids(flow_ctx: FlowContext, actors: Array) -> Array:
	var lost := ActiveStageService.lost_echo_names_with(flow_ctx, actors)
	var out: Array = []
	for a: Dictionary in SanctumService.get_party_actors_static(flow_ctx.save_data):
		if lost.has(str(a.get("name", ""))):
			out.append(str(a.get("id", "")))
	return out


## Opens the event of one won fight and returns a copy of its record; {} when no event opens (no stage, no
## situation, a loss, no finds, nobody standing, every find refused). Order (plan, "Determinism and RNG"):
## stamp gate -> roll count -> standing list -> chooser draw -> freeze check -> pick order -> pack room ->
## seam call -> case, tried, reaction -> write the record. A record with the same (run_count, situation_id)
## is the stamp: it is returned as stored, nothing is drawn or written. `armed`: debug finds (`PickupFinds`).
static func open_after_win(flow_ctx: FlowContext, situation_id: String, rank: String, fallen_ids: Array,
		return_to: String, armed: Array, t: int) -> Dictionary:
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	if stage.is_empty() or situation_id.is_empty():
		return {}
	var realm := RealmService.get_active(flow_ctx)
	var run_count := int(realm.get("run_count", 0))
	var stored := record_of(stage)
	# `stage.pickup` holds only the LAST event: call this only for `last_situation_id`. A later event replaces the
	# stamp, so reopening an older situation would offer its left finds again.
	if int(stored.get("run_count", -1)) == run_count and str(stored.get("situation_id", "")) == situation_id:
		return stored.duplicate(true)

	var data := ConfigService.get_balance_data(flow_ctx.config_service)
	var inv_cfg := ConfigService.get_inventory_cfg(flow_ctx.config_service)
	# UNWIRED (target: NEW "Realm seed survives a save reload"): realm.seed can lose digits through JSON; the finds roll and chooser draw read it
	var realm_seed := int(realm.get("seed", 0))
	var realm_scale := float(ActiveStageService.get_payout_factors(flow_ctx, flow_ctx.config_service)["realm_scale"])
	var count := FindsRules.roll_count(inv_cfg, realm_seed, flow_ctx.stage_id, run_count, situation_id, realm_scale, rank)
	var finds := PickupFinds.finds_for_win(count, armed)
	if finds.is_empty():
		return {}

	var party: Array = SanctumService.get_party_actors_static(flow_ctx.save_data)
	var standing := PickupChooser.standing_ids(party.map(func(a: Dictionary) -> String: return str(a.get("id", ""))),
		fallen_ids)
	if standing.is_empty():
		return {}
	var drawn := PickupChooser.draw(realm_seed, flow_ctx.stage_id, run_count, situation_id, standing)
	var chooser_id := str(drawn["chooser_id"])
	var chooser := _chooser_view(flow_ctx.save_data, data, party, standing, chooser_id)
	var pctx := PickupPick.ctx_from(data)
	var frozen := PickupPick.frozen(chooser, pctx)
	var order := PickupPick.order(chooser, finds, pctx)

	var room := PickupCase.pack_room(flow_ctx.save_data, inv_cfg)
	var got := ActiveStageService.record_found_items(flow_ctx, situation_id, finds if frozen else order, t, not frozen)
	var offered := {}
	for fid in (got["taken"] as Array) + (got["left"] as Array):
		offered[str(fid)] = true
	var kept_finds := _only(finds, offered)
	var kept_order := _only(order, offered)
	if kept_finds.is_empty():
		return {}
	var ev := PickupCase.resolve(kept_finds, kept_order, room, frozen, chooser["actor"] as Dictionary, inv_cfg)
	if str(ev["taken"]) != str(got["taken"]) and flow_ctx.logger != null:
		flow_ctx.logger.error(t, "inventory.pickup.taken_mismatch", "The seam took other finds than the case", {
			"situation_id": situation_id, "case": ev["taken"], "seam": got["taken"] })

	var fallen_names: Array = []
	for a: Dictionary in party:
		if not standing.has(str(a.get("id", ""))):
			fallen_names.append(str(a.get("name", "")))
	var rows: Array = []
	for i in kept_finds.size():
		var f: Dictionary = kept_finds[i]
		var type_id := str(f.get("type_id", ""))
		# UNWIRED (target: NEW "Pickup placement on the board"): real placement of finds on the board (a simple row today)
		rows.append({ "find_id": str(f.get("find_id", "")), "type_id": type_id,
			"name": InventoryService.name_of(inv_cfg, type_id), "kind": str(f.get("kind", "")),
			"grade": str(f.get("grade", "")), "quantity": int(f.get("quantity", 1)), "cell": i })
	# UNWIRED (target: NEW "Pickup reaction effect"): the reaction class is stored; no EmotionService call applies it
	var record := {
		"situation_id": situation_id, "run_count": run_count, "win_t": t, "phase": PHASE_IDLE,
		"return_to": return_to, "chooser": chooser_id, "standing_ids": standing, "fallen_names": fallen_names,
		"frozen": frozen, "reason": "froze" if frozen else PickupPick.reason(chooser, kept_order[0], pctx),
		"case": ev["case"], "reaction": ev["reaction"], "rank": rank, "realm_scale": realm_scale,
		"finds": rows, "order": kept_order.map(func(f: Dictionary) -> String: return str(f.get("find_id", ""))),
		"taken": (got["taken"] as Array).map(func(v: Variant) -> String: return str(v)),
		"left": kept_finds.map(func(f: Dictionary) -> String: return str(f.get("find_id", ""))).filter(
			func(id: String) -> bool: return not (got["taken"] as Array).has(id)),
		"tried": ev["tried"], "free": ev["free"], "swap": {},
	}
	stage[STAGE_KEY] = record.duplicate(true)
	flow_ctx.request_save("inventory.pickup.open")
	if flow_ctx.logger != null:
		flow_ctx.logger.info(t, "inventory.pickup.open", "Pickup event opened", {
			"stage_id": flow_ctx.stage_id, "situation_id": situation_id, "chooser": chooser_id, "frozen": frozen,
			"case": ev["case"], "finds": rows.size(), "taken": (record["taken"] as Array).size() })
	return record


## The one swap of a path (D-27, D-28): field find `find_id` from the open event goes into the pack, pack entry
## `pack_id` (a held piece or stack id, or an item row id, as `PickupSwapRules.pack_entries` lists them) is lost
## with reason `swapped`. Returns { ok, reason_key }: the `PickupSwapRules.pair` refusals, or `no_event`.
static func commit_swap(flow_ctx: FlowContext, find_id: String, pack_id: String, t: int) -> Dictionary:
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	var record := record_of(stage)
	if record.is_empty():
		return { "ok": false, "reason_key": "no_event" }
	var finds: Array = record.get("finds", [])
	var res := PickupSwapRules.pair(record, finds, PickupSwapRules.pack_entries(flow_ctx.save_data, stage),
		swap_used(stage), find_id, pack_id)
	if not bool(res["ok"]):
		return res

	var sit := str(record["situation_id"])
	var dropped_type := ""
	var dropped := _dropped_view(flow_ctx, stage, pack_id)
	# UNWIRED (target: V2-ITEM-004): recycle route for the dropped item
	var row := EarningsService.row_of(stage, pack_id)
	if not row.is_empty():
		row["lost"] = true
		var e: Dictionary = (row["items"] as Array)[0]
		e["fate"] = "lost"
		e["reason_key"] = "swapped"
		dropped_type = str(e.get("type_id", ""))
		# A find of this event goes back onto the field and is lost when the event ends (design 6.2).
		for f: Dictionary in finds:
			var fid := str(f["find_id"])
			if pack_id == EarningsService.item_id(sit, fid) and (record["taken"] as Array).has(fid):
				(record["taken"] as Array).erase(fid)
				(record["left"] as Array).append(fid)
	else:
		for p: Dictionary in InventoryService.remove_held(flow_ctx.save_data, [pack_id]):
			EarningsService.put_held_fate(stage, EarningsService.held_record(p,
				"swap:%d:%s" % [int(record["run_count"]), sit], "lost", "swapped"))
			dropped_type = str(p["type_id"])
	for f: Dictionary in finds:
		if str(f["find_id"]) == find_id:
			EarningsService.record_item(stage, sit, find_id, f)
	(record["taken"] as Array).append(find_id)
	(record["left"] as Array).erase(find_id)
	record["left"] = finds.map(func(f: Dictionary) -> String: return str(f["find_id"])).filter(
		func(id: String) -> bool: return (record["left"] as Array).has(id))
	record["swap"] = { "find_id": find_id, "dropped_id": pack_id, "dropped_type_id": dropped_type,
		"dropped": dropped, "t": t }
	stage[SWAP_KEY] = true
	flow_ctx.request_save("inventory.pickup.swap")
	if flow_ctx.logger != null:
		flow_ctx.logger.info(t, "inventory.pickup.swap", "Pickup swap committed", {
			"stage_id": flow_ctx.stage_id, "situation_id": sit, "find_id": find_id, "dropped_type_id": dropped_type })
	return res


## What a swap drops, read before the removal: { id, type_id, name, kind, grade, quantity }; {} when `pack_id` is
## in neither the held pieces nor the open item rows. The UI shows it after the swap.
static func _dropped_view(flow_ctx: FlowContext, stage: Dictionary, pack_id: String) -> Dictionary:
	var kind := ""
	var grade := ""
	var type_id := ""
	var quantity := 1
	var found := false
	for h: Dictionary in InventoryService.held_pieces(flow_ctx.save_data):
		if str(h["id"]) == pack_id:
			type_id = str(h["type_id"])
			kind = str(h["kind"])
			grade = str(h.get("grade", ""))
			quantity = int(h.get("quantity", 1))
			found = true
	var items: Array = EarningsService.row_of(stage, pack_id).get("items", [])
	if not found and not items.is_empty() and items[0] is Dictionary:
		var e: Dictionary = items[0]
		type_id = str(e.get("type_id", ""))
		kind = str(e.get("kind", ""))
		grade = str(e.get("grade", ""))
		quantity = int(e.get("quantity", 1))
		found = true
	if not found:
		return {}
	return { "id": pack_id, "type_id": type_id, "name": InventoryService.name_of(
		ConfigService.get_inventory_cfg(flow_ctx.config_service), type_id), "kind": kind, "grade": grade, "quantity": quantity }


## The chooser as `PickupPick` reads it: the `EchoActor.from_echo` view, with Judgment and composure derived the
## way `StagePartyStance.read_echo` derives them, living = the standing Echoes.
static func _chooser_view(save: Dictionary, data: Dictionary, party: Array, standing: Array, chooser_id: String) -> Dictionary:
	var actor: Dictionary = {}
	for a: Dictionary in party:
		if str(a.get("id", "")) == chooser_id:
			actor = a
	var sanctum: Dictionary = save.get("sanctum", {}) if save.get("sanctum", {}) is Dictionary else {}
	var bonds: Array = sanctum.get("bonds", []) if sanctum.get("bonds", []) is Array else []
	var living := {}
	for id in standing:
		living[id] = true
	var thresholds: Variant = (data.get("sanctum", {}) as Dictionary).get("bond_thresholds", {}) \
		if data.get("sanctum", {}) is Dictionary else {}
	var ctx_in := MaturityExpressionService.build_ctx_inputs(actor, bonds, living, data,
		thresholds if thresholds is Dictionary else {}, {}, 0.0)
	var mat: Variant = data.get("maturity_expression", {})
	var expr := MaturityExpressionService.derive_expression(actor, ctx_in, mat if mat is Dictionary else {})
	return { "actor": actor, "judgment": clampf(float(expr.get("judgment", 0.0)), 0.0, 1.0),
		"composure": float(expr.get("composure", 0.0)) }


## The finds of `list` whose id is in `ids`, first copy only, in list order.
static func _only(list: Array, ids: Dictionary) -> Array:
	var seen := {}
	var out: Array = []
	for f in list:
		var id := str((f as Dictionary).get("find_id", "")) if f is Dictionary else ""
		if ids.has(id) and not seen.has(id):
			seen[id] = true
			out.append(f)
	return out
