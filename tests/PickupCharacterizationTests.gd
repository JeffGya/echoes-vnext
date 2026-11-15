# res://tests/PickupCharacterizationTests.gd
# V2-ITEM-001b step C0: what the code does TODAY, before the pickup event is built. Production code is not touched.
# Each test records current behaviour, known defects included. A defect is labelled
# `# KNOWN DEFECT (<story> will change this):` and the step that fixes it changes the pinned value on purpose.
# What later steps must not move: the `_state_ends` numbers (C2), a won fight with no finds (C9).
# Floats are pinned to 1e-9; hashes are the first 16 hex characters of the sha256 of the sorted-key JSON.

class_name PickupCharacterizationTests
extends RefCounted

const StagePartyStanceScript := preload("res://core/movement/StagePartyStance.gd")
const _EPS := 1e-9

# status -> [morale, fear] that EmotionService.get_emotional_status maps to that status.
const _STATUS_POINT := {
	"hollow": [50, 85], "fraying": [50, 75], "strained": [50, 65], "pressed": [50, 55], "burdened": [50, 45],
	"hesitant": [30, 20], "uncertain": [37, 20], "grounded": [45, 20], "whole": [60, 20], "radiant": [80, 5],
}
# status -> [lean, afraid at composure 0, 0.5, 1, bold at composure 0, 0.5, 1]. Exponent 2.5, dampen scale 0.4.
const _STATE_ENDS := {
	"hollow": [-1.0, 1.0, 0.8, 0.6, 0.0, 0.0, 0.0],
	"fraying": [-0.95, 0.87964818961901, 0.70371855169521, 0.52778891377141, 0.0, 0.0, 0.0],
	"strained": [-0.9, 0.76843347142092, 0.61474677713673, 0.46106008285255, 0.0, 0.0, 0.0],
	"pressed": [-0.75, 0.48713928962875, 0.389711431703, 0.29228357377725, 0.0, 0.0, 0.0],
	"burdened": [-0.55, 0.22434000423464, 0.17947200338772, 0.13460400254079, 0.0, 0.0, 0.0],
	"hesitant": [-0.25, 0.03125, 0.025, 0.01875, 0.0, 0.0, 0.0],
	"uncertain": [-0.1, 0.00316227766017, 0.00252982212813, 0.0018973665961, 0.0, 0.0, 0.0],
	"grounded": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	"whole": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	"radiant": [0.7, 0.0, 0.0, 0.0, 0.7, 0.56, 0.42],
}


