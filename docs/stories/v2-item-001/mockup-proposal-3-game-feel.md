# V2-ITEM-001a mockup proposal 3 of 3: game feel (motion, timing, feedback, pacing)

Author: game-feel-developer. Written in STE. Proposal only. I built no mockup and ran no code. Jeff approves the merged proposal before any build.
Builds on proposal 1 (UI/UX), screens S1 to S8. Look and colour belong to the artist proposal. Player lines are PROPOSAL; Jeff owns copy.
`[R<section> LABEL]` cites `research-ui-best-practices.md`. Most evidence is COMMUNITY or ARTICLE, so each use is a hypothesis.
Checked in code: `StopMarkMotion.reduced` is the one reduced-motion flag. Current tween norms in `ui/`: 0.25 s, then 0.35, 0.2, 0.15; press 0.08 s. No audio layer exists, so sound items are hints only.

## 0. Rules for all motion

| Rule | Value |
|---|---|
| Reduced motion | Every beat becomes a 0.15 s fade. No lift, glide, scale or pulse. Order and final state stay the same. |
| Easing | `QUAD` `EASE_OUT` for arrivals and fades. `SINE` `EASE_IN_OUT` for glides. No bounce, no overshoot on item tiles. |
| Result first | The saved result is true from frame 0. Motion never hides it. |
| No loops | No idle animation on any inventory surface (AGENTS.md, UI Rules). |

## 1. Per-screen feel table

| Screen and beat | Order of events, duration, easing | Player feels | Sound hint / haptic hint | Reduced motion |
|---|---|---|---|---|
| S1 open | Panel fades 0 to 1 and rises 12 units, 0.25 s. Close: fade 0.18 s. | A drawer opens. No wait. | Soft paper slide / none | 0.15 s fade |
| S1 select tile | Press 0.08 s (existing press). Outline appears at once. Strip content cross-fades 0.12 s. | The tile answered. | Light tick / light tap | Outline at once, strip 0.15 s fade |
| S1 gauge change | Pips step; numeral eases 0.3 s. On first entry to `warn.room` the last pip pulses once (1.0 to 1.15 to 1.0, 0.4 s), never on later opens. | The Sanctum became full. | None / none | Pip changes shape, no pulse |
| S2 open | Backdrop dims 0.15 s. Card fades and rises 4 units, 0.15 s. Focus on `Keep it`. Modal `Let it go` ignores input for 0.25 s and shows at 70 percent strength until then. | A pause. Weight, not alarm. | Low soft tone / none | 0.15 s fade; the 0.25 s window stays |
| S2 confirm (Sanctum piece) | Modal closes 0.15 s. Tile uses the lost motion with lift (section 2) for 0.35 s, then fades to 0 in 0.15 s. Neighbours shift 0.25 s after. Gauge eases 0.3 s. Selection clears at once. | A leaf let go. The gap closes. | Leaf-fall tone, once / one low single thump | Tile fades 0.15 s, neighbours jump |
| S2 confirm (carried piece) | Same motion. The socket closes, neighbours shift 0.25 s, gauge unchanged. | The pack got lighter. | Same | Same |
| S2 carried glide | Only if the snapshot shows a carried piece entering the Sanctum: it glides from its socket to the freed place, 0.4 s `SINE`, starting 0.2 s after the lost motion starts. Its carried glyph fades on landing, 0.2 s. Total 0.8 s. | One discard freed one pack socket. | Soft settle / none | Piece fades out and in, 0.15 s each |
| S3 sockets, S4 chip | Static. A socket or the chip changes with a 0.15 s cross-fade. Carried sockets sit lower and darker (posture). Chip tap opens S1 in place. | Weight, then a reminder, not an alarm. | None / light tap on chip | Same |
| S5 leave row | Tiles fade in together, 0.2 s, with the modal. Focus on `Cancel`. `Confirm` ignores input for 0.25 s. | A plain list of stakes. | None / none | 0.15 s fade |
| S6 leave result | See section 3 (timeline). Tiles resolve in pack order (carried first), each on its own draw. |  | Kept: soft settle, quiet. Lost: leaf-fall, at most 3 per card / light tap on a kept tile, none on lost | 0.15 s fade per tile, same order, 0.1 s apart |
| S7 defeat card | Existing card text first, 0.25 s. All tiles then use the lost motion with lift together, 0.5 s. No stagger, because no piece had a draw. | The pack is gone. It is stated, not staged. | None. Never a sting / none | 0.15 s fade |
| S8 stage-clear preview | Groups appear in order: kept, carried, lost. Each group fades in 0.25 s, 0.15 s apart. Lost tiles arrive already at the lost level, with no lift (nothing moves; it is a preview). Total 0.55 s. | A forecast of the path end. | None / none | 0.15 s fade, all groups together |
| No-room find (Q5 of proposal 1) | Tile appears 0.2 s, holds 0.2 s, fades to 0.35 and out 0.5 s. No lift. The `PackSocketRow` (mini) beside it stays full. Once per path a line shows (see section 5). | There was no place for it. | Leaf-fall, once per path / none | 0.15 s fade |

