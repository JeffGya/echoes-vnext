class_name ContactModal
extends Control

signal action_requested(action: Dictionary)
signal dismiss_requested

const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")

@onready var _role: Label = %RoleLabel
@onready var _name: Label = %NameLabel
@onready var _meta: Label = %MetaLabel
@onready var _line: Label = %LineLabel
@onready var _reaction: Label = %ReactionLabel
@onready var _npc_zone: PanelContainer = %NPCZone
@onready var _confirm_button: Button = %ConfirmButton
@onready var _disengage_button: Button = %DisengageButton
@onready var _safe_frame: MarginContainer = %SafeFrame
@onready var _card: PanelContainer = $SafeFrame/Center/Card
@onready var _body_scroll: ScrollContainer = %BodyScroll

var _consult_action: Dictionary = {}
var _disengage_action: Dictionary = {}
var _option_actions: Array = []
var _selected_ids: Array[String] = []
var _option_ids: Array[String] = []
var _cards: Array[Dictionary] = []
var _presentation_key: String = ""

func _ready() -> void:
	_ensure_refs()
	_cards = [
		_card_refs(%OptionCard0),
		_card_refs(%OptionCard1),
		_card_refs(%OptionCard2),
		_card_refs(%OptionCard3),
		_card_refs(%OptionCard4),
	]
	for i in range(_cards.size()):
		var button := _cards[i]["button"] as Button
		var option_callable := Callable(self, "_on_option_pressed").bind(i)
		if not button.pressed.is_connected(option_callable):
			button.pressed.connect(option_callable)
	if not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)
	if not _disengage_button.pressed.is_connected(_on_disengage_pressed):
		_disengage_button.pressed.connect(_on_disengage_pressed)

func present(payload: Dictionary) -> void:
	_ensure_refs()
	_apply_layout(payload)
	var contact: Dictionary = payload.get("contact", {})
	var data: Dictionary = payload.get("data", {})
	var actions: Dictionary = payload.get("actions", {})
	var responses_v: Variant = data.get("contact_responses", [])
	var responses: Array = responses_v if responses_v is Array else []
	var bids_v: Variant = data.get("contact_echo_bids", [])
	var bids: Array = bids_v if bids_v is Array else []
	var presentation_key := _make_presentation_key(contact, responses, bids, actions)
	var same_presentation := not _presentation_key.is_empty() and presentation_key == _presentation_key
	var previous_selected := _selected_ids.duplicate() if same_presentation else []
	var previous_focus := _focused_control_key() if same_presentation else ""
	_role.text = str(contact.get("role_label", str(contact.get("role", "")).capitalize()))
	_name.text = str(contact.get("name", "Unknown"))
	_meta.text = _meta_text(contact)
	var npc_line := str(contact.get("npc_line", ""))
	_line.text = npc_line if not npc_line.is_empty() else "..."
	_npc_zone.self_modulate = _npc_ambient_color(
		int(contact.get("fear", 50)),
		int(contact.get("morale", 50))
	)
	_show_reaction(str(contact.get("npc_reaction_word", "")))

	var disengage_v: Variant = actions.get("cta.disengage_contact", {})
	_disengage_action = disengage_v if disengage_v is Dictionary else {}
	_disengage_button.visible = not _disengage_action.is_empty()
	_clear_options()

	if responses.is_empty():
		_render_picker(bids, actions)
		if same_presentation:
			for selected_id_v in previous_selected:
				var selected_id := str(selected_id_v)
				if selected_id in _option_ids and _selected_ids.size() < 3:
					_selected_ids.append(selected_id)
			_confirm_button.disabled = _selected_ids.is_empty()
			_refresh_picker_card_states()
	else:
		_render_responses(responses, actions)
	_presentation_key = presentation_key
	if same_presentation:
		_restore_focus(previous_focus)

func _ensure_refs() -> void:
	if _role == null:
		_role = get_node_or_null("%RoleLabel") as Label
	if _name == null:
		_name = get_node_or_null("%NameLabel") as Label
	if _meta == null:
		_meta = get_node_or_null("%MetaLabel") as Label
	if _line == null:
		_line = get_node_or_null("%LineLabel") as Label
	if _reaction == null:
		_reaction = get_node_or_null("%ReactionLabel") as Label
	if _npc_zone == null:
		_npc_zone = get_node_or_null("%NPCZone") as PanelContainer
	if _confirm_button == null:
		_confirm_button = get_node_or_null("%ConfirmButton") as Button
	if _disengage_button == null:
		_disengage_button = get_node_or_null("%DisengageButton") as Button
	if _safe_frame == null:
		_safe_frame = get_node_or_null("%SafeFrame") as MarginContainer
	if _card == null:
		_card = get_node_or_null("SafeFrame/Center/Card") as PanelContainer
	if _body_scroll == null:
		_body_scroll = get_node_or_null("%BodyScroll") as ScrollContainer
	if _cards.is_empty():
		_cards = [
			_card_refs(get_node("%OptionCard0") as PanelContainer),
			_card_refs(get_node("%OptionCard1") as PanelContainer),
			_card_refs(get_node("%OptionCard2") as PanelContainer),
			_card_refs(get_node("%OptionCard3") as PanelContainer),
			_card_refs(get_node("%OptionCard4") as PanelContainer),
		]

