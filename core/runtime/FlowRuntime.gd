# res://core/runtime/FlowRuntime.gd
class_name FlowRuntime
extends RefCounted

var logger: StructuredLogger
var config_service: ConfigService
var flow_ctx: FlowContext
var flow_machine: FlowStateMachine
var econ: EconomyService

func _init(_logger: StructuredLogger, _config_service: ConfigService) -> void:
	logger = _logger
	config_service = _config_service

func _next_tick() -> int:
	var t := flow_ctx.sim_tick
	flow_ctx.sim_tick += 1
	return t

func boot() -> Dictionary:
	# Flow owned ticks should start counting.
	flow_ctx = FlowContext.new()
	flow_ctx.sim_tick = 0
	flow_ctx.config_service = config_service

	logger.debug(_next_tick(), "boot.start", "Boot sequence started", {})

	# Load configs
	var ok_balance := config_service.load_balance(logger, _next_tick())
	var ok_actors := config_service.load_actors(logger, _next_tick())
	var ok_realms := config_service.load_realms(logger, _next_tick())

	if not (ok_balance and ok_actors and ok_realms):
		logger.log_state_transition(_next_tick(), "boot", "error", "config_invalid")
		var snap := {
			"type": "error",
			"meta": { "tick": flow_ctx.sim_tick },
			"data": { "message": "Configuration validation failed. See logs." }
		}
		_log_snapshot_emitted(flow_ctx.sim_tick, snap, "boot.error")
		flow_ctx.last_snapshot = snap
		return snap

	# Save load/create
	var save := SaveService.load_from_file(SaveSchema.DEFAULT_SAVE_PATH, logger, _next_tick())
	if save.is_empty():
		save = SaveService.make_new_save(12346)
		SaveService.save_to_file(SaveSchema.DEFAULT_SAVE_PATH, save, logger, _next_tick())

	flow_ctx.save_data = save
	econ = EconomyService.new(flow_ctx.save_data)
	
	# Flow state machine
	flow_machine = FlowStateMachine.new()
	flow_machine.register_default_states()
	flow_machine.start(flow_ctx, logger, _next_tick())

	# Flow should have placed last_snapshot already
	var out := flow_ctx.last_snapshot
	_log_snapshot_emitted(flow_ctx.sim_tick, out, "boot.complete")
	return out

