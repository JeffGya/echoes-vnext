extends Control

## The Sanctum panel, the party pack panel and the details area. One scene for both shells.
## Open state, the selection and the refusal line are UI-local. Contents come from `data.inventory` of the last
## snapshot (flow.sanctum, flow.echo_party, flow.stage_explore); this node never reads the save or the core.
## Moves and discards leave as actions (`inventory.move.apply`, `inventory.discard.apply`, sent by the row and not
## listed in `snapshot.actions`); the discard asks the player first through the modal `inventory.discard`.
## The core refuses what is not allowed and returns no reason. This node predicts the refusal from the snapshot
## (ItemMovePlan) and shows the line before it dispatches. A move that changed nothing shows the generic line.
##
## Rules: each panel opens alone (D-35). The pack panel shows no counts (D-39). On a path nothing moves and one
## pack piece may be let go (D-33).

signal action_requested(action: Dictionary)
signal modal_requested(modal_id: StringName, payload: Dictionary)
signal open_state_changed

const ItemUiText := preload("res://ui/components/ItemUiText.gd")
const ItemMovePlan := preload("res://ui/components/ItemMovePlan.gd")
const SlotScene := preload("res://ui/components/ItemSlot.tscn")
const SANCT := ItemMovePlan.BOX_SANCT
const PACK := ItemMovePlan.BOX_PACK
const MODE_SANCTUM := "sanctum"
const MODE_PATH := "path"
const DISCARD_MODAL := &"inventory.discard"
const REFUSE_SECONDS := 3.2
const LETGO_LOCK_MSEC := 600
const PULSE_SECONDS := 0.4
const PATH_TOP_EXTRA := 64
const BED_STANDARD := 72
const BED_WIDE := 80
const COLUMN_STANDARD := 360.0
const COLUMN_WIDE := 400.0

@onready var _dim: Control = %Dim
@onready var _work: MarginContainer = %Work
@onready var _spacer: Control = %Spacer
@onready var _column: BoxContainer = %Column
@onready var _details_panel: PanelContainer = %DetailsPanel
@onready var _sanct_panel: PanelContainer = %SanctumPanel
@onready var _sanct_title: Label = %SanctTitle
@onready var _sanct_sub: Label = %SanctSub
@onready var _show_pack: Button = %ShowPackButton
@onready var _sanct_close: Button = %SanctClose
@onready var _sanct_grid: GridContainer = %SanctGrid
@onready var _sanct_meter: Control = %SanctMeter
@onready var _slots_label: Label = %SlotsLabel
@onready var _full_label: Label = %FullLabel
@onready var _sanct_refuse: PanelContainer = %SanctRefuse
@onready var _sanct_refuse_label: Label = %SanctRefuseLabel
@onready var _pack_panel: PanelContainer = %PackPanel
@onready var _load_mark: Control = %LoadMark
@onready var _pack_title: Label = %PackTitle
@onready var _pack_sub: Label = %PackSub
@onready var _pack_close: Button = %PackClose
@onready var _path_bar: VBoxContainer = %PathBar
@onready var _path_readonly: Label = %PathReadonly
@onready var _path_token: Label = %PathToken
@onready var _pack_grid: GridContainer = %PackGrid
@onready var _pack_word: Label = %PackWord
@onready var _pack_refuse: PanelContainer = %PackRefuse
@onready var _pack_refuse_label: Label = %PackRefuseLabel
@onready var _details_title: Label = %DetailsTitle
@onready var _details_empty: VBoxContainer = %DetailsEmpty
@onready var _empty_label: Label = %EmptyLabel
@onready var _hint_label: Label = %HintLabel
@onready var _details_full: VBoxContainer = %DetailsFull
@onready var _big_tile: Button = %BigTile
@onready var _name_label: Label = %NameLabel
@onready var _kind_label: Label = %KindLabel
@onready var _grade_label: Label = %GradeLabel
@onready var _count_label: Label = %CountLabel
@onready var _stake_row: HBoxContainer = %StakeRow
@onready var _stake_label: Label = %StakeLabel
@onready var _where_label: Label = %WhereLabel
@onready var _move_button: Button = %MoveButton
@onready var _letgo_button: Button = %LetGoButton
@onready var _move_reason: Label = %MoveReason
@onready var _letgo_reason: Label = %LetGoReason
@onready var _path_note: Label = %PathNote

