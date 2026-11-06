class_name EarningsService
extends RefCounted

## The packs: what a party has earned on a path and not yet banked. One list of rows on the stage
## record (`stage.earnings`). Every payer reads these rows; no source pays the balance directly.
##
## Row = { id, source, kind, ase, ekwan, scaled, keep_on_defeat, settled, settled_share, lost, items }.
## `ase` and `ekwan` are BASE amounts. A `scaled` row takes the realm scale and the replay factor, and
## the payer rounds ONCE on the sum of the scaled rows. `id` is the exactly-once stamp. `items` holds the
## one entry of an item row (`record_item`) and is empty on every other row. An item row carries no
## currency and is never settled by `mark_settled`: the leave, defeat and path-end item paths mark it.
## Pure statics: no RNG, no save call, no tick of its own.

const SOURCE_OBJECTIVE := "objective"
const SOURCE_ENCOUNTER := "encounter"
const SOURCE_FOUND := "found"
const SOURCE_ITEM := "item"
const KIND_FIGHT := "fight"
## The encounter id of a hostile-Claimant forced fight ends with this.
const CLAIMANT_FIGHT_SUFFIX := ".claimant"


static func make_row(id: String, source: String, kind: String, ase: int, ekwan: int,
		scaled: bool = true, keep_on_defeat: bool = false) -> Dictionary:
	return { "id": id, "source": source, "kind": kind, "ase": ase, "ekwan": ekwan, "scaled": scaled,
		"keep_on_defeat": keep_on_defeat, "settled": false, "settled_share": 0, "lost": false, "items": [] }


static func rows_of(stage: Dictionary) -> Array:
	var v: Variant = stage.get("earnings", [])
	return v if v is Array else []


static func has_row(stage: Dictionary, id: String) -> bool:
	return not row_of(stage, id).is_empty()


## The row with this id, or {}.
static func row_of(stage: Dictionary, id: String) -> Dictionary:
	for r_v in rows_of(stage):
		if r_v is Dictionary and str((r_v as Dictionary).get("id", "")) == id:
			return r_v
	return {}


## The one writer. Returns false and writes nothing when the id exists, the id is empty, or the row
## holds no Ase, no Ekwan and no item.
static func add_row(stage: Dictionary, row: Dictionary) -> bool:
	var id := str(row.get("id", ""))
	if id.is_empty() or has_row(stage, id):
		return false
	if int(row.get("ase", 0)) <= 0 and int(row.get("ekwan", 0)) <= 0 and not is_item_row(row):
		return false
	var rows := rows_of(stage)
	rows.append(row)
	stage["earnings"] = rows
	return true


## True when the row holds at least one item entry.
static func is_item_row(row: Variant) -> bool:
	return row is Dictionary and (row as Dictionary).get("items", null) is Array \
		and not ((row as Dictionary)["items"] as Array).is_empty()


## The open item rows of the stage (not settled, not lost), in row order.
static func open_item_rows(stage: Dictionary) -> Array:
	return unsettled(rows_of(stage)).filter(func(r): return is_item_row(r))


## How many open item rows (not settled, not lost) the whole save holds, over every Realm and every stage.
## Pack room counts this number, because a row left open in one Realm still owns a pack slot. Read only.
static func open_item_rows_in_save(save: Dictionary) -> int:
	var realms_v: Variant = save.get("realms", {})
	if not (realms_v is Dictionary):
		return 0
	var total := 0
	for realm_v in (realms_v as Dictionary).values():
		if not (realm_v is Dictionary):
			continue
		var stages_v: Variant = (realm_v as Dictionary).get("stages", [])
		if not (stages_v is Array):
			continue
		for stage_v in (stages_v as Array):
			if stage_v is Dictionary:
				total += open_item_rows(stage_v as Dictionary).size()
	return total


