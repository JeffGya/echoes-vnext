# V2-COMBAT-002 Orchestrator Handoff

Created: 2026-07-17 (Europe/Amsterdam)

Repository: `/Users/jeffreygyamfi/Sites/echoes-vnext`

This is a planning handoff. No COMBAT-002 implementation has begun. No repository files were changed while producing this audit and plan.

## Immediate gate

Do not create the story worktree or implement until both conditions are satisfied:

1. Jeff approves or revises the plan below.
2. PR #43 is retargeted to `main` and merged, closed, or otherwise explicitly resolved.

PR #43: <https://github.com/JeffGya/echoes-vnext/pull/43>

Current verified Git state at the time of this handoff:

- Shared workspace branch: `fix/combat-is-kill-signal` at `a454379`.
- `origin/main` was fetched and was `531d13b`, four commits ahead of local `main`.
- PR #42 was merged into `main`.
- PR #43 remained OPEN and MERGEABLE, but targeted the now-merged `feat/v2-combat-support-attribution` branch instead of `main`.
- PR #43 changes `core/combat/CombatService.gd`, `core/runtime/FlowRuntime.gd`, `tests/CombatRoundtripIntegrationTests.gd`, and `tests/CombatServiceTests.gd`.
- These overlap COMBAT-002 directly.

Preserve these user-owned changes exactly. Do not reset, switch over, stage, rewrite, delete, or commit them:

- `AGENTS.md`
- `core/runtime/FlowRuntime.gd`
- `docs/Echoes vNext V2 Story Backlog d3dc9cb421e944fc9229238474907ed6_all.csv`
- `docs/Echoes vNext Working GDD.md`
- `tests/CombatRoundtripIntegrationTests.gd`
- untracked `docs/movement-model.md`
- untracked `docs/proposals/`
- untracked `prototypes/`

Existing detached Codex worktrees and a prunable temporary responsive worktree were inspected but not modified. Do not clean them without explicit authority.

## Required authority

Canonical Notion page:

<https://app.notion.com/p/339c3d1ede92817bac21e0a822ced6c8>

The live page was fetched on 2026-07-17 and confirmed:

- Code: V2-COMBAT-002
- Status: Ready
- Order: 243
- Priority: P1
- Spec State: Mostly Locked
- Dependencies: V2-STAGE-002, V2-STAGE-004, V2-COMBAT-001
- All seven production modes are in scope.
- Movement Model slices A/B and fixed hazard fixtures belong to COMBAT-002.
- COMBAT-003 retains final reason arbitration and counterfactual trace.
- COMBAT-004 retains generated boards, production hazard placement, tactical overlays, and guidance presentation.
- The local CSV exact page/order row matched the live page.
- All three dependencies were recorded Done in `docs/integration-map.md`.

Before acting in a fresh chat, read completely, in the order required by the user:

1. `docs/MEMORY.md`
2. `AGENTS.md`
3. `CONVENTIONS.md`
4. `docs/CONTEXT.md`
5. `docs/LESSONS.md`
6. `~/.claude/lessons.md`
7. `docs/v2-migration-map.md`
8. `docs/Echoes vNext Working GDD.md`
9. `docs/movement-model.md`
10. `docs/combat-modes.md`
11. `docs/combat-modes-distinctiveness.md`
12. `docs/proposals/keeper-tactical-guidance-promotion.md`
13. `docs/proposals/keeper-tactical-guidance-architecture.md`
14. `prototypes/keeper_tactical_guidance/SPEC.md`
15. `prototypes/keeper_tactical_guidance/CONTRACTS.md`
16. `prototypes/keeper_tactical_guidance/FINDINGS.md`
17. `prototypes/keeper_tactical_guidance/RUN.md`

Use the requested project/game/Godot skills. The prototype is evidence only and must never be imported into production.

## Verified production seams

### BehaviorArbiter

- `BehaviorArbiter.select_intent()` around line 248 builds and scores candidates.
- `_generate_candidates()` around line 346 currently identifies candidates mainly with action type, target, distance, HP, skill metadata, and an unused `priority` field.
- There is no movement goal ID, option ID, route, cost, capacity, commitment, route metric, planned action, fallback, or pressure-source list.
- The final tie-break around line 303 uses only `action_type`. Equal `actor.move` candidates would collapse to insertion behavior.
- Current mode overrides use exact target cells: shrine, carrier/totem threat, quarry, or nearest enemy.
- `_score()` already receives the full candidate, so candidate-specific spatial utility can be added inside the existing arbiter without creating another scoring engine.
- Existing Calling, traits, ten virtues, fear, morale, maturity, directives, skills, situation, bonds, and vows all use this seam and must remain operative.

