# res://core/combat/CombatRoundEmotionService.gd
# V2-INFRA-003 Phase 6 Slice 6A: the seven-term IN-COMBAT EMOTION TICK, extracted verbatim out
# of core/runtime/FlowRuntime.gd::_end_round (the block that sat at :2765–:2998).
#
# CONTRACT (identical to SituationEngagementService / StageExploreTurnService, the two most
# recent siblings in this extraction family):
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
# LOCATION — core/combat/, beside LeadershipEmotionService, the domain class that performs
# every single morale/fear computation in this file (apply_fear_gain / apply_morale_loss /
# apply_fear_relief appear in all seven terms), and beside ShrineService, the other per-round
# combat consequence helper _end_round calls. Recent slices place a procedure service next to
# the domain class it wraps; that class is LeadershipEmotionService.
#
# NOT core/emotion/EmotionConsequenceService.gd — deliberately, and this is the main placement
# question this slice had to answer. That service is the FLOW-LEVEL emotion layer: its own
# header states that "every method here still routes morale/fear writes through
# EmotionService.apply_morale_delta()/apply_fear_delta()", it reads and writes save_data
# (roster echoes, economy settle ticks, run modifiers), and it is called from flow.continue,
# stage-complete, retreat and contact resolution. THIS body is the opposite on every axis: it
# is the documented MID-COMBAT DIRECT-WRITE exception (core/AGENTS.md: "Mid-combat: direct dict
# writes only — EmotionService NOT called during combat rounds"), it never touches save_data,
# and it runs only inside the round loop. Merging the two would break the invariant
# EmotionConsequenceService documents about itself, and would put save-writing and
# save-free code behind one class name. They are two different layers that happen to share
# the word "emotion".
#
# WHAT IT TOUCHES. Runtime actor dictionaries and ectx.last_round_results, plus three things
# the pre-extraction recon did not list — all of them pre-existing, none of them changed here:
#   1. ectx.combat_state["_ally_killed_barked"] — the once-per-encounter ally-bark guard.
#   2. NarrativeVoiceService.fire_ally_bark(), which writes _bark_line/_bark_context/_bark_tier
#      onto the KO'd actor dict AND appends to ectx.round_bark_events.
#   3. flow_ctx, read only through _voice_service() below (NarrativeVoiceService resolves
#      flow_ctx.encounter_ctx itself). Nothing else in this file reads flow_ctx.
# Save data is never read or written.
#
# DETERMINISM. Nothing here draws RNG. No dispatch is added or removed (the retreat roll's
# seed path embeds the tick), and the round-counter increment stays in _end_round's caller
# chain, untouched (the theft roll's seed path embeds the round counter). The `round` parameter
# keeps its original name, including the shadowing of the built-in round() that the outnumber
# term calls at term D — same name, same resolution, same result as before the move.

class_name CombatRoundEmotionService
extends RefCounted

