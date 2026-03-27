# res://ui/overlays/RankUpOverlay.gd
# PROG-004: Rank-up confirmation + reveal overlay.
#
# Two-panel scene:
#   ConfirmPanel — Anansi narrator text (no numbers) + Cancel / Confirm Ascension buttons.
#   RevealPanel  — Full-screen celebration: rank badge, echo name, narrative, Continue button.
#
# Usage pattern (EchoManageScreen):
#   1. Preload as const; instantiate once in _ready(); add_child().
#   2. Call show_confirm(echo_data) when Ascend button is tapped.
#   3. Connect confirm_requested(echo_id) → dispatch sanctum.rank_up.
#   4. Call show_reveal(rank_up_event) when set_snapshot() receives data.rank_up_event.
#   5. Connect dismissed() → clear rank_up_event from local state.

class_name RankUpOverlay
extends Control

signal confirm_requested(echo_id: String)
signal dismissed()

# ── Narrative constants (Anansi voice — no numbers ever) ──────────────────
const _NARRATIVES: Dictionary = {
	"courage_positive": "The weave remembers every blow struck without hesitation. {name}'s resolve deepens.",
	"courage_negative": "Not every battle is won by force. {name} learns restraint.",
	"wisdom_positive":  "The weave remembers every guard held, every retreat denied. {name}'s wisdom grows in the silence.",
	"wisdom_negative":  "Some lessons arrive as doubt. {name}'s certainty is being tested.",
	"faith_positive":   "The weave rewards those who endure. {name}'s spirit holds firm.",
	"faith_negative":   "Carrying others' burdens leaves marks. {name}'s faith finds new ground.",
}
const _REVEAL_TEXT: String   = "{name} ascends to Rank {rank}. The weave shifts to hold what they have become."
const _CALLING_STIRS: String = "★ A Calling stirs within {name}."

# ── Scene refs ─────────────────────────────────────────────────────────────
@onready var confirm_panel: VBoxContainer  = %ConfirmPanel
@onready var confirm_text: Label           = %ConfirmText
@onready var cancel_button: Button         = %CancelButton
@onready var confirm_button: Button        = %ConfirmButton

@onready var reveal_panel: VBoxContainer   = %RevealPanel
@onready var rank_badge: Label             = %RankBadge
@onready var reveal_name: Label            = %RevealName
@onready var reveal_text_label: Label      = %RevealText
@onready var calling_stirs_label: Label    = %CallingStirs
@onready var continue_button: Button       = %ContinueButton

# ── State ──────────────────────────────────────────────────────────────────
var _echo_id: String = ""

# ── Lifecycle ──────────────────────────────────────────────────────────────
func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
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
	visible = true


## Show the reveal panel. Call after set_snapshot() receives data.rank_up_event.
## rank_up_event: dict from FlowRuntime._handle_sanctum_rank_up() attached to snapshot.data.
func show_reveal(rank_up_event: Dictionary) -> void:
	var echo_name: String      = str(rank_up_event.get("echo_name", "Unknown"))
	var new_rank: int          = int(rank_up_event.get("new_rank", 2))
	var calling_eligible: bool = bool(rank_up_event.get("calling_eligible", false))

	rank_badge.text          = "Rank %d" % new_rank
	reveal_name.text         = echo_name
	reveal_text_label.text   = _REVEAL_TEXT \
		.replace("{name}", echo_name) \
		.replace("{rank}", str(new_rank))

	calling_stirs_label.text    = _CALLING_STIRS.replace("{name}", echo_name)
	calling_stirs_label.visible = calling_eligible

	confirm_panel.visible = false
	reveal_panel.visible  = true
	visible = true


# ── Private handlers ───────────────────────────────────────────────────────

func _on_cancel_pressed() -> void:
	visible  = false
	_echo_id = ""


func _on_confirm_pressed() -> void:
	# EchoManageScreen receives this → dispatches sanctum.rank_up → calls show_reveal().
	confirm_requested.emit(_echo_id)


func _on_continue_pressed() -> void:
	visible  = false
	_echo_id = ""
	dismissed.emit()
