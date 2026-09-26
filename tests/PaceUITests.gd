extends RefCounted
class_name PaceUITests

## Pace bonus screens (docs/stories/pace-reward/design.md §6): the pace colour on the combat
## board and the result screen, the "Pace bonus" row at 0 Ase, and the rank-cause note.
## Each test mounts the real .tscn in a SubViewport so @onready nodes and authored colours exist.

const PacePresentation := preload("res://ui/components/PacePresentation.gd")
const CombatScene  := preload("res://ui/screens/combat/CombatBoardScreen.tscn")
const ResolveScene := preload("res://ui/screens/venture/ResolveScreen.tscn")
const RewardEntryScene := preload("res://ui/components/RewardEntryItem.tscn")
const PACE_STATES: Array[String] = ["full", "partial", "none"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat_ui/pace_color_on_board_per_state", Callable(PaceUITests, "_t_board_pace_color_per_state"))
	runner.register_test("combat_ui/pace_color_absent_on_no_pace_board", Callable(PaceUITests, "_t_board_no_pace_keeps_authored_color"))
	runner.register_test("combat_ui/pace_result_row_at_zero_and_round_color", Callable(PaceUITests, "_t_result_row_at_zero_and_round_color"))
	runner.register_test("combat_ui/pace_result_rank_cause_only_when_changed", Callable(PaceUITests, "_t_result_rank_cause_only_when_changed"))
	runner.register_test("combat_ui/pace_result_nothing_on_defeat_or_no_pace_win", Callable(PaceUITests, "_t_result_nothing_without_pace"))
	runner.register_test("combat_ui/pace_blend_starts_only_on_state_change", Callable(PaceUITests, "_t_blend_only_on_change"))
	runner.register_test("combat_ui/pace_blend_brightens_on_drop_and_ends_on_approved_color", Callable(PaceUITests, "_t_blend_drop_brightens_then_settles"))
	runner.register_test("combat_ui/pace_blend_absent_on_first_snapshot_and_no_pace", Callable(PaceUITests, "_t_blend_absent_first_and_no_pace"))
	runner.register_test("combat_ui/reward_row_zero_delta_muted", Callable(PaceUITests, "_t_reward_row_zero_delta_muted"))
	runner.register_test("combat_ui/pace_colors_match_approved_hex", Callable(PaceUITests, "_t_pace_colors_match_approved_hex"))


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


static func _combat_snap(objective_state: Dictionary, encounter_id: String = "pace_ui") -> Dictionary:
	return {
		"type": "flow.encounter",
		"meta": { "t": 1 },
		"data": {
			"encounter_id": encounter_id, "board_cols": 4, "board_rows": 4, "round": 3,
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


static func _recover(pace_state: String) -> Dictionary:
	return { "type": "recover", "hold_progress": 1, "hold_required": 3, "pace_state": pace_state }


## Returns "" when all three pace labels show `want`, or an error text.
static func _labels_show(screen: Node, want: Color, what: String) -> String:
	for path in ["RoundLabel", "%GlyphLabel", "%ProgressLabel"]:
		var got := _font_color(screen, path)
		if not got.is_equal_approx(want):
			return "%s: %s colour %s, expected %s" % [what, path, got, want]
	return ""


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
		# D-28: a state change blends; the check is on the colour at the end of the blend.
		(screen as CombatBoardScreen).step_pace_blend(10.0)
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


# ── Pace colour blend (decisions.md D-28) ───────────────────────────────────
# The tween is stepped by hand (CombatBoardScreen.step_pace_blend), so no frame must pass.
# Normal speed: the brightening takes 0.08 s, the blend 0.36 s (_MOVE_DURATION_NORMAL).

## An actor step with the same pace_state must not restart a running blend.
static func _t_blend_only_on_change() -> Dictionary:
	var m := _mount(CombatScene)
	var screen := m[1] as CombatBoardScreen
	var err := ""
	screen.set_snapshot(_combat_snap(_recover("full")))
	screen.set_snapshot(_combat_snap(_recover("full")))
	if screen.is_pace_blend_running():
		err = "blend runs with no state change"
	if err.is_empty():
		screen.set_snapshot(_combat_snap(_recover("partial")))
		if not screen.is_pace_blend_running():
			err = "no blend on full -> partial"
	if err.is_empty():
		screen.step_pace_blend(0.25)
		screen.set_snapshot(_combat_snap(_recover("partial")))
		if not screen.is_pace_blend_running():
			err = "same-state step stopped the blend"
	if err.is_empty():
		# 0.25 + 0.25 = 0.50 s > 0.44 s total. A restarted blend would still run here.
		screen.step_pace_blend(0.25)
		if screen.is_pace_blend_running():
			err = "same-state step restarted the blend"
	if err.is_empty():
		err = _labels_show(screen, PacePresentation.color("partial", false), "after blend")
	m[0].free()
	return { "ok": err.is_empty(), "error": err }


static func _t_blend_drop_brightens_then_settles() -> Dictionary:
	var m := _mount(CombatScene)
	var screen := m[1] as CombatBoardScreen
	var err := ""
	var full := PacePresentation.color("full", false)
	screen.set_snapshot(_combat_snap(_recover("full")))
	screen.set_snapshot(_combat_snap(_recover("partial")))
	screen.step_pace_blend(0.08)
	err = _labels_show(screen, full.lerp(Color.WHITE, 0.4), "brightening peak")
	if err.is_empty():
		screen.step_pace_blend(10.0)
		err = _labels_show(screen, PacePresentation.color("partial", false), "full -> partial end")
	if err.is_empty():
		screen.set_snapshot(_combat_snap(_recover("none")))
		screen.step_pace_blend(10.0)
		err = _labels_show(screen, PacePresentation.color("none", false), "partial -> none end")
	m[0].free()
	return { "ok": err.is_empty(), "error": err }


## D-06 / D-18: a no-pace fight never blends. A new fight shows its first colour with no blend.
static func _t_blend_absent_first_and_no_pace() -> Dictionary:
	var m := _mount(CombatScene)
	var screen := m[1] as CombatBoardScreen
	var authored := _font_color(screen, "RoundLabel")
	var err := ""
	screen.set_snapshot(_combat_snap(_recover("none"), "fight_a"))
	if screen.is_pace_blend_running():
		err = "blend on the first snapshot of a fight"
	if err.is_empty():
		err = _labels_show(screen, PacePresentation.color("none", false), "first snapshot")
	if err.is_empty():
		# A new fight on the same screen instance: the old state must not cause a blend.
		screen.set_snapshot(_combat_snap(_recover("full"), "fight_b"))
		if screen.is_pace_blend_running():
			err = "blend on the first snapshot of the next fight"
	if err.is_empty():
		screen.set_snapshot(_combat_snap(_recover("partial"), "fight_b"))
		screen.set_snapshot(_combat_snap({ "type": "endure", "round": 2, "rounds_required": 6, "waves_remaining": 1 }, "fight_c"))
		if screen.is_pace_blend_running():
			err = "blend in a no-pace fight"
		elif not _font_color(screen, "RoundLabel").is_equal_approx(authored):
			err = "no-pace fight does not show the authored round colour"
	m[0].free()
	return { "ok": err.is_empty(), "error": err }


# ── Reward row (decisions.md D-28) ──────────────────────────────────────────

static func _t_reward_row_zero_delta_muted() -> Dictionary:
	var m := _mount(ResolveScene)
	var section := (m[1] as Control).get_node("%BreakdownSection")
	var err := ""
	for delta in [0, 3, -2]:
		var item := RewardEntryScene.instantiate() as RewardEntryItem
		section.add_child(item)
		item.setup({ "label": "Pace bonus", "delta": delta, "currency": "ase" })
		var want: Color = item.color_positive
		if delta == 0:
			want = Color("#6E6450")
		elif delta < 0:
			want = item.color_negative
		var got := (item.get_node("%DeltaLabel") as Label).get_theme_color("font_color")
		if not got.is_equal_approx(want):
			err = "delta %d: colour %s, expected %s" % [delta, got, want]
			break
	m[0].free()
	return { "ok": err.is_empty(), "error": err }


# ── Approved colours (decisions.md D-25) ────────────────────────────────────

## The six PaceState* theme colours must equal the approved hex values.
## A changed theme colour must fail here, not pass through PacePresentation.color().
static func _t_pace_colors_match_approved_hex() -> Dictionary:
	# [pace_state, on_panel, approved hex]
	var approved := [
		["full", false, "#7EE3C0"], ["partial", false, "#F28C28"], ["none", false, "#E5533D"],
		["full", true, "#1D6552"], ["partial", true, "#7A4B00"], ["none", true, "#9E2F28"],
	]
	for c in approved:
		var got := PacePresentation.color(c[0], c[1])
		var want := Color(c[2])
		if got.to_html(false).to_upper() != want.to_html(false).to_upper() or not is_equal_approx(got.a, 1.0):
			return { "ok": false, "error": "%s (%s): colour #%s, expected %s" % [
				c[0], "result card" if c[1] else "combat HUD", got.to_html(true).to_upper(), c[2]] }
	return { "ok": true }
