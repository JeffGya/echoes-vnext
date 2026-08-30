# res://tests/StageExploreP5Tests.gd
# V2-STAGE-004 Phase 5 — UI/UX backend seams: directive composite, party_preview
# emotional_status, situation_pending.choices (obstacle/structure), travel-beat
# (bark/snippet) selection + determinism + non-advance gating, and data-file
# contract checks for anansi_travel_snippets.json / journey.json.
#
# Tests:
#   1.  explore_p5/directive_composite_id_label_present     — data.directive has non-empty id + label
#   2.  explore_p5/directive_composite_matches_active        — id/label match the active directive config entry
#   3.  explore_p5/party_preview_emotional_status_valid_tier — every party_preview entry's emotional_status is one of the 10 canonical tiers
#   4.  explore_p5/party_preview_emotional_status_matches_service — matches EmotionService.get_emotional_status(morale, fear) for the same echo
#   5.  explore_p5/situation_pending_choices_obstacle_nonempty — obstacle pending situation → choices non-empty, each has id+label
#   6.  explore_p5/situation_pending_choices_structure_nonempty — structure pending situation → choices non-empty, each has id+label
#   7.  explore_p5/situation_pending_choices_combat_empty     — combat pending situation → choices == []
#   8.  explore_p5/situation_pending_choices_loot_empty       — loot pending situation → choices == []
#   9.  explore_p5/travel_beat_bark_on_odd_t                 — t=1 advance (moved) → travel_bark populated, travel_snippet empty
#   10. explore_p5/anansi_snippet_on_first_entry             — fresh stage enter() (event-driven) → travel_snippet populated (first-entry whisper)
#   11. explore_p5/travel_beat_determinism_same_seed         — two fresh runtimes, identical seed + actions → identical bark/snippet sequence
#   12. explore_p5/travel_beat_gated_on_non_advance_refresh  — re-entering (session reset, already-locked) clears travel_bark/travel_snippet, fires no snippet
#   13. explore_p5/travel_snippets_json_contract             — anansi_travel_snippets.json parses, "travel" has ≥20 lines
#   14. explore_p5/journey_travel_shout_resolves_non_fallback — ShoutBank.get_expression_shout("journey.travel", "canny", "forming", "", 0) is non-empty and not the generic fallback line
#   15. explore_p5/anansi_no_snippet_on_plain_advance        — a plain travel advance (no narrative event) fires NO Anansi snippet

extends RefCounted
class_name StageExploreP5Tests

const SituationModelScript        := preload("res://core/realms/SituationModel.gd")
const StageExploreModelScript     := preload("res://core/realms/StageExploreModel.gd")
const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")
const StageTerrainScript          := preload("res://core/realms/StageTerrain.gd")
const EmotionServiceScript        := preload("res://core/emotion/EmotionService.gd")

static var TEST_SAVE_PATH := TestSaveHarness.dir() + "explore_p5_slot.json"

# Canonical 10-tier emotional_status set (EmotionService.get_emotional_status).
const VALID_EMOTIONAL_TIERS: Array = [
	"hollow", "fraying", "strained", "pressed", "burdened",
	"radiant", "whole", "grounded", "uncertain", "hesitant",
]


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("explore_p5/directive_composite_id_label_present",       Callable(StageExploreP5Tests, "_t_directive_composite_id_label_present"))
	runner.register_test("explore_p5/directive_composite_matches_active",         Callable(StageExploreP5Tests, "_t_directive_composite_matches_active"))
	runner.register_test("explore_p5/party_preview_emotional_status_valid_tier",  Callable(StageExploreP5Tests, "_t_party_preview_emotional_status_valid_tier"))
	runner.register_test("explore_p5/party_preview_emotional_status_matches_service", Callable(StageExploreP5Tests, "_t_party_preview_emotional_status_matches_service"))
	runner.register_test("explore_p5/situation_pending_choices_obstacle_nonempty", Callable(StageExploreP5Tests, "_t_situation_pending_choices_obstacle_nonempty"))
	runner.register_test("explore_p5/situation_pending_choices_structure_nonempty", Callable(StageExploreP5Tests, "_t_situation_pending_choices_structure_nonempty"))
	runner.register_test("explore_p5/situation_pending_choices_combat_empty",     Callable(StageExploreP5Tests, "_t_situation_pending_choices_combat_empty"))
	runner.register_test("explore_p5/situation_pending_choices_loot_empty",       Callable(StageExploreP5Tests, "_t_situation_pending_choices_loot_empty"))
	runner.register_test("explore_p5/travel_beat_bark_on_odd_t",                  Callable(StageExploreP5Tests, "_t_travel_beat_bark_on_odd_t"))
	runner.register_test("explore_p5/anansi_snippet_on_first_entry",              Callable(StageExploreP5Tests, "_t_anansi_snippet_on_first_entry"))
	runner.register_test("explore_p5/travel_beat_determinism_same_seed",          Callable(StageExploreP5Tests, "_t_travel_beat_determinism_same_seed"))
	runner.register_test("explore_p5/travel_beat_gated_on_non_advance_refresh",   Callable(StageExploreP5Tests, "_t_travel_beat_gated_on_non_advance_refresh"))
	runner.register_test("explore_p5/travel_snippets_json_contract",              Callable(StageExploreP5Tests, "_t_travel_snippets_json_contract"))
	runner.register_test("explore_p5/journey_travel_shout_resolves_non_fallback", Callable(StageExploreP5Tests, "_t_journey_travel_shout_resolves_non_fallback"))
	runner.register_test("explore_p5/anansi_no_snippet_on_plain_advance",         Callable(StageExploreP5Tests, "_t_anansi_no_snippet_on_plain_advance"))


