class_name FlowStageMapState

extends State

func _init(id: String = FlowStateIds.STAGE_MAP) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	# PROG-009: seed pending_equipped_skills from each echo's current save state on enter.
	flow_ctx.pending_equipped_skills = _load_pending_from_save(flow_ctx)
	flow_ctx.last_snapshot = build_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	pass


# ────────────────────────────────────────────────────────────────────────────
# Static builder — called by enter() and by FlowRuntime skill.assign / skill.unassign
# ────────────────────────────────────────────────────────────────────────────

static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	# Load active realm model
	var model := RealmService.get_active(flow_ctx)

	# REALM-004: guard — no active realm (e.g. after realm completion, ctx.realm_id cleared).
	if model.is_empty():
		if flow_ctx.logger != null:
			flow_ctx.logger.warn(t, "stage_map.no_active_realm", "StageMapState entered with no active realm; redirecting", {})
		return {
			"type":    FlowStateIds.STAGE_MAP,
			"data":    { "error": "no_active_realm" },
			"actions": {
				"nav.back": {
					"type":  "flow.go_state",
					"to":    FlowStateIds.REALM_SELECT,
					"label": "Select Realm",
					"slot":  "nav.back",
				}
			},
			"meta": { "t": t },
		}

	# V2-WEAVE-001: Recovery segments for cord display
	var segs_v: Variant = model.get("realm_recovery_segments", [])
	var recovery_segments: Array = segs_v if segs_v is Array else []

	# --- Build stage list from RealmModel ---
	var raw_model_stages: Variant = model.get("stages", [])
	var model_stages: Array = raw_model_stages if raw_model_stages is Array else []
	var current_stage_index := int(model.get("current_stage_index", 0))
	var realm_name: String   = str(model.get("name", ""))
	var realm_complete: bool = bool(model.get("is_completed", false))
	var stage_count: int     = int(model.get("stage_count", model_stages.size()))

	var stages: Array = []
	for stage_v in model_stages:
		var stage: Dictionary = stage_v if stage_v is Dictionary else {}
		var idx    := int(stage.get("index", 0))
		var stype  := str(stage.get("type", "combat"))
		var stage_status: String
		if idx < current_stage_index:
			stage_status = "completed"
		elif idx == current_stage_index:
			stage_status = "current"
		else:
			stage_status = "locked"

		# Project objectives for display
		var raw_objs: Variant = stage.get("objectives", [])
		var objs: Array = raw_objs if raw_objs is Array else []
		var projected_objs: Array = []
		for obj_v in objs:
			var obj: Dictionary = obj_v if obj_v is Dictionary else {}
			projected_objs.append({
				"obj_index":       int(obj.get("index", 0)),
				"obj_type":        str(obj.get("type", "")),
				"obj_description": str(ObjectiveModel.TYPE_DESCRIPTIONS.get(obj.get("type", ""), "")),
			})

		stages.append({
			"id":                "stage.%d" % idx,
			"name":              "Stage %d — %s" % [idx + 1, stype.capitalize()],
			"status":            stage_status,
			"stage_type":        stype,
			"stage_description": str(StageModel.TYPE_DESCRIPTIONS.get(stype, "")),
			"objective_count":   objs.size(),
			"objectives":        projected_objs,
		})

	# Current stage entry (first with status "current")
	var current_stage: Dictionary = stages[0] if not stages.is_empty() else {}
	for s in stages:
		if s.get("status", "") == "current":
			current_stage = s
			break

	# Actions
	var actions: Dictionary = {
		"nav.back": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.SANCTUM,
			"label": "Back",
			"slot":  "nav.back",
		},
	}
	# REALM-004: only offer stage entry when realm is not yet complete
	if not realm_complete:
		actions["cta.enter_stage"] = {
			"type":     "flow.select_stage",
			"stage_id": str(current_stage.get("id", "stage.0")),
			"label":    "Enter " + str(current_stage.get("name", "Stage")),
			"slot":     "cta.enter_stage",
		}

	# Read skill definitions and family config from balance.json (needed for party_prep)
	var skill_defs: Dictionary  = {}
	var families_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var bal: Dictionary = flow_ctx.config_service.get_balance()
		var bd: Dictionary  = bal.get("data", {})
		var skills_v: Variant = bd.get("skills", {})
		if skills_v is Dictionary:
			var skills_block := skills_v as Dictionary
			var defs_v: Variant = skills_block.get("definitions", {})
			if defs_v is Dictionary:
				skill_defs = defs_v as Dictionary
			# V2-PROG-005: family config (families + calling_family_alignment)
			families_cfg = skills_block

	# Party data from save
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var active_ids_v: Variant = sanctum.get("active_party_ids", [])
	var active_ids: Array = active_ids_v if active_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var party_preview: Array = []
	var party_prep: Array    = []  # PROG-009: per-echo skill selection (called echoes only)
	var any_called := false

	for echo_id_v in active_ids:
		if party_preview.size() >= 5:
			break
		var echo_id := str(echo_id_v)
		for echo_v in roster:
			var echo: Dictionary = echo_v if echo_v is Dictionary else {}
			if str(echo.get("id", "")) != echo_id:
				continue

			var calling_origin := str(echo.get("calling_origin", ""))
			party_preview.append({
				"name":           str(echo.get("name", "")),
				"rank":           int(echo.get("rank", 1)),
				"calling_origin": calling_origin,
			})

			# PROG-009: party prep row — only for echoes with a confirmed calling.
			# `calling` is the confirmed calling id (e.g. "ranger"); `calling_origin` stays
			# "uncalled" at the save level until calling is confirmed, so use `calling` here.
			var calling := str(echo.get("calling", ""))
			if not calling.is_empty() and calling != "uncalled":
				any_called = true
				# V2-PROG-005: family-based filter — calling → aligned families → skills in those families
				# PROG-009 fix: filter further to only skills the Echo has actually unlocked
				var all_accessible: Array = filter_skills_for_calling(calling, skill_defs, families_cfg)
				var unlocked_ids_v: Variant = echo.get("unlocked_skills", [])
				var unlocked_ids: Array = unlocked_ids_v if unlocked_ids_v is Array else []
				var available_skills: Array = all_accessible.filter(
					func(s: Dictionary) -> bool: return unlocked_ids.has(str(s.get("skill_id", "")))
				)
				# Equipped: in-session pending only — no pre-selection from save.
				var pending_echo_v: Variant = flow_ctx.pending_equipped_skills.get(echo_id, {})
				var pending_echo: Dictionary = pending_echo_v if pending_echo_v is Dictionary else {}
				var equipped_skill_id := str(pending_echo.get("0", ""))

				# Resolve calling_families for this echo (for UI grouping)
				var calling_families: Dictionary = _resolve_calling_families(calling, families_cfg)

				party_prep.append({
					"echo_id":              echo_id,
					"echo_name":            str(echo.get("name", "")),
					"calling_id":           calling,
					"calling_families":     calling_families,
					"available_skills":     available_skills,
					"equipped_skill_id":    equipped_skill_id,
					"has_unlocked_skills":  not available_skills.is_empty(),
				})
			break

	var stages_completed_count := 0
	for s in stages:
		if s.get("status", "") == "completed":
			stages_completed_count += 1

	# REALM-004: stages_remaining = total stages not yet completed (excludes current)
	var stages_remaining: int = max(0, stage_count - stages_completed_count - 1)

	return {
		"type": FlowStateIds.STAGE_MAP,
		"data": {
			"title":                  "Stage Map",
			"realm_id":               flow_ctx.realm_id,
			"realm_name":             realm_name,
			"realm_virtue":           str(model.get("virtue", "")),  # V2-WEAVE-001: cord palette
			"current_stage_id":       str(current_stage.get("id", "")),
			"stages_completed_count": stages_completed_count,
			"stage_count":            stage_count,
			"stages_remaining":       stages_remaining,
			"realm_complete":         realm_complete,
			"stages":                 stages,
			"party_preview":          party_preview,
			"party_prep":             party_prep,
			"has_called_echoes":      any_called,
			"recovery_segments":      recovery_segments,  # V2-WEAVE-001: Array[{stage_index, quality_tier}]
		},
		"actions": actions,
		"meta": { "t": t },
	}


