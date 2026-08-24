# res://core/runtime/controllers/ProgressionController.gd
# V2-INFRA-003 Phase 4 Slice 6b: fourth bounded domain controller extracted out of
# FlowRuntime.gd, following the pattern WeaveController/VowController/DebugController set
# (see WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - No flow_machine reference — this controller does not (and structurally cannot)
#     transition state or rebuild a snapshot itself. Every dispatched-action handler returns
#     a FlowActionOutcome describing what should happen; FlowRuntime.dispatch() applies it
#     via _apply_action_outcome(), the single place that acts on a controller's intent.
#   - Never calls another controller. Never calls SaveService directly — save intent is
#     reported via flow_ctx.request_save() (the RULES-mandated choke point) or, for
#     dispatched-action handlers, via the returned outcome's save_reasons.
#   - No UI or scene-tree reference.
#
# Owns 5 dispatched actions: sanctum.rank_up, sanctum.calling.confirm, skill.assign,
# skill.unassign, sanctum.unlock_skill. Moved verbatim (behaviour unchanged) from FlowRuntime.gd:
# _handle_sanctum_rank_up, _handle_sanctum_calling_confirm, _handle_skill_assign,
# _handle_skill_unassign, _persist_equipped_skills, _get_realm_xp_multiplier,
# _handle_sanctum_unlock_skill (added Phase 4 Slice 10 — see "sanctum.unlock_skill" below).
#
# PHASE 6 SLICE 6F: the two members of that list that were NOT dispatched-action handlers —
# persist_equipped_skills and get_realm_xp_multiplier — have since been demoted off this
# controller, because each had a caller that could not legally reach a controller. They are now
# core/progression/SkillLoadoutService.gd::persist_equipped_skills and the static
# ProgressionService.get_realm_xp_multiplier. This controller now owns handlers only.
#
# THE TWO SUPPRESSED-REFRESH ACTIONS: sanctum.rank_up and sanctum.calling.confirm are the
# only two dispatched actions in the whole codebase whose handler assigns a replacement
# snapshot but never calls flow_machine.refresh_snapshot() afterward (pre-extraction: both
# wrote flow_ctx.last_snapshot directly and returned void, with no refresh_snapshot() call
# anywhere on their path — confirmed by reading the pre-extraction bodies before moving them).
# FlowActionOutcome.snapshot_outcome() cannot express "assign but do not refresh" — every
# existing controller that uses it wants the refresh. So this slice adds
# FlowActionOutcome.snapshot_outcome_no_refresh() / .suppress_refresh, and
# FlowRuntime._apply_action_outcome() now checks outcome.suppress_refresh before calling
# refresh_snapshot(). Both handlers below return snapshot_outcome_no_refresh() on their
# success path, and handled_outcome() (no snapshot, no refresh, no save — a true no-op,
# matching the pre-extraction early-return branches exactly) on every denial path.
#
# sanctum.unlock_skill (moved Phase 4 Slice 10): was left on FlowRuntime by Slice 6b because its
# pre-extraction body called `_handle_economy_settle_time({...}, t)` inline, mid-handler, before
# its Ase-affordability check (so the balance is settled before the check reads it). At the time,
# _handle_economy_settle_time was a ~140-line cross-domain function still private on FlowRuntime
# that unconditionally called `flow_machine.refresh_snapshot()` itself — no controller may hold
# flow_machine or call FlowRuntime, so this call could not be reproduced by a controller without
# either duplicating that logic (forbidden) or extracting the settle handler to a service first.
#
# Slice 7 did exactly that: _handle_economy_settle_time is now
# core/economy/EconomySettlementService.gd (settle()) — a plain RefCounted service with no
# flow_machine reference, callable from anywhere. Slice 10 extracts handle_unlock_skill() using
# the same shape SanctumController.handle_summon() already established: this controller's own
# private _economy_settlement_service() builds a fresh EconomySettlementService per call and
# calls .settle({...}, t) before the affordability check. The reenter()+refresh_snapshot()
# pairing the pre-extraction handler used (fixing the recorded Sanctum-projection defect) is now
# expressed as FlowActionOutcome.reenter_outcome() — the same convenience constructor
# SanctumController's five reenter-pairing call sites already use.
#
# core/progression/ProgressionService.gd and core/progression/CallingService.gd already hold
# the rank-up / calling DOMAIN rules — this controller is the action-dispatch seam on top of
# them, same relationship WeaveController has with WeavingRiteService.

