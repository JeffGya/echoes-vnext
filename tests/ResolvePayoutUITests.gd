extends RefCounted
class_name ResolvePayoutUITests

## Resolve card payout explanation (docs/stories/v2-payout-explanation): the earnings summary, the
## ledger groups, the (i) buttons, the tooltip and the first-time open rule. Each test mounts the
## real .tscn. Fixtures use cause ids and arbitrary deltas; no test depends on a real amount.

const PayoutCausePresentation := preload("res://ui/components/PayoutCausePresentation.gd")
const ResolveScene := preload("res://ui/screens/venture/ResolveScreen.tscn")
const MARK_SEEN := { "type": "resolve.ledger.mark_seen" }


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("payout_ui/fight_card_rows_and_total", Callable(ResolvePayoutUITests, "_t_fight_card"))
	runner.register_test("payout_ui/stage_end_card_group_total_and_ekwan_line", Callable(ResolvePayoutUITests, "_t_stage_end"))
	runner.register_test("payout_ui/mid_stage_card_has_no_stage_group_or_ekwan", Callable(ResolvePayoutUITests, "_t_mid_stage"))
	runner.register_test("payout_ui/defeat_consolation_rows_net_into_one", Callable(ResolvePayoutUITests, "_t_consolation_net"))
	runner.register_test("payout_ui/replay_absent_and_zero_echoes_row", Callable(ResolvePayoutUITests, "_t_replay_and_bonus"))
	runner.register_test("payout_ui/zero_rows_show_muted_with_button", Callable(ResolvePayoutUITests, "_t_zero_rows"))
	runner.register_test("payout_ui/cause_rows_have_48_button_others_none", Callable(ResolvePayoutUITests, "_t_buttons"))
	runner.register_test("payout_ui/tooltip_text_matches_approved_wording", Callable(ResolvePayoutUITests, "_t_wording"))
	runner.register_test("payout_ui/tooltip_opens_pins_and_closes", Callable(ResolvePayoutUITests, "_t_tooltip_rules"))
	runner.register_test("payout_ui/tooltip_closes_on_tap_outside", Callable(ResolvePayoutUITests, "_t_tap_outside"))
	runner.register_test("payout_ui/ledger_emit_per_result_not_per_render", Callable(ResolvePayoutUITests, "_t_two_results"))
	runner.register_test("payout_ui/ledger_opens_once_when_unseen", Callable(ResolvePayoutUITests, "_t_first_time_open"))
	runner.register_test("payout_ui/ledger_closed_when_seen_or_key_absent", Callable(ResolvePayoutUITests, "_t_seen_or_absent"))
	runner.register_test("payout_ui/any_subset_of_rows_renders", Callable(ResolvePayoutUITests, "_t_any_subset"))
	runner.register_test("payout_ui/midstage_card_has_no_ase_text_or_ledger", Callable(ResolvePayoutUITests, "_t_midstage_no_ase"))
	runner.register_test("payout_ui/midstage_lines_appear_only_with_data", Callable(ResolvePayoutUITests, "_t_midstage_lines"))
	runner.register_test("payout_ui/home_sequence_final_state_with_lost_name_once", Callable(ResolvePayoutUITests, "_t_home_final"))
	runner.register_test("payout_ui/home_sequence_all_home_has_no_lost_line_or_label", Callable(ResolvePayoutUITests, "_t_home_all"))
	runner.register_test("payout_ui/home_sequence_motion_skips_on_tap_and_never_blocks", Callable(ResolvePayoutUITests, "_t_home_motion_skip"))
	runner.register_test("payout_ui/carried_ekwan_line_on_scout_return", Callable(ResolvePayoutUITests, "_t_carried_ekwan"))
	runner.register_test("payout_ui/ledger_waits_for_home_sequence_then_emits_once", Callable(ResolvePayoutUITests, "_t_ledger_after_sequence"))
	runner.register_test("payout_ui/ledger_opens_at_once_on_skip_reduced_motion_or_no_sequence", Callable(ResolvePayoutUITests, "_t_ledger_at_once"))
	runner.register_test("payout_ui/new_snapshot_mid_sequence_drops_old_emit", Callable(ResolvePayoutUITests, "_t_ledger_new_snapshot"))
	runner.register_test("payout_ui/carried_line_absent_at_zero_present_with_comparator", Callable(ResolvePayoutUITests, "_t_carried_panel"))
	runner.register_test("payout_ui/return_home_modal_carries_only_on_success", Callable(ResolvePayoutUITests, "_t_return_modal"))
	runner.register_test("payout_ui/retreat_button_price_affordable_and_denied", Callable(ResolvePayoutUITests, "_t_retreat_button"))
	runner.register_test("payout_ui/carried_scenes_hold_no_amount_text", Callable(ResolvePayoutUITests, "_t_carried_no_amounts"))
	runner.register_test("payout_ui/unknown_cause_shows_no_button", Callable(ResolvePayoutUITests, "_t_unknown_cause"))
	runner.register_test("payout_ui/other_cards_keep_working", Callable(ResolvePayoutUITests, "_t_other_cards"))
	runner.register_test("payout_ui/effects_rail_has_no_ase_ekwan_or_defeated_chip", Callable(ResolvePayoutUITests, "_t_rail_chips"))
	runner.register_test("payout_ui/scenes_hold_no_amount_text", Callable(ResolvePayoutUITests, "_t_no_hard_coded_amounts"))


# ── Fixtures ────────────────────────────────────────────────────────────────

static func _mount() -> Array:
	var host := (Engine.get_main_loop() as SceneTree).current_scene.get_node("UISnapshotRenderer")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var screen := ResolveScene.instantiate() as ResolveScreen
	viewport.add_child(screen)
	return [viewport, screen]


static func _row(label: String, delta: int, cause: String, params: Dictionary = {}) -> Dictionary:
	var row := { "label": label, "delta": delta, "currency": "ase" }
	if not cause.is_empty():
		row["cause"] = cause
		row["params"] = params
	return row


static func _snap(rows: Array, extra: Dictionary = {}, victory: bool = true) -> Dictionary:
	var total := 0
	for row in rows:
		total += int(row["delta"])
	var data := {
		"victory": victory, "reason": "all_enemies_defeated", "rank": "B", "ase_awarded": total,
		"ekwan_awarded": 0, "enemies_defeated": 2, "echoes_survived": 3, "round_ended": 5,
		"reward_breakdown": rows, "emotion_summary": [],
	}
	data.merge(extra, true)
	return { "type": "flow.resolve", "meta": { "t": 2 }, "data": data, "actions": {} }


static func _rows_in(screen: Node, section: String) -> Array:
	var out: Array = []
	for child in screen.get_node(section).get_children():
		if child is RewardEntryItem and not child.is_queued_for_deletion():
			out.append(child)
	return out


