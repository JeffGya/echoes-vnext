# res://core/combat/ContributionLedgerService.gd
# V2-INFRA-003 Phase 6 Slice 6H: the COMBAT CONTRIBUTION LEDGER, moved verbatim out of
# core/runtime/FlowRuntime.gd. Two pieces that were 250 lines apart in that file and are one
# thing:
#   - the three ledger primitives (_new_contribution_ledger_entry :1981-:2000,
#     _credit_support_tally :2002-:2011, _fold_support_tally :2013-:2029), and
#   - the PROG-003 per-turn accumulator + the support fold, the tail of _resolve_next_actor
#     that sat at :1709-:1749.
#
# WHAT THIS IS. The single owner of EncounterContext.echo_action_logs — the per-encounter,
# per-actor bookkeeping dict that ProgressionService.award_post_combat_xp() and
# RecruitmentService read after combat. Nothing in it ever influences a decision: it is
# read-only accounting written during the fight and consumed once at resolve.
#
# WHY A SEPARATE FILE FROM THE TWO TURN SERVICES. The primitives have TWO callers after this
# slice — CombatTurnActionService (melee: the offensive damage/kills/fear_inflicted rows, and
# the kill ripple's support credits) and this file's own accumulate_turn(). A helper used by
# two or more places has an owner (AGENTS.md), and duplicating it is banned. Filing the
# primitives on either turn service would make the other reach across for them.
#
# WHY core/combat/. echo_action_logs lives on EncounterContext, but EncounterContext is a
# state container, not a service, and its own header already points at FlowRuntime for the
# fold. The ledger is combat bookkeeping, so it files beside the Phase 6 combat siblings
# (CombatRoundEmotionService, CombatRoundObjectiveService, ...).
#
# CONTRACT (same as every Phase 6 sibling):
#   - Typed RefCounted. Explicit typed dependencies at construction — no autoloads, no service
#     locator, no reaching back into FlowRuntime.
#   - NO flow_machine. This class cannot transition state or rebuild a snapshot.
#   - Never calls SaveService and never sets flow_ctx.save_request. The pre-extraction blocks
#     requested no save and must not start: FlowRuntime._mark_save_requested() joins reasons
#     with "|", so a save queued here would glue its reason onto the next dispatch's string.
#   - Calls no controller. accumulate_turn() calls two DOMAIN services statically
#     (SanctumService.find_roster_echo, ProgressionService), exactly as the moved code did.
#
# CONSTRUCTOR DEPENDENCIES — deliberately TWO, not the usual three, following the
# LiveMovementContextService precedent from slice 6G. config_service is NOT taken because the
# moved body never reads it: the only config it needs (prog_cfg_block, birth_stats_block) is
# handed in by the caller, which is how the pre-extraction code worked. The three primitives
# need nothing at all and are therefore STATIC.
#
# WHAT IT TOUCHES — the complete read/write set, verified line by line:
#   READS   actor["faction"], actor["id"], actor["_support_tally"];
#           ectx.last_round_results (only .back(), only its "action_type" and "is_kill"),
#           ectx.echo_action_logs;
#           flow_ctx.save_data (SanctumService.find_roster_echo, and
#           ProgressionService.get_realm_xp_multiplier reads it too), flow_ctx.realm_id;
#           prog_cfg_block / birth_stats_block, both passed in.
#   WRITES  ectx.echo_action_logs entries (melee_count / guard_count / kill_count /
#           total_count, and the four support fields on fold);
#           actor["_support_tally"] (credit adds, fold ERASES it — always, even for
#           non-echo actors, so a stale tally can never double-count next turn);
#           the ROSTER echo dict and the live actor dict, through
#           ProgressionService.apply_mid_combat_kill_xp() — this is the one place in this file
#           that writes save data, and it does so through the progression domain service, not
#           directly, exactly as before the move.
#   NOT TOUCHED  combat_state, flow_ctx.save_request, any snapshot, any RNG.
#
# DETERMINISM. No RNG and no OS time; `t` is injected. No dispatch is added or removed (the
# retreat roll's seed embeds the sim tick) and no round counter is touched (the theft roll's
# seed embeds the round counter).
#
# NAMING. The three primitives lost their underscore prefix because they are now called across
# a class boundary (new_entry / credit_support_tally / fold_support_tally); their bodies are
# byte-identical. accumulate_turn() is new only as a name — its body is the two moved blocks
# in their original order.
#
# NO SHIM WAS LEFT ON FlowRuntime (AGENTS.md #20). The four reflection call sites in
# tests/CombatSupportLedgerTests.gd were rewritten in this same change.
#
# DEFECT NOTES — found during extraction, reported and deliberately NOT fixed here:
#   1. (register D48, FIXED) accumulate_turn()'s PROG-003 half now checks that the back() entry
#      of last_round_results carries this actor's source_id, matching the last_actor_action
#      stamp in FlowRuntime that reads the same entry. The check passes on every path that
#      exists today; it is there so the two readers cannot drift apart.
#   2. new_entry() is the canonical default, yet the two callers still write the
#      `if not has(id): logs[id] = new_entry()` shape by hand at four sites. A single
#      `ensure_entry(ectx, id)` would remove all four, but that is a (small) restructure, so it
#      is reported rather than taken.
#   3. fold_support_tally() erases the tally for non-echo actors without ever reading it, so
#      support work done by an ally or spirit actor is silently discarded. Pre-existing and
#      deliberate (support metrics are documented as an echo-only signal); recorded because the
#      erase and the gate are easy to misread as a bug.

