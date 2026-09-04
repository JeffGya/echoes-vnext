# res://tools/SpatialTermProbe.gd
#
# INVESTIGATION TOOL — not a test. Registered only under `-- tests spatialprobe`.
#
# Answers two questions for V2-COMBAT-003 phase 6, on all seven resolution modes:
#
#   FIELDS    — what values do `exposure`, `congestion` and `cohesion` actually carry on
#               the options the LIVE producer publishes? Read straight off
#               LiveMovementContextService.prepare_live_movement_context, which is the exact
#               call FlowRuntime._resolve_next_actor makes, with the board_cfg taken from the
#               production CombatTurnContextService.build_turn_context rather than rebuilt.
#   DECISIONS — one line per resolved turn (round, actor, action, from cell, to cell), so two
#               arms of the probe can be diffed with `diff` and every changed route named.
#
# Arms are selected by argument and applied to the in-memory balance only:
#   base    no override
#   noexp   exposure_weight = 0 AND directive_exposure_acceptance_weight = 0
#   noexpw  exposure_weight = 0 only
#   noacc   directive_exposure_acceptance_weight = 0 only
#   nocoh   cohesion_weight = 0
#   nocon   congestion_weight = 0
#
# Usage: `-- tests spatialprobe <arm>`. Report at user://spatial_term_probe_<arm>.txt.

class_name SpatialTermProbe
extends RefCounted

const LiveMovementScript := preload("res://core/movement/LiveMovementContextService.gd")

## The seven modes, with the same seed tags and guide arguments FlowFingerprintTests uses, so
## a probe arm and the recorded fingerprints describe the same seven encounters.
const MODES: Array = [
	["combat", "fp_combat", "", ""],
	["purify_shrine", "fp_purify_shrine", "", ""],
	["recover", "fp_recover", "", ""],
	["protect", "fp_protect", "", ""],
	["endure", "fp_endure", "", ""],
	["pursue", "fp_pursue", "", ""],
	["guide_spirit", "fp_guide_spirit", "protect", "nojoin"],
]

static var _sink: FileAccess = null


static func register(runner) -> void:
	runner.register_test("spatial_term_probe/run", func(): return run())


static func _say(line: String) -> void:
	print(line)
	if _sink != null:
		_sink.store_line(line)
		_sink.flush()


static func run() -> Dictionary:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var arm: String = str(argv[2]) if argv.size() > 2 else "base"
	_sink = FileAccess.open("user://spatial_term_probe_%s.txt" % arm, FileAccess.WRITE)
	_say("### ARM %s" % arm)
	for entry_v: Variant in MODES:
		var entry: Array = entry_v
		_run_mode(str(entry[0]), str(entry[1]), str(entry[2]), str(entry[3]), arm)
	if _sink != null:
		_sink.close()
		_sink = null
	return {"ok": true, "error": ""}


static func _run_mode(mode: String, tag: String, guide_mode: String, guide_joins: String, arm: String) -> void:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(mode, tag, guide_mode, guide_joins)
	if env.is_empty():
		_say("SETUP_FAILED %s" % mode)
		return
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	_apply_arm(runtime, arm)
	# Fields pass. Round 0 is not enough on its own: exposure only rises once a route runs
	# beside a controlling hostile, and the two sides start at opposite ends of the board.
	runtime.dispatch({"type": "combat.init"})
	_dump_fields(runtime, ectx, mode, 0)
	for round_index in range(1, 8):
		if bool(ectx.combat_state.get("combat_over", false)):
			break
		runtime.dispatch({"type": "combat.confirm_round"})
		var guard: int = 0
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)) or str(cs.get("round_phase", "")) != "in_round":
				break
			runtime.dispatch({"type": "combat.next_actor"})
		_dump_fields(runtime, ectx, mode, round_index)

	# Decisions pass — a SECOND, independently set up encounter, so the fields pass above
	# cannot perturb it, and so the capture stays FlowFingerprintTests' own.
	var env2: Dictionary = FlowFingerprintTests._setup_encounter(mode, tag, guide_mode, guide_joins)
	if env2.is_empty():
		_say("SETUP_FAILED %s" % mode)
		return
	_apply_arm(env2["runtime"] as FlowRuntime, arm)
	var drive: Dictionary = FlowFingerprintTests._drive_and_capture(
		env2["runtime"] as FlowRuntime, env2["ectx"] as EncounterContext, 30)
	_dump_decisions(mode, drive)


