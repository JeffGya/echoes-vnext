# res://ui/screens/venture/StageExploreScreen.gd
# Merged screen for both flow.stage (preview mode) and flow.stage_explore (explore mode).
# Single Board TileMapLayer is shared across both modes — no scene swap occurs.
#
# Preview mode  (snap.type == "flow.stage"):
#   Board scaled to fit screen; all situations hidden as grey ?-circles; directive overlay shown.
#   Begin button triggers zoom tween → emits cta.start → backend transitions to flow.stage_explore.
#
# Explore mode (snap.type == "flow.stage_explore"):
#   Board at 1:1 scale. Travel animation: board scrolls to follow party (_travel_tween);
#   SituationLayer tracks board.position each frame via _process() so markers move with it.
#   Engagement popup offers "Enter" and "Pass"; Pass auto-advances to next situation.
#   Situation shapes differentiate type: combat=square, shrine=triangle, loot/money=diamond, other=circle.
#   Resolved objectives are gold; resolved encounters are grey.
#
# Contract (UI-001): set_snapshot / action_requested signal. No sim state access.

class_name StageExploreScreen
extends Control

const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")

signal action_requested(action: Dictionary)
signal modal_requested(modal_id: StringName, payload: Dictionary)

# ─── Tile constants ───────────────────────────────────────────────────────────
const _TILE_SOURCE_ID:    int      = 0
const _TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
# The authored tile texture is 128×96 on a 128×64 isometric cell, with
# texture_origin.y = -16. Relative to map_to_local()'s cell centre, its visible
# footprint is therefore 64 left/right, 64 above, and 32 below.
const _TILE_VISUAL_LEFT := 64.0
const _TILE_VISUAL_TOP := 64.0
const _TILE_VISUAL_RIGHT := 64.0
const _TILE_VISUAL_BOTTOM := 32.0
const _CONTENT_EDGE := 16.0
const _PERSISTENT_CHROME_HEIGHT := 88.0
const _CHROME_SEPARATION := 12.0
const _BOTTOM_HUD_HEIGHT := 100.0
const _TOP_HUD_HEIGHT := 56.0
const _TOP_HUD_SEPARATION := 12.0
const _TOP_HUD_COMPACT_WIDTH := 520.0
const _TOP_HUD_STANDARD_WIDTH := 620.0
const _TOP_HUD_WIDE_WIDTH := 720.0
const _DIRECTIVE_BADGE_WIDTH := 204.0
const _DIRECTIVE_BADGE_HEIGHT := 36.0
const _STAGE_INFO_COMPACT_HEIGHT := 96.0
const _STAGE_INFO_DEFAULT_HEIGHT := 96.0
const _STAGE_INFO_MAX_WIDTH := 1120.0
const _PREVIEW_INFO_SEPARATION := 16.0

# ─── Zoom tween constants (preview → explore transition) ─────────────────────
const _ZOOM_DURATION:  float = 0.35
const _ZOOM_SCALE_MUL: float = 3.0

# ─── Explore initial scale ────────────────────────────────────────────────────
# At 1:1 scale on a 30×30 map the board far exceeds the screen and only the
# party's immediate neighbours are visible — the surrounding void that defines
# the island silhouette is off-screen. A modest zoom-out reveals the terrain
# shape around the party's starting area without losing the sense of traversal.
# Applied on first entry (not on subsequent advance-turn snapshot updates).
const _EXPLORE_INITIAL_SCALE: float = 0.55

# ─── Travel animation ─────────────────────────────────────────────────────────
const _TRAVEL_DURATION: float = 0.5

# ─── Cached actions ───────────────────────────────────────────────────────────
var _cached_start_action:   Dictionary = {}
var _cached_back_action:    Dictionary = {}
var _cached_stage_complete_action: Dictionary = {}
var _cached_advance_action: Dictionary = {}
var _cached_return_action:  Dictionary = {}
var _cached_overlay_action: Dictionary = {}
var _cached_ignore_action:  Dictionary = {}

# ─── Preview state ────────────────────────────────────────────────────────────
var _preview_scale:  float   = 1.0
var _preview_center: Vector2 = Vector2.ZERO
var _is_zooming:     bool    = false
var _preview_transition_tween: Tween = null

# ─── Situation marker tracking ────────────────────────────────────────────────
var _situation_markers: Array = []

# ─── V2-STAGE-004 Phase 5 explore-bundle state ───────────────────────────────
# Previous-snapshot revealed situation ids, for reveal-flash diffing.
var _prev_revealed_ids: Dictionary = {}   # situation_id → true
# situation_id → SituationMarkerDraw node, rebuilt each explore render.
var _marker_by_sit_id: Dictionary = {}
# Choice actions authored per pending situation: choice_id → { situation_id, choice_id }.
var _choice_actions: Array = []
# Bark/snippet tween handles so travel updates can supersede stale ones.
var _snippet_tween: Tween = null
# V2-STAGE-004 P5 (playtest fix): last travel_snippet text actually presented, so an
# event-driven snippet (which now arrives on ANY explore snapshot, not just travel) is
# played exactly once even though FlowRuntime only clears explore_map["travel_snippet"]
# at the START of stage.advance_turn — non-advance rebuilds (dismiss_overlay, ignore,
# resolve_choice, engage, disengage_contact, etc.) call build_snapshot() directly and the
# field lingers unchanged, so without this guard the same line would replay on every
# subsequent non-advance re-render.
var _last_played_snippet: String = ""
# Current step budget for this turn (drives StepProgressBar text denominator).
var _step_budget: int = 0
# V2-STAGE-004 P5 (playtest fix): number of tiles ACTUALLY walked this advance
# (traveled_path segment count). Drives how many diamonds the bar shows while in
# motion so it depletes to zero in sync with the travel tween — instead of showing
# the full budget with a dimmed remainder. 0 when parked/idle (bar shows full budget).
var _travel_step_count: int = 0
# Type of the currently-pending situation, used to gate the pre-combat transition beat.
var _pending_sit_type: String = ""
# Combat-track situation types that warrant the pre-combat transition beat.
const _COMBAT_TRACK_TYPES := {
	"combat": true, "shrine": true, "recover": true, "protect": true,
	"endure": true, "pursue": true, "guide_spirit": true,
}

# ─── Travel animation state ───────────────────────────────────────────────────
var _last_party_col:          int        = -1
var _last_party_row:          int        = -1
var _travel_tween:            Tween      = null
var _pending_overlay_data:    Dictionary = {}
var _pending_overlay_actions: Dictionary = {}

# ─── Board repaint guard ──────────────────────────────────────────────────────
# Single composite key that encodes every dimension that can change the painted
# board: realm_id · stage_id · terrain content hash · mode · walkable cell count
# · explored cell count. Any single change forces a clean repaint + fog rebuild.
# Using a content hash of the full terrain dict means different realms/reruns with
# the same walkable-cell count (but different island shapes) always get a fresh
# paint, eliminating the cross-realm/cross-rerun stale-board bug (Finding 1).
var _last_paint_key: String = ""

# ─── @onready refs ────────────────────────────────────────────────────────────
@onready var _board:              TileMapLayer   = $Board
@onready var _fog_layer:          TileMapLayer   = $FogLayer
@onready var _situation_layer:    Node2D         = $SituationLayer
# Preview-mode marker templates (Control nodes, absolute screen-space positioning)
@onready var _hidden_template:    Control        = $SituationLayer/HiddenMarkerTemplate
@onready var _revealed_template:  Control        = $SituationLayer/RevealedMarkerTemplate
@onready var _resolved_template:  Control        = $SituationLayer/ResolvedMarkerTemplate
@onready var _party_layer:        Node2D         = $PartyTokenLayer
# V2-STAGE-004 P5: board-local ghost trail, authored as a child of Board in the scene so
# ghosts inherit the board's transform (position + scale) and scroll with the terrain
# during travel — see GhostFootprintLayer.gd.
@onready var _ghost_layer:        Node2D         = %GhostFootprintLayer
@onready var _hud_strip:          PanelContainer = $HudStrip
@onready var _turn_label:         Label          = %TurnLabel
@onready var _objectives_label:   Label          = %ObjectivesLabel
@onready var _party_state_label:  Label          = %PartyStateLabel
@onready var _stage_complete_btn: Button         = %StageCompleteButton
@onready var _advance_btn:        Button         = %AdvanceButton
@onready var _return_btn:         Button         = %ReturnButton
@onready var _begin_btn:          Button         = %BeginButton
@onready var _bottom_hud_region:  Control        = %BottomHudRegion
@onready var _stage_info:         PanelContainer = $StageInfoPanel
@onready var _stage_title:        Label          = %StageTitleLabel
@onready var _obj_title:          Label          = %ObjectiveTitleLabel
@onready var _directive_label:    Label          = %DirectiveLabel
@onready var _preview_info_scroll: ScrollContainer = %PreviewInfoScroll
@onready var _info_columns:       HBoxContainer  = %InfoColumns
@onready var _stage_summary:      VBoxContainer  = %StageSummary
@onready var _vow_summary:        VBoxContainer  = %VowSummary
@onready var _vow_proverb_label:  Label          = %VowProverbLabel
@onready var _vow_hint_label:     Label          = %VowConditionLabel
@onready var _back_btn:           Button         = %BackButton
@onready var _sit_overlay:          PanelContainer = $SituationOverlay
@onready var _sit_header_label:     Label          = %SituationHeaderLabel
@onready var _sit_type_label:       Label          = %SituationTypeLabel
@onready var _sit_result_label:     Label          = %SituationResultLabel
@onready var _intel_clue_label:     Label          = %IntelClueLabel
@onready var _enemy_estimate_label: Label          = %EnemyEstimateLabel
@onready var _dismiss_btn:          Button         = %DismissButton
@onready var _ignore_btn:           Button         = %IgnoreButton
@onready var _directive_overlay:  Control        = %DirectiveSelectOverlay