## 2. The shared lost motion

| Parameter | Value |
|---|---|
| Fade level | 0.35 alpha on the tile body. The outline and the shape mark stay at 1.0, so the tile stays findable. |
| Time | 0.5 s on S6 and S7 (0.35 s on S1, then 0.15 s to 0) |
| Easing | `QUAD` `EASE_OUT` |
| Lift | 8 units up, same curve as the fade |
| Scale, rotation, colour | None. No red, no shake, no shatter, no strike-through. |

| Case | Lift | Why |
|---|---|---|
| S1 discard (Sanctum or carried) | Yes | The piece had a place. |
| S6 lost, S7 lost (gathered or carried) | Yes | Both sat in the pack. D-19 and D-20 make carried pieces equal to gathered pieces. |
| S8 lost in a preview | No | Nothing moves in a preview. |
| No-room find | No | The piece never had a place. It cannot rise from nowhere. |
| Stack surplus | No on the tile; a ghost chip of the surplus lifts | The stack stays. Only the surplus goes. |

Warm tone: the motion is slow, small and upward, like a leaf let go. The faded tile stays on S6 and S7 as a record, like Darkest Dungeon's greyed rewards [R4 COMMUNITY]. The line states the fact plainly [R5 ARTICLE]. D-02, D-19 and D-21 bar a recovery or return (proposal 1, Q6), so warmth comes from softness and silence.

## 3. Pacing budget

S6 timeline: outcome line 0.25 s, then a 0.3 s hold with all tiles visible at risk, then tiles resolve one by one, each 0.5 s. Start-to-start stagger is 0.3 s for 1 to 4 tiles and 0.15 s for 5 to 8 tiles.

| Items at path end | Leave result (S6) | Defeat (S7) | Stage clear (S8), added before | Typical player wait |
|---|---|---|---|---|
| 1 | 1.05 s | 0.75 s | 0.55 s | About 1.6 s |
| 4 | 1.95 s | 0.75 s | 0.55 s | About 2.5 s |
| 8 | 2.1 s | 0.75 s | 0.55 s | About 2.7 s |

Hard cap for any item sequence: 2.4 s. Longer sequences shorten the stagger.

**Skip rules.**

| Item | Skippable? |
|---|---|
| Resolve, lost, glide and fade motion | Yes. The first tap anywhere, or `Continue`, jumps to the final state. It does not leave the card. |
| `Continue` after the final state | Ignores input for 0.25 s, then works. This stops a double tap from passing the card. [R4 ARTICLE, Slay the Spire 2: skip and proceed were confused.] |
| S2 discard confirmation | Never. No timeout, no auto-close, no skip. |
| S5 leave confirmation | Never. |
| Outcome line and kept-or-lost marks | Never hidden. The final state always shows both. |

**Rule against hidden results.** No tile may leave the screen on S6 to S8. No fade may end below 0.35. A lost tile keeps a shape mark. A card needs one `Continue`. This follows [R4 COMMUNITY, Warframe] and [R4 DEVELOPER].

## 4. Accidental-input and confirmation feel

| Guard | Spec | Research |
|---|---|---|
| Select, then confirm | Tile tap never discards. `Let it go` sits at the strip bottom, away from `BackButton`. | [R6 COMMUNITY, Stardew] |
| Default focus | `Keep it` (S2). `Cancel` (S5). | [R6 ARTICLE, Primer] |
| Cancel behaviour | Esc, Back, B and an outside tap mean `Keep it`. Cancel never leads toward a more destructive prompt. | [R6 COMMUNITY, Fire Emblem] |
| Open window | Modal `Let it go` ignores input 0.25 s after the modal opens, and shows at 70 percent strength. A finger still over the strip button position cannot confirm. | [R6 COMMUNITY, Stardew Switch drift] |
| Double-tap guard | After confirm, every discard control ignores input for 0.6 s, and the selection clears at once. | [R6 COMMUNITY] |
| No hold, swipe or drag | None. No hold-to-confirm. | [R6 ARTICLE, Vercel] |
| Permanent action | One low thump and one leaf-fall tone, once. No coin sound (D-02). | No precedent found; hint only |

Risk: players click through confirmations and undo is better [R6 ARTICLE]. D-21 bars undo. The large tile and risk line slow a habit click.

## 5. The spiral and the readability check

The spiral: Sanctum full at departure, so carried pieces fill the pack, so free room is 0, so finds fade. Cause and symptom sit minutes apart.

