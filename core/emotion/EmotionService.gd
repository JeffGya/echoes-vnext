# res://core/emotion/EmotionService.gd
# Single choke point for all emotion field mutations on echo dicts.
# All methods are static — no state; mirrors EconomyService pattern.
#
# Emotion block shape (stored at echo["emotion"]):
#   {
#     "faith":          int,  # 0–100, clamped. Determines summon bonuses (future).
#     "morale_base":    int,  # 10–90, clamped. Long-term baseline. Mutates via win/loss streaks (±1 per 3-streak).
#     "morale_current": int,  # 0–100, clamped. Combat-volatile. Starts == morale_base.
#     "fear_current":   int,  # 0–100, clamped. Combat-volatile. Sanctum tick recovers bidirectionally toward fear_base.
#     "fear_base":      int,  # 0–40, clamped. Per-echo resting fear level. Rises +1 per combat loss, falls -1 per win.
#                             #   Born from traits.courage (inverted) + archetype_birth modifier. Range 0–20 at birth.
#     "win_streak":     int,  # Consecutive wins since last loss. Resets on loss. At 3: morale_base +1, streak resets.
#     "loss_streak":    int,  # Consecutive losses since last win. Resets on win. At 3: morale_base -1, streak resets.
#   }
#
# Morale tiers (computed, not stored — internal sim use only):
#   0–24   → "broken"
#   25–49  → "shaken"
#   50–74  → "steady"
#   75–100 → "inspired"
#
# Emotional status tiers (computed, not stored — player-facing, V2-EMOTION-002):
#   Derived from BOTH morale_current and fear_current.
#   8 tiers: radiant / whole / grounded / burdened / pressed / strained / fraying / hollow
#   Morale language dominates the top; fear language dominates the bottom.
#   Never build separate morale and fear display fields — use get_emotional_status() only.
#
# Rules (EMOTION-001/002):
# - Never write echo["emotion"] directly — always use these setters.
# - All values are clamped at the setter; callers need not clamp first.
# - init_echo() is idempotent: no-op if block already exists.
# - Birth variance (EMOTION-002): morale_base derives from traits.courage + archetype_birth.
#   Range 25–74 (shaken/steady). Echoes with no traits fall back to flat 50.
# - apply_morale_delta() / apply_fear_delta() are the only valid drift entry points.

class_name EmotionService

const DEFAULTS := {
	"faith":          50,
	"morale_base":    50,
	"morale_current": 50,
	"fear_current":   0,
	"fear_base":      0,
	"win_streak":     0,
	"loss_streak":    0,
}


## Initialises echo["emotion"] on first creation. Idempotent: no-op if block exists.
## Birth variance (EMOTION-002/003, updated for 9-archetype system):
##   morale_base derived from traits.courage + archetype_birth modifier.
##   Stage 1 — remap courage (30–70) → base morale (25–74)
##   Stage 2 — archetype modifier (9-archetype system):
##     valiant +5, proud +5, loyal +3, ambitious +3,
##     devout +2, empathic +2, canny 0, stoic 0, reflective -5
##   Result clamped to 25–74 (shaken/steady range; no echo starts broken or inspired).
##   faith uses traits.faith directly (30–70). Fallback to 50 if traits absent.
##
##   fear_base derived from traits.courage (inverted) + archetype_birth modifier (EMOTION-003):
##   Stage 1 — remap courage (30–70) → fear_base (20–5), inverted from morale formula
##   Stage 2 — archetype modifier:
##     stoic -5, valiant -3, loyal -2, devout -2, empathic +1, ambitious +2, proud +3
##   Result clamped to 0–20. Default fallback (no traits): 10.
static func init_echo(echo: Dictionary, logger: StructuredLogger, t: int) -> void:
	if echo.has("emotion"):
		return  # idempotent — block already set (e.g. second call, save repair echo)

	# Derive birth values from traits if present (EMOTION-002)
	var traits_v: Variant = echo.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}

	var birth_morale: int = DEFAULTS["morale_base"]  # fallback: no traits = flat 50
	var birth_faith: int  = DEFAULTS["faith"]         # fallback: no traits = flat 50

	var birth_fear_base: int = 10  # fallback: no traits = flat 10

	if not traits.is_empty() and traits.has("courage"):
		var courage := int(traits.get("courage", 50))
		# Stage 1: continuous base from courage trait range 30–70 → morale range 25–74
		var base_morale := 25 + int(round((courage - 30) * 49.0 / 40.0))
		# Stage 2: archetype modifier for narrative clarity on top (9-archetype system)
		var archetype := str(echo.get("archetype_birth", ""))
		const ARCH_MORALE_MOD: Dictionary = {
			"valiant": 5, "proud": 5, "loyal": 3, "ambitious": 3,
			"devout": 2, "empathic": 2, "canny": 0, "stoic": 0, "reflective": -5
		}
		var modifier: int = ARCH_MORALE_MOD.get(archetype, 0)
		birth_morale = clampi(base_morale + modifier, 25, 74)

		# EMOTION-003: fear_base born from courage (inverted) + archetype modifier
		# Stage 1: courage 30 → fear_base 20, courage 70 → fear_base 5
		var base_fear := 20 - int(round((courage - 30) * 15.0 / 40.0))
		const ARCH_FEAR_MOD: Dictionary = {
			"stoic": -5, "valiant": -3, "loyal": -2, "devout": -2,
			"empathic": 1, "reflective": 0, "canny": 0, "ambitious": 2, "proud": 3
		}
		var fear_modifier: int = ARCH_FEAR_MOD.get(archetype, 0)
		birth_fear_base = clampi(base_fear + fear_modifier, 0, 20)

	if not traits.is_empty() and traits.has("faith"):
		# faith uses the trait value directly (30–70 is already a fine sub-range of 0–100)
		birth_faith = int(traits.get("faith", 50))

	echo["emotion"] = {
		"faith":          birth_faith,
		"morale_base":    birth_morale,
		"morale_current": birth_morale,  # always synced to base at birth
		"fear_current":   0,             # always 0 at birth — builds through combat
		"fear_base":      birth_fear_base,
		"win_streak":     0,
		"loss_streak":    0,
	}
	logger.info(t, "emotion.init", "Emotion block initialised", {
		"echo_id":         echo.get("id", ""),
		"faith":           birth_faith,
		"morale_base":     birth_morale,
		"morale_current":  birth_morale,
		"fear_current":    0,
		"fear_base":       birth_fear_base,
		"birth_source":    "traits" if not traits.is_empty() else "defaults",
		"archetype_birth": str(echo.get("archetype_birth", ""))
	})


