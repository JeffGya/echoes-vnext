# V2-COMBAT-002 Slice 6: Custody Cutover — APPROVED STORY

## Subject

Replace the inline proximity+RNG totem-theft roll in `CombatRoundObjectiveService.apply_protect_theft_round()`
with the existing, dormant `ProtectCustodyService` (attack-triggered theft), and make PROTECT-mode AI
correctly act on the new rule — one subject: the custody cutover, nothing else.

## Why now

V2-COMBAT-004 depends on PROTECT-mode custody being final. `ProtectCustodyService` (Slice 4) was built
and tested in isolation but never wired in (Slices 5-6 never shipped). This is that missing Slice 6.

## Subtask 1: Confirm contracts

- **Hook point (CONFIRMED):** `core/combat/CombatTurnActionService.gd:154`, inside the `"melee_attack"`
  branch of the action-resolution match block, immediately after
  `var result: Dictionary = CombatService.resolve_action("melee_attack", actor, target, round)` and
  before `result` is appended to `ectx.last_round_results` (line 162).
- `ProtectCustodyService.resolve_theft_on_attack(custody_state, attack, protect_cfg)` expects an `attack`
  dict with: `defender_id`, `hit` (bool), `roll` (float), `attacker_faction`, `attacker_id`,
  `attacker_cell`. `CombatService.resolve_action()`'s `result` dict does **not** carry `hit`, `roll`,
  `attacker_faction`, or `attacker_cell` — these must be assembled at the call site from `result`,
  `actor`, and `target`, not read off `result` directly.
- **RNG draw:** the theft roll must move from the old inline roll (whatever seed key
  `CombatRoundObjectiveService.apply_protect_theft_round()` currently uses) to a draw taken at the new
  attack-triggered hook, keyed `combat.theft.<encounter_id>.<round>` per the existing convention. Per
  the determinism rule, this is a **new** draw at a new point in the sequence — do not attempt to reuse
  the old round-end draw's position or value. **Add a stable per-attempt discriminator to the path**
  (for example the attacker id and an attempt index). `CampaignSeed.get_rng()` builds a fresh generator
  from the path alone (`core/CampaignSeed.gd:52-57`), so two attempts with the same path get the same
  first `randf()`. One failed roll would then fail every later attempt in that round.
- **OPEN DESIGN QUESTION (Jeff decides before Subtask 2 starts): double-damage direction.**
  `_resolve_melee()` (`CombatService.gd:66-77`) doubles the damage the carrier DEALS
  (`attacker["_carrier_double_damage"]`). `ProtectCustodyService.enemy_carrier_restrictions()` returns
  `takes_double_damage` (the carrier TAKES double), and `CONVENTIONS.md:823` says the enemy carrier
  "takes double damage". The two contracts disagree. Settle one direction, then wire it in one place.

## Subtask 2: Mechanical cutover

- In `CombatTurnActionService.gd`, at the confirmed hook point, assemble the `attack` dict from `result`,
  `actor`, and `target`, and call `ProtectCustodyService.resolve_theft_on_attack()` when the encounter is
  PROTECT mode and a totem is in custody.
- **Own the custody state.** Every service call returns a new immutable `custody_state`. Production has
  no owner for it. `totem_stolen` and `totem_carrier_id` cannot hold an Echo carrier, a moving
  `totem_cell`, or the carrier faction. Define where `custody_state` lives, how it is created at
  encounter start, how it persists between activations, and how it syncs to the legacy
  `totem_stolen` / `totem_carrier_id` fields that pressure and snapshots still read.
- **Pickup needs a producer.** Nothing in production can select `protect.totem_pickup` today.
  `pickup_action_plan()` is used only by tests, `CombatPressureService._primary_plan()` has no pickup
  case, and `MovementGoal._validate_plan_for_purpose()` rejects it for every purpose. Scope the
  pressure facts, goal contract support, action context and arbitration path that emit this action.
- **Keep the authored carryability gate.** The totem is carryable only 60% of the time
  (`carryable_chance: 0.6`, `data/actors.json:132`; `docs/combat-modes.md:31-35`).
  `resolve_pickup()` has no such check. Add a deterministic encounter-time carryable flag and gate both
  pickup planning and pickup resolution on it.
