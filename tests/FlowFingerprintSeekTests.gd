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
const COMBAT_ROUNDS_HASH := "0e0ccca9805d76d36368153bbc6f063f95f2d499b0cfa6de64effb6a38152daa"
const COMBAT_FINAL_HASH  := "e0043b496aa493283d87769c19660e63bcb8d39422aae1000833a0402dd8c746"
const COMBAT_SAVE_HASH   := "caca2686f263f70df3fb30a6a0638cadf1f10d749586cd8bc9cb4e36f9bd50ba"

static func test_combat() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.COMBAT, "fp_combat", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK COMBAT", r, COMBAT_ROUNDS_HASH, COMBAT_FINAL_HASH, COMBAT_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. PURIFY_SHRINE_ROUNDS_HASH and PURIFY_SHRINE_FINAL_HASH moved; PURIFY_SHRINE_SAVE_HASH held.
const PURIFY_SHRINE_ROUNDS_HASH := "bbb992758e667ad3868ddc87f1ad454918b55f5468277fa769f37e0d0cc1d409"
const PURIFY_SHRINE_FINAL_HASH  := "5502ad6dbe2075fc59f8e9bbcd2fa01ba5a9bd9adba72cea93f5dd05edb65d10"
const PURIFY_SHRINE_SAVE_HASH   := "324f6c16a1e785088ae34d7211b08dd91684c9228dfe215ee079ec4256f193fc"

static func test_purify_shrine() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PURIFY_SHRINE, "fp_purify_shrine", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PURIFY_SHRINE", r, PURIFY_SHRINE_ROUNDS_HASH, PURIFY_SHRINE_FINAL_HASH, PURIFY_SHRINE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
const RECOVER_ROUNDS_HASH := "6fedd6a4694c95d91524ee4fd67150e43c25467e027a17be73d34a7259d0b657"
const RECOVER_FINAL_HASH  := "998e712bbb60a8bde0210851985ffe76eed911e219e0359479ac4fef03794246"
const RECOVER_SAVE_HASH   := "0b9bb5db21150c1e886ab7b3401b83287d6c82c168317d3d15e239dfa88b12b6"

static func test_recover() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.RECOVER, "fp_recover", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK RECOVER", r, RECOVER_ROUNDS_HASH, RECOVER_FINAL_HASH, RECOVER_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
const PROTECT_ROUNDS_HASH := "8468efd7371b3ffe22518b9e9adcf30f38ecbaed212802403e3a2f807139e1ff"
const PROTECT_FINAL_HASH  := "298e2a9335ad20092d836eef06602c82bd297fe6013642836080af8bbc4648a7"
const PROTECT_SAVE_HASH   := "f05e407a918d10027a255eddfc722fd893177dddfaf2148aae2de8fb17943e38"

static func test_protect() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PROTECT, "fp_protect", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PROTECT", r, PROTECT_ROUNDS_HASH, PROTECT_FINAL_HASH, PROTECT_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. ENDURE_ROUNDS_HASH and ENDURE_FINAL_HASH moved; ENDURE_SAVE_HASH held.
const ENDURE_ROUNDS_HASH := "14bcf5b0e87cf970ea77f3277a7030e306eb37b23840d8867c761ed338d8fdfd"
const ENDURE_FINAL_HASH  := "bf50059fbe3d259559747a454583ab918e7eda58ffa57344a9e1b49a1d9265b1"
const ENDURE_SAVE_HASH   := "f05e407a918d10027a255eddfc722fd893177dddfaf2148aae2de8fb17943e38"

static func test_endure() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.ENDURE, "fp_endure", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK ENDURE", r, ENDURE_ROUNDS_HASH, ENDURE_FINAL_HASH, ENDURE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
const PURSUE_ROUNDS_HASH := "73a589295f5e7187ee68ade67f9f805a83a61ed58add7bf480c04b32511a9380"
const PURSUE_FINAL_HASH  := "9f9cd0632e4f01fbc25e25488d2ba969c222c49fe0bb15603affcf3d88ad1681"
const PURSUE_SAVE_HASH   := "caca2686f263f70df3fb30a6a0638cadf1f10d749586cd8bc9cb4e36f9bd50ba"

static func test_pursue() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.PURSUE, "fp_pursue", "", "", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK PURSUE", r, PURSUE_ROUNDS_HASH, PURSUE_FINAL_HASH, PURSUE_SAVE_HASH)


# Recorded: Seek, with Directive exposure acceptance.
# Re-recorded: Directive stop cause. GUIDE_SPIRIT_ROUNDS_HASH and GUIDE_SPIRIT_FINAL_HASH moved; GUIDE_SPIRIT_SAVE_HASH held.
const GUIDE_SPIRIT_ROUNDS_HASH := "7ae36ae0f11e16e3558df5601bcc752a178ba33d96e2303c4da43bd3fb70a1e4"
const GUIDE_SPIRIT_FINAL_HASH  := "cf0012793e3ae7385e32b55d95ae345b9789dff7b53a07a9a27b376a7c9b571e"
const GUIDE_SPIRIT_SAVE_HASH   := "f05e407a918d10027a255eddfc722fd893177dddfaf2148aae2de8fb17943e38"

static func test_guide_spirit() -> Dictionary:
	var r: Dictionary = FlowFingerprintTests._run_mode_fingerprint(
		EncounterResolutionModes.GUIDE_SPIRIT, "fp_guide_spirit", "protect", "nojoin", 30, SEEK)
	return FlowFingerprintTests._assert_hashes("SEEK GUIDE_SPIRIT", r, GUIDE_SPIRIT_ROUNDS_HASH, GUIDE_SPIRIT_FINAL_HASH, GUIDE_SPIRIT_SAVE_HASH)