# ─── Save-file isolation helpers (mirrors UnifiedResolveTests) ──────────────
# Tests that boot a real FlowRuntime flush to disk — capture/restore keeps the
# developer's real save file untouched.

static func _capture_save() -> Dictionary:
	var path: String = TEST_SAVE_PATH
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		return { "existed": true, "bytes": bytes }
	return { "existed": false, "bytes": PackedByteArray() }


static func _restore_save(snapshot: Dictionary) -> void:
	var path: String = TEST_SAVE_PATH
	if snapshot.get("existed", false):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_buffer(snapshot["bytes"])
			f.close()
	else:
		if FileAccess.file_exists(path):
			var global_path := ProjectSettings.globalize_path(path)
			var dir := DirAccess.open(global_path.get_base_dir())
			if dir:
				dir.remove(global_path.get_file())


static func _make_logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level("off")
	return l


# ─── ctx-only helpers (no full FlowRuntime — mirrors StageExploreTests) ─────
# Used for directive-composite and situation_pending.choices tests: these read
# flow_ctx.config_service, so we load the REAL balance.json (no full runtime
# boot needed — build_snapshot is a pure static function of ctx).

static func _make_ctx_with_real_config(realm_id: String = "realm.01", stage_id: String = "stage.0") -> FlowContext:
	var ctx := FlowContext.new()
	var logger := _make_logger()
	ctx.logger              = logger
	ctx.realm_id            = realm_id
	ctx.stage_id            = stage_id
	ctx.save_request        = false
	ctx.save_request_reason = ""
	ctx.save_data = {
		"realms": {},
		"sanctum": { "roster": [], "active_party_ids": [] },
		"stage_context": { "active_directive_id": "directive.scout_carefully" },
	}
	ctx.campaign_seed = CampaignSeed.new(42)

	var config := ConfigService.new()
	config.load_balance(logger, 0)
	ctx.config_service = config

	return ctx


# Inject a single-situation stage with the given type, revealed + pending, for
# situation_pending.choices tests.
static func _inject_pending_situation(ctx: FlowContext, sit_type: String) -> void:
	var sit := SituationModelScript.make("sit.pending", sit_type, 5, 5, 777, false)
	sit["revealed"] = true

	var explore_map := StageExploreModelScript.make(30, 30, [sit])
	explore_map["pending_situation_id"] = "sit.pending"
	explore_map["party_pos"] = { "col": 5, "row": 5 }

	var stage := StageModel.make(0, StageModel.TYPE_COMBAT, 999, [], explore_map)
	var model := RealmModel.make(ctx.realm_id, "Vale of Dust", "courage", "desc", 42, 1, 0, 0)
	model["stages"] = [stage]
	ctx.save_data["realms"][ctx.realm_id] = model


# Inject a roster of party echoes with explicit fear/morale onto ctx.save_data.
# Returns the list of (fear, morale) pairs used, for comparison in assertions.
static func _inject_party_with_emotions(ctx: FlowContext, fear_morale_pairs: Array) -> void:
	var roster: Array = []
	var active_ids: Array = []
	for i in range(fear_morale_pairs.size()):
		var pair: Dictionary = fear_morale_pairs[i]
		var eid := "echo.p5.%d" % i
		roster.append({
			"id":             eid,
			"name":           "Echo %d" % i,
			"rank":           1,
			"calling_origin": "okofor",
			"emotion": {
				"fear_current":   int(pair.get("fear", 0)),
				"morale_current": int(pair.get("morale", 50)),
			},
		})
		active_ids.append(eid)
	ctx.save_data["sanctum"] = { "roster": roster, "active_party_ids": active_ids }


