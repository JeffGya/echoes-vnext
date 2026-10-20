# V2-ECONOMY-004 Part A, Phase 3b: design check (completed-only objective base)

Author: `sr-game-designer`. Read-only check. No code, config, GDD or Notion change.
Decision source: D-11. Notion addendum: "Calculate objective rewards only from objectives that were actually earned or completed under the stage contract."
Tree note: Phase 3a edits are already in the working tree (`RewardCalc.gd` has the `logger, t` parameters). All line numbers below are from that tree on 2026-10-20. Re-check them before the build.

Label rule: READ-FROM-CODE means I opened the file and read the line. INFERENCE means I reasoned from READ facts.

---

## 1. EVIDENCE

### Q1. Where does `completed` become true?

READ-FROM-CODE. The flag has a default of false: `ObjectiveModel.gd:68` (`make(..., completed=false, required=true)`).
It becomes true in exactly three places:

| # | Place | Event |
|---|---|---|
| A | `ActiveStageService.gd:582` (`resolve_combat_situation_and_objective`) | A combat-type encounter ends in victory and its situation has `is_objective` true. Called from `FlowRuntime.gd:1700` (pre-snapshot, in `_end_round`) and `FlowRuntime.gd:807` (`_apply_victory_return_to_explore`). |
| B | `VentureController.gd:622` (inline copy inside `handle_complete_stage`) | Same event, final-objective path. By then A has normally run already (`FlowRuntime.gd:1696-1700` runs before the final snapshot). |
| C | `ActiveStageService.gd:517` (`mark_stage_objective_completed`), called only from `ContactController.gd:581` | A "charge" NPC contact ends with outcome `good` on an objective-linked situation. |

Which objective types reach A:
- READ-FROM-CODE: `SituationResolutionService.gd:28` lists `combat, shrine, boss, recover, protect, endure, pursue, guide_spirit` as async objective types. `route()` (line 45-46) sends every `is_objective` situation to an encounter. None of them resolves in explore.
- READ-FROM-CODE: `EncounterSetupService.gd:858-870` picks a resolution mode per objective type (PURIFY_SHRINE, RECOVER, PROTECT, ENDURE, PURSUE, GUIDE_SPIRIT, else COMBAT).
- So: a combat objective won, a shrine purified, and recover / protect / endure / pursue / guide_spirit won in their own modes all set `completed` through A. The flag follows encounter VICTORY, whatever the mode.
- The comment at `ActiveStageService.gd:505` says "stub-completed types (recover/protect/endure/pursue)". That comment is stale. No code marks those types complete without a fight. The only non-fight caller is C, which is a contact outcome.

Not set by: a defeat, a retreat, a return-home, a dismissed or ignored situation (`stage.ignore_situation`), or a failed charge (`ContactController.gd:~590` abandons the stage).

The boss stub:
- READ-FROM-CODE: `RealmGenerator.gd:148-152` makes the boss objective with `required=false` at the last index.
- READ-FROM-CODE: `RealmGenerator.gd:278-284` and `:360-370` bind situations only to pre-boss objectives (`obj_count = mini(1 or 2, pre_boss_count)`). The boss has no situation.
- So `completed` is NEVER set on the boss. Today the boss weight is paid (60) for an objective that cannot complete. Under D-02 / D-10 the boss weighs 0, so the filter and the 0 weight agree. The completed-only filter also removes the boss on its own, even if a later change restores a boss weight before a boss story exists. Keep both.

### Q2. What can be incomplete at `flow.complete_stage`?

READ-FROM-CODE. The gate is `StageExploreSnapshotBuilder.gd:384-390`: `is_exploring and not has_pending and objectives_remaining == 0 and obj_total > 0 and objectives_found >= obj_total`.
- `objectives_remaining` counts objectives with `required` true and `completed` false (`:279-283`).
- `objectives_total` counts situations with `is_objective` true (`StageExploreModel.gd:46-50`). It does not count the boss, because the boss has no situation.
- `objectives_found` goes up when an objective situation is resolved. On the async path that is a combat victory (`ActiveStageService.gd:575`), the same event that sets `completed` (A).

