extends Control

signal action_requested(action: Dictionary)

@export var morning_background := Color("0b1411")
@export var afternoon_background := Color("111711")
@export var evening_background := Color("111210")
@export var night_background := Color("060b13")
const TUNING_KEYS: Array[String] = ["day_minutes", "routine_seconds", "rest_weight", "company_weight", "purpose_weight",
	"social_frequency", "warning_seconds", "intervention_seconds"]
const TUNING_LABELS: Array[String] = ["Day length · minutes", "Routine · seconds", "Rest influence", "Company influence", "Purpose influence",
	"Social frequency", "Warning · seconds", "Intervention · seconds"]
@onready var _world: Control = %HouseView
@onready var _panel: PanelContainer = %ContextPanel
@onready var _result_overlay: Control = %IncidentResultOverlay
@onready var _arrival_reveal: Control = %ArrivalReveal
@onready var _choices: Array[Button] = [%Choice0, %Choice1, %Choice2, %Choice3]
@onready var _sliders: Array[HSlider] = [%Tuning0, %Tuning1, %Tuning2, %Tuning3, %Tuning4, %Tuning5, %Tuning6, %Tuning7]
@onready var _tuning_labels: Array[Label] = [%TuningLabel0, %TuningLabel1, %TuningLabel2, %TuningLabel3, %TuningLabel4,
	%TuningLabel5, %TuningLabel6, %TuningLabel7]
var _snapshot: Dictionary = {}
var _rendering := false
var _dragging: Dictionary = {}
var _context_key := ""
var _focus_before_overlay: Control


func _ready() -> void:
	_world.subject_selected.connect(func(subject: Dictionary) -> void: _send("prototype.subject.select", subject))
	for id: String in ["paused", "normal", "fast", "next", "start"]:
		var node: Button = {"paused": %Pause, "normal": %Normal, "fast": %Fast, "next": %NextBeat, "start": %Start}[id]
		node.pressed.connect(_slot.bind("cta." + id))
	for index: int in range(_choices.size()):
		_choices[index].pressed.connect(_slot.bind("cta.choice_%d" % index))
	%Lab.pressed.connect(func() -> void: _send("prototype.view.lab"))
	%Back.pressed.connect(func() -> void: _send("prototype.view.back"))
	%Current.pressed.connect(func() -> void: _send("prototype.view.current"))
	%Recent.pressed.connect(func() -> void: _send("prototype.view.history"))
	%HistoryPrev.pressed.connect(func() -> void: _change_history_page(-1))
	%HistoryNext.pressed.connect(func() -> void: _change_history_page(1))
	%Reset.pressed.connect(func() -> void: _send("prototype.session.reset"))
	%Setup.pressed.connect(func() -> void: _send("prototype.session.setup"))
	%ApplySeed.pressed.connect(_apply_seed)
	%Seed.text_submitted.connect(func(_text: String) -> void: _apply_seed())
	%ReducedMotion.toggled.connect(func(value: bool) -> void:
		if not _rendering:
			_send("prototype.view.motion", {"reduced": value}))
	_result_overlay.dismiss_requested.connect(func(incident_id: String) -> void: _send("prototype.incident.result.dismiss", {"incident_id": incident_id}))
	for index: int in range(_sliders.size()):
		_sliders[index].drag_started.connect(func() -> void: _dragging[index] = true)
		_sliders[index].drag_ended.connect(func(changed: bool) -> void:
			_dragging.erase(index)
			if changed:
				_set_tuning(index, _sliders[index].value))
		_sliders[index].value_changed.connect(func(value: float) -> void:
			if not _rendering:
				_tuning_labels[index].text = "%s  %.1f" % [TUNING_LABELS[index], value]
				if not _dragging.has(index):
					_set_tuning(index, value))
	resized.connect(_layout)
	_layout()


