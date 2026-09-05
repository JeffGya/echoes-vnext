# res://tools/BehaviorResponseProbe.gd
#
# INVESTIGATION TOOL — not a test. Registered only under `-- tests guidanceprobe`.
#
# Answers three questions for V2-COMBAT-003 phase 8b:
#
#   COUNTS   — how often each of Align / Interpret / Hesitate / Object / Refuse actually
#              occurs across many hundreds of real Echo turns. A response that never
#              occurs is a reportable result, not a hidden failure.
#   CONTEST  — the raw distribution of the guidance contest, printed as deciles. The
#              five thresholds have no decided value until this is read, so run the
#              `dist` arm BEFORE trusting any threshold in GuidanceContribution.
#   DIFFER   — every round in which two Echoes answered the same suggestion
#              differently. That is the proof the decision belongs to the Echo.
#
# KNOWN LIMIT. Party composition follows the FIRST TWO CHARACTERS of the seed tag, so
# the arms below give two parties and no more, and changing the mode does not resample
# callings or traits. No per-calling claim may be generalised from this probe.
#
# Usage: `-- tests guidanceprobe [dist]`. Report at user://behavior_response_probe.txt.

class_name BehaviorResponseProbe
extends RefCounted

## Four resolution modes, with the seed tags and guide arguments FlowFingerprintTests
## uses, so a probe scenario and the recorded fingerprints describe the same encounters.
const MODES: Array = ["combat", "protect", "endure"]

## Three arms. `seed_prefix` decides the party (EchoFactory keys off the seed tag), so
## `young` and `other` are two different parties; `mature` is the SAME party as `young`
## promoted through the real rank-up path, which is what separates a Standing effect
## from a party effect. Two parties, and no more — see the KNOWN LIMIT above.
const VARIANTS: Array = [
	{"name": "young",  "seed_prefix": "fp", "ranks": {}},
	{"name": "other",  "seed_prefix": "qz", "ranks": {}},
	{"name": "mature", "seed_prefix": "fp", "ranks": {0: 6, 1: 5, 2: 4, 3: 2, 4: 1}},
]

## The suggestions. Each is a §9 movement purpose and, where one exists, the plan that
## serves it. `read` suggests standing still in a fight and is the deliberate
## contradiction: it is how the top of the ladder is reached at all.
const SUGGESTIONS: Array = [
	{"guidance_id": "hold",     "purpose": "hold",     "action_type": "actor.guard"},
	{"guidance_id": "advance",  "purpose": "advance",  "action_type": "actor.move"},
	{"guidance_id": "engage",   "purpose": "engage",   "action_type": "melee_attack"},
	{"guidance_id": "withdraw", "purpose": "withdraw", "action_type": "actor.move"},
	{"guidance_id": "protect",  "purpose": "protect",  "action_type": "protect_ally"},
	{"guidance_id": "read",     "purpose": "read",     "action_type": "actor.idle"},
	# Subject-bearing: "press THAT one", "cover HER". A suggestion that names someone is
	# the only kind an Echo can keep the purpose of while changing its shape, so these
	# two arms are what make Interpret reachable at all.
	{"guidance_id": "engage_one", "purpose": "engage", "action_type": "melee_attack", "subject": "enemy"},
	{"guidance_id": "cover_one",  "purpose": "protect", "action_type": "protect_ally", "subject": "ally"},
]

const MAX_ROUNDS: int = 8

static var _sink: FileAccess = null
static var _counts: Dictionary = {}
static var _contests: Array = []
static var _turns: int = 0
static var _differ_rounds: Array = []
static var _refuse_actions: Dictionary = {}
static var _reason_counts: Dictionary = {}
static var _by_suggestion: Dictionary = {}


static func register(runner) -> void:
	runner.register_test("behavior_response_probe/run", func(): return run())


static func _say(line: String) -> void:
	print(line)
	if _sink != null:
		_sink.store_line(line)
		_sink.flush()


