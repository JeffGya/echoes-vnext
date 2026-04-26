# res://core/sanctum/VowService.gd
# VOW-001: Pure-static vow logic.
# No state, no Node inheritance, no RNG, no OS time.
# All functions receive data in and return data out.
# Only pledge_vow, break_vow, release_vow, and unlock_vow mutate save_data.

class_name VowService
extends RefCounted

const _KEY_SANCTUM    := "sanctum"
const _KEY_ACTIVE_VOW := "active_vow"
const _KEY_UNLOCKED   := "vows"  # V2-MIG-002: canonical Dict (keyed by vow_id). Was: "unlocked_vows" Array.

# ---------------------------------------------------------------------------
# Read API
# ---------------------------------------------------------------------------

## Returns the vow definitions dict from balance config, or {} if missing.
static func get_definitions(cfg: Dictionary) -> Dictionary:
	var data_v: Variant = cfg.get("data", {})
	if not (data_v is Dictionary):
		return {}
	var data: Dictionary = data_v
	var vows_v: Variant = data.get("vows", {})
	if not (vows_v is Dictionary):
		return {}
	var vows: Dictionary = vows_v
	var defs_v: Variant = vows.get("definitions", {})
	if not (defs_v is Dictionary):
		return {}
	return defs_v


## Returns the active vow dict from save, or {} if none is set.
static func get_active_vow(save_data: Dictionary) -> Dictionary:
	var sanctum_v: Variant = save_data.get(_KEY_SANCTUM, {})
	if not (sanctum_v is Dictionary):
		return {}
	var sanctum: Dictionary = sanctum_v
	var av_v: Variant = sanctum.get(_KEY_ACTIVE_VOW, {})
	if not (av_v is Dictionary):
		return {}
	return av_v


## Returns the vows dict from save: { vow_id: { tier, discovered_realm } } or {} if none.
static func get_unlocked_vows(save_data: Dictionary) -> Dictionary:
	var sanctum_v: Variant = save_data.get(_KEY_SANCTUM, {})
	if not (sanctum_v is Dictionary):
		return {}
	var sanctum: Dictionary = sanctum_v
	var uv_v: Variant = sanctum.get(_KEY_UNLOCKED, {})
	if not (uv_v is Dictionary):
		return {}
	return uv_v


## Returns true if vow_id has been unlocked and the requested tier is within its unlocked tier.
static func is_tier_available(vow_id: String, tier: int, save_data: Dictionary) -> bool:
	var unlocked := get_unlocked_vows(save_data)
	var entry_v: Variant = unlocked.get(vow_id, {})
	if not (entry_v is Dictionary):
		return false
	var entry: Dictionary = entry_v
	return tier <= int(entry.get("tier", 0))


## Returns a vow definition enriched with UI display fields, or {} if not found.
## Enriched fields: vow_id, proverb_twi, proverb_en, vow_name, benefit_label,
##   tradeoff_label, tier_effects, breaking_costs, unlock_scenario, unlock_description.
static func get_definition(vow_id: String, cfg: Dictionary) -> Dictionary:
	var defs := get_definitions(cfg)
	var def_v: Variant = defs.get(vow_id, {})
	if not (def_v is Dictionary):
		return {}
	return def_v


# ---------------------------------------------------------------------------
# Write API
# ---------------------------------------------------------------------------

