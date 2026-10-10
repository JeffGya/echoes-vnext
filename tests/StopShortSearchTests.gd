# res://tests/StopShortSearchTests.gd
# Prefix-cell search for the stop-short route: MovementOptionService side data,
# StopShortContextService.apply_cell_search, and the flag-off parity of both.
# Every board goes through LiveMovementContextService.prepare_live_movement_context, the production entry.

class_name StopShortSearchTests
extends RefCounted

const LiveMovement = preload("res://core/movement/LiveMovementContextService.gd")

const _TESTS: Array = [
	"window_follows_capacity_and_margin",
	"fear_picks_the_cell_in_hostile_reach",
	"ranking_orders_by_strength_progress_exposure_id",
	"observe_in_range_beats_weaker_guard_further_on",
	"no_legal_prefix_leaves_the_options_alone",
	"unusable_prefixes_are_skipped_with_a_reason",
	"insertion_keeps_cap_and_canonical_order",
	"side_data_does_not_change_the_options",
	"switches_off_build_no_side_data",
	"search_and_screen_agree",
	"cell_independent_gates_skip_the_search",
	"two_runs_are_equal",
	"log_event_carries_the_search",
	"capacity_two_changes_nothing",
	"debug_override_turns_the_search_on_and_off",
]

const _TAG: String = "stop_short_search"
const _GUARD_FEAR: Dictionary = { "fear": 45, "fear_base": 0, "morale": 60 }


static func register(runner: CoreTestRunner) -> void:
	for name: String in _TESTS:
		runner.register_test("%s/%s" % [_TAG, name], Callable(StopShortSearchTests, "_t_%s" % name))


static func _res(errs: Array) -> Dictionary:
	return { "ok": errs.is_empty(), "error": "; ".join(errs) }


static func _eq(errs: Array, label: String, got: Variant, want: Variant) -> void:
	if got != want:
		errs.append("%s: got %s, want %s" % [label, str(got), str(want)])


## Mover at (0,5) with the given Standing, `enemy_cols` hostiles on row 5 (ids enemy.0, enemy.1, ...).
## `opts`: parent, search, margin, max, override, mover (Dictionary merged into the mover).
static func _env(standing: int, enemy_cols: Array, opts: Dictionary = {}) -> Dictionary:
	var mover: Dictionary = BehaviorCharacterizationTests._echo_actor("echo.free", 0, 5)
	mover["standing"] = standing
	mover["rank"] = standing
	mover["stats"] = { "max_hp": 100, "def": 3, "agi": 0 }
	var over: Dictionary = opts.get("mover", _GUARD_FEAR) as Dictionary
	for k: String in over.keys():
		mover[k] = over[k]
	var actors: Array = [mover]
	for i: int in range(enemy_cols.size()):
		var at: Variant = enemy_cols[i]
		var cell: Vector2i = at as Vector2i if at is Vector2i else Vector2i(int(at), 5)
		actors.append(BehaviorCharacterizationTests._enemy_actor("enemy.%d" % i, cell.x, cell.y))
	var ectx := EncounterContext.new()
	ectx.actors = actors
	ectx.resolution_mode = EncounterResolutionModes.COMBAT
	ectx.combat_state = {}
	ectx.purifier_id = ""
	ectx.stop_short_override = str(opts.get("override", ""))
	var flow_ctx := FlowContext.new()
	flow_ctx.encounter_ctx = ectx
	var logger := StructuredLogger.new()
	logger.set_level("debug")
	var bdata: Dictionary = BehaviorCharacterizationTests._real_bdata()
	var block: Dictionary = ((bdata["actor"] as Dictionary)["stop_short"]) as Dictionary
	block["enabled"] = bool(opts.get("parent", true))
	var search: Dictionary = block["cell_search"] as Dictionary
	search["enabled"] = bool(opts.get("search", true))
	search["cost_margin"] = int(opts.get("margin", 1))
	search["max_candidates"] = int(opts.get("max", 4))
	if bool(opts.get("strip", false)):
		block.erase("cell_search")
	var stop_over: Dictionary = opts.get("stop_over", {}) as Dictionary
	for k: String in stop_over.keys():
		block[k] = stop_over[k]
	var board_cfg: Dictionary = {
		"board_cols": 10, "board_rows": 10,
		"walkable": BehaviorCharacterizationTests._full_walkable(10, 10),
	}
	var prepared: Dictionary = LiveMovement.new(flow_ctx, logger).prepare_live_movement_context(
		mover, ectx, ectx.combat_state, board_cfg, bdata, 0)
	var context: Dictionary = {
		"actor": mover, "all_actors": actors, "board_cfg": board_cfg, "t": 0, "round": 0,
		"cfg": { "data": bdata },
		"calling_family": str(opts.get("family", "")), "judgment": float(opts.get("judgment", 0.3)),
	}
	if bool(prepared.get("valid", false)) and bool(prepared.get("selection_enabled", false)):
		context["movement_context"] = prepared["movement_context"]
		context["movement_profile"] = prepared["profile"]
		context["movement_goals"] = prepared["goals"]
		context["movement_options"] = prepared["options"]
		if prepared.has("stop_prefixes"):
			context["movement_stop_prefixes"] = prepared["stop_prefixes"]
	return {
		"mover": mover, "ectx": ectx, "bdata": bdata, "board_cfg": board_cfg, "logger": logger,
		"prepared": prepared, "context": context, "flow_ctx": flow_ctx,
	}


