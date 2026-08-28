# res://core/combat/CombatRoundGuideSpiritService.gd
# V2-INFRA-003 Phase 6 Slice 6C: the GUIDE_SPIRIT escort/skittish OBJECTIVE-AUTHORITY phase,
# extracted verbatim out of core/runtime/FlowRuntime.gd::_end_round (the block that sat at
# :2765-:2994, 230 lines).
#
# CONTRACT (identical to CombatRoundEmotionService and CombatRoundSpawnService, the two
# siblings already built from this same function in slices 6A and 6B):
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
# LOCATION — core/combat/, beside CombatRoundEmotionService, CombatRoundSpawnService and
# ShrineService, the other per-round combat consequence helpers _end_round calls. NOT
# core/movement/: that directory already holds GuideSpiritActivationService, and the two are
# deliberately on opposite sides of a boundary that service documents about itself —
# "This service owns HOW the spirit moves, NEVER whether the objective advances. Escort-radius
# checks, the escort-started latch, the skittish radius, the destination-reached /
# guide_protect_counter decisions and every bark are OBJECTIVE authority owned by the caller."
# THIS file is that caller. It is the objective-authority half; it decides should_move, latches,
# counters and barks, and delegates every actual step to GuideSpiritActivationService. Putting
# the two in one file would collapse the boundary the movement slice was built around.
#
# WHAT IT TOUCHES — the complete read/write set, verified line by line rather than assumed:
#
#   READS
#     ectx.resolution_mode                     mode gate
#     ectx.actors                              is_dead, faction, is_spirit, id, grid_pos
#     ectx.combat_state["spirit_id"]
#     ectx.combat_state["objective_params"]     escort_radius, skittish_radius
#     ectx.combat_state["guide_mode"]           "escort" | "protect" (default "protect")
#     ectx.combat_state["spirit_joins_battle"]
#     ectx.combat_state["escort_started"]
#     ectx.combat_state["destination_reached"]
#     ectx.combat_state["destination_col"] / ["destination_row"]
#     ectx.combat_state["_spirit_killed_barked"] / ["_spirit_greeted"]
#     ectx.combat_state["guide_protect_counter"]
#     `prepared`                               the movement-activation context, built by the
#                                              caller (see THE ONE INJECTED DEPENDENCY below)
#
#   WRITES
#     combat_state["_spirit_killed_barked"]     once-per-encounter spirit-death bark guard
#     combat_state["_spirit_greeted"]           once-per-encounter first-adjacency bark guard
#     combat_state["escort_started"]            escort latch, set once and never cleared
#     combat_state["destination_reached"]       escort win latch
#     combat_state["guide_protect_counter"]     protect-hold accumulator (never resets)
#     spirit.grid_pos                           via GridService.assign_grid_pos()
#     spirit.current_hp / is_dead / death_round / is_ko
#                                              via LiveHazardOutcomeService.apply()
#     spirit._bark_line / _bark_context / _bark_tier
#                                              via NarrativeVoiceService.fire_spirit_bark()
#     ectx.round_bark_events                    APPENDED by fire_spirit_bark — the coupling
#                                              slice 6A found the expensive way. Confirmed
#                                              present here: four bark sites (spirit_killed,
#                                              spirit_first_adjacency, spirit_escort_start,
#                                              spirit_guide_win).
#     five logger lines (combat.guide.no_route x2, combat.guide.escort,
#     combat.guide.skittish, combat.guide.protect_hold)
#
#   NOT TOUCHED  save data (never read, never written — the one save read the block used to
#   reach, flow_ctx.save_data via LiveMovementContextService._live_combat_known_hazards(),
#   now happens in the caller
#   before this method runs), ectx.last_round_results, ectx.final_snapshot,
#   flow_ctx.flow_machine, flow_ctx.last_snapshot. flow_ctx is used for exactly one thing:
#   handing it to NarrativeVoiceService in _voice_service().
#
# DETERMINISM. Nothing here draws RNG — confirmed rather than assumed: the block contains no
# randf/randi/RandomNumberGenerator/campaign_seed reference, and GuideSpiritActivationService
# is documented and verified pure ("No RNG, no OS time, no mutation of inputs"). The only RNG
# left in _end_round is the PROTECT theft roll, which runs AFTER this phase and whose seed path
# embeds the round counter. All guide-spirit randomness is upstream, in EncounterSetupService.setup().
# No dispatch is added or removed (the retreat roll's seed path embeds the sim tick), and the
# round-counter increment stays in _end_round, untouched.
#
# ORDERING IS LOAD-BEARING and unchanged: emotion tick -> RECOVER -> ENDURE -> GUIDE_SPIRIT ->
# PROTECT theft. Inside the phase, the protect-hold counter still runs AFTER skittish movement
# so proximity reflects end-of-round positions, as its own comment requires.
#
# THE ONE INJECTED DEPENDENCY, and why it is a parameter rather than a call.
# The block called FlowRuntime._prepare_guide_spirit_activation_context() twice (once per
# branch, and the branches are mutually exclusive, so at most once per round). That helper
# transitively depends on eight further helpers — _movement_rect_walkable,
# _movement_actor_facts, _movement_occupancy, _movement_relationships,
# _movement_pressure_snapshot, _movement_objective_actor, _movement_factual_role and
# _live_combat_known_hazards (which reads flow_ctx.save_data) — and those are SHARED with the
# ordinary per-actor activation path. Duplicating them is banned (AGENTS.md #19). So the
# prepared context is built by the caller and passed in.
# V2-INFRA-003 Phase 6 Slice 6G UPDATE: that whole family has since moved off FlowRuntime onto
# core/movement/LiveMovementContextService.gd, where the entry point is the public
# prepare_guide_spirit_activation_context(). The injection contract here is unchanged — the
# caller still builds the context and passes it in.
#
# To keep the GATE from being duplicated at the call site, the gate lives HERE, as the static
# needs_activation_context(). FlowRuntime asks this class whether the context is needed, and
# only then pays for it — so the preparation stays exactly as lazy as it was, and the PURSUE
# full-grid flood-fill cost is not newly incurred in any mode that did not already pay it.
#
# HOISTING THE PREPARATION IS BEHAVIOUR-NEUTRAL, verified rather than assumed. Between the top
# of this phase and the two original call sites, the block writes only _spirit_greeted,
# _spirit_killed_barked and escort_started, plus bark fields on the spirit dict. Nothing it
# writes before those points is an input to the preparation: the preparation reads
# spirit.grid_pos (not yet moved), ectx.actors, ectx.terrain, and — through
# _movement_pressure_snapshot / _movement_objective_actor / _movement_factual_role —
# combat_state.guide_mode, guide_protect_counter, objective_params, spirit_id,
# recover_holder_id, totem_carrier_id and the RECOVER/PROTECT/PURSUE counters. None of those
# is written by this phase before the activation, and guide_protect_counter is incremented
# only at the very end. The activation_id it stamps embeds `t`, which is the same value.
#
# NOTHING WAS FIXED. Story V2-COMBAT-003 owns guide-spirit behaviour; this slice moves code and
# changes none of it. Defects observed and deliberately left in place are recorded in the slice
# writeup, not patched here.

