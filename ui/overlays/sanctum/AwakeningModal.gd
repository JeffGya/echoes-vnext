extends Control
class_name AwakeningModal

signal dismiss_requested()

@onready var grant_label: Label = %AwakeningGrantLabel
@onready var dismiss_button: Button = %AwakeningDismiss
@onready var safe_frame: MarginContainer = %SafeFrame

func _ready() -> void:
	dismiss_button.pressed.connect(func() -> void:
		dismiss_requested.emit()
	)

func present(payload: Dictionary) -> void:
	if payload.get("layout", {}) is Dictionary:
		set_layout(payload.get("layout", {}) as Dictionary)
	grant_label.text = "+%d Ase" % int(payload.get("awakening_grant", 40))

func set_layout(layout: Dictionary) -> void:
	var frame := safe_frame if safe_frame != null else find_child("SafeFrame", true, false) as MarginContainer
	if frame != null and frame.has_method("set_layout"):
		frame.call("set_layout", layout)