## Pledges a vow at the given tier. Sets save_request on ctx.
## Returns true on success, false if vow is locked or a vow is already active.
## Signature: pledge_vow(vow_id, tier, save_data, ctx, logger, t) -> bool
static func pledge_vow(
	vow_id: String,
	tier: int,
	cfg: Dictionary,
	save_data: Dictionary,
	ctx: RefCounted,
	logger: StructuredLogger,
	t: int
) -> bool:
	# Guard: vow must be unlocked at this tier
	if not is_tier_available(vow_id, tier, save_data):
		if logger:
			logger.debug(t, "vow.pledge_denied", "Vow not available at tier", {
				"vow_id": vow_id, "tier": tier
			})
		return false

	# Guard: no vow already active
	var current := get_active_vow(save_data)
	if not current.is_empty():
		if logger:
			logger.debug(t, "vow.pledge_denied", "Cannot pledge: vow already active", {
				"vow_id": vow_id, "active_vow_id": str(current.get("vow_id", ""))
			})
		return false

	# Guard: definition must exist
	var defn := get_definition(vow_id, cfg)
	if defn.is_empty():
		if logger:
			logger.debug(t, "vow.pledge_denied", "Vow definition not found", { "vow_id": vow_id })
		return false

	# Persist
	var sanctum := _ensure_sanctum(save_data)
	var realm_id := str(ctx.get("realm_id") if ctx != null else "")

	# Count total realm runs completed so far. Used to detect completion when pledged outside a realm.
	var runs_at_pledge := 0
	var realms_v: Variant = save_data.get("realms", {})
	if realms_v is Dictionary:
		var realms_d: Dictionary = realms_v
		for rid in realms_d:
			var rm_v: Variant = realms_d[rid]
			if rm_v is Dictionary:
				runs_at_pledge += int((rm_v as Dictionary).get("run_count", 0))

	sanctum[_KEY_ACTIVE_VOW] = {
		"vow_id":           vow_id,
		"tier":             tier,
		"pledged_at_realm": realm_id,
		"runs_at_pledge":   runs_at_pledge,
	}

	_set_save_request(ctx, "vow.pledge")

	if logger:
		logger.info(t, "vow.pledged", "Vow pledged", {
			"vow_id": vow_id,
			"tier": tier,
			"proverb_twi": str(defn.get("proverb_twi", "")),
			"pledged_at_realm": realm_id,
		})

	return true


## Checks release conditions and calls release_vow() if met. Returns true if released.
## Called on every flow.sanctum enter. Two conditions:
##   pledged_at_realm != "" → release once that realm is no longer STATUS_ACTIVE.
##   pledged_at_realm == "" → release once total run_count across all realms > runs_at_pledge.
static func release_vow_if_due(
	save_data: Dictionary,
	ctx: RefCounted,
	logger: StructuredLogger,
	t: int
) -> bool:
	var av := get_active_vow(save_data)
	if av.is_empty():
		return false

	var pledged_realm := str(av.get("pledged_at_realm", ""))
	var realms_v: Variant = save_data.get("realms", {})
	var should_release := false

	if pledged_realm != "":
		# Pledged during a realm — release once that realm is no longer active.
		if realms_v is Dictionary:
			var realm_entry_v: Variant = (realms_v as Dictionary).get(pledged_realm, {})
			if realm_entry_v is Dictionary:
				var still_active := str((realm_entry_v as Dictionary).get("status", "")) == "active"
				should_release = not still_active
			else:
				should_release = true  # realm no longer exists — release
	else:
		# Pledged from Sanctum — release once total completed runs exceeds runs_at_pledge.
		var runs_at_pledge := int(av.get("runs_at_pledge", 0))
		var current_runs := 0
		if realms_v is Dictionary:
			for rid in (realms_v as Dictionary):
				var rm_v: Variant = (realms_v as Dictionary)[rid]
				if rm_v is Dictionary:
					current_runs += int((rm_v as Dictionary).get("run_count", 0))
		should_release = current_runs > runs_at_pledge

	if should_release:
		release_vow(save_data, ctx, logger, t)
		return true

	return false


## Releases the active vow with no penalty (natural end of a realm run).
## Sets save_request on ctx.
static func release_vow(
	save_data: Dictionary,
	ctx: RefCounted,
	logger: StructuredLogger,
	t: int
) -> void:
	var current := get_active_vow(save_data)
	if current.is_empty():
		return

	var vow_id := str(current.get("vow_id", ""))
	var sanctum := _ensure_sanctum(save_data)
	sanctum[_KEY_ACTIVE_VOW] = {}

	_set_save_request(ctx, "vow.release")

	if logger:
		logger.info(t, "vow.released", "Vow released (realm completed)", {
			"vow_id": vow_id,
			"realm_completed": true,
		})


