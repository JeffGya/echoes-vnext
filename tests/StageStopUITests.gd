extends RefCounted
class_name StageStopUITests

## V2-DIRECTIVE-002 B+C frontend, structure and data only: the stop glyph, the party card, the why card,
## the step row, the Directive badge and the presentation reads. Each test mounts the real .tscn.

const RealmShellScene := preload("res://ui/shells/RealmShell.tscn")
const StageScene := preload("res://ui/screens/venture/StageExploreScreen.tscn")
const WhyCardScene := preload("res://ui/components/StageWhyCard.tscn")
const CardScene := preload("res://ui/components/EchoCardItem.tscn")
const PARTY: Array[String] = ["Ama", "Kofi", "Yaa"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("stage_stop_ui/scenes_load", Callable(StageStopUITests, "_t_scenes_load"))
	runner.register_test("stage_stop_ui/glyph_on_named_card_for_all_six_kinds", Callable(StageStopUITests, "_t_glyph_per_kind"))
	runner.register_test("stage_stop_ui/glyph_matches_by_id_when_names_repeat", Callable(StageStopUITests, "_t_glyph_by_id"))
	runner.register_test("stage_stop_ui/glyph_on_party_card_when_no_echo_named", Callable(StageStopUITests, "_t_party_glyph_alone"))
	runner.register_test("stage_stop_ui/no_mark_without_a_stop_kind", Callable(StageStopUITests, "_t_no_mark_without_kind"))
	runner.register_test("stage_stop_ui/why_card_has_no_digit_and_no_id", Callable(StageStopUITests, "_t_why_card_clean"))
	runner.register_test("stage_stop_ui/why_card_unknown_token_shows_nothing", Callable(StageStopUITests, "_t_why_unknown_token"))
	runner.register_test("stage_stop_ui/step_row_crosses_budget_minus_effective", Callable(StageStopUITests, "_t_step_row_lost"))
	runner.register_test("stage_stop_ui/step_fraction_label_is_gone", Callable(StageStopUITests, "_t_fraction_label_gone"))
	runner.register_test("stage_stop_ui/presentation_read_with_literal_fallback", Callable(StageStopUITests, "_t_presentation_read"))
	runner.register_test("stage_stop_ui/motion_calm_timeline_from_snapshot", Callable(StageStopUITests, "_t_motion_calm"))
	runner.register_test("stage_stop_ui/motion_shaken_shake_and_crosses", Callable(StageStopUITests, "_t_motion_shaken"))
	runner.register_test("stage_stop_ui/motion_snippet_waits_on_travel_only", Callable(StageStopUITests, "_t_motion_snippet"))
	runner.register_test("stage_stop_ui/motion_advance_ready_then_second_advance_cuts", Callable(StageStopUITests, "_t_motion_cut"))
	runner.register_test("stage_stop_ui/motion_reduced_has_no_shake_no_scale_no_pulse", Callable(StageStopUITests, "_t_motion_reduced"))
	runner.register_test("stage_stop_ui/motion_mark_hidden_until_beat_then_tappable", Callable(StageStopUITests, "_t_motion_shell_mark"))
	runner.register_test("stage_stop_ui/motion_press_and_pulse_values", Callable(StageStopUITests, "_t_motion_press_pulse"))
	runner.register_test("stage_stop_ui/motion_leaves_snapshot_untouched_and_frees_tweens", Callable(StageStopUITests, "_t_motion_no_leak"))
	runner.register_test("stage_stop_ui/party_card_first_pinned_gap_32_echo_cards_scroll", Callable(StageStopUITests, "_t_party_pinned"))
	runner.register_test("stage_stop_ui/glyph_on_exactly_one_card_six_kinds_both_cases", Callable(StageStopUITests, "_t_glyph_one_card"))
	runner.register_test("stage_stop_ui/party_card_tap_rules", Callable(StageStopUITests, "_t_party_tap"))
	runner.register_test("stage_stop_ui/cards_never_shift_when_glyph_shows_or_hides", Callable(StageStopUITests, "_t_no_shift"))
	runner.register_test("stage_stop_ui/combat_echo_bar_has_no_party_card", Callable(StageStopUITests, "_t_combat_bar"))
	runner.register_test("stage_stop_ui/advance_ready_when_walk_ends_beats_never_block", Callable(StageStopUITests, "_t_lock_walk_end"))
	runner.register_test("stage_stop_ui/press_in_stop_beats_cuts_them_one_advance", Callable(StageStopUITests, "_t_press_in_beats"))
	runner.register_test("stage_stop_ui/step_row_crossed_is_budget_minus_commitment_depth", Callable(StageStopUITests, "_t_step_row_depth"))
	runner.register_test("stage_stop_ui/glyph_sits_on_portrait_top_left_corner", Callable(StageStopUITests, "_t_glyph_corner"))
	runner.register_test("stage_stop_ui/why_card_above_icon_inside_safe_area_above_advance_bar", Callable(StageStopUITests, "_t_why_place"))
	runner.register_test("stage_stop_ui/overlay_opens_after_the_mark_lands", Callable(StageStopUITests, "_t_overlay_after_mark"))
	runner.register_test("stage_stop_ui/token_tap_closes_open_why_card", Callable(StageStopUITests, "_t_token_tap_closes"))
	runner.register_test("stage_stop_ui/hidden_shell_closes_why_card_and_leaves_cancel", Callable(StageStopUITests, "_t_hidden_shell"))
	runner.register_test("stage_stop_ui/token_tap_rules", Callable(StageStopUITests, "_t_token_tap_rules"))
	runner.register_test("stage_stop_ui/same_holder_old_glyph_fades_then_new_settles", Callable(StageStopUITests, "_t_same_holder_fade"))
	runner.register_test("stage_stop_ui/no_directive_id_literal_in_ui", Callable(StageStopUITests, "_t_no_directive_literal"))
	runner.register_test("stage_stop_ui/glyph_textures_are_256_rgba", Callable(StageStopUITests, "_t_glyph_textures"))
	runner.register_test("stage_stop_ui/no_svg_glyph_left", Callable(StageStopUITests, "_t_no_svg_glyph"))
	runner.register_test("stage_stop_ui/glyph_rects_use_mipmap_filter", Callable(StageStopUITests, "_t_glyph_filter"))
	runner.register_test("stage_stop_ui/six_glyphs_differ", Callable(StageStopUITests, "_t_glyphs_differ"))


static func _mount(scene: PackedScene, view_size := Vector2i(1280, 720)) -> Array:
	var host := (Engine.get_main_loop() as SceneTree).current_scene.get_node("UISnapshotRenderer")
	var viewport := SubViewport.new()
	viewport.size = view_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var node := scene.instantiate() as Control
	viewport.add_child(node)
	return [viewport, node]


static func _fail(m: Array, error: String) -> Dictionary:
	m[0].free()
	return { "ok": false, "error": error }


static func _snap(kind: String, named: String, echo_id: String = "internal_echo_id") -> Dictionary:
	var preview: Array = []
	for n in PARTY:
		preview.append({ "name": n, "rank": 1, "calling_origin": "x", "emotional_status": "grounded" })
	return {
		"type": "flow.stage_explore",
		"data": {
			"party_preview": preview,
			"stop": { "kind": kind, "col": 1, "row": 2, "echo_id": echo_id if named != "" else "" },
			"travel_why": { "cause": "terrain", "purpose_family": "advance", "route_character": "direct",
				"stop_kind": kind, "named_echo_name": named, "echo_reason_class": "fear" if named != "" else "" },
		},
	}


## Runs the shell's bar and mark update on a fake snapshot, without mounting a stage screen.
static func _feed(shell: Control, snap: Dictionary) -> void:
	shell.call("_update_echo_bar", snap)
	shell.call("_update_stop_mark", snap)


static func _cards(shell: Control) -> Array:
	return shell.get_node("%EchoBar").get_children().filter(func(c: Node) -> bool: return c is EchoCardItem)


static func _t_scenes_load() -> Dictionary:
	for scene in [RealmShellScene, StageScene, WhyCardScene, CardScene]:
		var m := _mount(scene)
		var ok: bool = m[1] != null
		m[0].free()
		if not ok:
			return { "ok": false, "error": "scene did not load" }
	return { "ok": true }


static func _t_glyph_per_kind() -> Dictionary:
	var m := _mount(RealmShellScene)
	for kind in StopGlyphs.KINDS:
		_feed(m[1], _snap(kind, "Kofi"))
		var holders := 0
		for card in _cards(m[1]):
			var c := card as EchoCardItem
			if c.has_stop_glyph():
				holders += 1
				if c.display_name() != "Kofi" or c.get_node("%StopGlyph").texture != StopGlyphs.texture(kind):
					return _fail(m, "%s: wrong card or texture" % kind)
		if holders != 1:
			return _fail(m, "%s: %d cards hold a glyph" % [kind, holders])
		if (m[1].get_node("%PartyCard") as EchoCardItem).has_stop_glyph():
			return _fail(m, "%s: party card holds a glyph next to a named card" % kind)
	m[0].free()
	return { "ok": true }


static func _t_glyph_by_id() -> Dictionary:
	var m := _mount(RealmShellScene)
	var snap := _snap("capacity_spent", "Kofi", "echo_b")
	var rows: Array = []
	for id in ["echo_a", "echo_b"]:
		rows.append({ "id": id, "name": "Kofi", "rank": 1, "calling_origin": "x", "emotional_status": "grounded" })
	snap["data"]["party_preview"] = rows
	_feed(m[1], snap)
	var holders: Array[String] = []
	for card in _cards(m[1]):
		if (card as EchoCardItem).has_stop_glyph():
			holders.append((card as EchoCardItem).actor_id())
	if holders != ["echo_b"]:
		return _fail(m, "glyph must sit on echo_b only, got %s" % str(holders))
	m[0].free()
	return { "ok": true }


static func _t_party_glyph_alone() -> Dictionary:
	var m := _mount(RealmShellScene)
	_feed(m[1], _snap("capacity_spent", ""))
	var card := m[1].get_node("%PartyCard") as EchoCardItem
	var cards_with_glyph := _cards(m[1]).filter(func(c: Node) -> bool: return (c as EchoCardItem).has_stop_glyph())
	var ok: bool = card.visible and card.has_stop_glyph() and cards_with_glyph.is_empty() \
		and card.custom_minimum_size.x >= 48.0 and card.custom_minimum_size.y >= 48.0
	m[0].free()
	return { "ok": ok, "error": "the party card must hold the glyph alone, at least 48 x 48" }


static func _settle_layout(shell: Control) -> void:
	for pass_index in range(4):
		shell.propagate_notification(Control.NOTIFICATION_RESIZED)
		shell.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)


