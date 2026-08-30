# V2-INFRA-003 — Defect Ledger

**This document is a record of completed work. It is no longer a worklist.**

V2-INFRA-003 decomposed `FlowRuntime` (10,061 lines to 1,972), built the proof spine for the
opening session, and — as an explicit purpose of the refactor, not a side effect — found and
recorded every defect it walked past. This file is the account of what was found and what was done
about each item.

Ninety-seven identifiers were raised, `D01` to `D97`. **Every one has an outcome below.** Nothing
was closed by attrition. An entry left this register by being fixed, connected, deleted, disproved,
judged not a defect, or filed on a named story — never by being judged unimportant.

## How to read this

The ledger is in three parts:

| Part | What it holds |
|---|---|
| **A — The ledger** | One row per identifier, `D01` to `D97`, in numeric order. This is the authoritative outcome for each entry. |
| **B — Findings with no identifier** | Things this story proved that were never given a D-number: the manual-test findings, the combat controller decision, and the coverage truths. Each carries an owner. |
| **C — Deferred work, by owning story** | Everything handed on, grouped by the story that now owns it. |
| **D — The original register, preserved** | The working document as it stood, including the product owner's dated decision blocks. It is the evidence behind Part A. Its instructions are spent; do not act on them. |

Outcome vocabulary, used consistently:

| Outcome | Meaning |
|---|---|
| **Fixed** | Code changed. The row names the change, the commit or slice, and what moved in the recorded values. |
| **Connected** | A mechanic that had never run was turned on, one at a time, with a full suite run after each. |
| **Deleted** | Code or a field was removed. The row carries the proof it had no caller. |
| **Disproved** | The original claim was wrong. The claim is kept visible so nobody re-files it. |
| **Not a defect** | Real behaviour, confirmed intended by the product owner, or a documented characterization. |
| **Deferred** | Filed on a **named** story. No row says "later". |
| **Coverage gap** | A hole in the tests, not a defect in the code. |

"Recorded values" means the fingerprint constants in `tests/FlowFingerprintTests.gd` and
`tests/FlowSnapshotFingerprintTests.gd`, and the baselines in `tests/CombatBaselineTests.gd` and
`tests/VentureCharacterizationTests.gd`.

---

# Outcomes at a glance

Ninety-seven identifiers, `D01` to `D97`. The counts below sum to 97.

