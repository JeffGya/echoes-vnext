extends RefCounted

class_name CampaignSeed

# The CampaignSeed is the single entry point for all deterministic ranomness in a campaign run. All subsystems must derive their randomness from here.

var root_seed: int

static func _mix64(x: int) -> int:
	# SplitMix64-style mixing (finalizer).
	# Relies on 64-bit integer wraparound.
	var z := x + 0x9E3779B97F4A7C15
	z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ^ (z >> 27)) * 0x94D049BB133111EB
	z = z ^ (z >> 31)
	return z

func _init(seed: int) -> void:
	root_seed = seed
	
func derive(path: String) -> int:
	# Determinimsically derive a child seed from the root seed.
	# Based on a dot-separated path (e.g. "campaign.realm.01.stag.03)
	# NOTE: Paths are intentionally case-sensitive. "realm.01" and "Realm.01" must produce different seeds. Do NOT normalize (no to_lower(), no to_upper()). Case sensitivity is part of the deterministic contract.
	var h := path.hash() # 32-bit-ish hash in Godot
	
	# Expand to a 64-bit-ish combined value
	var combined := root_seed
	combined ^= int(h) << 32
	combined ^= int(h)
	combined ^= path.length() # optional extra variation
	
	var out := _mix64(combined)
	
	# Keep it postive
	return out & 0x7FFFFFFFFFFFFFFF
	
static func derive_from(parent_seed: int, path: String) -> int:
	# Determinimsically derive a child seed from the parent seed.
	# Does not mutate parent seed. Pure funciton.
	# NOTE: Paths are intentionally case-sensitive. Do not normalize.
	var h := path.hash()
	var combined := parent_seed
	combined ^= int(h) << 32
	combined ^= int(h)
	combined ^= path.length()

	var out := _mix64(combined)
	return out & 0x7FFFFFFFFFFFFFFF

func get_rng(path: String) -> RandomNumberGenerator:
	# Return a RandomNumberGenerator seeded deterministically from the given path.
	# To be implemented in subtask 4.
	var rng := RandomNumberGenerator.new()
	rng.seed = derive(path)
	return rng
	
static func get_rng_from(parent_seed: int, path: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = derive_from(parent_seed, path)
	return rng
