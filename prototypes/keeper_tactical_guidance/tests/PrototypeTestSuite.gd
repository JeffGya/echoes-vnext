extends RefCounted

const BoardGenerator = preload("res://prototypes/keeper_tactical_guidance/board/TacticalBoardGenerator.gd")
const Simulation = preload("res://prototypes/keeper_tactical_guidance/simulation/PrototypeSimulation.gd")
const BoardView = preload("res://prototypes/keeper_tactical_guidance/ui/TacticalBoardView.gd")

const MODES: Array[String] = ["recover", "protect"]
const DIRECTIVES: Array[String] = [
	"scout_carefully", "seek_signs", "press_the_path", "hold_the_circle",
]
const PING_MODES: Dictionary = {
	"hold_ground": "echo_specific",
	"break_through": "area_based",
	"focus_threat": "party_wide",
	"regroup": "area_based",
	"secure_objective": "party_wide",
}
const PING_COSTS: Dictionary = {
	"hold_ground": 2, "break_through": 3, "focus_threat": 5, "regroup": 3, "secure_objective": 5,
}


static func run_all() -> Dictionary:
	var tests: Array[Dictionary] = [
		{"name": "boards/batch_both_modes", "fn": _test_board_batch},
		{"name": "boards/same_seed_determinism", "fn": _test_board_determinism},
		{"name": "boards/connectivity_chokepoints_routes", "fn": _test_board_validation_contract},
		{"name": "boards/filled_obstacle_projection_and_fallback", "fn": _test_obstacle_projection},
		{"name": "hazards/all_three_resolve", "fn": _test_hazards},
		{"name": "ui/isometric_projection_hit_test_navigation", "fn": _test_isometric_board_view},
		{"name": "ui/raised_obstacle_occlusion_order", "fn": _test_obstacle_occlusion_order},
		{"name": "ui/structured_turn_animation_timings", "fn": _test_turn_animation_contract},
		{"name": "simulation/fixture_contract", "fn": _test_fixture_contract},
		{"name": "charge/one_per_full_round_and_max", "fn": _test_charge_generation},
		{"name": "charge/independent_of_actor_count", "fn": _test_non_generators},
		{"name": "charge/cancel_and_consume_all", "fn": _test_charge_cancel_consume},
		{"name": "pings/explanations_modes_aoe_availability", "fn": _test_all_ping_previews},
		{"name": "pings/confirmation_round_pending_then_activation", "fn": _test_snapshot_recipients},
		{"name": "pings/unresolved_blocks_and_activation_expiry", "fn": _test_ping_expiry_equality},
		{"name": "responses/all_outcomes_map_to_action_expression", "fn": _test_response_reasons},
		{"name": "directives/all_four_affect_replay", "fn": _test_directives},
		{"name": "combat/automatic_only_action_contract", "fn": _test_automatic_only_contract},
		{"name": "objectives/recover_win_loss_kill_all", "fn": _test_recover_objective},
		{"name": "objectives/protect_win_loss_theft_carry", "fn": _test_protect_objective},
		{"name": "replay/same_choices_same_timeline", "fn": _test_replay},
		{"name": "experience/preparation_to_review", "fn": _test_complete_battle},
	]
	var results: Array[Dictionary] = []
	var passed: int = 0
	for test: Dictionary in tests:
		var output: Dictionary = (test["fn"] as Callable).call()
		var ok: bool = bool(output.get("ok", false))
		passed += 1 if ok else 0
		results.append({"name": test["name"], "ok": ok, "error": output.get("error", "")})
	return {"total": tests.size(), "passed": passed, "failed": tests.size() - passed, "results": results}


static func _ok() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func _test_board_batch() -> Dictionary:
	var valid_count: int = 0
	var total: int = 0
	for mode: String in MODES:
		for seed: int in range(100, 125):
			total += 1
			var board: Dictionary = BoardGenerator.generate(seed, mode)
			if bool(board.get("validation", {}).get("valid", false)):
				valid_count += 1
			else:
				return _fail("seed %d/%s invalid: %s" % [seed, mode, board.get("validation", {}).get("diagnostics", [])])
	if valid_count != total:
		return _fail("only %d/%d generated boards were valid" % [valid_count, total])
	return _ok()


static func _test_board_determinism() -> Dictionary:
	for mode: String in MODES:
		var a: Dictionary = BoardGenerator.generate(424242, mode)
		var b: Dictionary = BoardGenerator.generate(424242, mode)
		if BoardGenerator.board_signature(a) != BoardGenerator.board_signature(b):
			return _fail("same seed differs for %s" % mode)
		if BoardGenerator.board_signature(a) == BoardGenerator.board_signature(BoardGenerator.generate(424243, mode)):
			return _fail("neighboring seed did not vary for %s" % mode)
	return _ok()


static func _test_board_validation_contract() -> Dictionary:
	for mode: String in MODES:
		for seed: int in [7, 19, 71, 701]:
			var validation: Dictionary = BoardGenerator.validate_board(BoardGenerator.generate(seed, mode))
			for key: String in ["valid", "connected", "objective_accessible", "deployment_accessible",
					"chokepoint_valid", "route_diversity_valid", "no_unavoidable_lethal_route"]:
				if not bool(validation.get(key, false)):
					return _fail("%s missing for %d/%s: %s" % [key, seed, mode, validation.get("diagnostics", [])])
	return _ok()


