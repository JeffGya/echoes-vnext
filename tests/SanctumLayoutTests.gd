extends RefCounted
class_name SanctumLayoutTests

const SanctumShellScene := preload("res://ui/shells/SanctumShell.tscn")
const SanctumScreenScene := preload("res://ui/screens/sanctum/SanctumScreen.tscn")
const SummonScreenScene := preload("res://ui/screens/sanctum/SummonScreen.tscn")
const EchoPartyScreenScene := preload("res://ui/screens/sanctum/EchoPartyScreen.tscn")
const RealmSelectScreenScene := preload("res://ui/screens/realm/RealmSelectScreen.tscn")
const VowScreenScene := preload("res://ui/screens/sanctum/VowScreen.tscn")
const WeavingScreenScene := preload("res://ui/screens/sanctum/WeavingRiteScreen.tscn")
const SummonRevealScene := preload("res://ui/overlays/SummonRevealOverlay.tscn")
const RankUpScene := preload("res://ui/overlays/RankUpOverlay.tscn")
const AwakeningScene := preload("res://ui/overlays/sanctum/AwakeningModal.tscn")
const CompanionScene := preload("res://ui/overlays/sanctum/CompanionInviteModal.tscn")
const VowMomentScene := preload("res://ui/overlays/sanctum/VowMomentModal.tscn")
const InstitutionScene := preload("res://ui/overlays/sanctum/InstitutionDetailModal.tscn")
const CallingInfoScene := preload("res://ui/overlays/sanctum/CallingInfoModal.tscn")
const ModalHostScene := preload("res://ui/components/ModalHost.tscn")
const ReturnHomeModalScene := preload("res://ui/overlays/realm/ReturnHomeModal.tscn")

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("sanctum.layout/ase_flame_always_in_layout",        Callable(SanctumLayoutTests, "_t_ase_flame_in_layout"))
	runner.register_test("sanctum.layout/ase_flame_always_in_occupants",      Callable(SanctumLayoutTests, "_t_ase_flame_in_occupants"))
	runner.register_test("sanctum.layout/institution_tile_after_establish",   Callable(SanctumLayoutTests, "_t_institution_tile_after_establish"))
	runner.register_test("sanctum.layout/all_echoes_placed_as_occupants",     Callable(SanctumLayoutTests, "_t_all_echoes_placed"))
	runner.register_test("sanctum.layout/echo_occupant_has_emotional_status", Callable(SanctumLayoutTests, "_t_echo_has_emotional_status"))
	runner.register_test("sanctum.layout/echo_near_placed_institution",       Callable(SanctumLayoutTests, "_t_echo_near_institution"))
	runner.register_test("sanctum.layout/valid_cells_exclude_occupied",       Callable(SanctumLayoutTests, "_t_valid_cells_exclude_occupied"))
	runner.register_test("sanctum.layout/valid_cells_not_in_exclusion",       Callable(SanctumLayoutTests, "_t_valid_cells_not_in_exclusion"))
	# check_placement_validity_from_data — one test per rule
	runner.register_test("sanctum.layout/validity_already_occupied",          Callable(SanctumLayoutTests, "_t_validity_already_occupied"))
	runner.register_test("sanctum.layout/validity_already_floor",             Callable(SanctumLayoutTests, "_t_validity_already_floor"))
	runner.register_test("sanctum.layout/validity_exclusion_zone",            Callable(SanctumLayoutTests, "_t_validity_exclusion_zone"))
	runner.register_test("sanctum.layout/validity_far_cell_is_valid",         Callable(SanctumLayoutTests, "_t_validity_far_cell_is_valid"))
	runner.register_test("sanctum.layout/validity_valid_cell",                Callable(SanctumLayoutTests, "_t_validity_valid_cell"))
	# get_bridge_preview_from_floor
	runner.register_test("sanctum.layout/bridge_preview_returns_cells",       Callable(SanctumLayoutTests, "_t_bridge_preview_returns_cells"))
	runner.register_test("sanctum.layout/bridge_preview_adjacent_is_empty",   Callable(SanctumLayoutTests, "_t_bridge_preview_adjacent_is_empty"))
	runner.register_test("sanctum.layout/shell_layers_and_rail_exclusion",    Callable(SanctumLayoutTests, "_t_shell_layers_and_rail_exclusion"))
	runner.register_test("sanctum.layout/modal_tracking_clear_blocks_resize", Callable(SanctumLayoutTests, "_t_modal_tracking_clear_blocks_resize"))
	runner.register_test("sanctum.layout/modal_dismiss_blocks_resize_reopen", Callable(SanctumLayoutTests, "_t_modal_dismiss_blocks_resize_reopen"))
	runner.register_test("sanctum.layout/hidden_shell_resize_no_modal_replay", Callable(SanctumLayoutTests, "_t_hidden_shell_resize_no_modal_replay"))
	runner.register_test("sanctum.layout/modal_ids_route_through_shell",      Callable(SanctumLayoutTests, "_t_modal_ids_route_through_shell"))
	runner.register_test("sanctum.layout/modal_safe_frames_authored",         Callable(SanctumLayoutTests, "_t_modal_safe_frames_authored"))
	runner.register_test("sanctum.layout/modal_safe_frames_apply_insets",     Callable(SanctumLayoutTests, "_t_modal_safe_frames_apply_insets"))
	runner.register_test("sanctum.layout/modal_content_geometry_and_identity", Callable(SanctumLayoutTests, "_t_modal_content_geometry_and_identity"))
	runner.register_test("sanctum.layout/companion_modal_fixed_footer",       Callable(SanctumLayoutTests, "_t_companion_modal_fixed_footer"))
	runner.register_test("sanctum.layout/rank_up_calling_fixed_footer",       Callable(SanctumLayoutTests, "_t_rank_up_calling_fixed_footer"))
	runner.register_test("sanctum.layout/all_interactive_targets_minimum",    Callable(SanctumLayoutTests, "_t_all_interactive_targets_minimum"))
	runner.register_test("sanctum.layout/profile_driven_composition",         Callable(SanctumLayoutTests, "_t_profile_driven_composition"))
	runner.register_test("sanctum.layout/overview_header_drives_body_geometry", Callable(SanctumLayoutTests, "_t_overview_header_drives_body_geometry"))
	runner.register_test("sanctum.layout/weaving_compact_scroll_geometry",    Callable(SanctumLayoutTests, "_t_weaving_compact_scroll_geometry"))
	runner.register_test("sanctum.layout/sanctum_rail_target_minima",         Callable(SanctumLayoutTests, "_t_sanctum_rail_target_minima"))
	runner.register_test("sanctum.layout/sanctum_rail_width_caps",            Callable(SanctumLayoutTests, "_t_sanctum_rail_width_caps"))
	runner.register_test("sanctum.layout/return_notice_does_not_block_rail",   Callable(SanctumLayoutTests, "_t_return_notice_does_not_block_rail"))
	runner.register_test("sanctum.layout/ancestor_hide_disables_shell_layers", Callable(SanctumLayoutTests, "_t_ancestor_hide_disables_shell_layers"))
	runner.register_test("sanctum.layout/notification_compact_safe_scroll",    Callable(SanctumLayoutTests, "_t_notification_compact_safe_scroll"))


static func _make_save(roster: Array = [], institutions: Dictionary = {}) -> Dictionary:
	var save := SaveSchema.make_new_save(42, "test")
	save["sanctum"]["roster"] = roster
	for iid in institutions:
		save["sanctum"]["institutions"][iid] = institutions[iid]
	return save


static func _make_echo(id_str: String, morale: int = 50) -> Dictionary:
	return {
		"id":     id_str,
		"name":   id_str,
		"rank":   1,
		"level":  1,
		"xp_total": 0,
		"emotion": { "morale_current": morale, "fear_current": 0 },
	}

static func _t_shell_layers_and_rail_exclusion() -> Dictionary:
	var shell := SanctumShellScene.instantiate()
	var world_layer := shell.get_node_or_null("WorldLayer") as CanvasLayer
	var ui_layer := shell.get_node_or_null("UILayer") as CanvasLayer
	var chrome_layer := shell.get_node_or_null("ChromeLayer") as CanvasLayer
	var notification_layer := shell.get_node_or_null("NotificationLayer") as CanvasLayer
	var spatial_layer := shell.get_node_or_null("WorldLayer/SpatialLayer") as Control
	var chrome_control := shell.get_node_or_null("ChromeLayer/ChromeControl") as Control
	if world_layer == null or world_layer.layer != 0:
		shell.free()
		return { "ok": false, "error": "Expected Sanctum WorldLayer layer 0" }
	if shell.get_node_or_null("WorldLayer/SpatialLayer") == null:
		shell.free()
		return { "ok": false, "error": "Expected Sanctum spatial presentation under WorldLayer" }
	if ui_layer == null or ui_layer.layer != 10:
		shell.free()
		return { "ok": false, "error": "Expected Sanctum UILayer layer 10" }
	if chrome_layer == null or chrome_layer.layer != 20:
		shell.free()
		return { "ok": false, "error": "Expected Sanctum ChromeLayer layer 20" }
	if notification_layer == null or notification_layer.layer != 30:
		shell.free()
		return { "ok": false, "error": "Expected Sanctum NotificationLayer layer 30" }
	if spatial_layer == null or spatial_layer.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		shell.free()
		return { "ok": false, "error": "Sanctum spatial presentation must not swallow UI pointer input" }
	if chrome_control == null or chrome_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		shell.free()
		return { "ok": false, "error": "Sanctum full-screen chrome root must ignore pointer input" }
	shell.call("set_layout", { "safe_insets": Vector4(3, 5, 7, 11), "profile": &"standard" })
	var exclusion := int(shell.call("bottom_content_exclusion"))
	if exclusion != 112:
		shell.free()
		return { "ok": false, "error": "Expected minimum bottom inset 16 + rail 88 + gap 8 = 112, got %d" % exclusion }
	var button := Button.new()
	var label := Label.new()
	if not bool(shell.call("_control_or_ancestor_is_interactive", button)):
		button.free()
		label.free()
		shell.free()
		return { "ok": false, "error": "Sanctum input arbitration does not protect button clicks from spatial input" }
	if bool(shell.call("_control_or_ancestor_is_interactive", label)):
		button.free()
		label.free()
		shell.free()
		return { "ok": false, "error": "Sanctum input arbitration treats noninteractive labels as actions" }
	button.free()
	label.free()
	shell.free()
	return { "ok": true }

