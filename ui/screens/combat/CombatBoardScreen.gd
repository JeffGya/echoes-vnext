# res://ui/screens/combat/CombatBoardScreen.gd
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

const InitiativeRowScene := preload("res://ui/components/InitiativeRowItem.tscn")
const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")

@onready var _board: TileMapLayer                   = $Board
@onready var _move_telegraph_layer: Node2D          = $MoveTelegraphLayer
@onready var _token_layer: CombatTokenLayer         = $TokenLayer
# V2-VOICE-001: bark popup layer — optional; null-checked before use.
@onready var _bark_popup_layer: BarkPopupLayer      = $BarkPopupLayer if has_node("BarkPopupLayer") else null
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
# UI-004: Pre-battle panel (pre_combat phase only).
@onready var _prebattle_panel: PanelContainer       = $PrebattlePanel
@onready var _prebattle_objective: Label            = $PrebattlePanel/PrebattleContent/ObjectivePanelLabel
@onready var _retreat_button: Button                = $PrebattlePanel/PrebattleContent/ButtonRow/RetreatButton
@onready var _enter_combat_button: Button           = $PrebattlePanel/PrebattleContent/ButtonRow/EnterCombatButton
@onready var _speed_slow_button: Button             = %SpeedSlowButton
@onready var _speed_normal_button: Button           = %SpeedNormalButton
@onready var _speed_fast_button: Button             = %SpeedFastButton

# Clay floor tile: source 0, atlas position (0, 0)
const _TILE_SOURCE_ID:    int       = 0
const _TILE_ATLAS_COORDS: Vector2i  = Vector2i(0, 0)

const _SPEED_SLOW:   float = 3.0
const _SPEED_NORMAL: float = 1.5
const _SPEED_FAST:   float = 0.5
const _MOVE_DURATION_SLOW: float = 0.72
const _MOVE_DURATION_NORMAL: float = 0.36
const _MOVE_DURATION_FAST: float = 0.20
const _TELEGRAPH_DURATION_SLOW: float = 0.28
const _TELEGRAPH_DURATION_NORMAL: float = 0.16
const _TELEGRAPH_DURATION_FAST: float = 0.09

var _current_cols: int       = 10
var _current_rows: int       = 10
# Cached nav.back action — set in _render(), read in _on_back_pressed().
var _nav_back_action: Dictionary = {}
# The action to auto-dispatch when _step_timer fires (cta.next_actor or cta.confirm_round).
var _pending_dispatch_action: Dictionary = {}
# COMBAT-005: cached action for the "Return to Sanctum" button in the result overlay.
var _end_combat_action: Dictionary = {}
# UI-004: cached actions for the pre-battle panel buttons.
var _pending_enter_combat_action: Dictionary = {}
var _pending_retreat_action: Dictionary      = {}
# Step delay in seconds — controlled by speed buttons.
var _step_delay: float = _SPEED_NORMAL
# Manual mode: when true, player clicks the CTA button instead of auto-dispatch.
var _manual_mode: bool = false
var _active_encounter_id: String = ""
# V2-VOICE-002: last bark line shown — prevents back-to-back identical lines across echoes.
var _last_bark_line: String = ""
var _presentation_board_size: Vector2i = Vector2i.ZERO

# V2-STAGE-004 P3b: PURSUE camera follow (manual board repositioning — avoids Camera2D UI-pan issue).
var _pursue_mode: bool            = false
var _quarry_local_pos: Vector2    = Vector2.ZERO
var _pan_offset: Vector2          = Vector2.ZERO
var _pan_active: bool             = false
var _pan_resume_timer: float      = 0.0
const _PAN_RESUME_DELAY: float    = 3.0
const _PURSUE_FOLLOW_SPEED: float = 5.0

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

	# UI-004: Pre-battle panel wiring.
	_prebattle_panel.visible = false
	_enter_combat_button.pressed.connect(_on_enter_combat_pressed)
	_retreat_button.pressed.connect(_on_retreat_pressed)

	# Speed buttons are authored in scene.
	_speed_slow_button.pressed.connect(func(): _on_speed_pressed(_SPEED_SLOW))
	_speed_normal_button.pressed.connect(func(): _on_speed_pressed(_SPEED_NORMAL))
	_speed_fast_button.pressed.connect(func(): _on_speed_pressed(_SPEED_FAST))
	_apply_visual_playback_for_delay(_SPEED_NORMAL)


