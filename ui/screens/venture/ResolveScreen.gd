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
const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")
const EffectChipScene     := preload("res://ui/components/EffectChip.tscn")

@onready var _banner:            Label         = %BannerLabel
@onready var _reason:            Label         = %ReasonLabel
@onready var _rank_badge:        Label         = %RankBadge
@onready var _ase_value:         Label         = %AseValue
@onready var _ekwan_row:         HBoxContainer = %EkwanRow
@onready var _ekwan_value:       Label         = %EkwanValue
@onready var _breakdown_section: VBoxContainer = %BreakdownSection
@onready var _enemies_value:     Label         = %EnemiesDefeatedValue
@onready var _echoes_value:      Label         = %EchoesAliveValue
@onready var _rounds_value:      Label         = %RoundsValue
@onready var _sanctum_button:    Button        = %SanctumButton
@onready var _next_stage_button: Button        = %NextStageButton
@onready var _emotion_list:            VBoxContainer = %EmotionList
# Phase 1 Close — new nodes (authored in .tscn).
@onready var _summary_label:           Label         = %SummaryLabel
@onready var _effects_rail:            HFlowContainer = %EffectsRail
# CardContent — parent of all card sections, used for dynamic vow nodes.
@onready var _card_content:            VBoxContainer = $CenterContainer/ResultCard/CardContent
# V2-VOW-002: vow outcome section nodes (authored in .tscn).
@onready var _vow_section:             VBoxContainer = %VowOutcomeSection
@onready var _vow_outcome_header:      Label         = %VowOutcomeHeader
@onready var _vow_list:                VBoxContainer = %VowOutcomeList
@onready var _vow_discovered_section:  VBoxContainer = %VowDiscoveredSection
@onready var _vow_discovered_list:     VBoxContainer = %VowDiscoveredList

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
	_ase_value.text     = "0"
	_ekwan_row.visible  = false
	_ekwan_value.text   = "0"
	for child in _breakdown_section.get_children():
		child.queue_free()
	for child in _emotion_list.get_children():
		child.queue_free()
	# Phase 1 Close: reset new nodes
	_summary_label.text    = ""
	_summary_label.visible = false
	for child in _effects_rail.get_children():
		child.queue_free()
	_effects_rail.visible = false
	# V2-VOW-002: reset template-based vow sections
	_vow_section.visible = false
	_vow_outcome_header.remove_theme_color_override("font_color")
	for child in _vow_list.get_children():
		child.queue_free()
	_vow_discovered_section.visible = false
	for child in _vow_discovered_list.get_children():
		child.queue_free()


func _render(data: Dictionary, actions: Dictionary) -> void:
	# V2-ECONOMY-001: scout_return path — partial Ase, no rank/vow/next_stage
	var run_type := str(data.get("run_type", ""))
	if run_type == "scout_return":
		_render_scout_return(data, actions)
		return
	# V2-STAGE-003: contact_result path — NPC conversation outcome
	if run_type == "contact_result":
		_render_contact_result(data, actions)
		return
	# Phase 1 Close: situation_result path — in-explore situation outcome
	if run_type == "situation_result":
		_render_situation_result(data, actions)
		return

	var victory: bool = bool(data.get("victory", false))

	_banner.text = "VICTORY" if victory else "DEFEAT"
	_reason.text = _format_reason(str(data.get("reason", "")))

	# Phase 1 Close: Summary zone
	var summary_line := str(data.get("summary_line", ""))
	if not summary_line.is_empty():
		_summary_label.text    = summary_line
		_summary_label.visible = true

	_enemies_value.text = str(data.get("enemies_defeated", 0))
	_echoes_value.text  = str(data.get("echoes_survived", 0))
	_rounds_value.text  = str(data.get("round_ended", 0))

	# Rank badge — color is informational (S=gold, F=red)
	var rank := str(data.get("rank", "F"))
	_rank_badge.text = rank
	_rank_badge.add_theme_color_override("font_color", _rank_color(rank))

	# Ase earned
	_ase_value.text = str(data.get("ase_awarded", 0)) + " Ase"

	# V2-ECONOMY-001: Ekwan earned — show row only when > 0
	var ekwan_awarded := int(data.get("ekwan_awarded", 0))
	_ekwan_row.visible = ekwan_awarded > 0
	_ekwan_value.text  = str(ekwan_awarded) + " Ekwan"

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
		row.get_node("%EmotionArcLabel").text = "%s → %s" % [
			EmotionPresentation.display_name(str(entry.get("pre_emotional_status", ""))),
			EmotionPresentation.display_name(str(entry.get("post_emotional_status", ""))),
		]
		row.get_node("%RefusedLabel").visible  = bool(entry.get("refused", false))
		# Phase 1 Close: token + direction cue + KO tag
		_populate_emotion_row_extras(row, entry)
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

	# Phase 1 Close: effects rail (Ase, Ekwan, objective, vow, + effects[] extras).
	_build_effects_rail(data)

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
# Phase 1 Close: Situation Result renderer
# ─────────────────────────────────────────────────────────────

