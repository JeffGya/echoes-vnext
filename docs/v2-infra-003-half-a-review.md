# V2-INFRA-003 — Half A Architecture Review Gate

**Verdict: APPROVED WITH CORRECTIONS** (7 corrections, listed in §9). See §7 for the
`CombatController` judgement and §10 for the single most important change.

Reviewer: independent read-only architecture gate.
Worktree: `.claude/worktrees/v2-infra-003-proof-spine-b3c770`.
Method: every claim below was re-derived from the code. The test suite was **not** run
(another process may hold the shared save directory); test facts come from test source.
Anything I could not confirm is marked **UNVERIFIED**.

Scope of the gate: Half A only — *"give every action exactly one owner and reduce
`FlowRuntime` to a composition and transaction shell."*

---

## 1. Inventory — verified

| Claim (handoff) | Verified? | Evidence |
|---|---|---|
| `FlowRuntime.gd` = 2,070 lines | ✅ | `wc -l` |
| 51 functions | ✅ | 51 `func` declarations, no nested/lambda funcs |
| 9 controllers | ✅ | `core/runtime/controllers/` — Weave, Vow, Debug, Progression, EconomySettlement, Sanctum, Onboarding, Contact, Venture |
| 5 builders | ✅ | Sanctum, StageExplore, Resolve, VentureResolve, Encounter `*SnapshotBuilder` |
| 26 services | ✅ (reconciled) | **24 new service files**, plus two existing services extended (`InstitutionService` institution tick, `KeeperIntroService` trial helpers). The table in the handoff mixes new files and extensions; the total is right, the wording is not. |
| `FlowEncounterState.gd` = 446 | ✅ | `wc -l` |
| `FlowStateMachine.gd` = 168 | ✅ | `wc -l` (handoff says `_rebuild_snapshot` 166→39; whole-file 168 is consistent) |
| Test suite 1,482 | ⚠️ **UNVERIFIED by run.** 1,483 `register_test` call sites counted statically across `tests/*.gd` — consistent with the claim, off by one, likely a conditionally-registered case. Nobody in this gate has run a cold suite. |
| Reflection call sites into `FlowRuntime` privates = 3 | ❌ **WRONG — it is 6.** See §5.3. |
| Nothing committed | ✅ | `git log main..HEAD` is empty; 61 modified + 41 untracked non-`.uid` files in the working tree |

---

## 2. Is `FlowRuntime` genuinely a shell?

**Mostly yes.** 51 functions classify as follows.

### 2.1 Composition — 26 functions, ~120 lines
`_init`, `_handle_new_game`, and **24 per-call factories** (`_weave_controller`,
`_vow_controller`, `_debug_controller`, `_progression_controller`,
`_economy_settlement_controller`, `_sanctum_controller`, `_contact_controller`,
`_venture_controller`, `_onboarding_controller`, `_vow_consequence_service`,
`_voice_service`, `_emotion_consequence_service`, `_combat_round_emotion_service`,
`_combat_round_spawn_service`, `_combat_round_guide_spirit_service`,
`_combat_round_objective_service`, `_combat_round_shrine_service`,
`_combat_turn_context_service`, `_combat_turn_action_service`,
`_contribution_ledger_service`, `_bond_consequence_service`,
`_recruitment_consequence_service`, `_stage_explore_session_service`,
`_live_movement_context_service`).

Every one is a genuine `return X.new(...)`. **No delegating stub was found anywhere in
`FlowRuntime`** (§3.1). `_handle_new_game` (43 lines) is save minting plus service rebuild —
composition, correctly placed.

### 2.2 Transaction — 10 functions, ~640 lines
`dispatch` (501), `boot` (101), `_next_tick`, `_apply_action_outcome`, `_mark_save_requested`,
`_log_snapshot_emitted`, `get_save_data`, `get_tick`, `_build_config_error_snapshot`,
`_build_save_error_snapshot`, `_ensure_encounter_started`.

`dispatch` is a 501-line match with 73 arms, 67 of which are a single
`_apply_action_outcome(_x_controller().handle_y(action, t), t)` line plus comment. The tail is
exactly one save-flush choke point and three gated one-shot consumptions. This is the shape the
story set out to produce and it holds.

### 2.3 Residual domain logic — 15 functions, ~800 lines

This is the third category the brief asked me to name.

