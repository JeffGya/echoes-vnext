# Echoes vNext Project Systems Audit

Date: 2026-06-20

## Purpose

This report audits the live project as implemented in the repo today, with a specific focus on:

- what systems exist
- what each system currently does
- where systems duplicate data or responsibility
- where systems should connect more tightly but do not
- which existing unfinished Notion stories best address the gaps

This is an implementation-aware audit, not a pure GDD reading. It synthesizes code inspection, the current docs, the active integration map, and a delegated multi-agent analysis pass.

## Scope And Sources

Primary repo sources:

- [core/](../core)
- [ui/](../ui)
- [data/](../data)
- [docs/integration-map.md](../docs/integration-map.md)
- [docs/v2-migration-map.md](../docs/v2-migration-map.md)
- [docs/Echoes vNext V2 Story Backlog d3dc9cb421e944fc9229238474907ed6_all.csv](../docs/Echoes%20vNext%20V2%20Story%20Backlog%20d3dc9cb421e944fc9229238474907ed6_all.csv)

Backlog-mapping rule used in this report:

- only existing Notion stories are referenced
- stories already marked `Done` in the repo-facing tracker are excluded
- stories marked `Superseded` in backlog export are excluded
- duplicate backlog rows for already-shipped stories are excluded

## Executive Summary

Echoes vNext already has a strong deterministic backbone. The project is not missing systems. It is missing tighter ownership boundaries between systems that already exist.

The main pattern across the codebase is:

- one concept often has two or three live representations
- one workflow often has two or three places that are allowed to mutate or rebuild it
- UI frequently surfaces only part of a system, so the player cannot feel the whole loop

The result is not chaos, but softness:

- the systems do connect
- they often connect through `FlowRuntime`
- they do not yet connect through enough reusable domain seams

The highest-value work is therefore not adding more systems first. It is reducing duplicate representations of:

- snapshots
- directives
- emotion
- progression vocabulary
- echo identity
- sanctum assignment/location
- stage meaning

## System Inventory

### 1. Runtime And Flow

Function:

- `FlowRuntime` is the effective application layer and dispatch choke point.
- `FlowContext`, `FlowStateMachine`, `FlowStateIds`, and flow states carry transient state and snapshot generation.

Main files:

- [core/runtime/FlowRuntime.gd](../core/runtime/FlowRuntime.gd)
- [core/state/flow/FlowContext.gd](../core/state/flow/FlowContext.gd)
- [core/state/flow/FlowStateMachine.gd](../core/state/flow/FlowStateMachine.gd)

Analysis:

- This is the strongest integration seam in the project.
- It is also the largest concentration of responsibility.
- `FlowRuntime` currently owns too much domain behavior directly: onboarding, combat, stage traversal, vow handling, snapshot refreshes, save flushing, and many per-system mutations.

Opportunity:

- keep `dispatch()` as the only mutation entry
- split internal orchestration into narrower coordinators without breaking the choke-point rule

### 2. Save, Schema, And Migration

Function:

- `SaveSchema` defines defaults
- `SaveService` loads, repairs, validates, migrates, and writes save data

Main files:

- [core/save/SaveSchema.gd](../core/save/SaveSchema.gd)
- [core/save/SaveService.gd](../core/save/SaveService.gd)

Analysis:

- Save migration is robust and additive.
- Save repair now performs a large amount of domain-specific normalization.
- This makes persistence tightly coupled to progression, sanctum, realms, onboarding, and combat data.

Opportunity:

- move domain-specific repair logic into dedicated migrators or repair helpers
- keep `SaveService` focused on IO, schema, and migration orchestration

### 3. Config, Data, And Determinism

Function:

- `ConfigService`, `ConfigValidator`, and `JsonFileLoader` load static config
- `CampaignSeed` provides deterministic RNG derivation

Main files:

- [core/config/ConfigService.gd](../core/config/ConfigService.gd)
- [core/config/ConfigValidator.gd](../core/config/ConfigValidator.gd)
- [core/CampaignSeed.gd](../core/CampaignSeed.gd)

Analysis:

