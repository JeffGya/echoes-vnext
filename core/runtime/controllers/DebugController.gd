# res://core/runtime/controllers/DebugController.gd
# V2-INFRA-003 Phase 4 Slice 6a: third bounded domain controller extracted out of
# FlowRuntime.gd, following the pattern WeaveController/VowController set (see
# WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - No flow_machine reference — this controller does not (and structurally cannot)
#     transition state or rebuild a snapshot itself. Every handler returns a
#     FlowActionOutcome describing what should happen; FlowRuntime.dispatch() applies it
#     via _apply_action_outcome(), the single place that acts on a controller's intent.
#   - Never calls another controller. Never calls SaveService directly — save intent is
#     reported on the returned FlowActionOutcome (save_reasons) and applied by
#     FlowRuntime.dispatch() via flow_ctx.request_save().
#   - No UI or scene-tree reference.
#
# Owns 9 actions: debug.seed.show, debug.seed.set, debug.seed.reset, debug.echo.gen_test,
# debug.ally.spawn, debug.claimant.force_combat, debug.charge_pressure.set, debug.guidance.set,
# debug.progression.force_rank_up (temporary instrumentation for the progress.rank_up bark
# rewrite — see handle_force_rank_up below).
# All but debug.guidance.set and debug.progression.force_rank_up were moved verbatim
# (behaviour unchanged) from FlowRuntime.gd: _handle_debug_seed_show, _handle_debug_seed_set,
# _handle_debug_echo_gen_test, _echo_fingerprint, _handle_debug_spawn_ally,
# _handle_debug_force_claimant_combat, _handle_debug_force_charge_pressure.
#
# debug.vow.unlock already belongs to VowController (V2-INFRA-003 Phase 4 Slice 2) and is
# left there.
#
# THE REFRESH-SNAPSHOT TRANSLATION: none of these handlers build a new/rebuilt snapshot —
# pre-extraction they all ended with a bare `flow_machine.refresh_snapshot(flow_ctx, logger, t)`
# call, which only re-validates the CURRENT flow_ctx.last_snapshot (FlowStateMachine's
# _rebuild_snapshot() reads ctx.last_snapshot as-is; it does not call enter() or otherwise
# rebuild anything — see core/state/flow/FlowStateMachine.gd and lesson #9 in
# docs/LESSONS.md). To reproduce that exact call, each such handler here returns
# `FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)` — assigning last_snapshot back
# to itself is a no-op, and _apply_action_outcome()'s has_replacement_snapshot branch then
# calls flow_machine.refresh_snapshot() on FlowRuntime's behalf, exactly matching the
# pre-extraction call. The one branch that instead transitions
# (handle_force_claimant_combat's success path) returns FlowActionOutcome.transition_outcome()
# instead, matching the pre-extraction flow_machine.transition() call with no refresh_snapshot
# beforehand.
#
# SHARED HELPER RELOCATED: _handle_debug_seed_set called a private FlowRuntime helper,
# _legacy_root_seed_from_seed_root(), also used by _handle_new_game() (flow.new_game, which
# stays on FlowRuntime — not a debug action). A helper used by two domains has an owner
# (core/AGENTS.md Extraction & Refactor Rules), so it was relocated (verbatim body, no
# behaviour change) to a static function on CampaignSeed — core/CampaignSeed.gd,
# `legacy_root_seed_from_seed_root(seed_root: String) -> int` — the class that already owns
# every other "derive a seed value from a seed string" concern. Both call sites (FlowRuntime's
# _handle_new_game and this controller's _handle_seed_set) now call the same static function;
# no duplicate remains.
#
# CORRECTION vs the story brief's "t = -1" note: no code path in FlowRuntime.dispatch()
# invokes these handlers with t = -1. dispatch() always computes `var t := _next_tick()`
# before the match block runs (FlowRuntime.gd, top of dispatch()), and every debug.* action
# routes through that same match block — there is no special-cased debug tick. Nothing here
# depended on a literal -1 tick value; the constructor/handler signatures below take whatever
# t dispatch() passes them, same as the pre-extraction private methods did.

