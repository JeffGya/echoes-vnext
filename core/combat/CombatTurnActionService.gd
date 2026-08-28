# res://core/combat/CombatTurnActionService.gd
# V2-INFRA-003 Phase 6 Slice 6H: the ACTION RESOLUTION half of a combat activation, moved
# verbatim out of core/runtime/FlowRuntime.gd::_resolve_next_actor (the contiguous block that
# sat at :1380-:1664, 285 lines) plus the one private helper that block was the sole production
# caller of (_apply_kill_momentum, :1922-:1951).
#
# WHAT THIS IS. Everything that happens AFTER ActorStateMachine.advance_turn() has returned an
# intent and BEFORE the purify/hazard boundary. In order, unchanged:
#
#   1. the V2-VOICE-001 activation bark append onto ectx.round_bark_events
#   2. the combat.actor_turn debug log
#   3. the five-arm `match action_type` that turns the intent into exactly ONE
#      last_round_results entry — melee_attack / actor.guard / actor.refuse / actor.move /
#      everything else
#   4. and, inside the melee arm only, every combat consequence: damage, the offensive
#      contribution ledger, per-hit fear, kill momentum, the killer bonus and the party-wide
#      kill ripple, guard absorb, the near-death trigger, and the combat_ko bark promotion
#
# This is where damage resolution and death handling actually live. The pre-slice recon that
# expected them in _end_round was measuring the wrong function.
#
# WHY ONE SERVICE AND NOT TWO. The melee arm is 180 of the 285 lines, so splitting "the match"
# from "the melee consequences" is tempting. It is not available: the consequences read
# `result` (the CombatService return), `target` (resolved inside the arm), and `asm` (for the
# combat_ko bark), and they interleave with the ledger writes rather than following them. A
# split would have to hand all four across a call boundary and would put the bark promotion in
# a different file from the bark append twenty lines above it. The arm moves whole.
#
# CONTRACT (same as every Phase 6 sibling):
#   - Typed RefCounted. Explicit typed dependencies at construction — no autoloads, no service
#     locator, no reaching back into FlowRuntime.
#   - NO flow_machine. This class cannot transition state or rebuild a snapshot. In particular
#     it does not decide the keeper-intro rewind, which is the caller's business and stays
#     there.
#   - Never calls SaveService and never sets flow_ctx.save_request. The pre-extraction block
#     requested no save and must not start: FlowRuntime._mark_save_requested() joins reasons
#     with "|", so a save queued here would glue its reason onto the next dispatch's string.
#   - Calls no controller. It calls CombatService, LeadershipEmotionService and
#     ContributionLedgerService — all domain services.
#
# CONSTRUCTOR DEPENDENCIES — TWO, following the LiveMovementContextService precedent from
# slice 6G. config_service is NOT taken: the body reads no config of its own. Everything it
# needs (bdata for data.combat.emotion, leadership_expr_cfg) is handed in by the caller, which
# read it once at the top of the activation. flow_ctx is not taken either — nothing in the
# moved block touches it.
#
# WHAT IT TOUCHES — the complete read/write set, verified line by line:
#   READS   intent (action_type, target_id, movement_result is NOT read here);
#           actor (id, name, faction, morale, fear, guard_state, _bark_context,
#           _last_attacker_id, leadership_traits via LeadershipEmotionService);
#           ectx.actors (target lookup, kill-share count, ripple loop);
#           bdata -> data.combat.emotion (fear_per_hit, morale_per_kill, fear_reduce_per_kill,
#           morale_ripple_per_kill, fear_ripple_per_kill, fear_relief_personal_threat,
#           morale_on_guard_absorb, morale_on_near_death, fear_on_near_death), all passed in;
#           leadership_expr_cfg, passed in;
#           `round` and `t`, passed in — so the log lines and CombatService.resolve_action()
#           carry the exact values the caller logged for the same turn.
#   WRITES  ectx.last_round_results (EXACTLY ONE append per call, on every arm);
#           ectx.round_bark_events (the activation bark, and the combat_ko promotion);
#           ectx.echo_action_logs, through ContributionLedgerService only;
#           the target actor: fear, _last_attacker_id, morale (guard absorb, near death),
#           _near_death_morale_fired;
#           the acting actor: morale, fear, _last_attacker_id, _support_tally, and
#           _bark_line/_bark_context/_bark_tier via asm.finalize_combat_bark();
#           every living echo ally: morale, fear, _last_attacker_id, and (through kill
#           momentum) morale again.
#           current_hp and is_dead are written by CombatService.resolve_action(), not here.
#   NOT TOUCHED  save data, combat_state, flow_ctx, flow_ctx.save_request, any snapshot.
#
# DETERMINISM. No RNG. The one pseudo-random-looking value, the combat_ko bark key
# `(t + actor.id.hash()) % 997`, is a deterministic function of the injected tick and is moved
# byte-identical. No dispatch is added or removed (the retreat roll's seed embeds the sim tick)
# and the round counter is read, never written (the theft roll's seed embeds it). `round` keeps
# its original name; it shadows the built-in round(), which the kill-relief block CALLS four
# lines later — same name, same resolution, same result as before the move, because GDScript
# resolves the call to the built-in and the identifier to the local exactly as it did inside
# _resolve_next_actor.
#
# NO SHIM WAS LEFT ON FlowRuntime (AGENTS.md #20). _apply_kill_momentum had one reflection call
# site, tests/LeadershipEmotionTests.gd:215, rewritten in this same change.
#
# DEFECT NOTES — reported and deliberately NOT fixed here:
#   1. The kill ripple and the kill-momentum helper both write ally morale in the same turn,
#      and both credit the killer through the support tally, so an ally inside the kill_momentum
#      radius is credited twice for one kill (once at morale_ripple_per_kill, once at the trait
#      morale_boost). Consistent with the "effective post-clamp delta" rule, but the double
#      credit is not obviously intended. Pre-existing.
#   2. `_k_alive_before` counts the just-killed target by id, so the share is computed against
#      the pre-kill enemy count — correct — but the same loop excludes structures, so in
#      PROTECT and PURIFY_SHRINE the totem/shrine never contributes to the denominator while it
#      does contribute to the fight. Pre-existing.