# -------------------------
# Bespoke screen contract (UI-001)
# -------------------------

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "CombatBoardScreen: snapshot missing 'type'")
	assert(snap.has("data"), "CombatBoardScreen: snapshot missing 'data'")
	var data: Dictionary = snap["data"]
	if _should_reset_presentation(data):
		_reset_presentation_state()
	_reset_transient_ui()
	_render(data, snap.get("actions", {}))
	_active_encounter_id = str(data.get("encounter_id", ""))
	_presentation_board_size = Vector2i(
		int(data.get("board_cols", 10)),
		int(data.get("board_rows", 10))
	)

func _reset_transient_ui() -> void:
	_step_timer.stop()
	_pending_dispatch_action = {}

	_board.clear()
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

	# UI-004: hide pre-battle panel; reset cached actions.
	_prebattle_panel.visible         = false
	_pending_enter_combat_action     = {}
	_pending_retreat_action          = {}


func _reset_presentation_state() -> void:
	_token_layer.reset_presentation()
	_move_telegraph_layer.clear_telegraph()
	if _bark_popup_layer != null:
		_bark_popup_layer.clear_all()
	_last_bark_line = ""


func _should_reset_presentation(data: Dictionary) -> bool:
	var next_encounter_id: String = str(data.get("encounter_id", ""))
	var next_board_size := Vector2i(
		int(data.get("board_cols", 10)),
		int(data.get("board_rows", 10))
	)
	if _active_encounter_id.is_empty():
		return true
	if next_encounter_id != _active_encounter_id:
		return true
	return next_board_size != _presentation_board_size

func _render(data: Dictionary, actions: Dictionary) -> void:
	_current_cols = int(data.get("board_cols", 10))
	_current_rows = int(data.get("board_rows", 10))
	var terrain_v: Variant = data.get("terrain", {})
	var terrain: Dictionary = terrain_v if terrain_v is Dictionary else {}
	_draw_board(_current_cols, _current_rows, terrain)
	_center_board(_current_cols, _current_rows)

	var actors: Array = data.get("actors", [])
	var current_actor_id: String = str(data.get("current_actor_id", ""))
	if not actors.is_empty():
		_draw_tokens(actors, current_actor_id, data)
		_distance_layer.update_distances(actors[0], _board, data)
		# V2-VOICE-002: show new barks + reposition all active bubbles to follow tokens.
		_show_bark_popups(actors, data)
		_update_bark_positions(actors)
	else:
		_token_layer.reset_presentation()
		_move_telegraph_layer.clear_telegraph()

	_round_label.text    = "Round: %d" % int(data.get("round", 0))
	_round_label.visible = true
	# COMBAT-007: read objective_state dict (replaces flat objective_type field).
	var obj_state: Dictionary = data.get("objective_state", {})
	var obj_type: String = str(obj_state.get("type", ""))
	# V2-STAGE-004 distinctiveness: enrich banner text for ENDURE, PROTECT, and PURSUE modes.
	var banner_text: String = obj_type
	if obj_type == "endure":
		var waves_remaining: int = int(obj_state.get("waves_remaining", 0))
		var wave_total: int      = int(obj_state.get("wave_total", 0))
		if wave_total > 0:
			banner_text = "Endure — Waves: %d/%d remaining" % [waves_remaining, wave_total]
	elif obj_type == "protect":
		if bool(obj_state.get("totem_stolen", false)):
			banner_text = "Totem STOLEN — recover it!"
	elif obj_type == "pursue":
		var contain_progress: int  = int(obj_state.get("contain_progress", 0))
		var contain_required: int  = int(obj_state.get("contain_required", 3))
		var window_remaining: int  = int(obj_state.get("window_remaining", 0))
		banner_text = "Pursue — Contain: %d/%d | Window: %d turns" % [contain_progress, contain_required, window_remaining]
	_objective_label.text    = banner_text
	_objective_label.visible = not banner_text.is_empty()

	# V2-STAGE-004 P3b: PURSUE camera — update quarry follow target each snapshot.
	if obj_type == "pursue":
		if not _pursue_mode:
			_pursue_mode = true
			_pan_offset  = Vector2.ZERO
			_board.scale = Vector2.ONE
		for actor_v in actors:
			if actor_v is Dictionary and bool(actor_v.get("is_quarry", false)):
				var gp_q: Dictionary = actor_v.get("grid_pos", {})
				_quarry_local_pos = _board.map_to_local(
					Vector2i(int(gp_q.get("col", 0)), int(gp_q.get("row", 0))))
				_apply_board_transform(get_viewport_rect().size / 2.0 - _quarry_local_pos + _pan_offset)
				break
	elif _pursue_mode:
		_pursue_mode = false
		_pan_offset   = Vector2.ZERO
		_board.scale  = Vector2.ONE
		_token_layer.scale          = Vector2.ONE
		_move_telegraph_layer.scale = Vector2.ONE
		_distance_layer.scale       = Vector2.ONE
		if _bark_popup_layer != null:
			_bark_popup_layer.scale = Vector2.ONE

	# COMBAT-SEQ: CTA and auto-dispatch depend on round_phase.
	var round_phase: String  = str(data.get("round_phase", "pre_combat"))
	var combat_over: bool    = bool(data.get("combat_over", false))

	# UI-004: pre_combat → show pre-battle panel instead of plain CTA button.
	if round_phase == "pre_combat":
		_show_prebattle_panel(data, actions)
		return

	if actions.has("cta.combat_init"):
		_show_cta("Start Combat", actions["cta.combat_init"])
	elif actions.has("cta.next_actor"):
		if _manual_mode:
			_show_cta("Next", actions["cta.next_actor"])
		else:
			_schedule_auto_dispatch(actions["cta.next_actor"])
	elif actions.has("cta.confirm_round"):
		var confirm_action: Dictionary = actions["cta.confirm_round"]
		var confirm_label := str(confirm_action.get("label", "Confirm Round"))
		if _manual_mode or round_phase == "pre_combat" or combat_over:
			_show_cta(confirm_label, confirm_action)
		elif not combat_over:
			_schedule_auto_dispatch(confirm_action)

	# Manual toggle is visible whenever combat is active (not pre_combat, not combat_end).
	if round_phase != "pre_combat" and not combat_over:
		_manual_toggle.visible = true

	if actions.has("nav.back"):
		var action_v: Variant = actions["nav.back"]
		if action_v is Dictionary:
			_nav_back_action = action_v
			_back_button.visible = true

	# COMBAT-007: combat_end phase no longer reaches CombatBoardScreen —
	# _end_round() now emits type "flow.resolve" which AppRoot routes to ResolveScreen.
	# The CombatResultOverlay is kept in scene for compatibility but never shown here.

	# COMBAT-002: draw initiative panel — snapshot-driven, no local playback state.
	_draw_initiative_panel(data)


