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
