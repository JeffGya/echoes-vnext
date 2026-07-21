class_name KeeperTacticalPrototypeUI
extends Control

signal action_requested(action: Dictionary)

const DIRECTIVE_LABELS := {
	"scout_carefully": "Scout Carefully",
	"seek_signs": "Seek Signs",
	"press_the_path": "Press the Path",
	"hold_the_circle": "Hold the Circle",
}
const PING_LABELS := {
	"hold_ground": "Hold Ground",
	"break_through": "Break Through",
	"focus_threat": "Focus Threat",
	"regroup": "Regroup",
	"secure_objective": "Secure Objective",
}
const PING_MODES := {
	"hold_ground": "echo_specific",
	"break_through": "area_based",
	"focus_threat": "party_wide",
	"regroup": "area_based",
	"secure_objective": "party_wide",
}
const PING_COSTS := {
	"hold_ground": 2,
	"break_through": 3,
	"focus_threat": 5,
	"regroup": 3,
	"secure_objective": 5,
}
const PING_SUGGESTIONS := {
	"hold_ground": "Ask one Echo to defend this nearby position and protect allies within reach.",
	"break_through": "Mark a short lane and ask nearby Echoes to push through it and confront blockers.",
	"focus_threat": "Ask the whole party to treat one visible enemy as the urgent threat.",
	"regroup": "Call Echoes already near this point to gather, protect one another, and leave danger.",
	"secure_objective": "Ask the whole party to prioritize the current RECOVER or PROTECT objective.",
}
const PING_INFLUENCES := {
	"hold_ground": "Raises guarding, nearby ally protection, and returning to the chosen anchor.",
	"break_through": "Raises movement through the lane and engagement with enemies blocking it.",
	"focus_threat": "Raises the marked enemy's priority while survival, rescue, Calling, and objective pressure may still override.",
	"regroup": "Raises movement toward the rally point, cohesion, protection, and leaving hazard exposure.",
	"secure_objective": "Raises entering, interacting with, holding, or defending the current objective.",
}
const PING_INSTRUCTIONS := {
	"hold_ground": "Select one living Echo, then select an anchor no more than 1 tile away.",
	"break_through": "Select the lane start and end on the board; maximum 5 contiguous tiles.",
	"focus_threat": "Select one living visible enemy or enemy totem carrier.",
	"regroup": "Select a rally tile; the radius-3 footprint determines recipients.",
	"secure_objective": "The current objective is selected automatically.",
}

@onready var _board_view: KeeperTacticalBoardView = %BoardView
@onready var _phase_label: Label = %PhaseLabel
@onready var _seed_header: Label = %SeedHeader
@onready var _objective_header: Label = %ObjectiveHeader
@onready var _board_hint: Label = %BoardHint
@onready var _routes_toggle: CheckButton = %RoutesToggle
@onready var _chokepoints_toggle: CheckButton = %ChokepointsToggle
@onready var _briefing_panel: VBoxContainer = %BriefingPanel
@onready var _preparation_panel: VBoxContainer = %PreparationPanel
@onready var _combat_panel: VBoxContainer = %CombatPanel
@onready var _review_panel: VBoxContainer = %ReviewPanel
@onready var _seed_input: LineEdit = %SeedInput
@onready var _recover_button: Button = %RecoverButton
@onready var _protect_button: Button = %ProtectButton
@onready var _board_diagnostics: Label = %BoardDiagnostics
@onready var _hazard_legend: Label = %HazardLegend
@onready var _echo_briefing: RichTextLabel = %EchoBriefing
@onready var _board_overlay_legend: Label = %BoardOverlayLegend
@onready var _directive_summary: Label = %DirectiveSummary
@onready var _deployment_status: Label = %DeploymentStatus
@onready var _selected_echo_label: Label = %SelectedEchoLabel
@onready var _preparation_board_legend: Label = %PreparationBoardLegend
@onready var _start_combat_button: Button = %StartCombatButton
@onready var _round_label: Label = %RoundLabel
@onready var _initiative_label: Label = %InitiativeLabel
@onready var _directive_label: Label = %DirectiveLabel
@onready var _objective_status: Label = %ObjectiveStatus
@onready var _charge_bar: ProgressBar = %ChargeBar
@onready var _charge_label: Label = %ChargeLabel
@onready var _threshold_label: Label = %ThresholdLabel
@onready var _speed_slow_button: Button = %SpeedSlowButton
@onready var _speed_normal_button: Button = %SpeedNormalButton
@onready var _speed_fast_button: Button = %SpeedFastButton
@onready var _ping_panel: VBoxContainer = %PingPanel
@onready var _ping_preview_panel: VBoxContainer = %PingPreviewPanel
@onready var _preview_title: Label = %PreviewTitle
@onready var _preview_suggestion: Label = %PreviewSuggestion
@onready var _preview_influence: Label = %PreviewInfluence
@onready var _preview_availability: Label = %PreviewAvailability
@onready var _preview_mode: Label = %PreviewMode
@onready var _preview_subject: Label = %PreviewSubject
@onready var _preview_instruction: Label = %PreviewInstruction
@onready var _preview_recipients: Label = %PreviewRecipients
@onready var _preview_cost: Label = %PreviewCost
@onready var _preview_duration: Label = %PreviewDuration
@onready var _preview_invalid: Label = %PreviewInvalid
@onready var _confirm_ping_button: Button = %ConfirmPingButton
@onready var _pending_guidance_panel: PanelContainer = %PendingGuidancePanel
@onready var _pending_guidance_title: Label = %PendingGuidanceTitle
@onready var _pending_guidance_text: Label = %PendingGuidanceText
@onready var _attention_label: Label = %AttentionLabel
@onready var _response_feedback: RichTextLabel = %ResponseFeedback
@onready var _timeline_tail: RichTextLabel = %TimelineTail
@onready var _debug_panel: VBoxContainer = %DebugPanel
@onready var _debug_text: RichTextLabel = %DebugText
@onready var _result_title: Label = %ResultTitle
@onready var _result_summary: Label = %ResultSummary
@onready var _report_text: RichTextLabel = %ReportText