# ─── V2-STAGE-004 Phase 5 explore-bundle refs ────────────────────────────────
@onready var _step_budget_row:    HBoxContainer  = %StepBudgetRow
@onready var _step_progress_bar:  Control        = %StepProgressBar
@onready var _step_fraction_lbl:  Label          = %StepFractionLabel
@onready var _directive_badge:    PanelContainer = %DirectiveBadge
@onready var _travel_snippet_lbl: Label          = %TravelSnippetLabel
@onready var _bark_layer:         Control        = %BarkPopupLayer
@onready var _choice_container:   VBoxContainer  = %ChoiceButtonsContainer
@onready var _choice_btn_0:       Button         = %ChoiceButton0
@onready var _choice_btn_1:       Button         = %ChoiceButton1
@onready var _transition_flash:   ColorRect      = %TransitionFlash
@onready var _transient_layer:    CanvasLayer    = $TransientLayer

# ─── Contact conversation @onready refs ──────────────────────────────────────
@onready var _dim_overlay:             ColorRect      = $DimOverlay
@onready var _contact_panel:           PanelContainer = $ContactPanel
@onready var _npc_zone:                PanelContainer = %NPCZone
@onready var _npc_role_badge:          Label          = %NPCRoleBadge
@onready var _npc_name_label:          Label          = %NPCNameLabel
@onready var _npc_disposition_lbl:     Label          = %NPCDispositionLabel
@onready var _npc_line_label:          Label          = %NPCLineLabel
@onready var _npc_reaction_label:      Label          = %NPCReactionLabel
@onready var _turn_counter_label:      Label          = %TurnCounterLabel
@onready var _disengage_btn:           Button         = %DisengageButton
@onready var _echo_chips_container:    HBoxContainer  = %EchoChipsContainer
@onready var _confirm_selection_btn:   Button         = %ConfirmSelectionButton

# ─── Contact conversation state ───────────────────────────────────────────────
var _contact_disengage_action:  Dictionary = {}
var _contact_speak_actions:     Dictionary = {}   # echo_id → action dict
var _contact_consult_action:    Dictionary = {}
var _picker_selected_ids:       Array      = []   # consultation picker selection
var _picker_chip_nodes:         Dictionary = {}   # echo_id → chip PanelContainer
var _is_picker_mode:            bool       = false
var _layout: Dictionary = {}
var _current_mode: StringName = &""
var _current_map_size: Vector2i = Vector2i.ZERO

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_hidden_template.visible   = false
	_revealed_template.visible = false
	_resolved_template.visible = false
	_sit_overlay.visible       = false
	_ignore_btn.visible        = false
	_directive_overlay.visible = false

	_dim_overlay.visible           = false
	_contact_panel.visible         = false
	_npc_reaction_label.visible    = false
	_confirm_selection_btn.visible = false

	# V2-STAGE-004 Phase 5 explore-bundle nodes start hidden; shown by data when present.
	_step_budget_row.visible    = false
	_directive_badge.visible    = false
	_travel_snippet_lbl.visible = false
	_choice_container.visible   = false
	_choice_btn_0.visible       = false
	_choice_btn_1.visible       = false
	_transition_flash.modulate  = Color(1, 1, 1, 0)
	_choice_btn_0.pressed.connect(_on_choice_pressed.bind(0))
	_choice_btn_1.pressed.connect(_on_choice_pressed.bind(1))

	_stage_complete_btn.pressed.connect(_on_stage_complete_pressed)
	_advance_btn.pressed.connect(_on_advance_pressed)
	_return_btn.pressed.connect(_on_return_pressed)
	_begin_btn.pressed.connect(_on_begin_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	_ignore_btn.pressed.connect(_on_ignore_pressed)
	_directive_overlay.action_requested.connect(_on_overlay_action)
	_disengage_btn.pressed.connect(_on_disengage_pressed)
	_confirm_selection_btn.pressed.connect(_on_confirm_selection_pressed)
	visibility_changed.connect(_sync_transient_visibility)
	_sync_transient_visibility()

func set_layout(layout: Dictionary) -> void:
	var previous_layout := _layout.duplicate(true)
	var preserve_explore_focus := (
		_current_mode == &"explore"
		and _board != null
		and not is_zero_approx(_board.scale.x)
	)
	var focused_world_point := Vector2.ZERO
	if preserve_explore_focus:
		var old_focus := _explore_spatial_rect(previous_layout).get_center()
		focused_world_point = (old_focus - _board.position) / _board.scale.x
	_layout = layout.duplicate(true)
	_apply_responsive_layout()
	# Preview is a fit-to-safe-body composition, so live profile changes refit it.
	if _current_mode == &"preview" and _current_map_size.x > 0 and _current_map_size.y > 0:
		_build_preview(_current_map_size.x, _current_map_size.y)
	elif preserve_explore_focus:
		var new_focus := _explore_spatial_rect(_layout).get_center()
		_board.position = new_focus - focused_world_point * _board.scale.x
		_clamp_explore_board_to_spatial_rect()
		_sync_fog_layer()
		_sync_situation_layer()
		_party_layer.call("init_position", new_focus)


func _process(_delta: float) -> void:
	# During board scroll, keep situation markers locked to the board by mirroring
	# the board's current position (and scale) onto the situation layer each frame.
	if _travel_tween != null and _travel_tween.is_valid():
		_sync_situation_layer()
		# Party token is screen-locked at centre during travel; keep the bark bubble
		# pinned to it so it reads as coming from the moving party.
		if _bark_layer != null:
			var sc := get_viewport_rect().size * 0.5
			_bark_layer.call("update_actor_positions", { "party": sc })
	# Keep fog layer in sync with board at all times (position + scale must match).
	_sync_fog_layer()


# Sync fog layer position and scale to match the board exactly.
# Called from _process() and after any explicit board position/scale change.
func _sync_fog_layer() -> void:
	if _fog_layer == null:
		return
	_fog_layer.position = _board.position
	_fog_layer.scale    = _board.scale


# Sync situation marker layer position and scale to match the board exactly.
# Markers are placed in board-local tile space so the layer must share the board's
# full transform (position + scale) for markers to land on the correct screen pixels.
# Called from _process() and after any explicit board position/scale change in explore mode.
# NOTE: in preview mode the situation layer stays at (0,0) / scale(1,1) because
# _rebuild_situations_preview uses _board_to_screen() which manually applies the transform.
func _sync_situation_layer() -> void:
	if _situation_layer == null:
		return
	_situation_layer.position = _board.position
	_situation_layer.scale    = _board.scale


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
	_cancel_preview_transition()
	_is_zooming = false
	_current_mode = &"preview"
	_stage_info.modulate = Color.WHITE
	_stage_info.mouse_filter = Control.MOUSE_FILTER_STOP
	_back_btn.modulate = Color.WHITE
	_back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_responsive_layout()

	# Clear any lingering travel ghosts when returning to the (non-scrolling) preview.
	if _ghost_layer != null:
		_ghost_layer.call("clear_all")

	var cols := int(data.get("map_width",  30))
	var rows := int(data.get("map_height", 30))
	_current_map_size = Vector2i(cols, rows)
	_fill_board(cols, rows, data, "preview")
	_build_preview(cols, rows)

	# Situation layer in absolute screen-space for preview (board does not scroll here).
	_situation_layer.position = Vector2.ZERO

	var raw_sits: Variant = data.get("map_situations", [])
	var map_sits: Array   = raw_sits if raw_sits is Array else []
	_rebuild_situations_preview(map_sits)

	var entry_v: Variant    = data.get("map_entry_pos", { "col": 0, "row": 0 })
	var entry: Dictionary   = entry_v if entry_v is Dictionary else { "col": 0, "row": 0 }
	var entry_local: Vector2 = _board.map_to_local(Vector2i(int(entry.get("col", 0)), int(entry.get("row", 0))))
	_party_layer.call("init_position", _board_to_screen(entry_local))

	_stage_title.text = str(data.get("stage_name", "Stage"))
	var obj_count := int(data.get("objective_count", 0))
	_obj_title.text   = "%d Objective%s" % [obj_count, "s" if obj_count != 1 else ""]
	var dir_v: Variant      = data.get("directive", {})
	var dir_data: Dictionary = dir_v if dir_v is Dictionary else {}
	_directive_label.text   = "Directive: " + _label_for_directive(str(dir_data.get("active_id", "")))

	var av_sf_v: Variant = data.get("active_vow", {})
	var av_sf: Dictionary = av_sf_v if av_sf_v is Dictionary else {}
	var _sf_twi := str(av_sf.get("proverb_twi", ""))
	var _sf_en  := str(av_sf.get("proverb_en", ""))
	var has_proverb := not av_sf.is_empty() and (not _sf_twi.is_empty() or not _sf_en.is_empty())
	_vow_proverb_label.text = (
		"%s — \"%s\"" % [_sf_twi, _sf_en]
		if not _sf_twi.is_empty()
		else '"%s"' % _sf_en
	)
	_vow_proverb_label.visible = has_proverb
	var _sf_status := str(av_sf.get("condition_status", "none"))
	var _sf_hint   := str(av_sf.get("condition_hint", ""))
	var has_condition := _sf_status != "none" and not _sf_hint.is_empty()
	_vow_hint_label.text = _sf_hint
	_vow_hint_label.visible = has_condition
	_vow_summary.visible = has_proverb or has_condition

	var start_v: Variant = actions.get("cta.start", {})
	_cached_start_action = start_v if start_v is Dictionary else {}
	var back_v: Variant  = actions.get("nav.back", {})
	_cached_back_action  = back_v if back_v is Dictionary else {}

	_hud_strip.hide()
	_hud_strip.modulate = Color.WHITE
	_hud_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_complete_btn.hide()
	_advance_btn.hide()
	_return_btn.hide()
	_begin_btn.show()
	_begin_btn.disabled = _cached_start_action.is_empty()
	_stage_info.show()
	_back_btn.show()
	_begin_btn.grab_focus()
	_sit_overlay.hide()
	_ignore_btn.visible = false

	# Phase 5 explore-only chrome is hidden in preview; reset reveal-diff so the first
	# explore render pops newly-revealed markers correctly.
	_step_budget_row.hide()
	_directive_badge.hide()
	_travel_snippet_lbl.hide()
	_choice_container.visible = false
	_transition_flash.modulate = Color(1, 1, 1, 0)
	_prev_revealed_ids = {}
	_last_played_snippet = ""
	if _bark_layer != null:
		_bark_layer.call("clear_all")

	if not dir_data.is_empty():
		_directive_overlay.hide()
		modal_requested.emit(&"realm.directive", {
			"directive": dir_data.duplicate(true),
		})

	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.25)


