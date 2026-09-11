# res://core/combat/CombatState.gd
# COMBAT-001: Centralized combat state container.
# COMBAT-002: Initiative order added — composite readiness scoring mirroring GridService._placement_score().
# V2-COMBAT-001: "initiative score" renamed to "readiness score" — reflects tactical attributes + emotional readiness.
#
# Readiness formula (per actor):
#   score = (speed * 3 + agi * 2)
#           + archetype_mod + calling_mod + trait_mod + vector_mod
#           + morale_mod    (by_morale_tier — inspired +4, steady 0, shaken -3, broken -6)
#           + seed_nudge
#
# Calculated ONCE at combat start. Mid-combat morale recovery does not re-sort.
#
# Shape: {
#   "actors":                  Array,   # deep copy of placed actors at combat start
#   "objective":               String,  # from EncounterContext.resolution_mode
#   "round_counter":           int,     # starts at 0
#   "initiative_order":        Array,   # [{ "id": String, "name": String }, ...] descending score
#   "active_initiative_index": int,     # whose turn it is; always 0 at init; COMBAT-004 advances
# }

class_name CombatState

extends RefCounted

const REQUIRED_FIELDS := [
	"actors",
	"objective",
	"round_counter",
	"initiative_order",
	"active_initiative_index",
]

## Returns a new CombatState dictionary.
## actors is deep-copied so mutations to the source do not propagate.
## initiative_seed: derived from ectx.placement_seed (pass 0 in tests for seed-agnostic checks).
## init_cfg: data.combat.initiative_modifiers from balance.json (pass {} for modifier-free checks).
## stalemate_cfg: data.combat.stalemate from balance.json (pass {} to disable the no-progress
## forced retreat — no_progress_round_limit defaults to 0, which check_end_condition() reads
## as "off").
static func create(actors: Array, objective: String,
		initiative_seed: int = 0, init_cfg: Dictionary = {},
		objective_params: Dictionary = {}, stalemate_cfg: Dictionary = {}) -> Dictionary:
	return {
		"actors":                  actors.duplicate(true),
		"objective":               objective,
		"objective_params":        objective_params,
		"round_counter":           0,
		"initiative_order":        _calc_initiative(actors, initiative_seed, init_cfg),
		"active_initiative_index": 0,
		# COMBAT-SEQ: sequential resolution fields — runtime only, not in REQUIRED_FIELDS.
		"current_actor_index":     0,     # pointer into initiative_order for the current round
		"round_phase":             "idle", # "idle" (between rounds) | "in_round" (round active)
		# V2-STAGE-004 P3b: PURSUE — contain counter and escape flag.
		# Safe defaults for all modes; only PURSUE logic writes to these.
		"contain_counter":    0,
		"quarry_escaped":     false,
		"quarry_id":          _find_quarry_id(actors),
		# V2-STAGE-004 P3c: GUIDE_SPIRIT — escort mode, joined-spirit tracking, destination state.
		# guide_mode/spirit_joins_battle/destination_col/destination_row are seeded via
		# objective_params by EncounterSetupService / EncounterObjectiveSpawnService (runtime decisions made at encounter setup).
		# Safe defaults for all modes; only GUIDE_SPIRIT logic writes to escort_started/destination_reached.
		"guide_mode":           str(objective_params.get("guide_mode", "protect")),
		"spirit_id":            _find_spirit_id(actors),
		"spirit_joins_battle":  bool(objective_params.get("spirit_joins_battle", false)),
		"escort_started":       false,
		"guide_protect_counter": 0,  # guard-to-count: advances only when an echo is within
			#                              escort_radius of the living spirit; NEVER resets (accumulates,
			#                              unlike PROTECT's resetting protect_counter).
			"destination_col":      int(objective_params.get("destination_col", -1)),
		"destination_row":      int(objective_params.get("destination_row", -1)),
		"destination_reached":  false,
		# V2-STAGE-004 P4: temporary-ally death bark guard. Fires once per encounter.
		# Declared here with the other latches so it is not an undeclared runtime key.
		"_ally_killed_barked":  false,
		# V2-COMBAT-003: universal no-progress detector. no_progress_streak counts consecutive
		# rounds with no damage AND no per-objective progress counter advancing
		# (FlowRuntime._end_round() writes both fields, scanning ectx.last_round_results for
		# damage and combat_state's own protect_counter/guide_protect_counter/contain_counter/
		# hold_counter for progress — a GUIDE_SPIRIT escort or a RECOVER hold can legitimately
		# run many damage-free rounds while still winning). At no_progress_round_limit,
		# check_end_condition() ends the fight as a forced retreat, so a fight where NOTHING
		# moves cannot loop forever. It covers every objective except PURIFY_SHRINE — see
		# branch 10 of check_end_condition(). 0 or absent config disables the check. _no_progress_last_sum is FlowRuntime's own scratch value (the
		# progress-counter sum as of the previous round) — declared here so it is not an
		# undeclared runtime key, mirroring _ally_killed_barked above.
		"no_progress_streak":      0,
		"no_progress_round_limit": int(stalemate_cfg.get("no_progress_round_limit", 0)),
		"_no_progress_last_sum":   0,
	}


