# res://tests/PickupProbeTests.gd
#
# V2-ITEM-001b step C11: the three probes of the pickup event (decisions D-09, D-49, D-50, D-63, D-64).
# MEASURES. Asserts two approved things: the D-50 hand check (cap 2, rank C, mean 1.45) and, at FULL size, the D-63 pass line.
# Fear and win drift: the win drift (apply_encounter_emotion_drift) runs in a LATER dispatch than the one that opens
# the pickup event, so in a real fight the event reads the chooser's fear BEFORE the win relief (fear -5, morale +10).
# P3 reports that real timing; it is not a probe artefact.
#
#   P1  finds chance: FindsRules.roll_count_with, cap 2..6 x rank D C B A S. Pure.
#   P2  pick rule: Standing 1 against Standing 9 on the same finds (D-63). Pure.
#   P3  real freeze rate: real won fights through FlowRuntime.dispatch. Only when PICKUP_PROBE_FIGHTS > 0.
#
# Size (env vars; the default is small so CI stays fast):
#   PICKUP_PROBE_FULL=1        P1 20000 rolls per cell, P2 2000 cases per cell, full tables, P2 pass line asserted.
#   PICKUP_PROBE_FIGHTS=<N>    P3 plays N real fights. Without it P3 prints one line and does nothing.
# Every probe prints its arm counts BEFORE any result (LESSONS #38, #40).
# P3 edits NO tracked file. It writes only under ECHOES_TEST_SAVE_DIR, and it refuses to run without that variable.

class_name PickupProbeTests
extends RefCounted

const _SEED := 20261115
const _RANKS := ["D", "C", "B", "A", "S"]
const _GRADES := ["g0", "g1", "g2", "g3", "g4"]
const _P2_SMALL := 100
const _P2_FULL := 2000
const _P1_SMALL := 2000
const _P1_FULL := 20000
const _MIN_JUDGMENT_GAP := 0.3
# D-63 pass line, pooled over the 18 cells.
const _M1_LO := 0.15
const _M1_HI := 0.60
const _M3_MIN := 0.5
const _M4_MIN := 0.70

# D-63 states. "afraid"/"bold" are the unsoftened state value the probe puts on the chooser's status.
const _STATES := [
	{ "id": "calm", "status": "grounded", "morale": 50, "fear": 0 },
	{ "id": "uneasy", "status": "burdened", "morale": 50, "fear": 50, "afraid": 0.3 },
	{ "id": "bold", "status": "radiant", "morale": 80, "fear": 5, "bold": 0.8 },
]