# ─── Full-runtime helpers (mirrors TraversalModelTests) ─────────────────────
# Used for travel-beat tests: need dispatch() + step_budget/terrain traversal,
# and a party roster so _select_travel_bark has an echo to pick from.

static func _make_directive_cfg() -> Dictionary:
	return {
		"data": {
			"directives": {
				"directive.scout_carefully": {
					"id":                  "directive.scout_carefully",
					"label":               "Scout Carefully",
					"description":         "Moves carefully, scouts widely, withdraws safely, keeps intel.",
					"pros":                ["p1", "p2"],
					"cons":                ["c1", "c2"],
					"intent_weights":      { "survival_bias": 0.4 },
					"unlock_condition":    "always",
					"step_budget":         3,
					"reveal_radius":       3,
					"passive_reveal":      true,
					"passive_reveal_radius": 3,
					"target_preference":   { "intel": 1.4, "objective": 1.2, "combat": 0.4, "reward": 1.2 },
					"precise_intel_bias":  25,
					"exposure_tolerance":  0.3,
					"escape_bonus":        20,
					"intel_retention":     true,
					"intel_retention_bonus": 1.5,
				},
			},
			"stages": {
				"objective_types":             {},
				"calling_action_bonuses":      {},
				"party_return_fear_threshold": 60,
				"cautious_advance_fear_threshold": 50,
				"situation_emotion_effects":   {},
			},
		}
	}


# Build a bare FlowRuntime wired for stage-explore dispatch with a party roster
# (needed for travel bark selection). Does NOT call boot() — no disk I/O.
static func _make_travel_runtime(seed_suffix: String) -> FlowRuntime:
	var logger := _make_logger()
	var runtime := FlowRuntime.new(logger, ConfigService.new(), TestSaveHarness.dir() + "explore_p5_travel_%s.json" % seed_suffix)

	runtime.flow_ctx          = FlowContext.new()
	runtime.flow_ctx.logger   = logger
	runtime.flow_ctx.sim_tick = 0

	var save_data := {
		"schema_version": SaveSchema.SCHEMA_VERSION,
		"first_boot": false,
		"meta": {
			"created_at_unix": 0,
			"last_saved_at_unix": 0,
			"save_generation": 0,
			"app_version": "explore-p5-test",
		},
		"realms": {},
		"sanctum": {
			"roster": [
				{
					"id":              "echo.travel.1",
					"name":            "Kesi",
					"rank":            1,
					"archetype_birth": "canny",
					"calling_origin":  "",
					"emotion": { "fear_current": 0, "morale_current": 50 },
				},
			],
			"active_party_ids": ["echo.travel.1"],
		},
		"stage_context": { "active_directive_id": "directive.scout_carefully" },
		"economy": { "ase": 0 },
		"campaign": { "root_seed": 42 },
		"flow": { "state": FlowStateIds.STAGE_EXPLORE, "context": {} },
	}
	runtime.flow_ctx.save_data = save_data
	runtime.flow_ctx.campaign_seed = CampaignSeed.new(42)

	runtime.directive_service = DirectiveService.new(save_data)
	runtime.directive_service.load_from_config(_make_directive_cfg())

	runtime.econ = EconomyService.new(save_data)
	runtime.flow_machine = FlowStateMachine.new()
	runtime.flow_machine.register_default_states()
	# Dispatch refreshes the current flow state's snapshot. Keep this lightweight
	# fixture on the real state-machine contract instead of relying on a snapshot
	# type alone while leaving the machine itself uninitialized.
	runtime.flow_machine.set_initial(
		FlowStateIds.STAGE_EXPLORE,
		runtime.flow_ctx,
		logger,
		0
	)

	return runtime


