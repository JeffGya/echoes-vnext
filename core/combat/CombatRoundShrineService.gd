# res://core/combat/CombatRoundShrineService.gd
# V2-INFRA-003 Phase 6 Slice 6E: the PURIFY_SHRINE PER-ROUND DRAIN phase, extracted verbatim out
# of core/runtime/FlowRuntime.gd::_end_round (the block that sat at :2716-:2761, 46 lines
# including its leading comment). This is the LAST phase extraction from that function.
#
# CONTRACT (identical to CombatRoundEmotionService / CombatRoundSpawnService /
# CombatRoundGuideSpiritService / CombatRoundObjectiveService, the four siblings already built
# from this same function in slices 6A-6D):
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly. This body requests NO save at all, which is the
#     pre-extraction behaviour and must stay that way: FlowRuntime._mark_save_requested()
#     joins reasons with "|", so a save queued here would glue its reason onto the next
#     dispatch's string.
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot.
#   - Same constructor signature (flow_ctx, config_service, logger) as every sibling service.
#
# LOCATION AND REMIT — why a new sibling BESIDE ShrineService rather than more methods ON it.
# ShrineService.gd's own header states its remit in its first rule: "Pure static functions only —
# no side effects outside the passed dicts, no logging." The block moved here breaks all three
# clauses of that sentence:
#   - it iterates ectx.actors and mutates actors it was not passed (the purifier's cooldown, and
#     every living echo's morale) — side effects outside any passed dict;
#   - it emits two StructuredLogger lines;
#   - it needs an EncounterContext, a logger and a `round`, none of which a pure static shrine
#     helper may know about.
# Folding it in would have required rewriting that sentence, i.e. widening ShrineService's remit
# to keep a caller. The existing division of labour is instead left exactly as it was: this file
# owns the PER-ROUND PHASE (when the drain happens, what dies, who logs, who loses morale) and
# calls ShrineService.apply_drain() for the DRAIN ARITHMETIC (stack tick-down, expiry penalty,
# clamp, hp write) exactly as _end_round did. Nothing is duplicated and no lookalike API is
# substituted — the one call to ShrineService is moved, not copied (AGENTS.md #19).
#
# The sibling placement also matches the slice 6D precedent: the Phase 6 services decompose
# _end_round BY PHASE, and for the objective phases that means BY RESOLUTION MODE.
# CombatRoundSpawnService owns RECOVER and ENDURE; CombatRoundGuideSpiritService owns
# GUIDE_SPIRIT; CombatRoundObjectiveService owns PROTECT and PURSUE. PURIFY_SHRINE was the one
# resolution mode with no service of its own. It has one now.
#
# WHAT IT TOUCHES — the complete read/write set, verified line by line rather than assumed:
#
#   READS
#     ectx.resolution_mode                      mode gate (PURIFY_SHRINE only)
#     ectx.actors                               is_structure, is_dead, id, faction, morale,
#                                               current_hp (via the alive-shrine fallback below
#                                               and inside ShrineService.apply_drain),
#                                               purify_stacks, purify_cooldown, and — inside
#                                               LeadershipEmotionService.apply_morale_loss —
#                                               every other actor's leadership_traits, grid_pos
#                                               and _morale_forecast_until_round
#     ectx.purifier_id                          guards the cooldown decrement
#     ConfigService.get_shrine_cfg()            data.combat.shrine, for the whole shrine cfg
#                                               dict handed to ShrineService.apply_drain plus
#                                               morale_drain_per_wave. NOTE this is this
#                                               service's OWN config_service field — the
#                                               pre-extraction line read FlowRuntime's
#                                               config_service, which is the same object handed
#                                               to the constructor. (Contrast slice 6D, which had
#                                               to keep reading flow_ctx.config_service.)
#     leadership_expr_cfg                       PASSED IN, not re-read. _end_round computes it
#                                               once at the top (data.maturity_expression) and
#                                               hands the same dict to the emotion tick; passing
#                                               it keeps that single read single, exactly as
#                                               before.
#     `round`                                   passed in, not re-read, so death_round and the
#                                               round_number argument to apply_morale_loss carry
#                                               the exact value _end_round logged in
#                                               combat.round_end for the same round.
#
#   WRITES
#     shrine actor["current_hp"]                via ShrineService.apply_drain
#     shrine actor["purify_stacks"]             via ShrineService.apply_drain (ticked/pruned)
#     shrine actor["is_dead"]                   true when drained to <= 0
#     shrine actor["death_round"]               set to `round` at the same moment
#     purifier actor["purify_cooldown"]         maxi(0, n - 1)
#     every living echo actor["morale"]         maxi(0, morale - applied_drain)
#     two logger lines                          combat.shrine_drain info,
#                                               combat.shrine.morale_drain info
#
#   RETURNS — the one value crossing the boundary
#     shrine_hp_val: int. This phase is NOT void, which is the whole reason the seam needed
#     designing. _end_round consumes the value TWICE downstream, both inside the
#     end_check.over branch: ectx.combat_result["shrine_hp"] (which the resolve snapshot
#     surfaces) and the "shrine_hp" field of the combat.end log line. Returning it is what
#     keeps the caller from re-deriving it — a re-derivation would not be equivalent, because
#     by the time the end check runs the shrine may have been marked dead and a second scan
#     would have to decide whether to skip dead structures. Exactly ONE value crosses: nothing
#     else computed here is read again by _end_round.
#     0 is returned for every non-PURIFY_SHRINE mode, which is the pre-extraction initialiser.
#
#   NOT TOUCHED, checked rather than assumed: save data (never read, never written),
#   ectx.round_bark_events (the coupling slice 6A hit — this phase fires no bark and constructs
#   no NarrativeVoiceService), ectx.combat_state in its entirety (round_counter is NOT read and
#   NOT incremented here; neither are hold_counter, protect_counter, contain_counter or
#   combat_over), ectx.last_round_results, ectx.last_round_snapshot, ectx.final_snapshot,
#   ectx.combat_result (written by _end_round from the returned int, not here),
#   flow_ctx.save_data, flow_ctx.last_snapshot and flow_ctx.flow_machine. flow_ctx is stored for
#   constructor symmetry with the four siblings and is not read by this file at all.
#
#   INDIRECT CALLS, both verified pure of RNG and of save access:
#     ShrineService.apply_drain()                       mutates only the shrine dict passed to it
#     LeadershipEmotionService.apply_morale_loss()      pure — returns an int, writes nothing;
#                                                       the caller performs the morale write
#
# DETERMINISM. This phase DRAWS NO RNG — verified rather than assumed, by reading both indirect
# callees through to their leaves: ShrineService.apply_drain is integer arithmetic over the stack
# array, and apply_morale_loss is a float fold over leadership traits. Neither derives a seed nor
# calls randf/randi. This confirms the standing measurement that the PROTECT theft roll (slice 6D)
# was the only random draw in _end_round; after this slice _end_round itself contains none. No
# dispatch is added or removed anywhere (the retreat roll's seed path embeds the sim tick).
#
# ORDERING IS LOAD-BEARING and unchanged. The drain is the FIRST phase in _end_round, running
# immediately after the combat.round_end log and BEFORE the emotion tick — because the drain can
# kill the shrine and the end-condition check must see that. Full order, unchanged: round_end log
# -> SHRINE DRAIN -> emotion tick -> RECOVER -> ENDURE -> GUIDE_SPIRIT -> PROTECT theft ->
# PROTECT guard -> PURSUE contain -> check_end_condition. The morale drain inside this phase must
# also keep running BEFORE the emotion tick, since that tick reads and further adjusts the same
# morale field.
#
# OPEN DEFECT — only the FIRST living structure is drained; the loop breaks after one. A
# PURIFY_SHRINE encounter with two shrines would drain one and silently ignore the other. Every
# shipped encounter has exactly one shrine. Not fixed.
#
# The cooldown decrement and the party morale drain below sit OUTSIDE that loop on purpose —
# see the comment at their site.

