# res://ui/screens/CombatBoardScreen.gd
# Bespoke combat board screen — renders the isometric grid for flow.encounter.
# GRID-001: Board configuration + isometric floor tile rendering.
#
# Contract (UI-001):
# - set_snapshot(snap: Dictionary) → _clear() + _render(data, actions)
# - action_requested signal for all player interactions
# - Never reads sim internals directly
#
# Routing note (GRID-001 temporary):
#   AppRoot routes flow.encounter → this screen directly.
#   INFRA-001 (pickup 44) will move this routing into RealmShell.
#
# Future GRID stories extend _render() and _clear():
#   GRID-002 — actor tokens drawn at grid_pos cells
#   GRID-004 — distance debug overlay on cells
#   GRID-005 — token positions updated after move_toward()

class_name CombatBoardScreen
extends Control

signal action_requested(action: Dictionary)

@onready var _board: TileMapLayer       = $Board
@onready var _back_button: Button       = $BackButton

# Clay floor tile: source 0, atlas position (0, 0)
const _TILE_SOURCE_ID:    int       = 0
const _TILE_ATLAS_COORDS: Vector2i  = Vector2i(0, 0)

var _current_cols: int       = 6
var _current_rows: int       = 3
# Cached nav.back action — set in _render(), read in _on_back_pressed().
var _nav_back_action: Dictionary = {}


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	# Wire back button once at startup; action dict is cached per-render.
	_back_button.visible = false
	_back_button.pressed.connect(_on_back_pressed)


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
	_back_button.visible = false
	_nav_back_action = {}

func _render(data: Dictionary, actions: Dictionary) -> void:
	_current_cols = int(data.get("board_cols", 6))
	_current_rows = int(data.get("board_rows", 3))
	_draw_board(_current_cols, _current_rows)
	_center_board(_current_cols, _current_rows)
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


## Emits the cached nav.back action when the Back button is pressed.
func _on_back_pressed() -> void:
	if not _nav_back_action.is_empty():
		action_requested.emit(_nav_back_action)


func _on_action(action: Dictionary) -> void:
	action_requested.emit(action)