static func _test_obstacle_projection() -> Dictionary:
	for mode: String in MODES:
		var board: Dictionary = BoardGenerator.generate(24051987, mode)
		var obstacles: Array = board.get("obstacles", [])
		if obstacles.is_empty():
			return _fail("%s board omitted filled obstacle payload" % mode)
		var projected: Dictionary = {}
		for obstacle_v: Variant in obstacles:
			var obstacle: Dictionary = obstacle_v if obstacle_v is Dictionary else {}
			if str(obstacle.get("id", "")).is_empty() or str(obstacle.get("label", "")).is_empty():
				return _fail("%s obstacle omitted id or player-facing label" % mode)
			if not str(obstacle.get("kind", "")) in ["rock", "vegetation", "ruin", "landmark"]:
				return _fail("%s obstacle used unsupported raised silhouette kind" % mode)
			if (obstacle.get("cells", []) as Array).is_empty():
				return _fail("%s obstacle omitted its filled cell mass" % mode)
			for cell_v: Variant in obstacle.get("cells", []):
				var cell: Dictionary = cell_v if cell_v is Dictionary else {}
				var key: String = "%d,%d" % [int(cell.get("col", -1)), int(cell.get("row", -1))]
				if (board.get("walkable", {}) as Dictionary).has(key):
					return _fail("%s obstacle overlaps walkable topology at %s" % [mode, key])
				projected[key] = true
		if projected.is_empty():
			return _fail("%s obstacle payload projected no occupied volume" % mode)
	var fallback_board: Dictionary = BoardGenerator.generate(77, "recover")
	fallback_board["obstacles"] = []
	var view: Control = BoardView.new()
	view.size = Vector2(720, 560)
	view.call("set_content", fallback_board, [], {}, {}, false, "briefing")
	if (view.call("_inferred_obstacles") as Array).is_empty():
		view.free()
		return _fail("renderer compatibility fallback inferred no obstacle mass")
	view.free()
	return _ok()


static func _test_hazards() -> Dictionary:
	var board: Dictionary = BoardGenerator.generate(91, "recover")
	var by_type: Dictionary = {}
	for hazard_value: Variant in board.get("hazards", []):
		var hazard: Dictionary = hazard_value as Dictionary
		by_type[str(hazard.get("type", ""))] = hazard
	for required: String in ["burning_ground", "unstable_ground", "binding_growth"]:
		if not by_type.has(required) or (by_type[required] as Dictionary).get("cells", []).is_empty():
			return _fail("missing non-empty %s" % required)
	var burning: Dictionary = by_type["burning_ground"]
	var actor: Dictionary = _hazard_actor((burning.get("cells", []) as Array)[0])
	var burn_result: Dictionary = BoardGenerator.apply_end_turn_hazards(actor, board)
	if int(burn_result.get("damage", 0)) <= 0 or int(actor.get("current_hp", 0)) >= 40:
		return _fail("Burning Ground did not deal end-turn damage")
	var binding: Dictionary = by_type["binding_growth"]
	actor = _hazard_actor((binding.get("cells", []) as Array)[0])
	var bind_result: Dictionary = BoardGenerator.apply_entry_hazards(actor, {"col": -9, "row": -9}, actor["grid_pos"], board, {})
	if not bool(bind_result.get("movement_stopped", false)) or int(actor.get("movement_remaining", 1)) != 0:
		return _fail("Binding Growth did not stop movement")
	var unstable: Dictionary = by_type["unstable_ground"]
	actor = _hazard_actor((unstable.get("cells", []) as Array)[0])
	var unstable_result: Dictionary = BoardGenerator.apply_entry_hazards(actor, {"col": -8, "row": -8}, actor["grid_pos"], board, {})
	if not bool(unstable_result.get("pushed", false)) and int(unstable_result.get("damage", 0)) <= 0:
		return _fail("Unstable Ground neither pushed nor applied fallback damage")
	return _ok()


static func _hazard_actor(pos: Dictionary) -> Dictionary:
	return {"id": "hazard_target", "is_dead": false, "is_structure": false,
		"current_hp": 40, "grid_pos": pos.duplicate(true), "movement_remaining": 1}