static func _names(rows: Array) -> Array:
	return rows.map(func(r: RewardEntryItem) -> String: return r.entry_label.text)


static func _fail(m: Array, error: String) -> Dictionary:
	m[0].free()
	return { "ok": false, "error": error }


static func _pass(m: Array) -> Dictionary:
	m[0].free()
	return { "ok": true }


static func _label(screen: Node, path: String) -> Label:
	return screen.get_node(path) as Label


# ── Tests ───────────────────────────────────────────────────────────────────

static func _t_fight_card() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var rows := [
		_row("Carried", 11, "partial_return_home"),
		_row("Redo penalty", -3, "replay", { "factor": 0.35 }),
	]
	screen.set_snapshot(_snap(rows, { "ledger_seen": true }, false))
	var shown := _rows_in(screen, "%BreakdownSection")
	if shown.size() != 2:
		return _fail(m, "expected 2 fight rows, got %d" % shown.size())
	if _names(shown) != ["Carried home", "Replay"]:
		return _fail(m, "row names %s" % str(_names(shown)))
	if _label(screen, "%AseTotalLabel").text != "+8 Ase" or _label(screen, "%TotalValue").text != "= 8 Ase":
		return _fail(m, "totals %s / %s" % [_label(screen, "%AseTotalLabel").text, _label(screen, "%TotalValue").text])
	if screen.get_node("%StageGroup").visible:
		return _fail(m, "stage group visible on a fight card")
	return _pass(m)


static func _t_stage_end() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var stage := [
		_row("Base objectives", 40, "objectives_overcome", { "overcome": 2, "total": 3 }),
		_row("Redo penalty", -4, "replay", { "factor": 0.9 }),
		_row("Echoes home", 6, "echoes_alive", { "alive": 2, "started": 3, "lost": ["Kofi"], "cap": 10, "replay": false }),
		_row("Carried home", -12, "carried_advance", { "carried_ase": 12, "carried_ekwan": 2 }),
	]
	screen.set_snapshot(_snap([], {
		"ledger_seen": true, "stage_payout_rows": stage, "stage_payout_ase": 30, "stage_payout_ekwan": 6 }))
	var stage_rows := _rows_in(screen, "%StageSection")
	if stage_rows.size() != 4 or not screen.get_node("%StageGroup").visible:
		return _fail(m, "stage group does not show the 4 stage rows")
	if (stage_rows[2] as RewardEntryItem).note_label.text != "Kofi did not come home." \
			or not (stage_rows[2] as RewardEntryItem).note_label.visible:
		return _fail(m, "lost-name note missing: %s" % (stage_rows[2] as RewardEntryItem).note_label.text)
	var carried: RewardEntryItem = stage_rows[3]
	if carried.delta_label.text != "\u221212 Ase" or carried.entry_label.text != "Carried home":
		return _fail(m, "carried row is %s / %s" % [carried.entry_label.text, carried.delta_label.text])
	if _label(screen, "%TotalValue").text != "= 30 Ase" or _label(screen, "%AseTotalLabel").text != "+30 Ase":
		return _fail(m, "total is not ase_awarded + stage_payout_ase")
	var line := screen.get_node("%EkwanLine") as Control
	if not line.visible or _label(screen, "%EkwanLineValue").text != "+6 Ekwan":
		return _fail(m, "Ekwan earned line missing or wrong")
	if not line.find_children("*", "Button", true, false).is_empty():
		return _fail(m, "Ekwan line has a button")
	if not _label(screen, "%EkwanTotalLabel").visible or _label(screen, "%EkwanTotalLabel").text != "+6 Ekwan":
		return _fail(m, "summary line misses the Ekwan amount")
	var replay: RewardEntryItem = _rows_in(screen, "%StageSection")[1]
	if replay.scope != "stage":
		return _fail(m, "stage rows must carry the stage scope")
	return _pass(m)


static func _t_mid_stage() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var sent: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	# A fight win pays nothing and has no rows: no earnings line, no ledger, no mark_seen.
	screen.set_snapshot(_snap([], { "ledger_seen": false }))
	if (screen.get_node("%EarningsSummary") as Control).visible or (screen.get_node("%Ledger") as Control).visible \
			or not sent.is_empty():
		return _fail(m, "a rowless win shows earnings or emitted (%d)" % sent.size())
	if (screen.get_node("%FightHeader") as Control).visible:
		return _fail(m, "a rowless win must show the Direction E card, not the chips")
	if screen.get_node("%StageGroup").visible or screen.get_node("%EkwanLine").visible \
			or screen.get_node("%EkwanTotalLabel").visible or screen.get_node("%FightGroupHeader").visible:
		return _fail(m, "stage group, Ekwan or group header visible on a mid-stage card")
	# A stage card whose Ekwan is 0 shows no Ekwan either.
	screen.set_snapshot(_snap([], {
		"ledger_seen": true, "stage_payout_ase": 5, "stage_payout_ekwan": 0,
		"stage_payout_rows": [_row("Base objectives", 5, "objectives_overcome", { "overcome": 1, "total": 2 })] }))
	if screen.get_node("%EkwanLine").visible or screen.get_node("%EkwanTotalLabel").visible:
		return _fail(m, "Ekwan shown while stage_payout_ekwan is 0")
	return _pass(m)


static func _t_consolation_net() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var rows := [
		_row("Base objectives", 13, "defeat_consolation", { "part": "base" }),
		_row("Defeat penalty", -9, "defeat_consolation", { "part": "penalty" }),
		_row("Redo penalty", -1, "replay", { "factor": 0.9 }),
	]
	screen.set_snapshot(_snap(rows, { "ledger_seen": true }, false))
	var shown := _rows_in(screen, "%BreakdownSection")
	if _names(shown) != ["Consolation", "Replay"]:
		return _fail(m, "row names %s" % str(_names(shown)))
	var net: RewardEntryItem = shown[0]
	if net.delta_label.text != "+4 Ase" or net.cause != "defeat_consolation" or not net.cause_button.visible:
		return _fail(m, "net row is %s / %s" % [net.delta_label.text, net.cause])
	return _pass(m)


