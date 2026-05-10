# res://ui/screens/venture/StageExploreScreen.gd
# Merged screen for both flow.stage (preview mode) and flow.stage_explore (explore mode).
# Single Board TileMapLayer is shared across both modes — no scene swap occurs.
# RealmShell's scene-reuse logic ensures the same instance persists through the
# flow.stage → flow.stage_explore transition, so the Begin zoom tween plays on
# the actual board the player will use.
#
# Preview mode  (snap.type == "flow.stage"):
#   Board scaled to fit screen; ? markers for all situations; stage info + directive overlay shown.
#   Begin button triggers zoom tween → emits cta.start → backend transitions to flow.stage_explore.
#
# Explore mode (snap.type == "flow.stage_explore"):
#   Board at 1:1 scale, centered on party pos; HUD visible; Advance + Return buttons.
#   situation_pending data → shows engagement popup (combat confirmation).
#   situation_overlay data → shows non-combat result popup.
#
# Contract (UI-001): set_snapshot / action_requested signal. No sim state access.

class_name StageExploreScreen
extends Control

signal action_requested(action: Dictionary)

# ─── Tile constants ───────────────────────────────────────────────────────────
const _TILE_SOURCE_ID:    int      = 0
const _TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)

# ─── Zoom tween constants (preview → explore transition) ─────────────────────
const _ZOOM_DURATION:  float = 0.35
const _ZOOM_SCALE_MUL: float = 3.0

# ─── Cached actions ───────────────────────────────────────────────────────────
var _cached_start_action:   Dictionary = {}
var _cached_back_action:    Dictionary = {}
var _cached_advance_action: Dictionary = {}
var _cached_return_action:  Dictionary = {}
var _cached_overlay_action: Dictionary = {}
# V2-VOW-002: dynamic vow proverb + condition hint labels in preview panel.
var _vow_proverb_label: Label = null
var _vow_hint_label:    Label = null

# ─── Preview state ────────────────────────────────────────────────────────────
var _preview_scale:  float   = 1.0
var _preview_center: Vector2 = Vector2.ZERO
var _is_zooming:     bool    = false

# ─── Situation marker tracking ────────────────────────────────────────────────
var _situation_markers: Array = []

