# V2-INFRA-010 — Path-search cost: Stage advance and Combat step

Status: Ready. Not picked up yet (Jeff, 2026-10-06). Spec State: Mostly Locked. Wave: Foundation. Order 262.9. Priority P1 (confirmed).

## Goal

Make one path search cheaper, so the game does not stall on a Stage advance or a Combat step.
The player must see no stutter when Combat runs on Fast or when Stage advances come in quick succession.
No behaviour change. Every path, every cost and every recorded value stays byte-identical.

## Why

Jeff reported a stutter in two places: a camera hitch and a second where nothing is clickable.
It happens on random steps in Stage (fast successive advances) and in Combat (many actions in a row, or camera moves).
It happens in a windowed run, with or without the editor.

A timing probe run on 2026-10-06 found the cause. The simulation step blocks the main thread.
Every frame spike matched the `dispatch` time of the action just before it.

| Cost | Measured | Verdict |
|---|---|---|
| Board repaint (Combat and Stage) | under 8 ms | Not the cause |
| Screen render of the snapshot | 1.5 to 3.5 ms | Not the cause |
| Log flush to console | 0.1 ms | Not the cause |
| Camera follow | not measurable | Not the cause |
| **Stage advance, `reachable_cost_region`** | **28 ms per call, 14 calls per advance = 390 ms of 435 ms** | **Cause** |
| **Combat step, `prepare_movement`** | **46 to 164 ms of a 55 to 173 ms step** | **Cause** |
| Combat step, `shortest_path` calls | 5 to 66 calls per step, 2 to 3 ms each | Cause (part of `prepare_movement`) |
| Save flush | 40 to 46 ms on most actions | Real cost, not in this story (see D-01) |

Test machine: Apple M2, Godot 4.6.1, GL Compatibility, run with `godot --path` (a debug run).
The raw excerpts are in `evidence-2026-10-06.md`. Re-confirm them when the story is picked up (D-05).
At 60 frames per second, a 120 ms Combat step drops 7 frames. A 470 ms Stage advance drops about 28 frames.

### Root cause

`MovementPathService._take_lowest_cost_cell` (`core/movement/MovementPathService.gd`) finds the next cell
by scanning the whole frontier. It does this on every pop, and it converts cell keys from strings each time.
The cost of one search therefore grows with the square of the cell count.
`reachable_cost_region` and `shortest_path` both use it.

Two more findings:

- On Stage, `find_explore_target` runs `reachable_cost_region` twice per call.
  One call is in `ActiveStageService.stage_reachable_costs`. The other is in `StagePartyMovementAdapter` (about line 674).
  `StageExploreTurnService.advance_turn` calls `find_explore_target` once per step of the advance, plus once before the loop.
- On Combat, `shortest_path` explains only about half of `prepare_movement`.
  The other half is not measured yet (see Phase 5).

## Prior work (checked 2026-10-06)

