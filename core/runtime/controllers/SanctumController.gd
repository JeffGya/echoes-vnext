# res://core/runtime/controllers/SanctumController.gd
# V2-INFRA-003 Phase 4 Slice 8: sixth bounded domain controller extracted out of
# FlowRuntime.gd, following the pattern WeaveController/VowController/DebugController/
# ProgressionController/EconomySettlementController set (see WeaveController.gd for the full
# contract writeup).
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
# Owns 11 actions: sanctum.summon, sanctum.grade_select, sanctum.party.toggle,
# sanctum.name.reroll, sanctum.name.confirm, sanctum.institution.establish,
# sanctum.institution.assign_echo, sanctum.institution.remove_echo, sanctum.companion.accept,
# sanctum.companion.decline, ui.dismiss_summon_reveals. Moved verbatim (behaviour unchanged)
# from FlowRuntime.gd: _handle_sanctum_summon, _handle_sanctum_grade_select,
# _handle_sanctum_party_toggle (+ its private helper _get_party_max_size),
# _handle_sanctum_institution_establish, _handle_sanctum_institution_assign_echo,
# _handle_sanctum_institution_remove_echo, _handle_companion_accept, _handle_companion_decline,
# plus the three actions that were previously inline case bodies in dispatch()'s match block
# rather than named private methods: sanctum.name.reroll, sanctum.name.confirm,
# ui.dismiss_summon_reveals.
#
# CORRECTION vs the story brief: _repair_echo_schema did NOT move here. Its only call site
# (flow.continue, at the top of dispatch()'s match block) is not one of this controller's 11
# actions and stays on FlowRuntime this slice. Per core/AGENTS.md's "a helper used by two or
# more domains has an owner" rule (mirroring EconomySettlementController's settle() precedent),
# a helper called from both a controller's action AND a still-private FlowRuntime handler
# belongs on a service, not on the controller — a controller's methods are meant to be reached
# via the dispatch()/FlowActionOutcome contract, not called as a bare mid-handler subroutine.
# _repair_echo_schema reads/writes save_data["sanctum"]["roster"], which is SanctumService's
# domain, so it moved there instead: SanctumService.repair_echo_schema(save_data, logger, t)
# -> bool (static, verbatim logic, returns whether anything was patched so the caller can decide
# to request a save — matching find_roster_echo's "static + explicit save_data param" shape).
# FlowRuntime's flow.continue call site now reads:
#   if SanctumService.repair_echo_schema(flow_ctx.save_data, logger, t):
#       _mark_save_requested("sanctum.schema.repair")
#
# THE REFRESH-SNAPSHOT TRANSLATION: sanctum.name.reroll, sanctum.name.confirm, and
# sanctum.grade_select never build/rebuild a fresh SUMMON snapshot on the reroll path — reroll
# and name.confirm both ended with a bare flow_machine.refresh_snapshot() call pre-extraction,
# translated the same way DebugController.gd's header documents: each returns
# FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot) — assigning last_snapshot back to
# itself is a no-op, and _apply_action_outcome()'s has_replacement_snapshot branch then calls
# flow_machine.refresh_snapshot() on FlowRuntime's behalf, exactly matching the pre-extraction
# call. sanctum.grade_select and sanctum.summon DO rebuild (FlowSummonState.build_snapshot()) —
# those return snapshot_outcome() with the freshly built dictionary instead.
#
# THE REENTER+REFRESH TRANSLATION (V2-INFRA-003 Phase 4 Slice 8 — new this slice):
# sanctum.party.toggle's SANCTUM branch, all three sanctum.institution.* handlers, and
# sanctum.companion.accept/decline all pre-extraction ended with the same two-call pairing:
#     flow_machine.reenter(flow_ctx, logger, t)
#     flow_machine.refresh_snapshot(flow_ctx, logger, t)
# reenter() re-runs the current state's enter() (FlowSanctumState.enter(), which delegates to
# SanctumSnapshotBuilder.build() — a COMPLETE flow.sanctum snapshot) and assigns the result to
# flow_ctx.last_snapshot itself; refresh_snapshot() afterward is just the generic
# validate-and-store pass (Lesson 9 — it does not rebuild anything for flow.sanctum on its own).
# This pairing fixed a recorded defect where the Sanctum projection came back incomplete after a
# mid-state mutation (skill unlock, party toggle) — see git history around
# "restore Sanctum snapshot projection after reenter()". FlowActionOutcome had no way to express
# "reenter, then refresh" as of Slice 7 — it only had has_replacement_snapshot (a snapshot the
# CALLER already built) and suppress_refresh (skip the refresh after assigning one). Neither
# fits: reenter() builds its own snapshot internally, so there is nothing for this controller to
# hand back as replacement_snapshot, and the refresh call here IS wanted (unlike
# suppress_refresh's two existing users). So this slice adds a third outcome shape:
#   - FlowActionOutcome.requires_reenter: bool (new field, default false)
#   - FlowActionOutcome.reenter_outcome() -> FlowActionOutcome (new convenience constructor,
#     handled=true, requires_reenter=true)
#   - FlowRuntime._apply_action_outcome() gains a requires_reenter branch, checked BEFORE
#     has_replacement_snapshot (mutually exclusive — reenter() already assigns
#     flow_ctx.last_snapshot, so a controller returning requires_reenter never also sets
#     has_replacement_snapshot):
#         if outcome.requires_reenter:
#             flow_machine.reenter(flow_ctx, logger, t)
#             flow_machine.refresh_snapshot(flow_ctx, logger, t)
#         elif outcome.has_replacement_snapshot:
#             ...
# transition_to and save_reasons are still applied afterward exactly as before, so
# .with_save_reason() chains onto reenter_outcome() the same way it does onto snapshot_outcome().
# This is the "requires_reenter/reenter_outcome" shape the story brief referenced as designed-
# but-unshipped in an earlier slice — this controller is its first (and, this slice, only) set
# of call sites.
#
# sanctum.party.toggle's ECHO_PARTY branch does NOT reenter (only SANCTUM does) — it keeps the
# snapshot_outcome(FlowEchoPartyState.build_snapshot(...)) shape instead, matching
# pre-extraction exactly (reenter() only ran when snap_type == FlowStateIds.SANCTUM).
#
# DEAD-BUT-OWNED: sanctum.name.reroll / sanctum.name.confirm have zero dispatch sites in ui/ or
# tests/ (superseded by onboarding.name.confirm) but stay routed here — every action keeps
# exactly one owner. Do not delete them, name_roll_index, or SanctumNameService (still
# live-read by the Sanctum projection).
#
# NO-STACK GUARD: sanctum.companion.accept/decline only clear save_data.sanctum.companion_invite
# — they never decide whether a NEW invite gets stored. That one-invite-max guard lives entirely
# in RecruitmentConsequenceService.compute_ally_recruit_offer_if_eligible() (combat-teardown
# path, not a dispatched sanctum.* action), which this controller does not call and must not
# reimplement.
#
# EchoFactory RNG draw order (rarity -> calling_origin -> gender -> name -> traits ->
# archetype_birth -> derived_stats) is IMMUTABLE inside handle_summon() below — moved verbatim,
# never reordered.