var _mode := ""
var _dock := "left"
var _snap_type := ""
var _inv: Dictionary = {}
var _sanct_open := false
var _pack_open := false
var _sel_box := ""
var _sel_slot := -1
var _wide := false
var _margin_right := 16
var _safe := Vector4.ZERO
var _col_w := COLUMN_STANDARD
var _awaiting := false
var _awaiting_hash := 0
var _prev_full := { SANCT: false, PACK: false }
var _have_prev := false
var _move_blocked := ""
var _letgo_blocked := ""
var _hint_box := ""
var _last_to := ""
var _pack_level := 0
var _tone_tween: Tween = null
var _line_timer: Tween = null
var _letgo_lock_until := 0


func _ready() -> void:
	_sanct_title.text = ItemUiText.SANCT_TITLE
	_sanct_sub.text = ItemUiText.SANCT_SUB
	_sanct_close.tooltip_text = ItemUiText.CLOSE_SANCT
	_pack_title.text = ItemUiText.PACK_TITLE
	_pack_sub.text = ItemUiText.PACK_SUB
	_pack_close.tooltip_text = ItemUiText.CLOSE_PACK
	_full_label.text = ItemUiText.FULL_WORD
	_details_title.text = ItemUiText.DETAILS_TITLE
	_empty_label.text = ItemUiText.DETAILS_EMPTY
	_hint_label.text = ItemUiText.DETAILS_HINT
	_letgo_button.text = ItemUiText.BTN_LET_GO
	_path_readonly.text = ItemUiText.PATH_READONLY
	_sanct_close.pressed.connect(_close_sanctum)
	_pack_close.pressed.connect(_close_pack)
	_show_pack.pressed.connect(toggle_pack)
	_move_button.pressed.connect(_on_move_pressed)
	_letgo_button.pressed.connect(_on_letgo_pressed)
	for panel in [_sanct_panel, _pack_panel]:
		panel.planner = Callable(self, "_plan_for_drag")
		panel.drop_requested.connect(_on_panel_drop)
		panel.hover_changed.connect(_on_panel_hover)
	_sanct_panel.box = SANCT
	_pack_panel.box = PACK
	_apply_visibility()


# ── Host API ───────────────────────────────────────────────────

func set_snapshot(snap: Dictionary) -> void:
	var snap_type := str(snap.get("type", ""))
	var mode := ""
	if snap_type == "flow.sanctum" or snap_type == "flow.echo_party":
		mode = MODE_SANCTUM
	elif snap_type == "flow.stage_explore":
		mode = MODE_PATH
	if snap_type != _snap_type:
		_reset_local()
	_snap_type = snap_type
	_mode = mode
	_apply_margins()
	_dock = "left" if snap_type == "flow.sanctum" else "right"
	var data_v: Variant = snap.get("data", {})
	var inv_v: Variant = (data_v as Dictionary).get("inventory", {}) if data_v is Dictionary else {}
	_inv = inv_v if inv_v is Dictionary else {}
	if _mode.is_empty() or _inv.is_empty():
		_inv = {}
		_awaiting = false
		_reset_local()
		_apply_visibility()
		open_state_changed.emit()
		return
	# The refusal line lives for one snapshot: a snapshot without the key clears it.
	var refused_v: Variant = _inv.get("refused", null)
	_clear_lines()
	if refused_v is Dictionary:
		_awaiting = false
		var reason := str((refused_v as Dictionary).get("reason", ""))
		_flash(_refusal_box(), ItemUiText.reason_text(reason, _last_to))
	elif _awaiting:
		_awaiting = false
		if _inv.hash() == _awaiting_hash:
			_flash(_sel_box if not _sel_box.is_empty() else SANCT, ItemUiText.R_UNKNOWN)
	_render()
	open_state_changed.emit()


func set_layout(layout: Dictionary) -> void:
	_wide = layout.get("profile", &"standard") == &"wide"
	_safe = layout.get("safe_insets", Vector4.ZERO)
	_apply_margins()
	_col_w = COLUMN_WIDE if _wide else COLUMN_STANDARD
	_pack_panel.custom_minimum_size.x = _col_w
	_details_panel.custom_minimum_size.x = _col_w
	if not _inv.is_empty():
		_render()


