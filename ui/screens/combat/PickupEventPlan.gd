class_name PickupEventPlan
extends RefCounted

## Pure timeline of the pickup intro (V2-ITEM-001b U3). Port of `pickup-event-playable.html` (the contract,
## D-36): `buildPlan`, `pointerFor`, `tempo`, `introView`. Takes a `flow.pickup` snapshot, returns plain data.
## No scene object, no animation object, no randomness: every number comes from snapshot keys or from `hash_of` over
## situation_id and find ids. Positions are in the 1280 x 720 design space of the mockup; `norm` gives 0..1.
##
## Differences from the mockup, on purpose: finds sit in one row (D-52; the mockup has iso cells and piles);
## a frozen chooser never has a walk stop, so the mockup's frozen walk branches are not ported; the idle sway of
## the neutral reaction is left to the scene (it would make the last frame depend on time).
##
## Space: every position is in the 1280 x 720 design space. The scene maps it to the real board and to the real pack
## slot nodes (U4 and U5 own that mapping); `norm` fields give 0..1. `opts.positions` ({ echo id: {x, y} } in design
## space) replaces the mockup battle spots as the Echoes' start positions.
## A scene must handle `plan.valid == false` (no chooser, error snapshot, pointer start below 0): show no intro.

const DESIGN_W := 1280.0
const DESIGN_H := 720.0

# Beat times, seconds. Mockup line 666 (tItems, tRow0, tRowEnd, tP0).
const T_ITEMS := 0.35
const ROW_FORM := 0.9
const POINTER_AFTER_ROW := 0.7
# Mockup line 670 and 671: pointer rest to step-out gap, step-out length, reduced-motion values.
const STEP_GAP := 0.2
const STEP_LEN := 0.45
const STEP_LEN_REDUCED := 0.15
const POINTER_REDUCED := 0.5
# Mockup line 773 and 774: item stagger and reveal length.
const ITEM_STAGGER := 0.08
const REVEAL_LEN := 0.25
const REVEAL_LEN_REDUCED := 0.15
# Mockup line 778 and 780: emotion beat and idle times.
const BARK_AFTER_LAST := 0.15
const IDLE_AFTER_BARK := 0.3
const IDLE_AFTER_DEPOSIT := 0.45
# Mockup line 781: dim of the items that stay on the field.
const DIM_OPACITY := 0.6
# Mockup line 566, 568 and 570: pointer slow-down distance, run-in time, minimum travel, minimum cruise, step.
const POINTER_DECEL_DIST := 2.5
const POINTER_ACCEL := 0.4
const POINTER_MIN_TRAVEL := 6.0
const POINTER_MIN_CRUISE := 0.25
const POINTER_T_STEP := 0.05
# Mockup line 602: base length 2.0 s plus 0.2 s times a hash value 0..4 (the mockup used scenario id and chooser index).
const POINTER_T_BASE := 2.0
const POINTER_T_VARY := 0.2
const POINTER_T_STEPS := 5
const POINTER_SAMPLE_DT := 0.05
# Mockup line 619: walk cap, fly time, typing speed.
const WALK_CAP := 3.4
const FLY_LEN := 0.34
const TYPE_CPS := 24.0
# Mockup line 688: reference distances and clamp of the walk time scale.
const REF_FIRST := 90.0
const REF_NEXT := 60.0
const DIST_SCALE_MIN := 0.6
const DIST_SCALE_MAX := 1.35
# Mockup lines 687 and 758: stand distance from an item.
const STAND_OFF := 34.0
# Mockup lines 712 (worth back-off 44 and approach), 716 (dwell) and 754 (safe: step back 10, 0.25 s).
const WORTH_APPROACH := 0.45
const WORTH_DWELL := 0.45
const WORTH_BACK_OFF := 44.0
const SAFE_STEP_BACK := 10.0
const SAFE_STEP_TIME := 0.25
const SAFE_PRE_EXTRA := 0.25
# Mockup lines 757 to 760 (and 731 to 737 for the same shape in a walk): frozen chooser walks 40 percent of the way, trembles, waits.
const FROZEN_FRAC := 0.4
const FROZEN_STEP := 0.35
const FROZEN_TREMBLE := 1.1
const FROZEN_WAIT := 1.35
# Mockup line 746 and 748: try item lift is longer by 0.1 s.
const TRY_LIFT_EXTRA := 0.1
# Mockup line 557 to 560: row spot, battle spots, held item height above the head.
const ROW_SPACING := 96.0
const ROW_Y := 486.0
const OUT_STEP := 44.0
const HEAD := 54.0
# Not mockup values: the D-52 one-row field (the mockup uses iso cells).
const FIELD_STEP := 120.0
const FIELD_Y := 300.0
const SLOT_X0 := 520.0
const SLOT_STEP := 80.0
const SLOT_Y := 640.0
const PACK_SLOTS_DEFAULT := 4
# Presentation constant (same documented reason as D-68): the pick rule never reads it. It copies the config default
# `data.inventory.pickup.severe_from_status`; Jeff reviews it. The safe / bold reading of the `state` reason is a U3
# choice: the mockup gives each Echo a manner trait that the core does not have.
const STATUS_AFRAID_MAX := "burdened"
const STATUS_LADDER: Array = ["hollow", "fraying", "strained", "pressed", "burdened", "hesitant", "uncertain",
	"grounded", "whole", "radiant"]

# Reason table: walk seconds for the first and later picks, touch, lift, hold before the pack, lift ease.
# Mockup lines 612 to 618 (froze is not ported: a frozen chooser has no stops; build maps it to likes).
const RS: Dictionary = {
	"likes": { "w": [0.70, 0.60], "touch": 0.10, "lift": 0.25, "ease": "back", "hold": 0.20 },
	"worth": { "w": [0.60, 0.60], "touch": 0.10, "lift": 0.40, "ease": "smooth", "hold": 0.20 },
	"safe": { "w": [0.95, 0.70], "touch": 0.10, "lift": 0.20, "ease": "smooth", "hold": 0.20 },
	"bold": { "w": [0.50, 0.40], "touch": 0.10, "lift": 0.15, "ease": "back", "hold": 0.20 },
	"fit": { "w": [0.45, 0.45], "touch": 0.0, "lift": 0.20, "ease": "smooth", "hold": 0.12 },
}


# ---------------------------------------------------------------------------
# Public
# ---------------------------------------------------------------------------