static func _t_modal_tracking_clear_blocks_resize() -> Dictionary:
	var shell := SanctumShellScene.instantiate()
	var emitted: Array = []
	shell.connect("modal_requested", func(modal_id: StringName, payload: Dictionary) -> void:
		emitted.append({ "id": modal_id, "payload": payload })
	)
	shell.call("_on_overlay_modal_requested", &"awakening", { "awakening_grant": 40 })
	if emitted.size() != 1:
		shell.free()
		return { "ok": false, "error": "Expected initial modal request" }
	shell.call("on_modal_accepted", &"awakening", emitted[0].get("payload", {}))
	shell.call("_on_overlay_modal_requested", &"", {})
	shell.call("set_layout", { "safe_insets": Vector4(0, 0, 0, 24), "profile": &"compact" })
	if emitted.size() != 1:
		shell.free()
		return { "ok": false, "error": "Resize re-emitted stale modal after clear" }
	shell.free()
	return { "ok": true }

static func _t_modal_dismiss_blocks_resize_reopen() -> Dictionary:
	var shell := SanctumShellScene.instantiate()
	var emitted: Array = []
	shell.connect("modal_requested", func(modal_id: StringName, payload: Dictionary) -> void:
		emitted.append({ "id": modal_id, "payload": payload })
	)
	shell.call("_on_overlay_modal_requested", &"companion_invite", { "invite": { "ally_name": "Akua" } })
	if emitted.size() != 1:
		shell.free()
		return { "ok": false, "error": "Expected initial companion modal request" }
	shell.call("on_modal_accepted", &"companion_invite", emitted[0].get("payload", {}))
	shell.call("on_modal_dismissed", &"rank_up")
	shell.call("set_layout", { "safe_insets": Vector4(0, 0, 0, 12), "profile": &"compact" })
	if emitted.size() != 2:
		shell.free()
		return { "ok": false, "error": "Mismatched dismiss should not clear active modal" }
	shell.call("on_modal_accepted", &"companion_invite", emitted[1].get("payload", {}))
	shell.call("on_modal_dismissed", &"companion_invite")
	shell.call("set_layout", { "safe_insets": Vector4(0, 0, 0, 24), "profile": &"compact" })
	if emitted.size() != 2:
		shell.free()
		return { "ok": false, "error": "Resize re-emitted stale modal after ModalHost dismissal" }
	shell.free()
	return { "ok": true }

static func _t_hidden_shell_resize_no_modal_replay() -> Dictionary:
	var shell := SanctumShellScene.instantiate()
	var emitted: Array = []
	shell.connect("modal_requested", func(modal_id: StringName, payload: Dictionary) -> void:
		emitted.append({ "id": modal_id, "payload": payload })
	)
	shell.call("_on_overlay_modal_requested", &"awakening", { "awakening_grant": 40 })
	if emitted.size() != 1:
		shell.free()
		return { "ok": false, "error": "Expected visible shell to request initial modal" }
	shell.call("on_modal_accepted", &"awakening", emitted[0].get("payload", {}))
	shell.visible = false
	shell.call("set_layout", { "safe_insets": Vector4.ZERO, "profile": &"wide", "logical_size": Vector2(1920, 1080) })
	if emitted.size() != 1:
		shell.free()
		return { "ok": false, "error": "Hidden shell resize replayed cached modal" }
	shell.visible = true
	shell.call("set_layout", { "safe_insets": Vector4.ZERO, "profile": &"wide", "logical_size": Vector2(1920, 1080) })
	if emitted.size() != 2:
		shell.free()
		return { "ok": false, "error": "Visible active shell resize did not refresh cached modal" }
	shell.free()
	return { "ok": true }

static func _t_modal_ids_route_through_shell() -> Dictionary:
	var shell := SanctumShellScene.instantiate()
	for modal_id in [&"summon_reveal", &"rank_up", &"awakening", &"companion_invite", &"vow_moment", &"institution_detail", &"calling_info"]:
		var scene: Variant = shell.call("modal_scene_for", modal_id)
		if not (scene is PackedScene):
			shell.free()
			return { "ok": false, "error": "Missing shell modal scene for %s" % str(modal_id) }
	shell.free()
	return { "ok": true }

static func _t_modal_safe_frames_authored() -> Dictionary:
	var scenes := [SummonRevealScene, RankUpScene, AwakeningScene, CompanionScene, VowMomentScene, InstitutionScene, CallingInfoScene]
	for scene: PackedScene in scenes:
		var modal := scene.instantiate()
		var safe := modal.get_node_or_null("SafeFrame") as MarginContainer
		if safe == null:
			var path := modal.scene_file_path
			modal.free()
			return { "ok": false, "error": "Missing authored SafeFrame in %s" % path }
		modal.free()
	return { "ok": true }

static func _t_modal_safe_frames_apply_insets() -> Dictionary:
	var scenes := [SummonRevealScene, RankUpScene, AwakeningScene, CompanionScene, VowMomentScene, InstitutionScene, CallingInfoScene]
	for scene: PackedScene in scenes:
		var modal := _instantiate_in_tree(scene)
		var safe := modal.get_node_or_null("SafeFrame") as MarginContainer
		if safe == null or not safe.has_method("set_layout"):
			var missing_path := modal.scene_file_path
			_free_tree_node(modal)
			return { "ok": false, "error": "SafeFrame lacks SafeAreaContainer script in %s" % missing_path }
		modal.call("set_layout", { "safe_insets": Vector4(5, 20, 24, 13), "profile": &"compact" })
		var left := safe.get_theme_constant("margin_left")
		var top := safe.get_theme_constant("margin_top")
		var right := safe.get_theme_constant("margin_right")
		var bottom := safe.get_theme_constant("margin_bottom")
		var modal_path := modal.scene_file_path
		_free_tree_node(modal)
		if left != 16 or top != 20 or right != 24 or bottom != 16:
			return { "ok": false, "error": "%s SafeFrame margins were %d,%d,%d,%d" % [modal_path, left, top, right, bottom] }
	return { "ok": true }

