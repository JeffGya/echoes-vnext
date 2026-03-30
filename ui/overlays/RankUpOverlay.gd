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

# ── Narrative constants (Anansi voice — no numbers ever) ──────────────────
const _NARRATIVES: Dictionary = {
	"courage_positive": "The weave remembers every blow struck without hesitation. {name}'s resolve deepens.",
	"courage_negative": "Not every battle is won by force. {name} learns restraint.",
	"wisdom_positive":  "The weave remembers every guard held, every retreat denied. {name}'s wisdom grows in the silence.",
	"wisdom_negative":  "Some lessons arrive as doubt. {name}'s certainty is being tested.",
	"faith_positive":   "The weave rewards those who endure. {name}'s spirit holds firm.",
	"faith_negative":   "Carrying others' burdens leaves marks. {name}'s faith finds new ground.",
}
const _REVEAL_TEXT: String    = "{name} ascends to Rank {rank}. The weave shifts to hold what they have become."
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
@onready var calling_option_template: PanelContainer = %CallingOptionTemplate
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
	var new_rank: int          = int(rank_up_event.get("new_rank", 2))
	var calling_eligible: bool = bool(rank_up_event.get("calling_eligible", false))
	var options_v: Variant     = rank_up_event.get("calling_options", [])
	var options: Array         = options_v if options_v is Array else []

	rank_badge.text          = "Rank %d" % new_rank
	reveal_name.text         = echo_name
	reveal_text_label.text   = _REVEAL_TEXT \
		.replace("{name}", echo_name) \
		.replace("{rank}", str(new_rank))

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
	# Clear previously generated rows only. Static designer content stays intact.
	for child in calling_options_container.get_children():
		if bool(child.get_meta("generated_calling_option", false)):
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

		var row := calling_option_template.duplicate() as PanelContainer
		row.visible = true
		row.modulate = Color(1, 1, 1)
		var name_lbl := _calling_row_node(row, "CallingNameLabel") as Label
		name_lbl.text = display_name

		# Compatibility badge (preferred / compatible / ambivalent only — not for incompatible)
		var badge_text: String = ""
		var effective_compatibility: String = "preferred" if is_preferred else compatibility
		match effective_compatibility:
			"preferred":  badge_text = _BADGE_PREFERRED
			"compatible": badge_text = _BADGE_COMPATIBLE
			"ambivalent": badge_text = _BADGE_AMBIVALENT
		var badge_lbl := _calling_row_node(row, "CompatibilityBadgeLabel") as Label
		badge_lbl.visible = not badge_text.is_empty()
		badge_lbl.text = badge_text

		# Description
		var desc_lbl := _calling_row_node(row, "DescriptionLabel") as Label
		desc_lbl.visible = not description.is_empty()
		desc_lbl.text = description

		# Tapping the row selects it
		var select_btn := _calling_row_node(row, "SelectButton") as Button
		select_btn.pressed.connect(_on_calling_row_pressed.bind(cid))

		row.set_meta("generated_calling_option", true)
		calling_options_container.add_child(row)
		# Store a ref so we can update highlight on selection
		row.set_meta("calling_id", cid)


func _on_calling_row_pressed(cid: String) -> void:
	_selected_calling_id = cid
	confirm_calling_button.disabled = false

	# Highlight selected row; clear others
	for child in calling_options_container.get_children():
		if child is PanelContainer and bool(child.get_meta("generated_calling_option", false)):
			var is_selected: bool = (str(child.get_meta("calling_id", "")) == cid)
			# Toggle a simple modulate tint for selection feedback
			child.modulate = Color(1.0, 0.85, 0.4) if is_selected else Color(1, 1, 1)


func _calling_row_node(row: Node, node_name: String) -> Node:
	var found := row.find_child(node_name, true, false)
	assert(found != null, "RankUpOverlay: calling option template missing node '%s'" % node_name)
	return found


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
