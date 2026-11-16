# res://tests/fixtures/PickupRealBoard.gd
# A REAL flow.pickup snapshot for screenshots (V2-ITEM-001b U4). It plays a real won fight on realm.01 stage.0
# through FlowRuntime (the same helpers the pickup tests use), with armed finds and held pieces, and returns the
# snapshot the app would publish: real board size, terrain, placement seed, actors, pack, swap and allowances.
# Nothing is hand-written. It writes save files under ECHOES_TEST_SAVE_DIR (or the test default) and removes them.
# Run it only from tools that set ECHOES_TEST_SAVE_DIR to a fresh directory (scripts/screenshot.gd, step "real_pickup:").
extends RefCounted

const SCENES := {
	"empty": { "held": [], "finds": ["ph_weapon_a", "ph_relic_a"], "cap": 2 },
	"near": { "held": ["ph_armor_a", "ph_charm_a"], "finds": ["ph_consumable_a"], "cap": 1 },
	"full": { "held": ["ph_armor_a", "ph_charm_a", "ph_relic_a", "ph_weapon_a"], "finds": ["ph_consumable_a"], "cap": 1 },
}


## `kind`: empty (pack empty, two finds taken), near (two held pieces, one find taken), full (pack full, one find left).
## `phase`: "idle" (the intro is skipped) or "intro" (the first publish). {} when the fight did not reach the event.
static func snapshot(kind: String, phase: String = "idle") -> Dictionary:
	var spec_v: Variant = SCENES.get(kind, {})
	if not (spec_v is Dictionary) or (spec_v as Dictionary).is_empty():
		return {}
	var spec: Dictionary = spec_v
	var held: Array = spec["held"]
	var finds: Array = spec["finds"]
	var cfg := PickupFlowTests._cfg(4, int(spec["cap"]))
	var prepare := func(env: Dictionary) -> void:
		PickupFlowTests._prepare(env, cfg, PickupStateTests._finds(finds), false, -1)
		var fc_prepare: FlowContext = env["flow_ctx"]
		for i in held.size():
			ItemPacksTests._hold(fc_prepare, 1, i + 1, str(held[i]))
	var env := PickupCharacterizationTests._won_fight("pickup_shot_" + kind, prepare)
	if not bool(env.get("ok", false)):
		return {}
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	if phase != "intro":
		rt.dispatch({ "type": "pickup.skip", "payload": {} })
	var snap: Dictionary = fc.last_snapshot.duplicate(true)
	PickupFlowTests._done(env)
	if str(snap.get("type", "")) != FlowStateIds.PICKUP:
		return {}
	return snap