## Breaks the active vow deliberately. Applies tier-appropriate penalties.
## Returns a penalty_summary dict: { vow_id, tier, ase_spent, ekwan_spent, morale_delta,
##   fear_delta, bond_score_delta, bonds_affected }.
## Caller is responsible for applying morale/fear deltas via EmotionService if needed.
## Sets save_request on ctx.
static func break_vow(
	cfg: Dictionary,
	save_data: Dictionary,
	ctx: RefCounted,
	econ: EconomyService,
	logger: StructuredLogger,
	t: int
) -> Dictionary:
	var current := get_active_vow(save_data)
	if current.is_empty():
		if logger:
			logger.debug(t, "vow.break_denied", "No active vow to break", {})
		return {}

	var vow_id := str(current.get("vow_id", ""))
	var tier   := int(current.get("tier", 1))

	var defn := get_definition(vow_id, cfg)
	var costs := _get_breaking_costs(defn, tier)

	var ase_cost    := int(costs.get("ase", 0))
	var ekwan_cost  := int(costs.get("ekwan", 0))
	var morale_d    := int(costs.get("morale_delta", 0))
	var fear_d      := int(costs.get("fear_delta", 0))
	var bond_d      := int(costs.get("bond_score_delta", 0))

	# Economy penalties — spend what we can (clamp to zero if broke)
	if econ != null and ase_cost > 0:
		econ.spend_ase(ase_cost, "vow.break", logger, t)
	if econ != null and ekwan_cost > 0:
		econ.spend_ekwan(ekwan_cost, "vow.break", logger, t)

	# Bond penalties — apply delta to all active bond edges
	var bonds_affected: Array = []
	if bond_d != 0:
		var sanctum_v: Variant = save_data.get(_KEY_SANCTUM, {})
		if sanctum_v is Dictionary:
			var sanctum: Dictionary = sanctum_v
			var bonds_v: Variant = sanctum.get("bonds", [])
			if bonds_v is Array:
				var bonds: Array = bonds_v
				var thresholds: Dictionary = _get_bond_thresholds(cfg)
				var edges_before := bonds.size()
				for edge_v in bonds:
					if not (edge_v is Dictionary):
						continue
					var edge: Dictionary = edge_v
					var a := str(edge.get("actor_a", ""))
					var b := str(edge.get("actor_b", ""))
					if a != "" and b != "":
						bonds = SocialGraphService.apply_score_delta(
							bonds, a, b, bond_d, thresholds, logger, t
						)
						bonds_affected.append([a, b])
				sanctum["bonds"] = bonds
				if logger and bonds_affected.size() > 0:
					logger.debug(t, "vow.break.bonds_penalised", "Bond edges penalised on vow break", {
						"vow_id": vow_id,
						"bond_delta": bond_d,
						"edges_affected": bonds_affected.size()
					})

	# Clear the active vow
	var sanctum2 := _ensure_sanctum(save_data)
	sanctum2[_KEY_ACTIVE_VOW] = {}

	_set_save_request(ctx, "vow.break")

	var summary := {
		"vow_id":           vow_id,
		"tier":             tier,
		"ase_spent":        ase_cost,
		"ekwan_spent":      ekwan_cost,
		"morale_delta":     morale_d,
		"fear_delta":       fear_d,
		"bond_score_delta": bond_d,
		"bonds_affected":   bonds_affected,
	}

	if logger:
		logger.info(t, "vow.broken", "Vow broken deliberately", {
			"vow_id":        vow_id,
			"tier":          tier,
			"penalty_summary": summary,
		})

	return summary


## Unlocks a vow for the Keeper (from a scenario trigger).
## If already unlocked, no-op (tier unlock ceiling handled in VOW-003+).
## Sets save_request on ctx.
static func unlock_vow(
	vow_id: String,
	discovered_realm: String,
	save_data: Dictionary,
	ctx: RefCounted,
	logger: StructuredLogger,
	t: int
) -> void:
	var sanctum := _ensure_sanctum(save_data)
	var unlocked_v: Variant = sanctum.get(_KEY_UNLOCKED, {})
	var unlocked: Dictionary = unlocked_v if unlocked_v is Dictionary else {}

	# Check if already unlocked — no-op for VOW-001
	if unlocked.has(vow_id):
		return

	# Add new unlock entry keyed by vow_id
	unlocked[vow_id] = {
		"tier":             1,  # VOW-001: all vows start at tier 1 ceiling
		"discovered_realm": discovered_realm,
	}
	sanctum[_KEY_UNLOCKED] = unlocked

	_set_save_request(ctx, "vow.unlock")

	if logger:
		logger.info(t, "vow.unlocked", "Vow revealed to Keeper", {
			"vow_id":           vow_id,
			"discovered_realm": discovered_realm,
		})


