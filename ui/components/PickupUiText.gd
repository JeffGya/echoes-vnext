class_name PickupUiText
extends RefCounted

## Player-facing text of the pickup event (V2-ITEM-001b). Core emits keys; this module maps keys to text.
## EVERY LINE BELOW IS AN AGENT-WRITTEN PROPOSAL until Jeff reviews all copy once at the end (ANSWERS #89, D-56).
## tests/fixtures/PickupUiProposedCopy.json pins each line; a test compares both ways. Item words (kind, grade, pack
## word) come from ItemUiText and are not repeated here. Never "home" or "stage" in a line (ANSWERS #86). No id as text.
## An unknown key gives "". A line that is "" on purpose is marked in the fixture.

const ItemUiText := preload("res://ui/components/ItemUiText.gd")

# UNWIRED (target: NEW "Pickup swap reactions"): the mockup's six chooser replies after a swap (TXT.react) need a temper key from the core; none exists, so only line.swap_done shows
const LINES: Dictionary = {
	# Chooser barks. Key = bark.<group>.<variant>.
	"bark.froze.0": "Just grab it. Grab it and go.",
	"bark.afraid.0": "I want to leave here.",
	"bark.full.0": "My pack is full.",
	"bark.full.1": "No room in the pack. I can't take more.",
	"bark.fits.0": "Room for all of it. Good.",
	"bark.fits.1": "That's everything. Easy.",
	"bark.some.0": "Took what I could carry.",
	"bark.some.1": "I wish I had more room.",
	"bark.some_low.0": "Is this one okay? I'll take this one.",
	"bark.some_high.0": "This one. Leave the rest.",
	# Lines in the event
	"line.swap_done": "Swapped. The other one stays behind.",
	"line.pick": "Pick one to trade.",
	# Buttons
	"btn.swap": "Swap",
	"btn.swap_confirm": "Swap them",
	"btn.keep": "Keep as it is",
	"btn.continue": "Continue",
	"btn.skip": "Skip",
	"btn.back": "Back",
	"btn.close": "Close",
	"btn.leave": "Leave",
	"btn.stay": "Stay",
	"leave.prompt": "Leave these behind?",
	# Details
	"where.ground": "On the ground",
	"where.carried": "Carried",
	"count.one": "1 piece",
	# Pack strip
	"allow.swap_left": "1 swap left on this path.",
	"allow.swap_none": "No swap left.",
	# Refusals a player can reach. "refuse.frozen" is "" on purpose: a frozen chooser shows no Swap button (D-54).
	"refuse.used": "The swap is used.",
	"refuse.has_room": "The pack has room.",
	"refuse.nothing_left": "Nothing is left to swap.",
	"refuse.same": "These two are the same.",
	"refuse.no_target": "Nothing here can be swapped.",
	"refuse.frozen": "",
	# Screen reader names
	"a11y.sealed": "Sealed item",
	"a11y.empty_slot": "Empty slot",
	"a11y.on_ground": ", on the ground",
	"a11y.held_up": ", held up",
	"a11y.in_pack": ", in the pack",
	"a11y.details": "Item details",
	"a11y.board": "Combat board after the fight",
}

# Presentation only: they choose one bark; the pick rule never reads them; values from the approved mockup;
# Jeff reviews them with the copy (D-56). This is the documented reason that keeps them out of data/balance.json (ANSWERS #83).
const STANDING_LOW_MAX := 2
const STANDING_HIGH_MIN := 9


static func line(key: String) -> String:
	return str(LINES.get(key, ""))


static func standing_band(standing: int) -> String:
	if standing <= STANDING_LOW_MAX:
		return "low"
	return "high" if standing >= STANDING_HIGH_MIN else "mid"


## Bark for the chosen Echo. `case_key`, `reaction` and `reason` are the snapshot keys `case`, `reaction` and `reason`;
## `band` is standing_band(). `variant` picks between two lines (use the chooser's place in `row`; it wraps).
## The reasons identity, sense and state share the same barks: only the case, the reaction and the band change the line.
static func bark(case_key: String, reaction: String, reason: String, band: String, variant: int = 0) -> String:
	var group := ""
	if reason == "froze" or case_key == "frozen":
		group = "froze"
	elif case_key == "C5":
		group = "afraid" if reaction == "none" else "full"
	elif case_key == "C1" or case_key == "C3":
		group = "fits"
	elif case_key == "C2" or case_key == "C4":
		group = "some_" + band if band == "low" or band == "high" else "some"
	else:
		return ""
	var count := 0
	while LINES.has("bark.%s.%d" % [group, count]):
		count += 1
	return str(LINES["bark.%s.%d" % [group, posmod(variant, count)]]) if count > 0 else ""


## Refusal reason key -> line. The keys bad_pair, ended, not_selectable, not_partner, wrong_phase, no_event, not_pickup
## and bad_payload are not expected through this UI, so they show nothing (a later step may add a line).
static func refusal(key: String) -> String:
	return line("refuse." + key)


## `where` keys (ground, carried, pack) and the item status `lost` belong to U5 and U7. `lost` has no word yet: ANSWERS #86 reserves it.
static func where_text(where: String) -> String:
	return ItemUiText.WHERE_PACK if where == "pack" else line("where." + where)


static func count_text(quantity: int, limit: int) -> String:
	return line("count.one") if quantity <= 1 else ItemUiText.stack_count(quantity, limit)


## Pack strip word by snapshot tone: plain, near, full.
static func tone_word(tone: String) -> String:
	match tone:
		"full":
			return ItemUiText.FULL_WORD
		"near":
			return ItemUiText.PACK_NEAR
	return ""


static func swap_allowance(left: int) -> String:
	return line("allow.swap_left") if left > 0 else line("allow.swap_none")


static func destroy_allowance(left: int) -> String:
	return ItemUiText.PATH_LEFT if left > 0 else ItemUiText.PATH_USED


## Screen reader name of a visible item. `where` is ground, carried or pack.
static func item_label(item_name: String, where: String) -> String:
	match where:
		"ground":
			return item_name + line("a11y.on_ground")
		"carried":
			return item_name + line("a11y.held_up")
		"pack":
			return item_name + line("a11y.in_pack")
	return item_name
