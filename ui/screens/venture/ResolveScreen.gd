# res://ui/screens/venture/ResolveScreen.gd
# UI-003: Resolve Screen — full art implementation.
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
#
# Rank colors are @export so they can be adjusted in the Godot editor
# without touching this script.

class_name ResolveScreen
extends Control

signal action_requested(action: Dictionary)

# Purposeful informational colors — adjustable in Godot inspector per instance.
@export var rank_color_s: Color = Color("#ffd700")  # gold
@export var rank_color_a: Color = Color("#c0ff80")  # lime
@export var rank_color_b: Color = Color("#80c0ff")  # sky blue
@export var rank_color_c: Color = Color("#f0e8d0")  # text default
@export var rank_color_d: Color = Color("#b08040")  # amber dim
@export var rank_color_f: Color = Color("#c04040")  # red

const RewardEntryScene    := preload("res://ui/components/RewardEntryItem.tscn")
const EmotionEntryScene   := preload("res://ui/components/EmotionEntryItem.tscn")

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
@onready var _emotion_list:      VBoxContainer = %EmotionList

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
	for child in _emotion_list.get_children():
		child.queue_free()


func _render(data: Dictionary, actions: Dictionary) -> void:
	var victory: bool = bool(data.get("victory", false))

	_banner.text = "VICTORY" if victory else "DEFEAT"
	_reason.text = _format_reason(str(data.get("reason", "")))

	_enemies_value.text = str(data.get("enemies_defeated", 0))
	_echoes_value.text  = str(data.get("echoes_survived", 0))
	_rounds_value.text  = str(data.get("round_ended", 0))

	# Rank badge — color is informational (S=gold, F=red)
	var rank := str(data.get("rank", "F"))
	_rank_badge.text = rank
	_rank_badge.add_theme_color_override("font_color", _rank_color(rank))

	# Ase earned
	_ase_value.text = str(data.get("ase_awarded", 0)) + " Ase"

	# Reward breakdown
	var breakdown_v: Variant = data.get("reward_breakdown", [])
	var breakdown: Array = breakdown_v if breakdown_v is Array else []
	_build_breakdown(breakdown, int(data.get("ase_awarded", 0)))

	# V2-VOICE-001: build arrival_bark lookup from actors list (echo faction only).
	var _arrival_barks: Dictionary = {}
	var _actors_v: Variant = data.get("actors", [])
	if _actors_v is Array:
		for _a_v in (_actors_v as Array):
			if _a_v is Dictionary:
				var _a: Dictionary = _a_v
				if str(_a.get("faction", "")) == "echo":
					var _ab := str(_a.get("arrival_bark", ""))
					if not _ab.is_empty():
						_arrival_barks[str(_a.get("id", ""))] = _ab

	# V2-EMOTION-002: per-echo emotion summary (unified emotional status arc).
	var emotion_summary_v: Variant = data.get("emotion_summary", [])
	var emotion_summary: Array = emotion_summary_v if emotion_summary_v is Array else []
	var _bark_rows: Array = []  # Array of [Label, String] for staggered animation
	for entry_v in emotion_summary:
		var entry: Dictionary = entry_v if entry_v is Dictionary else {}
		var row: Node = EmotionEntryScene.instantiate()
		row.get_node("%EchoNameLabel").text    = str(entry.get("name", ""))
		row.get_node("%EmotionArcLabel").text  = \
			"%s → %s" % [entry.get("pre_emotional_status", "").capitalize(), entry.get("post_emotional_status", "").capitalize()]
		row.get_node("%RefusedLabel").visible  = bool(entry.get("refused", false))
		_emotion_list.add_child(row)
		# V2-VOICE-001: add arrival bark label below this row if present.
		var _echo_id := str(entry.get("echo_id", ""))
		if _arrival_barks.has(_echo_id):
			var _bark_lbl := Label.new()
			_bark_lbl.text = "\"%s\"" % _arrival_barks[_echo_id]
			_bark_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
			_bark_lbl.add_theme_font_size_override("font_size", 12)
			_bark_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			_bark_lbl.modulate.a = 0.0  # starts invisible for stagger animation
			_emotion_list.add_child(_bark_lbl)
			_bark_rows.append(_bark_lbl)

	# V2-VOICE-001: staggered fade-in of arrival bark labels (0.3s each, 0.6s stagger).
	if not _bark_rows.is_empty():
		for _bi in range(_bark_rows.size()):
			var _bl: Label = _bark_rows[_bi]
			var _delay: float = float(_bi) * 0.6
			var _tween: Tween = create_tween()
			_tween.tween_interval(_delay)
			_tween.tween_property(_bl, "modulate:a", 1.0, 0.3)

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
		if str(entry.get("label", "")).is_empty():
			continue
		var item: RewardEntryItem = RewardEntryScene.instantiate()
		_breakdown_section.add_child(item)
		item.setup(entry)

	if not breakdown.is_empty():
		var sep := HSeparator.new()
		_breakdown_section.add_child(sep)
		var total_lbl := Label.new()
		total_lbl.text = "= %d Ase" % total_ase
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


func _rank_color(rank: String) -> Color:
	match rank:
		"S": return rank_color_s
		"A": return rank_color_a
		"B": return rank_color_b
		"C": return rank_color_c
		"D": return rank_color_d
		_:   return rank_color_f


func _ready() -> void:
	_sanctum_button.pressed.connect(_on_sanctum_pressed)
	_next_stage_button.pressed.connect(_on_next_stage_pressed)