# ─── Explore mode ─────────────────────────────────────────────────────────────

func _enter_explore_mode(data: Dictionary, actions: Dictionary) -> void:
	_cancel_preview_transition()
	_current_mode = &"explore"
	_stage_info.hide()
	_stage_info.modulate = Color.WHITE
	_stage_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_btn.hide()
	_back_btn.modulate = Color.WHITE
	_back_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _begin_btn.has_focus():
		_begin_btn.release_focus()
	if _back_btn.has_focus():
		_back_btn.release_focus()
	var cols := int(data.get("map_width",  30))
	var rows := int(data.get("map_height", 30))
	_current_map_size = Vector2i(cols, rows)
	_fill_board(cols, rows, data, "explore")

	var ppos_v: Variant    = data.get("party_pos", { "col": 0, "row": 0 })
	var ppos: Dictionary   = ppos_v if ppos_v is Dictionary else { "col": 0, "row": 0 }
	var pcol := int(ppos.get("col", 0))
	var prow := int(ppos.get("row", 0))

	# On first entry (coming from preview), use a modest zoom-out so the island
	# silhouette and surrounding void are visible around the party's start.
	# On subsequent advance-turn updates keep whatever scale the player has set
	# (pinch-zoom state is preserved in _board.scale between snapshot updates).
	var is_first_entry := (_last_party_col < 0)
	if is_first_entry:
		_board.scale = Vector2(_EXPLORE_INITIAL_SCALE, _EXPLORE_INITIAL_SCALE)
		_sync_fog_layer()
		_sync_situation_layer()
	# else: do not reset scale — preserve the player's current zoom level

	var board_scale   := _board.scale.x
	var party_local   := _board.map_to_local(Vector2i(pcol, prow))
	var screen_size   := get_viewport_rect().size
	var screen_center := Vector2(screen_size.x * 0.5, screen_size.y * 0.5)
	var board_target  := screen_center - party_local * board_scale

	var is_travel := (not is_first_entry) and (pcol != _last_party_col or prow != _last_party_row)
	_last_party_col = pcol
	_last_party_row = prow

	# Situation markers rebuild before the tween so they are correctly positioned
	# at the start of the scroll. _process() will move them each frame during travel.
	var sits_v: Variant   = data.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []

	if is_travel:
		if _travel_tween != null and _travel_tween.is_valid():
			_travel_tween.kill()

		# Situation layer anchored to current (pre-scroll) board position + scale.
		# _process() will sync its full transform to the board each frame during the tween.
		_sync_situation_layer()
		_rebuild_situations(situations)

		_travel_tween = create_tween()
		_travel_tween.set_ease(Tween.EASE_IN_OUT)
		_travel_tween.set_trans(Tween.TRANS_SINE)

		# V2-STAGE-004-P2: chained tween through each cell in traveled_path so the board
		# scroll follows the walkable route and never cuts across void.
		# traveled_path = pre-advance cell + each stepped cell (≥2 entries when movement occurred).
		# Segment duration = _TRAVEL_DURATION / segment_count so total time is unchanged.
		var tp_v: Variant = data.get("traveled_path", [])
		var traveled_path: Array = tp_v if tp_v is Array else []
		# Note: board_scale is already declared above in this function scope.

		# Only use chained path when we have ≥2 entries (pre-cell + at least one step).
		if traveled_path.size() >= 2:
			var seg_count: int = traveled_path.size() - 1
			# Bar shows one diamond per tile actually walked this advance (depletes to zero).
			_travel_step_count = seg_count
			var seg_dur: float = _TRAVEL_DURATION / float(seg_count)
			# Skip the first entry (pre-advance cell — already the current board position).
			# Chain one tween segment per subsequent step cell.
			# After each segment, deplete one step diamond so the budget display tracks travel.
			for _seg_i in range(1, traveled_path.size()):
				var step_v: Variant = traveled_path[_seg_i]
				var step: Dictionary = step_v if step_v is Dictionary else {}
				var step_local: Vector2 = _board.map_to_local(
					Vector2i(int(step.get("col", 0)), int(step.get("row", 0)))
				)
				var step_target: Vector2 = screen_center - step_local * board_scale
				# Board-local pixel of the cell being VACATED by this segment (the prior path
				# entry). Dropped as a ghost when the segment completes so the trail glues to
				# the terrain and fades behind the party.
				var _prev_v: Variant = traveled_path[_seg_i - 1]
				var _prev: Dictionary = _prev_v if _prev_v is Dictionary else {}
				var vacated_local: Vector2 = _board.map_to_local(
					Vector2i(int(_prev.get("col", 0)), int(_prev.get("row", 0)))
				)
				_travel_tween.tween_property(_board, "position", step_target, seg_dur)
				var spent_after: int = _seg_i
				_travel_tween.tween_callback(_on_step_consumed.bind(spent_after))
				_travel_tween.tween_callback(_drop_travel_ghost.bind(vacated_local))
		else:
			# Fallback: single straight tween (no path data or single-cell move).
			_travel_step_count = 1
			_travel_tween.tween_property(_board, "position", board_target, _TRAVEL_DURATION)
			_travel_tween.tween_callback(_on_step_consumed.bind(1))

		_party_layer.call("init_position", screen_center)

		# Travel-beat presentation: ghost-text snippet + party-token speech bubble.
		_maybe_play_travel_snippet(str(data.get("travel_snippet", "")))
		_play_travel_bark(data, screen_center)

		_pending_overlay_data    = data
		_pending_overlay_actions = actions
		_travel_tween.finished.connect(_apply_pending_overlay, CONNECT_ONE_SHOT)
	else:
		# Parked/idle refresh — no travel this snapshot; bar shows full budget.
		_travel_step_count = 0
		_board.position = board_target
		_sync_fog_layer()
		_sync_situation_layer()
		_rebuild_situations(situations)
		_party_layer.call("init_position", screen_center)
		_pending_overlay_data    = {}
		_pending_overlay_actions = {}
		# V2-STAGE-004 P5 (playtest fix): Anansi snippets are event-driven and can arrive
		# on a non-travel snapshot (notably the stage first-entry render). Gate through
		# _maybe_play_travel_snippet so it still presents here — not just during travel —
		# while the exactly-once guard skips lingering/unchanged text on later rebuilds.
		_maybe_play_travel_snippet(str(data.get("travel_snippet", "")))
		_apply_overlay_from(data, actions)

	# ── V2-STAGE-004 Phase 5: directive badge (HUD) ──────────────────────────
	# Data-driven {id,label}; badge hides itself when the field is absent/empty.
	var dir_snap_v: Variant  = data.get("directive", {})
	var dir_snap: Dictionary = dir_snap_v if dir_snap_v is Dictionary else {}
	_directive_badge.call("set_directive", dir_snap)

	# ── V2-STAGE-004 Phase 5: step-budget diamonds ───────────────────────────
	# One diamond per step_budget; deplete in sync with the travel tween below.
	# When step_budget is absent the row hides (old snapshots render as today).
	_step_budget = int(data.get("step_budget", 0))
	if _step_budget > 0:
		_step_budget_row.visible = true
		if is_travel and _travel_step_count > 0:
			# In motion: show one diamond per tile actually walked this advance so the bar
			# depletes to zero in sync with the travel tween. The tween's _on_step_consumed
			# callbacks dim them one-by-one. Text keeps the "x/y" budget context (y = budget).
			_step_progress_bar.call("set_budget", _travel_step_count)
			_step_fraction_lbl.text = "%d/%d" % [_travel_step_count, _step_budget]
		else:
			# Parked/idle: full budget shown as available — "how far can we go" at rest.
			_step_progress_bar.call("set_budget", _step_budget)
			_step_fraction_lbl.text = "%d/%d" % [_step_budget, _step_budget]
	else:
		_step_budget_row.visible = false

	_turn_label.text       = "Turn %d" % int(data.get("turn_count", 0))
	_objectives_label.text = "Objectives: %d / %d" % [
		int(data.get("objectives_found", 0)),
		int(data.get("objectives_total", 0)),
	]
	if data.get("return_failed", false):
		_party_state_label.text = "Couldn't escape..."
	else:
		_party_state_label.text = str(data.get("party_state", "exploring")).capitalize()

	var adv_v: Variant   = actions.get("cta.advance_turn", {})
	var adv: Dictionary  = adv_v if adv_v is Dictionary else {}
	_advance_btn.disabled = bool(adv.get("disabled", false))
	_cached_advance_action = { "type": "stage.advance_turn" }
	_cached_return_action  = { "type": "stage.return_home" }

	# Stage Complete button — shown when all required objectives are done.
	var sc_v: Variant = actions.get("cta.proceed_to_stage_map", {})
	_cached_stage_complete_action = sc_v if sc_v is Dictionary else {}
	_stage_complete_btn.visible = not _cached_stage_complete_action.is_empty()

	_hud_strip.modulate = Color.WHITE
	_hud_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_strip.show()
	_stage_complete_btn.show() if not _cached_stage_complete_action.is_empty() else _stage_complete_btn.hide()
	_advance_btn.show()
	_return_btn.show()
	_begin_btn.hide()
	_stage_info.hide()
	_back_btn.hide()
	_directive_overlay.hide()
	_apply_responsive_layout()
	if not _explore_requests_modal(data, actions):
		if _stage_complete_btn.visible and not _stage_complete_btn.disabled:
			_stage_complete_btn.grab_focus()
		elif _advance_btn.visible and not _advance_btn.disabled:
			_advance_btn.grab_focus()


