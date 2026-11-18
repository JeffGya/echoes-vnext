class_name PickupEventPlan
extends RefCounted

## Pure timeline of the pickup intro on board tiles (U3). Takes a `flow.pickup` snapshot, returns
## plain data. No scene object, no animation object, no randomness: every number comes from snapshot keys or from
## `hash_of`. The mockup `pickup-event-playable.html` gives the ORDER of events and the time constants; it gives
## no look. A cell is `{ col, row }`, as in the snapshot. Screen positions (pack slot centres) are not here: the plan
## carries slot indices and times, the scene maps them.
##
## build(snapshot, opts) -> { valid, reduced, total, times, beats, row, finds, legs, walk, pointer, pack, bark, ... }
##   row[]      { id, standing, status, chosen, cell }        cell = `row[i].tile`; the Echoes never move except the chooser
##   chooser_cell, out_cell, chooser_end_cell                  start tile, the tile one step out of the row ({} = stays), end tile
##   legs[]     { t0, t1, kind: "out" | "walk", cells[] }      cells = the tile path including the start; "back" is not used
##   walk[]     { find_id, k, is_try, t0, t1, stand }          one per stop; stand = the tile before the find tile
##   finds[]    { find_id, index, status, pick_index, tile, reveal, reveal_len, walked, is_try, walk0, arrive,
##              lift0, lift1, lift_ease, fly0, fly1, slot }    -1 = no time or no slot
##   pointer    { n, start, laps, decided, travel, length, steps[{ t, index }], plan }   the light's row index over time
##   pack       { before, after, slot_count, unlisted, tone, tone_before, land_end, pulse_at, held_find }
##   bark       { text, case, reaction, reason, band, variant, chars, t0, t1 };  emo = reaction name (emo_style)
## frame_at(plan, t) / skip_to_idle(snapshot, opts) -> { t, phase, beat, echoes[{ id, chosen, cell, walking, from, to,
##   progress }], items{ find_id: { state, cell, rev, p, held, dim, slot } }, pack{ slots, lit, used, pulse, tone },
##   pointer{ index, speed }, bark{ chars, total }, skip_o, cont_o, chooser_end }
##   item state: hidden | revealed | lifted | flying | pack.
## A scene must handle `plan.valid == false` (no chooser, error snapshot, pointer start below 0, a row or find with no
## tile): show no intro.

# Seconds of still picture before the pointer starts. Feel value, tune in playtest (the mockup had 1.05 s with a row formation in it).
const POINTER_START := 0.4
# Mockup line 670 and 671: pointer rest to step-out gap, step-out length, reduced-motion values.
const STEP_GAP := 0.2
const STEP_LEN := 0.45
const STEP_LEN_REDUCED := 0.15
const POINTER_REDUCED := 0.5
# Mockup line 774: reveal length.
const REVEAL_LEN := 0.25
const REVEAL_LEN_REDUCED := 0.15
# Mockup line 778 and 780: emotion beat and idle times.
const BARK_AFTER_LAST := 0.15
const IDLE_AFTER_BARK := 0.3
const IDLE_AFTER_DEPOSIT := 0.45
# Mockup line 566, 568 and 570: pointer slow-down distance, run-in time, minimum travel, minimum cruise, step.
const POINTER_DECEL_DIST := 2.5
const POINTER_ACCEL := 0.4
const POINTER_MIN_TRAVEL := 6.0
const POINTER_MIN_CRUISE := 0.25
const POINTER_T_STEP := 0.05
# Mockup line 602: base length 2.0 s plus 0.2 s times a hash value 0..4.
const POINTER_T_BASE := 2.0
const POINTER_T_VARY := 0.2
const POINTER_T_STEPS := 5
const POINTER_SAMPLE_DT := 0.05
# Mockup line 619: walk cap, fly time, typing speed.
const WALK_CAP := 3.4
const FLY_LEN := 0.34
const TYPE_CPS := 24.0
# Mockup line 688 gave the reference distances in pixels (90 and 60); here they are tiles (30 px a tile). Feel values, tune in playtest.
const REF_TILES_FIRST := 3.0
const REF_TILES_NEXT := 2.0
const DIST_SCALE_MIN := 0.6
const DIST_SCALE_MAX := 1.35
# Mockup lines 716 and 679: worth pauses before the last tile of the first walk; safe waits longer before the first step.
const WORTH_DWELL := 0.45
const SAFE_PRE_EXTRA := 0.25
# Mockup line 748: try item lift is longer by 0.1 s.
const TRY_LIFT_EXTRA := 0.1
# A frozen chooser waits FROZEN_STEP + FROZEN_WAIT after its step out (the mockup's step, tremble and wait; no tremble is played).
const FROZEN_STEP := 0.35
const FROZEN_WAIT := 1.35
const PACK_SLOTS_DEFAULT := 4
const PULSE_LEN := 0.4
# Presentation constant: the pick rule never reads it. It copies the config default
# `data.inventory.pickup.severe_from_status`; Jeff reviews it. The safe / bold reading of the `state` reason is a
# presentation choice: the mockup gives each Echo a manner trait that the core does not have.
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