- **Carrier burden is `apply_carrier_burden()`, not `track_carrier_movement()`.**
  `track_carrier_movement()` only moves `totem_cell` (`ProtectCustodyService.gd:319-342`). The
  capacity penalty and the enemy cap live in `apply_carrier_burden()` (`:162-222`). Add the
  movement-profile preparation hook that calls it.
- Also wire, at their natural call sites: `resolve_pickup`, `track_carrier_movement` (totem follows the
  carrier), `resolve_drop` (carrier down/KO) and `enemy_carrier_restrictions` (movement/action limits).
- Remove `CombatRoundObjectiveService.apply_protect_theft_round()` and its call from
  `FlowRuntime._end_round` (`core/runtime/FlowRuntime.gd:1579`) — the old proximity/RNG path is fully
  superseded, not left as a fallback.
- `resolve_cell_entry()` is an explicit no-op by design (adjacency/entry never transfers custody) — do
  not build logic around it; it exists so this cutover can't accidentally reintroduce the old rule.

## Subtask 3: Preserve the guard-block precondition (NEW — do not skip)

`ProtectCustodyService` has no concept of "guarded." Its `resolve_pickup()` and `resolve_theft_on_attack()`
let a pickup or theft attempt proceed as soon as range/state checks pass — there is no check for "is a
living echo currently guarding the totem." This is by design in the new service; its own docs say it does
no gating.

The CURRENT live rule, enforced today inside the `apply_protect_theft_round()` being removed, requires the
totem be UNGUARDED (no living echo adjacent) before a hostile actor can attempt theft or pickup. Jeff has
confirmed this rule must be preserved — it is not being redesigned as part of this cutover.

Because the new service does not implement this check, the cutover call site
(`CombatTurnActionService.gd`, at both the `resolve_pickup()` call and the `resolve_theft_on_attack()`
call for a hostile actor) must add an explicit "is any living echo adjacent to the totem?" check BEFORE
invoking either service function. Reuse the same adjacency check the old `apply_protect_theft_round()`
used — do not write a new one. If the check fails (an echo is guarding), skip the pickup/theft call
entirely for that attack.

This is its own subtask, not a detail folded into Subtask 2, because it is easy to drop silently: nothing
in `ProtectCustodyService`'s interface signals that gating is missing, so its absence would only surface
in playtest.

## Subtask 4: Arbitration correctness (CombatPressureService.gd)

**RESOLVED — confirmed contained, not an open risk.** The fix is entirely inside `_add_protect()`
(`core/movement/CombatPressureService.gd`, lines 263-294). Today, in the hostile pre-theft branch, line
293 calls `_add_objective_engage(...)`, which targets `pressure["objective_id"]` — the totem structure
actor — not the echo currently holding it. Under the old rule this was enough (adjacency alone triggered
the roll). Under the new attack-triggered rule it does nothing useful: the hostile arrives, engages the
structure, and never attacks the holding echo.

The fix: replace that `_add_objective_engage(...)` call with
`_add_actor_engage(candidates, BUCKET_TACTICAL, context, pressure, "breaker", NORMAL, <carrier id>)`,
mirroring the pattern already used at lines 273-287 for the post-theft carrier case, and already proven
correct for GUIDE_SPIRIT's escort-threat case via `_add_guide()` at line 364.

**Correction (code review):** `holder_id` does not work for PROTECT. `LiveMovementContextService.gd:821`
fills it only from `combat_state.recover_holder_id`, so in PROTECT it is empty or unrelated, and
`_add_actor_engage()` then emits no goal. Thread the real custody carrier into the pressure snapshot as
a new field and target that field. This adds a change in `LiveMovementContextService.gd`.

This change is confined to the hostile pre-theft branch inside `_add_protect()`. The shared helpers it
calls — `_add_actor_engage` (line 715), `_add_goal` (line 733), `_adjacent_region` (line 851),
`_actor_by_id` (line 882) — are called with new arguments only. Their own behavior is not modified, so no
other combat mode's goals change. No extra isolation subtask is required.

## Subtask 5: Test verification

