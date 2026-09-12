# V2-INFRA-003 — Pre-Playtest Defect Triage

Compiled 2026-08-25 at `789547e`. Every closure claim below was verified against the tree by the
orchestrator, not only by the triaging agent.

## Register accounting correction

The register's own summary table is stale. Actual identifiers: **D01–D90**. Six (D71–D76) are
**coverage gaps, not defects**. So the defect population is **84**, not 88.

---

## Headline

**37 of 84 can be closed before the manual test. 47 cannot.**

- **22 are already closed and the register has not caught up.**
- **15 more are genuinely closable cheaply** — 9 fixes, 3 deletions, 3 scheduled mechanic connections.
- **47 stay open**: large or design-bearing, unreachable by a player, pure observability, or owned by
  another story.

**The largest single saving is not a fix — it is paperwork.** Four Phase 8 closures are still
presented as open, one of them as the register's flagship live defect. Without that correction Jeff
spends the playtest hunting a reward exploit that no longer exists.

---

## Already fixed, still listed as open — VERIFIED BY THE ORCHESTRATOR

| ID | Claim | Verified evidence |
|---|---|---|
| **D36** | Quit-at-Resolve keeps the reward | Payment left the builder. `StageSettlementService.settle()` runs in the same dispatch as `advance_stage`, behind a persisted receipt. No window to quit inside. |
| **D77** | Full reward at every encounter; defeat farmable | `EconomyService.reward_encounter_complete()` (`:131`) and `settle_stage_complete()` (`:211`) exist. `ActiveStageService.claim_situation_defeat_consolation()` writes `consolation_paid` (`:341,369,371`) and returns true once per situation. The 25% stays; the fight stays retryable. Exactly the specified shape. |
| **D05** | No-encounter stage pays nothing, graded a defeat | `NO_COMBAT_GRADE = "C"` (`VentureController.gd:164`), settlement runs on `is_combat_victory or not has_encounter`. |
| **D39** | Two functions disagree on the base reward | `ActiveStageService.gd:330` delegates to `RewardCalc.base_reward()`. Both readers now sum. |
| **D20** | `verdict` written into a badge always hidden | **Disproved.** `ResolveScreen.gd:261-266` shows the badge when `verdict` is non-empty. **Third** disproved entry, not second. |
| **D73** | Nothing pins producer B's Ekwan omission | Closed — assertion at `tests/OnboardingTests.gd:283`. |

Plus D21–D26 (Phases 3–6), D34, D41 (disproved), D42, D63, D82, D86–D90 (Phase 8).

**Three product-owner questions are already answered in code and should be struck:** D05's grade
(`"C"` → "compromised"), D39's base (**sum**), and D77's consolation.

---

## The pre-test batch — ~4-6 hours, ONE explained re-record

### Stage 0 — paperwork, 30 min, zero code
Mark the closures above. Correct the kind-counts. **Highest value item in the batch.**

### Stage 1 — moves nothing recorded, ~1 hour
| ID | Fix |
|---|---|
| **D78** | `quit_on_go_back = false` + a `WM_GO_BACK_REQUEST` handler |
| D08 | A missing `.` in an unreachable retreat seed fallback |
| D10 + D11 | Clear `_double_damage_mult` beside `_carrier_double_damage` |
| D48 | Make two neighbouring `source_id` guards agree |
| D81 | Delete the **second**, unreachable dormant gate — never the inline one; the survivor rolls the clocks forward |

Run the suite. Expect 1,494 green, zero re-records.

### ⚠️ Stages 2 and 3 move recorded values — one batch, one re-record

**Stage 2 — baseline only, ~1 hour**
| ID | Fix |
|---|---|
| D37 + D38 | Two flags on the victory-return path; the parameters already exist |
| D40 | Return a distinct sentinel from `advance_stage`'s completed-guard branch |
| D07 | Read the flattened `morale`/`fear` in the scout-return preview — one line |

**Stage 3 — the scheduled one-at-a-time connection pass, ~2-3 hours**
Connect one, run the full suite, record what moved, then the next.
| ID | Mechanic |
|---|---|
| D01 | Near-death morale and fear — read `stats.max_hp` |
| D04 | Level-up full heal and stats written to the wrong place |
| D03 | The bark budget cap, and delete the comment that reasons about a cap that was never wired |
| D18 + D19 | Delete the two dead snapshot keys |

### Deliberately excluded
**D35** (missing `direction`/`tag` on the first resolve card) — trivial, but it moves a fingerprint
for a cosmetic gain. Let the playtest say whether the grey tokens read wrong.
**D50, D83, D12, D45** — all move recorded values for defects unlikely to be reached in one session.
**D57** must follow D27, which is another story.

---

## Could not verify

| ID | Why |
|---|---|
| D14 | Whether `death_round` appears in a pinned payload — decides trivial versus re-record |
| D43 | "KO visited twice" has never been reproduced |
| D59 | Whether the UI can surface the two dormant actions out of phase |
| D75 | "48 of 73 actions untested" — not re-measured, almost certainly stale |
| D02 | Whether all ten leadership trait ids are in a live grant pool |
| D66 | True owner disputed between the prompt and Notion |

---

## The one to fix first

**D78 — the Android Back button quits the app from any screen.**

Not the deepest defect. The one that can **end the playtest itself**. `quit_on_go_back` is unset, so
it defaults true, and there is no back handler anywhere in `ui/` or `core/`. On a phone a back-swipe
is reflexive — likely within ten minutes, likely at the Resolve screen where no back affordance
explains the gesture. Every other defect costs an observation. This one costs the run.

---

## What the playtest should watch for — no test can judge these

1. **Does the near-death beat land?** D01/D04 turn on a combat moment that has never fired in the
   game's history. Does it swing a fight, or is it noise?
2. **Bark density after the D03 cap.** Three per round is a number nobody has ever heard.
3. **The removed free full heal.** Fights get longer exactly where an Echo levels mid-combat. Does
   difficulty spike at the wrong moment?
4. **Opening pacing.** The prologue diverges from GDD §20.7 — the second summon comes after the
   Realm, because the awakening Ase grant does not exist. Does the session stall waiting for Ase?
5. **The awakening modal**, rendering for the first time. Payoff, or interruption?
6. **The no-combat Thread grade `"C"` → "compromised".** Flagged in code as a judgement, not a
   repair. Does the peaceful route feel compromised, or punished?
7. **Does the Resolve card lie about the party?** If D07 ships, confirm emotional status varies.
8. **Contact conversations** resolve without moving emotion, bonds or vows (D06). Take one
   deliberately and report whether it felt consequential.
9. **Movement legibility.** Nothing records *why* a unit moved (D27). If a move looks stupid, that
   observation is the only signal that exists.
10. **Thread readouts after D40.** Duplicate Threads are pinned by tests; plausible-but-wrong Thread
    narratives are not. Do they describe the run that actually happened?