func _clear_options() -> void:
	_option_actions.clear()
	_selected_ids.clear()
	_option_ids.clear()
	for card in _cards:
		var root := card["root"] as Control
		var button := card["button"] as Button
		var state := card["state"] as Label
		root.visible = false
		root.modulate = Color(1, 1, 1, 1)
		root.theme_type_variation = &"RealmContactOptionCard"
		state.text = " "
		state.visible = true
		state.modulate = Color(1, 1, 1, 0)
		if button.has_focus():
			button.release_focus()
		button.toggle_mode = false
		button.button_pressed = false
		button.disabled = false
		button.modulate = Color.WHITE
	if _confirm_button.has_focus():
		_confirm_button.release_focus()
	if _disengage_button.has_focus():
		_disengage_button.release_focus()
	_confirm_button.button_pressed = false
	_confirm_button.modulate = Color.WHITE
	_disengage_button.button_pressed = false
	_disengage_button.modulate = Color.WHITE
	_confirm_button.visible = false

func _render_picker(bids: Array, actions: Dictionary) -> void:
	var consult_v: Variant = actions.get("cta.consult_echoes", {})
	_consult_action = consult_v if consult_v is Dictionary else {}
	for i in range(mini(_cards.size(), bids.size())):
		var bid: Dictionary = bids[i] if bids[i] is Dictionary else {}
		var echo_id := str(bid.get("echo_id", ""))
		if echo_id.is_empty():
			continue
		_populate_card(_cards[i], {
			"echo_id": echo_id,
			"name": str(bid.get("echo_name", "")),
			"calling": str(bid.get("calling", "")),
			"emotional_status": str(bid.get("emotional_status", "")),
			"text": str(bid.get("hint", bid.get("bid_label", ""))),
			"stat_texture": "",
			"bid_type": str(bid.get("bid_type", "")),
		}, true)
		_option_ids.append(echo_id)
	_confirm_button.visible = not _consult_action.is_empty() and not _option_ids.is_empty()
	_confirm_button.disabled = true

func _render_responses(responses: Array, actions: Dictionary) -> void:
	_consult_action = {}
	_confirm_button.visible = false
	for i in range(mini(_cards.size(), responses.size())):
		var resp: Dictionary = responses[i] if responses[i] is Dictionary else {}
		var echo_id := str(resp.get("echo_id", ""))
		var action_v: Variant = actions.get("cta.speak_response." + echo_id, {})
		var action: Dictionary = action_v if action_v is Dictionary else {}
		_populate_card(_cards[i], {
			"echo_id": echo_id,
			"name": str(resp.get("echo_name", "")),
			"calling": str(resp.get("calling", "")),
			"emotional_status": str(resp.get("emotional_status", "")),
			"text": str(resp.get("response_text", "")),
			"stat_texture": str(resp.get("stat_texture", "")),
			"bid_type": str(resp.get("bid_type", "")),
		}, false)
		_option_actions.append(action)

func _on_option_pressed(index: int) -> void:
	if not _consult_action.is_empty():
		if index < 0 or index >= _option_ids.size():
			return
		var echo_id := _option_ids[index]
		if echo_id in _selected_ids:
			_selected_ids.erase(echo_id)
		elif _selected_ids.size() < 3:
			_selected_ids.append(echo_id)
		_confirm_button.disabled = _selected_ids.is_empty()
		_refresh_picker_card_states()
		return
	if index < 0 or index >= _option_actions.size():
		return
	var action: Dictionary = _option_actions[index]
	if action.is_empty():
		return
	dismiss_requested.emit()
	action_requested.emit(action)

func _on_confirm_pressed() -> void:
	if _consult_action.is_empty() or _selected_ids.is_empty():
		return
	var action := _consult_action.duplicate(true)
	action["echo_ids"] = _selected_ids.duplicate()
	action_requested.emit(action)

func _on_disengage_pressed() -> void:
	if _disengage_action.is_empty():
		return
	dismiss_requested.emit()
	action_requested.emit(_disengage_action)

