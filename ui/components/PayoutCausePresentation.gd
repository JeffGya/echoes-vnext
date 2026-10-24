extends RefCounted

## Maps a payout row `cause` id (and its `params`) to the row name and the tooltip text on the
## Resolve card. Wording: docs/stories/v2-payout-explanation/decisions.md.
## Word rule (D-04): Ase and Ekwan are "earned", never "paid". Objectives are "found and
## overcome", never "won". A cause that is not listed has no tooltip and keeps its backend label.

const SCOPE_FIGHT := "fight"
const SCOPE_STAGE := "stage"

## Row names. A cause that is not listed keeps its backend label.
const ROW_NAMES: Dictionary = {
	"replay": "Replay",
	"defeat_consolation": "Consolation",
	"repeat_defeat": "Consolation",
	"partial_retreat": "Carried home",
	"partial_return_home": "Carried home",
	"nothing_overcome_yet": "Carried home",
	"objectives_overcome": "Objectives overcome",
	"echoes_alive": "Echoes home",
	"carried_advance": "Carried home",
}

## PROPOSAL placeholders, not approved copy: echoes_alive, carried_advance and the lost-names note
## (docs/stories/v2-payout-explanation/decisions.md). Jeff owns the wording. All copy stays in this table.
const TEXT: Dictionary = {
	"echoes_alive": "Each Echo that comes home earns Ase.",
	"carried_advance": "Ase and Ekwan the party carried home earlier are taken off the stage payout, so nothing is earned twice.",
	"defeat_consolation": "The party lost, but the fight still earns a small part.",
	"partial_retreat": "The party left early. It keeps a small part of what it overcame.",
	"partial_return_home": "The party left early. It keeps a small part of what it overcame.",
	"nothing_overcome_yet": "The party has not overcome anything yet. Nothing is earned.",
	"repeat_defeat": "The party already earned the consolation for this. Another loss earns nothing.",
}

const REPLAY_FIGHT := "The party has been here before. It earns less."
const REPLAY_STAGE := "The party has been here before. The whole stage earns less Ase and Ekwan."
const OBJECTIVES := "Only objectives the party found and overcame earn Ase."


static func has_cause(cause: String) -> bool:
	return cause == "replay" or cause == "objectives_overcome" or TEXT.has(cause)


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
	var who := str(names[0])
	if names.size() > 1:
		who = "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]
	return "%s did not come home." % who
