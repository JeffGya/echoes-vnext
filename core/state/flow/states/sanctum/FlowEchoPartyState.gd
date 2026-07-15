class_name FlowEchoPartyState

extends State

func _init(id: String = FlowStateIds.ECHO_PARTY) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	var active_party_ids: Array = _read_active_party_ids(flow_ctx)
	flow_ctx.pending_party_ids = active_party_ids.duplicate()
	flow_ctx.last_snapshot = build_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	pass


static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	var max_level: int = 5
	var prog_cfg: Dictionary = {}
	var calling_cfg: Dictionary = {}
	var skill_defs: Dictionary = {}
	var bond_thresholds: Dictionary = {}
	if flow_ctx.config_service != null:
		var bal: Dictionary = flow_ctx.config_service.get_balance()
		var bd: Dictionary = bal.get("data", {})
		var prog_v: Variant = bd.get("progression", {})
		if prog_v is Dictionary:
			prog_cfg = prog_v as Dictionary
			max_level = int(prog_cfg.get("max_level_per_rank", 5))
		var calling_v: Variant = bd.get("calling", {})
		if calling_v is Dictionary:
			calling_cfg = calling_v as Dictionary
		var skills_v: Variant = bd.get("skills", {})
		if skills_v is Dictionary:
			var defs_v: Variant = (skills_v as Dictionary).get("definitions", {})
			if defs_v is Dictionary:
				skill_defs = defs_v as Dictionary
		var sanctum_cfg_v: Variant = bd.get("sanctum", {})
		if sanctum_cfg_v is Dictionary:
			var bt_v: Variant = (sanctum_cfg_v as Dictionary).get("bond_thresholds", {})
			if bt_v is Dictionary:
				bond_thresholds = bt_v as Dictionary

	var bonds: Array = []
	var party_encounters: Array = []
	var roster: Array = []
	var thread_count := 0
	var party_ids: Array = _read_active_party_ids(flow_ctx)
	if flow_ctx.save_data.has("sanctum") and flow_ctx.save_data["sanctum"] is Dictionary:
		var sanctum: Dictionary = flow_ctx.save_data["sanctum"]
		var roster_v: Variant = sanctum.get("roster", [])
		if roster_v is Array:
			roster = roster_v
		var threads_v: Variant = sanctum.get("threads", {})
		if threads_v is Dictionary:
			thread_count = (threads_v as Dictionary).size()
		var bonds_v: Variant = sanctum.get("bonds", [])
		bonds = bonds_v if bonds_v is Array else []
		var enc_v: Variant = sanctum.get("party_encounters", [])
		party_encounters = enc_v if enc_v is Array else []

	var echo_entries: Array = []
	for e_v in roster:
		if not (e_v is Dictionary):
			continue
		var e: Dictionary = e_v

		var xp_total: int = int(e.get("xp_total", 0))
		var level: int = int(e.get("level", 1))
		var fear: int = int(e.get("emotion", {}).get("fear_current", 0))
		var morale: int = int(e.get("emotion", {}).get("morale_current", 50))
		var max_hp: int = int(e.get("stats", {}).get("max_hp", 0))

		var eff_thresholds: Array = ProgressionService.get_effective_thresholds(int(e.get("rank", 1)), prog_cfg)
		var xp_to_next: int = ProgressionService.get_xp_to_next(xp_total, eff_thresholds, max_level)
		var level_idx: int = maxi(0, level - 1)
		var xp_in_level: int = xp_total - int(eff_thresholds[level_idx]) if level_idx < eff_thresholds.size() else 0
		var next_idx: int = mini(level, eff_thresholds.size() - 1)
		var xp_per_level: int = int(eff_thresholds[next_idx]) - int(eff_thresholds[level_idx]) if xp_to_next > 0 else 0

		var stats_v: Variant = e.get("stats", {})
		var stats: Dictionary = stats_v if stats_v is Dictionary else {}

		var rank_up_eligible: bool = ProgressionService.is_rank_up_eligible(e, prog_cfg)
		var calling_eligible: bool = bool(e.get("calling_eligible", false))
		var dominant_vector: String = str(e.get("dominant_vector", ""))

		var drift_preview: Dictionary = {}
		if rank_up_eligible and flow_ctx.campaign_seed != null:
			drift_preview = ProgressionService.compute_trait_drift_preview(e, flow_ctx.campaign_seed, prog_cfg)

		# BOND-001: build bond entries from party encounter history
		var bond_entries: Array = SocialGraphService.build_bond_entries_for_actor(
			str(e.get("id", "")),
			roster,
			bonds,
			party_encounters,
			bond_thresholds
		)

		echo_entries.append({
			"id":                    str(e.get("id", "")),
			"name":                  str(e.get("name", "")),
			"calling_origin":        str(e.get("calling_origin", "Uncalled")),
			"origin":                str(e.get("origin", "")),  # V2-STAGE-004 S15 prep: "recruited_ally" for companion tag
			"standing":              int(e.get("rank", 1)),
			"rarity":                str(e.get("rarity", "uncalled")),
			"step":                  level,
			"storyweight":           xp_total,
			"storyweight_to_next":   xp_to_next,
			"storyweight_in_step":   xp_in_level,
			"storyweight_per_step":  xp_per_level,
			"archetype":             str(e.get("archetype_birth", "")),
			"hp_max":                max_hp,
			"stats": {
				"atk":   int(stats.get("atk",   0)),
				"def":   int(stats.get("def",   0)),
				"agi":   int(stats.get("agi",   0)),
				"int":   int(stats.get("int",   0)),
				"cha":   int(stats.get("cha",   0)),
				"speed": int(stats.get("speed", 0)),
			},
			# V2-EMOTION-002: unified emotional status (replaces morale + fear + morale_status).
			"emotional_status":      EmotionService.get_emotional_status(morale, fear),
			"in_party":              str(e.get("id", "")) in party_ids,
			"current_shout":         "",
			"standing_up_eligible":  rank_up_eligible,
			"calling_eligible":      calling_eligible,
			"dominant_vector":       dominant_vector,
			"trait_drift_preview":   drift_preview,
			"calling_options":       _get_or_backfill_calling_options(e, calling_cfg),
			"calling":               str(e.get("calling", "")),
			"calling_description":   _get_calling_description(str(e.get("calling", "")), calling_cfg),
			"skill_slots":           _resolve_skill_slots(e, skill_defs),
			"bond_entries":          bond_entries,
		})

	var echo_count: int = echo_entries.size()
	return {
		"type": FlowStateIds.ECHO_PARTY,
		"data": {
			"title": "EchoParty",
			"echo_count": echo_count,
			"echoes": echo_entries,
			"max_party_size": _read_max_party_size(flow_ctx),
			"active_party_ids": party_ids,
			"party_count": party_ids.size(),
			"thread_count": thread_count,
		},
		"actions": {
			"nav.back": {
				"type": "flow.go_state",
				"to": FlowStateIds.SANCTUM,
				"label": "Back",
				"slot": "nav.back",
			},
		},
		"meta": { "t": t },
	}