- Determinism is one of the healthiest foundations in the repo.
- Config validation is still shallow compared with how many systems depend on config shape.
- seed compatibility still carries both `seed_root` and legacy `root_seed`.

Opportunity:

- make semantic validation more systematic per domain
- finish consolidating seed terminology around one canonical root

### 4. Onboarding

Function:

- `OnboardingService` and `KeeperIntroService` manage Chapter I and Keeper intro progression

Main files:

- [core/onboarding/OnboardingService.gd](../core/onboarding/OnboardingService.gd)
- [core/onboarding/KeeperIntroService.gd](../core/onboarding/KeeperIntroService.gd)

Analysis:

- Onboarding logic exists and works as a separate domain.
- Data-shape ownership overlaps with `SaveService`.
- some read-like calls still ensure and mutate structure.

Opportunity:

- choose one canonical owner for onboarding data repair

### 5. Economy

Function:

- Ase/Ekwan mutation, offline recovery, and reward calculation

Main files:

- [core/economy/EconomyService.gd](../core/economy/EconomyService.gd)
- [core/economy/EconomyAccrualService.gd](../core/economy/EconomyAccrualService.gd)
- [core/economy/RewardCalc.gd](../core/economy/RewardCalc.gd)

Analysis:

- Economy is more integrated than it first appears.
- It already touches summoning, skills, institutions, vows, resolve, and stage rewards.
- The weak point is not missing hooks. It is that offline and passive recovery are still flatter than the house-state fiction now implies.

Opportunity:

- bind passive recovery more tightly to pulse, flame state, and house condition

### 6. Summoning, Roster, And Sanctum Core

Function:

- deterministic echo generation
- roster and party access
- sanctum data wrappers

Main files:

- [core/sanctum/SummonService.gd](../core/sanctum/SummonService.gd)
- [core/sanctum/EchoFactory.gd](../core/sanctum/EchoFactory.gd)
- [core/sanctum/SanctumService.gd](../core/sanctum/SanctumService.gd)
- [core/sanctum/SanctumState.gd](../core/sanctum/SanctumState.gd)

Analysis:

- The generation and summon rails are solid.
- `SanctumService` and `SanctumState` are not yet true choke points.
- large parts of the code still edit `save_data["sanctum"]` directly.
- V2-STAGE-004 Phase 4 added a **second roster-mint path**: `core/sanctum/RecruitmentService.gd` (`promote_ally_to_echo()`) mints a roster echo from a battle-surviving `temporary_ally` contact, deliberately bypassing `EchoFactory` (whose RNG draw order is immutable and whose birth flow assumes a paid summon, not an earned companion). The new echo carries `origin: "recruited_ally"` and a seeded negative bond debuff against the existing roster. This is a considered exception, not drift — but it is now a second place that knows how to construct a valid roster echo dict, worth tracking if a third minting path is ever proposed.

Opportunity:

- either promote a real Sanctum API for roster, party, assignments, and institution occupancy
- or remove wrapper ambiguity and accept direct dict access as the real contract

### 7. Continuity And Institutions

Function:

- continuity value and gating
- institution definitions, unlock state, passive effects, and placement

Main files:

- [core/sanctum/ContinuityService.gd](../core/sanctum/ContinuityService.gd)
- [core/sanctum/InstitutionService.gd](../core/sanctum/InstitutionService.gd)
- [ui/sanctum/SanctumSpatialRenderer.gd](../ui/sanctum/SanctumSpatialRenderer.gd)

Analysis:

- This is a promising reusable system family.
- Continuity, institution state, spatial presence, and passive effects are all present.
- The system is ahead in data modeling and behind in readable everyday gameplay expression.

Opportunity:

- unify this through one shared house-state model
- then let pulse, incidents, jobs, and warnings read it consistently

### 8. Bonds And Vows

Function:

- social graph and bond effects
- vow tracking, compliance, breaks, and visible run pressure

Main files:

- [core/sanctum/SocialGraphService.gd](../core/sanctum/SocialGraphService.gd)
- [core/sanctum/VowService.gd](../core/sanctum/VowService.gd)

