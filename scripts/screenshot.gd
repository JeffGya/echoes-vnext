# Renders a chosen UI screen state to a PNG (ANSWERS.md #65).
#
# Usage (1920x1080 is the reference composition size, AGENTS.md "UI Rules"):
#   xvfb-run -a -s '-screen 0 1920x1080x24' godot --path <checkout> --rendering-driver opengl3 \
#       --resolution 1920x1080 --script res://scripts/screenshot.gd -- <fixture|all|list> [out_dir]
#
#   <fixture>  one key of FIXTURES; "all" renders every fixture; "list" prints the keys.
#   [out_dir]  an absolute directory; default user://screenshots. Output: <out_dir>/<fixture>.png.
#   [profile]  compact, standard or wide: forces that layout profile. Output: <fixture>_<profile>.png.
#
# On macOS, run it from a real window without xvfb:
#   godot --path <checkout> --resolution 1920x1080 --script res://scripts/screenshot.gd -- <fixture> <out_dir>
# Godot's --headless mode cannot render screenshots (dummy renderer, null texture).
#
# The layer hierarchy (RealmShell on layer 10, ModalHost on layer 40, as in Approot.tscn) lives
# in screenshot_harness.tscn (AGENTS.md "Build structure in .tscn"). This script only instances it,
# feeds it a hand-built snapshot and saves the frame. It never boots FlowRuntime, so it writes no save and does not touch the test save
# directory. Step real_pickup:<kind>[:idle|intro][:<variant>][:seed=<n>]; a seed makes core place the row again (pickup_idle_axis_a
# seed 0 gives the row axis, falling to the right; pickup_idle_axis_b seed 1 the col axis, rising to the right).
# EXCEPTION: the fixtures pickup_pack_*, pickup_idle_* and pickup_intro_* play a real won fight through
# FlowRuntime (tests/fixtures/PickupRealBoard.gd) and publish its real flow.pickup snapshot. pickup_idle_* then set only
# the event keys reaction (plus, none) or frozen; the board stays real. pickup_intro_* publish the real first (intro) snapshot. Run them with
# ECHOES_TEST_SAVE_DIR=<fresh dir>; they write and delete save files there. ECHOES_CLIP_EXTRA=<frames> keeps the app running that many frames after the shot (for --write-movie recordings). Fixture pickup_host stays the hand-built U1 frame.
# A fixture's snapshots are applied in order; a flow.resolve snapshot opens as the
# resolve modal over the board before it. To add a screen state, add a FIXTURES entry.
# A fixture copies the snapshot contract; update it when that contract changes.
extends SceneTree

const InventoryUIFixtures := preload("res://tests/fixtures/InventoryUIFixtures.gd")
const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")
const HarnessScene := preload("res://scripts/screenshot_harness.tscn")
const SanctumHarnessScene := preload("res://scripts/screenshot_harness_sanctum.tscn")
const SETTLE_FRAMES := 45


func _initialize() -> void:
	_run()