static func _test_isometric_board_view() -> Dictionary:
	var board: Dictionary = BoardGenerator.generate(24051987, "recover")
	var sim: RefCounted = Simulation.new()
	sim.call("setup_battle", 24051987, "recover", board)
	var actors: Array = (sim.call("get_state") as Dictionary).get("actors", [])
	var footprint: Array = [board.get("objective_pos", {}).duplicate(true)]
	var view: Control = BoardView.new()
	view.size = Vector2(720, 560)
	view.call("set_content", board, actors, {"footprint": footprint}, {}, false)
	var tile_width: float = float(view.get("_tile_width"))
	var tile_height: float = float(view.get("_tile_height"))
	if not is_equal_approx(tile_height / tile_width, 0.5):
		return _fail("board projection is not production-style 2:1 isometric")
	for key_value: Variant in (board.get("walkable", {}) as Dictionary).keys():
		var bits: PackedStringArray = str(key_value).split(",")
		var cell: Dictionary = {"col": int(bits[0]), "row": int(bits[1])}
		var center: Vector2 = view.call("_cell_center", cell)
		if view.call("_screen_to_cell", center) != cell:
			return _fail("isometric center hit-test failed for %s" % cell)
	if (view.get("_ping_preview") as Dictionary).get("footprint", []) != footprint:
		return _fail("isometric view dropped the ping footprint")
	var before_zoom: float = float(view.get("_tile_width"))
	view.call("zoom_in")
	if float(view.get("_tile_width")) <= before_zoom:
		return _fail("zoom-in did not enlarge the isometric board")
	view.set("_pan", Vector2(70, -35))
	view.call("_recalculate_view")
	if (view.get("_pan") as Vector2) != Vector2(70, -35):
		return _fail("board pan was not retained")
	view.call("recenter")
	if not is_equal_approx(float(view.get("_zoom")), 1.0) or (view.get("_pan") as Vector2) != Vector2.ZERO:
		return _fail("recenter did not reset pan and zoom")
	view.free()
	return _ok()


static func _test_obstacle_occlusion_order() -> Dictionary:
	# RenderingServer's headless dummy backend cannot return pixels. Keep a narrow assertion
	# on the world-layer sequence, while the neighboring tests exercise animation state,
	# hit testing, ping footprints, pan/zoom, and obstacle payload behavior independently.
	var source: String = FileAccess.get_file_as_string(
		"res://prototypes/keeper_tactical_guidance/ui/TacticalBoardView.gd")
	var draw_start: int = source.find("func _draw() -> void:")
	var draw_end: int = source.find("\n\nfunc _draw_void_grid", draw_start)
	if draw_start < 0 or draw_end < 0:
		return _fail("could not inspect TacticalBoardView world draw sequence")
	var draw_body: String = source.substr(draw_start, draw_end - draw_start)
	var cells_at: int = draw_body.find("\t_draw_cells()")
	var actors_at: int = draw_body.find("\t_draw_actors()")
	var feedback_at: int = draw_body.find("\t_draw_combat_feedback()")
	var obstacles_at: int = draw_body.find("\t_draw_obstacles()")
	var debug_at: int = draw_body.find("\t_draw_debug_marks()")
	if cells_at < 0 or actors_at < 0 or feedback_at < 0 or obstacles_at < 0 or debug_at < 0:
		return _fail("world draw sequence omitted a required layer")
	if not (cells_at < actors_at and actors_at < feedback_at and feedback_at < obstacles_at \
			and obstacles_at < debug_at):
		return _fail("raised obstacles are not after actors/animation feedback and before debug overlay")
	return _ok()


static func _test_turn_animation_contract() -> Dictionary:
	var board: Dictionary = BoardGenerator.generate(24051987, "recover")
	var sim: RefCounted = Simulation.new()
	sim.call("setup_battle", 24051987, "recover", board)
	var actors: Array = (sim.call("get_state") as Dictionary).get("actors", [])
	var echo: Dictionary = _first_actor(sim.call("get_state"), "echo")
	var enemy: Dictionary = _first_actor(sim.call("get_state"), "enemy")
	var result: Dictionary = {
		"tick": 9, "round": 2, "actor_id": echo.get("id", ""), "action_type": "attack",
		"from_pos": echo.get("grid_pos", {}).duplicate(true), "to_pos": enemy.get("grid_pos", {}).duplicate(true),
		"path": [echo.get("grid_pos", {}).duplicate(true)], "target_id": enemy.get("id", ""),
		"damage": 7, "hit": true, "hazard_events": [], "objective_events": [], "follow_up": [],
		"ping_response": {"actor_id": echo.get("id", ""), "outcome": "interpret", "primary_reason": "Calling changes the approach"},
		"guidance_expression": "interpret",
	}
	var durations: Dictionary = {}
	for speed: String in ["slow", "normal", "fast"]:
		var view: Control = BoardView.new()
		view.size = Vector2(720, 560)
		view.call("set_content", board, actors, {}, {}, false, "combat", {}, result, speed, [])
		if not bool(view.call("is_animating")):
			view.free()
			return _fail("structured attack did not start presentation animation at %s speed" % speed)
		durations[speed] = float(view.call("get_animation_duration"))
		view.free()
	if not (float(durations["slow"]) > float(durations["normal"]) and float(durations["normal"]) > float(durations["fast"])):
		return _fail("Slow/Normal/Fast did not scale movement/response/attack timings")
	if float(durations["normal"]) < 1.0:
		return _fail("attack presentation omitted response reveal, lunge, punch, recovery, or damage beat")
	return _ok()