static func _t_modal_content_geometry_and_identity() -> Dictionary:
	var summon := SummonRevealScene.instantiate()
	var summon_panel := summon.find_child("Panel", true, false) as PanelContainer
	var summon_scroll := summon.find_child("CardScroll", true, false) as ScrollContainer
	var summon_title := summon.find_child("TitleLabel", true, false) as Label
	if summon_panel == null or summon_panel.custom_minimum_size.x < 560.0:
		summon.free()
		return { "ok": false, "error": "Summon reveal card lacks authored 560-unit width" }
	if summon_scroll == null or summon_scroll.custom_minimum_size.y < 240.0:
		summon.free()
		return { "ok": false, "error": "Summon reveal body lacks authored compact scroll height" }
	if summon_panel.theme_type_variation != &"SanctumNoticePositive" \
			or summon_title == null or summon_title.theme_type_variation != &"SanctumDetailTitle":
		summon.free()
		return { "ok": false, "error": "Summon reveal lost its positive Living Tree card identity" }
	summon.free()

	var body_scroll_specs := [
		{ "scene": AwakeningScene, "node": "AwakeningBodyScroll" },
		{ "scene": CompanionScene, "node": "CompanionInviteScroll" },
		{ "scene": RankUpScene, "node": "CallingOptionsScroll" },
		{ "scene": CallingInfoScene, "node": "BodyScroll" },
		{ "scene": VowMomentScene, "node": "BodyScroll" },
		{ "scene": InstitutionScene, "node": "BodyScroll" },
	]
	for spec_v in body_scroll_specs:
		var spec: Dictionary = spec_v
		var modal := (spec.get("scene") as PackedScene).instantiate()
		var scroll := modal.find_child(str(spec.get("node", "")), true, false) as ScrollContainer
		var modal_path := modal.scene_file_path
		if scroll == null or scroll.custom_minimum_size.y <= 0.0:
			modal.free()
			return { "ok": false, "error": "%s lacks a nonzero authored modal body minimum" % modal_path }
		modal.free()

	var rank_up := RankUpScene.instantiate()
	var rank_card := rank_up.find_child("Panel", true, false) as PanelContainer
	var rank_name := rank_up.find_child("RevealName", true, false) as Label
	if rank_card == null or rank_card.theme_type_variation != &"SanctumCard" \
			or rank_name == null or rank_name.theme_type_variation != &"SanctumDetailTitle":
		rank_up.free()
		return { "ok": false, "error": "Rank-up modal lost its warm gold Living Tree identity" }
	rank_up.free()

	var awakening := AwakeningScene.instantiate()
	var awakening_card := awakening.find_child("InnerPanel", true, false) as PanelContainer
	var awakening_body := awakening.find_child("AwakeningBody", true, false) as Label
	if awakening_card == null or awakening_card.theme_type_variation != &"SanctumHeaderCard" \
			or awakening_body == null or awakening_body.theme_type_variation != &"SanctumHeaderText":
		awakening.free()
		return { "ok": false, "error": "Awakening modal lost its dark forest and gold identity" }
	awakening.free()

	var companion := CompanionScene.instantiate()
	var companion_card := companion.find_child("CompanionInviteCard", true, false) as PanelContainer
	var companion_title := companion.find_child("CompanionNameLabel", true, false) as Label
	if companion_card == null or not companion_card.has_theme_stylebox_override("panel") \
			or companion_title == null or companion_title.theme_type_variation != &"SanctumHeaderTitle":
		companion.free()
		return { "ok": false, "error": "Companion modal lost its authored Mist Blue card identity" }
	companion.free()

	var calling := CallingInfoScene.instantiate()
	var calling_card := calling.find_child("Panel", true, false) as PanelContainer
	var calling_title := calling.find_child("CallingInfoTitle", true, false) as Label
	var calling_close := calling.find_child("CallingInfoClose", true, false) as Button
	if calling_card == null or calling_card.theme_type_variation != &"SanctumDetailPanel" \
			or calling_title == null or calling_title.theme_type_variation != &"SanctumDetailTitle":
		calling.free()
		return { "ok": false, "error": "Calling information modal lost its light detail identity" }
	if calling_close == null or calling_close.text != "Close":
		calling.free()
		return { "ok": false, "error": "Calling close copy changed" }
	calling.free()

	var institution := InstitutionScene.instantiate()
	var institution_card := institution.find_child("Panel", true, false) as PanelContainer
	var institution_title := institution.find_child("InstDetailName", true, false) as Label
	if institution_card == null or institution_card.theme_type_variation != &"SanctumDetailPanel" \
			or institution_title == null or institution_title.theme_type_variation != &"SanctumDetailTitle":
		institution.free()
		return { "ok": false, "error": "Institution modal lost its light management identity" }
	institution.free()

	var vow := VowMomentScene.instantiate()
	var vow_card := vow.find_child("Panel", true, false) as PanelContainer
	var vow_title := vow.find_child("TitleLabel", true, false) as Label
	var vow_secondary := vow.find_child("SecondaryButton", true, false) as Button
	var vow_primary := vow.find_child("PrimaryButton", true, false) as Button
	if vow_card == null or vow_card.theme_type_variation != &"SanctumHeaderCard" \
			or vow_title == null or vow_title.theme_type_variation != &"SanctumHeaderTitle":
		vow.free()
		return { "ok": false, "error": "Vow modal lost its dark sacred identity" }
	if vow_title.text != "The web remembers." or vow_secondary == null or vow_secondary.text != "Keep My Word" \
			or vow_primary == null or vow_primary.text != "Continue":
		vow.free()
		return { "ok": false, "error": "Vow modal authored copy changed" }
	if vow.find_child("BreakWarningLabel", true, false) != null:
		vow.free()
		return { "ok": false, "error": "Vow modal contains unapproved added copy" }
	vow.free()
	return { "ok": true }


static func _t_companion_modal_fixed_footer() -> Dictionary:
	var modal := CompanionScene.instantiate()
	var scroll := modal.find_child("CompanionInviteScroll", true, false) as ScrollContainer
	var accept := modal.find_child("CompanionAcceptButton", true, false) as Button
	var decline := modal.find_child("CompanionDeclineButton", true, false) as Button
	if scroll == null or accept == null or decline == null:
		modal.free()
		return { "ok": false, "error": "Companion modal missing scroll or footer buttons" }
	if scroll.custom_minimum_size.y < 120.0:
		modal.free()
		return { "ok": false, "error": "Companion body scroll lacks authored compact bound" }
	if _is_descendant_of(accept, scroll) or _is_descendant_of(decline, scroll):
		modal.free()
		return { "ok": false, "error": "Companion CTA is inside scroll body" }
	if modal.has_method("_clamp_card_height"):
		modal.free()
		return { "ok": false, "error": "Companion modal still has runtime height clamp" }
	modal.free()
	return { "ok": true }

static func _t_rank_up_calling_fixed_footer() -> Dictionary:
	var modal := RankUpScene.instantiate()
	var scroll := modal.find_child("CallingOptionsScroll", true, false) as ScrollContainer
	var options := modal.find_child("CallingOptionsContainer", true, false) as VBoxContainer
	var confirm := modal.find_child("ConfirmCallingButton", true, false) as Button
	var defer := modal.find_child("DeferButton", true, false) as Button
	if scroll == null or options == null or confirm == null or defer == null:
		modal.free()
		return { "ok": false, "error": "RankUp calling modal missing scroll/options/footer nodes" }
	if not _is_descendant_of(options, scroll):
		modal.free()
		return { "ok": false, "error": "Calling options are not inside authored scroll body" }
	if _is_descendant_of(confirm, scroll) or _is_descendant_of(defer, scroll):
		modal.free()
		return { "ok": false, "error": "RankUp calling CTA is inside scroll body" }
	if scroll.custom_minimum_size.y < 180.0:
		modal.free()
		return { "ok": false, "error": "RankUp calling scroll lacks authored compact bound" }
	modal.free()
	return { "ok": true }

static func _t_sanctum_rail_target_minima() -> Dictionary:
	var shell := SanctumShellScene.instantiate()
	var rail := shell.get_node_or_null("ChromeLayer/ChromeControl/BottomRail") as Control
	if rail == null or rail.custom_minimum_size.y < 88.0:
		shell.free()
		return { "ok": false, "error": "Expected rail min height >= 88" }
	for button_name in ["PartyButton", "SummonButton", "RealmButton", "VowsButton", "WeavingButton"]:
		var button := shell.find_child(button_name, true, false) as Button
		if button == null or button.custom_minimum_size.y < 56.0:
			shell.free()
			return { "ok": false, "error": "Expected %s primary rail target >= 56 high" % button_name }
	shell.free()
	return { "ok": true }

static func _t_sanctum_rail_width_caps() -> Dictionary:
	var shell := _instantiate_shell_with_rail_binding()
	var rail := shell.get_node_or_null("ChromeLayer/ChromeControl/BottomRail") as Control
	if rail == null:
		_free_tree_node(shell)
		return { "ok": false, "error": "Missing Sanctum BottomRail" }

	shell.call("set_layout", { "safe_insets": Vector4.ZERO, "profile": &"compact", "logical_size": Vector2(960, 540) })
	var compact_width := rail.offset_right - rail.offset_left
	if not is_equal_approx(compact_width, 928.0):
		_free_tree_node(shell)
		return { "ok": false, "error": "Expected compact rail width 928, got %.1f" % compact_width }
	if not is_equal_approx(rail.offset_left, 16.0):
		_free_tree_node(shell)
		return { "ok": false, "error": "Expected compact rail left 16, got %.1f" % rail.offset_left }
	if not is_equal_approx(rail.offset_bottom, -16.0) or not is_equal_approx(rail.offset_top, -104.0):
		_free_tree_node(shell)
		return { "ok": false, "error": "Desktop rail must retain a 16-unit bottom edge inset" }

	shell.call("set_layout", { "safe_insets": Vector4.ZERO, "profile": &"wide", "logical_size": Vector2(1920, 1080) })
	var wide_width := rail.offset_right - rail.offset_left
	if not is_equal_approx(wide_width, 980.0):
		_free_tree_node(shell)
		return { "ok": false, "error": "Expected wide rail cap 980, got %.1f" % wide_width }
	if not is_equal_approx(rail.offset_left, 470.0):
		_free_tree_node(shell)
		return { "ok": false, "error": "Expected wide centered rail left 470, got %.1f" % rail.offset_left }

	shell.call("set_layout", { "safe_insets": Vector4(12, 0, 20, 30), "profile": &"wide", "logical_size": Vector2(3440, 1440) })
	var ultra_width := rail.offset_right - rail.offset_left
	if not is_equal_approx(ultra_width, 980.0):
		_free_tree_node(shell)
		return { "ok": false, "error": "Expected ultrawide rail cap 980, got %.1f" % ultra_width }
	if rail.offset_left < 28.0 or rail.offset_right > 3420.0:
		_free_tree_node(shell)
		return { "ok": false, "error": "Ultrawide rail ignored safe side insets" }
	if not is_equal_approx(rail.offset_bottom, -30.0) or not is_equal_approx(rail.offset_top, -118.0):
		_free_tree_node(shell)
		return { "ok": false, "error": "Ultrawide rail ignored bottom safe reservation" }
	_free_tree_node(shell)
	return { "ok": true }

