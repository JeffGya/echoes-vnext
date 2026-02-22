# SanctumScreen.gd

extends Control

class_name SanctumScreen

@onready var title_label: Label = %TitleLabel
@onready var ase_label: Label = %AseLabel
@onready var ase_rate_label: Label = %AseRateLabel
@onready var ase_delta_label: Label = %AseDeltaLabel
@onready var echo_count_label : Label = %EchoCountLabel
@onready var buttons : VBoxContainer = %Buttons

@onready var name_modal: Control = %NameModal
@onready var name_edit: LineEdit = %NameEdit
@onready var reroll_button: Button = %RerollButton
@onready var confirm_button: Button = %ConfirmButton

var _dispatch: Callable = Callable()
var _snapshot: Dictionary = {}
var _name_dirty := false

var _last_ase_balance: int = -1
var _ase_tween: Tween

func set_dispatch(dispatch_fn: Callable) -> void:
	_dispatch = dispatch_fn

func set_snapshot(snap: Dictionary) -> void:
	_snapshot = snap
	_render()
	
func _render() -> void:
	var data_v = _snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var ase_balance := int(data.get("ase_balance", 0))
	var per_hour := float(data.get("ase_rate_per_hour_hint", 0.0))

	var sanctum_name := str(data.get("sanctum_name", ""))
	var suggested := str(data.get("sanctum_name_suggested", "Sanctum"))
		
	title_label.text = sanctum_name if sanctum_name != "" else "Sanctum"
	ase_label.text = "Ase: %d" % ase_balance
	ase_rate_label.text = "~ %.1f Ase gathered p/h" % per_hour
	echo_count_label.text = "Echoes in sanctum: %d" % int(data.get("roster_count", 0))

	# Ase animate on change
	if _last_ase_balance != -1 and ase_balance != _last_ase_balance:
		var delta := ase_balance - _last_ase_balance
		_show_ase_delta(delta)
		_pulse_ase_label()

	_last_ase_balance = ase_balance

	# Rebuild buttons from snapshot actions
	for c in buttons.get_children():
		c.queue_free()
		
	var actions_v = _snapshot.get("actions", [])
	var actions: Array = actions_v if actions_v is Array else []
	
	for action in actions:
		if not (action is Dictionary):
			continue
			
		var b := Button.new()
		b.text = str(action.get("label", "Action"))
		b.disabled = bool(action.get("disabled", false))
		b.pressed.connect(func():
			if _dispatch.is_valid():
				_dispatch.call(action)
		)
		buttons.add_child(b)
	
	if sanctum_name == "":
		# Modal opening edge: reset dirty so first suggestion shows and rerolls work
		if not name_modal.visible:
			_name_dirty = false

		name_modal.visible = true

		# Keep synced to suggestion unless user has started typing
		if not _name_dirty:
			name_edit.text = suggested

		name_edit.grab_focus()
	else:
		name_modal.visible = false

func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	name_edit.text_changed.connect(_on_name_edit_changed)


# Helpers
func _on_name_edit_changed(_new_text: String) -> void:
	_name_dirty = true

func _on_reroll_pressed() -> void:
	if _dispatch.is_valid():
		_dispatch.call({ "type": "sanctum.name.reroll" })

func _on_confirm_pressed() -> void:
	if _dispatch.is_valid():
		_dispatch.call({ "type": "sanctum.name.confirm", "name": name_edit.text })

func _pulse_ase_label() -> void:
	if _ase_tween != null and _ase_tween.is_running():
		_ase_tween.kill()

	ase_label.scale = Vector2.ONE
	_ase_tween = create_tween()
	_ase_tween.tween_property(ase_label, "scale", Vector2(1.04, 1.04), 0.08)
	_ase_tween.tween_property(ase_label, "scale", Vector2.ONE, 0.12)

func _show_ase_delta(delta: int) -> void:
	ase_delta_label.visible = true
	ase_delta_label.text = ("%+d" % delta) # shows +5 / -2

	var start_y := ase_delta_label.position.y
	ase_delta_label.modulate.a = 1.0

	var tw := create_tween()
	tw.tween_property(ase_delta_label, "position:y", start_y - 6.0, 0.25)
	tw.tween_property(ase_delta_label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		ase_delta_label.visible = false
		ase_delta_label.position.y = start_y
	)
	
