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
	runner.register_test("payout_ui/home_sequence_names_an_earlier_fight_death_once", Callable(ResolvePayoutUITests, "_t_home_earlier_death"))
	runner.register_test("payout_ui/no_placeholder_derivation_remains", Callable(ResolvePayoutUITests, "_t_no_placeholder"))
	runner.register_test("payout_ui/home_sequence_all_home_has_no_lost_line_or_label", Callable(ResolvePayoutUITests, "_t_home_all"))
	runner.register_test("payout_ui/home_sequence_motion_skips_on_tap_and_never_blocks", Callable(ResolvePayoutUITests, "_t_home_motion_skip"))
	runner.register_test("payout_ui/carried_ekwan_line_on_scout_return", Callable(ResolvePayoutUITests, "_t_carried_ekwan"))
	runner.register_test("payout_ui/ledger_waits_for_home_sequence_then_emits_once", Callable(ResolvePayoutUITests, "_t_ledger_after_sequence"))
	runner.register_test("payout_ui/ledger_opens_at_once_on_skip_reduced_motion_or_no_sequence", Callable(ResolvePayoutUITests, "_t_ledger_at_once"))
	runner.register_test("payout_ui/new_snapshot_mid_sequence_drops_old_emit", Callable(ResolvePayoutUITests, "_t_ledger_new_snapshot"))
	runner.register_test("payout_ui/strings_match_jeffs_words_exactly", Callable(ResolvePayoutUITests, "_t_strings_exact"))
	runner.register_test("payout_ui/no_percent_home_or_stage_in_these_surfaces", Callable(ResolvePayoutUITests, "_t_surface_words"))
	runner.register_test("payout_ui/removed_strings_and_fields_are_gone_from_ui", Callable(ResolvePayoutUITests, "_t_removed_gone"))
	runner.register_test("payout_ui/return_card_outcome_line_and_amounts", Callable(ResolvePayoutUITests, "_t_return_card"))
	runner.register_test("payout_ui/return_card_empty_leave_has_no_outcome_line", Callable(ResolvePayoutUITests, "_t_return_card_empty_leave"))
	runner.register_test("payout_ui/older_strings_no_home_stage_or_percent", Callable(ResolvePayoutUITests, "_t_older_strings"))
	runner.register_test("payout_ui/retreat_card_renders_and_button_sends_retreat_return", Callable(ResolvePayoutUITests, "_t_retreat_card"))
	runner.register_test("payout_ui/retreat_card_through_real_shell_and_host", Callable(ResolvePayoutUITests, "_t_retreat_real_host"))
	runner.register_test("payout_ui/return_home_confirmation_opens_before_dispatch", Callable(ResolvePayoutUITests, "_t_return_confirm_before_dispatch"))
	runner.register_test("payout_ui/return_home_confirm_once_cancel_and_esc_send_nothing", Callable(ResolvePayoutUITests, "_t_return_confirm_buttons"))
	runner.register_test("payout_ui/return_home_through_real_shell_and_host", Callable(ResolvePayoutUITests, "_t_return_real_host"))
	runner.register_test("payout_ui/return_home_confirmation_zero_carry_and_failed_escape", Callable(ResolvePayoutUITests, "_t_return_confirm_zero_and_failure"))
	runner.register_test("payout_ui/retreat_button_price_affordable_and_denied", Callable(ResolvePayoutUITests, "_t_retreat_button"))
	runner.register_test("payout_ui/carried_scenes_hold_no_amount_text", Callable(ResolvePayoutUITests, "_t_carried_no_amounts"))
	runner.register_test("payout_ui/unknown_cause_shows_no_button", Callable(ResolvePayoutUITests, "_t_unknown_cause"))
	runner.register_test("payout_ui/other_cards_keep_working", Callable(ResolvePayoutUITests, "_t_other_cards"))
	runner.register_test("payout_ui/effects_rail_has_no_ase_ekwan_or_defeated_chip", Callable(ResolvePayoutUITests, "_t_rail_chips"))
	runner.register_test("payout_ui/scenes_hold_no_amount_text", Callable(ResolvePayoutUITests, "_t_no_hard_coded_amounts"))
	runner.register_test("payout_ui/standoff_strings_match_the_copy_file_exactly", Callable(ResolvePayoutUITests, "_t_standoff_strings"))
	runner.register_test("payout_ui/standoff_card_first_has_one_button_second_has_two", Callable(ResolvePayoutUITests, "_t_standoff_buttons"))
	runner.register_test("payout_ui/standoff_body_by_cause_and_calm_line_only_with_names", Callable(ResolvePayoutUITests, "_t_standoff_causes"))
	runner.register_test("payout_ui/standoff_card_through_real_shell_and_host", Callable(ResolvePayoutUITests, "_t_standoff_real_host"))
	runner.register_test("payout_ui/board_warning_levels_fade_clear_and_bark_once", Callable(ResolvePayoutUITests, "_t_warning_levels"))
	runner.register_test("payout_ui/prebattle_shows_the_stalled_line_only_when_flagged", Callable(ResolvePayoutUITests, "_t_prebattle_stalled"))
	runner.register_test("payout_ui/return_confirm_requested_opens_the_confirmation_once", Callable(ResolvePayoutUITests, "_t_confirm_requested_once"))
	runner.register_test("payout_ui/confirmation_shows_the_gathered_block_or_the_empty_line", Callable(ResolvePayoutUITests, "_t_gathered_block"))
	runner.register_test("payout_ui/found_ase_cards_show_the_packs_line_and_total", Callable(ResolvePayoutUITests, "_t_found_cards"))
	runner.register_test("payout_ui/defeat_card_shows_packs_lost_line_only_with_the_row", Callable(ResolvePayoutUITests, "_t_packs_lost"))
	runner.register_test("payout_ui/won_fight_with_gathered_row_keeps_the_midstage_layout", Callable(ResolvePayoutUITests, "_t_won_fight_midstage"))
	runner.register_test("payout_ui/packs_cause_names_and_tooltips_are_exact", Callable(ResolvePayoutUITests, "_t_packs_causes"))
	runner.register_test("payout_ui/phase7_strings_no_home_stage_percent_or_leave", Callable(ResolvePayoutUITests, "_t_phase7_scan"))


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
		_row("Settled when you left", 11, "settled_on_leave"),
		_row("Redo penalty", -3, "replay", { "factor": 0.35 }),
	]
	screen.set_snapshot(_snap(rows, { "ledger_seen": true }, false))
	var shown := _rows_in(screen, "%BreakdownSection")
	if shown.size() != 2:
		return _fail(m, "expected 2 fight rows, got %d" % shown.size())
	if _names(shown) != ["Settled when you left", "Replay"]:
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
		_row("Settled when you left", 0, "settled_on_leave", { "settled_ase": 12, "settled_ekwan": 2 }),
	]
	screen.set_snapshot(_snap([], {
		"ledger_seen": true, "stage_payout_rows": stage, "stage_payout_ase": 30, "stage_payout_ekwan": 6 }))
	var stage_rows := _rows_in(screen, "%StageSection")
	if stage_rows.size() != 4 or not screen.get_node("%StageGroup").visible:
		return _fail(m, "stage group does not show the 4 stage rows")
	# The lost name shows once: this card has no emotion row for him, so the note under the rows names him.
	screen.skip_motion()
	var named := _visible_texts(screen).filter(func(t: Variant) -> bool: return "did not make it back" in str(t))
	if named != ["Kofi did not make it back."]:
		return _fail(m, "lost-name lines: %s" % str(named))
	# The memo row changes no total: zero delta, the exact label, and no carried_advance row any more.
	var memo: RewardEntryItem = stage_rows[3]
	if memo.delta_label.text != "+0 Ase" or memo.entry_label.text != "Settled when you left" or not memo.cause_button.visible:
		return _fail(m, "memo row is %s / %s" % [memo.entry_label.text, memo.delta_label.text])
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
	if home.entry_label.text != "Echoes safe" or home.delta_label.text != "+0 Ase" or not home.cause_button.visible:
		return _fail(m, "echoes row %s %s" % [home.entry_label.text, home.delta_label.text])
	if home.note_label.text != "Ama and Kofi did not make it back.":
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
		_row("Settled when you left", 7, "settled_on_leave"),
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
		"echoes_alive": "Each Echo that stays alive earns Ase.",
		"settled_on_leave": "These were already taken when the party left earlier.",
		"defeat_consolation": "This one was lost, but we still earn a small part.",
		"nothing_overcome_yet": "Nothing was gathered.",
		"repeat_defeat": "The party already earned the consolation for this. Another loss earns nothing.",
	}
	for cause in want:
		if PayoutCausePresentation.tooltip(cause) != want[cause]:
			return { "ok": false, "error": "%s: \"%s\"" % [cause, PayoutCausePresentation.tooltip(cause)] }
	var replay_fight := PayoutCausePresentation.tooltip("replay", {}, "fight")
	var replay_stage := PayoutCausePresentation.tooltip("replay", {}, "stage")
	if replay_fight != "The party has been here before. It earns less.":
		return { "ok": false, "error": "replay (fight): \"%s\"" % replay_fight }
	if replay_stage != "The party has been here before. All of it earns less.":
		return { "ok": false, "error": "replay (stage): \"%s\"" % replay_stage }
	var objectives := PayoutCausePresentation.tooltip("objectives_overcome", { "overcome": 4, "total": 7 })
	if objectives != "Only objectives the party found and overcame earn Ase. 4 of 7 so far.":
		return { "ok": false, "error": "objectives: \"%s\"" % objectives }
	var names := { "replay": "Replay", "defeat_consolation": "Consolation", "objectives_overcome": "Objectives overcome",
		"echoes_alive": "Echoes safe", "settled_on_leave": "Settled when you left" }
	for cause in names:
		if PayoutCausePresentation.row_name(cause, "x") != names[cause]:
			return { "ok": false, "error": "row name of %s" % cause }
	# Removed causes: no entry, so a stray row keeps its backend label and shows no (i).
	for cause in ["enemies_defeated", "realm_virtue", "bonus_earned", "bonus_missed", "carried_advance", "partial_retreat", "partial_return_home"]:
		if PayoutCausePresentation.has_cause(cause) or PayoutCausePresentation.row_name(cause, "Label") != "Label":
			return { "ok": false, "error": "%s still has an entry" % cause }
	if PayoutCausePresentation.row_note("echoes_alive", { "lost": ["Ama", "Kofi", "Esi"] }) != "Ama, Kofi and Esi did not make it back.":
		return { "ok": false, "error": "three lost names note" }
	if PayoutCausePresentation.row_note("echoes_alive", { "lost": [] }) != "":
		return { "ok": false, "error": "a note shows with no lost Echo" }
	return { "ok": true }


