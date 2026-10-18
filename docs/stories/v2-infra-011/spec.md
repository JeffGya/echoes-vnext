# V2-INFRA-011 — Movement-option cost: cheaper guide-spirit fights and a faster test suite

Status: Draft (proposed by Claude, 2026-10-18). Spec State: Mostly Locked. Wave: Foundation. Priority and Order are proposals for Jeff.
Dependencies: V2-INFRA-010 (same file, `MovementPathService.gd`; see "Relation to V2-INFRA-010").

Everything marked **Proposed** is a suggestion. Jeff decides scope, targets, priority and order.

## Goal

Make the Combat movement planning cheaper, with identical results.
A guide-spirit fight must cost much less time. The full test suite must run faster as a result.
No behaviour change. Every path, every cost and every recorded fingerprint stays byte-identical.

## Why

The full test suite takes about 18 minutes sharded (about 53 minutes serial). Test work in 2026-10 showed that the floor is a few tests, and not the number of shards or cores:

| Fact | Value |
|---|---|
| Total test time (4-core machine) | 3637 s |
| Five tests | 2527 s (69%) |
| Guide-spirit fights (4 of the 5 tests) | 2391 s (66%) |
| Best possible sharded wall-clock time while these tests stay as they are | about 1058 s |

The same cost is the Combat step cost that Jeff feels in play, on boards with many cells.

## What the profile found (2026-10-18)

One guide-spirit fight (`fingerprint_guide_spirit`, 24 rounds, 168 turns). Full numbers are in `evidence-2026-10-18.md`.

| Level | Part | Time | Share of the fight |
|---|---|---|---|
| 1 | `prepare_live_movement_context` (movement options before every turn) | 264 s | **98.4% of turn time** |
| 2 | `MovementOptionService.generate_options` (432 calls) | 242 s | 93% |
| 2 | Inside it: `_candidate_routes` / `_build_forceful` / `_build_control` / `_build_lateral_extra` / `_build_endpoint_candidates` | 97 / 82 / 22 / 18 / 13 s | 37 / 32 / 8 / 7 / 5% |
| 3 | `MovementPathService.shortest_path` (10,100 calls, about 270 cells settled per call) | 212 s | **76%** |
| 3 | Inside it: `StageTerrain.legal_neighbors` (1.85 million calls, 60 µs each) | 110 s | **40%** |
| 3 | Inside it: `_take_lowest_cost_cell` (frontier scan; frontier averages 14 cells) | 30 s | 11% |
| 3 | Inside it: rest of the search loop | 71 s | 25% |

Setup is under 1.2% of every suite. The guide spirit itself costs 0.01 s per turn. The cost is the movement planning of the other actors on a board with about 680 walkable cells.

Findings that shape the work:

1. `legal_neighbors` is a pure function of (cell, walkable set, bounds). Every search inside one `generate_options` call uses the same walkable set, so the same cells are expanded again and again.
2. `_candidate_routes` and `_build_forceful` each run one full search per destination-region cell (about 7.7 cells per goal). `_build_forceful` uses empty terrain and edge costs, so its paths can differ from `_candidate_routes`.
3. `_build_control` runs 4 times per actor turn (once in prepare, once per goal): 29.5 s in total. Its inputs may differ, because `generate_options` removes occupied cells first. Not yet proven identical.
4. The frontier scan is only 11%, because the frontier is small. A heap (V2-INFRA-010 option 1) helps this fight little.

## Relation to V2-INFRA-010

V2-INFRA-010 targets Stage advance and the Combat step stutter. Its option 1 is a heap for the frontier. Its Phase 5 ("Combat remainder") asks for timers inside `prepare_live_movement_context`. This profile is that measurement.
Both stories change `MovementPathService.gd` and share the equivalence method. The two stories must not change that file at the same time.
**Open (Q-01):** Merge the two stories, or keep two stories and fix the order.

## Out of scope

- Any change to a path result, a cost, a tie-break order or a movement rule.
- Re-recording any fingerprint or golden constant (stop and report instead, D-02).
- `data/balance.json` and game design values.
- Shorter encounters, fewer determinism rounds, and changes to what any test asserts. (The determinism test for guide-spirit drives 2 x 30 rounds of a fight that never ends. That is a test-scope question for Jeff. It is not part of this story.)
- A heap for the frontier (V2-INFRA-010 option 1).
- Skipping or deferring saves.

## Contract that must hold

- `AGENTS.md` determinism rules: no RNG, no dependence on Dictionary insertion order, no new process-wide mutable state.
  A cache lives inside one call or one object. It is never a `static var`.
- `CONVENTIONS.md` weighted-path rules: positive integer entry costs; equal-cost routes prefer the lowest cumulative line deviation, then straighter relative progress, then numeric `(col,row)` order; returned paths exclude the origin.
- Every recorded value stays identical: 7 mode fingerprints, 7 determinism fingerprints, `combat_baseline` emotion and transition hashes, and the other suites.

## Work (Proposed order; each step is measured, and each step has its own commit)

1. **Gates.** The tree is clean. V2-INFRA-010 and V2-COMBAT-002 Slice 6 do not change `MovementPathService`, `MovementOptionService`, `StageTerrain` or `LiveMovementContextService` at the same time. If they do, stop and report.
2. **Baseline.** Re-run the saved profile (`probe/`; how to run it is in `evidence-2026-10-18.md`). Record the numbers. Run the sharded suite once and record the `Tests:` lines and the wall-clock time.
3. **Equivalence harness first (temporary).** For `legal_neighbors`: old versus new on randomized boards (including void cells, border cells and diagonal corner cases) and on every board of the suite. For `shortest_path`: path, cost and reason compared on every call. For `_build_control`: edge costs and sources compared.
   The harness is temporary. Remove it before the PR, as PR #58 did.
