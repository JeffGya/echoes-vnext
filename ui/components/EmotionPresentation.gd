class_name EmotionPresentation
extends RefCounted

const DEFAULT_STATUS: String = "hesitant"
const LIVING_TREE_THEME: Theme = preload("res://assets/theme/LivingTreeSystem.tres")
const STATUSES: Array[String] = [
	"radiant", "whole", "grounded", "uncertain", "hesitant",
	"burdened", "pressed", "strained", "fraying", "hollow",
]

static func normalize(status: String) -> String:
	var normalized := status.strip_edges().to_lower()
	return normalized if normalized in STATUSES else DEFAULT_STATUS


static func display_name(status: String) -> String:
	return normalize(status).capitalize()


static func color(status: String) -> Color:
	return LIVING_TREE_THEME.get_color(&"font_color", text_theme(status))


static func chip_theme(status: String) -> StringName:
	return StringName("EmotionChip%s" % display_name(status))


static func chip_label_theme(status: String) -> StringName:
	return StringName("EmotionChipLabel%s" % display_name(status))


static func text_theme(status: String) -> StringName:
	return StringName("EmotionStatus%s" % display_name(status))
