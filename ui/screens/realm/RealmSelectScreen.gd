# res://ui/screens/realm/RealmSelectScreen.gd
# UI-003: Realm selection screen — 3-column grid of realm cards.
# Dispatches flow.select_realm per card tap (not via snapshot.actions).
# nav.back slot returns to Sanctum.

extends Control

signal action_requested(action: Dictionary)

const RealmCardScene := preload("res://ui/components/RealmCardItem.tscn")

@onready var title_label: Label        = %Title
@onready var subtitle_label: Label     = %Subtitle
@onready var realm_list: GridContainer = %RealmList
@onready var back_btn: Button          = %Back

var _action_back: Dictionary = {}

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	get_viewport().size_changed.connect(_update_columns)
	_update_columns()

func _update_columns() -> void:
	var w := get_viewport_rect().size.x
	realm_list.columns = 3 if w >= 800 else 2

func set_snapshot(snap: Dictionary) -> void:
	var data: Dictionary    = snap.get("data", {})    if snap.get("data")    is Dictionary else {}
	var actions: Dictionary = snap.get("actions", {}) if snap.get("actions") is Dictionary else {}

	title_label.text    = str(data.get("title", "Select the realm you want to enter"))
	subtitle_label.text = "(this locks in your realm until you complete it)"

	var back_v: Variant = actions.get("nav.back", {})
	_action_back = back_v if back_v is Dictionary else {}
	back_btn.disabled = _action_back.is_empty()

	_rebuild_realm_grid(data)

func _rebuild_realm_grid(data: Dictionary) -> void:
	for c in realm_list.get_children():
		c.queue_free()

	var realms_v: Variant = data.get("realms", [])
	var realms: Array = realms_v if realms_v is Array else []

	for r_v in realms:
		if not (r_v is Dictionary):
			continue
		var card: RealmCardItem = RealmCardScene.instantiate()
		realm_list.add_child(card)
		card.setup(r_v)
		card.card_pressed.connect(func(rid: String) -> void:
			action_requested.emit({ "type": "flow.select_realm", "realm_id": rid })
		)

func _on_back_pressed() -> void:
	if _action_back.is_empty():
		return
	action_requested.emit(_action_back)
