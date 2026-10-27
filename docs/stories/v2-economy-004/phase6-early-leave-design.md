# V2-ECONOMY-004 Phase 6: early leave settles by a roll (design)

Author: sr-game-designer. Date: 2026-10-26. Status: OPTIONS for Jeff. Nothing here is decided.
Basis: D-04, D-65, D-72, D-79, D-102, D-103, D-104, D-105 in `decisions.md`.
Revision 2: D-105 replaced the "advance" model. What the roll does not carry is LOST.
Every number is a PROPOSED DEFAULT for `mid-game-designer`, except the odds 50/30/20 (Jeff, D-104).
All player text is a PROPOSAL (project voice). Jeff approves each line.
Player rule (Jeff): the player never sees a percentage or odds.

## 0. Facts read from the code (not from comments)

| Fact | Where |
|---|---|
| `carry_plan` pays 12% (`partial_intel_reward_factor`) of the completed-objective amount, times `retention_mul` (Ase only), minus `carried_ase`. | `StageSettlementService.gd:255-284` |
| `retention_mul` is 1.5 for Scout and 1.0 for Seek. | `balance.json:33-34, 69-70` |
| Return home draws the escape roll from `stage.escape.<stage_id>.<turn_count>`. The carry runs only after the escape succeeds. | `VentureController.gd:324-370` |
| The retreat success roll uses `encounter.retreat.<encounter_id>.<t>`. It runs before round 1, so no fight state exists. The retreat passes `retention_mul` 1.0. | `FlowRuntime.gd:1158-1235` |
| Each objective is a dict on the stage record with `type` and `completed`. `RewardCalc.base_reward` sums the weights of `completed` objectives. `objective_counts` counts `completed` objectives. | `RewardCalc.gd:23-76` |
| The stage payout subtracts `advance = min(carried_ase, gross)` and writes a negative `carried_advance` row. | `EconomyService.gd:216-251` |
| An uncleared stage pays nothing at settle. | `StageSettlementService.settle` |
| `engage_situation` marks a situation `revealed` and does not resolve it. `stage.ignore_situation` marks it `passed`. A passed objective returns at Tier 4. | `SituationEngagementService.gd`, `VentureController.gd` |
| A precedent for a persisted one-time roll exists: ANSWERS recruit roll, "computed once and persisted (no re-roll on Continue)". | `ANSWERS.md` #28 |
| Files that read or write `carried_ase`/`carried_ekwan`: EconomyService, StageSettlementService, ActiveStageService, VentureResolveSnapshotBuilder. | grep of `core/` |

## 1. Settlement model on the stage record (D-105)

### Rule

When the party leaves early (return home or retreat), core settles the objectives that are **completed and not yet settled** in one batch:
1. `gathered_new_ase = sum of objective_weights` of those objectives, times realm scale and replay factor.
2. `gathered_new_ekwan = sum of objective_ekwan` of the same objectives, times the same factors.
3. One roll gives a share: none (0), some (50%), everything (100%).
4. Core pays `round(gathered_new x share)` for Ase and for Ekwan now. It rounds once per currency, on the sum.
5. Core marks each of those objectives `settled = true`.
6. A settled objective pays nothing more at the stage end. It stays "overcome" in the count shown to the player.
7. Objectives completed after the leave are not settled. They pay normally at the stage end.
8. The stipend, the echo-home row, the pace and rank, and the Thread rule do not change.

### Options for where the state lives

| Option | Storage | Notes |
|---|---|---|
| A (pick) | Per-objective `settled` (bool) and `settled_share` (0, 50 or 100, kept for tests and the ledger, never printed). Stage-level `settled_ase` and `settled_ekwan` (running totals paid at leaves, record only). Stage-level `settle_count`. | The mark is the re-roll stamp. One data model. `carried_ase`/`carried_ekwan` are removed. |
| B | Keep the names `carried_ase`/`carried_ekwan` with the new meaning "paid at leaves" | No rename. But the old meaning was "advance to subtract". A stale name misleads future readers. |
| C | Stage-level stamp `settled_base` (a number) instead of per-objective marks | Cannot say which objective was settled. A later objective with a lower weight could be mis-counted. Reject. |

The game is not live and saves are disposable (project memory), so a clean break (A) costs nothing in migration.

### What replaces what