static func _t_tooltip_rules() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_snap([
		_row("Settled when you left", 7, "settled_on_leave"),
		_row("Realm virtue", 3, "realm_virtue"),
	], { "ledger_seen": true }))
	var tip := screen.get_node("%CauseTooltip") as CauseTooltip
	var first: RewardEntryItem = _rows_in(screen, "%BreakdownSection")[0]
	var button := first.cause_button
	button.mouse_entered.emit()
	if not tip.is_open() or tip.is_pinned() or (tip.get_node("%TitleLabel") as Label).text != "Settled when you left":
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
	screen.set_snapshot(_snap([_row("Settled when you left", 7, "settled_on_leave")], { "ledger_seen": true }))
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
	var first := [_row("Settled when you left", 7, "settled_on_leave")]
	var second := [_row("Settled when you left", 9, "settled_on_leave")]
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
	var rows := [_row("Settled when you left", 7, "settled_on_leave")]
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
	var rows := [_row("Settled when you left", 7, "settled_on_leave")]
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
		"reward_breakdown": [_row("Settled when you left", 6, "settled_on_leave")], "actors": [] } })
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
	screen.set_snapshot(_snap([_row("Settled when you left", 7, "settled_on_leave")], { "ledger_seen": true }))
	if not (screen.get_node("%EnemiesChip") as Control).visible or _label(screen, "%EnemiesDefeatedValue").text != "2" \
			or _label(screen, "%EchoesAliveValue").text != "3" or _label(screen, "%RoundsValue").text != "5" \
			or _label(screen, "%RankBadge").text != "B":
		return _fail(m, "fight strip values wrong after other cards")
	return _pass(m)


static func _t_rail_chips() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_snap([_row("Settled when you left", 7, "settled_on_leave")], {
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


## Mid-stage win. thread_whole is on the combat victory card; each test sets or erases it.
static func _midstage(extra: Dictionary = {}) -> Dictionary:
	var data := { "ledger_seen": true, "thread_whole": true,
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
	var objective := screen.get_node("%ObjectiveLine") as Label
	var intel := screen.get_node("%IntelLine") as Label
	var thread := screen.get_node("%ThreadLine") as Label
	var err := ""
	# thread_whole true shows the line; false and a missing key hide it.
	screen.set_snapshot(_midstage())
	if not thread.visible or thread.text != PayoutCausePresentation.THREAD_WHOLE or change.visible or objective.visible or intel.visible:
		err = "plain win: thread=%s change=%s objective=%s intel=%s" % [thread.visible, change.visible, objective.visible, intel.visible]
	if err.is_empty():
		screen.set_snapshot(_midstage({ "thread_whole": false }))
		if thread.visible:
			err = "thread_whole false must hide the Thread line"
	if err.is_empty():
		var snap := _midstage()
		snap["data"].erase("thread_whole")
		screen.set_snapshot(snap)
		if thread.visible or (screen.get_node("%StoryLines") as Control).visible:
			err = "a missing thread_whole must hide the Thread line"
	# objective_overcome: the label shows, the index and the type never do.
	if err.is_empty():
		screen.set_snapshot(_midstage({ "objective_overcome": { "index": 7, "type": "fixture_type", "label": "A test label." } }))
		if not objective.visible or objective.text != "Found and overcome. A test label.":
			err = "objective line: \"%s\"" % objective.text
		for t in _visible_texts(screen):
			if "fixture_type" in str(t) or "7" in str(t):
				err = "objective index or type shown: \"%s\"" % t
	if err.is_empty():
		screen.set_snapshot(_midstage())
		if objective.visible:
			err = "objective line shown with no objective_overcome"
	# intel_gained: shown at 2; hidden at 0 and when absent.
	if err.is_empty():
		screen.set_snapshot(_midstage({ "intel_gained": 2 }))
		if not intel.visible or intel.text != PayoutCausePresentation.INTEL_LEARNED:
			err = "intel_gained 2: visible=%s" % intel.visible
	if err.is_empty():
		screen.set_snapshot(_midstage({ "intel_gained": 0 }))
		if intel.visible:
			err = "intel_gained 0 must hide the line"
	# A shaken Echo gives the change line; two Echoes held back give one line with both names.
	if err.is_empty():
		screen.set_snapshot(_midstage({ "emotion_summary": [_summary("Ama"), _summary("Kofi", "", "fall"), _summary("Esi")] }))
		if change.text != "Kofi was shaken.":
			err = "event win: change \"%s\"" % change.text
	if err.is_empty():
		screen.set_snapshot(_midstage({ "emotion_summary": [_summary("Ama", "refused"), _summary("Kofi", "refused")] }))
		if change.text != "Ama and Kofi held back.":
			err = "two refused: \"%s\"" % change.text
	# A win with nothing at all shows no story lines.
	if err.is_empty():
		screen.set_snapshot(_snap([], { "ledger_seen": true, "emotion_summary": [] }))
		if (screen.get_node("%StoryLines") as Control).visible:
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
	if not count.visible or count.text != "alive 3 of 4":
		return _fail(m, "count is \"%s\"" % count.text)
	var lost_lines := texts.filter(func(t: Variant) -> bool: return "did not make it back" in str(t))
	if lost_lines != ["Kofi did not make it back."]:
		return _fail(m, "lost name lines: %s" % str(lost_lines))
	var homes := texts.filter(func(t: Variant) -> bool: return str(t) == "alive")
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
	if _label(screen, "%HomeCountLabel").text != "alive 4 of 4":
		return _fail(m, "count is \"%s\"" % _label(screen, "%HomeCountLabel").text)
	for t in texts:
		if "did not make it back" in str(t) or "perfect" in str(t).to_lower() or "flawless" in str(t).to_lower():
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
	if not screen.is_motion_running() or count.text != "alive 0 of 4" or ase.modulate.a != 0.0:
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
		if screen.is_motion_running() or count.text != "alive 3 of 4" or ase.modulate.a != 1.0:
			err = "a tap did not reach the final state: count=%s alpha=%s" % [count.text, ase.modulate.a]
	if err.is_empty():
		var lost_lines := _visible_texts(screen).filter(func(t: Variant) -> bool: return "did not make it back" in str(t))
		if lost_lines != ["Kofi did not make it back."]:
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
		"run_type": "scout_return", "ase_awarded": 0, "ekwan_awarded": 0, "ledger_seen": true,
		"reward_breakdown": [], "actors": [] } })
	if line.visible or (screen.get_node("%EarningsSummary") as Control).visible:
		return _fail(m, "Ekwan line shows at 0")
	return _pass(m)


# ── Carried home and the retreat button ─────────────────────────────────────

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


## Jeff's words (D-107), written out here on purpose: a changed character must fail this test.
static func _t_strings_exact() -> Dictionary:
	var want := {
		"CONFIRM_TITLE": "Return to the Sanctum",
		"CONFIRM_QUESTION": "Take the party back to the Sanctum?",
		"RISK_LINE": "Not all of it will survive the escape. What cannot be carried will be lost.",
		"CONFIRM_WARNING": "Escaping might be more difficult than expected. It might not be possible.",
		"KEEPS_LINE": "The path still waits.",
		"CONFIRM_LABEL": "To the Sanctum",
		"CANCEL_LABEL": "Stay",
		"FAILED_SUBTITLE": "No way out.",
		"RETREAT_TITLE": "Pulled back",
		"RETREAT_BODY": "Withdrawing. Back to the path.",
		"RETREAT_NO_REENTER": "It's not smart to re-enter this quickly.",
		"RETREAT_REENTER": "Our task is not done. This story is not over yet.",
	}
	var consts: Dictionary = _string_consts()
	for key in want:
		if str(consts.get(key, "<missing>")) != want[key]:
			return { "ok": false, "error": "%s is \"%s\"" % [key, str(consts.get(key, "<missing>"))] }
	var settle := { "none": "Nothing got out.", "some": "Some of it got out", "all": "Everything got out",
		"nothing_new": "Nothing was gathered since the last time." }
	for outcome in settle:
		if CarriedStrings.settle_line(outcome) != settle[outcome]:
			return { "ok": false, "error": "settle line %s is \"%s\"" % [outcome, CarriedStrings.settle_line(outcome)] }
	if CarriedStrings.settle_line("") != "" or CarriedStrings.settle_line("bogus") != "":
		return { "ok": false, "error": "an unknown outcome shows a line" }
	var gathered := [[4, 2, "In their packs: 4 Ase and 2 Ekwan."], [4, 0, "In their packs: 4 Ase."],
		[0, 2, "In their packs: 2 Ekwan."], [0, 0, ""]]
	for g in gathered:
		if CarriedStrings.gathered_line(g[0], g[1]) != g[2]:
			return { "ok": false, "error": "gathered %d/%d is \"%s\"" % [g[0], g[1], CarriedStrings.gathered_line(g[0], g[1])] }
	if CarriedStrings.retreat_label(10) != "Retreat (10 Ase)" or CarriedStrings.retreat_denied_line(10, 4) != "Retreating takes 10 Ase. The party has 4.":
		return { "ok": false, "error": "retreat button or denied line changed" }
	if CarriedStrings.retreat_line(true) != want["RETREAT_REENTER"] or CarriedStrings.retreat_line(false) != want["RETREAT_NO_REENTER"]:
		return { "ok": false, "error": "retreat extra line mapped to the wrong can_reenter" }
	return { "ok": true }


static func _string_consts() -> Dictionary:
	return (CarriedStrings as Script).get_script_constant_map()


## The first of "%", "home", "stage", a fraction or an odds word found in `text`, or "".
static func _banned_in(text: String) -> String:
	var low := text.to_lower()
	for word in ["%", "home", "stage", "odds", "chance", "percent"]:
		if word in low:
			return word
	if RegEx.create_from_string("[0-9]\\s*/\\s*[0-9]").search(low) != null:
		return "fraction"
	return ""


static func _first_banned(texts: Array) -> String:
	for t in texts:
		var hit := _banned_in(str(t))
		if not hit.is_empty():
			return "\"%s\" holds \"%s\"" % [str(t), hit]
	return ""


static func _scout_card(outcome: String, ase: int, ekwan: int) -> Dictionary:
	var rows := [] if outcome.is_empty() else [_row("Settled when you left", ase, "settle_" + outcome, { "overcome": 1, "total": 3 })]
	var data := { "run_type": "scout_return", "intel_count": 1, "ase_awarded": ase, "ekwan_awarded": ekwan,
		"ledger_seen": true, "reward_breakdown": rows, "actors": [] }
	if not outcome.is_empty():
		data["settle_outcome"] = outcome
	return { "type": "flow.resolve", "meta": { "t": 3 }, "data": data,
		"actions": { "cta.continue": { "type": "flow.go_state", "to": "SANCTUM", "label": "Return to Sanctum", "slot": "cta.continue" } } }


static func _retreat_card(can_reenter: bool) -> Dictionary:
	return VentureResolveSnapshotBuilder.build_retreat_return_snapshot(can_reenter, 2)


