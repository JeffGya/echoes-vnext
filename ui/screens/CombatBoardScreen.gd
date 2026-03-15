# res://ui/screens/CombatBoardScreen.gd
# Bespoke combat board screen — renders the isometric grid for flow.encounter.
# GRID-001: Board configuration + isometric floor tile rendering.
# GRID-002: Actor tokens drawn at grid_pos cells via CombatTokenLayer.
# GRID-004: Distance debug overlay via CombatDistanceLayer (dev-facing only).
# GRID-005: "Adv. Round" step-mode button (TEMP — removed at COMBAT-001).
#
# Contract (UI-001):
# - set_snapshot(snap: Dictionary) → _clear() + _render(data, actions)
# - action_requested signal for all player interactions
# - Never reads sim internals directly
#
# Routing note (GRID-001 temporary):
#   AppRoot routes flow.encounter → this screen directly.
#   INFRA-001 (pickup 44) will move this routing into RealmShell.

class_name CombatBoardScreen
extends Control

signal action_requested(action: Dictionary)

@onready var _board: TileMapLayer                   = $Board
@onready var _token_layer: CombatTokenLayer         = $TokenLayer
@onready var _distance_layer: CombatDistanceLayer   = $DistanceLayer  # GRID-004
@onready var _back_button: Button                   = $BackButton
@onready var _round_label: Label                    = $RoundLabel
@onready var _objective_label: Label                = $ObjectiveLabel
@onready var _start_combat_button: Button           = $StartCombatButton

# Clay floor tile: source 0, atlas position (0, 0)
const _TILE_SOURCE_ID:    int       = 0
const _TILE_ATLAS_COORDS: Vector2i  = Vector2i(0, 0)

var _current_cols: int       = 10
var _current_rows: int       = 10
# Cached nav.back action — set in _render(), read in _on_back_pressed().
var _nav_back_action: Dictionary = {}


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	# Wire back button once at startup; action dict is cached per-render.
	_back_button.visible = false
	_back_button.pressed.connect(_on_back_pressed)
	# COMBAT-001: Start Combat button triggers combat.init.
	_start_combat_button.visible = false
	_start_combat_button.pressed.connect(_on_start_combat_pressed)


# -------------------------
# Bespoke screen contract (UI-001)
# -------------------------

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "CombatBoardScreen: snapshot missing 'type'")
	assert(snap.has("data"), "CombatBoardScreen: snapshot missing 'data'")
	_clear()
	_render(snap["data"], snap.get("actions", {}))

func _clear() -> void:
	_board.clear()
	_token_layer.clear_tokens()
	_distance_layer.clear_distances()  # GRID-004
	_back_button.visible = false
	_round_label.visible = false
	_objective_label.visible = false
	_start_combat_button.visible = false
	_nav_back_action = {}

func _render(data: Dictionary, actions: Dictionary) -> void:
	_current_cols = int(data.get("board_cols", 10))
	_current_rows = int(data.get("board_rows", 10))
	_draw_board(_current_cols, _current_rows)
	_center_board(_current_cols, _current_rows)
	# GRID-002: draw actor tokens if the snapshot includes an actor list.
	var actors: Array = data.get("actors", [])
	if not actors.is_empty():
		_draw_tokens(actors)
		# GRID-004: show distance debug overlay from actors[0] as reference.
		_distance_layer.update_distances(actors[0], _board, data)

	# COMBAT-001: render round counter and objective type from snapshot.
	_round_label.text = "Round: %d" % int(data.get("round", 0))
	_round_label.visible = true
	var obj_type: String = str(data.get("objective_type", ""))
	_objective_label.text = obj_type
	_objective_label.visible = not obj_type.is_empty()

	# COMBAT-001: wire cta.combat_init → Start Combat; cta.confirm_round → disabled.
	if actions.has("cta.combat_init"):
		_start_combat_button.text = "Start Combat"
		_start_combat_button.disabled = false
		_start_combat_button.visible = true
	elif actions.has("cta.confirm_round"):
		_start_combat_button.text = "Confirm Round"
		_start_combat_button.disabled = true
		_start_combat_button.visible = true

	# Show back button only when the snapshot supplies a nav.back action.
	if actions.has("nav.back"):
		var action_v: Variant = actions["nav.back"]
		if action_v is Dictionary:
			_nav_back_action = action_v
			_back_button.visible = true


# -------------------------
# Board rendering
# -------------------------

## Places a clay floor tile at every grid cell of the board.
func _draw_board(cols: int, rows: int) -> void:
	for col in range(cols):
		for row in range(rows):
			_board.set_cell(Vector2i(col, row), _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)


## Offsets the TileMapLayer so the grid is visually centred on screen.
## map_to_local() returns the pixel centre of a cell in TileMapLayer-local space.
## The TokenLayer is placed at the same position so its draw coordinates match.
func _center_board(cols: int, rows: int) -> void:
	# Sample the four corner cells to get the visual bounding box.
	var tl: Vector2 = _board.map_to_local(Vector2i(0,        0       ))
	var tr: Vector2 = _board.map_to_local(Vector2i(cols - 1, 0       ))
	var bl: Vector2 = _board.map_to_local(Vector2i(0,        rows - 1))
	var br: Vector2 = _board.map_to_local(Vector2i(cols - 1, rows - 1))

	var grid_center := Vector2(
		(min(tl.x, bl.x) + max(tr.x, br.x)) / 2.0,
		(min(tl.y, tr.y) + max(bl.y, br.y)) / 2.0
	)

	var viewport_center: Vector2 = get_viewport_rect().size / 2.0
	_board.position = viewport_center - grid_center
	# GRID-002: token layer shares the board's coordinate origin.
	_token_layer.position = _board.position
	# GRID-004: distance layer shares the same origin.
	_distance_layer.position = _board.position


## Emits the cached nav.back action when the Back button is pressed.
func _on_back_pressed() -> void:
	if not _nav_back_action.is_empty():
		action_requested.emit(_nav_back_action)


## COMBAT-001: triggers combat.init to initialize CombatState.
func _on_start_combat_pressed() -> void:
	action_requested.emit({ "type": "combat.init" })


func _on_action(action: Dictionary) -> void:
	action_requested.emit(action)


# -------------------------
# Token rendering (GRID-002)
# -------------------------

## Converts the actor list from the snapshot into token descriptors and
## passes them to the CombatTokenLayer for drawing.
## _center_board() must be called first so _board.position is set correctly.
func _draw_tokens(actors: Array) -> void:
	var tokens: Array[Dictionary] = []
	for actor in actors:
		var gp: Dictionary = actor.get("grid_pos", {})
		var col: int = gp.get("col", 0)
		var row: int = gp.get("row", 0)
		# map_to_local() returns the cell centre in TileMapLayer-local space.
		# Since _token_layer.position == _board.position, these coordinates
		# are correct in the token layer's local space without further offset.
		var cell_pos: Vector2 = _board.map_to_local(Vector2i(col, row))
		var faction: String = actor.get("faction", "")
		var shape := "square" if actor.get("is_structure", false) else "circle"
		var name_str: String = actor.get("name", "??")
		tokens.append({
			"pos":   cell_pos,
			"color": _faction_color(faction),
			"shape": shape,
			"label": name_str.substr(0, 2).to_upper(),
		})
	_token_layer.update_tokens(tokens)


## Returns the placeholder colour for a given faction string.
func _faction_color(faction: String) -> Color:
	return CombatTokenLayer.FACTION_COLORS.get(faction, Color.WHITE)
