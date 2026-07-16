extends Control
class_name CallingInfoModal

signal dismiss_requested()

@onready var title_label: Label = %CallingInfoTitle
@onready var desc_label: Label = %CallingInfoDesc
@onready var close_button: Button = %CallingInfoClose
@onready var safe_frame: MarginContainer = %SafeFrame

func _ready() -> void:
	close_button.pressed.connect(func() -> void:
		dismiss_requested.emit()
	)

func present(payload: Dictionary) -> void:
	if payload.get("layout", {}) is Dictionary:
		set_layout(payload.get("layout", {}) as Dictionary)
	title_label.text = str(payload.get("title", ""))
	desc_label.text = str(payload.get("description", ""))

func set_layout(layout: Dictionary) -> void:
	var frame := safe_frame if safe_frame != null else find_child("SafeFrame", true, false) as MarginContainer
	if frame != null and frame.has_method("set_layout"):
		frame.call("set_layout", layout)
