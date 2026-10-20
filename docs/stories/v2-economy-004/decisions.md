# V2-ECONOMY-004 — decisions

Answers from Jeff. Number format: D-01, D-02, ...

## D-01 — Story split and build sequence (2026-10-19)

**Question:** ECONOMY-004 lists ECONOMY-003 and ITEM-001 as dependencies. Build order puts
ECONOMY-004 before ITEM-001. Which sequence?

**Answer:** Split ECONOMY-004. Do not combine it with ITEM-001. Build in this order:

| Step | Story | Content |
|---|---|---|
| 1 | V2-ECONOMY-004 Part A | Reward vocabulary and weights, D66/D83 repair, Ase/Ekwan split in rewards, validation, early-reward tuning. Needs V2-ECONOMY-001 only. |
| 2 | V2-ITEM-001 | Separate story, separate agent chat. Spec is Open. |
| 3 | V2-ECONOMY-004 Part B / V2-ECONOMY-003 | Item-cost shape (item + Ekwan + Ase). Starts after ITEM-001. |

**Rules that follow:**
- The ECONOMY-004 chat does not design or build ITEM-001.
- When ITEM-001 is due, the ECONOMY-004 orchestrator writes the opening prompt for the ITEM-001 chat,
  in the format of the ECONOMY-004 opening prompt. The prompt states what ITEM-001 must give
  ECONOMY-004 Part B. Jeff and the ITEM-001 chat decide the rest of the design.
- D95 and D96 stay untouched (boss-encounter contract decision, 2026-08-29).
- Notion is not changed until Jeff says yes. Proposed Notion change: ECONOMY-004 depends on
  ECONOMY-001 only; ECONOMY-003 gains ECONOMY-004 as a dependency.

## D-02 — Boss weight leaves live payout (2026-10-19)

**Question:** `data.rewards.objective_weights.boss` is 60. Every stage has a boss stub objective,
so `RewardCalc.base_reward` pays 60 per stage for unreachable content. Exclude it?

**Answer:** Yes, exclude it from live payout in Part A. Own commit, one named cause.

**Boss timing check (Jeff asked, 2026-10-19):**
- The Working GDD has no text on a boss encounter. A case-insensitive search for "boss" finds nothing.
- No open or draft backlog row names a boss in its Story, Summary, Definition of Done or Exit Criteria.
- No story is scheduled to build the boss. The nearest rows are V2-STAGE-009 (Order 560, Draft, Open,
  Full Game), V2-STAGE-005 (650) and V2-STAGE-103 (610). Their page bodies were not read, so they
  are candidates only.
- `ObjectiveModel.TYPE_BOSS` stays a stub. D96 stays blocked until a boss-encounter contract exists.
- Consequence: the exclusion has no end date. A future boss story must restore a boss weight on purpose.

## D-03 — Weights for the five unweighted types: propose, then Jeff approves (2026-10-19)

**Question:** `recover`, `protect`, `endure`, `pursue` and `guide_spirit` have no entry in
`objective_weights` and pay 0 silently. What should Part A do?

**Answer:** `mid-game-designer` proposes one weight per type, marked PROPOSAL. Jeff approves or
changes each one before any value enters `data/balance.json`.

## D-04 — Tuning direction: rewards are too high (2026-10-19)

**Statement (Jeff):** Rewards are very high. The economy overflows with Ase and has too few places to
spend it. Things must feel difficult to attain. 40 Ase for one objective is possibly too high.

**Effect on this story:**
- Direction is lower Ase. No target number is set yet.
- The proposed weights (D-03) must start low. The existing weights (combat 30, shrine 40) are open to cuts.
- Numbers come from a characterization of real payouts against the real Ase prices. Jeff sets them then.
- Ase sinks (more places to spend Ase) are outside Part A. The crafting cost contract (Part B) is expected
  to add one. Not decided here.

## D-05 — Ekwan gets its own source per objective type (2026-10-19)

**Question:** Keep Ekwan as a percentage of Ase (`ekwan_base_factor` 0.12), or give each objective type its own Ekwan amount?

**Answer:** Separate Ekwan source. Each objective type pays its own Ekwan amount, not tied to the Ase paid.

**Effects to resolve in the plan (not decided):**
- Per-encounter payout (`reward_encounter_complete`) also derives Ekwan from Ase today. Whether it keeps a share or pays no Ekwan is open.
- The fate of `ekwan_base_factor` and `ekwan_shrine_multiplier` is open. D66/D83 stay a separate first commit.
- The per-type Ekwan amounts are design numbers. `mid-game-designer` proposes, Jeff approves (as D-03).
- Save changes stay additive. No RNG draw order changes.

