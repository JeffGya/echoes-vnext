extends Control

class_name SummonRevealOverlay

signal dismiss_requested()

@onready var title_label: Label = %TitleLabel
@onready var count_label: Label = %CountLabel

@onready var name_label: Label = %NameLabel
@onready var meta_label: Label = %MetaLabel
@onready var archetype_label: Label = %ArchetypeLabel
@onready var traits_label: Label = %TraitsLabel
@onready var stats_label: Label = %StatsLabel

@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var dismiss_button: Button = %DismissButton

var _reveals: Array = []
var _index: int = 0

func _ready() -> void:
	prev_button.pressed.connect(func(): set_index(_index - 1))
	next_button.pressed.connect(func(): set_index(_index + 1))
	dismiss_button.pressed.connect(func(): dismiss_requested.emit())
	
	# Defaults
	title_label.text = "New Echo"
	_update_ui()
	
func set_reveals(reveals: Array) -> void:
	_reveals = reveals.duplicate(true)
	_index = 0
	_update_ui()

func set_index(i: int) -> void:
	if _reveals.is_empty():
		_index = 0
		_update_ui()
		return

	_index = clampi(i, 0, _reveals.size() - 1)
	_update_ui()

func _update_ui() -> void:
	var n := _reveals.size()
	visible = n > 0
	
	if n <= 0:
		return
		
	count_label.text = "%d / %d" % [_index + 1, n]
	
	prev_button.disabled = (_index <= 0)
	next_button.disabled = (_index >= n - 1)
	
	var e_v: Variant = _reveals[_index]
	var e: Dictionary = e_v if e_v is Dictionary else {}
	
	# Minimal bindings (safe defaults)
	var echo_name := str(e.get("name", "Unknown"))
	var gender := str(e.get("gender", ""))
	var rarity := str(e.get("rarity", ""))
	var calling := str(e.get("calling_origin", ""))
	
	name_label.text = echo_name
	meta_label.text = "%s • %s • %s" % [gender, rarity, calling]
	
	archetype_label.text = "Archetype: %s" % str(e.get("archetype_birth", ""))
	
	var traits_v: Variant = e.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	traits_label.text = "Traits: C %d  W %d  F %d" % [
		int(traits.get("courage", 0)),
		int(traits.get("wisdom", 0)),
		int(traits.get("faith", 0)),
	]
	
	var stats_v: Variant = e.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}
	stats_label.text = "Stats: HP %d  ATK %d  DEF %d  AGI %d" % [
		int(stats.get("max_hp", 0)),
		int(stats.get("atk", 0)),
		int(stats.get("def", 0)),
		int(stats.get("agi", 0)),
	]
