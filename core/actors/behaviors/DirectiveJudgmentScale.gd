# res://core/actors/behaviors/DirectiveJudgmentScale.gd
# The one Judgment scale on Directive influence. Read by exposure acceptance (BehaviorArbiter)
# and by the Directive stop cause (StopShortService). `cfg` is data.combat.movement.directive_judgment.
# Pure and static, no dependencies, so both callers can use it.

class_name DirectiveJudgmentScale


## floor + (1 - floor) x (1 - J). 1.0 when `cfg` has no floor.
static func scale(judgment: float, cfg: Dictionary) -> float:
	if not cfg.has("judgment_floor"):
		return 1.0
	var floor_v: float = float(cfg["judgment_floor"])
	return floor_v + (1.0 - floor_v) * (1.0 - clampf(judgment, 0.0, 1.0))


## True when the floor is a finite number in [judgment_floor_min, 1]. A missing floor is valid.
static func is_valid(cfg: Dictionary) -> bool:
	if not cfg.has("judgment_floor"):
		return true
	var floor_v: Variant = cfg["judgment_floor"]
	if not (floor_v is int or floor_v is float) or not is_finite(float(floor_v)):
		return false
	return float(floor_v) >= float(cfg.get("judgment_floor_min", 0.0)) and float(floor_v) <= 1.0


## Swing: `own_side` over the scale at J = 1, which is the floor. `own_side` is the multiplier on the
## Echo's own side at J = 1 (1.0 when nothing else scales with J). Without a floor the swing is `own_side`.
static func swing(cfg: Dictionary, own_side: float = 1.0) -> float:
	if not cfg.has("judgment_floor"):
		return own_side
	var floor_v: float = float(cfg["judgment_floor"])
	if floor_v <= 0.0:
		return INF
	return own_side / floor_v
