# res://tests/PickupPlannerTests.gd
# V2-ITEM-001b step U3: the pure planners PickupEventPlan (intro timeline) and PickupSwapPlan (swap helpers).
# Fixtures are hand-built dictionaries with every key PickupSnapshotBuilder.build emits (see _DATA_KEYS).

class_name PickupPlannerTests
extends RefCounted

const _SIT := "sit_u3"
const _NEW_FILES: Array = [
	"res://ui/screens/combat/PickupEventPlan.gd",
	"res://ui/screens/combat/PickupSwapPlan.gd",
]
const _BANNED_WORDS: Array = ["Node", "Control", "Tween", "randi", "randf", "Time.", "OS.", "dispatch", "FlowContext",
	"RandomNumberGenerator", ".hash(", "hash(", "seed(", "Engine", "load(", "preload", "await", "EmotionService"]
const _CASES: Array = ["C1", "C2", "C3", "C4", "C5", "frozen"]
const _EPS := 0.0001
const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/planner_beats_are_in_order_with_monotonic_times", Callable(PickupPlannerTests, "_t_beats"))
	runner.register_test("pickup_ui/planner_pointer_steps_start_end_and_lap", Callable(PickupPlannerTests, "_t_pointer"))
	runner.register_test("pickup_ui/planner_fade_starts_when_the_chooser_starts_to_walk", Callable(PickupPlannerTests, "_t_fade_t"))
	runner.register_test("pickup_ui/planner_reads_the_pointer_look_from_the_snapshot", Callable(PickupPlannerTests, "_t_look_config"))
	runner.register_test("pickup_ui/planner_is_deterministic_and_follows_the_pointer_key", Callable(PickupPlannerTests, "_t_deterministic"))
	runner.register_test("pickup_ui/planner_walk_follows_pick_order", Callable(PickupPlannerTests, "_t_pick_order"))
	runner.register_test("pickup_ui/planner_items_stay_hidden_until_picked", Callable(PickupPlannerTests, "_t_reveal"))
	runner.register_test("pickup_ui/planner_item_that_does_not_fit_is_held_up_without_a_slot", Callable(PickupPlannerTests, "_t_tried"))
	runner.register_test("pickup_ui/planner_frozen_chooser_takes_nothing_and_loses_all", Callable(PickupPlannerTests, "_t_frozen"))
	runner.register_test("pickup_ui/planner_five_cases_take_and_react_as_the_snapshot_says", Callable(PickupPlannerTests, "_t_cases"))
	runner.register_test("pickup_ui/planner_tempo_follows_standing_and_reason", Callable(PickupPlannerTests, "_t_tempo"))
	runner.register_test("pickup_ui/planner_skip_state_equals_the_last_frame", Callable(PickupPlannerTests, "_t_skip"))
	runner.register_test("pickup_ui/planner_frame_is_total_finite_and_pure", Callable(PickupPlannerTests, "_t_total_and_pure"))
	runner.register_test("pickup_ui/planner_reduced_motion_is_shorter_and_still_valid", Callable(PickupPlannerTests, "_t_reduced"))
	runner.register_test("pickup_ui/swap_legal_targets_from_either_side", Callable(PickupPlannerTests, "_t_swap_targets"))
	runner.register_test("pickup_ui/swap_twin_is_refused", Callable(PickupPlannerTests, "_t_swap_twin"))
	runner.register_test("pickup_ui/swap_preview_shows_the_trade_as_ghosts", Callable(PickupPlannerTests, "_t_swap_preview"))
	runner.register_test("pickup_ui/swap_after_confirm_shows_the_dropped_item", Callable(PickupPlannerTests, "_t_swap_after"))
	runner.register_test("pickup_ui/swap_button_state_per_phase_and_frozen", Callable(PickupPlannerTests, "_t_swap_button"))
	runner.register_test("pickup_ui/swap_dim_map_lights_origin_and_legal_items", Callable(PickupPlannerTests, "_t_swap_dim"))
	runner.register_test("pickup_ui/planner_plans_from_a_post_swap_snapshot", Callable(PickupPlannerTests, "_t_post_swap_plan"))
	runner.register_test("pickup_ui/planner_state_reason_follows_the_status_ladder", Callable(PickupPlannerTests, "_t_ladder"))
	runner.register_test("pickup_ui/planner_pack_counts_unlisted_slots_and_tone_per_frame", Callable(PickupPlannerTests, "_t_unlisted_and_tone"))
	runner.register_test("pickup_ui/planner_constants_match_the_mockup", Callable(PickupPlannerTests, "_t_constants"))
	runner.register_test("pickup_ui/planner_legs_follow_tile_paths_and_the_chooser_ends_where_the_plan_says", Callable(PickupPlannerTests, "_t_legs_follow_tile_paths"))
	runner.register_test("pickup_ui/planner_pulse_ends_before_the_plan_total", Callable(PickupPlannerTests, "_t_pulse_ends_before_total"))
	runner.register_test("pickup_ui/planner_probe_stand_tiles_stay_off_echo_and_find_tiles_env_gated", Callable(PickupPlannerTests, "_t_probe_stand_tiles"))
	runner.register_test("pickup_ui/planner_plans_over_real_snapshots", Callable(PickupPlannerTests, "_t_plan_over_real_snapshots"))
	runner.register_test("pickup_ui/planner_files_pass_the_source_scan", Callable(PickupPlannerTests, "_t_source_scan"))


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

static func _fail(msg: String) -> Dictionary:
	return { "ok": false, "error": msg }


## Builds a flow.pickup snapshot with every key of the builder. `o` overrides the defaults.
## finds: [[find_id, type_id, status, pick_index]]; held: type ids of the pack before the event.
static func _snap(o: Dictionary) -> Dictionary:
	var n: int = o.get("n", 5)
	var chooser: int = o.get("chooser", 2)
	var standing: Array = o.get("standing", [1, 3, 6, 9, 5])
	var row: Array = []
	for i in n:
		row.append({ "id": "e%d" % i, "name": "Echo %d" % i, "standing": int(standing[i % standing.size()]),
			"status": str(o.get("chooser_status", "grounded")) if i == chooser else "grounded", "is_chooser": i == chooser,
			"tile": { "col": i, "row": 4 } })
	var finds: Array = []
	var taken: Array = []
	for f: Array in o.get("finds", []):
		var pick := int(f[3]) if f.size() > 3 else -1
		finds.append({ "find_id": f[0], "type_id": f[1], "name": "Name " + str(f[1]), "kind": "gear", "grade": "common",
			"quantity": 1, "cell": finds.size(), "tile": { "col": 1 + finds.size(), "row": 0 }, "status": f[2],
			"revealed": str(o.get("phase", "idle")) != "intro", "pick_index": pick })
		if str(f[2]) == "taken":
			taken.append([pick, str(f[0])])
	taken.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var slots: Array = []
	var held: Array = o.get("held", [])
	for i in held.size():
		slots.append({ "id": "held_%d" % i, "type_id": held[i], "name": "Name " + str(held[i]), "find_id": "", "kind": "gear",
			"grade": "common", "quantity": 1, "source": "held", "mark_index": 0 })
	for t: Array in taken:
		var type_id := ""
		for f: Dictionary in finds:
			if f["find_id"] == t[1]:
				type_id = str(f["type_id"])
		slots.append({ "id": "item:%s:%s" % [_SIT, t[1]], "type_id": type_id, "name": "Name " + type_id, "find_id": t[1],
			"kind": "gear", "grade": "common", "quantity": 1, "source": "gathered", "mark_index": -1 })
	var order: Array = taken.map(func(t: Array) -> String: return t[1])
	for f: Dictionary in finds:
		if str(f["status"]) == "tried":
			order.append(f["find_id"])
	var offered: bool = o.get("offered", false)
	var targets := {}
	var twins: Array = []
	var origin: String = o.get("origin", "")
	if offered:
		for f: Dictionary in finds:
			if f["status"] in ["left", "tried"]:
				targets[f["find_id"]] = slots.filter(func(s: Dictionary) -> bool: return s["type_id"] != f["type_id"]).map(func(s: Dictionary) -> String: return s["id"])
		for s: Dictionary in slots:
			targets[s["id"]] = finds.filter(func(f: Dictionary) -> bool: return f["status"] in ["left", "tried"] and f["type_id"] != s["type_id"]).map(func(f: Dictionary) -> String: return f["find_id"])
	if origin != "":
		var o_type := ""
		var o_field := false
		for f: Dictionary in finds:
			if f["find_id"] == origin:
				o_type = f["type_id"]
				o_field = true
		for s: Dictionary in slots:
			if s["id"] == origin:
				o_type = s["type_id"]
		if o_field:
			for s: Dictionary in slots:
				if s["type_id"] == o_type:
					twins.append(s["id"])
		else:
			for f: Dictionary in finds:
				if f["status"] in ["left", "tried"] and f["type_id"] == o_type:
					twins.append(f["find_id"])
	var data := {
		"phase": o.get("phase", "idle"), "situation_id": _SIT, "run_count": 1, "return_to": "stage_map",
		"chooser": { "id": "e%d" % chooser, "name": "Echo %d" % chooser, "standing": int(standing[chooser % standing.size()]) },
		"row": row, "fallen": [], "order": order,
		"selected": o.get("selected", {}), "reason": o.get("reason", "identity"), "case": o.get("case", "C1"),
		"frozen": o.get("frozen", false), "reaction": o.get("reaction", "none"), "finds": finds,
		"pack": { "slots": slots, "free": 0, "capacity": o.get("capacity", 4), "carried": o.get("carried", slots.size()), "tone": o.get("tone", "plain"),
			"tone_before": o.get("tone_before", o.get("tone", "plain")) },
		"swap_left": 0 if o.get("spent", false) else 1, "destroy_left": 1,
		"swap": { "offered": offered, "reason_key": o.get("reason_key", "" if offered else "has_room"), "spent": o.get("spent", false),
			"origin": origin, "target": o.get("target", ""), "twins": twins, "targets": targets, "dropped": o.get("dropped", {}) },
		"confirm_leave_items": true,
		"board_cols": 6, "board_rows": 5, "terrain": {}, "placement_seed": 0, "encounter_id": "enc_u3", "actors": [],
		"camera_frame": { "floor_zoom": 0.75, "margin_px": 48.0, "tween_seconds": 0.45 },
		"pointer_look": PickupSnapshotBuilder.pointer_look({}),
	}
	var actions := {}
	match str(data["phase"]):
		"intro":
			actions["overlay.skip"] = { "type": "pickup.skip", "slot": "overlay.skip" }
		"idle":
			actions["cta.continue"] = { "type": "pickup.continue", "slot": "cta.continue" }
			if offered:
				actions["cta.swap"] = { "type": "pickup.swap.start", "slot": "cta.swap" }
	return { "type": "flow.pickup", "data": data, "actions": actions, "meta": { "t": 1 } }