# ─── Overlay helpers ─────────────────────────────────────────────────────────

func _apply_pending_overlay() -> void:
	_apply_overlay_from(_pending_overlay_data, _pending_overlay_actions)
	_pending_overlay_data    = {}
	_pending_overlay_actions = {}


func _apply_overlay_from(data: Dictionary, actions: Dictionary) -> void:
	# Contact conversation takes priority over all other overlays
	var cp_v: Variant = data.get("contact_pending", {})
	var cp: Dictionary = cp_v if cp_v is Dictionary else {}

	if not cp.is_empty():
		_hide_contact_panel()
		_sit_overlay.hide()
		_ignore_btn.visible = false
		_choice_container.visible = false
		modal_requested.emit(&"realm.contact", {
			"contact": cp.duplicate(true),
			"data": data.duplicate(true),
			"actions": actions.duplicate(true),
		})
		return

	_hide_contact_panel()

	var rhr_v: Variant      = data.get("return_home_result", {})
	var rhr: Dictionary     = rhr_v if rhr_v is Dictionary else {}
	var pending_v: Variant  = data.get("situation_pending", {})
	var pending: Dictionary = pending_v if pending_v is Dictionary else {}
	var eng_v: Variant      = actions.get("cta.engage_situation", {})
	var eng: Dictionary     = eng_v if eng_v is Dictionary else {}

	if not rhr.is_empty():
		_sit_overlay.hide()
		_ignore_btn.visible = false
		_choice_container.visible = false
		modal_requested.emit(&"realm.return_home", {
			"result": rhr.duplicate(true),
		})
	elif not pending.is_empty() and not eng.is_empty():
		var ign_v: Variant  = actions.get("cta.ignore_situation", {})
		var ign: Dictionary = ign_v if ign_v is Dictionary else {}
		_sit_overlay.hide()
		_ignore_btn.visible = false
		_choice_container.visible = false
		_pending_sit_type = str(pending.get("type", "")) if bool(pending.get("revealed", false)) else ""
		modal_requested.emit(&"realm.engagement", {
			"pending": pending.duplicate(true),
			"engage_action": eng.duplicate(true),
			"ignore_action": ign.duplicate(true),
		})
	elif data.has("situation_overlay"):
		var ov_v: Variant   = data.get("situation_overlay", {})
		var ov: Dictionary  = ov_v if ov_v is Dictionary else {}
		_sit_overlay.hide()
		_ignore_btn.visible = false
		_choice_container.visible = false
		modal_requested.emit(&"realm.situation", {
			"result": ov.duplicate(true),
		})
	else:
		_sit_overlay.hide()
		_ignore_btn.visible = false
		_choice_container.visible = false


# ─── Situation overlays ──────────────────────────────────────────────────────

func _show_pending_overlay(pending: Dictionary, engage_action: Dictionary, ignore_action: Dictionary = {}) -> void:
	var revealed     := bool(pending.get("revealed", false))
	var is_objective := bool(pending.get("is_objective", false)) and revealed
	_pending_sit_type = str(pending.get("type", "")) if revealed else ""

	# Header distinguishes objectives (required stage goals) from regular encounters.
	if is_objective:
		_sit_header_label.text = "Objective"
		_sit_header_label.add_theme_color_override("font_color", Color("#C8A96E"))  # Akan Gold
	else:
		_sit_header_label.text = "Encounter"
		_sit_header_label.remove_theme_color_override("font_color")

	if revealed:
		_sit_type_label.text   = str(pending.get("type", "")).capitalize()
		_sit_result_label.text = "The party stands before the situation. Commit to engage?"
	else:
		_sit_type_label.text   = "Unknown"
		_sit_result_label.text = "The party senses something ahead. Enter to discover what awaits."

	var intel_clues_v: Variant = pending.get("intel_clues", [])
	var intel_clues: Array = intel_clues_v if intel_clues_v is Array else []
	_intel_clue_label.text    = str(intel_clues[0]) if not intel_clues.is_empty() else ""
	_intel_clue_label.visible = not intel_clues.is_empty()
	var enemy_est := str(pending.get("enemy_estimate", ""))
	_enemy_estimate_label.text    = enemy_est
	_enemy_estimate_label.visible = not enemy_est.is_empty()

	# V2-STAGE-004 Phase 5: per-choice CTAs (obstacle/structure). When choices are
	# present the plain Enter button is hidden and one button per choice is shown.
	# When absent (all other types / old snapshots) the Enter button behaves as today.
	var choices_v: Variant = pending.get("choices", [])
	var choices: Array = choices_v if choices_v is Array else []
	var sit_id := str(pending.get("situation_id", ""))
	_populate_choice_ctas(choices, sit_id)
	var has_choices := not _choice_actions.is_empty()

	_dismiss_btn.visible   = not has_choices
	_dismiss_btn.text      = "Enter"
	_cached_overlay_action = engage_action
	_cached_ignore_action  = ignore_action
	_ignore_btn.visible    = not ignore_action.is_empty()
	_sit_overlay.show()


## Populate the two authored choice buttons from the pending situation's choice list.
## Hides the container + both buttons when there are no choices.
func _populate_choice_ctas(choices: Array, situation_id: String) -> void:
	_choice_actions = []
	var btns: Array = [_choice_btn_0, _choice_btn_1]
	# Guard: only two authored choice buttons exist. Config currently authors exactly 2;
	# this warns (and drops the extras) should future content author more.
	if choices.size() > btns.size():
		push_warning("StageExploreScreen: situation '%s' has %d choices; only %d shown, %d dropped." % [
			situation_id, choices.size(), btns.size(), choices.size() - btns.size()
		])
	for i in range(btns.size()):
		var btn: Button = btns[i]
		if i < choices.size():
			var choice_v: Variant = choices[i]
			var choice: Dictionary = choice_v if choice_v is Dictionary else {}
			var choice_id := str(choice.get("id", ""))
			var label     := str(choice.get("label", ""))
			if choice_id.is_empty():
				btn.visible = false
				continue
			btn.text    = label if not label.is_empty() else choice_id.capitalize()
			btn.visible = true
			_choice_actions.append({
				"type":         "stage.resolve_situation_choice",
				"situation_id": situation_id,
				"choice_id":    choice_id,
			})
		else:
			btn.visible = false
	_choice_container.visible = not _choice_actions.is_empty()


func _show_result_overlay(result: Dictionary) -> void:
	_sit_header_label.text  = "Situation"
	_sit_header_label.remove_theme_color_override("font_color")
	_sit_type_label.text    = str(result.get("type", "")).capitalize()
	_sit_result_label.text  = str(result.get("result_text", ""))
	_intel_clue_label.visible     = false
	_enemy_estimate_label.visible = false
	_dismiss_btn.visible    = true
	_dismiss_btn.text       = "Continue"
	_cached_overlay_action  = { "type": "stage.dismiss_overlay" }
	_ignore_btn.visible     = false
	_choice_container.visible = false
	_sit_overlay.show()


func _show_return_home_overlay(result: Dictionary) -> void:
	var success := bool(result.get("success", false))
	_sit_header_label.text = "Return Home"
	_sit_header_label.remove_theme_color_override("font_color")
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
	_dismiss_btn.visible          = true
	_ignore_btn.visible           = false
	_choice_container.visible     = false
	_sit_overlay.show()


