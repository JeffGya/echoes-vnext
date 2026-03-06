# res://tests/PartyTests.gd
extends RefCounted
class_name PartyTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("sanctum.party/toggle_confirm_persists",     Callable(PartyTests, "_t_toggle_confirm_persists"))
	runner.register_test("sanctum.party/double_toggle_removes",       Callable(PartyTests, "_t_double_toggle_removes"))
	runner.register_test("sanctum.party/over_cap_capped",             Callable(PartyTests, "_t_over_cap_capped"))
	runner.register_test("sanctum.party/empty_roster_snapshot_valid", Callable(PartyTests, "_t_empty_roster_snapshot_valid"))

# -------------------------
# Tests
# -------------------------

# Test 1: toggle_confirm_persists
# Steps:
#   1. Boot runtime (new game; starter echo is added to roster automatically)
#   2. Add 500 Ase so the economy state is settled and non-zero
#   3. Go to flow.party_manage
#   4. Read the first echo id from save_data.sanctum.roster
#   5. Dispatch sanctum.party.toggle with that echo_id (adds it to pending)
#   6. Dispatch sanctum.party.confirm (persists pending → active_party_ids in save)
#   7. Assert save_data.sanctum.active_party_ids contains the echo_id
static func _t_toggle_confirm_persists() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]

	# Step 2: seed Ase so economy is non-zero (no affect on party logic)
	runtime.dispatch({ "type": "economy.ase.add", "amount": 500, "reason": "test.seed" })

	# Reset active_party_ids so pending starts empty when entering party_manage.
	# boot() loads the existing save which may already have a full party (5/5),
	# causing subsequent toggles to be silently rejected by the cap check.
	var save_ref: Dictionary = runtime.get_save_data()
	var sanctum_ref_v: Variant = save_ref.get("sanctum", {})
	var sanctum_ref: Dictionary = sanctum_ref_v if sanctum_ref_v is Dictionary else {}
	sanctum_ref["active_party_ids"] = []
	save_ref["sanctum"] = sanctum_ref

	# Step 3: navigate to party manage
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.party_manage" })

	# Step 4: read first echo id from roster
	var save: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot — expected at least 1 starter echo" }

	var first_v: Variant = roster[0]
	if not (first_v is Dictionary):
		return { "ok": false, "error": "roster[0] is not a Dictionary" }
	var echo_id := str((first_v as Dictionary).get("id", ""))
	if echo_id.is_empty():
		return { "ok": false, "error": "roster[0].id is empty" }

	# Step 5: toggle echo into pending party
	runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })

	# Step 6: confirm — persists pending_party_ids to save_data.sanctum.active_party_ids
	runtime.dispatch({ "type": "sanctum.party.confirm" })

	# Step 7: assert active_party_ids contains the echo_id
	var save_after: Dictionary = runtime.get_save_data()
	var sanctum2_v: Variant = save_after.get("sanctum", {})
	var sanctum2: Dictionary = sanctum2_v if sanctum2_v is Dictionary else {}
	var active_v: Variant = sanctum2.get("active_party_ids", [])
	var active: Array = active_v if active_v is Array else []

	if not active.has(echo_id):
		return {
			"ok": false,
			"error": "active_party_ids does not contain echo_id=%s after confirm. active=%s" % [echo_id, str(active)]
		}

	return { "ok": true }


# Test 2: double_toggle_removes
# Steps:
#   1. Boot runtime
#   2. Go to flow.party_manage
#   3. Read first echo id from roster
#   4. Dispatch sanctum.party.toggle (adds echo to pending) — capture snap1
#   5. Dispatch sanctum.party.toggle again with the same echo_id (removes it) — capture snap2
#   6. Assert snap2.actions.primary.enabled == false (pending is now empty, confirm disabled)
static func _t_double_toggle_removes() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]

	# Reset active_party_ids so pending starts empty when entering party_manage.
	# boot() loads the existing save which may already have a full party (5/5),
	# causing the first toggle to be rejected and the second to be a no-op.
	var save_ref: Dictionary = runtime.get_save_data()
	var sanctum_ref_v: Variant = save_ref.get("sanctum", {})
	var sanctum_ref: Dictionary = sanctum_ref_v if sanctum_ref_v is Dictionary else {}
	sanctum_ref["active_party_ids"] = []
	save_ref["sanctum"] = sanctum_ref

	# Step 2
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.party_manage" })

	# Step 3: read first echo id
	var save: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot — expected at least 1 starter echo" }

	var first_v: Variant = roster[0]
	if not (first_v is Dictionary):
		return { "ok": false, "error": "roster[0] is not a Dictionary" }
	var echo_id := str((first_v as Dictionary).get("id", ""))
	if echo_id.is_empty():
		return { "ok": false, "error": "roster[0].id is empty" }

	# Step 4: first toggle — adds echo
	runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })

	# Step 5: second toggle — removes the same echo
	var snap2: Dictionary = runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })

	# Step 6: assert primary.enabled == false (empty pending → confirm disabled)
	var actions_v: Variant = snap2.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var primary_v: Variant = actions.get("primary", {})
	var primary: Dictionary = primary_v if primary_v is Dictionary else {}
	var enabled := bool(primary.get("enabled", true))

	if enabled:
		return {
			"ok": false,
			"error": "Expected primary.enabled=false after double-toggle (echo removed from pending), but got true"
		}

	return { "ok": true }


