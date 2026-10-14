# res://ui/screens/venture/DirectiveBadge.gd
# V2-STAGE-004 Phase 5: HUD strip badge showing the active exploration directive.
#
# Visual structure (glyph label, directive label, left-edge tint bar) is authored in
# StageExploreScreen.tscn. This script only sets label text and the tint-bar colour.
#
# Label and tint come from the snapshot's `directive` dict. A directive with no `tint` key gets the
# neutral tint. The badge hides when the dict has no label (old snapshots render as today).

extends PanelContainer

const _COLOR_NEUTRAL := Color(0.45, 0.45, 0.52, 1.0)

@onready var _tint_bar:    ColorRect = %DirectiveTintBar
@onready var _glyph_label: Label     = %DirectiveGlyphLabel
@onready var _text_label:  Label     = %DirectiveTextLabel


## Populate from the snapshot's `directive` dict { id, label, tint? }. Hides when it has no label.
func set_directive(directive: Dictionary) -> void:
	var label := str(directive.get("label", ""))
	visible = not label.is_empty()
	if not visible:
		return
	_text_label.text = label
	var tint: Color = Color.html(str(directive["tint"])) if str(directive.get("tint", "")).is_valid_html_color() else _COLOR_NEUTRAL
	_tint_bar.color = tint
	_glyph_label.add_theme_color_override("font_color", tint)