# -------------------------
# Board rendering
# -------------------------

func _draw_board(cols: int, rows: int, terrain: Dictionary = {}) -> void:
	# Compute walkable set from terrain data.
	# StageTerrain.walkable_set returns {} when terrain is absent/empty — that is
	# the legacy sentinel meaning "all cells walkable".
	var walkable: Dictionary = StageTerrain.walkable_set(terrain)

	_board.clear()

	if walkable.is_empty():
		# Legacy / no-terrain path: paint every cell in the bounding rectangle.
		# Byte-identical behaviour to the original — existing encounters are unaffected.
		for col in range(cols):
			for row in range(rows):
				_board.set_cell(Vector2i(col, row), _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)
	else:
		# Terrain-aware path: paint ONLY walkable cells; void cells get no tile.
		# Combat has no fog layer — the full walkable shape is always revealed.
		for key_v in walkable:
			var key: String = str(key_v)
			var parts := key.split(",")
			if parts.size() != 2:
				continue
			var c: int = int(parts[0])
			var r: int = int(parts[1])
			_board.set_cell(Vector2i(c, r), _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)


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
	_move_telegraph_layer.position = _board.position
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
	_apply_visual_playback_for_delay(delay)
	# If a timer is already running (mid-auto), restart with new delay.
	if _step_timer.time_left > 0.0 and not _pending_dispatch_action.is_empty():
		_step_timer.wait_time = _step_delay
		_step_timer.start()