static func _test_fixture_contract() -> Dictionary:
	var sim: RefCounted = _combat(301, "recover", "seek_signs")
	var state: Dictionary = sim.call("get_state")
	var required: Array[String] = ["id", "name", "actor_type", "faction", "is_structure", "is_dead",
		"grid_pos", "current_hp", "stats", "speed", "fear", "morale", "calling_origin", "standing",
		"expression_band", "traits", "vector_scores", "bonds", "tendency", "guard_state",
		"movement_remaining", "last_response"]
	for actor_value: Variant in state.get("actors", []):
		var actor: Dictionary = actor_value as Dictionary
		if str(actor.get("faction", "")) != "echo":
			continue
		for field: String in required:
			if not actor.has(field):
				return _fail("%s missing actor field %s" % [actor.get("id", "echo"), field])
	return _ok()


static func _test_charge_generation() -> Dictionary:
	var sim: RefCounted = _combat(302, "recover", "seek_signs")
	var initial: Dictionary = sim.call("get_state")
	if int(initial.get("ping_charge", {}).get("current", -1)) != 0:
		return _fail("charge did not start at zero")
	var entries: int = (initial.get("initiative_order", []) as Array).size()
	for _i: int in range(entries - 1):
		sim.call("resolve_next_turn")
	var state: Dictionary = sim.call("get_state")
	if int(state.get("ping_charge", {}).get("current", -1)) != 0:
		return _fail("charge increased before the full round completed")
	sim.call("resolve_next_turn")
	state = sim.call("get_state")
	if int(state.get("ping_charge", {}).get("current", -1)) != 1 or int(state.get("round", 0)) != 2:
		return _fail("full round did not grant exactly one charge")
	for _round: int in range(7):
		_resolve_one_full_round(sim)
	if int((sim.call("get_state") as Dictionary).get("ping_charge", {}).get("current", -1)) != 5:
		return _fail("round charge did not clamp to five")
	return _ok()


static func _test_non_generators() -> Dictionary:
	var full: RefCounted = _combat(303, "protect", "seek_signs")
	_resolve_one_full_round(full)
	if int((full.call("get_state") as Dictionary).get("ping_charge", {}).get("current", -1)) != 1:
		return _fail("normal multi-actor round did not grant one charge")
	var sparse: RefCounted = _combat(303, "protect", "seek_signs")
	var state: Dictionary = sparse.call("get_state")
	var original_order: Array = state.get("initiative_order", [])
	var living_id: String = str(original_order[0])
	var dead_id: String = str(original_order[1])
	for actor_v: Variant in state.get("actors", []):
		var actor: Dictionary = actor_v as Dictionary
		if str(actor.get("id", "")) == dead_id:
			actor["is_dead"] = true
			actor["current_hp"] = 0
	state["initiative_order"] = [str(state.get("objective", {}).get("structure_id", "")), dead_id, living_id]
	state["initiative_index"] = 0
	state["ping_charge"]["current"] = 0
	sparse.set("_state", state)
	sparse.call("resolve_next_turn")
	state = sparse.call("get_state")
	if int(state.get("ping_charge", {}).get("current", -1)) != 1:
		return _fail("one-living-actor round did not grant exactly one charge")
	if int(state.get("metrics", {}).get("turns_completed", -1)) != 1:
		return _fail("dead actor or structure was treated as a living completed turn")
	return _ok()


static func _test_charge_cancel_consume() -> Dictionary:
	var sim: RefCounted = _combat(304, "recover", "seek_signs")
	_set_charge(sim, 5)
	var before: int = int((sim.call("get_state") as Dictionary).get("ping_charge", {}).get("current", 0))
	sim.call("cancel_ping")
	if int((sim.call("get_state") as Dictionary).get("ping_charge", {}).get("current", 0)) != before:
		return _fail("cancel consumed charge")
	var preview: Dictionary = _valid_hold_preview(sim)
	if preview.is_empty() or not bool(sim.call("confirm_ping", preview)):
		return _fail("valid low-cost ping could not be confirmed at full charge")
	if int((sim.call("get_state") as Dictionary).get("ping_charge", {}).get("current", -1)) != 0:
		return _fail("confirm did not consume all stored charge")
	var blocked: Dictionary = sim.call("preview_ping", "hold_ground", _subject_for_ping(sim, "hold_ground"))
	if bool(blocked.get("valid", false)) or str(blocked.get("availability_state", "")) != "blocked_unresolved" \
			or str(blocked.get("invalid_reason", "")).find("previous ping") < 0:
		return _fail("unresolved ping did not block another placement")
	_resolve_one_full_round(sim)
	var rebuilt: Dictionary = sim.call("get_state")
	if int(rebuilt.get("ping_charge", {}).get("current", -1)) != 1 \
			or (rebuilt.get("unresolved_ping", {}) as Dictionary).is_empty():
		return _fail("round charge did not rebuild while the confirmed ping waited for activation")
	return _ok()


