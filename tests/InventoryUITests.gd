extends RefCounted
class_name InventoryUITests

## V2-ITEM-001a step 8: the inventory UI. Each test mounts the real .tscn and feeds it a snapshot fixture
## (tests/fixtures/InventoryUIFixtures.gd). Fixture sizes and names are arbitrary; no test reads data/balance.json.
## Dispatch tests read the action the UI emits; they do not run the core.

const FX := preload("res://tests/fixtures/InventoryUIFixtures.gd")
const ItemUiText := preload("res://ui/components/ItemUiText.gd")
const ItemMovePlan := preload("res://ui/components/ItemMovePlan.gd")
const ItemResultRow := preload("res://ui/components/ItemResultRow.gd")
const PanelsScene := preload("res://ui/components/InventoryPanels.tscn")
const TileScene := preload("res://ui/components/ItemTile.tscn")
const ModalScene := preload("res://ui/overlays/ItemDiscardModal.tscn")
const PackButtonScene := preload("res://ui/components/PartyPackButton.tscn")
const ResolveScene := preload("res://ui/screens/venture/ResolveScreen.tscn")
const ReturnModalScene := preload("res://ui/overlays/realm/ReturnHomeModal.tscn")
const SanctumShellScene := preload("res://ui/shells/SanctumShell.tscn")
const RealmShellScene := preload("res://ui/shells/RealmShell.tscn")

