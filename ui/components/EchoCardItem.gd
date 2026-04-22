# res://ui/components/EchoCardItem.gd
# UI-003: Echo status card for RealmShell bottom bar.
# Handles two data shapes:
#   Encounter/Resolve: { name, hp, max_hp, emotional_status, faction }
#   Stage/StageMap:    { name, rank, calling_origin, emotional_status }
# Data bind only — no colors. All styling via Godot theme.
# V2-EMOTION-002: single emotional_status field replaces morale_tier + fear_signal.

class_name EchoCardItem
extends PanelContainer

@onready var hp_bar: ProgressBar     = %HpBar
@onready var hp_label: Label         = %HpLabel
@onready var portrait_label: Label   = %PortraitLabel
@onready var name_label: Label       = %NameLabel
@onready var status_label: Label     = %StatusLabel

func setup(actor: Dictionary) -> void:
	var name_str := str(actor.get("name", "?"))
	name_label.text     = name_str
	portrait_label.text = name_str.substr(0, 2).to_upper()

	if actor.has("hp") and actor.has("max_hp"):
		var hp: int     = int(actor.get("hp", 0))
		var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
		hp_bar.max_value = max_hp
		hp_bar.value     = clampi(hp, 0, max_hp)
		hp_label.text    = "HP %d/%d" % [hp, max_hp]
		hp_bar.visible   = true
	else:
		hp_bar.visible = false

	# V2-EMOTION-002: unified emotional_status; fall back to morale_status for legacy shapes.
	if actor.has("emotional_status"):
		var status := str(actor.get("emotional_status", "burdened")).to_lower()
		status_label.text                = status.capitalize()
		status_label.theme_type_variation = _emotion_theme_key(status)
	elif actor.has("morale_status"):
		var status := str(actor.get("morale_status", "steady")).to_lower()
		status_label.text                = status.capitalize()
		status_label.theme_type_variation = _emotion_theme_key(status)
	else:
		status_label.text                = str(actor.get("calling_origin", "Ready"))
		status_label.theme_type_variation = &"EmotionBadge.Ready"


## Maps an emotional_status tier to the nearest available theme variation.
## New dedicated theme keys can be added per tier as the theme grows.
func _emotion_theme_key(status: String) -> StringName:
	match status:
		"radiant":  return &"EmotionBadge.Inspired"
		"whole":    return &"EmotionBadge.Inspired"
		"grounded": return &"EmotionBadge.Steady"
		"burdened": return &"EmotionBadge.Steady"
		"pressed":  return &"EmotionBadge.Shaken"
		"strained": return &"EmotionBadge.Shaken"
		"fraying":  return &"EmotionBadge.Broken"
		"hollow":   return &"EmotionBadge.Broken"
		# Legacy morale_status fallbacks (encounter actors pre-V2-EMOTION-002)
		"inspired": return &"EmotionBadge.Inspired"
		"steady":   return &"EmotionBadge.Steady"
		"shaken":   return &"EmotionBadge.Shaken"
		"broken":   return &"EmotionBadge.Broken"
		_:          return &"EmotionBadge.Ready"
