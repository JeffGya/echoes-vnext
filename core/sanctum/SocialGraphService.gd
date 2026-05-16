# res://core/sanctum/SocialGraphService.gd
# BOND-001: Pure-static social graph logic.
# No state, no Node inheritance, no RNG, no OS time.
# All functions receive data in and return data out.
# Only apply_score_delta mutates the bonds array it receives.

class_name SocialGraphService
extends RefCounted

# ---------------------------------------------------------------------------
# Tier constants — ordered N5..P5 (index 0..10)
# ---------------------------------------------------------------------------
const TIER_NAMES: Array = [
	"Nemesis",    # -5
	"Rival",      # -4
	"Resentful",  # -3
	"Tense",      # -2
	"Wary",       # -1
	"Indifferent", # 0
	"Familiar",   # +1
	"Friendly",   # +2
	"Trusted",    # +3
	"Bonded",     # +4
	"Kindred",    # +5
]


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

static func _canonical_pair(a: String, b: String) -> Array:
	if a < b:
		return [a, b]
	return [b, a]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the edge dict for the canonical pair, or {} if none exists.
static func get_edge(bonds: Array, actor_a: String, actor_b: String) -> Dictionary:
	var pair := _canonical_pair(actor_a, actor_b)
	for edge_v in bonds:
		if not (edge_v is Dictionary):
			continue
		var edge: Dictionary = edge_v
		if str(edge.get("actor_a", "")) == pair[0] and str(edge.get("actor_b", "")) == pair[1]:
			return edge
	return {}


## Returns the relationship tier (-5..+5) for a strength value.
## Tier boundaries align with bond_thresholds: friend_min=30, rival_max=-30.
static func get_tier(strength: int) -> int:
	if strength >= 90:
		return 5
	if strength >= 70:
		return 4
	if strength >= 50:
		return 3
	if strength >= 30:
		return 2
	if strength >= 10:
		return 1
	if strength >= -9:
		return 0
	if strength >= -29:
		return -1
	if strength >= -49:
		return -2
	if strength >= -69:
		return -3
	if strength >= -89:
		return -4
	return -5


## Returns the display name for a tier int (-5..+5).
static func get_tier_name(tier: int) -> String:
	var idx: int = clampi(tier + 5, 0, 10)
	return TIER_NAMES[idx]


## Derives bond_type string from a strength value and thresholds dict.
## Returns "friend", "neutral", or "rival".
static func get_bond_type(strength: int, thresholds: Dictionary) -> String:
	var rival_max: int = int(thresholds.get("rival_max", -30))
	var friend_min: int = int(thresholds.get("friend_min", 30))
	if strength <= rival_max:
		return "rival"
	if strength >= friend_min:
		return "friend"
	return "neutral"


## Returns all edges where actor_id appears as either actor_a or actor_b.
static func get_bonds_for_actor(bonds: Array, actor_id: String) -> Array:
	var result: Array = []
	for edge_v in bonds:
		if not (edge_v is Dictionary):
			continue
		var edge: Dictionary = edge_v
		if str(edge.get("actor_a", "")) == actor_id or str(edge.get("actor_b", "")) == actor_id:
			result.append(edge)
	return result


## Returns all echo_ids who have partied with actor_id (from party_encounters array).
static func get_encounters_for_actor(encounters: Array, actor_id: String) -> Array:
	var result: Array = []
	for pair_v in encounters:
		if not (pair_v is Array) or (pair_v as Array).size() < 2:
			continue
		var pair: Array = pair_v
		var pa := str(pair[0])
		var pb := str(pair[1])
		if pa == actor_id:
			result.append(pb)
		elif pb == actor_id:
			result.append(pa)
	return result


## Builds read-only bond entries for a single echo from shared party encounter history.
## Returns an Array[{ echo_id, name, tier, tier_name, strength, bond_type }]
## sorted by tier ascending (most negative first).
static func build_bond_entries_for_actor(
	actor_id: String,
	roster: Array,
	bonds: Array,
	party_encounters: Array,
	bond_thresholds: Dictionary
) -> Array:
	if actor_id.is_empty():
		return []

	var partner_ids: Array = get_encounters_for_actor(party_encounters, actor_id)
	if partner_ids.is_empty():
		return []

	var name_by_id: Dictionary = {}
	for r_v in roster:
		if not (r_v is Dictionary):
			continue
		var r: Dictionary = r_v
		name_by_id[str(r.get("id", ""))] = str(r.get("name", ""))

	var entries: Array = []
	for partner_id_v in partner_ids:
		var partner_id: String = str(partner_id_v)
		var edge := get_edge(bonds, actor_id, partner_id)
		var strength := 0
		if not edge.is_empty():
			strength = int(edge.get("strength", 0))
		var tier := get_tier(strength)
		var partner_name := str(name_by_id.get(partner_id, "")).strip_edges()
		if partner_name.is_empty():
			partner_name = "Unknown Echo"
		entries.append({
			"echo_id": partner_id,
			"name": partner_name,
			"tier": tier,
			"tier_name": get_tier_name(tier),
			"strength": strength,
			"bond_type": get_bond_type(strength, bond_thresholds),
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("tier", 0)) < int(b.get("tier", 0))
	)
	return entries