## One fixture per case. "frozen" has every find lost.
static func _case(key: String, phase: String = "idle") -> Dictionary:
	match key:
		"C1":
			return _snap({ "case": "C1", "phase": phase, "reaction": "plus", "reason": "identity",
				"finds": [["f0", "t_a", "taken", 0], ["f1", "t_b", "taken", 1], ["f2", "t_c", "taken", 2]] })
		"C2":
			return _snap({ "case": "C2", "phase": phase, "reaction": "none", "reason": "sense", "capacity": 2, "offered": true,
				"finds": [["f0", "t_a", "taken", 0], ["f1", "t_b", "taken", 1], ["f2", "t_c", "tried", -1]] })
		"C3":
			return _snap({ "case": "C3", "phase": phase, "reaction": "plus", "reason": "state", "held": ["t_x"],
				"finds": [["f0", "t_a", "taken", 0], ["f1", "t_b", "taken", 1]] })
		"C4":
			return _snap({ "case": "C4", "phase": phase, "reaction": "none", "reason": "identity", "capacity": 3, "offered": true,
				"held": ["t_x", "t_y"], "finds": [["f0", "t_a", "taken", 0], ["f1", "t_b", "tried", -1], ["f2", "t_c", "left", -1]] })
		"C5":
			return _snap({ "case": "C5", "phase": phase, "reaction": "minus", "reason": "state", "offered": true,
				"chooser_status": "grounded", "held": ["t_x", "t_y", "t_z", "t_w"], "tone": "full",
				"finds": [["f0", "t_x", "tried", -1], ["f1", "t_q", "left", -1]] })
	return _snap({ "case": "frozen", "phase": phase, "frozen": true, "reaction": "none", "reason": "froze", "reason_key": "frozen",
		"finds": [["f0", "t_a", "lost", -1], ["f1", "t_b", "lost", -1], ["f2", "t_c", "lost", -1]] })


static func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k: Variant in a:
			if not (b as Dictionary).has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= _EPS
	return a == b


static func _first_diff(a: Variant, b: Variant, path: String = "") -> String:
	if a is Dictionary and b is Dictionary:
		for k: Variant in a:
			if not (b as Dictionary).has(k):
				return "%s.%s missing" % [path, k]
			var d := _first_diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "":
				return d
		return ""
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return "%s size" % path
		for i in (a as Array).size():
			var d := _first_diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	return "" if _same(a, b) else "%s: %s vs %s" % [path, str(a), str(b)]


static func _finite(v: Variant) -> bool:
	if v is float:
		return not is_nan(float(v)) and not is_inf(float(v))
	if v is Dictionary:
		for k: Variant in v:
			if not _finite(v[k]):
				return false
	elif v is Array:
		for x: Variant in v:
			if not _finite(x):
				return false
	return true


static func _item(plan: Dictionary, fid: String) -> Dictionary:
	for f: Dictionary in plan["finds"]:
		if f["find_id"] == fid:
			return f
	return {}


# ---------------------------------------------------------------------------
# Intro plan
# ---------------------------------------------------------------------------

static func _t_beats() -> Dictionary:
	var names := ["last_enemy_falls", "pointer_runs", "chooser_steps_out"]
	for key: String in _CASES:
		var plan := PickupEventPlan.build(_case(key, "intro"))
		if not bool(plan["valid"]):
			return _fail("%s: plan not valid" % key)
		var beats: Array = plan["beats"]
		for i in names.size():
			if beats[i]["name"] != names[i]:
				return _fail("%s: beat %d is %s, expected %s" % [key, i, beats[i]["name"], names[i]])
		if not ["walks_to_picks", "tries_a_find", "takes_nothing"].has(beats[3]["name"]) or beats[4]["name"] != "reaction" or beats[5]["name"] != "idle":
			return _fail("%s: last beats wrong: %s" % [key, str(beats.slice(3))])
		for i in range(1, beats.size()):
			if float(beats[i]["t"]) < float(beats[i - 1]["t"]):
				return _fail("%s: beat times fall at %d" % [key, i])
		if absf(float(beats[5]["t"]) - float(plan["total"])) > _EPS or float(beats[0]["t"]) != 0.0:
			return _fail("%s: idle beat is not the total" % key)
		var tm: Dictionary = plan["times"]
		if not (float(tm["pointer0"]) < float(tm["pointer_end"]) and float(tm["pointer_end"]) < float(tm["step0"])
				and float(tm["step0"]) < float(tm["step1"]) and float(tm["step1"]) <= float(tm["walk0"])
				and float(tm["walk0"]) <= float(tm["deposit_end"]) and float(tm["deposit_end"]) < float(tm["idle"])):
			return _fail("%s: times are not in order: %s" % [key, str(tm)])
		var leg_t := float(tm["step0"])
		for l: Dictionary in plan["legs"]:
			if float(l["t0"]) < leg_t - _EPS or float(l["t1"]) <= float(l["t0"]):
				return _fail("%s: legs overlap or run backwards" % key)
			leg_t = float(l["t1"])
		if str(PickupEventPlan.frame_at(plan, 0.0)["beat"]) != "last_enemy_falls" or str(PickupEventPlan.frame_at(plan, float(plan["total"]))["beat"]) != "idle":
			return _fail("%s: first and last frame beat names wrong" % key)
	return { "ok": true }


## The racetrack of the mote (D-76): authored knots, monotone s(t), the end on the chooser, the times it moves in the plan.
## The mote fades when the chooser starts to walk: at the first leg's start, else at `times.step0`.
static func _t_fade_t() -> Dictionary:
	var none := PickupEventPlan.build(_snap({ "phase": "intro" }))
	if not (none["legs"] as Array).is_empty() or absf(float(none["pointer"]["fade_t"]) - float(none["times"]["step0"])) > _EPS:
		return _fail("a chooser that stays should fade from step0 (legs %d, fade_t %s)" % [(none["legs"] as Array).size(), none["pointer"]["fade_t"]])
	var normal := PickupEventPlan.build(_snap({ "phase": "intro", "finds": [["f0", "t_a", "taken", 0]] }))
	if (normal["legs"] as Array).is_empty() or absf(float(normal["pointer"]["fade_t"]) - float(normal["legs"][0]["t0"])) > _EPS:
		return _fail("with an out leg the fade should start at the first leg")
	# A find on the only free tile beside the chooser: no out tile, so the first leg is the walk, later than step0.
	var blocked := _snap({ "phase": "intro", "finds": [["f0", "t_a", "taken", 0]] })
	blocked["data"]["finds"][0]["tile"] = { "col": 2, "row": 3 }
	var plan := PickupEventPlan.build(blocked)
	var legs: Array = plan["legs"]
	if not (plan["out_cell"] as Dictionary).is_empty() or legs.is_empty() or str(legs[0]["kind"]) != "walk":
		return _fail("the fixture should have no out tile and a walk leg (out %s, %d legs)" % [plan["out_cell"], legs.size()])
	if float(plan["pointer"]["fade_t"]) <= float(plan["times"]["step0"]) + _EPS or absf(float(plan["pointer"]["fade_t"]) - float(legs[0]["t0"])) > _EPS:
		return _fail("the fade did not wait for the first leg: fade_t %s, step0 %s, leg %s" % [plan["pointer"]["fade_t"], plan["times"]["step0"], legs[0]["t0"]])
	var before := PickupEventPlan.pointer_pose(plan, float(plan["times"]["step0"]) + 0.1)
	if float(before["fade"]) != 1.0 or str(before["phase"]) != "hold":
		return _fail("the pointer fades before the chooser walks: %s" % [before])
	return { "ok": true }


static func _look() -> Dictionary:
	return PickupSnapshotBuilder.pointer_look({})


## Config values reach the plan: a changed `path` value moves the times, a dropped table falls back to the slow-down law,
## and the whole `mote` block and the derived landing length travel in `plan.pointer`.
static func _t_look_config() -> Dictionary:
	var base := PickupEventPlan.build(_snap({ "phase": "intro" }))
	var moved := _snap({ "phase": "intro" })
	moved["data"]["pointer_look"]["path"]["hold"] = 1.5
	moved["data"]["pointer_look"]["path"]["pointer_start"] = 0.8
	var plan := PickupEventPlan.build(moved)
	var d_hold := (float(plan["times"]["step0"]) - float(plan["times"]["pointer_end"])) - (float(base["times"]["step0"]) - float(base["times"]["pointer_end"]))
	if absf(float(plan["times"]["pointer0"]) - 0.8) > _EPS or absf(d_hold - 0.9) > _EPS:
		return _fail("hold or pointer_start from the config does not move the times: %s" % str(plan["times"]))
	var tabled := _snap({ "phase": "intro" })
	tabled["data"]["pointer_look"]["tables"]["5:2"] = [0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.4, 2.6, 2.8]
	if absf(float(PickupEventPlan.build(tabled)["pointer"]["total"]) - 2.8) > _EPS:
		return _fail("a changed table does not set the arrival times")
	var law := _snap({ "phase": "intro" })
	(law["data"]["pointer_look"]["tables"] as Dictionary).erase("5:2")
	var law_plan := PickupEventPlan.build(law)
	var law_ref := PickupEventPlan._pointer_path(5, 2, false, _look_without_table())
	if (law_plan["pointer"]["path"] as Array) != (law_ref["path"] as Array) or absf(float(law_plan["pointer"]["total"]) - 3.79) < 0.01:
		return _fail("a config without the table does not use the slow-down law")
	var paced := _snap({ "phase": "intro" })
	(paced["data"]["pointer_look"]["tables"] as Dictionary).erase("5:2")
	paced["data"]["pointer_look"]["path"]["path_pace"] = 0.3
	if float(PickupEventPlan.build(paced)["pointer"]["total"]) <= float(law_plan["pointer"]["total"]):
		return _fail("path_pace does not change the law times")
	var mote_look := _snap({ "phase": "intro" })
	mote_look["data"]["pointer_look"]["mote"]["wind_up_len"] = 0.2
	mote_look["data"]["pointer_look"]["mote"]["sink_len"] = 0.5
	var mp: Dictionary = PickupEventPlan.build(mote_look)["pointer"]
	if absf(float(mp["land_phase_len"]) - 0.7) > _EPS or float(mp["mote"]["sink_len"]) != 0.5:
		return _fail("the mote block or the landing length does not come from the config")
	return { "ok": true }