| Old | New |
|---|---|
| `carry_plan` (12% x retention, minus carried) | `settle_plan`: selects `completed and not settled`, uses `k = realm_scale x replay_factor`, no 12% factor, no subtraction. Pure. Returns `gathered_new_ase`, `gathered_new_ekwan`, the objective indexes, `nothing_new`. |
| `carry_home` (pays and adds to `carried_*`) | `settle_leave`: calls `settle_plan`, draws the roll, pays, marks objectives, writes the running totals, requests the save. Both payers call only this. |
| `retention_mul` (amount) | `carry_odds_for(directive)`: the weight shift of section 2. |
| `partial_intel_reward_factor` | Removed (dead). |
| The intel gate "at least one revealed situation" | Dropped. A completed objective already implies a revealed situation. Check in the build. |
| `stage_payout_rows(... carried_ase, carried_ekwan)` and the negative `carried_advance` row | The base row counts `completed and not settled`. The carried parameters and the negative row are removed. A memo row replaces it (section 5). |
| `carry_*_preview` | `gathered_new`, with no share. Core never exposes the odds. |

The preview is pure and draws no roll. The payer draws one roll only when `gathered_new_ase > 0` or `gathered_new_ekwan > 0`.

### The roll (stream, timing, re-roll)

Stream, option A (pick): `CampaignSeed.get_rng_from(realm_seed, "stage.settle.<stage_id>.<run_count>.<settle_count>")`, one `randi_range(0, 99)` on the cumulative weights from `data.rewards.carry_odds` (`[{share, weight}]`; shape PROPOSED; weights 50/30/20 are Jeff's). A missing key logs an error and settles 0.
Option B: key by the number of objectives settled so far. Stable, but two leaves with equal counts repeat. Option C: reuse the retreat stream. It couples the settlement to the retreat success roll and does not work for return home. Reject C.

Timing: the draw happens after the escape or the retreat succeeds, in the same handler step that pays and marks. A failed escape or failed retreat draws nothing. `settle_count` is increased when a roll is drawn.

| Attempt | Why it fails |
|---|---|
| Cancel the panel | No draw happens before "Confirm". |
| Save, then reload | The key uses saved state only (`stage_id`, `run_count`, `settle_count`). After the draw the marks and totals are in the save. |
| Retry on the same turn | A failed escape repeats for the same `turn_count` (existing rule). A successful escape ends the attempt. |
| Leave again at once | Every completed objective is already `settled`. `nothing_new`: no draw, no pay. |
| Leave, finish one more objective, leave | Only the new objective is rolled. The old ones stay settled, whatever their result. |

No existing stream gets a new draw. The new stream is path-derived and append-only (Lesson 5).

### Replays

- The roll key has `run_count`, so a replay does not repeat the first run's results.
- The value uses the live `replay_factor` at the leave, so a replay settles at the lower value (x0.35).
- Marks live on the objective dicts of the stage record. If a replay rebuilds the stage objectives, the marks reset with them. If a replay keeps the same objective dicts, old marks would hide payouts. This is BLOCKED (see OPEN). The build must test it.

## 2. Scout `intel_retention_bonus` and directives

A 1.5x multiplier on a 100% share would pay 150%. It cannot stay a multiplier on the amount.

| Option | Rule | Mean share (Seek / Scout) |
|---|---|---|
| A (pick) | Scout multiplies the weights of the non-zero outcomes by 1.5, then renormalises: 50/30/20 becomes 40/36/24. | 35% / 42% |
| B | Keep the amount multiplier, cap the share at 100%: Scout 0 / 75 / 100 with odds 50/30/20. | 35% / 42.5% |
| C | Drop the bonus. Scout keeps the escape bonus only. | 35% / 35% |

Pick A, then B, then C. The retreat keeps 1.0 (as today). Ekwan uses the same roll, so Scout also raises the Ekwan odds. Seek uses the base odds.

## 3. Confirmation panel (no percent, no odds)

- **Odds: do not show**, not in numbers and not in words like "half the time". That is a percentage in other words.
- **A range of amounts: may show.** An amount is not a percentage. The panel shows the gathered figure and says that all, some or none can come home.
- Under D-105 the panel must also say that what does not come home is gone. This is the part the player needs to decide.

| Option | Shows | Verdict |
|---|---|---|
| A (pick) | The gathered figure (from core), one line "all, some or none", one line "what does not come home is gone", one line that later objectives still pay. | Honest. Hides only the odds. |
| B | "Up to 74 Ase" only | Hides that the loss can be total. Reject. |
| C | Three amount rows (0 / 37 / 74) with no odds | Exact. The order lets the player guess the odds. Second choice. |

Preview block (PROPOSED shape): `{ gathered_new_ase, gathered_new_ekwan, settled_before_ase, nothing_new }`. No odds field. Core does all arithmetic.

PROPOSAL copy:
- Title: "Leave now?"
- Amount: "You have 74 Ase gathered here."
- Roll line: "You might take all of it home, some of it, or none."
- Loss line: "What does not come home is gone."
- Later line: "Anything you finish when you come back still pays."
- Existing line (Jeff, unchanged): "Escaping might be more difficult than expected. It might not be possible."
- Nothing new: "You already settled what you had. Nothing new to take."
- Retreat adds: "Pulling back costs 10 Ase. You go back to the stage, not home."
- Retreat when short: keep the existing denial reason.
- The void D-104 line "Whatever you leave behind is still yours when the stage is done." must not be used.

## 4. Resolve card (return home) and retreat result

Rule: no percent, no odds, no fraction word on the card. Ase and Ekwan amounts show as amounts.
ASSUMED: "some" is the 50% outcome. The card never says "half".
Label on every row: "Settled when you left" (see section 5; same words on the stage-end memo row). Cause keys (for `mechanics-developer`): `settle_none`, `settle_some`, `settle_all`, `settle_nothing_new`. `nothing_overcome_yet` stays.

| Outcome | Ledger row | PROPOSAL cause text |
|---|---|---|
| Everything | "Settled when you left +74 Ase" (Ekwan row if above 0) | "They got everything out." |
| Some | "Settled when you left +37 Ase" | "They got some of it out. The rest is gone." |
| Nothing | "Settled when you left +0 Ase" (a row, never a missing row) | "They got nothing out. It is gone." |
| Nothing new | one row, delta 0 | "Already settled. Nothing new to take." |
| Nothing overcome | existing row | existing text (copy pass later, D-84) |

Card rules:
- No row text contains "%", "half", "odds", "chance" or a fraction. `params` may hold the share for tests. The UI must not print it.
- The "nothing" case always shows a +0 row so it does not look like a bug.
- Return home: the card ends at the Sanctum. Retreat: the card ends with a button "Back to the stage".
- Retreat result display: (A, pick) a short card with the same ledger and a heading "Pulled back"; (B) an overlay on the stage map. `ui-ux-designer` decides layout after Jeff picks.
- Test rule: card tests assert that no row text matches a percent sign or the words "half", "odds", "chance".

## 5. Retreat back to the stage: state kept

The retreat happens before round 1. No fight state exists.

| State | Rule (pick first) |
|---|---|
| Stage record, completed objectives, revealed intel | Kept. |
| Engaged situation | A (pick): mark it `passed`. The party meets it again at Tier 4. B: leave it open (instant re-entry; the 10 Ase buys one step). |
| Encounter context | Cleared (as today). A new fight is built on re-engage. |
| Party HP | Unchanged. |
| Emotion | Keep the "withdrawal" modifiers and the vow release check. The Sanctum emotion tick stays on return home only. |
| Turn counter | A (pick): unchanged, a retreat is not a turn. B: +1 turn. |
| Escape-roll key | Unchanged. |
| Double count of settlement | Impossible: the `settled` mark is per objective. |

### Does a retreat settle at all? (D-105 raises this)

Under D-105 a settlement now **loses** value. A return home ends the visit. A retreat does not. A player who pulls back from one fight and then keeps playing would still lose, on average, 65% of the gathered amount. The player also pays 10 Ase.

| Option | Rule | Effect |
|---|---|---|
| A | Retreat settles like return home (D-104 item 2 as written). | Retreat costs 10 Ase plus an average loss of 65% of the gathered amount. The in-fight retreat becomes the worst button in the game. Players will fight on with hurt Echoes, against the pillar. |
| B (pick) | Retreat to the stage does not settle. Only a return home settles. The retreat keeps its 10 Ase cost and the denial rule. | The retreat is a "not this fight, not yet" move. The loss comes only with an actual exit. This changes D-104 item 2, so Jeff must confirm. |
| C | Retreat settles but at better odds | Needs new odds. Adds a second table. |

The 10 Ase price: keep it. With B the retreat buys a pause and costs only 10. With A the price is minor next to the loss.

## 6. Defeat, full clear, and a worked example

- **Defeat after a leave:** `settle()` runs only on a cleared stage. A defeat pays nothing at the stage end (unchanged). The amounts already paid at leaves stay. Objectives completed after the leave and not paid are lost with the defeat (unchanged rule).
- **Full clear after a leave:** the stage end pays the base row for `completed and not settled` objectives, the replay row, the stipend, and the rank rows. A memo row shows what was settled earlier.
- **Never-return:** the player keeps only what the roll paid. The same as defeat.

Worked example. Stage with 3 objectives: combat 20, recover 24, shrine 30 (`objective_weights`). Realm scale 1.0, first run, Seek odds, stipend 10 (all home). G = 74. Clear with no leave = 74 + 10 = 84.

| Leave when | Roll | Paid at the leave | Stage end after return and finish | Total | Loss against 84 |
|---|---|---|---|---|---|
| 1 done (combat, 20) | none | 0 | 24 + 30 + 10 = 64 | 64 | 20 |
| 1 done | some | 10 | 64 | 74 | 10 |
| 1 done | everything | 20 | 64 | 84 | 0 |
| 2 done (combat + recover, 44) | none | 0 | 30 + 10 = 40 | 40 | 44 |
| 2 done | some | 22 | 40 | 62 | 22 |
| 2 done | everything | 44 | 40 | 84 | 0 |

Expected total, Seek (50/30/20): leave after 1 done = 71.0 (loss 13.0). Leave after 2 done = 55.4 (loss 28.6).
Expected total, Scout (40/36/24): after 1 done = 72.4 (loss 11.6). After 2 done = 58.5 (loss 25.5).
Leave for good (or defeat after the leave), Seek: 7.0 / 15.4 / 25.9 Ase for 1 / 2 / 3 objectives done. Scout: 8.4 / 18.5 / 31.1.
Two leaves (after combat, then after recover) have the same expected value as one leave after both. Only the variance changes.

## 7. Balance check (real loss)

Numbers from `balance.json`: weights 20/24/30; echo price 60; retreat price 10; stipend rate 2, cap 10; replay factor 0.35.

**Expected loss.** A settled objective pays 35% (Scout 42%) of its value, and nothing else. The expected loss is 65% (Scout 58%) of every objective settled at a leave. Examples: 13.0 Ase after 1 done, 28.6 after 2 done. 28.6 Ase is close to half the price of an Echo (60).

**Is early leave still worse than finishing?** Yes, more strongly than before. Leave-and-return now always loses value on average. Leave-for-good pays 35% of the gathered part and gives up the stipend, the rank and the Thread.

**Exploits left.**

| Exploit | Result |
|---|---|
| Leave, return, repeat to re-roll | Closed. Each objective rolls once. `nothing_new` draws nothing. |
| Retreat spam | Closed. Nothing to settle after the first retreat. Each retreat still costs 10. |
| Bank before a hard fight | Now unattractive. Banking costs 65% of the banked amount in expectation. It pays only if the chance to lose the fight is above about 65%. D-72's old hedge is gone. |
| Farm easy objectives and leave | 35% of a small figure, x0.35 on replays. A bad rate. |
| Gamble for cash (need 60 for an Echo, have 44 gathered, 20% chance of 44) | Not an exploit. It is a gamble the player pays for. Also note that 44 alone does not buy an Echo. |
| Split objectives over several leaves to lower the variance | No gain in expectation. Not an exploit. |
| Settlement larger than gathered | Impossible. Share is at most 100%. |
| Leave with nothing completed | No roll, no loss. The free return home keeps its use as a safe exit (GDD 20.10). |

**Is the loss too harsh next to the 35% mean share?** Judgment: yes, for a deliberate return home out of fear, it is on the edge. Reasons:
1. D-04 wants Ase to feel hard to get. A loss of 65% of earned Ase on every early leave is hard.
2. The pillar rewards keeping Echoes alive. The safe move (come home) now carries the largest average cost in the game. A player in a bad run will be tempted to push on instead of leaving, and push-on is how Echoes die.
3. GDD 20.10 calls the failed run useful. Intel is still returned. Ase is not named there. So the GDD is not broken, but the feel is in tension.
4. A 0% result is half of all leaves. Half of all leaves show a "took nothing" card.

Options for Jeff (ranked):

| Option | Rule | Cost |
|---|---|---|
| A (pick) | Keep D-105 as decided for return home. Do not settle on a retreat (section 5, B). Re-check after a play test. | Changes D-104 item 2. |
| B | Keep D-105 and D-104 as written. Move the odds toward a higher mean after play (the odds are config, Jeff's numbers). Candidate range for a play test: mean share 50% to 65%. | Config only. |
| C | Keep everything as decided. | Harshest. Risk 2 above. |

Pick A first because it removes the unfair case (loss without leaving). The odds stay Jeff's call.

## 8. Stage-end ledger

Rows after a leave (stage end, cleared):

| Row | Value | Note |
|---|---|---|
| Base objectives | sum of `completed and not settled` objectives x scale | `params.overcome`/`total` still count all completed objectives, so the "N of M" line stays true. |
| Redo penalty | as today, on the unsettled base | |
| Echoes home | as today | |
| Settled when you left | delta 0, memo | `cause: settled_on_leave`, `params: { settled_ase, settled_ekwan }`. Shown only when above 0. |

The negative `carried_advance` row is removed. A zero-delta memo row has a precedent (`nothing_overcome_yet`).
PROPOSAL memo copy: "Settled when you left: 37 Ase." with cause "You settled these on the way out. They pay nothing more."
Options: (A, pick) memo row; (B) no row, which hides why the base row is smaller than the objectives count. B confuses the player.
Ekwan follows the same rule. The existing `carried_advance` label text in the UI tests must change.

## 9. GDD contradictions

| GDD item | Result |
|---|---|
| 20.8 "unresolved stage keeps its locked instance; reruns preserve what the player learned" | No conflict. Intel and objectives keep their state. Only the Ase of settled objectives is gone. |
| 20.10 "retreat from the stage map with intel", "no-battle return with useful information" | No conflict on intel. The Ase side is in tension (section 7). |
| 20.10 "combat retreat can remain unavailable or much more limited early" | D-104 makes the retreat a step back to the stage. Suggest Jeff adds one line to 20.10. I did not edit the GDD. |
| Death and withdrawal: "map-level withdrawal remains an early safety valve" | Holds, but with a cost. See section 7. |
| Pillar: Echoes have fear and interiority | Holds if the withdrawal emotion modifiers stay on the retreat. |
| D-25 (no mid-stage preview) and D-65 (running tally) | The panel shows a gathered figure at the moment of leaving. D-102 already allowed a preview before the action. Jeff confirms. |

## 10. Recorded values and tests that move (list only; nothing was run)

This list is a prediction from grep. It is not measured.

Config and code:
- `data/balance.json`: add `data.rewards.carry_odds`; remove `partial_intel_reward_factor`; the balance key tests.
- Stale comments to update: `StageSettlementService.carry_plan`, `VentureController.handle_return_home`, `VentureResolveSnapshotBuilder` ("pending Ase already added to carried_ase").

Tests (by file):
- `tests/EconomyCharacterizationTests.gd`: the fixture writing `carried_ase`/`carried_ekwan` (about lines 618-640); every `stage_payout_rows` and `settle_stage_complete` call that passes carried values; the stage payout totals after a leave.
- `tests/ResolvePayoutUITests.gd`: the `carried_advance` row and its tooltip/labels (about lines 141, 278, 299); `carried_ekwan_line_on_scout_return`; the return-home confirmation tests (about lines 810-925); the retreat preview payload `carry_retreat_preview` (about lines 980-984); the payload match test (about line 1190).
- `tests/VentureCharacterizationTests.gd`: return home and retreat flows, Ase balances after a leave, `pending_scout_return_*`.
- `tests/RetreatTests.gd`: a successful retreat now returns to the stage, not Resolve or the Sanctum.
- `tests/PendingResultTests.gd`: `pending_scout_return_*` fields in the saved result.
- `tests/FlowSnapshotFingerprintTests.gd` and the fingerprint seek/combat suites: the stage-explore snapshot (`carry_home_preview` shape) and the scout-return snapshot. D-77 already shows 5 fingerprint modes drift after payout changes; expect the same here and re-record with attribution.
- New tests needed: roll mapping and weights; Scout shift; no re-roll after reload; `nothing_new`; settled objective pays 0 at the stage end; defeat keeps the settled pay; replay marks; retreat to the stage marks the situation `passed`; card text has no percent word.
- Determinism suites: only the new stream is added, so existing draws should hold. Confirm by the long run.

## Recommended build order (for Jeff to scope; not scope here)

1. Config: `carry_odds`, remove the dead key.
2. Core: per-objective `settled`, `settle_plan`/`settle_leave`, roll, Scout shift, payout rows, retreat to the stage.
3. Snapshots: preview block, cause keys, memo row.
4. UI: panel and card.
5. One ux-copy pass (D-84).
6. Long run and attribution (RUN REQUEST to the main chat).

## OPEN — questions and assumptions

ASSUMED: "Some" in Jeff's rule is the 50% outcome. The card says "some", never "half". | WHY: Jeff named three outcomes. | WRONG IF: Jeff means another share.
ASSUMED: The no-percent rule also bars odds in words on the confirmation panel. | WHY: the coordinator said the percentage is not for the player. | WRONG IF: Jeff allows odds in words on the panel.
ASSUMED: One roll settles the whole batch of newly completed objectives (not one roll per objective). | WHY: Jeff's three outcomes read as one result on one card. | WRONG IF: Jeff wants a roll per objective (a mixed result then needs a different card).
ASSUMED: D-105 "paid now" covers Ekwan too, with the same share. | WHY: D-72 rule 3. | WRONG IF: Jeff wants Ekwan paid in full or rolled apart.
ASSUMED: The intel gate of `carry_plan` can go, because a completed objective implies a revealed situation. | WHY: engagement sets `revealed` before resolution. | WRONG IF: a completed objective can exist with no revealed situation.
ASSUMED: The per-objective `settled` flag and the rename of `carried_*` to `settled_*` (a clean break) are acceptable. | WHY: saves are disposable (project memory). | WRONG IF: Jeff wants old saves to load a mid-stage carry.
ASSUMED: Scout raises the Ekwan odds through the shared roll, and the retreat keeps `retention_mul` 1.0. | WHY: one roll; the retreat is 1.0 today. | WRONG IF: Jeff wants otherwise.
ASSUMED: Re-engaging a retreated situation rebuilds the same seeded fight. | WHY: encounter setup is seeded by the situation. I did not read `EncounterSetupService`. | WRONG IF: a new fight is generated each time (an exploit).
ASSUMED: The retreat path has no heal and no rest. | WHY: none found in the code I read. | WRONG IF: a heal or morale recovery happens on return to the stage map.
BLOCKED: Does a replay rebuild the stage objective dicts (so `settled` marks reset), or reuse them? | CHECKED: `RealmModel.gd` comment says `run_count` drives seed derivation; I did not trace stage rebuild. | NEED: `mechanics-developer`. If the dicts persist, a replay would hide payouts.
BLOCKED: Should a retreat to the stage settle at all (section 5)? This reopens D-104 item 2. | CHECKED: D-104, D-105. | NEED: Jeff's pick. I recommend no settlement on a retreat.
BLOCKED: Is the average loss of 65% on a return home acceptable (section 7)? | CHECKED: arithmetic from `balance.json`. | NEED: Jeff, ideally after a play test. Odds are config.
BLOCKED: Does the retreat success roll (`encounter.retreat.<id>.<t>`) repeat after a save and reload? | CHECKED: `FlowRuntime.gd:1182-1187`; the key uses tick `t`. I did not trace whether `t` is saved. | NEED: `mechanics-developer`. If `t` changes after a reload, the retreat is re-rollable (an existing issue).
BLOCKED: Retreat result display: Resolve-style card with "Back to the stage" (pick) or a map overlay. | CHECKED: D-104 says only "returns to the stage map". | NEED: Jeff, then `ui-ux-designer`.
BLOCKED: Does a retreat cost a turn? | CHECKED: `turn_count` increments only in `advance_turn`. | NEED: Jeff. I recommend no.
BLOCKED: Does the Scout directive card text promise a retention number? | CHECKED: `balance.json:20-40` shows keys, no retention line. | NEED: `mid-game-designer`, before option A or C of section 2.
BLOCKED: Does the gathered figure on the panel reverse D-25? | CHECKED: D-102 allowed `carry_home_preview` before the action. | NEED: Jeff to confirm.
BLOCKED: Should a forced withdrawal (morale collapse, GDD 20.10) settle by the roll? | CHECKED: `build_scout_return_snapshot` treats `forced_retreat` as paying nothing by design. | NEED: Jeff. Not covered here; the forced path stays as it is.
