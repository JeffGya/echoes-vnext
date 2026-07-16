extends RefCounted
class_name FoundationUITests

const LayoutController := preload("res://ui/components/ResponsiveLayoutController.gd")
const ModalHostScene := preload("res://ui/components/ModalHost.tscn")
const ResponsiveHelpers := preload("res://tests/ui_responsive/ResponsiveUITestHelpers.gd")
const FakeLayoutReceiverScript := preload("res://tests/ui_responsive/FakeLayoutReceiver.gd")
const TestModalFixtureScene := preload("res://tests/ui_responsive/TestModalFixture.tscn")
const SaveErrorScene := preload("res://ui/screens/boot/SaveErrorScreen.tscn")
const InvocationScene := preload("res://ui/screens/onboarding/InvocationScreen.tscn")
const AnansiScene := preload("res://ui/screens/onboarding/AnansiWebScreen.tscn")
const ForgottenNameScene := preload("res://ui/screens/onboarding/ForgottenNameScreen.tscn")
const FirstSanctumScene := preload("res://ui/screens/onboarding/FirstSanctumEncounterScreen.tscn")
const SanctumNamingScene := preload("res://ui/screens/onboarding/SanctumNamingScreen.tscn")
const KeeperIntroScene := preload("res://ui/screens/onboarding/KeeperIntroScreen.tscn")
const LivingTreeTheme := preload("res://assets/theme/LivingTreeSystem.tres")
const PrebattleModalScene := preload("res://ui/overlays/realm/PrebattleModal.tscn")
const EngagementModalScene := preload("res://ui/overlays/realm/EngagementModal.tscn")
const ContactModalScene := preload("res://ui/overlays/realm/ContactModal.tscn")
const SituationModalScene := preload("res://ui/overlays/realm/SituationModal.tscn")
const ReturnHomeModalScene := preload("res://ui/overlays/realm/ReturnHomeModal.tscn")
const CallingInfoModalScene := preload("res://ui/overlays/sanctum/CallingInfoModal.tscn")
const CompanionInviteModalScene := preload("res://ui/overlays/sanctum/CompanionInviteModal.tscn")
const InstitutionDetailModalScene := preload("res://ui/overlays/sanctum/InstitutionDetailModal.tscn")
const VowMomentModalScene := preload("res://ui/overlays/sanctum/VowMomentModal.tscn")
const RankUpOverlayScene := preload("res://ui/overlays/RankUpOverlay.tscn")
const SummonRevealOverlayScene := preload("res://ui/overlays/SummonRevealOverlay.tscn")
const ResolveScene := preload("res://ui/screens/venture/ResolveScreen.tscn")

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("foundation_ui/desktop_scale_profile_matrix", Callable(FoundationUITests, "_t_desktop_scale_profile_matrix"))
	runner.register_test("foundation_ui/mobile_profile_caps", Callable(FoundationUITests, "_t_mobile_profile_caps"))
	runner.register_test("foundation_ui/device_profile_detection", Callable(FoundationUITests, "_t_device_profile_detection"))
	runner.register_test("foundation_ui/safe_area_insets_are_logical", Callable(FoundationUITests, "_t_safe_area_insets_are_logical"))
	runner.register_test("foundation_ui/expanded_device_regression_matrix", Callable(FoundationUITests, "_t_expanded_device_regression_matrix"))
	runner.register_test("foundation_ui/live_resize_uses_new_safe_transform", Callable(FoundationUITests, "_t_live_resize_uses_new_safe_transform"))
	runner.register_test("foundation_ui/wide_bounds_grow_while_ui_scale_caps", Callable(FoundationUITests, "_t_wide_bounds_grow_while_ui_scale_caps"))
	runner.register_test("foundation_ui/app_root_layers_and_full_rect_host", Callable(FoundationUITests, "_t_app_root_layers_and_full_rect_host"))
	runner.register_test("foundation_ui/app_root_layout_forwarding_contract", Callable(FoundationUITests, "_t_app_root_layout_forwarding_contract"))
	runner.register_test("foundation_ui/modal_host_one_active_contract", Callable(FoundationUITests, "_t_modal_host_one_active_contract"))
	runner.register_test("foundation_ui/modal_dismissal_notifies_owner_once", Callable(FoundationUITests, "_t_modal_dismissal_notifies_owner_once"))
	runner.register_test("foundation_ui/modal_host_backdrop_and_trap_contract", Callable(FoundationUITests, "_t_modal_host_backdrop_and_trap_contract"))
	runner.register_test("foundation_ui/onboarding_boot_safe_frames_and_targets", Callable(FoundationUITests, "_t_onboarding_boot_safe_frames_and_targets"))
	runner.register_test("foundation_ui/onboarding_boot_scroll_and_cta_contract", Callable(FoundationUITests, "_t_onboarding_boot_scroll_and_cta_contract"))
	runner.register_test("foundation_ui/realm_modal_living_tree_contrast_and_buttons", Callable(FoundationUITests, "_t_realm_modal_living_tree_contrast_and_buttons"))
	runner.register_test("foundation_ui/blocking_modal_living_tree_cta_styles", Callable(FoundationUITests, "_t_blocking_modal_living_tree_cta_styles"))
	runner.register_test("foundation_ui/resolve_modal_geometry_compact_and_wide", Callable(FoundationUITests, "_t_resolve_modal_geometry_compact_and_wide"))

static func _t_desktop_scale_profile_matrix() -> Dictionary:
	var cases := [
		{ "size": Vector2(960, 540), "scale": 1.0, "profile": &"compact", "logical": Vector2(960, 540) },
		{ "size": Vector2(1280, 720), "scale": 1.0, "profile": &"standard", "logical": Vector2(1280, 720) },
		{ "size": Vector2(1600, 900), "scale": 1.25, "profile": &"standard", "logical": Vector2(1280, 720) },
		{ "size": Vector2(1920, 1080), "scale": 1.25, "profile": &"wide", "logical": Vector2(1536, 864) },
		{ "size": Vector2(2560, 1440), "scale": 1.25, "profile": &"wide", "logical": Vector2(2048, 1152) },
		{ "size": Vector2(3440, 1440), "scale": 1.25, "profile": &"wide", "logical": Vector2(2752, 1152) },
	]
	for c in cases:
		var layout: Dictionary = LayoutController.calculate_layout(c["size"])
		var got_scale := float(layout.get("ui_scale", 0.0))
		if absf(got_scale - float(c["scale"])) > 0.001:
			return { "ok": false, "error": "Expected %s scale %.2f, got %.3f" % [str(c["size"]), float(c["scale"]), got_scale] }
		if layout.get("profile", &"") != c["profile"]:
			return { "ok": false, "error": "Expected %s profile %s, got %s" % [str(c["size"]), str(c["profile"]), str(layout.get("profile", &""))] }
		var logical: Vector2 = layout.get("logical_size", Vector2.ZERO)
		if logical.distance_to(c["logical"]) > 0.01:
			return { "ok": false, "error": "Expected %s logical %s, got %s" % [str(c["size"]), str(c["logical"]), str(logical)] }
	return { "ok": true }

