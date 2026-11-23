# res://tests/PickupUiTextTests.gd
# V2-ITEM-001b step U2: the pickup event text module, its proposed-copy fixture, the theme variations and their contrast.
# The fixture tests/fixtures/PickupUiProposedCopy.json holds every line as a PROPOSAL (ANSWERS #89, D-56).
# ItemUiApprovedCopy.json is not read here and is not changed.

class_name PickupUiTextTests
extends RefCounted

const ItemUiText := preload("res://ui/components/ItemUiText.gd")
const _FIXTURE := "res://tests/fixtures/PickupUiProposedCopy.json"
# Length limits are layout guards chosen by U2 (no decision record).
const _BARK_MAX := 60
const _LINE_MAX := 120
const _NEW_VARIATIONS: Array = ["PickupSlotEmpty", "PickupSlotNew", "PickupBar", "PickupBarText",
	"PickupNameTag", "PickupWhereGround", "PickupWhereCarried", "PickupWherePack", "PickupAllowance",
	"PickupAllowanceSpent", "PickupControlButton"]
const _REUSED_VARIATIONS: Array = ["ItemPanelPack", "ItemPanelPackNear", "ItemPanelPackHeavy", "ItemSlotPack",
	"ItemTileSelectedDark", "ItemDim", "ItemDetailsPanel", "ItemButtonGold", "ItemButtonOutline", "ItemButtonBlocked",
	"ItemTextDark", "ItemTextLight", "ItemTextLightMuted", "ItemTitleDark", "EmotionChipHesitant"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/text_module_and_proposed_fixture_match_both_ways", Callable(PickupUiTextTests, "_t_fixture"))
	runner.register_test("pickup_ui/text_lines_obey_the_copy_rules", Callable(PickupUiTextTests, "_t_rules"))
	runner.register_test("pickup_ui/text_lookups_map_keys_and_fall_back_safely", Callable(PickupUiTextTests, "_t_lookups"))
	runner.register_test("pickup_ui/theme_variations_exist_and_reuse_tokens", Callable(PickupUiTextTests, "_t_theme"))
	runner.register_test("pickup_ui/theme_contrast_pairs_meet_wcag_aa", Callable(PickupUiTextTests, "_t_contrast"))


static func _fixture() -> Dictionary:
	var fx: Variant = JSON.parse_string(FileAccess.get_file_as_string(_FIXTURE))
	return fx if fx is Dictionary else {}


static func _fail(msg: String) -> Dictionary:
	return { "ok": false, "error": msg }


static func _t_fixture() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _fail("the proposed-copy fixture does not parse")
	if not fx.has("_header"):
		return _fail("the fixture has no _header that marks the lines as proposals")
	for key: String in PickupUiText.LINES:
		if not fx.has(key):
			return _fail("%s is in PickupUiText but not in the fixture" % key)
	for key: String in fx:
		if key.begins_with("_"):
			continue
		if not PickupUiText.LINES.has(key):
			return _fail("the fixture holds %s, which PickupUiText no longer has" % key)
		var e: Dictionary = fx[key]
		if not ["mockup", "agent"].has(str(e.get("source", ""))):
			return _fail("%s has no source mockup or agent" % key)
		if str(e.get("status", "")) != "proposal":
			return _fail("%s is not marked status proposal" % key)
		if str(e.get("text", "<missing>")) != str(PickupUiText.LINES[key]):
			return _fail("%s is '%s' in the module, '%s' in the fixture" % [key, PickupUiText.LINES[key], e.get("text", "")])
	return { "ok": true }


static func _t_rules() -> Dictionary:
	var fx := _fixture()
	var banned := RegEx.create_from_string("(?i)\\b(home\\w*|stage\\w*|staging|staged)\\b")
	# Real find ids: f<digit> in tests, t<N>.<i> from the debug producer (PickupDebug, DebugController).
	var ids := RegEx.create_from_string("(?i)(\\bit\\.[0-9a-z_]+|stack:|\\bitem:\\w+:\\w+|\\bf\\d+\\b|\\bp\\d+\\b|\\bt\\d+\\.\\d+|find_id|type_id|pack_id|\\bC[1-5]\\b)")
	for key: String in PickupUiText.LINES:
		var text := str(PickupUiText.LINES[key])
		if text.is_empty():
			if not bool((fx.get(key, {}) as Dictionary).get("intentionally_empty", false)):
				return _fail("%s is empty and not marked intentionally_empty" % key)
			continue
		if bool((fx.get(key, {}) as Dictionary).get("intentionally_empty", false)):
			return _fail("%s is marked intentionally_empty but has text" % key)
		if banned.search(text) != null:
			return _fail("%s uses a banned word: '%s'" % [key, text])
		if ids.search(text) != null:
			return _fail("%s looks like it holds an id: '%s'" % [key, text])
		var limit := _BARK_MAX if key.begins_with("bark.") else _LINE_MAX
		if text.length() > limit:
			return _fail("%s is %d characters, limit %d" % [key, text.length(), limit])
		if text != text.strip_edges() and not (key == "a11y.on_ground" or key == "a11y.held_up" or key == "a11y.in_pack"):
			return _fail("%s has edge spaces" % key)
	return { "ok": true }


static func _t_lookups() -> Dictionary:
	var errors: Array = []
	# Barks by snapshot keys. The group is the mockup rule: frozen, C5 afraid or full, C1 and C3 fits, C2 and C4 by band.
	var cases := [
		["frozen", "none", "froze", "mid", "bark.froze.0"], ["C2", "none", "froze", "mid", "bark.froze.0"],
		["C5", "none", "identity", "mid", "bark.afraid.0"], ["C5", "minus", "state", "mid", "bark.full.0"],
		["C1", "plus", "identity", "mid", "bark.fits.0"], ["C3", "plus", "sense", "low", "bark.fits.0"],
		["C2", "none", "identity", "mid", "bark.some.0"], ["C4", "none", "identity", "low", "bark.some_low.0"],
		["C4", "none", "state", "high", "bark.some_high.0"],
	]
	for c: Array in cases:
		var got := PickupUiText.bark(str(c[0]), str(c[1]), str(c[2]), str(c[3]))
		if got.is_empty() or got != PickupUiText.line(str(c[4])):
			errors.append("bark %s gave '%s', wanted %s" % [str(c), got, c[4]])
	if PickupUiText.bark("C5", "minus", "state", "mid", 1) != PickupUiText.line("bark.full.1") \
			or PickupUiText.bark("C5", "minus", "state", "mid", 2) != PickupUiText.line("bark.full.0") \
			or PickupUiText.bark("C5", "minus", "state", "mid", -1) != PickupUiText.line("bark.full.1"):
		errors.append("the bark variant does not wrap")
	if PickupUiText.standing_band(1) != "low" or PickupUiText.standing_band(2) != "low" \
			or PickupUiText.standing_band(5) != "mid" or PickupUiText.standing_band(9) != "high":
		errors.append("standing_band is wrong")
	# Safe fallbacks for unknown keys.
	for got: String in [PickupUiText.bark("", "", "", ""), PickupUiText.bark("C9", "plus", "x", "mid"), PickupUiText.line("nope"),
			PickupUiText.refusal("nope"), PickupUiText.refusal("bad_pair"), PickupUiText.refusal("ended"),
			PickupUiText.refusal("bad_payload"), PickupUiText.refusal("frozen"), PickupUiText.where_text("nope"),
			PickupUiText.tone_word("plain"), PickupUiText.tone_word("nope")]:
		if not got.is_empty():
			errors.append("an unknown or silent key gave '%s'" % got)
	for key in ["used", "has_room", "nothing_left", "same", "no_target"]:
		if PickupUiText.refusal(key).is_empty():
			errors.append("refusal %s is empty" % key)
	# Reuse of the approved item words.
	if PickupUiText.where_text("pack") != ItemUiText.WHERE_PACK or PickupUiText.tone_word("full") != ItemUiText.FULL_WORD \
			or PickupUiText.tone_word("near") != ItemUiText.PACK_NEAR \
			or PickupUiText.destroy_allowance(1) != ItemUiText.PATH_LEFT or PickupUiText.destroy_allowance(0) != ItemUiText.PATH_USED \
			or PickupUiText.count_text(3, 20) != ItemUiText.stack_count(3, 20):
		errors.append("an item word is not taken from ItemUiText")
	if PickupUiText.where_text("ground").is_empty() or PickupUiText.where_text("carried").is_empty() \
			or PickupUiText.count_text(1, 20).is_empty() or PickupUiText.swap_allowance(1).is_empty() \
			or PickupUiText.swap_allowance(0).is_empty():
		errors.append("a details line is empty")
	if PickupUiText.item_label("Dusk Charm", "carried") != "Dusk Charm, held up" or PickupUiText.item_label("Dusk Charm", "") != "Dusk Charm":
		errors.append("item_label is wrong")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _theme() -> Theme:
	return ThemeDB.get_project_theme()


static func _t_theme() -> Dictionary:
	var theme := _theme()
	if theme == null:
		return _fail("no project theme")
	var types := theme.get_type_list()
	for vname: String in _NEW_VARIATIONS + _REUSED_VARIATIONS:
		if not types.has(vname):
			return _fail("theme variation %s is missing" % vname)
	for sname: String in ["PickupSlotEmpty", "PickupSlotNew", "PickupBar", "PickupNameTag",
			"PickupWhereGround", "PickupWhereCarried", "PickupWherePack", "PickupAllowance", "PickupAllowanceSpent"]:
		if not (theme.get_stylebox("panel", sname) is StyleBoxFlat):
			return _fail("%s has no StyleBoxFlat panel" % sname)
	# The three where tags differ by shape as well as by colour.
	var g := theme.get_stylebox("panel", "PickupWhereGround") as StyleBoxFlat
	var c := theme.get_stylebox("panel", "PickupWhereCarried") as StyleBoxFlat
	var p := theme.get_stylebox("panel", "PickupWherePack") as StyleBoxFlat
	if g.border_width_left == c.border_width_left or g.corner_radius_top_left == c.corner_radius_top_left \
			or p.corner_radius_top_left == c.corner_radius_top_left:
		return _fail("the where tags do not differ by border and corner shape")
	var base_types := { "PickupSlotEmpty": "Panel", "PickupSlotNew": "Panel",
		"PickupBar": "PanelContainer", "PickupBarText": "Label", "PickupNameTag": "PanelContainer",
		"PickupWhereGround": "PanelContainer", "PickupWhereCarried": "PanelContainer", "PickupWherePack": "PanelContainer",
		"PickupAllowance": "PanelContainer", "PickupAllowanceSpent": "PanelContainer", "PickupControlButton": "Button" }
	for vname: String in base_types:
		if str(theme.get_type_variation_base(vname)) != str(base_types[vname]):
			return _fail("%s has base type %s, expected %s" % [vname, theme.get_type_variation_base(vname), base_types[vname]])
	return _new_colour_check()


## No new colour (decided for U2): every RGB triple in the pickup sub_resources and Pickup* variation lines must already
## appear in the other parts of the .tres. Alpha is ignored, so an alpha-only variant counts as reuse. New triples print.
static func _new_colour_check() -> Dictionary:
	var rx := RegEx.create_from_string("Color\\(([0-9.]+), ([0-9.]+), ([0-9.]+)")
	var old := {}
	var fresh := {}
	var pickup := false
	for ln: String in FileAccess.get_file_as_string("res://assets/theme/LivingTreeSystem.tres").split("\n"):
		if ln.begins_with("["):
			pickup = ln.contains("id=\"StyleBoxFlat_pickup")
		var mine := pickup or ln.begins_with("Pickup")
		for m: RegExMatch in rx.search_all(ln):
			var key := "%.4f, %.4f, %.4f" % [float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3))]
			if mine:
				fresh[key] = true
			else:
				old[key] = true
	var errors: Array = []
	for key: String in fresh:
		if not old.has(key):
			print("  NEW COLOUR in pickup styles: Color(%s)" % key)
			errors.append("new colour (%s)" % key)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