# ─── @onready refs ────────────────────────────────────────────────────────────
@onready var _board:              TileMapLayer   = $Board
@onready var _situation_layer:    Node2D         = $SituationLayer
@onready var _hidden_template:    Control        = $SituationLayer/HiddenMarkerTemplate
@onready var _revealed_template:  Control        = $SituationLayer/RevealedMarkerTemplate
@onready var _resolved_template:  Control        = $SituationLayer/ResolvedMarkerTemplate
@onready var _party_layer:        Node2D         = $PartyTokenLayer
@onready var _hud_strip:          PanelContainer = $HudStrip
@onready var _turn_label:         Label          = %TurnLabel
@onready var _objectives_label:   Label          = %ObjectivesLabel
@onready var _party_state_label:  Label          = %PartyStateLabel
@onready var _advance_btn:        Button         = %AdvanceButton
@onready var _return_btn:         Button         = %ReturnButton
@onready var _begin_btn:          Button         = %BeginButton
@onready var _stage_info:         PanelContainer = $StageInfoPanel
@onready var _stage_title:        Label          = %StageTitleLabel
@onready var _obj_title:          Label          = %ObjectiveTitleLabel
@onready var _directive_label:    Label          = %DirectiveLabel
@onready var _info_vbox:          VBoxContainer  = $StageInfoPanel/InfoVBox
@onready var _back_btn:           Button         = %BackButton
@onready var _sit_overlay:          PanelContainer = $SituationOverlay
@onready var _sit_header_label:     Label          = %SituationHeaderLabel
@onready var _sit_type_label:       Label          = %SituationTypeLabel
@onready var _sit_result_label:     Label          = %SituationResultLabel
@onready var _intel_clue_label:     Label          = %IntelClueLabel
@onready var _enemy_estimate_label: Label          = %EnemyEstimateLabel
@onready var _dismiss_btn:          Button         = %DismissButton
@onready var _directive_overlay:  Control        = %DirectiveSelectOverlay

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_hidden_template.visible   = false
	_revealed_template.visible = false
	_resolved_template.visible = false
	_sit_overlay.visible       = false
	_directive_overlay.visible = false

	_advance_btn.pressed.connect(_on_advance_pressed)
	_return_btn.pressed.connect(_on_return_pressed)
	_begin_btn.pressed.connect(_on_begin_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	_directive_overlay.action_requested.connect(_on_overlay_action)


# ─── Bespoke Screen Contract ─────────────────────────────────────────────────

func set_snapshot(snap: Dictionary) -> void:
	var snap_type := str(snap.get("type", ""))
	var data: Dictionary    = snap.get("data", {})
	var actions: Dictionary = snap.get("actions", {})

	match snap_type:
		"flow.stage":
			_enter_preview_mode(data, actions)
		_:  # flow.stage_explore
			_enter_explore_mode(data, actions)


# ─── Preview mode ─────────────────────────────────────────────────────────────

func _enter_preview_mode(data: Dictionary, actions: Dictionary) -> void:
	_is_zooming = false

	# Fill board tiles and scale to fit the screen body
	var cols := int(data.get("map_width",  30))
	var rows := int(data.get("map_height", 30))
	_fill_board(cols, rows)
	_build_preview(cols, rows)

	# Situation markers — all hidden in preview (positions only)
	var raw_sits: Variant = data.get("map_situations", [])
	var map_sits: Array   = raw_sits if raw_sits is Array else []
	_rebuild_situations_preview(map_sits)

	# Party token at entry position (instant snap, no animation)
	var entry_v: Variant    = data.get("map_entry_pos", { "col": 0, "row": 0 })
	var entry: Dictionary   = entry_v if entry_v is Dictionary else { "col": 0, "row": 0 }
	var entry_local: Vector2 = _board.map_to_local(Vector2i(int(entry.get("col", 0)), int(entry.get("row", 0))))
	_party_layer.call("init_position", _board_to_screen(entry_local))

	# Stage info
	_stage_title.text = str(data.get("stage_name", "Stage"))
	var obj_count := int(data.get("objective_count", 0))
	_obj_title.text   = "%d Objective%s" % [obj_count, "s" if obj_count != 1 else ""]
	var dir_v: Variant      = data.get("directive", {})
	var dir_data: Dictionary = dir_v if dir_v is Dictionary else {}
	_directive_label.text   = "Directive: " + _label_for_directive(str(dir_data.get("active_id", "")))

	# Cache actions
	var start_v: Variant = actions.get("cta.start", {})
	_cached_start_action = start_v if start_v is Dictionary else {}
	var back_v: Variant  = actions.get("nav.back", {})
	_cached_back_action  = back_v if back_v is Dictionary else {}

	# UI mode: preview
	_hud_strip.hide()
	_advance_btn.hide()
	_return_btn.hide()
	_begin_btn.show()
	_begin_btn.disabled = _cached_start_action.is_empty()
	_stage_info.show()
	_back_btn.show()
	_sit_overlay.hide()

	# Directive blocking overlay — auto-shown on every stage entry
	if not dir_data.is_empty():
		_directive_overlay.call("populate", dir_data)
		_directive_overlay.show()

	# V2-VOW-002: vow proverb + condition hint in preview panel.
	# Remove previous dynamic labels if present.
	if _vow_proverb_label != null:
		_vow_proverb_label.queue_free()
		_vow_proverb_label = null
	if _vow_hint_label != null:
		_vow_hint_label.queue_free()
		_vow_hint_label = null
	var av_v: Variant = data.get("active_vow", {})
	var av: Dictionary = av_v if av_v is Dictionary else {}
	if not av.is_empty():
		var proverb_twi := str(av.get("proverb_twi", ""))
		var proverb_en  := str(av.get("proverb_en", ""))
		if not proverb_twi.is_empty() or not proverb_en.is_empty():
			_vow_proverb_label = Label.new()
			_vow_proverb_label.text = "%s - \"%s\"" % [proverb_twi, proverb_en] if not proverb_twi.is_empty() else '"%s"' % proverb_en
			_vow_proverb_label.add_theme_font_size_override("font_size", 11)
			_vow_proverb_label.add_theme_color_override("font_color", Color("#C8A96E"))  # Akan Gold
			_vow_proverb_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			_info_vbox.add_child(_vow_proverb_label)
		var condition_status := str(av.get("condition_status", "none"))
		var condition_hint   := str(av.get("condition_hint",   ""))
		if condition_status != "none" and not condition_hint.is_empty():
			_vow_hint_label = Label.new()
			_vow_hint_label.text = condition_hint
			_vow_hint_label.add_theme_font_size_override("font_size", 11)
			_vow_hint_label.add_theme_color_override("font_color", Color("#A8865A"))  # Warm Brass — atmospheric, not a warning
			_vow_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			_info_vbox.add_child(_vow_hint_label)

	# Fade in (first entry into screen or returning from explore)
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.25)