static func _t_replay_and_bonus() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var stage := [
		_row("Base objectives", 7, "objectives_overcome", { "overcome": 1, "total": 2 }),
		_row("Echoes home", 0, "echoes_alive", { "alive": 0, "started": 2, "lost": ["Ama", "Kofi"], "cap": 10 }),
	]
	screen.set_snapshot(_snap([], { "ledger_seen": true, "stage_payout_rows": stage, "stage_payout_ase": 7 }))
	var shown := _rows_in(screen, "%StageSection")
	if "Replay" in _names(shown):
		return _fail(m, "Replay row present without a replay cause")
	var home: RewardEntryItem = shown[1]
	if home.entry_label.text != "Echoes home" or home.delta_label.text != "+0 Ase" or not home.cause_button.visible:
		return _fail(m, "echoes row %s %s" % [home.entry_label.text, home.delta_label.text])
	if home.note_label.text != "Ama and Kofi did not come home.":
		return _fail(m, "lost names note: %s" % home.note_label.text)
	if not home.delta_label.get_theme_color("font_color").is_equal_approx(home.color_zero) \
			or not home.entry_label.get_theme_color("font_color").is_equal_approx(home.color_zero):
		return _fail(m, "zero echoes row is not muted")
	return _pass(m)


static func _t_zero_rows() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	for cause in ["nothing_overcome_yet", "repeat_defeat"]:
		screen.set_snapshot(_snap([_row("Backend label", 0, cause)], { "ledger_seen": true }, false))
		var shown := _rows_in(screen, "%BreakdownSection")
		if shown.size() != 1:
			return _fail(m, "%s: expected 1 row" % cause)
		var row: RewardEntryItem = shown[0]
		if not row.cause_button.visible or not row.delta_label.get_theme_color("font_color").is_equal_approx(row.color_zero):
			return _fail(m, "%s: row not muted or no button" % cause)
		row.cause_button.pressed.emit()
		var tip := screen.get_node("%CauseTooltip") as CauseTooltip
		if not tip.is_open() or (tip.get_node("%BodyLabel") as Label).text != PayoutCausePresentation.tooltip(cause):
			return _fail(m, "%s: tooltip wrong" % cause)
	return _pass(m)


static func _t_buttons() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_snap([
		_row("Found", 4, ""),
		_row("Carried", 7, "partial_return_home"),
		_row("Redo penalty", -3, "replay", { "factor": 0.35 }),
	], { "ledger_seen": true }))
	for row in _rows_in(screen, "%BreakdownSection"):
		var r: RewardEntryItem = row
		var want := r.cause != ""
		var size := r.cause_button.get_combined_minimum_size()
		if r.cause_button.visible != want or r.cause_spacer.visible == want:
			return _fail(m, "%s: button/spacer visibility wrong" % r.entry_label.text)
		if want and (size.x < 48.0 or size.y < 48.0):
			return _fail(m, "%s: button %s is under 48x48" % [r.entry_label.text, str(size)])
		if r.cause_spacer.custom_minimum_size.x != r.cause_button.custom_minimum_size.x:
			return _fail(m, "spacer width differs from button width")
	return _pass(m)


## The approved wording, written out here on purpose: a changed sentence must fail this test.
static func _t_wording() -> Dictionary:
	var want := {
		"echoes_alive": "Each Echo that comes home earns Ase.",
		"carried_advance": "Ase and Ekwan the party carried home earlier are taken off the stage payout, so nothing is earned twice.",
		"defeat_consolation": "The party lost, but the fight still earns a small part.",
		"partial_retreat": "The party left early. It keeps a small part of what it overcame.",
		"partial_return_home": "The party left early. It keeps a small part of what it overcame.",
		"nothing_overcome_yet": "The party has not overcome anything yet. Nothing is earned.",
		"repeat_defeat": "The party already earned the consolation for this. Another loss earns nothing.",
	}
	for cause in want:
		if PayoutCausePresentation.tooltip(cause) != want[cause]:
			return { "ok": false, "error": "%s: \"%s\"" % [cause, PayoutCausePresentation.tooltip(cause)] }
	var replay_fight := PayoutCausePresentation.tooltip("replay", {}, "fight")
	var replay_stage := PayoutCausePresentation.tooltip("replay", {}, "stage")
	if replay_fight != "The party has been here before. It earns less.":
		return { "ok": false, "error": "replay (fight): \"%s\"" % replay_fight }
	if replay_stage != "The party has been here before. The whole stage earns less Ase and Ekwan.":
		return { "ok": false, "error": "replay (stage): \"%s\"" % replay_stage }
	var objectives := PayoutCausePresentation.tooltip("objectives_overcome", { "overcome": 4, "total": 7 })
	if objectives != "Only objectives the party found and overcame earn Ase. 4 of 7 so far.":
		return { "ok": false, "error": "objectives: \"%s\"" % objectives }
	var names := { "replay": "Replay", "defeat_consolation": "Consolation", "partial_retreat": "Carried home",
		"partial_return_home": "Carried home", "objectives_overcome": "Objectives overcome",
		"echoes_alive": "Echoes home", "carried_advance": "Carried home" }
	for cause in names:
		if PayoutCausePresentation.row_name(cause, "x") != names[cause]:
			return { "ok": false, "error": "row name of %s" % cause }
	# Removed causes: no entry, so a stray row keeps its backend label and shows no (i).
	for cause in ["enemies_defeated", "realm_virtue", "bonus_earned", "bonus_missed"]:
		if PayoutCausePresentation.has_cause(cause) or PayoutCausePresentation.row_name(cause, "Label") != "Label":
			return { "ok": false, "error": "%s still has an entry" % cause }
	if PayoutCausePresentation.row_note("echoes_alive", { "lost": ["Ama", "Kofi", "Esi"] }) != "Ama, Kofi and Esi did not come home.":
		return { "ok": false, "error": "three lost names note" }
	if PayoutCausePresentation.row_note("echoes_alive", { "lost": [] }) != "":
		return { "ok": false, "error": "a note shows with no lost Echo" }
	return { "ok": true }


static func _t_tooltip_rules() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_snap([
		_row("Carried", 7, "partial_return_home"),
		_row("Realm virtue", 3, "realm_virtue"),
	], { "ledger_seen": true }))
	var tip := screen.get_node("%CauseTooltip") as CauseTooltip
	var first: RewardEntryItem = _rows_in(screen, "%BreakdownSection")[0]
	var button := first.cause_button
	button.mouse_entered.emit()
	if not tip.is_open() or tip.is_pinned() or (tip.get_node("%TitleLabel") as Label).text != "Carried home":
		return _fail(m, "hover did not open an unpinned tooltip with the row name")
	button.mouse_exited.emit()
	if tip.is_open():
		return _fail(m, "hover end did not close an unpinned tooltip")
	button.pressed.emit()
	button.mouse_exited.emit()
	if not tip.is_open() or not tip.is_pinned():
		return _fail(m, "a tap did not pin the tooltip through a mouse exit")
	button.pressed.emit()
	if tip.is_open():
		return _fail(m, "a second tap did not close the tooltip")
	button.focus_entered.emit()
	if not tip.is_open():
		return _fail(m, "focus did not open the tooltip")
	var rect := Rect2(tip.global_position, (tip.get_node("%Panel") as Control).size)
	if not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect):
		return _fail(m, "tooltip %s is outside the screen" % str(rect))
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	tip._input(esc)
	if tip.is_open():
		return _fail(m, "Esc did not close the tooltip")
	button.pressed.emit()
	screen.set_snapshot(_snap([], { "ledger_seen": true }))
	if tip.is_open():
		return _fail(m, "a new snapshot left the tooltip open")
	return _pass(m)


