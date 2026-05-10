# res://core/state/flow/states/sanctum/FlowVowState.gd
# VOW-001: Vow doctrine management screen.
# Keeper can view available vows, pledge at tier 1, and break the active vow.
# Static build_snapshot() pattern — never calls enter() to rebuild mid-state.

class_name FlowVowState
extends State

func _init(id: String = FlowStateIds.VOW_MANAGE) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	flow_ctx.last_snapshot = build_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	pass


# ---------------------------------------------------------------------------
# Static snapshot builder
# ---------------------------------------------------------------------------

static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	# --- Config ---
	var vow_cfg: Dictionary = {}
	var tier_names: Dictionary = {}
	if flow_ctx.config_service != null:
		var bal: Dictionary = flow_ctx.config_service.get_balance()
		vow_cfg = bal
		var data_v: Variant = bal.get("data", {})
		if data_v is Dictionary:
			var data: Dictionary = data_v
			var vows_v: Variant = data.get("vows", {})
			if vows_v is Dictionary:
				var vows: Dictionary = vows_v
				var tn_v: Variant = vows.get("tier_names", {})
				if tn_v is Dictionary:
					tier_names = tn_v

	# --- Active vow ---
	var active_vow := VowService.get_active_vow(flow_ctx.save_data)

	# --- Realm context (informational only — pledging is allowed at any time) ---
	var realm_in_progress := false
	var realms_v: Variant = flow_ctx.save_data.get("realms", {})
	if realms_v is Dictionary:
		var realms: Dictionary = realms_v
		for rid in realms:
			var rm_v: Variant = realms[rid]
			if rm_v is Dictionary:
				var rm: Dictionary = rm_v
				if str(rm.get("status", "")) == "active":
					realm_in_progress = true
					break

	# --- Build available vows list ---
	var unlocked := VowService.get_unlocked_vows(flow_ctx.save_data)
	var definitions := VowService.get_definitions(vow_cfg)
	var available_vows: Array = []

	for vow_id in definitions:
		var defn_v: Variant = definitions[vow_id]
		if not (defn_v is Dictionary):
			continue
		var defn: Dictionary = defn_v

		# Determine unlock state. `unlocked` is Dict keyed by vow_id → {tier, discovered_realm}.
		var is_unlocked := false
		var max_tier := 0
		var discovered_realm := ""
		if unlocked.has(vow_id):
			var entry_v: Variant = unlocked[vow_id]
			if entry_v is Dictionary:
				var entry: Dictionary = entry_v
				is_unlocked = true
				max_tier = int(entry.get("tier", 1))
				discovered_realm = str(entry.get("discovered_realm", ""))

		var is_active := str(active_vow.get("vow_id", "")) == str(vow_id)
		# V2-VOW-002: "Discovered" badge — true if vow was unlocked during the current session.
		var is_new := false
		for uv in flow_ctx.session_unlocked_vows:
			if (uv as Dictionary).get("vow_id", "") == vow_id:
				is_new = true
				break

		available_vows.append({
			"vow_id":             str(vow_id),
			"proverb_twi":        str(defn.get("proverb_twi", "")),
			"proverb_en":         str(defn.get("proverb_en", "")),
			"vow_name":           str(defn.get("vow_name", "")),
			"description":        str(defn.get("description", "")),
			"benefit_label":      str(defn.get("benefit_label", "")),
			"tradeoff_label":     str(defn.get("tradeoff_label", "")),
			"breaking_cost_hint": str(defn.get("breaking_cost_hint", "")),
			"is_unlocked":        is_unlocked,
			"max_tier_unlocked":  max_tier,
			"is_active":          is_active,
			"discovered_realm":   discovered_realm,
			"unlock_hint":        str(defn.get("unlock_description", "")),
			"is_new":             is_new,  # V2-VOW-002: "Discovered" badge on VowScreen
		})

	# --- Active vow enriched with UI display fields ---
	var active_display: Dictionary = {}
	if not active_vow.is_empty():
		var av_id := str(active_vow.get("vow_id", ""))
		var av_defn := VowService.get_definition(av_id, vow_cfg)
		var av_tier := int(active_vow.get("tier", 1))
		var tier_name_v: Variant = tier_names.get(str(av_tier), "Whisper")
		active_display = {
			"vow_id":                 av_id,
			"proverb_twi":            str(av_defn.get("proverb_twi", "")),
			"proverb_en":             str(av_defn.get("proverb_en", "")),
			"vow_name":               str(av_defn.get("vow_name", "")),
			"tier":                   av_tier,
			"tier_name":              str(tier_name_v),
			"benefit_label":          str(av_defn.get("benefit_label", "")),
			"tradeoff_label":         str(av_defn.get("tradeoff_label", "")),
			# V2-VOW-002: compliance history and benefit condition label for VowScreen display.
			"compliance_count":       int(active_vow.get("compliance_count", 0)),
			"benefit_condition_label": str(av_defn.get("benefit_label", "")),
		}

	# --- Actions (slot-keyed dict) ---
	# Pledging is allowed at any time — during a realm or in Sanctum — as long as no vow is active.
	var can_pledge := active_vow.is_empty()
	var can_break  := not active_vow.is_empty()

	var actions: Dictionary = {
		"nav.back": {
			"type":    "flow.go_state",
			"label":   "Back",
			"to":      FlowStateIds.SANCTUM,
			"disabled": false,
		},
		"cta.pledge": {
			"type":     "vow.pledge",
			"label":    "Pledge Vow",
			"disabled": not can_pledge,
			"payload":  {},  # caller fills in { vow_id, tier } before dispatch
		},
		"cta.break": {
			"type":     "vow.break",
			"label":    "Break Vow",
			"disabled": not can_break,
		},
	}

	return {
		"type": FlowStateIds.VOW_MANAGE,
		"meta": { "sim_tick": t },
		"data": {
			"active_vow":       active_display,
			"available_vows":   available_vows,
			"can_pledge":       can_pledge,
			"realm_in_progress": realm_in_progress,
		},
		"actions": actions,
	}
