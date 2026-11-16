class_name PickupEventStage
extends Control

## The pickup event, drawn over the combat board (V2-ITEM-001b). The stage owns no input and
## never emits an action: the event motion and its buttons come in later steps.
## An event is named by situation_id + run_count. A repeat snapshot of the same event must not
## restart anything, so state is rebuilt only when the identity changes.

var _identity: String = ""
var _starts: int = 0


static func identity_of(data: Dictionary) -> String:
	return "%s#%d" % [str(data.get("situation_id", "")), int(data.get("run_count", 0))]


func apply_snapshot(snapshot: Dictionary) -> void:
	var data_v: Variant = snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var next := identity_of(data)
	if next == _identity:
		return
	_identity = next
	_starts += 1


## Called when the board leaves the event. The next event starts fresh even with the same identity.
func clear() -> void:
	_identity = ""


func identity() -> String:
	return _identity


func start_count() -> int:
	return _starts