## Stable integer hash (FNV-1a, 31 bits) over `parts` joined with "|" (an Array part is joined the same way).
## No engine hash: its value may change.
static func hash_of(parts: Array) -> int:
	var texts: Array = []
	for p: Variant in parts:
		texts.append("|".join((p as Array).map(func(x: Variant) -> String: return str(x))) if p is Array else str(p))
	var joined := "|".join(texts)
	var h := 2166136261
	for i in joined.length():
		h = ((h ^ joined.unicode_at(i)) * 16777619) & 0x7FFFFFFF
	return h


## The whole intro as data. `opts.reduced` = reduced motion (mockup `rm`); `opts.positions` = Echo start positions (see the header). Returns { valid: false, ... } when the
## snapshot has no chooser; every key then still exists so `frame_at` stays total.
static func build(snapshot: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var d := _d(snapshot.get("data", {}))
	var rm := bool(opts.get("reduced", false))
	var row: Array = d.get("row", []) if d.get("row", []) is Array else []
	var n := row.size()
	var cidx := -1
	for i in n:
		if bool((row[i] as Dictionary).get("is_chooser", false)):
			cidx = i
	var ptr := _d(d.get("pointer", {}))
	if cidx < 0 or str(d.get("error", "")) != "" or int(ptr.get("start", -1)) < 0:
		return _invalid(d, rm)

	var finds: Array = d.get("finds", []) if d.get("finds", []) is Array else []
	var frozen := bool(d.get("frozen", false))
	var case_key := str(d.get("case", ""))
	var chooser := row[cidx] as Dictionary
	var standing := int(chooser.get("standing", 1))
	var reason := _tempo_reason(case_key, frozen, str(d.get("reason", "")), str(chooser.get("status", "")))
	var tp := tempo(standing)
	# A frozen chooser has no stops, so the table is read only for its lift ease; likes is the explicit choice.
	var rs: Dictionary = RS["likes" if reason == "froze" else reason]
	var emo := emo_style(str(d.get("reaction", "")), case_key, frozen)

	var rows: Array = []
	var battles: Array = []
	var given := _d(opts.get("positions", {}))
	for k in n:
		rows.append(_row_spot(k, n))
		var gp := _d(given.get(str((row[k] as Dictionary).get("id", "")), {}))
		battles.append(Vector2(float(gp["x"]), float(gp["y"])) if gp.has("x") and gp.has("y") else _battle_spot(k))
	var out_pos: Vector2 = (rows[cidx] as Vector2) + Vector2(0.0, -OUT_STEP)

	var f_n := finds.size()
	var rest: Array = []
	for i in f_n:
		rest.append(_field_spot(i, f_n))

	# World beats (mockup lines 666 to 673).
	var t_items := T_ITEMS
	var t_row0 := t_items
	var t_row_end := t_row0 + ROW_FORM
	var t_p0 := t_row0 + POINTER_AFTER_ROW
	var sit := str(d.get("situation_id", ""))
	var find_ids: Array = finds.map(func(f: Variant) -> String: return str((f as Dictionary).get("find_id", "")))
	var pp := _pointer_plan(n, int(ptr["start"]), cidx, maxi(1, int(ptr.get("laps", 1))),
		POINTER_T_BASE + POINTER_T_VARY * float(hash_of([sit, find_ids]) % POINTER_T_STEPS))
	var t_pointer := POINTER_REDUCED if rm else float(pp["T"])
	var t_pend := t_p0 + t_pointer
	var t_s0 := t_pend + STEP_GAP
	var t_s1 := t_s0 + (STEP_LEN_REDUCED if rm else STEP_LEN)

	# Stops in pick order, then the held-up find.
	var stops: Array = []
	var by_id := {}
	for f_v: Variant in finds:
		by_id[str((f_v as Dictionary).get("find_id", ""))] = f_v
	var picked: Array = finds.filter(func(f: Variant) -> bool: return str((f as Dictionary).get("status", "")) == "taken")
	picked.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("pick_index", 0)) < int((b as Dictionary).get("pick_index", 0)))
	for f_v: Variant in picked:
		stops.append({ "find_id": str((f_v as Dictionary)["find_id"]), "is_try": false })
	for f_v: Variant in finds:
		if str((f_v as Dictionary).get("status", "")) == "tried":
			stops.append({ "find_id": str((f_v as Dictionary)["find_id"]), "is_try": true })

	# The chooser's walk (mockup lines 674 to 766).
	var trk := { "segs": [], "t": t_s0, "p": rows[cidx] }
	_go(trk, t_s1 - t_s0, out_pos, "back", 0.0)
	_wait(trk, float(tp["pre"]) + (SAFE_PRE_EXTRA if reason == "safe" else 0.0))
	var t_w0: float = trk["t"]
	var cur := out_pos
	var sum_w := 0.0
	for k in stops.size():
		var s: Dictionary = stops[k]
		var ip: Vector2 = rest[_index_of(find_ids, str(s["find_id"]))]
		var stand := ip + _unit(cur - ip) * STAND_OFF
		var dist := (stand - cur).length()
		var base: float = float((rs["w"] as Array)[1 if k > 0 else 0]) * clampf(dist / (REF_NEXT if k > 0 else REF_FIRST),
			DIST_SCALE_MIN, DIST_SCALE_MAX)
		var w: float = float((rs["w"] as Array)[0]) if reason == "fit" else base / float(tp["pace"])
		w += 0.0 if reason == "fit" else float(tp["hitch"])
		s["stand"] = stand
		s["w"] = w
		sum_w += w
		cur = stand
	var w_scale := WALK_CAP / sum_w if sum_w > WALK_CAP else 1.0

	var recs := {}
	var hops: Array = []
	var trem: Array = []
	var lean: Array = [{ "t": t_s1, "v": 0.0, "e": "smooth" }]
	var glints: Array = []
	var walk: Array = []
	var slot_of := {}
	var pack_before := _pack_before(d, finds)
	var unlisted := _unlisted(d)
	for u in unlisted:
		pack_before.append("unlisted_%d" % u)
	var slot_count := _slot_count(d, pack_before.size(), picked.size())
	var next_slot := pack_before.size()
	for k in stops.size():
		var s: Dictionary = stops[k]
		var fid := str(s["find_id"])
		var is_try: bool = s["is_try"]
		var ip: Vector2 = rest[_index_of(find_ids, fid)]
		var from: Vector2 = trk["p"]
		var stand: Vector2 = s["stand"]
		var sg := signf(ip.x - from.x)
		sg = 1.0 if sg == 0.0 else sg
		var w: float = float(s["w"]) * w_scale
		var r := { "walk0": trk["t"] }
		if k == 0:
			lean.append({ "t": trk["t"], "v": sg * float(tp["lean"]), "e": "smooth" })
		match reason:
			"worth":
				if k == 0 and not rm:
					var sp := stand + _unit(from - stand) * WORTH_BACK_OFF
					_go(trk, WORTH_APPROACH * w_scale, sp, "out", 0.0)
					lean.append({ "t": trk["t"], "v": sg * 5.0, "e": "smooth" })
					glints.append({ "find_id": fid, "t": float(trk["t"]) + 0.05, "dur": 0.35 })
					_wait(trk, WORTH_DWELL)
					_go(trk, WORTH_APPROACH * w_scale, stand, "smooth", 0.0)
				else:
					_walk_to(trk, hops, tp, reason, rm, from, stand, w, "smooth", 0.0)
			"safe":
				var du := _unit(stand - from)
				var bow := 14.0 * (1.0 if -du.y <= 0.0 else -1.0)
				_walk_to(trk, hops, tp, reason, rm, from, stand, w, "lin", 0.0 if rm else bow)
			"bold":
				if rm:
					_go(trk, 0.15, stand, "lin", 0.0)
				else:
					_go(trk, w * 0.9, stand + _unit(stand - from) * 8.0, "out", 0.0)
					_go(trk, 0.12, stand, "smooth", 0.0)
			_:
				if rm:
					_go(trk, 0.15, stand, "lin", 0.0)
				else:
					_go(trk, w, stand, "lin" if reason == "fit" else "smooth", 0.0)
		r["arrive"] = trk["t"]
		if k == 0:
			lean.append({ "t": trk["t"], "v": 0.0, "e": "smooth" })
		var touch := 0.0 if rm else float(rs["touch"])
		if touch > 0.0:
			hops.append({ "t": trk["t"], "dur": touch, "amp": 0.0 if reason == "worth" else 4.0, "sq": 0.08 })
			_wait(trk, touch)
		var lift := 0.15 if rm else (float(rs["lift"]) + TRY_LIFT_EXTRA if is_try else float(rs["lift"]))
		r["lift0"] = trk["t"]
		r["lift1"] = float(trk["t"]) + lift
		if not is_try:
			r["fly0"] = float(r["lift1"]) + (0.0 if rm else float(rs["hold"]))
			r["fly1"] = float(r["fly0"]) + (0.15 if rm else FLY_LEN)
			slot_of[fid] = next_slot
			next_slot += 1
		_wait(trk, maxf(0.0, lift - (0.0 if rm else 0.1)))
		if not is_try and reason == "safe" and not rm:
			_go(trk, SAFE_STEP_TIME, (trk["p"] as Vector2) + _unit(out_pos - (trk["p"] as Vector2)) * SAFE_STEP_BACK, "smooth", 0.0)
		recs[fid] = r
		walk.append({ "find_id": fid, "k": k, "is_try": is_try, "t0": r["walk0"], "t1": r["arrive"],
			"stand": _pt(stand), "stand_norm": _norm(stand) })
	if frozen and f_n > 0:
		var ip0: Vector2 = rest[0]
		var st := ip0 + _unit(out_pos - ip0) * STAND_OFF
		if rm:
			_wait(trk, 0.4)
		else:
			_go(trk, FROZEN_STEP, out_pos.lerp(st, FROZEN_FRAC), "out", 0.0)
			trem.append({ "t0": trk["t"], "t1": float(trk["t"]) + FROZEN_TREMBLE, "amp": 1.0, "hz": 9.0, "ramp": 0.12, "decay": 0.25 })
			_wait(trk, FROZEN_WAIT)

	var t_a: float = trk["t"]
	for fid: Variant in recs:
		t_a = maxf(t_a, float((recs[fid] as Dictionary).get("fly1", 0.0)))
	var try_id := ""
	for s: Dictionary in stops:
		if bool(s["is_try"]):
			try_id = str(s["find_id"])
	var t_b := (float((recs[try_id] as Dictionary)["lift1"]) + 0.05 if try_id != "" else (t_a if frozen else t_a - BARK_AFTER_LAST)) + float(tp["delay"])
	var band := PickupUiText.standing_band(standing)
	var bark_text := PickupUiText.bark(case_key, str(d.get("reaction", "")), str(d.get("reason", "")), band, cidx)
	var typed := 0.0 if rm else float(bark_text.length()) / TYPE_CPS
	var t_bark_end := t_b + typed
	var t_idle := maxf(t_bark_end + IDLE_AFTER_BARK, t_a + IDLE_AFTER_DEPOSIT)

	var out_finds: Array = []
	for i in f_n:
		var f: Dictionary = finds[i]
		var fid := str(f.get("find_id", ""))
		var r: Dictionary = recs.get(fid, {})
		var walked := not r.is_empty()
		out_finds.append({
			"find_id": fid, "index": i, "status": str(f.get("status", "")), "pick_index": int(f.get("pick_index", -1)),
			"rest": _pt(rest[i]), "norm": _norm(rest[i]),
			"appear": t_items + ITEM_STAGGER * float(i),
			"reveal": float(r["arrive"]) if walked else t_a,
			"reveal_len": REVEAL_LEN_REDUCED if rm else REVEAL_LEN,
			"walked": walked, "is_try": fid == try_id,
			"walk0": float(r["walk0"]) if walked else -1.0,
			"arrive": float(r["arrive"]) if walked else -1.0,
			"lift0": float(r["lift0"]) if walked else -1.0,
			"lift1": float(r["lift1"]) if walked else -1.0,
			"lift_ease": str(rs["ease"]),
			"fly0": float(r["fly0"]) if r.has("fly0") else -1.0,
			"fly1": float(r["fly1"]) if r.has("fly1") else -1.0,
			"slot": int(slot_of.get(fid, -1)),
		})
	var pack_after: Array = pack_before.duplicate()
	for f_v: Variant in picked:
		pack_after.append(_pack_id_of(d, str((f_v as Dictionary)["find_id"])))
	var centers: Array = []
	for i in slot_count:
		centers.append({ "x": _slot_center(i).x, "y": _slot_center(i).y, "norm": _norm(_slot_center(i)) })
	var samples: Array = []
	var steps := int(ceil(float(pp["T"]) / POINTER_SAMPLE_DT))
	for i in steps + 1:
		var ts := minf(float(i) * POINTER_SAMPLE_DT, float(pp["T"]))
		samples.append({ "t": ts, "idx": _pointer_idx(pp, ts) })
	var rows_out: Array = []
	for k in n:
		var e: Dictionary = row[k]
		rows_out.append({ "id": str(e.get("id", "")), "standing": int(e.get("standing", 1)),
			"status": str(e.get("status", "")), "chosen": k == cidx,
			"rest": _pt(rows[k]), "battle": _pt(battles[k]), "norm": _norm(rows[k]) })
	var beats: Array = [
		{ "name": "last_enemy_falls", "t": 0.0 },
		{ "name": "items_appear", "t": t_items },
		{ "name": "row_forms", "t": t_row0 },
		{ "name": "pointer_runs", "t": t_p0 },
		{ "name": "chooser_steps_out", "t": t_s0 },
		{ "name": "walks_to_picks" if not picked.is_empty() else ("tries_a_find" if try_id != "" else "takes_nothing"), "t": t_w0 },
		{ "name": "reaction", "t": t_b },
		{ "name": "idle", "t": t_idle },
	]
	return {
		"valid": true, "reduced": rm, "situation_id": sit,
		"chooser_id": str(chooser.get("id", "")), "chooser_index": cidx, "n": n,
		"case": case_key, "reason": str(d.get("reason", "")), "tempo_reason": reason, "frozen": frozen,
		"reaction": str(d.get("reaction", "")), "emo": emo, "offered": bool(_d(d.get("swap", {})).get("offered", false)),
		"design": { "w": DESIGN_W, "h": DESIGN_H },
		"total": t_idle,
		"times": { "items": t_items, "row0": t_row0, "row_end": t_row_end, "pointer0": t_p0, "pointer_end": t_pend,
			"step0": t_s0, "step1": t_s1, "walk0": t_w0, "deposit_end": t_a, "bark": t_b, "bark_end": t_bark_end, "idle": t_idle },
		"beats": beats,
		"row": rows_out,
		"pointer": { "n": n, "start": int(ptr["start"]), "laps": maxi(1, int(ptr.get("laps", 1))), "decided": cidx,
			"travel": float(pp["U"]), "length": float(pp["T"]), "plan": pp, "samples": samples },
		"finds": out_finds,
		"walk": walk,
		"track": { "t0": t_s0, "p0": _pt(rows[cidx]), "segs": trk["segs"], "end": _pt(trk["p"]), "end_norm": _norm(trk["p"]) },
		"out_pos": _pt(out_pos), "out_norm": _norm(out_pos),
		"hops": hops, "tremors": trem, "lean": lean, "glints": glints,
		"pack": { "before": pack_before, "after": pack_after, "slot_count": slot_count, "unlisted": unlisted, "centers": centers,
			"tone": str(_d(d.get("pack", {})).get("tone", "plain")),
			"pulse_at": float((recs[try_id] as Dictionary)["lift1"]) if try_id != "" else -1.0, "held_find": try_id },
		"bark": { "text": bark_text, "case": case_key, "reaction": str(d.get("reaction", "")),
			"reason": str(d.get("reason", "")), "band": band, "variant": cidx,
			"chars": bark_text.length(), "t0": t_b, "t1": t_bark_end },
	}


## The visible state at time `t` seconds. Total: any `t` (before 0, after the end, NaN) gives a finite frame.
static func frame_at(plan: Dictionary, t_in: float) -> Dictionary:
	if not bool(plan.get("valid", false)):
		return _empty_frame()
	var total := float(plan["total"])
	var t := 0.0 if is_nan(t_in) else clampf(t_in, 0.0, total)
	var tm: Dictionary = plan["times"]
	var rm := bool(plan["reduced"])
	var rows: Array = plan["row"]
	var out_echoes: Array = []
	var tag_all := _ph(t, float(tm["row_end"]) - 0.3, float(tm["row_end"]) - 0.05, "smooth")
	for k in rows.size():
		var e: Dictionary = rows[k]
		var chosen := bool(e["chosen"])
		var pos := _row_pos(plan, k, t)
		var o := 1.0
		var tag_o := tag_all
		var sh := 1.0
		var tag_dy := 0.0
		var body := _body_neutral()
		if chosen:
			pos = _chooser_pos(plan, t)
			body = _body_at(plan, t)
			sh = 1.0 + 0.3 * _ph(t, float(tm["step0"]), float(tm["step1"]), "smooth")
			if t >= float(tm["step0"]):
				tag_dy = 4.0 * (1.0 - _ph(t, float(tm["step0"]) + 0.15, float(tm["step0"]) + 0.33, "out"))
		else:
			var s := _ph(t, float(tm["step0"]), float(tm["step0"]) + 0.3, "smooth")
			pos = Vector2(pos.x, pos.y + 8.0 * s)
			o = 1.0 - 0.35 * _ph(t, float(tm["step0"]) + 0.05, float(tm["step0"]) + 0.35, "smooth")
			tag_o = tag_all * (1.0 - s)
		var item := { "id": str(e["id"]), "chosen": chosen, "x": pos.x, "y": pos.y, "o": o, "tag_o": tag_o, "tag_dy": tag_dy, "sh": sh }
		item.merge(body)
		out_echoes.append(item)

	var items := {}
	for f_v: Variant in plan["finds"]:
		var f: Dictionary = f_v
		items[str(f["find_id"])] = _item_frame(plan, f, t)

	var pk: Dictionary = plan["pack"]
	var slots: Array = []
	var lit: Array = []
	for i in int(pk["slot_count"]):
		slots.append(str((pk["before"] as Array)[i]) if i < (pk["before"] as Array).size() else "")
		lit.append(0.0)
	var after: Array = pk["after"]
	for f_v: Variant in plan["finds"]:
		var f: Dictionary = f_v
		if int(f["slot"]) >= 0 and t >= float(f["fly1"]) and int(f["slot"]) < slots.size():
			slots[int(f["slot"])] = str(after[int(f["slot"])])
			lit[int(f["slot"])] = 1.0 - _ph(t, float(f["fly1"]), float(f["fly1"]) + 0.25, "out")
	var used := 0
	for s_v: Variant in slots:
		used += 1 if str(s_v) != "" else 0
	var pulse_at := float(pk["pulse_at"])
	var pulse := sin(PI * _pr(t, pulse_at, pulse_at + 0.4)) if pulse_at >= 0.0 else 0.0

	var cp := _chooser_pos(plan, t)
	var pointer: Dictionary = plan["pointer"]
	var light_pos := cp
	var light_o := 1.0
	var t_p0 := float(tm["pointer0"])
	if not (rm or t >= float(tm["pointer_end"])):
		var q := _pointer_xy(pointer["plan"], t - t_p0, rows)
		light_pos = Vector2(q["x"], q["y"])
		light_o = float(q["o"])
	var light := { "x": light_pos.x, "y": light_pos.y,
		"o": light_o * _ph(t, t_p0, t_p0 + 0.15, "smooth") * (1.0 - _ph(t, float(tm["walk0"]), float(tm["walk0"]) + 0.4, "smooth")),
		"s": 1.0 + 0.22 * _ph(t, float(tm["pointer_end"]) - 0.3, float(tm["pointer_end"]) + 0.2, "smooth") }

	var bark: Dictionary = plan["bark"]
	var chars := int(bark["chars"])
	var typed := chars if rm else clampi(int(floor((t - float(bark["t0"])) * TYPE_CPS)), 0, chars)
	var t_idle := float(tm["idle"])
	return {
		"t": t, "phase": "idle" if t >= t_idle else "intro", "beat": _beat_at(plan, t),
		"echoes": out_echoes, "items": items,
		"pack": { "p": _ph(t, float(tm["step0"]), float(tm["step0"]) + 0.4, "out"), "slots": slots, "lit": lit,
			"used": used, "pulse": pulse, "tone": _tone_for(used, slots.size()) },
		"light": light, "pointer_speed": 0.0 if rm else _pointer_speed(pointer["plan"], t - t_p0),
		"bark": { "chars": typed, "total": chars, "o": _ph(t, float(bark["t0"]), float(bark["t0"]) + 0.12, "smooth") },
		"skip_o": _ph(t, 0.2, 0.35, "smooth") * (1.0 - _ph(t, t_idle - 0.1, t_idle, "smooth")),
		"cont_o": _ph(t, t_idle - 0.25, t_idle, "smooth"),
		"chooser_end": (plan["track"]["end"] as Dictionary).duplicate(),
	}


## The state Skip jumps to. Item and pack state come from the snapshot statuses; the chooser end point and `t` (the
## plan total) come from `build`. A test compares it with `frame_at(build(snapshot), total)`.
static func skip_to_idle(snapshot: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var plan := build(snapshot, opts)
	if not bool(plan["valid"]):
		return _empty_frame()
	var d := _d(snapshot.get("data", {}))
	var rm := bool(plan["reduced"])
	var rows: Array = plan["row"]
	var end_p := _vec(plan["track"]["end"])
	var echoes: Array = []
	for k in rows.size():
		var e: Dictionary = rows[k]
		var item := { "id": str(e["id"]), "chosen": bool(e["chosen"]) }
		if bool(e["chosen"]):
			item.merge({ "x": end_p.x, "y": end_p.y, "o": 1.0, "tag_o": 1.0, "tag_dy": 0.0, "sh": 1.3 })
			item.merge(_body_end(str(plan["emo"]), rm))
		else:
			var r := _vec(e["rest"])
			item.merge({ "x": r.x, "y": r.y + 8.0, "o": 0.65, "tag_o": 0.0, "tag_dy": 0.0, "sh": 1.0 })
			item.merge(_body_neutral())
		echoes.append(item)
	var items := {}
	var slots: Array = []
	var lit: Array = []
	for i in int((plan["pack"] as Dictionary)["slot_count"]):
		slots.append(str(((plan["pack"] as Dictionary)["before"] as Array)[i]) if i < ((plan["pack"] as Dictionary)["before"] as Array).size() else "")
		lit.append(0.0)
	var head := end_p + Vector2(0.0, -HEAD)
	for f_v: Variant in d.get("finds", []):
		var f: Dictionary = f_v
		var fid := str(f.get("find_id", ""))
		var rest_p := _vec(_find_plan(plan, fid)["rest"])
		var it := { "vis": "svg", "x": rest_p.x, "y": rest_p.y, "o": DIM_OPACITY, "sc": 1.0, "df": 1.0, "rev": 1.0, "held": false,
			"glint": -1.0, "layer": 0, "slot": -1 }
		match str(f.get("status", "")):
			"taken":
				var slot := int(_find_plan(plan, fid)["slot"])
				it.merge({ "vis": "tile", "x": SLOT_X0 + SLOT_STEP * float(slot), "y": SLOT_Y, "o": 1.0, "sc": 1.0, "df": 0.0, "slot": slot }, true)
				if slot >= 0 and slot < slots.size():
					slots[slot] = str(((plan["pack"] as Dictionary)["after"] as Array)[slot])
			"tried":
				it.merge({ "x": head.x, "y": head.y, "o": 1.0, "df": 0.0, "held": true }, true)
		items[fid] = it
	var used := 0
	for s_v: Variant in slots:
		used += 1 if str(s_v) != "" else 0
	return {
		"t": float(plan["total"]), "phase": "idle", "beat": "idle",
		"echoes": echoes, "items": items,
		"pack": { "p": 1.0, "slots": slots, "lit": lit, "used": used, "pulse": 0.0, "tone": _tone_for(used, slots.size()) },
		"light": { "x": end_p.x, "y": end_p.y, "o": 0.0, "s": 1.22 },
		"pointer_speed": 0.0,
		"bark": { "chars": int((plan["bark"] as Dictionary)["chars"]), "total": int((plan["bark"] as Dictionary)["chars"]), "o": 1.0 },
		"skip_o": 0.0, "cont_o": 1.0, "chooser_end": (plan["track"]["end"] as Dictionary).duplicate(),
	}


## Speed table by Standing (mockup lines 606 to 610): pre-walk pause, hitch, pace, reaction delay, lean degrees.
static func tempo(standing: int) -> Dictionary:
	var s := clampi(standing, 1, 9)
	var k := float(s - 1) / 4.0 if s <= 5 else 1.0 + float(s - 5) / 4.0
	return {
		"pre": snappedf(_at3(k, 0.6, 0.35, 0.1), 0.01), "hitch": snappedf(_at3(k, 0.12, 0.06, 0.0), 0.01),
		"pace": _at3(k, 0.8, 0.95, 1.0), "delay": snappedf(_at3(k, 0.2, 0.1, 0.0), 0.01),
		"lean": -4.0 if s <= 2 else (5.0 if s >= 8 else 3.0),
	}


## "plus", "minus", "lean" (afraid or frozen: a small lean away) or "neutral" (some fit).
static func emo_style(reaction: String, case_key: String, frozen: bool) -> String:
	if reaction == "plus":
		return "plus"
	if reaction == "minus":
		return "minus"
	return "lean" if frozen or case_key == "C5" or case_key == "frozen" else "neutral"


# ---------------------------------------------------------------------------
# Plan helpers
# ---------------------------------------------------------------------------

static func _invalid(d: Dictionary, rm: bool) -> Dictionary:
	return { "valid": false, "reduced": rm, "total": 0.0, "situation_id": str(d.get("situation_id", "")),
		"beats": [], "finds": [], "row": [], "walk": [] }


static func _empty_frame() -> Dictionary:
	return { "t": 0.0, "phase": "idle", "beat": "idle", "echoes": [], "items": {},
		"pack": { "p": 0.0, "slots": [], "lit": [], "used": 0, "pulse": 0.0, "tone": "plain" },
		"light": { "x": 0.0, "y": 0.0, "o": 0.0, "s": 1.0 }, "pointer_speed": 0.0,
		"bark": { "chars": 0, "total": 0, "o": 0.0 }, "skip_o": 0.0, "cont_o": 1.0, "chooser_end": { "x": 0.0, "y": 0.0 } }


## Snapshot reason class to the mockup's reason table. A case where everything fits is "fit" whatever the class.
static func _tempo_reason(case_key: String, frozen: bool, reason: String, status: String) -> String:
	if frozen or case_key == "frozen":
		return "froze"
	if case_key == "C1" or case_key == "C3":
		return "fit"
	match reason:
		"sense":
			return "worth"
		"state":
			var at: int = STATUS_LADDER.find(status)
			return "safe" if at >= 0 and at <= STATUS_LADDER.find(STATUS_AFRAID_MAX) else "bold"
	return "likes"


static func _pack_before(d: Dictionary, finds: Array) -> Array:
	var taken := {}
	for f_v: Variant in finds:
		if str((f_v as Dictionary).get("status", "")) == "taken":
			taken[str((f_v as Dictionary).get("find_id", ""))] = true
	var out: Array = []
	var slots_v: Variant = _d(d.get("pack", {})).get("slots", [])
	for s_v: Variant in (slots_v if slots_v is Array else []):
		var s := _d(s_v)
		var fid := str(s.get("find_id", ""))
		if fid == "" or not taken.has(fid):
			out.append(str(s.get("id", "")))
	return out


## Occupied slots the snapshot cannot name: `pack.carried` counts open rows of other stages and unlisted entries.
static func _unlisted(d: Dictionary) -> int:
	var pk := _d(d.get("pack", {}))
	var listed: Variant = pk.get("slots", [])
	return maxi(0, int(pk.get("carried", 0)) - (listed as Array).size() if listed is Array else 0)


## Mockup `packTone` (line 379): full when no slot is free, near when one is free, else plain.
static func _tone_for(used: int, slot_count: int) -> String:
	if used >= slot_count:
		return "full"
	return "near" if used == slot_count - 1 else "plain"


static func _pack_id_of(d: Dictionary, find_id: String) -> String:
	var slots_v: Variant = _d(d.get("pack", {})).get("slots", [])
	for s_v: Variant in (slots_v if slots_v is Array else []):
		if str(_d(s_v).get("find_id", "")) == find_id:
			return str(_d(s_v).get("id", ""))
	return find_id


static func _slot_count(d: Dictionary, before: int, picked: int) -> int:
	var cap := int(_d(d.get("pack", {})).get("capacity", 0))
	return maxi(cap if cap > 0 else PACK_SLOTS_DEFAULT, before + picked)


static func _find_plan(plan: Dictionary, find_id: String) -> Dictionary:
	for f_v: Variant in plan["finds"]:
		if str((f_v as Dictionary)["find_id"]) == find_id:
			return f_v
	return {}


static func _index_of(ids: Array, id: String) -> int:
	return maxi(0, ids.find(id))


static func _row_spot(k: int, n: int) -> Vector2:
	return Vector2(DESIGN_W / 2.0 + (float(k) - float(n - 1) / 2.0) * ROW_SPACING, ROW_Y)


## Mockup line 555: two columns, steps of 32 down.
static func _battle_spot(k: int) -> Vector2:
	return Vector2(448.0 if k % 2 == 0 else 384.0, 330.0 + 32.0 * float(k))


static func _field_spot(i: int, count: int) -> Vector2:
	return Vector2(DESIGN_W / 2.0 + (float(i) - float(count - 1) / 2.0) * FIELD_STEP, FIELD_Y)


static func _at3(k: float, a: float, b: float, c: float) -> float:
	return lerpf(a, b, k) if k <= 1.0 else lerpf(b, c, k - 1.0)


# ---------------------------------------------------------------------------
# Pointer (mockup lines 565 to 598)
# ---------------------------------------------------------------------------

static func _pointer_plan(n: int, start: int, decided: int, laps: int, t0: float) -> Dictionary:
	var u := float(posmod(decided - start, n) + n * laps)
	while u < POINTER_MIN_TRAVEL:
		u += float(n)
	var t_len := t0
	var v := 0.0
	var tc := 0.0
	var td := 0.0
	for _i in 60:
		v = (u + 2.0 * POINTER_DECEL_DIST) / (t_len - POINTER_ACCEL / 2.0)
		td = 3.0 * POINTER_DECEL_DIST / v
		tc = t_len - POINTER_ACCEL - td
		if tc >= POINTER_MIN_CRUISE:
			break
		t_len += POINTER_T_STEP
	return { "n": n, "start": start, "decided": decided, "U": u, "V": v, "tc": tc, "td": td, "T": t_len }


static func _pointer_s(pp: Dictionary, t: float) -> float:
	var ta := POINTER_ACCEL
	var v := float(pp["V"])
	var tc := float(pp["tc"])
	var td := float(pp["td"])
	var u := float(pp["U"])
	if t <= 0.0:
		return 0.0
	if t < ta:
		return v * t * t / (2.0 * ta)
	if t < ta + tc:
		return v * ta / 2.0 + v * (t - ta)
	if t < ta + tc + td:
		var tau := (t - ta - tc) / td
		return (u - POINTER_DECEL_DIST) + POINTER_DECEL_DIST * (1.0 - pow(1.0 - tau, 3.0))
	return u


static func _pointer_speed(pp: Dictionary, t: float) -> float:
	var ta := POINTER_ACCEL
	var v := float(pp["V"])
	var tc := float(pp["tc"])
	var td := float(pp["td"])
	if t <= 0.0 or t >= ta + tc + td:
		return 0.0
	if t < ta:
		return v * t / ta
	if t < ta + tc:
		return v
	var tau := (t - ta - tc) / td
	return 3.0 * POINTER_DECEL_DIST / td * pow(1.0 - tau, 2.0)


static func _pointer_idx(pp: Dictionary, t: float) -> float:
	return fposmod(float(pp["start"]) + _pointer_s(pp, t), float(pp["n"]))


## Light position on the row; it slides off the right end and comes in from the left.
static func _pointer_xy(pp: Dictionary, t: float, rows: Array) -> Dictionary:
	var n := int(pp["n"])
	var idx := _pointer_idx(pp, t)
	var i := int(floor(idx + 1e-9))
	var f := idx - float(i)
	var r0 := _vec((rows[0] as Dictionary)["rest"])
	if i >= n:
		return { "x": r0.x, "y": r0.y, "o": 1.0 }
	var ri := _vec((rows[i] as Dictionary)["rest"])
	if i < n - 1:
		var rn := _vec((rows[i + 1] as Dictionary)["rest"])
		return { "x": lerpf(ri.x, rn.x, f), "y": ri.y, "o": 1.0 }
	var gap := (_vec((rows[1] as Dictionary)["rest"]).x - r0.x) if n > 1 else ROW_SPACING
	if f < 0.5:
		return { "x": ri.x + f * gap, "y": ri.y, "o": 1.0 - 2.0 * f }
	return { "x": r0.x - gap * 0.5 + (f - 0.5) * gap, "y": r0.y, "o": 2.0 * f - 1.0 }


# ---------------------------------------------------------------------------
# Walk track and body (mockup lines 621 to 639, 803 to 845)
# ---------------------------------------------------------------------------

static func _go(trk: Dictionary, dur: float, to: Vector2, ease_id: String, bow: float) -> void:
	var a: Vector2 = trk["p"]
	(trk["segs"] as Array).append({ "t0": trk["t"], "t1": float(trk["t"]) + dur, "ax": a.x, "ay": a.y, "bx": to.x, "by": to.y,
		"e": ease_id, "bow": bow })
	trk["t"] = float(trk["t"]) + dur
	trk["p"] = to


static func _wait(trk: Dictionary, dur: float) -> void:
	trk["t"] = float(trk["t"]) + dur


## One walk leg; a Standing with a hitch walks in two halves with a small hop between (mockup line 697).
static func _walk_to(trk: Dictionary, hops: Array, tp: Dictionary, reason: String, rm: bool, from: Vector2, dest: Vector2,
		dur: float, ease_id: String, bow: float) -> void:
	if rm:
		_go(trk, 0.15, dest, "lin", 0.0)
		return
	var hitch := float(tp["hitch"])
	if hitch > 0.0 and reason != "fit" and dur > 0.3:
		_go(trk, dur / 2.0, from.lerp(dest, 0.5), "lin", bow)
		_wait(trk, hitch)
		hops.append({ "t": float(trk["t"]) - hitch, "dur": hitch, "amp": 0.0, "sq": 0.03 })
		_go(trk, dur / 2.0, dest, "lin", 0.0)
	else:
		_go(trk, dur, dest, ease_id, bow)


static func _track_at(track: Dictionary, t: float) -> Vector2:
	if t <= float(track["t0"]):
		return _vec(track["p0"])
	for s_v: Variant in track["segs"]:
		var s: Dictionary = s_v
		if t < float(s["t1"]):
			var a := Vector2(s["ax"], s["ay"])
			if t < float(s["t0"]):
				return a
			var b := Vector2(s["bx"], s["by"])
			var e := _ease(str(s["e"]), (t - float(s["t0"])) / (float(s["t1"]) - float(s["t0"])))
			var p := a.lerp(b, e)
			var bow := float(s["bow"])
			if bow != 0.0:
				var du := _unit(b - a)
				p += Vector2(-du.y, du.x) * bow * sin(PI * e)
			return p
	return _vec(track["end"])


static func _row_pos(plan: Dictionary, k: int, t: float) -> Vector2:
	var a := float((plan["times"] as Dictionary)["row0"]) + 0.045 * float(k)
	var e: Dictionary = (plan["row"] as Array)[k]
	return _vec(e["battle"]).lerp(_vec(e["rest"]), _ph(t, a, a + 0.72, "smooth"))


static func _chooser_pos(plan: Dictionary, t: float) -> Vector2:
	if t < float((plan["times"] as Dictionary)["step0"]):
		return _row_pos(plan, int(plan["chooser_index"]), t)
	return _track_at(plan["track"], t)


static func _body_neutral() -> Dictionary:
	return { "bx": 0.0, "by": 0.0, "sx": 1.0, "sy": 1.0, "rot": 0.0, "glow": 0.0, "shade": 0.0 }


static func _body_at(plan: Dictionary, t: float) -> Dictionary:
	var tm: Dictionary = plan["times"]
	var rm := bool(plan["reduced"])
	var b := _body_neutral()
	for h_v: Variant in plan["hops"]:
		var h: Dictionary = h_v
		var u := (t - float(h["t"])) / float(h["dur"])
		if u > 0.0 and u < 1.0:
			var s := sin(PI * u)
			b["by"] = float(b["by"]) - float(h["amp"]) * s
			b["sx"] = float(b["sx"]) + float(h["sq"]) * s
			b["sy"] = float(b["sy"]) - float(h["sq"]) * s
	var rot := _kf(t, plan["lean"])
	for m_v: Variant in plan["tremors"]:
		var m: Dictionary = m_v
		if t >= float(m["t0"]) and t <= float(m["t1"]) + float(m["decay"]):
			var env := minf(1.0, (t - float(m["t0"])) / float(m["ramp"]))
			if t > float(m["t1"]):
				env = 1.0 - (t - float(m["t1"])) / float(m["decay"])
			var w := sin(2.0 * PI * float(m["hz"]) * (t - float(m["t0"])))
			b["bx"] = float(b["bx"]) + 1.5 * float(m["amp"]) * w * env
			b["by"] = float(b["by"]) + 0.6 * float(m["amp"]) * w * env
	var t_b := float(tm["bark"])
	var p := _ph(t, t_b - 0.05, t_b + 0.3, "smooth")
	match str(plan["emo"]):
		"plus":
			if rm:
				b["glow"] = 0.28 * p
			else:
				b["by"] = float(b["by"]) - 3.0 * sin(PI * _pr(t, t_b - 0.05, t_b + 0.3))
				b["glow"] = 0.3 * p
		"minus":
			if rm:
				b["shade"] = 0.2 * p
			else:
				b["sx"] = float(b["sx"]) * (1.0 + 0.05 * p)
				b["sy"] = float(b["sy"]) * (1.0 - 0.07 * p)
				rot = lerpf(rot, -5.0, p)
				b["shade"] = 0.25 * p
		"lean":
			if not rm:
				rot = lerpf(rot, -4.0, p)
	b["rot"] = rot
	return b


## The body at rest after the intro; must match `_body_at` at the plan total.
static func _body_end(emo: String, rm: bool) -> Dictionary:
	var b := _body_neutral()
	match emo:
		"plus":
			b["glow"] = 0.28 if rm else 0.3
		"minus":
			if rm:
				b["shade"] = 0.2
			else:
				b["sx"] = 1.05
				b["sy"] = 0.93
				b["rot"] = -5.0
				b["shade"] = 0.25
		"lean":
			if not rm:
				b["rot"] = -4.0
	return b


static func _kf(t: float, keys: Array) -> float:
	var first: Dictionary = keys[0]
	if t <= float(first["t"]):
		return float(first["v"])
	for i in range(1, keys.size()):
		var b: Dictionary = keys[i]
		if t < float(b["t"]):
			var a: Dictionary = keys[i - 1]
			return lerpf(float(a["v"]), float(b["v"]), _ease(str(a["e"]), _pr(t, float(a["t"]), float(b["t"]))))
	return float((keys[keys.size() - 1] as Dictionary)["v"])


static func _beat_at(plan: Dictionary, t: float) -> String:
	var current := "last_enemy_falls"
	for b_v: Variant in plan["beats"]:
		if t >= float((b_v as Dictionary)["t"]):
			current = str((b_v as Dictionary)["name"])
	return current


# ---------------------------------------------------------------------------
# Item view (mockup lines 847 to 876)
# ---------------------------------------------------------------------------

static func _item_frame(plan: Dictionary, f: Dictionary, t: float) -> Dictionary:
	var rest_p := _vec(f["rest"])
	var ap := float(f["appear"])
	var fall := _ph(t, ap, ap + 0.28, "out")
	var bounce := 3.0 * sin(PI * _pr(t, ap + 0.28, ap + 0.36))
	var v := { "vis": "svg", "x": rest_p.x, "y": rest_p.y - 18.0 * (1.0 - fall) - bounce, "o": _pr(t, ap, ap + 0.12),
		"sc": 1.0, "df": 0.0, "rev": _ph(t, float(f["reveal"]), float(f["reveal"]) + float(f["reveal_len"]), "smooth"),
		"held": false, "glint": -1.0, "layer": 0, "slot": -1 }
	if t < ap:
		v["vis"] = "none"
		return v
	var is_try := bool(f["is_try"])
	if bool(f["walked"]):
		var lift0 := float(f["lift0"])
		var lift1 := float(f["lift1"])
		var fly0 := float(f["fly0"])
		var fly1 := float(f["fly1"])
		if t >= lift0 and (is_try or t < fly0):
			var p := _ph(t, lift0, lift1, str(f["lift_ease"]))
			var pos := rest_p.lerp(_head(plan, t), p)
			if is_try and t >= lift1:
				pos = _head(plan, t)
				v["held"] = true
			v["x"] = pos.x
			v["y"] = pos.y
		elif not is_try and t >= fly0 and t < fly1:
			var u := _ph(t, fly0, fly1, "smooth")
			var to := _slot_center(int(f["slot"]))
			var q := _head(plan, fly0).lerp(to, u)
			v["x"] = q.x
			v["y"] = q.y - 34.0 * sin(PI * u)
			v["sc"] = 1.0 + 0.45 * u
			v["layer"] = 1
		elif not is_try and t >= fly1:
			var c := _slot_center(int(f["slot"]))
			v["vis"] = "tile"
			v["x"] = c.x
			v["y"] = c.y
			v["slot"] = int(f["slot"])
	else:
		var tm: Dictionary = plan["times"]
		var dd := _ph(t, float(tm["deposit_end"]), float(tm["deposit_end"]) + 0.3, "out")
		v["df"] = dd
		v["o"] = float(v["o"]) * lerpf(1.0, DIM_OPACITY, dd)
	for g_v: Variant in plan["glints"]:
		var g: Dictionary = g_v
		if str(g["find_id"]) == str(f["find_id"]):
			var gu := (t - float(g["t"])) / float(g["dur"])
			if gu > 0.0 and gu < 1.0:
				v["glint"] = gu
	return v


static func _head(plan: Dictionary, t: float) -> Vector2:
	return _chooser_pos(plan, t - 0.06) + Vector2(0.0, -HEAD)


static func _slot_center(i: int) -> Vector2:
	return Vector2(SLOT_X0 + SLOT_STEP * float(i), SLOT_Y)


# ---------------------------------------------------------------------------
# Maths
# ---------------------------------------------------------------------------

static func _d(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _pt(v: Vector2) -> Dictionary:
	return { "x": v.x, "y": v.y }


static func _vec(d: Variant) -> Vector2:
	return Vector2(float((d as Dictionary)["x"]), float((d as Dictionary)["y"]))


static func _norm(v: Vector2) -> Dictionary:
	return { "x": v.x / DESIGN_W, "y": v.y / DESIGN_H }


static func _unit(v: Vector2) -> Vector2:
	var l := v.length()
	return v / (l if l > 0.0 else 1.0)


static func _pr(t: float, a: float, b: float) -> float:
	if b > a:
		return clampf((t - a) / (b - a), 0.0, 1.0)
	return 1.0 if t >= a else 0.0


static func _ph(t: float, a: float, b: float, ease_id: String) -> float:
	return _ease(ease_id, _pr(t, a, b))


static func _ease(ease_id: String, x: float) -> float:
	match ease_id:
		"lin":
			return x
		"out":
			return _bez(x, 0.2, 0.8, 0.2, 1.0)
		"in":
			return _bez(x, 0.5, 0.0, 0.9, 0.4)
		"back":
			return _bez(x, 0.34, 1.56, 0.64, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Cubic bezier easing by bisection (mockup line 292), 20 steps.
static func _bez(x: float, x1: float, y1: float, x2: float, y2: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	var lo := 0.0
	var hi := 1.0
	var u := x
	for _i in 20:
		var cx := 3.0 * x1 * u * (1.0 - u) * (1.0 - u) + 3.0 * x2 * u * u * (1.0 - u) + u * u * u
		if cx < x:
			lo = u
		else:
			hi = u
		u = (lo + hi) / 2.0
	return 3.0 * y1 * u * (1.0 - u) * (1.0 - u) + 3.0 * y2 * u * u * (1.0 - u) + u * u * u
