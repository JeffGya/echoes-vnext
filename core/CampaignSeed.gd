extends RefCounted

class_name CampaignSeed

# The CampaignSeed is the single entry point for all deterministic ranomness in a campaign run. All subsystems must derive their randomness from here.

var root_seed: int

static func _mix64(x: int) -> int:
	# SplitMix64-style mixing (finalizer).
	# Relies on 64-bit integer wraparound.
	# Constants are expressed as signed 64-bit values to avoid hex parse overflow logs.
	var z := x + -7046029254386353131  # 0x9E3779B97F4A7C15
	z = (z ^ (z >> 30)) * -4658895280553007687  # 0xBF58476D1CE4E5B9
	z = (z ^ (z >> 27)) * -7723592293110705685  # 0x94D049BB133111EB
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

# V2-INFRA-003 Phase 4 Slice 6a: relocated verbatim from FlowRuntime._legacy_root_seed_from_seed_root.
# Shared by two call sites — FlowRuntime._handle_new_game (flow.new_game) and
# DebugController._handle_seed_set (debug.seed.set / debug.seed.reset) — so it belongs here,
# on the class that already owns every other "derive a seed value from a seed string" concern,
# rather than staying private to either caller (core/AGENTS.md: "A helper used by two or more
# domains has an owner").
static func legacy_root_seed_from_seed_root(seed_root: String) -> int:
	# Derive a deterministic int from the first 8 hex chars (32-bit).
	if seed_root.length() < 8:
		return 0
	var prefix := seed_root.substr(0, 8)
	# Parse as hex via "0x" prefix
	return int("0x" + prefix)


# V2-INFRA-003 Half A review correction C2: relocated verbatim from
# FlowRuntime._generate_seed_root_string. It is the other half of the pair Phase 4 Slice 6a
# split — _handle_new_game calls this and legacy_root_seed_from_seed_root() on consecutive
# lines — and the reason recorded for moving that one ("the class that already owns every
# other 'derive a seed value from a seed string' concern") covers minting the string just as
# well as consuming it. Half a pair moved on a rule that applied to both; this closes it.
#
# THIS IS THE ONE SANCTIONED NON-DETERMINISTIC CALL IN core/. It does not violate the
# determinism rule, it is what that rule is defined against: the campaign root seed is the
# INPUT to determinism, drawn once at New Game and then persisted, after which every draw in
# the campaign comes from CampaignSeed.derive(). It uses OS crypto bytes rather than the
# global RNG precisely so it can never be perturbed by, or perturb, any seeded stream.
#
# Consequence for tests, recorded here because this is now the site: dispatching
# "flow.new_game" in a characterization test picks a fresh campaign seed on every run and
# makes the test unrepeatable (AGENTS.md common mistake 17). Drive onboarding from boot()
# instead, which uses the pinned literal seed when no save exists.
static func generate_seed_root_string() -> String:
	# Dev-safe randomness: allowed only as an input at New Game.
	# Uses OS crypto bytes, not global RNG.
	var crypto := Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(16)
	return bytes.hex_encode()