| Function(s) | Lines | Domain | Blocker? |
|---|---:|---|---|
| **`_apply_offline_accrual_if_needed` + `_build_offline_retention_context` + `_build_offline_return_notification`** | **~294** | **Economy / retention** | **NONE.** See §2.4 — this is the headline residual. |
| `_resolve_next_actor`, `_end_round`, `_handle_combat_init`, `_handle_combat_confirm_round`, `_handle_combat_next_actor`, `_handle_encounter_retreat`, `_find_next_living_actor_idx` | ~447 | Combat / encounter | Deliberate (§7) |
| `_apply_victory_return_to_explore` | 46 | Combat teardown orchestration | Real — reads `flow_machine._current_state_id`; body is 8 service calls, correctly composed |
| `_gate_state_for_keeper_intro` | 23 | Onboarding gating | Runs before a transition, inside `flow.go_state`; defensible as transaction-adjacent |
| `_generate_seed_root_string` | 6 | Campaign seed minting | **None.** See §2.5 |
| `_get_actor_cfg_merged` + `_actor_cfg_merged_cache` | 10 | Config memo | Real, and correctly argued — see §3.5 |

### 2.4 The offline-accrual block is the clearest failure of the shell goal

`core/runtime/FlowRuntime.gd:1528-1821`, 294 lines — 14% of the whole remaining file. It:

- gates on `sanctum.ase_flame.awakened`,
- computes elapsed-time deltas and a "time went backwards" anomaly path,
- derives a retention multiplier from `sanctum.continuity` and per-Echo morale/fear
  (`_build_offline_retention_context`),
- applies its own dynamic cap,
- and **writes player-facing prose** — `"The Flame Held"`, `"The Flame Guttered"`,
  `"The Flame Faltered"`, `"A little charge remained in your absence."` — in
  `_build_offline_return_notification`.

It holds no `flow_machine`. It calls no controller. It has **exactly one production caller**,
the `flow.continue` case at `:248`. A sibling service already exists —
`core/economy/EconomySettlementService.gd` — and that file's own header refers to this function
twice (`:55`, `:198`) as *"an unrelated, still-on-FlowRuntime function"*, i.e. the extraction
was seen and skipped.

There is **no structural blocker**. Every one of the twelve reasons this story recorded for
leaving something on `FlowRuntime` (needs `flow_machine`; no outcome in flight; per-call
lifetime; controller-to-controller) applies to none of it. It is the single largest block of
domain logic in a file whose stated end state is "composition and transaction shell", and
narrative copy for a modal is the least shell-like thing in the file.

Correction C1 (§9).

### 2.5 `_generate_seed_root_string` contradicts a decision this story already took

`FlowRuntime.gd:1507-1512` mints the campaign seed string from `Crypto.generate_random_bytes`.
Its immediate partner, `_legacy_root_seed_from_seed_root`, **was moved** in Phase 4 Slice 6a to
`CampaignSeed.legacy_root_seed_from_seed_root()` with this written reason
(`core/CampaignSeed.gd:62-66`):

> *"on the class that already owns every other 'derive a seed value from a seed string'
> concern"*

The two functions are called on consecutive lines (`:719-720`). Half the pair moved on a rule
that applies equally to the other half. Minor, but it is inconsistency inside one slice.
Correction C2.

---

## 3. The Phase 7 checks — verified, not asserted

### 3.1 Migrated helpers removed, no delegating stubs — ✅ CLEAN
No function in `FlowRuntime.gd` forwards to a moved implementation. The 24 factories are
constructors, not forwarders (`_live_movement_context_service` even says so in its docstring,
and I confirmed all 27 moved movement functions live only on the service). `_mark_save_requested`
forwards to `flow_ctx.request_save()` but that is the documented shared choke point, not a
relocated body.

`FlowEncounterState.gd` no longer declares `build_snapshot`; `_derive_status` moved to
`EncounterSnapshotBuilder` with all call sites repointed (`git diff` confirms the old
`FlowEncounterState._derive_status(...)` call sites became `EncounterSnapshotBuilder._derive_status(...)`).

