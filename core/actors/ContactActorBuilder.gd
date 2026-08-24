# res://core/actors/ContactActorBuilder.gd
# V2-STAGE-004 Phase 4 (S12): Temporary Ally auto-join.
#
# Builds an echo-faction combat actor from a "temporary_ally" NPC contact — mirrors the
# Phase 3c GUIDE_SPIRIT joined-spirit build (EnemyActor.from_definition + faction "echo",
# FlowEncounterState.gd:624-657). ContactModel carries no combat stats of its own, so the
# balance.json enemy_type template (cfg["actor_cfg"]) is the stat source, same shape every
# other combat actor already uses.
#
# Pure static. No RNG, no OS time, no side effects.
class_name ContactActorBuilder
extends RefCounted

## contact: a ContactModel dict (needs "id", "name").
## cfg keys (all read via .get with sane fallbacks — no hard-coded magic numbers):
##   "def_id"     String     — data.actor.enemy_types template key (data.contact.ally.def_id)
##   "damage_mul" float      — melee damage dampener, mirrors _spirit_damage_mul (P3c)
##   "actor_cfg"  Dictionary — { "birth_stats": ..., "enemy_types": ... }, same dict
##                             EncounterSetupService.setup() already builds for every other actor
## t: injected sim tick (forwarded to EnemyActor.from_definition; unused here otherwise).
## level: caller-computed level (completion-index scaled, same pattern as other objective actors).
static func build(contact: Dictionary, cfg: Dictionary, t: int, level: int) -> Dictionary:
	var contact_id: String   = str(contact.get("id", "ally"))
	var contact_name: String = str(contact.get("name", "Ally"))
	var def_id: String       = str(cfg.get("def_id", "temporary_ally"))
	var damage_mul: float    = float(cfg.get("damage_mul", 0.75))
	var actor_cfg: Dictionary = cfg.get("actor_cfg", {})

	var defn: Dictionary = {
		"id":      "ally_" + contact_id,
		"name":    contact_name,
		"type":    def_id,
		"level":   level,
		"faction": "echo",
	}
	var actor: Dictionary = EnemyActor.from_definition(defn, t, actor_cfg)

	# Tags read downstream: CombatState (all_echoes_dead exclusion), CombatService
	# (_ally_damage_mul melee dampener), FlowEncounterState (_project_actor + death knock).
	actor["is_ally"]           = true
	actor["_ally_damage_mul"]  = damage_mul

	# S14: precise archetype_birth via the same deterministic trait rule EchoFactory uses
	# at birth, so RecruitmentService.promote_ally_to_echo() doesn't have to fall back to
	# re-deriving it. Additive field — nothing in combat reads archetype_birth today.
	var traits: Dictionary = actor.get("traits", {})
	actor["archetype_birth"] = PersonalityArchetype.from_traits(
		int(traits.get("courage", 50)),
		int(traits.get("wisdom",  50)),
		int(traits.get("faith",   50))
	)

	return actor