static func _t_all_interactive_targets_minimum() -> Dictionary:
	var scenes := [
		SanctumScreenScene, SummonScreenScene, EchoPartyScreenScene, RealmSelectScreenScene,
		VowScreenScene, WeavingScreenScene, SanctumShellScene, SummonRevealScene, RankUpScene,
		AwakeningScene, CompanionScene, VowMomentScene, InstitutionScene, CallingInfoScene,
	]
	for scene: PackedScene in scenes:
		var root := _instantiate_in_tree(scene)
		var failure := _check_interactive_targets(root)
		var path := root.scene_file_path
		_free_tree_node(root)
		if not failure.is_empty():
			return { "ok": false, "error": "%s: %s" % [path, failure] }
	return { "ok": true }

static func _t_profile_driven_composition() -> Dictionary:
	var compact_layout := { "profile": &"compact", "safe_insets": Vector4.ZERO, "logical_size": Vector2(960, 540) }
	var standard_layout := { "profile": &"standard", "safe_insets": Vector4.ZERO, "logical_size": Vector2(1280, 720) }
	var wide_layout := { "profile": &"wide", "safe_insets": Vector4.ZERO, "logical_size": Vector2(1920, 1080) }
	var echo_party := _instantiate_in_tree(EchoPartyScreenScene)
	echo_party.call("set_layout", compact_layout)
	if (echo_party.find_child("ThreePanelRow", true, false) as GridContainer).columns != 1:
		_free_tree_node(echo_party)
		return { "ok": false, "error": "EchoParty compact must use one column" }
	echo_party.call("set_layout", wide_layout)
	if (echo_party.find_child("ThreePanelRow", true, false) as GridContainer).columns != 3:
		_free_tree_node(echo_party)
		return { "ok": false, "error": "EchoParty wide must restore three columns" }
	var echo_root := echo_party.find_child("RootVBox", true, false) as VBoxContainer
	if echo_root == null or echo_root.anchor_right != 1.0 or echo_root.anchor_bottom != 1.0 \
			or echo_root.offset_right != -16.0 or echo_root.offset_bottom != -16.0:
		_free_tree_node(echo_party)
		return { "ok": false, "error": "EchoParty content does not fill and center within its responsive capped root" }
	var echo_width: float = 1920.0 + echo_party.offset_right - echo_party.offset_left
	_free_tree_node(echo_party)

	var weaving := _instantiate_in_tree(WeavingScreenScene)
	weaving.call("set_layout", compact_layout)
	if (weaving.find_child("ContentArea", true, false) as GridContainer).columns != 1:
		_free_tree_node(weaving)
		return { "ok": false, "error": "Weaving compact must use one content column" }
	if (weaving.find_child("ThreadCardGrid", true, false) as GridContainer).columns != 3:
		_free_tree_node(weaving)
		return { "ok": false, "error": "Weaving compact landscape must retain three thread columns" }
	var compact_weaving_width: float = 960.0 + weaving.offset_right - weaving.offset_left
	weaving.call("set_layout", standard_layout)
	if (weaving.find_child("ContentArea", true, false) as GridContainer).columns != 2:
		_free_tree_node(weaving)
		return { "ok": false, "error": "Weaving standard must use two content columns" }
	var standard_weaving_width: float = 1280.0 + weaving.offset_right - weaving.offset_left
	weaving.call("set_layout", wide_layout)
	if (weaving.find_child("ContentArea", true, false) as GridContainer).columns != 2:
		_free_tree_node(weaving)
		return { "ok": false, "error": "Weaving wide must use two content columns" }
	var weaving_width: float = 1920.0 + weaving.offset_right - weaving.offset_left
	weaving.set("_last_snapshot", { "data": { "phase": "aftermath" } })
	weaving.call("set_layout", wide_layout)
	if (weaving.find_child("ContentArea", true, false) as GridContainer).columns != 1:
		_free_tree_node(weaving)
		return { "ok": false, "error": "Weaving single-panel phases must span the full content width" }
	var content_area := weaving.find_child("ContentArea", true, false) as GridContainer
	var thread_panel := weaving.find_child("ThreadPanel", true, false) as Control
	var echo_panel := weaving.find_child("EchoPanel", true, false) as Control
	var resolution_panel := weaving.find_child("ResolutionPanel", true, false) as Control
	var thread_card := weaving.find_child("ThreadCard1", true, false) as Control
	if content_area == null or content_area.size_flags_horizontal != Control.SIZE_EXPAND_FILL \
			or thread_panel == null or thread_panel.size_flags_horizontal != Control.SIZE_EXPAND_FILL \
			or echo_panel == null or echo_panel.size_flags_horizontal != Control.SIZE_EXPAND_FILL \
			or resolution_panel == null or resolution_panel.size_flags_horizontal != Control.SIZE_EXPAND_FILL \
			or thread_card == null or thread_card.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		_free_tree_node(weaving)
		return { "ok": false, "error": "Weaving authored panels do not expand into their available grid columns" }
	_free_tree_node(weaving)

	var realms := _instantiate_in_tree(RealmSelectScreenScene)
	realms.call("set_layout", compact_layout)
	if (realms.find_child("RealmList", true, false) as GridContainer).columns != 1:
		_free_tree_node(realms)
		return { "ok": false, "error": "RealmSelect compact must use one column" }
	realms.call("set_layout", wide_layout)
	if (realms.find_child("RealmList", true, false) as GridContainer).columns != 3:
		_free_tree_node(realms)
		return { "ok": false, "error": "RealmSelect wide must use three columns" }
	_free_tree_node(realms)

	var vows := _instantiate_in_tree(VowScreenScene)
	vows.call("set_layout", compact_layout)
	if (vows.find_child("ContentRow", true, false) as GridContainer).columns != 1:
		_free_tree_node(vows)
		return { "ok": false, "error": "Vow compact must use one column" }
	vows.call("set_layout", wide_layout)
	if (vows.find_child("ContentRow", true, false) as GridContainer).columns != 2:
		_free_tree_node(vows)
		return { "ok": false, "error": "Vow wide must use two columns" }
	_free_tree_node(vows)

	var sanctum := _instantiate_in_tree(SanctumScreenScene)
	sanctum.call("set_layout", compact_layout)
	var compact_header_width := (sanctum.find_child("HeaderCard", true, false) as Control).custom_minimum_size.x
	var compact_left_width := (sanctum.find_child("LeftStack", true, false) as Control).offset_right
	var compact_right := sanctum.find_child("RightStack", true, false) as Control
	var compact_right_width := -compact_right.offset_left
	var top_band_control := sanctum.find_child("TopBand", true, false) as Control
	var overview_body_control := sanctum.find_child("OverviewBody", true, false) as Control
	if top_band_control == null or overview_body_control == null \
			or compact_right.get_parent() != overview_body_control \
			or top_band_control.get_parent() != overview_body_control.get_parent():
		_free_tree_node(sanctum)
		return { "ok": false, "error": "Sanctum overview is not authored as TopBand followed by the shared side-panel body" }
	sanctum.call("set_layout", wide_layout)
	var wide_header_width := (sanctum.find_child("HeaderCard", true, false) as Control).custom_minimum_size.x
	var wide_left_width := (sanctum.find_child("LeftStack", true, false) as Control).offset_right
	var wide_right_width := -(sanctum.find_child("RightStack", true, false) as Control).offset_left
	_free_tree_node(sanctum)
	if compact_header_width >= wide_header_width:
		return { "ok": false, "error": "Sanctum hub wide header cap did not expand from compact" }
	var compact_spatial_clearance := 960.0 - compact_left_width - compact_right_width
	var wide_spatial_clearance := 1920.0 - wide_left_width - wide_right_width
	if wide_spatial_clearance <= compact_spatial_clearance:
		return { "ok": false, "error": "Sanctum wide profile does not expose more spatial field" }
	if wide_left_width > 360.0 or wide_right_width > 340.0:
		return { "ok": false, "error": "Sanctum wide side panels exceeded their readable caps" }
	if not is_equal_approx(compact_weaving_width, 928.0) \
			or not is_equal_approx(standard_weaving_width, 1200.0) \
			or not is_equal_approx(weaving_width, 1440.0):
		return { "ok": false, "error": "Weaving usable widths were compact %.1f, standard %.1f, wide %.1f" % [compact_weaving_width, standard_weaving_width, weaving_width] }
	if echo_width > 1320.0 or weaving_width > 1440.0:
		return { "ok": false, "error": "Wide capped panel dimensions exceeded profile cap" }
	return { "ok": true }