static func _entry(env: Dictionary) -> Dictionary:
	var entries: Dictionary = (env["prepared"] as Dictionary).get("stop_prefixes", {}) as Dictionary
	return entries.values()[0] as Dictionary if not entries.is_empty() else {}


static func _ks(entry: Dictionary, key: String) -> Array:
	var out: Array = []
	for p_v: Variant in entry.get(key, []) as Array:
		out.append(int((p_v as Dictionary)["k"]))
	return out


static func _style(option: Dictionary) -> String:
	return MovementOptionService._style_from_option_id(str(option["option_id"]))


static func _conservative(options: Array) -> Array:
	var out: Array = []
	for o_v: Variant in options:
		if _style(o_v as Dictionary) == "conservative":
			out.append(o_v)
	return out


static func _select(env: Dictionary) -> Dictionary:
	var prepared: Dictionary = env["prepared"] as Dictionary
	var context: Dictionary = env["context"] as Dictionary
	var arbiter := BehaviorArbiter.new(
		(env["bdata"] as Dictionary)["actor"] as Dictionary, prepared.get("movement_cfg", {}) as Dictionary)
	return arbiter.select_movement_intent(
		context, context["movement_context"], context["movement_profile"],
		context["movement_goals"], context["movement_options"])


static func _logs_of(env: Dictionary, type: String) -> Array:
	var out: Array = []
	for e_v: Variant in (env["logger"] as StructuredLogger).get_logs():
		if str((e_v as Dictionary)["type"]) == type:
			out.append((e_v as Dictionary)["data"])
	return out



## Applies the search to the env's context.
static func _apply(env: Dictionary) -> void:
	StopShortContextService.apply_cell_search(env["context"] as Dictionary, env["logger"] as StructuredLogger, 0)


static func _opt_ids(options: Array) -> Array:
	var out: Array = []
	for o_v: Variant in options:
		out.append(str((o_v as Dictionary)["option_id"]))
	return out


static func _t_window_follows_capacity_and_margin() -> Dictionary:
	var errs: Array = []
	_eq(errs, "standing 1 (capacity 2)", _ks(_entry(_env(1, [8])), "prefixes"), [1])
	_eq(errs, "standing 3 (capacity 3)", _ks(_entry(_env(3, [8])), "prefixes"), [1, 2])
	_eq(errs, "standing 6 (capacity 4)", _ks(_entry(_env(6, [8])), "prefixes"), [1, 2, 3])
	_eq(errs, "margin 2 is the old window", _ks(_entry(_env(6, [8], { "margin": 2 })), "prefixes"), [1, 2])
	_eq(errs, "max_candidates 2", _ks(_entry(_env(6, [8], { "max": 2 })), "prefixes"), [1, 2])
	_eq(errs, "window value", int(_entry(_env(6, [8]))["window"]), 3)
	return _res(errs)