class_name SanctumController
extends RefCounted

const InstitutionServiceScript := preload("res://core/sanctum/InstitutionService.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var econ: EconomyService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _econ: EconomyService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	econ = _econ
	logger = _logger


## sanctum.summon — moved verbatim from FlowRuntime._handle_sanctum_summon. Transactional:
## settle -> validate -> spend -> generate -> save. Denied paths (insufficient funds, spend
## failure, missing seed_root) return handled_outcome() with NO snapshot rebuild and NO save —
## matches pre-extraction behaviour exactly (those paths only logged and returned void).
func handle_summon(action: Dictionary, t: int) -> FlowActionOutcome:
	# 0) parse count
	var count := int(action.get("count", 1))
	if count < 1:
		count = 1
	if count > 10:
		count = 10

	# 1) settle before spend
	# V2-INFRA-003 Phase 4 Slice 7: routed to EconomySettlementService.settle() — the private
	# handler this used to call was a ~140-line cross-domain function that unconditionally
	# refreshed the snapshot itself; the service does not (services take no flow_machine, per
	# RULES). No refresh is added here because this function already rebuilds and refreshes
	# the SUMMON snapshot unconditionally below (step 5) via the returned outcome —
	# refresh_snapshot() only re-validates the current ctx.last_snapshot, and nothing between
	# here and step 5 reads it.
	var now_unix := int(action.get("now_unix", 0))
	if now_unix > 0:
		_economy_settlement_service().settle({
			"type": "economy.settle_time",
			"now_unix": now_unix,
			"source": "sanctum.summon.before_spend"
		}, t)

	# 2) read cost (grade-based; fall back to flat key if grade missing)
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}

	var fallback_flat_cost := int(summ_cfg.get("ase_cost_per_summon", 60))
	var grade_costs_v: Variant = summ_cfg.get("ase_cost_per_summon_by_grade", {})
	var grade_costs: Dictionary = grade_costs_v if grade_costs_v is Dictionary else {}
	var grade := flow_ctx.selected_summon_grade
	var cost_each := int(grade_costs.get(grade, fallback_flat_cost))

	var total_cost := cost_each * count

	# 3) check funds
	var econ_v: Variant = flow_ctx.save_data.get("economy", {})
	var econ_data: Dictionary = econ_v if econ_v is Dictionary else {}
	var ase_before := int(econ_data.get("ase", 0))

	if ase_before < total_cost:
		logger.info(t, "sanctum.summon.denied", "Not enough Ase to summon", {
			"ase": ase_before,
			"grade": grade,
			"cost_each": cost_each,
			"count": count,
			"total_cost": total_cost
		})
		return FlowActionOutcome.handled_outcome()

	# 4) spend once
	var spend_reason := "summon.cost." + grade
	var ok_spend: bool = econ.spend_ase(total_cost, spend_reason, logger, t)
	if not ok_spend:
		logger.info(t, "sanctum.summon.denied", "Spend failed", {
			"ase": ase_before,
			"grade": grade,
			"total_cost": total_cost,
			"count": count
		})
		return FlowActionOutcome.handled_outcome()

	# 5) generate + persist many
	var camp: Dictionary = {}
	if flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]
	var seed_root := str(camp.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "sanctum.summon.denied", "Missing campaign seed_root", {})
		return FlowActionOutcome.handled_outcome()

	var expr_v: Variant = data.get("maturity_expression", {})
	var expression_cfg: Dictionary = expr_v if expr_v is Dictionary else {}
	var result := SummonService.summon_paid_many(flow_ctx.save_data, seed_root, summ_cfg, count, logger, t, expression_cfg)

	if not bool(result.get("ok", false)):
		return FlowActionOutcome.handled_outcome()

	# Append newly summoned echoes to transient reveal queue (NOT saved)
	var echoes_v: Variant = result.get("echoes", [])
	var echoes: Array = echoes_v if echoes_v is Array else []
	# PROG-005: extract vector config once for the loop (data dict is already resolved above)
	var vec_cfg_v: Variant = data.get("vectors", {})
	var vec_cfg: Dictionary = vec_cfg_v if vec_cfg_v is Dictionary else {}
	for e_v in echoes:
		if e_v is Dictionary:
			# EMOTION-001: initialise emotion block before the echo enters reveals/roster
			EmotionService.init_echo(e_v, logger, t)
			# PROG-005: initialise vector scores from archetype_init config
			VectorService.init_vectors(e_v, vec_cfg, logger, t)
			# Arrival bark — logged for debug output and telemetry (display-only, no side effects)
			var arch_v   := str(e_v.get("archetype_birth", ""))
			var t_v_bark := e_v.get("traits", {}) as Dictionary
			var tier_v   := ShoutBank.get_tier(
				int(t_v_bark.get("courage", 50)),
				int(t_v_bark.get("wisdom",  50)),
				int(t_v_bark.get("faith",   50))
			)
			var bark := ShoutBank.get_shout("arrival", arch_v, tier_v)
			logger.info(t, "sanctum.summon.bark", bark, {
				"echo_id": str(e_v.get("id", "")),
				"arch":    arch_v,
				"tier":    tier_v,
			})
			flow_ctx.pending_summon_reveals.append(e_v)

	# Rebuild snapshot so SummonScreen immediately reflects the updated Ase balance
	# and the pending_summon_reveals queue (reveal overlay). Without this, the screen
	# stays stale and repeated clicks each trigger a real summon — the root cause of
	# echoes accumulating silently across sessions.
	# Same static build_snapshot() pattern used by handle_grade_select.
	return FlowActionOutcome.snapshot_outcome(FlowSummonState.build_snapshot(flow_ctx, t)).with_save_reason("sanctum.summon")


