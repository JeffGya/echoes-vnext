extends PanelContainer

func set_model(model: Dictionary) -> void:
	visible = not model.is_empty()
	if model.is_empty(): return
	_set_label(%MomentType, str(model.get("type_label", "")))
	_set_label(%EventGlyph, str(model.get("glyph", "")))
	_set_label(%MomentBadge, str(model.get("badge", "")))
	%Header.visible = %MomentType.visible or %EventGlyph.visible or %MomentBadge.visible
	_set_label(%People, str(model.get("people", "")))
	_set_tone(str(model.get("tone", "quiet")))
	_set_label(%MomentTitle, str(model.get("title", "")))
	_set_label(%MomentMeta, str(model.get("meta", "")))
	_set_label(%MomentText, str(model.get("text", "")))
	_set_label(%MomentCause, "Why: " + str(model.get("cause", "")) if not str(model.get("cause", "")).is_empty() else "")
	var aftermath: String = str(model.get("aftermath", ""))
	_set_label(%MomentAftermath, "Afterward: " + aftermath if not aftermath.is_empty() else "")
	var consequences: Array = model.get("consequences", [])
	_set_label(%ConsequenceA, str(consequences[0]) if consequences.size() > 0 else "")
	_set_label(%ConsequenceB, str(consequences[1]) if consequences.size() > 1 else "")
	var changes: Array = model.get("changes", [])
	_set_label(%Changes, "↗ " + "  ·  ".join(changes) if not changes.is_empty() else "")


func _set_label(label: Label, text_value: String) -> void:
	label.visible = not text_value.is_empty()
	label.text = text_value


func _set_tone(tone: String) -> void:
	var color := Color("718c7b")
	if tone == "warning": color = Color("e5b65c")
	elif tone == "settled": color = Color("a5d6a7")
	elif tone == "connection": color = Color("8fd4bd")
	%EventGlyph.modulate = color
	%MomentBadge.modulate = color
