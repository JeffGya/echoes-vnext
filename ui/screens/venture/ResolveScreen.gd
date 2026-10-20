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
#
# V2-STAGE-004 Phase 4: the ally-recruit offer (formerly rendered here as
# %AllyRecruitOffer) now lives on SanctumScreen as the %CompanionInvite
# modal, shown on Sanctum entry. This screen no longer reads
# data.ally_recruit_offer or cta.recruit_accept/cta.recruit_decline.

class_name ResolveScreen
extends Control

signal action_requested(action: Dictionary)
signal dismiss_requested

# Purposeful informational colors — adjustable in Godot inspector per instance.
@export var rank_color_s: Color = Color("#8B6A18")  # deep gold on warm panel
@export var rank_color_a: Color = Color("#2D6A4F")  # forest green
@export var rank_color_b: Color = Color("#315E6D")  # deep mist blue
@export var rank_color_c: Color = Color("#3D2817")  # dark brown
@export var rank_color_d: Color = Color("#76562E")  # warm brass
@export var rank_color_f: Color = Color("#9B342E")  # deep terracotta

const RewardEntryScene    := preload("res://ui/components/RewardEntryItem.tscn")
const EmotionEntryScene   := preload("res://ui/components/EmotionEntryItem.tscn")
const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")
const EffectChipScene     := preload("res://ui/components/EffectChip.tscn")
const PacePresentation    := preload("res://ui/components/PacePresentation.gd")
const PayoutCausePresentation := preload("res://ui/components/PayoutCausePresentation.gd")

## Fixed action the host dispatches once a first-time ledger is shown open (no slot, no payload).
const LEDGER_SEEN_ACTION := { "type": "resolve.ledger.mark_seen" }

@onready var _banner:            Label         = %BannerLabel
@onready var _reason:            Label         = %ReasonLabel
@onready var _fight_strip:       HFlowContainer = %FightStrip
@onready var _rank_chip:         PanelContainer = %RankChip
@onready var _enemies_chip:      PanelContainer = %EnemiesChip
@onready var _echoes_chip:       PanelContainer = %EchoesChip
@onready var _rounds_chip:       PanelContainer = %RoundsChip
@onready var _rank_badge:        Label         = %RankBadge
# Rank-cause note. Its text is authored in the .tscn, copy by Jeff: "The party's effort earned
# this rank" (docs/stories/pace-reward/decisions.md D-13, D-27).
@onready var _rank_cause:        Label         = %RankCauseLabel
@onready var _enemies_value:     Label         = %EnemiesDefeatedValue
@onready var _echoes_value:      Label         = %EchoesAliveValue
@onready var _rounds_key:        Label         = %RoundsKey
@onready var _rounds_value:      Label         = %RoundsValue
@onready var _summary_button:    Button        = %EarningsSummary
@onready var _ase_total:         Label         = %AseTotalLabel
@onready var _ekwan_total:       Label         = %EkwanTotalLabel
@onready var _summary_hint:      Label         = %SummaryHintLabel
@onready var _chevron:           Label         = %ChevronLabel
@onready var _ledger:            VBoxContainer = %Ledger
@onready var _fight_header:      Label         = %FightGroupHeader
@onready var _breakdown_section: VBoxContainer = %BreakdownSection
@onready var _stage_group:       VBoxContainer = %StageGroup
@onready var _stage_section:     VBoxContainer = %StageSection
@onready var _total_value:       Label         = %TotalValue
@onready var _ekwan_line:        HBoxContainer = %EkwanLine
@onready var _ekwan_line_value:  Label         = %EkwanLineValue
@onready var _tooltip:           CauseTooltip  = %CauseTooltip
@onready var _sanctum_button:    Button        = %SanctumButton
@onready var _next_stage_button: Button        = %NextStageButton
@onready var _emotion_list:            VBoxContainer = %EmotionList
# Phase 1 Close — new nodes (authored in .tscn).
@onready var _summary_label:           Label         = %SummaryLabel
@onready var _effects_rail:            HFlowContainer = %EffectsRail
# CardContent — parent of all card sections, used for dynamic vow nodes.
@onready var _card_content:            VBoxContainer = %CardContent
# V2-VOW-002: vow outcome section nodes (authored in .tscn).
@onready var _vow_section:             VBoxContainer = %VowOutcomeSection
@onready var _vow_outcome_header:      Label         = %VowOutcomeHeader
@onready var _vow_list:                VBoxContainer = %VowOutcomeList
@onready var _vow_discovered_section:  VBoxContainer = %VowDiscoveredSection
@onready var _vow_discovered_list:     VBoxContainer = %VowDiscoveredList
@onready var _safe_frame:              MarginContainer = %SafeFrame
@onready var _result_card:             Panel = %ResultCard
@onready var _body_viewport:           Control = %BodyViewport
@onready var _scroll_body:             ScrollContainer = %ScrollContainer