## sanctum.grade_select — moved verbatim from FlowRuntime._handle_sanctum_grade_select.
func handle_grade_select(action: Dictionary, t: int) -> FlowActionOutcome:
	var grade := str(action.get("grade", "")).strip_edges()
	if grade.is_empty():
		logger.debug(t, "economy.summon.grade_select.denied", "Grade select denied (empty grade)", {})
		return FlowActionOutcome.handled_outcome()

	# Validate grade against the cost table in balance.json
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}
	var grade_costs_v: Variant = summ_cfg.get("ase_cost_per_summon_by_grade", {})
	var grade_costs: Dictionary = grade_costs_v if grade_costs_v is Dictionary else {}

	if not grade_costs.has(grade):
		logger.debug(t, "economy.summon.grade_select.denied", "Grade select denied (invalid grade key)", {
			"grade": grade,
			"valid_grades": grade_costs.keys()
		})
		return FlowActionOutcome.handled_outcome()

	flow_ctx.selected_summon_grade = grade

	var ase_cost := int(grade_costs.get(grade, 60))
	var econ_v: Variant = flow_ctx.save_data.get("economy", {})
	var econ_data: Dictionary = econ_v if econ_v is Dictionary else {}
	var ase_balance := int(econ_data.get("ase", 0))

	logger.debug(t, "economy.summon.grade_select", "Summon grade selected", {
		"grade": grade,
		"ase_cost": ase_cost,
		"can_afford": ase_balance >= ase_cost,
	})

	# Rebuild snapshot mid-state (refresh_snapshot reads ctx.last_snapshot as-is for SUMMON)
	return FlowActionOutcome.snapshot_outcome(FlowSummonState.build_snapshot(flow_ctx, t))


