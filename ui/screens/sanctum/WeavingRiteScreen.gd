extends Control
class_name WeavingRiteScreen

signal action_requested(action: Dictionary)

@onready var _phase_label: Label = %PhaseLabel

@onready var _thread_panel: VBoxContainer = %ThreadPanel
@onready var _echo_panel: VBoxContainer = %EchoPanel
@onready var _resolution_panel: VBoxContainer = %ResolutionPanel
@onready var _empty_thread_label: Label = %EmptyThreadLabel
@onready var _empty_candidate_label: Label = %EmptyCandidateLabel

@onready var _echo_panel_title: Label = %EchoPanelTitle
@onready var _outcome_label: Label = %OutcomeLabel
@onready var _rite_bark_label: Label = %RiteBarkLabel

@onready var _back_button: Button = %BackButton
@onready var _begin_rite_button: Button = %BeginRiteButton
@onready var _confirm_button: Button = %ConfirmButton

var _last_snapshot: Dictionary = {}
var _thread_items: Array = []

var _thread_cards: Array = []
var _thread_rows: Array = []
var _invitation_labels: Array = []
var _aftermath_labels: Array = []
var _non_chosen_labels: Array = []


func _ready() -> void:
	_thread_rows = [
		{ "row": %ThreadRow1, "label": %ThreadLabel1, "button": %ThreadSelectButton1 },
		{ "row": %ThreadRow2, "label": %ThreadLabel2, "button": %ThreadSelectButton2 },
		{ "row": %ThreadRow3, "label": %ThreadLabel3, "button": %ThreadSelectButton3 },
		{ "row": %ThreadRow4, "label": %ThreadLabel4, "button": %ThreadSelectButton4 },
		{ "row": %ThreadRow5, "label": %ThreadLabel5, "button": %ThreadSelectButton5 },
		{ "row": %ThreadRow6, "label": %ThreadLabel6, "button": %ThreadSelectButton6 },
	]
	for i in range(_thread_rows.size()):
		var button: Button = _thread_rows[i]["button"]
		button.pressed.connect(_on_thread_row_pressed.bind(i))
		(_thread_rows[i]["row"] as HBoxContainer).visible = false

	_thread_cards = [%ThreadCard1, %ThreadCard2, %ThreadCard3, %ThreadCard4, %ThreadCard5, %ThreadCard6]
	for card_v in _thread_cards:
		if card_v is Node:
			var card: Node = card_v
			if card.has_signal("selected"):
				card.connect("selected", Callable(self, "_on_thread_card_selected"))

	_invitation_labels = [%CandidateName1, %CandidateFit1, %CandidateReadiness1, %CandidateStrain1]
	_aftermath_labels = [%AftermathLine1, %AftermathLine2, %AftermathLine3, %AftermathLine4]
	_non_chosen_labels = [%NonChosenLine1, %NonChosenLine2, %NonChosenLine3, %NonChosenLine4]

	_back_button.pressed.connect(_on_back_pressed)
	_begin_rite_button.pressed.connect(_on_begin_rite_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)


func set_snapshot(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot
	var data_v: Variant = snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actions_v: Variant = snapshot.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}

	var phase := str(data.get("phase", "thread_select"))
	_phase_label.text = _phase_title(phase)
	_apply_phase_visibility(phase)

	_render_threads(data)
	_render_invitation(data, phase)
	_render_resolution(data)
	_apply_action_slots(actions)