static func _look_without_table() -> Dictionary:
	var look := _look()
	(look["tables"] as Dictionary).erase("5:2")
	return look


static func _t_pointer() -> Dictionary:
	var exact := { 5: [2, [0.58, 0.78, 0.96, 1.14, 1.40, 1.58, 1.77, 2.01, 2.31, 2.81, 3.19, 3.79]],
		3: [1, [0.68, 0.96, 1.42, 1.72, 2.06, 2.70, 3.60]] }
	for n: int in exact:
		var plan := PickupEventPlan.build(_snap({ "n": n, "chooser": int(exact[n][0]), "phase": "intro" }))
		var p: Dictionary = plan["pointer"]
		var want: Array = exact[n][1]
		var path: Array = p["path"]
		if path.size() != want.size() or int(p["start_index"]) != n - 1 or int(p["land_index"]) != int(exact[n][0]):
			return _fail("n %d: path header wrong (%d moves, start %s, land %s)" % [n, path.size(), p["start_index"], p["land_index"]])
		for i in want.size():
			if absf(float(path[i]["t1"]) - float(want[i])) > 1e-9:
				return _fail("n %d: move %d arrives at %s, the table has %s" % [n, i, path[i]["t1"], want[i]])
		if absf(float(p["total"]) - float(want[want.size() - 1])) > 1e-9 or absf(float(p["lead"]) - 0.30) > 1e-9:
			return _fail("n %d: total %s or lead %s wrong" % [n, p["total"], p["lead"]])
		var tm: Dictionary = plan["times"]
		var cfg: Dictionary = _look()["path"]
		if absf(float(tm["pointer0"]) - float(cfg["pointer_start"])) > _EPS or absf(float(tm["pointer_end"]) - float(cfg["pointer_start"]) - float(p["total"])) > _EPS \
				or absf(float(tm["step0"]) - float(tm["pointer_end"]) - float(cfg["hold"])) > _EPS:
			return _fail("n %d: times do not follow the path: %s" % [n, str(tm)])
	if absf(float(PickupEventPlan.build(_snap({ "phase": "intro" }))["pointer"]["total"]) - 3.8) > 0.05:
		return _fail("the n 5 total is not about 3.8 s")
	for n: int in range(2, 8):
		for land in n:
			var pp := PickupEventPlan._pointer_path(n, land, false, _look())
			var path: Array = pp["path"]
			var last_t: float = _look()["path"]["pointer_lead"]
			var s_sum := 0.0
			for mv: Dictionary in path:
				if float(mv["t1"]) <= last_t or float(mv["s1"]) <= float(mv["s0"]):
					return _fail("n %d land %d: a move has no positive duration or length" % [n, land])
				last_t = float(mv["t1"])
				s_sum = float(mv["s1"])
			if int(path[path.size() - 1]["to"]) != land:
				return _fail("n %d land %d: the last move does not end on the chooser" % [n, land])
			var end := PickupEventPlan.path_at(n, s_sum)
			if absf(float(end["pos_row"]) - float(land)) > 1e-6 or absf(float(end["side"])) > 1e-6:
				return _fail("n %d land %d: the path ends at %s" % [n, land, str(end)])
			var s_prev := -1.0
			var t := 0.0
			while t <= float(pp["total"]) + 0.3:
				var sv := PickupEventPlan._s_at(pp["knots"], t)
				if sv < s_prev - 1e-9 or not is_finite(sv):
					return _fail("n %d land %d: s(t) is not monotone at %s" % [n, land, t])
				s_prev = sv
				t += 0.005
			if absf(s_prev - s_sum) > 1e-6 or PickupEventPlan._s_at(pp["knots"], float(pp["total"]), true) != 0.0 \
					or PickupEventPlan._s_at(pp["knots"], 0.0, true) != 0.0 or PickupEventPlan._s_at(pp["knots"], 0.2) != 0.0:
				return _fail("n %d land %d: s(t) does not rest at both ends" % [n, land])
			if pp != PickupEventPlan._pointer_path(n, land, false, _look()):
				return _fail("n %d land %d: the path is not repeatable" % [n, land])
	var plan := PickupEventPlan.build(_snap({ "phase": "intro" }))
	var tm: Dictionary = plan["times"]
	var phases: Array = []
	var t := 0.0
	while t < float(plan["total"]):
		var pose := PickupEventPlan.pointer_pose(plan, t)
		if bool(pose["visible"]) != (t >= float(tm["pointer0"]) and t < float(plan["pointer"]["fade_t"]) + float(plan["pointer"]["mote"]["halo_fade_out"])):
			return _fail("the pointer is visible at the wrong time (t %s)" % t)
		if str(pose["phase"]) != "" and (phases.is_empty() or phases[phases.size() - 1] != pose["phase"]):
			phases.append(str(pose["phase"]))
		t += 0.01
	if phases != ["gone", "lead", "glide", "turn", "glide", "turn", "glide", "land", "hold", "fade", "gone"]:
		return _fail("the phases run %s" % [phases])
	var rm := PickupEventPlan.build(_snap({ "phase": "intro" }), { "reduced": true })
	var rp: Dictionary = rm["pointer"]
	if (rp["path"] as Array).size() != 0 or absf(float(rp["total"]) - float(_look()["path"]["pointer_reduced"])) > _EPS \
			or float(PickupEventPlan.pointer_pose(rm, float(rm["times"]["pointer0"]) + 0.1)["pos_row"]) != 2.0:
		return _fail("reduced motion is not one rest on the chooser")
	return { "ok": true }


static func _t_deterministic() -> Dictionary:
	var a := PickupEventPlan.build(_case("C4", "intro"))
	var b := PickupEventPlan.build(_case("C4", "intro"))
	if a != b:
		return _fail("build is not repeatable")
	if PickupEventPlan.hash_of(["a", ["f0"]]) != PickupEventPlan.hash_of(["a", ["f0"]]) \
			or PickupEventPlan.hash_of(["a", ["f0"]]) == PickupEventPlan.hash_of(["b", ["f0"]]) \
			or PickupEventPlan.hash_of(["a", ["f0"]]) == PickupEventPlan.hash_of(["a", ["f1"]]):
		return _fail("hash_of is not stable or ignores a part")
	for i in 20:
		var h := PickupEventPlan.hash_of(["s%d" % i, ["f0", "f1"]])
		if h < 0 or h > 0x7FFFFFFF:
			return _fail("hash_of out of 31 bits: %d" % h)
	return { "ok": true }


static func _t_pick_order() -> Dictionary:
	# f0 was picked second and f1 first: the walk follows pick_index, not the find order.
	var snap := _snap({ "case": "C4", "phase": "intro", "capacity": 4, "held": ["t_x", "t_y"], "reaction": "none", "offered": true,
		"finds": [["f0", "t_a", "taken", 1], ["f1", "t_b", "taken", 0], ["f2", "t_c", "tried", -1], ["f3", "t_d", "left", -1]] })
	var plan := PickupEventPlan.build(snap)
	var ids: Array = (plan["walk"] as Array).map(func(w: Dictionary) -> String: return w["find_id"])
	if ids != ["f1", "f0", "f2"]:
		return _fail("walk order is %s, expected f1, f0, f2" % str(ids))
	var w: Array = plan["walk"]
	for i in range(1, w.size()):
		if float(w[i]["t0"]) < float(w[i - 1]["t1"]) - _EPS:
			return _fail("a walk starts before the last one arrived")
	if int(_item(plan, "f1")["slot"]) != 2 or int(_item(plan, "f0")["slot"]) != 3 or int(_item(plan, "f2")["slot"]) != -1:
		return _fail("slots are %d %d %d, expected 2 3 -1" % [_item(plan, "f1")["slot"], _item(plan, "f0")["slot"], _item(plan, "f2")["slot"]])
	if float(_item(plan, "f1")["fly1"]) > float(_item(plan, "f0")["fly0"]) + _EPS:
		return _fail("the second item flies before the first has landed")
	var pack: Dictionary = plan["pack"]
	if pack["after"] != ["held_0", "held_1", "item:%s:f1" % _SIT, "item:%s:f0" % _SIT] or pack["before"] != ["held_0", "held_1"]:
		return _fail("pack lists wrong: %s" % str(pack))
	return { "ok": true }


static func _t_reveal() -> Dictionary:
	var plan := PickupEventPlan.build(_case("C4", "intro"))
	var dep := float(plan["times"]["deposit_end"])
	var f0 := _item(plan, "f0")
	var before: Dictionary = PickupEventPlan.frame_at(plan, float(f0["reveal"]) - 0.01)["items"]["f0"]
	var after: Dictionary = PickupEventPlan.frame_at(plan, float(f0["reveal"]) + float(f0["reveal_len"]) + 0.01)["items"]["f0"]
	if float(before["rev"]) > 0.001 or before["state"] != "hidden" or float(after["rev"]) < 0.999 or after["state"] == "hidden":
		return _fail("f0 is %s before and %s after its pick" % [str(before), str(after)])
	if absf(float(f0["reveal"]) - float(f0["arrive"])) > _EPS:
		return _fail("a taken find is not revealed when the chooser arrives")
	var f2 := _item(plan, "f2")
	if absf(float(f2["reveal"]) - dep) > _EPS:
		return _fail("a left find is not revealed at the end of the picks")
	var mid: Dictionary = PickupEventPlan.frame_at(plan, dep - 0.01)["items"]["f2"]
	if float(mid["rev"]) > 0.001 or str(mid["state"]) != "hidden":
		return _fail("a left find shows before the picks end")
	for f: Dictionary in plan["finds"]:
		var first: Dictionary = PickupEventPlan.frame_at(plan, 0.0)["items"][f["find_id"]]
		if first["state"] != "hidden" or first["cell"] != f["tile"]:
			return _fail("find %s does not lie hidden on its tile at the start: %s" % [f["find_id"], str(first)])
	return { "ok": true }