## The path view keeps the top HUD and the directive badge clear.
func _apply_margins() -> void:
	_work.add_theme_constant_override("margin_left", maxi(16, int(ceilf(_safe.x))))
	_work.add_theme_constant_override("margin_top", maxi(16, int(ceilf(_safe.y))) + (PATH_TOP_EXTRA if _mode == MODE_PATH else 0))
	_margin_right = maxi(16, int(ceilf(_safe.z)))
	_work.add_theme_constant_override("margin_right", _margin_right)


## The space above the persistent bottom chrome that panels must not cover.
func set_bottom_content_exclusion(px: int) -> void:
	_work.add_theme_constant_override("margin_bottom", px + 8)


func toggle_sanctum() -> void:
	if _mode != MODE_SANCTUM:
		return
	if _sanct_open:
		_close_sanctum()
	else:
		_sanct_open = true
		_after_open_change()


func toggle_pack() -> void:
	if _mode.is_empty() or _inv.is_empty():
		return
	if _pack_open:
		_close_pack()
	else:
		_pack_open = true
		_after_open_change()


func is_sanctum_open() -> bool:
	return _sanct_open and _mode == MODE_SANCTUM


func is_pack_open() -> bool:
	return _pack_open and not _mode.is_empty()


func mode() -> String:
	return _mode


func close_all() -> void:
	_reset_local()
	_apply_visibility()
	open_state_changed.emit()


## Width the host screen gives up on the right while the column is docked there. 0 when nothing is docked.
func right_inset() -> int:
	if _dock == "right" and _column.visible:
		return int(_col_w) + 12 + _margin_right
	return 0


## The discard modal closed (Keep it or Let it go). `Let it go` ignores presses for 0.6 s so a double tap cannot
## open a second confirmation.
func note_discard_modal_closed() -> void:
	_letgo_lock_until = Time.get_ticks_msec() + LETGO_LOCK_MSEC


func selected() -> Dictionary:
	return { "box": _sel_box, "slot": _sel_slot }


# ── State ──────────────────────────────────────────────────────

func _reset_local() -> void:
	_sanct_open = false
	_pack_open = false
	_sel_box = ""
	_sel_slot = -1
	_last_to = ""
	_awaiting = false
	_have_prev = false
	_prev_full = { SANCT: false, PACK: false }


func _close_sanctum() -> void:
	_sanct_open = false
	if _sel_box == SANCT:
		_clear_selection()
	_after_open_change()


func _close_pack() -> void:
	_pack_open = false
	if _sel_box == PACK:
		_clear_selection()
	_after_open_change()


func _after_open_change() -> void:
	_apply_visibility()
	if not _inv.is_empty():
		_render()
	open_state_changed.emit()


func _clear_selection() -> void:
	_sel_box = ""
	_sel_slot = -1


func _apply_visibility() -> void:
	var sanct_vis := _sanct_open and _mode == MODE_SANCTUM
	var pack_vis := _pack_open and not _mode.is_empty()
	_sanct_panel.visible = sanct_vis
	_pack_panel.visible = pack_vis
	_column.visible = sanct_vis or pack_vis
	# On a path the pack and the details sit side by side, so the column stays short and clears the bottom buttons.
	_column.vertical = _mode != MODE_PATH
	_dim.visible = _column.visible
	_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _dock == "right" else 0
	var show_toggle := _dock == "left" and _mode == MODE_SANCTUM
	_show_pack.visible = show_toggle
	_show_pack.button_pressed = _pack_open
	_show_pack.text = ItemUiText.HIDE_PACK if _pack_open else ItemUiText.SHOW_PACK


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (is_pack_open() or is_sanctum_open()):
		get_viewport().set_input_as_handled()
		if is_pack_open():
			_close_pack()
		else:
			_close_sanctum()


# ── Drawing ────────────────────────────────────────────────────