func _render_situation_result(data: Dictionary, actions: Dictionary) -> void:
	var surface := str(data.get("surface", "Situation"))
	_banner.text = surface.replace("_", " ").capitalize()
	_banner.remove_theme_color_override("font_color")

	# Verdict badge (non-combat grade slot)
	var verdict := str(data.get("verdict", ""))
	if not verdict.is_empty():
		_rank_badge.visible = true
		_rank_badge.text    = verdict.capitalize()
		_rank_badge.add_theme_color_override("font_color", _verdict_color(verdict))
	else:
		_rank_badge.visible = false

	# Summary zone
	var summary_line := str(data.get("summary_line", ""))
	if not summary_line.is_empty():
		_summary_label.text    = summary_line
		_summary_label.visible = true

	# Echo stage rows
	var emotion_summary_v: Variant = data.get("emotion_summary", [])
	var emotion_summary: Array = emotion_summary_v if emotion_summary_v is Array else []
	for entry_v in emotion_summary:
		var entry: Dictionary = entry_v if entry_v is Dictionary else {}
		var row: Node = EmotionEntryScene.instantiate()
		row.get_node("%EchoNameLabel").text   = str(entry.get("name", ""))
		row.get_node("%EmotionArcLabel").text = "%s → %s" % [
			EmotionPresentation.display_name(str(entry.get("pre_emotional_status", ""))),
			EmotionPresentation.display_name(str(entry.get("post_emotional_status", ""))),
		]
		row.get_node("%RefusedLabel").visible = bool(entry.get("refused", false))
		_populate_emotion_row_extras(row, entry)
		_emotion_list.add_child(row)
		# Per-echo bark (situation bark field)
		var bark := str(entry.get("bark", ""))
		if not bark.is_empty():
			var bark_lbl := Label.new()
			bark_lbl.text = "\"%s\"" % bark
			bark_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
			bark_lbl.add_theme_font_size_override("font_size", 12)
			bark_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			_emotion_list.add_child(bark_lbl)

	# Effects rail
	_build_effects_rail(data)

	# Wire continue button (returns to stage explore)
	if actions.has("cta.continue"):
		var act_v: Variant = actions["cta.continue"]
		if act_v is Dictionary:
			_sanctum_action         = act_v
			_sanctum_button.text    = str(act_v.get("label", "Continue"))
			_sanctum_button.visible = true


# ─────────────────────────────────────────────────────────────
# Phase 1 Close: emotion row extras (token + direction cue + KO)
# Called for both combat and situation_result rows.
# ─────────────────────────────────────────────────────────────

func _populate_emotion_row_extras(row: Node, entry: Dictionary) -> void:
	# Token: first letter of name, colored by direction
	var token_label_node: Node = row.get_node_or_null("%TokenLabel")
	if token_label_node is Label:
		var name_str := str(entry.get("name", ""))
		(token_label_node as Label).text = name_str.left(1).to_upper() if not name_str.is_empty() else "?"
	var token_circle: Node = row.get_node_or_null("TokenCircle")
	if token_circle is PanelContainer:
		(token_circle as PanelContainer).self_modulate = _token_color_for_direction(
			str(entry.get("direction", "")),
			str(entry.get("tag", ""))
		)

	# Direction cue label
	var dir_node: Node = row.get_node_or_null("%DirectionCueLabel")
	if dir_node is Label:
		var dir := str(entry.get("direction", ""))
		var cue_text: String
		match dir:
			"lift":   cue_text = "spirits lift ↑"
			"ease":   cue_text = "fear eases ↓"
			"steady": cue_text = "— steady"
			"fall":   cue_text = "shaken ↓"
			_:        cue_text = ""
		(dir_node as Label).text    = cue_text
		(dir_node as Label).visible = not cue_text.is_empty()

	# KO tag
	var ko_node: Node = row.get_node_or_null("%KoTagLabel")
	if ko_node is Label:
		(ko_node as Label).visible = str(entry.get("tag", "")) == "ko"