class_name DebugController
extends RefCounted

const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")
const ContactModelScript          := preload("res://core/realms/ContactModel.gd")
const FlowEchoPartyStateScript     := preload("res://core/state/flow/states/sanctum/FlowEchoPartyState.gd")
const SanctumSnapshotBuilderScript := preload("res://core/state/flow/states/sanctum/SanctumSnapshotBuilder.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## debug.seed.show — logs the current campaign seed fields. Read-only; never saves.
func handle_seed_show(t: int) -> FlowActionOutcome:
	var camp: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]

	var seed_root := str(camp.get("seed_root", ""))
	var seed_source := str(camp.get("seed_source", ""))
	var root_seed := int(camp.get("root_seed", 0))

	logger.info(t, "debug.seed.show", "Seed show", {
		"seed_root": seed_root,
		"seed_source": seed_source,
		"root_seed": root_seed
	})

	# Refresh is optional, but harmless and keeps UI consistent if you display seed-derived hints.
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)


## debug.seed.set — routes to _handle_seed_set with do_reset = false. Kept as its own entry
## point (distinct from handle_seed_reset) matching the two dispatch()-level action types.
func handle_seed_set(action: Dictionary, t: int) -> FlowActionOutcome:
	return _handle_seed_set(action, t, false)


## debug.seed.reset — routes to _handle_seed_set with do_reset = true. Kept as its own entry
## point (distinct from handle_seed_set) matching the two dispatch()-level action types.
func handle_seed_reset(action: Dictionary, t: int) -> FlowActionOutcome:
	return _handle_seed_set(action, t, true)


## Moved verbatim from FlowRuntime._handle_debug_seed_set. Sets the debug seed_root (and, when
## do_reset, wipes sanctum roster/name data for a clean re-test). Denied (empty seed_root) case
## does not save or refresh — matches pre-extraction behaviour exactly.
func _handle_seed_set(action: Dictionary, t: int, do_reset: bool) -> FlowActionOutcome:
	var seed_root := str(action.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "debug.seed.denied", "Denied seed set/reset (empty seed_root)", {})
		return FlowActionOutcome.handled_outcome()

	# Ensure campaign dict exists
	if not flow_ctx.save_data.has("campaign") or typeof(flow_ctx.save_data["campaign"]) != TYPE_DICTIONARY:
		flow_ctx.save_data["campaign"] = {}
	var camp: Dictionary = flow_ctx.save_data["campaign"]

	# Update canonical seed fields
	camp["seed_root"] = seed_root
	camp["seed_source"] = "debug"

	# Keep legacy root_seed in sync for current systems (e.g., sanctum name suggestion)
	camp["root_seed"] = CampaignSeed.legacy_root_seed_from_seed_root(seed_root)

	# Reset sanctum data if requested
	if do_reset:
		if not flow_ctx.save_data.has("sanctum") or typeof(flow_ctx.save_data["sanctum"]) != TYPE_DICTIONARY:
			flow_ctx.save_data["sanctum"] = {}
		var sanctum: Dictionary = flow_ctx.save_data["sanctum"]

		# Reset everything test-relevant
		sanctum["name"] = ""
		sanctum["name_roll_index"] = 0
		sanctum["roster"] = []
		sanctum["active_party_ids"] = []
		sanctum["summon_count"] = 0
		sanctum["starter_granted"] = false

		logger.info(t, "debug.seed.reset", "Seed reset applied", {
			"seed_root": seed_root,
			"root_seed": int(camp.get("root_seed", 0))
		})
	else:
		logger.info(t, "debug.seed.set", "Seed set applied", {
			"seed_root": seed_root,
			"root_seed": int(camp.get("root_seed", 0))
		})

	# Save once via the Flow-owned choke point; no flow transition occurs, so refresh snapshot
	# immediately (both handled by FlowRuntime._apply_action_outcome() from this outcome).
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot).with_save_reason(
		"debug.seed.reset" if do_reset else "debug.seed.set"
	)


