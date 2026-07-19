# Echoes vNext — Project Memory

## What This Is
Godot 4.6.1 mythic house-and-trials strategy game. Deterministic core simulation + snapshot-driven UI.
Player is the Ase Keeper who runs a Sanctum, summons Echoes (returning names / fragments of stolen stories), and leads them through Realm trials to recover Threads and bring stolen stories home.

## Architecture at a Glance
- **Core** (`core/`): Deterministic sim. No UI deps. Outputs snapshots + logs.
- **UI** (`ui/`): Renders snapshots. Dispatches actions. Never touches sim state directly.
- **Data** (`data/`): JSON configs (balance, actors, realms). Read-only inputs.
- **Tests** (`tests/`): Lightweight, deterministic. Run via Debug Panel `tests` command.

## Key Architectural Decisions
- Single campaign seed root → all RNG via `CampaignSeed.derive("dot.separated.path")`
- `FlowRuntime.dispatch(action)` is the single choke point (tick, logger, save, snapshot)
- Snapshot shape: `{ type, meta, data, actions }` — only source of truth for UI
- `snapshot.actions` is a **slot-keyed Dictionary** (not Array). Per-row actions dispatched by rows, never in snapshot.actions.
- AppRoot remains the application composition root and owns responsive coordination plus the single layer-40 blocking `ModalHost`.
- UI layers: spatial 0, screen 10, persistent chrome 20, non-modal transient 30, blocking modal 40, recovery/debug 128.
- Window policy: 1280×720 landscape base, 1600×900 initial desktop, 960×540 minimum, resizable/HiDPI, `canvas_items` + fractional `expand`.
- Responsive layouts recompose at compact/standard/wide profiles. UI scale is capped; wide-window surplus expands spatial presentation rather than panels and controls.
- Logical safe insets are converted from the OS safe-area rect through the inverse stretch transform. Screens reserve safe edges and persistent bottom chrome.
- Save: crash-safe (write `.tmp` → rename), additive repairs, schema_version 1
- Economy: settlement model (not frame-based); offline decay applied once per session on Continue
- One save slot forever. Save triggers: new game, summon, realm select, stage enter, resolve, name confirm, party confirm

## V2 Migration State (Alignment Wave — started 2026-04-06)

The repo is migrating from V1 idioms to V2 canonical design. **V2-MIG-001 is Done.**

**Migration map:** `docs/v2-migration-map.md` — read this before starting any Alignment story.

**V2 terminology is canonical for all new work:**
- `Storyweight` / `Standing` / `Step` — not `xp_total` / `rank` / `level`
- 10 virtue domains (Courage, Wisdom, Leadership, Acceptance, Humility, Forgiveness, Truth, Generosity, Compassion, Empathy) — not the 4 legacy vectors
- `Scout Carefully` / `Seek Signs` — not `directive.scout` / `directive.none`
- Calling milestones at Standing 3 / 6 / 9 — not rank 3 gate

**V1 internal aliases still in save data** (`rank`, `level`, `xp_total`, old vector keys) — these persist as compatibility fields until V2-MIG-002 (save bridge) ships. Do not delete them; add V2 keys additively alongside.

**Alignment wave pickup order:**
1. V2-MIG-002 — Save schema bridge (additive V2 roots + repair) ✓ Done
2. V2-PROG-001 — Progression language rename ✓ Done
3. V2-PROG-002 — Calling seam unification ✓ Done
4. V2-PROG-003 — Vector expansion (4 → 10 virtue domains)
5. V2-DIRECTIVE-001 — Directive rewrite (Scout Carefully / Seek Signs)
6. V2-SANCTUM-001+ — Building + Continuity system
7. V2-ECONOMY-001+ — Economy expansion

---

## Available Skills
Four project-specific skills are installed. Use them proactively — they are authoritative.

- **`godot-echoes-dev`** — Godot 4.6.1 + GDScript dev patterns: architectural invariants, flow state IDs, all action types, naming conventions, checklists for adding new states/services/tests. **Use for any implementation question.**
- **`echoes-sankofa-gdd`** — V2 GDD navigator: design pillars, glossary, callings (S3/S6/S9), skill families, vectors, Weave system, Threads, Storyweight, Continuity. **Use for design decisions, feature scope, lore questions.**
- **`echoes-backlog`** — V2 story backlog (168 stories) via CSV + Notion MCP. **Use to look up stories, pickup order, wave, status.**
- **`game-ui-ux-echoes`** — Mobile-first UI/UX patterns: snapshot-to-screen mapping, touch targets, screen inventory, West African aesthetic. **Use for new screens, layout decisions.**

---

## Systems Inventory

| System | File | Purpose / Key Interface |
|--------|------|------------------------|
| CampaignSeed | `core/CampaignSeed.gd` | Seeded RNG root. `derive(path)` → RNG. Stored in save. Never regenerated. |
| StructuredLogger | `core/log/StructuredLogger.gd` | `info/debug(t, type, msg, data)`. `t` always injected. No OS time. |
| FlowRuntime | `core/runtime/FlowRuntime.gd` | Single dispatch choke. `dispatch(action)`, `boot()`. All saves via `save_request` flag. |
| FlowContext | `core/state/flow/FlowContext.gd` | Runtime state: sim_tick, last_snapshot, pending_party_ids, selected_summon_grade, encounter_ctx, encounter_machine, encounter_id, save_data, save_request, logger, dev_combat_objective. |
| FlowStateMachine | `core/state/flow/FlowStateMachine.gd` | 10 flow states. `refresh_snapshot()` for mid-state updates. `_rebuild_snapshot()` enriches SANCTUM. |
| FlowStateIds | `core/state/flow/FlowStateIds.gd` | 10 canonical state ID constants. |
| FlowSanctumState | `core/state/flow/states/sanctum/FlowSanctumState.gd` | Slot-keyed dict. `cta.enter_stage` always present with `disabled` flag. |
| FlowSummonState | `core/state/flow/states/sanctum/FlowSummonState.gd` | Static `build_snapshot()`. Grade defaults to "uncalled" on `enter()`. |
| FlowPartyManageState | `core/state/flow/states/sanctum/FlowPartyManageState.gd` | Static `build_snapshot()`. Pending toggle, max-cap=5, confirm→save. |
| FlowEncounterState | `core/state/flow/states/venture/FlowEncounterState.gd` | `build_round_snapshot()` + `build_final_snapshot()`. Combat actors project `emotional_status` only; raw/legacy emotion fields are stripped and operational `status` is alive/dead/guarding. Final combat fear/morale is copied back to the roster before resolve routing. |
| EncounterContext | `core/state/encounter/EncounterContext.gd` | actors, placement_seed, combat_state, initiative_cfg, last_round_results, combat_result, purifier_id, last_round_snapshot, final_snapshot. |
| EchoFactory | `core/sanctum/EchoFactory.gd` | Deterministic echo gen. RNG draw order v1 **IMMUTABLE**: rarity→calling_origin→gender→name→traits→archetype_birth→derived_stats. |
| SanctumService | `core/sanctum/SanctumService.gd` | `get_party_actors()` + `get_roster_actors()` → read-only actor dicts. |
| SummonService | `core/sanctum/SummonService.gd` | `summon_paid_one()` / `summon_paid_many()`. Transactional (settle→validate→spend→generate→save). |
| EconomyService | `core/economy/EconomyService.gd` | `spend_ase()`, `add_ase()`, `can_afford_ase()`, `get_ase()`. Single choke for Ase mutations. |
| SaveService + Schema | `core/save/` | Transactional verified tmp + three rotating backups. Highest-generation recovery, corrupt-primary archive, additive repair after validation. Runtime save path is injectable for test isolation. |
| ConfigService | `core/config/ConfigService.gd` | Loads `data/balance.json`. Read-only. |
| ActorSchema | `core/actors/ActorSchema.gd` | `validate()` checks 18 REQUIRED_FIELDS. `get_defaults()` adds `guard_state:false` (runtime only). |
| EchoActor | `core/actors/EchoActor.gd` | `from_echo(echo)` → deep-copied actor dict. Reads `echo["emotion"]` for morale/fear. |
| EnemyActor | `core/actors/EnemyActor.gd` | `from_definition(defn, t)` → actor dict. Level-scaled via DerivedStatService. |
| StructureActor | `core/actors/StructureActor.gd` | `from_definition(defn)` → actor dict (`is_structure=true`, idle behavior). |
| ActorStateMachine | `core/actors/ActorStateMachine.gd` | `advance_turn()`: death guards → Absolute Fear Rule (fear≥80→refuse) → module dispatch → move resolver. `finalize_combat_bark(is_kill, vk)` called post-resolution for `combat_ko` promotion. `_check_reactive_bark(ctx, t)` fires `combat_rally_ally` for forming+ actors. Bark fields written to `_actor` dict: `_bark_line`, `_bark_context`, `_bark_tier`, `_bark_target_id`, `_bark_is_response`. |
| ShoutBank | `core/echoes/ShoutBank.gd` | Lazy-loading bark line registry. JSON-backed (`data/bark/*.json`). `get_expression_shout(ctx, arch, band, calling, variation_key)` → deterministic line from Array. `variation_key = (t + actor_id_hash) % 997`. (V2-VOICE-001) |
| BarkPopupLayer | `ui/screens/combat/BarkPopupLayer.gd` + `.tscn` | Sequential bark popup queue above actor tokens. Two visual variants (original dark green, reaction warm light with ↩ prefix). `enqueue_barks(Array)` receives pre-sorted interleaved list from CombatBoardScreen. (V2-VOICE-001) |
| MaturityExpressionService | `core/actors/MaturityExpressionService.gd` | `get_expression_band(rank, band_by_standing)` → nascent/forming/grounded/whole. `get_presence_strength(band)` → 0.1/0.25/0.5/1.0. `get_expression(actor, cfg_data)` → full dict. Config: `balance.data.maturity_expression`. (V2-PROG-006) |
| BehaviorArbiter | `core/actors/behaviors/BehaviorArbiter.gd` | Data-driven weighted scoring. `score=(base+trait+vector)×fear_factor+directive`. module_id="arbiter". Reads `expression_band` from context. |
| ActorService | `core/actors/ActorService.gd` | `get_nearest_enemy()` + `get_threatened_ally()`. Filters `is_dead` + `is_structure`. |
| DerivedStatService | `core/actors/DerivedStatService.gd` | Pure static `compute_stats(traits, rank, level, stat_cfg)`. 7 stats incl. speed. |
| VectorService | `core/actors/VectorService.gd` | Tracks `vector_scores` + `dominant_vector`. 3% hysteresis to switch dominant. CLAMP_MAX=1000. |
| EmotionService | `core/emotion/EmotionService.gd` | Emotion mutation choke point outside mid-combat writes. `get_emotional_status(morale, fear)` returns the only player-facing feeling field: radiant → whole → grounded → uncertain → hesitant → burdened → pressed → strained → fraying → hollow. Hidden morale tiers remain simulation-only. |
| EmotionRecoveryService | `core/emotion/EmotionRecoveryService.gd` | Time settlement for roster emotion: +1 morale/min toward base, −0.5 fear/min toward zero, modifiers + maturity bonus, offline decay. Runs on bank/Continue settlement; consumed recovery clock is persisted even when no rounded delta applies. |
| LeadershipEmotionService | `core/combat/LeadershipEmotionService.gd` | Whole-band, radius-aware leadership emotion rules. Living Echo allies only; excludes source/dead/non-Echo/out-of-radius. Overlapping reductions use strongest factor (never multiply); direct positive recovery from separate leaders stacks. |
| EmotionPresentation | `ui/components/EmotionPresentation.gd` + `assets/theme/LivingTreeSystem.tres` | Shared ten-status display names, colors, chip variations, and text variations for every player-facing emotion surface. |
| GridService | `core/grid/GridService.gd` | `place_actors()`, `manhattan_distance()`, `move_toward()` (8-dir greedy). Board 10×10. |
| Movement contracts (V2-COMBAT-002 S1–2) | `core/movement/contracts/` | Strict, deep-copying contracts for context/profile/goal/option/intent/event/result plus Slice 2 action plans, perceived actor facts, known hazard facts, and seven-mode pressure snapshots. Exact-field validation returns stable `{valid, reason, field}` diagnostics; paths exclude origin; complete candidates carry explicit primary actions and declared fallbacks. Capacity remains a dormant 0–6 envelope; no live derivation or behavior switch yet. |
| MovementPathService (V2-COMBAT-002 S1–2) | `core/movement/MovementPathService.gd` | Pure deterministic weighted `shortest_path`, `reachable_cost_region`, and `validate_route`. Positive integer destination-entry costs default to 1; Slice 2 adds validated directed nonnegative edge surcharges. Routes exclude origin; tie policy is geometric then numeric and insertion-order independent. Uses `StageTerrain` as edge authority. |
| CombatPressureService (V2-COMBAT-002 S2) | `core/movement/CombatPressureService.gd` | Dormant perceived-fact adapter for COMBAT, PURIFY_SHRINE, RECOVER, PROTECT, ENDURE, PURSUE, and GUIDE_SPIRIT. Produces at most three fully validated direct/tactical/safety goals with stable IDs and sources; never mutates combat or decides objective, custody, progress, or victory truth. |
| MovementOptionService (V2-COMBAT-002 S2) | `core/movement/MovementOptionService.gd` | Dormant deterministic option generator over the intersection of authoritative walkability and perceived planning cells. Produces at most four distinct direct/safe/cohesive/screen/intercept/conservative route options; hostile control adds directed edge cost while known hazards remain factual summaries only. |
| MovementProfileService (V2-COMBAT-002 S3) | `core/movement/MovementProfileService.gd` | Dormant single source of live movement capacity. `derive_profile(actor, capacity_cfg, options={})`. **FROZEN formula:** `final = clamp(max(standing_capacity, aptitude_capacity), 2, 6)` (a `max()`, not a sum). Standing bands S1–2→2 / S3–5→3 / S6–9-and-above→4 (ceiling 4, S9 no auto-increase); aptitude = `2 + (agi≥12:+1)+(agi≥18:+1)+ Calling kra_soro(+1)+ skill kra_soro_open_ground(+1)` (no Standing term; `sum_okwanfo_shadow_step` deferred). Structures→0; non-joining GUIDE spirit→capacity-1 only via explicit `options.authored_override`. Reads `actor["standing"]`(→`rank`), `stats.agi`, `calling`, `equipped_skills`. No saved `max_movement`; equipment→V2-ITEM-003. |
| MovementHazardService (V2-COMBAT-002 S3) | `core/movement/MovementHazardService.gd` (+ `MovementHazardFixtures.gd`) | Dormant fixed-hazard resolver for `unstable`/`binding`/`burning`. `resolve_cell_entry` + `resolve_end_activation`; once-per-type-per-activation ledger (`{triggered:{unstable,binding,burning}}`). Unstable displacement ranked by outward-progress then angular-deviation (no row/col bias; genuine tie→`fallback_damage`); forced displacement is free and cannot recursively retrigger Unstable. |
| MovementExecutor (V2-COMBAT-002 S3) | `core/movement/MovementExecutor.gd` | Dormant pure edge-by-edge traversal. `execute(context, intent, profile, hazard_ctx)`. Two-solid-corners diagonal via `StageTerrain.is_legal_edge`; dynamic occupancy; once-per-edge hostile-control surcharge (+1, sources sorted); free forced displacement; strictly ordered events. Stop reasons: reached_destination / commitment_spent / capacity_spent / no_route / blocked_edge / occupied / binding_stop. |
| CombatActivationService (V2-COMBAT-002 S3) | `core/movement/CombatActivationService.gd` | Dormant ordered movement-plus-action pipeline. `activate(context, intent, profile, hazard_ctx, action_ctx={})`: executor → action revalidation at final cell → purpose-restricted fallback → declared resolved action (declared, NOT executed) → Burning end-activation → KO/death truth → one validated `MovementResult`. |
| StageTerrain shared movement seam | `core/realms/StageTerrain.gd` | Existing irregular terrain authority plus S1 `is_legal_edge` / `legal_neighbors`: stable 8-direction, optional bounds, walkable source+destination, and diagonal blocked only when both orthogonal side cells are solid. Occupancy is not terrain solidity; empty walkable keeps legacy all-walkable behavior. |
| CombatState | `core/combat/CombatState.gd` | `create()` + `check_end_condition()`. End priority: all_enemies_defeated → shrine_destroyed → all_echoes_dead. |
| CombatService | `core/combat/CombatService.gd` | `resolve_action(type, attacker, defender, round)` → result dict. Melee: guard doubles eff_def. |
| ShrineService | `core/combat/ShrineService.gd` | `select_purifier()`, `apply_drain()`, `apply_purify_stack()`. |
| RetreatService | `core/combat/RetreatService.gd` | `can_attempt()` (speed gate), `get_chance_tier()` (agi tiers), `roll_retreat()` (seeded RNG). |
| DirectiveService | `core/directives/DirectiveService.gd` | Directives: none, scout, protect, push, preserve. `set_active_directive()` writes to save. |
| AppRoot | `ui/AppRoot.gd` + `ui/Approot.tscn` | Application composition root. Runtime boot/dispatch, shell/onboarding routing, bank timer, recovery/debug/test surfaces, responsive layout forwarding, full-rect ScreenHost, and the single app-wide layer-40 ModalHost. |
| ResponsiveLayoutController | `ui/components/ResponsiveLayoutController.gd` | Emits `{profile, logical_size, safe_insets, ui_scale, is_mobile}`. Applies desktop/phone/tablet scale caps, detects mobile profile, converts physical safe areas to logical insets, and updates `Window.content_scale_size` on live resize. |
| ModalHost | `ui/components/ModalHost.gd` + `.tscn` | One blocking modal at a time. Full-viewport dim/input root above chrome; forwards modal actions, contains focus, and restores prior focus on dismissal. |
| SafeAreaContainer | `ui/components/SafeAreaContainer.gd` + `.tscn` | Shared logical edge margins plus optional persistent-bottom-chrome reservation. |
| SanctumShell | `ui/shells/SanctumShell.gd` | Hub family host. Owns layer-0 spatial world, layer-10 screen content, inset/capped layer-20 BottomRail, layer-30 notifications, cached nav actions, modal scene lookup, and inherited CanvasLayer visibility synchronization. |
| RealmShell | `ui/shells/RealmShell.gd` | Venture family host. Routes stage map/preview/explore/combat. Owns the inset/capped 88-unit layer-20 EchoBar and requests Resolve/directive/engagement/contact/situation/return/prebattle modals from AppRoot. |
| SanctumScreen | `ui/screens/sanctum/SanctumScreen.gd` | Spatial-first hub. Authored `OverviewFlow` places `TopBand` above `OverviewBody`; title/vow/guidance reflow without primary overview scrolling, while capped side panels leave surplus room to the Sanctum field. |
| StageExploreScreen | `ui/screens/venture/StageExploreScreen.gd` + `.tscn` | Shared stage preview/explore screen. Preview refits briefing + map; explore uses a capped Living Tree HUD and same-row directive badge, bottom controls above the EchoBar exclusion, and preserves world focus/zoom across live resize. |
| CombatBoardScreen | `ui/screens/combat/CombatBoardScreen.gd` | Responsive isometric board. Capped objective/initiative/control panels leave wide-layout surplus to the battlefield; prebattle is requested through ModalHost. |
| RealmModel | `core/realms/RealmModel.gd` | Pure data factory. Fields: id/name/virtue/description/seed/stage_count/current_stage_index/is_completed/status/run_index/run_count/stages. |
| RealmService | `core/realms/RealmService.gd` | `get_or_create()`, `get_active()`, `compute_runtime_locks()`, `advance_stage()→Dict`. |
| ObjectiveModel | `core/realms/ObjectiveModel.gd` | Pure data factory. `make(index, type, seed, params={}, completed=false, required=true)`. **V2-STAGE-002:** 7 VALID_TYPES: combat/shrine/boss/recover/protect/endure/pursue. `completed`+`required` track stage completion gate. `params` is extension point for V2-STAGE-004. |
| SituationModel | `core/realms/SituationModel.gd` | Pure data factory. `make(id, type, col, row, seed, is_objective, objective_index=-1)`. **V2-STAGE-002:** `objective_index` binds situation to `stage.objectives[idx]`. -1 = non-objective. V2-STAGE-003 `role` field deferred (comment stub). |
| RealmGenerator | `core/realms/RealmGenerator.gd` | `generate(realm_seed, stage_count, obj_min, obj_max, explore_cfg={}, stages_cfg={})` → stages Array. **V2-STAGE-002:** config-driven objective pool (realm → balance → fallback). Situations derive type from matching objective. `objective_index` bound on objective situations. Min obj_count=2 enforced. `_derive_stage_type()` helper. |
| StageExploreModel | `core/realms/StageExploreModel.gd` | Pure data factory for `stages[i]["explore_map"]`. `make(w, h, situations)`, `make_default()`. MIN 30×30. (V2-STAGE-001) |
| FlowRealmSelectState | `core/state/flow/states/sanctum/FlowRealmSelectState.gd` | Realm card list + runtime locks. Per-row dispatch. `nav.back` → SANCTUM. |
| FlowStageMapState | `core/state/flow/states/venture/FlowStageMapState.gd` | Stage progress list + party prep. Static `build_snapshot()`. |
| FlowStageState | `core/state/flow/states/venture/FlowStageState.gd` | Single-stage overview. `cta.start` → STAGE_EXPLORE (V2-STAGE-001). |
| FlowStageExploreState | `core/state/flow/states/venture/FlowStageExploreState.gd` | Exploration map state `flow.stage_explore`. Locks map on first entry. Directive-guided party movement. **V2-STAGE-002:** `cta.proceed_to_stage_map` completion gate (all required objectives done). `cta.ignore_situation` when pending. Calling-action bonuses (ranger/okofor/aduro/cautious_advance). `party_requesting_return` when avg fear > threshold. Snapshot: `objectives[]`, `objectives_remaining`, `party_calling_actions`, `party_requesting_return`. |
| StageExploreScreen (flow behavior) | `ui/screens/venture/StageExploreScreen.gd` + `.tscn` | Isometric exploration board. **V2-STAGE-002:** Travel animation — board tweens 0.5 s (SINE); `SituationLayer.position` mirrors `_board.position` in `_process()` so markers follow. Situation markers via `SituationMarkerDraw`. Engagement/contact/return/situation surfaces request blocking Realm modals; Stage Complete dispatches `flow.complete_stage` when its slot is present. |
| SituationMarkerDraw | `ui/screens/venture/SituationMarkerDraw.gd` | Node2D custom draw. Shape by type: combat=square, shrine=triangle, loot/money=diamond, other=circle. State: hidden=grey+?, revealed=blue shape, revealed-objective=blue shape+gold ring (+3.5 px arc), resolved-encounter=grey+✓, resolved-objective=gold+✓. Added as children of `SituationLayer`; position = board-local pixels. |
| ResolveScreen | `ui/screens/venture/ResolveScreen.gd` | Responsive bounded modal card presented by AppRoot as `realm.resolve`; keeps authored header/footer and scrolls only the long body. Actions and flow outcomes are unchanged. |
| SkillDefinition | `core/progression/SkillDefinition.gd` | Active skill data contract + validator. `MAX_SKILL_SLOTS=1`. |

The registered suite includes responsive foundation, viewport/safe-area, modal focus/input,
cross-shell CanvasLayer, target-size, live-resize, Sanctum geometry, Realm geometry,
and existing deterministic core regression coverage.

**V2-COMBAT-002 Slice 2 acceptance:** dormant pressure, route-option, and complete-candidate arbitration foundation only. `BehaviorArbiter.select_movement_intent()` preserves the existing identity/emotion/directive/vow/bond scoring layers and adds bounded spatial utility, but the production `select_intent()` path and live combat/exploration movement remain unchanged. Final verification: 1081/1081 full suite; focused Slice 2 contracts 12/12, pressure 23/23, options/path 23/23, and arbiter/legacy 70/70. Jeff's manual in-game regression pass confirmed no new live behavior or UI. Slice 3 owns movement profiles, live shared execution, fixed hazard fixtures/effects, forced displacement, and ordered movement-plus-action activation; carry, party stage movement, and presentation remain deferred to their approved later slices.

**V2-COMBAT-002 Slice 3 acceptance:** five new dormant pure/static movement services — `MovementProfileService`, `MovementHazardService` (+ `MovementHazardFixtures`), `MovementExecutor`, `CombatActivationService` — plus additive edits (`HAZARD_TYPES` const on `MovementKnownHazardFact`, `data.combat.movement.{capacity,hazards}` in `balance.json` with **proposed** 3/3 hazard damages pending Slice-6 tuning, and Slice-3 test registration in `AppRoot`). **Frozen capacity formula:** `final = clamp(max(standing_capacity, aptitude_capacity), 2, 6)` (a `max()`, never a sum); standing bands S1–2→2 / S3–5→3 / S6–9-and-above→4 (ceiling 4, S9 no auto-increase); aptitude adds agi and Calling/skill terms only (no Standing term). **Hazard model:** three fixed types (unstable/binding/burning) with a once-per-type-per-activation ledger; Unstable displacement ranked by outward-progress then angular-deviation. **Diagonal rule:** the executor routes each edge through `StageTerrain.is_legal_edge` (block only when both orthogonal side cells are solid; occupancy is never terrain solidity). **Dormant only** — nothing is wired into live combat; the live cutover is Slice 6. Final verification: **1149/1149 full suite** (baseline 1083 → 1149), 0 failed; compile clean; five independent reviews all SHIP (0 blockers/majors). Slice-6 carry-forward guardrails (NOT Slice-3 defects) and the Slice 4/5/6 deferrals are recorded in `CONVENTIONS.md` and `docs/integration-map.md`.