## The screen lives in a SubViewport, so real root-window input cannot reach it (AGENTS.md rule 29
## covers root-window input). The test calls the tooltip's input handler with a real mouse event.
static func _t_tap_outside() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_snap([_row("Carried", 7, "partial_return_home")], { "ledger_seen": true }))
	var tip := screen.get_node("%CauseTooltip") as CauseTooltip
	var button: Button = (_rows_in(screen, "%BreakdownSection")[0] as RewardEntryItem).cause_button
	button.global_position = Vector2(600, 300)
	button.size = Vector2(48, 48)
	button.pressed.emit()
	if not tip.is_open():
		return _fail(m, "tooltip did not open")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = Vector2(5, 5)
	tap.global_position = Vector2(5, 5)
	tip._input(tap)
	if tip.is_open():
		return _fail(m, "a tap outside did not close the tooltip")
	return _pass(m)


## One mark_seen per new result; a re-render of the same result never emits again.
static func _t_two_results() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var sent: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	var first := [_row("Carried", 7, "partial_return_home")]
	var second := [_row("Carried", 9, "partial_return_home")]
	screen.set_snapshot(_snap(first, { "ledger_seen": false }))
	screen.set_snapshot(_snap(first, { "ledger_seen": true }))
	if sent.size() != 1 or not screen.get_node("%Ledger").visible:
		return _fail(m, "first result: %d emits, ledger open=%s" % [sent.size(), screen.get_node("%Ledger").visible])
	(screen.get_node("%EarningsSummary") as Button).pressed.emit()
	screen.set_snapshot(_snap(first, { "ledger_seen": true }))
	if sent.size() != 1 or screen.get_node("%Ledger").visible:
		return _fail(m, "same result re-render changed the ledger or emitted again")
	screen.set_snapshot(_snap(second, { "ledger_seen": false }))
	if sent != [MARK_SEEN, MARK_SEEN] or not screen.get_node("%Ledger").visible:
		return _fail(m, "second result: %d emits, ledger open=%s" % [sent.size(), screen.get_node("%Ledger").visible])
	return _pass(m)


static func _t_first_time_open() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var sent: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	var rows := [_row("Carried", 7, "partial_return_home")]
	screen.set_snapshot(_snap(rows, { "ledger_seen": false }))
	if not screen.get_node("%Ledger").visible:
		return _fail(m, "ledger closed on an unseen result")
	if sent != [MARK_SEEN]:
		return _fail(m, "expected one mark_seen action, got %s" % str(sent))
	# The host patches ledger_seen and re-renders the same result: the ledger stays, no second emit.
	screen.set_snapshot(_snap(rows, { "ledger_seen": true }))
	if not screen.get_node("%Ledger").visible or sent.size() != 1:
		return _fail(m, "re-render closed the ledger or emitted again (%d emits)" % sent.size())
	# The player closes it; another re-render keeps it closed.
	(screen.get_node("%EarningsSummary") as Button).pressed.emit()
	screen.set_snapshot(_snap(rows, { "ledger_seen": true }))
	if screen.get_node("%Ledger").visible:
		return _fail(m, "re-render reopened a ledger the player closed")
	return _pass(m)


static func _t_seen_or_absent() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var sent: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	var rows := [_row("Carried", 7, "partial_return_home")]
	screen.set_snapshot(_snap(rows, { "ledger_seen": true }))
	var seen_open: bool = screen.get_node("%Ledger").visible
	var m2 := _mount()
	var screen2: ResolveScreen = m2[1]
	screen2.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	screen2.set_snapshot(_snap(rows))
	var absent_open: bool = screen2.get_node("%Ledger").visible
	m2[0].free()
	if seen_open or absent_open or not sent.is_empty():
		return _fail(m, "seen open=%s, absent open=%s, emits=%d" % [seen_open, absent_open, sent.size()])
	# The player can open it, and the summary shows the chevron change.
	(screen.get_node("%EarningsSummary") as Button).pressed.emit()
	if not screen.get_node("%Ledger").visible:
		return _fail(m, "summary button did not open the ledger")
	return _pass(m)


## Rows come from the data only: an empty fight group, stage rows alone, or no rows at all must render.
static func _t_any_subset() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var stage := [_row("Base", 8, "objectives_overcome", { "overcome": 1, "total": 2 })]
	screen.set_snapshot(_snap([], { "ledger_seen": true, "ase_awarded": 0, "stage_payout_rows": stage, "stage_payout_ase": 8 }))
	if not _rows_in(screen, "%BreakdownSection").is_empty() or _rows_in(screen, "%StageSection").size() != 1:
		return _fail(m, "stage-only card rows wrong")
	if screen.get_node("%FightGroupHeader").visible or _label(screen, "%TotalValue").text != "= 8 Ase":
		return _fail(m, "stage-only card header or total wrong")
	screen.set_snapshot(_snap([], { "ledger_seen": false, "ase_awarded": 0 }))
	var summary := screen.get_node("%EarningsSummary") as Button
	if summary.visible or screen.get_node("%Ledger").visible:
		return _fail(m, "an empty card must show no earnings line and no ledger")
	return _pass(m)


static func _t_unknown_cause() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_snap([_row("Mystery", 5, "not_a_real_cause", { "x": 1 })], { "ledger_seen": true }))
	var shown := _rows_in(screen, "%BreakdownSection")
	if shown.size() != 1 or shown[0].cause_button.visible or shown[0].entry_label.text != "Mystery":
		return _fail(m, "unknown cause row wrong")
	if PayoutCausePresentation.tooltip("not_a_real_cause") != "":
		return _fail(m, "unknown cause has tooltip text")
	return _pass(m)