func dispatch(action: Dictionary) -> Dictionary:
	var t := _next_tick()
	var action_type := str(action.get("type", ""))

	match action_type:
		
		# ---- Flow ----
		"flow.new_game":
			_handle_new_game(t)
			flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.flow.new_game")
			
		"flow.advance":
			var to_state := str(action.get("to", ""))
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.advance")

		"flow.go_state":
			var to_state := str(action.get("to", ""))
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.go_state")

		"flow.select_realm":
			var realm_id := str(action.get("realm_id", ""))
			flow_ctx.realm_id = realm_id
			flow_ctx.save_request = true
			flow_ctx.save_request_reason = "realm_select"
			flow_machine.transition(FlowStateIds.STAGE, flow_ctx, logger, t, "ui.flow.select_stage")

		"flow.continue":
			var is_first_boot: bool = bool(flow_ctx.save_data.get("first_boot", true))
			if is_first_boot:
				flow_ctx.save_data["first_boot"] = false
				flow_ctx.save_request = true
				flow_ctx.save_request_reason = "continue_first_boot"
				
			_apply_offline_accrual_if_needed(t, "flow.continue")
				
			flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.flow.continue")

		"flow.settings":
			logger.debug(t, "ui.flow.settings", "Settings not implemented (MVP).", {})

		"flow.quit":
			logger.debug(t, "ui.flow.quit", "Quit not implemented (MVP).", {})

		# ---- Debug Seed (SANCTUM-002) ----
		"debug.seed.show":
			_handle_debug_seed_show(t)

		"debug.seed.set":
			_handle_debug_seed_set(action, t, false)

		"debug.seed.reset":
			_handle_debug_seed_set(action, t, true)
			
		# ---- Debug Echo (SANCTUM-002) ----
		"debug.echo.gen_test":
			_handle_debug_echo_gen_test(t)

		# ---- Encounter ----
		"encounter.advance":
			var to_state := str(action.get("to", ""))
			if flow_ctx.encounter_machine == null or flow_ctx.encounter_ctx == null:
				logger.debug(t, "ui.encounter.advance", "Encounter not initialized", { "action": action })
			else:
				flow_ctx.encounter_machine.transition(to_state, flow_ctx.encounter_ctx, logger, t, "ui.encounter.advance")
				flow_machine.refresh_snapshot(flow_ctx, logger, t)

		"encounter.complete":
			flow_ctx.encounter_ctx = null
			flow_ctx.encounter_machine = null
			flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "ui.encounter.complete")

		# ---- Economy ----
		"economy.settle_time":
			_handle_economy_settle_time(action, t)
			
		"economy.ase.add":
			var amount := int(action.get("amount", 0))
			var reason := str(action.get("reason", "economy.ase.add"))
			econ.add_ase(amount, reason, logger, t)
			flow_machine.refresh_snapshot(flow_ctx, logger, t)

		"economy.ase.spend":
			# settle first (same as you do in debug.before_spend)
			var now_unix := int(action.get("now_unix", 0))
			if now_unix > 0:
				_handle_economy_settle_time({ "type":"economy.settle_time", "now_unix": now_unix, "source": "debug.before_spend" }, t)

			var amount := int(action.get("amount", 0))
			var reason := str(action.get("reason", "economy.ase.spend"))
			econ.spend_ase(amount, reason, logger, t)
			# include ok in snapshot? not needed now; debug prints it
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
		
		# ---- Sanctum ----
		"sanctum.name.reroll":
			if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
				flow_ctx.save_data["sanctum"] = {}

			var sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary
			var idx := int(sanctum.get("name_roll_index", 0)) + 1
			sanctum["name_roll_index"] = idx

			# No save request on reroll (no save spam)
			logger.debug(t, "sanctum.name.reroll", "Rerolled sanctum name suggestion", {
				"roll_index": idx
			})

			# IMPORTANT: no transition occurs, so we must refresh snapshot
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
		
		"sanctum.name.confirm":
			if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
				flow_ctx.save_data["sanctum"] = {}

			var sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary

			var raw := str(action.get("name", ""))
			var name := raw.strip_edges()

			# MVP sanitize rules (deterministic, no OS time)
			if name.length() < 2:
				name = "Sanctum"
			if name.length() > 24:
				name = name.substr(0, 24)

			sanctum["name"] = name

			# Request a save flush (Flow-owned choke point will do it once)
			flow_ctx.save_request = true
			if flow_ctx.save_request_reason != "":
				flow_ctx.save_request_reason += "|sanctum.name.confirm"
			else:
				flow_ctx.save_request_reason = "sanctum.name.confirm"

			logger.info(t, "sanctum.name.confirm", "Sanctum name set", {
				"name": name
			})
			
		"sanctum.summon":
			_handle_sanctum_summon(action, t)

		# UI actions
		"ui.dismiss_summon_reveals":
			flow_ctx.pending_summon_reveals.clear()
			logger.debug(t, "ui.dismiss_summon_reveals", "Dismissed summon reveal queue", {
				"remaining": flow_ctx.pending_summon_reveals.size()
			})
			flow_machine.refresh_snapshot(flow_ctx, logger, t)

			# IMPORTANT: no transition occurs, so refresh snapshot
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
		
		_:
			logger.debug(t, "ui.action.unknown", "Unknown action type", { "action": action })

	# If we just entered flow.encounter, bootstrap the Encounter machine.
	_ensure_encounter_started(t)

	# Flow-owned save choke point (single save max per dispatch tick)
	if flow_ctx.save_request:
		var reason := str(flow_ctx.save_request_reason)
		var ok := SaveService.save_to_file(
			SaveSchema.DEFAULT_SAVE_PATH,
			flow_ctx.save_data,
			logger,
			t
		)

		logger.debug(t, "save.flush", "Save flush executed", {
			"ok": ok,
			"reason": reason
		})

		# Always clear request so we don't spam saves on repeated dispatch
		flow_ctx.save_request = false
		flow_ctx.save_request_reason = ""

	# IMPORTANT: Subtask 2 will keep behavior identical:
	# return whatever Flow decided is current
	var out := flow_ctx.last_snapshot
	_log_snapshot_emitted(t, out, "dispatch")
	return out

