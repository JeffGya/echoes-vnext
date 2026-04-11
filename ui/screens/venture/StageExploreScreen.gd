# res://ui/screens/venture/StageExploreScreen.gd
# Logic only — all visual structure is in StageExploreScreen.tscn.
# V2-STAGE-001: Procedural exploration map screen for flow.stage_explore.
#
# Contract (UI-001):
# - set_snapshot(snap: Dictionary) → updates all @onready refs from snapshot data
# - action_requested signal for all player interactions
# - Never reads sim internals directly
# - No Node.new() or StyleBox in .gd — visual authoring is the .tscn's job

class_name StageExploreScreen
extends Control

signal action_requested(action: Dictionary)

# ─── Tile constants (same source as CombatBoardScreen) ───────────────────────
const _TILE_SOURCE_ID:    int      = 0
const _TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)

# ─── @onready refs ────────────────────────────────────────────────────────────
@onready var _board:             TileMapLayer   = $Board
@onready var _situation_layer:   Node2D         = $SituationLayer
@onready var _hidden_template:   Control        = $SituationLayer/HiddenMarkerTemplate
@onready var _revealed_template: Control        = $SituationLayer/RevealedMarkerTemplate
@onready var _resolved_template: Control        = $SituationLayer/ResolvedMarkerTemplate
@onready var _party_token:       Control        = $PartyToken
@onready var _turn_label:        Label          = %TurnLabel
@onready var _objectives_label:  Label          = %ObjectivesLabel
@onready var _party_state_label: Label          = %PartyStateLabel
@onready var _advance_btn:       Button         = %AdvanceButton
@onready var _return_btn:        Button         = %ReturnButton
@onready var _sit_overlay:       PanelContainer = $SituationOverlay
@onready var _sit_type_label:    Label          = %SituationTypeLabel
@onready var _sit_result_label:  Label          = %SituationResultLabel
@onready var _dismiss_btn:       Button         = %DismissButton

# Tracks dynamically duplicated situation markers so they can be freed on redraw
var _situation_markers: Array = []

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_hidden_template.visible   = false
	_revealed_template.visible = false
	_resolved_template.visible = false
	_sit_overlay.visible       = false

	_advance_btn.pressed.connect(_on_advance_pressed)
	_return_btn.pressed.connect(_on_return_pressed)
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)

func set_snapshot(snap: Dictionary) -> void:
	var data: Dictionary    = snap.get("data", {})
	var actions: Dictionary = snap.get("actions", {})

	# ── HUD labels ──────────────────────────────────────────────────────────
	_turn_label.text       = "Turn %d" % int(data.get("turn_count", 0))
	_objectives_label.text = "Objectives: %d / %d" % [
		int(data.get("objectives_found", 0)),
		int(data.get("objectives_total", 0))
	]
	if data.get("return_failed", false):
		_party_state_label.text = "Couldn't escape..."
	else:
		_party_state_label.text = str(data.get("party_state", "exploring")).capitalize()

	# ── Floor tiles ─────────────────────────────────────────────────────────
	_fill_board(int(data.get("map_width", 30)), int(data.get("map_height", 30)))

	# ── Party token ─────────────────────────────────────────────────────────
	var ppos: Dictionary = data.get("party_pos", { "col": 0, "row": 0 })
	_party_token.position = _board.map_to_local(
		Vector2i(int(ppos.get("col", 0)), int(ppos.get("row", 0)))
	)

	# ── Situation markers ────────────────────────────────────────────────────
	_rebuild_situations(data.get("situations", []))

	# ── Button states ────────────────────────────────────────────────────────
	var adv: Dictionary = actions.get("cta.advance_turn", {})
	_advance_btn.disabled = bool(adv.get("disabled", false))

	# ── Situation overlay ────────────────────────────────────────────────────
	if data.has("situation_overlay"):
		var ov: Dictionary     = data.get("situation_overlay", {})
		_sit_type_label.text   = str(ov.get("type", "")).capitalize()
		_sit_result_label.text = str(ov.get("result_text", ""))
		_sit_overlay.visible   = true
	else:
		_sit_overlay.visible = false

# ─────────────────────────────────────────────────────────────────────────────
# Floor rendering
# ─────────────────────────────────────────────────────────────────────────────

func _fill_board(cols: int, rows: int) -> void:
	# Only redraw when dimensions actually change to avoid thrashing
	if _board.get_used_cells().size() == cols * rows:
		return
	_board.clear()
	for c in range(cols):
		for r in range(rows):
			_board.set_cell(Vector2i(c, r), _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)

# ─────────────────────────────────────────────────────────────────────────────
# Situation markers
# ─────────────────────────────────────────────────────────────────────────────

func _rebuild_situations(situations: Array) -> void:
	# Free all previously duplicated markers
	for m in _situation_markers:
		if is_instance_valid(m):
			m.queue_free()
	_situation_markers.clear()

	for sit_v in situations:
		var sit: Dictionary  = sit_v if sit_v is Dictionary else {}
		var pos: Dictionary  = sit.get("pos", { "col": 0, "row": 0 })
		var revealed: bool   = bool(sit.get("revealed", false))
		var resolved: bool   = bool(sit.get("resolved", false))

		var template: Control
		if resolved:
			template = _resolved_template
		elif revealed:
			template = _revealed_template
		else:
			template = _hidden_template

		var marker: Control = template.duplicate() as Control
		marker.visible  = true
		marker.position = _board.map_to_local(
			Vector2i(int(pos.get("col", 0)), int(pos.get("row", 0)))
		)

		# Stamp type name on revealed (non-resolved) markers
		if revealed and not resolved:
			var type_lbl: Label = marker.get_node_or_null("TypeLabel")
			if type_lbl != null:
				type_lbl.text = str(sit.get("type", "")).capitalize()

		_situation_layer.add_child(marker)
		_situation_markers.append(marker)

# ─────────────────────────────────────────────────────────────────────────────
# Button handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_advance_pressed() -> void:
	action_requested.emit({ "type": "stage.advance_turn" })

func _on_return_pressed() -> void:
	action_requested.emit({ "type": "stage.return_home" })

func _on_dismiss_pressed() -> void:
	action_requested.emit({ "type": "stage.dismiss_overlay" })