### 3.2 Duplicate completion paths — ✅ CLEAN, with one pre-existing note
Exactly one `SaveService.save_to_file` inside `dispatch()` (`:568`), guarded by
`flow_ctx.save_request`, with a documented retry-on-failure. The only other
`SaveService.save_to_file` in the whole of `core/` outside `core/save/` is at `:70`, inside
`boot()`, minting a brand-new save — a different lifecycle. **No controller and no service
calls `SaveService` at all** (grep across `core/`, `ui/`: zero code hits). One flush per
dispatch is structurally enforced.

The **repeated reward** stop condition does fire — but on a pre-existing defect, not one this
work introduced. Defect **D77**: the full stage reward is paid unconditionally at every
encounter resolution, and defeat pays a 25% consolation with the situation left unresolved.
Confirmed in the register with file:line evidence, product-owner decision taken, and scheduled
for the after-Phase-9 bundle **inside this story**. Not a merge blocker for Half A; is a merge
blocker for the PR (§9, C7).

### 3.3 The action count — ✅ 73, verified independently

A naive extraction of `^\t{3}"` inside `dispatch()` returns **76** rows. Three are not cases:
`"blocked_action"` (a logger payload key at `:179`), and `"ok"` / `"reason"` (the return dict
at `:576-577`). **73 real cases.** (The earlier agent's "75 rows, two non-cases" was itself
slightly off; the correct numbers are 76 and 3.)

I mapped each case to the line that handles it. Owner counts:

| Owner | Count | Matches handoff? |
|---|---:|---|
| `VentureController` | 11 | ✅ |
| `OnboardingController` | 12 | ✅ |
| `SanctumController` | 11 | ✅ |
| `DebugController` | 7 | ✅ (`debug.vow.unlock` is `VowController`'s, not Debug's — the split is correct) |
| `WeaveController` | 6 | ✅ |
| `ProgressionController` | 5 | ✅ |
| `EconomySettlementController` | 3 | ✅ |
| `ContactController` | 3 | ✅ |
| `VowController` | 3 | ✅ |
| `FlowRuntime` | 12 | ✅ (6 `flow.*` session + 6 combat/encounter) |
| **Total** | **73** | ✅ |

**Zero duplicate case labels. Zero actions with two owners. Zero actions with no owner.** The
handoff's headline claim survives an independent count exactly. This is the strongest single
result in the change.

### 3.4 Exactly one dispatch closure — ✅
`grep 'func dispatch' core/ ui/` returns exactly one definition, `FlowRuntime.gd:170`.

### 3.5 No controller calls another controller — ✅ CLEAN
`grep 'Controller'` inside `core/runtime/controllers/*.gd` returns **only comment lines**. No
`_x_controller()` call, no `XController.new`, no `XController.` member access anywhere in
controller code.

Stronger: **no controller or service holds `flow_machine` in code.** I grepped every `core/`
file outside `FlowRuntime.gd` and `core/state/flow/Flow*` for a non-comment `flow_machine`
reference and got zero hits across all 9 controllers and all 24 new services. The "structurally
cannot transition" claim is real, not aspirational.

`_get_actor_cfg_merged`'s lifetime argument also checks out: controllers are constructed
per-call (`return WeaveController.new(...)`), so a controller-owned memo would be rebuilt on
every actor turn. The instance-member decision is correct.

---

## 4. Stop conditions — walked one at a time

| Stop condition | Result |
|---|---|
| Zero or two owners for an action | ✅ **Clean.** 73/73 with exactly one owner (§3.3) |
| A controller calling another controller | ✅ **Clean** (§3.5) |
| A builder mutating state | ❌ **FIRES.** `FlowEncounterState.build_final_snapshot()` — see §5.1 |
| Two flushes in one dispatch | ✅ **Clean** (§3.2) |
| Repeated reward / settlement / Thread / stage advance | ⚠️ **Pre-existing (D36/D77), verified and scheduled in-story.** Not introduced here |
| Unapproved fingerprint change | ✅ No evidence of one. All recorded fingerprint movements are deferred, not taken. **UNVERIFIED at runtime** — I did not run the fingerprint suites |
| RNG namespace or draw-order change | ✅ **Clean.** `git diff` shows every seed-path string moving with its code, never being edited. `CampaignSeed.gd` gained one function and changed none. `encounter.retreat.<id>.<t>` is unchanged, including the known missing-dot fallback |
| Removed or renamed snapshot or save field | ✅ **Clean.** `SaveSchema.gd` diff is purely additive (`flow.pending_result`, `onboarding.opening_realm_id`, `opening_realm_status`). `SaveService.gd` deletions are the ~60 lines of legacy V1→V2 migrations Jeff explicitly approved removing |
| **Any config VALUE change** | ✅ **Clean, verified.** `git diff -- data/` is **empty** and `git status -- data/` shows no untracked file. Not one tuning value moved |
| New file over ~1,000 lines without written justification | ⚠️ **Marginal — one file.** See §6 |
| Test baseline regressing | ⚠️ **UNVERIFIED.** No suite was run in this gate |