static func _t_fear_picks_the_cell_in_hostile_reach() -> Dictionary:
	var errs: Array = []
	var env: Dictionary = _env(6, [8])
	var before: Array = _opt_ids((env["context"] as Dictionary)["movement_options"] as Array)
	_apply(env)
	var options: Array = (env["context"] as Dictionary)["movement_options"] as Array
	var cons: Array = _conservative(options)
	_eq(errs, "one conservative option", cons.size(), 1)
	_eq(errs, "option count unchanged", options.size(), before.size())
	if cons.size() == 1:
		_eq(errs, "stops at the third cell", (cons[0] as Dictionary)["destination"], { "col": 3, "row": 5 })
	var log: Array = _logs_of(env, "movement.stop_short_cell_search")
	_eq(errs, "one log per goal", log.size(), 1)
	if log.size() == 1:
		_eq(errs, "chosen_k", (log[0] as Dictionary)["chosen_k"], 3)
		var results: Array = []
		for row_v: Variant in (log[0] as Dictionary)["tried"] as Array:
			results.append((row_v as Dictionary)["result"])
		_eq(errs, "tried results", results, ["no_benefit", "no_benefit", "legal"])
	return _res(errs)


static func _t_ranking_orders_by_strength_progress_exposure_id() -> Dictionary:
	var errs: Array = []
	var make: Callable = func(k: int, strength: float, progress: float, exposure: float, id: String) -> Dictionary:
		return { "k": k, "strength": strength,
			"option": { "objective_progress": progress, "exposure": exposure, "option_id": id } }
	var rows: Array = [
		make.call(1, 0.5, 0.9, 0.0, "b"),
		make.call(2, 0.8, 0.1, 5.0, "z"),
		make.call(3, 0.8, 0.3, 5.0, "y"),
		make.call(4, 0.8, 0.3, 1.0, "x"),
		make.call(5, 0.8, 0.3, 1.0, "w"),
	]
	_eq(errs, "strength, then progress, then exposure, then id", StopShortContextService._best_legal(rows)["k"], 5)
	var shuffled: Array = [rows[4], rows[2], rows[0], rows[3], rows[1]]
	_eq(errs, "input order does not matter", StopShortContextService._best_legal(shuffled)["k"], 5)
	_eq(errs, "stronger beats longer", StopShortContextService._best_legal([rows[0], rows[1]])["k"], 2)
	_eq(errs, "progress breaks a strength tie", StopShortContextService._best_legal([rows[1], rows[2]])["k"], 3)
	_eq(errs, "exposure breaks a progress tie", StopShortContextService._best_legal([rows[2], rows[3]])["k"], 4)
	_eq(errs, "empty", StopShortContextService._best_legal([]).is_empty(), true)
	return _res(errs)


static func _t_observe_in_range_beats_weaker_guard_further_on() -> Dictionary:
	var errs: Array = []
	# Enemy at column 4: the route is two cells before melee reach, both in observe range.
	var env: Dictionary = _env(6, [4], { "mover": { "fear": 0, "fear_base": 0, "morale": 60 }, "family": "sight", "judgment": 1.0 })
	_apply(env)
	var log: Array = _logs_of(env, "movement.stop_short_cell_search")
	if log.size() != 1:
		return _res(["expected one search log, got %d" % log.size()])
	var results: Array = []
	for row_v: Variant in (log[0] as Dictionary)["tried"] as Array:
		results.append((row_v as Dictionary)["result"])
	_eq(errs, "tried results", results, ["legal", "legal"])
	_eq(errs, "most progress among equal reasons", (log[0] as Dictionary)["chosen_k"], 2)
	var selection: Dictionary = _select(env)
	_eq(errs, "board still valid", bool(selection.get("valid", false)), true)
	_eq(errs, "the stop is an observe", str((selection.get("_stop_short", {}) as Dictionary).get("benefit_id", "")), "observe")
	return _res(errs)


static func _t_no_legal_prefix_leaves_the_options_alone() -> Dictionary:
	var errs: Array = []
	var calm: Dictionary = { "fear": 0, "fear_base": 0, "morale": 60 }
	var on: Dictionary = _env(6, [8], { "mover": calm })
	var off: Dictionary = _env(6, [8], { "mover": calm, "search": false })
	var before: String = JSON.stringify((on["context"] as Dictionary)["movement_options"])
	_apply(on)
	_eq(errs, "options untouched", JSON.stringify((on["context"] as Dictionary)["movement_options"]), before)
	var log: Array = _logs_of(on, "movement.stop_short_cell_search")
	if log.size() == 1:
		_eq(errs, "chosen_k 0", (log[0] as Dictionary)["chosen_k"], 0)
		_eq(errs, "kept the base option", str((log[0] as Dictionary)["option_id"]).contains(".conservative."), true)
	else:
		errs.append("expected one search log, got %d" % log.size())
	var vetoes_on: Array = _select(on).get("_stop_short_vetoes", []) as Array
	var vetoes_off: Array = _select(off).get("_stop_short_vetoes", []) as Array
	_eq(errs, "a veto exists", vetoes_on.is_empty(), false)
	_eq(errs, "vetoes equal the search-off vetoes", JSON.stringify(vetoes_on), JSON.stringify(vetoes_off))
	return _res(errs)


