extends VBoxContainer

## The item tiles inside a result card or the leave confirmation: ONE row, survivors first (state kept), then lost
## (ghost outline). It names no place and carries no lane title (D-42). A name shows on focus or tap.
## Motion: every tile appears in turn; a lost tile then fades to its ghost. The whole sequence ends within
## SEQ_CAP seconds. Reduced motion (`StopMarkMotion.reduced`) is a 0.15 s fade for each beat. `finish()` jumps to the
## final state. `absorb_continue()` makes the first tap finish the motion and ignores Continue for 0.25 s after it.
## Report rows: { type_id, kind, grade, quantity, source, mark_index, reason_key, lost_quantity?, name? }.

signal finished

const ItemUiText := preload("res://ui/components/ItemUiText.gd")
const TileScene := preload("res://ui/components/ItemTile.tscn")
const SEQ_CAP := 2.4
const LINE_SECONDS := 0.25
const HOLD_SECONDS := 0.3
const STAGGER_FEW := 0.3
const STAGGER_MANY := 0.15
const REVEAL_SECONDS := 0.25
const LOST_SECONDS := 0.5
const RM_FADE := 0.15
const RM_STAGGER := 0.1
const CONTINUE_GUARD_MSEC := 250

@onready var _tiles: HFlowContainer = %Tiles
@onready var _name_line: Label = %NameLine
@onready var _risk_line: Label = %RiskLine
@onready var _preview_tag: Label = %PreviewTag

var _tile_nodes: Array = []
var _fates: Array = []
var _motion: Tween = null
var _running := false
var _final_msec := -100000


## Timing of the sequence for `n` tiles. Pure; tests read it.
static func plan(n: int, reduced: bool) -> Dictionary:
	var t0 := LINE_SECONDS if reduced else LINE_SECONDS + HOLD_SECONDS
	var d := RM_FADE if reduced else LOST_SECONDS
	var base := RM_STAGGER if reduced else (STAGGER_FEW if n <= 4 else STAGGER_MANY)
	var st := 0.0
	if n > 1:
		st = minf(base, maxf(0.0, (SEQ_CAP - t0 - d) / float(n - 1)))
	return { "t0": t0, "d": d, "st": st, "total": (t0 + float(n - 1) * st + d) if n > 0 else t0 }


## The row sits on a dark surface (the leave confirmation) or a light card.
func set_on_dark(on: bool) -> void:
	var variation := &"ItemTextDark" if on else &"ItemTextLight"
	_name_line.theme_type_variation = variation
	_risk_line.theme_type_variation = variation


func clear() -> void:
	_kill_motion()
	for t in _tile_nodes:
		_tiles.remove_child(t)
		t.queue_free()
	_tile_nodes = []
	_fates = []
	_name_line.text = ""
	_risk_line.visible = false
	_preview_tag.visible = false
	visible = false


## Builds the row from a report: `kept` rows first, then `lost` rows. A kept stack with `lost_quantity` adds a
## ghost tile for the part that was lost. No motion: call `play()` or `finish()`.
func show_report(kept: Array, lost: Array, preview: bool = false, bed: int = 72) -> void:
	clear()
	for r in kept:
		if not (r is Dictionary):
			continue
		_add_tile(r, "kept", bed)
		var lq := int((r as Dictionary).get("lost_quantity", 0))
		if lq > 0:
			var ghost: Dictionary = (r as Dictionary).duplicate()
			ghost["quantity"] = lq
			ghost.erase("lost_quantity")
			_add_tile(ghost, "lost", bed)
	for r in lost:
		if r is Dictionary:
			_add_tile(r, "lost", bed)
	_preview_tag.text = ItemUiText.CARD_PREVIEW
	_preview_tag.visible = preview and not _tile_nodes.is_empty()
	visible = not _tile_nodes.is_empty()


## The leave confirmation: at-risk tiles with the leaf, a line that names no place. Rows have no `reason_key`.
func show_at_risk(rows: Array, bed: int = 72) -> void:
	clear()
	for r in rows:
		if r is Dictionary:
			_add_tile(r, "at_risk", bed)
	_risk_line.text = ItemUiText.leave_risk(_tile_nodes.size())
	_risk_line.visible = not _tile_nodes.is_empty()
	visible = not _tile_nodes.is_empty()


func tile_count() -> int:
	return _tile_nodes.size()


func tiles() -> Array:
	return _tile_nodes


func fates() -> Array:
	return _fates


func is_running() -> bool:
	return _running


func _add_tile(row: Dictionary, fate: String, bed: int) -> void:
	var tile := TileScene.instantiate() as Button
	_tiles.add_child(tile)
	tile.setup(row, { "state": fate, "source": str(row.get("source", "")), "bed": bed })
	tile.focus_entered.connect(_show_name.bind(tile, fate))
	tile.pressed.connect(_show_name.bind(tile, fate))
	_tile_nodes.append(tile)
	_fates.append(fate)


func _show_name(tile: Button, fate: String) -> void:
	var word := ""
	match fate:
		"kept":
			word = ItemUiText.CARD_SURVIVED
		"lost":
			word = ItemUiText.CARD_LOST
	_name_line.text = tile.describe() if word.is_empty() else "%s: %s" % [tile.describe(), word]


## Plays the sequence. Lost tiles start as plain tiles and fade to their ghost; kept tiles appear as survivors.
func play() -> void:
	_kill_motion()
	var n := _tile_nodes.size()
	if n == 0 or not is_inside_tree():
		_reach_final()
		return
	var reduced := StopMarkMotion.reduced
	var p := plan(n, reduced)
	for i in n:
		var tile: Button = _tile_nodes[i]
		if _fates[i] == "lost":
			tile.apply_state("")
		tile.modulate.a = 0.0
	_running = true
	_motion = create_tween().set_parallel(true)
	for i in n:
		_motion.tween_callback(_play_tile.bind(i, reduced)).set_delay(float(p["t0"]) + float(i) * float(p["st"]))
	_motion.tween_callback(_reach_final).set_delay(float(p["total"]))


func _play_tile(i: int, reduced: bool) -> void:
	var tile: Button = _tile_nodes[i]
	if not is_instance_valid(tile):
		return
	if _fates[i] == "lost":
		tile.reveal(RM_FADE if reduced else REVEAL_SECONDS, 0.0)
		tile.play_lost(RM_FADE if reduced else LOST_SECONDS, 0.0 if reduced else tile.LIFT)
	else:
		tile.reveal(RM_FADE if reduced else REVEAL_SECONDS, 0.0 if reduced else tile.REVEAL_RISE)


## First tap: ends the motion at the final state. Also used when the card is shown again (no replay).
func finish() -> void:
	_kill_motion()
	for i in _tile_nodes.size():
		var tile: Button = _tile_nodes[i]
		tile.modulate.a = 1.0
		tile.apply_state(_fates[i])
	_reach_final()


## True when a Continue press must be ignored: the motion was running (this press finishes it) or the final
## state came less than 0.25 s ago.
func absorb_continue() -> bool:
	if _tile_nodes.is_empty():
		return false
	if _running:
		finish()
		return true
	return Time.get_ticks_msec() - _final_msec < CONTINUE_GUARD_MSEC


func _reach_final() -> void:
	var was_running := _running
	_running = false
	_final_msec = Time.get_ticks_msec()
	if was_running:
		finished.emit()


func _kill_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	_running = false