- **Needs rewriting, not just re-running:** `tests/CombatRoundtripIntegrationTests.gd`,
  `test_protect_theft()` (lines ~1578-1690). This test currently sets up an enemy *adjacent* to the totem
  with no attack, drives one round, and asserts on the old `theft_chance=0.5` proximity-roll outcome. It
  must be rewritten to:
  1. Drive an actual melee attack against the carrier and assert the attack-triggered theft outcome.
  2. Guard gate, attack path: an otherwise-successful attack with a forced low roll against a carrier,
     while another living Echo guards the totem. Assert no theft. An adjacency-only case is not enough:
     it passes even with no guard check, because adjacency no longer triggers theft.
  3. Guard gate, pickup path: an enemy pickup action while an Echo guards the totem. Assert no pickup.
  4. Carrier death: the recovery half (lines ~1665-1689) is NOT trigger-agnostic. It marks the carrier
     dead by hand and waits for the old end-round function, which this story removes. Rewrite it to
     drive a real lethal attack or KO. Assert the immediate drop cell and the synced custody state.
- **NOT unaffected (corrected):** `tests/FlowFingerprintTests.gd` drives a full PROTECT encounter and
  hashes actions, positions and `totem_stolen` / `totem_carrier_id` per round
  (`PROTECT_ROUNDS_HASH`, `PROTECT_FINAL_HASH`, `PROTECT_SAVE_HASH`, lines ~765-771). Pickup,
  carrier burden, retargeting and attack-time theft all change that surface. Run the PROTECT
  fingerprints. Re-record any moved hash on purpose, and name the cause of each move.
- Previously confirmed unaffected (per prior analysis, not re-checked here):
  `tests/ObjectiveCombatTests.gd`, `tests/BehaviorArbiterTests.gd`, `tests/CombatPressureTests.gd`,
  `tests/SpatialModeGoalTests.gd`.
- `CombatPressureTests.gd` should get a **new** assertion added (not just re-run) covering the Subtask 4
  fix: hostile goal targets the holder's actor id, not the totem structure's id, once adjacent and totem
  is uncarried.

## Subtask 6: Docs + Commit

- Update `docs/MEMORY.md` / systems inventory entry for `ProtectCustodyService` to reflect it is now
  live (not dormant) and remove/retire the `CombatRoundObjectiveService.apply_protect_theft_round()`
  reference.
- Update `CONVENTIONS.md` PROTECT-mode section if it documents the old proximity-roll behavior. Note the
  preserved guard-block rule explicitly, so a future reader does not assume the new service enforces it.
- Iterate with filtered tests. Before the commit, run the FULL serial suite (`AGENTS.md:269-277`).
  A filtered or sharded run cannot validate the `movement_fallback` guard.

## Explicitly OUT of scope

- Any other PROTECT-mode mechanic not named above (e.g. totem spawn rules, PROTECT win/loss conditions).
- Any other combat mode (PURSUE, ordinary combat, etc.).
- Any V2-COMBAT-004 work — this story only unblocks it.
- Balance/tuning of `theft_chance`, carry-burden penalty values, or double-damage multiplier — those are
  `mid-game-designer` calls if they come up.

## Risk note

**Scope warning (code review, 2026-10-05):** this story is larger than first scoped. It now covers a
custody-state owner, a pickup producer, the carryability gate, the burden hook, a new pressure-snapshot
field, a fingerprint re-record and a design question. That is several subjects. Jeff decides whether to
split it (for example: state owner + pickup producer first, then theft + AI retargeting) before work
starts. Do not start the build until the double-damage question is answered.

The `CombatPressureService.gd` goal-targeting risk flagged in the original draft is now RESOLVED: the fix
is confined to the hostile branch inside `_add_protect()`, calls shared helpers with new arguments only,
and does not require touching shared helper behavior or verification surface for other combat modes.

The main residual risk is Subtask 3, the guard-block precondition. `ProtectCustodyService` does no gating
by design, and its interface gives no signal that gating is missing. If Subtask 3 is skipped or the
reused adjacency check is wrong, a guarded totem becomes stealable in play with no test catching it unless
the new guard-block test case from Subtask 5 is also added.

## Decisions Jeff has already made

- Guard-block rule: PRESERVE (confirmed 2026-09-26).
