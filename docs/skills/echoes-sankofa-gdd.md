# GDD Knowledge Base — Echoes vNext Design Reference

> Complete V2 design knowledge: pillars, glossary, callings, virtue domains, skill families, Weave system, Threads, Storyweight, Continuity, and the Anansi narrative frame.
> Primary canon is still `docs/Echoes vNext Working GDD.md` — this document distills and navigates it.

**Claude Code:** invoke as `/echoes-sankofa-gdd` or `anthropic-skills:echoes-sankofa-gdd`
**Codex / any agent:** read this file directly — all knowledge is self-contained here.

## When to consult this document
- Making any design decision or scoping a feature
- Answering lore or narrative questions
- Checking calling identities, virtue domain names, or system definitions
- Understanding Weave, Threads, or Continuity mechanics

---

## Key Design Pillars

1. **Stories are alive** — Echoes are returning fragments of stolen stories, not just characters. Every action carries narrative weight.
2. **Sankofa principle** — "Go back and fetch it." Recovery, not just progression. The game is about bringing things home.
3. **Deterministic fate, meaningful choice** — The world is seeded; what matters is what you do within it.
4. **Emotional truth** — Fear and Morale are mechanical. They shape what Echoes can and cannot do.
5. **West African mythic frame** — Anansi narrative structure. The Keeper is a steward, not a commander.

---

## V2 Terminology Glossary

| V2 Term | V1 Term | Meaning |
|---------|---------|---------|
| Storyweight | xp_total | Accumulated experience expressed as narrative weight |
| Standing | rank | Current tier of growth (1–9) |
| Step | level | Fine-grained position within a Standing |
| Virtue domain | vector | One of 10 dimensions of character identity |
| Calling | calling | The echo's fundamental nature/role |
| Thread | — | A fragment of a stolen story to be recovered |
| Continuity | — | The Sanctum's accumulated legacy state |
| Ase | — | Primary spendable currency (life-force energy) |
| Ekwan | — | Secondary currency for buildings/crafting |
| Sanctum | — | The Keeper's home base |
| Weave | — | The system connecting Threads to narrative recovery |

---

## The 6 Callings (V2)

Callings define an echo's fundamental nature. Milestone unlocks at Standing 3, 6, 9.

| Calling | Core Identity |
|---------|--------------|
| Ward | Protector — shields allies, absorbs harm |
| Break | Aggressor — shatters defenses, pushes through |
| Veil | Deceiver/Infiltrator — conceals, misdirects |
| Path | Guide/Scout — opens routes, reads terrain |
| Rite | Ritualist — channels power, maintains order |
| Root | Anchor — stabilises, grounds, sustains |

---

## The 10 Virtue Domains (V2)

Replace the legacy 4 vectors. All new work uses these:

1. Courage
2. Wisdom
3. Leadership
4. Acceptance
5. Humility
6. Forgiveness
7. Truth
8. Generosity
9. Compassion
10. Empathy

`dominant_vector` is the highest-scoring domain (3% hysteresis to switch). CLAMP_MAX=1000.

---

## Skill Families (V2-PROG-005)

Six skill families aligned to callings:

| Family | Aligned Calling |
|--------|----------------|
| Ward skills | Ward |
| Break skills | Break |
| Veil skills | Veil |
| Path skills | Path |
| Rite skills | Rite |
| Root skills | Root |

`MAX_SKILL_SLOTS=1` per echo currently. Skill loadout handled at StageMap (not a dedicated screen).

---

## Weave System (V2-WEAVE-001)

The Weave is the system through which stolen stories are recovered. Key concepts:
- **Threads** — fragments of a stolen story. Collected through Realm trials.
- **Thread recovery** — the act of bringing a Thread back to the Sanctum.
- **Weave progress** — accumulates as Threads are recovered. Drives narrative resolution.

---

## Emotional Mechanics

- **Morale tiers:** inspired / steady / shaken / broken
- **Fear threshold:** fear ≥ 80 → Absolute Fear Rule → echo refuses to act
- `EmotionService` is the single choke point for morale/fear mutations
- Emotion state is initialised once per echo (`init_echo()` is idempotent)

---

## Maturity Expression (V2-PROG-006)

Echoes express their maturity through four bands based on Standing:

| Band | Standing Range | Presence Strength |
|------|---------------|------------------|
| nascent | 1–2 | 0.1 |
| forming | 3–5 | 0.25 |
| grounded | 6–8 | 0.5 |
| whole | 9 | 1.0 |

Config lives under `balance.data.maturity_expression`.

---

## Economy (V2)

| Layer | Items |
|---|---|
| Spendable currencies | Ase (summoning, rites, Thread handling), Ekwan (rooms, crafting, buildings), Relics (rare artifacts) |
| Visible states | Faith, Harmony, Favor |
| Progression states | Continuity, Threads, Realm recovery track |

Exact values and cadences are open — see Working GDD `Economy` section.

---

## Anansi Narrative Frame

The overarching structure is Anansi's web — stories stolen from their rightful owners, scattered across Realms, waiting to be recovered. The Keeper is not a hero but a steward who helps Echoes find their way home. Every Realm is a stolen story. Every Thread recovered is a piece of something brought back.

---

## Related Files
- `docs/Echoes vNext Working GDD.md` — **primary canon**
- `docs/calling-reference.md` — calling reference detail
- `docs/v2-migration-map.md` — V1→V2 migration map
- `core/progression/` — skill and progression implementation
- `core/actors/VectorService.gd` — virtue domain tracking
- `core/actors/MaturityExpressionService.gd` — maturity expression
