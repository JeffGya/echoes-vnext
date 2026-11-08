extends RefCounted

## Every player-facing string of the item screens (panels, tile names, modal, result cards).
## Wording is Jeff's (docs/stories/v2-item-001/copy-approval-jeff.md, D-51). Rule for this file: each string line ends with
## `# APPROVED (Jeff 2026-11-08)`. A test compares every string with tests/fixtures/ItemUiApprovedCopy.json. Change a word only
## with a new approval. No id is ever shown as text.

# ── Rail, panel titles ─────────────────────────────────────────
const RAIL_LABEL := "Storehouse"  # APPROVED (Jeff 2026-11-08)
const SANCT_TITLE := "Storehouse"  # APPROVED (Jeff 2026-11-08)
const PACK_TITLE := "Travel pack"  # APPROVED (Jeff 2026-11-08)
const SHOW_PACK := "Open pack"  # APPROVED (Jeff 2026-11-08)
const HIDE_PACK := "Close pack"  # APPROVED (Jeff 2026-11-08)
const CLOSE_SANCT := "Close the storehouse"  # APPROVED (Jeff 2026-11-08)
const CLOSE_PACK := "Close the pack"  # APPROVED (Jeff 2026-11-08)
const PARTY_PACK_BUTTON := "Travel pack"  # APPROVED (Jeff 2026-11-08)
const FULL_WORD := "Full"  # APPROVED (Jeff 2026-11-08)

# ── Pack level words and the departure line ────────────────────
const PACK_FULL_PATH := "Pack is full. Nothing else fits."  # APPROVED (Jeff 2026-11-08)
const PACK_NEAR := "Almost full."  # APPROVED (Jeff 2026-11-08)
const DEPART_LINE := "There are items in the travel pack. Items can be lost."  # APPROVED (Jeff 2026-11-08)

# ── Details area ───────────────────────────────────────────────
const DETAILS_EMPTY := "Select an item to learn more."  # APPROVED (Jeff 2026-11-08)
const WHERE_SANCT := "Storehouse"  # APPROVED (Jeff 2026-11-08)
const WHERE_PACK := "Pack"  # APPROVED (Jeff 2026-11-08)
const KIND_LABEL := "Kind"  # APPROVED (Jeff 2026-11-08)
const GRADE_LABEL := "Grade"  # APPROVED (Jeff 2026-11-08)
const COUNT_LABEL := "Count"  # APPROVED (Jeff 2026-11-08)
const AT_LIMIT := "Full stack"  # APPROVED (Jeff 2026-11-08)
const BTN_MOVE_PACK := "Put in pack"  # APPROVED (Jeff 2026-11-08)
const BTN_MOVE_SANCT := "Place in storehouse"  # APPROVED (Jeff 2026-11-08)
const BTN_LET_GO := "Destroy"  # APPROVED (Jeff 2026-11-08)
const BTN_KEEP := "Keep"  # APPROVED (Jeff 2026-11-08)
const PATH_LEFT := "1 destroy action left on this path."  # APPROVED (Jeff 2026-11-08)
const PATH_USED := "No destroy action left."  # APPROVED (Jeff 2026-11-08)
const PATH_HINT := "While on the move you can't reorganize your pack."  # APPROVED (Jeff 2026-11-08)

const KIND_NAMES: Dictionary = {
	"gear": "Gear",  # APPROVED (Jeff 2026-11-08)
	"relic": "Relic",  # APPROVED (Jeff 2026-11-08)
	"consumable": "Supply",  # APPROVED (Jeff 2026-11-08)
	"material": "Material",  # APPROVED (Jeff 2026-11-08)
}

