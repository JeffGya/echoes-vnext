extends RefCounted

## Every player-facing string of the item screens (panels, tile names, modal, result cards).
## ALL WORDING HERE IS PLACEHOLDER. Jeff writes the final text (D-34, ANSWERS #86). Rule for this file:
## each string line ends with `# PLACEHOLDER`. A test scans for it. No id is ever shown as text.

# ── Rail, panel titles ─────────────────────────────────────────
const RAIL_LABEL := "Stores"  # PLACEHOLDER
const SANCT_TITLE := "Sanctum storage"  # PLACEHOLDER
const SANCT_SUB := "House storage. Always safe."  # PLACEHOLDER
const PACK_TITLE := "Party pack"  # PLACEHOLDER
const PACK_SUB := "Goes with the party."  # PLACEHOLDER
const SHOW_PACK := "Show pack"  # PLACEHOLDER
const HIDE_PACK := "Hide pack"  # PLACEHOLDER
const CLOSE_SANCT := "Close Sanctum storage"  # PLACEHOLDER
const CLOSE_PACK := "Close party pack"  # PLACEHOLDER
const PARTY_PACK_BUTTON := "Party pack"  # PLACEHOLDER
const FULL_WORD := "Full"  # PLACEHOLDER

# ── Pack level words and the departure line ────────────────────
const PACK_HEAVY := "Heavy. They may lose what they carry."  # PLACEHOLDER
const PACK_FULL_PATH := "Full. Nothing more fits."  # PLACEHOLDER
const PACK_NEAR := "Nearly full."  # PLACEHOLDER
const DEPART_LINE := "Carried pieces can be lost on a defeat or an early leave."  # PLACEHOLDER
const AT_STAKE := "At stake: it can be lost."  # PLACEHOLDER
const AT_STAKE_LABEL := "At stake"  # PLACEHOLDER

# ── Details area ───────────────────────────────────────────────
const DETAILS_TITLE := "Details"  # PLACEHOLDER
const DETAILS_EMPTY := "Select a piece to see its details."  # PLACEHOLDER
const DETAILS_HINT := "Drag a piece to the other panel, or select it and press a Move button."  # PLACEHOLDER
const WHERE_SANCT := "In the Sanctum"  # PLACEHOLDER
const WHERE_PACK := "In the pack"  # PLACEHOLDER
const KIND_LABEL := "Kind"  # PLACEHOLDER
const GRADE_LABEL := "Grade"  # PLACEHOLDER
const COUNT_LABEL := "Count"  # PLACEHOLDER
const ONE_PIECE := "1 piece"  # PLACEHOLDER
const AT_LIMIT := "At the limit"  # PLACEHOLDER
const BTN_MOVE_PACK := "Move to pack"  # PLACEHOLDER
const BTN_MOVE_SANCT := "Move to Sanctum"  # PLACEHOLDER
const BTN_LET_GO := "Let it go"  # PLACEHOLDER
const BTN_KEEP := "Keep it"  # PLACEHOLDER
const PATH_READONLY := "On a path: read-only"  # PLACEHOLDER
const PATH_LEFT := "Let it go: 1 left this path"  # PLACEHOLDER
const PATH_USED := "Let it go: used"  # PLACEHOLDER
const PATH_HINT := "On a path, pieces cannot be moved."  # PLACEHOLDER
const PATH_RULE := "Only one piece may be let go on a path."  # PLACEHOLDER
const PATH_PREVIEW := "Preview. Read-only."  # PLACEHOLDER

const KIND_NAMES: Dictionary = {
	"gear": "Gear",  # PLACEHOLDER
	"relic": "Relic",  # PLACEHOLDER
	"consumable": "Consumable",  # PLACEHOLDER
	"material": "Material",  # PLACEHOLDER
}

