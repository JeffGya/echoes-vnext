# res://tests/PartyTests.gd
extends RefCounted
class_name PartyTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("sanctum.party/toggle_persists_immediately", Callable(PartyTests, "_t_toggle_persists_immediately"))
	runner.register_test("sanctum.party/double_toggle_removes", Callable(PartyTests, "_t_double_toggle_removes"))
	runner.register_test("sanctum.party/over_cap_capped", Callable(PartyTests, "_t_over_cap_capped"))
	runner.register_test("sanctum.party/empty_roster_snapshot_valid", Callable(PartyTests, "_t_empty_roster_snapshot_valid"))


static func _t_toggle_persists_immediately() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.echo_party" })

	var save: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty():
		return { "ok": false, "error": "Roster is empty after boot" }
	if not (roster[0] is Dictionary):
		return { "ok": false, "error": "roster[0] is not a Dictionary" }
	# Find an echo that is NOT already in active_party_ids.
	# If we pick one that's already active, toggling would REMOVE it, making the test fail.
	var current_active_v: Variant = sanctum.get("active_party_ids", [])
	var current_active: Array = current_active_v if current_active_v is Array else []
	var echo_id := ""
	for entry_v in roster:
		if not (entry_v is Dictionary):
			continue
		var eid := str((entry_v as Dictionary).get("id", ""))
		if not eid.is_empty() and not current_active.has(eid):
			echo_id = eid
			break
	if echo_id.is_empty():
		return { "ok": false, "error": "No roster echo outside active_party_ids (cannot test add-toggle)" }

	runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })

	var save_after: Dictionary = runtime.get_save_data()
	var sanctum_after_v: Variant = save_after.get("sanctum", {})
	var sanctum_after: Dictionary = sanctum_after_v if sanctum_after_v is Dictionary else {}
	var active_v: Variant = sanctum_after.get("active_party_ids", [])
	var active: Array = active_v if active_v is Array else []
	if not active.has(echo_id):
		return { "ok": false, "error": "active_party_ids missing toggled echo_id=%s" % echo_id }
	return { "ok": true }


static func _t_double_toggle_removes() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.echo_party" })

	var save: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty() or not (roster[0] is Dictionary):
		return { "ok": false, "error": "Roster missing starter echo" }
	# Find an echo NOT already in active_party_ids so toggle 1 adds, toggle 2 removes.
	var current_active_v2: Variant = sanctum.get("active_party_ids", [])
	var current_active2: Array = current_active_v2 if current_active_v2 is Array else []
	var echo_id := ""
	for entry_v in roster:
		if not (entry_v is Dictionary):
			continue
		var eid := str((entry_v as Dictionary).get("id", ""))
		if not eid.is_empty() and not current_active2.has(eid):
			echo_id = eid
			break
	if echo_id.is_empty():
		return { "ok": false, "error": "No roster echo outside active_party_ids (cannot test double-toggle)" }

	runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })
	var snap2: Dictionary = runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })

	var data_v: Variant = snap2.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var active_v: Variant = data.get("active_party_ids", [])
	var active: Array = active_v if active_v is Array else []
	if active.has(echo_id):
		return { "ok": false, "error": "double-toggle should remove echo_id=%s from active_party_ids" % echo_id }
	return { "ok": true }


static func _t_over_cap_capped() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	runtime.dispatch({ "type": "economy.ase.add", "amount": 500, "reason": "test.seed" })
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.summon" })
	var now_unix := 444444
	var save_ref: Dictionary = runtime.get_save_data()
	var econ_v: Variant = save_ref.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	econ["last_settle_unix"] = now_unix
	save_ref["economy"] = econ
	runtime.dispatch({ "type": "sanctum.summon", "count": 5, "now_unix": now_unix })
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.echo_party" })

	var save: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.size() < 6:
		return { "ok": false, "error": "Expected at least 6 echoes in roster, got %d" % roster.size() }

	var last_snap: Dictionary = {}
	for i in range(6):
		var e_v: Variant = roster[i]
		if not (e_v is Dictionary):
			continue
		var eid := str((e_v as Dictionary).get("id", ""))
		if eid.is_empty():
			continue
		last_snap = runtime.dispatch({ "type": "sanctum.party.toggle", "payload": { "echo_id": eid } })

	var data_v: Variant = last_snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var active_v: Variant = data.get("active_party_ids", [])
	var active: Array = active_v if active_v is Array else []
	if active.size() > 5:
		return { "ok": false, "error": "Expected active_party_ids.size() <= 5, got %d" % active.size() }
	return { "ok": true }


static func _t_empty_roster_snapshot_valid() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	var save_ref: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save_ref.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	sanctum["roster"] = []
	sanctum["active_party_ids"] = []
	save_ref["sanctum"] = sanctum

	var snap: Dictionary = runtime.dispatch({ "type": "flow.go_state", "to": "flow.echo_party" })
	if str(snap.get("type", "")) != "flow.echo_party":
		return { "ok": false, "error": "Expected type=flow.echo_party, got: %s" % str(snap.get("type", "")) }

	var data_v: Variant = snap.get("data", {})
	if not (data_v is Dictionary):
		return { "ok": false, "error": "snap.data is not a Dictionary" }
	var data: Dictionary = data_v
	var echoes_v: Variant = data.get("echoes", null)
	if not (echoes_v is Array):
		return { "ok": false, "error": "snap.data.echoes is not an Array" }
	if (echoes_v as Array).size() != 0:
		return { "ok": false, "error": "Expected empty echoes array, got size %d" % (echoes_v as Array).size() }

	var actions_v: Variant = snap.get("actions", {})
	if not (actions_v is Dictionary):
		return { "ok": false, "error": "snap.actions is not a Dictionary" }
	var actions: Dictionary = actions_v
	if not actions.has("nav.back"):
		return { "ok": false, "error": "snap.actions missing 'nav.back' slot" }
	return { "ok": true }


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