static func _t_mobile_profile_caps() -> Dictionary:
	var phone: Dictionary = LayoutController.calculate_layout(Vector2(1920, 1080), Rect2i(), &"phone")
	if absf(float(phone.get("ui_scale", 0.0)) - 2.0) > 0.001:
		return { "ok": false, "error": "Expected phone scale cap 2.0, got %s" % str(phone.get("ui_scale", 0.0)) }
	if phone.get("logical_size", Vector2.ZERO).distance_to(Vector2(960, 540)) > 0.01:
		return { "ok": false, "error": "Expected phone logical target 960x540, got %s" % str(phone.get("logical_size", Vector2.ZERO)) }
	if not bool(phone.get("is_mobile", false)):
		return { "ok": false, "error": "Expected phone is_mobile=true" }

	var tablet: Dictionary = LayoutController.calculate_layout(Vector2(1920, 1080), Rect2i(), &"tablet")
	if absf(float(tablet.get("ui_scale", 0.0)) - 1.5) > 0.001:
		return { "ok": false, "error": "Expected tablet scale cap 1.5, got %s" % str(tablet.get("ui_scale", 0.0)) }
	if tablet.get("logical_size", Vector2.ZERO).distance_to(Vector2(1280, 720)) > 0.01:
		return { "ok": false, "error": "Expected tablet logical target 1280x720, got %s" % str(tablet.get("logical_size", Vector2.ZERO)) }
	if not bool(tablet.get("is_mobile", false)):
		return { "ok": false, "error": "Expected tablet is_mobile=true" }
	return { "ok": true }

static func _t_safe_area_insets_are_logical() -> Dictionary:
	var layout: Dictionary = LayoutController.calculate_layout(
		Vector2(1920, 1080),
		Rect2i(60, 30, 1800, 1000),
		&"desktop",
		Transform2D(Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(-10.0, -20.0))
	)
	var insets: Vector4 = layout.get("safe_insets", Vector4.ZERO)
	if insets.distance_to(Vector4(30, 15, 30, 25)) > 0.01:
		return { "ok": false, "error": "Expected transformed logical insets (30,15,30,25), got %s" % str(insets) }

	var invalid: Dictionary = LayoutController.calculate_layout(
		Vector2(1280, 720),
		Rect2i(-1, 0, 1280, 720),
		&"desktop"
	)
	if invalid.get("safe_insets", Vector4.ONE) != Vector4.ZERO:
		return { "ok": false, "error": "Expected invalid safe area to produce zero insets" }
	return { "ok": true }

static func _t_expanded_device_regression_matrix() -> Dictionary:
	for c in ResponsiveHelpers.desktop_matrix():
		var layout: Dictionary = LayoutController.calculate_layout(c["size"])
		var result: Dictionary = ResponsiveHelpers.assert_layout_case(layout, c)
		if not bool(result.get("ok", false)):
			return result
	for c in ResponsiveHelpers.device_safe_matrix():
		var scale := float(c["scale"])
		var inverse := Transform2D(Vector2(1.0 / scale, 0.0), Vector2(0.0, 1.0 / scale), Vector2.ZERO)
		var layout: Dictionary = LayoutController.calculate_layout(c["size"], c["safe"], c["device"], inverse)
		var result: Dictionary = ResponsiveHelpers.assert_layout_case(layout, c)
		if not bool(result.get("ok", false)):
			return result
	return { "ok": true }

static func _t_device_profile_detection() -> Dictionary:
	var phone := LayoutController.detect_device_profile(Vector2i(2532, 1170), 460, Vector2i(1280, 720), true)
	if phone != &"phone":
		return { "ok": false, "error": "Expected high-DPI 6in mobile screen to detect phone, got %s" % str(phone) }
	var tablet := LayoutController.detect_device_profile(Vector2i(2732, 2048), 264, Vector2i(1366, 1024), true)
	if tablet != &"tablet":
		return { "ok": false, "error": "Expected high-DPI 13in mobile screen to detect tablet, got %s" % str(tablet) }
	var fallback_phone := LayoutController.detect_device_profile(Vector2i(1920, 840), 0, Vector2i(960, 540), true)
	if fallback_phone != &"phone":
		return { "ok": false, "error": "Expected aspect fallback to detect phone, got %s" % str(fallback_phone) }
	var high_res_fallback_phone := LayoutController.detect_device_profile(Vector2i(2340, 1080), 0, Vector2i(1170, 540), true)
	if high_res_fallback_phone != &"phone":
		return { "ok": false, "error": "Expected high-resolution phone aspect fallback to detect phone, got %s" % str(high_res_fallback_phone) }
	var desktop := LayoutController.detect_device_profile(Vector2i(2560, 1440), 110, Vector2i(1600, 900), false)
	if desktop != &"desktop":
		return { "ok": false, "error": "Expected non-mobile large screen to detect desktop, got %s" % str(desktop) }
	var min_desktop := LayoutController.detect_device_profile(Vector2i(2560, 1440), 110, Vector2i(960, 540), false)
	if min_desktop != &"desktop":
		return { "ok": false, "error": "Expected 960x540 non-mobile window to stay desktop, got %s" % str(min_desktop) }
	return { "ok": true }

static func _t_live_resize_uses_new_safe_transform() -> Dictionary:
	var safe_rect := Rect2i(125, 50, 1795, 1030)
	var stale_from_1600 := Transform2D(Vector2(1.0 / 1.5, 0.0), Vector2(0.0, 1.0 / 1.5), Vector2.ZERO)
	var current_for_1920 := Transform2D(Vector2(1.0 / 1.25, 0.0), Vector2(0.0, 1.0 / 1.25), Vector2.ZERO)
	var stale_layout: Dictionary = LayoutController.calculate_layout(
		Vector2(1920, 1080),
		safe_rect,
		&"desktop",
		stale_from_1600
	)
	var final_layout: Dictionary = LayoutController.calculate_runtime_layout_after_scale(
		Vector2(1920, 1080),
		safe_rect,
		&"desktop",
		current_for_1920
	)
	var stale_insets: Vector4 = stale_layout.get("safe_insets", Vector4.ZERO)
	var final_insets: Vector4 = final_layout.get("safe_insets", Vector4.ZERO)
	if stale_insets.distance_to(Vector4(83.333, 33.333, 0, 0)) > 0.01:
		return { "ok": false, "error": "Stale transform fixture unexpected: %s" % str(stale_insets) }
	if final_insets.distance_to(Vector4(100, 40, 0, 0)) > 0.01:
		return { "ok": false, "error": "Expected resized safe insets to use new 1.25x transform, got %s" % str(final_insets) }
	if final_insets == stale_insets:
		return { "ok": false, "error": "Expected final safe insets to differ from stale transform result" }
	return { "ok": true }

static func _t_wide_bounds_grow_while_ui_scale_caps() -> Dictionary:
	var standard: Dictionary = LayoutController.calculate_layout(Vector2(1920, 1080))
	var ultra: Dictionary = LayoutController.calculate_layout(Vector2(3440, 1440))
	if float(standard.get("ui_scale", 0.0)) != float(ultra.get("ui_scale", 0.0)):
		return { "ok": false, "error": "Expected wide desktop scale cap to remain stable" }
	var standard_size: Vector2 = standard.get("logical_size", Vector2.ZERO)
	var ultra_size: Vector2 = ultra.get("logical_size", Vector2.ZERO)
	if ultra_size.x <= standard_size.x or ultra_size.y <= standard_size.y:
		return { "ok": false, "error": "Expected ultrawide logical/spatial bounds to grow" }
	if standard.get("profile", &"") != &"wide" or ultra.get("profile", &"") != &"wide":
		return { "ok": false, "error": "Expected both large desktop layouts to stay wide profile" }
	return { "ok": true }

static func _t_app_root_layers_and_full_rect_host() -> Dictionary:
	var app_root_scene := load("res://ui/Approot.tscn") as PackedScene
	var root := app_root_scene.instantiate() as Control if app_root_scene != null else null
	if root == null:
		return { "ok": false, "error": "Failed to instantiate AppRoot scene" }
	var content_layer := root.get_node_or_null("ContentLayer") as CanvasLayer
	var modal_layer := root.get_node_or_null("ModalLayer") as CanvasLayer
	var debug_layer := root.get_node_or_null("OverlayRoot") as CanvasLayer
	var screen_host := root.get_node_or_null("ContentLayer/ContentRoot/ScreenHost") as Control
	var fallback_root := root.get_node_or_null("ContentLayer/ContentRoot/FallbackRoot") as Control
	if content_layer == null or content_layer.layer != 10:
		root.free()
		return { "ok": false, "error": "Expected ContentLayer layer 10" }
	if modal_layer == null or modal_layer.layer != 40:
		root.free()
		return { "ok": false, "error": "Expected ModalLayer layer 40" }
	if debug_layer == null or debug_layer.layer != 128:
		root.free()
		return { "ok": false, "error": "Expected OverlayRoot debug/recovery layer 128" }
	if screen_host == null:
		root.free()
		return { "ok": false, "error": "Expected ScreenHost under ContentRoot" }
	if fallback_root == null:
		root.free()
		return { "ok": false, "error": "Expected FallbackRoot under ContentRoot" }
	if screen_host.anchor_left != 0.0 or screen_host.anchor_top != 0.0 or screen_host.anchor_right != 1.0 or screen_host.anchor_bottom != 1.0:
		root.free()
		return { "ok": false, "error": "Expected ScreenHost full rect anchors" }
	if fallback_root.anchor_left != 0.0 or fallback_root.anchor_top != 0.0 or fallback_root.anchor_right != 1.0 or fallback_root.anchor_bottom != 1.0:
		root.free()
		return { "ok": false, "error": "Expected FallbackRoot full rect anchors" }
	root.free()
	return { "ok": true }

static func _t_app_root_layout_forwarding_contract() -> Dictionary:
	var app_root_scene := load("res://ui/Approot.tscn") as PackedScene
	var root := app_root_scene.instantiate() as Control if app_root_scene != null else null
	if root == null:
		return { "ok": false, "error": "Failed to instantiate AppRoot scene" }
	var onboarding := FakeLayoutReceiverScript.new() as Control
	var save_error := FakeLayoutReceiverScript.new() as Control
	root.set("_active_onboarding_screen", onboarding)
	root.set("_save_error_screen", save_error)
	root.add_child(onboarding)
	root.add_child(save_error)
	var action_count := 0
	onboarding.action_requested.connect(func(_action: Dictionary): action_count += 1)
	save_error.action_requested.connect(func(_action: Dictionary): action_count += 1)
	var layout := {
		"profile": &"compact",
		"logical_size": Vector2(960, 540),
		"safe_insets": Vector4(60, 0, 60, 32),
		"ui_scale": 2.0,
		"is_mobile": true,
	}
	root.call("_on_layout_changed", layout)
	var onboarding_layouts: Array = onboarding.get("received_layouts")
	var save_error_layouts: Array = save_error.get("received_layouts")
	if onboarding_layouts.size() != 1:
		root.free()
		return { "ok": false, "error": "Expected layout forwarded once to onboarding receiver" }
	if save_error_layouts.size() != 1:
		root.free()
		return { "ok": false, "error": "Expected layout forwarded once to Save Error receiver" }
	if (onboarding_layouts[0] as Dictionary).get("safe_insets", Vector4.ZERO) != layout["safe_insets"]:
		root.free()
		return { "ok": false, "error": "Onboarding receiver got wrong safe insets" }
	if action_count != 0:
		root.free()
		return { "ok": false, "error": "Layout change emitted an action unexpectedly" }
	root.free()
	return { "ok": true }

static func _t_modal_host_one_active_contract() -> Dictionary:
	var fixture := _make_in_tree_modal_host_fixture()
	var viewport := fixture.get("viewport") as SubViewport
	var host := fixture.get("host") as Control
	var underlying := fixture.get("underlying") as Button
	if viewport == null or host == null or underlying == null:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Failed to create in-tree ModalHost fixture" }
	if not host.is_node_ready():
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "ModalHost fixture did not enter the tree and run _ready" }
	var scene_a := TestModalFixtureScene
	var scene_b := _make_basic_modal_scene()
	var dim_backdrop := host.get_node("DimBackdrop") as Control
	var input_blocker := host.get_node("InputBlocker") as Control
	if dim_backdrop.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected DimBackdrop to ignore input" }
	if input_blocker.mouse_filter != Control.MOUSE_FILTER_STOP:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected full-root input blocker to stop input" }
	underlying.grab_focus()
	if viewport.gui_get_focus_owner() != underlying:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected underlying control to own focus before modal presentation" }
	if not host.call("present_modal_for_id", &"first", scene_a, { "value": 1 }):
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected first modal to present" }
	var active := host.get("_active_modal") as Control
	if active == null or int(active.get("present_calls")) != 1 or int((active.get("last_payload") as Dictionary).get("value", 0)) != 1:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected modal present(payload) to be called with value 1" }
	if not host.visible or not host.has_active_modal():
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected host visible with active modal" }
	if host.call("active_modal_id") != &"first":
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected active modal id to be first" }
	var first_button := active.get_node_or_null("%FirstButton") as Button
	var second_button := active.get_node_or_null("%SecondButton") as Button
	if first_button == null or second_button == null or viewport.gui_get_focus_owner() != first_button:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected modal presentation to focus its safest first authored action" }
	second_button.grab_focus()
	if viewport.gui_get_focus_owner() != second_button:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected second modal action to accept focus before refresh" }
	if not host.call("present_modal_for_id", &"first", scene_a, { "value": 2 }):
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected same modal id to update active modal" }
	active = host.get("_active_modal") as Control
	if active == null or int(active.get("present_calls")) != 2 or int((active.get("last_payload") as Dictionary).get("value", 0)) != 2:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected same-ID update to call present(payload) on active modal" }
	if viewport.gui_get_focus_owner() != second_button:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Same-ID refresh stole valid focus from the current modal action" }
	if host.call("present_modal_for_id", &"second", scene_b, {}):
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected different modal id to be rejected while one is active" }
	if host.call("active_modal_id") != &"first":
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected rejected different id not to disturb active modal" }
	underlying.grab_focus()
	if viewport.gui_get_focus_owner() == underlying or not _is_descendant_of(viewport.gui_get_focus_owner(), active):
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected focus trap to return external focus to an action inside the modal" }
	var dismissed_instance := active
	host.call("dismiss_modal")
	if host.visible or host.has_active_modal():
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected host hidden after dismiss" }
	if dismissed_instance != null and is_instance_valid(dismissed_instance) and dismissed_instance.visible:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected outgoing modal hidden before queued deletion" }
	if viewport.gui_get_focus_owner() != underlying:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected dismiss to restore focus to the control active before modal presentation" }
	_free_modal_host_fixture(fixture)
	return { "ok": true }