static func _party_snap(kind: String, named: String, count: int) -> Dictionary:
	var snap := _snap(kind, named, "e1")
	var rows: Array = []
	for i in range(count):
		rows.append({ "id": "e%d" % i, "name": "Echo %d" % i, "rank": 1, "calling_origin": "x", "emotional_status": "grounded" })
	snap["data"]["party_preview"] = rows
	return snap


static func _t_party_pinned() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	var frame := shell.get_node("%EchoBarFrame") as Control
	var scroll := shell.get_node("%EchoBarScroll") as ScrollContainer
	var card := shell.get_node("%PartyCard") as Control
	for count in [1, 3, 5]:
		for inset in [0.0, 48.0]:
			shell.set_layout({ "profile": &"standard", "logical_size": Vector2(1280, 720), "safe_insets": Vector4(inset, inset, inset, inset) })
			for kind in ["capacity_spent", ""]:
				_feed(shell, _party_snap(kind, "", count))
				_settle_layout(shell)
				var edge := maxf(16.0, inset)
				var view := Rect2(Vector2(edge, edge), Vector2(1280.0 - 2.0 * edge, 720.0 - 2.0 * edge))
				var where := "party %d inset %d kind '%s'" % [count, int(inset), kind]
				var first := (_cards(shell)[0] as Control).get_global_rect()
				var rect := card.get_global_rect()
				if card.get_parent() != frame or card.get_index() != 0:
					return _fail(m, "%s: the party card must be the first child of the bar frame" % where)
				if not card.visible or not view.encloses(rect):
					return _fail(m, "%s: party card %s outside view %s" % [where, str(rect), str(view)])
				if rect.size.x < 160.0 or rect.size.x > 176.0 or absf(rect.size.y - 58.0) > 1.0:
					return _fail(m, "%s: party card must be about 168 x 58, got %s" % [where, str(rect.size)])
				if absf((first.position.x - rect.end.x) - 32.0) > 1.0:
					return _fail(m, "%s: gap to the first Echo card must be 32, got %f" % [where, first.position.x - rect.end.x])
				if not is_equal_approx(rect.position.y, first.position.y):
					return _fail(m, "%s: party card must sit on the card row" % where)
				var scrolls := scroll.get_h_scroll_bar().max_value > scroll.get_h_scroll_bar().page + 0.5
				if (count == 5) != scrolls:
					return _fail(m, "%s: the Echo cards must scroll only with 5 Echoes" % where)
				if scrolls:
					scroll.scroll_horizontal = 400
					_settle_layout(shell)
					if card.get_global_rect() != rect:
						return _fail(m, "%s: the party card moved when the Echo cards scrolled" % where)
					if absf(rect.position.x - frame.get_global_rect().position.x) > 0.5:
						return _fail(m, "%s: a scrolling party must pin the party card at the frame left edge" % where)
					scroll.scroll_horizontal = 0
				for c in _cards(shell):
					if (c as Control).size.x < 280.0 - 0.1:
						return _fail(m, "%s: card under 280 wide" % where)
				if (_bar_gap(shell) != 16.0):
					return _fail(m, "%s: Echo cards must sit 16 apart" % where)
	m[0].free()
	return { "ok": true }