| Cap signal | 1. World behaviour | 2. Spatial UI | 3. Compact UI | 4. Reference UI |
|---|---|---|---|---|
| Sanctum full (cause) | The hub has no item world object in 001a. I cannot propose one. A later art story could show a full shelf. | `CapGauge` shape change at full, plus the single pulse on first entry | `StoragePanel` card state | Reason line |
| Pack heavy at departure | Carried sockets sit lower and darker | `PackSocketRow` with carried glyphs | `PackLoadChip`, gold outline at low room | Tooltip |
| Pack full on the path (symptom) | A find appears, finds no place and fades (the no-room beat) | The mini `PackSocketRow` on the encounter card shows full sockets. The old pieces carry the carried glyph. | Count on the card | One line, once per path |
| At risk | Tiles on S5 | Same `ItemTile` row | Count | Names on focus |
| Lost, kept | Faded tile, settled tile (section 2) | Shape mark | Group order on S8 | Names on focus |

The bridge: the same `PackSocketRow` and carried glyph show at party prep, on the encounter card and on S8. Proposal 1 has no mini socket row on the encounter card; I request one.
PROPOSAL once-per-path line at the first no-room find: `Lost. There was no room.` After that, only the fade plays. This avoids a repeated alarm.
**Never only text:** Sanctum full, pack full, carried (at risk), kept or lost, blocked discard (`path_open`), twin identity, stack at limit, pack load level. Each also needs a shape or position read.

## 6. What the mockups should show of my part

**Storyboards** (static frames, each with its time label):

| Board | Frames and times |
|---|---|
| Discard with a carried piece | 0.00 s modal, `Keep it` focused; 0.25 s `Let it go` fully lit; confirm +0.15 s tile lifting; +0.5 s tile at 0.35; +0.8 s carried piece landed |
| Leave result, 4 items, "some" | 0.00 s all tiles at risk; 0.55 s tile 1 settled; 0.85 s tile 2 faded, tile 3 resolving; 1.45 s tile 4 resolving; 1.95 s final, `Continue` live |
| Defeat, 3 items | 0.00 s card; 0.25 s tiles full; 0.50 s tiles at 0.6; 0.75 s all at 0.35 |
| Stage-clear preview | 0.00 s card; 0.25 s kept group; 0.40 s carried group; 0.55 s lost group |

**CSS-only loop demos.** Three: the lost motion on one tile, the S6 stagger with 4 tiles, the discard glide. Each loops with a 1.5 s rest and a time label. Each uses `@media (prefers-reduced-motion: reduce)` for a 0.15 s fade; a `:has()` checkbox forces it. No script.

**Play-test checklist for Jeff (real build):**
1. Open the panel and select five tiles: does anything feel slow?
2. Discard a piece: is the thump and leaf-fall weight right, or too much?
3. Tap `Let it go` twice at the same spot: does anything discard?
4. Discard with a carried piece: does the glide explain the freed socket?
5. Leave early with 4 items: is 2 s right?
6. Tap during the resolve: does the first tap finish and the second continue?
7. Lose a fight: does the card feel stated, not staged?
8. Meet a find with a full pack: do you link the fade to the old pieces?
9. Reduced motion on: is every result clear?
10. At 1280x720: can you see the fade level and shape mark?

## 7. Conflicts, risks and questions

| # | Item | Position |
|---|---|---|
| C1 | Proposal 1, S7: "no input skips the tiles". | I allow the first tap to jump motion to the final state. Tiles never hide. If Jeff prefers no skip, S7 lasts 0.75 s, which is short. |
| C2 | v2: lift for pack pieces; count line on leave; S6 cap 1.8 s. | Changed: lift follows "had a place"; D-23 tiles; cap 2.4 s plus tap-to-finish. |
| C4 | v2 survivor settle, carried glyph, silent defeat, stack ghost chip, 0.6 s lock. | Still hold. |
| C7 | Proposal 1 has no mini socket row on the encounter card. | I request one. It needs the UI/UX owner. |
| C8 | The glide needs core to move a carried piece when room appears (v2 C-8). Not confirmed in proposal 1. | Without it, no glide. |

**Risks.** (1) 2.4 s may feel long on repeat paths. (2) The open window may feel like lag. (3) The 0.35 level may fail contrast; the artist checks it. (4) Nothing sets `StopMarkMotion.reduced` today. (5) Sound and haptic items cannot be tested without an audio layer.

| Q | Question | Recommendation |
|---|---|---|
| Q1 | First tap finishes motion, second tap continues, or `Continue` leaves at once? | First tap finishes. It stops a skipped result. |
| Q2 | Item sequence cap 2.4 s, or 1.8 s? | 2.4 s, with tap to finish. |
| Q3 | Pulse the last gauge pip once on first entry to full? | Yes. It teaches the cause at the moment it begins. |
| Q4 | Play the carried glide, if core moves the piece? | Yes. It ties one discard to one freed socket. |
| Q5 | Add the 0.25 s open window on modal `Let it go` and S5 `Confirm`? | Yes for both. The S5 change touches an existing modal. |
| Q6 | Add a mini pack row on the encounter card to link symptom to cause? | Yes. It costs little and closes the spiral gap. |