Analysis:

- Both systems are genuinely connected into gameplay, not just stored as flavor.
- Bonds already affect combat and aftermath.
- Vows already affect stage play and resolve.
- The next gap is scaling them from reactive modifiers into house systems.

Opportunity:

- connect them to incidents, jobs, pulse, and longer-run social memory

### 9. Progression, Calling, Skills, And Recognition

Function:

- storyweight/rank/level progression rail
- confirmed calling
- skill data and unlocks
- maturity-expression and future recognition/autonomy seams

Main files:

- [core/progression/ProgressionService.gd](../core/progression/ProgressionService.gd)
- [core/progression/CallingService.gd](../core/progression/CallingService.gd)
- [core/progression/SkillDefinition.gd](../core/progression/SkillDefinition.gd)
- [core/actors/MaturityExpressionService.gd](../core/actors/MaturityExpressionService.gd)

Analysis:

- This is one of the most duplicated areas in the project.
- V1/V2 alias fields still coexist as live runtime concepts in places.
- confirmed calling exists, but identity consumption is still inconsistent across systems.
- skill model and skill UI are not fully aligned on one data contract.

Opportunity:

- make progression aliases save-compatibility only
- add one shared identity resolver for effective calling, virtue alignment, and role

### 10. Threads And Weaving

Function:

- thread reserve
- realm recovery segments
- weaving rite selection and outcomes

Main files:

- [core/progression/ThreadService.gd](../core/progression/ThreadService.gd)
- [core/progression/WeavingRiteService.gd](../core/progression/WeavingRiteService.gd)

Analysis:

- The thread and rite loop exists.
- The main weakness is incomplete pressure.
- reserve cap is surfaced but not fully enforced as a meaningful system constraint.
- stored weave history is not yet strongly reused in later rite scoring.

Opportunity:

- turn thread reserve from display state into real pressure
- turn weave memory from stored metadata into future decision weight

### 11. Realms, Stages, Directives, And Intel

Function:

- realm generation and progression
- stage persistence and exploration
- objective taxonomy
- situation routing
- directives and intel

Main files:

- [core/realms/RealmService.gd](../core/realms/RealmService.gd)
- [core/realms/RealmGenerator.gd](../core/realms/RealmGenerator.gd)
- [core/realms/SituationResolutionService.gd](../core/realms/SituationResolutionService.gd)
- [core/directives/DirectiveService.gd](../core/directives/DirectiveService.gd)

Analysis:

- Realm exploration is one of the most complete end-to-end loops in the codebase.
- V2-STAGE-004 Phase 5 (2026-07-09) tightened two traversal edges: **frontier chaining** (tier-3 frontier targets lift fog per step and re-target `nearest_unexplored` until `step_budget` is spent, so an advance now binds to the directive budget instead of stopping ~`reveal_radius`+1 tiles out) and **mid-path stop** (stepping onto an unresolved, un-passed situation parks the party for resolution — walking onto a situation always triggers the resolution flow). Pass/resolved invariants preserved.
- V2-STAGE-004 Phase 4 (final phase — story now fully Done) closed the last gap between `ConversationService`/`SituationResolutionService` (STAGE-003) and combat: a good `temporary_ally` conversation outcome now auto-joins the next fight (`ContactActorBuilder`), a failed Claimant routes straight into real combat, and a failed non-objective Charge leaves a one-time pressure marker consumed by the next PROTECT/ENDURE encounter. A pre-existing Phase 3c soft-lock was folded in and fixed: `guide_spirit` was missing from `SituationResolutionService._ASYNC_OBJ_TYPES`, so a guide_spirit OBJECTIVE fell through to flavor text and never completed. Directive state and intel remain the two live seams called out below — Phase 4 did not touch either.
- V2-COMBAT-002 Slice 5 (2026-07-21) corrected a convention seam in traversal: a traveled path now holds **destinations only** and excludes the cell departed from, matching the movement contracts' path-excludes-origin rule. The pre-move cell is carried by the new additive `traveled_origin` / `last_traveled_origin` fields; on-screen animation, ghost trail, and step-diamond count are unchanged, and the save change is additive. Live exploration **routing** is deliberately untouched — the dormant `StagePartyMovementAdapter` holds the corrected edge and tie-break rules until the Slice-6 cutover, so `StageTerrain.nearest_unexplored` / `next_step` and `FlowRuntime._find_explore_target` tiers 1–2 still carry their known directional bias. See `docs/integration-map.md` for the Slice-6 carry-forward list.
- The biggest live seam is directive state split between canonical and legacy paths.
- intel exists, but cost, aftermath, and multi-channel acquisition are still underdeveloped.
- stage summary meaning and actual objective meaning still partially diverge.

