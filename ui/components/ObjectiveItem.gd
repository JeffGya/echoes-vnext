# res://ui/components/ObjectiveItem.gd
# UI-003: Objective line item for StageScreen and StageMapScreen right panel.
# Data bind only — no colors.

class_name ObjectiveItem
extends HBoxContainer

@onready var index_label: Label = %IndexLabel
@onready var desc_label: Label  = %DescLabel

func setup(obj: Dictionary) -> void:
	index_label.text = "%d." % (int(obj.get("obj_index", 0)) + 1)
	var type_label  := str(obj.get("obj_type", "")).capitalize()
	var desc        := str(obj.get("obj_description", ""))
	desc_label.text  = "%s — %s" % [type_label, desc]
