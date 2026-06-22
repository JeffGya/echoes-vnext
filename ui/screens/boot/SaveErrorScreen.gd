extends Control

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var detail_label: Label = %DetailLabel

func set_snapshot(snapshot: Dictionary) -> void:
	var data_v: Variant = snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	title_label.text = str(data.get("title", "Campaign Save Needs Attention"))
	message_label.text = str(data.get("message", "The campaign save could not be verified."))
	detail_label.text = str(data.get("detail", "Your save files were left untouched."))