# Injects a terrain stage with one distant situation so the first advance moves
# the party (stepped non-empty), which is required for travel-beat selection to fire.
static func _inject_travel_stage(runtime: FlowRuntime, realm_seed: int) -> void:
	var sig := {
		"plateau_count_min": 2, "plateau_count_max": 3,
		"plateau_w_min": 4, "plateau_w_max": 8,
		"plateau_h_min": 4, "plateau_h_max": 8,
		"bridge_width": 2, "bridge_density": 0.3,
		"straggler_count_min": 1, "straggler_count_max": 2,
	}
	var bounds := { "w": 30, "h": 30 }
	var terrain: Dictionary = StageTerrainScript.generate(realm_seed, 0, sig, bounds)
	var walkable: Dictionary = StageTerrainScript.walkable_set(terrain)
	var entry: Dictionary = StageTerrainScript.entry_cell(walkable, bounds)

	# Pick a walkable cell far (Chebyshev-wise) from entry so the party doesn't
	# arrive in a single turn (step_budget=3) — guarantees stepped is non-empty
	# for several consecutive advances.
	var far_pos: Dictionary = { "col": 25, "row": 15 }
	if not walkable.is_empty() and not walkable.has("%d,%d" % [int(far_pos.get("col", 0)), int(far_pos.get("row", 0))]):
		var best_dist := -1
		for k in walkable:
			var parts: PackedStringArray = (k as String).split(",")
			var kc := int(parts[0])
			var kr := int(parts[1])
			var d: int = max(abs(kc - int(entry.get("col", 0))), abs(kr - int(entry.get("row", 0))))
			if d > best_dist:
				best_dist = d
				far_pos = { "col": kc, "row": kr }

	var sit := SituationModelScript.make("sit.far", SituationModelScript.TYPE_COMBAT,
		int(far_pos.get("col", 25)), int(far_pos.get("row", 15)), 5001, true)

	var explore_map := StageExploreModelScript.make(int(bounds.get("w", 30)), int(bounds.get("h", 30)), [sit])
	explore_map["locked"]              = true
	explore_map["party_pos"]           = entry.duplicate()
	explore_map["terrain"]             = terrain
	explore_map["loot_results"]        = []
	explore_map["in_transit"]          = false
	explore_map["target_situation_id"] = ""
	explore_map["explored_cells"]      = {}

	var stage := StageModel.make(0, StageModel.TYPE_COMBAT, realm_seed, [], explore_map)
	var realm := RealmModel.make("realm.01", "Vale of Dust", "courage", "desc", realm_seed, 1, 0, 0)
	realm["stages"] = [stage]

	runtime.flow_ctx.save_data["realms"]["realm.01"] = realm
	runtime.flow_ctx.realm_id = "realm.01"
	runtime.flow_ctx.stage_id = "stage.0"
	runtime.flow_ctx.last_snapshot = {
		"type": FlowStateIds.STAGE_EXPLORE,
		"data": {}, "actions": {}, "meta": { "t": 0 },
	}


static func _read_em(runtime: FlowRuntime, field: String) -> Variant:
	var realms_v: Variant = runtime.flow_ctx.save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	var realm_v: Variant = realms.get("realm.01", {})
	var realm: Dictionary = realm_v if realm_v is Dictionary else {}
	var stages_v: Variant = realm.get("stages", [])
	var stages: Array = stages_v if stages_v is Array else []
	for s_v in stages:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		var em_v: Variant = s.get("explore_map", {})
		var em: Dictionary = em_v if em_v is Dictionary else {}
		return em.get(field, null)
	return null


# ═══════════════════════════════════════════════════════════════════════════
# Test 1 — directive composite: data.directive has non-empty id + label
# ═══════════════════════════════════════════════════════════════════════════
static func _t_directive_composite_id_label_present() -> Dictionary:
	var ctx := _make_ctx_with_real_config()
	_inject_pending_situation(ctx, SituationModelScript.TYPE_LOOT)

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var directive_v: Variant = data.get("directive", null)
	if not (directive_v is Dictionary):
		return { "ok": false, "error": "data.directive missing or not a Dictionary" }
	var directive: Dictionary = directive_v

	if str(directive.get("id", "")).is_empty():
		return { "ok": false, "error": "data.directive.id is empty" }
	if str(directive.get("label", "")).is_empty():
		return { "ok": false, "error": "data.directive.label is empty" }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 2 — directive composite matches the active directive's real config entry
# ═══════════════════════════════════════════════════════════════════════════
static func _t_directive_composite_matches_active() -> Dictionary:
	var ctx := _make_ctx_with_real_config()
	_inject_pending_situation(ctx, SituationModelScript.TYPE_LOOT)

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var directive: Dictionary = data.get("directive", {})

	if str(directive.get("id", "")) != "directive.scout_carefully":
		return { "ok": false, "error": "directive.id expected 'directive.scout_carefully', got '%s'" % directive.get("id", "") }
	if str(directive.get("label", "")) != "Scout Carefully":
		return { "ok": false, "error": "directive.label expected 'Scout Carefully', got '%s'" % directive.get("label", "") }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 3 — party_preview entries all carry a valid canonical emotional_status tier