class_name ProgressionController
extends RefCounted

const FlowEchoPartyStateScript := preload("res://core/state/flow/states/sanctum/FlowEchoPartyState.gd")
const FlowStageMapStateScript  := preload("res://core/state/flow/states/venture/FlowStageMapState.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var econ: EconomyService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _econ: EconomyService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	econ = _econ
	logger = _logger


## sanctum.rank_up — PROG-004: Executes Keeper-confirmed rank-up for a single echo. Moved
## verbatim from FlowRuntime._handle_sanctum_rank_up. Valid from ECHO_PARTY snapshots.
## Every denial path returns handled_outcome() (no snapshot assignment, no refresh, no save) —
## matching the pre-extraction early `return` exactly. The success path never called
## flow_machine.refresh_snapshot() pre-extraction, so it returns snapshot_outcome_no_refresh().
func handle_rank_up(action: Dictionary, t: int) -> FlowActionOutcome:
	var snap_type: String = str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY:
		logger.debug(t, "sanctum.rank_up.ignored", "Rank-up ignored (not in echo party)", {
			"snapshot_type": snap_type
		})
		return FlowActionOutcome.handled_outcome()

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id: String = str(payload.get("echo_id", "")).strip_edges()
	if echo_id.is_empty():
		logger.debug(t, "sanctum.rank_up.denied", "Rank-up denied (missing echo_id)", {})
		return FlowActionOutcome.handled_outcome()

	# Find echo in roster.
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var echo_ref: Dictionary = {}
	var echo_idx: int = -1
	for i in range(roster.size()):
		if roster[i] is Dictionary and str(roster[i].get("id", "")) == echo_id:
			echo_ref = roster[i]
			echo_idx = i
			break

	if echo_idx == -1:
		logger.debug(t, "sanctum.rank_up.denied", "Rank-up denied (echo not in roster)", {
			"echo_id": echo_id
		})
		return FlowActionOutcome.handled_outcome()

	# Read prog_cfg and calling_cfg from balance.json.
	var prog_cfg_v: Variant = {}
	var birth_stats_v: Variant = {}
	var calling_cfg_v: Variant = {}
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		var bd: Dictionary  = bal.get("data", {})
		prog_cfg_v    = bd.get("progression", {})
		birth_stats_v = bd.get("summoning", {}).get("birth_stats", {})
		calling_cfg_v = bd.get("calling", {})
	var prog_cfg: Dictionary    = prog_cfg_v if prog_cfg_v is Dictionary else {}
	var birth_stats: Dictionary = birth_stats_v if birth_stats_v is Dictionary else {}
	var calling_cfg: Dictionary = calling_cfg_v if calling_cfg_v is Dictionary else {}

	# Guard: must be eligible.
	if not ProgressionService.is_rank_up_eligible(echo_ref, prog_cfg):
		logger.debug(t, "sanctum.rank_up.denied", "Rank-up denied (not eligible)", {
			"echo_id": echo_id,
			"level": int(echo_ref.get("level", 1)),
			"rank":  int(echo_ref.get("rank", 1)),
		})
		return FlowActionOutcome.handled_outcome()

	# Execute rank-up — mutates echo_ref in place (roster[echo_idx] is the same ref).
	var event: Dictionary = ProgressionService.execute_rank_up(
		echo_ref,
		flow_ctx.campaign_seed,
		prog_cfg,
		birth_stats,
		calling_cfg,
		logger,
		t
	)

	# Persist.
	flow_ctx.request_save("progression.rank_up")

	# V2-VOICE-001: write progress.rank_up bark to the echo's save entry.
	var _ru_roster_v: Variant = sanctum.get("roster", [])
	var _ru_roster: Array = _ru_roster_v if _ru_roster_v is Array else []
	_voice_service().select_sanctum_bark_for_echo_data_and_write(echo_ref, "progress.rank_up", t, _ru_roster)
	sanctum["roster"] = _ru_roster
	flow_ctx.save_data["sanctum"] = sanctum

	# Rebuild EchoParty snapshot with updated roster data.
	var new_snapshot: Dictionary = FlowEchoPartyStateScript.build_snapshot(flow_ctx, t)

	# Attach the rank-up event to the snapshot data so the UI can drive the reveal overlay.
	if new_snapshot.has("data") and new_snapshot["data"] is Dictionary:
		new_snapshot["data"]["rank_up_event"] = event

	return FlowActionOutcome.snapshot_outcome_no_refresh(new_snapshot)


## sanctum.calling.confirm — PROG-007: Confirms a Keeper-chosen calling for an echo. Moved
## verbatim from FlowRuntime._handle_sanctum_calling_confirm. Valid from ECHO_PARTY snapshots.
## Same suppress-refresh treatment as handle_rank_up above, for the same reason.
func handle_calling_confirm(action: Dictionary, t: int) -> FlowActionOutcome:
	var snap_type: String = str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY:
		logger.debug(t, "sanctum.calling.ignored", "Calling confirm ignored (not in echo party)", {
			"snapshot_type": snap_type
		})
		return FlowActionOutcome.handled_outcome()

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id: String = str(payload.get("echo_id", "")).strip_edges()
	var chosen_calling_id: String = str(payload.get("chosen_calling_id", "")).strip_edges()

	if echo_id.is_empty() or chosen_calling_id.is_empty():
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (missing echo_id or chosen_calling_id)", {})
		return FlowActionOutcome.handled_outcome()

	# Find echo in roster.
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var echo_ref: Dictionary = {}
	for i in range(roster.size()):
		if roster[i] is Dictionary and str(roster[i].get("id", "")) == echo_id:
			echo_ref = roster[i]
			break

	if echo_ref.is_empty():
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (echo not in roster)", {
			"echo_id": echo_id
		})
		return FlowActionOutcome.handled_outcome()

	# Guard: must have a calling pending (calling_eligible=true and no calling set yet).
	if not CallingService.is_calling_pending(echo_ref):
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (no calling pending)", {
			"echo_id":         echo_id,
			"calling_eligible": bool(echo_ref.get("calling_eligible", false)),
			"calling":         str(echo_ref.get("calling", "")),
		})
		return FlowActionOutcome.handled_outcome()

	# Read calling_cfg from balance.json.
	var calling_cfg_v: Variant = {}
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		calling_cfg_v = bal.get("data", {}).get("calling", {})
	var calling_cfg: Dictionary = calling_cfg_v if calling_cfg_v is Dictionary else {}

	# Confirm the calling — mutates echo_ref in place.
	var confirmed: String = CallingService.confirm_calling(echo_ref, chosen_calling_id, calling_cfg, logger, t)
	if confirmed.is_empty():
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (invalid chosen_calling_id)", {
			"echo_id":           echo_id,
			"chosen_calling_id": chosen_calling_id,
		})
		return FlowActionOutcome.handled_outcome()

	# Persist.
	flow_ctx.request_save("progression.calling.confirm")

	# V2-VOICE-001: write calling_settled bark to the echo's save entry.
	var _cs_roster_v: Variant = (flow_ctx.save_data.get("sanctum", {}) as Dictionary).get("roster", [])
	var _cs_roster: Array = _cs_roster_v if _cs_roster_v is Array else []
	_voice_service().select_sanctum_bark_for_echo_data_and_write(echo_ref, "sanctum.calling_settled", t, _cs_roster)
	var _cs_sanctum_m: Variant = flow_ctx.save_data.get("sanctum", {})
	if _cs_sanctum_m is Dictionary:
		(_cs_sanctum_m as Dictionary)["roster"] = _cs_roster

	# Rebuild EchoParty snapshot.
	var new_snapshot: Dictionary = FlowEchoPartyStateScript.build_snapshot(flow_ctx, t)

	# Attach calling_event so UI can react (clear pending indicator, etc.).
	if new_snapshot.has("data") and new_snapshot["data"] is Dictionary:
		new_snapshot["data"]["calling_event"] = {
			"echo_id":    echo_id,
			"calling":    confirmed,
		}

	return FlowActionOutcome.snapshot_outcome_no_refresh(new_snapshot)