static func _t_unusable_prefixes_are_skipped_with_a_reason() -> Dictionary:
	var errs: Array = []
	var env: Dictionary = _env(6, [8])
	var prepared: Dictionary = env["prepared"] as Dictionary
	var mc: Dictionary = prepared["movement_context"] as Dictionary
	var profile: Dictionary = prepared["profile"] as Dictionary
	var goal: Dictionary = (prepared["goals"] as Array)[0] as Dictionary
	var walk: Dictionary = MovementOptionService._planning_walkable(mc)
	var control: Dictionary = MovementOptionService._build_control(mc, walk)
	var costs: Dictionary = control["edge_costs"] as Dictionary
	var sources: Dictionary = control["edge_sources"] as Dictionary
	var primary: Dictionary = {
		"path": [{ "col": 1, "row": 5 }, { "col": 2, "row": 5 }, { "col": 3, "row": 5 }, { "col": 4, "row": 5 }],
		"cohesion": 0.25,
	}
	var fill: Callable = func(g: Dictionary, p: Dictionary, others: Array) -> Dictionary:
		var data: Dictionary = { "cost_margin": 1, "max_candidates": 4 }
		MovementOptionService._fill_stop_search(data, mc, profile, g, walk, costs, sources, p, others)
		return data
	# A prefix with the same destination and path as another style is not offered again.
	var plain: Dictionary = fill.call(goal, primary, [])
	_eq(errs, "no other options: all three offered", _ks(plain, "prefixes"), [1, 2, 3])
	_eq(errs, "primary cohesion is carried", float(plain["primary_cohesion"]), 0.25)
	var twin: Dictionary = ((plain["prefixes"] as Array)[1] as Dictionary)["option"] as Dictionary
	var as_safe: Dictionary = MovementOptionService._with_style(twin, goal, "safe")
	var dup: Dictionary = fill.call(goal, primary, [as_safe])
	_eq(errs, "duplicate skipped", _ks(dup, "skipped"), [2])
	_eq(errs, "duplicate reason", str(((dup["skipped"] as Array)[0] as Dictionary)["reason"]), "duplicate_mechanics")
	_eq(errs, "others still offered", _ks(dup, "prefixes"), [1, 3])
	# The base conservative option itself is not a duplicate.
	var base: Dictionary = fill.call(goal, primary, [twin])
	_eq(errs, "conservative twin is not skipped", _ks(base, "prefixes"), [1, 2, 3])
	# A stop cell inside the goal region.
	var region_goal: Dictionary = goal.duplicate(true)
	(region_goal["destination_region"] as Array).append({ "col": 2, "row": 5 })
	var inside: Dictionary = fill.call(region_goal, primary, [])
	_eq(errs, "region skipped", _ks(inside, "skipped"), [2])
	_eq(errs, "region reason", str(((inside["skipped"] as Array)[0] as Dictionary)["reason"]), "in_goal_region")
	# A first step that does not approach the region.
	var sidestep: Dictionary = { "path": [{ "col": 0, "row": 4 }, { "col": 1, "row": 4 }, { "col": 2, "row": 4 }, { "col": 3, "row": 4 }], "cohesion": 0.0 }
	var side: Dictionary = fill.call(goal, sidestep, [])
	_eq(errs, "no-progress skipped", _ks(side, "skipped"), [1])
	_eq(errs, "no-progress reason", str(((side["skipped"] as Array)[0] as Dictionary)["reason"]), "no_progress")
	# Skip reasons reach the log in k order.
	var entries: Dictionary = { str(goal["goal_id"]): {
		"primary_cohesion": 0.0, "window": 3, "prefixes": plain["prefixes"], "skipped": side["skipped"] } }
	var ctx: Dictionary = (env["context"] as Dictionary).duplicate()
	ctx["movement_stop_prefixes"] = entries
	StopShortContextService.apply_cell_search(ctx, env["logger"] as StructuredLogger, 0)
	var log: Array = _logs_of(env, "movement.stop_short_cell_search")
	var order: Array = []
	for row_v: Variant in ((log[0] as Dictionary)["tried"] as Array):
		order.append(int((row_v as Dictionary)["k"]))
	_eq(errs, "tried in k order", order, [1, 1, 2, 3])
	return _res(errs)


