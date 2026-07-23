class_name MovementGoal
extends RefCounted

## A truthful tactical purpose and its bounded destination region.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")

const PURPOSES: Array = [
	"advance", "engage", "intercept", "protect", "hold", "pursue", "cut_off",
	"reposition", "regroup", "withdraw", "read", "escort",
]
const MODES: Array = [
	"combat", "purify_shrine", "recover", "protect", "endure", "pursue", "guide_spirit",
	# V2-COMBAT-002 slice 5 (A3): stage exploration. MODES is an allowlist, so
	# appending cannot invalidate any goal that validated before this entry existed.
	"explore",
]
const GOAL_ROLES: Array = [
	"baseline", "purifier", "holder", "carrier", "quarry", "spirit",
	"runner", "screener", "protector", "vanguard", "rear_guard", "blocker",
	"hunter", "watcher", "breaker", "custody_threat", "escort_threat",
]

## Pressure-source prefix that names an authored objective, situation, or place.
## A PLACE-DIRECTED `advance` publishes what it advances toward here rather than
## in `relevant_actors`, because `CombatPressureService._goal_sources` expands
## `relevant_actors` as `"actor.%s"` — putting a situation or shrine id there
## would publish the false fact `actor.sit.obj`. Kept in sync with
## `CombatPressureService._valid_source`'s `"objective."` prefix.
const OBJECTIVE_SOURCE_PREFIX: String = "objective."

const REQUIRED_FIELDS: Array = [
	"goal_id",
	"purpose",
	"destination_region",
	"urgency",
	"objective_progress",
	"relevant_actors",
	"pressure_sources",
	"planned_primary",
	"declared_fallback",
]


static func build(
	goal_id: String,
	purpose: String,
	destination_region: Array,
	urgency: float,
	objective_progress: float,
	relevant_actors: Array,
	pressure_sources: Array,
	planned_primary: Dictionary,
	declared_fallback: Dictionary
) -> Dictionary:
	return {
		"goal_id": goal_id,
		"purpose": purpose,
		"destination_region": V.canonical_position_array(destination_region),
		"urgency": urgency,
		"objective_progress": objective_progress,
		"relevant_actors": V.canonical_string_array(relevant_actors),
		"pressure_sources": V.canonical_string_array(pressure_sources),
		"planned_primary": planned_primary.duplicate(true),
		"declared_fallback": declared_fallback.duplicate(true),
	}