static func _ratio(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _over(fg: Color, bg: Color) -> Color:
	return Color(fg.r * fg.a + bg.r * (1.0 - fg.a), fg.g * fg.a + bg.g * (1.0 - fg.a), fg.b * fg.a + bg.b * (1.0 - fg.a), 1.0)


static func _bg(theme: Theme, type: String, state: String = "panel") -> Color:
	return (theme.get_stylebox(state, type) as StyleBoxFlat).bg_color


static func _edge(theme: Theme, type: String) -> Color:
	return (theme.get_stylebox("panel", type) as StyleBoxFlat).border_color


static func _ink(theme: Theme, type: String, color: String = "font_color") -> Color:
	return theme.get_color(color, type)


static func _t_contrast() -> Dictionary:
	var theme := _theme()
	if theme == null:
		return _fail("no project theme")
	var tones: Array = ["ItemPanelPack", "ItemPanelPackNear", "ItemPanelPackHeavy"]
	var pairs: Array = []  # [label, foreground, background, minimum ratio]
	for t: String in tones:
		pairs.append(["pack text on %s" % t, _ink(theme, "ItemTextDark"), _bg(theme, t), 4.5])
		pairs.append(["slot empty edge on %s" % t, _over(_edge(theme, "PickupSlotEmpty"), _bg(theme, t)), _bg(theme, t), 3.0])
		pairs.append(["slot new edge on %s" % t, _edge(theme, "PickupSlotNew"), _bg(theme, t), 3.0])
		pairs.append(["allowance edge on %s" % t, _edge(theme, "PickupAllowance"), _bg(theme, t), 3.0])
		pairs.append(["spent allowance edge on %s" % t, _over(_edge(theme, "PickupAllowanceSpent"), _bg(theme, t)), _bg(theme, t), 3.0])
	pairs.append(["details text on card", _ink(theme, "ItemTextLight"), _bg(theme, "ItemDetailsPanel"), 4.5])
	pairs.append(["details muted text on card", _ink(theme, "ItemTextLightMuted"), _bg(theme, "ItemDetailsPanel"), 4.5])
	pairs.append(["details card edge", _edge(theme, "ItemDetailsPanel"), _bg(theme, "ItemDetailsPanel"), 3.0])
	pairs.append(["bar text on bar", _ink(theme, "PickupBarText"), _bg(theme, "PickupBar"), 4.5])
	pairs.append(["bar edge", _edge(theme, "PickupBar"), _bg(theme, "PickupBar"), 3.0])
	pairs.append(["Keep button text on bar", _ink(theme, "ItemButtonOutline"), _bg(theme, "PickupBar"), 4.5])
	pairs.append(["Swap button text on gold", _ink(theme, "ItemButtonGold"), _bg(theme, "ItemButtonGold", "normal"), 4.5])
	pairs.append(["where ground text", _ink(theme, "ItemTextLight"), _bg(theme, "PickupWhereGround"), 4.5])
	pairs.append(["where carried text", _ink(theme, "ItemTextLight"), _bg(theme, "PickupWhereCarried"), 4.5])
	pairs.append(["where pack text", _ink(theme, "ItemTextDark"), _bg(theme, "PickupWherePack"), 4.5])
	pairs.append(["where pack edge", _edge(theme, "PickupWherePack"), _bg(theme, "PickupWherePack"), 3.0])
	pairs.append(["name tag text", _ink(theme, "ItemTextDark"), _bg(theme, "PickupNameTag"), 4.5])
	pairs.append(["control text on its outline", _ink(theme, "PickupControlButton"), _ink(theme, "PickupControlButton", "font_outline_color"), 4.5])
	pairs.append(["control hover text on its outline", _ink(theme, "PickupControlButton", "font_hover_color"), _ink(theme, "PickupControlButton", "font_outline_color"), 4.5])
	var errors: Array = []
	print("PICKUP UI CONTRAST (ratio, minimum)")
	for pair: Array in pairs:
		var r := _ratio(pair[1], pair[2])
		print("  %-40s %6.2f:1  min %.1f" % [pair[0], r, pair[3]])
		if r < float(pair[3]):
			errors.append("%s reads %.2f:1, needs %.1f:1" % [pair[0], r, pair[3]])
	# Informational, not asserted: U-steps may put text on a new slot.
	var fill := _over(_bg(theme, "PickupSlotNew"), _bg(theme, "ItemPanelPack"))
	print("  INFO cream text on slot-new fill over ItemPanelPack %.2f:1 (not asserted)" % _ratio(_ink(theme, "ItemTextDark"), fill))
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }
