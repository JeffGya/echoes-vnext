# res://core/combat/CombatRoundObjectiveService.gd
# V2-INFRA-003 Phase 6 Slice 6D: the three PROTECT / PURSUE OBJECTIVE-PROGRESS phases,
# extracted verbatim out of core/runtime/FlowRuntime.gd::_end_round (the theft block that sat
# at :2797-:2876, the guard-proximity block at :2878-:2919, and the PURSUE contain block at
# :2921-:2948 — 153 lines including the two separating blank lines).
#
# CONTRACT (identical to CombatRoundEmotionService / CombatRoundSpawnService /
# CombatRoundGuideSpiritService, the three siblings already built from this same function in
# slices 6A, 6B and 6C):
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly. All three bodies request NO save at all, which is the
#     pre-extraction behaviour and must stay that way: FlowRuntime._mark_save_requested()
#     joins reasons with "|", so a save queued here would glue its reason onto the next
#     dispatch's string.
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot.
#   - Same constructor signature (flow_ctx, config_service, logger) as every sibling service.
#
# LOCATION AND REMIT — why a new sibling rather than more methods on CombatRoundSpawnService,
# which already owns the RECOVER hold counter (the fourth member of this same adjacency-counter
# family). The decision was made from what that file says about itself, not from convenience:
#
#   The four Phase 6 services decompose _end_round BY PHASE, and for the objective phases that
#   means BY RESOLUTION MODE, not by mechanism. CombatRoundSpawnService owns RECOVER and ENDURE;
#   CombatRoundGuideSpiritService owns GUIDE_SPIRIT; this file owns PROTECT and PURSUE. Its
#   header's own words are "the two MID-ROUND OBJECTIVE SPAWN phases", and both of its public
#   methods are named for their mode (apply_recover_round / apply_endure_wave_spawn). The hold
#   counter lives there because it is a sub-step of the RECOVER phase, in a fixed order with the
#   holder designation and the reinforcement spawn — not because that file claims counters as a
#   remit. Neither block moved here spawns anything, so filing them under "Spawn" would widen
#   that name past what it can carry.
#
#   The "one mechanism, two files" objection does not apply, because the mechanism is not in one
#   file today. Adjacency-gated, reset-on-leave counters are hand-written FOUR times, in three
#   different places: hold_counter (CombatRoundSpawnService), guide_protect_counter
#   (CombatRoundGuideSpiritService), and protect_counter + contain_counter (here, previously
#   FlowRuntime). There is no shared helper, so nothing is being split and nothing is being
#   duplicated — this slice consolidates two of the four for the first time. Extracting the
#   common shape into one helper is a BEHAVIOUR-ADJACENT change (the four differ in their
#   distance metric — Chebyshev-1 via is_adjacent for hold/contain, a configurable Chebyshev
#   radius for protect — in whether they log at debug or not, and in whether they reset), so it
#   is reported rather than attempted: see DEFECT NOTES below.
#
# WHAT IT TOUCHES — the complete read/write set, verified line by line rather than assumed:
#
#   READS
#     ectx.resolution_mode                      mode gate on all three methods
#     ectx.actors                               is_structure, is_dead, is_quarry, faction, id,
#                                               name, grid_pos
#     ectx.encounter_id                         theft RNG seed path only
#     ectx.combat_state["totem_stolen"]
#     ectx.combat_state["totem_carrier_id"]
#     ectx.combat_state["protect_counter"]
#     ectx.combat_state["contain_counter"]
#     flow_ctx.campaign_seed                    theft roll only, via get_rng() — null-guarded,
#                                               with a hash() fallback. BOTH branches preserved
#                                               exactly; the derive is not discarded.
#     flow_ctx.config_service                   get_balance() twice, read longhand down
#                                               data.combat.objective_modes.protect for
#                                               theft_chance, double_damage_mult (theft) and
#                                               protect_guard_radius (guard). NOTE this is
#                                               flow_ctx.config_service, NOT this service's own
#                                               config_service field, and it is null-guarded at
#                                               every use — both preserved exactly, because the
#                                               two can in principle differ.
#     `round`                                   passed in, not re-read, so the four log lines
#                                               carry the exact value _end_round logged in
#                                               combat.round_end for the same round. This also
#                                               makes the RNG seed path's round component the
#                                               same value it was before the move.
#
#   WRITES
#     ectx.combat_state["totem_stolen"]         set false on carrier-down recovery, true on a
#                                               successful theft roll
#     ectx.combat_state["totem_carrier_id"]
#     ectx.combat_state["protect_counter"]      +1 when guarded, hard 0 when not
#     ectx.combat_state["contain_counter"]      +1 when an echo is adjacent, hard 0 when not
#     carrier actor["_carrier_double_damage"]   false on recovery (only when the carrier dict is
#                                               still findable), true on theft
#     carrier actor["_double_damage_mult"]      written on theft only, from balance config
#     four logger lines (combat.protect.theft_cleared info, combat.protect.theft info,
#     combat.protect.guard debug, combat.pursue.contain debug)
#
#   NOT TOUCHED, checked rather than assumed: save data (never read, never written),
#   ectx.round_bark_events (the coupling slice 6A hit — these three phases fire no bark and
#   construct no NarrativeVoiceService), ectx.last_round_results, ectx.last_round_snapshot,
#   ectx.final_snapshot, ectx.combat_result, combat_state["round_counter"] (NOT re-read here and
#   NOT incremented — the increment stays in _end_round, which the theft seed path depends on),
#   flow_ctx.save_data, flow_ctx.last_snapshot and flow_ctx.flow_machine. flow_ctx is used for
#   exactly two things: flow_ctx.campaign_seed and flow_ctx.config_service.
#
#   INDIRECT CALLS, all verified pure and non-mutating: GridService.is_adjacent(),
#   GridService.chebyshev_distance(), EncounterContext.find_actor_by_id() (a linear id scan
#   returning the live dict or {}). None reads or writes save data; none draws RNG.
#
# DETERMINISM. This file holds the ONLY RNG left in _end_round: the PROTECT theft roll. Its seed
# path is "combat.theft.%s.%d" % [encounter_id, round] — reproduced character for character,
# with the same single randf() draw and no draw added, removed or reordered around it. Because
# the path embeds the round counter it is order-fragile, so the round-counter increment stays in
# _end_round untouched and `round` is passed in rather than re-read. No dispatch is added or
# removed anywhere (the retreat roll's seed path embeds the sim tick).
#
# ORDERING IS LOAD-BEARING and unchanged: emotion tick -> RECOVER -> ENDURE -> GUIDE_SPIRIT ->
# PROTECT theft -> PROTECT guard -> PURSUE contain -> check_end_condition. The three methods are
# separate rather than merged so that each keeps its own mode gate and its own verbatim body,
# exactly as the two blocks did; PROTECT guard must still run AFTER PROTECT theft in the same
# round, because check_end_condition reads protect_counter and totem_stolen together.
#
# NO NON-VERBATIM CHANGE. Unlike slice 6B, this slice introduces no ConfigService getter: the
# longhand data.combat.objective_modes.protect reads are MOVED, not copied, so no new copy is
# created. See DEFECT NOTES.
#
# DEFECT NOTES — found during extraction, reported and deliberately NOT fixed here (this slice
# is extraction only):
#   1. data.combat.objective_modes has no ConfigService owner. It is read longhand at four
#      sites: twice in the theft method below, once in the guard method below,
#      EncounterSetupService.gd:420 (was FlowEncounterState.gd:347, moved by slice 6I), and FlowRuntime.gd:2232. BehaviorArbiter.gd:1761/1788 read the
#      same subtree from an already-narrowed cfg dict. The pre-existing count is unchanged by
#      this move.
#   2. The adjacency-counter shape is written out four times (see LOCATION AND REMIT above).
#   3. On the carrier-down recovery path, "_carrier_double_damage" is only cleared when the
#      carrier dict is still present in ectx.actors. When the carrier has been REMOVED rather
#      than marked dead the flag is left set on the orphaned dict. Harmless today because the
#      combat spine never removes actors from ectx.actors, only marks is_dead — but the branch
#      is written as if it did. Preserved verbatim.
#   4. "_double_damage_mult" is written on theft but never cleared on recovery, unlike
#      "_carrier_double_damage". A once-carrier actor keeps a stale multiplier field for the
#      rest of the encounter; it is inert only because every consumer gates on
#      "_carrier_double_damage" first. Preserved verbatim.