func _run() -> void:
	# The root enters the tree after _initialize; nodes added before that never get _ready.
	await process_frame
	var args := OS.get_cmdline_user_args()
	var which := str(args[0]) if args.size() > 0 else "list"
	var out_dir := str(args[1]) if args.size() > 1 else "user://screenshots"
	var profile := str(args[2]) if args.size() > 2 else ""
	var fixtures := _fixtures()
	if which == "list" or (which != "all" and not fixtures.has(which)):
		print("Fixtures: all, ", ", ".join(PackedStringArray(fixtures.keys())))
		quit(0 if which == "list" else 1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var names: Array = fixtures.keys() if which == "all" else [which]
	for fixture_name in names:
		await _render_fixture(str(fixture_name), fixtures[fixture_name], out_dir, profile)
	quit(0)


func _render_fixture(fixture_name: String, snapshots: Array, out_dir: String, profile: String = "") -> void:
	var layout := ResponsiveLayoutController.calculate_layout(Vector2(root.size))
	if not profile.is_empty():
		layout["profile"] = StringName(profile)
	ResponsiveLayoutController.apply_content_scale_size(root, layout)

	# A fixture of flow.summon snapshots needs the Sanctum shell, which owns that screen.
	var sanctum_fixture: bool = fixture_name.begins_with("summon_") or fixture_name.begins_with("invs_")
	var harness := (SanctumHarnessScene if sanctum_fixture else HarnessScene).instantiate()
	root.add_child(harness)
	var shell := harness.get_node("ContentLayer/SanctumShell" if sanctum_fixture else "ContentLayer/RealmShell") as Control
	var modal_host := harness.get_node("ModalLayer/ModalHost") as Control
	shell.modal_requested.connect(func(modal_id: StringName, payload: Dictionary) -> void:
		modal_host.call("present_modal_for_id", modal_id, shell.call("modal_scene_for", modal_id), payload))

	shell.call("set_layout", layout)
	for snap in snapshots:
		if snap is Dictionary and snap.has("_modal"):
			var req: Dictionary = snap["_modal"]
			modal_host.call("present_modal_for_id", req["id"], shell.call("modal_scene_for", req["id"]), req["payload"])
		elif snap is String and (snap as String).begins_with("real_pickup:"):
			var real_parts: PackedStringArray = (snap as String).split(":")
			var real_phase := "idle"
			var real_variant := ""
			var real_seed := ""
			for token in real_parts.slice(2):
				if token.begins_with("seed="):
					real_seed = token.substr(5)
				elif token == "idle" or token == "intro":
					real_phase = token
				else:
					real_variant = token
			var real_snap: Dictionary = PickupRealBoard.snapshot(real_parts[1], real_phase, real_variant, real_seed)
			if real_snap.is_empty():
				push_error("real_pickup fixture %s did not reach the pickup event" % real_parts[1])
			else:
				shell.call("set_snapshot", real_snap)
		elif snap is String:
			_run_step(harness, snap)
		else:
			shell.call("set_snapshot", snap)
		await process_frame
	for _i in range(SETTLE_FRAMES):
		await process_frame

	var file_name := fixture_name if profile.is_empty() else "%s_%s" % [fixture_name, profile]
	var path := out_dir.path_join(file_name + ".png")
	var err := root.get_texture().get_image().save_png(path)
	print("SHOT %s -> %s (err=%d)" % [fixture_name, ProjectSettings.globalize_path(path), err])
	# Video proof: run godot with --write-movie <file.avi> --fixed-fps 30 and ECHOES_CLIP_EXTRA=<frames>; the extra frames
	# keep the scene alive after the shot so a recording shows the motion.
	var clip_extra := int(OS.get_environment("ECHOES_CLIP_EXTRA")) if OS.get_environment("ECHOES_CLIP_EXTRA").is_valid_int() else 0
	for _c in range(clip_extra):
		await process_frame
	harness.queue_free()
	StopMarkMotion.reduced = false
	await process_frame


# ── Fixtures ────────────────────────────────────────────────────────────────

func _fixtures() -> Dictionary:
	var recover := { "type": "recover", "hold_progress": 1, "hold_required": 3 }
	var endure := { "type": "endure", "round": 4, "rounds_required": 8, "waves_remaining": 2 }
	var escort := { "type": "guide_spirit", "guide_mode": "escort", "spirit_name": "Nana", "destination_reached": false }
	var fx := InventoryUIFixtures
	return {
		"invs_sanctum": [fx.sanctum_snap(fx.standard()), "inv:toggle_sanct", "inv:select:sanctum:0"],
		"invs_sanctum_empty_details": [fx.sanctum_snap(fx.standard()), "inv:toggle_sanct"],
		"invs_both_panels": [fx.sanctum_snap(fx.standard()), "inv:toggle_sanct", "inv:toggle_pack", "inv:select:pack:0"],
		"invs_stack_selected": [fx.sanctum_snap(fx.standard()), "inv:toggle_sanct", "inv:select:sanctum:3"],
		"invs_party_pack": [fx.party_snap(fx.standard()), "inv:toggle_pack", "inv:select:pack:0"],
		"invs_party_closed": [fx.party_snap(fx.standard())],
		"invr_path": [fx.path_snap(fx.inventory(20, 4, [], [fx.piece(0, "gear", "g2", 3, "Test gear G"), fx.piece(1, "relic", "g3", 0, "Test relic H"), fx.piece(2, "gear", "g1", 4, "Test gear I"), fx.stack(3, "consumable", 4, 20, "Test potion C")], fx.path_data(false))), "inv:toggle_pack", "inv:select:pack:1"],
		"invr_path_used": [fx.path_snap(fx.inventory(20, 4, [], [fx.piece(0, "gear", "g2", 3, "Test gear G")], fx.path_data(true))), "inv:toggle_pack", "inv:select:pack:0"],
		"invr_leave_confirm": [_combat(6, { "type": "recover" }), _return_home_modal({ "ase": 4, "ekwan": 0, "overcome": 1, "total": 3, "nothing_new": false,
			"items_at_risk": [fx.report_row("gear", "g2", 1, "held", "", 1, "Test gear A"), fx.report_row("relic", "g3", 4, "held", "", 1, "Test relic B"),
				fx.report_row("consumable", "", -1, "gathered", "", 5, "Test potion C")] })],
		"invr_leave_result": [_combat(6, { "type": "recover" }), _items_card(_return_card("some", 7, 2), fx.items_block()), "skip_motion"],
		"invr_leave_result_midmotion": [_combat(6, { "type": "recover" }), _items_card(_return_card("some", 7, 2), fx.items_block())],
		"invr_defeat_items": [_combat(7, { "type": "recover" }), _defeat_items(), "skip_motion"],
		"invr_stage_clear_items": [_combat(6, { "type": "recover" }), _items_card(_payout_stage_end(true), fx.items_block()), "skip_motion"],
		"invs_refusal": [fx.sanctum_snap(fx.full_both()), "inv:toggle_sanct", "inv:toggle_pack", "inv:select:pack:1",
			fx.sanctum_snap(_refused(fx.full_both(), "move", "container_full"))],
		"invs_refusal_slot": [fx.sanctum_snap(fx.standard()), "inv:toggle_sanct", "inv:select:sanctum:0",
			fx.sanctum_snap(_refused(fx.standard(), "move", "slot_taken"))],
		"invr_path_refused": [fx.path_snap(fx.inventory(20, 4, [], [fx.piece(0, "gear", "g2", 3, "Test gear G"), fx.piece(1, "relic", "g3", 0, "Test relic H")], fx.path_data(false))),
			"inv:toggle_pack", "inv:select:pack:0",
			fx.path_snap(_refused(fx.inventory(20, 4, [], [fx.piece(0, "gear", "g2", 3, "Test gear G"), fx.piece(1, "relic", "g3", 0, "Test relic H")], fx.path_data(false)), "discard", "bad_state"))],
		"invs_party_lv0": [fx.party_snap(fx.inventory(20, 4, [], [])), "inv:toggle_pack"],
		"invs_party_lv2": [fx.party_snap(fx.inventory(20, 4, [], [fx.piece(0, "gear", "g1", 0, "A"), fx.piece(1, "gear", "g1", 1, "B"), fx.piece(2, "relic", "g2", 2, "C")])), "inv:toggle_pack"],
		"invs_party_lv3": [fx.party_snap(fx.full_both()), "inv:toggle_pack"],
		"invr_path_lv0": [fx.path_snap(fx.inventory(20, 4, [], [], fx.path_data(false))), "inv:toggle_pack"],
		"invr_path_lv2": [fx.path_snap(fx.inventory(20, 4, [], [fx.piece(0, "gear", "g1", 0, "A"), fx.piece(1, "gear", "g1", 1, "B"), fx.piece(2, "relic", "g2", 2, "C")], fx.path_data(false))), "inv:toggle_pack"],
		"invr_path_lv3": [fx.path_snap(fx.inventory(20, 4, [], [fx.piece(0, "gear", "g1", 0, "A"), fx.piece(1, "gear", "g1", 1, "B"), fx.piece(2, "relic", "g2", 2, "C"), fx.piece(3, "gear", "g1", 3, "D")], fx.path_data(false))), "inv:toggle_pack"],
		"invr_discard_stack": [_combat(6, { "type": "recover" }), { "_modal": { "id": &"inventory.discard", "payload": {
			"row": fx.stack(2, "consumable", 12, 20, "Test potion C"), "box": "pack", "slot": 2, "stack": true, "count_max": 12, "path": true } } }],
		"invs_both_full": [fx.sanctum_snap(fx.full_both()), "inv:toggle_sanct", "inv:toggle_pack", "inv:select:pack:1"],
		"combat_pace_full":    [_combat(3, _with(recover, "pace_state", "full"))],
		"combat_pace_partial": [_combat(6, _with(recover, "pace_state", "partial"))],
		"combat_pace_none":    [_combat(9, _with(recover, "pace_state", "none"))],
		"combat_no_pace":      [_combat(4, endure)],
		"combat_escort_pace_partial": [_combat(7, _with(escort, "pace_state", "partial"))],
		"combat_initiative_full": [_combat_initiative(_with(escort, "pace_state", "partial"))],
		"resolve_escort_win":  [_combat(9, escort),
			_resolve(true, "spirit_escorted", 9, "S", { "pace_state": "full", "pace_changed_rank": false })],
		"resolve_pace_win":    [_combat(6, recover),
			_resolve(true, "relic_secured", 6, "B", { "pace_state": "partial", "pace_changed_rank": false })],
		"resolve_pace_win_rank_changed": [_combat(4, recover),
			_resolve(true, "relic_secured", 4, "A", { "pace_state": "full", "pace_changed_rank": true })],
		"resolve_pace_win_zero": [_combat(10, recover),
			_resolve(true, "relic_secured", 10, "C", { "pace_state": "none", "pace_changed_rank": false })],
		"resolve_no_pace_win": [_combat(8, endure), _resolve(true, "endured", 8, "B", {})],
		"resolve_pace_defeat": [_combat(7, recover), _resolve(false, "all_echoes_dead", 7, "F", {})],
		"resolve_ledger_closed": [_combat(6, recover), _payout_stage_end(true), "skip_motion"],
		"resolve_ledger_open_fight": [_combat(6, recover), _payout_repeat_defeat()],
		"resolve_stage_end": [_combat(6, recover), _payout_stage_end(false), "skip_motion"],
		"resolve_stage_end_first_view": [_combat(6, recover), _payout_stage_end(false), "freeze_motion"],
		"resolve_stage_earlier_death": [_combat(6, recover), _payout_stage_earlier_death(), "skip_motion"],
		"resolve_stage_home_lost": [_combat(6, recover), _payout_stage_end(true), "skip_motion"],
		"resolve_stage_home_all": [_combat(6, recover), _payout_stage_all_home(), "skip_motion"],
		"resolve_midstage_win_no_rows": [_combat(6, recover), _payout_midstage_win(), "skip_motion"],
		"resolve_midstage_event": [_combat(6, recover), _payout_midstage_event(), "skip_motion"],
		"resolve_defeat_consolation": [_combat(7, recover), _payout_defeat()],
		"resolve_retreat_zero": [_combat(7, recover), _payout_retreat_zero()],
		"carry_return_home": [_combat(6, recover), _return_home_modal({ "ase": 4, "ekwan": 2, "overcome": 1, "total": 3, "nothing_new": false })],
		"carry_return_home_ase_only": [_combat(6, recover), _return_home_modal({ "ase": 4, "ekwan": 0, "overcome": 1, "total": 3, "nothing_new": false })],
		"carry_return_home_nothing_new": [_combat(6, recover), _return_home_modal({ "ase": 0, "ekwan": 0, "overcome": 1, "total": 3, "nothing_new": true })],
		"carry_return_home_failed": [_combat(6, recover), _return_home_modal({}, true)],
		"return_card_none": [_combat(6, recover), _return_card("none", 0, 0)],
		"return_card_some": [_combat(6, recover), _return_card("some", 7, 2)],
		"return_card_all": [_combat(6, recover), _return_card("all", 14, 4)],
		"return_card_ekwan_only": [_combat(6, recover), _return_card_ekwan_only(), "skip_motion"],
		"return_card_nothing_new": [_combat(6, recover), _return_card("nothing_new", 0, 0)],
		"retreat_card_no_reenter": [_combat(6, recover), _retreat_card(false)],
		"retreat_card_reenter": [_combat(6, recover), _retreat_card(true)],
		"retreat_button": [_prebattle({})],
		"retreat_disabled_price": [_prebattle({ "retreat_affordable": false })],
		"retreat_denied": [_prebattle({ "retreat_affordable": false,
			"retreat_denied": { "reason": "insufficient_ase", "ase_cost": 10, "ase_balance": 4 } })],
		"resolve_tooltip_replay": [_combat(6, recover), _payout_stage_end(false), "skip_motion", "focus_cause:1"],
		"resolve_defeat_tooltip": [_combat(7, recover), _payout_defeat(), "focus_cause:0"],
		"return_card_empty_leave": [_combat(6, recover), _return_card_empty_leave()],
		"resolve_tooltip_open": [_combat(6, recover), _payout_stage_end(false), "skip_motion", "focus_cause:2"],
		"standoff_first": [_combat(6, recover), _standoff_card(1, false, "unknown", [], [])],
		"standoff_second": [_combat(6, recover), _standoff_card(2, true, "blocked", [], [])],
		"standoff_froze_two": [_combat(6, recover), _standoff_card(2, true, "froze", ["Ama", "Kofi"], [])],
		"standoff_calm": [_combat(6, recover), _standoff_card(3, true, "froze", ["Ama", "Kofi"], ["Ama", "Kofi"])],
		"standoff_fight_gone": [_combat(6, recover), _standoff_card(3, true, "froze", ["Ama", "Kofi"], ["Ama", "Kofi"], false)],
		"pickup_host": [_pickup_host()],
		"pickup_pack_empty": ["real_pickup:empty"],
		"pickup_pack_near": ["real_pickup:near"],
		"pickup_pack_full": ["real_pickup:full"],
		"pickup_idle_plus": ["real_pickup:empty:idle:plus"],
		"pickup_idle_none": ["real_pickup:full:idle:none"],
		"pickup_idle_frozen": ["real_pickup:near:idle:frozen"],
		"pickup_intro_many": ["real_pickup:many:intro"],
		"pickup_intro_many_b": ["real_pickup:many:intro:seed=1"],
		"pickup_intro_pointer": ["real_pickup:many:intro:seed=0"],
		"pickup_intro_pointer_b": ["real_pickup:many:intro:seed=1"],
		# Fixed-time stills of the mote (seed 0, 5 Echoes, chooser index 2: path 3.79 s, P0 0.5 s; intro time = path time + 0.5).
		# 2.5 = path 2.0, mid-glide on the return leg; 1.7 = path 1.2, the first half turn; 4.49 = 0.2 s into the landing; 4.89 = end of the hold.
		"pickup_intro_pointer_t1": ["real_pickup:many:intro:seed=0", "pointer_at:2.5"],
		"pickup_intro_pointer_turn": ["real_pickup:many:intro:seed=0", "pointer_at:1.7"],
		"pickup_intro_pointer_land": ["real_pickup:many:intro:seed=0", "pointer_at:4.49"],
		"pickup_intro_pointer_hold": ["real_pickup:many:intro:seed=0", "pointer_at:4.89"],
		# R6b stills (seed 0): end of the first leg (the out leg), and the plan total, where the chooser stands on chooser_end_cell. Both read the plan.
		# R6c stills: the first taken find at its reveal, mid-flight, and the intro end (strip filled, tone changed). `empty` has two taken finds.
		"pickup_intro_empty_clip": ["real_pickup:empty:intro:seed=0"],
		"pickup_intro_reduced": ["reduced:1", "real_pickup:empty:intro:seed=0"],
		"pickup_intro_bark": ["real_pickup:empty:intro:seed=0", "pointer_at_bark"],
		"pickup_intro_reduced_hold": ["reduced:1", "real_pickup:empty:intro:seed=0", "pointer_at_find:0:hold"],
		"pickup_intro_reduced_flight": ["reduced:1", "real_pickup:empty:intro:seed=0", "pointer_at_find:0:flight"],
		"pickup_intro_reduced_end": ["reduced:1", "real_pickup:empty:intro:seed=0", "pointer_at_total"],
		"pickup_intro_reveal": ["real_pickup:empty:intro:seed=0", "pointer_at_find:0:reveal"],
		"pickup_intro_carry": ["real_pickup:empty:intro:seed=0", "pointer_at_find:0:lift"],
		"pickup_intro_hold": ["real_pickup:empty:intro:seed=0", "pointer_at_find:0:hold"],
		"pickup_intro_flight": ["real_pickup:empty:intro:seed=0", "pointer_at_find:0:flight"],
		"pickup_intro_end": ["real_pickup:empty:intro:seed=0", "pointer_at_total"],
		"pickup_intro_reveal_many": ["real_pickup:many:intro:seed=0", "pointer_at_find:0:reveal"],
		"pickup_intro_flight_many": ["real_pickup:many:intro:seed=0", "pointer_at_find:0:flight"],
		"pickup_intro_end_many": ["real_pickup:many:intro:seed=0", "pointer_at_total"],
		"pickup_intro_walk_out": ["real_pickup:many:intro:seed=0", "pointer_at_leg_end"],
		"pickup_intro_walk_end": ["real_pickup:many:intro:seed=0", "pointer_at_total"],
		"pickup_intro_empty": ["real_pickup:empty:intro"],
		"pickup_intro_near": ["real_pickup:near:intro"],
		"pickup_intro_full": ["real_pickup:full:intro"],
		"pickup_intro_axis_a": ["real_pickup:empty:intro:seed=0"],
		"pickup_intro_axis_b": ["real_pickup:empty:intro:seed=1"],
		"pickup_idle_many": ["real_pickup:many:idle:none"],
		"pickup_idle_many_b": ["real_pickup:many:idle:none:seed=1"],
		"pickup_idle_axis_a": ["real_pickup:empty:idle:plus:seed=0"],
		"pickup_idle_axis_b": ["real_pickup:empty:idle:plus:seed=1"],
		"pickup_idle_zoomed_out": ["real_pickup:empty:idle:plus", "cam_zoom:0.3", "cam_frame"],
		"warning_level_1": [_combat_stall(1, "")],
		"warning_level_2": [_combat_stall(2, "Ama")],
		"prebattle_stalled": [_prebattle({ "stalled_before": true })],
		"fight_won_packs": [_combat(6, recover), _payout_fight_won_packs(), "skip_motion"],
		"found_money_card": [_combat(6, recover), _found_money_card()],
		"defeat_packs_lost": [_combat(7, recover), _payout_defeat_packs_lost()],
		"carry_packs_gathered": [_combat(6, recover), _return_home_modal(_preview(12, 3))],
		"carry_packs_empty": [_combat(6, recover), _return_home_modal(_preview(0, 0))],
		"summon_price_rising":   [_summon({})],
		"summon_price_flat":     [_summon({ "living_count": 14, "price_flat": true, "batch_affordable_max": 1,
			"batch_prices": [430, 430, 430, 430, 430, 430, 430, 430, 430, 430],
			"batch_totals": [430, 860, 1290, 1720, 2150, 2580, 3010, 3440, 3870, 4300],
			"ase_balance": 500,
			"summon_grade_options": _summon_grades(430, 430) })],
		"summon_price_short":    [_summon({ "ase_balance": 100, "batch_affordable_max": 0, "summon_disabled": true, "ase_short_by": 45 })],
	}


func _summon_grades(uncalled: int, after: int) -> Array:
	return [
		{ "key": "uncalled", "label": "Uncalled", "enabled": true, "ase_cost": uncalled, "ase_cost_after": after },
		{ "key": "called", "label": "Called", "enabled": false, "ase_cost": uncalled + 90, "ase_cost_after": after + 90 },
		{ "key": "chosen", "label": "Chosen", "enabled": false, "ase_cost": uncalled + 340, "ase_cost_after": after + 340 },
	]


# FlowSummonState.build_snapshot data keys, V2-ECONOMY-004 Phase 5.5. Defaults: 7 living, 700 Ase.
func _summon(over: Dictionary) -> Dictionary:
	var data := {
		"title": "Summon Echo", "ase_balance": 700, "ase_rate_per_hour_hint": 4.0, "living_count": 7,
		"village_ceiling": 14, "price_flat": false, "selected_grade": "uncalled", "summon_disabled": false,
		"batch_prices": [145, 175, 210, 250, 300, 360, 430, 430, 430, 430],
		"batch_totals": [145, 320, 530, 780, 1080, 1440, 1870, 2300, 2730, 3160],
		"batch_affordable_max": 3, "ase_short_by": 0,
		"summon_grade_options": _summon_grades(145, 175), "pending_summon_reveals": [],
	}
	for k in over.keys():
		data[k] = over[k]
	return { "type": "flow.summon", "data": data, "actions": { "cta.summon": { "type": "sanctum.summon", "slot": "cta.summon" } } }


func _with(d: Dictionary, key: String, value: Variant) -> Dictionary:
	var out := d.duplicate(true)
	out[key] = value
	return out


func _actors() -> Array:
	return [
		_actor("e1", "Ama", "echo", 2, 5, 18, 22),
		_actor("e2", "Kofi", "echo", 3, 6, 12, 20),
		_actor("e3", "Esi", "echo", 2, 7, 20, 20),
		_actor("m1", "Hollow", "enemy", 6, 2, 9, 14),
		_actor("m2", "Hollow", "enemy", 7, 3, 14, 14),
	]


func _actor(id: String, actor_name: String, faction: String, col: int, row: int, hp: int, max_hp: int) -> Dictionary:
	return {
		"id": id, "name": actor_name, "faction": faction,
		"grid_pos": { "col": col, "row": row },
		"hp": hp, "current_hp": hp, "max_hp": max_hp,
		"emotional_status": "grounded",
	}


func _combat(round_num: int, objective_state: Dictionary) -> Dictionary:
	return {
		"type": "flow.encounter",
		"meta": { "t": 1 },
		"data": {
			"encounter_id": "screenshot",
			"board_cols": 10, "board_rows": 10,
			"round": round_num,
			"round_phase": "actor_turn",
			"combat_over": false,
			"actors": _actors(),
			"current_actor_id": "",
			"objective_state": objective_state,
		},
		"actions": {},
	}


## U1 host fixture: the flow.pickup shape (board keys and actors, idle phase) with no event content.
func _pickup_host() -> Dictionary:
	return {
		"type": "flow.pickup",
		"meta": { "t": 1 },
		"data": {
			"phase": "idle", "situation_id": "screenshot_pickup", "run_count": 1,
			"encounter_id": "screenshot", "board_cols": 10, "board_rows": 10,
			"terrain": {}, "placement_seed": 0, "actors": _actors(),
		},
		"actions": { "cta.continue": { "type": "pickup.continue", "slot": "cta.continue" } },
	}


## Eight initiative rows: five echoes, the escorted spirit and two enemies, with some action text.
func _combat_initiative(objective_state: Dictionary) -> Dictionary:
	var snap := _combat(5, objective_state)
	var actors: Array = _actors()
	actors.append(_actor("e4", "Yaw", "echo", 3, 4, 16, 20))
	actors.append(_actor("e5", "Abena", "echo", 2, 3, 20, 24))
	actors.append(_actor("s1", "Nana", "spirit", 4, 5, 10, 10))
	var order: Array = []
	for a in ["e1", "m1", "e2", "s1", "e3", "m2", "e4", "e5"]:
		for actor in actors:
			if actor["id"] == a:
				order.append({ "id": a, "name": actor["name"] })
	snap["data"]["actors"] = actors
	snap["data"]["initiative_order"] = order
	snap["data"]["active_initiative_index"] = 3
	snap["data"]["action_results"] = [
		{ "source_id": "e1", "action_type": "melee_attack", "target_name": "Hollow", "damage": 6 },
		{ "source_id": "m1", "action_type": "actor.move", "target_name": "Ama" },
		{ "source_id": "e2", "action_type": "actor.guard" },
	]
	return snap


func _resolve(victory: bool, reason: String, round_ended: int, rank: String, pace: Dictionary) -> Dictionary:
	var breakdown: Array = []
	if victory:
		breakdown.append({ "label": "3 echoes survived", "delta": 15, "currency": "ase" })
	else:
		breakdown.append({ "label": "Base objectives", "delta": 40, "currency": "ase" })
		breakdown.append({ "label": "Defeat penalty", "delta": -30, "currency": "ase" })
	var total := 0
	for row in breakdown:
		total += int(row["delta"])
	var data := {
		"victory": victory,
		"reason": reason,
		"rank": rank,
		"ase_awarded": total,
		"enemies_defeated": 2,
		"echoes_survived": 3 if victory else 0,
		"round_ended": round_ended,
		"reward_breakdown": breakdown,
		"emotion_summary": [],
		"actors": _actors(),
	}
	data.merge(pace)
	var actions := { "cta.continue": { "type": "flow.go_state", "slot": "cta.continue", "label": "To Sanctum" } }
	return { "type": "flow.resolve", "meta": { "t": 2 }, "data": data, "actions": actions }


## A fixture step that is a String acts on the live scene. "focus_cause:N" focuses the Nth (i) button.
func _run_step(harness: Node, step: String) -> void:
	var parts := step.split(":")
	if parts[0] == "inv":
		var panels := harness.find_child("InventoryPanels", true, false)
		if panels == null:
			return
		if parts[1] == "toggle_sanct":
			panels.call("toggle_sanctum")
		elif parts[1] == "toggle_pack":
			panels.call("toggle_pack")
		elif parts[1] == "select":
			panels.call("_on_slot_chosen", parts[2], int(parts[3]))
	if parts[0] == "cam_zoom" or parts[0] == "cam_frame":
		var board_camera := harness.find_child("BoardCamera", true, false) as Camera2D
		if board_camera != null and board_camera.owner != null and parts[0] == "cam_zoom":
			# The opening tween would overwrite the zoom, so it is killed first.
			board_camera.owner.call("_kill_pickup_camera_tween")
			board_camera.zoom = Vector2(float(parts[1]), float(parts[1]))
			print("CAM zoom before reframe: %s" % board_camera.zoom.x)
		if board_camera != null and board_camera.owner != null and parts[0] == "cam_frame":
			board_camera.owner.call("frame_pickup_camera", false)
			print("CAM zoom after reframe: %s" % board_camera.zoom.x)
	if parts[0] == "reduced":
		# reduced:1 sets the project's reduced-motion flag (before the snapshot, so the plan is built reduced); it is cleared after the shot.
		StopMarkMotion.reduced = parts[1] == "1"
	if parts[0] == "pointer_at_bark":
		# Moves the intro clock to just after the chooser's bark time (the plan's `bark.t0`) and stops it.
		var bark_stage := harness.find_child("PickupEventStage", true, false)
		if bark_stage != null:
			var bark_plan: Dictionary = bark_stage.call("plan")
			var bark_at := float((bark_plan.get("bark", {}) as Dictionary).get("t0", 0.0)) + 0.05
			bark_stage.call("advance", maxf(bark_at - float(bark_stage.call("clock_time")), 0.0))
			bark_stage.set_process(false)
	if parts[0] == "pointer_at_find":
		# pointer_at_find:<k>:<phase> moves the intro clock to a moment of the k-th taken find (in the order the chooser takes them) and
		# stops it. phase: reveal (middle of the flip), lift (middle of the carry), hold (middle of the hold at the head), flight (middle), landed (the end of the flight). Reads the plan.
		var find_stage := harness.find_child("PickupEventStage", true, false)
		if find_stage != null:
			var find_plan: Dictionary = find_stage.call("plan")
			var taken: Array = (find_plan.get("finds", []) as Array).filter(func(f: Dictionary) -> bool: return bool(f["walked"]) and not bool(f["is_try"]))
			taken.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["lift0"]) < float(b["lift0"]))
			var k := int(parts[1])
			if k < taken.size():
				var f: Dictionary = taken[k]
				var at := 0.0
				match parts[2]:
					"reveal":
						at = float(f["reveal"]) + float(f["reveal_len"]) * 0.5
					"lift":
						at = (float(f["lift0"]) + float(f["lift1"])) * 0.5
					"hold":
						at = (float(f["lift1"]) + float(f["fly0"])) * 0.5
					"flight":
						at = (float(f["fly0"]) + float(f["fly1"])) * 0.5
					_:
						at = float(f["fly1"])
				find_stage.call("advance", maxf(at - float(find_stage.call("clock_time")), 0.0))
				find_stage.set_process(false)
	if parts[0] in ["pointer_advance", "pointer_at", "pointer_at_leg_end", "pointer_at_total"]:
		# pointer_advance:<s> moves the intro clock on by <s> in one tick; pointer_at:<t> moves it to the intro time <t> and then
		# stops it, so the PNG shows that exact moment (later frames would add time). pointer_at_leg_end moves it to the end of the
		# chooser's first leg and pointer_at_total to the plan total: both read the plan, so the stills follow the config.
		var stage := harness.find_child("PickupEventStage", true, false)
		if stage != null:
			var plan: Dictionary = stage.call("plan")
			var now := float(stage.call("clock_time"))
			var delta := 0.0
			match parts[0]:
				"pointer_advance":
					delta = float(parts[1])
				"pointer_at":
					delta = maxf(float(parts[1]) - now, 0.0)
				"pointer_at_leg_end":
					delta = maxf(float((plan["legs"] as Array)[0]["t1"]) - now, 0.0) if not (plan.get("legs", []) as Array).is_empty() else 0.0
				"pointer_at_total":
					delta = maxf(float(plan.get("total", now)) - now, 0.0)
			stage.call("advance", delta)
			if parts[0] != "pointer_advance":
				stage.set_process(false)
	if parts[0] == "freeze_motion":
		for node in harness.find_children("*", "Control", true, false):
			if node.has_method("skip_motion") and node.get("_motion") != null:
				(node.get("_motion") as Tween).pause()
	if parts[0] == "skip_motion":
		for node in harness.find_children("*", "Control", true, false):
			if node.has_method("skip_motion"):
				node.call("skip_motion")
	if parts[0] == "focus_cause":
		var buttons := harness.find_children("CauseButton", "Button", true, false)
		var visible_buttons := buttons.filter(func(b: Node) -> bool: return (b as Button).is_visible_in_tree())
		var index := int(parts[1]) if parts.size() > 1 else 0
		if index < visible_buttons.size():
			(visible_buttons[index] as Button).grab_focus()