# Helper section for the flow actions
func _handle_sanctum_summon(action: Dictionary, t: int) -> void:
	# 0) parse count
	var count := int(action.get("count", 1))
	if count < 1:
		count = 1
	if count > 10:
		count = 10

	# 1) settle before spend
	var now_unix := int(action.get("now_unix", 0))
	if now_unix > 0:
		_handle_economy_settle_time({
			"type": "economy.settle_time",
			"now_unix": now_unix,
			"source": "sanctum.summon.before_spend"
		}, t)

	# 2) read cost
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}
	var cost_each := int(summ_cfg.get("ase_cost_per_summon", 60))

	var total_cost := cost_each * count

	# 3) check funds
	var econ_v: Variant = flow_ctx.save_data.get("economy", {})
	var econ_data: Dictionary = econ_v if econ_v is Dictionary else {}
	var ase_before := int(econ_data.get("ase", 0))

	if ase_before < total_cost:
		logger.info(t, "sanctum.summon.denied", "Not enough Ase to summon", {
			"ase": ase_before,
			"cost_each": cost_each,
			"count": count,
			"total_cost": total_cost
		})
		return

	# 4) spend once
	var ok_spend: bool = econ.spend_ase(total_cost, "summon.cost", logger, t)
	if not ok_spend:
		logger.info(t, "sanctum.summon.denied", "Spend failed", {
			"ase": ase_before,
			"total_cost": total_cost,
			"count": count
		})
		return

	# 5) generate + persist many
	var camp: Dictionary = {}
	if flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]
	var seed_root := str(camp.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "sanctum.summon.denied", "Missing campaign seed_root", {})
		return

	var result := SummonService.summon_paid_many(flow_ctx.save_data, seed_root, summ_cfg, count, logger, t)

	if bool(result.get("ok", false)):
		# Append newly summoned echoes to transient reveal queue (NOT saved)
		var echoes_v: Variant = result.get("echoes", [])
		var echoes: Array = echoes_v if echoes_v is Array else []
		for e_v in echoes:
			if e_v is Dictionary:
				flow_ctx.pending_summon_reveals.append(e_v)

		flow_ctx.save_request = true
		flow_ctx.save_request_reason = "sanctum.summon"
		