Results:
- Required objective incomplete at settlement: NO, by the gate. `objectives_remaining == 0`.
- Optional objective (today only `pursue`) incomplete at settlement, when it has a situation: NO in practice. `objectives_found >= obj_total` forces every objective situation, optional ones included, to be resolved. Resolved on the async path means won, which means completed. `find_explore_target` Tier 4 re-offers a passed objective for this reason (`ActiveStageService.gd` Tier 4 comment; gate comment `StageExploreSnapshotBuilder.gd:376-377`).
- Objectives that CAN be incomplete at settlement:
  1. The boss. Always. Required false, no situation.
  2. Any pre-boss objective that has no situation. Not produced by the shipped realms. READ-FROM-CODE: `realms.json` gives `obj_count_max` 1, 2, 3 and `sit_count_min` 4 or 5. The generator forces at least 2 objectives, so pre-boss is at most 2. With `sit_count > 3` the generator binds 2 situations. If `sit_count_min` ever drops to 3 or less on a realm with 2 pre-boss objectives, one required objective has no situation and the stage cannot be finished at all. That is a generator hazard, not a payer rule. Report only.
  3. An old or edited save where a flag is out of step. INFERENCE only.
- Another READ-FROM-CODE point: the guide_spirit config says optional, the generator writes it required (`RealmGenerator.gd:145`, already in the Phase 3 proposal). Out of scope (D95).

So the D-11 filter, on the shipped content, removes exactly one thing at the stage payer: the boss. It will not visibly change the payout of a normal stage. The D94 gate, not the payer, is what makes `pursue` effectively mandatory. Jeff should know this (see OPEN B1).

Settlement entry: READ-FROM-CODE. `StageSettlementService.settle()` has one caller, `VentureController.gd:666` inside `handle_complete_stage`. It reads `stage_ref["objectives"]`, the live save dict (`StageSettlementService.gd:121-124`).

### Q3 evidence. Who reads the stage base today?

READ-FROM-CODE. Four readers share `RewardCalc.base_reward(all objectives)`:

| Reader | Where | Use |
|---|---|---|
| Stage payer | `StageSettlementService.gd:124` | The Ase paid at `flow.complete_stage`. |
| Partial payout, encounter retreat | `FlowRuntime.gd:1202` via `ActiveStageService.get_stage_base_reward` | `base x partial_intel_reward_factor (0.12)`, only if revealed situations > 0. |
| Partial payout, return home | `VentureController.gd:379` | Same, times the directive `intel_retention_bonus`. |
| Fight-start pace base | `EncounterSetupService.gd:739` | `combat_state.stage_base`. The pace bonus is a share of it. |
| `RewardCalc.compute` | `FlowEncounterState.gd:189` | `base` feeds the defeat consolation (`EconomyService.gd:169`, `base x 0.25`) and both sides of the rank ratio (`RewardCalc.gd` `max_possible` and `kept`). |

READ-FROM-CODE: `compute()`'s `base_reward` output is used only by the consolation (`FlowEncounterState.gd:229`). A victory does not pay it (`EconomyService.gd:121-123`).

Facts that decide the answer:
- F1. Order on a victory: the fought objective is marked complete BEFORE `RewardCalc.compute` runs (`FlowRuntime.gd:1696-1700`, then `build_final_snapshot`). So at rank time a completed-only base already includes the objective just won.
- F2. Order on a defeat: the fought objective is NOT complete. A completed-only base excludes it. On the first fight of a stage the base is 0, so the consolation is 0.
- F3. The pace base is read at fight START (`EncounterSetupService.gd:739`). The fought objective is not complete then. A completed-only base gives the first fight of every stage a pace base of 0.
- F4. A retreat or return-home happens before the fought objective completes. The completed-only partial for a first objective is 0. In realm.01 (one pre-boss objective), an encounter-retreat partial is always 0. The return-home partial is 0 until the single objective is won.
- F5. `completed` persists in the save across a return-home and re-entry (explore_map keeps situations; only transient fields reset, `FlowStageExploreState.gd:60-70`). So completed-only does not lose earned value when the party leaves and returns.