static func _t_overview_header_drives_body_geometry() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for Sanctum overview geometry test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var sanctum := SanctumScreenScene.instantiate() as Control
	viewport.add_child(sanctum)
	sanctum.call("set_snapshot", {
		"type": "flow.sanctum",
		"meta": { "t": 1 },
		"data": {
			"sanctum_name": "The House Beneath the Returning Memory Tree",
			"ase_balance": 42,
			"ase_rate_per_hour": 1.5,
			"ekwan_balance": 3,
			"party_slots": [],
			"thread_reserve": [],
			"thread_reserve_cap": 4,
			"active_vow": {
				"proverb_twi": "Praye, se woyi baako a na ebu; wokabomu a emmu",
				"proverb_en": "A broomstick breaks alone, but together the bundle cannot be broken.",
				"compliance_count": 12,
			},
			"echo_detail_roster": [],
		},
		"actions": {},
	})
	var title := sanctum.find_child("TitleLabel", true, false) as Label
	var vow_mantra := sanctum.find_child("VowMantraLabel", true, false) as Label
	var vow_compliance := sanctum.find_child("VowComplianceLabel", true, false) as Label
	var guidance := sanctum.find_child("GuidanceLabel", true, false) as Label
	var management := sanctum.find_child("SanctumMgmtBtn", true, false) as Button
	var header_copy := sanctum.find_child("HeaderCopy", true, false) as HBoxContainer
	var vow_copy := sanctum.find_child("VowCopyStack", true, false) as VBoxContainer
	var thread_header := sanctum.find_child("ThreadHeader", true, false) as Label
	var thread_empty := sanctum.find_child("ThreadEmptyLabel", true, false) as Label
	var thread_note := sanctum.find_child("ThreadNoteLabel", true, false) as Label
	var thread_count := sanctum.find_child("ThreadCountLabel", true, false) as Label
	var top_band := sanctum.find_child("TopBand", true, false) as Control
	var layout_root := sanctum.find_child("LayoutRoot", true, false) as Control
	var overview_flow := sanctum.find_child("OverviewFlow", true, false) as Control
	var overview_body := sanctum.find_child("OverviewBody", true, false) as Control
	var header_card := sanctum.find_child("HeaderCard", true, false) as Control
	var ase_card := sanctum.find_child("AseCard", true, false) as Control
	var left_stack := sanctum.find_child("LeftStack", true, false) as Control
	var right_stack := sanctum.find_child("RightStack", true, false) as Control
	var party_panel := sanctum.find_child("PartyPanel", true, false) as Control
	var thread_panel := sanctum.find_child("ThreadPanel", true, false) as Control
	if title == null or vow_mantra == null or vow_compliance == null or guidance == null \
			or management == null or header_copy == null or vow_copy == null \
			or thread_header == null or thread_empty == null \
			or thread_note == null or thread_count == null \
			or top_band == null or layout_root == null or overview_flow == null or overview_body == null \
			or header_card == null or ase_card == null \
			or left_stack == null or right_stack == null \
			or party_panel == null or thread_panel == null:
		viewport.free()
		return { "ok": false, "error": "Sanctum overview responsive fixture is incomplete" }
	if sanctum.find_child("TitleScroll", true, false) != null \
			or sanctum.find_child("HeaderCopyScroll", true, false) != null \
			or sanctum.find_child("ThreadScroll", true, false) != null:
		viewport.free()
		return { "ok": false, "error": "Primary Sanctum overview copy must reflow without nested scroll containers" }
	if _is_descendant_of(management, header_copy):
		viewport.free()
		return { "ok": false, "error": "Sanctum Institutions action was placed inside the header copy region" }
	if not _is_descendant_of(vow_mantra, vow_copy) or not _is_descendant_of(vow_compliance, vow_copy) \
			or _is_descendant_of(guidance, vow_copy):
		viewport.free()
		return { "ok": false, "error": "Sanctum header metadata is not authored as vow/compliance beside guidance" }
	var cases := [
		{
			"name": "wide",
			"size": Vector2i(1920, 1080),
			"profile": &"wide",
			"insets": Vector4.ZERO,
			"header_width": 680.0,
		},
		{
			"name": "compact",
			"size": Vector2i(960, 540),
			"profile": &"compact",
			"insets": Vector4(24, 12, 20, 18),
			"header_width": 600.0,
		},
		{
			"name": "wide_return",
			"size": Vector2i(1920, 1080),
			"profile": &"wide",
			"insets": Vector4.ZERO,
			"header_width": 680.0,
		},
	]
	var first_wide_body_width := 0.0
	for case_v in cases:
		var case: Dictionary = case_v
		var viewport_size: Vector2i = case["size"]
		var insets: Vector4 = case["insets"]
		viewport.size = viewport_size
		sanctum.call("set_bottom_content_exclusion", maxi(16, int(ceilf(insets.w))) + 88 + 8)
		sanctum.call("set_layout", {
			"profile": case["profile"],
			"logical_size": Vector2(viewport_size),
			"safe_insets": insets,
		})
		_force_control_layout(sanctum)
		sanctum.call("_refresh_overview_wrap_metrics")
		_force_control_layout(sanctum)
		var screen_rect := sanctum.get_global_rect()
		var layout_rect := layout_root.get_global_rect()
		var flow_rect := overview_flow.get_global_rect()
		var top_rect := top_band.get_global_rect()
		var body_rect := overview_body.get_global_rect()
		var header_rect := header_card.get_global_rect()
		var ase_rect := ase_card.get_global_rect()
		var left_rect := left_stack.get_global_rect()
		var right_rect := right_stack.get_global_rect()
		var party_rect := party_panel.get_global_rect()
		var thread_rect := thread_panel.get_global_rect()
		if not is_equal_approx(header_card.custom_minimum_size.x, float(case["header_width"])):
			viewport.free()
			return { "ok": false, "error": "Sanctum header width ignored the %s profile" % str(case["name"]) }
		if not flow_rect.position.is_equal_approx(layout_rect.position) \
				or not flow_rect.size.is_equal_approx(layout_rect.size):
			viewport.free()
			return { "ok": false, "error": "Sanctum OverviewFlow escaped LayoutRoot after snapshot-before-layout at %s: flow=%s layout=%s" % [str(case["name"]), str(flow_rect), str(layout_rect)] }
		var expected_separation := 7.5 if case["profile"] == &"compact" else 9.5
		if body_rect.position.y < top_rect.end.y + expected_separation:
			viewport.free()
			return { "ok": false, "error": "Sanctum overview body did not reflow below its rendered header at %s" % str(case["name"]) }
		if not screen_rect.encloses(header_rect) or not screen_rect.encloses(ase_rect):
			viewport.free()
			return { "ok": false, "error": "Sanctum header or Ase card escaped the safe screen at %s" % str(case["name"]) }
		if str(case["name"]) == "compact" and right_rect.position.x - left_rect.end.x < 260.0:
			viewport.free()
			return { "ok": false, "error": "Compact Sanctum side cards left too little spatial field" }
		if str(case["name"]) == "compact" and (not is_equal_approx(right_rect.size.x, 280.0) or thread_rect.size.x > 284.5):
			viewport.free()
			return { "ok": false, "error": "Compact Thread Reserve exceeded its authored 280-unit side-card cap" }
		if str(case["name"]) == "compact" and screen_rect.end.y - thread_rect.end.y < 15.5:
			viewport.free()
			return { "ok": false, "error": "Compact Thread Reserve did not retain the 16-unit safe bottom inset" }
		if header_rect.intersects(party_rect) or top_rect.intersects(party_rect) \
				or header_rect.intersects(thread_rect) or top_rect.intersects(thread_rect):
			var overlap_error := {
				"ok": false,
				"error": "Sanctum header overlaps Departure Party or Thread Reserve at %s: top=%s header=%s party=%s thread=%s body=%s" % [
					str(case["name"]),
					str(top_rect),
					str(header_rect),
					str(party_rect),
					str(thread_rect),
					"%s title=%s title_min=%s copy=%s copy_min=%s" % [
						str(body_rect),
						str(title.get_global_rect()),
						str(title.get_combined_minimum_size()),
						str(header_copy.get_global_rect()),
						str(header_copy.get_combined_minimum_size()),
					],
				],
			}
			viewport.free()
			return overlap_error
		if party_rect.position.y < body_rect.position.y - 0.5 \
				or thread_rect.position.y < body_rect.position.y - 0.5 \
				or party_rect.end.y > screen_rect.end.y + 0.5 \
				or thread_rect.end.y > screen_rect.end.y + 0.5:
			var bounds_error := {
				"ok": false,
				"error": "Sanctum side panels escaped the safe/chrome-excluded body at %s: screen=%s body=%s party=%s thread=%s" % [
					str(case["name"]),
					str(screen_rect),
					str(body_rect),
					str(party_rect),
					str(thread_rect),
				],
			}
			viewport.free()
			return bounds_error
		for header_label in [title, vow_mantra, vow_compliance, guidance]:
			if not header_label.visible or not header_rect.encloses(header_label.get_global_rect()):
				viewport.free()
				return { "ok": false, "error": "%s escaped or disappeared from the Sanctum header at %s" % [header_label.name, str(case["name"])] }
		for thread_label in [thread_header, thread_count, thread_empty, thread_note]:
			if not thread_label.visible or not thread_rect.encloses(thread_label.get_global_rect()):
				viewport.free()
				return { "ok": false, "error": "%s escaped or disappeared from Thread Reserve at %s" % [thread_label.name, str(case["name"])] }
		if management.get_global_rect().size.x < 48.0 or management.get_global_rect().size.y < 48.0:
			viewport.free()
			return { "ok": false, "error": "Sanctum Institutions action fell below the 48-unit target at %s" % str(case["name"]) }
		if str(case["name"]) == "compact" and title.get_global_rect().size.y <= 32.0:
			viewport.free()
			return { "ok": false, "error": "Long compact Sanctum title did not wrap within the authored header row" }
		if str(case["name"]) == "wide":
			first_wide_body_width = body_rect.size.x
		elif str(case["name"]) == "wide_return" and not is_equal_approx(body_rect.size.x, first_wide_body_width):
			viewport.free()
			return { "ok": false, "error": "Sanctum live compact-to-wide resize did not restore the spatial body width" }
	viewport.free()
	return { "ok": true }

static func _t_weaving_compact_scroll_geometry() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for compact geometry test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var weaving := WeavingScreenScene.instantiate() as Control
	viewport.add_child(weaving)
	weaving.call("set_bottom_content_exclusion", 112)
	weaving.call("set_layout", {
		"profile": &"compact",
		"safe_insets": Vector4.ZERO,
		"logical_size": Vector2(960, 540),
	})
	var threads: Array = []
	for i in range(6):
		threads.append({
			"id": "thread.test.%d" % i,
			"virtue": "courage",
			"quality_tier": "clean",
		})
	weaving.call("set_snapshot", {
		"type": "flow.weaving_rite",
		"meta": { "t": 0 },
		"data": {
			"phase": "thread_select",
			"selected_echo": {
				"name": "Akua",
				"standing": 1,
				"calling_origin": "uncalled",
			},
			"thread_reserve": threads,
			"selected_thread_id": "",
			"invitation_lines": [],
			"outcome": "",
			"aftermath_lines": [],
			"non_chosen": [],
		},
		"actions": {},
	})
	_force_control_layout(weaving)
	var scroll := weaving.find_child("ContentScroll", true, false) as ScrollContainer
	var content := weaving.find_child("ContentArea", true, false) as Control
	var action_bar := weaving.find_child("ActionBar", true, false) as Control
	if scroll == null or content == null or action_bar == null:
		viewport.free()
		return { "ok": false, "error": "Weaving compact scene lacks authored scroll body or fixed ActionBar" }
	var visible_cards := 0
	for i in range(1, 7):
		var card := weaving.find_child("ThreadCard%d" % i, true, false) as Control
		if card != null and card.visible:
			visible_cards += 1
	if visible_cards != 6:
		viewport.free()
		return { "ok": false, "error": "Expected six visible Thread cards, got %d" % visible_cards }
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		viewport.free()
		return { "ok": false, "error": "Weaving body must disable horizontal scrolling" }
	if content.get_combined_minimum_size().y <= scroll.size.y:
		viewport.free()
		return { "ok": false, "error": "Compact six-card fixture did not exercise vertical overflow" }
	var vbar := scroll.get_v_scroll_bar()
	if vbar == null or vbar.max_value <= vbar.page:
		viewport.free()
		return { "ok": false, "error": "Weaving compact body cannot scroll to its overflow content" }
	if scroll.size.x < 800.0 or content.size.x < 800.0:
		viewport.free()
		return { "ok": false, "error": "Weaving compact scroll body collapsed instead of using safe width" }
	if _is_descendant_of(action_bar, scroll):
		viewport.free()
		return { "ok": false, "error": "Weaving ActionBar is inside the scrolling body" }
	var safe_content_bottom := 540.0 - 112.0
	var action_bottom := action_bar.get_global_rect().end.y
	if action_bottom > safe_content_bottom + 0.5:
		viewport.free()
		return { "ok": false, "error": "Weaving ActionBar bottom %.1f exceeds safe content bottom %.1f" % [action_bottom, safe_content_bottom] }
	viewport.free()
	return { "ok": true }

static func _t_return_notice_does_not_block_rail() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for return-to-Sanctum input test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var shell := SanctumShellScene.instantiate() as SanctumShell
	var modal_host := ModalHostScene.instantiate() as ModalHost
	viewport.add_child(shell)
	viewport.add_child(modal_host)
	shell.set_layout({
		"profile": &"standard",
		"safe_insets": Vector4.ZERO,
		"logical_size": Vector2(1280, 720),
	})
	var nav_actions: Array[Dictionary] = []
	shell.action_requested.connect(func(action: Dictionary) -> void:
		nav_actions.append(action.duplicate(true))
	)
	modal_host.action_requested.connect(func(_action: Dictionary) -> void:
		shell.set_snapshot({
			"type": "flow.sanctum",
			"meta": { "t": 1 },
			"data": {
				"return_notification": {
					"id": "offline.test",
					"title": "The Flame Held",
					"body": "A little charge remained in your absence.",
					"detail": "",
					"amount": "+1 Ase retained",
					"tone": "positive",
					"auto_dismiss": false,
					"blocking_overlay": true,
				},
			},
			"actions": {
				"nav.echo_party": {
					"type": "flow.go_state",
					"slot": "nav.echo_party",
					"label": "Party",
					"to": "flow.echo_party",
				},
			},
		})
	)
	if not modal_host.present_modal_for_id(&"realm.return_home", ReturnHomeModalScene, {
		"layout": {
			"profile": &"standard",
			"safe_insets": Vector4.ZERO,
			"logical_size": Vector2(1280, 720),
		},
		"result": {
			"success": true,
			"message": "The party found its way home.",
		},
	}):
		viewport.free()
		return { "ok": false, "error": "Failed to present Realm return-result fixture" }
	var return_result := modal_host.get("_active_modal") as Control
	var return_button := return_result.get_node_or_null("%ContinueButton") as Button if return_result != null else null
	if return_button == null or not return_button.visible or return_button.disabled:
		viewport.free()
		return { "ok": false, "error": "Realm return-result action was not reachable" }
	return_button.pressed.emit()
	var notification_overlay := shell.get_node_or_null("NotificationLayer/NotificationOverlay") as Control
	var notification_control := shell.get_node_or_null("NotificationLayer/NotificationControl") as Control
	var notification_anchor := shell.get_node_or_null("%NotificationAnchor") as Control
	var notification_panel := shell.get_node_or_null("%NotificationPanel") as Control
	var notification_dismiss := shell.get_node_or_null("%NotificationDismiss") as Button
	var bottom_rail := shell.get_node_or_null("ChromeLayer/ChromeControl/BottomRail") as Control
	var party_button := shell.get_node_or_null("%PartyButton") as Button
	if modal_host.has_active_modal() or modal_host.visible:
		viewport.free()
		return { "ok": false, "error": "ModalHost remained blocking after Realm resolve returned to Sanctum" }
	if notification_overlay == null or not notification_overlay.visible:
		viewport.free()
		return { "ok": false, "error": "Return notification fixture did not show its decorative backdrop" }
	if notification_overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		viewport.free()
		return { "ok": false, "error": "Layer-30 return notification backdrop blocks layer-20 rail input" }
	if notification_control == null or notification_control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			or notification_anchor == null or notification_anchor.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		viewport.free()
		return { "ok": false, "error": "Notification positioning controls must remain pointer-transparent" }
	if notification_panel == null or notification_panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		viewport.free()
		return { "ok": false, "error": "Visible notification card must stop input over its card area" }
	if notification_dismiss == null or notification_dismiss.disabled \
			or notification_dismiss.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		viewport.free()
		return { "ok": false, "error": "Notification Dismiss action is not an interactive child of the stopping card" }
	if bottom_rail == null or bottom_rail.mouse_filter != Control.MOUSE_FILTER_STOP:
		viewport.free()
		return { "ok": false, "error": "Sanctum rail was not restored as an interactive surface" }
	if party_button == null or party_button.disabled or not party_button.is_visible_in_tree():
		viewport.free()
		return { "ok": false, "error": "Sanctum Party navigation action was not reachable after return" }
	_force_control_layout(shell)
	var party_center := party_button.get_global_rect().get_center()
	var card_size := notification_anchor.size
	notification_anchor.global_position = party_center - card_size * 0.5
	_force_control_layout(shell)
	if not notification_panel.get_global_rect().has_point(party_center):
		viewport.free()
		return { "ok": false, "error": "Pointer fixture failed to overlap notification card and Party nav target" }
	_push_pointer_click(viewport, party_center)
	if not nav_actions.is_empty():
		viewport.free()
		return { "ok": false, "error": "Card-area pointer click passed through to underlying Sanctum nav" }
	shell.set_layout({
		"profile": &"standard",
		"safe_insets": Vector4.ZERO,
		"logical_size": Vector2(1280, 720),
	})
	_force_control_layout(shell)
	party_center = party_button.get_global_rect().get_center()
	if notification_panel.get_global_rect().has_point(party_center):
		viewport.free()
		return { "ok": false, "error": "Responsive notification layout still covers the bottom rail" }
	_push_pointer_click(viewport, party_center)
	if nav_actions.size() != 1:
		viewport.free()
		return { "ok": false, "error": "Expected one real pointer-triggered Sanctum rail action after return, got %d" % nav_actions.size() }
	var emitted := nav_actions[0]
	if str(emitted.get("type", "")) != "flow.go_state" \
			or str(emitted.get("slot", "")) != "nav.echo_party" \
			or str(emitted.get("to", "")) != "flow.echo_party":
		viewport.free()
		return { "ok": false, "error": "Sanctum rail emitted the wrong return action: %s" % str(emitted) }
	viewport.free()
	return { "ok": true }

