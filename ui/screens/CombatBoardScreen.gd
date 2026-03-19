# res://ui/screens/CombatBoardScreen.gd
# Bespoke combat board screen — renders the isometric grid for flow.encounter.
# GRID-001: Board configuration + isometric floor tile rendering.
# GRID-002: Actor tokens drawn at grid_pos cells via CombatTokenLayer.
# GRID-004: Distance debug overlay via CombatDistanceLayer (dev-facing only).
# COMBAT-SEQ: True sequential per-actor display. Each snapshot = one actor's turn.
#   Initiative arrow + action text driven by snapshot data.
#   Speed buttons (Slow/Normal/Fast) + Manual toggle for pace control.
#   Auto-dispatch cta.next_actor or cta.confirm_round after _step_delay seconds.
#
# Contract (UI-001):
# - set_snapshot(snap: Dictionary) → _clear() + _render(data, actions)
# - action_requested signal for all player interactions
# - Never reads sim internals directly

class_name CombatBoardScreen
extends Control

signal action_requested(action: Dictionary)

@onready var _board: TileMapLayer                   = $Board
@onready var _token_layer: CombatTokenLayer         = $TokenLayer
@onready var _distance_layer: CombatDistanceLayer   = $DistanceLayer
@onready var _back_button: Button                   = $BackButton
@onready var _round_label: Label                    = $RoundLabel
@onready var _objective_label: Label                = $ObjectiveLabel
# Repurposed: was StartCombatButton / Confirm Round — now also shows "Next" during actor_turn phase.
@onready var _cta_button: Button                    = $StartCombatButton
# Repurposed: was AutoToggleButton — now Manual mode toggle.
@onready var _manual_toggle: CheckButton            = $AutoToggleButton
# Repurposed: was AutoTimer — now the step-delay timer for auto-dispatch.
@onready var _step_timer: Timer                     = $AutoTimer
# COMBAT-002: Initiative panel overlay.
@onready var _initiative_panel: PanelContainer      = $InitiativePanel
@onready var _initiative_list: VBoxContainer        = $InitiativePanel/InitiativeList
# COMBAT-005: Combat result overlay — shown when round_phase == "combat_end".
@onready var _result_overlay: PanelContainer        = $CombatResultOverlay
@onready var _outcome_label: Label                  = $CombatResultOverlay/ResultContent/OutcomeLabel
@onready var _reason_label: Label                   = $CombatResultOverlay/ResultContent/ReasonLabel
@onready var _round_ended_label: Label              = $CombatResultOverlay/ResultContent/RoundEndedLabel
@onready var _end_combat_button: Button             = $CombatResultOverlay/ResultContent/EndCombatButton

# Clay floor tile: source 0, atlas position (0, 0)
const _TILE_SOURCE_ID:    int       = 0
const _TILE_ATLAS_COORDS: Vector2i  = Vector2i(0, 0)

const _SPEED_SLOW:   float = 3.0
const _SPEED_NORMAL: float = 1.5
const _SPEED_FAST:   float = 0.5

var _current_cols: int       = 10
var _current_rows: int       = 10
# Cached nav.back action — set in _render(), read in _on_back_pressed().
var _nav_back_action: Dictionary = {}
# The action to auto-dispatch when _step_timer fires (cta.next_actor or cta.confirm_round).
var _pending_dispatch_action: Dictionary = {}
# COMBAT-005: cached action for the "Return to Sanctum" button in the result overlay.
var _end_combat_action: Dictionary = {}
# Step delay in seconds — controlled by speed buttons.
var _step_delay: float = _SPEED_NORMAL
# Manual mode: when true, player clicks the CTA button instead of auto-dispatch.
var _manual_mode: bool = false


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	_back_button.visible = false
	_back_button.pressed.connect(_on_back_pressed)

	_cta_button.visible = false
	_cta_button.pressed.connect(_on_cta_pressed)

	# Manual toggle (was Auto toggle — repurposed).
	_manual_toggle.text = "Manual"
	_manual_toggle.visible = false
	_manual_toggle.toggled.connect(_on_manual_toggle_pressed)

	# Step timer (was AutoTimer — repurposed). wait_time overridden per step.
	_step_timer.one_shot  = true
	_step_timer.autostart = false
	_step_timer.timeout.connect(_on_step_timer_timeout)

	_initiative_panel.visible = false
	_result_overlay.visible   = false
	_end_combat_button.pressed.connect(_on_end_combat_pressed)

	# Speed buttons — built programmatically, no scene changes needed.
	var speed_bar := HBoxContainer.new()
	speed_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	speed_bar.position = Vector2(295, 3)
	add_child(speed_bar)

	for speed_def in [["Slow", _SPEED_SLOW], ["Normal", _SPEED_NORMAL], ["Fast", _SPEED_FAST]]:
		var btn := Button.new()
		btn.text = speed_def[0]
		btn.custom_minimum_size = Vector2(48, 26)
		var delay: float = speed_def[1]
		btn.pressed.connect(func(): _on_speed_pressed(delay))
		speed_bar.add_child(btn)