---

## Currency & Economy (V2 design)

| Layer | Items |
|---|---|
| **Spendable currencies** | Ase (summoning, rites, Thread handling), Ekwan (rooms, crafting, buildings), Relics (rare artifacts) |
| **Visible states** | Faith, Harmony, Favor |
| **Progression states** | Continuity, Threads, Realm recovery track |

Exact values and cadences are open — see Working GDD `Economy` section for design direction.

## Conventions
- snake_case folders, PascalCase.gd classes
- No `randomize()`, `rand()`, `randf()` anywhere in core
- All meaningful logs via StructuredLogger, not `print()`
- `t` (sim_tick) always injected by caller, never generated in core
- Action format: `domain.subdomain.verb`
- Snapshot actions in named slots (slot-keyed Dictionary): `primary`, `secondary`, `back`, `nav.*`, `cta.*`, `overlay.*`
- Per-row UI actions dispatched directly by rows — NOT in `snapshot.actions`

## User Preferences / Workflow
- Always read the GitHub repo before writing subtasks
- Confirm contracts in Subtask 1 of every story before building
- Backend-first: complete backend fully before frontend work
- Every story ends with a Docs + Commit subtask
- **Every story must end with a visual/playable update.** If a story produces no visible change in-game, that is a gap — find an existing story that can absorb the UI/playable surface rather than writing a new one.