---

## 5. Half-decomposition — where it exists

### 5.1 Producer A: a reward-paying "snapshot builder" survives Half A

This is the most important structural finding after the action count.

The handoff's own statement of the problem Half A exists to fix (§1):

> *"Snapshot builders paid rewards and wrote to disk."*

`core/state/flow/states/venture/FlowEncounterState.gd:37` `build_final_snapshot()` still:

- mutates actor emotion state (the temporary-ally death knock, `:52-85`),
- computes and **pays** the stage reward — `EconomyService.reward_stage_complete` (`:203`),
- **awards Storyweight** — `ProgressionService.award_post_combat_xp` (`:264`),
- writes final combat emotion back onto the roster,
- and requests **two** saves — `request_save("stage.reward")` (`:220`) and
  `request_save("progression.xp")`,

...all inside a `static func build_*`. It is ~380 of that file's remaining 446 lines, and it is
called from `_end_round` (`FlowRuntime.gd:1482`).

So `flow.resolve` today has **six producers with two different architectures**: four compose
purely through `ResolveSnapshotBuilder`'s block library; producer B
(`EncounterSnapshotBuilder:564`) is pure and emits `ase_awarded: 40` as a *display* value while
the money lands in a later dispatch; producer A pays, mutates and flushes.

**Why I am not rejecting on this.** Slice 6J did migrate producer A's *payload composition*
into the block library (`:409-441`) and left the impure prefix behind **deliberately, with the
reason written at the site** (`:397-405`) and a full evidence trail in the register (D36, D77,
D76). The deferral is (a) inside this same story, not filed to another one; (b) sequenced for a
real reason — the fix zeroes `ase_awarded`/`ekwan_awarded` and moves all seven combat
fingerprints, so it must land as one attributable baseline re-record with D01/D04/D18/D19/D35/D50;
and (c) pre-cut — 6J split the file along exactly the seam the later move needs, so the
relocation into `EncounterSnapshotBuilder` is a cut-and-paste.

That is a scheduled deferral, not a half-decomposition left to rot. But it means **Half A's own
charter is not satisfied at this gate**, and the gate must say so rather than wave it through.
Correction C7.

Stale text to fix while there: `tests/FlowSnapshotFingerprintTests.gd:339` still says
*"KNOWN DEFECT — Phase 3 inverts this assertion to 'must not mutate'."* Phase 3 did not, and
the register (D76) has since revised the plan to "invert the assertion, keep the production
drive". The test's docstring now points at a plan that no longer exists.

### 5.2 A stale controller header asserts an architecture that was disproved

`core/runtime/controllers/ContactController.gd:28-42` states:

> *"`_start_contact_conversation` STAYS ON FlowRuntime. Two independent blockers … it cannot
> become a service either, because services take no `flow_machine`."*

That function no longer exists on `FlowRuntime`. Slice 5D moved it wholesale into
`core/realms/ContactConversationService.gd` — a service — after finding its only `flow_machine`
use was a trailing publish the controller now returns as an outcome. The correction is recorded
in `FlowRuntime.gd:1997`, in `VentureController.gd:53-60`, and in the service's own header —
but **not** in the file that makes the false claim. `core/realms/ContactResponseService.gd:8`
repeats the stale claim a second time.

`VentureController.gd` shows the right way to do this: its Slice-D "flow.select_stage stays on
FlowRuntime" note is immediately followed by a "SLICE 6F RESOLVED IT" paragraph. Contact never
got that paragraph. In a codebase where the file header *is* the architectural documentation,
two of the nine controllers/services now describe a structure that does not exist, and one of
them states a general rule ("services take no `flow_machine`, therefore X cannot be a service")
that this story proved wrong. Correction C3.

### 5.3 A test still reaches into a `FlowRuntime` private by name — and the count is wrong