class_name CombatRoundShrineService
extends RefCounted

const LeadershipEmotionServiceScript := preload("res://core/combat/LeadershipEmotionService.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## COMBAT-006: applies the per-round shrine drain, run once per round from _end_round as the
## FIRST phase — after the combat.round_end log and BEFORE the emotion tick and the
## end-condition check, because the drain can kill the shrine.
##
## Returns the shrine hit points to report for this round: the post-drain value when a living
## shrine was drained, the first LIVING structure's current_hp when no drain ran, and 0 for
## every non-PURIFY_SHRINE mode and for a round with no living structure at all. _end_round consumes the
## return value twice — ectx.combat_result["shrine_hp"] and the combat.end log line — which is
## why this method returns rather than mutating and letting the caller re-read.
##
## The mode gate lives here rather than at the call site — COMBAT / RECOVER / ENDURE /
## GUIDE_SPIRIT / PROTECT / PURSUE return 0 immediately and are byte-identical.
func apply_shrine_drain_round(
		ectx: EncounterContext,
		round: int,
		leadership_expr_cfg: Dictionary,
		t: int) -> int:

	var shrine_hp_val: int = 0
	if ectx.resolution_mode != EncounterResolutionModes.PURIFY_SHRINE:
		return shrine_hp_val

	var shrine_cfg_drain: Dictionary = ConfigService.get_shrine_cfg(config_service)
	var shrine_drained: bool = false
	for a_v in ectx.actors:
		if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
			shrine_drained = true
			var drain_result: Dictionary = ShrineService.apply_drain(a_v, shrine_cfg_drain)
			shrine_hp_val = int(drain_result.get("shrine_hp", 0))
			if shrine_hp_val <= 0:
				a_v["is_dead"]     = true
				a_v["death_round"] = round
			logger.info(t, "combat.shrine_drain", "Shrine drained this round", {
				"shrine_id":     str(a_v.get("id", "")),
				"drain":         int(drain_result.get("drain", 0)),
				"shrine_hp":     shrine_hp_val,
				"stacks_active": a_v.get("purify_stacks", []).size(),
			})
			break

	# PER ROUND, not per shrine. purify_cooldown_rounds and morale_drain_per_wave are both
	# time-based keys, so neither the cooldown decrement nor the party morale drain may depend
	# on how many shrines live. Both run once per PURIFY_SHRINE round, including rounds after
	# the shrine is dead.
	if not ectx.purifier_id.is_empty():
		for pa_v in ectx.actors:
			if pa_v is Dictionary and str(pa_v.get("id", "")) == ectx.purifier_id:
				pa_v["purify_cooldown"] = maxi(0, int(pa_v.get("purify_cooldown", 0)) - 1)
				break

	# Shrine morale drain: each wave grinds down the party's will (runtime dict only).
	var morale_drain_wave: int = int(shrine_cfg_drain.get("morale_drain_per_wave", 5))
	var shrine_morale_affected: int = 0
	var shrine_morale_total: int = 0
	for em_a in ectx.actors:
		if em_a is Dictionary and not em_a.get("is_dead", false) \
				and em_a.get("faction", "") == "echo":
			var applied_drain := LeadershipEmotionServiceScript.apply_morale_loss(
				em_a, morale_drain_wave, ectx.actors, leadership_expr_cfg, round)
			var morale_before: int = int(em_a.get("morale", 50))
			em_a["morale"] = maxi(0, morale_before - applied_drain)
			# Report the EFFECTIVE drop: apply_morale_loss can reduce the loss and the floor
			# clamp can absorb the rest, so the configured number is not what landed.
			shrine_morale_total += morale_before - int(em_a["morale"])
			shrine_morale_affected += 1
	if shrine_morale_affected > 0:
		logger.info(t, "combat.shrine.morale_drain", "Shrine wave drains echo morale", {
			"delta":          -shrine_morale_total,
			"affected_count": shrine_morale_affected,
		})

	# Capture shrine_hp when no drain ran this round (for snapshot). D12: the trigger is
	# "the drain did not run", not the sentinel value 0 — a drain that lands the shrine on
	# exactly 0 hp must keep its own result. The rescan skips dead structures, so a dead
	# shrine no longer reports hit points; with no living structure the answer is 0.
	if not shrine_drained:
		for a_v in ectx.actors:
			if a_v is Dictionary and a_v.get("is_structure", false) \
					and not a_v.get("is_dead", false):
				shrine_hp_val = int(a_v.get("current_hp", 0))
				break

	return shrine_hp_val
