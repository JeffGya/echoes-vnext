# core/ — Agent Instructions

> Deterministic simulation layer. No UI node refs. No Godot scene tree calls. Pure GDScript logic.
> Full contracts: `../CONVENTIONS.md`. Full context: `../docs/CONTEXT.md`.

---

## What Goes Here

All game simulation: actor model, combat, economy, emotion, progression, realms, save, sanctum.
This layer outputs **snapshots** and **logs** — nothing else.

---

## Absolute Rules for core/

### No randomness except via CampaignSeed
```gdscript
# CORRECT
var rng = ctx.campaign_seed.derive("combat.placement.realm_01.stage_0")
var roll = rng.randi_range(1, 100)

# FORBIDDEN
var roll = randi()           # no global RNG
var roll = randf()           # no global RNG
randomize()                  # never
OS.get_unix_time()           # no real time in sim
```

### Sim tick `t` is always injected
```gdscript
# CORRECT — t injected by caller
func apply_morale_delta(echo: Dictionary, delta: int, cause: String, logger, t: int) -> void:

# FORBIDDEN — never generate t internally
func apply_morale_delta(echo: Dictionary, delta: int) -> void:
    var t = Time.get_ticks_msec()  # NO
```

### Logging via StructuredLogger — never print()
```gdscript
# CORRECT
logger.info(t, "emotion", "morale_shifted", { "echo_id": echo["id"], "delta": delta })

# FORBIDDEN
print("morale shifted")
```

### Single choke points — never bypass
- All state mutations via `FlowRuntime.dispatch(action)` — never mutate ctx directly from a state
- All Ase/Ekwan mutations via `EconomyService` — never write `save_data["economy"]` directly
- All emotion mutations via `EmotionService` (outside mid-combat direct writes)
- All saves via `SaveService` — never write save file directly

---

## Key Service Interfaces

### FlowRuntime (`runtime/FlowRuntime.gd`)
```gdscript
FlowRuntime.dispatch(action: Dictionary) -> void
FlowRuntime.boot() -> void
```
Single entry point for all game state mutations. Sets `save_request` flag — SaveService flushes once per tick.

### EconomyService (`economy/EconomyService.gd`)
```gdscript
EconomyService.spend_ase(amount, save_data, logger, t) -> bool
EconomyService.add_ase(amount, save_data, logger, t) -> void
EconomyService.can_afford_ase(amount, save_data) -> bool
EconomyService.get_ase(save_data) -> int
```

### EmotionService (`emotion/EmotionService.gd`)
```gdscript
EmotionService.init_echo(echo, logger, t) -> void        # idempotent
EmotionService.apply_morale_delta(echo, delta, cause, logger, t) -> void
EmotionService.apply_fear_delta(echo, delta, cause, fear_threshold, logger, t) -> void
EmotionService.get_morale_tier(morale_current) -> String # "inspired"/"steady"/"shaken"/"broken"
```
Mid-combat: direct dict writes only — EmotionService NOT called during combat rounds.

### CampaignSeed (`CampaignSeed.gd`)
```gdscript
CampaignSeed.derive("dot.separated.path") -> RandomNumberGenerator
```
Reserved namespaces: `campaign.starter.*`, `campaign.summon.*`, `encounter.retreat.*`

### EchoFactory (`sanctum/EchoFactory.gd`)
RNG draw order v1 **IMMUTABLE**: `rarity → calling_origin → gender → name → traits → archetype_birth → derived_stats`
Only append new draws at end. Bump version string if added.

### ActorSchema (`actors/ActorSchema.gd`)
```gdscript
ActorSchema.validate(actor) -> bool   # checks 18 REQUIRED_FIELDS
ActorSchema.get_defaults() -> Dictionary  # adds guard_state: false (runtime only)
```

### GridService (`grid/GridService.gd`)
```gdscript
GridService.chebyshev_distance(a, b) -> int  # use for range checks and AI distance
GridService.manhattan_distance(a, b) -> int  # direction heuristic only — not range checks
GridService.is_adjacent(a, b) -> bool        # Chebyshev == 1; use for melee range
GridService.move_toward(actor, target_pos, board_cfg) -> Dictionary
GridService.place_actors(echo_actors, enemy_actors, board_cfg, rng) -> void
```

### ThreadService (`progression/ThreadService.gd`)
```gdscript
ThreadService.crystallize_threads(realm_id, save_data, cfg, t, logger) -> Array
ThreadService.get_recovery_band(segments, cfg) -> String  # "strong"/"compromised"/"weak"
```
Call order: `RealmService.contribute_segment()` BEFORE `advance_stage()`. Then `crystallize_threads()` AFTER realm confirmed complete.

---

## Actor Dict Rules

Actor dicts are **read-only views** — always deep-copied at construction.

```gdscript
# CORRECT — top-level fields
var hp = actor["current_hp"]
var spd = actor["speed"]

# WRONG — these are NOT inside stats
var hp = actor["stats"]["current_hp"]
```

18 REQUIRED_FIELDS: `id`, `name`, `rarity`, `rank`, `calling_origin`, `stats` (sub-dict with 7 fields), `traits`, `xp_total`, `level`, `actor_type`, `current_hp`, `speed`, `morale`, `fear`, `is_structure`, `is_dead`, `death_round`, `grid_pos`, `resilience_traits`, `leadership_traits`

**Absolute Fear Rule:** `fear ≥ 80` → actor refuses to act. Veteran+ last-echo-standing raises threshold to 88; Elite to 95. `suppress_panic_spiral` adds +5 on top.

---

## Adding a New Service

1. Create `XxxService.gd` in appropriate `core/` subdirectory
2. Expose via `FlowContext` or inject via constructor — never accessed directly from UI
3. All mutations dispatched via `FlowRuntime.dispatch()` — no direct state writes from UI
4. Write deterministic unit tests in `tests/XxxTests.gd`
5. Add to test runner registration

---

## Adding a New Flow State

1. Add ID constant to `FlowStateIds.gd`
2. Create `FlowXxxState.gd` in `core/state/flow/states/`
3. Implement: `enter(ctx)`, `handle(ctx, action)`, `static func build_snapshot(ctx) -> Dictionary`
4. Register in `FlowStateMachine.gd`
5. Route in `AppRoot.gd` or appropriate shell
6. Write tests

---

## Save Data Shape (top-level keys)

```
schema_version / first_boot / meta / campaign / flow / economy / sanctum / stage_context
```

Inside `sanctum`:
- `threads: []` — Thread dicts `{ id, virtue, quality_tier, realm_id, run_index }`
- `bonds: []` — Bond dicts `{ actor_a, actor_b, strength }`
- `party_encounters: []` — Canonical echo pair arrays
- `vows: {}` — Vow dicts keyed by vow_id
- `active_vow: {}` — Current active vow or `{}`

Additive-only. Never remove or rename fields.
