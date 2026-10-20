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
	runner.register_test("payout_ui/replay_absent_and_bonus_missed_zero_row", Callable(ResolvePayoutUITests, "_t_replay_and_bonus"))
	runner.register_test("payout_ui/zero_rows_show_muted_with_button", Callable(ResolvePayoutUITests, "_t_zero_rows"))
	runner.register_test("payout_ui/cause_rows_have_48_button_others_none", Callable(ResolvePayoutUITests, "_t_buttons"))
	runner.register_test("payout_ui/tooltip_text_matches_approved_wording", Callable(ResolvePayoutUITests, "_t_wording"))
	runner.register_test("payout_ui/tooltip_opens_pins_and_closes", Callable(ResolvePayoutUITests, "_t_tooltip_rules"))
	runner.register_test("payout_ui/ledger_opens_once_when_unseen", Callable(ResolvePayoutUITests, "_t_first_time_open"))
	runner.register_test("payout_ui/ledger_closed_when_seen_or_key_absent", Callable(ResolvePayoutUITests, "_t_seen_or_absent"))
	runner.register_test("payout_ui/any_subset_of_rows_renders", Callable(ResolvePayoutUITests, "_t_any_subset"))
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
		_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 }),
		_row("3 echoes survived", 11, "echoes_alive", { "count": 3 }),
		_row("Pace bonus", 0, "bonus_missed"),
		_row("Redo penalty", -3, "replay", { "factor": 0.9 }),
	]
	screen.set_snapshot(_snap(rows, { "ledger_seen": true }))
	var shown := _rows_in(screen, "%BreakdownSection")
	if shown.size() != 4:
		return _fail(m, "expected 4 fight rows, got %d" % shown.size())
	if _names(shown) != ["2 enemies defeated", "3 echoes survived", "Bonus", "Replay"]:
		return _fail(m, "row names %s" % str(_names(shown)))
	if _label(screen, "%AseTotalLabel").text != "+15 Ase" or _label(screen, "%TotalValue").text != "= 15 Ase":
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
		_row("Realm virtue", 9, "realm_virtue"),
	]
	var fight := [_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 })]
	screen.set_snapshot(_snap(fight, {
		"ledger_seen": true, "stage_payout_rows": stage, "stage_payout_ase": 45, "stage_payout_ekwan": 6 }))
	if _rows_in(screen, "%StageSection").size() != 3 or not screen.get_node("%StageGroup").visible:
		return _fail(m, "stage group does not show the 3 stage rows")
	if _label(screen, "%TotalValue").text != "= 52 Ase" or _label(screen, "%AseTotalLabel").text != "+52 Ase":
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
	screen.set_snapshot(_snap([_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 })],
		{ "ledger_seen": true }))
	if screen.get_node("%StageGroup").visible or screen.get_node("%EkwanLine").visible \
			or screen.get_node("%EkwanTotalLabel").visible or screen.get_node("%FightGroupHeader").visible:
		return _fail(m, "stage group, Ekwan or group header visible on a mid-stage card")
	# A stage card whose Ekwan is 0 shows no Ekwan either.
	screen.set_snapshot(_snap([_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 })], {
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
	screen.set_snapshot(_snap([
		_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 }),
		_row("Pace bonus", 0, "bonus_missed"),
	], { "ledger_seen": true }))
	var shown := _rows_in(screen, "%BreakdownSection")
	if "Replay" in _names(shown):
		return _fail(m, "Replay row present without a replay cause")
	var bonus: RewardEntryItem = shown[1]
	if bonus.entry_label.text != "Bonus" or bonus.delta_label.text != "+0 Ase" or not bonus.cause_button.visible:
		return _fail(m, "bonus row %s %s" % [bonus.entry_label.text, bonus.delta_label.text])
	if not bonus.delta_label.get_theme_color("font_color").is_equal_approx(bonus.color_zero) \
			or not bonus.entry_label.get_theme_color("font_color").is_equal_approx(bonus.color_zero):
		return _fail(m, "zero bonus row is not muted")
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
		_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 }),
		_row("Realm virtue", 3, "realm_virtue"),
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
		"enemies_defeated": "Each enemy the party defeats earns Ase.",
		"echoes_alive": "Each Echo still standing when the fight ends earns Ase.",
		"bonus_missed": "The party was not quick enough to earn a bonus.",
		"bonus_earned": "The party was quick enough to earn a bonus.",
		"realm_virtue": "The realm rewards the virtue the party showed here.",
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
	var names := { "bonus_earned": "Bonus", "bonus_missed": "Bonus", "replay": "Replay",
		"defeat_consolation": "Consolation", "partial_retreat": "Carried home",
		"partial_return_home": "Carried home", "objectives_overcome": "Objectives overcome",
		"realm_virtue": "Realm virtue" }
	for cause in names:
		if PayoutCausePresentation.row_name(cause, "x") != names[cause]:
			return { "ok": false, "error": "row name of %s" % cause }
	if PayoutCausePresentation.row_name("enemies_defeated", "9 enemies defeated") != "9 enemies defeated":
		return { "ok": false, "error": "fight rows must keep their backend label" }
	return { "ok": true }


