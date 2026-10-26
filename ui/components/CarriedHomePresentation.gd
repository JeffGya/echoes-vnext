extends RefCounted

## Strings for the return-to-the-Sanctum confirmation, the return and retreat cards and the retreat
## button. The wording is Jeff's (docs/stories/v2-economy-004/decisions.md D-107), used exactly.
## Amounts come from the snapshot. No percent, no fraction and no odds appear in any string here.

const CONFIRM_TITLE := "Return to the Sanctum"
const CONFIRM_QUESTION := "Take the party back to the Sanctum?"
const RISK_LINE := "Not all of it will survive the escape. What cannot be carried will be lost."
const CONFIRM_WARNING := "Escaping might be more difficult than expected. It might not be possible."
const KEEPS_LINE := "The path still waits."
const CONFIRM_LABEL := "To the Sanctum"
const CANCEL_LABEL := "Stay"
const FAILED_SUBTITLE := "No way out."
const RETREAT_UNAFFORDABLE := "Not enough Ase"

## Outcome line on the return card, by data.settle_outcome. "some" and "all" have no full stop.
const SETTLE_LINES: Dictionary = {
	"none": "Nothing got out.",
	"some": "Some of it got out",
	"all": "Everything got out",
	"nothing_new": "Nothing was gathered since the last time.",
}

const RETREAT_TITLE := "Pulled back"
const RETREAT_BODY := "Withdrawing. Back to the path."
const RETREAT_NO_REENTER := "It's not smart to re-enter this quickly."
const RETREAT_REENTER := "Our task is not done. This story is not over yet."


## "In their packs: 4 Ase and 2 Ekwan." A zero clause and its "and" are dropped. "" when both are 0.
static func gathered_line(ase: int, ekwan: int) -> String:
	var parts: Array[String] = []
	if ase > 0:
		parts.append("%d Ase" % ase)
	if ekwan > 0:
		parts.append("%d Ekwan" % ekwan)
	return "" if parts.is_empty() else "In their packs: %s." % " and ".join(parts)


static func settle_line(outcome: String) -> String:
	return str(SETTLE_LINES.get(outcome, ""))


static func retreat_line(can_reenter: bool) -> String:
	return RETREAT_REENTER if can_reenter else RETREAT_NO_REENTER


## The price on a retreat button. `reason` is "" when the button is enabled; a disabled button adds
## the reason on a second line, so it never relies on colour alone.
static func retreat_label(ase_cost: int, reason: String = "") -> String:
	var price := "Retreat (%d Ase)" % ase_cost
	return price if reason.is_empty() else "%s\n%s" % [price, reason]


## One plain line after a refused retreat (no scolding). Both numbers come from data.retreat_denied.
static func retreat_denied_line(ase_cost: int, ase_balance: int) -> String:
	return "Retreating takes %d Ase. The party has %d." % [ase_cost, ase_balance]