var _snapshot: Dictionary = {}
var _data: Dictionary = {}
var _actions: Dictionary = {}
var _phase: String = "briefing"
var _selected_directive: String = "scout_carefully"
var _selected_actor_id: String = ""
var _selected_ping_id: String = ""
var _selected_subject: Dictionary = {}
var _deployment_assignments: Dictionary = {}
var _debug_visible: bool = false


func _ready() -> void:
	_wire_controls()
	_recover_button.grab_focus.call_deferred()


func set_snapshot(snapshot: Dictionary) -> void:
	assert(snapshot.has("type"), "PrototypeUI: snapshot missing type")
	assert(snapshot.has("data"), "PrototypeUI: snapshot missing data")
	_snapshot = snapshot.duplicate(true)
	_data = snapshot.get("data", {})
	_actions = snapshot.get("actions", {})
	_phase = str(snapshot.get("type", "prototype.briefing")).trim_prefix("prototype.")
	if not ["briefing", "preparation", "combat", "review"].has(_phase):
		_phase = str(_data.get("phase", "briefing"))
	_selected_directive = str(_data.get("directive_id", _selected_directive))
	_deployment_assignments = _data.get("deployment_assignments", _deployment_assignments)
	_selected_actor_id = str(_data.get("selected_deployment_actor_id", _selected_actor_id))
	_render()


func _wire_controls() -> void:
	%GenerateButton.pressed.connect(_on_generate_pressed)
	%RerollButton.pressed.connect(func() -> void: _request("cta.reroll", "prototype.board.reroll"))
	%PrepareButton.pressed.connect(func() -> void: _request("cta.prepare", "prototype.phase.prepare"))
	_seed_input.text_submitted.connect(func(_text: String) -> void: _on_generate_pressed())
	_recover_button.pressed.connect(_on_mode_selected.bind("recover"))
	_protect_button.pressed.connect(_on_mode_selected.bind("protect"))
	for directive_id in DIRECTIVE_LABELS.keys():
		(get_node(NodePath("%Directive_" + str(directive_id))) as Button).pressed.connect(_on_directive_selected.bind(directive_id))
	for index in 4:
		(get_node(NodePath("%EchoSelect" + str(index))) as Button).pressed.connect(_on_echo_selected.bind(index))
	_start_combat_button.pressed.connect(func() -> void: _request("cta.start", "prototype.combat.start"))
	_speed_slow_button.pressed.connect(_on_speed_selected.bind("slow"))
	_speed_normal_button.pressed.connect(_on_speed_selected.bind("normal"))
	_speed_fast_button.pressed.connect(_on_speed_selected.bind("fast"))
	for ping_id in PING_LABELS.keys():
		(get_node(NodePath("%Ping_" + str(ping_id))) as Button).pressed.connect(_on_ping_selected.bind(ping_id))
	_confirm_ping_button.pressed.connect(_on_confirm_ping)
	%CancelPingButton.pressed.connect(_on_cancel_ping)
	%ZoomInButton.pressed.connect(_board_view.zoom_in)
	%ZoomOutButton.pressed.connect(_board_view.zoom_out)
	%RecenterButton.pressed.connect(_board_view.recenter)
	%DebugButton.pressed.connect(_on_debug_toggled)
	_routes_toggle.toggled.connect(_on_overlay_toggled)
	_chokepoints_toggle.toggled.connect(_on_overlay_toggled)
	%RestartSameButton.pressed.connect(func() -> void: _request("cta.restart_same", "prototype.restart.same_seed"))
	%NewSeedButton.pressed.connect(func() -> void: _request("cta.new_seed", "prototype.restart.new_seed"))
	_board_view.cell_selected.connect(_on_board_cell_selected)
	_board_view.subject_selected.connect(_on_board_subject_selected)