static func _t_modal_host_backdrop_and_trap_contract() -> Dictionary:
	var fixture := _make_in_tree_modal_host_fixture()
	var viewport := fixture.get("viewport") as SubViewport
	var host := fixture.get("host") as Control
	var underlying := fixture.get("underlying") as Button
	var input_probe := fixture.get("input_probe") as _UnhandledInputProbe
	if viewport == null or host == null or underlying == null or input_probe == null:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Failed to create in-tree ModalHost input fixture" }
	var dim_backdrop := host.get_node("DimBackdrop") as Control
	var input_blocker := host.get_node("InputBlocker") as Control
	var modal_slot := host.get_node("InputBlocker/ModalSlot") as Control
	if dim_backdrop.anchor_left != 0.0 or dim_backdrop.anchor_top != 0.0 or dim_backdrop.anchor_right != 1.0 or dim_backdrop.anchor_bottom != 1.0:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected modal backdrop full viewport anchors" }
	if input_blocker.anchor_left != 0.0 or input_blocker.anchor_top != 0.0 or input_blocker.anchor_right != 1.0 or input_blocker.anchor_bottom != 1.0:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected modal input blocker full viewport anchors" }
	if modal_slot.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected ModalSlot to ignore pointer input outside modal content" }
	var underlying_presses := 0
	underlying.pressed.connect(func(): underlying_presses += 1)
	underlying.grab_focus()
	if not host.call("present_modal_for_id", &"fixture", TestModalFixtureScene, { "value": 7 }):
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected fixture modal to present" }
	var active := host.get("_active_modal") as Control
	if active == null:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected active modal instance" }
	var first_button := active.get_node_or_null("%FirstButton") as Button
	var second_button := active.get_node_or_null("%SecondButton") as Button
	if first_button == null or second_button == null or first_button.focus_mode == Control.FOCUS_NONE:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected authored focusable controls inside modal fixture" }
	var pointer_position := Vector2(72, 52)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pointer_position
	press.global_position = pointer_position
	press.pressed = true
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = pointer_position
	release.global_position = pointer_position
	release.pressed = false
	viewport.push_input(press)
	viewport.push_input(release)
	if underlying_presses != 0:
		host.dismiss_modal()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Full-root modal blocker allowed pointer activation beneath the modal" }
	var blocked_action := InputEventAction.new()
	blocked_action.action = &"ui_cancel"
	blocked_action.pressed = true
	viewport.push_input(blocked_action)
	if input_probe.action_count != 0:
		host.dismiss_modal()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "ModalHost allowed a global action to reach underlying unhandled input" }
	var actions: Array[Dictionary] = []
	host.action_requested.connect(func(action: Dictionary): actions.append(action.duplicate(true)))
	active.action_requested.emit({ "type": "fixture.action", "value": 7 })
	if actions.size() != 1 or str(actions[0].get("type", "")) != "fixture.action" or int(actions[0].get("value", 0)) != 7:
		host.dismiss_modal()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected ModalHost to forward modal action signal with payload-derived value" }
	active.dismiss_requested.emit()
	if host.has_active_modal() or host.visible:
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected dismiss signal to close active modal" }
	_free_modal_host_fixture(fixture)
	return { "ok": true }

static func _t_modal_dismissal_notifies_owner_once() -> Dictionary:
	var app_root_scene := load("res://ui/Approot.tscn") as PackedScene
	var app_root := app_root_scene.instantiate() as Control if app_root_scene != null else null
	if app_root == null:
		return { "ok": false, "error": "Failed to instantiate AppRoot scene" }
	var fixture := _make_in_tree_modal_host_fixture()
	var host := fixture.get("host") as Control
	var shell_a := _TestModalShell.new()
	var shell_b := _TestModalShell.new()
	var scene_a := TestModalFixtureScene
	var scene_b := _make_basic_modal_scene()
	if host == null or not host.is_node_ready():
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected owner-notification test to use a ready in-tree ModalHost" }
	shell_a.scene_by_id[&"first"] = scene_a
	shell_b.scene_by_id[&"first"] = scene_a
	shell_b.scene_by_id[&"second"] = scene_b
	app_root.modal_host = host
	host.connect("modal_dismissed", Callable(app_root, "_on_modal_dismissed"))
	if not bool(app_root.call("_present_shell_modal", &"first", { "value": 1 }, shell_a)):
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected first shell modal request to present" }
	if not bool(app_root.call("_present_shell_modal", &"first", { "value": 2 }, shell_a)):
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected owning shell same-ID request to refresh active modal" }
	if bool(app_root.call("_present_shell_modal", &"first", { "value": 3 }, shell_b)):
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected cross-shell same-ID request to be rejected" }
	if bool(app_root.call("_present_shell_modal", &"second", {}, shell_b)):
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected different-ID request to be rejected while first is active" }
	if host.call("active_modal_id") != &"first":
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected rejected request not to disturb active modal ID" }
	if shell_a.accepted_requests.size() != 2:
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected owner to receive initial and same-ID acceptance callbacks" }
	if int((shell_a.accepted_requests[1].get("payload", {}) as Dictionary).get("value", 0)) != 2:
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected same-ID acceptance to carry refreshed payload" }
	if not shell_b.accepted_requests.is_empty():
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Rejected shell must not receive modal acceptance" }
	host.call("dismiss_modal")
	host.call("dismiss_modal")
	if shell_a.dismissed_ids != [&"first"]:
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected original owner to receive one dismissal, got %s" % str(shell_a.dismissed_ids) }
	if not shell_b.dismissed_ids.is_empty():
		app_root.free()
		shell_a.free()
		shell_b.free()
		_free_modal_host_fixture(fixture)
		return { "ok": false, "error": "Expected rejected/same-ID requester not to replace original owner" }
	app_root.free()
	shell_a.free()
	shell_b.free()
	_free_modal_host_fixture(fixture)
	return { "ok": true }