func _handle_new_game(t: int) -> void:
	# Create a new campaign root seed string (random once; then persisted)
	var seed_root := _generate_seed_root_string()
	var legacy_root_seed := _legacy_root_seed_from_seed_root(seed_root)

	# Replace current save with a fresh one
	var save := SaveService.make_new_save(legacy_root_seed)

	# Canonical campaign seed fields (SANCTUM-002)
	if not save.has("campaign") or typeof(save["campaign"]) != TYPE_DICTIONARY:
		save["campaign"] = {}
	var camp: Dictionary = save["campaign"]
	camp["seed_root"] = seed_root
	camp["seed_source"] = "random"

	# This is a brand-new run (menu first boot should not persist)
	save["first_boot"] = false

	# Ensure sanctum dict exists
	if not save.has("sanctum") or typeof(save["sanctum"]) != TYPE_DICTIONARY:
		save["sanctum"] = {}
	var sanctum: Dictionary = save["sanctum"]
	
	if not sanctum.has("roster") or typeof(sanctum["roster"]) != TYPE_ARRAY:
		sanctum["roster"] = []

	var roster: Array = sanctum["roster"] as Array
	
	# Deterministic starter Echo (no placeholder)
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}

	var seed_path := "campaign.starter.0"

	# NOTE: EchoFactory leaves "id" blank on purpose (id is assigned by caller)
	var echo: Dictionary = EchoFactory.generate(
		seed_root,
		seed_path,
		0,
		"starter",
		summ_cfg
	)

	# Assign stable id outside factory (does NOT affect determinism)
	var echo_id := "echo_%04d" % (roster.size() + 1)
	echo["id"] = echo_id

	roster.append(echo)
	sanctum["starter_granted"] = true

	logger.info(t, "sanctum.starter.grant", "Starter Echo granted", {
		"echo_id": echo_id,
		"seed_path": seed_path,
		"seed_root": seed_root
	})

	# Install save into runtime + rebuild economy service
	flow_ctx.save_data = save
	econ = EconomyService.new(flow_ctx.save_data)

	# Request save flush via Flow-owned choke point
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|flow.new_game"
	else:
		flow_ctx.save_request_reason = "flow.new_game"

	# IMPORTANT: no transition has occurred yet when this runs, so refresh snapshot after mutation
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# Helpers
func _handle_debug_seed_show(t: int) -> void:
	var camp: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]

	var seed_root := str(camp.get("seed_root", ""))
	var seed_source := str(camp.get("seed_source", ""))
	var root_seed := int(camp.get("root_seed", 0))

	logger.info(t, "debug.seed.show", "Seed show", {
		"seed_root": seed_root,
		"seed_source": seed_source,
		"root_seed": root_seed
	})

	# Refresh is optional, but harmless and keeps UI consistent if you display seed-derived hints.
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_debug_seed_set(action: Dictionary, t: int, do_reset: bool) -> void:
	var seed_root := str(action.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "debug.seed.denied", "Denied seed set/reset (empty seed_root)", {})
		return

	# Ensure campaign dict exists
	if not flow_ctx.save_data.has("campaign") or typeof(flow_ctx.save_data["campaign"]) != TYPE_DICTIONARY:
		flow_ctx.save_data["campaign"] = {}
	var camp: Dictionary = flow_ctx.save_data["campaign"]

	# Update canonical seed fields
	camp["seed_root"] = seed_root
	camp["seed_source"] = "debug"

	# Keep legacy root_seed in sync for current systems (e.g., sanctum name suggestion)
	camp["root_seed"] = _legacy_root_seed_from_seed_root(seed_root)

	# Reset sanctum data if requested
	if do_reset:
		if not flow_ctx.save_data.has("sanctum") or typeof(flow_ctx.save_data["sanctum"]) != TYPE_DICTIONARY:
			flow_ctx.save_data["sanctum"] = {}
		var sanctum: Dictionary = flow_ctx.save_data["sanctum"]

		# Reset everything test-relevant
		sanctum["name"] = ""
		sanctum["name_roll_index"] = 0
		sanctum["roster"] = []
		sanctum["active_party_ids"] = []
		sanctum["summon_count"] = 0
		sanctum["starter_granted"] = false

		logger.info(t, "debug.seed.reset", "Seed reset applied", {
			"seed_root": seed_root,
			"root_seed": int(camp.get("root_seed", 0))
		})
	else:
		logger.info(t, "debug.seed.set", "Seed set applied", {
			"seed_root": seed_root,
			"root_seed": int(camp.get("root_seed", 0))
		})

	# Save once via Flow-owned choke point
	flow_ctx.save_request = true
	var reason := "debug.seed.reset" if do_reset else "debug.seed.set"
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|" + reason
	else:
		flow_ctx.save_request_reason = reason

	# IMPORTANT: no flow transition occurs, so refresh snapshot immediately
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _generate_seed_root_string() -> String:
	# Dev-safe randomness: allowed only as an input at New Game.
	# Uses OS crypto bytes, not global RNG.
	var crypto := Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(16)
	return bytes.hex_encode()

