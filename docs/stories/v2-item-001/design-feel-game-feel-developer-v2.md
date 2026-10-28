# V2-ITEM-001a feel design (game-feel-developer, v2, corrected for D-17 to D-21)

Written in STE. Design only. I ran no code and no Godot. D-01 to D-21 bind this design.
Tags: READ = from a file I opened. ASSUMED = not verified. Research is hypothesis only (`research-comparison.md`, evidence LOW).
All player text is PROPOSAL. Jeff owns copy. Word rules (ANSWERS #86): say Sanctum, path, lost. No "banked", "settled" or "roll" in text.
**[CORRECTED D-18]** Sections 1 to 8 scope 001a. Section 9 holds the 001b parts (parked, ideas unchanged).

## 0. Findings first

1. READ: a reduced-motion switch exists (`ui/components/StopMarkMotion.gd:24`). Every motion needs a 0.15 s fade path.
2. READ: no audio player exists in `ui/` or `core/`. Sound items are hints only.
3. READ: `docs/Living_Grove_Design_System.md:35-52`. Info blue `#7AB5C8` is also the Fearful colour. Marks use shape and neutral ink. Gold means actionable or full.
4. **[CORRECTED D-19 D-20]** Carried pieces are at risk. A carried tile is never "safe" or "lit". The lock glyph and the "carried tiles stay lit" idea are removed. Only the Sanctum is safe.
5. **[CORRECTED D-18]** 001a has no path packs view. The leave and defeat beats need one surface. I propose a result row on the existing outcome screen (section 3.1). Question for Jeff.


## 1. Plain find-order arrival (001a) [CORRECTED D-18]

The pack fills in find order (`take_in_order`). No Echo chooses. No portrait walks. No manner, ground line or left list.
The beat plays on the encounter result card (ASSUMED; `ui-ux-designer` confirms).

| Case | What the player sees | Time |
|---|---|---|
| No finds | Nothing | 0 |
| Finds fit | Tiles appear and drop together into free sockets, left to right. | 0.5 s |
| Finds exceed free room | Tiles appear in a row (0.2 s). The first tiles drop into the free sockets (0.3 s). The other tiles fade to 35 percent and leave the row (0.5 s, `EASE_OUT`, no lift). | 0.8 s |
| Free room 0 | Tiles appear (0.2 s) and fade out (0.5 s). No drop. | 0.7 s |

A tap finishes the beat. The result is already saved.

**How the extra finds read.** A tile appears and fades where no socket waits. This is the "lost" gesture without the lift. The lift means "it was in the pack". An extra find never was, so it only fades. The filled sockets show the cause.
PROPOSAL line, once per path, at the first find with no room: `Lost. There was no room.` After that, only the fade plays. This avoids a repeated alarm.
An extra find is not saved and cannot return. Risk: a first-time player may think it waits. Mitigation: the fade and the once-only line.

## 2. The carried pack before departure (D-16, D-17, D-19)

### 2.1 Sockets

At party prep a socket row shows the pack. Carried pieces fill from the left. A carried socket looks heavy: darker bed, 2 units lower. **[CORRECTED D-19]** Each carried tile has a small "loose leaf" glyph (a leaf with a gap) in its top-left corner. It means "may be lost". It uses shape only. It disappears when the piece enters the Sanctum (section 5.2). Free sockets look light.

### 2.2 The departure chip [CORRECTED D-19]

The chip once warned about lost room. Now it must also warn about lost pieces.

| Condition | Chip |
|---|---|
| No carried piece | Hidden. |
| One or more carried pieces | Shown in neutral ink: the carried count and the loose-leaf glyph. |
| Free room at or below `warn_pack_free_at` | Thin gold outline added, no fill. Depart keeps the only gold fill. |

A tap opens the Sanctum inventory view, where the discard is (section 5). The chip leads to the cure.
PROPOSAL tooltip: `They may lose what they carry.` Second line when room is low: `They have less room to carry this time.`
No modal at departure. Sockets and chip share the screen with Depart.

### 2.3 Leave-panel count line [CORRECTED D-19]

The existing leave confirmation gets one line. It counts gathered pieces plus carried pieces that may be lost. A stack counts as one piece.
PROPOSAL: `They may lose 3 pieces. 1 was carried from before.` The second sentence shows only when a carried piece exists. The line hides at 0.
It is a number line, with no tiles and no odds. Tiles with per-item marks on the path are 001b.

## 3. Loss beats (001a) [CORRECTED D-19 D-20]

### 3.1 One shared motion and the surface

Lost means: fade to 35 percent over 0.5 s, `EASE_OUT`. One parameter: lift 8 units if the tile was in the pack. Gathered and carried pieces were both in the pack, so both use the lift. No red, shake or strike-through. Tone: a leaf let go.
**Surface (question for Jeff).** The beats need tiles. 001a has no path packs view. I propose a result row on the existing leave and defeat outcome screens. It shows only pieces at stake, carried first, then gathered. It is a result, not a path view. Fallback if Jeff refuses: the outcome line plus a count (`Lost 2 of 3 pieces.`), and the Sanctum view shows what survived.

### 3.2 The beats

| Beat | Motion | Time | Sound hint | PROPOSAL line |
|---|---|---|---|---|
| Early leave, some | The existing outcome line first. Tiles resolve in pack order. Each holds 0.3 s, then slides toward the Sanctum glyph (kept) or uses the lost motion with lift. Stagger 0.25 s. | Cap 1.8 s; over seven tiles, stagger 0.1 s | One soft falling tone per lost tile, at most three | `Lost. They did not get it out.` |
| Early leave, nothing | All tiles, carried and gathered, use the lost motion with lift together. | 0.6 s | One tone | Outcome line only |
| Early leave, everything | All tiles slide to the Sanctum glyph together, then intake. | 0.5 s | One soft rising tone | Outcome line only |
| Survivor, Sanctum full | A kept carried tile does not slide. It settles in its socket and keeps its loose-leaf glyph. | 0.2 s | None | `The Sanctum is full. This stays in their packs.` |
| Defeat | All pack tiles, gathered and carried, use the lost motion with lift together. | 0.8 s | None. Never a sting. | Existing `The party fell, and the packs were lost.` |
| Stack surplus | The badge ticks to the limit and becomes the at-limit capsule. A ghost chip of the surplus lifts off and fades. The tile stays. | 0.6 s | One small tone | `Lost. The stack was full.` |

A slide toward the Sanctum glyph promises safety, so the survivor settles in place.
Order at a path end: outcome line, leave beats, intake (kept tiles settle 0.25 s each), surplus ghosts. Cap 3.0 s. A tap finishes all motion.

### 3.3 Repeat-leave wear-down (A9) — question for Jeff

Each early leave draws every carried piece again. In the "some" outcome a piece survives n leaves with chance 0.5 to the power n. After two leaves, 75 percent are lost on average.

| Test | Result |
|---|---|
| Readable | Yes. Each tile shows its fate each time. The glyph stays until the piece reaches the Sanctum. |
| Fair | Mostly. The player can discard, or finish a path (no draw). The risk is a choice. |
| Warm | Weak point. A survivor feels earned, and a second draw can feel like a trick. |

Recommendation: keep A9. One rule, "carried means at risk", is easier to read than a hidden exemption. Warmth comes from the survivor beat, which promises no safety, and from the persistent glyph.
Alternative: a survivor is exempt for the rest of that stage. It is kinder, but it needs a visible mark and an exploit check. Not recommended. Jeff decides. Checklist 7 tests it.

### 3.4 Spiral risk [CORRECTED D-17 D-19]

Trace: Sanctum full, pack fills, free room 0, nothing gathered, carried pieces can only be lost. Nothing locks: a lost carried piece frees a slot. Mitigations, all visual: sockets and chip at party prep; the quiet room-0 beat; one discard visibly frees one pack socket (5.2); the chip tap leads to the Sanctum view.

### 3.5 Hook for the later debuff story [CORRECTED D-17]

D-17 puts debuffs in another story. 001a designs no debuff, no Echo state change and no rule that reads the load. These are data and visual hooks only.

| Hook | Content |
|---|---|
| Snapshot `pack_load` | `{ carried, capacity, free, level }`. `carried` counts held pieces. `level` 0 to 3 (none, light, heavy, full). Thresholds: `warn_pack_free_at` plus one config key. Core derives it each snapshot. |
| Visual slot `LoadMark` | A satchel glyph at the head of the socket row, four states. Static in 001a. |
| Socket posture | Carried sockets are lower and darker. A higher `level` adds one tone step. |

Only `LoadMark` and the socket tone read `level` in 001a. Numbers are unset (Jeff).

## 4. Reading at a glance

| View | A glance must answer | Elements in rank order |
|---|---|---|
| Sanctum inventory | Full? What is carried? Anything at limit? | Cap gauge `n / cap`, shape change at full. Carried row under it, with glyphs. Tile grid by kind. Stack badges. |
| Pack before departure | How heavy? What may be lost? | Socket row with `LoadMark`. The chip. |
| Leave panel | How many pieces are at stake? | The count line. |

Tiles: 72 units at 1920x1080, 64 at 1280x720; gap 8 or more; targets 48 or more. Ase and Ekwan stay a plain text line. Stack badge `x7` bottom right; at the limit a solid capsule with an underline. Material quantity is a tile badge only (D-06). Twins: a corner notch from `mark_index`, kept across pack and Sanctum.

## 5. The Sanctum discard (D-11, D-21) [CORRECTED D-21]

### 5.1 Picking a piece and the confirmation

The discard works only in the Sanctum, on Sanctum pieces and carried pieces. It has many uses. Each use needs a confirmation.
1. The player taps a unique tile in the grid or in the carried row. A selection outline shows. Both use the same outline.
2. A detail strip shows name, grade pips and `Let it go` (quiet, thin border, 48 or more, never gold fill; thin gold outline at full cap). For a carried piece it adds PROPOSAL `It may be lost on a path.`
3. The button shows even with room left, so the rule is visible. Stacks show no button.
4. `Let it go` opens ModalHost (layer 40), which restores focus.

| Part | Spec |
|---|---|
| Content | Tile at large size (with the glyph if carried), name, grade pips |
| PROPOSAL line | `Let this go? It cannot be brought back.` |
| Buttons | `Keep it` (primary look, 56, default focus). `Let it go` (secondary, 48). 24 units apart or more. |
| After confirm | The button ignores input for 0.6 s. |

**Guards.** No swipe, long press, drag or button on the tile. No hold-to-confirm. Default focus is `Keep it`.
**[CORRECTED D-21]** New guard: after a discard the selection clears and the strip hides. The discard is many-use and tiles shift. A double tap must not reach a new `Let it go`.

### 5.2 What the tiles do

| Discarded piece | Motion |
|---|---|
| Carried | The modal closes (0.15 s). The tile uses the lost motion with lift. The socket closes and neighbours shift (0.25 s). The gauge does not change. |
| Sanctum | The modal closes (0.15 s). The tile uses the lost motion with lift. If the pack holds a piece, the oldest carried piece glides from its socket into the freed grid place (0.4 s). Its glyph fades on landing (0.2 s). The gauge eases (0.3 s). |

The glide shows one discard free one pack socket. Without it the socket would vanish with no cause. The glyph fade is the only "safe" signal, and it sits in the Sanctum.
No coin sound, no yield text (D-02). No recycle in 001a.

### 5.3 Nothing to discard

Empty: PROPOSAL `Nothing is stored yet.` and no button. Only stacks: no button, never a grey disabled one. All equipped (ITEM-003): PROPOSAL `Everything here is in use.`

## 6. Placeholder look

Hatched grey-cream tiles, dashed outline, one plain shape per kind, no gold or Adinkra (READ: `docs/art-direction.md`). Twin notch, pips and glyph show real data.

## 7. Play test checklist for Jeff (001a)

1. Finds fit: does the 0.5 s drop feel like nothing?
2. Finds exceed room: do fading tiles read as "no room"? Does a tile look like it will return?
3. Free room 0: is the quiet fade enough?
4. Party prep with carried pieces: do you see weight and risk before Depart? Does the chip help?
5. A path with a full pack: stall, punishment or reminder?
6. Leave early with five pieces, some carried: is each tile its own chance? Is "lost" warm?
7. Leave early twice with the same carried piece: fair, warm, readable? (A9)
8. A survivor with a full Sanctum: does the settle read as "kept, still carried"?
9. Lose a fight with carried pieces: do all tiles read as lost with no extra line?
10. Overflow a stack: does the ghost chip read as "the stack was full"?
11. Discard a Sanctum piece with a full pack: do you see the carried piece glide in?
12. Discard a carried piece: is the difference clear?
13. Tap `Let it go` twice fast: does anything discard by accident?
14. Is the leave-panel count line enough?
15. At 1280x720: tell twins apart.

## 8. Conflicts and dependencies

| # | Designer v2 | My position | Status |
|---|---|---|---|
| C-1 | No pack discard | Allow discard on a carried piece | **ACCEPTED by Jeff, D-21.** Closed. |
| C-6 | Chip gold at `warn_pack_free_at` | Thin gold outline, not fill | Open for the designer |
| C-7 | Material number out of the path view | Tile badge everywhere; never a header | Designer confirms (D-06) |
| C-8 | Auto-move of held pieces | Make the move a visible glide | Still applies |
| C-9 (new) | Leave panel: one count line (A8) | Add a result row of tiles on leave and defeat screens | Question for Jeff (3.1) |
| C-10 (new) | Chip gold at low room only | Chip also shows whenever a carried piece exists | Risk exists at any room level |

Dropped (need an Echo choice, now in section 9): C-2 left tiles, C-3 portrait, C-4 `manner`, C-5 full stack rank.

Dependencies: (1) per find: `taken` or `no_room`, kind, pips, `mark_index`; (2) per piece at a leave or defeat: `fate`, `reason_key`, `carried`, `stack_at_limit`; (3) `pack_load` and the at-risk count each snapshot; (4) `can_discard` per tile, covering carried pieces and ITEM-003 `held_by`; (5) party prep state survives a trip to the inventory view (ASSUMED).

Rules that feel bad where numbers cannot help: (1) discard is the only relief and it destroys; ITEM-004 fixes it; (2) cause (full Sanctum at departure) and symptom (nothing gathered) sit minutes apart; (3) a held piece costs room and risk, so `pack_capacity` is the lever. Watch it in the first play test.

## 9. 001b (parked) [CORRECTED D-18]

Not built in 001a. Needs a Notion row with Jeff's yes. Ideas are unchanged except the D-19 note.

**Echo choice beat.** Finds fit: tiles drop together with a portrait badge on each (0.5 s). A real choice: the chooser portrait slides in (0.25 s); per pick it leans and the tile rises into a socket (0.3 s); left tiles sink to the ground line (0.3 s). Cap 2.0 s.
**Ground line.** Left tiles rest on a thin line below the pack row, at full outline and 65 percent fill. PROPOSAL tooltips: `%s took this.` / `%s left this.`
**Manner.** A sure pick pauses 0.2 s; a hasty pick leans at once (0.15 s). Core outputs `manner` per pick; the rule already draws `a < wise_pct`. No fake hesitation. A Standing glyph by the chooser name covers the hasty high-Standing case.
**Bug-like pick.** Pass `sanctum_stack_full` to the seam; rank that find lowest.
**Keeper swap.** One pip at the head of the pack row. Tap a left tile (take), tap a pack tile (drop); either order. An inline strip shows both tiles. `Swap` (primary, 56) and `Cancel` (secondary, 48), 24 units apart; default focus `Cancel`. PROPOSAL: `You can do this once on this path. It cannot be undone.` No ModalHost. Tiles cross in 0.45 s; a keeper hand glyph replaces the portrait badge; the pip empties (0.3 s).
**[D-19 note]** The old design showed carried pieces with a lock glyph, as "safe". D-19 removes that meaning. If 001b refuses a swap on carried pieces (designer A7), it needs a different "cannot swap" mark, and the lock must not mean "safe". The 001b path view must mark carried pieces at risk with the loose-leaf glyph. The swap drop is the only path discard (D-21).
001b dependencies: `manner`, chooser data, `swap: { available, spent }`, left items in the snapshot.

## OPEN — questions and assumptions

- ASSUMED: The encounter result card hosts the arrival beat. | WRONG IF: it must sit on the path view.
- ASSUMED: `StopMarkMotion.reduced` can drive the new motions.
- ASSUMED: No audio layer exists. Sound items are hints only.
- ASSUMED: Party prep state survives a trip to the inventory view.
- ASSUMED: The line `Lost. There was no room.` shows once per path.
- BLOCKED: Jeff decides A9 (3.3): a draw at every early leave, or a survivor exempt for the stage. I recommend the draw at every leave.
- BLOCKED: Jeff decides C-9 (3.1): a result row of tiles on leave and defeat screens, or a count line only.
- BLOCKED: Jeff decides whether departure needs a modal when carried pieces exist. I recommend none.
- BLOCKED: Numbers for `pack_capacity`, `warn_pack_free_at` and the `level` thresholds (Jeff, D-13).
- BLOCKED: Jeff approves all PROPOSAL lines.
