extends PanelContainer


func _ready() -> void:
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


func set_model(model: Dictionary) -> void:
	visible = not model.is_empty()
	if model.is_empty():
		return
	var stage: String = str(model.get("stage", ""))
	%Stage.text = "THE RETURN · " + stage.to_upper()
	var portrait_path: String = str(model.get("portrait_path", "")) if bool(model.get("manifested", false)) else ""
	%Portrait.visible = not portrait_path.is_empty()
	if not portrait_path.is_empty():
		%Portrait.texture = load(portrait_path)
	%Name.text = str(model.get("name", "A returning Echo"))
	%Identity.text = "%s · %s" % [str(model.get("archetype", "Unknown")), str(model.get("emotion", "Unsure"))]
	%Marking.text = str(model.get("marking", ""))
	var tendencies: Array = model.get("tendencies", [])
	%Tendencies.visible = not tendencies.is_empty()
	%Tendencies.text = "\n".join(tendencies)
	var witness_lines: Array[String] = []
	for witness: Dictionary in model.get("witnesses", []):
		witness_lines.append("%s · %s" % [str(witness.get("name", "Echo")), str(witness.get("response", "watching")).capitalize()])
	%Witnesses.visible = not witness_lines.is_empty()
	%Witnesses.text = "WITNESSES\n" + "\n".join(witness_lines)
	var cue_lines: Array[String] = []
	for choice: Dictionary in model.get("welcome_choices", []):
		var cue: Dictionary = choice.get("cue", {})
		cue_lines.append("%s · %s" % [str(choice.get("label", "Welcome")), str(cue.get("text", ""))])
	%WelcomeCues.visible = not cue_lines.is_empty() and stage == "welcome"
	%WelcomeCues.text = "WELCOME DIRECTION\n" + "\n".join(cue_lines)
	var welcome: Dictionary = model.get("welcome", {})
	%Reaction.visible = not welcome.is_empty()
	%Reaction.text = "THEIR REACTION\n" + str(welcome.get("result", ""))
	var destination: String = str(model.get("destination", ""))
	%Destination.visible = not destination.is_empty()
	%Destination.text = "NEXT · " + destination + "\n" + str(model.get("cause", ""))
	_layout()


func _layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var tight: bool = viewport_size.y <= 560.0
	var compact: bool = viewport_size.y <= 720.0 or viewport_size.x <= 1280.0
	var inset: float = 12.0 if tight else 20.0
	var panel_size := Vector2(
		minf(340.0, maxf(280.0, viewport_size.x - inset * 2.0)),
		minf(600.0, maxf(360.0, viewport_size.y - inset * 2.0))
	)
	%Portrait.custom_minimum_size.y = 120.0 if tight else (160.0 if compact else 210.0)
	$Scroll/Stack.add_theme_constant_override("separation", 5 if compact else 8)
	custom_minimum_size = Vector2.ZERO
	var left: float = viewport_size.x - inset - panel_size.x if tight else inset
	offset_left = left
	offset_right = left + panel_size.x
	offset_top = -panel_size.y * 0.5
	offset_bottom = panel_size.y * 0.5
	size = panel_size