func _legacy_root_seed_from_seed_root(seed_root: String) -> int:
	# Temporary compatibility: several MVP systems still use CampaignSeed(int).
	# Derive a deterministic int from the first 8 hex chars (32-bit).
	if seed_root.length() < 8:
		return 0
	var prefix := seed_root.substr(0, 8)
	# Parse as hex via "0x" prefix
	return int("0x" + prefix)

func _handle_debug_echo_gen_test(t: int) -> void:
	# Pull seed_root from save
	var camp: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]

	var seed_root := str(camp.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "debug.echo.gen_test.denied", "Denied echo gen test (missing seed_root)", {})
		return

	# Pull summoning config from balance.json
	var balance := config_service.get_balance()
	var data_v : Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v : Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}

	# Generate same path twice
	var path0 := "campaign.summon.0"
	var e1: Dictionary = EchoFactory.generate(seed_root, path0, 0, "summon", summ_cfg)
	var e2: Dictionary = EchoFactory.generate(seed_root, path0, 0, "summon", summ_cfg)

	# Generate different path
	var path1 := "campaign.summon.1"
	var e3: Dictionary = EchoFactory.generate(seed_root, path1, 1, "summon", summ_cfg)

	var fp1 := _echo_fingerprint(e1)
	var fp2 := _echo_fingerprint(e2)
	var fp3 := _echo_fingerprint(e3)

	logger.info(t, "debug.echo.gen_test", "EchoFactory determinism test", {
		"seed_root": seed_root,
		"path_a": path0,
		"path_b": path1,
		"fingerprint_1": fp1,
		"fingerprint_2": fp2,
		"fingerprint_3": fp3,
		"same_path_equal": fp1 == fp2,
		"diff_path_differs": fp1 != fp3,
	})

	# No state transition: refresh snapshot so UI/debug panels remain in sync
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _echo_fingerprint(e: Dictionary) -> String:
	# Stable, human-readable digest for determinism checks.
	# Do NOT include id (caller assigns it).
	var name := str(e.get("name", ""))
	var gender := str(e.get("gender", ""))
	var rarity := str(e.get("rarity", ""))
	var calling := str(e.get("calling_origin", ""))
	var arch := str(e.get("archetype_birth", ""))
	var traits_v : Variant = e.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	var stats_v : Variant = e.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}

	return "%s|%s|%s|%s|%s|c%dw%df%d|hp%datk%ddef%dagi%dint%dcha%d" % [
		name,
		gender,
		rarity,
		calling,
		arch,
		int(traits.get("courage", 0)),
		int(traits.get("wisdom", 0)),
		int(traits.get("faith", 0)),
		int(stats.get("max_hp", 0)),
		int(stats.get("atk", 0)),
		int(stats.get("def", 0)),
		int(stats.get("agi", 0)),
		int(stats.get("int", 0)),
		int(stats.get("cha", 0)),
	]