# [morale, fear, fear_base, status]: the status reads the larger of fear and fear_base. The burdened row 50/40/45 has both above 0
# (a sum would give hollow). The last three keep a low fear_base that must not raise afraid. Values come from _STATE_ENDS[status].
const _FEAR_BASE_CASES := [
	[50, 0, 85, "hollow"], [50, 0, 65, "strained"], [50, 0, 55, "pressed"], [30, 0, 45, "burdened"],
	[50, 40, 45, "burdened"], [80, 0, 15, "radiant"], [60, 0, 30, "whole"], [45, 0, 40, "grounded"],
]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_char/state_ends_table_for_ten_statuses", Callable(PickupCharacterizationTests, "_t_state_ends_table"))
	runner.register_test("pickup_char/state_ends_empty_table_is_zero", Callable(PickupCharacterizationTests, "_t_state_ends_empty"))
	runner.register_test("pickup_char/read_echo_standing_1_5_9", Callable(PickupCharacterizationTests, "_t_read_echo"))
	runner.register_test("pickup_char/seam_find_order_refusals_and_duplicates", Callable(PickupCharacterizationTests, "_t_seam_order_and_refusals"))
	runner.register_test("pickup_char/seam_has_no_cap", Callable(PickupCharacterizationTests, "_t_seam_no_cap"))
	runner.register_test("pickup_char/real_won_fight_order", Callable(PickupCharacterizationTests, "_t_won_fight_order"))
	runner.register_test("pickup_char/discard_mark_cleared_at_path_end", Callable(PickupCharacterizationTests, "_t_clear_path_end"))
	runner.register_test("pickup_char/discard_mark_cleared_at_early_leave", Callable(PickupCharacterizationTests, "_t_clear_early_leave"))
	runner.register_test("pickup_char/discard_mark_cleared_at_defeat", Callable(PickupCharacterizationTests, "_t_clear_defeat"))
	runner.register_test("pickup_char/pending_result_consumed_by_a_non_resolve_snapshot", Callable(PickupCharacterizationTests, "_t_pending_consumed"))
	runner.register_test("pickup_char/win_with_no_finds_snapshot_and_save_are_pinned", Callable(PickupCharacterizationTests, "_t_win_no_finds_pinned"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _near(a: float, b: float) -> bool:
	return absf(a - b) < _EPS


static func _hash(v: Variant) -> String:
	return JSON.stringify(v, "", true).sha256_text().substr(0, 16)


static func _data() -> Dictionary:
	return MoraleInfluenceTests._data()


static func _pending_outcome(rt: FlowRuntime) -> String:
	return str(PendingResultService.read(rt.get_save_data()).get("outcome", ""))


# ---------------------------------------------------------------------------
# 1. BehaviorArbiter._state_ends
# ---------------------------------------------------------------------------

static func _t_state_ends_table() -> Dictionary:
	var m: Array = []
	var data := _data()
	var arb := MoraleInfluenceTests._arbiter(data)
	if not _near(float(arb._cfg_get("afraid_curve_exponent")), 2.5) or not _near(BehaviorArbiter.composure_dampen(arb._cfg), 0.4):
		m.append("shipped exponent %s, dampen %s" % [str(arb._cfg_get("afraid_curve_exponent")), str(BehaviorArbiter.composure_dampen(arb._cfg))])
	var lean_table := EmotionStatusLean.table_of((data["combat"] as Dictionary)["movement"] as Dictionary)
	for status in EmotionService.STATUS_LADDER:
		var point: Array = _STATUS_POINT[status]
		var actor := { "morale": point[0], "fear": point[1], "fear_base": 0 }
		if EmotionStatusLean.status_of(actor) != status:
			m.append("fixture for %s reads as %s" % [status, EmotionStatusLean.status_of(actor)])
			continue
		var want: Array = _STATE_ENDS[status]
		if not _near(EmotionStatusLean.lean(status, lean_table), float(want[0])):
			m.append("%s lean %s, expected %s" % [status, str(EmotionStatusLean.lean(status, lean_table)), str(want[0])])
		var composures := [0.0, 0.5, 1.0]
		for i in 3:
			var ends: Array = arb._state_ends(actor, composures[i])
			if ends.size() != 2 or not _near(float(ends[0]), float(want[1 + i])) or not _near(float(ends[1]), float(want[4 + i])):
				m.append("%s composure %s: [afraid, bold] %s, expected [%s, %s]" % [status, str(composures[i]), str(ends), str(want[1 + i]), str(want[4 + i])])
	for c in _FEAR_BASE_CASES:
		var actor := { "morale": c[0], "fear": c[1], "fear_base": c[2] }
		var status: String = c[3]
		if EmotionStatusLean.status_of(actor) != status:
			m.append("fear_base fixture %s reads as %s" % [str(c), EmotionStatusLean.status_of(actor)])
			continue
		var want: Array = _STATE_ENDS[status]
		var composures := [0.0, 0.5, 1.0]
		for i in 3:
			var ends: Array = arb._state_ends(actor, composures[i])
			if ends.size() != 2 or not _near(float(ends[0]), float(want[1 + i])) or not _near(float(ends[1]), float(want[4 + i])):
				m.append("fear_base %s composure %s: %s, expected [%s, %s]" % [str(c), str(composures[i]), str(ends), str(want[1 + i]), str(want[4 + i])])
	return _result(m)


static func _t_state_ends_empty() -> Dictionary:
	var data := _data()
	var arb := BehaviorArbiter.new(MoraleInfluenceTests._actor_cfg(data), {})
	var ends: Array = arb._state_ends({ "morale": 50, "fear": 85, "fear_base": 0 }, 0.5)
	return _result([] if str(ends) == str([0.0, 0.0]) else ["empty table gave %s, expected [0.0, 0.0]" % str(ends)])


# ---------------------------------------------------------------------------
# 2. StagePartyStance.read_echo, through the real roster and the real party reader
# ---------------------------------------------------------------------------

## Echoes 1 to 3 of the party are raised to Standing 1, 5 and 9 through the real rank-up path (FlowFingerprintTests).
static func _t_read_echo() -> Dictionary:
	var m: Array = []
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "pickup_char_stance", "", "", { 1: 5, 2: 9 })
	if env.is_empty():
		return { "ok": false, "error": "encounter setup failed" }
	var save: Dictionary = (env["runtime"] as FlowRuntime).get_save_data()
	var actors: Array = SanctumService.get_party_actors_static(save)
	var ranks: Array = actors.slice(0, 3).map(func(a): return int(a["rank"]))
	if str(ranks) != str([1, 5, 9]):
		m.append("party ranks %s, expected [1, 5, 9]" % str(ranks))
	var party: Array = StagePartyStanceScript.read_party(save, _data())
	if party.size() != 5:
		return { "ok": false, "error": "read_party gave %d Echoes, expected 5" % party.size() }
	var keys: Array = (party[0] as Dictionary).keys()
	keys.sort()
	if str(keys) != str(["best_style", "family", "fear", "fear_base", "id", "lean", "morale", "status", "style_score", "width"]):
		m.append("read_echo keys %s" % str(keys))
	# [id, best_style, family, fear, fear_base, lean, morale, status, style_score, width]
	var want := [
		["echo_0001", "careful", "", 0, 13, -0.25, 32, "hesitant", 1.8, 0.0175],
		["echo_0002", "lateral", "", 0, 17, -0.25, 29, "hesitant", 2.025, 0.1525],
		["echo_0003", "low_exposure", "edge", 0, 15, 0.0, 40, "grounded", 1.8, 0.34],
	]
	for i in 3:
		var e: Dictionary = party[i]
		var w: Array = want[i]
		if str(e["id"]) != w[0] or str(e["best_style"]) != w[1] or str(e["family"]) != w[2] or int(e["fear"]) != w[3] \
				or int(e["fear_base"]) != w[4] or not _near(float(e["lean"]), w[5]) or int(e["morale"]) != w[6] \
				or str(e["status"]) != w[7] or not _near(float(e["style_score"]), w[8]) or not _near(float(e["width"]), w[9]):
			m.append("Standing %d Echo: %s, expected %s" % [ranks[i], JSON.stringify(e, "", true), str(w)])
	return _result(m)


# ---------------------------------------------------------------------------
# 3. The found-items seam today
# ---------------------------------------------------------------------------

static func _t_seam_order_and_refusals() -> Dictionary:
	var m: Array = []
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_NONE, 5, 3)
	var finds: Array = [ItemPacksTests._find("f2", "ph_weapon_a"), "not a find", ItemPacksTests._find("f0", "ph_relic_a"),
		ItemPacksTests._find("x", "nope"), ItemPacksTests._find("f2", "ph_charm_a"), ItemPacksTests._find("f1", "ph_charm_a")]
	var got := ActiveStageService.record_found_items(ctx, "s0", finds, 4)
	var want := { "taken": ["f2", "f0", "f1"], "left": [], "refused": [{ "find_id": "", "reason_key": "bad_entry" },
		{ "find_id": "x", "reason_key": "unknown_kind" }, { "find_id": "f2", "reason_key": "duplicate_find" }] }
	if str(got) != str(want):
		m.append("result %s, expected %s" % [str(got), str(want)])
	if str(ItemPacksTests._ids_of_rows(ctx)) != str(["item:s0:f2", "item:s0:f0", "item:s0:f1"]):
		m.append("row ids %s: rows follow the find order" % str(ItemPacksTests._ids_of_rows(ctx)))
	# Room for two of three: the first two in find order are taken, the rest is left, not lost.
	var ctx2 := ItemPacksTests._ctx(ItemPacksTests._SEED_NONE, 5, 2)
	var got2 := ActiveStageService.record_found_items(ctx2, "s0",
		[ItemPacksTests._find("b", "ph_weapon_a"), ItemPacksTests._find("a", "ph_charm_a"), ItemPacksTests._find("c", "ph_relic_a")], 4)
	if str(got2) != str({ "taken": ["b", "a"], "left": ["c"], "refused": [] }):
		m.append("room for two: %s" % str(got2))
	return _result(m)