static func _bar_gap(shell: Control) -> float:
	return float((shell.get_node("%EchoBar") as HBoxContainer).get_theme_constant("separation"))


static func _t_glyph_one_card() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	var party := shell.get_node("%PartyCard") as EchoCardItem
	for kind in StopGlyphs.KINDS:
		for named in ["", "Echo 1"]:
			_feed(shell, _party_snap(kind, named, 3))
			var holders: Array[String] = []
			for c in _cards(shell):
				if (c as EchoCardItem).has_stop_glyph():
					holders.append((c as EchoCardItem).display_name())
			var where := "%s named '%s'" % [kind, named]
			if party.has_stop_glyph() == (named != ""):
				return _fail(m, "%s: the party card holds the glyph if and only if no Echo is named" % where)
			if holders.size() + int(party.has_stop_glyph()) != 1:
				return _fail(m, "%s: exactly one card must hold the glyph, got %s and party %s" % [where, str(holders), str(party.has_stop_glyph())])
			if named != "" and holders != [named]:
				return _fail(m, "%s: wrong holder %s" % [where, str(holders)])
	m[0].free()
	return { "ok": true }


static func _t_party_tap() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	var why := shell.get_node("%StageWhyCard") as StageWhyCard
	var party := shell.get_node("%PartyCard") as EchoCardItem
	var cases := {
		"glyph on the party card": [_party_snap("capacity_spent", "", 3), true],
		"no mark, entry exists": [_party_snap("", "", 3), true],
	}
	var empty := _party_snap("", "", 3)
	empty["data"]["travel_why"] = {}
	cases["no mark, no entry"] = [empty, false]
	var blank := _party_snap("", "", 3)
	blank["data"]["travel_why"] = { "cause": "", "purpose_family": "" }
	cases["no mark, only empty slots"] = [blank, false]
	for name in cases:
		_feed(shell, cases[name][0])
		_settle_layout(shell)
		party.card_pressed.emit("")
		if why.is_open() != cases[name][1]:
			return _fail(m, "%s: the why card open state must be %s" % [name, str(cases[name][1])])
		if why.is_open():
			var rect := why.get_global_rect()
			if absf(rect.get_center().x - party.get_global_rect().get_center().x) > 1.0 and rect.position.x > 17.0:
				return _fail(m, "%s: the why card must sit above the party card" % name)
			party.card_pressed.emit("")
			if why.is_open():
				return _fail(m, "%s: a second tap must close the card" % name)
	_feed(shell, _party_snap("capacity_spent", "Echo 1", 3))
	_settle_layout(shell)
	var named: EchoCardItem
	for c in _cards(shell):
		if (c as EchoCardItem).has_stop_glyph():
			named = c
	shell.call("_on_echo_card_pressed", "e1", named)
	var rect := why.get_global_rect()
	if not why.is_open() or absf(rect.get_center().x - named.get_global_rect().get_center().x) > 1.0:
		return _fail(m, "a tap on the named card must open the why card above that card")
	shell.call("_on_echo_card_pressed", "e1", named)
	if why.is_open():
		return _fail(m, "a second tap on the named card must close the card")
	var other: EchoCardItem = _cards(shell)[0] if _cards(shell)[0] != named else _cards(shell)[2]
	shell.call("_on_echo_card_pressed", other.actor_id(), other)
	if why.is_open():
		return _fail(m, "a card without a glyph must not open the why card")
	party.card_pressed.emit("")
	if not why.is_open():
		return _fail(m, "named stop: the party card has no mark but the last entry exists, so it opens")
	m[0].free()
	return { "ok": true }


static func _t_no_shift() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	for count in [1, 3, 5]:
		var seen: Array = []
		for kind in ["capacity_spent", "", "interrupted"]:
			for named in ["", "Echo 1"]:
				_feed(shell, _party_snap(kind, named, count))
				_settle_layout(shell)
				var rects: Array = [(shell.get_node("%PartyCard") as Control).get_global_rect()]
				for c in _cards(shell):
					rects.append((c as Control).get_global_rect())
				seen.append(rects)
		for rects in seen:
			if rects != seen[0]:
				return _fail(m, "party %d: cards moved between glyph states: %s vs %s" % [count, str(rects), str(seen[0])])
	m[0].free()
	return { "ok": true }


static func _t_combat_bar() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	var actors: Array = []
	for i in range(3):
		actors.append({ "id": "a%d" % i, "name": "Ally %d" % i, "faction": "echo", "hp": 10, "max_hp": 10, "emotional_status": "grounded" })
	actors.append({ "id": "foe", "name": "Foe", "faction": "enemy", "hp": 5, "max_hp": 5 })
	shell.call("_update_echo_bar", { "type": "flow.encounter", "data": { "actors": actors } })
	_settle_layout(shell)
	var bar := shell.get_node("%EchoBar")
	var party := shell.get_node("%PartyCard") as Control
	var frame := shell.get_node("%EchoBarFrame")
	var visible_children := frame.get_children().filter(func(c: Node) -> bool: return (c as Control).visible)
	var ok: bool = bar.get_child_count() == 3 and not party.visible and visible_children.size() == 1
	m[0].free()
	return { "ok": ok, "error": "combat bar must hold 3 Echo cards and no party card" }


static func _t_glyph_corner() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	var error := ""
	for named in ["Echo 1", ""]:
		_feed(shell, _party_snap("capacity_spent", named, 3))
		_settle_layout(shell)
		var holder: EchoCardItem = shell.get_node("%PartyCard")
		for c in _cards(shell):
			if (c as EchoCardItem).has_stop_glyph():
				holder = c
		if not holder.has_stop_glyph():
			return _fail(m, "no card holds the glyph")
		var glyph := holder.stop_glyph_rect()
		var portrait := (holder.get_node("%PortraitPanel") as Control).get_global_rect()
		var name_left := portrait.end.x
		if glyph.size.x != 24.0 or glyph.size.y != 24.0:
			error = "glyph must be 24 px, got %s" % str(glyph.size)
		elif glyph.get_center().distance_to(portrait.position) > 14.0 or glyph.get_center().x > portrait.get_center().x:
			error = "glyph centre %s must sit near the top-left portrait corner %s" % [str(glyph.get_center()), str(portrait.position)]
		elif not holder.get_global_rect().encloses(glyph):
			error = "glyph must stay inside the card"
		if error != "":
			break
	m[0].free()
	return { "ok": error == "", "error": error }