# ─── Board rendering ─────────────────────────────────────────────────────────

func _fill_board(cols: int, rows: int, data: Dictionary = {}, mode: String = "") -> void:
	# Compute the walkable set from terrain data (if any).
	# StageTerrain.walkable_set returns {} when terrain is absent/empty — that is
	# the legacy sentinel meaning "all cells walkable".
	var terrain_v: Variant = data.get("terrain", {})
	var terrain: Dictionary = terrain_v if terrain_v is Dictionary else {}
	var walkable: Dictionary = StageTerrain.walkable_set(terrain)

	# Fog-of-war: explored_cells is the discovered tile set.
	# Empty dict = no explored data (treat as all discovered for legacy stages).
	var explored_v: Variant = data.get("explored_cells", {})
	var explored: Dictionary = explored_v if explored_v is Dictionary else {}

	# Determine how many cells will be painted so we can detect change.
	var expected_count: int
	if walkable.is_empty():
		# Legacy path: full cols×rows rectangle.
		expected_count = cols * rows
	else:
		expected_count = walkable.size()

	# Composite change-detection guard.
	# Encodes: realm_id · stage_id · terrain content hash · mode · walkable count · explored count.
	# terrain content hash catches different island shapes that happen to share the same
	# walkable-cell count (e.g. two realms, two reruns) — prevents stale-board bleed across
	# realm switches or rerun regenerations.
	var stage_id:       String = str(data.get("stage_id", ""))
	var realm_id:       String = str(data.get("realm_id", ""))
	var terrain_sig:    int    = str(terrain).hash()   # deterministic content signature
	var explored_size:  int    = explored.size()
	var paint_key: String = "%s|%s|%d|%s|%d|%d" % [realm_id, stage_id, terrain_sig, mode, expected_count, explored_size]
	if paint_key == _last_paint_key:
		return

	_board.clear()
	_fog_layer.clear()
	_last_paint_key = paint_key

	if walkable.is_empty():
		# Legacy / no-terrain path: paint every cell in the bounding rectangle.
		# No fog — all cells treated as discovered (backward compat).
		for c in range(cols):
			for r in range(rows):
				_board.set_cell(Vector2i(c, r), _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)
		# FogLayer stays empty: legacy mode has no fog.
	else:
		# THREE-STATE RENDER:
		#   Void (not in walkable)      → no tile on Board, no tile on FogLayer.
		#   Walkable + discovered       → normal tile on Board only.
		#   Walkable + undiscovered     → normal tile on Board (so it's a dim land shape,
		#                                  not void) + fog tile on FogLayer (dark overlay).
		#
		# When explored is empty (terrain present but no explored data yet — shouldn't
		# happen in practice because the backend seeds entry vicinity on lock, but handle
		# gracefully): all walkable cells rendered as fogged.
		#
		# The FogLayer sits at z_index=1 above the Board, modulated to Color(0,0,0,0.65),
		# so fogged cells look dark while discovered cells are clear.
		# Void stays completely absent (no tile = transparent gap).
		var all_fog: bool = explored.is_empty()

		for key_v in walkable:
			var key: String = str(key_v)
			var parts := key.split(",")
			if parts.size() != 2:
				continue
			var c: int = int(parts[0])
			var r: int = int(parts[1])
			var cell_v: Vector2i = Vector2i(c, r)
			# Paint land tile on Board for every walkable cell (discovered or not).
			# This ensures fog cells are visually land-shaped, never invisible (void).
			_board.set_cell(cell_v, _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)
			# Fog overlay: paint on FogLayer if NOT discovered.
			var is_discovered: bool = (not all_fog) and explored.has(key)
			if not is_discovered:
				_fog_layer.set_cell(cell_v, _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)


func _build_preview(cols: int, rows: int) -> void:
	var visual_rect := _preview_visual_rect(cols, rows)
	var map_pixel_w: float = visual_rect.size.x
	var map_pixel_h: float = visual_rect.size.y
	var preview_rect := _preview_safe_rect()
	var available_w: float = preview_rect.size.x
	var available_h: float = preview_rect.size.y

	if map_pixel_w <= 0.0 or map_pixel_h <= 0.0 or available_w <= 0.0 or available_h <= 0.0:
		return

	_preview_scale = min(available_w / map_pixel_w, available_h / map_pixel_h)
	_board.scale   = Vector2(_preview_scale, _preview_scale)

	_preview_center = preview_rect.get_center()
	_board.position = _preview_center - visual_rect.get_center() * _preview_scale
	_sync_fog_layer()

func _preview_safe_rect() -> Rect2:
	var logical_size: Vector2 = _layout.get("logical_size", Vector2.ZERO)
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		logical_size = get_viewport_rect().size
	var insets: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	var edge_left := maxf(_CONTENT_EDGE, ceilf(insets.x))
	var edge_top := maxf(_CONTENT_EDGE, ceilf(insets.y))
	var edge_right := maxf(_CONTENT_EDGE, ceilf(insets.z))
	var edge_bottom := maxf(_CONTENT_EDGE, ceilf(insets.w))
	# Derive the field boundary from the actual laid-out banner so the authored
	# preview card and map fit cannot drift apart as profiles change.
	var preview_top := maxf(edge_top, _stage_info.offset_bottom) + _PREVIEW_INFO_SEPARATION
	var preview_bottom := (
		edge_bottom
		+ _PERSISTENT_CHROME_HEIGHT
		+ _CHROME_SEPARATION
		+ 56.0
	)
	return Rect2(
		Vector2(edge_left, preview_top),
		Vector2(
			maxf(0.0, logical_size.x - edge_left - edge_right),
			maxf(0.0, logical_size.y - preview_top - preview_bottom)
		)
	)


func _preview_visual_rect(cols: int, rows: int) -> Rect2:
	var used_rect := _board.get_used_rect()
	var first_cell := Vector2i.ZERO
	var last_cell := Vector2i(maxi(0, cols - 1), maxi(0, rows - 1))
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		first_cell = used_rect.position
		last_cell = used_rect.end - Vector2i.ONE

	var tl: Vector2 = _board.map_to_local(first_cell)
	var tr: Vector2 = _board.map_to_local(Vector2i(last_cell.x, first_cell.y))
	var bl: Vector2 = _board.map_to_local(Vector2i(first_cell.x, last_cell.y))
	var br: Vector2 = _board.map_to_local(last_cell)
	var center_min := Vector2(
		minf(minf(tl.x, tr.x), minf(bl.x, br.x)),
		minf(minf(tl.y, tr.y), minf(bl.y, br.y))
	)
	var center_max := Vector2(
		maxf(maxf(tl.x, tr.x), maxf(bl.x, br.x)),
		maxf(maxf(tl.y, tr.y), maxf(bl.y, br.y))
	)
	var visual_min := center_min - Vector2(_TILE_VISUAL_LEFT, _TILE_VISUAL_TOP)
	var visual_max := center_max + Vector2(_TILE_VISUAL_RIGHT, _TILE_VISUAL_BOTTOM)
	return Rect2(visual_min, visual_max - visual_min)


# ─── Situation markers ───────────────────────────────────────────────────────

## Preview mode — uses existing Control templates; SituationLayer stays at (0,0) so
## markers can use absolute screen-space positions. All situations appear hidden (grey ?)
## so the player cannot identify objectives or types before entry.
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


## Explore mode — uses SituationMarkerDraw (Node2D with custom shape drawing).
## Markers positioned in board-local space; SituationLayer tracks _board.position so
## markers scroll correctly during the travel tween.
## Shape by type: combat=square, shrine=triangle, loot/money=diamond, other=circle.
## Color: grey=hidden, blue=revealed, gold=resolved-objective, grey=resolved-encounter.
func _rebuild_situations(situations: Array) -> void:
	for m in _situation_markers:
		if is_instance_valid(m):
			m.queue_free()
	_situation_markers.clear()
	_marker_by_sit_id.clear()

	# Newly-revealed situations get a scale-pop; diff current vs previous revealed set.
	var next_revealed: Dictionary = {}
	var newly_revealed: Array = []

	for sit_v in situations:
		var sit: Dictionary   = sit_v if sit_v is Dictionary else {}
		var pos_v: Variant    = sit.get("pos", { "col": 0, "row": 0 })
		var pos_d: Dictionary = pos_v if pos_v is Dictionary else { "col": 0, "row": 0 }
		var revealed: bool    = bool(sit.get("revealed", false))
		var resolved: bool    = bool(sit.get("resolved", false))
		var is_obj: bool      = bool(sit.get("is_objective", false))
		var sit_type: String  = str(sit.get("type", ""))
		var sit_id: String    = str(sit.get("id", ""))

		var marker := SituationMarkerDraw.new()
		marker.setup(sit_type, not revealed, resolved, is_obj)
		marker.position = _board.map_to_local(Vector2i(int(pos_d.get("col", 0)), int(pos_d.get("row", 0))))

		_situation_layer.add_child(marker)
		_situation_markers.append(marker)

		if not sit_id.is_empty():
			_marker_by_sit_id[sit_id] = marker
			if revealed:
				next_revealed[sit_id] = true
				if not _prev_revealed_ids.has(sit_id):
					newly_revealed.append(sit_id)

	# Fire reveal-flash on markers that flipped to revealed this snapshot.
	for sid_v in newly_revealed:
		var sid: String = str(sid_v)
		var mk: Variant = _marker_by_sit_id.get(sid, null)
		if mk != null and is_instance_valid(mk):
			mk.call("play_reveal_flash")

	_prev_revealed_ids = next_revealed


