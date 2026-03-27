class_name FlowEchoManageState

extends State

func _init(id: String = FlowStateIds.ECHO_MANAGE) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	flow_ctx.last_snapshot = build_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	pass


# ────────────────────────────────────────────────────────────────────────────
# PROG-003: Static builder — follows FlowSummonState.build_snapshot() pattern.
# Reads roster from save_data; computes xp_to_next via ProgressionService.
# ────────────────────────────────────────────────────────────────────────────

static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	# --- Read level thresholds and max_level from balance.json ---
	var thresholds: Array = [0, 100, 250, 450, 700]
	var max_level: int    = 5
	if flow_ctx.config_service != null:
		var bal: Dictionary = flow_ctx.config_service.get_balance()
		var bd: Dictionary  = bal.get("data", {})
		var prog_v: Variant  = bd.get("progression", {})
		if prog_v is Dictionary:
			var t_v: Variant = (prog_v as Dictionary).get("level_thresholds", thresholds)
			if t_v is Array:
				thresholds = t_v
			max_level = int((prog_v as Dictionary).get("max_level_per_rank", 5))

	# --- Read roster and party ids from save_data ---
	var roster: Array    = []
	var party_ids: Array = []
	if flow_ctx.save_data.has("sanctum") and flow_ctx.save_data["sanctum"] is Dictionary:
		var sanc: Dictionary = flow_ctx.save_data["sanctum"]
		var r_v: Variant = sanc.get("roster", [])
		if r_v is Array:
			roster = r_v
		var p_v: Variant = sanc.get("active_party_ids", [])
		if p_v is Array:
			party_ids = p_v

	# --- Build per-echo snapshot data ---
	var echo_entries: Array = []
	for e_v in roster:
		if not (e_v is Dictionary):
			continue
		var e: Dictionary = e_v

		var xp_total: int  = int(e.get("xp_total", 0))
		var level: int     = int(e.get("level", 1))
		var fear: int      = int(e.get("emotion", {}).get("fear_current", 0))
		var morale: int    = int(e.get("emotion", {}).get("morale_current", 50))
		var max_hp: int    = int(e.get("stats", {}).get("max_hp", 0))

		var xp_to_next: int = ProgressionService.get_xp_to_next(xp_total, thresholds, max_level)

		var stats_v: Variant  = e.get("stats", {})
		var stats: Dictionary = stats_v if stats_v is Dictionary else {}

		echo_entries.append({
			"id":              str(e.get("id", "")),
			"name":            str(e.get("name", "")),
			"calling_origin":  str(e.get("calling_origin", "Uncalled")),
			"rank":            int(e.get("rank", 1)),
			"rarity":          str(e.get("rarity", "uncalled")),
			"level":           level,
			"xp_total":        xp_total,
			"xp_to_next":      xp_to_next,
			"archetype":       str(e.get("archetype_birth", "")),
			"hp_max":          max_hp,
			"stats": {
				"atk":   int(stats.get("atk",   0)),
				"def":   int(stats.get("def",   0)),
				"agi":   int(stats.get("agi",   0)),
				"int":   int(stats.get("int",   0)),
				"cha":   int(stats.get("cha",   0)),
				"speed": int(stats.get("speed", 0)),
			},
			"morale":          morale,
			"fear":            fear,
			"morale_status":   _derive_morale_status(fear),
			"in_party":        str(e.get("id", "")) in party_ids,
			"current_shout":   "",  # VOICE-001 stub — no event bus yet
		})

	var echo_count: int = echo_entries.size()

	return {
		"type": FlowStateIds.ECHO_MANAGE,
		"data": {
			"title":       "Echoes",
			"echo_count":  echo_count,
			"echoes":      echo_entries,
		},
		# Slot-keyed Dictionary — NOT an Array (lesson from legacy scaffold)
		"actions": {
			"nav.back": {
				"type":  "flow.go_state",
				"to":    FlowStateIds.SANCTUM,
				"label": "Back",
				"slot":  "nav.back",
			},
			# Per-echo row actions are dispatched by UI rows directly — NOT here.
		},
		"meta": { "t": t },
	}


## Derives a player-facing morale status label from fear level.
## Mirrors FlowEncounterState._derive_morale_status() — kept local to avoid cross-dep.
static func _derive_morale_status(fear: int) -> String:
	if fear >= 80:
		return "Broken"
	if fear >= 40:
		return "Afraid"
	if fear > 0:
		return "Shaken"
	return "Normal"