static func _test_all_ping_previews() -> Dictionary:
	for ping_id: String in PING_MODES.keys():
		var sim: RefCounted = _combat(410, "recover", "seek_signs")
		var locked: Dictionary = sim.call("preview_ping", ping_id, _subject_for_ping(sim, ping_id))
		for field: String in ["suggestion", "mechanical_influence", "targeting_instruction", "recipient_mode", "charge_required", "expected_duration", "availability_state", "invalid_reason"]:
			if not locked.has(field) or str(locked.get(field, "")).is_empty():
				return _fail("%s locked preview omitted %s" % [ping_id, field])
		if str(locked.get("availability_state", "")) != "insufficient_charge":
			return _fail("%s did not remain inspectable as insufficient-charge preview" % ping_id)
		_set_charge(sim, 5)
		var preview: Dictionary = sim.call("preview_ping", ping_id, _subject_for_ping(sim, ping_id))
		if not bool(preview.get("valid", false)):
			return _fail("%s invalid: %s" % [ping_id, preview.get("invalid_reason", "")])
		if str(preview.get("recipient_mode", "")) != str(PING_MODES[ping_id]):
			return _fail("%s has wrong recipient mode" % ping_id)
		if int(preview.get("charge_required", -1)) != int(PING_COSTS[ping_id]):
			return _fail("%s has wrong charge requirement" % ping_id)
		var recipients: Array = preview.get("eligible_recipient_ids", [])
		if ping_id == "hold_ground" and recipients.size() != 1:
			return _fail("Hold Ground did not select exactly one Echo")
		if ping_id == "hold_ground" and (preview.get("footprint", []) as Array).size() != 1:
			return _fail("Hold Ground did not expose its one-tile anchor")
		if ping_id == "break_through" and ((preview.get("footprint", []) as Array).is_empty() \
				or (preview.get("footprint", []) as Array).size() > 5):
			return _fail("Break Through footprint was not a 1-5 tile lane")
		if ping_id == "regroup" and (preview.get("footprint", []) as Array).size() <= 1:
			return _fail("Regroup did not expose an area footprint")
		if str(PING_MODES[ping_id]) == "party_wide" and recipients.size() != _living_echo_count(sim.call("get_state")):
			return _fail("%s did not expose every living Echo recipient" % ping_id)
		if not bool(sim.call("confirm_ping", preview)):
			return _fail("%s failed confirmation" % ping_id)
		var confirmed: Dictionary = (sim.call("get_state") as Dictionary).get("unresolved_ping", {})
		if confirmed.get("recipient_ids", []) != recipients:
			return _fail("%s recipient snapshot changed at confirmation" % ping_id)
	return _ok()


static func _test_snapshot_recipients() -> Dictionary:
	var sim: RefCounted = _combat(411, "recover", "seek_signs")
	_set_charge(sim, 5)
	var preview: Dictionary = _valid_hold_preview(sim)
	var recipient: String = str((preview.get("eligible_recipient_ids", []) as Array)[0])
	var state: Dictionary = sim.call("get_state")
	state["round"] = 5
	state["initiative_index"] = (state.get("initiative_order", []) as Array).find(recipient)
	sim.set("_state", state)
	preview = _valid_hold_preview(sim)
	if not bool(sim.call("confirm_ping", preview)):
		return _fail("Hold Ground confirmation failed")
	state = sim.call("get_state")
	if str(_actor_by_id(state, recipient).get("guidance_state", "")) != "pending":
		return _fail("confirmed recipient was not visibly pending")
	sim.call("resolve_next_turn")
	state = sim.call("get_state")
	if not (state.get("response_feedback", []) as Array).is_empty():
		return _fail("recipient responded during confirmation round")
	while int((sim.call("get_state") as Dictionary).get("round", 0)) < 6:
		sim.call("resolve_next_turn")
	state = sim.call("get_state")
	state["initiative_index"] = (state.get("initiative_order", []) as Array).find(recipient)
	sim.set("_state", state)
	var activation_result: Dictionary = sim.call("resolve_next_turn")
	state = sim.call("get_state")
	var feedback: Array = state.get("response_feedback", [])
	if feedback.size() != 1 or str((feedback[0] as Dictionary).get("actor_id", "")) != recipient:
		return _fail("first living activation-round turn did not evaluate exactly one recipient response")
	if (activation_result.get("ping_response", {}) as Dictionary).is_empty() \
			or str(activation_result.get("guidance_expression", "")) == "unaffected":
		return _fail("activation response and same-turn action expression were not published together")
	for actor_value: Variant in state.get("actors", []):
		var actor: Dictionary = actor_value as Dictionary
		if str(actor.get("faction", "")) == "echo" and str(actor.get("id", "")) != recipient \
				and not (actor.get("last_response", {}) as Dictionary).is_empty():
			return _fail("unaffected Echo produced a response")
	return _ok()