func _row(label: String, delta: int, cause: String, params: Dictionary = {}) -> Dictionary:
	return { "label": label, "delta": delta, "currency": "ase", "cause": cause, "params": params }


## Fixture amounts are arbitrary. The real values come from EconomyService.
func _payout_data(victory: bool, reason: String, rank: String, rows: Array, seen: bool) -> Dictionary:
	var total := 0
	for row in rows:
		total += int(row["delta"])
	return {
		"victory": victory, "reason": reason, "rank": rank, "ase_awarded": total, "ekwan_awarded": 0,
		"enemies_defeated": 3, "echoes_survived": 3 if victory else 0, "round_ended": 6,
		"reward_breakdown": rows, "ledger_seen": seen, "actors": _actors(),
		"emotion_summary": [
			{ "echo_id": "e1", "name": "Ama", "pre_emotional_status": "grounded", "post_emotional_status": "radiant", "direction": "lift" },
			{ "echo_id": "e2", "name": "Kofi", "pre_emotional_status": "grounded", "post_emotional_status": "uncertain", "direction": "fall" },
			{ "echo_id": "e3", "name": "Esi", "pre_emotional_status": "grounded", "post_emotional_status": "grounded", "direction": "steady" },
		],
	}


func _payout_snap(data: Dictionary) -> Dictionary:
	var actions := { "cta.continue": { "type": "flow.go_state", "slot": "cta.continue", "label": "To Sanctum" } }
	return { "type": "flow.resolve", "meta": { "t": 2 }, "data": data, "actions": actions }