The handoff's metric table claims reflection call sites into `FlowRuntime` privates went
**50 → 3**. The real number is **6**:

- `tests/EconomyTests.gd:70, 94, 95, 114, 134` — five `runtime.call("_apply_offline_accrual_if_needed", …)`
- `tests/Stage004SeamTests.gd:1148` — `runtime._apply_victory_return_to_explore(t)` (a direct
  private access, not `.call()`, so a name-based grep for `.call("_` misses it)

The `Stage004SeamTests` one is legitimate and the handoff argues it correctly: the function
still does real un-extracted work. The five `EconomyTests` ones are the reflection anti-pattern
`AGENTS.md` mistake 20 names — and they exist **because** the offline block never moved (§2.4).
Extracting it to `EconomySettlementService` deletes the residual logic and the five reflection
sites in one change. Correction C1 covers both.

### 5.4 A file that kept its name after losing its behaviour

`core/realms/StageExploreSessionService.gd` was 1,461 lines; slice 5E cut `advance_turn` out to
`StageExploreTurnService` and `engage_situation`/`resolve_situation_choice` out to
`SituationEngagementService`. What remains at 527 lines is:

`stage_integer_cell`, `explore_walkable`, `lift_fog_at_cell`, `situation_blocks_step`,
`stage_party_heading`, `stage_reachable_costs`, `count_revealed_situations`,
`get_stage_base_reward`, `stage_movement_salt`, `find_explore_target`,
`mark_stage_objective_completed`, `resolve_combat_situation_and_objective`.

That is grid/fog geometry + a rewards reader + two objective-resolution methods. It is the
closest thing in the change to a **bag of unrelated functions**, and the name "Session" now
describes nothing it does — the session behaviour left in 5E. `get_stage_base_reward` in
particular is a rewards concern sitting beside fog-lifting, and it is read from
`_handle_encounter_retreat` for an intel payout. Not a merge blocker; it is the one boundary I
would revisit. Correction C4.

### 5.5 Everything else in this section is clean
No service reaches back into `FlowRuntime` (one comment-only hit in `FlowContext.gd:53`, none
in code). No domain is split across two owners without a written rule. No function was found
left behind for a reason that has since evaporated, other than §5.2's documentation of one.

---

## 6. `LiveMovementContextService.gd` — 1,018 lines

Judged as the brief asked.

The header is genuinely good — better than most files in this repo. It carries: an ASCII
diagram of the adapter position; a "WHY HERE, IN `core/movement/`" section reasoning from what
the neighbouring pure services say about themselves; the full contract (no `flow_machine`, no
`SaveService`, no controller, stateless); a line-by-line READS/WRITES/NOT-TOUCHED set; a
determinism section naming the two preserved ordering guards; a naming rule; an explicit
"NO SHIM WAS LEFT" statement with the call-site count; and a recorded known gap.

But it **never mentions its size**, and it never says *"this file exceeds the ~1,000-line guard
because V2-COMBAT-003 owns this behaviour and splitting it was forbidden."* The stop condition
is worded "*without written justification*" — of the size, not of the file's existence. A
reviewer arriving at 1,018 lines with no acknowledgement cannot tell whether the guard was
weighed or missed.

**Judgement: the verbatim-move-because-another-story-owns-it reason IS a sufficient
justification, and it is not written down.** This is a three-line fix, not a re-architecture.
I am not treating it as a blocker — the substance is right and the reasoning exists elsewhere
in the handoff — but the sentence must be added before merge so the next reader does not have
to reconstruct it. Correction C5.

(Note: `AGENTS.md` carries no line-count rule at all. If the ~1,000-line guard is meant to
outlive this story, it belongs there.)

---

## 7. The deliberate omission — no `CombatController`

**Judgement: defensible as an end state for Half A, but the file does not say so, and the
"irreducible residue" argument is over-stated.**

### Arguing it from the code — for

1. **The ownership rule is not violated.** The stop condition is "zero or two owners". These
   six actions have exactly one owner, `FlowRuntime`, and it is a named, real, single owner.
   Half A's goal is *one owner per action*, not *one controller per domain*.