static func _t_tried() -> Dictionary:
	for key: String in ["C2", "C4", "C5"]:
		var plan := PickupEventPlan.build(_case(key, "intro"))
		var held := _item(plan, str(plan["pack"]["held_find"]))
		if held.is_empty() or not bool(held["is_try"]) or int(held["slot"]) != -1 or float(held["fly0"]) >= 0.0:
			return _fail("%s: tried find has a slot or a fly time" % key)
		var end := PickupEventPlan.frame_at(plan, float(plan["total"]))
		var it: Dictionary = end["items"][held["find_id"]]
		if not bool(it["held"]) or str(it["state"]) != "lifted":
			return _fail("%s: tried find is not held up at the end" % key)
		var filled := int(end["pack"]["used"])
		var expect := (plan["pack"]["before"] as Array).size() + (plan["finds"] as Array).filter(func(f: Dictionary) -> bool: return f["status"] == "taken").size()
		if filled != expect:
			return _fail("%s: pack shows %d slots used, expected %d" % [key, filled, expect])
		if (end["pack"]["slots"] as Array).size() != int(plan["pack"]["slot_count"]):
			return _fail("%s: slot count changed" % key)
		if float(plan["pack"]["pulse_at"]) < 0.0 or float(plan["pack"]["pulse_at"]) > float(plan["total"]):
			return _fail("%s: no pack pulse for the held-up item" % key)
	return { "ok": true }


## D-39: a frozen chooser walks to nothing. Its only leg is the step out of the row.
static func _t_frozen() -> Dictionary:
	var snap := _case("frozen", "intro")
	var plan := PickupEventPlan.build(snap)
	if not (plan["walk"] as Array).is_empty() or bool(plan["offered"]) or not bool(plan["frozen"]):
		return _fail("a frozen plan walks or offers a swap")
	for l: Dictionary in plan["legs"]:
		if l["kind"] != "out":
			return _fail("a frozen chooser has a %s leg" % l["kind"])
	var end := PickupEventPlan.frame_at(plan, float(plan["total"]))
	for f: Dictionary in plan["finds"]:
		var it: Dictionary = end["items"][f["find_id"]]
		if int(f["slot"]) != -1 or float(it["rev"]) < 0.999 or float(it["dim"]) < 0.999 or str(it["state"]) != "revealed":
			return _fail("find %s is not revealed and left on the field" % f["find_id"])
		if absf(float(f["reveal"]) - float(plan["times"]["deposit_end"])) > _EPS:
			return _fail("find %s is not revealed at the end of the beat" % f["find_id"])
	if int(end["pack"]["used"]) != 0:
		return _fail("a frozen chooser filled the pack")
	for rm in [false, true]:
		var fp := PickupEventPlan.build(snap, { "reduced": rm })
		var wait := float(fp["times"]["deposit_end"]) - float(fp["times"]["walk0"])
		var want := 0.4 if rm else PickupEventPlan.FROZEN_STEP + PickupEventPlan.FROZEN_WAIT
		if absf(wait - want) > _EPS:
			return _fail("the frozen wait is %s s (reduced=%s), expected %s" % [str(wait), str(rm), str(want)])
	if plan["chooser_end_cell"] != (plan["out_cell"] if not (plan["out_cell"] as Dictionary).is_empty() else plan["chooser_cell"]):
		return _fail("a frozen chooser does not end on the out tile")
	if PickupUiText.line("bark.froze.0") == "" or str(plan["bark"]["text"]) != PickupUiText.line("bark.froze.0"):
		return _fail("frozen bark is not the froze bark")
	if str(plan["beats"][3]["name"]) != "takes_nothing":
		return _fail("frozen beat name is %s" % plan["beats"][3]["name"])
	return { "ok": true }


static func _t_cases() -> Dictionary:
	var expect := {
		"C1": { "taken": 3, "tried": false, "emo": "plus", "tone": "plain" },
		"C2": { "taken": 2, "tried": true, "emo": "neutral" },
		"C3": { "taken": 2, "tried": false, "emo": "plus" },
		"C4": { "taken": 1, "tried": true, "emo": "neutral" },
		"C5": { "taken": 0, "tried": true, "emo": "minus" },
	}
	for key: String in expect:
		var plan := PickupEventPlan.build(_case(key, "intro"))
		var e: Dictionary = expect[key]
		if (plan["walk"] as Array).filter(func(w: Dictionary) -> bool: return not w["is_try"]).size() != int(e["taken"]):
			return _fail("%s: wrong number of picks" % key)
		if (str(plan["pack"]["held_find"]) != "") != bool(e["tried"]):
			return _fail("%s: held-up find is wrong" % key)
		if plan["emo"] != e["emo"] or plan["case"] != key:
			return _fail("%s: emo %s" % [key, plan["emo"]])
		if str(plan["bark"]["text"]) == "" or int(plan["bark"]["chars"]) != str(plan["bark"]["text"]).length():
			return _fail("%s: bark text missing" % key)
	var severe := _case("C5", "intro")
	severe["data"]["reaction"] = "none"
	var lean := PickupEventPlan.build(severe)
	if lean["emo"] != "lean":
		return _fail("an afraid chooser with no minus should lean, got %s" % lean["emo"])
	if not PickupEventPlan.build(_case("C2", "intro"))["offered"] or PickupEventPlan.build(_case("C1", "intro"))["offered"]:
		return _fail("offered flag does not follow the snapshot")
	return { "ok": true }


static func _t_tempo() -> Dictionary:
	var low := PickupEventPlan.tempo(1)
	var mid := PickupEventPlan.tempo(5)
	var high := PickupEventPlan.tempo(9)
	if absf(float(low["pre"]) - 0.6) > _EPS or absf(float(mid["pre"]) - 0.35) > _EPS or absf(float(high["pre"]) - 0.1) > _EPS:
		return _fail("tempo pre does not hit the anchors 0.6, 0.35, 0.1")
	if float(low["pace"]) >= float(high["pace"]) or PickupEventPlan.tempo(-3) != low or PickupEventPlan.tempo(40) != high:
		return _fail("pace or clamp is wrong")
	var a := _snap({ "case": "C1", "phase": "intro", "standing": [1, 1, 1, 1, 1], "reaction": "plus", "reason": "identity",
		"finds": [["f0", "t_a", "taken", 0], ["f1", "t_b", "taken", 1]] })
	var b := _snap({ "case": "C1", "phase": "intro", "standing": [9, 9, 9, 9, 9], "reaction": "plus", "reason": "identity",
		"finds": [["f0", "t_a", "taken", 0], ["f1", "t_b", "taken", 1]] })
	var pa := PickupEventPlan.build(a)
	var pb := PickupEventPlan.build(b)
	var gap_a := float(pa["times"]["walk0"]) - float(pa["times"]["step1"])
	var gap_b := float(pb["times"]["walk0"]) - float(pb["times"]["step1"])
	if gap_a <= gap_b:
		return _fail("a Standing 1 chooser does not wait longer before the first step (%s vs %s)" % [gap_a, gap_b])
	var worth := _case("C4", "intro")
	worth["data"]["reason"] = "sense"
	var like := _case("C4", "intro")
	like["data"]["reason"] = "identity"
	if PickupEventPlan.build(worth)["tempo_reason"] != "worth" or PickupEventPlan.build(like)["tempo_reason"] != "likes" \
			or PickupEventPlan.build(worth)["legs"] == PickupEventPlan.build(like)["legs"]:
		return _fail("the reason class does not change the walk")
	var afraid := _case("C4", "intro")
	afraid["data"]["reason"] = "state"
	afraid["data"]["row"][2]["status"] = "strained"
	var bold := _case("C4", "intro")
	bold["data"]["reason"] = "state"
	bold["data"]["row"][2]["status"] = "whole"
	if PickupEventPlan.build(afraid)["tempo_reason"] != "safe" or PickupEventPlan.build(bold)["tempo_reason"] != "bold":
		return _fail("state reason does not split by the chooser status")
	return { "ok": true }


static func _t_skip() -> Dictionary:
	var snaps: Array = []
	for key: String in _CASES:
		snaps.append([key, _case(key, "intro")])
	var safe := _case("C4", "intro")
	safe["data"]["reason"] = "state"
	safe["data"]["row"][2]["status"] = "strained"
	snaps.append(["C4 safe", safe])
	for entry: Array in snaps:
		for rm in [false, true]:
			var key: String = entry[0]
			var snap: Dictionary = entry[1]
			var plan := PickupEventPlan.build(snap, { "reduced": rm })
			var last := PickupEventPlan.frame_at(plan, float(plan["total"]))
			var skip := PickupEventPlan.skip_to_idle(snap, { "reduced": rm })
			var diff := _first_diff(skip, last)
			if diff != "":
				return _fail("%s reduced=%s: skip differs from the last frame at %s" % [key, str(rm), diff])
			var diff2 := _first_diff(last, skip)
			if diff2 != "":
				return _fail("%s reduced=%s: last frame differs from skip at %s" % [key, str(rm), diff2])
			# Expected state derived here from the snapshot statuses only (no PickupEventPlan.build).
			var want := _expected_final(snap)
			if skip["pack"]["slots"] != want["slots"] or int(skip["pack"]["used"]) != int(want["used"]) or str(skip["pack"]["tone"]) != str(want["tone"]):
				return _fail("%s reduced=%s: pack is %s, expected %s" % [key, str(rm), str(skip["pack"]), str(want)])
			for fid: String in want["items"]:
				var w: Dictionary = want["items"][fid]
				var g: Dictionary = skip["items"][fid]
				if g["state"] != w["state"] or bool(g["held"]) != bool(w["held"]) or int(g["slot"]) != int(w["slot"]) or g["cell"] != w["cell"]:
					return _fail("%s reduced=%s: item %s is %s, expected %s" % [key, str(rm), fid, str(g), str(w)])
			var stops: Array = want["stops"]
			if not stops.is_empty() and _cheb(skip["chooser_end"], stops[stops.size() - 1]["tile"]) > 1:
				return _fail("%s reduced=%s: the chooser ends %s, not next to its last find" % [key, str(rm), str(skip["chooser_end"])])
	var plain := PickupEventPlan.skip_to_idle({ "type": "flow.pickup", "data": {}, "actions": {} })
	if plain["phase"] != "idle" or not (plain["echoes"] as Array).is_empty():
		return _fail("skip on an empty snapshot is not the empty idle frame")
	return { "ok": true }


static func _cheb(a: Dictionary, b: Dictionary) -> int:
	return maxi(absi(int(a["col"]) - int(b["col"])), absi(int(a["row"]) - int(b["row"])))