## Returns true if all required fields are present in the dictionary.
static func validate(state: Dictionary) -> bool:
	for f in REQUIRED_FIELDS:
		if not state.has(f):
			return false
	return true


## Calculates readiness order for all actors.
##
## Formula (per actor):
##   score = (speed * 3 + agi * 2)
##           + archetype_mod + calling_mod + trait_mod + vector_mod
##           + morale_mod + seed_nudge
##
## morale_mod = by_morale_tier[_morale_tier_from_score(actor.morale)] (default 0)
## seed_nudge = CampaignSeed.derive_from(seed, actor_id) % 10
## Calculated once at combat start — mid-combat morale recovery does not re-sort.
##
## Sort: descending by score.
## Tiebreak: original list position (stable — echoes before enemies = party list order).
##
## Returns: [{ "id": String, "name": String }, ...]
static func _calc_initiative(actors: Array, seed: int, cfg: Dictionary) -> Array:
	var arch_table: Dictionary   = cfg.get("by_archetype",       {})
	var call_table: Dictionary   = cfg.get("by_calling_origin",  {})
	var trait_table: Dictionary  = cfg.get("by_dominant_trait",  {})
	var vec_table: Dictionary    = cfg.get("by_dominant_vector", {})
	var morale_table: Dictionary = cfg.get("by_morale_tier",     {})

	# Build scored list with original index for stable tiebreak.
	var scored: Array = []
	for i in range(actors.size()):
		var actor_v: Variant = actors[i]
		if not actor_v is Dictionary:
			continue
		var actor := actor_v as Dictionary

		var spd: int = int(actor.get("speed", 5))
		var stats_v: Variant = actor.get("stats", {})
		var stats: Dictionary = stats_v if stats_v is Dictionary else {}
		var agi: int = int(stats.get("agi", 0))
		var base: int = spd * 3 + agi * 2

		# Archetype modifier.
		var arch_mod: int = int(arch_table.get(str(actor.get("archetype_birth", "")), 0))

		# Calling modifier — V2-PROG-002: prefer confirmed calling over birth origin.
		var _act_confirmed: String = str(actor.get("calling", ""))
		var _call_key: String = _act_confirmed \
			if not _act_confirmed.is_empty() and _act_confirmed != "uncalled" \
			else str(actor.get("calling_origin", ""))
		var call_mod: int = int(call_table.get(_call_key, 0))

		# Dominant trait modifier. All keys in actor.traits are candidates —
		# _dominant_key() scores every key in the dict. The list below is a TIEBREAK ONLY,
		# for equal values (courage > faith > wisdom).
		var traits_v: Variant = actor.get("traits", {})
		var traits: Dictionary = traits_v if traits_v is Dictionary else {}
		var dom_trait: String = _dominant_key(traits, ["courage", "faith", "wisdom"])
		var trait_mod: int = int(trait_table.get(dom_trait, 0))

		# Dominant vector modifier. All ten V2 vectors are candidates — _dominant_key()
		# scores every key in the dict. The list below is a TIEBREAK ONLY, for equal
		# values among these four.
		var vec_v: Variant = actor.get("vector_scores", {})
		var vectors: Dictionary = vec_v if vec_v is Dictionary else {}
		var dom_vec: String = _dominant_key(vectors, ["vanguard", "seeker", "protector", "pillar"])
		var vec_mod: int = int(vec_table.get(dom_vec, 0))

		# Morale-tier readiness modifier — emotional state at combat start.
		var morale_val: int = int(actor.get("morale", 50))
		var morale_mod: int = int(morale_table.get(_morale_tier_from_score(morale_val), 0))

		# Deterministic seed nudge (0-9) for remaining ties.
		var actor_id: String = str(actor.get("id", ""))
		var nudge: int = int(CampaignSeed.derive_from(seed, actor_id) % 10)

		var score: int = base + arch_mod + call_mod + trait_mod + vec_mod + morale_mod + nudge

		scored.append({
			"id":    actor_id,
			"name":  str(actor.get("name", "??")),
			"score": score,
			"index": i,
		})

	# Stable descending sort: primary = score DESC, tiebreak = original index ASC.
	scored.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["index"] < b["index"]
	)

	# Strip internal fields — return only { id, name }.
	var order: Array = []
	for entry in scored:
		order.append({ "id": entry["id"], "name": entry["name"] })
	return order


