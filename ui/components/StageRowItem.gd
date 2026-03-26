# res://ui/components/StageRowItem.gd
# UI-003: Stage list row for StageMapScreen left panel.
# Data bind only — no colors. All styling via Godot theme.

class_name StageRowItem
extends HBoxContainer

@onready var badge_label: Label        = %BadgeLabel
@onready var stage_name: RichTextLabel = %StageName

func setup(stage: Dictionary) -> void:
	var status    := str(stage.get("status", "locked"))
	var name_str  := str(stage.get("name", "Unknown stage"))
	var obj_count := int(stage.get("objective_count", 0))
	var obj_suffix := " (%d obj)" % obj_count if obj_count > 0 else ""

	badge_label.text = _badge_text(status)

	if status == "completed":
		stage_name.text = "[s]%s%s[/s]" % [name_str, obj_suffix]
	else:
		stage_name.text = "%s%s" % [name_str, obj_suffix]

func _badge_text(status: String) -> String:
	match status:
		"completed":              return "Completed"
		"current", "not_started": return "Not started"
		_:                        return "Locked"
