# res://core/emotion/EmotionService.gd
# Single choke point for all emotion field mutations on echo dicts.
# All methods are static — no state; mirrors EconomyService pattern.
#
# Emotion block shape (stored at echo["emotion"]):
#   {
#     "faith":          int,  # 0–100, clamped. Determines summon bonuses (future).
#     "morale_base":    int,  # 0–100, clamped. Long-term baseline (story events).
#     "morale_current": int,  # 0–100, clamped. Combat-volatile. Starts == morale_base.
#     "fear_current":   int,  # 0–100, clamped. Resets to 0 each venture.
#   }
#
# Morale tiers (computed, not stored):
#   0–24   → "broken"
#   25–49  → "shaken"
#   50–74  → "steady"
#   75–100 → "inspired"
#
# Rules (EMOTION-001):
# - Never write echo["emotion"] directly — always use these setters.
# - All values are clamped at the setter; callers need not clamp first.
# - init_echo() is idempotent: safe to call even if the block already exists.

class_name EmotionService

const DEFAULTS := {
	"faith":          50,
	"morale_base":    50,
	"morale_current": 50,
	"fear_current":   0
}


## Ensures echo["emotion"] exists with all 4 fields initialised to defaults.
## Call when an echo is first created (new_game, summon).
## Logs emotion.init — idempotent: will not overwrite existing field values.
static func init_echo(echo: Dictionary, logger: StructuredLogger, t: int) -> void:
	_ensure_emotion_block(echo)
	logger.info(t, "emotion.init", "Emotion block initialised", {
		"echo_id":         echo.get("id", ""),
		"faith":           echo["emotion"]["faith"],
		"morale_base":     echo["emotion"]["morale_base"],
		"morale_current":  echo["emotion"]["morale_current"],
		"fear_current":    echo["emotion"]["fear_current"]
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