const LeadershipEmotionServiceScript := preload("res://core/combat/LeadershipEmotionService.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## Builds a fresh NarrativeVoiceService, mirroring FlowRuntime._voice_service() — the same
## per-call construction pattern VowConsequenceService, BondConsequenceService and
## StageExploreTurnService already use. Cheap RefCounted; always correct even if flow_ctx is
## replaced after construction. NarrativeVoiceService is the real owner of bark selection, so
## nothing is duplicated here (AGENTS.md #19).
func _voice_service() -> NarrativeVoiceService:
	return NarrativeVoiceService.new(flow_ctx, config_service, logger)


## The seven-term in-combat emotion tick, run once per round from _end_round AFTER the shrine
## drain and BEFORE the RECOVER hold-counter update. Term order (A→G) is load-bearing and is
## unchanged: G's no-damage streak reads the same last_round_results that A already scanned,
## and D's relief is applied on top of B's tick, not before it.
##
##   A) Ally-KO fear spread          writes actor.fear, combat_state._ally_killed_barked
##   B) Per-round fear tick          writes actor.fear
##   C) Morale decay every N rounds  writes actor.morale
##   D) Outnumber relief             writes actor.fear
##   E) Witness-refuse               writes actor.fear, actor._witness_fear_taken
##   F) Overwhelmed                  writes actor.fear
##   G) No-damage streak             writes actor.morale, actor._no_damage_streak
##
## `round` and `leadership_expr_cfg` are passed in rather than recomputed: _end_round's shrine
## morale drain uses the same two values, and re-reading balance.json here would be a second
## read of a config subtree that already has exactly one reader per round.
func apply_round_emotion_tick(
		ectx: EncounterContext,
		round: int,
		leadership_expr_cfg: Dictionary,
		t: int) -> void:
	var combat_state: Dictionary = ectx.combat_state

	# In-combat emotion tick — applied to runtime actor dicts only; save data unchanged here.
	var emo_tick_cfg: Dictionary = config_service.get_balance().get("data", {}).get("combat", {}).get("emotion", {})

	# A) Ally KO fear spread: when a comrade falls, surviving same-faction actors gain fear.
	var fear_per_ally_ko: int = int(emo_tick_cfg.get("fear_per_ally_ko", 4))
	for res_v in ectx.last_round_results:
		if res_v is Dictionary and int(res_v.get("defender_hp_after", 1)) <= 0:
			var ko_id: String = str(res_v.get("target_id", ""))
			var ko_actor: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, ko_id)
			if ko_actor.is_empty():
				continue
			# V2-STAGE-004 Phase 4 (S15 UI-B): Temporary Ally death bark. Fires once, the
			# round the joined ally (is_ally true) is KO'd — mirrors the GUIDE_SPIRIT
			# spirit_killed detection pattern (fire-once guard on combat_state).
			if bool(ko_actor.get("is_ally", false)) \
					and not bool(combat_state.get("_ally_killed_barked", false)):
				combat_state["_ally_killed_barked"] = true
				_voice_service().fire_ally_bark(ko_actor, "ally_killed", t)
			var ko_faction: String = str(ko_actor.get("faction", ""))
			var ko_spread_count: int = 0
			for sp_a in ectx.actors:
				if sp_a is Dictionary and not sp_a.get("is_dead", false) \
						and str(sp_a.get("id", "")) != ko_id \
						and str(sp_a.get("faction", "")) == ko_faction \
						and not sp_a.get("is_structure", false):
					var ko_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
						sp_a, fear_per_ally_ko, ectx.actors, leadership_expr_cfg, true)
					sp_a["fear"] = mini(100, int(sp_a.get("fear", 0)) + ko_fear_applied)
					ko_spread_count += 1
			if ko_spread_count > 0:
				logger.info(t, "combat.fear.ally_ko", "Ally KO spreads fear to survivors", {
					"ko_actor_id":    ko_id,
					"affected_count": ko_spread_count,
					"delta":          fear_per_ally_ko,
				})

	# B) Per-round fear tick: baseline fear accumulation for all living actors.
	var fear_per_round: int = int(emo_tick_cfg.get("fear_per_round", 1))
	for tick_a in ectx.actors:
		if tick_a is Dictionary and not tick_a.get("is_dead", false) \
				and not tick_a.get("is_structure", false):
			var round_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
				tick_a, fear_per_round, ectx.actors, leadership_expr_cfg)
			tick_a["fear"] = mini(100, int(tick_a.get("fear", 0)) + round_fear_applied)
	logger.debug(t, "combat.emotion.tick", "Round fear tick applied", {
		"round":      round,
		"fear_delta": fear_per_round,
	})

	# C) Morale decay every N rounds: long fights grind echo morale (echo actors only).
	var morale_decay_n: int  = int(emo_tick_cfg.get("morale_decay_n_rounds", 3))
	var morale_decay_amt: int = int(emo_tick_cfg.get("morale_decay_amount", 1))
	if morale_decay_n > 0 and round % morale_decay_n == 0:
		for dec_a in ectx.actors:
			if dec_a is Dictionary and not dec_a.get("is_dead", false) \
					and dec_a.get("faction", "") == "echo":
				var decay_applied := LeadershipEmotionServiceScript.apply_morale_loss(
					dec_a, morale_decay_amt, ectx.actors, leadership_expr_cfg, round)
				dec_a["morale"] = maxi(0, int(dec_a.get("morale", 50)) - decay_applied)
		logger.debug(t, "combat.emotion.morale_decay", "Round morale decay applied", {
			"round": round,
			"delta": -morale_decay_amt,
		})

	# D) Outnumbering advantage (T5): Echoes outnumbering enemies reduces fear at end of round.
	var t5_living_echoes: Array = []
	var t5_living_enemies: Array = []
	for t5_a in ectx.actors:
		if not (t5_a is Dictionary) or t5_a.get("is_dead", false) or t5_a.get("is_structure", false):
			continue
		if str(t5_a.get("faction", "")) == "echo":
			t5_living_echoes.append(t5_a)
		elif str(t5_a.get("faction", "")) == "enemy":
			t5_living_enemies.append(t5_a)
	if t5_living_echoes.size() > t5_living_enemies.size() and not t5_living_echoes.is_empty():
		# A4: the relief scales with the MARGIN, not with the bare fact of outnumbering.
		#
		# This was a flat -2 whenever living echoes outnumbered living enemies. It reads
		# as a condition but behaved as a constant: shipped encounters are 5 echoes
		# against 1 to 4 enemies (enemy_spawn_config.max_count is 4), so it fired from
		# round 1 of every fight and stayed on as the party killed things. Measured, it
		# was the single largest recovery source in every shipped fight at -2.00 per echo
		# per round, against a total accumulation of +1.22 — a standing subsidy, not a
		# reward for winning.
		#
		# Scaling by margin/party_size keeps the intent (a rout is calming) and removes
		# the subsidy from fights that are actually close:
		#   5 v 1 -> margin 4/5 = 0.8 -> -2   (a rout still calms)
		#   5 v 3 -> margin 2/5 = 0.4 -> -1
		#   5 v 4 -> margin 1/5 = 0.2 ->  0   (a grind pays nothing)
		var outnumber_fear: int = int(emo_tick_cfg.get("fear_reduce_on_outnumber", 2))
		var t5_margin: float = float(t5_living_echoes.size() - t5_living_enemies.size()) \
			/ float(t5_living_echoes.size())
		var t5_relief: int = int(round(float(outnumber_fear) * t5_margin))
		if t5_relief > 0:
			# Sum the EFFECTIVE post-clamp delta. The nominal t5_relief is not what each
			# Echo receives: apply_fear_relief tapers it per actor once that actor is past
			# recovery_taper_start, and the fear-0 floor can cut it again. Logging the
			# nominal value once and letting a reader multiply it by echo_count overstates
			# this term and misattributes the remainder — the exact error the ledger this
			# rebalance depends on is meant to catch.
			var t5_total: int = 0
			for t5_echo in t5_living_echoes:
				var t5_applied: int = LeadershipEmotionServiceScript.apply_fear_relief(
					t5_echo, t5_relief, emo_tick_cfg)
				var t5_before: int = int(t5_echo.get("fear", 0))
				t5_echo["fear"] = maxi(0, t5_before - t5_applied)
				t5_total += t5_before - int(t5_echo["fear"])
			logger.debug(t, "combat.emotion.outnumber", "Echoes outnumber enemies — fear reduction", {
				"echo_count":  t5_living_echoes.size(),
				"enemy_count": t5_living_enemies.size(),
				"margin":      t5_margin,
				"delta":       -t5_relief,
				"total_delta": -t5_total,
			})

	# E) Witness ally refuse (T7): nearby Echoes gain fear when a comrade freezes this round.
	#
	# DAMPING (A1). This term is positive feedback: a refusal raises the fear of every
	# nearby Echo, which pushes those Echoes over their own refusal threshold, which
	# raises the fear of THEIR neighbours. Measured in a live encounter where refusal is
	# reachable, it became the single largest accumulation source (+196 points) and drove
	# 20 refusals in 20 rounds with fear pinned at 100. The system had only two states:
	# no refusals at all, or total collapse. That is a loop with no damping, not a tuning
	# error.
	#
	# Two dampers, both required:
	#   1. An Echo that is ITSELF refusing gains no witness fear. This is the loop: a
	#      refuser must not be pushed further by the refusals it helped cause.
	#   2. A per-Echo per-encounter cap. Repeated refusals nearby stop compounding once
	#      an Echo has taken the full dose. The counter is transient runtime state on the
	#      actor dict, so it resets with each encounter and is never persisted.
	var witness_fear: int   = int(emo_tick_cfg.get("fear_on_witness_refuse", 4))
	var witness_radius: int = int(emo_tick_cfg.get("witness_refuse_radius", 3))
	var witness_cap: int    = int(emo_tick_cfg.get("witness_refuse_max_per_encounter", 8))
	# Every Echo that refused THIS round. Read from the round results, not from the
	# actor dict: the Absolute Fear Rule returns early in ActorStateMachine.advance_turn,
	# before `last_intent` is written, so a refusing actor carries no record of it.
	var t7_refusers: Dictionary = {}
	for t7_scan in ectx.last_round_results:
		if t7_scan is Dictionary and str((t7_scan as Dictionary).get("action_type", "")) == "actor.refuse":
			t7_refusers[str((t7_scan as Dictionary).get("source_id", ""))] = true
	for t7_res in ectx.last_round_results:
		if not (t7_res is Dictionary): continue
		if str(t7_res.get("action_type", "")) != "actor.refuse": continue
		var t7_refuser_id: String = str(t7_res.get("source_id", ""))
		var t7_refuser_pos: Dictionary = {}
		for t7_a in ectx.actors:
			if t7_a is Dictionary and str(t7_a.get("id", "")) == t7_refuser_id:
				t7_refuser_pos = t7_a.get("grid_pos", {})
				break
		if t7_refuser_pos.is_empty(): continue
		for t7_obs in ectx.actors:
			if not (t7_obs is Dictionary): continue
			if t7_obs.get("is_dead", false): continue
			if str(t7_obs.get("faction", "")) != "echo": continue
			if str(t7_obs.get("id", "")) == t7_refuser_id: continue
			# Damper 1 — an Echo that refused this round is already at its threshold.
			if t7_refusers.has(str(t7_obs.get("id", ""))): continue
			# Damper 2 — this Echo has absorbed its full witness dose for this encounter.
			var t7_taken: int = int(t7_obs.get("_witness_fear_taken", 0))
			if witness_cap > 0 and t7_taken >= witness_cap: continue
			var t7_obs_pos: Dictionary = t7_obs.get("grid_pos", {})
			if GridService.manhattan_distance(t7_refuser_pos, t7_obs_pos) <= witness_radius:
				var t7_room: int = witness_fear
				if witness_cap > 0:
					t7_room = mini(witness_fear, witness_cap - t7_taken)
				var witness_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
					t7_obs, t7_room, ectx.actors, leadership_expr_cfg, true)
				var t7_before: int = int(t7_obs.get("fear", 0))
				t7_obs["fear"] = mini(100, t7_before + witness_fear_applied)
				# Count the EFFECTIVE post-clamp gain, so an Echo already at fear 100
				# does not burn its allowance on points it never received.
				t7_obs["_witness_fear_taken"] = t7_taken + (int(t7_obs["fear"]) - t7_before)
				logger.debug(t, "combat.emotion.witness_refuse", "Witness ally freeze — fear tick", {
					"observer_id": str(t7_obs.get("id", "")),
					"refuser_id":  t7_refuser_id,
					"delta":       int(t7_obs["fear"]) - t7_before,
					"taken_total": int(t7_obs["_witness_fear_taken"]),
					"cap":         witness_cap,
				})

	# F) Overwhelmed (T8): Echo targeted by 2+ attackers in one round gains fear.
	var overwhelm_threshold: int = int(emo_tick_cfg.get("overwhelmed_threshold", 2))
	var overwhelm_fear: int      = int(emo_tick_cfg.get("fear_on_overwhelmed", 5))
	var t8_attack_counts: Dictionary = {}
	for t8_res in ectx.last_round_results:
		if not (t8_res is Dictionary): continue
		if str(t8_res.get("action_type", "")) != "melee_attack": continue
		var t8_tid: String = str(t8_res.get("target_id", ""))
		if t8_tid.is_empty(): continue
		t8_attack_counts[t8_tid] = t8_attack_counts.get(t8_tid, 0) + 1
	for t8_tid in t8_attack_counts:
		if t8_attack_counts[t8_tid] >= overwhelm_threshold:
			var t8_victim: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, t8_tid)
			if t8_victim.is_empty() or t8_victim.get("is_dead", false): continue
			var overwhelm_applied := LeadershipEmotionServiceScript.apply_fear_gain(
				t8_victim, overwhelm_fear, ectx.actors, leadership_expr_cfg)
			t8_victim["fear"] = mini(100, int(t8_victim.get("fear", 0)) + overwhelm_applied)
			logger.info(t, "combat.emotion.overwhelmed", "Echo overwhelmed by multiple attackers", {
				"actor_id":       t8_tid,
				"attacker_count": t8_attack_counts[t8_tid],
				"delta":          overwhelm_fear,
			})

	# G) Consecutive no-damage (T9): Echo that dealt no damage for N rounds loses morale.
	var no_dmg_threshold: int = int(emo_tick_cfg.get("consecutive_no_damage_threshold", 2))
	var no_dmg_morale: int    = int(emo_tick_cfg.get("morale_on_consecutive_no_damage", -3))
	for t9_a in ectx.actors:
		if not (t9_a is Dictionary): continue
		if t9_a.get("is_dead", false): continue
		if str(t9_a.get("faction", "")) != "echo": continue
		var t9_id: String = str(t9_a.get("id", ""))
		var t9_dealt: bool = false
		for t9_res in ectx.last_round_results:
			if t9_res is Dictionary \
					and str(t9_res.get("source_id", "")) == t9_id \
					and int(t9_res.get("damage", 0)) > 0:
				t9_dealt = true
				break
		if t9_dealt:
			t9_a["_no_damage_streak"] = 0
		else:
			t9_a["_no_damage_streak"] = int(t9_a.get("_no_damage_streak", 0)) + 1
			if int(t9_a["_no_damage_streak"]) >= no_dmg_threshold:
				var no_damage_loss := LeadershipEmotionServiceScript.apply_morale_loss(
					t9_a, abs(no_dmg_morale), ectx.actors, leadership_expr_cfg, round)
				t9_a["morale"] = maxi(0, int(t9_a.get("morale", 50)) - no_damage_loss)
				logger.debug(t, "combat.emotion.no_damage_streak", "Echo helplessness — morale decay", {
					"actor_id": t9_id,
					"streak":   t9_a["_no_damage_streak"],
					"delta":    no_dmg_morale,
				})