func _render() -> void:
	_apply_visibility()
	var bed := BED_WIDE if _wide else BED_STANDARD
	var drag_ok := _mode == MODE_SANCTUM
	_fill_grid(_sanct_grid, SANCT, bed, drag_ok)
	_fill_grid(_pack_grid, PACK, bed, drag_ok)
	var cap_s := ItemMovePlan.capacity(_inv, SANCT)
	_sanct_grid.columns = 5 if cap_s <= 20 else 6
	_pack_grid.columns = 4
	_render_sanctum_gauge(cap_s)
	_render_pack_state()
	_update_pulses()
	_refresh_selection()


func _fill_grid(grid: GridContainer, box: String, bed: int, drag_ok: bool) -> void:
	var n := ItemMovePlan.drawn_slots(_inv, box)
	while grid.get_child_count() < n:
		var slot := SlotScene.instantiate()
		grid.add_child(slot)
		slot.chosen.connect(_on_slot_chosen)
		slot.drop_requested.connect(_on_slot_drop)
		slot.hover_changed.connect(_on_slot_hover)
		slot.planner = Callable(self, "_plan_for_drag")
	while grid.get_child_count() > n:
		var last := grid.get_child(grid.get_child_count() - 1)
		grid.remove_child(last)
		last.queue_free()
	for i in n:
		var slot := grid.get_child(i)
		slot.setup(box, i, bed)
		slot.set_content(ItemMovePlan.entry_at(_inv, box, i), { "bed": bed, "drag": drag_ok })


func _render_sanctum_gauge(cap_s: int) -> void:
	var room := int(_inv.get("sanctum_room", 0))
	var warn_v: Variant = _inv.get("warn", {})
	var warn: Dictionary = warn_v if warn_v is Dictionary else {}
	var full := cap_s > 0 and room <= 0
	_sanct_meter.total = cap_s
	_sanct_meter.used = int(_inv.get("sanctum_used", 0))
	_sanct_meter.level = "full" if full else ("near" if bool(warn.get("room", false)) else "")
	_slots_label.text = ItemUiText.slots_word(int(_inv.get("sanctum_used", 0)), cap_s)
	_full_label.visible = full


func _render_pack_state() -> void:
	var load_v: Variant = _inv.get("pack_load", {})
	var load_info: Dictionary = load_v if load_v is Dictionary else {}
	var level := int(load_info.get("level", 0))
	var on_path := _mode == MODE_PATH
	_load_mark.level = level
	_pack_level = level
	# Three levels read apart by tone and wording: plain, darker near full, darkest at full.
	_pack_panel.theme_type_variation = &"ItemPanelPackHeavy" if level >= 3 else (&"ItemPanelPackNear" if level == 2 else &"ItemPanelPack")
	_pack_word.visible = level >= 2
	if level >= 3:
		_pack_word.text = ItemUiText.PACK_FULL_PATH if on_path else ItemUiText.PACK_HEAVY
	elif level == 2:
		_pack_word.text = ItemUiText.PACK_NEAR
	_path_bar.visible = on_path
	if on_path:
		var path_v: Variant = _inv.get("path", {})
		var path: Dictionary = path_v if path_v is Dictionary else {}
		_path_token.text = ItemUiText.PATH_USED if bool(path.get("discard_used", false)) else ItemUiText.PATH_LEFT


## One pulse on every transition into full (D-36, D-39). The first render only records the state.
func _update_pulses() -> void:
	var sanct_full: bool = _sanct_meter.level == "full"
	var pack_full := _pack_level >= 3
	if _have_prev:
		var reduced := StopMarkMotion.reduced
		var seconds := 0.15 if reduced else PULSE_SECONDS
		if sanct_full and not _prev_full[SANCT] and _sanct_panel.visible:
			_sanct_meter.pulse(seconds, reduced)
		if pack_full and not _prev_full[PACK] and _pack_panel.visible:
			_pulse_pack_tone(seconds, reduced)
	_prev_full[SANCT] = sanct_full
	_prev_full[PACK] = pack_full
	_have_prev = true


## The pack pulse acts on the panel tone only: a brightness flash (0.4 s), or a 0.15 s fade in reduced motion.
func _pulse_pack_tone(seconds: float, reduced: bool) -> void:
	if _tone_tween != null and _tone_tween.is_valid():
		_tone_tween.kill()
	_tone_tween = create_tween()
	if reduced:
		_pack_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_tone_tween.tween_property(_pack_panel, "modulate:a", 1.0, seconds)
	else:
		_pack_panel.modulate = Color(1.3, 1.3, 1.3, 1.0)
		_tone_tween.tween_property(_pack_panel, "modulate", Color.WHITE, seconds)