func _render() -> void:
	_phase_label.text = _phase.capitalize()
	_seed_header.text = "Seed %d" % int(_snapshot.get("meta", {}).get("seed", _data.get("seed", 0)))
	_objective_header.text = str(_data.get("mode", "recover")).to_upper()
	_briefing_panel.visible = _phase == "briefing"
	_preparation_panel.visible = _phase == "preparation"
	_combat_panel.visible = _phase == "combat"
	_review_panel.visible = _phase == "review"
	var board: Dictionary = _data.get("board", {})
	var actors: Array = _data.get("actors", [])
	var preview: Dictionary = _data.get("ping_preview", {})
	_board_view.set_content(
		board,
		actors,
		preview,
		_deployment_assignments,
		_debug_visible,
		_phase,
		_data.get("unresolved_ping", {}),
		_data.get("last_turn_result", {}),
		str(_data.get("playback_speed_id", "normal")),
		_data.get("response_feedback", [])
	)
	_board_hint.text = _board_instruction()
	var show_analysis_overlays := _phase in ["briefing", "preparation"]
	_routes_toggle.visible = show_analysis_overlays
	_chokepoints_toggle.visible = show_analysis_overlays
	_board_overlay_legend.visible = _phase == "briefing"
	_preparation_board_legend.visible = _phase == "preparation"
	_on_overlay_toggled(false)
	_render_briefing(board, actors)
	_render_preparation(board, actors)
	_render_combat(actors, preview)
	_render_review()
	_render_debug(board)


func _render_briefing(board: Dictionary, actors: Array) -> void:
	_seed_input.text = str(_data.get("seed", _snapshot.get("meta", {}).get("seed", 0)))
	var mode := str(_data.get("mode", "recover"))
	_recover_button.disabled = mode == "recover"
	_protect_button.disabled = mode == "protect"
	var validation: Dictionary = board.get("validation", {})
	_board_diagnostics.text = "Board %dx%d • %d walkable cells\nChokepoint: %s • Route diversity: %s • Accessible: %s\n%s" % [
		int(board.get("bounds", {}).get("w", 0)), int(board.get("bounds", {}).get("h", 0)),
		(board.get("walkable", {}) as Dictionary).size(),
		_pass_fail(bool(validation.get("chokepoint_valid", false))),
		_pass_fail(bool(validation.get("route_diversity_valid", false))),
		_pass_fail(bool(validation.get("objective_accessible", false))),
		" • ".join(validation.get("diagnostics", [])),
	]
	_hazard_legend.text = "VISIBLE HAZARDS\n▲ Burning Ground — end-turn damage\n↝ Unstable Ground — pushes on entry\n✣ Binding Growth — ends movement"
	var echo_lines: PackedStringArray = []
	for actor_v in actors:
		var actor: Dictionary = actor_v if actor_v is Dictionary else {}
		if str(actor.get("faction", "")) != "echo":
			continue
		echo_lines.append("[b]%s[/b] — %s • Standing %d • %s\n%s; morale %d, fear %d" % [
			str(actor.get("name", "Echo")), _calling_label(str(actor.get("calling_origin", ""))),
			int(actor.get("standing", 1)), str(actor.get("expression_band", "nascent")).capitalize(),
			str(actor.get("tendency", "Autonomous")), int(actor.get("morale", 0)), int(actor.get("fear", 0)),
		])
	_echo_briefing.text = "\n\n".join(echo_lines)