4. **Fix 1a.** Make `StageTerrain.legal_neighbors` cheaper with the same result and the same order. Measure.
5. **Fix 1b.** If the profile still shows `legal_neighbors` above 15% of the fight, add a neighbor cache that lives inside one `generate_options` call and passes through the `shortest_path` callers. Measure.
6. **Fix 3.** Prove first whether the 4 `_build_control` calls per turn return identical results. If they do, compute once per turn and pass the result on. If they do not, report and skip.
7. **Fix 4.** Reduce key-string and dictionary work in the `shortest_path` loop. One change per commit, each with the harness.
8. **Fix 2 (analysis only).** Report whether the repeated searches can be merged or reused without changing a tie-break. Do not implement it without Jeff's approval. The deviation term depends on the destination, so a merge is probably not byte-safe.
9. **Re-profile and re-measure.** Same probe, same seed. Run the sharded suite twice. Compare with the baseline.
   The sharded run is a full run: its merge step judges `movement_fallback` on the ledgers of all shards with the serial verdict
   (AGENTS.md "movement_fallback in a sharded run"). Choose one full mode and do not run both (LESSONS #34).
   The merge step also prints how many real fallbacks it ignores (57 on 2026-10-18, all from `combat_roundtrip`).
   That number must not change: a change means a movement-path change altered which boards fall back.
10. **Docs.** Update the timing table, the best-case wall-clock figure and the slow-test list in `AGENTS.md`. Update `docs/LESSONS.md` if a rule changes.
11. **Jeff's play test.** Combat on Fast on a guide-spirit stage. The result must feel the same and faster.
12. **Verification.** One independent `qa-verifier` checks the combined tree and tries to prove an equivalence break. Remove every probe line and the harness.

## Risks

| Risk | Control |
|---|---|
| A path or cost differs, so a fight changes | Step 3 harness. Stop on one mismatch (D-02). |
| A recorded fingerprint moves | Stop and report. No re-record without Jeff's yes. |
| A cache returns stale data | The cache lives inside one `generate_options` call. It is keyed by cell. The walkable set does not change inside the call (occupied cells are removed before the first search). The harness checks this. |
| `_build_control` results differ between the 4 calls | Fix 3 starts with a proof. If it fails, skip the fix. |
| Conflict with V2-INFRA-010 | Gate in step 1 and the open question Q-01. |
| Gains on the cloud 4-core machine do not equal gains on Jeff's Mac | Measure on both. Targets use percent, not seconds. |

## Targets (Proposed, Jeff to confirm)

- `fingerprint_guide_spirit` fight drive: at least 30% shorter than the baseline of 265 s (4-core cloud machine).
- Sharded full suite: at most 13 minutes on the same machine (baseline: 17m40s). CI follows.
- Zero moved fingerprints. Zero harness mismatches.

These are engineering budgets, not design values. The estimates behind them (30 to 35% from fix 1, up to 10% from fix 3) are not measured yet.

## Cost (estimates, not measured)

| Fix | Work estimate |
|---|---|
| 1a `legal_neighbors` cheaper | about half a day, plus 2 verification runs |
| 1b neighbor cache | about 1 day, plus 2 verification runs |
| 3 `_build_control` once | about 1 day, half of it analysis |
| 4 search-loop overhead | 1 to 2 days |
| 2 merge or reuse searches | analysis only here; implementation 2 to 4 days and may be impossible |

A sharded suite run takes about 18 minutes. A profile run takes about 5 minutes. Only one Godot process group may run at a time.

## Model tiers (per `CLAUDE.md`)

| Work | Agent | Model |
|---|---|---|
| Profile re-run, baseline, doc updates | `mechanics-developer` | sonnet |
| Equivalence harness and every change in `core/` (determinism) | `mechanics-developer` | opus |
| Long runs (sharded suite, profile) | main conversation | — |
| Combined-tree verification | `qa-verifier` | opus |

## Exit criteria

- Targets met (as confirmed by Jeff), measured with the same probe as the baseline.
- The harness shows zero mismatches over the suite, the probe scenarios and the randomized boards.
- The `Tests:` lines match the baseline. No recorded value moved.
- Jeff signs off the play test.
- No probe line and no harness remain.
- One independent `qa-verifier` confirms the combined tree.
- `AGENTS.md` shows the new timing figures.

## Open questions

| # | Question | Status |
|---|---|---|
| Q-01 | Merge with V2-INFRA-010 or keep two stories? | Open |
| Q-02 | Targets: at least 30% shorter guide-spirit fight; sharded suite at most 13 minutes. | Proposed |
| Q-03 | Priority (proposed P2). Order: V2-INFRA-011 comes after V2-INFRA-010 (Jeff, 2026-10-18). Notion: 254.8 (V2-INFRA-010 is 254.7). The backlog CSV export is behind Notion and still has V2-INFRA-010 at 262.9, so the CSV row of V2-INFRA-011 is 262.95. A refresh of the CSV from Notion makes both agree. | Order decided; priority proposed |
| Q-04 | Is the determinism test for guide-spirit allowed to keep 2 x 30 rounds of an unfinished fight? | Open, outside this story |
| Q-05 | Is `movement_arbiter/avoid_overcommit_stays_proportionate` (a known failure in the runner) in scope? | No. Listed for completeness. |