## Memory Files
- `feedback_visual_playable_end.md` — Every story must end with a visual/playable in-game update; broaden existing stories rather than writing new ones
- `feedback_notion_page_content.md` — Add content to Notion page body (not comments)
- `project_voice001_deferred.md` — ✅ Resolved: V2-VOICE-001 Done. `_sanctum_bark` dict on echo save entries; `round_bark_events` on EncounterContext; BarkPopupLayer in CombatBoardScreen. Spatial sanctum bark popup deferred to V2-SANCTUM-005.
- `feedback_godot_terminal.md` — Godot brew path + headless check-only command for compile verification
- `feedback_story_verification_workflow.md` — End-of-story sequence: Godot terminal tests → pause for Jeff in-game test → docs + commit

## Key Docs
- `docs/Echoes vNext Working GDD.md` — **Primary canon. Only authoritative design source.**
- `docs/calling-reference.md` — Calling reference (recreated V2-PROG-002; V1 IDs active until V2-PROG-004; V2 Twi names documented as target)

---

## Notion Backlog (V2)

| Resource | ID |
|---|---|
| V2 Backlog Hub | `339c3d1ede92814da4c2dad94d650e30` |
| V2 Story Backlog DB | `d3dc9cb4-21e9-44fc-9229-238474907ed6` |
| Backlog Conventions | `339c3d1ede9281509bcacb334bce5593` |

168 stories. Waves: Alignment / Foundation / Expansion / Full Game. Use `echoes-backlog` skill to query.
