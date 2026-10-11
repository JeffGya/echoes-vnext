# V2-DIRECTIVE-002 — Handoff after PHASE A

**Status: phase A is done. The story is NOT done.** Phases B+C and D are pending.
Plan: `~/.claude/plans/jolly-cooking-crescent.md`. Decisions: `decisions.md`. Open items: `follow-ups.md`.
Project-wide answers: ANSWERS.md #81 (a Directive is data-only to add), #82 (profile inputs).

## What changed (by file)

| File | Change |
|---|---|
| `core/directives/DirectiveService.gd` | Static accessors `active_id`, `resolve`, `registry_of`, `available_ids`. The `data.directives` subtree is read by `ConfigService.get_directives_cfg` (the owner of balance subtrees). Constants `DEFAULT_DIRECTIVE_ID`, `KNOWN_UNLOCK_CONDITIONS`, `ENTRY_SCHEMA`, `OPTIONAL_KEYS`, `CONTACT_EFFECT_KEYS`. `validate_entry_schema()`. Instance `get_active_directive` and `get_available_directives` delegate. |
| `core/config/ConfigService.gd` | `directives_block_is_loadable()`. A malformed entry aborts `load_balance` (`config.balance.directives_invalid`). Degenerate `intent_weights` stays warn-only. |
| `ContactController`, `ContactConversationService`, `SituationEngagementService` | Read the Directive through `DirectiveService.resolve(save, ConfigService.get_directives_cfg(config_service))`. `SituationEngagementService` now writes the right `encounter_approach.directive_id`. |
| `FlowStageExploreState`, `FlowStageState`, `StageExploreSnapshotBuilder`, `SanctumSnapshotBuilder` | Use the canonical accessor. Picker and Sanctum lists read the registry. Substring matches removed. |
| `core/realms/ConversationService.gd` | `compute_bids` takes the resolved `contact_effects` dict. |
| `core/save/SaveService.gd`, `SaveSchema.gd`, `core/runtime/FlowRuntime.gd` | Load repair keeps any registry-known id (new optional `directives_cfg` parameter; `FlowRuntime.boot` passes `data.directives`). Legacy-id map kept. Unknown id resets with a note. Both files use `DEFAULT_DIRECTIVE_ID`. |
| `data/balance.json` | Contact effects moved from `data.contact.directive_effects` (removed) to `data.directives.<id>.contact_effects`. Each config `description` equals today's picker text. |
| `tests/DirectiveCharacterizationTests.gd` (+ `.uid`), `ui/AppRoot.gd` | New suite `directive_char`, 14 tests, registered in `AppRoot`. Includes a synthetic third Directive and a no-literal-in-core scan. |
| `AGENTS.md`, `scripts/run-tests-sharded.sh` | Alarm 3600 s, suite count 129, `directive_char` in shard5 (D-20, D-21). |
| `CONVENTIONS.md`, `docs/MEMORY.md`, `docs/integration-map.md`, `docs/project_systems_audit.md` | Docs pass for phase A. |

## How it was verified

- Compile check: clean.
- Full serial suite: 2043 total, 2042 passed, 1 failed. The failure is the known red `movement_arbiter/avoid_overcommit_stays_proportionate` (pace-reward follow-up #11). It is not part of this story.
- Two qa-verifier reviews (opus whole-diff, sonnet re-check). No claim disproved. 9 low findings. 4 fixed (F3, F4, F5+F6, F9). The rest are in `follow-ups.md`.
- Jeff tested in game: start, picker text and order, selection persists across save and reload, stage run. All fine.
- Contact-bid change cannot be tested in game (no tool gives an Echo with the needed calling). Automated tests cover it.

## What moved

Nothing recorded. No fingerprint and no baseline moved.

## Player-visible change

Seek Signs now reaches contact bids (before, bids always read as Scout Carefully). No visible text change.

## Decisions

| # | One line |
|---|---|
| D-00 | Plan V2-DIRECTIVE-002 before V2-COMBAT-004. INFRA-004 stays out. |
| D-01 | Three phases, one PR each: A, B+C, D. |
| D-02 | Hazard addendum out. Build the exposure seam only. |
| D-03 | Profile inputs: Calling, virtue identity, Standing band and Judgment, fear, morale. Bonds are an interrupt only. |
| D-04 | Stage party profile: bounded modifiers plus counterfactual naming. |
| D-05 | Revive `exposure_tolerance` as the one exposure input (0.3, 0.8 PROPOSED DEFAULT). |
| D-06 | Only Scout Carefully and Seek Signs. More stances go to V2-DIRECTIVE-003. |
| D-07 | `reposition` and `regroup` goal sources belong to V2-COMBAT-004. |
| D-08 | Contrast is required at every Standing. |
| D-09 | Directive only. No shared influence function. |
| D-10 | Phase D registers a Directive cause in stop-short. Route scores do not change. |
| D-11 | Contact bids scale by Judgment and fear (Jeff's choice against the recommendation). |
| D-12 | Visible result: a stage "why" line plus a visible route, stop or commitment difference. |
| D-13 | `step_budget` is the baseline. Party readiness moves it inside a small bound. |
| D-14 | A new Directive is a data entry plus tests. No logic change. |
| D-15 | A malformed Directive entry fails the config load. |
| D-16 | Wire `witness_resonance_bonus`: +0.1 resonance on every conversation under Seek Signs (B+C). |
| D-17 | Accessor is static and takes the save dict and the `data.directives` dict. |
| D-18 | Picker shows one description field from config. Phase A keeps today's text. |
| D-19 | Degenerate `intent_weights` stays warn-only. |
| D-20 | One full serial run per phase gate. Alarm raised to 3600 s. |
| D-21 | Approved: alarm change, shard map entry, suite count 129, contact-window findings filed. |
| D-22 | The four contact-window findings are a separate later story, not part of this story. No Notion story until Jeff asks. |
| D-23 | PR #106 review: `ConfigService.get_directives_cfg` owns the `data.directives` read; the guard checks `pros` and `cons` (2 or more non-empty strings). |

## Open items

See `follow-ups.md`: contact-window findings (separate story, D-22), phase A QA nits (owner B+C), and the open items for Jeff:
picker wording (D-18), `witness_resonance_bonus` value (D-16), UI per-id label and colour, Seek Signs friction, the known red test.

## Phase B+C starts from

- One accessor: use `DirectiveService.resolve(save, ConfigService.get_directives_cfg(config_service))`. Do not read the save key directly.
- Contact effects sit in `data.directives.<id>.contact_effects`. D-11 and D-16 add Judgment/fear scaling and the resonance bonus there. They move conversation tests.
- The entry schema guard is in `validate_entry_schema()`. B+C edits it and must fix the QA nits first.
- Stage traversal fields (`step_budget`, `reveal_radius`, `exposure_tolerance`, and the rest) are already in `ENTRY_SCHEMA`. `exposure_tolerance` has no reader yet (D-05).
- Picker wording: Jeff rewrites both lines before B+C (D-18).
- Phases C and D both move recorded values. They run one after the other (D-01).
- `docs/movement-model.md` is unchanged: phase A delivers none of Slice D.
