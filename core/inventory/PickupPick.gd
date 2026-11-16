class_name PickupPick
extends RefCounted

## The pick rule of the pickup event (D-06, D-12, D-39): how much one chooser Echo wants one find.
## Pure statics. No RNG, no writes, no player text. Numbers: `data.inventory.pick` (pick-numbers.md).
## Reads an Echo through the same keys combat uses (`BehaviorArbiter._score`): `calling` else
## `calling_origin`, `archetype_birth`, `vector_scores`, `traits`, `stats`, and morale/fear/fear_base.
##
## chooser = { actor: Dictionary, judgment: float 0..1, composure: float 0..1 }; the caller reads
## Judgment and composure the way `StagePartyStance.read_echo` does (`MaturityExpressionService`).
## ctx = `ctx_from(data)`; `data` is the `data` block of balance.json.

const KINDS: Array = ["gear", "relic", "consumable", "material"]
const CALLINGS: Array = ["okofor", "onyamesu", "aduro", "sum_okwanfo", "okomfo", "kra_soro"]
const ARCHETYPES: Array = ["valiant", "proud", "ambitious", "canny", "loyal", "stoic", "devout", "empathic", "reflective"]
const VECTORS: Array = ["vanguard", "protector", "seeker", "pillar", "strategist", "skeptic", "devoted", "opportunist", "mediator", "nurturer"]
const TRAITS: Array = ["courage", "wisdom", "faith"]
const STATS: Array = ["max_hp", "atk", "def", "agi", "int", "cha"]

## Two totals closer than this are a tie (float noise must not decide an order).
const TIE_EPS := 0.000001


static func ctx_from(data: Dictionary) -> Dictionary:
	var mat := _d(data.get("maturity_expression"))
	var inv := _d(data.get("inventory"))
	var grades_v: Variant = inv.get("grades", [])
	return {
		"pick": _d(inv.get("pick")),
		"grades": grades_v if grades_v is Array else [],
		"table": EmotionStatusLean.table_of(_d(_d(data.get("combat")).get("movement"))),
		"exponent": _d(data.get("actor")).get("afraid_curve_exponent", null),
		"dampen": BehaviorArbiter.composure_dampen(mat),
		"id_scale": _d(mat.get("identity_weight_scale")),
		"calling_behavior": _d(mat.get("calling_behavior")),
	}


## [afraid, bold]: curved and composure-softened, as the action layer reads them (D-12 assumption E).
## [0, 0] for an invalid exponent, as `BehaviorArbiter._state_ends` does: the status then adds nothing,
## and nobody freezes. `EmotionStatusLean.state_ends` does not check the exponent, so this does.
static func state_ends(chooser: Dictionary, ctx: Dictionary) -> Array:
	if not BehaviorArbiter.is_valid_afraid_curve_exponent(ctx.get("exponent", null)):
		return [0.0, 0.0]
	return EmotionStatusLean.state_ends(_d(chooser.get("actor")), float(chooser.get("composure", 0.0)),
		_d(ctx.get("table")), float(ctx["exponent"]), float(ctx.get("dampen", 0.0)))


## True when the chooser takes nothing (D-39): afraid is at or above `freeze_at`.
static func frozen(chooser: Dictionary, ctx: Dictionary) -> bool:
	# UNWIRED (target: NEW "Pickup tuning from real play"): freeze_at is untuned for real play; probe P3 shows only the status at the event
	return float(state_ends(chooser, ctx)[0]) >= float(_d(ctx.get("pick")).get("freeze_at", INF))


