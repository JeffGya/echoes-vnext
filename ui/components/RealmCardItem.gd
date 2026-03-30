# res://ui/components/RealmCardItem.gd
# UI-003: Reusable realm card for the 3-column grid on RealmSelectScreen.
# Data bind only — no colors. All styling via Godot theme.

class_name RealmCardItem
extends PanelContainer

signal card_pressed(realm_id: String)

@export var alpha_locked: float = 0.4

@onready var realm_name_label: Label  = %RealmName
@onready var virtue_label: Label      = %VirtueLabel
@onready var status_label: Label      = %StatusLabel

var _realm_id: String = ""

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func setup(r: Dictionary) -> void:
	_realm_id             = str(r.get("id", ""))
	realm_name_label.text = str(r.get("name", _realm_id))
	virtue_label.text     = str(r.get("virtue", "")).capitalize()
	var locked: bool      = bool(r.get("locked", false))
	var status: String    = str(r.get("status", "not_started"))
	status_label.text     = _status_text(locked, status)
	status_label.theme_type_variation = _status_theme_key(locked, status)
	modulate.a            = alpha_locked if locked else 1.0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_pressed.emit(_realm_id)

func _status_text(locked: bool, status: String) -> String:
	if locked:
		return "Locked"
	match status:
		"in_progress": return "In progress"
		"completed":   return "Completed"
		_:             return "Not started"

func _status_theme_key(locked: bool, status: String) -> StringName:
	if locked:
		return &"StatusBadge.Locked"
	match status:
		"in_progress": return &"StatusBadge.InProgress"
		"completed":   return &"StatusBadge.Completed"
		_:             return &"StatusBadge.NotStarted"
