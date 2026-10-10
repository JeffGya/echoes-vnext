# res://ui/components/EchoCardItem.gd
# UI-003: Echo status card for RealmShell bottom bar.
# Handles two data shapes:
#   Encounter/Resolve: { name, hp, max_hp, emotional_status, faction }
#   Stage/StageMap:    { name, rank, calling_origin, emotional_status }
# Data bind only — no colors. All styling via Godot theme.
# V2-EMOTION-002: emotional_status is the sole player-facing feeling field.
# V2-STAGE-004 P3c: an optional GUIDE_SPIRIT ally variant — same card, gold accent +
#   "◆ SPIRIT" badge + objective progress line. Toggled via setup_spirit(); the plain
#   setup() path leaves the spirit nodes hidden and the panel untouched (pixel-identical).
# V2-STAGE-004 P4 S15-UI-A: a combat RECRUITED_ALLY variant — same card, Mist Blue accent +
#   "⊕ ALLY" badge. Toggled via setup_ally(). Separately, any roster echo carrying
#   origin == "recruited_ally" (a durable companion, not a one-off combat ally) shows a
#   "⊕ Companion" tag from plain setup() — the two never show together.

class_name EchoCardItem
extends PanelContainer

## Tap on the card: a press and release on it, with no drag and no scroll of the bar between. actor_id
## is the actor's snapshot id, or "" when the data shape has none (Stage party_preview rows).
signal card_pressed(actor_id: String)

const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")

# Gold accent border applied only to the spirit ally slot (Akan Gold). Authored declaratively
# as a standalone StyleBox resource; script only toggles it on for the spirit variant.
const _SPIRIT_PANEL_STYLE: StyleBox = preload("res://ui/components/EchoCardSpiritAccent.tres")
# Mist Blue accent border applied only to the combat RECRUITED_ALLY slot. Authored declaratively
# as a standalone StyleBox resource; script only toggles it on for the ally variant.
const _ALLY_PANEL_STYLE: StyleBox = preload("res://ui/components/EchoCardAllyAccent.tres")

@onready var hp_bar: ProgressBar     = %HpBar
@onready var hp_label: Label         = %HpLabel
@onready var portrait_label: Label   = %PortraitLabel
@onready var name_label: Label       = %NameLabel
@onready var status_label: Label     = %StatusLabel
@onready var spirit_badge: Label     = %SpiritBadge
@onready var progress_label: Label   = %ProgressLabel
@onready var ally_badge: Label       = %AllyBadge
@onready var companion_tag: Label    = %CompanionTag

var _actor_id: String = ""
## Set by RealmShell: which bar slot this card fills (kind and actor id), so a snapshot updates it in place.
var slot_key: String = ""
# Tells a tap from a drag (same 8 px rule as the board) and ignores the engine's emulated twin of a
# mouse click, so one tap is one signal. The card has mouse_filter PASS: a drag that starts on it
# reaches the EchoBar's ScrollContainer, which can scroll.
var _pointer := BoardPointerTracker.new()
var _scroll_at_press := Vector2i.ZERO

func _ready() -> void:
	_pointer.space_held_fn = Callable(self, "_never")
	_pointer.tap.connect(_on_pointer_tap)
	gui_input.connect(_on_gui_input)

func _never() -> bool:
	return false

func _on_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		_scroll_at_press = _scroll_position()
	_pointer.handle_event(event)

# A release outside the card is no tap (press on one card, release on another). A bar that scrolled
# since the press is no tap either.
func _on_pointer_tap(release_pos: Vector2) -> void:
	if not Rect2(Vector2.ZERO, size).has_point(release_pos):
		return
	if _scroll_position() != _scroll_at_press:
		return
	card_pressed.emit(_actor_id)

func _scroll_position() -> Vector2i:
	var node := get_parent()
	while node != null and not (node is ScrollContainer):
		node = node.get_parent()
	if node == null:
		return Vector2i.ZERO
	var scroll := node as ScrollContainer
	return Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical)

func setup(actor: Dictionary) -> void:
	# Reset any accent stylebox left over from a prior setup_ally()/setup_spirit() call on a
	# reused card instance, so a plain setup() is fully back to the default panel look.
	remove_theme_stylebox_override("panel")

	_actor_id = str(actor.get("id", ""))
	var name_str := str(actor.get("name", "?"))
	name_label.text     = name_str
	portrait_label.text = name_str.substr(0, 2).to_upper()

	if actor.has("hp") and actor.has("max_hp"):
		var hp: int     = int(actor.get("hp", 0))
		var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
		hp_bar.max_value = max_hp
		hp_bar.value     = clampi(hp, 0, max_hp)
		hp_label.text    = "HP %d/%d" % [hp, max_hp]
		hp_bar.visible   = true
	else:
		hp_bar.visible = false

	var status := EmotionPresentation.normalize(str(actor.get("emotional_status", "")))
	status_label.text = EmotionPresentation.display_name(status)
	status_label.theme_type_variation = EmotionPresentation.text_theme(status)

	# Recruited-ally companion tag: a durable roster echo recruited via V2-STAGE-004 Phase 4
	# (origin == "recruited_ally") is tagged in any list that uses this card. Distinct from the
	# per-encounter ALLY badge below, which is applied via setup_ally() and never both at once.
	ally_badge.visible = false
	companion_tag.visible = str(actor.get("origin", "")) == "recruited_ally"

## Applies the base card bind, then promotes the card to the distinct GUIDE_SPIRIT ally
## slot: reveals the gold badge + objective-progress line and paints the gold accent border.
## progress_text is pre-composed by the shell from objective_state (e.g. "3 rounds left",
## "Arrived", "Fallen"). Non-spirit cards never call this — they stay visually identical.
func setup_spirit(actor: Dictionary, progress_text: String) -> void:
	setup(actor)
	spirit_badge.visible   = true
	progress_label.visible = not progress_text.is_empty()
	progress_label.text    = progress_text
	# Gold left-border accent — authored as EchoCardSpiritAccent.tres, toggled on here only.
	add_theme_stylebox_override("panel", _SPIRIT_PANEL_STYLE)

## Applies the base card bind, then promotes the card to the combat RECRUITED_ALLY slot:
## reveals the Mist Blue "⊕ ALLY" badge and paints the Mist Blue accent border. Unlike the
## GUIDE_SPIRIT variant, an ally is a normal party-side card — it renders inline in the echo
## bar loop, not in the single dedicated spirit slot. Non-ally cards never call this.
func setup_ally(actor: Dictionary) -> void:
	setup(actor)
	ally_badge.visible = true
	# Mist Blue left-border accent — authored as EchoCardAllyAccent.tres, toggled on here only.
	add_theme_stylebox_override("panel", _ALLY_PANEL_STYLE)
