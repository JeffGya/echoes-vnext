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
# PROG-004: Adds rank_up_eligible, calling_eligible, dominant_vector, trait_drift_preview.
# ────────────────────────────────────────────────────────────────────────────

static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	# --- Read max_level, prog_cfg, and calling_cfg from balance.json ---
	var max_level: int        = 5
	var prog_cfg: Dictionary  = {}
	var calling_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var bal: Dictionary = flow_ctx.config_service.get_balance()
		var bd: Dictionary  = bal.get("data", {})
		var prog_v: Variant  = bd.get("progression", {})
		if prog_v is Dictionary:
			prog_cfg = prog_v as Dictionary
			max_level = int(prog_cfg.get("max_level_per_rank", 5))
		var calling_v: Variant = bd.get("calling", {})
		if calling_v is Dictionary:
			calling_cfg = calling_v as Dictionary

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

		# XP tuning: use rank-effective thresholds so rank 2+ echoes have harder per-level costs.
		var eff_thresholds: Array = ProgressionService.get_effective_thresholds(int(e.get("rank", 1)), prog_cfg)
		var xp_to_next: int = ProgressionService.get_xp_to_next(xp_total, eff_thresholds, max_level)
		var level_idx: int   = maxi(0, level - 1)
		var xp_in_level: int = xp_total - int(eff_thresholds[level_idx]) if level_idx < eff_thresholds.size() else 0
		var next_idx: int    = mini(level, eff_thresholds.size() - 1)
		var xp_per_level: int = int(eff_thresholds[next_idx]) - int(eff_thresholds[level_idx]) if xp_to_next > 0 else 0

		var stats_v: Variant  = e.get("stats", {})
		var stats: Dictionary = stats_v if stats_v is Dictionary else {}

		# PROG-004: rank-up eligibility, calling_eligible flag, dominant_vector.
		var rank_up_eligible: bool = ProgressionService.is_rank_up_eligible(e, prog_cfg)
		var calling_eligible: bool = bool(e.get("calling_eligible", false))
		var dominant_vector: String = str(e.get("dominant_vector", ""))

		# Drift preview: deterministic, pure — only computed when eligible.
		var drift_preview: Dictionary = {}
		if rank_up_eligible and flow_ctx.campaign_seed != null:
			drift_preview = ProgressionService.compute_trait_drift_preview(e, flow_ctx.campaign_seed, prog_cfg)

		echo_entries.append({
			"id":               str(e.get("id", "")),
			"name":             str(e.get("name", "")),
			"calling_origin":   str(e.get("calling_origin", "Uncalled")),
			"rank":             int(e.get("rank", 1)),
			"rarity":           str(e.get("rarity", "uncalled")),
			"level":            level,
			"xp_total":         xp_total,
			"xp_to_next":       xp_to_next,
			"xp_in_level":      xp_in_level,
			"xp_per_level":     xp_per_level,
			"archetype":        str(e.get("archetype_birth", "")),
			"hp_max":           max_hp,
			"stats": {
				"atk":   int(stats.get("atk",   0)),
				"def":   int(stats.get("def",   0)),
				"agi":   int(stats.get("agi",   0)),
				"int":   int(stats.get("int",   0)),
				"cha":   int(stats.get("cha",   0)),
				"speed": int(stats.get("speed", 0)),
			},
			"morale":           morale,
			"fear":             fear,
			"morale_status":    _derive_morale_status(fear),
			"in_party":         str(e.get("id", "")) in party_ids,
			"current_shout":    "",  # VOICE-001 stub — no event bus yet
			# PROG-004 fields:
			"rank_up_eligible": rank_up_eligible,
			"calling_eligible": calling_eligible,
			"dominant_vector":  dominant_vector,
			"trait_drift_preview": drift_preview,
			# PROG-007 fields:
			# Back-fill calling_options for echoes ranked up before PROG-007:
			# if pending but options were never written, compute and store them now.
			"calling_options":  _get_or_backfill_calling_options(e, calling_cfg),
			"calling":          str(e.get("calling", "")),
			# SANCTUM-005: one-line description for confirmed calling (detail panel only).
			"calling_description": _get_calling_description(str(e.get("calling", "")), calling_cfg),
			# PROG-008: active skill slots — Array of skill_id strings; [""] = 1 empty slot (MVP).
			"skill_slots": (e.get("skill_slots", [""]) as Array).duplicate(),
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


## Returns calling_options for the echo, backfilling if the echo was ranked up
## before PROG-007 (calling_eligible=true but calling_options never written).
## Writes options back to the echo dict so they persist on the next save.
static func _get_or_backfill_calling_options(e: Dictionary, calling_cfg: Dictionary) -> Array:
	if not CallingService.is_calling_pending(e):
		return []
	var existing_v: Variant = e.get("calling_options", [])
	if existing_v is Array and not (existing_v as Array).is_empty():
		return existing_v as Array
	# Missing or empty — compute and write back (will be saved on next save trigger).
	if calling_cfg.is_empty():
		return []
	var options: Array = CallingService.compute_all_options(e, calling_cfg)
	e["calling_options"] = options
	return options


## SANCTUM-005: Returns the one-line description for a confirmed calling from balance.json.
## Returns "" if calling_id is empty or not found in definitions.
static func _get_calling_description(calling_id: String, calling_cfg: Dictionary) -> String:
	if calling_id.is_empty() or calling_cfg.is_empty():
		return ""
	var defs_v: Variant = calling_cfg.get("definitions", {})
	if not (defs_v is Dictionary):
		return ""
	var defs: Dictionary = defs_v
	if not defs.has(calling_id):
		return ""
	return str(defs[calling_id].get("description", ""))


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