## No percent, no "home", no "stage", no fraction and no odds word on any surface of this step.
static func _t_surface_words() -> Dictionary:
	var texts: Array = []
	for v in _string_consts().values():
		if v is String:
			texts.append(v)
	texts.append_array(CarriedStrings.SETTLE_LINES.values())
	for q in [[4, 2], [4, 0], [0, 2]]:
		texts.append(CarriedStrings.gathered_line(q[0], q[1]))
	texts.append(CarriedStrings.retreat_label(10, CarriedStrings.RETREAT_UNAFFORDABLE))
	texts.append(CarriedStrings.retreat_denied_line(10, 4))
	texts.append(PayoutCausePresentation.tooltip("settled_on_leave"))
	texts.append(PayoutCausePresentation.row_name("settled_on_leave", ""))
	var hit := _first_banned(texts)
	if not hit.is_empty():
		return { "ok": false, "error": "string tables: " + hit }
	# What the player sees on each card, read from the mounted scenes.
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var shown: Array = []
	for outcome in ["none", "some", "all", "nothing_new"]:
		screen.set_snapshot(_scout_card(outcome, 5, 2))
		shown.append_array(_visible_texts(screen))
	for can in [false, true]:
		screen.set_snapshot(_retreat_card(can))
		shown.append_array(_visible_texts(screen))
	# "Return to Sanctum" is the action label sent by the core; the other "stage" words are not on these cards.
	hit = _first_banned(shown)
	m[0].free()
	if not hit.is_empty():
		return { "ok": false, "error": "resolve cards: " + hit }
	var m2 := _mount_scene(ReturnHomeScene)
	var modal: ReturnHomeModal = m2[1]
	shown = []
	for carry in [{ "ase": 4, "ekwan": 2 }, { "ase": 4, "ekwan": 0 }, { "ase": 0, "ekwan": 2 }, { "nothing_new": true }]:
		modal.present(_confirm_payload(carry))
		shown.append_array(_visible_texts(modal))
	modal.present({ "result": { "success": false, "message": "The way is blocked." } })
	shown.append_array(_visible_texts(modal))
	hit = _first_banned(shown)
	m2[0].free()
	if not hit.is_empty():
		return { "ok": false, "error": "confirmation: " + hit }
	var m3 := _mount_scene(PrebattleScene)
	var pre: PrebattleModal = m3[1]
	shown = []
	for extra in [{}, { "retreat_affordable": false },
			{ "retreat_affordable": false, "retreat_denied": { "ase_cost": 13, "ase_balance": 4 } }]:
		pre.present(_prebattle_payload(extra))
		shown.append_array(_visible_texts(pre))
	hit = _first_banned(shown)
	m3[0].free()
	if not hit.is_empty():
		return { "ok": false, "error": "pre-battle modal: " + hit }
	# The stage-stop button that opens the confirmation.
	var stage_scene := (load("res://ui/screens/venture/StageExploreScreen.tscn") as PackedScene).instantiate()
	var button_text := (stage_scene.get_node("%ReturnButton") as Button).text
	stage_scene.free()
	if button_text != "To the Sanctum":
		return { "ok": false, "error": "Return button text is \"%s\"" % button_text }
	return { "ok": true }


## The older strings of the payout cards (D-111). Excluded: constant and node NAMES, causes and other
## ids, the SCOPE_* ids, strings in other scenes, the vow header texts, and the core labels (a row
## label is replaced by row_name for every listed cause). `%s` and `%d` are removed before the scan.
static func _t_older_strings() -> Dictionary:
	var texts: Array = []
	var consts: Dictionary = (PayoutCausePresentation as Script).get_script_constant_map()
	for key in consts:
		if str(key).begins_with("SCOPE_"):
			continue
		var v: Variant = consts[key]
		if v is String:
			texts.append(v)
		elif v is Dictionary:
			texts.append_array((v as Dictionary).values())
		elif v is Array:
			for entry in (v as Array):
				if entry is Array:
					texts.append_array((entry as Array).slice(1))
	texts.append(PayoutCausePresentation.home_count(2, 3))
	texts.append(PayoutCausePresentation.lost_line("Kofi"))
	texts.append(PayoutCausePresentation.tooltip("replay", {}, "stage"))
	var bad := _first_old_word(texts.map(func(t: Variant) -> String: return str(t).replace("%s", "").replace("%d", "")))
	if not bad.is_empty():
		return { "ok": false, "error": "PayoutCausePresentation: " + bad }
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var shown: Array = []
	var cards: Array = [
		_stage_home(["Kofi"], 3, 4),
		_snap([_row("Base objectives", 13, "defeat_consolation", { "part": "base" })], { "ledger_seen": true }, false),
		_midstage({ "intel_gained": 2 }),
		_snap([], { "ledger_seen": true, "stage_payout_rows": [_row("Redo penalty", -4, "replay", { "factor": 0.9 })],
			"stage_payout_ase": 5, "vow_outcome": { "event": "compliant", "compliance_count": 3 } }),
		_snap([], { "ledger_seen": true, "stage_payout_rows": [_row("Redo penalty", -4, "replay", { "factor": 0.9 })],
			"stage_payout_ase": 5, "vow_outcome": { "event": "compliant", "compliance_count": 1 } }),
	]
	var before := _set_reduced(true)
	for card in cards:
		screen.set_snapshot(card)
		screen.skip_motion()
		shown.append_array(_visible_texts(screen))
	var empty := _scout_card("nothing_new", 0, 0)
	empty["data"]["reward_breakdown"] = [_row("Nothing overcome yet", 0, "nothing_overcome_yet", { "overcome": 0, "total": 3 })]
	screen.set_snapshot(empty)
	shown.append_array(_visible_texts(screen))
	StopMarkMotion.reduced = before
	# Tooltips of every row cause that these cards carry.
	for cause in ["echoes_alive", "defeat_consolation", "nothing_overcome_yet", "replay"]:
		shown.append(PayoutCausePresentation.tooltip(cause, {}, "stage"))
	bad = _first_old_word(shown)
	# Static texts of the scene, unfiltered: a placeholder that is never overwritten still reaches the player.
	for path in ["res://ui/screens/venture/ResolveScreen.tscn", "res://ui/components/EmotionEntryItem.tscn"]:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("text = "):
				shown.append(line.trim_prefix("text = ").trim_prefix("\"").trim_suffix("\""))
	m[0].free()
	if bad.is_empty():
		bad = _first_old_word(shown)
	if not bad.is_empty():
		return { "ok": false, "error": "resolve cards: " + bad }
	return { "ok": true }


static func _first_old_word(texts: Array) -> String:
	for t in texts:
		var low := str(t).to_lower()
		for word in ["home", "stage", "%"]:
			if word in low:
				return "\"%s\" holds \"%s\"" % [str(t), word]
	return ""


static func _t_removed_gone() -> Dictionary:
	var needles := ["Going home costs nothing", "The rest is earned when the stage", "The stage waits", "Carried home",
		"Return Home", "Go home", "Escape guaranteed", "Chance of failure", "carry_retreat_preview", "carried_advance",
		"partial_return_home", "partial_retreat", "CarriedHomePanel", "retreat_tier_label"]
	var stack: Array[String] = ["res://ui"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir_path):
			stack.append(dir_path.path_join(sub))
		for file in DirAccess.get_files_at(dir_path):
			if not (file.ends_with(".gd") or file.ends_with(".tscn")):
				continue
			var text := FileAccess.get_file_as_string(dir_path.path_join(file))
			for needle in needles:
				if needle in text:
					return { "ok": false, "error": "%s still holds \"%s\"" % [dir_path.path_join(file), needle] }
	return { "ok": true }


## The return card: no row label, one outcome line, then the amounts. The "none" card still shows +0.
static func _t_return_card() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var outcome_line := screen.get_node("%OutcomeLine") as Label
	var cases := [["none", 0, 0, "Nothing got out."], ["some", 6, 0, "Some of it got out"],
		["all", 9, 3, "Everything got out"], ["nothing_new", 0, 0, "Nothing was gathered since the last time."]]
	for c in cases:
		screen.set_snapshot(_scout_card(c[0], c[1], c[2]))
		if not outcome_line.visible or outcome_line.text != c[3]:
			return _fail(m, "%s: outcome line is \"%s\"" % [c[0], outcome_line.text])
		if _label(screen, "%AseTotalLabel").text != "+%d Ase" % c[1] or not (screen.get_node("%EarningsSummary") as Control).visible:
			return _fail(m, "%s: Ase amount missing or wrong: %s" % [c[0], _label(screen, "%AseTotalLabel").text])
		var ekwan := screen.get_node("%EkwanTotalLabel") as Label
		if ekwan.visible != (c[2] > 0) or (c[2] > 0 and ekwan.text != "+%d Ekwan" % c[2]):
			return _fail(m, "%s: Ekwan amount wrong (visible=%s text=%s)" % [c[0], ekwan.visible, ekwan.text])
		# The settle row has no label on the card: no row at all.
		if not _rows_in(screen, "%BreakdownSection").is_empty() or "Settled when you left" in _visible_texts(screen):
			return _fail(m, "%s: the settle row shows" % c[0])
		var tap_target := (screen.get_node("%SanctumButton") as Button)
		if not tap_target.visible or tap_target.custom_minimum_size.y < 56.0:
			return _fail(m, "%s: the button is missing or under 56 high" % c[0])
	# A card without settle_outcome (a forced retreat) shows no outcome line.
	screen.set_snapshot(_scout_card("", 0, 0))
	if outcome_line.visible:
		return _fail(m, "an outcome line shows without settle_outcome")
	return _pass(m)


## D-110 F1: a leave with nothing completed shows only the "Nothing was gathered." row (the UI replaces the core label), even though the
## core still sends settle_outcome "nothing_new". The line returns once something was completed earlier.
static func _t_return_card_empty_leave() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var outcome_line := screen.get_node("%OutcomeLine") as Label
	var empty := _scout_card("nothing_new", 0, 0)
	empty["data"]["reward_breakdown"] = [_row("Nothing overcome yet", 0, "nothing_overcome_yet", { "overcome": 0, "total": 3 })]
	screen.set_snapshot(empty)
	if outcome_line.visible or not outcome_line.text.is_empty():
		return _fail(m, "empty leave shows the line \"%s\"" % outcome_line.text)
	if _names(_rows_in(screen, "%BreakdownSection")) != ["Nothing was gathered."]:
		return _fail(m, "empty leave rows: %s" % str(_names(_rows_in(screen, "%BreakdownSection"))))
	screen.set_snapshot(_scout_card("nothing_new", 0, 0))
	if not outcome_line.visible or outcome_line.text != "Nothing was gathered since the last time.":
		return _fail(m, "nothing new after an earlier completion: \"%s\"" % outcome_line.text)
	return _pass(m)


