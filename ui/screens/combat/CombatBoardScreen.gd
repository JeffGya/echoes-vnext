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
signal modal_requested(modal_id: StringName, payload: Dictionary)

const InitiativeRowScene := preload("res://ui/components/InitiativeRowItem.tscn")
const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")
const PacePresentation := preload("res://ui/components/PacePresentation.gd")
const PICKUP_TYPE := "flow.pickup"
const StandoffStrings := preload("res://ui/components/StandoffPresentation.gd")
const CarriedHomePresentation := preload("res://ui/components/CarriedHomePresentation.gd")
const StopShortMotion := preload("res://ui/screens/combat/CombatStopShortMotion.gd")

# WorldLayer.follow_viewport_enabled (in the .tscn) is what lets the Camera2D move the board.
# Without it the camera changes only the viewport canvas transform, which a CanvasLayer ignores.
@onready var _world_layer: CanvasLayer              = $WorldLayer
# Board content is centred on world origin here, because the camera bounds are symmetric about it.
@onready var _board_root: Node2D                    = %BoardRoot
@onready var camera: BoardCameraController          = %BoardCamera
@onready var _board: TileMapLayer                   = %Board
# V2-COMBAT-003 terrain commit 4 (decision 16) — a bridge is its own tile. A CHILD of Board,
# so it inherits every pan, zoom and centring transform with no sync code, and it draws a
# tinted overlay ON TOP of the ordinary ground tile rather than replacing it — so the board
# silhouette and the isometric overlap order are byte-identical to before. The tint is a
# PLACEHOLDER for the real bridge art; the geometry it reads is already in the terrain dict.
@onready var _bridge_layer: TileMapLayer            = %BridgeLayer
@onready var _move_telegraph_layer: Node2D          = %MoveTelegraphLayer
@onready var _token_layer: CombatTokenLayer         = %TokenLayer
@onready var _finds_layer: PickupFindsLayer         = %PickupFindsLayer
@onready var _pickup_mote: PickupPointerMote        = %PickupPointerMote
# V2-VOICE-001: bark popup layer — optional; null-checked before use.
@onready var _bark_popup_layer: BarkPopupLayer      = get_node_or_null("%BarkPopupLayer") as BarkPopupLayer
@onready var _distance_layer: CombatDistanceLayer   = %DistanceLayer
@onready var _back_button: Button                   = $BackButton
@onready var _round_label: Label                    = $RoundLabel
@onready var _objective_label: Label                = $ObjectiveLabel
# V2-STAGE-004 P5: authored ObjectiveBanner (replaces the bare objective label during combat).
@onready var _objective_banner: PanelContainer      = %ObjectiveBanner
@onready var _stall_panel: PanelContainer           = %StallPanel
@onready var _stall_label: Label                    = %StallLabel
@onready var _banner_glyph: Label                   = %GlyphLabel
@onready var _banner_instruction: Label             = %InstructionLabel
@onready var _banner_progress: Label                = %ProgressLabel
@onready var _banner_quarry_pips: HBoxContainer      = %QuarryPips
# V2-STAGE-004 Phase 4 (S15 UI-B): "Pressure raised" marker — shown when objective_state
# .charge_pressure_applied is true. Icon+text (Amber), never colour-only.
@onready var _banner_pressure_marker: HBoxContainer  = %PressureMarker
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
# V2-STAGE-004 Phase 4 (S15 UI-B): claimant-forced combat intro line — hidden when
# data.combat_intro_line is "".
@onready var _speed_slow_button: Button             = %SpeedSlowButton
@onready var _speed_normal_button: Button           = %SpeedNormalButton
@onready var _speed_fast_button: Button             = %SpeedFastButton
# Camera controls (all modes): recenter-on-party button.
@onready var _recenter_button: Button               = %RecenterButton
# Pickup event host (V2-ITEM-001b). The stage sits over the board; the speed bar lies outside
# _reset_transient_ui, so the pickup branch hides it and every other snapshot shows it again.
@onready var _speed_bar: HBoxContainer              = %SpeedBar
@onready var _pickup_stage: PickupEventStage        = %PickupEventStage
@onready var _pickup_debug: PickupDebugContinue     = %PickupDebugContinue

# Clay floor tile: source 0, atlas position (0, 0)
const _TILE_SOURCE_ID:    int       = 0
const _TILE_ATLAS_COORDS: Vector2i  = Vector2i(0, 0)

# V2-STAGE-004 P5: ObjectiveBanner urgent-state tinting (applied via modulate; base = WHITE).
# The urgent tint is used when a PROTECT totem is stolen or a PURSUE quarry is at the exit edge.
const _BANNER_MODULATE_NORMAL: Color = Color(1, 1, 1, 1)
const _BANNER_MODULATE_URGENT: Color = Color(1.0, 0.62, 0.55, 1)
# Pip glyphs: filled = urgency, hollow = safe distance.
const _PIP_FILLED: String = "◆"
const _PIP_HOLLOW: String = "◇"
const _PIP_COUNT:  int    = 5
# Cached banner StyleBoxes captured at _ready from the authored ObjectiveBanner panel.
# _normal is the authored base; _urgent is a duplicate re-tinted for the PROTECT stolen state.
var _normal_banner_style: StyleBoxFlat = null
var _urgent_banner_style: StyleBoxFlat = null
# Authored .tscn font colours, restored when the fight has no pace_state.
var _round_label_color: Color = Color.WHITE
var _banner_glyph_color: Color = Color.WHITE
var _banner_progress_color: Color = Color.WHITE
# Pace colour blend (decisions.md D-28). The last applied pace_state; "" = none applied yet or a
# no-pace fight. The blend tween starts only when this value changes between two pace states.
var _last_pace_state: String = ""
var _pace_tween: Tween = null
# Quiet-fight warning: the level on screen (0 = none) and its fade. The bark plays once per fight.
const _STALL_FADE_TIME: float = 0.4
var _stall_level: int = 0
var _stall_tween: Tween = null
var _stall_bark_done: bool = false

const _SPEED_SLOW:   float = 3.0
const _SPEED_NORMAL: float = 1.5
const _SPEED_FAST:   float = 0.5
const _MOVE_DURATION_SLOW: float = 0.72
const _MOVE_DURATION_NORMAL: float = 0.36
const _MOVE_DURATION_FAST: float = 0.20
const _TELEGRAPH_DURATION_SLOW: float = 0.28
const _TELEGRAPH_DURATION_NORMAL: float = 0.16
const _TELEGRAPH_DURATION_FAST: float = 0.09
# Pace drop brightening (decisions.md D-28): the fraction toward white, and its time in seconds.
const _PACE_DROP_BRIGHTEN: float = 0.4
const _PACE_DROP_BRIGHTEN_TIME: float = 0.08

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
# Cached actor projection from the latest snapshot — board-tap hit test and camera follow read it.
var _last_actors: Array = []
var _layout: Dictionary = {}
# Stop-short step state: actor, report, held bark, and rows that switch word at settle.
var _step_actor_id: String = ""
var _step_stop_short: Dictionary = {}
var _held_barks: Array = []
var _pending_row: Dictionary = {}

# Camera zoom (decisions.md #70, #71). min_zoom derives from the real board span so the whole board
# fits at full zoom-out on any board shape.
const _ZOOM_FIT_FACTOR: float     = 0.90
const _ZOOM_MIN_FLOOR: float      = 0.05
const _ZOOM_MIN_CEILING: float    = 0.35
const _ZOOM_MAX: float            = 2.2
const _ZOOM_DEFAULT: float        = 1.3
# Unscaled isometric board extent in pixels, from map_to_local corners plus one tile.
var _board_span_px: Vector2       = Vector2(1280.0, 640.0)
# A new encounter (or board size) resets zoom, position and selection on the next _center_board.
var _camera_needs_reset: bool     = true
# Pickup framing (D-73): the tiles to keep in view, the camera tunables of the snapshot, and the running move.
const _PICKUP_FRAME_PAD: float    = 16.0
const _PICKUP_FRAME_STRIP_GAP: float = 8.0
# EchoBar height (ui/AGENTS.md: 88). The pads 16 and 8 and the 88 stay in code: screen-layout offsets, as in _apply_responsive_layout (ANSWERS #83).
const _ECHO_BAR_HEIGHT: float     = 88.0
var _pickup_cells: Array[Vector2i] = []
var _pickup_camera_cfg: Dictionary = {}
var _pickup_camera_tween: Tween = null
# True from a new event until the deferred framing runs. Tests read it, because deferred calls do not run inside a test.
var _pickup_frame_due: bool = false
# "event|chooser|text" of the bark now shown in the pickup event; "" when none. A repeat snapshot with the same key shows nothing again.
var _pickup_bark_key: String = ""
# The row Echoes' board positions by row index, one grid step toward the camera, and the chooser, for the pointer mote.
var _pickup_row_positions: Array = []
var _pickup_lateral: Vector2 = Vector2.ZERO
var _pickup_chooser_id: String = ""
# The pickup plan of the event on show (built once per identity), how many of its chooser legs the board already played, and the
# row Echoes as the snapshot gives them (the chooser on its row tile). Presentation only; none of it is saved.
var _pickup_plan: Dictionary = {}
var _pickup_plan_identity: String = ""
var _pickup_legs_started: int = 0
var _pickup_base_actors: Array = []
# The snapshot of the event on show: the intro finds and the pack strip are drawn from it at the clock time.
var _pickup_snap: Dictionary = {}
# The intro was on show at the last render; the last mote pose; seconds left (and in total) of the fade after a skip (< 0 = none).
var _pickup_intro_on: bool = false
var _pickup_last_pose: Dictionary = {}
var _pickup_skip_left: float = -1.0
var _pickup_skip_total: float = 0.0
# Input of the event (U7). The lowest zoom that keeps the finds apart (0 = none); the last input was a key or pad (focus moves to the
# card only then); where the focus goes back when the card closes; a close the board already asked for.
var _pickup_zoom_floor: float = 0.0
# The floor the finds ask for, and the zoom at which the framed box just fits (INF when it fits at the floor). The fit wins (D-73): the
# camera floor is the lower of the two.
var _pickup_floor_derived: float = 0.0
var _pickup_fit_cap: float = INF
var _pickup_key_input: bool = false
# What opened the current card by keyboard, so closing returns the focus there: an int is a find index, a Control is a pack tile, null is none.
var _pickup_opener: Variant = null
var _pickup_close_sent: bool = false
# Continue was sent: the Resolve card is over the board, so the event takes no input until a new pickup snapshot arrives.
var _pickup_ended: bool = false
# Bark bubbles stay in screen space, so they are re-anchored whenever the camera view changes.
var _last_canvas_xform: Transform2D = Transform2D.IDENTITY

# Tells a board tap from a drag from a pinch. A tap selects the actor under it or, on empty board,
# releases the camera to FREE. A drag pans the camera 1:1.
var _pointer := BoardPointerTracker.new()

# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	_pointer.tap.connect(_on_pointer_tap)
	_token_layer.actor_settled.connect(_on_actor_settled)
	_pointer.drag_pan.connect(camera.drag_pan)
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

	# Speed buttons are authored in scene.
	_speed_slow_button.pressed.connect(func(): _on_speed_pressed(_SPEED_SLOW))
	_speed_normal_button.pressed.connect(func(): _on_speed_pressed(_SPEED_NORMAL))
	_speed_fast_button.pressed.connect(func(): _on_speed_pressed(_SPEED_FAST))
	_apply_visual_playback_for_delay(_SPEED_NORMAL)

	# Camera controls (all modes): recenter-on-party button. Hidden until combat is drawn.
	_recenter_button.visible = false
	_recenter_button.pressed.connect(_on_recenter_pressed)
	_pickup_debug.action_requested.connect(_on_action)
	_pickup_stage.clock_ticked.connect(_on_pickup_clock)
	_pickup_stage.action_requested.connect(_on_action)

	# CanvasLayer visibility and Camera2D.enabled do not follow this Control. A hidden screen must
	# neither draw its board nor drive the viewport canvas transform.
	visibility_changed.connect(_sync_world_visibility)
	_sync_world_visibility()

	# V2-STAGE-004 P5: cache the authored banner StyleBox and derive the urgent variant.
	# _normal is the .tscn-authored base; _urgent duplicates it and re-tints bg + border red
	# for the PROTECT "STOLEN" state (distinct chrome, not just a modulate).
	_objective_banner.visible = false
	_round_label_color     = _round_label.get_theme_color("font_color")
	_banner_glyph_color    = _banner_glyph.get_theme_color("font_color")
	_banner_progress_color = _banner_progress.get_theme_color("font_color")
	# get_theme_stylebox() returns the effective stylebox (the .tscn-authored override here) —
	# Control has no get_theme_stylebox_override() getter, only has_/add_/remove_.
	_normal_banner_style = _objective_banner.get_theme_stylebox("panel") as StyleBoxFlat
	if _normal_banner_style != null:
		_urgent_banner_style = _normal_banner_style.duplicate() as StyleBoxFlat
		_urgent_banner_style.bg_color     = Color(0.16, 0.04, 0.04, 0.88)
		_urgent_banner_style.border_color = Color(0.86, 0.27, 0.22, 0.9)


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
	if str(snap["type"]) == PICKUP_TYPE:
		_render_pickup(snap, data)
	else:
		_leave_pickup()
		_render(data, snap.get("actions", {}))
	_active_encounter_id = str(data.get("encounter_id", ""))
	_presentation_board_size = Vector2i(
		int(data.get("board_cols", 10)),
		int(data.get("board_rows", 10))
	)
	_apply_responsive_layout()

func set_layout(layout: Dictionary) -> void:
	_layout = layout.duplicate(true)
	_apply_responsive_layout()
	if _current_cols > 0 and _current_rows > 0:
		_center_board(_current_cols, _current_rows)
		# The viewport may have changed, and min_zoom depends on it. Keep the player's zoom.
		var min_zoom := _current_min_zoom()
		camera.configure_zoom_range(min_zoom, _ZOOM_MAX, clampf(camera.zoom.x, min_zoom, _ZOOM_MAX))
		camera.reclamp()
		if is_instance_valid(_pickup_stage) and _pickup_stage.visible and not camera.has_manual_override:
			frame_pickup_camera(false)


## The pickup event keeps the board drawn from the snapshot (terrain, size) and shows no combat HUD. Only the standing
## Echoes get a token, on their row tiles (the chooser on the tile its legs have reached; on `chooser_end_cell` in idle), with no
## active actor (no selection ring; the intro pointer is the mote).
## The snapshot has no nav.back slot, so Back stays hidden and AppRoot's Back does nothing.
func _render_pickup(snap: Dictionary, data: Dictionary) -> void:
	_flush_held_barks()
	_pickup_ended = false
	var new_event := PickupEventStage.identity_of(data) != _pickup_stage.identity()
	if new_event:
		_pickup_fit_cap = INF
		camera.deselect()
		camera.has_manual_override = false
		_pickup_bark_key = ""
		_pickup_skip_left = -1.0
		_pickup_last_pose = {}
		_pickup_intro_on = false
		_hide_pickup_mote()
		if _bark_popup_layer != null:
			_bark_popup_layer.clear_all()
	_pickup_cells = pickup_frame_cells(data)
	var cfg_v: Variant = data.get("camera_frame", {})
	_pickup_camera_cfg = cfg_v if cfg_v is Dictionary else {}
	if not _pickup_stage.visible:
		# Tokens left from the fight would slide to the row tiles.
		_token_layer.reset_presentation()
		_move_telegraph_layer.clear_telegraph()
	_current_cols = int(data.get("board_cols", 10))
	_current_rows = int(data.get("board_rows", 10))
	var terrain_v: Variant = data.get("terrain", {})
	_draw_board(_current_cols, _current_rows, terrain_v if terrain_v is Dictionary else {})
	_center_board(_current_cols, _current_rows)
	var identity := PickupEventStage.identity_of(data)
	if identity != _pickup_plan_identity:
		_pickup_plan = PickupEventPlan.build(snap, PickupEventPlan.board_opts())
		_pickup_plan_identity = identity
		_pickup_legs_started = 0
	_pickup_base_actors = pickup_row_actors(data)
	_pickup_chooser_id = pickup_chooser_id(data)
	var phase := str(data.get("phase", ""))
	var chooser_now := pickup_chooser_cell(_pickup_plan, phase, 0.0 if new_event else _pickup_stage.clock_time())
	_pickup_legs_started = int(chooser_now["started"])
	var actors: Array = pickup_actors_at(_pickup_base_actors, _pickup_chooser_id, chooser_now)
	_last_actors = actors
	if actors.is_empty():
		_token_layer.reset_presentation()
		_move_telegraph_layer.clear_telegraph()
	else:
		_draw_tokens(actors, "", {})
	_pickup_row_positions = pickup_row_positions(data)
	_pickup_lateral = pickup_lateral(data, _pickup_row_positions)
	if phase == "intro":
		_pickup_intro_on = true
	else:
		# The intro ended (Skip or its end): the mote, halo and brightness fade out; everything else is the idle picture at once.
		if _pickup_intro_on and not _pickup_last_pose.is_empty() and bool(_pickup_plan.get("valid", false)):
			_pickup_skip_total = float((_pickup_plan["pointer"] as Dictionary)["mote"]["skip_fade"])
			_pickup_skip_left = _pickup_skip_total
		elif _pickup_skip_left < 0.0:
			_hide_pickup_mote()
		_pickup_intro_on = false
	_finds_layer.show_finds(data, _board)
	_show_pickup_bark(data, actors, 0.0 if new_event else _pickup_stage.clock_time())
	_update_bark_positions(actors)
	_push_camera_follow_target()
	_stall_level = 0
	_kill_stall_tween()
	_stall_panel.visible = false
	_speed_bar.visible = false
	_pickup_stage.visible = true
	_pickup_snap = snap
	_pickup_stage.apply_snapshot(snap)
	_place_pickup_strip()
	call_deferred("_place_pickup_strip")
	_apply_pickup_zoom_floor(data)
	_pickup_close_sent = false
	_update_pickup_card(true)
	if phase == "intro":
		# The finds and the strip show the intro at the clock time: a repeat snapshot must not reset them.
		_advance_pickup_items(0.0 if new_event else _pickup_stage.clock_time())
	if new_event:
		_pickup_frame_due = true
		call_deferred("frame_pickup_camera", true)
	if is_instance_valid(_pickup_debug):
		_pickup_debug.apply_actions(snap.get("actions", {}))


## The intro clock drives the chooser's walk and the pointer mote. No ring, no camera move.
func _on_pickup_clock(t: float) -> void:
	if not _pickup_stage.visible:
		return
	_advance_pickup_walk(t)
	_advance_pickup_items(t)
	var cfg: CombatTokenVisualConfig = _token_layer.visual_config
	var plan := _pickup_stage.plan()
	var pose := PickupPointerMote.pose_at(plan, _pickup_row_positions, _pickup_lateral, t, cfg.token_radius)
	if bool(pose["visible"]):
		if t >= float((plan["pointer"] as Dictionary)["fade_t"]):
			# The chooser walks away: the halo goes with the token while it fades.
			var centre := _pickup_chooser_centre(t)
			if centre != Vector2.INF:
				pose["halo_pos"] = centre
		_pickup_mote.apply_pose(pose, (plan["pointer"] as Dictionary)["mote"], float(_board.tile_set.tile_size.x))
		_pickup_last_pose = pose
	else:
		_pickup_mote.hide_all()
		_pickup_last_pose = {}
	_token_layer.set_brighten(_pickup_chooser_id, float(pose["brighten"]))
	_advance_pickup_bark(t)


## The intro bark at clock time `t`: shown by `_show_pickup_bark` once `t` reaches the plan's bark time.
func _advance_pickup_bark(t: float) -> void:
	if not bool(_pickup_plan.get("valid", false)) or _pickup_snap.is_empty():
		return
	var cell: Dictionary = PickupEventPlan.chooser_target_at(_pickup_plan, t)["cell"]
	var actors := pickup_actors_at(_pickup_base_actors, _pickup_chooser_id, { "cell": cell })
	_show_pickup_bark(_pickup_snap["data"] as Dictionary, actors, t)


## The fade of the mote, halo and brightness after a skip: the last pose with its alphas scaled down linearly.
func _step_pickup_skip_fade(delta: float) -> void:
	_pickup_skip_left -= delta
	var k := maxf(_pickup_skip_left, 0.0) / maxf(_pickup_skip_total, 0.0001)
	if _pickup_skip_left <= 0.0 or _pickup_last_pose.is_empty():
		_pickup_skip_left = -1.0
		_pickup_last_pose = {}
		_hide_pickup_mote()
		return
	var pose := _pickup_last_pose.duplicate()
	for key: String in ["alpha", "halo_alpha", "shadow_alpha", "brighten"]:
		pose[key] = float(pose[key]) * k
	pose["trail"] = []
	var plan_mote: Dictionary = (_pickup_plan["pointer"] as Dictionary)["mote"]
	_pickup_mote.apply_pose(pose, plan_mote, float(_board.tile_set.tile_size.x))
	_token_layer.set_brighten(_pickup_chooser_id, float(pose["brighten"]))


## The chooser's token centre at clock time `t` (board px). While the chooser stands, it is the planned tile: the token layer moves a
## token on its next frame, so after a jump of the clock its live position is still the old one. While a leg runs the token is
## between two tiles and only the live position is right. INF when there is no plan.
func _pickup_chooser_centre(t: float) -> Vector2:
	if not bool(_pickup_plan.get("valid", false)):
		return Vector2.INF
	var feet := Vector2(0.0, _token_layer.visual_config.feet_offset_y)
	if PickupEventPlan.chooser_walking(_pickup_plan, t):
		var drawn := _token_layer.display_cell_position(_pickup_chooser_id)
		if drawn != Vector2.INF:
			return drawn + feet
	var cell: Dictionary = PickupEventPlan.chooser_target_at(_pickup_plan, t)["cell"]
	return _board.map_to_local(Vector2i(int(cell["col"]), int(cell["row"]))) + feet


## The finds and the pack strip at clock time `t`: a pure function of the plan and `t` (the chooser's place comes from the plan while
## it stands), so a jump of the clock shows the same state as stepping to it. The plan is the one the board keeps for the event;
## with no valid plan the intro stays the still picture.
func _advance_pickup_items(t: float) -> void:
	if not bool(_pickup_plan.get("valid", false)) or _pickup_snap.is_empty():
		return
	var frame := PickupEventPlan.frame_at(_pickup_plan, t)
	var items: Dictionary = frame["items"]
	var landed: Array = []
	var appear := {}
	var reduced := bool(_pickup_plan["reduced"])
	for find_id: Variant in items:
		var state := str((items[find_id] as Dictionary)["state"])
		if state == "pack":
			landed.append(str(find_id))
		elif reduced and state == "flying":
			# Reduced motion: the slot fades in while the ground card fades out.
			landed.append(str(find_id))
			appear[str(find_id)] = float((items[find_id] as Dictionary)["p"])
	_pickup_stage.pack_strip().apply_intro_frame(_pickup_snap, landed, str((frame["pack"] as Dictionary)["tone"]), appear)
	_finds_layer.show_intro(_pickup_snap["data"] as Dictionary, _board, items, _pickup_plan["items_look"] as Dictionary, _pickup_slot_target,
		_pickup_chooser_centre(t), reduced)


