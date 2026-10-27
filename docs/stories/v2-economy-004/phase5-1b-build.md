# V2-ECONOMY-004 Phase 5.1b — build report (mechanics-developer)

Written in STE. Decisions used: D-69, D-74, D-75, D-78. Nothing is committed, pushed or sent to Notion. No `ui/` file is edited.
Tags: RAN = I ran it. PREDICTED = not measured.

## 1. The rule code (`core/economy/RewardCalc.gd`, one place)

- `compute` sets `any_death := echoes_survived < total_echoes` and passes it to `_compute_rank`.
- `_compute_rank(raw_score, thresholds, any_death)`: the S branch is `rank_score >= S and not any_death`. A death therefore falls through to the A test. The branch is the cap; the letter is `const DEATH_CAP_RANK := "A"` (a documentation constant, see OPEN).
- `rank_score(echoes_survived, total_echoes, pace_credit, reward_cfg)` lost the `redo_mul` argument and the multiplication (D-74).
- `_compute_rank` lost the `run_count` argument; the "S only on run 0" test is gone (D-75).
- `redo_multiplier` still exists and `compute` still returns `redo_multiplier`. Ase and Ekwan payers still use it. Unchanged: `rank_points`, thresholds, weights, stipend, Thread code.
- A defeat is still F (the rank code runs only for a win).
- `pace_changed_rank` compares the grade with and without pace, both with the same death cap.

## 2. Grade table (RAN, tested). Win, pace: slow / partial / full

| Started | All home | One dead |
|---|---|---|
| 1 | A / S / S | C / C / B |
| 2 | A / S / S | B / B / A |
| 3 | A / S / S | B / A / A |
| 4 | A / S / S | B / A / A (full is capped; score 0.90) |
| 5 | A / S / S | B / A / A (full is capped; score 0.92) |

The cap changes a grade only from 4 Echoes started. With 1 to 3 started, the score of one death never reaches S.
So the brief line "1 to 5 started, one dead, full pace: rank is A" is true only for 2 to 5. At 1 started the grade is B. Rule tested: never above A.

## 3. Tests

Added in `tests/EconomyCharacterizationTests.gd` (both pass):
- `econ_char/death_caps_rank_at_a`: the table above for 1 to 5 started; no death grade above A; 2 dead of 5 is not above A; a death with full pace never outranks all home with slow pace.
- `econ_char/rank_ignores_replay_factor`: for 1 to 5 started, every home count, 3 paces, run_count 1, 3 and 9 give the same grade as run_count 0; all home with full pace is S at run_count 1 and 3.

Edited: `rank_score_table` lost its "S only on run 0" check (now covered by the new test). A defeat is F stays there.
`reward` suite: I read it, I did not run it. No test asserts a removed rule: `rank_S_first_run` (run 0, all home) and `rank_F_poor_performance` (defeat) still hold, and `pace_rank_changed_flag` uses run 0 with no death at 2 started, so the cap does not touch it. I made no edit there. Its test 10 name says "first run"; the name is now narrower than the rule (cosmetic).
Other tests that use `rank_score`, `_compute_rank` or `run_count` with rank: none (grep in `tests/`, `core/`, `ui/`).

RAN: compile check, 0 errors. Filtered suites with `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase51b`:
`Tests: 243 total, 242 passed, 1 failed` (16 suites). The one failure was my own wrong expected grade for 1 started (C, real B). I fixed it. Then `=econ_char,economy,realm_reward`: `Tests: 56 total, 56 passed, 0 failed`. I did not re-run the other 13 suites after the one-line expected-value fix; the fix touched only that test.

## 4. PREDICTED moved values

Evidence (READ, `/tmp/echoes-econ004-p51r-a.log`): the six fingerprint fixtures (`fp_combat`, `fp_purify_shrine`, `fp_recover`, `fp_protect`, `fp_endure`, `fp_pursue`) each show `"echoes_survived":5` and `"rank":"S"` (6 and 6 hits). Roster 5, none dead, so `any_death` is false. Run count 0, so the redo factor is 1.0 and the rank score does not change.

| Group | Moves? | One cause |
|---|---|---|
| `snapshot_fingerprint` fixtures | PREDICTED no | 5 of 5 home, run 0: no cap, redo factor 1.0 |
| seek | PREDICTED no | Same fixture shape; I did not read its payload |
| combat_baseline, combat_roundtrip | PREDICTED no | They hold sim values; the rank does not enter the sim. I did not check that every fixture keeps all Echoes home |
| `reward` | PREDICTED no | See section 3 |

A mode that could move: any fixture where an Echo dies in a win and the score reaches 0.90 (needs 4 or 5 started and a fast win), or a fight with run_count above 0 (then the rank can rise; Ase and Ekwan do not change). I did not find one. Only the run can show it.

## 5. RUN REQUEST (for the main chat)

1. Groups: fingerprints (`snapshot_fingerprint`), `seek`, `combat_baseline`, `combat_roundtrip`, `reward` (its own run).
2. Commands, one per group, from the checkout root. Delete the save dir before each run:
```
rm -rf /tmp/echoes-econ004-phase51b-run; ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase51b-run /usr/bin/perl -e 'alarm shift; exec @ARGV' 900 /opt/homebrew/bin/godot --headless --quit --path "$(git rev-parse --show-toplevel)" -- tests =<group> > /tmp/echoes-econ004-p51b-<group>.log 2>&1
```
   Use `=snapshot_fingerprint`, `=seek`, `=combat_baseline`, `=combat_roundtrip`, `=reward`. Tool timeout 600000 ms. Run them in the background from the main chat.
3. Files edited by the run: none. (The suites write only to the save dir.)
4. Restore check: `git status --porcelain` shows only the three files in section 6.
5. Read back: the `Tests:` line and any line that starts with `❌` or `FP_DEBUG` per group. If a fingerprint hash moves, compare `echoes_survived`, `rank` and `run_count` in the payload against section 4.

## 6. Files changed

- `core/economy/RewardCalc.gd`
- `tests/EconomyCharacterizationTests.gd`
- `docs/stories/v2-economy-004/phase5-1b-build.md`

## 7. Consumers outside `core/` (report only)

`ui/screens/venture/ResolveScreen.gd:182` reads `pace_changed_rank`; its meaning is unchanged. No `ui/` file reads `rank_score` or `_compute_rank`. I found no `ui/` text that states "S only on the first run" in a search of `rank`/`first run` patterns I did not run exhaustively (see OPEN).

## OPEN — questions and assumptions
ASSUMED: "Death" = `echoes_survived < total_echoes` in the fight | WHY: Jeff's definition in the brief | WRONG IF: an Echo can leave the fight home count without dying (retreat, ally swap), or `total_echoes` can include a non-roster unit.
ASSUMED: `DEATH_CAP_RANK` is a documentation constant; the S-branch condition does the work | WHY: the cap letter is A and the next branch is A, so a lookup would add code for no gain | WRONG IF: Jeff wants a different cap letter; then the code must clamp, not skip a branch.
ASSUMED: the brief line "one dead, full pace: rank is A" is a ceiling, not an exact grade | WHY: the score gives B at 1 started and A at 2 to 5 | WRONG IF: Jeff wants A guaranteed (that would raise a low score, which D-69 does not say).
BLOCKED: none.
NOTE for the main chat: I did not re-run 13 of the 16 suites after the last one-line test fix. I did not search `ui/` text for "first run" claims. Docs (`CONVENTIONS.md`, rank prose) may still say "S only on run 0" or "x redo"; I did not search them.