static func _t_retreat_card() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var actions: Array = []
	var dismissed: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: actions.append(a))
	screen.dismiss_requested.connect(func() -> void: dismissed.append(1))
	var button := screen.get_node("%SanctumButton") as Button
	for c in [[false, "It's not smart to re-enter this quickly."], [true, "Our task is not done. This story is not over yet."]]:
		screen.set_snapshot(_retreat_card(c[0]))
		if _label(screen, "%BannerLabel").text != "Pulled back" or _label(screen, "%ReasonLabel").text != "Withdrawing. Back to the path.":
			return _fail(m, "retreat card title or body: %s / %s" % [_label(screen, "%BannerLabel").text, _label(screen, "%ReasonLabel").text])
		if _label(screen, "%OutcomeLine").text != c[1] or not (screen.get_node("%OutcomeLine") as Control).visible:
			return _fail(m, "can_reenter %s: extra line \"%s\"" % [c[0], _label(screen, "%OutcomeLine").text])
		# The card is not the victory or defeat card.
		for hidden in ["%FightHeader", "%EarningsSummary", "%Ledger", "%BodyViewport", "%NextStageButton"]:
			if (screen.get_node(hidden) as Control).visible:
				return _fail(m, "retreat card shows %s" % hidden)
		if button.text != "Leave" or not button.visible or button.disabled:
			return _fail(m, "retreat button text=%s visible=%s" % [button.text, button.visible])
		if button.size.x != 0.0 and (button.size.x < 48.0 or button.size.y < 48.0) or button.custom_minimum_size.y < 48.0:
			return _fail(m, "retreat button %s is under 48x48" % str(button.size))
		for t in _visible_texts(screen):
			if str(t) in ["VICTORY", "DEFEAT"]:
				return _fail(m, "retreat card shows %s" % str(t))
	# The button sends stage.retreat_return through the card's own signal, once per press.
	actions.clear()
	button.pressed.emit()
	if actions.size() != 1 or str(actions[0].get("type", "")) != "stage.retreat_return" or dismissed.size() != 1:
		return _fail(m, "button sent %s" % str(actions))
	# The next normal card gets its body back.
	screen.set_snapshot(_snap([], { "ledger_seen": true }))
	if not (screen.get_node("%BodyViewport") as Control).visible or (screen.get_node("%OutcomeLine") as Control).visible:
		return _fail(m, "the retreat layout leaked into the next card")
	return _pass(m)


## Real chain: a real RealmShell, a real ModalHost, the real producer for the card, the real button.
static func _t_retreat_real_host() -> Dictionary:
	var fx := StageCameraSelectTests._make_fixture("payout_retreat")
	if fx.is_empty():
		return { "ok": false, "error": "could not build the real stage fixture" }
	var vp: SubViewport = fx["viewport"]
	var realm: RealmShell = fx["realm"]
	var host := preload("res://ui/components/ModalHost.tscn").instantiate() as ModalHost
	vp.add_child(host)
	var actions: Array = []
	realm.modal_requested.connect(func(id: StringName, payload: Dictionary) -> void:
		host.present_modal_for_id(id, realm.modal_scene_for(id), payload))
	host.action_requested.connect(func(a: Dictionary) -> void: actions.append(a))
	var err := ""
	realm.set_snapshot(_retreat_card(true))
	SanctumLayoutTests._force_control_layout(realm)
	var card := host.get("_active_modal") as ResolveScreen
	if card == null or not host.has_active_modal():
		err = "the retreat card did not open in the host"
	elif _label(card, "%BannerLabel").text != "Pulled back" or _label(card, "%OutcomeLine").text != "Our task is not done. This story is not over yet.":
		err = "card text: %s / %s" % [_label(card, "%BannerLabel").text, _label(card, "%OutcomeLine").text]
	else:
		var button := card.get_node("%SanctumButton") as Button
		button.pressed.emit()
		if actions.size() != 1 or str(actions[0].get("type", "")) != "stage.retreat_return":
			err = "the button sent %s" % str(actions)
		elif host.has_active_modal():
			err = "the card stayed open after the button"
	vp.free()
	return { "ok": err.is_empty(), "error": err }


const RETURN_ACTION := { "type": "stage.return_home" }


## A fixture may give the amounts as { ase, ekwan }: they become the `gathered` block of carry_home_preview,
## which is what the panel reads (it sums every source in the packs).
static func _confirm_payload(carry: Dictionary) -> Dictionary:
	var preview := carry.duplicate(true)
	if carry.has("ase") and not carry.has("gathered"):
		preview["gathered"] = { "ase": carry["ase"], "ekwan": carry.get("ekwan", 0), "rows": [], "has_fight_rows": false, "has_found_rows": false }
	return { "confirm": true, "action": RETURN_ACTION.duplicate(), "carry": preview }


## The core writes return_home_result only on a FAILED escape. A success goes to the scout-return
## card. The panel therefore opens before the action; the result display stays for the failure.
static func _t_return_confirm_before_dispatch() -> Dictionary:
	var screen := (load("res://ui/screens/venture/StageExploreScreen.tscn") as PackedScene).instantiate() as Control
	var actions: Array = []
	var modals: Array = []
	screen.connect("action_requested", func(a: Dictionary) -> void: actions.append(a))
	screen.connect("modal_requested", func(id: StringName, payload: Dictionary) -> void: modals.append([id, payload]))
	screen.set("_cached_return_action", RETURN_ACTION.duplicate())
	screen.set("_cached_carry_preview", { "ase": 4, "ekwan": 0, "overcome": 1, "total": 3 })
	screen.call("_on_return_pressed")
	screen.free()
	if not actions.is_empty():
		return { "ok": false, "error": "the Return button dispatched before the confirmation" }
	if modals.size() != 1 or modals[0][0] != &"realm.return_home" or not bool(modals[0][1].get("confirm", false)):
		return { "ok": false, "error": "expected one confirmation request, got %s" % str(modals) }
	var payload: Dictionary = modals[0][1]
	if payload["action"] != RETURN_ACTION or payload["carry"].get("ase", 0) != 4 or payload.has("party"):
		return { "ok": false, "error": "confirmation payload wrong: %s" % str(payload) }
	return { "ok": true }


static func _t_return_confirm_buttons() -> Dictionary:
	var m := _mount_scene(ReturnHomeScene)
	var modal: ReturnHomeModal = m[1]
	var actions: Array = []
	var dismissed: Array = []
	modal.action_requested.connect(func(a: Dictionary) -> void: actions.append(a))
	modal.dismiss_requested.connect(func() -> void: dismissed.append(1))
	var confirm := modal.get_node("%ConfirmButton") as Button
	var cancel := modal.get_node("%CancelButton") as Button
	modal.present(_confirm_payload({ "ase": 4, "ekwan": 0, "overcome": 1, "total": 3 }))
	if not actions.is_empty() or not (modal.get_node("%ConfirmRow") as Control).visible or (modal.get_node("%ContinueButton") as Control).visible:
		return _fail(m, "the panel must open with Confirm and Cancel and no dispatch")
	for b in [confirm, cancel]:
		var size: Vector2 = (b as Button).get_combined_minimum_size()
		if size.x < 48.0 or size.y < 48.0 or (b as Button).text.is_empty():
			return _fail(m, "a confirm button is under 48x48 or has no text")
	# Cancel sends nothing.
	cancel.pressed.emit()
	if not actions.is_empty() or dismissed.size() != 1:
		return _fail(m, "Cancel: actions=%d dismissed=%d" % [actions.size(), dismissed.size()])
	# Esc is Cancel.
	modal.present(_confirm_payload({}))
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	modal._input(esc)
	if not actions.is_empty() or dismissed.size() != 2:
		return _fail(m, "Esc: actions=%d dismissed=%d" % [actions.size(), dismissed.size()])
	# Confirm sends the action once; a second press does nothing.
	modal.present(_confirm_payload({}))
	confirm.pressed.emit()
	confirm.pressed.emit()
	if actions != [RETURN_ACTION] or not confirm.disabled:
		return _fail(m, "Confirm: actions=%s" % str(actions))
	return _pass(m)


static func _t_return_confirm_zero_and_failure() -> Dictionary:
	var m := _mount_scene(ReturnHomeScene)
	var modal: ReturnHomeModal = m[1]
	var gathered := modal.get_node("%GatheredLabel") as Label
	var risk := modal.get_node("%RiskLabel") as Label
	var warning := modal.get_node("%WarningLabel") as Label
	var keeps := modal.get_node("%KeepsLabel") as Label
	# Nothing in the packs (D-110 F1 kept: no risk line): the empty line, the question, the escape line and the keeps line.
	for carry in [{ "ase": 0, "ekwan": 0, "overcome": 0, "total": 2, "nothing_new": false }, {},
			{ "ase": 0, "ekwan": 0, "overcome": 1, "total": 2, "nothing_new": true }]:
		modal.present(_confirm_payload(carry))
		if gathered.text != CarriedStrings.GATHERED_EMPTY or not gathered.visible or risk.visible or not warning.visible or not keeps.visible:
			return _fail(m, "empty packs %s: gathered=\"%s\" risk=%s" % [str(carry), gathered.text, risk.visible])
	# The subtitle stays hidden in confirm mode.
	if (modal.get_node("%SubtitleLabel") as Control).visible:
		return _fail(m, "confirmation shows a subtitle")
	# The failed-escape display: no gathered, risk or keeps line; Continue dismisses.
	var actions: Array = []
	modal.action_requested.connect(func(a: Dictionary) -> void: actions.append(a))
	modal.present({ "result": { "success": false, "message": "The way is blocked." }, "carry": { "ase": 4, "ekwan": 1, "overcome": 1 } })
	if gathered.visible or risk.visible or keeps.visible or warning.visible \
			or (modal.get_node("%ConfirmRow") as Control).visible or not (modal.get_node("%ContinueButton") as Control).visible:
		return _fail(m, "failed-escape display changed")
	if (modal.get_node("%SubtitleLabel") as Label).text != CarriedStrings.FAILED_SUBTITLE or not (modal.get_node("%SubtitleLabel") as Control).visible \
			or (modal.get_node("%BodyLabel") as Label).text != "The way is blocked.":
		return _fail(m, "failed-escape subtitle or core body wrong")
	(modal.get_node("%ContinueButton") as Button).pressed.emit()
	if actions != [{ "type": "stage.dismiss_overlay" }]:
		return _fail(m, "Continue action changed: %s" % str(actions))
	return _pass(m)


