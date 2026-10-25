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
# Re-recorded: pace bonus removed from the fight pay (step 5.1). COMBAT_FINAL_HASH and COMBAT_SAVE_HASH moved.
# Re-recorded: a won fight pays 0 Ase (step 5.2, D-89). COMBAT_FINAL_HASH and COMBAT_SAVE_HASH moved.
# Re-recorded: `thread_whole` added to the victory card (step 5.11, D-101). COMBAT_FINAL_HASH moved.
const COMBAT_ROUNDS_HASH := "cafb7137ada94ac47eb8de3e024ac20a7178dbb3a3663aa319b789205e4c01f3"
const COMBAT_FINAL_HASH  := "b151b90145a1f2f859423e5d6e51990316377a792fdd9c63a59b0f10205fe774"
const COMBAT_SAVE_HASH   := "8a8db4a7ff94c93fb23ce44c3a7e20f3e1af2c7a984ec64a08aa82be136aba39"

static func test_combat() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.COMBAT, "fp_combat", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK COMBAT", r, COMBAT_ROUNDS_HASH, COMBAT_FINAL_HASH, COMBAT_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. PURIFY_SHRINE_ROUNDS_HASH and PURIFY_SHRINE_FINAL_HASH moved; PURIFY_SHRINE_SAVE_HASH held.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. PURIFY_SHRINE_ROUNDS_HASH moved; PURIFY_SHRINE_FINAL_HASH and PURIFY_SHRINE_SAVE_HASH held.
# Re-recorded: pace bonus removed from the fight pay (step 5.1). PURIFY_SHRINE_FINAL_HASH and PURIFY_SHRINE_SAVE_HASH moved.
# Re-recorded: a won fight pays 0 Ase (step 5.2, D-89). PURIFY_SHRINE_FINAL_HASH and PURIFY_SHRINE_SAVE_HASH moved.
# Re-recorded: `thread_whole` added to the victory card (step 5.11, D-101). PURIFY_SHRINE_FINAL_HASH moved.
const PURIFY_SHRINE_ROUNDS_HASH := "3ba1596f66a5cd6412830cfbccead832e762e3f9288f2a34c9a4177928e0d807"
const PURIFY_SHRINE_FINAL_HASH  := "f99aa300006ccf93d0d0ddf254f76e140b92264fe4f4fc9910020c5da51638fd"
const PURIFY_SHRINE_SAVE_HASH   := "99e54983fee7e2fe8db9ac3f37752a081458e12ae0083cda771f1f43a5062da2"

static func test_purify_shrine() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PURIFY_SHRINE, "fp_purify_shrine", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PURIFY_SHRINE", r, PURIFY_SHRINE_ROUNDS_HASH, PURIFY_SHRINE_FINAL_HASH, PURIFY_SHRINE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: emotional-state pull and state steps in route scoring. RECOVER_ROUNDS_HASH and RECOVER_FINAL_HASH moved; RECOVER_SAVE_HASH held.
# Re-recorded: pace bonus removed from the fight pay (step 5.1). RECOVER_FINAL_HASH and RECOVER_SAVE_HASH moved.
# Re-recorded: a won fight pays 0 Ase (step 5.2, D-89). RECOVER_FINAL_HASH and RECOVER_SAVE_HASH moved.
# Re-recorded: `thread_whole` added to the victory card (step 5.11, D-101). RECOVER_FINAL_HASH moved.
const RECOVER_ROUNDS_HASH := "92454eb5cd96d688a96b5c4686b413d80ac10df6c803e6c0fce86b883332dbaa"
const RECOVER_FINAL_HASH  := "867e08760b02b2b4fd67a76651e653c3351f2f004c08b539f303dac73f7c7a15"
const RECOVER_SAVE_HASH   := "9fe055bb97376feb37db422eb595527dec0aa5e90751d08b509a440cc7456d51"

static func test_recover() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.RECOVER, "fp_recover", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK RECOVER", r, RECOVER_ROUNDS_HASH, RECOVER_FINAL_HASH, RECOVER_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: emotional-state pull and state steps in route scoring. PROTECT_ROUNDS_HASH moved; PROTECT_FINAL_HASH and PROTECT_SAVE_HASH held.
# Re-recorded: a won fight pays 0 Ase (step 5.2, D-89). PROTECT_FINAL_HASH and PROTECT_SAVE_HASH moved.
# Re-recorded: `thread_whole` added to the victory card (step 5.11, D-101). PROTECT_FINAL_HASH moved.
const PROTECT_ROUNDS_HASH := "0da463fed98219e2ed3165c4941a8e2c369fd77fa29b1331a630386250f61e53"
const PROTECT_FINAL_HASH  := "0b8ab57340ccbb86c30e6c98d6fbefa4e78d01e23887fcb77ec5832e7d55731e"
const PROTECT_SAVE_HASH   := "9fe055bb97376feb37db422eb595527dec0aa5e90751d08b509a440cc7456d51"

