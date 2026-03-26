# res://ui/components/RewardEntryItem.gd
# UI-003: Reward breakdown row for ResolveScreen.
# Purposeful colors (positive/negative delta) via @export so they are
# adjustable in the Godot editor / .tscn inspector.

class_name RewardEntryItem
extends HBoxContainer

@export var color_positive: Color = Color("#f0e8d0")
@export var color_negative: Color = Color("#908870")

@onready var entry_label: Label = %EntryLabel
@onready var delta_label: Label = %DeltaLabel

func setup(entry: Dictionary) -> void:
	var delta := int(entry.get("delta", 0))
	entry_label.text = str(entry.get("label", ""))
	if delta >= 0:
		delta_label.text = "+%d Ase" % delta
		delta_label.add_theme_color_override("font_color", color_positive)
	else:
		delta_label.text = "\u2212%d Ase" % abs(delta)
		delta_label.add_theme_color_override("font_color", color_negative)
