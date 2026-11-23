class_name PickupEventStage
extends Control

## The pickup event, drawn over the combat board (V2-ITEM-001b). The stage owns no input and
## never builds an action: it relays the one the strip or the card asks for (U7), and the board forwards it to the shell.
## An event is named by situation_id + run_count. A repeat snapshot of the same event must not
## restart anything, so state is rebuilt only when the identity changes.

## One tick of the intro clock, with the time in seconds. The host places the pointer mote from it.
signal clock_ticked(t: float)
## `pickup.select` for a chosen pack tile or a closed card. Finds are chosen by the board (`PickupHitRules`).
signal action_requested(action: Dictionary)

@onready var _pack_strip: PickupPackStrip = %PickupPackStrip
@onready var _tooltip: CauseTooltip = %CauseTooltip
@onready var _card_layer: CanvasLayer = %CardLayer
@onready var _card: PickupDetailsCard = %PickupDetailsCard

var _identity: String = ""
var _starts: int = 0
var _plan: Dictionary = {}
var _t: float = 0.0
var _running: bool = false


func _ready() -> void:
	set_process(false)
	# A CanvasLayer does not follow the visibility of this Control or of its ancestors (a hidden board hides the card layer too).
	visibility_changed.connect(func() -> void: _card_layer.visible = is_visible_in_tree())
	_pack_strip.pack_chosen.connect(func(id: String) -> void:
		action_requested.emit(PickupHitRules.select_action("pack", id) if not id.is_empty() else PickupHitRules.close_action()))
	_pack_strip.token_shown.connect(_tooltip.show_for)
	_pack_strip.token_hidden.connect(_tooltip.release)
	_card.close_requested.connect(func() -> void: action_requested.emit(PickupHitRules.close_action()))


func _process(delta: float) -> void:
	advance(delta)


static func identity_of(data: Dictionary) -> String:
	return "%s#%d" % [str(data.get("situation_id", "")), int(data.get("run_count", 0))]


## The strip gets every snapshot: it is idempotent and must follow a swap inside the same event.
func apply_snapshot(snapshot: Dictionary) -> void:
	_pack_strip.apply_snapshot(snapshot)
	var data_v: Variant = snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var next := identity_of(data)
	if next == _identity:
		if str(data.get("phase", "")) != "intro":
			_stop()
		return
	_identity = next
	_starts += 1
	_stop()
	if str(data.get("phase", "")) == "intro":
		_start(snapshot)


## Called when the board leaves the event. The next event starts fresh even with the same identity.
func clear() -> void:
	_identity = ""
	_stop()
	_card.hide_card()
	_tooltip.hide_tooltip()


## The intro clock: runs from 0 to `plan.total`, then stops. Public so tests drive time without frames.
func advance(delta: float) -> void:
	if not _running:
		return
	var total := float(_plan["total"])
	_t = minf(_t + delta, total)
	clock_ticked.emit(_t)
	if _t >= total:
		_stop()


func plan() -> Dictionary:
	return _plan


func clock_time() -> float:
	return _t


func is_clock_running() -> bool:
	return _running


func _start(snapshot: Dictionary) -> void:
	var plan := PickupEventPlan.build(snapshot, PickupEventPlan.board_opts())
	if not bool(plan.get("valid", false)):
		return
	_plan = plan
	_t = 0.0
	_running = true
	set_process(true)


func _stop() -> void:
	_running = false
	set_process(false)


func identity() -> String:
	return _identity


func start_count() -> int:
	return _starts


func set_layout(layout: Dictionary) -> void:
	var profile: StringName = layout.get("profile", &"standard")
	_pack_strip.set_profile(profile)


## `bar_top_global`: the top edge of the EchoBar, read by the board from the shell.
func place_pack_strip(bar_top_global: float) -> void:
	_pack_strip.place(bar_top_global)


func pack_strip() -> PickupPackStrip:
	return _pack_strip


func card() -> PickupDetailsCard:
	return _card


func tooltip() -> CauseTooltip:
	return _tooltip