## Scout return, forced retreat, contact and situation cards share the renderer.
static func _t_other_cards() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot({ "type": "flow.resolve", "meta": { "t": 3 }, "actions": {}, "data": {
		"run_type": "scout_return", "intel_count": 1, "ase_awarded": 6, "ledger_seen": true,
		"reward_breakdown": [_row("Carried", 6, "partial_return_home")], "actors": [] } })
	if not (screen.get_node("%EarningsSummary") as Button).visible or _label(screen, "%AseTotalLabel").text != "+6 Ase":
		return _fail(m, "scout return lost its earnings summary")
	if (screen.get_node("%FightHeader") as Control).visible:
		return _fail(m, "scout return shows the fight strip")
	screen.set_snapshot({ "type": "flow.resolve", "meta": { "t": 4 }, "actions": {}, "data": {
		"run_type": "contact_result", "outcome": "good", "role_label": "Elder", "outcome_text": "Done." } })
	if (screen.get_node("%EarningsSummary") as Button).visible or (screen.get_node("%Ledger") as Control).visible \
			or (screen.get_node("%FightHeader") as Control).visible:
		return _fail(m, "contact card shows payout parts")
	screen.set_snapshot({ "type": "flow.resolve", "meta": { "t": 5 }, "actions": {}, "data": {
		"run_type": "situation_result", "surface": "shrine", "verdict": "passed", "emotion_summary": [] } })
	if (screen.get_node("%EarningsSummary") as Button).visible or not (screen.get_node("%RankChip") as Control).visible \
			or (screen.get_node("%EnemiesChip") as Control).visible:
		return _fail(m, "situation card shows wrong chips")
	screen.set_snapshot(_snap([_row("Carried", 7, "partial_return_home")], { "ledger_seen": true }))
	if not (screen.get_node("%EnemiesChip") as Control).visible or _label(screen, "%EnemiesDefeatedValue").text != "2" \
			or _label(screen, "%EchoesAliveValue").text != "3" or _label(screen, "%RoundsValue").text != "5" \
			or _label(screen, "%RankBadge").text != "B":
		return _fail(m, "fight strip values wrong after other cards")
	return _pass(m)


static func _t_rail_chips() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_snap([_row("Carried", 7, "partial_return_home")], {
		"ledger_seen": true, "ekwan_awarded": 5, "effects": [{ "kind": "item", "label": "Gourd", "tone": "good" }] }))
	var rail := screen.get_node("%EffectsRail")
	var texts: Array = []
	for chip in rail.get_children():
		if not chip.is_queued_for_deletion():
			texts.append((chip.get_node("%ChipLabel") as Label).text)
	if texts != ["Gourd"]:
		return _fail(m, "effects rail chips %s, expected only the item chip" % str(texts))
	return _pass(m)


static func _t_no_hard_coded_amounts() -> Dictionary:
	var pattern := RegEx.create_from_string("text = \"[^\"]*[0-9]+\\s*(Ase|Ekwan)")
	var id_pattern := RegEx.create_from_string("text = \"[^\"]*(_id|\\bid\\b)")
	for path in ["res://ui/screens/venture/ResolveScreen.tscn", "res://ui/components/RewardEntryItem.tscn",
			"res://ui/components/CauseTooltip.tscn"]:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			return { "ok": false, "error": "cannot read %s" % path }
		if pattern.search(text) != null:
			return { "ok": false, "error": "%s has an amount in a text value" % path }
		if id_pattern.search(text) != null:
			return { "ok": false, "error": "%s has an id in a text value" % path }
	return { "ok": true }


# ── Direction E ─────────────────────────────────────────────────────────────

static func _actor(who: String, faction: String = "echo", extra: Dictionary = {}) -> Dictionary:
	var a := { "id": "id_" + who, "name": who, "faction": faction, "status": "alive" }
	a.merge(extra, true)
	return a


static func _summary(who: String, tag: String = "", direction: String = "steady") -> Dictionary:
	return { "echo_id": "id_" + who, "name": who, "pre_emotional_status": "grounded",
		"post_emotional_status": "grounded", "direction": direction, "tag": tag }


## Mid-stage win: three Echoes in the party, all alive, plus an ally and a spirit that do not count.
static func _midstage(extra: Dictionary = {}) -> Dictionary:
	var data := { "ledger_seen": true, "echoes_survived": 3,
		"actors": [_actor("Ama"), _actor("Kofi"), _actor("Esi"),
			_actor("Yaw", "echo", { "is_ally": true }), _actor("Nana", "echo", { "is_spirit": true })],
		"emotion_summary": [_summary("Ama"), _summary("Kofi"), _summary("Esi")] }
	data.merge(extra, true)
	return _snap([], data)


static func _visible_texts(root: Node) -> Array:
	var out: Array = []
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).is_visible_in_tree() and not (node as Label).text.is_empty():
			out.append((node as Label).text)
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree() and not (node as Button).text.is_empty():
			out.append((node as Button).text)
	return out


static func _set_reduced(value: bool) -> bool:
	var before: bool = StopMarkMotion.reduced
	StopMarkMotion.reduced = value
	return before


static func _t_midstage_no_ase() -> Dictionary:
	var before := _set_reduced(true)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_midstage({ "ledger_seen": false, "ase_awarded": 0, "ekwan_awarded": 0 }))
	var sent_ledger: bool = (screen.get_node("%Ledger") as Control).visible
	var summary_visible: bool = (screen.get_node("%EarningsSummary") as Control).visible
	var texts := _visible_texts(screen)
	StopMarkMotion.reduced = before
	if sent_ledger or summary_visible:
		return _fail(m, "mid-stage card shows the ledger or the earnings line")
	for t in texts:
		if "Ase" in str(t) or "Ekwan" in str(t) or " of " in str(t):
			return _fail(m, "mid-stage card shows \"%s\"" % t)
	return _pass(m)


static func _t_midstage_lines() -> Dictionary:
	var before := _set_reduced(true)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var change := screen.get_node("%ChangeLine") as Label
	var intel := screen.get_node("%IntelLine") as Label
	var thread := screen.get_node("%ThreadLine") as Label
	var err := ""
	# No event, no intel field: only the Thread line shows.
	screen.set_snapshot(_midstage())
	if change.visible or intel.visible or not thread.visible or thread.text != PayoutCausePresentation.THREAD_WHOLE:
		err = "plain win: change=%s intel=%s thread=%s" % [change.visible, intel.visible, thread.visible]
	# A shaken Echo gives the change line. intel_gained gives the intel line.
	if err.is_empty():
		screen.set_snapshot(_midstage({ "intel_gained": 2,
			"emotion_summary": [_summary("Ama"), _summary("Kofi", "", "fall"), _summary("Esi")] }))
		if change.text != "Kofi was shaken." or not intel.visible or intel.text != PayoutCausePresentation.INTEL_LEARNED:
			err = "event win: change \"%s\", intel visible %s" % [change.text, intel.visible]
	# Two Echoes held back: one line, both names.
	if err.is_empty():
		screen.set_snapshot(_midstage({ "emotion_summary": [_summary("Ama", "refused"), _summary("Kofi", "refused")] }))
		if change.text != "Ama and Kofi held back.":
			err = "two refused: \"%s\"" % change.text
	# A fallen Echo: the Thread line is gone, and cannot come back with the same snapshot.
	if err.is_empty():
		screen.set_snapshot(_midstage({ "echoes_survived": 2, "emotion_summary": [_summary("Ama"), _summary("Kofi", "ko")] }))
		if thread.visible or change.text != "Kofi fell.":
			err = "fallen Echo: thread visible %s, change \"%s\"" % [thread.visible, change.text]
	# No party data: no Thread line (nothing is claimed).
	if err.is_empty():
		screen.set_snapshot(_snap([], { "ledger_seen": true, "echoes_survived": 3, "emotion_summary": [] }))
		if thread.visible or change.visible or intel.visible or (screen.get_node("%StoryLines") as Control).visible:
			err = "a win without data shows story lines"
	StopMarkMotion.reduced = before
	if not err.is_empty():
		return _fail(m, err)
	return _pass(m)


