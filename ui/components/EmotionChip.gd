class_name EmotionChip
extends PanelContainer

@onready var _label: Label = %Label
var _pending_status: String = ""


func _ready() -> void:
	if not _pending_status.is_empty():
		setup(_pending_status)
		_pending_status = ""


func setup(status: String) -> void:
	if not is_node_ready():
		_pending_status = status
		return
	var normalized := status.to_lower()
	_label.text = normalized.capitalize() if not normalized.is_empty() else "Waiting"
	theme_type_variation = _emotion_panel_theme_key(normalized)
	_label.theme_type_variation = _emotion_label_theme_key(normalized)


func _emotion_label_theme_key(status: String) -> StringName:
	match status:
		"radiant", "whole", "inspired":
			return &"EmotionChipLabelInspired"
		"grounded", "burdened", "steady":
			return &"EmotionChipLabelSteady"
		"pressed", "strained", "shaken":
			return &"EmotionChipLabelShaken"
		"fraying", "hollow", "broken":
			return &"EmotionChipLabelBroken"
		_:
			return &"EmotionChipLabelReady"


func _emotion_panel_theme_key(status: String) -> StringName:
	match status:
		"radiant", "whole", "inspired":
			return &"EmotionChipInspired"
		"grounded", "burdened", "steady":
			return &"EmotionChipSteady"
		"pressed", "strained", "shaken":
			return &"EmotionChipShaken"
		"fraying", "hollow", "broken":
			return &"EmotionChipBroken"
		_:
			return &"EmotionChipReady"
