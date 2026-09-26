# Renders a chosen UI screen state to a PNG (ANSWERS.md #65).
#
# Usage (1920x1080 is the reference composition size, AGENTS.md "UI Rules"):
#   xvfb-run -a -s '-screen 0 1920x1080x24' godot --path <checkout> --rendering-driver opengl3 \
#       --resolution 1920x1080 --script res://scripts/screenshot.gd -- <fixture|all|list> [out_dir]
#
#   <fixture>  one key of FIXTURES; "all" renders every fixture; "list" prints the keys.
#   [out_dir]  an absolute directory; default user://screenshots. Output: <out_dir>/<fixture>.png.
#
# The script mounts RealmShell and ModalHost the way AppRoot does and feeds them a hand-built
# snapshot. It never boots FlowRuntime, so it writes no save and does not touch the test save
# directory. A fixture's snapshots are applied in order; a flow.resolve snapshot opens as the
# resolve modal over the board before it. To add a screen state, add a FIXTURES entry.
# A fixture copies the snapshot contract; update it when that contract changes.
extends SceneTree

const RealmShellScene := preload("res://ui/shells/RealmShell.tscn")
const ModalHostScene  := preload("res://ui/components/ModalHost.tscn")
const SETTLE_FRAMES := 45


func _initialize() -> void:
	_run()


func _run() -> void:
	# The root enters the tree after _initialize; nodes added before that never get _ready.
	await process_frame
	var args := OS.get_cmdline_user_args()
	var which := str(args[0]) if args.size() > 0 else "list"
	var out_dir := str(args[1]) if args.size() > 1 else "user://screenshots"
	var fixtures := _fixtures()
	if which == "list" or (which != "all" and not fixtures.has(which)):
		print("Fixtures: all, ", ", ".join(PackedStringArray(fixtures.keys())))
		quit(0 if which == "list" else 1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var names: Array = fixtures.keys() if which == "all" else [which]
	for fixture_name in names:
		await _render_fixture(str(fixture_name), fixtures[fixture_name], out_dir)
	quit(0)


func _render_fixture(fixture_name: String, snapshots: Array, out_dir: String) -> void:
	var layout := ResponsiveLayoutController.calculate_layout(Vector2(root.size))
	ResponsiveLayoutController.apply_content_scale_size(root, layout)

	var screen_layer := CanvasLayer.new()
	screen_layer.layer = 10
	var modal_layer := CanvasLayer.new()
	modal_layer.layer = 40
	root.add_child(screen_layer)
	root.add_child(modal_layer)
	var shell := RealmShellScene.instantiate() as Control
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer.add_child(shell)
	var modal_host := ModalHostScene.instantiate() as Control
	modal_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(modal_host)
	shell.modal_requested.connect(func(modal_id: StringName, payload: Dictionary) -> void:
		modal_host.call("present_modal_for_id", modal_id, shell.call("modal_scene_for", modal_id), payload))

	shell.call("set_layout", layout)
	for snap in snapshots:
		shell.call("set_snapshot", snap)
		await process_frame
	for _i in range(SETTLE_FRAMES):
		await process_frame

	var path := out_dir.path_join(fixture_name + ".png")
	var err := root.get_texture().get_image().save_png(path)
	print("SHOT %s -> %s (err=%d)" % [fixture_name, ProjectSettings.globalize_path(path), err])
	screen_layer.queue_free()
	modal_layer.queue_free()
	await process_frame


# ── Fixtures ────────────────────────────────────────────────────────────────

func _fixtures() -> Dictionary:
	var recover := { "type": "recover", "hold_progress": 1, "hold_required": 3 }
	var endure := { "type": "endure", "round": 4, "rounds_required": 8, "waves_remaining": 2 }
	return {
		"combat_pace_full":    [_combat(3, _with(recover, "pace_state", "full"))],
		"combat_pace_partial": [_combat(6, _with(recover, "pace_state", "partial"))],
		"combat_pace_none":    [_combat(9, _with(recover, "pace_state", "none"))],
		"combat_no_pace":      [_combat(4, endure)],
		"resolve_pace_win":    [_combat(6, recover),
			_resolve(true, "relic_secured", 6, "B", { "pace_state": "partial", "pace_bonus_awarded": 2, "pace_changed_rank": false })],
		"resolve_pace_win_rank_changed": [_combat(4, recover),
			_resolve(true, "relic_secured", 4, "A", { "pace_state": "full", "pace_bonus_awarded": 3, "pace_changed_rank": true })],
		"resolve_pace_win_zero": [_combat(10, recover),
			_resolve(true, "relic_secured", 10, "C", { "pace_state": "none", "pace_bonus_awarded": 0, "pace_changed_rank": false })],
		"resolve_no_pace_win": [_combat(8, endure), _resolve(true, "endured", 8, "B", {})],
		"resolve_pace_defeat": [_combat(7, recover), _resolve(false, "all_echoes_dead", 7, "F", {})],
	}


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


## An empty pace dict omits the "Pace bonus" row, as EconomyService does for a no-pace fight or a defeat.
func _resolve(victory: bool, reason: String, round_ended: int, rank: String, pace: Dictionary) -> Dictionary:
	var breakdown: Array = []
	if victory:
		breakdown.append({ "label": "2 enemies defeated", "delta": 10, "currency": "ase" })
		breakdown.append({ "label": "3 echoes survived", "delta": 15, "currency": "ase" })
		if pace.has("pace_bonus_awarded"):
			breakdown.append({ "label": "Pace bonus", "delta": int(pace["pace_bonus_awarded"]), "currency": "ase" })
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
