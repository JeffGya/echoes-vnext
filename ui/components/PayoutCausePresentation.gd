extends RefCounted

## Maps a payout row `cause` id (and its `params`) to the row name and the tooltip text on the
## Resolve card. Wording approved by Jeff: docs/stories/v2-payout-explanation/decisions.md.
## Word rule (D-04): Ase and Ekwan are "earned", never "paid". Objectives are "found and
## overcome", never "won". A cause that is not listed has no tooltip and keeps its backend label.

const SCOPE_FIGHT := "fight"
const SCOPE_STAGE := "stage"

## Row names. enemies_defeated and echoes_alive are absent on purpose: their backend label
## carries the count ("3 enemies defeated"), so the row keeps it.
const ROW_NAMES: Dictionary = {
	"bonus_earned": "Bonus",
	"bonus_missed": "Bonus",
	"replay": "Replay",
	"defeat_consolation": "Consolation",
	"repeat_defeat": "Consolation",
	"partial_retreat": "Carried home",
	"partial_return_home": "Carried home",
	"nothing_overcome_yet": "Carried home",
	"objectives_overcome": "Objectives overcome",
	"realm_virtue": "Realm virtue",
}

const TEXT: Dictionary = {
	"enemies_defeated": "Each enemy the party defeats earns Ase.",
	"echoes_alive": "Each Echo still standing when the fight ends earns Ase.",
	"bonus_missed": "The party was not quick enough to earn a bonus.",
	"bonus_earned": "The party was quick enough to earn a bonus.",
	"realm_virtue": "The realm rewards the virtue the party showed here.",
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
