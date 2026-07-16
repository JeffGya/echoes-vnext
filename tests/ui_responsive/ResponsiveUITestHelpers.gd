extends RefCounted
class_name ResponsiveUITestHelpers

const MIN_TARGET := 48.0
const MIN_PRIMARY_TARGET := 56.0

static func desktop_matrix() -> Array[Dictionary]:
	return [
		{ "size": Vector2(960, 540), "profile": &"compact", "logical": Vector2(960, 540), "scale": 1.0 },
		{ "size": Vector2(1280, 720), "profile": &"standard", "logical": Vector2(1280, 720), "scale": 1.0 },
		{ "size": Vector2(1600, 900), "profile": &"standard", "logical": Vector2(1280, 720), "scale": 1.25 },
		{ "size": Vector2(1920, 1080), "profile": &"wide", "logical": Vector2(1536, 864), "scale": 1.25 },
		{ "size": Vector2(2560, 1440), "profile": &"wide", "logical": Vector2(2048, 1152), "scale": 1.25 },
		{ "size": Vector2(3440, 1440), "profile": &"wide", "logical": Vector2(2752, 1152), "scale": 1.25 },
	]

static func device_safe_matrix() -> Array[Dictionary]:
	return [
		{
			"size": Vector2(1920, 1080),
			"safe": Rect2i(84, 0, 1752, 1020),
			"device": &"phone",
			"scale": 2.0,
			"profile": &"compact",
			"insets": Vector4(42, 0, 42, 30),
		},
		{
			"size": Vector2(2340, 1080),
			"safe": Rect2i(120, 0, 2100, 1016),
			"device": &"phone",
			"scale": 2.0,
			"profile": &"compact",
			"insets": Vector4(60, 0, 60, 32),
		},
		{
			"size": Vector2(1920, 1200),
			"safe": Rect2i(0, 24, 1920, 1140),
			"device": &"tablet",
			"scale": 1.5,
			"profile": &"standard",
			"insets": Vector4(0, 16, 0, 24),
		},
		{
			"size": Vector2(1440, 1080),
			"safe": Rect2i(0, 0, 1440, 1044),
			"device": &"tablet",
			"scale": 1.125,
			"profile": &"standard",
			"insets": Vector4(0, 0, 0, 32),
		},
	]

static func assert_layout_case(layout: Dictionary, c: Dictionary) -> Dictionary:
	if layout.get("profile", &"") != c.get("profile", &""):
		return _fail("Expected profile %s, got %s" % [str(c.get("profile", &"")), str(layout.get("profile", &""))])
	var scale := float(layout.get("ui_scale", 0.0))
	if absf(scale - float(c.get("scale", 0.0))) > 0.001:
		return _fail("Expected scale %.3f, got %.3f" % [float(c.get("scale", 0.0)), scale])
	if c.has("logical"):
		var logical: Vector2 = layout.get("logical_size", Vector2.ZERO)
		if logical.distance_to(c["logical"]) > 0.01:
			return _fail("Expected logical %s, got %s" % [str(c["logical"]), str(logical)])
	if c.has("insets"):
		var insets: Vector4 = layout.get("safe_insets", Vector4.ZERO)
		if insets.distance_to(c["insets"]) > 0.01:
			return _fail("Expected insets %s, got %s" % [str(c["insets"]), str(insets)])
	return { "ok": true }

static func inspect_scene_controls(scene: PackedScene, layout: Dictionary) -> Dictionary:
	var root := scene.instantiate() as Control
	if root == null:
		return _fail("Scene did not instantiate as Control")
	var safe_frame := root.get_node_or_null("SafeFrame") as Control
	if safe_frame == null:
		root.free()
		return _fail("Expected unique SafeFrame")
	if safe_frame.has_method("set_layout"):
		safe_frame.call("set_layout", layout)
	var margin_left := safe_frame.get_theme_constant("margin_left")
	var margin_top := safe_frame.get_theme_constant("margin_top")
	var margin_right := safe_frame.get_theme_constant("margin_right")
	var margin_bottom := safe_frame.get_theme_constant("margin_bottom")
	var insets: Vector4 = layout.get("safe_insets", Vector4.ZERO)
	if margin_left < maxi(16, int(ceilf(insets.x))) or margin_top < maxi(16, int(ceilf(insets.y))):
		root.free()
		return _fail("SafeFrame did not apply left/top safe margins")
	if margin_right < maxi(16, int(ceilf(insets.z))) or margin_bottom < maxi(16, int(ceilf(insets.w))):
		root.free()
		return _fail("SafeFrame did not apply right/bottom safe margins")
	var button_result := assert_button_targets(root)
	root.free()
	return button_result

static func assert_scroll_present(scene: PackedScene, scroll_path: NodePath) -> Dictionary:
	var root := scene.instantiate() as Control
	if root == null:
		return _fail("Scene did not instantiate as Control")
	var scroll := root.get_node_or_null(scroll_path) as ScrollContainer
	if scroll == null:
		root.free()
		return _fail("Expected ScrollContainer at %s" % str(scroll_path))
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		root.free()
		return _fail("Expected horizontal scroll disabled for %s" % str(scroll_path))
	root.free()
	return { "ok": true }

static func assert_button_outside_scroll(scene: PackedScene, button_name: StringName) -> Dictionary:
	var root := scene.instantiate() as Control
	if root == null:
		return _fail("Scene did not instantiate as Control")
	var button := root.get_node_or_null("%" + str(button_name)) as Button
	if button == null:
		root.free()
		return _fail("Expected button %" + str(button_name))
	var current := button.get_parent()
	while current != null:
		if current is ScrollContainer:
			root.free()
			return _fail("Expected %" + str(button_name) + " outside ScrollContainer")
		current = current.get_parent()
	root.free()
	return { "ok": true }

static func assert_button_targets(root: Node) -> Dictionary:
	var buttons: Array[Button] = []
	_collect_buttons(root, buttons)
	for button in buttons:
		if not _is_effectively_visible(button):
			continue
		var min_size := button.custom_minimum_size
		if min_size.y < MIN_TARGET:
			return _fail("%s target height %.1f is below %.1f" % [button.name, min_size.y, MIN_TARGET])
		var variation := str(button.theme_type_variation)
		if variation == "ButtonPrimary" and min_size.y < MIN_PRIMARY_TARGET:
			return _fail("%s primary target height %.1f is below %.1f" % [button.name, min_size.y, MIN_PRIMARY_TARGET])
	return { "ok": true }

static func _is_effectively_visible(control: Control) -> bool:
	var current: Node = control
	while current != null:
		if current is CanvasItem and not (current as CanvasItem).visible:
			return false
		current = current.get_parent()
	return true

static func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node as Button)
	for child in node.get_children():
		_collect_buttons(child, out)

static func _fail(message: String) -> Dictionary:
	return { "ok": false, "error": message }
