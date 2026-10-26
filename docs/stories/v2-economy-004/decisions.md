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

## D-36 — Phase 5 targets (2026-10-21)

**Answer (Jeff):**
1. The first summon takes about 1 to 3 stages. After that, about one summon per 2 stages.
2. Targets are also wanted for a called summon and a skill unlock. A skill unlock may cost "even higher" than today.
   Everything must make sense together with accrual (online and offline Ase) and rewards.
3. Advice wanted on simplifying the virtue bonus, fight bonuses, pace bonus and replay. Jeff's intent: "an XCOM style reward system"
   (the phrase is not defined; the advice agent states its reading and asks one confirming question).

**Process:** design advice in two rounds (`sr-game-designer` with the game-mechanics-designer and game-design skills, then
`game-feel-developer` reading round 1 and building on it). Then a tuning proposal; Jeff approves each number.
Open: which summon grade "a summon" means (uncalled 60, called 150, chosen 400).

## D-37 — "A summon" means the uncalled summon (2026-10-21)

**Answer (Jeff):** The cadence target (first summon in about 1 to 3 stages, then one per 2 stages) is for the UNCALLED summon (60 Ase).
Called (150) and chosen (400) are special cases. They must not be easily attainable. Their cadence is much larger.
Their target numbers are not set. The design advice proposes a range; Jeff approves.

## D-38 — Pre-entry reward: an estimate in the stage overview, not an exact promise (2026-10-21)

**Answer (Jeff):** Today the player does not see the reward before entering a stage, and no exact promise is wanted now.
Items and other rewards may be seen or estimated before entering later. An ESTIMATE of the Ase and Ekwan to earn, shown in the
stage overview before entering, "would be nice".

**Effect:** not built in Part A (one story, one subject). It needs its own design: what an estimate may say without breaking hidden
objectives and scouting (GDD §20.7, §20.8), and a backend read of expected rewards. The feel review (round 2) advises on the honest
form of an estimate. Open: owner story, UI design. No Notion write without Jeff's yes.

## D-39 — "First summon" is the third Echo, from about 0 Ase (2026-10-21)

**Answer (Jeff):** Confirmed (GDD §20.7, §22.4 step 4, §20.12 as read by the feel review): the opening Ase pays for the second Echo before
stage 0. The player enters stage 0 with about 0 Ase. "First summon in 1 to 3 stages" means the third Echo. The round 1 cadence table
(52 Ase in hand) is superseded by round 2.

## D-40 — Remove the enemy bonus and the virtue bonus (2026-10-21)

**Answer (Jeff):** Remove both (both advice agents recommend it).
- Enemy bonus (5 Ase per enemy, `enemy_defeated_bonus`) and the `enemies_defeated` row leave the payout.
- Virtue bonus (`virtue_bonuses`, `stage_index_bonus_per`, the realm-order multiplier inputs it used, `RealmService.calculate_stage_reward`) and the
  `realm_virtue` row leave the payout.
- This is a removal under the AGENTS.md exception: full-repo audit of `core/`, `ui/`, `tests/`, `docs/`, `scripts/`, `data/`; migrate every consumer in the
  same change; no alias; say so in the story writeup. The rank ratio (uses `enemies x 5`) must be re-based (see next decisions).
- The UI session is told: rows `enemies_defeated` and `realm_virtue` and their causes are removed.
Open: what the realm scale becomes (the realm-order multiplier), the Echoes-alive amount, the bonus maximum, replay, retreat price.

## D-41 — Echoes alive: a small capped stipend, shown as a count (2026-10-21)

**Answer (Jeff):** Keep an Ase payment per surviving Echo, shown as a count ("2 of 2"). It is meant to be a stipend: with permadeath, the
player should be rewarded and incentivized to keep Echoes alive. It must NOT be a game-changing amount, and it is CAPPED.
- A full party pays about 10 Ase in total at most. For each member fewer, the total falls by a percentage. A party of 2 has a different
  maximum, "let's say 4 maybe".
- To be rechecked with the feel agent (numbers, curve, count display).
- Facts: `data.sanctum.party_max_size` = 5 (the party cap in config). So "full party" = 5 Echoes unless Jeff says otherwise.
Open: the exact curve for 1 to 5 Echoes; whether the percentage applies to Echoes alive at the end or to Echoes lost.

## D-42 — Goal statement: keeping Echoes alive must be rewarded and feel rewarding (2026-10-21)

**Statement (Jeff):** The goal of the game is to keep your Echoes alive and guide them to complete their stories and grow. Keeping them
alive should be rewarded and should FEEL rewarding, as part of the game and the economy.

**Effect:** This is a design pillar for the reward rows and the tuning. D-41 (a small, capped Ase stipend per surviving Echo) is one
channel, not the only one. The advice agents propose how survival is rewarded and felt (feedback, readability, other canon channels such as
growth), without inventing mechanics, as options for Jeff. Open: whether survival also pays in a non-Ase channel (growth), a Part A scope question.

## D-43 — Echoes alive stipend: 2 Ase per Echo, cap 10 (2026-10-21)

**Answer (Jeff):** 2 Ase per Echo alive at the end of a win, capped at 10 (1 to 5 Echoes pay 2, 4, 6, 8, 10). Count shown as "home N of M"
(display and copy are the UI session's and Jeff's). Count Echoes alive at the end, shown against the Echoes started.
Source: `phase5-echoes-alive-recheck.md`. Open sub-decisions: per fight or once per stage; downed or withdrawn counts as alive; no stipend on a retreat;
stipend excluded from the replay factor and the realm scale; retreat price.

## D-44 — Echoes stipend is paid once per stage (2026-10-21)

**Answer (Jeff):** The stipend (D-43) is paid ONCE per stage, with the stage payout on the stage-ending card, up to 10 Ase.
Mid-stage fights show the count only. Effect: the `echoes_alive` row moves from the fight rows to `stage_payout_rows` (stage payer and preview),
and the preview must equal what `flow.complete_stage` pays. Assumed, to confirm with the Phase 5 build: the count is the Echoes alive at the
stage-ending win, against the party that started that stage. UI session heads-up sent.

## D-45 — "Home" means not dead (2026-10-21)

**Answer (Jeff):** Only dead Echoes do not count. Downed or withdrawn Echoes count as home. A mechanics-developer confirms the death state
in code (the exact field) before the build.

## D-46 — Retreat price about 10 Ase; no stipend on a retreat (2026-10-21)