## Rows a payer may still pay: not settled by a leave and not lost.
static func unsettled(rows: Array) -> Array:
	var out: Array = []
	for r_v in rows:
		if r_v is Dictionary and not bool((r_v as Dictionary).get("settled", false)) \
				and not bool((r_v as Dictionary).get("lost", false)):
			out.append(r_v)
	return out


## Base sums of `rows`. Unscaled rows are summed apart. The payers read only the scaled sums, so a
## row with `scaled` false is never paid until a payer reads `flat_*`; no producer writes one.
static func sums(rows: Array) -> Dictionary:
	var out := { "scaled_ase": 0, "scaled_ekwan": 0, "flat_ase": 0, "flat_ekwan": 0 }
	for r_v in rows:
		var r: Dictionary = r_v if r_v is Dictionary else {}
		var prefix := "scaled_" if bool(r.get("scaled", true)) else "flat_"
		out[prefix + "ase"] = int(out[prefix + "ase"]) + int(r.get("ase", 0))
		out[prefix + "ekwan"] = int(out[prefix + "ekwan"]) + int(r.get("ekwan", 0))
	return out


## What the payers would pay now: the sums of the unsettled rows plus `ids`, the rows they cover. A
## completed objective with no row is counted from a row built on the fly, so a preview equals the
## payout after `ensure_objective_rows`. `sources` splits the open rows by source: { rows, ase } with
## the BASE Ase of the scaled rows, so a payer can split its ledger without a second formula. `all` counts
## every row of the source, settled and lost too: it feeds a count text, never an amount. Item rows hold no
## Ase, so `sources.item.ase` stays 0. Pure.
static func plan(stage: Dictionary, reward_cfg: Dictionary) -> Dictionary:
	var rows := rows_of(stage).duplicate()
	rows.append_array(_missing_objective_rows(stage, reward_cfg, null, 0))
	var open := unsettled(rows)
	var out := sums(open)
	var ids: Array = []
	var sources := {}
	for source in [SOURCE_OBJECTIVE, SOURCE_ENCOUNTER, SOURCE_FOUND, SOURCE_ITEM]:
		sources[source] = { "rows": 0, "ase": 0, "all": 0 }
	for r_v in rows:
		var any_part: Dictionary = sources.get(str((r_v as Dictionary).get("source", "")) if r_v is Dictionary else "", {})
		if not any_part.is_empty():
			any_part["all"] = int(any_part["all"]) + 1
	for r_v in open:
		var r: Dictionary = r_v
		ids.append(str(r.get("id", "")))
		var part: Dictionary = sources.get(str(r.get("source", "")), {})
		if not part.is_empty():
			part["rows"] = int(part["rows"]) + 1
			if bool(r.get("scaled", true)):
				part["ase"] = int(part["ase"]) + int(r.get("ase", 0))
	out["ids"] = ids
	out["sources"] = sources
	return out


## Marks the rows named in `ids` as settled by a leave. `share_pct` is 0, 50 or 100.
static func mark_settled(stage: Dictionary, ids: Array, share_pct: int) -> void:
	for r_v in rows_of(stage):
		var r: Dictionary = r_v if r_v is Dictionary else {}
		if ids.has(str(r.get("id", ""))):
			r["settled"] = true
			r["settled_share"] = share_pct


## The rows a defeat loses: unsettled and not kept on defeat.
static func losable(rows: Array) -> Array:
	return unsettled(rows).filter(func(r): return not bool((r as Dictionary).get("keep_on_defeat", false)))


## Marks every losable row lost. Returns how many rows it marked.
static func mark_lost(stage: Dictionary) -> int:
	var n := 0
	for r_v in losable(rows_of(stage)):
		(r_v as Dictionary)["lost"] = true
		n += 1
	return n


# ---------------------------------------------------------------------------
# Fight and found rows
# ---------------------------------------------------------------------------

## Row id of a won fight that is not an objective. The Claimant fight has its own id: its situation
## is resolved before the fight starts.
static func fight_id(situation_id: String, claimant: bool) -> String:
	return "enc:%s%s" % [situation_id, ":claimant" if claimant else ""]


