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
const COMBAT_FINAL_HASH  := "e0043b496aa493283d87769c19660e63bcb8d39422aae1000833a0402dd8c746"
const COMBAT_SAVE_HASH   := "0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352"

static func test_combat() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.COMBAT, "fp_combat", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK COMBAT", r, COMBAT_ROUNDS_HASH, COMBAT_FINAL_HASH, COMBAT_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. PURIFY_SHRINE_ROUNDS_HASH and PURIFY_SHRINE_FINAL_HASH moved; PURIFY_SHRINE_SAVE_HASH held.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. PURIFY_SHRINE_ROUNDS_HASH moved; PURIFY_SHRINE_FINAL_HASH and PURIFY_SHRINE_SAVE_HASH held.
const PURIFY_SHRINE_ROUNDS_HASH := "3ba1596f66a5cd6412830cfbccead832e762e3f9288f2a34c9a4177928e0d807"
const PURIFY_SHRINE_FINAL_HASH  := "5502ad6dbe2075fc59f8e9bbcd2fa01ba5a9bd9adba72cea93f5dd05edb65d10"
const PURIFY_SHRINE_SAVE_HASH   := "324f6c16a1e785088ae34d7211b08dd91684c9228dfe215ee079ec4256f193fc"

static func test_purify_shrine() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PURIFY_SHRINE, "fp_purify_shrine", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PURIFY_SHRINE", r, PURIFY_SHRINE_ROUNDS_HASH, PURIFY_SHRINE_FINAL_HASH, PURIFY_SHRINE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: emotional-state pull and state steps in route scoring. RECOVER_ROUNDS_HASH and RECOVER_FINAL_HASH moved; RECOVER_SAVE_HASH held.
const RECOVER_ROUNDS_HASH := "92454eb5cd96d688a96b5c4686b413d80ac10df6c803e6c0fce86b883332dbaa"
const RECOVER_FINAL_HASH  := "33e43352f7aa027a6d034a3d24c07308825adb4b62ae3227310c03856d1626e7"
const RECOVER_SAVE_HASH   := "0b9bb5db21150c1e886ab7b3401b83287d6c82c168317d3d15e239dfa88b12b6"

static func test_recover() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.RECOVER, "fp_recover", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK RECOVER", r, RECOVER_ROUNDS_HASH, RECOVER_FINAL_HASH, RECOVER_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: emotional-state pull and state steps in route scoring. PROTECT_ROUNDS_HASH moved; PROTECT_FINAL_HASH and PROTECT_SAVE_HASH held.
const PROTECT_ROUNDS_HASH := "0da463fed98219e2ed3165c4941a8e2c369fd77fa29b1331a630386250f61e53"
const PROTECT_FINAL_HASH  := "298e2a9335ad20092d836eef06602c82bd297fe6013642836080af8bbc4648a7"
const PROTECT_SAVE_HASH   := "f05e407a918d10027a255eddfc722fd893177dddfaf2148aae2de8fb17943e38"

static func test_protect() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PROTECT, "fp_protect", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PROTECT", r, PROTECT_ROUNDS_HASH, PROTECT_FINAL_HASH, PROTECT_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. ENDURE_ROUNDS_HASH and ENDURE_FINAL_HASH moved; ENDURE_SAVE_HASH held.
# Re-recorded: emotional-state pull and state steps in route scoring. ENDURE_ROUNDS_HASH, ENDURE_FINAL_HASH and ENDURE_SAVE_HASH moved; none held.
const ENDURE_ROUNDS_HASH := "488d5c89a3ca387e4b9d015f3fbb527ee0184fb8b2c3b3c18a46293983bc3a53"
const ENDURE_FINAL_HASH  := "b71e750707ca784e8a002b6b122a80ca37a952234f7355372d31b3e698ac6b39"
const ENDURE_SAVE_HASH   := "64dc78e3baf7dd7c3ea61b26536f842b3fecda7de923487fb9143904cffabe49"

static func test_endure() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.ENDURE, "fp_endure", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK ENDURE", r, ENDURE_ROUNDS_HASH, ENDURE_FINAL_HASH, ENDURE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. PURSUE_ROUNDS_HASH and PURSUE_SAVE_HASH moved; PURSUE_FINAL_HASH held.
const PURSUE_ROUNDS_HASH := "bfda3ed98f36daa39fe948633b44ad2dd47e8e9990fac1c66106531698030d41"
const PURSUE_FINAL_HASH  := "9f9cd0632e4f01fbc25e25488d2ba969c222c49fe0bb15603affcf3d88ad1681"
const PURSUE_SAVE_HASH   := "0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352"

static func test_pursue() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PURSUE, "fp_pursue", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PURSUE", r, PURSUE_ROUNDS_HASH, PURSUE_FINAL_HASH, PURSUE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
# Re-recorded: emotional-state pull and state steps in route scoring. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
# Re-recorded: group A, status reading in action layer and style (curved afraid value), composure computed before the movement profile, and initiative and bark triggers on the status. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
const GUIDE_SPIRIT_ROUNDS_HASH := "a55d045558f22473ef775d555218458f4e817e69f56f93936eae0c2641c75d9b"
const GUIDE_SPIRIT_FINAL_HASH  := "853b6a425e43de956056f3e199e7a988fc0c1d44901bc17584a0b4994aad7ee5"
const GUIDE_SPIRIT_SAVE_HASH   := "f05e407a918d10027a255eddfc722fd893177dddfaf2148aae2de8fb17943e38"

static func test_guide_spirit() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.GUIDE_SPIRIT, "fp_guide_spirit", "protect", "nojoin", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK GUIDE_SPIRIT", r, GUIDE_SPIRIT_ROUNDS_HASH, GUIDE_SPIRIT_FINAL_HASH, GUIDE_SPIRIT_SAVE_HASH)