## D-06 — Ekwan counts all objectives (2026-10-19)

**Answer:** Sum all objectives, the same rule as the Ase base (decision D39). Each objective type adds its
own Ekwan amount. The "first objective only" read (`objectives[0]`) ends.

**Effect:** `ekwan_shrine_multiplier` has no job in a summed model. Its removal or rename needs the
AGENTS.md rename exception (full-repo audit) or an alias. Open for the plan.

## D-07 — Unknown objective type: log an error, pay 0 (2026-10-19)

**Answer:** An objective type with no weight logs an error through `StructuredLogger` and pays 0.
The game does not stop. A test asserts the error is logged. The type never defaults to `combat`.

## D-08 — Banner `surface` should show the objective being fought: saved as a follow-up (2026-10-19)

**Finding:** `FlowEncounterState.gd:346` sets `_combat_surface` from `stage_objectives[0]`, the stage's first
objective. It does not use the objective being fought. After the Phase 2 repair the banner `data["surface"]`
shows that first-objective type (`guide_spirit` in the fingerprint harness).

**Answer (Jeff):** `surface` should show the objective being fought. This is NOT part of ECONOMY-004.
Save it as a separate item. Do not widen this story.

**Effect when it is built later:** it moves the same 14 FINAL fingerprint constants again
(`FlowFingerprintTests.gd`, `FlowFingerprintSeekTests.gd`). Re-record once, with its own cause.
Open: which story or backlog row owns it. No Notion write without Jeff's yes.

## D-09 — Working weight set B (2026-10-19)

**Answer (Jeff):** Set B from `phase3-weights-proposal.md` is the working shape. Phase 5 can still scale it.

| Type | Ase weight |
|---|---|
| pursue | 8 |
| combat | 10 |
| recover | 12 |
| protect | 12 |
| endure | 14 |
| shrine | 15 |
| guide_spirit | 16 |

Boss: pays 0 (D-02). Config shape for the boss: open (next question).

## D-10 — Boss config: keep `"boss": 0` in `objective_weights` (2026-10-19)

**Answer (Jeff):** Keep the `boss` key with weight 0. No new key. No code branch. The boss has a weight, so D-07 logs no error.

## D-11 — Pay only completed objectives (2026-10-19)

**Answer (Jeff):** Part A includes the Notion addendum rule: calculate objective rewards only from
objectives that were earned or completed. A skipped optional objective pays nothing.

**Sequence:** Phase 3a (weights set B, boss 0, unknown-type error) lands first with its own re-record.
Phase 3b (completed-only base) lands second with its own re-record. `sr-game-designer` checks the
mechanic first (read-only): when `completed` is set, and what pays on defeat, retreat and return-home.
Not in scope: D95 (`guide_spirit` required versus optional), the hard-coded 0.25 defeat factor.

## D-12 — Completed-only rule reaches everywhere (2026-10-20)

**Question (from `phase3b-design-check.md`):** stage payer only, or every reader of the stage base?

**Answer (Jeff):** Everywhere. The stage payer, the retreat and return-home partials, the defeat
consolation, the pace base and the rank all use the completed-only base, or a base Jeff names for that case.

**Consequence:** a plain completed-only read gives 0 in cases where no objective is complete yet (first fight of a
stage, first defeat, early retreat). Each case needs its own base. Decisions D-13 on follow.
Rank must use the same base on both sides of its ratio. Out of scope, report only: B1 (skippable optional
objectives), B5 (unstamped repeat return-home partial).

## D-13 — Defeat consolation base: the fought objective's weight (2026-10-20)

**Answer (Jeff):** The consolation is the existing 25% of the weight of the objective the party lost, not of the
whole stage sum. The first defeat still pays. The hard-coded 0.25 (`EconomyService.gd:168-169`) is a separate
finding and stays out of scope unless Jeff says so.

## D-14 — Partial payouts base: completed objectives (2026-10-20)

**Answer (Jeff):** Retreat and return-home partials pay 12% of the weight of completed objectives. They pay 0
until the party wins one objective. Consequence: the Scout `intel_retention_bonus` has no effect until an
objective is won.

## D-15 — Pace base: completed objectives plus the fought objective (2026-10-20)

**Answer (Jeff):** The pace base (`stage_base`, read at fight start) is the weights of completed objectives plus the
weight of the objective being fought. A mechanics-developer must confirm that the active objective index is set
before `EncounterSetupService.gd:739` runs.

## D-16 — Ekwan follows the completed-only filter (2026-10-20)

