# EconomyService (ECONOMY-001)
# Determinitic currency mutations for Ase (active) and Ekwan (reseverd, but available).
# Does not own a global stat. Operates on the save Dictionary reference.
# Emits structured logs for every mutation
# no RNG, no OS time, no UI dependencies

class_name EconomyService

extends RefCounted

var _save: Dictionary

# Key we own inside the save
const _KEY_ECONOMY := "economy"
const _KEY_ASE := "ase"
const _KEY_EKWAN := "ekwan"

# ---- Construction ----
func _init(save_ref: Dictionary) -> void:
	# We keep a reference to the authoritative save dictionary.
	# This means EconomyService is a thin deterministic façade, not a second source of truth.
	_save = save_ref
	_ensure_economy_dict_exists()
	
# ---- Read API ----
func get_ase() -> int:
	return _get_int_or_zero(_save[_KEY_ECONOMY], _KEY_ASE)

func get_ekwan() -> int:
	return _get_int_or_zero(_save[_KEY_ECONOMY], _KEY_EKWAN)
	
func can_afford_ase(cost_ase: int) -> bool:
	if cost_ase <= 0:
		return true
	return get_ase() >= cost_ase

func can_afford_ekwan(cost_ekwan: int) -> bool:
	if cost_ekwan <= 0:
		return true
	return get_ekwan() >= cost_ekwan

# ---- Mutation API (Ase) ----
func add_ase(amount: int, reason: String, logger: StructuredLogger, t: int) -> void:
	if amount <= 0:
		_log_denied(logger, t, "economy.ase.add_denied", "Denied ase add (non-positive amount)", {
			"amount": amount,
			"reason": reason
		})
		return

	var econ: Dictionary = _save[_KEY_ECONOMY]
	var before := _get_int_or_zero(econ, _KEY_ASE)
	var after := before + amount
	econ[_KEY_ASE] = after

	_log_info(logger, t, "economy.ase.add", "Ase added", {
		"amount": amount,
		"before": before,
		"after": after,
		"reason": reason
	})
	

func spend_ase(amount: int, reason: String, logger: StructuredLogger, t: int) -> bool:
	if amount <= 0:
		_log_denied(logger, t, "economy.ase.spend_denied", "Denied ase spend (non-positive amount)", {
			"amount": amount,
			"reason": reason
		})
		return false

	var econ: Dictionary = _save[_KEY_ECONOMY]
	var before := _get_int_or_zero(econ, _KEY_ASE)

	if before < amount:
		_log_denied(logger, t, "economy.ase.spend_denied", "Denied ase spend (insufficient funds)", {
			"amount": amount,
			"before": before,
			"reason": reason
		})
		return false

	var after := before - amount
	econ[_KEY_ASE] = after

	_log_info(logger, t, "economy.ase.spend", "Ase spent", {
		"amount": amount,
		"before": before,
		"after": after,
		"reason": reason
	})
	return true

# ---- Stage Reward API ----
#
# Two payers, one per cadence:
#   reward_encounter_complete()  — once per ENCOUNTER, at combat end.
#       Victory: the echoes-survived bonus, redo-scaled.
#       Defeat:  the 25% consolation, paid ONCE per situation (the caller's `consolation_eligible`).
#   settle_stage_complete()      — once per STAGE, in `flow.complete_stage`, behind the stage's
#       `settlement_receipt` stamp. Objective weights (and Ekwan), redo-scaled.
# Speed, enemy kills and the realm virtue pay nothing (D-40, D-49).

