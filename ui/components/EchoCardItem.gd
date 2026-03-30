# res://ui/components/EchoCardItem.gd
# UI-003: Echo status card for RealmShell bottom bar.
# Handles two data shapes:
#   Encounter/Resolve: { name, hp, max_hp, morale_status, faction }
#   Stage/StageMap:    { name, rank, calling_origin }
# Data bind only — no colors. All styling via Godot theme.

class_name EchoCardItem
extends PanelContainer

@onready var hp_bar: ProgressBar     = %HpBar
@onready var hp_label: Label         = %HpLabel
@onready var portrait_label: Label   = %PortraitLabel
@onready var name_label: Label       = %NameLabel
@onready var status_label: Label     = %StatusLabel

func setup(actor: Dictionary) -> void:
	var name_str := str(actor.get("name", "?"))
	name_label.text    = name_str
	portrait_label.text = name_str.substr(0, 2).to_upper()

	if actor.has("hp") and actor.has("max_hp"):
		var hp: int = int(actor.get("hp", 0))
		var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
		hp_bar.max_value = max_hp
		hp_bar.value = clampi(hp, 0, max_hp)
		hp_label.text  = "HP %d/%d" % [hp, max_hp]
		hp_bar.visible = true
	else:
		hp_bar.visible = false

	if actor.has("morale_status"):
		status_label.text = str(actor.get("morale_status", "Normal"))
	else:
		status_label.text = str(actor.get("calling_origin", "Ready"))
