# res://ui/components/EchoCardItem.gd
# UI-003: Echo status card for RealmShell bottom bar.
# Handles two data shapes:
#   Encounter/Resolve: { name, hp, max_hp, morale_tier, morale_status, fear_signal, faction }
#   Stage/StageMap:    { name, rank, calling_origin, morale_tier, fear_signal }
# Data bind only — no colors. All styling via Godot theme.

class_name EchoCardItem
extends PanelContainer

@onready var hp_bar: ProgressBar     = %HpBar
@onready var hp_label: Label         = %HpLabel
@onready var portrait_label: Label   = %PortraitLabel
@onready var name_label: Label       = %NameLabel
@onready var status_label: Label     = %StatusLabel
@onready var fear_badge: Label       = %FearBadge

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

	# V2-EMOTION-001: morale_tier (morale-derived) takes priority over legacy morale_status (fear-derived).
	if actor.has("morale_tier"):
		var tier := str(actor.get("morale_tier", "steady")).to_lower()
		status_label.text = _morale_text(tier)
		status_label.theme_type_variation = _morale_theme_key(tier)
	elif actor.has("morale_status"):
		var morale_status := str(actor.get("morale_status", "steady")).to_lower()
		status_label.text = _morale_text(morale_status)
		status_label.theme_type_variation = _morale_theme_key(morale_status)
	else:
		status_label.text = str(actor.get("calling_origin", "Ready"))
		status_label.theme_type_variation = &"EmotionBadge.Ready"

	# V2-EMOTION-001: fear signal badge — only shown when fear is above calm.
	var fear_signal := str(actor.get("fear_signal", "calm"))
	fear_badge.visible = fear_signal != "" and fear_signal != "calm"
	fear_badge.text    = fear_signal.capitalize()

func _morale_text(morale_status: String) -> String:
	match morale_status:
		"inspired": return "Inspired"
		"steady":   return "Steady"
		"shaken":   return "Shaken"
		"broken":   return "Broken"
		_:          return morale_status.capitalize()

func _morale_theme_key(morale_status: String) -> StringName:
	match morale_status:
		"inspired": return &"EmotionBadge.Inspired"
		"steady":   return &"EmotionBadge.Steady"
		"shaken":   return &"EmotionBadge.Shaken"
		"broken":   return &"EmotionBadge.Broken"
		_:          return &"EmotionBadge.Ready"