# ─── Button handlers ─────────────────────────────────────────────────────────

func _on_stage_complete_pressed() -> void:
	if not _cached_stage_complete_action.is_empty():
		action_requested.emit(_cached_stage_complete_action)
		_cached_stage_complete_action = {}


func _on_advance_pressed() -> void:
	if not _cached_advance_action.is_empty():
		action_requested.emit(_cached_advance_action)


func _on_return_pressed() -> void:
	if not _cached_return_action.is_empty():
		action_requested.emit(_cached_return_action)


func _on_begin_pressed() -> void:
	if _cached_start_action.is_empty() or _is_zooming:
		return
	_cancel_preview_transition()
	_is_zooming         = true
	_begin_btn.disabled = true
	if _begin_btn.has_focus():
		_begin_btn.release_focus()
	if _back_btn.has_focus():
		_back_btn.release_focus()

	_preview_transition_tween = create_tween()
	_preview_transition_tween.set_ease(Tween.EASE_IN)
	_preview_transition_tween.set_trans(Tween.TRANS_QUAD)

	var target_scale := Vector2(_preview_scale * _ZOOM_SCALE_MUL, _preview_scale * _ZOOM_SCALE_MUL)
	var current_pos  := _board.position
	var map_offset   := _preview_center - current_pos
	var target_pos   := _preview_center - map_offset * _ZOOM_SCALE_MUL

	_preview_transition_tween.parallel().tween_property(_board,      "scale",    target_scale,      _ZOOM_DURATION)
	_preview_transition_tween.parallel().tween_property(_board,      "position", target_pos,        _ZOOM_DURATION)
	_preview_transition_tween.parallel().tween_property(_stage_info, "modulate", Color(1, 1, 1, 0), _ZOOM_DURATION)
	_preview_transition_tween.parallel().tween_property(_back_btn,   "modulate", Color(1, 1, 1, 0), _ZOOM_DURATION)

	_preview_transition_tween.finished.connect(_on_zoom_finished)


func _on_zoom_finished() -> void:
	_preview_transition_tween = null
	action_requested.emit(_cached_start_action)


func _cancel_preview_transition() -> void:
	if _preview_transition_tween != null and _preview_transition_tween.is_valid():
		_preview_transition_tween.kill()
	_preview_transition_tween = null


func _on_back_pressed() -> void:
	if not _cached_back_action.is_empty():
		action_requested.emit(_cached_back_action)


func _on_choice_pressed(index: int) -> void:
	if index < 0 or index >= _choice_actions.size():
		return
	var act_v: Variant = _choice_actions[index]
	var act: Dictionary = act_v if act_v is Dictionary else {}
	if act.is_empty():
		return
	_sit_overlay.hide()
	_choice_container.visible = false
	_ignore_btn.visible       = false
	_choice_actions = []
	action_requested.emit(act)


func _on_dismiss_pressed() -> void:
	_sit_overlay.hide()
	_ignore_btn.visible = false
	_choice_container.visible = false
	if not _cached_overlay_action.is_empty():
		# Pre-combat transition beat: brief flash when handing off to a combat-track
		# situation. Purely cosmetic; the action still dispatches immediately after.
		if str(_cached_overlay_action.get("type", "")) == "stage.engage_situation" \
				and _COMBAT_TRACK_TYPES.has(_pending_sit_type):
			_play_transition_flash()
		action_requested.emit(_cached_overlay_action)
		_cached_overlay_action = {}
		_pending_sit_type = ""


func _on_ignore_pressed() -> void:
	_sit_overlay.hide()
	_ignore_btn.visible = false
	_choice_container.visible = false
	if not _cached_ignore_action.is_empty():
		action_requested.emit(_cached_ignore_action)
		_cached_ignore_action = {}


func _on_overlay_action(action: Dictionary) -> void:
	action_requested.emit(action)


# ─── Helpers ─────────────────────────────────────────────────────────────────

# ── V2-STAGE-004 Phase 5 travel-beat helpers ─────────────────────────────────

## Called after each travel tween segment: dims one more step diamond + updates fraction.
func _on_step_consumed(spent: int) -> void:
	if _step_budget <= 0:
		return
	# In motion the bar shows _travel_step_count diamonds (tiles walked this advance); the
	# numerator counts diamonds still filled, the denominator stays the directive budget.
	var shown: int = _travel_step_count if _travel_step_count > 0 else _step_budget
	var clamped: int = clampi(spent, 0, shown)
	_step_progress_bar.call("set_spent", clamped)
	_step_fraction_lbl.text = "%d/%d" % [shown - clamped, _step_budget]


## Drop a fading ghost footprint at a vacated cell (board-local pixel). Called from the
## travel-tween segment chain so the trail appears along the traveled path and fades out.
func _drop_travel_ghost(vacated_local: Vector2) -> void:
	if _ghost_layer != null:
		_ghost_layer.call("drop_ghost", vacated_local)


## Gate for _play_travel_snippet: presents a given snippet text at most once.
## FlowRuntime clears explore_map["travel_snippet"] only at the START of
## stage.advance_turn; every other action handler (dismiss_overlay, ignore_situation,
## resolve_situation_choice, engage_situation, disengage_contact, ...) rebuilds the
## snapshot via FlowStageExploreState.build_snapshot() directly, which re-projects
## whatever text is still sitting in explore_map — so without this de-dupe the same
## line would replay on every subsequent non-advance re-render. Comparing against the
## last-presented text (updated on every call, including the "" clear case) keeps
## presentation exactly-once while still allowing a genuinely new/different snippet
## (or the field going back to empty) to be picked up immediately.
func _maybe_play_travel_snippet(snippet: String) -> void:
	if snippet == _last_played_snippet:
		return
	_last_played_snippet = snippet
	_play_travel_snippet(snippet)


## Ghost-text snippet fading in/out during the travel tween. No-op when empty.
func _play_travel_snippet(snippet: String) -> void:
	if _snippet_tween != null and _snippet_tween.is_valid():
		_snippet_tween.kill()
	if snippet.is_empty():
		_travel_snippet_lbl.visible = false
		return
	_travel_snippet_lbl.text     = snippet
	_travel_snippet_lbl.visible  = true
	_travel_snippet_lbl.modulate = Color(1, 1, 1, 0)
	_snippet_tween = create_tween()
	_snippet_tween.tween_property(_travel_snippet_lbl, "modulate:a", 1.0, 0.4)
	_snippet_tween.tween_interval(2.1)
	_snippet_tween.tween_property(_travel_snippet_lbl, "modulate:a", 0.0, 0.5)
	_snippet_tween.tween_callback(func() -> void: _travel_snippet_lbl.visible = false)


## Party-token speech bubble during travel, fed to the instanced BarkPopupLayer.
## Builds one synthetic event for the "party" actor. No-op when travel_bark is empty.
func _play_travel_bark(data: Dictionary, screen_center: Vector2) -> void:
	if _bark_layer == null:
		return
	var tb_v: Variant  = data.get("travel_bark", {})
	var tb: Dictionary = tb_v if tb_v is Dictionary else {}
	var line := str(tb.get("line", ""))
	if line.is_empty():
		return
	_bark_layer.call("show_barks", [{
		"actor_id":    "party",
		"bark_line":   line,
		"screen_pos":  screen_center,
		"is_response": false,
	}])


## 200ms flash/fade overlay when handing off to combat. Cosmetic only.
func _play_transition_flash() -> void:
	_transition_flash.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_transition_flash, "modulate:a", 1.0, 0.1)
	tw.tween_property(_transition_flash, "modulate:a", 0.0, 0.1)


func _board_to_screen(board_local: Vector2) -> Vector2:
	return _board.position + board_local * _board.scale.x


func _label_for_directive(dir_id: String) -> String:
	match dir_id:
		"directive.scout_carefully": return "Scout Carefully"
		"directive.seek_signs":      return "Seek Signs"
		_: return dir_id.capitalize() if not dir_id.is_empty() else "None"


# ─── Contact conversation ─────────────────────────────────────────────────────

