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
	var re := RegEx.create_from_string("\"directive\\.(?!select\"|confirm\")[a-z_]+\"")
	var stack: Array[String] = ["res://ui"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + sub)
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				if re.search(FileAccess.get_file_as_string(dir + "/" + f)) != null:
					return { "ok": false, "error": "Directive id literal in " + dir + "/" + f }
	return { "ok": true }
