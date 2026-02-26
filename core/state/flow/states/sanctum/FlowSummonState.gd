class_name FlowSummonState
extends State

func _init(id: String = FlowStateIds.SUMMON) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Transient reveal queue (FlowContext only; NOT saved)
	var pending: Array = []
	if flow_ctx.pending_summon_reveals != null and flow_ctx.pending_summon_reveals is Array:
		pending = flow_ctx.pending_summon_reveals

	# --- Economy snapshot fields (authoritative from save, hints from config) ---
	var ase_balance := 0
	var ase_rate_per_hour_hint := 0.0
	var ase_cost_per_summon := 60 # MVP default

	# Read economy balances from save (authoritative)
	if flow_ctx.save_data != null and flow_ctx.save_data.has("economy") and typeof(flow_ctx.save_data["economy"]) == TYPE_DICTIONARY:
		var econ: Dictionary = flow_ctx.save_data["economy"]
		ase_balance = int(econ.get("ase", 0))

	# Read economy config from balance.json (hints / costs)
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		if balance.has("data") and typeof(balance["data"]) == TYPE_DICTIONARY:
			var bal_data: Dictionary = balance["data"]

			# ECONOMY-002 hint (same shape you used in FlowStateMachine for Sanctum)
			if bal_data.has("economy") and typeof(bal_data["economy"]) == TYPE_DICTIONARY:
				var econ_cfg: Dictionary = bal_data["economy"]

				# Rate hint (~ per hour)
				var ase_per_min_base := float(econ_cfg.get("ase_online_per_min_base", 0.0))
				ase_rate_per_hour_hint = ase_per_min_base * 60.0

				# Summon cost (try a few likely keys; fallback stays 60)
				# NOTE: keep these additive/non-breaking; whichever exists in your balance.json wins.
				if econ_cfg.has("ase_cost_per_summon"):
					ase_cost_per_summon = int(econ_cfg.get("ase_cost_per_summon", 60))
				elif econ_cfg.has("summon_cost_ase"):
					ase_cost_per_summon = int(econ_cfg.get("summon_cost_ase", 60))
				elif econ_cfg.has("ase_summon_cost"):
					ase_cost_per_summon = int(econ_cfg.get("ase_summon_cost", 60))

	# --- Snapshot ---
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.SUMMON,
		"data": {
			"title": "Summon Echo",

			# Economy (authoritative + hint)
			"ase_balance": ase_balance,
			"ase_rate_per_hour_hint": ase_rate_per_hour_hint,
			"ase_cost_per_summon": ase_cost_per_summon,

			# UI scaffolding (MVP)
			"summon_grade_options": ["uncalled", "called", "chosen"],
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

			# Main CTA: UI supplies count/grade/now_unix
			"cta.summon": {
				"type": "sanctum.summon",
				"label": "Summon",
				"slot": "cta.summon",
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

func exit(ctx: RefCounted, t: int) -> void:
	pass