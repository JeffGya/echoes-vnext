extends RefCounted
class_name PaceUITests

## Pace bonus screens (docs/stories/pace-reward/design.md §6): the pace colour on the combat
## board and the result screen, the "Pace bonus" row at 0 Ase, and the rank-cause note.
## Each test mounts the real .tscn in a SubViewport so @onready nodes and authored colours exist.

const PacePresentation := preload("res://ui/components/PacePresentation.gd")
const CombatScene  := preload("res://ui/screens/combat/CombatBoardScreen.tscn")
const ResolveScene := preload("res://ui/screens/venture/ResolveScreen.tscn")
const PACE_STATES: Array[String] = ["full", "partial", "none"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat_ui/pace_color_on_board_per_state", Callable(PaceUITests, "_t_board_pace_color_per_state"))
	runner.register_test("combat_ui/pace_color_absent_on_no_pace_board", Callable(PaceUITests, "_t_board_no_pace_keeps_authored_color"))
	runner.register_test("combat_ui/pace_result_row_at_zero_and_round_color", Callable(PaceUITests, "_t_result_row_at_zero_and_round_color"))
	runner.register_test("combat_ui/pace_result_rank_cause_only_when_changed", Callable(PaceUITests, "_t_result_rank_cause_only_when_changed"))
	runner.register_test("combat_ui/pace_result_nothing_on_defeat_or_no_pace_win", Callable(PaceUITests, "_t_result_nothing_without_pace"))


# ── Fixtures ────────────────────────────────────────────────────────────────

static func _mount(scene: PackedScene) -> Array:
	# The runner starts inside AppRoot._ready, while the root is busy; this host already is ready.
	var host := (Engine.get_main_loop() as SceneTree).current_scene.get_node("UISnapshotRenderer")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var screen := scene.instantiate() as Control
	viewport.add_child(screen)
	return [viewport, screen]


static func _combat_snap(objective_state: Dictionary) -> Dictionary:
	return {
		"type": "flow.encounter",
		"meta": { "t": 1 },
		"data": {
			"encounter_id": "pace_ui", "board_cols": 4, "board_rows": 4, "round": 3,
			"round_phase": "actor_turn", "combat_over": false, "actors": [],
			"objective_state": objective_state,
		},
		"actions": {},
	}


static func _resolve_snap(victory: bool, extra: Dictionary, pace_row: bool) -> Dictionary:
	var breakdown: Array = [{ "label": "2 enemies defeated", "delta": 10, "currency": "ase" }]
	if pace_row:
		breakdown.append({ "label": "Pace bonus", "delta": int(extra.get("pace_bonus_awarded", 0)), "currency": "ase" })
	var data := {
		"victory": victory, "reason": "relic_secured", "rank": "B", "ase_awarded": 10,
		"enemies_defeated": 2, "echoes_survived": 3, "round_ended": 6,
		"reward_breakdown": breakdown, "emotion_summary": [],
	}
	data.merge(extra)
	return { "type": "flow.resolve", "meta": { "t": 2 }, "data": data, "actions": {} }


static func _font_color(screen: Node, path: String) -> Color:
	return (screen.get_node(path) as Label).get_theme_color("font_color")


static func _pace_rows(screen: Node) -> Array:
	var rows: Array = []
	for child in screen.get_node("%BreakdownSection").get_children():
		if child.is_queued_for_deletion() or not (child is RewardEntryItem):
			continue
		if (child.get_node("%EntryLabel") as Label).text == "Pace bonus":
			rows.append(child)
	return rows


# ── Combat board ────────────────────────────────────────────────────────────

static func _t_board_pace_color_per_state() -> Dictionary:
	var m := _mount(CombatScene)
	var screen: Control = m[1]
	for state in PACE_STATES:
		screen.call("set_snapshot", _combat_snap({ "type": "recover", "hold_progress": 1, "hold_required": 3, "pace_state": state }))
		var want := PacePresentation.color(state, false)
		for path in ["RoundLabel", "%GlyphLabel", "%ProgressLabel"]:
			var got := _font_color(screen, path)
			if got != want:
				m[0].free()
				return { "ok": false, "error": "%s: %s colour %s, expected %s" % [state, path, got, want] }
	m[0].free()
	return { "ok": true }


## Covers the no-pace modes (D-06), the keeper-intro trial with no key (D-18), and the
## restore after a pace fight on the same screen instance.
static func _t_board_no_pace_keeps_authored_color() -> Dictionary:
	var m := _mount(CombatScene)
	var screen: Control = m[1]
	var authored := {}
	for path in ["RoundLabel", "%GlyphLabel", "%ProgressLabel"]:
		authored[path] = _font_color(screen, path)
	var no_pace_states: Array = [
		{ "type": "endure", "round": 2, "rounds_required": 6, "waves_remaining": 1 },
		{ "type": "protect", "protect_progress": 1, "protect_required": 4, "objective_hp": 9 },
		{ "type": "guide_spirit", "guide_mode": "protect" },
		{ "type": "combat" },
		{ "type": "combat", "pace_state": "" },
	]
	for obj in no_pace_states:
		screen.call("set_snapshot", _combat_snap({ "type": "recover", "hold_progress": 0, "hold_required": 2, "pace_state": "none" }))
		screen.call("set_snapshot", _combat_snap(obj))
		for path in authored:
			var got := _font_color(screen, path)
			if got != authored[path]:
				m[0].free()
				return { "ok": false, "error": "%s: %s colour %s, expected authored %s" % [obj, path, got, authored[path]] }
	m[0].free()
	return { "ok": true }


# ── Result screen ───────────────────────────────────────────────────────────

static func _t_result_row_at_zero_and_round_color() -> Dictionary:
	var m := _mount(ResolveScene)
	var screen: Control = m[1]
	screen.call("set_snapshot", _resolve_snap(true,
		{ "pace_state": "none", "pace_bonus_awarded": 0, "pace_changed_rank": false }, true))
	var rows := _pace_rows(screen)
	var ok := rows.size() == 1 and (rows[0].get_node("%DeltaLabel") as Label).text == "+0 Ase"
	var want := PacePresentation.color("none", true)
	var colored := _font_color(screen, "%RoundsValue") == want and _font_color(screen, "%RoundsKey") == want
	m[0].free()
	if not ok:
		return { "ok": false, "error": "expected one \"Pace bonus\" row showing +0 Ase, got %d rows" % rows.size() }
	if not colored:
		return { "ok": false, "error": "Rounds line does not carry the pace colour" }
	return { "ok": true }


static func _t_result_rank_cause_only_when_changed() -> Dictionary:
	var m := _mount(ResolveScene)
	var screen: Control = m[1]
	var note := screen.get_node("%RankCauseLabel") as Label
	var seen: Array = []
	for changed in [true, false, true]:
		screen.call("set_snapshot", _resolve_snap(true,
			{ "pace_state": "full", "pace_bonus_awarded": 3, "pace_changed_rank": changed }, true))
		seen.append(note.visible)
	m[0].free()
	if seen != [true, false, true]:
		return { "ok": false, "error": "rank-cause visibility %s, expected [true, false, true]" % str(seen) }
	return { "ok": true }


## D-19: a defeat shows nothing about pace, even when stray pace keys reach the screen.
## A no-pace win shows nothing either (design §6).
static func _t_result_nothing_without_pace() -> Dictionary:
	var m := _mount(ResolveScene)
	var screen: Control = m[1]
	var authored_value := _font_color(screen, "%RoundsValue")
	var authored_key := _font_color(screen, "%RoundsKey")
	var stray := { "pace_state": "full", "pace_bonus_awarded": 3, "pace_changed_rank": true }
	var cases := { "defeat": _resolve_snap(false, {}, false),
		"defeat_with_stray_keys": _resolve_snap(false, stray, false),
		"no_pace_win": _resolve_snap(true, {}, false) }
	for case_name in cases:
		screen.call("set_snapshot", _resolve_snap(true, stray, true))
		screen.call("set_snapshot", cases[case_name])
		var err := ""
		if (screen.get_node("%RankCauseLabel") as Label).visible:
			err = "rank-cause note visible"
		elif _font_color(screen, "%RoundsValue") != authored_value or _font_color(screen, "%RoundsKey") != authored_key:
			err = "Rounds line carries a pace colour"
		elif not _pace_rows(screen).is_empty():
			err = "\"Pace bonus\" row present"
		if not err.is_empty():
			m[0].free()
			return { "ok": false, "error": "%s: %s" % [case_name, err] }
	m[0].free()
	return { "ok": true }
