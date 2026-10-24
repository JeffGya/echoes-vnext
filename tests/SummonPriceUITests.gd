extends RefCounted
class_name SummonPriceUITests

## V2-ECONOMY-004 Summon price card. Each test mounts the real SummonScreen.tscn and feeds it a
## hand-built snapshot with the field names of FlowSummonState. The screen must show the snapshot
## values as given and compute no price.

const SummonScreenScene := preload("res://ui/screens/sanctum/SummonScreen.tscn")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("summon_price_ui/card_shows_count_two_prices_and_one_reason", Callable(SummonPriceUITests, "_t_card"))
	runner.register_test("summon_price_ui/flat_price_uses_the_flat_reason", Callable(SummonPriceUITests, "_t_flat"))
	runner.register_test("summon_price_ui/total_is_the_snapshot_value_never_a_product", Callable(SummonPriceUITests, "_t_total_verbatim"))
	runner.register_test("summon_price_ui/stepper_and_max_clamp_to_affordable_max", Callable(SummonPriceUITests, "_t_stepper"))
	runner.register_test("summon_price_ui/short_line_and_disabled_button_when_nothing_affordable", Callable(SummonPriceUITests, "_t_short"))
	runner.register_test("summon_price_ui/summon_sends_the_chosen_count", Callable(SummonPriceUITests, "_t_action"))
	runner.register_test("summon_price_ui/called_and_chosen_shown_but_locked", Callable(SummonPriceUITests, "_t_grades_locked"))
	runner.register_test("summon_price_ui/enabled_flag_unlocks_a_grade_card", Callable(SummonPriceUITests, "_t_grade_unlocks"))
	runner.register_test("summon_price_ui/no_discount_wording_and_no_id_in_copy_or_screen", Callable(SummonPriceUITests, "_t_no_discount_no_id"))
	runner.register_test("summon_price_ui/copy_table_has_every_key_the_screen_reads", Callable(SummonPriceUITests, "_t_copy_keys"))


static func _snapshot(over: Dictionary = {}) -> Dictionary:
	var data := {
		"title": "Summon Echo",
		"ase_balance": 700,
		"ase_rate_per_hour_hint": 4.0,
		"living_count": 7,
		"village_ceiling": 14,
		"price_flat": false,
		"selected_grade": "uncalled",
		"summon_disabled": false,
		"batch_prices": [145, 175, 210, 250, 300, 360, 430, 430, 430, 430],
		"batch_totals": [145, 320, 530, 780, 1080, 1440, 1870, 2300, 2730, 3160],
		"batch_affordable_max": 3,
		"ase_short_by": 0,
		"summon_grade_options": [
			{ "key": "uncalled", "label": "Uncalled", "enabled": true, "ase_cost": 145, "ase_cost_after": 175 },
			{ "key": "called", "label": "Called", "enabled": false, "ase_cost": 235, "ase_cost_after": 265 },
			{ "key": "chosen", "label": "Chosen", "enabled": false, "ase_cost": 485, "ase_cost_after": 515 },
		],
		"pending_summon_reveals": [],
	}
	for k: String in over.keys():
		data[k] = over[k]
	return {
		"type": "flow.summon",
		"data": data,
		"actions": { "cta.summon": { "type": "sanctum.summon", "slot": "cta.summon", "disabled": false } },
	}


static func _mount() -> Control:
	var host := (Engine.get_main_loop() as SceneTree).current_scene.get_node("UISnapshotRenderer")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var screen := SummonScreenScene.instantiate() as Control
	viewport.add_child(screen)
	return screen


static func _unmount(screen: Control) -> void:
	screen.get_parent().free()


static func _label(screen: Control, node_name: String) -> String:
	return (screen.find_child(node_name, true, false) as Label).text


static func _button(screen: Control, node_name: String) -> Button:
	return screen.find_child(node_name, true, false) as Button


static func _fail(screen: Control, msg: String) -> Dictionary:
	_unmount(screen)
	return { "ok": false, "error": msg }