# ═══════════════════════════════════════════════════════════════════════════
static func _t_party_preview_emotional_status_valid_tier() -> Dictionary:
	var ctx := _make_ctx_with_real_config()
	_inject_pending_situation(ctx, SituationModelScript.TYPE_LOOT)
	_inject_party_with_emotions(ctx, [
		{ "fear": 0,  "morale": 80 },   # radiant
		{ "fear": 90, "morale": 50 },   # hollow
		{ "fear": 40, "morale": 40 },   # grounded
		{ "fear": 60, "morale": 50 },   # pressed-ish
		{ "fear": 45, "morale": 35 },   # uncertain-ish
	])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var preview_v: Variant = data.get("party_preview", [])
	var preview: Array = preview_v if preview_v is Array else []

	if preview.size() != 5:
		return { "ok": false, "error": "Expected 5 party_preview entries, got %d" % preview.size() }

	for entry_v in preview:
		var entry: Dictionary = entry_v if entry_v is Dictionary else {}
		if not entry.has("emotional_status"):
			return { "ok": false, "error": "party_preview entry missing emotional_status key" }
		var tier := str(entry.get("emotional_status", ""))
		if not (tier in VALID_EMOTIONAL_TIERS):
			return { "ok": false, "error": "party_preview emotional_status '%s' is not one of the 10 canonical tiers" % tier }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 4 — party_preview emotional_status matches EmotionService derivation directly
# ═══════════════════════════════════════════════════════════════════════════
static func _t_party_preview_emotional_status_matches_service() -> Dictionary:
	var ctx := _make_ctx_with_real_config()
	_inject_pending_situation(ctx, SituationModelScript.TYPE_LOOT)
	var pairs := [
		{ "fear": 5,  "morale": 75 },
		{ "fear": 88, "morale": 8 },
	]
	_inject_party_with_emotions(ctx, pairs)

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var preview_v: Variant = data.get("party_preview", [])
	var preview: Array = preview_v if preview_v is Array else []

	if preview.size() != pairs.size():
		return { "ok": false, "error": "Expected %d party_preview entries, got %d" % [pairs.size(), preview.size()] }

	for i in range(pairs.size()):
		var expected := EmotionServiceScript.get_emotional_status(int(pairs[i].get("morale", 50)), int(pairs[i].get("fear", 0)))
		var entry: Dictionary = preview[i] if preview[i] is Dictionary else {}
		var actual := str(entry.get("emotional_status", ""))
		if actual != expected:
			return { "ok": false, "error": "party_preview[%d] emotional_status expected '%s', got '%s'" % [i, expected, actual] }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 5 — obstacle pending situation → situation_pending.choices non-empty, id+label present
# ═══════════════════════════════════════════════════════════════════════════
static func _t_situation_pending_choices_obstacle_nonempty() -> Dictionary:
	return _assert_choices_for_type(SituationModelScript.TYPE_OBSTACLE, true)


# ═══════════════════════════════════════════════════════════════════════════
# Test 6 — structure pending situation → situation_pending.choices non-empty, id+label present
# ═══════════════════════════════════════════════════════════════════════════
static func _t_situation_pending_choices_structure_nonempty() -> Dictionary:
	return _assert_choices_for_type(SituationModelScript.TYPE_STRUCTURE, true)


# ═══════════════════════════════════════════════════════════════════════════
# Test 7 — combat pending situation → situation_pending.choices == []
# ═══════════════════════════════════════════════════════════════════════════
static func _t_situation_pending_choices_combat_empty() -> Dictionary:
	return _assert_choices_for_type(SituationModelScript.TYPE_COMBAT, false)


# ═══════════════════════════════════════════════════════════════════════════
# Test 8 — loot pending situation → situation_pending.choices == []
# ═══════════════════════════════════════════════════════════════════════════
static func _t_situation_pending_choices_loot_empty() -> Dictionary:
	return _assert_choices_for_type(SituationModelScript.TYPE_LOOT, false)