# -------------------------
# Bespoke screen contract (UI-001)
# -------------------------

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "CombatBoardScreen: snapshot missing 'type'")
	assert(snap.has("data"), "CombatBoardScreen: snapshot missing 'data'")
	_clear()
	_render(snap["data"], snap.get("actions", {}))

func _clear() -> void:
	_step_timer.stop()
	_pending_dispatch_action = {}

	_board.clear()
	_token_layer.clear_tokens()
	_distance_layer.clear_distances()
	_back_button.visible     = false
	_round_label.visible     = false
	_objective_label.visible = false
	_cta_button.visible      = false
	_manual_toggle.visible   = false
	_nav_back_action         = {}

	_initiative_panel.visible = false
	for child in _initiative_list.get_children():
		child.queue_free()

	_result_overlay.visible = false
	_end_combat_action      = {}

func _render(data: Dictionary, actions: Dictionary) -> void:
	_current_cols = int(data.get("board_cols", 10))
	_current_rows = int(data.get("board_rows", 10))
	_draw_board(_current_cols, _current_rows)
	_center_board(_current_cols, _current_rows)

	var actors: Array = data.get("actors", [])
	var current_actor_id: String = str(data.get("current_actor_id", ""))
	if not actors.is_empty():
		_draw_tokens(actors, current_actor_id, data)
		_distance_layer.update_distances(actors[0], _board, data)

	_round_label.text    = "Round: %d" % int(data.get("round", 0))
	_round_label.visible = true
	var obj_type: String = str(data.get("objective_type", ""))
	_objective_label.text    = obj_type
	_objective_label.visible = not obj_type.is_empty()

	# COMBAT-SEQ: CTA and auto-dispatch depend on round_phase.
	var round_phase: String  = str(data.get("round_phase", "pre_combat"))
	var combat_over: bool    = bool(data.get("combat_over", false))

	if actions.has("cta.combat_init"):
		_show_cta("Start Combat", actions["cta.combat_init"])
	elif actions.has("cta.next_actor"):
		if _manual_mode:
			_show_cta("Next", actions["cta.next_actor"])
		else:
			_schedule_auto_dispatch(actions["cta.next_actor"])
	elif actions.has("cta.confirm_round"):
		if _manual_mode or round_phase == "pre_combat":
			_show_cta("Confirm Round", actions["cta.confirm_round"])
		elif not combat_over:
			_schedule_auto_dispatch(actions["cta.confirm_round"])

	# Manual toggle is visible whenever combat is active (not pre_combat, not combat_end).
	if round_phase != "pre_combat" and not combat_over:
		_manual_toggle.visible = true

	if actions.has("nav.back"):
		var action_v: Variant = actions["nav.back"]
		if action_v is Dictionary:
			_nav_back_action = action_v
			_back_button.visible = true

	# COMBAT-005: result overlay — shown only at combat_end.
	if round_phase == "combat_end":
		var victory: bool    = bool(data.get("victory", false))
		var reason: String   = str(data.get("reason", ""))
		var round_ended: int = int(data.get("round_ended", 0))
		_outcome_label.text    = "VICTORY" if victory else "DEFEAT"
		_reason_label.text     = _format_result_reason(reason)
		_round_ended_label.text = "Completed in Round %d" % round_ended
		if actions.has("cta.end_combat"):
			_end_combat_action = actions["cta.end_combat"]
		_result_overlay.visible = true

	# COMBAT-002: draw initiative panel — snapshot-driven, no local playback state.
	_draw_initiative_panel(data)


# -------------------------
# Board rendering
# -------------------------

func _draw_board(cols: int, rows: int) -> void:
	for col in range(cols):
		for row in range(rows):
			_board.set_cell(Vector2i(col, row), _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)


func _center_board(cols: int, rows: int) -> void:
	var tl: Vector2 = _board.map_to_local(Vector2i(0,        0       ))
	var tr: Vector2 = _board.map_to_local(Vector2i(cols - 1, 0       ))
	var bl: Vector2 = _board.map_to_local(Vector2i(0,        rows - 1))
	var br: Vector2 = _board.map_to_local(Vector2i(cols - 1, rows - 1))

	var grid_center := Vector2(
		(min(tl.x, bl.x) + max(tr.x, br.x)) / 2.0,
		(min(tl.y, tr.y) + max(bl.y, br.y)) / 2.0
	)

	var viewport_center: Vector2 = get_viewport_rect().size / 2.0
	_board.position    = viewport_center - grid_center
	_token_layer.position    = _board.position
	_distance_layer.position = _board.position


