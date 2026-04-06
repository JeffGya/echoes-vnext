# res://ui/overlays/RankUpOverlay.gd
# PROG-004/PROG-007: Rank-up confirmation + reveal + calling selection overlay.
#
# Three-panel scene:
#   ConfirmPanel  — Anansi narrator text (no numbers) + Cancel / Confirm Ascension buttons.
#   RevealPanel   — Full-screen celebration: rank badge, echo name, narrative, CTA button.
#                   CTA label: "Choose a Path" when calling pending, "Continue" otherwise.
#   CallingPanel  — All 5 callings displayed with compatibility tags. Keeper picks one.
#                   "Choose Later" defers — calling persists in save until confirmed.
#
# Usage pattern (EchoPartyScreen):
#   1. Preload as const; instantiate once in _ready(); add_child().
#   2. Call show_confirm(echo_data) when Ascend button is tapped.
#   3. Connect confirm_requested(echo_id) → dispatch sanctum.rank_up.
#   4. Call show_reveal(rank_up_event) when set_snapshot() receives data.rank_up_event.
#   5. Connect calling_confirm_requested(echo_id, chosen_calling_id) → dispatch sanctum.calling.confirm.
#   6. Connect dismissed() → clear rank_up_event from local state.
#   7. For deferred access: call show_calling(echo_id, calling_options) directly.

class_name RankUpOverlay
extends Control

signal confirm_requested(echo_id: String)
signal calling_confirm_requested(echo_id: String, chosen_calling_id: String)
signal dismissed()

const _CALLING_OPTION_CARD_SCENE: PackedScene = preload("res://ui/components/CallingOptionCard.tscn")

# ── Narrative constants (Anansi voice — no numbers ever) ──────────────────
const _NARRATIVES: Dictionary = {
	"courage_positive": "The weave remembers every blow struck without hesitation. {name}'s resolve deepens.",
	"courage_negative": "Not every battle is won by force. {name} learns restraint.",
	"wisdom_positive":  "The weave remembers every guard held, every retreat denied. {name}'s wisdom grows in the silence.",
	"wisdom_negative":  "Some lessons arrive as doubt. {name}'s certainty is being tested.",
	"faith_positive":   "The weave rewards those who endure. {name}'s spirit holds firm.",
	"faith_negative":   "Carrying others' burdens leaves marks. {name}'s faith finds new ground.",
}
const _REVEAL_TEXT: String    = "{name} rises to Standing {standing}. The weave shifts to hold what they have become."
const _CALLING_STIRS: String  = "★ A Calling stirs within {name}."

# ── Compatibility badge labels ──────────────────────────────────────────────
const _BADGE_PREFERRED:  String = "Echo's Path"
const _BADGE_COMPATIBLE: String = "Compatible"
const _BADGE_AMBIVALENT: String = "Ambivalent"

# ── Scene refs — ConfirmPanel ───────────────────────────────────────────────
@onready var confirm_panel: VBoxContainer  = %ConfirmPanel
@onready var confirm_text: Label           = %ConfirmText
@onready var cancel_button: Button         = %CancelButton
@onready var confirm_button: Button        = %ConfirmButton

# ── Scene refs — RevealPanel ────────────────────────────────────────────────
@onready var reveal_panel: VBoxContainer   = %RevealPanel
@onready var rank_badge: Label             = %RankBadge
@onready var reveal_name: Label            = %RevealName
@onready var reveal_text_label: Label      = %RevealText
@onready var calling_stirs_label: Label    = %CallingStirs
@onready var continue_button: Button       = %ContinueButton

# ── Scene refs — CallingPanel ───────────────────────────────────────────────
@onready var calling_panel: VBoxContainer      = %CallingPanel
@onready var calling_options_container: VBoxContainer = %CallingOptionsContainer
@onready var confirm_calling_button: Button    = %ConfirmCallingButton
@onready var defer_button: Button              = %DeferButton

# ── State ──────────────────────────────────────────────────────────────────
var _echo_id: String           = ""
var _calling_echo_id: String   = ""
var _calling_options: Array    = []
var _selected_calling_id: String = ""


# ── Lifecycle ──────────────────────────────────────────────────────────────
func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	confirm_calling_button.pressed.connect(_on_confirm_calling_pressed)
	defer_button.pressed.connect(_on_defer_pressed)
	visible = false


# ── Public API ─────────────────────────────────────────────────────────────

## Show the confirmation panel. Call when the Ascend button is tapped.
## echo_data: an entry from snapshot.data.echoes (must include trait_drift_preview).
func show_confirm(echo_data: Dictionary) -> void:
	_echo_id = str(echo_data.get("id", ""))
	var echo_name: String = str(echo_data.get("name", "Unknown"))

	# Build Anansi confirmation text from drift_preview (narrative key only — no numbers).
	var drift_v: Variant   = echo_data.get("trait_drift_preview", {})
	var drift: Dictionary  = drift_v if drift_v is Dictionary else {}
	var trait_key: String  = str(drift.get("trait_key", "courage"))
	var direction: int     = int(drift.get("direction", 1))
	var nkey: String       = trait_key + ("_positive" if direction > 0 else "_negative")
	var narrative: String  = str(_NARRATIVES.get(nkey, ""))
	confirm_text.text = narrative.replace("{name}", echo_name)

	confirm_panel.visible = true
	reveal_panel.visible  = false
	calling_panel.visible = false
	visible = true


