class_name RealmShell
extends Control

signal action_requested(action: Dictionary)

var _active_overlay: Control = null

var _stage_map_scene  := preload("res://ui/screens/StageMapScreen.tscn")
var _stage_scene      := preload("res://ui/screens/StageScreen.tscn")
var _combat_board_scene := preload("res://ui/screens/CombatBoardScreen.tscn")
var _resolve_scene    := preload("res://ui/screens/ResolveScreen.tscn")

var _scene_by_flow_type: Dictionary = {}

@onready var _overlay_root: Control      = $OverlayRoot
@onready var _echo_bar:     HBoxContainer = %EchoBar

func _ready() -> void:
	_scene_by_flow_type = {
		"flow.stage_map": _stage_map_scene,
		"flow.stage":     _stage_scene,
		"flow.encounter": _combat_board_scene,
		"flow.resolve":   _resolve_scene,
	}

func set_snapshot(snap: Dictionary) -> void:
	_update_echo_bar(snap)
	_show_overlay_for_type(str(snap.get("type", "")), snap)

# ─────────────────────────────────────────────────────────────
# Echo bar — shell-owned, live-updates on every snapshot
# ─────────────────────────────────────────────────────────────

## Extracts party actors from the snapshot and rebuilds the bar.
## Called on every set_snapshot() — always reflects the latest HP + emotional state.
func _update_echo_bar(snap: Dictionary) -> void:
	var snap_type := str(snap.get("type", ""))
	var data: Dictionary = snap.get("data", {})

	var party: Array = []
	match snap_type:
		"flow.encounter", "flow.resolve":
			# Encounter snapshots include all combatants — filter for echoes only.
			for a in data.get("actors", []):
				if a is Dictionary and str(a.get("faction", "")) == "echo":
					party.append(a)
		"flow.stage", "flow.stage_map":
			# Stage snapshots include party_preview: { name, rank, calling_origin }
			var preview: Variant = data.get("party_preview", [])
			if preview is Array:
				party = preview

	# Rebuild from scratch — max 5 cards, trivially fast.
	for child in _echo_bar.get_children():
		child.queue_free()
	for actor in party:
		if actor is Dictionary:
			_echo_bar.add_child(_make_echo_card(actor))


## Builds a single echo status card for the bar.
## Handles two data shapes:
##   Encounter/Resolve: { name, hp, max_hp, morale_status, status, faction }
##   Stage/StageMap:    { name, rank, calling_origin }
func _make_echo_card(actor: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(100, 80)

	var name_str: String = str(actor.get("name", "?"))

	# HP label — only shown when combat data is present.
	if actor.has("hp") and actor.has("max_hp"):
		var hp_label := Label.new()
		hp_label.add_theme_font_size_override("font_size", 11)
		hp_label.text = "HP %d/%d" % [int(actor.get("hp", 0)), int(actor.get("max_hp", 1))]
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(hp_label)

	# Portrait circle — initials.
	var portrait := _EchoPortrait.new(name_str)
	portrait.custom_minimum_size = Vector2(44, 44)
	card.add_child(portrait)

	# Name.
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.text = name_str
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	# Status / morale — morale_status when in combat, calling_origin pre-combat.
	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	if actor.has("morale_status"):
		status_label.text = str(actor.get("morale_status", "Normal"))
	else:
		status_label.text = str(actor.get("calling_origin", "Ready"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(status_label)

	return card


## Minimal inner class — draws a coloured circle with 2-letter echo initials.
## Mirrors the visual language of CombatTokenLayer tokens.
class _EchoPortrait extends Control:
	var _initials: String

	func _init(echo_name: String) -> void:
		_initials = echo_name.substr(0, 2).to_upper()

	func _draw() -> void:
		var center := size / 2.0
		var radius: float = minf(center.x, center.y) - 2.0
		draw_circle(center, radius, Color(0.25, 0.45, 0.75))
		var font := ThemeDB.fallback_font
		var font_size := 13
		var text_size := font.get_string_size(_initials, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos  := center - text_size / 2.0 + Vector2(0, text_size.y * 0.1)
		draw_string(font, text_pos, _initials, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


# ─────────────────────────────────────────────────────────────
# Overlay routing
# ─────────────────────────────────────────────────────────────

func _show_overlay_for_type(snap_type: String, snap: Dictionary) -> void:
	if not _scene_by_flow_type.has(snap_type):
		push_warning("RealmShell: no overlay mapped for snapshot type: " + snap_type)
		return

	var packed: PackedScene = _scene_by_flow_type[snap_type]
	if packed == null:
		return

	# Scene reuse: if same scene is already active, just update snapshot
	if _active_overlay != null and _active_overlay.scene_file_path == packed.resource_path:
		if _active_overlay.has_method("set_snapshot"):
			_active_overlay.call("set_snapshot", snap)
		return

	# Otherwise replace overlay
	if _active_overlay != null:
		_active_overlay.queue_free()
		_active_overlay = null

	var overlay := packed.instantiate()
	_overlay_root.add_child(overlay)
	_active_overlay = overlay as Control

	if _active_overlay != null and _active_overlay.has_signal("action_requested"):
		var ok := _active_overlay.connect("action_requested", Callable(self, "_on_overlay_action_requested"))
		if ok != OK:
			push_warning("RealmShell: failed to connect overlay action_requested (err=%d)" % ok)

	if _active_overlay != null and _active_overlay.has_method("set_snapshot"):
		_active_overlay.call("set_snapshot", snap)

func _on_overlay_action_requested(action: Dictionary) -> void:
	action_requested.emit(action)
