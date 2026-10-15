# Play findings report (Jeff's play of the B+C frontend build)

Branch `claude/v2-directive-002-phase-bc`, head `d05aa9a` + docs (`66f4530`). Written 2026-10-14.
No repo file was changed except this report. No code is proposed.

## 0. Method and limits

| Item | Fact |
|---|---|
| Save | Jeff's `slot_01.json` was COPIED to a scratch folder. The runs used a separate work copy of that copy. The original has the same SHA-1 as the copy (`8970c478...`) and the same timestamp (23:04). Runs used `HOME=<scratch>` so Godot wrote nothing to the user folder. |
| Save path rule | `FlowRuntime.new(logger, config, save_path)` takes an explicit path. The runs passed the scratch path. `ECHOES_TEST_SAVE_DIR` was not needed. |
| Party in the save | 3 Echoes: Enyonam (morale 50), Edward (morale 72), Benjamin (morale 46). Fear 2 for all. No Calling for any Echo. |
| Stage | `realm.01`, `stage.0` (also `stage.1`, `stage.2` for Part C). Real `stage.advance_turn` dispatches. |
| Timing runs | Windowed Godot 4.6.1 (M2, Metal, 1280x720 logical, layout `standard`). The real `RealmShell` and `StageExploreScreen`. The script pressed the real Advance button and polled `disabled` every frame. Each run is under 100 s. |
| Old commits | Scratch git worktrees at `36094de` and `6d9bca4` (the commit before `345b392`). Both are removed. `git worktree list` now shows only `main` and the current worktree. |
| Not done | No full suite. No filtered test. Nothing was committed. |
| Synthetic data | No real Advance named an Echo (Part C). The "named Echo" screenshots use a REAL snapshot with the named fields filled in (Echo id, name, cause `echo`). They test layout only. |
| Scripts and images | `.../scratchpad/play/scripts/` (`probe_bc.gd`, `win.gd`, `overlay.gd`). Images: `.../scratchpad/play/shots3/` and `shots5/` (files `chip_why_seek.png`, `named_why_seek.png`, `overlay_*.png`). Raw logs: `.../scratchpad/play/*.txt`. |

---

## A. Finding 1: Advance is slower, "every other click does nothing"

### A1. Measured time from the Advance press to the Advance button enabled again

Calm stop and shaken stop are measured in the windowed run. Each row is the range over the Advances in the run (calm: 12 valid rows, shaken: 7 valid rows). An Advance that opens a situation overlay is left out: the button stays off until the situation closes.

| Build | Stop | Press to snapshot | Snapshot to enabled | Press to enabled | Button disabled by the press? |
|---|---|---|---|---|---|
| Current (`d05aa9a`) | Calm, chip (no Echo named) | 209 to 279 ms | 667 to 741 ms | **900 to 1018 ms (typical 975 ms)** | Yes |
| Current | Calm, 5 Echoes (3 + 2 clones) | 238 to 281 ms | 714 to 741 ms | 964 to 986 ms | Yes |
| Current | Calm, Scout (1 or 2 steps) | 143 to 195 ms | 720 to 742 ms | 898 to 934 ms | Yes |
| Current | Shaken (fear 60), chip | 207 to 233 ms | 984 to 998 ms | **1193 to 1213 ms (typical 1200 ms)** | Yes |
| Current | Named Echo | not pressed (synthetic) | - | The beat plan is the same as the calm chip: `ready_at` 0.35 s (shaken 0.62 s). Expect the same time as the matching chip row. | Yes |
| `36094de` (before the motion work) | Calm | 212 to 268 ms | 3 to 9 ms | **221 to 273 ms** | Yes, until the snapshot only |
| `6d9bca4` (before the UI work, `345b392~1`) | Calm | 202 to 268 ms | 5 to 15 ms | **217 to 274 ms, but the button was never disabled** | No |

How to read the table:

- "Press to snapshot" is the main-thread compute of the Advance (about 0.22 to 0.28 s with 3 Echoes) plus one drawn frame.
- The compute blocks the main thread in every build. A click in that time waits in the OS queue.
- In `36094de` the button came back at the snapshot. It was disabled only during the compute.
- In `6d9bca4` the button was never disabled by a press. A press during a walk was accepted and cut the walk (`_travel_tween.kill()`).
- The current time is the compute plus the walk plus the stop beats.
- Jeff's terminal log shows one "Party advanced" about every 1 s. This matches 0.95 to 0.98 s.
- Arithmetic from config (`stages.presentation`): walk 0.5 s + `ready_at`. Calm: `stop_rest` 0.1 + `chip_settle` 0.25 = 0.35. Shaken: 0.1 + shake 0.22 + gap 0.05 + 0.25 = 0.62.
- The walk is 0.5 s for any step count (one step is also 0.5 s). The snapshot-to-enabled value is about 0.12 s under the arithmetic sum (0.85 s). The tween starts after `set_snapshot` has done its own work.
- `timings-proposal.md` and D-57 count "input ready 0.85 s" from the snapshot. They do not count the compute. So the player waits 0.85 s plus the compute.

### A2. Every code path that disables or blocks the Advance button

File `ui/screens/venture/StageExploreScreen.gd`.

| # | Line | What it does | Cleared by | Duration (measured) |
|---|---|---|---|---|
| 1 | 1085 | `_advance_pending` guard: a second press is ignored | `set_snapshot` (line 333) | Press to snapshot: 0.14 to 0.28 s |
| 2 | 1088 (`_on_advance_pressed`) | `_advance_btn.disabled = true` at press | Not cleared by the snapshot (see 3). Cleared by 4 | Press to input ready |
| 3 | 618 | On every snapshot: `disabled = not _advance_allowed or is_travel`. A travel snapshot keeps the button off | 4 | Whole walk |
| 4 | 1918 to 1921 (`_on_input_ready`) | Sets `disabled = not _advance_allowed`. Called by `_stop_tween` at `ready_at` after the walk | - | Walk 0.5 s + 0.35 s calm, + 0.62 s shaken |
| 5 | 1088 before 1089 | The press feedback frame: `await RenderingServer.frame_post_draw`, then `action_requested` is emitted | - | 1 frame (about 17 ms) |
| 6 | 617 | `_advance_allowed` comes from `actions["cta.advance_turn"].disabled` (no target, situation pending) | Next snapshot | Until the situation is closed |
| 7 | 1338 | A contact panel disables Advance and Return Home | Next snapshot | Until the contact is closed |

At `36094de` only paths 1, 2 (cleared at the snapshot, line 599 `disabled = adv.disabled`), 6 and 7 existed. Paths 3 and 4 are new in the motion work (`6a4aad2`). At `6d9bca4` only 6 and 7 existed.

### A3. Clicks ignored at a 0.5 s click rhythm

The script clicks every 500 ms of real time for 24 s. A click counts only if the button is enabled when the frame delivers it.

| Build | Clicks | Accepted | Ignored | Ignored share |
|---|---|---|---|---|
| Current | 49 | 27 | **22** | 45 percent (about every second click) |
| `36094de` | 49 | 49 | 0 | 0 percent |
| `6d9bca4` | 49 | 49 | 0 | 0 percent |

Plain words: the lock is about 0.98 s. A click every 0.5 s is ignored every second time. This matches Jeff's words.

---

## B. Finding 3: Seek Signs steps and the step row

### B1. Numbers for Jeff's save (3 Echoes, calm), 30 Advances each

| Variant | Directive | `step_budget` (snapshot) | `effective_steps` (snapshot) | Dial `commitment_fraction` after leans | `commitment_depth` | Steps walked | Diamonds shown | Crossed out | Gold left after the walk |
|---|---|---|---|---|---|---|---|---|---|
| Jeff's save as copied | Seek | 6 | 6 | 0.862 (0.85 + 0.012) | **5** | 5 in 26 of 30 (1, 4 or the rest: stops ended early) | 6 | 0 | **1** |
| Jeff's save as copied | Scout | 3 | 3 | 0.612 (0.60 + 0.012) | 2 | 2 in 23 of 30 (else 1) | 3 | 0 | 1 |
| All Echoes morale 90 | Seek | 6 | 6 | 0.930 | **6** | 6 in 22 of 30 | 6 | 0 | **0** |
| All Echoes morale 90 | Scout | 3 | 3 | 0.680 | 2 | 2 in 23 of 30 | 3 | 0 | 1 |
| All Echoes fear 60 (shaken) | Seek | 6 | **5** | 0.862 | 4 | 4 in 26 of 30 | 6 | **1** | 1 |
| All Echoes fear 60 (shaken) | Scout | 3 | **2** | 0.612 | 1 | 1 in 30 of 30 | 3 | **1** | 1 |
| 5 Echoes (2 clones) | Seek | 6 | 6 | 0.866 | 5 | 5 in 26 of 30 | 6 | 0 | 1 |