## COMBAT-005/006: Returns { "over": bool, "victory": bool, "reason": String }.
## "reason" is "" when not over. Check priority (locked):
##   0. PURSUE quarry_escaped → defeat  (immediate — takes priority over kill-win)
##   0b. GUIDE_SPIRIT spirit_killed → defeat  (immediate — takes priority over kill-win)
##       OR GUIDE_SPIRIT destination_reached → victory  (escort win, before kill-win)
##   1. all_enemies_defeated → victory  (runs first — echoes that kill the last enemy win
##      even if the shrine falls the same round)
##      EXCEPTION: ENDURE while not all_waves_spawned — lull between waves, fight continues.
##   2. shrine_destroyed (purify_shrine objective only) → defeat
##   3. PROTECT entity lost → defeat  (structure actor dead)
##   4. all_echoes_dead → defeat
##   5. RECOVER secured → victory  (hold_counter >= hold_rounds)
##   6. PROTECT guarded → victory  (protect_counter >= duration_turns AND not totem_stolen)
##      OR PROTECT stolen-at-clockout → defeat (reason: "totem_taken")
##   7. ENDURE survived → victory   (round_counter >= duration_turns)
##   8. PURSUE escaped/window → defeat / contained → victory
##   9. GUIDE_SPIRIT (protect mode) survived → victory  (guide_protect_counter >= duration_turns)
##      guide_protect_counter advances only on rounds an echo was within escort_radius of the
##      living spirit (guard-to-count) and never resets — the party must actually reach the spirit.
##   10. No-progress stalemate → forced retreat  (checked LAST, every objective except
##       PURIFY_SHRINE and GUIDE_SPIRIT escort mode, whose own clocks the detector cannot see;
##       no_progress_streak >= no_progress_round_limit, both stored on combat_state)
##
## combat_state carries round_counter, protect_counter, objective_params, hold_counter,
## no_progress_streak, and no_progress_round_limit.
## Callers that omit combat_state (COMBAT / PURIFY_SHRINE) receive byte-identical results
## to the previous 2-arg signature — no new branches fire for those modes.
static func check_end_condition(actors: Array, objective: String,
		combat_state: Dictionary = {}) -> Dictionary:
	# Read combat_state fields with safe defaults.
	var round_counter: int     = int(combat_state.get("round_counter", 0))
	var obj_params: Dictionary = combat_state.get("objective_params", {})
	var hold_counter: int      = int(combat_state.get("hold_counter", 0))

	# 0. PURSUE: quarry_escaped is an immediate defeat — takes priority over kill-win.
	if objective == EncounterResolutionModes.PURSUE and bool(combat_state.get("quarry_escaped", false)):
		return { "over": true, "victory": false, "reason": "quarry_escaped" }

	# 0b. GUIDE_SPIRIT: spirit death is an immediate defeat — takes priority over kill-win.
	if objective == EncounterResolutionModes.GUIDE_SPIRIT:
		var _gs_spirit: Dictionary = _find_spirit(actors)
		if not _gs_spirit.is_empty() and _gs_spirit.get("is_dead", false):
			return { "over": true, "victory": false, "reason": "spirit_killed" }
		# Escort: destination reached wins before all_enemies_defeated (mirrors PURSUE priority).
		if combat_state.get("destination_reached", false):
			return { "over": true, "victory": true, "reason": "spirit_escorted" }

	# 1. Victory: all enemies dead (universal).
	# ENDURE exception: while waves are still scheduled (all_waves_spawned == false),
	# clearing the field between waves must NOT end the fight — the next wave must spawn.
	# Once all_waves_spawned is true, all_enemies_defeated fires normally ("out-kill" win).
	var living_enemies := actors.filter(func(a: Dictionary) -> bool:
		return a.get("faction", "") == "enemy" and not a.get("is_dead", false))
	if living_enemies.is_empty():
		var skip_universal_win: bool = (
			objective == EncounterResolutionModes.ENDURE
			and not combat_state.get("all_waves_spawned", false)
		)
		if not skip_universal_win:
			return { "over": true, "victory": true, "reason": "all_enemies_defeated" }

	# 2. Shrine destroyed (purify_shrine objective only, unchanged).
	if objective == EncounterResolutionModes.PURIFY_SHRINE:
		var shrine: Dictionary = _find_shrine(actors)
		if not shrine.is_empty() and shrine.get("is_dead", false):
			return { "over": true, "victory": false, "reason": "shrine_destroyed" }

	# 3. PROTECT: guarded entity destroyed → immediate defeat.
	#    Uses same structure-finder as PURIFY_SHRINE; RECOVER's relic is also is_structure
	#    but this branch is gated on the PROTECT objective string so it cannot misfire.
	if objective == EncounterResolutionModes.PROTECT:
		var entity: Dictionary = _find_shrine(actors)
		if not entity.is_empty() and entity.get("is_dead", false):
			return { "over": true, "victory": false, "reason": "entity_lost" }

	# 4. Defeat: all echoes dead (unchanged).
	# A joined GUIDE_SPIRIT combatant has faction "echo" + is_spirit true, but it must never
	# keep a wiped party "alive" — exclude it so a dead party still triggers all_echoes_dead.
	# V2-STAGE-004 Phase 4 (S12): a joined Temporary Ally (is_ally true) gets the same
	# exclusion — party wipe is defeat even if the ally still stands.
	var living_echoes := actors.filter(func(a: Dictionary) -> bool:
		return a.get("faction", "") == "echo" and not a.get("is_dead", false) \
			and not a.get("is_spirit", false) and not a.get("is_ally", false))
	if living_echoes.is_empty():
		return { "over": true, "victory": false, "reason": "all_echoes_dead" }

	# 5. RECOVER: relic held for required number of rounds → victory.
	if objective == EncounterResolutionModes.RECOVER:
		var hold_rounds: int = int(obj_params.get("hold_rounds", 2))
		if hold_counter >= hold_rounds:
			return { "over": true, "victory": true, "reason": "relic_secured" }

	# 6. PROTECT: guarded for the required number of rounds.
	# protect_counter only advances on rounds where an echo was within guard radius of the entity.
	# Victory only when the totem was NOT stolen at clockout.
	# If the totem was stolen (totem_stolen == true) and the guard threshold is met → defeat "totem_taken".
	if objective == EncounterResolutionModes.PROTECT:
		var duration_turns: int = int(obj_params.get("duration_turns", 4))
		var protect_counter: int = int(combat_state.get("protect_counter", 0))
		if protect_counter >= duration_turns:
			if combat_state.get("totem_stolen", false):
				return { "over": true, "victory": false, "reason": "totem_taken" }
			return { "over": true, "victory": true, "reason": "protected" }

	# 7. ENDURE: survived the required wave duration → victory.
	if objective == EncounterResolutionModes.ENDURE:
		var duration_turns: int = int(obj_params.get("duration_turns", 5))
		if round_counter >= duration_turns:
			return { "over": true, "victory": true, "reason": "endured" }

	# 8. PURSUE: quarry escaped or window expired → defeat; contained → victory.
	if objective == EncounterResolutionModes.PURSUE:
		# Immediate defeat: quarry reached board edge.
		if combat_state.get("quarry_escaped", false):
			return { "over": true, "victory": false, "reason": "quarry_escaped" }
		var window_turns: int   = int(obj_params.get("window_turns",   8))
		var contain_rounds: int = int(obj_params.get("contain_rounds", 3))
		var contain_counter: int = int(combat_state.get("contain_counter", 0))
		# Window expired with quarry alive (all_enemies_defeated would have fired first if quarry dead).
		if round_counter >= window_turns and contain_counter < contain_rounds:
			return { "over": true, "victory": false, "reason": "window_expired" }
		# Victory: held adjacent for required rounds.
		if contain_counter >= contain_rounds:
			return { "over": true, "victory": true, "reason": "quarry_contained" }

	# 9. GUIDE_SPIRIT (protect mode): spirit guarded for the required duration → victory.
	# guide_protect_counter advances only on rounds where a living echo was within escort_radius
	# of the living spirit (guard-to-count) and never resets — a bare round timer no longer wins,
	# so the party must actually reach the spirit.
	if objective == EncounterResolutionModes.GUIDE_SPIRIT and str(combat_state.get("guide_mode", "protect")) == "protect":
		var _gs_duration: int = int(obj_params.get("duration_turns", 4))
		if int(combat_state.get("guide_protect_counter", 0)) >= _gs_duration:
			return { "over": true, "victory": true, "reason": "spirit_protected" }

	# 10. Universal no-progress stalemate. Checked LAST, after every objective-specific win or
	# loss, so it only fires when nothing else ended the fight this round. It is the fallback for
	# a fight where nothing above can fire — no damage AND no per-objective counter
	# (protect/guide_protect/contain/hold) advancing, e.g. both actors refuse or guard every
	# round. FlowRuntime._end_round() is the sole writer of no_progress_streak; it resets on
	# damage OR on any of those counters rising, so a GUIDE_SPIRIT escort or a RECOVER hold that
	# is genuinely progressing toward its own win condition — with zero combat damage the whole
	# time — never gets cut short here. Ends as a forced retreat, not a defeat: see
	# FlowRuntime._resolve_forced_retreat().
	#
	# Two objectives are excluded. See data.combat.stalemate._comment in balance.json for the
	# full reasoning; the short form:
	#   PURIFY_SHRINE — the shrine loses hit points every round with no actor acting, so branch 2
	#     (shrine_destroyed) always ends the fight on its own.
	#   GUIDE_SPIRIT escort mode — the spirit's own steps toward the destination do not advance
	#     guide_protect_counter (that field only counts protect-mode guard rounds), so a long,
	#     damage-free crossing looks identical to a true stall. Escort protect mode is NOT
	#     excluded: it has guide_protect_counter and the detector is useful there.
	var no_progress_limit: int = int(combat_state.get("no_progress_round_limit", 0))
	var is_guide_spirit_escort: bool = objective == EncounterResolutionModes.GUIDE_SPIRIT \
		and str(combat_state.get("guide_mode", "protect")) == "escort"
	if no_progress_limit > 0 and objective != EncounterResolutionModes.PURIFY_SHRINE \
			and not is_guide_spirit_escort:
		var no_progress_streak: int = int(combat_state.get("no_progress_streak", 0))
		if no_progress_streak >= no_progress_limit:
			return { "over": true, "victory": false, "reason": "no_progress_forced_retreat" }

	return { "over": false, "victory": false, "reason": "" }


