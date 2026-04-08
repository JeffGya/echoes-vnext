# Calling Reference — Echoes vNext V2

**Status:** V2-PROG-004 Done (2026-04-08). V2 six-calling model is now active in all backend systems.

---

## Two-Field Contract (post V2-PROG-002)

| Field | Where stored | Meaning | Mutability |
|---|---|---|---|
| `calling_origin` | `sanctum.roster[].calling_origin` | Birth bias — seeded at summon by EchoFactory RNG | Immutable after summon |
| `calling` | `sanctum.roster[].calling` | Confirmed runtime identity — chosen at Standing-3 milestone | Empty `""` until confirmed; then permanent |

**Rules:**
- `BehaviorArbiter`, `CombatState._calc_initiative()`, and `FlowStageMapState` all prefer `calling` (confirmed) when non-empty and not `"uncalled"`. Fall back to `calling_origin` for unconfirmed Echoes.
- `calling_origin` is in `ActorSchema.REQUIRED_FIELDS`. `calling` is not (enemies and structures have none).
- `calling_eligible` and `calling_options` are ephemeral V1 fields — superseded by V2-PROG-002. Not the V2 gate shape.

---

## V2 Vector Model (ten-vector — V2-PROG-003 ✅ Done)

Ten vectors describe the shape of recovering selfhood. Each is a pairing of two virtue domains.
Vector keys are lowercase identifiers stored in `echo["vector_scores"]` and `echo["dominant_vector"]`.

| Vector ID | Virtue composition | V2 calling (active) | Calling family |
|---|---|---|---|
| `vanguard` | Courage + Leadership | `aduro` | Edge |
| `protector` | Courage + Compassion | `okofor` | Anchor |
| `seeker` | Wisdom + Truth | `okomfo` (preferred) / `kra_soro` (compatible) | Sight |
| `strategist` | Wisdom + Leadership | `okomfo` | Sight |
| `skeptic` | Truth + Humility | `kra_soro` | Sight |
| `pillar` | Acceptance + Humility | `onyamesu` | Anchor |
| `devoted` | Acceptance + Generosity | `onyamesu` | Anchor |
| `opportunist` | Courage + Wisdom | `sum_okwanfo` | Edge |
| `mediator` | Empathy + Forgiveness | `okofor` | Anchor |
| `nurturer` | Generosity + Compassion | `onyamesu` | Anchor |

**Save fields:** `echo["vector_scores"]` (Dictionary<String, int> 0–1000 per key), `echo["dominant_vector"]` (String, hysteresis-protected at 3% margin).

**Config source:** `data/balance.json data.vectors.archetype_init` — 10 class_origin entries, each with 10 vector keys. VectorService is fully config-driven; adding vectors requires no GDScript changes.

**Save repair:** `VectorService.backfill_vector_scores()` adds any missing vector keys at 0 on load. Old 4-key saves are expanded to 10 keys automatically.

---

## V2 Calling Set — Active (V2-PROG-004 ✅ Done)

Six foundational callings replace the V1 five. Grouped into three families.
These are the live IDs used in all backend systems: `balance.json`, `BehaviorArbiter`, `CallingService`, `SaveService`, `CallingTests`, `CallingBehaviorTests`.

### Anchor Family — steadiness, protection, continuity, holding

| ID | Twi name | Primary vector | Secondary vector | Description |
|---|---|---|---|---|
| `okofor` | Oko Fo — Strong Ward | Protector | Pillar (secondary) | Bears danger for others and refuses collapse |
| `onyamesu` | Onyame Su — Root | Pillar | Nurturer (secondary) | Sustains life, morale, and communal steadiness |

### Edge Family — initiative, breach, pursuit, decisive redirection

| ID | Twi name | Primary vector | Secondary vector | Description |
|---|---|---|---|---|
| `aduro` | Aduro — Break | Vanguard | Opportunist (secondary) | Meets danger directly and turns courage into momentum |
| `sum_okwanfo` | Sum Okwanfo — Veil | Opportunist | Skeptic (secondary) | Moves through concealment, timing, and unseen openings |

### Sight Family — interpretation, warning, omen-reading, knowledge-shaped action

| ID | Twi name | Primary vector | Secondary vector | Description |
|---|---|---|---|---|
| `okomfo` | Okomfo — Rite | Seeker | Strategist (secondary) | Reads spirit, sign, and hidden meaning |
| `kra_soro` | Kra Soro — Path | Seeker | Opportunist (secondary) | Reads path, distance, and shifting ground |

**Uncalled:** `uncalled` — default for echoes not yet confirmed at Standing-3. Seeded by EchoFactory as `calling_origin` before milestone.

**Calling adjacency ring (V2):**
`Okofor ↔ Aduro ↔ Sum-Okwanfo ↔ Kra-Soro ↔ Okomfo ↔ Onyamesu ↔ Okofor`

**Distinctions:**
- `Okomfo` knows the unseen through spirit, omen, and interpretation
- `Kra-Soro` navigates the field through path, distance, and movement
- `Sum-Okwanfo` enters through concealment, timing, and hidden approach
- `Onyamesu` is the communal anchor and sustaining-presence calling — not a generic healer

---

## V1 Calling IDs (migration history — superseded by V2-PROG-004)

These were the V1 values stored in save data up until V2-PROG-004 shipped. `SaveService` repair now migrates them automatically on load.

| V1 ID | → V2 ID |
|---|---|
| `blade` | `aduro` |
| `warder` | `okofor` |
| `steward` | `onyamesu` |
| `ranger` | `kra_soro` |
| `seer` | `okomfo` |

**EchoFactory seeding note:** `calling_origin` is the 2nd RNG draw in the immutable v1 sequence:
`rarity → calling_origin → gender → name → traits → archetype_birth → derived_stats`
Never reorder or insert draws before position 2. The draw produces a V2 calling ID for new summons; SaveService migration handles any pre-V2-PROG-004 saves.

---

## Calling Behavior Grammar (BehaviorArbiter)

Calling families weight intent — they do not determine it. Traits, vectors, fear, and directive can override.

| Family | Base behavioral tendency |
|---|---|
| **Anchor** | Bias steadiness, protection, burden-taking, continuity, holding |
| **Edge** | Bias initiative, breach, pursuit, decisive redirection, forceful commitment |
| **Sight** | Bias interpretation, warning, omen-reading, hidden-truth response, knowledge-shaped caution or insistence |

Higher-Standing Echoes let **calling / identity consistency lead** over situational impulse.

**Absolute Fear Thresholds by calling (balance.json `data.calling.absolute_fear_threshold_by_calling`):**

| Calling | Threshold |
|---|---|
| `aduro` | 75.0 |
| `sum_okwanfo` | 70.0 |
| `okofor` | 80.0 |
| `onyamesu` | 85.0 |
| `okomfo` | 85.0 |
| `kra_soro` | 80.0 |
| `uncalled` | 80.0 |

---

## Standing Milestones (V2)

| Standing | Gate | Calling event |
|---|---|---|
| 3 | Core calling confirmation | Keeper chooses from the 6 foundational callings |
| 6 | Deepening | Drift and synthesis across adjacent calling families allowed |
| 9 | Culmination | Loosened structure; cross-track movement valid |

*Current save gate: `calling_eligible = true` at `rank == 3` (V1 shape — pending V2 milestone UI rewrite)*

---

*Primary design source: `docs/Echoes vNext Working GDD.md` §11.4.5, §11.5, §11.9*
*Migration context: `docs/v2-migration-map.md` — Domain 2 (Calling)*