static func _t_onboarding_boot_safe_frames_and_targets() -> Dictionary:
	var phone_case: Dictionary = ResponsiveHelpers.device_safe_matrix()[1]
	var inverse := Transform2D(Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2.ZERO)
	var layout: Dictionary = LayoutController.calculate_layout(phone_case["size"], phone_case["safe"], phone_case["device"], inverse)
	var scenes: Array[PackedScene] = [
		SaveErrorScene,
		InvocationScene,
		AnansiScene,
		ForgottenNameScene,
		FirstSanctumScene,
		SanctumNamingScene,
		KeeperIntroScene,
	]
	for scene in scenes:
		var result: Dictionary = ResponsiveHelpers.inspect_scene_controls(scene, layout)
		if not bool(result.get("ok", false)):
			return result
	return { "ok": true }

static func _t_onboarding_boot_scroll_and_cta_contract() -> Dictionary:
	var save_scroll: Dictionary = ResponsiveHelpers.assert_scroll_present(SaveErrorScene, NodePath("SafeFrame/ScrollContainer"))
	if not bool(save_scroll.get("ok", false)):
		return save_scroll
	var meeting_scroll: Dictionary = ResponsiveHelpers.assert_scroll_present(ForgottenNameScene, NodePath("SafeFrame/ContentRoot/MeetingRoot/InfoScroll"))
	if not bool(meeting_scroll.get("ok", false)):
		return meeting_scroll
	var meeting_cta: Dictionary = ResponsiveHelpers.assert_button_outside_scroll(ForgottenNameScene, &"MeetingContinue")
	if not bool(meeting_cta.get("ok", false)):
		return meeting_cta
	var keeper_scroll: Dictionary = ResponsiveHelpers.assert_scroll_present(KeeperIntroScene, NodePath("SafeFrame/ContentRoot/NarratorPanel/NarratorMargin/NarratorVBox/BodyScroll"))
	if not bool(keeper_scroll.get("ok", false)):
		return keeper_scroll
	var keeper_cta: Dictionary = ResponsiveHelpers.assert_button_outside_scroll(KeeperIntroScene, &"CtaButton")
	if not bool(keeper_cta.get("ok", false)):
		return keeper_cta
	return { "ok": true }

static func _t_realm_modal_living_tree_contrast_and_buttons() -> Dictionary:
	var fixture_host := _ready_fixture_host()
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for realm modal contrast test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var layout := {
		"profile": &"compact",
		"logical_size": Vector2(960, 540),
		"safe_insets": Vector4.ZERO,
	}
	var cases: Array[Dictionary] = [
		{
			"name": "PrebattleModal",
			"scene": PrebattleModalScene,
			"payload": {
				"layout": layout,
				"objective_label": "Recover the stolen story",
				"intro_line": "The grove holds its breath.",
				"enter_action": { "type": "combat.start" },
				"retreat_action": { "type": "combat.retreat" },
				"retreat_enabled": true,
				"retreat_label": "Retreat",
			},
			"pairs": [
				["SafeFrame/Center/Card/Content/ObjectiveLabel", "SafeFrame/Center/Card"],
				["SafeFrame/Center/Card/Content/IntroLineLabel", "SafeFrame/Center/Card"],
			],
			"primary": ["SafeFrame/Center/Card/Content/ButtonRow/EnterCombatButton"],
			"secondary": ["SafeFrame/Center/Card/Content/ButtonRow/RetreatButton"],
		},
		{
			"name": "EngagementModal",
			"scene": EngagementModalScene,
			"payload": {
				"layout": layout,
				"pending": {
					"revealed": true,
					"is_objective": false,
					"type": "combat",
				},
				"engage_action": { "type": "stage.engage_situation" },
				"ignore_action": { "type": "stage.ignore_situation" },
			},
			"pairs": [
				["SafeFrame/Center/Card/Content/TitleLabel", "SafeFrame/Center/Card"],
				["SafeFrame/Center/Card/Content/BodyLabel", "SafeFrame/Center/Card"],
			],
			"primary": ["SafeFrame/Center/Card/Content/ButtonRow/EnterButton"],
			"secondary": ["SafeFrame/Center/Card/Content/ButtonRow/PassButton"],
		},
		{
			"name": "ContactModal",
			"scene": ContactModalScene,
			"payload": {
				"layout": layout,
				"contact": {
					"name": "Ama",
					"role_label": "Witness",
					"npc_line": "The road remembers every footstep.",
					"fear": 50,
					"morale": 50,
				},
				"data": {
					"contact_responses": [{
						"echo_id": "echo.ama",
						"echo_name": "Akua",
						"calling": "Keeper",
						"emotional_status": "grounded",
						"response_text": "Then let us answer with care.",
					}],
				},
				"actions": {
					"cta.disengage_contact": { "type": "stage.disengage_contact" },
					"cta.speak_response.echo.ama": { "type": "stage.speak_response" },
				},
			},
			"pairs": [
				["SafeFrame/Center/Card/Content/NameLabel", "SafeFrame/Center/Card"],
				["SafeFrame/Center/Card/Content/BodyScroll/Body/NPCZone/NPCZoneContent/LineLabel", "SafeFrame/Center/Card/Content/BodyScroll/Body/NPCZone"],
				["SafeFrame/Center/Card/Content/BodyScroll/Body/Options/OptionCard0/CardContent/EchoNameLabel", "SafeFrame/Center/Card/Content/BodyScroll/Body/Options/OptionCard0"],
				["SafeFrame/Center/Card/Content/BodyScroll/Body/Options/OptionCard0/CardContent/ResponseLabel", "SafeFrame/Center/Card/Content/BodyScroll/Body/Options/OptionCard0"],
			],
			"primary": ["SafeFrame/Center/Card/Content/ButtonRow/ConfirmButton"],
			"secondary": ["SafeFrame/Center/Card/Content/ButtonRow/DisengageButton"],
		},
		{
			"name": "SituationModal",
			"scene": SituationModalScene,
			"payload": {
				"layout": layout,
				"result": {
					"type": "omen",
					"result_text": "The sign settles into memory.",
				},
			},
			"pairs": [
				["SafeFrame/Center/Card/Content/TitleLabel", "SafeFrame/Center/Card"],
				["SafeFrame/Center/Card/Content/BodyLabel", "SafeFrame/Center/Card"],
			],
			"primary": ["SafeFrame/Center/Card/Content/ContinueButton"],
			"secondary": [],
		},
	]
	for case in cases:
		var root := (case["scene"] as PackedScene).instantiate() as Control
		if root == null:
			viewport.free()
			return { "ok": false, "error": "Failed to instantiate %s" % str(case["name"]) }
		root.theme = LivingTreeTheme
		viewport.add_child(root)
		root.call("present", case["payload"])
		_force_control_layout(root)
		for pair_v in case["pairs"]:
			var pair: Array = pair_v
			var label := root.get_node_or_null(NodePath(str(pair[0]))) as Label
			var panel := root.get_node_or_null(NodePath(str(pair[1]))) as PanelContainer
			if label == null or panel == null:
				root.free()
				viewport.free()
				return { "ok": false, "error": "%s contrast fixture path missing: %s" % [str(case["name"]), str(pair)] }
			var ratio := _contrast_ratio(label.get_theme_color("font_color"), _effective_panel_color(panel))
			if ratio < 4.5:
				root.free()
				viewport.free()
				return { "ok": false, "error": "%s %s contrast %.2f is below 4.5:1" % [str(case["name"]), label.name, ratio] }
		for path_v in case["primary"]:
			var button := root.get_node_or_null(NodePath(str(path_v))) as Button
			var failure := _assert_realm_primary_button(button, str(case["name"]))
			if not failure.is_empty():
				root.free()
				viewport.free()
				return { "ok": false, "error": failure }
		for path_v in case["secondary"]:
			var button := root.get_node_or_null(NodePath(str(path_v))) as Button
			var card := root.get_node("SafeFrame/Center/Card") as PanelContainer
			var failure := _assert_realm_secondary_button(button, _effective_panel_color(card), str(case["name"]))
			if not failure.is_empty():
				root.free()
				viewport.free()
				return { "ok": false, "error": failure }
		root.free()
	viewport.free()
	return { "ok": true }

