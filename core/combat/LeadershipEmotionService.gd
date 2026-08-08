# LeadershipEmotionService — Whole-band combat emotion effects.
# Pure deterministic helpers; callers own logging and persistence.

class_name LeadershipEmotionService
extends RefCounted

const MaturityExpressionService = preload("res://core/actors/MaturityExpressionService.gd")


static func is_whole_leader(actor: Dictionary, expr_cfg: Dictionary) -> bool:
	if actor.get("is_dead", false) or str(actor.get("actor_type", "")) != "echo":
		return false
	var band_by_standing: Dictionary = expr_cfg.get("band_by_standing", {})
	return MaturityExpressionService.get_expression_band(
		int(actor.get("rank", 1)), band_by_standing) == "whole"


static func get_trait_effect(trait_id: String, expr_cfg: Dictionary) -> Dictionary:
	var effects: Dictionary = expr_cfg.get("leadership_trait_effects", {})
	var effect_v: Variant = effects.get(trait_id, {})
	return effect_v if effect_v is Dictionary else {}


# V2-PROG-012 Phase 3: how strongly a leader's traits press onto nearby allies, graded by
# the leader's derived Presence (autonomy_outputs.presence — GDD:1361, GDD:1424-1429) rather
# than a flat Whole-band aura. See data.maturity_expression.leadership_presence_scaling for the
# full derivation and why canonical_presence (not 1.0) is the identity point.
#
# leader._presence is written by ActorStateMachine.advance_turn() (via
# MaturityExpressionService.derive_expression()) once per turn. A leader dict that has not yet
# taken a turn this encounter (most hand-built test fixtures; the pre-combat surprise-fear bump
# in FlowEncounterState, which runs before any turn) has no "_presence" key — that case defaults
# to canonical_presence itself, i.e. multiplier 1.0 (today's full strength), not 0.0. This is a
# deliberate identity default, not a bug: the seam only weakens an established leader once its
# real Presence has actually been computed and found wanting.
static func _presence_multiplier(leader: Dictionary, expr_cfg: Dictionary) -> float:
	var scaling_cfg: Dictionary = expr_cfg.get("leadership_presence_scaling", {})
	var canonical: float = maxf(0.0001, float(scaling_cfg.get("canonical_presence", 1.0)))
	var presence: float = float(leader.get("_presence", canonical))
	return clampf(presence / canonical, 0.0, 1.0)


static func get_trait_radius(
	leader: Dictionary,
	trait_id: String,
	expr_cfg: Dictionary,
	calling_behavior: Dictionary = {}
) -> int:
	var effect := get_trait_effect(trait_id, expr_cfg)
	var base_radius: int
	if effect.has("radius"):
		base_radius = maxi(0, int(effect.get("radius", 0)))
	else:
		var behavior := calling_behavior
		if behavior.is_empty():
			behavior = MaturityExpressionService.get_calling_behavior(
				leader, expr_cfg.get("calling_behavior", {}))
		base_radius = maxi(0, int(behavior.get("leadership_radius", 3)))
	if base_radius <= 0:
		return 0  # An explicitly-configured zero-radius trait stays zero regardless of Presence.
	var scaling_cfg: Dictionary = expr_cfg.get("leadership_presence_scaling", {})
	var floor_tiles: int = maxi(1, int(scaling_cfg.get("radius_floor_tiles", 1)))
	var multiplier := _presence_multiplier(leader, expr_cfg)
	return maxi(floor_tiles, roundi(float(base_radius) * multiplier))


static func get_nearby_living_echo_allies(
	leader: Dictionary,
	actors: Array,
	radius: int
) -> Array:
	var allies: Array = []
	var leader_id := str(leader.get("id", ""))
	var leader_pos: Dictionary = leader.get("grid_pos", {})
	if leader_pos.is_empty():
		return allies
	for actor_v in actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("id", "")) == leader_id:
			continue
		if actor.get("is_dead", false) or str(actor.get("actor_type", "")) != "echo":
			continue
		var actor_pos: Dictionary = actor.get("grid_pos", {})
		if actor_pos.is_empty():
			continue
		if GridService.chebyshev_distance(leader_pos, actor_pos) <= radius:
			allies.append(actor)
	return allies