### ActorStateMachine

- `ActorStateMachine.advance_turn()` starts around line 78.
- It currently selects, logs, and then irreversibly moves around line 340 through `GridService.move_toward()`.
- It returns selected intent rather than resolved activation truth.
- It has no movement-plus-action structure, post-movement revalidation, declared fallback, interruption, ordered events, or truthful failed-move accounting.
- `_last_action` can be captured before later target redirection/movement truth.
- Passive bookkeeping can count a selected move even if the actor did not change cells.

Required boundary: keep identity/emotion/skill activation ownership here, but separate selection from physical execution and finalize bookkeeping from the actual result.

### GridService

- `GridService.move_toward()` around line 113 mutates exactly one cell and returns only from/to.
- It lacks weighted cost, capacity, control, hazards, forced movement, or structured results.
- Its legacy rectangular greedy fallback around line 159 has a lowest-row/column directional bias.
- Keep GridService focused on grid math, bounds, placement, and direct position assignment.

### StageTerrain

- `bfs_distance_field()` around line 466 is deterministic, unweighted, eight-direction BFS.
- `next_step()` around line 614 contains the shipped target-directed correction.
- `walkable` is the irregular-board collision authority.
- Current production permits diagonal travel between two blocked corners.
- Frontier ties still fall back to row/column ordering.
- StageTerrain should own topology and shared edge legality. New weighted routing belongs under `core/movement/`.

### FlowRuntime and live modes

- `_resolve_next_actor()` starts around line 1614 and currently combines actor selection, full-information context, mode weights, state-machine mutation, damage, emotion, support attribution, result projection, and PURSUE escape checks.
- `_end_round()` starts around line 2102 and authoritatively orders shrine drain, emotion, RECOVER, ENDURE waves, GUIDE movement, PROTECT custody/theft, PURSUE containment, and end-condition checks.
- COMBAT remains generic skirmish targeting.
- PURIFY_SHRINE uses exact shrine targeting rather than lanes/regions.
- RECOVER weights the holder but still geometrically targets enemies; holder selection occurs at round end.
- PROTECT targets structure/carrier while interposition is non-spatial.
- ENDURE has waves and dual-win authority but no movement-pressure adapter.
- PURSUE redirects Echoes to the quarry's exact cell. Arbiter/snapshot logic uses distance to any edge, but authoritative escape is the long-axis far end.
- GUIDE_SPIRIT has no close/front/rear escort regions. A non-joining spirit uses bespoke one-cell end-round movement.

FlowRuntime must remain a coordinator. Do not move planning, routing, or hazard algorithms into it.

### Combat/encounter state

- `EncounterContext` has safe additive transient seams for pressure, fixed hazard fixtures, trigger ledgers, and movement results.
- `CombatState.create()` calculates initiative once.
- RECOVER and ENDURE reinforcements append without re-sorting.
- Live mutation must use `EncounterContext.actors`; `combat_state["actors"]` is a stale deep copy after combat begins.
- `objective_state` may project readable facts but must not become decision or win/loss authority.

### Stage traversal

- Stage traversal remains one party token in `_handle_stage_advance_turn()`.
- Current party budget comes from directive `step_budget`: Scout Carefully 3, Seek Signs 6.
- Per-cell fog reveal and contact interruption already exist.
- Internal stepped cells exclude the start, but stored/projected `traveled_path` prepends it.
- Hard objective preference and deterministic frontier ties require bias review, not random wandering.

### Config, baseline, and F1 command

- Correct additive config location: `data.combat.movement` in `data/balance.json`.
- Mode pressure tuning should extend `data.combat.objective_modes`.
- Current dirty PR branch compile check passed.
- Full test runner reported `958 total, 958 passed, 0 failed`, exit 0.
- Godot added no workspace changes.
- The test log was not clean. It emitted unexpected script errors, including an `ActorStateMachine._select_bark()` Array.get arity error and stage snapshot assertions. Re-run on clean updated `origin/main` after PR #43 resolves. Runner-green with unexpected engine script errors is not an acceptable clean baseline.