static func _assert_choices_for_type(sit_type: String, expect_nonempty: bool) -> Dictionary:
	var ctx := _make_ctx_with_real_config()
	_inject_pending_situation(ctx, sit_type)

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var pending_v: Variant = data.get("situation_pending", {})
	var pending: Dictionary = pending_v if pending_v is Dictionary else {}

	if str(pending.get("type", "")) != sit_type:
		return { "ok": false, "error": "situation_pending.type expected '%s', got '%s'" % [sit_type, pending.get("type", "")] }

	var choices_v: Variant = pending.get("choices", null)
	if not (choices_v is Array):
		return { "ok": false, "error": "situation_pending.choices missing or not an Array for type '%s'" % sit_type }
	var choices: Array = choices_v

	if expect_nonempty:
		if choices.is_empty():
			return { "ok": false, "error": "situation_pending.choices expected non-empty for type '%s'" % sit_type }
		for choice_v in choices:
			var choice: Dictionary = choice_v if choice_v is Dictionary else {}
			if str(choice.get("id", "")).is_empty():
				return { "ok": false, "error": "choice entry missing non-empty 'id' for type '%s'" % sit_type }
			if str(choice.get("label", "")).is_empty():
				return { "ok": false, "error": "choice entry missing non-empty 'label' for type '%s'" % sit_type }
	else:
		if not choices.is_empty():
			return { "ok": false, "error": "situation_pending.choices expected EMPTY for type '%s', got size %d" % [sit_type, choices.size()] }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 9 — travel beat: t=1 (odd) advance where party moved → bark populated, snippet empty