## Score of one find for the chooser. `parts` names every term; identity, sense and state are their sums.
static func appeal(chooser: Dictionary, find: Dictionary, ctx: Dictionary) -> Dictionary:
	var pick := _d(ctx.get("pick"))
	var actor := _d(chooser.get("actor"))
	var kind := str(find.get("kind", ""))
	var j := clampf(float(chooser.get("judgment", 0.0)), 0.0, 1.0)
	var id_scale := _d(ctx.get("id_scale"))
	var calling := _calling_of(actor)

	var vector_sum := 0.0
	var scores := _d(actor.get("vector_scores"))
	for v: String in _d(pick.get("vector_pick_muls")):
		vector_sum += float(scores.get(v, 0)) * _cell2(pick, "vector_pick_muls", v, kind)
	var trait_sum := 0.0
	var traits := _d(actor.get("traits"))
	for t: String in _d(pick.get("trait_pick_muls")):
		trait_sum += float(traits.get(t, 0)) * _cell2(pick, "trait_pick_muls", t, kind)
	var stat_sum := 0.0
	var stats := _d(actor.get("stats"))
	for s: String in _d(pick.get("stat_pick_muls")):
		stat_sum += float(stats.get(s, 0)) * _cell2(pick, "stat_pick_muls", s, kind)

	var parts := {
		"calling": _cell2(pick, "calling_pick", calling, kind),
		"archetype": _cell2(pick, "archetype_pick", str(actor.get("archetype_birth", "")), kind),
		"vector": vector_sum * (1.0 + j * float(id_scale.get("vector", 0.0))),
		"trait": trait_sum * (1.0 + j * float(id_scale.get("trait", 0.0))),
		"stat": stat_sum,
	}
	var identity: float = float(parts["calling"]) + float(parts["archetype"]) + float(parts["vector"]) \
		+ float(parts["trait"]) + float(parts["stat"])

	var worth := worth_of(find, ctx)
	var base := float(pick.get("sense_base", 0.0))
	var sense: float = worth * float(pick.get("worth_weight", 0.0)) * (base + (1.0 - base) * j)

	var ends := state_ends(chooser, ctx)
	var signature := _d(_d(_d(ctx.get("calling_behavior")).get(calling)).get("afraid_pick_signature"))
	parts["afraid"] = float(ends[0]) * _cell1(pick, "afraid_pick", kind)
	parts["bold"] = float(ends[1]) * _cell1(pick, "bold_pick", kind)
	parts["signature"] = float(ends[0]) * float(signature.get(kind, 0.0))
	var state: float = float(parts["afraid"]) + float(parts["bold"]) + float(parts["signature"])

	return { "identity": identity, "sense": sense, "state": state, "total": identity + sense + state,
		"worth": worth, "parts": parts }


## Worth of a find before Judgment: kind weight + grade steps + capped extra units. An ungraded find
## (or a grade not in `data.inventory.grades`) has grade index 0.
static func worth_of(find: Dictionary, ctx: Dictionary) -> float:
	var pick := _d(ctx.get("pick"))
	var grade_index := maxi(0, (ctx.get("grades", []) as Array).find(str(find.get("grade", ""))))
	var qty := clampi(int(find.get("quantity", 1)), 1, maxi(1, int(pick.get("quantity_cap", 1))))
	return float(_d(pick.get("kind_weight")).get(str(find.get("kind", "")), 0.0)) \
		+ float(pick.get("grade_step", 0.0)) * grade_index + float(pick.get("quantity_gain", 0.0)) * (qty - 1)


## The finds the chooser takes, best first. Ties go to the lower `find_id` (D-06; plain String order).
## A frozen chooser takes nothing: [] (D-39). Returns the find dictionaries, not copies.
static func order(chooser: Dictionary, finds: Array, ctx: Dictionary) -> Array:
	if frozen(chooser, ctx):
		return []
	var rows: Array = []
	for f: Dictionary in finds:
		rows.append([snappedf(float(appeal(chooser, f, ctx)["total"]), TIE_EPS), str(f.get("find_id", "")), f])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1] < b[1] if a[0] == b[0] else a[0] > b[0])
	return rows.map(func(r: Array) -> Dictionary: return r[2])


## Why the chooser took this find, as one class for the UI to word: "froze" when frozen, else the
## largest of "identity", "sense", "state" (a tie goes in that order). "fit" is not emitted: no rule
## in D-06 defines it apart from "identity".
static func reason(chooser: Dictionary, find: Dictionary, ctx: Dictionary) -> String:
	if frozen(chooser, ctx):
		return "froze"
	var a := appeal(chooser, find, ctx)
	var best := "identity"
	for key: String in ["sense", "state"]:
		if float(a[key]) > float(a[best]):
			best = key
	return best


static func _calling_of(actor: Dictionary) -> String:
	var confirmed := str(actor.get("calling", ""))
	return confirmed if not confirmed.is_empty() and confirmed != "uncalled" else str(actor.get("calling_origin", "uncalled"))


## One cell of a kind-keyed table (afraid_pick, bold_pick): pick[table][kind]. 0.0 when the table is missing
## or the kind is empty, unknown or not in KINDS. Never returns a Dictionary.
static func _cell1(pick: Dictionary, table: String, kind: String) -> float:
	if not KINDS.has(kind):
		return 0.0
	return float(_d(pick.get(table)).get(kind, 0.0))


## One cell of a row-then-kind table (calling, archetype, vector, trait, stat): pick[table][row][kind]. 0.0
## when the table or row is missing or the kind is empty, unknown or not in KINDS.
static func _cell2(pick: Dictionary, table: String, row: String, kind: String) -> float:
	if not KINDS.has(kind):
		return 0.0
	return float(_d(_d(pick.get(table)).get(row)).get(kind, 0.0))


static func _d(v: Variant) -> Dictionary:
	return v as Dictionary if v is Dictionary else {}
