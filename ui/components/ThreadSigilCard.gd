class_name ThreadSigilCard
extends PanelContainer

signal selected(thread_id: String)

@onready var _name_label: Label = %ThreadNameLabel
@onready var _virtue_label: Label = %ThreadVirtueLabel
@onready var _quality_label: Label = %ThreadQualityLabel
@onready var _select_button: Button = %ThreadSelectButton

var _thread_id: String = ""


func _ready() -> void:
	_select_button.pressed.connect(_on_select_pressed)


func bind_thread(thread: Dictionary, selected_active: bool = false, button_label: String = "Offer") -> void:
	_thread_id = str(thread.get("id", ""))
	var display_name := str(thread.get("display_name", "Thread"))
	if display_name.is_empty():
		display_name = "Thread"
	_name_label.text = display_name
	_virtue_label.text = _title_case(str(thread.get("virtue", "unknown")))
	_quality_label.text = _title_case(str(thread.get("quality_tier", "broken")))
	_select_button.text = "Selected" if selected_active else button_label
	_select_button.disabled = selected_active or _thread_id.is_empty()
	modulate = Color(1.0, 0.92, 0.72) if selected_active else Color(1, 1, 1)
	visible = true


func set_selectable(enabled: bool) -> void:
	_select_button.visible = enabled


func _on_select_pressed() -> void:
	if not _thread_id.is_empty():
		selected.emit(_thread_id)


func _title_case(value: String) -> String:
	if value.is_empty():
		return ""
	return value.substr(0, 1).to_upper() + value.substr(1)