## Where a find lands: the centre of its strip slot and the slot's edge, in viewport px. {} when the find has no slot.
func _pickup_slot_target(find_id: String) -> Dictionary:
	var strip := _pickup_stage.pack_strip()
	var slot := strip.slot_index_of_find(find_id)
	if slot < 0:
		return {}
	return { "center": strip.get_canvas_transform() * strip.slot_global_center(slot), "bed": strip.bed_size() }


## Plays the chooser's legs in step with the clock. A leg that starts on this tick walks on the token layer's own path walk for
## the leg's time (`pickup.walk`: no telegraph, no hop). If the clock jumped over a leg (or several), the token snaps to the end
## of the last one at once.
func _advance_pickup_walk(t: float) -> void:
	if not bool(_pickup_plan.get("valid", false)) or _pickup_chooser_id.is_empty():
		return
	var legs: Array = _pickup_plan["legs"]
	var first := _pickup_legs_started
	var next := first
	while next < legs.size() and t >= float((legs[next] as Dictionary)["t0"]):
		next += 1
	if next == first:
		return
	_pickup_legs_started = next
	var leg: Dictionary = legs[next - 1]
	var cells: Array = leg["cells"]
	var seconds := float(leg["t1"]) - float(leg["t0"])
	var animate := next - first == 1 and t < float(leg["t1"]) and cells.size() > 1
	var end_cell: Dictionary = cells[cells.size() - 1]
	var actors := pickup_actors_at(_pickup_base_actors, _pickup_chooser_id, { "cell": end_cell, "snap": not animate, "seconds": seconds,
		"ease": float(_pickup_plan["walk_ease"]) })
	_last_actors = actors
	var action := {}
	if animate:
		action = { "action_type": "pickup.walk", "source_id": _pickup_chooser_id, "path": cells.slice(1) }
	_draw_tokens(actors, "", { "last_actor_action": action } if animate else {})


## The chooser's tile for a render: `chooser_end_cell` in idle, the tile its legs have reached at clock time `t` in the intro,
## the row tile when the plan is not valid. { cell ({} = the row tile), started, snap }.
static func pickup_chooser_cell(plan: Dictionary, phase: String, t: float) -> Dictionary:
	if not bool(plan.get("valid", false)):
		return { "cell": {}, "started": 0, "snap": false }
	if phase != "intro":
		return { "cell": plan["chooser_end_cell"], "started": (plan["legs"] as Array).size(), "snap": true }
	var target := PickupEventPlan.chooser_target_at(plan, t)
	return { "cell": target["cell"], "started": int(target["started"]), "snap": false }


## `base` (the row Echoes, the chooser on its row tile) with the chooser moved to `where.cell`. A snap, or a walk of
## `where.seconds`, is set as the chooser's `move_duration`; the other Echoes are never touched.
static func pickup_actors_at(base: Array, chooser_id: String, where: Dictionary) -> Array:
	var out: Array = []
	var cell: Dictionary = where.get("cell", {})
	for actor_v in base:
		var actor: Dictionary = (actor_v as Dictionary).duplicate(true)
		if not cell.is_empty() and str(actor.get("id", "")) == chooser_id:
			actor["grid_pos"] = { "col": int(cell.get("col", 0)), "row": int(cell.get("row", 0)) }
			if bool(where.get("snap", false)):
				actor["move_duration"] = 0.001
			elif where.has("seconds"):
				actor["move_duration"] = float(where["seconds"])
				if where.has("ease"):
					actor["move_ease"] = float(where["ease"])
		out.append(actor)
	return out


func _hide_pickup_mote() -> void:
	_pickup_mote.hide_all()
	_token_layer.clear_brighten()


## The board centre of every row token, by row index: the token's own draw position.
func pickup_row_positions(data: Dictionary) -> Array:
	var out: Array = []
	for entry_v in data.get("row", []):
		var tile: Dictionary = (entry_v as Dictionary).get("tile", {}) if entry_v is Dictionary else {}
		out.append(_board.map_to_local(Vector2i(int(tile.get("col", 0)), int(tile.get("row", 0)))) + Vector2(0.0, _token_layer.visual_config.feet_offset_y))
	return out


## One step toward the camera, in board pixels: the neighbour grid tile across a straight row, else the screen perpendicular.
func pickup_lateral(data: Dictionary, positions: Array) -> Vector2:
	var rows: Array = data.get("row", [])
	if rows.size() >= 2 and rows[0] is Dictionary and rows[1] is Dictionary:
		var a: Dictionary = (rows[0] as Dictionary).get("tile", {})
		var b: Dictionary = (rows[1] as Dictionary).get("tile", {})
		var step := Vector2i(int(b.get("col", 0)) - int(a.get("col", 0)), int(b.get("row", 0)) - int(a.get("row", 0)))
		if absi(step.x) + absi(step.y) == 1:
			var from := Vector2i(int(a.get("col", 0)), int(a.get("row", 0)))
			var perp := Vector2i(-step.y, step.x)
			var down := _board.map_to_local(from + perp) - _board.map_to_local(from)
			return down if down.y >= 0.0 else -down
	return PickupPointerMote.screen_lateral(positions)


## The pack strip sits above the EchoBar of the shell; NAN (no shell above this board) lets the strip use its fallback.
func _place_pickup_strip() -> void:
	if not is_instance_valid(_pickup_stage):
		return
	_pickup_stage.set_layout(_layout)
	_pickup_stage.place_pack_strip(_echo_bar_top())


## The lowest zoom now: the board fit, raised during the event so that two finds keep a 48 px target and an 8 px gap (B1).
func _current_min_zoom() -> float:
	return maxf(_min_zoom_for_span(_board_span_px), _pickup_zoom_floor)


## The floor comes from the finds the snapshot puts on the board, so it needs no config: it is (48 + 8) / the nearest pair of finds in
## board px. A floor that changed moves the zoom range; the zoom stays where it is unless it is below the new floor.
func _apply_pickup_zoom_floor(data: Dictionary) -> void:
	var points: Array = []
	for f: Dictionary in PickupFindsLayer.ground_finds(data):
		var t: Dictionary = f["tile"]
		points.append(_board.map_to_local(Vector2i(int(t.get("col", 0)), int(t.get("row", 0)))))
	_pickup_floor_derived = PickupHitRules.min_zoom(points)
	_update_pickup_floor()


func _update_pickup_floor() -> void:
	var next := minf(_pickup_floor_derived, _pickup_fit_cap)
	if is_equal_approx(next, _pickup_zoom_floor):
		return
	_pickup_zoom_floor = next
	var min_zoom := _current_min_zoom()
	camera.configure_zoom_range(min_zoom, _ZOOM_MAX, clampf(camera.zoom.x, min_zoom, _ZOOM_MAX))


## Moves the camera so every row and find tile is in view, clear of the pack strip, the EchoBar and the safe areas.
## Does nothing without `camera_frame` in the snapshot. The tween copies the Sanctum camera tween.
func frame_pickup_camera(animated: bool) -> void:
	_pickup_frame_due = false
	if not is_instance_valid(_pickup_stage) or not _pickup_stage.visible or _pickup_cells.is_empty() \
			or not _pickup_camera_cfg.has("floor_zoom"):
		return
	var view := get_viewport_rect().size
	var insets: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	var bottom := _echo_bar_top()
	if is_nan(bottom):
		bottom = view.y - ceilf(insets.w) - _ECHO_BAR_HEIGHT
	var strip := _pickup_stage.pack_strip().panel_global_rect()
	if strip.size.y > 0.0:
		bottom = minf(bottom, strip.position.y - _PICKUP_FRAME_STRIP_GAP)
	var top := ceilf(insets.y) + _PICKUP_FRAME_PAD
	var left := ceilf(insets.x) + _PICKUP_FRAME_PAD
	var usable := Rect2(left, top, view.x - ceilf(insets.z) - _PICKUP_FRAME_PAD - left, bottom - top)
	var points := PackedVector2Array()
	for cell in _pickup_cells:
		points.append(_board_root.position + _board.map_to_local(cell))
	# When the box does not fit at the finds' floor, the fit wins and the floor gives way to it (spacing 1 or a small screen).
	var fit := PickupCameraFrame.fit_zoom(points, Vector2(_board.tile_set.tile_size), usable, float(_pickup_camera_cfg.get("margin_px", 0.0)))
	_pickup_fit_cap = fit if fit > 0.0 and fit < _pickup_floor_derived - 0.0001 else INF
	_update_pickup_floor()
	var framed := PickupCameraFrame.frame(points, Vector2(_board.tile_set.tile_size), view, usable, camera.zoom.x,
		_current_min_zoom(), _ZOOM_MAX, float(_pickup_camera_cfg["floor_zoom"]),
		float(_pickup_camera_cfg.get("margin_px", 0.0)))
	if not bool(framed["valid"]):
		return
	var target_zoom := Vector2(float(framed["zoom"]), float(framed["zoom"]))
	var target_position := camera.clamped_position(framed["position"], target_zoom)
	var seconds := float(_pickup_camera_cfg.get("tween_seconds", 0.0))
	_kill_pickup_camera_tween()
	if not animated or seconds <= 0.0:
		camera.cancel_zoom_ease()
		camera.zoom = target_zoom
		camera.position = target_position
		camera.reclamp()
		return
	camera.begin_screen_animation()
	_pickup_camera_tween = create_tween()
	_pickup_camera_tween.set_trans(Tween.TRANS_SINE)
	_pickup_camera_tween.set_ease(Tween.EASE_OUT)
	_pickup_camera_tween.parallel().tween_property(camera, "zoom", target_zoom, seconds)
	_pickup_camera_tween.parallel().tween_property(camera, "position", target_position, seconds)
	_pickup_camera_tween.tween_callback(camera.end_screen_animation)
	_pickup_camera_tween.tween_callback(camera.reclamp)


## A killed tween never runs its end callback, so the camera hold is released here.
func _kill_pickup_camera_tween() -> void:
	if _pickup_camera_tween != null and _pickup_camera_tween.is_valid():
		_pickup_camera_tween.kill()
	_pickup_camera_tween = null
	camera.end_screen_animation()