static func _read_max_party_size(flow_ctx: FlowContext) -> int:
	var max_party_size := 5
	if flow_ctx.config_service == null:
		return max_party_size
	var balance: Dictionary = flow_ctx.config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_v: Variant = data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	return int(sanctum_cfg.get("party_max_size", max_party_size))


static func _read_active_party_ids(flow_ctx: FlowContext) -> Array:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	return party_ids_v if party_ids_v is Array else []


static func _get_or_backfill_calling_options(e: Dictionary, calling_cfg: Dictionary) -> Array:
	if not CallingService.is_calling_pending(e):
		return []
	var existing_v: Variant = e.get("calling_options", [])
	if existing_v is Array and not (existing_v as Array).is_empty():
		return existing_v as Array
	if calling_cfg.is_empty():
		return []
	var options: Array = CallingService.compute_all_options(e, calling_cfg)
	e["calling_options"] = options
	return options


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


static func _resolve_skill_slots(echo: Dictionary, skill_defs: Dictionary) -> Array:
	var calling := str(echo.get("calling", ""))
	if calling.is_empty() or calling == "uncalled":
		return []
	if skill_defs.is_empty():
		return []
	var result: Array = []
	for skill_id in skill_defs.keys():
		var defn: Dictionary = skill_defs[skill_id]
		if str(defn.get("calling_requirement", "")) == calling:
			result.append(str(defn.get("display_name", skill_id)))
	return result