var _sanctum_action:    Dictionary = {}
var _next_stage_action: Dictionary = {}
var _layout: Dictionary = {}
var _ledger_open := false
# Identity of the result on screen, without ledger_seen: the host re-renders the same result after
# the mark_seen dispatch, and that re-render must keep the ledger as the player left it.
var _result_key: int = 0
var _has_result_key := false


# ─────────────────────────────────────────────────────────────
# UI-001 bespoke screen contract
# ─────────────────────────────────────────────────────────────

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "ResolveScreen: snapshot missing 'type'")
	assert(snap.has("data"), "ResolveScreen: snapshot missing 'data'")
	var data: Dictionary = snap["data"]
	var key := _key_of(data)
	var same_result := _has_result_key and key == _result_key
	_has_result_key = true
	_result_key = key
	_clear()
	_render(data, snap.get("actions", {}))
	_finish_ledger(data, same_result)

func present(payload: Dictionary) -> void:
	var layout_v: Variant = payload.get("layout", {})
	if layout_v is Dictionary:
		set_layout(layout_v)
	var snap_v: Variant = payload.get("snapshot", {})
	if snap_v is Dictionary:
		set_snapshot(snap_v)

func set_layout(layout: Dictionary) -> void:
	_layout = layout.duplicate(true)
	if _safe_frame != null and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", _layout)
	_apply_profile_size()


func _clear() -> void:
	_sanctum_action    = {}
	_next_stage_action = {}
	_sanctum_button.visible    = false
	_next_stage_button.visible = false
	_banner.remove_theme_color_override("font_color")
	_tooltip.hide_tooltip()
	_fight_strip.visible = false
	for chip in [_rank_chip, _enemies_chip, _echoes_chip, _rounds_chip]:
		chip.visible = true
	_rank_badge.text = "—"
	_rank_badge.remove_theme_color_override("font_color")
	_rank_cause.visible = false
	_rounds_key.remove_theme_color_override("font_color")
	_rounds_value.remove_theme_color_override("font_color")
	_summary_button.visible = false
	_ekwan_total.visible = false
	_ledger.visible = false
	_stage_group.visible = false
	_fight_header.visible = false
	_ekwan_line.visible = false
	for section in [_breakdown_section, _stage_section]:
		for row in section.get_children():
			section.remove_child(row)
			row.queue_free()
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
	# V2-COMBAT-003: forced_retreat is the same card shape with zero payout — same renderer.
	var run_type := str(data.get("run_type", ""))
	if run_type == "scout_return" or run_type == "forced_retreat":
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

	_fight_strip.visible = true
	_enemies_value.text = str(data.get("enemies_defeated", 0))
	_echoes_value.text  = str(data.get("echoes_survived", 0))
	_rounds_value.text  = str(data.get("round_ended", 0))

	# Rank badge — color is informational (S=gold, F=red)
	var rank := str(data.get("rank", "F"))
	_rank_badge.text = rank
	_rank_badge.add_theme_color_override("font_color", _rank_color(rank))

	# Pace keys exist only for a pace-mode win (decisions.md D-19); the victory check is a second guard.
	var pace_state := str(data.get("pace_state", "")) if victory else ""
	if PacePresentation.has_pace(pace_state):
		var pace_color := PacePresentation.color(pace_state, true)
		_rounds_key.add_theme_color_override("font_color", pace_color)
		_rounds_value.add_theme_color_override("font_color", pace_color)
		_rank_cause.visible = bool(data.get("pace_changed_rank", false))

	_build_ledger(data)

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
			_bark_lbl.add_theme_color_override("font_color", Color("#6F5A43"))
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

	# Phase 1 Close: effects rail (vow + effects[] extras).
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
		_fight_strip.visible = true
		for chip in [_enemies_chip, _echoes_chip, _rounds_chip]:
			chip.visible = false
		_rank_badge.text    = verdict.capitalize()
		_rank_badge.add_theme_color_override("font_color", _verdict_color(verdict))

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
			bark_lbl.add_theme_color_override("font_color", Color("#6F5A43"))
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
# Dual-source: vow_outcome + the effects[] array for item/intel/continuity extras.
# Ase, Ekwan and enemy counts live in the earnings summary and the fight strip.
# ─────────────────────────────────────────────────────────────

