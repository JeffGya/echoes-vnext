class_name EarningsService
extends RefCounted

## The packs: what a party has earned on a path and not yet banked. One list of rows on the stage
## record (`stage.earnings`). Every payer reads these rows; no source pays the balance directly.
##
## Row = { id, source, kind, ase, ekwan, scaled, keep_on_defeat, settled, settled_share, lost, items }.
## `ase` and `ekwan` are BASE amounts. A `scaled` row takes the realm scale and the replay factor, and
## the payer rounds ONCE on the sum of the scaled rows. `id` is the exactly-once stamp. `items` is
## reserved and always empty. Pure statics: no RNG, no save call, no tick of its own.

const SOURCE_OBJECTIVE := "objective"
const SOURCE_ENCOUNTER := "encounter"
const SOURCE_FOUND := "found"
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
## holds no Ase and no Ekwan.
static func add_row(stage: Dictionary, row: Dictionary) -> bool:
	var id := str(row.get("id", ""))
	if id.is_empty() or has_row(stage, id):
		return false
	if int(row.get("ase", 0)) <= 0 and int(row.get("ekwan", 0)) <= 0:
		return false
	var rows := rows_of(stage)
	rows.append(row)
	stage["earnings"] = rows
	return true


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
## the BASE Ase of the scaled rows, so a payer can split its ledger without a second formula. Pure.
static func plan(stage: Dictionary, reward_cfg: Dictionary) -> Dictionary:
	var rows := rows_of(stage).duplicate()
	rows.append_array(_missing_objective_rows(stage, reward_cfg, null, 0))
	var open := unsettled(rows)
	var out := sums(open)
	var ids: Array = []
	var sources := {}
	for source in [SOURCE_OBJECTIVE, SOURCE_ENCOUNTER, SOURCE_FOUND]:
		sources[source] = { "rows": 0, "ase": 0 }
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


## Marks every unsettled row lost, except rows kept on defeat. Returns how many rows it marked.
static func mark_lost(stage: Dictionary) -> int:
	var n := 0
	for r_v in unsettled(rows_of(stage)):
		var r: Dictionary = r_v
		if not bool(r.get("keep_on_defeat", false)):
			r["lost"] = true
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
