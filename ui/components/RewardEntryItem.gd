# res://ui/components/RewardEntryItem.gd
# UI-003: Reward breakdown row for ResolveScreen.
# Purposeful colors (positive/negative delta) via @export so they are
# adjustable in the Godot editor / .tscn inspector.

class_name RewardEntryItem
extends HBoxContainer

@export var color_positive: Color = Color("#f0e8d0")
@export var color_negative: Color = Color("#908870")
@export var color_ekwan: Color = Color(0.91, 0.627, 0.188, 1)

@onready var entry_label: Label = %EntryLabel
@onready var delta_label: Label = %DeltaLabel

func setup(entry: Dictionary) -> void:
	var delta    := int(entry.get("delta", 0))
	var currency := str(entry.get("currency", "ase"))
	entry_label.text = str(entry.get("label", ""))
	var currency_label := "Ase" if currency == "ase" else "Ekwan"
	if delta >= 0:
		delta_label.text = "+%d %s" % [delta, currency_label]
		var pos_color := color_ekwan if currency == "ekwan" else color_positive
		delta_label.add_theme_color_override("font_color", pos_color)
	else:
		delta_label.text = "\u2212%d %s" % [abs(delta), currency_label]
		delta_label.add_theme_color_override("font_color", color_negative)
