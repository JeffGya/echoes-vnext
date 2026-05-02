# Echoes vNext — Project Memory

## What This Is
Godot 4.5.1 mythic house-and-trials strategy game. Deterministic core simulation + snapshot-driven UI.
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

- **`godot-echoes-dev`** — Godot 4.5 + GDScript dev patterns: architectural invariants, flow state IDs, all action types, naming conventions, checklists for adding new states/services/tests. **Use for any implementation question.**
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
| FlowEncounterState | `core/state/flow/states/venture/FlowEncounterState.gd` | Two static builders: `build_round_snapshot()` + `build_final_snapshot()`. |
| EncounterContext | `core/state/encounter/EncounterContext.gd` | actors, placement_seed, combat_state, initiative_cfg, last_round_results, combat_result, purifier_id, last_round_snapshot, final_snapshot. |
| EchoFactory | `core/sanctum/EchoFactory.gd` | Deterministic echo gen. RNG draw order v1 **IMMUTABLE**: rarity→calling_origin→gender→name→traits→archetype_birth→derived_stats. |
| SanctumService | `core/sanctum/SanctumService.gd` | `get_party_actors()` + `get_roster_actors()` → read-only actor dicts. |
| SummonService | `core/sanctum/SummonService.gd` | `summon_paid_one()` / `summon_paid_many()`. Transactional (settle→validate→spend→generate→save). |
| EconomyService | `core/economy/EconomyService.gd` | `spend_ase()`, `add_ase()`, `can_afford_ase()`, `get_ase()`. Single choke for Ase mutations. |
| SaveService + Schema | `core/save/` | Crash-safe (tmp→rename). Additive repair. 8 top-level keys: schema_version/first_boot/meta/campaign/flow/economy/sanctum/stage_context. |
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
| EmotionService | `core/emotion/EmotionService.gd` | `init_echo()` idempotent. `apply_morale_delta()` / `apply_fear_delta()` / `set_fear_base()`. Emotion block: faith, morale_base, morale_current, fear_current, fear_base, win_streak, loss_streak. fear_base born from traits/archetype (0–20), rises +1 per loss, falls -1 per win, capped 0–40. morale_base mutates via streaks (3-win: +1, 3-loss: -1, range 10–90). Sanctum tick bidirectional for fear (toward fear_base). BehaviorArbiter uses max(fear_current, fear_base) as effective fear. Morale tiers: inspired/steady/shaken/broken. 8 emotional status tiers. (V2-EMOTION-003) |
| GridService | `core/grid/GridService.gd` | `place_actors()`, `manhattan_distance()`, `move_toward()` (8-dir greedy). Board 10×10. |
| CombatState | `core/combat/CombatState.gd` | `create()` + `check_end_condition()`. End priority: all_enemies_defeated → shrine_destroyed → all_echoes_dead. |
| CombatService | `core/combat/CombatService.gd` | `resolve_action(type, attacker, defender, round)` → result dict. Melee: guard doubles eff_def. |
| ShrineService | `core/combat/ShrineService.gd` | `select_purifier()`, `apply_drain()`, `apply_purify_stack()`. |
| RetreatService | `core/combat/RetreatService.gd` | `can_attempt()` (speed gate), `get_chance_tier()` (agi tiers), `roll_retreat()` (seeded RNG). |
| DirectiveService | `core/directives/DirectiveService.gd` | Directives: none, scout, protect, push, preserve. `set_active_directive()` writes to save. |
| AppRoot | `ui/AppRoot.gd` | Routes `snapshot.type` → SanctumShell or RealmShell. Bank timer. Debug panel (F1). Test runner. |
| SanctumShell | `ui/shells/SanctumShell.gd` | Hub family host. Owns persistent NavBar via `_cached_nav`. Shell-cached nav pattern. |
| RealmShell | `ui/shells/RealmShell.gd` | Venture family host. Routes stage_map/stage/encounter/resolve. No shared chrome. |
| ScreenTemplate | `ui/screens/ScreenTemplate.gd` | Canonical starting point for all new bespoke screens. |
| SanctumScreen | `ui/screens/SanctumScreen.gd` | Hub: Ase, roster preview, party slots, name modal. No nav buttons (in shell). |
| CombatBoardScreen | `ui/screens/CombatBoardScreen.gd` | Isometric TileMap. InitiativePanel, PrebattlePanel, PartyBar, CombatTokenLayer, CombatDistanceLayer. |
| RealmModel | `core/realms/RealmModel.gd` | Pure data factory. Fields: id/name/virtue/description/seed/stage_count/current_stage_index/is_completed/status/run_index/run_count/stages. |
| RealmService | `core/realms/RealmService.gd` | `get_or_create()`, `get_active()`, `compute_runtime_locks()`, `advance_stage()→Dict`. |
| RealmGenerator | `core/realms/RealmGenerator.gd` | `generate(realm_seed, stage_count, obj_min, obj_max, explore_cfg)` → deterministic stages Array with `explore_map` per stage (V2-STAGE-001). |
| SituationModel | `core/realms/SituationModel.gd` | Pure data factory for exploration map situations. `make(id, type, col, row, seed, is_objective)`. Types: combat/npc/loot/money. (V2-STAGE-001) |
| StageExploreModel | `core/realms/StageExploreModel.gd` | Pure data factory for `stages[i]["explore_map"]`. `make(w, h, situations)`, `make_default()`. MIN 30×30. (V2-STAGE-001) |
| FlowRealmSelectState | `core/state/flow/states/sanctum/FlowRealmSelectState.gd` | Realm card list + runtime locks. Per-row dispatch. `nav.back` → SANCTUM. |
| FlowStageMapState | `core/state/flow/states/venture/FlowStageMapState.gd` | Stage progress list + party prep. Static `build_snapshot()`. |
| FlowStageState | `core/state/flow/states/venture/FlowStageState.gd` | Single-stage overview. `cta.start` → STAGE_EXPLORE (V2-STAGE-001). |
| FlowStageExploreState | `core/state/flow/states/venture/FlowStageExploreState.gd` | Exploration map state `flow.stage_explore`. Locks map on first entry. Directive-guided party movement. (V2-STAGE-001) |
| StageExploreScreen | `ui/screens/venture/StageExploreScreen.gd` + `.tscn` | Isometric TileMap exploration board. Situation markers (hidden=?, revealed=type, resolved=✓), party token, HUD strip, action bar, situation overlay. (V2-STAGE-001) |
| ResolveScreen | `ui/screens/ResolveScreen.gd` | VICTORY/DEFEAT. Actor roster. `cta.continue` → sanctum. `cta.next_stage` → dispatches `flow.complete_stage`. |
| SkillDefinition | `core/progression/SkillDefinition.gd` | Active skill data contract + validator. `MAX_SKILL_SLOTS=1`. |

**Tests (215 total, 32 suites):** EconomyTests, SanctumSummonTests, PartyTests, ActorTests, EchoSchemaTests, ActorStatInitTests, DerivedStatTests, BehaviorModuleTests, MeleeTests, BehaviorArbiterTests, StructureTests, MoraleInfluenceTests, KODeathTests, EmotionTests, VectorTests, DirectiveTests, GridTests, CombatStateTests, CombatServiceTests, CombatRoundTests, CombatSnapshotTests, RetreatTests, ArchetypeTests, StageProgressionTests, SkillDefinitionTests, CallingBehaviorTests, ExclusiveActionTests, CooldownTests, PassiveIdentityTests, SkillLoadoutTests, MaturityExpressionTests, StageExploreTests (V2-STAGE-001), VoiceTests (V2-VOICE-001)

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