const NEW_UI_SCRIPTS: Array[String] = [
	"res://ui/components/ItemUiText.gd", "res://ui/components/ItemTile.gd", "res://ui/components/ItemTileGlyphs.gd",
	"res://ui/components/ItemSlot.gd", "res://ui/components/ItemMovePlan.gd", "res://ui/components/ItemMeter.gd",
	"res://ui/components/ItemLoadMark.gd", "res://ui/components/ItemPanelDrop.gd", "res://ui/components/InventoryPanels.gd",
	"res://ui/components/PartyPackButton.gd", "res://ui/components/ItemResultRow.gd", "res://ui/overlays/ItemDiscardModal.gd",
]
const PLACE_WORDS: Array[String] = ["pack", "Sanctum", "sanctum", "path", "home", "stage", "Stage"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("inventory_ui/rail_button_sits_before_party_and_opens_the_panel", Callable(InventoryUITests, "_t_rail_button"))
	runner.register_test("inventory_ui/panel_sizes_come_from_the_snapshot_and_grow", Callable(InventoryUITests, "_t_sizes"))
	runner.register_test("inventory_ui/tiles_sit_in_their_slots_and_names_come_from_rows", Callable(InventoryUITests, "_t_slots_and_names"))
	runner.register_test("inventory_ui/no_id_or_core_text_reaches_a_label", Callable(InventoryUITests, "_t_no_ids"))
	runner.register_test("inventory_ui/tile_marks_shapes_and_five_states", Callable(InventoryUITests, "_t_tile_states"))
	runner.register_test("inventory_ui/stack_tile_has_edge_capsule_and_limit_mark", Callable(InventoryUITests, "_t_stack_tile"))
	runner.register_test("inventory_ui/placeholder_strings_are_marked_and_scenes_hold_no_words", Callable(InventoryUITests, "_t_placeholders"))
	runner.register_test("inventory_ui/panels_start_closed_and_open_alone", Callable(InventoryUITests, "_t_open_alone"))
	runner.register_test("inventory_ui/pack_panel_shows_no_counts_and_level_words", Callable(InventoryUITests, "_t_pack_panel"))
	runner.register_test("inventory_ui/party_pack_button_count_and_departure_line", Callable(InventoryUITests, "_t_pack_button"))
	runner.register_test("inventory_ui/move_button_dispatches_the_move_action", Callable(InventoryUITests, "_t_move_button"))
	runner.register_test("inventory_ui/drops_reorder_merge_and_cross_with_parameters", Callable(InventoryUITests, "_t_drops"))
	runner.register_test("inventory_ui/refused_drops_send_nothing_and_show_the_reason", Callable(InventoryUITests, "_t_refused_drops"))
	runner.register_test("inventory_ui/refusal_keys_map_to_text", Callable(InventoryUITests, "_t_reason_keys"))
	runner.register_test("inventory_ui/unchanged_snapshot_after_a_move_shows_the_generic_line", Callable(InventoryUITests, "_t_unchanged_after_move"))
	runner.register_test("inventory_ui/move_plan_follows_the_core_rules", Callable(InventoryUITests, "_t_move_plan"))
	runner.register_test("inventory_ui/path_view_is_read_only_with_one_discard", Callable(InventoryUITests, "_t_path_view"))
	runner.register_test("inventory_ui/discard_modal_focus_window_count_and_cancel_keys", Callable(InventoryUITests, "_t_discard_modal"))
	runner.register_test("inventory_ui/discard_flows_from_the_panel_to_the_modal_in_both_shells", Callable(InventoryUITests, "_t_discard_shells"))
	runner.register_test("inventory_ui/party_pack_button_is_ui_local_through_the_shell", Callable(InventoryUITests, "_t_party_shell"))
	runner.register_test("inventory_ui/result_row_is_one_row_with_survivors_and_ghosts", Callable(InventoryUITests, "_t_result_row"))
	runner.register_test("inventory_ui/result_row_motion_cap_finish_and_continue_guard", Callable(InventoryUITests, "_t_row_motion"))
	runner.register_test("inventory_ui/reduced_motion_is_a_short_fade", Callable(InventoryUITests, "_t_reduced_motion"))
	runner.register_test("inventory_ui/resolve_cards_show_items_and_guard_continue", Callable(InventoryUITests, "_t_resolve_cards"))
	runner.register_test("inventory_ui/leave_confirmation_shows_at_risk_tiles_and_guards_confirm", Callable(InventoryUITests, "_t_leave_confirm"))
	runner.register_test("inventory_ui/new_ui_files_never_read_the_save_or_the_core", Callable(InventoryUITests, "_t_source_grep"))
	runner.register_test("inventory_ui/theme_additions_use_no_forbidden_colour", Callable(InventoryUITests, "_t_theme_colours"))


# ── Helpers ────────────────────────────────────────────────────────────────

static func _mount(scene: PackedScene) -> Array:
	var host := (Engine.get_main_loop() as SceneTree).current_scene.get_node("UISnapshotRenderer")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var node := scene.instantiate()
	viewport.add_child(node)
	return [viewport, node]


static func _fail(m: Array, error: String) -> Dictionary:
	m[0].free()
	return { "ok": false, "error": error }


static func _pass(m: Array) -> Dictionary:
	m[0].free()
	return { "ok": true }


static func _set_reduced(value: bool) -> bool:
	var before: bool = StopMarkMotion.reduced
	StopMarkMotion.reduced = value
	return before


static func _panels(snap: Dictionary) -> Array:
	var m := _mount(PanelsScene)
	m[1].set_snapshot(snap)
	return m


static func _capture(node: Object, signal_name: String) -> Array:
	var got: Array = []
	node.connect(signal_name, func(a: Variant) -> void: got.append(a))
	return got


static func _slot(panels: Node, grid_name: String, index: int) -> Node:
	return (panels.get_node(grid_name) as GridContainer).get_child(index)


## Text of every shown control under `root`. A hidden node and its children show nothing.
static func _texts(root: Node, out: Array = []) -> Array:
	if root is CanvasItem and not (root as CanvasItem).visible:
		return out
	if root is Label:
		out.append((root as Label).text)
	elif root is Button:
		out.append((root as Button).text)
		out.append((root as Button).tooltip_text)
	elif root is RichTextLabel:
		out.append((root as RichTextLabel).text)
	for c in root.get_children():
		_texts(c, out)
	return out


static func _label_texts(root: Node, out: Array = []) -> Array:
	if root is CanvasItem and not (root as CanvasItem).visible:
		return out
	if root is Label:
		out.append((root as Label).text)
	for c in root.get_children():
		_label_texts(c, out)
	return out


static func _drag(from_box: String, slot: int) -> Dictionary:
	return { "item_drag": true, "from": from_box, "slot": slot, "row": {} }


# ── Rail, sizes, slots, names ──────────────────────────────────────────────

static func _t_rail_button() -> Dictionary:
	var m := _mount(SanctumShellScene)
	var shell: Control = m[1]
	var rail := shell.get_node("ChromeLayer/ChromeControl/BottomRail/MarginContainer/RailButtons")
	var button := shell.get_node("%InventoryButton") as Button
	var party := shell.get_node("%PartyButton") as Button
	if button.get_parent() != rail or rail.get_child(0) != button or rail.get_child(1) != party:
		return _fail(m, "the inventory button is not the rail button next to Party")
	if not button.disabled:
		return _fail(m, "the button is usable before any inventory screen")
	var shell_actions := _capture(shell, "action_requested")
	shell.set_snapshot(FX.sanctum_snap(FX.standard()))
	var panels := shell.get_node("%InventoryPanels")
	if button.disabled or button.text != ItemUiText.RAIL_LABEL:
		return _fail(m, "button disabled=%s text=%s after a Sanctum snapshot" % [button.disabled, button.text])
	if panels.is_sanctum_open():
		return _fail(m, "the panel starts open")
	button.pressed.emit()
	if not panels.is_sanctum_open() or button.theme_type_variation != &"RailButtonSelected":
		return _fail(m, "press did not open the panel with the selected look")
	if not shell_actions.is_empty():
		return _fail(m, "opening the panel dispatched an action: %s" % str(shell_actions))
	button.pressed.emit()
	if panels.is_sanctum_open() or button.theme_type_variation == &"RailButtonSelected":
		return _fail(m, "second press did not close the panel")
	shell.set_snapshot({ "type": "flow.summon", "meta": { "t": 2 }, "data": {}, "actions": {} })
	if not button.disabled:
		return _fail(m, "the button is usable on the Summon screen")
	return _pass(m)


static func _t_sizes() -> Dictionary:
	var rows := [FX.piece(1, "gear", "g1", 0, "A")]
	var m := _panels(FX.sanctum_snap(FX.inventory(20, 4, rows, [])))
	var panels: Node = m[1]
	var sg := panels.get_node("%SanctGrid") as GridContainer
	var pg := panels.get_node("%PackGrid") as GridContainer
	if sg.get_child_count() != 20 or pg.get_child_count() != 4 or sg.columns != 5:
		return _fail(m, "20/4: sanctum %d slots, pack %d, columns %d" % [sg.get_child_count(), pg.get_child_count(), sg.columns])
	panels.set_snapshot(FX.sanctum_snap(FX.inventory(30, 6, rows, [])))
	if sg.get_child_count() != 30 or pg.get_child_count() != 6 or sg.columns != 6:
		return _fail(m, "30/6: sanctum %d slots, pack %d, columns %d" % [sg.get_child_count(), pg.get_child_count(), sg.columns])
	panels.set_snapshot(FX.sanctum_snap(FX.inventory(8, 2, rows, [])))
	if sg.get_child_count() != 8 or pg.get_child_count() != 2:
		return _fail(m, "8/2: sanctum %d slots, pack %d" % [sg.get_child_count(), pg.get_child_count()])
	var past := [FX.piece(22, "gear", "g1", 0, "Past the size")]
	panels.set_snapshot(FX.sanctum_snap(FX.inventory(20, 4, past, [])))
	if sg.get_child_count() != 23:
		return _fail(m, "an entry past the size must stay visible: %d slots" % sg.get_child_count())
	return _pass(m)


static func _t_slots_and_names() -> Dictionary:
	var inv := FX.standard()
	var m := _panels(FX.sanctum_snap(inv))
	var panels: Node = m[1]
	var filled := 0
	for box in ["sanctum", "pack"]:
		var grid := "%SanctGrid" if box == "sanctum" else "%PackGrid"
		var n := (panels.get_node(grid) as GridContainer).get_child_count()
		for i in n:
			var slot := _slot(panels, grid, i)
			var row := ItemMovePlan.entry_at(inv, box, i)
			if row.is_empty():
				if slot.has_content():
					return _fail(m, "%s slot %d shows a tile but holds nothing" % [box, i])
				continue
			filled += 1
			var tile: Button = slot.tile()
			if not slot.has_content() or str(tile.row.get("name", "")) != str(row["name"]) or tile.tooltip_text != str(row["name"]):
				return _fail(m, "%s slot %d: tile name %s, row name %s" % [box, i, tile.tooltip_text, row["name"]])
			if tile.slot != i or tile.box != box:
				return _fail(m, "%s slot %d: tile thinks it is %s %d" % [box, i, tile.box, tile.slot])
	if filled != 9:
		return _fail(m, "expected 9 entries in slots, got %d" % filled)
	# A row without a name shows the kind word, never its type id.
	var nameless := FX.piece(0, "relic", "g1", 0, "", "ph_secret_type_id")
	panels.set_snapshot(FX.sanctum_snap(FX.inventory(20, 4, [nameless], [])))
	var tile0: Button = _slot(panels, "%SanctGrid", 0).tile()
	if tile0.display_name() != ItemUiText.KIND_NAMES["relic"] or tile0.tooltip_text.contains("ph_"):
		return _fail(m, "a nameless row shows %s" % tile0.tooltip_text)
	return _pass(m)


static func _t_no_ids() -> Dictionary:
	var inv := FX.standard()
	var m := _panels(FX.sanctum_snap(inv))
	var panels: Node = m[1]
	panels.toggle_sanctum()
	panels.toggle_pack()
	for entry in [["sanctum", 0], ["sanctum", 3], ["pack", 0], ["pack", 2]]:
		panels._on_slot_chosen(entry[0], entry[1])
		for t in _texts(panels):
			var text := str(t)
			if text.contains("ph_") or text.contains("it.1") or text.contains("type_id"):
				return _fail(m, "an id reached the screen: %s (selected %s)" % [text, str(entry)])
	return _pass(m)


static func _t_tile_states() -> Dictionary:
	var m := _mount(TileScene)
	var tile: Button = m[1]
	var piece := FX.piece(2, "gear", "g3", 4, "Test gear")
	tile.setup(piece, { "box": "sanctum", "bed": 72 })
	var g: Control = tile.get_node("%Glyphs")
	if g.kind != "gear" or g.pips != 3 or g.mark != 4 or g.leaf != "" or g.is_stack:
		return _fail(m, "sanctum piece glyphs: kind=%s pips=%d mark=%d leaf=%s" % [g.kind, g.pips, g.mark, g.leaf])
	if tile.get_node("%Bed").theme_type_variation != &"ItemBed":
		return _fail(m, "a Sanctum tile must use the plain bed")
	tile.setup(piece, { "box": "pack", "bed": 72 })
	if g.leaf != "held" or tile.get_node("%Bed").theme_type_variation != &"ItemBedHeavy":
		return _fail(m, "a carried tile needs the leaf and the darker bed: leaf=%s" % g.leaf)
	tile.setup(piece, { "box": "pack", "bed": 72, "source": "gathered" })
	if g.leaf != "gathered":
		return _fail(m, "a find of this path shows the whole leaf: %s" % g.leaf)
	# At most three marks: pips, notch, leaf.
	var marks := (1 if g.pips > 0 else 0) + (1 if g.mark >= 0 else 0) + (1 if g.leaf != "" else 0)
	if marks > 3:
		return _fail(m, "%d marks on one tile" % marks)
	tile.apply_state("at_risk")
	if not g.at_risk or g.leaf == "" or g.lost != 0.0:
		return _fail(m, "at risk keeps the leaf and draws brackets")
	tile.apply_state("kept")
	if g.leaf != "" or tile.get_node("%Plate").theme_type_variation != &"ItemPlateKept":
		return _fail(m, "kept drops the leaf and thickens the plate")
	tile.apply_state("lost")
	if g.lost != 1.0 or tile.get_node("%Plate").theme_type_variation != &"ItemPlateLost" or tile.get_node("%Body").position.y != -8.0:
		return _fail(m, "lost: ghost=%s plate=%s lift=%s" % [g.lost, tile.get_node("%Plate").theme_type_variation, tile.get_node("%Body").position.y])
	tile.apply_state("")
	if g.lost != 0.0 or g.at_risk or tile.get_node("%Plate").theme_type_variation != &"ItemPlate":
		return _fail(m, "the plain state did not reset the tile")
	# Kind shapes: each kind is a distinct drawn shape (the glyph holds the kind), and the pip count follows the grade.
	for kind in ["gear", "relic", "consumable", "material"]:
		tile.setup({ "kind": kind, "grade": "g1", "count": 3 }, { "box": "sanctum" })
		if g.kind != kind:
			return _fail(m, "kind %s not passed to the glyph" % kind)
	tile.setup({ "kind": "gear", "grade": "", "mark_index": 1 }, { "box": "sanctum" })
	if g.pips != 0:
		return _fail(m, "a gradeless piece shows pips")
	return _pass(m)


static func _t_stack_tile() -> Dictionary:
	var m := _mount(TileScene)
	var tile: Button = m[1]
	tile.setup(FX.stack(0, "consumable", 12, 20, "Test potion"), { "box": "sanctum" })
	var capsule := tile.get_node("%Capsule") as Control
	var edge := tile.get_node("%PlateEdge") as Control
	var g: Control = tile.get_node("%Glyphs")
	if not capsule.visible or not edge.visible or tile.get_node("%CountLabel").text != "x12":
		return _fail(m, "stack: capsule=%s edge=%s text=%s" % [capsule.visible, edge.visible, tile.get_node("%CountLabel").text])
	if g.pips != 0 or g.mark != -1:
		return _fail(m, "a stack shows pips or a notch")
	if capsule.theme_type_variation != &"ItemCapsule":
		return _fail(m, "below the limit the capsule is plain")
	tile.setup(FX.stack(0, "material", 20, 20, "Test fibre"), { "box": "sanctum" })
	if capsule.theme_type_variation != &"ItemCapsuleLimit" or not str(tile.get_node("%CountLabel").text).contains("[u]"):
		return _fail(m, "at the limit the capsule needs the gold frame and the underline")
	tile.setup(FX.piece(0, "gear", "g1", 0, "Test gear"), { "box": "sanctum" })
	if capsule.visible or edge.visible:
		return _fail(m, "a unique piece shows stack parts")
	return _pass(m)


static func _t_placeholders() -> Dictionary:
	var m := _mount(TileScene)
	var text := FileAccess.get_file_as_string("res://ui/components/ItemUiText.gd")
	var lines := text.split("\n")
	var strings := 0
	for i in lines.size():
		var line := lines[i]
		var s := line.strip_edges()
		if s.begins_with("#") or s.is_empty():
			continue
		var holds_text := s.contains(":= \"") or s.contains("return \"") or s.contains("\": \"")
		if not holds_text:
			continue
		strings += 1
		if not line.ends_with("# PLACEHOLDER"):
			return _fail(m, "ItemUiText.gd line %d holds wording without `# PLACEHOLDER`: %s" % [i + 1, s])
	if strings < 60:
		return _fail(m, "the scan found only %d string lines" % strings)
	# Words live in ItemUiText.gd. The new scenes hold only glyphs and a default count.
	var allowed := ["×", "−", "+", "x1"]
	for path in ["res://ui/components/ItemTile.tscn", "res://ui/components/ItemSlot.tscn", "res://ui/components/InventoryPanels.tscn",
			"res://ui/components/PartyPackButton.tscn", "res://ui/components/ItemResultRow.tscn", "res://ui/overlays/ItemDiscardModal.tscn"]:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("text = \"") and not allowed.has(line.trim_prefix("text = \"").trim_suffix("\"")):
				return _fail(m, "%s holds player text outside ItemUiText.gd: %s" % [path, line])
	return _pass(m)


# ── Panels ─────────────────────────────────────────────────────────────────

static func _t_open_alone() -> Dictionary:
	var m := _panels(FX.sanctum_snap(FX.standard()))
	var panels: Node = m[1]
	if panels.is_sanctum_open() or panels.is_pack_open() or panels.get_node("%Column").visible or panels.get_node("%SanctumPanel").visible:
		return _fail(m, "a panel starts open")
	panels.toggle_sanctum()
	if not panels.is_sanctum_open() or panels.is_pack_open() or panels.get_node("%PackPanel").visible:
		return _fail(m, "opening the Sanctum panel opened the pack")
	panels.toggle_sanctum()
	panels.toggle_pack()
	if panels.is_sanctum_open() or not panels.is_pack_open() or panels.get_node("%SanctumPanel").visible:
		return _fail(m, "opening the pack opened the Sanctum panel")
	panels.toggle_sanctum()
	if not (panels.is_sanctum_open() and panels.is_pack_open()):
		return _fail(m, "the player could not open both")
	panels.set_snapshot(FX.party_snap(FX.standard()))
	if panels.is_sanctum_open() or panels.is_pack_open():
		return _fail(m, "a new screen started with panels open")
	panels.set_snapshot(FX.path_snap(FX.inventory(20, 4, [], [], FX.path_data(false))))
	panels.toggle_sanctum()
	if panels.is_sanctum_open():
		return _fail(m, "the path view opened the Sanctum panel")
	panels.set_snapshot({ "type": "flow.summon", "meta": { "t": 1 }, "data": {}, "actions": {} })
	panels.toggle_pack()
	if panels.is_pack_open():
		return _fail(m, "a screen with no inventory opened the pack")
	return _pass(m)


static func _t_pack_panel() -> Dictionary:
	var m := _panels(FX.sanctum_snap(FX.full_both()))
	var panels: Node = m[1]
	panels.toggle_pack()
	for t in _texts(panels.get_node("%PackPanel")):
		var text := str(t)
		for ch in text:
			if ch >= "0" and ch <= "9":
				return _fail(m, "a count shows in the pack panel: %s" % text)
	var word := panels.get_node("%PackWord") as Label
	if not word.visible or word.text != ItemUiText.PACK_HEAVY:
		return _fail(m, "a full pack must say the consequence: %s" % word.text)
	if panels.get_node("%PackPanel").theme_type_variation != &"ItemPanelPackHeavy" or panels.get_node("%PackStrap").level != "full":
		return _fail(m, "a full pack needs the heavy tone and the solid strap line")
	for i in 4:
		if _slot(panels, "%PackGrid", i).tile().get_node("%Glyphs").leaf == "":
			return _fail(m, "carried piece %d has no leaf" % i)
	# One piece less: near full has the dashed strap and its own word, no heavy tone.
	var inv := FX.inventory(6, 4, [], [FX.piece(0, "gear", "g1", 0, "A"), FX.piece(1, "gear", "g1", 1, "B"), FX.piece(2, "gear", "g1", 2, "C")])
	panels.set_snapshot(FX.sanctum_snap(inv))
	if panels.get_node("%PackStrap").level != "near" or word.text != ItemUiText.PACK_NEAR \
			or panels.get_node("%PackPanel").theme_type_variation == &"ItemPanelPackHeavy":
		return _fail(m, "near full: strap=%s word=%s" % [panels.get_node("%PackStrap").level, word.text])
	panels.set_snapshot(FX.sanctum_snap(FX.inventory(6, 4, [], [FX.piece(0, "gear", "g1", 0, "A")])))
	if word.visible or panels.get_node("%PackStrap").level != "":
		return _fail(m, "a roomy pack shows a warning")
	# The Sanctum panel keeps its gauge and its count.
	panels.toggle_sanctum()
	panels.set_snapshot(FX.sanctum_snap(FX.full_both()))
	if panels.get_node("%SlotsLabel").text != ItemUiText.slots_word(6, 6) or not panels.get_node("%FullLabel").visible:
		return _fail(m, "the Sanctum gauge lost its count or its full word")
	return _pass(m)


static func _t_pack_button() -> Dictionary:
	var m := _mount(PackButtonScene)
	var button: Control = m[1]
	button.set_inventory(FX.standard())
	if button.get_node("%PackCountLabel").text != ItemUiText.sockets_word(2, 4):
		return _fail(m, "count text %s" % button.get_node("%PackCountLabel").text)
	if not button.get_node("%DepartLine").visible or button.get_node("%DepartLabel").text != ItemUiText.DEPART_LINE:
		return _fail(m, "the departure line must show above the button while the pack holds a piece")
	button.set_inventory(FX.inventory(20, 4, [], []))
	if button.get_node("%DepartLine").visible:
		return _fail(m, "the departure line shows with an empty pack")
	var got: Array = []
	button.toggle_requested.connect(func() -> void: got.append(true))
	button.get_node("%PackButton").pressed.emit()
	if got.size() != 1:
		return _fail(m, "the button did not report a press")
	return _pass(m)


# ── Moves and drops ────────────────────────────────────────────────────────

static func _t_move_button() -> Dictionary:
	var m := _panels(FX.sanctum_snap(FX.standard()))
	var panels: Node = m[1]
	var got := _capture(panels, "action_requested")
	panels.toggle_sanctum()
	panels.toggle_pack()
	panels._on_slot_chosen("sanctum", 4)
	var move := panels.get_node("%MoveButton") as Button
	if move.text != ItemUiText.BTN_MOVE_PACK:
		return _fail(m, "move button text %s" % move.text)
	move.pressed.emit()
	var want := { "type": "inventory.move.apply", "payload": { "from": "sanctum", "slot": 4, "to": "pack", "to_slot": -1 } }
	if got.size() != 1 or got[0] != want:
		return _fail(m, "action %s, wanted %s" % [str(got), str(want)])
	if str(got[0].get("slot", "")) != "":
		return _fail(m, "a per-row action must not claim a snapshot slot")
	panels.set_snapshot(FX.sanctum_snap(FX.standard()))
	panels._on_slot_chosen("pack", 0)
	got.clear()
	if (panels.get_node("%MoveButton") as Button).text != ItemUiText.BTN_MOVE_SANCT:
		return _fail(m, "a carried piece offers the move to the Sanctum")
	panels.get_node("%MoveButton").pressed.emit()
	want = { "type": "inventory.move.apply", "payload": { "from": "pack", "slot": 0, "to": "sanctum", "to_slot": -1 } }
	if got.size() != 1 or got[0] != want:
		return _fail(m, "action %s, wanted %s" % [str(got), str(want)])
	return _pass(m)


static func _t_drops() -> Dictionary:
	var m := _panels(FX.sanctum_snap(FX.standard()))
	var panels: Node = m[1]
	panels.toggle_sanctum()
	panels.toggle_pack()
	var got := _capture(panels, "action_requested")
	# Reorder: an empty slot of the same container. Sanctum slot 2 is empty.
	var slot2 := _slot(panels, "%SanctGrid", 2)
	if not slot2._can_drop_data(Vector2.ZERO, _drag("sanctum", 0)):
		return _fail(m, "an empty slot refused a reorder")
	slot2._drop_data(Vector2.ZERO, _drag("sanctum", 0))
	var want := { "type": "inventory.move.apply", "payload": { "from": "sanctum", "slot": 0, "to": "sanctum", "to_slot": 2 } }
	if got.size() != 1 or got[0] != want:
		return _fail(m, "reorder: %s" % str(got))
	panels.set_snapshot(FX.sanctum_snap(FX.standard()))
	got.clear()
	# Merge: potion stack at slot 12 (6) dropped on potion stack at slot 3 (12 of 20).
	var slot3 := _slot(panels, "%SanctGrid", 3)
	slot3._drop_data(Vector2.ZERO, _drag("sanctum", 12))
	want = { "type": "inventory.move.apply", "payload": { "from": "sanctum", "slot": 12, "to": "sanctum", "to_slot": 3 } }
	if got.size() != 1 or got[0] != want:
		return _fail(m, "merge: %s" % str(got))
	panels.set_snapshot(FX.sanctum_snap(FX.standard()))
	got.clear()
	# Across containers: a carried piece to an empty Sanctum slot, and a Sanctum piece to the pack panel (first free slot).
	_slot(panels, "%SanctGrid", 5)._drop_data(Vector2.ZERO, _drag("pack", 0))
	want = { "type": "inventory.move.apply", "payload": { "from": "pack", "slot": 0, "to": "sanctum", "to_slot": 5 } }
	if got.size() != 1 or got[0] != want:
		return _fail(m, "cross to a slot: %s" % str(got))
	panels.set_snapshot(FX.sanctum_snap(FX.standard()))
	got.clear()
	panels.get_node("%PackPanel")._drop_data(Vector2.ZERO, _drag("sanctum", 1))
	want = { "type": "inventory.move.apply", "payload": { "from": "sanctum", "slot": 1, "to": "pack", "to_slot": -1 } }
	if got.size() != 1 or got[0] != want:
		return _fail(m, "cross to the panel: %s" % str(got))
	return _pass(m)


static func _t_refused_drops() -> Dictionary:
	var m := _panels(FX.sanctum_snap(FX.standard()))
	var panels: Node = m[1]
	panels.toggle_sanctum()
	panels.toggle_pack()
	var got := _capture(panels, "action_requested")
	var line := panels.get_node("%SanctRefuseLabel") as Label
	# No swap onto an occupied slot.
	var slot1 := _slot(panels, "%SanctGrid", 1)
	slot1._drop_data(Vector2.ZERO, _drag("sanctum", 0))
	if not got.is_empty() or line.text != ItemUiText.R_OCCUPIED or not panels.get_node("%SanctRefuse").visible:
		return _fail(m, "occupied slot: sent %s, line '%s'" % [str(got), line.text])
	# Two different stack types do not merge.
	slot1._drop_data(Vector2.ZERO, _drag("sanctum", 3))
	_slot(panels, "%SanctGrid", 7)._drop_data(Vector2.ZERO, _drag("sanctum", 3))
	if not got.is_empty() or line.text != ItemUiText.R_TYPE:
		return _fail(m, "type mismatch: sent %s, line '%s'" % [str(got), line.text])
	# A stack at its limit takes no more.
	_slot(panels, "%SanctGrid", 7)._drop_data(Vector2.ZERO, _drag("sanctum", 12))
	if not got.is_empty() or line.text != ItemUiText.R_TYPE:
		return _fail(m, "different stack onto a limit stack: '%s'" % line.text)
	# Full containers.
	panels.set_snapshot(FX.sanctum_snap(FX.full_both()))
	panels._on_panel_drop(_drag("sanctum", 0), "pack")
	if not got.is_empty() or panels.get_node("%PackRefuseLabel").text != ItemUiText.R_PACK_FULL:
		return _fail(m, "full pack: sent %s, line '%s'" % [str(got), panels.get_node("%PackRefuseLabel").text])
	panels._on_panel_drop(_drag("pack", 0), "sanctum")
	if not got.is_empty() or line.text != ItemUiText.R_SANCT_FULL:
		return _fail(m, "full Sanctum: sent %s, line '%s'" % [str(got), line.text])
	# Dropping a piece on its own slot is nothing at all.
	var own := _slot(panels, "%SanctGrid", 0)
	if own._can_drop_data(Vector2.ZERO, _drag("sanctum", 0)):
		return _fail(m, "a piece accepts a drop on its own slot")
	return _pass(m)


static func _t_reason_keys() -> Dictionary:
	var m := _mount(TileScene)
	var plain := { "path_open": ItemUiText.R_PATH, "path_used": ItemUiText.R_DISCARD_USED, "not_in_pack": ItemUiText.R_NOT_IN_PACK,
		"slot_taken": ItemUiText.R_OCCUPIED, "type_mismatch": ItemUiText.R_TYPE, "stack_limit": ItemUiText.R_STACK_LIMIT,
		"equipped": ItemUiText.R_EQUIPPED, "not_in_sanctum": ItemUiText.R_SANCTUM_ONLY }
	for key in plain:
		if ItemUiText.reason_text(key) != plain[key] or ItemUiText.reason_text(key) == ItemUiText.R_UNKNOWN:
			return _fail(m, "reason %s maps to '%s'" % [key, ItemUiText.reason_text(key)])
	if ItemUiText.reason_text("container_full", "pack") != ItemUiText.R_PACK_FULL \
			or ItemUiText.reason_text("container_full", "sanctum") != ItemUiText.R_SANCT_FULL:
		return _fail(m, "container_full must name the full container")
	for key in ["unknown_entry", "bad_slot", "bad_box", "bad_state", "bad_payload", "count_range", "no_change", "zzz", ""]:
		if ItemUiText.reason_text(key) != ItemUiText.R_UNKNOWN:
			return _fail(m, "unmapped key %s did not use the generic line" % key)
	return _pass(m)


static func _t_unchanged_after_move() -> Dictionary:
	var m := _panels(FX.sanctum_snap(FX.standard()))
	var panels: Node = m[1]
	panels.toggle_sanctum()
	var got := _capture(panels, "action_requested")
	panels._on_slot_chosen("sanctum", 0)
	panels.get_node("%MoveButton").pressed.emit()
	if got.size() != 1:
		return _fail(m, "no move was sent")
	# The core refused: the same snapshot comes back.
	panels.set_snapshot(FX.sanctum_snap(FX.standard()))
	if panels.get_node("%SanctRefuseLabel").text != ItemUiText.R_UNKNOWN:
		return _fail(m, "an unchanged snapshot after a move shows '%s'" % panels.get_node("%SanctRefuseLabel").text)
	# A changed snapshot shows nothing.
	panels.get_node("%SanctRefuse").visible = false
	panels._on_slot_chosen("sanctum", 0)
	panels.get_node("%MoveButton").pressed.emit()
	var moved := FX.standard()
	(moved["items"] as Array)[0]["slot"] = 9
	panels.set_snapshot(FX.sanctum_snap(moved))
	if panels.get_node("%SanctRefuse").visible:
		return _fail(m, "a changed snapshot showed a refusal")
	return _pass(m)


static func _t_move_plan() -> Dictionary:
	var m := _mount(TileScene)
	var inv := FX.standard()
	var cases := [
		["sanctum", 0, "sanctum", 0, "none", ""],
		["sanctum", 0, "sanctum", 2, "reorder", ""],
		["sanctum", 0, "sanctum", 1, "refuse", "slot_taken"],
		["sanctum", 12, "sanctum", 3, "merge", ""],
		["sanctum", 3, "sanctum", 7, "refuse", "type_mismatch"],
		["sanctum", 3, "sanctum", 4, "refuse", "slot_taken"],
		["sanctum", 7, "sanctum", 3, "refuse", "type_mismatch"],
		["sanctum", 0, "pack", -1, "place", ""],
		["sanctum", 0, "pack", 1, "place", ""],
		["sanctum", 0, "pack", 99, "refuse", "bad_slot"],
		["pack", 2, "sanctum", 3, "merge", ""],
		["pack", 2, "sanctum", 7, "refuse", "type_mismatch"],
		["pack", 0, "sanctum", -1, "place", ""],
		["pack", 7, "sanctum", -1, "refuse", "unknown_entry"],
	]
	for c in cases:
		var p := ItemMovePlan.plan(inv, c[0], c[1], c[2], c[3])
		if str(p["kind"]) != c[4] or str(p["reason"]) != c[5]:
			return _fail(m, "plan %s -> %s %s: got %s %s" % [str(c.slice(0, 4)), c[4], c[5], p["kind"], p["reason"]])
	# The first free slot is the lowest one below the size.
	if ItemMovePlan.free_slot(inv, "sanctum") != 2 or ItemMovePlan.free_slot(inv, "pack") != 1:
		return _fail(m, "free slots %d / %d" % [ItemMovePlan.free_slot(inv, "sanctum"), ItemMovePlan.free_slot(inv, "pack")])
	var full := FX.full_both()
	if ItemMovePlan.plan(full, "sanctum", 0, "pack", -1)["reason"] != "container_full" \
			or ItemMovePlan.plan(full, "pack", 0, "sanctum", -1)["reason"] != "container_full":
		return _fail(m, "a full container must refuse a place")
	# A merge needs no free slot.
	var stacks := FX.inventory(2, 1, [FX.stack(0, "consumable", 5, 20, "P", "t"), FX.stack(1, "consumable", 5, 20, "P", "t")], [FX.stack(0, "consumable", 4, 20, "P", "t")])
	if ItemMovePlan.plan(stacks, "pack", 0, "sanctum", 0)["kind"] != "merge":
		return _fail(m, "a merge into a full container was refused")
	var limit := FX.inventory(2, 1, [FX.stack(0, "consumable", 20, 20, "P", "t")], [FX.stack(0, "consumable", 4, 20, "P", "t")])
	if ItemMovePlan.plan(limit, "pack", 0, "sanctum", 0)["reason"] != "stack_limit":
		return _fail(m, "a merge into a stack at its limit was not refused with stack_limit")
	var path := FX.inventory(20, 4, [FX.piece(0, "gear", "g1", 0, "A")], [], FX.path_data(false))
	if ItemMovePlan.plan(path, "sanctum", 0, "pack", -1)["reason"] != "path_open":
		return _fail(m, "a move on a path must be refused with path_open")
	return _pass(m)


# ── Path view and the discard ──────────────────────────────────────────────

static func _t_path_view() -> Dictionary:
	var pack := [FX.piece(0, "gear", "g2", 3, "Test gear G"), FX.piece(1, "relic", "g3", 0, "Test relic H")]
	var m := _panels(FX.path_snap(FX.inventory(20, 4, [], pack, FX.path_data(false))))
	var panels: Node = m[1]
	var actions := _capture(panels, "action_requested")
	var modals: Array = []
	panels.modal_requested.connect(func(id: StringName, payload: Dictionary) -> void: modals.append([id, payload]))
	panels.toggle_pack()
	if not panels.is_pack_open() or panels.get_node("%PathBar").visible == false:
		return _fail(m, "the path pack panel did not open with its path bar")
	if panels.get_node("%PathToken").text != ItemUiText.PATH_LEFT:
		return _fail(m, "token '%s'" % panels.get_node("%PathToken").text)
	for i in 4:
		if _slot(panels, "%PackGrid", i).tile().drag_enabled:
			return _fail(m, "a path tile can be dragged")
	panels._on_slot_chosen("pack", 0)
	var move := panels.get_node("%MoveButton") as Button
	move.pressed.emit()
	if not actions.is_empty() or panels.get_node("%PackRefuseLabel").text != ItemUiText.R_PATH:
		return _fail(m, "a move on a path: sent %s, line '%s'" % [str(actions), panels.get_node("%PackRefuseLabel").text])
	if not panels.get_node("%MoveReason").visible:
		return _fail(m, "the blocked move shows no reason in the details")
	var plan: Dictionary = panels._plan_for_drag(_drag("pack", 0), "pack", 1)
	if plan["kind"] != "refuse" or plan["reason"] != "path_open":
		return _fail(m, "a drag on a path is not refused")
	# The one discard.
	panels.get_node("%LetGoButton").pressed.emit()
	if modals.size() != 1 or modals[0][0] != &"inventory.discard" or not bool(modals[0][1]["path"]) or modals[0][1]["box"] != "pack" or modals[0][1]["slot"] != 0:
		return _fail(m, "let it go on a path: %s" % str(modals))
	if not actions.is_empty():
		return _fail(m, "let it go dispatched before the confirmation")
	panels.set_snapshot(FX.path_snap(FX.inventory(20, 4, [], pack, FX.path_data(true))))
	modals.clear()
	panels.note_discard_modal_closed()
	panels._letgo_lock_until = 0
	panels.get_node("%LetGoButton").pressed.emit()
	if not modals.is_empty() or not panels.get_node("%LetGoReason").visible \
			or not panels.get_node("%LetGoReason").text.contains(ItemUiText.R_DISCARD_USED) \
			or panels.get_node("%PathToken").text != ItemUiText.PATH_USED:
		return _fail(m, "a used discard: modals %s, reason '%s'" % [str(modals), panels.get_node("%LetGoReason").text])
	# A Sanctum piece cannot be let go on a path.
	if ItemMovePlan.discard_block(FX.inventory(20, 4, [], [], FX.path_data(false)), "sanctum") != "not_in_pack":
		return _fail(m, "a Sanctum piece may be let go on a path")
	return _pass(m)


static func _t_discard_modal() -> Dictionary:
	var m := _mount(ModalScene)
	var modal: Control = m[1]
	var actions := _capture(modal, "action_requested")
	var dismissed: Array = []
	modal.dismiss_requested.connect(func() -> void: dismissed.append(true))
	var piece := FX.piece(3, "gear", "g2", 1, "Test gear")
	modal.present({ "row": piece, "box": "pack", "slot": 3, "stack": false, "count_max": 1, "path": true })
	if not modal.get_node("%KeepButton").has_focus():
		return _fail(m, "the default focus is not Keep it")
	if modal.get_node("%Picker").visible or not modal.get_node("%PathLabel").visible:
		return _fail(m, "a piece needs no picker; a path discard says it is the one")
	modal.get_node("%LetGoButton").pressed.emit()
	if not actions.is_empty() or modal.is_armed():
		return _fail(m, "Let it go worked inside the 0.25 s window")
	modal.set("_armed", true)
	modal.get_node("%LetGoButton").pressed.emit()
	modal.get_node("%LetGoButton").pressed.emit()
	var want := { "type": "inventory.discard.apply", "payload": { "from": "pack", "slot": 3 } }
	if actions.size() != 1 or actions[0] != want or dismissed.size() != 1:
		return _fail(m, "confirm sent %s (dismissed %d), wanted one %s" % [str(actions), dismissed.size(), str(want)])
	# A stack asks how many: default the whole stack, minimum 1.
	var stack := FX.stack(5, "consumable", 12, 20, "Test potion")
	modal.present({ "row": stack, "box": "sanctum", "slot": 5, "stack": true, "count_max": 12, "path": false })
	actions.clear()
	if not modal.get_node("%Picker").visible or modal.count() != 12 or modal.get_node("%PathLabel").visible:
		return _fail(m, "stack picker: visible=%s count=%d" % [modal.get_node("%Picker").visible, modal.count()])
	modal.get_node("%PlusButton").pressed.emit()
	if modal.count() != 12:
		return _fail(m, "plus went past the stack: %d" % modal.count())
	for i in 14:
		modal.get_node("%MinusButton").pressed.emit()
	if modal.count() != 1:
		return _fail(m, "minus went below 1: %d" % modal.count())
	modal.get_node("%PlusButton").pressed.emit()
	modal.set("_armed", true)
	modal.get_node("%LetGoButton").pressed.emit()
	want = { "type": "inventory.discard.apply", "payload": { "from": "sanctum", "slot": 5, "count": 2 } }
	if actions.size() != 1 or actions[0] != want:
		return _fail(m, "stack confirm sent %s, wanted %s" % [str(actions), str(want)])
	# Esc, Back and a tap outside all mean Keep it: no action, one dismissal each.
	dismissed.clear()
	actions.clear()
	modal.present({ "row": piece, "box": "pack", "slot": 3, "stack": false, "count_max": 1, "path": false })
	modal.set("_armed", true)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	modal._input(esc)
	modal.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	modal.get_node("%Outside").pressed.emit()
	modal.get_node("%KeepButton").pressed.emit()
	if not actions.is_empty() or dismissed.size() != 4:
		return _fail(m, "keep paths: actions %s, dismissals %d" % [str(actions), dismissed.size()])
	return _pass(m)


static func _t_discard_shells() -> Dictionary:
	var m := _mount(SanctumShellScene)
	var shell: Control = m[1]
	shell.set_snapshot(FX.sanctum_snap(FX.standard()))
	var modals: Array = []
	shell.modal_requested.connect(func(id: StringName, payload: Dictionary) -> void: modals.append([id, payload]))
	var panels := shell.get_node("%InventoryPanels")
	panels.toggle_sanctum()
	panels._on_slot_chosen("sanctum", 0)
	panels.get_node("%LetGoButton").pressed.emit()
	if modals.size() != 1 or modals[0][0] != &"inventory.discard" or not modals[0][1].has("layout"):
		return _fail(m, "Sanctum shell modal request: %s" % str(modals))
	if shell.modal_scene_for(&"inventory.discard") == null:
		return _fail(m, "the Sanctum shell has no scene for the discard modal")
	var realm_m := _mount(RealmShellScene)
	var realm: Control = realm_m[1]
	var scene_ok: bool = realm.modal_scene_for(&"inventory.discard") != null
	var path_snap := FX.path_snap(FX.inventory(20, 4, [], [FX.piece(0, "gear", "g1", 0, "A")], FX.path_data(false)))
	realm.set_snapshot(path_snap)
	var realm_modals: Array = []
	realm.modal_requested.connect(func(id: StringName, payload: Dictionary) -> void: realm_modals.append(id))
	var realm_actions := _capture(realm, "action_requested")
	var realm_panels := realm.get_node("%InventoryPanels")
	# The pack toggle from the HUD button is UI-local: it opens the panel and dispatches nothing.
	realm._on_overlay_action_requested({ "type": "ui.toggle_pack_panel" })
	if not realm_panels.is_pack_open() or not realm_actions.is_empty():
		realm_m[0].free()
		return _fail(m, "the path HUD button must only open the pack panel (open=%s, actions %s)" % [realm_panels.is_pack_open(), str(realm_actions)])
	realm_panels._on_slot_chosen("pack", 0)
	realm_panels.get_node("%LetGoButton").pressed.emit()
	realm_m[0].free()
	if not scene_ok or realm_modals != [&"inventory.discard"]:
		return _fail(m, "Realm shell: scene=%s modals=%s" % [scene_ok, str(realm_modals)])
	return _pass(m)


static func _t_party_shell() -> Dictionary:
	var m := _mount(SanctumShellScene)
	var shell: Control = m[1]
	var shell_actions := _capture(shell, "action_requested")
	shell.set_snapshot(FX.party_snap(FX.standard()))
	var panels := shell.get_node("%InventoryPanels")
	var overlay := shell.get("_active_overlay") as Control
	if overlay == null or overlay.get_node("%PartyPackButton").get_node("%PackCountLabel").text != ItemUiText.sockets_word(2, 4):
		return _fail(m, "party details show no pack count")
	if panels.is_pack_open():
		return _fail(m, "party prep starts with the pack open")
	overlay.get_node("%PartyPackButton").toggle_requested.emit()
	if not panels.is_pack_open() or not shell_actions.is_empty():
		return _fail(m, "the party pack button must open the pack and dispatch nothing: open=%s actions=%s" % [panels.is_pack_open(), str(shell_actions)])
	if panels.right_inset() <= 0 or not overlay.get_node("%PartyPackButton").is_open():
		return _fail(m, "the pack must open to the right of party details (inset %d)" % panels.right_inset())
	if panels.get_node("%SanctumPanel").visible:
		return _fail(m, "opening the pack opened the Sanctum panel")
	overlay.get_node("%PartyPackButton").toggle_requested.emit()
	if panels.is_pack_open() or panels.right_inset() != 0:
		return _fail(m, "the pack did not close")
	return _pass(m)


# ── Result cards and the leave confirmation ────────────────────────────────

static func _t_result_row() -> Dictionary:
	var m := _mount(preload("res://ui/components/ItemResultRow.tscn"))
	var row: Control = m[1]
	var block := FX.items_block()
	row.show_report(block["kept"], block["lost"], false)
	if row.tile_count() != 5 or row.fates() != ["kept", "kept", "lost", "lost", "lost"]:
		return _fail(m, "row fates %s" % str(row.fates()))
	var labels := _label_texts(row)
	for t in labels:
		if str(t) != "":
			return _fail(m, "a result row holds text before any focus: '%s'" % str(t))
	if row.get_node("%Tiles").get_child_count() != 5 or not row.visible:
		return _fail(m, "the tiles are not in one row")
	# A stack with a lost part adds a ghost tile beside the survivor.
	var kept := [FX.report_row("consumable", "", -1, "gathered", "overflow", 3, "Test potion")]
	kept[0]["lost_quantity"] = 5
	row.show_report(kept, [])
	if row.fates() != ["kept", "lost"] or row.tiles()[1].stack_count_of(row.tiles()[1].row) != 5:
		return _fail(m, "the stack surplus ghost: %s" % str(row.fates()))
	# Names show on focus or tap, never a place.
	row.show_report(block["kept"], block["lost"], false)
	row.tiles()[2].pressed.emit()
	var shown: String = row.get_node("%NameLine").text
	if not shown.contains("Test relic B") or not shown.contains(ItemUiText.CARD_LOST):
		return _fail(m, "name line '%s'" % shown)
	for tile in row.tiles():
		tile.pressed.emit()
		for word in PLACE_WORDS:
			if row.get_node("%NameLine").text.contains(word):
				return _fail(m, "the name line holds the place word '%s': %s" % [word, row.get_node("%NameLine").text])
	# A row without a name falls back to the kind word.
	row.show_report([FX.report_row("gear", "g1", 2, "held", "ok")], [])
	row.tiles()[0].pressed.emit()
	if not row.get_node("%NameLine").text.begins_with(ItemUiText.KIND_NAMES["gear"]) or row.get_node("%NameLine").text.contains("ph_"):
		return _fail(m, "a nameless report row shows '%s'" % row.get_node("%NameLine").text)
	# Preview tag only for the stage-clear card. Empty report: no row.
	row.show_report(block["kept"], [], true)
	if not row.get_node("%PreviewTag").visible:
		return _fail(m, "the preview mark is missing")
	row.show_report([], [])
	if row.visible:
		return _fail(m, "an empty report shows a row")
	return _pass(m)


static func _t_row_motion() -> Dictionary:
	var before := _set_reduced(false)
	var m := _mount(preload("res://ui/components/ItemResultRow.tscn"))
	var row: Control = m[1]
	var block := FX.items_block()
	row.show_report(block["kept"], block["lost"], false)
	# The cap: 1 to 14 tiles never run longer than 2.4 s.
	for n in range(1, 15):
		var p := ItemResultRow.plan(n, false)
		if float(p["total"]) > ItemResultRow.SEQ_CAP + 0.0001:
			_set_reduced(before)
			return _fail(m, "%d tiles take %.2f s" % [n, p["total"]])
	var p5 := ItemResultRow.plan(5, false)
	if absf(float(p5["st"]) - 0.15) > 0.0001 or absf(float(p5["t0"]) - 0.55) > 0.0001 or absf(float(p5["d"]) - 0.5) > 0.0001:
		_set_reduced(before)
		return _fail(m, "5 tiles: %s" % str(p5))
	row.play()
	if not row.is_running():
		_set_reduced(before)
		return _fail(m, "play() did not start")
	if row.tiles()[2].state == "lost" or row.tiles()[2].modulate.a != 0.0:
		_set_reduced(before)
		return _fail(m, "a lost tile starts as a plain, hidden tile")
	# First tap finishes the motion; the Continue press of the same tap is absorbed.
	if not row.absorb_continue() or row.is_running():
		_set_reduced(before)
		return _fail(m, "the first press did not finish the motion and get absorbed")
	if row.fates() != ["kept", "kept", "lost", "lost", "lost"] or row.tiles()[2].state != "lost" or row.tiles()[0].state != "kept":
		_set_reduced(before)
		return _fail(m, "final states %s" % str([row.tiles()[0].state, row.tiles()[2].state]))
	if row.tiles()[2].get_node("%Body").position.y != -8.0 or row.tiles()[2].modulate.a != 1.0:
		_set_reduced(before)
		return _fail(m, "a lost tile must end lifted by 8 and visible")
	if not row.absorb_continue():
		_set_reduced(before)
		return _fail(m, "Continue is not guarded for 0.25 s after the final state")
	row.set("_final_msec", Time.get_ticks_msec() - 260)
	if row.absorb_continue():
		_set_reduced(before)
		return _fail(m, "Continue is still guarded after 0.25 s")
	row.show_report([], [])
	if row.absorb_continue():
		_set_reduced(before)
		return _fail(m, "an empty row guards Continue")
	_set_reduced(before)
	return _pass(m)


static func _t_reduced_motion() -> Dictionary:
	var before := _set_reduced(true)
	var m := _mount(preload("res://ui/components/ItemResultRow.tscn"))
	var row: Control = m[1]
	var p := ItemResultRow.plan(5, true)
	if absf(float(p["d"]) - 0.15) > 0.0001 or float(p["total"]) > ItemResultRow.SEQ_CAP:
		_set_reduced(before)
		return _fail(m, "reduced plan %s" % str(p))
	var block := FX.items_block()
	row.show_report(block["kept"], block["lost"], false)
	row.play()
	if not row.is_running():
		_set_reduced(before)
		return _fail(m, "reduced motion did not run")
	row._play_tile(2, true)
	var tile: Button = row.tiles()[2]
	row.finish()
	if tile.get_node("%Body").position.y != -8.0 or tile.state != "lost":
		_set_reduced(before)
		return _fail(m, "reduced motion changed the final state")
	_set_reduced(before)
	return _pass(m)


static func _scout_snap(items: Dictionary) -> Dictionary:
	var data := { "victory": false, "reason": "", "rank": "F", "ase_awarded": 0, "ekwan_awarded": 0, "enemies_defeated": 0,
		"echoes_survived": 0, "round_ended": 1, "reward_breakdown": [], "emotion_summary": [], "run_type": "scout_return",
		"intel_count": 1, "settle_outcome": "some", "actors": [] }
	if not items.is_empty():
		data["items"] = items
	return { "type": "flow.resolve", "meta": { "t": 2 }, "data": data,
		"actions": { "cta.continue": { "type": "flow.go_state", "slot": "cta.continue", "label": "To Sanctum" } } }


static func _t_resolve_cards() -> Dictionary:
	var before := _set_reduced(false)
	var m := _mount(ResolveScene)
	var screen: ResolveScreen = m[1]
	var actions := _capture(screen, "action_requested")
	var row := screen.get_node("%ItemRow")
	screen.set_snapshot(_scout_snap({}))
	if row.visible:
		_set_reduced(before)
		return _fail(m, "a card without items shows an item row")
	# Leave result: one row, five tiles, motion running.
	screen.set_snapshot(_scout_snap(FX.items_block()))
	if not row.visible or row.tile_count() != 5 or row.fates() != ["kept", "kept", "lost", "lost", "lost"]:
		_set_reduced(before)
		return _fail(m, "leave card row: visible=%s fates=%s" % [row.visible, str(row.fates())])
	if row.get_node("%PreviewTag").visible:
		_set_reduced(before)
		return _fail(m, "a leave card is not a preview")
	if not row.is_running():
		_set_reduced(before)
		return _fail(m, "the item motion did not start")
	# The first tap finishes the motion; the second continues.
	screen.get_node("%SanctumButton").pressed.emit()
	if not actions.is_empty() or row.is_running():
		_set_reduced(before)
		return _fail(m, "first press: actions %s running=%s" % [str(actions), row.is_running()])
	screen.get_node("%SanctumButton").pressed.emit()
	if not actions.is_empty():
		_set_reduced(before)
		return _fail(m, "Continue worked inside its 0.25 s guard")
	row.set("_final_msec", Time.get_ticks_msec() - 300)
	screen.get_node("%SanctumButton").pressed.emit()
	if actions.size() != 1 or str(actions[0].get("type", "")) != "flow.go_state":
		_set_reduced(before)
		return _fail(m, "the second press did not continue: %s" % str(actions))
	# Same snapshot again: no replay of the motion.
	screen.set_snapshot(_scout_snap(FX.items_block()))
	screen.set_snapshot(_scout_snap(FX.items_block()))
	if row.is_running():
		_set_reduced(before)
		return _fail(m, "the same result replayed its motion")
	# Defeat: the lost items of the packs_lost row, no survivors.
	var lost: Array = []
	for r in FX.items_block()["lost"]:
		var copy: Dictionary = (r as Dictionary).duplicate()
		copy["reason_key"] = "defeat"
		lost.append(copy)
	var defeat := { "type": "flow.resolve", "meta": { "t": 3 }, "actions": {},
		"data": { "victory": false, "reason": "all_echoes_dead", "rank": "F", "ase_awarded": 0, "ekwan_awarded": 0, "enemies_defeated": 0,
			"echoes_survived": 0, "round_ended": 2, "emotion_summary": [],
			"reward_breakdown": [{ "label": "Packs lost", "delta": 0, "currency": "ase", "cause": "packs_lost",
				"params": { "lost_ase": 0, "lost_ekwan": 0, "items": lost } }] } }
	screen.set_snapshot(defeat)
	if row.tile_count() != 3 or row.fates() != ["lost", "lost", "lost"]:
		_set_reduced(before)
		return _fail(m, "defeat row fates %s" % str(row.fates()))
	# Stage clear: the same row with the read-only mark.
	var clear := _scout_snap(FX.items_block())
	(clear["data"] as Dictionary).erase("run_type")
	(clear["data"] as Dictionary)["victory"] = true
	(clear["data"] as Dictionary)["stage_payout_rows"] = []
	screen.set_snapshot(clear)
	if row.tile_count() != 5 or not row.get_node("%PreviewTag").visible or row.get_node("%PreviewTag").text != ItemUiText.CARD_PREVIEW:
		_set_reduced(before)
		return _fail(m, "stage clear row: tiles=%d preview=%s" % [row.tile_count(), row.get_node("%PreviewTag").visible])
	# No place word, no lane title anywhere in the row.
	for t in _texts(row):
		for word in PLACE_WORDS:
			if str(t).contains(word):
				_set_reduced(before)
				return _fail(m, "the item row holds the place word '%s'" % word)
	_set_reduced(before)
	return _pass(m)


static func _t_leave_confirm() -> Dictionary:
	var m := _mount(ReturnModalScene)
	var modal: Control = m[1]
	var actions := _capture(modal, "action_requested")
	var at_risk := [FX.report_row("gear", "g2", 1, "held", "", 1, "Test gear A"), FX.report_row("relic", "g3", 4, "held", "", 1, "Test relic B"),
		FX.report_row("consumable", "", -1, "gathered", "", 5, "Test potion C")]
	for r in at_risk:
		r.erase("reason_key")
	var go := { "type": "stage.return_home" }
	modal.present({ "confirm": true, "action": go, "carry": { "ase": 0, "ekwan": 0, "gathered": { "ase": 0, "ekwan": 0 }, "items_at_risk": at_risk } })
	var row := modal.get_node("%ItemRow")
	if not row.visible or row.tile_count() != 3 or row.fates() != ["at_risk", "at_risk", "at_risk"]:
		return _fail(m, "at-risk row: visible=%s fates=%s" % [row.visible, str(row.fates())])
	for tile in row.tiles():
		if tile.get_node("%Glyphs").leaf == "":
			return _fail(m, "an at-risk tile lost its leaf")
	var line: String = row.get_node("%RiskLine").text
	if line != ItemUiText.leave_risk(3):
		return _fail(m, "risk line '%s'" % line)
	for word in PLACE_WORDS:
		if line.contains(word):
			return _fail(m, "the at-risk line names a place: %s" % line)
	if modal.get_node("%GatheredLabel").visible:
		return _fail(m, "'nothing is in the packs' shows while pieces are at risk")
	# Confirm waits 0.25 s while the tiles show; Stay is never delayed.
	modal.get_node("%ConfirmButton").pressed.emit()
	if not actions.is_empty():
		return _fail(m, "Confirm worked inside its 0.25 s window")
	modal.set("_armed", true)
	modal.get_node("%ConfirmButton").pressed.emit()
	modal.get_node("%ConfirmButton").pressed.emit()
	if actions.size() != 1 or actions[0] != go:
		return _fail(m, "confirm sent %s" % str(actions))
	# No pieces: the old confirmation, unchanged and immediate.
	actions.clear()
	modal.present({ "confirm": true, "action": go, "carry": { "ase": 0, "ekwan": 0, "gathered": { "ase": 0, "ekwan": 0 } } })
	if row.visible or not modal.get_node("%GatheredLabel").visible:
		return _fail(m, "an item-free confirmation changed: row=%s" % row.visible)
	modal.get_node("%ConfirmButton").pressed.emit()
	if actions.size() != 1:
		return _fail(m, "an item-free Confirm is delayed")
	return _pass(m)


# ── Source and theme guards ────────────────────────────────────────────────

static func _t_source_grep() -> Dictionary:
	var m := _mount(TileScene)
	var banned := ["FlowContext", "SaveService", "save_data", "FlowRuntime", "InventoryService", "InventoryRules", "EarningsService",
		"StageSettlementService", ".dispatch("]
	for path in NEW_UI_SCRIPTS:
		var code := ""
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var s := line.strip_edges()
			if not s.begins_with("#"):
				code += line.split(" #")[0] + "\n"
		for word in banned:
			if code.contains(word):
				return _fail(m, "%s names %s" % [path, word])
	# The shells and screens that host the new UI added no core read either.
	for path in ["res://ui/shells/SanctumShell.gd", "res://ui/shells/RealmShell.gd", "res://ui/components/ItemUiText.gd"]:
		for word in ["FlowContext", "SaveService", "save_data"]:
			for line in FileAccess.get_file_as_string(path).split("\n"):
				var s := line.strip_edges()
				if not s.begins_with("#") and s.contains(word):
					return _fail(m, "%s code names %s: %s" % [path, word, s])
	# No UI file builds the item hierarchy in code.
	for path in NEW_UI_SCRIPTS:
		var text := FileAccess.get_file_as_string(path)
		if text.contains(".new()") or text.contains("StyleBoxFlat"):
			return _fail(m, "%s builds nodes or styles in code" % path)
	return _pass(m)


static func _t_theme_colours() -> Dictionary:
	var m := _mount(TileScene)
	var text := FileAccess.get_file_as_string("res://assets/theme/LivingTreeSystem.tres")
	var forbidden := { "soft blue": Color("#7AB5C8"), "terracotta": Color("#C85A54"), "forest": Color("#2D6A4F"), "success green": Color("#4CAF72"),
		"weary tan": Color("#8B7355") }
	var re := RegEx.new()
	re.compile("Color\\(([0-9.]+), ([0-9.]+), ([0-9.]+), ([0-9.]+)\\)")
	var in_item_style := false
	var checked := 0
	for line in text.split("\n"):
		if line.begins_with("["):
			in_item_style = line.contains("StyleBoxFlat_item_")
			continue
		var mine: bool = in_item_style or line.begins_with("Item") or line.begins_with("RailButtonSelected")
		if not mine:
			continue
		for hit in re.search_all(line):
			var c := Color(float(hit.get_string(1)), float(hit.get_string(2)), float(hit.get_string(3)), 1.0)
			checked += 1
			for name in forbidden:
				var f: Color = forbidden[name]
				if absf(c.r - f.r) < 0.012 and absf(c.g - f.g) < 0.012 and absf(c.b - f.b) < 0.012:
					return _fail(m, "the item styles use the forbidden %s: %s" % [name, line])
	if checked < 40:
		return _fail(m, "the scan checked only %d colours" % checked)
	return _pass(m)