class_name CombatTurnActionService
extends RefCounted

const LeadershipEmotionServiceScript := preload("res://core/combat/LeadershipEmotionService.gd")
const ContributionLedgerScript       := preload("res://core/combat/ContributionLedgerService.gd")

var logger: StructuredLogger


func _init(_logger: StructuredLogger) -> void:
	logger = _logger


## Resolves one activation into exactly one ectx.last_round_results entry and applies every
## combat consequence of it. Run once per activation from FlowRuntime._resolve_next_actor,
## immediately AFTER LiveMovementContextService.apply_live_activation() and BEFORE the
## purify-shrine side effect and the Burning hazard outcome.
##
## `asm` is the SAME ActorStateMachine instance that produced `intent`; it is needed only for
## finalize_combat_bark(), which owns the combat_ko bark promotion and must see the machine's
## own pending bark state. `action_type` is passed in rather than re-read from `intent` so the
## value matched here is provably the value the caller logged and branched on.
func resolve_activation(
	actor: Dictionary,
	intent: Dictionary,
	action_type: String,
	asm: ActorStateMachine,
	ectx: EncounterContext,
	bdata: Dictionary,
	leadership_expr_cfg: Dictionary,
	round: int,
	t: int
) -> void:
	# V2-VOICE-001: after advance_turn, if actor produced a high-signal bark, append to round queue.
	# Reactive barks in subsequent actors' turns read this queue via ctx["round_bark_events"].
	var _bark_ctx_post: String = str(actor.get("_bark_context", ""))
	if not _bark_ctx_post.is_empty() and _bark_ctx_post in [
		"combat_last_stand", "combat_fear_extreme", "combat_resilient", "combat_taunt", "combat_ko"
	]:
		ectx.round_bark_events.append({
			"actor_id":    str(actor.get("id", "")),
			"faction":     str(actor.get("faction", "")),
			"bark_context": _bark_ctx_post,
			"grid_pos":    actor.get("grid_pos", {}),
		})

	logger.debug(t, "combat.actor_turn", "%s → %s" % [actor.get("name", "?"), action_type], {
		"round":       round,
		"actor_id":    actor.get("id", ""),
		"actor_name":  actor.get("name", ""),
		"action_type": action_type,
		"faction":     actor.get("faction", ""),
	})

	# Resolve the action and append result to last_round_results.
	match action_type:
		"melee_attack":
			var target_id: String = str(intent.get("target_id", ""))
			var target: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, target_id)
			if not target.is_empty() and not target.get("is_dead", false):
				var result: Dictionary = CombatService.resolve_action("melee_attack", actor, target, round)
				if not result.is_empty():
					# source_id is the shared lookup key across last_round_results consumers
					# (initiative-panel action text, T9 no-damage streak, current_actor_id) —
					# CombatService returns attacker_id only, so enrich here like source_name.
					result["source_id"]   = str(actor.get("id", ""))
					result["source_name"] = str(actor.get("name", ""))
					result["target_name"] = str(target.get("name", ""))
					ectx.last_round_results.append(result)
					# S14a: offensive contribution ledger — damage_dealt/damage_taken/kills across
					# ALL factions (echo/enemy/spirit/ally). Widens the existing echo_action_logs
					# accumulator (PROG-003, ~line 1944 below) in place — same field name, kept for
					# ProgressionService compatibility. Read-only bookkeeping; never influences a
					# decision. Kill signal comes from result.is_kill, set by
					# CombatService._resolve_melee — the single source of truth (same condition
					# that sets defender.is_dead). All result.get("is_kill", ...) checks below
					# read the same key.
					var _s14a_dmg: int = int(result.get("damage", 0))
					var _s14a_attacker_id: String = str(actor.get("id", ""))
					var _s14a_defender_id: String = str(target.get("id", ""))
					var _s14a_is_kill: bool = bool(result.get("is_kill", false))
					if not ectx.echo_action_logs.has(_s14a_attacker_id):
						ectx.echo_action_logs[_s14a_attacker_id] = ContributionLedgerScript.new_entry()
					if not ectx.echo_action_logs.has(_s14a_defender_id):
						ectx.echo_action_logs[_s14a_defender_id] = ContributionLedgerScript.new_entry()
					var _s14a_atk_log: Dictionary = ectx.echo_action_logs[_s14a_attacker_id]
					var _s14a_def_log: Dictionary = ectx.echo_action_logs[_s14a_defender_id]
					_s14a_atk_log["damage_dealt"] = int(_s14a_atk_log.get("damage_dealt", 0)) + _s14a_dmg
					_s14a_def_log["damage_taken"] = int(_s14a_def_log.get("damage_taken", 0)) + _s14a_dmg
					if _s14a_is_kill:
						_s14a_atk_log["kills"] = int(_s14a_atk_log.get("kills", 0)) + 1
					var kill_str: String = " (kills)" if result.get("is_kill", false) else ""
					logger.info(t, "combat.action_resolved",
					"%s attacks %s for %d%s" % [actor.get("name", "?"), target.get("name", "?"), int(result.get("damage", 0)), kill_str], result)
					# In-combat fear accumulation: each hit adds fear pressure to the defender (runtime dict only).
					var combat_emo_cfg: Dictionary = bdata.get("combat", {}).get("emotion", {})
					var fear_per_hit: int = int(combat_emo_cfg.get("fear_per_hit", 2))
					var hit_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
						target, fear_per_hit, ectx.actors, leadership_expr_cfg)
					var _fear_before: int = int(target.get("fear", 0))
					target["fear"] = mini(100, _fear_before + hit_fear_applied)
					# S14b Tier 2 (offensive): credit the attacker the EFFECTIVE post-clamp fear
					# increase on whoever they hit — a target already at/near the 100 cap accrues less
					# than the nominal dampened amount. Consistent with the support fields'
					# effective-delta accounting. Credited only across factions — frightening
					# your own side is not a contribution. No same-faction melee exists today.
					if str(actor.get("faction", "")) != str(target.get("faction", "")):
						_s14a_atk_log["fear_inflicted"] = int(_s14a_atk_log.get("fear_inflicted", 0)) + (int(target["fear"]) - _fear_before)
					# A3: remember who last struck this actor, so the kill relief can tell
					# "the thing that was hurting ME is gone" from "a thing died somewhere".
					# Transient runtime state on the actor dict; never persisted.
					target["_last_attacker_id"] = str(actor.get("id", ""))
					logger.debug(t, "combat.fear.hit", "%s gains fear from hit" % target.get("name", "?"), {
						"actor_id": str(target.get("id", "")),
						"delta":    hit_fear_applied,
						"new_fear": int(target.get("fear", 0)),
					})
					# Kill bonus: killer gets morale + fear reduction; living Echo allies get a ripple.
					# GATED to echo killers: this is a player-side feedback mechanic (the ripple
					# hardcodes echo recipients, and kill_momentum boosts nearby echo allies). An
					# ENEMY landing a lethal blow also sets is_kill=true, so without this gate an
					# enemy kill would boost the enemy AND wrongly hand the surviving party morale
					# for losing a member. The all-faction kill signal (ledger kills, "(kills)" log,
					# combat_ko bark) stays live; only these positive party effects are echo-only.
					if result.get("is_kill", false) and str(actor.get("faction", "")) == "echo":
						_apply_kill_momentum(actor, ectx.actors, leadership_expr_cfg, t)
						var morale_per_kill: int      = int(combat_emo_cfg.get("morale_per_kill",       25))
						var fear_reduce_per_kill: int = int(combat_emo_cfg.get("fear_reduce_per_kill",  15))
						var morale_ripple: int         = int(combat_emo_cfg.get("morale_ripple_per_kill", 10))
						var fear_ripple: int           = int(combat_emo_cfg.get("fear_ripple_per_kill",    5))
						# A3: an important kill relieves more fear than a routine one.
						#
						# Relief used to be flat: -15 to the killer and -5 to EVERY living ally,
						# so -35 party-wide, for any kill in any situation. Measured, that was
						# the largest recovery term in a shipped fight. Killing 1 of 8 calmed the
						# party exactly as much as killing the last enemy on the board.
						#
						# Importance has two parts:
						#   1. SHARE OF THREAT REMOVED. share = 1 / enemies_alive_before_kill.
						#      One of four -> 0.25. The last enemy -> 1.0, so the blow that ends
						#      a fight is the big exhale. Scales the killer bonus and the ripple.
						#   2. PERSONAL THREAT REMOVED. Any Echo this enemy was last hitting gets
						#      a flat extra relief, NOT scaled by share — your attacker is gone
						#      regardless of how many others remain.
						var _k_alive_before: int = 0
						for _k_a in ectx.actors:
							if _k_a is Dictionary and str((_k_a as Dictionary).get("faction", "")) == "enemy" \
									and not bool((_k_a as Dictionary).get("is_structure", false)) \
									and (not bool((_k_a as Dictionary).get("is_dead", false)) \
										or str((_k_a as Dictionary).get("id", "")) == str(target.get("id", ""))):
								_k_alive_before += 1
						var _k_share: float = 1.0 / float(maxi(1, _k_alive_before))
						var _k_killer_relief: int = int(round(float(fear_reduce_per_kill) * _k_share))
						var _k_ripple_relief: int = int(round(float(fear_ripple) * _k_share))
						var _k_personal: int = int(combat_emo_cfg.get("fear_relief_personal_threat", 5))
						var _k_dead_id: String = str(target.get("id", ""))
						# The killer is skipped by the ally loop below, so award its personal
						# bonus here — killing the enemy that was hitting you is the clearest
						# case of "the threat to me is gone".
						if str(actor.get("_last_attacker_id", "")) == _k_dead_id:
							_k_killer_relief += _k_personal
							actor["_last_attacker_id"] = ""
						actor["morale"] = mini(100, int(actor.get("morale", 50)) + morale_per_kill)
						_k_killer_relief = LeadershipEmotionServiceScript.apply_fear_relief(
							actor, _k_killer_relief, combat_emo_cfg)
						actor["fear"]   = maxi(0,   int(actor.get("fear",   0)) - _k_killer_relief)
						logger.info(t, "combat.kill_boost", "%s gains morale from kill" % actor.get("name", "?"), {
							"actor_id":     str(actor.get("id", "")),
							"morale_delta": morale_per_kill,
							"fear_delta":   -_k_killer_relief,
							"enemies_before": _k_alive_before,
							"threat_share": _k_share,
						})
						for ally_v in ectx.actors:
							var ally: Dictionary = ally_v if ally_v is Dictionary else {}
							if str(ally.get("id", "")) == str(actor.get("id", "")): continue
							if ally.get("is_dead", false): continue
							if str(ally.get("faction", "")) != "echo": continue
							var _kr_m_before: int = int(ally.get("morale", 50))
							var _kr_f_before: int = int(ally.get("fear",   0))
							# Threat-share relief, plus the personal bonus if this dead enemy
							# was the one last striking this ally.
							var _kr_relief: int = _k_ripple_relief
							if str(ally.get("_last_attacker_id", "")) == _k_dead_id:
								_kr_relief += _k_personal
								ally["_last_attacker_id"] = ""
							_kr_relief = LeadershipEmotionServiceScript.apply_fear_relief(
								ally, _kr_relief, combat_emo_cfg)
							ally["morale"] = mini(100, _kr_m_before + morale_ripple)
							ally["fear"]   = maxi(0,   _kr_f_before - _kr_relief)
							# S14b Tier 2 (support): credit the killer the effective morale gained
							# and fear relieved on each living echo ally (post-clamp deltas).
							ContributionLedgerScript.credit_support_tally(actor, "morale_given",  int(ally["morale"]) - _kr_m_before)
							ContributionLedgerScript.credit_support_tally(actor, "fear_relieved", _kr_f_before - int(ally["fear"]))
							logger.info(t, "combat.kill_ripple",
								"%s ripple from %s kill" % [ally.get("name", "?"), actor.get("name", "?")], {
								"ally_id":      str(ally.get("id", "")),
								"morale_delta": morale_ripple,
								"fear_delta":   -_kr_relief,
							})
					# Trigger 5b: guard absorb — guarding Echo absorbs a hit and gains morale.
					var guard_absorb_morale: int = int(combat_emo_cfg.get("morale_on_guard_absorb", 4))
					if result.get("damage", 0) > 0 \
							and target.get("guard_state", false) \
							and not result.get("is_kill", false):
						target["morale"] = mini(100, int(target.get("morale", 50)) + guard_absorb_morale)
						logger.info(t, "actor.guard_absorb_morale", "Guard absorbed hit — morale tick", {
							"actor_id": str(target.get("id", "")),
							"morale":   target["morale"],
							"delta":    guard_absorb_morale,
						})
					# Triggers 2+6: near-death — first HP drop to ≤ 25% fires morale+fear once per actor.
					# max_hp lives at actor["stats"]["max_hp"]; the top-level fallback is for
					# definition-shaped dicts that carry it flat (LiveMovementContextService:824).
					var nd_max_hp: int = int((target.get("stats", {}) as Dictionary).get("max_hp", target.get("max_hp", 1)))
					if nd_max_hp > 0 \
							and not target.get("_near_death_morale_fired", false) \
							and int(target.get("current_hp", 1)) * 4 <= nd_max_hp \
							and int(target.get("current_hp", 1)) > 0:
						target["_near_death_morale_fired"] = true
						var nd_morale: int = int(combat_emo_cfg.get("morale_on_near_death", 7))
						var nd_fear:   int = int(combat_emo_cfg.get("fear_on_near_death", 8))
						target["morale"] = mini(100, int(target.get("morale", 50)) + nd_morale)
						var nd_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
							target, nd_fear, ectx.actors, leadership_expr_cfg)
						target["fear"]   = mini(100, int(target.get("fear", 0)) + nd_fear_applied)
						logger.info(t, "actor.near_death", "Near-death trigger — morale+fear tick", {
							"actor_id": str(target.get("id", "")),
							"morale":   target["morale"],
							"fear":     target["fear"],
							"fear_delta": nd_fear_applied,
						})
					# V2-VOICE-001: kill is now confirmed — upgrade bark to combat_ko if eligible.
					var _ko_vk: int = (t + str(actor.get("id", "")).hash()) % 997
					asm.finalize_combat_bark(result.get("is_kill", false), _ko_vk)
					# If finalize promoted bark to combat_ko, add it to round_bark_events.
					if str(actor.get("_bark_context", "")) == "combat_ko":
						ectx.round_bark_events.append({
							"actor_id":     str(actor.get("id", "")),
							"faction":      str(actor.get("faction", "")),
							"bark_context": "combat_ko",
							"grid_pos":     actor.get("grid_pos", {}),
						})
			else:
				# Target was dead or missing when this actor's turn resolved — log and skip.
				logger.info(t, "combat.attack_invalid_target",
					"%s's attack target already dead — turn skipped" % actor.get("name", "?"), {
					"actor_id":  str(actor.get("id", "")),
					"target_id": target_id,
				})
				ectx.last_round_results.append({
					# The intent was a melee attack. Report the attack, not an idle, so the
					# contribution ledger does not read a wasted swing as inaction.
					"action_type": "melee_attack",
					"source_id":   str(actor.get("id", "")),
					"source_name": str(actor.get("name", "")),
					"target_id":   "",
					"target_name": "",
					"damage":      0,
					"is_kill":     false,
				})
		"actor.guard":
			var guard_result: Dictionary = CombatService.resolve_action("actor.guard", actor, {}, round)
			if not guard_result.is_empty():
				guard_result["source_id"]   = str(actor.get("id", ""))
				guard_result["source_name"] = str(actor.get("name", ""))
				ectx.last_round_results.append(guard_result)
				logger.info(t, "combat.guard_taken",
					"%s guards" % actor.get("name", "?"), { "actor_id": actor.get("id", "") })
		"actor.refuse":
			# V2-PROG-012 Phase 4: threshold + expression_band + primary_reason were
			# already computed by ActorStateMachine.advance_turn() two frames earlier
			# (~:219-236) and written onto `actor` there — carry them into the log so
			# a refusal shows evidence of WHY the threshold sat where it did.
			logger.info(t, "combat.action_refused",
				"%s refuses (fear %d)" % [actor.get("name", "?"), int(actor.get("fear", 0))], {
				"actor_id":        actor.get("id", ""),
				"fear":            int(actor.get("fear", 0)),
				"threshold":       int(actor.get("_fear_threshold", 0)),
				"expression_band": str(actor.get("_expression_band", "")),
				"primary_reason":  str(actor.get("_fear_threshold_reason", "")),
			})
			ectx.last_round_results.append({
				"action_type": "actor.refuse",
				"source_id":   str(actor.get("id", "")),
				"source_name": str(actor.get("name", "")),
				"target_id":   "",
				"target_name": "",
				"damage":      0,
				"is_kill":     false,
			})
		"actor.move":
			var move_target_id: String = str(intent.get("target_id", ""))
			var move_target: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, move_target_id)
			var move_target_name: String = str(move_target.get("name", "")) if not move_target.is_empty() else ""
			logger.debug(t, "combat.actor_moved",
				"%s moves toward %s" % [actor.get("name", "?"), move_target_name if not move_target_name.is_empty() else move_target_id], {
				"actor_id":    actor.get("id", ""),
				"actor_name":  actor.get("name", ""),
				"target_id":   move_target_id,
				"target_name": move_target_name,
				"grid_pos":    actor.get("grid_pos", {}),
				"round":       round,
			})
			ectx.last_round_results.append({
				"action_type": "actor.move",
				"source_id":   str(actor.get("id", "")),
				"source_name": str(actor.get("name", "")),
				"target_id":   move_target_id,
				"target_name": move_target_name,
				"damage":      0,
				"is_kill":     false,
				"to_pos":      actor.get("grid_pos", {}).duplicate(),
			})
		_:
			ectx.last_round_results.append({
				"action_type": action_type,
				"source_id":   str(actor.get("id", "")),
				"source_name": str(actor.get("name", "")),
				"target_id":   str(intent.get("target_id", "")),
				"target_name": "",
				"damage":      0,
				"is_kill":     false,
			})