## skill.assign — PROG-009: Assigns a skill to an echo slot while on STAGE_MAP party prep.
## Moved verbatim from FlowRuntime._handle_skill_assign. Updates
## flow_ctx.pending_equipped_skills and rebuilds the STAGE_MAP snapshot. Unlike rank_up /
## calling.confirm above, the pre-extraction body DID end with flow_machine.refresh_snapshot()
## on every path that rebuilds the snapshot, so this uses ordinary snapshot_outcome() (which
## _apply_action_outcome() always refreshes).
func handle_skill_assign(action: Dictionary, t: int) -> FlowActionOutcome:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.STAGE_MAP:
		logger.debug(t, "skill.assign.ignored", "skill.assign outside STAGE_MAP", {
			"snapshot_type": str(flow_ctx.last_snapshot.get("type", ""))
		})
		return FlowActionOutcome.handled_outcome()

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id  := str(payload.get("echo_id",  "")).strip_edges()
	var slot     := str(payload.get("slot",     "0")).strip_edges()
	var skill_id := str(payload.get("skill_id", "")).strip_edges()

	if echo_id.is_empty() or skill_id.is_empty():
		logger.debug(t, "skill.assign.denied", "skill.assign missing echo_id or skill_id", { "payload": payload })
		return FlowActionOutcome.handled_outcome()

	if not flow_ctx.pending_equipped_skills.has(echo_id):
		flow_ctx.pending_equipped_skills[echo_id] = {}
	flow_ctx.pending_equipped_skills[echo_id][slot] = skill_id

	logger.debug(t, "skill.assign", "Skill assigned", {
		"echo_id": echo_id, "slot": slot, "skill_id": skill_id
	})
	return FlowActionOutcome.snapshot_outcome(FlowStageMapStateScript.build_snapshot(flow_ctx, t))


