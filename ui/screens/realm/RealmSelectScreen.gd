# res://ui/screens/realm/RealmSelectScreen.gd
# UI-003: Realm selection screen — 3-column grid of realm cards.
# Dispatches flow.select_realm per card tap (not via snapshot.actions).
# nav.back slot returns to Sanctum.

extends Control

signal action_requested(action: Dictionary)
signal modal_requested(modal_id: StringName, payload: Dictionary)

const RealmCardScene := preload("res://ui/components/RealmCardItem.tscn")

@onready var title_label: Label        = %Title
@onready var subtitle_label: Label     = %Subtitle
@onready var root_panel: PanelContainer = %RootPanel
@onready var realm_list: GridContainer = %RealmList
@onready var back_btn: Button          = %Back

var _action_back: Dictionary = {}
var _bottom_content_exclusion := 108
var _profile: StringName = &"standard"
var _logical_size := Vector2(1280, 720)

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	get_viewport().size_changed.connect(_update_columns)
	_update_columns()

func _update_columns() -> void:
	var grid := realm_list if realm_list != null else find_child("RealmList", true, false) as GridContainer
	if grid == null:
		return
	if _profile == &"compact":
		grid.columns = 1
		return
	if _profile == &"wide":
		grid.columns = 3
		return
	var w := _logical_size.x
	grid.columns = 3 if w >= 800 else 2

func set_snapshot(snap: Dictionary) -> void:
	var data: Dictionary    = snap.get("data", {})    if snap.get("data")    is Dictionary else {}
	var actions: Dictionary = snap.get("actions", {}) if snap.get("actions") is Dictionary else {}

	title_label.text    = str(data.get("title", "Select the realm you want to enter"))
	subtitle_label.text = "(this locks in your realm until you complete it)"

	var back_v: Variant = actions.get("nav.back", {})
	_action_back = back_v if back_v is Dictionary else {}
	back_btn.disabled = _action_back.is_empty()

	_rebuild_realm_grid(data)

func set_layout(layout: Dictionary) -> void:
	_profile = layout.get("profile", &"standard")
	var logical_size_v: Variant = layout.get("logical_size", Vector2(1280, 720))
	_logical_size = logical_size_v if logical_size_v is Vector2 else Vector2(1280, 720)
	var safe: Vector4 = layout.get("safe_insets", Vector4.ZERO)
	var viewport_w := float(_logical_size.x)
	var cap := 1180.0 if _profile == &"wide" else 980.0
	var available_w := maxf(320.0, viewport_w - float(32 + int(ceilf(safe.x)) + int(ceilf(safe.z))))
	var content_w := minf(available_w, cap)
	var left := float(16 + int(ceilf(safe.x))) + maxf(0.0, (available_w - content_w) * 0.5)
	offset_left = left
	offset_top = float(16 + int(ceilf(safe.y)))
	offset_right = -(viewport_w - left - content_w)
	offset_bottom = -float(_bottom_content_exclusion)
	_update_columns()

func set_bottom_content_exclusion(value: int) -> void:
	_bottom_content_exclusion = maxi(0, value)

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
