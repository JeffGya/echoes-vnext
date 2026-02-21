# EconomyAccrualService:
# Pure math utilites for Ase accrual.
# - No OS time calls
# - No logging
# - No save mutation
# - Deterministic rounding rules

class_name EconomyAccrualService

extends RefCounted

static func compute_online_settle_gain(delta_seconds: int, rate_per_sec: float, multiplier: float) -> int:
	if delta_seconds <= 0:
		return 0

	var m := maxf(multiplier, 0.0)
	var raw := float(delta_seconds) * rate_per_sec * m
	return _floor_int(raw)

static func compute_offline_gain_decay_linear(
	delta_seconds: int,
	rate_per_sec: float,
	multiplier: float,
	offline_start_factor: float,
	offline_cap_seconds: int
) -> int:
	if delta_seconds <= 0:
		return 0
	if offline_cap_seconds <= 0:
		return 0

	var m := maxf(multiplier, 0.0)
	
	# Clamp elapsed to cap (after cap, rate reaches 0).
	var effective := mini(delta_seconds, offline_cap_seconds)
	
	# Linear decay from offline_start_factor -> 0 across [0, cap]
	# Average factor over the interval is: (start + end)/2 = (offline_start_factor + 0)/2
	# BUT because decay happens across time, the total gained is:
	# integral_0^effective start*(1 - t/cap) dt = start*(effective - effective^2/(2*cap))
	var start := maxf(offline_start_factor, 0.0)
	var cap := float(offline_cap_seconds)
	var eff := float(effective)
	
	var factor_integral := start * (eff - (eff * eff) / (2.0 * cap)) # seconds * factor
	var raw := factor_integral * rate_per_sec * m
	
	return _floor_int(raw)

static func compute_offline_gain(
	delta_seconds: int,
	rate_per_sec: float,
	multiplier: float,
	offline_start_factor: float,
	offline_cap_seconds: int
) -> int:
	return compute_offline_gain_decay_linear(
		delta_seconds,
		rate_per_sec,
		multiplier,
		offline_start_factor,
		offline_cap_seconds
	)
	
static func _floor_int(v: float) -> int:
	# Deterministic rounding: always floor toward -inf, but economy gains should never be negative.
	if v <= 0.0:
		return 0
	return int(floor(v))