static func apply_fear_gain(
	target: Dictionary,
	amount: int,
	actors: Array,
	expr_cfg: Dictionary,
	is_propagated: bool = false
) -> int:
	if amount <= 0:
		return 0
	var factor := 1.0
	for leader_v in actors:
		if not (leader_v is Dictionary):
			continue
		var leader: Dictionary = leader_v
		if not is_whole_leader(leader, expr_cfg):
			continue
		if str(leader.get("id", "")) == str(target.get("id", "")):
			continue
		var traits: Array = leader.get("leadership_traits", []) as Array
		for trait_v in traits:
			var trait_id := str(trait_v)
			var trait_factor := 1.0
			if trait_id == "fearless_example":
				trait_factor = float(get_trait_effect(trait_id, expr_cfg).get(
					"fear_accumulation_factor", 0.7))
			elif is_propagated and trait_id == "calm_transmission":
				trait_factor = float(get_trait_effect(trait_id, expr_cfg).get(
					"fear_transmission_rate", 0.3))
			elif is_propagated and trait_id == "block_contagion":
				trait_factor = 0.0
			else:
				continue
			var radius := get_trait_radius(leader, trait_id, expr_cfg)
			if _is_ally_in_radius(leader, target, radius):
				# V2-PROG-012 Phase 3: grade the trait's effect by the leader's Presence — a
				# fully-present (>= canonical) leader keeps today's full trait_factor; a
				# barely-present one has a weaker effect (graded_factor moves toward 1.0,
				# i.e. no reduction) instead of the old flat Whole-band cutoff. See
				# _presence_multiplier() and data.maturity_expression.leadership_presence_scaling.
				var multiplier := _presence_multiplier(leader, expr_cfg)
				var graded_factor := 1.0 - (1.0 - clampf(trait_factor, 0.0, 1.0)) * multiplier
				factor = minf(factor, clampf(graded_factor, 0.0, 1.0))
	return maxi(0, roundi(float(amount) * factor))


static func apply_morale_loss(
	target: Dictionary,
	amount: int,
	actors: Array,
	expr_cfg: Dictionary,
	round_number: int
) -> int:
	if amount <= 0:
		return 0
	var factor := 1.0
	for leader_v in actors:
		if not (leader_v is Dictionary):
			continue
		var leader: Dictionary = leader_v
		if not is_whole_leader(leader, expr_cfg):
			continue
		if str(leader.get("id", "")) == str(target.get("id", "")):
			continue
		var traits: Array = leader.get("leadership_traits", []) as Array
		# V2-PROG-012 Phase 3: both traits below grade their effect by the leader's Presence —
		# see apply_fear_gain()'s equivalent comment and
		# data.maturity_expression.leadership_presence_scaling for the shared derivation.
		if "morale_forecast" in traits \
				and int(leader.get("_morale_forecast_until_round", -1)) >= round_number:
			var forecast_radius := get_trait_radius(leader, "morale_forecast", expr_cfg)
			if _is_ally_in_radius(leader, target, forecast_radius):
				var forecast_multiplier := _presence_multiplier(leader, expr_cfg)
				var forecast_graded := 1.0 - forecast_multiplier  # trait_factor is 0.0 (full prevention)
				factor = minf(factor, clampf(forecast_graded, 0.0, 1.0))
		if "morale_anchor" in traits:
			var anchor_radius := get_trait_radius(leader, "morale_anchor", expr_cfg)
			if _is_ally_in_radius(leader, target, anchor_radius):
				var anchor_factor := float(get_trait_effect("morale_anchor", expr_cfg).get(
					"morale_loss_reduction", 0.5))
				var anchor_multiplier := _presence_multiplier(leader, expr_cfg)
				var anchor_graded := 1.0 - (1.0 - clampf(anchor_factor, 0.0, 1.0)) * anchor_multiplier
				factor = minf(factor, clampf(anchor_graded, 0.0, 1.0))
	return maxi(0, roundi(float(amount) * factor))


static func _is_ally_in_radius(leader: Dictionary, target: Dictionary, radius: int) -> bool:
	if target.get("is_dead", false) or str(target.get("actor_type", "")) != "echo":
		return false
	if str(leader.get("id", "")) == str(target.get("id", "")):
		return false
	var leader_pos: Dictionary = leader.get("grid_pos", {})
	var target_pos: Dictionary = target.get("grid_pos", {})
	if leader_pos.is_empty() or target_pos.is_empty():
		return false
	return GridService.chebyshev_distance(leader_pos, target_pos) <= radius
