# res://ui/screens/sanctum/VowCard.gd
# VOW-001: Single vow list card. Discovered or undiscovered state.
# All layout lives in VowCard.tscn — this script only populates data and emits.
# setup(entry) is called once per render cycle from VowScreen.

extends Button
class_name VowCard

signal card_selected(entry: Dictionary)

@onready var thumb: ColorRect       = %Thumb
@onready var question_label: Label  = %QuestionLabel
@onready var name_label: Label      = %NameLabel
@onready var active_badge: Label    = %ActiveBadge

var _entry: Dictionary = {}


func _ready() -> void:
	pressed.connect(func():
		card_selected.emit(_entry)
	)


func setup(entry: Dictionary) -> void:
	_entry = entry
	var is_unlocked: bool = bool(entry.get("is_unlocked", false))
	var is_active: bool   = bool(entry.get("is_active", false))
	var is_new: bool      = bool(entry.get("is_new", false))
	var vow_name: String  = str(entry.get("vow_name", "Vow"))

	thumb.color            = Color(0.22, 0.18, 0.10, 1) if is_unlocked else Color(0.10, 0.10, 0.12, 1)
	question_label.visible = not is_unlocked
	name_label.text        = vow_name if is_unlocked else "???"
	active_badge.visible   = is_active

	# V2-VOW-002: "Discovered" badge — Mist Blue, shown when vow was unlocked this session.
	# Remove any previously-created badge to prevent duplicates on re-render.
	var _info: VBoxContainer = name_label.get_parent() as VBoxContainer
	for _ch in _info.get_children():
		if _ch.name == "_discovered_badge":
			_ch.queue_free()
	if is_new:
		var badge := Label.new()
		badge.name = "_discovered_badge"
		badge.text = "Discovered"
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color("#7AB5C8"))  # Mist Blue — The Loom accent
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info.add_child(badge)