## The final state of a skipped intro from the snapshot alone: pack lists, tone, and each find's state.
static func _expected_final(snap: Dictionary) -> Dictionary:
	var d: Dictionary = snap["data"]
	var finds: Array = d["finds"]
	var taken: Array = finds.filter(func(f: Dictionary) -> bool: return f["status"] == "taken")
	taken.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pick_index"] < b["pick_index"])
	var tried: Array = finds.filter(func(f: Dictionary) -> bool: return f["status"] == "tried")
	var slots: Array = []
	var listed: Array = d["pack"]["slots"]
	var taken_ids: Array = taken.map(func(f: Dictionary) -> String: return f["find_id"])
	for sl: Dictionary in listed:
		if sl["find_id"] == "" or not taken_ids.has(sl["find_id"]):
			slots.append(sl["id"])
	var unlisted := maxi(0, int(d["pack"]["carried"]) - listed.size())
	for u in unlisted:
		slots.append("unlisted_%d" % u)
	var first_new := slots.size()
	for fid: String in taken_ids:
		for sl: Dictionary in listed:
			if sl["find_id"] == fid:
				slots.append(sl["id"])
	var count := maxi(int(d["pack"]["capacity"]), slots.size())
	while slots.size() < count:
		slots.append("")
	var used := slots.filter(func(x: String) -> bool: return x != "").size()
	var items := {}
	for f: Dictionary in finds:
		var fid: String = f["find_id"]
		var it := { "state": "revealed", "held": false, "slot": -1, "cell": f["tile"] }
		if f["status"] == "taken":
			it.merge({ "state": "pack", "slot": first_new + taken_ids.find(fid) }, true)
		elif f["status"] == "tried":
			it.merge({ "state": "lifted", "held": true }, true)
		items[fid] = it
	return { "slots": slots, "used": used, "tone": d["pack"]["tone"], "items": items, "stops": taken + tried }


static func _t_total_and_pure() -> Dictionary:
	for key: String in _CASES:
		var snap := _case(key, "intro")
		var before := snap.duplicate(true)
		var plan := PickupEventPlan.build(snap)
		var total := float(plan["total"])
		for t: float in [-5.0, 0.0, 0.01, 1.0, total * 0.5, total - 0.001, total, total + 50.0, 1e9, NAN, INF, -INF]:
			var fr := PickupEventPlan.frame_at(plan, t)
			if not _finite(fr):
				return _fail("%s: frame at %s has a NaN or INF" % [key, str(t)])
		if PickupEventPlan.frame_at(plan, -5.0) != PickupEventPlan.frame_at(plan, 0.0) \
				or PickupEventPlan.frame_at(plan, 1e9) != PickupEventPlan.frame_at(plan, total) \
				or PickupEventPlan.frame_at(plan, NAN) != PickupEventPlan.frame_at(plan, 0.0):
			return _fail("%s: frames outside 0..total are not clamped" % key)
		var again := PickupEventPlan.frame_at(plan, 1.7)
		PickupEventPlan.skip_to_idle(snap)
		PickupSwapPlan.button_state(snap)
		if snap != before or again != PickupEventPlan.frame_at(plan, 1.7):
			return _fail("%s: the snapshot changed or a frame is not repeatable" % key)
		var fr0 := PickupEventPlan.frame_at(plan, 0.0)
		for k: String in ["t", "phase", "beat", "echoes", "items", "pack", "pointer", "bark", "skip_o", "cont_o", "chooser_end"]:
			if not fr0.has(k):
				return _fail("frame key %s missing" % k)
	var bad := PickupEventPlan.build({ "type": "flow.pickup", "data": { "error": "no_pickup_event" }, "actions": {} })
	if bool(bad["valid"]) or not _finite(PickupEventPlan.frame_at(bad, 3.0)) or PickupEventPlan.frame_at(bad, 3.0) != PickupEventPlan.skip_to_idle({}):
		return _fail("an invalid snapshot does not give the empty frame")
	var nolook := _case("C1", "intro")
	(nolook["data"] as Dictionary).erase("pointer_look")
	var nolook_plan := PickupEventPlan.build(nolook)
	if bool(nolook_plan["valid"]) or PickupEventPlan.frame_at(nolook_plan, 3.0) != PickupEventPlan.skip_to_idle({}):
		return _fail("a snapshot with no pointer_look should give no plan and the empty frame")
	for broken: String in ["path", "mote", "tables"]:
		var half := _case("C1", "intro")
		(half["data"]["pointer_look"] as Dictionary).erase(broken)
		if bool(PickupEventPlan.build(half)["valid"]):
			return _fail("a pointer_look with no %s should give no plan" % broken)
	var nokey := _case("C1", "intro")
	(nokey["data"]["pointer_look"]["mote"] as Dictionary).erase("rise")
	if bool(PickupEventPlan.build(nokey)["valid"]):
		return _fail("a pointer_look with a missing mote key should give no plan")
	for what: String in ["row", "find"]:
		var notile := _case("C1", "intro")
		((notile["data"]["row"] if what == "row" else notile["data"]["finds"])[0] as Dictionary).erase("tile")
		var np := PickupEventPlan.build(notile)
		if bool(np["valid"]) or not _finite(PickupEventPlan.frame_at(np, 2.0)) or PickupEventPlan.skip_to_idle(notile) != PickupEventPlan.frame_at(np, 0.0):
			return _fail("a %s with no tile does not give the invalid plan and the empty frame" % what)
	return { "ok": true }


static func _t_reduced() -> Dictionary:
	for key: String in _CASES:
		var full := PickupEventPlan.build(_case(key, "intro"))
		var rm := PickupEventPlan.build(_case(key, "intro"), { "reduced": true })
		if not bool(rm["valid"]) or float(rm["total"]) >= float(full["total"]):
			return _fail("%s: reduced plan is not shorter (%s vs %s)" % [key, rm["total"], full["total"]])
		if not _finite(PickupEventPlan.frame_at(rm, float(rm["total"]) * 0.5)):
			return _fail("%s: reduced frame not finite" % key)
		if rm["chooser_end_cell"] != full["chooser_end_cell"] or (rm["legs"] as Array).size() > (full["legs"] as Array).size():
			return _fail("%s: reduced motion changes where the chooser ends or adds legs" % key)
		for l: Dictionary in rm["legs"]:
			if float(l["t1"]) - float(l["t0"]) > 0.4 + _EPS:
				return _fail("%s: a reduced leg is longer than 0.4 s" % key)
	return { "ok": true }


# ---------------------------------------------------------------------------
# Swap plan
# ---------------------------------------------------------------------------

static func _t_swap_targets() -> Dictionary:
	var snap := _case("C5")
	if PickupSwapPlan.legal_targets(snap, "f0") != ["held_1", "held_2", "held_3"]:
		return _fail("targets of the twin find f0: %s" % str(PickupSwapPlan.legal_targets(snap, "f0")))
	if PickupSwapPlan.legal_targets(snap, "f1") != ["held_0", "held_1", "held_2", "held_3"]:
		return _fail("targets of f1: %s" % str(PickupSwapPlan.legal_targets(snap, "f1")))
	if PickupSwapPlan.legal_targets(snap, "held_0") != ["f1"] or PickupSwapPlan.legal_targets(snap, "held_2") != ["f0", "f1"]:
		return _fail("targets from the pack side are wrong")
	for id: String in ["nope", ""]:
		if not PickupSwapPlan.legal_targets(snap, id).is_empty():
			return _fail("an unknown id has targets")
	if not PickupSwapPlan.legal_targets(_case("C1"), "f0").is_empty() or not PickupSwapPlan.legal_targets({}, "f0").is_empty():
		return _fail("a snapshot with no swap offered has targets")
	var copy: Array = PickupSwapPlan.legal_targets(snap, "f1")
	copy.append("x")
	if (snap["data"]["swap"]["targets"]["f1"] as Array).size() != 4:
		return _fail("legal_targets returns the snapshot array, not a copy")
	return { "ok": true }


static func _t_swap_twin() -> Dictionary:
	var snap := _snap({ "case": "C5", "offered": true, "held": ["t_x", "t_y", "t_z", "t_w"], "reaction": "minus", "phase": "swap_pick",
		"origin": "f0", "finds": [["f0", "t_x", "tried", -1], ["f1", "t_q", "left", -1]] })
	if snap["data"]["swap"]["twins"] != ["held_0"]:
		return _fail("fixture twins wrong: %s" % str(snap["data"]["swap"]["twins"]))
	if not PickupSwapPlan.is_twin_refusal(snap, "f0", "held_0"):
		return _fail("the twin of the origin is not refused")
	if PickupSwapPlan.is_twin_refusal(snap, "f0", "held_1") or PickupSwapPlan.is_twin_refusal(snap, "f0", "f1"):
		return _fail("a legal partner or a same-side item is refused as a twin")
	# Other origin: the type ids decide (the snapshot lists twins for one origin only).
	if not PickupSwapPlan.is_twin_refusal(snap, "held_0", "f0") or PickupSwapPlan.is_twin_refusal(snap, "held_1", "f0"):
		return _fail("twin check from another origin is wrong")
	if PickupSwapPlan.is_twin_refusal(snap, "", "held_0") or PickupSwapPlan.is_twin_refusal(snap, "f0", "nope"):
		return _fail("an empty or unknown id counts as a twin")
	var pv := PickupSwapPlan.preview(snap, "f0", "held_0")
	if bool(pv["ok"]) or pv["reason"] != "same":
		return _fail("preview of a twin pair: %s" % str(pv))
	return { "ok": true }


static func _swap_pre() -> Dictionary:
	return _snap({ "case": "C4", "phase": "idle", "capacity": 3, "offered": true, "held": ["t_x"], "reaction": "none",
		"finds": [["f0", "t_a", "taken", 0], ["f1", "t_b", "taken", 1], ["f2", "t_c", "left", -1]] })


## Post-swap snapshots in the core order (held pieces, then item rows in record order; the incoming find is last).
static func _swap_post(drop_slot: int) -> Dictionary:
	if drop_slot == 0:
		return _snap({ "case": "C4", "capacity": 3, "held": [], "spent": true,
			"dropped": { "id": "held_0", "type_id": "t_x", "name": "Name t_x", "kind": "gear", "grade": "", "quantity": 1 },
			"finds": [["f0", "t_a", "taken", 0], ["f1", "t_b", "taken", 1], ["f2", "t_c", "taken", 2]] })
	return _snap({ "case": "C4", "capacity": 3, "held": ["t_x"], "spent": true,
		"dropped": { "id": "item:%s:f0" % _SIT, "type_id": "t_a", "name": "Name t_a", "kind": "gear", "grade": "common", "quantity": 1 },
		"finds": [["f0", "t_a", "left", -1], ["f1", "t_b", "taken", 0], ["f2", "t_c", "taken", 1]] })


