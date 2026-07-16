class_name ModalHost
extends Control

signal action_requested(action: Dictionary)
signal modal_dismissed(modal_id: StringName)

@onready var _dim_backdrop: ColorRect = %DimBackdrop
@onready var _input_blocker: Control = %InputBlocker
@onready var _modal_slot: Control = %ModalSlot

var _active_modal: Control = null
var _active_modal_id: StringName = &""
var _previous_focus: Control = null

func _ready() -> void:
	_ensure_nodes()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.gui_input.connect(_on_input_blocker_gui_input)
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_focus_changed.connect(_on_gui_focus_changed)

func has_active_modal() -> bool:
	return _active_modal != null and is_instance_valid(_active_modal)

func active_modal_id() -> StringName:
	return _active_modal_id

func present_modal_for_id(modal_id: StringName, scene: PackedScene, payload: Dictionary = {}) -> bool:
	if modal_id == &"":
		return false
	if has_active_modal():
		if _active_modal_id == modal_id:
			if _active_modal.has_method("present"):
				_active_modal.call("present", payload)
			_ensure_modal_focus()
			return true
		return false
	if _present_modal_scene(scene, payload):
		_active_modal_id = modal_id
		return true
	return false

func present_modal(scene: PackedScene, payload: Dictionary = {}) -> bool:
	if has_active_modal():
		return false
	if _present_modal_scene(scene, payload):
		_active_modal_id = &""
		return true
	return false

func _present_modal_scene(scene: PackedScene, payload: Dictionary = {}) -> bool:
	_ensure_nodes()
	if scene == null or has_active_modal():
		return false
	var viewport := get_viewport()
	_previous_focus = viewport.gui_get_focus_owner() if viewport != null else null
	var modal := scene.instantiate() as Control
	if modal == null:
		return false
	_modal_slot.add_child(modal)
	_active_modal = modal
	visible = true
	if modal.has_signal("action_requested"):
		modal.connect("action_requested", Callable(self, "_on_modal_action_requested"))
	if modal.has_signal("dismiss_requested"):
		modal.connect("dismiss_requested", Callable(self, "_on_modal_dismiss_requested"))
	if modal.has_method("present"):
		modal.call("present", payload)
	_ensure_modal_focus()
	return true

func dismiss_modal() -> void:
	var dismissed_id := _active_modal_id
	if _active_modal != null and is_instance_valid(_active_modal):
		# A modal action may synchronously dispatch a snapshot that presents the next
		# modal before queued deletion runs. Hide the outgoing instance immediately
		# so two blocking surfaces can never render during that handoff frame.
		_active_modal.visible = false
		_active_modal.queue_free()
	_active_modal = null
	_active_modal_id = &""
	visible = false
	if _previous_focus != null and is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_grab_focus_safely(_previous_focus)
	_previous_focus = null
	if dismissed_id != &"":
		modal_dismissed.emit(dismissed_id)

func _ensure_nodes() -> void:
	if _dim_backdrop == null:
		_dim_backdrop = get_node_or_null("DimBackdrop") as ColorRect
	if _input_blocker == null:
		_input_blocker = get_node_or_null("InputBlocker") as Control
	if _modal_slot == null:
		_modal_slot = get_node_or_null("InputBlocker/ModalSlot") as Control

func _on_input_blocker_gui_input(event: InputEvent) -> void:
	var is_pressed_pointer := (
		(event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	)
	if has_active_modal() and is_pressed_pointer:
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if has_active_modal() and (
		event is InputEventAction
		or event is InputEventKey
		or event is InputEventJoypadButton
		or event is InputEventJoypadMotion
	):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _on_gui_focus_changed(control: Control) -> void:
	if not has_active_modal():
		return
	if not _is_valid_modal_focus(control):
		_focus_first_control(_active_modal)

func _on_modal_action_requested(action: Dictionary) -> void:
	action_requested.emit(action)

func _on_modal_dismiss_requested() -> void:
	dismiss_modal()

func _focus_first_control(root: Control) -> void:
	var candidate := _find_focusable(root)
	if candidate != null:
		_grab_focus_safely(candidate)

func _contain_focus() -> void:
	_ensure_modal_focus()

func _ensure_modal_focus() -> void:
	if _active_modal == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var focus_owner := viewport.gui_get_focus_owner()
	if not _is_valid_modal_focus(focus_owner):
		_focus_first_control(_active_modal)

func _is_valid_modal_focus(control: Control) -> bool:
	if control == null or not has_active_modal():
		return false
	if control != _active_modal and not _active_modal.is_ancestor_of(control):
		return false
	if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree():
		return false
	return not _is_disabled_focus_candidate(control)

func _grab_focus_safely(control: Control) -> void:
	control.grab_focus()
	if not control.has_focus():
		control.grab_focus.call_deferred()

func _find_focusable(root: Node) -> Control:
	if root is Control:
		var ctrl := root as Control
		if ctrl.focus_mode != Control.FOCUS_NONE and ctrl.is_visible_in_tree() and not _is_disabled_focus_candidate(ctrl):
			return ctrl
	for child in root.get_children():
		var found := _find_focusable(child)
		if found != null:
			return found
	return null

func _is_disabled_focus_candidate(control: Control) -> bool:
	if control is BaseButton:
		return (control as BaseButton).disabled
	if control is LineEdit:
		return not (control as LineEdit).editable
	if control is TextEdit:
		return not (control as TextEdit).editable
	return false