func _render_threads(data: Dictionary) -> void:
	var reserve_v: Variant = data.get("thread_reserve", [])
	_thread_items = reserve_v if reserve_v is Array else []
	var selected_thread_id := str(data.get("selected_thread_id", ""))

	if not _thread_cards.is_empty():
		for i in range(_thread_cards.size()):
			var card_v: Variant = _thread_cards[i]
			if not (card_v is Node):
				continue
			var card: Node = card_v
			if i >= _thread_items.size():
				card.visible = false
				continue
			var card_item_v: Variant = _thread_items[i]
			if not (card_item_v is Dictionary):
				card.visible = false
				continue
			var card_item: Dictionary = card_item_v
			var card_id := str(card_item.get("id", ""))
			card.call("bind_thread", card_item, card_id == selected_thread_id, "Offer")
			card.call("set_selectable", true)
		for row_info in _thread_rows:
			(row_info["row"] as HBoxContainer).visible = false
		_empty_thread_label.visible = _thread_items.is_empty()
		return

	for i in range(_thread_rows.size()):
		var row: HBoxContainer = _thread_rows[i]["row"]
		var label: Label = _thread_rows[i]["label"]
		var button: Button = _thread_rows[i]["button"]
		if i >= _thread_items.size():
			row.visible = false
			continue

		var item_v: Variant = _thread_items[i]
		if not (item_v is Dictionary):
			row.visible = false
			continue
		var item: Dictionary = item_v
		var item_id := str(item.get("id", ""))
		var is_selected := item_id == selected_thread_id

		var virtue := _title_case(str(item.get("virtue", "unknown")))
		var quality := _title_case(str(item.get("quality_tier", "broken")))
		label.text = "%s • %s" % [virtue, quality]
		button.text = "Selected" if is_selected else "Offer"
		button.disabled = is_selected
		row.modulate = Color(1.0, 0.92, 0.72) if is_selected else Color(1, 1, 1)
		row.visible = true

	_empty_thread_label.visible = _thread_items.is_empty()


func _render_invitation(data: Dictionary, phase: String) -> void:
	var selected_echo_v: Variant = data.get("selected_echo", {})
	var selected_echo: Dictionary = selected_echo_v if selected_echo_v is Dictionary else {}
	var echo_name := str(selected_echo.get("name", "No Echo Selected"))
	var standing := int(selected_echo.get("standing", 1))
	var origin := _title_case(str(selected_echo.get("calling_origin", "")))
	var origin_suffix := ""
	if not origin.is_empty():
		origin_suffix = " • %s" % origin
	if _echo_panel_title != null:
		_echo_panel_title.text = "%s • Standing %d%s" % [echo_name, standing, origin_suffix]

	var lines: Array = []
	var invitation_v: Variant = data.get("invitation_lines", [])
	if invitation_v is Array:
		lines = invitation_v

	if phase == "echo_missing":
		lines = ["Select an Echo from Echo Party to begin this rite."]
	elif phase == "thread_select":
		lines = ["Choose one Thread to offer.", "The house will answer once the rite begins."]

	for i in range(_invitation_labels.size()):
		var label: Label = _invitation_labels[i]
		if i < lines.size():
			label.text = str(lines[i])
			label.visible = true
		else:
			label.text = ""
			label.visible = false

	# Candidate rows are repurposed as static invitation text rows.
	var row_1: Node = %CandidateRow1
	var row_2: Node = %CandidateRow2
	var row_3: Node = %CandidateRow3
	var select_1: Node = %CandidateSelectButton1
	var select_2: Node = %CandidateSelectButton2
	var select_3: Node = %CandidateSelectButton3
	if row_1 != null:
		row_1.visible = true
	if row_2 != null:
		row_2.visible = false
	if row_3 != null:
		row_3.visible = false
	if select_1 != null:
		select_1.visible = false
	if select_2 != null:
		select_2.visible = false
	if select_3 != null:
		select_3.visible = false

	_empty_candidate_label.visible = lines.is_empty()