static func _t_swap_preview() -> Dictionary:
	var snap := _swap_pre()
	var f0_id := "item:%s:f0" % _SIT
	for drop: int in [0, 1]:
		var pack_id := "held_0" if drop == 0 else f0_id
		var pv := PickupSwapPlan.preview(snap, "f2", pack_id)
		if not bool(pv["ok"]) or pv["find_id"] != "f2" or pv["pack_id"] != pack_id or int(pv["from_slot"]) != drop \
				or int(pv["slot"]) != 2 or int(pv["cell"]) != 2:
			return _fail("drop %d: preview ids wrong: %s" % [drop, str(pv)])
		var pa: Array = pv["pack_after"]
		var ids: Array = pa.map(func(e: Dictionary) -> String: return e["id"])
		var post_ids: Array = PickupSwapPlan.after_confirm(_swap_post(drop))["pack_ids"]
		if ids != post_ids:
			return _fail("drop %d: pack_after %s is not the core order %s" % [drop, str(ids), str(post_ids)])
		for i in pa.size():
			if int(pa[i]["slot"]) != i or bool(pa[i]["ghost"]) != (i == pa.size() - 1):
				return _fail("drop %d: slot or ghost flag wrong at %d: %s" % [drop, i, str(pa)])
		if pa[2]["from"] != "field" or int(PickupSwapPlan.after_confirm(_swap_post(drop))["slot"]) != 2:
			return _fail("drop %d: the incoming find is not the last slot" % drop)
		var fa: Array = pv["field_after"]
		if fa.size() != 1 or fa[0]["id"] != pack_id or not bool(fa[0]["ghost"]) or int(fa[0]["cell"]) != 2:
			return _fail("drop %d: the dropped item is not the only ghost on the incoming find's place: %s" % [drop, str(fa)])
		if bool(pv["dropped"]["was_find"]) != (drop == 1) or pv["dropped"]["find_id"] != ("f0" if drop == 1 else "") \
				or not bool(pv["lost_at_end"]) or int(pv["swap_left_after"]) != 0:
			return _fail("drop %d: dropped info wrong: %s" % [drop, str(pv["dropped"])])
		var from_pack := PickupSwapPlan.preview(snap, pack_id, "f2")
		if _first_diff(from_pack, pv) != "":
			return _fail("drop %d: preview from the pack side differs: %s" % [drop, _first_diff(from_pack, pv)])
	for pair: Array in [["f2", "f1"], ["held_0", "held_1"], ["f2", "nope"], ["nope", "f2"]]:
		var r := PickupSwapPlan.preview(snap, pair[0], pair[1])
		if bool(r["ok"]) or r["reason"] != "not_partner":
			return _fail("a bad pair %s is not refused: %s" % [str(pair), str(r)])
	return { "ok": true }


## A plan built from the snapshot after a committed swap (the dropped find is back on the field, the incoming find is taken).
static func _t_post_swap_plan() -> Dictionary:
	for drop: int in [0, 1]:
		var snap := _swap_post(drop)
		snap["data"]["phase"] = "idle"
		var plan := PickupEventPlan.build(snap)
		if not bool(plan["valid"]):
			return _fail("drop %d: post-swap plan is not valid" % drop)
		var ids: Array = (plan["walk"] as Array).map(func(w: Dictionary) -> String: return w["find_id"])
		var want_ids: Array = ["f0", "f1", "f2"] if drop == 0 else ["f1", "f2"]
		if ids != want_ids:
			return _fail("drop %d: walk is %s, expected %s" % [drop, str(ids), str(want_ids)])
		var after: Array = plan["pack"]["after"]
		var core_ids: Array = PickupSwapPlan.after_confirm(snap)["pack_ids"]
		if after != core_ids:
			return _fail("drop %d: plan pack %s differs from the snapshot order %s" % [drop, str(after), str(core_ids)])
		if int(_item(plan, "f2")["slot"]) != after.size() - 1:
			return _fail("drop %d: the incoming find is not in the last slot" % drop)
		if _first_diff(PickupEventPlan.skip_to_idle(snap), PickupEventPlan.frame_at(plan, float(plan["total"]))) != "":
			return _fail("drop %d: skip differs from the last frame" % drop)
	return { "ok": true }


static func _t_swap_after() -> Dictionary:
	var dropped := { "id": "item:%s:f0" % _SIT, "type_id": "t_a", "name": "Name t_a", "kind": "gear", "grade": "common", "quantity": 1 }
	var snap := _snap({ "case": "C4", "phase": "idle", "capacity": 3, "offered": false, "held": ["t_x", "t_y"], "reaction": "none",
		"spent": true, "dropped": dropped, "reason_key": "used",
		"finds": [["f0", "t_a", "left", -1], ["f1", "t_b", "tried", -1], ["f2", "t_c", "taken", 0]] })
	var res := PickupSwapPlan.after_confirm(snap)
	if not bool(res["ok"]) or res["dropped"]["id"] != dropped["id"] or res["dropped"]["name"] != "Name t_a" \
			or not bool(res["dropped"]["was_find"]) or res["dropped"]["find_id"] != "f0":
		return _fail("after_confirm dropped wrong: %s" % str(res))
	if res["in_find_id"] != "f2" or int(res["slot"]) != 2 or int(res["swap_left"]) != 0 or not bool(res["lost_at_end"]):
		return _fail("after_confirm incoming wrong: %s" % str(res))
	if res["pack_ids"] != ["held_0", "held_1", "item:%s:f2" % _SIT]:
		return _fail("after_confirm pack ids wrong")
	# Two taken finds: the first taken in find order (f0, pick 0) is not the incoming one (f1, highest pick_index).
	var two := _snap({ "case": "C4", "capacity": 4, "held": ["t_y"], "spent": true,
		"dropped": { "id": "held_9", "type_id": "t_x", "name": "Name t_x", "kind": "gear", "grade": "", "quantity": 1 },
		"finds": [["f0", "t_a", "taken", 0], ["f1", "t_b", "taken", 1], ["f2", "t_c", "left", -1]] })
	var res3 := PickupSwapPlan.after_confirm(two)
	if res3["in_find_id"] != "f1" or int(res3["slot"]) != 2:
		return _fail("after_confirm picked the wrong incoming find: %s" % str(res3))
	var held_drop := _snap({ "case": "C4", "capacity": 3, "held": ["t_y"], "spent": true,
		"dropped": { "id": "held_9", "type_id": "t_x", "name": "Name t_x", "kind": "gear", "grade": "", "quantity": 1 },
		"finds": [["f2", "t_c", "taken", 0]] })
	var res2 := PickupSwapPlan.after_confirm(held_drop)
	if not bool(res2["ok"]) or bool(res2["dropped"]["was_find"]):
		return _fail("a dropped held piece is marked as a find")
	if bool(PickupSwapPlan.after_confirm(_case("C4"))["ok"]) or bool(PickupSwapPlan.after_confirm({})["ok"]):
		return _fail("after_confirm is ok with no swap done")
	return { "ok": true }


static func _t_swap_button() -> Dictionary:
	var sel_find := { "id": "f2", "side": "find" }
	var offered := _case("C4")
	offered["data"]["selected"] = sel_find
	var st := PickupSwapPlan.button_state(offered)
	if not bool(st["visible"]) or not bool(st["enabled"]) or st["refusal_key"] != "" or st["action"].get("type", "") != "pickup.swap.start":
		return _fail("offered and selectable: %s" % str(st))
	# Every possible partner is a twin: shown, disabled, "same".
	var twin := _snap({ "case": "C5", "offered": true, "held": ["t_x"], "reaction": "minus", "capacity": 1, "selected": { "id": "f0", "side": "find" },
		"finds": [["f0", "t_x", "tried", -1]] })
	var ts := PickupSwapPlan.button_state(twin)
	if not bool(ts["visible"]) or bool(ts["enabled"]) or ts["refusal_key"] != "same":
		return _fail("all twins: %s" % str(ts))
	var unknown := _case("C4")
	unknown["data"]["selected"] = { "id": "f0", "side": "find" }
	var us := PickupSwapPlan.button_state(unknown)
	if not bool(us["visible"]) or bool(us["enabled"]) or us["refusal_key"] != "no_target":
		return _fail("selected id with no target list: %s" % str(us))
	for key: String in ["has_room", "used", "nothing_left", "no_target"]:
		var s := _case("C3")
		s["data"]["selected"] = { "id": "f0", "side": "find" }
		s["data"]["swap"]["reason_key"] = key
		var r := PickupSwapPlan.button_state(s)
		if not bool(r["visible"]) or bool(r["enabled"]) or r["refusal_key"] != key:
			return _fail("not offered with %s: %s" % [key, str(r)])
	var frozen := _case("frozen")
	frozen["data"]["selected"] = { "id": "f0", "side": "find" }
	var fs := PickupSwapPlan.button_state(frozen)
	if bool(fs["visible"]) or bool(fs["enabled"]) or fs["action"] != {}:
		return _fail("a frozen chooser shows a Swap button: %s" % str(fs))
	for phase: String in ["intro", "swap_pick", "swap_preview"]:
		var s := _case("C4")
		s["data"]["selected"] = sel_find
		s["data"]["phase"] = phase
		if bool(PickupSwapPlan.button_state(s)["visible"]):
			return _fail("the Swap button shows in phase %s" % phase)
	var none := _case("C4")
	if bool(PickupSwapPlan.button_state(none)["visible"]) or bool(PickupSwapPlan.button_state({})["visible"]):
		return _fail("the Swap button shows with nothing selected")
	return { "ok": true }


static func _t_swap_dim() -> Dictionary:
	var snap := _snap({ "case": "C5", "phase": "swap_pick", "offered": true, "held": ["t_x", "t_y", "t_z", "t_w"], "reaction": "minus",
		"origin": "f0", "finds": [["f0", "t_x", "tried", -1], ["f1", "t_q", "left", -1]] })
	var dm := PickupSwapPlan.dim_map(snap, "f0")
	var items: Dictionary = dm["items"]
	if dm["origin"] != "f0" or items.size() != 6:
		return _fail("dim map header or size wrong: %s" % str(dm))
	var want := { "f0": "origin", "f1": "other", "held_0": "twin", "held_1": "legal", "held_2": "legal", "held_3": "legal" }
	for id: String in want:
		if items[id]["role"] != want[id]:
			return _fail("%s has role %s, expected %s" % [id, items[id]["role"], want[id]])
	if bool(items["held_1"]["dim"]) or bool(items["f0"]["dim"]) or not bool(items["held_0"]["dim"]) or not bool(items["f1"]["dim"]):
		return _fail("dim flags wrong")
	if not bool(items["held_0"]["tappable"]) or bool(items["f1"]["tappable"]) or not bool(items["held_2"]["tappable"]) or bool(items["f0"]["tappable"]):
		return _fail("tappable flags wrong")
	if _first_diff(PickupSwapPlan.dim_map(snap, ""), dm) != "":
		return _fail("an empty origin does not read swap.origin")
	var from_pack := PickupSwapPlan.dim_map(snap, "held_1")
	if from_pack["items"]["f0"]["role"] != "legal" or from_pack["items"]["f1"]["role"] != "legal" or from_pack["items"]["held_1"]["role"] != "origin":
		return _fail("dim map from the pack side is wrong")
	var empty := PickupSwapPlan.dim_map({}, "")
	if not (empty["items"] as Dictionary).is_empty():
		return _fail("an empty snapshot has dim items")
	return { "ok": true }


