# res://ui/components/EffectChip.gd
# Phase 1 Close — Unified Resolve: small pill chip for the Effects Rail.
# Renders one effect entry (Ase, Ekwan, objective, vow, item, intel, etc.).
# .gd only sets text/color — all visual structure lives in EffectChip.tscn.

class_name EffectChip
extends PanelContainer

@onready var _label: Label = %ChipLabel

# Palette
const COLOR_GOOD    := Color("#4CAF72")   # Akan Green
const COLOR_GOLD    := Color("#C8A96E")   # Akan Gold
const COLOR_AMBER   := Color("#E8A030")   # Amber
const COLOR_MIST    := Color("#7AB5C8")   # Mist Blue
const COLOR_RED     := Color("#C05050")   # muted red
const COLOR_DEFAULT := Color("#E8D0A0")   # Pale Kente

# kind: "ase" | "ekwan" | "item" | "intel" | "continuity" | "objective" | "storyweight" | "vow"
# tone: "good" | "partial" | "neutral" | "warn" | "bad" | ""
func setup(kind: String, label: String, value: String, tone: String) -> void:
	# Build display text
	var display_text: String = label
	if not value.is_empty() and value != "0":
		display_text = "%s  %s" % [label, value]
	_label.text = display_text

	# Color by tone, then by kind as fallback
	var col: Color
	match tone:
		"good":    col = COLOR_GOOD
		"partial": col = COLOR_GOLD
		"warn":    col = COLOR_AMBER
		"bad":     col = COLOR_RED
		_:
			match kind:
				"ase":         col = COLOR_GOLD
				"ekwan":       col = COLOR_AMBER
				"intel":       col = COLOR_MIST
				"continuity":  col = COLOR_GOLD
				"objective":   col = COLOR_GOOD
				"storyweight": col = COLOR_AMBER
				_:             col = COLOR_DEFAULT
	_label.add_theme_color_override("font_color", col)
