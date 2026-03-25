# res://ui/screens/ResolveScreen.gd
# UI-005: Resolve Screen — full art implementation.
# Renders the final combat result (type "flow.resolve") emitted by
# FlowEncounterState.build_final_snapshot().
#
# Contract (UI-001):
#   set_snapshot(snap) → _clear() + _render(data, actions)
#   action_requested signal for all player interactions
#   Never reads sim internals directly
#
# Note: The echo party bar is owned by RealmShell and updated automatically
# on every snapshot. This screen only renders the result summary card.

class_name ResolveScreen
extends Control

signal action_requested(action: Dictionary)

const RANK_COLORS: Dictionary = {
	"S": Color("#ffd700"),  # gold
	"A": Color("#c0ff80"),  # lime
	"B": Color("#80c0ff"),  # sky blue
	"C": Color("#f0e8d0"),  # text default
	"D": Color("#b08040"),  # amber dim
	"F": Color("#c04040"),  # red
}
const COL_TEXT_DIM := Color("#908870")
const COL_TEXT     := Color("#f0e8d0")

@onready var _banner:            Label         = %BannerLabel
@onready var _reason:            Label         = %ReasonLabel
@onready var _rank_badge:        Label         = %RankBadge
@onready var _ase_value:         Label         = %AseValue
@onready var _breakdown_section: VBoxContainer = %BreakdownSection
@onready var _enemies_value:     Label         = %EnemiesDefeatedValue
@onready var _echoes_value:      Label         = %EchoesAliveValue
@onready var _rounds_value:      Label         = %RoundsValue
@onready var _sanctum_button:    Button        = %SanctumButton
@onready var _next_stage_button: Button        = %NextStageButton

var _sanctum_action:    Dictionary = {}
var _next_stage_action: Dictionary = {}


# ─────────────────────────────────────────────────────────────
# UI-001 bespoke screen contract
# ─────────────────────────────────────────────────────────────

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "ResolveScreen: snapshot missing 'type'")
	assert(snap.has("data"), "ResolveScreen: snapshot missing 'data'")
	_clear()
	_render(snap["data"], snap.get("actions", {}))


func _clear() -> void:
	_sanctum_action    = {}
	_next_stage_action = {}
	_sanctum_button.visible    = false
	_next_stage_button.visible = false
	_rank_badge.text = "—"
	_rank_badge.remove_theme_color_override("font_color")
	_ase_value.text  = "0"
	for child in _breakdown_section.get_children():
		child.queue_free()


func _render(data: Dictionary, actions: Dictionary) -> void:
	var victory: bool = bool(data.get("victory", false))

	_banner.text = "VICTORY" if victory else "DEFEAT"
	_reason.text = _format_reason(str(data.get("reason", "")))

	_enemies_value.text = str(data.get("enemies_defeated", 0))
	_echoes_value.text  = str(data.get("echoes_survived", 0))
	_rounds_value.text  = str(data.get("round_ended", 0))

	# Rank badge
	var rank := str(data.get("rank", "F"))
	_rank_badge.text = rank
	var rank_color: Variant = RANK_COLORS.get(rank, COL_TEXT)
	_rank_badge.add_theme_color_override("font_color", rank_color as Color)

	# Ase earned
	_ase_value.text = str(data.get("ase_awarded", 0)) + " Ase"

	# Reward breakdown
	var breakdown_v: Variant = data.get("reward_breakdown", [])
	var breakdown: Array = breakdown_v if breakdown_v is Array else []
	_build_breakdown(breakdown, int(data.get("ase_awarded", 0)))

	# Wire CTA buttons from snapshot actions.
	if actions.has("cta.continue"):
		var act_v: Variant = actions["cta.continue"]
		if act_v is Dictionary:
			_sanctum_action = act_v
			_sanctum_button.text    = str(act_v.get("label", "To Sanctum"))
			_sanctum_button.visible = true

	if actions.has("cta.next_stage"):
		var act_v: Variant = actions["cta.next_stage"]
		if act_v is Dictionary:
			_next_stage_action         = act_v
			_next_stage_button.text    = str(act_v.get("label", "Next Stage"))
			_next_stage_button.visible = true


# ─────────────────────────────────────────────────────────────
# Breakdown renderer
# ─────────────────────────────────────────────────────────────

func _build_breakdown(breakdown: Array, total_ase: int) -> void:
	for entry_v in breakdown:
		var entry: Dictionary = entry_v if entry_v is Dictionary else {}
		var label_str := str(entry.get("label", ""))
		var delta     := int(entry.get("delta", 0))
		if label_str.is_empty():
			continue

		var lbl := Label.new()
		if delta >= 0:
			lbl.text = "%s: +%d Ase" % [label_str, delta]
			lbl.add_theme_color_override("font_color", COL_TEXT)
		else:
			lbl.text = "%s: −%d Ase" % [label_str, abs(delta)]
			lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		lbl.add_theme_font_size_override("font_size", 13)
		_breakdown_section.add_child(lbl)

	# Total line
	if not breakdown.is_empty():
		var sep := HSeparator.new()
		_breakdown_section.add_child(sep)
		var total_lbl := Label.new()
		total_lbl.text = "= %d Ase" % total_ase
		total_lbl.add_theme_color_override("font_color", COL_TEXT)
		total_lbl.add_theme_font_size_override("font_size", 14)
		_breakdown_section.add_child(total_lbl)


# ─────────────────────────────────────────────────────────────
# Button handlers
# ─────────────────────────────────────────────────────────────

func _on_sanctum_pressed() -> void:
	if not _sanctum_action.is_empty():
		action_requested.emit(_sanctum_action)


func _on_next_stage_pressed() -> void:
	if not _next_stage_action.is_empty():
		action_requested.emit(_next_stage_action)


## Maps internal reason strings to player-facing labels.
func _format_reason(reason: String) -> String:
	match reason:
		"all_enemies_defeated": return "All enemies defeated"
		"all_echoes_dead":      return "All echoes fell"
		"shrine_destroyed":     return "Shrine Destroyed"
	return reason


func _ready() -> void:
	_sanctum_button.pressed.connect(_on_sanctum_pressed)
	_next_stage_button.pressed.connect(_on_next_stage_pressed)