Actual F1 forcing commands:

```text
combat_objective <combat|purify_shrine|recover|protect|endure|pursue|guide_spirit|show>
combat_objective guide_spirit [protect|escort] [join|nojoin]
```

The global `AppRoot.gd` help string is stale and advertises only a partial older list.

---

# Approved-plan candidate awaiting Jeff's response

## 1. Problem Statement

Combat currently translates autonomous judgment into one geometrically chosen target and one-cell movement. Mode weights can influence whether an actor moves, but do not provide distinct routes, tactical regions, commitment choices, or truthful spatial roles.

Because movement mutates before ordered execution can be observed, the runtime cannot correctly support multi-step paths, hostile-control cost, hazards, interruption, movement-plus-action, or post-movement revalidation.

Stage traversal already executes multiple cells but uses a separate unweighted, fixed-budget representation whose public path incorrectly includes the starting cell.

COMBAT-002 must establish one deterministic physical movement foundation while preserving existing arbitration and identity layers, party-level exploration, individual combat actors, all seven objective authorities, fixed initiative, reinforcement append order, and the COMBAT-003/004/ITEM-003 boundaries.

## 2. Design Brief

Implement a shared movement contract and physical executor with separate decision adapters:

- Combat pressure adapters publish goals, regions, urgency, custody, roles, blockers, perceived facts, and truthful purpose IDs.
- Stage exploration publishes one party-level goal and intent.
- Route services generate bounded, mechanically distinct alternatives.
- `BehaviorArbiter` remains the sole selector.
- Capacity describes what can be spent; the selected option's route cost becomes commitment.
- The executor resolves the selected route edge by edge and returns one structured atomic activation result.
- Echoes, enemies, quarry, and eligible NPCs use the same legality, occupancy, edge cost, hostile-control, forced-movement, hazard, and stop semantics.
- Existing round-end objective authority remains outside the planner and executor.

Proposed capacity derivation for explicit Jeff approval:

```text
capacity = clamp(
  2
  + 1 if current agi >= 12
  + 1 if current agi >= 18
  + configured confirmed-Calling bonus
  + configured equipped-skill bonus,
  2,
  6
)
```

Initial truthful modifiers:

- Confirmed `kra_soro`: +1.
- Equipped `kra_soro_open_ground`: +1.
- `sum_okwanfo_shadow_step`: candidate for +1, subject to P0 characterization because its current effect is mostly descriptive.
- No direct Standing bonus. Standing affects capacity only through existing developed stats, Calling, and equipped skills.
- No saved `max_movement` field.
- Equipment remains ITEM-003.

Current ranges imply early capacity 2, unusually agile early actors possibly 3, developed actors 3-4, movement-focused development 5, and cumulative Kra Soro development up to 6.

Proposed diagonal freeze for explicit Jeff approval:

- A diagonal edge is illegal only when both orthogonal side cells are non-walkable.
- Occupied side cells do not count as solid corners.
- Apply identically to planning, execution, forced displacement, combat, and stage traversal.

## 3. Player experience and UI/UX consequences

No new screen and no player-facing combat movement-point or score display.

Existing combat presentation gains:

- Chained token movement through the actual ordered path rather than straight interpolation from origin to final cell.
- Short mechanically truthful activity text from purpose/result facts, such as screening a holder, cutting off a quarry, staying near a spirit, a named enemy forcing a longer route, or Binding stopping an actor.
- One initiative activation for a long move.
- Chronological forced displacement and hazard feedback.
- No flanking, dodge, high-ground, back-attack, or similar claims before those mechanics exist.

COMBAT-003 later decides the final primary explanatory reason.

Stage presentation keeps one party marker and adapts its chained tween to path-excludes-start while preserving fog, interruption, and travel readability.

## 4. Architecture and contract map

### Service ownership

