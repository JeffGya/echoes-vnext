# EmotionRecoveryService — V2-SANCTUM-001
# Time-based fear/morale recovery for roster echoes.
# Mirrors EconomyAccrualService pattern: pure static RefCounted, no RNG, no OS time, no UI deps.
#
# Recovery math (per echo):
#   morale_rate = cfg.morale_recovery_per_min / 60.0 * morale_multiplier
#   fear_rate   = cfg.fear_recovery_per_min   / 60.0 * fear_multiplier
#   effective   = _apply_decay(elapsed_seconds, offline_cap_seconds)
#     - elapsed ≤ cap/2 → full rate; elapsed > cap/2 → extra seconds count at 50%
#   morale_delta = roundi(morale_rate * effective)  → clamps at morale_base (ceiling)
#   fear_delta   = roundi(fear_rate   * effective)  → clamps at 0 (floor)
#   # SANCTUM-FEAR-BASE: swap 0 → echo["emotion"]["fear_base"] when that lands
#
# Modifier tick: after each apply, ticks_remaining decrements by 1.
#   When it hits 0, both multipliers reset to 1.0.

class_name EmotionRecoveryService

extends RefCounted


## Applies time-based fear/morale recovery to all roster echoes.
## Reads per-echo recovery_modifiers multipliers; decrements ticks_remaining.
## Returns Array of { echo_id, morale_delta, fear_delta } — positive values indicate improvement.
static func apply_recovery_from_elapsed(
	roster:          Array,
	elapsed_seconds: int,
	cfg:             Dictionary,
	fear_threshold:  int,
	logger:          StructuredLogger,
	t:               int
) -> Array:
	var results: Array = []
	if elapsed_seconds <= 0 or roster.is_empty():
		return results

	var cap_seconds  := int(cfg.get("offline_cap_seconds",     28800))
	var morale_per_min := float(cfg.get("morale_recovery_per_min", 1.0))
	var fear_per_min   := float(cfg.get("fear_recovery_per_min",   0.5))

	var effective := _apply_decay(elapsed_seconds, cap_seconds)

	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v

		var emo_v: Variant = echo.get("emotion", {})
		if not (emo_v is Dictionary):
			continue
		var emo: Dictionary = emo_v

		var rm_v: Variant = echo.get("recovery_modifiers", {})
		var rm: Dictionary = rm_v if rm_v is Dictionary else {}
		var morale_mul := maxf(float(rm.get("morale_multiplier", 1.0)), 0.0)
		var fear_mul   := maxf(float(rm.get("fear_multiplier",   1.0)), 0.0)
		var ticks      := int(rm.get("ticks_remaining", 0))

		var morale_rate := morale_per_min / 60.0 * morale_mul
		var fear_rate   := fear_per_min   / 60.0 * fear_mul

		var morale_current := int(emo.get("morale_current", 50))
		var morale_base    := int(emo.get("morale_base",    50))
		var fear_current   := int(emo.get("fear_current",   0))

		var morale_applied := 0
		var fear_applied   := 0

		# Morale recovers toward morale_base (ceiling)
		if morale_rate > 0.0 and morale_current < morale_base:
			var raw_delta := roundi(morale_rate * float(effective))
			if raw_delta > 0:
				var clamped := mini(morale_current + raw_delta, morale_base) - morale_current
				if clamped > 0:
					EmotionService.apply_morale_delta(echo, clamped, "recovery.settle", logger, t)
					morale_applied = clamped

		# Fear recovers toward 0 (floor)
		# SANCTUM-FEAR-BASE: swap 0 → echo["emotion"]["fear_base"] when that lands
		if fear_rate > 0.0 and fear_current > 0:
			var raw_delta := roundi(fear_rate * float(effective))
			if raw_delta > 0:
				var clamped := fear_current - maxi(fear_current - raw_delta, 0)
				if clamped > 0:
					EmotionService.apply_fear_delta(echo, -clamped, "recovery.settle", fear_threshold, logger, t)
					fear_applied = clamped

		# Tick down modifier; reset when expired
		if ticks > 0:
			rm["ticks_remaining"] = ticks - 1
			if rm["ticks_remaining"] <= 0:
				rm["morale_multiplier"] = 1.0
				rm["fear_multiplier"]   = 1.0
				rm["ticks_remaining"]   = 0
				logger.info(t, "emotion.recovery.modifier.expired", "Recovery modifier expired", {
					"echo_id": str(echo.get("id", ""))
				})

		if morale_applied != 0 or fear_applied != 0:
			results.append({
				"echo_id":      str(echo.get("id", "")),
				"morale_delta": morale_applied,
				"fear_delta":   fear_applied,
			})

	return results


## Sets per-echo recovery modifier for a single echo.
## Overwrites any existing modifier (only one active at a time per direction).
static func set_modifier(
	echo:       Dictionary,
	morale_mul: float,
	fear_mul:   float,
	ticks:      int,
	logger:     StructuredLogger,
	t:          int
) -> void:
	if not echo.has("recovery_modifiers") or typeof(echo["recovery_modifiers"]) != TYPE_DICTIONARY:
		echo["recovery_modifiers"] = {}
	var rm: Dictionary = echo["recovery_modifiers"]
	rm["morale_multiplier"] = morale_mul
	rm["fear_multiplier"]   = fear_mul
	rm["ticks_remaining"]   = maxi(ticks, 0)
	logger.info(t, "emotion.recovery.modifier.set", "Recovery modifier set", {
		"echo_id":           str(echo.get("id", "")),
		"morale_multiplier": morale_mul,
		"fear_multiplier":   fear_mul,
		"ticks_remaining":   ticks,
	})


# Two-step decay model (mirrors Ase offline accrual):
#   elapsed ≤ cap/2  → effective = elapsed      (full rate)
#   elapsed > cap/2  → extra seconds at 50%     (diminishing return)
static func _apply_decay(elapsed_seconds: int, cap_seconds: int) -> int:
	if cap_seconds <= 0:
		return elapsed_seconds
	var half_cap := cap_seconds / 2
	if elapsed_seconds <= half_cap:
		return elapsed_seconds
	var over := elapsed_seconds - half_cap
	return half_cap + over / 2
