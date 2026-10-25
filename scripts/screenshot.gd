# Renders a chosen UI screen state to a PNG (ANSWERS.md #65).
#
# Usage (1920x1080 is the reference composition size, AGENTS.md "UI Rules"):
#   xvfb-run -a -s '-screen 0 1920x1080x24' godot --path <checkout> --rendering-driver opengl3 \
#       --resolution 1920x1080 --script res://scripts/screenshot.gd -- <fixture|all|list> [out_dir]
#
#   <fixture>  one key of FIXTURES; "all" renders every fixture; "list" prints the keys.
#   [out_dir]  an absolute directory; default user://screenshots. Output: <out_dir>/<fixture>.png.
#   [profile]  compact, standard or wide: forces that layout profile. Output: <fixture>_<profile>.png.
#
# On macOS, run it from a real window without xvfb:
#   godot --path <checkout> --resolution 1920x1080 --script res://scripts/screenshot.gd -- <fixture> <out_dir>
# Godot's --headless mode cannot render screenshots (dummy renderer, null texture).
#
# The layer hierarchy (RealmShell on layer 10, ModalHost on layer 40, as in Approot.tscn) lives
# in screenshot_harness.tscn (AGENTS.md "Build structure in .tscn"). This script only instances it,
# feeds it a hand-built snapshot and saves the frame. It never boots FlowRuntime, so it writes no save and does not touch the test save
# directory. A fixture's snapshots are applied in order; a flow.resolve snapshot opens as the
# resolve modal over the board before it. To add a screen state, add a FIXTURES entry.
# A fixture copies the snapshot contract; update it when that contract changes.
extends SceneTree

const HarnessScene := preload("res://scripts/screenshot_harness.tscn")
const SanctumHarnessScene := preload("res://scripts/screenshot_harness_sanctum.tscn")
const SETTLE_FRAMES := 45


func _initialize() -> void:
	_run()


