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
# CardContent — parent of all card sections, used for dynamic vow nodes.
@onready var _card_content:      VBoxContainer = $CenterContainer/ResultCard/CardContent

var _sanctum_action:    Dictionary = {}
var _next_stage_action: Dictionary = {}
# V2-VOW-002: dynamically-created vow sections (freed on _clear).
var _vow_outcome_node:    Node = null
var _vow_discovered_node: Node = null


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
	# V2-VOW-002: free dynamic vow sections
	if _vow_outcome_node != null:
		_vow_outcome_node.queue_free()
		_vow_outcome_node = null
	if _vow_discovered_node != null:
		_vow_discovered_node.queue_free()
		_vow_discovered_node = null


func _render(data: Dictionary, actions: Dictionary) -> void:
	# V2-ECONOMY-001: scout_return path — partial Ase, no rank/vow/next_stage
	var run_type := str(data.get("run_type", ""))
	if run_type == "scout_return":
		_render_scout_return(data, actions)
		return

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

	# V2-VOW-002: vow outcome + discovery sections (inserted before ButtonRow).
	_build_vow_section(data)
	_build_vow_discovered_section(data)

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
		# V2-ECONOMY-001: Ekwan entries in Amber; Ase entries keep default theme color
		if str(entry.get("currency", "ase")) == "ekwan":
			item.add_theme_color_override("font_color", Color("#E8A030"))

	# V2-ECONOMY-001: skip total line on scout_return (total_ase == 0 signals no total)
	if total_ase > 0:
		var sep := HSeparator.new()
		_breakdown_section.add_child(sep)
		var total_lbl := Label.new()
		total_lbl.text = "= %d Ase" % total_ase
		_breakdown_section.add_child(total_lbl)


# ─────────────────────────────────────────────────────────────
# V2-VOW-002: Vow fallout renderer
# ─────────────────────────────────────────────────────────────

## Populates _vow_list with narrative header, vow name, and signed deltas.
## GDD: vows = "structure, pressure, and moral shape"; broken vow = strongest Continuity harm.
func _build_vow_section(outcome: Dictionary) -> void:
	var event := str(outcome.get("event", ""))
	var headline: String
	match event:
		"break":     headline = "The promise fractured."
		"compliant": headline = "The promise holds."
		_:           headline = "The promise held."

	var headline_lbl := Label.new()
	headline_lbl.text = headline
	headline_lbl.add_theme_font_size_override("font_size", 13)
	_vow_list.add_child(headline_lbl)

	var vow_name := str(outcome.get("vow_name", ""))
	if not vow_name.is_empty():
		var name_lbl := Label.new()
		name_lbl.text = vow_name
		name_lbl.add_theme_font_size_override("font_size", 12)
		_vow_list.add_child(name_lbl)

	# V2-VOW-002: compliance count line for "compliant" event.
	if event == "compliant":
		var count := int(outcome.get("compliance_count", 0))
		if count > 0:
			var count_lbl := Label.new()
			count_lbl.text = "%d stage%s honored" % [count, "s" if count != 1 else ""]
			count_lbl.add_theme_font_size_override("font_size", 12)
			count_lbl.add_theme_color_override("font_color", Color("#A8865A"))  # Warm Brass
			_vow_list.add_child(count_lbl)

	# Signed deltas — only non-zero values shown, joined with " · "
	var morale_d := int(outcome.get("morale_delta", 0))
	var fear_d   := int(outcome.get("fear_delta", 0))
	var ase_d    := int(outcome.get("ase_delta", 0))

	var parts: Array = []
	if morale_d != 0:
		parts.append("Morale %s%d" % ["+" if morale_d > 0 else "", morale_d])
	if fear_d != 0:
		parts.append("Fear %s%d" % ["+" if fear_d > 0 else "", fear_d])
	if ase_d != 0:
		parts.append("Ase %s%d" % ["+" if ase_d > 0 else "", ase_d])

	if not parts.is_empty():
		var delta_lbl := Label.new()
		delta_lbl.text = " · ".join(parts)
		delta_lbl.add_theme_font_size_override("font_size", 12)
		_vow_list.add_child(delta_lbl)


# ─────────────────────────────────────────────────────────────
# V2-VOW-002: Vow discovery renderer
# ─────────────────────────────────────────────────────────────

## Builds the list of vows revealed during this stage.
## Each entry shows: vow_name (13, Akan Gold), proverb_twi (12, Pale Kente), proverb_en (12, Warm Brass muted).
func _build_vow_discovered_section(vows: Array) -> void:
	for vow_v in vows:
		var vow: Dictionary = vow_v if vow_v is Dictionary else {}
		var vow_name := str(vow.get("vow_name", ""))
		var twi      := str(vow.get("proverb_twi", ""))
		var en       := str(vow.get("proverb_en", ""))

		if not vow_name.is_empty():
			var name_lbl := Label.new()
			name_lbl.text = vow_name
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.add_theme_color_override("font_color", Color("#C8A96E"))  # Akan Gold
			_vow_discovered_list.add_child(name_lbl)

		if not twi.is_empty():
			var twi_lbl := Label.new()
			twi_lbl.text = twi
			twi_lbl.add_theme_font_size_override("font_size", 12)
			twi_lbl.add_theme_color_override("font_color", Color("#E8D0A0"))  # Pale Kente
			twi_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			_vow_discovered_list.add_child(twi_lbl)

		if not en.is_empty():
			var en_lbl := Label.new()
			en_lbl.text = en
			en_lbl.add_theme_font_size_override("font_size", 12)
			en_lbl.add_theme_color_override("font_color", Color("#A8865A"))  # Warm Brass (muted)
			en_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			_vow_discovered_list.add_child(en_lbl)