static func _t_seam_no_cap() -> Dictionary:
	var m: Array = []
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_NONE, 8, 8)
	var finds: Array = []
	for i in 7:
		finds.append(ItemPacksTests._find("f%d" % i, "ph_weapon_a"))
	var got := ActiveStageService.record_found_items(ctx, "s0", finds, 4)
	# Test configs have no `finds_cap_by_realm_scale` key, which the seam reads as no cap (C6). The cap is tested in pickup_state.
	if (got["taken"] as Array).size() != 7:
		m.append("taken %d of 7 with room for 8" % (got["taken"] as Array).size())
	var keys: Array = got.keys()
	keys.sort()
	if str(keys) != str(["left", "refused", "taken"]):
		m.append("result keys %s, expected left, refused, taken" % str(keys))
	return _result(m)


# ---------------------------------------------------------------------------
# 4. A real won fight
# ---------------------------------------------------------------------------

## A 5-Echo party on realm.01 stage.0 engages a combat situation through the production dispatch. Each enemy is set to 1 hp so
## the win is certain. `last_situation_id` is set the way an Advance sets it. Drives the real round loop and records the
## first dispatch after which the final snapshot exists.
static func _won_fight(tag: String) -> Dictionary:
	var env: Dictionary = CombatRoundtripIntegrationTests._setup_two_combat_situations(tag)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var rt: FlowRuntime = env["runtime"]
	var fc: FlowContext = env["flow_ctx"]
	var sit := str((env["sit_ids"] as Array)[0])
	var stage := FlowStageExploreState._get_current_stage(fc)
	(stage["explore_map"] as Dictionary)["last_situation_id"] = sit
	FlowStageExploreState._write_stage_back(fc, stage)
	rt.dispatch({ "type": "stage.engage_situation", "situation_id": sit })
	var ectx: EncounterContext = fc.encounter_ctx
	if ectx == null:
		return { "ok": false, "error": "engage did not enter combat" }
	for a_v in ectx.actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("faction", "")) == "enemy":
			(a_v as Dictionary)["current_hp"] = 1
	var trace := { "dispatches": 0, "pending_before": false, "flip_action": "", "pending_at_flip": false,
		"state_at_flip": "", "type_at_flip": "" }
	var dispatch_step := func(action: Dictionary) -> void:
		if not ectx.final_snapshot.is_empty():
			return
		trace["pending_before"] = trace["pending_before"] or PendingResultService.has_pending(rt.get_save_data())
		rt.dispatch(action)
		trace["dispatches"] = int(trace["dispatches"]) + 1
		if not ectx.final_snapshot.is_empty():
			trace["flip_action"] = str(action["type"])
			trace["pending_at_flip"] = PendingResultService.has_pending(rt.get_save_data())
			trace["state_at_flip"] = str(rt.flow_machine._current_state_id)
			trace["type_at_flip"] = str(fc.last_snapshot.get("type", ""))
	dispatch_step.call({ "type": "combat.init" })
	for _r in 40:
		dispatch_step.call({ "type": "combat.confirm_round" })
		var guard := 0
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)) or str(cs.get("round_phase", "")) != "in_round":
				break
			dispatch_step.call({ "type": "combat.next_actor" })
		if not ectx.final_snapshot.is_empty():
			break
	return { "ok": ectx.final_snapshot.is_empty() == false, "error": "the fight did not end in a final snapshot", "rt": rt, "fc": fc,
		"ectx": ectx, "sit": sit, "trace": trace }


