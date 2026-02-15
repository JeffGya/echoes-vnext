class_name State

extends RefCounted

var _id: String

func _init(id: String) -> void:
	_id = id

func get_id() -> String:
	return _id
	
# Lifecycle hooks (deterministic; caller inject t)
func enter(ctx: RefCounted, t: int) -> void:
	pass

func exit(ctx: RefCounted, t: int) -> void:
	pass