func _meta_text(contact: Dictionary) -> String:
	var disposition := str(contact.get("disposition", ""))
	return _disposition_cue(disposition)

func _disposition_cue(disposition: String) -> String:
	match disposition:
		"bold": return "speaks directly"
		"reflective": return "chooses words carefully"
		"protective": return "stands with arms crossed"
		"wary": return "eyes keep moving"
		"grieving": return "voice is very still"
		"proud": return "holds their ground"
		_: return ""

func _apply_layout(payload: Dictionary) -> void:
	var layout_v: Variant = payload.get("layout", {})
	var layout: Dictionary = layout_v if layout_v is Dictionary else {}
	if _safe_frame != null and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", layout)
	var profile := str(layout.get("profile", "standard"))
	var logical_v: Variant = layout.get("logical_size", Vector2(1280, 720))
	var logical_size: Vector2 = logical_v if logical_v is Vector2 else Vector2(1280, 720)
	var insets_v: Variant = layout.get("safe_insets", Vector4.ZERO)
	var insets: Vector4 = insets_v if insets_v is Vector4 else Vector4.ZERO
	var safe_width := maxf(
		0.0,
		logical_size.x - maxf(16.0, ceilf(insets.x)) - maxf(16.0, ceilf(insets.z))
	)
	var target_card_width := 840.0
	var target_option_width := 248.0
	match profile:
		"wide":
			target_card_width = 960.0
			target_option_width = 260.0
			_body_scroll.custom_minimum_size = Vector2(0, 420)
		"compact":
			target_card_width = 880.0
			_body_scroll.custom_minimum_size = Vector2(0, 280)
		_:
			_body_scroll.custom_minimum_size = Vector2(0, 360)
	_card.custom_minimum_size = Vector2(minf(target_card_width, safe_width), 0)
	for card in _cards:
		(card["root"] as Control).custom_minimum_size = Vector2(target_option_width, 224)

func _card_refs(root: PanelContainer) -> Dictionary:
	return {
		"root": root,
		"name": root.get_node("CardContent/EchoNameLabel") as Label,
		"calling": root.get_node("CardContent/CallingLabel") as Label,
		"emotion_dot": root.get_node("CardContent/EmotionRow/EmotionDotLabel") as Label,
		"emotion": root.get_node("CardContent/EmotionRow/EmotionLabel") as Label,
		"text": root.get_node("CardContent/ResponseLabel") as Label,
		"stat": root.get_node("CardContent/StatTextureLabel") as Label,
		"bid": root.get_node("CardContent/BidBadgeLabel") as Label,
		"state": root.get_node("CardContent/StateLabel") as Label,
		"button": root.get_node("CardButton") as Button,
	}

func _populate_card(card: Dictionary, data: Dictionary, _picker_mode: bool) -> void:
	var root := card["root"] as Control
	var button := card["button"] as Button
	root.visible = true
	root.modulate = Color.WHITE
	root.theme_type_variation = &"RealmContactOptionCard"
	(card["name"] as Label).text = str(data.get("name", ""))
	(card["calling"] as Label).text = str(data.get("calling", ""))
	var emotional_status := str(data.get("emotional_status", ""))
	var emotion_label := card["emotion"] as Label
	emotion_label.text = EmotionPresentation.display_name(emotional_status)
	var emotion_dot := card["emotion_dot"] as Label
	emotion_dot.add_theme_color_override("font_color", EmotionPresentation.color(emotional_status))
	(card["text"] as Label).text = str(data.get("text", ""))
	var stat_texture := str(data.get("stat_texture", ""))
	var stat_label := card["stat"] as Label
	stat_label.text = stat_texture
	stat_label.visible = not stat_texture.is_empty()
	var bid_type := str(data.get("bid_type", ""))
	var bid_label := card["bid"] as Label
	bid_label.text = _bid_badge_text(bid_type)
	bid_label.visible = not bid_type.is_empty()
	bid_label.add_theme_color_override("font_color", _bid_badge_color(bid_type))
	var state_label := card["state"] as Label
	state_label.text = " "
	state_label.visible = true
	state_label.modulate = Color(1, 1, 1, 0)
	button.toggle_mode = false
	button.button_pressed = false
	button.disabled = false
	button.modulate = Color.WHITE