func _token_color_for_direction(direction: String, tag: String) -> Color:
	if tag == "ko":
		return Color("#7A5A4A")   # rust — KO / fallen
	match direction:
		"lift":   return Color("#E8A030")   # Amber — morale rising
		"steady": return Color("#E8A030")   # Amber — holding
		"ease":   return Color("#7AB5C8")   # Mist Blue — fear easing
		"fall":   return Color("#6E8FA8")   # grey-blue — shaken
		_:        return Color("#A8865A")   # Warm Brass — default


# ─────────────────────────────────────────────────────────────
# Phase 1 Close: Effects Rail builder
# Dual-source: existing fields (ase_awarded, ekwan_awarded, enemies_defeated,
# vow_outcome) + new effects[] array for item/intel/continuity extras.
# ─────────────────────────────────────────────────────────────

func _build_effects_rail(data: Dictionary) -> void:
	var chips_added := 0

	# Ase chip
	var ase := int(data.get("ase_awarded", 0))
	if ase > 0:
		var chip: Node = EffectChipScene.instantiate()
		_effects_rail.add_child(chip)
		chip.call("setup", "ase", "+%d Ase" % ase, "", "partial")
		chips_added += 1

	# Ekwan chip
	var ekwan := int(data.get("ekwan_awarded", 0))
	if ekwan > 0:
		var chip: Node = EffectChipScene.instantiate()
		_effects_rail.add_child(chip)
		chip.call("setup", "ekwan", "+%d Ekwan" % ekwan, "", "warn")
		chips_added += 1

	# Objective chip (combat: enemies defeated out of survived)
	var enemies_defeated := int(data.get("enemies_defeated", 0))
	if enemies_defeated > 0:
		var chip: Node = EffectChipScene.instantiate()
		_effects_rail.add_child(chip)
		chip.call("setup", "objective", "%d defeated" % enemies_defeated, "", "good")
		chips_added += 1

	# Vow chip
	var vow_v: Variant = data.get("vow_outcome", {})
	var vow: Dictionary = vow_v if vow_v is Dictionary else {}
	var vow_event := str(vow.get("event", ""))
	if vow_event == "break":
		var chip: Node = EffectChipScene.instantiate()
		_effects_rail.add_child(chip)
		chip.call("setup", "vow", "vow fractured", "", "bad")
		chips_added += 1
	elif vow_event == "benefit" or vow_event == "compliant":
		var chip: Node = EffectChipScene.instantiate()
		_effects_rail.add_child(chip)
		chip.call("setup", "vow", "vow held", "", "good")
		chips_added += 1

	# effects[] extras (item, intel, continuity, storyweight, etc.)
	var effects_v: Variant = data.get("effects", [])
	var effects: Array = effects_v if effects_v is Array else []
	for fx_v in effects:
		var fx: Dictionary = fx_v if fx_v is Dictionary else {}
		var kind  := str(fx.get("kind",  ""))
		var label := str(fx.get("label", ""))
		var value: String = str(fx.get("value", ""))
		var tone  := str(fx.get("tone",  ""))
		if label.is_empty():
			continue
		var chip: Node = EffectChipScene.instantiate()
		_effects_rail.add_child(chip)
		chip.call("setup", kind, label, value, tone)
		chips_added += 1

	_effects_rail.visible = chips_added > 0


func _verdict_color(verdict: String) -> Color:
	match verdict:
		"carried", "good": return Color("#4CAF72")   # Akan Green
		"passed":          return Color("#C8A96E")   # Akan Gold
		"partial":         return Color("#E8A030")   # Amber
		"missed", "failed":return Color("#C05050")   # muted red
		_:                 return Color("#E8D0A0")   # Pale Kente default


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

	# V2-ECONOMY-001: skip total line on scout_return (total_ase == 0 signals no total)
	if total_ase > 0:
		var sep := HSeparator.new()
		_breakdown_section.add_child(sep)
		var total_lbl := Label.new()
		total_lbl.text = "= %d Ase" % total_ase
		_breakdown_section.add_child(total_lbl)


# ─────────────────────────────────────────────────────────────
# V2-STAGE-003: Contact Result renderer
# ─────────────────────────────────────────────────────────────

func _render_contact_result(data: Dictionary, actions: Dictionary) -> void:
	var outcome    := str(data.get("outcome",    ""))
	var role_label := str(data.get("role_label", "Contact"))
	var outcome_text := str(data.get("outcome_text", "The conversation has ended."))

	_banner.text = role_label.to_upper()
	match outcome:
		"good":    _banner.add_theme_color_override("font_color", Color("#4CAF72"))
		"partial": _banner.add_theme_color_override("font_color", Color("#C8A96E"))
		"failed":  _banner.add_theme_color_override("font_color", Color("#C05050"))
		_:         _banner.remove_theme_color_override("font_color")

	_reason.text = outcome_text

	# Phase 1 Close: optional summary_line enrichment (harmless if absent)
	var summary_line := str(data.get("summary_line", ""))
	if not summary_line.is_empty():
		_summary_label.text    = summary_line
		_summary_label.visible = true

	# Repurpose rank badge as outcome level chip — hide it to keep layout clean
	_rank_badge.visible = false

	# Wire continue button (reuses _sanctum_button)
	if actions.has("cta.continue"):
		var act_v: Variant = actions["cta.continue"]
		if act_v is Dictionary:
			_sanctum_action         = act_v
			_sanctum_button.text    = str(act_v.get("label", "Continue"))
			_sanctum_button.visible = true