static func run() -> Dictionary:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var arm: String = str(argv[2]) if argv.size() > 2 else "counts"
	_sink = FileAccess.open("user://behavior_response_probe.txt", FileAccess.WRITE)
	_counts = {}
	_contests = []
	_turns = 0
	_differ_rounds = []
	_refuse_actions = {}
	_reason_counts = {}
	_by_suggestion = {}
	_say("### ARM %s" % arm)
	for variant_v: Variant in VARIANTS:
		var variant: Dictionary = variant_v
		for mode_v: Variant in MODES:
			for suggestion_v: Variant in SUGGESTIONS:
				_run_scenario(str(mode_v), variant, suggestion_v as Dictionary)
	_report(arm)
	if _sink != null:
		_sink.close()
		_sink = null
	return {"ok": true, "error": ""}


static func _run_scenario(mode: String, variant: Dictionary, suggestion: Dictionary) -> void:
	var tag: String = "%s_%s" % [str(variant["seed_prefix"]), mode]
	var label: String = "%s/%s" % [mode, str(variant["name"])]
	var env: Dictionary = FlowFingerprintTests._setup_encounter(
		mode, tag, "", "", variant["ranks"] as Dictionary)
	if env.is_empty():
		_say("SETUP_FAILED %s" % label)
		return
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({"type": "combat.init"})
	# After combat.init: the board is placed, so a subject-bearing suggestion can name
	# an actor that is actually on it.
	var request: Dictionary = suggestion.duplicate()
	request["subject_id"] = _first_actor_id(ectx, str(suggestion.get("subject", "")))
	request.erase("subject")
	request["recipient_ids"] = []
	runtime.flow_ctx.dev_guidance = request

	for round_index: int in range(1, MAX_ROUNDS + 1):
		if bool(ectx.combat_state.get("combat_over", false)):
			break
		var seen: int = (ectx.last_round_results as Array).size()
		runtime.dispatch({"type": "combat.confirm_round"})
		var round_responses: Dictionary = {}
		seen = _drain(ectx, seen, label, str(suggestion["guidance_id"]), round_index, round_responses)
		var guard: int = 0
		while guard < 40:
			guard += 1
			var combat_state: Dictionary = ectx.combat_state
			if bool(combat_state.get("combat_over", false)) \
					or str(combat_state.get("round_phase", "")) != "in_round":
				break
			runtime.dispatch({"type": "combat.next_actor"})
			seen = _drain(ectx, seen, label, str(suggestion["guidance_id"]), round_index, round_responses)
		_note_differing_round(label, str(suggestion["guidance_id"]), round_index, round_responses)


## Reads every turn resolved since `seen` and records the acting actor's answer.
## ActorStateMachine erases the key when no answer was produced, so a value read here
## always belongs to the turn just resolved.
static func _drain(
	ectx: EncounterContext,
	seen: int,
	label: String,
	guidance_id: String,
	round_index: int,
	round_responses: Dictionary
) -> int:
	var results: Array = ectx.last_round_results as Array
	for index: int in range(seen, results.size()):
		var entry: Dictionary = results[index] as Dictionary
		var actor_id: String = str(entry.get("source_id", ""))
		var actor: Dictionary = _find_actor(ectx, actor_id)
		if actor.is_empty() or str(actor.get("faction", "")) != "echo":
			continue
		var response: Dictionary = actor.get("_guidance_response", {}) as Dictionary
		if response.is_empty():
			continue
		var name: String = str(response.get("response", ""))
		_turns += 1
		_counts[name] = int(_counts.get(name, 0)) + 1
		_contests.append(float(response.get("contest", 0.0)))
		round_responses[actor_id] = name
		if not _by_suggestion.has(guidance_id):
			_by_suggestion[guidance_id] = {}
		var per: Dictionary = _by_suggestion[guidance_id]
		per[name] = int(per.get(name, 0)) + 1
		var reason_text: String = str(response.get("reason_text", ""))
		if not reason_text.is_empty():
			_reason_counts[reason_text] = int(_reason_counts.get(reason_text, 0)) + 1
		if name == "refuse":
			var acted: String = str(entry.get("action_type", ""))
			_refuse_actions[acted] = int(_refuse_actions.get(acted, 0)) + 1
		_say("TURN %s %s r%02d %s %-9s contest=%.4f judgment=%.3f composure=%.3f action=%s reason=%s" % [
			label, guidance_id, round_index, actor_id, name,
			float(response.get("contest", 0.0)),
			float(actor.get("_judgment", 0.0)),
			float(actor.get("_composure", 0.0)),
			str(entry.get("action_type", "")),
			reason_text,
		])
	return results.size()


