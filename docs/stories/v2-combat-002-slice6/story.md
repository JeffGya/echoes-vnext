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
  the old round-end draw's position or value.
- `_resolve_melee()` in `CombatService.gd` already supports carrier double-damage via
  `attacker["_carrier_double_damage"]` / `attacker["_double_damage_mult"]` — this stays; only the
  theft-trigger condition changes from "adjacent at round end" to "attack landed on carrier."

## Subtask 2: Mechanical cutover

- In `CombatTurnActionService.gd`, at the confirmed hook point, assemble the `attack` dict from `result`,
  `actor`, and `target`, and call `ProtectCustodyService.resolve_theft_on_attack()` when the encounter is
  PROTECT mode and a totem is in custody.
- Also wire, at their natural call sites: `pickup_action_plan` / `resolve_pickup` (totem pickup),
  `track_carrier_movement` (carry-burden movement penalty), `resolve_drop` (carrier down/KO), and
  `enemy_carrier_restrictions` (movement/action limits on an enemy carrying the totem).
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
`_add_actor_engage(candidates, BUCKET_TACTICAL, context, pressure, "breaker", NORMAL, str(holder_id))`,
mirroring the pattern already used at lines 273-287 for the post-theft carrier case, and already proven
correct for GUIDE_SPIRIT's escort-threat case via `_add_guide()` at line 364.

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
  2. Add a new case verifying the guard-block precondition from Subtask 3 still holds — a hostile actor
     adjacent to the totem does NOT trigger pickup/theft while a living echo is guarding it.
  The carrier-death recovery half of the test (lines ~1665-1690) is behavior-agnostic to the trigger
  mechanism and is expected to keep passing largely as-is.
- **Confirmed unaffected:** `tests/FlowFingerprintTests.gd` only reads `totem_stolen` /
  `totem_carrier_id` as fixture keys (line ~254-255) — no assertion on trigger mechanism. No change
  needed.
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
- Commit per project convention after compile check + filtered test run pass.

## Explicitly OUT of scope

- Any other PROTECT-mode mechanic not named above (e.g. totem spawn rules, PROTECT win/loss conditions).
- Any other combat mode (PURSUE, ordinary combat, etc.).
- Any V2-COMBAT-004 work — this story only unblocks it.
- Balance/tuning of `theft_chance`, carry-burden penalty values, or double-damage multiplier — those are
  `mid-game-designer` calls if they come up.

## Risk note

The `CombatPressureService.gd` goal-targeting risk flagged in the original draft is now RESOLVED: the fix
is confined to the hostile branch inside `_add_protect()`, calls shared helpers with new arguments only,
and does not require touching shared helper behavior or verification surface for other combat modes.

The main residual risk is Subtask 3, the guard-block precondition. `ProtectCustodyService` does no gating
by design, and its interface gives no signal that gating is missing. If Subtask 3 is skipped or the
reused adjacency check is wrong, a guarded totem becomes stealable in play with no test catching it unless
the new guard-block test case from Subtask 5 is also added.

## Decisions Jeff has already made

- Guard-block rule: PRESERVE (confirmed 2026-09-26).
