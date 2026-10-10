extends Control

signal dismiss_requested(incident_id: String)

@onready var _card: Panel = %Card

func _ready() -> void:
	%Continue.pressed.connect(func() -> void: dismiss_requested.emit(str(get_meta("incident_id", ""))))
	%Back.pressed.connect(func() -> void: dismiss_requested.emit(str(get_meta("incident_id", ""))))
	resized.connect(_layout)
	_layout()


func set_model(model: Dictionary) -> void:
	visible = not model.is_empty()
	if model.is_empty():
		return
	set_meta("incident_id", str(model.get("incident_id", "")))
	%Title.text = str(model.get("title", "A difficult moment"))
	%Subtitle.text = "%s · %s" % [" & ".join(model.get("participants", [])), str(model.get("place", "Village path"))]
	%Outcome.text = str(model.get("outcome", "The moment settled."))
	%Response.text = str(model.get("response", "The moment was answered"))
	var people: Array = model.get("people", [])
	_set_person(%PortraitA, %NameA, %EmotionA, people[0] if people.size() > 0 else {})
	_set_person(%PortraitB, %NameB, %EmotionB, people[1] if people.size() > 1 else {})
	var axis_bond: Dictionary = model.get("bond", {})
	%AxisOutcome.text = str(axis_bond.get("direction", "Their relationship shifted"))
	_set_lines(%ViewsHeading, %Views, model.get("views", []))
	_set_lines(%ReactionsHeading, %Reactions, model.get("keeper_reactions", []))
	var bond: Dictionary = model.get("bond", {})
	%Relationship.visible = not bond.is_empty()
	if %Relationship.visible:
		%Relationship.text = "%s · %s → %s" % [str(bond.get("direction", "Neutral → Neutral")), str(bond.get("before", "Unformed")), str(bond.get("after", "Unformed"))]
	var effects: Array = model.get("effects", [])
	var emotions: Array[String] = []
	for effect: Dictionary in effects:
		emotions.append("%s · %s" % [str(effect.get("name", "Echo")), str(effect.get("emotion_change", ""))])
	_set_lines(%EmotionsHeading, %Emotions, emotions)
	_set_lines(%NextHeading, %Next, model.get("next_behaviors", []))
	var eased: bool = bool(model.get("cause_eased", false))
	%CauseState.text = "✓ CAUSE EASED" if eased else "○ CAUSE STILL PRESENT"
	%CauseState.modulate = Color("a5d6a7") if eased else Color("e5b65c")
	%Cause.text = str(model.get("cause_summary", ""))
	var recurrence: String = str(model.get("recurrence_cause", ""))
	%Recurrence.visible = bool(model.get("recurrence_possible", false)) and not recurrence.is_empty()
	%Recurrence.text = "It could return: " + recurrence
	_layout()


func focus_continue() -> void:
	%Continue.grab_focus.call_deferred()


func _layout() -> void:
	if not is_instance_valid(_card):
		return
	var compact: bool = size.y <= 720.0 or size.x <= 1280.0
	var tight: bool = size.y <= 560.0
	var inset: float = 12.0 if tight else 20.0
	var card_size := Vector2(
		minf(660.0, maxf(300.0, size.x - inset * 2.0)),
		minf(760.0, maxf(360.0, size.y - inset * 2.0))
	)
	var portrait_height: float = 96.0 if tight else (112.0 if compact else 136.0)
	var axis_width: float = 96.0 if tight else (120.0 if compact else 150.0)
	$Card/Stack.add_theme_constant_override("separation", 6 if compact else 10)
	$Card/Stack/PeopleRow.add_theme_constant_override("separation", 6 if compact else 10)
	$Card/Stack/PeopleRow/Axis.custom_minimum_size.x = axis_width
	%PortraitA.custom_minimum_size.y = portrait_height
	%PortraitB.custom_minimum_size.y = portrait_height
	$Card/Stack/Scroll.visible = not tight
	$Card/Stack/Scroll.custom_minimum_size.y = 80.0 if compact else 140.0
	$Card/Stack/Scroll/Details.add_theme_constant_override("separation", 5 if compact else 8)
	_card.offset_left = -card_size.x * 0.5
	_card.offset_top = -card_size.y * 0.5
	_card.offset_right = card_size.x * 0.5
	_card.offset_bottom = card_size.y * 0.5
	_card.size = card_size


func _set_lines(heading: Label, content: Label, lines: Array) -> void:
	heading.visible = not lines.is_empty()
	content.visible = not lines.is_empty()
	content.text = "\n".join(lines)


func _set_person(portrait: TextureRect, name_label: Label, emotion_label: Label, person: Dictionary) -> void:
	portrait.visible = not person.is_empty()
	name_label.visible = not person.is_empty()
	emotion_label.visible = not person.is_empty()
	if person.is_empty():
		return
	portrait.texture = load(str(person.get("portrait_path", "")))
	name_label.text = str(person.get("name", "Echo"))
	emotion_label.text = str(person.get("emotion", ""))