class_name ContributionLedgerService
extends RefCounted

var flow_ctx: FlowContext
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	logger = _logger


## S14a: canonical default entry for EncounterContext.echo_action_logs.
## Field name kept for compatibility — ProgressionService.award_post_combat_xp() reads this
## Dictionary by echo_id (PROG-003). Entries now exist for ALL combat factions (echo/enemy/
## spirit/ally) so the offensive contribution ledger (damage_dealt/damage_taken/kills) can
## be attributed to any actor; melee_count/guard_count/kill_count/total_count remain
## echo-only, populated exclusively by the pre-existing PROG-003 accumulator block.
## S14b (Tier 2 — support/defensive attribution): five additive fields, all default 0.
##   - guards_granted / morale_given / fear_relieved / support_actions are SUPPORT metrics,
##     echo-gated (populated only for echo-faction acting actors via the _support_tally fold
##     in accumulate_turn() below). morale_given/fear_relieved are EFFECTIVE post-clamp points
##     delivered to ALLIES (self-effects excluded).
##   - fear_inflicted is an OFFENSIVE metric (fear dealt to whoever the actor hits),
##     all-faction, written directly at the per-hit fear choke (mirrors damage_dealt).
static func new_entry() -> Dictionary:
	return {
		"melee_count":  0,
		"guard_count":  0,
		"kill_count":   0,
		"total_count":  0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"kills":        0,
		# S14b Tier 2 — support/defensive (echo-gated) + offensive fear (all-faction)
		"guards_granted":  0,
		"morale_given":    0,
		"fear_relieved":   0,
		"support_actions": 0,
		"fear_inflicted":  0,
	}


## S14b Tier 2: accumulate a support metric onto the acting actor's transient _support_tally
## dict (folded into echo_action_logs once per turn by accumulate_turn() below, then erased).
## Additive, read-only bookkeeping — never influences a decision. amount == 0 is a no-op.
static func credit_support_tally(a: Dictionary, field: String, amount: int) -> void:
	if amount == 0:
		return
	var st: Dictionary = a.get("_support_tally", {})
	st[field] = int(st.get(field, 0)) + amount
	a["_support_tally"] = st


## S14b Tier 2: merge the acting actor's transient _support_tally into echo_action_logs and
## clear it. Echo-gated (support fields are an echo-only signal, mirroring PROG-003); the tally
## is ALWAYS erased so a stale tally can never double-count on the actor's next turn.
static func fold_support_tally(actor: Dictionary, ectx: EncounterContext) -> void:
	var st_v: Variant = actor.get("_support_tally", {})
	if not (st_v is Dictionary) or (st_v as Dictionary).is_empty():
		return
	if str(actor.get("faction", "")) == "echo":
		var st: Dictionary = st_v
		var aid: String = str(actor.get("id", ""))
		if not ectx.echo_action_logs.has(aid):
			ectx.echo_action_logs[aid] = new_entry()
		var slog: Dictionary = ectx.echo_action_logs[aid]
		slog["guards_granted"]  = int(slog.get("guards_granted", 0))  + int(st.get("guards_granted", 0))
		slog["morale_given"]    = int(slog.get("morale_given", 0))    + int(st.get("morale_given", 0))
		slog["fear_relieved"]   = int(slog.get("fear_relieved", 0))   + int(st.get("fear_relieved", 0))
		slog["support_actions"] = int(slog.get("support_actions", 0)) + int(st.get("support_actions", 0))
	actor.erase("_support_tally")