func _render_preparation(board: Dictionary, actors: Array) -> void:
	_directive_summary.text = "%s\n%s" % [DIRECTIVE_LABELS.get(_selected_directive, "Choose a Directive"), _directive_intent(_selected_directive)]
	for directive_id in DIRECTIVE_LABELS.keys():
		var button := get_node(NodePath("%Directive_" + str(directive_id))) as Button
		button.disabled = directive_id == _selected_directive
	var echoes: Array = _data.get("party_roster", [])
	if echoes.is_empty():
		echoes = _echoes(actors)
	for index in 4:
		var button := get_node(NodePath("%EchoSelect" + str(index))) as Button
		if index < echoes.size():
			var echo: Dictionary = echoes[index]
			var echo_id := str(echo.get("id", ""))
			var assigned_slot := int(_deployment_assignments.get(echo_id, -1))
			button.visible = true
			button.text = "%s  •  %s  •  Slot %s\nStanding %d • %s expression • morale %d • fear %d\n%s\nPrediction: %s" % [
				str(echo.get("name", "Echo")),
				_calling_label(str(echo.get("calling_origin", ""))),
				str(assigned_slot + 1) if assigned_slot >= 0 else "—",
				int(echo.get("standing", 1)),
				str(echo.get("expression_band", "nascent")).capitalize(),
				int(echo.get("morale", 0)),
				int(echo.get("fear", 0)),
				str(echo.get("tendency", "Autonomous")),
				_preparation_prediction(echo),
			]
			button.disabled = false
			button.modulate = Color("#f5d66f") if echo_id == _selected_actor_id else Color.WHITE
		else:
			button.visible = false
	_selected_echo_label.text = (
		"Selected: %s. Now choose a cyan slot on the board; an occupied slot swaps Echoes."
		% _actor_name(_selected_actor_id, actors)
		if not _selected_actor_id.is_empty()
		else "Select one Echo from this roster, then choose a cyan slot on the board."
	)
	_deployment_status.text = "%d / %d Echoes positioned • one roster, one spatial assignment path" % [_deployment_assignments.size(), echoes.size()]
	_start_combat_button.disabled = _deployment_assignments.size() < echoes.size() or _selected_directive.is_empty()


func _render_combat(actors: Array, preview: Dictionary) -> void:
	var round_number := int(_data.get("round", 1))
	_round_label.text = "Round %d" % round_number
	var initiative: Array = _data.get("initiative_order", [])
	var initiative_index := int(_data.get("initiative_index", 0))
	var names: PackedStringArray = []
	for index in initiative.size():
		var name := _actor_name(str(initiative[index]), actors)
		names.append(("▶ " if index == initiative_index else "") + name)
	_initiative_label.text = "  →  ".join(names)
	_directive_label.text = "Directive: %s\n%s" % [DIRECTIVE_LABELS.get(str(_data.get("directive_id", "")), "—"), _directive_intent(str(_data.get("directive_id", "")))]
	_objective_status.text = _format_objective(_data.get("objective", {}))
	var charge: Dictionary = _data.get("ping_charge", {})
	var current := int(charge.get("current", 0))
	var maximum := int(charge.get("maximum", 5))
	_charge_bar.max_value = maximum
	_charge_bar.value = current
	_charge_label.text = "%d / %d Ping Charge" % [current, maximum]
	_threshold_label.text = "Round-based charge • Echo-specific %s  •  Area-based %s  •  Party-wide %s" % [_threshold_state(current, 2), _threshold_state(current, 3), _threshold_state(current, 5)]
	var playback_speed := str(_data.get("playback_speed_id", "normal"))
	_speed_slow_button.modulate = Color("#f5d66f") if playback_speed == "slow" else Color.WHITE
	_speed_normal_button.modulate = Color("#f5d66f") if playback_speed == "normal" else Color.WHITE
	_speed_fast_button.modulate = Color("#f5d66f") if playback_speed == "fast" else Color.WHITE
	_ping_panel.visible = true
	var unresolved: Dictionary = _data.get("unresolved_ping", {})
	var library: Dictionary = _data.get("ping_library", {})
	for ping_id in PING_LABELS.keys():
		var button := get_node(NodePath("%Ping_" + str(ping_id))) as Button
		var definition: Dictionary = library.get(ping_id, {})
		var required := int(definition.get("charge_required", PING_COSTS[ping_id]))
		var state := _ping_availability_label(ping_id, current, unresolved)
		button.text = "%s  •  %s\n%s • %d charge" % [PING_LABELS[ping_id], state, str(PING_MODES[ping_id]).replace("_", " ").capitalize(), required]
		button.disabled = false
		button.modulate = Color("#f5d66f") if ping_id == _selected_ping_id else Color.WHITE
	_render_ping_preview(preview)
	_render_pending_guidance(unresolved, _data.get("queued_ping_confirmation", {}), actors)
	_attention_label.visible = not (_data.get("attention_cues", []) as Array).is_empty()
	_attention_label.text = "ATTENTION — " + " • ".join(_data.get("attention_cues", []))
	_response_feedback.text = _format_responses(_data.get("response_feedback", _data.get("responses", [])), actors)
	_timeline_tail.text = _format_timeline(_data.get("timeline_tail", []), 8)