Other dials in Jeff's save (Seek): `exposure_tolerance` 0.815, `stop_willingness` 0.300, `escape_bonus` 0. Lean on `commitment_fraction` per Echo: Enyonam 0.000, Benjamin -0.008, Edward +0.044 (his morale 72 gives (72-50)/50 x 0.1). The party mean is +0.012.

Calling variants (Edge, Anchor, Sight) moved the dial by less than 0.01 in the runs. The depth did not change.

### B2. Why Seek can walk 6 steps

The rule is `depth = clamp(round(effective_steps x commitment_fraction), 1, effective_steps)` (`StagePartyStance.gd`, last lines of `build`).

| Step | Value |
|---|---|
| Seek baseline `commitment_fraction` (`directive_profile`) | 0.85 |
| Largest party lean (`bounds.commitment_fraction`) | +0.10 |
| Largest dial | 0.95 |
| `round(6 x 0.85)` | `round(5.10)` = 5 |
| `round(6 x 0.95)` | `round(5.70)` = 6 |
| Threshold for 6 steps | `6 x f >= 5.5`, so `f >= 0.9167` |
| Lean needed | +0.067 or more: 67 percent of the bound |
| Lean sources | Morale: 1.0 x bound x (morale - 50) / 50. Edge Calling: +1.0 x bound x strength. Anchor and Sight: -0.5. |
| Example | All Echoes at morale 83 or more (no Callings) reach it. Measured: morale 90 gives 0.930 and depth 6. |

In Jeff's saved party the mean lean is only +0.012. The depth is 5, not 6. So his save as saved walks 5. I cannot say what his party morale was in the play. A party with morale of 83 or more, or with Edge Callings, walks 6.

### B3. What the step row shows

| Walk | Row |
|---|---|
| Seek, depth 5 | 6 diamonds. 5 dim, **1 stays gold**. No cross. |
| Seek, depth 6 | 6 diamonds, all 6 dim at the end. No cross. |
| Seek, shaken | 6 diamonds. The last one has a red cross. 4 dim, 1 gold. |
| Scout | 3 diamonds. 2 dim, 1 gold. |
| Scout, shaken | 3 diamonds. The last one has a red cross. 1 dim, 1 gold. |

The row never shows the commitment depth. The row shows capacity and lost capacity only.

### B4. Where the step row reads (all places)

| Place | Reads | Line |
|---|---|---|
| `StageExploreScreen._enter_explore_mode` | `step_budget`, `effective_steps` | 595 to 599: `set_budget(step_budget, step_budget - effective)` |
| `_on_step_consumed` | the walked count `_seg_i + 1` of the walk tween | 1193 to 1195: `set_spent(n)` |
| `_build_stop_plan` | `step_budget`, `effective_steps` | 1838 to 1839: lost count for the shake and the crosses |
| `StepProgressBar` | what the screen gives it | `set_budget`, `set_spent`, `set_cross_alpha` |

`commitment_depth` is NOT in the snapshot. Confirmed: `grep` in `ui/` finds no `commitment`. The snapshot builder (`StageExploreSnapshotBuilder.gd` lines 471 and 496) carries `step_budget` and `effective_steps` only.

### B5. What sets Jeff's expectation ("should be 5")