**Answer (Jeff):** Ekwan counts only completed objectives, the same rule as Ase. Applies in Phase 4 with the new
Ekwan source (D-05, D-06).

## D-17 — Player-side payout explanation: separate UI/UX task (2026-10-20)

**Statement (Jeff):** The player must understand why they get the amount they get. The reward rules
(completed-only base, consolation, partials, pace, redo) need an explanation on the player side. This is a UI/UX task.

**Effect on ECONOMY-004:**
- It is not built inside Part A (backend first; one story, one subject).
- Part A keeps the data the UI will need: each payout `breakdown` row carries the cause (for example
  "Base objectives", "Redo penalty", "Realm virtue", "Pace bonus"). Open for Phase 3b and Phase 4: which new rows
  the new rules add (completed objectives, consolation base, partial base). Names are PROPOSAL only.
- Player-facing wording is Jeff's. Agents propose options marked PROPOSAL and stop (ANSWERS #64: the result
  screen states the cause of the reward).
- Needs its own row in the backlog. No Notion write without Jeff's yes.

## D-18 — Payout row contract is a phase inside Part A (2026-10-20)

**Request (UI session):** every payout `breakdown` row gets a stable `cause` id and a `params` dict; a delta-0 row
with a cause appears when a payout is 0 by rule (partial before any win, repeat defeat); the retreat/return-home
row (`VentureResolveSnapshotBuilder.gd:63`, label "Scout return") gets a cause and the won count; Ekwan gets its own
cause row (D-16). Proposed cause ids (PROPOSAL, names open): objectives_won, pace_met, pace_missed, redo,
realm_virtue, defeat_consolation, partial_retreat, partial_return_home, sanctum_share, nothing_won_yet, repeat_defeat.

**Answer (Jeff):** Build it inside Part A as its own phase, Phase 3c, after Phase 3b. Phase 4 adds the Ekwan cause.
Fields are additive (saved `reward_breakdown` copies them; old saves have rows without them).
The UI build starts after Phase 3c. Own commit, own re-record if a fingerprint carries `breakdown`.

## D-19 — Row contract changes relayed by the UI session (2026-10-20)

Source: messages from the UI session (`payout-explain-ui`), which reports Jeff's wording and decisions in
`docs/stories/v2-payout-explanation/decisions.md` (worktree `cranky-proskuriakova-c4adbe`). These are relayed, not
typed to this session. They change the D-18 proposal. Jeff confirms them here when Phase 3c is planned.

| Item | Relayed change |
|---|---|
| Objectives cause | id `objectives_overcome`, params `overcome` and `total` (not `objectives_won`/`won`) |
| Redo | cause id `replay`; the row is ABSENT when it does not apply (no zero row) |
| Sanctum share | no `sanctum_share` cause; Ekwan shows only "Ekwan earned" with its amount; no cause or tooltip |
| Realm-end payout | none; skipped for now |
| Pace | ids `bonus_earned`, `bonus_missed` (earned or zero) |
| Other ids | `realm_virtue`, `defeat_consolation`, `partial_retreat`, `partial_return_home`, `nothing_overcome_yet` |
| New request | one saved bool "has seen a result ledger" so the ledger opens only the first time |

Open for Jeff: the saved bool is a new save field. It is additive and has no payout effect, but it is a
save-schema change outside the economy. Not decided.

## D-20 — Saved bool "has seen a result ledger" goes in Phase 3c (2026-10-20)

**Answer (Jeff):** Add one additive bool to the save (safe default false). It has no payout effect. A dispatched
action sets it; `SaveService` stays the only persistence entry. Own tests, including an old save without the field.
The save field name and the action name are open for the plan (no ID shown to the player).

## D-21 — Fix the fingerprint harness to match production (2026-10-20)

**Finding (Phase 3b build):** `FlowFingerprintTests._setup_encounter` calls `FlowEncounterState.enter` directly and
never sets `flow_ctx.active_encounter_objective_index` (stays -1). Production sets it when the party engages an
objective (`SituationEngagementService.gd:172`). So the harness reads a pace, rank and consolation base of 0.

**Answer (Jeff):** Fix the harness: set the index to 0. FINAL and SAVE hashes should hold at their Phase 3a values.
A run confirms it. If they hold, no fingerprint re-record is needed for Phase 3b.

## D-22 — Non-objective combat defeat pays 0 consolation (2026-10-20)

**Answer (Jeff):** Keep 0. A defeat in a combat that is not an objective has no objective weight, so the D-13 base is 0.
Before Phase 3b it paid 25% of the stage sum. Assumed accepted by the same answer: rank on a defeat uses
completed plus fought (the same base as pace), not strict completed-only.