static func _t_card() -> Dictionary:
	var s := _mount()
	s.call("set_snapshot", _snapshot())
	if _label(s, "LivingLabel") != "7 living in the village":
		return _fail(s, "living line: " + _label(s, "LivingLabel"))
	if _label(s, "NextPriceLabel") != "145 Ase" or _label(s, "AfterPriceLabel") != "175 Ase":
		return _fail(s, "prices: %s / %s" % [_label(s, "NextPriceLabel"), _label(s, "AfterPriceLabel")])
	if _label(s, "ReasonLabel") != SummonPriceText.text("price_card", "reason_rising"):
		return _fail(s, "reason line")
	var reason := s.find_child("ReasonLabel", true, false) as Label
	if reason.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return _fail(s, "the reason line must stay on one line")
	_unmount(s)
	return { "ok": true }


static func _t_flat() -> Dictionary:
	var s := _mount()
	s.call("set_snapshot", _snapshot({ "price_flat": true, "living_count": 14 }))
	var ok := _label(s, "ReasonLabel") == SummonPriceText.text("price_card", "reason_flat")
	_unmount(s)
	return { "ok": ok, "error": "flat reason not shown" }


static func _t_total_verbatim() -> Dictionary:
	# Totals that are not count x price: a screen that multiplies would show a different number.
	var s := _mount()
	s.call("set_snapshot", _snapshot({ "batch_totals": [145, 321, 533, 780, 1080, 1440, 1870, 2300, 2730, 3160] }))
	_button(s, "PlusButton").pressed.emit()
	_button(s, "PlusButton").pressed.emit()
	var got := _label(s, "TotalLabel")
	_unmount(s)
	return { "ok": got == "533 Ase", "error": "total was " + got }


static func _t_stepper() -> Dictionary:
	var s := _mount()
	s.call("set_snapshot", _snapshot())
	for i in range(8):
		_button(s, "PlusButton").pressed.emit()
	if _label(s, "CountValueLabel") != "3":
		return _fail(s, "plus must stop at the affordable max (3), got " + _label(s, "CountValueLabel"))
	if not _button(s, "PlusButton").disabled or not _button(s, "MaxButton").disabled:
		return _fail(s, "plus and Max must be disabled at the max")
	for i in range(8):
		_button(s, "MinusButton").pressed.emit()
	if _label(s, "CountValueLabel") != "1" or not _button(s, "MinusButton").disabled:
		return _fail(s, "minus must stop at 1")
	_button(s, "MaxButton").pressed.emit()
	if _label(s, "CountValueLabel") != "3" or _label(s, "TotalLabel") != "530 Ase":
		return _fail(s, "Max must set 3 and show 530 Ase")
	# A summon spent Ase: the new snapshot allows 1 only, the count follows it.
	s.call("set_snapshot", _snapshot({ "batch_affordable_max": 1 }))
	var ok := _label(s, "CountValueLabel") == "1"
	_unmount(s)
	return { "ok": ok, "error": "count did not follow a lower affordable max" }


static func _t_short() -> Dictionary:
	var s := _mount()
	s.call("set_snapshot", _snapshot({ "ase_balance": 100, "batch_affordable_max": 0, "summon_disabled": true, "ase_short_by": 45 }))
	if _label(s, "ShortLabel") != "Need 45 more Ase":
		return _fail(s, "short line: " + _label(s, "ShortLabel"))
	if not _button(s, "SummonButton").disabled:
		return _fail(s, "the Summon button must be disabled")
	if _label(s, "CountValueLabel") != "1":
		return _fail(s, "the count stays at 1")
	s.call("set_snapshot", _snapshot())
	var ok := _label(s, "ShortLabel") == "" and not _button(s, "SummonButton").disabled
	_unmount(s)
	return { "ok": ok, "error": "short line must clear when the player can pay" }


