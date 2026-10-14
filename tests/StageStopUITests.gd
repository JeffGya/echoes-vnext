extends RefCounted
class_name StageStopUITests

## V2-DIRECTIVE-002 B+C frontend, structure and data only: the stop glyph, the party chip, the why card,
## the step row, the Directive badge and the presentation reads. Each test mounts the real .tscn.

const RealmShellScene := preload("res://ui/shells/RealmShell.tscn")
const StageScene := preload("res://ui/screens/venture/StageExploreScreen.tscn")
const WhyCardScene := preload("res://ui/components/StageWhyCard.tscn")
const ChipScene := preload("res://ui/components/PartyStopChip.tscn")
const CardScene := preload("res://ui/components/EchoCardItem.tscn")
const PARTY: Array[String] = ["Ama", "Kofi", "Yaa"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("stage_stop_ui/scenes_load", Callable(StageStopUITests, "_t_scenes_load"))
	runner.register_test("stage_stop_ui/glyph_on_named_card_for_all_six_kinds", Callable(StageStopUITests, "_t_glyph_per_kind"))
	runner.register_test("stage_stop_ui/glyph_matches_by_id_when_names_repeat", Callable(StageStopUITests, "_t_glyph_by_id"))
	runner.register_test("stage_stop_ui/chip_only_when_no_echo_named", Callable(StageStopUITests, "_t_chip_only_without_name"))
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
	runner.register_test("stage_stop_ui/chip_slot_fixed_inside_view_cards_never_shift", Callable(StageStopUITests, "_t_chip_slot"))
	runner.register_test("stage_stop_ui/overlay_opens_after_the_mark_lands", Callable(StageStopUITests, "_t_overlay_after_mark"))
	runner.register_test("stage_stop_ui/token_tap_closes_open_why_card", Callable(StageStopUITests, "_t_token_tap_closes"))
	runner.register_test("stage_stop_ui/same_holder_old_glyph_fades_then_new_settles", Callable(StageStopUITests, "_t_same_holder_fade"))
	runner.register_test("stage_stop_ui/no_directive_id_literal_in_ui", Callable(StageStopUITests, "_t_no_directive_literal"))


static func _mount(scene: PackedScene) -> Array:
	var host := (Engine.get_main_loop() as SceneTree).current_scene.get_node("UISnapshotRenderer")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
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
	for scene in [RealmShellScene, StageScene, WhyCardScene, ChipScene, CardScene]:
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
		if (m[1].get_node("%PartyStopChip") as Control).visible:
			return _fail(m, "%s: chip shows next to a card glyph" % kind)
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


static func _t_chip_only_without_name() -> Dictionary:
	var m := _mount(RealmShellScene)
	_feed(m[1], _snap("capacity_spent", ""))
	var chip := m[1].get_node("%PartyStopChip") as PartyStopChip
	var cards_with_glyph := _cards(m[1]).filter(func(c: Node) -> bool: return (c as EchoCardItem).has_stop_glyph())
	var ok: bool = chip.visible and cards_with_glyph.is_empty() and chip.custom_minimum_size.x >= 48.0 and chip.custom_minimum_size.y >= 48.0
	m[0].free()
	return { "ok": ok, "error": "chip must show alone, at least 48 x 48" }


static func _t_chip_slot() -> Dictionary:
	var m := _mount(RealmShellScene)
	var shell := m[1] as RealmShell
	var frame := shell.get_node("%EchoBarFrame") as Control
	var scroll := shell.get_node("%EchoBarScroll") as ScrollContainer
	var chip := shell.get_node("%PartyStopChip") as Control
	for count in [1, 3, 4, 5]:
		for inset in [0.0, 48.0]:
			shell.set_layout({ "profile": &"standard", "logical_size": Vector2(1280, 720), "safe_insets": Vector4(inset, inset, inset, inset) })
			var xs: Array = []
			for kind in ["capacity_spent", ""]:
				var snap := _snap(kind, "")
				var rows: Array = []
				for i in range(count):
					rows.append({ "id": "e%d" % i, "name": "Echo %d" % i, "rank": 1, "calling_origin": "x", "emotional_status": "grounded" })
				snap["data"]["party_preview"] = rows
				_feed(shell, snap)
				for pass_index in range(4):
					shell.propagate_notification(Control.NOTIFICATION_RESIZED)
					shell.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)
				var view := Rect2(Vector2(maxf(16.0, inset), maxf(16.0, inset)), Vector2(1280.0 - 2.0 * maxf(16.0, inset), 720.0 - 2.0 * maxf(16.0, inset)))
				var where := "party %d inset %d kind '%s'" % [count, int(inset), kind]
				if kind != "":
					var rect := chip.get_global_rect()
					if not chip.visible or not view.encloses(rect):
						return _fail(m, "%s: chip %s outside view %s" % [where, str(rect), str(view)])
					if rect.size.x < 48.0 or rect.size.y < 48.0:
						return _fail(m, "%s: chip under 48 px" % where)
					if rect.intersects(scroll.get_global_rect()):
						return _fail(m, "%s: chip overlaps the card scroll area" % where)
					for card in _cards(shell):
						if rect.intersects((card as Control).get_global_rect().intersection(scroll.get_global_rect())):
							return _fail(m, "%s: chip covers a card" % where)
				elif chip.visible:
					return _fail(m, "%s: chip shows without a stop" % where)
				for card in _cards(shell):
					if (card as Control).size.x < 280.0 - 0.1:
						return _fail(m, "%s: card under 280 wide" % where)
				xs.append((_cards(shell)[0] as Control).get_global_rect().position.x)
				if frame.get_global_rect().size.x <= 0.0:
					return _fail(m, "frame has no size")
			if not is_equal_approx(xs[0], xs[1]):
				return _fail(m, "party %d inset %d: cards moved %s -> %s" % [count, int(inset), str(xs[0]), str(xs[1])])
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
	var chip := m[1].get_node("%PartyStopChip") as Control
	var any_glyph := _cards(m[1]).any(func(c: Node) -> bool: return (c as EchoCardItem).has_stop_glyph())
	var ok: bool = not chip.visible and not any_glyph
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
	# shake 0.25 vs crosses 0.1 + 0.2 = 0.3: the longer one sets the beat; the chip follows after the gap.
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
