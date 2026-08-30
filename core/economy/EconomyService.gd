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
# V2-INFRA-003 Phase 8 — THE SETTLEMENT SPLIT (defects D36 / D77).
#
# There used to be ONE payer, `reward_stage_complete()`, called unconditionally from
# `FlowEncounterState.build_final_snapshot()` at every combat end. It paid the whole reward —
# the STAGE's summed objective weights and the STAGE's virtue bonus included — for every
# ENCOUNTER. A stage with three combat situations paid three full stage rewards, and a defeat
# paid `base × 0.25 × redo` while deliberately leaving the situation unresolved, so one fight
# could be lost for Ase without limit. That single function is now two, one per cadence:
#
#   reward_encounter_complete()  — paid once per ENCOUNTER, in the combat-end dispatch.
#       Victory: enemies-defeated + echoes-survived + speed bonus, redo-scaled.
#       Defeat:  the 25% consolation, which is intended design (Jeff, 2026-08-24) — but paid
#                only ONCE per situation, gated by the caller's `consolation_eligible`.
#   settle_stage_complete()      — paid once per STAGE, in the `flow.complete_stage` dispatch,
#       behind the stage's `settlement_receipt` stamp. Base objective weights + virtue bonus.
#
# WHAT DID NOT CHANGE. Every component keeps the exact formula and the exact redo exposure it
# had: redo scaled base+enemy+echo+speed and never the virtue bonus, and it still does — only
# now inside two `roundi()` calls instead of one, which is the sole arithmetic consequence of
# splitting (a possible ±1 Ase against the old single rounding). `RewardCalc.compute()` is
# untouched, so `speed_bonus` is still `roundi(base × speed_pct)`: the stage's base stays an
# INPUT to the encounter cadence, it just stops being a PAYOUT of it. The defeat consolation
# likewise still reads the stage base to take 25% of.

## Encounter-cadence payout. Paid at every combat end, once per encounter.
##
## victory:   on a win pays `roundi((enemy + echo + speed) × redo)`; on a loss pays the
##            `roundi(base × 0.25 × redo)` consolation.
## base_reward: the STAGE's base (sum of its objective weights). An INPUT only — never paid
##            here on a victory. Used for the defeat consolation.
## consolation_eligible: false on a repeat defeat of a situation that has already paid its
##            consolation. Ignored on a victory. When false the defeat branch pays nothing and
##            returns an empty breakdown — there is no second consolation to itemise.
## ekwan_factor: fraction of THIS payout to award as Ekwan (V2-ECONOMY-001). 0.0 for none.
## Returns reward_result dict with ase_awarded, ekwan_awarded, rank, victory, breakdown.
func reward_encounter_complete(
	victory: bool,
	base_reward: int,
	enemy_bonus: int,
	enemies_defeated: int,
	echo_bonus: int,
	echoes_survived: int,
	speed_bonus: int,
	redo_multiplier: float,
	rank: String,
	consolation_eligible: bool,
	ekwan_factor: float,
	logger: StructuredLogger,
	t: int
) -> Dictionary:
	var total: int
	var breakdown: Array  # Array of {label: String, delta: int, currency: String}

	if victory:
		var pre_redo := enemy_bonus + echo_bonus + speed_bonus
		total = roundi(float(pre_redo) * redo_multiplier)
		var redo_penalty := total - pre_redo  # negative or 0

		breakdown = []
		if enemy_bonus > 0:
			var e_label := "%d %s defeated" % [enemies_defeated, "enemy" if enemies_defeated == 1 else "enemies"]
			breakdown.append({ "label": e_label, "delta": enemy_bonus, "currency": "ase" })
		if echo_bonus > 0:
			var ec_label := "%d %s survived" % [echoes_survived, "echo" if echoes_survived == 1 else "echoes"]
			breakdown.append({ "label": ec_label, "delta": echo_bonus, "currency": "ase" })
		if speed_bonus > 0:
			breakdown.append({ "label": "Speed bonus", "delta": speed_bonus, "currency": "ase" })
		if redo_penalty < 0:
			breakdown.append({ "label": "Redo penalty", "delta": redo_penalty, "currency": "ase" })
	elif consolation_eligible:
		total = roundi(float(base_reward) * 0.25 * redo_multiplier)
		var base_consolation := roundi(float(base_reward) * 0.25)
		var defeat_penalty   := base_consolation - base_reward  # negative
		var redo_penalty     := total - base_consolation        # negative or 0

		breakdown = []
		breakdown.append({ "label": "Base objectives", "delta": base_reward, "currency": "ase" })
		breakdown.append({ "label": "Defeat penalty", "delta": defeat_penalty, "currency": "ase" })
		if redo_penalty < 0:
			breakdown.append({ "label": "Redo penalty", "delta": redo_penalty, "currency": "ase" })
	else:
		# D77: this situation has already paid its one defeat consolation. Losing it again pays
		# nothing. The situation still is NOT marked resolved by this path, so the fight stays
		# retryable — it is just no longer payable.
		total = 0
		breakdown = []

	if total > 0:
		add_ase(total, "encounter_reward", logger, t)

	# V2-ECONOMY-001: Ekwan — scales off the Ase actually awarded here.
	var ekwan_total := roundi(float(total) * maxf(ekwan_factor, 0.0))
	if ekwan_total > 0:
		add_ekwan(ekwan_total, "encounter_reward", logger, t)
		breakdown.append({ "label": "Sanctum share", "delta": ekwan_total, "currency": "ekwan" })

	return {
		"ase_awarded":   total,
		"ekwan_awarded": ekwan_total,
		"rank":          rank,
		"victory":       victory,
		"breakdown":     breakdown,
	}


## Stage-cadence payout. Paid once per stage, in the `flow.complete_stage` dispatch, behind the
## stage's `settlement_receipt` idempotency stamp. The CALLER owns that stamp
## (`StageSettlementService`), not this function — this function only pays what it is told to.
##
## base_reward:  sum of the stage's objective weights (`RewardCalc.base_reward`).
## redo_multiplier: same value the encounter payout used; scales the base exactly as the single
##               combined payer scaled it.
## virtue_bonus: REALM-005 realm-virtue + stage-index bonus. Never redo-scaled — it carries its
##               own realm-order multiplier already (`RealmService.calculate_stage_reward`).
## Returns { ase_awarded, ekwan_awarded, breakdown }.
func settle_stage_complete(
	base_reward: int,
	redo_multiplier: float,
	virtue_bonus: int,
	ekwan_factor: float,
	logger: StructuredLogger,
	t: int
) -> Dictionary:
	var base_after_redo := roundi(float(base_reward) * redo_multiplier)
	var total := base_after_redo + virtue_bonus
	var redo_penalty := base_after_redo - base_reward  # negative or 0

	var breakdown: Array = []
	breakdown.append({ "label": "Base objectives", "delta": base_reward, "currency": "ase" })
	if redo_penalty < 0:
		breakdown.append({ "label": "Redo penalty", "delta": redo_penalty, "currency": "ase" })
	if virtue_bonus > 0:
		breakdown.append({ "label": "Realm virtue", "delta": virtue_bonus, "currency": "ase" })

	if total > 0:
		add_ase(total, "stage_reward", logger, t)

	var ekwan_total := roundi(float(total) * maxf(ekwan_factor, 0.0))
	if ekwan_total > 0:
		add_ekwan(ekwan_total, "stage_reward", logger, t)
		breakdown.append({ "label": "Sanctum share", "delta": ekwan_total, "currency": "ekwan" })

	return {
		"ase_awarded":   total,
		"ekwan_awarded": ekwan_total,
		"breakdown":     breakdown,
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