static func _t_tooltip_rules() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_snap([
		_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 }),
		_row("Realm virtue", 3, "realm_virtue"),
	], { "ledger_seen": true }))
	var tip := screen.get_node("%CauseTooltip") as CauseTooltip
	var first: RewardEntryItem = _rows_in(screen, "%BreakdownSection")[0]
	var button := first.cause_button
	button.mouse_entered.emit()
	if not tip.is_open() or tip.is_pinned() or (tip.get_node("%TitleLabel") as Label).text != "2 enemies defeated":
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


static func _t_first_time_open() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	var sent: Array = []
	screen.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	var rows := [_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 })]
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
	var rows := [_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 })]
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
	if not summary.visible or not summary.disabled or screen.get_node("%Ledger").visible:
		return _fail(m, "an empty card must show a disabled summary and no ledger")
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
	if (screen.get_node("%FightStrip") as Control).visible:
		return _fail(m, "scout return shows the fight strip")
	screen.set_snapshot({ "type": "flow.resolve", "meta": { "t": 4 }, "actions": {}, "data": {
		"run_type": "contact_result", "outcome": "good", "role_label": "Elder", "outcome_text": "Done." } })
	if (screen.get_node("%EarningsSummary") as Button).visible or (screen.get_node("%Ledger") as Control).visible \
			or (screen.get_node("%FightStrip") as Control).visible:
		return _fail(m, "contact card shows payout parts")
	screen.set_snapshot({ "type": "flow.resolve", "meta": { "t": 5 }, "actions": {}, "data": {
		"run_type": "situation_result", "surface": "shrine", "verdict": "passed", "emotion_summary": [] } })
	if (screen.get_node("%EarningsSummary") as Button).visible or not (screen.get_node("%RankChip") as Control).visible \
			or (screen.get_node("%EnemiesChip") as Control).visible:
		return _fail(m, "situation card shows wrong chips")
	screen.set_snapshot(_snap([_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 })], { "ledger_seen": true }))
	if not (screen.get_node("%EnemiesChip") as Control).visible or _label(screen, "%EnemiesDefeatedValue").text != "2" \
			or _label(screen, "%EchoesAliveValue").text != "3" or _label(screen, "%RoundsValue").text != "5" \
			or _label(screen, "%RankBadge").text != "B":
		return _fail(m, "fight strip values wrong after other cards")
	return _pass(m)


static func _t_rail_chips() -> Dictionary:
	var m := _mount()
	var screen: ResolveScreen = m[1]
	screen.set_snapshot(_snap([_row("2 enemies defeated", 7, "enemies_defeated", { "count": 2 })], {
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
