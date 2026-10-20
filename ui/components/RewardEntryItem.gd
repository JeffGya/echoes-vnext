# res://ui/components/RewardEntryItem.gd
# One payout row on the Resolve card. A row with a known `cause` gets an (i) button; hover, focus
# or tap on it asks the screen's CauseTooltip to open (the tooltip is not a child of this row).
# Colors are @export so they stay adjustable in the .tscn inspector.

class_name RewardEntryItem
extends HBoxContainer

## anchor is the (i) button. `pinned` is true when the player tapped it, false for hover or focus.
signal cause_requested(anchor: Control, title: String, cause: String, params: Dictionary, scope: String, pinned: bool)
## force is false for a mouse leaving (a tapped tooltip stays) and true for focus leaving.
signal cause_released(anchor: Control, force: bool)

const PayoutCausePresentation := preload("res://ui/components/PayoutCausePresentation.gd")

@export var color_positive: Color = Color("#f0e8d0")
@export var color_negative: Color = Color("#908870")
# A row that earns exactly 0 is muted, not shown as a gain (pace-reward decisions D-28, D-29).
@export var color_zero: Color = Color("#6E6450")

@onready var entry_label: Label = %EntryLabel
@onready var delta_label: Label = %DeltaLabel
@onready var cause_button: Button = %CauseButton
@onready var cause_spacer: Control = %CauseSpacer

var cause: String = ""
var params: Dictionary = {}
var scope: String = PayoutCausePresentation.SCOPE_FIGHT


## scope is "fight" or "stage"; only the Replay text differs between them.
func setup(entry: Dictionary, row_scope: String = PayoutCausePresentation.SCOPE_FIGHT) -> void:
	var delta := int(entry.get("delta", 0))
	cause = str(entry.get("cause", ""))
	var params_v: Variant = entry.get("params", {})
	params = params_v if params_v is Dictionary else {}
	scope = row_scope
	entry_label.text = PayoutCausePresentation.row_name(cause, str(entry.get("label", "")))
	if delta >= 0:
		delta_label.text = "+%d Ase" % delta
		delta_label.add_theme_color_override("font_color", color_zero if delta == 0 else color_positive)
	else:
		delta_label.text = "\u2212%d Ase" % abs(delta)
		delta_label.add_theme_color_override("font_color", color_negative)
	if delta == 0:
		entry_label.add_theme_color_override("font_color", color_zero)
	else:
		entry_label.remove_theme_color_override("font_color")
	var has_cause := PayoutCausePresentation.has_cause(cause)
	cause_button.visible = has_cause
	cause_spacer.visible = not has_cause


func _ready() -> void:
	cause_button.mouse_entered.connect(_request.bind(false))
	cause_button.focus_entered.connect(_request.bind(false))
	cause_button.pressed.connect(_request.bind(true))
	cause_button.mouse_exited.connect(func() -> void: cause_released.emit(cause_button, false))
	cause_button.focus_exited.connect(func() -> void: cause_released.emit(cause_button, true))


func _request(pinned: bool) -> void:
	cause_requested.emit(cause_button, entry_label.text, cause, params, scope, pinned)