## skill.unassign — PROG-009: Unassigns a skill from an echo slot while on STAGE_MAP party
## prep. Moved verbatim from FlowRuntime._handle_skill_unassign. Same refresh treatment as
## handle_skill_assign above.
func handle_skill_unassign(action: Dictionary, t: int) -> FlowActionOutcome:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.STAGE_MAP:
		logger.debug(t, "skill.unassign.ignored", "skill.unassign outside STAGE_MAP", {
			"snapshot_type": str(flow_ctx.last_snapshot.get("type", ""))
		})
		return FlowActionOutcome.handled_outcome()

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id := str(payload.get("echo_id", "")).strip_edges()
	var slot    := str(payload.get("slot",    "0")).strip_edges()

	if echo_id.is_empty():
		logger.debug(t, "skill.unassign.denied", "skill.unassign missing echo_id", {})
		return FlowActionOutcome.handled_outcome()

	if flow_ctx.pending_equipped_skills.has(echo_id):
		flow_ctx.pending_equipped_skills[echo_id].erase(slot)

	logger.debug(t, "skill.unassign", "Skill unassigned", {
		"echo_id": echo_id, "slot": slot
	})
	return FlowActionOutcome.snapshot_outcome(FlowStageMapStateScript.build_snapshot(flow_ctx, t))


