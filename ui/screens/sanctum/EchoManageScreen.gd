# res://ui/screens/sanctum/EchoManageScreen.gd
# PROG-003: Echo Manage screen — list + detail panel.
# PROG-004: Rank-up overlay (RankUpOverlay), dominant_vector label,
#           CallingEligibleBadge, AscendButton, ▲ row indicator.
# PROG-007: Calling selection (CallingPanel via RankUpOverlay), ⚡ pending indicator,
#           deferred access from detail panel, sanctum.calling.confirm dispatch.
#
# Layout: persistent echo list (left) + detail panel (right, shown on row tap).
# Follows ScreenTemplate contract: set_snapshot() → _clear() → _render().
# Never reads FlowContext or sim internals directly.
# Per-echo row taps are handled client-side (no dispatch). Party assignment dispatches
# sanctum.party.toggle via action_requested signal.

extends Control

signal action_requested(action: Dictionary)

# ── Overlay preload (PROG-004) ─────────────────────────────────────────────
const _RANK_UP_OVERLAY_SCENE: PackedScene = preload("res://ui/overlays/RankUpOverlay.tscn")

# ── Static node refs ──────────────────────────────────────────────────────
@onready var echo_count_label: Label       = %EchoCountLabel
@onready var echo_row_list: VBoxContainer  = %EchoRowList
@onready var summon_btn: Button            = %SummonBtn
@onready var view_bonds_btn: Button        = %ViewBondsBtn
@onready var detail_panel: Control         = %DetailPanel

# Detail panel nodes
@onready var detail_name_label: Label      = %DetailName
@onready var detail_shout_label: Label     = %DetailShout
@onready var detail_hp_bar: ProgressBar    = %DetailHPBar
@onready var detail_hp_label: Label        = %DetailHPLabel
@onready var detail_calling_label: Label   = %DetailCalling
@onready var detail_rank_label: Label      = %DetailRank
@onready var detail_grade_label: Label     = %DetailGrade
@onready var detail_level_label: Label     = %DetailLevel
@onready var detail_xp_bar: ProgressBar    = %DetailXPBar
@onready var detail_xp_label: Label        = %DetailXPLabel
@onready var detail_archetype_label: Label = %DetailArchetype
@onready var detail_stats_grid: GridContainer = %DetailStatsGrid
@onready var detail_emotion_status: Label  = %DetailEmotionStatus
@onready var detail_morale_bar: ProgressBar = %DetailMoraleBar
@onready var detail_fear_bar: ProgressBar   = %DetailFearBar
@onready var detail_assign_party_btn: Button = %AssignPartyBtn
@onready var detail_assign_job_btn: Button   = %AssignJobBtn
@onready var back_btn: Button                = %BackButton

# PROG-004 detail panel nodes (defined in EchoManageScreen.tscn)
@onready var dominant_vector_label: Label    = %DominantVectorLabel
@onready var calling_eligible_badge: Button  = %CallingEligibleBadge
@onready var ascend_button: Button           = %AscendButton

# ── State ─────────────────────────────────────────────────────────────────
var _snap: Dictionary          = {}
var _action_back: Dictionary   = {}
var _echoes: Array             = []
var _selected_echo: Dictionary = {}
var _rank_up_overlay: RankUpOverlay = null
# SANCTUM-005: programmatic description label inserted after detail_calling_label.
var _calling_desc_label: Label = null

# ── Lifecycle ─────────────────────────────────────────────────────────────

