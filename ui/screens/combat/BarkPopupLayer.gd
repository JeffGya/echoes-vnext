class_name BarkPopupLayer
extends Control

# V2-VOICE-001: Sequential bark popup display layer for CombatBoardScreen.
#
# Receives a pre-sorted, pre-filtered flat list of bark events from CombatBoardScreen
# (originals interleaved with their reactions). Shows each popup in order, waiting for
# the previous to fully fade before showing the next.
#
# Popup visual spec (Living Grove Design System):
#   Original : Dark panel Color("#3D5A47") @ 85% alpha, Akan Gold border Color("#D4AF37")
#   Reaction : Warm light panel Color("#F5E6D3") @ 90% alpha, amber border Color("#b08040")
#
# Authored via scene nodes: BarkPopupOriginal and BarkPopupReaction are Panel/Label combos
# instanced from sub-scenes. This .gd only sets text, position, and drives the Tween.

# ── scene refs ───────────────────────────────────────────────────────────────
@onready var _original_template: Control = $BarkPopupOriginal
@onready var _reaction_template: Control = $BarkPopupReaction

# ── state ────────────────────────────────────────────────────────────────────
var _bark_queue: Array = []   # Array of { bark_line, screen_pos, is_response }
var _busy: bool = false
var _active_tween: Tween = null

# Duration constants (seconds)
const HOLD_DURATION: float    = 2.5
const FADE_IN_DURATION: float = 0.15
const FADE_OUT_DURATION: float = 0.5
const REACTION_DELAY: float   = 0.1   # reaction starts this many seconds after its trigger

# Pixel offsets from the actor token screen position
const ORIGINAL_OFFSET: Vector2  = Vector2(0.0, -72.0)
const REACTION_OFFSET: Vector2  = Vector2(28.0, -50.0)
const REACTION_PREFIX: String   = "↩ "


func _ready() -> void:
	# Both templates start hidden; we instance clones from them.
	if _original_template:
		_original_template.visible = false
	if _reaction_template:
		_reaction_template.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Receives pre-assembled interleaved list: [original, reaction, original, reaction, ...].
## Appends to internal queue and starts processing if idle.
func enqueue_barks(bark_events: Array) -> void:
	for ev_v in bark_events:
		if ev_v is Dictionary:
			_bark_queue.append(ev_v)
	if not _busy:
		_process_next()


## Clears the queue and cancels any active tween. Useful on round transition.
func clear() -> void:
	_bark_queue.clear()
	_busy = false
	if _active_tween:
		_active_tween.kill()
		_active_tween = null
	# Remove any live popup children (not the templates).
	for child in get_children():
		if child != _original_template and child != _reaction_template:
			child.queue_free()


# ── internal ─────────────────────────────────────────────────────────────────

func _process_next() -> void:
	if _bark_queue.is_empty():
		_busy = false
		return
	_busy = true
	var ev: Dictionary = _bark_queue.pop_front()
	_show_bark(ev)


func _show_bark(ev: Dictionary) -> void:
	var is_response: bool = bool(ev.get("is_response", false))
	var bark_line: String = str(ev.get("bark_line", ""))
	var screen_pos: Vector2 = ev.get("screen_pos", Vector2.ZERO)

	if bark_line.is_empty():
		_process_next()
		return

	# Choose template and offset.
	var template: Control = _reaction_template if is_response else _original_template
	if template == null:
		_process_next()
		return

	# Instance a copy from the template.
	var popup: Control = template.duplicate()
	add_child(popup)
	popup.visible = true
	popup.modulate.a = 0.0

	# Set text — look for a Label child named "BarkLabel" or the first Label.
	var label: Label = _find_label(popup)
	if label:
		label.text = (REACTION_PREFIX + bark_line) if is_response else bark_line

	# Position: offset from actor token.
	var offset: Vector2 = REACTION_OFFSET if is_response else ORIGINAL_OFFSET
	popup.position = screen_pos + offset - popup.size * 0.5

	# Entry delay for reactions.
	var entry_delay: float = REACTION_DELAY if is_response else 0.0

	# Animate: delay → fade in → hold → fade out → next.
	var tween: Tween = create_tween()
	_active_tween = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if entry_delay > 0.0:
		tween.tween_interval(entry_delay)

	# Scale-in: 0.9 → 1.0
	popup.scale = Vector2(0.9, 0.9)
	tween.parallel().tween_property(popup, "scale", Vector2(1.0, 1.0), FADE_IN_DURATION)
	tween.parallel().tween_property(popup, "modulate:a", 1.0, FADE_IN_DURATION)

	tween.tween_interval(HOLD_DURATION)
	tween.tween_property(popup, "modulate:a", 0.0, FADE_OUT_DURATION)

	tween.tween_callback(func():
		popup.queue_free()
		_active_tween = null
		_process_next()
	)


func _find_label(node: Control) -> Label:
	# Try the well-known name first.
	var named: Node = node.get_node_or_null("BarkLabel")
	if named is Label:
		return named as Label
	# Fall back to first Label child.
	for child in node.get_children():
		if child is Label:
			return child as Label
	return null