## Writes the one `fight` row of a won fight: Ase only, scaled. False when the situation is unknown or
## the row exists. The weight is read only when the row is new, so a repeat logs nothing.
static func record_fight(stage: Dictionary, situation_id: String, claimant: bool, reward_cfg: Dictionary,
		logger: StructuredLogger = null, t: int = 0) -> bool:
	var id := fight_id(situation_id, claimant)
	if situation_id.is_empty() or has_row(stage, id):
		return false
	var ase := RewardCalc.encounter_weight(reward_cfg, KIND_FIGHT, logger, t)
	return add_row(stage, make_row(id, SOURCE_ENCOUNTER, KIND_FIGHT, ase, 0))


## Writes the row of Ase found on a situation (`money`, `claimant_good`). Scaled like every other row.
static func record_found(stage: Dictionary, situation_id: String, kind: String, ase: int) -> bool:
	if situation_id.is_empty():
		return false
	return add_row(stage, make_row("found:%s" % situation_id, SOURCE_FOUND, kind, ase, 0))


# ---------------------------------------------------------------------------
# Item rows
# ---------------------------------------------------------------------------

## `stage.held_fates` holds one record per held piece: { id, type_id, kind, grade, token, fate, reason_key }.
## `token` names the settle that decided it, so a retry of the same settle never draws the piece again.
static func held_fates_of(stage: Dictionary) -> Array:
	var v: Variant = stage.get("held_fates", [])
	return v if v is Array else []


## True when a record for this piece carries this token.
static func has_held_fate(stage: Dictionary, piece_id: String, token: String) -> bool:
	for r_v in held_fates_of(stage):
		if r_v is Dictionary and str((r_v as Dictionary).get("id", "")) == piece_id \
				and str((r_v as Dictionary).get("token", "")) == token:
			return true
	return false


## Writes the record of a held piece. A newer record replaces the older one of the same piece id.
static func put_held_fate(stage: Dictionary, record: Dictionary) -> void:
	var fates := held_fates_of(stage)
	for i in fates.size():
		if fates[i] is Dictionary and str((fates[i] as Dictionary).get("id", "")) == str(record.get("id", "")):
			fates[i] = record
			stage["held_fates"] = fates
			return
	fates.append(record)
	stage["held_fates"] = fates


## A held-piece record: { id, type_id, kind, grade, token, fate, reason_key }. The one builder for the leave and the defeat.
static func held_record(piece: Dictionary, token: String, fate: String, reason_key: String) -> Dictionary:
	return { "id": piece["id"], "type_id": piece["type_id"], "kind": piece["kind"], "grade": piece["grade"],
		"token": token, "fate": fate, "reason_key": reason_key }


## One item as the result screens and the leave confirmation show it. No id. `source` is "gathered" (an item row
## on the path) or "held" (a piece carried from an earlier path). `mark_index` is the piece mark
## (`InventoryService.mark_index_of`), or -1 when the item has no piece id yet.
static func at_risk_row(e: Dictionary, source: String, mark_index: int) -> Dictionary:
	return { "type_id": str(e.get("type_id", "")), "kind": str(e.get("kind", "")), "grade": str(e.get("grade", "")),
		"quantity": int(e.get("quantity", 1)), "source": source, "mark_index": mark_index }


## A row of a leave, defeat or path-end item report: `at_risk_row` plus the `reason_key`, and `lost_quantity`
## when a stack surplus was lost. The one builder for all three reports.
static func report_row(e: Dictionary, reason: String, source: String, mark_index: int) -> Dictionary:
	var out := at_risk_row(e, source, mark_index)
	out["reason_key"] = reason
	if int(e.get("lost_quantity", 0)) > 0:
		out["lost_quantity"] = int(e["lost_quantity"])
	return out


## Row id of one find. It is the exactly-once stamp of that find.
## Contract for the caller (ITEM-002): send the same `find_id` for the same find on every call, in any order.
static func item_id(situation_id: String, find_id: String) -> String:
	return "item:%s:%s" % [situation_id, find_id]