| Work | What it did | What it left |
|---|---|---|
| PR #58 (`886143d`, 2026-08-11) PURSUE freeze fix | Replaced N `shortest_path` calls per goal with one flood fill. Average PURSUE turn 2082 ms to 518 ms. | Plain Combat turn stayed at about 45 ms. It named the next step: `build_goals` runs 9 separate flood fills where one multi-source pass would do. It said "tracked separately". No tracking item exists in the backlog or the docs. |
| V2-COMBAT-003.5 Phase 3c (PR #69, `e9ff259`) | Fixed a 16x regression with a capacity-bounded flood-fill prefilter in `MovementOptionService`. | Same limit: it reduced the number of searches. |

Both fixes reduced how many searches run. Neither made one search faster. This story does that.
No other story in the backlog covers this work. V2-COMBAT-004 is the Keeper guidance loop and has no performance scope.

Existing tools to reuse:

- `tools/PursueTimingProbe.gd` (`-- tests pursueprobe`) measures per-turn cost in a PURSUE encounter.
- The equivalence method from PR #58: a temporary harness computes the result both ways on every call and compares destination, cost and path.
  PR #58 ran 677 comparisons with zero mismatches, then removed the harness.

## Out of scope

- Skipping, deferring or batching saves. Jeff rejected this on 2026-10-06 (D-01).
- Board repaint, camera, logger and screen render. They are measured as not causal.
- Changing any path result, tie-break order or movement rule.
- The `build_goals` multi-source change from PR #58, unless Phase 5 shows it is still a large part of the cost. If it is, report it and wait for approval.
- Making the `TEMP-PROBE` timers permanent.

## Contract that must hold

`CONVENTIONS.md` line 791 fixes the path rules. They stay unchanged:

- Positive integer destination-entry costs. Default 1.
- No RNG. No dependence on Dictionary insertion order.
- Equal-cost routes prefer the lowest cumulative line deviation, then straighter relative progress,
  then numeric `(col,row)` order as the last fallback.
- Returned paths exclude the origin. Failures return explicit reason codes.

## Options (chosen in phases below)

| # | Option | Effect | Risk |
|---|---|---|---|
| 1 | Replace the linear frontier scan with a binary heap that uses the same comparator. | Most of the Stage cost. Part of the Combat cost. | Medium. The result must stay identical. |
| 2 | Compute the Stage reachable region once per step and share it between its two callers. | About half of the Stage cost. | Low |
| 3 | Probe the rest of `prepare_movement` in Combat. | Finds the second half of the Combat cost. | None |

## Phases

1. **Gates.** Check that the V2-COMBAT-002 Slice 6 branch does not change `MovementPathService`, `ActiveStageService` or `StagePartyMovementAdapter`.
   If it does, stop and report. The tree must be clean. The Godot binary and `/tmp/echoes-vnext-tests/` are exclusive: no parallel runs.
2. **Baseline.** Re-confirm the evidence in `evidence-2026-10-06.md` first. Then re-apply `stutter-probe.patch` (it holds the `TEMP-PROBE` timers).
   If the patch no longer applies, rebuild the timers by hand. Add a fixed-seed probe in `tools/`
   (`-- tests pathprobe`) that drives one Stage session and one Combat fight and prints per-step phase times.
   Record the numbers from a debug run. No export build exists yet (D-07). Run the full suite once. Record the `Tests:` line.
3. **Equivalence harness.** Build the old-versus-new comparison first, before any change to the search.
   It compares cost map and path on every call. It runs over the full suite, the probe scenarios and randomized boards.
   The harness is temporary. Remove it before the PR, as PR #58 did (D-08).
4. **Option 2, then option 1.** Do option 2 first, and measure. Then do option 1, and measure again.
   Each change gets its own commit. If the harness shows one mismatch, stop and report. Do not re-record any fingerprint without Jeff's yes (D-02).
5. **Combat remainder.** If a Combat step is still above the target, add timers inside `prepare_live_movement_context`.
   Report what they show. Do not fix anything beyond this story without approval.
6. **Save cost.** Only measure the inside of `SaveService.save_to_file` (validate, deep copy, write, read-back, rotation).
   Report the numbers. Any change needs Jeff's decision, and every safety step stays unless he approves otherwise (D-01).
7. **Jeff's play test.** Jeff plays Stage with fast advances and Combat on Fast with camera moves. He compares with the baseline.
8. **Clean-up and docs.** Remove every `TEMP-PROBE` line, `core/PerfProbe.gd` and the equivalence harness. Update `docs/MEMORY.md`, `docs/integration-map.md` and `CONVENTIONS.md` if a contract text changes.
9. **Verification and PR.** One independent `qa-verifier` checks the combined tree and tries to prove an equivalence break.

## Risks

| Risk | Control |
|---|---|
| A path or cost differs, so combat results change | Phase 3 harness. Stop on one mismatch (D-02). |
| A recorded fingerprint moves | Stop and report. No re-record without Jeff's yes. |
| A heap uses a different tie order | Reuse the exact comparator. The harness runs randomized equal-cost boards. |
| A cache returns stale data | Share the region only inside one step. Key it by origin and walkable set. |
| A debug run overstates the cost | No export build exists yet (D-07). Re-measure on an export build when one exists. The targets then apply to the export build. |
| Branch conflict with Slice 6 | Phase 1 gate. |

## Targets (confirmed by Jeff, 2026-10-06, D-06)

On the test machine, excluding the save flush:

- Stage advance: at most 50 ms per step.
- Combat step: at most 30 ms per step.

These are engineering budgets, not design values. Today: 62 to 435 ms and 55 to 173 ms.

## Cost

The full suite takes about 18 minutes. Run it at baseline and once at the end. Do not run it in parallel.

## Model tiers (per `CLAUDE.md`)

| Work | Agent | Model |
|---|---|---|
| Probe tool, option 2 | `mechanics-developer` | sonnet |
| Heap change and equivalence harness (determinism) | `mechanics-developer` | opus |
| Combined-tree verification | `qa-verifier` | opus |

## Exit criteria

- Measured step times meet the confirmed targets, using the same probe as the baseline.
- The equivalence harness shows zero mismatches over the full suite, the probe scenarios and the randomized boards.
- The full suite `Tests:` line matches the baseline. No recorded value moved.
- Jeff signs off the play test.
- No `TEMP-PROBE` line remains. `core/PerfProbe.gd` is deleted.
- One independent `qa-verifier` confirms the combined tree.

## Open questions

None. All four questions are answered (2026-10-06):

| # | Question | Answer |
|---|---|---|
| Q-01 | Targets: Stage advance at most 50 ms, Combat step at most 30 ms. | Confirmed (D-06). |
| Q-02 | Priority P1. | Confirmed (D-06). |
| Q-03 | Does the stutter happen in an export build? | No export build exists yet. Not enough assets (D-07). |
| Q-04 | Keep the equivalence check as a permanent test? | No. Remove it after the story, as PR #58 did (D-08). |