# ═══════════════════════════════════════════════════════════════════════════
static func _t_travel_beat_bark_on_odd_t() -> Dictionary:
	var _save_bak := _capture_save()
	var runtime := _make_travel_runtime("bark")
	_inject_travel_stage(runtime, 42)
	# sim_tick starts at 0 (even → no bark). Burn one turn first so the SECOND advance
	# consumes t=1 (odd → bark fires), while still guaranteeing the party is in transit
	# (moved, objective not yet revealed → no Anansi snippet) on that second turn.
	runtime.dispatch({ "type": "stage.advance_turn" })  # t=0
	var pending_after_first := str(_read_em(runtime, "pending_situation_id"))
	if not pending_after_first.is_empty():
		_restore_save(_save_bak)
		return { "ok": true }  # Degenerate: arrived in one turn — nothing to assert for t=1

	runtime.dispatch({ "type": "stage.advance_turn" })  # t=1 → bark turn

	var bark_v: Variant = _read_em(runtime, "travel_bark")
	var snippet_v: Variant = _read_em(runtime, "travel_snippet")
	var bark: Dictionary = bark_v if bark_v is Dictionary else {}
	var snippet := str(snippet_v) if snippet_v != null else ""

	_restore_save(_save_bak)

	if bark.is_empty():
		return { "ok": false, "error": "travel_bark should be populated on odd t (t=1) after party moved" }
	if str(bark.get("actor_name", "")).is_empty():
		return { "ok": false, "error": "travel_bark.actor_name should be non-empty" }
	if str(bark.get("line", "")).is_empty():
		return { "ok": false, "error": "travel_bark.line should be non-empty" }
	if not snippet.is_empty():
		return { "ok": false, "error": "travel_snippet should be empty when bark fired (odd t), got '%s'" % snippet }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 10 — Anansi snippets are EVENT-DRIVEN: a fresh stage entry (event
# "stage_first_entry") fires a snippet, independent of any advance cadence.
# ═══════════════════════════════════════════════════════════════════════════
static func _t_anansi_snippet_on_first_entry() -> Dictionary:
	var _save_bak := _capture_save()
	var runtime := _make_travel_runtime("first_entry")
	_inject_travel_stage(runtime, 42)

	# Reset to a genuine first entry: flip locked→false so enter() detects the false→true
	# lock flip. The distant objective is far from entry, so the entry-fog seed does NOT
	# reveal it and objectives are not complete → the first-entry event is the one that fires.
	var realms: Dictionary = runtime.flow_ctx.save_data["realms"]
	var em: Dictionary = realms["realm.01"]["stages"][0]["explore_map"]
	em["locked"]           = false
	em["explored_cells"]   = {}
	em["travel_snippet"]   = ""
	em.erase("anansi_complete_fired")

	var explore_state := FlowStageExploreStateScript.new()
	explore_state.enter(runtime.flow_ctx, 0)

	var snippet := str(_read_em(runtime, "travel_snippet"))

	# Snapshot the UI actually reads must also carry it.
	var snap: Dictionary = runtime.flow_ctx.last_snapshot
	var snap_data_v: Variant = snap.get("data", {})
	var snap_data: Dictionary = snap_data_v if snap_data_v is Dictionary else {}
	var snap_snippet := str(snap_data.get("travel_snippet", ""))

	_restore_save(_save_bak)

	if snippet.is_empty():
		return { "ok": false, "error": "Anansi 'stage_first_entry' snippet should fire on first entry; explore_map.travel_snippet was empty" }
	if snap_snippet.is_empty():
		return { "ok": false, "error": "First-entry snapshot data.travel_snippet should carry the Anansi snippet, was empty" }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 11 — determinism: two fresh runtimes, identical seed + action sequence
# → identical bark/snippet at each turn.
# ═══════════════════════════════════════════════════════════════════════════
static func _t_travel_beat_determinism_same_seed() -> Dictionary:
	var _save_bak := _capture_save()

	var runtime_a := _make_travel_runtime("det_a")
	_inject_travel_stage(runtime_a, 42)
	var runtime_b := _make_travel_runtime("det_b")
	_inject_travel_stage(runtime_b, 42)

	var bark_lines_a: Array = []
	var bark_lines_b: Array = []
	var snippet_lines_a: Array = []
	var snippet_lines_b: Array = []

	for _i in range(4):
		var pending_a := str(_read_em(runtime_a, "pending_situation_id"))
		var pending_b := str(_read_em(runtime_b, "pending_situation_id"))
		if not pending_a.is_empty() or not pending_b.is_empty():
			break
		runtime_a.dispatch({ "type": "stage.advance_turn" })
		runtime_b.dispatch({ "type": "stage.advance_turn" })

		var bark_a_v: Variant = _read_em(runtime_a, "travel_bark")
		var bark_b_v: Variant = _read_em(runtime_b, "travel_bark")
		bark_lines_a.append((bark_a_v as Dictionary).get("line", "") if bark_a_v is Dictionary else "")
		bark_lines_b.append((bark_b_v as Dictionary).get("line", "") if bark_b_v is Dictionary else "")

		snippet_lines_a.append(str(_read_em(runtime_a, "travel_snippet")))
		snippet_lines_b.append(str(_read_em(runtime_b, "travel_snippet")))

	_restore_save(_save_bak)

	if bark_lines_a != bark_lines_b:
		return { "ok": false, "error": "Determinism failure: bark lines diverged: A=%s vs B=%s" % [str(bark_lines_a), str(bark_lines_b)] }
	if snippet_lines_a != snippet_lines_b:
		return { "ok": false, "error": "Determinism failure: snippet lines diverged: A=%s vs B=%s" % [str(snippet_lines_a), str(snippet_lines_b)] }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 12 — gating: a non-advance refresh (re-entry / session reset) does not
# carry forward a stale travel_bark/travel_snippet from the prior advance.
# ═══════════════════════════════════════════════════════════════════════════
static func _t_travel_beat_gated_on_non_advance_refresh() -> Dictionary:
	var _save_bak := _capture_save()
	var runtime := _make_travel_runtime("gating")
	_inject_travel_stage(runtime, 42)

	# Echo barks are the only travel beat left on a fixed cadence (odd t, party moved) —
	# Anansi snippets are event-driven now, so they can't be relied on to guarantee a beat
	# here. Burn the first (even, t=0) advance, then take the second (odd, t=1) advance,
	# which deterministically fires a bark as long as the party is still travelling.
	runtime.dispatch({ "type": "stage.advance_turn" })  # t=0
	var pending_after_first := str(_read_em(runtime, "pending_situation_id"))
	if not pending_after_first.is_empty():
		_restore_save(_save_bak)
		return { "ok": true }  # Degenerate: arrived in one turn — nothing to assert.

	runtime.dispatch({ "type": "stage.advance_turn" })  # t=1 → bark turn
	var bark_after_advance_v: Variant = _read_em(runtime, "travel_bark")
	var snippet_after_advance_v: Variant = _read_em(runtime, "travel_snippet")
	var had_beat := (bark_after_advance_v is Dictionary and not (bark_after_advance_v as Dictionary).is_empty()) \
		or (snippet_after_advance_v != null and not str(snippet_after_advance_v).is_empty())
	if not had_beat:
		_restore_save(_save_bak)
		return { "ok": false, "error": "Test setup: expected a travel beat (bark) to fire on the odd-t advance but neither bark nor snippet were set" }

	# Simulate re-entry: FlowStageExploreState.enter() runs _reset_session_state,
	# which rebuilds explore_map without travel_bark/travel_snippet keys.
	var explore_state := FlowStageExploreStateScript.new()
	explore_state.enter(runtime.flow_ctx, 99)

	var bark_after_reenter_v: Variant = _read_em(runtime, "travel_bark")
	var snippet_after_reenter_v: Variant = _read_em(runtime, "travel_snippet")
	var bark_after_reenter: Dictionary = bark_after_reenter_v if bark_after_reenter_v is Dictionary else {}
	var snippet_after_reenter := str(snippet_after_reenter_v) if snippet_after_reenter_v != null else ""

	# Also check the rebuilt snapshot itself (what the UI actually reads).
	var snap: Dictionary = runtime.flow_ctx.last_snapshot
	var snap_data_v: Variant = snap.get("data", {})
	var snap_data: Dictionary = snap_data_v if snap_data_v is Dictionary else {}
	var snap_bark_v: Variant = snap_data.get("travel_bark", {})
	var snap_bark: Dictionary = snap_bark_v if snap_bark_v is Dictionary else {}
	var snap_snippet := str(snap_data.get("travel_snippet", ""))

	_restore_save(_save_bak)

	if not bark_after_reenter.is_empty():
		return { "ok": false, "error": "explore_map.travel_bark should be cleared after session reset, got %s" % str(bark_after_reenter) }
	if not snippet_after_reenter.is_empty():
		return { "ok": false, "error": "explore_map.travel_snippet should be cleared after session reset, got '%s'" % snippet_after_reenter }
	if not snap_bark.is_empty():
		return { "ok": false, "error": "snapshot data.travel_bark should be empty after non-advance refresh, got %s" % str(snap_bark) }
	if not snap_snippet.is_empty():
		return { "ok": false, "error": "snapshot data.travel_snippet should be empty after non-advance refresh, got '%s'" % snap_snippet }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 13 — data file contract: anansi_travel_snippets.json parses; "travel" has ≥20 lines
# ═══════════════════════════════════════════════════════════════════════════
static func _t_travel_snippets_json_contract() -> Dictionary:
	var path := "res://data/stages/anansi_travel_snippets.json"
	if not FileAccess.file_exists(path):
		return { "ok": false, "error": "%s does not exist" % path }
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return { "ok": false, "error": "Could not open %s" % path }
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return { "ok": false, "error": "%s did not parse to a Dictionary" % path }
	var parsed_dict: Dictionary = parsed
	var travel_v: Variant = parsed_dict.get("travel", null)
	if not (travel_v is Array):
		return { "ok": false, "error": "%s missing 'travel' Array key" % path }
	var travel: Array = travel_v
	if travel.size() < 20:
		return { "ok": false, "error": "%s 'travel' array has %d lines, expected >= 20" % [path, travel.size()] }
	for line_v in travel:
		if str(line_v).is_empty():
			return { "ok": false, "error": "%s 'travel' array contains an empty line" % path }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 14 — journey.travel ShoutBank contract resolves through to a non-fallback line
# ═══════════════════════════════════════════════════════════════════════════
static func _t_journey_travel_shout_resolves_non_fallback() -> Dictionary:
	var line := ShoutBank.get_expression_shout("journey.travel", "canny", "forming", "", 0)
	if line.is_empty():
		return { "ok": false, "error": "ShoutBank.get_expression_shout('journey.travel', 'canny', 'forming', '', 0) returned empty string" }
	if line == "I'll do my part.":
		return { "ok": false, "error": "ShoutBank.get_expression_shout('journey.travel', ...) fell back to the generic fallback line — data/shouts/journey.json is missing the 'canny' voice key" }

	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════
# Test 15 — a PLAIN travel advance (no narrative event: no objective revealed,
# not a return-home fail) fires NO Anansi snippet. Proves Anansi is incidental,
# not a constant narrator.
# ═══════════════════════════════════════════════════════════════════════════
static func _t_anansi_no_snippet_on_plain_advance() -> Dictionary:
	var _save_bak := _capture_save()
	var runtime := _make_travel_runtime("plain_adv")
	_inject_travel_stage(runtime, 42)

	# First advance (t=0): the party moves toward the distant objective but is far too
	# far to reveal it this turn — a plain travel advance with no narrative event.
	runtime.dispatch({ "type": "stage.advance_turn" })

	var snippet := str(_read_em(runtime, "travel_snippet"))
	# Guard: confirm the objective is genuinely still hidden (no reveal this turn), so the
	# absence of a snippet reflects "no event" and not an unexpected arrival.
	var pending := str(_read_em(runtime, "pending_situation_id"))

	_restore_save(_save_bak)

	if not pending.is_empty():
		# Degenerate map: party engaged something on turn 1 — not a plain advance; skip.
		return { "ok": true }
	if not snippet.is_empty():
		return { "ok": false, "error": "A plain travel advance (no narrative event) must NOT fire an Anansi snippet, got '%s'" % snippet }

	return { "ok": true }