func _ready() -> void:
	detail_panel.visible = false

	if not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)

	if not summon_btn.pressed.is_connected(_on_summon_pressed):
		summon_btn.pressed.connect(_on_summon_pressed)

	# View bonds is a stub — disabled until BONDS story.
	view_bonds_btn.disabled = true

	if not detail_assign_party_btn.pressed.is_connected(_on_assign_party_pressed):
		detail_assign_party_btn.pressed.connect(_on_assign_party_pressed)

	# Assign job is a stub — disabled until Sanctum jobs story.
	detail_assign_job_btn.disabled = true

	# PROG-004: Ascend button — connected once; echo is read from _selected_echo at press time.
	if not ascend_button.pressed.is_connected(_on_ascend_pressed):
		ascend_button.pressed.connect(_on_ascend_pressed)

	# PROG-007: Path Awaits button — deferred calling access.
	if not calling_eligible_badge.pressed.is_connected(_on_path_awaits_pressed):
		calling_eligible_badge.pressed.connect(_on_path_awaits_pressed)

	# SANCTUM-005: Description label for confirmed calling — inserted after detail_calling_label.
	_calling_desc_label = Label.new()
	_calling_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_calling_desc_label.visible = false
	var _cl_parent := detail_calling_label.get_parent()
	_cl_parent.add_child(_calling_desc_label)
	_cl_parent.move_child(_calling_desc_label, detail_calling_label.get_index() + 1)

	# PROG-004: Rank-up overlay — instantiated once, lives as a child of this screen.
	_rank_up_overlay = _RANK_UP_OVERLAY_SCENE.instantiate() as RankUpOverlay
	add_child(_rank_up_overlay)
	_rank_up_overlay.confirm_requested.connect(_on_rank_up_confirm_requested)
	_rank_up_overlay.dismissed.connect(_on_rank_up_dismissed)
	# PROG-007: Calling confirmation signal.
	_rank_up_overlay.calling_confirm_requested.connect(_on_calling_confirm_requested)


# ── Snapshot contract ─────────────────────────────────────────────────────

func set_snapshot(snap: Dictionary) -> void:
	_snap = snap
	var data: Dictionary    = snap.get("data", {}) if snap.get("data") is Dictionary else {}
	var actions: Dictionary = snap.get("actions", {}) if snap.get("actions") is Dictionary else {}

	var back_v: Variant = actions.get("nav.back", {})
	_action_back = back_v if back_v is Dictionary else {}

	_echoes = data.get("echoes", []) if data.get("echoes") is Array else []
	var count: int = int(data.get("echo_count", _echoes.size()))
	echo_count_label.text = "%d Echoes in sanctum" % count

	_rebuild_echo_list()

	# If a selected echo is already set, refresh its detail panel in case XP/level changed.
	if not _selected_echo.is_empty():
		var sel_id: String = str(_selected_echo.get("id", ""))
		for e_v in _echoes:
			if e_v is Dictionary and str(e_v.get("id", "")) == sel_id:
				_selected_echo = e_v
				break
		_render_detail(_selected_echo)

	# PROG-004: If a rank_up_event arrived, advance the overlay to the reveal panel.
	var rank_up_event_v: Variant = data.get("rank_up_event", null)
	if rank_up_event_v is Dictionary and not (rank_up_event_v as Dictionary).is_empty():
		if _rank_up_overlay != null:
			_rank_up_overlay.show_reveal(rank_up_event_v as Dictionary)

	# PROG-007: calling_event is attached after confirm — snapshot already rebuilt; no extra action needed.


# ── List builder ──────────────────────────────────────────────────────────

func _rebuild_echo_list() -> void:
	for c in echo_row_list.get_children():
		c.queue_free()

	for e_v in _echoes:
		if not (e_v is Dictionary):
			continue
		echo_row_list.add_child(_make_echo_row(e_v))


func _make_echo_row(e: Dictionary) -> Control:
	var echo_id        := str(e.get("id", ""))
	var name_str       := str(e.get("name", ""))
	var level          := int(e.get("level", 1))
	var rank           := int(e.get("rank", 1))
	var in_party       := bool(e.get("in_party", false))
	var rank_up_eligible  := bool(e.get("rank_up_eligible", false))
	# PROG-007: calling pending indicator
	var calling_options_v: Variant = e.get("calling_options", [])
	var calling_pending: bool = (calling_options_v is Array) and (calling_options_v as Array).size() > 0

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size   = Vector2(0, 48)

	var name_lbl := Label.new()
	name_lbl.text = name_str
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	# SANCTUM-005: archetype label (secondary identity, after name).
	var archetype_str := str(e.get("archetype", "")).capitalize()
	if not archetype_str.is_empty():
		var arch_lbl := Label.new()
		arch_lbl.text = archetype_str
		row.add_child(arch_lbl)

	# SANCTUM-005: replace calling_origin display with three-tier calling logic.
	var confirmed_calling: String = str(e.get("calling", ""))
	var calling_eligible: bool    = bool(e.get("calling_eligible", false))
	var calling_display: String   = ""
	if not confirmed_calling.is_empty():
		calling_display = confirmed_calling.capitalize()
	elif calling_eligible:
		calling_display = "Calling Undecided"
	if not calling_display.is_empty():
		var calling_lbl := Label.new()
		calling_lbl.text = calling_display
		row.add_child(calling_lbl)

	var level_lbl := Label.new()
	level_lbl.text = "Lv %d" % level
	row.add_child(level_lbl)

	var rank_lbl := Label.new()
	rank_lbl.text = "R%d" % rank
	row.add_child(rank_lbl)

	if in_party:
		var party_badge := Label.new()
		party_badge.text = "★"
		row.add_child(party_badge)

	# PROG-004: show ascend indicator when rank-up is available.
	if rank_up_eligible:
		var ascend_badge := Label.new()
		ascend_badge.text = "▲"
		row.add_child(ascend_badge)

	# PROG-007: show ⚡ when a calling choice is pending.
	if calling_pending:
		var calling_badge := Label.new()
		calling_badge.text = "⚡"
		row.add_child(calling_badge)

	var arrow_btn := Button.new()
	arrow_btn.text = "▶"
	arrow_btn.custom_minimum_size = Vector2(40, 48)
	arrow_btn.theme_type_variation = "ButtonGhost"
	# Capture echo dict by value for the closure.
	var e_capture: Dictionary = e.duplicate()
	arrow_btn.pressed.connect(func() -> void:
		_selected_echo = e_capture
		_render_detail(e_capture)
		detail_panel.visible = true
	)
	row.add_child(arrow_btn)

	return row