## Show the reveal panel. Call after set_snapshot() receives data.rank_up_event.
## rank_up_event: dict from FlowRuntime._handle_sanctum_rank_up() attached to snapshot.data.
func show_reveal(rank_up_event: Dictionary) -> void:
	var echo_name: String      = str(rank_up_event.get("echo_name", "Unknown"))
	var echo_id_from_event: String = str(rank_up_event.get("echo_id", ""))
	var new_standing: int      = int(rank_up_event.get("new_standing", 2))
	var calling_eligible: bool = bool(rank_up_event.get("calling_eligible", false))
	var options_v: Variant     = rank_up_event.get("calling_options", [])
	var options: Array         = options_v if options_v is Array else []

	rank_badge.text          = "Standing %d" % new_standing
	reveal_name.text         = echo_name
	reveal_text_label.text   = _REVEAL_TEXT \
		.replace("{name}", echo_name) \
		.replace("{standing}", str(new_standing))

	calling_stirs_label.text    = _CALLING_STIRS.replace("{name}", echo_name)
	calling_stirs_label.visible = calling_eligible

	# Store calling context so ContinueButton can route to CallingPanel.
	_calling_echo_id = echo_id_from_event
	_calling_options = options

	# Single CTA button — label changes based on whether a calling is pending.
	if calling_eligible and not options.is_empty():
		continue_button.text = "Choose a Path"
	else:
		continue_button.text = "Continue"

	confirm_panel.visible = false
	reveal_panel.visible  = true
	calling_panel.visible = false
	visible = true


## Show the calling selection panel directly — used for both the post-rank-up flow
## and deferred access from EchoParty (Keeper taps ⚡ Path Awaits on a pending echo).
func show_calling(echo_id: String, calling_options: Array) -> void:
	_calling_echo_id      = echo_id
	_calling_options      = calling_options
	_selected_calling_id  = ""
	confirm_calling_button.disabled = true

	_build_calling_rows()

	confirm_panel.visible = false
	reveal_panel.visible  = false
	calling_panel.visible = true
	visible = true


# ── Private helpers ─────────────────────────────────────────────────────────

## Builds calling option rows dynamically from _calling_options.
## Clears container first — safe to call multiple times.
func _build_calling_rows() -> void:
	# Clear previously generated rows.
	for child in calling_options_container.get_children():
		if child.has_method("get_calling_id"):
			child.queue_free()

	for opt_v in _calling_options:
		if not (opt_v is Dictionary):
			continue
		var opt: Dictionary      = opt_v
		var cid: String          = str(opt.get("calling_id", ""))
		var display_name: String = str(opt.get("display_name", cid))
		var description: String  = str(opt.get("description", ""))
		var compatibility: String = str(opt.get("compatibility", ""))
		var is_preferred: bool   = bool(opt.get("is_preferred", false))

		# Compatibility badge (preferred / compatible / ambivalent only — not for incompatible)
		var badge_text: String = ""
		var effective_compatibility: String = "preferred" if is_preferred else compatibility
		match effective_compatibility:
			"preferred":  badge_text = _BADGE_PREFERRED
			"compatible": badge_text = _BADGE_COMPATIBLE
			"ambivalent": badge_text = _BADGE_AMBIVALENT

		var row: Node = _CALLING_OPTION_CARD_SCENE.instantiate()
		row.connect("selected", Callable(self, "_on_calling_row_pressed"))
		calling_options_container.add_child(row)
		row.call("configure", cid, display_name, description, badge_text)


func _on_calling_row_pressed(cid: String) -> void:
	_selected_calling_id = cid
	confirm_calling_button.disabled = false

	# Highlight selected row; clear others
	for child in calling_options_container.get_children():
		if child.has_method("get_calling_id") and child.has_method("set_selected"):
			var is_selected: bool = (str(child.call("get_calling_id")) == cid)
			child.call("set_selected", is_selected)


# ── Private button handlers ─────────────────────────────────────────────────

func _on_cancel_pressed() -> void:
	visible  = false
	_echo_id = ""


func _on_confirm_pressed() -> void:
	# EchoPartyScreen receives this → dispatches sanctum.rank_up → calls show_reveal().
	confirm_requested.emit(_echo_id)


func _on_continue_pressed() -> void:
	# If calling options are pending, transition to CallingPanel instead of dismissing.
	if not _calling_options.is_empty():
		show_calling(_calling_echo_id, _calling_options)
		return
	visible  = false
	_echo_id = ""
	dismissed.emit()


func _on_confirm_calling_pressed() -> void:
	if _selected_calling_id.is_empty():
		return
	calling_confirm_requested.emit(_calling_echo_id, _selected_calling_id)
	_reset_calling_state()
	visible = false
	dismissed.emit()


func _on_defer_pressed() -> void:
	# Keeper defers — calling_options stay in save; ⚡ indicator remains on EchoParty.
	_reset_calling_state()
	visible = false
	dismissed.emit()


func _reset_calling_state() -> void:
	_calling_echo_id     = ""
	_calling_options     = []
	_selected_calling_id = ""
	confirm_calling_button.disabled = true