static func validate(value: Dictionary, mover_origin: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	var origin_result: Dictionary = V.validate_position(mover_origin, "mover_origin")
	if not bool(origin_result["valid"]):
		return origin_result
	for field: String in ["goal_id", "purpose"]:
		var string_result: Dictionary = V.require_non_empty_string(value, field)
		if not bool(string_result["valid"]):
			return string_result
	if not PURPOSES.has(str(value["purpose"])):
		return V.failure("invalid_purpose", "purpose")
	var region_result: Dictionary = V.require_canonical_position_array(
		value,
		"destination_region",
		false
	)
	if not bool(region_result["valid"]):
		return region_result
	if (value["destination_region"] as Array).has(mover_origin) and str(value["purpose"]) != "hold":
		return V.failure("goal_region_contains_origin", "destination_region")
	var id_result: Dictionary = _validate_goal_id(value)
	if not bool(id_result["valid"]):
		return id_result
	for field: String in ["urgency", "objective_progress"]:
		var number_result: Dictionary = V.require_unit_interval(value, field)
		if not bool(number_result["valid"]):
			return number_result
	var relevant_result: Dictionary = V.require_strictly_sorted_unique_strings(value, "relevant_actors")
	if not bool(relevant_result["valid"]):
		return relevant_result
	var pressure_result: Dictionary = V.require_strictly_sorted_unique_strings(value, "pressure_sources")
	if not bool(pressure_result["valid"]):
		return pressure_result
	var primary_type: Dictionary = V.require_type(value, "planned_primary", TYPE_DICTIONARY)
	if not bool(primary_type["valid"]):
		return primary_type
	var primary_result: Dictionary = ActionPlan.validate(value["planned_primary"] as Dictionary)
	if not bool(primary_result["valid"]):
		return V.failure(
			"invalid_action_plan.%s" % str(primary_result["reason"]),
			"planned_primary.%s" % str(primary_result["field"])
		)
	var fallback_type: Dictionary = V.require_type(value, "declared_fallback", TYPE_DICTIONARY)
	if not bool(fallback_type["valid"]):
		return fallback_type
	if not (value["declared_fallback"] as Dictionary).is_empty():
		var fallback_result: Dictionary = ActionPlan.validate(value["declared_fallback"] as Dictionary)
		if not bool(fallback_result["valid"]):
			return V.failure(
				"invalid_action_plan.%s" % str(fallback_result["reason"]),
				"declared_fallback.%s" % str(fallback_result["field"])
			)
	var plan_result: Dictionary = _validate_plan_for_purpose(value)
	if not bool(plan_result["valid"]):
		return plan_result
	return V.ok()


static func _validate_goal_id(value: Dictionary) -> Dictionary:
	var goal_id: String = str(value["goal_id"])
	if not V.is_semantic_token(goal_id):
		return V.failure("invalid_goal_id", "goal_id")
	var parts: PackedStringArray = goal_id.split(".", false)
	if parts.size() != 5 or parts[0] != "goal":
		return V.failure("invalid_goal_id", "goal_id")
	if not MODES.has(parts[1]):
		return V.failure("invalid_goal_mode", "goal_id")
	if parts[2] != str(value["purpose"]):
		return V.failure("goal_id_purpose_mismatch", "goal_id")
	if not GOAL_ROLES.has(parts[3]):
		return V.failure("invalid_goal_role", "goal_id")
	var anchor: Dictionary = _parse_anchor(parts[4])
	if anchor.is_empty():
		return V.failure("invalid_goal_anchor", "goal_id")
	if anchor != (value["destination_region"] as Array)[0]:
		return V.failure("goal_anchor_mismatch", "goal_id")
	return V.ok()


static func _parse_anchor(token: String) -> Dictionary:
	if not token.begins_with("c"):
		return {}
	var row_marker: int = token.find("r", 1)
	if row_marker <= 1 or row_marker >= token.length() - 1:
		return {}
	var col_text: String = token.substr(1, row_marker - 1)
	var row_text: String = token.substr(row_marker + 1)
	if not col_text.is_valid_int() or not row_text.is_valid_int():
		return {}
	var col: int = int(col_text)
	var row: int = int(row_text)
	if col < 0 or row < 0 or token != "c%dr%d" % [col, row]:
		return {}
	return {"col": col, "row": row}


## True when `pressure_sources` names at least one authored objective/place.
## Pure: reads only the goal dict, no config, no services, no RNG.
##
## The suffix must be a well-formed semantic token, not merely non-empty:
## `CombatPressureService._valid_source` gates `"objective."` sources with
## `V.is_semantic_token(source)` (applied to the whole token), and `goal_id`
## is gated the same way. Without mirroring that here, `objective.Bad-ID`
## (capitals, hyphens, spaces) would launder a place-directed `advance`
## through `validate()`, which is laxer than either sibling. Matching
## `_valid_source` exactly keeps the two validators in agreement.
static func _has_objective_source(value: Dictionary) -> bool:
	for source_value: Variant in value["pressure_sources"] as Array:
		var source: String = str(source_value)
		if (
			source.begins_with(OBJECTIVE_SOURCE_PREFIX)
			and source.length() > OBJECTIVE_SOURCE_PREFIX.length()
			and V.is_semantic_token(source)
		):
			return true
	return false


static func _validate_plan_for_purpose(value: Dictionary) -> Dictionary:
	var purpose: String = str(value["purpose"])
	var primary: Dictionary = value["planned_primary"] as Dictionary
	var fallback: Dictionary = value["declared_fallback"] as Dictionary
	var target_id: String = str(primary["target_id"])
	var relevant: Array = value["relevant_actors"] as Array
	match purpose:
		"advance":
			if not str(primary["type"]) in ["actor.move", "actor.purify_shrine"]:
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			# An `advance` must truthfully name WHAT it advances toward (§9:
			# "reduce route distance to an authored objective or priority
			# subject"). There are exactly two truthful shapes:
			#
			#   actor-directed — `target_id` names an actor, which must appear in
			#                    `relevant_actors` (UNCHANGED rule);
			#   place-directed — `target_id` is EMPTY, `destination_region` IS the
			#                    place, and `pressure_sources` must carry an
			#                    `objective.` source naming the authored objective.
			#
			# The second clause is what makes this a rule rather than a hole:
			# without it, a place-directed advance would be indistinguishable from
			# a `reposition` and every moving goal could relabel itself `advance`
			# for free. It also removes the slice-5 concession that forced all
			# moving stage goals to `reposition` because a situation id could not
			# be laundered through `relevant_actors`.
			if target_id.is_empty():
				if not _has_objective_source(value):
					return V.failure("advance_requires_named_objective", "pressure_sources")
			elif not relevant.has(target_id):
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"engage", "pursue":
			if str(primary["type"]) != "melee_attack":
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if target_id.is_empty() or not relevant.has(target_id):
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"intercept", "hold", "cut_off":
			if str(primary["type"]) != "actor.guard":
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if not target_id.is_empty():
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"protect", "escort":
			# `escort` is protect-in-motion (§9: "maintain a moving protection
			# relationship"), and §13.7 lists FRONT SCREEN and REAR GUARD among
			# the escort goals — a screening escort's primary is an
			# `actor.guard`, not a `protect_ally`. `escort` previously admitted
			# `protect_ally` alone, which made those authored goals unexpressible.
			# The two purposes now share one plan rule.
			#
			# `actor.idle` is deliberately NOT admitted here. A mover that
			# declares no action is not escorting or protecting anyone; that
			# shape belongs to `read`, `hold`, or `withdraw`.
			if str(primary["type"]) == "protect_ally":
				if target_id.is_empty() or not relevant.has(target_id):
					return V.failure("invalid_primary_target", "planned_primary.target_id")
			elif str(primary["type"]) == "actor.guard":
				if not target_id.is_empty():
					return V.failure("invalid_primary_target", "planned_primary.target_id")
			else:
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
		"reposition", "regroup":
			if str(primary["type"]) != "actor.move":
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if not target_id.is_empty() and not relevant.has(target_id):
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"withdraw":
			# §8.5 step 3 — "otherwise stop, guard, or observe according to the
			# original intent". `actor.guard` and `actor.idle` are exactly those
			# outcomes, so a withdrawing mover may declare them as its primary
			# alongside the existing `actor.move`. Purely ADDITIVE: no goal that
			# validated before this widening is rejected now.
			#
			# RETRACTION (slice 6 phase 6A, unit 4). This branch used to claim it
			# "owned §8.3's action consequence" — that withdraw "usually forfeits
			# attack or limits follow-up" — and presented the rejection of
			# `melee_attack` / `protect_ally` / `actor.purify_shrine` as that
			# forfeit. THAT WAS A CATEGORY ERROR and is withdrawn:
			#
			#   * §8.3 is the movement-EXPRESSIONS table — a STYLE vocabulary
			#     (Measured / Rush / Screen / Withdraw / Observe / Hold), each row
			#     pairing a movement rule with an action consequence.
			#   * `PURPOSES` comes from §9, the movement-INTENT vocabulary, where
			#     `withdraw` means only "increase safety while preserving future
			#     participation" and carries NO action consequence whatsoever.
			#
			# The two tables share the token `withdraw` and nothing else. Applying
			# one table's consequence to the other table's token is not enforcement,
			# it is a name collision. And the claim was hollow regardless: those
			# three types were ALREADY rejected before the widening, so this change
			# forfeits nothing that was not already forfeited — it is a pure
			# widening that admits guard/idle, and that is all it is.
			#
			# STILL UNOWNED: §8.3's actual withdraw consequence. It is a rule about
			# what a mover may DO after expressing a withdrawal, which belongs at
			# ACTION RESOLUTION, not in a contract validator that only ever sees a
			# declaration. Nothing in the codebase owns it yet.
			var withdraw_type: String = str(primary["type"])
			if not withdraw_type in ["actor.move", "actor.guard", "actor.idle"]:
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if withdraw_type == "actor.move":
				if not target_id.is_empty() and not relevant.has(target_id):
					return V.failure("invalid_primary_target", "planned_primary.target_id")
			elif not target_id.is_empty():
				# guard/idle are position-independent everywhere else in this
				# validator; naming a target under them would be a false claim.
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"read":
			if str(primary["type"]) != "actor.idle":
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if not target_id.is_empty():
				return V.failure("invalid_primary_target", "planned_primary.target_id")
	if str(primary["type"]) == "actor.idle":
		if not fallback.is_empty():
			return V.failure("idle_primary_requires_empty_fallback", "declared_fallback")
		return V.ok()
	if fallback.is_empty():
		return V.failure("missing_universal_fallback", "declared_fallback")
	if (
		str(fallback["type"]) != "actor.idle"
		or not str(fallback["target_id"]).is_empty()
		or not (fallback["payload"] as Dictionary).is_empty()
	):
		return V.failure("invalid_universal_fallback", "declared_fallback")
	return V.ok()