**Answer (Jeff):** The retreat costs about 10 Ase (today 30, `data.combat.retreat_ase_cost`). A retreat pays no Echoes stipend (it is not a stage-ending win);
the partial payout of D-14 stays. Exact value 10 unless Jeff says otherwise; the tuning proposal checks it against the cadence.
Open: what the code does when the balance is below the retreat price (mechanics-developer reads it).

## D-47 — Quick-win bonus: open; Jeff wants risk-taking encouraged, perhaps through the rank (2026-10-21)

**Statement (Jeff):** Torn. He wants players to risk their Echoes and find the balance, and to not always take the safe route, accepting that
choices sometimes bring loss. He agrees that handled wrong the bonus reads as a penalty. A speed bonus makes sense "sort of", but it should
perhaps be part of the ranking system.

**Tension with D-42** (keeping Echoes alive is the goal): the design must make risk a visible, fair CHOICE with stakes, not a trap, and must not
pay more for losing Echoes. Not decided. Advice requested from the designer, then the feel agent (rank-based bonus, how rank is computed after
the D-40 re-base, what speed and survival each contribute to rank, what the player sees before the fight).

## D-48 — Design leads; scope is judged at build time (2026-10-21)

**Statement (Jeff):** Do not worry about scope while designing. When the work reaches the build stage, then scope matters. The first priority is always a
clear, engaging and fun game.
**Effect:** Advice agents and questions must rank options by game quality (clarity, engagement, fun, the Echoes pillar), not by size of work. Scope and cost
appear only in the build plan.

## D-49 — Quick-win bonus: Part A pays nothing in Ase for speed (R0); the rank design stays open (2026-10-21)

**Answer (Jeff):** R0. Part A pays no Ase for speed. Win rows: objectives, Echoes home (stipend), replay or consolation when they apply. The rank is re-based
internally (win 0.40, home share 0.40, pace 0.20), no Ase attached; survival is the largest term.
**Design reason (not a scope reason):** no player action is known that trades speed for safety, so a "Swift" reward would read as luck, not as a fair risk choice
(feel review). The agents' option C (marks "All home" and "Swift", rank pay, Thread rule) stays the design target for the rank, pending a probe for a lever.
**Note:** the question was framed partly by scope. Under D-48, Jeff confirms or corrects this decision on its design merits.

## D-50 — A death always compromises the stage Thread (2026-10-21)

**Answer (Jeff):** Any dead Echo in a stage makes that stage's Thread "compromised", whatever the speed (GDD §14.3; remedy routes in §15.6).
Today one lost Echo can still give a clean Thread (rank A). This is a design target; the rank/Thread build is a later step. It must be readable to the player
(the cause shown: which Echo, "home N of M"). Open: the build plan for it (rank story).

## D-51 — Quick goal: show that it exists, not the target (2026-10-21)

**Answer (Jeff):** Before a fight the player sees that a quick win is possible on this objective type (and what it is worth), but NOT the target round.
This keeps pace-reward D-12 and D-20 (target hidden). Objective types with no pace (protect, endure, the protect variant of guide_spirit) show no quick goal.
UI and wording are a later step; copy is Jeff's.

## D-52 — Run the risk probe (2026-10-21)

**Answer (Jeff):** Yes. A probe measures whether player choices (directive, formation, any guidance lever that exists) change the pace outcome
(full, partial, none) and the Echo loss rate over fixed seeds. It decides whether a speed reward can be a fair risk choice (feel review, D-47/D-49).
No game change. A mechanics-developer builds it; the main chat runs the long parts. Result goes to Jeff with the design options.

## D-53 — What replay is for; replay reduces Ase strongly and halves the Echoes stipend (2026-10-21)

**Answer (Jeff):** Replay is for mastery and story, not farming. It is also for collecting Threads, or trying for higher-quality Threads, which are tied to a virtue.
A relatively strong reduction on the Ase is acceptable. The Echoes stipend is cut in half on a replay (cap 10 becomes 5).
**Supersedes** the feel review proposal that the stipend skip the replay factor. D-30 stands (Ekwan follows the replay factor).
Open: the replay factor value and shape (flat, or the existing ladder with a lower floor); the same factor for Ase and Ekwan; what counts as a replay
(a completed realm run, `run_count`; a retry of an unresolved stage must not take the factor).

## D-54 — Replay factor: flat 0.35 on Ase objectives and Ekwan (2026-10-21)

**Answer (Jeff):** A flat factor of 0.35 on a replay, for the objective Ase and the Ekwan (one factor, rounded once on the stage sum). The Echoes stipend
uses its own halving (D-53: cap 5 on a replay). It replaces the ladder (`redo_penalty_per_run`, `redo_penalty_floor`) after the audit.
Open: what counts as a replay (completed realm run); the retry rule (an unresolved stage must not take the factor); the S-grade-only-on-first-run rule
in the rank (unchanged, out of scope until the rank story).

## D-55 — Later realms pay more; summon prices should rise with the number of Echoes (2026-10-21)

**Answer (Jeff):** Later realms pay more (a fixed per-realm scale on objective Ase and Ekwan; value in the tuning proposal).
Summon prices should also rise with the number of Echoes a player has, to keep the balance. Jeff also wants this economy lever to REGULATE POPULATION SIZE.
He says it might not be part of this story. Under D-48, the design is made now; scope is judged at the build plan.
Open: the price curve by roster size (and what population range the game wants; GDD roster/party/inventory limits); whether it applies to called and chosen grades;
interaction with the cadence targets (D-36, D-37, D-39: early cadence stays 1 to 3 stages for the first summon, then about one per 2 stages).

## D-56 — More Directives are wanted: a lever that trades speed for survival (2026-10-21)

**Answer (Jeff):** Agreed with the feel review. The game needs Directives (player intent levers) that add a speed-versus-survival choice. More Directives will be added;
noted for later work. Today only two exist (`Scout Carefully`, `Seek Signs`), both scouting styles. Not built in this story.
Effect on this story: the rank/Swift design (D-47, D-49) waits for those Directives; R0 (no Ase for speed) holds until then.
Recorded in `follow-ups.md`.

## D-57 — Population: a Sanctum VILLAGE, regular size 7 to 12, ceiling about 14 (2026-10-21)