func _render_ping_preview(preview: Dictionary) -> void:
	_ping_preview_panel.visible = not _selected_ping_id.is_empty() or not preview.is_empty()
	if not _ping_preview_panel.visible:
		return
	var ping_id := str(preview.get("id", _selected_ping_id))
	var library: Dictionary = _data.get("ping_library", {})
	var definition: Dictionary = library.get(ping_id, {})
	var recipient_mode := str(preview.get("recipient_mode", PING_MODES.get(ping_id, "")))
	_preview_title.text = PING_LABELS.get(ping_id, "Choose a ping")
	_preview_suggestion.text = "SUGGESTION — %s" % str(preview.get("suggestion", definition.get("suggestion", PING_SUGGESTIONS.get(ping_id, ""))))
	_preview_influence.text = "Influence: %s" % str(preview.get("mechanical_influence", definition.get("mechanical_influence", PING_INFLUENCES.get(ping_id, ""))))
	var availability := str(preview.get("availability_state", _preview_availability_fallback(preview)))
	_preview_availability.text = "Availability: %s" % _availability_copy(availability, preview)
	_preview_availability.modulate = Color("#75c889") if availability == "available" else Color("#f09a66")
	_preview_mode.text = "Recipient mode: %s (exclusive)" % recipient_mode.replace("_", " ").capitalize()
	_preview_subject.text = "Subject: %s\nFootprint: %d cells" % [_format_subject(preview.get("subject", _selected_subject)), (preview.get("footprint", []) as Array).size()]
	_preview_instruction.text = "Targeting: %s" % str(preview.get("targeting_instruction", definition.get("targeting_instruction", PING_INSTRUCTIONS.get(ping_id, ""))))
	_preview_recipients.text = "Eligible Echoes: %s" % _recipient_names(preview.get("eligible_recipient_ids", []), _data.get("actors", []))
	_preview_cost.text = "Consumes all stored charge • Requirement %d" % int(preview.get("charge_required", PING_COSTS.get(ping_id, 0)))
	_preview_duration.text = "Activates in Round %d • %s" % [int(preview.get("activation_round", int(_data.get("round", 1)) + 1)), str(preview.get("expected_duration", "each recipient's first turn in the activation round"))]
	var valid := bool(preview.get("valid", false))
	var invalid_reason := str(preview.get("invalid_reason", "Select a valid subject on the board."))
	_preview_invalid.visible = not valid
	_preview_invalid.text = "Cannot confirm now: %s" % invalid_reason
	_confirm_ping_button.disabled = not valid
	_confirm_ping_button.text = "Confirm for Round %d" % int(preview.get("activation_round", int(_data.get("round", 1)) + 1))


func _render_pending_guidance(unresolved: Dictionary, queued: Dictionary, actors: Array) -> void:
	_pending_guidance_panel.visible = not unresolved.is_empty() or not queued.is_empty()
	if unresolved.is_empty() and queued.is_empty():
		return
	if unresolved.is_empty():
		_pending_guidance_title.text = "%s — confirmation queued" % PING_LABELS.get(str(queued.get("id", "")), "Ping")
		_pending_guidance_text.text = "Combat continues. This target will be revalidated and committed after the current actor's complete turn. No charge is consumed unless confirmation succeeds."
		return
	var ping_id := str(unresolved.get("id", ""))
	var remaining: Array = unresolved.get("remaining_recipient_ids", [])
	_pending_guidance_title.text = "%s — guidance pending" % PING_LABELS.get(ping_id, "Ping")
	_pending_guidance_text.text = "Confirmed in Round %d • activates in Round %d\nWaiting for: %s\nEach affected Echo reveals Align, Interpret, Hesitate, Object, or Refuse immediately before their turn, then acts on that response." % [
		int(unresolved.get("confirmed_round", 0)),
		int(unresolved.get("activation_round", 0)),
		_recipient_names(remaining, actors),
	]


func _render_review() -> void:
	if _phase != "review":
		return
	var result: Dictionary = _data.get("result", {})
	_result_title.text = "VICTORY" if bool(result.get("victory", false)) else "DEFEAT"
	_result_summary.text = "%s • %d rounds • %s" % [str(result.get("reason", "Battle resolved")).replace("_", " ").capitalize(), int(_data.get("round", 0)), DIRECTIVE_LABELS.get(str(_data.get("directive_id", "")), "No Directive")]
	_report_text.text = _build_report(_data)


func _render_debug(board: Dictionary) -> void:
	_debug_panel.visible = _debug_visible
	if not _debug_visible:
		return
	var validation: Dictionary = board.get("validation", {})
	_debug_text.text = "[b]Generator[/b]\nAttempt %d • valid %s • connected %s\nChokepoints %d • routes %d\n\n[b]Metrics[/b]\n%s" % [
		int(validation.get("attempt", 0)), str(validation.get("valid", false)), str(validation.get("connected", false)),
		(board.get("chokepoints", []) as Array).size(), (board.get("routes", []) as Array).size(),
		JSON.stringify(_data.get("metrics", {}), "  "),
	]


