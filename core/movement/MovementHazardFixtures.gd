# res://core/movement/MovementHazardFixtures.gd
# V2-COMBAT-002 Slice 3: deterministic authored-hazard fixture provider.
#
# Pure, all-static, no RNG. Stands in for COMBAT-004's future hazard generator so the
# executor + tests have fixed hazard fact sets on a known board. Slice 6 uses
# authored_set() as the approved combat-board hazard field. Facts conform to
# MovementKnownHazardFact.build().

class_name MovementHazardFixtures
extends RefCounted

const HazardFact = preload("res://core/movement/contracts/MovementKnownHazardFact.gd")

## Known 10x10 test board bounds.
const BOARD_BOUNDS: Dictionary = {"w": 10, "h": 10}


static func board_bounds() -> Dictionary:
	return BOARD_BOUNDS.duplicate(true)


## Empty walkable dict == StageTerrain all-walkable sentinel (bounds still constrain).
static func walkable_open() -> Dictionary:
	return {}


static func _pos(col: int, row: int) -> Dictionary:
	return {"col": col, "row": row}


static func unstable_at(position: Dictionary, hazard_id: String = "hazard.unstable.0") -> Array:
	return [HazardFact.build(hazard_id, position, "unstable")]


static func binding_at(position: Dictionary, hazard_id: String = "hazard.binding.0") -> Array:
	return [HazardFact.build(hazard_id, position, "binding")]


static func burning_at(position: Dictionary, hazard_id: String = "hazard.burning.0") -> Array:
	return [HazardFact.build(hazard_id, position, "burning")]


## A fixed combined authored hazard field on the known board — one of each type at
## distinct cells along the mid row. Deterministic, order-stable.
static func authored_set() -> Array:
	return [
		HazardFact.build("hazard.unstable.a", _pos(3, 5), "unstable"),
		HazardFact.build("hazard.binding.a", _pos(6, 5), "binding"),
		HazardFact.build("hazard.burning.a", _pos(8, 5), "burning"),
	]
