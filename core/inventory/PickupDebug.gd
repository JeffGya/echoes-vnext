class_name PickupDebug
extends RefCounted

## Debug scenes of the pickup event (V2-ITEM-001b C10, D-61). Static helpers behind `DebugController`:
## the producer modes `event` and `arm`, and `debug.pickup.scene.check|apply`. Nothing here is reached
## from play; the F1 console and menu are the only senders (debug builds, gated in ui/).
## Scenes: `event_now` opens the event on the path view at once (as if a fight was just won, fresh situation id
## `debug.<t>`); `arm` makes the NEXT real won fight open it with that fight's real rank and fallen Echoes.
## `prepare` and `report` change nothing. `run` is the only writer and runs inside one dispatch.
##
## `arm` without `count` uses the real finds roll of the won fight (the cap override still applies).
## Options (payload keys): ids, grades, count, rank, chooser_standing, chooser_id, fallen, cap, held, swap_used,
## and, for the scene actions only, frozen and full_pack. `rank` and `fallen` are refused by `arm`.

const SCENE_EVENT_NOW := "event_now"
const SCENE_ARM := "arm"
const SCENES: Array = [SCENE_EVENT_NOW, SCENE_ARM]
const DEFAULT_RANK := "B"
const RANKS: Array = ["S", "A", "B", "C", "D", "F"]
const FROZEN_FEAR := 95
const FROZEN_MORALE := 0
const MAX_COUNT := 12
## Lazy counter on the stage: event-now situation ids are `debug.<seq>`, so a reload cannot reuse an old id.
const SEQ_KEY := "debug_pickup_seq"

const _PLACES := {
	FlowStateIds.SANCTUM: "the Sanctum", FlowStateIds.ECHO_PARTY: "the Sanctum", FlowStateIds.SUMMON: "the Sanctum",
	FlowStateIds.VOW_MANAGE: "the Sanctum", FlowStateIds.WEAVING_RITE: "the Sanctum",
	FlowStateIds.REALM_SELECT: "the realm map", FlowStateIds.STAGE_MAP: "the stage map", FlowStateIds.STAGE: "the stage screen",
	FlowStateIds.ENCOUNTER: "a fight", FlowStateIds.RESOLVE: "a result card", FlowStateIds.PICKUP: "a pickup event",
}


## The options of `payload`, checked. { ok, reason_key, spec }. `spec` has every key; -1 or "" means absent.
static func parse(payload: Dictionary) -> Dictionary:
	var spec := { "ids": [], "grades": [], "count": -1, "rank": "", "chooser_standing": -1, "chooser_id": "", "fallen": "",
		"cap": -1, "held": [], "swap_used": false, "frozen": false, "full_pack": false }
	for key in ["ids", "grades", "held"]:
		if not payload.has(key):
			continue
		var v: Variant = payload[key]
		if not (v is Array) or (v as Array).any(func(x: Variant) -> bool: return not (x is String) or (x as String).is_empty()):
			return _bad("bad_" + key)
		if key == "ids" and (v as Array).is_empty():
			return _bad("bad_ids")
		spec[key] = (v as Array).duplicate()
	for pair in [["count", "bad_count"], ["cap", "bad_cap"], ["chooser_standing", "bad_standing"]]:
		if payload.has(pair[0]):
			var n := _whole(payload[pair[0]])
			if n < 1:
				return _bad(pair[1])
			if pair[0] != "chooser_standing" and n > MAX_COUNT:
				return _bad(pair[0] + "_too_big")
			spec[pair[0]] = n
	for key in ["chooser_id", "fallen", "rank"]:
		if payload.has(key):
			if not (payload[key] is String) or (payload[key] as String).is_empty():
				return _bad("bad_" + key)
			spec[key] = payload[key]
	if str(spec["rank"]) != "" and not RANKS.has(spec["rank"]):
		return _bad("bad_rank")
	for key in ["swap_used", "frozen", "full_pack"]:
		spec[key] = bool(payload.get(key, false))
	if int(spec["chooser_standing"]) > 0 and str(spec["chooser_id"]) != "":
		return _bad("chooser_conflict")
	return { "ok": true, "reason_key": "", "spec": spec }