# ── Refusal lines, by core reason key (shown in the panel) ─────
const R_PATH := "Moves are closed on a path."  # PLACEHOLDER
const R_PACK_FULL := "The pack is full. Free a socket first."  # PLACEHOLDER
const R_SANCT_FULL := "The Sanctum is full. Free a slot first."  # PLACEHOLDER
const R_DISCARD_USED := "The one discard of this path is used."  # PLACEHOLDER
const R_NOT_IN_PACK := "On a path only a piece in the pack can be let go."  # PLACEHOLDER
const R_OCCUPIED := "That slot is taken. Drop on an empty slot."  # PLACEHOLDER
const R_TYPE := "Only the same kind of stack can merge."  # PLACEHOLDER
const R_STACK_LIMIT := "That stack is at its limit."  # PLACEHOLDER
const R_EQUIPPED := "It is in use."  # PLACEHOLDER
const R_SANCTUM_ONLY := "This can only be done in the Sanctum."  # PLACEHOLDER
const R_NO_CHANGE := "Nothing changed."  # PLACEHOLDER
const R_GONE := "That piece is not there any more."  # PLACEHOLDER
const R_BAD_SLOT := "That slot is not available."  # PLACEHOLDER
const R_COUNT := "That count is not possible."  # PLACEHOLDER
const R_UNKNOWN := "That did not work. Nothing changed."  # PLACEHOLDER

# ── Drop hints ─────────────────────────────────────────────────
const DROP_REORDER := "Drop to place it in this slot"  # PLACEHOLDER
const DROP_MERGE := "Drop to merge the stacks"  # PLACEHOLDER
const DROP_PACK := "Drop to put it in the pack"  # PLACEHOLDER
const DROP_SANCT := "Drop to put it in the Sanctum"  # PLACEHOLDER

# ── Discard confirmation ───────────────────────────────────────
const MODAL_TITLE := "Let this go?"  # PLACEHOLDER
const MODAL_LINE := "It cannot be brought back."  # PLACEHOLDER
const MODAL_PATH_LINE := "This is the one discard of this path."  # PLACEHOLDER
const MODAL_PACK_LINE := "It is in the pack."  # PLACEHOLDER
const MODAL_SANCT_LINE := "It is in the Sanctum."  # PLACEHOLDER
const MODAL_COUNT_LABEL := "How many?"  # PLACEHOLDER
const COUNT_FEWER := "Fewer"  # PLACEHOLDER
const COUNT_MORE := "More"  # PLACEHOLDER

# ── Leave confirmation and result cards ────────────────────────
const LEAVE_RISK_LABEL := "At stake"  # PLACEHOLDER
const CARD_SURVIVED := "Survived"  # PLACEHOLDER
const CARD_LOST := "Lost"  # PLACEHOLDER
const CARD_PREVIEW := "Preview. Read-only."  # PLACEHOLDER
const ITEMS_GROUP_LABEL := "Pieces"  # PLACEHOLDER

## Refusal reason key -> line. `box` is the target container of a move ("sanctum" or "pack").
static func reason_text(key: String, box: String = "") -> String:
	match key:
		"path_open":
			return R_PATH
		"container_full":
			return R_PACK_FULL if box == "pack" else R_SANCT_FULL
		"path_used":
			return R_DISCARD_USED
		"not_in_pack":
			return R_NOT_IN_PACK
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
	return "%d / %d slots" % [used, total]  # PLACEHOLDER


static func sockets_word(used: int, total: int) -> String:
	return "%d / %d sockets" % [used, total]  # PLACEHOLDER


static func pack_button(count: int, total: int) -> String:
	return "%s %d/%d" % [PARTY_PACK_BUTTON, count, total]  # PLACEHOLDER


static func stack_count(count: int, limit: int) -> String:
	return "x%d of %d" % [count, limit]  # PLACEHOLDER


static func leave_risk(n: int) -> String:
	return "They may lose %d %s." % [n, "piece" if n == 1 else "pieces"]  # PLACEHOLDER


static func moved_toast(to_box: String) -> String:
	return "It is now in the %s." % ("pack" if to_box == "pack" else "Sanctum")  # PLACEHOLDER


## The name shown for a tile. The row `name` when it has one; else the kind word (never a type id).
static func display_name(row: Dictionary) -> String:
	var n := str(row.get("name", ""))
	if not n.is_empty():
		return n
	return kind_name(str(row.get("kind", "")))