## The tiles the pickup camera keeps in view: every row tile and every find tile.
static func pickup_frame_cells(data: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key in ["row", "finds"]:
		for entry_v in data.get(key, []):
			var tile_v: Variant = (entry_v as Dictionary).get("tile", {}) if entry_v is Dictionary else {}
			if PickupFindsLayer.tile_valid(tile_v):
				cells.append(Vector2i(int((tile_v as Dictionary).get("col", 0)), int((tile_v as Dictionary).get("row", 0))))
	return cells


func _echo_bar_top() -> float:
	var node: Node = get_parent()
	while node != null:
		var frame := node.get_node_or_null("%EchoBarFrame") as Control
		if frame != null:
			return frame.get_global_rect().position.y
		node = node.get_parent()
	return NAN


## The actors to draw in a pickup snapshot: the `row` Echoes, in row order, each moved to its `tile`.
static func pickup_row_actors(data: Dictionary) -> Array:
	var by_id: Dictionary = {}
	for actor_v in data.get("actors", []):
		if actor_v is Dictionary:
			by_id[str((actor_v as Dictionary).get("id", ""))] = actor_v
	var drawn: Array = []
	for entry_v in data.get("row", []):
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var actor_v: Variant = by_id.get(str(entry.get("id", "")))
		if actor_v == null:
			continue
		var actor: Dictionary = (actor_v as Dictionary).duplicate(true)
		var tile_v: Variant = entry.get("tile", {})
		if tile_v is Dictionary and not (tile_v as Dictionary).is_empty():
			actor["grid_pos"] = { "col": int((tile_v as Dictionary).get("col", 0)), "row": int((tile_v as Dictionary).get("row", 0)) }
		drawn.append(actor)
	return drawn


## The chooser's one bark line. Mirrors PickupEventPlan.build (`plan.bark.text`): same inputs; the chooser is the single `is_chooser` row.
static func pickup_bark_text(data: Dictionary) -> String:
	var row: Array = data.get("row", []) if data.get("row", []) is Array else []
	for i in row.size():
		if row[i] is Dictionary and bool((row[i] as Dictionary).get("is_chooser", false)):
			var standing := int((row[i] as Dictionary).get("standing", 1))
			return PickupUiText.bark(str(data.get("case", "")), str(data.get("reaction", "")), str(data.get("reason", "")),
				PickupUiText.standing_band(standing), i)
	return ""


## The bark stays over the chooser's token for the rest of the event. In idle it shows at once (on the end tile); in the intro it shows
## when the clock reaches the plan's bark time `intro_t`, over the tile the plan says the chooser stands on. It shows once per event,
## chooser and text, so the flip to idle keeps the same popup; a repeat snapshot keeps it too.
func _show_pickup_bark(data: Dictionary, actors: Array, intro_t: float = 0.0) -> void:
	if _bark_popup_layer == null:
		return
	var chooser_id := pickup_chooser_id(data)
	var text := ""
	if str(data.get("phase", "")) != "intro":
		text = pickup_bark_text(data)
	elif bool(_pickup_plan.get("valid", false)) and intro_t >= float((_pickup_plan["bark"] as Dictionary)["t0"]):
		text = str((_pickup_plan["bark"] as Dictionary)["text"])
	if text.is_empty():
		if not _pickup_bark_key.is_empty():
			_bark_popup_layer.clear_all()
			_pickup_bark_key = ""
		return
	var key := "%s|%s|%s" % [PickupEventStage.identity_of(data), chooser_id, text]
	if key == _pickup_bark_key and _bark_popup_layer.has_popup(chooser_id):
		return
	for actor_v in actors:
		if actor_v is Dictionary and str((actor_v as Dictionary).get("id", "")) == chooser_id:
			_bark_popup_layer.show_barks([{ "actor_id": chooser_id, "bark_line": text, "bark_context": "pickup",
				"bark_tier": "", "bark_target_id": "", "bark_priority": 1, "is_response": false, "persist": true,
				"screen_pos": _actor_screen_pos(actor_v) }])
			_pickup_bark_key = key
			return


static func pickup_chooser_id(data: Dictionary) -> String:
	for entry_v in data.get("row", []):
		if entry_v is Dictionary and bool((entry_v as Dictionary).get("is_chooser", false)):
			return str((entry_v as Dictionary).get("id", ""))
	return ""


func _leave_pickup() -> void:
	_pickup_intro_on = false
	_pickup_last_pose = {}
	_pickup_skip_left = -1.0
	_pickup_bark_key = ""
	_pickup_snap = {}
	_pickup_plan = {}
	_pickup_plan_identity = ""
	_pickup_legs_started = 0
	_pickup_base_actors = []
	_hide_pickup_mote()
	_speed_bar.visible = true
	_finds_layer.clear()
	_pickup_opener = null
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_pickup_floor_derived = 0.0
	_pickup_fit_cap = INF
	if _pickup_zoom_floor > 0.0:
		_pickup_zoom_floor = 0.0
		var min_zoom := _min_zoom_for_span(_board_span_px)
		camera.configure_zoom_range(min_zoom, _ZOOM_MAX, clampf(camera.zoom.x, min_zoom, _ZOOM_MAX))
	if _pickup_stage.visible:
		_kill_pickup_camera_tween()
		_token_layer.reset_presentation()
		_move_telegraph_layer.clear_telegraph()
		if _bark_popup_layer != null:
			_bark_popup_layer.clear_all()
	_pickup_stage.visible = false
	_pickup_stage.clear()
	if is_instance_valid(_pickup_debug):
		_pickup_debug.apply_actions({})


func _sync_world_visibility() -> void:
	var shown := is_visible_in_tree()
	_world_layer.visible = shown
	camera.enabled = shown
	if not shown:
		_pointer.reset()


# A release lost to a focus change would leave a finger counted or a drag owned, and board pan and
# tap would stay dead. Both notifications are handled; the reset is idempotent.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pointer.reset()


func _reset_transient_ui() -> void:
	_step_timer.stop()
	_pending_dispatch_action = {}

	_board.clear()
	if _bridge_layer != null:
		_bridge_layer.clear()
	_distance_layer.clear_distances()
	_back_button.visible     = false
	_round_label.visible     = false
	_objective_label.visible = false
	_cta_button.visible      = false
	_manual_toggle.visible   = false
	_objective_banner.visible = false
	_nav_back_action         = {}

	_initiative_panel.visible = false
	for child in _initiative_list.get_children():
		child.queue_free()

	_result_overlay.visible = false
	_end_combat_action      = {}

	# UI-004: hide pre-battle panel; reset cached actions.
	_pending_enter_combat_action     = {}
	_pending_retreat_action          = {}

	# Camera reset each snapshot; re-shown by _render when applicable.
	_recenter_button.visible  = false


func _reset_presentation_state() -> void:
	_token_layer.reset_presentation()
	_move_telegraph_layer.clear_telegraph()
	if _bark_popup_layer != null:
		_bark_popup_layer.clear_all()
	_last_bark_line = ""
	_held_barks.clear()
	_pending_row.clear()
	# Fresh encounter → the first pace colour shows with no blend.
	_kill_pace_tween()
	_last_pace_state = ""
	_stall_level = 0
	_stall_bark_done = false
	_kill_stall_tween()
	_stall_panel.visible = false
	# Fresh encounter → FREE camera at default zoom, nothing selected (ANSWERS.md #76).
	_camera_needs_reset = true
	_pointer.reset()


func _should_reset_presentation(data: Dictionary) -> bool:
	var next_encounter_id: String = str(data.get("encounter_id", ""))
	var next_board_size := Vector2i(
		int(data.get("board_cols", 10)),
		int(data.get("board_rows", 10))
	)
	if _active_encounter_id.is_empty():
		# A reload can publish a pickup snapshot with no encounter id; it is the same event, not a new fight, on every repeat.
		return not (_pickup_stage.visible and next_encounter_id.is_empty() and next_board_size == _presentation_board_size)
	if next_encounter_id != _active_encounter_id:
		return true
	return next_board_size != _presentation_board_size

func _render(data: Dictionary, actions: Dictionary) -> void:
	_flush_held_barks()
	_current_cols = int(data.get("board_cols", 10))
	_current_rows = int(data.get("board_rows", 10))
	var terrain_v: Variant = data.get("terrain", {})
	var terrain: Dictionary = terrain_v if terrain_v is Dictionary else {}
	_draw_board(_current_cols, _current_rows, terrain)
	_center_board(_current_cols, _current_rows)

	var actors: Array = data.get("actors", [])
	_last_actors = actors
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
	# V2-STAGE-004 P5: the authored ObjectiveBanner renders all per-mode objective content.
	# The bare _objective_label is retired here — the banner is the single objective surface.
	var obj_state: Dictionary = data.get("objective_state", {})
	var obj_type: String = str(obj_state.get("type", ""))
	_objective_label.visible = false
	_render_objective_banner(obj_state, obj_type)
	_apply_pace_color(str(obj_state.get("pace_state", "")))
	_apply_stall_warning(data)

	# Selection-lock works the same in every objective type — no per-mode camera.
	_push_camera_follow_target()

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
		# Recenter-on-party button shares the same active-combat lifetime on every board.
		_recenter_button.visible = true

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
# V2-STAGE-004 P5: ObjectiveBanner
# -------------------------

## Populates the authored ObjectiveBanner from snapshot.data.objective_state.
## Reads ONLY objective_state fields — no core access. Unknown/missing type hides
## the banner entirely (graceful degradation: old snapshots render as before).
##
## Per-mode content (static instruction text sourced from _objective_instruction_text,
## the single source shared with the pre-battle modal label — see that function's docstring):
##   combat        → "Defeat all enemies"                           (no progress line)
##   purify_shrine → "Purify the shrine"        + "Shrine HP x"
##   recover       → "Hold the relic ground"    + "Hold h/N"
##   protect       → "Protect <entity>"         + "Guard c/N · HP x"; totem_stolen → urgent
##   endure        → "Survive the onslaught"    + "Round r/N · Waves left: w"
##   pursue        → "Contain the quarry"       + "Contain c/N · Window: w" + distance pips
##   guide_spirit  → protect: "Keep <name> calm" / escort: "Guide <name> to safety" (+ "Arrived")
func _render_objective_banner(obj_state: Dictionary, obj_type: String) -> void:
	# Reset transient state each render: neutral tint, hidden pips.
	_objective_banner.modulate = _BANNER_MODULATE_NORMAL
	_banner_quarry_pips.visible = false
	_banner_pressure_marker.visible = false

	var glyph: String       = "◆"
	var instruction: String = ""
	var progress: String    = ""
	var urgent: bool        = false

	match obj_type:
		"combat":
			glyph = "◆"
			instruction = _objective_instruction_text(obj_type, obj_state)
		"purify_shrine":
			glyph = "◆"
			instruction = _objective_instruction_text(obj_type, obj_state)
			progress = "Shrine HP %d" % int(obj_state.get("shrine_hp", 0))
		"recover":
			glyph = "◆"
			instruction = _objective_instruction_text(obj_type, obj_state)
			progress = "Hold %d/%d" % [
				int(obj_state.get("hold_progress", 0)),
				int(obj_state.get("hold_required", 0)),
			]
		"protect":
			glyph = "◆"
			if bool(obj_state.get("totem_stolen", false)):
				instruction = "STOLEN — recover it!"
				urgent = true
			else:
				instruction = _objective_instruction_text(obj_type, obj_state)
			progress = "Guard %d/%d · HP %d" % [
				int(obj_state.get("protect_progress", 0)),
				int(obj_state.get("protect_required", 0)),
				int(obj_state.get("objective_hp", 0)),
			]
		"endure":
			glyph = "◆"
			instruction = _objective_instruction_text(obj_type, obj_state)
			progress = "Round %d/%d · Waves left: %d" % [
				int(obj_state.get("round", 0)),
				int(obj_state.get("rounds_required", 0)),
				int(obj_state.get("waves_remaining", 0)),
			]
		"pursue":
			glyph = "◆"
			instruction = _objective_instruction_text(obj_type, obj_state)
			progress = "Contain %d/%d · Window: %d" % [
				int(obj_state.get("contain_progress", 0)),
				int(obj_state.get("contain_required", 0)),
				int(obj_state.get("window_remaining", 0)),
			]
		"guide_spirit":
			glyph = "◆"
			instruction = _objective_instruction_text(obj_type, obj_state)
			if str(obj_state.get("guide_mode", "protect")) == "escort" \
					and bool(obj_state.get("destination_reached", false)):
				instruction += " — Arrived"
			# HP / rounds detail lives in the EchoBar spirit slot — no duplication here.
		_:
			# Unknown / missing objective type → hide banner, board renders as today.
			_objective_banner.visible = false
			return

	_banner_glyph.text       = glyph
	_banner_instruction.text = instruction
	_banner_progress.text    = progress
	_banner_progress.visible = not progress.is_empty()
	# PURSUE distance pips — rendered after the progress label so the text hint
	# ("· AT EXIT!" / "· closing in") appends to the freshly-set progress string.
	if obj_type == "pursue":
		_render_quarry_pips(int(obj_state.get("quarry_distance_to_exit", 0)))
	# V2-STAGE-004 Phase 4 (S15 UI-B): "Pressure raised" marker — mode-agnostic, gated
	# solely on objective_state.charge_pressure_applied (S15-prep field). Icon+text
	# (Amber), never colour-only.
	_banner_pressure_marker.visible = bool(obj_state.get("charge_pressure_applied", false))
	# Urgent state (PROTECT totem stolen): swap to the pre-authored urgent StyleBox for
	# distinct chrome, plus a red modulate. The instruction text also carries the state
	# ("STOLEN — recover it!") so the signal is never colour-only.
	if urgent:
		_objective_banner.modulate = _BANNER_MODULATE_URGENT
		if _urgent_banner_style != null:
			_objective_banner.add_theme_stylebox_override("panel", _urgent_banner_style)
	else:
		_objective_banner.modulate = _BANNER_MODULATE_NORMAL
		if _normal_banner_style != null:
			_objective_banner.add_theme_stylebox_override("panel", _normal_banner_style)
	_objective_banner.visible = true


## Pace modes only (design §6, decisions.md D-12): colour the round label and the banner's
## glyph and progress line by pace_state. No text is added. No-pace fights keep the authored colour.
## D-28: a change between two pace states blends over the move duration of the current speed.
## A drop (full → partial, partial → none) first brightens the colour once. This runs on every
## actor step, so an unchanged state never restarts the blend.
func _apply_pace_color(pace_state: String) -> void:
	if not PacePresentation.has_pace(pace_state):
		_kill_pace_tween()
		_last_pace_state = ""
		_round_label.add_theme_color_override("font_color", _round_label_color)
		_banner_glyph.add_theme_color_override("font_color", _banner_glyph_color)
		_banner_progress.add_theme_color_override("font_color", _banner_progress_color)
		return
	var target := PacePresentation.color(pace_state, false)
	var previous := _last_pace_state
	_last_pace_state = pace_state
	if pace_state == previous:
		if not is_pace_blend_running():
			_set_pace_label_color(target)
		return
	_kill_pace_tween()
	if previous.is_empty():
		_set_pace_label_color(target)
		return
	var from := _round_label.get_theme_color("font_color")
	_pace_tween = create_tween().set_trans(Tween.TRANS_SINE)
	if PacePresentation.STATES.find(pace_state) > PacePresentation.STATES.find(previous):
		_pace_tween.tween_method(_set_pace_label_color, from,
			from.lerp(Color.WHITE, _PACE_DROP_BRIGHTEN), _PACE_DROP_BRIGHTEN_TIME).set_ease(Tween.EASE_OUT)
		from = from.lerp(Color.WHITE, _PACE_DROP_BRIGHTEN)
	_pace_tween.tween_method(_set_pace_label_color, from, target, _pace_blend_duration()).set_ease(Tween.EASE_IN_OUT)


## True while the pace colour blend runs.
func is_pace_blend_running() -> bool:
	return _pace_tween != null and _pace_tween.is_valid() and _pace_tween.is_running()


## Advances the pace colour blend by `seconds`. Headless tests use this; the game never calls it.
func step_pace_blend(seconds: float) -> void:
	if is_pace_blend_running():
		_pace_tween.custom_step(seconds)


func _set_pace_label_color(c: Color) -> void:
	_round_label.add_theme_color_override("font_color", c)
	_banner_glyph.add_theme_color_override("font_color", c)
	_banner_progress.add_theme_color_override("font_color", c)


## The quiet-fight line under the banner. It follows data.stall_level: it fades in when the level
## rises, and clears at once when progress brings the level back to 0. Info blue, never an alarm colour.
func _apply_stall_warning(data: Dictionary) -> void:
	var level := clampi(int(data.get("stall_level", 0)), 0, 2)
	if level == _stall_level:
		return
	_stall_level = level
	_kill_stall_tween()
	if level == 0:
		_stall_panel.visible = false
		return
	_stall_label.text = StandoffStrings.WARN_LEVEL_1 if level == 1 else StandoffStrings.WARN_LEVEL_2
	_stall_panel.visible = true
	if StopMarkMotion.reduced or not is_inside_tree():
		_stall_panel.modulate.a = 1.0
	else:
		_stall_panel.modulate.a = 0.0
		_stall_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_stall_tween.tween_property(_stall_panel, "modulate:a", 1.0, _STALL_FADE_TIME)
	if level == 2:
		_stall_bark(str(data.get("stall_froze_name", "")))


## One short line from the Echo that froze, through the normal bark layer. No name, no bark.
func _stall_bark(who: String) -> void:
	if _stall_bark_done or who.is_empty() or _bark_popup_layer == null:
		return
	for actor_v in _last_actors:
		if actor_v is Dictionary and str(actor_v.get("name", "")) == who and str(actor_v.get("faction", "")) == "echo":
			_stall_bark_done = true
			_bark_popup_layer.show_barks([{ "actor_id": str(actor_v.get("id", "")), "bark_line": StandoffStrings.WARN_BARK,
				"bark_context": "", "bark_tier": "", "bark_target_id": "", "bark_priority": 3, "is_response": false,
				"screen_pos": _actor_screen_pos(actor_v) }])
			return


func _kill_stall_tween() -> void:
	if _stall_tween != null and _stall_tween.is_valid():
		_stall_tween.kill()
	_stall_tween = null


func _kill_pace_tween() -> void:
	if _pace_tween != null and _pace_tween.is_valid():
		_pace_tween.kill()
	_pace_tween = null


## The blend uses the token move duration of the current playback speed.
func _pace_blend_duration() -> float:
	if is_equal_approx(_step_delay, _SPEED_SLOW):
		return _MOVE_DURATION_SLOW
	if is_equal_approx(_step_delay, _SPEED_FAST):
		return _MOVE_DURATION_FAST
	return _MOVE_DURATION_NORMAL


## Fills the pre-authored diamond pips by quarry proximity to the exit edge.
## Closer to exit (smaller distance) = more urgent = more filled pips + text hint.
## dist is quarry_distance_to_exit (chebyshev-to-edge, 0 = at the exit).
func _render_quarry_pips(dist: int) -> void:
	# Map distance → filled count: 0 tiles ⇒ all 5 filled (max urgency);
	# ≥5 tiles ⇒ 0 filled (safe). Clamped in between.
	var filled: int = clampi(_PIP_COUNT - dist, 0, _PIP_COUNT)
	var pips: Array = _banner_quarry_pips.get_children()
	for i in range(pips.size()):
		var pip := pips[i] as Label
		if pip == null:
			continue
		if i < filled:
			pip.text = _PIP_FILLED
			pip.modulate = _BANNER_MODULATE_URGENT
		else:
			pip.text = _PIP_HOLLOW
			pip.modulate = _BANNER_MODULATE_NORMAL
	# Text hint alongside the colour/shape signal (accessibility: never colour-only).
	if filled >= _PIP_COUNT:
		_banner_progress.text += " · AT EXIT!"
	elif filled >= _PIP_COUNT - 1:
		_banner_progress.text += " · closing in"
	_banner_quarry_pips.visible = true


# -------------------------
# Board rendering
# -------------------------

func _draw_board(cols: int, rows: int, terrain: Dictionary = {}) -> void:
	# Compute walkable set from terrain data.
	# StageTerrain.walkable_set returns {} when terrain is absent/empty — that is
	# the legacy sentinel meaning "all cells walkable".
	var walkable: Dictionary = StageTerrain.walkable_set(terrain)
	# Which cells to PAINT as a bridge (V2-COMBAT-003, decision 16). Load-bearing spans
	# only, plateau ground subtracted — see StageTerrain.bridge_tile_cell_set.
	var bridge_cells: Dictionary = StageTerrain.bridge_tile_cell_set(terrain)

	_board.clear()
	if _bridge_layer != null:
		_bridge_layer.clear()

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
			var cell_v := Vector2i(c, r)
			_board.set_cell(cell_v, _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)
			# A bridge is its own tile: same ground tile underneath, tinted overlay above.
			if _bridge_layer != null and bridge_cells.has(key):
				_bridge_layer.set_cell(cell_v, _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)


func _center_board(cols: int, rows: int) -> void:
	var tl: Vector2 = _board.map_to_local(Vector2i(0,        0       ))
	var tr: Vector2 = _board.map_to_local(Vector2i(cols - 1, 0       ))
	var bl: Vector2 = _board.map_to_local(Vector2i(0,        rows - 1))
	var br: Vector2 = _board.map_to_local(Vector2i(cols - 1, rows - 1))

	var min_x: float = min(tl.x, bl.x)
	var max_x: float = max(tr.x, br.x)
	var min_y: float = min(tl.y, tr.y)
	var max_y: float = max(bl.y, br.y)
	var grid_center := Vector2(
		(min_x + max_x) / 2.0,
		(min_y + max_y) / 2.0
	)
	# Record the true (unscaled) isometric span so the clamp measures both axes correctly.
	# Add one tile of padding so edge cells aren't flush against the clamp boundary.
	_board_span_px = Vector2(
		maxf(max_x - min_x, 1.0) + 128.0,
		maxf(max_y - min_y, 1.0) + 64.0
	)
	_board_root.position = -grid_center
	camera.configure_bounds(_board_span_px)

	if _camera_needs_reset:
		_camera_needs_reset = false
		camera.deselect()
		camera.position = Vector2.ZERO
		camera.configure_zoom_range(_min_zoom_for_span(_board_span_px), _ZOOM_MAX, _ZOOM_DEFAULT)
	camera.reclamp()


## decisions.md #70: the whole board fits the shorter viewport side, with a 10% margin.
func _min_zoom_for_span(span: Vector2) -> float:
	var view := get_viewport_rect().size
	var fit := minf(view.x, view.y) / maxf(maxf(span.x, span.y), 1.0)
	return clampf(fit * _ZOOM_FIT_FACTOR, _ZOOM_MIN_FLOOR, _ZOOM_MIN_CEILING)


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
	var settle: Vector2 = Vector2(1.0, 0.10)  # stop-short motion scale, badge delay

	if is_equal_approx(delay, _SPEED_SLOW):
		move_duration = _MOVE_DURATION_SLOW
		telegraph_duration = _TELEGRAPH_DURATION_SLOW
		settle = Vector2(1.6, 0.20)
	elif is_equal_approx(delay, _SPEED_FAST):
		move_duration = _MOVE_DURATION_FAST
		telegraph_duration = _TELEGRAPH_DURATION_FAST
		settle = Vector2(0.0, 0.05)

	if _token_layer != null and _token_layer.visual_config != null:
		_token_layer.visual_config.move_duration = move_duration
		_token_layer.visual_config.telegraph_lead_time = telegraph_duration
		_token_layer.visual_config.motion_scale = settle.x
		_token_layer.visual_config.badge_delay = settle.y
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
	# Continue ends the event: the held Resolve card opens over this board, which stays mounted. The event takes no more input and its card closes.
	if str(action.get("type", "")) == "pickup.continue":
		_pickup_ended = true
		_pickup_stage.card().hide_card()
		_finds_layer.set_focus_index(-1)
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

	var last_actor_action: Dictionary = data.get("last_actor_action", {})
	_step_actor_id = str(last_actor_action.get("source_id", ""))
	_step_stop_short = last_actor_action.get("stop_short", {}) as Dictionary
	var step_shown: bool = bool(_step_stop_short.get("performed", false))
	var hop_lift: float = stop_short_hop_lift(
		str(_step_stop_short.get("benefit", "")),
		is_actor_selected(camera.mode, camera.target_id, _step_actor_id), step_shown,
		camera.zoom.x, _token_layer.visual_config.motion_scale)

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

		var descriptor := {
			"actor_id":           actor_id,
			"grid_pos":           gp.duplicate(),
			"cell_pos":           cell_center,
			"faction":            str(actor.get("faction", "")),
			"is_structure":       bool(actor.get("is_structure", false)),
			"is_objective_relic": bool(actor.get("is_objective_relic", false)),
			"is_quarry":          bool(actor.get("is_quarry", false)),
			"is_spirit":          bool(actor.get("is_spirit", false)),
			# V2-STAGE-004 Phase 4 (S15 UI-B): joined-ally token ring — mirrors is_spirit.
			"is_ally":            bool(actor.get("is_ally", false)),
			"label":              str(actor.get("name", "??")).substr(0, 2).to_upper(),
			"hp_ratio":           hp_ratio,
			"damage_text":        damage_by_id.get(actor_id, ""),
			"emotional_status":   str(actor.get("emotional_status", "")),
			"status":             str(actor.get("status", "")),
			"mark_kind":          str(actor.get("mark_kind", "")),
			"hop_lift":           hop_lift if step_shown and actor_id == _step_actor_id else 0.0,
			"cause_badge":        stop_short_badge(_step_stop_short) if step_shown and actor_id == _step_actor_id else "",
			"observe_target":     str(_step_stop_short.get("subject_actor_id", "")) if step_shown and actor_id == _step_actor_id and str(_step_stop_short.get("benefit", "")) == "observe" else "",
		}
		# The pickup chooser's walk time (a leg of the plan). Absent in combat: the layer then reads the speed-bar duration.
		if actor.has("move_duration"):
			descriptor["move_duration"] = float(actor["move_duration"])
		if actor.has("move_ease"):
			descriptor["move_ease"] = float(actor["move_ease"])
		tokens.append(descriptor)

	var telegraph_event: Dictionary = _token_layer.apply_snapshot(
		tokens,
		current_actor_id,
		last_actor_action,
		_move_path_cell_positions(last_actor_action)
	)
	if telegraph_event.is_empty():
		_move_telegraph_layer.clear_telegraph()
	else:
		_move_telegraph_layer.show_move_telegraph(telegraph_event)

## V2-COMBAT-002 Slice 6D: converts `last_actor_action.path` (cells ENTERED, origin
## excluded, MAY be empty) into board-local cell centres through the very same
## `_board.map_to_local()` call that produces each token's `cell_pos`. Reusing that
## call is what makes a waypoint for cell X pixel-identical to the token draw position
## for cell X. Not filtered by action_type: a move-then-melee activation reports the
## MELEE entry, and that entry still carries the traversed path.
func _move_path_cell_positions(last_actor_action: Dictionary) -> Array[Vector2]:
	var cell_positions: Array[Vector2] = []
	if _board == null:
		return cell_positions
	for cell_v in last_actor_action.get("path", []):
		if cell_v is Dictionary:
			var cell: Dictionary = cell_v
			cell_positions.append(
				_board.map_to_local(Vector2i(int(cell.get("col", 0)), int(cell.get("row", 0))))
			)
	return cell_positions


# V2-VOICE-002: Assembles new bark events for this snapshot and passes them to
# _bark_popup_layer.show_barks(). Called every render; only actors with a non-empty
# bark_line produce an event (bark is consumed on first projection in FlowEncounterState).
#
# The budget — how many barks a round may show, and their tier order — is applied upstream by
# NarrativeVoiceService.apply_round_bark_budget() from data.voice. Rows arriving here are
# already the survivors, ranked by bark_priority (1 = most significant). This function only
# orders and interleaves them; it must not reintroduce a cap or a tier table of its own.
# Originals shown immediately; reactions shown after REACTION_DELAY (in BarkPopupLayer).
func _show_bark_popups(actors: Array, _data: Dictionary) -> void:
	if _bark_popup_layer == null:
		return

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
			"bark_priority": int(actor.get("bark_priority", 3)),
			"is_response":   bool(actor.get("bark_is_response", false)),
			"screen_pos":    screen_pos,
		}
		if ev["is_response"]:
			reactions.append(ev)
		else:
			originals.append(ev)

	# Sort by the upstream priority (1 = highest, shown first).
	originals.sort_custom(func(a, b):
		return int(a.get("bark_priority", 3)) < int(b.get("bark_priority", 3))
	)

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
		# The stop-short Echo's own bark waits for the settle; a settled token shows it now.
		var held: Array = deduped.filter(func(ev: Dictionary) -> bool:
			return bool(_step_stop_short.get("performed", false)) and str(ev.get("actor_id", "")) == _step_actor_id and not _token_layer.is_settled(_step_actor_id))
		_held_barks.append_array(held)
		_bark_popup_layer.show_barks(deduped.filter(func(ev: Dictionary) -> bool: return not held.has(ev)))


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


