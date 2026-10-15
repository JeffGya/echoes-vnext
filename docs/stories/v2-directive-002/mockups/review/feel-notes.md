# Feel notes: stage stop marker mockup (V2-DIRECTIVE-002 B+C, round 1)

Author: game-feel-developer. Status: PROPOSALS for Jeff. No number here goes in config yet (D-37).
Sources read: `ui/screens/venture/StageExploreScreen.gd` (travel tween at lines 508-537, snippet at 1193-1215, `_apply_pending_overlay` at 628), `StageExploreScreen.tscn` (`TravelSnippetLabel`), design.md section 8 and 8a, D-32, D-37 to D-40, the mockup README. The mockup HTML is 500 KB; I read its headings and README, not every line.

## 0. The real rhythm today (facts from code)

| Beat | Time | Source |
|---|---|---|
| Walk, all segments together | `_TRAVEL_DURATION` = 0.5 s total. Each segment = 0.5 / path length. A 4-tile path = 0.125 s per tile. | `StageExploreScreen.gd:71, 513` |
| Per segment | token moves, a step diamond is spent, a ghost footprint drops on the vacated cell | `:528-531` |
| Overlay after walk | `_apply_pending_overlay` runs on tween `finished`. Contact modal, sit overlay and choices appear only after the walk ends. | `:540-545, 628` |
| Snippet (ghost text) | starts WITH the walk (not after). Fade in 0.4 s, hold 2.1 s, fade out 0.5 s = 3.0 s. Label sits top-centre, 15 pt, 480 wide, 140 units below the top. | `:1210-1214`, tscn |
| Party bark | starts with the walk, on the token | `:540-541` |
| Existing hard-coded literals | 0.4 / 2.1 / 0.5 (snippet), 0.35 (reaction label), 0.1+0.1 (combat flash), 0.25 (preview fade). D-40 item 14 moves these to config in the same pass. | grep |

Key read: the walk is short (0.5 s) and the snippet is long (3.0 s) and starts at the same moment. So today the text is still fading in while the token is already parked. The new marker lands at 0.5 s, inside the snippet's fade-in.

## 1. Where the mockup is noisy

### 1a. Visual noise (a single frame)
The mockup puts all of these on one sheet. In the game they would all be on the board at once after a stop.

| Competing element | Why it pulls the eye |
|---|---|
| Stop-marker head (six shapes, some with chevrons and a dashed ray) | Needs a shape read. Dashed ray and chevrons add a second and third motion cue. |
| Ground ring on the cell | Same colour family as the marker. It repeats the marker's job. |
| Portrait pulse on the EchoBar | Pulls the eye to the bottom of the screen, far from the board. |
| Path (gold) plus ghost footprints | The path is needed. The ghosts fade, so they are short noise only. |
| Step bar with crossed steps | A second place with a shape cue. It sits in the HUD, near the top. |
| Journey entry under the top HUD (left) | Text at rest, always visible, one more small block near the step bar. |
| Directive badge (204x36, tinted, with glyph) | Already in the top HUD. It adds a colour and a glyph. |
| Snippet (ghost text, top-centre) | Text, 3.0 s long. Reads as a caption of the stop, but says something else (flavour). |
| Party bark bubble | Text again, on the token. |
| Why card (on tap) | Fine on tap. In the mockup it is drawn next to everything else, so the page looks as if it is always open. |
| Touch map, tint toggles, "considered, not chosen" options | Review tools. They are not in the game. They make the sheet look heavier than the game. |

Count: on the board, after one Advance, a player could see up to 4 text or shape cues in the same 3 s (marker, snippet, bark, pulse) plus 2 persistent HUD cues (step bar cross-outs, journey entry). That is the "busy and dense" Jeff feels.

