extends RefCounted

class_name InstitutionService

# ---- Constants ----

const HEARTH           := "hearth"
const TRAINING_GROUNDS := "training_grounds"
const ALL_INSTITUTIONS := [HEARTH, TRAINING_GROUNDS]

const CONDITION_HEALTHY   := "healthy"
const CONDITION_STRAINED  := "strained"
const CONDITION_NEGLECTED := "neglected"

const COMPAT_NATURAL := "natural_fit"
const COMPAT_COMPAT  := "compatible"
const COMPAT_POOR    := "poor_fit"

# ---- Unlock / query ----

static func is_candidate(inst_id: String, save_data: Dictionary, inst_cfg: Dictionary) -> bool:
	if is_unlocked(inst_id, save_data):
		return false
	var cfg: Dictionary = inst_cfg.get(inst_id, {}) as Dictionary
	if cfg.is_empty():
		return false
	var threshold := int(cfg.get("unlock_continuity_threshold", 999))
	var sanctum: Dictionary = _get_sanctum(save_data)
	var continuity := int(sanctum.get("continuity", 0))
	return continuity >= threshold


static func is_unlocked(inst_id: String, save_data: Dictionary) -> bool:
	var inst: Dictionary = _get_inst(inst_id, save_data)
	return bool(inst.get("unlocked", false))


static func get_condition(inst_id: String, save_data: Dictionary) -> String:
	if not is_unlocked(inst_id, save_data):
		return CONDITION_NEGLECTED
	var inst: Dictionary = _get_inst(inst_id, save_data)
	return str(inst.get("condition", CONDITION_NEGLECTED))


static func update_condition(inst_id: String, save_data: Dictionary, inst_cfg: Dictionary, now_unix: int, logger: StructuredLogger, t: int) -> void:
	if not is_unlocked(inst_id, save_data):
		return
	var inst: Dictionary = _get_inst(inst_id, save_data)
	var occupants: Array = inst.get("occupant_ids", []) as Array
	if occupants.is_empty():
		_set_condition(inst, CONDITION_NEGLECTED, inst_id, logger, t)
		return
	var last: int = int(inst.get("last_activated_unix", 0))
	var elapsed := now_unix - last if last > 0 else 0
	var healthy_max  := int(inst_cfg.get("healthy_max_elapsed_seconds",  3600))
	var strained_max := int(inst_cfg.get("strained_max_elapsed_seconds", 10800))
	var new_condition: String
	if elapsed <= healthy_max:
		new_condition = CONDITION_HEALTHY
	elif elapsed <= strained_max:
		new_condition = CONDITION_STRAINED
	else:
		new_condition = CONDITION_NEGLECTED
	_set_condition(inst, new_condition, inst_id, logger, t)
	inst["last_activated_unix"] = now_unix


# ---- Compatibility ----

static func compute_compatibility(echo: Dictionary, inst_id: String, inst_cfg: Dictionary) -> String:
	var cfg: Dictionary = inst_cfg.get(inst_id, {}) as Dictionary
	var primary_vectors: Array  = cfg.get("primary_vectors",  []) as Array
	var primary_callings: Array = cfg.get("primary_callings", []) as Array
	var dominant := str(echo.get("dominant_vector", ""))
	var calling   := str(echo.get("calling_origin",  ""))
	if not dominant.is_empty() and primary_vectors.has(dominant):
		return COMPAT_NATURAL
	if not calling.is_empty() and primary_callings.has(calling):
		return COMPAT_COMPAT
	return COMPAT_POOR


static func get_compatibility_hint(echo_name: String, inst_id: String, compat_tier: String, hints_cfg: Dictionary) -> String:
	var inst_hints: Dictionary = hints_cfg.get(inst_id, {}) as Dictionary
	var template: String = str(inst_hints.get(compat_tier, ""))
	if template.is_empty():
		return ""
	return template.replace("{name}", echo_name)


# ---- Actions ----

