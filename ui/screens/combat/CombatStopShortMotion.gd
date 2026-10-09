# res://ui/screens/combat/CombatStopShortMotion.gd
# Timing, shape and pose maths for the stop-short tell (decisions.md #109). No nodes, no draw calls.
# Times are Normal-speed seconds; callers scale them by the speed's motion scale (Slow 1.6, Fast 0).

extends RefCounted

# Seconds: dip, hold at the bottom, rise, hold at the top, fall. Their sum is the landing time.
const HOP_STEPS: Dictionary = {
	"guard":   [0.08, 0.02, 0.15, 0.0, 0.09],
	"hold":    [0.08, 0.02, 0.15, 0.0, 0.11],
	"observe": [0.0, 0.0, 0.16, 0.10, 0.08],
}
const DIP_UNITS: Dictionary = { "guard": 5.0, "hold": 4.0, "observe": 0.0 }
const SHAKE_UNITS: Array = [3.0, 1.5]
const SHAKE_TIME: float = 0.10
const REBOUND_UNITS: float = 2.0
const REBOUND_TIME: float = 0.08
const RIPPLE_TIME: float = 0.30
const POP_TIME: float = 0.16
const POSE_DELAY: Dictionary = { "guard": 0.10, "hold": 0.08 }
const POSE_TIME: float = 0.20


static func settle_time(benefit: String, motion_scale: float) -> float:
	var total: float = 0.0
	for step_v in HOP_STEPS.get(benefit, []):
		total += float(step_v)
	return total * motion_scale


static func pose_return_time(motion_scale: float) -> float:
	return 0.06 if motion_scale <= 0.0 else (0.12 if motion_scale <= 1.0 else 0.20)


## World units of lift at the hop's peak. Guard and Hold follow the zoom; Observe is fixed.
static func hop_lift(benefit: String, zoom: float) -> float:
	var guard_lift: float = clampf(22.0 / maxf(zoom, 0.01), 16.0, 28.0)
	match benefit:
		"guard":
			return guard_lift
		"hold":
			return guard_lift * 0.875
		"observe":
			return 10.0
	return 0.0


## Marker scale: keeps the marker readable when zoomed out, capped so it never reaches a neighbour.
static func view_scale(zoom: float) -> float:
	return clampf(1.0 / maxf(zoom, 0.01), 1.0, 2.0)


static func lean_distance(zoom: float) -> float:
	return clampf(8.0 / maxf(zoom, 0.01), 6.0, 8.0)


static func hold_body_scale(zoom: float) -> float:
	return 0.78 if zoom < 0.6 else 0.85


static func pose_amount(pose: float) -> float:
	return 1.0 - (1.0 - pose) * (1.0 - pose)


## Height above the ground (negative in the dip) at `progress` 0..1 of the settle time.
static func hop_height(benefit: String, progress: float, lift: float) -> float:
	if lift <= 0.0 or not HOP_STEPS.has(benefit):
		return 0.0
	var steps: Array = HOP_STEPS[benefit]
	var low: float = -float(DIP_UNITS[benefit])
	var t: float = clampf(progress, 0.0, 1.0) * settle_time(benefit, 1.0)
	if t < float(steps[0]):
		return low * _ease_in(t / float(steps[0]))
	t -= float(steps[0])
	if t < float(steps[1]):
		return low
	t -= float(steps[1])
	if t < float(steps[2]):
		return lerpf(low, lift, _ease_out(t / float(steps[2])))
	t -= float(steps[2])
	if t < float(steps[3]):
		return lift
	t -= float(steps[3])
	return lerpf(lift, 0.0, _ease_in(minf(t / float(steps[4]), 1.0)))


## The next four take `since`: Normal-speed seconds after landing, or -1 when the motion is off.
static func shake_x(since: float) -> float:
	if since < 0.0 or since >= SHAKE_TIME:
		return 0.0
	var half: float = SHAKE_TIME * 0.5
	if since < half:
		return float(SHAKE_UNITS[0]) * sin(PI * since / half)
	return -float(SHAKE_UNITS[1]) * sin(PI * (since - half) / half)


static func rebound_y(since: float) -> float:
	return REBOUND_UNITS * sin(PI * since / REBOUND_TIME) if since >= 0.0 and since < REBOUND_TIME else 0.0


## Marker pop as (radius scale, alpha). Steady (1, 1) outside the pop.
static func pop(since: float) -> Vector2:
	if since < 0.0 or since >= POP_TIME:
		return Vector2.ONE
	var u: float = since / POP_TIME
	if u < 0.6:
		return Vector2(lerpf(0.5, 1.08, _ease_out(u / 0.6)), u / 0.6)
	return Vector2(lerpf(1.08, 1.0, (u - 0.6) / 0.4), 1.0)


## Ripple as (radius progress, alpha). Alpha 0 outside the ripple.
static func ripple(since: float) -> Vector2:
	if since < 0.0 or since >= RIPPLE_TIME:
		return Vector2.ZERO
	var u: float = since / RIPPLE_TIME
	return Vector2(_ease_out(u), 0.7 * (1.0 - u))


## Angle spans (draw_arc convention) for a stance marker. `enemy_angle` NAN: Guard is a full ring.
static func shape_spans(kind: String, enemy_angle: float, radius: float, half_length: float) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	match kind:
		"hold":
			spans.append(Vector2(0.0, TAU))
		"observe":
			for diagonal in [1.0, 3.0, 5.0, 7.0]:
				var half: float = half_length / maxf(radius, 0.001)
				spans.append(Vector2(diagonal * PI * 0.25 - half, diagonal * PI * 0.25 + half))
		"guard":
			if is_nan(enemy_angle):
				spans.append(Vector2(0.0, TAU))
			else:
				spans.append(Vector2(enemy_angle - PI * 0.5, enemy_angle + PI * 0.5))
	return spans


static func is_full_ring(spans: Array[Vector2]) -> bool:
	return spans.size() == 1 and spans[0].y - spans[0].x >= TAU - 0.001


static func _ease_in(t: float) -> float:
	return t * t


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
