# res://ui/screens/sanctum/EchoRankBenefitGlyph.gd
# V2-PROG-010: Persistent earned rank benefit glyph shown on the Echo detail card.
# Displays an icon (placeholder until Jeff supplies final Akan-styled asset) with an
# expandable tooltip/description that reveals on tap.
#
# Rules (lessons.md):
# - All visual structure is authored in EchoRankBenefitGlyph.tscn.
# - This script only sets values: text, texture, visibility.
# - Never add_child() or create visual nodes here.

class_name EchoRankBenefitGlyph
extends PanelContainer

@onready var _glyph_icon: TextureRect    = %GlyphIcon
@onready var _tooltip_panel: PanelContainer = %TooltipPanel
@onready var _tooltip_label: Label       = %TooltipLabel


func _ready() -> void:
	_tooltip_panel.visible = false
	gui_input.connect(_on_gui_input)


## Sets the benefit data for this glyph.
## Call this from SanctumScreen._apply_snapshot() — never call add_child() or build visual nodes.
func set_benefit(label: String, description: String, icon: Texture2D = null) -> void:
	if _glyph_icon != null:
		if icon != null:
			_glyph_icon.texture = icon
		# Placeholder tooltip label uses the benefit label as alt text when no tooltip is open.
		_glyph_icon.tooltip_text = label
	if _tooltip_label != null:
		_tooltip_label.text = description


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		_tooltip_panel.visible = not _tooltip_panel.visible
		accept_event()