## A mid-stage win pays nothing and has no rows: the Direction E card. Three Echoes, all alive.
func _payout_midstage_win() -> Dictionary:
	var data := _payout_data(true, "relic_secured", "A", [], true)
	data["pace_state"] = "partial"
	return _payout_snap(data)


## The same card with every line present: a shaken Echo, an overcome objective, intel, a whole Thread.
func _payout_midstage_event() -> Dictionary:
	var snap := _payout_midstage_win()
	snap["data"]["emotion_summary"][1]["direction"] = "fall"
	snap["data"]["intel_gained"] = 1
	snap["data"]["thread_whole"] = true
	snap["data"]["objective_overcome"] = { "index": 1, "type": "recover", "label": "A lost keepsake is recovered." }
	return snap


func _payout_stage_end(seen: bool) -> Dictionary:
	var snap := _payout_midstage_win()
	var stage_rows := [
		_row("Base objectives", 90, "objectives_overcome", { "overcome": 2, "total": 3, "realm_scale": 1.0 }),
		_row("Redo penalty", -58, "replay", { "factor": 0.35 }),
		_row("Echoes home", 4, "echoes_alive", { "alive": 2, "started": 3, "lost": ["Kofi"], "cap": 10, "replay": true }),
		_row("Settled when you left", 0, "settled_on_leave", { "settled_ase": 20, "settled_ekwan": 3 }),
	]
	snap["data"]["ledger_seen"] = seen
	snap["data"]["echoes_survived"] = 2
	snap["data"]["stage_payout_rows"] = stage_rows
	snap["data"]["stage_payout_ase"] = 16
	snap["data"]["stage_payout_ekwan"] = 4
	snap["actions"]["cta.next_stage"] = { "type": "flow.complete_stage", "slot": "cta.next_stage", "label": "Continue" }
	return snap


