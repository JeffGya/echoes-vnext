# res://ui/screens/sanctum/VowScreen.gd
# VOW-001: Vow doctrine management screen.
# Two-panel layout: card list on left, detail panel on right.
# Selecting an undiscovered vow shows only the riddle hint.
# Selecting a discovered vow shows full detail + pledge/break action.
# Never reads sim internals directly — all data from snapshot.

extends Control
class_name VowScreen

signal action_requested(action: Dictionary)

var _vow_card_scene := preload("res://ui/screens/sanctum/VowCard.tscn")

# ---- Node refs ----
@onready var back_button: Button               = %BackButton
@onready var realm_locked_label: Label         = %RealmLockedLabel
@onready var vow_card_container: VBoxContainer = %VowCardContainer

# Detail panel states
@onready var empty_label: Label                = %EmptyLabel
@onready var hint_content: VBoxContainer       = %HintContent
@onready var hint_label: Label                 = %HintLabel
@onready var discovered_content: VBoxContainer = %DiscoveredContent

# Discovered detail fields
@onready var detail_image_rect: ColorRect      = %DetailImageRect
@onready var proverb_twi_label: Label          = %ProverbTwiLabel
@onready var proverb_en_label: Label           = %ProverbEnLabel
@onready var description_label: Label          = %DescriptionLabel
@onready var benefit_label: Label              = %BenefitLabel
@onready var tradeoff_label: Label             = %TradeoffLabel
@onready var breaking_cost_label: Label        = %BreakingCostLabel
@onready var action_button: Button             = %ActionButton

# Pledge moment overlay (shown after pledging — moment of reflection)
@onready var pledge_moment_overlay: Control    = %PledgeMomentOverlay
@onready var pledge_twi_label: Label           = %PledgeTwiLabel
@onready var pledge_en_label: Label            = %PledgeEnLabel
@onready var pledge_dismiss_button: Button     = %PledgeDismissButton

# Break confirm overlay (shown before breaking — irreversible gate)
@onready var break_confirm_overlay: Control    = %BreakConfirmOverlay
@onready var break_vow_name_label: Label       = %BreakVowNameLabel
@onready var break_penalty_label: Label        = %BreakPenaltyLabel
@onready var break_keep_button: Button         = %BreakKeepButton
@onready var break_confirm_button: Button      = %BreakConfirmButton

var _last_snapshot: Dictionary = {}
var _selected_vow_id: String   = ""


func _ready() -> void:
	back_button.pressed.connect(func():
		_emit_slot_action("nav.back")
	)
	action_button.pressed.connect(_on_action_button_pressed)
	pledge_dismiss_button.pressed.connect(_on_dismiss_pledge_pressed)
	break_keep_button.pressed.connect(_on_cancel_break_pressed)
	break_confirm_button.pressed.connect(_on_confirm_break_pressed)