func _apply_visual_playback_for_delay(delay: float) -> void:
	var move_duration: float = _MOVE_DURATION_NORMAL
	var telegraph_duration: float = _TELEGRAPH_DURATION_NORMAL

	if is_equal_approx(delay, _SPEED_SLOW):
		move_duration = _MOVE_DURATION_SLOW
		telegraph_duration = _TELEGRAPH_DURATION_SLOW
	elif is_equal_approx(delay, _SPEED_FAST):
		move_duration = _MOVE_DURATION_FAST
		telegraph_duration = _TELEGRAPH_DURATION_FAST

	if _token_layer != null and _token_layer.visual_config != null:
		_token_layer.visual_config.move_duration = move_duration
		_token_layer.visual_config.telegraph_lead_time = telegraph_duration
	if _move_telegraph_layer != null and _move_telegraph_layer.get("visual_config") != null:
		var telegraph_cfg: Variant = _move_telegraph_layer.get("visual_config")
		if telegraph_cfg != null:
			telegraph_cfg.move_duration = move_duration
			telegraph_cfg.telegraph_lead_time = telegraph_duration


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

# Converts the actor list into token descriptors and passes them to CombatTokenLayer.
# current_actor_id: id of the actor currently acting — gets a yellow ring.
# COMBAT-003: reads action_results from data to build a damage lookup by target_id.
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

		var cell_center: Vector2 = _board.map_to_local(Vector2i(col, row))
		var actor_id: String     = str(actor.get("id", ""))

		var max_hp: float   = float(actor.get("max_hp", 1))
		var cur_hp: float   = float(actor.get("hp", max_hp))
		var hp_ratio: float = clampf(cur_hp / max(max_hp, 1.0), 0.0, 1.0)

		tokens.append({
			"actor_id":           actor_id,
			"grid_pos":           gp.duplicate(),
			"cell_pos":           cell_center,
			"faction":            str(actor.get("faction", "")),
			"is_structure":       bool(actor.get("is_structure", false)),
			"is_objective_relic": bool(actor.get("is_objective_relic", false)),
			"is_quarry":          bool(actor.get("is_quarry", false)),
			"label":              str(actor.get("name", "??")).substr(0, 2).to_upper(),
			"hp_ratio":           hp_ratio,
			"damage_text":        damage_by_id.get(actor_id, ""),
			"emotional_status":   str(actor.get("emotional_status", "")),
		})

	var telegraph_event: Dictionary = _token_layer.apply_snapshot(
		tokens,
		current_actor_id,
		data.get("last_actor_action", {})
	)
	if telegraph_event.is_empty():
		_move_telegraph_layer.clear_telegraph()
	else:
		_move_telegraph_layer.show_move_telegraph(telegraph_event)

## The legacy raw emotion overlay is unavailable from player-facing snapshots.
## Called from AppRoot when the "combat_emotion" debug command fires.
func set_emotion_debug(enabled: bool) -> void:
	_token_layer.set_emotion_debug(enabled)


# V2-VOICE-002: Assembles new bark events for this snapshot and passes them to
# _bark_popup_layer.show_barks(). Called every render; only actors with a non-empty
# bark_line produce an event (bark is consumed on first projection in FlowEncounterState).
#
# Priority sort:
#   Tier 1: combat_last_stand, combat_fear_extreme, combat_ko, combat_resilient — always shown
#   Tier 2: combat_fear_rising, combat_morale_falling, combat_inspired, combat_taunt, combat_calling_skill
#   Tier 3: combat_attack, combat_guard, combat_banter, combat_rally_ally (situational)
# Cap: max 3 originals. Reactions do NOT count against cap.
# Originals shown immediately; reactions shown after REACTION_DELAY (in BarkPopupLayer).
func _show_bark_popups(actors: Array, _data: Dictionary) -> void:
	if _bark_popup_layer == null:
		return

	var max_originals: int = 3
	var tier_map: Dictionary = {
		"combat_last_stand":    1, "combat_fear_extreme": 1,
		"combat_ko":            1, "combat_resilient":    1,
		"combat_fear_rising":   2, "combat_morale_falling": 2,
		"combat_inspired":      2, "combat_taunt":          2,
		"combat_calling_skill": 2,
		"combat_attack":        3, "combat_guard":          3,
		"combat_banter":        3,
	}

	var originals: Array = []
	var reactions: Array = []
	for actor_v in actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		var bark_line: String = str(actor.get("bark_line", ""))
		if bark_line.is_empty():
			continue
		var screen_pos: Vector2 = _actor_screen_pos(actor)
		var ev: Dictionary = {
			"actor_id":      str(actor.get("id", "")),
			"bark_line":     bark_line,
			"bark_context":  str(actor.get("bark_context", "")),
			"bark_tier":     str(actor.get("bark_tier", "")),
			"bark_target_id": str(actor.get("bark_target_id", "")),
			"is_response":   bool(actor.get("bark_is_response", false)),
			"screen_pos":    screen_pos,
		}
		if ev["is_response"]:
			reactions.append(ev)
		else:
			originals.append(ev)

	# Sort originals by tier (1 = highest priority shown first).
	originals.sort_custom(func(a, b):
		var ta: int = int(tier_map.get(str(a.get("bark_context", "")), 3))
		var tb: int = int(tier_map.get(str(b.get("bark_context", "")), 3))
		return ta < tb
	)
	if originals.size() > max_originals:
		originals = originals.slice(0, max_originals)

	# Interleave: orig → its reaction (if any) → next orig → ...
	var interleaved: Array = []
	for orig in originals:
		interleaved.append(orig)
		var orig_id: String = str(orig.get("actor_id", ""))
		for reaction in reactions:
			if str(reaction.get("bark_target_id", "")) == orig_id:
				interleaved.append(reaction)
				break

	# Remove any event whose line matches the one immediately before it (or the last shown).
	var deduped: Array = []
	var prev_line: String = _last_bark_line
	for ev in interleaved:
		var line: String = str(ev.get("bark_line", ""))
		if line != prev_line:
			deduped.append(ev)
			prev_line = line
	if not deduped.is_empty():
		_last_bark_line = str(deduped.back().get("bark_line", ""))
		_bark_popup_layer.show_barks(deduped)


