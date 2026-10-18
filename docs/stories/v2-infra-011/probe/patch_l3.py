import re
N = [0]
def wrap(path, old, label):
    s = open(path).read()
    assert s.count(old) == 1, (path, s.count(old), label, old[:80])
    indent = re.match(r'^(\t*)', old).group(1)
    N[0] += 1
    v = "_q%d" % N[0]
    new = "%svar %s: int = TP.t()\n%sTP.caller = \"%s\"\n%s\n%sTP.add(\"%s\", %s)" % (indent, v, indent, label, old, indent, label, v)
    open(path, 'w').write(s.replace(old, new))
def sub(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, s.count(old), old[:80])
    open(path, 'w').write(s.replace(old, new))

LM = 'core/movement/LiveMovementContextService.gd'
MO = 'core/movement/MovementOptionService.gd'
FP = 'tests/FlowFingerprintTests.gd'
TPDEF = 'const TP = preload("res://tests/TimingProbeAcc.gd")\n'

# --- LiveMovementContextService.prepare_live_movement_context
wrap(LM, '''	var displacement_immune: bool = _movement_displacement_immunity(
		actor, ectx.actors, bdata.get("maturity_expression", {}) as Dictionary)''', 'P.displacement')
wrap(LM, '	var occupancy: Dictionary = _movement_occupancy(ectx.actors)\n	# V2-COMBAT-002 Slice 6E: the mover always', 'P.occupancy') if False else None
s = open(LM).read()
i = s.index('func prepare_live_movement_context(')
j = s.index('func _movement_displacement_immunity(')
body = s[i:j]
for old, label in [
    ('	var occupancy: Dictionary = _movement_occupancy(ectx.actors)', 'P.occupancy'),
    ('	var perceived: Array = _movement_actor_facts(ectx.actors)', 'P.actor_facts'),
    ('	var relationships: Dictionary = _movement_relationships(actor, perceived)', 'P.relationships'),
    ('	var pressure: Dictionary = _movement_pressure_snapshot(actor, ectx, combat_state, bounds, walkable)', 'P.pressure_snapshot'),
    ('	var known_hazards: Array = _live_combat_known_hazards()', 'P.known_hazards'),
    ('	var planning_walkable_ec: Dictionary = _movement_planning_walkable(movement_context)', 'P.planning_walkable'),
    ('	var control_build: Dictionary = MovementOptionServiceScript._build_control(movement_context, planning_walkable_ec)', 'P.build_control'),
    ('	var profile: Dictionary = MovementProfileServiceScript.derive_profile(actor, capacity_cfg, {})', 'P.derive_profile'),
    ('	var goals_result: Dictionary = CombatPressureServiceScript.build_goals(movement_context, pressure_cfg)', 'P.build_goals'),
    ('		options = _movement_live_options(movement_context, profile, goals, t, stop_search)', 'P.live_options'),
]:
    assert body.count(old) == 1, (label, body.count(old))
    N[0] += 1
    v = "_q%d" % N[0]
    indent = re.match(r'^(\t*)', old).group(1)
    body = body.replace(old, "%svar %s: int = TP.t()\n%s\n%sTP.add(\"%s\", %s)" % (indent, v, old, indent, label, v))
old = '''	var movement_context: Dictionary = MovementContextScript.build('''
assert body.count(old) == 1
N[0] += 1
body = body.replace(old, '	var _qctx: int = TP.t()\n' + old)
old = '''		pressure,
		[]
	)
'''
assert body.count(old) == 1
body = body.replace(old, old + '	TP.add("P.context_build", _qctx)\n')
open(LM, 'w').write(s[:i] + body + s[j:])
# header const
sub(LM, 'func prepare_live_movement_context(', TPDEF + '\nfunc prepare_live_movement_context(')

# --- _movement_live_options
wrap(LM, '''		var generated: Dictionary = MovementOptionServiceScript.generate_options(
			movement_context, profile, goal, side_data)''', 'O.generate_options')
wrap(LM, '	_log_perception_narrowing(movement_context, t)\n	return options', 'O.log_perception') if False else None
wrap(LM, '''		for option_value: Variant in generated_options:
			options.append((option_value as Dictionary).duplicate(true))''', 'O.dup_options')

# --- MovementOptionService.generate_options
sub(MO, 'static func generate_options(', TPDEF + '\nstatic func generate_options(')
wrap(MO, '	var context_result: Dictionary = ContextContract.validate(context)', 'G.validate_context')
wrap(MO, '	var profile_result: Dictionary = ProfileContract.validate(profile)', 'G.validate_profile')
wrap(MO, '	var goal_result: Dictionary = GoalContract.validate(goal, context["origin"] as Dictionary)', 'G.validate_goal')
wrap(MO, '	var planning_walkable: Dictionary = _planning_walkable(context)\n	var origin_key: String = _cell_key(origin)', 'G.planning_walkable') if False else None
wrap(MO, '	var control: Dictionary = _build_control(context, planning_walkable)\n	var edge_costs: Dictionary = control["edge_costs"] as Dictionary\n	var edge_sources: Dictionary = control["edge_sources"] as Dictionary\n	var primary_style', 'G.x') if False else None
wrap(MO, '	var control: Dictionary = _build_control(context, planning_walkable)', 'G.build_control')
wrap(MO, '		routes = _candidate_routes(context, goal, planning_walkable, edge_costs)', 'G.candidate_routes')
wrap(MO, '''	if primary_style == "lateral":
		primary = _build_lateral_primary(
			context, profile, goal, planning_walkable, edge_costs, edge_sources, routes
		)
	else:
		primary = _build_primary(
			context,
			profile,
			goal,
			planning_walkable,
			edge_costs,
			edge_sources,
			primary_style,
			routes
		)''', 'G.build_primary')
