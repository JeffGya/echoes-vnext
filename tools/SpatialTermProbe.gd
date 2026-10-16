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
#   scout   active Directive = directive.scout_carefully (the default; explicit for sweeps)
#   seek    active Directive = directive.seek_signs
#   nofear  exposure_acceptance.fear_lean_bound = 0 (fear lean off)
#   parts   log every Echo route decision (DECISION, TURNSUM, SUMMARY) from the arbiter pass of the
#           chosen move; decision pass only. Example: `scout,fear=50,parts`
#   boards  run only the fixture boards of tools/ExposureChoiceBoards.gd (no fights)
#   fear=N  every Echo starts with fear N and fear_base min(N, 40); keep N below the lowest
#           refusal threshold or the Echoes refuse (a warning line says so). Try 0, 20, 45, 60.
# Tokens combine with commas, and `<spatial_utility key>=<float>` sweeps a weight to any value:
#   seek,directive_exposure_acceptance_weight=20
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
static var _turns_by_action: Dictionary = {}
static var _fear_warned: bool = false
static var _parts_mode: String = ""
static var _parts_sum: Dictionary = {}


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
	if arm.split(",", false).has("boards"):
		_sink = FileAccess.open("user://spatial_term_probe_%s.txt" % arm, FileAccess.WRITE)
		ExposureChoiceBoards.run(arm)
		_sink.close()
		_sink = null
		return {"ok": true, "error": ""}
	_sink = FileAccess.open("user://spatial_term_probe_%s.txt" % arm, FileAccess.WRITE)
	_say("### ARM %s" % arm)
	_turns_by_action = {}
	_fear_warned = false
	var parts_on: bool = arm.split(",", false).has("parts")
	_parts_sum = {"echo_passes": 0, "purifier_skipped": 0, "with_routes": 0, "two_plus": 0, "mixed": 0,
		"mixed_xmargin_lt10": 0, "mixed_margin_lt10": 0, "mixed_flips": 0, "mixed_chosen_exposed": 0}
	for entry_v: Variant in MODES:
		var entry: Array = entry_v
		if parts_on:
			_run_parts_mode(str(entry[0]), str(entry[1]), str(entry[2]), str(entry[3]), arm)
		else:
			_run_mode(str(entry[0]), str(entry[1]), str(entry[2]), str(entry[3]), arm)
	if parts_on:
		var pieces: PackedStringArray = []
		for key: Variant in _parts_sum:
			pieces.append("%s=%d" % [str(key), int(_parts_sum[key])])
		_say("SUMMARY arm=%s %s" % [arm, " ".join(pieces)])
	var keys: Array = _turns_by_action.keys()
	keys.sort()
	for key: Variant in keys:
		_say("ECHO_TURNS %s = %d" % [str(key), int(_turns_by_action[key])])
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
	_apply_arm(runtime, arm, ectx)
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
	_apply_arm(env2["runtime"] as FlowRuntime, arm, env2["ectx"] as EncounterContext)
	var drive: Dictionary = FlowFingerprintTests._drive_and_capture(
		env2["runtime"] as FlowRuntime, env2["ectx"] as EncounterContext, 30)
	_dump_decisions(mode, drive, env2["ectx"] as EncounterContext)


## Decision pass only. Every Echo route decision is captured by ExposureCaptureArbiter in the same
## arbiter pass as the chosen move.
static func _run_parts_mode(mode: String, tag: String, guide_mode: String, guide_joins: String, arm: String) -> void:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(mode, tag, guide_mode, guide_joins)
	if env.is_empty():
		_say("SETUP_FAILED %s" % mode)
		return
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	_apply_arm(runtime, arm, ectx)
	_parts_mode = mode
	runtime.behavior_module_factory = func(actor_cfg: Dictionary, movement_cfg: Dictionary) -> BehaviorModule:
		var arbiter := ExposureCaptureArbiter.new(actor_cfg, movement_cfg)
		arbiter.on_done = Callable(SpatialTermProbe, "_on_capture").bind(ectx)
		return arbiter
	var drive: Dictionary = FlowFingerprintTests._drive_and_capture(runtime, ectx, 30)
	_dump_decisions(mode, drive, ectx)


## A pass with a ready purifier is counted apart: the arbiter sets its winner to 9999 after the
## capture point, so the capture is not the decision.
static func _on_capture(last: Dictionary, context: Dictionary, ectx: EncounterContext) -> void:
	var actor: Dictionary = context.get("actor", {}) as Dictionary
	if str(actor.get("faction", "")) != "echo":
		return
	var records: Array = last["records"]
	var chosen: Dictionary = last["chosen"]
	var round_index: int = int(ectx.combat_state.get("round_counter", 0))
	_parts_sum["echo_passes"] += 1
	if bool(context.get("is_purifier", false)) and bool(context.get("shrine_alive", false)) \
			and int(actor.get("purify_cooldown", 0)) == 0:
		_parts_sum["purifier_skipped"] += 1
		_say("PURIFIER_SKIPPED %s r%02d %s" % [_parts_mode, round_index, str(actor.get("id", ""))])
		return
	var tag: String = "%s r%02d %s" % [_parts_mode, round_index, str(actor.get("id", ""))]
	var summary: Dictionary = ExposureCaptureArbiter.analyse(records, chosen)
	for line: String in ExposureCaptureArbiter.decision_lines(tag, records, chosen):
		_say(line)
	_say(ExposureCaptureArbiter.turnsum_line(tag, summary))
	if int(summary["options"]) >= 1:
		_parts_sum["with_routes"] += 1
	if int(summary["options"]) >= 2:
		_parts_sum["two_plus"] += 1
	if not bool(summary["mixed"]):
		return
	_parts_sum["mixed"] += 1
	if float(summary["xmargin"]) >= 0.0 and float(summary["xmargin"]) < 10.0:
		_parts_sum["mixed_xmargin_lt10"] += 1
	if float(summary["margin"]) < 10.0:
		_parts_sum["mixed_margin_lt10"] += 1
	if bool(summary["flips"]):
		_parts_sum["mixed_flips"] += 1
	if bool(summary["chosen_exposed"]):
		_parts_sum["mixed_chosen_exposed"] += 1


