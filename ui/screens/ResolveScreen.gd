# res://ui/screens/ResolveScreen.gd
# COMBAT-007: Resolve Screen scaffold — UI-001 bespoke screen contract.
# Renders the final combat result (type "flow.resolve") emitted by
# FlowEncounterState.build_final_snapshot().
#
# Scaffold scope: labels only. Full art/layout deferred to UI-005.
#
# Contract (UI-001):
#   set_snapshot(snap) → _clear() + _render(data, actions)
#   action_requested signal for all player interactions
#   Never reads sim internals directly

class_name ResolveScreen
extends Control

signal action_requested(action: Dictionary)

@onready var _title_label:      Label  = $Content/TitleLabel
@onready var _outcome_label:    Label  = $Content/OutcomeLabel
@onready var _reason_label:     Label  = $Content/ReasonLabel
@onready var _round_label:      Label  = $Content/RoundLabel
@onready var _actor_list:       VBoxContainer = $Content/ActorList
@onready var _continue_button:  Button = $Content/ContinueButton

var _continue_action: Dictionary = {}


# ─────────────────────────────────────────────────────────────
# UI-001 bespoke screen contract
# ─────────────────────────────────────────────────────────────

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "ResolveScreen: snapshot missing 'type'")
	assert(snap.has("data"), "ResolveScreen: snapshot missing 'data'")
	_clear()
	_render(snap["data"], snap.get("actions", {}))


func _clear() -> void:
	_continue_action = {}
	_continue_button.visible = false
	for child in _actor_list.get_children():
		child.queue_free()


func _render(data: Dictionary, actions: Dictionary) -> void:
	var victory: bool    = bool(data.get("victory", false))
	var reason: String   = str(data.get("reason", ""))
	var round_ended: int = int(data.get("round_ended", 0))

	_title_label.text   = str(data.get("title", "Result"))
	_outcome_label.text = "VICTORY" if victory else "DEFEAT"
	_reason_label.text  = _format_reason(reason)
	_round_label.text   = "Completed in Round %d" % round_ended

	# Actor roster summary — name: hp/max_hp (status)
	for actor in data.get("actors", []):
		var lbl := Label.new()
		var name_str: String   = str(actor.get("name", "?"))
		var hp: int            = int(actor.get("hp", 0))
		var max_hp: int        = int(actor.get("max_hp", 1))
		var status_str: String = str(actor.get("status", "alive"))
		lbl.text = "%s: %d/%d (%s)" % [name_str, hp, max_hp, status_str]
		lbl.add_theme_font_size_override("font_size", 14)
		_actor_list.add_child(lbl)

	# Wire continue button.
	if actions.has("cta.continue"):
		var act_v: Variant = actions["cta.continue"]
		if act_v is Dictionary:
			_continue_action    = act_v
			_continue_button.text    = str(act_v.get("label", "Continue"))
			_continue_button.visible = true


func _on_continue_pressed() -> void:
	if not _continue_action.is_empty():
		action_requested.emit(_continue_action)


## Maps internal reason strings to player-facing labels.
func _format_reason(reason: String) -> String:
	match reason:
		"all_enemies_defeated": return "All enemies defeated"
		"all_echoes_dead":      return "All echoes fell"
		"shrine_destroyed":     return "Shrine Destroyed"
	return reason


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