## debug.echo.gen_test — moved verbatim from FlowRuntime._handle_debug_echo_gen_test. Generates
## the same EchoFactory path twice plus one different path, and logs determinism fingerprints.
## NEVER reorder the EchoFactory.generate() calls below — RNG draw order is immutable and
## append-only (core/AGENTS.md, EchoFactory RNG draw order v1).
func handle_echo_gen_test(t: int) -> FlowActionOutcome:
	# Pull seed_root from save
	var camp: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]

	var seed_root := str(camp.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "debug.echo.gen_test.denied", "Denied echo gen test (missing seed_root)", {})
		return FlowActionOutcome.handled_outcome()

	# Pull summoning config from balance.json
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}

	# Generate same path twice
	var path0 := "campaign.summon.0"
	var e1: Dictionary = EchoFactory.generate(seed_root, path0, 0, "summon", summ_cfg)
	var e2: Dictionary = EchoFactory.generate(seed_root, path0, 0, "summon", summ_cfg)

	# Generate different path
	var path1 := "campaign.summon.1"
	var e3: Dictionary = EchoFactory.generate(seed_root, path1, 1, "summon", summ_cfg)

	var fp1 := _echo_fingerprint(e1)
	var fp2 := _echo_fingerprint(e2)
	var fp3 := _echo_fingerprint(e3)

	logger.info(t, "debug.echo.gen_test", "EchoFactory determinism test", {
		"seed_root": seed_root,
		"path_a": path0,
		"path_b": path1,
		"fingerprint_1": fp1,
		"fingerprint_2": fp2,
		"fingerprint_3": fp3,
		"same_path_equal": fp1 == fp2,
		"diff_path_differs": fp1 != fp3,
	})

	# No state transition: refresh snapshot so UI/debug panels remain in sync
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)


## Moved verbatim from FlowRuntime._echo_fingerprint. Pure — no dependencies beyond its
## argument. Stable, human-readable digest for determinism checks. Do NOT include id (caller
## assigns it).
func _echo_fingerprint(e: Dictionary) -> String:
	var name := str(e.get("name", ""))
	var gender := str(e.get("gender", ""))
	var rarity := str(e.get("rarity", ""))
	var calling := str(e.get("calling_origin", ""))
	var arch := str(e.get("archetype_birth", ""))
	var traits_v: Variant = e.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	var stats_v: Variant = e.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}

	return "%s|%s|%s|%s|%s|c%dw%df%d|hp%datk%ddef%dagi%dint%dcha%d" % [
		name,
		gender,
		rarity,
		calling,
		arch,
		int(traits.get("courage", 0)),
		int(traits.get("wisdom", 0)),
		int(traits.get("faith", 0)),
		int(stats.get("max_hp", 0)),
		int(stats.get("atk", 0)),
		int(stats.get("def", 0)),
		int(stats.get("agi", 0)),
		int(stats.get("int", 0)),
		int(stats.get("cha", 0)),
	]


## debug.ally.spawn — moved verbatim from FlowRuntime._handle_debug_spawn_ally. V2-STAGE-004
## Phase 4 (S12) dev command: stages a synthetic ContactModel-shaped temporary_ally contact on
## explore_map.ally_contact so the next encounter fought in this stage auto-joins it (mirrors
## the real temporary_ally/good outcome in _apply_contact_outcome, minus the
## situation/Continuity side effects). Dev-only: reached only via the F1 debug panel. AppRoot
## guards the "must be exploring a stage" precondition before dispatching, so this handler
## additionally no-ops safely (push_warning + refresh, never crash) if called from an
## unexpected context.
func handle_spawn_ally(t: int) -> FlowActionOutcome:
	var stage: Dictionary = FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		push_warning("debug.ally.spawn: no active stage — command ignored")
		return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	var contact: Dictionary = ContactModelScript.make(
		"dev_ally", "temporary_ally", "courage", "wisdom",
		20, 75, "bold", "Dev Ally", 3
	)
	contact["state"]   = "concluded"
	contact["outcome"] = "good"
	contact["allied"]  = true
	# S14a engagement-signal fields (RecruitmentService._conversation_component) — set to
	# plausible non-zero values so the recruit-chance formula has real signal to work with.
	contact["conv_score_sum"] = 4.0
	contact["winning_turns"]  = 2

	explore_map["ally_contact"]               = contact
	explore_map["ally_contact_id"]            = "dev_ally"
	explore_map["ally_consumed_in_encounter"] = false
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)

	logger.info(t, "debug.ally.spawn", "Dev ally staged for next encounter", {
		"stage_id": flow_ctx.stage_id,
	})
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot).with_save_reason("debug.ally.spawn")


