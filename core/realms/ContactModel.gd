class_name ContactModel

extends RefCounted

const REQUIRED_FIELDS: Array = [
	"id", "role", "virtue_primary", "virtue_secondary",
	"fear", "morale", "disposition", "state",
	"name", "turn_count", "turn_current", "outcome",
]

const VALID_ROLES: Array = [
	"witness", "guide", "charge", "claimant", "temporary_ally",
]

const VALID_STATES: Array = ["pending", "concluded", "failed"]

const VALID_DISPOSITIONS: Array = [
	"bold", "reflective", "protective", "wary", "grieving", "proud",
]


static func make(
	id: String,
	role: String,
	virtue_primary: String,
	virtue_secondary: String,
	fear: int,
	morale: int,
	disposition: String,
	npc_name: String,
	turn_count: int
) -> Dictionary:
	return {
		"id":                    id,
		"role":                  role,
		"virtue_primary":        virtue_primary,
		"virtue_secondary":      virtue_secondary,
		"fear":                  fear,
		"morale":                morale,
		"disposition":           disposition,
		"state":                 "pending",
		"name":                  npc_name,
		"turn_count":            turn_count,
		"turn_current":          0,
		"outcome":               "",
		"consulted_echo_ids":    [],
		"speaking_echo_ids":     [],
		"consulted_ids_this_turn": [],
		"ignored_bid_counts":    {},
		"burden_variant":        "",
		"npc_line":              "",
		"npc_reaction_word":     "",
	}


static func validate(contact: Dictionary) -> bool:
	for key in REQUIRED_FIELDS:
		if not contact.has(key):
			return false
	return true