# ─────────────────────────────────────────────────────────────
# V2-ECONOMY-001: Scout Return renderer
# ─────────────────────────────────────────────────────────────

func _render_scout_return(data: Dictionary, actions: Dictionary) -> void:
	_banner.text = "Scout Return"
	_banner.add_theme_color_override("font_color", Color("#7AB5C8"))  # Mist Blue — neutral info

	var intel := int(data.get("intel_count", 0))
	_reason.text = "%d situation%s revealed" % [intel, "s" if intel != 1 else ""]

	# Phase 1 Close: optional summary_line enrichment (harmless if absent)
	var summary_line := str(data.get("summary_line", ""))
	if not summary_line.is_empty():
		_summary_label.text    = summary_line
		_summary_label.visible = true

	_rank_badge.visible        = false
	_next_stage_button.visible = false

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
		lbl.text = "%s — [%s]" % [nm, EmotionPresentation.display_name(es)] if es != "" else nm
		if es != "":
			lbl.theme_type_variation = EmotionPresentation.text_theme(es)
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
		"totem_taken":          return "The totem was taken."
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
	match event:
		"break":
			_vow_outcome_header.text = "The promise fractured."
			_vow_outcome_header.add_theme_color_override("font_color", Color("#E8412A"))  # Ohene Red
		"benefit":
			_vow_outcome_header.text = "The promise held."
			_vow_outcome_header.add_theme_color_override("font_color", Color("#C8A96E"))  # Akan Gold
		"compliant":
			_vow_outcome_header.text = "The promise holds."
			_vow_outcome_header.add_theme_color_override("font_color", Color("#C8A96E"))  # Akan Gold
		_:
			return

	# Sub-line for compliance count or penalty hint — added to the pre-authored list container.
	if event == "compliant":
		var count := int(vow.get("compliance_count", 0))
		if count > 0:
			var count_lbl := Label.new()
			count_lbl.text = "%d stage%s honored" % [count, "s" if count != 1 else ""]
			count_lbl.add_theme_color_override("font_color", Color("#A8865A"))  # Warm Brass
			_vow_list.add_child(count_lbl)
	elif event == "break":
		var morale := int(vow.get("morale_delta", 0))
		var fear   := int(vow.get("fear_delta",   0))
		if morale != 0 or fear != 0:
			var pen_lbl := Label.new()
			pen_lbl.text = "Morale %+d  Fear %+d" % [morale, fear]
			pen_lbl.add_theme_color_override("font_color", Color("#E8D0A0"))  # Pale Kente
			_vow_list.add_child(pen_lbl)

	_vow_section.visible = true


# V2-VOW-002: Vow discovery section — shows vows unlocked this stage.
func _build_vow_discovered_section(data: Dictionary) -> void:
	var vows_v: Variant = data.get("newly_unlocked_vows", [])
	var vows: Array = vows_v if vows_v is Array else []
	if vows.is_empty():
		return

	for vow_v in vows:
		var vow: Dictionary = vow_v if vow_v is Dictionary else {}
		var name_lbl := Label.new()
		name_lbl.text = str(vow.get("vow_name", ""))
		name_lbl.add_theme_color_override("font_color", Color("#E8D0A0"))
		_vow_discovered_list.add_child(name_lbl)

		var twi_lbl := Label.new()
		twi_lbl.text = str(vow.get("proverb_twi", ""))
		twi_lbl.add_theme_color_override("font_color", Color("#C8A96E"))
		twi_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_vow_discovered_list.add_child(twi_lbl)

		var en_lbl := Label.new()
		en_lbl.text = '"%s"' % str(vow.get("proverb_en", ""))
		en_lbl.add_theme_color_override("font_color", Color("#A8865A"))
		en_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_vow_discovered_list.add_child(en_lbl)

	_vow_discovered_section.visible = true


func _ready() -> void:
	_sanctum_button.pressed.connect(_on_sanctum_pressed)
	_next_stage_button.pressed.connect(_on_next_stage_pressed)