func _on_generate_pressed() -> void:
	var seed_value := int(_seed_input.text) if _seed_input.text.is_valid_int() else 1
	_request("cta.generate", "prototype.seed.set", {"seed": seed_value})


func _on_mode_selected(mode: String) -> void:
	_request("mode.%s" % mode, "prototype.mode.select", {"mode": mode})


func _on_directive_selected(directive_id: String) -> void:
	_selected_directive = directive_id
	_request("directive.%s" % directive_id, "prototype.directive.select", {"directive_id": directive_id})
	_render_preparation(_data.get("board", {}), _data.get("actors", []))


func _on_echo_selected(index: int) -> void:
	var echoes: Array = _data.get("party_roster", [])
	if echoes.is_empty():
		echoes = _echoes(_data.get("actors", []))
	if index >= echoes.size():
		return
	_selected_actor_id = str((echoes[index] as Dictionary).get("id", ""))
	_request("deployment.select_echo", "prototype.deployment.select_echo", {"actor_id": _selected_actor_id})


func _on_speed_selected(speed_id: String) -> void:
	_request("playback.speed", "prototype.playback.speed", {"speed_id": speed_id})


func _on_ping_selected(ping_id: String) -> void:
	_selected_ping_id = ping_id
	_selected_subject = _default_subject(ping_id)
	_request("ping.select", "prototype.ping.select", {"ping_id": ping_id})
	_request("ping.preview", "prototype.ping.preview", {"ping_id": ping_id, "subject": _selected_subject})


func _on_board_cell_selected(pos: Dictionary) -> void:
	if _phase == "preparation":
		var slot_index := _deployment_slot_index(pos)
		if not _selected_actor_id.is_empty() and slot_index >= 0:
			_request("deployment.assign_slot", "prototype.deployment.assign_slot", {"slot_index": slot_index})
		return
	if _selected_ping_id.is_empty():
		return
	_selected_subject = _subject_for_cell(_selected_ping_id, pos)
	_request("ping.preview", "prototype.ping.preview", {"ping_id": _selected_ping_id, "subject": _selected_subject})


func _on_board_subject_selected(subject: Dictionary) -> void:
	if _phase != "combat":
		return
	if str(subject.get("type", "")) != "actor":
		return
	var actor_id := str(subject.get("actor_id", ""))
	if _selected_ping_id == "focus_threat":
		_selected_subject = {"kind": "enemy", "enemy_id": actor_id, "position": subject.get("pos", {})}
		_request("ping.preview", "prototype.ping.preview", {"ping_id": _selected_ping_id, "subject": _selected_subject})
	elif _selected_ping_id == "hold_ground":
		_selected_subject = {"kind": "anchor", "actor_id": actor_id, "anchor": subject.get("pos", {})}
		_request("ping.preview", "prototype.ping.preview", {"ping_id": _selected_ping_id, "subject": _selected_subject})


func _on_confirm_ping() -> void:
	_request("ping.confirm", "prototype.ping.confirm", {"ping_id": _selected_ping_id, "subject": _selected_subject})
	_selected_ping_id = ""
	_selected_subject = {}


func _on_cancel_ping() -> void:
	_request("ping.cancel", "prototype.ping.cancel")
	_selected_ping_id = ""
	_selected_subject = {}
	_ping_preview_panel.visible = false


func _on_debug_toggled() -> void:
	_debug_visible = not _debug_visible
	_board_view.set_content(
		_data.get("board", {}), _data.get("actors", []), _data.get("ping_preview", {}),
		_deployment_assignments, _debug_visible, _phase, _data.get("unresolved_ping", {}),
		_data.get("last_turn_result", {}), str(_data.get("playback_speed_id", "normal")),
		_data.get("response_feedback", [])
	)
	_render_debug(_data.get("board", {}))


func _on_overlay_toggled(_pressed: bool) -> void:
	if _board_view.has_method("set_overlay_visibility"):
		_board_view.call("set_overlay_visibility", _routes_toggle.button_pressed, _chokepoints_toggle.button_pressed)


func _request(slot: String, fallback_type: String, payload: Dictionary = {}) -> void:
	var action: Dictionary = _actions.get(slot, {})
	if action.is_empty():
		action = {"type": fallback_type, "slot": slot, "payload": payload.duplicate(true)}
	else:
		action = action.duplicate(true)
		var merged_payload: Dictionary = action.get("payload", {})
		merged_payload.merge(payload, true)
		action["payload"] = merged_payload
	if bool(action.get("disabled", false)):
		return
	action_requested.emit(action)


func _default_subject(ping_id: String) -> Dictionary:
	if ping_id == "secure_objective":
		return {"kind": "objective", "position": _data.get("objective", {}).get("position", _data.get("board", {}).get("objective_pos", {}))}
	return {}