## debug.claimant.force_combat — moved verbatim from FlowRuntime._handle_debug_force_claimant_combat.
## V2-STAGE-004 Phase 4 (S13) dev command: replicates the claimant-hostile branch of
## _apply_contact_outcome (the "claimant" / "failed" case) — sets the durable
## combat_intro_reason marker and force-transitions straight to flow.encounter with the same
## transition reason, so FlowEncounterState's combat_intro_line projection matches the real
## path exactly.
func handle_force_claimant_combat(t: int) -> FlowActionOutcome:
	var stage: Dictionary = FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		push_warning("debug.claimant.force_combat: no active stage — command ignored")
		return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	explore_map["combat_intro_reason"] = "claimant_hostile"
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)

	flow_ctx.active_encounter_objective_index = -1

	logger.info(t, "debug.claimant.force_combat", "Dev-forced hostile Claimant combat", {
		"stage_id": flow_ctx.stage_id,
	})

	return FlowActionOutcome.transition_outcome(
		FlowStateIds.ENCOUNTER, "stage.claimant.combat_forced"
	).with_save_reason("debug.claimant.force_combat")


## debug.charge_pressure.set — moved verbatim from FlowRuntime._handle_debug_force_charge_pressure.
## V2-STAGE-004 Phase 4 (S13) dev command: sets/clears explore_map.hostile_charge_sit_id,
## consumed exactly once by the next PROTECT/ENDURE objective combat
## (EncounterSetupService.setup, charge-pressure block) for the charge-pressure duration/wave bump.
func handle_force_charge_pressure(action: Dictionary, t: int) -> FlowActionOutcome:
	var on: bool = bool(action.get("on", true))
	var stage: Dictionary = FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		push_warning("debug.charge_pressure.set: no active stage — command ignored")
		return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	explore_map["hostile_charge_sit_id"] = "dev_charge" if on else ""
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)

	logger.info(t, "debug.charge_pressure.set", "Dev charge pressure toggled", {
		"stage_id": flow_ctx.stage_id,
		"on": on,
	})
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot).with_save_reason("debug.charge_pressure.set")


## debug.guidance.set — sets or clears the headless Keeper suggestion (flow_ctx.dev_guidance).
## An empty "guidance" dictionary clears it. The field is session-transient, so no save is
## requested. See FlowContext.dev_guidance and GuidanceContribution.resolve() for the shape.
func handle_guidance_set(action: Dictionary, t: int) -> FlowActionOutcome:
	var guidance_v: Variant = action.get("guidance", {})
	var guidance: Dictionary = guidance_v if guidance_v is Dictionary else {}

	flow_ctx.dev_guidance = guidance.duplicate(true)

	logger.info(t, "debug.guidance.set", "Dev Keeper guidance set", {
		"guidance_id": str(guidance.get("guidance_id", "")),
		"subject_id":  str(guidance.get("subject_id", "")),
		"cleared":     guidance.is_empty(),
	})
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)