2. **The bodies genuinely left.** `_end_round` is now 143 lines of which ~70 are code, and that
   code is: build a `remaining_actors` log list, call six services in fixed order, run
   `CombatState.check_end_condition`, write `combat_result`, reset five `combat_state` keys,
   publish a snapshot. `_resolve_next_actor` is 129 lines that read config, call
   `CombatTurnContextService`, `LiveMovementContextService`, `CombatTurnActionService`,
   `ContributionLedgerService` and `CombatRoundObjectiveService`, and publish. There is no
   un-extracted combat logic of any size left in `FlowRuntime`. The decomposition happened; only
   the *routing* did not move.
3. **Two of the three blockers are real and I verified them.** `_resolve_next_actor:1305-1307`
   transitions to `KEEPER_REWIND` from inside a per-actor turn and returns bare — there is no
   `FlowActionOutcome` in flight to carry it. And `_actor_cfg_merged_cache` is an instance memo
   whose correct lifetime is one campaign, while every controller in this codebase is
   constructed per call; a per-call `CombatController` would rebuild it ~240 times per
   encounter, re-introducing exactly the cost the memo exists to remove.
4. **It is not silently deferred.** It is a written decision, filed as a full handoff section on
   the V2-COMBAT-004 Notion page, which also corrects that story's own instruction to wire
   `ProtectCustodyService` through a controller that does not exist.

### Arguing it from the code — against

1. **The six actions are not homogeneous, and the argument treats them as one block.** Three
   (`combat.confirm_round`, `combat.next_actor`, `encounter.advance`) are genuinely bound to the
   turn loop and its mid-body transition. Three are not:
   - `encounter.retreat` (`:1034-1104`) spends Ase, rolls a seeded RNG, pays an intel-gated
     partial reward, clears the encounter, calls four services, assigns `last_snapshot` and
     transitions to RESOLVE. That maps onto `FlowActionOutcome.snapshot_outcome()` +
     `transition_to` with no residue — the exact translation `ContactController`'s header
     tabulates. Its only awkward branch calls `_handle_combat_init`.
   - `combat.init` (`:1105-1142`) starts the encounter machine, logs, requests a save and
     publishes — `snapshot_outcome()` plus a save reason.
   - `encounter.complete` is already two service calls and a transition.

   So the residue is not irreducible; it is *three* turn-loop actions plus three ordinary
   handlers that were kept with them for cohesion. That is a defensible grouping, but it should
   be argued as cohesion, not as impossibility.
2. **Blocker 1 is a design choice this story has already overturned three times.** The
   KEEPER_REWIND mid-body transition is "no outcome in flight" — which is precisely the shape
   that produced `requires_reenter`, `suppress_refresh` and `requires_refresh`, each added to
   `FlowActionOutcome` when a real call site appeared. A fourth field, or a returned sentinel
   the caller acts on, would carry it. Also worth noting on its own merits: a *keeper-intro*
   transition fires from inside the combat turn loop, which is a cross-domain reach the
   architecture would normally reject.
3. **Blocker 3 has a one-line fix the story identified and declined on scope**
   (memoise on `ConfigService`), described in the handoff as "behaviour-adjacent and therefore
   not taken". That is a scope decision, not a structural bar.

### Why this is not the half-decomposition the rule forbids

Half-decomposition means *ambiguous or split ownership* — a domain with two owners and no rule,
or a body sitting in a state that no longer matches its name. Neither is true here. Ownership is
singular, complete, counted and documented. What is missing is a *symmetry*, not an *owner*.

### But the code must say it

`FlowRuntime.gd` contains **no ownership statement for the combat block at all.**
`grep 'CombatController\|COMBAT-004'` over the whole file returns one incidental
`# COMBAT-004:` comment at `:357` that refers to the old story prefix, not the decision. A
reader who opens `dispatch()` sees 67 arms routed to controllers and 6 handled inline, with
nothing to distinguish "deliberately owned here" from "not finished yet". The decision lives
only in a handoff document that Phase 11 will archive and on a Notion page.

**That is the correction.** Not building `CombatController` is defensible. Leaving the file
looking half-finished is not. Correction C6 — the highest-value single item in this review.

---

## 8. Boundaries — the questions only a review can answer

**Is any service a bag of unrelated functions?** One candidate: `StageExploreSessionService`
(§5.4). `NarrativeVoiceService` (13 methods: spirit barks, ally barks, travel beats, Anansi
snippets, Sanctum barks, arrival barks) is broad but coherently "every narrative voice line",
and it sits beside `ShoutBank` per the `AGENTS.md` placement rule. Fine.

