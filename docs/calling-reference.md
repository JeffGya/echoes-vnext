# Calling Reference — Echoes vNext V2

**Status:** V2-PROG-002 seam resolved (2026-04-06). V1 calling IDs remain active until V2-PROG-004 replaces them.

---

## Two-Field Contract (post V2-PROG-002)

| Field | Where stored | Meaning | Mutability |
|---|---|---|---|
| `calling_origin` | `sanctum.roster[].calling_origin` | Birth bias — seeded at summon by EchoFactory RNG | Immutable after summon |
| `calling` | `sanctum.roster[].calling` | Confirmed runtime identity — chosen at Standing-3 milestone | Empty `""` until confirmed; then permanent |

**Rules:**
- `BehaviorArbiter`, `CombatState._calc_initiative()`, and `FlowStageMapState` all prefer `calling` (confirmed) when non-empty and not `"uncalled"`. Fall back to `calling_origin` for unconfirmed Echoes.
- `calling_origin` is in `ActorSchema.REQUIRED_FIELDS`. `calling` is not (enemies and structures have none).
- `calling_eligible` and `calling_options` are ephemeral V1 fields — not the V2 gate shape. V2-PROG-004 will supersede them with Standing-3 milestone logic.

---

## V2 Vector Model (ten-vector — V2-PROG-003 ✅ Done)

Ten vectors describe the shape of recovering selfhood. Each is a pairing of two virtue domains.
Vector keys are lowercase identifiers stored in `echo["vector_scores"]` and `echo["dominant_vector"]`.

| Vector ID | Virtue composition | V1 calling ID (interim until V2-PROG-004) | Calling family |
|---|---|---|---|
| `vanguard` | Courage + Leadership | `blade` | Edge |
| `protector` | Courage + Compassion | `warder` | Anchor |
| `seeker` | Wisdom + Truth | `ranger` / `seer` (trait split) | Sight |
| `strategist` | Wisdom + Leadership | `seer` | Sight |
| `skeptic` | Truth + Humility | `ranger` | Sight |
| `pillar` | Acceptance + Humility | `steward` | Anchor |
| `devoted` | Acceptance + Generosity | `steward` | Anchor |
| `opportunist` | Courage + Wisdom | `blade` | Edge |
| `mediator` | Empathy + Forgiveness | `warder` | Anchor |
| `nurturer` | Generosity + Compassion | `steward` | Anchor |

**Save fields:** `echo["vector_scores"]` (Dictionary<String, int> 0–1000 per key), `echo["dominant_vector"]` (String, hysteresis-protected at 3% margin).

**Config source:** `data/balance.json data.vectors.archetype_init` — 10 class_origin entries, each with 10 vector keys. VectorService is fully config-driven; adding vectors requires no GDScript changes.

**Save repair:** `VectorService.backfill_vector_scores()` adds any missing vector keys at 0 on load. Old 4-key saves are expanded to 10 keys automatically.

---

## V1 Calling IDs (active until V2-PROG-004)

These are the current values stored in save data and used by balance.json config. V2-PROG-004 will replace them with the V2 Twi-named set.

| ID | Display name | Vector alignment |
|---|---|---|
| `blade` | Blade | Vanguard |
| `warder` | Warder | Protector |
| `steward` | Steward | Pillar |
| `ranger` | Ranger | Seeker (courage ≥ wisdom) |
| `seer` | Seer | Seeker (wisdom > courage) |
| `uncalled` | — | Default (birth not yet resolved) |

**EchoFactory seeding note:** `calling_origin` is the 2nd RNG draw in the immutable v1 sequence:
`rarity → calling_origin → gender → name → traits → archetype_birth → derived_stats`
Never reorder or insert draws before position 2.

---

## V2 Standing-3 Calling Set (target for V2-PROG-004)

Six foundational callings replace the V1 five. Grouped into three families.

### Anchor Family — steadiness, protection, continuity, holding

| ID (proposed) | Twi name | Primary vector | Secondary vector | Description |
|---|---|---|---|---|
| `okofor` | Oko Fo — Strong Ward | Protector | Pillar (secondary) | Bears danger for others and refuses collapse |
| `onyamesu` | Onyame Su — Root | Pillar | Nurturer (secondary) | Sustains life, morale, and communal steadiness |

### Edge Family — initiative, breach, pursuit, decisive redirection

| ID (proposed) | Twi name | Primary vector | Secondary vector | Description |
|---|---|---|---|---|
| `aduro` | Aduro — Break | Vanguard | Opportunist (secondary) | Meets danger directly and turns courage into momentum |
| `sum_okwanfo` | Sum Okwanfo — Veil | Opportunist | Skeptic (secondary) | Moves through concealment, timing, and unseen openings |

### Sight Family — interpretation, warning, omen-reading, knowledge-shaped action

| ID (proposed) | Twi name | Primary vector | Secondary vector | Description |
|---|---|---|---|---|
| `okomfo` | Okomfo — Rite | Seeker | Strategist (secondary) | Reads spirit, sign, and hidden meaning |
| `kra_soro` | Kra Soro — Path | Seeker | Opportunist (secondary) | Reads path, distance, and shifting ground |

**Calling adjacency ring (V2):**
`Okofor ↔ Aduro ↔ Sum-Okwanfo ↔ Kra-Soro ↔ Okomfo ↔ Onyamesu ↔ Okofor`

**Distinctions:**
- `Okomfo` knows the unseen through spirit, omen, and interpretation
- `Kra-Soro` navigates the field through path, distance, and movement
- `Sum-Okwanfo` enters through concealment, timing, and hidden approach
- `Onyamesu` is the communal anchor and sustaining-presence calling — not a generic healer

---

## Calling Behavior Grammar (BehaviorArbiter)

Calling families weight intent — they do not determine it. Traits, vectors, fear, and directive can override.

| Family | Base behavioral tendency |
|---|---|
| **Anchor** | Bias steadiness, protection, burden-taking, continuity, holding |
| **Edge** | Bias initiative, breach, pursuit, decisive redirection, forceful commitment |
| **Sight** | Bias interpretation, warning, omen-reading, hidden-truth response, knowledge-shaped caution or insistence |

Higher-Standing Echoes let **calling / identity consistency lead** over situational impulse.

---

## Standing Milestones (V2 — target for V2-PROG-004+)

| Standing | Gate | Calling event |
|---|---|---|
| 3 | Core calling confirmation | Keeper chooses from the 6 foundational callings |
| 6 | Deepening | Drift and synthesis across adjacent calling families allowed |
| 9 | Culmination | Loosened structure; cross-track movement valid |

*Current save gate: `calling_eligible = true` at `rank == 3` (V1 shape — superseded by V2-PROG-004)*

---

*Primary design source: `docs/Echoes vNext Working GDD.md` §11.4.5, §11.5, §11.9*
*Migration context: `docs/v2-migration-map.md` — Domain 2 (Calling)*
