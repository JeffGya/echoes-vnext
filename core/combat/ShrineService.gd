# res://core/combat/ShrineService.gd
# COMBAT-006: Shrine objective helpers — purifier selection, drain application, purify stacks.
#
# Rules:
# - Pure static functions only — no side effects outside the passed dicts, no logging.
# - Purify never heals the shrine: it only reduces per-round drain for a limited duration.
# - Purifier is selected once at combat init (EncounterSetupService.setup) and stored in
#   EncounterContext.purifier_id. Only that echo may use actor.purify_shrine.
# - Stacks live on the shrine actor dict as purify_stacks: Array[Dictionary].
#   Each stack: { "duration": int, "reduction": int } — duration ticks down each round.
# - Purify cooldown lives on the purifier echo actor as purify_cooldown: int.
#
# Config block read from balance.json data.combat.shrine:
#   base_drain_per_round, purify_stack_rounds, purify_drain_reduction,
#   purify_expiry_penalty, purify_cooldown_rounds,
#   purify_weight_faith, purify_weight_by_vector { pillar, protector, seeker, vanguard }

class_name ShrineService
extends RefCounted


## Selects the designated purifier echo from the active party.
##
## Purifier = the echo with the highest weight, where:
##   weight = faith_trait × purify_weight_faith + purify_weight_by_vector[dominant_vector]
## Dominant vector = highest value in actor["vector_scores"]; tiebreak: pillar > protector > seeker > vanguard.
## Actor id tiebreak: lexicographically smallest — ensures determinism.
##
## Returns the actor_id string of the chosen purifier, or "" if echo_actors is empty.
static func select_purifier(echo_actors: Array, shrine_cfg: Dictionary) -> String:
	var weight_faith: float = float(shrine_cfg.get("purify_weight_faith", 0.5))
	var vec_weights: Dictionary = shrine_cfg.get("purify_weight_by_vector", {
		"pillar": 20, "protector": 10, "seeker": 5, "vanguard": 0
	})
	# All ten V2 vectors are candidates — _dominant_key() scores every key in the dict.
	# The list below is a TIEBREAK ONLY, for equal values among these four.
	var vec_tiebreak: Array = ["pillar", "protector", "seeker", "vanguard"]

	var best_id: String = ""
	var best_weight: float = -1.0

	for actor_v in echo_actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v

		# Faith trait contribution.
		var traits_v: Variant = actor.get("traits", {})
		var traits: Dictionary = traits_v if traits_v is Dictionary else {}
		var faith: float = float(traits.get("faith", 0))

		# Dominant vector contribution.
		var vecs_v: Variant = actor.get("vector_scores", {})
		var vecs: Dictionary = vecs_v if vecs_v is Dictionary else {}
		var dom_vec: String = _dominant_key(vecs, vec_tiebreak)
		var vec_bonus: float = float(vec_weights.get(dom_vec, 0))

		var weight: float = faith * weight_faith + vec_bonus

		var actor_id: String = str(actor.get("id", ""))
		var better: bool = false
		if best_id.is_empty():
			better = true
		elif weight > best_weight:
			better = true
		elif weight == best_weight:
			# Tiebreak: lexicographically smallest id.
			better = actor_id < best_id

		if better:
			best_id     = actor_id
			best_weight = weight

	return best_id


## Applies one round of shrine drain.
##
## Drain formula:
##   drain = base_drain - sum(active_stack.reduction) + sum(expiring_stack.penalty)
##   drain is clamped to minimum 0.
##
## Mutates shrine["current_hp"] and shrine["purify_stacks"]:
##   - Decrements each stack's duration by 1.
##   - Removes stacks whose duration reaches 0 (and accumulates their expiry penalty first).
##
## Returns { "drain": int, "shrine_hp": int, "stacks_expired": int }.
static func apply_drain(shrine: Dictionary, shrine_cfg: Dictionary) -> Dictionary:
	var base_drain: int      = int(shrine_cfg.get("base_drain_per_round", 5))
	var expiry_penalty: int  = int(shrine_cfg.get("purify_expiry_penalty", 2))

	var stacks_v: Variant = shrine.get("purify_stacks", [])
	var stacks: Array = stacks_v if stacks_v is Array else []

	var reduction_sum: int  = 0
	var penalty_sum: int    = 0
	var expired_count: int  = 0
	var remaining: Array    = []

	for stack_v in stacks:
		if not (stack_v is Dictionary):
			continue
		var stack: Dictionary = stack_v
		var dur: int          = int(stack.get("duration", 0)) - 1  # tick down
		var red: int          = int(stack.get("reduction", 0))

		if dur <= 0:
			# Stack expires this round: add expiry penalty, no reduction.
			penalty_sum   += expiry_penalty
			expired_count += 1
		else:
			reduction_sum += red
			remaining.append({ "duration": dur, "reduction": red })

	shrine["purify_stacks"] = remaining

	var drain: int = maxi(0, base_drain - reduction_sum + penalty_sum)
	var new_hp: int = int(shrine.get("current_hp", 0)) - drain
	shrine["current_hp"] = new_hp

	return { "drain": drain, "shrine_hp": new_hp, "stacks_expired": expired_count }


## Applies a purify action: adds a drain-reduction stack to the shrine and sets the
## purifier's cooldown.
##
## Mutates:
##   shrine["purify_stacks"] — appends { duration, reduction }
##   purifier["purify_cooldown"] — set to purify_cooldown_rounds
static func apply_purify_stack(
		shrine: Dictionary, purifier: Dictionary, shrine_cfg: Dictionary) -> void:

	var stack_rounds: int  = int(shrine_cfg.get("purify_stack_rounds", 2))
	var reduction: int     = int(shrine_cfg.get("purify_drain_reduction", 3))
	var cooldown: int      = int(shrine_cfg.get("purify_cooldown_rounds", 3))

	var stacks_v: Variant = shrine.get("purify_stacks", [])
	var stacks: Array = stacks_v if stacks_v is Array else []
	stacks.append({ "duration": stack_rounds, "reduction": reduction })
	shrine["purify_stacks"] = stacks

	purifier["purify_cooldown"] = cooldown


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
## (Mirrors CombatState._dominant_key / GridService._dominant_key — kept local to avoid coupling.)
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