**Did any extraction create worse coupling than it removed?** No. The strongest evidence: zero
non-comment `flow_machine`, `SaveService` or `FlowRuntime` references across all 33 new
controller/service files. The dependency graph points strictly one way.

**Two services that should be one, or one that should be two?**
`CombatRoundShrineService` (the phase) sitting beside `ShrineService` (the arithmetic) reads
odd at first, but the reasoning is right and is written down: `ShrineService`'s own first rule is
"pure static functions only, no side effects, no logging", and the drain phase breaks all three.
Folding it in would have meant rewriting that sentence to accommodate a caller. Same for
`LiveHazardOutcomeService` beside `LiveMovementContextService`. I would not merge any pair.

**Does any name lie?** Three, all minor:
- `CombatRoundObjectiveService` now holds `apply_pursue_quarry_escape` at `:353`, called from
  `_resolve_next_actor` (per **turn**), not `_end_round` (per **round**). The *method*
  docstring (`:332-346`) is honest about this; the *class* header (`:2-5`) still says "the three
  PROTECT / PURSUE objective-progress phases, extracted verbatim out of `_end_round`" — now
  false on both the count and the source. Fix the header, keep the name: a turn is inside a
  round, and the alternative (a fifth combat service for one 25-line method) is worse.
- `StageExploreSessionService` — §5.4.
- `ResolveSnapshotBuilder` (a 17-block *library*) and `VentureResolveSnapshotBuilder` (a
  *producer*) are two adjacent files with near-identical names and completely different roles.
  Both headers explain the distinction at length, which is itself the tell that the names do not.
  Not worth renaming now; worth knowing.

**Did the controller/service/builder distinction drift across six phases?** No — and this
surprised me. The contract paragraph is reproduced near-verbatim at the top of all nine
controllers, and the "services exist because controllers may not call each other" rule is
applied consistently across all six phases (Vow, emotion/bond, keeper intro, contact
conversation, skill loadout). The one recurring inconsistency is that **headers were not
maintained when a later slice overturned them** — `VentureController` corrects itself,
`ContactController` and `ContactResponseService` do not (§5.2). The rules held; the record of
the rules did not, in two places out of thirty-three.

---

## 9. Corrections required before merge