func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if not is_node_ready():
		return
	_rendering = true
	var data: Dictionary = snapshot.data
	var panel: Dictionary = data.panel
	var overlay: Dictionary = data.get("incident_result_overlay", {})
	var overlay_was_open: bool = _result_overlay.visible
	var overlay_open: bool = not overlay.is_empty()
	if overlay_open and not overlay_was_open:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is Control and not _result_overlay.is_ancestor_of(focus_owner):
			_focus_before_overlay = focus_owner
	_result_overlay.set_model(overlay)
	if overlay_open and not overlay_was_open:
		_result_overlay.focus_continue()
	elif not overlay_open and overlay_was_open:
		if is_instance_valid(_focus_before_overlay):
			_focus_before_overlay.grab_focus.call_deferred()
		else:
			_world.grab_focus.call_deferred()
		_focus_before_overlay = null
	_arrival_reveal.set_model(data.get("arrival_presentation", {}))
	var setup: bool = data.phase == "setup"
	%Start.visible = setup
	for button: Button in [%Pause, %Normal, %Fast, %NextBeat]:
		button.visible = not setup
	for entry: Array in [[%Pause, "paused"], [%Normal, "normal"], [%Fast, "fast"], [%NextBeat, "next"], [%Start, "start"]]:
		var action: Dictionary = snapshot.actions["cta." + str(entry[1])]
		entry[0].disabled = action.disabled
		entry[0].text = action.label
		if entry[1] in ["paused", "normal", "fast"]:
			entry[0].set_pressed_no_signal(data.speed == entry[1])
	%Clock.text = "Village setup" if setup else "Day %d · %s" % [data.clock.day, str(data.clock.phase).capitalize()]
	%Clock.tooltip_text = "%.0f%% of the day · %.0f real minutes at Normal speed" % [float(data.clock.progress) * 100, float(data.clock.day_minutes)]
	%Background.color = _phase_background(float(data.clock.progress))
	%Status.text = ("Place both anchors · %d/2 placed" % data.placements.size()) if setup else data.notice
	var closing_panel: bool = _panel.visible and not panel.visible
	_panel.visible = panel.visible
	if closing_panel:
		_world.grab_focus.call_deferred()
	%PanelTitle.text = panel.title
	%PanelSubtitle.text = panel.subtitle
	var lab: bool = data.panel_mode == "lab"
	var history: bool = data.panel_mode == "history"
	var visual: Dictionary = panel.get("visual", {})
	var visual_type: String = str(visual.get("type", ""))
	%LabControls.visible = lab
	%NeedPressureDisplay.visible = visual_type == "echo"
	%RelationshipMap.visible = visual_type == "echo"
	%IncidentContext.visible = visual_type == "incident"
	%HistoryCards.visible = visual_type == "history"
	%Body.visible = not lab and visual_type not in ["incident", "history"]
	%Body.text = panel.body
	%Body.tooltip_text = ""
	if visual_type == "echo":
		%NeedPressureDisplay.set_model(visual)
		%RelationshipMap.set_model(visual)
	elif visual_type == "incident":
		%IncidentContext.set_model(visual)
	elif visual_type == "history":
		var cards: Array = visual.get("cards", [])
		for index: int in range(%HistoryCards.get_child_count()):
			%HistoryCards.get_child(index).set_model(cards[index] if index < cards.size() else {})
	%DebugReadout.text = panel.body if lab else ""
	%ContextTabs.visible = panel.tabs_visible
	%Current.set_pressed_no_signal(not history)
	%Recent.set_pressed_no_signal(history)
	%HistoryPagination.visible = history
	%HistoryPrev.disabled = int(panel.history_page) == 0
	%HistoryNext.disabled = int(panel.history_page) >= int(panel.history_pages) - 1
	%HistoryPage.text = "%d / %d" % [int(panel.history_page) + 1, panel.history_pages]
	%HistoryPage.tooltip_text = "%d remembered moments · up to 12 per page" % panel.history_total
	var resolving: bool = data.conversation.get("status", "") == "resolved"
	%Back.disabled = resolving
	%Lab.disabled = resolving
	%ReducedMotion.set_pressed_no_signal(data.reduced_motion)
	if not %Seed.has_focus():
		%Seed.text = str(data.seed)
	for index: int in range(_choices.size()):
		var slot := "cta.choice_%d" % index
		_choices[index].visible = snapshot.actions.has(slot)
		if _choices[index].visible:
			_choices[index].text = snapshot.actions[slot].label
			_choices[index].disabled = snapshot.actions[slot].disabled
	for index: int in range(_sliders.size()):
		var key: String = TUNING_KEYS[index]
		var bounds: Array = data.tuning_ranges[key]
		_sliders[index].min_value = bounds[0]
		_sliders[index].max_value = bounds[1]
		_sliders[index].step = bounds[2]
		if not _dragging.has(index):
			_sliders[index].set_value_no_signal(float(data.tuning[key]))
			_tuning_labels[index].text = "%s  %.1f" % [TUNING_LABELS[index], float(data.tuning[key])]
	_rendering = false
	_layout()
	var context_key: String = "%s|%s|%s|%s|%s|%s|%s" % [data.session_serial, data.selection, data.panel_mode, panel.history_page,
		data.conversation.get("status", ""), data.conversation.get("topic", ""), panel.get("context_key", "")]
	if context_key != _context_key:
		%PanelScroll.scroll_vertical = 0
		_context_key = context_key
		if (not data.conversation.is_empty() and data.conversation.status == "choosing") or (panel.get("kind", "") == "incident" and not panel.choices.is_empty()):
			_choices[0].grab_focus()
		elif panel.get("kind", "") == "incident":
			%Back.grab_focus()