static func _t_ladder() -> Dictionary:
	if PickupEventPlan.STATUS_LADDER != EmotionService.STATUS_LADDER:
		return _fail("the planner status ladder differs from EmotionService.STATUS_LADDER")
	var ladder: Array = PickupEventPlan.STATUS_LADDER
	var edge := ladder.find(PickupEventPlan.STATUS_AFRAID_MAX)
	if edge < 0 or edge + 1 >= ladder.size():
		return _fail("STATUS_AFRAID_MAX is not inside the ladder")
	for pair: Array in [[ladder[edge - 1], "safe"], [ladder[edge], "safe"], [ladder[edge + 1], "bold"], ["no_such_status", "bold"]]:
		var snap := _case("C4", "intro")
		snap["data"]["reason"] = "state"
		snap["data"]["row"][2]["status"] = pair[0]
		var got: String = PickupEventPlan.build(snap)["tempo_reason"]
		if got != pair[1]:
			return _fail("state reason at status %s is %s, expected %s" % [str(pair[0]), got, str(pair[1])])
	return { "ok": true }


static func _t_unlisted_and_tone() -> Dictionary:
	# Capacity 4, one listed held piece, two carried entries the snapshot cannot list, one find taken.
	var snap := _snap({ "case": "C3", "phase": "intro", "capacity": 4, "held": ["t_x"], "carried": 4, "tone": "full", "tone_before": "near",
		"reaction": "plus", "finds": [["f0", "t_a", "taken", 0]] })
	var plan := PickupEventPlan.build(snap)
	var pk: Dictionary = plan["pack"]
	if int(pk["unlisted"]) != 2 or pk["before"] != ["held_0", "unlisted_0", "unlisted_1"] or int(pk["slot_count"]) != 4 \
			or pk["tone"] != "full" or pk["tone_before"] != "near":
		return _fail("pack plan wrong: %s" % str(pk))
	var f0 := _item(plan, "f0")
	if int(f0["slot"]) != 3:
		return _fail("the taken find is in slot %d, expected 3" % int(f0["slot"]))
	var start: Dictionary = PickupEventPlan.frame_at(plan, 0.0)["pack"]
	var before: Dictionary = PickupEventPlan.frame_at(plan, float(f0["fly1"]) - 0.01)["pack"]
	var after: Dictionary = PickupEventPlan.frame_at(plan, float(f0["fly1"]) + 0.01)["pack"]
	var end: Dictionary = PickupEventPlan.frame_at(plan, float(plan["total"]))["pack"]
	if int(start["used"]) != 3 or start["tone"] != "near" or before["tone"] != "near" or int(before["used"]) != 3:
		return _fail("pack before the last item lands: %s" % str(before))
	if int(after["used"]) != 4 or after["tone"] != "full" or end["slots"] != ["held_0", "unlisted_0", "unlisted_1", "item:%s:f0" % _SIT]:
		return _fail("pack after the last item lands: %s, end %s" % [str(after), str(end)])
	var plain := PickupEventPlan.build(_case("C1", "intro"))
	if int(plain["pack"]["unlisted"]) != 0 or PickupEventPlan.frame_at(plain, 0.0)["pack"]["tone"] != "plain":
		return _fail("a pack with nothing unlisted should start plain")
	if _first_diff(PickupEventPlan.skip_to_idle(snap), PickupEventPlan.frame_at(plan, float(plan["total"]))) != "":
		return _fail("skip differs from the last frame with unlisted slots")
	return { "ok": true }


## Literals copied from pickup-event-playable.html; the line of each is in the comment.
static func _t_constants() -> Dictionary:
	var map: Dictionary = (load("res://ui/screens/combat/PickupEventPlan.gd") as GDScript).get_script_constant_map()
	var table: Array = [
		["STEP_LEN", 0.45], ["STEP_LEN_REDUCED", 0.15],  # lines 670, 671
		["REVEAL_LEN", 0.25], ["REVEAL_LEN_REDUCED", 0.15],  # line 774
		["BARK_AFTER_LAST", 0.15], ["IDLE_AFTER_BARK", 0.3], ["IDLE_AFTER_DEPOSIT", 0.45],  # lines 778, 780
		["WALK_CAP", 3.4], ["FLY_LEN", 0.34], ["TYPE_CPS", 24.0],  # line 619
		["DIST_SCALE_MIN", 0.6], ["DIST_SCALE_MAX", 1.35],  # line 688
		["WORTH_DWELL", 0.45], ["SAFE_PRE_EXTRA", 0.25],  # lines 716, 679
		["FROZEN_STEP", 0.35], ["FROZEN_WAIT", 1.35],  # lines 757 to 760
		["TRY_LIFT_EXTRA", 0.1],  # line 748
		["PACK_SLOTS_DEFAULT", 4],  # line 312
		["REF_TILES_FIRST", 3.0], ["REF_TILES_NEXT", 2.0],  # provisional feel values: 90 and 60 px at 30 px a tile (D-75)
	]
	for row: Array in table:
		if not map.has(row[0]) or absf(float(map[row[0]]) - float(row[1])) > 1e-9:
			return _fail("constant %s is %s, the mockup has %s" % [row[0], str(map.get(row[0])), str(row[1])])
	for gone: String in ["POINTER_SLOWDOWN", "STEP_GAP", "POINTER_DECEL_DIST", "POINTER_ACCEL", "POINTER_MIN_TRAVEL", "POINTER_MIN_CRUISE",
			"POINTER_T_STEP", "POINTER_T_BASE", "POINTER_T_VARY", "POINTER_T_STEPS", "POINTER_SAMPLE_DT",
			"POINTER_START", "POINTER_LEAD", "HOLD", "HOLD_REDUCED", "POINTER_REDUCED", "LAND_PHASE_LEN", "PATH_PACE", "PATH_FIRST_K",
			"PATH_SLOW_N", "PATH_SLOW_K", "PATH_FINAL_K", "PATH_TURN_MIN", "PATH_TURN_MAX", "PATH_ARC_FAST", "PATH_ARC_SPAN", "PATH_TABLES"]:
		if map.has(gone):
			return _fail("old pointer constant %s is still in the planner" % gone)
	# The pixel and body constants of the mockup are gone: the plan runs on tiles and paths.
	for gone: String in ["DESIGN_W", "DESIGN_H", "ROW_SPACING", "ROW_Y", "OUT_STEP", "HEAD", "STAND_OFF", "SLOT_X0", "SLOT_Y", "FIELD_STEP"]:
		if map.has(gone):
			return _fail("design-space constant %s is still in the planner" % gone)
	# RS rows, mockup lines 612 to 618: walk first, walk next, touch, lift, lift ease, hold.
	var rs := {
		"likes": [0.70, 0.60, 0.10, 0.25, "back", 0.20], "worth": [0.60, 0.60, 0.10, 0.40, "smooth", 0.20],
		"safe": [0.95, 0.70, 0.10, 0.20, "smooth", 0.20], "bold": [0.50, 0.40, 0.10, 0.15, "back", 0.20],
		"fit": [0.45, 0.45, 0.0, 0.20, "smooth", 0.12] }
	for k: String in rs:
		var r: Dictionary = PickupEventPlan.RS[k]
		var w: Array = rs[k]
		if absf(float(r["w"][0]) - float(w[0])) > 1e-9 or absf(float(r["w"][1]) - float(w[1])) > 1e-9 or absf(float(r["touch"]) - float(w[2])) > 1e-9 \
				or absf(float(r["lift"]) - float(w[3])) > 1e-9 or r["ease"] != w[4] or absf(float(r["hold"]) - float(w[5])) > 1e-9:
			return _fail("RS row %s differs from the mockup" % k)
	if PickupEventPlan.RS.size() != 5:
		return _fail("RS has a row the mockup does not")
	# Tempo anchors, mockup lines 606 to 610: Standing 1, 5, 9 -> pre, hitch, pace, delay.
	var anchors := { 1: [0.6, 0.12, 0.8, 0.2], 5: [0.35, 0.06, 0.95, 0.1], 9: [0.1, 0.0, 1.0, 0.0] }
	for st: int in anchors:
		var t := PickupEventPlan.tempo(st)
		var a: Array = anchors[st]
		for i in 4:
			if absf(float(t[["pre", "hitch", "pace", "delay"][i]]) - float(a[i])) > 1e-9:
				return _fail("tempo(%d) key %d differs from the mockup" % [st, i])
	if (PickupEventPlan.tempo(5) as Dictionary).size() != 4:
		return _fail("tempo has a body key (lean) the plan does not play")
	return { "ok": true }


# ---------------------------------------------------------------------------
# Tiles and paths
# ---------------------------------------------------------------------------