static func _t_insertion_keeps_cap_and_canonical_order() -> Dictionary:
	var errs: Array = []
	var make: Callable = func(goal: String, style: String, cell: String) -> Dictionary:
		return { "goal_id": "goal.%s" % goal, "option_id": "option.%s.%s.d%s" % [goal, style, cell] }
	var chosen: Dictionary = make.call("a", "conservative", "2r5")
	var list: Array = [
		make.call("a", "direct", "4r4"), make.call("a", "retreating", "0r5"),
		make.call("b", "direct", "5r5"), make.call("b", "safe", "5r4"),
	]
	var out: Array = StopShortContextService._with_conservative(list, "goal.a", chosen)
	_eq(errs, "inserted between direct and retreating", _opt_ids(out), [
		"option.a.direct.d4r4", "option.a.conservative.d2r5", "option.a.retreating.d0r5",
		"option.b.direct.d5r5", "option.b.safe.d5r4"])
	var last: Array = StopShortContextService._with_conservative(
		[make.call("a", "direct", "4r4"), make.call("b", "direct", "5r5")], "goal.a", chosen)
	_eq(errs, "goal block end when nothing ranks after", _opt_ids(last)[1], "option.a.conservative.d2r5")
	var replaced: Array = StopShortContextService._with_conservative(
		[make.call("a", "direct", "4r4"), make.call("a", "conservative", "1r5"), make.call("a", "forceful", "9r9")],
		"goal.a", chosen)
	_eq(errs, "replaces the old conservative", _opt_ids(replaced), [
		"option.a.direct.d4r4", "option.a.conservative.d2r5", "option.a.forceful.d9r9"])
	_eq(errs, "producer and consumer style lists are equal",
		MovementOptionService.STYLE_ORDER, BehaviorArbiter._ROUTE_STYLE_ORDER)
	# Live: the board after the swap passes the arbiter's canonical-order and cap checks.
	var env: Dictionary = _env(6, [8])
	_apply(env)
	var options: Array = (env["context"] as Dictionary)["movement_options"] as Array
	_eq(errs, "at most one conservative", _conservative(options).size() <= 1, true)
	_eq(errs, "within the style cap", options.size() <= MovementOptionService.STYLE_ORDER.size(), true)
	var selection: Dictionary = _select(env)
	_eq(errs, "arbiter accepts the board", bool(selection.get("valid", false)), true)
	return _res(errs)


static func _t_side_data_does_not_change_the_options() -> Dictionary:
	var errs: Array = []
	for standing: int in [1, 3, 6]:
		var env: Dictionary = _env(standing, [8], { "search": false })
		var prepared: Dictionary = env["prepared"] as Dictionary
		var mc: Dictionary = prepared["movement_context"] as Dictionary
		var profile: Dictionary = prepared["profile"] as Dictionary
		for goal_v: Variant in prepared["goals"] as Array:
			var goal: Dictionary = goal_v as Dictionary
			var plain: Dictionary = MovementOptionService.generate_options(mc, profile, goal)
			var data: Dictionary = { "cost_margin": 1, "max_candidates": 4 }
			var with_data: Dictionary = MovementOptionService.generate_options(mc, profile, goal, data)
			_eq(errs, "standing %d result" % standing, JSON.stringify(with_data), JSON.stringify(plain))
			_eq(errs, "standing %d data filled" % standing, data.has("prefixes"), true)
	return _res(errs)


