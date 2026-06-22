class_name EmotionChip
extends PanelContainer

const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")

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
	var normalized := EmotionPresentation.normalize(status)
	_label.text = EmotionPresentation.display_name(normalized)
	theme_type_variation = EmotionPresentation.chip_theme(normalized)
	_label.theme_type_variation = EmotionPresentation.chip_label_theme(normalized)