## S14b/leadership: the kill_momentum trait ripple, moved with its sole production caller (the
## melee kill branch above). Kept private and kept its original underscore name because the
## body is byte-identical apart from the ContributionLedgerService redirect; the one test that
## reached it by name was repointed to this class in the same change.
func _apply_kill_momentum(
	source: Dictionary,
	actors: Array,
	expr_cfg: Dictionary,
	t: int
) -> void:
	if not LeadershipEmotionServiceScript.is_whole_leader(source, expr_cfg):
		return
	var traits: Array = source.get("leadership_traits", []) as Array
	if not ("kill_momentum" in traits):
		return
	var effect := LeadershipEmotionServiceScript.get_trait_effect("kill_momentum", expr_cfg)
	var morale_boost := int(effect.get("morale_boost", 0))
	var radius := LeadershipEmotionServiceScript.get_trait_radius(
		source, "kill_momentum", expr_cfg)
	var allies := LeadershipEmotionServiceScript.get_nearby_living_echo_allies(
		source, actors, radius)
	if morale_boost <= 0 or allies.is_empty():
		return
	for ally_v in allies:
		var ally: Dictionary = ally_v
		var _km_before: int = int(ally.get("morale", 50))
		ally["morale"] = clampi(_km_before + morale_boost, 0, 100)
		# S14b Tier 2 (support): credit the killer the effective morale gained per ally.
		ContributionLedgerScript.credit_support_tally(source, "morale_given", int(ally["morale"]) - _km_before)
	logger.info(t, "actor.leadership.kill_momentum", "Leadership kill momentum fired", {
		"actor_id": source.get("id", ""),
		"morale_boost": morale_boost,
		"radius": radius,
		"allies_affected": allies.size(),
	})
