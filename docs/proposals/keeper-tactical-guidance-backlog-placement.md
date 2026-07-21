# Keeper Tactical Guidance — Backlog Placement Assessment

**Date:** 2026-07-12  
**Status:** Decision implemented July 12, 2026  
**Decision:** Place the promoted Keeper Tactical Guidance work in Foundation relative to `V2-STAGE-004` and the existing V2 backlog.  
**Outcome record:** Six Notion pages were updated: `V2-COMBAT-002`, `V2-COMBAT-003`, `V2-COMBAT-004`, `V2-DIRECTIVE-002`, `V2-INFRA-004`, and `V2-PROG-012`.

## Recommendation

The implemented decision promotes the prototype through the existing canonical **`V2-COMBAT-004`** story, splits that story into implementation-sized slices, and places its architecture/specification slice in the near-term queue immediately after `V2-STAGE-004`. Do **not** absorb the tactical-guidance implementation into `V2-STAGE-004`.

The backlog already described almost exactly what the prototype proved: tactical pre-positioning and richer mid-battle guidance that preserve Echo autonomy. The canonical page is now **Ready**, **Mostly Locked**, **P1**, and **Foundation**, at order `262`, with its updated dependency and scope record ([V2-COMBAT-004](https://app.notion.com/p/339c3d1ede92819ab2a3cdf32df96731)). The successful prototype supplied the evidence needed to sharpen and re-sequence this existing story rather than create a competing epic.

`V2-STAGE-004` remains the stage/encounter spine: consistent encounter resolution, persistence, logging, hostile-contact escalation, and noncombat outcomes. Its current Definition of Done is not a combat-control or combat-presentation contract ([V2-STAGE-004](https://app.notion.com/p/339c3d1ede928111b43af78e2c44f7ee)). Expanding it with deployment, asynchronous pings, animation, or board interaction would mix stage orchestration with tactical combat and make Jeff's active story materially larger.

The practical pickup order is therefore:

1. Finish and sign off `V2-STAGE-004` without adding Keeper Tactical Guidance scope.
2. Immediately lock the promoted `V2-COMBAT-004` production contract and architecture against the finished stage/encounter seams.
3. After `V2-STAGE-004`, allow `V2-COMBAT-002` to proceed alongside the `V2-COMBAT-004A` architecture work where capacity permits; it does not need to wait for that architecture slice.
4. Complete `V2-PROG-012`, which is a direct declared prerequisite of `V2-COMBAT-003`; then complete `V2-COMBAT-003`, followed by its dependent `V2-DIRECTIVE-002`.
5. Only after those Foundation behavior prerequisites are complete, implement the split `V2-COMBAT-004` slices: tactical field/preparation, asynchronous guidance runtime, then combat readability/presentation.
6. Treat deeper board/ecology variety as later Realm-content work rather than blocking the first production promotion.

## Options Compared

| Option | Fit | Benefit | Main problem | Decision |
|---|---|---|---|---|
| Fold the work into `V2-STAGE-004` | Low | Uses the story currently in progress | Violates its encounter-framework scope; combines stage persistence, combat behavior, board generation, UI, and animation in one story | Reject |
| Leave `V2-COMBAT-004` unchanged in Post-Foundation | Medium | Preserves the old roadmap | Ignores successful prototype evidence and delays a combat change Jeff now considers important | Reject |
| Promote and split the existing `V2-COMBAT-004` after `V2-STAGE-004` | High | Reuses the exact canonical backlog home, preserves dependencies, avoids duplicate architecture | Requires a deliberate GDD/backlog promotion and several coordinated slices | **Recommend** |
| Create a new tactical-guidance epic | Medium-low | Makes the work highly visible | Duplicates `V2-COMBAT-004`; backlog conventions say overlapping canonical stories should be consolidated, not multiplied ([Backlog Conventions](https://app.notion.com/p/339c3d1ede9281509bcacb334bce5593)) | Reject unless scope grows beyond combat |

## Task Fit Matrix

| Prototype learning or production need | Existing backlog fit | Status and dependency evidence | Placement decision |
|---|---|---|---|
| Persistent encounter/objective handoff into combat | `V2-STAGE-004` | **Ready**, Mostly Locked, P1; covers unified combat/contact/structure/pressure resolution and persistence ([V2-STAGE-004](https://app.notion.com/p/339c3d1ede928111b43af78e2c44f7ee)) | Keep only the encounter-to-combat contract here; do not add tactical controls |
| Objective-shaped enemy pressure for all currently authored combat objectives | `V2-COMBAT-002` | **Ready**, Mostly Locked, P1; depends on `V2-STAGE-004` and explicitly aligns enemy behavior with objective/stage pressure ([V2-COMBAT-002](https://app.notion.com/p/339c3d1ede92817bac21e0a822ced6c8)) | Pick up after `V2-STAGE-004`; it may proceed in parallel with `COMBAT-004A` architecture where capacity permits and must finish before full tactical-guidance implementation. Prototype evidence is direct for `RECOVER` and `PROTECT`; the other authored modes need equivalent production validation. |
| Initiative and downstream autonomous behavior | `V2-COMBAT-001` | Canonical story is **Done** and establishes deterministic readiness plus post-initiative guard, rescue, hesitation, refusal, and target choice ([V2-COMBAT-001](https://app.notion.com/p/339c3d1ede9281aca40fd9c2f802d385)) | Reuse; do not build a second turn architecture |
| Directive, fear, morale, bond, and Calling collision order | `V2-COMBAT-003` | **Ready**, Open, P1; directly depends on `V2-PROG-012` (as well as `V2-COMBAT-001`, `V2-BOND-002`, and `V2-VOW-002`) and requires deterministic collision order plus reason-bearing tests/logs ([V2-COMBAT-003](https://app.notion.com/p/339c3d1ede928190ad52ce3f2a0620c8)) | Complete `PROG-012` first, then `COMBAT-003`; pings should enter this arbiter as another bounded pressure source |
| Same guidance interpreted differently by different Echoes | `V2-DIRECTIVE-002` | **Ready**, Open, P1; depends on `V2-COMBAT-003` and requires contrasting profile outcomes under the same influence ([V2-DIRECTIVE-002](https://app.notion.com/p/339c3d1ede9281039faacf423c3e61ba)) | Extend the shared influence/interpretation seam; do not make pings a parallel obedience system |
| Maturity-expression effects on refusal and interpretation | `V2-PROG-010` and `V2-PROG-012` | Runtime maturity expression is **Done** ([V2-PROG-010](https://app.notion.com/p/339c3d1ede9281e4a6f2e32c2d2e122d)); autonomy threshold tuning remains **Draft/Open**, and `PROG-012` is a declared direct dependency of `COMBAT-003` ([V2-PROG-012](https://app.notion.com/p/339c3d1ede928111a2bfc5ad27720596), [V2-COMBAT-003](https://app.notion.com/p/339c3d1ede928190ad52ce3f2a0620c8)) | `COMBAT-004A` contract design may proceed, but `PROG-012` must complete before `COMBAT-003`; it is not optional for the behavior-prerequisite chain |
| One consolidated pre-battle surface and one Echo selection method | `V2-INFRA-004` plus promoted `V2-COMBAT-004` | `V2-INFRA-004` is **Ready**, Mostly Locked, P1 and explicitly asks for one readiness surface combining Directive, intel, prep, loadout, fear, and morale ([V2-INFRA-004](https://app.notion.com/p/339c3d1ede928133b08af6877b4b5be3)) | Put information architecture and consolidation in `INFRA-004`; put tactical deployment rules and board interaction in `COMBAT-004` |
| Fear/morale and listen/resist/refuse readability | `V2-EMOTION-001`, `V2-COMBAT-003`, promoted `V2-COMBAT-004` | Emotional causes and thresholds are already **Done** across Encounter/Resolve surfaces ([V2-EMOTION-001](https://app.notion.com/p/339c3d1ede92818897cbe53e9773eabb)); collision reasons belong to `COMBAT-003` | Reuse cause data; `COMBAT-004` owns the immediate pending/reaction/action presentation |
| Tactical pre-positioning, pings, Charge, exclusive recipient modes, next-round activation | `V2-COMBAT-004` | **Ready**, Mostly Locked, P1, Foundation, order `262`; scope preserves indirect command while adding the promoted tactical-guidance loop ([V2-COMBAT-004](https://app.notion.com/p/339c3d1ede92819ab2a3cdf32df96731)) | This is the canonical Foundation home; implement it through the approved slices and dependency order |
| Automatic playback speeds, movement/attack animation, AOE preview, obstacle occlusion, camera controls, post-battle report | No separate canonical task surfaced in targeted backlog searches | The backlog database is the authoritative task source ([V2 Story Backlog](https://app.notion.com/p/d3dc9cb421e944fc9229238474907ed6)); adjacent combat tasks specify behavioral outcomes rather than this presentation bundle | Make this a distinct presentation/readability slice under promoted `COMBAT-004`, not incidental polish scattered across backend stories |
| Stronger topology and board variety | Later stage/Realm expansion | `V2-STAGE-101` is **Draft**, Post-Foundation and covers richer stage populations/set pieces ([V2-STAGE-101](https://app.notion.com/p/339c3d1ede92816c9e8ee8b897441a0a)); `V2-STAGE-102` is **Draft**, Full Game and covers Realm-specific pressure/ecology ([V2-STAGE-102](https://app.notion.com/p/339c3d1ede92810caf85edeed948513b)) | Keep first production board generator extensible; defer content breadth and Realm-specific ecology |

## Why `V2-STAGE-004` Should Not Absorb the Change

`V2-STAGE-004` answers **what kind of situation is being resolved, how it persists, and how it returns to the stage spine**. Keeper Tactical Guidance answers **how an autonomous combat field runs, how the Keeper influences it, how each Echo interprets that influence, and how the result is shown**. They meet at an encounter contract but have different owners and failure modes.

The active stage story should expose only the additive data tactical combat needs: objective type and parameters, encounter approach, participants/temporary allies, pressure context, deterministic seed context, and final resolution payload. Charge, ping lifecycle, recipient snapshots, response evaluation, animation timing, and board camera state should remain combat concerns.

This boundary also follows the backlog's intended sequence. `V2-COMBAT-002` explicitly depends on `V2-STAGE-004`, which means stage objective/pressure context is meant to stabilize first, then combat behavior consumes it ([V2-COMBAT-002](https://app.notion.com/p/339c3d1ede92817bac21e0a822ced6c8)). Once that stage seam is stable, `COMBAT-002` may run in parallel with `COMBAT-004A` architecture where capacity permits. The behavior chain is stricter: `V2-PROG-012` is a declared dependency of `V2-COMBAT-003`, and `V2-COMBAT-003` is a declared dependency of `V2-DIRECTIVE-002` ([V2-PROG-012](https://app.notion.com/p/339c3d1ede928111a2bfc5ad27720596), [V2-COMBAT-003](https://app.notion.com/p/339c3d1ede928190ad52ce3f2a0620c8), [V2-DIRECTIVE-002](https://app.notion.com/p/339c3d1ede9281039faacf423c3e61ba)).

## Implemented Story Split and Order

`V2-COMBAT-004A` through `004E` are planning slice labels under the single `V2-COMBAT-004` Notion page, not separate database story codes.

### 0. Finish `V2-STAGE-004` — encounter contract only

- Finish the persistent encounter/objective spine already in progress.
- Confirm every currently authored production combat objective exposes the state tactical guidance needs without tactical-UI assumptions.
- Preserve deterministic encounter seed/context and unified resolve handoff.
- Do not add pings, Charge, tactical deployment, or combat animation.

### 1. Pick up `V2-COMBAT-004A` — production contract and architecture

**Pickup:** immediately after `V2-STAGE-004` signoff.

- Use the approved GDD, prototype findings, design reference, and architecture reference as the production contract basis.
- Lock automatic-only combat, playback speed ownership, asynchronous input at atomic boundaries, round-based Charge, next-round activation, one unresolved ping, exclusive recipient modes, and reason-bearing response states.
- Define additive combat-state, snapshot, action, logging, save/re-entry, and seed namespaces before implementation.
- Map prototype concepts onto production services; no prototype dependency.

This approved architecture slice begins after `V2-STAGE-004` because it consumes the completed encounter contract and clarifies the downstream work. The full feature should not be implemented as a single immediate story.

### 2. Complete the Foundation behavior prerequisites

After `V2-STAGE-004`, use two coordinated lanes where capacity permits:

- `V2-COMBAT-002` — objective/stage-shaped enemy pressure — may proceed in parallel with `V2-COMBAT-004A` architecture.
- The mandatory behavior chain is `V2-PROG-012` → `V2-COMBAT-003` → `V2-DIRECTIVE-002`:
  1. `V2-PROG-012` — named autonomy/maturity weighting and threshold seam with observable interpretation, refusal, and self-assertion outcomes.
  2. `V2-COMBAT-003` — deterministic pressure collision and observable primary reasons; its other declared dependencies must also remain satisfied.
  3. `V2-DIRECTIVE-002` — identity-sensitive interpretation of a shared influence.

Full tactical-guidance implementation begins only after `V2-COMBAT-002` and the mandatory behavior chain are complete. `V2-INFRA-004` remains the home for the consolidated readiness information architecture; tactical deployment rules and board interaction remain in `V2-COMBAT-004`.

`V2-COMBAT-001`, `V2-EMOTION-001`, and `V2-PROG-010` are already Done and can be treated as established rails ([V2-COMBAT-001](https://app.notion.com/p/339c3d1ede9281aca40fd9c2f802d385), [V2-EMOTION-001](https://app.notion.com/p/339c3d1ede92818897cbe53e9773eabb), [V2-PROG-010](https://app.notion.com/p/339c3d1ede9281e4a6f2e32c2d2e122d)).

### 3. `V2-COMBAT-004B` — tactical field and preparation

- Production tactical board contract, deterministic field generation, deployment zones, hazards, obstacle occupancy/occlusion, and objective accessibility.
- One roster selection surface and one deployment interaction path.
- All seven currently authored combat modes as Foundation acceptance scope, each preserving its mode rules; `RECOVER` and `PROTECT` remain the prototype-validated evidence cases.
- Board diagnostics and same-seed regeneration.
- Coordinate the consolidated readiness shell with `V2-INFRA-004`; do not duplicate its party/readiness presentation.

### 4. `V2-COMBAT-004C` — asynchronous Keeper guidance

- Ping Charge and round cadence.
- Five promoted pings, each with exactly one recipient mode.
- Live legality/AOE/recipient preview without pausing playback.
- Buffered confirmation at atomic action boundaries.
- Immutable recipient snapshot and next-round pending lifecycle.
- Per-recipient Align/Interpret/Hesitate/Object/Refuse evaluation through the canonical behavior arbiter.
- Immediate reaction/reason reveal followed by the Echo's first resulting action.

### 5. `V2-COMBAT-004D` — combat readability and report

- Always-automatic playback with speed controls.
- Movement interpolation, attacker-to-target action animation, damage punch, hazards, and objective feedback.
- Pending/listening/resisting/rejecting state cues without debug formulas.
- Isometric draw order, obstacle occlusion, pan/zoom/recenter, and compact viewport support.
- Post-battle causal report joining preparation, pings, responses, fear/morale, hazards, and objective outcome.

### 6. `V2-COMBAT-004E` — production tuning and promotion gate

- Same-seed paired tests across all currently authored combat objectives, Directives, deployments, parties, and ping schedules; use `RECOVER` and `PROTECT` as direct prototype comparison cases without treating them as the production scope limit.
- Measure the prototype's still-unproven human thresholds: ping comprehension, response-reason comprehension, visible behavior change, Directive differentiation, meaningful decisions, and battle duration.
- Defer broad Realm ecology and large board-variety expansion to `V2-STAGE-101` / `V2-STAGE-102`; only fix generator variety that prevents the first production slice from meeting its tactical acceptance criteria.

## Risks and Guardrails

### Dependency order remains binding

`V2-COMBAT-004` is now Ready/Mostly Locked/P1/Foundation, but its declared dependency order still applies: `PROG-012` must complete before `COMBAT-003`, and `COMBAT-003` must complete before `DIRECTIVE-002`; full tactical-guidance implementation follows those behavior seams ([V2-PROG-012](https://app.notion.com/p/339c3d1ede928111a2bfc5ad27720596), [V2-COMBAT-003](https://app.notion.com/p/339c3d1ede928190ad52ce3f2a0620c8), [V2-DIRECTIVE-002](https://app.notion.com/p/339c3d1ede9281039faacf423c3e61ba)).

### Execution-state caveat

The six approved Notion page updates were applied July 12, 2026. Jeff's active work and repository evidence remain the execution truth when a stored task status lags the work in progress.

### Prototype evidence is positive but not exhaustive

The qualitative playtest establishes meaningful choice, challenge, emotional readability, and a successful non-command combat fantasy. It does not yet prove every quantitative success threshold across players, seeds, Directives, and objective modes. Keep the production rollout sliced and measurable.

### Avoid a second behavior architecture

Pings must be temporary weighted influences resolved by the same deterministic pressure/identity system as Directives, Calling, maturity expression, fear, morale, and bonds. A standalone ping AI or special-case obedience score would recreate the exact collision problem `V2-COMBAT-003` exists to solve.

### Keep stage and combat boards distinct

The persistent stage map and the tactical combat field serve different scales. Reuse deterministic seed context and objective/pressure data, not necessarily the same topology or token model. `V2-STAGE-101` still has an open design question about group-token versus individual-Echo stage traversal; tactical deployment should not silently decide that separate exploration question ([V2-STAGE-101](https://app.notion.com/p/339c3d1ede92816c9e8ee8b897441a0a)).

## Sources

- [Echoes vNext V2 Backlog Hub](https://app.notion.com/p/339c3d1ede92814da4c2dad94d650e30)
- [Echoes vNext V2 Story Backlog](https://app.notion.com/p/d3dc9cb421e944fc9229238474907ed6)
- [Backlog Conventions](https://app.notion.com/p/339c3d1ede9281509bcacb334bce5593)
- [V2-STAGE-004](https://app.notion.com/p/339c3d1ede928111b43af78e2c44f7ee)
- [V2-COMBAT-001](https://app.notion.com/p/339c3d1ede9281aca40fd9c2f802d385)
- [V2-COMBAT-002](https://app.notion.com/p/339c3d1ede92817bac21e0a822ced6c8)
- [V2-COMBAT-003](https://app.notion.com/p/339c3d1ede928190ad52ce3f2a0620c8)
- [V2-COMBAT-004](https://app.notion.com/p/339c3d1ede92819ab2a3cdf32df96731)
- [V2-DIRECTIVE-002](https://app.notion.com/p/339c3d1ede9281039faacf423c3e61ba)
- [V2-INFRA-004](https://app.notion.com/p/339c3d1ede928133b08af6877b4b5be3)
- [V2-EMOTION-001](https://app.notion.com/p/339c3d1ede92818897cbe53e9773eabb)
- [V2-PROG-010](https://app.notion.com/p/339c3d1ede9281e4a6f2e32c2d2e122d)
- [V2-PROG-012](https://app.notion.com/p/339c3d1ede928111a2bfc5ad27720596)
- [V2-STAGE-101](https://app.notion.com/p/339c3d1ede92816c9e8ee8b897441a0a)
- [V2-STAGE-102](https://app.notion.com/p/339c3d1ede92810caf85edeed948513b)
