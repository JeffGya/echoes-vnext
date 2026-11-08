extends PanelContainer

## A panel that takes a drop anywhere on it (not on a slot): the piece goes to the first free slot, or is refused.
## Callables are set by InventoryPanels.

signal drop_requested(data: Dictionary, box: String)
signal hover_changed(box: String, plan: Dictionary)

var box := ""
var planner: Callable = Callable()


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not bool((data as Dictionary).get("item_drag", false)) or not planner.is_valid():
		return false
	var p: Dictionary = planner.call(data, box, -1)
	hover_changed.emit(box, p)
	return str(p.get("kind", "")) != "none"


func _drop_data(_at: Vector2, data: Variant) -> void:
	drop_requested.emit(data, box)
