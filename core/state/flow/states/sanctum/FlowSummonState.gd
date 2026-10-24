class_name FlowSummonState
extends State

func _init(id: String = FlowStateIds.SUMMON) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Grade resets on every Summon state entry — never persists across visits
	flow_ctx.selected_summon_grade = "uncalled"

	flow_ctx.last_snapshot = build_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	pass

# Static builder — called by enter() and by FlowRuntime.grade_select handler.
# Does NOT reset grade (that is enter()'s responsibility).
static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	# Transient reveal queue (FlowContext only; NOT saved)
	var pending: Array = []
	if flow_ctx.pending_summon_reveals != null and flow_ctx.pending_summon_reveals is Array:
		pending = flow_ctx.pending_summon_reveals

	# --- Economy snapshot fields (authoritative from save, hints from config) ---
	var ase_balance := 0
	var ase_rate_per_hour_hint := 0.0
	var summ_cfg: Dictionary = {}

	# Read economy balances from save (authoritative)
	if flow_ctx.save_data != null and flow_ctx.save_data.has("economy") and typeof(flow_ctx.save_data["economy"]) == TYPE_DICTIONARY:
		var econ: Dictionary = flow_ctx.save_data["economy"]
		ase_balance = int(econ.get("ase", 0))

	# Read economy config from balance.json (hints / costs)
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		if balance.has("data") and typeof(balance["data"]) == TYPE_DICTIONARY:
			var bal_data: Dictionary = balance["data"]

			# Rate hint comes from data.economy
			if bal_data.has("economy") and typeof(bal_data["economy"]) == TYPE_DICTIONARY:
				var econ_cfg: Dictionary = bal_data["economy"]
				var ase_per_min_base := float(econ_cfg.get("ase_online_per_min_base", 0.0))
				var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
				var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
				var flame_v: Variant = sanctum.get("ase_flame", {})
				var flame: Dictionary = flame_v if flame_v is Dictionary else {}
				if not bool(flame.get("awakened", false)):
					ase_per_min_base = 0.0
				ase_rate_per_hour_hint = ase_per_min_base * 60.0

			# Summon costs come from data.summoning (ECONOMY-003)
			if bal_data.has("summoning") and typeof(bal_data["summoning"]) == TYPE_DICTIONARY:
				summ_cfg = bal_data["summoning"]

	# --- Prices: every number comes from SummonService.price_for ---
	var selected_grade: String = flow_ctx.selected_summon_grade
	var living := SummonService.living_count(flow_ctx.save_data)
	var batch_prices := SummonService.batch_prices(summ_cfg, selected_grade, living, SummonService.MAX_BATCH)
	var batch_totals: Array[int] = []
	var running := 0
	var affordable_max := 0
	for p: int in batch_prices:
		running += p
		batch_totals.append(running)
		if running <= ase_balance:
			affordable_max += 1
	var summon_disabled := affordable_max < 1
	var summon_disabled_reason := "not_enough_ase" if summon_disabled else ""
	# The count is UI state; ase_short_by covers one summon. For a larger count the UI subtracts from batch_totals.
	var ase_short_by := maxi(0, batch_totals[0] - ase_balance)

	var grade_labels := { "uncalled": "Uncalled", "called": "Called", "chosen": "Chosen" }
	var summon_grade_options: Array = []
	for gk: String in SummonService.GRADES:
		summon_grade_options.append({
			"key": gk,
			"label": str(grade_labels.get(gk, gk)),
			"ase_cost": SummonService.price_for(summ_cfg, gk, living + 1),
			"ase_cost_after": SummonService.price_for(summ_cfg, gk, living + 2),
		})
	var next_uncalled := SummonService.price_for(summ_cfg, "uncalled", living + 1)
	var after_uncalled := SummonService.price_for(summ_cfg, "uncalled", living + 2)

	return {
		"type": FlowStateIds.SUMMON,
		"data": {
			"title": "Summon Echo",

			# Economy (authoritative + hint)
			"ase_balance": ase_balance,
			"ase_rate_per_hour_hint": ase_rate_per_hour_hint,
			"ase_cost_per_summon": next_uncalled, # Legacy key; the UI stops reading it later

			# Village price (D-55, D-59): the price depends on how many Echoes live
			"living_count": living,
			"village_ceiling": SummonService.village_ceiling(summ_cfg),
			"price_flat": next_uncalled == after_uncalled,
			"batch_prices": batch_prices,
			"batch_totals": batch_totals,
			"batch_affordable_max": affordable_max,
			"ase_short_by": ase_short_by,

			# Grade selection (ECONOMY-003)
			"selected_grade": selected_grade,
			"summon_disabled": summon_disabled,
			"summon_disabled_reason": summon_disabled_reason,

			# Grade options now Array[Dict] with per-grade costs
			"summon_grade_options": summon_grade_options,
			"default_summon_grade": "uncalled",

			# Slider UI is 1..10 (SummonScreen clamps anyway)
			"default_summon_amount": 1,

			# Reveal overlay queue (SummonScreen reads this key)
			"pending_summon_reveals": pending,
		},

		# Slot-based actions (bespoke UI binds these)
		"actions": {
			"nav.back": {
				"type": "flow.go_state",
				"to": FlowStateIds.SANCTUM,
				"label": "Back",
				"slot": "nav.back",
			},

			# Main CTA: UI supplies count/now_unix; disabled when insufficient balance
			"cta.summon": {
				"type": "sanctum.summon",
				"label": "Summon",
				"slot": "cta.summon",
				"disabled": summon_disabled,
			},

			# Overlay dismiss
			"overlay.dismiss_reveals": {
				"type": "ui.dismiss_summon_reveals",
				"label": "Dismiss",
				"slot": "overlay.dismiss_reveals",
			},
		},

		"meta": { "t": t }
	}
