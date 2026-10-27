# V2-ITEM-001 feel design (game-feel-developer, v2)

Written in STE. Design only. I ran no code and no Godot. D-01 to D-17 bind this design.
Tags: READ = from a file I opened. ASSUMED = not verified. Research is hypothesis only (`research-comparison.md`, evidence LOW).
All player text is PROPOSAL. Jeff owns copy. Word rules (ANSWERS #86): say Sanctum, path, lost. No "banked", "settled" or "roll" in text.
This design replaces `design-round2-game-feel-developer.md`, which predates D-11 to D-17.

## 0. Findings first

1. Pressure moved. Cap pressure is now PACK pressure (D-13, D-16, D-17). The Sanctum room strip of round 2 is dropped.
2. The new central beat is the Echo pick. It repeats every encounter, so it must be short.
3. READ: a reduced-motion switch exists (`ui/components/StopMarkMotion.gd:24`). Round 2 said none existed. Every motion below needs a 0.15 s fade path.
4. READ: no audio player exists in `ui/` or `core/`. Sound items are hints only.
5. Colour collision. READ: `docs/Living_Grove_Design_System.md:35-52`. Info soft blue `#7AB5C8` is also the Fearful emotion colour. I drop round 2's blue marks. Marks use shape and neutral ink. Gold means actionable or full.
6. The pick rule can make a wise Echo take a stack that is already at its Sanctum limit. That reads as a bug (section 1.5).

### Reused and dropped from round 2

| Idea | Verdict | Re-check |
|---|---|---|
| Shared lost motion | REUSED, one parameter | Section 4.1 |
| `Let it go` and `Keep it` default | REUSED | D-11 still asks for a confirmation |
| Twin mark (`mark_index`) | REUSED | D-01 needs twins to differ with no ids |
| Hatched placeholder tiles | REUSED | Section 7 |
| Departure chip as shortcut | REUSED, about the pack now | Section 3.1 |
| Sanctum room strip | DROPPED | Sockets now show pack room |
| Hollow ring "no room" mark | DROPPED | Left items use a ground line (1.3) |
| Defeat line `What is in the Sanctum is safe.` | DROPPED as default | Carried tiles stay lit instead (4.2) |
| Info blue marks | DROPPED | Finding 5 |

## 1. The Echoes choose (question 1)

Channel order: (1) world behavior, the chooser moves toward a find; (2) spatial UI, tiles drop into sockets or rest on a ground line; (3) compact UI, portrait badge and Standing glyph; (4) tooltips.

### 1.1 The beat

It plays on the encounter result card (ASSUMED; `ui-ux-designer` confirms).

| Case | What the player sees | Time |
|---|---|---|
| No finds | Nothing | 0 |
| Finds fit (no choice) | Tiles appear and drop into sockets together. A small portrait badge lands on each. The portrait does not walk. | 0.5 s |
| Finds exceed room (a real choice) | Finds appear in a row (0.3 s). The chooser portrait slides in (0.25 s). Per pick, the portrait leans to a tile and the tile rises into a socket (0.3 s). Left tiles sink to the ground line (0.3 s). | 1.3 s for one pick; cap 2.0 s |
| Free room 0 | Tiles appear and sink to the ground line. No walk. | 0.5 s |

A tap finishes the beat. The result is already saved. Why short: 3 s times ten encounters is 30 s of watching.

### 1.2 Left items

Left tiles rest on a thin ground line below the pack row, with a path glyph at its start. They keep full outline strength and 65 percent fill. They are not faded to the "lost" level: the swap can still take them. Three places, three meanings: sockets are with the party, the ground line is still on the path, a lost tile leaves.
PROPOSAL tooltips: `%s took this.` / `%s left this.`

### 1.3 Reading WHY, without numbers

Grade pips sit on every tile. A good pick: the highest pips are in sockets. A poor pick: higher pips sit on the ground line.
Stronger read: pick MANNER as timing. A sure pick pauses 0.2 s over the tile. A hasty pick leans at once (0.15 s). The player learns that a pause means care. A lucky hasty pick looks lucky. This is character: low Standing grabs.
It needs one core output per pick, `manner` (`sure` or `hasty`). The rule already draws `a < wise_pct`, so the fact is true. I reject a fake hesitation that core did not draw. The later full Echo model must output `manner` too.
PROPOSAL tooltips: `%s chose this.` / `%s grabbed this.`
Risk: a high Standing Echo can still be hasty (`wise_max`). It reads as a mood. Risk: the chooser may not be the top Standing (the best Echo is down). Mitigation: a small Standing glyph beside the chooser name.

### 1.4 Where a pick looks like a bug

| Case | Fix |
|---|---|
| The chooser takes a stack whose Sanctum stack is at its limit. The surplus will be lost. | Pass `sanctum_stack_full` to the seam. Rank that find lowest (D-2). |
| Stacks have grade index 0, so a stack of 9 always loses to a grade 1 piece. | Accept now. Flag to the catalogue story. |

## 2. The keeper swap (question 2)

### 2.1 Flow

1. Finding. One pip with an exchange glyph sits at the head of the pack row. Full means "yours to use". It is always visible, so the rule is never hidden.
2. Select. The player taps a left tile (the take). It lifts 4 units and gets a gold outline. Droppable pack tiles get a thin outline. Carried pieces show a lock glyph and no outline. A tap on one shows `They carried this from before.`
3. The player taps a pack tile (the drop). Either order works.
4. Confirm. An inline strip under the pack row shows both tiles with an exchange arrow. Buttons: `Swap` (primary, 56) and `Cancel` (secondary, 48), 24 units apart. Default focus is `Cancel`. PROPOSAL line: `You can do this once on this path. It cannot be undone.`
5. No ModalHost. A modal would hide the tiles being judged.

### 2.2 Motion and spent state

| Beat | Spec |
|---|---|
| Confirm | The tiles cross: the take rises into the freed socket, the drop sinks to the ground line. A keeper hand glyph replaces the portrait badge on both. 0.45 s, `TRANS_SINE`, `EASE_IN_OUT`. |
| Pip | Empties over 0.3 s. Tooltip `Used on this path.` |
| Hints | One warm short knock. One light haptic tap. No chime. |
| Spent | Ground tiles keep their place and lose the lift. The dropped tile cannot be taken again. |

The hand glyph shows who decided. One quiet moment, no fanfare. Targets: tiles 64 units at 1280x720, gap 8 or more; buttons 48 and 56 (READ: AGENTS.md).
No left items: the ground line hides; the pip stays dim and takes no input. An unused swap at path end triggers nothing.

## 3. The carried pack (question 3, D-16, D-17)

### 3.1 Before departure

At party prep a socket row shows the pack. Carried pieces fill from the left. A carried socket looks heavy: darker bed, 2 units lower, small Sanctum glyph. Free sockets look light.
The departure chip is quiet until free room reaches `warn_pack_free_at`. Then it gets a thin secondary gold outline, not a fill. The Depart button keeps the only gold fill. A tap opens the inventory view (shortcut only). PROPOSAL tooltip: `They have less room to carry this time.` No modal at departure.

### 3.2 On the path

The same sockets show in the packs view. Carried pieces keep the lock glyph and never dim on a leave or defeat. That is the proof they are safe. At free room 0 the socket row gets a solid frame (shape change, no alarm colour).

### 3.3 Spiral risk

Trace: Sanctum full, pack fills, room 0, every find is left. Nothing is lost (A2), so it is a stall. The player sees dim tiles after each encounter, and the cure (discard) is in the Sanctum, minutes away from the symptom.
Mitigations, all visual: (1) sockets at party prep; (2) at room 0 use the quiet 0.5 s beat, with no repeated alarm; (3) cap the ground line at pack capacity and show `+` for more; (4) one discard visibly frees one pack socket (5.2).

### 3.4 Hook for the later debuff story (data and visual only)

| Hook | Content |
|---|---|
| Snapshot `pack_load` | `{ carried, capacity, free, level }`. `level` 0 to 3 (none, light, heavy, full). Thresholds from `warn_pack_free_at` plus one config key. Core derives it each snapshot. |
| Visual slot `LoadMark` | A satchel glyph at the head of the socket row, four states. The later story may also show it on Echo tokens. |
| Socket posture | Carried sockets are lower and darker. A higher `level` adds one more tone step. |

## 4. Loss beats (question 4)

### 4.1 One shared motion, justified

Lost means: fade to 35 percent over 0.5 s, `EASE_OUT`. One parameter: lift 8 units if the tile was in the pack (it was secured and is gone). Left items never were in the pack, so they only fade.
Why one: the player learns one gesture for "lost". Four gestures would teach nothing more. What differs is the lead-in and the order. No red, shake, shatter or strike-through. Tone: a leaf let go.

### 4.2 The beats

| Beat | Lead-in and motion | Time | Sound hint | PROPOSAL line |
|---|---|---|---|---|
| Early leave, some | The existing outcome line first. Tiles resolve in pack order. Each holds 0.3 s, then slides toward the Sanctum glyph (kept) or uses the lost motion. Stagger 0.25 s. | Cap 1.8 s; over seven tiles, stagger 0.1 s | One soft falling tone per beat, at most three | `Lost. They did not get it out.` |
| Early leave, nothing | All pack tiles use the lost motion together. | 0.6 s | One tone | Existing outcome line only |
| Early leave, everything | All pack tiles slide to the Sanctum glyph together, then intake. | 0.5 s | One soft tone, the only rising one | Existing outcome line only |
| Defeat | Gathered tiles dim together. Carried pieces stay lit and still. | 0.8 s | None. Never a sting. | Existing `The party fell, and the packs were lost.` Optional: `What they carried from before is safe.` |
| Left behind | The pack row slides toward the Sanctum glyph. Ground tiles stay and fade. No lift. | 0.6 s | None | `They left this behind.` |
| Stack surplus | The badge ticks to the limit and becomes the at-limit capsule. A ghost chip of the surplus lifts off the badge and fades. The tile does not fade. | 0.6 s | One small tone | `Lost. The stack was full.` |

Order at a path end: outcome line, leave beats, intake (kept tiles settle 0.25 s each), surplus ghosts, ground fade. Total cap 3.0 s. A tap finishes all motion. The ground fade goes last and quiet because the player saw those items left long before. The optional defeat line depends on A2. Jeff decides.

## 5. The free-a-slot discard (question 5, D-11)

### 5.1 Place, confirmation, guard

In the Sanctum inventory view, the player taps a unique tile. A selection outline shows. The detail strip shows name, grade pips and `Let it go` (quiet, thin border, 48 or more, never gold fill; thin gold outline at full cap). It shows even with room left, so the rule is visible. No swipe, long press, drag or button on the tile. Stacks show no button.
Confirmation uses ModalHost (layer 40), which restores focus.

| Part | Spec |
|---|---|
| Content | Tile at large size, name, grade pips |
| PROPOSAL line | `Let this go? It cannot be brought back.` |
| Buttons | `Keep it` (primary look, 56, default focus). `Let it go` (secondary, 48). 24 units apart or more. |
| After confirm | The button ignores input for 0.6 s. |

No hold-to-confirm.

### 5.2 What the tile does

1. The modal closes (0.15 s). The tile uses the lost motion with lift.
2. If the pack holds a piece, the oldest glides from its socket into the grid (0.4 s). The player sees one discard free one pack socket. Without this the socket would vanish with no cause.
3. Neighbours close the gap (0.25 s). The gauge eases down (0.3 s). Selection moves on.
No coin sound, no yield text (D-02).

### 5.3 Nothing to discard

| Case | Behaviour |
|---|---|
| Empty | One line, PROPOSAL: `Nothing is stored yet.` No button. |
| Only stacks | No button. Never a grey disabled button. |
| All equipped (ITEM-003) | No button on those. PROPOSAL: `Everything here is in use.` |

## 6. Reading at a glance (question 6)

| View | A glance must answer | Elements in rank order |
|---|---|---|
| Sanctum inventory | Full? Is the pack holding spill? Anything at limit? | Cap gauge with `n / cap` and a shape change at full. Pack socket row directly under it. Tile grid by kind. Stack badges. |
| Packs on the path | Who chose? Room left? Anything left? Swap ready? | Socket row. Chooser portrait and Standing glyph. Ground line. Swap pip. |
| Pack before departure | How heavy? | Socket row with `LoadMark`. The chip. |

Tiles: 72 units at 1920x1080, 64 at 1280x720. Gap 8 or more. Targets 48 or more.
Ase and Ekwan stay a plain text line (READ: `CarriedHomePresentation.gathered_line`), with no frame. Items are framed tiles in their own region. Threads are not shown.
Stack badge `x7` sits bottom right. At the limit it becomes a solid capsule with an underline: shape and text both change. A gathered stack whose Sanctum stack is at limit shows the same capsule on the path. That is the "it will be lost" tell, before the loss (Darkest Dungeon silent loss, evidence Medium). Material quantity is a tile badge only, never a header or balance (D-06).
Twins (D-01): same type in mint order; a corner notch, one of six shapes from `mark_index`, kept across pack, ground line and Sanctum; grade pips in the other corner. Risk: a seventh twin repeats a shape. Accept. Shapes carry no order.

## 7. Placeholder look (question 7)

1. Flat grey-cream tile with a diagonal hatch (READ: the art direction has none).
2. Dashed outline, not the Living Grove border.
3. One plain shape per kind: square gear, diamond relic, circle consumable, triangle material. No gold, terracotta or Adinkra (READ: `docs/art-direction.md` Adinkra rules).
4. Names like `Test piece A`.
5. Twin notch, pips and chooser badge show real data.
6. Sockets, ground line and strip are final structure in `.tscn`, in plain style.

## 8. Play test checklist for Jeff

1. Finds fit: does the 0.5 s drop feel like nothing, as it should?
2. A real choice: does the lean feel like an Echo deciding? Is 1.3 s long by the fifth encounter?
3. Sure versus hasty: can you feel the timing difference with no tooltip?
4. A poor pick: character or bug?
5. Can you find the swap pip alone? Does either tap order feel natural?
6. Use the swap: is it your one good decision? Is the strip too slow?
7. A spent swap: does it read as spent, with no nag?
8. Party prep with a carried pack: do you see the weight before Depart?
9. A path with a full pack: stall, punishment or reminder?
10. Leave early with five items, several times: is each tile its own chance? Is "lost" warm?
11. Lose a fight with carried pieces: do lit tiles say "safe" without a line?
12. Overflow a stack: does the ghost chip read as "the stack was full"?
13. Discard with a full pack: do you see the pack piece glide in? Can a double tap discard by accident?
14. At 1280x720: tell twins apart, and tiles from the Ase and Ekwan line, with no text.

## 9. Conflicts and dependencies (question 9)

### Conflicts with `design-sr-game-designer-v2.md`

| # | Designer v2 | My position | Reason |
|---|---|---|---|
| C-1 | No pack discard (section 5). | Allow `inventory.discard.apply` on a carried piece. | The player should drop the piece they dislike. Dropping an older Sanctum piece to make room for a junk pack piece is a trap. Same action, same confirmation. |
| C-2 | Left tiles dimmed. | Full outline, 65 percent fill, on a ground line. | Dim and tappable reads as disabled. |
| C-3 | Portrait on every taken tile. | Keep, 24 to 28 units. Walking portrait only for a real choice. | A walk with no choice overstates a decision. |
| C-4 | Seam output has no manner. | Add `manner` per pick. | Section 1.3. |
| C-5 | Rank ignores a full Sanctum stack. | Rank it lowest. | Section 1.4. |
| C-6 | Chip gold at `warn_pack_free_at`. | Thin gold outline, not fill. | Depart owns the gold fill. |
| C-7 | Path view keeps "a material as a number" out; Sanctum shows badges. | Tile badge in both; never a header. | D-06 bans a balance, not a tile count. Designer confirms. |
| C-8 | A2 held pieces safe; silent auto-move. | Agree on A2. Make the auto-move a visible glide. | A room cost that becomes a loss double-punishes. |

### Dependencies

| # | Dependency |
|---|---|
| D-1 | Snapshot per find: taken or left, `manner`, chooser name, portrait reference, Standing, `mark_index`, pips, `fate`, `reason_key`, `carried`, `stack_at_limit`. |
| D-2 | Core passes `sanctum_stack_full` into the seam (C-5). |
| D-3 | Core supplies `pack_load` and projected Sanctum room each snapshot. |
| D-4 | `can_discard` per tile; it covers carried pieces (C-1) and ITEM-003 `held_by`. |
| D-5 | `swap: { available, spent }` in the snapshot. |
| D-6 | Party prep state survives a trip to the inventory view (ASSUMED). |

### Rules that feel bad where numbers cannot help

1. Discard is the only relief and it destroys. Nothing here can be sold, recycled or equipped (D-02, D-08), so clearing a full Sanctum is a chore of two-step discards. A bigger cap hides it. ITEM-004 fixes it. Flag to Jeff.
2. Cause (full Sanctum at departure) and symptom (empty picks on the path) sit minutes apart. Only the sockets and the chip bridge that.
3. While the pack is full, the Echo choice is a quiet "no" and the beat has no character to show. The whole feature depends on free room being usual. `pack_capacity` is the lever. Watch it in the first play test.

## OPEN — questions and assumptions

- ASSUMED: The encounter result card hosts the pick beat. | WRONG IF: it must sit on the path view.
- ASSUMED: Echo portraits stay legible at 24 to 28 units. | WRONG IF: they do not; use a ring plus a name tooltip.
- ASSUMED: Party prep state survives a trip to the inventory view.
- ASSUMED: `StopMarkMotion.reduced` can drive the new motions.
- ASSUMED: No audio layer exists. Sound items are hints only.
- ASSUMED: A2 stands. One line and one beat depend on it.
- ASSUMED: The discard is many-use (designer A4).
- BLOCKED: Jeff accepts `manner` as a core output (C-4), or prefers a plain pick.
- BLOCKED: Jeff decides C-1 (discard a carried piece).
- BLOCKED: Jeff decides whether the optional defeat line stays.
- BLOCKED: Numbers for `pack_capacity`, `warn_pack_free_at` and the `level` thresholds (Jeff, D-13).
- BLOCKED: Jeff approves all PROPOSAL lines.