## The per-turn ledger accumulation, run once per activation from FlowRuntime._resolve_next_actor
## AFTER the keeper-intro rewind check and BEFORE current_actor_index is advanced. Two blocks
## in their original order and with their original gates:
##   1. PROG-003 — echo-only action counts (melee/guard/kill/total) taken from the entry the
##      activation just appended, plus the immediate mid-combat kill XP award.
##   2. S14b Tier 2 — fold the acting actor's transient _support_tally into the ledger and
##      erase it.
## Order is load-bearing: the fold's `if not has(aid)` relies on block 1 having already created
## the entry for an echo actor, so a fold-first version would build the entry with a different
## set of fields populated first. Behaviourally identical today, but the order is preserved
## rather than reasoned about.
func accumulate_turn(
	actor: Dictionary,
	ectx: EncounterContext,
	prog_cfg_block: Dictionary,
	birth_stats_block: Dictionary,
	t: int
) -> void:
	# PROG-003: accumulate echo action log for XP virtue multiplier at resolve.
	# Only echo-faction actors contribute. Accumulated across all rounds.
	# Register D48: the back() entry is credited to this actor, so it must BE this actor's.
	# Every path in CombatTurnActionService appends exactly one entry per activation, so the
	# check passes today — it is here because the last_actor_action stamp in
	# FlowRuntime._resolve_next_actor reads the same back() entry and already compares
	# source_id. Two neighbouring readers of one entry now apply one rule.
	var eid: String = str(actor.get("id", ""))
	if str(actor.get("faction", "")) == "echo" and not ectx.last_round_results.is_empty() \
			and str((ectx.last_round_results.back() as Dictionary).get("source_id", "")) == eid:
		var last_res: Dictionary = ectx.last_round_results.back()
		if not ectx.echo_action_logs.has(eid):
			ectx.echo_action_logs[eid] = new_entry()
		var alog: Dictionary = ectx.echo_action_logs[eid]
		match str(last_res.get("action_type", "")):
			"melee_attack":
				alog["melee_count"] += 1
				alog["total_count"] += 1
				if bool(last_res.get("is_kill", false)):
					alog["kill_count"] += 1
					# XP tuning: kill XP applied immediately for mid-combat stat bump.
					var roster_echo: Dictionary = SanctumService.find_roster_echo(flow_ctx.save_data, str(actor.get("id", "")))
					if not roster_echo.is_empty():
						ProgressionService.apply_mid_combat_kill_xp(
							roster_echo, actor, prog_cfg_block, birth_stats_block,
							# V2-INFRA-003 Phase 6 Slice 6F: was
							# _progression_controller().get_realm_xp_multiplier() — a
							# controller-to-controller call that blocked this function from ever
							# joining a CombatController. Now a static on the progression domain
							# service. The three arguments are the same values the controller
							# read for itself: prog_cfg_block IS
							# config_service.get_balance().data.progression, read once at the top
							# of this function from the same immutable balance dict.
							ProgressionService.get_realm_xp_multiplier(
								str(flow_ctx.realm_id), flow_ctx.save_data, prog_cfg_block
							), logger, t
						)
			"actor.guard":
				alog["guard_count"] += 1
				alog["total_count"] += 1
			"actor.move", "actor.idle", "actor.refuse":
				alog["total_count"] += 1

	# S14b Tier 2: fold this actor's transient support tally into the contribution ledger.
	# Single write path for support fields (ActorStateMachine + kill ripple/momentum all
	# accumulate onto actor["_support_tally"] during this turn).
	fold_support_tally(actor, ectx)