static func _t_blocking_modal_living_tree_cta_styles() -> Dictionary:
	var fixture_host := _ready_fixture_host()
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for blocking modal CTA test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var cases: Array[Dictionary] = [
		{
			"name": "ReturnHomeModal",
			"scene": ReturnHomeModalScene,
			"surface": "SafeFrame/Center/Card",
			"labels": [
				["SafeFrame/Center/Card/Content/TitleLabel", &"RealmModalTitle"],
				["SafeFrame/Center/Card/Content/SubtitleLabel", &"RealmModalMeta"],
				["SafeFrame/Center/Card/Content/BodyLabel", &"RealmModalBody"],
			],
			"buttons": [
				["SafeFrame/Center/Card/Content/ContinueButton", &"RealmModalPrimaryButton"],
			],
		},
		{
			"name": "CallingInfoModal",
			"scene": CallingInfoModalScene,
			"surface": "SafeFrame/Center/Panel",
			"labels": [],
			"buttons": [
				["SafeFrame/Center/Panel/Margin/Root/CallingInfoClose", &"SanctumModalPrimaryButton"],
			],
		},
		{
			"name": "CompanionInviteModal",
			"scene": CompanionInviteModalScene,
			"surface": "SafeFrame/Center/CompanionInviteCard",
			"labels": [],
			"buttons": [
				["SafeFrame/Center/CompanionInviteCard/CompanionInviteMargin/CompanionInviteVBox/CompanionButtonRow/CompanionDeclineButton", &"SanctumModalSecondaryDarkButton"],
				["SafeFrame/Center/CompanionInviteCard/CompanionInviteMargin/CompanionInviteVBox/CompanionButtonRow/CompanionAcceptButton", &"SanctumModalPrimaryButton"],
			],
		},
		{
			"name": "InstitutionDetailModal",
			"scene": InstitutionDetailModalScene,
			"surface": "SafeFrame/Center/Panel",
			"labels": [],
			"buttons": [
				["SafeFrame/Center/Panel/Margin/Stack/BodyScroll/BodyStack/InstDetailOccupantList/OccupantRowTemplate/OccupantRemoveButton", &"SanctumModalSecondaryWarmButton"],
				["SafeFrame/Center/Panel/Margin/Stack/BodyScroll/BodyStack/EchoAssignPicker/PickerMargin/PickerStack/PickerList/PickerRowTemplate", &"SanctumModalSecondaryWarmButton"],
				["SafeFrame/Center/Panel/Margin/Stack/BodyScroll/BodyStack/EchoAssignPicker/PickerMargin/PickerStack/PickerCancelButton", &"SanctumModalSecondaryWarmButton"],
				["SafeFrame/Center/Panel/Margin/Stack/FooterButtons/InstDetailAssignButton", &"SanctumModalPrimaryButton"],
				["SafeFrame/Center/Panel/Margin/Stack/FooterButtons/InstDetailEstablishButton", &"SanctumModalPrimaryButton"],
				["SafeFrame/Center/Panel/Margin/Stack/FooterButtons/InstDetailBackButton", &"SanctumModalSecondaryWarmButton"],
			],
		},
		{
			"name": "VowMomentModal",
			"scene": VowMomentModalScene,
			"surface": "SafeFrame/Center/Panel",
			"labels": [],
			"buttons": [
				["SafeFrame/Center/Panel/Margin/Root/ButtonRow/SecondaryButton", &"SanctumModalSecondaryDarkButton"],
				["SafeFrame/Center/Panel/Margin/Root/ButtonRow/PrimaryButton", &"SanctumModalPrimaryButton"],
			],
		},
		{
			"name": "RankUpOverlay",
			"scene": RankUpOverlayScene,
			"surface": "SafeFrame/Center/Panel",
			"labels": [],
			"buttons": [
				["SafeFrame/Center/Panel/Margin/Root/ConfirmPanel/ButtonRow/CancelButton", &"SanctumModalSecondaryWarmButton"],
				["SafeFrame/Center/Panel/Margin/Root/ConfirmPanel/ButtonRow/ConfirmButton", &"SanctumModalPrimaryButton"],
				["SafeFrame/Center/Panel/Margin/Root/RevealPanel/ContinueButton", &"SanctumModalPrimaryButton"],
				["SafeFrame/Center/Panel/Margin/Root/CallingPanel/ConfirmCallingButton", &"SanctumModalPrimaryButton"],
				["SafeFrame/Center/Panel/Margin/Root/CallingPanel/DeferButton", &"SanctumModalSecondaryWarmButton"],
			],
		},
		{
			"name": "SummonRevealOverlay",
			"scene": SummonRevealOverlayScene,
			"surface": "SafeFrame/Center/Panel",
			"labels": [],
			"buttons": [
				["SafeFrame/Center/Panel/PanelMargin/Root/ButtonRow/NavButtons/PrevButton", &"SanctumModalSecondaryWarmButton"],
				["SafeFrame/Center/Panel/PanelMargin/Root/ButtonRow/NavButtons/NextButton", &"SanctumModalSecondaryWarmButton"],
				["SafeFrame/Center/Panel/PanelMargin/Root/ButtonRow/DismissButton", &"SanctumModalPrimaryButton"],
			],
		},
	]
	for case in cases:
		var root := (case["scene"] as PackedScene).instantiate() as Control
		if root == null:
			viewport.free()
			return { "ok": false, "error": "Failed to instantiate %s" % str(case["name"]) }
		root.theme = LivingTreeTheme
		viewport.add_child(root)
		root.visible = true
		_force_control_layout(root)
		var surface := root.get_node_or_null(NodePath(str(case["surface"]))) as Control
		if surface == null:
			root.free()
			viewport.free()
			return { "ok": false, "error": "%s card surface is missing" % str(case["name"]) }
		var surface_color := _effective_panel_color(surface)
		for label_v in case["labels"]:
			var label_case: Array = label_v
			var label := root.get_node_or_null(NodePath(str(label_case[0]))) as Label
			var expected_variation: StringName = label_case[1]
			if label == null or label.theme_type_variation != expected_variation:
				root.free()
				viewport.free()
				return { "ok": false, "error": "%s label role is unresolved at %s" % [str(case["name"]), str(label_case[0])] }
			var label_ratio := _contrast_ratio(label.get_theme_color("font_color"), surface_color)
			if label_ratio < 4.5:
				root.free()
				viewport.free()
				return { "ok": false, "error": "%s %s contrast %.2f is below 4.5:1" % [str(case["name"]), label.name, label_ratio] }
		for button_v in case["buttons"]:
			var button_case: Array = button_v
			var button := root.get_node_or_null(NodePath(str(button_case[0]))) as Button
			var expected_variation: StringName = button_case[1]
			var failure := _assert_scoped_modal_button(button, expected_variation, surface_color, str(case["name"]))
			if not failure.is_empty():
				root.free()
				viewport.free()
				return { "ok": false, "error": failure }
		root.free()
	viewport.free()
	return { "ok": true }