class_name CombatRoundObjectiveService
extends RefCounted

const PursueEscapeServiceScript := preload("res://core/movement/PursueEscapeService.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## V2-STAGE-004 Distinctiveness §4-G: PROTECT theft phase, run once per round from _end_round
## AFTER the GUIDE_SPIRIT phase and BEFORE the guard-proximity counter. Two mutually exclusive
## branches: recovery (already stolen, carrier dead or gone -> clear the theft state) and the
## theft roll itself (not stolen, totem unguarded, a living non-structure enemy adjacent). The
## mode gate lives here rather than at the call site — COMBAT / PURIFY_SHRINE / RECOVER /
## ENDURE / GUIDE_SPIRIT / PURSUE return immediately and are byte-identical.
##
## THE ONLY RNG IN _end_round. Seed path "combat.theft.%s.%d" % [encounter_id, round], one
## randf() draw per qualifying round. `round` is the value passed in, so the path is identical
## to the pre-extraction one; the round-counter increment is deliberately left in _end_round.
func apply_protect_theft_round(ectx: EncounterContext, round: int, t: int) -> void:
	if ectx.resolution_mode != EncounterResolutionModes.PROTECT:
		return
	var combat_state: Dictionary = ectx.combat_state

	# Gate: PROTECT only. Locate the totem (first living is_structure actor).
	var _prot_totem: Dictionary = {}
	for _pt_a in ectx.actors:
		if _pt_a is Dictionary and bool(_pt_a.get("is_structure", false)) \
				and not bool(_pt_a.get("is_dead", false)):
			_prot_totem = _pt_a
			break
	if not _prot_totem.is_empty():
		var _pt_totem_pos: Dictionary = _prot_totem.get("grid_pos", {})
		# Recovery first: if stolen and carrier is dead/absent → clear theft state.
		if bool(combat_state.get("totem_stolen", false)):
			var _pt_carrier_id: String = str(combat_state.get("totem_carrier_id", ""))
			var _pt_carrier: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, _pt_carrier_id)
			var _pt_carrier_dead: bool = _pt_carrier.is_empty() or bool(_pt_carrier.get("is_dead", false))
			if _pt_carrier_dead:
				combat_state["totem_stolen"] = false
				combat_state["totem_carrier_id"] = ""
				if not _pt_carrier.is_empty():
					_pt_carrier["_carrier_double_damage"] = false
				logger.info(t, "combat.protect.theft_cleared", "PROTECT carrier down — theft cleared", {
					"round":       round,
					"carrier_id":  _pt_carrier_id,
				})
		# Theft roll: only when NOT already stolen.
		elif not bool(combat_state.get("totem_stolen", false)):
			# Determine if totem is guarded (any living echo adjacent to totem).
			var _pt_guarded: bool = false
			for _pt_echo in ectx.actors:
				if not (_pt_echo is Dictionary): continue
				if bool(_pt_echo.get("is_dead", false)): continue
				if str(_pt_echo.get("faction", "")) != "echo": continue
				if GridService.is_adjacent(_pt_echo.get("grid_pos", {}), _pt_totem_pos):
					_pt_guarded = true
					break
			if not _pt_guarded:
				# Find living enemy adjacent to totem with lowest id (deterministic).
				var _pt_adj_enemy: Dictionary = {}
				for _pt_en in ectx.actors:
					if not (_pt_en is Dictionary): continue
					if bool(_pt_en.get("is_dead", false)): continue
					if str(_pt_en.get("faction", "")) != "enemy": continue
					if bool(_pt_en.get("is_structure", false)): continue
					if GridService.is_adjacent(_pt_en.get("grid_pos", {}), _pt_totem_pos):
						if _pt_adj_enemy.is_empty() or \
								str(_pt_en.get("id", "")) < str(_pt_adj_enemy.get("id", "")):
							_pt_adj_enemy = _pt_en
				if not _pt_adj_enemy.is_empty():
					# Roll theft via CampaignSeed — one derive per round, append-only namespace.
					var _pt_encounter_id: String = str(ectx.encounter_id)
					var _pt_theft_rng: RandomNumberGenerator = RandomNumberGenerator.new()
					if flow_ctx.campaign_seed != null:
						_pt_theft_rng = flow_ctx.campaign_seed.get_rng(
							"combat.theft.%s.%d" % [_pt_encounter_id, round])
					else:
						_pt_theft_rng.seed = hash("combat.theft.%s.%d" % [_pt_encounter_id, round])
					# Read theft_chance from balance config.
					var _pt_bal: Dictionary = {}
					if flow_ctx.config_service != null:
						_pt_bal = flow_ctx.config_service.get_balance()
					var _pt_theft_chance: float = float(
						_pt_bal.get("data", {}).get("combat", {})
							.get("objective_modes", {})
							.get("protect", {})
							.get("theft_chance", 0.5))
					if _pt_theft_rng.randf() < _pt_theft_chance:
						combat_state["totem_stolen"]     = true
						combat_state["totem_carrier_id"] = str(_pt_adj_enemy.get("id", ""))
						_pt_adj_enemy["_carrier_double_damage"] = true
						_pt_adj_enemy["_double_damage_mult"] = float(
							_pt_bal.get("data", {}).get("combat", {})
								.get("objective_modes", {})
								.get("protect", {})
								.get("double_damage_mult", 2.0))
						logger.info(t, "combat.protect.theft", "PROTECT totem stolen!", {
							"round":       round,
							"carrier_id":  str(_pt_adj_enemy.get("id", "")),
							"carrier_name": str(_pt_adj_enemy.get("name", "")),
						})