## Returns rival bond pairs where both actors are in party_ids.
## Each element is [actor_a_id, actor_b_id].
static func get_rival_pairs_in_party(bonds: Array, party_ids: Array, thresholds: Dictionary) -> Array:
	var result: Array = []
	for edge_v in bonds:
		if not (edge_v is Dictionary):
			continue
		var edge: Dictionary = edge_v
		var a := str(edge.get("actor_a", ""))
		var b := str(edge.get("actor_b", ""))
		if not (a in party_ids) or not (b in party_ids):
			continue
		var strength := int(edge.get("strength", 0))
		if get_bond_type(strength, thresholds) == "rival":
			result.append([a, b])
	return result


## Returns friend bond pairs where both actors are in party_ids.
## Each element is [actor_a_id, actor_b_id].
static func get_friend_pairs_in_party(bonds: Array, party_ids: Array, thresholds: Dictionary) -> Array:
	var result: Array = []
	for edge_v in bonds:
		if not (edge_v is Dictionary):
			continue
		var edge: Dictionary = edge_v
		var a := str(edge.get("actor_a", ""))
		var b := str(edge.get("actor_b", ""))
		if not (a in party_ids) or not (b in party_ids):
			continue
		var strength := int(edge.get("strength", 0))
		if get_bond_type(strength, thresholds) == "friend":
			result.append([a, b])
	return result


## The only mutating function. Applies delta to the strength of the canonical pair.
## Creates the edge if it does not yet exist.
## Clamps strength to -100..+100.
## No-op (no log) if delta is 0 or resulting strength equals current strength.
## Logs "sanctum.bond_updated" with full payload.
## Returns the mutated bonds array.
static func apply_score_delta(
	bonds: Array,
	actor_a: String,
	actor_b: String,
	delta: int,
	thresholds: Dictionary,
	logger: StructuredLogger,
	t: int
) -> Array:
	if delta == 0:
		return bonds

	var pair := _canonical_pair(actor_a, actor_b)
	var canon_a: String = str(pair[0])
	var canon_b: String = str(pair[1])

	# Find existing edge index or -1
	var edge_idx: int = -1
	for i in range(bonds.size()):
		var ev = bonds[i]
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev
		if str(e.get("actor_a", "")) == canon_a and str(e.get("actor_b", "")) == canon_b:
			edge_idx = i
			break

	var strength_before: int = 0
	if edge_idx >= 0:
		strength_before = int((bonds[edge_idx] as Dictionary).get("strength", 0))

	var strength_after: int = clampi(strength_before + delta, -100, 100)

	if strength_after == strength_before:
		return bonds

	var bond_type_before: String = get_bond_type(strength_before, thresholds)
	var bond_type_after: String = get_bond_type(strength_after, thresholds)

	if edge_idx >= 0:
		(bonds[edge_idx] as Dictionary)["strength"] = strength_after
	else:
		bonds.append({
			"actor_a": canon_a,
			"actor_b": canon_b,
			"strength": strength_after,
		})

	if logger != null:
		logger.info(t, "sanctum.bond_updated", "Bond edge updated", {
			"actor_a": canon_a,
			"actor_b": canon_b,
			"delta": delta,
			"strength_before": strength_before,
			"strength_after": strength_after,
			"bond_type_before": bond_type_before,
			"bond_type_after": bond_type_after,
		})

	return bonds


## Returns true if arch_a and arch_b form a rival archetype pair (directional-agnostic).
static func is_rival_archetype_pair(arch_a: String, arch_b: String, rival_pairs: Array) -> bool:
	for pair_v in rival_pairs:
		if not (pair_v is Array) or (pair_v as Array).size() < 2:
			continue
		var p: Array = pair_v
		var pa := str(p[0])
		var pb := str(p[1])
		if (pa == arch_a and pb == arch_b) or (pa == arch_b and pb == arch_a):
			return true
	return false


## Adds a canonical encounter pair if not already present.
## Returns the mutated encounters array.
static func record_encounter(encounters: Array, actor_a: String, actor_b: String) -> Array:
	var pair := _canonical_pair(actor_a, actor_b)
	for existing_v in encounters:
		if not (existing_v is Array) or (existing_v as Array).size() < 2:
			continue
		var existing: Array = existing_v
		if str(existing[0]) == pair[0] and str(existing[1]) == pair[1]:
			return encounters  # already recorded
	encounters.append(pair)
	return encounters