static func _t_ancestor_hide_disables_shell_layers() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for inherited visibility test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var ancestor := Control.new()
	ancestor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(ancestor)
	var shell := SanctumShellScene.instantiate() as SanctumShell
	ancestor.add_child(shell)
	var layers: Array[CanvasLayer] = [
		shell.get_node("WorldLayer") as CanvasLayer,
		shell.get_node("UILayer") as CanvasLayer,
		shell.get_node("ChromeLayer") as CanvasLayer,
		shell.get_node("NotificationLayer") as CanvasLayer,
	]
	for layer in layers:
		if layer == null or not layer.visible:
			viewport.free()
			return { "ok": false, "error": "Visible Sanctum ancestor did not activate all shell CanvasLayers" }
	var camera := shell.get_node("WorldLayer/SpatialLayer/SpatialView/Camera2D") as Camera2D
	if camera == null or not camera.enabled:
		viewport.free()
		return { "ok": false, "error": "Visible Sanctum ancestor did not activate the shell camera" }
	ancestor.hide()
	for layer in layers:
		if layer.visible:
			viewport.free()
			return { "ok": false, "error": "Ancestor-hidden Sanctum shell left CanvasLayer %s active" % layer.name }
	if camera.enabled:
		viewport.free()
		return { "ok": false, "error": "Ancestor-hidden Sanctum shell left Camera2D enabled" }
	ancestor.show()
	for layer in layers:
		if not layer.visible:
			viewport.free()
			return { "ok": false, "error": "Restored Sanctum ancestor did not reactivate CanvasLayer %s" % layer.name }
	if not camera.enabled:
		viewport.free()
		return { "ok": false, "error": "Restored Sanctum ancestor did not reactivate Camera2D" }
	viewport.free()
	return { "ok": true }

static func _t_notification_compact_safe_scroll() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for compact notification geometry test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var shell := SanctumShellScene.instantiate() as SanctumShell
	viewport.add_child(shell)
	var safe_insets := Vector4(40, 28, 52, 34)
	shell.set_layout({
		"profile": &"compact",
		"safe_insets": safe_insets,
		"logical_size": Vector2(960, 540),
	})
	var long_body := "The Sanctum held this account through a long absence. ".repeat(18)
	var long_detail := "Every remembered thread remained visible and recoverable. ".repeat(16)
	shell.push_notification({
		"id": "offline.long.geometry",
		"title": "The Flame Held Steady",
		"body": long_body,
		"detail": long_detail,
		"amount": "+12 Ase retained",
		"tone": "positive",
		"auto_dismiss": false,
		"blocking_overlay": false,
	})
	_force_control_layout(shell)
	var anchor := shell.get_node_or_null("%NotificationAnchor") as Control
	var panel := shell.get_node_or_null("%NotificationPanel") as Control
	var body_scroll := shell.get_node_or_null("%NotificationBodyScroll") as ScrollContainer
	var body_content := shell.get_node_or_null("%BodyContent") as Control
	var title := shell.get_node_or_null("%NotificationTitle") as Control
	var dismiss := shell.get_node_or_null("%NotificationDismiss") as Control
	var amount := shell.get_node_or_null("%NotificationAmount") as Control
	var body := shell.get_node_or_null("%NotificationBody") as Control
	var detail := shell.get_node_or_null("%NotificationDetail") as Control
	var rail := shell.get_node_or_null("%BottomRail") as Control
	if anchor == null or panel == null or body_scroll == null or body_content == null \
			or title == null or dismiss == null or amount == null or body == null \
			or detail == null or rail == null:
		viewport.free()
		return { "ok": false, "error": "Compact notification fixture lacks authored safe/scroll/card regions" }
	var panel_rect := panel.get_global_rect()
	var rail_rect := rail.get_global_rect()
	if panel_rect.position.x < safe_insets.x - 0.5 \
			or panel_rect.end.x > 960.0 - safe_insets.z + 0.5 \
			or panel_rect.position.y < safe_insets.y - 0.5:
		viewport.free()
		return { "ok": false, "error": "Compact notification card escapes converted safe bounds: %s" % str(panel_rect) }
	if panel_rect.size.x > 560.5 or panel_rect.size.y > 240.5:
		viewport.free()
		return { "ok": false, "error": "Compact notification exceeds its 560x240 profile cap: %s" % str(panel_rect.size) }
	if panel_rect.end.y > rail_rect.position.y - 8.0 + 0.5:
		viewport.free()
		return {
			"ok": false,
			"error": "Compact notification overlaps bottom rail separation; notice bottom %.1f rail top %.1f" % [
				panel_rect.end.y,
				rail_rect.position.y,
			],
		}
	if not _is_descendant_of(body, body_scroll) or not _is_descendant_of(detail, body_scroll):
		viewport.free()
		return { "ok": false, "error": "Long notification copy is not inside the authored scroll body" }
	if _is_descendant_of(title, body_scroll) or _is_descendant_of(dismiss, body_scroll) \
			or _is_descendant_of(amount, body_scroll):
		viewport.free()
		return { "ok": false, "error": "Notification header, Dismiss, or amount moved into the scroll body" }
	if body_content.get_combined_minimum_size().y <= body_scroll.size.y:
		viewport.free()
		return { "ok": false, "error": "Long compact notification fixture did not overflow its bounded body" }
	var vbar := body_scroll.get_v_scroll_bar()
	if vbar == null or vbar.max_value <= vbar.page:
		viewport.free()
		return { "ok": false, "error": "Long compact notification content is not reachable by scrolling" }
	viewport.free()
	return { "ok": true }

static func _push_pointer_click(viewport: SubViewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	viewport.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.position = position
	release.global_position = position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	viewport.push_input(release, true)

static func _force_control_layout(root: Node) -> void:
	for pass_index in range(4):
		root.propagate_notification(Control.NOTIFICATION_RESIZED)
		root.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)

static func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false

static func _instantiate_in_tree(scene: PackedScene) -> Node:
	return scene.instantiate()

static func _instantiate_shell_with_rail_binding() -> SanctumShell:
	var shell := SanctumShellScene.instantiate() as SanctumShell
	shell.set("_bottom_rail", shell.get_node_or_null("ChromeLayer/ChromeControl/BottomRail"))
	return shell

static func _free_tree_node(node: Node) -> void:
	node.free()

static func _check_interactive_targets(root: Node) -> String:
	for child in root.get_children():
		var nested := _check_interactive_targets(child)
		if not nested.is_empty():
			return nested
	var control := root as Control
	if control == null:
		return ""
	var is_interactive := control is Button or control is CheckButton or control is OptionButton or control is HSlider
	if not is_interactive:
		return ""
	var min_size := control.custom_minimum_size
	var min_height := 56.0 if control.theme_type_variation == &"ButtonPrimary" else 48.0
	if root.name == &"ThreadSelectButton" and _has_thread_card_ancestor(root):
		var card := _thread_card_ancestor(root) as Control
		if card != null and card.custom_minimum_size.x >= 48.0 and card.custom_minimum_size.y >= 48.0:
			return ""
	if min_size.x < 48.0 or min_size.y < min_height:
		return "%s target %.1fx%.1f below %.0fx%.0f" % [root.name, min_size.x, min_size.y, 48.0, min_height]
	return ""

static func _has_ancestor_named(node: Node, node_name: StringName) -> bool:
	return _ancestor_named(node, node_name) != null

static func _ancestor_named(node: Node, node_name: StringName) -> Node:
	var current := node.get_parent()
	while current != null:
		if current.name == node_name:
			return current
		current = current.get_parent()
	return null

static func _has_thread_card_ancestor(node: Node) -> bool:
	return _thread_card_ancestor(node) != null

static func _thread_card_ancestor(node: Node) -> Node:
	var current := node.get_parent()
	while current != null:
		if String(current.name).begins_with("ThreadCard"):
			return current
		current = current.get_parent()
	return null


# 1. Layout always contains ase_flame tile at (0,0)
static func _t_ase_flame_in_layout() -> Dictionary:
	var save := _make_save()
	var layout := SanctumLayoutService.snapshot_layout(save)
	var tiles: Array = layout.get("tiles", [])
	for tile_v in tiles:
		if not (tile_v is Dictionary):
			continue
		var tile: Dictionary = tile_v
		if str(tile.get("kind", "")) == "ase_flame" and int(tile.get("x", -1)) == 0 and int(tile.get("y", -1)) == 0:
			return { "ok": true }
	return { "ok": false, "error": "ase_flame tile not found at (0,0)" }


# 2. Occupants always contain ase_flame as first entry
static func _t_ase_flame_in_occupants() -> Dictionary:
	var save := _make_save()
	var occupants := SanctumLayoutService.snapshot_occupants(save)
	if occupants.is_empty():
		return { "ok": false, "error": "occupants empty" }
	var first_v: Variant = occupants[0]
	if not (first_v is Dictionary):
		return { "ok": false, "error": "first occupant not a dict" }
	var first: Dictionary = first_v
	if str(first.get("kind", "")) != "ase_flame":
		return { "ok": false, "error": "first occupant kind is not ase_flame: %s" % first.get("kind","") }
	return { "ok": true }


# 3. Established institution appears in layout tiles
static func _t_institution_tile_after_establish() -> Dictionary:
	var hearth := {
		"unlocked": true,
		"tier": 0,
		"condition": "neglected",
		"last_activated_unix": 0,
		"occupant_ids": [],
		"position": { "x": 3, "y": 0 },
	}
	var save := _make_save([], { "hearth": hearth })
	var layout := SanctumLayoutService.snapshot_layout(save)
	var tiles: Array = layout.get("tiles", [])
	for tile_v in tiles:
		if not (tile_v is Dictionary):
			continue
		var tile: Dictionary = tile_v
		if str(tile.get("kind", "")) == "institution" and str(tile.get("inst_id", "")) == "hearth":
			if int(tile.get("x", -1)) == 3 and int(tile.get("y", -1)) == 0:
				return { "ok": true }
	return { "ok": false, "error": "hearth institution tile not found at (3,0)" }