## Zeroes one or more spatial_utility weights in the in-memory balance. data/balance.json is
## never touched. FlowRuntime re-reads data.combat.movement on every activation, so an override
## applied after setup is honoured for the whole fight.
static func _apply_arm(runtime: FlowRuntime, arm: String) -> void:
	if arm == "base":
		return
	var cfg: Dictionary = runtime.config_service._balance \
		.get("data", {}).get("combat", {}).get("movement", {}).get("spatial_utility", {})
	match arm:
		"noexp":
			cfg["exposure_weight"] = 0.0
			cfg["directive_exposure_acceptance_weight"] = 0.0
		"noexpw":
			cfg["exposure_weight"] = 0.0
		"noacc":
			cfg["directive_exposure_acceptance_weight"] = 0.0
		"nocoh":
			cfg["cohesion_weight"] = 0.0
		"nocon":
			cfg["congestion_weight"] = 0.0
		"seek":
			_set_directive(runtime, "directive.seek_signs")
		"seeknoacc":
			_set_directive(runtime, "directive.seek_signs")
			cfg["directive_exposure_acceptance_weight"] = 0.0
		_:
			_say("UNKNOWN_ARM %s" % arm)


## One line per published option, for every living non-structure actor on the starting board.
static func _dump_fields(runtime: FlowRuntime, ectx: EncounterContext, mode: String, round_index: int) -> void:
	var balance: Dictionary = runtime.config_service.get_balance()
	var bdata: Dictionary = balance.get("data", {})
	var turn_ctx := CombatTurnContextService.new(
		runtime.flow_ctx, runtime.config_service, runtime.directive_service, runtime.logger)
	var live := LiveMovementScript.new(runtime.flow_ctx, runtime.logger)
	var t: int = 900 + round_index * 100
	for actor_v: Variant in ectx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if bool(actor.get("is_dead", false)) or bool(actor.get("is_structure", false)):
			continue
		t += 1
		var built: Dictionary = turn_ctx.build_turn_context(actor, ectx, balance, bdata, 0, t)
		var prepared: Dictionary = live.prepare_live_movement_context(
			actor, ectx, ectx.combat_state, built["board_cfg"] as Dictionary, bdata, t)
		if not bool(prepared.get("valid", false)):
			continue
		var options: Array = prepared.get("options", []) as Array
		if options.is_empty():
			_say("FIELDS %s r%02d %s NO_OPTIONS" % [mode, round_index, str(actor.get("id", ""))])
			continue
		for option_v: Variant in options:
			var option: Dictionary = option_v
			_say("FIELDS %s r%02d %s %s exp=%.4f con=%.4f coh=%.4f hostile=%d" % [
				mode,
				round_index,
				str(actor.get("id", "")),
				str(option.get("option_id", "")),
				float(option.get("exposure", -1.0)),
				float(option.get("congestion", -1.0)),
				float(option.get("cohesion", -1.0)),
				(option.get("hostile_control_sources", []) as Array).size(),
			])


## One line per resolved turn. Format is fixed and grep/diff friendly.
static func _dump_decisions(mode: String, drive: Dictionary) -> void:
	for round_v: Variant in drive.get("rounds", []) as Array:
		var round_entry: Dictionary = round_v
		for turn_v: Variant in round_entry.get("turns", []) as Array:
			var turn: Dictionary = turn_v
			_say("TURN %s r%02d %s %s tgt=%s dmg=%d from=%s to=%s" % [
				mode,
				int(round_entry.get("round", 0)),
				str(turn.get("actor_id", "")),
				str(turn.get("action_type", "")),
				str(turn.get("target_id", "")),
				int(turn.get("damage", 0)),
				_cell(turn.get("from_pos", {}) as Dictionary),
				_cell(turn.get("to_pos", {}) as Dictionary),
			])
	_say("MODE_END %s rounds=%d over=%s" % [
		mode,
		(drive.get("rounds", []) as Array).size(),
		str(bool(drive.get("combat_over", false))),
	])


static func _cell(cell: Dictionary) -> String:
	if cell.is_empty():
		return "-"
	return "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]


## exposure_acceptance is authored only on directive.seek_signs, so the default
## directive.scout_carefully leaves directive_exposure_acceptance_weight inert even once
## exposure is live. Switching the active directive separates "structurally inert" from
## "not exercised by this fixture".
static func _set_directive(runtime: FlowRuntime, directive_id: String) -> void:
	var save_data: Dictionary = runtime.flow_ctx.save_data
	if not (save_data.get("stage_context", null) is Dictionary):
		save_data["stage_context"] = {}
	(save_data["stage_context"] as Dictionary)["active_directive_id"] = directive_id