static func _t_resolve_modal_geometry_compact_and_wide() -> Dictionary:
	var fixture_host := _ready_fixture_host()
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for Resolve geometry test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var resolve := ResolveScene.instantiate() as Control
	if resolve == null:
		viewport.free()
		return { "ok": false, "error": "Failed to instantiate ResolveScreen" }
	resolve.theme = LivingTreeTheme
	viewport.add_child(resolve)
	var breakdown: Array = []
	for i in range(14):
		breakdown.append({
			"label": "Recovered thread %02d" % i,
			"delta": 1 + i,
			"currency": "ase",
		})
	resolve.call("present", {
		"layout": {
			"profile": &"compact",
			"logical_size": Vector2(960, 540),
			"safe_insets": Vector4.ZERO,
		},
		"snapshot": {
			"type": "flow.resolve",
			"meta": { "t": 1 },
			"data": {
				"victory": true,
				"reason": "all_enemies_defeated",
				"summary_line": "The party returns carrying the recovered story.",
				"rank": "A",
				"ase_awarded": 120,
				"enemies_defeated": 7,
				"echoes_survived": 4,
				"round_ended": 8,
				"reward_breakdown": breakdown,
				"emotion_summary": [],
			},
			"actions": {
				"cta.continue": { "type": "flow.go_state", "label": "To Sanctum" },
				"cta.next_stage": { "type": "flow.go_state", "label": "Next Stage" },
			},
		},
	})
	_force_control_layout(resolve)
	var card := resolve.get_node_or_null("%ResultCard") as Control
	var header := resolve.get_node_or_null("%HeaderSection") as VBoxContainer
	var scroll := resolve.get_node_or_null("%ScrollContainer") as ScrollContainer
	var content := resolve.get_node_or_null("%CardContent") as VBoxContainer
	var footer := resolve.get_node_or_null("%ButtonRow") as HBoxContainer
	var footer_surface := resolve.get_node_or_null("%FooterSurface") as PanelContainer
	var primary := resolve.get_node_or_null("%NextStageButton") as Button
	var secondary := resolve.get_node_or_null("%SanctumButton") as Button
	if card == null or header == null or scroll == null or content == null or footer == null or footer_surface == null or primary == null or secondary == null:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve authored card/header/body/footer controls are incomplete" }
	if _is_descendant_of(header, scroll) or _is_descendant_of(footer, scroll):
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve header/footer must remain fixed outside BodyScroll" }
	var compact_card_rect := card.get_global_rect()
	if compact_card_rect.position.x < 16.0 or compact_card_rect.position.y < 16.0 \
			or compact_card_rect.end.x > 944.0 or compact_card_rect.end.y > 524.0:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve compact card escaped the 16-unit safe frame: %s" % str(compact_card_rect) }
	if compact_card_rect.size.x < 660.0 or compact_card_rect.size.x > 700.0:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve compact card width %.1f did not use the available view" % compact_card_rect.size.x }
	if scroll.size.x < compact_card_rect.size.x - 80.0 or content.size.x < scroll.size.x - 24.0:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve compact body collapsed horizontally; card=%.1f scroll=%.1f content=%.1f" % [compact_card_rect.size.x, scroll.size.x, content.size.x] }
	if footer.size.y > 72.0 or primary.size.y > 72.0 or secondary.size.y > 72.0:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve footer button expanded vertically; footer=%.1f primary=%.1f secondary=%.1f" % [footer.size.y, primary.size.y, secondary.size.y] }
	if primary.custom_minimum_size.y < 56.0 or secondary.custom_minimum_size.y < 56.0:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve footer actions are below the 56-unit target" }
	var vbar := scroll.get_v_scroll_bar()
	if vbar == null or vbar.max_value <= vbar.page:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve long compact content does not produce reachable vertical scrolling" }
	var compact_button_height := primary.size.y
	viewport.size = Vector2i(1536, 864)
	resolve.call("set_layout", {
		"profile": &"wide",
		"logical_size": Vector2(1536, 864),
		"safe_insets": Vector4.ZERO,
	})
	_force_control_layout(resolve)
	var wide_card_rect := card.get_global_rect()
	if wide_card_rect.size.x < 820.0 or wide_card_rect.size.x > 860.0:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve wide card did not hold its readable 840-unit cap: %.1f" % wide_card_rect.size.x }
	if wide_card_rect.size.x <= compact_card_rect.size.x or scroll.size.x <= 700.0:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve wide profile did not expose a wider body" }
	if absf(primary.size.y - compact_button_height) > 0.5:
		resolve.free()
		viewport.free()
		return { "ok": false, "error": "Resolve primary action scaled vertically between compact and wide" }
	var primary_failure := _assert_realm_primary_button(primary, "ResolveScreen")
	var secondary_failure := _assert_realm_secondary_button(secondary, _effective_panel_color(footer_surface), "ResolveScreen")
	resolve.free()
	viewport.free()
	if not primary_failure.is_empty():
		return { "ok": false, "error": primary_failure }
	if not secondary_failure.is_empty():
		return { "ok": false, "error": secondary_failure }
	return { "ok": true }

static func _assert_realm_primary_button(button: Button, owner_name: String) -> String:
	if button == null:
		return "%s primary button missing" % owner_name
	if button.theme_type_variation != &"RealmModalPrimaryButton":
		return "%s primary button does not use scoped RealmModalPrimaryButton" % owner_name
	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
	if normal == null or focus == null:
		return "%s primary button styles are unresolved" % owner_name
	if normal.bg_color.a < 0.95:
		return "%s primary button is not a filled gold action" % owner_name
	var normal_ratio := _contrast_ratio(button.get_theme_color("font_color"), normal.bg_color)
	var focus_ratio := _contrast_ratio(button.get_theme_color("font_focus_color"), focus.bg_color)
	if normal_ratio < 4.5 or focus_ratio < 4.5:
		return "%s primary button contrast failed; normal=%.2f focus=%.2f" % [owner_name, normal_ratio, focus_ratio]
	return ""