## Returns the first structure actor (is_structure == true) from the list, or {} if none found.
static func _find_shrine(actors: Array) -> Dictionary:
	for actor_v in actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if actor.get("is_structure", false):
			return actor
	return {}


## Maps a raw morale value to a tier string.
## Mirrors EmotionService.get_morale_tier() thresholds — kept inline to avoid
## coupling CombatState (pure static RefCounted) to a service dependency.
static func _morale_tier_from_score(morale: int) -> String:
	if morale >= 75: return "inspired"
	if morale >= 50: return "steady"
	if morale >= 25: return "shaken"
	return "broken"


## Returns the key with the highest integer value in a Dictionary.
##
## EVERY key present in `scores` is a candidate — the dictionary is the source of truth, so
## a key added to a taxonomy in balance.json (V2-PROG-003 grew the vectors from 4 to 10) is
## scored here without a code change.
##
## `tiebreak_order` is consulted ONLY to break an equal-value tie: the key appearing earliest
## in the list wins. A key absent from the list ranks after every listed key; two unlisted
## keys tied on value are broken by ascending key name, so the result never depends on
## Dictionary insertion order.
##
## Returns "" if the dict is empty.
## (Mirrors GridService._dominant_key() — kept inline to avoid coupling.)
static func _dominant_key(scores: Dictionary, tiebreak_order: Array) -> String:
	if scores.is_empty():
		return ""
	var unranked: int    = tiebreak_order.size()
	var have: bool       = false
	var best_key: String = ""
	var best_val: int    = -9999999
	var best_rank: int   = 0
	for key_v in scores.keys():
		var key: String = str(key_v)
		var val: int    = int(scores[key_v])
		var rank: int   = tiebreak_order.find(key)
		if rank < 0:
			rank = unranked
		var better: bool = false
		if not have:
			better = true
		elif val > best_val:
			better = true
		elif val == best_val:
			if rank < best_rank:
				better = true
			elif rank == best_rank:
				better = key < best_key
		if better:
			have      = true
			best_key  = key
			best_val  = val
			best_rank = rank
	return best_key


## Returns the id of the first actor with is_quarry == true, or "" if none found.
static func _find_quarry_id(actors: Array) -> String:
	for a_v in actors:
		if not (a_v is Dictionary): continue
		var a: Dictionary = a_v
		if bool(a.get("is_quarry", false)):
			return str(a.get("id", ""))
	return ""


## Returns the id of the first actor with is_spirit == true, or "" if none found.
static func _find_spirit_id(actors: Array) -> String:
	for a_v in actors:
		if not (a_v is Dictionary): continue
		var a: Dictionary = a_v
		if bool(a.get("is_spirit", false)):
			return str(a.get("id", ""))
	return ""


## Returns the first spirit actor (is_spirit == true) from the list, or {} if none found.
static func _find_spirit(actors: Array) -> Dictionary:
	for actor_v in actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if actor.get("is_spirit", false):
			return actor
	return {}