## V2-STAGE-004 Distinctiveness §4-G2: PROTECT guard-proximity counter, run once per round from
## _end_round immediately AFTER apply_protect_theft_round(). protect_counter only advances on
## rounds where at least one living echo is within protect_guard_radius (Chebyshev) of the
## protected entity, and resets hard to 0 when unguarded — the same reset-on-leave semantics as
## RECOVER's hold_counter. Order relative to the theft phase is load-bearing:
## CombatState.check_end_condition() reads protect_counter and totem_stolen together, so the
## counter must see this round's theft outcome. The mode gate lives here rather than at the call
## site — every other resolution mode returns immediately and is byte-identical.
func apply_protect_guard_round(ectx: EncounterContext, round: int, t: int) -> void:
	if ectx.resolution_mode != EncounterResolutionModes.PROTECT:
		return
	var combat_state: Dictionary = ectx.combat_state

	var _pg_entity: Dictionary = {}
	for _pg_a in ectx.actors:
		if _pg_a is Dictionary and bool(_pg_a.get("is_structure", false)) \
				and not bool(_pg_a.get("is_dead", false)):
			_pg_entity = _pg_a
			break
	if not _pg_entity.is_empty():
		var _pg_entity_pos: Dictionary = _pg_entity.get("grid_pos", {})
		# Read guard radius from balance config (default 2).
		var _pg_bal: Dictionary = {}
		if flow_ctx.config_service != null:
			_pg_bal = flow_ctx.config_service.get_balance()
		var _pg_guard_radius: int = int(
			_pg_bal.get("data", {}).get("combat", {})
				.get("objective_modes", {})
				.get("protect", {})
				.get("protect_guard_radius", 2))
		# Check whether any living echo is within guard radius of the entity.
		var _pg_guarded: bool = false
		for _pg_echo in ectx.actors:
			if not (_pg_echo is Dictionary): continue
			if bool(_pg_echo.get("is_dead", false)): continue
			if str(_pg_echo.get("faction", "")) != "echo": continue
			if GridService.chebyshev_distance(_pg_echo.get("grid_pos", {}), _pg_entity_pos) \
					<= _pg_guard_radius:
				_pg_guarded = true
				break
		if _pg_guarded:
			combat_state["protect_counter"] = int(combat_state.get("protect_counter", 0)) + 1
		else:
			# Not guarded: reset to 0 (mirrors RECOVER hold_counter reset-on-leave semantics).
			combat_state["protect_counter"] = 0
		logger.debug(t, "combat.protect.guard", "PROTECT guard progress", {
			"round":           round,
			"protect_counter": int(combat_state.get("protect_counter", 0)),
			"guarded":         _pg_guarded,
		})


