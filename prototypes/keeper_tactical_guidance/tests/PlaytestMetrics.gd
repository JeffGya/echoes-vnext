class_name KeeperGuidancePlaytestMetrics
extends RefCounted

## Read-only formatter used by debug/playtest tooling. It consumes the real simulation
## metrics and timeline contracts; it does not introduce test-only combat behavior.


static func summarize(snapshot_data: Dictionary) -> Dictionary:
	var metrics: Dictionary = snapshot_data.get("metrics", {})
	var responses: Dictionary = metrics.get("responses", {})
	var non_align: int = int(responses.get("interpret", 0)) + int(responses.get("hesitate", 0)) \
		+ int(responses.get("object", 0)) + int(responses.get("refuse", 0))
	return {
		"turns_completed": int(metrics.get("turns_completed", 0)),
		"rounds_completed": int(metrics.get("rounds_completed", 0)),
		"pings_confirmed": int(metrics.get("pings_confirmed", 0)),
		"responses_total": int(metrics.get("response_count", 0)),
		"non_align_responses": non_align,
		"hazard_events": int(metrics.get("hazard_events", 0)),
		"hazard_damage": int(metrics.get("hazard_damage", 0)),
		"hazard_forced_moves": int(metrics.get("hazard_forced_moves", 0)),
		"objective_events": int(metrics.get("objective_events", 0)),
		"timeline_events": (snapshot_data.get("timeline", []) as Array).size(),
	}
