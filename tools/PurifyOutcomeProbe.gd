# res://tools/PurifyOutcomeProbe.gd
#
# INVESTIGATION TOOL — not a test. Registered only under `-- tests purifyprobe`.
#
# V2-COMBAT-003 phase 7b. Two questions about the PURIFY_SHRINE mode:
#
#   OUTCOME — over 20 independently seeded purify encounters: victory or defeat, the round it
#             ended, and the shrine's HP at the end. This is the phase-7b stop condition
#             (20/20 victories in rounds 5..16) and the shrine-survival before/after.
#   GOALS   — for the first few rounds of a few of those encounters, the goals
#             CombatPressureService actually publishes for the designated purifier, read from
#             the same LiveMovementContextService call FlowRuntime._resolve_next_actor makes.
#             This is the only way to see the objective-anchored branch run: the chosen
#             goal_id is never logged (see tests/CombatBaselineTests.gd "PERMANENT GAP").
#
# The two passes use separate encounters so the read-only goal dump cannot perturb the
# outcome numbers, mirroring tools/SpatialTermProbe.gd.
#
# Usage: `-- tests purifyprobe [tag]`. Report at user://purify_outcome_probe_<tag>.txt.

class_name PurifyOutcomeProbe
extends RefCounted

const LiveMovementScript := preload("res://core/movement/LiveMovementContextService.gd")

const RUNS := 20
const MAX_ROUNDS := 30
## Encounters whose purifier goals are dumped round by round.
const GOAL_DUMP_RUNS := 3
const GOAL_DUMP_ROUNDS := 4

static var _sink: FileAccess = null


static func register(runner) -> void:
	runner.register_test("purify_outcome_probe/run", func(): return run())


static func _say(line: String) -> void:
	print(line)
	if _sink != null:
		_sink.store_line(line)
		_sink.flush()


static func run() -> Dictionary:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var tag: String = str(argv[2]) if argv.size() > 2 else "base"
	_sink = FileAccess.open("user://purify_outcome_probe_%s.txt" % tag, FileAccess.WRITE)
	_say("### PURIFY OUTCOME PROBE %s" % tag)

	# A tag beginning with "turns" runs only the per-turn trace of the fixture the
	# recorded fingerprint uses, so a moved hash can be attributed turn by turn.
	if tag.begins_with("turns"):
		_dump_turns("fp_purify_shrine")
		if _sink != null:
			_sink.close()
			_sink = null
		return {"ok": true, "error": ""}

	var victories: int = 0
	var in_band: int = 0
	for index: int in range(RUNS):
		var seed_tag: String = "p7b_%02d" % index
		var outcome: Dictionary = _run_outcome(seed_tag)
		if outcome.is_empty():
			_say("RUN %s SETUP_FAILED" % seed_tag)
			continue
		if bool(outcome["victory"]):
			victories += 1
			var rounds: int = int(outcome["round_ended"])
			if rounds >= 5 and rounds <= 16:
				in_band += 1
		_say("RUN %s victory=%s reason=%-22s round=%2d shrine_hp=%3d/%3d purifier=%s enemies_left=%d echoes_left=%d" % [
			seed_tag,
			str(bool(outcome["victory"])),
			str(outcome["reason"]),
			int(outcome["round_ended"]),
			int(outcome["shrine_hp"]),
			int(outcome["shrine_max_hp"]),
			str(outcome["purifier_id"]),
			int(outcome["enemies_left"]),
			int(outcome["echoes_left"]),
		])
	_say("TOTAL victories=%d/%d in_band_5_16=%d/%d" % [victories, RUNS, in_band, RUNS])

	for index: int in range(GOAL_DUMP_RUNS):
		_dump_goals("p7b_%02d" % index)

	if _sink != null:
		_sink.close()
		_sink = null
	return {"ok": true, "error": ""}


static func _run_outcome(seed_tag: String) -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(
		EncounterResolutionModes.PURIFY_SHRINE, seed_tag)
	if env.is_empty():
		return {}
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	FlowFingerprintTests._drive_and_capture(runtime, ectx, MAX_ROUNDS)
	var shrine: Dictionary = _shrine(ectx)
	var result: Dictionary = ectx.combat_result
	return {
		"victory": bool(result.get("victory", false)),
		"reason": str(result.get("reason", "no_end_within_%d_rounds" % MAX_ROUNDS)),
		"round_ended": int(result.get("round_ended", int(ectx.combat_state.get("round_counter", 0)))),
		"shrine_hp": int(shrine.get("current_hp", 0)),
		"shrine_max_hp": int((shrine.get("stats", {}) as Dictionary).get("max_hp", 0)),
		"purifier_id": str(ectx.purifier_id),
		"enemies_left": _living(ectx, "enemy"),
		"echoes_left": _living(ectx, "echo"),
	}