# ─────────────────────────────────────────────────────────────
# V2-ECONOMY-001: Scout Return renderer
# ─────────────────────────────────────────────────────────────

func _render_scout_return(data: Dictionary, actions: Dictionary) -> void:
	_banner.text = "Scout Return"
	_banner.add_theme_color_override("font_color", Color("#7AB5C8"))  # Mist Blue — neutral info

	var intel := int(data.get("intel_count", 0))
	_reason.text = "%d situation%s revealed" % [intel, "s" if intel != 1 else ""]

	_rank_badge.visible              = false
	_vow_section.visible             = false
	_vow_discovered_section.visible  = false
	_next_stage_button.visible       = false

	_ase_value.text = "%d" % int(data.get("ase_awarded", 0))

	var breakdown_v: Variant = data.get("reward_breakdown", [])
	var breakdown: Array = breakdown_v if breakdown_v is Array else []
	_build_breakdown(breakdown, 0)

	# Actor preview — show name + emotional state (no pre/post arc on scout return)
	var actors_v: Variant = data.get("actors", [])
	var actors: Array = actors_v if actors_v is Array else []
	for actor_v in actors:
		if not actor_v is Dictionary:
			continue
		var actor: Dictionary = actor_v
		var nm := str(actor.get("name", ""))
		var es := str(actor.get("emotional_status", ""))
		var lbl := Label.new()
		lbl.text = "%s — [%s]" % [nm, es.capitalize()] if es != "" else nm
		lbl.add_theme_font_size_override("font_size", 14)
		_emotion_list.add_child(lbl)

	if actions.has("cta.continue"):
		var act_v: Variant = actions["cta.continue"]
		if act_v is Dictionary:
			_sanctum_action = act_v
			_sanctum_button.text    = str(act_v.get("label", "Return to Sanctum"))
			_sanctum_button.visible = true


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


# ─────────────────────────────────────────────────────────────
# V2-VOW-002: Vow outcome section (break / compliant / benefit)
# ─────────────────────────────────────────────────────────────

func _build_vow_section(data: Dictionary) -> void:
	var vow_v: Variant = data.get("vow_outcome", {})
	var vow: Dictionary = vow_v if vow_v is Dictionary else {}
	if vow.is_empty():
		return

	var event := str(vow.get("event", ""))
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var sep := HSeparator.new()
	section.add_child(sep)

	var headline := Label.new()
	headline.add_theme_font_size_override("font_size", 15)
	match event:
		"break":
			headline.text = "The promise fractured."
			headline.add_theme_color_override("font_color", Color("#E8412A"))  # Ohene Red
		"benefit":
			headline.text = "The promise held."
			headline.add_theme_color_override("font_color", Color("#C8A96E"))  # Akan Gold
		"compliant":
			headline.text = "The promise holds."
			headline.add_theme_color_override("font_color", Color("#C8A96E"))  # Akan Gold
		_:
			headline.text = ""
	section.add_child(headline)

	# Sub-line for compliance count or penalty hint
	if event == "compliant":
		var count := int(vow.get("compliance_count", 0))
		if count > 0:
			var count_lbl := Label.new()
			count_lbl.text = "%d stage%s honored" % [count, "s" if count != 1 else ""]
			count_lbl.add_theme_font_size_override("font_size", 12)
			count_lbl.add_theme_color_override("font_color", Color("#A8865A"))  # Warm Brass
			section.add_child(count_lbl)
	elif event == "break":
		var morale := int(vow.get("morale_delta", 0))
		var fear   := int(vow.get("fear_delta",   0))
		if morale != 0 or fear != 0:
			var pen_lbl := Label.new()
			pen_lbl.text = "Morale %+d  Fear %+d" % [morale, fear]
			pen_lbl.add_theme_font_size_override("font_size", 12)
			pen_lbl.add_theme_color_override("font_color", Color("#E8D0A0"))  # Pale Kente
			section.add_child(pen_lbl)

	# Insert before ButtonRow (last child of CardContent).
	_card_content.add_child(section)
	_card_content.move_child(section, _card_content.get_child_count() - 2)
	_vow_outcome_node = section


# V2-VOW-002: Vow discovery section — shows vows unlocked this stage.
func _build_vow_discovered_section(data: Dictionary) -> void:
	var vows_v: Variant = data.get("newly_unlocked_vows", [])
	var vows: Array = vows_v if vows_v is Array else []
	if vows.is_empty():
		return

	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var sep := HSeparator.new()
	section.add_child(sep)

	var header := Label.new()
	header.text = "Vow Revealed"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color("#7AB5C8"))  # Mist Blue
	section.add_child(header)

	for vow_v in vows:
		var vow: Dictionary = vow_v if vow_v is Dictionary else {}
		var name_lbl := Label.new()
		name_lbl.text = str(vow.get("vow_name", ""))
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color("#E8D0A0"))
		section.add_child(name_lbl)

		var twi_lbl := Label.new()
		twi_lbl.text = str(vow.get("proverb_twi", ""))
		twi_lbl.add_theme_font_size_override("font_size", 12)
		twi_lbl.add_theme_color_override("font_color", Color("#C8A96E"))
		twi_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		section.add_child(twi_lbl)

		var en_lbl := Label.new()
		en_lbl.text = '"%s"' % str(vow.get("proverb_en", ""))
		en_lbl.add_theme_font_size_override("font_size", 12)
		en_lbl.add_theme_color_override("font_color", Color("#A8865A"))
		en_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		section.add_child(en_lbl)

	# Insert before ButtonRow.
	_card_content.add_child(section)
	_card_content.move_child(section, _card_content.get_child_count() - 2)
	_vow_discovered_node = section


func _ready() -> void:
	_sanctum_button.pressed.connect(_on_sanctum_pressed)
	_next_stage_button.pressed.connect(_on_next_stage_pressed)