## Every plan of a snapshot must satisfy: legs chain from the start tile, each step is to a neighbour tile on the
## board, the out tile is free, each stand tile is next to its find tile, the end tile is where the last leg ends.
## Returns "" or the first problem.
static func _check_paths(plan: Dictionary, d: Dictionary) -> String:
	var walkable := StageTerrain.walkable_set(d.get("terrain", {}))
	var cols := int(d["board_cols"])
	var rows := int(d["board_rows"])
	var cur: Dictionary = plan["chooser_cell"]
	var row_tiles: Dictionary = {}
	for e: Dictionary in plan["row"]:
		row_tiles["%d,%d" % [e["cell"]["col"], e["cell"]["row"]]] = true
	if plan["chooser_cell"] != _row_tile(d, plan["chooser_id"]):
		return "chooser_cell is not the chooser's row tile"
	for l: Dictionary in plan["legs"]:
		var cells: Array = l["cells"]
		if cells.size() < 2 or cells[0] != cur:
			return "a %s leg does not start where the last one ended" % l["kind"]
		for i in cells.size():
			var c: Dictionary = cells[i]
			if int(c["col"]) < 0 or int(c["row"]) < 0 or int(c["col"]) >= cols or int(c["row"]) >= rows or not StageTerrain.is_walkable(c, walkable):
				return "leg cell %s is off the board or not walkable" % str(c)
			if i > 0 and _cheb(c, cells[i - 1]) != 1:
				return "leg cells %s and %s are not neighbours" % [str(cells[i - 1]), str(c)]
		cur = cells[cells.size() - 1]
	if plan["chooser_end_cell"] != cur:
		return "chooser_end_cell %s is not the end of the last leg %s" % [str(plan["chooser_end_cell"]), str(cur)]
	var legs: Array = plan["legs"]
	if not legs.is_empty() and legs[0]["kind"] == "out":
		var out: Dictionary = plan["out_cell"]
		var key := "%d,%d" % [out["col"], out["row"]]
		if row_tiles.has(key) or out != (legs[0]["cells"] as Array)[1] or (legs[0]["cells"] as Array).size() != 2:
			return "the out leg is not one step to a tile outside the row"
		for f: Dictionary in plan["finds"]:
			if f["tile"] == out:
				return "the out tile is a find tile"
	elif not (plan["out_cell"] as Dictionary).is_empty():
		return "out_cell is set but the first leg is not out"
	var find_tiles: Array = (plan["finds"] as Array).map(func(f: Dictionary) -> Dictionary: return f["tile"])
	var row_cells: Array = (plan["row"] as Array).map(func(e: Dictionary) -> Dictionary: return e["cell"])
	for w: Dictionary in plan["walk"]:
		var f := _item(plan, w["find_id"])
		if _cheb(w["stand"], f["tile"]) > 1 or w["stand"] == f["tile"]:
			return "stand tile %s is not next to find tile %s" % [str(w["stand"]), str(f["tile"])]
		var free := false
		for dc in range(-1, 2):
			for dr in range(-1, 2):
				var n := { "col": int(f["tile"]["col"]) + dc, "row": int(f["tile"]["row"]) + dr }
				free = free or ((dc != 0 or dr != 0) and int(n["col"]) >= 0 and int(n["row"]) >= 0 and int(n["col"]) < cols
						and int(n["row"]) < rows and StageTerrain.is_walkable(n, walkable) and not row_cells.has(n) and not find_tiles.has(n))
		if free and (row_cells.has(w["stand"]) or find_tiles.has(w["stand"])):
			return "stand tile %s is a row tile or a find tile, but a free neighbour of find tile %s exists" % [str(w["stand"]), str(f["tile"])]
	if not (plan["walk"] as Array).is_empty() and plan["chooser_end_cell"] != (plan["walk"] as Array)[(plan["walk"] as Array).size() - 1]["stand"]:
		return "chooser_end_cell is not the last stand tile"
	return ""


static func _row_tile(d: Dictionary, id: String) -> Dictionary:
	for r: Dictionary in d["row"]:
		if r["id"] == id:
			return r["tile"]
	return {}


static func _t_legs_follow_tile_paths() -> Dictionary:
	for key: String in _CASES:
		for rm in [false, true]:
			var snap := _case(key, "intro")
			var plan := PickupEventPlan.build(snap, { "reduced": rm })
			var bad := _check_paths(plan, snap["data"])
			if bad != "":
				return _fail("%s reduced=%s: %s" % [key, str(rm), bad])
			if PickupEventPlan.build(snap, { "reduced": rm }) != plan:
				return _fail("%s: the plan is not repeatable" % key)
	# Fixture board: Echoes on row 4, finds on row 0, chooser e2 at (2,4). The finds' side is up, so out is (2,3).
	var plan := PickupEventPlan.build(_case("C1", "intro"))
	if plan["out_cell"] != { "col": 2, "row": 3 }:
		return _fail("out tile is %s, expected col 2 row 3 (up, toward the finds, off the row)" % str(plan["out_cell"]))
	var walks: Array = (plan["legs"] as Array).filter(func(l: Dictionary) -> bool: return l["kind"] == "walk")
	# A stop already next to its find has no leg, so there can be fewer legs than stops.
	if walks.is_empty() or (plan["walk"] as Array).size() != 3:
		return _fail("C1 has %d walk legs and %d stops, expected some legs and 3 stops" % [walks.size(), (plan["walk"] as Array).size()])
	# The chooser moves between tiles in a frame in the middle of a leg.
	var mid := (float(walks[0]["t0"]) + float(walks[0]["t1"])) / 2.0
	var chooser: Dictionary = {}
	for e: Dictionary in PickupEventPlan.frame_at(plan, mid)["echoes"]:
		if e["chosen"]:
			chooser = e
	if not bool(chooser["walking"]) or _cheb(chooser["from"], chooser["to"]) != 1 or float(chooser["progress"]) < 0.0 or float(chooser["progress"]) >= 1.0:
		return _fail("no tile step in the middle of a walk leg: %s" % str(chooser))
	# The other Echoes never leave their tiles.
	for e: Dictionary in PickupEventPlan.frame_at(plan, mid)["echoes"]:
		if not e["chosen"] and (e["walking"] or e["cell"] != _row_tile(_case("C1")["data"], e["id"])):
			return _fail("Echo %s left its tile" % e["id"])
	# No free side: a find lies on the tile in front of the chooser, so the chooser stays and the plan still runs.
	var boxed := _case("C1", "intro")
	boxed["data"]["finds"][0]["tile"] = { "col": 2, "row": 3 }
	var stay := PickupEventPlan.build(boxed)
	if not bool(stay["valid"]) or not (stay["out_cell"] as Dictionary).is_empty() or _check_paths(stay, boxed["data"]) != "" \
			or not _finite(PickupEventPlan.frame_at(stay, 3.0)):
		return _fail("a chooser with no free tile in front must stay, with a valid plan: %s" % str(stay.get("out_cell")))
	return { "ok": true }


## Real snapshots: the real fight board, terrain and seeded tiles (seeds 0 and 1 give the two row axes).
static func _t_plan_over_real_snapshots() -> Dictionary:
	var snaps: Array = []
	for kind: String in ["many", "empty"]:
		for seed_text: String in ["0", "1"]:
			var snap := PickupRealBoard.snapshot(kind, "intro", "", seed_text)
			if snap.is_empty():
				return _fail("the fixture fight did not reach the event (%s seed %s)" % [kind, seed_text])
			snaps.append(["%s seed %s" % [kind, seed_text], snap])
	# Same keys the fixture sets for a frozen chooser, on the seed 0 snapshot (no second fight).
	var frozen: Dictionary = (snaps[0][1] as Dictionary).duplicate(true)
	PickupRealBoard._vary(frozen, "frozen")
	snaps.append(["many seed 0 frozen", frozen])
	for entry: Array in snaps:
		var snap: Dictionary = entry[1]
		for rm in [false, true]:
			var plan := PickupEventPlan.build(snap, { "reduced": rm })
			var tag := "%s reduced=%s" % [entry[0], str(rm)]
			if not bool(plan["valid"]):
				return _fail("%s: plan not valid" % tag)
			var bad := _check_paths(plan, snap["data"])
			if bad != "":
				return _fail("%s: %s" % [tag, bad])
			if _first_diff(PickupEventPlan.skip_to_idle(snap, { "reduced": rm }), PickupEventPlan.frame_at(plan, float(plan["total"]))) != "":
				return _fail("%s: skip differs from the last frame" % tag)
			if not _finite(PickupEventPlan.frame_at(plan, float(plan["total"]) * 0.5)):
				return _fail("%s: frame not finite" % tag)
	return { "ok": true }


## Probe, off by default: `PICKUP_PLAN_PROBE_SEEDS=n` plans the real "empty" and "many" boards for seeds 0 to n - 1 and
## counts stops whose stand tile is a row tile or a find tile. A free neighbour must always win, so the count must be 0.
static func _t_probe_stand_tiles() -> Dictionary:
	var count := OS.get_environment("PICKUP_PLAN_PROBE_SEEDS").to_int()
	var stops := 0
	var on_row := 0
	var on_find := 0
	for kind: String in ["empty", "many"]:
		for sd in count:
			var snap := PickupRealBoard.snapshot(kind, "intro", "", str(sd))
			var plan := PickupEventPlan.build(snap)
			if not bool(plan["valid"]):
				return _fail("%s seed %d: plan not valid" % [kind, sd])
			var bad := _check_paths(plan, snap["data"])
			if bad != "":
				return _fail("%s seed %d: %s" % [kind, sd, bad])
			for w: Dictionary in plan["walk"]:
				stops += 1
				on_row += 1 if (plan["row"] as Array).any(func(e: Dictionary) -> bool: return e["cell"] == w["stand"]) else 0
				on_find += 1 if (plan["finds"] as Array).any(func(f: Dictionary) -> bool: return f["tile"] == w["stand"]) else 0
	if count > 0:
		print("PPROBE seeds 0..%d, scenes empty and many: %d stops, stand on a row tile %d, stand on a find tile %d" % [count - 1, stops, on_row, on_find])
	return { "ok": on_row == 0 and on_find == 0, "error": "%d stand tiles on a row tile, %d on a find tile" % [on_row, on_find] }


## The pack pulse of a held-up find must be over at the plan total, also with a short bark (reduced motion, Standing 9).
static func _t_pulse_ends_before_total() -> Dictionary:
	for key: String in ["C2", "C4", "C5"]:
		for rm in [false, true]:
			var snap := _case(key, "intro")
			snap["data"]["row"][2]["standing"] = 9
			snap["data"]["chooser"]["standing"] = 9
			var plan := PickupEventPlan.build(snap, { "reduced": rm })
			if float(plan["total"]) < float(plan["pack"]["pulse_at"]) + PickupEventPlan.PULSE_LEN - _EPS:
				return _fail("%s reduced=%s: the plan ends at %s, before the pulse ends" % [key, str(rm), str(plan["total"])])
			var diff := _first_diff(PickupEventPlan.skip_to_idle(snap, { "reduced": rm }), PickupEventPlan.frame_at(plan, float(plan["total"])))
			if diff != "":
				return _fail("%s reduced=%s: skip differs from the last frame at %s" % [key, str(rm), diff])
	return { "ok": true }


static func _t_source_scan() -> Dictionary:
	var errors: Array = []
	for path: String in _NEW_FILES:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			errors.append("%s unreadable" % path)
		for word: String in _BANNED_WORDS:
			if text.contains(word):
				errors.append("%s contains %s" % [path, word])
	# Key set of a real builder snapshot: PickupSnapshotTests asserts its own `_DATA_KEYS` against real
	# PickupSnapshotBuilder output, so this fixture is compared with that list (no cheap real fixture here).
	var snap_keys := (_case("C1")["data"] as Dictionary).keys()
	snap_keys.sort()
	var want: Array = PickupSnapshotTests._DATA_KEYS.duplicate()
	want.sort()
	if snap_keys != want:
		errors.append("fixture keys differ from the builder keys: %s" % str(snap_keys))
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }
