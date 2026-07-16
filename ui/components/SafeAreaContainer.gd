class_name SafeAreaContainer
extends MarginContainer

@export var base_margin: int = 16
@export var bottom_chrome_reservation: int = 0

var _layout: Dictionary = {}

func set_layout(layout: Dictionary) -> void:
	_layout = layout.duplicate(true)
	_apply_margins()

func current_layout() -> Dictionary:
	return _layout.duplicate(true)

func set_bottom_chrome_reservation(value: int) -> void:
	bottom_chrome_reservation = maxi(0, value)
	_apply_margins()

func _ready() -> void:
	_apply_margins()

func _apply_margins() -> void:
	var insets: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	add_theme_constant_override("margin_left", maxi(base_margin, int(ceilf(insets.x))))
	add_theme_constant_override("margin_top", maxi(base_margin, int(ceilf(insets.y))))
	add_theme_constant_override("margin_right", maxi(base_margin, int(ceilf(insets.z))))
	var chrome_gap := 8 if bottom_chrome_reservation > 0 else 0
	var bottom_edge := maxi(base_margin, int(ceilf(insets.w)))
	add_theme_constant_override("margin_bottom", bottom_edge + bottom_chrome_reservation + chrome_gap)