## Encounter-cadence payout. Paid at every combat end, once per encounter.
##
## victory:   on a win pays `roundi(echo_bonus × redo)`; on a loss pays the
##            `roundi(base × 0.25 × redo)` consolation.
## base_reward: the weight of the fought objective (`RewardCalc.consolation_base`). Never paid
##            here on a victory. Used for the defeat consolation.
## consolation_eligible: false on a repeat defeat of a situation that has already paid its
##            consolation. Ignored on a victory. When false the defeat branch pays nothing and
##            returns one delta-0 `repeat_defeat` row.
## Every row carries `cause` and `params` (see `_row`). A fight pays no Ekwan (D-28):
## `ekwan_awarded` stays in the result as 0 so the Resolve snapshot keeps its shape.
## Returns reward_result dict with ase_awarded, ekwan_awarded, rank, victory, breakdown.
func reward_encounter_complete(
	victory: bool,
	base_reward: int,
	echo_bonus: int,
	echoes_survived: int,
	redo_multiplier: float,
	rank: String,
	consolation_eligible: bool,
	logger: StructuredLogger,
	t: int
) -> Dictionary:
	var total: int
	var breakdown: Array  # Array of {label: String, delta: int, currency: String}

	if victory:
		var pre_redo := echo_bonus
		total = roundi(float(pre_redo) * redo_multiplier)
		var redo_penalty := total - pre_redo  # negative or 0

		breakdown = []
		if echo_bonus > 0:
			var ec_label := "%d %s survived" % [echoes_survived, "echo" if echoes_survived == 1 else "echoes"]
			breakdown.append(_row(ec_label, echo_bonus, "echoes_alive", { "count": echoes_survived }))
		if redo_penalty < 0:
			breakdown.append(_row("Redo penalty", redo_penalty, "replay", { "factor": redo_multiplier }))
	elif consolation_eligible:
		total = roundi(float(base_reward) * 0.25 * redo_multiplier)
		var base_consolation := roundi(float(base_reward) * 0.25)
		var defeat_penalty   := base_consolation - base_reward  # negative
		var redo_penalty     := total - base_consolation        # negative or 0

		breakdown = []
		breakdown.append(_row("Base objectives", base_reward, "defeat_consolation", { "part": "base" }))
		breakdown.append(_row("Defeat penalty", defeat_penalty, "defeat_consolation", { "part": "penalty" }))
		if redo_penalty < 0:
			breakdown.append(_row("Redo penalty", redo_penalty, "replay", { "factor": redo_multiplier }))
	else:
		# D77: this situation has already paid its one defeat consolation. Losing it again pays
		# nothing. The situation still is NOT marked resolved by this path, so the fight stays
		# retryable — it is just no longer payable.
		total = 0
		breakdown = [_row("Repeat defeat", 0, "repeat_defeat")]

	if total > 0:
		add_ase(total, "encounter_reward", logger, t)

	return {
		"ase_awarded":   total,
		"ekwan_awarded": 0,
		"rank":          rank,
		"victory":       victory,
		"breakdown":     breakdown,
	}


## Stage-cadence payout. Paid once per stage, in the `flow.complete_stage` dispatch, behind the
## stage's `settlement_receipt` idempotency stamp. The CALLER owns that stamp
## (`StageSettlementService`), not this function — this function only pays what it is told to.
##
## base_reward:  sum of the stage's objective weights (`RewardCalc.base_reward`).
## objective_counts: `RewardCalc.objective_counts()`; feeds the `objectives_overcome` params only.
## ekwan_base:   `RewardCalc.stage_ekwan()`, the Ekwan of the completed objectives before redo.
## redo_multiplier: same value the encounter payout used; scales the base exactly as the single
##               combined payer scaled it.
## Returns { ase_awarded, ekwan_awarded, breakdown }.
func settle_stage_complete(
	base_reward: int,
	redo_multiplier: float,
	logger: StructuredLogger,
	t: int,
	objective_counts: Dictionary = {},
	ekwan_base: int = 0
) -> Dictionary:
	var rows := stage_payout_rows(base_reward, redo_multiplier, objective_counts, ekwan_base)
	var total: int = rows["ase"]
	var breakdown: Array = rows["breakdown"]

	if total > 0:
		add_ase(total, "stage_reward", logger, t)

	var ekwan_total: int = rows["ekwan"]
	if ekwan_total > 0:
		add_ekwan(ekwan_total, "stage_reward", logger, t)

	return {
		"ase_awarded":   total,
		"ekwan_awarded": ekwan_total,
		"breakdown":     breakdown,
	}

## The Ase rows of the stage payout, and the Ase and Ekwan totals. The ONE producer:
## `settle_stage_complete` pays from it and `StageSettlementService.preview` shows it, so the two
## cannot drift. Ekwan has no rows (D-32). Like the Ase base, it is rounded once on the stage sum.
## Pure. Returns { breakdown: Array, ase: int, ekwan: int }.
static func stage_payout_rows(base_reward: int, redo_multiplier: float,
		objective_counts: Dictionary = {}, ekwan_base: int = 0) -> Dictionary:
	var base_after_redo := roundi(float(base_reward) * redo_multiplier)
	var redo_penalty := base_after_redo - base_reward  # negative or 0
	var breakdown: Array = []
	breakdown.append(_row("Base objectives", base_reward, "objectives_overcome", {
		"overcome": int(objective_counts.get("overcome", 0)),
		"total": int(objective_counts.get("total", 0)),
	}))
	if redo_penalty < 0:
		breakdown.append(_row("Redo penalty", redo_penalty, "replay", { "factor": redo_multiplier }))
	return {
		"breakdown": breakdown,
		"ase": base_after_redo,
		"ekwan": roundi(float(ekwan_base) * redo_multiplier),
	}


# ---- Mutation API (Ekwan) ----
func add_ekwan(amount: int, reason: String, logger: StructuredLogger, t: int) -> void:
	if amount <= 0:
		_log_denied(logger, t, "economy.ekwan.add_denied", "Denied ekwan add (non-positive amount)", {
			"amount": amount,
			"reason": reason
		})
		return

	var econ: Dictionary = _save[_KEY_ECONOMY]
	var before := _get_int_or_zero(econ, _KEY_EKWAN)
	var after := before + amount
	econ[_KEY_EKWAN] = after

	_log_info(logger, t, "economy.ekwan.add", "Ekwan added", {
		"amount": amount,
		"before": before,
		"after": after,
		"reason": reason
	})

func spend_ekwan(amount: int, reason: String, logger: StructuredLogger, t: int) -> bool:
	if amount <= 0:
		_log_denied(logger, t, "economy.ekwan.spend_denied", "Denied ekwan spend (non-positive amount)", {
			"amount": amount,
			"reason": reason
		})
		return false

	var econ: Dictionary = _save[_KEY_ECONOMY]
	var before := _get_int_or_zero(econ, _KEY_EKWAN)

	if before < amount:
		_log_denied(logger, t, "economy.ekwan.spend_denied", "Denied ekwan spend (insufficient funds)", {
			"amount": amount,
			"before": before,
			"reason": reason
		})
		return false

	var after := before - amount
	econ[_KEY_EKWAN] = after

	_log_info(logger, t, "economy.ekwan.spend", "Ekwan spent", {
		"amount": amount,
		"before": before,
		"after": after,
		"reason": reason
	})
	return true

# ---- Internal helpers ----
## One Ase breakdown row. `cause` is a stable id and `params` holds the numbers its sentence
## needs; both are additive, so `label`, `delta` and `currency` keep their old meaning.
static func _row(label: String, delta: int, cause: String, params: Dictionary = {}) -> Dictionary:
	return { "label": label, "delta": delta, "currency": "ase", "cause": cause, "params": params }

func _ensure_economy_dict_exists() -> void:
	# SaveService should already guarantee this after load,
	# but EconomyService defends itself to remain safe in isolation.
	if not _save.has(_KEY_ECONOMY) or typeof(_save[_KEY_ECONOMY]) != TYPE_DICTIONARY:
		_save[_KEY_ECONOMY] = {_KEY_ASE: 0, _KEY_EKWAN: 0}
		return

	var econ: Dictionary = _save[_KEY_ECONOMY]
	if not econ.has(_KEY_ASE) or (typeof(econ[_KEY_ASE]) != TYPE_INT and typeof(econ[_KEY_ASE]) != TYPE_FLOAT):
		econ[_KEY_ASE] = 0
	if not econ.has(_KEY_EKWAN) or (typeof(econ[_KEY_EKWAN]) != TYPE_INT and typeof(econ[_KEY_EKWAN]) != TYPE_FLOAT):
		econ[_KEY_EKWAN] = 0

func _get_int_or_zero(d: Dictionary, key: String) -> int:
	if not d.has(key):
		return 0
	var v = d[key]
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	return 0


# ---- Logging helpers ----
func _log_info(logger: StructuredLogger, t: int, type: String, msg: String, data: Dictionary) -> void:
	if logger == null:
		return
	# If the logger is in DEBUG mode, emit debug events so formatter can show richer details (like reason).
	if logger.get_level() == StructuredLogger.LEVEL_DEBUG:
		logger.debug(t, type, msg, data)
	else:
		logger.info(t, type, msg, data)

func _log_denied(logger: StructuredLogger, t: int, type: String, msg: String, data: Dictionary) -> void:
	if logger == null:
		return
	# Denied attempts are useful; mirror the same severity policy as normal logs.
	if logger.get_level() == StructuredLogger.LEVEL_DEBUG:
		logger.debug(t, type, msg, data)
	else:
		logger.info(t, type, msg, data)