## V2-INFRA-003 Phase 6 Slice 6F: persist_equipped_skills() was DEMOTED off this controller to
## core/progression/SkillLoadoutService.gd. Slice 6b's header (above) placed it here as "a
## preparatory step from FlowRuntime's flow.select_stage case (which stays on FlowRuntime)" —
## true when written, because there was no VentureController then and FlowRuntime may call any
## controller. Slice D created VentureController, found flow.select_stage blocked by this exact
## call, named this exact fix and deferred it on scope alone. This slice performs it, which lets
## flow.select_stage finally join VentureController. No forwarder is left here on purpose. See
## SkillLoadoutService.gd's header for the full reading of that earlier decision.


## V2-INFRA-003 Phase 6 Slice 6F: get_realm_xp_multiplier() was DEMOTED off this controller to
## ProgressionService.get_realm_xp_multiplier(realm_id, save_data, prog_cfg) — a static on the
## progression domain service. Its only caller was FlowRuntime._resolve_next_actor(), which
## reached it controller-to-controller; that is the blocker keeping _resolve_next_actor out of a
## future CombatController. No forwarder is left here on purpose: a one-line delegate would keep
## the call sites compiling while proving the demotion never happened. See that function's
## header in core/progression/ProgressionService.gd for the full placement reasoning.


## Builds a fresh NarrativeVoiceService scoped to the current flow_ctx/config_service/logger.
## Constructed per-call, same rationale as FlowRuntime._weave_controller(): cheap RefCounted,
## always correct even if a caller replaces flow_ctx after construction.
func _voice_service() -> NarrativeVoiceService:
	return NarrativeVoiceService.new(flow_ctx, config_service, logger)