# Converts an actor's grid_pos to BarkPopupLayer local space. The bark layer does not follow the
# camera, so bubbles keep a readable size at any zoom; the path goes through viewport space.
func _actor_screen_pos(actor: Dictionary) -> Vector2:
	var gp: Dictionary = actor.get("grid_pos", {})
	var cell_pos: Vector2 = _board.map_to_local(Vector2i(gp.get("col", 0), gp.get("row", 0)))
	var viewport_pos: Vector2 = _board.get_global_transform_with_canvas() * cell_pos
	return _bark_popup_layer.get_global_transform_with_canvas().affine_inverse() * viewport_pos


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
	var stop_row_ids: Dictionary = {}
	_pending_row.clear()
	for result_v in data.get("action_results", []):
		if result_v is Dictionary:
			var sid: String = str(result_v.get("source_id", ""))
			if not sid.is_empty():
				action_by_id[sid] = _format_action(result_v)
				if bool((result_v.get("stop_short", {}) as Dictionary).get("performed", false)):
					stop_row_ids[sid] = true

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
		# Stop-short step still settling: plain move word now, benefit word at actor_settled.
		var shown_text: String = action_text
		if actor_id == _step_actor_id and stop_row_ids.has(actor_id) and not _token_layer.is_settled(actor_id):
			shown_text = "Moves"
			_pending_row[actor_id] = { "row": row, "args": [actor_name, action_text, i == active_idx, is_dead, _action_color_for_text(action_text)] }
		row.call(
			"setup_row",
			actor_name,
			shown_text,
			i == active_idx,
			is_dead,
			_action_color_for_text(shown_text)
		)
		row.call("set_actor_id", actor_id)
		row.connect("row_pressed", select_board_target)
		# V2-EMOTION-002: set unified emotional status per actor row.
		var actor_d: Dictionary = actor_by_id.get(actor_id, {})
		var emotion_str: String = str(actor_d.get("emotional_status", ""))
		var emotion_label := row.get_node("%EmotionLabel") as Label
		emotion_label.text = EmotionPresentation.display_name(emotion_str)
		emotion_label.theme_type_variation = EmotionPresentation.text_theme(emotion_str)
		emotion_label.visible = not emotion_str.is_empty() and not stop_row_ids.has(actor_id)

	_initiative_panel.visible = true