# Test 3: over_cap_capped
# Steps:
#   1. Boot runtime (1 starter echo in roster)
#   2. Add 500 Ase and summon 5 more echoes → 6 total in roster
#   3. Go to flow.party_manage
#   4. Read all 6 echo ids from roster
#   5. Toggle all 6 one by one
#   6. Assert final snapshot data.active_party_ids.size() <= max_party_size (5), no crash
static func _t_over_cap_capped() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]

	# Step 2: summon 5 more echoes (starter already in roster from boot)
	runtime.dispatch({ "type": "economy.ase.add", "amount": 500, "reason": "test.seed" })
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.summon" })
	var now_unix := 444444
	var save_ref: Dictionary = runtime.get_save_data()
	var econ_v: Variant = save_ref.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	econ["last_settle_unix"] = now_unix
	save_ref["economy"] = econ
	runtime.dispatch({ "type": "sanctum.summon", "count": 5, "now_unix": now_unix })

	# Step 3: navigate to party manage
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.party_manage" })

	# Step 4: read all echo ids from roster
	var save: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	if roster.size() < 6:
		return {
			"ok": false,
			"error": "Expected at least 6 echoes in roster (1 starter + 5 summons), got %d" % roster.size()
		}

	# Step 5: toggle all 6 echoes
	var last_snap: Dictionary = {}
	for i in range(6):
		var e_v: Variant = roster[i]
		if not (e_v is Dictionary):
			continue
		var eid := str((e_v as Dictionary).get("id", ""))
		if eid.is_empty():
			continue
		last_snap = runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": eid } })

	# Step 6: assert pending size is capped at 5
	var data_v: Variant = last_snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var pending_v: Variant = data.get("active_party_ids", [])
	var pending: Array = pending_v if pending_v is Array else []

	if pending.size() > 5:
		return {
			"ok": false,
			"error": "Expected active_party_ids.size() <= 5 after toggling 6 echoes, got %d" % pending.size()
		}

	return { "ok": true }


# Test 4: empty_roster_snapshot_valid
# Steps:
#   1. Boot runtime
#   2. Clear save_data.sanctum.roster and active_party_ids via direct mutation of save reference
#   3. Dispatch flow.go_state to flow.party_manage
#   4. Assert returned snapshot has: type == "flow.party_manage", data.roster == [],
#      actions.has("back"), actions.has("primary") — no crash, valid shape
static func _t_empty_roster_snapshot_valid() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]

	# Step 2: clear the roster and active_party_ids in the save reference
	var save_ref: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save_ref.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	sanctum["roster"] = []
	sanctum["active_party_ids"] = []
	save_ref["sanctum"] = sanctum

	# Step 3: navigate to party manage
	var snap: Dictionary = runtime.dispatch({ "type": "flow.go_state", "to": "flow.party_manage" })

	# Step 4: assert snapshot shape is valid
	if str(snap.get("type", "")) != "flow.party_manage":
		return { "ok": false, "error": "Expected type=flow.party_manage, got: %s" % str(snap.get("type", "")) }

	var data_v: Variant = snap.get("data", {})
	if not (data_v is Dictionary):
		return { "ok": false, "error": "snap.data is not a Dictionary" }
	var data: Dictionary = data_v

	var roster_v: Variant = data.get("roster", null)
	if not (roster_v is Array):
		return { "ok": false, "error": "snap.data.roster is not an Array" }
	if (roster_v as Array).size() != 0:
		return { "ok": false, "error": "Expected empty roster array, got size %d" % (roster_v as Array).size() }

	var actions_v: Variant = snap.get("actions", {})
	if not (actions_v is Dictionary):
		return { "ok": false, "error": "snap.actions is not a Dictionary" }
	var actions: Dictionary = actions_v

	if not actions.has("back"):
		return { "ok": false, "error": "snap.actions missing 'back' slot" }
	if not actions.has("primary"):
		return { "ok": false, "error": "snap.actions missing 'primary' slot" }

	return { "ok": true }


# -------------------------
# Helper
# -------------------------

static func _make_runtime_env() -> Dictionary:
	var FlowRuntimeScript := load("res://core/runtime/FlowRuntime.gd")
	var ConfigServiceScript := load("res://core/config/ConfigService.gd")
	var StructuredLoggerScript := load("res://core/log/StructuredLogger.gd")

	if FlowRuntimeScript == null:
		return { "ok": false, "error": "FlowRuntime script not found" }
	if ConfigServiceScript == null:
		return { "ok": false, "error": "ConfigService script not found" }
	if StructuredLoggerScript == null:
		return { "ok": false, "error": "StructuredLogger script not found" }

	var logger = StructuredLoggerScript.new()
	logger.set_level("off")

	var config = ConfigServiceScript.new()
	var runtime = FlowRuntimeScript.new(logger, config)
	runtime.boot()

	if not runtime.has_method("get_save_data"):
		return { "ok": false, "error": "FlowRuntime.get_save_data() missing" }

	return { "ok": true, "runtime": runtime }