func _build_effects_rail(data: Dictionary) -> void:
	var chips_added := 0

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
# Earnings summary + ledger
# ─────────────────────────────────────────────────────────────

## The earnings line and the ledger rows. The total is the data total: ase_awarded plus the stage
## payout when the card carries one. Ekwan shows only on the card that carries stage_payout_ekwan.
func _build_ledger(data: Dictionary) -> void:
	var fight_rows := _net_consolation(_ase_rows(data.get("reward_breakdown", [])))
	var stage_rows := _ase_rows(data.get("stage_payout_rows", []))
	var has_stage := not stage_rows.is_empty()
	for row in fight_rows:
		_add_row(_breakdown_section, row, PayoutCausePresentation.SCOPE_FIGHT)
	for row in stage_rows:
		_add_row(_stage_section, row, PayoutCausePresentation.SCOPE_STAGE)
	_fight_header.visible = has_stage and not fight_rows.is_empty()
	_stage_group.visible = has_stage

	var total := int(data.get("ase_awarded", 0))
	if data.has("stage_payout_ase"):
		total += int(data["stage_payout_ase"])
	_ase_total.text = "+%d Ase" % total
	_total_value.text = "= %d Ase" % total
	var ekwan := int(data.get("stage_payout_ekwan", 0))
	_ekwan_total.text = "+%d Ekwan" % ekwan
	_ekwan_total.visible = ekwan > 0
	_ekwan_line_value.text = "+%d Ekwan" % ekwan
	_ekwan_line.visible = ekwan > 0

	var has_rows := not fight_rows.is_empty() or has_stage
	_summary_button.visible = true
	_summary_button.disabled = not has_rows
	_summary_hint.visible = has_rows
	_chevron.visible = has_rows


## Rows that show: dictionaries with a label, in Ase. Ekwan rows are ignored (no Ekwan row exists).
func _ase_rows(rows_v: Variant) -> Array:
	var out: Array = []
	if not rows_v is Array:
		return out
	for entry_v in (rows_v as Array):
		if not entry_v is Dictionary:
			continue
		var entry: Dictionary = entry_v
		if str(entry.get("label", "")).is_empty() or str(entry.get("currency", "ase")) == "ekwan":
			continue
		out.append(entry)
	return out


## A defeat sends two defeat_consolation rows (params.part base and penalty). The player sees
## one "Consolation" row with the net amount, at the place of the first.
func _net_consolation(rows: Array) -> Array:
	var out: Array = []
	var merged_at := -1
	for entry in rows:
		if str(entry.get("cause", "")) != "defeat_consolation":
			out.append(entry)
		elif merged_at < 0:
			merged_at = out.size()
			var net: Dictionary = (entry as Dictionary).duplicate(true)
			net["params"] = {}
			out.append(net)
		else:
			out[merged_at]["delta"] = int(out[merged_at]["delta"]) + int(entry.get("delta", 0))
	return out


func _add_row(section: VBoxContainer, entry: Dictionary, scope: String) -> void:
	var item: RewardEntryItem = RewardEntryScene.instantiate()
	section.add_child(item)
	item.setup(entry, scope)
	item.cause_requested.connect(_on_cause_requested)
	item.cause_released.connect(_tooltip.release)


func _on_cause_requested(anchor: Control, title: String, cause: String, params: Dictionary,
		scope: String, pinned: bool) -> void:
	_tooltip.show_for(anchor, title, PayoutCausePresentation.tooltip(cause, params, scope), pinned)


func _key_of(data: Dictionary) -> int:
	var copy := data.duplicate(true)
	copy.erase("ledger_seen")
	return copy.hash()


## Opens the ledger the first time the player sees a result (ledger_seen false), then asks the
## host to record it. A re-render of the same result keeps the ledger as the player left it.
func _finish_ledger(data: Dictionary, same_result: bool) -> void:
	var can_open := _summary_button.visible and not _summary_button.disabled
	var first_time := data.has("ledger_seen") and not bool(data["ledger_seen"])
	var open := _ledger_open if same_result else first_time
	_set_ledger_open(open and can_open)
	if first_time and not same_result and _ledger_open:
		action_requested.emit(LEDGER_SEEN_ACTION.duplicate())


func _set_ledger_open(open: bool) -> void:
	_ledger_open = open
	_ledger.visible = open
	_chevron.text = "▴" if open else "▾"
	if not open:
		_tooltip.hide_tooltip()


