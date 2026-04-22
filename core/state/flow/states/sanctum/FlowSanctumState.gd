class_name FlowSanctumState

extends State

func _init(id: String = FlowStateIds.SANCTUM) -> void:
	super(id)
	
func enter(ctx: RefCounted, t:int) -> void:
	var flow_ctx := ctx as FlowContext

	# VOW-001: release active vow when returning to Sanctum after a realm run completes.
	# Two cases:
	#   pledged_at_realm != "" → release when that specific realm is no longer active.
	#   pledged_at_realm == "" → pledged from Sanctum with no realm active;
	#                            release when total run_count across all realms increases.
	var _v_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if _v_sanctum_v is Dictionary:
		var _v_sanctum: Dictionary = _v_sanctum_v
		var _av_v: Variant = _v_sanctum.get("active_vow", {})
		if _av_v is Dictionary and not (_av_v as Dictionary).is_empty():
			var _av: Dictionary = _av_v
			var _pledged_realm := str(_av.get("pledged_at_realm", ""))
			var _realms_check_v: Variant = flow_ctx.save_data.get("realms", {})
			var _should_release := false

			if _pledged_realm != "":
				# Pledged during a realm — release once that realm is no longer active.
				if _realms_check_v is Dictionary:
					var _realm_entry_v: Variant = (_realms_check_v as Dictionary).get(_pledged_realm, {})
					if _realm_entry_v is Dictionary:
						var _still_active := str((_realm_entry_v as Dictionary).get("status", "")) == RealmModel.STATUS_ACTIVE
						_should_release = not _still_active
					else:
						_should_release = true  # realm no longer exists — release
			else:
				# Pledged from Sanctum with no active realm.
				# Release once total completed runs across all realms exceeds runs_at_pledge.
				var _runs_at_pledge := int(_av.get("runs_at_pledge", 0))
				var _current_runs := 0
				if _realms_check_v is Dictionary:
					var _realms_d: Dictionary = _realms_check_v
					for _rid in _realms_d:
						var _rm_v: Variant = _realms_d[_rid]
						if _rm_v is Dictionary:
							_current_runs += int((_rm_v as Dictionary).get("run_count", 0))
				_should_release = _current_runs > _runs_at_pledge

			if _should_release:
				VowService.release_vow(flow_ctx.save_data, flow_ctx, flow_ctx.logger, t)

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

	# Build a small preview list (first 3)
	var roster_preview: Array = []
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
				"vow_id":      _av_id,
				"proverb_twi": str(_av_defn.get("proverb_twi", "")),
				"proverb_en":  str(_av_defn.get("proverb_en", "")),
				"tier":        _av_tier,
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
		"active_vow": _av_display,  # VOW-001: mantra data for SanctumScreen header
		"thread_reserve":     _thread_reserve,      # V2-WEAVE-001: Array[{virtue, quality_tier}]
		"thread_reserve_cap": _thread_reserve_cap,  # V2-WEAVE-001: base reserve cap (default 4)
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
