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
		max_level
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
	max_level: int
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
			"skill_entries": _build_skill_entries_for_echo(echo, skills_cfg),
			"bond_entries": SocialGraphService.build_bond_entries_for_actor(
				str(echo.get("id", "")),
				roster,
				bonds,
				party_encounters,
				bond_thresholds
			),
	})
	return out


static func _build_skill_entries_for_echo(echo: Dictionary, skills_cfg: Dictionary) -> Array:
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
		entries.append({
			"skill_id": skill_id,
			"name": _humanize_skill_name(str(skill_id)),
			"family_id": family_id,
			"family_name": str(family.get("name", _humanize_skill_name(family_id))),
			"alignment": alignment_strength,
		})

	entries.sort_custom(Callable(FlowSanctumState, "_sort_skill_entries"))
	return entries


static func _sort_skill_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_rank := 0 if str(a.get("alignment", "")) == "strong" else 1
	var b_rank := 0 if str(b.get("alignment", "")) == "strong" else 1
	if a_rank != b_rank:
		return a_rank < b_rank
	var a_family := str(a.get("family_name", ""))
	var b_family := str(b.get("family_name", ""))
	if a_family != b_family:
		return a_family.naturalnocasecmp_to(b_family) < 0
	return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0


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