func _subject_for_cell(ping_id: String, pos: Dictionary) -> Dictionary:
	match ping_id:
		"hold_ground":
			return {"kind": "anchor", "actor_id": str(_selected_subject.get("actor_id", "")), "anchor": pos.duplicate(true)}
		"break_through":
			var start: Dictionary = _selected_subject.get("start", {})
			if start.is_empty() or _selected_subject.get("end", {}) != start:
				return {"kind": "lane", "start": pos.duplicate(true), "end": pos.duplicate(true)}
			return {"kind": "lane", "start": start.duplicate(true), "end": pos.duplicate(true)}
		"regroup": return {"kind": "rally", "rally": pos.duplicate(true), "radius": 3}
		_: return {"kind": "cell", "position": pos.duplicate(true)}


func _format_objective(objective: Dictionary) -> String:
	var mode := str(objective.get("mode", _data.get("mode", "recover")))
	if mode == "protect":
		return "PROTECT — %s\nGuard %d / %d • Totem HP %d / %d%s" % [str(objective.get("status", "Defend the totem")), int(objective.get("protect_counter", 0)), int(objective.get("protect_required", 0)), int(objective.get("hp", 0)), int(objective.get("max_hp", 0)), " • STOLEN" if bool(objective.get("totem_stolen", false)) else ""]
	return "RECOVER — %s\nHold %d / %d adjacent rounds" % [str(objective.get("status", "Reach the relic")), int(objective.get("hold_counter", 0)), int(objective.get("hold_required", 0))]


func _format_responses(responses: Array, actors: Array) -> String:
	if responses.is_empty():
		return "No response revealed yet. Only affected Echoes respond, immediately before their activation-round turn."
	var lines: PackedStringArray = []
	for response_v in responses:
		var response: Dictionary = response_v if response_v is Dictionary else {}
		var outcome := str(response.get("outcome", "align"))
		lines.append("[b]%s — %s · %s[/b]\nWhy: %s" % [
			_actor_name(str(response.get("actor_id", "")), actors),
			outcome.capitalize(),
			_response_behavior(outcome),
			str(response.get("explanation", response.get("primary_reason", "The guidance fits their judgment."))),
		])
	return "\n\n".join(lines)


func _format_timeline(events: Array, limit: int) -> String:
	var lines: PackedStringArray = []
	var start := maxi(0, events.size() - limit)
	for index in range(start, events.size()):
		var event: Dictionary = events[index] if events[index] is Dictionary else {}
		lines.append("[color=#9fb2a7]R%d · T%d[/color]  %s" % [int(event.get("round", 0)), int(event.get("t", event.get("tick", 0))), str(event.get("message", event.get("type", "Event"))).replace("_", " ")])
	return "\n".join(lines) if not lines.is_empty() else "Battle events will appear here."


func _build_report(data: Dictionary) -> String:
	var metrics: Dictionary = data.get("metrics", {})
	var timeline: Array = data.get("timeline", [])
	return "[b]Preparation[/b]\nDirective: %s\nDeployment: %s\n\n[b]Interventions[/b]\nPings confirmed: %d • Responses: %d\nHazard damage: %d • Forced movement: %d\n\n[b]Event timeline[/b]\n%s" % [DIRECTIVE_LABELS.get(str(data.get("directive_id", "")), "—"), _deployment_summary(data.get("deployment_assignments", {}), data.get("actors", [])), int(metrics.get("pings_confirmed", metrics.get("ping_count", 0))), _response_count(metrics.get("responses", metrics.get("response_count", 0))), int(metrics.get("hazard_damage", 0)), int(metrics.get("hazard_forced_moves", 0)), _format_timeline(timeline, timeline.size())]


func _response_count(value: Variant) -> int:
	if value is Dictionary:
		var total: int = 0
		for count_v in (value as Dictionary).values():
			total += int(count_v)
		return total
	return int(value)


func _echoes(actors: Array) -> Array:
	var result: Array = []
	for actor_v in actors:
		if actor_v is Dictionary and str((actor_v as Dictionary).get("faction", "")) == "echo":
			result.append(actor_v)
	return result


func _actor_name(actor_id: String, actors: Array) -> String:
	for actor_v in actors:
		if actor_v is Dictionary and str((actor_v as Dictionary).get("id", "")) == actor_id:
			return str((actor_v as Dictionary).get("name", "Echo"))
	return actor_id if not actor_id.is_empty() else "—"


func _recipient_names(ids: Array, actors: Array) -> String:
	if ids.is_empty():
		return "none"
	var names: PackedStringArray = []
	for actor_id_v in ids:
		names.append(_actor_name(str(actor_id_v), actors))
	return ", ".join(names)