static func _t_why_place() -> Dictionary:
	for view_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for count in [3, 5]:
			for source in ["party", "named", "token_party", "token_named"]:
				var m := _mount(RealmShellScene, view_size)
				var shell := m[1] as RealmShell
				shell.set_layout({ "profile": &"standard", "logical_size": Vector2(view_size), "safe_insets": Vector4.ZERO })
				var party_holds: bool = source.ends_with("party")
				var snap := _explore_snap(1, "capacity_spent", "" if party_holds else "Echo 1", 0)
				snap["data"]["party_preview"] = _party_snap("x", "", count)["data"]["party_preview"]
				snap["data"]["stop"]["echo_id"] = "" if party_holds else "e1"
				shell.set_snapshot(snap)
				_settle_layout(shell)
				shell.call("_on_stop_beat", &"mark")
				var card := shell.get_node("%StageWhyCard") as StageWhyCard
				var screen := shell.get("_active_overlay") as Control
				var holder := shell.get("_stop_holder") as Control
				var where := "%s party %d source %s" % [str(view_size), count, source]
				if holder == null:
					return _fail(m, "%s: no mark holder" % where)
				match source:
					"party", "named": shell.call("_toggle_why", holder)
					_: shell.call("_on_why_requested")
				if not card.is_open():
					return _fail(m, "%s: the card did not open" % where)
				var rect := card.get_global_rect()
				var icon := holder.get_global_rect()
				var bar_top: float = screen.call("advance_bar_top")
				var safe := Rect2(Vector2(16, 16), Vector2(view_size) - Vector2(32, 32))
				var centred := absf(rect.get_center().x - icon.get_center().x) < 1.0
				var clamped := absf(rect.position.x - safe.position.x) < 1.0 or absf(rect.end.x - safe.end.x) < 1.0
				var error := ""
				if absf(rect.end.y - (bar_top - 8.0)) > 1.0:
					error = "bottom %f must be 8 px above the Advance bar top %f" % [rect.end.y, bar_top]
				elif not (centred or clamped):
					error = "card centre %f must match icon centre %f" % [rect.get_center().x, icon.get_center().x]
				elif not safe.encloses(rect):
					error = "card %s outside the safe area" % str(rect)
				elif rect.intersects((screen.get_node("%AdvanceButton") as Control).get_global_rect()) or rect.intersects((screen.get_node("%ReturnButton") as Control).get_global_rect()):
					error = "card covers the Advance or Return button"
				if error != "":
					return _fail(m, "%s: %s" % [where, error])
				m[0].free()
	return { "ok": true }


static func _t_token_tap_rules() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	var card := shell.get_node("%StageWhyCard") as StageWhyCard
	var empty := _snap("", "")
	empty["data"]["travel_why"] = {}
	var cases := {
		"mark": [_snap("capacity_spent", ""), true],
		"no mark, entry exists": [_snap("", ""), true],
		"no mark, no entry": [empty, false],
	}
	for name in cases:
		_feed(shell, cases[name][0])
		shell.call("_on_why_requested")
		if card.is_open() != cases[name][1]:
			return _fail(m, "token tap, %s: open state must be %s" % [name, str(cases[name][1])])
		card.close()
	m[0].free()
	return { "ok": true }


static func _t_token_tap_closes() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	var card := shell.get_node("%StageWhyCard") as StageWhyCard
	_feed(shell, _snap("capacity_spent", ""))
	shell.call("_on_why_requested")
	if not card.is_open():
		return _fail(m, "first token tap must open the card")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(640, 300)
	shell.call("_input", press)
	shell.call("_on_why_requested")
	if card.is_open():
		return _fail(m, "second token tap (press closes, release taps) must leave the card closed")
	m[0].free()
	return { "ok": true }


static func _t_hidden_shell() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	var card := shell.get_node("%StageWhyCard") as StageWhyCard
	_feed(shell, _snap("capacity_spent", ""))
	shell.call("_on_why_requested")
	if not card.is_open():
		return _fail(m, "the card must open before the shell is hidden")
	shell.visible = false  # AppRoot hides non-target shells the same way
	if card.is_open():
		return _fail(m, "hiding the shell must close the why card")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	shell.call("_input", cancel)
	if (m[0] as Viewport).is_input_handled():
		return _fail(m, "a hidden shell must not handle ui_cancel")
	m[0].free()
	return { "ok": true }


static func _t_same_holder_fade() -> Dictionary:
	for early_beat in [false, true]:
		var m := _mount(RealmShellScene)
		var shell := m[1] as RealmShell
		_feed(shell, _snap("capacity_spent", "Kofi"))
		var card: EchoCardItem
		for c in _cards(shell):
			if (c as EchoCardItem).has_stop_glyph():
				card = c
		var glyph := card.get_node("%StopGlyph") as TextureRect
		var old_tex := StopGlyphs.texture("capacity_spent")
		var new_tex := StopGlyphs.texture("interrupted")
		shell.call("_on_advance_started")
		shell.call("_on_travel_started")
		_feed(shell, _snap("interrupted", "Kofi"))
		if glyph.texture != old_tex or not is_equal_approx(glyph.modulate.a, 0.5):
			return _fail(m, "old glyph must stay at alpha 0.5 until the fade runs, got alpha %f" % glyph.modulate.a)
		if early_beat:
			shell.call("_on_stop_beat", &"mark")
			if glyph.texture != new_tex:
				return _fail(m, "a beat before the fade ends must show the new shape")
		else:
			var fade: Tween = (card.get("_motion") as StopMarkMotion).get("_fade")
			fade.custom_step(0.1)
			if glyph.texture != old_tex or not (glyph.modulate.a > 0.0 and glyph.modulate.a < 0.5):
				return _fail(m, "old glyph must fade, not cut: alpha %f" % glyph.modulate.a)
			fade.custom_step(0.15)
			if glyph.texture != new_tex or glyph.modulate.a != 0.0:
				return _fail(m, "after the fade the new shape waits unseen")
			shell.call("_on_stop_beat", &"mark")
		var settle: Tween = (card.get("_motion") as StopMarkMotion).get("_settle")
		settle.custom_step(1.0)
		if glyph.texture != new_tex or not is_equal_approx(glyph.modulate.a, 1.0):
			return _fail(m, "new glyph must settle in")
		m[0].free()
	return { "ok": true }


