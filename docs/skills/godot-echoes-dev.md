# Godot + GDScript Development Reference

> Authoritative Godot 4.5 + GDScript guide for Echoes vNext.
> Read this before writing any new GDScript, adding a flow state, service, or test.

**Claude Code:** invoke as `/godot-echoes-dev` or `anthropic-skills:godot-echoes-dev`
**Codex / any agent:** read this file directly — all knowledge is self-contained here.

## When to consult this document
- Starting any new GDScript file or flow state
- Checking action type format or snapshot shape
- Adding a new service, test suite, or flow state
- Any time you're unsure whether a pattern matches project conventions

---

## Reference Knowledge

### Flow State IDs (FlowStateIds.gd)
Current canonical flow state IDs include:
- `SANCTUM` — hub home screen
- `SUMMON` — summon screen
- `ECHO_PARTY` — party management
- `REALM_SELECT` — realm selection
- `STAGE_MAP` — stage progress + party prep
- `STAGE` — stage preview
- `STAGE_EXPLORE` — exploration map
- `ENCOUNTER` — combat board
- `RESOLVE` — post-combat resolve screen
- `SPLASH` — splash/title entry
- `MAIN_MENU` — main menu / continue gate

### Action Type Format
All actions follow `domain.subdomain.verb` format:
- `flow.summon.confirm`
- `flow.party.toggle`
- `nav.back`
- `cta.enter_stage`
- `overlay.grade_select`

### Snapshot Shape
```gdscript
{
  "type": FlowStateIds.SANCTUM,   # string
  "meta": { ... },                 # screen-level metadata
  "data": { ... },                 # content data
  "actions": {                     # slot-keyed Dictionary
    "primary": { "id": "...", "label": "...", "disabled": false },
    "nav.back": { "id": "nav.back", "label": "Back" },
    "cta.enter_stage": { "id": "cta.enter_stage", "disabled": true }
  }
}
```

### Checklist: Adding a New Flow State
1. Add ID constant to `FlowStateIds.gd`
2. Create `FlowXxxState.gd` in `core/state/flow/states/`
3. Implement `enter(ctx)`, `handle(ctx, action)`, `static func build_snapshot(ctx) → Dictionary`
4. Register in `FlowStateMachine.gd`
5. Add UI screen in `ui/screens/` (`.tscn` first, `.gd` second)
6. Route in `AppRoot.gd`, `SanctumShell.gd`, or `RealmShell.gd` as appropriate
7. Write tests in `tests/`

### Checklist: Adding a New Service
1. Create `XxxService.gd` in `core/xxx/`
2. Expose via `FlowRuntime` or `FlowContext` — never accessed directly from UI
3. All mutations via `FlowRuntime.dispatch()` — no direct state writes from UI
4. Write deterministic unit tests

### Checklist: Adding a New Test Suite
1. Create `XxxTests.gd` in `tests/`
2. Register in test runner
3. Each test: set up isolated env, call service directly, assert result
4. No `randomize()`, no OS calls, no time dependencies

---

## Architecture Invariants (never violate)

- `CampaignSeed.derive("dot.path")` is the only RNG source in core
- `FlowRuntime.dispatch(action)` is the only mutation entry point
- `snapshot.actions` is always a **slot-keyed Dictionary**, never an Array
- Per-row UI actions are dispatched directly by the row — never put them in `snapshot.actions`
- `t` (sim_tick) is always injected by caller — never generated inside a service
- `EchoFactory` RNG draw order is **IMMUTABLE** — only append new draws at the end; bump version string
- All logging via `StructuredLogger` — never `print()`
- No `randomize()`, `rand()`, `randf()` anywhere in `core/`

---

## Related Files
- `CONVENTIONS.md` — contracts, action type reference, screen summaries
- `core/state/flow/FlowStateIds.gd` — canonical state ID constants
- `core/runtime/FlowRuntime.gd` — dispatch choke point
- `core/state/flow/FlowContext.gd` — runtime state shape
- `core/state/flow/FlowStateMachine.gd` — state registration + routing