## Stage-ending card: 4 started, 3 home, Kofi lost.
static func _stage_home(lost: Array, alive: int, started: int) -> Dictionary:
	var names := ["Ama", "Kofi", "Esi", "Yaw"]
	var actors: Array = []
	var summary: Array = []
	for n in names.slice(0, started):
		actors.append(_actor(n))
		summary.append(_summary(n))
	var rows := [
		_row("Base objectives", 20, "objectives_overcome", { "overcome": 2, "total": 3 }),
		_row("Echoes home", 2 * alive, "echoes_alive", { "alive": alive, "started": started, "lost": lost, "cap": 10 }),
	]
	return _snap([], { "ledger_seen": true, "echoes_survived": alive, "actors": actors, "emotion_summary": summary,
		"stage_payout_rows": rows, "stage_payout_ase": 20 + 2 * alive, "stage_payout_ekwan": 0 })


static func _t_home_final() -> Dictionary:
	var before := _set_reduced(true)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_stage_home(["Kofi"], 3, 4))
	var count := _label(screen, "%HomeCountLabel")
	var texts := _visible_texts(screen)
	var running: bool = screen.is_motion_running()
	StopMarkMotion.reduced = before
	if running:
		return _fail(m, "reduced motion must not start a sequence")
	if not count.visible or count.text != "home 3 of 4":
		return _fail(m, "count is \"%s\"" % count.text)
	var lost_lines := texts.filter(func(t: Variant) -> bool: return "did not come home" in str(t))
	if lost_lines != ["Kofi did not come home."]:
		return _fail(m, "lost name lines: %s" % str(lost_lines))
	var homes := texts.filter(func(t: Variant) -> bool: return str(t) == "home")
	if homes.size() != 3:
		return _fail(m, "expected 3 home marks, got %d" % homes.size())
	if (screen.get_node("%EchoesChip") as Control).visible:
		return _fail(m, "the Echoes alive chip must give way to the home sequence")
	for t in texts:
		if "perfect" in str(t).to_lower() or "\u2212" in str(t) and "Echo" in str(t):
			return _fail(m, "forbidden text \"%s\"" % t)
	return _pass(m)


static func _t_home_all() -> Dictionary:
	var before := _set_reduced(true)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_stage_home([], 4, 4))
	var texts := _visible_texts(screen)
	StopMarkMotion.reduced = before
	if _label(screen, "%HomeCountLabel").text != "home 4 of 4":
		return _fail(m, "count is \"%s\"" % _label(screen, "%HomeCountLabel").text)
	for t in texts:
		if "did not come home" in str(t) or "perfect" in str(t).to_lower() or "flawless" in str(t).to_lower():
			return _fail(m, "all-home card shows \"%s\"" % t)
	return _pass(m)


static func _t_home_motion_skip() -> Dictionary:
	var before := _set_reduced(false)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_stage_home(["Kofi"], 3, 4))
	var err := ""
	var count := _label(screen, "%HomeCountLabel")
	var ase := _label(screen, "%AseTotalLabel")
	if not screen.is_motion_running() or count.text != "home 0 of 4" or ase.modulate.a != 0.0:
		err = "motion start: running=%s count=%s ase alpha=%s" % [screen.is_motion_running(), count.text, ase.modulate.a]
	# The footer stays usable while the motion runs.
	if err.is_empty():
		var sanctum := screen.get_node("%SanctumButton") as Button
		var next := screen.get_node("%NextStageButton") as Button
		sanctum.visible = true
		if sanctum.disabled or sanctum.mouse_filter == Control.MOUSE_FILTER_IGNORE or next.disabled:
			err = "footer buttons are blocked during the motion"
	if err.is_empty():
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		screen._input(tap)
		if screen.is_motion_running() or count.text != "home 3 of 4" or ase.modulate.a != 1.0:
			err = "a tap did not reach the final state: count=%s alpha=%s" % [count.text, ase.modulate.a]
	if err.is_empty():
		var lost_lines := _visible_texts(screen).filter(func(t: Variant) -> bool: return "did not come home" in str(t))
		if lost_lines != ["Kofi did not come home."]:
			err = "lost lines after skip: %s" % str(lost_lines)
	# A new snapshot ends the old motion.
	if err.is_empty():
		screen.set_snapshot(_stage_home([], 4, 4))
		if not screen.is_motion_running():
			err = "a new stage card must start its own motion"
		screen.set_snapshot(_snap([], { "ledger_seen": true }))
		if screen.is_motion_running():
			err = "motion survived a new snapshot"
	StopMarkMotion.reduced = before
	if not err.is_empty():
		return _fail(m, err)
	return _pass(m)


static func _t_carried_ekwan() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot({ "type": "flow.resolve", "meta": { "t": 3 }, "actions": {}, "data": {
		"run_type": "scout_return", "intel_count": 1, "ase_awarded": 0, "ekwan_awarded": 3, "ledger_seen": true,
		"reward_breakdown": [], "actors": [] } })
	var line := screen.get_node("%EkwanLine") as Control
	if not line.visible or _label(screen, "%EkwanLineValue").text != "+3 Ekwan":
		return _fail(m, "carried Ekwan line missing")
	if not line.find_children("*", "Button", true, false).is_empty():
		return _fail(m, "Ekwan line has a button")
	if not (screen.get_node("%EarningsSummary") as Control).visible:
		return _fail(m, "summary hidden while Ekwan is carried")
	screen.set_snapshot({ "type": "flow.resolve", "meta": { "t": 4 }, "actions": {}, "data": {
		"run_type": "forced_retreat", "ase_awarded": 0, "ekwan_awarded": 0, "ledger_seen": true,
		"reward_breakdown": [], "actors": [] } })
	if line.visible or (screen.get_node("%EarningsSummary") as Control).visible:
		return _fail(m, "Ekwan line shows at 0")
	return _pass(m)


# ── Carried home and the retreat button ─────────────────────────────────────