| Source | Says | Effect |
|---|---|---|
| `design.md` section 5, row "Direction" | "A calm party walks the Directive baseline." Seek baseline 6. | Capacity is 6. |
| `design.md` section 5, row "Seek at the cap" | Seek's baseline is already the cap (6). | Capacity is 6. |
| `design.md` section 8.1 item 5 and D-40 item 8 | The bar shows the BASELINE (`step_budget`) as diamonds. Lost steps are crossed out. | Row = 6 diamonds, by design. |
| D-43 | No count text. Diamonds only. | The player cannot read "5 of 6". |
| D-50 A1 | Keep `roundi` and Seek 0.85. "Seek 6 x 0.85 rounds to 5." | Jeff approved 5 for Seek. |
| `numbers.md` section 3, row `commitment_fraction` | Seek range 0.75 to 0.95. | 0.95 is inside the range, so 6 is in the design range. |
| `numbers.md` section 4 | Seek 0.85, Scout 0.6. "Seek spends most of its steps." | Seek walks about 5. |

Finding: the code follows the written design. The design text has two numbers for one idea. Capacity (6) is shown. Commitment (5, sometimes 6) is walked. The row does not show the commitment. So a player sees 6 diamonds, a 5-step walk and one gold diamond left. Or a 6-step walk with a full dim row while D-50 said 5. Both are "out of sync" to a player. D-40 item 8 chose the baseline on purpose. D-50 changed the walked count later. No decision says what the row shows for commitment.

Which reading of Jeff's words is true? I cannot tell:

1. Reading A: the party walked 6 and Jeff expected 5 (D-50). This needs a morale of 83 or more, or Edge Callings (B2).
2. Reading B: the party walked 5 and the row had 6 diamonds, with 1 gold left. This matches his saved party exactly.

---

## C. Finding 5: the reason is generic text and names no Echo

### C1. 30 Advances per Directive, Jeff's save, `stage.0`

Full per-Advance listing is in `seek_calm.txt` and `scout_calm.txt`. Summary:

| Directive | Named Echo | Not named | `directive` | `terrain` | `situation` | `objective` | `party` | `echo` |
|---|---|---|---|---|---|---|---|---|
| Seek | **0** | 30 | 24 | 3 | 3 | 0 | 0 | 0 |
| Scout | **0** | 30 | 21 | 4 | 4 | 1 | 0 | 0 |

Stop kinds: Seek `capacity_spent` 23, `arrived_at` 5, `spotted_ahead` 1, `interrupted` 1. Scout `capacity_spent` 20, `arrived_at` 5, `paused_to_read` 4, `spotted_ahead` 1.

Typical `travel_why` for a calm Seek Advance: `cause directive`, `purpose_family read`, `route_character ""`, `stop_kind capacity_spent`, `named_echo_name ""`, `echo_reason_class ""`.

### C2. More runs (same method, 30 Advances each)

| Variants | Runs | Advances | Named | Cause counts |
|---|---|---|---|---|
| Calm, morale 90, fear 60, 5 Echoes, three Callings, Edge x3 at morale 100, Anchor x3 at fear 45, `stage.1`, `stage.2`; both Directives | 21 runs in all (the two in C1 included) | 606 | **0** | `directive` 286, `party` 123, `terrain` 80, `situation` 75, `objective` 42, `echo` **0** |

Zero Advances in 606 named an Echo. The test suite builds named cases on purpose (`design.md` section 7). A normal play board did not produce one in these runs.

### C3. What the why card shows for these values

`data/ui/stage_why_text.json` has only placeholders. `StageWhyText.compose` gives a title from `stop_kind` and one row each for `cause`, `purpose_family` and `route_character`. It adds an Echo row only if `named_echo_name` is set.

| Snapshot values | Card (real screenshot) |
|---|---|
| `capacity_spent`, `directive`, `read`, no name | Title "[Jeff's wording: stop capacity_spent]", row "[Jeff's wording: cause directive]", row "[Jeff's wording: purpose read]". No Echo row. |
| Synthetic named Echo, `echo`, `steadied` | The same title, rows "cause echo", "purpose read", and "Benjamin Danquah: [Jeff's wording: echo reason steadied]" |

So the text is generic by design until Jeff writes it. Even with his wording, the cause `directive` gives no Echo. The player will see the same line for most Advances.

### C4. Why a calm party rarely names an Echo

