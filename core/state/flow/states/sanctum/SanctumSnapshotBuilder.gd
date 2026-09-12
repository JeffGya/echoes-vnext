class_name SanctumSnapshotBuilder

extends RefCounted

## V2-INFRA-003 Phase 3 Slice A.
##
## Pure projection for the flow.sanctum snapshot. Reads `flow_ctx` and `flow_ctx.save_data`
## only — writes nothing. No save_data mutation, no FlowContext field mutation, no
## request_save(), no service call whose purpose is to persist a change.
##
## Absorbs two things that used to be split across two different call sites:
##   1. Everything FlowSanctumState.enter() built directly (roster preview, echo detail
##      roster, sanctum layout/occupants, institutions, thread reserve, active vow display,
##      companion invite, ...).
##   2. The Sanctum-only enrichment block that used to be bolted onto
##      FlowStateMachine._rebuild_snapshot() (ase_balance, ekwan_balance, ase_flame fields,
##      sanctum_name(+suggested), roster_count, active_party_count, party_slots,
##      active_directive_id, available_directives, show_awakening_overlay,
##      return_notification).
##
## Because both halves are now produced by this one pure function, FlowSanctumState.enter()
## (and FlowStateMachine.reenter(), which re-runs enter() without a transition) produce a
## COMPLETE flow.sanctum snapshot on their own — no follow-up state-specific enrichment pass
## is required or performed by FlowStateMachine._rebuild_snapshot() anymore.
##
## The two one-shot flags (FlowContext.pending_awakening_banner and
## pending_return_notification) are READ here to derive show_awakening_overlay and
## return_notification, but never cleared here — this function is pure. They are cleared
## exactly once by FlowRuntime.dispatch(), in the closure at the end of dispatch(), AFTER the
## snapshot this build() call produced has already been published to flow_ctx.last_snapshot
## and logged. This preserves "shown exactly once" without the previous bug where a second
## refresh_snapshot() call within the same dispatch silently swallowed the overlay before the
## UI ever saw it.
##
## Lifecycle work — VowService.release_vow_if_due(), SanctumLayoutService.ensure_layout(),
## and any other save_data repair — belongs in FlowSanctumState.enter() BEFORE this is
## called. Never add lifecycle/repair work here.
static func build(flow_ctx: FlowContext, t: int) -> Dictionary:
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
	var echo_detail_roster: Array = FlowSanctumState._build_echo_detail_roster(
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
			"origin":          str(echo.get("origin", "")),  # V2-STAGE-004 S15 prep: "recruited_ally" for companion tag
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
	# Reads the layout via SanctumLayoutService.ensure_layout() — idempotent re-derivation of
	# the layout FlowSanctumState.enter() already repaired as lifecycle work before calling
	# build(). Calling it again here produces byte-identical output (same institutions, same
	# save_data), not a new mutation of substance.
	var _pl_layout := SanctumLayoutService.ensure_layout(flow_ctx.save_data, _inst_snapshot)
	var _pl_tiles: Array = _pl_layout.get("tiles", [])
	# V2-INFRA-003 Phase 3 Slice B2: JSON-safe plain dicts, not Vector2i — Vector2i cannot survive
	# JSON serialization, so the central null-scan validator could not inspect this field before.
	# Same cells, same order, same count as the Vector2i form this replaces — representation only.
	var _pl_floor: Array = []
	var _pl_occupied: Array = []
	for _pl_tile_v in _pl_tiles:
		if not (_pl_tile_v is Dictionary):
			continue
		var _pl_tile: Dictionary = _pl_tile_v
		var _pl_kind := str(_pl_tile.get("kind", ""))
		var _pl_cell := { "x": int(_pl_tile.get("x", 0)), "y": int(_pl_tile.get("y", 0)) }
		if _pl_kind == "floor":
			_pl_floor.append(_pl_cell)
		else:
			_pl_occupied.append(_pl_cell)

	# V2-INFRA-003 Phase 3 Slice B2: same JSON-safe conversion for the valid-placement cell list —
	# SanctumLayoutService.compute_valid_placement_cells() still returns Array[Vector2i] (its
	# other consumers, e.g. tests/SanctumLayoutTests.gd and SanctumLayoutService's own
	# check_placement_validity_from_data()/get_bridge_preview_from_floor(), take live Vector2i
	# arrays, not snapshot payloads, so that return type is unchanged). Convert only at this
	# snapshot-payload boundary — same cells, same order, same count.
	var _pl_valid_v2i: Array = SanctumLayoutService.compute_valid_placement_cells(flow_ctx.save_data, _inst_snapshot)
	var _pl_valid: Array = []
	for _pl_vc in _pl_valid_v2i:
		if _pl_vc is Vector2i:
			_pl_valid.append({ "x": (_pl_vc as Vector2i).x, "y": (_pl_vc as Vector2i).y })

	# V2-CONTINUITY-001: Continuity band + points for TitleRow flame indicator.
	var _cont_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var _b: Dictionary = flow_ctx.config_service.get_balance()
		var _bd := _b.get("data", {}) as Dictionary
		var _cv: Variant = _bd.get("continuity", {})
		_cont_cfg = _cv if _cv is Dictionary else {}
	var _cont_pts  := ContinuityService.get_points(flow_ctx.save_data)
	var _cont_band := ContinuityService.get_band(_cont_pts, _cont_cfg)

	# V2-STAGE-004 Phase 4 (S14 redesign): earned-return companion invite — a one-slot Sanctum
	# inbox (written by RecruitmentConsequenceService.compute_ally_recruit_offer_if_eligible on combat victory,
	# cleared by sanctum.companion.accept/decline). {} when no invite is pending. Re-projects on
	# every Sanctum entry, so the invite "persists until decided" for free — no expiry logic here.
	var _companion_invite_v: Variant = sanctum.get("companion_invite", {})
	var _companion_invite: Dictionary = _companion_invite_v if _companion_invite_v is Dictionary else {}

	# Base Sanctum snapshot payload (formerly built by FlowSanctumState.enter() alone).
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
		"active_effects": FlowSanctumState._build_active_effects(flow_ctx),
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
		# JSON-safe cell dicts {"x": int, "y": int} — NOT Vector2i (see conversion above).
		"valid_placement_cells":     _pl_valid,
		"placement_floor_cells":     _pl_floor,    # all floor tiles; for SanctumShell placement checks
		"placement_occupied_cells":  _pl_occupied, # all non-floor tiles (ase_flame, institutions)
		"institution_compat_hints":  _compat_hints,
		# V2-STAGE-004 Phase 4 (S14 redesign): {} when no invite pending.
		"companion_invite": _companion_invite,
	}

	# ---------------------------------------------------------------------
	# V2-INFRA-003 Phase 3: former FlowStateMachine._rebuild_snapshot() Sanctum enrichment
	# block, folded into this pure builder. Same fields, same values, same read-only sources —
	# the only change is WHERE this runs, and that the two one-shot flags below are read
	# (never cleared) here.
	# ---------------------------------------------------------------------

	# Read from save data only (authoritative), normalize int/float safely
	var econ: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("economy") and typeof(flow_ctx.save_data["economy"]) == TYPE_DICTIONARY:
		econ = flow_ctx.save_data["economy"]

	# SANCTUM-001: Ase rate hint (NOT a balance prediction)
	# Used only for UI text like: "~ 1.2 Ase gathered p/h"
	var ase_per_min_base := 0.0
	var multiplier := 1.0 # seam for later emotion metrics

	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		if balance.has("data") and typeof(balance["data"]) == TYPE_DICTIONARY:
			var bal_data: Dictionary = balance["data"]
			if bal_data.has("economy") and typeof(bal_data["economy"]) == TYPE_DICTIONARY:
				var econ_cfg: Dictionary = bal_data["economy"]
				ase_per_min_base = float(econ_cfg.get("ase_online_per_min_base", 0.0))

	data["ase_balance"] = int(econ.get("ase", 0))
	data["ekwan_balance"] = int(econ.get("ekwan", 0))
	var flame_v: Variant = sanctum.get("ase_flame", {})
	var flame: Dictionary = flame_v if flame_v is Dictionary else {}
	if not bool(flame.get("awakened", false)):
		ase_per_min_base = 0.0
	# per_hour = per_min * 60
	data["ase_rate_per_hour_hint"] = ase_per_min_base * 60.0 * multiplier
	data["ase_flame"] = flame.duplicate(true)
	data["ase_rate_per_hour"] = ase_per_min_base * 60.0 * multiplier

	# V2-ECONOMY-001: Ase Flame awakened flag + awakening overlay.
	data["ase_flame_awakened"] = bool(flame.get("awakened", false))

	# READ ONLY — pending_awakening_banner is a one-shot flag. This build() call surfaces its
	# current value; it does NOT clear it. FlowRuntime.dispatch() clears it after the snapshot
	# built here has been published (see the closure at the end of dispatch()).
	data["show_awakening_overlay"] = flow_ctx.pending_awakening_banner

	# Awakening grant amount for overlay label (read from balance config).
	var _aw_grant := 40
	if flow_ctx.config_service != null:
		var _aw_bal: Dictionary = flow_ctx.config_service.get_balance()
		var _aw_data_v: Variant = _aw_bal.get("data", {})
		var _aw_data: Dictionary = _aw_data_v if _aw_data_v is Dictionary else {}
		var _aw_econ_v: Variant = _aw_data.get("economy", {})
		var _aw_econ: Dictionary = _aw_econ_v if _aw_econ_v is Dictionary else {}
		_aw_grant = int(_aw_econ.get("awakening_ase_grant", 40))
	data["awakening_grant"] = _aw_grant

	# ECONOMY-005: one-shot return notification (VOW-002 path). READ ONLY — same one-shot
	# contract as show_awakening_overlay above; FlowRuntime.dispatch() clears
	# pending_return_notification after this snapshot is published, never here.
	if not flow_ctx.pending_return_notification.is_empty():
		data["return_notification"] = flow_ctx.pending_return_notification.duplicate(true)

	# Sanctum name
	var sanctum_name := str(sanctum.get("name", ""))
	var roll_index := int(sanctum.get("name_roll_index", 0))

	# Deterministic suggestion (even if already named, harmless)
	var root_seed := int(flow_ctx.save_data.get("campaign", {}).get("root_seed", 0))
	var seed := CampaignSeed.new(root_seed)
	data["sanctum_name_suggested"] = SanctumNameService.suggest(seed, roll_index)

	data["sanctum_name"] = sanctum_name
	data["roster_count"] = roster.size()
	data["active_party_count"] = active_party_ids.size()

	# SANCTUM-003 Subtask 4: party_slots projection (player-facing only, no IDs)
	var party_slots: Array = []
	for pid_v in active_party_ids:
		var pid := str(pid_v)
		if pid.is_empty():
			continue
		for echo_v2 in roster:
			if not (echo_v2 is Dictionary):
				continue
			var echo2: Dictionary = echo_v2
			if str(echo2.get("id", "")) == pid:
				var _emo_p: Dictionary = echo2.get("emotion", {})
				party_slots.append({
					"name":             str(echo2.get("name", "")),
					"step":             int(echo2.get("level", 1)),
					"standing":         int(echo2.get("rank", 1)),
					# V2-EMOTION-002: unified emotional status.
					"emotional_status": EmotionService.get_emotional_status(
						int(_emo_p.get("morale_current", 50)),
						int(_emo_p.get("fear_current", 0))
					),
					# V2-STAGE-004 P4 S15 UI-A3: player-facing companion attribute (no id exposed).
					"origin":           str(echo2.get("origin", "")),
				})
				break
	data["party_slots"] = party_slots

	# DIRECTIVE-001: surface active directive in Sanctum snapshot (debug/snapshot visibility)
	# DIRECTIVE-002 will replace the static available_directives list with a dynamic call.
	var stage_ctx_dir: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("stage_context") \
			and typeof(flow_ctx.save_data["stage_context"]) == TYPE_DICTIONARY:
		stage_ctx_dir = flow_ctx.save_data["stage_context"]
	data["active_directive_id"] = str(stage_ctx_dir.get("active_directive_id", "directive.scout_carefully"))
	data["available_directives"] = ["directive.scout_carefully", "directive.seek_signs"]

	return {
		"type": FlowStateIds.SANCTUM,
		"data": data,
		"actions": actions,
		"meta": {
			"t": t
		}
	}