func _on_summary_pressed() -> void:
	_set_ledger_open(not _ledger_open)


# ─────────────────────────────────────────────────────────────
# V2-STAGE-003: Contact Result renderer
# ─────────────────────────────────────────────────────────────

func _render_contact_result(data: Dictionary, actions: Dictionary) -> void:
	var outcome    := str(data.get("outcome",    ""))
	var role_label := str(data.get("role_label", "Contact"))
	var outcome_text := str(data.get("outcome_text", "The conversation has ended."))

	_banner.text = role_label.to_upper()
	match outcome:
		"good":    _banner.add_theme_color_override("font_color", Color("#2D6A4F"))
		"partial": _banner.add_theme_color_override("font_color", Color("#76562E"))
		"failed":  _banner.add_theme_color_override("font_color", Color("#9B342E"))
		_:         _banner.remove_theme_color_override("font_color")

	_reason.text = outcome_text

	# Phase 1 Close: optional summary_line enrichment (harmless if absent)
	var summary_line := str(data.get("summary_line", ""))
	if not summary_line.is_empty():
		_summary_label.text    = summary_line
		_summary_label.visible = true

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
	# V2-COMBAT-003: forced_retreat is a stalemate, not a scout return — its own header line
	# so the player never reads it as a retreat they chose.
	var _is_forced_retreat := str(data.get("run_type", "")) == "forced_retreat"
	_banner.text = "Forced Retreat" if _is_forced_retreat else "Scout Return"
	_banner.add_theme_color_override("font_color", Color("#315E6D"))  # Deep Mist Blue on warm panel

	if _is_forced_retreat:
		_reason.text = "The fight did not end"
	else:
		var intel := int(data.get("intel_count", 0))
		_reason.text = "%d situation%s revealed" % [intel, "s" if intel != 1 else ""]

	# Phase 1 Close: optional summary_line enrichment (harmless if absent)
	var summary_line := str(data.get("summary_line", ""))
	if not summary_line.is_empty():
		_summary_label.text    = summary_line
		_summary_label.visible = true

	_next_stage_button.visible = false
	_build_ledger(data)

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
		dismiss_requested.emit()
		action_requested.emit(_sanctum_action)


func _on_next_stage_pressed() -> void:
	if not _next_stage_action.is_empty():
		dismiss_requested.emit()
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
			_vow_outcome_header.add_theme_color_override("font_color", Color("#76562E"))  # Warm Brass
		"compliant":
			_vow_outcome_header.text = "The promise holds."
			_vow_outcome_header.add_theme_color_override("font_color", Color("#76562E"))  # Warm Brass
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
			pen_lbl.add_theme_color_override("font_color", Color("#9B342E"))  # Deep terracotta
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
		name_lbl.add_theme_color_override("font_color", Color("#3D2817"))
		_vow_discovered_list.add_child(name_lbl)

		var twi_lbl := Label.new()
		twi_lbl.text = str(vow.get("proverb_twi", ""))
		twi_lbl.add_theme_color_override("font_color", Color("#76562E"))
		twi_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_vow_discovered_list.add_child(twi_lbl)

		var en_lbl := Label.new()
		en_lbl.text = '"%s"' % str(vow.get("proverb_en", ""))
		en_lbl.add_theme_color_override("font_color", Color("#6F5A43"))
		en_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_vow_discovered_list.add_child(en_lbl)

	_vow_discovered_section.visible = true


func _ready() -> void:
	_summary_button.pressed.connect(_on_summary_pressed)
	_sanctum_button.pressed.connect(_on_sanctum_pressed)
	_next_stage_button.pressed.connect(_on_next_stage_pressed)

func _apply_profile_size() -> void:
	if _result_card == null or _body_viewport == null:
		return
	var profile: StringName = _layout.get("profile", &"compact")
	match profile:
		&"wide":
			_set_result_card_size(Vector2(840, 700))
			_body_viewport.custom_minimum_size = Vector2(0, 430)
		&"standard":
			_set_result_card_size(Vector2(760, 600))
			_body_viewport.custom_minimum_size = Vector2(0, 320)
		_:
			_set_result_card_size(Vector2(680, 476))
			_body_viewport.custom_minimum_size = Vector2(0, 210)

func _set_result_card_size(card_size: Vector2) -> void:
	_result_card.offset_left = -card_size.x * 0.5
	_result_card.offset_top = -card_size.y * 0.5
	_result_card.offset_right = card_size.x * 0.5
	_result_card.offset_bottom = card_size.y * 0.5
