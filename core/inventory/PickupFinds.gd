class_name PickupFinds
extends RefCounted

## Seam S1: the finds of one won fight. `count` comes from `FindsRules.roll_count`. Pure, no RNG.
## Shipping has no source, so it returns []. `armed` is the debug override (V2-ITEM-001b C10): a list of
## finds ({ find_id, type_id, kind, grade, quantity }); the first `count` of them are offered, as copies.


# UNWIRED (target: V2-ITEM-002): real finds in real fights
static func finds_for_win(count: int, armed: Array = []) -> Array:
	return armed.slice(0, maxi(0, count)).map(func(f: Variant) -> Variant:
		return (f as Dictionary).duplicate(true) if f is Dictionary else f)
