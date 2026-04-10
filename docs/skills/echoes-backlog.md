# Story Backlog Reference — Echoes vNext V2

> 168-story V2 backlog. Use to look up stories by ID, find the current pickup order, check status, or understand wave/epic groupings.

**Claude Code:** invoke as `/echoes-backlog` or `anthropic-skills:echoes-backlog` (queries Notion MCP live)
**Codex / any agent:** read the local CSV at `docs/Echoes vNext V2 Story Backlog d3dc9cb421e944fc9229238474907ed6_all.csv` and use the structure below to navigate it.

## When to consult this document
- Looking up a specific story (e.g. "what does V2-PROG-007 do?")
- Finding the next story to pick up in a wave
- Checking story dependencies or exit criteria
- Understanding which stories are Done, In Progress, or queued

---

## Backlog Sources

| Source | Details | Access |
|--------|---------|--------|
| Local CSV | `docs/Echoes vNext V2 Story Backlog d3dc9cb421e944fc9229238474907ed6_all.csv` | All agents |
| Notion DB | `d3dc9cb4-21e9-44fc-9229-238474907ed6` | Claude Code (Notion MCP) |
| Notion Hub | `339c3d1ede92814da4c2dad94d650e30` | Claude Code (Notion MCP) |
| Backlog Conventions | `339c3d1ede9281509bcacb334bce5593` | Claude Code (Notion MCP) |

---

## Backlog Structure

### Waves
Stories are grouped into waves indicating when they ship:

| Wave | Focus |
|------|-------|
| Alignment | V1→V2 migration, terminology, architecture corrections |
| Foundation | Core gameplay loops, Sanctum, Realms, combat |
| Expansion | Economy, Continuity, Weave, advanced systems |
| Full Game | Polish, narrative, end-state features |

### Story ID Format
`V2-[AREA]-[###]` e.g. `V2-PROG-001`, `V2-MIG-002`, `V2-WEAVE-001`

### Common Story Areas
- `MIG` — Migration (V1→V2 alignment)
- `PROG` — Progression (callings, vectors, skills, maturity)
- `WEAVE` — Weave + Thread recovery
- `SANCTUM` — Sanctum systems (buildings, rooms, Continuity)
- `ECONOMY` — Economy expansion (Ekwan, Relics, Faith/Harmony/Favor)
- `DIRECTIVE` — Directive system (Scout Carefully / Seek Signs)
- `COMBAT` — Combat refinements
- `VOICE` — Bark/voice systems (deferred — no event bus yet)

---

## Alignment Wave Status (as of 2026-04-10)

| Story | Title | Status |
|-------|-------|--------|
| V2-MIG-001 | V1→V2 migration foundation | Done |
| V2-MIG-002 | Save schema bridge | Done |
| V2-PROG-001 | Progression language rename | Done |
| V2-PROG-002 | Calling seam unification | Done |
| V2-PROG-003 | Vector expansion (4→10) | Done |
| V2-PROG-004 | 6-calling set | Done |
| V2-PROG-005 | Skill family foundation | Done |
| V2-PROG-006 | Maturity-expression seam | Done |
| V2-WEAVE-001 | Thread recovery model | Done |
| V2-DIRECTIVE-001 | Directive rewrite | Next up |

---

## How to Query

**Claude Code:** the `echoes-backlog` skill queries Notion live via MCP.

**Codex / any agent:** read the local CSV:
```
docs/Echoes vNext V2 Story Backlog d3dc9cb421e944fc9229238474907ed6_all.csv
```
CSV columns to filter on:
- `Status` — Done / In Progress / Ready / Backlog
- `Wave` — Alignment / Foundation / Expansion / Full Game
- `System Area` — PROG / MIG / WEAVE / etc.
- `Order` — pickup sequence within wave
- `Dependencies` — prerequisite story IDs

**Notion IDs (for agents with Notion access):**
- DB: `d3dc9cb4-21e9-44fc-9229-238474907ed6`
- Hub: `339c3d1ede92814da4c2dad94d650e30`
- Conventions page: `339c3d1ede9281509bcacb334bce5593`

---

## Related Files
- `docs/v2-migration-map.md` — read before any Alignment story
- `docs/CONTEXT.md` — current migration state summary
- `docs/MEMORY.md` — alignment wave pickup order