static func _t_won_fight_order() -> Dictionary:
	var env := _won_fight("pickup_char_order")
	if not bool(env["ok"]):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	var ectx: EncounterContext = env["ectx"]
	var tr: Dictionary = env["trace"]
	if bool(tr["pending_before"]):
		m.append("a pending result existed before the ending dispatch: %s" % str(tr))
	if str(tr["flip_action"]) != "combat.next_actor":
		m.append("the fight ended in '%s', expected combat.next_actor" % str(tr["flip_action"]))
	# One dispatch does all of it: final snapshot, durable result, Resolve type. The machine stays in ENCOUNTER.
	if not bool(tr["pending_at_flip"]) or str(tr["type_at_flip"]) != FlowStateIds.RESOLVE or str(tr["state_at_flip"]) != FlowStateIds.ENCOUNTER:
		m.append("at the ending dispatch: pending %s, snapshot '%s', machine '%s'" % [str(tr["pending_at_flip"]), str(tr["type_at_flip"]), str(tr["state_at_flip"])])
	if JSON.stringify(ectx.final_snapshot) != JSON.stringify(fc.last_snapshot):
		m.append("ectx.final_snapshot is not the published snapshot")
	if _pending_outcome(rt) != "partial":
		m.append("pending outcome '%s', expected partial (objectives remain)" % _pending_outcome(rt))
	var bond_keys: Array = fc.bond_outcome.keys()
	bond_keys.sort()
	if str(bond_keys) != str(["aftermath", "rivals", "triggers"]):
		m.append("bond_outcome keys %s: the bond block runs in the ending dispatch" % str(bond_keys))
	var stage := FlowStageExploreState._get_current_stage(fc)
	if str(EarningsService.rows_of(stage).map(func(r): return str((r as Dictionary)["id"]))) != str(["enc:%s" % str(env["sit"])]):
		m.append("fight rows %s, expected the one fight row" % str(EarningsService.rows_of(stage)))
	var actions: Dictionary = fc.last_snapshot.get("actions", {})
	var go: Dictionary = actions.get("cta.continue", {})
	if str(actions.keys()) != str(["cta.continue"]) or str(go.get("type", "")) != "flow.go_state" or str(go.get("to", "")) != FlowStateIds.STAGE_EXPLORE:
		m.append("resolve actions %s" % str(actions))
	# The Resolve card's own button leaves through flow.go_state, which runs _apply_victory_return_to_explore.
	var out := rt.dispatch(go)
	if str(rt.flow_machine._current_state_id) != FlowStateIds.STAGE_EXPLORE or str(out.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
		m.append("after flow.go_state: machine '%s', snapshot '%s'" % [str(rt.flow_machine._current_state_id), str(out.get("type", ""))])
	if fc.encounter_ctx != null:
		m.append("encounter_ctx survived the return to the path")
	if not _pending_outcome(rt).is_empty():
		m.append("the pending result survived the return to the path: '%s'" % _pending_outcome(rt))
	return _result(m)


# ---------------------------------------------------------------------------
# 5. The three clear sites of the one-discard mark (stage.discard_used)
# ---------------------------------------------------------------------------

## StageSettlementService.settle (stage cleared, path end).
static func _t_clear_path_end() -> Dictionary:
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 4, 3)
	ItemPacksTests._stage(ctx)["discard_used"] = true
	if not ItemPacksTests._stage(ctx).has("discard_used"):
		return { "ok": false, "error": "test setup: the mark was not set" }
	var paid := ItemPacksTests._settle_path(ctx, 3)
	if paid.is_empty():
		return { "ok": false, "error": "test setup: the settlement paid nothing, so it did not reach the clear" }
	return _result([] if not ItemPacksTests._stage(ctx).has("discard_used") else ["the mark stayed after the path end settlement"])