# ─── Explore mode ─────────────────────────────────────────────────────────────

func _enter_explore_mode(data: Dictionary, actions: Dictionary) -> void:
	var cols := int(data.get("map_width",  30))
	var rows := int(data.get("map_height", 30))
	_fill_board(cols, rows)

	# Reset board to 1:1 scale, center party on screen
	var ppos_v: Variant    = data.get("party_pos", { "col": 0, "row": 0 })
	var ppos: Dictionary   = ppos_v if ppos_v is Dictionary else { "col": 0, "row": 0 }
	var pcol := int(ppos.get("col", 0))
	var prow := int(ppos.get("row", 0))
	_board.scale    = Vector2.ONE
	var party_local := _board.map_to_local(Vector2i(pcol, prow))
	# Use viewport rect — safe before layout pass (size may be zero on first call)
	var screen_size := get_viewport_rect().size
	_board.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.5) - party_local

	# Animate party token to new position (lerp — combat board style)
	# _board_to_screen() must be called AFTER board position is set above
	_party_layer.call("set_party_position", _board_to_screen(party_local))

	# Situation markers (full state — hidden / revealed / resolved)
	var sits_v: Variant  = data.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []
	_rebuild_situations(situations)

	# HUD
	_turn_label.text       = "Turn %d" % int(data.get("turn_count", 0))
	_objectives_label.text = "Objectives: %d / %d" % [
		int(data.get("objectives_found", 0)),
		int(data.get("objectives_total", 0)),
	]
	if data.get("return_failed", false):
		_party_state_label.text = "Couldn't escape..."
	else:
		_party_state_label.text = str(data.get("party_state", "exploring")).capitalize()

	# Button states
	var adv_v: Variant   = actions.get("cta.advance_turn", {})
	var adv: Dictionary  = adv_v if adv_v is Dictionary else {}
	_advance_btn.disabled = bool(adv.get("disabled", false))
	_cached_advance_action = { "type": "stage.advance_turn" }
	_cached_return_action  = { "type": "stage.return_home" }

	# UI mode: explore
	_hud_strip.show()
	_advance_btn.show()
	_return_btn.show()
	_begin_btn.hide()
	_stage_info.hide()
	_back_btn.hide()
	_directive_overlay.hide()

	# Overlay priority: return_home_result > pending engagement > non-combat result
	var rhr_v: Variant      = data.get("return_home_result", {})
	var rhr: Dictionary     = rhr_v if rhr_v is Dictionary else {}
	var pending_v: Variant  = data.get("situation_pending", {})
	var pending: Dictionary = pending_v if pending_v is Dictionary else {}
	var eng_v: Variant      = actions.get("cta.engage_situation", {})
	var eng: Dictionary     = eng_v if eng_v is Dictionary else {}

	if not rhr.is_empty():
		_show_return_home_overlay(rhr)
	elif not pending.is_empty() and not eng.is_empty():
		_show_pending_overlay(pending, eng)
	elif data.has("situation_overlay"):
		var ov_v: Variant   = data.get("situation_overlay", {})
		var ov: Dictionary  = ov_v if ov_v is Dictionary else {}
		_show_result_overlay(ov)
	else:
		_sit_overlay.hide()


# ─── Situation overlays ──────────────────────────────────────────────────────

func _show_pending_overlay(pending: Dictionary, engage_action: Dictionary) -> void:
	var revealed := bool(pending.get("revealed", false))
	_sit_header_label.text = "Situation Ahead"
	if revealed:
		_sit_type_label.text   = str(pending.get("type", "")).capitalize()
		_sit_result_label.text = "The party stands before the situation. Commit to engage?"
	else:
		_sit_type_label.text   = "Unknown"
		_sit_result_label.text = "The party senses something ahead. Enter to discover what awaits."
	# V2-INTEL-001: show prior-run intel clue and enemy estimate if available
	var intel_clues_v: Variant = pending.get("intel_clues", [])
	var intel_clues: Array = intel_clues_v if intel_clues_v is Array else []
	_intel_clue_label.text    = str(intel_clues[0]) if not intel_clues.is_empty() else ""
	_intel_clue_label.visible = not intel_clues.is_empty()
	var enemy_est := str(pending.get("enemy_estimate", ""))
	_enemy_estimate_label.text    = enemy_est
	_enemy_estimate_label.visible = not enemy_est.is_empty()
	_dismiss_btn.text      = "Enter"
	_cached_overlay_action = engage_action
	_sit_overlay.show()


