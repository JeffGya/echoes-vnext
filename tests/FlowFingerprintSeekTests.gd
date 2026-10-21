# res://tests/FlowFingerprintSeekTests.gd
#
# The seven FlowFingerprintTests mode fingerprints, run with the Seek Signs Directive active.
# Same seed tags, rosters and driver as the Scout tests; only the Directive differs.
# Update a hash only with a named cause, recorded in the commit.

class_name FlowFingerprintSeekTests
extends RefCounted

const SEEK := "directive.seek_signs"


static func register(runner) -> void:
	runner.register_test("fingerprint_seek/combat", func(): return test_combat())
	runner.register_test("fingerprint_seek/purify_shrine", func(): return test_purify_shrine())
	runner.register_test("fingerprint_seek/recover", func(): return test_recover())
	runner.register_test("fingerprint_seek/protect", func(): return test_protect())
	runner.register_test("fingerprint_seek/endure", func(): return test_endure())
	runner.register_test("fingerprint_seek/pursue", func(): return test_pursue())
	runner.register_test("fingerprint_seek/guide_spirit", func(): return test_guide_spirit())


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: emotional-state pull and state steps in route scoring. COMBAT_ROUNDS_HASH moved; COMBAT_FINAL_HASH and COMBAT_SAVE_HASH held.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. COMBAT_ROUNDS_HASH and COMBAT_SAVE_HASH moved; COMBAT_FINAL_HASH held.
const COMBAT_ROUNDS_HASH := "cafb7137ada94ac47eb8de3e024ac20a7178dbb3a3663aa319b789205e4c01f3"
const COMBAT_FINAL_HASH  := "908c9e1569b238860c6827ce48d6ecf79e7a430212f6fa5e213a755d2b57426a"
const COMBAT_SAVE_HASH   := "9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca"

static func test_combat() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.COMBAT, "fp_combat", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK COMBAT", r, COMBAT_ROUNDS_HASH, COMBAT_FINAL_HASH, COMBAT_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. PURIFY_SHRINE_ROUNDS_HASH and PURIFY_SHRINE_FINAL_HASH moved; PURIFY_SHRINE_SAVE_HASH held.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. PURIFY_SHRINE_ROUNDS_HASH moved; PURIFY_SHRINE_FINAL_HASH and PURIFY_SHRINE_SAVE_HASH held.
const PURIFY_SHRINE_ROUNDS_HASH := "3ba1596f66a5cd6412830cfbccead832e762e3f9288f2a34c9a4177928e0d807"
const PURIFY_SHRINE_FINAL_HASH  := "2150fa9844108ff0e4130d7ce3f8f674217fd390d5ecdaf0b2bb4382d2e8a424"
const PURIFY_SHRINE_SAVE_HASH   := "53cc63d72fda11556577a75d2e71279d1a0a347ed52ad5bb058b3a26718dd9a9"

static func test_purify_shrine() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PURIFY_SHRINE, "fp_purify_shrine", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PURIFY_SHRINE", r, PURIFY_SHRINE_ROUNDS_HASH, PURIFY_SHRINE_FINAL_HASH, PURIFY_SHRINE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: emotional-state pull and state steps in route scoring. RECOVER_ROUNDS_HASH and RECOVER_FINAL_HASH moved; RECOVER_SAVE_HASH held.
const RECOVER_ROUNDS_HASH := "92454eb5cd96d688a96b5c4686b413d80ac10df6c803e6c0fce86b883332dbaa"
const RECOVER_FINAL_HASH  := "31ec056cccc677314d33d2cdf24cd340b355cd0684dc02988583dbf6d5a068f4"
const RECOVER_SAVE_HASH   := "f9796b7777958f03eb587c61802286240ea191e37f5cf34f077e40bacb866cf6"

static func test_recover() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.RECOVER, "fp_recover", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK RECOVER", r, RECOVER_ROUNDS_HASH, RECOVER_FINAL_HASH, RECOVER_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: emotional-state pull and state steps in route scoring. PROTECT_ROUNDS_HASH moved; PROTECT_FINAL_HASH and PROTECT_SAVE_HASH held.
const PROTECT_ROUNDS_HASH := "0da463fed98219e2ed3165c4941a8e2c369fd77fa29b1331a630386250f61e53"
const PROTECT_FINAL_HASH  := "b070391ccd6dc662bced62bfec3aaf1433aba3b44c55e37a997bd836fd7155cd"
const PROTECT_SAVE_HASH   := "f9796b7777958f03eb587c61802286240ea191e37f5cf34f077e40bacb866cf6"

static func test_protect() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PROTECT, "fp_protect", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PROTECT", r, PROTECT_ROUNDS_HASH, PROTECT_FINAL_HASH, PROTECT_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. ENDURE_ROUNDS_HASH and ENDURE_FINAL_HASH moved; ENDURE_SAVE_HASH held.
# Re-recorded: emotional-state pull and state steps in route scoring. ENDURE_ROUNDS_HASH, ENDURE_FINAL_HASH and ENDURE_SAVE_HASH moved; none held.
const ENDURE_ROUNDS_HASH := "488d5c89a3ca387e4b9d015f3fbb527ee0184fb8b2c3b3c18a46293983bc3a53"
const ENDURE_FINAL_HASH  := "35fe03ffe9a8c91273ebf263c440b7282c1ba14afac944e22cae829a944ba5c9"
const ENDURE_SAVE_HASH   := "af54a21da43971bce4969473b253e14012b8e8ed582ad1985287f2536cb26439"

static func test_endure() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.ENDURE, "fp_endure", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK ENDURE", r, ENDURE_ROUNDS_HASH, ENDURE_FINAL_HASH, ENDURE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. PURSUE_ROUNDS_HASH and PURSUE_SAVE_HASH moved; PURSUE_FINAL_HASH held.
const PURSUE_ROUNDS_HASH := "bfda3ed98f36daa39fe948633b44ad2dd47e8e9990fac1c66106531698030d41"
const PURSUE_FINAL_HASH  := "23d10f38d127333956eec3181ca978d44da19eeee8cc78e2140f0a45399669c7"
const PURSUE_SAVE_HASH   := "9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca"

static func test_pursue() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PURSUE, "fp_pursue", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PURSUE", r, PURSUE_ROUNDS_HASH, PURSUE_FINAL_HASH, PURSUE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
# Re-recorded: emotional-state pull and state steps in route scoring. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
const GUIDE_SPIRIT_ROUNDS_HASH := "a55d045558f22473ef775d555218458f4e817e69f56f93936eae0c2641c75d9b"
const GUIDE_SPIRIT_FINAL_HASH  := "bdddd85f8f6b794f3da8c8805d73f0fd57ab681345613387cd66f38103004467"
const GUIDE_SPIRIT_SAVE_HASH   := "f9796b7777958f03eb587c61802286240ea191e37f5cf34f077e40bacb866cf6"

static func test_guide_spirit() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.GUIDE_SPIRIT, "fp_guide_spirit", "protect", "nojoin", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK GUIDE_SPIRIT", r, GUIDE_SPIRIT_ROUNDS_HASH, GUIDE_SPIRIT_FINAL_HASH, GUIDE_SPIRIT_SAVE_HASH)
