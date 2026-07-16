extends Control
class_name VowMomentModal

signal action_requested(action: Dictionary)
signal dismiss_requested()

@onready var title_label: Label = %TitleLabel
@onready var safe_frame: MarginContainer = %SafeFrame
@onready var twi_label: Label = %TwiLabel
@onready var en_label: Label = %EnLabel
@onready var penalty_label: Label = %PenaltyLabel
@onready var secondary_button: Button = %SecondaryButton
@onready var primary_button: Button = %PrimaryButton

var _mode := "pledge"
var _confirm_action: Dictionary = {}

func _ready() -> void:
	secondary_button.pressed.connect(_on_secondary_pressed)
	primary_button.pressed.connect(_on_primary_pressed)

func present(payload: Dictionary) -> void:
	_mode = str(payload.get("mode", "pledge"))
	_confirm_action = payload.get("confirm_action", {}) if payload.get("confirm_action", {}) is Dictionary else {}
	if payload.get("layout", {}) is Dictionary:
		set_layout(payload.get("layout", {}) as Dictionary)
	secondary_button.visible = true
	primary_button.visible = true
	twi_label.visible = true
	en_label.visible = true
	penalty_label.visible = false
	twi_label.text = ""
	en_label.text = ""
	penalty_label.text = ""
	if _mode == "break":
		title_label.text = "Are you certain?"
		twi_label.text = str(payload.get("name", ""))
		en_label.text = ""
		en_label.visible = false
		penalty_label.text = str(payload.get("penalty", ""))
		penalty_label.visible = not penalty_label.text.is_empty()
		secondary_button.text = "Keep My Word"
		primary_button.text = "Break the Vow"
	else:
		title_label.text = "The web remembers."
		twi_label.text = str(payload.get("proverb_twi", ""))
		en_label.text = "\"%s\"" % str(payload.get("proverb_en", ""))
		penalty_label.visible = false
		secondary_button.visible = false
		primary_button.text = "Continue"

func set_layout(layout: Dictionary) -> void:
	var frame := safe_frame if safe_frame != null else find_child("SafeFrame", true, false) as MarginContainer
	if frame != null and frame.has_method("set_layout"):
		frame.call("set_layout", layout)

func _on_secondary_pressed() -> void:
	dismiss_requested.emit()

func _on_primary_pressed() -> void:
	if _mode == "break" and not _confirm_action.is_empty():
		dismiss_requested.emit()
		action_requested.emit(_confirm_action.duplicate(true))
		return
	dismiss_requested.emit()
