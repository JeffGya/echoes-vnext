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

@onready var living_label: Label = %LivingLabel
@onready var next_label: Label = %NextLabel
@onready var next_price_label: Label = %NextPriceLabel
@onready var after_label: Label = %AfterLabel
@onready var after_price_label: Label = %AfterPriceLabel
@onready var reason_label: Label = %ReasonLabel

@onready var grade_label: Label = %GradeLabel
@onready var grade_buttons: Dictionary = {
	"uncalled": %GradeUncalledButton,
	"called": %GradeCalledButton,
	"chosen": %GradeChosenButton,
}

@onready var count_label: Label = %CountLabel
@onready var count_value_label: Label = %CountValueLabel
@onready var minus_button: Button = %MinusButton
@onready var plus_button: Button = %PlusButton
@onready var max_button: Button = %MaxButton
@onready var total_label: Label = %TotalLabel
@onready var short_label: Label = %ShortLabel

@onready var summon_button: Button = %SummonButton

# Grades the player can pick. Called and Chosen are shown but locked until Jeff opens them (D-85).
const _OPEN_GRADES: Array[String] = ["uncalled"]

var _last_snapshot: Dictionary = {}

var _count: int = 1
var _grade: String = "uncalled"
var _bottom_content_exclusion := 108

func _ready() -> void:
	back_button.pressed.connect(func():
		_emit_slot_action("nav.back")
	)
	minus_button.pressed.connect(func(): _set_count(_count - 1))
	plus_button.pressed.connect(func(): _set_count(_count + 1))
	max_button.pressed.connect(func(): _set_count(_affordable_max()))
	summon_button.pressed.connect(_on_summon_pressed)

	next_label.text = SummonPriceText.text("price_card", "next_label")
	after_label.text = SummonPriceText.text("price_card", "after_label")
	count_label.text = SummonPriceText.text("summon", "count_label")
	max_button.text = SummonPriceText.text("summon", "max_button")
	grade_label.text = SummonPriceText.text("grade", "label")
	for key: String in grade_buttons.keys():
		var b: Button = grade_buttons[key]
		b.disabled = not _OPEN_GRADES.has(key)
		b.tooltip_text = "" if _OPEN_GRADES.has(key) else SummonPriceText.text("grade", "locked_hint")

	_refresh()

func set_snapshot(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot

	var data := _data()

	title_label.text = str(data.get("title", "Call for a new Echo"))
	_grade = str(data.get("selected_grade", "uncalled"))

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

	_count = clampi(_count, 1, _affordable_max())
	_refresh()

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

func _data() -> Dictionary:
	var data_v: Variant = _last_snapshot.get("data", {})
	return data_v if data_v is Dictionary else {}

func _int_at(key: String, index: int) -> int:
	var arr_v: Variant = _data().get(key, [])
	var arr: Array = arr_v if arr_v is Array else []
	return int(arr[index]) if index >= 0 and index < arr.size() else 0

# The largest count the player can pay for, at least 1 (the snapshot gives 0 when even one is too dear).
func _affordable_max() -> int:
	return maxi(1, int(_data().get("batch_affordable_max", 0)))

func _set_count(v: int) -> void:
	_count = clampi(v, 1, _affordable_max())
	_refresh()

# The grade option row for the selected grade; prices come from the snapshot as given.
func _grade_option() -> Dictionary:
	var opts_v: Variant = _data().get("summon_grade_options", [])
	var opts: Array = opts_v if opts_v is Array else []
	for o_v: Variant in opts:
		if o_v is Dictionary and str((o_v as Dictionary).get("key", "")) == _grade:
			return o_v
	return {}

func _on_summon_pressed() -> void:
	if _short_by() > 0:
		# UI guard only; Core is authoritative anyway.
		return
	_emit_slot_action("cta.summon", {
		"count": _count,
		"grade": _grade,
		"now_unix": int(Time.get_unix_time_from_system()),
	})

# Subtraction only: the snapshot total for this count minus the balance.
func _short_by() -> int:
	return maxi(0, _int_at("batch_totals", _count - 1) - int(_data().get("ase_balance", 0)))

func _refresh() -> void:
	var data := _data()
	var opt := _grade_option()

	living_label.text = SummonPriceText.with_number("price_card", "living_line", int(data.get("living_count", 0)))
	next_price_label.text = SummonPriceText.with_number("price_card", "price", int(opt.get("ase_cost", 0)))
	after_price_label.text = SummonPriceText.with_number("price_card", "price", int(opt.get("ase_cost_after", 0)))
	reason_label.text = SummonPriceText.text("price_card", "reason_flat" if bool(data.get("price_flat", false)) else "reason_rising")

	for key: String in grade_buttons.keys():
		var b: Button = grade_buttons[key]
		b.theme_type_variation = &"SanctumTabButtonActive" if key == _grade else &"SanctumTabButton"
		b.button_pressed = key == _grade

	count_value_label.text = str(_count)
	total_label.text = SummonPriceText.with_number("price_card", "price", _int_at("batch_totals", _count - 1))
	minus_button.disabled = _count <= 1
	plus_button.disabled = _count >= _affordable_max()
	max_button.disabled = _count >= _affordable_max()

	ase_label.text = "Ase: %d" % int(data.get("ase_balance", 0))

	var short := _short_by()
	short_label.text = SummonPriceText.with_number("summon", "short_line", short) if short > 0 else ""
	summon_button.disabled = short > 0 or bool(data.get("summon_disabled", false))

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