func _format_subject(subject: Dictionary) -> String:
	if subject.is_empty():
		return "select on board"
	var subject_type := str(subject.get("kind", subject.get("type", "subject"))).replace("_", " ").capitalize()
	for pos_key in ["position", "anchor", "rally", "start", "pos"]:
		if not subject.has(pos_key):
			continue
		var pos: Dictionary = subject.get(pos_key, {})
		return "%s at %d,%d" % [subject_type, int(pos.get("col", 0)), int(pos.get("row", 0))]
	return subject_type


func _deployment_summary(assignments: Dictionary, actors: Array) -> String:
	var parts: PackedStringArray = []
	for actor_id_v in assignments.keys():
		parts.append("%s → slot %d" % [_actor_name(str(actor_id_v), actors), int(assignments[actor_id_v]) + 1])
	return ", ".join(parts) if not parts.is_empty() else "default formation"


func _directive_intent(directive_id: String) -> String:
	match directive_id:
		"scout_carefully": return "Preserve the party, avoid overcommitment, retain what is learned."
		"seek_signs": return "Press into uncertainty and accept contact to surface hidden meaning."
		"press_the_path": return "Advance the objective and engage only threats that block progress."
		"hold_the_circle": return "Maintain cohesion, intercept threats, and protect what is in your care."
		_: return "Choose the party's broad intent for this battle."


func _calling_label(calling: String) -> String:
	return calling.replace("_", " ").capitalize() if not calling.is_empty() else "Calling undecided"


func _threshold_state(current: int, required: int) -> String:
	return "READY" if current >= required else "%d rounds" % (required - current)


func _deployment_slot_index(pos: Dictionary) -> int:
	var slots: Array = _data.get("board", {}).get("deployment_slots", [])
	for index in slots.size():
		if slots[index] is Dictionary and (slots[index] as Dictionary) == pos:
			return index
	return -1


func _preparation_prediction(actor: Dictionary) -> String:
	var mode := str(_data.get("mode", "recover"))
	var tendency := str(actor.get("tendency", "act according to their Calling")).trim_suffix(".")
	var pressure := "objective approach" if mode == "recover" else "guarding and custody pressure"
	var risk := "steady under pressure"
	if int(actor.get("fear", 0)) >= 60:
		risk = "high fear may slow exposed movement"
	elif int(actor.get("morale", 100)) <= 35:
		risk = "low morale may favor safety"
	return "%s; likely to weigh %s; %s under %s." % [tendency, _directive_intent(_selected_directive).to_lower(), risk, pressure]


func _ping_availability_label(ping_id: String, current: int, unresolved: Dictionary) -> String:
	if not unresolved.is_empty():
		return "PENDING"
	var required := int(PING_COSTS.get(ping_id, 0))
	return "READY" if current >= required else "LOCKED · %d rounds" % (required - current)


func _preview_availability_fallback(preview: Dictionary) -> String:
	if bool(preview.get("valid", false)):
		return "available"
	if int(_data.get("ping_charge", {}).get("current", 0)) < int(preview.get("charge_required", 0)):
		return "insufficient_charge"
	return "invalid_subject"


func _availability_copy(state: String, preview: Dictionary) -> String:
	match state:
		"available": return "READY — can commit at the next actor boundary"
		"insufficient_charge": return "LOCKED — needs %d more completed round(s)" % maxi(0, int(preview.get("rounds_until_charge", 0)))
		"blocked_unresolved": return "PENDING — earlier guidance must resolve first"
		"no_eligible_recipients": return "NO RECIPIENTS — the shown area contains no eligible Echo"
		"invalid_subject": return "CHOOSE TARGET — the current subject or footprint is invalid"
		_: return state.replace("_", " ").to_upper()


func _response_behavior(outcome: String) -> String:
	match outcome:
		"align": return "will follow fully"
		"interpret": return "will follow in their own way"
		"hesitate": return "will follow partly after weighing danger"
		"object": return "will resist for another priority"
		"refuse": return "will reject and act autonomously"
		_: return "response unknown"


func _board_instruction() -> String:
	match _phase:
		"briefing": return "Read the board • use Routes/Chokepoints to inspect tactical structure • drag to pan • wheel to zoom"
		"preparation": return "Select one Echo in the roster, then choose one cyan deployment slot • Echo tokens are display-only"
		"combat":
			if _selected_ping_id.is_empty():
				return "Combat is automatic • choose a ping to reveal its legal target and full area"
			return "%s targeting — %s" % [PING_LABELS.get(_selected_ping_id, "Ping"), PING_INSTRUCTIONS.get(_selected_ping_id, "Select on the board")]
		_: return "Drag to pan • wheel to zoom • recenter at any time"


func _pass_fail(value: bool) -> String:
	return "pass" if value else "fail"