func _on_actor_settled(actor_id: String) -> void:
	if actor_id != _step_actor_id or not bool(_step_stop_short.get("performed", false)):
		return
	var pending: Dictionary = _pending_row.get(actor_id, {})
	_pending_row.erase(actor_id)
	var stopped: Dictionary = _find_actor(actor_id)
	if not stopped.is_empty():
		_move_telegraph_layer.show_settle_diamond(_board.map_to_local(_actor_cell(stopped)), _step_stop_short)
	if not pending.is_empty() and is_instance_valid(pending["row"]):
		(pending["row"] as Node).callv("setup_row", pending["args"])
	# Selected: the bubble replaces the bark. Unselected: the held bark shows.
	if is_actor_selected(camera.mode, camera.target_id, actor_id):
		_held_barks.clear()
		_show_stop_short_bubble(actor_id)
	else:
		_flush_held_barks()


func _flush_held_barks() -> void:
	if _bark_popup_layer != null:
		for ev: Dictionary in _held_barks:
			var actor: Dictionary = _find_actor(str(ev.get("actor_id", "")))
			if not actor.is_empty():
				ev["screen_pos"] = _actor_screen_pos(actor)
				_bark_popup_layer.show_barks([ev])
	_held_barks.clear()


func _show_stop_short_bubble(actor_id: String) -> void:
	var actor: Dictionary = _find_actor(actor_id)
	if _bark_popup_layer == null or actor.is_empty():
		return
	_bark_popup_layer.show_barks([{
		"actor_id": actor_id, "bark_line": stop_short_reason(_step_stop_short),
		"bark_context": "stop_short_reason", "bark_tier": "", "bark_target_id": "",
		"bark_priority": 1, "is_response": false, "screen_pos": _actor_screen_pos(actor),
	}])


## Selected = the camera is locked on this actor (read at the moment of use, never stored).
static func is_actor_selected(camera_mode: int, camera_target_id: String, actor_id: String) -> bool:
	return camera_mode == BoardCameraController.Mode.FOLLOW_ACTOR and camera_target_id == actor_id


## World-unit lift of the notice hop: none when selected, not performed, or at Fast (motion scale 0).
## The marker and the rest pose still show then.
static func stop_short_hop_lift(benefit: String, selected: bool, performed: bool, zoom_x: float, motion_scale: float) -> float:
	if selected or not performed or motion_scale <= 0.0:
		return 0.0
	return StopShortMotion.hop_lift(benefit, zoom_x)


static func stop_short_badge(stop_short: Dictionary) -> String:
	var args: Dictionary = (stop_short.get("trace", {}) as Dictionary).get("message_args", {})
	match str(args.get("source", "")):
		"emotion":
			return "fear"
		"calling", "vector":
			return "identity"
	return ""


static func stop_short_reason(stop_short: Dictionary) -> String:
	var args: Dictionary = (stop_short.get("trace", {}) as Dictionary).get("message_args", {})
	return StopShortText.reason_line(str(stop_short.get("benefit", "")), str(args.get("code", "")))


## Formats an action_result entry into a short display string for the initiative panel.
func _format_action(result: Dictionary) -> String:
	var atype: String = str(result.get("action_type", ""))
	var tname: String = str(result.get("target_name", ""))
	var stop_short: Dictionary = result.get("stop_short", {}) as Dictionary
	if bool(stop_short.get("performed", false)):
		return StopShortText.row_word(str(stop_short.get("benefit", "")))
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
		"actor.observe":
			return StopShortText.row_word("observe")
		"actor.dead":
			return ""
	return atype


## Returns an appropriate colour for an action text string (used on the active row).
func _action_color_for_text(action_text: String) -> Color:
	if action_text.begins_with("Kills"):
		return Color.RED
	if action_text.begins_with("Attacks"):
		return Color.ORANGE
	if action_text == "Guards" or action_text in [StopShortText.row_word("guard"), StopShortText.row_word("hold")]:
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
	# The pre-battle step is rendered by AppRoot's ModalHost (realm.prebattle), not in this
	# scene. This function only assembles the payload.
	_round_label.visible     = false
	_objective_label.visible = false

	var obj_state: Dictionary = data.get("objective_state", {})
	var objective_label := _format_objective_label(obj_state)

	# V2-STAGE-004 Phase 4 (S15 UI-B): claimant-forced combat intro line — snapshot-driven,
	# never hard-coded. "" (not a claimant-forced fight) means no intro line.
	var intro_line: String = str(data.get("combat_intro_line", ""))

	# Enter Combat — always offered; the action decides whether it is available.
	_pending_enter_combat_action = actions.get("cta.combat_init", {})

	# Retreat — offered only when eligible.
	var retreat_enabled: bool = false
	var retreat_label: String = "Retreat is not possible"
	var retreat_eligible: bool = bool(data.get("retreat_eligible", false))
	# A missing key reads as affordable: only the pre-combat snapshot carries it.
	var retreat_affordable: bool = bool(data.get("retreat_affordable", true))
	var ase_cost: int = int(data.get("retreat_ase_cost", 0))
	if retreat_eligible and actions.has("cta.retreat"):
		_pending_retreat_action = actions["cta.retreat"]
		if not retreat_affordable:
			# Disabled, and the reason is in the text as well as the state (not colour alone).
			retreat_label = CarriedHomePresentation.retreat_label(ase_cost, CarriedHomePresentation.RETREAT_UNAFFORDABLE)
		else:
			retreat_enabled = true
			retreat_label = CarriedHomePresentation.retreat_label(ase_cost)
	else:
		_pending_retreat_action = {}

	var denied_v: Variant = data.get("retreat_denied", {})
	modal_requested.emit(&"realm.prebattle", {
		"objective_label": objective_label,
		"intro_line": intro_line,
		"enter_action": _pending_enter_combat_action.duplicate(true),
		"retreat_action": _pending_retreat_action.duplicate(true),
		"retreat_enabled": retreat_enabled,
		"retreat_label": retreat_label,
		"stalled_before": bool(data.get("stalled_before", false)),
		"retreat_denied": (denied_v as Dictionary).duplicate(true) if denied_v is Dictionary else {},
	})