func _layout() -> void:
	if not is_node_ready():
		return
	var width: float = 360 if size.x < 1200 else 420 if size.x < 1500 else 460 if size.x < 1850 else 520
	_panel.offset_left = -width - 20
	_panel.offset_right = -20
	%Body.custom_minimum_size.x = width - 44
	%DebugReadout.custom_minimum_size.x = width - 44
	%PanelSubtitle.custom_minimum_size.x = width - 24
	%PanelTitle.custom_minimum_size.x = width - 24
	if not _snapshot.is_empty():
		var current_echo: bool = _snapshot.data.selection.get("kind") == "echo" and _snapshot.data.panel_mode == "" and _snapshot.data.conversation.is_empty()
		%Choices.columns = 2 if current_echo else 1
		_world.set_snapshot(_snapshot.data, width + 40 if _panel.visible else 0)
	%Help.text = "Drag to pan · Wheel to zoom · Arrows + Enter in world · Tab for controls · Esc to return" if size.x >= 1200 else "Drag / wheel: camera · Arrows + Enter: select · Tab: controls · Esc: back"


func presentation_metrics() -> Dictionary:
	return {"minimum_font_size": 16, "normal_surface": str(_snapshot.get("data", {}).get("panel", {}).get("visual", {}).get("type", "simple")),
		"components": {"needs": %NeedPressureDisplay.visible, "relationships": %RelationshipMap.visible,
			"incident": %IncidentContext.visible, "history": %HistoryCards.visible}}


func _slot(slot: String) -> void:
	var action: Dictionary = _snapshot.get("actions", {}).get(slot, {})
	if not action.is_empty() and not action.get("disabled", false):
		action_requested.emit(action.duplicate(true))


func _send(type: String, payload: Dictionary = {}) -> void:
	action_requested.emit({"type": type, "slot": "primary", "payload": payload})


func _change_history_page(direction: int) -> void:
	_send("prototype.view.history.page", {"page": int(_snapshot.data.panel.history_page) + direction})


func _set_tuning(index: int, value: float) -> void:
	_send("prototype.tuning.set", {"key": TUNING_KEYS[index], "value": value})


func _apply_seed() -> void:
	if %Seed.text.is_valid_int():
		_send("prototype.seed.set", {"seed": int(%Seed.text)})
	else:
		%Seed.text = str(_snapshot.meta.seed)


func _phase_background(progress: float) -> Color:
	var anchors: Array[Color] = [morning_background, afternoon_background, evening_background, night_background]
	var phase_position: float = fposmod(progress, 1.0) * 4.0
	var index: int = mini(3, int(phase_position))
	var transition: float = clampf((phase_position - index - 0.72) / 0.28, 0.0, 1.0)
	transition = transition * transition * (3.0 - 2.0 * transition)
	return anchors[index].lerp(anchors[(index + 1) % anchors.size()], transition)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _result_overlay.visible:
			_send("prototype.incident.result.dismiss", {"incident_id": str(_snapshot.get("data", {}).get("incident_result_overlay", {}).get("incident_id", ""))})
		else:
			_send("prototype.view.back")
		get_viewport().set_input_as_handled()
