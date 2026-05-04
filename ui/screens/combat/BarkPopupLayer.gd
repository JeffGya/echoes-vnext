class_name BarkPopupLayer
extends Control

# V2-VOICE-002: Simultaneous per-actor bark popup layer for CombatBoardScreen.
#
# Each echo can show their own speech bubble at the same time.
# Positions update every render pass so bubbles follow moving tokens.
# Reactions appear 0.4s after their trigger (call-and-response feel).
#
# Popup visual spec (Living Grove Design System) — authored in BarkPopupLayer.tscn:
#   Original : Dark forest green panel, Akan Gold border, rounded corners, triangle tail
#   Reaction : Warm cream panel, amber border, rounded corners, triangle tail
#
# This .gd only sets text, position, modulate, and drives Tweens.
# No nodes or StyleBoxes are created here (Lesson 5).

# ── scene refs ───────────────────────────────────────────────────────────────
@onready var _original_template: Control = $BarkPopupOriginal
@onready var _reaction_template: Control = $BarkPopupReaction

# ── state ────────────────────────────────────────────────────────────────────
# actor_id → { "node": Control, "tween": Tween, "offset": Vector2 }
var _active_popups: Dictionary = {}

# Duration constants (seconds)
const HOLD_DURATION: float      = 2.5
const FADE_IN_DURATION: float   = 0.15
const FADE_OUT_DURATION: float  = 0.5
const REACTION_DELAY: float     = 0.4   # reactions appear this many seconds after originals

# Pixel offsets from the actor token screen position (bubble center → token)
const ORIGINAL_OFFSET: Vector2 = Vector2(0.0, -72.0)
const REACTION_OFFSET: Vector2 = Vector2(28.0, -50.0)
const REACTION_PREFIX: String  = "↩ "


func _ready() -> void:
	if _original_template:
		_original_template.visible = false
	if _reaction_template:
		_reaction_template.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows bark events. Originals appear immediately; reactions after REACTION_DELAY seconds.
## A second bark for the same actor replaces the existing popup (refreshes text + duration).
func show_barks(bark_events: Array) -> void:
	var originals: Array = []
	var reactions: Array = []
	for ev_v in bark_events:
		if not (ev_v is Dictionary):
			continue
		if bool(ev_v.get("is_response", false)):
			reactions.append(ev_v)
		else:
			originals.append(ev_v)

	for ev in originals:
		_show_bark_popup(ev)

	if not reactions.is_empty():
		get_tree().create_timer(REACTION_DELAY).timeout.connect(
			func() -> void:
				for ev in reactions:
					_show_bark_popup(ev),
			CONNECT_ONE_SHOT
		)


## Repositions all active popups to match current actor positions.
## Removes popups for actors no longer present (dead / left combat).
## positions: Dictionary — actor_id (String) → screen_pos (Vector2) in BarkPopupLayer local space.
func update_actor_positions(positions: Dictionary) -> void:
	var dead_ids: Array = []
	for actor_id in _active_popups.keys():
		if not positions.has(actor_id):
			dead_ids.append(actor_id)
			continue
		var entry: Dictionary = _active_popups[actor_id]
		var popup: Control = entry.get("node")
		if popup == null or not is_instance_valid(popup):
			dead_ids.append(actor_id)
			continue
		var offset: Vector2 = entry.get("offset", ORIGINAL_OFFSET)
		var screen_pos: Vector2 = positions[actor_id]
		var sz: Vector2 = popup.size
		if sz == Vector2.ZERO:
			sz = popup.get_combined_minimum_size()
		popup.position = screen_pos + offset - sz * 0.5

	for actor_id in dead_ids:
		_kill_popup(actor_id)


## Kills all active popups immediately. Call on combat-end.
func clear_all() -> void:
	for actor_id in _active_popups.keys().duplicate():
		_kill_popup(actor_id)


# ── internal ─────────────────────────────────────────────────────────────────

func _show_bark_popup(ev: Dictionary) -> void:
	var actor_id: String  = str(ev.get("actor_id", ""))
	var bark_line: String = str(ev.get("bark_line", ""))
	if bark_line.is_empty() or actor_id.is_empty():
		return

	# Replace existing popup for this actor (same echo barking again).
	if _active_popups.has(actor_id):
		_kill_popup(actor_id)

	var is_response: bool = bool(ev.get("is_response", false))
	var template: Control = _reaction_template if is_response else _original_template
	if template == null:
		return

	var popup: Control = template.duplicate()
	add_child(popup)
	popup.visible = true
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.9, 0.9)

	var label: Label = _find_label(popup)
	if label:
		label.text = (REACTION_PREFIX + bark_line) if is_response else bark_line

	# Initial position from the event's screen_pos (will be refined by update_actor_positions).
	var offset: Vector2 = REACTION_OFFSET if is_response else ORIGINAL_OFFSET
	var screen_pos: Vector2 = ev.get("screen_pos", Vector2.ZERO)
	var min_sz: Vector2 = popup.get_combined_minimum_size()
	popup.position = screen_pos + offset - min_sz * 0.5

	# Animate: fade in → hold → fade out → free.
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.parallel().tween_property(popup, "scale", Vector2(1.0, 1.0), FADE_IN_DURATION)
	tween.parallel().tween_property(popup, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.tween_interval(HOLD_DURATION)
	tween.tween_property(popup, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(func() -> void:
		_active_popups.erase(actor_id)
		popup.queue_free()
	)

	_active_popups[actor_id] = { "node": popup, "tween": tween, "offset": offset }


func _kill_popup(actor_id: String) -> void:
	if not _active_popups.has(actor_id):
		return
	var entry: Dictionary = _active_popups[actor_id]
	var tw: Tween = entry.get("tween")
	if tw:
		tw.kill()
	var node: Control = entry.get("node")
	if node and is_instance_valid(node):
		node.queue_free()
	_active_popups.erase(actor_id)


func _find_label(node: Control) -> Label:
	# New structure: VBoxContainer → BarkPanel (PanelContainer) → BarkLabel
	var named: Node = node.get_node_or_null("BarkPanel/BarkLabel")
	if named is Label:
		return named as Label
	# Legacy fallback: BarkLabel directly on node
	named = node.get_node_or_null("BarkLabel")
	if named is Label:
		return named as Label
	# Last resort: first Label anywhere one level deep
	for child in node.get_children():
		if child is Label:
			return child as Label
		for grandchild in (child as Node).get_children():
			if grandchild is Label:
				return grandchild as Label
	return null
