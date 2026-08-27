# V2-INFRA-003 — Defect Register

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

**Register accounting.** Identifiers run **D01–D90**. Six of them (D71–D76) are **coverage gaps,
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
| **D01** | Near-death morale + fear trigger reads `max_hp` at top level; never fires | `core/combat/CombatTurnActionService.gd:321` (header note `:82-95`). **Handoff/brief said ~315 — corrected.** | `var nd_max_hp: int = int(target.get("max_hp", 1))` — actors carry `stats.max_hp`, never a top-level copy (`core/actors/EchoActor.gd:45,55` builds `stats` + `current_hp`, no `max_hp`). Default `1` passes `nd_max_hp > 0`, then `current_hp * 4 <= 1` is unsatisfiable for any living actor. Two authored keys unreachable: `data/balance.json:1662-1663` `morale_on_near_death: 7`, `fear_on_near_death: 8`. Correct sibling reads verified at `BehaviorArbiter.gd:1625`/`:2284`, `ActorService.gd:86`, `LiveMovementContextService.gd:816`/`:921`. | **Yes** — code path is on the main melee-damage line, executed every damaging turn; only the condition is unsatisfiable. | Currently **none** (has never fired). After fix: every Echo and enemy dropping to ≤25% HP gains morale and fear once per actor — a real combat-tension beat that has never existed. | **DECISION TAKEN — goes live.** Read `stats.max_hp` with the `LiveMovementContextService` fallback idiom. **Sequenced after the Phase 6 extraction completes**, as its own commit, with an explained baseline update. | **FP + BL.** Turns on morale/fear writes inside the round loop → moves `CombatBaselineTests` per-actor fear/morale hashes across all seven modes, and `FlowFingerprintTests` wherever emotion feeds the final snapshot. This is why it must not land mid-extraction. |
| **D02** | Ten leadership trait effects are authored with parameters nothing reads | `data/balance.json` → `data.maturity_expression.leadership_trait_effects`; consumer is `core/combat/LeadershipEmotionService.gd:19-20` (+ `core/actors/ActorStateMachine.gd`) | Repo-wide grep for each key returns **zero readers in `core/` or `ui/`**: `melee_score_bonus` (`aggression_field`), `taunt_attack_bonus` (`challenge_call`), `attack_score_bonus` (`mark_target`), `move_score_bonus` (`safe_path_read`), `retreat_threshold_reduction` (`threat_read`), `move_score_reduction` (`hold_formation`), `directive_bonus_mul` (`directive_echo`), `immune_to_displacement` (`position_lock`), plus `anchor_presence: {radius}` (no effect body at all) and `cover_positioning: {}` (authored empty). The sibling keys that *are* read — `morale_per_round`, `fear_reduction`, `morale_boost`, `radius`, `fear_accumulation_factor`, `morale_lock_rounds`, `morale_loss_reduction`, `fear_transmission_rate`, `directive_mul` — all resolve, which is what makes the gap invisible. | **Unknown.** The traits are authored and can be rolled onto Echoes; the *effect* is unreachable. Whether all ten trait ids are actually in a live grant pool was not verified. | Ten leadership traits are cosmetic. A player who builds toward `mark_target` or `threat_read` gets nothing. | Product-owner call per trait: implement in `BehaviorArbiter` scoring (six of them are scoring bonuses and belong there, not in `LeadershipEmotionService`), or delete the trait + its balance block. Do not implement all ten blind. | **FP + BL** if any scoring bonus is implemented — arbiter score changes re-roll movement and target choice, which moves every combat fingerprint. Deleting the config alone is `—`. |
| **D03** | The `data.voice` bark budget block has no reader | `data/balance.json` → `data.voice.max_barks_per_round: 3`, `.max_reactions_per_original: 1`, `.bark_tiers` | Zero readers repo-wide for all three keys. `core/echoes/NarrativeVoiceService.gd` fires barks unbudgeted and untiered. **`core/combat/CombatRoundEmotionService.gd:223` even comments "it also breaks the bark budget (max_barks_per_round 3)" — the code believes a budget exists.** | **Yes** — barks fire in every combat round; the cap simply never applies. | Bark spam in busy rounds; the authored tier-1/2/3 priority ordering (last-stand / KO lines vs. chatter) never arbitrates, so a dramatic line can be drowned out. | Either connect the budget in `NarrativeVoiceService` (cap per round, prefer higher tier) or delete `data.voice` and the misleading comment. | **BL.** `CombatBaselineTests` and the round-bark integration suites pin `round_bark_events`; capping changes their contents. `—` for fingerprints (barks are not in the final-snapshot key set). |
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
| **D14** | Guide-spirit hazard deaths record the sim tick as `death_round` | `core/movement/LiveHazardOutcomeService.gd:70` (documented `:34`) | `actor["death_round"] = t` — `t` is the sim tick, not the round counter. | **Yes** — GUIDE_SPIRIT hazard deaths. | Low; corrupts any post-hoc "died in round N" readout. | Pass the round counter. | **BL** if `death_round` is in any pinned payload — **UNVERIFIED** whether it is; check before scheduling. |
| **D15** | `_gs_spirit_pos` goes stale in the protect branch | `core/combat/CombatRoundGuideSpiritService.gd:200` captured, refreshed at `:289` only on one branch; re-read at `:214/:234/:249` | The protect path evaluates adjacency against a position captured before the spirit may have moved. | Yes (GUIDE_SPIRIT protect). | Low-medium: escort/protect adjacency judged one step late. | Re-read after any spirit move. | **BL** — GUIDE_SPIRIT baseline. |
| **D16** | Unrecognised `guide_mode` silently does nothing | `core/combat/CombatRoundGuideSpiritService.gd:162-163` | `return guide_mode == "escort" or guide_mode == "protect"` — any other value disables the whole phase with no warn. | **No** — only two values are ever written today. | None. | Warn on unknown mode. | `—` |
| **D17** | Escort win latch can fire on a spirit that never moved | `core/combat/CombatRoundGuideSpiritService.gd:298-302` (`escort_started` "set once and never cleared", `:49`). Producer side now at `core/combat/EncounterObjectiveSpawnService.gd` (escort-destination block, moved from `FlowEncounterState.gd:764-812` by slice 6I). | Destination match is checked without requiring movement to have occurred. | **ANSWERED 2026-08-24, slice 6I — YES, overlap is possible, via the relaxation branch.** The producer picks the spirit's spawn cell as `_gs_candidates[0]` and then picks the destination out of `_gs_far_candidates`, which is `_gs_edge_candidates` filtered to Chebyshev distance `>= destination_min_distance` (6). While that filter holds, overlap is impossible. But when **no** frontier cell clears the distance, the code relaxes to `_gs_far_candidates = [_gs_edge_candidates[0]]` after sorting by distance **descending** — with **no distance floor at all**. `_gs_edge_candidates` is a subset of `_gs_candidates`, which contains the spawn cell, so if the spawn cell is itself a frontier cell and is the only frontier cell among the unoccupied walkables, the farthest edge cell IS the spawn cell and destination == spawn. The latch then matches on round 1. Needs a terrain island with exactly one unoccupied frontier cell — rare, but not impossible, and StageTerrain can produce small pockets. | Instant escort win, one round, no movement. | **Do not change the relaxation, change its floor:** require `dist > 0` (or `>= 1`) in the relaxed branch, and fall through to no destination when even that fails. Do NOT chase it in the latch — the latch is correct given a valid destination. | **BL** if reachable in a shipped seed — the seven mode fingerprints pin GUIDE_SPIRIT end-of-round positions, and today no shipped seed hits the relaxation branch (`combat_baseline` is green on the current terrain). Adding the floor moves nothing until a seed reaches it. |