func set_snapshot(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot
	var data_v: Variant = snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	_render_realm_locked(data)
	_render_cards(data)

	# Keep the selected card in sync after snapshot updates (e.g. after pledge/break)
	if _selected_vow_id != "":
		var available_v: Variant = data.get("available_vows", [])
		var available: Array = available_v if available_v is Array else []
		var found := false
		for entry_v in available:
			if not (entry_v is Dictionary):
				continue
			var entry: Dictionary = entry_v
			if str(entry.get("vow_id", "")) == _selected_vow_id:
				_show_detail(entry)
				found = true
				break
		if not found:
			_show_empty()
	else:
		_show_empty()


# ---- Rendering ----

func _render_realm_locked(_data: Dictionary) -> void:
	# Pledging is allowed at any time — this label is unused in VOW-001.
	if realm_locked_label != null:
		realm_locked_label.visible = false


func _render_cards(data: Dictionary) -> void:
	for child in vow_card_container.get_children():
		child.queue_free()

	var available_v: Variant = data.get("available_vows", [])
	var available: Array = available_v if available_v is Array else []

	for entry_v in available:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var card: VowCard = _vow_card_scene.instantiate() as VowCard
		vow_card_container.add_child(card)
		card.setup(entry)
		card.card_selected.connect(func(e: Dictionary):
			_selected_vow_id = str(e.get("vow_id", ""))
			_show_detail(e)
		)


# ---- Detail panel ----

func _show_empty() -> void:
	empty_label.visible        = true
	hint_content.visible       = false
	discovered_content.visible = false


func _show_detail(entry: Dictionary) -> void:
	var is_unlocked: bool = bool(entry.get("is_unlocked", false))

	if not is_unlocked:
		empty_label.visible        = false
		hint_content.visible       = true
		discovered_content.visible = false
		hint_label.text = str(entry.get("unlock_hint", ""))
		return

	empty_label.visible        = false
	hint_content.visible       = false
	discovered_content.visible = true

	# V2-VOW-002: remove any previously added dynamic labels before re-populating.
	for _dc in discovered_content.get_children():
		if _dc.name == "ComplianceCountLabel":
			_dc.free()

	proverb_twi_label.text   = str(entry.get("proverb_twi", ""))
	proverb_en_label.text    = '"%s"' % str(entry.get("proverb_en", ""))
	description_label.text   = str(entry.get("description", ""))
	benefit_label.text       = "+ %s" % str(entry.get("benefit_label", ""))
	tradeoff_label.text      = "- %s" % str(entry.get("tradeoff_label", ""))
	breaking_cost_label.text = str(entry.get("breaking_cost_hint", ""))

	var is_active: bool = bool(entry.get("is_active", false))
	var data_v: Variant = _last_snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	# V2-VOW-002: compliance count — shown below benefit line when vow is active.
	if is_active:
		var av_v: Variant = data.get("active_vow", {})
		var av: Dictionary = av_v if av_v is Dictionary else {}
		var comp_count := int(av.get("compliance_count", 0))
		if comp_count > 0:
			var comp_lbl := Label.new()
			comp_lbl.name = "ComplianceCountLabel"
			comp_lbl.text = "%d stage%s honored" % [comp_count, "s" if comp_count != 1 else ""]
			comp_lbl.add_theme_font_size_override("font_size", 12)
			comp_lbl.add_theme_color_override("font_color", Color("#A8865A"))  # Warm Brass
			discovered_content.add_child_below_node(benefit_label, comp_lbl)
	var can_pledge: bool = bool(data.get("can_pledge", false))

	if is_active:
		var actions_v: Variant = _last_snapshot.get("actions", {})
		var actions: Dictionary = actions_v if actions_v is Dictionary else {}
		var break_v: Variant = actions.get("cta.break", {})
		var break_a: Dictionary = break_v if break_v is Dictionary else {}
		action_button.text     = "Break Vow"
		action_button.disabled = bool(break_a.get("disabled", true))
		action_button.visible  = true
	elif can_pledge:
		action_button.text     = "Pledge Vow (Tier 1)"
		action_button.disabled = false
		action_button.visible  = true
	else:
		action_button.visible = false


func _on_action_button_pressed() -> void:
	if _selected_vow_id.is_empty():
		return

	var data_v: Variant = _last_snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actions_v: Variant = _last_snapshot.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}

	# Find the selected entry
	var available_v: Variant = data.get("available_vows", [])
	var available: Array = available_v if available_v is Array else []
	var is_active := false
	var selected_entry: Dictionary = {}
	for entry_v in available:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		if str(entry.get("vow_id", "")) == _selected_vow_id:
			is_active = bool(entry.get("is_active", false))
			selected_entry = entry
			break

	if is_active:
		# Destructive — show confirmation overlay first; dispatch only on confirm
		_show_break_confirm(selected_entry)
	else:
		# Pledge: dispatch first (synchronous → snapshot updates immediately),
		# then show the moment of reflection overlay.
		var pledge_action: Dictionary = actions.get("cta.pledge", {}).duplicate()
		pledge_action["vow_id"] = _selected_vow_id
		pledge_action["tier"]   = 1
		action_requested.emit(pledge_action)
		_show_pledge_moment(selected_entry)


# ---- Pledge moment overlay ----

func _show_pledge_moment(entry: Dictionary) -> void:
	pledge_twi_label.text = str(entry.get("proverb_twi", ""))
	pledge_en_label.text  = '"%s"' % str(entry.get("proverb_en", ""))
	pledge_moment_overlay.modulate.a = 0.0
	pledge_moment_overlay.visible    = true
	var tw := create_tween()
	tw.tween_property(pledge_moment_overlay, "modulate:a", 1.0, 0.25)


func _on_dismiss_pledge_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(pledge_moment_overlay, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		pledge_moment_overlay.visible = false
	)


# ---- Break confirm overlay ----

func _show_break_confirm(entry: Dictionary) -> void:
	break_vow_name_label.text = str(entry.get("vow_name", ""))
	break_penalty_label.text  = str(entry.get("breaking_cost_hint", ""))
	break_confirm_overlay.modulate.a = 0.0
	break_confirm_overlay.visible    = true
	var tw := create_tween()
	tw.tween_property(break_confirm_overlay, "modulate:a", 1.0, 0.25)


func _on_cancel_break_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(break_confirm_overlay, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		break_confirm_overlay.visible = false
	)


func _on_confirm_break_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(break_confirm_overlay, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		break_confirm_overlay.visible = false
		_emit_slot_action("cta.break")
	)


# ---- Helpers ----

func _emit_slot_action(slot: String) -> void:
	var actions_v: Variant = _last_snapshot.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var action_v: Variant = actions.get(slot, {})
	if action_v is Dictionary and not (action_v as Dictionary).is_empty():
		action_requested.emit((action_v as Dictionary).duplicate())
