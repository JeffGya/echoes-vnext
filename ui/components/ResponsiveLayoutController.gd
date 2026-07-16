class_name ResponsiveLayoutController
extends Node

signal layout_changed(layout: Dictionary)

const DESIGN_BASE := Vector2(1280.0, 720.0)
const DESKTOP_MIN_SIZE := Vector2i(960, 540)
const DESKTOP_MAX_SCALE := 1.25
const PHONE_BASE := Vector2(960.0, 540.0)
const PHONE_MAX_SCALE := 2.0
const TABLET_BASE := Vector2(1280.0, 720.0)
const TABLET_MAX_SCALE := 1.5

var _layout: Dictionary = {}
var _last_window_size := Vector2i.ZERO
var _safe_recompute_queued := false

func _ready() -> void:
	var window := get_window()
	if window != null:
		window.min_size = DESKTOP_MIN_SIZE
		window.size_changed.connect(_on_window_size_changed)
	_recompute_and_emit(true)

func current_layout() -> Dictionary:
	return _layout.duplicate(true)

func refresh() -> void:
	_recompute_and_emit(false)

static func calculate_layout(
		window_size: Vector2,
		safe_area_px: Rect2i = Rect2i(),
		device_profile: StringName = &"desktop",
		inverse_stretch_transform: Transform2D = Transform2D()
	) -> Dictionary:
	var safe_window := Vector2(maxf(1.0, window_size.x), maxf(1.0, window_size.y))
	var is_mobile := device_profile == &"phone" or device_profile == &"tablet"
	var target_base := DESIGN_BASE
	var max_scale := DESKTOP_MAX_SCALE
	if device_profile == &"phone":
		target_base = PHONE_BASE
		max_scale = PHONE_MAX_SCALE
	elif device_profile == &"tablet":
		target_base = TABLET_BASE
		max_scale = TABLET_MAX_SCALE

	var raw_scale := minf(safe_window.x / target_base.x, safe_window.y / target_base.y)
	var ui_scale := clampf(raw_scale, 1.0, max_scale)
	var logical_size := safe_window / ui_scale
	var safe_insets := safe_insets_from_physical_rect(safe_window, safe_area_px, inverse_stretch_transform)
	var safe_logical_size := Vector2(
		maxf(0.0, logical_size.x - safe_insets.x - safe_insets.z),
		maxf(0.0, logical_size.y - safe_insets.y - safe_insets.w)
	)

	return {
		"profile": _profile_for_safe_space(safe_logical_size),
		"logical_size": logical_size,
		"safe_insets": safe_insets,
		"ui_scale": ui_scale,
		"is_mobile": is_mobile,
	}

static func calculate_runtime_layout_after_scale(
		window_size: Vector2,
		safe_area_px: Rect2i,
		device_profile: StringName,
		actual_inverse_stretch_transform: Transform2D
	) -> Dictionary:
	return calculate_layout(window_size, safe_area_px, device_profile, actual_inverse_stretch_transform)

static func _profile_for_safe_space(safe_logical_size: Vector2) -> StringName:
	if safe_logical_size.x < 1200.0 or safe_logical_size.y < 680.0:
		return &"compact"
	if safe_logical_size.x < 1440.0 or safe_logical_size.y < 810.0:
		return &"standard"
	return &"wide"

static func safe_insets_from_physical_rect(
		window_size: Vector2,
		safe_area_px: Rect2i,
		inverse_stretch_transform: Transform2D = Transform2D()
	) -> Vector4:
	if safe_area_px.size.x <= 0 or safe_area_px.size.y <= 0:
		return Vector4.ZERO
	if safe_area_px.position.x < 0 or safe_area_px.position.y < 0:
		return Vector4.ZERO
	if safe_area_px.size.x > int(ceilf(window_size.x)) or safe_area_px.size.y > int(ceilf(window_size.y)):
		return Vector4.ZERO

	var physical_top_left := Vector2(float(safe_area_px.position.x), float(safe_area_px.position.y))
	var physical_bottom_right := Vector2(
		float(safe_area_px.position.x + safe_area_px.size.x),
		float(safe_area_px.position.y + safe_area_px.size.y)
	)
	var logical_window_top_left := inverse_stretch_transform * Vector2.ZERO
	var logical_window_bottom_right := inverse_stretch_transform * window_size
	var logical_safe_top_left := inverse_stretch_transform * physical_top_left
	var logical_safe_bottom_right := inverse_stretch_transform * physical_bottom_right
	var left := maxf(0.0, logical_safe_top_left.x - logical_window_top_left.x)
	var top := maxf(0.0, logical_safe_top_left.y - logical_window_top_left.y)
	var right := maxf(0.0, logical_window_bottom_right.x - logical_safe_bottom_right.x)
	var bottom := maxf(0.0, logical_window_bottom_right.y - logical_safe_bottom_right.y)
	return Vector4(left, top, right, bottom)

static func detect_device_profile(screen_size_px: Vector2i, dpi: int, window_size: Vector2i, mobile_hint: bool) -> StringName:
	if not mobile_hint:
		return &"desktop"
	if mobile_hint:
		var shortest_px := mini(screen_size_px.x, screen_size_px.y)
		var longest_px := maxi(screen_size_px.x, screen_size_px.y)
		var diagonal_inches := 0.0
		if dpi > 0:
			diagonal_inches = sqrt(float(screen_size_px.x * screen_size_px.x + screen_size_px.y * screen_size_px.y)) / float(dpi)
		if diagonal_inches > 0.0:
			return &"phone" if diagonal_inches < 7.0 else &"tablet"
		var aspect := float(longest_px) / maxf(1.0, float(shortest_px))
		# With no trustworthy physical-size data, aspect is the only stable
		# distinction available: modern landscape phones commonly exceed 900 px
		# on the short edge, while tablets/foldables remain closer to 16:10/4:3.
		if aspect >= 1.7:
			return &"phone"
		return &"tablet"
	return &"desktop"

static func apply_content_scale_size(window: Window, layout: Dictionary) -> void:
	if window == null:
		return
	var logical_size: Vector2 = layout.get("logical_size", DESIGN_BASE)
	var next_size := Vector2i(maxi(1, int(roundf(logical_size.x))), maxi(1, int(roundf(logical_size.y))))
	if window.content_scale_size != next_size:
		window.content_scale_size = next_size

func _on_window_size_changed() -> void:
	_recompute_and_emit(false)

func _recompute_and_emit(force_emit: bool) -> void:
	var window := get_window()
	if window == null:
		return
	var window_size := Vector2i(maxi(1, window.size.x), maxi(1, window.size.y))
	if not force_emit and window_size == _last_window_size:
		return
	_last_window_size = window_size

	var device_profile := _detect_device_profile(window_size)
	var base_layout := calculate_layout(Vector2(window_size), Rect2i(), device_profile)
	apply_content_scale_size(window, base_layout)
	var next_layout := calculate_runtime_layout_after_scale(
		Vector2(window_size),
		_get_display_safe_area(),
		device_profile,
		get_viewport().get_stretch_transform().affine_inverse()
	)
	_accept_layout(next_layout, force_emit)
	_queue_safe_area_recompute()

func _accept_layout(next_layout: Dictionary, force_emit: bool) -> void:
	if force_emit or not _layouts_equal(_layout, next_layout):
		_layout = next_layout
		layout_changed.emit(current_layout())

func _queue_safe_area_recompute() -> void:
	if _safe_recompute_queued:
		return
	_safe_recompute_queued = true
	call_deferred("_finalize_safe_area_after_scale")

func _finalize_safe_area_after_scale() -> void:
	_safe_recompute_queued = false
	var window := get_window()
	if window == null:
		return
	var window_size := Vector2i(maxi(1, window.size.x), maxi(1, window.size.y))
	var device_profile := _detect_device_profile(window_size)
	var final_layout := calculate_runtime_layout_after_scale(
		Vector2(window_size),
		_get_display_safe_area(),
		device_profile,
		get_viewport().get_stretch_transform().affine_inverse()
	)
	_accept_layout(final_layout, false)

func _get_display_safe_area() -> Rect2i:
	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return Rect2i()
	return safe_area

func _detect_device_profile(window_size: Vector2i) -> StringName:
	var screen_size := DisplayServer.screen_get_size()
	var dpi := DisplayServer.screen_get_dpi()
	return detect_device_profile(screen_size, dpi, window_size, OS.has_feature("mobile"))

func _layouts_equal(a: Dictionary, b: Dictionary) -> bool:
	return a.get("profile", &"") == b.get("profile", &"") \
		and a.get("logical_size", Vector2.ZERO) == b.get("logical_size", Vector2.ZERO) \
		and a.get("safe_insets", Vector4.ZERO) == b.get("safe_insets", Vector4.ZERO) \
		and is_equal_approx(float(a.get("ui_scale", 0.0)), float(b.get("ui_scale", 0.0))) \
		and bool(a.get("is_mobile", false)) == bool(b.get("is_mobile", false))