## V2-STAGE-004 P3b: PURSUE contain counter, run once per round from _end_round immediately
## AFTER apply_protect_guard_round() and BEFORE CombatState.check_end_condition(). Mirror of the
## RECOVER hold_counter pattern, measured against the quarry (first living is_quarry actor)
## rather than a structure. The mode gate lives here rather than at the call site — every other
## resolution mode returns immediately and is byte-identical.
func apply_pursue_contain_round(ectx: EncounterContext, round: int, t: int) -> void:
	if ectx.resolution_mode != EncounterResolutionModes.PURSUE:
		return
	var combat_state: Dictionary = ectx.combat_state

	var _quarry: Dictionary = {}
	for _qa in ectx.actors:
		if _qa is Dictionary and bool(_qa.get("is_quarry", false)) \
				and not bool(_qa.get("is_dead", false)):
			_quarry = _qa
			break
	if not _quarry.is_empty():
		var _quarry_pos: Dictionary = _quarry.get("grid_pos", {})
		var _any_adjacent: bool = false
		for _qe_a in ectx.actors:
			if not (_qe_a is Dictionary): continue
			if bool(_qe_a.get("is_dead", false)): continue
			if str(_qe_a.get("faction", "")) != "echo": continue
			if GridService.is_adjacent(_qe_a.get("grid_pos", {}), _quarry_pos):
				_any_adjacent = true
				break
		if _any_adjacent:
			combat_state["contain_counter"] = int(combat_state.get("contain_counter", 0)) + 1
		else:
			combat_state["contain_counter"] = 0
		logger.debug(t, "combat.pursue.contain", "PURSUE contain_counter updated", {
			"round":           round,
			"contain_counter": int(combat_state.get("contain_counter", 0)),
			"adjacent":        _any_adjacent,
		})