## D-23 — Phase 3b result and the objective total (2026-10-20)

**Phase 3b verified:** after the harness fix (D-21) every long suite passed with NO constant re-recorded:
fingerprint suites 6/6, 1/1, `fingerprint_seek` 7/7, `combat_baseline` and `combat_roundtrip` 65/65, `reward` 39/39,
the rest 135/135. `balance.json` unchanged by the runs.

**Objective total (Jeff):** the `objectives_overcome` row shows "overcome of total". For now the total EXCLUDES the boss
stub. When the boss becomes a proper objective, the total includes it. The stub must be marked in one place that is
easy to remove (config, not a hard-coded type in code). Same marker is the natural home for "does not count".

**UI session decisions** (`docs/stories/v2-payout-explanation/decisions.md`, written by Jeff in that session) are accepted
as the source for the row contract: cause ids `objectives_overcome` (params `overcome`, `total`), `bonus_earned`,
`bonus_missed`, `replay` (absent when not applicable), `realm_virtue`, `defeat_consolation`, `partial_retreat`,
`partial_return_home`, `nothing_overcome_yet`, `repeat_defeat`; no Sanctum share cause; plus the saved "ledger seen" bool (D-20).

## D-24 — Stage payout rows show on the Resolve card (2026-10-20)

**Finding (Phase 3c):** the stage payout (objectives overcome, realm virtue, stage replay) is paid in the
`flow.complete_stage` dispatch and the return value is dropped (`VentureController.gd:680`). No screen shows it.

**Answer (Jeff):** Show it on the Resolve card. The UI/UX session adds it to the Resolve design.

**Backend rule (Phase 3d):** a pure, read-only preview of the stage payout, built by the SAME code that pays
(one row producer shared by `settle` and the preview, so the preview cannot drift from the payment). Payment
stays in `StageSettlementService.settle` behind `settlement_receipt`. The Resolve snapshot data carries the preview
rows (`cause`/`params` as in D-18/D-19) and the previewed totals. A test proves preview == paid on the same state.
Ekwan in the preview follows Phase 4.

## D-25 — No mid-stage stage-payout preview (2026-10-20)

**Answer (Jeff, relayed by the UI session; recorded in its D-12 and D-13):** No mid-stage stage preview. Mid-stage cards
show fight rows only. `stage_payout_rows` and `stage_payout_ase` exist only on the card that offers `flow.complete_stage`
(victory with no objectives remaining). No `stage_payout_final` flag. This matches the Phase 3d build.

## D-26 — Phase 3c/3d fingerprint re-record: one cause (2026-10-20)

14 FINAL constants moved (7 in `FlowFingerprintTests.gd`, 7 in `FlowFingerprintSeekTests.gd`). Cause: the final snapshot data
gained the key `ledger_seen` (the harness hashes key NAMES). Proof (MEASURED): for each of the 14 `FP_DEBUG final=` payloads,
removing `ledger_seen` from `data_keys` and hashing gives the old constant. ROUNDS and SAVE held (no drift line).
The new keys `stage_payout_rows` and `stage_payout_ase` are NOT in these payloads: the harness calls `enter` without the
pre-snapshot objective completion, so `objectives_remaining` is 1 and the preview is absent. Their production path is
covered by a separate test (see Phase 3d follow-up), not by the fingerprints.

## D-27 — Phases 3c/3d/3e verified; old Ekwan keys are removed in Phase 4 (2026-10-20)

**Verified (MEASURED):** after the D-26 re-record, fingerprint suites 6/6, `fingerprint_guide_spirit` 1/1,
`fingerprint_seek` 7/7; `combat_baseline` + `combat_roundtrip` 65/65; `reward` 39/39; the key-list and snapshot group 235/235;
`econ_char` 34/34. `balance.json` unchanged by the runs.

**Answer (Jeff):** Remove `ekwan_base_factor` and `ekwan_shrine_multiplier` in Phase 4. Use the AGENTS.md rename/removal
exception: a full-repo audit of `core/`, `ui/`, `tests/`, `docs/`; migrate every consumer in the same change; leave no alias;
say so in the story writeup.

## D-28 — Fights pay no Ekwan (2026-10-20)

**GDD check (READ-FROM-CODE of the GDD):** §19.2 defines Ekwan as "shaped matter, stored labor, and build capacity" (uses: rooms and
buildings, crafting, research and preparation; §19.6 "Ekwan pays the material and build cost"; §19.7 recycling returns Ekwan only).
No section names a fight as an Ekwan source. §21.1 and §19.10 leave the early Ekwan cadence open.