# ── Detail panel renderer ─────────────────────────────────────────────────

func _render_detail(e: Dictionary) -> void:
	var name_str   := str(e.get("name", ""))
	var rank       := int(e.get("rank", 1))
	var rarity     := str(e.get("rarity", "uncalled"))
	var level      := int(e.get("level", 1))
	var xp_total   := int(e.get("xp_total", 0))
	var xp_to_next := int(e.get("xp_to_next", 0))
	var archetype  := str(e.get("archetype", ""))
	var hp_max     := int(e.get("hp_max", 0))
	var morale     := int(e.get("morale", 50))
	var fear       := int(e.get("fear", 0))
	var status     := str(e.get("morale_status", "Normal"))
	var in_party   := bool(e.get("in_party", false))
	var shout      := str(e.get("current_shout", ""))
	var stats_v: Variant = e.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}

	detail_name_label.text  = name_str
	detail_shout_label.text = shout
	detail_shout_label.visible = not shout.is_empty()

	# HP bar (always full outside combat in MVP)
	detail_hp_bar.max_value = maxi(1, hp_max)
	detail_hp_bar.value     = hp_max
	detail_hp_label.text    = "HP %d/%d" % [hp_max, hp_max]

	detail_rank_label.text    = "Rank %d" % rank
	detail_grade_label.text   = rarity.capitalize()
	detail_level_label.text   = "Level %d" % level

	# PROG-004: dominant vector, calling eligible badge, ascend button.
	var dominant_vector: String  = str(e.get("dominant_vector", ""))
	var calling_eligible: bool   = bool(e.get("calling_eligible", false))
	var rank_up_eligible: bool   = bool(e.get("rank_up_eligible", false))

	dominant_vector_label.visible = not dominant_vector.is_empty()
	if not dominant_vector.is_empty():
		dominant_vector_label.text = _vector_label(dominant_vector)

	# SANCTUM-005: three-tier calling display.
	var confirmed_calling: String   = str(e.get("calling", ""))
	var calling_description: String = str(e.get("calling_description", ""))

	if not confirmed_calling.is_empty():
		# Tier 1: confirmed calling — show name + one-line description.
		detail_calling_label.visible   = true
		detail_calling_label.text      = confirmed_calling.capitalize()
		_calling_desc_label.text       = calling_description
		_calling_desc_label.visible    = not calling_description.is_empty()
		calling_eligible_badge.visible = false
	elif calling_eligible:
		# Tier 2: eligible but undecided — "Calling Undecided" + ⚡ Path Awaits badge.
		detail_calling_label.visible   = true
		detail_calling_label.text      = "Calling Undecided"
		_calling_desc_label.visible    = false
		calling_eligible_badge.visible = true
		calling_eligible_badge.text    = "⚡ Path Awaits"
	else:
		# Tier 3: not yet eligible — hide calling section entirely.
		detail_calling_label.visible   = false
		_calling_desc_label.visible    = false
		calling_eligible_badge.visible = false

	ascend_button.visible = rank_up_eligible
	if rank_up_eligible:
		ascend_button.text = "▲ Ascend to Rank %d" % (rank + 1)

	# XP bar: progress toward next level threshold (pre-computed by FlowEchoManageState)
	var xp_in_level: int  = int(e.get("xp_in_level", 0))
	var xp_per_level: int = int(e.get("xp_per_level", 100))
	if xp_to_next > 0:
		detail_xp_bar.max_value = maxi(1, xp_per_level)
		detail_xp_bar.value     = xp_in_level
		detail_xp_label.text    = "XP %d/%d" % [xp_in_level, xp_per_level]
	else:
		# At max level for this rank
		detail_xp_bar.max_value = 1
		detail_xp_bar.value     = 1
		detail_xp_label.text    = "XP MAX"

	detail_archetype_label.text = archetype.capitalize()

	# Stats grid (2-column: label + value)
	for c in detail_stats_grid.get_children():
		c.queue_free()
	var stat_rows: Array = [
		["Attack",       stats.get("atk",   0)],
		["Defense",      stats.get("def",   0)],
		["Intelligence", stats.get("int",   0)],
		["Agility",      stats.get("agi",   0)],
		["Charisma",     stats.get("cha",   0)],
		["Speed",        stats.get("speed", 0)],
	]
	for row_v in stat_rows:
		var key_lbl := Label.new()
		key_lbl.text = str(row_v[0])
		var val_lbl := Label.new()
		val_lbl.text = str(int(row_v[1]))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		detail_stats_grid.add_child(key_lbl)
		detail_stats_grid.add_child(val_lbl)

	# Emotion section
	detail_emotion_status.text = status
	detail_morale_bar.max_value = 100
	detail_morale_bar.value     = morale
	detail_fear_bar.max_value   = 100
	detail_fear_bar.value       = fear

	# Party CTA label
	detail_assign_party_btn.text = "Remove from party" if in_party else "Assign to party"