## Everything a scene needs, read only. `inv_cfg` is the cfg copy with the placeholder definitions, `defs` the
## placeholder definitions. Returns { errors: [{ key, text }], spec, finds, held, fallen_ids, chooser_id, scene }.
## `errors` empty = the scene can run.
static func prepare(flow_ctx: FlowContext, inv_cfg: Dictionary, defs: Dictionary, default_ids: Array,
		payload: Dictionary, scene: String, t: int) -> Dictionary:
	var out := { "errors": [], "spec": {}, "finds": [], "held": [], "fallen_ids": [], "chooser_id": "", "scene": scene,
		"cfg": inv_cfg, "names": {} }
	var errors: Array = out["errors"]
	errors.append_array(place_errors(flow_ctx))
	var parsed := parse(payload)
	if not bool(parsed["ok"]):
		errors.append({ "key": parsed["reason_key"], "text": "An option is not valid (%s)." % parsed["reason_key"] })
		return out
	var spec: Dictionary = parsed["spec"]
	out["spec"] = spec
	if scene == SCENE_ARM:
		for key in ["rank", "fallen"]:
			if spec[key] != "":
				errors.append({ "key": key + "_not_allowed", "text": "Arm uses the real %s of the fight. Leave out %s=." % [key, key] })
	elif str(spec["rank"]) == "":
		spec["rank"] = DEFAULT_RANK
	if scene == SCENE_EVENT_NOW and not FindsRules.is_win_rank(inv_cfg, str(spec["rank"])):
		errors.append({ "key": "loss_rank", "text": "Rank %s is a loss. No event opens for a loss rank." % spec["rank"] })

	var ids: Array = spec["ids"] if not (spec["ids"] as Array).is_empty() else default_ids.duplicate()
	spec["ids"] = ids
	if (spec["grades"] as Array).size() > ids.size():
		errors.append({ "key": "bad_grades", "text": "grades= lists more grades than ids=." })
	if int(spec["count"]) > ids.size():
		errors.append({ "key": "count_exceeds_ids", "text": "count= (%d) is more than the %d id(s) listed." % [int(spec["count"]), ids.size()] })
	if scene == SCENE_ARM and bool(spec["frozen"]):
		errors.append({ "key": "frozen_not_for_arm", "text": "The freeze cannot hold until a real fight. Use event_now for the frozen case." })
	var finds := _entries(ids, spec["grades"], defs, inv_cfg, "t%d." % t, errors)
	var names: Dictionary = out["names"]
	for id in ids + spec["held"]:
		if defs.get(id, null) is Dictionary:
			names[str(id)] = str((defs[id] as Dictionary).get("name", ""))
	if scene == SCENE_EVENT_NOW and int(spec["count"]) < 1:
		spec["count"] = finds.size()
	out["finds"] = finds

	if bool(spec["full_pack"]):
		var free := _pack_free(flow_ctx, inv_cfg)
		var filler: Array = []
		for i in free:
			filler.append(default_ids[i % default_ids.size()])
		spec["held"] = filler
	out["held"] = _entries(spec["held"], [], defs, inv_cfg, "", errors)
	if (spec["held"] as Array).size() > _pack_free(flow_ctx, inv_cfg):
		errors.append({ "key": "pack_room", "text": "The pack has room for %d, but held= lists %d." % [
			_pack_free(flow_ctx, inv_cfg), (spec["held"] as Array).size()] })

	var party: Array = SanctumService.get_party_actors_static(flow_ctx.save_data)
	var fallen_ids: Array = PickupEventService.fallen_party_ids(flow_ctx, []) if not party.is_empty() else []
	var party_ids: Array = party.map(func(a: Dictionary) -> String: return str(a.get("id", "")))
	if str(spec["fallen"]) != "":
		if not party_ids.has(spec["fallen"]):
			errors.append({ "key": "bad_fallen", "text": "fallen= is not an Echo of the party." })
		elif not fallen_ids.has(spec["fallen"]):
			fallen_ids.append(spec["fallen"])
	out["fallen_ids"] = fallen_ids
	var standing: Array = PickupChooser.standing_ids(party_ids, fallen_ids)
	if not party.is_empty() and standing.is_empty():
		errors.append({ "key": "nobody_standing", "text": "Every Echo of the party has fallen on this path. Nobody can choose." })
	var chooser_id := str(spec["chooser_id"])
	if chooser_id != "" and not standing.has(chooser_id):
		errors.append({ "key": "bad_chooser", "text": "chooser= is not a standing Echo of the party." })
	elif int(spec["chooser_standing"]) > 0:
		chooser_id = ""
		for a: Dictionary in party:
			if standing.has(str(a.get("id", ""))) and int(a.get("rank", 0)) == int(spec["chooser_standing"]):
				chooser_id = str(a.get("id", ""))
				break
		if chooser_id == "":
			errors.append({ "key": "no_such_standing", "text": "No standing Echo of the party has Standing %d." % int(spec["chooser_standing"]) })
	out["chooser_id"] = chooser_id
	if bool(spec["frozen"]) and chooser_id == "":
		errors.append({ "key": "frozen_needs_chooser", "text": "frozen needs chooser= or standing=, so the scene knows whom to scare." })
	return out


