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
	var fallback_flat_cost := 60 # MVP default
	var grade_costs: Dictionary = {}

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
				ase_rate_per_hour_hint = ase_per_min_base * 60.0

			# Summon costs come from data.summoning (ECONOMY-003)
			if bal_data.has("summoning") and typeof(bal_data["summoning"]) == TYPE_DICTIONARY:
				var summ_cfg: Dictionary = bal_data["summoning"]
				fallback_flat_cost = int(summ_cfg.get("ase_cost_per_summon", 60))
				var grade_costs_v: Variant = summ_cfg.get("ase_cost_per_summon_by_grade", {})
				if grade_costs_v is Dictionary:
					grade_costs = grade_costs_v

	# --- Grade-based cost computation ---
	var selected_grade: String = flow_ctx.selected_summon_grade
	var selected_cost := int(grade_costs.get(selected_grade, fallback_flat_cost))
	var summon_disabled := ase_balance < selected_cost
	var summon_disabled_reason := "not_enough_ase" if summon_disabled else ""

	# Build grade options Array[Dictionary] with per-grade costs
	var grade_labels := { "uncalled": "Uncalled", "called": "Called", "chosen": "Chosen" }
	var grade_keys := ["uncalled", "called", "chosen"]
	var summon_grade_options: Array = []
	for gk: String in grade_keys:
		var gcost := int(grade_costs.get(gk, fallback_flat_cost))
		summon_grade_options.append({
			"key": gk,
			"label": str(grade_labels.get(gk, gk)),
			"ase_cost": gcost,
		})

	return {
		"type": FlowStateIds.SUMMON,
		"data": {
			"title": "Summon Echo",

			# Economy (authoritative + hint)
			"ase_balance": ase_balance,
			"ase_rate_per_hour_hint": ase_rate_per_hour_hint,
			"ase_cost_per_summon": fallback_flat_cost, # Legacy flat key — kept as fallback

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