func _on_back_pressed() -> void:
	if not _nav_back_action.is_empty():
		action_requested.emit(_nav_back_action)


# COMBAT-005: "Return to Sanctum" button in the result overlay.
func _on_end_combat_pressed() -> void:
	if not _end_combat_action.is_empty():
		action_requested.emit(_end_combat_action)


## COMBAT-005/006: Maps internal reason strings to player-facing labels.
func _format_result_reason(reason: String) -> String:
	match reason:
		"all_enemies_defeated": return "All enemies defeated"
		"all_echoes_dead":      return "All echoes fell"
		"shrine_destroyed":     return "Shrine Destroyed"  # COMBAT-006
	return reason


func _on_cta_pressed() -> void:
	if not _pending_dispatch_action.is_empty():
		var act: Dictionary = _pending_dispatch_action
		_pending_dispatch_action = {}
		_cta_button.visible = false
		action_requested.emit(act)


## Displays the CTA button with the given label and caches the action.
func _show_cta(label: String, act: Dictionary) -> void:
	_pending_dispatch_action = act
	_cta_button.text     = label
	_cta_button.disabled = false
	_cta_button.visible  = true


## Schedules auto-dispatch of act after _step_delay seconds.
## If already timing, stop first so the new snapshot resets the timer cleanly.
func _schedule_auto_dispatch(act: Dictionary) -> void:
	_step_timer.stop()
	_pending_dispatch_action    = act
	_step_timer.wait_time = _step_delay
	_step_timer.start()


func _on_step_timer_timeout() -> void:
	if not _pending_dispatch_action.is_empty():
		var act: Dictionary = _pending_dispatch_action
		_pending_dispatch_action = {}
		action_requested.emit(act)


func _on_speed_pressed(delay: float) -> void:
	_step_delay = delay
	# If a timer is already running (mid-auto), restart with new delay.
	if _step_timer.time_left > 0.0 and not _pending_dispatch_action.is_empty():
		_step_timer.wait_time = _step_delay
		_step_timer.start()


func _on_manual_toggle_pressed(enabled: bool) -> void:
	_manual_mode = enabled
	if enabled:
		# Switch to manual: cancel pending auto-dispatch, show button instead.
		_step_timer.stop()
		if not _pending_dispatch_action.is_empty():
			# Determine correct label for the pending action.
			var act_type: String = str(_pending_dispatch_action.get("type", ""))
			var lbl: String = "Next" if act_type == "combat.next_actor" else "Confirm Round"
			_show_cta(lbl, _pending_dispatch_action)
	else:
		# Switch to auto: hide button, schedule if there is a pending action.
		if not _pending_dispatch_action.is_empty():
			_cta_button.visible = false
			_schedule_auto_dispatch(_pending_dispatch_action)


func _on_action(action: Dictionary) -> void:
	action_requested.emit(action)


# -------------------------
# Token rendering (GRID-002 + COMBAT-SEQ)
# -------------------------

## Converts the actor list into token descriptors and passes them to CombatTokenLayer.
## current_actor_id: id of the actor currently acting — gets a yellow ring.
## COMBAT-003: reads action_results from data to build a damage lookup by target_id.
func _draw_tokens(actors: Array, current_actor_id: String, data: Dictionary = {}) -> void:
	var damage_by_id: Dictionary = {}
	for result_v in data.get("action_results", []):
		if result_v is Dictionary and result_v.get("action_type", "") == "melee_attack":
			var tid: String = str(result_v.get("target_id", ""))
			var dmg: int    = int(result_v.get("damage", 0))
			if not tid.is_empty() and dmg > 0:
				damage_by_id[tid] = "-%d" % dmg

	var tokens: Array[Dictionary] = []
	for actor in actors:
		var gp: Dictionary = actor.get("grid_pos", {})
		var col: int = gp.get("col", 0)
		var row: int = gp.get("row", 0)
		var cell_pos: Vector2 = _board.map_to_local(Vector2i(col, row))
		var faction: String   = actor.get("faction", "")
		var shape := "square" if actor.get("is_structure", false) else "circle"
		var name_str: String  = actor.get("name", "??")
		var actor_id: String  = str(actor.get("id", ""))

		var max_hp: float   = float(actor.get("stats", {}).get("max_hp", 1))
		var cur_hp: float   = float(actor.get("current_hp", max_hp))
		var hp_ratio: float = clampf(cur_hp / max(max_hp, 1.0), 0.0, 1.0)
		var hp_color: Color
		if hp_ratio > 0.5:
			hp_color = Color.GREEN
		elif hp_ratio > 0.25:
			hp_color = Color.YELLOW
		else:
			hp_color = Color.RED

		tokens.append({
			"pos":         cell_pos,
			"color":       _faction_color(faction),
			"shape":       shape,
			"label":       name_str.substr(0, 2).to_upper(),
			"hp_ratio":    hp_ratio,
			"hp_color":    hp_color,
			"damage_text": damage_by_id.get(actor_id, ""),
			"actor_id":    actor_id,   # COMBAT-SEQ: needed for yellow ring
			"fear":        int(actor.get("fear", 0)),
			"morale":      int(actor.get("morale", 50)),
			"is_structure": actor.get("is_structure", false),
		})
	_token_layer.update_tokens(tokens, current_actor_id)


