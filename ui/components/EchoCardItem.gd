# res://ui/components/EchoCardItem.gd
# UI-003: Echo status card for RealmShell bottom bar.
# Handles two data shapes:
#   Encounter/Resolve: { name, hp, max_hp, emotional_status, faction }
#   Stage/StageMap:    { name, rank, calling_origin, emotional_status }
# Data bind only — no colors. All styling via Godot theme.
# V2-EMOTION-002: emotional_status is the sole player-facing feeling field.
# V2-STAGE-004 P3c: an optional GUIDE_SPIRIT ally variant — same card, gold accent +
#   "◆ SPIRIT" badge + objective progress line. Toggled via setup_spirit(); the plain
#   setup() path leaves the spirit nodes hidden and the panel untouched (pixel-identical).

class_name EchoCardItem
extends PanelContainer

const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")

# Gold accent border applied only to the spirit ally slot (Akan Gold). Authored declaratively
# as a standalone StyleBox resource; script only toggles it on for the spirit variant.
const _SPIRIT_PANEL_STYLE: StyleBox = preload("res://ui/components/EchoCardSpiritAccent.tres")

@onready var hp_bar: ProgressBar     = %HpBar
@onready var hp_label: Label         = %HpLabel
@onready var portrait_label: Label   = %PortraitLabel
@onready var name_label: Label       = %NameLabel
@onready var status_label: Label     = %StatusLabel
@onready var spirit_badge: Label     = %SpiritBadge
@onready var progress_label: Label   = %ProgressLabel

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

	var status := EmotionPresentation.normalize(str(actor.get("emotional_status", "")))
	status_label.text = EmotionPresentation.display_name(status)
	status_label.theme_type_variation = EmotionPresentation.text_theme(status)

## Applies the base card bind, then promotes the card to the distinct GUIDE_SPIRIT ally
## slot: reveals the gold badge + objective-progress line and paints the gold accent border.
## progress_text is pre-composed by the shell from objective_state (e.g. "3 rounds left",
## "Arrived", "Fallen"). Non-spirit cards never call this — they stay visually identical.
func setup_spirit(actor: Dictionary, progress_text: String) -> void:
	setup(actor)
	spirit_badge.visible   = true
	progress_label.visible = not progress_text.is_empty()
	progress_label.text    = progress_text
	# Gold left-border accent — authored as EchoCardSpiritAccent.tres, toggled on here only.
	add_theme_stylebox_override("panel", _SPIRIT_PANEL_STYLE)