## Where the player must be, plus the party. [{ key, text }] in plain words; empty = right place.
static func place_errors(flow_ctx: FlowContext) -> Array:
	var errors: Array = []
	var type := str(flow_ctx.last_snapshot.get("type", ""))
	if type == FlowStateIds.PICKUP:
		errors.append({ "key": "event_open", "text": "A pickup event is already open. Finish it first." })
	elif type != FlowStateIds.STAGE_EXPLORE:
		errors.append({ "key": "wrong_place", "text": "Needs the path view. You are in %s." % _PLACES.get(type, "an unknown screen (%s)" % type) })
	var live := not flow_ctx.realm_id.is_empty() and not flow_ctx.stage_id.is_empty() \
		and not FlowStageExploreState._get_current_stage(flow_ctx).is_empty()
	if not live:
		errors.append({ "key": "no_live_path", "text": "Needs a live path. Begin a path in a realm first." })
	if SanctumService.get_party_actors_static(flow_ctx.save_data).is_empty():
		errors.append({ "key": "no_party", "text": "Needs at least one Echo in the party." })
	return errors


## The check result for the menu and the console: { scene, ok, errors: [String], keys: [String], setup: [row] }.
## A row: { id, text, commands: [String], saves: bool }, in the order `apply` does them.
static func report(flow_ctx: FlowContext, prep: Dictionary) -> Dictionary:
	var errors: Array = prep["errors"]
	var rep := { "scene": prep["scene"], "ok": errors.is_empty(),
		"errors": errors.map(func(e: Dictionary) -> String: return str(e["text"])),
		"keys": errors.map(func(e: Dictionary) -> String: return str(e["key"])), "setup": [] }
	if prep["spec"] is Dictionary and not (prep["spec"] as Dictionary).is_empty():
		rep["setup"] = _setup_rows(flow_ctx, prep)
	return rep


static func _setup_rows(flow_ctx: FlowContext, prep: Dictionary) -> Array:
	var spec: Dictionary = prep["spec"]
	var scene: String = prep["scene"]
	var mode := "event" if scene == SCENE_EVENT_NOW else "arm"
	var run_cmd := command(mode, spec)
	var rows: Array = []
	if bool(spec["frozen"]) and str(prep["chooser_id"]) != "":
		var actor := _roster_echo(flow_ctx, str(prep["chooser_id"]))
		var id := str(prep["chooser_id"])
		rows.append({ "id": "fear", "saves": true, "commands": [
			"emotion set %s fear %d" % [id, FROZEN_FEAR], "emotion set %s morale %d" % [id, FROZEN_MORALE]],
			"text": "Set %s to fear %d and morale %d, so the chooser freezes (now fear %s, morale %s). A calm Echo with high composure may not freeze at fear 95." % [
				str(actor.get("name", id)), FROZEN_FEAR, FROZEN_MORALE, str(_emotion(actor, "fear_current")), str(_emotion(actor, "morale_current"))] })
	if not (spec["held"] as Array).is_empty():
		rows.append({ "id": "held", "saves": true, "commands": [run_cmd],
			"text": "Put %d piece(s) in the pack first: %s. The run does it." % [(spec["held"] as Array).size(), ", ".join(spec["held"])] })
	if bool(spec["swap_used"]):
		rows.append({ "id": "swap_used", "saves": true, "commands": [run_cmd],
			"text": "Mark the one swap of this path as already used. The run does it." })
	var finds_text := "Open the event now with %d find(s): %s." if scene == SCENE_EVENT_NOW \
		else "Arm %d find(s) for the next real won fight: %s. Not saved; a reload clears them."
	rows.append({ "id": "finds", "saves": scene == SCENE_EVENT_NOW, "commands": [run_cmd],
		"text": finds_text % [(prep["finds"] as Array).size(), ", ".join(spec["ids"])] })
	return rows


