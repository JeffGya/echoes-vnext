class_name FlowSanctumState

extends State

func _init(id: String = FlowStateIds.SANCTUM) -> void:
	super(id)
	
func enter(ctx: RefCounted, t:int) -> void:
	var flow_ctx := ctx as FlowContext
	var balance_data: Dictionary = {}
	var prog_cfg: Dictionary = {}
	var skills_cfg: Dictionary = {}
	var max_level: int = 5
	if flow_ctx.config_service != null:
		var balance_v: Variant = flow_ctx.config_service.get_balance()
		var balance: Dictionary = balance_v if balance_v is Dictionary else {}
		var balance_data_v: Variant = balance.get("data", {})
		balance_data = balance_data_v if balance_data_v is Dictionary else {}
		var progression_v: Variant = balance_data.get("progression", {})
		if progression_v is Dictionary:
			prog_cfg = progression_v as Dictionary
			max_level = int(prog_cfg.get("max_level_per_rank", 5))
		var skills_v: Variant = balance_data.get("skills", {})
		if skills_v is Dictionary:
			skills_cfg = skills_v as Dictionary

	# VOW-001: release active vow when returning to Sanctum if the release condition is met.
	# Condition logic is in VowService.release_vow_if_due (testable in isolation).
	VowService.release_vow_if_due(flow_ctx.save_data, flow_ctx, flow_ctx.logger, t)

	# REALM-001: check save_data["realms"] directly — survives Continue (realm_id restored in boot)
	var _realms_v: Variant = flow_ctx.save_data.get("realms", {})
	var _realms: Dictionary = _realms_v if _realms_v is Dictionary else {}
	var has_realm_locked_in := false
	for _rid in _realms:
		var _rm_v: Variant = _realms[_rid]
		var _rm: Dictionary = _rm_v if _rm_v is Dictionary else {}
		if _rm.get("status", "") == RealmModel.STATUS_ACTIVE:
			has_realm_locked_in = true
			break

	# Slot-keyed Dictionary — Feb 2026 standard. Each entry includes its own "slot" key.
	# cta.enter_stage is always present; "disabled" flag communicates availability to UI.
	var actions: Dictionary = {
		"nav.echo_party": {
			"type": "flow.go_state",
			"to": FlowStateIds.ECHO_PARTY,
			"label": "EchoParty",
			"slot": "nav.echo_party",
		},
		"nav.realm_select": {
			"type": "flow.go_state",
			"to": FlowStateIds.REALM_SELECT,
			"label": "Select Realm",
			"slot": "nav.realm_select",
		},
		"nav.summon": {
			"type": "flow.go_state",
			"to": FlowStateIds.SUMMON,
			"label": "Summon Echo",
			"slot": "nav.summon",
		},
		"cta.enter_stage": {
			"type": "flow.go_state",
			"to": FlowStateIds.STAGE_MAP,
			"label": "Enter Stage",
			"slot": "cta.enter_stage",
			"disabled": not has_realm_locked_in,
		},
		# VOW-001: navigate to vow doctrine screen
		"nav.vow_manage": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.VOW_MANAGE,
			"label": "Vows",
			"slot":  "nav.vow_manage",
		},
	}
		
	# --- Sanctum roster (from save) ---
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}

	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	var active_party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var active_party_ids: Array = active_party_ids_v if active_party_ids_v is Array else []
	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var party_encounters_v: Variant = sanctum.get("party_encounters", [])
	var party_encounters: Array = party_encounters_v if party_encounters_v is Array else []
	var bond_thresholds: Dictionary = {}
	if flow_ctx.config_service != null:
		var _bond_bal: Dictionary = flow_ctx.config_service.get_balance()
		var _bond_data_v: Variant = _bond_bal.get("data", {})
		var _bond_data: Dictionary = _bond_data_v if _bond_data_v is Dictionary else {}
		var _bond_sanctum_v: Variant = _bond_data.get("sanctum", {})
		var _bond_sanctum: Dictionary = _bond_sanctum_v if _bond_sanctum_v is Dictionary else {}
		var _bond_thresholds_v: Variant = _bond_sanctum.get("bond_thresholds", {})
		bond_thresholds = _bond_thresholds_v if _bond_thresholds_v is Dictionary else {}

	# V2-PROG-009: Read current Ase balance for can_afford calculation in skill entries.
	var _economy_v: Variant = flow_ctx.save_data.get("economy", {})
	var _economy: Dictionary = _economy_v if _economy_v is Dictionary else {}
	var _ase_balance := int(_economy.get("ase", 0))

	# Build a small preview list (first 3)
	var roster_preview: Array = []
	var echo_detail_roster: Array = _build_echo_detail_roster(
		roster,
		active_party_ids,
		bonds,
		party_encounters,
		bond_thresholds,
		skills_cfg,
		prog_cfg,
		max_level,
		_ase_balance,
		balance_data  # V2-PROG-010: cfg_data for rank_benefits + maturity expression fields
	)
	var limit : Variant = min(3, roster.size())
	for i in range(limit):
		var echo_v: Variant = roster[i]
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}

		var _emo := EmotionService.get_emotion(echo)
		var _last_drift_v: Variant = _emo.get("_last_drift", {})
		roster_preview.append({
			"id":              str(echo.get("id", "")),
			"name":            str(echo.get("name", "")),
			"calling_origin":  str(echo.get("calling_origin", "")),
			"rarity":          str(echo.get("rarity", "")),
			"standing":        int(echo.get("rank", 1)),
			"step":            int(echo.get("level", 1)),
			"archetype_birth": str(echo.get("archetype_birth", "")),
			# EMOTION-002: emotion snapshot (V2-EMOTION-002: morale_tier → emotional_status)
			"emotion": {
				"faith":             int(_emo.get("faith",          50)),
				"morale_current":    int(_emo.get("morale_current", 50)),
				"fear_current":      int(_emo.get("fear_current",   0)),
				"emotional_status":  EmotionService.get_emotional_status(
					int(_emo.get("morale_current", 50)),
					int(_emo.get("fear_current",   0))
				),
				"last_drift_event":  _last_drift_v if _last_drift_v is Dictionary else {},
			},
			# V2-VOICE-001: sanctum bark for this echo (written by FlowRuntime bark helpers).
			"sanctum_bark": echo.get("_sanctum_bark", {}),
		})

	# VOW-001: read active vow for mantra display
	var _av_display: Dictionary = {}
	if flow_ctx.config_service != null:
		var _av_raw := VowService.get_active_vow(flow_ctx.save_data)
		if not _av_raw.is_empty():
			var _av_cfg: Dictionary = flow_ctx.config_service.get_balance()
			var _av_id := str(_av_raw.get("vow_id", ""))
			var _av_defn := VowService.get_definition(_av_id, _av_cfg)
			var _av_tier := int(_av_raw.get("tier", 1))
			_av_display = {
				"vow_id":           _av_id,
				"proverb_twi":      str(_av_defn.get("proverb_twi", "")),
				"proverb_en":       str(_av_defn.get("proverb_en", "")),
				"tier":             _av_tier,
				# V2-VOW-002: compliance count for "N stages honored" label under proverb.
				"compliance_count": int(_av_raw.get("compliance_count", 0)),
			}

	# V2-WEAVE-001: Thread reserve for ThreadReserveRow display
	var _threads_src_v: Variant = sanctum.get("threads", {})
	var _threads_src: Dictionary = _threads_src_v if _threads_src_v is Dictionary else {}
	var _thread_reserve: Array = []
	for _tid in _threads_src:
		var _th_v: Variant = _threads_src[_tid]
		if _th_v is Dictionary:
			var _th: Dictionary = _th_v
			_thread_reserve.append({
				"virtue":       str(_th.get("virtue", "unknown")),
				"quality_tier": str(_th.get("quality_tier", "broken")),
			})
	# Read reserve cap from config if available, otherwise default 4
	var _thread_reserve_cap := 4
	if flow_ctx.config_service != null:
		var _bal_th_v: Variant = flow_ctx.config_service.get_balance()
		var _bal_th: Dictionary = _bal_th_v if _bal_th_v is Dictionary else {}
		var _bd_th_v: Variant = _bal_th.get("data", {})
		var _bd_th: Dictionary = _bd_th_v if _bd_th_v is Dictionary else {}
		var _th_cfg_v: Variant = _bd_th.get("threads", {})
		var _th_cfg: Dictionary = _th_cfg_v if _th_cfg_v is Dictionary else {}
		_thread_reserve_cap = int(_th_cfg.get("base_reserve_cap", 4))

	# V2-WEAVE-002: Weaving Rite nav — enabled only when threads are available
	actions["nav.weaving_rite"] = {
		"type":     "weave.enter_rite",
		"label":    "Weaving",
		"slot":     "nav.weaving_rite",
		"disabled": _thread_reserve.is_empty(),
	}

	# V2-SANCTUM-002: institution config + ground data
	var _inst_cfg_s: Dictionary = {}

	var _econ_s: Dictionary = (flow_ctx.save_data.get("economy", {}) as Dictionary)
	var _ekwan_balance_s := int(_econ_s.get("ekwan", 0))
	if flow_ctx.config_service != null:
		var _bal_s: Dictionary = flow_ctx.config_service.get_balance()
		var _bd_s: Dictionary = _bal_s.get("data", {}) as Dictionary
		var _ic_v: Variant = _bd_s.get("institutions", {})
		_inst_cfg_s = _ic_v if _ic_v is Dictionary else {}
	var _inst_snapshot := InstitutionService.get_snapshot_data(flow_ctx.save_data, _inst_cfg_s, t)
	# Compatibility hints for all roster echoes (keyed inst_id -> echo_id -> hint string)
	var _compat_hints: Dictionary = {}
	for _inst_entry in _inst_snapshot:
		if not (_inst_entry is Dictionary):
			continue
		var _iid := str((_inst_entry as Dictionary).get("id", ""))
		if _iid.is_empty():
			continue
		var _hints_cfg_v: Variant = _inst_cfg_s.get("compatibility_hints", {})
		var _hints_cfg: Dictionary = _hints_cfg_v if _hints_cfg_v is Dictionary else {}
		var _echo_hints: Dictionary = {}
		for _e_v in roster:
			if not (_e_v is Dictionary):
				continue
			var _e: Dictionary = _e_v
			var _eid := str(_e.get("id", ""))
			var _ename := str(_e.get("name", ""))
			if _eid.is_empty():
				continue
			var _tier := InstitutionService.compute_compatibility(_e, _iid, _inst_cfg_s)
			_echo_hints[_eid] = InstitutionService.get_compatibility_hint(_ename, _iid, _tier, _hints_cfg)
		_compat_hints[_iid] = _echo_hints
	# Establish CTA slots for institution candidates
	for _inst_e in _inst_snapshot:
		if not (_inst_e is Dictionary):
			continue
		var _inst_e_dict: Dictionary = _inst_e
		if bool(_inst_e_dict.get("is_candidate", false)):
			var _eid2 := str(_inst_e_dict.get("id", ""))
			var _slot_key := "cta.establish." + _eid2
			var _ecost := int((_inst_cfg_s.get(_eid2, {}) as Dictionary).get("establish_ekwan_cost", 10))
			actions[_slot_key] = {
				"type":    "sanctum.institution.establish",
				"slot":    _slot_key,
				"label":   "Establish " + _eid2.replace("_", " ").capitalize(),
				"payload": { "institution_id": _eid2, "establish_ekwan_cost": _ecost },
				"disabled": _ekwan_balance_s < _ecost,
			}

	# Placement context — floor and occupied cell arrays for SanctumShell validity checks.
	# Derived from ensure_layout() so SanctumShell never needs save_data directly.
	var _pl_layout := SanctumLayoutService.ensure_layout(flow_ctx.save_data, _inst_snapshot)
	var _pl_tiles: Array = _pl_layout.get("tiles", [])
	var _pl_floor: Array = []
	var _pl_occupied: Array = []
	for _pl_tile_v in _pl_tiles:
		if not (_pl_tile_v is Dictionary):
			continue
		var _pl_tile: Dictionary = _pl_tile_v
		var _pl_kind := str(_pl_tile.get("kind", ""))
		var _pl_cell := Vector2i(int(_pl_tile.get("x", 0)), int(_pl_tile.get("y", 0)))
		if _pl_kind == "floor":
			_pl_floor.append(_pl_cell)
		else:
			_pl_occupied.append(_pl_cell)

	# V2-CONTINUITY-001: Continuity band + points for TitleRow flame indicator.
	var _cont_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var _b: Dictionary = flow_ctx.config_service.get_balance()
		var _bd := _b.get("data", {}) as Dictionary
		var _cv: Variant = _bd.get("continuity", {})
		_cont_cfg = _cv if _cv is Dictionary else {}
	var _cont_pts  := ContinuityService.get_points(flow_ctx.save_data)
	var _cont_band := ContinuityService.get_band(_cont_pts, _cont_cfg)

	# Base Sanctum snapshot. FlowStateMachine._rebuild_snapshot() enriches data with:
	# - ase_balance, ekwan_balance (Economy)
	# - roster_count, active_party_count (Sanctum)
	var data := {
		"title": "Sanctum",
		"first_boot": flow_ctx.save_data.get("first_boot", true),
		"realm_id": flow_ctx.realm_id,
		"stage_id": flow_ctx.stage_id,
		"encounter_id": flow_ctx.encounter_id,
		"roster_count": roster.size(),
		"roster_preview": roster_preview,
		"active_vow":    _av_display,   # VOW-001: mantra data for SanctumScreen header
		# V2-VOW-002: generic active-effects array for ActiveEffectsPanel (chips + popout).
		"active_effects": _build_active_effects(flow_ctx),
		"thread_reserve":     _thread_reserve,      # V2-WEAVE-001: Array[{virtue, quality_tier}]
		"thread_reserve_cap": _thread_reserve_cap,  # V2-WEAVE-001: base reserve cap (default 4)
		"sanctum_layout": SanctumLayoutService.snapshot_layout(flow_ctx.save_data, _inst_snapshot),
		"sanctum_occupants": SanctumLayoutService.snapshot_occupants(flow_ctx.save_data, roster, active_party_ids, _inst_snapshot),
		"echo_detail_roster": echo_detail_roster,
		"featured_echo_id": str((echo_detail_roster[0] as Dictionary).get("id", "")) if not echo_detail_roster.is_empty() and echo_detail_roster[0] is Dictionary else "",
		# V2-CONTINUITY-001
		"continuity_points": _cont_pts,
		"continuity_band":   _cont_band,
		# V2-SANCTUM-002
		"institutions":              _inst_snapshot,
		"valid_placement_cells":     SanctumLayoutService.compute_valid_placement_cells(flow_ctx.save_data, _inst_snapshot),
		"placement_floor_cells":     _pl_floor,    # Array[Vector2i] — all floor tiles; for SanctumShell placement checks
		"placement_occupied_cells":  _pl_occupied, # Array[Vector2i] — all non-floor tiles (ase_flame, institutions)
		"institution_compat_hints":  _compat_hints,
	}

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.SANCTUM,
		"data": data,
		"actions": actions,
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass


static func _build_echo_detail_roster(
	roster: Array,
	active_party_ids: Array,
	bonds: Array,
	party_encounters: Array,
	bond_thresholds: Dictionary,
	skills_cfg: Dictionary,
	prog_cfg: Dictionary,
	max_level: int,
	ase_balance: int = 0,
	cfg_data: Dictionary = {}  # V2-PROG-010: full balance data for rank_benefits + maturity fields
) -> Array:
	var out: Array = []
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var emotion_v: Variant = echo.get("emotion", {})
		var emotion: Dictionary = emotion_v if emotion_v is Dictionary else {}
		var stats_v: Variant = echo.get("stats", {})
		var stats: Dictionary = stats_v if stats_v is Dictionary else {}
		var rank := int(echo.get("rank", 1))
		var step := int(echo.get("level", 1))
		var storyweight := int(echo.get("xp_total", 0))
		var thresholds: Array = ProgressionService.get_effective_thresholds(rank, prog_cfg)
		var storyweight_to_next := ProgressionService.get_xp_to_next(storyweight, thresholds, max_level)
		var level_idx := maxi(0, step - 1)
		var next_idx := mini(step, thresholds.size() - 1)
		var storyweight_in_step := storyweight - int(thresholds[level_idx]) if level_idx < thresholds.size() else 0
		var storyweight_per_step := int(thresholds[next_idx]) - int(thresholds[level_idx]) if storyweight_to_next > 0 else 0
		var bark_v: Variant = echo.get("_sanctum_bark", {})
		var bark: Dictionary = bark_v if bark_v is Dictionary else {}
		out.append({
			"id": str(echo.get("id", "")),
			"name": str(echo.get("name", "")),
			"archetype_birth": str(echo.get("archetype_birth", "")),
			"calling_origin": str(echo.get("calling_origin", "Uncalled")),
			"calling": str(echo.get("calling", "")),
			"standing": rank,
			"step": step,
			"step_max": max_level,
			"storyweight": storyweight,
			"storyweight_to_next": storyweight_to_next,
			"storyweight_in_step": storyweight_in_step,
			"storyweight_per_step": storyweight_per_step,
			"dominant_vector": str(echo.get("dominant_vector", "")),
			"stats": {
				"max_hp": int(stats.get("max_hp", 0)),
				"atk": int(stats.get("atk", 0)),
				"def": int(stats.get("def", 0)),
				"agi": int(stats.get("agi", 0)),
				"int": int(stats.get("int", 0)),
				"cha": int(stats.get("cha", 0)),
				"speed": int(stats.get("speed", 0)),
			},
			"emotional_status": EmotionService.get_emotional_status(
				int(emotion.get("morale_current", 50)),
				int(emotion.get("fear_current", 0))
			),
			"sanctum_bark": str(bark.get("line", "")),
			"in_party": str(echo.get("id", "")) in active_party_ids,
			"calling_confirmed": not str(echo.get("calling", "")).strip_edges().is_empty(),
			"skill_entries": _build_skill_entries_for_echo(echo, skills_cfg, ase_balance),
			"bond_entries": SocialGraphService.build_bond_entries_for_actor(
				str(echo.get("id", "")),
				roster,
				bonds,
				party_encounters,
				bond_thresholds
			),
			# V2-PROG-010: maturity expression fields (simulation-internal — not displayed as labels)
			"expression_band":  MaturityExpressionService.get_expression_band(
				rank, cfg_data.get("maturity_expression", {}).get("band_by_standing", {})),
			"rank_strength":    MaturityExpressionService.get_rank_strength(
				rank, int(cfg_data.get("maturity_expression", {}).get("rank_strength_scale", {}).get("max_rank", 9))),
			# V2-PROG-010: earned rank benefits — persistent glyphs on Echo detail card
			"rank_benefits":    _build_rank_benefits(echo, cfg_data),
	})
	return out


