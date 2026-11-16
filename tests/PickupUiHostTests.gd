# res://tests/PickupUiHostTests.gd
# V2-ITEM-001b step U1: the combat board hosts the pickup event.
# flow.pickup routes to the combat board scene through the real RealmShell. The board stays drawn
# from the snapshot, the encounter HUD is hidden, one empty PickupEventStage sits on top, and the
# debug placeholder sends the slot actions of the snapshot.
# The fixture is a hand-built dictionary in the shape of PickupSnapshotBuilder: board keys, actors,
# situation_id, run_count and the slot-keyed actions.

class_name PickupUiHostTests
extends RefCounted

const RealmShellScene := preload("res://ui/shells/RealmShell.tscn")
const _VIEW := Vector2i(1280, 720)
const _LAYOUT := { "profile": &"standard", "safe_insets": Vector4.ZERO, "logical_size": Vector2(1280, 720) }
const _NEW_FILES: Array = [
	"res://ui/screens/combat/PickupEventStage.gd",
	"res://ui/screens/combat/PickupDebugContinue.gd",
]
const _BANNED_WORDS: Array = ["dispatch", "FlowContext", "Node.new", "StyleBoxFlat.new", "add_child"]
const _HUD_NODES: Array = ["RoundLabel", "ObjectiveLabel", "ObjectiveBanner", "StallPanel", "SpeedBar",
	"StartCombatButton", "AutoToggleButton", "InitiativePanel", "BackButton", "RecenterButton", "CombatResultOverlay"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/pickup_routes_to_the_combat_board", Callable(PickupUiHostTests, "_t_routing"))
	runner.register_test("pickup_ui/stage_is_one_empty_non_blocking_control", Callable(PickupUiHostTests, "_t_stage_mounts_once"))
	runner.register_test("pickup_ui/same_event_does_not_restart_new_event_does", Callable(PickupUiHostTests, "_t_identity"))
	runner.register_test("pickup_ui/encounter_hud_is_hidden_and_comes_back", Callable(PickupUiHostTests, "_t_hud"))
	runner.register_test("pickup_ui/board_draws_the_snapshot_actors_and_size", Callable(PickupUiHostTests, "_t_board"))
	runner.register_test("pickup_ui/debug_placeholder_sends_slot_actions", Callable(PickupUiHostTests, "_t_placeholder"))
	runner.register_test("pickup_ui/placeholder_exists_only_in_debug_builds", Callable(PickupUiHostTests, "_t_placeholder_gate"))
	runner.register_test("pickup_ui/stage_nodes_send_no_action", Callable(PickupUiHostTests, "_t_stage_sends_nothing"))
	runner.register_test("pickup_ui/new_ui_files_pass_the_source_scan", Callable(PickupUiHostTests, "_t_source_scan"))
	runner.register_test("pickup_ui/back_slot_is_absent_so_back_does_nothing", Callable(PickupUiHostTests, "_t_no_back_slot"))


static func _actors() -> Array:
	return [
		_actor("a1", "Ama", "echo", 2, 3),
		_actor("a2", "Kofi", "echo", 3, 4),
		_actor("m1", "Hollow", "enemy", 6, 2),
	]


static func _actor(id: String, actor_name: String, faction: String, col: int, row: int) -> Dictionary:
	return { "id": id, "name": actor_name, "faction": faction, "grid_pos": { "col": col, "row": row },
		"hp": 10, "current_hp": 10, "max_hp": 12, "emotional_status": "grounded" }


static func _pickup(situation: String = "sit_a", run_count: int = 1, phase: String = "idle", cols: int = 6, rows: int = 5) -> Dictionary:
	var actions := { "cta.continue": { "type": "pickup.continue", "slot": "cta.continue" } }
	if phase == "intro":
		actions = { "overlay.skip": { "type": "pickup.skip", "slot": "overlay.skip" } }
	return {
		"type": "flow.pickup", "meta": { "t": 1 },
		"data": { "phase": phase, "situation_id": situation, "run_count": run_count,
			"encounter_id": "host_test", "board_cols": cols, "board_rows": rows, "terrain": {},
			"placement_seed": 0, "actors": _actors() },
		"actions": actions,
	}


static func _encounter() -> Dictionary:
	return {
		"type": "flow.encounter", "meta": { "t": 1 },
		"data": { "encounter_id": "host_test", "board_cols": 6, "board_rows": 5, "round": 2,
			"round_phase": "actor_turn", "combat_over": false, "actors": _actors(), "current_actor_id": "",
			"stall_level": 1, "objective_state": { "type": "combat" } },
		"actions": {},
	}


# Returns { viewport, realm, combat } or {} when the host scene is missing.
static func _mount(first: Dictionary) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if host == null:
		return {}
	var vp := SubViewport.new()
	vp.size = _VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(vp)
	var layer := CanvasLayer.new()
	layer.layer = 10
	vp.add_child(layer)
	var realm := RealmShellScene.instantiate() as RealmShell
	layer.add_child(realm)
	realm.set_layout(_LAYOUT)
	realm.set_snapshot(first)
	var combat := realm.get("_active_overlay") as CombatBoardScreen
	if combat == null:
		vp.free()
		return {}
	return { "viewport": vp, "realm": realm, "combat": combat }


static func _stage(fx: Dictionary) -> PickupEventStage:
	return (fx["combat"] as Node).get_node("%PickupEventStage") as PickupEventStage


static func _free(fx: Dictionary) -> void:
	(fx["viewport"] as SubViewport).free()


static func _fail(fx: Dictionary, error: String) -> Dictionary:
	if not fx.is_empty():
		_free(fx)
	return { "ok": false, "error": error }


static func _t_routing() -> Dictionary:
	var fx := _mount(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "flow.pickup did not mount a CombatBoardScreen through RealmShell" }
	var errors: Array = []
	var table: Dictionary = (fx["realm"] as RealmShell).get("_scene_by_flow_type")
	if not table.has("flow.pickup"):
		errors.append("RealmShell route table has no flow.pickup")
	var scene_path := ((fx["combat"] as Node).scene_file_path)
	if scene_path != "res://ui/screens/combat/CombatBoardScreen.tscn":
		errors.append("flow.pickup mounted %s" % scene_path)
	var app_source := FileAccess.get_file_as_string("res://ui/AppRoot.gd")
	var family_at := app_source.find("const VENTURE_FAMILY")
	var family_end := app_source.find("]", family_at)
	if family_at < 0 or not app_source.substr(family_at, family_end - family_at).contains("\"flow.pickup\""):
		errors.append("AppRoot VENTURE_FAMILY does not list flow.pickup")
	_free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_stage_mounts_once() -> Dictionary:
	var fx := _mount(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	(fx["realm"] as RealmShell).set_snapshot(_pickup())
	(fx["realm"] as RealmShell).set_snapshot(_pickup())
	var errors: Array = []
	var count := 0
	for child in combat.get_children():
		if child is PickupEventStage:
			count += 1
	if count != 1:
		errors.append("%d stages after three snapshots" % count)
	var stage := _stage(fx)
	if stage == null:
		_free(fx)
		return { "ok": false, "error": "no PickupEventStage" }
	if not stage.visible:
		errors.append("stage hidden during the event")
	if stage.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("stage blocks the mouse")
	if stage.anchor_right != 1.0 or stage.anchor_bottom != 1.0:
		errors.append("stage is not full rect")
	if stage.get_child_count() != 0:
		errors.append("stage is not empty in U1")
	if stage.name != &"PickupEventStage":
		errors.append("stage name changed")
	_free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_identity() -> Dictionary:
	var fx := _mount(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var realm := fx["realm"] as RealmShell
	var stage := _stage(fx)
	var errors: Array = []
	realm.set_snapshot(_pickup())
	realm.set_snapshot(_pickup("sit_a", 1, "idle"))
	if stage.start_count() != 1:
		errors.append("same event restarted: %d starts" % stage.start_count())
	realm.set_snapshot(_pickup("sit_a", 2))
	if stage.start_count() != 2:
		errors.append("new run_count did not restart: %d" % stage.start_count())
	realm.set_snapshot(_pickup("sit_b", 2))
	if stage.start_count() != 3:
		errors.append("new situation did not restart: %d" % stage.start_count())
	realm.set_snapshot(_pickup("sit_b", 2, "intro"))
	if stage.start_count() != 3:
		errors.append("a phase change restarted the event: %d" % stage.start_count())
	realm.set_snapshot(_encounter())
	realm.set_snapshot(_pickup("sit_b", 2))
	if stage.start_count() != 4:
		errors.append("an event after leaving the board did not start fresh: %d" % stage.start_count())
	_free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_hud() -> Dictionary:
	var fx := _mount(_encounter())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var realm := fx["realm"] as RealmShell
	var errors: Array = []
	if not (combat.get_node("%SpeedBar") as Control).visible:
		errors.append("premise: speed bar hidden during an encounter")
	if not (combat.get_node("%StallPanel") as Control).visible:
		errors.append("premise: stall panel not shown by stall_level 1")
	if _stage(fx).visible:
		errors.append("stage visible during an encounter")
	realm.set_snapshot(_pickup())
	for node_name: String in _HUD_NODES:
		var node := combat.find_child(node_name, true, false) as CanvasItem
		if node == null:
			errors.append("HUD node %s not found" % node_name)
		elif node.visible:
			errors.append("%s is visible during the event" % node_name)
	realm.set_snapshot(_encounter())
	if not (combat.get_node("%SpeedBar") as Control).visible:
		errors.append("speed bar did not come back after the event")
	if _stage(fx).visible:
		errors.append("stage still visible after the event")
	_free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_board() -> Dictionary:
	var fx := _mount(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var errors: Array = []
	var board := combat.get_node("%Board") as TileMapLayer
	if board.get_used_cells().size() != 30:
		errors.append("board drew %d cells, wanted 30 (6 x 5)" % board.get_used_cells().size())
	var last_actors: Array = combat.get("_last_actors")
	if last_actors.size() != 3:
		errors.append("screen holds %d actors, wanted 3" % last_actors.size())
	var tokens: Array = (combat.get_node("%TokenLayer") as Node).get("_tokens")
	if tokens.size() != 3:
		errors.append("token layer holds %d tokens, wanted 3" % tokens.size())
	_free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_placeholder() -> Dictionary:
	var fx := _mount(_pickup("sit_a", 1, "intro"))
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	if not PickupDebugContinue.is_available():
		_free(fx)
		return { "ok": true }
	var realm := fx["realm"] as RealmShell
	var combat := fx["combat"] as CombatBoardScreen
	var sent: Array = []
	realm.action_requested.connect(func(action: Dictionary) -> void: sent.append(action))
	var errors: Array = []
	var skip := combat.find_child("SkipButton", true, false) as Button
	var cont := combat.find_child("ContinueButton", true, false) as Button
	if not skip.visible or cont.visible:
		errors.append("intro phase must show Skip only")
	skip.pressed.emit()
	realm.set_snapshot(_pickup("sit_a", 1, "idle"))
	if skip.visible or not cont.visible:
		errors.append("idle phase must show Continue only")
	cont.pressed.emit()
	if sent.size() != 2 or str(sent[0].get("type", "")) != "pickup.skip" or str(sent[1].get("type", "")) != "pickup.continue":
		errors.append("sent %s" % [sent])
	if cont.custom_minimum_size.y < 56.0 or skip.custom_minimum_size.y < 56.0:
		errors.append("placeholder buttons are under 56 high")
	realm.set_snapshot(_encounter())
	if (combat.get_node("%PickupDebugContinue") as Control).visible:
		errors.append("placeholder stays visible after the event")
	_free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_placeholder_gate() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://ui/screens/combat/PickupDebugContinue.gd")
	var errors: Array = []
	if PickupDebugContinue.is_available() != OS.is_debug_build():
		errors.append("is_available() does not follow OS.is_debug_build()")
	if not source.contains("return OS.is_debug_build()"):
		errors.append("is_available() no longer reads OS.is_debug_build()")
	if not source.contains("if not is_available():\n\t\tqueue_free()"):
		errors.append("_ready no longer frees the node in a release build")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_stage_sends_nothing() -> Dictionary:
	var fx := _mount(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var stage := _stage(fx)
	var errors: Array = []
	var nodes: Array = [stage]
	nodes.append_array(stage.find_children("*", "", true, false))
	for node: Node in nodes:
		for sig in node.get_signal_list():
			if str(sig["name"]) == "action_requested":
				errors.append("%s declares action_requested" % node.name)
	var sent: Array = []
	(fx["realm"] as RealmShell).action_requested.connect(func(action: Dictionary) -> void: sent.append(action))
	(fx["realm"] as RealmShell).set_snapshot(_pickup())
	(fx["realm"] as RealmShell).set_snapshot(_pickup("sit_b", 3))
	if not sent.is_empty():
		errors.append("snapshots alone sent %d actions" % sent.size())
	_free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_source_scan() -> Dictionary:
	var errors: Array = []
	for path: String in _NEW_FILES:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			errors.append("%s unreadable" % path)
		for word: String in _BANNED_WORDS:
			if text.contains(word):
				errors.append("%s contains %s" % [path, word])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_no_back_slot() -> Dictionary:
	var errors: Array = []
	for phase in ["intro", "idle"]:
		var actions: Dictionary = _pickup("sit_a", 1, phase)["actions"]
		if actions.has("nav.back"):
			errors.append("%s snapshot carries a Back slot" % phase)
	var fx := _mount(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	if (fx["combat"].get_node("%BackButton") as Control).visible:
		errors.append("Back button visible during the event")
	_free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }
