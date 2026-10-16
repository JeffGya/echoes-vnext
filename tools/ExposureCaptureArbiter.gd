# res://tools/ExposureCaptureArbiter.gd
#
# INVESTIGATION TOOL — not a test. A BehaviorArbiter that records every scored candidate of
# one select_movement_intent pass, so the log and the chosen move come from the same pass.
#
# `_apply_guidance` runs after every score term (spatial, style, vow, bond) and before the
# sort, so the snapshot taken there is the score the sort compares. Purifier overrides and the
# legacy purifier candidate come later and are not recorded (no purifier in a probe board).
# Behaviour is unchanged: the override calls `super` and only reads.

class_name ExposureCaptureArbiter
extends BehaviorArbiter

const PART_KEYS: Array = [
	"urgency", "objective_progress", "cohesion", "exposure", "congestion", "commitment",
	"directive_objective_advance", "directive_avoid_overcommit", "directive_exposure_acceptance",
	"directive_ally_protection", "directive_threat_interception",
]
const PART_SHORT: Array = ["urg", "prog", "coh", "exp", "con", "com", "dadv", "davoid", "dexp", "dally", "dicpt"]

## {records: Array, chosen: Dictionary} of the latest pass; empty when the pass failed.
var last: Dictionary = {}
var _pending: Array = []


func _apply_guidance(candidates: Array, context: Dictionary, actor: Dictionary, is_movement: bool, capacity: int) -> Dictionary:
	var response: Dictionary = super(candidates, context, actor, is_movement, capacity)
	if is_movement:
		_pending = _snapshot(candidates)
	return response


func select_movement_intent(context: Dictionary, movement_context: Dictionary, profile: Dictionary, goals: Array, options: Array) -> Dictionary:
	_pending = []
	last = {}
	var result: Dictionary = super(context, movement_context, profile, goals, options)
	if bool(result.get("valid", false)) and not _pending.is_empty():
		var intent: Dictionary = result["intent"] as Dictionary
		var planned: Dictionary = intent.get("planned_action", {}) as Dictionary
		last = {
			"records": _pending,
			"chosen": {
				"goal_id": str(intent.get("goal_id", "")),
				"option_id": str(intent.get("option_id", "")),
				"type": str(planned.get("type", "")),
				"target_id": str(planned.get("target_id", "")),
			},
		}
	return result


static func _snapshot(candidates: Array) -> Array:
	var records: Array = []
	for candidate_v: Variant in candidates:
		var candidate: Dictionary = candidate_v
		var option: Dictionary = candidate.get("_movement_option", {}) as Dictionary
		var spatial: Dictionary = candidate.get("_spatial_components", {}) as Dictionary
		var bias: Dictionary = candidate.get("_score_bias", {}) as Dictionary
		var plan: Dictionary = candidate.get("_movement_plan", {}) as Dictionary
		records.append({
			"route": bool(candidate.get("_movement_route", false)),
			"goal_id": str(candidate.get("_movement_goal_id", "")),
			"option_id": str(candidate.get("_movement_option_id", "")),
			"type": str(plan.get("type", "")),
			"target_id": str(candidate.get("target_id", "")),
			"exposure": float(option.get("exposure", 0.0)),
			"progress": float(option.get("objective_progress", 0.0)),
			"parts": (spatial.get("parts", {}) as Dictionary).duplicate(),
			"raw": float(spatial.get("raw", 0.0)),
			"cap": float(spatial.get("cap", 0.0)),
			"value": float(spatial.get("value", 0.0)),
			"style": float(bias.get("movement_style", 0.0)),
			"score": float(candidate.get("_score", 0.0)),
		})
	return records


static func is_chosen(record: Dictionary, chosen: Dictionary) -> bool:
	return str(record["goal_id"]) == str(chosen["goal_id"]) and str(record["option_id"]) == str(chosen["option_id"]) \
		and str(record["type"]) == str(chosen["type"]) and str(record["target_id"]) == str(chosen["target_id"])


## Score with the Directive exposure part (which carries the fear lean) taken out and the
## spatial clamp re-applied to the remaining raw sum.
static func score_without_acceptance(record: Dictionary) -> float:
	if not bool(record["route"]):
		return float(record["score"])
	var removed: float = float((record["parts"] as Dictionary).get("directive_exposure_acceptance", 0.0))
	var cap: float = float(record["cap"])
	return float(record["score"]) - float(record["value"]) + clampf(float(record["raw"]) - removed, -cap, cap)