---

## Kind 2 — DEAD-SUPERSEDED
*No caller, or replaced. Delete.*

| ID | Title | Verified location | Evidence | Reachable | Impact | Action | Blast radius |
|---|---|---|---|---|---|---|---|
| **D18** | `title` — dead snapshot key, zero consumers | `core/state/flow/states/venture/ResolveSnapshotBuilder.gd:213-219` (block 16); emitted by producers A, B, F. Also `core/state/flow/states/FlowResolveState.gd:22-24`. | "`title` is a dead key with zero consumers in `ui/`, `core/` or `tests/`." Duplicate record: `docs/resolve-snapshot-block-spec.md:136` and `:449`; handoff `:403` (Q3 decision). | Written every resolve; read never. | None. | **Delete — decision already taken to defer, not to keep.** Handoff Q3: kept in Phase 5 only because deletion drifts producer A's seven fingerprints, "cheap to re-record in Phase 6". Do it with the next fingerprint re-record. | **FP — moves all seven `data_keys` hashes.** Bundle with D01/D04. |
| **D19** | `note` — dead snapshot key, zero consumers | `core/state/flow/states/venture/ResolveSnapshotBuilder.gd:221-226` (block 17); producer F only. | Same as D18. Duplicate: spec `:137`, `:449`. | Written on the fallback resolve only. | None. | Delete with D18. | **FP** (producer F has no test anywhere — see D34 — so the fingerprints are the only guard). |
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
| **D27** | Movement decision (`goal_id` / `option_id`) is never stored or logged | `core/runtime/FlowRuntime.gd` `_resolve_next_actor` (handoff `:597-600`) | Private local, never persisted. **"A refactor that reaches the right cell for the wrong reason passes silently."** Stated in the handoff as a permanent gap. | n/a — it is an observability hole, not a mechanic. | None directly; it is the reason the whole movement refactor is under-guarded. | Log the decision. Needs a production change → own story. | `—` (adds a log only). Do it **before** the `_movement_*` verbatim move, not after. |
| **D28** | `total_waves` frozen on the first ENDURE round | `core/combat/CombatRoundSpawnService.gd:317-323` (`if not combat_state.has("total_waves")`), read back at `:437`/`:445` | Computed once from the interval range; if the encounter's duration config changes mid-fight the stale count drives `all_waves_spawned`. Also: `total_waves` and `initiative_order` are **outside fingerprint cover** (handoff `:653-657`) — guarded only by `combat_baseline` and `objective_combat`. | Yes; harmless while duration is immutable. | None today. | Leave, but record the fingerprint gap. | `—` |
| **D29** | ~60 duplicated placement lines including a determinism-critical sort | `core/combat/CombatRoundSpawnService.gd:367-402` vs `:404-435` | Character-for-character duplicates, now confined to one file — "which is the precondition for fixing it". | n/a | none | Deduplicate. Pure refactor, but the sort is determinism-critical → must be byte-identical. | **BL** if the sort changes at all. |
| **D30** | `data.combat.objective_modes` has no `ConfigService` owner — read longhand at 5 sites | Sites verified: `core/combat/CombatRoundObjectiveService.gd` (×3, header `:116-120`), `core/combat/CombatTurnContextService.gd:73-75`, ~~`core/state/flow/states/venture/FlowEncounterState.gd:347`~~ → **`core/combat/EncounterSetupService.gd:420` (moved, slice 6I 2026-08-24)**, `core/runtime/FlowRuntime.gd:2232` — **the last is stale, `FlowRuntime.gd` is now 2,070 lines.** `BehaviorArbiter.gd:1761/1788` read the same subtree from a pre-narrowed dict. | Two headers record this independently (4 sites, then a 5th). Merged here. | n/a | none | Add `ConfigService.get_objective_modes_cfg()`. Deliberately not done during extraction because the reads were *moved*, not copied. | `—` |
| **D31** | `data.combat.shrine` has no `ConfigService` getter | `core/combat/CombatRoundShrineService.gd:146-148` | Read longhand as it was in `_end_round`. | n/a | none | Same as D30. | `—` |
| **D32** | `ConfigService.get_rewards_cfg` has no `config_service == null` guard, unlike its siblings | `core/config/ConfigService.gd:278-285`; sibling with the guard at `:263-264` (`get_economy_cfg`). Originally recorded in `core/realms/StageExploreSessionService.gd` header (that file is now `core/realms/ActiveStageService.gd` — renamed by Half A review correction C4, 2026-08-24) / handoff `:381-383`. | **VERIFIED.** `get_rewards_cfg` calls `config_service.get_balance()` on line 279 with no null check; `get_economy_cfg` opens with `if config_service == null:`. | Yes — any caller reaching it before config load nils out. | None observed (config loads at boot). | Add the guard for parity. Adding it *is* a behaviour change, which is why the extraction slice left it. | `—` |
| **D33** | The realm XP multiplier formula is written twice from two sources | `core/state/flow/states/venture/FlowEncounterState.gd:682` (was `:1830-1835`; **re-verified after slice 6I**) (`realm_xp_mult = 1.0 + float(run_index) * mult_rate`, `run_index` from `:590`) vs `core/progression/ProgressionService.get_realm_xp_multiplier()` at `:275-287` | Two independently sourced `run_index` values; "collapsing them is behaviour-adjacent, not extraction, because the two sources may differ." | Yes — both run. | Unknown; they may already disagree. | **Measure whether they differ before collapsing.** If they do, that is a live XP defect, not a duplication. **MEASURED 2026-08-24, slice 6J — THEY CANNOT DIFFER. This is pure duplication, not an XP defect.** Standing at the site (now `FlowEncounterState.gd:169` for `run_index`, `:261` for the formula, after slice 6J moved 589 lines out of this file): the inline path reads `RealmService.get_active(flow_ctx)` which is literally `save_data["realms"][flow_ctx.realm_id]` (`RealmService.gd:143-147`); `ProgressionService.get_realm_xp_multiplier(realm_id, save_data, prog_cfg)` reads `save_data["realms"][realm_id]["run_index"]` (`:281-288`). Same dict, same key, and its only caller passes `flow_ctx.realm_id` (`ContributionLedgerService.gd:206`). The two "independent sources" are one source. Every guard branch agrees too: empty `realm_id` -> `get_active` returns `{}` -> `run_index` 0 -> `1.0 + 0*rate` = 1.0, which is what the service's early return also gives; `rate <= 0.0` -> the inline `if mult_rate > 0.0` leaves `realm_xp_mult` at 1.0, same as the service. So collapsing the inline formula onto `ProgressionService.get_realm_xp_multiplier()` is a **behaviour-neutral deduplication**, not the behaviour-adjacent change this row assumed. | **FP** if they differ and the fix changes awarded XP. **Revised after the 6J measurement: `—`.** They do not differ, so the collapse moves no XP and no fingerprint. |
| **D34** | `STATE_ESCAPED` "written and never read" — **claim corrected** | Written at `core/runtime/controllers/VentureController.gd:343`; read at `core/realms/StageExploreTurnService.gd:119` (gates `advance_turn`), `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd:67/279/445`, rendered at `ui/screens/venture/StageExploreScreen.gd:602`. | The handoff (`:270`) says it is never read. **That is wrong as written**: `party_state` is read generically — it gates further exploration and is displayed capitalised in the UI. What is true is that **no code branches on `STATE_ESCAPED` specifically**. | Yes | None. | Downgrade to a note. Do not delete the constant. | `—` |
| **D35** | Producer B omits `direction` and `tag` from emotion entries | `core/state/flow/states/venture/ResolveSnapshotBuilder.gd:147-153` (block 9) | A adds `direction` + `tag`; E adds both plus `bark`; B has neither → the keeper-trial resolve renders grey default tokens and no direction cue. Duplicate: spec `:6.3 item 5`. | Yes — every keeper trial resolve. | Low-medium: the trial's emotional outcome reads as neutral when it is not. | Add the two keys to B. | **FP** — B is fingerprinted (`data_keys`). |

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
| **D53** | Mode-directive block re-reads config instead of the `balance` dict handed in | `core/combat/CombatTurnContextService.gd:69-72` | Same immutable object in production (`load_balance()` runs once at boot), so they cannot differ today. | Yes, benign. | None. | Use the passed dict. | `—` |
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
| **D67** | `SaveSchema.make_new_save()` writes `active_directive_id = "directive.none"`, immediately rewritten by repair | Handoff `:809-811` | **Phase 11 docs** + a schema fix | Consequence: **the V1→V2 directive migration is LIVE, not dead.** Fix the schema default first, *then* the migration can be removed. Order matters. |
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
| **D18 / D19** | Delete `title` and `note` | **Yes — seven `data_keys` hashes** | No | Bundle with D01/D04's fingerprint re-record. Decision already taken to defer, not to keep. |
| **D07** | Read flattened `morale`/`fear` in the scout preview | No | **Yes** — `VentureCharacterizationTests` | Any time. One line. |
| **D37 + D38** | Flip `skip_if_already_resolved` and `commit_only_when_modified` on path (B) | Check `objectives_remaining` in producer A | **Yes** | One fix, two flags. The parameters already exist — this is the cheapest real repair in the register. |
| **D08** | Add the missing dot to the retreat seed fallback | No | No (unreachable) | Any time. Zero risk. |
| **D10 / D11** | Clear `_double_damage_mult` with its partner | No | No | Any time. |
| **D30 / D31** | Give `objective_modes` and `combat.shrine` a `ConfigService` owner | No | No | Any time. Pure consolidation. |
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
| **D84** | A run's bond and Thread consequences do not exist yet when its Resolve card is published | Producers: `core/runtime/controllers/VentureController.gd::handle_complete_stage` — `apply_combat_bond_triggers`, `apply_bond_aftermath_modifiers`, `seed_rival_stage_incidents`, and `RealmService.contribute_segment`. Consumer that wants them: `core/state/flow/PendingResultService.gd::_build_result` (`bond_outcome`, `thread_outcome`). | The Resolve card is published by the dispatch that ENDS the fight. All four of the above run in the `flow.complete_stage` dispatch — the one the card's `cta.next_stage` triggers, i.e. the dispatch that CONSUMES the durable result. At capture time neither a bond outcome nor this stage's Thread segment exists anywhere in the process, so `save.flow.pending_result.bond_outcome` is written `{}` and `thread_outcome` carries only the realm's standing recovery-track count plus `flow_ctx.last_realm_threads_earned` (non-empty only when a realm completed). The schema at `SaveSchema.gd:34-45` names both keys, which is why this is recorded rather than silently dropped. | n/a — it is an ordering fact, not a mechanic. | **None today.** No screen reads either key. It becomes an omission the moment a Resolve card wants to show "the bonds this run changed". | Either move the bond hooks and the segment contribution ahead of the resolve card (a real behaviour change — they currently run once per STAGE, the card once per ENCOUNTER, so they are not the same cadence), or accept that a durable result records the ENCOUNTER and let a later Sanctum surface report the stage's bond/Thread movement. **Do not "fill in" these two keys from save state at capture time** — that would record the party's standing bonds as if they were this run's outcome. | `—` today (nothing reads the keys). |
| **D85** | `save.flow.state` is defaulted and validated but written by nothing, and `boot()` restores `realm_id` without `stage_id` | `core/save/SaveSchema.gd:31-33` (default `"flow.splash"`), the validator, and `core/save/SaveService.gd:515-526` (repair). Restore gap: `core/runtime/FlowRuntime.gd:105-112`. | Repo-wide grep finds no write to `save["flow"]["state"]` outside `make_new_save` and the repair branch; `save.flow.context` is likewise `{}` forever. Separately, `boot()` restores `flow_ctx.realm_id` from the first realm with `status == "active"` and comments "survives Continue", but never restores `flow_ctx.stage_id` — nothing needed it, because before Phase 8B a run in progress could not be resumed. | The dead field: n/a. The `stage_id` gap: **yes** — any resumed run. | The `stage_id` gap would have been player-visible the moment resume existed: the victory card's `cta.next_stage` dispatches `flow.complete_stage`, and both `StageSettlementService` and `RealmService.advance_stage` locate the stage through `flow_ctx.stage_id`. With it empty the settlement returns `{}` and a completed stage pays nothing. | Phase 8B works around the `stage_id` half locally, in `PendingResultService.restore_run_context()`, filling only EMPTY fields from the durable result — deliberately NOT a change to `boot()`, since boot has no pending result to read and widening it would touch every save-integrity boot path. `save.flow.state` itself is untouched: writing it for the first time changes save contents for no consumer. Decide later whether to make it the real resume pointer or delete it. | `—` for what Phase 8B did. Writing `save.flow.state` would move save contents (though not the `FlowFingerprintTests` SAVE fingerprint, which reads only `economy` + party). |

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