static func _test_response_reasons() -> Dictionary:
	var sim: RefCounted = _combat(412, "recover", "seek_signs")
	var expected: Dictionary = {"align": "follow", "interpret": "interpret", "hesitate": "resist", "object": "resist", "refuse": "reject"}
	for outcome: String in expected.keys():
		var response: Dictionary = {"outcome": outcome, "influence": 1.0 if outcome == "align" else 0.0,
			"primary_reason": "" if outcome == "align" else "identity and danger conflict", "explanation": "fixture"}
		var result: Dictionary = sim.call("_finalize_turn_result", {"actor_id": "echo_adwoa", "action_type": "move",
			"from_pos": {"col": 0, "row": 0}, "to_pos": {"col": 1, "row": 0}, "path": [{"col": 1, "row": 0}],
			"ping_response": response, "hazard_events": [], "objective_events": [], "follow_up": []})
		if str(result.get("guidance_expression", "")) != str(expected[outcome]):
			return _fail("%s did not map to %s action expression" % [outcome, expected[outcome]])
		if outcome != "align" and (str(response.get("primary_reason", "")).is_empty() or str(response.get("explanation", "")).is_empty()):
			return _fail("%s omitted a clear primary reason" % outcome)
	return _ok()


static func _test_ping_expiry_equality() -> Dictionary:
	var sim: RefCounted = _combat(413, "recover", "seek_signs")
	_set_charge(sim, 5)
	var preview: Dictionary = sim.call("preview_ping", "secure_objective", {})
	if not bool(preview.get("valid", false)) or not bool(sim.call("confirm_ping", preview)):
		return _fail("party-wide expiry fixture could not confirm")
	var confirmed_ids: Array = (sim.call("get_state") as Dictionary).get("unresolved_ping", {}).get("recipient_ids", []).duplicate()
	var blocked: Dictionary = sim.call("preview_ping", "hold_ground", _subject_for_ping(sim, "hold_ground"))
	if str(blocked.get("availability_state", "")) != "blocked_unresolved":
		return _fail("confirmed unresolved ping did not block a second placement")
	var activation_round: int = int((sim.call("get_state") as Dictionary).get("unresolved_ping", {}).get("activation_round", -1))
	for _turn: int in range(40):
		var state: Dictionary = sim.call("get_state")
		if (state.get("unresolved_ping", {}) as Dictionary).is_empty():
			if int(state.get("round", 0)) > activation_round:
				return _fail("ping survived beyond its activation-round duration")
			var responded: Dictionary = {}
			for response_v: Variant in state.get("response_feedback", []):
				var response: Dictionary = response_v if response_v is Dictionary else {}
				var actor_id: String = str(response.get("actor_id", ""))
				if responded.has(actor_id):
					return _fail("recipient %s responded more than once to one ping" % actor_id)
				responded[actor_id] = true
			for actor_id_v: Variant in confirmed_ids:
				var recipient: Dictionary = _actor_by_id(state, str(actor_id_v))
				if not bool(recipient.get("is_dead", false)) and not responded.has(str(actor_id_v)):
					return _fail("living party-wide recipient %s never responded on its first activation-round turn" % actor_id_v)
			return _ok()
		sim.call("resolve_next_turn")
	return _fail("ping did not expire after recipients acted or activation round ended")


static func _test_directives() -> Dictionary:
	var signatures: Dictionary = {}
	for directive: String in DIRECTIVES:
		var sim: RefCounted = _combat(501, "recover", directive)
		_resolve_turns(sim, 12)
		var state: Dictionary = sim.call("get_state")
		if str(state.get("directive_id", "")) != directive:
			return _fail("directive %s was not retained" % directive)
		var positions: Array[String] = []
		for actor_value: Variant in state.get("actors", []):
			var actor: Dictionary = actor_value as Dictionary
			if str(actor.get("faction", "")) == "echo":
				positions.append("%s:%s" % [actor.get("id", ""), JSON.stringify(actor.get("grid_pos", {}))])
		signatures[directive] = "|".join(positions)
	var unique: Dictionary = {}
	for value: Variant in signatures.values():
		unique[str(value)] = true
	if unique.size() < 2:
		return _fail("all four directives produced identical tactical positions")
	return _ok()


static func _test_automatic_only_contract() -> Dictionary:
	var forbidden_state_fields: Array[String] = ["paused", "paused_at_safe_boundary", "pause_requested", "manual_step", "intervention_window"]
	var sim: RefCounted = _combat(601, "recover", "seek_signs")
	var data: Dictionary = sim.call("build_snapshot_data")
	for field: String in forbidden_state_fields:
		if data.has(field):
			return _fail("automatic-only combat leaked forbidden state field %s" % field)
	var before_tick: int = int((sim.call("get_state") as Dictionary).get("tick", 0))
	var result: Dictionary = sim.call("resolve_next_turn")
	if result.is_empty() or int((sim.call("get_state") as Dictionary).get("tick", 0)) != before_tick + 1:
		return _fail("automatic playback primitive did not resolve one complete atomic actor turn")
	for field: String in ["tick", "round", "actor_id", "action_type", "from_pos", "to_pos", "path", "target_id", "damage", "hit", "hazard_events", "objective_events", "follow_up", "ping_response", "guidance_expression"]:
		if not result.has(field):
			return _fail("structured automatic turn omitted %s" % field)
	return _ok()