# V2-PROG-010: Builds the list of earned rank benefits for display on the Echo detail card.
# Each benefit is unlocked at a minimum rank. Prose only — no numbers.
static func _build_rank_benefits(echo: Dictionary, cfg_data: Dictionary) -> Array:
	var rank: int = int(echo.get("rank", 1))
	var benefits_cfg: Dictionary = cfg_data.get("maturity_expression", {}).get("rank_benefits_config", {})
	var result: Array = []
	for benefit_id in benefits_cfg:
		var b_v: Variant = benefits_cfg[benefit_id]
		if not (b_v is Dictionary):
			continue
		var b: Dictionary = b_v as Dictionary
		if rank >= int(b.get("min_rank", 999)):
			result.append({
				"id":          benefit_id,
				"label":       str(b.get("label", "")),
				"description": str(b.get("description", "")),
			})
	return result


# V2-PROG-009: signature updated — ase_balance needed for can_afford field.
# Uncalled echoes always return [] (no calling_origin fallback).
# Emits constellation_angle, constellation_radius, tier, description, type_label per entry.
# Ghost S6/S9 entries appended with tier:6/9, is_unlocked:false, can_afford:false.
static func _build_skill_entries_for_echo(echo: Dictionary, skills_cfg: Dictionary, ase_balance: int = 0) -> Array:
	var calling := str(echo.get("calling", "")).strip_edges()
	if calling.is_empty() or calling == "uncalled" or skills_cfg.is_empty():
		return []

	var alignments_v: Variant = skills_cfg.get("calling_family_alignment", {})
	var alignments: Dictionary = alignments_v if alignments_v is Dictionary else {}
	if not alignments.has(calling):
		return []

	var alignment_v: Variant = alignments.get(calling, {})
	var alignment: Dictionary = alignment_v if alignment_v is Dictionary else {}
	var strong_families_v: Variant = alignment.get("strong", [])
	var strong_families: Array = strong_families_v if strong_families_v is Array else []
	var light_families_v: Variant = alignment.get("light", [])
	var light_families: Array = light_families_v if light_families_v is Array else []

	var families_v: Variant = skills_cfg.get("families", {})
	var families: Dictionary = families_v if families_v is Dictionary else {}
	var defs_v: Variant = skills_cfg.get("definitions", {})
	var defs: Dictionary = defs_v if defs_v is Dictionary else {}

	# V2-PROG-009: unlock state
	var unlocked_v: Variant = echo.get("unlocked_skills", [])
	var unlocked_skills: Array = unlocked_v if unlocked_v is Array else []
	var calling_confirmed := true  # calling is confirmed if we passed the early return above

	# V2-PROG-009: constellation config for angle assignment
	var constellation_cfg_v: Variant = skills_cfg.get("calling_constellation", {})
	var constellation_cfg: Dictionary = constellation_cfg_v if constellation_cfg_v is Dictionary else {}
	var calling_const_v: Variant = constellation_cfg.get(calling, {})
	var calling_const: Dictionary = calling_const_v if calling_const_v is Dictionary else {}

	# Track how many S3 skills placed per family (for angle index assignment in definition order)
	var family_s3_index: Dictionary = {}

	var entries: Array = []
	for skill_id in defs.keys():
		var defn_v: Variant = defs.get(skill_id, {})
		if not (defn_v is Dictionary):
			continue
		var defn: Dictionary = defn_v
		var family_id := str(defn.get("skill_family", ""))
		var alignment_strength := ""
		if family_id in strong_families:
			alignment_strength = "strong"
		elif family_id in light_families:
			alignment_strength = "light"
		else:
			continue

		var family_v: Variant = families.get(family_id, {})
		var family: Dictionary = family_v if family_v is Dictionary else {}

		# Unlock state
		var uc_v: Variant = defn.get("unlock_conditions", {})
		var uc: Dictionary = uc_v if uc_v is Dictionary else {}
		var ase_cost := int(uc.get("ase_cost", 0))
		var is_unlocked: bool = str(skill_id) in unlocked_skills

		# Constellation position — assign n-th angle in definition order
		var fam_const_v: Variant = calling_const.get(family_id, {})
		var fam_const: Dictionary = fam_const_v if fam_const_v is Dictionary else {}
		var s3_angles_v: Variant = fam_const.get("s3_angles", [])
		var s3_angles: Array = s3_angles_v if s3_angles_v is Array else []
		var s3_idx := int(family_s3_index.get(family_id, 0))
		var constellation_angle := float(s3_angles[s3_idx]) if s3_idx < s3_angles.size() else 270.0
		family_s3_index[family_id] = s3_idx + 1

		entries.append({
			"skill_id":             skill_id,
			"name":                 _humanize_skill_name(str(skill_id)),
			"family_id":            family_id,
			"family_name":          str(family.get("name", _humanize_skill_name(family_id))),
			"alignment":            alignment_strength,
			"is_unlocked":          is_unlocked,
			"ase_cost":             ase_cost,
			"can_afford":           calling_confirmed and ase_balance >= ase_cost,
			"calling_confirmed":    calling_confirmed,
			"tier":                 3,
			"constellation_angle":  constellation_angle,
			"constellation_radius": 70.0,
			"description":          str(defn.get("description", "")),
			"type_label":           _capitalize_type(str(defn.get("type", ""))),
		})

	# Append ghost S6 and S9 nodes for all accessible families.
	# These are visual-only structural placeholders (MOUSE_FILTER_IGNORE in UI).
	var all_fams: Array = []
	for fid_v in strong_families:
		all_fams.append({"id": str(fid_v), "strength": "strong"})
	for fid_v in light_families:
		all_fams.append({"id": str(fid_v), "strength": "light"})

	for fam_info_v in all_fams:
		var fam_info: Dictionary = fam_info_v if fam_info_v is Dictionary else {}
		var fid := str(fam_info.get("id", ""))
		var fstrength := str(fam_info.get("strength", "strong"))
		var fam_const_v: Variant = calling_const.get(fid, {})
		var fam_const: Dictionary = fam_const_v if fam_const_v is Dictionary else {}
		var fam_v: Variant = families.get(fid, {})
		var fam: Dictionary = fam_v if fam_v is Dictionary else {}
		var fam_name := str(fam.get("name", _humanize_skill_name(fid)))

		var s6_angles_v: Variant = fam_const.get("s6_angles", [])
		var s6_angles: Array = s6_angles_v if s6_angles_v is Array else []
		for idx in range(s6_angles.size()):
			entries.append({
				"skill_id":             "",
				"name":                 "—",
				"family_id":            fid,
				"family_name":          fam_name,
				"alignment":            fstrength,
				"is_unlocked":          false,
				"ase_cost":             0,
				"can_afford":           false,
				"calling_confirmed":    calling_confirmed,
				"tier":                 6,
				"constellation_angle":  float(s6_angles[idx]),
				"constellation_radius": 120.0,
				"description":          "",
				"type_label":           "",
			})

		var s9_angles_v: Variant = fam_const.get("s9_angles", [])
		var s9_angles: Array = s9_angles_v if s9_angles_v is Array else []
		for idx in range(s9_angles.size()):
			entries.append({
				"skill_id":             "",
				"name":                 "—",
				"family_id":            fid,
				"family_name":          fam_name,
				"alignment":            fstrength,
				"is_unlocked":          false,
				"ase_cost":             0,
				"can_afford":           false,
				"calling_confirmed":    calling_confirmed,
				"tier":                 9,
				"constellation_angle":  float(s9_angles[idx]),
				"constellation_radius": 165.0,
				"description":          "",
				"type_label":           "",
			})

	entries.sort_custom(Callable(FlowSanctumState, "_sort_skill_entries"))
	return entries


