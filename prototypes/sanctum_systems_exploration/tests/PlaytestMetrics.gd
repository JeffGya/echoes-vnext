extends RefCounted
## Observation instrumentation only. Never an input to house resolution.

var counts: Dictionary = {"world_selections": 0, "observe_requests": 0, "keeper_replies": 0}
var seconds: Dictionary = {"world": 0.0, "context": 0.0, "reference": 0.0}


func record_action(type: String) -> void:
	match type:
		"prototype.subject.select": counts.world_selections += 1
		"prototype.subject.observe": counts.observe_requests += 1
		"prototype.conversation.reply": counts.keeper_replies += 1


func sample(delta: float, channel: String) -> void:
	seconds[channel] = float(seconds[channel]) + delta


func report() -> Dictionary:
	return {"counts": counts.duplicate(true), "seconds": seconds.duplicate(true),
		"note": "Counts measure input, not recognition, voluntary interest, or attachment. Record those with Jeff."}