# V2-VOICE-002: Pushes current actor positions to BarkPopupLayer so speech bubbles
# follow their token each render pass. Also prunes popups for dead/gone actors.
func _update_bark_positions(actors: Array) -> void:
	if _bark_popup_layer == null:
		return
	var positions: Dictionary = {}
	for actor_v in actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		var actor_id: String = str(actor.get("id", ""))
		if not actor_id.is_empty():
			positions[actor_id] = _actor_screen_pos(actor)
	_bark_popup_layer.update_actor_positions(positions)


# Converts an actor's grid_pos to BarkPopupLayer local space.
# Control has no to_local(); use get_global_transform().affine_inverse() instead.
func _actor_screen_pos(actor: Dictionary) -> Vector2:
	var gp: Dictionary = actor.get("grid_pos", {})
	var cell_pos: Vector2 = _board.map_to_local(Vector2i(gp.get("col", 0), gp.get("row", 0)))
	var world_pos: Vector2 = _board.to_global(cell_pos)
	return _bark_popup_layer.get_global_transform().affine_inverse() * world_pos


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

	# Build dead-id set from actors projection (COMBAT-007: use status field instead of is_dead).
	var dead_ids: Dictionary = {}
	for actor in data.get("actors", []):
		if actor.get("status", "") == "dead":
			dead_ids[str(actor.get("id", ""))] = true

	# Build action-text lookup from action_results resolved so far this round.
	var action_by_id: Dictionary = {}
	for result_v in data.get("action_results", []):
		if result_v is Dictionary:
			var sid: String = str(result_v.get("source_id", ""))
			if not sid.is_empty():
				action_by_id[sid] = _format_action(result_v)

	# V2-EMOTION-001: build actor lookup for emotion fields.
	var actor_by_id: Dictionary = {}
	for actor_v in data.get("actors", []):
		if actor_v is Dictionary:
			actor_by_id[str(actor_v.get("id", ""))] = actor_v

	for child in _initiative_list.get_children():
		child.queue_free()

	for i in range(order.size()):
		var entry: Dictionary  = order[i]
		var actor_id: String   = str(entry.get("id", "??"))
		var actor_name: String = str(entry.get("name", "??"))
		var is_dead: bool      = dead_ids.has(actor_id)
		var action_text: String = action_by_id.get(actor_id, "")
		var row: Node = InitiativeRowScene.instantiate()
		_initiative_list.add_child(row)
		row.call(
			"setup_row",
			actor_name,
			action_text,
			i == active_idx,
			is_dead,
			_action_color_for_text(action_text)
		)
		# V2-EMOTION-002: set unified emotional status per actor row.
		var actor_d: Dictionary = actor_by_id.get(actor_id, {})
		var emotion_str: String = str(actor_d.get("emotional_status", ""))
		var emotion_label := row.get_node("%EmotionLabel") as Label
		emotion_label.text = EmotionPresentation.display_name(emotion_str)
		emotion_label.theme_type_variation = EmotionPresentation.text_theme(emotion_str)
		emotion_label.visible = not emotion_str.is_empty()

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


# -------------------------
# UI-004: Pre-battle panel + Party bar
# -------------------------