Opportunity:

- make directives truly single-source
- deepen intel as a costful and multi-channel system
- unify stage meaning around objective truth

### 12. Actors, Identity, And Behavior

Function:

- actor schemas and construction
- behavior arbitration
- maturity-expression
- vector identity

Main files:

- [core/actors/ActorSchema.gd](../core/actors/ActorSchema.gd)
- [core/actors/EchoActor.gd](../core/actors/EchoActor.gd)
- [core/actors/ActorStateMachine.gd](../core/actors/ActorStateMachine.gd)
- [core/actors/behaviors/BehaviorArbiter.gd](../core/actors/behaviors/BehaviorArbiter.gd)
- [core/actors/VectorService.gd](../core/actors/VectorService.gd)

Analysis:

- The actor stack is strong, but the same echo identity is still interpreted differently by placement, readiness, behavior, and conversation.
- this weakens the sense that an Echo is one coherent being across systems.

Opportunity:

- create shared helpers for effective identity resolution instead of subsystem-specific fallbacks

### 13. Emotion And Recovery

Function:

- persistent echo emotion
- recovery over time
- player-facing emotional status

Main files:

- [core/emotion/EmotionService.gd](../core/emotion/EmotionService.gd)
- [core/emotion/EmotionRecoveryService.gd](../core/emotion/EmotionRecoveryService.gd)

Analysis:

- Emotion is one of the most central systems in the game fantasy.
- It is also one of the clearest duplicate-data seams.
- save echoes use `emotion.*`
- combat actors use top-level `morale` and `fear`
- combat mutates one and syncs back later

Opportunity:

- reduce emotion to one authoritative representation plus projection helpers
- then route exploration, sanctum, and combat pressure through that same readable model

### 14. Combat, Objectives, Grid, And Terrain

Function:

- combat loop
- objective-specific encounter logic
- retreat and shrine logic
- grid placement and movement
- terrain-aware boards

Main files:

- [core/combat/CombatState.gd](../core/combat/CombatState.gd)
- [core/combat/CombatService.gd](../core/combat/CombatService.gd)
- [core/grid/GridService.gd](../core/grid/GridService.gd)
- [core/realms/StageTerrain.gd](../core/realms/StageTerrain.gd)

Analysis:

- The board and objective foundation is strong.
- As of V2-STAGE-004 Phase 3c (2026-07-05) all seven combat modes (COMBAT / PURIFY_SHRINE / RECOVER / PROTECT / ENDURE / PURSUE / GUIDE_SPIRIT) have live per-mode win/lose conditions, distinct objective-actor behavior, and mode-specific echo-autonomy biasing — the objective now drives outcome per mode rather than every stage collapsing to "kill the nearest enemy". See `docs/combat-modes.md` and `CONVENTIONS.md` § Combat resolution modes & boards.
- As of V2-STAGE-004 Phase 5 (2026-07-09) the combat board reads its per-mode objective through an authored `ObjectiveBanner` (7 per-mode layouts) with de-overlapped top chrome and a contrast-fixed cream/gold palette — the mode is now legible on-screen, not just in the model. See `CombatBoardScreen` below and `CONVENTIONS.md` § Per-Screen Snapshot Summaries.
- As of V2-STAGE-004 Phase 4 (2026-07-15, final phase — story now fully Done) the combat and progression stack gained two new integration seams: a `temporary_ally` NPC contact can auto-join the next fight as a full echo-faction combatant (`ContactActorBuilder`, excluded from `all_echoes_dead` the same way a joined GUIDE_SPIRIT is), and `EncounterContext.echo_action_logs` is now a general Tier-1 contribution ledger (`damage_dealt`/`damage_taken`/`kills`) across **all** factions, not just echoes — `ProgressionService` reads it byte-identically via keyed lookup. This is the first system to read combat outcomes for a purpose *other* than XP: `RecruitmentService.compute_recruit_chance()` blends the ledger's combat component with a conversation-quality score and a party-fit score to gate a post-victory "Earned Return" companion invite.
- V2-COMBAT-002 is building the shared movement layer underneath this in dormant slices (1–5 accepted): contracts and weighted paths, pressure/route arbitration, profile derivation plus a shared executor and hazards, the special PURSUE/GUIDE/PROTECT mechanics, and now a stage-party adapter that expresses exploration traversal in the same contract vocabulary as combat — one party token, not per-Echo. Nothing is wired into live combat yet; the live cutover is Slice 6. Movement rules that today exist in four different shapes (combat `GridService`, exploration `StageTerrain`, escape checks, spirit/carrier pacing) converge there.
- The next gap is battlefield meaning: enemies still need richer pressure roles (V2-COMBAT-002), and stage context should drive more enemy behavior. Tier-2 support-attribution (guard/heal/utility contribution, not just damage) remains a deferred follow-up to the new ledger.

Opportunity:

- make combat feel less like one generic skirmish engine wearing different labels

### 15. UI, Shells, Screens, And Components

Function:

- snapshot routing
- shell-owned shared chrome
- sanctum, venture, onboarding, and combat screens
- reusable UI components

Main files:

- [ui/AppRoot.gd](../ui/AppRoot.gd)
- [ui/shells/SanctumShell.gd](../ui/shells/SanctumShell.gd)
- [ui/shells/RealmShell.gd](../ui/shells/RealmShell.gd)
- [ui/UISnapshotRenderer.gd](../ui/UISnapshotRenderer.gd)

Analysis:

- The shell model is one of the best reuse patterns in the repo.
- The biggest weak points are:
- `StageExploreScreen` carrying too many jobs — V2-STAGE-004 Phase 5 extracted several presentation concerns into dedicated venture components (`StepProgressBar`, `DirectiveBadge`, `GhostFootprintLayer`), but the screen still owns board/fog/situation/travel-beat orchestration
- fragmented echo presentation across screens
- script-built sanctum UI pieces that should be scene components
- legacy fallback renderer still expecting Array actions

Opportunity:

- strengthen reusable presenters and shrink overgrown screens

## Cross-Cutting Duplication And Soft Seams

### A. Snapshot Ownership Is Split

Current split:

- flow states build snapshots
- `FlowStateMachine` validates and mutates some snapshots
- `FlowRuntime` also rebuilds and edits snapshots directly

Main files:

- [core/state/flow/FlowStateMachine.gd](../core/state/flow/FlowStateMachine.gd)
- [core/runtime/FlowRuntime.gd](../core/runtime/FlowRuntime.gd)

Why it matters:

- one UI truth should have one builder
- current state makes snapshot bugs and drift more likely

### B. Directive State Is Split

Current split:

- canonical `stage_context.active_directive_id`
- legacy `flow.active_directive` reads still exist

Main files:

- [core/directives/DirectiveService.gd](../core/directives/DirectiveService.gd)
- [core/runtime/FlowRuntime.gd](../core/runtime/FlowRuntime.gd)

Why it matters:

- exploration, contact, and encounter handoff can reason from different directive state

### C. Emotion Has Two Live Models

Current split:

- save echo `emotion.{morale_current,fear_current}`
- combat actor top-level `morale` and `fear`

Main files:

- [core/emotion/EmotionService.gd](../core/emotion/EmotionService.gd)
- [core/actors/EchoActor.gd](../core/actors/EchoActor.gd)
- [core/state/flow/states/venture/FlowEncounterState.gd](../core/state/flow/states/venture/FlowEncounterState.gd)