func _show_contact_panel(contact: Dictionary, data: Dictionary, actions: Dictionary) -> void:
	var role        := str(contact.get("role", ""))
	var role_label  := str(contact.get("role_label", role.capitalize()))
	var npc_name    := str(contact.get("name", "Unknown"))
	var disposition := str(contact.get("disposition", ""))
	var fear        := int(contact.get("fear",   50))
	var morale      := int(contact.get("morale", 50))
	var turn_cur    := int(contact.get("turn_current", 0))
	var turn_tot    := int(contact.get("turn_count",   2))

	_npc_role_badge.text         = role_label
	_npc_name_label.text         = npc_name
	_npc_disposition_lbl.text    = _disposition_cue(disposition)
	var npc_line := str(contact.get("npc_line", ""))
	_npc_line_label.text         = npc_line if not npc_line.is_empty() else "..."
	_turn_counter_label.hide()

	# Ambient tint on NPC zone — emotional state communicated as colour, no numbers
	var npc_style := StyleBoxFlat.new()
	npc_style.bg_color = _npc_ambient_color(fear, morale)
	npc_style.set_corner_radius_all(6)
	npc_style.content_margin_left   = 12.0
	npc_style.content_margin_top    = 10.0
	npc_style.content_margin_right  = 12.0
	npc_style.content_margin_bottom = 10.0
	_npc_zone.add_theme_stylebox_override("panel", npc_style)

	# Show reaction word (NPC's emotional response from previous turn) with fade-in
	var reaction_word := str(contact.get("npc_reaction_word", ""))
	if not reaction_word.is_empty():
		_npc_reaction_label.text      = reaction_word
		_npc_reaction_label.modulate  = Color(1.0, 1.0, 1.0, 0.0)
		_npc_reaction_label.visible   = true
		var rw_tween := create_tween()
		rw_tween.tween_property(_npc_reaction_label, "modulate:a", 1.0, 0.35)
	else:
		_npc_reaction_label.visible = false

	# Determine echo chip mode
	var responses_v: Variant = data.get("contact_responses", [])
	var responses: Array = responses_v if responses_v is Array else []
	var bids_v: Variant = data.get("contact_echo_bids", [])
	var bids: Array = bids_v if bids_v is Array else []

	var consult_v: Variant = actions.get("cta.consult_echoes", {})
	_contact_consult_action = consult_v if consult_v is Dictionary else {}
	var dis_v: Variant = actions.get("cta.disengage_contact", {})
	_contact_disengage_action = dis_v if dis_v is Dictionary else {}

	_is_picker_mode = responses.is_empty() and not _contact_consult_action.is_empty()
	if _is_picker_mode:
		_build_picker_chips(bids)
		_confirm_selection_btn.visible = true
	else:
		_build_response_chips(responses, actions)
		_confirm_selection_btn.visible = false

	# Disable advance/return while conversation is active
	_advance_btn.disabled = true
	_return_btn.disabled  = true

	_dim_overlay.visible   = true
	_contact_panel.visible = true


func _hide_contact_panel() -> void:
	_dim_overlay.visible    = false
	_contact_panel.visible  = false
	_contact_disengage_action.clear()
	_contact_speak_actions.clear()
	_contact_consult_action.clear()
	_picker_selected_ids.clear()
	_picker_chip_nodes.clear()
	_is_picker_mode = false


func _npc_ambient_color(fear: int, morale: int) -> Color:
	if fear > 65:
		return Color(0.20, 0.06, 0.06, 0.90)   # deep red — frightened
	elif fear > 45:
		return Color(0.20, 0.12, 0.04, 0.90)   # amber — unsettled
	elif morale >= 60 and fear <= 30:
		return Color(0.05, 0.18, 0.10, 0.90)   # jade — settled / calm
	else:
		return Color(0.07, 0.07, 0.12, 0.90)   # neutral dark


func _disposition_cue(disposition: String) -> String:
	match disposition:
		"bold":       return "speaks directly"
		"reflective": return "chooses words carefully"
		"protective": return "stands with arms crossed"
		"wary":       return "eyes keep moving"
		"grieving":   return "voice is very still"
		"proud":      return "holds their ground"
		_:            return ""




func _build_response_chips(responses: Array, actions: Dictionary) -> void:
	for child in _echo_chips_container.get_children():
		child.queue_free()
	_contact_speak_actions.clear()
	_picker_chip_nodes.clear()

	for resp_v in responses:
		var resp: Dictionary = resp_v if resp_v is Dictionary else {}
		var echo_id           := str(resp.get("echo_id", ""))
		var calling           := str(resp.get("calling", ""))
		var emotional_status  := str(resp.get("emotional_status", ""))
		var response_text     := str(resp.get("response_text", ""))
		var stat_texture      := str(resp.get("stat_texture", ""))
		var bid_type          := str(resp.get("bid_type", ""))

		if echo_id.is_empty():
			continue

		var act_v: Variant = actions.get("cta.speak_response." + echo_id, {})
		var act: Dictionary = act_v if act_v is Dictionary else {}
		_contact_speak_actions[echo_id] = act

		var chip: PanelContainer = _build_echo_chip(
			echo_id, calling, emotional_status, response_text, stat_texture, bid_type, false
		)
		_echo_chips_container.add_child(chip)
		_picker_chip_nodes[echo_id] = chip

		var chip_btn: Button = chip.get_node_or_null("ChipButton") as Button
		if chip_btn != null:
			chip_btn.pressed.connect(_on_chip_speak.bind(echo_id))


func _build_picker_chips(bids: Array) -> void:
	for child in _echo_chips_container.get_children():
		child.queue_free()
	_contact_speak_actions.clear()
	_picker_chip_nodes.clear()
	_picker_selected_ids.clear()
	_confirm_selection_btn.disabled = true

	for bid_v in bids:
		var bid: Dictionary = bid_v if bid_v is Dictionary else {}
		var echo_id          := str(bid.get("echo_id",          ""))
		var echo_name        := str(bid.get("echo_name",        ""))
		var calling          := str(bid.get("calling",          ""))
		var emotional_status := str(bid.get("emotional_status", ""))
		var hint             := str(bid.get("hint",             ""))
		var bid_type         := str(bid.get("bid_type",         ""))

		if echo_id.is_empty():
			continue

		# Build chip — calling in calling slot, hint in response_text slot, emotional_status drives dot.
		var chip: PanelContainer = _build_echo_chip(
			echo_id, calling, emotional_status, hint, "", bid_type, false
		)

		# Inject echo name as the first label in the chip's content VBox.
		var content_vbox: VBoxContainer = chip.get_child(0) as VBoxContainer
		if content_vbox != null:
			var name_lbl := Label.new()
			name_lbl.text = echo_name
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.add_theme_color_override("font_color", Color("#E8D8B0"))
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			content_vbox.add_child(name_lbl)
			content_vbox.move_child(name_lbl, 0)

		_echo_chips_container.add_child(chip)
		_picker_chip_nodes[echo_id] = chip

		var chip_btn: Button = chip.get_node_or_null("ChipButton") as Button
		if chip_btn != null:
			chip_btn.pressed.connect(_on_chip_toggle_picker.bind(echo_id))


