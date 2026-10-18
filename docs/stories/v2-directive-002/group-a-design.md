# Group A design: C6 (style) and C7 (action layer) on the one status

Author: `sr-game-designer` pass, 2026-10-18. Jeff's answers: D-95 to D-100 in `decisions.md`.
All numbers are PROPOSED DEFAULT. `mid-game-designer` refines them. Line numbers are from main at `19fd246`.

## 1. Model: one reading, two channels (D-96)

Per activation compute once:
- `L = band_lean[status_of(actor)]` (config `data.combat.movement.felt_state.band_lean`).
- `L_eff = EmotionStatusLean.soften(L, composure, composure_dampen_scale)`.
- `A = afraid(L_eff)`, `B = bold(L_eff)`; both 0 to 1.

| Channel | GDD role | Effect | Fed by |
|---|---|---|---|
| Threat response | fear: immediate threat response | multiplier on active actions; pull from exposure | `A` |
| Follow-through | morale: follow-through, persistence, recovery | low state raises guard and idle; high state raises melee and move | `A`, `B` |

Composure enters only in `L_eff`. In `_score`, `eff_dampen = dampen * (1 - composure * d_scale)` becomes plain `dampen`. Test: composure 0.5 gives `fear_factor = 1 - fear_active_dampen * A` with no second composure term.
`band_lean` stays in place (D-100). `select_intent` reads it from `_movement_cfg.felt_state.band_lean`.

## 2. C7: action layer (`BehaviorArbiter._score`, ~1785-1866)

```
fear_factor  = clamp(1 - fear_active_dampen * A, 0, 1)      # active actions only; fear_passive_actions exempt
state_points = A * afraid_points[action] + B * bold_points[action]
score        = (base + trait + vector + archetype + state_points) * fear_factor * calling_mul + directive + situational
```
Same structure as today. `state_points` replaces the `morale_action_muls` bonus inside the bracket.

Config `data.actor.state_action_points` replaces `morale_action_muls`:

| Action | afraid | bold |
|---|---:|---:|
| melee_attack | -10 | +17 |
| protect_ally | -4 | +9 |
| actor.guard | +10 | -7 |
| actor.idle | +8 | -7 |
| actor.move | -10 | +14 |

Reasoning: bold end is old `inspired` divided by the radiant lean 0.7 (range 1.0 to 1.5 times old inspired). Afraid end is about half of old `broken` (range 0.4 to 0.6), because the same band now also feeds `fear_factor`. Linear in `A` and `B`; no tier cliff. Targets for the re-score: at `hollow` the total effect is near the old worst stack; at `burdened` from fear alone it is within 25 percent of the old fear 45 effect; `radiant` near old `inspired`.
Known loss (accepted): morale 75+ with fear 20 to 30 reads `whole` (lean 0); no old `inspired` bonus.
Validator for `state_action_points`: known action keys, both ends finite, absolute value at most a config limit (PROPOSED 25). No literal range in code.

**Aduro (D-98).** `calling_behavior.aduro.broken_morale_override` becomes `afraid_points_override = {melee_attack: 8.0, actor.guard: -5.0}`, scaled by `A`. No tier branch. The fear multiplier still applies.

**Calling signatures (D-98, `:1917-1938`).** Kra Soro `fear_move_bonus`, Okomfo `fear*0.15`, Onyamesu `fear*0.15`, Okofor `fear*0.1` and the literal `-8.0` read `A` (`fear_points = 100 * A`). Literals move to `calling_behavior.<calling>.afraid_signature`. Same numbers at `A = 1`. Kra Soro `fear_move_bonus` scales by `A` (the comment at `balance.json:1146` says "per 10 fear points"; the code adds it once when fear > 0).

**Dead config.** Delete `data.actor.broken_morale_overrides` (`balance.json` ~2432): no reader.

**Enemies (D-97).** Enemies read the same status (no faction gate in the action layer). They have real fear and morale.

**Logged keys.** Winner dict `morale_tier` becomes `emotional_status` (string). `morale_modifier` (intent) becomes `state_points`; log and snapshot key `action_weight_modifier` keeps its name with value `round(state_points)`. Readers: `ActorStateMachine.gd` ~67-68, 215, 428-429, 450-451, 622, 708-709; tests `MoraleInfluenceTests`, `CombatSnapshotTests`, `CombatInitiativeTests`, `DivergenceDetectorTests`. Save is not affected.

## 3. C6: movement style

`style_inputs` (`BehaviorArbiter.gd` ~777-778) passes `afraid` and `bold` (softened once) in place of `fear` and `morale_tier`. `MovementStyleService._score_style` (~171-176):
```
total += afraid * fear_weight[style]
total += afraid * follow_through_bias.afraid[style]
total += bold   * follow_through_bias.bold[style]
```
`bond_weight`, vow terms, slice 7 `vector_mul` and `trait_mul` stay. State terms stay unscaled by Judgment.
Config `data.actor.movement_style_weights`: `fear_weight` keeps its values (unit is now `A`). `morale_bias` becomes `follow_through_bias`:

| End | Entries |
|---|---|
| afraid | careful +5, restrained +5, forceful -3, overcommitted -3 |
| bold | forceful +11, direct +11 |

Callers to update: `StagePartyStance.gd:189` (passes fear 0 today; stays neutral), `tools/ExposureChoiceBoards.gd` (~360-362), tests `MovementStyleServiceTests` (~128, 545-550), `FeltStateTests` (~635).

## 4. Two small readers (D-99)

1. Initiative (`CombatState.gd:461`, `data.combat.initiative_modifiers.by_morale_tier`): readiness points = `A * initiative.afraid_points + B * initiative.bold_points`, from the unsoftened lean at combat start (no composure exists yet). PROPOSED afraid -6, bold +5. Remove `_morale_tier_from_score` and `by_morale_tier`.
2. Bark triggers (`ActorStateMachine.gd` ~215, 622, 819, 861): keep context keys. "morale falling" fires when the status rank worsens across the turn (`EmotionService.STATUS_LADDER`); "inspired" fires at `radiant`. Bark wording is Jeff's and is not changed here.

## 5. Readers outside the list

- `ui/AppRoot.gd:943` calls `EmotionService.get_morale_tier` (needs a read by `ui-ux-designer`).
- Absolute Fear Rule (`ActorStateMachine.gd` ~234-246) and the fear-crossing bark thresholds (40, 60, 80) stay on raw fear (Standing-set refusal threshold; not a status reading).

## 6. Tests to plan

Composure counted once; no input beyond `L_eff` reaches `_score`; Aduro charges when afraid; enemy reads the status; log keys `emotional_status` and `action_weight_modifier`; validators for `state_action_points`, `follow_through_bias`, initiative points, `afraid_signature`.
