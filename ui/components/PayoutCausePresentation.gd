extends RefCounted

## Maps a payout row `cause` id (and its `params`) to the row name and the tooltip text on the
## Resolve card. Wording: docs/stories/v2-payout-explanation/decisions.md.
## Word rule (D-04): Ase and Ekwan are "earned", never "paid". Objectives are "found and
## overcome", never "won". A cause that is not listed has no tooltip and keeps its backend label.

const SCOPE_FIGHT := "fight"
const SCOPE_STAGE := "stage"

## The empty leave row. It replaces the older "Nothing overcome yet" (phase7-copy-final.md section 4).
const NOTHING_GATHERED := "Nothing was gathered."

## Row names. A cause that is not listed keeps its backend label.
const ROW_NAMES: Dictionary = {
	"replay": "Replay",
	"defeat_consolation": "Consolation",
	"repeat_defeat": "Consolation",
	"objectives_overcome": "Objectives overcome",
	"echoes_alive": "Echoes safe",
	"settled_on_leave": "Settled when you left",
	"encounter_gathered": "Fight won",
	"found_gathered": "Found",
	"encounters_overcome": "Fights won",
	"found_banked": "Found on the path",
	"nothing_overcome_yet": NOTHING_GATHERED,
}

## PROPOSAL placeholders, not approved copy: echoes_alive and the lost-names note
## (docs/stories/v2-payout-explanation/decisions.md). Jeff owns the wording. All copy stays in this table.
const TEXT: Dictionary = {
	"echoes_alive": "Each Echo that stays alive earns Ase.",
	"settled_on_leave": "These were already taken when the party left earlier.",
	"defeat_consolation": "This one was lost, but we still earn a small part.",
	"nothing_overcome_yet": NOTHING_GATHERED,
	"encounter_gathered": "It goes in their packs. It is safe only when the party gets out.",
	"found_gathered": "Found along the way. It goes in their packs.",
	"found_banked": "Gathered along the way and carried to the Sanctum.",
	"repeat_defeat": "The party already earned the consolation for this. Another loss earns nothing.",
}

## Count line of the path-end "Fights won" row.
const ENCOUNTERS_COUNT := "Fights won on this path: %d."
## Defeat card line when the packs were lost, and the lines of the found-Ase cards (%d is the base amount).
const PACKS_LOST_LINE := "The party fell, and the packs were lost."
const SITUATION_MONEY := "They found %d Ase. It goes in the packs."
const SITUATION_CLAIMANT_GOOD := "The party was given %d Ase for the way. It goes in the packs."

const REPLAY_FIGHT := "The party has been here before. It earns less."
const REPLAY_STAGE := "The party has been here before. All of it earns less."
const OBJECTIVES := "Only objectives the party found and overcame earn Ase."


static func has_cause(cause: String) -> bool:
	return cause == "replay" or cause == "objectives_overcome" or cause == "encounters_overcome" or TEXT.has(cause)


## The row name for a cause, or `fallback` (the backend label) when the cause keeps its label.
static func row_name(cause: String, fallback: String) -> String:
	return str(ROW_NAMES.get(cause, fallback))


## The tooltip text, or "" when the cause is unknown.
static func tooltip(cause: String, params: Dictionary = {}, scope: String = SCOPE_FIGHT) -> String:
	if cause == "replay":
		return REPLAY_STAGE if scope == SCOPE_STAGE else REPLAY_FIGHT
	if cause == "objectives_overcome":
		if params.has("overcome") and params.has("total"):
			return "%s %d of %d so far." % [OBJECTIVES, int(params["overcome"]), int(params["total"])]
		return OBJECTIVES
	if cause == "encounters_overcome":
		return ENCOUNTERS_COUNT % int(params["count"]) if params.has("count") else ""
	return str(TEXT.get(cause, ""))


## A second line under a row, or "" when the row has none. PROPOSAL placeholder wording.
## `lost` holds display names; the row shows them once, with no figure.
static func row_note(cause: String, params: Dictionary) -> String:
	if cause != "echoes_alive":
		return ""
	var lost_v: Variant = params.get("lost", [])
	var names: Array = []
	if lost_v is Array:
		for n in (lost_v as Array):
			if not str(n).is_empty():
				names.append(str(n))
	if names.is_empty():
		return ""
	return lost_line_many(names)


## PROPOSAL placeholders for the Direction E cards (docs/stories/v2-payout-explanation/decisions.md).
## Jeff owns the wording. Every string below is a placeholder, not approved copy.
const ALIVE_TAG := "alive"
const THREAD_WHOLE := "The Thread is whole so far."
const INTEL_LEARNED := "The party learned something new about the path."
const OBJECTIVE_MARK := "Found and overcome."
## One line about what the fight changed. Only for a real event in emotion_summary; first match wins.
## [name(s), singular form, plural form] by emotion_summary tag or direction.
const CHANGE_LINES: Array = [
	["ko", "%s fell.", "%s fell."],
	["refused", "%s held back.", "%s held back."],
	["fall", "%s was shaken.", "%s were shaken."],
]


## The story mark for the objective this fight overcame. The label comes from data; with no label
## only the frame text shows. Never the index or the type.
static func objective_line(label: String) -> String:
	return OBJECTIVE_MARK if label.is_empty() else "%s %s" % [OBJECTIVE_MARK, label]


static func lost_line(who: String) -> String:
	return "%s did not make it back." % who


static func lost_line_many(names: Array) -> String:
	return lost_line(_join_names(names))


static func home_count(alive: int, started: int) -> String:
	return "%s %d of %d" % [ALIVE_TAG, alive, started]


static func _join_names(names: Array) -> String:
	if names.size() == 1:
		return str(names[0])
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## The change line for a win, or "" when emotion_summary reports no event.
static func change_line(emotion_summary: Array) -> String:
	for rule in CHANGE_LINES:
		var names: Array = []
		for entry_v in emotion_summary:
			if not entry_v is Dictionary:
				continue
			var entry: Dictionary = entry_v
			var hit: bool = str(entry.get("tag", "")) == rule[0] or \
				(rule[0] == "fall" and str(entry.get("direction", "")) == "fall" and str(entry.get("tag", "")).is_empty())
			if hit and not str(entry.get("name", "")).is_empty():
				names.append(str(entry["name"]))
		if not names.is_empty():
			return str(rule[1] if names.size() == 1 else rule[2]) % _join_names(names)
	return ""
