extends Control
class_name CompanionInviteModal

signal action_requested(action: Dictionary)
signal dismiss_requested()

@onready var scroll: ScrollContainer = %CompanionInviteScroll
@onready var safe_frame: MarginContainer = %SafeFrame
@onready var name_label: Label = %CompanionNameLabel
@onready var chance_label: Label = %CompanionChanceLabel
@onready var chance_bar: ProgressBar = %CompanionChanceBar
@onready var talk_bar: ProgressBar = %CompanionTalkBar
@onready var talk_value: Label = %CompanionTalkValue
@onready var fight_bar: ProgressBar = %CompanionFightBar
@onready var fight_value: Label = %CompanionFightValue
@onready var fit_bar: ProgressBar = %CompanionFitBar
@onready var fit_value: Label = %CompanionFitValue
@onready var accept_button: Button = %CompanionAcceptButton
@onready var decline_button: Button = %CompanionDeclineButton

func _ready() -> void:
	accept_button.pressed.connect(_emit_accept)
	decline_button.pressed.connect(_emit_decline)

func present(payload: Dictionary) -> void:
	if payload.get("layout", {}) is Dictionary:
		set_layout(payload.get("layout", {}) as Dictionary)
	var invite_v: Variant = payload.get("invite", {})
	var invite: Dictionary = invite_v if invite_v is Dictionary else {}
	var cap := maxi(1, int(invite.get("cap", 75)))
	var chance := int(invite.get("chance", 0))
	var conversation := int(invite.get("conversation", 0))
	var combat := int(invite.get("combat", 0))
	var fit := int(invite.get("fit", 0))
	name_label.text = str(invite.get("ally_name", ""))
	chance_label.text = "%d%%" % chance
	_set_bar(chance_bar, 0, cap, chance)
	_set_bar(talk_bar, 0, cap, conversation)
	talk_value.text = "%d/%d" % [conversation, cap]
	_set_bar(fight_bar, 0, cap, combat)
	fight_value.text = "%d/%d" % [combat, cap]
	_set_bar(fit_bar, 0, cap, fit)
	fit_value.text = "%d/%d" % [fit, cap]

func set_layout(layout: Dictionary) -> void:
	var frame := safe_frame if safe_frame != null else find_child("SafeFrame", true, false) as MarginContainer
	if frame != null and frame.has_method("set_layout"):
		frame.call("set_layout", layout)

func _set_bar(bar: ProgressBar, min_value: int, max_value: int, value: int) -> void:
	bar.min_value = min_value
	bar.max_value = max_value
	bar.value = value

func _emit_accept() -> void:
	dismiss_requested.emit()
	action_requested.emit({ "type": "sanctum.companion.accept" })

func _emit_decline() -> void:
	dismiss_requested.emit()
	action_requested.emit({ "type": "sanctum.companion.decline" })