## Toggle the emotion debug overlay on the token layer.
## Called from AppRoot when the "combat_emotion" debug command fires.
func set_emotion_debug(enabled: bool) -> void:
	_token_layer.set_emotion_debug(enabled)


func _faction_color(faction: String) -> Color:
	return CombatTokenLayer.FACTION_COLORS.get(faction, Color.WHITE)


# -------------------------
# Initiative panel (COMBAT-002 + COMBAT-SEQ)
# -------------------------

## Draws the left-side initiative order overlay.
## Fully driven by snapshot data — no local playback state.
##
## Arrow (→ + yellow):  actor at data.active_initiative_index
## Action text:         built from data.action_results lookup by source_id
## Dead actor:          X + red font + 40% opacity
## Panel hidden when initiative_order is empty (pre-combat).
func _draw_initiative_panel(data: Dictionary) -> void:
	var order: Array = data.get("initiative_order", [])
	if order.is_empty():
		_initiative_panel.visible = false
		return

	var active_idx: int = int(data.get("active_initiative_index", 0))

	# Build dead-id set from actors array.
	var dead_ids: Dictionary = {}
	for actor in data.get("actors", []):
		if actor.get("is_dead", false):
			dead_ids[str(actor.get("id", ""))] = true

	# Build action-text lookup from action_results resolved so far this round.
	var action_by_id: Dictionary = {}
	for result_v in data.get("action_results", []):
		if result_v is Dictionary:
			var sid: String = str(result_v.get("source_id", ""))
			if not sid.is_empty():
				action_by_id[sid] = _format_action(result_v)

	for child in _initiative_list.get_children():
		child.queue_free()

	for i in range(order.size()):
		var entry: Dictionary  = order[i]
		var actor_id: String   = str(entry.get("id", "??"))
		var actor_name: String = str(entry.get("name", "??"))
		var is_dead: bool      = dead_ids.has(actor_id)
		var action_text: String = action_by_id.get(actor_id, "")

		var hbox := HBoxContainer.new()

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.custom_minimum_size.x = 155
		name_label.clip_text = true

		var action_label := Label.new()
		action_label.add_theme_font_size_override("font_size", 12)
		action_label.custom_minimum_size.x = 70
		action_label.clip_text = true
		action_label.text = action_text

		if is_dead:
			name_label.text = "X  %s" % actor_name
			name_label.add_theme_color_override("font_color", Color.RED)
			action_label.add_theme_color_override("font_color", Color.RED)
			hbox.self_modulate = Color(1, 1, 1, 0.4)
		elif i == active_idx:
			name_label.text = "→  %s" % actor_name
			name_label.add_theme_color_override("font_color", Color.YELLOW)
			action_label.add_theme_color_override("font_color", _action_color_for_text(action_text))
		else:
			name_label.text = "   %s" % actor_name
			name_label.add_theme_color_override("font_color", Color.WHITE)
			action_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))

		hbox.add_child(name_label)
		hbox.add_child(action_label)
		_initiative_list.add_child(hbox)

	_initiative_panel.visible = true


## Formats an action_result entry into a short display string for the initiative panel.
func _format_action(result: Dictionary) -> String:
	var atype: String = str(result.get("action_type", ""))
	var tname: String = str(result.get("target_name", ""))
	match atype:
		"melee_attack":
			var target: String = tname if not tname.is_empty() else "?"
			if result.get("is_kill", false):
				return "Kills %s" % target
			return "Attacks %s (%d)" % [target, int(result.get("damage", 0))]
		"actor.guard":
			return "Guards"
		"actor.move":
			if not tname.is_empty():
				return "Move → %s" % tname
			return "Moves"
		"actor.idle":
			return "Idle"
		"actor.refuse":
			return "Refuses"
		"actor.dead":
			return ""
	return atype


## Returns an appropriate colour for an action text string (used on the active row).
func _action_color_for_text(action_text: String) -> Color:
	if action_text.begins_with("Kills"):
		return Color.RED
	if action_text.begins_with("Attacks"):
		return Color.ORANGE
	if action_text == "Guards":
		return Color.CYAN
	if action_text.begins_with("Move →") or action_text == "Moves":
		return Color(0.6, 0.9, 0.6)
	if action_text == "Refuses":
		return Color.RED
	return Color(0.65, 0.65, 0.65)
