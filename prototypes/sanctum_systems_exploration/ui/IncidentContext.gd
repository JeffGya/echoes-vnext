extends VBoxContainer

const STATES: Array[String] = ["warning", "open", "joined", "resolved"]
const QUIET := Color("40584d")
const ACTIVE := Color("e8c47b")
const OPEN := Color("ef8b58")
const APPEAL := Color("f1d27f")

func set_model(model: Dictionary) -> void:
	var status: String = str(model.get("status", "warning"))
	var access: String = str(model.get("keeper_access", "private"))
	var access_tone: Color = _access_tone(access)
	%Place.text = str(model.get("place", "Village path"))
	%Now.text = _exchange_text(model.get("exchange_lines", []))
	%Cause.text = str(model.get("why", model.get("cause", "A tense moment is forming.")))
	%Urgency.text = "STATUS · " + str(model.get("status_text", "Watching"))
	%Urgency.modulate = access_tone
	%Action.text = str(model.get("action", "Nothing to choose yet."))
	%StageRail.visible = status != "warning"
	var reply_cues: Array = model.get("reply_cues", [])
	%ReplyCues.visible = not reply_cues.is_empty()
	for index: int in range(3):
		var cue_node: Label = get_node("ReplyCues/Cue%d" % index)
		cue_node.visible = index < reply_cues.size()
		if index < reply_cues.size():
			var cue: Dictionary = reply_cues[index]
			cue_node.text = "%s · %s" % [str(cue.get("label", "Respond")), str(cue.get("text", ""))]
			cue_node.modulate = _cue_tone(str(cue.get("tone", "quiet")))
	for index: int in range(STATES.size()):
		var node: Label = get_node("StageRail/%s" % STATES[index].capitalize())
		node.modulate = access_tone if STATES[index] == status else QUIET
	for index: int in range(5):
		get_node("UrgencyRail/Urgency%d" % index).color = access_tone if index < int(model.get("urgency_level", 0)) else QUIET
	var result: Dictionary = model.get("result", {})
	%Aftermath.visible = not result.is_empty()
	if not result.is_empty():
		%Response.text = str(result.get("response_label", "The moment is answered"))
		%AftermathText.text = str(result.get("aftermath", "The moment settles."))
		var effects: Array = result.get("effects", [])
		%EffectA.visible = effects.size() > 0
		%EffectB.visible = effects.size() > 1
		if effects.size() > 0: _set_effect(%EffectA, effects[0])
		if effects.size() > 1: _set_effect(%EffectB, effects[1])
		%BondChange.visible = not result.get("bond", {}).is_empty()
		if %BondChange.visible:
			%BondChange.text = "%s · %s → %s" % [result.bond.get("direction", "Neutral → Neutral"), result.bond.get("before", "Unformed"), result.bond.get("after", "Unformed")]
		_set_lines(%ParticipantViewsHeading, %ParticipantViews, result.get("participant_views", []))
		_set_lines(%KeeperReactionsHeading, %KeeperReactions, result.get("keeper_reactions", []))
		_set_lines(%NextHeading, %NextBehaviors, result.get("next_behaviors", []))

func _set_effect(label: Label, effect: Dictionary) -> void:
	label.text = "%s\n%s\n%s" % [effect.get("name", "Echo"), effect.get("need_change", "Needs held steady"), effect.get("emotion_change", "Emotional state held steady")]


func _set_lines(heading: Label, content: Label, lines: Array) -> void:
	heading.visible = not lines.is_empty()
	content.visible = not lines.is_empty()
	content.text = "\n".join(lines)


func _cue_tone(tone: String) -> Color:
	match tone:
		"calm", "gentle": return Color("a5d6a7")
		"honest": return Color("e8c47b")
		_: return ACTIVE


func _exchange_text(lines: Array) -> String:
	var formatted: Array[String] = []
	for line: Dictionary in lines:
		var speaker: String = str(line.get("speaker", ""))
		var text: String = str(line.get("text", ""))
		if not speaker.is_empty() and not text.is_empty():
			formatted.append("%s: “%s”" % [speaker, text])
	return "\n\n".join(formatted) if not formatted.is_empty() else "They are speaking quietly."


func _access_tone(access: String) -> Color:
	match access:
		"appeal": return APPEAL
		"open": return OPEN
		_: return QUIET