| Rule | Source | Effect in these runs |
|---|---|---|
| An Echo is named only if removing that Echo changes the first plan (path, steps or depth that cuts the walk, or the stop). | `design.md` section 4 rules 4 and 8 | Leans are small. Morale gives at most +0.1 x lean. Dials move by 0.01 to 0.05. The path, stop and cutting depth stay the same, so removing one Echo changes nothing. |
| An Echo needs a non-zero lean to be a candidate. | `design.md` section 4 rule 5 | Jeff's three Echoes have no Calling. Only morale and the movement-style identity lean. |
| No name when the model plan differs from the real walk. | D-55 A1, D-56 | The drop rate on boards with a hostile near the start is 13 percent of proposed names. It does not explain 0 of 606. |
| The cause is `directive` when the Directive alone decided. | `design.md` section 4 rule 7 | 286 of 606 Advances. |
| Readiness (fear, morale) only changes the cause to `party` | observed | 123 Advances (fear 60 and fear 45 runs). |

---

## D. Findings 2 and 4: layout against the approved mockup

### D1. Method

The approved look is `mockups/v3/` "New mockup", style 3, at 1280x720. Mockup positions come from the code of `index.html` (lines 63 to 66, 423 to 468, 518 to 524) and from `preview-new-map2-style3.png` and `preview-new-map2-why.png`. Build positions come from `Control.get_global_rect()` in the windowed run (logical px). Overlay pictures (cyan = mockup boxes, magenta = mockup glyph or chip and why card) are `shots3/overlay_chip_why_seek.png`, `shots3/overlay_named_why_seek.png` and the same names in `shots5/`.

The mockup why card for style 3 uses one placement rule: 16 px from the token hit area, card top = token y - 30. The approved screenshot is style 1 (ring on token). Its card is at x 219 to 578, y 305 to 467 (token centre 640, 357).

### D2. Table: item, mockup, build, distance

Party of 3, 1280x720. Token centre: mockup (640,357), build (640,360).

| Item | Mockup (px) | Build (px) | Distance |
|---|---|---|---|
| Glyph on the named Echo | 40x40 at x 642 to 682, y 632 to 672. Centre on the portrait corner: offset (+22, -22) from the portrait centre (640,674). | 28x28 at x 708 to 736, y 624 to 652, at the right end of the card. The portrait is x 470 to 510 (card 1). | Portrait to glyph: mockup about 31 px centre to centre. Build 198 px edge to edge, 232 px centre to centre. About **200 px** further. |
| Party chip (no Echo named) | Blue round chip 56x56, centre (408,674), x 380 to 436. "Left of the cards" (README). First portrait left edge 494. | Cream pill 56x88 at x 1208 to 1264, y 616 to 704, the right end of the frame. Glyph 40x28 inside. Nearest card (card 2) right edge 1040. | Edge gap to nearest portrait or card: mockup 58 px. Build 168 px. The chip is on the opposite side of the cards (right end, not left). Chip centre to first portrait centre: mockup 112 px; build 1236 - 194 = 1042 px. |
| Chip, party of 5 | (not drawn) | Same slot. Cards x 16 to 1480. The scroll area ends at x 1192. Card 3 ends at 1184 (24 px to the chip). Card 4 starts at 1200 under the clip. | The chip sits at the cards' scroll edge. Card 4 is hidden until scrolled. |
| Why card | 360 wide. About x 219 to 578 (shot) or 239 to 599 (rule), y 305 to 467. Next to the token. Gap card to token hit area: 16 px (by rule). Card top 30 px above token centre. | `StageWhyCard` fixed at offset (16, 96). x 16 to 392, y 96 to 241 (chip stop) or 290 (named). HUD turn panel is above it (y 16 to 72). | Card right edge to token centre: mockup 62 to 41 px (shot / rule), build 248 px. Card top to token centre: mockup 30 px above, build 264 px above. Centre of card to token: mockup about 244 px, build about 476 px. About **230 px** further. |
| Advance button | Tan `rgba(200,169,110,.9)`, radius 8, 180x48 at x 550 to 730, y 552 to 600. Centred at 640. Label "Advance", 16 px. | Wide gold `ButtonPrimary`, 1096x56 at x 16 to 1112, y 548 to 604. "Return Home" 140 wide at x 1124 to 1264. The label showed blank in this run (known defect, D-41). | Width: 180 vs 1096 (916 px more). Centre x: 640 vs 564 (76 px left). |
| Step icons | Row at y 510 to 542. Diamonds 20x20 in a row, 5 diamonds, gap 10, centred. Red cross on lost. "Steps" label left. | `StepProgressBar` at x 559 to 767, y 504 to 536. Diamonds 28x18, gap 8. Red cross on lost. "Steps" label. | Row y: 6 px higher. Same centre. The F1 work did this part. |
| Echo band | Dark green `#1A271E` band, full width, y 632 to 720 (88 high), gold 2 px top line. Round portraits 52 px, centres at x 520, 640, 760, y 674, name 11 px below. | No band. Frame y 616 to 704 on the dark ground. Gold-edged cream pill cards 280x58 at x 168, 464, 760 (3 Echoes). Square portrait 40x46. Name, status text inside. | Top edge: 16 px higher. Card pitch 296 vs 120 px. Card width 280 vs 52. Shape differs (pill vs round). |
| Token, HUD, badge | Parchment HUD, dark badge at the top right. | Same (these are in the live game). | none |