# ── Refusal lines, by core reason key (shown in the panel) ─────
const R_PATH := "While on the move you can't organize your pack."  # APPROVED (Jeff 2026-11-08)
const R_PACK_FULL := "The pack is full."  # APPROVED (Jeff 2026-11-08)
const R_SANCT_FULL := "The storehouse is full."  # APPROVED (Jeff 2026-11-08)
const R_DISCARD_USED := "No destroy actions left."  # APPROVED (Jeff 2026-11-08)
const R_OCCUPIED := "This spot is taken. Choose an empty spot."  # APPROVED (Jeff 2026-11-08)
const R_TYPE := "Only similar items can be joined."  # APPROVED (Jeff 2026-11-08)
const R_STACK_LIMIT := "This stack is already full."  # APPROVED (Jeff 2026-11-08)
const R_EQUIPPED := "This is in use."  # APPROVED (Jeff 2026-11-08)
const R_SANCTUM_ONLY := "This can only be done in the Sanctum."  # APPROVED (Jeff 2026-11-08)
const R_NO_CHANGE := "Nothing changed."  # APPROVED (Jeff 2026-11-08)
const R_GONE := "It's no longer there."  # APPROVED (Jeff 2026-11-08)
const R_BAD_SLOT := "That spot is not available."  # APPROVED (Jeff 2026-11-08)
const R_COUNT := "This is not possible."  # APPROVED (Jeff 2026-11-08)
const R_UNKNOWN := "Nothing was changed."  # APPROVED (Jeff 2026-11-08)

# ── Drop hints ─────────────────────────────────────────────────
const DROP_REORDER := "Drop to place"  # APPROVED (Jeff 2026-11-08)
const DROP_MERGE := "Drop to combine"  # APPROVED (Jeff 2026-11-08)
const DROP_PACK := "Move to pack"  # APPROVED (Jeff 2026-11-08)
const DROP_SANCT := "Move to storehouse"  # APPROVED (Jeff 2026-11-08)

# ── Destroy confirmation ───────────────────────────────────────
const MODAL_TITLE := "Are you sure?"  # APPROVED (Jeff 2026-11-08)
const MODAL_PATH_LINE := "There is only 1 chance to destroy on this path."  # APPROVED (Jeff 2026-11-08)
const MODAL_COUNT_LABEL := "How many?"  # APPROVED (Jeff 2026-11-08)
const COUNT_FEWER := "One less"  # APPROVED (Jeff 2026-11-08)
const COUNT_MORE := "One more"  # APPROVED (Jeff 2026-11-08)

# ── Leave confirmation and result cards ────────────────────────
const CARD_SURVIVED := "Made it through."  # APPROVED (Jeff 2026-11-08)
const CARD_LOST := "Lost"  # APPROVED (Jeff 2026-11-08)

## Refusal reason key -> line. `box` is the target container of a move ("sanctum" or "pack"). `not_in_pack` has no
## line of its own (Jeff: it should not be possible), so it gives the unknown line.
static func reason_text(key: String, box: String = "") -> String:
	match key:
		"path_open":
			return R_PATH
		"container_full":
			return R_PACK_FULL if box == "pack" else R_SANCT_FULL
		"path_used":
			return R_DISCARD_USED
		"slot_taken":
			return R_OCCUPIED
		"type_mismatch":
			return R_TYPE
		"stack_limit":
			return R_STACK_LIMIT
		"equipped":
			return R_EQUIPPED
		"not_in_sanctum":
			return R_SANCTUM_ONLY
		"no_change":
			return R_NO_CHANGE
		"unknown_entry", "not_found":
			return R_GONE
		"bad_slot":
			return R_BAD_SLOT
		"count_range":
			return R_COUNT
	return R_UNKNOWN


static func kind_name(kind: String) -> String:
	return str(KIND_NAMES.get(kind, ""))


static func slots_word(used: int, total: int) -> String:
	return "%d / %d spots filled" % [used, total]  # APPROVED (Jeff 2026-11-08)


static func sockets_word(used: int, total: int) -> String:
	return "%d / %d spots filled" % [used, total]  # APPROVED (Jeff 2026-11-08)


static func stack_count(count: int, limit: int) -> String:
	return "x%d of %d" % [count, limit]  # APPROVED (Jeff 2026-11-08)


static func leave_risk(n: int) -> String:
	return "1 item can be lost." if n == 1 else "%d items can be lost" % n  # APPROVED (Jeff 2026-11-08)


## The name shown for a tile. The row `name` when it has one; else the kind word (never a type id).
static func display_name(row: Dictionary) -> String:
	var n := str(row.get("name", ""))
	if not n.is_empty():
		return n
	return kind_name(str(row.get("kind", "")))