func _payout_stage_all_home() -> Dictionary:
	var snap := _payout_stage_end(true)
	var rows: Array = snap["data"]["stage_payout_rows"]
	rows[2] = _row("Echoes home", 6, "echoes_alive", { "alive": 3, "started": 3, "lost": [], "cap": 10, "replay": false })
	snap["data"]["echoes_survived"] = 3
	return snap


## Yaw died in an earlier fight: params.lost names him, no row of this fight carries him.
func _payout_stage_earlier_death() -> Dictionary:
	var snap := _payout_stage_end(true)
	var rows: Array = snap["data"]["stage_payout_rows"]
	rows[2] = _row("Echoes home", 6, "echoes_alive", { "alive": 3, "started": 4, "lost": ["Yaw"], "cap": 10, "replay": false })
	snap["data"]["echoes_survived"] = 3
	return snap


func _payout_repeat_defeat() -> Dictionary:
	return _payout_snap(_payout_data(false, "all_echoes_dead", "F", [_row("Repeat defeat", 0, "repeat_defeat")], false))


func _payout_defeat() -> Dictionary:
	var rows := [
		_row("Base objectives", 40, "defeat_consolation", { "part": "base" }),
		_row("Defeat penalty", -30, "defeat_consolation", { "part": "penalty" }),
		_row("Redo penalty", -1, "replay", { "factor": 0.9 }),
	]
	return _payout_snap(_payout_data(false, "all_echoes_dead", "F", rows, false))