static func _assert_realm_secondary_button(button: Button, surface: Color, owner_name: String) -> String:
	if button == null:
		return "%s secondary button missing" % owner_name
	if button.theme_type_variation != &"RealmModalSecondaryButton":
		return "%s secondary button does not use scoped RealmModalSecondaryButton" % owner_name
	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	if normal == null:
		return "%s secondary button style is unresolved" % owner_name
	if normal.bg_color.a > 0.15:
		return "%s secondary button incorrectly uses a filled gold surface" % owner_name
	if normal.border_color.a < 0.7:
		return "%s secondary button is missing its gold border" % owner_name
	var composite := _composite_over(normal.bg_color, surface)
	var ratio := _contrast_ratio(button.get_theme_color("font_color"), composite)
	if ratio < 4.5:
		return "%s secondary button contrast %.2f is below 4.5:1" % [owner_name, ratio]
	return ""

static func _assert_scoped_modal_button(
	button: Button,
	expected_variation: StringName,
	surface: Color,
	owner_name: String
) -> String:
	if button == null:
		return "%s CTA is missing" % owner_name
	if button.theme_type_variation != expected_variation:
		return "%s %s uses %s instead of scoped %s" % [
			owner_name,
			button.name,
			str(button.theme_type_variation),
			str(expected_variation),
		]
	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
	if normal == null or focus == null:
		return "%s %s has an unresolved normal or focus style" % [owner_name, button.name]
	var is_primary := expected_variation == &"RealmModalPrimaryButton" or expected_variation == &"SanctumModalPrimaryButton"
	if is_primary:
		if normal.bg_color.a < 0.95 or focus.bg_color.a < 0.95:
			return "%s %s primary action is not filled in normal and focus states" % [owner_name, button.name]
	else:
		if normal.bg_color.a > 0.15 or focus.bg_color.a > 0.2:
			return "%s %s secondary action is too visually filled" % [owner_name, button.name]
		if normal.border_color.a < 0.7 or focus.border_color.a < 0.7:
			return "%s %s secondary action lacks a resolved border" % [owner_name, button.name]
	var normal_surface := _composite_over(normal.bg_color, surface)
	var focus_surface := _composite_over(focus.bg_color, surface)
	var normal_ratio := _contrast_ratio(button.get_theme_color("font_color"), normal_surface)
	var focus_ratio := _contrast_ratio(button.get_theme_color("font_focus_color"), focus_surface)
	if normal_ratio < 4.5 or focus_ratio < 4.5:
		return "%s %s CTA contrast failed; normal=%.2f focus=%.2f" % [
			owner_name,
			button.name,
			normal_ratio,
			focus_ratio,
		]
	return ""

static func _make_in_tree_modal_host_fixture() -> Dictionary:
	var fixture_host := _ready_fixture_host()
	if fixture_host == null:
		return {}
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var surface := Control.new()
	surface.name = "ModalTestSurface"
	surface.set_position(Vector2.ZERO)
	surface.set_size(Vector2(960, 540))
	viewport.add_child(surface)
	var underlying := Button.new()
	underlying.name = "UnderlyingButton"
	underlying.focus_mode = Control.FOCUS_ALL
	underlying.mouse_filter = Control.MOUSE_FILTER_STOP
	underlying.text = "Underlying"
	underlying.set_position(Vector2(24, 24))
	underlying.set_size(Vector2(160, 56))
	surface.add_child(underlying)
	var input_probe := _UnhandledInputProbe.new()
	input_probe.name = "UnderlyingInputProbe"
	surface.add_child(input_probe)
	var host := ModalHostScene.instantiate() as Control
	if host == null:
		viewport.free()
		return {}
	host.theme = LivingTreeTheme
	surface.add_child(host)
	_force_control_layout(surface)
	return {
		"viewport": viewport,
		"surface": surface,
		"underlying": underlying,
		"input_probe": input_probe,
		"host": host,
	}

static func _free_modal_host_fixture(fixture: Dictionary) -> void:
	var viewport := fixture.get("viewport") as SubViewport
	if viewport != null and is_instance_valid(viewport):
		viewport.free()

static func _ready_fixture_host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("UISnapshotRenderer")

static func _force_control_layout(root: Node) -> void:
	for _pass_index in range(4):
		root.propagate_notification(Control.NOTIFICATION_RESIZED)
		root.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)

static func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	if node == null or ancestor == null:
		return false
	var current := node.get_parent()
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false

static func _effective_panel_color(panel: Control) -> Color:
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return Color.TRANSPARENT
	var modulate := panel.self_modulate
	return Color(
		style.bg_color.r * modulate.r,
		style.bg_color.g * modulate.g,
		style.bg_color.b * modulate.b,
		style.bg_color.a * modulate.a
	)

static func _composite_over(foreground: Color, background: Color) -> Color:
	var alpha := foreground.a + background.a * (1.0 - foreground.a)
	if alpha <= 0.0:
		return Color.TRANSPARENT
	return Color(
		(foreground.r * foreground.a + background.r * background.a * (1.0 - foreground.a)) / alpha,
		(foreground.g * foreground.a + background.g * background.a * (1.0 - foreground.a)) / alpha,
		(foreground.b * foreground.a + background.b * background.a * (1.0 - foreground.a)) / alpha,
		alpha
	)

static func _contrast_ratio(a: Color, b: Color) -> float:
	var lighter := maxf(_relative_luminance(a), _relative_luminance(b))
	var darker := minf(_relative_luminance(a), _relative_luminance(b))
	return (lighter + 0.05) / (darker + 0.05)

static func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) + 0.7152 * _linear_channel(color.g) + 0.0722 * _linear_channel(color.b)

static func _linear_channel(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)

static func _make_basic_modal_scene() -> PackedScene:
	var root := Control.new()
	root.name = "TestModal"
	root.focus_mode = Control.FOCUS_ALL
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed

class _TestModalShell:
	extends Control

	var scene_by_id: Dictionary = {}
	var dismissed_ids: Array = []
	var accepted_requests: Array = []

	func modal_scene_for(modal_id: StringName) -> PackedScene:
		var scene_v: Variant = scene_by_id.get(modal_id, null)
		return scene_v if scene_v is PackedScene else null

	func on_modal_accepted(modal_id: StringName, payload: Dictionary) -> void:
		accepted_requests.append({
			"id": modal_id,
			"payload": payload.duplicate(true),
		})

	func on_modal_dismissed(modal_id: StringName) -> void:
		dismissed_ids.append(modal_id)

class _UnhandledInputProbe:
	extends Node

	var action_count: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventAction and (event as InputEventAction).pressed:
			action_count += 1
