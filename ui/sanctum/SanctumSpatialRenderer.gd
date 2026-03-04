extends Node2D
class_name SanctumSpatialRenderer

@onready var floor: TileMapLayer = $Floor

func render(_snap: Dictionary) -> void:
	# Phase B: render is intentionally a no-op.
	# We only need the scene alive behind the UI.
	pass