## V2-PROG-009: Unlock a skill from the constellation skill tree. Moved verbatim (behaviour
## unchanged) from FlowRuntime._handle_sanctum_unlock_skill in V2-INFRA-003 Phase 4 Slice 10.
## Validates: SANCTUM state, skill exists, calling confirmed, skill family accessible for the
## echo's calling, not already unlocked, can afford. Settles accrued Ase BEFORE the affordability
## check — that order is load-bearing: settling after the check would deny an unlock the player
## can actually afford. Spends the configured Ase cost, appends skill_id to
## echo["unlocked_skills"], requests a save, then pairs reenter()+refresh_snapshot() (via
## FlowActionOutcome.reenter_outcome()) to rebuild the Sanctum projection — the same pairing
## SanctumController's five reenter call sites use, fixing the same recorded defect where the
## Sanctum projection came back incomplete after a mid-state mutation.
func handle_unlock_skill(action: Dictionary, t: int) -> FlowActionOutcome:
	var snap_type := str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.SANCTUM:
		return FlowActionOutcome.handled_outcome()

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id  := str(payload.get("echo_id",  "")).strip_edges()
	var skill_id := str(payload.get("skill_id", "")).strip_edges()
	if echo_id.is_empty() or skill_id.is_empty():
		return FlowActionOutcome.handled_outcome()

	# Validate skill exists in config
	var balance: Dictionary = config_service.get_balance()
	var bal_data_v: Variant = balance.get("data", {})
	var bal_data: Dictionary = bal_data_v if bal_data_v is Dictionary else {}
	var skills_cfg_v: Variant = bal_data.get("skills", {})
	var skills_cfg: Dictionary = skills_cfg_v if skills_cfg_v is Dictionary else {}
	var defs_v: Variant = skills_cfg.get("definitions", {})
	var defs: Dictionary = defs_v if defs_v is Dictionary else {}
	if not defs.has(skill_id):
		logger.debug(t, "sanctum.unlock_skill.denied", "Unknown skill_id", { "skill_id": skill_id })
		return FlowActionOutcome.handled_outcome()

	# Find echo in roster (mutable reference — Dictionary is a reference type in GDScript)
	var echo_ref := SanctumService.find_roster_echo(flow_ctx.save_data, echo_id)
	if echo_ref.is_empty():
		return FlowActionOutcome.handled_outcome()

	# Calling must be confirmed
	if SkillDefinition.get_slot_count(echo_ref, skills_cfg) < 1:
		logger.debug(t, "sanctum.unlock_skill.denied", "Calling not confirmed", { "echo_id": echo_id })
		return FlowActionOutcome.handled_outcome()

	# Skill family must be accessible for the echo's calling (strong or light alignment).
	# Guards against stale / bypassed payloads that reference skills outside the calling's constellation.
	var defn: Dictionary = defs.get(skill_id, {}) as Dictionary
	var skill_family := str(defn.get("skill_family", ""))
	var echo_calling := str(echo_ref.get("calling", ""))
	var align_table_v: Variant = skills_cfg.get("calling_family_alignment", {})
	var align_table: Dictionary = align_table_v if align_table_v is Dictionary else {}
	var calling_align_v: Variant = align_table.get(echo_calling, {})
	var calling_align: Dictionary = calling_align_v if calling_align_v is Dictionary else {}
	var accessible: Array = []
	for fid_v in calling_align.get("strong", []):
		accessible.append(str(fid_v))
	for fid_v in calling_align.get("light", []):
		accessible.append(str(fid_v))
	if not skill_family.is_empty() and not accessible.is_empty() \
			and not (skill_family in accessible):
		logger.debug(t, "sanctum.unlock_skill.denied", "Skill family not accessible for calling", {
			"echo_id": echo_id, "skill_id": skill_id,
			"skill_family": skill_family, "accessible": accessible,
		})
		return FlowActionOutcome.handled_outcome()

	# Not already unlocked
	var ul_v: Variant = echo_ref.get("unlocked_skills", [])
	var ul: Array = ul_v if ul_v is Array else []
	if skill_id in ul:
		logger.debug(t, "sanctum.unlock_skill.denied", "Already unlocked", { "skill_id": skill_id })
		return FlowActionOutcome.handled_outcome()

	# Ase cost from unlock_conditions (defn already loaded above)
	var uc_v: Variant = defn.get("unlock_conditions", {})
	var uc: Dictionary = uc_v if uc_v is Dictionary else {}
	var ase_cost := int(uc.get("ase_cost", 0))

	# Settle time so accrued Ase is applied before the afford check
	_economy_settlement_service().settle({ "type": "economy.settle_time", "now_unix": int(Time.get_unix_time_from_system()) }, t)

	if not econ.can_afford_ase(ase_cost):
		logger.debug(t, "sanctum.unlock_skill.denied", "Insufficient Ase", {
			"echo_id": echo_id, "skill_id": skill_id, "cost": ase_cost
		})
		return FlowActionOutcome.handled_outcome()

	econ.spend_ase(ase_cost, "skill.unlock", logger, t)

	ul.append(skill_id)
	echo_ref["unlocked_skills"] = ul

	logger.info(t, "sanctum.skill.unlock", "Skill unlocked", {
		"echo_id": echo_id, "skill_id": skill_id, "ase_cost": ase_cost
	})

	return FlowActionOutcome.reenter_outcome().with_save_reason("skill.unlock")


## Builds a fresh EconomySettlementService scoped to the current flow_ctx/config_service/econ/
## logger. Same per-call construction rationale as SanctumController's own private
## _economy_settlement_service() — used for handle_unlock_skill()'s settle-before-afford-check
## pre-step (not a dispatched action itself).
func _economy_settlement_service() -> EconomySettlementService:
	return EconomySettlementService.new(flow_ctx, config_service, econ, logger)