const CarriedPanelScene := preload("res://ui/components/CarriedHomePanel.tscn")
const ReturnHomeScene := preload("res://ui/overlays/realm/ReturnHomeModal.tscn")
const PrebattleScene := preload("res://ui/overlays/realm/PrebattleModal.tscn")
const CarriedStrings := preload("res://ui/components/CarriedHomePresentation.gd")


static func _mount_scene(scene: PackedScene) -> Array:
	var host := (Engine.get_main_loop() as SceneTree).current_scene.get_node("UISnapshotRenderer")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var node := scene.instantiate() as Control
	viewport.add_child(node)
	return [viewport, node]


static func _party() -> Array:
	return [{ "name": "Ama", "emotional_status": "grounded" }, { "name": "Kofi", "emotional_status": "uncertain" }]


static func _t_carried_panel() -> Dictionary:
	var m := _mount_scene(CarriedPanelScene)
	var panel: CarriedHomePanel = m[1]
	var ase := panel.get_node("%AseLine") as Label
	var ekwan := panel.get_node("%EkwanLine") as Label
	var carried := panel.get_node("%CarriedBlock") as Control
	var party := panel.get_node("%PartyBlock") as Control
	var waits := panel.get_node("%WaitsLine") as Control
	# 0 and 0, nothing overcome: nothing shows.
	panel.present({ "ase": 0, "ekwan": 0, "overcome": 0, "total": 5 }, _party(), CarriedStrings.RETURN_COST)
	if panel.visible:
		return _fail(m, "panel visible with no carry and nothing overcome")
	# A repeat return that carries 0 with an overcome objective: the stage-waits line only.
	panel.present({ "ase": 0, "ekwan": 0, "overcome": 1, "total": 5 }, _party(), CarriedStrings.RETURN_COST)
	if not panel.visible or carried.visible or party.visible or not waits.visible:
		return _fail(m, "0/0 repeat return must show the waits line only")
	# Ase only, Ekwan only, both. Amounts come from data.
	var cases := [[7, 0, true, false], [0, 3, false, true], [11, 5, true, true]]
	for c in cases:
		panel.present({ "ase": c[0], "ekwan": c[1], "overcome": 1, "total": 9 }, _party(), CarriedStrings.RETURN_COST)
		if not carried.visible or ase.visible != c[2] or ekwan.visible != c[3]:
			return _fail(m, "carry %s: ase visible %s, ekwan visible %s" % [str(c), ase.visible, ekwan.visible])
		if c[2] and ase.text != "+%d Ase" % c[0] or c[3] and ekwan.text != "+%d Ekwan" % c[1]:
			return _fail(m, "carry %s: amounts %s / %s" % [str(c), ase.text, ekwan.text])
		# The comparator is always beside a carried line.
		if not party.visible or not waits.visible or not (panel.get_node("%CostLine") as Control).visible:
			return _fail(m, "carry %s: comparator missing" % str(c))
		if (panel.get_node("%PartyList") as Label).text != "Ama \u2014 Grounded\nKofi \u2014 Uncertain":
			return _fail(m, "party list: %s" % (panel.get_node("%PartyList") as Label).text)
		if (panel.get_node("%AdvanceNote") as Label).text != CarriedStrings.ADVANCE_NOTE:
			return _fail(m, "advance note missing")
	for t in _visible_texts(panel):
		if "lost" in str(t).to_lower() or " of " in str(t):
			return _fail(m, "forbidden text \"%s\"" % t)
	return _pass(m)


static func _t_return_modal() -> Dictionary:
	var m := _mount_scene(ReturnHomeScene)
	var modal: ReturnHomeModal = m[1]
	var panel := modal.get_node("%CarriedPanel") as Control
	var carry := { "ase": 4, "ekwan": 0, "overcome": 1, "total": 3 }
	modal.present({ "result": { "success": true, "message": "x" }, "carry": carry, "party": _party() })
	var shown: bool = panel.visible and (panel.get_node("%AseLine") as Label).text == "+4 Ase"
	var cost: String = (panel.get_node("%CostLine") as Label).text
	modal.present({ "result": { "success": false, "message": "x" }, "carry": carry, "party": _party() })
	var hidden_on_block: bool = not panel.visible
	var action: Dictionary = modal.get("_action")
	modal.present({ "result": { "success": true, "message": "x" }, "carry": carry, "party": _party() })
	var dispatched: Dictionary = modal.get("_action")
	if not shown or cost != CarriedStrings.RETURN_COST:
		return _fail(m, "carried panel missing on a successful return")
	if not hidden_on_block or action != { "type": "stage.dismiss_overlay" }:
		return _fail(m, "a blocked return must carry nothing and keep its action")
	if dispatched != { "type": "stage.confirm_return_home" }:
		return _fail(m, "the confirm action changed")
	return _pass(m)


static func _prebattle_payload(data_extra: Dictionary) -> Dictionary:
	var combat := (load("res://ui/screens/combat/CombatBoardScreen.tscn") as PackedScene).instantiate() as CombatBoardScreen
	var emitted: Array = []
	combat.modal_requested.connect(func(_id: StringName, payload: Dictionary) -> void: emitted.append(payload.duplicate(true)))
	combat.set("_round_label", combat.get_node("RoundLabel"))
	combat.set("_objective_label", combat.get_node("ObjectiveLabel"))
	var data := { "round_phase": "pre_combat", "board_cols": 2, "board_rows": 2,
		"actors": [_actor("Ama"), _actor("Kofi")], "objective_state": { "type": EncounterResolutionModes.COMBAT },
		"retreat_eligible": true, "retreat_tier_label": "Risky", "retreat_ase_cost": 13, "retreat_affordable": true }
	data.merge(data_extra, true)
	combat.call("_show_prebattle_panel", data, {
		"cta.combat_init": { "type": "combat.init", "slot": "cta.combat_init" },
		"cta.retreat": { "type": "encounter.retreat", "slot": "cta.retreat" } })
	combat.free()
	return emitted[0] if not emitted.is_empty() else {}