func _render_resolution(data: Dictionary) -> void:
	var outcome := str(data.get("outcome", "")).strip_edges().to_lower()
	if outcome.is_empty():
		_outcome_label.text = "Outcome"
	else:
		_outcome_label.text = "Outcome: %s" % _title_case(outcome)

	var lines_v: Variant = data.get("aftermath_lines", [])
	var lines: Array = lines_v if lines_v is Array else []
	for i in range(_aftermath_labels.size()):
		var label: Label = _aftermath_labels[i]
		if i < lines.size():
			label.text = str(lines[i])
			label.visible = true
		else:
			label.text = ""
			label.visible = false

	var non_chosen_v: Variant = data.get("non_chosen", [])
	var non_chosen: Array = non_chosen_v if non_chosen_v is Array else []
	for i in range(_non_chosen_labels.size()):
		var label: Label = _non_chosen_labels[i]
		if i < non_chosen.size() and non_chosen[i] is Dictionary:
			var item: Dictionary = non_chosen[i]
			label.text = str(item.get("ripple_line", ""))
			label.visible = not label.text.is_empty()
		else:
			label.text = ""
			label.visible = false

	# V2-VOICE-001: show rite bark below aftermath lines if present.
	var echo_bark_v: Variant = data.get("echo_bark", {})
	var bark_line := ""
	if echo_bark_v is Dictionary:
		bark_line = str((echo_bark_v as Dictionary).get("line", ""))
	_rite_bark_label.text = "\"%s\"" % bark_line if not bark_line.is_empty() else ""
	_rite_bark_label.visible = not bark_line.is_empty()


func _apply_phase_visibility(phase: String) -> void:
	_thread_panel.visible = phase == "thread_select" or phase == "invitation" or phase == "echo_missing"
	_echo_panel.visible = phase == "thread_select" or phase == "invitation" or phase == "echo_missing"
	_resolution_panel.visible = phase == "aftermath"


func _apply_action_slots(actions: Dictionary) -> void:
	_apply_slot_to_button(actions, "nav.back", _back_button, "Back")
	_apply_slot_to_button(actions, "cta.begin_rite", _begin_rite_button, "Begin Rite")
	_apply_slot_to_button(actions, "cta.confirm", _confirm_button, "Confirm")


func _apply_slot_to_button(actions: Dictionary, slot: String, button: Button, fallback_label: String) -> void:
	var action_v: Variant = actions.get(slot, {})
	if action_v is Dictionary:
		var action: Dictionary = action_v
		button.text = str(action.get("label", fallback_label))
		button.disabled = bool(action.get("disabled", false))
	else:
		button.text = fallback_label
		button.disabled = true


func _on_back_pressed() -> void:
	_emit_slot_action("nav.back")


func _on_begin_rite_pressed() -> void:
	_emit_slot_action("cta.begin_rite")


func _on_confirm_pressed() -> void:
	_emit_slot_action("cta.confirm")


func _on_thread_row_pressed(index: int) -> void:
	if index < 0 or index >= _thread_items.size():
		return
	var item_v: Variant = _thread_items[index]
	if not (item_v is Dictionary):
		return
	var item: Dictionary = item_v
	action_requested.emit({
		"type": "weave.select_thread",
		"thread_id": str(item.get("id", "")),
	})


func _on_thread_card_selected(thread_id: String) -> void:
	if thread_id.is_empty():
		return
	action_requested.emit({
		"type": "weave.select_thread",
		"thread_id": thread_id,
	})


func _emit_slot_action(slot: String) -> void:
	var actions_v: Variant = _last_snapshot.get("actions", {})
	if not (actions_v is Dictionary):
		return
	var actions: Dictionary = actions_v
	var action_v: Variant = actions.get(slot, {})
	if action_v is Dictionary and not (action_v as Dictionary).is_empty():
		action_requested.emit((action_v as Dictionary).duplicate())


func _phase_title(phase: String) -> String:
	match phase:
		"echo_missing":
			return "Choose Echo"
		"thread_select":
			return "Choose Thread"
		"invitation":
			return "Invitation"
		"aftermath":
			return "Resolution"
		_:
			return "Weaving Rite"


func _title_case(value: String) -> String:
	if value.is_empty():
		return ""
	return value.substr(0, 1).to_upper() + value.substr(1)