## V2-STAGE-004 P3b: PURSUE quarry edge-escape detection — the one objective-progress step in
## this file that runs ONCE PER TURN rather than once per round. Moved verbatim out of
## FlowRuntime._resolve_next_actor (:1754-:1772) in V2-INFRA-003 Phase 6 Slice 6H.
##
## WHY HERE, in a file whose other three methods are per-round. The four methods share a remit —
## PROTECT and PURSUE objective progress, gated by resolution mode, writing only combat_state
## counters and flags — and this one writes combat_state["quarry_escaped"], the flag
## CombatState.check_end_condition() reads two lines above contain_counter, which this file
## already owns. Filing it anywhere else would put the two halves of PURSUE progress in two
## files. The "Round" in the class name is the only thing that does not fit, and a rename would
## touch four call sites in _end_round for no behavioural gain; it is recorded instead.
##
## The mode gate stays INSIDE the condition rather than being lifted to an early return, because
## the pre-extraction block tested four things in one `if` and short-circuit order is preserved
## exactly: mode, is_quarry, not dead, not already escaped.
##
## `movement_board_cfg` is passed in — the terrain-aware board_cfg the caller already built via
## CombatTurnContextService — so no second copy of the terrain derivation is created
## (AGENTS.md #19). LiveMovementContextService is constructed per call for the rectangular
## walkable fallback, the same cheap-RefCounted pattern CombatRoundEmotionService uses for
## NarrativeVoiceService; it is a service, not a controller, so calling it is legal.
func apply_pursue_quarry_escape(
	actor: Dictionary,
	ectx: EncounterContext,
	movement_board_cfg: Dictionary,
	t: int
) -> void:
	var combat_state: Dictionary = ectx.combat_state
	# V2-STAGE-004 P3b: PURSUE — quarry edge escape detection.
	# Quarry's grid_pos is updated inside asm.advance_turn(); check after index is advanced.
	if ectx.resolution_mode == EncounterResolutionModes.PURSUE \
			and bool(actor.get("is_quarry", false)) \
			and not bool(actor.get("is_dead", false)) \
			and not bool(combat_state.get("quarry_escaped", false)):
		var _qe_bounds: Dictionary = {
			"w": int(movement_board_cfg.get("board_cols", 10)),
			"h": int(movement_board_cfg.get("board_rows", 10)),
		}
		var _qe_walkable: Dictionary = movement_board_cfg.get("walkable", {}) as Dictionary
		if _qe_walkable.is_empty():
			_qe_walkable = LiveMovementContextService.new(flow_ctx, logger).movement_rect_walkable(_qe_bounds)
		if PursueEscapeServiceScript.is_escaped(actor.get("grid_pos", {}), _qe_bounds, _qe_walkable):
			combat_state["quarry_escaped"] = true
			logger.info(t, "combat.pursue.escaped", "Quarry reached board edge", {
				"quarry_id": str(actor.get("id", "")),
				"grid_pos":  actor.get("grid_pos", {}),
			})
