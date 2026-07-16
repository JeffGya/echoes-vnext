# res://ui/screens/sanctum/SummonScreen.gd
extends Control
class_name SummonScreen

signal action_requested(action: Dictionary)
signal modal_requested(modal_id: StringName, payload: Dictionary)

@onready var title_label: Label = %TitleLabel
@onready var back_button: Button = %BackButton
@onready var root_panel: PanelContainer = %RootPanel

@onready var ase_label: Label = %AseLabel
@onready var ase_rate_label: Label = %AseRateLabel

@onready var grade_option: OptionButton = %GradeOption

@onready var count_label: Label = %CountLabel
@onready var count_slider: HSlider = %CountSlider
@onready var cost_label: Label = %CostLabel

@onready var summon_button: Button = %SummonButton

var _last_snapshot: Dictionary = {}

var _count: int = 1
var _cost_each: int = 60
var _ase: int = 0
var _grade: String = "uncalled"
var _bottom_content_exclusion := 108

func _ready() -> void:
	# Slider
	count_slider.min_value = 1
	count_slider.max_value = 10
	count_slider.step = 1
	count_slider.value = 1
	count_slider.value_changed.connect(_on_count_changed)

	# Buttons
	back_button.pressed.connect(func():
		_emit_slot_action("nav.back")
	)

	summon_button.pressed.connect(_on_summon_pressed)

	# Grade options (MVP: only "uncalled" enabled)
	_setup_grade_options()

	_refresh_labels_and_button()

func set_snapshot(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot

	var data_v: Variant = snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	# Title
	title_label.text = str(data.get("title", "Call for a new Echo"))

	# Economy (authoritative)
	_ase = int(data.get("ase_balance", 0))
	_cost_each = int(data.get("ase_cost_per_summon", 60))

	# Rate hint (~ X / hour)
	var rate := float(data.get("ase_rate_per_hour_hint", 0.0))
	ase_rate_label.text = "(~ %.1f Ase / hour)" % rate

	# Overlay reveals (transient)
	var reveals_v: Variant = data.get("pending_summon_reveals", [])
	var reveals: Array = reveals_v if reveals_v is Array else []

	if reveals.size() > 0:
		var dismiss_action := _slot_action("overlay.dismiss_reveals")
		modal_requested.emit(&"summon_reveal", {
			"reveals": reveals,
			"dismiss_action": dismiss_action,
		})

	_refresh_labels_and_button()

func set_layout(layout: Dictionary) -> void:
	var safe: Vector4 = layout.get("safe_insets", Vector4.ZERO)
	var profile: StringName = layout.get("profile", &"standard")
	var logical_size_v: Variant = layout.get("logical_size", Vector2(1280, 720))
	var logical_size: Vector2 = logical_size_v if logical_size_v is Vector2 else Vector2(1280, 720)
	var viewport_w := float(logical_size.x)
	var cap := 680.0 if profile == &"compact" else 760.0
	var available_w := maxf(320.0, viewport_w - float(32 + int(ceilf(safe.x)) + int(ceilf(safe.z))))
	var content_w := minf(available_w, cap)
	var left := float(16 + int(ceilf(safe.x))) + maxf(0.0, (available_w - content_w) * 0.5)
	offset_left = left
	offset_top = float(16 + int(ceilf(safe.y)))
	offset_right = -(viewport_w - left - content_w)
	offset_bottom = -float(_bottom_content_exclusion)

func set_bottom_content_exclusion(value: int) -> void:
	_bottom_content_exclusion = maxi(0, value)

func _setup_grade_options() -> void:
	grade_option.clear()

	# Show three grades, but only "uncalled" is active in MVP
	grade_option.add_item("Uncalled", 0)
	grade_option.add_item("Called (Locked)", 1)
	grade_option.add_item("Chosen (Locked)", 2)

	# Disable locked items (Godot 4 OptionButton supports per-item disable)
	grade_option.set_item_disabled(1, true)
	grade_option.set_item_disabled(2, true)

	grade_option.select(0)
	_grade = "uncalled"

	grade_option.item_selected.connect(func(idx: int):
		# MVP: only idx 0 possible due to disabled items, but keep it safe.
		if idx == 0:
			_grade = "uncalled"
		elif idx == 1:
			_grade = "called"
		else:
			_grade = "chosen"
		_refresh_labels_and_button()
	)

func _on_count_changed(v: float) -> void:
	_count = int(v)
	_refresh_labels_and_button()

func _on_summon_pressed() -> void:
	var total_cost := _cost_each * _count
	if _ase < total_cost:
		# UI guard only; Core is authoritative anyway.
		return

	_emit_slot_action("cta.summon", {
		"count": _count,
		"grade": _grade,
		"now_unix": int(Time.get_unix_time_from_system()),
	})

func _refresh_labels_and_button() -> void:
	count_label.text = "Summons: %d" % _count

	var total_cost := _cost_each * _count
	cost_label.text = "Cost: %d" % total_cost

	ase_label.text = "Ase: %d" % _ase

	summon_button.disabled = (_ase < total_cost)

func _emit_action(action: Dictionary) -> void:
	action_requested.emit(action)

func _emit_slot_action(slot: String, extra: Dictionary = {}) -> void:
	var a := _slot_action(slot)
	if not a.is_empty():
		for k in extra.keys():
			a[k] = extra[k]
		action_requested.emit(a)
		return
	action_requested.emit(extra)

func _slot_action(slot: String) -> Dictionary:
	if _last_snapshot.has("actions") and typeof(_last_snapshot["actions"]) == TYPE_DICTIONARY:
		var actions: Dictionary = _last_snapshot["actions"]
		if actions.has(slot) and typeof(actions[slot]) == TYPE_DICTIONARY:
			var a: Dictionary = (actions[slot] as Dictionary).duplicate(true)
			return a
	return {}
