# Story Backlog — Echoes vNext V2

**Source:** the backlog CSV in `docs/` (`Echoes vNext V2 Story Backlog d3dc9cb421e944fc9229238474907ed6_all.csv`). Notion is the live copy. The CSV can lag Notion. Check Notion when status matters. Notion IDs: see `docs/MEMORY.md`.

**Claude Code:** the skill `echoes-backlog` points here. **Codex / any agent:** read the CSV with the steps below.

## When to read this file
- Look up a story, its wave, its order, its dependencies or its exit criteria.

## How to read the CSV
- Read the row count from the CSV. Do not quote a fixed count.
- Filter on these columns: `Code`, `Prefix`, `Status`, `Wave`, `Order`, `Dependencies`, `Source GDD`.
- `Status` is Ready, Draft or Superseded. Superseded rows keep older information. For the current story, filter `Status != Superseded`. One `Code` can appear on several rows.
- `Order` rises within a wave. Waves: Foundation, Alignment, Expansion, Full Game.
- `Code` is `V2-<AREA>-nnn`. `MIG` in a code is `MIGRATION` in `Prefix`. List the other prefixes from the CSV: read the distinct `Prefix` values.
- Exit criteria are in `Exit Criteria`, `Definition of Done` and `Spec State`.

## Related files
- `docs/v2-migration-map.md` — read before any Alignment story
- `docs/CONTEXT.md` — migration state summary
