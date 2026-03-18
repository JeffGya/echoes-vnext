# res://core/combat/CombatService.gd
# COMBAT-003: Full action resolver — dispatches on action_type and applies the result.
#
# GDD mandate (echo-and-actor-systems.md):
#   "Uncalled Echo (Rank 1–2): no active skills — only basic attack, defend/guard, movement."
#   "guard_state is a Runtime Combat State field (Layer 4)."
#
# Contract:
#   resolve_action(action_type, attacker, defender, round) → ActionResultSnapshot dict or {}
#   Mutates actor dicts directly (current_hp, is_dead, death_round, guard_state).
#   Caller is responsible for: finding target, injecting t for logging.
#
# Action dispatch table (COMBAT-003):
#   melee_attack       → _resolve_melee()    — damage + guard check + kill detection
#   actor.guard        → _resolve_guard()    — sets guard_state = true on attacker
#   actor.refuse       → {}                  — no mutation; Absolute Fear Rule handled upstream
#   protect_ally       → {}                  — stub; movement already resolved by GridService
#   actor.retreat      → {}                  — stub; GridService.move_away() not yet implemented
#   actor.interact     → {}                  — stub; objective interactions (shrine, totem) deferred
#   actor.move / idle  → {}                  — no-ops; resolved elsewhere
#
# Melee damage formula — stats + emotions only.
# Calling / trait / vector modifiers apply to equipment/weapon compatibility — not base melee.
#   effective_def = defender["def"] * 2  if guard_state  else defender["def"]
#   base          = max(0, attacker["atk"] - effective_def)
#   morale_bonus  = (attacker["morale"] - 50) / 10     # int div: −5 to +5
#   fear_penalty  = attacker["fear"] / 20               # int div: 0 to 5
#   damage        = max(0, base + morale_bonus - fear_penalty)
#
# ActionResultSnapshot shapes:
#   melee_attack: { action_type, attacker_id, target_id, damage, defender_hp_before, defender_hp_after }
#   actor.guard:  { action_type, actor_id, guard_state: true }
#   actor.refuse: { action_type, refused: true, actor_id }
#   stubs / no-ops: {}

class_name CombatService
extends RefCounted


## Full action resolver — dispatches on action_type and applies the result.
## Returns a non-empty ActionResultSnapshot dict for meaningful results; {} for no-ops/stubs.
## Mutates attacker or defender dicts where noted (current_hp, guard_state, is_dead, death_round).
## Caller injects t for logging; caller resolves target lookup before calling.
static func resolve_action(action_type: String, attacker: Dictionary,
		defender: Dictionary, round: int) -> Dictionary:
	match action_type:
		"melee_attack":
			return _resolve_melee(attacker, defender, round)
		"actor.guard":
			return _resolve_guard(attacker)
		"actor.refuse":
			# Absolute Fear Rule was handled in ActorStateMachine — resolver is a no-op.
			return {
				"action_type": "actor.refuse",
				"refused":     true,
				"actor_id":    str(attacker.get("id", "")),
			}
		"protect_ally", "actor.retreat", "actor.interact":
			return {}  # movement stubs — resolved elsewhere or not yet implemented
		_:
			return {}  # actor.move, actor.idle, unknown


## Resolves a melee attack: computes damage (with guard check), mutates defender HP,
## sets is_dead + death_round when HP reaches zero.
static func _resolve_melee(attacker: Dictionary, defender: Dictionary,
		round: int) -> Dictionary:
	var hp_before: int      = int(defender.get("current_hp", 0))
	var damage: int         = _melee_damage(attacker, defender)
	var hp_after: int       = max(0, hp_before - damage)
	defender["current_hp"]  = hp_after
	if hp_after <= 0:
		defender["is_dead"]     = true
		defender["death_round"] = round
	return {
		"action_type":        "melee_attack",
		"attacker_id":        str(attacker.get("id", "")),
		"target_id":          str(defender.get("id", "")),
		"damage":             damage,
		"defender_hp_before": hp_before,
		"defender_hp_after":  hp_after,
	}


## Guard: actor commits to a defensive stance this round.
## Sets guard_state = true — doubles effective_def for any melee attack received this round.
## guard_state is cleared by FlowRuntime at the start of each new round.
static func _resolve_guard(actor: Dictionary) -> Dictionary:
	actor["guard_state"] = true
	return {
		"action_type": "actor.guard",
		"actor_id":    str(actor.get("id", "")),
		"guard_state": true,
	}


## Melee damage: stats + emotions only.
## Guard check doubles effective_def when defender["guard_state"] == true.
## Calling / trait / vector modifiers are for equipment/weapon compatibility — not here.
## atk/def are nested under actor["stats"] — morale/fear are flat top-level emotion fields.
static func _melee_damage(attacker: Dictionary, defender: Dictionary) -> int:
	var a_stats: Dictionary = attacker.get("stats", {})
	var d_stats: Dictionary = defender.get("stats", {})
	var raw_def: int      = int(d_stats.get("def", 0))
	var eff_def: int      = raw_def * 2 if defender.get("guard_state", false) else raw_def
	var base: int         = max(0, int(a_stats.get("atk", 0)) - eff_def)
	var morale_bonus: int = (int(attacker.get("morale", 50)) - 50) / 10   # int div: −5 to +5
	var fear_penalty: int = int(attacker.get("fear", 0)) / 20              # int div: 0 to 5
	return max(0, base + morale_bonus - fear_penalty)
