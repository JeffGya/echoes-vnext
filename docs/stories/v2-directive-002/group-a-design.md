# Group A design: C6 (style) and C7 (action layer) on the one status

Author: `sr-game-designer` pass, 2026-10-18. Jeff's answers: D-95 to D-100 in `decisions.md`.
All numbers are PROPOSED DEFAULT. `mid-game-designer` refines them. Line numbers are from main at `19fd246`.
**Note:** `decisions.md` D-101 to D-102 override the numbers and the afraid formula in this first draft. Sections 2 and 3 show the final values.

## 1. Model: one reading, two channels (D-96)

Per activation compute once:
- `L = band_lean[status_of(actor)]` (config `data.combat.movement.felt_state.band_lean`).
- `L_eff = EmotionStatusLean.soften(L, composure, composure_dampen_scale)`.
- `A = afraid(L)^k` (curve on the unsoftened lean, `k` = `data.actor.afraid_curve_exponent` 2.5), then composure softening once (D-101). `B = bold(L_eff)`. Both 0 to 1.

| Channel | GDD role | Effect | Fed by |
|---|---|---|---|
| Threat response | fear: immediate threat response | multiplier on active actions; pull from exposure | `A` |
| Follow-through | morale: follow-through, persistence, recovery | low state raises guard and idle; high state raises melee and move | `A`, `B` |

Composure enters only in `L_eff`. In `_score`, `eff_dampen = dampen * (1 - composure * d_scale)` becomes plain `dampen`. Test: composure 0.5 gives `fear_factor = 1 - fear_active_dampen * A` with no second composure term.
`band_lean` stays in place (D-100). `select_intent` reads it from `_movement_cfg.felt_state.band_lean`.

## 2. C7: action layer (`BehaviorArbiter._score`, ~1785-1866)

```
fear_factor  = clamp(1 - fear_active_dampen * A, 0, 1)   # fear_active_dampen 0.55      # active actions only; fear_passive_actions exempt
state_points = A * afraid_points[action] + B * bold_points[action]
score        = (base + trait + vector + archetype + state_points) * fear_factor * calling_mul + directive + situational
```
Same structure as today. `state_points` replaces the `morale_action_muls` bonus inside the bracket.

Config `data.actor.state_action_points` replaces `morale_action_muls`:

| Action | afraid | bold |
|---|---:|---:|
| melee_attack | -20 | +13 |
| protect_ally | -8 | +8 |
| actor.guard | +25 | -9 |
| actor.idle | +19 | -9 |
| actor.move | -20 | +11 |

Reasoning (D-101): afraid points are the full old `broken` values. Bold points are the old `inspired` shift at composure 0.5 divided by B 0.56. `A` is convex (exponent 2.5), so a mild fear costs little and full fear costs the full amount. No tier cliff.
Known loss (accepted): morale 75+ with fear 20 to 30 reads `whole` (lean 0); no old `inspired` bonus.
Validator for `state_action_points`: known action keys, both ends finite, absolute value at most a config limit (PROPOSED 30). No literal range in code.

**Aduro (D-98).** `calling_behavior.aduro.broken_morale_override` becomes `afraid_points_override = {melee_attack: 8.0, actor.guard: -5.0}`, scaled by `A`. No tier branch. The fear multiplier still applies.

**Calling signatures (D-98, `:1917-1938`).** Kra Soro move, Okomfo `fear*0.15`, Onyamesu `fear*0.15`, Okofor `fear*0.1` and the literal `-8.0` read `A` (`fear_points = 100 * A`). Literals move to `calling_behavior.<calling>.afraid_signature`. Same numbers at `A = 1`. All signature numbers, including Kra Soro move (+12) and idle (-8), live in `afraid_signature`. The key `fear_move_bonus` is removed (D-102).

**Dead config.** `data.actor.broken_morale_overrides` is deleted: no reader.

**Enemies (D-97).** Enemies read the same status (no faction gate in the action layer). They have real fear and morale.

**Logged keys.** Winner dict `morale_tier` becomes `emotional_status` (string). `morale_modifier` (intent) becomes `state_points`; log and snapshot key `action_weight_modifier` keeps its name with value `round(state_points)`. Readers: `ActorStateMachine.gd` ~67-68, 215, 428-429, 450-451, 622, 708-709; tests `MoraleInfluenceTests`, `CombatSnapshotTests`, `CombatInitiativeTests`, `DivergenceDetectorTests`. Save is not affected.

## 3. C6: movement style

`style_inputs` (`BehaviorArbiter.gd` ~777-778) passes `afraid` (the same curved `A`, D-102) and `bold` in place of `fear` and `morale_tier`. `MovementStyleService._score_style` (~171-176):
```
total += afraid * fear_weight[style]
total += afraid * follow_through_bias.afraid[style]
total += bold   * follow_through_bias.bold[style]
```
`bond_weight`, vow terms, slice 7 `vector_mul` and `trait_mul` stay. State terms stay unscaled by Judgment.
Config `data.actor.movement_style_weights`: `fear_weight` keeps its values (unit is now `A`). `morale_bias` becomes `follow_through_bias`:

| End | Entries |
|---|---|
| afraid | careful +10, restrained +10, forceful -6, overcommitted -6 |
| bold | forceful +11, direct +11 |

Callers to update: `StagePartyStance.gd:189` (passes fear 0 today; stays neutral), `tools/ExposureChoiceBoards.gd` (~360-362), tests `MovementStyleServiceTests` (~128, 545-550), `FeltStateTests` (~635).

## 4. Two small readers (D-99)

1. Initiative (`CombatState.gd:180`, `data.combat.initiative_modifiers.afraid_points` and `bold_points`): readiness points = `afraid * afraid_points + bold * bold_points`, from the linear unsoftened lean at combat start (no composure, no curve). PROPOSED afraid -6, bold +5. Remove `_morale_tier_from_score` and `by_morale_tier`.
2. Bark triggers (`ActorStateMachine.gd` ~215, 622, 819, 861): keep context keys. "morale falling" fires when the status rank worsens across the turn (`EmotionService.STATUS_LADDER`); "inspired" fires at `radiant`. Bark wording is Jeff's and is not changed here.

## 5. Readers outside the list

- `ui/AppRoot.gd:943` calls `EmotionService.get_morale_tier` (needs a read by `ui-ux-designer`).
- Absolute Fear Rule (`ActorStateMachine.gd` ~234-246) and the fear-crossing bark thresholds (40, 60, 80) stay on raw fear (Standing-set refusal threshold; not a status reading).

## 6. Tests to plan

Composure counted once; no input beyond `L_eff` reaches `_score`; Aduro charges when afraid; enemy reads the status; log keys `emotional_status` and `action_weight_modifier`; validators for `state_action_points`, `follow_through_bias`, initiative points, `afraid_signature`.