# ---------------------------------------------------------------------------
# Condition evaluation API (pure — no side effects, no save mutations)
# ---------------------------------------------------------------------------

## Evaluates the active vow's stage-entry condition.
## Returns { "status": "none"/"compliant"/"violated", "morale_delta": int, "fear_delta": int,
##           "should_auto_break": bool }
## Caller is responsible for applying deltas via EmotionService and calling break_vow if flagged.
## MUTATES active_vow dict in save_data to track consecutive violation count (requires save flush).
static func evaluate_stage_condition(
	save_data:       Dictionary,
	party_echo_ids:  Array,
	cfg:             Dictionary
) -> Dictionary:
	var av := get_active_vow(save_data)
	if av.is_empty():
		return { "status": "none", "morale_delta": 0, "fear_delta": 0, "should_auto_break": false }

	var vow_id := str(av.get("vow_id", ""))
	var tier   := int(av.get("tier", 1))
	var defn   := get_definition(vow_id, cfg)
	if defn.is_empty():
		return { "status": "none", "morale_delta": 0, "fear_delta": 0, "should_auto_break": false }

	var tier_mul := _get_tier_multiplier(defn, tier)

	match vow_id:
		"tikoro_nko_agyina":
			return _eval_tikoro_nko_agyina(av, save_data, party_echo_ids, defn, tier_mul)
		"praye_wokabomu":
			return _eval_praye_wokabomu(av, save_data, party_echo_ids, defn, tier_mul, cfg)
		_:
			return { "status": "none", "morale_delta": 0, "fear_delta": 0, "should_auto_break": false }


## Evaluates the active vow's condition when a situation is engaged.
## Returns { "status": "none"/"compliant"/"violated", "morale_delta": int, "fear_delta": int,
##           "should_auto_break": bool }
## MUTATES active_vow dict in save_data to track blind engagement count (requires save flush).
static func evaluate_engage_condition(
	save_data:  Dictionary,
	situation:  Dictionary,
	stage_id:   String,
	cfg:        Dictionary
) -> Dictionary:
	var av := get_active_vow(save_data)
	if av.is_empty():
		return { "status": "none", "morale_delta": 0, "fear_delta": 0, "should_auto_break": false }

	var vow_id := str(av.get("vow_id", ""))
	var tier   := int(av.get("tier", 1))
	var defn   := get_definition(vow_id, cfg)
	if defn.is_empty():
		return { "status": "none", "morale_delta": 0, "fear_delta": 0, "should_auto_break": false }

	var tier_mul := _get_tier_multiplier(defn, tier)

	match vow_id:
		"obi_nnim_kyere":
			return _eval_obi_nnim_kyere_engage(av, save_data, situation, stage_id, defn, tier_mul)
		_:
			return { "status": "none", "morale_delta": 0, "fear_delta": 0, "should_auto_break": false }


## Evaluates the active vow's post-stage completion benefit.
## Returns { "morale_delta": int, "fear_delta": int }
## Pure — no save mutations.
static func evaluate_stage_complete_benefit(
	save_data:  Dictionary,
	situations: Array,
	cfg:        Dictionary
) -> Dictionary:
	var av := get_active_vow(save_data)
	if av.is_empty():
		return { "morale_delta": 0, "fear_delta": 0 }

	var vow_id := str(av.get("vow_id", ""))
	var tier   := int(av.get("tier", 1))
	var defn   := get_definition(vow_id, cfg)
	if defn.is_empty():
		return { "morale_delta": 0, "fear_delta": 0 }

	var tier_mul := _get_tier_multiplier(defn, tier)

	match vow_id:
		"obi_nnim_kyere":
			return _eval_obi_nnim_kyere_complete(situations, defn, tier_mul)
		_:
			return { "morale_delta": 0, "fear_delta": 0 }


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _ensure_sanctum(save_data: Dictionary) -> Dictionary:
	if not save_data.has(_KEY_SANCTUM) or not (save_data[_KEY_SANCTUM] is Dictionary):
		save_data[_KEY_SANCTUM] = {}
	return save_data[_KEY_SANCTUM]