static func _t_retreat_button() -> Dictionary:
	var m := _mount_scene(PrebattleScene)
	var modal: PrebattleModal = m[1]
	var button := modal.get_node("%RetreatButton") as Button
	var note := modal.get_node("%RetreatNoteLabel") as Label
	# Affordable: enabled, price from data.
	var payload := _prebattle_payload({})
	modal.present(payload)
	if button.disabled or "13" not in button.text or note.visible:
		return _fail(m, "affordable retreat: disabled=%s text=%s" % [button.disabled, button.text])
	# Not affordable: disabled, price and reason in the text, 48x48 target.
	payload = _prebattle_payload({ "retreat_affordable": false })
	modal.present(payload)
	if not button.disabled or "13" not in button.text or CarriedStrings.RETREAT_UNAFFORDABLE not in button.text:
		return _fail(m, "unaffordable retreat: disabled=%s text=%s" % [button.disabled, button.text])
	var size := button.get_combined_minimum_size()
	if size.x < 48.0 or size.y < 48.0:
		return _fail(m, "retreat button %s is under 48x48" % str(size))
	# After a refused dispatch: one plain line, numbers from data.
	payload = _prebattle_payload({ "retreat_affordable": false,
		"retreat_denied": { "reason": "insufficient_ase", "ase_cost": 13, "ase_balance": 4 } })
	modal.present(payload)
	if not note.visible or note.text != "Retreating takes 13 Ase. The party has 4." or "lost" in note.text.to_lower():
		return _fail(m, "denied line: %s" % note.text)
	# The carried comparator on the retreat decision: only above 0, with the party.
	var panel := modal.get_node("%CarriedPanel") as Control
	payload = _prebattle_payload({ "carry_retreat_preview": { "ase": 0, "ekwan": 0, "overcome": 0, "total": 2 } })
	modal.present(payload)
	if panel.visible:
		return _fail(m, "carried panel shows at 0/0")
	payload = _prebattle_payload({ "carry_retreat_preview": { "ase": 6, "ekwan": 2, "overcome": 1, "total": 2 } })
	modal.present(payload)
	if not panel.visible or (panel.get_node("%PartyList") as Label).text != "Ama\nKofi":
		return _fail(m, "retreat comparator wrong: %s" % (panel.get_node("%PartyList") as Label).text)
	# The retreat action is unchanged.
	if modal.get("_retreat_action") != { "type": "encounter.retreat", "slot": "cta.retreat" }:
		return _fail(m, "the retreat action changed")
	return _pass(m)


static func _t_carried_no_amounts() -> Dictionary:
	var pattern := RegEx.create_from_string("text = \"[^\"]*[0-9]+\\s*(Ase|Ekwan)")
	for path in ["res://ui/components/CarriedHomePanel.tscn", "res://ui/overlays/realm/PrebattleModal.tscn",
			"res://ui/overlays/realm/ReturnHomeModal.tscn"]:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty() or pattern.search(text) != null:
			return { "ok": false, "error": "%s unreadable or has an amount in a text value" % path }
	return { "ok": true }


# ── Ledger and the home sequence ────────────────────────────────────────────

static func _unseen_stage(lost: Array, alive: int, started: int) -> Dictionary:
	var snap := _stage_home(lost, alive, started)
	snap["data"]["ledger_seen"] = false
	return snap


static func _t_ledger_after_sequence() -> Dictionary:
	var before := _set_reduced(false)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var sent: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	var ledger := screen.get_node("%Ledger") as Control
	var err := ""
	screen.set_snapshot(_unseen_stage(["Kofi"], 3, 4))
	if not screen.is_motion_running() or ledger.visible or not sent.is_empty():
		err = "while the sequence runs: running=%s ledger=%s emits=%d" % [screen.is_motion_running(), ledger.visible, sent.size()]
	# The host re-renders the same result mid-sequence: still closed, still no emit.
	if err.is_empty():
		screen.set_snapshot(_unseen_stage(["Kofi"], 3, 4))
		if ledger.visible or not sent.is_empty():
			err = "same-result re-render opened the ledger or emitted"
	# The sequence ends: the ledger opens and the emit happens once.
	if err.is_empty():
		screen._on_motion_done()
		if not ledger.visible or sent != [MARK_SEEN]:
			err = "after the sequence: ledger=%s emits=%s" % [ledger.visible, str(sent)]
	# A second end signal (for example a late skip) never emits again.
	if err.is_empty():
		screen.skip_motion()
		screen.set_snapshot(_stage_home(["Kofi"], 3, 4))
		if sent.size() != 1 or not ledger.visible:
			err = "double emit or ledger closed after the re-render (%d emits)" % sent.size()
	StopMarkMotion.reduced = before
	if not err.is_empty():
		return _fail(m, err)
	return _pass(m)


static func _t_ledger_at_once() -> Dictionary:
	var before := _set_reduced(false)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var sent: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	var ledger := screen.get_node("%Ledger") as Control
	var err := ""
	# A tap skips the sequence: the ledger opens at once, one emit.
	screen.set_snapshot(_unseen_stage(["Kofi"], 3, 4))
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	screen._input(tap)
	if screen.is_motion_running() or not ledger.visible or sent != [MARK_SEEN]:
		err = "tap skip: ledger=%s emits=%d" % [ledger.visible, sent.size()]
	# Reduced motion: no sequence, the ledger opens at once.
	if err.is_empty():
		sent.clear()
		StopMarkMotion.reduced = true
		screen.set_snapshot(_unseen_stage([], 4, 4))
		if screen.is_motion_running() or not ledger.visible or sent != [MARK_SEEN]:
			err = "reduced motion: ledger=%s emits=%d" % [ledger.visible, sent.size()]
		StopMarkMotion.reduced = false
	# A card with no home sequence (defeat rows) opens at once, as before.
	if err.is_empty():
		sent.clear()
		screen.set_snapshot(_snap([_row("Carried", 7, "partial_return_home")], { "ledger_seen": false }, false))
		if not ledger.visible or sent != [MARK_SEEN]:
			err = "no sequence: ledger=%s emits=%d" % [ledger.visible, sent.size()]
	StopMarkMotion.reduced = before
	if not err.is_empty():
		return _fail(m, err)
	return _pass(m)


static func _t_ledger_new_snapshot() -> Dictionary:
	var before := _set_reduced(false)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var sent: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	var ledger := screen.get_node("%Ledger") as Control
	var err := ""
	screen.set_snapshot(_unseen_stage(["Kofi"], 3, 4))
	# A different result arrives mid-sequence: the old one never emits.
	screen.set_snapshot(_unseen_stage([], 2, 2))
	if not sent.is_empty() or ledger.visible or not screen.is_motion_running():
		err = "new card: emits=%d ledger=%s running=%s" % [sent.size(), ledger.visible, screen.is_motion_running()]
	if err.is_empty():
		screen.skip_motion()
		if sent != [MARK_SEEN] or not ledger.visible:
			err = "new card after skip: emits=%d ledger=%s" % [sent.size(), ledger.visible]
	# A seen card that replaces a waiting one leaves nothing to emit.
	if err.is_empty():
		sent.clear()
		screen.set_snapshot(_unseen_stage(["Kofi"], 3, 4))
		screen.set_snapshot(_snap([], { "ledger_seen": true }))
		screen.skip_motion()
		if not sent.is_empty():
			err = "an old waiting emit survived a new card"
	StopMarkMotion.reduced = before
	if not err.is_empty():
		return _fail(m, err)
	return _pass(m)