## Maps objective type string to a player-facing label for the pre-battle modal.
## Delegates all static wording to _objective_instruction_text — the single source shared
## with the live ObjectiveBanner (_render_objective_banner) — so the two surfaces cannot
## drift out of sync again. This function ONLY adds the unknown-type fallback; it applies
## no dynamic combat-state overrides (no STOLEN branch, no "Arrived" suffix) because a
## pre-battle modal must never show live combat state.
static func _format_objective_label(obj_state: Dictionary) -> String:
	var obj_type: String = str(obj_state.get("type", ""))
	var text := _objective_instruction_text(obj_type, obj_state)
	return text if not text.is_empty() else "[Battle objective]"


## Single source of truth for the STATIC objective instruction text shown on both the
## pre-battle modal (_format_objective_label) and the live ObjectiveBanner
## (_render_objective_banner). Pure string logic: no Node/scene access, callable headless.
##
## Returns "" for an unrecognised obj_type; callers apply their own fallback.
##
## Per-mode text:
##   combat        → "Defeat all enemies"
##   purify_shrine → "Purify the shrine"
##   pursue        → "Contain the quarry"
##   recover       → "Hold the relic ground"
##   endure        → "Survive the onslaught"
##   protect       → "Protect <entity_name>", or "Protect the totem" when entity_name is empty
##   guide_spirit  → escort: "Guide <spirit_name> to safety"; protect: "Keep <spirit_name> calm";
##                   falls back to "the spirit" when spirit_name is empty
##
## Dynamic overrides (STOLEN, "— Arrived") are NOT part of this function — they live only in
## _render_objective_banner, which reacts to live combat state a pre-battle modal must never show.
static func _objective_instruction_text(obj_type: String, obj_state: Dictionary) -> String:
	match obj_type:
		"combat":
			return "Defeat all enemies"
		"purify_shrine":
			return "Purify the shrine"
		"pursue":
			return "Contain the quarry"
		"recover":
			return "Hold the relic ground"
		"endure":
			return "Survive the onslaught"
		"protect":
			var entity_name: String = str(obj_state.get("entity_name", ""))
			return "Protect %s" % entity_name if not entity_name.is_empty() else "Protect the totem"
		"guide_spirit":
			var spirit_name: String = str(obj_state.get("spirit_name", ""))
			var who: String = spirit_name if not spirit_name.is_empty() else "the spirit"
			# guide_mode is a seeded 50/50 per encounter (EncounterObjectiveSpawnService):
			# "escort" walks the spirit to a destination, "protect" holds it in place.
			# The two win conditions differ, so the instruction must too.
			if str(obj_state.get("guide_mode", "protect")) == "escort":
				return "Guide %s to safety" % who
			return "Keep %s calm" % who
	return ""


# -------------------------
# Board camera (ANSWERS.md #74-79, decisions.md #70-72): real Camera2D, universal selection-lock
# -------------------------

func _process(delta: float) -> void:
	if _pickup_skip_left >= 0.0:
		_step_pickup_skip_fade(delta)
	if _pickup_active() and _pickup_stage.card().is_open():
		_update_pickup_card(false)
	# A locked actor's token animates between cells, so the target follows the drawn token each frame.
	if camera.mode == BoardCameraController.Mode.FOLLOW_ACTOR and is_visible_in_tree():
		_push_camera_follow_target()
	# Bark bubbles are screen-space, so they follow their tokens only if re-anchored on camera moves.
	if _bark_popup_layer == null or _last_actors.is_empty() or not is_visible_in_tree():
		return
	var xform := get_viewport().get_canvas_transform()
	if xform == _last_canvas_xform:
		return
	_last_canvas_xform = xform
	_update_bark_positions(_last_actors)


## Locks the camera onto one actors-array entry. Echoes, enemies, spirits and structures are all
## entries in that array, so one path covers every target type in every objective mode.
## Public: RealmShell forwards echo-card taps here.
## The pickup event ignores it, so its camera stays FREE (D-73).
func select_board_target(actor_id: String) -> void:
	if is_instance_valid(_pickup_stage) and _pickup_stage.visible:
		return
	var actor := _find_actor(actor_id)
	if actor.is_empty() or _actor_is_dead(actor):
		return
	camera.select(actor_id)
	_push_camera_follow_target()
	if actor_id == _step_actor_id and bool(_step_stop_short.get("performed", false)) and _token_layer.is_settled(actor_id):
		_show_stop_short_bubble(actor_id)


## Pushes the lock target for the current camera mode. Called on select and on every snapshot, so
## a locked camera starts moving at once even in Manual mode, where snapshots can be far apart.
func _push_camera_follow_target() -> void:
	match camera.mode:
		BoardCameraController.Mode.FOLLOW_ACTOR:
			var actor := _find_actor(camera.target_id)
			if actor.is_empty() or _actor_is_dead(actor):
				# ANSWERS.md #78: when the locked actor dies or leaves, the camera follows the party.
				camera.follow_party()
				camera.set_follow_target_local(_party_centroid_world())
				return
			camera.set_follow_target_local(_actor_follow_world_pos(actor))
		BoardCameraController.Mode.FOLLOW_PARTY:
			camera.set_follow_target_local(_party_centroid_world())


func _find_actor(actor_id: String) -> Dictionary:
	for actor_v in _last_actors:
		if actor_v is Dictionary and str(actor_v.get("id", "")) == actor_id:
			return actor_v
	return {}


static func _actor_cell(actor: Dictionary) -> Vector2i:
	var gp: Dictionary = actor.get("grid_pos", {})
	return Vector2i(int(gp.get("col", 0)), int(gp.get("row", 0)))


static func _actor_is_dead(actor: Dictionary) -> bool:
	return str(actor.get("status", "")) == "dead" or bool(actor.get("is_dead", false))


# In the camera's parent space (WorldLayer), which is where camera.position lives.
func _actor_world_pos(actor: Dictionary) -> Vector2:
	return _board.to_global(_board.map_to_local(_actor_cell(actor)))


## Where the locked actor's token is drawn now, in world space. At rest it is the cell centre. While the
## token animates (a move, or the telegraph delay before it) it is the drawn position, so the camera
## never gets ahead of the token.
func _actor_follow_world_pos(actor: Dictionary) -> Vector2:
	var drawn := _token_layer.display_cell_position(str(actor.get("id", "")))
	if drawn == Vector2.INF:
		return _actor_world_pos(actor)
	return _board.to_global(drawn)


## Centroid of the living party. With no living echo, the board centre (world origin).
func _party_centroid_world() -> Vector2:
	var sum := Vector2.ZERO
	var count: int = 0
	for actor_v in _last_actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("faction", "")) != "echo" or _actor_is_dead(actor):
			continue
		sum += _actor_world_pos(actor)
		count += 1
	return sum / float(count) if count > 0 else Vector2.ZERO


func _cell_at_viewport_point(viewport_point: Vector2) -> Vector2i:
	return _board.local_to_map(_board.get_global_transform_with_canvas().affine_inverse() * viewport_point)


## The actors on a cell, living first. A dead actor cannot be locked, so a living one always wins.
func _actors_on_cell(cell: Vector2i) -> Array:
	var living: Array = []
	var dead: Array = []
	for actor_v in _last_actors:
		if not (actor_v is Dictionary) or str(actor_v.get("id", "")).is_empty():
			continue
		if _actor_cell(actor_v) != cell:
			continue
		if _actor_is_dead(actor_v):
			dead.append(actor_v)
		else:
			living.append(actor_v)
	return living + dead


# Empty board releases the camera to FREE (ANSWERS.md #76), not to a party follow. A cell that
# holds only dead actors changes nothing: a dead actor cannot be locked (ANSWERS.md #78).
func _on_board_tap(viewport_point: Vector2) -> void:
	if _pickup_active():
		_on_pickup_tap(viewport_point)
		return
	var on_cell := _actors_on_cell(_cell_at_viewport_point(viewport_point))
	if on_cell.is_empty():
		camera.deselect()
	elif not _actor_is_dead(on_cell[0]):
		select_board_target(str(on_cell[0].get("id", "")))