static func establish(inst_id: String, save_data: Dictionary, econ: EconomyService, inst_cfg: Dictionary, logger: StructuredLogger, t: int) -> bool:
	if not is_candidate(inst_id, save_data, inst_cfg):
		logger.info(t, "sanctum.institution.establish.blocked", "not a candidate", { "id": inst_id })
		return false
	var cost := int((inst_cfg.get(inst_id, {}) as Dictionary).get("establish_ekwan_cost", 10))
	if not econ.can_afford_ekwan(cost):
		logger.info(t, "sanctum.institution.establish.blocked", "insufficient ekwan", { "id": inst_id, "cost": cost })
		return false
	econ.spend_ekwan(cost, "institution.establish." + inst_id, logger, t)
	var inst: Dictionary = _get_inst(inst_id, save_data)
	inst["unlocked"]            = true
	inst["last_activated_unix"] = 0
	inst["condition"]           = CONDITION_NEGLECTED
	logger.info(t, "sanctum.institution.established", inst_id, { "id": inst_id, "ekwan_spent": cost })
	return true


static func assign_echo(inst_id: String, echo_id: String, save_data: Dictionary, econ: EconomyService, inst_cfg: Dictionary, logger: StructuredLogger, t: int) -> bool:
	if not is_unlocked(inst_id, save_data):
		return false
	var cfg: Dictionary = inst_cfg.get(inst_id, {}) as Dictionary
	var capacity := int(cfg.get("capacity", 4))
	var inst: Dictionary = _get_inst(inst_id, save_data)
	var occupants: Array = inst.get("occupant_ids", []) as Array
	if occupants.size() >= capacity:
		logger.info(t, "sanctum.institution.assign.blocked", "at capacity", { "id": inst_id })
		return false
	if find_institution_for_echo(echo_id, save_data) != "":
		logger.info(t, "sanctum.institution.assign.blocked", "echo already assigned", { "echo_id": echo_id })
		return false
	var assign_cost := int(cfg.get("assign_ase_cost", 5))
	if not econ.can_afford_ase(assign_cost):
		logger.info(t, "sanctum.institution.assign.blocked", "insufficient ase", { "echo_id": echo_id, "cost": assign_cost })
		return false
	# Auto-remove from active party if present
	var sanctum: Dictionary = _get_sanctum(save_data)
	var party_ids: Array = sanctum.get("active_party_ids", []) as Array
	if party_ids.has(echo_id):
		party_ids.erase(echo_id)
		sanctum["active_party_ids"] = party_ids
	econ.spend_ase(assign_cost, "institution.assign." + inst_id, logger, t)
	occupants.append(echo_id)
	inst["occupant_ids"] = occupants
	var compat := compute_compatibility(_find_echo(echo_id, save_data), inst_id, inst_cfg)
	logger.info(t, "sanctum.institution.echo_assigned", inst_id, { "id": inst_id, "echo_id": echo_id, "compat": compat })
	return true


static func remove_echo(inst_id: String, echo_id: String, save_data: Dictionary, econ: EconomyService, inst_cfg: Dictionary, logger: StructuredLogger, t: int) -> bool:
	if not is_unlocked(inst_id, save_data):
		return false
	var inst: Dictionary = _get_inst(inst_id, save_data)
	var occupants: Array = inst.get("occupant_ids", []) as Array
	if not occupants.has(echo_id):
		return false
	var cfg: Dictionary = inst_cfg.get(inst_id, {}) as Dictionary
	var unassign_cost := int(cfg.get("unassign_ekwan_cost", 3))
	if not econ.can_afford_ekwan(unassign_cost):
		logger.info(t, "sanctum.institution.remove.blocked", "insufficient ekwan", { "echo_id": echo_id, "cost": unassign_cost })
		return false
	econ.spend_ekwan(unassign_cost, "institution.unassign." + inst_id, logger, t)
	occupants.erase(echo_id)
	inst["occupant_ids"] = occupants
	# Drop condition one tier
	var old_cond := str(inst.get("condition", CONDITION_NEGLECTED))
	var new_cond: String
	if old_cond == CONDITION_HEALTHY:
		new_cond = CONDITION_STRAINED
	else:
		new_cond = CONDITION_NEGLECTED
	inst["condition"] = new_cond
	# Morale/fear hit if natural fit
	var echo: Dictionary = _find_echo(echo_id, save_data)
	if not echo.is_empty():
		var compat := compute_compatibility(echo, inst_id, inst_cfg)
		if compat == COMPAT_NATURAL:
			var morale_delta := int(inst_cfg.get("unassign_natural_fit_morale_delta", -5))
			var fear_delta   := int(inst_cfg.get("unassign_natural_fit_fear_delta",    5))
			if morale_delta != 0:
				EmotionService.apply_morale_delta(echo, morale_delta, "institution.unassign.natural_fit", logger, t)
			if fear_delta != 0:
				EmotionService.apply_fear_delta(echo, fear_delta, "institution.unassign.natural_fit", logger, t)
	logger.info(t, "sanctum.institution.echo_removed", inst_id, { "id": inst_id, "echo_id": echo_id, "condition_drop": old_cond + "->" + new_cond })
	return true