## The console line that runs a scene with `spec` (`mode` is "event" or "arm").
static func command(mode: String, spec: Dictionary) -> String:
	var parts: Array = ["inventory produce " + mode]
	if not (spec["ids"] as Array).is_empty():
		parts.append("ids=" + ",".join(spec["ids"]))
	if not (spec["grades"] as Array).is_empty():
		parts.append("grades=" + ",".join(spec["grades"]))
	if int(spec["count"]) > 0:
		parts.append("count=%d" % int(spec["count"]))
	if str(spec["rank"]) != "" and mode == "event":
		parts.append("rank=" + str(spec["rank"]))
	if int(spec["chooser_standing"]) > 0:
		parts.append("standing=%d" % int(spec["chooser_standing"]))
	if str(spec["chooser_id"]) != "":
		parts.append("chooser=" + str(spec["chooser_id"]))
	if str(spec["fallen"]) != "":
		parts.append("fallen=" + str(spec["fallen"]))
	if int(spec["cap"]) > 0:
		parts.append("cap=%d" % int(spec["cap"]))
	if not (spec["held"] as Array).is_empty():
		parts.append("held=" + ",".join(spec["held"]))
	if bool(spec["swap_used"]):
		parts.append("swapused")
	return " ".join(parts)


## Runs a prepared scene (no errors). event_now: held pieces into the pack, the swap mark, the frozen fear and
## morale writes, then the event under a fresh id `debug.<seq>`; publishes the intro. arm: the same marks, then the
## armed finds and options (volatile, never saved). Nothing stays written when a step fails or the event does not
## open (a stamp that is not this call's own counts as not opened): the pieces about to change are restored.
static func run(flow_ctx: FlowContext, logger: StructuredLogger, prep: Dictionary, t: int) -> FlowActionOutcome:
	var spec: Dictionary = prep["spec"]
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	var saved := _snapshot(flow_ctx, stage, prep)
	var reserved := EarningsService.open_item_rows_in_save(flow_ctx.save_data)
	for entry in prep["held"]:
		var res := InventoryService.intake(flow_ctx.save_data, prep["cfg"], entry, InventoryService.MODE_PACK_ONLY, reserved, logger, t)
		if str(res.get("result", "")) == "rejected":
			_restore(flow_ctx, stage, saved, prep)
			return FlowActionOutcome.error_outcome("held_" + str(res.get("reason_key", "refused")))
	if bool(spec["swap_used"]):
		stage[PickupEventService.SWAP_KEY] = true
	var opts := {}
	if int(spec["count"]) > 0:
		opts["count"] = int(spec["count"])
	if int(spec["cap"]) > 0:
		opts["cap"] = int(spec["cap"])
	if str(prep["chooser_id"]) != "":
		opts["chooser_id"] = str(prep["chooser_id"])
	opts["names"] = prep["names"]
	var save_reason := "debug.pickup." + str(prep["scene"])
	if prep["scene"] == SCENE_ARM:
		flow_ctx.pickup_armed = prep["finds"]
		flow_ctx.pickup_armed_opts = opts
		logger.info(t, "debug.pickup.armed", "Finds armed for the next won fight", { "finds": (prep["finds"] as Array).size() })
		var armed_outcome := FlowActionOutcome.handled_outcome()
		return armed_outcome.with_save_reason(save_reason) if not (prep["held"] as Array).is_empty() or bool(spec["swap_used"]) else armed_outcome
	var echo := _roster_echo(flow_ctx, str(prep["chooser_id"]))
	if bool(spec["frozen"]) and not echo.is_empty():
		EmotionService.set_fear_current(echo, FROZEN_FEAR, logger, t)
		EmotionService.set_morale_current(echo, FROZEN_MORALE, logger, t)
	var seq := int(stage.get(SEQ_KEY, 0)) + 1
	stage[SEQ_KEY] = seq
	opts["event_now"] = true
	var record := PickupEventService.open_after_win(flow_ctx, "debug.%d" % seq, str(spec["rank"]), prep["fallen_ids"],
		FlowStateIds.STAGE_EXPLORE, prep["finds"], t, opts)
	if record.is_empty() or int(record.get("win_t", -1)) != t or PickupEventService.is_ended(record):
		_restore(flow_ctx, stage, saved, prep)
		logger.info(t, "debug.pickup.not_opened", "Dev pickup event did not open", { "reason_key": "not_opened" })
		return FlowActionOutcome.error_outcome("not_opened")
	if bool(spec["frozen"]) and not bool(record.get("frozen", false)):
		logger.info(t, "debug.pickup.scene.frozen_not_reached", "The chooser did not freeze at fear 95", {
			"chooser": str(prep["chooser_id"]), "standing": int(echo.get("rank", 0)) })
	flow_ctx.pickup_session = { "phase": PickupSnapshotBuilder.PHASE_INTRO }
	return FlowActionOutcome.snapshot_outcome(PickupSnapshotBuilder.build(flow_ctx, t, flow_ctx.pickup_session)).with_save_reason(save_reason)