For the picture on the glyph, the overlay shows the cyan and magenta boxes against the build.

### D3. Decisions and design text

| Source | Text | Build |
|---|---|---|
| D-41 | Marker style 3 approved. A glyph "sits on the named Echo's card". Jeff prefers the OLD mockup's Advance button, step icons (big diamonds, red cross) and Echo band. Improvements 5 and 10 are not used. | Glyph: yes, but at the card's right end, not on the portrait. Step icons: yes. **Advance button: not done. Echo band: not done.** |
| D-42 | "A small chip beside the Echo cards ... `ui-ux-designer` places it so it stays inside the safe area and does not cover the Echo cards." | Chip exists. Placed at the far right end, 168 px from the nearest card (3 Echoes). "Beside" is met only in a loose sense. |
| D-59 | "Reserve a fixed slot beside the cards ... always inside the safe area, so the cards never shift. The cards scroll in the remaining width." | Done as written: `ChipSlot` 56 px at the right end. It put the chip far from the cards when the party is small. |
| `design.md` 8.1 item 3 | "The party chip sits beside the Echo cards, inside the safe area ... must not shrink a card below its minimum width." | Same as D-42. |
| `design.md` 8.1 item 4 | "The why card opens clear of the Echo bar and the Advance button, inside the board area." | Met in the literal text: card y 96 to 290, Advance at y 548. The text does not say "next to the token". |
| `design.md` 8.1 trigger paragraph and v3 README | The card opens from the glyph, the Echo card, the chip or the token. The mockup places it next to the token. | The card is fixed at the top left, 230 px further from the token. |
| `design.md` 8.1 rule 5 | "The old mockup look stays: the old Advance button, the big step diamonds, a red cross on each lost step ... The live layout is otherwise unchanged." | The same paragraph says "old Advance button" and "live layout otherwise unchanged". Row 12a (line 443) says Advance, step diamonds and Echo band. The F1 build followed only the step icons. |

### D4. What the build did not follow from the approved mockup

1. **Advance button.** The mockup New mode uses the OLD narrow tan button (180x48). The build keeps the live wide gold bar (1096x56). D-41 and `design.md` 8.1 rule 5 name this.
2. **Echo band.** The mockup uses a dark green band with round portraits. The build keeps the live gold-edged pill cards. D-41 and `design.md` line 443 name this.
3. **Glyph place on the card.** The mockup puts the glyph on the portrait corner. The build puts it at the card's right end, 198 px from the portrait.
4. **Chip place and look.** The mockup puts a blue round chip 58 px left of the first portrait. The build puts a cream pill at the far right of the frame.
5. **Why card place.** The mockup puts it next to the token. The build fixes it at the top left under the HUD.
6. **Not a gap.** Step icons, the red crosses, the HUD, the badge and the token match.