static func _prebattle_payload(data_extra: Dictionary) -> Dictionary:
	var combat := (load("res://ui/screens/combat/CombatBoardScreen.tscn") as PackedScene).instantiate() as CombatBoardScreen
	var emitted: Array = []
	combat.modal_requested.connect(func(_id: StringName, payload: Dictionary) -> void: emitted.append(payload.duplicate(true)))
	combat.set("_round_label", combat.get_node("RoundLabel"))
	combat.set("_objective_label", combat.get_node("ObjectiveLabel"))
	var data := { "round_phase": "pre_combat", "board_cols": 2, "board_rows": 2,
		"actors": [_actor("Ama"), _actor("Kofi")], "objective_state": { "type": EncounterResolutionModes.COMBAT },
		"retreat_eligible": true, "retreat_ase_cost": 13, "retreat_affordable": true }
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
	if button.disabled or button.text != "Retreat (13 Ase)" or note.visible:
		return _fail(m, "affordable retreat: disabled=%s text=%s" % [button.disabled, button.text])
	# Not affordable: disabled, price and reason in the text, 48x48 target.
	payload = _prebattle_payload({ "retreat_affordable": false })
	modal.present(payload)
	if not button.disabled or not button.text.begins_with("Retreat (13 Ase)") or CarriedStrings.RETREAT_UNAFFORDABLE not in button.text:
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
	# No odds line, no carry preview: the payload holds neither.
	payload = _prebattle_payload({})
	modal.present(payload)
	if payload.has("carry") or payload.has("party") or button.text != "Retreat (13 Ase)" or "\n" in button.text:
		return _fail(m, "retreat button shows more than the price: %s" % button.text)
	# The retreat action is unchanged.
	if modal.get("_retreat_action") != { "type": "encounter.retreat", "slot": "cta.retreat" }:
		return _fail(m, "the retreat action changed")
	return _pass(m)


