class_name PickupChooser
extends RefCounted

## Who chooses in the pickup event (D-05) and how the pointer plays it (D-21). Pure statics, no writes.
## Stream: `inventory.pick.<stage_id>.<run_count>.<situation_id>`. It must never share a path with
## `stage.settle.*`, `inventory.leave.*` or `inventory.finds.*`.

## Pointer laps before the slow-down, as in the approved mockup (`pointerFor`: 1 or 2). Presentation only.
const LAPS_MIN := 1
const LAPS_MAX := 2


static func stream_path(stage_id: String, run_count: int, situation_id: String) -> String:
	return "inventory.pick.%s.%d.%s" % [stage_id, run_count, situation_id]


## A hash path, never a stream: the pointer plan draws nothing.
static func pointer_path(stage_id: String, run_count: int, situation_id: String) -> String:
	return "inventory.pointer.%s.%d.%s" % [stage_id, run_count, situation_id]


## The Echoes that may be drawn: `party_ids` in its own order (pass `sanctum.active_party_ids`, which is
## party slot order) minus every id in `fallen_ids`. Empty ids and repeats are dropped (first stays).
static func standing_ids(party_ids: Array, fallen_ids: Array) -> Array:
	var fallen := {}
	for f in fallen_ids:
		fallen[str(f)] = true
	var out: Array = []
	for id_v in party_ids:
		var id := str(id_v)
		if not id.is_empty() and not out.has(id) and not fallen.has(id):
			out.append(id)
	return out


## { chooser_id, index, n }. n == 0 makes no draw and gives { "", -1, 0 }: the event then has no chooser.
static func draw(realm_seed: int, stage_id: String, run_count: int, situation_id: String, standing: Array) -> Dictionary:
	var n := standing.size()
	if n < 1:
		return { "chooser_id": "", "index": -1, "n": 0 }
	var index := draw_with(CampaignSeed.get_rng_from(realm_seed, stream_path(stage_id, run_count, situation_id)), n)
	return { "chooser_id": str(standing[index]), "index": index, "n": n }


## Exactly one `randi_range(0, n - 1)` for every n >= 1 (also n == 1); none and -1 for n < 1.
## `randi_range(0, 0)` leaves the generator state unchanged in Godot 4.6, so n == 1 leaves no trace; the
## call stays so the code path is the same for every n.
static func draw_with(rng: RandomNumberGenerator, n: int) -> int:
	if n < 1:
		return -1
	return rng.randi_range(0, n - 1)


## { n, start, laps } for the pointer light. Start is never the chooser when n >= 2. n == 1 gives start 0.
## An empty row or a chooser index outside the row gives { n, -1, 0 }.
static func pointer(realm_seed: int, stage_id: String, run_count: int, situation_id: String, n: int,
		chooser_index: int) -> Dictionary:
	if n < 1 or chooser_index < 0 or chooser_index >= n:
		return { "n": maxi(n, 0), "start": -1, "laps": 0 }
	var h := CampaignSeed.derive_from(realm_seed, pointer_path(stage_id, run_count, situation_id))
	var start: int = 0 if n == 1 else (chooser_index + 1 + h % (n - 1)) % n
	return { "n": n, "start": start, "laps": LAPS_MIN + (h >> 32) % (LAPS_MAX - LAPS_MIN + 1) }