func _run() -> void:
	# The root enters the tree after _initialize; nodes added before that never get _ready.
	await process_frame
	var args := OS.get_cmdline_user_args()
	var which := str(args[0]) if args.size() > 0 else "list"
	var out_dir := str(args[1]) if args.size() > 1 else "user://screenshots"
	var profile := str(args[2]) if args.size() > 2 else ""
	var fixtures := _fixtures()
	if which == "list" or (which != "all" and not fixtures.has(which)):
		print("Fixtures: all, ", ", ".join(PackedStringArray(fixtures.keys())))
		quit(0 if which == "list" else 1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var names: Array = fixtures.keys() if which == "all" else [which]
	for fixture_name in names:
		await _render_fixture(str(fixture_name), fixtures[fixture_name], out_dir, profile)
	quit(0)


func _render_fixture(fixture_name: String, snapshots: Array, out_dir: String, profile: String = "") -> void:
	var layout := ResponsiveLayoutController.calculate_layout(Vector2(root.size))
	if not profile.is_empty():
		layout["profile"] = StringName(profile)
	ResponsiveLayoutController.apply_content_scale_size(root, layout)

	# A fixture of flow.summon snapshots needs the Sanctum shell, which owns that screen.
	var sanctum_fixture: bool = fixture_name.begins_with("summon_")
	var harness := (SanctumHarnessScene if sanctum_fixture else HarnessScene).instantiate()
	root.add_child(harness)
	var shell := harness.get_node("ContentLayer/SanctumShell" if sanctum_fixture else "ContentLayer/RealmShell") as Control
	var modal_host := harness.get_node("ModalLayer/ModalHost") as Control
	shell.modal_requested.connect(func(modal_id: StringName, payload: Dictionary) -> void:
		modal_host.call("present_modal_for_id", modal_id, shell.call("modal_scene_for", modal_id), payload))

	shell.call("set_layout", layout)
	for snap in snapshots:
		if snap is Dictionary and snap.has("_modal"):
			var req: Dictionary = snap["_modal"]
			modal_host.call("present_modal_for_id", req["id"], shell.call("modal_scene_for", req["id"]), req["payload"])
		elif snap is String:
			_run_step(harness, snap)
		else:
			shell.call("set_snapshot", snap)
		await process_frame
	for _i in range(SETTLE_FRAMES):
		await process_frame

	var file_name := fixture_name if profile.is_empty() else "%s_%s" % [fixture_name, profile]
	var path := out_dir.path_join(file_name + ".png")
	var err := root.get_texture().get_image().save_png(path)
	print("SHOT %s -> %s (err=%d)" % [fixture_name, ProjectSettings.globalize_path(path), err])
	harness.queue_free()
	await process_frame


# ── Fixtures ────────────────────────────────────────────────────────────────

func _fixtures() -> Dictionary:
	var recover := { "type": "recover", "hold_progress": 1, "hold_required": 3 }
	var endure := { "type": "endure", "round": 4, "rounds_required": 8, "waves_remaining": 2 }
	var escort := { "type": "guide_spirit", "guide_mode": "escort", "spirit_name": "Nana", "destination_reached": false }
	return {
		"combat_pace_full":    [_combat(3, _with(recover, "pace_state", "full"))],
		"combat_pace_partial": [_combat(6, _with(recover, "pace_state", "partial"))],
		"combat_pace_none":    [_combat(9, _with(recover, "pace_state", "none"))],
		"combat_no_pace":      [_combat(4, endure)],
		"combat_escort_pace_partial": [_combat(7, _with(escort, "pace_state", "partial"))],
		"combat_initiative_full": [_combat_initiative(_with(escort, "pace_state", "partial"))],
		"resolve_escort_win":  [_combat(9, escort),
			_resolve(true, "spirit_escorted", 9, "S", { "pace_state": "full", "pace_changed_rank": false })],
		"resolve_pace_win":    [_combat(6, recover),
			_resolve(true, "relic_secured", 6, "B", { "pace_state": "partial", "pace_changed_rank": false })],
		"resolve_pace_win_rank_changed": [_combat(4, recover),
			_resolve(true, "relic_secured", 4, "A", { "pace_state": "full", "pace_changed_rank": true })],
		"resolve_pace_win_zero": [_combat(10, recover),
			_resolve(true, "relic_secured", 10, "C", { "pace_state": "none", "pace_changed_rank": false })],
		"resolve_no_pace_win": [_combat(8, endure), _resolve(true, "endured", 8, "B", {})],
		"resolve_pace_defeat": [_combat(7, recover), _resolve(false, "all_echoes_dead", 7, "F", {})],
		"resolve_ledger_closed": [_combat(6, recover), _payout_stage_end(true), "skip_motion"],
		"resolve_ledger_open_fight": [_combat(6, recover), _payout_repeat_defeat()],
		"resolve_stage_end": [_combat(6, recover), _payout_stage_end(false), "skip_motion"],
		"resolve_stage_end_first_view": [_combat(6, recover), _payout_stage_end(false), "freeze_motion"],
		"resolve_stage_earlier_death": [_combat(6, recover), _payout_stage_earlier_death(), "skip_motion"],
		"resolve_stage_home_lost": [_combat(6, recover), _payout_stage_end(true), "skip_motion"],
		"resolve_stage_home_all": [_combat(6, recover), _payout_stage_all_home(), "skip_motion"],
		"resolve_midstage_win_no_rows": [_combat(6, recover), _payout_midstage_win(), "skip_motion"],
		"resolve_midstage_event": [_combat(6, recover), _payout_midstage_event(), "skip_motion"],
		"resolve_defeat_consolation": [_combat(7, recover), _payout_defeat()],
		"resolve_retreat_zero": [_combat(7, recover), _payout_retreat_zero()],
		"carry_return_home": [_combat(6, recover), _return_home_modal({ "ase": 4, "ekwan": 2, "overcome": 1, "total": 3 })],
		"carry_return_home_zero": [_combat(6, recover), _return_home_modal({ "ase": 0, "ekwan": 0, "overcome": 1, "total": 3 })],
		"carry_retreat": [_prebattle({ "carry_retreat_preview": { "ase": 4, "ekwan": 0, "overcome": 1, "total": 3 } })],
		"retreat_disabled_price": [_prebattle({ "retreat_affordable": false })],
		"retreat_denied": [_prebattle({ "retreat_affordable": false,
			"retreat_denied": { "reason": "insufficient_ase", "ase_cost": 10, "ase_balance": 4 } })],
		"resolve_tooltip_open": [_combat(6, recover), _payout_stage_end(false), "skip_motion", "focus_cause:2"],
		"summon_price_rising":   [_summon({})],
		"summon_price_flat":     [_summon({ "living_count": 14, "price_flat": true, "batch_affordable_max": 1,
			"batch_prices": [430, 430, 430, 430, 430, 430, 430, 430, 430, 430],
			"batch_totals": [430, 860, 1290, 1720, 2150, 2580, 3010, 3440, 3870, 4300],
			"ase_balance": 500,
			"summon_grade_options": _summon_grades(430, 430) })],
		"summon_price_short":    [_summon({ "ase_balance": 100, "batch_affordable_max": 0, "summon_disabled": true, "ase_short_by": 45 })],
	}


func _summon_grades(uncalled: int, after: int) -> Array:
	return [
		{ "key": "uncalled", "label": "Uncalled", "enabled": true, "ase_cost": uncalled, "ase_cost_after": after },
		{ "key": "called", "label": "Called", "enabled": false, "ase_cost": uncalled + 90, "ase_cost_after": after + 90 },
		{ "key": "chosen", "label": "Chosen", "enabled": false, "ase_cost": uncalled + 340, "ase_cost_after": after + 340 },
	]


# FlowSummonState.build_snapshot data keys, V2-ECONOMY-004 Phase 5.5. Defaults: 7 living, 700 Ase.
func _summon(over: Dictionary) -> Dictionary:
	var data := {
		"title": "Summon Echo", "ase_balance": 700, "ase_rate_per_hour_hint": 4.0, "living_count": 7,
		"village_ceiling": 14, "price_flat": false, "selected_grade": "uncalled", "summon_disabled": false,
		"batch_prices": [145, 175, 210, 250, 300, 360, 430, 430, 430, 430],
		"batch_totals": [145, 320, 530, 780, 1080, 1440, 1870, 2300, 2730, 3160],
		"batch_affordable_max": 3, "ase_short_by": 0,
		"summon_grade_options": _summon_grades(145, 175), "pending_summon_reveals": [],
	}
	for k in over.keys():
		data[k] = over[k]
	return { "type": "flow.summon", "data": data, "actions": { "cta.summon": { "type": "sanctum.summon", "slot": "cta.summon" } } }


func _with(d: Dictionary, key: String, value: Variant) -> Dictionary:
	var out := d.duplicate(true)
	out[key] = value
	return out


func _actors() -> Array:
	return [
		_actor("e1", "Ama", "echo", 2, 5, 18, 22),
		_actor("e2", "Kofi", "echo", 3, 6, 12, 20),
		_actor("e3", "Esi", "echo", 2, 7, 20, 20),
		_actor("m1", "Hollow", "enemy", 6, 2, 9, 14),
		_actor("m2", "Hollow", "enemy", 7, 3, 14, 14),
	]


func _actor(id: String, actor_name: String, faction: String, col: int, row: int, hp: int, max_hp: int) -> Dictionary:
	return {
		"id": id, "name": actor_name, "faction": faction,
		"grid_pos": { "col": col, "row": row },
		"hp": hp, "current_hp": hp, "max_hp": max_hp,
		"emotional_status": "grounded",
	}


func _combat(round_num: int, objective_state: Dictionary) -> Dictionary:
	return {
		"type": "flow.encounter",
		"meta": { "t": 1 },
		"data": {
			"encounter_id": "screenshot",
			"board_cols": 10, "board_rows": 10,
			"round": round_num,
			"round_phase": "actor_turn",
			"combat_over": false,
			"actors": _actors(),
			"current_actor_id": "",
			"objective_state": objective_state,
		},
		"actions": {},
	}


## Eight initiative rows: five echoes, the escorted spirit and two enemies, with some action text.
func _combat_initiative(objective_state: Dictionary) -> Dictionary:
	var snap := _combat(5, objective_state)
	var actors: Array = _actors()
	actors.append(_actor("e4", "Yaw", "echo", 3, 4, 16, 20))
	actors.append(_actor("e5", "Abena", "echo", 2, 3, 20, 24))
	actors.append(_actor("s1", "Nana", "spirit", 4, 5, 10, 10))
	var order: Array = []
	for a in ["e1", "m1", "e2", "s1", "e3", "m2", "e4", "e5"]:
		for actor in actors:
			if actor["id"] == a:
				order.append({ "id": a, "name": actor["name"] })
	snap["data"]["actors"] = actors
	snap["data"]["initiative_order"] = order
	snap["data"]["active_initiative_index"] = 3
	snap["data"]["action_results"] = [
		{ "source_id": "e1", "action_type": "melee_attack", "target_name": "Hollow", "damage": 6 },
		{ "source_id": "m1", "action_type": "actor.move", "target_name": "Ama" },
		{ "source_id": "e2", "action_type": "actor.guard" },
	]
	return snap


func _resolve(victory: bool, reason: String, round_ended: int, rank: String, pace: Dictionary) -> Dictionary:
	var breakdown: Array = []
	if victory:
		breakdown.append({ "label": "3 echoes survived", "delta": 15, "currency": "ase" })
	else:
		breakdown.append({ "label": "Base objectives", "delta": 40, "currency": "ase" })
		breakdown.append({ "label": "Defeat penalty", "delta": -30, "currency": "ase" })
	var total := 0
	for row in breakdown:
		total += int(row["delta"])
	var data := {
		"victory": victory,
		"reason": reason,
		"rank": rank,
		"ase_awarded": total,
		"enemies_defeated": 2,
		"echoes_survived": 3 if victory else 0,
		"round_ended": round_ended,
		"reward_breakdown": breakdown,
		"emotion_summary": [],
		"actors": _actors(),
	}
	data.merge(pace)
	var actions := { "cta.continue": { "type": "flow.go_state", "slot": "cta.continue", "label": "To Sanctum" } }
	return { "type": "flow.resolve", "meta": { "t": 2 }, "data": data, "actions": actions }


## A fixture step that is a String acts on the live scene. "focus_cause:N" focuses the Nth (i) button.
func _run_step(harness: Node, step: String) -> void:
	var parts := step.split(":")
	if parts[0] == "freeze_motion":
		for node in harness.find_children("*", "Control", true, false):
			if node.has_method("skip_motion") and node.get("_motion") != null:
				(node.get("_motion") as Tween).pause()
	if parts[0] == "skip_motion":
		for node in harness.find_children("*", "Control", true, false):
			if node.has_method("skip_motion"):
				node.call("skip_motion")
	if parts[0] == "focus_cause":
		var buttons := harness.find_children("CauseButton", "Button", true, false)
		var visible_buttons := buttons.filter(func(b: Node) -> bool: return (b as Button).is_visible_in_tree())
		var index := int(parts[1]) if parts.size() > 1 else 0
		if index < visible_buttons.size():
			(visible_buttons[index] as Button).grab_focus()


func _row(label: String, delta: int, cause: String, params: Dictionary = {}) -> Dictionary:
	return { "label": label, "delta": delta, "currency": "ase", "cause": cause, "params": params }


## Fixture amounts are arbitrary. The real values come from EconomyService.
func _payout_data(victory: bool, reason: String, rank: String, rows: Array, seen: bool) -> Dictionary:
	var total := 0
	for row in rows:
		total += int(row["delta"])
	return {
		"victory": victory, "reason": reason, "rank": rank, "ase_awarded": total, "ekwan_awarded": 0,
		"enemies_defeated": 3, "echoes_survived": 3 if victory else 0, "round_ended": 6,
		"reward_breakdown": rows, "ledger_seen": seen, "actors": _actors(),
		"emotion_summary": [
			{ "echo_id": "e1", "name": "Ama", "pre_emotional_status": "grounded", "post_emotional_status": "radiant", "direction": "lift" },
			{ "echo_id": "e2", "name": "Kofi", "pre_emotional_status": "grounded", "post_emotional_status": "uncertain", "direction": "fall" },
			{ "echo_id": "e3", "name": "Esi", "pre_emotional_status": "grounded", "post_emotional_status": "grounded", "direction": "steady" },
		],
	}


func _payout_snap(data: Dictionary) -> Dictionary:
	var actions := { "cta.continue": { "type": "flow.go_state", "slot": "cta.continue", "label": "To Sanctum" } }
	return { "type": "flow.resolve", "meta": { "t": 2 }, "data": data, "actions": actions }


## A mid-stage win pays nothing and has no rows: the Direction E card. Three Echoes, all alive.
func _payout_midstage_win() -> Dictionary:
	var data := _payout_data(true, "relic_secured", "A", [], true)
	data["pace_state"] = "partial"
	return _payout_snap(data)


## The same card with every line present: a shaken Echo, an overcome objective, intel, a whole Thread.
func _payout_midstage_event() -> Dictionary:
	var snap := _payout_midstage_win()
	snap["data"]["emotion_summary"][1]["direction"] = "fall"
	snap["data"]["intel_gained"] = 1
	snap["data"]["thread_whole"] = true
	snap["data"]["objective_overcome"] = { "index": 1, "type": "recover", "label": "A lost keepsake is recovered." }
	return snap


func _payout_stage_end(seen: bool) -> Dictionary:
	var snap := _payout_midstage_win()
	var stage_rows := [
		_row("Base objectives", 90, "objectives_overcome", { "overcome": 2, "total": 3, "realm_scale": 1.0 }),
		_row("Redo penalty", -58, "replay", { "factor": 0.35 }),
		_row("Echoes home", 4, "echoes_alive", { "alive": 2, "started": 3, "lost": ["Kofi"], "cap": 10, "replay": true }),
		_row("Carried home", -20, "carried_advance", { "carried_ase": 20, "carried_ekwan": 3 }),
	]
	snap["data"]["ledger_seen"] = seen
	snap["data"]["echoes_survived"] = 2
	snap["data"]["stage_payout_rows"] = stage_rows
	snap["data"]["stage_payout_ase"] = 16
	snap["data"]["stage_payout_ekwan"] = 4
	snap["actions"]["cta.next_stage"] = { "type": "flow.complete_stage", "slot": "cta.next_stage", "label": "Complete Stage" }
	return snap


func _payout_stage_all_home() -> Dictionary:
	var snap := _payout_stage_end(true)
	var rows: Array = snap["data"]["stage_payout_rows"]
	rows[2] = _row("Echoes home", 6, "echoes_alive", { "alive": 3, "started": 3, "lost": [], "cap": 10, "replay": false })
	snap["data"]["echoes_survived"] = 3
	return snap


## Yaw died in an earlier fight: params.lost names him, no row of this fight carries him.
func _payout_stage_earlier_death() -> Dictionary:
	var snap := _payout_stage_end(true)
	var rows: Array = snap["data"]["stage_payout_rows"]
	rows[2] = _row("Echoes home", 6, "echoes_alive", { "alive": 3, "started": 4, "lost": ["Yaw"], "cap": 10, "replay": false })
	snap["data"]["echoes_survived"] = 3
	return snap


func _payout_repeat_defeat() -> Dictionary:
	return _payout_snap(_payout_data(false, "all_echoes_dead", "F", [_row("Repeat defeat", 0, "repeat_defeat")], false))


func _payout_defeat() -> Dictionary:
	var rows := [
		_row("Base objectives", 40, "defeat_consolation", { "part": "base" }),
		_row("Defeat penalty", -30, "defeat_consolation", { "part": "penalty" }),
		_row("Redo penalty", -1, "replay", { "factor": 0.9 }),
	]
	return _payout_snap(_payout_data(false, "all_echoes_dead", "F", rows, false))


func _payout_retreat_zero() -> Dictionary:
	var data := _payout_data(false, "", "F", [_row("Nothing carried home", 0, "nothing_overcome_yet")], false)
	data["run_type"] = "scout_return"
	data["intel_count"] = 0
	data["actors"] = _actors()
	return _payout_snap(data)


func _return_home_modal(carry: Dictionary) -> Dictionary:
	return { "_modal": { "id": &"realm.return_home", "payload": {
		"result": { "success": true, "message": "The party slips away." }, "carry": carry,
		"party": [{ "name": "Ama", "emotional_status": "grounded" }, { "name": "Kofi", "emotional_status": "uncertain" },
			{ "name": "Esi", "emotional_status": "whole" }] } } }


## A pre-combat snapshot: the shell shows the pre-battle modal with the retreat button.
func _prebattle(extra: Dictionary) -> Dictionary:
	var snap := _combat(1, { "type": "combat" })
	var actors: Array = _actors()
	for a in actors:
		if a["faction"] == "echo":
			a["emotional_status"] = "grounded"
	snap["data"]["actors"] = actors
	snap["data"]["round_phase"] = "pre_combat"
	snap["data"]["retreat_eligible"] = true
	snap["data"]["retreat_tier_label"] = "Risky"
	snap["data"]["retreat_ase_cost"] = 10
	snap["data"]["retreat_affordable"] = true
	snap["data"].merge(extra, true)
	snap["actions"] = {
		"cta.combat_init": { "type": "combat.init", "slot": "cta.combat_init", "label": "Start Combat" },
		"cta.retreat": { "type": "encounter.retreat", "slot": "cta.retreat", "success_pct": 50, "ase_cost": 10 } }
	return snap
