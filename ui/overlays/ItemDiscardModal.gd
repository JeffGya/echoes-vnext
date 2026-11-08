extends Control

## The destroy confirmation (ModalHost, layer 40). Default focus is `Keep`. Esc, Back, B and a tap outside
## the card all mean `Keep`. `Destroy` ignores presses for 0.25 s after the card opens. A stack asks how many
## (default the whole stack, minimum 1). No hold, swipe or drag confirms. One press sends one action.
## payload: { row, box, slot, stack, count_max, path, layout }.

signal action_requested(action: Dictionary)
signal dismiss_requested

const ItemUiText := preload("res://ui/components/ItemUiText.gd")
const OPEN_WINDOW_SECONDS := 0.25

@onready var _safe_frame: MarginContainer = %SafeFrame
@onready var _outside: Button = %Outside
@onready var _title: Label = %TitleLabel
@onready var _tile: Button = %Tile
@onready var _name: Label = %NameLabel
@onready var _path_line: Label = %PathLabel
@onready var _picker: HBoxContainer = %Picker
@onready var _picker_label: Label = %PickerLabel
@onready var _minus: Button = %MinusButton
@onready var _count_out: Label = %CountOutput
@onready var _plus: Button = %PlusButton
@onready var _keep: Button = %KeepButton
@onready var _let_go: Button = %LetGoButton

var _box := ""
var _slot := -1
var _stack := false
var _max := 1
var _count := 1
var _armed := false
var _sent := false
var _arm: Tween = null


func _ready() -> void:
	_outside.pressed.connect(_on_keep)
	_keep.pressed.connect(_on_keep)
	_let_go.pressed.connect(_on_let_go)
	_minus.pressed.connect(_step.bind(-1))
	_plus.pressed.connect(_step.bind(1))
	_title.text = ItemUiText.MODAL_TITLE
	_keep.text = ItemUiText.BTN_KEEP
	_let_go.text = ItemUiText.BTN_LET_GO
	_picker_label.text = ItemUiText.MODAL_COUNT_LABEL
	_minus.tooltip_text = ItemUiText.COUNT_FEWER
	_plus.tooltip_text = ItemUiText.COUNT_MORE


func present(payload: Dictionary) -> void:
	var layout_v: Variant = payload.get("layout", {})
	if layout_v is Dictionary and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", layout_v)
	var row_v: Variant = payload.get("row", {})
	var row: Dictionary = row_v if row_v is Dictionary else {}
	_box = str(payload.get("box", ""))
	_slot = int(payload.get("slot", -1))
	_stack = bool(payload.get("stack", false))
	_max = maxi(1, int(payload.get("count_max", 1)))
	_count = _max
	_sent = false
	_tile.setup(row, { "box": _box, "bed": 72 })
	_name.text = ItemUiText.display_name(row)
	_path_line.text = ItemUiText.MODAL_PATH_LINE
	_path_line.visible = bool(payload.get("path", false))
	_picker.visible = _stack
	_sync_picker()
	_armed = false
	_let_go.disabled = false
	if _arm != null and _arm.is_valid():
		_arm.kill()
	_arm = create_tween()
	_arm.tween_interval(OPEN_WINDOW_SECONDS)
	_arm.tween_callback(func() -> void: _armed = true)
	_keep.grab_focus()


func is_armed() -> bool:
	return _armed


func count() -> int:
	return _count


func _step(delta: int) -> void:
	_count = clampi(_count + delta, 1, _max)
	_sync_picker()


func _sync_picker() -> void:
	_count_out.text = ItemUiText.stack_count(_count, _max)


func _on_keep() -> void:
	if _sent:
		return
	dismiss_requested.emit()


func _on_let_go() -> void:
	if _sent or not _armed:
		return
	_sent = true
	_let_go.disabled = true
	_keep.disabled = true
	var payload := { "from": _box, "slot": _slot }
	if _stack:
		payload["count"] = _count
	dismiss_requested.emit()
	action_requested.emit({ "type": "inventory.discard.apply", "payload": payload })


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_keep()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree():
		_on_keep()