wrap(MO, '''		var endpoints: Array = _build_endpoint_candidates(
			context,
			profile,
			goal,
			planning_walkable,
			edge_costs,
			edge_sources
		)''', 'G.endpoint_candidates')
wrap(MO, '''		var conservative: Dictionary = _build_conservative(
			context,
			profile,
			goal,
			planning_walkable,
			edge_costs,
			edge_sources,
			primary
		)''', 'G.conservative')
wrap(MO, '''		var forceful: Dictionary = _build_forceful(
			context, profile, goal, planning_walkable, edge_costs, edge_sources
		)''', 'G.forceful')
wrap(MO, '''		var overcommitted: Dictionary = _build_overcommitted(
			context, profile, goal, planning_walkable, edge_costs, edge_sources, routes
		)''', 'G.overcommitted')
wrap(MO, '''			var lateral: Dictionary = _build_lateral_extra(
				context, profile, goal, planning_walkable, edge_costs, edge_sources,
				taken_destinations, routes
			)''', 'G.lateral_extra')
wrap(MO, '	var deduplication: Dictionary = _deduplicate_candidates(validated)', 'G.dedupe')
wrap(MO, '''	if stop_search is Dictionary:
		_fill_stop_search(
			stop_search as Dictionary, context, profile, goal, planning_walkable,
			edge_costs, edge_sources, primary, deduplication["options"] as Array
		)''', 'G.fill_stop_search')

# --- drive + dump
sub(FP, 'static func _drive_and_capture(runtime: FlowRuntime, ectx: EncounterContext, max_rounds: int) -> Dictionary:', TPDEF + '\nstatic func _drive_and_capture(runtime: FlowRuntime, ectx: EncounterContext, max_rounds: int) -> Dictionary:')
sub(FP, '''	var drive: Dictionary = _drive_and_capture(runtime, ectx, max_rounds)
	if not bool(drive.get("combat_over", false)):
		return {
			"ok": false,''', '''	var _tpd: int = TP.t()
	var drive: Dictionary = _drive_and_capture(runtime, ectx, max_rounds)
	TP.add("D.drive_total", _tpd)
	TP.dump("L2")
	if not bool(drive.get("combat_over", false)):
		return {
			"ok": false,''')


PS = 'core/movement/MovementPathService.gd'
sub(PS, 'static func shortest_path(', TPDEF + '\nstatic func shortest_path(')
sub(PS, ''') -> Dictionary:
	var edge_validation: Dictionary = _validate_edge_costs(edge_costs)
	if not bool(edge_validation["valid"]):
		return _path_failure(str(edge_validation["reason"]))
	if not _is_cell(origin):''', ''') -> Dictionary:
	var _s0: int = TP.t()
	var _s_settled: int = 0
	var _s_scan: int = 0
	var edge_validation: Dictionary = _validate_edge_costs(edge_costs)
	if not bool(edge_validation["valid"]):
		return _path_failure(str(edge_validation["reason"]))
	if not _is_cell(origin):''')
sub(PS, '''		var current: Dictionary = _take_lowest_cost_cell(
			frontier,
			costs,
			deviations,
			destination_cell
		)''', '''		_s_scan += frontier.size()
		var _s1: int = TP.t()
		var current: Dictionary = _take_lowest_cost_cell(
			frontier,
			costs,
			deviations,
			destination_cell
		)
		TP.add("SP.take_lowest." + TP.caller, _s1)''')
sub(PS, '''		settled[current_key] = true

		if current_key == destination_key:
			return {''', '''		settled[current_key] = true
		_s_settled += 1

		if current_key == destination_key:
			TP.add("SP.total." + TP.caller, _s0)
			TP.count("SP.settled." + TP.caller, _s_settled)
			TP.count("SP.scanned." + TP.caller, _s_scan)
			TP.count("SP.calls." + TP.caller, 1)
			return {''')
_t = open(PS).read()
_old = "\t\tfor neighbor_value: Variant in StageTerrain.legal_neighbors(current, walkable, bounds):\n"
assert _t.count(_old) == 2
_new = ("\t\tvar _s2: int = TP.t()\n\t\tvar _nbrs: Array = StageTerrain.legal_neighbors(current, walkable, bounds)\n"
        "\t\tTP.add(\"SP.legal_neighbors.\" + TP.caller, _s2)\n\t\tfor neighbor_value: Variant in _nbrs:\n")
open(PS, "w").write(_t.replace(_old, _new, 1))
sub(PS, '''	return _path_failure("unreachable")''', '''	TP.add("SP.total_unreachable." + TP.caller, _s0)
	TP.count("SP.unreachable_calls." + TP.caller, 1)
	TP.count("SP.unreachable_settled." + TP.caller, _s_settled)
	return _path_failure("unreachable")''')
sub(MO, '''static func _candidate_routes(
	context: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary
) -> Array:
	var origin: Dictionary = context["origin"] as Dictionary''', '''static func _candidate_routes(
	context: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary
) -> Array:
	TP.count("CR.region_cells", (goal["destination_region"] as Array).size())
	TP.count("CR.walkable_cells", planning_walkable.size())
	TP.count("CR.edge_cost_entries", edge_costs.size())
	TP.count("CR.calls", 1)
	var origin: Dictionary = context["origin"] as Dictionary''')
print("level-3 patched")