## sanctum.party.toggle — moved verbatim from FlowRuntime._handle_sanctum_party_toggle (+ its
## private helper _get_party_max_size below). Denied paths (outside sanctum family, missing/
## unknown echo_id, party full) return handled_outcome() — no snapshot rebuild, no save,
## matching the pre-extraction bare `return`.
func handle_party_toggle(action: Dictionary, t: int) -> FlowActionOutcome:
	# Allow from EchoParty and Sanctum (EchoDetail party button); ignore elsewhere.
	var snap_type := str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY and snap_type != FlowStateIds.SANCTUM:
		logger.debug(t, "sanctum.party.toggle.ignored", "Party toggle ignored (outside sanctum family)", {
			"snapshot_type": snap_type
		})
		return FlowActionOutcome.handled_outcome()

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}

	var echo_id := str(payload.get("echo_id", "")).strip_edges()
	if echo_id.is_empty():
		logger.debug(t, "sanctum.party.toggle.denied", "Party toggle denied (missing echo_id)", {})
		return FlowActionOutcome.handled_outcome()

	# Ensure pending exists (should have been initialized on enter, but be defensive)
	if flow_ctx.pending_party_ids == null:
		flow_ctx.pending_party_ids = []
	if not (flow_ctx.pending_party_ids is Array):
		flow_ctx.pending_party_ids = []

	# V2-PROG-009: When toggling from flow.sanctum (EchoDetail party button), sync
	# pending_party_ids from active_party_ids so the toggle operates on the current list.
	if snap_type == FlowStateIds.SANCTUM:
		var _s_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var _s: Dictionary = _s_v if _s_v is Dictionary else {}
		var _ap_v: Variant = _s.get("active_party_ids", [])
		flow_ctx.pending_party_ids = (_ap_v if _ap_v is Array else []).duplicate()

	# Validate echo_id exists in roster (prevent selecting ghost ids)
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var exists := false
	for e_v in roster:
		if e_v is Dictionary and str(e_v.get("id", "")) == echo_id:
			exists = true
			break

	if not exists:
		logger.debug(t, "sanctum.party.toggle.denied", "Party toggle denied (echo not in roster)", {
			"echo_id": echo_id
		})
		return FlowActionOutcome.handled_outcome()

	var max_party_size := _get_party_max_size()

	# Toggle behavior
	var added := false
	if flow_ctx.pending_party_ids.has(echo_id):
		flow_ctx.pending_party_ids.erase(echo_id)
		added = false
	else:
		if flow_ctx.pending_party_ids.size() >= max_party_size:
			logger.info(t, "sanctum.party.toggle_denied", "Party is full", {
				"echo_id": echo_id,
				"max_party_size": max_party_size,
				"pending_count": flow_ctx.pending_party_ids.size()
			})
			return FlowActionOutcome.handled_outcome()
		flow_ctx.pending_party_ids.append(echo_id)
		added = true

		# BOND-001: record party encounter with all current party members (before this echo was added)
		if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
			flow_ctx.save_data["sanctum"] = {}
		var bond_sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary
		var enc_v = bond_sanctum.get("party_encounters", [])
		var encounters: Array = enc_v if enc_v is Array else []
		for existing_id_v in flow_ctx.pending_party_ids:
			var existing_id: String = str(existing_id_v)
			if existing_id == echo_id:
				continue
			encounters = SocialGraphService.record_encounter(encounters, echo_id, existing_id)
		bond_sanctum["party_encounters"] = encounters

	logger.debug(t, "sanctum.party.toggle", "Party toggled", {
		"echo_id": echo_id,
		"added": added,
		"pending_count": flow_ctx.pending_party_ids.size(),
		"max_party_size": max_party_size
	})

	# Immediate apply: persist selection on each toggle.
	if not flow_ctx.save_data.has("sanctum") or typeof(flow_ctx.save_data["sanctum"]) != TYPE_DICTIONARY:
		flow_ctx.save_data["sanctum"] = {}
	var sanctum_for_save: Dictionary = flow_ctx.save_data["sanctum"]
	sanctum_for_save["active_party_ids"] = flow_ctx.pending_party_ids.duplicate()

	# V2-PROG-009: Rebuild the appropriate snapshot.
	# SANCTUM: full reenter so echo_detail_roster reflects updated in_party flags.
	# ECHO_PARTY: build party snapshot as before.
	if snap_type == FlowStateIds.SANCTUM:
		# V2-INFRA-003 Phase 3: reenter() re-runs FlowSanctumState.enter(), which delegates to
		# SanctumSnapshotBuilder.build() — a COMPLETE flow.sanctum snapshot (ase_balance,
		# sanctum_name, party_slots, ...) on its own. The refresh_snapshot() call
		# requires_reenter triggers afterward is just the generic validate-and-store pass; it no
		# longer performs any Sanctum-specific rebuild.
		return FlowActionOutcome.reenter_outcome().with_save_reason("sanctum.party.autosave")
	else:
		return FlowActionOutcome.snapshot_outcome(FlowEchoPartyState.build_snapshot(flow_ctx, t)).with_save_reason("sanctum.party.autosave")