## Writes the row of one gathered find: no currency, one entry. `entry` = { type_id, kind, grade, quantity }.
## False when the situation id or the find id is empty, or the row exists.
static func record_item(stage: Dictionary, situation_id: String, find_id: String, entry: Dictionary) -> bool:
	if situation_id.is_empty() or find_id.is_empty():
		return false
	var item := {
		"type_id": str(entry.get("type_id", "")), "kind": str(entry.get("kind", "")),
		"grade": str(entry.get("grade", "")), "quantity": int(entry.get("quantity", 1)),
		"fate": "gathered", "reason_key": "ok" }
	var row := make_row(item_id(situation_id, find_id), SOURCE_ITEM, str(item["kind"]), 0, 0, false, false)
	row["items"] = [item]
	return add_row(stage, row)


# ---------------------------------------------------------------------------
# Objective rows
# ---------------------------------------------------------------------------

static func objective_id(stage: Dictionary, objective_index: int) -> String:
	return "obj:%d:%d" % [int(stage.get("index", -1)), objective_index]


## The row of one objective: its type weight in `objective_weights` and `objective_ekwan`. {} when
## the objective does not exist or its weights are both 0 (the boss stub, an unknown type).
static func objective_row(stage: Dictionary, objective_index: int, reward_cfg: Dictionary,
		logger: StructuredLogger = null, t: int = 0) -> Dictionary:
	var objs_v: Variant = stage.get("objectives", [])
	var objs: Array = objs_v if objs_v is Array else []
	if objective_index < 0 or objective_index >= objs.size() or not (objs[objective_index] is Dictionary):
		return {}
	var type := str((objs[objective_index] as Dictionary).get("type", ""))
	var ase_v: Variant = reward_cfg.get("objective_weights", {})
	var ekwan_v: Variant = reward_cfg.get("objective_ekwan", {})
	var ase := RewardCalc.type_weight(type, objective_index,
		ase_v if ase_v is Dictionary else {}, "objective_weights", logger, t)
	var ekwan := RewardCalc.type_weight(type, objective_index,
		ekwan_v if ekwan_v is Dictionary else {}, "objective_ekwan", logger, t)
	if ase <= 0 and ekwan <= 0:
		return {}
	return make_row(objective_id(stage, objective_index), SOURCE_OBJECTIVE, type, ase, ekwan)


## Writes the row of an objective that has just completed. Call it beside every `completed = true`.
static func record_objective(stage: Dictionary, objective_index: int, reward_cfg: Dictionary,
		logger: StructuredLogger = null, t: int = 0) -> bool:
	var row := objective_row(stage, objective_index, reward_cfg, logger, t)
	return not row.is_empty() and add_row(stage, row)


## Safety net for a completion hook that wrote no row: logs `economy.earnings.missing_row` and writes
## the row. Every payer calls it before it reads the rows.
static func ensure_objective_rows(stage: Dictionary, reward_cfg: Dictionary,
		logger: StructuredLogger, t: int) -> void:
	for row_v in _missing_objective_rows(stage, reward_cfg, logger, t):
		var row: Dictionary = row_v
		logger.warn(t, "economy.earnings.missing_row", "Completed objective had no earnings row; row written now", {
			"stage_index": int(stage.get("index", -1)), "id": row["id"] })
		add_row(stage, row)


static func _missing_objective_rows(stage: Dictionary, reward_cfg: Dictionary,
		logger: StructuredLogger, t: int) -> Array:
	var out: Array = []
	var objs_v: Variant = stage.get("objectives", [])
	var objs: Array = objs_v if objs_v is Array else []
	for i in objs.size():
		var o: Dictionary = objs[i] if objs[i] is Dictionary else {}
		if bool(o.get("completed", false)) and not has_row(stage, objective_id(stage, i)):
			var row := objective_row(stage, i, reward_cfg, logger, t)
			if not row.is_empty():
				out.append(row)
	return out