func _refresh_selection() -> void:
	var row := ItemMovePlan.entry_at(_inv, _sel_box, _sel_slot) if _sel_slot >= 0 else {}
	if row.is_empty():
		_clear_selection()
	for grid in [_sanct_grid, _pack_grid]:
		for slot in grid.get_children():
			slot.tile().set_selected(slot.box == _sel_box and slot.index == _sel_slot and slot.has_content())
	_hint_label.text = ItemUiText.PATH_HINT if _mode == MODE_PATH else ItemUiText.DETAILS_HINT
	_details_empty.visible = row.is_empty()
	_details_full.visible = not row.is_empty()
	if row.is_empty():
		_move_blocked = ""
		_letgo_blocked = ""
		return
	var in_pack := _sel_box == PACK
	var stack := ItemMovePlan.is_stack(row)
	_big_tile.setup(row, { "box": _sel_box, "bed": 88 if not _wide else 96 })
	_big_tile.set_selected(false)
	_name_label.text = ItemUiText.display_name(row)
	_kind_label.text = "%s: %s" % [ItemUiText.KIND_LABEL, ItemUiText.kind_name(str(row.get("kind", "")))]
	var pips: int = _big_tile.pips_of(row)
	_grade_label.visible = not stack and pips > 0
	_grade_label.text = "%s: %d" % [ItemUiText.GRADE_LABEL, pips]
	if stack:
		var limit_text := ItemUiText.stack_count(int(row.get("count", 0)), int(row.get("stack_limit", 0)))
		_count_label.text = "%s: %s%s" % [ItemUiText.COUNT_LABEL, limit_text,
			(" " + ItemUiText.AT_LIMIT) if bool(row.get("at_limit", false)) else ""]
	else:
		_count_label.text = "%s: %s" % [ItemUiText.COUNT_LABEL, ItemUiText.ONE_PIECE]
	_stake_row.visible = in_pack
	_stake_label.text = ItemUiText.AT_STAKE
	_where_label.text = ItemUiText.WHERE_PACK if in_pack else ItemUiText.WHERE_SANCT
	var to_box := SANCT if in_pack else PACK
	_move_button.text = ItemUiText.BTN_MOVE_SANCT if in_pack else ItemUiText.BTN_MOVE_PACK
	var move_plan := ItemMovePlan.plan(_inv, _sel_box, _sel_slot, to_box, -1)
	_move_blocked = str(move_plan.get("reason", "")) if str(move_plan.get("kind", "")) == "refuse" else ""
	_move_button.theme_type_variation = &"ItemButtonBlocked" if not _move_blocked.is_empty() else &"ItemButtonGold"
	_move_reason.visible = not _move_blocked.is_empty()
	_move_reason.text = "%s: %s" % [_move_button.text, ItemUiText.reason_text(_move_blocked, to_box)]
	_letgo_blocked = ItemMovePlan.discard_block(_inv, _sel_box)
	_letgo_button.theme_type_variation = &"ItemButtonBlocked" if not _letgo_blocked.is_empty() else &"ItemButtonOutline"
	_letgo_reason.visible = not _letgo_blocked.is_empty()
	_letgo_reason.text = "%s: %s" % [ItemUiText.BTN_LET_GO, ItemUiText.reason_text(_letgo_blocked)]
	_path_note.visible = _mode == MODE_PATH and _letgo_blocked.is_empty()
	_path_note.text = ItemUiText.PATH_RULE


# ── Input ──────────────────────────────────────────────────────

func _on_slot_chosen(box: String, index: int) -> void:
	if index < 0:
		_clear_selection()
	else:
		_sel_box = box
		_sel_slot = index
	_refresh_selection()


func _plan_for_drag(data: Variant, box: String, index: int) -> Dictionary:
	if not (data is Dictionary):
		return { "kind": "none", "reason": "", "to_slot": -1 }
	var d: Dictionary = data
	return ItemMovePlan.plan(_inv, str(d.get("from", "")), int(d.get("slot", -1)), box, index)