# P3 arms: one per status of EmotionService.STATUS_LADDER. All five Echoes get the same values.
const _P3_ARMS := [
	{ "status": "hollow", "morale": 50, "fear": 90 },
	{ "status": "fraying", "morale": 50, "fear": 80 },
	{ "status": "strained", "morale": 50, "fear": 70 },
	{ "status": "pressed", "morale": 50, "fear": 60 },
	{ "status": "burdened", "morale": 50, "fear": 50 },
	{ "status": "hesitant", "morale": 30, "fear": 0 },
	{ "status": "uncertain", "morale": 37, "fear": 20 },
	{ "status": "grounded", "morale": 50, "fear": 20 },
	{ "status": "whole", "morale": 60, "fear": 10 },
	{ "status": "radiant", "morale": 80, "fear": 5 },
]
const _P3_TYPES := ["ph_weapon_a", "ph_relic_a", "ph_material_a", "ph_armor_a", "ph_weapon_a", "ph_relic_a"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_probe/p1_finds_chance", Callable(PickupProbeTests, "_t_p1"))
	runner.register_test("pickup_probe/p2_pick_rule_standing_1_vs_9", Callable(PickupProbeTests, "_t_p2"))
	runner.register_test("pickup_probe/p3_real_freeze_rate", Callable(PickupProbeTests, "_t_p3"))


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _full() -> bool:
	return OS.get_environment("PICKUP_PROBE_FULL") == "1"


static func _fights() -> int:
	var v := OS.get_environment("PICKUP_PROBE_FIGHTS")
	return maxi(0, int(v)) if v != "" else 0


# ---------------------------------------------------------------------------
# P1 finds chance
# ---------------------------------------------------------------------------

## Chance of slot `slot` at modifier `mod`, from the raw config numbers (not through FindsRules).
static func _p1_chance(base: Array, mod: int, max_pct: int, slot: int) -> float:
	return float(clampi(int(base[slot]) + mod, 0, max_pct)) / 100.0


static func _t_p1() -> Dictionary:
	var real := ConfigService.new()
	real.load_balance()
	var inv := ConfigService.get_inventory_cfg(real)
	var chance: Dictionary = inv["finds_chance"]
	var base: Array = chance["base_by_slot_pct"]
	var mods: Dictionary = chance["rank_modifier_pct"]
	var max_pct := int(chance["max_pct"])
	var floor_p := float(chance["first_find_floor_pct"]) / 100.0
	var rolls := _P1_FULL if _full() else _P1_SMALL
	var m: Array = []

	print("PROBE P1 arms: 5 caps (2..6) x %d ranks = %d cells, %d rolls per cell, %d rolls in total, size %s" % [
		_RANKS.size(), 5 * _RANKS.size(), rolls, 5 * _RANKS.size() * rolls, "FULL" if _full() else "small"])
	print("PROBE P1 cap | rank | rolls | hist 0..cap | mean | expected | tol(5 sd) | P(0) | P(cap)")
	var means := {}
	var p_any := {}
	for cap in range(2, 7):
		for rank: String in _RANKS:
			var rng := CampaignSeed.get_rng_from(_SEED, "pickup_probe.p1.%d.%s" % [cap, rank])
			var hist: Array = []
			hist.resize(cap + 1)
			hist.fill(0)
			var total := 0
			for _i in rolls:
				var c := FindsRules.roll_count_with(inv, rng, cap, rank)
				hist[c] = int(hist[c]) + 1
				total += c
			var n := 0
			for h in hist:
				n += int(h)
			var mean := float(total) / float(maxi(1, n))
			# Slots are independent (D-50): the count has mean sum(p) and variance sum(p(1-p)).
			var expected := 0.0
			var variance := 0.0
			for slot in cap:
				var p := _p1_chance(base, int(mods[rank]), max_pct, slot)
				expected += p
				variance += p * (1.0 - p)
			var tol := 5.0 * sqrt(variance / float(maxi(1, n)))
			var p0 := float(hist[0]) / float(maxi(1, n))
			var pcap := float(hist[cap]) / float(maxi(1, n))
			means["%d.%s" % [cap, rank]] = mean
			p_any["%d.%s" % [cap, rank]] = 1.0 - p0
			print("PROBE P1 %d | %s | %d | %s | %.4f | %.4f | %.4f | %.4f | %.4f" % [cap, rank, n, str(hist), mean, expected, tol, p0, pcap])
			if n != rolls:
				m.append("cap %d rank %s: arm count %d, expected %d" % [cap, rank, n, rolls])
			if absf(mean - expected) > tol:
				m.append("cap %d rank %s: mean %.4f is not within %.4f of the config mean %.4f" % [cap, rank, mean, tol, expected])

	# Hand check: cap 2 at rank C is 0.85 + 0.60 = 1.45. Tolerance: 5 standard errors of the mean,
	# 5 x sqrt(0.85 x 0.15 + 0.60 x 0.40) / sqrt(rolls): 0.068 at 2000 rolls, 0.021 at 20000.
	var hand_exp := _p1_chance(base, int(mods["C"]), max_pct, 0) + _p1_chance(base, int(mods["C"]), max_pct, 1)
	var hand_tol := 5.0 * sqrt(0.85 * 0.15 + 0.60 * 0.40) / sqrt(float(rolls))
	var hand_mean := float(means["2.C"])
	print("PROBE P1 hand check cap 2 rank C: config %.4f (hand 1.45), measured %.4f, tolerance %.4f" % [hand_exp, hand_mean, hand_tol])
	if absf(hand_exp - 1.45) > 0.000001:
		m.append("hand check: the config gives %.4f at cap 2 rank C, the hand value is 1.45 (0.85 + 0.60)" % hand_exp)
	if absf(hand_mean - 1.45) > hand_tol:
		m.append("hand check: measured %.4f is not within %.4f of 1.45" % [hand_mean, hand_tol])

	# Lever check (LESSONS #38): the rank must move the mean. Margin: half the config difference of the means.
	for cap in range(2, 7):
		var diff_sc := 0.0
		var diff_cd := 0.0
		for slot in cap:
			diff_sc += _p1_chance(base, int(mods["S"]), max_pct, slot) - _p1_chance(base, int(mods["C"]), max_pct, slot)
			diff_cd += _p1_chance(base, int(mods["C"]), max_pct, slot) - _p1_chance(base, int(mods["D"]), max_pct, slot)
		var moved_sc := float(means["%d.S" % cap]) - float(means["%d.C" % cap])
		var moved_cd := float(means["%d.C" % cap]) - float(means["%d.D" % cap])
		print("PROBE P1 lever cap %d: mean(S) - mean(C) = %.4f (config %.4f, margin %.4f); mean(C) - mean(D) = %.4f (config %.4f)" % [
			cap, moved_sc, diff_sc, diff_sc * 0.5, moved_cd, diff_cd])
		if diff_sc <= 0.0 or moved_sc <= diff_sc * 0.5:
			m.append("lever: cap %d, mean(S) - mean(C) = %.4f is not above the margin %.4f: the rank modifier does not move the count" % [cap, moved_sc, diff_sc * 0.5])
		if diff_cd > 0.0 and moved_cd <= diff_cd * 0.5:
			m.append("lever: cap %d, mean(C) - mean(D) = %.4f is not above the margin %.4f" % [cap, moved_cd, diff_cd * 0.5])

	# D-50 floor: at the lowest win rank (C) at least one find has a chance of the first-find floor or more.
	for cap in range(2, 7):
		var any_c := float(p_any["%d.C" % cap])
		if any_c < floor_p:
			m.append("floor: cap %d rank C P(at least one find) = %.4f is below the first-find floor %.2f" % [cap, any_c, floor_p])
	print("PROBE P1 floor: P(at least one find) at rank C: cap 2 %.4f, cap 3 %.4f, cap 6 %.4f (floor %.2f)" % [
		float(p_any["2.C"]), float(p_any["3.C"]), float(p_any["6.C"]), floor_p])
	# Boundary sanity (an off-by-one in `<` would move it): cap 1 gives the slot 0 hit rate alone.
	var rng0 := CampaignSeed.get_rng_from(_SEED, "pickup_probe.p1.slot0")
	var hits0 := 0
	for _i in rolls:
		hits0 += FindsRules.roll_count_with(inv, rng0, 1, "C")
	var p0_exp := _p1_chance(base, int(mods["C"]), max_pct, 0)
	var rate0 := float(hits0) / float(rolls)
	var tol0 := 5.0 * sqrt(p0_exp * (1.0 - p0_exp) / float(rolls))
	print("PROBE P1 slot 0 at rank C: hit rate %.4f, config %.4f, tolerance %.4f" % [rate0, p0_exp, tol0])
	if absf(rate0 - p0_exp) > tol0:
		m.append("boundary: the slot 0 hit rate at rank C is %.4f, config %.4f, tolerance %.4f" % [rate0, p0_exp, tol0])
	# D-50 floor rule: slot 0 at the lowest win rank (C) is at least first_find_floor_pct.
	for cap in range(2, 7):
		var slot0_pct := FindsRules.slot_chance_pct(inv, 0, "C")
		print("PROBE P1 floor rule cap %d: slot 0 chance at rank C = %d%% (floor %d%%)" % [cap, slot0_pct, int(chance["first_find_floor_pct"])])
		if slot0_pct < int(chance["first_find_floor_pct"]) or p0_exp * 100.0 < float(chance["first_find_floor_pct"]) - 0.000001:
			m.append("floor rule: cap %d slot 0 chance at rank C is %d%%, below the first-find floor %d%%" % [cap, slot0_pct, int(chance["first_find_floor_pct"])])
	return _result(m)


# ---------------------------------------------------------------------------
# P2 pick rule, Standing 1 against Standing 9 (D-63)
# ---------------------------------------------------------------------------

static func _new_acc() -> Dictionary:
	return { "cases": 0, "arm1": 0, "arm9": 0, "finds": 0, "j1": 0.0, "j9": 0.0, "freeze": 0, "nan": 0, "ties": 0,
		"m1": 0, "m2": 0, "w_diff": 0.0, "differ": 0, "differ_hi": 0, "differ_worth_tie": 0,
		"af1": 0.0, "bo1": 0.0, "af9": 0.0, "bo9": 0.0 }


static func _add_acc(into: Dictionary, from: Dictionary) -> void:
	for k: String in from:
		into[k] = into[k] + from[k]


## The pick-rule band table with the D-63 state value put on the chooser's own status.
static func _table_for(state: Dictionary, real_table: Dictionary, exponent: float) -> Dictionary:
	var t := real_table.duplicate(true)
	if state.has("afraid"):
		t[str(state["status"])] = -pow(float(state["afraid"]), 1.0 / exponent)
	if state.has("bold"):
		t[str(state["status"])] = float(state["bold"])
	return t


## One paired case: one Echo built once through the production factory and view, then copied into
## two arms that differ only in Standing (and the Calling being confirmed from Standing 3).
static func _p2_arms(data: Dictionary, cell_id: String, calling: String, state: Dictionary, i: int) -> Dictionary:
	var echo := EchoFactory.generate("pickup_probe.p2", "echo.%s.%d" % [cell_id, i], i, "summon",
		data["summoning"] as Dictionary, data["maturity_expression"] as Dictionary)
	echo["id"] = "probe_%s_%d" % [cell_id, i]
	echo["calling_origin"] = calling
	# Production runs init_vectors right after the summon (SanctumController) and in onboarding. Without it
	# vector_scores stay empty: no vector term and identity_coherence 0.
	var logger := StructuredLogger.new()
	logger.set_level("off")
	VectorService.init_vectors(echo, data["vectors"] as Dictionary, logger, 0)
	var sealed := JSON.stringify(echo["vector_scores"])
	var base := EchoActor.from_echo(echo)
	base["morale"] = int(state["morale"])
	base["fear"] = int(state["fear"])
	base["fear_base"] = 0
	base["xp_total"] = 0
	var a1 := base.duplicate(true)
	a1["rank"] = 1
	a1["calling"] = ""
	var a9 := base.duplicate(true)
	a9["rank"] = 9
	a9["calling"] = calling
	return { "a1": a1, "a9": a9, "sealed": sealed }


static func _view(data: Dictionary, actor: Dictionary) -> Dictionary:
	var id := str(actor["id"])
	return PickupEventService._chooser_view({}, data, [actor], [id], id)


## Counts a NaN total and an adjacent tie of totals (the id rule then decides) for one arm.
static func _noise(chooser: Dictionary, finds: Array, ctx: Dictionary) -> Vector2i:
	var totals: Array = []
	var nan := 0
	for f: Dictionary in finds:
		var tot := float(PickupPick.appeal(chooser, f, ctx)["total"])
		if is_nan(tot):
			nan += 1
		totals.append(tot)
	totals.sort()
	var ties := 0
	for k in range(1, totals.size()):
		if absf(float(totals[k]) - float(totals[k - 1])) < PickupPick.TIE_EPS:
			ties += 1
	return Vector2i(nan, ties)


static func _ids(order: Array) -> String:
	return ",".join(order.map(func(f: Variant) -> String: return str((f as Dictionary).get("find_id", ""))))


static func _t_p2() -> Dictionary:
	var real := ConfigService.new()
	real.load_balance()
	var data := ConfigService.get_balance_data(real)
	var base_ctx := PickupPick.ctx_from(data)
	base_ctx["grades"] = _GRADES
	var m: Array = []
	var exp_v: Variant = base_ctx["exponent"]
	if not BehaviorArbiter.is_valid_afraid_curve_exponent(exp_v):
		return _result(["the afraid curve exponent is not valid, so the freeze check would read 0"])
	var exponent := float(exp_v)
	var n_cases := _P2_FULL if _full() else _P2_SMALL

	# Hand check of the sense term (shipping sense_base is 0.0 since D-67; the formula holds for any value): worth x worth_weight x (sense_base + (1 - sense_base) x Judgment).
	var pick: Dictionary = base_ctx["pick"]
	var gear_worth := float((pick["kind_weight"] as Dictionary)["gear"])
	for j in [0.0, 1.0]:
		var want := gear_worth * float(pick["worth_weight"]) * (float(pick["sense_base"]) + (1.0 - float(pick["sense_base"])) * float(j))
		var got := float(PickupPick.appeal({ "actor": {}, "judgment": j, "composure": 0.0 },
			{ "find_id": "h", "kind": "gear", "grade": "g0", "quantity": 1 }, base_ctx)["sense"])
		print("PROBE P2 hand check sense at Judgment %.1f: config %.4f, rule %.4f" % [j, want, got])
		if absf(want - got) > 0.000001:
			m.append("hand check: sense at Judgment %.1f is %.4f, the hand value is %.4f" % [j, got, want])

	var cells: Array = []
	var sample_printed := false
	print("PROBE P2 grades: g0..g4 is a probe choice (shipping data.inventory.grades is empty; D-63 specifies grade index uniform 0..4)")
	var pooled := _new_acc()
	for calling: String in PickupPick.CALLINGS:
		for state: Dictionary in _STATES:
			var cell_id := "%s.%s" % [calling, str(state["id"])]
			var ctx := base_ctx.duplicate(true)
			ctx["table"] = _table_for(state, base_ctx["table"] as Dictionary, exponent)
			var acc := _new_acc()
			for i in n_cases:
				var rng := CampaignSeed.get_rng_from(_SEED, "pickup_probe.p2.%s.%d" % [cell_id, i])
				var finds: Array = []
				for k in rng.randi_range(2, 4):
					var kind: String = PickupPick.KINDS[rng.randi_range(0, 3)]
					finds.append({ "find_id": "f%d" % k, "type_id": "probe_" + kind, "kind": kind,
						"grade": _GRADES[rng.randi_range(0, 4)], "quantity": rng.randi_range(1, 3) })
				var arms := _p2_arms(data, cell_id, calling, state, i)
				if EmotionStatusLean.status_of(arms["a1"]) != str(state["status"]):
					return _result(["state %s: the actor status is '%s', expected '%s'" % [str(state["id"]), EmotionStatusLean.status_of(arms["a1"]), str(state["status"])]])
				# Both arms copy one dictionary, so the four fields below are equal by construction (this check only
				# catches a later edit of _p2_arms). The real checks: vectors exist, and both arms hold the vectors
				# that init_vectors wrote into the Echo before from_echo.
				for arm_key: String in ["a1", "a9"]:
					var vs: Variant = (arms[arm_key] as Dictionary)["vector_scores"]
					if not (vs is Dictionary) or (vs as Dictionary).is_empty():
						return _result(["cell %s case %d: arm %s has empty vector_scores (init_vectors was not applied)" % [cell_id, i, arm_key]])
					if JSON.stringify(vs) != str(arms["sealed"]):
						return _result(["cell %s case %d: arm %s does not hold the vectors from init_vectors" % [cell_id, i, arm_key]])
				if not sample_printed:
					sample_printed = true
					print("PROBE P2 sample vector_scores (cell %s case 0, after VectorService.init_vectors): %s" % [cell_id, str(arms["sealed"])])
				for key: String in ["vector_scores", "traits", "stats", "archetype_birth"]:
					if JSON.stringify((arms["a1"] as Dictionary)[key]) != JSON.stringify((arms["a9"] as Dictionary)[key]):
						return _result(["paired design broken: cell %s case %d, the two arms differ in '%s'" % [cell_id, i, key]])
				var c1 := _view(data, arms["a1"])
				var c9 := _view(data, arms["a9"])
				acc["cases"] += 1
				acc["arm1"] += 1
				acc["arm9"] += 1
				acc["finds"] += finds.size()
				acc["j1"] += float(c1["judgment"])
				acc["j9"] += float(c9["judgment"])
				var e1 := PickupPick.state_ends(c1, ctx)
				var e9 := PickupPick.state_ends(c9, ctx)
				acc["af1"] += float(e1[0])
				acc["bo1"] += float(e1[1])
				acc["af9"] += float(e9[0])
				acc["bo9"] += float(e9[1])
				if PickupPick.frozen(c1, ctx) or PickupPick.frozen(c9, ctx):
					acc["freeze"] += 1
					continue
				var o1 := PickupPick.order(c1, finds, ctx)
				var o9 := PickupPick.order(c9, finds, ctx)
				var n1 := _noise(c1, finds, ctx)
				var n9 := _noise(c9, finds, ctx)
				acc["nan"] += n1.x + n9.x
				acc["ties"] += n1.y + n9.y
				var first1: Dictionary = o1[0]
				var first9: Dictionary = o9[0]
				var w1 := PickupPick.worth_of(first1, ctx)
				var w9 := PickupPick.worth_of(first9, ctx)
				acc["w_diff"] += w9 - w1
				if _ids(o1) != _ids(o9):
					acc["m2"] += 1
				if str(first1["find_id"]) != str(first9["find_id"]):
					acc["m1"] += 1
					acc["differ"] += 1
					if w9 > w1:
						acc["differ_hi"] += 1
					elif absf(w9 - w1) < PickupPick.TIE_EPS:
						acc["differ_worth_tie"] += 1
			acc["id"] = cell_id
			cells.append(acc)
			var plain := acc.duplicate()
			plain.erase("id")
			_add_acc(pooled, plain)

	# Arms and the real Judgment first (LESSONS #38, #40), then the result.
	print("PROBE P2 arms: %d cells (6 Callings x 3 states), %d cases per cell, size %s, pooled cases %d (Standing 1 arm %d, Standing 9 arm %d), mean finds per case %.2f" % [
		cells.size(), n_cases, "FULL" if _full() else "small", int(pooled["cases"]), int(pooled["arm1"]), int(pooled["arm9"]),
		float(pooled["finds"]) / float(maxi(1, int(pooled["cases"])))])
	print("PROBE P2 mapping: Standing -> actor.rank; Judgment and composure from PickupEventService._chooser_view (build_ctx_inputs + derive_expression, no bonds, no vow, xp_total 0, vectors from VectorService.init_vectors); both arms keep the same Calling pick term (calling_origin set on both); the Calling is confirmed only at Standing 9, so confirmation reaches P2 only through Judgment (0.15 of the calm gap); Standing 9 is a newborn with rank 9 (no bonds, no vow, no XP, no rank stat growth), so its Judgment is a lower bound; state value %s" % str(_STATES))
	print("PROBE P2 cell | cases arm1/arm9 | Judgment S1 | Judgment S9 | gap | ends S1 afraid/bold | ends S9 afraid/bold | freezes")
	var low_cells := 0
	for c: Dictionary in cells:
		var cn := float(maxi(1, int(c["cases"])))
		var gap := (float(c["j9"]) - float(c["j1"])) / cn
		if gap < _MIN_JUDGMENT_GAP:
			low_cells += 1
		print("PROBE P2 %s | %d/%d | %.3f | %.3f | %.3f%s | %.3f/%.3f | %.3f/%.3f | %d" % [str(c["id"]), int(c["arm1"]), int(c["arm9"]),
			float(c["j1"]) / cn, float(c["j9"]) / cn, gap, " LOW" if gap < _MIN_JUDGMENT_GAP else "",
			float(c["af1"]) / cn, float(c["bo1"]) / cn, float(c["af9"]) / cn, float(c["bo9"]) / cn, int(c["freeze"])])
	var pn := float(maxi(1, int(pooled["cases"])))
	var j1 := float(pooled["j1"]) / pn
	var j9 := float(pooled["j9"]) / pn
	var gap_all := j9 - j1
	print("PROBE P2 pooled Judgment: Standing 1 = %.3f, Standing 9 = %.3f, gap = %.3f (valid at >= %.1f), cells under the gap: %d of %d; freezes %d; NaN totals %d; tied totals %d" % [
		j1, j9, gap_all, _MIN_JUDGMENT_GAP, low_cells, cells.size(), int(pooled["freeze"]), int(pooled["nan"]), int(pooled["ties"])])

	if int(pooled["arm1"]) != 18 * n_cases or int(pooled["arm9"]) != 18 * n_cases or cells.size() != 18:
		m.append("arm counts: %d cells, Standing 1 arm %d, Standing 9 arm %d, expected 18 cells and %d cases per arm" % [cells.size(), int(pooled["arm1"]), int(pooled["arm9"]), 18 * n_cases])
	if gap_all < _MIN_JUDGMENT_GAP or is_nan(gap_all):
		m.append("INVALID: the pooled Judgment gap is %.3f, below %.1f: the two arms are not different enough to read M1 to M4" % [gap_all, _MIN_JUDGMENT_GAP])
	if int(pooled["freeze"]) > 0:
		m.append("INVALID: %d cases froze a chooser (D-63 allows none)" % int(pooled["freeze"]))
	if int(pooled["nan"]) > 0:
		m.append("%d NaN totals" % int(pooled["nan"]))
	if not m.is_empty():
		return _result(m)

	print("PROBE P2 cell | M1 first pick differs | M2 order differs | M3 mean worth S9 - S1 | M4 S9 higher among differing | differing | worth ties among differing")
	for c: Dictionary in cells:
		print("PROBE P2 %s | %s" % [str(c["id"]), _metrics_line(c)])
	print("PROBE P2 POOLED | %s" % _metrics_line(pooled))
	var cn_all := float(maxi(1, int(pooled["cases"])))
	var m1 := float(pooled["m1"]) / cn_all
	var m3 := float(pooled["w_diff"]) / cn_all
	var m4 := float(pooled["differ_hi"]) / float(maxi(1, int(pooled["differ"])))
	# Lever check: Standing must reach the rule at all.
	if int(pooled["m1"]) == 0:
		m.append("lever: no first pick differs between Standing 1 and Standing 9 in any case")
	if _full():
		var pass_ok := m1 >= _M1_LO and m1 <= _M1_HI and m3 >= _M3_MIN and m4 >= _M4_MIN and int(pooled["differ"]) > 0
		print("PROBE P2 D-63 pass line: M1 %.1f%% (15 to 60), M3 %+.3f (>= +0.5), M4 %.1f%% (>= 70): %s" % [m1 * 100.0, m3, m4 * 100.0, "PASS" if pass_ok else "FAIL"])
		if not pass_ok:
			m.append("D-63 pass line failed: M1 %.1f%%, M3 %+.3f, M4 %.1f%%. The shipping sense_base is 0.0 (D-67); this pass line is asserted at FULL size only. Lever if it fails again: data.inventory.pick.sense_base, one tunable at a time; worth_weight is the fallback. If M3 or M4 fails while M1 passes, stop and report to sr-game-designer" % [m1 * 100.0, m3, m4 * 100.0])
	else:
		print("PROBE P2 small size: the pass line is NOT asserted (noisy); the pass line is asserted at FULL size (PICKUP_PROBE_FULL=1); shipping sense_base is 0.0 (D-67)")
	return _result(m)


static func _metrics_line(c: Dictionary) -> String:
	var cn := float(maxi(1, int(c["cases"])))
	var differ := int(c["differ"])
	var m4 := "n/a" if differ == 0 else "%.1f%%" % (float(c["differ_hi"]) / float(differ) * 100.0)
	return "%.1f%% | %.1f%% | %+.3f | %s | %d | %d" % [float(c["m1"]) / cn * 100.0, float(c["m2"]) / cn * 100.0,
		float(c["w_diff"]) / cn, m4, differ, int(c["differ_worth_tie"])]


# ---------------------------------------------------------------------------
# P3 real freeze rate: real won fights, real roll, real config
# ---------------------------------------------------------------------------

## Runs on the setup env before the engage (as PickupFlowTests._prepare, which it calls). It sets one emotional
## state on every Echo through EmotionService, the service `debug.emotion.set` uses, and gives each fight its own
## realm `run_count` so the finds roll and the chooser draw (both keyed on it) differ between fights.
static func _p3_prepare(env: Dictionary, cfg: ConfigService, finds: Array, arm: Dictionary, index: int) -> void:
	PickupFlowTests._prepare(env, cfg, finds, false, -1)
	var fc: FlowContext = env["flow_ctx"]
	RealmService.get_active(fc)["run_count"] = index
	var sanctum: Dictionary = fc.save_data["sanctum"]
	var roster: Array = sanctum["roster"]
	for e_v in roster:
		var e: Dictionary = e_v
		EmotionService.set_morale_current(e, int(arm["morale"]), fc.logger, 0)
		EmotionService.set_fear_current(e, int(arm["fear"]), fc.logger, 0)
		EmotionService.set_fear_base(e, 0, fc.logger, 0)


## A won fight with the party's emotional state set from the first dispatch. A real fight cannot be driven with
## a hollow, fraying or strained party: those Echoes refuse to act (`actor.refuse`, fear above the refusal
## threshold), so the 1-hp enemies of `PickupCharacterizationTests._won_fight` never die. Here the enemies are dead
## before `combat.init`, so the real end-of-round check (`CombatState.check_end_condition`) wins the fight. The ending
## dispatch is the real one: sync of the combat emotion to the roster, the rank, the pickup hook.
## The win drift runs in a LATER dispatch, so the event reads the chooser's fear BEFORE the win relief (fear -5,
## morale +10). That is the real order. The status at the event is the arm status plus what the round did.
## Dispatches are counted, capped at `_P3_MAX_DISPATCHES`; on a failure `diag` says why.
const _P3_MAX_DISPATCHES := 80


static func _p3_fight(tag: String, prepare: Callable) -> Dictionary:
	var trace := { "dispatches": 0 }
	var env: Dictionary = CombatRoundtripIntegrationTests._setup_two_combat_situations(tag)
	if env.is_empty():
		return { "ok": false, "error": "setup failed", "trace": trace }
	prepare.call(env)
	var rt: FlowRuntime = env["runtime"]
	var fc: FlowContext = env["flow_ctx"]
	var sit := str((env["sit_ids"] as Array)[0])
	var stage := FlowStageExploreState._get_current_stage(fc)
	(stage["explore_map"] as Dictionary)["last_situation_id"] = sit
	FlowStageExploreState._write_stage_back(fc, stage)
	rt.dispatch({ "type": "stage.engage_situation", "situation_id": sit })
	var ectx: EncounterContext = fc.encounter_ctx
	var out := { "ok": false, "error": "engage did not enter combat", "rt": rt, "fc": fc, "trace": trace }
	if ectx == null:
		return out
	for a_v in ectx.actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("faction", "")) == "enemy":
			(a_v as Dictionary)["current_hp"] = 0
			(a_v as Dictionary)["is_dead"] = true
	var step := func(action: Dictionary) -> void:
		if ectx.final_snapshot.is_empty() and int(trace["dispatches"]) < _P3_MAX_DISPATCHES:
			rt.dispatch(action)
			trace["dispatches"] = int(trace["dispatches"]) + 1
	step.call({ "type": "combat.init" })
	while ectx.final_snapshot.is_empty() and int(trace["dispatches"]) < _P3_MAX_DISPATCHES:
		step.call({ "type": "combat.confirm_round" })
		var guard := 0
		while guard < 40 and ectx.final_snapshot.is_empty():
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)) or str(cs.get("round_phase", "")) != "in_round":
				break
			step.call({ "type": "combat.next_actor" })
	out["ectx"] = ectx
	out["sit"] = sit
	if not ectx.final_snapshot.is_empty():
		out["ok"] = true
		return out
	var who: Array = []
	for a_v in ectx.actors:
		var a: Dictionary = a_v
		who.append("%s/%s hp=%s dead=%s status=%s pos=%s" % [str(a.get("faction", "")), str(a.get("id", "")), str(a.get("current_hp", "")),
			str(a.get("is_dead", false)), EmotionStatusLean.status_of(a), str(a.get("grid_pos", ""))])
	var logs: Array = fc.logger.get_logs()
	var last: Array = logs.slice(maxi(0, logs.size() - 5)).map(func(e: Variant) -> String: return str((e as Dictionary)["type"]))
	out["error"] = "no final snapshot after %d dispatches" % int(trace["dispatches"])
	out["diag"] = "snapshot=%s round_phase=%s combat_over=%s actors=%s last5logs=%s" % [str(fc.last_snapshot.get("type", "")),
		str(ectx.combat_state.get("round_phase", "")), str(ectx.combat_state.get("combat_over", "")), str(who), str(last)]
	return out