func _handle_economy_settle_time(action: Dictionary, t: int) -> void:
	var now_unix := int(action.get("now_unix", 0))
	var source := str(action.get("source", ""))
	
	if now_unix <= 0:
		logger.info(t, "economy.time_anomaly", "Denied settle (invalid now_unix)", {
			"now_unix": now_unix,
			"source": source
		})
		return
		
	# Ensure economy dict exists
	if not flow_ctx.save_data.has("economy") or not (flow_ctx.save_data["economy"] is Dictionary):
		logger.info(t, "economy.settle.denied", "No economy data in save", {
			"source": source
		})
		return
		
	var econ_data := flow_ctx.save_data["economy"] as Dictionary
	var last_settle := int(econ_data.get("last_settle_unix", now_unix))
	
	var raw_delta := now_unix - last_settle
	var delta_seconds := raw_delta
	
	# Clamp policy (MVP)
	var clamped_negative := false
	var clamped_cap := false
	
	if delta_seconds < 0:
		delta_seconds = 0
		clamped_negative = true
		
	var max_delta_seconds := _get_max_online_settle_delta_seconds()
	if delta_seconds > max_delta_seconds:
		delta_seconds = max_delta_seconds
		clamped_cap = true
	
	var note := ""
	if clamped_cap:
		note = "delta clamped to cap (likely boot catch-up; not offline accrual)"
	elif clamped_negative:
		note = "negative delta clamped to 0"
	
	# Read balance knobs
	var econ_cfg := _get_balance_economy_cfg()
	var ase_per_min := float(econ_cfg.get("ase_online_per_min_base", 0.0))
	var rate_per_sec := ase_per_min / 60.0
	
	# Multiplier seam (Faith later) - optional input, default 1.0
	var multiplier := float(action.get("multiplier", 1.0))
	
	# Compute gain
	var gain := EconomyAccrualService.compute_online_settle_gain(delta_seconds, rate_per_sec, multiplier)
	
	var settle_reason := "economy.settle_time.normal"
	if clamped_cap:
		settle_reason = "economy.settle_time.catch_up"
	elif clamped_negative:
		settle_reason = "economy.settle_time.anomaly"

	# Apply via EconomyService (keep logging cnetralized there)
	if gain > 0:
		# Replace this call with your EconomyService signature if different.
		econ.add_ase(gain, settle_reason, logger, t)
	
	# Update settle guard even if gain=0 (prevents re-settling same window)
	econ_data["last_settle_unix"] = now_unix
	
	# Structured settle log (Core truth)
	var settle_msg := "Ase settled"
	if clamped_cap:
		settle_msg = "Ase settled (clamped)"
	elif clamped_negative:
		settle_msg = "Ase settled (time anomaly)"

	logger.debug(t, "economy.settle", settle_msg, {
		"source": source,
		"now_unix": now_unix,
		"last_settle_unix_before": last_settle,
		"raw_delta_seconds": raw_delta,
		"delta_seconds_used": delta_seconds,
		"clamped_negative": clamped_negative,
		"clamped_cap": clamped_cap,
		"cap_seconds": max_delta_seconds,
		"note": note,
		"ase_per_min_base": ase_per_min,
		"multiplier": multiplier,
		"gain": gain,
		"ase_after": int(econ_data.get("ase", 0)),
	})
	
	# IMPORTANT: settle_time can occur without a flow transition (e.g., Sanctum bank interval),
	# so we must refresh snapshot so UI updates immediately.
	flow_machine.refresh_snapshot(flow_ctx, logger, t)
	