The F1 brief named only the step icons. Items 1 and 2 were named in D-41 and in `design.md` but were not in the F1 brief. I did not read the F1 brief file. I read the commit message list and `handover.md` line 46 only. This is an inference.

---

## E. Summary

| # | Finding | Cause | Evidence |
|---|---|---|---|
| 1 | Advance lock about 1 s, every second click ignored | Paths 3 and 4 in A2 (button off until `ready_at`), plus the compute (0.22 to 0.28 s). The beat plan itself follows D-57. D-57 counted from the snapshot, not from the press. | A1, A3: 975 ms calm, 1200 ms shaken, old build 240 ms. 22 of 49 clicks ignored (old: 0) |
| 2 | Reason icon far from the Echo cards, not the mockup | Glyph at the card's right end. Chip at the right end of the frame. The Advance bar and the Echo band are not the approved look. | D2: about 200 px (glyph), 168 px vs 58 px (chip) |
| 3 | Step icons out of sync with the steps walked | The row shows capacity (6). The walk shows commitment (5, or 6 with morale of 83 or more). `commitment_depth` is not in the snapshot. D-40 item 8 and D-50 together leave this open. | B1 to B5 |
| 4 | Reason panel far from button and icon | `StageWhyCard` fixed at (16, 96). Mockup puts it next to the token. | D2: about 230 px |
| 5 | Reason is generic and names no Echo | The text file has placeholders only. The cause is `directive` in 47 percent of Advances. No Advance named an Echo in 606. | C1 to C4 |

## OPEN — questions and assumptions

ASSUMED: The mockup why card for style 3 sits where the style 1 screenshot and the code rule put it (16 px from the token hit area, top 30 px above token centre). | WHY: No approved style-3 screenshot shows an open card. `index.html` uses one placement rule for all styles. | WRONG IF: Jeff approved a different place for style 3 that the page does not show.

ASSUMED: The "named Echo" pictures are valid for layout. They use a real snapshot with the Echo id, the name and cause `echo` filled in. | WHY: No real Advance named an Echo in 606 tries. | WRONG IF: A real named stop uses a different snapshot shape (for example other card text). The glyph place should be the same.

ASSUMED: "Directive (chip) stop" in Part A means every calm stop with no named Echo. | WHY: All 606 Advances were chip stops (no Echo named). Their beat plan is `ready_at` 0.35 s. | WRONG IF: Jeff means a stop with another kind of beat plan.

ASSUMED: The timing run on the machine (M2, windowed, 1280x720) matches Jeff's play. | WHY: Jeff's log (one Advance about every 1 s) matches 0.95 to 0.98 s. | WRONG IF: His machine has a different compute time. A slower machine makes the lock longer, because the compute is added.

BLOCKED: Did the party walk 6 steps or 5 in Jeff's play (Reading A or B in B5)? | CHECKED: his save copy (morale 50, 72, 46: dial 0.862, depth 5); `design.md`, D-40, D-43, D-50, `numbers.md`. I did not read his Godot log (the brief allowed the save copy only). | NEED: The `steps_taken` value in his terminal log for one Seek Advance, or the party morale at that time.

BLOCKED: What should the step row show for commitment (6 diamonds for capacity while the walk uses 5)? | CHECKED: D-40 item 8, D-43, D-50, `design.md` 5 and 8.1. No text decides this. | NEED: Jeff's decision (the row shows capacity, the walk depth, or both). This is a design choice. It is not mine.

BLOCKED: Is a lock of about 1 s (1.2 s shaken, longer on slow devices) acceptable? D-57 O3 left a phone measurement open. | CHECKED: `timings-proposal.md` lines 61 to 107, D-57. | NEED: Jeff's decision on the input-ready point, and whether the compute time counts inside it.

BLOCKED: Does Jeff want items 1 and 2 of D4 (old Advance button, old Echo band) built now? | CHECKED: D-41, `design.md` 8.1 rule 5 and line 443, `handover.md`. | NEED: Jeff's yes, then a brief to `ui-ux-designer` that names them.

Skipped (Ponytail, no code was written for the repo): no repo edit, no test run, no 1920x1080 pictures (not requested), no read of Jeff's Godot log, no run on a second machine.