# Board tap and drag (mouse button + touch), tracked by BoardPointerTracker.
#
# ROUTING NOTE: this MUST live in _gui_input, not _unhandled_input. The screen root is a
# full-rect Control with the default mouse_filter = STOP, so it consumes button/touch/motion
# events as GUI input before they ever reach _unhandled_input. Child Buttons, panels and
# initiative rows sit above it in the pick order and consume their own presses first, so this
# only sees presses on open board. Pinch and two-finger pan are not handled here; they reach
# BoardCameraController._unhandled_input.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _pickup_active():
		var over := _pickup_find_at(get_global_transform_with_canvas() * (event as InputEventMouseMotion).position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over >= 0 else Control.CURSOR_ARROW
	if _pointer.handle_event(event):
		accept_event()


## Counts fingers for the pinch rule. Never marks the event handled, so rows, cards and buttons
## still get their taps.
func _input(event: InputEvent) -> void:
	_pointer.note_touch(event)
	if _pickup_active():
		_pickup_input(event)


## The pickup event is on show, this board is visible in the tree and Continue was not sent (a hidden board or an ended event takes no pickup input).
func _pickup_active() -> bool:
	return is_instance_valid(_pickup_stage) and _pickup_stage.visible and is_visible_in_tree() and not _pickup_ended


## The half size of a find on screen in px: the drawn find, but never under half the 48 px target. The hit test and the card anchor use it.
func _pickup_find_half() -> float:
	return maxf(_finds_layer.bed() * _finds_layer.get_global_transform_with_canvas().get_scale().x * 0.5, PickupHitRules.TARGET * 0.5)


## The mark under a viewport point that can be selected now, or -1. Only a selectable find counts, so the cursor and the tap agree.
func _pickup_find_at(viewport_point: Vector2) -> int:
	var i := PickupHitRules.hit(viewport_point, _finds_layer.screen_centers(), _pickup_find_half())
	if i < 0 or not PickupHitRules.can_select(_pickup_phase(), "find", _finds_layer.status_at(i)):
		return -1
	return i


func _pickup_phase() -> String:
	return str((_pickup_snap.get("data", {}) as Dictionary).get("phase", ""))


func _pickup_selected_id() -> String:
	return str(PickupHitRules.selection(_pickup_snap.get("data", {}) as Dictionary).get("id", ""))


## A tap in the event: a find that can be selected opens its card (a second tap closes it). Any other tap, on open board or on an Echo,
## closes an open card and does nothing else (D-73). The camera is never released here.
func _on_pickup_tap(viewport_point: Vector2) -> void:
	_pickup_key_input = false
	_finds_layer.set_focus_index(-1)
	var i := _pickup_find_at(viewport_point)
	if i >= 0:
		_pickup_choose_find(i)
	elif not _pickup_selected_id().is_empty():
		action_requested.emit(PickupHitRules.close_action())


func _pickup_choose_find(index: int) -> void:
	var id := _finds_layer.find_id_at(index)
	action_requested.emit(PickupHitRules.close_action() if id == _pickup_selected_id() else PickupHitRules.select_action("find", id))


## Keyboard and pad. Focus enters only after a key or a joypad button press: Tab, or the D-pad right or down (`ui_right`, `ui_down`), with no
## focus owner. The marks are reached by `_finds_layer.focus_index` (they are no Controls in the focus tree); the strip and the buttons use the
## engine focus. Tab order: finds, tokens, slots, buttons. A Control outside the pickup event that owns the focus (the F1 debug field)
## keeps all keys. The sticks (`InputEventJoypadMotion`) are not read.
func _pickup_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_pickup_key_input = false
		_finds_layer.set_focus_index(-1)
		return
	if not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed() or event.is_echo():
		return
	var owner_control := get_viewport().gui_get_focus_owner()
	if owner_control != null and not _pickup_owns_focus(owner_control):
		return
	_pickup_key_input = true
	if _pickup_phase() != "idle":
		return
	var at := _finds_layer.focus_index()
	var step := 0
	# Shift+Tab also matches ui_focus_next (the match ignores extra modifiers), so the backward action is read first.
	if event.is_action_pressed("ui_focus_prev") or (at >= 0 and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"))):
		step = -1
	elif event.is_action_pressed("ui_focus_next") or ((at >= 0 or owner_control == null) and (event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"))):
		step = 1
	var targets := _pickup_stage.pack_strip().focus_targets()
	var count := _finds_layer.mark_count()
	if at >= 0 and event.is_action_pressed("ui_accept"):
		_pickup_opener = at
		_pickup_choose_find(at)
		get_viewport().set_input_as_handled()
	elif step == 0:
		return
	elif at >= 0:
		var next := at + step
		if next >= 0 and next < count:
			_finds_layer.set_focus_index(next)
		else:
			_finds_layer.set_focus_index(-1)
			_pickup_focus_end(step, targets)
		get_viewport().set_input_as_handled()
	elif owner_control == null:
		# Entry: the first find on the ground, else the Continue button.
		if count > 0:
			_finds_layer.set_focus_index(0 if step > 0 else count - 1)
		else:
			_pickup_focus_end(-1, targets)
		get_viewport().set_input_as_handled()
	elif step < 0 and count > 0 and not targets.is_empty() and owner_control == targets[0]:
		owner_control.release_focus()
		_finds_layer.set_focus_index(count - 1)
		get_viewport().set_input_as_handled()
	elif step > 0 and count > 0 and owner_control == _pickup_last_target(targets):
		# Forward from the last target wraps to the first find.
		owner_control.release_focus()
		_finds_layer.set_focus_index(0)
		get_viewport().set_input_as_handled()


## True for a Control that belongs to the pickup event: the stage (strip, card) or the debug buttons.
func _pickup_owns_focus(control: Control) -> bool:
	return _pickup_stage.is_ancestor_of(control) or (is_instance_valid(_pickup_debug) and _pickup_debug.is_ancestor_of(control))


## The last focus target: the Continue button while it shows, else the last pack tile.
func _pickup_last_target(targets: Array[Control]) -> Control:
	if is_instance_valid(_pickup_debug) and _pickup_debug.visible and _pickup_debug.continue_button().visible:
		return _pickup_debug.continue_button()
	return targets[targets.size() - 1] if not targets.is_empty() else null


## Leaves the marks: forward to the first token, back to the Continue button (else the last tile).
func _pickup_focus_end(step: int, targets: Array[Control]) -> void:
	if step > 0:
		if not targets.is_empty():
			targets[0].grab_focus()
	elif not (is_instance_valid(_pickup_debug) and _pickup_debug.focus_continue()) and not targets.is_empty():
		targets[targets.size() - 1].grab_focus()


## Shows, moves or closes the details card. `from_snapshot` is true when a new snapshot arrived: the card then takes the selected row.
## Every frame it follows its item; an item that left the screen closes the card (B11).
func _update_pickup_card(from_snapshot: bool) -> void:
	var card := _pickup_stage.card()
	var sel := PickupHitRules.selection(_pickup_snap.get("data", {}) as Dictionary)
	if from_snapshot:
		if sel.is_empty():
			_close_pickup_card()
			return
		var fresh := card.current_id() != str(sel["id"])
		card.show_selection(sel)
		if fresh:
			# A card that opens or switches item replaces the opener: a find the keyboard chose keeps it, a pack tile takes it, a mouse tap clears it.
			if not _pickup_key_input:
				_pickup_opener = null
			elif str(sel["side"]) == "pack":
				_pickup_opener = get_viewport().gui_get_focus_owner()
		if fresh and _pickup_key_input:
			_finds_layer.set_focus_index(-1)
			card.close_button().grab_focus()
	if not card.is_open():
		return
	var anchor := _pickup_anchor_rect(sel)
	if anchor.size == Vector2.ZERO or not get_viewport_rect().has_point(anchor.get_center()):
		if not _pickup_close_sent:
			_pickup_close_sent = true
			action_requested.emit(PickupHitRules.close_action())
		return
	var pack := str(sel["side"]) == "pack"
	# A pack card sits close above its tile, over the strip header (Jeff, D-84 n); the strip only tells which tile is first or last.
	var slot := _pickup_stage.pack_strip().slot_index_of_pack(str(sel["id"])) if pack else -1
	card.place(anchor, _pickup_usable_rect(), _pickup_obstacles(str(sel["id"]), pack), "pack" if pack else "find",
		not pack or _pickup_stage.pack_strip().is_first_slot(slot), not pack or _pickup_stage.pack_strip().is_last_slot(slot))


## Where the card may lie: the viewport inside the safe insets and a 16 px margin, above the EchoBar.
func _pickup_usable_rect() -> Rect2:
	var view := get_viewport_rect()
	var insets: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	var bottom := _echo_bar_top()
	if is_nan(bottom):
		bottom = view.end.y - ceilf(insets.w) - _ECHO_BAR_HEIGHT
	# The 16 unit safe zone of ui/AGENTS.md.
	var margin := 16.0
	var left := view.position.x + ceilf(insets.x) + margin
	var top := view.position.y + ceilf(insets.y) + margin
	return Rect2(left, top, view.end.x - ceilf(insets.z) - margin - left, bottom - margin - top)


## What the card should not cover, in screen px. A find card: the Echo tokens as drawn now, the other finds, the pack strip with its tokens,
## the EchoBar, the debug buttons and the bark popups (weighted by `PickupDetailsPlan.BARK_WEIGHT`); `own_find` is its find id. A pack card
## covers the board, the barks and the strip header on purpose (Jeff, D-84 n, D-86 g): only the EchoBar and the debug buttons count.
func _pickup_obstacles(own_find: String, pack_card: bool = false) -> Array:
	var out: Array = []
	if not pack_card:
		var xf := _token_layer.get_global_transform_with_canvas()
		var radius: float = _token_layer.visual_config.token_radius * xf.get_scale().x
		for actor_v in _last_actors:
			var id := str((actor_v as Dictionary).get("id", ""))
			var at := _token_layer.display_cell_position(id)
			if at != Vector2.INF:
				var c := xf * (at + Vector2(0.0, _token_layer.visual_config.feet_offset_y))
				out.append(PickupDetailsPlan.obstacle(Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0)))
		var centers := _finds_layer.screen_centers()
		var half := _pickup_find_half()
		for i in centers.size():
			if _finds_layer.find_id_at(i) != own_find:
				out.append(PickupDetailsPlan.obstacle(Rect2((centers[i] as Vector2) - Vector2(half, half), Vector2(half, half) * 2.0)))
		out.append(PickupDetailsPlan.obstacle(_pickup_stage.pack_strip().panel_global_rect()))
	var bar := _echo_bar_top()
	if not is_nan(bar):
		out.append(PickupDetailsPlan.obstacle(Rect2(get_viewport_rect().position.x, bar, get_viewport_rect().size.x, get_viewport_rect().end.y - bar)))
	if is_instance_valid(_pickup_debug) and _pickup_debug.visible:
		out.append(PickupDetailsPlan.obstacle(_pickup_debug.get_global_rect()))
	if _bark_popup_layer != null and not pack_card:
		for r in _bark_popup_layer.popup_rects():
			out.append(PickupDetailsPlan.obstacle(r, PickupDetailsPlan.BARK_WEIGHT))
	return out


func _close_pickup_card() -> void:
	var card := _pickup_stage.card()
	var had_focus := card.close_button().has_focus()
	card.hide_card()
	if had_focus:
		if typeof(_pickup_opener) == TYPE_INT:
			_finds_layer.set_focus_index(int(_pickup_opener))
		elif _pickup_opener is Control and is_instance_valid(_pickup_opener):
			(_pickup_opener as Control).grab_focus()
	_pickup_opener = null


## The screen rect of the selected item, or an empty rect when it has none on screen.
func _pickup_anchor_rect(sel: Dictionary) -> Rect2:
	if sel.is_empty():
		return Rect2()
	if str(sel["side"]) == "find":
		var i := _finds_layer.index_of_find(str(sel["id"]))
		if i < 0:
			return Rect2()
		var half := _pickup_find_half()
		return Rect2(_finds_layer.screen_centers()[i] - Vector2(half, half), Vector2(half, half) * 2.0)
	var slot := _pickup_stage.pack_strip().slot_index_of_pack(str(sel["id"]))
	return _pickup_stage.pack_strip().slot_global_rect(slot) if slot >= 0 else Rect2()


func _on_pointer_tap(pos: Vector2) -> void:
	_on_board_tap(get_global_transform_with_canvas() * pos)


## Recenter button: follow the living party's centroid until the player selects or taps away.
func _on_recenter_pressed() -> void:
	camera.follow_party()
	_push_camera_follow_target()

func _apply_responsive_layout() -> void:
	var insets: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	var top := float(ceilf(insets.y))
	var right := float(ceilf(insets.z))
	var bottom := float(ceilf(insets.w)) + _ECHO_BAR_HEIGHT
	_back_button.offset_top = 16.0 + top
	_back_button.offset_bottom = _back_button.offset_top + 48.0
	_round_label.offset_top = 16.0 + top
	_round_label.offset_bottom = 48.0 + top
	_objective_banner.offset_top = 68.0 + top
	_stall_panel.offset_top = 140.0 + top
	_stall_panel.offset_bottom = 176.0 + top
	_recenter_button.offset_left = -64.0 - right
	_recenter_button.offset_right = -16.0 - right
	_recenter_button.offset_top = 16.0 + top
	_recenter_button.offset_bottom = 64.0 + top
	_cta_button.offset_top = -bottom - 56.0
	_cta_button.offset_bottom = -bottom - 8.0
	_manual_toggle.offset_top = -bottom - 112.0
	_manual_toggle.offset_bottom = -bottom - 64.0
	# `$SpeedBar` here, not `_speed_bar`: layout runs before _ready in some tests (Stage004SeamTests wires the nodes by hand).
	var speed_bar := $SpeedBar as HBoxContainer
	speed_bar.offset_top = -bottom - 168.0
	speed_bar.offset_bottom = -bottom - 120.0
	if is_instance_valid(_pickup_debug):
		_pickup_debug.offset_top = -bottom - 56.0
		_pickup_debug.offset_bottom = -bottom - 8.0
	_initiative_panel.offset_top = 150.0 + top
	_initiative_panel.offset_bottom = -bottom - 62.0
	if is_instance_valid(_pickup_stage) and _pickup_stage.visible:
		_place_pickup_strip()