static func _note_differing_round(
	label: String,
	guidance_id: String,
	round_index: int,
	round_responses: Dictionary
) -> void:
	var distinct: Dictionary = {}
	for actor_id: String in round_responses:
		distinct[str(round_responses[actor_id])] = true
	if distinct.size() < 2:
		return
	var rendered: Array = []
	for actor_id: String in round_responses:
		rendered.append("%s=%s" % [actor_id, str(round_responses[actor_id])])
	rendered.sort()
	_differ_rounds.append("%s %s r%02d  %s" % [
		label, guidance_id, round_index, " ".join(rendered)
	])


## The lowest-id living enemy or Echo on the starting board, so a subject-bearing
## suggestion names a real actor without introducing a draw.
static func _first_actor_id(ectx: EncounterContext, kind: String) -> String:
	if kind.is_empty():
		return ""
	var wanted: String = "enemy" if kind == "enemy" else "echo"
	var found: Array = []
	for actor_v: Variant in ectx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if bool(actor.get("is_dead", false)) or bool(actor.get("is_structure", false)):
			continue
		if str(actor.get("faction", "")) == wanted:
			found.append(str(actor.get("id", "")))
	found.sort()
	return str(found[0]) if not found.is_empty() else ""


static func _find_actor(ectx: EncounterContext, actor_id: String) -> Dictionary:
	for actor_v: Variant in ectx.actors:
		if actor_v is Dictionary and str((actor_v as Dictionary).get("id", "")) == actor_id:
			return actor_v as Dictionary
	return {}


static func _report(arm: String) -> void:
	_say("")
	_say("=== ECHO TURNS WITH A RESPONSE: %d" % _turns)
	for name: String in GuidanceContribution.RESPONSES:
		_say("COUNT %-10s %5d" % [name, int(_counts.get(name, 0))])
	_say("")
	_say("=== BY SUGGESTION")
	var suggestion_keys: Array = _by_suggestion.keys()
	suggestion_keys.sort()
	for guidance_id: String in suggestion_keys:
		var per: Dictionary = _by_suggestion[guidance_id]
		var cells: Array = []
		for name: String in GuidanceContribution.RESPONSES:
			cells.append("%s=%d" % [name, int(per.get(name, 0))])
		_say("SUGGESTION %-12s %s" % [guidance_id, " ".join(cells)])
	_say("")
	_say("=== WHAT A REFUSING ECHO DID INSTEAD")
	if _refuse_actions.is_empty():
		_say("  (no refusals recorded)")
	for action: String in _refuse_actions:
		_say("REFUSE_ACTION %-24s %5d" % [action, int(_refuse_actions[action])])
	_say("")
	_say("=== TWO ECHOES ANSWERED DIFFERENTLY, SAME BOARD, SAME ROUND: %d rounds" % _differ_rounds.size())
	for line: String in _differ_rounds.slice(0, 12):
		_say("DIFFER %s" % line)
	_say("")
	_say("=== REASONS GIVEN")
	var reason_keys: Array = _reason_counts.keys()
	reason_keys.sort()
	for reason: String in reason_keys:
		_say("REASON %5d  %s" % [int(_reason_counts[reason]), reason])
	if arm == "dist":
		_say("")
		_say("=== CONTEST DISTRIBUTION (deciles)")
		_contests.sort()
		if _contests.is_empty():
			_say("  (no samples)")
			return
		for decile: int in range(0, 11):
			var index: int = mini(int(float(decile) / 10.0 * float(_contests.size())), _contests.size() - 1)
			_say("P%03d %.4f" % [decile * 10, float(_contests[index])])