static func _t_switches_off_build_no_side_data() -> Dictionary:
	var errs: Array = []
	var pr1_search_off: String = JSON.stringify(_env(6, [8], { "strip": true })["prepared"])
	var cases: Dictionary = {
		"cell_search off": _env(6, [8], { "search": false }),
		"cell_search block absent": _env(6, [8], { "strip": true }),
		"enemy mover": _env(6, [8], { "mover": { "actor_type": "enemy", "faction": "enemy" } }),
	}
	for label: String in cases.keys():
		var env: Dictionary = cases[label] as Dictionary
		var prepared: Dictionary = env["prepared"] as Dictionary
		_eq(errs, label + ": no side data", prepared.has("stop_prefixes"), false)
		_eq(errs, label + ": no context key", (env["context"] as Dictionary).has("movement_stop_prefixes"), false)
		if label != "enemy mover":
			_eq(errs, label + ": prepared equals the search-off board", JSON.stringify(prepared), pr1_search_off)
		var before: String = JSON.stringify((env["context"] as Dictionary).get("movement_options", []))
		_apply(env)
		_eq(errs, label + ": apply is a no-op", JSON.stringify((env["context"] as Dictionary).get("movement_options", [])), before)
		_eq(errs, label + ": no search log", _logs_of(env, "movement.stop_short_cell_search").size(), 0)
	var parent_off: Dictionary = _env(6, [8], { "parent": false })
	_eq(errs, "parent off: no side data", (parent_off["prepared"] as Dictionary).has("stop_prefixes"), false)
	_eq(errs, "parent off equals the search-off board",
		JSON.stringify(parent_off["prepared"]), JSON.stringify(_env(6, [8], { "parent": false, "strip": true })["prepared"]))
	var on: Dictionary = _env(6, [8])
	_eq(errs, "control: both on gives side data", (on["prepared"] as Dictionary).has("stop_prefixes"), true)
	_eq(errs, "control: options list is the PR1 list",
		JSON.stringify((on["prepared"] as Dictionary)["options"]), JSON.stringify((_env(6, [8], { "strip": true })["prepared"] as Dictionary)["options"]))
	return _res(errs)


static func _t_search_and_screen_agree() -> Dictionary:
	var errs: Array = []
	var moods: Array = [
		{ "label": "fear", "mover": _GUARD_FEAR, "family": "", "judgment": 0.3 },
		{ "label": "sight", "mover": { "fear": 0, "fear_base": 0, "morale": 60 }, "family": "sight", "judgment": 0.8 },
		{ "label": "anchor", "mover": { "fear": 0, "fear_base": 0, "morale": 60 }, "family": "anchor", "judgment": 0.8 },
	]
	var chosen_seen: int = 0
	for standing: int in [1, 3, 6]:
		for enemy_col: int in [9, 8, 7, 6, 5, 4]:
			for mood_v: Variant in moods:
				var mood: Dictionary = mood_v as Dictionary
				var env: Dictionary = _env(standing, [enemy_col], mood)
				var label: String = "standing %d enemy %d %s" % [standing, enemy_col, str(mood["label"])]
				if not bool((env["prepared"] as Dictionary).get("selection_enabled", false)):
					continue
				_apply(env)
				var log: Array = _logs_of(env, "movement.stop_short_cell_search")
				var selection: Dictionary = _select(env)
				if not bool(selection.get("valid", false)):
					errs.append(label + ": board invalid: " + str(selection.get("reason", "")))
					continue
				for g_v: Variant in log:
					var g: Dictionary = g_v as Dictionary
					if int(g["chosen_k"]) == 0:
						continue
					chosen_seen += 1
					for veto_v: Variant in selection.get("_stop_short_vetoes", []) as Array:
						_eq(errs, label + ": chosen option not vetoed", str((veto_v as Dictionary)["option_id"]) == str(g["option_id"]), false)
	_eq(errs, "the sweep chose at least one prefix", chosen_seen > 0, true)
	var entry: Dictionary = { "primary_cohesion": 0.7 }
	_eq(errs, "cohesion_full from side data",
		StopShortContextService._cohesion_full("g", [], { "movement_stop_prefixes": { "g": entry } }), 0.7)
	var opts: Array = [
		{ "goal_id": "g", "option_id": "option.g.direct.d1r1", "path": [{}, {}], "cohesion": 0.4 },
		{ "goal_id": "g", "option_id": "option.g.cohesive.d1r1", "path": [{}, {}, {}], "cohesion": 0.9 },
	]
	_eq(errs, "cohesion_full guess when no side data", StopShortContextService._cohesion_full("g", opts, {}), 0.9)
	return _res(errs)