## The whole intro as data. `opts.reduced` = reduced motion (mockup `rm`). Returns { valid: false, ... } (the keys reduced, total,
## situation_id, beats, finds, row, walk, legs only) when the snapshot is not playable; `frame_at` returns the empty frame for it.
static func build(snapshot: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var d := _d(snapshot.get("data", {}))
	var rm := bool(opts.get("reduced", false))
	var row: Array = d.get("row", []) if d.get("row", []) is Array else []
	var n := row.size()
	var cidx := -1
	for i in n:
		if bool(_d(row[i]).get("is_chooser", false)):
			cidx = i
	var ptr := _d(d.get("pointer", {}))
	var finds: Array = d.get("finds", []) if d.get("finds", []) is Array else []
	var row_cells: Array = []
	var find_cells: Array = []
	for r_v: Variant in row:
		row_cells.append(_cell(_d(r_v).get("tile")))
	for f_v: Variant in finds:
		find_cells.append(_cell(_d(f_v).get("tile")))
	if cidx < 0 or str(d.get("error", "")) != "" or int(ptr.get("start", -1)) < 0 or row_cells.has({}) or find_cells.has({}):
		return _invalid(d, rm)

	var frozen := bool(d.get("frozen", false))
	var case_key := str(d.get("case", ""))
	var chooser := row[cidx] as Dictionary
	var standing := int(chooser.get("standing", 1))
	var reason := _tempo_reason(case_key, frozen, str(d.get("reason", "")), str(chooser.get("status", "")))
	var tp := tempo(standing)
	# A frozen chooser has no stops, so the table is read only for its lift ease; likes is the explicit choice.
	var rs: Dictionary = RS["likes" if reason == "froze" else reason]
	var sit := str(d.get("situation_id", ""))

	# Board for the paths: `{}` walkable = the whole board (StageTerrain.is_walkable), cut by the board bounds.
	var cols := int(d.get("board_cols", 0))
	var rows_n := int(d.get("board_rows", 0))
	var walkable := StageTerrain.walkable_set(_d(d.get("terrain", {})))
	var bounds: Dictionary = { "w": cols, "h": rows_n } if cols > 0 and rows_n > 0 else {}

	# World beats (mockup lines 666 to 673).
	var find_ids: Array = finds.map(func(f: Variant) -> String: return str((f as Dictionary).get("find_id", "")))
	var pp := _pointer_plan(n, int(ptr["start"]), cidx, maxi(1, int(ptr.get("laps", 1))),
		POINTER_T_BASE + POINTER_T_VARY * float(hash_of([sit, find_ids]) % POINTER_T_STEPS))
	var t_p0 := POINTER_START
	var t_pend := t_p0 + (POINTER_REDUCED if rm else float(pp["T"]))
	var t_s0 := t_pend + STEP_GAP
	var t_s1 := t_s0 + (STEP_LEN_REDUCED if rm else STEP_LEN)

	# Stops in pick order, then the held-up find.
	var picked: Array = finds.filter(func(f: Variant) -> bool: return str((f as Dictionary).get("status", "")) == "taken")
	picked.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("pick_index", 0)) < int((b as Dictionary).get("pick_index", 0)))
	var stops: Array = []
	for f_v: Variant in picked:
		stops.append({ "find_id": str((f_v as Dictionary)["find_id"]), "is_try": false })
	for f_v: Variant in finds:
		if str((f_v as Dictionary).get("status", "")) == "tried":
			stops.append({ "find_id": str((f_v as Dictionary)["find_id"]), "is_try": true })

	# The chooser's path (legs).
	var start_cell: Dictionary = row_cells[cidx]
	var out_cell := _out_cell(cidx, row_cells, find_cells, walkable, bounds, sit, str(chooser.get("id", "")))
	var trk := { "t": t_s0, "cell": start_cell, "legs": [] }
	if not out_cell.is_empty():
		_emit(trk, [start_cell, out_cell], "out", t_s1 - t_s0)
	trk["t"] = t_s1
	_wait(trk, float(tp["pre"]) + (SAFE_PRE_EXTRA if reason == "safe" else 0.0))
	var t_w0: float = trk["t"]
	var cur: Dictionary = trk["cell"]
	var sum_w := 0.0
	for k in stops.size():
		var s: Dictionary = stops[k]
		var cells := _stand_path(cur, find_cells[_index_of(find_ids, str(s["find_id"]))], find_cells, row_cells, walkable, bounds, sit)
		var steps := cells.size() - 1
		var first := k == 0
		var base := float((rs["w"] as Array)[0 if first else 1]) * clampf(float(steps) / (REF_TILES_FIRST if first else REF_TILES_NEXT),
			DIST_SCALE_MIN, DIST_SCALE_MAX)
		var w := 0.0
		if steps > 0:
			w = float((rs["w"] as Array)[0]) if reason == "fit" else base / float(tp["pace"]) + float(tp["hitch"])
		s["cells"] = cells
		s["w"] = w
		sum_w += w
		cur = cells[cells.size() - 1]
	var w_scale := WALK_CAP / sum_w if sum_w > WALK_CAP else 1.0

	var recs := {}
	var walk: Array = []
	var slot_of := {}
	var pack_before := _pack_before(d, finds)
	var unlisted := _unlisted(d)
	for u in unlisted:
		pack_before.append("unlisted_%d" % u)
	var slot_count := _slot_count(d, pack_before.size(), picked.size())
	var next_slot := pack_before.size()
	var prev_fly1 := 0.0
	for k in stops.size():
		var s: Dictionary = stops[k]
		var fid := str(s["find_id"])
		var is_try: bool = s["is_try"]
		var cells: Array = s["cells"]
		var w: float = float(s["w"]) * w_scale
		var r := { "walk0": trk["t"] }
		if cells.size() > 1:
			if rm:
				_emit(trk, cells, "walk", 0.15)
			elif reason == "worth" and k == 0:
				# Pause before the last tile (the mockup's glance at the find).
				var steps := cells.size() - 1
				_emit(trk, cells.slice(0, steps), "walk", w * float(steps - 1) / float(steps))
				_wait(trk, WORTH_DWELL)
				_emit(trk, cells.slice(steps - 1), "walk", w / float(steps))
			else:
				_emit(trk, cells, "walk", w)
		r["arrive"] = trk["t"]
		var touch := 0.0 if rm else float(rs["touch"])
		_wait(trk, touch)
		var lift := 0.15 if rm else (float(rs["lift"]) + TRY_LIFT_EXTRA if is_try else float(rs["lift"]))
		# A pick next to the last one must not fly before that one has landed.
		if not is_try:
			_wait(trk, maxf(0.0, prev_fly1 - float(trk["t"]) - lift - (0.0 if rm else float(rs["hold"]))))
		r["lift0"] = trk["t"]
		r["lift1"] = float(trk["t"]) + lift
		if not is_try:
			r["fly0"] = float(r["lift1"]) + (0.0 if rm else float(rs["hold"]))
			r["fly1"] = float(r["fly0"]) + (0.15 if rm else FLY_LEN)
			slot_of[fid] = next_slot
			next_slot += 1
			prev_fly1 = float(r["fly1"])
		_wait(trk, maxf(0.0, lift - (0.0 if rm else 0.1)))
		recs[fid] = r
		walk.append({ "find_id": fid, "k": k, "is_try": is_try, "t0": r["walk0"], "t1": r["arrive"],
			"stand": (trk["cell"] as Dictionary).duplicate() })
	if frozen and not finds.is_empty():
		_wait(trk, 0.4 if rm else FROZEN_STEP + FROZEN_WAIT)

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
	if try_id != "":
		t_idle = maxf(t_idle, float((recs[try_id] as Dictionary)["lift1"]) + PULSE_LEN)

	var out_finds: Array = []
	for i in finds.size():
		var f: Dictionary = finds[i]
		var fid := str(f.get("find_id", ""))
		var r: Dictionary = recs.get(fid, {})
		var walked := not r.is_empty()
		out_finds.append({
			"find_id": fid, "index": i, "status": str(f.get("status", "")), "pick_index": int(f.get("pick_index", -1)),
			"tile": find_cells[i],
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
	var land_end := 0.0
	for fid: Variant in slot_of:
		land_end = maxf(land_end, float((recs[fid] as Dictionary)["fly1"]))
	var rows_out: Array = []
	for k in n:
		var e: Dictionary = row[k]
		rows_out.append({ "id": str(e.get("id", "")), "standing": int(e.get("standing", 1)),
			"status": str(e.get("status", "")), "chosen": k == cidx, "cell": row_cells[k] })
	var beats: Array = [
		{ "name": "last_enemy_falls", "t": 0.0 },
		{ "name": "pointer_runs", "t": t_p0 },
		{ "name": "chooser_steps_out", "t": t_s0 },
		{ "name": "walks_to_picks" if not picked.is_empty() else ("tries_a_find" if try_id != "" else "takes_nothing"), "t": t_w0 },
		{ "name": "reaction", "t": t_b },
		{ "name": "idle", "t": t_idle },
	]
	var pk := _d(d.get("pack", {}))
	return {
		"valid": true, "reduced": rm, "situation_id": sit,
		"chooser_id": str(chooser.get("id", "")), "chooser_index": cidx, "n": n,
		"case": case_key, "reason": str(d.get("reason", "")), "tempo_reason": reason, "frozen": frozen,
		"reaction": str(d.get("reaction", "")), "emo": emo_style(str(d.get("reaction", "")), case_key, frozen),
		"offered": bool(_d(d.get("swap", {})).get("offered", false)),
		"total": t_idle,
		"times": { "pointer0": t_p0, "pointer_end": t_pend, "step0": t_s0, "step1": t_s1, "walk0": t_w0,
			"deposit_end": t_a, "bark": t_b, "bark_end": t_bark_end, "idle": t_idle },
		"beats": beats,
		"row": rows_out,
		"chooser_cell": start_cell, "out_cell": out_cell, "chooser_end_cell": (trk["cell"] as Dictionary).duplicate(),
		"legs": trk["legs"],
		"pointer": { "n": n, "start": int(ptr["start"]), "laps": maxi(1, int(ptr.get("laps", 1))), "decided": cidx,
			"travel": float(pp["U"]), "length": float(pp["T"]), "plan": pp, "steps": _pointer_steps(pp, t_p0, rm, cidx) },
		"finds": out_finds,
		"walk": walk,
		"pack": { "before": pack_before, "after": pack_after, "slot_count": slot_count, "unlisted": unlisted,
			"tone": str(pk.get("tone", "plain")), "tone_before": str(pk.get("tone_before", pk.get("tone", "plain"))),
			"land_end": land_end,
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
	var echoes: Array = []
	for e_v: Variant in plan["row"]:
		var e: Dictionary = e_v
		var item := { "id": str(e["id"]), "chosen": bool(e["chosen"]) }
		item.merge(_standing(e["cell"]) if not bool(e["chosen"]) else _chooser_at(plan, t))
		echoes.append(item)

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
	var pulse := sin(PI * _pr(t, pulse_at, pulse_at + PULSE_LEN)) if pulse_at >= 0.0 else 0.0

	var pointer: Dictionary = plan["pointer"]
	var t_p0 := float(tm["pointer0"])
	var on := -1
	var speed := 0.0
	if t >= t_p0 and t < float(tm["step0"]):
		on = int(plan["chooser_index"]) if rm or t >= float(tm["pointer_end"]) else _pointer_row(pointer["plan"], t - t_p0)
		speed = 0.0 if rm else _pointer_speed(pointer["plan"], t - t_p0)

	var bark: Dictionary = plan["bark"]
	var chars := int(bark["chars"])
	var typed := chars if rm else clampi(int(floor((t - float(bark["t0"])) * TYPE_CPS)), 0, chars)
	var t_idle := float(tm["idle"])
	return {
		"t": t, "phase": "idle" if t >= t_idle else "intro", "beat": _beat_at(plan, t),
		"echoes": echoes, "items": items,
		"pack": { "slots": slots, "lit": lit, "used": used, "pulse": pulse,
			"tone": str(pk["tone"]) if t >= float(pk["land_end"]) else str(pk["tone_before"]) },
		"pointer": { "index": on, "speed": speed },
		"bark": { "chars": typed, "total": chars },
		"skip_o": _ph(t, 0.2, 0.35, "smooth") * (1.0 - _ph(t, t_idle - 0.1, t_idle, "smooth")),
		"cont_o": _ph(t, t_idle - 0.25, t_idle, "smooth"),
		"chooser_end": (plan["chooser_end_cell"] as Dictionary).duplicate(),
	}


## The state Skip jumps to. Item and pack state come from the snapshot statuses; the chooser end tile and `t` (the plan
## total) come from `build`. A test compares it with `frame_at(build(snapshot), total)`.
static func skip_to_idle(snapshot: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var plan := build(snapshot, opts)
	if not bool(plan["valid"]):
		return _empty_frame()
	var d := _d(snapshot.get("data", {}))
	var pk: Dictionary = plan["pack"]
	var echoes: Array = []
	for e_v: Variant in plan["row"]:
		var e: Dictionary = e_v
		var item := { "id": str(e["id"]), "chosen": bool(e["chosen"]) }
		item.merge(_standing(plan["chooser_end_cell"] if bool(e["chosen"]) else e["cell"]))
		echoes.append(item)
	var items := {}
	var slots: Array = []
	var lit: Array = []
	for i in int(pk["slot_count"]):
		slots.append(str((pk["before"] as Array)[i]) if i < (pk["before"] as Array).size() else "")
		lit.append(0.0)
	for f_v: Variant in d.get("finds", []):
		var f: Dictionary = f_v
		var fid := str(f.get("find_id", ""))
		var fp := _find_plan(plan, fid)
		var it := { "state": "revealed", "cell": fp["tile"], "rev": 1.0, "p": 0.0, "held": false, "dim": 1.0, "slot": -1 }
		match str(f.get("status", "")):
			"taken":
				var slot := int(fp["slot"])
				it.merge({ "state": "pack", "p": 1.0, "dim": 0.0, "slot": slot }, true)
				if slot >= 0 and slot < slots.size():
					slots[slot] = str((pk["after"] as Array)[slot])
			"tried":
				it.merge({ "state": "lifted", "p": 1.0, "dim": 0.0, "held": true }, true)
		items[fid] = it
	var used := 0
	for s_v: Variant in slots:
		used += 1 if str(s_v) != "" else 0
	return {
		"t": float(plan["total"]), "phase": "idle", "beat": "idle",
		"echoes": echoes, "items": items,
		"pack": { "slots": slots, "lit": lit, "used": used, "pulse": 0.0, "tone": str(pk["tone"]) },
		"pointer": { "index": -1, "speed": 0.0 },
		"bark": { "chars": int((plan["bark"] as Dictionary)["chars"]), "total": int((plan["bark"] as Dictionary)["chars"]) },
		"skip_o": 0.0, "cont_o": 1.0, "chooser_end": (plan["chooser_end_cell"] as Dictionary).duplicate(),
	}


## Speed table by Standing (mockup lines 606 to 610): pre-walk pause, hitch (added to a walk), pace, reaction delay.
static func tempo(standing: int) -> Dictionary:
	var s := clampi(standing, 1, 9)
	var k := float(s - 1) / 4.0 if s <= 5 else 1.0 + float(s - 5) / 4.0
	return {
		"pre": snappedf(_at3(k, 0.6, 0.35, 0.1), 0.01), "hitch": snappedf(_at3(k, 0.12, 0.06, 0.0), 0.01),
		"pace": _at3(k, 0.8, 0.95, 1.0), "delay": snappedf(_at3(k, 0.2, 0.1, 0.0), 0.01),
	}


## "plus", "minus", "lean" (afraid or frozen) or "neutral" (some fit). A name for the reaction; the plan plays no body style.
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
		"beats": [], "finds": [], "row": [], "walk": [], "legs": [] }


static func _empty_frame() -> Dictionary:
	return { "t": 0.0, "phase": "idle", "beat": "idle", "echoes": [], "items": {},
		"pack": { "slots": [], "lit": [], "used": 0, "pulse": 0.0, "tone": "plain" },
		"pointer": { "index": -1, "speed": 0.0 }, "bark": { "chars": 0, "total": 0 }, "skip_o": 0.0, "cont_o": 1.0,
		"chooser_end": {} }


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


static func _at3(k: float, a: float, b: float, c: float) -> float:
	return lerpf(a, b, k) if k <= 1.0 else lerpf(b, c, k - 1.0)


# ---------------------------------------------------------------------------
# Tiles and legs
# ---------------------------------------------------------------------------

## `{ col, row }` from a snapshot tile, or `{}` when it is not one.
static func _cell(v: Variant) -> Dictionary:
	if v is Dictionary and (v as Dictionary).has("col") and (v as Dictionary).has("row"):
		return { "col": int((v as Dictionary)["col"]), "row": int((v as Dictionary)["row"]) }
	return {}


static func _key(c: Dictionary) -> String:
	return "%d,%d" % [int(c["col"]), int(c["row"])]


static func _cheb(a: Dictionary, b: Dictionary) -> int:
	return maxi(absi(int(a["col"]) - int(b["col"])), absi(int(a["row"]) - int(b["row"])))


## The tile one step out of the row: a free orthogonal neighbour of the chooser's tile on the side of the finds' centre,
## perpendicular to the row when the row is a straight line. Hash breaks ties. `{}` = the chooser stays.
static func _out_cell(cidx: int, row_cells: Array, find_cells: Array, walkable: Dictionary, bounds: Dictionary,
		sit: String, chooser_id: String) -> Dictionary:
	if find_cells.is_empty():
		return {}
	var me: Dictionary = row_cells[cidx]
	var first: Dictionary = row_cells[0]
	var same_col := row_cells.all(func(c: Dictionary) -> bool: return int(c["col"]) == int(first["col"]))
	var same_row := row_cells.all(func(c: Dictionary) -> bool: return int(c["row"]) == int(first["row"]))
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	if row_cells.size() > 1 and same_col != same_row:
		dirs = [Vector2i(1, 0), Vector2i(-1, 0)] if same_col else [Vector2i(0, 1), Vector2i(0, -1)]
	var sum := Vector2.ZERO
	for c: Dictionary in find_cells:
		sum += Vector2(float(c["col"]), float(c["row"]))
	var toward := sum / float(find_cells.size()) - Vector2(float(me["col"]), float(me["row"]))
	var cands: Array = []
	for dv: Vector2i in dirs:
		cands.append({ "dot": toward.dot(Vector2(dv)), "h": hash_of([sit, "out", chooser_id, dv.x, dv.y]),
			"cell": { "col": int(me["col"]) + dv.x, "row": int(me["row"]) + dv.y } })
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["h"]) < int(b["h"]) if is_equal_approx(float(a["dot"]), float(b["dot"])) else float(a["dot"]) > float(b["dot"]))
	var taken := {}
	for c: Dictionary in row_cells + find_cells:
		taken[_key(c)] = true
	var best := float((cands[0] as Dictionary)["dot"])
	for c: Dictionary in cands:
		var dot := float(c["dot"])
		if dot < 0.0 or (dot == 0.0 and best > 0.0):
			continue
		var cell: Dictionary = c["cell"]
		if not taken.has(_key(cell)) and _on_board(cell, walkable, bounds):
			return cell
	return {}


static func _on_board(cell: Dictionary, walkable: Dictionary, bounds: Dictionary) -> bool:
	if not bounds.is_empty() and (int(cell["col"]) < 0 or int(cell["row"]) < 0 or int(cell["col"]) >= int(bounds["w"]) or int(cell["row"]) >= int(bounds["h"])):
		return false
	return StageTerrain.is_walkable(cell, walkable)


## The tile path from `from` to a stand tile next to the find: the free neighbour of the find tile (on the board, walkable,
## not a row tile, not another find's tile) with the shortest board path; `hash_of` breaks ties. Tiers when none is free:
## a neighbour that is another find's tile, then a row tile, then the tile before the find tile. Includes `from`;
## just `[from]` when already on a stand tile of the first tier that has one, or when there is no path. Actors are not avoided.
static func _stand_path(from: Dictionary, find_cell: Dictionary, find_cells: Array, row_cells: Array, walkable: Dictionary,
		bounds: Dictionary, sit: String) -> Array:
	var tiers: Array = [[], [], []]
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			var c := { "col": int(find_cell["col"]) + dc, "row": int(find_cell["row"]) + dr }
			if (dc == 0 and dr == 0) or not _on_board(c, walkable, bounds):
				continue
			(tiers[2 if row_cells.has(c) else (1 if find_cells.has(c) else 0)] as Array).append(c)
	for tier: Array in tiers:
		if tier.has(from):
			return [from]
		var best: Array = []
		var best_h := 0
		for c: Dictionary in tier:
			var res := MovementPathService.shortest_path(from, c, walkable, {}, bounds)
			if not bool(res.get("reachable", false)):
				continue
			var path: Array = res.get("path", [])
			var h := hash_of([sit, "stand", find_cell["col"], find_cell["row"], c["col"], c["row"]])
			if best.is_empty() or path.size() < best.size() or (path.size() == best.size() and h < best_h):
				best = path
				best_h = h
		if not best.is_empty():
			var cells: Array = [from]
			for p: Variant in best:
				cells.append(_cell(p))
			return cells
	var res := MovementPathService.shortest_path(from, find_cell, walkable, {}, bounds)
	var cells: Array = [from]
	if bool(res.get("reachable", false)):
		var path: Array = res.get("path", [])
		for i in maxi(0, path.size() - 1):
			cells.append(_cell(path[i]))
	return cells


static func _emit(trk: Dictionary, cells: Array, kind: String, dur: float) -> void:
	if cells.size() < 2:
		return
	(trk["legs"] as Array).append({ "t0": trk["t"], "t1": float(trk["t"]) + dur, "kind": kind, "cells": cells.duplicate(true) })
	trk["t"] = float(trk["t"]) + dur
	trk["cell"] = (cells[cells.size() - 1] as Dictionary).duplicate()


static func _wait(trk: Dictionary, dur: float) -> void:
	trk["t"] = float(trk["t"]) + dur


static func _standing(cell: Variant) -> Dictionary:
	return { "cell": cell, "walking": false, "from": cell, "to": cell, "progress": 0.0 }


## Where the chooser is at `t`: on a tile, or between two tiles of a leg.
static func _chooser_at(plan: Dictionary, t: float) -> Dictionary:
	var cur: Dictionary = plan["chooser_cell"]
	for l_v: Variant in plan["legs"]:
		var l: Dictionary = l_v
		var cells: Array = l["cells"]
		if t < float(l["t0"]):
			break
		if t < float(l["t1"]):
			var steps := cells.size() - 1
			var u := (t - float(l["t0"])) / (float(l["t1"]) - float(l["t0"])) * float(steps)
			var i := mini(int(u), steps - 1)
			return { "cell": cells[i], "walking": true, "from": cells[i], "to": cells[i + 1], "progress": u - float(i) }
		cur = cells[cells.size() - 1]
	return _standing(cur)


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


## The row index the light is on at `t` seconds after it starts: the nearest index of the running position.
static func _pointer_row(pp: Dictionary, t: float) -> int:
	var n := int(pp["n"])
	return posmod(int(roundf(float(pp["start"]) + _pointer_s(pp, t))), n)


## The light's index over time: one entry each time it moves to another row index. Ends on the chooser at `pointer_end`.
static func _pointer_steps(pp: Dictionary, t_p0: float, rm: bool, cidx: int) -> Array:
	if rm:
		return [{ "t": t_p0, "index": cidx }]
	var steps: Array = []
	var last := -1
	var count := int(ceil(float(pp["T"]) / POINTER_SAMPLE_DT))
	for i in count + 1:
		var ts := minf(float(i) * POINTER_SAMPLE_DT, float(pp["T"]))
		var idx := _pointer_row(pp, ts)
		if idx != last:
			steps.append({ "t": t_p0 + ts, "index": idx })
			last = idx
	return steps


static func _beat_at(plan: Dictionary, t: float) -> String:
	var current := "last_enemy_falls"
	for b_v: Variant in plan["beats"]:
		if t >= float((b_v as Dictionary)["t"]):
			current = str((b_v as Dictionary)["name"])
	return current


# ---------------------------------------------------------------------------
# Find view
# ---------------------------------------------------------------------------

static func _item_frame(plan: Dictionary, f: Dictionary, t: float) -> Dictionary:
	var rev := _ph(t, float(f["reveal"]), float(f["reveal"]) + float(f["reveal_len"]), "smooth")
	var v := { "state": "hidden" if t < float(f["reveal"]) else "revealed", "cell": f["tile"], "rev": rev, "p": 0.0,
		"held": false, "dim": 0.0, "slot": -1 }
	if bool(f["walked"]):
		var is_try := bool(f["is_try"])
		if t >= float(f["lift0"]) and (is_try or t < float(f["fly0"])):
			v["state"] = "lifted"
			v["p"] = _ph(t, float(f["lift0"]), float(f["lift1"]), str(f["lift_ease"]))
			v["held"] = is_try and t >= float(f["lift1"])
		elif not is_try and t >= float(f["fly0"]) and t < float(f["fly1"]):
			v["state"] = "flying"
			v["p"] = _ph(t, float(f["fly0"]), float(f["fly1"]), "smooth")
			v["slot"] = int(f["slot"])
		elif not is_try and t >= float(f["fly1"]):
			v["state"] = "pack"
			v["p"] = 1.0
			v["slot"] = int(f["slot"])
	else:
		v["dim"] = _ph(t, float((plan["times"] as Dictionary)["deposit_end"]), float((plan["times"] as Dictionary)["deposit_end"]) + 0.3, "out")
	return v


# ---------------------------------------------------------------------------
# Maths
# ---------------------------------------------------------------------------

static func _d(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


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