## Returns the full emotion block for echo.
## Returns safe defaults dict if block is absent — does NOT mutate echo.
static func get_emotion(echo: Dictionary) -> Dictionary:
	return echo.get("emotion", DEFAULTS.duplicate())


## Sets faith, clamped 0–100. Logs emotion.faith.set.
static func set_faith(echo: Dictionary, value: int, logger: StructuredLogger, t: int) -> void:
	_ensure_emotion_block(echo)
	echo["emotion"]["faith"] = clampi(value, 0, 100)
	logger.info(t, "emotion.faith.set", "Faith updated", {
		"echo_id": echo.get("id", ""),
		"faith":   echo["emotion"]["faith"]
	})


## Sets morale_base, clamped 0–100. Logs emotion.morale_base.set.
static func set_morale_base(echo: Dictionary, value: int, logger: StructuredLogger, t: int) -> void:
	_ensure_emotion_block(echo)
	echo["emotion"]["morale_base"] = clampi(value, 0, 100)
	logger.info(t, "emotion.morale_base.set", "Morale base updated", {
		"echo_id":     echo.get("id", ""),
		"morale_base": echo["emotion"]["morale_base"]
	})


## Sets morale_current, clamped 0–100. Logs emotion.morale_current.set.
static func set_morale_current(echo: Dictionary, value: int, logger: StructuredLogger, t: int) -> void:
	_ensure_emotion_block(echo)
	echo["emotion"]["morale_current"] = clampi(value, 0, 100)
	logger.info(t, "emotion.morale_current.set", "Morale current updated", {
		"echo_id":        echo.get("id", ""),
		"morale_current": echo["emotion"]["morale_current"],
		"morale_tier":    get_morale_tier(echo["emotion"]["morale_current"])
	})


## Sets fear_current, clamped 0–100. Logs emotion.fear.set.
static func set_fear_current(echo: Dictionary, value: int, logger: StructuredLogger, t: int) -> void:
	_ensure_emotion_block(echo)
	echo["emotion"]["fear_current"] = clampi(value, 0, 100)
	logger.info(t, "emotion.fear.set", "Fear updated", {
		"echo_id":      echo.get("id", ""),
		"fear_current": echo["emotion"]["fear_current"]
	})


## Sets fear_base, clamped 0–100. Logs emotion.fear_base.set.
## fear_base is the resting fear level (EMOTION-003). Rises on combat loss, falls on win.
static func set_fear_base(echo: Dictionary, value: int, logger: StructuredLogger, t: int) -> void:
	_ensure_emotion_block(echo)
	echo["emotion"]["fear_base"] = clampi(value, 0, 100)
	logger.info(t, "emotion.fear_base.set", "Fear base updated", {
		"echo_id":   echo.get("id", ""),
		"fear_base": echo["emotion"]["fear_base"]
	})


## Returns the morale tier label for the given morale_current value.
## Pure — no dict required. Safe to call with any int.
static func get_morale_tier(morale_current: int) -> String:
	if morale_current >= 75:
		return "inspired"
	elif morale_current >= 50:
		return "steady"
	elif morale_current >= 25:
		return "shaken"
	return "broken"