func _apply_offline_accrual_if_needed(t: int, source: String) -> int:
	# Offline accrual must only happen when the player enters the session (flow.continue),
	# not on boot/splash/menu. Uses OS time only here.
	var now_unix := int(Time.get_unix_time_from_system())

	# Ensure economy dict exists
	if not flow_ctx.save_data.has("economy") or not (flow_ctx.save_data["economy"] is Dictionary):
		flow_ctx.save_data["economy"] = {}
	var econ_data := flow_ctx.save_data["economy"] as Dictionary

	var last_offline := int(econ_data.get("last_offline_unix", now_unix))
	var raw_delta := now_unix - last_offline

	# Nothing to do (or suspicious backwards time)
	if raw_delta <= 0:
		if raw_delta < 0:
			logger.info(t, "economy.time_anomaly", "Offline accrual denied (time went backwards)", {
				"source": source,
				"now_unix": now_unix,
				"last_offline_unix": last_offline,
				"raw_delta_seconds": raw_delta
			})
		else:
			logger.debug(t, "economy.offline.skip", "Offline accrual skipped (no elapsed time)", {
				"source": source,
				"now_unix": now_unix,
				"last_offline_unix": last_offline,
				"raw_delta_seconds": raw_delta
			})
		return 0

	# Read balance knobs
	var econ_cfg := _get_balance_economy_cfg()
	var ase_per_min := float(econ_cfg.get("ase_online_per_min_base", 0.0))
	var rate_per_sec := ase_per_min / 60.0

	var offline_start_factor := float(econ_cfg.get("offline_start_factor", 0.5))
	var offline_cap_seconds := int(econ_cfg.get("offline_cap_seconds", 28800))

	# Clamp forward jumps to cap (anti-cheat MVP)
	var delta_seconds := raw_delta
	var clamped_cap := false
	if offline_cap_seconds > 0 and delta_seconds > offline_cap_seconds:
		delta_seconds = offline_cap_seconds
		clamped_cap = true

	# Multiplier seam (Faith later). Economy stays emotion-agnostic.
	var multiplier := 1.0

	var ase_before := int(econ_data.get("ase", 0))

	var gain := EconomyAccrualService.compute_offline_gain(
		delta_seconds,
		rate_per_sec,
		multiplier,
		offline_start_factor,
		offline_cap_seconds
	)

	# Apply via EconomyService (centralizes ledger logs)
	if gain > 0:
		econ.add_ase(gain, "economy.offline_accrual", logger, t)
		logger.debug(t, "economy.offline.apply", "Offline accrual applied", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix_before": last_offline,
			"raw_delta_seconds": raw_delta,
			"delta_seconds_used": delta_seconds,
			"clamped_cap": clamped_cap,
			"offline_start_factor": offline_start_factor,
			"offline_cap_seconds": offline_cap_seconds,
			"ase_per_min_base": ase_per_min,
			"multiplier": multiplier,
			"gain": gain,
			"ase_before": ase_before,
			"ase_after": int(econ_data.get("ase", 0)),
		})
	else:
		logger.debug(t, "economy.offline.noop", "Offline accrual no-op", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix_before": last_offline,
			"raw_delta_seconds": raw_delta,
			"delta_seconds_used": delta_seconds,
			"clamped_cap": clamped_cap,
			"offline_start_factor": offline_start_factor,
			"offline_cap_seconds": offline_cap_seconds,
			"ase_per_min_base": ase_per_min,
			"multiplier": multiplier,
			"gain": gain,
		})

	# Update guards ONLY here (so we don't re-award next launch)
	econ_data["last_offline_unix"] = now_unix

	# Also reset last_settle_unix so online settle doesn't mint a "catch-up" window after continue
	econ_data["last_settle_unix"] = now_unix

	# Persist via Flow boundary save policy (sanctioned boundary)
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|economy.offline_accrual"
	else:
		flow_ctx.save_request_reason = "economy.offline_accrual"
	
	return gain
	
func _get_balance_economy_cfg() -> Dictionary:
	var balance := config_service.get_balance()
	if balance.is_empty():
		return {}

	var data_v = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var econ_v = data.get("economy", {})
	var econ_cfg: Dictionary = econ_v as Dictionary if econ_v is Dictionary else {}

	return econ_cfg
	
func _get_max_online_settle_delta_seconds() -> int:
	# Online settle guard. Offline accrual has its own capped window.
	return 3600 # 1 hour
	
func get_save_data() -> Dictionary:
	return flow_ctx.save_data

func get_tick() -> int:
	return int(flow_ctx.sim_tick)

func _ensure_encounter_started(t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.ENCOUNTER:
		return
	if flow_ctx.encounter_ctx == null:
		return
	if flow_ctx.encounter_machine == null:
		return
	if not flow_ctx.encounter_ctx.phase_snapshot.is_empty():
		return
	flow_ctx.encounter_machine.start(flow_ctx.encounter_ctx, logger, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _log_snapshot_emitted(t: int, snapshot: Dictionary, reason: String) -> void:
	logger.debug(t, "snapshot.emitted", "Snapshot emitted", {
		"reason": reason,
		"snapshot_type": str(snapshot.get("type", "")),
	})