## Deep copies of what `run` may change: the stage record, the inventory block, the chooser's emotion block and the
## save request flag.
static func _snapshot(flow_ctx: FlowContext, stage: Dictionary, prep: Dictionary) -> Dictionary:
	var echo := _roster_echo(flow_ctx, str(prep["chooser_id"]))
	var inv_v: Variant = flow_ctx.save_data.get("inventory", null)
	return { "stage": stage.duplicate(true), "has_inv": inv_v is Dictionary,
		"inventory": (inv_v as Dictionary).duplicate(true) if inv_v is Dictionary else {},
		"has_emotion": echo.has("emotion"), "emotion": (echo["emotion"] as Dictionary).duplicate(true) if echo.get("emotion", null) is Dictionary else {},
		"request": flow_ctx.save_request, "reason": flow_ctx.save_request_reason }


static func _restore(flow_ctx: FlowContext, stage: Dictionary, saved: Dictionary, prep: Dictionary) -> void:
	stage.clear()
	stage.merge(saved["stage"], true)
	if bool(saved["has_inv"]):
		flow_ctx.save_data["inventory"] = saved["inventory"]
	var echo := _roster_echo(flow_ctx, str(prep["chooser_id"]))
	if not echo.is_empty():
		if bool(saved["has_emotion"]):
			echo["emotion"] = saved["emotion"]
		else:
			echo.erase("emotion")
	flow_ctx.save_request = bool(saved["request"])
	flow_ctx.save_request_reason = str(saved["reason"])


## Find or held entries for `ids`, from the placeholder definitions. An unknown id adds an `unknown_id` error.
## `find_prefix` non-empty makes find entries (`find_id` = prefix + index).
static func _entries(ids: Array, grades: Array, defs: Dictionary, inv_cfg: Dictionary, find_prefix: String,
		errors: Array) -> Array:
	var out: Array = []
	for i in ids.size():
		var type_id := str(ids[i])
		var def_v: Variant = defs.get(type_id, null)
		if not (def_v is Dictionary):
			errors.append({ "key": "unknown_id", "text": "Unknown placeholder id: %s." % type_id })
			continue
		var entry := { "type_id": type_id, "kind": str((def_v as Dictionary).get("kind", "")),
			"grade": str(grades[i]) if i < grades.size() else str((def_v as Dictionary).get("grade", "")), "quantity": 1 }
		var bad := InventoryService.check_entry(inv_cfg, entry)
		if bad != "":
			errors.append({ "key": bad, "text": "%s cannot be used (%s)." % [type_id, bad] })
			continue
		if find_prefix != "":
			entry["find_id"] = find_prefix + str(i)
		out.append(entry)
	return out


static func _pack_free(flow_ctx: FlowContext, inv_cfg: Dictionary) -> int:
	return InventoryService.pack_free(flow_ctx.save_data, inv_cfg, EarningsService.open_item_rows_in_save(flow_ctx.save_data))


static func _roster_echo(flow_ctx: FlowContext, id: String) -> Dictionary:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var roster_v: Variant = (sanctum_v as Dictionary).get("roster", []) if sanctum_v is Dictionary else []
	for e_v: Variant in (roster_v as Array if roster_v is Array else []):
		if e_v is Dictionary and str((e_v as Dictionary).get("id", "")) == id:
			return e_v
	return {}


static func _emotion(echo: Dictionary, key: String) -> Variant:
	var emo_v: Variant = echo.get("emotion", {})
	return (emo_v as Dictionary).get(key, "?") if emo_v is Dictionary else "?"


## A whole number from an int, a whole float or a digit string; -1 for anything else.
static func _whole(v: Variant) -> int:
	if v is int:
		return v
	if v is float and floorf(v) == v:
		return int(v)
	if v is String and (v as String).is_valid_int():
		return (v as String).to_int()
	return -1


static func _bad(key: String) -> Dictionary:
	return { "ok": false, "reason_key": key, "spec": {} }