## Returns the unified player-facing emotional status from morale_current + fear_current.
## 8 tiers (worst-first derivation; burdened is the catch-all middle):
##   hollow   — fear ≥ 75, or fear ≥ 55 with morale ≤ 20
##   fraying  — fear ≥ 65 and morale ≤ 35
##   strained — fear ≥ 55 and morale ≤ 45
##   pressed  — fear ≥ 45 and morale ≤ 55
##   radiant  — morale ≥ 70 and fear ≤ 15
##   whole    — morale ≥ 55 and fear ≤ 30
##   grounded — morale ≥ 40 and fear ≤ 45
##   burdened — catch-all (neither side dominant)
## Pure — no dict required. Safe to call with any ints.
static func get_emotional_status(morale: int, fear: int) -> String:
	if fear >= 75 or (fear >= 55 and morale <= 20):
		return "hollow"
	if fear >= 65 and morale <= 35:
		return "fraying"
	if fear >= 55 and morale <= 45:
		return "strained"
	if fear >= 45 and morale <= 55:
		return "pressed"
	if morale >= 70 and fear <= 15:
		return "radiant"
	if morale >= 55 and fear <= 30:
		return "whole"
	if morale >= 40 and fear <= 45:
		return "grounded"
	return "burdened"


# ---------------------------------------------------------------------------
# Drift methods (EMOTION-002)
# ---------------------------------------------------------------------------

## Adds delta to morale_current (clamped 0–100). Logs emotion.morale.drift.
## Stores _last_drift on the emotion block (transient; not saved to disk).
static func apply_morale_delta(echo: Dictionary, delta: int, cause: String, logger: StructuredLogger, t: int) -> void:
	_ensure_emotion_block(echo)
	var emo: Dictionary = echo["emotion"]
	var old_val := int(emo.get("morale_current", 50))
	var new_val := clampi(old_val + delta, 0, 100)
	emo["morale_current"] = new_val
	emo["_last_drift"] = { "cause": cause, "delta": delta, "field": "morale", "new_value": new_val }
	logger.info(t, "emotion.morale.drift", "Morale drifted", {
		"echo_id":     echo.get("id", ""),
		"cause":       cause,
		"delta":       delta,
		"old_value":   old_val,
		"new_value":   new_val,
		"morale_tier": get_morale_tier(new_val)
	})


## Adds delta to fear_current (clamped 0–100). Logs emotion.fear.drift.
## If fear_current >= fear_threshold after change, also logs emotion.fear.threshold_crossed.
## Stores _last_drift on the emotion block (transient; not saved to disk).
##
## V2-PROG-006: resilience_traits and expression_band are optional params.
## If "resist_fear" is in resilience_traits AND expression_band is "grounded" or "whole",
## the incoming fear delta is reduced by 40%. Sets emotion._resilience_fired = true when
## a trait fires (cleared each turn by ActorStateMachine before advance_turn).
static func apply_fear_delta(
	echo: Dictionary,
	delta: int,
	cause: String,
	fear_threshold: int,
	logger: StructuredLogger,
	t: int,
	resilience_traits: Array = [],
	expression_band: String = ""
) -> void:
	_ensure_emotion_block(echo)
	var emo: Dictionary = echo["emotion"]
	var old_val := int(emo.get("fear_current", 0))

	# V2-PROG-006: resist_fear — reduce fear delta by 40% at Grounded+
	var effective_delta := delta
	var trait_fired := false
	if delta > 0 and "resist_fear" in resilience_traits \
			and (expression_band == "grounded" or expression_band == "whole"):
		effective_delta = int(round(float(delta) * 0.60))
		trait_fired = true

	var new_val := clampi(old_val + effective_delta, 0, 100)
	emo["fear_current"] = new_val
	emo["_last_drift"] = { "cause": cause, "delta": effective_delta, "field": "fear", "new_value": new_val }
	if trait_fired:
		emo["_resilience_fired"] = true
	logger.info(t, "emotion.fear.drift", "Fear drifted", {
		"echo_id":          echo.get("id", ""),
		"cause":            cause,
		"delta":            effective_delta,
		"delta_original":   delta,
		"old_value":        old_val,
		"new_value":        new_val,
		"resilience_fired": trait_fired
	})
	if new_val >= fear_threshold:
		logger.info(t, "emotion.fear.threshold_crossed", "Fear threshold reached", {
			"echo_id":        echo.get("id", ""),
			"fear_current":   new_val,
			"fear_threshold": fear_threshold
		})


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## Ensures echo["emotion"] exists and all 4 default fields are present.
## Does NOT overwrite fields that are already set.
static func _ensure_emotion_block(echo: Dictionary) -> void:
	if not echo.has("emotion"):
		echo["emotion"] = DEFAULTS.duplicate()
		return
	for key in DEFAULTS:
		if not echo["emotion"].has(key):
			echo["emotion"][key] = DEFAULTS[key]