| Outcome | Count | Identifiers |
|---|---|---|
| **Fixed** | 57 | D02, D05, D07, D08, D09, D10, D11, D12, D13, D14, D16, D17, D22, D23, D24, D25, D26, D27, D29, D30, D31, D32, D33, D35, D36, D37, D38, D39, D40, D42, D43, D47, D48, D50, D51, D52, D53, D54, D55, D56, D58, D63, D67, D68, D77, D78, D79, D80, D82, D84, D86, D87, D89, D90, D91, D92, D94 |
| **Connected** | 3 | D01, D03, D04 |
| **Deleted** | 6 | D18, D19, D21, D81, D85, D88 |
| **Disproved** | 3 | D20, D34, D41 |
| **Reverted — the fix was wrong** | 1 | D46 (see Part A; found by the PR #61 review) |
| **Not a defect** | 6 | D15, D28, D44, D45, D49, D70 |
| **Deferred to a named story** | 13 | D06, D57, D61, D62, D64, D65, D66, D69, D83, D93, D95, D96, D97 |
| **Carried with no owner named** | 2 | D59, D60 |
| **Coverage gap, not a defect** | 6 | D71, D72, D73, D74, D75, D76 |

**The two rows that need a reader's attention are D59 and D60.** Both are real, both were left open,
and neither was given an owning story. The post-manual-test triage filed them under "owned by
another story" without naming one. They are recorded here plainly rather than assigned to a story
that was never asked to take them. See Part A and Part C.

## Where the work landed

| Stage | Commits | What it did |
|---|---|---|
| Half A and Phases 5 to 7 | `aa8147d` and earlier slices | Decomposition. Closed D21 to D26 as a by-product. |
| Phase 8A | `091bcfd` | Stage settlement. Closed D05, D36, D39, D77. |
| Phase 8 groundwork | `61ffcf8` | Closed D82, the `run_index` leak. |
| Phase 8B and 8C | `0e801f1` | Durable result and opening spine. Closed D42, D63, D86, D87, D88, D89, D90. |
| Pre-playtest batch | `e98a70b` | Nine hygiene and repair items. Closed D07, D08, D10, D11, D37, D38, D40, D48, D78, D81. |
| Connect pass, one mechanic at a time | `39cfbaf`, `df54fba`, `2bc1ec9`, `2d5d629` | D01, D04, D03, then D18 and D19. |
| Fix passes 1 to 10 | `f6b9a0c`, `7a91df6`, `c31d9d0`, `0cee9db`, `d0d5125`, `57f431b`, `e9bd152`, `bca31d7`, `fd0bedc`, `3ca76a8`, `99b319e` | The remaining open defects. |
| After manual test 2 | `4b27881`, `ff068ed`, `83a13dd`, `36e5d98` | D93 pinned and deferred, D94 fixed, D95 to D97 recorded. |

---

# Corrections that supersede earlier statements in this file

The register grew by accretion over six days. Where two statements conflict, **the later dated one
wins**, and the earlier one is named here rather than quietly dropped.

| Subject | The earlier statement | What superseded it |
|---|---|---|
| **D35 blast radius** | Graded **FP**. The row said producer B is fingerprinted, so adding `direction` and `tag` would move a fingerprint. | Pass 7, 2026-08-28: **it moved nothing.** `tests/FlowFingerprintTests.gd:238-244` hashes the sorted **top-level** `data.keys()`. `emotion_summary` was already one of those keys and the shape of its entries is not hashed, so adding two fields inside an entry cannot move the constant. |
| **D50 blast radius and premise** | Graded **FP + BL**, on the premise that PROTECT and PURIFY_SHRINE always carry a structure inside `party_size`. | Pass 5, 2026-08-28: **it moved nothing, and the premise was wrong.** All three authored structures carry `faction: "structure"` (`data.actor.structures`), so the existing `faction == "echo"` test already excluded them. The filter that actually bit was `is_spirit` (D51): a joined guide spirit is built as faction `"echo"` and inflated the count by one. |
| **D02 count** | "**Ten** leadership trait effects are authored with parameters nothing reads." | Pass 8, 2026-08-28: it was **eleven**. `directive_amplify` and `directive_echo` were also dead. The `directive_mul` grep hit that made `directive_amplify` look live is `calling_behavior.directive_mul`, a different config subtree. |
| **D62 owner** | First ruling, 2026-08-28: expand V2-STAGE-003, write no new story. The addendum was added at Order 310. | Same day, twice. The **twin rule** was applied — the database holds duplicate story codes, V2-STAGE-003 also exists at Order 236 with status Done, and when one twin is Done the other is not used. The addendum was removed and that page returned to its previous state. Thirteen open stories were then checked and each rejected with a reason. **Final: a new story, `V2-INFRA-007 — contact resolution consequence parity`, Ready, Order 262.5.** |
| **Number of disproved entries** | The conversion rule in this file said "**two** entries in this register were disproved". | Pre-playtest triage, 2026-08-27: **three** — D20, D34 and D41. |
| **Open count** | "The ~**53** after-the-test entries". | Post-manual-test triage, 2026-08-28: **44**, after four independent readers re-verified all 90 identifiers at `702608b`. Of the 44, 32 needed no product-owner decision and 12 did. |
| **D03 premise and blast radius** | "The `data.voice` bark budget block has no reader"; graded **BL** because `CombatBaselineTests` and the round-bark suites pin `round_bark_events`. | Connect case 3, 2026-08-28: **wrong on both counts.** The budget was not missing, it was **duplicated** as hardcoded literals in `ui/screens/combat/CombatBoardScreen._show_bark_popups()`, and the two copies had already drifted. And no suite pins `round_bark_events`; `CombatBaselineTests` contains no bark assertion at all. Nothing moved. |
| **D33 location** | The duplicate realm XP multiplier lives in `FlowEncounterState.gd`. | Triage, 2026-08-28: it had **moved** to `core/economy/StageSettlementService.gd:262-265`. Fixed there in pass 3. |
| **D73 status** | Phase 8B addendum, 2026-08-25: "**STILL OPEN** after slice 6J, and now load-bearing." | The assertion had in fact already landed in Half A. `git blame` puts `tests/OnboardingTests.gd:284-285` at commit `aa8147d`, 2026-08-24 — one day **before** the addendum that called it open. The 2026-08-27 closure is correct. |
| **D76 prediction** | `snapshot_purity/build_final_snapshot_pays_rewards` "will go silently vacuous" when payment moves. | Slice 6J, 2026-08-24: it goes vacuous only under an `_end_round` relocation, which was ruled out. Under the settlement move actually shipped it **fails loudly**, and that failure is the positive evidence the payment left the builder. Revised action: invert the assertion, keep the production drive. |
| **D79 shape** | The six duplicated placement copies differ in exactly two knobs. | Pass 4, 2026-08-28: **three knobs.** The five objective copies rank lexicographically by column distance then row distance; the temporary-ally copy ranks by summed Manhattan distance to the party centroid, a different total order. The metric became a fourth parameter so no cell moved. |
| **D30 completeness** | The pass 1 row implied every longhand `objective_modes` read was routed. | Pass 1 correction: the two `BehaviorArbiter` sites were **not** routed — they read a different subtree, `data.actor`. Raised as **D91** and fixed in pass 3. |
| **D66 owner** | "Owner disputed — the prompt says V2-ECONOMY-004; Notion says that story is the Ekwan loop." | 2026-08-25: a **false contradiction.** They are the same story; that page's `Code` property is `V2-ECONOMY-004`, and it already carried a 2026-08-11 addendum describing this exact `obj_type` / `type` mismatch. |
| **D07, D37, D38, D40 blast radius** | Each predicted **BL**. | Pre-playtest batch, 2026-08-27: the full suite was green with **zero** re-records. Not because the fixes were inert, but because the changed behaviour sits **outside recorded cover**. That is a real coverage gap, not a clean bill of health — three player-visible repairs landed with no test able to tell whether they worked. |
| **`death_round` scope** | D14 named one writer, `LiveHazardOutcomeService.gd:70`. | Pass 7: the field's documentation was wrong for **every** writer, and had been before this story. Corrected in the same commit at `core/actors/ActorSchema.gd:39` and `CONVENTIONS.md:307`. |
| **Register accounting** | "Identifiers run **D01 to D93**." | D94 to D97 were added 2026-08-29. The range is **D01 to D97**. |
| **Manual test 1 ruling on stalemates** | "A fight always reaches an end state — Echoes die, win state reached, or enemies die." Correct for its own case: enemies were still dealing 1 to 2 damage. | Manual test 2, 2026-08-29: damage floors at **0**, not 1 (`core/combat/CombatService.gd:126`), and there is **no round cap anywhere**. A fight in which every swing lands 0 and both sides refuse or guard has no reachable end condition. |
| **D84 instruction** | Product owner, 2026-08-28: run the bond hooks **and** the Thread contribution before the card, at encounter cadence. | Pass 9: correct for three producers, **wrong for the fourth**. `RealmService.contribute_segment` keys every entry by `stage_index` and `ThreadService` counts entries, so one segment per encounter would inflate a multi-objective stage's recovery. It was made idempotent with a receipt and contributed only on the stage-clearing fight. Half the instruction was deliberately refused, and the refusal is recorded. |

---

# Part A — The ledger

One row per identifier, in numeric order. **This is the authoritative outcome.** Where a row below
disagrees with anything in Part D, this row wins; the correction is named in "Corrections that
supersede earlier statements" above.

Commit references are real hashes on `claude/v2-infra-003-proof-spine-b3c770`.

## D01 to D33

| ID | Subject | Outcome | What was done, and what moved |
|---|---|---|---|
| **D01** | Near-death morale and fear read `max_hp` at the top level, so the trigger could never fire | **Connected** | Connect case 1 of 4, `39cfbaf`, 2026-08-27. `CombatTurnActionService.gd:310` now reads `stats.max_hp` with the `LiveMovementContextService` fallback idiom. Two authored keys became reachable: `morale_on_near_death: 7`, `fear_on_near_death: 8`. **Moved: 7 of 34 `CombatBaselineTests` emotion constants, and not one of the seven mode fingerprints.** COMBAT, ENDURE, PURSUE and PURIFY_SHRINE each move by one actor gaining morale 50 to 57 and fear +8, unscaled, once. RECOVER, PROTECT and GUIDE_SPIRIT are byte-identical. **Verified in manual test 1** (2026-08-28, `2d5d629`): near-death fired at `t:89`, `t:141` and `t:195`, all on enemies. |
| **D02** | Leadership trait effects authored with parameters nothing reads | **Fixed** | Pass 8, `fd0bedc`. **The count was eleven, not ten** — `directive_amplify` and `directive_echo` were also dead. All eleven implemented: `aggression_field`, `challenge_call`, `mark_target`, `safe_path_read`, `threat_read`, `hold_formation`, `position_lock`, `cover_positioning`, `anchor_presence`, `directive_amplify`, `directive_echo`. The two empty blocks were authored per the owner's decision: `cover_positioning` a move-score bonus toward cover, `anchor_presence` displacement immunity within a radius. **Nothing moved**, and the reason matters: no recorded scenario contains a Whole-band Echo, so no leadership trait activates in any fixture (see Part B). Each of the eleven was demonstrated by probe instead, with a with-and-without value. |
| **D03** | The `data.voice` bark budget block had no reader | **Connected** | Connect case 3 of 4, `2bc1ec9`, 2026-08-28. `ConfigService.get_voice_cfg()` plus `NarrativeVoiceService.apply_round_bark_budget()`, run on projected snapshot rows by both builders so their `_bark_line` purity holds. The UI's hardcoded cap and tier table were deleted; it keeps only ordering and sorts on the new `bark_priority`. **The premise was wrong** — the budget was duplicated in the UI, not missing, and the two copies had drifted. **Nothing moved**, and a probe across the full suite showed the cap has **never bound**: maximum barks ever offered in one snapshot is two, and zero reactions ever reach a projection. Suite 1500 to 1508. `ectx.round_bark_events` was deliberately not capped — it is a trigger queue, not a display stream. |
| **D04** | Mid-combat level-up synced stats to the wrong place and full-healed the actor | **Connected** | Connect case 2 of 4, `df54fba`, 2026-08-28. `ProgressionService.apply_mid_combat_kill_xp` now reads and writes through `actor["stats"]`, so `old_max_hp` is real and the unintended full heal is gone. Previously `old_max_hp` read 0, so `hp_gained` equalled the new maximum and every mid-combat level-up restored the Echo to full. **Verified in manual test 1**: level-up applied at `t:155`, Simon Mensah to level 2, with no free heal. |
| **D05** | A stage completed with no encounter paid nothing and was flavoured as a defeat | **Fixed** | Phase 8A, `091bcfd`. `VentureController.NO_COMBAT_GRADE = "C"`; settlement runs on `is_combat_victory or not has_encounter`. A stage cleared without a fight now pays and grades "compromised", recorded at the site as a judgement rather than a repair. This answered the product-owner question in code. |
| **D06** | Contact resolution runs none of the six post-encounter steps | **Deferred — V2-INFRA-007** | Cross-listed as D62; the same defect, filed once. See D62 for the ruling history. Owner: **V2-INFRA-007 — contact resolution consequence parity** (Ready, Order 262.5, depends on V2-INFRA-003). Emotion drift, bond triggers, sanctum emotion tick, vow discovery, vow release and ally teardown all still fail to run after a conversation. |
| **D07** | The scout-return party preview always showed a constant emotional status | **Fixed** | Pre-playtest batch, `e98a70b`, 2026-08-27. `VentureResolveSnapshotBuilder.gd:70-83` now reads the flattened `morale` and `fear` that `EchoActor.from_echo()` actually writes. This corrects the stored `save.flow.pending_result` copy for free. **Predicted BL; nothing moved** — the characterization test asserts the projection's key set, never the `emotional_status` value, so `get_emotional_status(50, 0)` was never pinned. Recorded as a coverage finding, not a clean result. |
| **D08** | The retreat RNG fallback used a different seed namespace from the primary path | **Fixed** | Pre-playtest batch, `e98a70b`. The missing `.` added to the fallback string at `FlowRuntime.gd:1166`. Unreachable in a booted campaign, so nothing moved. |
| **D09** | Wave reinforcements were silently placed at `{0,0}` when cells ran out | **Fixed** | Pass 6, `e9bd152`. Decision recorded at the site: **do not spawn what you cannot place.** The alternative fallback would have to pick a cell the placement rule already rejected. Dropping the spawn is recoverable — the next interval tries again on a board that may have opened. Both log `count` fields and `recover_reinforce_count` now report placed actors, not built ones. Not verifiable: no shipped seed reaches a nearly full board. |
| **D10** | `_double_damage_mult` was never cleared on totem recovery | **Fixed** | Pre-playtest batch, `e98a70b`. Now erased beside `_carrier_double_damage` on carrier-down recovery. Inert today because `CombatService` gates on the partner flag first; one gate-order change would have made it a live 2x damage bug. |
| **D11** | `_carrier_double_damage` was cleared only when the carrier dict was still findable | **Fixed** | Pre-playtest batch, `e98a70b`. The recovery branch was written as if actors can be removed from `ectx.actors`; the spine only marks `is_dead`. The guard's real premise is now stated at the site. |
| **D12** | Shrine drain used a sentinel key and an unfiltered rescan | **Fixed** | Pass 6, `e9bd152`. The fallback scan now filters `is_dead`, so a dead shrine's HP no longer leaks into later rounds' readouts. Only partly verifiable: the shipped path ends PURIFY_SHRINE on the round the shrine dies, so the changed branch is not exercised. |
| **D13** | The purifier cooldown and party morale drain were nested inside the shrine loop | **Fixed** | Pass 5, `57f431b`. Both hoisted out of the loop, per the owner's decision that they are **per round**. The answer came from the data, not from the owner: the authored keys are `purify_cooldown_rounds` and `morale_drain_per_wave`, both time-based; no authored key is expressed per shrine. **Fixed but currently unverifiable, recorded honestly:** no fixture has more than one living shrine, and a round never begins with a dead shrine, so the number of living shrines at drain time is always exactly 1. The fix removes a latent coupling; it changes no number until a mode ships two shrines. |
| **D14** | Guide-spirit hazard deaths recorded the sim tick as `death_round` | **Fixed** | Pass 7, `bca31d7`. Readers were audited first: `RecruitmentService.gd:378-381` divides `death_round` by `rounds_total`, so it needs a round, and every other writer already stores a round. The field name was right and the value was wrong, so `LiveHazardOutcomeService.apply()` now takes a `round` and writes it; all six call sites pass theirs. **The fault was schema-wide, not one site** — the two documents describing the field as a tick, `ActorSchema.gd:39` and `CONVENTIONS.md:307`, were corrected in the same commit. Nothing re-recorded. |
| **D15** | `_gs_spirit_pos` went stale in the protect branch | **Not a defect** | Pass 6, `e9bd152`. Investigated: after the protect move, no reader consumes the captured position. The skittish log reads `_gs_spirit.grid_pos` directly, the win counter builds a fresh copy, and the protect branch is the last code in the function. A refresh was added anyway, with a comment stating it changes nothing — it closes the trap for the next editor rather than fixing a live fault. |
| **D16** | An unrecognised `guide_mode` silently disabled the whole phase | **Fixed** | Pass 6, `e9bd152`. Warns on an unknown mode. Unreachable today: only two values are ever written. |
| **D17** | The escort win latch could fire on a spirit that never moved | **Fixed** | Pass 6, `e9bd152`. The fix went where slice 6I's investigation said it should — **the relaxation branch's floor, not the latch.** When no frontier cell clears `destination_min_distance` the producer relaxes with no distance floor at all, so on a terrain island with one unoccupied frontier cell the destination can equal the spawn cell. A `dist > 0` requirement was added and the branch falls through to no destination when even that fails. The latch was left alone: it is correct given a valid destination. Not verifiable — no shipped terrain reaches the relaxation. |
| **D18** | `title` — a dead snapshot key with zero consumers | **Deleted** | Connect case 4 of 4, `2d5d629`, 2026-08-28. **Proof of no caller:** `title` has no reader in `core/`, `ui/`, `tests/`, `tools/` or any `.tscn`; `ResolveScreen.gd` never names it, and the other `"title"` hits belong to unrelated snapshot types. Block 16 and all four producer calls deleted. **Moved: seven FINAL `data_keys` hashes re-recorded.** No ROUNDS hash and no SAVE hash moved. Attribution was measured, not assumed: the fourteen FP_DEBUG payloads were diffed field by field, and `data_keys` is the only field that differs anywhere — 24 keys to 23, the removal of `title`. |
| **D19** | `note` — a dead snapshot key with zero consumers | **Deleted** | Connect case 4 of 4, `2d5d629`. Same verification as D18: no reader anywhere, including scenes. Block 17, producer F's call and producer G's replay line deleted. **It moved nothing on its own** — `note` reached no fingerprinted producer. The seven FINAL hashes moved because of `title` alone. |
| **D20** | `verdict` written into a badge the screen always hides | **Disproved** | **Original claim, kept visible:** "`ResolveScreen`'s contact renderer sets `_rank_badge.visible = false` unconditionally", so the computed `verdict` is invisible on every contact resolve. **Evidence it was wrong, 2026-08-27:** `ui/screens/venture/ResolveScreen.gd:262-268` shows the badge whenever `verdict` is non-empty and hides it only when the string is empty. The "hidden unconditionally" claim describes the reset and clear paths at `:484` and `:512`, not the contact renderer. Product-owner decision 2026-08-28: **keep the badge.** No code change. Do not re-file this. |
| **D21** | `_find_target_situation` and `_mark_situation_revealed` — 114 dead lines | **Deleted** | Removed during Phase 5, before this register was compiled. **Proof of no caller:** grep for both symbol names returns nothing in `core/`, `ui/` or `tests/`, and the cited `FlowRuntime.gd` line ranges no longer exist — the file is now roughly 2,070 lines. Recorded so the deletion is attributable. |
| **D22** | `flow.select_stage` had a provisional owner | **Fixed** | Slice 6F. The blocking controller-to-controller call was removed and ownership moved to `core/progression/SkillLoadoutService.gd`. All 73 actions now have exactly one owner — the ownership stop condition for the story. |
| **D23** | Producer C emitted `meta.sim_tick`, tripping `assert(false)` | **Fixed** | Slice 5B. `FlowStateMachine._validate_snapshot()` asserts on a missing `t`. Three characterization tests were **inverted rather than deleted**, so the original intent stays visible. |
| **D24** | `_project_actor` mutated the actor it projected | **Fixed** | Phase 3. The probe assertion at `tests/FlowSnapshotFingerprintTests.gd:33` was inverted to "must not mutate". |
| **D25** | `_build_scout_return_snapshot` consumed its own one-shot inputs | **Fixed** | Slice 5B. Consumption moved to the dispatch closure, gated on `type == flow.resolve` **and** `data.run_type == "scout_return"`. Now at `core/runtime/FlowRuntime.gd:1094`. The guard was preserved deliberately in slice 5E. |
| **D26** | `_fresh_save_path()` deleted only the primary save artifact | **Fixed** | Slice 5.0. A leftover `.bak1` made `boot()` recover the previous campaign and produced nine false fingerprint failures. Fixed by `tests/TestSaveHarness.gd`, adopted by 22 suites. Recorded in the register as the highest-value fix of the story: it removed a source of fake regressions from every later measurement. |
| **D27** | The movement decision (`goal_id` / `option_id`) was never stored or logged | **Fixed** | Pass 7, `bca31d7`. **Superseding the 2026-08-25 filing to V2-COMBAT-003** — it was filed there, then fixed here because it turned out to need no new plumbing. The values were already on the activation result contract (`MovementResult`, built at `CombatActivationService.gd:235-236`), so `LiveMovementContextService.gd:502` simply logs both on `actor.moved`. Verified populated for an ordinary echo, not only a guide spirit. The superseded KNOWN GAP header on that file was deleted. **This unblocked D57**, which could not be safely investigated without it. |
| **D28** | `total_waves` frozen on the first ENDURE round | **Not a defect** | Pass 6, `e9bd152`. **Decision: keep the cache.** Both inputs live on `objective_params`, which is written once during setup, before any round runs, and never written after. Recomputing each round returns the same number. No code change; the comment now records the proof instead of calling it preserved behaviour. |
| **D29** | Roughly 60 duplicated placement lines including a determinism-critical sort | **Fixed** | Pass 6, `e9bd152`. **The instruction was deliberately refused as written.** The two blocks do not fit `GridService.place_on_terrain` from pass 4, and forcing them would have moved every wave spawn cell: the helper returns one cell ranked by distance to a target column, while these blocks hand out N cells ranked enemy-side-first by descending column — a different total order — and `GridService.occupied_cells` counts a dead actor's cell as occupied while these blocks treat it as free. Deduplicated locally instead, into one private `_place_enemy_spawns`, with the determinism-critical sort copied character for character. Nothing moved. |
| **D30** | `data.combat.objective_modes` had no `ConfigService` owner, read longhand at five sites | **Fixed** | Pass 1, `f6b9a0c`. `ConfigService.get_objective_modes_cfg()` plus a `_from_balance` variant added at `ConfigService.gd:308-330`; four production reads routed through it. **Correction to the original row:** the two `BehaviorArbiter` sites were **not** routed in this pass — they read a different subtree, `data.actor`, where the key does not exist. Raised as **D91** and fixed in pass 3. The stale `FlowRuntime.gd:2232` site was confirmed gone. Nothing moved. |
| **D31** | `data.combat.shrine` had no `ConfigService` getter | **Fixed** | Pass 1, `f6b9a0c`. `ConfigService.get_shrine_cfg()` added at `ConfigService.gd:333-345`; the one read routed through it. Nothing moved. |
| **D32** | `ConfigService.get_rewards_cfg` had no null guard, unlike its siblings | **Fixed** | Pass 1, `f6b9a0c`. `ConfigService.gd:281-282` now opens with `if config_service == null: return {}`, matching `get_economy_cfg`. Behaviour-neutral in practice: every caller passes a live service, and the previous code would have crashed rather than returned a different value. |
| **D33** | The realm XP multiplier formula was written twice from two apparent sources | **Fixed** | Pass 3, `c31d9d0`. **Proved identical before collapsing, not after:** same dictionary, same key, same rate, and every guard branch agrees, so the two "independent sources" were one source. The inline copy was deleted and the call routed to `ProgressionService.get_realm_xp_multiplier`. **Superseded location:** the register put the duplicate in `FlowEncounterState.gd`; by 2026-08-28 it had moved to `core/economy/StageSettlementService.gd:262-265`, which is where it was fixed. Nothing moved. |

## D34 to D66

| ID | Subject | Outcome | What was done, and what moved |
|---|---|---|---|
| **D34** | `STATE_ESCAPED` "written and never read" | **Disproved** | **Original claim, kept visible:** the handoff at `:270` recorded `STATE_ESCAPED` as a value written at `VentureController.gd:343` and read by nothing. **Evidence it was wrong:** `party_state` is read generically — `StageExploreTurnService.gd:119` gates `advance_turn` on it, `StageExploreSnapshotBuilder.gd:67/279/445` build from it, and `ui/screens/venture/StageExploreScreen.gd:602` renders it capitalised. What is true, and all that is true, is that **no code branches on `STATE_ESCAPED` specifically.** Downgraded to a note. The constant was not deleted. Do not re-file this. |
| **D35** | Producer B omitted `direction` and `tag` from emotion entries | **Fixed** | Pass 7, `bca31d7`. `EncounterSnapshotBuilder._build_keeper_intro_emotion_summary` now matches producer A exactly: same eight keys in the same order, `direction` from the pre-to-post emotional-status rank, `tag` as `ko` / `refused` / empty. **The predicted fingerprint move did not happen** — see the corrections table. Nothing re-recorded. **Raised and not fixed:** the D35 row claimed producer E "adds both plus `bark`". It does not — `SituationEngagementService.gd:352-362` emits a third, shorter shape with no `morale_delta`, no `refused`, no `bark` and a hardcoded empty `tag`. That is outside D35's scope and is recorded here so it is not lost. |
| **D36** | Quit at Resolve kept the reward but never advanced the stage | **Fixed** | Phase 8A, `091bcfd`, re-verified 2026-08-27. Payment left the snapshot builder. `core/economy/StageSettlementService.settle()` now runs in the same dispatch as `advance_stage`, behind a persisted `settlement_receipt` keyed per stage. No screen sits between payment and advance any more, so there is no window to quit inside. Re-checked independently against the fresh-stage case in Phase 8B: a realm generated at runtime carries no receipt key at all, and two `flow.complete_stage` dispatches aimed at the same stage pay exactly once. **Verified in manual test 1**: `t:155`, a single `stage_reward`, +90 Ase, with encounter rewards still paid per fight at `t:96` and `t:154`. |
| **D37** | The victory-return path could double-increment `objectives_found` | **Fixed** | Pre-playtest batch, `e98a70b`. The call site now passes `skip_if_already_resolved=true`. **Predicted BL; nothing moved** — the only test that drives this path asserts ally-field teardown and never `objectives_found`, and no test calls it twice. A coverage gap, recorded as one. |
| **D38** | The victory-return path committed, saved and logged even when nothing matched | **Fixed** | Pre-playtest batch, `e98a70b`. Same call site now passes `commit_only_when_modified=true`. One fix, two flags, with D37. Predicted BL; nothing moved, for the same coverage reason. |
| **D39** | `get_stage_base_reward()` read `objectives[0]` only | **Fixed** | Phase 8A, `091bcfd`. `ActiveStageService.gd:330` delegates to `RewardCalc.base_reward()`, so both base-reward readers now **sum** the stage's objective weights. This answered the product-owner question in code and removed a disagreement by construction: the retreat payout and the stage-completion payout had been computed on different bases. |
| **D40** | `RealmService.advance_stage()`'s idempotency guard **caused** Thread double-minting | **Fixed** | Pre-playtest batch, `e98a70b`. The already-completed guard returns `{}` instead of the model. Its one production caller reads `is_completed` off the returned dict as its Thread-mint trigger, so the guard no longer hands back a second reason to mint. **One deliberate recorded change:** `realm_prog/advance_idempotent_when_complete` had **pinned the defect** — it required the model back from the guard — so its assertion was inverted in `StageProgressionTests.gd`. That was the only re-record in the batch. |
| **D41** | A successful withdrawal was scored as a defeat | **Disproved** | **Original claim, kept visible:** handoff `:269` recorded that `_apply_run_emotion_modifiers` treats a withdrawal as a defeat. **Evidence it was wrong:** the `match outcome` block in `core/emotion/EmotionConsequenceService.gd:258-259` has a distinct `"withdrawal"` arm that sets `morale_mul = modifier_survived_morale_mul` — 1.25, a **boost**. `"defeat"` is a separate arm that sets `fear_mul`. The handoff line was also stale on location: the function moved off `FlowRuntime` in Phase 4. Do not act on the handoff line, and do not re-file this. |
| **D42** | The Ase Flame lit one full chapter early | **Fixed** | Phase 8C, `0e801f1`, 2026-08-27. **Fixed as a deletion, not a relocation.** `KeeperIntroService.awaken_flame()` already did the whole job idempotently at the intended beat, so the Chapter I copy was pure duplication and was cut. Every measured reader was walked before the cut and the consequence of a dark Flame for one more chapter recorded at the deletion site — including two the sending brief had listed as readers and which are not: `FlowSummonState` treats the flag as a rate hint only, so summoning is not gated by the Flame, and `SanctumLayoutService` does not read `awakened` at all. `tests/EconomyTests.gd` had pinned the **wrong beat**; it was inverted in place and renamed, with its original intent kept in its docstring. **No recorded value moved** — the predicted onboarding fingerprint move did not occur. **Verified in manual test 1**: flame not lit at name confirm; `t:30 Ase Flame awakened`. |
| **D43** | A KO could be visited twice in one loop, so fear spread might double-apply | **Fixed (defensively)** | Pass 6, `e9bd152`. **Could not be reproduced, and is provably impossible today:** `defender_hp_after` has one producer, reached only behind a `not target.is_dead` guard; that same call sets `is_dead` on any blow leaving HP at or below zero; each actor activates once per round; and `last_round_results` is cleared at round start. So one target id can appear at most once per round with HP at or below zero. A dedupe set was added because it is provably harmless — it can never fire on current producers — and the proof is recorded at the site. **No test was added**, because a test would pin a behaviour that cannot be produced. |
| **D44** | Kill ripple and kill momentum double-credit one ally for one kill | **Not a defect** | Product-owner decision, 2026-08-28: **intended as it stands.** Both apply, and the double ledger credit is part of the payoff for the trait the player invested in. No code change. |
| **D45** | The kill-share denominator excludes structures | **Not a defect** | Product-owner decision, 2026-08-28: **structures stay excluded.** A structure is an objective, not a party member; it does not earn, so it must not dilute. No code change. |
| **D46** | A melee attack on an already-dead target was logged as `actor.idle` | **Reverted — the fix was wrong** | Pass 5 changed this arm to `"melee_attack"`, reasoning that the log should name the intent. The PR #61 review found that wrong, and re-verification confirmed it. No attack happens on this path, and naming one has two live consequences: `ContributionLedgerService.gd:191` counts `melee_attack` into `melee_count` and `total_count`, which feed `melee_share` and so the courage virtue XP multiplier; and `CombatBoardScreen._format_action:962` renders it as **`Attacks ? (0)`**, because `target_name` is empty here. Reverted to `actor.idle`, which is what `main` does. The intent is already recorded by the `combat.attack_invalid_target` log line. **The suite cannot see this path** — 1,519 passed both before and after the revert, so the green suite is not evidence. |
| **D47** | The morale-drain log reported the configured amount, not the applied amount | **Fixed** | Pass 5, `57f431b`. The summed applied delta is logged. `apply_morale_loss` can reduce or fully prevent the loss and the clamp absorbs more, so the old line overstated the real drain whenever a leader was nearby — and misled every balance investigation that read it. Nothing moved. |
| **D48** | The contribution ledger read `last_round_results.back()` without checking `source_id` | **Fixed** | Pre-playtest batch, `e98a70b`. The ledger now checks the entry's `source_id`, matching the `last_actor_action` stamp that reads the same entry. Correct before and after; the two neighbouring blocks no longer disagree about whether the check is needed. |
| **D49** | The support tally is erased for non-echo actors without being read | **Not a defect** | Pre-existing and deliberate: support metrics are documented as an echo-only signal. Recorded because the erase and the gate are easy to misread as a bug. The note is the fix. |
| **D50** | `party_size` counted structures and temporary allies | **Fixed** | Pass 5, `57f431b`. **Both the premise and the blast radius were wrong** — see the corrections table. Structures were already excluded by `faction == "structure"`; the filter that actually bit was `is_spirit`, a joined guide spirit built as faction `"echo"`. Nothing moved. **Raised and not fixed:** `party_size` still counts temporary allies (`is_ally`). Whether a one-battle companion counts toward the `tikoro_nko_agyina` vow gate is a design question, not a defect. Recorded in the file header. |
| **D51** | Spirit-flagged echoes received mode directive weights outside GUIDE_SPIRIT | **Fixed** | Pass 5, `57f431b`. The `is_spirit` filter added to the other four branches for symmetry. This was the filter that actually mattered for D50. |
| **D52** | `round_bark_events` was passed by reference but documented "read-only" | **Fixed** | Pass 3, `c31d9d0`. Now passes a shallow duplicate. Chosen over a comment because the array is small and per-round, so the copy is cheap, and the named risk is a consumer appending to the caller's array. Nothing moved. |
| **D53** | The mode-directive block re-read config instead of the `balance` dict handed in | **Fixed** | Pass 1, `f6b9a0c`. Now `ConfigService.get_objective_modes_cfg_from_balance(balance)` — one read, of the dict the caller already passed. Same immutable object in production, so nothing could differ and nothing moved. |
| **D54** | `fear_inflicted` was credited to the attacker on same-faction hits | **Fixed** | Pass 5, `57f431b`. Unreachable today — no same-faction melee exists — so nothing moved. |
| **D55** | A `round` parameter shadowed the built-in `round()` | **Fixed** | Pass 3, `c31d9d0`. Renamed `round_number` at both sites, which is the project's existing name. **Raised and not fixed:** four other files still use `round` as a parameter name. Out of pass scope, recorded so it is not lost. |
| **D56** | `_ally_killed_barked` was an ad-hoc string key where its sibling is a typed field | **Fixed** | Pass 5, `57f431b`. Typed. **Raised and not fixed:** `_spirit_killed_barked` and `_spirit_greeted` (`CombatRoundGuideSpiritService.gd:195,204`) are the same undeclared-latch shape. Out of pass scope. |
| **D57** | Movement adapter criterion 5 orders cells by lexicographic `"col,row"` | **Deferred — V2-COMBAT-003** | `"10,3" < "9,3"`, so the induced order is jagged, non-monotone in either axis, and flips its favoured compass direction with coordinate magnitude — on ordinary input, since the header's original "id-less entries are rare" justification was explicitly withdrawn. **D27 unblocked it** by logging the movement decision, which is what makes the re-record auditable. Not fixed here: party movement paths are pinned, and the movement family belongs to **V2-COMBAT-003** (filed 2026-08-25). Fix by comparing `(col, row)` numerically. |
| **D58** | `_mark_save_requested()` joins reasons with a pipe across dispatch boundaries | **Fixed (comment only)** | Pass 3, `c31d9d0`. A save queued outside a dispatch glues its reason onto the next one. **Deliberately not fixed with an assertion:** `FlowContext` has no in-dispatch flag, and adding one plus an assertion is a behaviour-adjacent change against a baseline this pass was not authorised to move. The contract is now written at the site. Latent — no controller queues a save outside a dispatch today. |
| **D59** | `encounter.advance` has no phase guard; `encounter.complete` transitions from any state | **Carried — no owner named** | **Still open at `e8c89f4`, and verified so for this ledger:** `FlowRuntime.gd:448-453` guards `encounter.advance` only on "encounter not initialized", not on phase, and `encounter.complete` at `:462-470` transitions to RESOLVE unconditionally. Both are dispatchable out of phase and are pinned by `CombatBaselineTests` as the two dormant actions no test had ever dispatched. Reachability is **unknown** — the UI may never surface them out of phase; the risk is state corruption through debug or automation. The post-manual-test triage grouped it under "owned by another story" **without naming one**, and no Notion filing was made for it. It is recorded here unassigned rather than pushed onto a story that was never asked to take it. |
| **D60** | The flow machine never transitions to RESOLVE at the end of combat | **Carried — no owner named** | **Still open at `e8c89f4`, and verified so for this ledger:** `FlowRuntime.gd:1591` still writes `flow_ctx.last_snapshot = final_snap` directly inside `_end_round`. Phase 8B made `FlowResolveState` a real state and added RESOLVE transitions on three other paths (`:313`, `:470`, `:1201`), but **not on the combat-end path**, which is the one this entry names. No player-visible effect; it is the architecture defect that blocks `FlowResolveState` from ever owning the combat resolve, and the reason producer F exists as a fallback at all. Same accounting problem as D59: filed under "owned by another story" with no story named. Recorded here unassigned. Related, and separately filed: **D69**, the combat controller decision, went to V2-COMBAT-004. |
| **D61** | `InstitutionService.run_settle_tick` asymmetry | **Deferred — V2-SANCTUM-004** | `update_condition` and `apply_institution_modifiers` run only when `inst_cfg` is non-empty, while `apply_passive_effects` runs whenever `hours_elapsed > 0`, so institutions accrue passive effects while their condition never degrades. Filed 2026-08-28 on **V2-SANCTUM-004** (Order 340, Ready), the only open story that owns house condition as a runtime layer. **The filing added a scope line** for authoring the first institutions' passive values and their upkeep — that item had sat with V2-SANCTUM-002, which Notion now marks Done, so it was otherwise orphaned. The strain warning surface stays with V2-SANCTUM-005. No property on the page was changed; its Superseded twin at Order 239 was not touched. |
| **D62** | Contact resolution runs none of the six post-encounter steps | **Deferred — V2-INFRA-007** | The largest player-facing item left open, and the one whose ownership took three rulings in one day. **First:** expand V2-STAGE-003, write no new story; the addendum was added at Order 310. **Then the twin rule was applied** — the database holds duplicate story codes, V2-STAGE-003 also exists at Order 236 with status Done, and when one twin is Done the other is not used. The addendum was removed and Order 310 returned to exactly its previous state, every property unchanged. **Then a new story was authorised, conditionally**, and thirteen open stories were checked and each rejected with a reason: V2-INFRA-005 (death ripple only), V2-INFRA-004 (before the stage, not after), V2-SANCTUM-005 (generates house events, does not own who calls the tick), both V2-INTEL-002 rows, V2-COMBAT-003 and V2-COMBAT-004 (both stop at Resolve), V2-STAGE-002 (generation, not consequence), and six Draft stories owning content breadth or authoring vocabulary. **Final: `V2-INFRA-007 — contact resolution consequence parity`, Ready, Order 262.5, depends on V2-INFRA-003.** Four properties were left empty rather than guessed. The two stale `ContactController.gd` comments naming the never-built `EncounterResolutionService` now name V2-INFRA-007 instead (`d0d5125`). |
| **D63** | Ase Flame lights a chapter early (cross-listing of D42) | **Fixed** | Phase 8C, `0e801f1`, with D42. The finding is written at D42. Kept here so the cross-listing does not read as still open. |
| **D64** | The 28-function live movement family, moved verbatim | **Deferred — V2-COMBAT-003** | Filed 2026-08-25. The extraction was behaviour-preserving by construction; **V2-COMBAT-003** owns the behaviour. The register's own count was corrected in place: 28 functions, not 26 or 25 — 20 `_movement_*` plus 8 others including three `_apply_live_*`. |
| **D65** | The guide-spirit mover, moved verbatim | **Deferred — V2-COMBAT-003** | Filed 2026-08-25. A 231-line block; extraction only, no behaviour change. |
| **D66** | Reward resolution reads `obj_type`; objectives store `type` | **Deferred — V2-ECONOMY-004** | Objective-specific weighting falls through to the default combat path. Filed 2026-08-25 on **V2-ECONOMY-004**. The recorded "owner disputed" note was a **false contradiction**: the prompt's V2-ECONOMY-004 and Notion's Ekwan loop are the same story — that page's `Code` property is `V2-ECONOMY-004`. Better, the page already carried a 2026-08-11 addendum describing this exact mismatch and already drew the boundary: keep exactly-once payout orchestration in V2-INFRA-003; that story owns reward vocabulary, weights and the Ase/Ekwan split. The boundary was honoured — this story built the orchestration and changed no reward value. |

## D67 to D97

| ID | Subject | Outcome | What was done, and what moved |
|---|---|---|---|
| **D67** | `make_new_save()` wrote a directive value the repair immediately rewrote | **Fixed** | Pass 2, `7a91df6`. **The order was load-bearing and was followed:** the schema default was fixed first, then the migration removed. `SaveSchema.gd:137` now writes `directive.scout_carefully` — the default every consumer already falls back to — and the `directive.none` to `directive.seek_signs` branch was deleted from `SaveService.gd`. A `directive.none` value now falls to the unknown-id branch and is reset to `scout_carefully`. **Behaviour moved:** the repair ran on every load, so an existing campaign's first stage effectively ran `seek_signs`; it now runs `scout_carefully`. **Two new-save fingerprints re-recorded, both explained.** This change **exposed D92**. |
| **D68** | `CONVENTIONS.md` claimed debug actions run at `t = -1` | **Fixed** | Documentation pass, `d0d5125`. False: `dispatch()` computes one tick per action for every branch, via `_next_tick()`. Corrected at `CONVENTIONS.md:1095`. **The neighbouring claim at `:1121` is true and was left alone** — `debug.cmd.in/out/err` really are logged at a literal `-1`, from `ui/AppRoot.gd:362-368`; they are log lines, not dispatched actions. Two stale code headers were corrected in the same commit: the `VentureController` header, which contradicted the code beneath it about `flow.select_stage` ownership since slice 6F, and the two `ContactController` comments naming the never-built `EncounterResolutionService`. |
| **D69** | `_resolve_next_actor` cannot become a controller | **Deferred — V2-COMBAT-004** | Filed 2026-08-24, with **all three blockers measured** and recorded on the story page. See Part B for the full decision, including the correction made to that story's own 2026-08-11 audit addendum, which told its implementer to wire `ProtectCustodyService` through a controller that does not exist. |
| **D70** | `_end_round` cannot be reduced below 139 lines | **Not a defect** | Closed. "There is no further phase to extract. Do not chase it lower." Recorded so a later reader does not reopen it. |
| **D71** | Producer F has no test anywhere in the repo | **Coverage gap — still open** | Re-verified for this ledger: a repo-wide search of `tests/` for `FlowResolveState` returns nothing. Called "the weakest point of the slice" in the handoff. D19 deleted a key from this untested producer, guarded only by the fingerprints. |
| **D72** | `SnapshotContractTests` has no `flow.resolve` case | **Coverage gap — still open** | Re-verified for this ledger: `grep -c "flow.resolve" tests/SnapshotContractTests.gd` returns 0. The product owner did not approve adding it in Phase 5. This is exactly the gap that let D23 survive. |
| **D73** | Nothing asserted that producer B **omits** `ekwan_awarded` | **Coverage gap — closed** | Closed by the assertion at `tests/OnboardingTests.gd:284-285`, which rejects a keeper-trial resolve payload carrying `ekwan_awarded` and requires `ase_awarded`. **A dating conflict, resolved:** the Phase 8B addendum of 2026-08-25 called this "STILL OPEN and now load-bearing"; `git blame` puts the assertion at commit `aa8147d`, 2026-08-24 — a day earlier. The 2026-08-27 closure is correct and the addendum was already stale when written. The omission that block #8 depends on is now pinned. |
| **D74** | `initiative_order` and `total_waves` are outside fingerprint cover | **Coverage gap — still open** | Re-verified for this ledger: neither appears in `tests/FlowFingerprintTests.gd`. Guarded only by `combat_baseline` and `objective_combat`. |
| **D75** | 48 of 73 actions have no test coverage | **Coverage gap — count never re-measured** | Recorded as unverified and it stays unverified. Slices 5.0 and 6.0 added coverage, so the number is almost certainly stale in the safe direction. Anyone who needs the real figure must re-measure it; do not quote 48. |
| **D76** | `snapshot_purity/build_final_snapshot_pays_rewards` would go silently vacuous | **Coverage gap — claim corrected** | Corrected at the site during slice 6J. It goes vacuous only under an `_end_round` relocation, which the decisions block ruled out. Under the settlement move actually shipped, the probe **fails loudly**, and that failure is the positive evidence the payment left the builder. Revised action, recorded: invert the assertion to "must not mutate" and keep the same production drive. A direct `build_final_snapshot()` call would be weaker, because it could not observe the dispatch boundary that is the whole point of the fix. |
| **D77** | The full stage reward was paid at **every** encounter resolution, victory or defeat | **Fixed** | Phase 8A, `091bcfd`, verified 2026-08-27. The root mechanism behind D36. The two payments are now distinct functions: `EconomyService.reward_encounter_complete()` per encounter, `settle_stage_complete()` once per stage. **The 25% defeat consolation stayed** — product-owner decision, it is intended design — and is stamped once per situation by `ActiveStageService.claim_situation_defeat_consolation()`, which writes `consolation_paid` and returns true only on the first defeat. **The situation stays unresolved after a defeat**, so a lost fight is still retryable and no longer payable twice. That was explicit in the decision: removing retryability would have been a design change nobody asked for. |
| **D78** | The Android Back button quit the app from any screen | **Fixed** | Pre-playtest batch, `e98a70b`. `application/config/quit_on_go_back=false` plus a `NOTIFICATION_WM_GO_BACK_REQUEST` handler in `ui/AppRoot.gd`. Back dispatches the live snapshot's own `nav.back` action when it has one, is swallowed while a blocking modal is up, and otherwise does nothing. **It can never quit and can never reach a state a tap could not.** Moved no recorded value. |
| **D79** | The depth-scaled placement routine was written out six times | **Fixed** | Pass 4, `0cee9db`. Collapsed to `GridService.place_on_terrain`, with **every copy's values preserved exactly** per the owner's decision — the target column and row reference became parameters, PURSUE keeping the party centroid and the other five the board midpoint. **Correction to the original row:** the six copies do not share one comparator. The temporary-ally copy ranks by summed Manhattan distance to the party centroid, which orders cells differently from the five objective copies' axis metric, so the metric became a fourth parameter rather than a forced unification. **Nothing moved.** All six paths were captured before and after, and the two ordered captures are identical line for line. |
| **D80** | GUIDE_SPIRIT escort on a legacy board got destination `(-1,-1)` and could never complete | **Fixed** | Pass 6, `e9bd152`, per the owner's decision: **use a board-edge cell when terrain is absent**, so the escort stays available and the objective is completable on every board. **Determinism checked, not assumed:** no existing draw moved. The spirit-destination generator is per-encounter and freshly derived, boards with terrain take the identical path, and the new draw happens only on a legacy board where none happened before. Not verifiable — reachable only through `dev_combat_objective` with no active realm. |
| **D81** | The offline-accrual dormant gate was evaluated twice, the second unreachable | **Deleted** | Pre-playtest batch, `e98a70b`. **The second, unreachable gate deleted, with its `economy.offline_guard` save.** Proof it had no reachable caller: the two predicates are semantically identical, and the inline one runs first and returns, so the second can only be reached when the first already passed. **The direction of the delete was load-bearing** and is recorded: the inline gate survives because it leaves `last_offline_unix` and `last_settle_unix` alone; the dead one rolled them forward and would have swallowed the accrual window the awakening is supposed to open onto. Anyone who had "tidied" this by deleting the inline gate instead would have changed behaviour silently. |
| **D82** | `prologue.first` inflated `run_index` for every player | **Fixed** | `61ffcf8`, folded into the Phase 8 settlement bundle because it moves the same numbers. `KeeperIntroService` wrote `save_data["realms"]["prologue.first"]` with **no `status` key**, and `RealmService._count_started_realms` counts any entry whose `status != "not_started"` — an absent key reads as `""`, which passes. So every player who completed the keeper intro entered their first real Realm with `run_index = 1` instead of `0`, inflating the virtue bonus, the reward order multiplier and the realm XP multiplier. Live before this story, not caused by it. Verified by the orchestrator directly, not only by an agent. |
| **D83** | `ekwan_shrine_multiplier` has never applied | **Deferred — V2-ECONOMY-004** | The same root cause as D66 at a second site: `StageSettlementService.gd:145-150` and the identical read in `FlowEncounterState.gd:186-191` both do `objectives[0].get("obj_type", "combat")`, but `ObjectiveModel.make()` writes `type`, never `obj_type`. So `data.rewards.ekwan_shrine_multiplier` has no effect anywhere and shrine stages pay the ordinary Ekwan factor instead of the authored 1.5x. Carried verbatim by Phase 8A rather than fixed, so the settlement split stayed attributable. Filed 2026-08-25 on **V2-ECONOMY-004**, to be fixed with D66 in one change and re-recorded once. **The two sites must move together**, or a shrine stage's per-encounter and per-stage Ekwan would disagree. |
| **D84** | A run's bond and Thread consequences did not exist when its Resolve card was published | **Fixed** | Pass 9, `3ca76a8`, **with half the product owner's instruction deliberately refused.** Three of the four producers were already at encounter cadence, split across two sites, both after the card: `apply_combat_bond_triggers`, `apply_bond_aftermath_modifiers` and `seed_rival_stage_incidents` all moved into `_end_round()`, after `build_final_snapshot()` so the bark ordering is unchanged. **The fourth was refused:** `RealmService.contribute_segment` keys every entry by `stage_index` and `ThreadService` counts entries, so a per-encounter contribution would inflate a multi-objective stage's recovery. It was made idempotent with a receipt — **no new save key, the recorded `stage_index` is the stamp** — and contributed only on the stage-clearing fight. The `VentureController` call stays at stage cadence because it is still the only contributor on the no-encounter path (D05). Pinned by `pending_result/bond_and_thread_are_on_the_card`, which fails against the pre-change core. **A resume bug was fixed as a side effect:** a stage-clearing victory resumed from the card had been graded `NO_COMBAT_GRADE` ("compromised") because `encounter_ctx` was gone. **A dead arm was found:** the `"loss"` arm in `handle_complete_stage` can never run, because a defeat card offers no `cta.next_stage`. Nothing re-recorded. |
| **D85** | `save.flow.state` was defaulted, validated and repaired but written by nothing | **Deleted** | Pass 10, `99b319e`, by product-owner decision. **Proof of no caller, established before deleting:** every reference was found and classified — the schema default and the repair were the only two writers, the validator rejected a save for missing a field it also defaulted, one comment mentioned it, and six test fixtures set it without reading it. No reader of `state` or `context` exists in `core/`, `ui/` or `tests/`. **`flow.context` was removed with it** — same shape, same two writers, no consumer; keeping one half of a dead pair would leave the same trap. **Backward compatibility was proved, not assumed:** `SaveService.validate()` is a required-key whitelist with no unknown-key rejection, pinned by `bridge/legacy_flow_state_context_still_loads`. Nothing re-recorded. The `stage_id` half of this entry had already been closed in Phase 8B, locally in `PendingResultService.restore_run_context()`, deliberately not by widening `boot()`. |
| **D86** | The awakening modal had never rendered | **Fixed** | Phase 8C, `0e801f1`. The whole chain existed and was correct end to end; the only production write to `FlowContext.pending_awakening_banner` was `= false` in the consume closure, so the flag was never true and `modal_requested` never fired. `OnboardingController.handle_awakening` now sets it at the awakening rite, and the established consume gate carries it across the two intervening dispatches onto the first Sanctum snapshot. **Why it survived:** it was pinned only by a test that set the flag by hand — the tests proved the plumbing and nothing proved the arming. No recorded value moved. |
| **D87** | The awakening modal promised "+40 Ase" that no code has ever paid | **Fixed** | Phase 8C, `0e801f1`, **by removing the claim, not by paying it.** `awakening_ase_grant` has no consumer anywhere — the same authored-but-unreachable shape as D01 to D04 — and the moment D86 armed the modal it would have told every player it had granted money it had not. The grant label is deleted from the modal scene and from `present()`. **The grant itself is deferred to V2-ECONOMY-002** and `awakening_ase_grant` stays unreachable. `data.awakening_grant` was deliberately left on the snapshot: removing it would move the recorded `flow.sanctum` key set for no gain. |
| **D88** | Two copies of the awakening modal, one dead, both carrying the same body string | **Deleted** | Phase 8C, `0e801f1`. **Proof it had no caller:** the legacy `%AwakeningOverlay` was permanently disabled in `_ready` and nothing re-enabled it, and a repo-wide grep for `AwakeningOverlay`, `AwakeningTitle`, `AwakeningBody`, `AwakeningGrantLabel` and `AwakeningDismiss` returns only `AwakeningModal.tscn` and two test lines that instantiate the **live** modal. The node block and all four `.gd` references were deleted with the reason recorded in place. Its only remaining effect had been to hold a second copy of the modal's copy where an edit would touch one and miss the other. |
| **D89** | The opening Realm did not exist; its two save fields were read and written by nothing | **Fixed (built)** | Phase 8C, `0e801f1`. `realm.prologue` is a real one-stage generated run created from `keeper_intro.complete`, unlocked by **awakening plus first Weave**, carrying the player's own starter virtue — passed as a `cfg_overrides` argument because the virtue differs per campaign and cannot live in `realms.json`. `flow.select_realm` is validated against the gate. **A divergence from the GDD is recorded deliberately:** GDD §20.7 puts the second summon before the opening Realm; this does not, because that ordering depends on an awakening Ase grant that does not exist (D87) and 40 Ase against a 60 Ase summon cost would stall the arc at its first beat. **Do not "fix" it back before the grant ships.** No recorded value moved. **Verified in manual test 1**: opening Realm unlocked at `t:31`, prologue complete and normal Realms open at `t:155`. |
| **D90** | The prologue Realm needs a second predicate; `is_realm_run()` does not cover it | **Fixed** | Phase 8C, `0e801f1`. D82's predicate discriminates on the `status` key because `prologue.first` is a synthetic container that was never played; `realm.prologue` is the opposite — a genuine run the player really plays, which must pass `is_realm_run()`. What makes it special is that it is not one of the player's Realms. Excluded at **six** sites, each annotated in place with why: the `run_index` count, the one-active-Realm lock, the Vow "realm in progress" scan, the `runs_at_pledge` counter, the consequence-pass intel group, and `boot()`'s `realm_id` restore, where it is restored explicitly from `opening_realm_status` instead so a real Realm always wins and the prologue stays resumable. **A correction to the slice brief is recorded:** the Sanctum enter-stage enablement is deliberately **not** excluded, because that is the affordance the player uses to enter the prologue. Without this, every player's first real Realm would have gone to `run_index = 1` again, by a different door. No recorded value moved. |
| **D91** | `BehaviorArbiter` read `objective_modes` off `data.actor`, where the key does not exist | **Fixed** | Raised during pass 1, fixed in pass 3, `c31d9d0`. Both `has()` guards were always false and both values fell through to hardcoded defaults of 3. The authored values are also 3, so nothing differed in play — but retuning either number in `balance.json` would have done nothing. Fixed by passing the subtree through the `context` dictionary, the seam `bond_behavior_cfg` and `skills_cfg` already use. **`ConfigService` was not injected into the arbiter**, which holds none by design, and `balance.json` was not changed. **Proved by probe, not by the suite:** a probe radius of 9 fires `objective_threatened` at 5 tiles, while `{}` and the authored config do not. |
| **D92** | A party wipe could score as a successful escort | **Fixed** | Pass 2, `7a91df6`, in the same change as D67 so the cause stays attributable. The escort win latched on the spirit's own position with no guard, so a **joined** spirit standing on the destination delivered itself — and `destination_reached` is tested before `all_echoes_dead`, so a wipe read as `spirit_escorted`. **It survived because the existing test passed by accident:** under the old directive default the joined spirit moved off that cell on turn 1, so the latch never ran; D67's directive change made it stay. The latch now requires `escort_started` **and** a living non-spirit echo within `escort_radius`, both computed by loops that already skip `is_spirit` actors. Pinned by two tests, including `guide_spirit_party_wipe_scores_defeat_not_escort`, which an `escort_started`-only fix would fail. **Proved by reverting the guard.** Nothing moved: no shipped encounter reaches this path. |
| **D93** | The Thread count of a completed Realm ignores Realm size | **Deferred — V2-ECONOMY-004** | `ThreadService._derive_quality()` divides summed segment weights by `segments.size()`, so a one-stage Realm cleared cleanly scores 1.0 exactly as a ten-stage Realm does, and takes the top count of three. It surfaced because `realm.prologue` has one stage and paid **three** Threads on a real run. **Product-owner decision, 2026-08-29: pin the prologue, do not change the formula.** The prologue now pays a fixed one Thread (`RealmService.PROLOGUE_THREAD_COUNT`, applied in `ThreadService.crystallize_threads`), commit `ff068ed`; its virtue and quality tier still come from the run. Correcting the formula changes the payout of **every** Realm, which is a real economy change and larger than this story. Owner: **V2-ECONOMY-004** — it owns reward vocabulary and weighting, so it owns making Thread count sensitive to Realm size. |
| **D94** | A stage with no **required** objective was completable, and paid, on entry | **Fixed** | `83a13dd`, 2026-08-29. The gate offered `flow.complete_stage` whenever no *required* objective remained incomplete, and never checked whether the objective situations had been reached — so on a stage where every objective is optional the gate was open from entry and settlement paid a full stage reward for walking one step. **Measured, not estimated: 115 of 800 generated `realm.01` stages, 14.4%**, have zero required objectives (probe over 200 seeds x 4 stages, run against `main`). **Not farmable** — the settlement receipt is keyed per stage and the index advances in the same dispatch; the loss is skipped content, not unbounded Ase. **Attribution stated plainly: the gate is pre-existing** (identical line on `main`), **the payment is ours** — `091bcfd` introduced the no-encounter payment as the intended D05 fix, which is correct and merely exposed the hole. **Fixed the gate, not the generator**, per the owner: the condition gained an `objectives_found >= obj_total` term. Changing the generator's `required` flags would move recorded values for every realm. Completability was verified at the site before shipping: `find_explore_target` Tier 4 re-offers a passed objective once the frontier is exhausted. Covered by `objective/zero_required_blocked_until_reached` and `objective/required_stage_gate_unchanged`. |
| **D95** | The generator ignores the authored per-type `required` flag | **Deferred — V2-ECONOMY-004** (placement of convenience) | `data/balance.json:2958-2965` authors `required` per objective type; `RealmGenerator.gd:146` ignores it and hardcodes `is_required = (obj_type != TYPE_PURSUE)`. So `guide_spirit` is authored optional and generated required, and the authored flag is dead config for every type. Not fixed here: honouring it changes which stages have required objectives and therefore moves generation-derived recorded values. Fix by reading `required` from `objective_types[obj_type]`, defaulting true. **Ownership, stated plainly: the natural owner is realm generation, V2-STAGE-002** — but that story's only open row is blocked by a Done twin, so under the twin rule it cannot be used. It is filed on **V2-ECONOMY-004** as a placement of convenience, so it has a real page rather than none. Whoever next touches objective generation should take it back. |
| **D96** | The boss objective is always optional | **Deferred — V2-ECONOMY-004** (placement of convenience) | `RealmGenerator.gd:152` appends the final boss objective with `required = false` on every stage of every realm, unconditionally. **This is the root cause of D94**: because the boss never counts as required, a stage's required set is decided entirely by its pre-boss objectives, and `realm.01` has exactly one of those. It also means no stage anywhere requires its boss to be engaged. **Product-owner decision, 2026-08-29: fix the gate (D94), not the generator.** Making the boss required would move recorded values across the whole generation surface and alter difficulty; the gate fix removes the exploit without touching generation. A second reason not to act: `TYPE_BOSS` is still a stub, so requiring it before boss combat exists would soft-lock stages. Same placement note as D95 — the natural owner is realm generation, filed on **V2-ECONOMY-004** because V2-STAGE-002's open row is blocked by a Done twin. |
| **D97** | Enemies share the Echo emotional model and always refuse eventually | **Deferred — V2-COMBAT-003** | Recorded 2026-08-29, `36e5d98`. **Pre-existing; verified byte-identical on `main`. Noted, not fixed, by the owner's decision.** Reported from play as "enemies are too similar to echoes, they refuse and do nothing even when they have the upper hand", observed past 70 rounds. **Enemy refusal is unauthored** — every refusal reference in the GDD frames it as an Echo declining the Keeper's directive; the enemy path is an accident of a shared state machine. **Every relief term is Echo-gated** — outnumber relief, kill relief and ally ripple, the passive rank-scaled tick, identity relief and leadership dampening all apply to Echoes only, while every fear **gain** applies to both. **So enemy fear is monotonic.** Measured through the production path with an enemy given effectively infinite HP and 500 defence, that is, winning outright: `1, 2, 12, 26, 38, 50, 53, 67, 81, 95, 100`, then 100 for 79 more rounds, while Echo fear stayed at 0. **And the enemy threshold is the lowest in the game** — an `enemy` never gets a rank, so its band is `nascent` and it takes the raw base of 65 against a grounded Echo's 80; the unconditional +1 per-round tick alone reaches 65 by round 65 with no contact at all. Four options with their blast radii are recorded in Part D. Owner: **V2-COMBAT-003** (Ready). |

---

# Part B — Findings with no identifier

Things this story proved that were never given a D-number. Each carries an owner, or says plainly
that it has none.

## The two manual tests

**Manual test 1 passed, 2026-08-28, played end to end on `2d5d629`. The proof spine works.**
Confirmed live from the run log: the house is dormant through Chapter I; the Flame lights at the
awakening (`t:30`); the opening Realm is unlocked by awakening plus rite (`t:31`); the prologue
completes and normal Realms open (`t:155`); the stage settles **once** (`t:155`, a single
`stage_reward`, +90 Ase) while encounter rewards stay per fight (`t:96`, `t:154`, +15 each); the
durable result is written then consumed (`t:96`, `t:97`); level-up applies (`t:155`); and near-death
fires (`t:89`, `t:141`, `t:195`).

**Manual test 2, 2026-08-29, found two combat symptoms. Both were proved pre-existing and, by the
owner's decision, noted rather than fixed.** Causation was settled by comparison, not by reasoning —
a separate `main` worktree was built and both symptoms reproduced on each tree — because reasoning
about causation is how this story's earlier fingerprint prediction went wrong.

| Scenario | Result |
|---|---|
| Forced two-body case, Echo (1,1) against enemy (11,0), 12x12 board | **Byte-identical to `main`** |
| Long board, 60 columns, GUIDE_SPIRIT | **Byte-identical to `main`** |
| Forced escort with a non-joining spirit | **Byte-identical to `main`** |
| Twelve real new campaigns, `boot()` through the prologue | Echo closes and wins in 7 to 9 rounds. No stall |

No bisect was needed. **Nothing in the story's 31 commits causes either symptom.**

## The findings themselves

| Finding | What it is | Owner |
|---|---|---|
| **T01 — refusal is now reachable** | In manual test 1's third encounter, fear climbed to 100 and the Echo refused for 27 consecutive rounds. **Not a softlock in that case** — the enemies still dealt 1 to 2 damage, so the fight terminates on Echo death; slow, not stuck. **Not caused by this story** — all three near-death triggers in the log fired on the enemy. The owner's assessment: our changes did not cause the fear rise but may make refusal more reachable, which is acceptable. Two observations for whoever takes it: fear has no in-combat recovery term except outnumber relief, which cannot fire while the party is outnumbered; and a refusing Echo deals no damage. | **A fear-economy tuning pass. No story was named**, and none is invented here. This is a tuning question, not a defect. |
| **The `actor.idle` label on a moving actor** | In every run the Echo advances two cells per round while the recorded `action_type` reads `actor.idle`. Identical on `main`. Most of what read as twelve idle rounds is twelve rounds of approach across a long board. **Confusing, not broken.** Renaming it would move fingerprints for no gameplay gain. | None. Recorded so the next reader is not misled by the log. |
| **Movement-option starvation on long boards** | The real freeze behind manual test 2's symptom A. For the frozen Echo the movement layer reports `goals=1, options=0`, and with zero options the arbiter ranks only stationary candidates, so its unconditional `actor.idle` wins. `core/movement/LiveMovementContextService.gd:191-199` gates the movement-aware layer on **goals, not options**, and relies on the arbiter's stationary fallback. Safe on a 10x10 board. On a long board an actor whose goal region is not routable within its 2-cell capacity gets no option — and because it does not move, it never gains one. **The stall sustains itself**, and `Echo helplessness — morale decay` then fires every round. Three checks confirmed clean: pass 8's leadership traits are inert here, the pass 2 directive default moves nothing, and the ANSWERS #48 move-then-attack fix is still effective. | **V2-COMBAT-003** (Ready). Per the owner's 2026-08-29 decision, a movement-related cause is filed to the next movement story; this story's job was to report the mechanism precisely. |
| **Escort paired with an immobile spirit — about one guide-spirit encounter in four is unwinnable** | `EncounterObjectiveSpawnService.gd:411-427` builds the spirit as a `StructureActor` whenever the joins-battle coin flip loses, and that `else` branch covers **protect and escort**. The mode roll and the joins roll are two independent 50/50 draws, so escort-plus-structure occurs about **25%** of the time. `MovementExecutor.gd:282` then skips it, because it carries `is_structure`. **No player action can complete that objective. Only the timer ends it.** D80 and D92 are not involved: the destination was real, and the D92 guard only tightens the win latch. The fix belongs at the decision point, keeping the draw-then-override shape. | **V2-COMBAT-004** (Ready). |
| **The zero-damage floor** | `core/combat/CombatService.gd:126` returns `max(0, base + morale_bonus - fear_penalty)`. Damage floors at **0**, not 1. A guarding defender doubles `def`; a high-fear attacker loses up to 5. The formula is unchanged from `main`. | **V2-COMBAT-004** (Ready). |
| **The absent round cap** | There is **no `max_rounds` anywhere.** COMBAT mode requires a kill. Together with the zero-damage floor, a fight in which every swing lands 0 and both sides refuse or guard runs for ever. **This is the case the manual-test-1 ruling did not cover**, and that ruling was correct for its own case. | **V2-COMBAT-004** (Ready). |
| **The combat controller is not built** | Decision, 2026-08-24. The ownership stop condition was already met — all 73 actions have exactly one owner, and the six combat actions are `FlowRuntime`-owned deliberately, not provisionally. **Three blockers, all measured:** `_resolve_next_actor` transitions to the keeper rewind mid-body and returns bare, so no outcome can carry it; it calls `_end_round`, so a controller must take both functions or neither; and `_actor_cfg_merged_cache` is a per-`FlowRuntime` memo, so a per-call controller would rebuild it about 240 times per encounter — a `static var` was rejected as a silent cross-campaign determinism fault. Cost if built later: about 250 lines, of which the actual control-flow change is about **ten**. The extraction already did the expensive part. **Reason for stopping:** the remaining change sits in the least-guarded code in the combat path — the `last_actor_action` stamping block has no production test. **Also corrected on that story's page:** its own 2026-08-11 audit addendum told its implementer to wire `ProtectCustodyService` "through the extracted encounter/combat controller from V2-INFRA-003". That controller does not exist. The correct target is `core/combat/CombatRoundObjectiveService.gd`, which already owns PROTECT theft, carrier tracking and proximity. The addendum's real intent is satisfied either way. | **V2-COMBAT-004** (Ready), already carrying all three measured blockers. Recorded as **D69** in Part A. |
| **One real behaviour difference between the trees, explained and not chased** | In a plain-combat sample an enemy at 4 HP chose `actor.guard` on the branch and `melee_attack` on `main`. Not either symptom. The suspect is the near-death morale and fear hook from `39cfbaf` — connect case 1, which the owner approved, and which by design changes behaviour at low health. **Behaving differently at 4 HP is what that change is for.** Recorded, not bisected. | None. Expected consequence of an approved change. |

## Coverage truths this story established

These are not defects. They are facts about what the test suite can and cannot see, and they change
how much weight a green suite carries.

1. **Leadership is invisible to every test.** No recorded scenario contains a Whole-band Echo, so
   **no leadership trait activates in any fixture.** `leadership_trait_pool._comment` says the traits
   activate at the Whole band, `band_by_standing` puts Whole at rank 4, and `EchoFactory` mints every
   Echo at rank 1. This is a pre-existing property of the fixtures. It is why implementing eleven
   traits (D02) moved no fingerprint and no baseline, and it means the eleven traits that were
   **already** live are equally dormant in the recorded scenarios. **Until a Whole-band baseline
   scenario exists, every leadership claim rests on probes rather than on pinned values.**
2. **Three player-visible repairs landed with no test able to tell whether they worked.** D07, D37,
   D38 and D40 were each predicted to move a baseline. The suite was green with zero re-records, and
   the reason is not that the fixes were inert — the changed behaviour is **outside recorded cover**.
   File this as a real gap, not a clean bill of health.
3. **Six of pass 6's nine fixes are unreachable in play**, and each says so plainly rather than
   claiming the green suite as evidence: D09 needs a nearly full board, D12's changed branch is not
   exercised because the shipped path ends PURIFY_SHRINE on the round the shrine dies, D16 and D17
   are unreachable today, D80 is reachable only through a dev toggle, and D15, D28, D29 and D43
   changed no behaviour at all.

## Design questions raised and left open

Recorded so they are not lost. None is a defect.

| Question | Where it came from |
|---|---|
| `combat_divergence` was tier 2 in the deleted UI bark table and is absent from `data.voice.bark_tiers`, so it now ranks 3. Adding it is a one-line config edit that the D03 slice was forbidden to make. | Connect case 3 |
| **The board has no line-of-sight system.** "Cover" is read off the only physical obstruction the movement layer knows: an in-bounds non-walkable cell on the straight line to the nearest perceived hostile. If real line of sight or destructible cover arrives, that helper is the one place to change. | Pass 8 |
| **`mark_target` and `aggression_field` are the same effect at different magnitudes** (10 and 8), differing only in calling pool. Their key names suggest a distinction the action vocabulary cannot express, because there is only one attack action type. | Pass 8 |
| **`challenge_call`'s `taunt_attack_bonus` is 25.0, exactly the hardcoded taunt pull already in `_score()`.** It was implemented as the `actor.taunt` score bonus, not as a second copy of that constant. If the intent was the other reading, it needs changing. | Pass 8 |
| Whether a one-battle companion should count toward the `tikoro_nko_agyina` vow gate, given that `party_size` still counts `is_ally`. | Pass 5 |

## Smaller items raised during the fix passes and deliberately not fixed

Each is recorded at its site as well as here.

- `_spirit_killed_barked` and `_spirit_greeted` (`CombatRoundGuideSpiritService.gd:195,204`) are the
  same undeclared-latch shape as D56. Out of pass scope.
- `data.actor.structures` has no `guide_spirit` entry, so the non-joining spirit falls back to an
  inline literal at `EncounterObjectiveSpawnService.gd:419-423`. The unreachable-config shape again.
- The shrine morale drain filters on `faction == "echo"` only, so it drains allies and a joined
  spirit as well as real Echoes.
- Four files still use `round` as a parameter name, shadowing the built-in (D55 fixed two).
- `tests/KODeathTests.gd:47-48` comments its assertion as a tick. It passes because that fixture
  supplies no round and hits the fallback. The comment misleads; the assertion is correct.
- `core/save/SaveSchema.gd:34-35` was corrected in pass 10, but several test fixtures still write
  `"flow": {"state": ..., "context": {}}`. Those keys are now ignored. Cleaning them is churn.
- The combat-end dispatch's `save_request_reason` now also accumulates `bond.combat_triggers`, and
  `bond.rival_incidents` when a rival pair is seeded. **No test pins those two dispatches' reason
  strings.**
- `contribute_segment` requests no save of its own and relies on the surrounding dispatch flushing
  for another reason. True before and after pass 9.
- `data.voice.reactive_min_expression_band` ("forming") has zero readers;
  `ActorStateMachine._check_reactive_bark` hardcodes the equivalent gate as `nascent`.

## One hazard that governs any future fix here

**The retreat roll is genuinely tick-bound.** Same encounter, same 50 percent: ticks 7 and 8 succeed,
9 and 10 fail. **Any change to the dispatch count re-rolls every retreat in the game.** Check the
dispatch count before and after any change to this code.

## Backlog source of truth

**Notion is current. The CSV export is stale.** Notion marks seven stories Done that the CSV still
shows as Ready or Draft: V2-SANCTUM-001, both V2-SANCTUM-002 rows, V2-STAGE-003 (Order 236), both
V2-STAGE-004 rows, V2-BOND-002 and V2-VOW-002. Notion has no "Closed" status; the open set is Draft,
Ready, In Progress and Blocked. **Read Notion, not the CSV.**

**The twin rule.** The database holds duplicate story codes. When one twin is Done, the other twin is
not used. This decided D62's ownership and it is why D95 and D96 could not be filed on their natural
owner.

---

# Part C — Deferred work, by owning story

Every item below has a named owner and, where a Notion filing was made, a written handoff on that
story's page. **A defect filed only in this repository dies with this branch.**

## V2-INFRA-007 — contact resolution consequence parity (Ready, Order 262.5)

New story, created 2026-08-28 after thirteen open stories were checked and each rejected with a
reason. Depends on V2-INFRA-003. Page: `https://app.notion.com/p/3cac3d1ede9281f58864c9d15a954952`.
Four properties were left empty rather than guessed: Priority, Spec State, Source GDD, Legacy Source.

| Item | What it owns |
|---|---|
| **D62**, cross-listed as **D06** | Contact resolution runs none of the six post-encounter steps: ally teardown, emotion drift, bond triggers, sanctum emotion tick, vow discovery, vow release. A whole social path is inert relative to combat. |

## V2-COMBAT-003 (Ready)

| Item | What it owns |
|---|---|
| **D57** | Movement adapter criterion 5 orders cells by lexicographic `"col,row"`. Unblocked by D27. |
| **D64** | The 28-function live movement family, moved verbatim by this story. |
| **D65** | The guide-spirit mover, moved verbatim. |
| **D97** | Enemies share the Echo emotional model and always refuse eventually. |
| **Movement-option starvation on long boards** | The self-sustaining stall from manual test 2, symptom A. See Part B for the mechanism, the file and the line. |

## V2-COMBAT-004 (Ready)

| Item | What it owns |
|---|---|
| **D69** — the combat controller decision | Already carrying **all three measured blockers** on the story page. |
| **The GUIDE_SPIRIT escort and structure pairing** | About one guide-spirit encounter in four is unwinnable by construction. |
| **The zero damage floor** | `CombatService.gd:126` floors damage at 0, not 1. |
| **The absent round cap** | No `max_rounds` exists anywhere. With the damage floor, a fight can have no reachable end condition. |

## V2-ECONOMY-004 (Ready)

| Item | Filed | Note |
|---|---|---|
| **D66** | 2026-08-25 | Reward resolution reads `obj_type` where objectives store `type`. |
| **D83** | 2026-08-25 | `ekwan_shrine_multiplier` has never applied — the same root cause, second site. **Fix both with D66 in one change and re-record once.** |
| **D93** | 2026-08-29 | Thread count ignores Realm size. The prologue is pinned to one Thread as a stopgap; the formula is untouched. |
| **D95** | 2026-08-29 | **Placement of convenience.** See below. |
| **D96** | 2026-08-29 | **Placement of convenience.** See below. |

**D95 and D96 are filed here for want of a better page, and that must not be forgotten.** Their
natural owner is **realm generation, V2-STAGE-002** — both are `RealmGenerator` defects and neither
is about reward vocabulary. V2-STAGE-002's only open row is blocked by a Done twin, and under the
twin rule that row is not used, so there was no correct page to file them on. They are recorded on
V2-ECONOMY-004 so they have a real owner rather than none. **Whoever next touches objective
generation should take them back.**

## V2-SANCTUM-004 (Order 340, Ready)

| Item | Filed | Note |
|---|---|---|
| **D61** | 2026-08-28 | The institution passive-accrual asymmetry. Page: `https://app.notion.com/p/339c3d1ede92810ebcb4c71776d816a5`. **The filing added a scope line** for authoring the first institutions' passive values and their upkeep — that item sat with V2-SANCTUM-002, which Notion now marks Done, so it was otherwise orphaned. The strain warning surface stays with V2-SANCTUM-005. No property on the page was changed; its Superseded twin at Order 239 was not touched. |

## V2-ECONOMY-002

| Item | Note |
|---|---|
| **The awakening Ase grant** | Deferred from **D87**. `data.economy.awakening_ase_grant: 40` stays unreachable and the modal no longer claims it. **D89's recorded divergence from GDD §20.7 depends on this** — do not restore the GDD ordering before the grant ships. |

## Carried with no owning story

**These two are the honest gap in this ledger.** Both are real, both were left open, and the
post-manual-test triage filed them under "owned by another story" without naming one. No Notion
filing exists for either.

| Item | Why it has no owner |
|---|---|
| **D59** — `encounter.advance` has no phase guard; `encounter.complete` transitions from any state | Grouped with "owned by another story" in the 2026-08-28 triage, but no story was named and none was filed. Verified still open at `e8c89f4`. |
| **D60** — the flow machine never transitions to RESOLVE at the end of combat | Same. Phase 8B added RESOLVE transitions on three other paths but not the combat-end path. Architecturally adjacent to D69, which went to V2-COMBAT-004, but it was never filed there and is not assigned here on a guess. |
| **T01 — the fear-economy tuning question** | The owner assigned it to "a fear-economy tuning pass, not V2-INFRA-003". No story exists for that pass. Related work is already recorded in project memory (the August fear pass, peak fear 4 to 46), and **D97 is the same subject seen from the enemy side**. |
| **D71, D72, D74, D75** — four open coverage gaps | Test gaps, not defects. No story owns test coverage. See Part A for each one's verified status. |


---

# Part D — The original register, preserved

**Historical record. Read for evidence, not for instructions.**

Everything below is the working document as it stood when the story finished, kept whole: the
product owner's dated decision blocks, the five defect kinds, the per-phase addenda, the
pre-playtest and post-manual-test triages, and the fix-pass outcome tables. The reasoning here is
why the outcomes in Part A are what they are.

Two warnings for a later reader:

1. **The standing instructions in this part are spent.** The slice rule ("when your work brings you
   to the location of a listed defect...") was scoped to this story, and its companion rule has been
   removed from `AGENTS.md` (commit `e8c89f4`). Do not follow it.
2. **Where two statements below conflict, the later dated one wins**, and Part A states which. Some
   rows describe an entry as open that a later block closes.

---

## The register as compiled — V2-INFRA-003 Defect Register

Compiled 2026-08-23 from service/controller headers, in-code `KNOWN DEFECT` /
`CHARACTERIZATION` labels, `docs/v2-infra-003-handoff.md`, `docs/resolve-snapshot-block-spec.md`,
and the characterization suites. **Every `file:line` below was re-verified against the worktree**
(`.claude/worktrees/v2-infra-003-proof-spine-b3c770`); stale locations from the handoff are
corrected in place and flagged.

Read-only compilation. Nothing was changed.

---

## DECISIONS AND SCHEDULE — Jeff, 2026-08-24

**This register is the single place defect decisions are recorded.** A finding written anywhere else
is lost.

### Rule for every V2-INFRA-003 slice from now on
> Scope: **this story only.** It is recorded in `AGENTS.md` with an instruction to delete that section when the story ships.
When your work brings you to the location of a listed defect: investigate briefly, record what you
learned in that defect's entry, and **do not fix it**. If you find a defect not listed here, add a
new entry with the next free ID. See `AGENTS.md`, "When you reach the site of a known defect".

### When each group is handled

| Group | When | Method |
|---|---|---|
| Low-impact and no-impact fixes | after Phase 6 | normal slices |
| D03 bark budget | after Phase 6 | connect the cap |
| **Every mechanic that has never run** — D01, D02, D04, and any other `BROKEN-SHOULD-BE-LIVE` | **after Phase 9 full regression, before Jeff's manual test** | **ONE AT A TIME.** Connect one, run the full suite, record exactly what moved, then the next. |
| D36 replayable reward | **verify NOW** (read-only); fix in the after-Phase-9 group | |

**Why one at a time.** Connecting ten mechanics together produces one large set of moved values with
no way to attribute them. One at a time gives an attributable diff per mechanic: if the tests break,
we know which mechanic did it; if a recorded value moves, we know why. Jeff then verifies the feel
in his manual test against a written list of what changed.

### What happens to THIS FILE when the work is done — Jeff, 2026-08-24

This file is a worklist now. It must not stay one. After the after-Phase-9 fix pass, convert it to a
**ledger of completed work**, in Phase 11 with the rest of the documentation.

Conversion rules:

| Entry outcome | What the ledger row must carry |
|---|---|
| Fixed | what was changed, which slice or commit, and what moved in the recorded values |
| Connected | which mechanic went live, what moved, and what Jeff verified in the manual test |
| Deleted | what was removed and the proof it had no caller |
| Deferred | the **named story** it was filed against — never "later" |
| Disproved | keep the original claim visible, and the evidence that it was wrong |

Three rules for the conversion:
1. **Delete nothing.** A defect that turned out to be imaginary is still a useful record — three
   entries in this register were disproved (**D20, D34, D41**), and knowing that stops someone
   re-filing them.
2. **No entry may end without an outcome.** An entry with no row in the ledger means the work was
   dropped silently.
3. **Remove the companion rule from `AGENTS.md`** ("When you reach the site of a known defect") in
   the same change. It is scoped to this story and would otherwise send later agents to a document
   about finished work.

The result is a record of what this refactor found and what was done about each item — readable by
someone who was not here.

### The combat controller is NOT built — filed to V2-COMBAT-004, 2026-08-24

Decision: **do not build a `CombatController` in this story.** The ownership stop condition is already
met — all 73 actions have exactly one owner, and the six combat actions are `FlowRuntime`-owned
deliberately, not provisionally.

Three blockers, all measured, all recorded on the V2-COMBAT-004 page:
1. `_resolve_next_actor` transitions to the keeper rewind mid-body and returns bare — no outcome can carry it.
2. It calls `_end_round`, so a controller must take both functions or neither.
3. `_actor_cfg_merged_cache` is a per-`FlowRuntime` memo; controllers are built per call, so a
   controller would rebuild it ~240× per encounter. A `static var` is a silent cross-campaign
   determinism fault and was rejected.

Cost if built later: ~250 lines total, of which the actual control-flow change is **about ten lines**.
The extraction already did the expensive part.

Reason for stopping: the remaining change sits in the least-guarded code in the combat path — the
`last_actor_action` stamping block has no production test, because the fingerprints compute positions
inside the test and never read the production field.

**Also corrected on that page:** V2-COMBAT-004's own 2026-08-11 audit addendum tells its implementer
to wire `ProtectCustodyService` "through the extracted encounter/combat controller from
V2-INFRA-003". That controller does not exist. The correct target is
`core/combat/CombatRoundObjectiveService.gd`, which already owns PROTECT theft, carrier tracking and
proximity. The addendum's actual intent — keep objective-mode orchestration out of `FlowRuntime` — is
satisfied either way.

### PHASE 8 SCHEDULING — Reading A, decided 2026-08-25

**The settlement rework and the D36/D77 fix are the same change.** Phase 8's core deliverable is
"settle only on the final required objective; base + virtue + stage-clear XP once per stage", which
IS moving payment out of `FlowEncounterState.build_final_snapshot`. The earlier "after Phase 9"
schedule for D36/D77 was set before that overlap was noticed.

**Decision: Phase 8 does the settlement work.** The after-Phase-9 bundle keeps only what it was
actually meant for — mechanics that have never run (D01, D02, D03, D04), connected **one at a time**
with a suite run after each.

**Reason.** Three independent changes move reward numbers: the `run_index` leak (already live), the
payment relocation, and the base/bonus split. Bundling them into one explained re-record is the only
way to get **one** baseline event instead of three.

### D82 — `prologue.first` inflates `run_index` for every player (NEW, LIVE, verified 2026-08-25)

`core/onboarding/KeeperIntroService.gd:435-446` writes `save_data["realms"]["prologue.first"]` with
**no `status` key**. `RealmService._count_started_realms` (`:311-318`) counts any entry whose
`status != "not_started"`, and an absent key reads as `""`, which passes.

**So every player who completes the keeper intro enters their first real Realm with `run_index = 1`
instead of `0`.** That inflates the virtue bonus, the reward order multiplier
(`RealmService.calculate_stage_reward:280-306`) and the realm XP multiplier
(`ProgressionService.get_realm_xp_multiplier:275-288`, plus its inline duplicate at
`FlowEncounterState.gd:257-261` — see D33).

Verified by the orchestrator directly, not only by an agent. Live today; not caused by this story.

**Jeff, 2026-08-25: fix it — `run_index` must be 0 for the first real Realm.** Folded into the
Phase 8 settlement bundle, because it moves the same numbers and fixing it separately means a second
re-record.

**Blast radius: FP + BL.** It changes reward numbers on its own, independently of the payment move.

### MANUAL TEST 1 PASSED — Jeff, 2026-08-28

First full session played end to end on `2d5d629`. **The proof spine works.** Confirmed live from
the run log:

| Step | Evidence |
|---|---|
| House dormant through Chapter I | Flame not lit at name confirm |
| Flame lights at the awakening | `t:30 Ase Flame awakened` |
| Opening Realm unlocked by awakening + rite | `t:31` |
| Prologue completes; normal Realms open | `t:155` |
| Stage settles ONCE | `t:155` — a single `stage_reward`, +90 Ase |
| Encounter rewards stay per fight | `t:96`, `t:154` — +15 each |
| Durable result written, then consumed | `t:96`, `t:97` |
| Level-up applies | `t:155` — Simon Mensah to level 2 |
| Near-death fires | `t:89`, `t:141`, `t:195` — all on enemies |

### T01 — refusal is now reachable, and that is a TUNING question, not a defect

In the third encounter (two enemies, one Echo) fear climbed to 100 and the Echo refused for 27
consecutive rounds before Jeff quit.

**Not a softlock.** The orchestrator called this "a stalemate with no end condition in reach" and
was wrong: the enemies still deal 1–2 damage per round, so the fight terminates on Echo death. It is
slow, not stuck. Jeff: *"it will have to reach an end state — echoes die, win state reached, or
enemies die. I just quit early."*

**Not caused by this story.** All three near-death triggers in the log fired on the Dust Wanderer,
after Simon attacked — D01 added fear to enemies, not to him.

Jeff's assessment: our changes did not cause the fear rise, but may make refusal **more reachable**,
which is acceptable. Earlier work (the August fear-economy pass, peak fear 4 → 46) tried to balance
this and did not succeed. *"If everything was alright we just refactored and turned on systems that
were already supposed to be turned on."*

**Owner: a fear-economy tuning pass, not V2-INFRA-003.** Two observations for whoever takes it:
fear has no in-combat recovery term except outnumber relief, which cannot fire while the party is
outnumbered; and a refusing Echo deals no damage, so the fight can only end by its own death.

### THE ~53 "AFTER THE TEST" ENTRIES ARE NOT OPTIONAL — Jeff, 2026-08-25

**Correction to this document's framing.** The triage sorted entries by "would Jeff hit this in a
first session" and labelled the remainder *"real, but not urgent."* That was wrong, and it is the
kind of wrong that loses work. Sequencing is not severity. **Every one of these is code that does
not currently work correctly**, and finding them was an explicit purpose of this refactor — not a
side effect of it.

**The agreed plan:**

| Step | Work |
|---|---|
| 1 | Connect pass — the never-run mechanics, one at a time, full suite after each |
| 2 | Jeff's manual first-session test |
| 3 | **Fix the remaining defects** — all of them, not a selection |
| 4 | Jeff manual-tests again |
| 5 | Orchestrator runs the full suite |

Design decisions are raised with Jeff as they arise, not resolved unilaterally and not deferred to
a story that does not exist.

**Nothing in this register may be closed by attrition.** An entry leaves this file by being fixed,
deleted, disproved, or filed on a named story's page — never by being judged unimportant.

### DEFERRED ENTRIES ARE NOW FILED ON THEIR STORIES — 2026-08-25

Every deferred defect now has a named owner and a written handoff **on that story's Notion page**.
A defect filed only in this repo dies with this branch.

| ID | Defect | Filed on |
|---|---|---|
| **D66** | Reward resolution reads `obj_type`; objectives store `type`, so objective-specific weighting falls through to the default combat path | **V2-ECONOMY-004** |
| **D83** | `ekwan_shrine_multiplier` has never applied — same root cause, second site. Fix both together, re-record once | **V2-ECONOMY-004** |
| **D64** | The 28-function live movement family, moved verbatim | **V2-COMBAT-003** |
| **D65** | The GUIDE_SPIRIT mover, moved verbatim | **V2-COMBAT-003** |
| **D27** | The movement decision (`goal_id`/`option_id`) is never stored or logged — a refactor reaching the right cell for the wrong reason passes silently. **D57 cannot be safely investigated until this exists.** | **V2-COMBAT-003** |
| **D69** | `_resolve_next_actor` cannot become a controller — three measured blockers | **V2-COMBAT-004** (filed 2026-08-24) |
| **D67** | `make_new_save` writes a directive value the repair immediately rewrites, so the V1 to V2 migration is LIVE. Fix the schema default first, THEN remove the migration — order matters | **This story, Phase 11** |
| **D62 / D06** | Contact resolution runs none of the six post-encounter steps — emotion, bonds and vows do not move | **UNRESOLVED — see below** |

**D66's "disputed owner" was a false contradiction.** This register recorded that the prompt said
V2-ECONOMY-004 while Notion showed the Ekwan loop. They are the **same story** — that page's `Code`
property is `V2-ECONOMY-004`. The original brief was right. Better: that page already carried a
2026-08-11 addendum describing this exact `obj_type` / `type` mismatch, and it already drew the
boundary — *"Keep exactly-once payout orchestration in V2-INFRA-003; this story owns reward
vocabulary, weights, Ase/Ekwan split."* That boundary was honoured: this story built the
orchestration and changed **no** reward value.

**D62 needs a decision.** It is the largest player-facing item still open, it was scheduled for
Phase 8, and Phase 8 did not build it — `EncounterResolutionService` does not exist. It is therefore
deferred to a phase that has already passed, which is how work silently disappears. Options: build it
before the manual test, after it, or give it its own story.

### Decisions taken 2026-08-24 on D36 / D77 / D78

**D77 — the 25% defeat consolation STAYS. It is intended design.**
So the defect is NOT the payout. It is that the payout **repeats**. The fix must therefore keep the
consolation and stop the farming, and it must NOT mark the situation resolved on defeat — that would
remove the player's ability to retry a lost fight, which is a design change nobody asked for.

Required shape:
- pay the stage reward **once per situation**, stamped on a persisted per-situation `rewarded` flag
- the defeat consolation pays once, on the first defeat of that situation
- the situation stays **unresolved** after a defeat, so the fight is still retryable — just not payable again
- the real settlement still moves to `VentureController.handle_complete_stage`, so payment and stage
  advance land in one dispatch (this also fixes D05's no-encounter case)

**D78 — the Android Back button must NOT quit the app.** Confirmed as a bug to fix.
`project.godot` leaves `quit_on_go_back` unset (default `true`) and nothing in `ui/` or `core/`
handles `WM_GO_BACK_REQUEST`, `WM_CLOSE_REQUEST` or `APPLICATION_PAUSED`. One press of the system
Back button ends a session from any screen.
**This moves no recorded value**, so it does not need the after-Phase-9 bundle. Proposed for the
after-Phase-6 low-impact group. Say if you want it later.

**D36 + D77 fixes go in the after-Phase-9 bundle**, with the single explained baseline re-record
alongside D01, D04, D18, D19, D35 and D50.

### Decisions taken
- **D01 + D04 are bundled** — same root cause (a stat read at the top level of the actor instead of
  under `stats`). D04 has the larger player impact: every mid-combat level-up currently gives a free
  full heal. Both move to the after-Phase-9 group.
- **D36 is verified now**, fixed later. It is a live exploit, not a dormant mechanic, and the
  register has no confirmed location for it.
- **Six fixes move recorded values** — D01, D04, D18, D19, D35, D50. They land as **one** change with
  **one** explained baseline re-record. Never re-record a constant you cannot explain
  (`AGENTS.md` mistake 23).
- **Every fix needs a dispatch-count check first.** The retreat roll seeds on the simulation tick, so
  any change to the number of dispatches changes every retreat result in the game.

---

Legend for **Blast radius**: `FP` = fixing it moves one or more `tests/FlowFingerprintTests.gd`
fingerprint constants. `BL` = moves a recorded baseline (`tests/CombatBaselineTests.gd`,
`tests/VentureCharacterizationTests.gd`, `tests/FlowSnapshotFingerprintTests.gd`). `—` = neither.

---

### PRE-PLAYTEST TRIAGE — accounting and closures, 2026-08-27

**Register accounting.** Identifiers run **D01–D93** (D91 added 2026-08-28, fix pass 1; D92 added 2026-08-28, fix pass 2; D93 added 2026-08-29, prologue Thread payout — recorded and deferred). Six of them (D71–D76) are **coverage gaps,
not defects**. The defect population is therefore **84 defects + 6 coverage gaps**, not 88.
(No summary count table exists in this file to correct — the stale "88" the triage refers to lives
in `docs/v2-infra-003-triage.md`'s source material, not here. The correct accounting is stated
above so it cannot drift again.)

**Three entries have been disproved, not two:** **D20**, **D34** and **D41**. The rule above
("two entries in this register were disproved") is corrected to **three**. Each keeps its original
claim visible so nobody re-files it.

**Closed by earlier work, marked here because the register had not caught up.** All five were
re-verified against this worktree by the orchestrator, not only by a triaging agent.

| ID | Evidence in this tree |
|---|---|
| **D36** | Payment left the snapshot builder. `core/economy/StageSettlementService.settle()` (`:92`) runs in the same dispatch as `advance_stage`, behind a persisted `settlement_receipt` (`:108-110`, written `:163`). No window to quit inside. |
| **D77** | `EconomyService.reward_encounter_complete()` (`:131`) and `settle_stage_complete()` (`:211`) are now separate payments. `ActiveStageService.claim_situation_defeat_consolation()` (`:349`) writes `consolation_paid` (`:369-371`) and returns true once per situation. The 25% stays; the fight stays retryable. |
| **D92** | The GUIDE_SPIRIT escort win latches on the spirit's own position with no guard, so a **joined** spirit standing on the destination delivers itself | `core/combat/CombatRoundGuideSpiritService.gd:297-302` — the `destination_reached = true` latch is guarded only on `not is_dead` and the position match. The escort-start and escort-proximity loops above it (`:225-249`) correctly skip `is_spirit` actors; the latch does not. | **FOUND during fix pass 2 (2026-08-28, D67), NOT touched.** `tests/CombatRoundtripIntegrationTests.gd:2002` (`guide_spirit_joined_spirit_does_not_self_escort`) exists to pin this and passed only by accident: under `directive.seek_signs` the joined spirit chose to move off the destination on its own turn (probe: `(5,5)` → `(7,3)` in round 1), so the latch never ran. D67 changes the new-save directive to `directive.scout_carefully`, under which the same spirit stays on `(5,5)`, the latch fires at the first `_end_round`, and `destination_reached` becomes true with every real echo dead. `destination_reached` is evaluated before `all_echoes_dead` (`core/combat/CombatState.gd:210`), so the encounter would end `spirit_escorted` — a victory after a party wipe. | Yes — any GUIDE_SPIRIT escort with `spirit_joins_battle` true whose spirit is on or reaches the destination cell. | A party wipe can be scored as an escort victory. | **FIXED 2026-08-28 (fix pass 2), by product-owner decision, in the same change as D67 so the cause stays attributable.** The latch at `core/combat/CombatRoundGuideSpiritService.gd:299-309` now carries the same pair the movement gate above it uses: `escort_started` must be true, and `_gs_escorted` must be true — a living non-spirit echo within `escort_radius` this round. Both are computed by loops that already skip `is_spirit` actors, so a joined spirit can neither start nor satisfy its own escort. The precedence in `CombatState.gd:210` was not touched. | **Pinned by two tests**, both in `tests/CombatRoundtripIntegrationTests.gd`: the existing `guide_spirit_joined_spirit_does_not_self_escort` (escort never started) and the new `guide_spirit_party_wipe_scores_defeat_not_escort` (escort started earlier, then the party dies — the case an `escort_started` guard alone would miss). Both were confirmed to fail with the guard reverted and to pass with it restored. No fingerprint or baseline moved: no shipped encounter reaches this path. |
| **D05** | `VentureController.NO_COMBAT_GRADE = "C"` (`:164`); settlement runs on `is_combat_victory or not has_encounter` (`:659`). The no-encounter stage now pays and grades "compromised", recorded at `:681-688` as a judgement, not a repair. |
| **D39** | `ActiveStageService.gd:330` delegates to `RewardCalc.base_reward()`. Both readers now sum the stage's objective weights. |
| **D73** | Closed by the assertion at `tests/OnboardingTests.gd:283` — producer B's resolve payload is rejected if it carries `ekwan_awarded`. |

**Fixed in the pre-playtest batch, 2026-08-27 — full suite 1,494 passed, 0 failed, and NOTHING
recorded moved.**

| ID | Change | Site |
|---|---|---|
| **D78** | `application/config/quit_on_go_back=false` plus a `NOTIFICATION_WM_GO_BACK_REQUEST` handler. Back dispatches the live snapshot's own `nav.back` action when it has one, is swallowed while a blocking modal is up, and otherwise does nothing. It can never quit and can never reach a state a tap could not. | `project.godot`, `ui/AppRoot.gd` |
| **D08** | Missing `.` added to the retreat seed fallback string. | `core/runtime/FlowRuntime.gd:1166` |
| **D10 + D11** | `_double_damage_mult` is now erased beside `_carrier_double_damage` on carrier-down recovery, and the emptiness guard's real premise (actors are marked `is_dead`, never removed) is stated at the site. | `core/combat/CombatRoundObjectiveService.gd` |
| **D48** | The ledger now checks the `back()` entry's `source_id`, matching the `last_actor_action` stamp that reads the same entry. | `core/combat/ContributionLedgerService.gd` |
| **D81** | The **second**, unreachable dormant gate deleted, with its `economy.offline_guard` save. The inline gate survives because it leaves `last_offline_unix` / `last_settle_unix` alone — the dead one rolled them forward and would have swallowed an accrual window. | `core/economy/OfflineAccrualService.gd` |
| **D37 + D38** | The victory-return call site now passes `skip_if_already_resolved=true` and `commit_only_when_modified=true`. | `core/runtime/FlowRuntime.gd:789` |
| **D40** | The already-completed guard returns `{}` instead of the model. Its one production caller (`VentureController.gd:692`) reads `is_completed` off the RETURNED dict as its Thread-mint trigger, so the guard no longer hands back a second reason to mint. | `core/realms/RealmService.gd` |
| **D07** | The scout-return preview reads the flattened `morale` / `fear` that `EchoActor.from_echo()` actually writes. This corrects the stored `save.flow.pending_result` copy for free. | `core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd:70-83` |

**NEW COVERAGE FINDING — the blast-radius column was wrong for all three Stage 2 fixes.**
D37, D38, D40 and D07 were each predicted **BL**. The full suite is green with zero re-records,
and the reason is not that the fixes are inert — it is that the changed behaviour is **outside
recorded cover**:

- **D07** — `venture_char/return_home_call_site_builds_scout_return` asserts the actor
  projection's KEY SET (`VentureCharacterizationTests.gd:738-742`) and never its
  `emotional_status` VALUE. The constant `get_emotional_status(50, 0)` was never pinned. The
  correction changes the card for any party echo not at exactly morale 50 / fear 0, and no test
  would have noticed either way.
- **D37 / D38** — the only test that drives `_apply_victory_return_to_explore`
  (`Stage004SeamTests.gd:1109`) asserts ally-field teardown. Neither `objectives_found` nor the
  `stage.combat_resolved` flush reason is asserted on this path, and no test calls it twice.
- **D40** — `realm_prog/advance_idempotent_when_complete` was the only cover, and it **pinned the
  defect**: it required the model back from the guard. Its assertion is inverted in this change
  (`StageProgressionTests.gd`), which is the single deliberate recorded change in the batch.

File this as a real gap, not a clean bill of health. Three player-visible repairs landed with no
test able to tell whether they worked.

**Three product-owner questions are answered in code and are struck below:** D05's grade (`"C"` →
"compromised"), D39's base (**sum**), D77's consolation (25%, once per situation).

---

## Kind 1 — BROKEN-SHOULD-BE-LIVE
*Runs but cannot work. Fixing turns the mechanic on, so it changes behaviour.*

### Group A — wrong path / wrong key makes authored configuration unreachable
The V2-PROG-012 "decorative balance value" shape. **D01 is the one the product owner has already
decided.** D02–D04 are the same shape found while compiling this register and were **not previously
recorded anywhere**. They are not one fix — D01 is a one-line path correction; D02/D03 are
unimplemented mechanics, not typos — but they should be triaged as one group.

| ID | Title | Verified location | Evidence | Reachable in play | Player impact | Recommended action | Blast radius |
|---|---|---|---|---|---|---|---|
| **D01** | Near-death morale + fear trigger reads `max_hp` at top level; never fires — ✅ **CONNECTED, 2026-08-27 (connect case 1 of 4)** | `core/combat/CombatTurnActionService.gd:321` (header note `:82-95`). **Handoff/brief said ~315 — corrected.** | `var nd_max_hp: int = int(target.get("max_hp", 1))` — actors carry `stats.max_hp`, never a top-level copy (`core/actors/EchoActor.gd:45,55` builds `stats` + `current_hp`, no `max_hp`). Default `1` passes `nd_max_hp > 0`, then `current_hp * 4 <= 1` is unsatisfiable for any living actor. Two authored keys unreachable: `data/balance.json:1662-1663` `morale_on_near_death: 7`, `fear_on_near_death: 8`. Correct sibling reads verified at `BehaviorArbiter.gd:1625`/`:2284`, `ActorService.gd:86`, `LiveMovementContextService.gd:816`/`:921`. | **Yes** — code path is on the main melee-damage line, executed every damaging turn; only the condition is unsatisfiable. | Currently **none** (has never fired). After fix: every Echo and enemy dropping to ≤25% HP gains morale and fear once per actor — a real combat-tension beat that has never existed. | **DECISION TAKEN — goes live.** Read `stats.max_hp` with the `LiveMovementContextService` fallback idiom. **Sequenced after the Phase 6 extraction completes**, as its own commit, with an explained baseline update. | **FP + BL.** Turns on morale/fear writes inside the round loop → moves `CombatBaselineTests` per-actor fear/morale hashes across all seven modes, and `FlowFingerprintTests` wherever emotion feeds the final snapshot. This is why it must not land mid-extraction. | **CONNECTED 2026-08-27.** `CombatTurnActionService.gd:310` now reads `int((target.get("stats", {}) as Dictionary).get("max_hp", target.get("max_hp", 1)))` — the `LiveMovementContextService.gd:824` fallback idiom, unchanged. No config value moved. **Measured blast radius was much smaller than predicted here: 7 of 34 `CombatBaselineTests` emotion constants, and NOT ONE of the seven mode fingerprints.** COMBAT (idx 3,4), ENDURE (idx 3,4), PURSUE (idx 3,4) and PURIFY_SHRINE (idx 3) each move by exactly one actor gaining morale 50→57 and fear +8 — the two authored values, unscaled, once. RECOVER, PROTECT and GUIDE_SPIRIT are byte-identical: no actor is left alive at ≤25% HP in those traces. In all four moved modes the actor is the ENEMY, crossing the line in round 4 and dying in round 5, so its raised fear changes no decision — that is why the fingerprints held, and it is a property of these fixtures, not of the mechanic. Proof the branch is live: `consequence/near_death_fires_at_quarter_hp`, `…_silent_above_quarter_hp`, `…_fires_once_per_actor` (`tests/CombatConsequenceTests.gd`), verified to FAIL on the pre-fix read and pass on the fixed one. **Two behaviours for the manual test:** the trigger fires for STRUCTURES too (shrine/totem/relic/guided spirit all carry `stats.max_hp`, `morale` and `fear`), and it is a MORALE GAIN on the wounded actor, so a badly hurt enemy hits harder — `_melee_damage` adds `(morale-50)/10`, and +7 is short of the +10 needed for +1 damage on its own.
| **D02** | Ten leadership trait effects are authored with parameters nothing reads | `data/balance.json` → `data.maturity_expression.leadership_trait_effects`; consumer is `core/combat/LeadershipEmotionService.gd:19-20` (+ `core/actors/ActorStateMachine.gd`) | Repo-wide grep for each key returns **zero readers in `core/` or `ui/`**: `melee_score_bonus` (`aggression_field`), `taunt_attack_bonus` (`challenge_call`), `attack_score_bonus` (`mark_target`), `move_score_bonus` (`safe_path_read`), `retreat_threshold_reduction` (`threat_read`), `move_score_reduction` (`hold_formation`), `directive_bonus_mul` (`directive_echo`), `immune_to_displacement` (`position_lock`), plus `anchor_presence: {radius}` (no effect body at all) and `cover_positioning: {}` (authored empty). The sibling keys that *are* read — `morale_per_round`, `fear_reduction`, `morale_boost`, `radius`, `fear_accumulation_factor`, `morale_lock_rounds`, `morale_loss_reduction`, `fear_transmission_rate`, `directive_mul` — all resolve, which is what makes the gap invisible. | **Unknown.** The traits are authored and can be rolled onto Echoes; the *effect* is unreachable. Whether all ten trait ids are actually in a live grant pool was not verified. | Ten leadership traits are cosmetic. A player who builds toward `mark_target` or `threat_read` gets nothing. | Product-owner call per trait: implement in `BehaviorArbiter` scoring (six of them are scoring bonuses and belong there, not in `LeadershipEmotionService`), or delete the trait + its balance block. Do not implement all ten blind. | **FP + BL** if any scoring bonus is implemented — arbiter score changes re-roll movement and target choice, which moves every combat fingerprint. Deleting the config alone is `—`. |
| **D03** | The `data.voice` bark budget block has no reader — ✅ **CONNECTED, 2026-08-28 (connect case 3 of 4)** | `data/balance.json` → `data.voice.max_barks_per_round: 3`, `.max_reactions_per_original: 1`, `.bark_tiers` | Zero readers repo-wide for all three keys. `core/echoes/NarrativeVoiceService.gd` fires barks unbudgeted and untiered. **`core/combat/CombatRoundEmotionService.gd:223` even comments "it also breaks the bark budget (max_barks_per_round 3)" — the code believes a budget exists.** | **Yes** — barks fire in every combat round; the cap simply never applies. | Bark spam in busy rounds; the authored tier-1/2/3 priority ordering (last-stand / KO lines vs. chatter) never arbitrates, so a dramatic line can be drowned out. | Either connect the budget in `NarrativeVoiceService` (cap per round, prefer higher tier) or delete `data.voice` and the misleading comment. | **BL.** `CombatBaselineTests` and the round-bark integration suites pin `round_bark_events`; capping changes their contents. `—` for fingerprints (barks are not in the final-snapshot key set). **CORRECTED 2026-08-28: that blast-radius claim is wrong on both counts.** `CombatBaselineTests` contains no bark assertion at all (`grep -i bark` returns nothing), and no suite in the repository pins `round_bark_events`. Nothing moved.

**THE PREMISE WAS WRONG — the budget was not missing, it was duplicated.** `ui/screens/combat/CombatBoardScreen._show_bark_popups()` already implemented the whole block as hardcoded literals: `max_originals = 3`, a `tier_map` with the same membership as `bark_tiers`, reactions collected separately and never counted (`reactions_exceed_cap`), and a `break` after the first reaction per original (`max_reactions_per_original`). So barks were neither unlimited nor untiered in what the player saw. The defect was that the authored config had no reader while a copy of it ran in the UI, where `ui/` cannot read `balance.json` and the two could drift silently — and they already had: the UI table carried `combat_divergence: 2`, which `data.voice.bark_tiers` does not list.

**Also unread, found here, not fixed:** `data.voice.reactive_min_expression_band` ("forming") has zero readers; `ActorStateMachine._check_reactive_bark` hardcodes the equivalent gate as `if _expression_band == "nascent": return`.

**WHAT WAS DONE.** `ConfigService.get_voice_cfg()` (new static getter) + `NarrativeVoiceService.apply_round_bark_budget(projected_actors, voice_cfg)` — pure and static, run on the projected snapshot rows by `EncounterSnapshotBuilder.build_round_snapshot()` and `FlowEncounterState.build_final_snapshot()`, never on `ectx.actors`, so both builders keep their `_bark_line` purity. Losing rows get `bark_line` cleared; survivors are stamped `bark_priority` (additive projected field). The UI keeps only ordering and interleaving and sorts on `bark_priority`; its literal cap and tier table are deleted.

`ectx.round_bark_events` was deliberately NOT capped. It is the reactive-bark trigger queue, not a display stream — it holds no reactions at all, so `reactions_exceed_cap` and `max_reactions_per_original` cannot describe it. Capping it would have been a sim behaviour change with no authorisation in the data.

**MEASURED: the cap has never bound.** A probe on `apply_round_bark_budget` across the full 1500-test suite recorded, for production fixtures, 1412 snapshots with 0 barks, 426 with 1, and 2 with 2. Maximum ever offered in one snapshot: **two**. Zero reactions ever reached a projection. The mechanism is `FlowRuntime.dispatch()`\'s per-snapshot `_bark_line` clear plus one actor acting per dispatch: a reaction is written on the reacting actor during ITS OWN turn, a dispatch later than the original it answers. So `max_reactions_per_original` and `reactions_exceed_cap` are unexercised in play today, and the three-bark cap is unreachable through the current per-actor snapshot cadence. Suite: 1500 -> 1508, nothing re-recorded.

**Open question for the product owner:** `combat_divergence` was tier 2 in the deleted UI table and is absent from `data.voice.bark_tiers`, so it now ranks 3. Adding it to `bark_tiers` is a one-line config edit that this slice was forbidden to make. |
| **D04** | Mid-combat level-up syncs stats to the wrong place and full-heals the actor | `core/progression/ProgressionService.gd:475-486` (`apply_mid_combat_kill_xp`) | `var old_max_hp: int = int(actor.get("max_hp", 0))` — same top-level-vs-`stats` error as D01, so `old_max_hp == 0`; then `hp_gained = new_max_hp - 0` and `actor["current_hp"] = mini(cur_hp + hp_gained, new_max_hp)` → **full heal on every mid-combat level-up**. Separately the loop writes `actor[stat_key]` top-level for `atk/def/agi/int/cha/speed/max_hp`, but combat reads `actor["stats"]` (`CombatService.gd:123` reads `a_stats.get("atk")`) — so only `speed` (genuinely top-level on `EchoActor`) actually takes effect. | **Yes** — called from `_resolve_next_actor` after every kill (docstring `:441`). | Large and unintended: an Echo that levels mid-fight is silently restored to full HP; its atk/def gains do not apply that fight. | Read/write through `actor["stats"]`, and compute `old_max_hp` from it. Decide separately whether the partial heal is wanted at all. | **FP + BL.** Removes an unintended full heal → changes damage, KO timing and round counts in any fingerprinted mode where a kill levels an Echo. Sequence with D01. |

### Group B — other broken-but-live
| ID | Title | Verified location | Evidence | Reachable | Player impact | Action | Blast radius |
|---|---|---|---|---|---|---|---|
| **D05** | Stage completed with no encounter pays nothing and is flavoured as a defeat — ✅ **CLOSED, verified 2026-08-27** | `core/runtime/controllers/VentureController.gd:519` (header `:137-139`) | `# KNOWN DEFECT 1 (see header): with no encounter_ctx this defaults to "loss".` Feeds `apply_encounter_emotion_drift` and the bond hooks; the Thread segment is written `broken` with grade `"F"`. Also in handoff §8. | **Yes** — any stage finished without triggering an encounter. | High. Player completes content, receives no reward, an emotional penalty and a broken Thread. | Assigned to Phase 8 / `EncounterResolutionService`. Confirm the intended no-encounter grade with the owner (see "Needs the product owner"). | **BL** — `VentureCharacterizationTests` pins the current loss payload. `—` for FP. **CLOSED 2026-08-27.** `VentureController.NO_COMBAT_GRADE = "C"` (`:164`); settlement runs on `is_combat_victory or not has_encounter` (`:659`). A stage cleared without a fight pays and grades "compromised" (`:681-688`), recorded in place as a judgement rather than a repair. The product-owner question is answered. |
| **D06** | Contact resolution runs none of the six post-encounter steps | `core/runtime/controllers/ContactController.gd:105-111` (header) and `:463-468` (`apply_contact_outcome`) | "runs NONE of the six resolution steps that a combat result runs — ally teardown, emotion drift, bond triggers, sanctum emotion tick, vow discovery, vow release." | **Yes** — every contact conversation resolution. | High. Contacts do not move emotion, bonds or vows; a whole social path is inert relative to combat. | Phase 8 via `EncounterResolutionService`. **DEFERRED-BY-DECISION already; listed here because the impact is player-visible, not cosmetic.** | **BL** heavy — turning on six steps moves contact resolve payloads and the Sanctum emotion tick. `—` for FP. |
| **D07** | Scout-return party preview always shows a constant emotional status | `core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd:70-74` | `EchoActor.from_echo()` flattens emotion to top-level `morale`/`fear` and emits no `emotion` key (confirmed `core/actors/EchoActor.gd:57-59`), so `_a.get("emotion", {})` is always `{}` and every preview renders `get_emotional_status(50, 0)`. Duplicate record: `docs/resolve-snapshot-block-spec.md:6.3 item 2` (which cites the now-stale `FlowRuntime.gd:4340`). | **Yes** — every retreat and return-home resolve card. | Medium. The card lies about party state at exactly the moment the player is deciding whether to push on. | Read the flattened `morale`/`fear` directly. One-line fix, no config change. | **BL** — `VentureCharacterizationTests` pins the scout-return payload byte-for-byte. `—` for FP. |
| **D08** | Retreat RNG fallback uses a different seed namespace from the primary path | `core/runtime/FlowRuntime.gd:1055` vs `:1057`. **Handoff said `:1017` — stale, corrected.** | `get_rng("encounter.retreat." + encounter_id + "." + str(t))` vs fallback `hash("encounter.retreat." + encounter_id + str(t))` — **no dot** before the tick. | **No** — fallback only runs when `flow_ctx.campaign_seed == null`, which does not occur in a booted campaign. Pinned as unreachable by `CombatBaselineTests`. | None today. | Add the dot when the surrounding code is next touched. Zero-risk. | `—` (unreachable path). |
| **D09** | Wave reinforcements silently placed at `{0,0}` when cells run out | `core/combat/CombatRoundSpawnService.gd:393-402` (terrain path) and `:419+` (legacy path) | `if _w_cell_idx >= _w_candidate_keys.size(): break` — the loop stops assigning positions but the already-built actors in `_w_new_actors` are appended to `ectx.actors` regardless, keeping `EnemyActor`'s default `grid_pos {0,0}` — the **echo** side, possibly overlapping a living actor. | **Yes but rare** — needs a nearly-full board (ENDURE late waves). | Enemies materialising inside the player's formation. | Skip or defer unplaceable spawns. | **BL** — `CombatBaselineTests` ENDURE hashes. `—` for FP unless actor count changes. |
| **D10** | `_double_damage_mult` is never cleared on totem recovery | `core/combat/CombatRoundObjectiveService.gd:127-130` (header) | Written on theft, cleared never; its partner `_carrier_double_damage` *is* cleared. Inert only because `CombatService.gd:75-76` gates on `_carrier_double_damage` first. | Yes (PROTECT mode), but inert. | None today; one gate-order change makes it a live 2× damage bug. | Clear both together. | `—` |
| **D11** | `_carrier_double_damage` cleared only when the carrier dict is still findable | `core/combat/CombatRoundObjectiveService.gd:122-126` | Recovery branch is written as if actors can be removed from `ectx.actors`; the spine only marks `is_dead`. | **No** — the removal case does not occur. | None. | Simplify or leave; document. | `—` |
| **D12** | Shrine drain: sentinel-keyed fallback + unfiltered rescan | `core/combat/CombatRoundShrineService.gd:226-231` (header notes `:124-133`) | `if shrine_hp_val == 0:` cannot distinguish "no living shrine" from "hp landed on 0"; the fallback scan at `:227` does **not** filter `is_dead`, so after the shrine dies every later round reports the dead shrine's hp. | **Yes** — every PURIFY_SHRINE encounter past the shrine's death. | Low-medium: the HUD/`combat_result` shrine HP readout is wrong after death. | Return an explicit `{found, hp}`; filter `is_dead`. | **FP** — `shrine_hp` is in the final-snapshot key set for PURIFY_SHRINE. **BL** too. |
| **D13** | Shrine loop drains only the first structure; cooldown + morale drain nested inside it | `core/combat/CombatRoundShrineService.gd:190-224` (header notes `:134-140`) | `break` after one structure; the purifier-cooldown decrement and party morale drain sit **inside** the shrine loop, so both stop the moment the shrine dies and would double-run if two shrines existed. Read as written, both look intended to be per-round. | **Yes** — the "stops on shrine death" half is reachable today; the two-shrine half is not (no authored two-shrine encounter found). | Medium: party morale pressure ends early, changing the felt difficulty curve of PURIFY_SHRINE. | Hoist the cooldown + morale drain out of the loop. Confirm intent with the owner. | **BL** — morale per actor per round is baselined. **FP** where morale reaches the final snapshot. |
| **D14** | Guide-spirit hazard deaths record the sim tick as `death_round` | `core/movement/LiveHazardOutcomeService.gd:70` (documented `:34`) | `actor["death_round"] = t` — `t` is the sim tick, not the round counter. | **Yes** — GUIDE_SPIRIT hazard deaths. | Low; corrupts any post-hoc "died in round N" readout. | Pass the round counter. | **BL** if `death_round` is in any pinned payload — **UNVERIFIED** whether it is; check before scheduling. **FIXED, pass 7 (2026-08-28).** Readers audited first: `RecruitmentService.gd:378-381` divides `death_round` by `rounds_total` (round semantics, the only consumer that arithmetic on it); `ActorStateMachine.gd:579` passes it through into actor snapshot data; every other writer already stores a round — `ActorStateMachine.gd:93` (`context.get("round", t)`), `CombatService.gd:88`, `CombatRoundShrineService.gd:175`. No reader depends on it being a tick. So the field name is right and the value was wrong: `LiveHazardOutcomeService.apply()` now takes a `round: int` and writes it. All six production call sites pass their round in scope (`CombatRoundGuideSpiritService` ×4, `FlowRuntime.gd:1401`, `LiveMovementContextService` via `ctx.get("round", t)`). **Not in any pinned payload** — the fingerprints hash top-level `data_keys`, and no baseline pins a hazard death. Nothing re-recorded. STILL STALE, NOT TOUCHED: `ActorSchema.gd:39` and `CONVENTIONS.md:307` both document the field as the sim tick. |
| **D15** | `_gs_spirit_pos` goes stale in the protect branch | `core/combat/CombatRoundGuideSpiritService.gd:200` captured, refreshed at `:289` only on one branch; re-read at `:214/:234/:249` | The protect path evaluates adjacency against a position captured before the spirit may have moved. | Yes (GUIDE_SPIRIT protect). | Low-medium: escort/protect adjacency judged one step late. | Re-read after any spirit move. | **BL** — GUIDE_SPIRIT baseline. |
| **D16** | Unrecognised `guide_mode` silently does nothing | `core/combat/CombatRoundGuideSpiritService.gd:162-163` | `return guide_mode == "escort" or guide_mode == "protect"` — any other value disables the whole phase with no warn. | **No** — only two values are ever written today. | None. | Warn on unknown mode. | `—` |
| **D17** | Escort win latch can fire on a spirit that never moved | `core/combat/CombatRoundGuideSpiritService.gd:298-302` (`escort_started` "set once and never cleared", `:49`). Producer side now at `core/combat/EncounterObjectiveSpawnService.gd` (escort-destination block, moved from `FlowEncounterState.gd:764-812` by slice 6I). | Destination match is checked without requiring movement to have occurred. | **ANSWERED 2026-08-24, slice 6I — YES, overlap is possible, via the relaxation branch.** The producer picks the spirit's spawn cell as `_gs_candidates[0]` and then picks the destination out of `_gs_far_candidates`, which is `_gs_edge_candidates` filtered to Chebyshev distance `>= destination_min_distance` (6). While that filter holds, overlap is impossible. But when **no** frontier cell clears the distance, the code relaxes to `_gs_far_candidates = [_gs_edge_candidates[0]]` after sorting by distance **descending** — with **no distance floor at all**. `_gs_edge_candidates` is a subset of `_gs_candidates`, which contains the spawn cell, so if the spawn cell is itself a frontier cell and is the only frontier cell among the unoccupied walkables, the farthest edge cell IS the spawn cell and destination == spawn. The latch then matches on round 1. Needs a terrain island with exactly one unoccupied frontier cell — rare, but not impossible, and StageTerrain can produce small pockets. | Instant escort win, one round, no movement. | **Do not change the relaxation, change its floor:** require `dist > 0` (or `>= 1`) in the relaxed branch, and fall through to no destination when even that fails. Do NOT chase it in the latch — the latch is correct given a valid destination. | **BL** if reachable in a shipped seed — the seven mode fingerprints pin GUIDE_SPIRIT end-of-round positions, and today no shipped seed hits the relaxation branch (`combat_baseline` is green on the current terrain). Adding the floor moves nothing until a seed reaches it. |

---

## Kind 2 — DEAD-SUPERSEDED
*No caller, or replaced. Delete.*

| ID | Title | Verified location | Evidence | Reachable | Impact | Action | Blast radius |
|---|---|---|---|---|---|---|---|
| **D18** | `title` — dead snapshot key, zero consumers | `core/state/flow/states/venture/ResolveSnapshotBuilder.gd:213-219` (block 16); emitted by producers A, B, F. Also `core/state/flow/states/FlowResolveState.gd:22-24`. | "`title` is a dead key with zero consumers in `ui/`, `core/` or `tests/`." Duplicate record: `docs/resolve-snapshot-block-spec.md:136` and `:449`; handoff `:403` (Q3 decision). | Written every resolve; read never. | None. | **Delete — decision already taken to defer, not to keep.** Handoff Q3: kept in Phase 5 only because deletion drifts producer A's seven fingerprints, "cheap to re-record in Phase 6". Do it with the next fingerprint re-record. | **FP — moves all seven `data_keys` hashes.** Bundle with D01/D04. **✅ FIXED, connect case 4/4, 2026-08-28.** Re-verified unread first: `title` has no reader in `core/`, `ui/`, `tests/`, `tools/` or any `.tscn` — `ResolveScreen.gd` never names it, and the other `"title"` hits in the repo belong to unrelated snapshot types (sanctum, summon, realm select, stage map, keeper intro, save error). Block 16 and all four producer calls (A `FlowEncounterState`, B `EncounterSnapshotBuilder`, F `FlowResolveState`, G's replay line in `PendingResultService`) deleted. Seven FINAL hashes re-recorded; **no ROUNDS hash and no SAVE hash moved.** Attribution measured by diffing the fourteen FP_DEBUG payloads field by field: `data_keys` is the ONLY field that differs anywhere, and the only difference in it is the removal of `title` (24 keys → 23). |
| **D19** | `note` — dead snapshot key, zero consumers | `core/state/flow/states/venture/ResolveSnapshotBuilder.gd:221-226` (block 17); producer F only. | Same as D18. Duplicate: spec `:137`, `:449`. | Written on the fallback resolve only. | None. | Delete with D18. | **FP** (producer F has no test anywhere — see D34 — so the fingerprints are the only guard). **✅ FIXED, connect case 4/4, 2026-08-28.** Same verification as D18: `note` has no reader anywhere, including scenes. Block 17, producer F's call and G's replay line deleted. `note` reached no fingerprinted producer, so it moved nothing on its own — the seven FINAL hashes moved because of `title` alone. |
| **D20** | `verdict` written by producer D into a badge the screen always hides — **CLAIM DISPROVED** | `core/state/flow/states/venture/ResolveSnapshotBuilder.gd:94-99` (block 4) and `core/runtime/controllers/ContactController.gd:752-755` | "`ResolveScreen`'s contact renderer sets `_rank_badge.visible = false` unconditionally." Duplicate: spec `:6.3 item 3`. | Written on every contact resolve. | None — invisible. | Decide: show the badge on contacts, or drop the key. Design question, not technical (see "Needs the product owner"). | `—` for FP (D is not fingerprinted); **BL** — `VentureCharacterizationTests` asserts the contact card writes `verdict`. **DISPROVED 2026-08-27.** `ui/screens/venture/ResolveScreen.gd:262-268` shows the badge whenever `verdict` is non-empty, and hides it only when the string is empty. The "hidden unconditionally" claim describes the reset and clear paths (`:484`, `:512`), not the contact renderer. This is the **third** disproved entry, with D34 and D41. Original claim kept visible per the conversion rules. |
| **D21** | `_find_target_situation` / `_mark_situation_revealed` — 114 dead lines | Handoff `:319-320` cites `FlowRuntime.gd:6348-6433` and `:6656-6683`. **Both are gone — the file is now 2,070 lines and neither symbol exists.** | Grep for both names returns nothing in `core/`, `ui/`, `tests/`. | n/a | none | **RESOLVED** — deleted during Phase 5. Record kept per the rules. | `—` |
| **D22** | `flow.select_stage` had a provisional owner | Handoff `:487-491` | Blocked by a controller-to-controller call; moved to `core/progression/SkillLoadoutService.gd` in slice 6F. All 73 actions now have exactly one owner. | n/a | none | **RESOLVED (slice 6F).** | `—` |
| **D23** | Producer C emitted `meta.sim_tick`, tripping `assert(false)` | Handoff `:400-402`; spec `:6.1` / `:6.3 item 1` | `FlowStateMachine._validate_snapshot()` asserts on a missing `t`. Fixed in slice 5B (Q1 approved); three characterization tests were inverted rather than deleted. | n/a | none now | **RESOLVED (slice 5B).** | `—` |
| **D24** | `_project_actor` mutated the actor it projected | Handoff `:252`; probe `tests/FlowSnapshotFingerprintTests.gd:33` ("no longer tagged KNOWN DEFECT") | Fixed in Phase 3; the probe assertion was inverted to "must not mutate". | n/a | none | **RESOLVED (Phase 3).** | `—` |
| **D25** | `_build_scout_return_snapshot` consumed its own one-shot inputs | Handoff `:311-314` (cites stale `FlowRuntime.gd:4352-4353`) | Consumption moved to the dispatch closure in slice 5B, gated on `type == flow.resolve` **and** `data.run_type == "scout_return"`. Now at `core/runtime/FlowRuntime.gd:1094`. | n/a | none | **RESOLVED (slice 5B).** Guard preserved deliberately in 5E (see handoff `:527-537`). | `—` |
| **D26** | `_fresh_save_path()` deleted only the primary save artifact | Handoff `:343-352` | A leftover `.bak1` made `boot()` recover the previous campaign; produced 9 false fingerprint failures. Fixed by `tests/TestSaveHarness.gd`, adopted by 22 suites. | n/a | none | **RESOLVED (slice 5.0).** Highest-value fix of the story. | `—` |

---

## Kind 3 — WRITTEN-NEVER-READ
*Produced and stored, nothing consumes it. Connect or delete.*

| ID | Title | Verified location | Evidence | Reachable | Impact | Action | Blast radius |
|---|---|---|---|---|---|---|---|
| **D27** | Movement decision (`goal_id` / `option_id`) is never stored or logged | `core/runtime/FlowRuntime.gd` `_resolve_next_actor` (handoff `:597-600`) | Private local, never persisted. **"A refactor that reaches the right cell for the wrong reason passes silently."** Stated in the handoff as a permanent gap. | n/a — it is an observability hole, not a mechanic. | None directly; it is the reason the whole movement refactor is under-guarded. | Log the decision. Needs a production change → own story. | `—` (adds a log only). Do it **before** the `_movement_*` verbatim move, not after. **FIXED, pass 7 (2026-08-28).** The values were already on the activation result contract (`MovementResult` fields `goal_id` / `option_id`, built at `CombatActivationService.gd:235-236`), so no new plumbing was needed. `LiveMovementContextService.gd:502` now logs both on `actor.moved`. Verified populated for an ordinary echo, not just a guide spirit: `echo_0005`, faction `echo`, `goal_id=goal.combat.engage.baseline.c9r1`, `option_id=option.combat.engage.baseline.c9r1.direct.d3r4.pc2r5-c3r4`. The superseded KNOWN GAP header on that file was deleted. **D57 is now unblocked.** |
| **D91** | `BehaviorArbiter` reads `objective_modes` off `data.actor`, where the key does not exist — both reads are dead | `core/actors/behaviors/BehaviorArbiter.gd:1761` (`objective_threatened_radius`) and `:1788` (`quarry_near_exit_threshold`). Constructor at `:279-281` takes `actor_cfg` = `data.actor`; the authored keys live under `data.combat.objective_modes.protect` / `.pursue`. | **FOUND during fix pass 1 (2026-08-28), NOT touched.** `data.actor` has no `objective_modes` child (checked against `data/balance.json`), so both `_cfg.has("objective_modes")` guards are false and both values fall through to their hardcoded defaults, 3 and 3. The authored values are also 3 and 3, so no behaviour differs today. | Yes — the code runs every PROTECT and PURSUE turn; it just never sees config. | None today. Latent: retuning either authored value in `balance.json` would silently do nothing. | Inject `data.combat.objective_modes` into the arbiter (constructor arg or the per-turn context), then delete the `_cfg` fallback. The arbiter holds no `ConfigService` by design, so this cannot be routed through `ConfigService.get_objective_modes_cfg` at the read site. Own change; not a config-ownership fix. | **FP/BL** the moment an authored value stops equalling its default. `—` while both are 3. |
| **D28** | `total_waves` frozen on the first ENDURE round | `core/combat/CombatRoundSpawnService.gd:317-323` (`if not combat_state.has("total_waves")`), read back at `:437`/`:445` | Computed once from the interval range; if the encounter's duration config changes mid-fight the stale count drives `all_waves_spawned`. Also: `total_waves` and `initiative_order` are **outside fingerprint cover** (handoff `:653-657`) — guarded only by `combat_baseline` and `objective_combat`. | Yes; harmless while duration is immutable. | None today. | Leave, but record the fingerprint gap. | `—` |
| **D29** | ~60 duplicated placement lines including a determinism-critical sort | `core/combat/CombatRoundSpawnService.gd:367-402` vs `:404-435` | Character-for-character duplicates, now confined to one file — "which is the precondition for fixing it". | n/a | none | Deduplicate. Pure refactor, but the sort is determinism-critical → must be byte-identical. | **BL** if the sort changes at all. |
| **D30** | `data.combat.objective_modes` has no `ConfigService` owner — read longhand at 5 sites | Sites verified: `core/combat/CombatRoundObjectiveService.gd` (×3, header `:116-120`), `core/combat/CombatTurnContextService.gd:73-75`, ~~`core/state/flow/states/venture/FlowEncounterState.gd:347`~~ → **`core/combat/EncounterSetupService.gd:420` (moved, slice 6I 2026-08-24)**, `core/runtime/FlowRuntime.gd:2232` — **the last is stale, `FlowRuntime.gd` is now 2,070 lines.** `BehaviorArbiter.gd:1761/1788` read the same subtree from a pre-narrowed dict. | Two headers record this independently (4 sites, then a 5th). Merged here. | n/a | none | Add `ConfigService.get_objective_modes_cfg()`. Deliberately not done during extraction because the reads were *moved*, not copied. **FIXED 2026-08-28 (fix pass 1).** `ConfigService.get_objective_modes_cfg(config_service)` plus a `_from_balance` variant (the `get_enemy_actor_cfg` precedent) added at `core/config/ConfigService.gd:308-330`. Four production reads routed through it: `CombatRoundObjectiveService.gd` (theft ×2 collapsed to one lookup, guard ×1), `EncounterSetupService.gd`, `CombatTurnContextService.gd` (via `_from_balance`, which also closes D53). The `FlowRuntime.gd:2232` site is confirmed gone. **`BehaviorArbiter.gd:1761/1788` NOT routed and NOT touched** — its `_cfg` is `data.actor`, which has no `objective_modes` key, so both reads are dead and always fall through to their hardcoded defaults (3 and 3). Those defaults happen to equal the authored `objective_threatened_radius` and `quarry_near_exit_threshold`, so nothing moves today, but routing them would need config injected through the arbiter's constructor (it holds no `ConfigService` by design) and is a separate change. Logged as **D91**. | `—` |
| **D31** | `data.combat.shrine` has no `ConfigService` getter | `core/combat/CombatRoundShrineService.gd:189` | Read longhand as it was in `_end_round`. | n/a | none | Same as D30. **FIXED 2026-08-28 (fix pass 1).** `ConfigService.get_shrine_cfg()` added at `core/config/ConfigService.gd:333-345`; the one read routed through it. | `—` |
| **D32** | `ConfigService.get_rewards_cfg` has no `config_service == null` guard, unlike its siblings | `core/config/ConfigService.gd:278-285`; sibling with the guard at `:263-264` (`get_economy_cfg`). Originally recorded in `core/realms/StageExploreSessionService.gd` header (that file is now `core/realms/ActiveStageService.gd` — renamed by Half A review correction C4, 2026-08-24) / handoff `:381-383`. | **VERIFIED.** `get_rewards_cfg` calls `config_service.get_balance()` on line 279 with no null check; `get_economy_cfg` opens with `if config_service == null:`. | Yes — any caller reaching it before config load nils out. | None observed (config loads at boot). | Add the guard for parity. **FIXED 2026-08-28 (fix pass 1).** `core/config/ConfigService.gd:281-282` now opens with `if config_service == null: return {}`, matching `get_economy_cfg`. Behaviour-neutral in practice: every caller passes a live `ConfigService`, and the previous code would have crashed on null rather than returning a different value. | `—` |
| **D33** | The realm XP multiplier formula is written twice from two sources | `core/state/flow/states/venture/FlowEncounterState.gd:682` (was `:1830-1835`; **re-verified after slice 6I**) (`realm_xp_mult = 1.0 + float(run_index) * mult_rate`, `run_index` from `:590`) vs `core/progression/ProgressionService.get_realm_xp_multiplier()` at `:275-287` | Two independently sourced `run_index` values; "collapsing them is behaviour-adjacent, not extraction, because the two sources may differ." | Yes — both run. | Unknown; they may already disagree. | **Measure whether they differ before collapsing.** If they do, that is a live XP defect, not a duplication. **MEASURED 2026-08-24, slice 6J — THEY CANNOT DIFFER. This is pure duplication, not an XP defect.** Standing at the site (now `FlowEncounterState.gd:169` for `run_index`, `:261` for the formula, after slice 6J moved 589 lines out of this file): the inline path reads `RealmService.get_active(flow_ctx)` which is literally `save_data["realms"][flow_ctx.realm_id]` (`RealmService.gd:143-147`); `ProgressionService.get_realm_xp_multiplier(realm_id, save_data, prog_cfg)` reads `save_data["realms"][realm_id]["run_index"]` (`:281-288`). Same dict, same key, and its only caller passes `flow_ctx.realm_id` (`ContributionLedgerService.gd:206`). The two "independent sources" are one source. Every guard branch agrees too: empty `realm_id` -> `get_active` returns `{}` -> `run_index` 0 -> `1.0 + 0*rate` = 1.0, which is what the service's early return also gives; `rate <= 0.0` -> the inline `if mult_rate > 0.0` leaves `realm_xp_mult` at 1.0, same as the service. So collapsing the inline formula onto `ProgressionService.get_realm_xp_multiplier()` is a **behaviour-neutral deduplication**, not the behaviour-adjacent change this row assumed. | **FP** if they differ and the fix changes awarded XP. **Revised after the 6J measurement: `—`.** They do not differ, so the collapse moves no XP and no fingerprint. |
| **D34** | `STATE_ESCAPED` "written and never read" — **claim corrected** | Written at `core/runtime/controllers/VentureController.gd:343`; read at `core/realms/StageExploreTurnService.gd:119` (gates `advance_turn`), `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd:67/279/445`, rendered at `ui/screens/venture/StageExploreScreen.gd:602`. | The handoff (`:270`) says it is never read. **That is wrong as written**: `party_state` is read generically — it gates further exploration and is displayed capitalised in the UI. What is true is that **no code branches on `STATE_ESCAPED` specifically**. | Yes | None. | Downgrade to a note. Do not delete the constant. | `—` |
| **D35** | Producer B omits `direction` and `tag` from emotion entries | `core/state/flow/states/venture/ResolveSnapshotBuilder.gd:147-153` (block 9) | A adds `direction` + `tag`; E adds both plus `bark`; B has neither → the keeper-trial resolve renders grey default tokens and no direction cue. Duplicate: spec `:6.3 item 5`. | Yes — every keeper trial resolve. | Low-medium: the trial's emotional outcome reads as neutral when it is not. | Add the two keys to B. | **FP** — B is fingerprinted (`data_keys`). **FIXED, pass 7 (2026-08-28).** `EncounterSnapshotBuilder._build_keeper_intro_emotion_summary` now matches producer A (`FlowEncounterState.gd:275-306`) exactly: same eight keys in the same order, `direction` from `_emotional_status_rank(pre)` vs `(post)` → lift/fall/steady, `tag` = `ko` if `is_dead` else `refused` if `fear >= FEAR_THRESHOLD_DEFAULT` else `""`. **The predicted fingerprint move did NOT happen.** `FlowFingerprintTests.gd:238-244` hashes the sorted **top-level** `data.keys()`; `emotion_summary` is one such key and its entry shape is not hashed. Nothing re-recorded. |

---

## Kind 4 — LIVE-DEFECT
*Runs, reachable, behaves wrongly.*

| ID | Title | Verified location | Evidence | Reachable | Player impact | Action | Blast radius |
|---|---|---|---|---|---|---|---|
| **D36** | Quit-at-Resolve keeps the reward but never advances the stage — **PARTIALLY CONFIRMED, 2026-08-24** — ✅ **CLOSED, verified 2026-08-27** | Payment: `FlowEncounterState.gd:624` (`reward_stage_complete`) + `:641` (`request_save("stage.reward")`) + `:682` (post-combat XP), all inside `build_final_snapshot` (`:458`) — **line numbers re-verified after slice 6I moved 979 lines of setup out of this file**, called from `FlowRuntime.gd:1483`. Flush: `FlowRuntime.gd:566-583`, same dispatch. Advance: `VentureController.gd:613` → `RealmService.gd:199-219`, reachable only via `flow.complete_stage` (`FlowRuntime.gd:239-240`). Between them sits the Resolve screen, whose only actions are the two `flow.complete_stage` CTAs (`FlowEncounterState.gd:851-882`). **Original handoff claim at `:265` gave no location and said "replayable for full reward"; that wording is kept here and corrected in Evidence.** | **Confirmed:** reward, Ekwan and XP are banked and flushed to disk in the combat-end dispatch; `current_stage_index` advances only in a later player-initiated dispatch; nothing records that the stage has paid. **Corrected:** the *same* encounter is NOT replayable — `FlowRuntime.gd:1469-1470` resolves the situation pre-snapshot (`StageExploreSessionService.gd:461-527`) in the same flush. What IS repeatable: (a) every other combat situation in the stage pays another FULL stage reward, because `base_reward` sums the stage's objective weights and ignores which situation was fought (`RewardCalc.gd:31-38`); (b) a **defeat** pays `base*0.25*redo_mul` (`EconomyService.gd:139-152`, verified by the orchestrator) and never resolves the situation, so one fight can be lost for Ase indefinitely. `redo_multiplier` keys on realm `run_count`, not stage repeats (`RewardCalc.gd:53-56`). Root mechanism: **D77**. | **Yes — one tap, and accidental.** `ResolveScreen.gd:51-52` offers no back or quit control; `AppRoot.gd:361-366` handles only `KEY_F1`; there is **no** `WM_GO_BACK_REQUEST` / `WM_CLOSE_REQUEST` / `APPLICATION_PAUSED` handler anywhere in `ui/` or `core/`, and `project.godot` leaves `quit_on_go_back` unset at its `true` default — **both verified by the orchestrator**. So the Android system Back button at the Resolve screen quits the app. Relaunch → `flow.continue` → Sanctum; the stage still renders `"current"` (`FlowStageMapState.gd:62-67`) and re-entry preserves the locked map and resolved flags (`FlowStageExploreState.gd:56-120`, `:197`; `locked` is never cleared in `core/`). | **High, and accidental as often as deliberate.** Per quit: full stage Ase + Ekwan + party XP kept, stage uncompleted. Re-earnable ≈130–160 Ase + 16–19 Ekwan + 40 XP × party per remaining combat situation (typically 0–2 per stage), plus an **unbounded** ~15 Ase per deliberate defeat. | **Move payment out of the snapshot builder** — relocate `FlowEncounterState.gd:617-641` into `VentureController.handle_complete_stage` ahead of `advance_stage` (`:613`), so payment and advance are one dispatch. This also fixes D05's no-encounter case. Stopgap: a per-situation `rewarded` stamp. Do NOT fix via `advance_stage` — D40's guard is not on this path. After-Phase-9 group; dispatch-count check first. | **FP + BL, confirmed.** `FlowFingerprintTests.gd:251-252` hashes `ase_awarded`/`ekwan_awarded` out of the resolve snapshot → moving payment zeroes both across every combat mode. `CombatBaselineTests.gd:90/399` pins per-dispatch flush reasons → `"stage.reward"` leaves the combat dispatch. `VentureCharacterizationTests` pins resolve payloads. `FlowSnapshotFingerprintTests.gd:333-340` must be **rewritten**, not flipped (D76). Bundle with D01/D04/D18/D19/D35/D50. **SLICE 6J (2026-08-24) — locations re-verified again; nothing moved.** After 6J extracted 589 lines into `EncounterSnapshotBuilder.gd`, the payment lines are `FlowEncounterState.gd:203` (`reward_stage_complete`), `:220` (`request_save("stage.reward")`), `:264` (`award_post_combat_xp`), plus the roster emotion write-back, all still inside `build_final_snapshot` (now `:37`). 6J deliberately left every one of them where it was and said so in a comment at `:399-405`; the function stayed on `FlowEncounterState` for exactly this reason while the pure half of the file became a builder. **New supporting evidence: producer B already demonstrates the target architecture.** `_build_keeper_intro_final_snapshot` (now `EncounterSnapshotBuilder.gd:564`) emits `ase_awarded: 40` as a pure DISPLAY value and pays nothing; the 40 Ase actually lands in a later, player-initiated dispatch (`keeper_intro.trial.finish` — pinned by `onboarding/_t_keeper_trial_rewards`, which sees `economy.ase == 40` only after that dispatch). That is precisely the settle-at-completion shape D36/D77 want for producer A, already shipped and already tested on the keeper-trial path. **CLOSED 2026-08-27.** Payment left `build_final_snapshot`. `core/economy/StageSettlementService.settle()` (`:92`) pays inside the same dispatch as `advance_stage`, guarded by the persisted `settlement_receipt` it reads at `:108-110` and writes at `:163`. No screen sits between payment and advance any more, so there is no window to quit inside. |
| **D37** | Victory-return path can double-increment `objectives_found` | `core/realms/ActiveStageService.gd:100-101` (DEFECT 1; file renamed from `StageExploreSessionService.gd` by Half A review correction C4, 2026-08-24 — rename only, no body changed) — the `(B)` path, `skip_if_already_resolved=false`. Duplicate: `core/runtime/controllers/VentureController.gd:143-147` (KNOWN DEFECT 3); handoff `:378-380`. | The `(B)` inline block had no already-resolved guard and re-runs the mutation on a second pass. Both call sites' behaviour is now explicit named parameters — the drift is visible, not fixed. | Yes — non-final-objective victory returns. | Objective count over-reported → stage completes early / rewards inflated. | Set `skip_if_already_resolved=true` on (B). One-parameter fix, now that the parameter exists. | **BL** — `VentureCharacterizationTests`. `—` for FP unless `objectives_remaining` reaches the final snapshot (it does for producer A → check). |
| **D38** | Victory-return path commits, saves and logs even when nothing matched | `core/realms/ActiveStageService.gd:102-105` (DEFECT 2 — header note, re-verified after the C4 rename; file renamed by Half A review correction C4, 2026-08-24 — rename only), same `(B)` path, `commit_only_when_modified=false` | With an unmatched `last_situation_id` it still writes the stage back, requests a save, and logs "Non-final objective resolved on victory" for a situation it never touched. | Yes | Spurious saves and a lying log line; masks real resolution failures. | Flip the parameter. Pairs with D37 — **one fix, two flags.** | **BL** — save-reason strings are pinned by `CombatBaselineTests` per-dispatch flush counts. |
| **D39** | `get_stage_base_reward()` reads `objectives[0]` only → double pay on multi-objective stages — ✅ **CLOSED, verified 2026-08-27** | ~~`core/realms/StageExploreSessionService.gd:269`~~ → **`core/realms/ActiveStageService.gd` (same function, file renamed by Half A review correction C4, 2026-08-24; body byte-identical)**; call site `core/runtime/controllers/VentureController.gd:358-362` (KNOWN DEFECT 2). Duplicate: handoff `:264`. **RE-VERIFIED AT THE SITE during C4:** the function reads `_objs[0].obj_type` and nothing else — it does not sum, does not select by objective status, and does not look at how many objectives the stage has. It then looks that single type up in `ConfigService.get_rewards_cfg().objective_weights`. Note the shape difference from D77's `RewardCalc.base_reward`, which SUMS the stage's objective weights: the two "base reward" readers for one stage disagree by construction, so the retreat/partial payout and the stage-completion payout are computed on different bases. Whatever D39 is answered with must be answered for both, or the disagreement becomes permanent. Not fixed — C4 was a rename. | "a multi-objective stage computes its partial-withdrawal reward from the first objective alone." | Yes — partial withdrawal from any multi-objective stage. | High economic: over- or under-pays depending on objective ordering. | Sum or select correctly. Balance decision on which. | **BL**. **CLOSED 2026-08-27.** `ActiveStageService.gd:330` delegates to `RewardCalc.base_reward()`, so both readers sum the stage's objective weights. The product-owner question is answered: **sum**. |
| **D40** | `RealmService.advance_stage()`'s idempotency guard **causes** Thread double-minting | `core/realms/RealmService.gd:207-212` | `if bool(model.get("is_completed", false)): ... return model` — it returns a model whose `is_completed` flag is the caller's crystallize trigger, so the guard hands the caller a second reason to mint. Recorded handoff `:266-268`. | Yes | High — duplicate Threads in Continuity, the game's long-memory system. | Return `{}` or a distinct sentinel on the guard branch. | **BL** — Thread minting is pinned. |
| **D41** | A successful withdrawal is scored as a defeat — **CLAIM DISPROVED** | Dispatch `core/runtime/FlowRuntime.gd:1090` passes `"withdrawal"`; handler `core/emotion/EmotionConsequenceService.gd:258-259`. Handoff `:269` (stale) named `_apply_run_emotion_modifiers` on `FlowRuntime` — that function moved to `EmotionConsequenceService` in Phase 4. | The `match outcome` block has a distinct `"withdrawal"` arm: `morale_mul = modifier_survived_morale_mul` (1.25 — a **boost**). `"defeat"` is a separate arm setting `fear_mul = modifier_defeat_fear_mul`. Withdrawal is not scored as a defeat. | n/a | None. | **RESOLVED / claim incorrect.** Record kept per the rules. Do not act on the handoff line. | `—` |
| **D42** | Ase Flame lights one full chapter early — ✅ **FIXED, Phase 8C, 2026-08-27** | `core/runtime/controllers/OnboardingController.gd:163-171` (header `:62-67`, docstring `:139-140`) | `handle_name_confirm` sets `sanctum.ase_flame.awakened = true` at the end of Chapter I; the intended beat is Keeper Intro's `KEEPER_AWAKENING` step, which also touches `ase_flame`. | **Yes — every new campaign.** | High narrative impact: the Flame's awakening beat is spoiled for every player. | ✅ **FIXED in Phase 8C as a DELETION, not a relocation.** The intended-beat write already existed and already did the whole job idempotently — `KeeperIntroService.awaken_flame()` sets `awakened`, `boost_remaining_seconds` and `boost_per_bank_tick` at `keeper_intro.awakening.choose`. The Chapter I copy was pure duplication, so it was cut rather than moved. Every measured reader was walked before the cut and the consequence of a dark Flame for one more chapter recorded in the code at the deletion site: `OfflineAccrualService:102-107,134` and `EconomySettlementService:132` simply do not accrue during the keeper intro (the gate's stated intent); `FlowSummonState:49-51` is a RATE HINT only — `summon_disabled` is `ase_balance < selected_cost` and nothing else, so **summoning is not gated by the Flame**; `SanctumSnapshotBuilder:386-396` is unreachable in that window because `flow.sanctum` is gated until `keeper_intro.complete`; `SanctumLayoutService:78,110-135` **does not read `awakened` at all** — its `ase_flame` entry is an unconditional layout TILE (the brief that sent this slice listed it as a reader; it is not one). The one visible change is the intended one: `FlowKeeperIntroState:84-96` → `KeeperIntroScreen.gd:65` lights the flame core at the awakening step instead of from the Call onward. `tests/EconomyTests.gd` `economy/awakening_trigger_sets_flag_grants_ase` pinned the WRONG BEAT; it is inverted in place (renamed `economy/name_confirm_leaves_flame_dark`), drive kept, original intent kept visible in its docstring, and the no-Ase half strengthened into a real assertion. New coverage: `onboarding/flame_lights_at_awakening_and_arms_modal`. | **No recorded value moved.** The predicted onboarding save-state fingerprint move did not occur: no fingerprint suite drives the keeper intro past name-confirm, and `FlowFingerprintTests`' SAVE fingerprint reads `economy` + party only. Full suite green with zero re-records. |
| **D43** | KO can be visited twice in one loop → fear spread may double-apply | `core/combat/CombatRoundEmotionService.gd:114-115` (`_ally_killed_barked` guards only the **bark**, not the fear spread) | The bark is latched once per encounter; the fear write is not equivalently guarded. Recorded handoff `:635-638`. | **Unknown** — requires two KOs resolving in one pass; not demonstrated. | Fear inflation on multi-KO rounds. | Reproduce first. | **BL** if real. |
| **D44** | Kill ripple + kill-momentum double-credit one ally for one kill | `core/combat/CombatTurnActionService.gd:96-100` (header note); code at `:294-308` | Both write ally morale in the same turn and both credit the killer through the support tally — an ally inside the `kill_momentum` radius is credited twice (once at `morale_ripple_per_kill`, once at the trait `morale_boost`). | Yes, whenever a leader with `kill_momentum` is in radius. | Contribution ledger over-credits; morale over-grants. | Balance decision — is the stack intended? | **BL**. |
| **D45** | Kill-share denominator excludes structures | `core/combat/CombatTurnActionService.gd:101-104` | `_k_alive_before` excludes structures, so in PROTECT and PURIFY_SHRINE the totem/shrine never contributes to the denominator while it does contribute to the fight. | Yes, those two modes. | XP/contribution shares skewed in exactly the two modes built around a structure. | Include structures, or document the exclusion as intended. | **FP + BL** (XP awarded is fingerprinted). |
| **D46** | "Target already dead" arm logs `actor.idle` for a `melee_attack` intent | `core/combat/CombatTurnActionService.gd:105-107` | The contribution ledger counts that turn as an idle. "Pre-existing and deliberate-looking, recorded because it is invisible from the log line." | Yes | Low; corrupts contribution analytics. | Emit a distinct action type. | **BL**. |
| **D47** | Morale-drain log reports the configured amount, not the applied amount | `core/combat/CombatRoundShrineService.gd:141-145` | `apply_morale_loss` can reduce or fully prevent the loss (`morale_anchor` / `morale_forecast`), and the `maxi(0, ...)` clamp absorbs more, so the logged delta overstates the real one whenever a leader is nearby. | Yes | None to the player; misleads every balance investigation that reads the log. | Log the summed applied delta. | `—` (log text only, unless a suite asserts it). |
| **D48** | Contribution ledger reads `last_round_results.back()` without checking `source_id` | `core/combat/ContributionLedgerService.gd:72-77` | Every path appends exactly one entry per activation so `back()` is always this actor's today — **but the guard four lines further down in `FlowRuntime` does compare `source_id`, so two neighbouring blocks disagree about whether the check is needed.** | Yes, but currently correct. | None. | Make the two agree. Cheap. | `—` |
| **D49** | Support tally erased for non-echo actors without being read | `core/combat/ContributionLedgerService.gd:82-85` | Support work by an ally or spirit is silently discarded. "Pre-existing and deliberate (support metrics are documented as an echo-only signal); recorded because the erase and the gate are easy to misread as a bug." | Yes | None — intended. | Leave; the note is the fix. | `—` |
| **D50** | `party_size` counts structures and temporary allies | `core/combat/CombatTurnContextService.gd:76-77` | The filter tests `faction` and `is_dead` only. | Yes — PROTECT and PURIFY_SHRINE always carry a structure. | Every behaviour weight keyed on party size is off by one in exactly those modes. | Exclude `is_structure`. | **FP + BL** — changes arbiter scoring. |
| **D51** | Spirit-flagged echoes would receive mode directive weights outside GUIDE_SPIRIT | `core/combat/CombatTurnContextService.gd:78-80` | The GUIDE_SPIRIT branch excludes `is_spirit`; the other four branches do not. | **No** — spirits only exist in GUIDE_SPIRIT. | None. | Add the filter for symmetry when touched. | `—` |
| **D52** | `round_bark_events` passed by reference but documented "read-only" | `core/combat/CombatTurnContextService.gd:66-68` | `ctx["round_bark_events"]` is `ectx.round_bark_events` **by reference**; nothing enforces the contract, and `ActorStateMachine` holds the live array and could append. | Yes (latent). | None observed. | Duplicate or make the contract enforceable. | `—` |
| **D53** | Mode-directive block re-reads config instead of the `balance` dict handed in | `core/combat/CombatTurnContextService.gd:202` | Same immutable object in production (`load_balance()` runs once at boot), so they cannot differ today. | Yes, benign. | None. | Use the passed dict. **FIXED 2026-08-28 (fix pass 1).** Now `ConfigService.get_objective_modes_cfg_from_balance(balance)` — one read, of the dict the caller already handed in. | `—` |
| **D54** | `fear_inflicted` credited to the attacker on same-faction hits | `core/combat/CombatTurnActionService.gd:108-109` | No same-faction melee exists today. | **No.** | None. | Leave documented. | `—` |
| **D55** | `round` parameter shadows the built-in `round()` | `core/combat/CombatRoundEmotionService.gd:94`; same shadow documented at `core/combat/CombatTurnContextService.gd:56-60` | Safe today — term D calls the built-in inside that scope and gets the right one; `CombatTurnContextService` never calls `round()` at all. Kept deliberately so the move stays verbatim. | Yes | None. | Rename when the verbatim constraint lifts. | `—` |
| **D56** | `_ally_killed_barked` is an ad-hoc string key where its sibling is a typed field | `core/combat/CombatRoundEmotionService.gd:38`, `:114-115` | Inconsistent state modelling on `combat_state`. | Yes | None. | Type it. | `—` |
| **D57** | Movement adapter criterion 5 orders cells by lexicographic `"col,row"` | `core/movement/StagePartyMovementAdapter.gd:788-795` | `"10,3" < "9,3"` — the induced order is jagged, non-monotone in either axis, and flips its favoured compass direction with coordinate magnitude. **The header explicitly withdraws the earlier justification**: id-less entries were assumed rare/malformed, "since they are in fact ordinary input, that justification does not hold and is withdrawn." | Yes — ordinary input. | Party movement tie-breaks favour a direction that changes with board position. Subtle but real. | Compare `(col, row)` numerically. | **BL** — party movement paths are pinned; this re-rolls stage exploration routes. |
| **D58** | `_mark_save_requested()` joins reasons with `\|` across dispatch boundaries | Handoff `:592-595`; mechanism at `core/runtime/FlowRuntime.gd:1023+` (`for reason in outcome.save_reasons`) | A save queued **outside** a dispatch glues its reason onto the next one. "A controller that queues a save outside a dispatch boundary would silently corrupt the reason string." | Yes (latent — no such controller exists today). | None. | Assert on out-of-dispatch queueing. | **BL** — `CombatBaselineTests` pins per-dispatch save reasons. |
| **D59** | `encounter.advance` has no phase guard; `encounter.complete` transitions from any state | Handoff `:588-589`; dispatch at `core/runtime/FlowRuntime.gd:377-378` region | Both actions are dispatchable out of phase. Pinned by `CombatBaselineTests` as the two dormant actions no test had ever dispatched. | **Unknown** — the UI may never surface them out of phase. | Potential state corruption via debug/automation. | Add phase guards. | **BL**. |
| **D60** | The flow machine never transitions to RESOLVE at end of combat | `core/runtime/FlowRuntime.gd:1485` — `flow_ctx.last_snapshot = final_snap` written directly inside `_end_round`. Handoff `:585-587`. | Documented in prose before slice 6.0, now pinned by `CombatBaselineTests`. | Yes — every combat end. | None visible; it is an architecture defect that blocks `FlowResolveState` from ever owning the combat resolve (which is why producer F exists as a fallback at all). | Structural — belongs to the Phase 7 architecture gate. | **FP + BL** — a real transition changes the transition sequence baseline. |
| **D61** | `InstitutionService.run_settle_tick` asymmetry | `core/sanctum/InstitutionService.gd:426-436` | `update_condition` + `apply_institution_modifiers` run only when `inst_cfg` is non-empty, but `apply_passive_effects` runs whenever `hours_elapsed > 0` regardless. Labelled CHARACTERIZATION: "original behaviour, not a bug introduced by this move; do not 'fix' it here." | Yes — every economy settle with an empty `inst_cfg`. | Institutions accrue passive effects while their condition never degrades. | Decide whether the asymmetry is intended. | **BL** — economy settle is pinned. |
| **D77** | The full stage reward is paid at **every** encounter resolution, victory or defeat, with no per-stage idempotency — **found 2026-08-24 while verifying D36** — ✅ **CLOSED, verified 2026-08-27** | `FlowEncounterState.gd:624` (`reward_stage_complete`) — **line re-verified after slice 6I** — fed by `RewardCalc.gd:31-38` (`base_reward` = sum of the **stage's** objective weights) and paid by `EconomyService.gd:117-158`. Called unconditionally from `build_final_snapshot` (`:458`) at every combat end (`FlowRuntime.gd:1483`). | `base_reward` depends only on `stage.objectives`, never on which situation was fought, and nothing marks a stage or situation as already paid. Each of a stage's 2–4 non-objective situations that rolls `TYPE_COMBAT` (`SituationModel.gd:39-52`) pays another full stage reward. The defeat branch (`EconomyService.gd:139-152`) pays `roundi(base*0.25*redo_mul)` while the situation stays unresolved — the pre-snapshot resolve is gated on victory — so one fight can be lost repeatedly for Ase with no cap. **Orchestrator verified the defeat payout directly.** | **Yes, and no quit is required.** This is the root mechanism; D36 merely leaves the stage in the `"current"` slot so it stays farmable. | Unbounded Ase and Ekwan inflation for any player who notices that losing pays. No XP leak — defeat awards none (`ProgressionService.gd:118-122`, `skip_kill_xp=true`). | Same fix as **D36**: settle once, at stage completion, in `VentureController.handle_complete_stage`. If payment must stay per encounter, gate it on a persisted per-situation `rewarded` flag and pay nothing on defeat. **Product-owner call: should a defeat pay a consolation at all?** **SLICE 6J (2026-08-24): site re-verified, payment untouched.** `reward_stage_complete` is now `FlowEncounterState.gd:203`, still called unconditionally from `build_final_snapshot` (`:37`), which 6J deliberately kept on `FlowEncounterState` rather than moving it into the new pure `EncounterSnapshotBuilder` **because it pays** — see the header note at `EncounterSnapshotBuilder.gd:27-39`. When the D36/D77 settlement moves to `VentureController.handle_complete_stage`, the remainder of `build_final_snapshot` becomes pure and can move into `EncounterSnapshotBuilder` in that same change; 6J left the file split along exactly that seam so the later move is a cut-and-paste rather than a re-analysis. | **FP + BL** — identical surface to D36. Fix as one change with D36. **CLOSED 2026-08-27.** The two payments are now distinct functions: `EconomyService.reward_encounter_complete()` (`:131`) per encounter, `settle_stage_complete()` (`:211`) once per stage. The 25% defeat consolation stayed, as decided, and is stamped once per situation by `ActiveStageService.claim_situation_defeat_consolation()` (`:349`), which writes `consolation_paid` (`:369-371`) and returns true only on the first defeat. The situation stays unresolved, so the fight is still retryable and no longer payable twice — exactly the specified shape. |

---

## Kind 5 — DEFERRED-BY-DECISION
*Assigned to another story or deliberately out of scope.*

| ID | Title | Verified location | Assigned to | Note |
|---|---|---|---|---|
| **D62** | Contact resolution runs none of the six steps | `core/runtime/controllers/ContactController.gd:105-111` | **Phase 8**, `EncounterResolutionService` | Cross-listed as **D06** because of its player impact. |
| **D63** | Ase Flame lights a chapter early | `core/runtime/controllers/OnboardingController.gd:139-171` | **Phase 8** | ✅ **FIXED in Phase 8C** together with **D42**; the finding is written there. Kept here so the cross-listing does not read as still open. |
| **D64** | The 26/28 `_movement_*` functions move verbatim | Handoff `:786`; `core/runtime/FlowRuntime.gd:1146-2131` region (**line range is stale — the file is now 2,070 lines**) | **V2-COMBAT-003** owns the behaviour | 28 functions, not 26 or 25 (20 `_movement_*` + 8 others incl. three `_apply_live_*`). |
| **D65** | Guide-spirit mover moves verbatim | `core/combat/CombatRoundGuideSpiritService.gd`, `core/movement/LiveHazardOutcomeService.gd` | **V2-COMBAT-003** | 231-line block; extraction only, no behaviour change. |
| **D66** | Reward-type weighting bug | Handoff `:812-814` | **Owner disputed** — the prompt says `V2-ECONOMY-004`; Notion shows that story is the Ekwan loop. | **Confirm the true owner before filing.** |
| **D67** | `SaveSchema.make_new_save()` writes `active_directive_id = "directive.none"`, immediately rewritten by repair | Handoff `:809-811` | **Phase 11 docs** + a schema fix | Consequence: **the V1→V2 directive migration is LIVE, not dead.** Fix the schema default first, *then* the migration can be removed. Order matters. **FIXED 2026-08-28 (fix pass 2).** `SaveSchema.gd:137` now writes `directive.scout_carefully` (the default every consumer already falls back to: `DirectiveService.get_active_directive()`, the two `SaveService` repair defaults, and every `core/` read site); the `directive.none` → `directive.seek_signs` branch was then deleted from `SaveService.gd`. A `directive.none` value now falls to the unknown-id branch and is reset to `directive.scout_carefully`. **Behaviour moved:** the repair ran on every load, so the effective directive of an existing campaign's first stage was `seek_signs`; it is now `scout_carefully`. Two new-save fingerprints re-recorded. Exposed **D92**. |
| **D68** | `CONVENTIONS.md` claims debug actions run at `t = -1` | Handoff `:807-808` | **Phase 11** | False — `dispatch()` computes one tick for every action. |
| **D69** | `_resolve_next_actor` cannot become a controller | Handoff `:770-780` | **Phase 6 / Phase 7 gate** | Two live blockers remain: the mid-function `flow_machine.transition(KEEPER_REWIND)` (no `FlowActionOutcome` can carry it), and **`_actor_cfg_merged_cache` — a mutable instance member that must outlive a dispatch**, while controllers are constructed per call. The controller-to-controller blocker is **RESOLVED (6F)**. |
| **D70** | `_end_round` cannot be reduced below 139 lines | Handoff `:602-616` | **Closed** | "There is no further phase to extract. Do not chase it lower." Recorded so a later reader does not reopen it. |

---

## Coverage gaps (recorded, not defects)

| ID | Gap | Location | Note |
|---|---|---|---|
| **D71** | **Producer F has no test anywhere in the repo** | `core/state/flow/states/FlowResolveState.gd:17-32` | "the weakest point of the slice" (handoff `:418`). D19 deletes a key from an untested producer. |
| **D72** | `SnapshotContractTests` has no `flow.resolve` case | `tests/SnapshotContractTests.gd` | Jeff **did not approve** adding it in Phase 5 (handoff `:404`). This is exactly the gap that let D23 survive. |
| **D73** | Nothing asserts producer B *omits* `ekwan_awarded` — ✅ **CLOSED, verified 2026-08-27** | — | "the most fragile fact in the spec and the entire reason `ekwan` is block #8 rather than a flag on `ledger`". **STILL OPEN after slice 6J (2026-08-24), and now load-bearing.** 6J migrated producer B onto the block library, so the omission is expressed by the ABSENCE of an `add_ekwan(...)` line at `core/state/flow/states/venture/EncounterSnapshotBuilder.gd:622` — a line someone can add in good faith with nothing to stop them. Re-confirmed that no suite pins it: `onboarding` covers only the snapshot type, the actor list and the `cta.continue` routing; `fingerprint`/`combat_baseline` never drive the keeper trial; `snapshot_contract` has no `flow.resolve` case at all (D72). 6J left an explicit `# NO add_ekwan` comment plus a header note at `:549-556` as the only guard, and did NOT add an assertion — adding a test is a scope change the requester must approve. **Cheapest fix: one assertion in `OnboardingTests._t_keeper_trial_victory_routes_resolve`, `if data.has("ekwan_awarded"): fail` — the snapshot is already in hand there, so it costs one `if`.** **CLOSED 2026-08-27.** `tests/OnboardingTests.gd:283` rejects a keeper-trial resolve payload that carries `ekwan_awarded`, and `:285` requires `ase_awarded`. The omission block #8 depends on is now pinned. |
| **D74** | `initiative_order` and `total_waves` are outside fingerprint cover | `core/combat/CombatRoundSpawnService.gd:38`, `:52` | Guarded only by `combat_baseline` and `objective_combat`. |
| **D75** | 48 of 73 actions have no test coverage | Handoff `:271` | **UNVERIFIED — count not re-measured.** Slices 5.0 and 6.0 have since added coverage, so the number is likely stale. |
| **D76** | `snapshot_purity/build_final_snapshot_pays_rewards` will go silently vacuous | `tests/FlowSnapshotFingerprintTests.gd` | If payment moves to `_end_round` (same dispatch), the probe still passes while proving nothing. **Inverting it needs a rewritten body scoped to a direct `build_final_snapshot()` call, not a flipped boolean** (handoff `:566-570`). **CLAIM CORRECTED 2026-08-24, slice 6J — it goes vacuous only for a relocation this project is NOT doing.** Read at the site: `test_purity_build_final_snapshot_pays_rewards` (`tests/FlowSnapshotFingerprintTests.gd:340-393`) never calls `build_final_snapshot()`; it reuses `FlowFingerprintTests._setup_encounter` + `_drive_and_capture` and asserts that economy/XP/emotion CHANGED across the drive. `_drive_and_capture` (`FlowFingerprintTests.gd:181-215`) dispatches only `combat.init`, `combat.confirm_round` and `combat.next_actor` — it **never dispatches `flow.complete_stage`**. So under the SCHEDULED D36/D77 fix (settlement moves to `VentureController.handle_complete_stage`, a later dispatch) this probe does not go silently vacuous — it **FAILS LOUDLY**, and that failure is the positive evidence the payment left the builder. It goes vacuous only under the `_end_round`-relocation variant this row was written against, which the Decisions block has since ruled out. **Revised action: do not rewrite the body — invert the assertion to "must NOT mutate" and keep the same production drive.** A direct `build_final_snapshot()` call would be weaker, because it could not observe the dispatch boundary that is the whole point of the fix. |

---

## Ready to decide
*Action clear, cost known.*

| ID | Fix | Moves a fingerprint? | Moves a baseline? | Sequencing |
|---|---|---|---|---|
| **D01** | Read `stats.max_hp` | **Yes** — all seven modes | **Yes** — `CombatBaselineTests` fear/morale | **Decided. After Phase 6.** Own commit, explained baseline update. |
| **D04** | Fix the level-up stat sync + heal | **Yes** | **Yes** | Bundle with D01 — same baseline re-record, same root cause. |
| ~~D18 / D19~~ | ~~Delete `title` and `note`~~ | **Yes — seven `data_keys` hashes, confirmed** | No | ✅ Done, connect case 4/4 2026-08-28. Landed on its own, not bundled: D01 and D04 had already shipped as connect cases 1 and 2. |
| **D07** | Read flattened `morale`/`fear` in the scout preview | No | **Yes** — `VentureCharacterizationTests` | Any time. One line. |
| **D37 + D38** | Flip `skip_if_already_resolved` and `commit_only_when_modified` on path (B) | Check `objectives_remaining` in producer A | **Yes** | One fix, two flags. The parameters already exist — this is the cheapest real repair in the register. |
| **D08** | Add the missing dot to the retreat seed fallback | No | No (unreachable) | Any time. Zero risk. |
| **D10 / D11** | Clear `_double_damage_mult` with its partner | No | No | Any time. |
| **D30 / D31** | Give `objective_modes` and `combat.shrine` a `ConfigService` owner | No | No | ~~Any time. Pure consolidation.~~ **Done 2026-08-28.** |
| **D48** | Make the two `source_id` guards agree | No | No | Any time. |
| **D57** | Numeric `(col, row)` compare in the movement adapter | No | **Yes** — party movement paths | Do it **after** D27 (log the movement decision) so the re-record is auditable. |
| **D50** | Exclude structures from `party_size` | **Yes** | **Yes** | Bundle with D01/D04. |
| **D35** | Add `direction` + `tag` to producer B | **Yes** | No | Bundle with the fingerprint re-record. |
| ~~D42~~ | ~~Move the Ase Flame flag write~~ | No | **No — the prediction was wrong** | ✅ Done, Phase 8C 2026-08-27. Deleted rather than moved; no recorded value moved. |
| **D67** | Fix `make_new_save`'s directive default, **then** remove the migration | No | **Yes** — new-save fingerprints | Order is load-bearing. |

**One sequencing rule that governs the whole list:** D01, D04, D18, D19, D35 and D50 all move
fingerprint constants. Land them as **one** re-record with a written explanation, not six. Anything
in the "no fingerprint" column can go in at any time, including during Phase 6.

**One hazard that governs the whole list:** the retreat roll is genuinely tick-bound (handoff
`:581-584`) — same encounter, same 50%, ticks 7 and 8 succeed, 9 and 10 fail. **Any change to the
dispatch count re-rolls every retreat in the game.** Check the dispatch count before and after
every fix above.

---

### Found during slice 6I (Phase 6 — encounter setup extraction), 2026-08-24
| ID | Title | Verified location | Evidence | Reachable | Player impact | Action | Blast radius |
|---|---|---|---|---|---|---|---|
| **D79** | The depth-scaled placement routine is written out **six** times, and `data.combat.objective_placement` is read longhand **twice** in the same setup pass | `core/combat/EncounterObjectiveSpawnService.gd` — `spawn_shrine` (shrine), and `spawn_objective_actor` ×4 (RECOVER relic, PROTECT entity, PURSUE quarry, GUIDE_SPIRIT spirit). Sixth copy: `core/combat/EncounterSetupService.gd`, temporary-ally placement. All six moved verbatim from `FlowEncounterState.gd::enter()` by slice 6I; none was copied. | Every copy does the same five steps — build an occupancy set from `echo_actors` + `enemy_actors` grid_pos, collect unoccupied walkable cells into a candidate array, derive min/max walkable column, compute a target column, then `sort_custom` on (distance to target col, distance to a reference row, col, row) and take `[0]`. They differ in exactly two knobs: the **target column** (depth-scaled for shrine/relic/quarry/spirit, board centre for PROTECT, party centroid for the ally) and the **row reference** (board midpoint everywhere except PURSUE, which uses the party centroid row after the slice-6E fix — see the comment at that site). The two `objective_placement` reads are `_op_cfg`/`_op_f` inside `spawn_shrine` and `_op_cfg_p3`/`_op_f_p3` at the head of `spawn_objective_actor`; both read `depth_min_frac`, `depth_max_frac`, `completion_full_at` from the same subtree and can never disagree, because only one of the two branches ever produces an actor. | Yes — one of the six runs in every encounter. | **None today.** Every copy behaves correctly. The cost is drift risk: slice 6E had to fix the row reference and fixed it in **one** copy only, which is why PURSUE now differs from the other five. | Collapse to one helper — `place_on_terrain(candidates_source, target_col, ref_row) -> Dictionary` — with the two knobs as parameters, on a service beside `GridService`. **Not extraction**: the five surviving board-midpoint copies and PURSUE's centroid copy would have to agree on a row reference, and choosing one changes placement. Schedule as a normal slice **after** Phase 6, and decide the row-reference question explicitly. | **BL + FP** if the row reference is unified — every mode's spawn cell moves, so all seven `CombatBaselineTests` mode hashes and every `FlowFingerprintTests` constant that sees a position move. `—` if the six are collapsed while preserving each one's current knobs exactly. |
| **D80** | GUIDE_SPIRIT escort on a legacy (no-terrain) board gets destination `(-1,-1)` and can never be completed | Producer: `core/combat/EncounterObjectiveSpawnService.gd`, `spawn_objective_actor` GUIDE_SPIRIT branch — `_gs_dest_col`/`_gs_dest_row` are initialised to `-1` and the whole destination block is gated on `_gs_mode == "escort" and not _gs_terrain.is_empty()`. Consumer: `core/combat/CombatRoundGuideSpiritService.gd:254-255`, `:300-301`, which read `combat_state.destination_col/row` with default `-1`. | Terrain is generated only when an **active realm model** exists and the encounter is not `keeper_intro.first_trial` (`EncounterSetupService.gd`, board-sizing block). On a legacy board `_gs_candidates` is never populated, so `_gs_edge_candidates` is empty, so no destination is chosen — and the escort latch at `:300-301` compares the spirit's real position against `(-1,-1)`, which no grid cell can equal. The spirit walks toward a destination it can never reach and the objective can only end on the duration timer. | **Not in normal play** — GUIDE_SPIRIT is reached through a stage objective, which requires an active realm, which guarantees terrain. Reachable via the `dev_combat_objective` toggle with no active realm, and via any future legacy-board encounter that resolves to GUIDE_SPIRIT. | None today (dev-only). Would be a silent unwinnable objective if a legacy-board GUIDE_SPIRIT ever shipped. | Either fall back to a literal board-edge destination when terrain is empty, or refuse to select `escort` at all on a legacy board (force `protect`) — **the second changes an RNG-derived value and must not be done by short-circuiting the coin flip; keep the draw-then-override shape**. Low priority. | `—` today (unreachable in any recorded run). |

---

### Found during the Half A review corrections (C1–C6), 2026-08-24
| ID | Title | Verified location | Evidence | Reachable | Player impact | Action | Blast radius |
|---|---|---|---|---|---|---|---|
| **D81** | The offline-accrual "house dormant" gate is evaluated **twice**, and the second evaluation is unreachable dead code that would have done something different | `core/economy/OfflineAccrualService.gd` — inline gate near the top of `apply_if_needed()` (reads `save_data.sanctum.ase_flame.awakened` directly, logs `economy.offline.noop`, `return 0`); second gate immediately after the elapsed-time read (`if not KeeperIntroService.is_ase_flame_awakened(flow_ctx.save_data)`, logs `economy.offline.skip`, rolls the clocks, `flow_ctx.request_save("economy.offline_guard")`, `return 0`). Both moved verbatim out of `FlowRuntime._apply_offline_accrual_if_needed` by correction C1; neither was written by that move. | The two predicates are semantically identical. `KeeperIntroService.is_ase_flame_awakened` (`core/onboarding/KeeperIntroService.gd:250-256`) reads `save_data.sanctum.ase_flame.awakened` with the same `is Dictionary` guards and the same `false` default as the inline block. The inline gate runs first and returns, so **the second can only be reached when the first already passed, i.e. never on its own terms.** The two are NOT equivalent in effect: the reachable one returns without touching the clocks; the dead one advances `last_offline_unix` and `last_settle_unix` to `now_unix` and requests a save. So today, a dormant house leaves both clocks untouched, and the elapsed window it would have consumed is still there the moment the flame is awakened. | The dead branch: **no**. The surviving inline gate: yes, on every `flow.continue` before the awakening rite. | **None today** — the reachable path is the correct one. The latent risk is the reverse: anyone who "tidies" this by deleting the *inline* gate instead of the dead one silently changes behaviour, because the survivor rolls the clocks forward and swallows the accrual window that the awakening is supposed to open onto. | Delete the SECOND gate (the `KeeperIntroService` one) and its `economy.offline_guard` save, keeping the inline gate. Confirm first whether the clock-rolling was ever intended — if it was, the fix is the opposite one and it changes the first post-awakening payout. **Do not fix during an extraction slice.** | `—` for the delete-the-dead-branch direction (unreachable code, no recorded value moves). **BL** for the opposite direction — `economy/offline_gate_blocked_before_awakening` asserts `ase` unchanged, and a save reason would enter the pipe-joined `save_request_reason` that `CombatBaselineTests` pins per dispatch. |


---

### Found during Phase 8A (stage settlement), recorded in Phase 8B, 2026-08-25
`core/economy/StageSettlementService.gd:142` already cites "Register entry D83" — the entry itself
was never written into this file. Written here now, from the call site, without changing the code.

| ID | Title | Verified location | Evidence | Reachable | Player impact | Action | Blast radius |
|---|---|---|---|---|---|---|---|
| **D83** | `ekwan_shrine_multiplier` has never applied — the Ekwan factor reads an objective key nothing writes | `core/economy/StageSettlementService.gd:145-150`, and the identical read at `core/state/flow/states/venture/FlowEncounterState.gd:186-191` | Both sites do `objectives[0].get("obj_type", "combat")`. `ObjectiveModel.make()` writes `type`, never `obj_type`, so `_obj_type` is the `"combat"` default on every stage and the `if obj_type == "shrine"` branch is dead. `data.rewards.ekwan_shrine_multiplier` therefore has no effect anywhere. Carried verbatim by Phase 8A rather than fixed, so the settlement split would stay attributable. | **Yes** — every shrine stage. | Shrine stages pay the ordinary Ekwan factor instead of the authored 1.5×. Never noticed because the multiplier has never been observed working. | Read `type`, at BOTH sites, in one change. Note the two sites must move together or a shrine stage's per-encounter and per-stage Ekwan would disagree. | **FP + BL** — Ekwan is in `FlowFingerprintTests`' SAVE fingerprint and in the resolve card's `ekwan_awarded`; it moves on any shrine stage. Belongs with the after-Phase-9 group, not with a settlement change. |
| **D84** | A run's bond and Thread consequences do not exist yet when its Resolve card is published | Producers: `core/runtime/controllers/VentureController.gd::handle_complete_stage` — `apply_combat_bond_triggers`, `apply_bond_aftermath_modifiers`, `seed_rival_stage_incidents`, and `RealmService.contribute_segment`. Consumer that wants them: `core/state/flow/PendingResultService.gd::_build_result` (`bond_outcome`, `thread_outcome`). | The Resolve card is published by the dispatch that ENDS the fight. All four of the above run in the `flow.complete_stage` dispatch — the one the card's `cta.next_stage` triggers, i.e. the dispatch that CONSUMES the durable result. At capture time neither a bond outcome nor this stage's Thread segment exists anywhere in the process, so `save.flow.pending_result.bond_outcome` is written `{}` and `thread_outcome` carries only the realm's standing recovery-track count plus `flow_ctx.last_realm_threads_earned` (non-empty only when a realm completed). The schema at `SaveSchema.gd:34-45` names both keys, which is why this is recorded rather than silently dropped. | n/a — it is an ordering fact, not a mechanic. | **None today.** No screen reads either key. It becomes an omission the moment a Resolve card wants to show "the bonds this run changed". | Either move the bond hooks and the segment contribution ahead of the resolve card (a real behaviour change — they currently run once per STAGE, the card once per ENCOUNTER, so they are not the same cadence), or accept that a durable result records the ENCOUNTER and let a later Sanctum surface report the stage's bond/Thread movement. **Do not "fill in" these two keys from save state at capture time** — that would record the party's standing bonds as if they were this run's outcome. | **FIXED, pass 9/10.** Investigated all four producers separately. THREE ARE ENCOUNTER CADENCE and were already running once per victorious encounter, split across two call sites (`FlowRuntime._apply_victory_return_to_explore` for a mid-stage victory, `handle_complete_stage` for the stage-clearing one) — both AFTER the card. All three moved to the single site `FlowRuntime._end_round()`, in the dispatch that publishes the card, placed after `build_final_snapshot()` so the arrival-bark / bond_formed-bark order is unchanged. They return a summary, which `PendingResultService` records. THE THREAD SEGMENT IS NOT ENCOUNTER CADENCE: `realm_recovery_segments` holds one entry per `stage_index` and `ThreadService` counts the entries, so a per-encounter contribution would inflate a multi-objective stage's recovery. It is contributed at `_end_round()` only on the fight that CLEARS the stage (`classify() == victory`, the exact card that offers `cta.next_stage`), and `RealmService.contribute_segment` gained a per-`stage_index` receipt — the recorded stage index IS the stamp, no new save key — so the `flow.complete_stage` call that follows is a no-op. That call stays because it is the only contributor on the no-encounter path (D05). Pinned by `tests/PendingResultTests.gd::_t_bond_and_thread_cadence`. |
| **D85** | `save.flow.state` is defaulted and validated but written by nothing, and `boot()` restores `realm_id` without `stage_id` | `core/save/SaveSchema.gd:31-33` (default `"flow.splash"`), the validator, and `core/save/SaveService.gd:515-526` (repair). Restore gap: `core/runtime/FlowRuntime.gd:105-112`. | Repo-wide grep finds no write to `save["flow"]["state"]` outside `make_new_save` and the repair branch; `save.flow.context` is likewise `{}` forever. Separately, `boot()` restores `flow_ctx.realm_id` from the first realm with `status == "active"` and comments "survives Continue", but never restores `flow_ctx.stage_id` — nothing needed it, because before Phase 8B a run in progress could not be resumed. | The dead field: n/a. The `stage_id` gap: **yes** — any resumed run. | The `stage_id` gap would have been player-visible the moment resume existed: the victory card's `cta.next_stage` dispatches `flow.complete_stage`, and both `StageSettlementService` and `RealmService.advance_stage` locate the stage through `flow_ctx.stage_id`. With it empty the settlement returns `{}` and a completed stage pays nothing. | Phase 8B works around the `stage_id` half locally, in `PendingResultService.restore_run_context()`, filling only EMPTY fields from the durable result — deliberately NOT a change to `boot()`, since boot has no pending result to read and widening it would touch every save-integrity boot path. `save.flow.state` itself is untouched: writing it for the first time changes save contents for no consumer. Decide later whether to make it the real resume pointer or delete it. | `—` for what Phase 8B did. Writing `save.flow.state` would move save contents (though not the `FlowFingerprintTests` SAVE fingerprint, which reads only `economy` + party). **✅ FIXED, pass 10/10 (2026-08-28), by DELETION — product-owner decision.** Both `flow.state` and `flow.context` removed together: same shape, same zero writers, and no reader of either outside the validator that also defaulted it. Removed the schema default (`core/save/SaveSchema.gd:31-33`), the repair default (`core/save/SaveService.gd:520-522`) and the validator check (`core/save/SaveService.gd:1411-1412`). Backward compatible: `SaveService.validate()` is a required-key whitelist with no unknown-key rejection, so an older save's leftover `flow.state` / `flow.context` are simply carried and ignored. Pinned by `tests/SaveBridgeTests.gd::bridge/legacy_flow_state_context_still_loads`, which repairs and validates both a save that carries the dead keys and one that does not. **Nothing re-recorded** — no fingerprint hashes the `flow` subtree's key set, and the SAVE fingerprint reads only `economy` + party as predicted. Full suite 1516/1516. |

| **D86** | The awakening modal had never rendered: nothing in `core/` or `ui/` ever set `FlowContext.pending_awakening_banner` true — ✅ **FIXED, Phase 8C** | Flag: `core/state/flow/FlowContext.gd:122`. Reader: `core/state/flow/states/sanctum/SanctumSnapshotBuilder.gd:401` (`show_awakening_overlay`). Consumer: the one-shot closure at `core/runtime/FlowRuntime.gd` end-of-dispatch. Modal: `ui/overlays/sanctum/AwakeningModal.tscn/.gd`, registered `ui/shells/SanctumShell.gd:118`, requested `ui/screens/sanctum/SanctumScreen.gd:417-419`. | The whole chain existed and was correct end to end. The ONLY production write was `= false` in the consume closure, so `show_awakening_overlay` was false in every snapshot ever built and `modal_requested.emit(&"awakening", …)` never fired. Pinned only by `FlowSnapshotFingerprintTests`, which sets the flag by hand — which is why the gap survived: the tests proved the plumbing, and nothing proved the arming. | **No — the modal was unreachable in play.** | The awakening beat had no payoff on the Sanctum side. Found while fixing D42, at the same site. | ✅ **FIXED.** `OnboardingController.handle_awakening` sets the flag at the awakening rite; the established consume gate (clear only when the published snapshot is `flow.sanctum`) carries it across the two intervening dispatches and spends it on the first Sanctum snapshot. New coverage: `onboarding/awakening_modal_shows_once_on_first_sanctum`. | `—` — no recorded value moved. |
| **D87** | The awakening modal promised "+40 Ase" that no code has ever paid — ✅ **FIXED, Phase 8C** | Label node `AwakeningGrantLabel` in `ui/overlays/sanctum/AwakeningModal.tscn` + `AwakeningModal.gd::present`; value `data.economy.awakening_ase_grant: 40` (`data/balance.json:82`) via `SanctumSnapshotBuilder.gd:405-412`. | `awakening_ase_grant` has **no consumer anywhere** — the same "authored but unreachable" shape as D01–D04. The player leaves the keeper intro with exactly the 40 Ase `KeeperIntroService.grant_trial_rewards` pays for the first trial. Latent while the modal never rendered; the moment D86 armed it, the modal would have told every player it had granted 40 Ase it had not. | Would have been **yes** for every new campaign, from the D86 fix onward. | A modal claiming money that never arrives. | ✅ **FIXED by removing the claim, not by paying it.** The grant label is deleted from the modal scene and from `present()`. The grant itself is **deferred to V2-ECONOMY-002** and `awakening_ase_grant` stays unreachable. `data.awakening_grant` is deliberately LEFT on the snapshot: removing it would move the recorded `flow.sanctum` data-key set for no gain. | `—` (UI only; the snapshot key set is unchanged). |
| **D88** | Two copies of the awakening modal, one dead, both carrying the same body string — ✅ **FIXED, Phase 8C** | Dead copy: `%AwakeningOverlay` in `ui/screens/sanctum/SanctumScreen.tscn` (~72 lines), permanently disabled at `SanctumScreen.gd:197` via `_disable_legacy_modal`, with `_show_awakening_overlay()` / `_on_awakening_dismiss_pressed()` that only re-disable it. Live copy: `ui/overlays/sanctum/AwakeningModal.tscn`. | The legacy overlay could never be shown again — `_disable_legacy_modal` runs in `_ready` and nothing re-enables it. Its only remaining effect was to hold a second copy of the modal's title, body and grant text where a copy edit would touch one and miss the other. | No — dead node. | None directly; a divergence trap for the next copy change. | ✅ **DELETED**, node block and all four `.gd` references, with the reason recorded in place. Proof it had no caller: repo-wide grep for `AwakeningOverlay` / `AwakeningTitle` / `AwakeningBody` / `AwakeningGrantLabel` / `AwakeningDismiss` returns only `AwakeningModal.tscn` and `tests/SanctumLayoutTests.gd:299,327`, which instantiate the LIVE modal scene. `sanctum` + `foundation_ui` suites green after. | `—` |
| **D89** | The opening Realm did not exist; `onboarding.opening_realm_id` / `opening_realm_status` were defaulted, validated and repaired but read and written by nothing — ✅ **BUILT, Phase 8C** | `core/save/SaveSchema.gd:63-66`, `core/save/SaveService.gd:550-551,610-617`. Now owned by `core/onboarding/OpeningRealmService.gd`. | Phase 8 groundwork added both fields additively and said so ("nothing reads or writes these yet"). Until this slice the first session ended at `keeper_intro.complete` with nothing to do and every Realm equally available. | n/a — the gap was the absence of a mechanic. | The whole opening arc. | ✅ **BUILT.** `realm.prologue` is a real one-stage generated run created from `keeper_intro.complete`, unlocked by **awakening + first Weave**, carrying the player's own starter virtue (passed as a `cfg_overrides` argument to `RealmService.get_or_create`, because the virtue differs per campaign and cannot live in `realms.json`). `flow.select_realm` is validated against the gate. **RECORDED DIVERGENCE: GDD §20.7 puts the second summon before the opening Realm; this does not.** That ordering depends on an awakening Ase grant that does not exist (see D87) — 40 Ase against a 60 Ase summon cost would stall the arc at its first beat. Do not "fix" it back before the grant ships. | `—` — no recorded value moved. |
| **D90** | The prologue Realm needs a SECOND predicate; `is_realm_run()` (D82) does not cover it | `core/realms/RealmService.gd::is_prologue_run` + `PROLOGUE_REALM_ID`. | D82's predicate discriminates on the `status` key because `prologue.first` is a synthetic segment CONTAINER that was never played. `realm.prologue` is the opposite: a genuine `RealmModel.make()` run WITH a status, which the player really plays — so it passes `is_realm_run()`, and must. What makes it special is that it is not one of the player's Realms. **The two ids are not unified**; a scan that wants to exclude both applies both. | **Yes** — counting it would put every player's first real Realm on `run_index = 1`, reintroducing exactly the reward inflation D82 removed, by a different door. | Would have inflated the virtue bonus, the realm order multiplier and the realm XP multiplier for every campaign. | ✅ Excluded at six sites, each annotated in place with why: `RealmService._count_started_realms` (the `run_index` leak), `RealmService.compute_runtime_locks` (the one-active-Realm lock), `FlowVowState:51` (the Vow "realm in progress" scan), `VowService::pledge` (the `runs_at_pledge` counter), `ConsequencePassService._build_intel_group` (the consequence-pass intel group — the prologue exists to ASK the hidden-information question, so the pass must not answer it), and `FlowRuntime.boot()`'s `realm_id` restore, where it is excluded from the generic scan and restored EXPLICITLY from `opening_realm_status == "active"` instead, so a real Realm always wins and the prologue is still resumable. Absence from `realm_order` covers Realm Select and the realm-card list for free. The reward order multiplier and the realm XP multiplier need no site change: both are keyed on `run_index`, which the first exclusion already fixes. **Correction to the slice brief: the Sanctum enter-stage enablement (`SanctumSnapshotBuilder:57`) is deliberately NOT excluded** — `cta.enter_stage` is the affordance the player uses to enter the prologue, and excluding it would make the opening Realm unreachable. Pinned by `onboarding/prologue_does_not_inflate_first_realm_run_index` and `onboarding/normal_realms_locked_until_prologue_complete`. | `—` — no recorded value moved. |

#### Phase 8C addenda

**A second inverted assertion, in `snapshot_purity`.**
`snapshot_purity/dispatch_preserves_pending_return_notification_until_sanctum`
(`tests/FlowSnapshotFingerprintTests.gd`) also pinned the wrong beat, in its SETUP: it asserted
the Ase Flame was lit by `onboarding.name.confirm`. Inverted in place, not dropped, with the
reason written at the site. Its SUBJECT is unaffected — it exercises the `dispatch()` closure's
gate on `pending_return_notification`, and the notice it uses is injected directly onto the
context rather than travelling through `OfflineAccrualService`, so the Flame is scaffolding
there, never a precondition. This was the only failure the full suite produced for the whole
slice.

**`OnboardingTests._make_runtime` never loaded `realms.json` (harness gap, fixed).**
It builds its `FlowRuntime` by hand and so skips `boot()`, which is where `load_realms()` runs —
leaving `ConfigService.get_realms()` empty. Harmless for eleven suites' worth of history, because
nothing in the keeper intro touched a Realm. The moment `keeper_intro.complete` started opening
the prologue Realm, it made `RealmService.get_or_create` return `{}` and Realm Select list
nothing. One line added; no production code involved.

**Nothing in this slice moved a recorded value.** No fingerprint constant, no baseline, no
`git diff -- data/` change to any existing line (the file gains a new realm entry and a note; not
one authored number was edited). Suite 1,489 → 1,494, all passing.

#### Phase 8B addenda to existing entries (stood at the site; nothing fixed)

**D07 — scout-return party preview shows a constant emotional status.** Still live, and it now
has a second consequence: the durable withdrawal result stores `resolve_data.actors` verbatim,
so the constant `get_emotional_status(50, 0)` preview is now written into `save.flow.pending_result`
and replayed after a quit. The fix is unchanged (read the flattened `morale`/`fear`); it just has
one more reader to be correct for. No new work — a corrected producer C produces a corrected
stored copy for free, because the store copies whatever the card carried.

**D18 / D19 — the dead `title` and `note` keys.** Producer G
(`PendingResultService.build_snapshot`) replays both, because it replays whichever blocks the
stored card carried and `title` reaches it through producer A. Deleting blocks 16/17 therefore
now touches one more producer — but only by deleting two lines from it, and G is not
fingerprinted. The D18 recommendation ("delete with the next fingerprint re-record") is unchanged.

**D36 — replayable reward, re-verified in Phase 8B.** Phase 8A's `settlement_receipt` was
re-checked independently against the FRESH-STAGE case the receipt comment flags: a realm generated
at runtime by `RealmGenerator` carries no `settlement_receipt` key at all until a save repair pass
adds one. Two `flow.complete_stage` dispatches aimed at the same such stage pay exactly once —
`RealmService.get_active()` returns the LIVE realm dict out of `save_data`, `_stage_ref()` returns
the LIVE stage dict inside it, and the receipt written there is therefore in save data before the
second dispatch reads it. Pinned by `venture_char/complete_stage_no_encounter_advances_and_pays_nothing`,
whose second dispatch resets `stage_id` and `current_stage_index` back to the first stage before
re-dispatching. Green. No change made.

## Needs the product owner
*Design or balance questions, not technical ones.*

| ID | Question |
|---|---|
| **D02** | Ten leadership traits have authored effects nothing implements — six are combat-scoring bonuses that belong in `BehaviorArbiter`, two are movement modifiers, `anchor_presence` has no effect body and `cover_positioning` is authored empty. **Implement which, delete which?** Implementing all ten is a substantial combat-balance change; deleting them removes ten build choices from the game. |
| **D03** | Should barks be budgeted and tiered as `data.voice` describes (3/round, tier priority), or is the current unbudgeted stream the intended feel? |
| ~~D05~~ | ✅ **ANSWERED IN CODE 2026-08-27: the stage pays, and its Thread segment carries grade `"C"` → "compromised."** `VentureController.NO_COMBAT_GRADE` (`:164`), settlement gate (`:659`), judgement recorded at `:681-688`. Original question kept visible. |
| **D13** | Are the purifier cooldown and the party morale drain meant to be **per-round** (stop only when the encounter ends) or **per-shrine** (stop when the shrine dies)? Read as written they look per-round; implemented they are per-shrine. This changes PURIFY_SHRINE's difficulty curve either way. |
| **D20** | Should the contact resolve show a rank badge? The `verdict` value is computed; the screen hides it unconditionally. Show it or drop it. |
| ~~D39~~ | ✅ **ANSWERED IN CODE 2026-08-27: the SUM.** Both readers delegate to `RewardCalc.base_reward()` (`ActiveStageService.gd:330`). Original question kept visible. |
| **D44** | Is the kill-ripple + kill-momentum morale stack intended? An ally in a `kill_momentum` leader's radius currently receives both and is credited twice in the ledger. |
| **D45** | Should the totem/shrine count toward the kill-share denominator in PROTECT and PURIFY_SHRINE? It fights, but it does not currently dilute XP. |
| ~~D77~~ | ✅ **ANSWERED: 25% intended; fix moves to PHASE 8** (Reading A). The fix keeps the consolation and stops the repetition — see Decisions. |
| ~~D78~~ | ✅ **ANSWERED 2026-08-24: no, Back must not quit.** Fix required. Moves no recorded value. |
| **D61** | Should institutions accrue passive effects while their condition never degrades (today's behaviour when `inst_cfg` is empty)? |
| **D66** | Who owns the reward-type weighting bug? The prompt says `V2-ECONOMY-004`; Notion says that story is the Ekwan loop. |

---

## POST-MANUAL-TEST TRIAGE AND DECISIONS — 2026-08-28

### The triage

All 90 identifiers were re-verified against the worktree at `702608b` by four independent
readers. Each reader went to the named code. None trusted a register row.

| Outcome | Count |
|---|---|
| Fixed | 32 |
| Deleted | 1 |
| Disproved | 3 |
| Not a defect | 4 |
| **Still open** | **44** |

The earlier count of 53 open items was wrong. It is 44. Of those, **32 need no decision** from
the product owner. **12 needed one.** All 12 are decided below.

Three corrections found by the triage:
- **D20 is disproved.** `ui/screens/venture/ResolveScreen.gd:262-268` shows the rank badge when
  `verdict` is not empty. The claim that the screen hides it unconditionally is wrong.
- **D33 has moved.** The duplicate realm XP multiplier now lives in
  `core/economy/StageSettlementService.gd:262-265`, not in `FlowEncounterState.gd`.
- **D85 is half fixed.** The `stage_id` gap is closed by
  `core/state/flow/PendingResultService.gd:129`. The dead `save.flow.state` field remains.

### Two questions answered by existing sources, not by the product owner

| ID | Answer | Source |
|---|---|---|
| **D13** | **Per round.** The authored keys are `purify_cooldown_rounds` and `morale_drain_per_wave`. Both are time-based. No authored key is expressed per shrine. The per-shrine implementation is therefore the defect. | `data/balance.json:1627-1631,1646` |
| **D66** | **V2-ECONOMY-004 owns it. There was no dispute.** That story is the Ekwan loop AND owns reward vocabulary, weights and the Ase/Ekwan split. It therefore owns D66 and D83. Exactly-once payout stayed with V2-INFRA-003. | Register `:198-212`; backlog line 85. The stale "confirm the true owner" note at `docs/v2-infra-003-handoff.md:1011` is superseded. |

### The twelve decisions — Jeff, 2026-08-28

| ID | Decision | Consequence |
|---|---|---|
| **D02** | **Implement all ten leadership traits.** The two empty blocks get authored effects: `cover_positioning` = a move-score bonus toward cover; `anchor_presence` = allies within the radius resist displacement. | A real combat-balance change. Moves recorded values. |
| **D13** | Make the purifier cooldown and the party morale drain **per round**. | Changes the PURIFY_SHRINE difficulty curve. Moves recorded values. |
| **D20** | **Keep the badge.** A contact outcome carries a visible rank. | No code change. Entry closes as disproved. |
| **D44** | **Intended as it stands.** The kill ripple and `kill_momentum` both apply, and the double ledger credit is part of the payoff for the trait the player invested in. | No code change. Entry closes as not a defect. |
| **D45** | **Structures stay excluded** from the kill-share denominator. A structure is an objective, not a party member. It does not earn, so it must not dilute. | No code change. Entry closes as correct behaviour. |
| **D61** | **Defer to V2-SANCTUM-004** (Ready). It is the only open story that owns house condition as a runtime layer. The file note must add a scope line for passive values and upkeep, because V2-SANCTUM-002 held that item and is now Done. | No code change in this story. |
| **D62** | **SUPERSEDED SAME DAY — see the correction below.** The first ruling was: expand V2-STAGE-003, no new story. | No code change in this story. |
| **D79** | **Collapse the six placement copies to one function.** Keep each copy's current values: the target column and the row reference become parameters. PURSUE keeps the party centroid. The other five keep the board midpoint. | No spawn cell moves. No recorded value moves. |
| **D80** | **Use a board-edge cell when terrain is absent.** The escort stays available and the objective becomes completable on every board. | No recorded value moves. No shipped encounter reaches this path. |
| **D84** | **Run the bond hooks and the Thread contribution before the card is published.** The hooks currently run once per stage; they must run at the encounter cadence, so the card reports the run that just happened. | A change of behaviour, not only of display. Moves recorded values. Ships as one commit with a written record of what moved. |
| **D85** | **Delete the field**, its default, its validation and its repair. Resume operates through the durable pending result. | Save contents change. The game is not live and saves are disposable. |

### Backlog source of truth — 2026-08-28

**Notion is current. The CSV export is stale.** Notion marks seven stories Done that the CSV
still shows as Ready or Draft: V2-SANCTUM-001, both V2-SANCTUM-002 rows, V2-STAGE-003
(Order 236), both V2-STAGE-004 rows, V2-BOND-002 and V2-VOW-002. Notion has no "Closed" status;
the open set is Draft, Ready, In Progress and Blocked. Read Notion, not the CSV.

### The 32 open items that need no decision

| Group | Items |
|---|---|
| Combat consequence | D46, D47, D50, D51, D54, D56 |
| Objective and spawn | D09, D12, D15, D16, D17, D28, D29, D43 |
| Config ownership | D30, D31, D32, D53, D67 |
| Duplication and hygiene | D33, D52, D55, D58, D69 |
| Observability | D14, D27, D35 |
| Documentation | D68, and two stale code headers (`VentureController.gd:27-35`, `ContactController.gd:139-141`) |
| Owned by another story | D06, D57, D59, D60, D62, D66, D83 |

---

## FIX PASS OUTCOMES — 2026-08-28

Rows above that describe these defects as open are superseded by this table.

| Pass | Commit | Items | Outcome | Recorded values |
|---|---|---|---|---|
| 1 | `f6b9a0c` | D30, D31, D32, D53 | Fixed. Added `get_objective_modes_cfg` (+ `_from_balance`) and `get_shrine_cfg`; routed every longhand read; added the missing null guard to `get_rewards_cfg`; `CombatTurnContextService` now uses the balance dictionary passed to it. **Correction to the D30 row: the two `BehaviorArbiter` sites were NOT routed in this pass** — they read a different subtree. Raised as D91 and fixed in pass 3. | None moved |
| 2 | `7a91df6` | D67, D92 | Fixed. See the commit for the full account. | Two new-save fingerprints re-recorded, both explained |
| 3 | `c31d9d0` | D33, D52, D55, D58, D91 | Fixed. See below. | None moved |

### New entries raised by the fix work itself

**D91 — the behaviour arbiter read `objective_modes` from the wrong subtree. ✅ FIXED, pass 3.**
`core/actors/behaviors/BehaviorArbiter.gd:1761,1788` read the subtree out of `_cfg`, which is
`data.actor`. The subtree lives under `data.combat`. Both `has()` guards were therefore always
false and both values fell through to hardcoded defaults of 3. The authored values are also 3, so
nothing differed in play — but retuning either number in `balance.json` would have done nothing.
Fixed by passing the subtree through the `context` dictionary, the seam `bond_behavior_cfg` and
`skills_cfg` already use. `ConfigService` was NOT injected into the arbiter, which holds none by
design, and `balance.json` was not changed. Proved by probe, not by the suite: a probe radius of 9
fires `objective_threatened` at 5 tiles, while `{}` and the authored config do not.

**D92 — a party wipe could score as a successful escort. ✅ FIXED, pass 2.**
`core/combat/CombatRoundGuideSpiritService.gd` latched the escort win on the spirit's own position
with no guard. A joined spirit standing on the destination delivered itself. `destination_reached`
is tested before `all_echoes_dead`, so the wipe read as `spirit_escorted`. It survived because the
old directive default moved the spirit off that cell on turn 1 — the existing test passed by
accident. The latch now requires `escort_started` AND a living non-spirit echo within
`escort_radius`. Pinned by `combat_roundtrip/guide_spirit_party_wipe_scores_defeat_not_escort`,
which an `escort_started`-only fix would fail. Proved by reverting the guard.

### Pass 3 detail

| ID | What changed |
|---|---|
| **D33** | Deleted the inline realm XP multiplier in `StageSettlementService` and called `ProgressionService.get_realm_xp_multiplier`. Proved identical first: same dictionary, same key, same rate, and both guards agree. |
| **D52** | `round_bark_events` now passes a shallow duplicate. Chosen over a comment because the array is small and per-round, so the copy is cheap, and the named risk is a consumer appending to the caller's array. |
| **D55** | The parameter `round`, which shadows the built-in, is renamed `round_number` at both sites. That name is the project's existing one. Four other files still use `round` as a parameter name — out of scope, recorded here. |
| **D58** | Comment only. `FlowContext` has no in-dispatch flag, and adding one plus an assertion would be a behaviour-adjacent change against a baseline this pass may not move. The contract is now written at the site. |

| 4 | see commit | D79 | Fixed. Six placement copies collapsed to `GridService.place_on_terrain`. Every copy's values preserved exactly. **Correction to the D79 row above: the six copies do NOT share one comparator.** The five objective copies rank lexicographically — column distance first, row distance only as a tie-break. The temporary-ally copy ranks by the summed Manhattan distance to the party centroid, which orders cells differently: a cell one column off can beat a cell in the exact column. Forcing the ally onto the axis metric would move its cell, so the metric is a fourth parameter. | None moved. All six paths captured before and after; the two ordered captures are identical line for line |

| 5 | see commit | D13, D47, D50, D51, D54, D56 | Fixed. **Two register premises disproved.** D50: the row predicted FP + BL, on the premise that PROTECT and PURIFY_SHRINE always carry a structure inside the party count. They do not — all three authored structures carry `faction: "structure"` (`data.actor.structures`), so the existing `faction == "echo"` test already excluded them. `is_spirit` (D51) was the filter that actually bit: a JOINED guide spirit is built as faction `"echo"` and inflated the count by one. D13: the per-shrine coupling is real but **unreachable today** — see below. | None moved |

### D13 is fixed but currently unverifiable — recorded honestly

The product owner decided the purifier cooldown and the party morale drain are per round. Both are
now hoisted out of the shrine loop. **This moves no number in play today**, for two independent
reasons, both checked:

1. **No fixture has more than one living shrine.** `EncounterObjectiveSpawnService` spawns exactly
   one, and the pre-existing `break` capped the old code at one execution regardless.
2. **A round never begins with a dead shrine.** `is_dead` on the shrine is written in exactly one
   place — the drain itself. Nothing else damages it. `CombatState.check_end_condition` priority 2
   makes a dead shrine an immediate `shrine_destroyed` defeat, in the same `_end_round` as the drain.

So the checkable claim is: the drain is `morale_drain_per_wave = 5` per living echo per round,
applied once, before and after — because the number of living shrines at drain time is always
exactly 1 on every round that exists. The fix removes a latent coupling. It does not change the
difficulty curve until a mode ships more than one shrine.

### Raised by pass 5, not fixed

- `party_size` still counts temporary allies (`is_ally`). Whether a one-battle companion counts
  toward the `tikoro_nko_agyina` vow gate is a design question, not a defect. Recorded in the file
  header.
- `_spirit_killed_barked` and `_spirit_greeted` (`CombatRoundGuideSpiritService.gd:195,204`) are
  the same undeclared-latch shape as D56. Out of pass scope.
- `data.actor.structures` has no `guide_spirit` entry, so the non-joining spirit falls back to an
  inline literal at `EncounterObjectiveSpawnService.gd:419-423`. Unreachable-config shape.
- The shrine morale drain filters on `faction == "echo"` only, so it drains allies and a joined
  spirit as well as real Echoes.

| 6 | see commit | D09, D12, D15, D16, D17, D28, D29, D43, D80 | Fixed, refused or disproved — see below. Six of the nine are unreachable in play, and each says so plainly rather than claiming the green suite as evidence. | None moved |

### Pass 6 — the three that were NOT ordinary fixes

**D15 — investigated, no live defect.** After the protect move, no reader consumes the captured
spirit position: the skittish log reads `_gs_spirit.grid_pos` directly, and the win counter builds
its own fresh copy. The protect branch is the last code in the function. A refresh was added anyway,
with a comment stating it changes nothing — it closes the trap for the next editor rather than
fixing a live fault.

**D29 — refused, deliberately.** The two duplicated blocks do NOT fit
`GridService.place_on_terrain` from pass 4, and forcing them would have moved every wave spawn cell.
Two exact differences: the helper returns ONE cell ranked by distance to a target column, while
these blocks hand out N cells ranked enemy-side-first by descending column — a different total
order; and `GridService.occupied_cells` counts a dead actor's cell as occupied, while these blocks
treat it as free. Deduplicated locally instead, into one private `_place_enemy_spawns`, with the
determinism-critical sort copied character for character.

**D43 — could not be reproduced, and is provably impossible today.** `defender_hp_after` has exactly
one producer, reached only behind a `not target.is_dead` guard; that same call sets `is_dead` on any
blow leaving hp at or below zero; each actor activates once per round; and `last_round_results` is
cleared at round start. So one target id can appear at most once per round with hp at or below zero.
A dedupe set was added because it is provably harmless — it can never fire on current producers —
and the proof is recorded at the site. **No test was added**, because a test would pin a behaviour
that cannot be produced.

### Pass 6 — verifiability, stated honestly

| ID | Verifiable? |
|---|---|
| D09 | No. Needs a nearly full board; no shipped seed reaches it |
| D12 | Only in part. The shipped path ends PURIFY_SHRINE on the round the shrine dies, so the changed branch is not exercised |
| D16 | No. Unreachable today |
| D17 | No. No shipped terrain reaches the relaxation |
| D80 | No. Reachable only through `dev_combat_objective` with no active realm |
| D15, D28, D29, D43 | No behaviour changed, so there is nothing to verify |

**D09's decision: do not spawn what you cannot place.** The alternative fallback would have to pick
a cell the placement rule already rejected — either overlapping a living actor, or off the enemy
side. Dropping the spawn is recoverable: the next interval tries again on a board that may have
opened. Both log `count` fields and `recover_reinforce_count` now report placed actors, not built
ones.

**D28's decision: keep the cache.** Both inputs live on `objective_params`, which is written once
during setup, before any round runs, and never written after. Recomputing each round returns the
same number. No code change; the comment now records the proof instead of calling it preserved
behaviour.

**D80 determinism.** No existing draw moved. The spirit-destination generator is per-encounter and
freshly derived, and boards with terrain take the identical path. The new draw happens only on a
legacy board, where none happened before.

| 7 | see commit | D14, D27, D35 | Fixed. **The D35 fingerprint prediction was wrong** — see below. `death_round` was a schema-wide fault, not a single-site one. | None moved |

### Pass 7 — the D35 prediction was wrong, and why

The register predicted D35 would move a fingerprint. It did not, and the reason is checkable:
`tests/FlowFingerprintTests.gd:238-244` hashes the **sorted top-level `data.keys()`**. `emotion_summary`
was already one of those keys, and the shape of its entries is not hashed. So adding two fields
inside the entries cannot move that constant. The "FP" grading on the D35 row was wrong on that
detail.

### Pass 7 — `death_round` was wrong everywhere, not at one site

D14 named one writer. The investigation found the field's documentation was wrong for **every**
writer, and had been before this pass.

Readers found, and what each does:

| Reader | Use |
|---|---|
| `core/sanctum/RecruitmentService.gd:378-381` | `rounds_ratio = death_round / rounds_total` — the only arithmetic reader, and it needs a ROUND |
| `core/actors/ActorStateMachine.gd:579` | copies it into actor snapshot data |
| `core/onboarding/KeeperIntroService.gd:376` | resets it to 0 |

No reader depends on it being a tick. So the fix writes the real round rather than renaming the
field. Renaming would have split one schema field across five writers and broken the recruitment
ratio.

The two documents that described it as a tick are corrected in the same commit:
`core/actors/ActorSchema.gd:39` and `CONVENTIONS.md:307`.

### Raised by pass 7, not fixed

- The D35 row claims producer E "adds both plus `bark`". It does not.
  `core/realms/SituationEngagementService.gd:352-362` emits a SHORTER entry — no `morale_delta`, no
  `refused`, no `bark`, and a hardcoded empty `tag` at two sites. That is a third shape, outside
  D35's scope.
- `tests/KODeathTests.gd:47-48` comments its assertion as a tick. It passes because that fixture
  supplies no round and hits the fallback. The comment misleads; the assertion is correct.

| 8 | see commit | D02 | Fixed. **The count was 11, not 10.** All eleven dead traits implemented and each demonstrated with a with-and-without value. | None moved — and the reason is important, see below |

### D02 — the count was wrong, and two more traits were dead

The register said ten. It is **eleven**. `directive_amplify` and `directive_echo` were also dead. The
`directive_mul` grep hit that made `directive_amplify` look live is `calling_behavior.directive_mul`,
a different config subtree.

The eleven: `aggression_field`, `challenge_call`, `mark_target`, `safe_path_read`, `threat_read`,
`hold_formation`, `position_lock`, `cover_positioning`, `anchor_presence`, `directive_amplify`,
`directive_echo`.

The two authored blocks, per the product owner's decision:
```json
"cover_positioning": { "cover_move_score_bonus": 8.0 },
"anchor_presence":   { "immune_to_displacement": true, "radius": 2.0 }
```

### THE FINDING THAT MATTERS MORE THAN D02 — leadership is invisible to every test

**No recorded scenario contains a Whole-band Echo, so no leadership trait activates in any fixture.**

`leadership_trait_pool._comment` says the traits are "Activated at Whole band".
`band_by_standing` puts Whole at rank 4. `EchoFactory` mints every Echo at rank 1.

So the eleven traits that were ALREADY live are equally dormant in the recorded scenarios. This is a
pre-existing property of the fixtures, not something pass 8 introduced. It is why implementing
eleven traits moved no fingerprint and no baseline.

**Consequence: the baselines cannot see leadership at all.** A Whole-band baseline scenario would be
a genuinely useful addition, and until one exists, every leadership claim rests on probes rather
than on pinned values.

Each of the eleven was demonstrated by probe instead:

| Trait | With and without |
|---|---|
| aggression_field | melee score 68.150 → 76.150 |
| mark_target | melee score 68.150 → 78.150 |
| challenge_call | taunt score 5.000 → 30.000 |
| safe_path_read | move score 81.150 → 89.150 |
| hold_formation | move score 81.150 → 76.150 |
| directive_amplify | melee score 68.150 → 85.175 |
| directive_echo | melee score 68.150 → 78.365 |
| threat_read | retreat gate 0.45 → 0.35; candidate offered true → false at 0.40 HP |
| cover_positioning | bonus 0.0 → 8.0; blocked line detected |
| position_lock | owner immune true, plain actor false |
| anchor_presence | ally in radius immune true, ally outside false, no leader false |

### Raised by pass 8 — three design questions, not defects

1. **The board has no line-of-sight system.** "Cover" is read off the only physical obstruction the
   movement layer knows: an in-bounds non-walkable cell on the straight line to the nearest
   perceived hostile. If real line of sight or destructible cover arrives, that helper is the one
   place to change.
2. **`mark_target` and `aggression_field` are the same effect at different magnitudes** (10 and 8),
   differing only in calling pool. Their key names — `attack_score_bonus` and `melee_score_bonus` —
   suggest a distinction the action vocabulary cannot express, because there is only one attack
   action type.
3. **`challenge_call`'s `taunt_attack_bonus` is 25.0, exactly the hardcoded taunt pull already in
   `_score()`.** It was implemented as the `actor.taunt` score bonus, not as a second copy of that
   constant. If the intent was the other reading, it needs changing.

| 9 | see commit | D84 | Fixed, with HALF the instruction deliberately refused — see below. The Resolve card now carries this run's real bond and Thread movement. | None moved |

### D84 — three of the four producers moved; the fourth did not, and must not

The product owner decided the bond hooks and the Thread contribution should run before the card, at
encounter cadence. Investigating the four producers separately showed that decision is correct for
three of them and wrong for the fourth.

| Producer | Per-encounter correct? | What was done |
|---|---|---|
| `apply_combat_bond_triggers` | **Yes.** It already ran once per victorious encounter, split across two sites, both after the card | Moved ahead of the card |
| `apply_bond_aftermath_modifiers` | **Yes.** `set_modifier` overwrites, so it is naturally repeat-safe | Moved ahead of the card |
| `seed_rival_stage_incidents` | **Yes.** Already idempotent — a pair is appended only when not already queued | Moved ahead of the card |
| `RealmService.contribute_segment` | **NO. It would double-count.** Every entry is keyed by `stage_index` and `ThreadService` counts entries, so one segment per encounter inflates a multi-objective stage's recovery | Made idempotent with a receipt, then contributed only on the stage-clearing fight |

**The receipt uses no new save key.** The already-recorded `stage_index` IS the stamp — the same
"read the stamp, return early" shape `StageSettlementService` uses for `settlement_receipt`.

The `contribute_segment` call in `VentureController` **stays at stage cadence**. It is now a no-op
on the combat path, and it is still the only contributor on the no-encounter path (D05).

**A dead arm was found while investigating.** The `"loss"` arm in `handle_complete_stage` could never
run: a defeat card offers no `cta.next_stage`, so `flow.complete_stage` is never reached after a
defeat.

**A resume bug was fixed as a side effect.** On a stage-clearing victory the segment is now graded
from the fight that cleared the stage even if the player quits at the card and resumes. Previously
that resume path graded it `NO_COMBAT_GRADE` ("C" → "compromised"), because `encounter_ctx` was gone.
So a resumed run was silently recorded as compromised.

### Evidence, captured on a real card

Before:
```
bond_outcome={}  thread_outcome={"realm_id":"realm.01","segments":0,"threads_earned":[]}
```
After:
```
bond_outcome={"triggers":{"outcome":"win","echo_count":5,"ko_count":0,"near_wipe":false,
              "new_friend_pairs":[]},"aftermath":{"grief_ids":[],"shared_survival_ids":[]},
              "rivals":{"added":0,"pairs":[]}}
thread_outcome={"realm_id":"realm.01","segment":{"stage_index":0,"quality_tier":"clean"},
              "segments":1,"threads_earned":[]}
```

Pinned by `pending_result/bond_and_thread_are_on_the_card`, which **fails against the pre-change
core**. It pins the new cadence rather than restating the old one, and it asserts that the following
`flow.complete_stage` appends no second segment.

### Raised by pass 9, not fixed

- `core/save/SaveSchema.gd:34-35` still says the `pending_result` payload is groundwork and that
  "nothing reads or writes this yet". False since Phase 8B.
- The combat-end dispatch's `save_request_reason` now also accumulates `bond.combat_triggers`, and
  `bond.rival_incidents` when a rival pair is seeded. `flow.complete_stage` no longer contributes
  them. No test pins those two dispatches' reason strings.
- `contribute_segment` requests no save of its own and relies on the surrounding dispatch flushing
  for another reason. True before and after.

| 10 | see commit | D85 | Fixed. `save.flow.state` and `save.flow.context` deleted — defaults, validator and repair. | None moved |

### D85 — proved dead before deleting

Every reference was found and classified first:

| Reference | What it did |
|---|---|
| `SaveSchema.gd:31-33` | Defaulted both keys in `make_new_save`. One of only two writers |
| `SaveService.gd:519-526` | Repair. Recreated both if `flow` was missing. The other writer |
| `SaveService.gd:1411-1412` | Validator. Rejected a save with no `flow.state` — a field it also defaulted |
| `FlowRuntime.gd:115` | A comment only |
| Six test fixtures | Set the key. None read it |

No reader of `state` or `context` exists anywhere in `core/`, `ui/` or `tests/`. Every other
`save["flow"]` access reads a different key: `active_directive`, `pending_result`, `vow_outcome`.

**`flow.context` was removed with it.** Same shape, same two writers, no consumer. Keeping one half
of a dead pair would leave the same trap.

**Backward compatibility was proved, not assumed.** `SaveService.validate()` is a whitelist of
required keys with no unknown-key rejection, so a leftover key cannot fail a load. Pinned by
`bridge/legacy_flow_state_context_still_loads`, which builds an old save carrying both keys, runs the
real repair, and asserts the leftovers are untouched, `pending_result` is added, and validation
passes. It then does the same for a save with no `flow` block at all, asserting repair does not
reintroduce the keys.

No fingerprint hashes the `flow` subtree. The SAVE fingerprint reads `economy` and party only, as the
register predicted — checked rather than assumed.

Also corrected in the same change: `SaveSchema.gd:34-35` no longer claims the `pending_result`
payload is groundwork that "nothing reads or writes yet". That has been false since Phase 8B, and
pass 9 made it more false.

### Raised by pass 10, not fixed

Several test fixtures still write `"flow": {"state": …, "context": {}}`. The keys are now ignored.
Cleaning them is churn.

### D62 — the owner's ruling changed the same day. This is the final one.

**First ruling:** expand V2-STAGE-003; write no new story. The addendum was added to V2-STAGE-003
at Order 310 (Ready).

**Then the twin rule was applied.** The database holds duplicate story codes. V2-STAGE-003 also
exists at Order 236 with Status Done, and that page carries the shipped contact work. The owner's
rule is: when one twin is Done, the other twin is not used. So the addendum was removed from
Order 310, and that page was returned to exactly its previous state — every property unchanged.

**Then the owner authorised a new story, conditionally:** "if no other story applies then yes a new
story is needed."

**Thirteen open stories were checked and each was rejected with a reason** — V2-INFRA-005 (death
ripple only), V2-INFRA-004 (before the stage, not after), V2-SANCTUM-005 (generates house events,
does not own who calls the tick), both V2-INTEL-002 rows, V2-COMBAT-003 and V2-COMBAT-004 (both stop
at Resolve), V2-STAGE-002 (generation, not consequence), and six Draft stories that mention contacts
but own content breadth or authoring vocabulary. No open story fitted.

**FINAL: a new story was created — `V2-INFRA-007 — contact resolution consequence parity`.**
Status Ready, Order 262.5, depends on V2-INFRA-003.
https://app.notion.com/p/3cac3d1ede9281f58864c9d15a954952
Four properties were left empty rather than guessed: Priority, Spec State, Source GDD, Legacy Source.

The two stale `ContactController.gd` comments that named the never-built `EncounterResolutionService`
now name V2-INFRA-007 instead. Fixed in the documentation pass, commit `d0d5125`.

### Notion filings made for this story — 2026-08-28

| Defect | Story | Page | What was added |
|---|---|---|---|
| **D61** | V2-SANCTUM-004 (Order 340, Ready) | https://app.notion.com/p/339c3d1ede92810ebcb4c71776d816a5 | The institution passive-accrual defect, **plus an added scope line for authoring the first institutions' passive values and their upkeep**. That item sat with V2-SANCTUM-002 (GDD 21.2 item 8), which Notion now marks Done, so it was otherwise orphaned. The strain warning surface (GDD 21.2 item 7) stays with V2-SANCTUM-005. |
| **D62** | V2-INFRA-007 (Order 262.5, Ready) — NEW | https://app.notion.com/p/3cac3d1ede9281f58864c9d15a954952 | See the D62 correction above for why a new story was the final answer. |

No property was changed on V2-SANCTUM-004. Its Superseded twin at Order 239 was not touched.

---

## MANUAL TEST 2 — TWO COMBAT SYMPTOMS UNDER DIAGNOSIS, 2026-08-29

The product owner played the branch and reported two problems. Diagnosis is running. **Nothing has
been fixed, and nothing will be, until the mechanism is reported and he decides.**

### Symptom A — actors stand at range and never engage

A new campaign, first real encounter. One Echo at (1,1), one enemy at (11,0), ten columns apart.
Both choose `actor.idle` for twelve consecutive rounds. Neither closes. `Echo helplessness — morale
decay` fires every round. The same shape appears on a long board at columns 11 against 49.

### Symptom B — a GUIDE_SPIRIT escort that cannot be completed

The spirit logs `Movement skipped (structure)` every round. `MovementExecutor.gd:282` skips any
actor carrying `is_structure`. The spirit is built as a `StructureActor` in the "protect, or escort
without joining" branch of `EncounterObjectiveSpawnService.gd`. But the objective is an ESCORT, so
`GUIDE_SPIRIT escort progress` logs every round from t:167 to t:602 and never completes: the spirit
cannot walk to its destination.

**If escort can ever be paired with a non-joining spirit, that objective is unwinnable by
construction.** No player action can complete it. Only the timer ends it.

On top of that the fight deadlocks. One Echo sits at fear 100 refusing every round; the enemy
attacks it for **0**. Neither side can reduce the other. This differs from the product owner's
manual-test-1 ruling that a fight always reaches an end state — at zero damage there may be no end
condition in reach. Being established.

### RESULT — BOTH ARE PRE-EXISTING. Verified 2026-08-29. No action taken.

**Jeff's decision: these are pre-existing, so we do nothing and note them.** They are recorded here
as findings of this story, not as work for it.

The method below was carried out. A separate `main` worktree was built and both symptoms were
reproduced on each tree.

| Scenario | Result |
|---|---|
| Forced two-body case — Echo (1,1), enemy (11,0), 12x12 board | **Byte-identical to `main`** |
| Long board, 60 columns, GUIDE_SPIRIT | **Byte-identical to `main`** |
| Forced escort with a non-joining spirit | **Byte-identical to `main`** |
| Twelve real new campaigns, `boot()` through the prologue | Echo closes and wins in 7-9 rounds. No stall |

No bisect was needed. Nothing in the story's 31 commits causes either symptom.

#### Symptom A is two separate things

**1. The `actor.idle` label on a MOVING actor is normal.** In every run the Echo advances two cells
per round while the recorded `action_type` reads `actor.idle`. Identical on `main`. Most of what
reads as twelve idle rounds is twelve rounds of approach across a long board. Confusing, not broken.
Renaming it would move fingerprints for no gameplay gain.

**2. The real freeze is movement-option starvation.** For the frozen Echo the movement layer reports
`goals=1, options=0`, while every other actor has one option. With zero options the arbiter ranks
only stationary candidates and its unconditional `actor.idle` wins.

`core/movement/LiveMovementContextService.gd:191-199` gates the movement-aware layer on GOALS, not
options, and relies on the arbiter's stationary fallback in `BehaviorArbiter._generate_candidates`.
That is safe on a 10x10 board. On a long board an actor whose goal region is not routable within its
2-cell capacity gets no option — and because it does not move, it never gains one. **The stall
sustains itself.** `Echo helplessness — morale decay` (`core/combat/CombatRoundEmotionService.gd:334`)
then fires every round.

Three checks confirmed clean: pass 8's leadership traits are inert here (`expression_band` is
`"nascent"`, and `is_whole_leader` gates every trait); the pass 2 directive default moves nothing
(`directive_action` is `""`, `decision_scale` is `0.0`); and the ANSWERS #48 move-then-attack fix is
still effective.

#### Symptom B — about one guide-spirit encounter in four is unwinnable

`core/combat/EncounterObjectiveSpawnService.gd:411-427` builds the spirit as a `StructureActor`
whenever the joins-battle coin flip loses — and that `else` branch covers **protect AND escort**.
The mode roll (`:337-357`) and the joins roll (`:373-380`) are two independent 50/50 draws, so
escort-plus-structure occurs about **25% of the time**. `core/movement/MovementExecutor.gd:282` then
skips it, because it carries `is_structure`.

**No player action can complete that objective. Only the timer ends it.** D80 and D92 are not
involved: the destination was real, not `(-1,-1)`, and the D92 guard only tightens the win latch.

#### The zero-damage deadlock has no reachable end condition

`core/combat/CombatService.gd:126` returns `max(0, base + morale_bonus - fear_penalty)`. Damage
floors at **0**, not 1. A guarding defender doubles `def`; a high-fear attacker loses up to 5.
COMBAT mode requires a kill and there is **no round cap anywhere** — no `max_rounds` exists. So a
fight in which every swing lands 0 and both sides refuse or guard runs for ever. The formula is
unchanged from `main`.

**This is the case the manual-test-1 ruling did not cover.** That ruling was correct for its own
case: enemies were still dealing 1-2 damage, so the fight did terminate.

#### One real difference between the trees, explained and NOT chased

In a plain-combat sample an enemy at 4 HP chose `actor.guard` on the branch and `melee_attack` on
`main`. This is not either symptom. The suspect is the near-death morale and fear hook from
`39cfbaf` — connect case 1 of 4, which the product owner approved, and which by design changes
behaviour at low health. Behaving differently at 4 HP is what that change is FOR. Recorded, not
bisected.

#### Suggested owners, if these are ever picked up

| Item | Nature | Natural owner |
|---|---|---|
| Movement-option starvation on long boards | Movement | The movement story |
| Escort paired with an immobile spirit | Objective selection, not movement | Guardable at the decision point, keeping the draw-then-override shape |
| Zero-damage stalemate with no round cap | Combat or fear economy | The fear-economy work |

---

### The method — comparison, not reasoning

Reasoning about causation is how this story's earlier fingerprint prediction went wrong. So
causation is being settled by reproducing both symptoms on a separate `main` worktree, then
bisecting the full `main..HEAD` range — **all 31 commits of the story, not only the ten fix passes**.

Half A is the prime suspect for symptom A, not the fix passes. The whole movement family was
extracted during this story — `LiveMovementContextService`, `MovementExecutor`,
`CombatActivationService`, `EncounterSetupService`, `EncounterObjectiveSpawnService`. A move meant to
preserve behaviour exactly is the kind of change that can alter scoring with no test noticing. Pass 8
already proved the baselines cannot observe leadership at all, so a green suite is weak evidence here.

One narrowing hint, not a boundary: the product owner played and approved a session at `2d5d629`,
after all four connect commits, and combat behaved acceptably. He may simply not have met this board
geometry.

### DECISION — Jeff, 2026-08-29

**If the cause is movement-related and was introduced by this story, the fix does NOT happen here.**
It is filed to the next movement story to be picked up. The movement work is still in progress, so
this story does not try to finish it.

This story's job is to REPORT the mechanism precisely enough that the movement story can act on it —
the commit, the file, the line, and the divergence from `main`.

---

## D93 — Thread count ignores Realm size. RECORDED, KNOWINGLY DEFERRED.

| Field | Value |
|---|---|
| **ID** | **D93** (added 2026-08-29) |
| **Defect** | The Thread payout of a completed Realm is derived from an AVERAGE, so it carries no information about how large the Realm was. |
| **Location** | `core/progression/ThreadService.gd` — `_derive_quality()` divides the summed segment weights by `segments.size()`, and `_resolve_count()` maps that float through `data.threads.count_thresholds`. |
| **Effect** | A one-stage Realm cleared cleanly scores 1.0, the same as a ten-stage Realm cleared cleanly, and takes the top count of three. Volume is invisible to the reward. |
| **How it surfaced** | `realm.prologue` has exactly one stage. Cleared cleanly it paid **three** Threads — the maximum a full Realm can pay. Measured on a real run through `flow.complete_stage`. |
| **Decision — product owner, 2026-08-29** | **Pin the prologue, do not change the formula.** The prologue now pays a fixed one Thread (`RealmService.PROLOGUE_THREAD_COUNT`, applied in `ThreadService.crystallize_threads`). Its virtue and quality tier still come from the run. Correcting the formula changes the payout of EVERY Realm, which is a real economy change and larger than this story. |
| **Owner** | **`V2-ECONOMY-004`** — reward vocabulary and weighting. It owns any change that makes Thread count sensitive to Realm size. |
| **Status** | **NOT FIXED. Deferred by decision.** Do not act on it here. |


---

## D94 — a stage with no REQUIRED objective was completable, and paid, on entry. ✅ FIXED.

| Field | Value |
|---|---|
| **ID** | **D94** (added 2026-08-29, found in manual play) |
| **Defect** | The stage-completion gate offered `flow.complete_stage` whenever no *required* objective remained incomplete. It never checked whether the stage's objective situations had been reached. On a stage where every objective is optional, the gate was open from entry, and the settlement paid a full stage reward for walking one step. |
| **Location** | Gate: `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd:389`. Payer: `core/runtime/controllers/VentureController.gd:648` (`_stage_cleared := is_combat_victory or not has_encounter` → `StageSettlementService.settle()`). Trigger: `handle_ignore_situation` at `VentureController.gd:421` sets `passed = true` and clears `pending_situation_id` at `:424`, which removes the gate's last blocking term. |
| **Mechanism** | `objectives_remaining` (`StageExploreSnapshotBuilder.gd:283-287`) counts only `stage.objectives` entries flagged `required`. `RealmGenerator.gd:152` writes the boss objective `required = false` unconditionally, and `:146` makes a `pursue` pre-boss optional. `realm.01` generates exactly two objectives (`data/realms.json:45-46`), so a `pursue` roll leaves the stage with **no** required objective at all. The explore map already tracked the honest pair — `objectives_found` against `objectives_total` — and the gate ignored it. `passed` is a red herring for the payment: it only cleared `has_pending`. |
| **Measurement** | **115 of 800 generated `realm.01` stages (14.4%) have zero required objectives.** Probe over 200 seeds × 4 stages, run against `main`. Sample: `["pursue(req=false)", "boss(req=false)"] obj_total=1`. |
| **Farmable?** | **No.** `StageSettlementService`'s `settlement_receipt` (`:108-110`, written `:163`) is keyed per `(realm, stage_index)`, and `RealmService.advance_stage()` moves the index on in the same dispatch. Each qualifying stage pays once. The loss is skipped content, not unbounded Ase. |
| **Pre-existing or ours?** | **The gate is pre-existing** (V2-STAGE-002; identical line on `main` at `FlowStageExploreState.gd:551`), and so is the `passed` write (`main:FlowRuntime.gd:8238`). **The payment is ours.** On `main`, `_handle_complete_stage` contains no economy call — walking such a stage advanced it and paid nothing. Commit **`091bcfd`** (Phase 8A) introduced `_stage_cleared := is_combat_victory or not has_encounter`, which pays the no-encounter path as the intended D05 fix. That fix is correct; it exposed the hole in the gate. |
| **Fix — product owner, 2026-08-29** | **Fix the gate, not the generator.** The condition gained an `objectives_found >= obj_total` term, so a stage completes only once its objective situations were actually engaged. Changing `RealmGenerator`'s `required` flags would move recorded values for every realm — a far larger change for the same outcome. |
| **Completability** | A stage whose objectives are all optional stays finishable. Once the frontier is exhausted, `ActiveStageService.find_explore_target` Tier 4 (`:486-505`) re-offers a passed objective, and `situation_blocks_step` (`:225-239`) re-prompts on that deliberate re-target (`id == target_sit_id`). Verified at the site before the fix shipped. |
| **Cover** | `objective/zero_required_blocked_until_reached` (both halves: blocked while unreached, offered once reached) and `objective/required_stage_gate_unchanged` (normal stage gates as before), in `tests/StageObjectiveTests.gd`. |
| **Status** | **FIXED.** |

---

## D95 — the generator ignores the authored per-type `required` flag. RECORDED, NOT FIXED.

| Field | Value |
|---|---|
| **ID** | **D95** (added 2026-08-29, found while diagnosing D94) |
| **Defect** | `data/balance.json:2958-2965` authors a `required` flag per objective type under `data.stages.objective_types`. `RealmGenerator.gd:146` ignores it and hardcodes `is_required = (obj_type != ObjectiveModel.TYPE_PURSUE)`. |
| **Effect** | `guide_spirit` is authored `required: false` but is generated `required = true`. The authored flag is dead config for every type: the only consumer of that subtree, `FlowStageExploreState._build_objective_entries` (`:300-311`), reads `label` and `reveal_hint` from it and takes `required` off the objective dict instead. |
| **Why not fixed here** | Honouring the authored flag makes `guide_spirit` optional, which changes which stages have required objectives and therefore moves generation-derived recorded values. Out of scope for a gate fix. Note the direction: this would create MORE zero-required stages, which D94's gate now handles safely. |
| **Owner** | Whichever story next touches objective generation. Fix by reading `required` from `objective_types[obj_type]`, defaulting true. |
| **Status** | **NOT FIXED. Recorded only.** |

---

## D96 — the boss objective is always optional. RECORDED, NOT FIXED BY DECISION.

| Field | Value |
|---|---|
| **ID** | **D96** (added 2026-08-29, found while diagnosing D94) |
| **Defect** | `RealmGenerator.gd:152` appends the final boss objective with `required = false` on every stage of every realm, unconditionally. |
| **Effect** | This is the root cause of D94. Because the boss never counts as required, a stage's required set is decided entirely by its pre-boss objectives — and `realm.01` has exactly one of those. It also means no stage anywhere requires its boss to be engaged. |
| **Decision — product owner, 2026-08-29** | **Fix the gate (D94), not the generator.** Making the boss required would change the required-objective set of every stage in every realm, moving recorded values across the whole generation surface, and would alter difficulty as well. The gate fix removes the exploit without touching generation. |
| **Owner** | Whichever story owns boss encounters. `TYPE_BOSS` is still a stub (`ObjectiveModel.gd:25`), so requiring it before boss combat exists would soft-lock stages. |
| **Status** | **NOT FIXED. Deferred by decision.** Do not act on it here. |

---

## D97 — ENEMIES SHARE THE ECHO EMOTIONAL MODEL AND ALWAYS REFUSE EVENTUALLY

**Pre-existing. Verified byte-identical on `main`. Noted, not fixed, per Jeff 2026-08-29.**

Reported from play: "enemies are too similar to echoes, they refuse and do nothing even when they
have the upper hand." Observed in a battle past 70 rounds.

### Enemy refusal is UNAUTHORED

Every refusal reference in the GDD (`:251`, `:1284-1305`, `:1388-1419`) frames refusal as an ECHO
declining the Keeper's directive. No line describes a Distortion or enemy refusing. `ANSWERS.md`
#45, #47 and #49 discuss only Echo fear. **The enemy path is an accident of a shared state machine,
not a design.**

### Every relief term is Echo-gated; enemies have none

| Term | Applies to |
|---|---|
| Fear per hit (+2), near-death (+8), ally-KO spread (+4), per-round tick (+1), overwhelmed (+5) | **Both** |
| Absolute Fear Rule → `actor.refuse` | **Both** |
| Outnumber fear relief | Echo only |
| Kill relief and ally ripple | Echo only |
| Passive rank-scaled fear tick | Echo only |
| Identity fear relief | Echo only |
| Leadership fear and morale dampening | Echo only |

Enemies also receive no leadership dampening, so `apply_fear_gain` returns the raw amount for them.

### Enemy fear is monotonic, so refusal is inevitable

Measured through the production path over 80+ rounds, with an enemy given effectively infinite HP and
500 defence — that is, winning outright:

`1, 2, 12, 26, 38, 50, 53, 67, 81, 95, 100 …` then 100 for the remaining 79 rounds. Echo fear stayed
at 0.

The per-round tick (`CombatRoundEmotionService.gd:150-155`) is unconditional on every living
non-structure actor. It does not read HP, damage, or who is ahead. Nothing subtracts.

**And the enemy threshold is the lowest in the game.** `actor_type "enemy"`
(`core/actors/EnemyActor.gd:58`) never gets a rank, so its band is `nascent`, and
`calling_behavior.uncalled` has no `absolute_fear_offset` — so it takes the raw band base of **65**,
while a grounded Echo sits at **80**. The +1 tick alone reaches 65 by round 65 with no contact at all.

### The options, if this is ever picked up

| Option | Blast radius |
|---|---|
| Gate the Absolute Fear Rule to `faction == "echo"` (`ActorStateMachine.gd:286`) | Smallest. Enemies keep fear as a scoring input but never freeze. Moves combat fingerprints and baselines |
| Give enemies a symmetric relief term | Larger. Touches the round tick and needs re-tuning |
| Give enemies their own threshold or band | Cheapest tuning fix, but a winning enemy still ratchets to 100 |
| Make the per-round tick threat-aware for all factions | Most principled, biggest radius. Changes Echo fear too and re-opens the ANSWERS #47/#49 rebalance |

Related and already recorded: damage floors at 0 (`CombatService.gd:126`) and there is no round cap
anywhere, so a long fight has no forced end.
