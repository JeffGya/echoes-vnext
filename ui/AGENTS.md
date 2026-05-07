# ui/ — Agent Instructions

> Snapshot renderer. Dispatches actions. Never touches sim state directly.
> Full contracts: `../CONVENTIONS.md`. Full context: `../docs/CONTEXT.md`.

---

## What Goes Here

Screens, shells, components, overlays. The UI receives a snapshot from the sim and renders it.
When the player acts, the UI emits an action — it never mutates state itself.

---

## Absolute Rules for ui/

### Never access sim internals
```gdscript
# FORBIDDEN in any ui/ file
FlowContext.save_data          # no
SanctumService.get_roster()    # no
FlowRuntime.dispatch(action)   # no — emit action_requested signal instead
SaveService.flush()            # no
```

### Never build UI structure in .gd
```gdscript
# FORBIDDEN
func _ready():
    var label = Label.new()
    label.text = "Hello"
    add_child(label)           # NO — build structure in .tscn

# CORRECT
@onready var _name_label: Label = %NameLabel   # defined in .tscn
func set_snapshot(snap):
    _name_label.text = snap["data"]["name"]    # only set values
```

### Only set values in .gd — never create or layout
Allowed in `.gd`: `.text = ...`, `.modulate = ...`, `.visible = ...`, `.disabled = ...`, `.value = ...`
Forbidden in `.gd`: `Node.new()`, `add_child()`, `StyleBoxFlat.new()` (except modal overlays with no persistent scene ref)

### Theme-first styling
- Reused visual treatments belong in `assets/theme/LivingTreeSystem.tres`, not as repeated per-scene overrides.
- When adding a new surface, first check whether an existing theme variation covers it.
- If it does not, add the smallest new variation needed for the current screen story and reuse it immediately.
- Do not rebuild the same card, badge, chip, or text treatment locally across multiple scenes.

---

## Screen Contract

Every bespoke screen extends `ScreenTemplate.gd`:

```gdscript
# Entry point — called by shell when snapshot changes
func set_snapshot(snap: Dictionary) -> void

# Exit signal — emit this when player acts
signal action_requested(action: Dictionary)
```

Screens never call `dispatch()`. They emit `action_requested` → shell → AppRoot → FlowRuntime.

---

## Shell Routing

| Shell | Handles |
|-------|---------|
| `SanctumShell.gd` | `flow.sanctum`, `flow.summon`, `flow.echo_party`, `flow.realm_select`, `flow.vow_manage` |
| `RealmShell.gd` | `flow.stage_map`, `flow.stage`, `flow.stage_explore`, `flow.encounter`, `flow.keeper_trial`, `flow.resolve` |

AppRoot routes on `snapshot.type` → shell. Shell routes to screen.

### Shell-owned chrome — never put in snapshots
- `SanctumShell` owns the persistent **NavBar** via `_cached_nav`
  - On `flow.sanctum`: shell caches all `nav.*` and `cta.*` slots from `snap.actions` → `_cached_nav`
  - All other sanctum-family screens inherit cached NavBar unchanged
  - Do NOT inject nav actions into SummonState, PartyManageState, etc.

- `RealmShell` owns the persistent **EchoBar** (bottom 88px, full-width)
  - `_update_echo_bar(snap)` called on every `set_snapshot()` — always reflects latest state
  - `OverlayRoot` sized to stop 88px above bottom — bar never overlaps content
  - Do NOT render the EchoBar inside individual screens

---

## Snapshot Reading Pattern

```gdscript
func set_snapshot(snap: Dictionary) -> void:
    var data = snap["data"]
    var actions = snap["actions"]   # always Dictionary, never Array

    _name_label.text = data.get("name", "")
    _ase_label.text = str(data.get("ase", 0))

    # Wire action slots
    var cta = actions.get("cta.summon", {})
    _summon_button.disabled = cta.get("disabled", true)
    _summon_button.text = cta.get("label", "Summon")
```

**Per-row actions** — dispatched by the row component itself, never from `snap.actions`:
```gdscript
# In a row component
func _on_toggle_pressed():
    action_requested.emit({ "type": "sanctum.party.toggle", "payload": { "echo_id": _echo_id } })
```

---

## Player-Facing Display Rules

- Show **Standing** not `rank`, **Step** not `level`, **Storyweight** not `xp_total`
- Show calling by name: Ward / Break / Veil / Path / Rite / Root — not internal ID
- Show morale as tier: inspired / steady / shaken / broken — not raw number
- Never show internal `id` fields to the player

---

## Adding a New Screen

1. Create `XxxScreen.tscn` — full node tree, theme properties, StyleBoxFlat resources authored here
2. Create `XxxScreen.gd` implementing `set_snapshot()` + `action_requested` signal only
3. Use `unique_name_in_owner = true` on nodes referenced by script
4. Wire in the appropriate shell's routing logic
5. Add scene to `ui/screens/`

---

## Stage Preview Warning

`flow.stage` is the stage preview entry into `StageExploreScreen`. Do NOT add:
- Party prep UI
- Skill selection
- unrelated pre-stage management

Pre-stage prep belongs on `StageMapScreen`. When in doubt, ask Jeff before adding anything to StageScreen.

---

## Touch Targets

- Minimum: **48×48dp** for all interactive elements
- Preferred: 56×56dp for primary CTAs
- Spacing: at least 8dp between adjacent touch targets
- Safe zone: 16dp margin from screen edges