func _refresh_picker_card_states() -> void:
	for i in range(_cards.size()):
		var card := _cards[i]
		var root := card["root"] as Control
		if not root.visible:
			continue
		var button := card["button"] as Button
		var state := card["state"] as Label
		var echo_id := _option_ids[i] if i < _option_ids.size() else ""
		var selected := echo_id in _selected_ids
		var unavailable := not selected and _selected_ids.size() >= 3
		button.button_pressed = false
		button.disabled = unavailable
		root.modulate = Color.WHITE
		if selected:
			root.theme_type_variation = &"RealmContactOptionSelected"
			state.text = "✓"
			state.visible = true
			state.modulate = Color.WHITE
		elif unavailable:
			root.theme_type_variation = &"RealmContactOptionUnavailable"
			root.modulate = Color(1, 1, 1, 0.48)
			state.text = " "
			state.visible = true
			state.modulate = Color(1, 1, 1, 0)
		else:
			root.theme_type_variation = &"RealmContactOptionCard"
			state.text = " "
			state.visible = true
			state.modulate = Color(1, 1, 1, 0)

func _show_reaction(reaction: String) -> void:
	if reaction.is_empty():
		_reaction.visible = false
		return
	_reaction.text = reaction
	_reaction.visible = true
	_reaction.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_reaction, "modulate:a", 1.0, 0.35)

func _npc_ambient_color(fear: int, morale: int) -> Color:
	if fear > 65:
		return Color(0.20, 0.06, 0.06, 1.0)
	if fear > 45:
		return Color(0.20, 0.12, 0.04, 1.0)
	if morale >= 60 and fear <= 30:
		return Color(0.05, 0.18, 0.10, 1.0)
	return Color(0.07, 0.07, 0.12, 1.0)

func _bid_badge_text(bid_type: String) -> String:
	match bid_type:
		"alignment": return "⬥"
		"reactive": return "⬥"
		_: return "⬥"

func _bid_badge_color(bid_type: String) -> Color:
	match bid_type:
		"alignment": return Color("#C8A96E")
		"reactive": return Color("#C87830")
		_: return Color(0.5, 0.5, 0.5, 1.0)

func _make_presentation_key(
	contact: Dictionary,
	responses: Array,
	bids: Array,
	actions: Dictionary
) -> String:
	var mode := "picker" if responses.is_empty() else "response"
	var contact_id := str(contact.get("id", ""))
	if contact_id.is_empty():
		contact_id = "%s|%s" % [str(contact.get("role", "")), str(contact.get("name", ""))]
	var parts: Array[String] = [
		contact_id,
		str(contact.get("turn_current", "")),
		str(contact.get("turn_count", "")),
		str(contact.get("npc_line", "")),
		str(contact.get("npc_reaction_word", "")),
		mode,
	]
	var options := bids if mode == "picker" else responses
	for option_v in options:
		var option: Dictionary = option_v if option_v is Dictionary else {}
		var echo_id := str(option.get("echo_id", ""))
		var option_action: Dictionary = {}
		if mode == "response":
			var action_v: Variant = actions.get("cta.speak_response." + echo_id, {})
			option_action = action_v if action_v is Dictionary else {}
		parts.append("\u001f".join(PackedStringArray([
			echo_id,
			str(option.get("echo_name", "")),
			str(option.get("calling", "")),
			str(option.get("emotional_status", "")),
			str(option.get("hint", option.get("response_text", option.get("bid_label", "")))),
			str(option.get("stat_texture", "")),
			str(option.get("bid_type", "")),
			str(option_action.get("type", "")),
			str(option_action.get("slot", "")),
			str(option_action.get("disabled", false)),
		])))
	var consult_v: Variant = actions.get("cta.consult_echoes", {})
	var consult: Dictionary = consult_v if consult_v is Dictionary else {}
	parts.append("\u001f".join(PackedStringArray([
		str(consult.get("type", "")),
		str(consult.get("slot", "")),
		str(consult.get("disabled", false)),
	])))
	return "\u001e".join(PackedStringArray(parts))

func _focused_control_key() -> String:
	for i in range(_cards.size()):
		var button := _cards[i]["button"] as Button
		if button.has_focus():
			return "option:%d" % i
	if _confirm_button.has_focus():
		return "confirm"
	if _disengage_button.has_focus():
		return "disengage"
	return ""

func _restore_focus(focus_key: String) -> void:
	if focus_key.begins_with("option:"):
		var index := focus_key.trim_prefix("option:").to_int()
		if index >= 0 and index < _cards.size():
			var root := _cards[index]["root"] as Control
			var button := _cards[index]["button"] as Button
			if root.visible and not button.disabled:
				button.grab_focus()
				return
	if focus_key == "confirm" and _confirm_button.visible and not _confirm_button.disabled:
		_confirm_button.grab_focus()
	elif focus_key == "disengage" and _disengage_button.visible and not _disengage_button.disabled:
		_disengage_button.grab_focus()
