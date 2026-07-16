# res://ui/screens/venture/DirectiveSelectOverlay.gd
# V2-DIRECTIVE-001: Directive selection overlay for the stage preview screen.
# Shown at every stage entry — player must confirm a directive before the stage can begin.
# Layout and style authored in DirectiveSelectOverlay.tscn. This script only sets values.

extends Control

signal action_requested(action: Dictionary)
signal dismiss_requested

@onready var _tag_0:       Button = %Tag0
@onready var _tag_1:       Button = %Tag1
@onready var _arrow_left:  Button = %ArrowLeft
@onready var _arrow_right: Button = %ArrowRight
@onready var _title:       Label  = %DirectiveTitle
@onready var _description: Label  = %DirectiveDescription
@onready var _pro_0:       Label  = %Pro0
@onready var _pro_1:       Label  = %Pro1
@onready var _con_0:       Label  = %Con0
@onready var _con_1:       Label  = %Con1
@onready var _select_btn:  Button = %SelectButton
@onready var _safe_frame:  MarginContainer = %SafeFrame
@onready var _panel:       PanelContainer = %Panel
@onready var _body_scroll: ScrollContainer = %BodyScroll

var _directives: Array = []
var _active_id:  String = ""
var _preview_idx: int   = 0
var _layout: Dictionary = {}


func _ready() -> void:
	_tag_0.pressed.connect(_on_tag_pressed.bind(0))
	_tag_1.pressed.connect(_on_tag_pressed.bind(1))
	_arrow_left.pressed.connect(_on_arrow_left_pressed)
	_arrow_right.pressed.connect(_on_arrow_right_pressed)
	_select_btn.pressed.connect(_on_select_pressed)


# Called by StageExploreScreen preview mode with snap["data"]["directive"].
func populate(directive_data: Dictionary) -> void:
	_directives  = directive_data.get("directives", [])
	_active_id   = directive_data.get("active_id", "")
	_preview_idx = _find_idx(_active_id)
	_refresh_ui()

func present(payload: Dictionary) -> void:
	var layout_v: Variant = payload.get("layout", {})
	if layout_v is Dictionary:
		set_layout(layout_v)
	var directive_v: Variant = payload.get("directive", {})
	if directive_v is Dictionary:
		populate(directive_v)

func set_layout(layout: Dictionary) -> void:
	_layout = layout.duplicate(true)
	if _safe_frame != null and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", _layout)
	_apply_profile_size()

func _apply_profile_size() -> void:
	var profile := str(_layout.get("profile", "standard"))
	match profile:
		"wide":
			_panel.custom_minimum_size = Vector2(460, 0)
			_body_scroll.custom_minimum_size = Vector2(0, 360)
		"compact":
			_panel.custom_minimum_size = Vector2(360, 0)
			_body_scroll.custom_minimum_size = Vector2(0, 260)
		_:
			_panel.custom_minimum_size = Vector2(400, 0)
			_body_scroll.custom_minimum_size = Vector2(0, 300)


func _find_idx(id: String) -> int:
	for i in _directives.size():
		if str(_directives[i].get("id", "")) == id:
			return i
	return 0


# Updates all text values from _directives[_preview_idx]. No node creation.
func _refresh_ui() -> void:
	if _directives.is_empty():
		return

	# Tag labels + selected state (disabled = currently previewing this one)
	var tags: Array = [_tag_0, _tag_1]
	for i in tags.size():
		if i >= _directives.size():
			(tags[i] as Button).visible = false
			continue
		(tags[i] as Button).text     = str(_directives[i].get("label", ""))
		(tags[i] as Button).disabled = (i == _preview_idx)
		(tags[i] as Button).theme_type_variation = (
			&"SanctumTabButtonActive" if i == _preview_idx else &"SanctumTabButton"
		)

	# Detail panel
	var d: Dictionary = _directives[_preview_idx]
	_title.text       = str(d.get("label", ""))
	_description.text = str(d.get("description", ""))

	var pros: Array = d.get("pros", [])
	_pro_0.text = str(pros[0]) if pros.size() > 0 else ""
	_pro_1.text = str(pros[1]) if pros.size() > 1 else ""

	var cons: Array = d.get("cons", [])
	_con_0.text = str(cons[0]) if cons.size() > 0 else ""
	_con_1.text = str(cons[1]) if cons.size() > 1 else ""


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_tag_pressed(idx: int) -> void:
	_preview_idx = idx
	_refresh_ui()


func _on_arrow_left_pressed() -> void:
	_preview_idx = (_preview_idx - 1 + _directives.size()) % _directives.size()
	_refresh_ui()


func _on_arrow_right_pressed() -> void:
	_preview_idx = (_preview_idx + 1) % _directives.size()
	_refresh_ui()


func _on_select_pressed() -> void:
	if _directives.is_empty():
		return
	var chosen_id: String = str(_directives[_preview_idx].get("id", ""))
	action_requested.emit({
		"type":         "directive.select",
		"directive_id": chosen_id,
		"slot":         "directive.confirm"
	})
	dismiss_requested.emit()
	hide()