static func _test_recover_objective() -> Dictionary:
	var sim: RefCounted = _combat(701, "recover", "press_the_path")
	var state: Dictionary = sim.call("get_state")
	state["objective"]["hold_counter"] = state["objective"]["hold_required"]
	sim.set("_state", state)
	sim.call("_check_end_condition")
	state = sim.call("get_state")
	if not bool(state.get("result", {}).get("victory", false)) or str(state.get("result", {}).get("reason", "")) != "relic_secured":
		return _fail("RECOVER hold win failed")
	sim = _combat(702, "recover", "seek_signs")
	state = sim.call("get_state")
	_mark_faction_dead(state, "echo")
	sim.set("_state", state)
	sim.call("_check_end_condition")
	if str((sim.call("get_state") as Dictionary).get("result", {}).get("reason", "")) != "all_echoes_dead":
		return _fail("RECOVER loss failed")
	sim = _combat(703, "recover", "seek_signs")
	state = sim.call("get_state")
	_mark_faction_dead(state, "enemy")
	sim.set("_state", state)
	sim.call("_check_end_condition")
	if str((sim.call("get_state") as Dictionary).get("result", {}).get("reason", "")) != "all_enemies_defeated":
		return _fail("RECOVER universal kill-all failed")
	return _ok()


static func _test_protect_objective() -> Dictionary:
	var sim: RefCounted = _combat(801, "protect", "hold_the_circle")
	var state: Dictionary = sim.call("get_state")
	state["objective"]["protect_counter"] = state["objective"]["protect_required"]
	sim.set("_state", state)
	sim.call("_check_end_condition")
	if str((sim.call("get_state") as Dictionary).get("result", {}).get("reason", "")) != "protected":
		return _fail("PROTECT duration win failed")
	sim = _combat(802, "protect", "seek_signs")
	state = sim.call("get_state")
	state["objective"]["hp"] = 0
	sim.set("_state", state)
	sim.call("_check_end_condition")
	if str((sim.call("get_state") as Dictionary).get("result", {}).get("reason", "")) != "entity_lost":
		return _fail("PROTECT destruction loss failed")
	sim = _combat(803, "protect", "seek_signs")
	state = sim.call("get_state")
	if not state.get("objective", {}).has("carryable") or not state.get("objective", {}).has("totem_stolen") \
			or not state.get("objective", {}).has("totem_carrier_id"):
		return _fail("PROTECT carrying/theft seams are absent")
	_mark_faction_dead(state, "enemy")
	sim.set("_state", state)
	sim.call("_check_end_condition")
	if str((sim.call("get_state") as Dictionary).get("result", {}).get("reason", "")) != "all_enemies_defeated":
		return _fail("PROTECT universal kill-all failed")
	sim = _combat(804, "protect", "seek_signs")
	state = sim.call("get_state")
	state["objective"]["totem_stolen"] = true
	state["objective"]["totem_carrier_id"] = "enemy_01"
	state["objective"]["protect_counter"] = state["objective"]["protect_required"]
	sim.set("_state", state)
	sim.call("_check_end_condition")
	if str((sim.call("get_state") as Dictionary).get("result", {}).get("reason", "")) != "totem_taken":
		return _fail("PROTECT stolen-totem loss failed")
	sim = _combat(805, "protect", "seek_signs")
	state = sim.call("get_state")
	var theft_pos: Dictionary = _adjacent_walkable(state, state["objective"]["position"])
	if theft_pos.is_empty():
		return _fail("PROTECT objective had no adjacent walkable theft tile")
	var thief: Dictionary = _first_actor(state, "enemy")
	thief["grid_pos"] = theft_pos
	for actor_value: Variant in state.get("actors", []):
		var actor: Dictionary = actor_value as Dictionary
		if str(actor.get("faction", "")) == "echo":
			actor["grid_pos"] = {"col": -20, "row": -20}
	sim.set("_state", state)
	for round_number: int in range(1, 21):
		sim.call("_resolve_protect_theft", round_number)
		if bool((sim.call("get_state") as Dictionary).get("objective", {}).get("totem_stolen", false)):
			break
	if not bool((sim.call("get_state") as Dictionary).get("objective", {}).get("totem_stolen", false)):
		return _fail("PROTECT deterministic theft seam never selected a carrier")
	sim = _combat(806, "protect", "seek_signs")
	state = sim.call("get_state")
	state["objective"]["carryable"] = true
	var echo: Dictionary = _first_actor(state, "echo")
	var objective_pos: Dictionary = state["objective"]["position"]
	var adjacent: Dictionary = _adjacent_walkable(state, objective_pos)
	if adjacent.is_empty():
		return _fail("PROTECT objective had no adjacent walkable custody tile")
	echo["grid_pos"] = adjacent
	sim.set("_state", state)
	sim.call("_handle_objective_interaction", echo, {"influence": 1.0})
	if str((sim.call("get_state") as Dictionary).get("objective", {}).get("holder_id", "")) == "":
		return _fail("PROTECT carryable custody seam did not assign a holder")
	return _ok()


static func _test_replay() -> Dictionary:
	var first: String = _replay_signature(901)
	var second: String = _replay_signature(901)
	if first != second:
		return _fail("same-seed replay timeline differs")
	return _ok()