## debug.progression.force_rank_up — verification aid for the progress.rank_up bark rewrite:
## reaching a real Standing gain in normal play takes a long session, so this forces one.
## action.echo_id is optional — when empty, the FIRST roster echo not already at the configured
## rank cap is used. Makes the target eligible (sets level = prog_cfg.max_level_per_rank, the
## field ProgressionService.is_rank_up_eligible() checks) then runs the SAME execution path
## sanctum.rank_up uses: ProgressionService.execute_rank_up() followed by
## NarrativeVoiceService.select_sanctum_bark_for_echo_data_and_write(echo_ref, "progress.rank_up",
## t, roster) — see ProgressionController.handle_rank_up(), the real handler this mirrors. Does
## NOT call ProgressionController (this controller may never call another controller) or
## reimplement rank-up; it calls the same two domain services directly, so the bark write is the
## real one. handle_rank_up()'s only gate this command deliberately skips is its
## `flow_ctx.last_snapshot.type == FlowStateIds.ECHO_PARTY` check — a UI-context guard, not a
## rank-up rule, so a debug console command run from anywhere would otherwise be denied for the
## wrong reason. The rank-cap guard IS a rank-up rule, so it is kept.
##
## POST-PR-#64-REVIEW FIX: the success path used to return
## FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot) — the PRE-mutation snapshot,
## unchanged, re-validated by refresh_snapshot() but never rebuilt. The UI kept showing the old
## Standing/eligibility/bark until the player left the screen and came back, defeating the
## command's purpose (verifying the rank-up UI reaction). Fixed by rebuilding the snapshot for
## whichever roster-showing screen the player is actually on:
##   - ECHO_PARTY: rebuild via FlowEchoPartyState.build_snapshot() and attach data.rank_up_event,
##     the exact shape ProgressionController.handle_rank_up() produces, so RankUpOverlay (the
##     only consumer of rank_up_event — see ui/screens/sanctum/EchoPartyScreen.gd) fires for real.
##     Uses snapshot_outcome_no_refresh(), matching handle_rank_up() exactly (see that function's
##     doc comment for why: the pre-extraction path never called refresh_snapshot() on success).
##   - SANCTUM: rebuild via SanctumSnapshotBuilder.build() so the roster-derived fields the
##     Sanctum party-manage view shows (Standing, Step, rank_benefits, bark) are current too.
##     No rank_up_event attach — SanctumScreen has no RankUpOverlay consumer for it, so attaching
##     it there would be a shape no one reads.
##   - Any other screen: return handled_outcome() (no snapshot touched at all). Rebuilding an
##     ECHO_PARTY or SANCTUM snapshot while the player is on, say, a combat or venture screen
##     would hand the renderer a snapshot type it isn't currently driving — worse than doing
##     nothing. The save still happens (with_save_reason below applies regardless of branch), so
##     the mutation is not lost; the player just sees the update on next visit to a roster screen,
##     same as before this fix for those screens.
func handle_force_rank_up(action: Dictionary, t: int) -> FlowActionOutcome:
	var echo_id: String = str(action.get("echo_id", "")).strip_edges()

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	# Same balance.json keys ProgressionController.handle_rank_up() reads.
	var prog_cfg: Dictionary = {}
	var birth_stats: Dictionary = {}
	var calling_cfg: Dictionary = {}
	var max_rank: int = 9
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		var bd_v: Variant = bal.get("data", {})
		var bd: Dictionary = bd_v if bd_v is Dictionary else {}
		var prog_cfg_v: Variant = bd.get("progression", {})
		prog_cfg = prog_cfg_v if prog_cfg_v is Dictionary else {}
		var summ_v: Variant = bd.get("summoning", {})
		var summ: Dictionary = summ_v if summ_v is Dictionary else {}
		var birth_stats_v: Variant = summ.get("birth_stats", {})
		birth_stats = birth_stats_v if birth_stats_v is Dictionary else {}
		var calling_cfg_v: Variant = bd.get("calling", {})
		calling_cfg = calling_cfg_v if calling_cfg_v is Dictionary else {}
		var mat_exp_v: Variant = bd.get("maturity_expression", {})
		var mat_exp: Dictionary = mat_exp_v if mat_exp_v is Dictionary else {}
		var rank_scale_v: Variant = mat_exp.get("rank_strength_scale", {})
		var rank_scale: Dictionary = rank_scale_v if rank_scale_v is Dictionary else {}
		max_rank = int(rank_scale.get("max_rank", 9))
	var max_level_per_rank: int = int(prog_cfg.get("max_level_per_rank", 5))

	# Resolve target: named echo_id, or the first roster echo below the rank cap.
	var echo_ref: Dictionary = {}
	var echo_idx: int = -1
	if not echo_id.is_empty():
		for i in range(roster.size()):
			if roster[i] is Dictionary and str((roster[i] as Dictionary).get("id", "")) == echo_id:
				echo_ref = roster[i]
				echo_idx = i
				break
		if echo_idx == -1:
			logger.info(t, "debug.progression.force_rank_up.denied", "Force rank-up denied (echo not in roster)", {
				"echo_id": echo_id,
			})
			return FlowActionOutcome.handled_outcome()
	else:
		for i in range(roster.size()):
			if roster[i] is Dictionary and int((roster[i] as Dictionary).get("rank", 1)) < max_rank:
				echo_ref = roster[i]
				echo_idx = i
				break
		if echo_idx == -1:
			logger.info(t, "debug.progression.force_rank_up.denied", "Force rank-up denied (no roster echo below rank cap)", {
				"max_rank": max_rank,
			})
			return FlowActionOutcome.handled_outcome()

	var old_rank: int = int(echo_ref.get("rank", 1))
	if old_rank >= max_rank:
		logger.info(t, "debug.progression.force_rank_up.denied", "Force rank-up denied (echo already at rank cap)", {
			"echo_id": str(echo_ref.get("id", "")),
			"rank": old_rank,
			"max_rank": max_rank,
		})
		return FlowActionOutcome.handled_outcome()

	# Make eligible: force level to the configured per-rank cap — exactly what
	# ProgressionService.is_rank_up_eligible() checks. echo_ref is the same Dictionary
	# reference stored in roster[echo_idx], so this mutates the roster entry in place.
	echo_ref["level"] = max_level_per_rank

	# Execute the SAME rank-up path sanctum.rank_up uses — no reimplementation here.
	var event: Dictionary = ProgressionService.execute_rank_up(
		echo_ref,
		flow_ctx.campaign_seed,
		prog_cfg,
		birth_stats,
		calling_cfg,
		logger,
		t
	)

	# Write the progress.rank_up bark for real — same call sanctum.rank_up makes.
	NarrativeVoiceService.new(flow_ctx, config_service, logger).select_sanctum_bark_for_echo_data_and_write(
		echo_ref, "progress.rank_up", t, roster
	)
	sanctum["roster"] = roster
	flow_ctx.save_data["sanctum"] = sanctum

	var bark_v: Variant = echo_ref.get("_sanctum_bark", {})
	var bark: Dictionary = bark_v if bark_v is Dictionary else {}

	logger.info(t, "debug.progression.force_rank_up", "Forced rank-up for verification", {
		"echo_id": str(echo_ref.get("id", "")),
		"old_rank": old_rank,
		"new_rank": int(echo_ref.get("rank", old_rank)),
		"bark_line": str(bark.get("line", "")),
	})

	# Rebuild the snapshot for whatever roster-showing screen is currently live, so the UI
	# reflects the mutation instead of re-rendering the stale pre-rank-up snapshot. See the doc
	# comment above for why each branch does what it does.
	var current_snap_type: String = str(flow_ctx.last_snapshot.get("type", ""))
	if current_snap_type == FlowStateIds.ECHO_PARTY:
		var new_snapshot: Dictionary = FlowEchoPartyStateScript.build_snapshot(flow_ctx, t)
		if new_snapshot.has("data") and new_snapshot["data"] is Dictionary:
			new_snapshot["data"]["rank_up_event"] = event
		return FlowActionOutcome.snapshot_outcome_no_refresh(new_snapshot).with_save_reason("debug.progression.force_rank_up")
	elif current_snap_type == FlowStateIds.SANCTUM:
		var new_sanctum_snapshot: Dictionary = SanctumSnapshotBuilderScript.build(flow_ctx, t)
		return FlowActionOutcome.snapshot_outcome_no_refresh(new_sanctum_snapshot).with_save_reason("debug.progression.force_rank_up")

	return FlowActionOutcome.handled_outcome().with_save_reason("debug.progression.force_rank_up")