## VentureController.handle_return_home, escape succeeds (early leave).
static func _t_clear_early_leave() -> Dictionary:
	var env := InventoryPathTests._path_env("pickup_char_leave")
	if not bool(env.get("ok", false)):
		return env
	var rt: FlowRuntime = env["rt"]
	if not InventoryRules.mark_discard_used(rt.flow_ctx) or not InventoryRules.discard_used(rt.flow_ctx):
		return { "ok": false, "error": "test setup: the mark was not set" }
	if not InventoryActionTests._force_leave_all(env):
		return { "ok": false, "error": "test setup failed: no seed rolls all with a successful escape" }
	rt.dispatch({ "type": "stage.return_home" })
	var stage := InventoryActionTests._stage_of(env)
	var m: Array = []
	if str((stage["explore_map"] as Dictionary).get("party_state", "")) != "escaped":
		m.append("the escape did not succeed: party_state '%s'" % str((stage["explore_map"] as Dictionary).get("party_state", "")))
	if stage.has("discard_used"):
		m.append("the mark stayed after the early leave")
	return _result(m)


## ActiveStageService.lose_unsettled_packs (defeat).
static func _t_clear_defeat() -> Dictionary:
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 4, 3)
	ItemPacksTests._stage(ctx)["discard_used"] = true
	if not ItemPacksTests._stage(ctx).has("discard_used"):
		return { "ok": false, "error": "test setup: the mark was not set" }
	ActiveStageService.lose_unsettled_packs(ctx, 3)
	return _result([] if not ItemPacksTests._stage(ctx).has("discard_used") else ["the mark stayed after the defeat"])