| Owner | Responsibility |
|---|---|
| `StageTerrain` | Walkable topology, bounds-aware neighbors, shared diagonal edge legality, legacy BFS compatibility |
| `GridService` | Grid math, placement, distance helpers, direct position assignment |
| `MovementProfileService` | Derive capacity, control capability, and source terms from current actor/config data |
| `MovementPathService` | Weighted paths, reachable regions, route cost, candidate envelope, deterministic reconstruction |
| `MovementOptionService` | Generate/deduplicate truthful direct, safe, cohesive, lateral, screen, intercept, and conservative options |
| `CombatPressureService` | Publish seven-mode pressure snapshots and role goals; never decide victory |
| `BehaviorArbiter` | Score distinct options through existing identity, directive, bond, vow, emotion, and situation layers |
| `MovementExecutor` | Edge legality, dynamic occupancy, voluntary cost, forced displacement, stop semantics, ordered events |
| `MovementHazardService` | Fixed Unstable/Binding/Burning behavior and once-per-type turn ledger |
| `CombatActivationService` | Coordinate selection, movement, action revalidation/fallback, counters, and final result |
| `StagePartyMovementAdapter` | Convert party/directive state into one shared profile, goal, intent, and result |
| `ActorStateMachine` | Identity/emotion/skill activation preparation and final bookkeeping without hidden movement mutation |
| `FlowRuntime` | Thin orchestration and existing objective/custody/end-condition boundaries |

### Documented validated schemas

Implement constructors, required-field constants, validators, and contract tests. Do not use undocumented free-form dictionaries.

- `MovementContext`: actor/party ID, activation ID, origin, bounds, authoritative walkable, perceived planning cells, occupancy, perceived actors, relationships, terrain costs, known hazards, objective pressure, movement history.
- `MovementProfile`: capacity, source terms, controlling state, actor kind, authored override. Structures zero; non-joining GUIDE spirit authored one-cell profile.
- `MovementGoal`: `goal_id`, purpose, destination region, urgency, objective progress, relevant actors, pressure sources, planned primary, declared fallback.
- `MovementOption`: `goal_id`, deterministic `option_id`, purpose, destination, ordered path excluding start, route/shortest cost, slack, capacity, commitment, exposure, congestion, cohesion, hostile-control sources, hazard summary, objective progress, planned action, fallback.
- `MovementIntent`: selected actor/activation/goal/option/path/capacity/commitment/action/fallback/pressure sources.
- `MovementResult`: origin/final destination/planned path/actual traversed cells/voluntary cost/forced steps/remaining capacity/stop reason/events/planned and resolved actions/fallback/hazards/objective progress/hostile constraints.
- Ordered event: strictly increasing `seq`, phase/type/source/from/to/voluntary-or-forced/cost/hazard/damage/stop facts.
- Stop reasons: `reached_destination`, `commitment_spent`, `capacity_spent`, `no_route`, `blocked_edge`, `occupied`, `interrupted`, `binding_stop`, `ko`, `death`, `action_invalid_no_fallback`.

Paths exclude the start. Actual traversal includes every voluntary and forced destination chronologically.

### Route and arbitration rules

- Weighted Dijkstra/A* with stable semantic keys; no RNG.
- Maximum four distinct options per goal and three active goals per actor.
- Use the approved route-slack formula.
- Deduplicate identical destination/path combinations.
- Generate an option only when its route/destination makes its label truthful.
- Add bounded candidate-specific spatial utility inside `BehaviorArbiter._score()`.
- Preserve all old identity/action layers.
- Stable tie order: score descending, then `action_type`, `goal_id`, `option_id`.
- Conservative stopping positions are real partial-progress options. Commitment equals selected option cost, not a second personality model.

### Physical rules

- Normal orthogonal/diagonal edge: 1.
- Difficult edge: 2.
- Voluntary hostile-control edge: +1 once if either endpoint is eight-direction adjacent to one or more active perceived hostiles.
- Record all source IDs sorted, but charge only once.
- Friendly/neutral adjacency: 0.
- Dead, KO, structures, and explicitly non-controlling actors project no control.
- Occupied destinations unavailable.
- Forced movement consumes no voluntary capacity.
- Hazard exposure is separate from capacity cost.
- Planner receives perceived facts; executor receives physical truth.
- No move-attack-move.

### Hazard and objective order

```text
enter cell
-> Unstable displacement or fallback damage
-> Binding stop
-> repeat voluntary edges when allowed
-> revalidate selected primary action
-> declared purpose-related fallback, if required
-> action and counters
-> Burning end-activation damage
-> immediate KO/death truth
-> existing objective/custody/end-condition boundary
```