**Answer (Jeff):** Confirmed. Fights pay no Ekwan. Ekwan comes only from stage objectives, per objective type, completed
objectives only (D-05, D-06, D-16). Fight rows show Ase only. The per-encounter Ekwan share (`reward_encounter_complete`) is removed.
Revisit when the GDD sets the Ekwan cadence.

## D-29 — Working Ekwan set B (2026-10-20)

**Answer (Jeff):** Set B from `phase4-ekwan-proposal.md` is the working shape. Phase 5 can still scale it.

| Type | Ekwan |
|---|---|
| pursue | 2 |
| combat | 2 |
| protect | 3 |
| guide_spirit | 3 |
| endure | 4 |
| recover | 5 |
| shrine | 6 |
| boss | 0 |

Config key (PROPOSAL name): `data.rewards.objective_ekwan`, next to `objective_weights`, with a `boss: 0` entry.

## D-30 — Ekwan follows the replay multiplier (2026-10-20)

**Answer (Jeff):** Ekwan is multiplied by the same replay factor (`redo_multiplier`) as the Ase base, rounded ONCE on the stage sum.
A test pins the x.5 cells (Set B `recover` 5 at 0.7 = 3.5; `protect` 3 at 0.5 = 1.5). The replay row shows only when the amount changes.

## D-31 — Stage Ekwan is added to the stage-payout preview (2026-10-21)

**Answer (Jeff):** Add `stage_payout_ekwan` (name PROPOSAL) to the stage-payout preview, beside `stage_payout_ase`, only on the
stage-ending victory card (same condition as D-24/D-25). The UI shows "Ekwan earned" with its amount and no cause row.
Preview must equal what `flow.complete_stage` pays (test). Key-list tests change; the UI session is told the key name.

## D-32 — Remove the "Sanctum share" row (2026-10-21)

**Answer (Jeff):** Remove the Ekwan "Sanctum share" row from both payers. No breakdown row carries `currency: ekwan`.
Ekwan reaches the player as `stage_payout_ekwan` (D-31) and the balance. Not blocking, noted for Part B: whether vow-break
Ekwan prices (20 to 100) are goals or penalties.

## D-33 — UI build gets its go when the backend is ready and verified; one shared PR (2026-10-21)

**Answer (Jeff):** Give the UI session (`payout-explain-ui`) the go to build when everything it needs from the backend is
ready and verified. Backend and UI work in the same PR. The two sessions keep each other updated.

**Go condition (set by the backend session):** Phase 4 built, long suites run, every moved value attributed, re-recorded and
confirmed by a run; `stage_payout_ekwan` name confirmed. Phase 5 tuning changes numbers only, not keys, so it does not block.
**Not decided / needs Jeff:** the shared branch and commit. The backend work is uncommitted in this worktree; the UI session is on
`claude/cranky-proskuriakova-c4adbe` cut from `main`. A shared PR needs one branch that holds both. Commit only when Jeff asks.

## D-34 — Phase 4 fingerprint re-record: one cause (2026-10-21)

**Verified before the re-record (MEASURED):** `combat_baseline` + `combat_roundtrip` 65/65; `reward` 39/39; the key-list, snapshot,
save and stage group 239/239; `econ_char` 37/37 (agent run). `balance.json` unchanged by the runs.

28 constants moved: 14 FINAL (7 in `FlowFingerprintTests.gd`, 7 in `FlowFingerprintSeekTests.gd`) and 14 SAVE. ROUNDS held (0 drift lines).
Cause (D-28): fights pay no Ekwan. Proof: for all 28 payloads, the field diff against the previous run (Phase 3d logs) shows exactly ONE
changed field: FINAL `ekwan_awarded` 6 or 7 -> 0; SAVE `economy.ekwan` 6 or 7 -> 0. The previous payload hashes to the old constant in 28 of 28.
`stage_payout_ekwan` is not in the harness payloads (the harness fight leaves `objectives_remaining` at 1), as for `stage_payout_ase` (D-26).

## D-35 — Backend committed; shared PR from the backend branch; UI go sent (2026-10-21)

**Answer (Jeff):** The backend branch `claude/v2-economy-004-material-split-24c3be` is the shared PR branch.
Backend committed as ONE commit `4712518` (not pushed): the phases overlap in the same files, so they cannot be split
into clean per-phase commits after the fact; each moved value keeps one named cause in `phase2-attribution.md`,
`phase3a-attribution.md` and D-21 to D-34. UI session `payout-explain-ui` got "GO: backend verified": it merges the backend branch
into its own, builds, and reports its last commit; the backend session merges the UI branch back; Jeff opens one PR.
