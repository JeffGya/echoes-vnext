class_name CombatTokenVisualConfig
extends Resource

@export var token_radius: float = 20.0
@export var structure_half_size: float = 20.0
@export var feet_offset_y: float = 0.0

@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.28)
@export var shadow_size: Vector2 = Vector2(32.0, 10.0)
@export var shadow_offset: Vector2 = Vector2(0.0, 18.0)

@export var move_duration: float = 0.18
@export var telegraph_lead_time: float = 0.10
@export var telegraph_half_size: Vector2 = Vector2(64.0, 32.0)
@export var telegraph_fill_color: Color = Color(1.0, 0.9, 0.25, 0.18)
@export var telegraph_outline_color: Color = Color(1.0, 0.92, 0.45, 0.95)
@export var telegraph_outline_width: float = 3.0

@export var active_ring_color: Color = Color(1.0, 0.92, 0.35, 1.0)
@export var active_ring_width: float = 2.5
@export var active_ring_padding: float = 4.0

@export var hp_bar_offset_y: float = 10.0
@export var hp_bar_height: float = 4.0
@export var hp_bar_background_color: Color = Color(0.15, 0.15, 0.15, 1.0)