static func _test_complete_battle() -> Dictionary:
	for seed: int in range(1000, 1010):
		var sim: RefCounted = _combat(seed, "recover", "press_the_path")
		for _turn: int in range(400):
			var state: Dictionary = sim.call("get_state")
			if bool(state.get("combat_over", false)):
				if str(state.get("phase", "")) != "review" or (state.get("timeline", []) as Array).is_empty():
					return _fail("completed battle omitted review/timeline")
				return _ok()
			sim.call("resolve_next_turn")
	return _fail("no fixture battle reached review within the deterministic turn budget")


static func _combat(seed: int, mode: String, directive: String) -> RefCounted:
	var sim: RefCounted = Simulation.new()
	sim.call("setup_battle", seed, mode, BoardGenerator.generate(seed, mode))
	sim.call("set_directive", directive)
	sim.call("start_combat")
	return sim


static func _resolve_turns(sim: RefCounted, count: int) -> void:
	for _i: int in range(count):
		if bool((sim.call("get_state") as Dictionary).get("combat_over", false)):
			return
		sim.call("resolve_next_turn")


static func _resolve_one_full_round(sim: RefCounted) -> void:
	var start_round: int = int((sim.call("get_state") as Dictionary).get("round", 0))
	for _i: int in range(64):
		var state: Dictionary = sim.call("get_state")
		if bool(state.get("combat_over", false)) or int(state.get("round", 0)) > start_round:
			return
		sim.call("resolve_next_turn")


static func _set_charge(sim: RefCounted, value: int) -> void:
	var state: Dictionary = sim.call("get_state")
	state["ping_charge"]["current"] = clampi(value, 0, 5)
	sim.set("_state", state)


static func _living_echo_count(state: Dictionary) -> int:
	var count: int = 0
	for actor_v: Variant in state.get("actors", []):
		var actor: Dictionary = actor_v if actor_v is Dictionary else {}
		if str(actor.get("faction", "")) == "echo" and not bool(actor.get("is_dead", false)):
			count += 1
	return count


static func _actor_by_id(state: Dictionary, actor_id: String) -> Dictionary:
	for actor_v: Variant in state.get("actors", []):
		var actor: Dictionary = actor_v if actor_v is Dictionary else {}
		if str(actor.get("id", "")) == actor_id:
			return actor
	return {}


static func _valid_hold_preview(sim: RefCounted) -> Dictionary:
	return sim.call("preview_ping", "hold_ground", _subject_for_ping(sim, "hold_ground"))


static func _subject_for_ping(sim: RefCounted, ping_id: String) -> Dictionary:
	var state: Dictionary = sim.call("get_state")
	var echo: Dictionary = {}
	var enemy: Dictionary = {}
	for actor_value: Variant in state.get("actors", []):
		var actor: Dictionary = actor_value as Dictionary
		if echo.is_empty() and str(actor.get("faction", "")) == "echo" and not bool(actor.get("is_dead", false)):
			echo = actor
		if enemy.is_empty() and str(actor.get("faction", "")) == "enemy" and not bool(actor.get("is_dead", false)):
			enemy = actor
	match ping_id:
		"hold_ground":
			return {"actor_id": echo.get("id", ""), "anchor": echo.get("grid_pos", {}).duplicate(true)}
		"break_through":
			var start: Dictionary = echo.get("grid_pos", {}).duplicate(true)
			# A one-cell lane is a legal contiguous lane "up to 5 tiles" and keeps this
			# recipient-mode test independent of a particular generated route shape.
			return {"cells": [start]}
		"focus_threat":
			return {"enemy_id": enemy.get("id", "")}
		"regroup":
			return {"rally": echo.get("grid_pos", {}).duplicate(true)}
	return {}


static func _mark_faction_dead(state: Dictionary, faction: String) -> void:
	for actor_value: Variant in state.get("actors", []):
		var actor: Dictionary = actor_value as Dictionary
		if str(actor.get("faction", "")) == faction:
			actor["is_dead"] = true
			actor["current_hp"] = 0


static func _first_actor(state: Dictionary, faction: String) -> Dictionary:
	for actor_value: Variant in state.get("actors", []):
		var actor: Dictionary = actor_value as Dictionary
		if str(actor.get("faction", "")) == faction and not bool(actor.get("is_dead", false)):
			return actor
	return {}


static func _adjacent_walkable(state: Dictionary, origin: Dictionary) -> Dictionary:
	var walkable: Dictionary = state.get("board", {}).get("walkable", {})
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var candidate: Dictionary = {"col": int(origin["col"]) + dx, "row": int(origin["row"]) + dy}
			if walkable.has("%d,%d" % [candidate["col"], candidate["row"]]):
				return candidate
	return {}


static func _replay_signature(seed: int) -> String:
	var sim: RefCounted = _combat(seed, "recover", "seek_signs")
	_set_charge(sim, 5)
	var preview: Dictionary = _valid_hold_preview(sim)
	if bool(preview.get("valid", false)):
		sim.call("confirm_ping", preview)
	_resolve_turns(sim, 20)
	var state: Dictionary = sim.call("get_state")
	return JSON.stringify({"result": state.get("result", {}), "timeline": state.get("timeline", []),
		"actors": state.get("actors", []), "objective": state.get("objective", {})})