Why it matters:

- the same emotional truth is duplicated at the exact moment it matters most

### D. Progression Still Has Active Alias Drift

Current split:

- `xp_total` and `storyweight`
- `rank` and `standing`
- `level` and `step`

Main files:

- [core/save/SaveService.gd](../core/save/SaveService.gd)
- [core/progression/ProgressionService.gd](../core/progression/ProgressionService.gd)

Why it matters:

- some paths update both, some update only legacy values

### E. Skill Model Is Not Single-Source

Current split:

- `SkillDefinition` is family-based
- some UI logic still assumes older per-calling requirement shape

Main files:

- [core/progression/SkillDefinition.gd](../core/progression/SkillDefinition.gd)
- [core/state/flow/states/sanctum/FlowEchoPartyState.gd](../core/state/flow/states/sanctum/FlowEchoPartyState.gd)

Why it matters:

- unlock logic and display logic can diverge

### F. Echo Identity Is Consumed Inconsistently

Current split:

- placement, readiness, behavior, and conversation use different identity fallbacks

Main files:

- [core/grid/GridService.gd](../core/grid/GridService.gd)
- [core/combat/CombatState.gd](../core/combat/CombatState.gd)
- [core/actors/behaviors/BehaviorArbiter.gd](../core/actors/behaviors/BehaviorArbiter.gd)
- [core/realms/ConversationService.gd](../core/realms/ConversationService.gd)

Why it matters:

- one echo can feel like a different person in different systems

### G. Stage Meaning Is Duplicated

Current split:

- `stage.type` is summary-facing
- `objective.type` drives actual encounter behavior

Main files:

- [core/realms/StageModel.gd](../core/realms/StageModel.gd)
- [core/realms/ObjectiveModel.gd](../core/realms/ObjectiveModel.gd)

Why it matters:

- the player-facing stage identity can drift from actual runtime intent

### H. Sanctum Assignment/Location Is Represented Indirectly

Current split:

- party membership
- institution occupants
- inferred roaming / not-assigned state

Main files:

- [core/sanctum/InstitutionService.gd](../core/sanctum/InstitutionService.gd)
- [core/sanctum/SanctumService.gd](../core/sanctum/SanctumService.gd)

Why it matters:

- one conceptual question, “where does this Echo belong right now?”, is answered indirectly

### I. UI Reuse Is Uneven

Current split:

- shell-level reuse is strong
- screen-level presentation reuse is inconsistent

Main files:

- [ui/screens/venture/StageExploreScreen.gd](../ui/screens/venture/StageExploreScreen.gd)
- [ui/screens/sanctum/SanctumScreen.gd](../ui/screens/sanctum/SanctumScreen.gd)
- [ui/components/EchoCardItem.gd](../ui/components/EchoCardItem.gd)
- [ui/UISnapshotRenderer.gd](../ui/UISnapshotRenderer.gd)

Why it matters:

- implemented systems do not always read as one family of reusable surfaces

## Missed Connections And Opportunities

### 1. House-State Backbone

The strongest missing connection is a single shared house-state layer tying together:

- pulse
- continuity
- institutions
- passive recovery
- incidents
- jobs
- return-to-sanctum consequence display

The project has most of these pieces. They are just not yet tied through one dominant backbone.

### 2. Costful Information Game

The second strongest opportunity is to make information gain a true loop:

- directives shape risk appetite
- scouting and withdrawal preserve knowledge
- intel carries cost and aftermath
- stage persistence remembers that knowledge
- sanctum return reflects what that knowledge cost

Right now the game already has intel persistence. The missing layer is sacrifice and readable consequence.

### 3. One Echo, One Identity

The project needs a stronger shared rule for:

- who this Echo is
- how that identity changes action
- how that identity is displayed

This should bind:

- calling
- vectors
- maturity-expression
- role pressure
- dialogue interpretation

### 4. Weave Pressure

Threads and rites exist, but their pressure is still softer than the rest of the game’s intended identity:

- reserve pressure is weak
- weave memory is stored but underused
- contested fallout is still light as a long-run shaping force

### 5. Readable Living House

Sanctum already has continuity, institutions, vows, bonds, and voice.
What it lacks is a stronger sense of daily consequence:

- why this house feels healthy or strained
- why this Echo is stationed here
- why this incident surfaced now

## Priority Map Against Existing Unfinished Notion Stories

This section maps the audit to existing unfinished backlog stories only.

Excluded on purpose:

- any story marked done in [docs/integration-map.md](../docs/integration-map.md)
- any story marked `Superseded` in the synced backlog CSV
- duplicate backlog rows for shipped work

### P0

These are the highest-value stories for tightening the project into a more reusable and coherent system.

1. `V2-SANCTUM-004` — Sanctum pulse as shared house-state runtime
Pickup order: `1`
Why:
- best match for the missing backbone between continuity, institutions, recovery, warnings, and consequence
- directly addresses the “many systems, weak shared house model” problem
Backlog source:
- `Ready` in synced CSV

2. `V2-INTEL-002` — scouting sacrifice and failed-run ripple
Pickup order: `2`
Why:
- converts intel from persistence-only into a real costful system
- ties realms back into sanctum consequence more tightly
Backlog source:
- `Ready` in synced CSV

3. `V2-DIRECTIVE-002` — directives vary by Echo profile
Pickup order: `3`
Why:
- directly addresses directive flattening and identity drift
- gives the existing directive system a stronger reusable role across traversal and behavior
Backlog source:
- `Ready` in synced CSV

4. `V2-COMBAT-002` — enemy pressure roles and stage-context combat behavior
Pickup order: `4`
Why:
- best match for the current “generic skirmish engine” softness
- tightens stage meaning, enemy identity, and objective pressure into one combat language
Backlog source:
- `Ready` in synced CSV

5. `V2-ECONOMY-002` — Ase Flame and house-conditioned recovery rules
Pickup order: `5`
Why:
- closes the gap between economy fiction and runtime behavior
- lets passive recovery participate in the same house-state model as pulse and institutions
Backlog source:
- `Ready` in synced CSV

### P1

These stories should follow once the P0 seams are in place.

1. `V2-SANCTUM-005` — incidents and routine framework
Pickup order: `6`
Why:
- turns pulse, bonds, vows, institutions, and realm aftermath into visible daily house life
- best next step for making the Sanctum feel alive instead of only connected in backend terms

2. `V2-SANCTUM-006` — assignable jobs and office logic
Pickup order: `7`
Why:
- resolves the soft assignment/location seam
- gives institutions, pulse, and party management a stronger shared data contract

3. `V2-WEAVE-003` — thread reserve cap, expansion cadence, and overflow UX
Pickup order: `8`
Why:
- turns thread reserve into a real pressure system instead of a display-only one
- closes the current reserve-cap gap between UI and runtime

4. `V2-PROG-012` — autonomy ladder weighting and threshold rules
Pickup order: `9`
Why:
- best match for the current fragmented identity and refusal logic
- gives maturity-expression, emotion, and obedience one clearer tuning seam

5. `V2-STAGE-101` — fuller stage-ecology population layer
Pickup order: `10`
Why:
- deepens exploration from “persistent node chain” into a richer ecology
- supports stronger links between intel, roaming pressure, and objective-linked reveals

6. `V2-INTEL-101` — alternate intel channels
Pickup order: `11`
Why:
- stops scouting from becoming the only meaningful discovery path
- strengthens omen/contact/aftermath as first-class information systems

7. `V2-INFRA-006` — implementation-facing content definitions and surfacing language
Pickup order: `12`
Why:
- needed once incidents, rites, support states, and stage contacts start scaling
- helps prevent future ad hoc system growth

### P2

These are worthwhile, but they depend on the tighter foundation above.

1. `V2-SANCTUM-003` — first institution anchors as a living-house step
Pickup order: `13`
Why:
- useful for deeper house presence, but stronger once pulse, jobs, and incident systems are in place

