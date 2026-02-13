extends VBoxContainer

class_name DebugPanel

@onready var output: RichTextLabel = %DebugOuput
@onready var input: LineEdit = %DebugInput
@onready var send_button: Button = %DebugSend

signal command_submitted(command: String)

func _ready() -> void:
	send_button.pressed.connect(_on_send_pressed)
	input.text_submitted.connect(_on_text_submitted)
	
	_append_line("Debug ready. Type a command and press Enter.")
	
func _on_send_pressed() -> void:
	_submit_current()
	
func _on_text_submitted(_text: String) -> void:
	_submit_current()
	
func _submit_current() -> void:
	var cmd := input.text.strip_edges()
	if cmd.is_empty():
		return
		
	_append_line("> " + cmd)
	input.clear()
	emit_signal("command_submitted", cmd)
	
func _append_line(line: String) -> void:
	#Keep it simple for MVP
	output.append_text(line + "\n")