static func test_protect() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PROTECT, "fp_protect", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PROTECT", r, PROTECT_ROUNDS_HASH, PROTECT_FINAL_HASH, PROTECT_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. ENDURE_ROUNDS_HASH and ENDURE_FINAL_HASH moved; ENDURE_SAVE_HASH held.
# Re-recorded: emotional-state pull and state steps in route scoring. ENDURE_ROUNDS_HASH, ENDURE_FINAL_HASH and ENDURE_SAVE_HASH moved; none held.
# Re-recorded: pace bonus removed from the fight pay (step 5.1). ENDURE_FINAL_HASH and ENDURE_SAVE_HASH moved.
# Re-recorded: a won fight pays 0 Ase (step 5.2, D-89). ENDURE_FINAL_HASH and ENDURE_SAVE_HASH moved.
# Re-recorded: `thread_whole` added to the victory card (step 5.11, D-101). ENDURE_FINAL_HASH moved.
const ENDURE_ROUNDS_HASH := "488d5c89a3ca387e4b9d015f3fbb527ee0184fb8b2c3b3c18a46293983bc3a53"
const ENDURE_FINAL_HASH  := "a0d7eaabed1e0f9c73bcd0765e557dd79d585ad3446f0517179a20431b2055f6"
const ENDURE_SAVE_HASH   := "28bbceb1388c0580f17d9d9455d0487bb5e73ea17cb75ba87fe04112ac0ec219"

static func test_endure() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.ENDURE, "fp_endure", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK ENDURE", r, ENDURE_ROUNDS_HASH, ENDURE_FINAL_HASH, ENDURE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. PURSUE_ROUNDS_HASH and PURSUE_SAVE_HASH moved; PURSUE_FINAL_HASH held.
# Re-recorded: pace bonus removed from the fight pay (step 5.1). PURSUE_FINAL_HASH and PURSUE_SAVE_HASH moved.
# Re-recorded: a won fight pays 0 Ase (step 5.2, D-89). PURSUE_FINAL_HASH and PURSUE_SAVE_HASH moved.
# Re-recorded: `thread_whole` added to the victory card (step 5.11, D-101). PURSUE_FINAL_HASH moved.
const PURSUE_ROUNDS_HASH := "bfda3ed98f36daa39fe948633b44ad2dd47e8e9990fac1c66106531698030d41"
const PURSUE_FINAL_HASH  := "a6975f63935c138acc6054695775198a1d9b658e5bda22ac08eac4746b816c12"
const PURSUE_SAVE_HASH   := "8a8db4a7ff94c93fb23ce44c3a7e20f3e1af2c7a984ec64a08aa82be136aba39"

static func test_pursue() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PURSUE, "fp_pursue", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PURSUE", r, PURSUE_ROUNDS_HASH, PURSUE_FINAL_HASH, PURSUE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
# Re-recorded: emotional-state pull and state steps in route scoring. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
# Re-recorded: a won fight pays 0 Ase (step 5.2, D-89). GUIDE_SPIRIT_FINAL_HASH and GUIDE_SPIRIT_SAVE_HASH moved.
# Re-recorded: `thread_whole` added to the victory card (step 5.11, D-101). GUIDE_SPIRIT_FINAL_HASH moved.
const GUIDE_SPIRIT_ROUNDS_HASH := "a55d045558f22473ef775d555218458f4e817e69f56f93936eae0c2641c75d9b"
const GUIDE_SPIRIT_FINAL_HASH  := "62eccbb7162ce1e9575601e28c2dff4de93d3e4f6756a07ccf42a224f29665a6"
const GUIDE_SPIRIT_SAVE_HASH   := "9fe055bb97376feb37db422eb595527dec0aa5e90751d08b509a440cc7456d51"

static func test_guide_spirit() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.GUIDE_SPIRIT, "fp_guide_spirit", "protect", "nojoin", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK GUIDE_SPIRIT", r, GUIDE_SPIRIT_ROUNDS_HASH, GUIDE_SPIRIT_FINAL_HASH, GUIDE_SPIRIT_SAVE_HASH)