2. `V2-CONTINUITY-002` — recognition scaffolding
Pickup order: `14`
Why:
- good long-run progression seam
- lower immediate impact than pulse, jobs, and weave pressure

3. `V2-PROG-011` — mythic recognition scaffold
Pickup order: `15`
Why:
- related to recognition and person-shaping depth
- lower immediate coherence payoff than fixing identity usage and house-state integration

4. `V2-WEAVE-005` — contested non-chosen fallout bands
Pickup order: `16`
Why:
- deepens rite consequence after reserve pressure and shared house consequence are stronger

5. `V2-VOICE-002` — deeper social voice and disagreement
Pickup order: `17`
Why:
- voice is already useful as interpretation
- should scale after the underlying house and identity systems are tighter

## Recommended Ordering

If the goal is system cohesion rather than surface breadth, the best sequence from the current state is:

1. `V2-SANCTUM-004`
2. `V2-INTEL-002`
3. `V2-DIRECTIVE-002`
4. `V2-COMBAT-002`
5. `V2-ECONOMY-002`
6. `V2-SANCTUM-005`
7. `V2-SANCTUM-006`
8. `V2-WEAVE-003`

That sequence tightens:

- house state
- information cost
- directive identity
- combat pressure meaning
- passive recovery
- daily house consequence
- assignment ownership
- weave pressure

before moving into broader expansion systems.

## Final Assessment

Echoes vNext already has enough separate systems to support its intended identity.
The next phase should not be “add more isolated mechanics.”

The next phase should be:

- reduce duplicate representations
- strengthen single-source domain seams
- surface house consequence more clearly
- make information and identity travel coherently across sanctum, realm, combat, and resolve

If that work lands well, the project will stop feeling like many good systems living beside each other and start feeling like one reusable game ecology.

## Story-Agnostic Priority Map

This section intentionally ignores story boundaries and names the most critical pickups purely by system urgency.

### P0

1. House-state backbone
Why:
- pulse, continuity, institutions, passive recovery, incidents, and return consequences need one dominant shared model
- this is the single biggest missing reusable seam in the project

2. Directive single-source truth
Why:
- directive state is still split across canonical and legacy paths
- this risks traversal, contact, and encounter systems reading different intent

3. Emotion single-source truth
Why:
- save emotion and combat emotion are still duplicated representations
- emotion is too central to remain split across persistence and runtime actor projections

4. `FlowRuntime` responsibility reduction
Why:
- it currently acts as the application layer for most of the game
- this is the main coupling hotspot across otherwise solid systems

5. Canonical progression and identity model
Why:
- progression aliases and mixed identity fallbacks weaken cohesion across combat, sanctum, progression, and UI
- one Echo should read as one coherent being in all systems

### P1

1. Sanctum as a living system
Why:
- incidents, jobs, warnings, and visible house consequence are the biggest missing bridge between backend systems and player experience

2. Costful intel loop
Why:
- stage persistence exists, but intel still needs sacrifice, aftermath, and multi-channel acquisition to become a full loop

3. Context-sensitive combat
Why:
- combat foundation is strong, but enemy pressure roles and objective-driven behavior still feel too generic

4. Real weave pressure
Why:
- thread reserve, overflow, weave memory, and contested fallout are still softer than the rest of the project's intended pressure systems

5. Screen and component consolidation
Why:
- UI fragmentation makes connected systems feel disconnected
- this is especially visible in Sanctum surfaces and `StageExploreScreen`

### P2

1. Long-run social simulation depth
Why:
- bonds, rumor spread, reconciliation, and wider house politics matter, but they depend on stronger house-state foundations first

2. Recognition and mythic scaffolding depth
Why:
- important later, but not the current structural bottleneck

3. Realm ecology breadth and content variety
Why:
- breadth should come after core seams stop duplicating truth

## Immediate Pickup Order

If the question is simply what must be picked up immediately, independent of story shape, the order is:

1. House-state backbone
2. Directive single-source truth
3. Emotion single-source truth
4. `FlowRuntime` responsibility reduction
5. Canonical progression and identity model

This is the work that will make the project tighter instead of merely larger.