## Moved verbatim from FlowRuntime._get_party_max_size. Only caller is handle_party_toggle above.
func _get_party_max_size() -> int:
	var max_party_size := 5
	if config_service == null:
		return max_party_size

	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var s_v: Variant = data.get("sanctum", {})
	var s_cfg: Dictionary = s_v if s_v is Dictionary else {}

	return int(s_cfg.get("party_max_size", 5))


## sanctum.name.reroll — DEAD but OWNED (see file header). Moved verbatim from dispatch()'s
## inline case body. No save request on reroll (no save spam) — matches pre-extraction exactly.
func handle_name_reroll(t: int) -> FlowActionOutcome:
	if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
		flow_ctx.save_data["sanctum"] = {}

	var sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary
	var idx := int(sanctum.get("name_roll_index", 0)) + 1
	sanctum["name_roll_index"] = idx

	logger.debug(t, "sanctum.name.reroll", "Rerolled sanctum name suggestion", {
		"roll_index": idx
	})

	# IMPORTANT: no transition occurs, so we must refresh snapshot
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)


## sanctum.name.confirm — DEAD but OWNED (see file header). Moved verbatim from dispatch()'s
## inline case body.
func handle_name_confirm(action: Dictionary, t: int) -> FlowActionOutcome:
	if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
		flow_ctx.save_data["sanctum"] = {}

	var sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary

	var raw := str(action.get("name", ""))
	var name := raw.strip_edges()

	# MVP sanitize rules (deterministic, no OS time)
	if name.length() < 2:
		name = "Sanctum"
	if name.length() > 24:
		name = name.substr(0, 24)

	sanctum["name"] = name

	logger.info(t, "sanctum.name.confirm", "Sanctum name set", {
		"name": name
	})

	# Refresh snapshot so the modal hides (sanctum_name is now set)
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot).with_save_reason("sanctum.name.confirm")