func _payout_retreat_zero() -> Dictionary:
	var data := _payout_data(false, "", "F", [_row("Nothing overcome yet", 0, "nothing_overcome_yet")], false)
	data["run_type"] = "scout_return"
	data["intel_count"] = 0
	data["actors"] = _actors()
	return _payout_snap(data)


## The standoff card, built by the real producer so the fixture follows the contract.
func _standoff_card(count: int, can_sanctum: bool, cause: String, froze: Array, calmed: Array, fight_returns: bool = true) -> Dictionary:
	return VentureResolveSnapshotBuilder.build_standoff_snapshot({ "standoff_count": count, "can_go_sanctum": can_sanctum,
		"cause": cause, "froze_names": froze, "calmed_names": calmed, "fight_returns": fight_returns }, 3)


## A quiet fight: the round snapshot with stall_level (and the Echo that froze at level 2).
func _combat_stall(level: int, froze_name: String) -> Dictionary:
	var snap := _combat(11, { "type": "combat" })
	snap["data"]["stall_level"] = level
	snap["data"]["stall_froze_name"] = froze_name
	return snap


func _preview(ase: int, ekwan: int) -> Dictionary:
	return { "ase": ase, "ekwan": ekwan, "overcome": 1, "total": 3, "nothing_new": ase + ekwan == 0,
		"gathered": { "ase": ase, "ekwan": ekwan, "rows": [], "has_fight_rows": ase > 0, "has_found_rows": false } }


## A mid-path fight win: the mid-stage card plus the one encounter_gathered row.
func _payout_fight_won_packs() -> Dictionary:
	var snap := _payout_midstage_win()
	snap["data"]["reward_breakdown"] = [_row("Fight won", 6, "encounter_gathered", { "kind": "combat", "gathered_ase": 6 })]
	snap["data"]["ase_awarded"] = 0
	snap["data"]["ledger_seen"] = false
	return snap


func _found_money_card() -> Dictionary:
	var snap := VentureResolveSnapshotBuilder.build_situation_resolve_snapshot({ "type": "money" }, "A small purse lay in the grass.", [], [], 12, 2)
	snap["data"]["actors"] = _actors()
	return snap


func _payout_defeat_packs_lost() -> Dictionary:
	var snap := _payout_defeat()
	snap["data"]["reward_breakdown"].append(_row("Packs lost", 0, "packs_lost", { "lost_ase": 12, "lost_ekwan": 0 }))
	return snap


func _refused(inv: Dictionary, action: String, reason: String) -> Dictionary:
	var copy := inv.duplicate(true)
	copy["refused"] = { "action": action, "reason": reason }
	return copy


func _items_card(snap: Dictionary, items: Dictionary) -> Dictionary:
	snap["data"]["items"] = items
	return snap