### Q4 evidence. Rank

READ-FROM-CODE (`RewardCalc.gd` compute): victory rank = `(base + kill_bonus + echo_bonus [+ pace]) / max_possible`, with `max_possible = base + enemies*5 + echoes*10 + max_pace`. Defeat rank = `(base x defeat_factor) / max_possible`.
- `base` is on BOTH sides of the ratio.
- INFERENCE: if `base` is replaced by the completed-only value on both sides, a skipped objective is absent from numerator and ceiling. It cannot lower the rank. Rank is per encounter, not per stage, so a skipped optional objective is never in a rank ratio at all unless it is the fight being ranked.
- INFERENCE: a smaller `base` makes imperfect play rank a little lower, because the fixed base cushions the ratio less (ratio `(B+k)/(B+K)` grows with B when k<K). Perfect play ranks the same. This is a re-record, not an unfairness.
- Hazard: if only the numerator were filtered and `max_possible` kept all objectives, a skipped optional would be punished. Do not split the two.

### Q5 evidence. Exactly-once and late completion

READ-FROM-CODE: `settle()` returns `{}` if `settlement_receipt.settled` is true (`StageSettlementService.gd:~108-118`), and stamps after paying. It is reached only through `flow.complete_stage`.
- Can the stage settle before an optional objective is later completed? Not on shipped content. The gate needs `objectives_found >= obj_total` and no incomplete required objective. Every objective with a situation is already complete (Q2).
- Hole that remains: an objective with no situation (the boss; or a pre-boss objective on a mis-authored realm) can never complete. It pays nothing under the filter. It is not "lost", because it was never reachable.
- After settlement the stage advances (`RealmService.advance_stage`). A completed stage is not re-entered in the same run. A realm re-run builds fresh stages with a new `run_count` (`RealmService.gd:17`). So there is no second chance to complete an optional objective on a settled stage.
- Acceptable? Yes, for the shipped content. If a future design makes optional objectives truly skippable (the gate stops requiring them), then a skipped optional objective pays nothing and cannot be completed after settlement. That would be a deliberate trade, and the result screen must say so (ANSWERS #64: the result states what earned it). That future design is out of scope here.

Other canon read: the GDD has no text on stage reward amounts or on objective payout (grep of the index and the stage section `1215-1306`: no "reward", no "optional" rule). ANSWERS.md has no answer on objective payouts; #64 asks that a result state its cause. GDD 20.10 (`lines 4020-4040`) says a failed run should still return intel and should be "learning rather than pure punishment".

---

## 2. RECOMMENDATION

### The smallest rule (Q6)

> The stage payer sums the weights of the objectives whose `completed` flag is true. An objective that is not complete adds 0.

That is all D-11 and the Notion addendum need. It adds no state, no field and no flow change. `completed` already exists, is already saved and is already read by the gate. The boss stays 0 by D-10, and the filter also keeps it out if its weight ever returns before a boss story exists.

### Per case (Q3)

Pillar terms used: Echoes are people; the player earns by what the party actually did; failure teaches (GDD 20.10); things feel hard to attain (D-04).

| Case | Recommendation | Reason |
|---|---|---|
| (a) Completed required objective | Pays its full weight at the stage payer. | The party did the work. Matches the Notion text. No change to what a normal stage pays. |
| (b) Completed optional objective | Pays its full weight. Same rule, no special case. | An optional objective should not need its own rule. Its weight is where "optional pays less or more" is decided (Phase 3 weights), not in the filter. |
| (c) Optional objective never reached | Pays 0. | This is the D-11 decision. On shipped content this case cannot occur at the stage payer (Q2), so the rule is a guard. See OPEN B1. |
| (d) Stage left by retreat or return-home | RECOMMEND the completed-only base for the partial payout, as the smallest consistent reading. Flag for Jeff (OPEN B2). | The partial is `0.12 x stage base`. If it stays on all objectives it pays for objectives the party never earned, which is the exact thing D-11 removes. If it moves to completed-only, it pays little or nothing on the first objective (F4): that cuts Ase (D-04 direction) but it also empties the Scout Carefully `intel_retention_bonus`. The intel itself is the reward at that point (GDD 20.10). Jeff must confirm this knock-on. |
| (e) Defeat consolation (`base x 0.25`) | RECOMMEND the consolation keeps reading the all-objectives sum, as a separate named read ("stake of the stage"), not the completed-only base. Flag for Jeff (OPEN B3). | A defeat never completes the fought objective (F2). With completed-only, the first defeat of a stage pays exactly 0, and a later defeat pays 25% of an EARLIER win. That silently removes a consolation Jeff called intended design (2026-08-24, `EconomyService.gd:107`) and it punishes the learning loop (GDD 20.10). Keeping the stake read preserves today's behaviour and today's recorded values. The consolation is not an "objective reward earned", so D-11 does not require filtering it. The hard-coded 0.25 stays out of scope (D-11). |

### Rank and pace (Q4 and F3)

1. Rank: use ONE base definition on both sides of the ratio. Either both completed-only or both all-objectives. Never split.
2. Smallest and safest: keep rank on the all-objectives base, so rank, the consolation and the existing rank fixtures do not move. Then a skipped optional objective cannot be punished, because it sits on both sides.
3. If Jeff prefers rank on completed-only (INFERENCE: lower ranks for imperfect play, one more re-record), it is also fair, because the base is on both sides.
4. Pace base (F3): do NOT use the plain completed-only read at fight start. The first fight of every stage would have a pace base of 0, so a pace bonus could never appear there. That breaks ANSWERS #64 (the goal must be visible before the fight). RECOMMEND the pace base = completed objectives plus the objective being fought (`active_encounter_objective_index`, which `EncounterSetupService.gd:~853` already reads in the same setup). This is a read of data that already exists, not a new mechanic. It is a small build item. Flag in OPEN B4 because it changes what a fixture records.

Net effect on the code (for `mechanics-developer`, not a build instruction): `RewardCalc` needs two named reads, "earned" (completed-only) and "stake" (all). Stage payer and partial payouts take "earned". Consolation and rank take "stake". Pace takes "earned plus the fought objective".

### Failure modes

- Player ignores objectives: cannot reach the payer; the gate blocks `flow.complete_stage` first.
- Player returns home before winning anything: partial pays 0 under (d). Intel is kept. The Scout bonus has no value until an objective is won.
- Standing 1: the party has no map-level withdrawal restrictions here; the earlier GDD rule (20.10) lets an uncalled Echo withdraw. At Standing 1 the first objective is the whole stage in realm.01, so the stage payout equals one objective's weight and the partial payout is always 0. At Standing 6 and 9 nothing changes in the rule; stages carry two objectives, so the partial after the first win is non-zero.
- Exploit check, repeat return-home: the partial has no stamp (existing behaviour). Under completed-only it pays less than today. The exploit is not closed and is not mine to close here. Report only (OPEN B5).
- Player who never reads it: sees a result line. Result copy must say what was paid for ("Cleared: <objective>"). No raw numbers or IDs are needed. UI wording is not decided here.

### Design pressure answers

| Question | Answer |
|---|---|
| Legible without an ID or raw number? | Yes if the result lists the objectives that paid. Needs a UI story. Not in Part A. |
| Survives a player who never reads it? | Yes. The rule is automatic. |
| Produces a decision or only a delay? | On shipped content it produces no new decision (Q2). It keeps a future skippable optional objective honest. |
| Interacts with fear and emotion? | No. It does not bypass them either. Fear/morale effects of a fight are unchanged. |
| Standing 1 / 6 / 9? | See Failure modes. No Standing dependency in the rule. |

### Deferrals

- D95 (guide_spirit required or optional): unchanged.
- Hard-coded 0.25 defeat factor: unchanged.
- A real "skip an optional objective" mechanic (the gate stops requiring it): not designed here. It needs its own story. This check shows the filter is ready for it.
- Boss payout: waits for a boss story (D-02).
- Ekwan: D-06 says Ekwan sums all objectives "like the Ase base". D-11 changes the Ase base. The Ekwan sum must follow the same filter, or the two rules disagree. See OPEN B6.

---

## OPEN — questions and assumptions

ASSUMED: The shipped realm content never leaves a pre-boss objective without a situation | WHY: `realms.json` has `obj_count_max` at most 3 and `sit_count_min` 4 or 5; the generator binds up to 2 objective situations when `sit_count > 3` (`RealmGenerator.gd:284`) | WRONG IF: a realm sets `sit_count_min` at 3 or less with 2 pre-boss objectives, or a save was edited. Then the stage cannot finish, and the filter would pay less than the player expects.

ASSUMED: "Completed" means the `completed` flag on the stage objective, set by encounter victory or a good charge contact | WHY: it is the only flag that exists, and the gate already reads it | WRONG IF: Jeff means "completed under the stage contract" as something richer (for example a completion quality or a Weave condition). Then the rule needs a new field.

ASSUMED: Phase 3a (weights, boss 0, unknown-type error) lands first as D-11 says, and the line numbers above still hold after it | WHY: the tree already shows 3a edits in `RewardCalc.gd` and `ActiveStageService.gd` | WRONG IF: 3a changes the function signatures again before 3b starts.

BLOCKED: B1. On shipped content the D94 gate already makes optional objectives (`pursue`) mandatory to settle a stage, so a "skipped optional objective" never reaches the payer. Is that what Jeff wants, or should optional objectives become truly skippable? | CHECKED: `StageExploreSnapshotBuilder.gd:376-390`, `ActiveStageService.gd` Tier 4, `RealmGenerator.gd:145-152` | NEED: Jeff's decision. If optional should be skippable, that is a gate change in a separate story. Phase 3b can still land as the guard.

BLOCKED: B2. Partial payout (retreat and return-home): completed-only (recommended, smallest), or another base? Under completed-only the partial for the first objective is always 0 and the Scout `intel_retention_bonus` has no effect until an objective is won. | CHECKED: `FlowRuntime.gd:1202`, `VentureController.gd:379`, GDD 20.10, ANSWERS.md (no answer) | NEED: Jeff. Alternative if he wants intel to pay: a fraction of the weights of objectives that were REVEALED (new read of `revealed` + `objective_index`; a small new rule).

BLOCKED: B3. Defeat consolation base: keep the all-objectives "stake" (recommended; unchanged behaviour), or completed-only (pays 0 on the first defeat of a stage), or the weight of the fought objective (new read)? | CHECKED: `RewardCalc.gd` compute, `EconomyService.gd:107-127,169`, `FlowEncounterState.gd:229`, `ActiveStageService.gd:335-340` | NEED: Jeff. The 2026-08-24 "intended design" decision does not say which base.

BLOCKED: B4. Pace base at fight start: completed plus the fought objective (recommended), or plain completed-only (pace bonus 0 on every first fight)? | CHECKED: `EncounterSetupService.gd:739`, `FlowEncounterState.gd:189-202`, ANSWERS #64 | NEED: Jeff (design) and `mechanics-developer` (confirm `active_encounter_objective_index` is set before `:739` runs; I read that it is read at `:~853` in the same file, not the call order).

BLOCKED: B5. Repeat return-home partial payout has no stamp, so it can pay again on each return. Existing behaviour, not caused by 3b. Report only. | CHECKED: `VentureController.gd:360-385` | NEED: Jeff to say which story owns it.

BLOCKED: B6. D-06 (Ekwan sums all objectives) conflicts in wording with D-11 (Ase counts completed only). Should the per-type Ekwan amounts follow the completed-only filter? | CHECKED: `decisions.md` D-05, D-06, D-11; `StageSettlementService.gd:129-135` | NEED: Jeff. Recommend yes, same filter, so one rule covers both currencies.

Findings outside this story (report only):
- Stale comment `ActiveStageService.gd:505`: "stub-completed types (recover/protect/endure/pursue)". No code does this.
- Generator hazard (ASSUMED line 1): a pre-boss objective can end without a situation if `sit_count` drops to 3 or less.
- Concurrent edits: the working tree changes while this check ran (3a). A build on this check should re-read the lines first.

Skills used: none loaded. The repo (AGENTS.md scope, canon-index, decisions.md, source) answered every question.