static func _t_cell_independent_gates_skip_the_search() -> Dictionary:
	var errs: Array = []
	var cases: Dictionary = {
		"urgency_critical": { "stop_over": { "urgency_ceiling": 0.5 } },
		"purpose_excluded": { "stop_over": { "excluded_purposes": ["engage"] } },
		"streak": { "mover": { "fear": 45, "fear_base": 0, "morale": 60, StopShortContextService.STREAK_KEY: true } },
	}
	for reason: String in cases.keys():
		var env: Dictionary = _env(6, [8], cases[reason] as Dictionary)
		_eq(errs, reason + ": no prefixes built", (env["prepared"] as Dictionary).has("stop_prefixes"), false)
		_apply(env)
		_eq(errs, reason + ": no search log", _logs_of(env, "movement.stop_short_cell_search").size(), 0)
		var vetoes: Array = _select(env).get("_stop_short_vetoes", []) as Array
		_eq(errs, reason + ": veto kept", vetoes.is_empty() or str((vetoes[0] as Dictionary)["reason"]) == reason, true)
		_eq(errs, reason + ": a veto exists", vetoes.is_empty(), false)
	return _res(errs)


static func _t_two_runs_are_equal() -> Dictionary:
	var errs: Array = []
	var digests: Array = []
	for _run: int in range(2):
		var env: Dictionary = _env(6, [8, 9])
		_apply(env)
		var selection: Dictionary = _select(env)
		digests.append(JSON.stringify([
			(env["context"] as Dictionary)["movement_options"],
			(env["logger"] as StructuredLogger).get_logs(),
			selection.get("_stop_short", {}), selection.get("_stop_short_vetoes", []),
		]).sha256_text())
	_eq(errs, "same digest", digests[0], digests[1])
	return _res(errs)


static func _t_log_event_carries_the_search() -> Dictionary:
	var errs: Array = []
	var env: Dictionary = _env(6, [8])
	_apply(env)
	var log: Array = _logs_of(env, "movement.stop_short_cell_search")
	if log.size() != 1:
		return _res(["expected one search log, got %d" % log.size()])
	var data: Dictionary = log[0] as Dictionary
	var keys: Array = data.keys()
	keys.sort()
	_eq(errs, "field set", keys, ["actor_id", "chosen_k", "goal_id", "option_id", "tried", "window"])
	_eq(errs, "actor_id", data["actor_id"], "echo.free")
	_eq(errs, "window", int(data["window"]), 3)
	_eq(errs, "chosen option is in the list", str(data["option_id"]) in _opt_ids(
		(env["context"] as Dictionary)["movement_options"] as Array), true)
	var row: Dictionary = (data["tried"] as Array)[0] as Dictionary
	var row_keys: Array = row.keys()
	row_keys.sort()
	_eq(errs, "tried row fields", row_keys, ["destination", "k", "result"])
	var calm: Dictionary = _env(6, [8], { "mover": { "fear": 0, "fear_base": 0, "morale": 60 } })
	_apply(calm)
	_eq(errs, "no cause gives no_cause", str((((_logs_of(calm, "movement.stop_short_cell_search")[0] as Dictionary)["tried"] as Array)[0] as Dictionary)["result"]), "no_cause")
	return _res(errs)


static func _t_capacity_two_changes_nothing() -> Dictionary:
	var errs: Array = []
	var env: Dictionary = _env(1, [8], { "mover": { "fear": 45, "fear_base": 0, "morale": 60 } })
	_eq(errs, "capacity", int((env["prepared"]["profile"] as Dictionary)["capacity"]), 2)
	var before: String = JSON.stringify((env["context"] as Dictionary)["movement_options"])
	_apply(env)
	_eq(errs, "options equal the base options", JSON.stringify((env["context"] as Dictionary)["movement_options"]), before)
	return _res(errs)


static func _t_debug_override_turns_the_search_on_and_off() -> Dictionary:
	var errs: Array = []
	var forced_on: Dictionary = _env(6, [8], { "parent": false, "override": "on" })
	_eq(errs, "override on beats balance off", (forced_on["prepared"] as Dictionary).has("stop_prefixes"), true)
	var forced_off: Dictionary = _env(6, [8], { "parent": true, "override": "off" })
	_eq(errs, "override off beats balance on", (forced_off["prepared"] as Dictionary).has("stop_prefixes"), false)
	var none: Dictionary = _env(6, [8], { "parent": true, "override": "" })
	_eq(errs, "no override follows balance", (none["prepared"] as Dictionary).has("stop_prefixes"), true)
	return _res(errs)