static func _t_action() -> Dictionary:
	var s := _mount()
	var seen: Array = []
	s.connect("action_requested", func(a: Dictionary) -> void: seen.append(a))
	s.call("set_snapshot", _snapshot())
	_button(s, "PlusButton").pressed.emit()
	_button(s, "SummonButton").pressed.emit()
	_unmount(s)
	if seen.size() != 1:
		return { "ok": false, "error": "expected one action, got %d" % seen.size() }
	var a: Dictionary = seen[0]
	return { "ok": str(a.get("type", "")) == "sanctum.summon" and int(a.get("count", 0)) == 2 and str(a.get("grade", "")) == "uncalled", "error": "action: " + str(a) }


static func _t_grades_locked() -> Dictionary:
	var s := _mount()
	s.call("set_snapshot", _snapshot())
	# A grade option without the key stays locked (Called and Chosen).
	var bare := _snapshot()
	for o: Dictionary in (bare["data"] as Dictionary)["summon_grade_options"]:
		o.erase("enabled")
	s.call("set_snapshot", bare)
	if not (_button(s, "GradeCalledButton").disabled and _button(s, "GradeChosenButton").disabled):
		return _fail(s, "a missing enabled key must keep Called and Chosen locked")
	s.call("set_snapshot", _snapshot())
	var ok := not _button(s, "GradeUncalledButton").disabled \
		and _button(s, "GradeCalledButton").disabled and _button(s, "GradeChosenButton").disabled \
		and _button(s, "GradeUncalledButton").button_pressed and not _button(s, "GradeCalledButton").button_pressed
	# Locked grades show no price anywhere.
	var texts := _label(s, "NextPriceLabel") + _label(s, "AfterPriceLabel") + _label(s, "TotalLabel")
	var leak := texts.contains("235") or texts.contains("485")
	_unmount(s)
	return { "ok": ok and not leak, "error": "Called and Chosen must be visible, locked, and show no price" }


static func _t_grade_unlocks() -> Dictionary:
	var s := _mount()
	var snap := _snapshot()
	for o: Dictionary in (snap["data"] as Dictionary)["summon_grade_options"]:
		if str(o["key"]) == "called":
			o["enabled"] = true
	s.call("set_snapshot", snap)
	var ok := not _button(s, "GradeCalledButton").disabled and _button(s, "GradeChosenButton").disabled
	_unmount(s)
	return { "ok": ok, "error": "flipping enabled must unlock the Called card and leave Chosen locked" }


static func _t_no_discount_no_id() -> Dictionary:
	var banned := ["cheaper", "discount", "sale", "house", "echo_"]
	var copy := FileAccess.get_file_as_string("res://data/ui/summon_price_text.json")
	var body := (JSON.parse_string(copy) as Dictionary)
	var lines: Array[String] = []
	for g: String in ["price_card", "summon", "grade"]:
		for k: String in (body[g] as Dictionary).keys():
			lines.append(str((body[g] as Dictionary)[k]).to_lower())
	var s := _mount()
	s.call("set_snapshot", _snapshot({ "living_count": 6 }))
	for n: String in ["LivingLabel", "NextLabel", "NextPriceLabel", "AfterLabel", "AfterPriceLabel", "ReasonLabel", "ShortLabel", "TotalLabel"]:
		lines.append(_label(s, n).to_lower())
	_unmount(s)
	for line in lines:
		for w in banned:
			if line.contains(w):
				return { "ok": false, "error": "'%s' in '%s'" % [w, line] }
	return { "ok": true }


static func _t_copy_keys() -> Dictionary:
	var keys := [
		["price_card", "living_line"], ["price_card", "next_label"], ["price_card", "after_label"], ["price_card", "price"],
		["price_card", "reason_rising"], ["price_card", "reason_flat"], ["summon", "count_label"], ["summon", "max_button"],
		["summon", "short_line"], ["grade", "label"], ["grade", "locked_hint"],
	]
	for pair: Array in keys:
		if SummonPriceText.text(pair[0], pair[1]).is_empty():
			return { "ok": false, "error": "missing copy key %s.%s" % [pair[0], pair[1]] }
	return { "ok": true }