- Unstable uses its authored center, then incoming edge direction when exactly centered. Alternatives rank by outward progress and angular deviation rather than global row/column order.
- Each hazard type triggers at most once per actor activation.
- Forced displacement cannot recursively retrigger Unstable.
- Non-joining GUIDE spirit keeps authored one-cell end-round pace. Treat objective-phase movement as an explicit NPC activation using the same executor and hazards before GUIDE progress.
- Authoritative PURSUE escape remains the long-axis far end; arbiter, snapshot, quarry, and forced movement must share the same helper.

## 5. Foundation versus Later

COMBAT-002 includes shared movement contracts, seven pressure adapters, candidate-specific spatial arbitration, capacity/commitment, ordered execution, movement-plus-action, spatial retreat/screen/interpose/protect/pursue/carry behavior, parity, party stage adapter, fixed obstacle/hazard fixtures, semantic results, and existing-screen presentation.

Deferred:

- COMBAT-003: pressure collision, primary-reason selection, counterfactual trace, complete influence reporting.
- COMBAT-004: board generator/validator, production obstacle/hazard placement, topology profiles, briefing, legends, overlays, telegraphs, occlusion.
- ITEM-003: equipment movement/range/weight.
- Later: elevation, climbing, facing, back attacks, reaction timing, overwatch, concealment, phasing, broad hazard families.

## 6. Risks

- PR #43 may invalidate audited contracts/line numbers.
- Current runner reports green despite unexpected script errors.
- Moving execution out of ActorStateMachine can disturb bark, passive, skill, and support attribution timing.
- FlowRuntime may grow if algorithms are integrated inline.
- The stale combat-state actor copy can be mutated accidentally.
- GUIDE objective-phase movement and PURSUE escape ordering are high risk.
- Capacity may double-reward Standing if direct rank bonuses are added.
- The diagonal rule changes current production traversal.
- Route candidate volume may cause performance/score dominance; retain option limits and utility bounds.
- Planning/execution information separation is necessary for hidden-information fairness.
- Pressure adapters must not absorb win/loss authority.
- Atomic long movement must remain readable.

Use separate architecture, determinism, movement-design, mode-correctness, and test-coverage reviewers. `FlowRuntime.gd`, `BehaviorArbiter.gd`, `balance.json`, and AppRoot test registration are serial integration bottlenecks; never assign two concurrent editors to them.

## 7. Automated acceptance

Dedicated suites must cover:

- Schema construction/validation and path-excludes-start.
- Deterministic replay and mirrored fixtures without row/column bias.
- Weighted legality/cost and difficult terrain.
- Exact once-per-edge hostile control; friendly/neutral/dead/KO/non-controlling cases.
- Slack envelope and truthful option deduplication.
- Capacity/commitment bounds and free forced movement.
- Dynamic occupancy, interruption, no backtracking, named stop reasons.
- Movement then action ordering and final-position revalidation.
- Purpose-related fallback restriction.
- Unstable -> Binding -> action -> Burning.
- Hazard ledger across voluntary and forced cells.
- Hazard death, custody, quarry escape, objective boundaries.
- Echo/enemy/NPC physical parity.
- Hidden hazard/hostility exclusion from planning.
- Fixed initiative and reinforcement append order.
- All old Calling/trait/virtue/fear/morale/bond/vow/directive/maturity/skill/situation influences after candidate expansion.
- All seven pressure-mode invariants and transitions.
- Contact around rounds 2-3 and representative 5-7-round COMBAT trends without identical outcomes.
- No more than two consecutive pure-movement activations without progress unless mode-required.
- Party-token stage traversal, per-cell discovery/interruption, corrected path convention, deterministic frontier correction.

After every GDScript change, use the exact compile watchdog. At each slice gate run the full exact watchdog and compare `git status` before/after.

## 8. Manual playtest acceptance

Force:

```text
combat_objective combat
combat_objective purify_shrine
combat_objective recover
combat_objective protect
combat_objective endure
combat_objective pursue
combat_objective guide_spirit protect nojoin
combat_objective guide_spirit escort nojoin
```

Also sample joined GUIDE variants. Commands reset the encounter; re-enter combat.

Jeff verifies:

- No top-left/bottom-right drift.
- At least 8/10 moves have an understandable purpose.
- At least 8/10 constrained routes identify the hostile source.
- Rash/cautious/protective/calculating profiles differ defensibly.
- Every mode shows its runner/lane/screen/wave/cutoff/theft/recovery/escort behaviors.
- Stage remains party-based.
- Hazards matter without unavoidable losses.
- Long movement reads clearly and objective banners remain truthful.