static func _chooser_status(fc: FlowContext, chooser_id: String) -> String:
	for a: Dictionary in SanctumService.get_party_actors_static(fc.save_data):
		if str(a.get("id", "")) == chooser_id:
			return EmotionStatusLean.status_of(a)
	return "?"


static func _t_p3() -> Dictionary:
	var n := _fights()
	if n <= 0:
		print("PROBE P3 skipped: set PICKUP_PROBE_FIGHTS=<N> (N > 0) to play N real won fights.")
		return { "ok": true }
	if OS.get_environment("ECHOES_TEST_SAVE_DIR") == "":
		return _result(["P3 needs its own ECHOES_TEST_SAVE_DIR (for example /tmp/echoes-pickup-probe); it will not use the shared test directory"])
	for arm: Dictionary in _P3_ARMS:
		var st := EmotionService.get_emotional_status(int(arm["morale"]), int(arm["fear"]))
		if st != str(arm["status"]):
			return _result(["P3 arm '%s' reads as status '%s'" % [str(arm["status"]), st]])

	var tally := {}
	for arm: Dictionary in _P3_ARMS:
		tally[str(arm["status"])] = { "planned": 0, "ended": 0, "events": 0, "frozen": 0, "dispatches": 0, "drift": 0, "finds": 0 }
	for i in n:
		var planned_row: Dictionary = tally[str((_P3_ARMS[i % _P3_ARMS.size()] as Dictionary)["status"])]
		planned_row["planned"] += 1
	print("PROBE P3 arms: %d fights, %d arms (one status each, all 5 Echoes set), planned fights per arm: %s" % [
		n, _P3_ARMS.size(), str(_P3_ARMS.map(func(a: Dictionary) -> String: return "%s=%d" % [str(a["status"]), int((tally[str(a["status"])] as Dictionary)["planned"])]))])
	print("PROBE P3 config: real data.inventory finds_chance and finds_cap_by_realm_scale (realm.01 scale 1.0), real roll (no forced count), armed finds %d" % _P3_TYPES.size())

	var ranks := {}
	var counts := {}
	var chooser_status_hist := {}
	var ended_total := 0
	var real_inv := ConfigService.get_inventory_cfg(_real())
	for i in n:
		var arm: Dictionary = _P3_ARMS[i % _P3_ARMS.size()]
		var row: Dictionary = tally[str(arm["status"])]
		var cfg := PickupFlowTests._cfg(4, 2, 100)
		var inv: Dictionary = cfg.get("inv")
		inv["finds_chance"] = (real_inv["finds_chance"] as Dictionary).duplicate(true)
		inv["finds_cap_by_realm_scale"] = (real_inv["finds_cap_by_realm_scale"] as Array).duplicate(true)
		var finds := PickupStateTests._finds(_P3_TYPES)
		var env := _p3_fight("pickup_probe_%d" % i, Callable(PickupProbeTests, "_p3_prepare").bind(cfg, finds, arm, i))
		row["dispatches"] += int((env["trace"] as Dictionary)["dispatches"])
		if not bool(env.get("ok", false)):
			print("PROBE P3 fight %d arm=%s: did not end (%s)" % [i, str(arm["status"]), str(env.get("error", ""))])
			print("PROBE P3 diagnosis: %s" % str(env.get("diag", "none")))
			PickupFlowTests._done(env)
			continue
		ended_total += 1
		row["ended"] += 1
		var fc: FlowContext = env["fc"]
		var rec := PickupFlowTests._record(fc)
		var line := "PROBE P3 fight %d arm=%s dispatches=%d" % [i, str(arm["status"]), int((env["trace"] as Dictionary)["dispatches"])]
		if rec.is_empty():
			line += " event=none"
		else:
			row["events"] += 1
			var cs := _chooser_status(fc, str(rec.get("chooser", "")))
			if cs != str(arm["status"]):
				row["drift"] += 1
			chooser_status_hist[cs] = int(chooser_status_hist.get(cs, 0)) + 1
			var nf := (rec.get("finds", []) as Array).size()
			row["finds"] += nf
			counts[nf] = int(counts.get(nf, 0)) + 1
			ranks[str(rec.get("rank", ""))] = int(ranks.get(str(rec.get("rank", "")), 0)) + 1
			if bool(rec.get("frozen", false)):
				row["frozen"] += 1
			line += " event=%s rank=%s finds=%d chooser_status=%s frozen=%s" % [str(rec.get("case", "")), str(rec.get("rank", "")), nf, cs, str(rec.get("frozen", false))]
		print(line)
		PickupFlowTests._done(env)

	print("PROBE P3 summary | status | fights planned | fights ended | events opened | chooser frozen | dispatches | chooser status differs from arm | finds offered")
	var sum := { "planned": 0, "ended": 0, "events": 0, "frozen": 0, "dispatches": 0, "drift": 0, "finds": 0 }
	for arm: Dictionary in _P3_ARMS:
		var r: Dictionary = tally[str(arm["status"])]
		print("PROBE P3 %-10s | %d | %d | %d | %d | %d | %d | %d" % [str(arm["status"]), int(r["planned"]), int(r["ended"]), int(r["events"]),
			int(r["frozen"]), int(r["dispatches"]), int(r["drift"]), int(r["finds"])])
		for k: String in sum:
			sum[k] += r[k]
	print("PROBE P3 %-10s | %d | %d | %d | %d | %d | %d | %d" % ["TOTAL", int(sum["planned"]), int(sum["ended"]), int(sum["events"]),
		int(sum["frozen"]), int(sum["dispatches"]), int(sum["drift"]), int(sum["finds"])])
	print("PROBE P3 event ranks %s; finds per event %s; chooser status at the event %s" % [str(ranks), str(counts), str(chooser_status_hist)])
	if ended_total == 0:
		return _result(["no fight ended: the probe measured nothing"])
	return { "ok": true }


static func _real() -> ConfigService:
	var c := ConfigService.new()
	c.load_balance()
	return c