func _build_echo_chip(
	echo_id:       String,
	calling:       String,
	emotional_status: String,
	response_text: String,
	stat_texture:  String,
	bid_type:      String,
	_selected:     bool
) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(140, 190)

	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.08, 0.08, 0.14, 1.0)
	chip_style.set_corner_radius_all(6)
	chip_style.content_margin_left   = 10.0
	chip_style.content_margin_top    = 10.0
	chip_style.content_margin_right  = 10.0
	chip_style.content_margin_bottom = 10.0
	chip.add_theme_stylebox_override("panel", chip_style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	chip.add_child(content)

	# Portrait placeholder — the status treatment below carries emotional meaning.
	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = Vector2(56, 56)
	portrait_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(portrait_holder)

	# Calling label beneath portrait
	var calling_lbl := Label.new()
	calling_lbl.text = calling
	calling_lbl.add_theme_font_size_override("font_size", 11)
	calling_lbl.add_theme_color_override("font_color", Color("#A8865A"))
	calling_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	calling_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	content.add_child(calling_lbl)

	var emotion_dot := Label.new()
	emotion_dot.text = "● %s" % EmotionPresentation.display_name(emotional_status)
	emotion_dot.add_theme_font_size_override("font_size", 10)
	emotion_dot.add_theme_color_override("font_color", EmotionPresentation.color(emotional_status))
	emotion_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(emotion_dot)

	# Response text
	var response_lbl := Label.new()
	response_lbl.text = response_text
	response_lbl.add_theme_font_size_override("font_size", 12)
	response_lbl.add_theme_color_override("font_color", Color("#D0C0A0"))
	response_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	response_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	response_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(response_lbl)

	# Stat texture pill
	if not stat_texture.is_empty():
		var pill_lbl := Label.new()
		pill_lbl.text = stat_texture
		pill_lbl.add_theme_font_size_override("font_size", 10)
		pill_lbl.add_theme_color_override("font_color", Color(0.533, 0.533, 0.6, 1.0))
		pill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(pill_lbl)

	# Bid badge
	if not bid_type.is_empty():
		var bid_badge := Label.new()
		bid_badge.text = "⬥"
		bid_badge.add_theme_font_size_override("font_size", 10)
		bid_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		match bid_type:
			"alignment": bid_badge.add_theme_color_override("font_color", Color("#C8A96E"))
			"reactive":  bid_badge.add_theme_color_override("font_color", Color("#C87830"))
			_:           bid_badge.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		content.add_child(bid_badge)

	# Invisible full-coverage button on top — tap portrait = tap button
	var chip_btn := Button.new()
	chip_btn.name = "ChipButton"
	chip_btn.flat = true
	chip_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chip.add_child(chip_btn)

	# Store echo_id as metadata for later reference
	chip.set_meta("echo_id", echo_id)

	return chip


func _refresh_picker_chip_states() -> void:
	var selected_count: int = _picker_selected_ids.size()
	for eid_v: Variant in _picker_chip_nodes:
		var eid: String = str(eid_v)
		var chip_v: Variant = _picker_chip_nodes[eid]
		var chip: PanelContainer = chip_v as PanelContainer
		if chip == null or not is_instance_valid(chip):
			continue
		var chip_style := StyleBoxFlat.new()
		chip_style.set_corner_radius_all(6)
		chip_style.content_margin_left   = 10.0
		chip_style.content_margin_top    = 10.0
		chip_style.content_margin_right  = 10.0
		chip_style.content_margin_bottom = 10.0
		if eid in _picker_selected_ids:
			chip_style.bg_color = Color(0.15, 0.28, 0.20, 1.0)
			chip.modulate.a = 1.0
		elif selected_count >= 3:
			chip_style.bg_color = Color(0.08, 0.08, 0.14, 1.0)
			chip.modulate.a = 0.4
		else:
			chip_style.bg_color = Color(0.08, 0.08, 0.14, 1.0)
			chip.modulate.a = 1.0
		chip.add_theme_stylebox_override("panel", chip_style)


# ─── Contact button handlers ──────────────────────────────────────────────────

func _on_chip_speak(echo_id: String) -> void:
	var act_v: Variant = _contact_speak_actions.get(echo_id, {})
	var act: Dictionary = act_v if act_v is Dictionary else {}
	if act.is_empty():
		return
	# Dim unchosen echo chips
	for eid_v: Variant in _picker_chip_nodes:
		var eid: String = str(eid_v)
		if eid != echo_id:
			var chip_v: Variant = _picker_chip_nodes[eid]
			var chip: PanelContainer = chip_v as PanelContainer
			if chip != null and is_instance_valid(chip):
				chip.modulate.a = 0.4
	action_requested.emit(act)


func _on_chip_toggle_picker(echo_id: String) -> void:
	if echo_id in _picker_selected_ids:
		_picker_selected_ids.erase(echo_id)
	elif _picker_selected_ids.size() < 3:
		_picker_selected_ids.append(echo_id)
	_refresh_picker_chip_states()
	_confirm_selection_btn.disabled = _picker_selected_ids.is_empty()


func _on_confirm_selection_pressed() -> void:
	if _picker_selected_ids.is_empty() or _contact_consult_action.is_empty():
		return
	var act: Dictionary = _contact_consult_action.duplicate()
	act["echo_ids"] = _picker_selected_ids.duplicate()
	action_requested.emit(act)
	_picker_selected_ids.clear()


func _on_disengage_pressed() -> void:
	if not _contact_disengage_action.is_empty():
		action_requested.emit(_contact_disengage_action)
	_hide_contact_panel()

func _apply_responsive_layout() -> void:
	var insets: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	var top := maxf(_CONTENT_EDGE, float(ceilf(insets.y)))
	var left := maxf(_CONTENT_EDGE, float(ceilf(insets.x)))
	var right := maxf(_CONTENT_EDGE, float(ceilf(insets.z)))
	var bottom_edge := maxf(_CONTENT_EDGE, float(ceilf(insets.w)))
	var chrome_exclusion := bottom_edge + _PERSISTENT_CHROME_HEIGHT
	var logical_size_v: Variant = _layout.get("logical_size", Vector2.ZERO)
	var logical_size: Vector2 = logical_size_v if logical_size_v is Vector2 else Vector2.ZERO
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		logical_size = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var profile := str(_layout.get("profile", "standard"))
	var target_hud_width := _TOP_HUD_STANDARD_WIDTH
	match profile:
		"compact":
			target_hud_width = _TOP_HUD_COMPACT_WIDTH
		"wide":
			target_hud_width = _TOP_HUD_WIDE_WIDTH
	var available_hud_width := maxf(
		0.0,
		logical_size.x - left - right - _DIRECTIVE_BADGE_WIDTH - _TOP_HUD_SEPARATION
	)
	var hud_width := minf(target_hud_width, available_hud_width)
	_hud_strip.offset_left = left
	_hud_strip.offset_top = top
	_hud_strip.offset_right = left + hud_width
	_hud_strip.offset_bottom = top + _TOP_HUD_HEIGHT
	var stage_info_height := (
		_STAGE_INFO_COMPACT_HEIGHT
		if profile == "compact"
		else _STAGE_INFO_DEFAULT_HEIGHT
	)
	_back_btn.offset_left = left
	_back_btn.offset_top = top
	_back_btn.offset_right = _back_btn.offset_left + 80.0
	_back_btn.offset_bottom = _back_btn.offset_top + 48.0
	var stage_info_safe_left := left
	if profile == "compact":
		stage_info_safe_left = _back_btn.offset_right + 16.0
	var available_info_width := maxf(0.0, logical_size.x - stage_info_safe_left - right)
	var stage_info_width := minf(_STAGE_INFO_MAX_WIDTH, available_info_width)
	var stage_info_left := stage_info_safe_left + maxf(0.0, (available_info_width - stage_info_width) * 0.5)
	_stage_info.offset_left = stage_info_left
	_stage_info.offset_right = stage_info_left + stage_info_width
	_stage_info.offset_top = top
	_stage_info.offset_bottom = top + stage_info_height
	if _info_columns != null:
		# ScrollContainer does not guarantee an HBox child receives the viewport
		# width when its wrapped labels report a tiny intrinsic minimum. Give the
		# authored two-column body and its children concrete widths so autowrap
		# cannot feed an artificially tall minimum back into the container.
		var info_body_width := maxf(0.0, stage_info_width - 48.0)
		var column_content_width := maxf(0.0, info_body_width - 24.0)
		var stage_summary_width := floorf(column_content_width / 3.0)
		var vow_summary_width := column_content_width - stage_summary_width
		_info_columns.custom_minimum_size.x = info_body_width
		_stage_summary.custom_minimum_size.x = stage_summary_width
		_stage_title.custom_minimum_size.x = stage_summary_width
		_vow_summary.custom_minimum_size.x = vow_summary_width
		_vow_proverb_label.custom_minimum_size.x = vow_summary_width
		_vow_hint_label.custom_minimum_size.x = vow_summary_width
	_bottom_hud_region.offset_left = left
	_bottom_hud_region.offset_right = -right
	_bottom_hud_region.offset_bottom = -chrome_exclusion - _CHROME_SEPARATION
	_bottom_hud_region.offset_top = _bottom_hud_region.offset_bottom - _BOTTOM_HUD_HEIGHT
	_directive_badge.offset_right = -right
	_directive_badge.offset_left = _directive_badge.offset_right - _DIRECTIVE_BADGE_WIDTH
	_directive_badge.offset_top = top + (_TOP_HUD_HEIGHT - _DIRECTIVE_BADGE_HEIGHT) * 0.5
	_directive_badge.offset_bottom = _directive_badge.offset_top + _DIRECTIVE_BADGE_HEIGHT

func _explore_requests_modal(data: Dictionary, actions: Dictionary) -> bool:
	var contact_v: Variant = data.get("contact_pending", {})
	if contact_v is Dictionary and not (contact_v as Dictionary).is_empty():
		return true
	var return_v: Variant = data.get("return_home_result", {})
	if return_v is Dictionary and not (return_v as Dictionary).is_empty():
		return true
	var pending_v: Variant = data.get("situation_pending", {})
	var engage_v: Variant = actions.get("cta.engage_situation", {})
	if pending_v is Dictionary and engage_v is Dictionary \
			and not (pending_v as Dictionary).is_empty() \
			and not (engage_v as Dictionary).is_empty():
		return true
	return data.has("situation_overlay")

func _explore_spatial_rect(layout: Dictionary) -> Rect2:
	var logical_size: Vector2 = layout.get("logical_size", Vector2.ZERO)
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		logical_size = get_viewport_rect().size
	var insets: Vector4 = layout.get("safe_insets", Vector4.ZERO)
	var left := maxf(_CONTENT_EDGE, ceilf(insets.x))
	var top := maxf(_CONTENT_EDGE, ceilf(insets.y)) + _TOP_HUD_HEIGHT + _TOP_HUD_SEPARATION
	var right := maxf(_CONTENT_EDGE, ceilf(insets.z))
	var bottom_edge := maxf(_CONTENT_EDGE, ceilf(insets.w))
	var bottom := (
		logical_size.y
		- bottom_edge
		- _PERSISTENT_CHROME_HEIGHT
		- _CHROME_SEPARATION
		- _BOTTOM_HUD_HEIGHT
		- 12.0
	)
	return Rect2(
		Vector2(left, top),
		Vector2(maxf(0.0, logical_size.x - left - right), maxf(0.0, bottom - top))
	)

func _clamp_explore_board_to_spatial_rect() -> void:
	if _current_map_size.x <= 0 or _current_map_size.y <= 0:
		return
	var visual_rect := _preview_visual_rect(_current_map_size.x, _current_map_size.y)
	var spatial_rect := _explore_spatial_rect(_layout)
	var scale_value := _board.scale.x
	var min_position := spatial_rect.end - visual_rect.end * scale_value
	var max_position := spatial_rect.position - visual_rect.position * scale_value
	if min_position.x <= max_position.x:
		_board.position.x = clampf(_board.position.x, min_position.x, max_position.x)
	else:
		_board.position.x = spatial_rect.get_center().x - visual_rect.get_center().x * scale_value
	if min_position.y <= max_position.y:
		_board.position.y = clampf(_board.position.y, min_position.y, max_position.y)
	else:
		_board.position.y = spatial_rect.get_center().y - visual_rect.get_center().y * scale_value

func _sync_transient_visibility() -> void:
	if _transient_layer != null:
		_transient_layer.visible = is_visible_in_tree()