## Same tie-break order as the arbiter sort: score, action type, goal id, option id.
static func argmax(records: Array, removed: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = 0.0
	for record_v: Variant in records:
		var record: Dictionary = record_v
		var score: float = score_without_acceptance(record) if removed else float(record["score"])
		var wins: bool = best.is_empty() or score > best_score
		if not wins and score == best_score:
			wins = [str(record["type"]), str(record["goal_id"]), str(record["option_id"])] \
				< [str(best["type"]), str(best["goal_id"]), str(best["option_id"])]
		if wins:
			best = record
			best_score = score
	return best


static func analyse(records: Array, chosen: Dictionary) -> Dictionary:
	var routes: Array = []
	for record_v: Variant in records:
		if bool((record_v as Dictionary)["route"]):
			routes.append(record_v)
	var scores: Array = []
	var exposures: Dictionary = {}
	var any_exposed: bool = false
	var any_clear: bool = false
	var best_route: Dictionary = {}
	for route_v: Variant in routes:
		var route: Dictionary = route_v
		scores.append(float(route["score"]))
		exposures[snappedf(float(route["exposure"]), 0.0001)] = true
		any_exposed = any_exposed or float(route["exposure"]) > 0.0
		any_clear = any_clear or float(route["exposure"]) <= 0.0
		if best_route.is_empty() or float(route["score"]) > float(best_route["score"]):
			best_route = route
	scores.sort()
	scores.reverse()
	var best: float = float(scores[0]) if scores.size() > 0 else 0.0
	var second: float = float(scores[1]) if scores.size() > 1 else best
	var xmargin: float = -1.0
	for route_v: Variant in routes:
		var route: Dictionary = route_v
		if not best_route.is_empty() and snappedf(float(route["exposure"]), 0.0001) != snappedf(float(best_route["exposure"]), 0.0001):
			var gap: float = float(best_route["score"]) - float(route["score"])
			if xmargin < 0.0 or gap < xmargin:
				xmargin = gap
	var best_removed: float = -INF
	for route_v: Variant in routes:
		best_removed = maxf(best_removed, score_without_acceptance(route_v))
	var chosen_record: Dictionary = {}
	for record_v: Variant in records:
		if is_chosen(record_v, chosen):
			chosen_record = record_v
			break
	var argmax_removed: Dictionary = argmax(records, true)
	return {
		"options": routes.size(),
		"distinct_exposures": exposures.size(),
		"best": best,
		"second": second,
		"margin": best - second,
		"xmargin": xmargin,
		"mixed": any_exposed and any_clear,
		"chosen_route": bool(chosen_record.get("route", false)),
		"chosen_exposed": float(chosen_record.get("exposure", 0.0)) > 0.0,
		"best_removed": best_removed if routes.size() > 0 else 0.0,
		"flips": not argmax_removed.is_empty() and not is_chosen(argmax_removed, chosen),
	}


static func decision_lines(tag: String, records: Array, chosen: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for record_v: Variant in records:
		var record: Dictionary = record_v
		if not bool(record["route"]):
			continue
		var parts: Dictionary = record["parts"] as Dictionary
		var pieces: PackedStringArray = []
		for index: int in range(PART_KEYS.size()):
			pieces.append("%s=%.2f" % [PART_SHORT[index], float(parts.get(PART_KEYS[index], 0.0))])
		lines.append("DECISION %s opt=%s plan=%s exp=%.3f prog=%.3f %s raw=%.2f spatial=%.2f style=%.3f score=%.3f chosen=%d" % [
			tag, str(record["option_id"]), str(record["type"]), float(record["exposure"]), float(record["progress"]),
			" ".join(pieces), float(record["raw"]), float(record["value"]), float(record["style"]),
			float(record["score"]), 1 if is_chosen(record, chosen) else 0,
		])
	return lines


static func turnsum_line(tag: String, summary: Dictionary) -> String:
	return "TURNSUM %s options=%d distinct_exp=%d best=%.3f second=%.3f margin=%.3f xmargin=%s mixed=%d chosen_route=%d chosen_exposed=%d best_without_dexp=%.3f flips=%d" % [
		tag, int(summary["options"]), int(summary["distinct_exposures"]), float(summary["best"]), float(summary["second"]),
		float(summary["margin"]), "-" if float(summary["xmargin"]) < 0.0 else "%.3f" % float(summary["xmargin"]),
		1 if bool(summary["mixed"]) else 0, 1 if bool(summary["chosen_route"]) else 0,
		1 if bool(summary["chosen_exposed"]) else 0, float(summary["best_removed"]), 1 if bool(summary["flips"]) else 0,
	]