static func _set_save_request(ctx: RefCounted, reason: String) -> void:
	if ctx == null:
		return
	if ctx.get("save_request") != null:
		ctx.set("save_request", true)
	if ctx.get("save_request_reason") != null:
		var existing := str(ctx.get("save_request_reason"))
		if existing != "":
			ctx.set("save_request_reason", existing + "|" + reason)
		else:
			ctx.set("save_request_reason", reason)


static func _get_breaking_costs(defn: Dictionary, tier: int) -> Dictionary:
	var costs_v: Variant = defn.get("breaking_costs", {})
	if not (costs_v is Dictionary):
		return {}
	var costs: Dictionary = costs_v
	var tier_key := str(tier)
	var tier_v: Variant = costs.get(tier_key, {})
	if not (tier_v is Dictionary):
		return {}
	return tier_v


static func _get_bond_thresholds(cfg: Dictionary) -> Dictionary:
	var data_v: Variant = cfg.get("data", {})
	if not (data_v is Dictionary):
		return {}
	var data: Dictionary = data_v
	var bond_v: Variant = data.get("bonds", {})
	if not (bond_v is Dictionary):
		return {}
	var bonds: Dictionary = bond_v
	return {
		"friend_min": int(bonds.get("friend_min", 30)),
		"rival_max":  int(bonds.get("rival_max", -30)),
	}


static func _get_tier_multiplier(defn: Dictionary, tier: int) -> float:
	var te_v: Variant = defn.get("tier_effects", {})
	if not (te_v is Dictionary):
		return 1.0
	var te: Dictionary = te_v
	var t_v: Variant = te.get(str(tier), {})
	if not (t_v is Dictionary):
		return 1.0
	return float((t_v as Dictionary).get("multiplier", 1.0))


## tikoro_nko_agyina — stage-entry party size check.
static func _eval_tikoro_nko_agyina(
	active_vow:    Dictionary,
	save_data:     Dictionary,
	party_ids:     Array,
	defn:          Dictionary,
	tier_mul:      float
) -> Dictionary:
	var benefit_v: Variant = defn.get("benefit", {})
	var benefit: Dictionary = benefit_v if benefit_v is Dictionary else {}
	var tradeoff_v: Variant = defn.get("tradeoff", {})
	var tradeoff: Dictionary = tradeoff_v if tradeoff_v is Dictionary else {}

	var threshold := int(benefit.get("party_size_threshold", 3))
	var party_size := party_ids.size()

	# Mutate active_vow to track consecutive violations (caller must flush save).
	var sanctum := _ensure_sanctum(save_data)
	var av_mut: Dictionary = sanctum.get("active_vow", {})

	if party_size >= threshold:
		av_mut["consecutive_small_deployments"] = 0
		sanctum["active_vow"] = av_mut
		var morale_bonus := roundi(float(benefit.get("morale_bonus_on_entry", 5)) * tier_mul)
		return {
			"status":           "compliant",
			"morale_delta":     morale_bonus,
			"fear_delta":       0,
			"should_auto_break": false,
		}
	else:
		var streak: int = int(av_mut.get("consecutive_small_deployments", 0)) + 1
		av_mut["consecutive_small_deployments"] = streak
		sanctum["active_vow"] = av_mut
		var fear_pen := roundi(float(tradeoff.get("small_party_fear_penalty", 10)) * tier_mul)
		return {
			"status":            "violated",
			"morale_delta":      0,
			"fear_delta":        fear_pen,
			"should_auto_break": streak >= 2,
		}