**Answer (Jeff):** The game has a Sanctum village, not a house. The designer's recommendation (P-A: 7 to 10, soft ceiling near 12) is about right, with the ceiling around 14.
Because of permadeath and rising difficulty, Jeff hopes the population is reduced regularly and stays about 7 to 12 in regular play.
**Effect:** the summon price curve is built for a typical roster of 7 to 12, with a plateau at the ceiling (about 14). Wording: "village", not "house" (copy is Jeff's).
The feel review's repairs stand: a plateau (not x1.2 forever), and a visible next price and plain reason. A death lowers the living count and so the next price
(never shown as a discount). Open: plateau value, called/chosen premium, the opening's Echo 2 affordability.

## D-58 — Opening Ase stays at 52 (2026-10-21)

**Answer (Jeff):** No change. Keep the opening at 52 Ase.
**Open fact check (mechanics-developer, read-only, before the build):** how the opening affords Echo 2 with 52 Ase when the uncalled price is 60
(a scripted or free first summon, a different price, or a real shortfall). If a shortfall exists, report it to Jeff; do not change the opening.

## D-59 — Price curve rises to Echo 14, then flat (2026-10-21)

**Answer (Jeff):** The uncalled summon price keeps rising gently up to the ceiling at about Echo 14, then stays flat (about 360 to 430 at the ceiling; exact values in the
tuning proposal). A large village stays possible (GDD §18.8). The next price and the plain reason are shown to the player.

## D-60 — Called and chosen: a fixed extra over the uncalled price, reviewed after playtest (2026-10-21)

**Answer (Jeff):** Called = uncalled price + a fixed extra; chosen = uncalled price + a larger fixed extra. Start values: called +90 (range to 180), chosen +340 (range to 800)
as PROPOSAL; reviewed after playtest and raised if called or chosen become routine late. Config keys in `data.summoning`.

## D-61 — Skill unlock 60 / 90 / 120 Ase by Standing, not rising with village size (2026-10-21)

**Answer (Jeff):** Approved: 60 Ase at Standing 3, 90 at Standing 6, 120 at Standing 9 (today 40 for every skill). Does not rise with the number of Echoes.
Mechanics-developer confirms `ase_cost` is per skill with no code change (`unlock_conditions.ase_cost`).

## D-62 — Working Ase weights: set B doubled (2026-10-21)

**Answer (Jeff):** Approved as the working set; the order is checked with the probe before the player sees it.

| Type | Ase weight |
|---|---|
| pursue | 16 |
| combat | 20 |
| recover | 24 |
| protect | 24 |
| endure | 28 |
| shrine | 30 |
| guide_spirit | 32 |
| boss | 0 |

Ekwan set B (D-29) is unchanged. The probe reports rounds and loss rate per objective type so the order can be judged.

## D-63 — Realm scale: 1.00 / 1.25, then +0.25 per realm (2026-10-21)

**Answer (Jeff):** Approved. `realm.01` = 1.00, `realm.02` = 1.25, later realms add 0.25 (rule: 1 + 0.25 x (position in `realm_order` - 1)). The scale applies to
objective Ase and Ekwan only, not to the stipend. Replaces the virtue-based realm-order multiplier (removed, D-40).

## D-64 — Village dwellings paid with Ekwan: wanted, out of this story (2026-10-21)

**Answer (Jeff):** Yes, a village capacity limit built with Ekwan (rooms or dwellings) is wanted, alongside the rising summon price. It is out of scope for this story.
It goes to an open Sanctum story or a new story later. Recorded as follow-up 20. No Notion row without Jeff's yes.

## D-65 — Objective Ase is paid at the stage end; a running tally is under design review (2026-10-21)

**Answer (Jeff):** Pay at the stage end (as D-44). Reason raised by Jeff: Ase has little use inside a realm. READ-FROM-CODE (Phase 1 sink table): the only Ase spend
during a realm run is the retreat (10 Ase); summons, skill unlocks and institution assign happen in the Sanctum; vow breaks may act at stage entry (unconfirmed).
Jeff wants more design and feel work on a **running tally** (an estimate of the Ase and Ekwan earned during the stage run, or another mechanic that feels like that):
does it fit the game concept in the GDD, and is it a good mechanic to begin with? The tally would reverse D-25 (no mid-stage preview) only if Jeff approves it after the review.
Until then D-25 stands. Not decided: the tally.

## D-66 — Permadeath is not built here; the reward system is built to connect to it (2026-10-22)

**Finding (Phase 5.0, READ-FROM-CODE):** permadeath is not built. A dead Echo is rebuilt at full HP each fight (`EncounterSetupService.gd:210-214`) and nothing removes it from the roster;
`roster.size()` equals Echoes ever owned; `echo_id` uses `roster.size() + 1`; no release action; recruits join free.
**Answer (Jeff):** Skip building permadeath here. Build the reward system so it connects to it. A story on the backlog will build permadeath; a note there says the two must be connected.
Candidate backlog story: V2-INFRA-005 (Ready, Order 262, Locked: "make death always carry a reliable baseline consequence package"); also V2-ITEM-006 (Draft, death relics).
Jeff confirms which story gets the note. No Notion write until he says yes.
**Connection points (the note, for the permadeath story):** (1) the stipend counts Echoes home at the stage end; needs a record of "Echoes that started the stage" and "an Echo died this stage"; (2) the Thread rule D-50 needs the "an Echo died this stage" flag, recorded when the death happens, because dead Echoes revive between fights today; (3) the summon price counts LIVING Echoes; needs dead Echoes removed from the roster, a unique id scheme (`roster.size() + 1` repeats), and a rule for recruits and any release action; (4) the rank home share (0.40) reads Echoes home / started.
Until permadeath exists: use the last fight's survivors (non-ally, non-spirit, `is_dead == false`) as "home"; use active party size as "started"; the price counts the roster as it is.

## D-67 — Permadeath note written on V2-INFRA-005 (2026-10-22)

**Done (Jeff said yes):** a dated note "Impact from V2-ECONOMY-004" was appended to the Notion page V2-INFRA-005 (Ready, Order 262, Locked; "any permadeath removes the Echo from roster state").
It lists the four connection points of D-66 (stage stipend, Thread rule, summon price, rank). No other Notion page was changed.

## D-68 — Tally direction waits for a mockup in motion (2026-10-22)

**Answer (Jeff):** Interesting suggestion. Before choosing, he wants a mockup he can see in motion: a sequence stage -> objective -> stage.
**Action:** the UI session builds an interactive click-through mockup with switchable variants: (1) status quo, (2) direction E (people and stakes; "carried home" only at the return decision with a comparator),
(3) E plus a wordless flame glow. Realm.02 example (recover 24 then combat 20, scale 1.25, party 4). A "lose an Echo" toggle shows the loss case. Wording is PROPOSAL.
D-25 stands until Jeff chooses.

## D-69 — Any death caps the rank at A (2026-10-22)

**Finding (Phase 5.1):** with the rank score 0.40 win + 0.40 home share + 0.20 pace, a party of 4 or more that lost one Echo but went fast scores 0.90 = S, above a slow all-home win (0.80 = A).
**Answer (Jeff):** Any death caps the rank at A. S needs everyone home. A death never ranks above a clean win, whatever the speed. Matches D-42 and D-50.
**Build:** a separate step 5.1b after Phase 5.1 is verified and re-recorded, so each moved value keeps one cause. The cap is a rule in `RewardCalc.rank_score` (config-free: it is a rule, not a number).

## D-70 — Pace HUD follows the pace fraction (2026-10-22)

**Answer (Jeff):** OK. `pace_state` follows the pace fraction: full up to 1.1 times par (`pace_full_ratio`, fraction 1.0), none at 1.6 times par or worse (`pace_zero_ratio`, fraction 0.0), partial in between. The old rule (follow the Ase paid)
could never show partial with the new weights. A visible HUD change; Jeff checks it in play.

## D-71 — Direction E chosen, without the flame glow (2026-10-22)

**Answer (Jeff, via the UI session, recorded as D-16 in `docs/stories/v2-payout-explanation/decisions.md`):** Direction E, WITHOUT the flame glow.
No running Ase figure on the mid-stage card. "Carried home" appears only at the return or retreat confirmation, with a comparator beside it (people safe and their state, intel gained,
whether the stage waits, the cost), and only when above 0. Mid-stage card content: the party and their state, what the fight changed, the objective mark, intel gained, "the Thread is whole so far".
D-25 stands (no mid-stage Ase preview). The mockup: `docs/stories/v2-payout-explanation/mockups/stage-flow-motion.html` (UI worktree).
Open rule questions before the build: (1) after a return home, does an overcome objective stay overcome, and is the 12% deducted from the later payout; (2) B5, the unstamped repeat return-home payout;
(3) do the realm scale and the replay factor apply to the 12% partial.

## D-72 — "Carried home" is an advance on the stage payout (2026-10-22)

**Basis (GDD §20.8):** an unresolved stage keeps its locked instance; reruns preserve what the player learned. After a return home, overcome objectives stay overcome and the player can come back.
**Answer (Jeff):** The 12% carried home on a return or retreat is an ADVANCE. When the stage is finished, the stage payout is paid in full MINUS what was already carried home. No double pay.
**Rules that follow:**
1. Overcome objectives stay overcome after a return home. The stage waits.
2. The amount carried = 12% of the stage amount for the completed objectives, using the same formula as the final payout (realm scale and replay factor apply), minus what was already carried from this stage. A repeat return with no new objective carries 0 more. This closes B5 (the unstamped repeat return-home payout) by construction: the stage keeps a record of the Ase and Ekwan already carried.
3. Ekwan follows the same rule.
4. Leaving early costs time and the risk of the choice, not Ase. The "carried home" figure on the confirmation is what is banked now.
**Build:** a new field on the stage record (additive): carried Ase and carried Ekwan. The stage payer subtracts it; the receipt stays exactly-once. Own step (5.8), own long run and attribution.

## D-73 — Opening: keep as it is (2026-10-22)

**Answer (Jeff):** Keep the opening as it is, knowing the facts (Phase 5.0, READ-FROM-CODE): the player holds 40 Ase after the first trial (52 at best after about 10 minutes of the awakening boost); Echo 2 costs a flat 60.
The player waits a few minutes for the flame to gather charge. No change in Part A. D-58 stands. Risk noted by the feel review: a wall before stage 0. Revisit after a playtest (follow-up 22).

## D-74 — Rank ignores the replay factor (2026-10-22)

**Answer (Jeff):** The rank does not use the replay factor. Replays pay less Ase and Ekwan (D-54) but are judged on the fight: win, Echoes home, pace. A clean replay can give a clean Thread.
Build: in step 5.1b (with the death cap, D-69), remove the replay factor from `rank_score`. Open: the "S only on the first run" rule.

## D-75 — Rank S is allowed on replays (2026-10-22)

**Answer (Jeff):** Remove the "S only on run 0" rule. S needs everyone home (D-69) and speed (the score), on any run. A replay can earn the best Thread quality. Build: step 5.1b with D-69 and D-74.

## D-76 — All 14 skills cost 60 Ase now; Standing 6 and 9 skills come later (2026-10-22)

**Answer (Jeff):** Set all 14 existing skills to 60 Ase now. Standing 6 and 9 skills will be added later, and the 90 and 120 prices (D-61) apply then. A note goes on the Notion story responsible for those skills.
Facts (Phase 5.0, READ-FROM-CODE): `ase_cost` is read per skill at `ProgressionController.gd:433`; all 14 are `min_standing` 3; no code gates on Standing; no Standing 6 or 9 skill exists.
Notion candidates found: V2-PROG-012 (Draft, Order 410, "Turn the mid-tier calling lattice from data support into real progression play"), V2-PROG-016 (Draft, Order 520, "Complete the calling lattice"); V2-PROG-005 (Done) says "future Standing 6/9 growth can attach". Jeff picks the story; no Notion write until then.

## D-77 — Skill price notes written on V2-PROG-012 and V2-PROG-016 (2026-10-22)

**Done (Jeff chose both stories):** a dated note "Impact from V2-ECONOMY-004" was appended to the Notion pages V2-PROG-012 (the Order 410 mid-game Calling story, which needs Standing-6 skills at 90 Ase)
and V2-PROG-016 (Standing-9 skills at 120 Ase). Both notes say: all 14 current skills cost 60 now; the price is read per skill with no code change; the price does not rise with village size; the story must add the skill content.
No other Notion page was changed. Note found: two Notion stories share the code V2-PROG-012 (Order 251 and Order 410); the note is on Order 410 (page id 339c3d1ede928122b934ec4443ac3104), the Standing-6 story.

## Phase 5.1 long run result (MEASURED, 2026-10-22)
fingerprint_combat, purify_shrine, recover, endure, pursue: 5 drifted (FINAL and SAVE; endure FINAL only per earlier prediction, see log). fingerprint_guide_spirit: 1/1 held. fingerprint_seek: 5 modes drifted, 2 held. combat_baseline + combat_roundtrip: passed.
7 determinism suites 7/7. `reward` 35/35. Wider group 241/241. `balance.json` and `git status` unchanged by the runs. Attribution (opus) is running; no constant is edited until it is proved.

## D-78 — Rank/replay/S decisions fold into step 5.1b (2026-10-22)
Step 5.1b (after the 5.1 re-record): any death caps the rank at A (D-69); rank ignores the replay factor (D-74); S is allowed on replays (D-75). Own long run, attribution and re-record.

## D-79 — The combat retreat is denied when the balance is short (2026-10-22)

**Answer (Jeff):** Deny the retreat when the player has less Ase than the price (10). Today (Phase 5.0, READ-FROM-CODE, `FlowRuntime.gd:1175-1180`) a short balance proceeds free and the balance never goes negative.
**Effects to build (step 5.4):** the retreat action is disabled with a readable reason when the balance is below the price; the UI reads the balance (today it checks only `retreat_eligible`); tests for denied, exact balance, and enough balance.
**Noted risk (feel review, GDD §20.10):** a poor player in a losing fight cannot leave exactly when they are weakest. The map-level return home (`stage.return_home`) is a different action and stays free; this denial applies to the in-fight retreat only. Revisit after a playtest (follow-up 23).

## D-80 — The summon screen is its own UI session, after the backend price curve (2026-10-22)

**Answer (Jeff):** Yes, as its own session after the backend. It shows the living count, the next two prices and one plain reason; never a "cheaper now" line after a death. Starts after step 5.5 builds the price curve and the backend branch is merged.
A session card (summon-price-ui) was proposed. No Notion row. Copy is Jeff's.

## D-81 — The lost Echo's name comes from a `lost` list in the stage row params (2026-10-22)

**Answer (Jeff):** The backend adds a `lost` list (the display names of the Echoes that died in the stage) to the params of the `echoes_alive` stage row, alongside `alive` and `started`. It reads from the stage record, which permadeath (D-66) will fill; until then it uses the last fight's dead Echoes.
Names only, no ids shown to the player. Built in step 5.2.

## D-82 — Optional objectives become truly skippable (2026-10-22)

**Answer (Jeff):** Yes. A stage can finish with an optional objective left undone. It then pays nothing for it (completed-only, D-11), so skipping is a real choice between reward and risk.
**Facts (READ-FROM-CODE, Phase 3b check, D94/D95):** the stage gate (`objectives_found >= obj_total`, D94) forces every objective situation to be reached, so `pursue` is mandatory in practice. The generator marks only `pursue` optional (`RealmGenerator.gd:145`) while config marks `guide_spirit` optional too (D95); the boss stub is always optional (D96, untouched).
**Build (new step 5.9):** change the gate to "every REQUIRED objective is completed, and at least one objective was reached" (keeps the D94 guard: a stage with no required objective must not complete on entry). Needs: what the player sees about a skipped optional objective; what "reached" means. Open: D95 (is `guide_spirit` required or optional), below.

## D-83 — guide_spirit is required; D95 is closed by changing the config flag (2026-10-22)

**Answer (Jeff):** `guide_spirit` is required. The config flag `data.stages.objective_types.guide_spirit.required` changes from false to true, so the config matches how the generator plays. Only `pursue` stays optional. The generator is not changed, so generation-derived values do not move (it already treats `guide_spirit` as required). D95 is closed.
Check in the build: whether the generator should read the config flag (the defect's fix) or keep its constant; the safest path keeps generation unchanged and fixes the dead flag.

## D-84 — Copy: one ux-copy pass after the row set is final (2026-10-22)

**Answer (Jeff):** A copy pass later with the ux-copy skill. After the row set is final, a ux-copy session proposes options for every player-facing string (tooltips, "home N of M", the carried-home line, the stage waits line, the summon-price reason, the mid-stage card lines, the rank marks), all marked PROPOSAL, in Jeff's vocabulary ("earns", "found and overcome", "village", "home"). Jeff approves each. Until then the builds use placeholder text.

## D-85 — Called and Chosen stay locked on the summon screen; the screen asks the backend for the new price fields (2026-10-22)

**Answer (Jeff):** Keep Called and Chosen locked for now. The summon screen shows the uncalled price card only. The price config for them is ready (D-60), so opening them later needs no price change.
**Backend request accepted into step 5.5** (from the summon UI session): snapshot `data` gains `living_count`, `village_ceiling`, `price_flat`, per-grade next price and price after, `batch_prices`, `batch_totals`, and the largest affordable count; the summon handler spends the sum of the in-turn prices, never `count x one price`.
**Copy:** per D-84 a ux-copy pass later; the session's picks (A1 "7 living in the village", B1 "Next Echo / The one after", C1 "The price of holding one more life in the village.", P1 plateau line, D1 "Need 40 more Ase") are placeholders only.

## D-86 — Phase 5.1 re-recorded (2026-10-22)
20 constants (FINAL and SAVE of combat, purify_shrine, recover, endure, pursue in each suite) re-recorded with the proof in `phase5-1-attribution.md` (hash restore 20 of 20, forward 20 of 20). ROUNDS held; protect and guide_spirit held. Correction: D-70 text now says full up to 1.1 times par.

## D-87 — Commit each verified step on the backend branch; never push (2026-10-22)

**Answer (Jeff):** Yes. After a step's long run, attribution, re-record and confirmation run pass, the backend session commits it on `claude/v2-economy-004-material-split-24c3be` (local only, no push). The message names the step and its cause. Jeff opens the PR later.

## D-88 — Phase 5.1b verified: no fingerprint moved (2026-10-22)
Rank: any death caps at A (S needs everyone home); the replay factor no longer touches the rank; S is allowed on replays (D-69, D-74, D-75). MEASURED after the build: fingerprint suites 6/6 and 1/1, `fingerprint_seek` + `combat_baseline` + `combat_roundtrip` 72/72, `reward` 35/35, wider group 243/243. `balance.json` and `git status` unchanged by the runs. Grades with one dead at full pace: B at 1 Echo started, A at 2 to 5 (the cap changes a grade only from 4 started).

## D-89 — Phase 5.2 re-recorded: a won fight pays 0 Ase (2026-10-22)
MEASURED long run: `combat_baseline` + `combat_roundtrip` passed (seek group 72 total: only the 7 seek drifts failed), `reward` 35/35, wider group 247/247, ROUNDS held, `balance.json` and `git status` unchanged. 28 constants moved (14 FINAL, 14 SAVE, in both suites, including protect and guide_spirit). Proof: for all 28 payloads exactly ONE field changed (FINAL `ase_awarded` 50 to 0, SAVE `economy.ase` 50 to 0) and the previous payload hashes to the old constant in 28 of 28. Cause: the Echoes stipend moved from the fight payout to the stage payout (D-43, D-44).

## D-90 — Phase 5.3 verified: no recorded value moved (2026-10-22)
Weights doubled, realm scale 1.00/1.25/+0.25, replay factor 0.35 flat (ladder and `redo_multiplier` removed with a full audit). MEASURED: fingerprints 6/6 and 1/1, `fingerprint_seek` + `combat_baseline` + `combat_roundtrip` + `maturity_baseline` 74/74, `reward` 35/35, wider group 251/251; `balance.json` and `git status` unchanged by the runs. Assumed by the build: the "Base objectives" row shows the amount after the realm scale (rows add up); consolation and the 12% partials take scale and replay now (the advance rule is step 5.8).

## D-91 — Phase 5.4 verified: retreat costs 10 and is denied when short; no fingerprint moved (2026-10-22)
`data.combat.retreat_ase_cost` is 10, read through `RetreatService.get_ase_cost` (missing key: error log and 10, never 30). A balance below the price denies the in-fight retreat (log `encounter.retreat.denied`, no spend, no partial, fight continues). New snapshot keys: `retreat_affordable` (bool) and the denial marker `retreat_denied`; `retreat_ase_cost` now holds 10. UI must read `retreat_affordable` (CombatBoardScreen ~1199-1210). MEASURED: fingerprints 6/6 and 1/1, seek+baseline+roundtrip+maturity 74/74, `reward` 35/35, wider group 323/323; `balance.json` and `git status` unchanged by the runs. A recorded key list (`snapshot` suite) gained `retreat_affordable` (cause: the new key).

## D-92 — Phase 5.5 verified: summon price by village size, called/chosen extras, skill cost 60; no recorded value moved (2026-10-24)
`SummonService.price_for(cfg, grade, echo_number)` is the one price function; `data.summoning.price_by_echo_number` (Echo 2..14: 60, 60, 70, 85, 100, 120, 145, 175, 210, 250, 300, 360, 430; flat from 14), `village_ceiling` 14, `called_extra` 90, `chosen_extra` 340. All 14 skills cost 60 (`unlock_conditions.ase_cost`; no code change). The handler spends the sum of the in-turn prices; a short balance spends nothing and returns the SUMMON snapshot with `summon_denied`. Legacy config keys `ase_cost_per_summon` and `ase_cost_per_summon_by_grade` removed with an audit; the snapshot keeps the legacy `ase_cost_per_summon` (= next uncalled price) for the UI until it removes its read. MEASURED: fingerprints 6/6 and 1/1, seek+baseline+roundtrip+maturity 74/74, `reward` 35/35, 7 determinism suites 7/7, wider group 522/522; `balance.json` and `git status` unchanged by the runs.
Findings (not fixed): `handle_summon` spends Ase before checking `seed_root`; `echo_id = roster.size()+1` (permadeath story); a recruit raises `living_count` and so the next price (matches D-55, ANSWERS #28).

## D-93 — Phases 5.5b and 5.8 verified; one recorded value moved (2026-10-24)
5.5b: the summon grade lock lives in the core (`data.summoning.grade_enabled`, `summon_grade_options[].enabled`, refusal `summon_denied = {reason:"grade_locked", grade}`; Jeff: the rule belongs in the core, not in a UI constant). 5.8: "carried home" is an advance (D-72): `carried_ase`/`carried_ekwan` on the stage record, one helper (`StageSettlementService.carry_home`) for retreat and return home, stage end net of the advance with the `carried_advance` row, previews `carry_home_preview` (stage-explore snapshot) and `carry_retreat_preview` (encounter snapshot). MEASURED: fingerprints 6/6 and 1/1; seek + baseline + roundtrip + maturity 74/74 (rerun alone after one run hit its alarm under 6-way load: no `Tests:` line, discarded); `reward` 35/35; determinism 7/7; wider group 579/579; `balance.json` unchanged by the runs. The one moved value: `STAGE_EXPLORE_FINGERPRINT_HASH`, cause the new key `data.carry_home_preview` (proof: with the key removed the old hash returned).

## D-94 — Phase 5.9 verified: optional objectives are skippable; guide_spirit is required; no recorded value moved (2026-10-25)
Rule (one function, `ObjectiveModel.stage_completable`): a stage completes when every REQUIRED objective is completed AND at least one non-boss objective is completed (keeps the D94 guard; the boss never counts). The explore gate and the Resolve gate agree. `data.stages.objective_types.guide_spirit.required` = true (D95 closed); the generator is untouched (a 40-seed test checks the generated flags equal the config). A skipped optional pays nothing (D-11). MEASURED: fingerprints 6/6 and 1/1; seek+baseline+roundtrip+maturity 74/74; `reward` 35/35; determinism 7/7; wider group 623/623; `balance.json` and `git status` unchanged by the runs.
Not guarded: `VentureController.handle_complete_stage` trusts the offered action (a hand-sent `flow.complete_stage` is not re-validated): follow-up 25.

## D-95 — Payout UI scope: all of Direction E, now (2026-10-25)

**Answer (Jeff):** The payout UI session builds all of Direction E now: the ledger at the final rows; the mid-stage card (party and state, what the fight changed, the objective mark, intel gained, "the Thread is whole so far"); "carried home" only at the return or retreat decision with its comparator (only above 0); the "home N of M" row with the sequence (party first, each Echo marked home, count completes, quiet Ase figure; lost Echo named once, no minus); the retreat button disabled with its price. Copy stays placeholder until the ux-copy pass (D-84). No flame glow (D-71). The session resolves the merge conflicts in `AGENTS.md` and `scripts/test-shard-map.sh` (suite counts) from `scripts/check-shard-map.sh`, and does not push.

## D-96 — Scope conflict resolved: all of Direction E in the payout UI session (2026-10-25)
The payout UI session reported that Jeff had approved only the ledger update in its own chat; Jeff had chosen all of Direction E in the backend chat (D-95). Jeff confirmed (backend chat, 2026-10-25): ALL of Direction E in that session. The earlier limit is lifted. Order: the ledger first (running), then the mid-stage card, the carried-home confirmations, the "home N of M" sequence, the retreat button state, the skipped-objective display. Jeff plays the result before the PR.

## D-97 — Skipped-objective display: later (2026-10-25)
**Answer (Jeff):** Later, as a follow-up. Part A shows "N of M overcome" only; a skipped optional objective is simply not counted. Watch in play whether players understand it, then design the display. The boss stub is never shown as skipped. Follow-up 26.

## D-98 — Card fields: no preference from Jeff; the recommended two are added (2026-10-25)
**Answer (Jeff):** No preference on the three optional mid-stage card fields. **Default taken by the backend session (reversible by Jeff):** add the two recommended fields; do not add fight events.
1. `intel_gained` (step 5.10, built first; key only when above 0).
2. Step 5.11: `objective_overcome` ({index, type, label}; key only when this fight overcame an objective) and `thread_whole` (bool, computed in ONE place from this fight's deaths, D-50; the permadeath story later changes that one place).
3. NOT added: fight events (rescue, refusal): events are not defined yet (follow-up 27).
`thread_whole` is always present on the combat victory card, so the final-snapshot key list gains one key; the 14 FINAL fingerprint constants will move with that one named cause and a hash proof.

## D-99 — intel_gained: keep the dormant seam; intel is a later story (2026-10-25)
**Finding (step 5.10, READ-FROM-CODE):** no fight reveals a situation in the current code (writers of `revealed`: `SituationEngagementService`, `ContactController`, `FlowStageExploreState`, all before or outside combat). `data.intel_gained` is therefore absent in every real game today.
**Answer (Jeff):** Keep it. Intel will be worked on in a later story. The seam stays: volatile `FlowContext.encounter_start_revealed_count` (not saved), set in `EncounterSetupService.setup`, read in `build_final_snapshot`, key written only above 0, kept by the replayed card. Follow-up 28: design how a fight reveals intel; then the mid-stage card's intel line lights up.

## D-100 — Phase 5.10 verified: no recorded value moved (2026-10-25)
`data.intel_gained` seam (key only above 0; dormant, D-99). MEASURED: fingerprints 6/6 and 1/1; seek+baseline+roundtrip+maturity 74/74; `reward` 35/35; determinism 7/7; wider group 625/625; `balance.json` and `git status` unchanged by the runs.

## D-101 — Phase 5.11 re-recorded: thread_whole (2026-10-25)
Steps built: stage death record `lost_echo_names` (written once at the end of each fight in the combat-over branch of `_end_round`; the snapshot builder stays pure), `data.thread_whole` (always on a combat victory card), `data.objective_overcome` {index, type, label} (only when this fight overcame an objective), and the stipend row `lost`/`alive` from the union of the stage record and the last fight (so an earlier-fight death is not home). One place changes with permadeath: `ActiveStageService.lost_echo_names_with`.
MEASURED long run: `reward` 35/35, determinism 7/7, wider group 632/632, seek group: only the 7 seek drifts failed (baseline, roundtrip and maturity passed); 14 FINAL constants drifted, SAVE and ROUNDS held, `balance.json` and `git status` unchanged by the runs. Proof: removing the key `thread_whole` from `data_keys` of each of the 14 new payloads gives the old constant (14 of 14). Re-recorded.
Limits: a retreat does not record deaths; the record matches by display name; the `FlowRuntime` call is covered by direct-call tests only.

## D-102 — Combined-tree QA result and fixes (2026-10-25)
QA (`qa-verifier`, opus, HEAD b968eb3): no blocker; C4 (decisions against code and config) holds; C1 partial (see N1/N2); C2, C3, C6 partial because of two defects.
- **D1 (defect):** a quit and resume at the stage-ending card pays more than the card showed: `StageSettlementService._echo_home` (no encounter context after a reload) counts every active-party Echo as home and ignores the stage death record. Card "home 4 of 5, 58 Ase", paid 60. **Jeff: fix now** (step 5.12, backend).
- **D2 (defect):** the "carried home" panel never shows on a return home: `ReturnHomeModal` shows only when `result.success` is true, but the core writes `return_home_result` only on a failed escape (`VentureController.gd:386-390`). **Jeff: confirmation BEFORE the action, UI only:** the return-home button opens the panel first with `carry_home_preview` (already in the stage-explore snapshot), people safe, whether the stage waits; only "Confirm" dispatches `stage.return_home`. The payout UI session builds it; no core change.
- Notes taken: N2 (add per-mode re-record comments to `FlowFingerprintSeekTests.gd`; fix the stale "realm-virtue bonus" comment in `VentureCharacterizationTests.gd:247`) and N8 (follow-up 9 is stale: closed by D-72) go with step 5.12. N1 stands as accepted by D-35 and noted. N3, N4 (legacy snapshot key `ase_cost_per_summon` and four unread summon keys), N5 (hard-coded defaults, the 0.25 defeat factor), N6, N7 are follow-ups 29 to 32.

## D-103 — Final QA result and decisions (2026-10-25)
QA (`qa-verifier`, opus, HEAD 9cfd2e4): claims 1, 3 and 4 hold; claim 2 partly (F2, F3). Jeff's decisions:
- **F4 (stage death record):** **keep the full record until the stage clears.** A death stays on the stage record for every later visit; a stipend, "home N of M", rank cap and `thread_whole` all stay reduced. Reason (Jeff): after a death, the next visit must not give a full payout. Reset per visit was considered and rejected. Step 5.14 must check that the record is cleared when the stage is cleared, so a replay run does not inherit old deaths. If no code clears it, add the clear and test it.
- **F2:** route `echo_home_ase`, `echo_home_cap` and `echo_home_cap_replay` through `RewardCalc.cfg_num`. Fix.
- **F1:** the red `realm_ui` test (`EarningsSummary` width 0 in `ResolveScreen.tscn`). Fix (UI layout only).
- **F6:** remove `stage.confirm_return_home` (no UI sender) and the unreachable `return_failed` message. Fix.
- **F3 (ContactController literal 20, summon grade surcharge default):** not fixed; stays a follow-up.
- **F5 (confirmation copy when the escape can fail):** Jeff's wording; open. Not fixed.

## D-104 — Play test: early leave carries by a roll; a retreat goes back to the stage (2026-10-26)
Play test (Jeff): summon screen, escape result and failed-escape display are as wanted. Two changes:
1. **Early leave (return home and retreat) carries by a roll.** Outcomes: 0%, 50% or 100% of the gathered amount (completed objectives, same formula as D-72). **Odds (Jeff): 0% = 50, 50% = 30, 100% = 20.** Average carried share = 35%. Replaces the fixed 12% of D-72 rule 2. The advance rule stays: the final stage payout is reduced by what was carried, so nothing is paid twice. Reason (Jeff): Ase should not wait for the stage end when the party leaves early.
2. **A successful combat retreat returns the party to the stage map**, not to the Sanctum. The retreat keeps the 10 Ase cost, the denial when short, and uses the same carry roll.
Open for design (sr-game-designer, then Jeff): the roll stream and seed; what the confirmation panel shows when the figure is a roll; what the Resolve card shows for a 0% carry; what state the fight and the party keep after a retreat to the stage. Odds are config numbers (`data.rewards`), never hard-coded.

D-104 addendum (Jeff, 2026-10-26): the Resolve card does NOT show the percentage or the odds; they are not for the player to see. The card shows only the outcome in words: the party managed to take nothing, some, or everything back to the Sanctum. (Orchestrator's reading of "nothing less or everything": nothing / less / everything. The middle outcome is the 50% roll. Jeff to confirm the reading.)

## D-105 — The part the roll does not carry is lost for good (2026-10-26)
**Answer (Jeff):** an early leave settles the gathered objectives at once. What the roll (D-104) does not carry is LOST. It is not paid later when the stage is cleared. This reverses D-72 rule 2 (advance) for the share the roll drops; the "no double pay" rule stays.
Model to design (sr-game-designer, then Jeff): the objectives completed at the moment of leaving are SETTLED by the roll (0%, 50% or 100% of their value, paid now). A settled objective pays nothing more at the stage end. Objectives completed after the leave pay normally at the stage end. The stipend and the other stage-end rows are unchanged. Leave-then-return therefore pays at most what the roll gave for the settled objectives, plus the later ones.
Copy follows: the "still yours when the stage is done" lines in the D-104 design file are void. Player-facing wording is Jeff's.

## D-106 — Early leave and retreat: final rules (2026-10-26)
Source: `phase6-early-leave-design.md` (sr-game-designer) and Jeff's answers.
1. **Return home settles by the roll** (D-104 odds 50/30/20, D-105 real loss). One roll covers Ase and Ekwan. Scout: better odds, never above 100% (non-zero weights x1.5, renormalised; about 40/36/24). The weights are a tuning number; mid-game-designer authors the final weights.
2. **A combat retreat does NOT settle** (reopens and replaces D-104 item 2 for the retreat). It is a step back inside the same visit: nothing is paid or lost by the roll. The 10 Ase cost stays and the denial when short stays (D-79).
3. **A retreat returns the party to the stage map, shown on a short card with a "Back to the stage" button.** It uses ONE turn. Re-entry: a normal fight is marked passed (no instant re-entry); an objective fight can be entered again at once.
4. **The confirmation panel shows the gathered Ase and Ekwan amount, no odds.** Jeff's escape line stays.
5. **Settlement model (design file pick A):** per-objective `settled` mark and `settled_share`; stage `settled_ase`, `settled_ekwan`, `settle_count`; `carried_ase`/`carried_ekwan` removed (clean break, saves disposable); stage end pays only unsettled completed objectives plus the stipend; roll stream `stage.settle.<stage_id>.<run_count>.<settle_count>` drawn only after the escape succeeds.
6. **The Resolve card never shows a percentage or odds.** It names the outcome in words: nothing, some, everything. The player-facing wording is Jeff's: proposals only.
Open (BLOCKED in the design file, for the build to check): whether a replay rebuilds the objective dicts so `settled` marks reset; whether the retreat roll key `t` repeats after a reload; the retreat objective-fight rule needs the objective type on the situation.

## D-107 — Early leave and retreat copy chosen by Jeff (2026-10-26)
Source: `phase6-ux-copy-proposals.md`. The strings below are Jeff's words. The UI step uses them EXACTLY, with no edits (typos included: report them, do not fix them).
**Word rules (Jeff):** the word for what is not carried is **"lost"** (W1 = B). Avoid the word "home": use "Sanctum" or another word (the Sanctum is a village/community, not a building). Avoid the word "stage": it is internal game language; the player-facing word is **"path"**. W2 to W5 agreed: remove "Going home costs nothing.", remove the advance note, remove the `carried_advance` cause text, replace the "keeps a small part" causes.
1. Confirmation panel. Gathered line (option C): `In their packs: <Ase> Ase and <Ekwan> Ekwan.` Risk line: `Not all of it will survive the escape. What cannot be carried will be lost.` Keeps line: `The path still waits.` Escape line (D-103) stays.
2. Resolve card, return. Everything: `Everything got out` · Some: `Some of it got out` · Nothing: `Nothing got out.` · Nothing new: `Nothing was gathered since the last time.`
3. Stage-end ledger memo cause text: `These were already taken when the party left earlier.`
4. Retreat card. Title: `Pulled back` · Body: `Withdrawing. Back to the path.` · Button: `Leave` · Normal fight re-entry: `It's not smart to re-enter this quickly.` · Objective fight: `Our task is not done. This story is not over yet.`
Still open for Jeff: the row label on the return card and the memo row; the retreat button second line; and the older placeholder words that contain "home" or "stage": "Take the party home?", "Go home", "Stay", "Return Home" (title), "Carried home", "Settled when you left", "The stage waits." The typo in the normal-fight line.

D-107 addendum (Jeff, 2026-10-26): (a) The typo is fixed: `It's not smart to re-enter this quickly.` (b) The word rules apply to every old placeholder: no "home" (use "Sanctum" or another word), no "stage" (use "path"). Orchestrator applied them; the results are Jeff-authorised derivations: confirmation title `Return to the Sanctum`; question `Take the party back to the Sanctum?`; confirm button `To the Sanctum`; cancel `Stay` (unchanged). The row label "Carried home" is dropped: the return card shows the outcome line and the `+N Ase` / `+N Ekwan` lines only. The stage-end memo row label stays `Settled when you left`. "The stage waits." is replaced by `The path still waits.` The retreat button second line: `Uses a turn.` The "Retreat (10 Ase)" label is unchanged.
