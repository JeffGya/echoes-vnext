extends RefCounted

## Strings for the return-home and retreat decisions (Direction E, mockups/stage-flow-motion.html
## step 4). Every string here is a PROPOSAL placeholder, not approved copy: Jeff owns the wording
## (docs/stories/v2-payout-explanation/decisions.md). Amounts always come from the snapshot.
## Word rule: "carried", never "lost". Ase and Ekwan are "earned", never "paid".

const CARRIED := "Carried home"
const ADVANCE_NOTE := "The rest is earned when the stage is finished."
const STAGE_WAITS := "The stage waits."
const WITH_PARTY := "With the party"
const RETURN_COST := "Going home costs nothing."
const RETREAT_UNAFFORDABLE := "Not enough Ase"


static func ase_line(amount: int) -> String:
	return "+%d Ase" % amount


static func ekwan_line(amount: int) -> String:
	return "+%d Ekwan" % amount


static func party_line(entry: Dictionary) -> String:
	var who := str(entry.get("name", ""))
	var status := str(entry.get("emotional_status", ""))
	if who.is_empty():
		return ""
	return who if status.is_empty() else "%s — %s" % [who, EmotionPresentation.display_name(status)]


## The price on a retreat button. `affordable` false adds the reason on a second line, so a
## disabled button never relies on colour alone.
static func retreat_label(ase_cost: int, second_line: String) -> String:
	return "Retreat (%d Ase)\n%s" % [ase_cost, second_line]


## One plain line after a refused retreat (no scolding). Both numbers come from data.retreat_denied.
static func retreat_denied_line(ase_cost: int, ase_balance: int) -> String:
	return "Retreating takes %d Ase. The party has %d." % [ase_cost, ase_balance]