# ---------------------------------------------------------------------------
# 6. PendingResultService.capture_or_consume
# ---------------------------------------------------------------------------

static func _t_pending_consumed() -> Dictionary:
	var env := _won_fight("pickup_char_consume")
	if not bool(env["ok"]):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	if _pending_outcome(rt).is_empty():
		return { "ok": false, "error": "no pending result after the won fight" }
	# A second publication of the same Resolve card keeps the result (first write wins).
	var same := PendingResultService.capture_or_consume(fc, fc.last_snapshot, 90)
	if not same.is_empty() or _pending_outcome(rt).is_empty():
		m.append("republishing the resolve card gave '%s'" % same)
	# KNOWN DEFECT (V2-ITEM-001b step C9 will change this): any snapshot that is not flow.resolve consumes the result.
	# A pickup snapshot published between the win and the Resolve card would spend it.
	var other := { "type": "flow.pickup", "meta": { "t": 91 }, "data": {}, "actions": {} }
	var got := PendingResultService.capture_or_consume(fc, other, 91)
	if got != "consumed" or not _pending_outcome(rt).is_empty():
		m.append("a flow.pickup snapshot gave '%s', pending '%s'" % [got, _pending_outcome(rt)])
	return _result(m)


# ---------------------------------------------------------------------------
# 7. A win with no finds source: the final snapshot and the save blocks are pinned (C9 must keep them byte-identical)
# ---------------------------------------------------------------------------

static func _t_win_no_finds_pinned() -> Dictionary:
	var env := _won_fight("pickup_char_win")
	if not bool(env["ok"]):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	var save := rt.get_save_data()
	var snap: Dictionary = fc.last_snapshot
	var stage := FlowStageExploreState._get_current_stage(fc)
	var got := {
		"snapshot_data": _hash(snap["data"]), "snapshot_meta_t": int((snap["meta"] as Dictionary)["t"]),
		"stage": _hash(stage), "inventory": _hash(save["inventory"]), "pending_result": _hash(PendingResultService.read(save)),
	}
	var want := { "snapshot_data": "242608323b62fc1a", "snapshot_meta_t": 63, "stage": "fb98e3b8604d9f01",
		"inventory": "3d73c8662138083f", "pending_result": "5aad8910d61b2cc1" }
	if str(got) != str(want):
		m.append("hashes %s, expected %s" % [str(got), str(want)])
	# The economy block holds wall-clock stamps (`*_unix`), so only its balances are pinned.
	var econ: Dictionary = save["economy"]
	var balances := {}
	for k in ["ase", "ekwan", "relics", "faith", "harmony", "favor"]:
		balances[k] = int(econ.get(k, -1))
	if str(balances) != str({ "ase": 0, "ekwan": 0, "relics": 0, "faith": 0, "harmony": 0, "favor": 0 }):
		m.append("economy balances %s" % str(balances))
	# No pickup field exists on the stage record or the snapshot today. C6 adds them lazily, only when an event opens.
	var stage_keys: Array = stage.keys()
	stage_keys.sort()
	if str(stage_keys) != str(["earnings", "explore_map", "held_fates", "index", "objectives", "seed", "type"]):
		m.append("stage record keys %s" % str(stage_keys))
	if (snap["data"] as Dictionary).has("pickup_result") or stage.has("pickup") or stage.has("swap_used"):
		m.append("a pickup field already exists")
	return _result(m)