## ui.dismiss_summon_reveals — MUTATES flow_ctx.pending_summon_reveals (not publication-only).
## Moved verbatim from dispatch()'s inline case body.
func handle_dismiss_summon_reveals(t: int) -> FlowActionOutcome:
	flow_ctx.pending_summon_reveals.clear()
	logger.debug(t, "ui.dismiss_summon_reveals", "Dismissed summon reveal queue", {
		"remaining": flow_ctx.pending_summon_reveals.size()
	})
	# IMPORTANT: no transition occurs, so refresh snapshot
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)


## sanctum.institution.establish — moved verbatim from FlowRuntime._handle_sanctum_institution_establish.
func handle_institution_establish(action: Dictionary, t: int) -> FlowActionOutcome:
	var payload: Dictionary = action.get("payload", {})
	var inst_id := str(payload.get("institution_id", ""))
	if inst_id.is_empty():
		return FlowActionOutcome.handled_outcome()
	var pos_dict_v: Variant = payload.get("position", { "x": 0, "y": 0 })
	var pos_dict: Dictionary = pos_dict_v if pos_dict_v is Dictionary else { "x": 0, "y": 0 }
	var position := Vector2i(int(pos_dict.get("x", 0)), int(pos_dict.get("y", 0)))
	var inst_cfg := ConfigService.get_institutions_cfg(config_service)
	if InstitutionServiceScript.establish(inst_id, flow_ctx.save_data, econ, inst_cfg, logger, t, position):
		# reenter() re-runs FlowSanctumState.enter() so sanctum_layout + sanctum_occupants
		# reflect the newly established institution before refresh_snapshot() emits the UI update.
		return FlowActionOutcome.reenter_outcome().with_save_reason("institution.establish")
	return FlowActionOutcome.handled_outcome()


## sanctum.institution.assign_echo — moved verbatim from FlowRuntime._handle_sanctum_institution_assign_echo.
func handle_institution_assign_echo(action: Dictionary, t: int) -> FlowActionOutcome:
	var payload := action.get("payload", {}) as Dictionary
	var inst_id := str(payload.get("institution_id", ""))
	var echo_id := str(payload.get("echo_id", ""))
	if inst_id.is_empty() or echo_id.is_empty():
		return FlowActionOutcome.handled_outcome()
	var inst_cfg := ConfigService.get_institutions_cfg(config_service)
	if InstitutionServiceScript.assign_echo(inst_id, echo_id, flow_ctx.save_data, econ, inst_cfg, logger, t):
		return FlowActionOutcome.reenter_outcome().with_save_reason("institution.assign_echo")
	return FlowActionOutcome.handled_outcome()


## sanctum.institution.remove_echo — moved verbatim from FlowRuntime._handle_sanctum_institution_remove_echo.
func handle_institution_remove_echo(action: Dictionary, t: int) -> FlowActionOutcome:
	var payload := action.get("payload", {}) as Dictionary
	var inst_id := str(payload.get("institution_id", ""))
	var echo_id := str(payload.get("echo_id", ""))
	if inst_id.is_empty() or echo_id.is_empty():
		return FlowActionOutcome.handled_outcome()
	var inst_cfg := ConfigService.get_institutions_cfg(config_service)
	if InstitutionServiceScript.remove_echo(inst_id, echo_id, flow_ctx.save_data, econ, inst_cfg, logger, t):
		return FlowActionOutcome.reenter_outcome().with_save_reason("institution.remove_echo")
	return FlowActionOutcome.handled_outcome()