static func apply_institution_modifiers(save_data: Dictionary, bldg_cfg: Dictionary, inst_cfg: Dictionary, logger: StructuredLogger, t: int) -> void:
	var sanctum: Dictionary = _get_sanctum(save_data)
	var roster: Array = sanctum.get("roster", []) as Array
	for inst_id in ALL_INSTITUTIONS:
		if not is_unlocked(inst_id, save_data):
			continue
		var cond := get_condition(inst_id, save_data)
		if cond == CONDITION_NEGLECTED:
			continue
		var inst: Dictionary = _get_inst(inst_id, save_data)
		var occupants: Array = inst.get("occupant_ids", []) as Array
		var b_cfg: Dictionary = bldg_cfg.get(inst_id, {}) as Dictionary
		var mul_key  := "morale_mul_" + cond
		var fmul_key := "fear_mul_"   + cond
		var inst_morale := float(b_cfg.get(mul_key,  1.0))
		var inst_fear   := float(b_cfg.get(fmul_key, 1.0))
		var ticks := int(b_cfg.get("ticks", 4))
		for eid in occupants:
			var echo := _find_echo_in_roster(str(eid), roster)
			if echo.is_empty():
				continue
			var rm: Dictionary = echo.get("recovery_modifiers", {}) as Dictionary
			var existing_morale := float(rm.get("morale_multiplier", 1.0))
			var existing_fear   := float(rm.get("fear_multiplier",   1.0))
			EmotionRecoveryService.set_modifier(echo, existing_morale * inst_morale, existing_fear * inst_fear, ticks, logger, t)


# ---- Lookup helpers ----

static func find_institution_for_echo(echo_id: String, save_data: Dictionary) -> String:
	var institutions: Dictionary = _get_sanctum(save_data).get("institutions", {}) as Dictionary
	for inst_id in ALL_INSTITUTIONS:
		var inst_v: Variant = institutions.get(inst_id, null)
		if not (inst_v is Dictionary):
			continue
		var occupants: Array = (inst_v as Dictionary).get("occupant_ids", []) as Array
		if occupants.has(echo_id):
			return inst_id
	return ""


# ---- Snapshot data ----

static func get_snapshot_data(save_data: Dictionary, inst_cfg: Dictionary, _t: int) -> Array:
	var result: Array = []
	for inst_id in ALL_INSTITUTIONS:
		var inst: Dictionary = _get_inst(inst_id, save_data)
		result.append({
			"id":          inst_id,
			"unlocked":    bool(inst.get("unlocked", false)),
			"condition":   str(inst.get("condition", CONDITION_NEGLECTED)),
			"occupant_ids": inst.get("occupant_ids", []).duplicate(),
			"is_candidate": is_candidate(inst_id, save_data, inst_cfg),
		})
	return result


static func get_ground_data(save_data: Dictionary, inst_cfg: Dictionary, roster: Array, party_ids: Array, bonds: Array) -> Dictionary:
	var inst_visibility: Dictionary = {}
	var inst_conditions: Dictionary = {}
	for inst_id in ALL_INSTITUTIONS:
		inst_visibility[inst_id] = is_unlocked(inst_id, save_data)
		inst_conditions[inst_id] = get_condition(inst_id, save_data)
	var echo_slots: Array = []
	var slot_counters: Dictionary = { "hearth": 0, "training_grounds": 0, "party": 0, "roaming": 0 }
	# Build bond-pair map to help adjacency sorting: echo_id -> Array of bonded echo_ids in same zone
	var bond_map: Dictionary = {}
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var eid := str(echo.get("id", ""))
		if eid.is_empty():
			continue
		var zone := _zone_for_echo(eid, save_data, party_ids)
		var bonded_in_zone: Array = []
		for b_v in bonds:
			if not (b_v is Dictionary):
				continue
			var b: Dictionary = b_v
			var a_id := str(b.get("actor_a", ""))
			var b_id := str(b.get("actor_b", ""))
			var partner: String
			if a_id == eid:
				partner = b_id
			elif b_id == eid:
				partner = a_id
			else:
				continue
			var strength := int(b.get("strength", 0))
			if strength > 0 and _zone_for_echo(partner, save_data, party_ids) == zone:
				bonded_in_zone.append(partner)
		bond_map[eid] = bonded_in_zone
	# Assign slots — bonded echoes get adjacent indices
	var zone_queues: Dictionary = { "hearth": [], "training_grounds": [], "party": [], "roaming": [] }
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var eid := str(echo.get("id", ""))
		if eid.is_empty():
			continue
		var zone := _zone_for_echo(eid, save_data, party_ids)
		zone_queues[zone].append(eid)
	for zone_id in zone_queues:
		var queue: Array = zone_queues[zone_id] as Array
		var slot_idx := 0
		for eid in queue:
			var echo := _find_echo_in_roster(str(eid), roster)
			var emo_status := ""
			if not echo.is_empty():
				var emo: Dictionary = echo.get("emotion", {}) as Dictionary
				emo_status = str(emo.get("emotional_status", ""))
			echo_slots.append({
				"echo_id":          str(eid),
				"zone":             str(zone_id),
				"slot_index":       slot_idx,
				"emotional_status": emo_status,
				"bond_pairs":       bond_map.get(str(eid), []).duplicate(),
			})
			slot_idx += 1
	return {
		"institution_visibility": inst_visibility,
		"institution_conditions": inst_conditions,
		"echo_slots":             echo_slots,
	}


# ---- Private helpers ----

static func _get_sanctum(save_data: Dictionary) -> Dictionary:
	var s: Variant = save_data.get("sanctum", {})
	return s if s is Dictionary else {}


static func _get_inst(inst_id: String, save_data: Dictionary) -> Dictionary:
	var sanctum := _get_sanctum(save_data)
	var institutions_v: Variant = sanctum.get("institutions", {})
	var institutions: Dictionary = institutions_v if institutions_v is Dictionary else {}
	var inst_v: Variant = institutions.get(inst_id, {})
	return inst_v if inst_v is Dictionary else {}


static func _find_echo(echo_id: String, save_data: Dictionary) -> Dictionary:
	var sanctum := _get_sanctum(save_data)
	var roster: Array = sanctum.get("roster", []) as Array
	return _find_echo_in_roster(echo_id, roster)


static func _find_echo_in_roster(echo_id: String, roster: Array) -> Dictionary:
	for e_v in roster:
		if e_v is Dictionary:
			var e: Dictionary = e_v
			if str(e.get("id", "")) == echo_id:
				return e
	return {}


static func _zone_for_echo(echo_id: String, save_data: Dictionary, party_ids: Array) -> String:
	var inst_for := find_institution_for_echo(echo_id, save_data)
	if inst_for != "":
		return inst_for
	if party_ids.has(echo_id):
		return "party"
	return "roaming"


static func _set_condition(inst: Dictionary, new_cond: String, inst_id: String, logger: StructuredLogger, t: int) -> void:
	var old_cond := str(inst.get("condition", CONDITION_NEGLECTED))
	inst["condition"] = new_cond
	if old_cond != new_cond:
		logger.info(t, "sanctum.institution.condition_updated", inst_id, { "id": inst_id, "old": old_cond, "new": new_cond })