func _on_slot_hover(box: String, index: int, plan: Dictionary) -> void:
	_hint(box, plan)


func _on_panel_hover(box: String, plan: Dictionary) -> void:
	_hint(box, plan)


func _hint(box: String, plan: Dictionary) -> void:
	var text := ""
	match str(plan.get("kind", "")):
		"refuse":
			text = ItemUiText.reason_text(str(plan.get("reason", "")), box)
		"merge":
			text = ItemUiText.DROP_MERGE
		"reorder":
			text = ItemUiText.DROP_REORDER
		"place":
			text = ItemUiText.DROP_PACK if box == PACK else ItemUiText.DROP_SANCT
	_hint_box = box
	_show_line(box, text)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and not _hint_box.is_empty():
		_show_line(_hint_box, "")
		_hint_box = ""


func _on_slot_drop(data: Dictionary, box: String, index: int) -> void:
	_do_move(str(data.get("from", "")), int(data.get("slot", -1)), box, index)


func _on_panel_drop(data: Dictionary, box: String) -> void:
	_do_move(str(data.get("from", "")), int(data.get("slot", -1)), box, -1)


func _on_move_pressed() -> void:
	if _sel_slot < 0:
		return
	var to_box := SANCT if _sel_box == PACK else PACK
	if not _move_blocked.is_empty():
		_flash(to_box, ItemUiText.reason_text(_move_blocked, to_box))
		return
	_do_move(_sel_box, _sel_slot, to_box, -1)


func _on_letgo_pressed() -> void:
	if _sel_slot < 0 or Time.get_ticks_msec() < _letgo_lock_until:
		return
	if not _letgo_blocked.is_empty():
		_flash(_sel_box, ItemUiText.reason_text(_letgo_blocked))
		return
	var row := ItemMovePlan.entry_at(_inv, _sel_box, _sel_slot)
	if row.is_empty():
		return
	var stack := ItemMovePlan.is_stack(row)
	modal_requested.emit(DISCARD_MODAL, {
		"row": row.duplicate(true), "box": _sel_box, "slot": _sel_slot,
		"stack": stack, "count_max": int(row.get("count", 1)) if stack else 1,
		"path": _mode == MODE_PATH,
	})


## Sends one move. A predicted refusal stays here: the core is not asked.
func _do_move(from: String, slot: int, to: String, to_slot: int) -> void:
	if _mode != MODE_SANCTUM:
		_flash(to, ItemUiText.reason_text("path_open"))
		return
	var plan := ItemMovePlan.plan(_inv, from, slot, to, to_slot)
	match str(plan.get("kind", "")):
		"none":
			return
		"refuse":
			_flash(to, ItemUiText.reason_text(str(plan.get("reason", "")), to))
			return
	_last_to = to
	_sel_box = to
	_sel_slot = int(plan.get("to_slot", -1))
	_awaiting = true
	_awaiting_hash = _inv.hash()
	action_requested.emit({
		"type": "inventory.move.apply",
		"payload": { "from": from, "slot": slot, "to": to, "to_slot": to_slot },
	})


# ── Reason line ────────────────────────────────────────────────

func _clear_lines() -> void:
	_show_line(SANCT, "")
	_show_line(PACK, "")


## The panel that shows a refusal from the core: the selected piece's box (a move already selects its target), else the open panel.
func _refusal_box() -> String:
	if not _sel_box.is_empty():
		return _sel_box
	return SANCT if _sanct_panel.visible else PACK


func _flash(box: String, text: String) -> void:
	var target := box
	if (target == PACK and not _pack_panel.visible) or (target == SANCT and not _sanct_panel.visible):
		target = SANCT if _sanct_panel.visible else PACK
	_show_line(target, text)
	if _line_timer != null and _line_timer.is_valid():
		_line_timer.kill()
	if text.is_empty() or not is_inside_tree():
		return
	_line_timer = create_tween()
	_line_timer.tween_interval(REFUSE_SECONDS)
	_line_timer.tween_callback(_show_line.bind(target, ""))


func _show_line(box: String, text: String) -> void:
	var panel := _sanct_refuse if box == SANCT else _pack_refuse
	var label := _sanct_refuse_label if box == SANCT else _pack_refuse_label
	panel.visible = not text.is_empty()
	label.text = text