func _defeat_items() -> Dictionary:
	var snap := _payout_defeat()
	var lost: Array = []
	for r in InventoryUIFixtures.items_block()["kept"] + InventoryUIFixtures.items_block()["lost"]:
		var row: Dictionary = (r as Dictionary).duplicate()
		row["reason_key"] = "defeat"
		lost.append(row)
	snap["data"]["reward_breakdown"].append(_row("Packs lost", 0, "packs_lost", { "lost_ase": 0, "lost_ekwan": 0, "items": lost }))
	return snap


## The confirmation opens before the action. `failed` builds the failed-escape display instead.
func _return_home_modal(carry: Dictionary, failed: bool = false) -> Dictionary:
	if failed:
		return { "_modal": { "id": &"realm.return_home", "payload": {
			"result": { "success": false, "message": "It was not possible to escape at the moment. Move on, we can try again later." } } } }
	return { "_modal": { "id": &"realm.return_home", "payload": {
		"confirm": true, "action": { "type": "stage.return_home" }, "carry": carry } } }


## The card after a return: the outcome in words, then the amounts. The ledger row has no label here.
func _return_card(outcome: String, ase: int, ekwan: int) -> Dictionary:
	var data := _payout_data(false, "", "F", [_row("Settled when you left", ase, "settle_" + outcome)], true)
	data["run_type"] = "scout_return"
	data["intel_count"] = 2
	data["settle_outcome"] = outcome
	data["ase_awarded"] = ase
	data["ekwan_awarded"] = ekwan
	data["actors"] = _actors()
	return _payout_snap(data)


## Ekwan above 0 and no other row: the ledger that opens holds only the total and the Ekwan line.
func _return_card_ekwan_only() -> Dictionary:
	var snap := _return_card("some", 0, 5)
	snap["data"]["ledger_seen"] = false
	return snap


## Left with nothing completed: the core still sends settle_outcome "nothing_new"; the card shows the row only.
func _return_card_empty_leave() -> Dictionary:
	var snap := _return_card("nothing_new", 0, 0)
	snap["data"]["reward_breakdown"] = [_row("Nothing overcome yet", 0, "nothing_overcome_yet", { "overcome": 0, "total": 3 })]
	return snap


## The card after a combat retreat: words only and one button.
func _retreat_card(can_reenter: bool) -> Dictionary:
	return { "type": "flow.resolve", "meta": { "t": 1 }, "actions": { "cta.continue": {
		"type": "stage.retreat_return", "label": "Leave", "slot": "cta.continue" } },
		"data": { "run_type": "retreat_return", "surface": "retreat_return", "retreat_outcome": "pulled_back", "can_reenter": can_reenter } }


## A pre-combat snapshot: the shell shows the pre-battle modal with the retreat button.
func _prebattle(extra: Dictionary) -> Dictionary:
	var snap := _combat(1, { "type": "combat" })
	var actors: Array = _actors()
	for a in actors:
		if a["faction"] == "echo":
			a["emotional_status"] = "grounded"
	snap["data"]["actors"] = actors
	snap["data"]["round_phase"] = "pre_combat"
	snap["data"]["retreat_eligible"] = true
	snap["data"]["retreat_ase_cost"] = 10
	snap["data"]["retreat_affordable"] = true
	snap["data"].merge(extra, true)
	snap["actions"] = {
		"cta.combat_init": { "type": "combat.init", "slot": "cta.combat_init", "label": "Start Combat" },
		"cta.retreat": { "type": "encounter.retreat", "slot": "cta.retreat", "ase_cost": 10 } }
	return snap
