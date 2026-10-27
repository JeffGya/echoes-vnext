extends RefCounted

## Strings of the standoff card, the quiet-fight warning and the pre-battle line.
## The wording is the agent-written copy of docs/stories/v2-economy-004/phase7-copy-final.md (D-117),
## used exactly. Names and counts come from the snapshot. No percent, fraction or odds appear here.

const CarriedHomePresentation := preload("res://ui/components/CarriedHomePresentation.gd")

const TITLE := "Nobody moved"
const BODY_GENERIC := "Neither side would strike. The party stepped back."
const BODY_FROZE_ONE := "%s could not move. The party stepped back."
const BODY_FROZE_TWO := "%s and %s could not move. The party stepped back."
const BODY_BLOCKED := "No one could get through. The party stepped back."
const PACKS_LINE := "Their packs are as they were."
const OPEN_FIGHT_LINE := "The task is still there."
const CALM_LINE := "%s breathed out."
const REPEAT_HINT_1 := "It went the same way last time."
const REPEAT_HINT_2 := "Maybe they need rest."
const BTN_PATH := "Back to the path"
const BTN_SANCTUM := CarriedHomePresentation.CONFIRM_LABEL

const WARN_LEVEL_1 := "Nobody is moving."
const WARN_LEVEL_2 := "Nobody wants to go first."
const WARN_BARK := "Not yet. I can't."

const PREBATTLE_STALLED := "They stalled here before."


## The card body. A cause shows only with the names its line needs; anything else reads as generic.
static func body(cause: String, froze_names: Array) -> String:
	if cause == "froze" and froze_names.size() == 1:
		return BODY_FROZE_ONE % str(froze_names[0])
	if cause == "froze" and froze_names.size() >= 2:
		return BODY_FROZE_TWO % [str(froze_names[0]), str(froze_names[1])]
	if cause == "blocked":
		return BODY_BLOCKED
	return BODY_GENERIC


## "" when no name is given.
static func calm_line(names: Array) -> String:
	if names.is_empty():
		return ""
	return CALM_LINE % " and ".join(PackedStringArray(names.map(func(n: Variant) -> String: return str(n))))


## The first standoff has no hint. The second reads the first hint; later ones read the second.
static func repeat_hint(standoff_count: int) -> String:
	if standoff_count <= 1:
		return ""
	return REPEAT_HINT_1 if standoff_count == 2 else REPEAT_HINT_2