func _show_result_overlay(result: Dictionary) -> void:
	_sit_header_label.text  = "Situation"
	_sit_type_label.text    = str(result.get("type", "")).capitalize()
	_sit_result_label.text  = str(result.get("result_text", ""))
	_intel_clue_label.visible     = false
	_enemy_estimate_label.visible = false
	_dismiss_btn.text       = "Continue"
	_cached_overlay_action  = { "type": "stage.dismiss_overlay" }
	_sit_overlay.show()


func _show_return_home_overlay(result: Dictionary) -> void:
	var success := bool(result.get("success", false))
	_sit_header_label.text = "Return Home"
	if success:
		_sit_type_label.text   = "Escaped"
		_dismiss_btn.text      = "Leave"
		_cached_overlay_action = { "type": "stage.confirm_return_home" }
	else:
		_sit_type_label.text   = "Blocked"
		_dismiss_btn.text      = "Continue"
		_cached_overlay_action = { "type": "stage.dismiss_overlay" }
	_sit_result_label.text        = str(result.get("message", ""))
	_intel_clue_label.visible     = false
	_enemy_estimate_label.visible = false
	_sit_overlay.show()


# ─── Board rendering ─────────────────────────────────────────────────────────

func _fill_board(cols: int, rows: int) -> void:
	if _board.get_used_cells().size() == cols * rows:
		return
	_board.clear()
	for c in range(cols):
		for r in range(rows):
			_board.set_cell(Vector2i(c, r), _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)


## Scale and center the board to fit the screen body area (preview mode).
## Body: below StageInfoPanel (~112px top), above ActionBar (80px bottom), 24px margins.
func _build_preview(cols: int, rows: int) -> void:
	var tl: Vector2 = _board.map_to_local(Vector2i(0,        0       ))
	var tr: Vector2 = _board.map_to_local(Vector2i(cols - 1, 0       ))
	var bl: Vector2 = _board.map_to_local(Vector2i(0,        rows - 1))
	var br: Vector2 = _board.map_to_local(Vector2i(cols - 1, rows - 1))

	var map_pixel_w: float = max(tr.x, br.x) - min(tl.x, bl.x)
	var map_pixel_h: float = max(bl.y, br.y) - min(tl.y, tr.y)

	var vp_size := get_viewport_rect().size
	var available_w: float = vp_size.x - 48.0
	var available_h: float = (vp_size.y - 80.0) - 112.0 - 48.0

	if map_pixel_w <= 0.0 or map_pixel_h <= 0.0 or available_w <= 0.0 or available_h <= 0.0:
		return

	_preview_scale = min(available_w / map_pixel_w, available_h / map_pixel_h)
	_board.scale   = Vector2(_preview_scale, _preview_scale)

	var map_center_local := (tl + tr + bl + br) / 4.0
	var body_center_y: float = 112.0 + (vp_size.y - 80.0 - 112.0) / 2.0
	_preview_center = Vector2(vp_size.x / 2.0, body_center_y)
	_board.position = _preview_center - map_center_local * _preview_scale


# ─── Situation markers ───────────────────────────────────────────────────────

## Preview mode — V2-INTEL-001: previously scouted situations show their type marker.
## Resolved situations show the resolved marker. Unknown situations show the hidden ? marker.
func _rebuild_situations_preview(map_situations: Array) -> void:
	for m in _situation_markers:
		if is_instance_valid(m):
			m.queue_free()
	_situation_markers.clear()

	for sit_v in map_situations:
		var sit: Dictionary   = sit_v if sit_v is Dictionary else {}
		var pos_v: Variant    = sit.get("pos", { "col": 0, "row": 0 })
		var pos_d: Dictionary = pos_v if pos_v is Dictionary else { "col": 0, "row": 0 }
		var revealed: bool    = bool(sit.get("revealed", false))
		var resolved: bool    = bool(sit.get("resolved", false))
		var template: Control
		if resolved:
			template = _resolved_template
		elif revealed:
			template = _revealed_template
		else:
			template = _hidden_template
		var marker: Control  = template.duplicate() as Control
		var board_local := _board.map_to_local(Vector2i(int(pos_d.get("col", 0)), int(pos_d.get("row", 0))))
		marker.position      = _board_to_screen(board_local)
		marker.visible       = true
		if revealed and not resolved:
			var type_lbl: Label = marker.get_node_or_null("RevealedCircle/TypeLabel")
			if type_lbl != null:
				type_lbl.text = str(sit.get("type", "")).capitalize()
		_situation_layer.add_child(marker)
		_situation_markers.append(marker)