## Shows the pre-battle overview panel (pre_combat phase only).
## Populates objective label and wires Retreat + Enter Combat buttons from snapshot.
func _show_prebattle_panel(data: Dictionary, actions: Dictionary) -> void:
	# Hide the main HUD labels — pre_combat uses its own panel.
	_round_label.visible     = false
	_objective_label.visible = false

	# Objective label.
	var obj_state: Dictionary = data.get("objective_state", {})
	var obj_type: String = str(obj_state.get("type", ""))
	_prebattle_objective.text = _format_objective_label(obj_type)

	# Enter Combat button — always enabled; dispatches cta.combat_init.
	if actions.has("cta.combat_init"):
		_enter_combat_button.disabled = false
		_pending_enter_combat_action  = actions["cta.combat_init"]
	else:
		_enter_combat_button.disabled = true
		_pending_enter_combat_action  = {}

	# Retreat button — always shown; enabled only when eligible.
	var retreat_eligible: bool = bool(data.get("retreat_eligible", false))
	if retreat_eligible and actions.has("cta.retreat"):
		_pending_retreat_action   = actions["cta.retreat"]
		_retreat_button.disabled  = false
		var tier_label: String    = str(data.get("retreat_tier_label", ""))
		var ase_cost: int         = int(data.get("retreat_ase_cost", 0))
		if tier_label == "Guaranteed":
			_retreat_button.text = "Retreat (%d ase)\nEscape guaranteed" % ase_cost
		else:
			_retreat_button.text = "Retreat (%d ase)\nChance of failure: %s" % [ase_cost, tier_label.to_lower()]
	else:
		_pending_retreat_action  = {}
		_retreat_button.disabled = true
		_retreat_button.text     = "Retreat is not possible"

	_prebattle_panel.visible = true

## Maps objective type string to a player-facing label.
func _format_objective_label(obj_type: String) -> String:
	match obj_type:
		"purify_shrine":   return "Purify the Ancestral Shrine"
		"defeat_enemies":  return "Defeat all enemies"
		"pursue":          return "Contain the Fleeing Quarry"
	return obj_type if not obj_type.is_empty() else "[Battle objective]"


func _on_enter_combat_pressed() -> void:
	if not _pending_enter_combat_action.is_empty():
		var act := _pending_enter_combat_action
		_pending_enter_combat_action = {}
		action_requested.emit(act)


func _on_retreat_pressed() -> void:
	if not _pending_retreat_action.is_empty():
		var act := _pending_retreat_action
		_pending_retreat_action = {}
		action_requested.emit(act)


# -------------------------
# V2-STAGE-004 P3b: PURSUE camera follow
# -------------------------

func _process(delta: float) -> void:
	if not _pursue_mode:
		return
	if _pan_active:
		_pan_resume_timer -= delta
		if _pan_resume_timer <= 0.0:
			_pan_active = false
			_pan_offset = Vector2.ZERO
	var target: Vector2 = get_viewport_rect().size / 2.0 - _quarry_local_pos + _pan_offset
	var new_pos: Vector2 = _board.position.lerp(target, clampf(_PURSUE_FOLLOW_SPEED * delta, 0.0, 1.0))
	_apply_board_transform(new_pos)


func _unhandled_input(event: InputEvent) -> void:
	if not _pursue_mode:
		return
	if event is InputEventPanGesture:
		_pan_offset -= (event as InputEventPanGesture).delta * 1.5
		_pan_active = true
		_pan_resume_timer = _PAN_RESUME_DELAY
	elif event is InputEventMagnifyGesture:
		var factor: float = (event as InputEventMagnifyGesture).factor
		var new_zoom: float = clampf(_board.scale.x * factor, 0.4, 2.0)
		var all_zoom := Vector2(new_zoom, new_zoom)
		_board.scale               = all_zoom
		_token_layer.scale         = all_zoom
		_move_telegraph_layer.scale = all_zoom
		_distance_layer.scale      = all_zoom
		if _bark_popup_layer != null:
			_bark_popup_layer.scale = all_zoom
		_pan_active = true
		_pan_resume_timer = _PAN_RESUME_DELAY


func _apply_board_transform(pos: Vector2) -> void:
	_board.position              = pos
	_token_layer.position        = pos
	_move_telegraph_layer.position = pos
	_distance_layer.position     = pos
	if _bark_popup_layer != null:
		_bark_popup_layer.position = pos