static func _t_no_mark_without_kind() -> Dictionary:
	var m := _mount(RealmShellScene)
	_feed(m[1], _snap("", ""))
	var party := m[1].get_node("%PartyCard") as EchoCardItem
	var any_glyph := party.has_stop_glyph() or _cards(m[1]).any(func(c: Node) -> bool: return (c as EchoCardItem).has_stop_glyph())
	var ok: bool = party.visible and not any_glyph
	m[0].free()
	return { "ok": ok, "error": "no stop kind must show no mark" }


static func _visible_texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n in root.find_children("*", "Label", true, false):
		if (n as Label).is_visible_in_tree() or (n as Label).visible:
			out.append((n as Label).text)
	return out


static func _t_why_card_clean() -> Dictionary:
	var m := _mount(WhyCardScene)
	var card := m[1] as StageWhyCard
	for echo in ["", "Ama"]:
		card.open({ "cause": "echo", "purpose_family": "read", "route_character": "skirted", "stop_kind": "paused_to_read",
			"named_echo_name": echo, "echo_reason_class": "fear" if echo != "" else "" })
		var shown := 0
		for text in _visible_texts(card):
			for ch in text:
				if ch >= "0" and ch <= "9":
					return _fail(m, "digit in why card text: " + text)
			if text.contains("internal_echo_id"):
				return _fail(m, "id in why card text")
		for row in ["%RowCause", "%RowPurpose", "%RowRoute", "%RowEcho"]:
			if (card.get_node(row) as Label).visible:
				shown += 1
		if shown > 4 or shown == 0:
			return _fail(m, "rows shown: %d" % shown)
	m[0].free()
	return { "ok": true }


static func _t_why_unknown_token() -> Dictionary:
	var m := _mount(WhyCardScene)
	var card := m[1] as StageWhyCard
	card.open({ "cause": "e_0142", "purpose_family": "_status", "route_character": "7", "stop_kind": "nope", "named_echo_name": "", "echo_reason_class": "" })
	var texts := _visible_texts(card).filter(func(t: String) -> bool: return not t.is_empty() and t != "✕")
	m[0].free()
	return { "ok": texts.is_empty(), "error": "unknown tokens must show nothing, got %s" % str(texts) }


static func _t_step_row_lost() -> Dictionary:
	var m := _mount(StageScene)
	var screen := m[1] as StageExploreScreen
	var data := { "map_width": 6, "map_height": 6, "party_pos": { "col": 1, "row": 1 }, "step_budget": 5, "effective_steps": 3,
		"party_preview": [], "situations": [], "terrain": {} }
	screen.set_snapshot({ "type": "flow.stage_explore", "data": data, "actions": {} })
	var bar := screen.get_node("%StepProgressBar")
	var ok: bool = int(bar.get("_budget")) == 5 and int(bar.get("_lost")) == 2 \
		and bar.get_parent().name == "StepBarShake" and not (bar.get_parent() is Container)
	m[0].free()
	return { "ok": ok, "error": "bar must hold 5 diamonds with 2 lost, inside a plain Control" }


static func _t_fraction_label_gone() -> Dictionary:
	var m := _mount(StageScene)
	var gone: bool = m[1].get_node_or_null("%StepFractionLabel") == null
	m[0].free()
	return { "ok": gone, "error": "StepFractionLabel must be deleted (D-43)" }


static func _t_presentation_read() -> Dictionary:
	var m := _mount(StageScene)
	var screen := m[1] as StageExploreScreen
	var fallback: float = screen.call("_pres", "walk_seconds", 0.5)
	screen.set("_presentation", { "walk_seconds": 0.9, "bad": "text" })
	var read: float = screen.call("_pres", "walk_seconds", 0.5)
	var bad: float = screen.call("_pres", "bad", 0.25)
	m[0].free()
	return { "ok": is_equal_approx(fallback, 0.5) and is_equal_approx(read, 0.9) and is_equal_approx(bad, 0.25), "error": "_pres read or fallback wrong" }


static func _t_no_directive_literal() -> Dictionary:
	var re := RegEx.create_from_string("[\"']directive\\.(?!(select|confirm)[\"'])[a-z_]+[\"']")
	var stack: Array[String] = ["res://ui"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + sub)
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") or f.ends_with(".tscn"):
				if re.search(FileAccess.get_file_as_string(dir + "/" + f)) != null:
					return { "ok": false, "error": "Directive id literal in " + dir + "/" + f }
	return { "ok": true }


# ─── Stop motion (F2) ─────────────────────────────────────────────────────────

static func _pres_full() -> Dictionary:
	return { "walk_seconds": 0.5, "snippet_fade_in_seconds": 0.4, "snippet_hold_seconds": 2.1, "snippet_fade_out_seconds": 0.5,
		"stop_rest_seconds": 0.2, "beat_gap_seconds": 0.1, "glyph_fade_seconds": 0.2, "glyph_settle_seconds": 0.4,
		"glyph_settle_from_scale": 0.9, "glyph_settle_overshoot_scale": 1.2, "chip_settle_seconds": 0.3, "glyph_press_seconds": 0.08,
		"why_open_seconds": 0.15, "why_close_seconds": 0.1, "portrait_pulse_seconds": 0.6, "portrait_pulse_peak": 1.5,
		"shaken_shake_seconds": 0.25, "shaken_shake_offsets_px": [4, 4, 2, 2], "cross_stagger_seconds": 0.1, "cross_in_seconds": 0.2,
		"reduced_motion_fade_seconds": 0.15, "overlay_hold_seconds": 0.35 }


static func _explore_snap(col: int, kind: String, named: String, lost: int, snippet: String = "") -> Dictionary:
	var snap := _snap(kind, named)
	var d: Dictionary = snap["data"]
	d.merge({ "map_width": 6, "map_height": 6, "party_pos": { "col": col, "row": 1 }, "step_budget": 5, "effective_steps": 5 - lost,
		"situations": [], "terrain": {}, "presentation": _pres_full(), "travel_snippet": snippet,
		"traveled_origin": { "col": 1, "row": 1 }, "traveled_path": [{ "col": 2, "row": 1 }, { "col": 3, "row": 1 }] if col > 1 else [] })
	snap["actions"] = { "cta.advance_turn": {} }
	return snap