static func _sort_skill_entries(a: Dictionary, b: Dictionary) -> bool:
	# Sort: tier ascending (S3 → S6 → S9), then strong before light, then family, then name.
	var a_tier := int(a.get("tier", 3))
	var b_tier := int(b.get("tier", 3))
	if a_tier != b_tier:
		return a_tier < b_tier
	var a_rank := 0 if str(a.get("alignment", "")) == "strong" else 1
	var b_rank := 0 if str(b.get("alignment", "")) == "strong" else 1
	if a_rank != b_rank:
		return a_rank < b_rank
	var a_family := str(a.get("family_name", ""))
	var b_family := str(b.get("family_name", ""))
	if a_family != b_family:
		return a_family.naturalnocasecmp_to(b_family) < 0
	return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0


static func _capitalize_type(t: String) -> String:
	if t.is_empty():
		return ""
	return t.substr(0, 1).to_upper() + t.substr(1).to_lower()


static func _humanize_skill_name(value: String) -> String:
	var parts: PackedStringArray = value.split("_")
	var words: Array[String] = []
	for part in parts:
		if part.is_empty():
			continue
		words.append(part.capitalize())
	return " ".join(words)


## V2-VOW-002: Builds the active_effects array for the Sanctum ActiveEffectsPanel.
## Shape per entry: { effect_id, label, direction, headline, body, duration_hint, source }
## direction: "buff" | "debuff" | "neutral"
## Debuff chip (vow broken this session) takes priority over active doctrine chip.
## Future stories append entries here without changing the UI consumer.
static func _build_active_effects(flow_ctx: FlowContext) -> Array:
	var effects: Array = []

	# Debuff chip takes priority — if vow just broke this session, show the break indicator.
	if not flow_ctx.session_broken_vow_effect.is_empty():
		effects.append(flow_ctx.session_broken_vow_effect.duplicate())
		return effects

	# Active vow doctrine chip.
	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return effects

	var vow_name       := ""
	var benefit_label  := ""
	var tradeoff_label := ""
	var proverb_twi    := ""
	var proverb_en     := ""
	if flow_ctx.config_service != null:
		var defn := VowService.get_definition(str(av.get("vow_id", "")), flow_ctx.config_service.get_balance())
		vow_name       = str(defn.get("vow_name", ""))
		benefit_label  = str(defn.get("benefit_label", ""))
		tradeoff_label = str(defn.get("tradeoff_label", ""))
		proverb_twi    = str(defn.get("proverb_twi", ""))
		proverb_en     = str(defn.get("proverb_en", ""))

	var compliance_count := int(av.get("compliance_count", 0))
	var direction        := "buff" if compliance_count > 0 else "neutral"

	# Body spells out the mechanical effect — the proverb is already on the mantra label.
	var _body := ""
	if not benefit_label.is_empty():
		_body += "Benefit: " + benefit_label
	if not tradeoff_label.is_empty():
		if not _body.is_empty():
			_body += "\n\n"
		_body += "Violation: " + tradeoff_label
	if _body.is_empty() and not proverb_twi.is_empty():
		_body = proverb_twi + "\n" + proverb_en

	var _duration_hint := ""
	if compliance_count > 0:
		_duration_hint = "%d stage%s honored. Active until the run ends." % [compliance_count, "s" if compliance_count != 1 else ""]
	else:
		_duration_hint = "Honor the vow to activate the benefit."

	effects.append({
		"effect_id":    "vow_active",
		"label":        vow_name,
		"direction":    direction,
		"headline":     vow_name,
		"body":         _body,
		"duration_hint": _duration_hint,
		"source":       "vow",
	})
	return effects