## Overrides one or more spatial_utility weights in the in-memory balance. data/balance.json is
## never touched. FlowRuntime re-reads data.combat.movement on every activation, so an override
## applied after setup is honoured for the whole fight.
##
## An arm is a comma-separated token list. A token is either a named arm above, or a
## `<spatial_utility key>=<float>` assignment, so a weight can be swept rather than only zeroed:
##   `seek,directive_exposure_acceptance_weight=10`
static func _apply_arm(runtime: FlowRuntime, arm: String, ectx: EncounterContext = null) -> void:
	if arm == "base":
		return
	var cfg: Dictionary = runtime.config_service._balance \
		.get("data", {}).get("combat", {}).get("movement", {}).get("spatial_utility", {})
	for token: String in arm.split(",", false):
		match token:
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
			"parts":
				pass
			"scout":
				_set_directive(runtime, "directive.scout_carefully")
			"seek":
				_set_directive(runtime, "directive.seek_signs")
			"nofear":
				var block: Dictionary = runtime.config_service._balance \
					.get("data", {}).get("combat", {}).get("movement", {}).get("exposure_acceptance", {})
				block["fear_lean_bound"] = 0.0
			"seeknoacc":
				_set_directive(runtime, "directive.seek_signs")
				cfg["directive_exposure_acceptance_weight"] = 0.0
			_:
				var pair: PackedStringArray = token.split("=", false)
				if pair.size() == 2 and pair[0] == "fear" and pair[1].is_valid_int() and ectx != null:
					var fear_n: int = pair[1].to_int()
					for actor_v: Variant in ectx.actors:
						if actor_v is Dictionary and str((actor_v as Dictionary).get("faction", "")) == "echo":
							(actor_v as Dictionary)["fear"] = fear_n
							(actor_v as Dictionary)["fear_base"] = mini(fear_n, 40)
					var lowest: int = _lowest_refusal_threshold(runtime)
					if fear_n >= lowest and not _fear_warned:
						_fear_warned = true
						_say("### WARNING fear=%d is at or above the lowest refusal threshold %d: every Echo turn at or below that threshold will refuse" % [fear_n, lowest])
					_say("### OVERRIDE echo fear = %s" % pair[1])
					continue
				# An unknown key must not pass silently: it would read as "this weight
				# changes nothing" when in fact nothing was overridden.
				if pair.size() != 2 or not cfg.has(pair[0]) or not pair[1].is_valid_float():
					_say("UNKNOWN_ARM %s" % token)
					continue
				cfg[pair[0]] = pair[1].to_float()
				_say("### OVERRIDE %s = %s" % [pair[0], pair[1]])


## Lowest Absolute Fear Rule threshold: lowest band base plus lowest calling offset.
static func _lowest_refusal_threshold(runtime: FlowRuntime) -> int:
	var actor_cfg: Dictionary = runtime.config_service._balance.get("data", {}).get("actor", {})
	var lowest_band: int = 100
	for value: Variant in (actor_cfg.get("refusal_thresholds_by_band", {}) as Dictionary).values():
		if value is int or value is float:
			lowest_band = mini(lowest_band, int(value))
	var lowest_offset: int = 0
	for entry: Variant in (actor_cfg.get("calling_behavior", {}) as Dictionary).values():
		if entry is Dictionary and (entry as Dictionary).has("absolute_fear_offset"):
			lowest_offset = mini(lowest_offset, int((entry as Dictionary)["absolute_fear_offset"]))
	return clampi(lowest_band + lowest_offset, 0, 100)


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
static func _dump_decisions(mode: String, drive: Dictionary, ectx: EncounterContext) -> void:
	var echo_ids: Dictionary = {}
	for actor_v: Variant in ectx.actors:
		if actor_v is Dictionary and str((actor_v as Dictionary).get("faction", "")) == "echo":
			echo_ids[str((actor_v as Dictionary).get("id", ""))] = true
	for round_v: Variant in drive.get("rounds", []) as Array:
		var round_entry: Dictionary = round_v
		for turn_v: Variant in round_entry.get("turns", []) as Array:
			var turn: Dictionary = turn_v
			if echo_ids.has(str(turn.get("actor_id", ""))):
				var action_key: String = str(turn.get("action_type", ""))
				_turns_by_action[action_key] = int(_turns_by_action.get(action_key, 0)) + 1
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


## Switches the active Directive, so a sweep can compare Scout and Seek on the same encounter.
static func _set_directive(runtime: FlowRuntime, directive_id: String) -> void:
	var save_data: Dictionary = runtime.flow_ctx.save_data
	if not (save_data.get("stage_context", null) is Dictionary):
		save_data["stage_context"] = {}
	(save_data["stage_context"] as Dictionary)["active_directive_id"] = directive_id