After compile and full tests pass, stop for Jeff's in-game approval before that slice's Docs + Commit step.

## 9. Docs + Commit scope

After manual approval only:

- `CONVENTIONS.md`
- `docs/MEMORY.md`
- `docs/integration-map.md`
- `docs/movement-model.md` only for approved discovered clarifications
- relevant combat/traversal docs
- story acceptance and actual test totals
- stale F1 help text as an explicitly approved story-owned tooling fix

Correct `V2-DIRECTIVE-001 Next` in integration-map from verified current state. Do not include the user-modified AGENTS.md, GDD, backlog CSV, proposals, or prototypes.

Update Notion only after automated verification, manual approval, current docs, commit, and PR.

## Proposed PR slices

1. Contracts and weighted primitives: P0-P1, no live behavior switch.
2. Pressure and route arbitration: P2, all seven modes and enemy roles.
3. Profile, executor, and fixed hazards: P3-P4.
4. Special combat movement: P5.
5. Party stage adapter: P6.
6. Playable surface, full regression, and final docs: P7.

Each slice uses an isolated branch/worktree after its predecessor is approved and integrated. Delegate all production code, tests, config, presentation, and documentation. The root orchestrator freezes contracts, assigns non-overlapping ownership, commissions independent reviews, integrates, and performs git hygiene.

---

# Startup prompt for the next chat

Copy everything inside the following block into a new Codex chat:

```text
Act as the root orchestrator for Echoes vNext story V2-COMBAT-002. The prior chat completed the required read-only audit and prepared a plan, but implementation has not begun.

First read this handoff completely:

/private/tmp/v2-combat-002-orchestrator-handoff.md

Then independently obey AGENTS.md and the original story authority. Re-read every mandatory source listed in the handoff before planning or acting; do not rely only on the handoff summary. Load and use the requested project/Godot/game-design skills, reading docs/skills fallbacks where unavailable. The prototype is evidence only and must never be imported into production.

You are the orchestrator. Delegate all feature code, tests, config, content, presentation, and documentation authoring. Freeze contracts before delegation. Give agents disjoint file ownership and never allow concurrent edits to FlowRuntime.gd, BehaviorArbiter.gd, balance.json, AppRoot test registration, or another shared file. Use separate architecture, determinism, movement-design, mode-correctness, and test-coverage reviewers. Perform only hard pipeline-blocker and git/integration hygiene inline.

Before any implementation:

1. Inspect current branch, status, worktrees, dirty files, and open PRs.
2. Fetch and verify origin/main.
3. Verify PR #43's current base and disposition. It previously remained open on the merged feat/v2-combat-support-attribution branch and overlaps CombatService, FlowRuntime, and combat tests.
4. Do not create the COMBAT-002 worktree until PR #43 is retargeted/merged/closed or otherwise explicitly resolved.
5. Preserve all user-owned dirty and untracked files listed in the handoff. Never reset, switch, stage, delete, rewrite, or commit them.
6. Once the overlap is resolved and Jeff has approved the plan, create an isolated worktree and fresh feat/v2-combat-002 branch from updated origin/main. Do not reuse an old stage branch.
7. In that clean worktree, establish the real baseline with the exact 200-second compile and full-test watchdogs. Check git status before and after. The prior dirty branch reported 958/958 but emitted unexpected script errors; do not accept a runner-green baseline with engine script errors.

The plan awaits Jeff's explicit approval or revision on four freezes: the capacity formula, the two-solid-corners diagonal rule, the GUIDE objective-phase NPC activation boundary, and the six-PR slicing. If this new chat begins without that approval, present the handoff plan concisely and stop for approval. Do not implement.

If Jeff approves, execute only the approved first slice. Backend before frontend. Preserve fixed initiative, reinforcement append order, walkable authority, actor-ID uniqueness, target-directed next_step, snapshot/action contracts, determinism, and all COMBAT-003/004/ITEM-003 boundaries. Run compile after every GDScript change and full tests at the slice gate. Then stop for Jeff's manual in-game test before Docs + Commit and PR.

At every handoff, report exact contracts, mode behavior, movement/hazard rules, tests and actual totals, manual result, deferred work, changed files, commit/PR, and remaining risks.
```