| # | Location | Fix |
|---|---|---|
| **C1** | `core/runtime/FlowRuntime.gd:1528-1821` | Extract `_apply_offline_accrual_if_needed`, `_build_offline_retention_context` and `_build_offline_return_notification` (294 lines) into `core/economy/EconomySettlementService.gd` or a sibling `OfflineAccrualService` beside it. No blocker exists: no `flow_machine`, one caller, and the destination service's header already names the function. Repoint `tests/EconomyTests.gd:70/94/95/114/134` to the service in the same change — that also deletes five of the six remaining reflection call sites into `FlowRuntime` privates. Update the handoff's "50 → 3" metric to the true number. |
| **C2** | `core/runtime/FlowRuntime.gd:1507-1512` | Move `_generate_seed_root_string()` to `CampaignSeed`, beside `legacy_root_seed_from_seed_root()` which was moved in Phase 4 Slice 6a on exactly this reasoning. The two are called on consecutive lines at `:719-720`. Or, if it stays, write the reason it stays. |
| **C3** | `core/runtime/controllers/ContactController.gd:28-42` and `core/realms/ContactResponseService.gd:8` | Both state `_start_contact_conversation` "STAYS ON FlowRuntime" and that it "cannot become a service, because services take no `flow_machine`". Slice 5D disproved both. Add a "SLICE 5D RESOLVED IT" paragraph in the style `VentureController.gd:37-42` already uses, naming `core/realms/ContactConversationService.gd` as the owner. |
| **C4** | `core/realms/StageExploreSessionService.gd` | After slice 5E removed the session behaviour, the name describes nothing the file does and the remaining 12 methods span grid geometry, fog, a rewards reader and objective resolution. Either rename (`StageExploreQueryService`) or add a header paragraph stating what the residual remit now is and why `get_stage_base_reward` belongs with `lift_fog_at_cell`. |
| **C5** | `core/movement/LiveMovementContextService.gd`, header | Add an explicit size justification: this file is 1,018 lines and exceeds the ~1,000-line guard because V2-COMBAT-003 owns the behaviour and the 27 functions had to move verbatim, so splitting was forbidden. If the guard is meant to outlive this story, add it to `AGENTS.md`. |
| **C6** | `core/runtime/FlowRuntime.gd`, above the `combat.*` / `encounter.*` arms in `dispatch()` | **The most important correction.** Add an ownership block stating that `FlowRuntime` is the deliberate owner of these six actions; that this is a decision, not an unfinished state; the three verified blockers (mid-body `KEEPER_REWIND` transition with no outcome in flight; `_resolve_next_actor` ↔ `_end_round` pairing forcing both to move together; `_actor_cfg_merged_cache`'s lifetime vs per-call controller construction); the honest note that `encounter.retreat`, `combat.init` and `encounter.complete` are grouped here for cohesion rather than blocked; and the pointer to V2-COMBAT-004. Nothing in the file says any of this today. |
| **C7** | `core/state/flow/states/venture/FlowEncounterState.gd:37` (`build_final_snapshot`) | Not fixable at this gate — the D36/D77 relocation must land as one attributable change with D01/D04/D18/D19/D35/D50 after Phase 9. **Required: it must land before the PR, not be filed onward.** Half A's charter names reward-paying snapshot builders as the problem, and producer A is still one. Also fix `tests/FlowSnapshotFingerprintTests.gd:339`, whose docstring still promises a Phase 3 inversion the register (D76) has since replaced. |

C1–C6 are small and can land now. C7 is the scheduled bundle.

---

## 10. Answers to the brief

**Verdict:** APPROVED WITH CORRECTIONS.

**On the missing `CombatController`:** defensible. The ownership rule Half A set is met — 73
actions, 73 single owners, `FlowRuntime` among them by decision. The bodies genuinely left; what
remains in `_resolve_next_actor` and `_end_round` is service orchestration and snapshot
publication, and two of the three blockers (the mid-body KEEPER_REWIND transition, the memo
lifetime) I verified in the code. But the "irreducible residue" framing is over-stated —
`encounter.retreat`, `combat.init` and `encounter.complete` have no turn-loop coupling and would
translate cleanly to outcomes today. The right defence is cohesion, not impossibility. **The
failure is that none of this is in the file.** A reader of `dispatch()` sees 67 routed arms and
6 inline ones with nothing to distinguish decision from debt.

**What I could not verify:**
- The 1,482 test baseline and that the suite passes — no run was permitted. 1,483
  `register_test` call sites counted statically.
- That no fingerprint drifted. No fingerprint suite was executed. Nothing in the diff *looks*
  like a fingerprint change and every recorded movement is deferred rather than taken, but this
  is inference, not evidence.
- The claim that `FlowRuntime` started at 10,061 lines, and every intermediate per-slice line
  count. Nothing is committed, so there is no history to check them against.
- Whether Notion actually carries the V2-COMBAT-004 handoff section (no Notion access in this
  gate).

**The single thing I would most want changed before this merges:** C6 — the combat ownership
block in `FlowRuntime.gd`. Every other correction is a line count or a stale sentence. This one
decides how the next engineer reads the whole file. A deliberate decision that is invisible in
the code is indistinguishable from unfinished work, and the story's own rule is that a
half-decomposed architecture must not merge. Right now nothing in `FlowRuntime.gd` proves this
one is not.

---

## Appendix — sections that are clean

Stated plainly, because a clean section is a result:

- **Action ownership** (§3.3) — 73 actions, one owner each, independently counted. No
  duplicates, no orphans. The headline claim survives.
- **Delegating stubs** (§3.1) — none. Every migrated helper is gone from its old home.
- **Controller isolation** (§3.5) — no controller calls another; none holds `flow_machine`,
  `SaveService` or a `FlowRuntime` reference in code.
- **Save transaction** (§3.2) — exactly one flush site, exactly one `dispatch`.
- **Config values** (§4) — `git diff -- data/` is empty. Not one tuning value changed.
- **RNG** (§4) — no namespace string edited, no draw order altered.
- **Save schema** (§4) — additive only; the deletions are the approved legacy migrations.
- **Builder purity** — the four pure builders write only to locally-constructed payload dicts;
  none calls `request_save`; none writes `save_data`. `ResolveSnapshotBuilder` takes no
  `FlowContext` at all. The one exception is producer A (§5.1).
- **Coupling direction** (§8) — strictly one way, across all 33 new files.