## Round-by-round goals for the purifier, plus one non-purifier echo, on a fresh encounter.
static func _dump_goals(seed_tag: String) -> void:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(
		EncounterResolutionModes.PURIFY_SHRINE, seed_tag)
	if env.is_empty():
		_say("GOALS %s SETUP_FAILED" % seed_tag)
		return
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({"type": "combat.init"})
	for round_index: int in range(1, GOAL_DUMP_ROUNDS + 1):
		if bool(ectx.combat_state.get("combat_over", false)):
			break
		_dump_goals_for_round(runtime, ectx, seed_tag, round_index)
		runtime.dispatch({"type": "combat.confirm_round"})
		var guard: int = 0
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)) or str(cs.get("round_phase", "")) != "in_round":
				break
			runtime.dispatch({"type": "combat.next_actor"})


static func _dump_goals_for_round(
	runtime: FlowRuntime, ectx: EncounterContext, seed_tag: String, round_index: int
) -> void:
	var balance: Dictionary = runtime.config_service.get_balance()
	var bdata: Dictionary = balance.get("data", {})
	var turn_ctx := CombatTurnContextService.new(
		runtime.flow_ctx, runtime.config_service, runtime.directive_service, runtime.logger)
	var live := LiveMovementScript.new(runtime.flow_ctx, runtime.logger)
	var shrine: Dictionary = _shrine(ectx)
	var shrine_max: int = int((shrine.get("stats", {}) as Dictionary).get("max_hp", 1))
	var ratio: float = 0.0 if shrine_max <= 0 else float(shrine.get("current_hp", 0)) / float(shrine_max)
	var t: int = 5000 + round_index * 100
	for actor_v: Variant in ectx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if bool(actor.get("is_dead", false)) or bool(actor.get("is_structure", false)):
			continue
		var actor_id: String = str(actor.get("id", ""))
		var is_purifier: bool = actor_id == str(ectx.purifier_id)
		if not is_purifier and str(actor.get("faction", "")) != "enemy":
			continue
		t += 1
		var built: Dictionary = turn_ctx.build_turn_context(actor, ectx, balance, bdata, round_index, t)
		var prepared: Dictionary = live.prepare_live_movement_context(
			actor, ectx, ectx.combat_state, built["board_cfg"] as Dictionary, bdata, t)
		if not bool(prepared.get("valid", false)):
			continue
		var goals: Array = prepared.get("goals", []) as Array
		if goals.is_empty():
			_say("GOALS %s r%02d hp=%.2f %s NO_GOALS" % [seed_tag, round_index, ratio, actor_id])
			continue
		for goal_v: Variant in goals:
			var goal: Dictionary = goal_v
			_say("GOALS %s r%02d hp=%.2f %s %s urg=%.2f primary=%s region=%d" % [
				seed_tag,
				round_index,
				ratio,
				actor_id,
				str(goal.get("goal_id", "")),
				float(goal.get("urgency", 0.0)),
				str((goal.get("planned_primary", {}) as Dictionary).get("type", "")),
				(goal.get("destination_region", []) as Array).size(),
			])


## Every resolved turn of one fixture, in the grep/diff-friendly shape SpatialTermProbe uses.
static func _dump_turns(seed_tag: String) -> void:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(
		EncounterResolutionModes.PURIFY_SHRINE, seed_tag)
	if env.is_empty():
		_say("TURNS %s SETUP_FAILED" % seed_tag)
		return
	var ectx: EncounterContext = env["ectx"]
	var drive: Dictionary = FlowFingerprintTests._drive_and_capture(
		env["runtime"] as FlowRuntime, ectx, MAX_ROUNDS)
	for round_v: Variant in drive.get("rounds", []) as Array:
		var round_entry: Dictionary = round_v
		for turn_v: Variant in round_entry.get("turns", []) as Array:
			var turn: Dictionary = turn_v
			_say("TURN r%02d %-22s %-18s tgt=%-22s dmg=%3d from=%s to=%s" % [
				int(round_entry.get("round", 0)),
				str(turn.get("actor_id", "")),
				str(turn.get("action_type", "")),
				str(turn.get("target_id", "")),
				int(turn.get("damage", 0)),
				_cell(turn.get("from_pos", {}) as Dictionary),
				_cell(turn.get("to_pos", {}) as Dictionary),
			])
	var shrine: Dictionary = _shrine(ectx)
	_say("TURNS_END rounds=%d over=%s victory=%s shrine_hp=%d" % [
		(drive.get("rounds", []) as Array).size(),
		str(bool(drive.get("combat_over", false))),
		str(bool(ectx.combat_result.get("victory", false))),
		int(shrine.get("current_hp", 0)),
	])


static func _cell(cell: Dictionary) -> String:
	if cell.is_empty():
		return "-"
	return "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]


static func _shrine(ectx: EncounterContext) -> Dictionary:
	for actor_v: Variant in ectx.actors:
		if actor_v is Dictionary and bool((actor_v as Dictionary).get("is_structure", false)):
			return actor_v
	return {}


static func _living(ectx: EncounterContext, faction: String) -> int:
	var count: int = 0
	for actor_v: Variant in ectx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("faction", "")) == faction and not bool(actor.get("is_dead", false)) \
				and not bool(actor.get("is_structure", false)):
			count += 1
	return count
