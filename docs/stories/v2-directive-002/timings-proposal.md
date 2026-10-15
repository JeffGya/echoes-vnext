# V2-DIRECTIVE-002 B+C: timing proposal for the stage stop frontend

Author: game-feel-developer. Status: PROPOSALS for Jeff (D-37). No value goes into `data/balance.json` now.
All times are seconds. Player wording is [Jeff's wording]. Engine: 4.6 (`project.godot` line 20), GL Compatibility. I found no 4.7 issue in the Tween calls named here. I did not check the 4.7 notes.

Sources read: D-32, D-37, D-38, D-40, D-41, D-42, D-55; design.md sections 8, 8.1; `mockups/review/feel-notes.md`; `mockups/v3/README.md`; numbers.md `stages.presentation` rows and section 12; `StageExploreScreen.gd` and `.tscn`; `RealmShell.gd`/`.tscn`; `EchoCardItem.tscn`; `AppRoot.gd`.

## 0. Findings that change the plan (read first)

| # | Finding | Evidence | Effect |
|---|---|---|---|
| F1 | The Advance runs on the main thread. While it computes, the screen does not redraw. Nothing can animate in that wait, so a spinner is impossible. | `AppRoot.gd:188-190`: `runtime.dispatch(action)` then `_render_snapshot(snap)`, one call. `StageExploreScreen.gd:1064` emits `action_requested` straight from the button signal. | Section 2: feedback must be a still image drawn BEFORE the compute starts. |
| F2 | The walk tween starts only when the snapshot arrives. The first frame after a long compute may carry a large delta. That could eat part of the 0.5 s walk. | `StageExploreScreen.gd:508-545`. I did not measure the engine delta after a hitch. | ASSUMED, see OPEN. Mitigation in section 2.4. |
| F3 | The Echo bar is NOT in the stage screen. It is `%EchoBar` in `RealmShell` (persistent chrome, layer 20). The stage screen cannot reach the cards. The glyph, the chip and the portrait pulse sit in the shell. | `RealmShell.tscn` node `ChromeLayer/ChromeRoot/EchoBarFrame/EchoBarScroll/EchoBar`; cards built at `RealmShell.gd:151-155`. | One clock must start the glyph beats in the shell and the shake beats in the screen. `ui-ux-designer` owns the hand-off. I give the clock in section 2. |
| F4 | A contact, sit or choice overlay opens on walk end (0.5 s). The glyph settles at 0.6 s, behind the dim. | `StageExploreScreen.gd:545` and `:628`. | OPEN question O1. |
| F5 | No reduced-motion setting exists. | grep of `ui/`, `core/`, `data/` for reduced/reduce motion: no match. | Section 3 says what to do once a setting exists. A setting is a scope decision for Jeff (O2). |
| F6 | The 0.4/2.1/0.5 snippet, 0.35 zoom, 0.25 preview, 0.1 flash and 0.35 reaction values are still literals in the screen. numbers.md says "UI reader pending". | `StageExploreScreen.gd:56, 71, 430, 1211-1213, 1239, 1286`. | The build reads them from the snapshot in the same pass (D-40 item 14). New keys use the same path. |
| F7 | `EchoBarScroll` already has `scroll_deadzone = 8`. A horizontal drag on a card does not count as a tap. | `RealmShell.tscn` line 53. | Good for section 4. Keep it. |

## 1. Timing table

Home for every key: `stages.presentation`. "Easing" uses Godot names (trans, ease). Times marked "from walk end" start at the end of the walk tween (0.5 s after the snapshot arrives).

### 1.1 Existing keys (keep)

| Key | Value | Easing | Controls | Why this value | Status |
|---|---|---|---|---|---|
| `walk_seconds` | 0.5 | linear | Whole walk, split in equal segments | Shipped. Each tile still lands as a footprint and a spent diamond. Keep. | Exists |
| `snippet_fade_in_seconds` | 0.4 | linear | Ghost text fade in | Shipped. Keep. | Exists |
| `snippet_hold_seconds` | 2.1 | none | Ghost text hold | Shipped. Keep. | Exists |
| `snippet_fade_out_seconds` | 0.5 | linear | Ghost text fade out | Shipped. Keep. | Exists |
| `zoom_seconds` | 0.35 | camera's own | Zoom | Not part of the stop. No change. | Exists |
| `preview_fade_seconds` | 0.25 | linear | Stage preview fade | Not part of the stop. No change. | Exists |
| `flash_half_seconds` | 0.1 | linear | Combat flash | Not part of the stop. No change. | Exists |
| `reaction_fade_in_seconds` | 0.35 | linear | Contact reaction word | Not part of the stop. No change. | Exists |

### 1.2 New keys

| Key | Value | Easing | Controls | Why this value | Status |
|---|---|---|---|---|---|
| `stop_rest_seconds` | 0.10 | none | Pause between token parked and first stop beat | The eye needs one beat to follow the token to a stop. Mockup used 0.10 (0.50 to 0.60). Replaces the reserved `shaken_shake_delay_seconds`: same job, now relative to walk end. | New |
| `beat_gap_seconds` | 0.05 | none | Gap between two stop beats in a chain | Keeps "one new thing at a time" without a visible hole. | New |
| `glyph_fade_seconds` | 0.20 | sine, ease in | Old glyph or chip leaves when the next Advance snapshot arrives | Mockup: fades as the new walk starts. It runs inside the 0.5 s walk, so it adds no wait. Reserved key. | New |
| `glyph_settle_seconds` | 0.25 | alpha: quad out over the first 40%. Scale: 0.95 to 1.10 quad out (60%), 1.10 to 1.00 sine in-out (40%) | Glyph on an Echo card appears once and rests | Mockup value. Long enough to read as "it landed", short enough to stay quiet. Reserved key. | New |
| `glyph_settle_from_scale` | 0.95 | n/a | Start scale | Mockup. | New |
| `glyph_settle_overshoot_scale` | 1.10 | n/a | Peak scale | Mockup. A glyph is small (about 24 units), so 1.10 is 2 to 3 units. Jeff may need 1.2. | New |
| `chip_settle_seconds` | 0.25 | same as glyph | Party chip appears | Same beat as the glyph, so both read as one gesture. Reserved key. | New |
| `glyph_press_seconds` | 0.08 | quad out | Tap feedback on glyph, card and chip: scale 0.95 and brightness 0.85, then back | Mockup value. Under 0.1 s reads as instant. | New |
| `why_open_seconds` | 0.15 | sine, ease out | Why card fades in | Mockup value. Starts at once on the tap. | New |
| `why_close_seconds` | 0.10 | sine, ease in | Why card fades out | Leaving is faster than arriving. Never blocks the next tap. | New |
| `portrait_pulse_seconds` | 0.50 | sine, ease in-out | ONE cycle of brightness on the named Echo's portrait (1.0 to 1.25 to 1.0). Not a scale: the card sits in a container. | Mockup value. One cycle, then still. Plays only when an Echo is named. | New |
| `portrait_pulse_peak` | 1.25 | n/a | Peak brightness | Starting value. A 40 unit portrait on a bottom bar needs a visible lift. | New |
| `shaken_shake_seconds` | 0.22 | none (steps) | Whole shake, token and step row together | Mockup. Reserved key. | New |
| `shaken_shake_offsets_px` | [3, 3, 2, 2] | none | Alternating sideways offsets, then back to 0. 4 moves = 2 oscillations. Each move is `shake_seconds` / 5 = 0.044 s; the 5th move returns to 0. | Mockup (3/3/2/2). Design says "2 to 3 oscillations": this is 2. Replaces the reserved `shaken_shake_oscillations`. Unit: screen pixels at the 1280x720 base. On the token, divide by camera zoom so the shake does not grow when zoomed in. | New |
| `cross_stagger_seconds` | 0.06 | none | Gap between lost-step crosses, left to right | The loss lands one step at a time, so "how many" reads without a number. Each cross fades in over 0.12 s (`cross_in_seconds`). | New |
| `cross_in_seconds` | 0.12 | quad out | One cross appears | With 3 lost steps: 0.06 + 0.06 + 0.12 = 0.24 s, near the 0.22 s shake. | New |
| `snippet_delay_seconds` | derived, see 1.3 | none | Start of the snippet after a TRAVEL snapshot | Judged in 1.3. | New |
| `reduced_motion_fade_seconds` | 0.15 | linear | Every fade-only replacement in section 3 | One shared value. | New |
| `overlay_hold_seconds` | 0.35 (only if Jeff picks O1 option B) | none | Delay of the contact, sit or choice overlay after walk end, only when a glyph is about to settle | Lets the glyph land before the modal covers it. | New, conditional |

Calm time and "input ready" are derived, not keys. See section 2.

### 1.3 Judgment: snippet start delay

The mockup used 0.9 s. I accept the idea and change the rule.

- Today the snippet starts WITH the walk (`StageExploreScreen.gd:540`). It is still fading in while the token parks. It competes with the stop read.
- A fixed 0.9 s breaks when the shaken chain is longer. So I define it as: start = the end of the last stop beat + `beat_gap_seconds`. Calm stop: 0.85 + 0.05 = 0.90 s. Same as the mockup. Shaken stop: later (1.15 s).
- It applies only to a TRAVEL snapshot. A non-travel snapshot (first entry to the stage, `StageExploreScreen.gd:558`) plays the snippet at once, as today. Otherwise a stage entry would wait for a glyph that is not there.
- The exactly-once gate (`_maybe_play_travel_snippet`) stays as is. The delay goes before the fade in, not in the gate.
- Cost: the text ends at about 3.9 s instead of 3.0 s. The player is not blocked (section 2).

## 2. Scripted timeline: Advance press to calm

t = 0 is the press. `C` = compute time (the freeze). `W` = the snapshot arrives = `C` after the press. Walk start = `W`. All later times are written from `W` (call it w+). Below, "calm" values assume a 3-tile or longer walk. `walk_seconds` is fixed at 0.5 s for any path length.

### 2.1 Common start (all three stops)

| Time | What the player sees |
|---|---|
| t = 0 (press down) | The Advance button shows its pressed style at once (theme, `button_down`). |
| t = 0 to 1 frame | UI sets a still "working" state: button disabled, pressed look held. The old glyph or chip dims to 50% alpha. It does not animate. The `action_requested` is emitted one rendered frame later (F1). |
| Compute `C` | Screen is frozen on that still image. This is by design (section 2.4). |
| w+0.00 | Snapshot arrives. Walk starts (linear). The old glyph or chip fades out over 0.20 (it is already at 50%). Footprints drop and diamonds spend per tile as shipped. |
| w+0.50 | Token parks. Walk ends. Shipped overlay hook fires here (F4). |
| w+0.60 | `stop_rest_seconds` (0.10) is over. First stop beat starts. |

### 2.2 The three timelines

| w+ | A. Calm stop: an Echo is named, party steady (glyph on the card) | B. Directive stop: Directive is the cause, no Echo named (chip) | C. Shaken stop: steps dropped, no deciding Echo (chip) |
|---|---|---|---|
| 0.00 | Walk starts. Old glyph fades. | Same | Same |
| 0.50 | Token parks. | Same | Same |
| 0.60 | Card glyph settles (0.25). | Party chip settles (0.25). | Crosses stagger in (0.24) and the token and step row shake (0.22). The chip waits. |
| 0.84 | | | Crosses done. Shake done at 0.82. |
| 0.85 | Glyph at rest. **Input ready.** | Chip at rest. **Input ready.** | |
| 0.89 | | | `beat_gap` (0.05). |
| 0.90 | Portrait pulse (0.50) starts. Snippet starts (fade in 0.40). | Snippet starts. No pulse. | Chip settles (0.25). |
| 1.14 | | | Chip at rest. **Input ready** at 1.15. |
| 1.15 | | | Snippet starts. |
| 1.40 | **Calm.** Pulse done. Board still. Snippet text is still fading in or held. | **Calm.** Board still. | |
| 1.65 | | | **Calm.** |
| 3.90 / 4.15 | Snippet fully gone (A and B 3.90, C 4.15). | | |

Notes on the table:

1. "Input ready" is when the Advance button re-enables. It is earlier than the mockup's calm (1.4 s). Reason: the pulse and the snippet are decoration. Locking input behind them breaks Response, which ranks first. If the player presses Advance during the pulse or the snippet, the pulse stops at once and the snippet fades to 0 over `reduced_motion_fade_seconds` (0.15). Judge this in play (section 5).
2. In A, the pulse and the snippet start in the same frame. One is at the bottom and one at the top, and the snippet is a slow alpha fade. If it still reads as two events, move the snippet 0.25 s later (1.15 s). Try it in the game.
3. In C the chip comes AFTER the shake. The mockup put the cross-outs, shake and mark in one beat. With a chip at the bottom and the shake on the board top, that is three places at once. Sequencing costs 0.25 s and keeps the shake clean.
4. The shake runs on the token and the step row at the same time, same offsets, same start. The cross-outs run under it. Under a shake the first cross lands at 0.60.
5. If the stop kind is "Arrived" and the cause is empty, it is timeline B (chip, no pulse).
6. The stop is drawn from the result of the last Advance (design 8.1). The timeline never depends on a timer in the simulation.

### 2.3 Hook points (where each beat would attach)

| Beat | Where | Note |
|---|---|---|
| Walk end clock | `_travel_tween` in `StageExploreScreen.gd:508-545`. Append the stop beats to this one tween as intervals and callbacks, so there is one clock. | `_apply_pending_overlay` already hangs on `finished` (`:545`). See F4/O1. |
| Token shake | `PartyTokenLayer` (`WorldLayer/BoardRoot`). Offset the token sprite, not the logical position, so the camera follow target (`display_position`) is not shaken. | Divide offsets by camera zoom. |
| Step row shake and crosses | `BottomHudRegion/StepBudgetRow/StepProgressBar`. The row is an `HBoxContainer`, so a direct `position` change is reset by layout. The diamonds need a plain `Control` wrapper in the `.tscn`. | `ui-ux-designer` adds the wrapper. `StepFractionLabel` is deleted (D-43). |
| Glyph, pulse | `EchoCardItem` inside `%EchoBar` (`RealmShell`). Pulse target: `PortraitPanel` (ColorRect, 40 x 40). The card is the tap area (at least 48 units, D-39). | F3. Use `modulate` for the pulse. Do not scale a card in a container. |
| Chip | Beside the cards, inside the safe area, in the shell (D-42). | `ui-ux-designer` places it. |
| Snippet delay | Before the fade in at `StageExploreScreen.gd:1210`. | Only on a travel snapshot. |
| Advance press state | `AdvanceButton` (`BottomHudRegion/ActionBar`); `_on_advance_pressed` at `:1064`. | Section 2.4. |
| Lock during the walk | `_is_travelling()` at `:1794`. | Reuse for the token tap lock (section 4). |

### 2.4 A slow Advance (compute 200 to 500 ms on a phone)

What the player sees during the wait:

1. A pressed Advance button, held. The button is disabled. The old glyph is dimmed. Nothing moves.
2. No spinner. F1 says the screen cannot redraw during the compute, so a spinner would freeze on its first frame. A frozen spinner looks broken. A still pressed state is honest.

Maximum wait before feedback: **one rendered frame** (about 17 ms at 60 fps, 33 ms at 30 fps). Target: under 50 ms. Starting value test: on the slowest target phone, press Advance 20 times and record the time from touch to the first changed pixel. Pass: 95% under 50 ms. If it fails, the deferred emit is the first thing to check.

How to get it (UI only, no sim change): on press, set the still state, then emit `action_requested` after one frame (`call_deferred` or one `process_frame`). `ui-ux-designer` decides how. The sim and its outcome do not change (feel never changes outcomes).

Walk start after a long compute (F2): the first tween frame may get a large delta. Mitigation: create the walk tween one frame after the snapshot is applied, so the hitch frame is not counted. Test: log the tween's elapsed time at the first and second frame with `C` forced to 400 ms. Pass: the walk takes 0.5 s of real time after the first drawn frame. If the engine already clamps this, skip the mitigation.

What I cannot fix with timing: the tail. D-55 measured the worst 5% at about 600 ms (Scout) and about 1 s (Seek) on a desktop, before the package E trim. A phone is slower. Above about 0.5 s of frozen still image, the player may think the game hung. Timing cannot cure this. Package E and V2-INFRA-010 can. I list it as a risk.

## 3. Reduced motion

No setting exists (F5). The table says what each effect does once Jeff decides the setting (O2). Rule: nothing moves across space, nothing scales, nothing shakes. Fades stay (`reduced_motion_fade_seconds`, 0.15).

| Effect | Normal | Reduced motion |
|---|---|---|
| Walk | 0.5 s, camera follows, footprints and diamonds per tile | Token and camera jump to the end. Footprints and the spent diamonds appear together. 0 s walk. |
| Old glyph leaves | Fade 0.20 | Fade 0.15 |
| Stop rest | 0.10 | 0 |
| Glyph or chip settle | Fade + scale 0.95/1.10/1.0 | Fade only 0.15. No scale. The glyph is the stop's signal and still appears. |
| Portrait pulse | One cycle 0.5 s | Skipped. The glyph is the signal. |
| Shake | 0.22 s | Skipped (D-41). |
| Cross-out stagger | 0.06 apart | All crosses fade in together over 0.15. The loss still shows. |
| Snippet | Fades, delayed | Same fades. Start = 0.15 + beat gap. |
| Why card | Fade 0.15 / 0.10 | Same. A fade is not motion across space. |
| Press feedback | Scale 0.95 + brightness | Brightness only. |
| Resulting timeline (A) | Input ready 0.85, calm 1.40 | Input ready about 0.20, calm about 0.20 (snippet continues) |

## 4. Touch

| Item | Proposal | Why |
|---|---|---|
| Press feedback | On touch down, glyph, card and chip show brightness 0.85 and scale 0.95 for `glyph_press_seconds` (0.08). The card opens on release. | Every touch gets an answer in one frame, even when the result is a fade. |
| Minimum hold | **None.** A tap fires on release inside the target. A drag of 8 or more units cancels it (`scroll_deadzone = 8` already exists, F7). | A hold requirement feels laggy and fails a short tap. |
| Target size | Card at least 48 x 48 with 8 units to the next target (D-39). The glyph is smaller than 48, so the whole card is the tap area for the Echo case (design 8.1 item 2). The chip hit area is at least 48 x 48 even when the drawn chip is smaller. | D-39. |
| Lock | Before the glyph or chip is visible (walk, rest, and the shaken chain before the chip, w+0 to w+0.60, or to w+0.90 in C): a tap on the token or the previous glyph is ignored. The previous glyph is dimmed and not tappable during the compute. From the first visible frame of the settle the glyph IS tappable. No lock during the 0.25 s settle. | A visible glyph that ignores a tap breaks Response. The card content is already in the snapshot, so no data waits on the animation. The mockup locked until 0.85 s: I advise against it. |
| Token tap during the walk | Ignored. No queue. | Smallest rule. A queue adds a state for little gain. |
| Why card close | Second tap, outside tap or Escape (design 8.1). Close never blocks the next Advance: the card closes (0.10) when Advance is pressed. | Response. |
| Tap while the Advance computes | All ignored (button disabled, glyph dimmed). | The still image says "busy". |

## 5. Confidence

| Confident (take as is) | Why |
|---|---|
| Walk 0.5 s, snippet fades 0.4/2.1/0.5 | Shipped. Players have seen them. |
| Press feedback 0.08, no minimum hold | A short press response is a safe default. Starting value; the test is "feels instant". |
| Why card open 0.15 / close 0.10 | Short fades on a non-blocking card. Low risk. |
| Glyph settle 0.25 and the chip with it | Mockup value. Jeff approved the look (D-41). |
| One shake, once, no loop; skipped under reduced motion | Jeff's rule (D-41). |
| Press-state-then-deferred-emit | The only honest feedback under F1. Structure is certain; the frame count is not tunable. |

| Try in the game and tune | What to look for | Likely adjustment |
|---|---|---|
| Shake size [3,3,2,2] px | Visible on a 1280x720 base and on a phone? 3 units is about 0.23% of the width. | Raise to [5,5,3,3]. |
| Glyph overshoot 1.10 | On a 24 unit glyph this is 2 to 3 units. May read as nothing. | 1.2 or longer settle 0.30. |
| Portrait pulse peak 1.25 and 0.5 s | Does the eye reach the bottom bar? Does it fight the snippet at the same frame? | Peak 1.4, or snippet +0.25 s. |
| Stop rest 0.10 and beat gap 0.05 | Do beats feel like one gesture or like stutter? | Rest 0.15. Gap 0. |
| Cross stagger 0.06 / 0.12 | Does a player count the lost steps without a number? | Stagger 0.10. |
| Snippet start (end of last beat + 0.05) | Is the walk-to-text hole too long? Is the text late for a fast player? | Back to 0.5 s after walk end. |
| Input ready at 0.85 (not 1.4) | Does cutting the pulse on the next press look rough? | Lock to 1.4 s. I advise against. |
| Chip after shake (C, +0.25 s) | Does the extra 0.25 s feel slow on repeated shaken Advances? | Chip at the same time as the shake. |
| Frame budget | Everything here is alpha, modulate and small transforms on 2 to 3 nodes. I did not measure it. `qa-verifier` or Jeff checks on the 1280x720 base and a real phone. | n/a |

Hand-off: `qa-verifier` checks the build. I do not sign off my own polish.

## OPEN — questions and assumptions

ASSUMED: The Echo bar glyph and the party chip live in `RealmShell`, outside the stage screen scene, so the stop beats need one shared start signal from the walk tween. | WHY: `RealmShell.tscn` has `%EchoBar`; `StageExploreScreen.tscn` has no Echo bar. | WRONG IF: `ui-ux-designer` decides to draw a copy of the cards inside the stage screen.

ASSUMED: The first tween frame after a long compute can carry a large delta (F2). | WHY: the tween is created inside the same call that does the compute (`AppRoot.gd:188-190`). I did not measure it. | WRONG IF: Godot clamps the process delta; then the one-frame-late tween start is not needed.

ASSUMED: The player is allowed to press Advance as soon as the glyph or chip has settled, and a running pulse or snippet is cut. | WHY: Response ranks first, and the decoration carries no rules (design 8.1). | WRONG IF: Jeff wants the full 1.40 s calm before the next Advance.

ASSUMED: Shake offsets are screen pixels at the 1280x720 base, applied to the token sprite divided by camera zoom. | WHY: a world-pixel shake would grow with the camera zoom (default 1.3, max 2.2). | WRONG IF: Jeff wants the shake to scale with the board.

BLOCKED: O1. A contact, sit or choice overlay opens at walk end (0.5 s) and covers the glyph that settles at 0.6 s. Which order does Jeff want? Option A (default, no change): overlay opens at 0.5 s, the glyph settles behind the dim, and the glyph is visible when the overlay closes. Option B (my pick): the overlay waits `overlay_hold_seconds` (0.35 s) so the glyph lands first. Option B delays every contact by 0.35 s but shows "Met something" before the conversation. | CHECKED: `StageExploreScreen.gd:545, 628`; design 8.1; D-41. No decision recorded. | NEED: Jeff's choice. It is a pacing choice, not a simulation change.

BLOCKED: O2. Does Jeff want a reduced-motion setting in this story? None exists (grep of `ui/`, `core/`, `data/`). The mockup and D-41 already assume "off under reduced motion". Where it is stored and who reads it is a save and settings decision. | CHECKED: grep of the three folders, `docs/stories/v2-directive-002/mockups/review/feel-notes.md` (flags it as "not new scope"). | NEED: Jeff's yes or no, and `mechanics-developer` or `ui-ux-designer` to own the setting. Until then section 3 has no switch to read.

BLOCKED: O3. The tail of a slow Advance (about 1 s on a desktop for the worst 5% of Seek, D-55) is longer than the 200 to 500 ms the brief assumed. A still pressed button for 1 s or more may read as a hang on a phone. | CHECKED: D-55 numbers; `AppRoot.gd:188`. | NEED: the package E result and a phone measurement. If the tail stays above 0.5 s, Jeff may want a second still cue (for example a changed button label, [Jeff's wording]).

ASSUMED: Replacing the reserved keys `shaken_shake_delay_seconds` (now `stop_rest_seconds`) and `shaken_shake_oscillations` (now the length of `shaken_shake_offsets_px`) is acceptable. | WHY: both were reserved with no value (numbers.md section 12), so nothing reads them. | WRONG IF: another file already reads those names.

## Skipped (ponytail)

- No pulse scale animation: the card sits in a container, so I use brightness.
- No queue for a token tap during the walk: one ignore rule is smaller.
- No spinner or loading bar: F1 makes it impossible without a thread (Jeff declined threads in D-55).
- No separate "calm time" key: it is derived from the beats.
- No per-device timing scale: one set of values until a phone measurement says otherwise.
- No first-stop discoverability pulse: it is a tutorial choice for Jeff and `ui-ux-designer` (feel-notes section 5).