# 4. All roster echoes appear as occupants
static func _t_all_echoes_placed() -> Dictionary:
	var roster := [_make_echo("e1"), _make_echo("e2"), _make_echo("e3")]
	var save := _make_save(roster)
	var occupants := SanctumLayoutService.snapshot_occupants(save, roster, [])
	var echo_ids_found: Array = []
	for occ_v in occupants:
		if not (occ_v is Dictionary):
			continue
		var occ: Dictionary = occ_v
		if str(occ.get("kind", "")) == "echo":
			echo_ids_found.append(str(occ.get("id", "")))
	for id_str in ["e1", "e2", "e3"]:
		if not echo_ids_found.has(id_str):
			return { "ok": false, "error": "echo %s not in occupants" % id_str }
	return { "ok": true }


# 5. Each Echo occupant exposes the canonical emotional status only.
static func _t_echo_has_emotional_status() -> Dictionary:
	var roster := [_make_echo("e1", 80)]  # 80 morale = inspired
	var save := _make_save(roster)
	var occupants := SanctumLayoutService.snapshot_occupants(save, roster, [])
	for occ_v in occupants:
		if not (occ_v is Dictionary):
			continue
		var occ: Dictionary = occ_v
		if str(occ.get("kind", "")) == "echo" and str(occ.get("id", "")) == "e1":
			var status := str(occ.get("emotional_status", ""))
			if status.is_empty():
				return { "ok": false, "error": "emotional_status missing for e1" }
			if occ.has("morale_tier"):
				return { "ok": false, "error": "occupant exposes legacy morale_tier" }
			return { "ok": true }
	return { "ok": false, "error": "echo e1 not found in occupants" }


# 6. Echo assigned to institution appears adjacent to its tile
static func _t_echo_near_institution() -> Dictionary:
	var hearth := {
		"unlocked": true,
		"tier": 0,
		"condition": "neglected",
		"last_activated_unix": 0,
		"occupant_ids": ["e1"],
		"position": { "x": 3, "y": 0 },
	}
	var roster := [_make_echo("e1")]
	var save := _make_save(roster, { "hearth": hearth })
	var occupants := SanctumLayoutService.snapshot_occupants(save, roster, [])
	for occ_v in occupants:
		if not (occ_v is Dictionary):
			continue
		var occ: Dictionary = occ_v
		if str(occ.get("kind", "")) == "echo" and str(occ.get("id", "")) == "e1":
			var ex := int(occ.get("x", -99))
			var ey := int(occ.get("y", -99))
			# Echo should be within 2 tiles of hearth at (3,0)
			var dist: int = max(abs(ex - 3), abs(ey - 0))
			if dist <= 2:
				return { "ok": true }
			return { "ok": false, "error": "echo e1 at (%d,%d) is not near hearth at (3,0)" % [ex, ey] }
	return { "ok": false, "error": "echo e1 not found" }


# 7. Valid placement cells don't include occupied positions (Ase Flame at 0,0)
static func _t_valid_cells_exclude_occupied() -> Dictionary:
	var save := _make_save()
	var cells: Array = SanctumLayoutService.compute_valid_placement_cells(save)
	for cell_v in cells:
		if cell_v is Vector2i:
			var cell: Vector2i = cell_v
			if cell == Vector2i(0, 0):
				return { "ok": false, "error": "valid cells include Ase Flame position (0,0)" }
	if cells.is_empty():
		return { "ok": false, "error": "valid cells is empty — expected at least some adjacents" }
	return { "ok": true }


# 8. All valid placement cells are outside the exclusion zone of every occupied tile
static func _t_valid_cells_not_in_exclusion() -> Dictionary:
	var save := _make_save()
	var cells: Array = SanctumLayoutService.compute_valid_placement_cells(save)
	if cells.is_empty():
		return { "ok": false, "error": "valid cells is empty — expected non-empty for 5×5 starter layout" }
	# Ase Flame at (0,0) with exclusion radius 2: no valid cell should be
	# within Chebyshev distance 2 of (0,0).
	const EXCL := SanctumLayoutService.PLACEMENT_EXCLUSION_RADIUS
	for cell_v in cells:
		if not (cell_v is Vector2i): continue
		var cell: Vector2i = cell_v
		var cheb := maxi(abs(cell.x), abs(cell.y))
		if cheb <= EXCL:
			return { "ok": false, "error": "valid cell (%d,%d) is within Ase Flame exclusion zone" % [cell.x, cell.y] }
	return { "ok": true }


# --- check_placement_validity_from_data tests ---
# Test setup: a single floor tile at (5,0), Ase Flame occupant at (0,0).
# This gives a clear scenario with no overlap between floor and exclusion zones.

# 9. Already-occupied cell returns "Already occupied"
static func _t_validity_already_occupied() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(0, 0), floor_cells, occupied_cells)
	if bool(result.get("valid", true)):
		return { "ok": false, "error": "expected invalid for occupied cell, got valid" }
	if str(result.get("reason", "")) != "Already occupied":
		return { "ok": false, "error": "wrong reason: %s" % result.get("reason", "") }
	return { "ok": true }


# 10. Floor-tile cell returns "Already part of the floor"
static func _t_validity_already_floor() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(5, 0), floor_cells, occupied_cells)
	if bool(result.get("valid", true)):
		return { "ok": false, "error": "expected invalid for floor cell, got valid" }
	if str(result.get("reason", "")) != "Already part of the floor":
		return { "ok": false, "error": "wrong reason: %s" % result.get("reason", "") }
	return { "ok": true }


# 11. Cell within Chebyshev-2 of occupied returns "Too close to an existing building"
static func _t_validity_exclusion_zone() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	# (2,0) is Chebyshev distance 2 from (0,0) — inside the exclusion zone
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(2, 0), floor_cells, occupied_cells)
	if bool(result.get("valid", true)):
		return { "ok": false, "error": "expected invalid for exclusion-zone cell, got valid" }
	if str(result.get("reason", "")) != "Too close to an existing building":
		return { "ok": false, "error": "wrong reason: %s" % result.get("reason", "") }
	return { "ok": true }


# 12. A far cell outside the exclusion zone is now valid (no adjacency requirement)
static func _t_validity_far_cell_is_valid() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	# (10,10) is far from floor and outside all exclusion zones — should be valid.
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(10, 10), floor_cells, occupied_cells)
	if not bool(result.get("valid", false)):
		return { "ok": false, "error": "expected valid for far cell (10,10), got: %s" % result.get("reason", "") }
	return { "ok": true }


# 13. A valid cell returns { "valid": true, "reason": "" }
static func _t_validity_valid_cell() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	# (6,0) is adjacent to (5,0), not in floor, not occupied,
	# and Chebyshev distance from (0,0) = 6 — well outside exclusion zone
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(6, 0), floor_cells, occupied_cells)
	if not bool(result.get("valid", false)):
		return { "ok": false, "error": "expected valid for (6,0), got invalid: %s" % result.get("reason", "") }
	if str(result.get("reason", "")) != "":
		return { "ok": false, "error": "expected empty reason for valid cell, got: %s" % result.get("reason", "") }
	return { "ok": true }


# --- get_bridge_preview_from_floor tests ---

# 14. Target 3 tiles away in x returns a full connecting path
static func _t_bridge_preview_returns_cells() -> Dictionary:
	var floor_cells: Array = [Vector2i(0, 0)]
	# target at (3,0): nearest floor = (0,0), dist = 3.
	# Full path: (1,0) → (2,0) → stop before target (3,0).
	var bridge: Array = SanctumLayoutService.get_bridge_preview_from_floor(
		Vector2i(3, 0), floor_cells)
	if bridge.is_empty():
		return { "ok": false, "error": "expected bridge cells for target (3,0), got empty" }
	if not bridge.has(Vector2i(1, 0)):
		return { "ok": false, "error": "expected (1,0) in bridge, got %s" % str(bridge) }
	if not bridge.has(Vector2i(2, 0)):
		return { "ok": false, "error": "expected (2,0) in bridge, got %s" % str(bridge) }
	return { "ok": true }


# 15. Target already adjacent to floor returns empty bridge
static func _t_bridge_preview_adjacent_is_empty() -> Dictionary:
	var floor_cells: Array = [Vector2i(0, 0)]
	# (1,1) is diagonally adjacent to (0,0) — manhattan distance 2 but Chebyshev 1
	# _bridge_cells uses manhattan (abs(dx)+abs(dy)) for nearest, then returns [] if dist<=1
	# Actually _bridge_cells checks abs(dx)+abs(dy): abs(1)+abs(1)=2, so best_dist=2>1
	# Step x: cx=1, step=(1,0). Not in floor. bridge=[(1,0)]
	# Step y: cy=1, step=(1,1). Not in floor. bridge=[(1,0),(1,1)]
	# So (1,1) returns 2 bridge cells. Use (0,1) instead:
	# (0,1): abs(0)+abs(1)=1 → best_dist=1 ≤ 1 → return []
	var bridge: Array = SanctumLayoutService.get_bridge_preview_from_floor(
		Vector2i(0, 1), floor_cells)
	if not bridge.is_empty():
		return { "ok": false, "error": "expected empty bridge for adjacent target (0,1), got %s" % str(bridge) }
	return { "ok": true }