## Mounts the stage screen on its first-entry snapshot, then sends a travel snapshot. Returns [viewport, screen, beats].
static func _travel(kind: String, named: String, lost: int, snippet: String = "") -> Array:
	var m := _mount(StageScene)
	var screen := m[1] as StageExploreScreen
	var beats: Array = []
	screen.stop_beat.connect(func(b: StringName) -> void: beats.append(b))
	screen.set_snapshot(_explore_snap(1, kind, named, 0))
	screen.set_snapshot(_explore_snap(3, kind, named, lost, snippet))
	return [m[0], screen, beats]


static func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.002


static func _t_motion_calm() -> Dictionary:
	var t := _travel("capacity_spent", "Kofi", 0)
	var screen := t[1] as StageExploreScreen
	var plan: Dictionary = screen.get("_stop_plan")
	var ok: bool = _near(plan["mark_at"], 0.2) and _near(plan["ready_at"], 0.6) and _near(plan["pulse_at"], 0.7) and _near(plan["snippet_at"], 0.7) \
		and float(plan["shake_at"]) < 0.0
	if not ok:
		return _fail(t, "calm plan wrong: %s" % str(plan))
	var walk := screen.get("_travel_tween") as Tween
	walk.custom_step(0.5001)
	var stop := screen.get("_stop_tween") as Tween
	if stop == null or not stop.is_valid():
		return _fail(t, "walk end must start the stop beats")
	stop.custom_step(0.19)
	if not (t[2] as Array).is_empty():
		return _fail(t, "mark must wait for stop_rest_seconds")
	stop.custom_step(0.02)
	if t[2] != [&"mark"]:
		return _fail(t, "mark beat missing at rest end: %s" % str(t[2]))
	stop.custom_step(0.5001)
	if t[2] != [&"mark", &"pulse"]:
		return _fail(t, "pulse must follow the mark: %s" % str(t[2]))
	t[0].free()
	return { "ok": true }


static func _t_overlay_after_mark() -> Dictionary:
	for lost in [0, 2, 5]:
		var m := _mount(StageScene)
		var screen := m[1] as StageExploreScreen
		var events: Array = []
		var clock := [0.0]
		screen.stop_beat.connect(func(b: StringName) -> void: events.append([b, clock[0]]))
		screen.modal_requested.connect(func(_id: StringName, _payload: Dictionary) -> void: events.append([&"modal", clock[0]]))
		screen.set_snapshot(_explore_snap(1, "capacity_spent", "Kofi", 0))
		var travel := _explore_snap(3, "capacity_spent", "Kofi", lost)
		travel["data"]["contact_pending"] = { "x": 1 }
		screen.set_snapshot(travel)
		var walk := screen.get("_travel_tween") as Tween
		for i in range(300):
			clock[0] += 0.01
			walk.custom_step(0.01)
			var stop: Tween = screen.get("_stop_tween")
			if stop != null and stop.is_valid() and clock[0] > 0.5:
				stop.custom_step(0.01)
		var mark_at := -1.0
		var modal_at := -1.0
		for e in events:
			if e[0] == &"mark":
				mark_at = e[1]
			elif e[0] == &"modal":
				modal_at = e[1]
		if modal_at < 0.0 or mark_at < 0.0 or modal_at < mark_at:
			return _fail(m, "lost %d: mark at %f, modal at %f" % [lost, mark_at, modal_at])
		m[0].free()
	return { "ok": true }


static func _t_motion_shaken() -> Dictionary:
	var t := _travel("capacity_spent", "", 2)
	var screen := t[1] as StageExploreScreen
	var plan: Dictionary = screen.get("_stop_plan")
	# shake 0.25 vs crosses 0.1 + 0.2 = 0.3: the longer one sets the beat; the mark follows after the gap.
	if not (_near(plan["shake_at"], 0.2) and _near(plan["mark_at"], 0.6) and float(plan["pulse_at"]) < 0.0):
		return _fail(t, "shaken plan wrong: %s" % str(plan))
	var bar := screen.get_node("%StepProgressBar")
	var layer := screen.get_node("%PartyTokenLayer") as Node2D
	var cam := screen.get_node("%BoardCamera") as Camera2D
	cam.zoom = Vector2(2, 2)
	(screen.get("_travel_tween") as Tween).custom_step(0.5001)
	var stop := screen.get("_stop_tween") as Tween
	stop.custom_step(0.201)
	var cross := screen.get("_cross_tween") as Tween
	var shake := screen.get("_shake_tween") as Tween
	if cross == null or shake == null or not cross.is_valid():
		return _fail(t, "shake beat must start both tweens")
	if (bar.get("_cross_alpha") as Array).any(func(a: float) -> bool: return a > 0.0):
		return _fail(t, "crosses must be hidden before the beat")
	shake.custom_step(0.025)
	if not (_near((bar as Control).position.x, 2.0) and _near(layer.position.x, 1.0)):
		return _fail(t, "shake is 4 px on the bar and 4 / zoom on the token: bar %f token %f" % [(bar as Control).position.x, layer.position.x])
	shake.custom_step(0.3)
	if layer.position.x != 0.0 or (bar as Control).position.x != 0.0:
		return _fail(t, "shake must end at rest, token %f bar %f" % [layer.position.x, (bar as Control).position.x])
	cross.custom_step(0.31)
	if (bar.get("_cross_alpha") as Array).any(func(a: float) -> bool: return not _near(a, 1.0)):
		return _fail(t, "all crosses must be in after the stagger")
	t[0].free()
	return { "ok": true }


static func _t_motion_snippet() -> Dictionary:
	var t := _travel("capacity_spent", "Kofi", 0, "A line.")
	var screen := t[1] as StageExploreScreen
	var label := screen.get_node("%TravelSnippetLabel") as Label
	var tween := screen.get("_snippet_tween") as Tween
	tween.custom_step(0.5 + 0.7 - 0.01)
	var early := label.modulate.a
	tween.custom_step(0.21)
	var later := label.modulate.a
	t[0].free()
	if early != 0.0 or later < 0.4:
		return { "ok": false, "error": "snippet must start 0.7 s after the walk begins; early %f later %f" % [early, later] }
	var m := _mount(StageScene)
	var screen2 := m[1] as StageExploreScreen
	screen2.set_snapshot(_explore_snap(1, "capacity_spent", "Kofi", 0, "Entry line."))
	(screen2.get("_snippet_tween") as Tween).custom_step(0.2)
	var at_once: float = (screen2.get_node("%TravelSnippetLabel") as Label).modulate.a
	m[0].free()
	return { "ok": at_once > 0.4, "error": "a stage entry must play the snippet at once" }