## Explore mode — markers reflect actual revealed / resolved state.
func _rebuild_situations(situations: Array) -> void:
	for m in _situation_markers:
		if is_instance_valid(m):
			m.queue_free()
	_situation_markers.clear()

	for sit_v in situations:
		var sit: Dictionary   = sit_v if sit_v is Dictionary else {}
		var pos_v: Variant    = sit.get("pos", { "col": 0, "row": 0 })
		var pos_d: Dictionary = pos_v if pos_v is Dictionary else { "col": 0, "row": 0 }
		var revealed: bool    = bool(sit.get("revealed", false))
		var resolved: bool    = bool(sit.get("resolved", false))

		var template: Control
		if resolved:
			template = _resolved_template
		elif revealed:
			template = _revealed_template
		else:
			template = _hidden_template

		var marker: Control  = template.duplicate() as Control
		var board_local := _board.map_to_local(Vector2i(int(pos_d.get("col", 0)), int(pos_d.get("row", 0))))
		marker.position      = _board_to_screen(board_local)
		marker.visible       = true

		if revealed and not resolved:
			var type_lbl: Label = marker.get_node_or_null("RevealedCircle/TypeLabel")
			if type_lbl != null:
				type_lbl.text = str(sit.get("type", "")).capitalize()

		_situation_layer.add_child(marker)
		_situation_markers.append(marker)


# ─── Button handlers ─────────────────────────────────────────────────────────

func _on_advance_pressed() -> void:
	if not _cached_advance_action.is_empty():
		action_requested.emit(_cached_advance_action)


func _on_return_pressed() -> void:
	if not _cached_return_action.is_empty():
		action_requested.emit(_cached_return_action)


func _on_begin_pressed() -> void:
	if _cached_start_action.is_empty() or _is_zooming:
		return
	_is_zooming        = true
	_begin_btn.disabled = true

	# Zoom-in tween for preview mode — scales the board up while
	# fading the stage info panel out. No scene swap: the board stays in this
	# screen instance for the explore mode that follows.
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)

	var target_scale := Vector2(_preview_scale * _ZOOM_SCALE_MUL, _preview_scale * _ZOOM_SCALE_MUL)
	var current_pos  := _board.position
	var map_offset   := _preview_center - current_pos
	var target_pos   := _preview_center - map_offset * _ZOOM_SCALE_MUL

	tween.parallel().tween_property(_board,      "scale",    target_scale,          _ZOOM_DURATION)
	tween.parallel().tween_property(_board,      "position", target_pos,            _ZOOM_DURATION)
	tween.parallel().tween_property(_stage_info, "modulate", Color(1, 1, 1, 0),     _ZOOM_DURATION)
	tween.parallel().tween_property(_back_btn,   "modulate", Color(1, 1, 1, 0),     _ZOOM_DURATION)

	tween.finished.connect(_on_zoom_finished)


func _on_zoom_finished() -> void:
	action_requested.emit(_cached_start_action)


func _on_back_pressed() -> void:
	if not _cached_back_action.is_empty():
		action_requested.emit(_cached_back_action)


func _on_dismiss_pressed() -> void:
	_sit_overlay.hide()
	if not _cached_overlay_action.is_empty():
		action_requested.emit(_cached_overlay_action)
		_cached_overlay_action = {}


func _on_overlay_action(action: Dictionary) -> void:
	action_requested.emit(action)


# ─── Helpers ─────────────────────────────────────────────────────────────────

## Convert a board-local position to screen position, accounting for
## the board's current position and scale. Used to place root-level
## markers and token that live outside the Board node hierarchy.
func _board_to_screen(board_local: Vector2) -> Vector2:
	return _board.position + board_local * _board.scale.x


func _label_for_directive(dir_id: String) -> String:
	match dir_id:
		"directive.scout_carefully": return "Scout Carefully"
		"directive.seek_signs":      return "Seek Signs"
		_: return dir_id.capitalize() if not dir_id.is_empty() else "None"
