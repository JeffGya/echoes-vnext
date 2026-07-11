# res://ui/screens/venture/DirectiveBadge.gd
# V2-STAGE-004 Phase 5: HUD strip badge showing the active exploration directive.
#
# Visual structure (glyph label, directive label, left-edge tint bar) is authored in
# StageExploreScreen.tscn. This script only sets label text and the tint-bar colour.
#
# Tint is data-driven: the id → colour mapping lives in a dict so adding a future directive
# is one entry. Unknown/absent ids fall back to a neutral tint (and the badge hides when no
# directive is provided) — old snapshots without a `directive` field render as today.

extends PanelContainer

const _COLOR_NEUTRAL := Color(0.45, 0.45, 0.52, 1.0)

# id → left-edge tint. Add a directive by adding one entry here.
const _TINT_BY_ID := {
	"directive.scout_carefully": Color("#7AB5C8"),  # Mist Blue
	"directive.seek_signs":      Color("#C8A96E"),  # Akan Gold
}

@onready var _tint_bar:    ColorRect = %DirectiveTintBar
@onready var _glyph_label: Label     = %DirectiveGlyphLabel
@onready var _text_label:  Label     = %DirectiveTextLabel


## Populate from the snapshot's `directive` dict { id, label }. Hides when empty.
func set_directive(directive: Dictionary) -> void:
	var dir_id := str(directive.get("id", ""))
	var label  := str(directive.get("label", ""))
	if dir_id.is_empty() and label.is_empty():
		visible = false
		return
	visible = true
	_text_label.text = label if not label.is_empty() else _fallback_label(dir_id)
	var tint: Color = _TINT_BY_ID.get(dir_id, _COLOR_NEUTRAL)
	_tint_bar.color = tint
	_glyph_label.add_theme_color_override("font_color", tint)


func _fallback_label(dir_id: String) -> String:
	if dir_id.is_empty():
		return "Directive"
	return dir_id.trim_prefix("directive.").capitalize()