class_name CombatRoundGuideSpiritService
extends RefCounted

const GuideSpiritActivationServiceScript := preload("res://core/movement/GuideSpiritActivationService.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## Builds a fresh NarrativeVoiceService, mirroring FlowRuntime._voice_service() — the same
## per-call construction pattern CombatRoundEmotionService, VowConsequenceService and
## BondConsequenceService already use. Cheap RefCounted. NarrativeVoiceService is the real
## owner of bark selection, so nothing is duplicated here (AGENTS.md #19).
func _voice_service() -> NarrativeVoiceService:
	return NarrativeVoiceService.new(flow_ctx, config_service, logger)


## THE GATE, owned here so the call site cannot drift from the branch conditions below.
## True exactly when apply_guide_spirit_round() will reach a GuideSpiritActivationService
## activation this round, i.e. when the pre-extraction code would have called
## LiveMovementContextService.prepare_guide_spirit_activation_context() (V2-INFRA-003 Slice 6G;
## it was FlowRuntime._prepare_guide_spirit_activation_context() before that): GUIDE_SPIRIT mode, a living spirit
## on the roster, a recognised guide_mode, and a spirit that has NOT joined the battle.
## A joined spirit is an ordinary combatant and goes through the ordinary activation path —
## GuideSpiritActivationService REFUSES it by contract.
static func needs_activation_context(ectx: EncounterContext) -> bool:
	if ectx == null:
		return false
	if ectx.resolution_mode != EncounterResolutionModes.GUIDE_SPIRIT:
		return false
	var combat_state: Dictionary = ectx.combat_state
	if bool(combat_state.get("spirit_joins_battle", false)):
		return false
	var spirit: Dictionary = EncounterContext.find_actor_by_id(
		ectx.actors, str(combat_state.get("spirit_id", "")))
	if spirit.is_empty() or bool(spirit.get("is_dead", false)):
		return false
	var guide_mode: String = str(combat_state.get("guide_mode", "protect"))
	if guide_mode != "escort" and guide_mode != "protect":
		# D16: only "escort" and "protect" are ever written today. Any other value disables the
		# whole GUIDE_SPIRIT phase, so it must be visible rather than silent.
		push_warning("GUIDE_SPIRIT: unknown guide_mode \"%s\" — objective phase disabled" % guide_mode)
		return false
	return true


## The GUIDE_SPIRIT objective phase, run once per round from _end_round AFTER the ENDURE wave
## spawn and BEFORE the PROTECT theft roll. The mode gate lives here rather than at the call
## site — COMBAT / PURIFY_SHRINE / RECOVER / PROTECT / ENDURE / PURSUE return immediately and
## are byte-identical.
##
## `round` is passed in rather than re-read so the five log lines and the two activation_id
## strings carry the exact value _end_round logged in combat.round_end for the same round.
## `prepared` is the FlowRuntime-built movement activation context; pass {} when
## needs_activation_context() is false — every branch that consumes it is then unreachable,
## and the `valid` guard below is the same guard the pre-extraction code used.
func apply_guide_spirit_round(
		ectx: EncounterContext,
		round: int,
		prepared: Dictionary,
		t: int) -> void:
	var combat_state: Dictionary = ectx.combat_state

	# V2-STAGE-004 P3c — GUIDE_SPIRIT: escort/skittish movement + first-adjacency/kill barks.
	# Gate: GUIDE_SPIRIT only; COMBAT / PURIFY_SHRINE / RECOVER / PROTECT / ENDURE / PURSUE
	# are byte-identical. Deterministic — no randf()/OS time; away-step and toward-step both
	# use fixed tiebreak rules over the walkable set.
	if ectx.resolution_mode == EncounterResolutionModes.GUIDE_SPIRIT:
		var _gs_obj: Dictionary = combat_state.get("objective_params", {})
		var _gs_spirit_id: String = str(combat_state.get("spirit_id", ""))
		var _gs_spirit: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, _gs_spirit_id)

		if _gs_spirit.is_empty() or bool(_gs_spirit.get("is_dead", false)):
			# Spirit is dead (or missing from the roster) — fire spirit_killed once; end
			# condition handles the defeat branch. No movement possible.
			if not bool(combat_state.get("_spirit_killed_barked", false)):
				combat_state["_spirit_killed_barked"] = true
				if not _gs_spirit.is_empty():
					_voice_service().fire_spirit_bark(_gs_spirit, "spirit_killed", t)
		else:
			var _gs_spirit_pos: Dictionary = _gs_spirit.get("grid_pos", {})

			# First-adjacency bark (both escort + protect modes): fires once, the first round
			# any living echo is Chebyshev-adjacent to the living spirit.
			if not bool(combat_state.get("_spirit_greeted", false)):
				var _gs_any_adjacent: bool = false
				for _gs_e in ectx.actors:
					if not (_gs_e is Dictionary): continue
					if bool(_gs_e.get("is_dead", false)): continue
					if str(_gs_e.get("faction", "")) != "echo": continue
					# A joined spirit has faction "echo" + is_spirit true — never count it as a
					# guiding echo (else it self-greets/self-escorts). Same exclusion the
					# directive-injection and party-wipe (all_echoes_dead) checks already use.
					if bool(_gs_e.get("is_spirit", false)): continue
					if GridService.is_adjacent(_gs_e.get("grid_pos", {}), _gs_spirit_pos):
						_gs_any_adjacent = true
						break
				if _gs_any_adjacent:
					combat_state["_spirit_greeted"] = true
					_voice_service().fire_spirit_bark(_gs_spirit, "spirit_first_adjacency", t)

			var _gs_mode: String = str(combat_state.get("guide_mode", "protect"))

			if _gs_mode == "escort":
				var _gs_escort_radius: int = int(_gs_obj.get("escort_radius", 2))

				# Escort start: first round any living echo is adjacent to the spirit.
				if not bool(combat_state.get("escort_started", false)):
					var _gs_start_adjacent: bool = false
					for _gs_e2 in ectx.actors:
						if not (_gs_e2 is Dictionary): continue
						if bool(_gs_e2.get("is_dead", false)): continue
						if str(_gs_e2.get("faction", "")) != "echo": continue
						if bool(_gs_e2.get("is_spirit", false)): continue  # never latch on the spirit itself
						if GridService.is_adjacent(_gs_e2.get("grid_pos", {}), _gs_spirit_pos):
							_gs_start_adjacent = true
							break
					if _gs_start_adjacent:
						combat_state["escort_started"] = true
						_voice_service().fire_spirit_bark(_gs_spirit, "spirit_escort_start", t)

				var _gs_escorted: bool = false
				if bool(combat_state.get("escort_started", false)) \
						and not bool(combat_state.get("destination_reached", false)):
					for _gs_e3 in ectx.actors:
						if not (_gs_e3 is Dictionary): continue
						if bool(_gs_e3.get("is_dead", false)): continue
						if str(_gs_e3.get("faction", "")) != "echo": continue
						if bool(_gs_e3.get("is_spirit", false)): continue
						if GridService.chebyshev_distance(_gs_e3.get("grid_pos", {}), _gs_spirit_pos) \
								<= _gs_escort_radius:
							_gs_escorted = true
							break
				var _gs_dest: Dictionary = {
					"col": int(combat_state.get("destination_col", -1)),
					"row": int(combat_state.get("destination_row", -1)),
				}
				var _gs_should_move: bool = bool(combat_state.get("escort_started", false)) \
					and _gs_escorted \
					and not bool(combat_state.get("destination_reached", false))
				if not bool(combat_state.get("spirit_joins_battle", false)):
					var _gs_goal_id: String = "guide.escort"
					if bool(combat_state.get("destination_reached", false)):
						_gs_goal_id = "guide.escort_arrived"
					elif not _gs_should_move:
						_gs_goal_id = "guide.escort_caller_gated"
					var _gs_prepared: Dictionary = prepared
					if bool(_gs_prepared.get("valid", false)):
						var _gs_result: Dictionary = GuideSpiritActivationServiceScript.activate_spirit(
							_gs_spirit,
							_gs_prepared["context"] as Dictionary,
							{
								"mode": "escort",
								"joined": false,
								"should_move": _gs_should_move,
								"destination": _gs_dest,
								"activation_id": "guide.%s.%d" % [_gs_spirit_id, round],
								"goal_id": _gs_goal_id,
								"option_id": "guide.escort.step",
								"mover_ko_only": false,
							},
							_gs_prepared["hazard_ctx"] as Dictionary,
							_gs_prepared["capacity_cfg"] as Dictionary
						)
						var _gs_actual: Array = _gs_result.get("actual_traversed_cells", []) as Array
						if not _gs_actual.is_empty():
							GridService.assign_grid_pos(_gs_spirit,
								int((_gs_result.get("final_destination", {}) as Dictionary).get("col", 0)),
								int((_gs_result.get("final_destination", {}) as Dictionary).get("row", 0)))
							_gs_spirit_pos = _gs_spirit.get("grid_pos", {})
						LiveHazardOutcomeService.apply(_gs_spirit, _gs_result, t, logger, false)
						LiveHazardOutcomeService.apply(_gs_spirit, _gs_result, t, logger, true)
						if _gs_should_move and str(_gs_result.get("stop_reason", "")) == "no_route":
							logger.info(t, "combat.guide.no_route", "GUIDE_SPIRIT escort route unavailable", {
								"round": round,
								"spirit_id": _gs_spirit_id,
								"reason": "unreachable",
								"goal_id": str(_gs_result.get("goal_id", "")),
							})
				# D92: the escort win belongs to the party, never to the spirit itself. A joined
				# spirit has faction "echo" + is_spirit true, so without these two guards a spirit
				# standing on the destination delivers itself — even with every real echo dead,
				# which scores a party wipe as a victory. Same pair the movement gate above uses:
				# the escort must have started, and a living non-spirit echo must be within
				# escort_radius this round. Both loops that compute them skip is_spirit actors.
				if bool(combat_state.get("escort_started", false)) \
						and _gs_escorted \
						and not bool(_gs_spirit.get("is_dead", false)) \
						and int(_gs_spirit_pos.get("col", -999)) == int(combat_state.get("destination_col", -1)) \
						and int(_gs_spirit_pos.get("row", -999)) == int(combat_state.get("destination_row", -1)):
					combat_state["destination_reached"] = true
					_voice_service().fire_spirit_bark(_gs_spirit, "spirit_guide_win", t)
				logger.debug(t, "combat.guide.escort", "GUIDE_SPIRIT escort progress", {
					"round":              round,
					"escorted":           _gs_escorted,
					"escort_started":     bool(combat_state.get("escort_started", false)),
					"destination_reached": bool(combat_state.get("destination_reached", false)),
					"spirit_pos":         _gs_spirit_pos,
				})

			elif _gs_mode == "protect":
				var _gs_skittish_radius: int = int(_gs_obj.get("skittish_radius", 3))
				var _gs_enemy_near: bool = false
				var _gs_nearest_enemy: Dictionary = {}
				var _gs_nearest_dist: int = 999999
				for _gs_en in ectx.actors:
					if not (_gs_en is Dictionary): continue
					if bool(_gs_en.get("is_dead", false)): continue
					if str(_gs_en.get("faction", "")) != "enemy": continue
					var _gs_d: int = GridService.chebyshev_distance(_gs_en.get("grid_pos", {}), _gs_spirit_pos)
					if _gs_d <= _gs_skittish_radius:
						_gs_enemy_near = true
					if _gs_d < _gs_nearest_dist \
							or (_gs_d == _gs_nearest_dist and (_gs_nearest_enemy.is_empty() \
								or str(_gs_en.get("id", "")) < str(_gs_nearest_enemy.get("id", "")))):
						_gs_nearest_dist = _gs_d
						_gs_nearest_enemy = _gs_en
				var _gs_echo_adjacent: bool = false
				for _gs_e4 in ectx.actors:
					if not (_gs_e4 is Dictionary): continue
					if bool(_gs_e4.get("is_dead", false)): continue
					if str(_gs_e4.get("faction", "")) != "echo": continue
					if bool(_gs_e4.get("is_spirit", false)): continue
					if GridService.is_adjacent(_gs_e4.get("grid_pos", {}), _gs_spirit_pos):
						_gs_echo_adjacent = true
						break
				var _gs_protect_should_move: bool = _gs_enemy_near \
					and not _gs_echo_adjacent \
					and not _gs_nearest_enemy.is_empty()
				if not bool(combat_state.get("spirit_joins_battle", false)):
					var _gs_protect_goal_id: String = "guide.protect"
					if not _gs_protect_should_move:
						_gs_protect_goal_id = "guide.protect_caller_gated"
					var _gs_prepared_p: Dictionary = prepared
					if bool(_gs_prepared_p.get("valid", false)):
						var _gs_threats: Array = []
						if not _gs_nearest_enemy.is_empty():
							_gs_threats.append((_gs_nearest_enemy.get("grid_pos", {}) as Dictionary).duplicate(true))
						var _gs_result_p: Dictionary = GuideSpiritActivationServiceScript.activate_spirit(
							_gs_spirit,
							_gs_prepared_p["context"] as Dictionary,
							{
								"mode": "protect",
								"joined": false,
								"should_move": _gs_protect_should_move,
								"threats": _gs_threats,
								"activation_id": "guide.%s.%d" % [_gs_spirit_id, round],
								"goal_id": _gs_protect_goal_id,
								"option_id": "guide.protect.step",
								"mover_ko_only": false,
							},
							_gs_prepared_p["hazard_ctx"] as Dictionary,
							_gs_prepared_p["capacity_cfg"] as Dictionary
						)
						var _gs_actual_p: Array = _gs_result_p.get("actual_traversed_cells", []) as Array
						if not _gs_actual_p.is_empty():
							GridService.assign_grid_pos(_gs_spirit,
								int((_gs_result_p.get("final_destination", {}) as Dictionary).get("col", 0)),
								int((_gs_result_p.get("final_destination", {}) as Dictionary).get("row", 0)))
							# D15: assign_grid_pos replaces the grid_pos dict, so the captured
							# reference is stale after a move. Nothing below reads it today (the
							# log and the win counter both re-read the actor), so this refresh
							# changes no behaviour. It keeps the trap closed for the next edit.
							_gs_spirit_pos = _gs_spirit.get("grid_pos", {})
						LiveHazardOutcomeService.apply(_gs_spirit, _gs_result_p, t, logger, false)
						LiveHazardOutcomeService.apply(_gs_spirit, _gs_result_p, t, logger, true)
						if _gs_protect_should_move and str(_gs_result_p.get("stop_reason", "")) == "no_route":
							logger.info(t, "combat.guide.no_route", "GUIDE_SPIRIT protect route unavailable", {
								"round": round,
								"spirit_id": _gs_spirit_id,
								"reason": "unreachable",
								"goal_id": str(_gs_result_p.get("goal_id", "")),
							})
				logger.debug(t, "combat.guide.skittish", "GUIDE_SPIRIT skittish check", {
					"round":       round,
					"enemy_near":  _gs_enemy_near,
					"echo_adjacent": _gs_echo_adjacent,
					"spirit_pos":  _gs_spirit.get("grid_pos", {}),
				})

				# V2-STAGE-004 P3c "guard to count": guide_protect_counter advances only on rounds
				# where a living echo is within escort_radius (Chebyshev) of the living spirit — the
				# party must actually reach the spirit to make progress toward the protect win. Unlike
				# PROTECT's protect_counter, this NEVER resets when no echo is near (accumulates).
				# Runs AFTER skittish movement so proximity reflects end-of-round positions.
				var _gs_escort_radius_p: int = int(_gs_obj.get("escort_radius", 2))
				var _gs_spirit_pos_final: Dictionary = _gs_spirit.get("grid_pos", {})
				var _gs_guard_near: bool = false
				for _gs_e5 in ectx.actors:
					if not (_gs_e5 is Dictionary): continue
					if bool(_gs_e5.get("is_dead", false)): continue
					if str(_gs_e5.get("faction", "")) != "echo": continue
					if bool(_gs_e5.get("is_spirit", false)): continue
					if GridService.chebyshev_distance(_gs_e5.get("grid_pos", {}), _gs_spirit_pos_final) \
							<= _gs_escort_radius_p:
						_gs_guard_near = true
						break
				if not bool(_gs_spirit.get("is_dead", false)) and _gs_guard_near:
					combat_state["guide_protect_counter"] = int(combat_state.get("guide_protect_counter", 0)) + 1
				logger.debug(t, "combat.guide.protect_hold", "GUIDE_SPIRIT protect_hold updated", {
					"round":                 round,
					"guide_protect_counter": int(combat_state.get("guide_protect_counter", 0)),
					"near":                  _gs_guard_near,
				})
