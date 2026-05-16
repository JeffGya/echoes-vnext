# res://ui/components/BondTierBar.gd
# BOND-001: Visual tier bar showing the 11-step bond strength scale.
# Structure is fully authored in BondTierBar.tscn.
# This script only updates visibility (modulate) and the tier name label.
#
# Cell names (left to right): Cell_N5 .. Cell_0 .. Cell_P5
# Tier int range: -5 .. 0 .. +5
# Default state: tier 0 (Indifferent), centre cell active.

extends Control

@onready var tier_name_label: Label = %TierNameLabel
var _pending_tier: int = 0

const _CELL_NAMES: Array = [
	"Cell_N5", "Cell_N4", "Cell_N3", "Cell_N2", "Cell_N1",
	"Cell_0",
	"Cell_P1", "Cell_P2", "Cell_P3", "Cell_P4", "Cell_P5",
]

const _TIER_NAMES: Array = [
	"Nemesis", "Rival", "Resentful", "Tense", "Wary",
	"Indifferent",
	"Familiar", "Friendly", "Trusted", "Bonded", "Kindred",
]

const _DIM_ALPHA: float = 0.28
const _ACTIVE_ALPHA: float = 1.0
const _ACTIVE_SCALE: Vector2 = Vector2(1.1, 1.1)
const _DEFAULT_SCALE: Vector2 = Vector2.ONE


func _ready() -> void:
	set_tier(_pending_tier)


## Sets the active tier and updates all cell modulate values + the tier name label.
## tier must be in range -5..+5.
func set_tier(tier: int) -> void:
	_pending_tier = tier
	if not is_node_ready():
		return
	var active_idx: int = clampi(tier + 5, 0, 10)
	for i in range(11):
		var cell := find_child(_CELL_NAMES[i], true, false) as Control
		if cell == null:
			continue
		cell.modulate = Color(1.0, 1.0, 1.0, _ACTIVE_ALPHA if i == active_idx else _DIM_ALPHA)
		cell.scale = _ACTIVE_SCALE if i == active_idx else _DEFAULT_SCALE
	if tier_name_label != null:
		tier_name_label.text = _TIER_NAMES[active_idx]