## V2-PROG-005: Filters skill definitions by family alignment.
## A calling can access all skills whose skill_family is in its aligned families (strong + light).
## calling_requirement is removed — access is determined by family alignment only.
## Returns Array of { skill_id, display_name, action_type, skill_family, family_alignment } dicts.
static func filter_skills_for_calling(calling_id: String, skill_defs: Dictionary, families_cfg: Dictionary) -> Array:
	if calling_id.is_empty() or skill_defs.is_empty():
		return []

	var calling_families := _resolve_calling_families(calling_id, families_cfg)
	var strong_v: Variant = calling_families.get("strong", [])
	var light_v:  Variant = calling_families.get("light",  [])
	var strong: Array = strong_v if strong_v is Array else []
	var light:  Array = light_v  if light_v  is Array else []
	var aligned: Array = strong + light

	var result: Array = []
	for skill_id in skill_defs.keys():
		var defn: Dictionary = skill_defs[skill_id]
		var family := str(defn.get("skill_family", ""))
		if family.is_empty() or not aligned.has(family):
			continue
		var alignment := "strong" if strong.has(family) else "light"
		result.append({
			"skill_id":         str(defn.get("skill_id",     skill_id)),
			"display_name":     str(defn.get("display_name", skill_id)),
			"action_type":      str(defn.get("action_type",  "")),
			"skill_family":     family,
			"family_alignment": alignment,
		})
	return result


## V2-PROG-005: Returns { strong: [], light: [] } for the given calling from families_cfg.
## families_cfg is the full data.skills block from balance.json.
## Returns empty arrays if the calling has no alignment entry (e.g. uncalled echoes).
static func _resolve_calling_families(calling_id: String, families_cfg: Dictionary) -> Dictionary:
	var empty := { "strong": [], "light": [] }
	if calling_id.is_empty() or families_cfg.is_empty():
		return empty
	var align_v: Variant = families_cfg.get("calling_family_alignment", {})
	if not (align_v is Dictionary):
		return empty
	var calling_v: Variant = (align_v as Dictionary).get(calling_id, {})
	if not (calling_v is Dictionary):
		return empty
	var entry := calling_v as Dictionary
	return {
		"strong": entry.get("strong", []),
		"light":  entry.get("light",  []),
	}


## PROG-009: Clears pending_equipped_skills on enter so the Keeper always makes a fresh
## choice. Skills from the previous run are not pre-selected.
static func _load_pending_from_save(_flow_ctx: FlowContext) -> Dictionary:
	return {}