static func _t_motion_cut() -> Dictionary:
	var t := _travel("capacity_spent", "", 2, "A line.")
	var screen := t[1] as StageExploreScreen
	var btn := screen.get_node("%AdvanceButton") as Button
	if not btn.disabled:
		return _fail(t, "Advance must wait during the walk")
	(screen.get("_travel_tween") as Tween).custom_step(0.5001)
	var stop := screen.get("_stop_tween") as Tween
	stop.custom_step(0.201)
	var shake := screen.get("_shake_tween") as Tween
	shake.custom_step(0.06)
	stop.custom_step(0.9 - 0.201 + 0.01)
	if btn.disabled:
		return _fail(t, "Advance must be ready when the mark has settled")
	var ready_at := float((screen.get("_stop_plan") as Dictionary)["ready_at"])
	if ready_at < 0.8:
		return _fail(t, "ready_at too early: %f" % ready_at)
	var started := [0]
	screen.advance_started.connect(func() -> void: started[0] += 1)
	screen.call("_on_advance_pressed")
	var layer := screen.get_node("%PartyTokenLayer") as Node2D
	var bar := screen.get_node("%StepProgressBar")
	var dead := not shake.is_valid() and not stop.is_valid() and not (screen.get("_cross_tween") as Tween).is_valid()
	var ok: bool = dead and started[0] == 1 and layer.position.x == 0.0 and (bar as Control).position.x == 0.0 \
		and not (bar.get("_cross_alpha") as Array).any(func(a: float) -> bool: return a < 1.0)
	t[0].free()
	return { "ok": ok, "error": "a new Advance must kill every stop tween and reset the board" }


static func _t_lock_walk_end() -> Dictionary:
	for lost in [0, 2]:
		var t := _travel("capacity_spent", "", lost)
		var screen := t[1] as StageExploreScreen
		var btn := screen.get_node("%AdvanceButton") as Button
		var walk := screen.get("_travel_tween") as Tween
		if not btn.disabled:
			return _fail(t, "lost %d: Advance must be off during the walk" % lost)
		walk.custom_step(0.4)
		if not btn.disabled:
			return _fail(t, "lost %d: Advance must stay off until the walk ends" % lost)
		walk.custom_step(0.1001)
		if btn.disabled:
			return _fail(t, "lost %d: Advance must be ready when the walk ends" % lost)
		var stop := screen.get("_stop_tween") as Tween
		if stop == null or not stop.is_valid():
			return _fail(t, "lost %d: the stop beats must still run" % lost)
		for i in range(150):
			if stop.is_valid():
				stop.custom_step(0.01)
			if btn.disabled:
				return _fail(t, "lost %d: a stop beat disabled Advance at step %d" % [lost, i])
		t[0].free()
	return { "ok": true }


static func _t_press_in_beats() -> Dictionary:
	var t := _travel("capacity_spent", "Kofi", 2, "A line.")
	var screen := t[1] as StageExploreScreen
	var started := [0]
	screen.advance_started.connect(func() -> void: started[0] += 1)
	(screen.get("_travel_tween") as Tween).custom_step(0.5001)
	var stop := screen.get("_stop_tween") as Tween
	stop.custom_step(0.21)
	var shake := screen.get("_shake_tween") as Tween
	shake.custom_step(0.05)
	screen.call("_on_advance_pressed")
	screen.call("_on_advance_pressed")
	var bar := screen.get_node("%StepProgressBar")
	var layer := screen.get_node("%PartyTokenLayer") as Node2D
	var dead := not stop.is_valid() and not shake.is_valid() and not (screen.get("_cross_tween") as Tween).is_valid()
	var reset: bool = layer.position.x == 0.0 and (bar as Control).position.x == 0.0 \
		and not (bar.get("_cross_alpha") as Array).any(func(a: float) -> bool: return a < 1.0)
	var ok: bool = dead and reset and started[0] == 1 and bool(screen.get("_advance_pending"))
	t[0].free()
	return { "ok": ok, "error": "a press in the stop beats must kill them, reset the board and start one Advance (dead %s, reset %s, started %d)" % [str(dead), str(reset), started[0]] }


static func _t_step_row_depth() -> Dictionary:
	# budget, effective, depth (-1 = absent), crossed, lost to readiness
	var cases := [[3, 3, 2, 1, 0], [6, 6, 5, 1, 0], [6, 5, 4, 2, 1], [3, 3, 0, 3, 0], [6, 6, 6, 0, 0], [6, 6, 9, 0, 0], [5, 3, -1, 2, 2]]
	for c in cases:
		var m := _mount(StageScene)
		var screen := m[1] as StageExploreScreen
		var data := { "map_width": 6, "map_height": 6, "party_pos": { "col": 1, "row": 1 }, "step_budget": c[0], "effective_steps": c[1],
			"party_preview": [], "situations": [], "terrain": {} }
		if c[2] >= 0:
			data["commitment_depth"] = c[2]
		screen.set_snapshot({ "type": "flow.stage_explore", "data": data, "actions": {} })
		var bar := screen.get_node("%StepProgressBar")
		var plan: Dictionary = screen.call("_build_stop_plan", data)
		var ok: bool = int(bar.get("_budget")) == c[0] and int(bar.get("_lost")) == c[3] and int(plan["crossed"]) == c[3] and int(plan["lost"]) == c[4] \
			and (float(plan["shake_at"]) >= 0.0) == (c[4] > 0) and (float(plan["cross_at"]) >= 0.0) == (c[3] > 0)
		m[0].free()
		if not ok:
			return { "ok": false, "error": "case %s: crossed %d lost %d plan %s" % [str(c), int(bar.get("_lost")), c[4], str(plan)] }
	return { "ok": true }


static func _t_motion_reduced() -> Dictionary:
	StopMarkMotion.reduced = true
	var t := _travel("capacity_spent", "Kofi", 2)
	var screen := t[1] as StageExploreScreen
	var plan: Dictionary = screen.get("_stop_plan")
	(screen.get("_travel_tween") as Tween).custom_step(0.5001)
	(screen.get("_stop_tween") as Tween).custom_step(0.001)
	var no_shake: bool = screen.get("_shake_tween") == null
	var crosses := screen.get("_cross_tween") as Tween
	var plan_ok: bool = _near(plan["shake_at"], 0.0) and _near(plan["mark_at"], 0.15 + 0.1) and float(plan["pulse_at"]) < 0.0
	StopMarkMotion.reduced = false
	t[0].free()
	var m := _mount(RealmShellScene)
	StopMarkMotion.reduced = true
	var snap := _snap("capacity_spent", "Kofi")
	snap["data"]["presentation"] = _pres_full()
	m[1].call("_on_travel_started")
	_feed(m[1], snap)
	m[1].call("_on_stop_beat", &"mark")
	var holder: EchoCardItem
	for card in _cards(m[1]):
		if (card as EchoCardItem).has_stop_glyph():
			holder = card
	var glyph := holder.get_node("%StopGlyph") as Control
	m[1].call("_on_stop_beat", &"pulse")
	var settle := holder.get("_motion").get("_settle") as Tween
	settle.custom_step(0.05)
	var scale_flat: bool = glyph.scale == Vector2.ONE
	var no_pulse: bool = holder.get("_pulse") == null
	StopMarkMotion.reduced = false
	m[0].free()
	var ok: bool = no_shake and crosses != null and plan_ok and scale_flat and no_pulse
	return { "ok": ok, "error": "reduced: shake %s crosses %s plan %s flat %s nopulse %s" % [no_shake, crosses != null, plan_ok, scale_flat, no_pulse] }