# ── Button handlers ───────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	if not _action_back.is_empty():
		action_requested.emit(_action_back)


func _on_summon_pressed() -> void:
	action_requested.emit({
		"type": "flow.go_state",
		"to":   "flow.summon",
	})


func _on_assign_party_pressed() -> void:
	if _selected_echo.is_empty():
		return
	action_requested.emit({
		"type":    "sanctum.party.toggle",
		"payload": { "echo_id": str(_selected_echo.get("id", "")) },
	})


# ── PROG-004 handlers ─────────────────────────────────────────────────────

func _on_ascend_pressed() -> void:
	if _selected_echo.is_empty() or _rank_up_overlay == null:
		return
	_rank_up_overlay.show_confirm(_selected_echo)


func _on_rank_up_confirm_requested(echo_id: String) -> void:
	action_requested.emit({
		"type":    "sanctum.rank_up",
		"payload": { "echo_id": echo_id },
	})


func _on_rank_up_dismissed() -> void:
	pass  # Snapshot already refreshed via set_snapshot(); nothing extra needed.


# ── PROG-007 handlers ─────────────────────────────────────────────────────

## Called when the ⚡ Path Awaits badge/button is tapped in the detail panel.
## Opens the CallingPanel directly — no rank-up flow required.
func _on_path_awaits_pressed() -> void:
	if _selected_echo.is_empty() or _rank_up_overlay == null:
		return
	var options_v: Variant = _selected_echo.get("calling_options", [])
	var options: Array = options_v if options_v is Array else []
	if options.is_empty():
		return
	_rank_up_overlay.show_calling(str(_selected_echo.get("id", "")), options)


## Dispatches sanctum.calling.confirm when the Keeper picks a calling in the overlay.
func _on_calling_confirm_requested(echo_id: String, chosen_calling_id: String) -> void:
	action_requested.emit({
		"type":    "sanctum.calling.confirm",
		"payload": { "echo_id": echo_id, "chosen_calling_id": chosen_calling_id },
	})


# ── PROG-004 helpers ──────────────────────────────────────────────────────

## Returns a player-facing descriptive label for a dominant vector.
## Vectors are never shown numerically — descriptive only (GDD §5.4).
static func _vector_label(vector: String) -> String:
	match vector:
		"vanguard":  return "Vanguard spirit"
		"seeker":    return "Seeker's curiosity"
		"pillar":    return "Pillar's steadiness"
		"protector": return "Protector's shelter"
		_:           return ""