## sanctum.companion.accept — moved verbatim from FlowRuntime._handle_companion_accept. Mints
## exactly one roster echo via RecruitmentService.promote_ally_to_echo() (origin
## "recruited_ally" + companion bond debuff, seeded by the service itself), clears the invite,
## then rebuilds the Sanctum snapshot (reenter + refresh) so the modal dismisses. No-op
## (handled_outcome(), no save/reenter) when no invite is pending.
func handle_companion_accept(t: int) -> FlowActionOutcome:
	if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
		flow_ctx.save_data["sanctum"] = {}
	var _hca_sanctum: Dictionary = flow_ctx.save_data["sanctum"]
	var _hca_invite_v: Variant = _hca_sanctum.get("companion_invite", {})
	var _hca_invite: Dictionary = _hca_invite_v if _hca_invite_v is Dictionary else {}
	if _hca_invite.is_empty():
		return FlowActionOutcome.handled_outcome()

	var _hca_ally_v: Variant = _hca_invite.get("ally_actor", {})
	var _hca_ally: Dictionary = _hca_ally_v if _hca_ally_v is Dictionary else {}
	var _hca_contact_v: Variant = _hca_invite.get("source_contact", {})
	var _hca_contact: Dictionary = _hca_contact_v if _hca_contact_v is Dictionary else {}
	var _hca_bal: Dictionary = config_service.get_balance()
	var _hca_bal_data_v: Variant = _hca_bal.get("data", {})
	var _hca_bal_data: Dictionary = _hca_bal_data_v if _hca_bal_data_v is Dictionary else {}
	var _hca_echo_id: String = RecruitmentService.promote_ally_to_echo(
		_hca_ally, _hca_contact, flow_ctx.save_data, _hca_bal_data, logger, t)

	_hca_sanctum["companion_invite"] = {}
	flow_ctx.save_data["sanctum"] = _hca_sanctum
	logger.info(t, "sanctum.companion.accepted", "Player accepted the earned-return companion invite", {
		"echo_id": _hca_echo_id,
	})

	return FlowActionOutcome.reenter_outcome().with_save_reason("sanctum.companion.recruited")


## sanctum.companion.decline — moved verbatim from FlowRuntime._handle_companion_decline. Mints
## nothing, clears the invite, then rebuilds the Sanctum snapshot so the modal dismisses. No-op
## (handled_outcome(), no save/reenter) when no invite is pending.
func handle_companion_decline(t: int) -> FlowActionOutcome:
	if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
		flow_ctx.save_data["sanctum"] = {}
	var _hcd_sanctum: Dictionary = flow_ctx.save_data["sanctum"]
	var _hcd_invite_v: Variant = _hcd_sanctum.get("companion_invite", {})
	var _hcd_invite: Dictionary = _hcd_invite_v if _hcd_invite_v is Dictionary else {}
	if _hcd_invite.is_empty():
		return FlowActionOutcome.handled_outcome()

	_hcd_sanctum["companion_invite"] = {}
	flow_ctx.save_data["sanctum"] = _hcd_sanctum
	logger.info(t, "sanctum.companion.declined", "Player declined the earned-return companion invite", {})

	return FlowActionOutcome.reenter_outcome().with_save_reason("sanctum.companion.declined")


## Builds a fresh EconomySettlementService scoped to the current flow_ctx/config_service/econ/
## logger. Constructed per-call, same rationale as FlowRuntime._weave_controller(): cheap
## RefCounted, always correct even if a caller replaces flow_ctx after construction. Used by
## handle_summon()'s settle-before-spend pre-step (not a dispatched action itself).
func _economy_settlement_service() -> EconomySettlementService:
	return EconomySettlementService.new(flow_ctx, config_service, econ, logger)
