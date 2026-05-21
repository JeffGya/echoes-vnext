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

## Standing-6 Expressions (V2-PROG-007 ✅ Done)

Two expressions per foundational calling. Selection pool at S6 = 2 from own calling + 2 from each adjacent calling = 6 total options. Adjacency ring governs availability; vectors provide the secondary fit signal (V2-PROG-009 work).

Data in `balance.json data.calling.definitions.[id].standing_6`. Queryable via calling definition block — no dedicated service function yet (V2-PROG-008).

| Calling | ID | Twi name | English scaffold | Descriptor |
|---|---|---|---|---|
| `okofor` | `okyefo_kesee` | Ɔkyɛfo Kɛseɛ | Great Ward | deepens into greater protection and wider safeguarding |
| `okofor` | `asa_okyefo` | Asa-Ɔkyɛfo | Storm Guard | hardens protection into forceful answer and counter-pressure |
| `aduro` | `asafo` | Asafo | War Captain | deepens into collective courage and war-company momentum |
| `aduro` | `twaese` | Twaesɛ | Splitfang | turns force toward disruption, timing, and opening-breaking |
| `sum_okwanfo` | `ntontamfafo` | Ntontamfafo | Web-Passer | deepens concealment into web-path mastery and unseen passage |
| `sum_okwanfo` | `sunsum_ahoma` | Sunsum Ahoma | Shadow Thread | leans into sabotage, hidden intervention, and surgical disruption |
| `kra_soro` | `okwansoani` | Ɔkwansoani | Pathfinder | deepens field-reading into route mastery and recon precision |
| `kra_soro` | `wiemhwefo` | Wiemhwɛfo | Sky Watcher | turns field sense toward anticipation, range control, and far-seeing watch |
| `okomfo` | `kranimfo` | Kranimfo | Spirit Knower | deepens spirit-reading into omen authority and hidden-truth knowing |
| `okomfo` | `ogyafo` | Ogyafo | Flame Keeper | turns insight toward sacred thresholds, ritual control, and keeping the flame |
| `onyamesu` | `opanyin` | Opanyin | Elder | deepens care into communal memory, moral weight, and elder presence |
| `onyamesu` | `sunsum_kyere` | Sunsum Kyerɛ | Soulbinder | turns sustaining care toward memory-binding, threshold tending, and the living-dead bridge |

---

## Standing-9 Culminations (V2-PROG-007 ✅ Done)

Two culminations per Standing-6 expression (24 total). Structure is locked per GDD §11. Names marked `twi_provisional: true` have English scaffolds only — Twi names need cultural validation before ship.

Data in `balance.json data.calling.definitions.[id].standing_9`.

| Parent S6 | ID | Twi name | English scaffold | twi_provisional |
|---|---|---|---|---|
| `okyefo_kesee` | `nyamedua_okyefo` | Nyamedua Ɔkyɛfo | Nyamedua's Ward | false |
| `okyefo_kesee` | `grove_bastion` | _(needs Twi)_ | Grove Bastion | true |
| `asa_okyefo` | `storm_crown` | _(needs Twi)_ | Storm Crown | true |
| `asa_okyefo` | `war_ward_sentinel` | _(needs Twi)_ | War-Ward Sentinel | true |
| `asafo` | `asante_ohene_kobo` | Asante Ɔhene Kɔbɔ | Asante War-Chief | false |
| `asafo` | `asafohene` | Asafohene | War Captain | false |
| `twaese` | `red_fang` | _(needs Twi)_ | Red Fang | true |
| `twaese` | `web_cleaver` | _(needs Twi)_ | Web-Cleaver | true |
| `ntontamfafo` | `veiled_passage` | _(needs Twi)_ | Veiled Passage | true |
| `ntontamfafo` | `hidden_web` | _(needs Twi)_ | Hidden Web | true |
| `sunsum_ahoma` | `shadow_web` | _(needs Twi)_ | Shadow Web | true |
| `sunsum_ahoma` | `whisper_knot` | _(needs Twi)_ | Whisper Knot | true |
| `okwansoani` | `sankofa_wanderer` | _(needs Twi)_ | Sankofa Wanderer | true |
| `okwansoani` | `far_road_captain` | _(needs Twi)_ | Far Road Captain | true |
| `wiemhwefo` | `star_watch` | _(needs Twi)_ | Star Watch | true |
| `wiemhwefo` | `horizon_judge` | _(needs Twi)_ | Horizon Judge | true |
| `kranimfo` | `spirit_sage` | _(needs Twi)_ | Spirit Sage | true |
| `kranimfo` | `memory_listener` | _(needs Twi)_ | Memory Listener | true |
| `ogyafo` | `ananse_kasa` | Ananse Kasa | Anansi's Voice | false |
| `ogyafo` | `flame_of_thresholds` | _(needs Twi)_ | Flame of Thresholds | true |
| `opanyin` | `abosom_tena_ho` | Abosom Tena Hɔ | Abosom Anchor | false |
| `opanyin` | `root_elder` | _(needs Twi)_ | Root Elder | true |
| `sunsum_kyere` | `samanfo_nkyen` | Samanfo Nkyɛn | Ancestor Vessel | false |
| `sunsum_kyere` | `bridge_of_names` | _(needs Twi)_ | Bridge of Names | true |

---

## Adjacency Ring — Data-Driven (V2-PROG-007 ✅ Done)

The calling adjacency ring is now encoded as config data, not hardcoded logic.

**Data:** `balance.json data.calling.adjacency`
**Query:** `CallingService.get_adjacent_callings(calling_id, calling_cfg) → Array[String]`
**Config integrity guard:** `CallingService.validate_config_integrity(calling_cfg, logger, t)` — called at balance load via `ConfigService.load_balance()`.

| Calling | Left neighbour | Right neighbour |
|---|---|---|
| `okofor` | `onyamesu` | `aduro` |
| `aduro` | `okofor` | `sum_okwanfo` |
| `sum_okwanfo` | `aduro` | `kra_soro` |
| `kra_soro` | `sum_okwanfo` | `okomfo` |
| `okomfo` | `kra_soro` | `onyamesu` |
| `onyamesu` | `okomfo` | `okofor` |

---

*Primary design source: `docs/Echoes vNext Working GDD.md` §11.4.5, §11.5, §11.9*
*Migration context: `docs/v2-migration-map.md` — Domain 2 (Calling)*