### 1b. Temporal noise (a sequence)
1. Walk is 0.5 s. Snippet, bark, ghost drops and step-diamond spends all start inside that 0.5 s. Four things change per 0.125 s tile.
2. The marker, ring, chevron motion and portrait pulse would all arrive at about 0.5 s together. One moment, four signals: the eye reads none of them.
3. The "shaken beat" (D-38 item 2) is a fifth event in the same window if it plays after the walk. It also competes with the step bar cross-outs, which say the same thing.
4. The snippet is still fading out at about 3.0 s. The player's attention is on text while the marker should be the answer.
5. Looping animation (a ring that keeps pulsing, a dashed ray that keeps moving) keeps drawing the eye after the stop is already understood.

## 2. Calm reading order

Idea: most stops need ONE quiet cue. The marker is that cue. The card exists only on tap.

| Order | What the player sees | Where | Time (proposal) |
|---|---|---|---|
| 1 | The party walks the path. The path is already the explanation of "how". | Board | 0 to 0.5 s (today's walk) |
| 2 | The token stops. The marker head settles on the cell once, then is still. Its SHAPE says the kind of stop. | Board, next to token | about 0.5 to 0.9 s |
| 3 | If an Echo is named: the one portrait on the EchoBar gets a single soft pulse, then rests with a faint ring (open question 1 in README). | EchoBar | starts about 0.9 s, one cycle, then still |
| 4 (optional, only on tap) | Marker or token tapped: the why card opens. | Board / card | on demand |

Rules that make this calm:
- One new thing at a time, never two arriving in the same frame.
- Everything ends still. No cue loops after the stop. A resting state is a static shape.
- Quiet by default: a stop with no named Echo has no portrait pulse. That is the common case, so most stops are marker only.
- The snippet and bark are flavour and already ship. They do not become part of the stop read. Proposal: the stop marker is the answer, the snippet stays a caption. See section 3 for how to stop them colliding.

## 3. What to drop or merge

| Cue | Proposal | Reason |
|---|---|---|
| Marker head (shape) | KEEP. This is the minimum. | It is the only cue that carries stop kind with no text. D-38 item 1 asks for it. |
| Ground ring | MERGE into the marker. One object: head plus a thin base mark, drawn together, same colour. | Two objects with one job. Merge halves the shapes on the board. |
| Dashed ray and chevron motion | DROP the motion. Keep chevrons as a static shape detail only where the shape needs them (met vs spotted). | Motion that loops draws the eye after the read is done. Shape is already the carrier. |
| Settle animation of the marker | KEEP, one beat (scale 1.15 to 1.0, short ease out, no loop). | Gives the "it happened" feel. Cheap. |
| Portrait pulse | KEEP only when an Echo is named. One cycle, then a static faint ring. | It is a real signal (D-38). It must not play on every stop. |
| Step bar crossed steps | KEEP, but static. No animation at stop time. It is a HUD fact read at rest. | Satisfies D-40 item 8. It is NOT the shaken beat. |
| Shaken beat (D-38 item 2) | MERGE with the step bar: the crossed steps appear with one small "scratch" in the same 0.2 s as the marker settle. Do not add a separate screen beat. | The step bar already shows loss as a shape. A second, separate beat is a duplicate. If Jeff wants the beat stronger, one quiet nudge of the bar (a 4 unit shift and back) is the most I would add. |
| Snippet | KEEP as shipped, but start it AFTER the marker settles (about 0.9 s), not with the walk. Do not change its hold in this story (see section 4). | Text and marker no longer fight for the first second. This is a timing change only. Outcome unchanged. |
| Party bark | Leave. Report only: two text blocks (bark plus snippet) in one window is already dense. Out of this story's scope. | Scope control. |
| Journey entry at rest (under top HUD) | Do not show it as a standing text block. Show it only inside the why card. | D-32: why is on demand only. A standing block would make "on demand" untrue. D-32 also asks for a persistent journey entry for keyboard and screen-reader users: that is the same content, reachable by the same tap or a focus target, not drawn at rest. ASSUMED, see OPEN. |
| Directive badge | Leave as shipped (already in the HUD). In the mockup, draw it small and plain. | It is not part of the stop moment. |
| Review tools (touch map, grey, light/dark, options 2 and 3) | Move out of the demo frame. | They are for review. They inflate the sheet. |

Minimum readable stop = marker head (merged with its base mark) + static step bar. Add the portrait pulse only when an Echo is named. The card is on tap.

Screen-reader and keyboard note: the marker and the journey entry need an accessible name and focus order. That is `ui-ux-designer` scope.

## 4. Proposed timing outline for the demo

A scripted loop the mockup can run on a button press: "Advance". Times are from the start of the Advance. All are PROPOSALS (D-37: Jeff approves after seeing; nothing goes in config yet).

| t (s) | Beat | Detail |
|---|---|---|
| 0.00 | Tap "Advance" | Instant press feedback (button depress), under 0.1 s. Button disabled during the walk. |
| 0.00 to 0.50 | Walk | Same as shipped: 0.5 s total, equal segments, ghost drops, diamonds spent. Demo uses a 4-tile path so each tile is 0.125 s. |
| 0.50 | Token parks | Walk ends. No other cue yet. A short rest. |
| 0.60 to 0.85 | Marker settles | Head appears at 0.95 scale and 0 alpha, goes to 1.0 scale with a small overshoot to 1.1 then 1.0, ease out. About 0.25 s. Base mark fades in with it. Then still. |
| 0.60 to 0.80 | Step bar update (only if shaken) | Lost steps get the cross in the same 0.2 s as the marker. No separate beat. |
| 0.90 | Portrait pulse (only if an Echo is named) | One cycle of about 0.5 s, then a static faint ring. Skipped for most stops. |
| 0.90 | Snippet fade in | Shipped fade (0.4 s), shipped hold (2.1 s), shipped fade-out (0.5 s). Only the start moves, from 0.0 s to about 0.9 s. |
| about 1.4 | Calm | Everything on the board is still. Button re-enabled. |
| any time after 0.85 | Tap marker or token | Why card opens with a short fade (about 0.15 s). Tap outside or tap marker again closes it. Not a modal blocker: the board stays visible. |

Demo variants to show with one switch (not all at once):
1. Quiet stop: marker only.
2. Named-Echo stop: marker + portrait pulse.
3. Shaken stop: marker + crossed steps in the same beat.
4. Reduced motion: no scale overshoot, no pulse; the marker simply appears. The ring stays as the static signal. (Needs a setting. Flag only; that is not new scope here.)

Frame budget: all of this is a handful of transforms and alpha tweens on 2 to 3 nodes. Cost is trivial. I have not measured on device; this is an estimate, so qa-verifier or Jeff should confirm on the 1280x720 base.

Config note for D-37 and D-40 item 14: the new values (settle time, rest after walk, snippet start delay, pulse time) would be new tunables. They go in `data/balance.json` per ANSWERS #83 once Jeff approves, together with the existing literals listed in section 0. Not done now.

## 5. Touch-first notes (D-39)

- No hover state anywhere in the demo. Nothing is revealed on pointer-over. The "marker looks tappable" cue must be visible at rest: for example a slightly raised head or a thin base mark. Not an animation, not hover.
- The marker head and the party token are one target (alias, D-40 item 10). Size: at least 48x48, with 8 units to the next target. At 1280x720 the cell is small, so the demo should draw the invisible hit area larger than the head, and show it in an optional "touch map" only.
- Marker position and the EchoBar: the README already keeps tap areas out of the EchoBar and safe edges. A stop at a board edge can put the marker under the EchoBar or a thumb zone. The demo should show one edge-stop case and say what happens (proposal: the hit area is clamped inside the safe area; the drawn head may sit on the cell).
- The card: opens near the marker but stays inside the safe edges, in the lower half only if the thumb is likely there. Place the close action where the thumb rests (landscape: lower left or lower right). A tap outside closes the card, so no tiny close target is needed.
- Tap feedback: the marker gives an immediate small press response (scale 0.95 for about 0.08 s) before the card fades in. This is the "response" rule for async-free taps.
- Discoverability: the new-player test is in `ui-ux-designer` scope (design.md section 8). Feel can help: on the FIRST stop only, the marker could do one extra soft pulse after the settle. That is a proposal and needs Jeff; it could also count as a tutorial and is not decided. Wording of any hint is [Jeff's wording].
- Fat-finger: the walk disables the Advance button for 0.5 s; the rest of the HUD still takes taps. A tap on the marker DURING the walk should be ignored or queued; the demo should not open the card before the marker has settled (before about 0.85 s).

## 6. Placeholders for text (no wording written)

| Slot | Placeholder |
|---|---|
| Marker accessible name per kind (six) | [Jeff's wording] x6 |
| Card cause line | [Jeff's wording] |
| Card Echo line | [Jeff's wording] |
| First-stop hint (if any) | [Jeff's wording] |
| Snippet and bark | shipped content, unchanged |

## 7. Out of scope, reported only

- Bark plus snippet density at the same time (two text blocks in one second). Not changed here.
- Snippet hold of 2.1 s may be long for a calm board. Not changed; a candidate for the D-40 item 14 config pass.
- The 960x540 contract in AGENTS.md versus D-39: already an open item for Jeff.

## Handoff
`qa-verifier` verifies the finished mockup and, later, the build. Feel does not sign off its own work. No file was edited except this one. No Godot run. No command over 2 minutes.

## Skills used
`game-design` and `game-ui-ux-echoes` were not loaded. I judged the code and the decisions directly because the task was a read-only critique. `ponytail` principle applied: one file, no extras.

Ponytail skipped: a numeric budget for the portrait pulse and a reduced-motion spec (both need Jeff first); a measured frame cost (needs a device run).

## OPEN — questions and assumptions
ASSUMED: The marker is a static board object after settle, and the persistent journey entry (D-32) is the same content reached by the same tap or by focus, not a text block drawn at rest | WHY: D-32 says "on demand only" and also "persistent journey entry so keyboard and screen-reader users can read it"; both hold if the entry is persistent in data but not drawn at rest | WRONG IF: Jeff wants the last-journey text always visible on screen (README open item 3 puts it under the top HUD).
ASSUMED: The snippet start can move from 0.0 s to about 0.9 s without changing any outcome | WHY: it is a presentational delay; `_maybe_play_travel_snippet` is called right after the tween is built and its gate is exactly-once | WRONG IF: another system reads the snippet's visibility as a signal, or Jeff wants flavour text to lead the stop.
ASSUMED: The shaken beat (D-38 item 2) can be merged with the step bar cross-out | WHY: both show the same fact; the bar is a shape cue | WRONG IF: Jeff wants a separate, stronger beat on the board or the portrait.
ASSUMED: The portrait pulse plays only when an Echo is named, and rests as a faint ring | WHY: design.md section 8 says "a portrait pulse on the named Echo" | WRONG IF: Jeff wants a pulse on every stop, or no resting ring (README open item 1).
BLOCKED: Does Jeff want the first-stop discoverability pulse (one extra soft pulse on the first marker)? | CHECKED: design.md section 8 (trigger is a tap; `ui-ux-designer` tests discoverability), D-32, D-40 item 10 | NEED: Jeff's decision, or the ui-ux-designer discoverability result.
BLOCKED: Is there a reduced-motion setting in the game? | CHECKED: not searched beyond the stage screen and the decisions; I did not grep the settings code | NEED: ui-ux-designer or a grep of settings, before the demo shows a reduced-motion variant as real.
BLOCKED: Frame budget on the declared minimum window | CHECKED: no run made (read-only round) | NEED: a device or editor measurement at 1280x720 after the build.