## praye_wokabomu — stage-entry calling diversity check.
static func _eval_praye_wokabomu(
	active_vow:    Dictionary,
	save_data:     Dictionary,
	party_ids:     Array,
	defn:          Dictionary,
	tier_mul:      float,
	cfg:           Dictionary
) -> Dictionary:
	var benefit_v: Variant = defn.get("benefit", {})
	var benefit: Dictionary = benefit_v if benefit_v is Dictionary else {}
	var tradeoff_v: Variant = defn.get("tradeoff", {})
	var tradeoff: Dictionary = tradeoff_v if tradeoff_v is Dictionary else {}

	var threshold := int(benefit.get("calling_diversity_threshold", 2))

	# Count distinct calling_origin values among party echoes.
	var roster_v: Variant = save_data.get("sanctum", {})
	var calling_origins: Dictionary = {}
	if roster_v is Dictionary:
		var roster_arr_v: Variant = (roster_v as Dictionary).get("roster", [])
		if roster_arr_v is Array:
			for echo_v in (roster_arr_v as Array):
				if not (echo_v is Dictionary):
					continue
				var echo: Dictionary = echo_v
				if party_ids.has(str(echo.get("id", ""))):
					var co := str(echo.get("calling_origin", "uncalled"))
					calling_origins[co] = true

	var distinct_callings := calling_origins.size()

	var sanctum := _ensure_sanctum(save_data)
	var av_mut: Dictionary = sanctum.get("active_vow", {})

	if distinct_callings >= threshold:
		av_mut["consecutive_same_calling_deployments"] = 0
		sanctum["active_vow"] = av_mut
		var morale_bonus := roundi(float(benefit.get("morale_bonus_on_entry", 3)) * tier_mul)
		return {
			"status":            "compliant",
			"morale_delta":      morale_bonus,
			"fear_delta":        0,
			"should_auto_break": false,
		}
	else:
		var streak: int = int(av_mut.get("consecutive_same_calling_deployments", 0)) + 1
		av_mut["consecutive_same_calling_deployments"] = streak
		sanctum["active_vow"] = av_mut
		var fear_pen := roundi(float(tradeoff.get("single_calling_fear_penalty", 8)) * tier_mul)
		return {
			"status":            "violated",
			"morale_delta":      0,
			"fear_delta":        fear_pen,
			"should_auto_break": streak >= 2,
		}


## obi_nnim_kyere — situation-engagement revealed check.
static func _eval_obi_nnim_kyere_engage(
	active_vow:  Dictionary,
	save_data:   Dictionary,
	situation:   Dictionary,
	stage_id:    String,
	defn:        Dictionary,
	tier_mul:    float
) -> Dictionary:
	var benefit_v: Variant = defn.get("benefit", {})
	var benefit: Dictionary = benefit_v if benefit_v is Dictionary else {}
	var tradeoff_v: Variant = defn.get("tradeoff", {})
	var tradeoff: Dictionary = tradeoff_v if tradeoff_v is Dictionary else {}

	var sanctum := _ensure_sanctum(save_data)
	var av_mut: Dictionary = sanctum.get("active_vow", {})

	# Reset blind count when stage changes (new stage = fresh start).
	var tracked_stage := str(av_mut.get("blind_stage_id", ""))
	if tracked_stage != stage_id:
		av_mut["consecutive_blind_engagements"] = 0
		av_mut["blind_stage_id"] = stage_id

	var is_revealed := bool(situation.get("revealed", false))
	if is_revealed:
		sanctum["active_vow"] = av_mut
		var morale_bonus := roundi(float(benefit.get("revealed_engagement_morale_bonus", 3)) * tier_mul)
		return {
			"status":            "compliant",
			"morale_delta":      morale_bonus,
			"fear_delta":        0,
			"should_auto_break": false,
		}
	else:
		var streak: int = int(av_mut.get("consecutive_blind_engagements", 0)) + 1
		av_mut["consecutive_blind_engagements"] = streak
		sanctum["active_vow"] = av_mut
		var fear_pen := roundi(float(tradeoff.get("blind_engagement_fear_penalty", 8)) * tier_mul)
		return {
			"status":            "violated",
			"morale_delta":      0,
			"fear_delta":        fear_pen,
			"should_auto_break": streak >= 2,
		}


## obi_nnim_kyere — post-stage all-scouted benefit.
static func _eval_obi_nnim_kyere_complete(
	situations: Array,
	defn:       Dictionary,
	tier_mul:   float
) -> Dictionary:
	var benefit_v: Variant = defn.get("benefit", {})
	var benefit: Dictionary = benefit_v if benefit_v is Dictionary else {}

	# Bonus fires only if every situation was revealed before being engaged.
	var all_revealed := true
	for sit_v in situations:
		if not (sit_v is Dictionary):
			continue
		var sit: Dictionary = sit_v
		if not bool(sit.get("revealed", false)):
			all_revealed = false
			break

	if all_revealed and not situations.is_empty():
		var morale_bonus := roundi(float(benefit.get("full_scout_morale_bonus", 5)) * tier_mul)
		return { "morale_delta": morale_bonus, "fear_delta": 0 }

	return { "morale_delta": 0, "fear_delta": 0 }