static func _t_carried_no_amounts() -> Dictionary:
	var pattern := RegEx.create_from_string("text = \"[^\"]*[0-9]+\\s*(Ase|Ekwan)")
	for path in ["res://ui/overlays/realm/PrebattleModal.tscn",
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
		screen.set_snapshot(_snap([_row("Settled when you left", 7, "settled_on_leave")], { "ledger_seen": false }, false))
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


## params.lost holds every death of the stage. Kofi died in an EARLIER fight: no row of this fight
## carries him, and the count still reads from params (4 started, 3 home).
static func _t_home_earlier_death() -> Dictionary:
	var before := _set_reduced(true)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var snap := _stage_home(["Kofi"], 3, 4)
	var summary: Array = []
	for n in ["Ama", "Esi", "Yaw"]:
		summary.append(_summary(n))
	snap["data"]["emotion_summary"] = summary
	snap["data"]["actors"] = []
	screen.set_snapshot(snap)
	var texts := _visible_texts(screen)
	var count := _label(screen, "%HomeCountLabel").text
	StopMarkMotion.reduced = before
	if count != "alive 3 of 4":
		return _fail(m, "count is \"%s\"" % count)
	var lost_lines := texts.filter(func(t: Variant) -> bool: return "did not make it back" in str(t))
	if lost_lines != ["Kofi did not make it back."]:
		return _fail(m, "lost lines: %s" % str(lost_lines))
	var homes := texts.filter(func(t: Variant) -> bool: return str(t) == "alive")
	if homes.size() != 3:
		return _fail(m, "expected 3 home marks, got %d" % homes.size())
	# The same death named by a row of this fight shows once there, not twice.
	StopMarkMotion.reduced = true
	screen.set_snapshot(_stage_home(["Kofi"], 3, 4))
	var again := _visible_texts(screen).filter(func(t: Variant) -> bool: return "did not make it back" in str(t))
	StopMarkMotion.reduced = before
	if again != ["Kofi did not make it back."]:
		return _fail(m, "a matched name shows %d times" % again.size())
	return _pass(m)


## The Thread, objective and intel lines read real fields. No derivation from actors remains.
static func _t_no_placeholder() -> Dictionary:
	var code := FileAccess.get_file_as_string("res://ui/screens/venture/ResolveScreen.gd")
	if code.is_empty():
		return { "ok": false, "error": "cannot read ResolveScreen.gd" }
	for needle in ["_thread_whole", "PLACEHOLDER", "hypothetical", "echoes_survived\", -1"]:
		if needle in code:
			return { "ok": false, "error": "ResolveScreen.gd still holds \"%s\"" % needle }
	for field in ["thread_whole", "objective_overcome", "intel_gained"]:
		if "\"%s\"" % field not in code:
			return { "ok": false, "error": "ResolveScreen.gd does not read %s" % field }
	return { "ok": true }


## Real chain: a real stage (FlowRuntime, StageExploreSnapshotBuilder), a real RealmShell and
## StageExploreScreen, a real ModalHost, the real %ReturnButton. No private field is set, so the
## carry payload proves the cache fill from the snapshot. Not testable headless: the real mouse
## click (the test emits the button's `pressed`) and the focus ring (only focus ownership is checked).
static func _t_return_real_host() -> Dictionary:
	var fx := StageCameraSelectTests._make_fixture("payout_return")
	if fx.is_empty():
		return { "ok": false, "error": "could not build the real stage fixture" }
	var vp: SubViewport = fx["viewport"]
	var realm: RealmShell = fx["realm"]
	var stage: StageExploreScreen = fx["stage"]
	var snap: Dictionary = fx["snap"]
	var host := preload("res://ui/components/ModalHost.tscn").instantiate() as ModalHost
	vp.add_child(host)
	var modals: Array = []
	var actions: Array = []
	realm.modal_requested.connect(func(id: StringName, payload: Dictionary) -> void:
		modals.append([id, payload.duplicate(true)])
		host.present_modal_for_id(id, realm.modal_scene_for(id), payload))
	host.action_requested.connect(func(a: Dictionary) -> void: actions.append(a))
	var ret := stage.get_node("%ReturnButton") as Button
	var err := ""
	var data: Dictionary = snap["data"]
	# 1. The press opens the confirmation and dispatches nothing.
	ret.grab_focus()
	ret.pressed.emit()
	if modals.size() != 1 or modals[0][0] != &"realm.return_home" or not host.has_active_modal() or not actions.is_empty():
		err = "press: modals=%d active=%s actions=%d" % [modals.size(), host.has_active_modal(), actions.size()]
	if err.is_empty():
		var payload: Dictionary = modals[0][1]
		if payload.get("carry") != data["carry_home_preview"] or payload.has("party") or not bool(payload.get("confirm", false)):
			err = "payload does not match the snapshot: %s vs %s" % [str(payload.get("carry")), str(data["carry_home_preview"])]
	# 2. Confirm sends one stage.return_home; a second press adds none.
	if err.is_empty():
		var modal := host.get_node("%ModalSlot/ReturnHomeModal") as ReturnHomeModal
		var confirm := modal.get_node("%ConfirmButton") as Button
		confirm.pressed.emit()
		confirm.pressed.emit()
		if actions != [{ "type": "stage.return_home" }] or host.has_active_modal():
			err = "Confirm: actions=%s active=%s" % [str(actions), host.has_active_modal()]
	# 3. Cancel: no action, the modal closes, focus returns to the Return button.
	if err.is_empty():
		actions.clear()
		ret.grab_focus()
		ret.pressed.emit()
		# A closed modal waits for deletion, so the open one is read from the host, not by node name.
		var cancel := (host.get("_active_modal") as Node).get_node("%CancelButton") as Button
		cancel.pressed.emit()
		if not actions.is_empty() or host.has_active_modal() or vp.gui_get_focus_owner() != ret:
			err = "Cancel: actions=%d active=%s focus=%s" % [actions.size(), host.has_active_modal(), str(vp.gui_get_focus_owner())]
	# 4. Esc through the viewport input path does the same.
	if err.is_empty():
		ret.grab_focus()
		ret.pressed.emit()
		var esc := InputEventAction.new()
		esc.action = &"ui_cancel"
		esc.pressed = true
		vp.push_input(esc)
		if not actions.is_empty() or host.has_active_modal() or vp.gui_get_focus_owner() != ret:
			err = "Esc: actions=%d active=%s focus=%s" % [actions.size(), host.has_active_modal(), str(vp.gui_get_focus_owner())]
	# 5. The failed escape: the result modal shows with Continue, no carried figure.
	if err.is_empty():
		var failed := snap.duplicate(true)
		failed["data"]["return_home_result"] = { "success": false, "message": "The way is blocked." }
		realm.set_snapshot(failed)
		SanctumLayoutTests._force_control_layout(realm)
		if not host.has_active_modal():
			stage.call("_apply_pending_overlay")
		if not host.has_active_modal() or host.active_modal_id() != &"realm.return_home":
			err = "failed escape: no result modal"
		else:
			var modal2 := host.get("_active_modal") as ReturnHomeModal
			var carried := modal2.get_node("%GatheredLabel") as Control
			if carried.visible or (modal2.get_node("%ConfirmRow") as Control).visible \
					or not (modal2.get_node("%ContinueButton") as Control).visible:
				err = "failed escape display wrong"
			else:
				(modal2.get_node("%ContinueButton") as Button).pressed.emit()
				if actions != [{ "type": "stage.dismiss_overlay" }]:
					err = "failed escape Continue sent %s" % str(actions)
	vp.free()
	return { "ok": err.is_empty(), "error": err }


# ── Phase 7: the standoff card, the warning, the packs ──────────────────────

const StandoffStrings := preload("res://ui/components/StandoffPresentation.gd")
const CombatScene := preload("res://ui/screens/combat/CombatBoardScreen.tscn")
const INFO_BLUE := Color("#7AB5C8")


## The real producer, so the keys cannot drift from the card the core sends.
static func _standoff_card(count: int, can_sanctum: bool, cause: String = "unknown", froze: Array = [], calmed: Array = []) -> Dictionary:
	return VentureResolveSnapshotBuilder.build_standoff_snapshot({ "standoff_count": count, "can_go_sanctum": can_sanctum,
		"cause": cause, "froze_names": froze, "calmed_names": calmed }, 3)


## Written out from phase7-copy-final.md on purpose: a changed character must fail this test.
static func _t_standoff_strings() -> Dictionary:
	var want := {
		"TITLE": "Nobody moved",
		"BODY_GENERIC": "Neither side would strike. The party stepped back.",
		"BODY_FROZE_ONE": "%s could not move. The party stepped back.",
		"BODY_FROZE_TWO": "%s and %s could not move. The party stepped back.",
		"BODY_BLOCKED": "No one could get through. The party stepped back.",
		"PACKS_LINE": "Their packs are as they were.",
		"OPEN_FIGHT_LINE": "The task is still there.",
		"CALM_LINE": "%s breathed out.",
		"REPEAT_HINT_1": "It went the same way last time.",
		"REPEAT_HINT_2": "Maybe they need rest.",
		"BTN_PATH": "Back to the path",
		"BTN_SANCTUM": "To the Sanctum",
		"WARN_LEVEL_1": "Nobody is moving.",
		"WARN_LEVEL_2": "Nobody wants to go first.",
		"WARN_BARK": "Not yet. I can't.",
		"PREBATTLE_STALLED": "They stalled here before.",
	}
	var consts: Dictionary = (StandoffStrings as Script).get_script_constant_map()
	for key in want:
		if str(consts.get(key, "<missing>")) != want[key]:
			return { "ok": false, "error": "%s is \"%s\"" % [key, str(consts.get(key, "<missing>"))] }
	var cards := {
		"PayoutCausePresentation.PACKS_LOST_LINE": [PayoutCausePresentation.PACKS_LOST_LINE, "The party fell, and the packs were lost."],
		"SITUATION_MONEY": [PayoutCausePresentation.SITUATION_MONEY % 12, "They found 12 Ase. It goes in the packs."],
		"SITUATION_CLAIMANT_GOOD": [PayoutCausePresentation.SITUATION_CLAIMANT_GOOD % 20, "The party was given 20 Ase for the way. It goes in the packs."],
		"ENCOUNTERS_COUNT": [PayoutCausePresentation.ENCOUNTERS_COUNT % 3, "Fights won on this path: 3."],
		"GATHERED_EMPTY": [CarriedStrings.GATHERED_EMPTY, "Nothing is in their packs."],
		"NOTHING_GATHERED": [PayoutCausePresentation.NOTHING_GATHERED, "Nothing was gathered."],
	}
	for key in cards:
		if cards[key][0] != cards[key][1]:
			return { "ok": false, "error": "%s is \"%s\"" % [key, cards[key][0]] }
	if StandoffStrings.repeat_hint(1) != "" or StandoffStrings.repeat_hint(2) != want["REPEAT_HINT_1"] \
			or StandoffStrings.repeat_hint(3) != want["REPEAT_HINT_2"] or StandoffStrings.repeat_hint(9) != want["REPEAT_HINT_2"]:
		return { "ok": false, "error": "repeat hint by standoff_count" }
	return { "ok": true }


static func _button_error(button: Button, what: String) -> String:
	if not button.visible or button.disabled or button.custom_minimum_size.y < 56.0 or button.custom_minimum_size.x < 48.0:
		return "%s: visible=%s disabled=%s min=%s" % [what, button.visible, button.disabled, str(button.custom_minimum_size)]
	return ""


## First standoff: one button, back to the path. Second on: the Sanctum button joins. Each button sends its
## slot's action whole (the Sanctum one carries to_sanctum), once per press.
static func _t_standoff_buttons() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var sent: Array = []
	var dismissed: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	screen.dismiss_requested.connect(func() -> void: dismissed.append(1))
	var path := screen.get_node("%NextStageButton") as Button
	var sanctum := screen.get_node("%SanctumButton") as Button
	var first := _standoff_card(1, false)
	screen.set_snapshot(first)
	if _label(screen, "%BannerLabel").text != "Nobody moved" or _label(screen, "%ReasonLabel").text != StandoffStrings.BODY_GENERIC:
		return _fail(m, "first card title or body: %s / %s" % [_label(screen, "%BannerLabel").text, _label(screen, "%ReasonLabel").text])
	if _label(screen, "%PacksLine").text != "Their packs are as they were." or _label(screen, "%OpenFightLine").text != "The task is still there.":
		return _fail(m, "packs or open-fight line wrong")
	if (screen.get_node("%CalmLine") as Control).visible or (screen.get_node("%RepeatLine") as Control).visible:
		return _fail(m, "the first standoff shows a calm or repeat line")
	var err := _button_error(path, "path button")
	if not err.is_empty():
		return _fail(m, err)
	if path.text != "Back to the path" or sanctum.visible:
		return _fail(m, "first card buttons: path=\"%s\" sanctum visible=%s" % [path.text, sanctum.visible])
	for hidden in ["%FightHeader", "%EarningsSummary", "%Ledger", "%BodyViewport"]:
		if (screen.get_node(hidden) as Control).visible:
			return _fail(m, "standoff card shows %s" % hidden)
	for t in _visible_texts(screen):
		if str(t) in ["VICTORY", "DEFEAT", "Leave"]:
			return _fail(m, "standoff card shows \"%s\"" % str(t))
	path.pressed.emit()
	if sent != [first["actions"]["cta.continue"]] or dismissed.size() != 1:
		return _fail(m, "path button sent %s" % str(sent))
	# Second standoff: both buttons, the first repeat hint.
	sent.clear()
	var second := _standoff_card(2, true)
	screen.set_snapshot(second)
	if _label(screen, "%RepeatLine").text != "It went the same way last time." or not (screen.get_node("%RepeatLine") as Control).visible:
		return _fail(m, "second card repeat hint: \"%s\"" % _label(screen, "%RepeatLine").text)
	err = _button_error(path, "path button (second)") + _button_error(sanctum, "sanctum button")
	if not err.is_empty():
		return _fail(m, err)
	if sanctum.text != "To the Sanctum" or path.text != "Back to the path":
		return _fail(m, "second card button texts: %s / %s" % [sanctum.text, path.text])
	var gap: int = sanctum.get_parent().get_theme_constant("separation")
	if gap < 8:
		return _fail(m, "gap between the two buttons is %d" % gap)
	sanctum.pressed.emit()
	if sent != [second["actions"]["cta.sanctum"]] or not bool(sent[0].get("to_sanctum", false)):
		return _fail(m, "sanctum button sent %s" % str(sent))
	sent.clear()
	path.pressed.emit()
	if sent != [second["actions"]["cta.continue"]] or sent[0].has("to_sanctum"):
		return _fail(m, "path button (second) sent %s" % str(sent))
	# A third standoff reads the second hint; the next normal card gets its body back.
	screen.set_snapshot(_standoff_card(3, true))
	if _label(screen, "%RepeatLine").text != "Maybe they need rest.":
		return _fail(m, "third card repeat hint: \"%s\"" % _label(screen, "%RepeatLine").text)
	screen.set_snapshot(_snap([], { "ledger_seen": true }))
	if not (screen.get_node("%BodyViewport") as Control).visible or (screen.get_node("%StandoffLines") as Control).visible or sanctum.visible:
		return _fail(m, "the standoff layout leaked into the next card")
	return _pass(m)


static func _t_standoff_causes() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var body := _label(screen, "%ReasonLabel")
	var cases := [
		["froze", ["Ama"], "Ama could not move. The party stepped back."],
		["froze", ["Ama", "Kofi"], "Ama and Kofi could not move. The party stepped back."],
		["froze", [], "Neither side would strike. The party stepped back."],
		["blocked", [], "No one could get through. The party stepped back."],
		["unknown", ["Ama"], "Neither side would strike. The party stepped back."],
		["", [], "Neither side would strike. The party stepped back."],
	]
	for c in cases:
		screen.set_snapshot(_standoff_card(1, false, c[0], c[1]))
		if body.text != c[2]:
			return _fail(m, "cause %s %s: body \"%s\"" % [c[0], str(c[1]), body.text])
	var calm := _label(screen, "%CalmLine")
	screen.set_snapshot(_standoff_card(1, false, "froze", ["Ama"], ["Ama"]))
	if not (calm as Control).visible or calm.text != "Ama breathed out.":
		return _fail(m, "one calm name: \"%s\"" % calm.text)
	screen.set_snapshot(_standoff_card(1, false, "froze", ["Ama", "Kofi"], ["Ama", "Kofi"]))
	if calm.text != "Ama and Kofi breathed out.":
		return _fail(m, "two calm names: \"%s\"" % calm.text)
	screen.set_snapshot(_standoff_card(1, false, "froze", ["Ama"], []))
	if (calm as Control).visible:
		return _fail(m, "the calm line shows with no names")
	return _pass(m)


## Real chain: a real RealmShell, a real ModalHost, the real producer, the real buttons.
static func _t_standoff_real_host() -> Dictionary:
	var fx := StageCameraSelectTests._make_fixture("payout_standoff")
	if fx.is_empty():
		return { "ok": false, "error": "could not build the real stage fixture" }
	var vp: SubViewport = fx["viewport"]
	var realm: RealmShell = fx["realm"]
	var host := preload("res://ui/components/ModalHost.tscn").instantiate() as ModalHost
	vp.add_child(host)
	var actions: Array = []
	realm.modal_requested.connect(func(id: StringName, payload: Dictionary) -> void:
		host.present_modal_for_id(id, realm.modal_scene_for(id), payload))
	host.action_requested.connect(func(a: Dictionary) -> void: actions.append(a))
	var err := ""
	var first := _standoff_card(1, false, "froze", ["Ama"], ["Ama"])
	realm.set_snapshot(first)
	SanctumLayoutTests._force_control_layout(realm)
	var card := host.get("_active_modal") as ResolveScreen
	if card == null or not host.has_active_modal():
		err = "the standoff card did not open in the host"
	elif _label(card, "%BannerLabel").text != "Nobody moved" or _label(card, "%ReasonLabel").text != "Ama could not move. The party stepped back.":
		err = "card text: %s / %s" % [_label(card, "%BannerLabel").text, _label(card, "%ReasonLabel").text]
	elif (card.get_node("%SanctumButton") as Control).visible:
		err = "the first card shows the Sanctum button"
	else:
		(card.get_node("%NextStageButton") as Button).pressed.emit()
		if actions != [first["actions"]["cta.continue"]] or host.has_active_modal():
			err = "the path button sent %s (open=%s)" % [str(actions), host.has_active_modal()]
	if err.is_empty():
		actions.clear()
		var second := _standoff_card(2, true)
		realm.set_snapshot(second)
		SanctumLayoutTests._force_control_layout(realm)
		card = host.get("_active_modal") as ResolveScreen
		if card == null or not host.has_active_modal() or not (card.get_node("%SanctumButton") as Control).visible:
			err = "the second card did not open with the Sanctum button"
		else:
			(card.get_node("%SanctumButton") as Button).pressed.emit()
			if actions != [second["actions"]["cta.sanctum"]] or not bool(actions[0].get("to_sanctum", false)) or host.has_active_modal():
				err = "the Sanctum button sent %s" % str(actions)
	vp.free()
	return { "ok": err.is_empty(), "error": err }


static func _board_actor(who: String, col: int) -> Dictionary:
	return { "id": "id_" + who, "name": who, "faction": "echo", "grid_pos": { "col": col, "row": 1 },
		"hp": 10, "current_hp": 10, "max_hp": 10, "emotional_status": "grounded" }


static func _board_snap(extra: Dictionary) -> Dictionary:
	var data := { "encounter_id": "stall_ui", "board_cols": 4, "board_rows": 4, "round": 9, "round_phase": "actor_turn",
		"combat_over": false, "actors": [_board_actor("Ama", 1), _board_actor("Kofi", 2)],
		"objective_state": { "type": "combat" } }
	data.merge(extra, true)
	return { "type": "flow.encounter", "meta": { "t": 1 }, "data": data, "actions": {} }


## The warning: Info blue, a 0.4 s fade in, a second line at level 2 with one bark, gone at once on progress.
static func _t_warning_levels() -> Dictionary:
	var before := _set_reduced(false)
	var m := _mount_scene(CombatScene)
	var screen: CombatBoardScreen = m[1]
	var line := screen.get_node("%StallLabel") as Label
	var panel := screen.get_node("%StallPanel") as Control
	var err := ""
	screen.set_snapshot(_board_snap({}))
	if panel.visible:
		err = "the warning shows at level 0"
	if err.is_empty():
		screen.set_snapshot(_board_snap({ "stall_level": 1 }))
		var tween := screen.get("_stall_tween") as Tween
		if not panel.visible or line.text != "Nobody is moving." or tween == null or panel.modulate.a != 0.0:
			err = "level 1: visible=%s text=\"%s\" alpha=%s" % [panel.visible, line.text, panel.modulate.a]
		else:
			tween.custom_step(0.2)
			var half := panel.modulate.a
			tween.custom_step(0.3)
			if half <= 0.0 or half >= 1.0 or not is_equal_approx(panel.modulate.a, 1.0):
				err = "fade: half=%s end=%s" % [half, panel.modulate.a]
		var colour := line.get_theme_color("font_color")
		if err.is_empty() and (colour.r > colour.b or not colour.is_equal_approx(INFO_BLUE)):
			err = "the line is not Info blue: %s" % str(colour)
	if err.is_empty():
		screen.set_snapshot(_board_snap({ "stall_level": 1 }))
		if not panel.visible or not is_equal_approx(panel.modulate.a, 1.0):
			err = "a repeat snapshot at the same level restarted the fade (alpha %s)" % panel.modulate.a
	if err.is_empty():
		# Level 2 with no name: the second line only, no bark.
		screen.set_snapshot(_board_snap({ "stall_level": 2, "stall_froze_name": "" }))
		var popups := (screen.get_node("%BarkPopupLayer") as Node).get("_active_popups") as Dictionary
		if line.text != "Nobody wants to go first." or not popups.is_empty():
			err = "level 2 without a name: text=\"%s\" popups=%d" % [line.text, popups.size()]
	if err.is_empty():
		screen.set_snapshot(_board_snap({ "stall_level": 0 }))
		if panel.visible:
			err = "the line did not clear at once on progress"
	if err.is_empty():
		# Level 2 with the Echo that froze: one bark from that Echo, once per fight.
		screen.set_snapshot(_board_snap({ "stall_level": 2, "stall_froze_name": "Ama" }))
		var popups2 := (screen.get_node("%BarkPopupLayer") as Node).get("_active_popups") as Dictionary
		if line.text != "Nobody wants to go first." or not popups2.has("id_Ama") or popups2.size() != 1:
			err = "level 2 bark: text=\"%s\" popups=%s" % [line.text, str(popups2.keys())]
		else:
			var label := ((popups2["id_Ama"] as Dictionary)["node"] as Node).find_children("*", "Label", true, false)
			if label.is_empty() or (label[0] as Label).text != "Not yet. I can't.":
				err = "the bark text is wrong"
	if err.is_empty():
		screen.set_snapshot(_board_snap({ "stall_level": 0 }))
		screen.set_snapshot(_board_snap({ "stall_level": 2, "stall_froze_name": "Kofi" }))
		var popups3 := (screen.get_node("%BarkPopupLayer") as Node).get("_active_popups") as Dictionary
		if popups3.has("id_Kofi"):
			err = "a second bark played in the same fight"
	StopMarkMotion.reduced = before
	m[0].free()
	return { "ok": err.is_empty(), "error": err }


static func _t_prebattle_stalled() -> Dictionary:
	var m := _mount_scene(PrebattleScene)
	var pre: PrebattleModal = m[1]
	var line := pre.get_node("%StalledLabel") as Label
	pre.present(_prebattle_payload({}))
	if line.visible:
		return _fail(m, "the stalled line shows without the flag")
	pre.present(_prebattle_payload({ "stalled_before": true }))
	if not line.visible or line.text != "They stalled here before.":
		return _fail(m, "stalled line: visible=%s \"%s\"" % [line.visible, line.text])
	pre.present(_prebattle_payload({ "stalled_before": false }))
	if line.visible:
		return _fail(m, "the stalled line stayed after the flag fell")
	for b in [pre.get_node("%RetreatButton"), pre.get_node("%EnterCombatButton")]:
		if (b as Button).custom_minimum_size.y < 56.0:
			return _fail(m, "a pre-battle button is under 56 high")
	return _pass(m)


## data.return_confirm_requested opens the same confirmation as the Return button, once per request.
static func _t_confirm_requested_once() -> Dictionary:
	var fx := StageCameraSelectTests._make_fixture("payout_confirm_requested")
	if fx.is_empty():
		return { "ok": false, "error": "could not build the real stage fixture" }
	var vp: SubViewport = fx["viewport"]
	var realm: RealmShell = fx["realm"]
	var snap: Dictionary = fx["snap"]
	var host := preload("res://ui/components/ModalHost.tscn").instantiate() as ModalHost
	vp.add_child(host)
	var modals: Array = []
	var actions: Array = []
	realm.modal_requested.connect(func(id: StringName, payload: Dictionary) -> void:
		modals.append([id, payload.duplicate(true)])
		host.present_modal_for_id(id, realm.modal_scene_for(id), payload))
	host.action_requested.connect(func(a: Dictionary) -> void: actions.append(a))
	var flagged := snap.duplicate(true)
	flagged["data"]["return_confirm_requested"] = true
	var err := ""
	realm.set_snapshot(snap)
	if not modals.is_empty():
		err = "a snapshot without the flag opened a modal"
	if err.is_empty():
		realm.set_snapshot(flagged)
		if modals.size() != 1 or modals[0][0] != &"realm.return_home" or not bool(modals[0][1].get("confirm", false)) or not actions.is_empty():
			err = "first flagged snapshot: modals=%d actions=%d" % [modals.size(), actions.size()]
	if err.is_empty():
		var preview: Dictionary = flagged["data"]["carry_home_preview"]
		if modals[0][1].get("carry") != preview or not preview.has("gathered"):
			err = "the confirmation carry is not the snapshot's carry_home_preview"
	if err.is_empty():
		realm.set_snapshot(flagged)
		realm.set_snapshot(flagged)
		if modals.size() != 1:
			err = "a refresh re-opened the confirmation (%d opens)" % modals.size()
	if err.is_empty():
		# Cancel sends nothing; a refresh while the flag is still set does not bring it back.
		var cancel := (host.get("_active_modal") as Node).get_node("%CancelButton") as Button
		cancel.pressed.emit()
		realm.set_snapshot(flagged)
		if not actions.is_empty() or modals.size() != 1 or host.has_active_modal():
			err = "Cancel: actions=%d opens=%d open=%s" % [actions.size(), modals.size(), host.has_active_modal()]
	if err.is_empty():
		# A snapshot without the flag, then a new request: opens again, and Confirm sends the action once.
		realm.set_snapshot(snap)
		realm.set_snapshot(flagged)
		if modals.size() != 2 or not host.has_active_modal():
			err = "a new request did not open (opens=%d)" % modals.size()
		else:
			var confirm := (host.get("_active_modal") as Node).get_node("%ConfirmButton") as Button
			confirm.pressed.emit()
			confirm.pressed.emit()
			if actions != [{ "type": "stage.return_home" }]:
				err = "Confirm sent %s" % str(actions)
	vp.free()
	return { "ok": err.is_empty(), "error": err }


static func _gathered_preview(ase: int, ekwan: int) -> Dictionary:
	return { "ase": ase, "ekwan": ekwan, "overcome": 1, "total": 3, "nothing_new": ase + ekwan == 0,
		"gathered": { "ase": ase, "ekwan": ekwan, "rows": [], "has_fight_rows": ase > 0, "has_found_rows": false } }


static func _t_gathered_block() -> Dictionary:
	var m := _mount_scene(ReturnHomeScene)
	var modal: ReturnHomeModal = m[1]
	var gathered := modal.get_node("%GatheredLabel") as Label
	var risk := modal.get_node("%RiskLabel") as Label
	var keeps := modal.get_node("%KeepsLabel") as Label
	var actions: Array = []
	modal.action_requested.connect(func(a: Dictionary) -> void: actions.append(a))
	var cases := [[12, 3, "In their packs: 12 Ase and 3 Ekwan."], [12, 0, "In their packs: 12 Ase."],
		[0, 3, "In their packs: 3 Ekwan."], [0, 0, "Nothing is in their packs."]]
	for c in cases:
		modal.present({ "confirm": true, "action": RETURN_ACTION.duplicate(), "carry": _gathered_preview(c[0], c[1]) })
		if not gathered.visible or gathered.text != c[2]:
			return _fail(m, "gathered %d/%d: \"%s\"" % [c[0], c[1], gathered.text])
		# Jeff's lines stay: the risk line with an amount, the keeps line always.
		if risk.visible != (c[0] + c[1] > 0) or (c[0] + c[1] > 0 and risk.text != "Not all of it will survive the escape. What cannot be carried will be lost."):
			return _fail(m, "risk line for %d/%d: visible=%s" % [c[0], c[1], risk.visible])
		if not keeps.visible or keeps.text != "The path still waits.":
			return _fail(m, "keeps line missing")
	# The block reads `gathered`, not the older top-level amounts.
	modal.present({ "confirm": true, "action": RETURN_ACTION.duplicate(), "carry": { "ase": 99, "ekwan": 99,
		"gathered": { "ase": 6, "ekwan": 0 } } })
	if gathered.text != "In their packs: 6 Ase.":
		return _fail(m, "the block did not read gathered: \"%s\"" % gathered.text)
	# Cancel sends nothing, Confirm sends the action once.
	(modal.get_node("%CancelButton") as Button).pressed.emit()
	if not actions.is_empty():
		return _fail(m, "Cancel sent an action")
	modal.present({ "confirm": true, "action": RETURN_ACTION.duplicate(), "carry": _gathered_preview(12, 3) })
	(modal.get_node("%ConfirmButton") as Button).pressed.emit()
	(modal.get_node("%ConfirmButton") as Button).pressed.emit()
	if actions != [RETURN_ACTION]:
		return _fail(m, "Confirm sent %s" % str(actions))
	return _pass(m)


## Found Ase waits in the packs. The money card total is the found amount (not +0), with the Found row and
## its line; the good-Claimant contact card shows its line from ase_gathered.
static func _t_found_cards() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var money := VentureResolveSnapshotBuilder.build_situation_resolve_snapshot({ "type": "money" }, "", [], [], 12, 2)
	screen.set_snapshot(money)
	if _label(screen, "%AseTotalLabel").text != "+12 Ase" or not (screen.get_node("%EarningsSummary") as Control).visible:
		return _fail(m, "money total: \"%s\"" % _label(screen, "%AseTotalLabel").text)
	var rows := _rows_in(screen, "%BreakdownSection")
	if _names(rows) != ["Found"] or (rows[0] as RewardEntryItem).delta_label.text != "+12 Ase" or not (rows[0] as RewardEntryItem).cause_button.visible:
		return _fail(m, "money rows %s" % str(_names(rows)))
	if _label(screen, "%OutcomeLine").text != "They found 12 Ase. It goes in the packs." or not (screen.get_node("%OutcomeLine") as Control).visible:
		return _fail(m, "money line: \"%s\"" % _label(screen, "%OutcomeLine").text)
	(rows[0] as RewardEntryItem).cause_button.pressed.emit()
	var tip := screen.get_node("%CauseTooltip") as CauseTooltip
	if not tip.is_open() or (tip.get_node("%BodyLabel") as Label).text != "Found along the way. It goes in their packs.":
		return _fail(m, "Found tooltip wrong")
	# Another situation (loot) carries no found Ase: no line, no earnings.
	screen.set_snapshot(VentureResolveSnapshotBuilder.build_situation_resolve_snapshot({ "type": "loot" }, "", [], [], 0, 2))
	if (screen.get_node("%OutcomeLine") as Control).visible or (screen.get_node("%EarningsSummary") as Control).visible:
		return _fail(m, "a loot card shows a found line or earnings")
	# The good Claimant.
	screen.set_snapshot({ "type": "flow.resolve", "meta": { "t": 2 }, "actions": {}, "data": { "run_type": "contact_result",
		"outcome": "good", "role_label": "Claimant", "outcome_text": "Done.", "ase_gathered": 20 } })
	if _label(screen, "%OutcomeLine").text != "The party was given 20 Ase for the way. It goes in the packs.":
		return _fail(m, "claimant line: \"%s\"" % _label(screen, "%OutcomeLine").text)
	screen.set_snapshot({ "type": "flow.resolve", "meta": { "t": 2 }, "actions": {}, "data": { "run_type": "contact_result",
		"outcome": "good", "role_label": "Claimant", "outcome_text": "Done." } })
	if (screen.get_node("%OutcomeLine") as Control).visible:
		return _fail(m, "the claimant line shows without ase_gathered")
	return _pass(m)


static func _t_packs_lost() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var lost := _row("Packs lost", 0, "packs_lost", { "lost_ase": 12, "lost_ekwan": 0 })
	var consolation := [_row("Base objectives", 13, "defeat_consolation", { "part": "base" }),
		_row("Defeat penalty", -9, "defeat_consolation", { "part": "penalty" })]
	screen.set_snapshot(_snap(consolation + [lost], { "ledger_seen": true }, false))
	var line := screen.get_node("%OutcomeLine") as Label
	if not line.visible or line.text != "The party fell, and the packs were lost.":
		return _fail(m, "defeat line: visible=%s \"%s\"" % [line.visible, line.text])
	if _names(_rows_in(screen, "%BreakdownSection")) != ["Consolation"]:
		return _fail(m, "the packs_lost row shows in the ledger: %s" % str(_names(_rows_in(screen, "%BreakdownSection"))))
	if _label(screen, "%BannerLabel").text != "DEFEAT":
		return _fail(m, "the defeat banner changed")
	screen.set_snapshot(_snap(consolation, { "ledger_seen": true }, false))
	if line.visible:
		return _fail(m, "the packs line shows without the packs_lost row")
	screen.set_snapshot(_snap([lost], { "ledger_seen": true }, true))
	if _label(screen, "%OutcomeLine").text != "The party fell, and the packs were lost.":
		return _fail(m, "the line keys on the row, so it shows whenever the row is present")
	return _pass(m)


## A normal fight win now carries one encounter_gathered row. The card stays the mid-stage card (party,
## story lines, no chips) and shows the row and the base amount.
static func _t_won_fight_midstage() -> Dictionary:
	var before := _set_reduced(true)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var row := _row("Fight won", 6, "encounter_gathered", { "kind": "combat", "gathered_ase": 6 })
	screen.set_snapshot(_midstage({ "reward_breakdown": [row], "ase_awarded": 0, "ledger_seen": false }))
	StopMarkMotion.reduced = before
	if (screen.get_node("%FightHeader") as Control).visible:
		return _fail(m, "the won fight left the mid-stage layout (chips show)")
	if (screen.get_node("%EmotionList") as Control).get_child_count() != 3:
		return _fail(m, "the party rows are missing")
	if not (screen.get_node("%StoryLines") as Control).visible:
		return _fail(m, "the story lines are missing on the mid-stage card")
	var rows := _rows_in(screen, "%BreakdownSection")
	if _names(rows) != ["Fight won"] or (rows[0] as RewardEntryItem).delta_label.text != "+6 Ase":
		return _fail(m, "gathered row: %s" % str(_names(rows)))
	if _label(screen, "%AseTotalLabel").text != "+6 Ase" or not (screen.get_node("%EarningsSummary") as Control).visible:
		return _fail(m, "total: \"%s\"" % _label(screen, "%AseTotalLabel").text)
	if PayoutCausePresentation.tooltip("encounter_gathered") != "It goes in their packs. It is safe only when the party gets out.":
		return _fail(m, "fight row tooltip wrong")
	# A win with any other row is a ledger card with chips, as before.
	screen.set_snapshot(_snap([row, _row("Bonus", 2, "objectives_overcome", { "overcome": 1, "total": 2 })], { "ledger_seen": true }))
	if not (screen.get_node("%FightHeader") as Control).visible:
		return _fail(m, "a win with another row must show the chips")
	return _pass(m)


static func _t_packs_causes() -> Dictionary:
	var names := { "encounter_gathered": "Fight won", "found_gathered": "Found", "encounters_overcome": "Fights won",
		"found_banked": "Found on the path", "nothing_overcome_yet": "Nothing was gathered." }
	for cause in names:
		if PayoutCausePresentation.row_name(cause, "x") != names[cause]:
			return { "ok": false, "error": "row name of %s is \"%s\"" % [cause, PayoutCausePresentation.row_name(cause, "x")] }
	var tips := { "encounter_gathered": "It goes in their packs. It is safe only when the party gets out.",
		"found_gathered": "Found along the way. It goes in their packs.",
		"found_banked": "Gathered along the way and carried to the Sanctum.", "nothing_overcome_yet": "Nothing was gathered." }
	for cause in tips:
		if PayoutCausePresentation.tooltip(cause) != tips[cause] or not PayoutCausePresentation.has_cause(cause):
			return { "ok": false, "error": "tooltip of %s is \"%s\"" % [cause, PayoutCausePresentation.tooltip(cause)] }
	for n in [1, 3]:
		if PayoutCausePresentation.tooltip("encounters_overcome", { "count": n }) != "Fights won on this path: %d." % n:
			return { "ok": false, "error": "encounters_overcome count line for %d" % n }
	if not PayoutCausePresentation.has_cause("encounters_overcome"):
		return { "ok": false, "error": "encounters_overcome has no tooltip" }
	# The path-end rows render with their names and the count line.
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var stage := [_row("Base objectives", 20, "objectives_overcome", { "overcome": 2, "total": 3 }),
		_row("Fights won", 12, "encounters_overcome", { "count": 2 }), _row("Found on the path", 6, "found_banked", { "count": 1 })]
	screen.set_snapshot(_snap([], { "ledger_seen": true, "stage_payout_rows": stage, "stage_payout_ase": 38 }))
	var shown := _rows_in(screen, "%StageSection")
	if _names(shown) != ["Objectives overcome", "Fights won", "Found on the path"]:
		return _fail(m, "path-end rows %s" % str(_names(shown)))
	(shown[1] as RewardEntryItem).cause_button.pressed.emit()
	var tip := screen.get_node("%CauseTooltip") as CauseTooltip
	if not tip.is_open() or (tip.get_node("%BodyLabel") as Label).text != "Fights won on this path: 2.":
		return _fail(m, "Fights won tooltip wrong")
	return _pass(m)


## Every new player string: no "home", no "stage", no percent (apart from %s and %d), no odds word, no fraction.
## The standoff card never says "Leave".
static func _t_phase7_scan() -> Dictionary:
	var texts: Array = []
	for v in (StandoffStrings as Script).get_script_constant_map().values():
		if v is String:
			texts.append(v)
	texts.append_array([PayoutCausePresentation.PACKS_LOST_LINE, PayoutCausePresentation.SITUATION_MONEY,
		PayoutCausePresentation.SITUATION_CLAIMANT_GOOD, PayoutCausePresentation.ENCOUNTERS_COUNT,
		PayoutCausePresentation.NOTHING_GATHERED, CarriedStrings.GATHERED_EMPTY])
	for cause in ["encounter_gathered", "found_gathered", "encounters_overcome", "found_banked", "nothing_overcome_yet"]:
		texts.append(PayoutCausePresentation.row_name(cause, ""))
		texts.append(PayoutCausePresentation.tooltip(cause, { "count": 2 }))
	var bad := _first_banned(texts.map(func(t: Variant) -> String: return str(t).replace("%s", "").replace("%d", "")))
	if not bad.is_empty():
		return { "ok": false, "error": "string tables: " + bad }
	for t in texts:
		var low := str(t).to_lower()
		for word in ["banked", "settled", "roll"]:
			if word in low and not (str(t) == "Found on the path"):
				return { "ok": false, "error": "\"%s\" holds \"%s\"" % [str(t), word] }
	# What the player sees on each new card.
	var reduced_before := _set_reduced(true)
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var shown: Array = []
	for card in [_standoff_card(1, false), _standoff_card(2, true, "froze", ["Ama", "Kofi"], ["Ama"]),
			_standoff_card(3, true, "blocked"), VentureResolveSnapshotBuilder.build_situation_resolve_snapshot({ "type": "money" }, "", [], [], 12, 2),
			{ "type": "flow.resolve", "meta": { "t": 2 }, "actions": {}, "data": { "run_type": "contact_result", "outcome": "good",
				"role_label": "Claimant", "outcome_text": "Done.", "ase_gathered": 20 } },
			_snap([_row("Packs lost", 0, "packs_lost")], { "ledger_seen": true }, false),
			_midstage({ "reward_breakdown": [_row("Fight won", 6, "encounter_gathered")], "ase_awarded": 0 })]:
		screen.set_snapshot(card)
		shown.append_array(_visible_texts(screen))
		if str(card["data"].get("run_type", "")) == "standoff":
			for t in _visible_texts(screen):
				if "leave" in str(t).to_lower():
					return _fail(m, "the standoff card shows \"%s\"" % str(t))
	StopMarkMotion.reduced = reduced_before
	bad = _first_banned(shown)
	m[0].free()
	if not bad.is_empty():
		return { "ok": false, "error": "cards: " + bad }
	var m2 := _mount_scene(ReturnHomeScene)
	var modal: ReturnHomeModal = m2[1]
	shown = []
	for c in [[12, 3], [0, 0]]:
		modal.present({ "confirm": true, "action": RETURN_ACTION.duplicate(), "carry": _gathered_preview(c[0], c[1]) })
		shown.append_array(_visible_texts(modal))
	bad = _first_banned(shown)
	m2[0].free()
	if not bad.is_empty():
		return { "ok": false, "error": "confirmation: " + bad }
	return { "ok": true }
