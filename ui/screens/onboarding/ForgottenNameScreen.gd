extends Control

class_name ForgottenNameScreen

signal action_requested(action: Dictionary)

const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")

const VIRTUE_COLORS := {
	"courage": Color("#E8D5B0"),
	"wisdom": Color("#E8EDE8"),
	"leadership": Color("#E8D8C8"),
	"acceptance": Color("#78A0B0"),
	"humility": Color("#F8F4E8"),
	"forgiveness": Color("#C08890"),
	"truth": Color("#E0A8A0"),
	"generosity": Color("#E8E0D8"),
	"compassion": Color("#E8F0F0"),
	"empathy": Color("#F8F8FC"),
}

@onready var _choice_root: Control = %ChoiceRoot
@onready var _meeting_root: Control = %MeetingRoot
@onready var _commit_button: Button = %CommitButton
@onready var _name_labels: Array[Label] = [%Name1, %Name2, %Name3]
@onready var _bark_labels: Array[Label] = [%Bark1, %Bark2, %Bark3]
@onready var _orb_buttons: Array[Button] = [%OrbButton1, %OrbButton2, %OrbButton3]
@onready var _orbs: Array[VirtueOrbControl] = [%Orb1, %Orb2, %Orb3]
@onready var _echo_name: Label = %EchoName
@onready var _echo_meta: Label = %EchoMeta
@onready var _echo_traits: Label = %EchoTraits
@onready var _echo_stats: Label = %EchoStats
@onready var _meeting_continue: Button = %MeetingContinue

var _fragments: Array = []
var _selected := ""
var _confirm_action: Dictionary = {}
var _continue_action: Dictionary = {}


func _ready() -> void:
	for i in range(_orb_buttons.size()):
		_orb_buttons[i].pressed.connect(_on_orb_pressed.bind(i))
	_commit_button.pressed.connect(_on_commit_pressed)
	_meeting_continue.pressed.connect(_on_meeting_continue_pressed)


func set_snapshot(snap: Dictionary) -> void:
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var snap_type := str(snap.get("type", ""))
	if snap_type == FlowStateIds.ONBOARDING_MEETING:
		_render_meeting(data, actions)
	else:
		_render_choice(data, actions)


func _render_choice(data: Dictionary, actions: Dictionary) -> void:
	_choice_root.visible = true
	_meeting_root.visible = false
	var fragments_v: Variant = data.get("fragment_options", [])
	_fragments = fragments_v if fragments_v is Array else []
	_selected = str(data.get("selected_fragment", ""))
	var heard_v: Variant = data.get("heard_fragments", [])
	var heard: Array = heard_v if heard_v is Array else []
	for i in range(3):
		var has_fragment := i < _fragments.size() and _fragments[i] is Dictionary
		_orb_buttons[i].disabled = not has_fragment
		_bark_labels[i].visible = false
		if not has_fragment:
			_name_labels[i].text = ""
			_orbs[i].selected = false
			continue
		var fragment: Dictionary = _fragments[i]
		var virtue := str(fragment.get("virtue", ""))
		_name_labels[i].text = str(fragment.get("label", "The Forgotten One"))
		_orbs[i].orb_color = VIRTUE_COLORS.get(virtue, Color("#D4AF37"))
		_orbs[i].selected = virtue == _selected
		if virtue == _selected or (virtue in heard and _selected == ""):
			_bark_labels[i].text = str(fragment.get("bark", ""))
			_bark_labels[i].visible = true
	var action_v: Variant = actions.get("cta.confirm", {})
	_confirm_action = action_v if action_v is Dictionary else {}
	_commit_button.disabled = _confirm_action.is_empty() or bool(_confirm_action.get("disabled", false))
	_commit_button.text = str(_confirm_action.get("label", "COMMIT TO ONE"))


func _render_meeting(data: Dictionary, actions: Dictionary) -> void:
	_choice_root.visible = false
	_meeting_root.visible = true
	var echo_v: Variant = data.get("starter_echo", {})
	var echo: Dictionary = echo_v if echo_v is Dictionary else {}
	_echo_name.text = str(echo.get("name", "A name has returned"))
	_echo_meta.text = "Standing %d   Step %d   Storyweight %d\n%s   %s   %s" % [
		int(echo.get("standing", 1)),
		int(echo.get("step", 1)),
		int(echo.get("storyweight", 0)),
		str(echo.get("archetype_birth", "")).capitalize(),
		str(echo.get("dominant_vector", "")).capitalize(),
		EmotionPresentation.display_name(str(echo.get("emotional_status", ""))),
	]
	var traits_v: Variant = echo.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	_echo_traits.text = "Courage %d\nWisdom %d\nFaith %d" % [
		int(traits.get("courage", 0)),
		int(traits.get("wisdom", 0)),
		int(traits.get("faith", 0)),
	]
	var stats_v: Variant = echo.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}
	_echo_stats.text = "HP %d\nATK %d  DEF %d\nAGI %d  INT %d  CHA %d" % [
		int(stats.get("max_hp", 0)),
		int(stats.get("atk", 0)),
		int(stats.get("def", 0)),
		int(stats.get("agi", 0)),
		int(stats.get("int", 0)),
		int(stats.get("cha", 0)),
	]
	var action_v: Variant = actions.get("cta.continue", {})
	_continue_action = action_v if action_v is Dictionary else {}
	_meeting_continue.text = str(_continue_action.get("label", "Continue"))


func _on_orb_pressed(index: int) -> void:
	if index >= _fragments.size() or not (_fragments[index] is Dictionary):
		return
	var fragment: Dictionary = _fragments[index]
	action_requested.emit({
		"type": "onboarding.fragment.select",
		"virtue": str(fragment.get("virtue", "")),
	})


func _on_commit_pressed() -> void:
	if _confirm_action.is_empty() or _commit_button.disabled:
		return
	_commit_button.disabled = true
	var tween := create_tween()
	_choice_root.modulate = Color.WHITE
	tween.tween_property(_choice_root, "modulate", Color("#D4AF37"), 0.35)
	tween.tween_interval(0.2)
	tween.tween_callback(func(): action_requested.emit(_confirm_action))


func _on_meeting_continue_pressed() -> void:
	if not _continue_action.is_empty():
		action_requested.emit(_continue_action)
