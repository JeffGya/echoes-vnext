# V2-ITEM-001 design round 2 (game-feel-developer)

Written in STE. Design only. I ran no code. D-01 to D-11 bind this design.
Tags: READ = from a file I opened. ASSUMED = not verified. Research labels are quoted from `research-comparison.md` (evidence LOW overall).
All player text is PROPOSAL. Jeff owns copy. Word rules (ANSWERS #86): no "home", no "stage", no "banked", "settled" or "roll" in text. Say Sanctum, path, lost.

## 0. Findings first

1. D-11 changes round 1. The departure chip is now actionable. Path signals stay quiet.
2. Two round 1 leave lines disagree (section 7, conflict 2).
3. Items never join the existing line `In their packs: 4 Ase and 2 Ekwan.` (READ: `CarriedHomePresentation.gathered_line`; D-06).
4. Sound: ASSUMED: no audio layer exists. Sound items are hints only.

## 1. Cap pressure feel (question 1)

### 1.1 The five points, judged

| # | Point | Weight | Recommendation | Reason | Risk |
|---|---|---|---|---|---|
| 1 | Sanctum inventory view | Reference, calm | Keep. A gauge plus a count. The full state changes shape, not alarm colour. | The player studies this view at rest. It can carry detail. | Low. |
| 2 | Departure chip | Compact, actionable (D-11) | Show it when room is at or below `warn_room_at`. Quiet at low pressure. At room 0 it gets a gold outline and a tap target. A tap opens the inventory view. | This is the only point where the player can act. It is where pressure is first felt. | The player leaves party prep and may lose context. Party prep state must survive the round trip (ASSUMED). |
| 3 | Packs on the path | World behavior, quiet | The packs bundle reads fuller. A joining item that will not fit shows a mark. No text on the tile. Detail in the tooltip. | The player cannot act here. Weight must stay low. | A strong mark would look like a block. |
| 4 | Leave confirmation | Compact | Item tiles with marks, then one line that agrees with them. | The choice needs the stakes in view. | Text bulk. |
| 5 | Path-end card | Record | Each item shows stored or lost with a reason mark. | The loss must be an explicit event (D-04). | Pile-up of marks on a defeat card (section 2). |

Pressure is first felt at point 2 when the cap is near full at party prep, else at point 3. It must never first appear at point 5. That is the Darkest Dungeon failure (pitfall "Silent loss at a full cap", evidence Medium).

### 1.2 Packs read fuller (world behavior first)

Idea: a room strip in the packs. It is a row of empty sockets, one per free Sanctum slot (8 shown at most; more shows a bar). Each unique item that joins fills a socket from the left.

| Beat | Motion | Duration |
|---|---|---|
| Item joins and fits | The tile drops into the next socket. It overshoots 4 units, then rests. The bundle swells 3 percent and returns. | 0.25 to 0.35 s, `TRANS_SINE`, `EASE_OUT` |
| Item joins and does not fit | The tile drops, then rests half out of the strip, beside the last socket. It dims to about 65 percent. A hollow ring mark shows on its corner. No overshoot. | 0.30 to 0.40 s, same easing |
| Strip becomes full | The last socket fills. The strip outline changes from soft blue to gold. No flash. | 0.4 s |
| Tap or hover on the tile | Tooltip: `There is no room for this in the Sanctum.` | At once |

Colour: Info soft blue `#7AB5C8` for the ring and the strip (READ: `docs/Living_Grove_Design_System.md`). The mark is a shape, not colour alone. Gold only at room 0.

Avoid: red or orange on the path, shake, flash, looping pulses, a rising tone, a modal or toast on join, and text on the tile.

Risk: the strip puts Sanctum room inside the packs. Mitigation: a Sanctum glyph at the strip start.

## 2. How a lost item feels (question 2)

Common rules for all three beats:
1. The same motion language means "lost": the tile lifts 8 units and fades to 35 percent over 0.5 s, `EASE_OUT`. It does not drop, shatter, burn or strike through.
2. The same mark language: the hollow ring. A carried item gets a Sanctum glyph.
3. No red. No sting. Tone: a leaf let go, not a penalty.
4. Every card is tappable from its first frame. A tap completes the animation. Each motion needs a no-motion fallback (ASSUMED: no reduced-motion setting exists).

## 2.1 Early leave (nothing, some, everything)

| Outcome | What the player sees | Time |
|---|---|---|
| Some | The tiles resolve one after another, in packs-row order. Each draws alone, so each tile gets its own beat: 0.30 s hold, then carried (slides toward the Sanctum glyph, 0.3 s) or lost (lift and fade, 0.5 s). Stagger 0.25 s. | Up to 1.8 s total. Over 7 items: stagger 0.1 s. |
| Nothing | All tiles lift and fade together. One beat, no stagger. | 0.6 s |
| Everything | All tiles slide together. Then intake runs (2.2). | 0.5 s |

Sound hint: a soft falling tone per lost tile. Never the defeat sound.
Lines (PROPOSAL): `Lost. They did not get it out.` per lost tile (tooltip). Card line stays the existing settle line (`Some of it got out`).
Risk: a long row delays the card. Mitigation: the 1.8 s cap and tap-to-finish.

### 2.2 Overflow at intake

Overflow only happens on the path-end card, after the leave result, in packs-row order. The stored items settle first (0.25 s each). A tile with no room reaches the Sanctum glyph, stops, holds 0.3 s, then lifts and fades (0.5 s). The hold is the beat: it reads as "it did not fit".
Line (PROPOSAL): `Lost. There was no room.`
Risk: two losses in a row (leave, then overflow). Mitigation: ring marks show on the leave confirmation.

### 2.3 Defeat

No per-item show. A defeat already ends the path with weight. The existing line is `The party fell, and the packs were lost.` (READ: `phase7-copy-final.md` section 5).
Beat: the packs tiles dim together over 0.8 s, with no stagger and no per-item line. The Sanctum tiles do not change.
Add one calming line (PROPOSAL): `What is in the Sanctum is safe.`
Reason: a defeat should not add a lecture. Held items never move on a defeat, and saying so is true. The line shows only when the Sanctum holds a piece.

## 3. The free-a-slot action (question 3, D-11)

### 3.1 Placement

1. The player taps a unique tile. The tile gets a selection outline. A detail strip at the bottom of the view shows the name, the grade mark, and one secondary button.
2. Button label (PROPOSAL): `Let it go`. Quiet style: text button with a thin border. Height 48 or more. Not gold.
3. The button is not on the tile. No swipe, no long press and no drag discard. These are accident routes on touch.
4. Stack tiles show no button (D-11: unique pieces only). Stacks do not use the unique cap (D-05). A stack at its limit is not relieved by this action.
5. The button shows for any selected unique piece, even with room left. Hiding it until full would hide the rule. At full cap it gets a thin gold outline.

### 3.2 Confirmation

Use the layer-40 `ModalHost` (READ: AGENTS.md UI Rules). It restores focus on dismissal.

| Part | Spec |
|---|---|
| Content | The tile at large size, its name, its grade mark. |
| Line (PROPOSAL) | `Let this go? It cannot be brought back.` |
| Buttons | `Keep it` (primary look, height 56, default focus). `Let it go` (secondary, height 48). |
| Spacing | At least 24 units apart, side by side. Not stacked in the same tap zone. |


No hold-to-confirm: a hold is hard for some players. Default focus on `Keep it` is enough.

### 3.3 What happens to the tile

1. Modal closes (0.15 s). The tile lifts 8 units and fades (0.5 s), the same "lost" motion as section 2.
3. Neighbour tiles slide to close the gap (0.25 s, after the fade starts).
4. The count falls with a 0.15 s change. The gauge eases down (0.3 s). A full state clears with the same easing.
5. Selection moves to the nearest tile. The button ignores taps for 0.6 s. This prevents a second accidental discard.
No coin sound and no yield text: there is no sell (D-02) and no recycle.

### 3.4 Reach from the departure chip

The chip is a shortcut, not a second discard. A tap opens the Sanctum inventory view with the selection mode on. Only one place discards and only one confirmation exists. Reason: one save write, one choke point, one test.
Risk: two taps from party prep. Accept. ASSUMED: party prep state is kept.

### 3.5 Nothing to discard

No pieces and no stacks: an empty view with one line (PROPOSAL): `Nothing is stored yet.` Only stacks: no button appears. Never a disabled grey button; it invites taps. When ITEM-003 sets `held_by`, an equipped piece must not show the button.

## 4. Reading at a glance (question 4)

A two-second glance answers: am I full, what do I have, is anything at its limit?

| Rank | Element | Form |
|---|---|---|
| 1 | Cap gauge | A bar plus `12 / 20`. A notch marks `warn_room_at`. Full state: the bar is solid and the frame gets a small notch badge. Shape change, not colour alone. |
| 2 | Tile grid | Grouped by kind, then by type, then by mint order. Tile 72 units at 1920x1080, 64 at 1280x720. Gap 8 or more. Targets stay at least 48. |
| 3 | Stack badge | `x7` bottom right. At limit: the badge becomes a solid capsule with an underline bar. Text and shape both change. |
| 4 | Ase and Ekwan line | Separate. It stays in the existing line style, never as tiles. |
| 5 | Threads | Not shown. They are not items (round 1 section 5). |

The Ase and Ekwan line sits in its own region with its own type, so a count of Ase is not read as a stack. Materials show a quantity badge only (D-06).

### Telling gear 1.1 from gear 1.2 without ids (D-01)

1. Order: pieces of one type sit in mint order, oldest first.
2. Twin mark: a small corner notch from the piece's mint sequence (one of six simple shapes). Siblings differ. It has no meaning, grade or rank. Core sends it as `mark_index`. The id never reaches the UI.
3. The grade mark is separate: pips in the other corner.
Risk: players read a notch as quality. Mitigation: shapes with no order, kept dim.

## 5. Placeholder look (question 5)

Plain, honest, unmistakable:

1. Flat grey-cream tile with a diagonal hatch. The hatch exists nowhere in the art direction.
2. A dashed outline, not the Living Grove border.
3. One plain shape per kind: square gear, diamond relic, circle consumable, triangle material. No gold, no terracotta, no Adinkra (READ: `docs/art-direction.md:230`).
4. Names such as `Test piece A`. No weapon names.
5. Twin notch and grade mark still show, so views prove order and grade.
6. Tiles load only from the test fixture and debug producer, never from a new save.

Structure stays in `.tscn` and the theme (AGENTS.md). ASSUMED: simple shape textures in a marked placeholder folder are acceptable.

## 6. Play test checklist for Jeff

1. Open the Sanctum inventory view with 0, then 3, then a full set of pieces. Does a glance tell you "full" within two seconds?
2. Does a full cap look calm in the view and quiet on the path? Nothing should look like an error.
3. Prepare a party with room at the threshold. Is the chip noticed but not annoying?
4. Tap the chip. Do you reach the inventory view in one tap? Can you return without losing the party?
5. Free a slot. Is the confirmation clear? Can you discard by accident with a quick double tap? (It should not be possible.)
6. Open the leave confirmation with items and a full cap. Do the lines agree with each other?
7. Leave early with 4 items, several times. Does each tile feel like its own chance? Does the lost beat feel warm, not punishing?
8. Let items overflow at the path end. Did you see it coming? Does the hold-then-fade beat read as "it did not fit"?
9. Lose a fight with items in the packs. Is the line `What is in the Sanctum is safe.` a comfort or noise?
10. At 1280x720, can you tell two gear pieces of one type apart, with no text? Do the Ase and Ekwan line and the item tiles look like different things?

## 7. Conflicts and dependencies with round 1

### Conflicts

| # | Round 1 | My position | Reason |
|---|---|---|---|
| 1 | Cap warning is not actionable (section 1). | Superseded by D-11. The departure chip is actionable. The path signals stay non-actionable. | D-11 adds the discard. UI rule: weight follows urgency. |
| 2 | Three leave-confirmation lines (risk, finish, room). | Show item tiles with marks, then one line. | `they carry all of it` contradicts `the rest will be lost` when the cap is short. Three lines are also text-heavy beside the existing risk line. |
| 3 | Tag text on the joining item: `No room. It will be lost.` | A ring mark. The text goes to the tooltip: `There is no room for this in the Sanctum.` | Text on a tile fails at 1280x720. `It will be lost` is also too sure: a leave or a defeat may change the result first. |
| 4 | `Lost. They left too soon.` | `Lost. They did not get it out.` | "Too soon" blames the player. It also does not fit a defeat or an overflow. |
| 5 | `Also in their packs: %d things.` | Use tiles. Drop the count line. | A count of "things" is reference text. Tiles are the visual-first channel. |
| 6 | Discard is "unique pieces only" is left open. | Unique pieces only. | Stacks do not use the unique cap. |

### Dependencies

1. The packs snapshot must carry per-item fate, reason key and display order. My beats follow that order.
2. The snapshot needs projected Sanctum room, so the strip, the ring marks and the leave confirmation can show the same fact. Before a leave it must say "may not fit" (round 1 section 1 tag exactness).
3. `mark_index` must reach the tile from core. The id must not.
4. A `can_discard` flag per tile lets ITEM-003 block equipped pieces later.
5. `warn_room_at` and the cap number come from Jeff (D-05).

## OPEN — questions and assumptions

- ASSUMED: The packs view can host a Sanctum room strip. `ui-ux-designer` confirms.
- ASSUMED: Party prep state survives a round trip to the inventory view.
- ASSUMED: No audio layer and no reduced-motion setting exist. Sound items are hints only.
- ASSUMED: `held_by` is always empty in this story, so no equipped-piece guard is needed yet.
- BLOCKED: The cap number and `warn_room_at` (Jeff, D-05). The grid may need paging above about 24.
- BLOCKED: Does Jeff accept one shared "lost" motion and the line `What is in the Sanctum is safe.` on a defeat card? This is copy and tone. Jeff decides.
- BLOCKED: Does Jeff accept the chip as a shortcut only, with the discard in one place?