static func _t_motion_shell_mark() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell: Control = m[1]
	var snap := _snap("interrupted", "Kofi")
	snap["data"]["presentation"] = _pres_full()
	shell.call("_on_travel_started")
	_feed(shell, snap)
	var holder: EchoCardItem
	for card in _cards(shell):
		if (card as EchoCardItem).has_stop_glyph():
			holder = card
	var glyph := holder.get_node("%StopGlyph") as Control
	var why := shell.get_node("%StageWhyCard") as StageWhyCard
	if glyph.modulate.a != 0.0:
		return _fail(m, "the mark must be invisible before its beat")
	holder.card_pressed.emit(holder.actor_id())
	if why.is_open():
		return _fail(m, "a tap before the mark shows must do nothing")
	shell.call("_on_stop_beat", &"mark")
	var settle := holder.get("_motion").get("_settle") as Tween
	if settle == null or not settle.is_valid():
		return _fail(m, "the mark must settle on its beat")
	holder.card_pressed.emit(holder.actor_id())
	if not why.is_open():
		return _fail(m, "a tap must open the why card from the first visible frame")
	settle.custom_step(0.239)
	var over := glyph.scale.x
	settle.custom_step(0.5001)
	var rest := glyph.scale.x
	var alpha := glyph.modulate.a
	m[0].free()
	return { "ok": over > 1.15 and over <= 1.2001 and _near(rest, 1.0) and _near(alpha, 1.0), "error": "settle must overshoot to 1.2 then rest at 1 (over %f)" % over }


static func _t_motion_press_pulse() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell: Control = m[1]
	var snap := _snap("interrupted", "Kofi")
	snap["data"]["presentation"] = _pres_full()
	_feed(shell, snap)
	var holder: EchoCardItem
	for card in _cards(shell):
		if (card as EchoCardItem).has_stop_glyph():
			holder = card
	var glyph := holder.get_node("%StopGlyph") as Control
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	holder.call("_on_gui_input", down)
	(holder.get("_motion").get("_press") as Tween).custom_step(0.09)
	var pressed_ok: bool = _near(glyph.modulate.r, 0.85) and _near(glyph.scale.x, 0.95)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	holder.call("_on_gui_input", up)
	(holder.get("_motion").get("_press") as Tween).custom_step(0.09)
	var back_ok: bool = _near(glyph.modulate.r, 1.0) and _near(glyph.scale.x, 1.0)
	shell.call("_on_stop_beat", &"pulse")
	var portrait := holder.get_node("%PortraitPanel") as Control
	var pulse := holder.get("_pulse") as Tween
	pulse.custom_step(0.301)
	var peak := portrait.modulate.r
	pulse.custom_step(0.31)
	var end := portrait.modulate.r
	m[0].free()
	return { "ok": pressed_ok and back_ok and _near(peak, 1.5) and _near(end, 1.0),
		"error": "press %s back %s pulse peak %f end %f" % [pressed_ok, back_ok, peak, end] }


static func _t_motion_no_leak() -> Dictionary:
	var snap1 := _explore_snap(1, "capacity_spent", "", 2)
	var snap2 := _explore_snap(3, "capacity_spent", "", 2, "A line.")
	var before := [snap1.hash(), snap2.hash()]
	var m := _mount(StageScene)
	var screen := m[1] as StageExploreScreen
	screen.set_snapshot(snap1)
	screen.set_snapshot(snap2)
	(screen.get("_travel_tween") as Tween).custom_step(0.5001)
	(screen.get("_stop_tween") as Tween).custom_step(0.25)
	var tweens: Array = []
	for name in ["_travel_tween", "_stop_tween", "_shake_tween", "_cross_tween", "_snippet_tween"]:
		tweens.append(screen.get(name))
	if tweens.any(func(x: Variant) -> bool: return x == null or not (x as Tween).is_valid()):
		return _fail(m, "every effect tween must run before the exit")
	m[0].free()
	var leaked := tweens.any(func(x: Variant) -> bool: return (x as Tween).is_valid())
	return { "ok": not leaked and before == [snap1.hash(), snap2.hash()], "error": "a tween outlived the screen, or a snapshot changed" }


static func _t_glyph_textures() -> Dictionary:
	for kind in StopGlyphs.KINDS:
		var tex := StopGlyphs.texture(kind)
		if tex == null:
			return { "ok": false, "error": "%s: no texture" % kind }
		var img := tex.get_image()
		if tex.get_width() != 256 or tex.get_height() != 256 or not img.detect_alpha():
			return { "ok": false, "error": "%s: must be 256 x 256 with alpha" % kind }
	if StopGlyphs.texture("not_a_kind") != null:
		return { "ok": false, "error": "an unknown kind must give null" }
	return { "ok": true }


static func _t_no_svg_glyph() -> Dictionary:
	for f in DirAccess.get_files_at("res://assets/ui/stage_stop_glyphs"):
		if f.contains(".svg"):
			return { "ok": false, "error": "svg glyph left: %s" % f }
	if FileAccess.get_file_as_string("res://ui/components/StopGlyphs.gd").contains(".svg"):
		return { "ok": false, "error": "StopGlyphs.gd still names .svg" }
	return { "ok": true }


static func _t_glyph_filter() -> Dictionary:
	var card := CardScene.instantiate() as Control
	var why := WhyCardScene.instantiate() as Control
	var ok: bool = (card.get_node("%StopGlyph") as TextureRect).texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS \
		and (why.get_node("%HeaderGlyph") as TextureRect).texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	card.free()
	why.free()
	return { "ok": ok, "error": "both glyph rects need linear-with-mipmaps filtering" }


static func _t_glyphs_differ() -> Dictionary:
	var seen := {}
	for kind in StopGlyphs.KINDS:
		var h := StopGlyphs.texture(kind).get_image().get_data().hex_encode().hash()
		if seen.has(h):
			return { "ok": false, "error": "%s has the same image as %s" % [kind, seen[h]] }
		seen[h] = kind
	return { "ok": true }
