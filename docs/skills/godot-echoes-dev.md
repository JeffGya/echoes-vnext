# Godot + GDScript Development Reference — Echoes vNext

Checklists for adding a flow state, an action, a service and a test. The rules and their reasons live in `AGENTS.md`. The contracts live in `CONVENTIONS.md`: look them up with `docs/canon-index.md`. Engine version: read `config/features` in `project.godot`.

**Claude Code:** the skill `godot-echoes-dev` points here. **Codex / any agent:** read `AGENTS.md` first, then this file.

## When to read this file
- You add or change a flow state, an action, a service, a save field or a test.

## Checklist: add a flow state
1. Add the ID constant to `core/state/flow/FlowStateIds.gd`. Read that file for the current IDs.
2. Create `FlowXxxState.gd` in `core/state/flow/states/`. Some states sit in the subfolders `boot/`, `onboarding/`, `sanctum/` and `venture/`.
3. A state implements `enter(ctx)` and `exit(ctx)` (see `core/state/State.gd`) and a `static func build_snapshot(...)`. A state has no `handle` method. Actions go through `FlowRuntime.dispatch` (next checklist).
4. Register the state in `register_default_states()` in `core/state/flow/FlowStateMachine.gd`.
5. Add the UI screen in `ui/screens/`, `.tscn` first. Follow `ui/AGENTS.md`.
6. Route the screen in `ui/AppRoot.gd`, `ui/shells/SanctumShell.gd` or `ui/shells/RealmShell.gd`.
7. Write tests (see below).

## Checklist: add an action
1. Read the action shape in `AGENTS.md` "Action Shape". `snapshot.actions` is a slot-keyed Dictionary. Each action has `type` and `slot`. Example: `core/state/flow/states/FlowResolveState.gd` (`"slot": "cta.continue"`).
2. Add a case in `FlowRuntime.dispatch` (`core/runtime/FlowRuntime.gd`) or in the matching controller in `core/runtime/controllers/`. Real action types look like `sanctum.summon`, `sanctum.party.toggle` and `sanctum.grade_select`.
3. A per-row UI action is not in `snapshot.actions`. The row emits `action_requested`. `AppRoot.gd` dispatches it.
4. To save, call `flow_ctx.request_save(reason)`. Controllers and services never call `SaveService`.

## Checklist: add a service
1. Create `XxxService.gd` in the matching `core/` folder.
2. Expose it through `FlowRuntime` or `FlowContext`. UI never calls it.
3. All mutations go through `FlowRuntime.dispatch`.
4. Write deterministic tests.

## Checklist: add a test suite
1. Create `XxxTests.gd` in `tests/`. Register each test with a "suite/name" string and a `Callable`, as in `tests/EconomyTests.gd`.
2. Register the suite in the run-tests block of `ui/AppRoot.gd`.
3. Each test sets up an isolated environment, calls the service directly and asserts the result.
4. To run, filter and read the result, follow `AGENTS.md` "How to Run & Verify". Only the `Tests:` line counts as evidence.

## Related files
- `AGENTS.md`, `CONVENTIONS.md`, `docs/canon-index.md`, `docs/MEMORY.md`
- `core/state/flow/FlowStateIds.gd`, `core/runtime/FlowRuntime.gd`, `core/state/flow/FlowStateMachine.gd`
