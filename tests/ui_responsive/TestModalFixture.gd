extends Control
class_name TestModalFixture

signal action_requested(action: Dictionary)
signal dismiss_requested

@onready var first_button: Button = %FirstButton
@onready var second_button: Button = %SecondButton
@onready var dismiss_button: Button = %DismissButton

var present_calls: int = 0
var last_payload: Dictionary = {}

func _ready() -> void:
	first_button.pressed.connect(_on_first_pressed)
	dismiss_button.pressed.connect(_on_dismiss_pressed)

func present(payload: Dictionary) -> void:
	present_calls += 1
	last_payload = payload.duplicate(true)

func _on_first_pressed() -> void:
	action_requested.emit({ "type": "fixture.action", "value": last_payload.get("value", 0) })

func _on_dismiss_pressed() -> void:
	dismiss_requested.emit()
