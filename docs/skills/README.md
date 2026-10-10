# Skills Reference — Echoes vNext

This folder is the home of the project's agent knowledge. The files route you to the canon and give the checklists. They do not copy the canon.

**Claude Code:** global skills of the same names are thin triggers that point to these files. **Codex and other agents:** read the files directly from `docs/skills/`.

**Canon first:** the Working GDD is the only design canon. Look up terms with `docs/canon-index.md`. Rules are in `AGENTS.md` and `ui/AGENTS.md`.

---

## Echoes-Specific References

| File | Topic | When to read |
|------|-------|-------------|
| `godot-echoes-dev.md` | Checklists: flow state, action, service, test | Any `core/` implementation work |
| `echoes-sankofa-gdd.md` | Routing from a design term to its GDD section | Design decisions, lore, callings, Weave, Threads, V2 terms |
| `echoes-backlog.md` | How to read the V2 story backlog CSV | Story lookup, order, wave, status, dependencies |
| `game-ui-ux-echoes.md` | Landscape-first UI patterns for Echoes | New screens, layout, emotion display, aesthetic direction |
| `echoes-visual-plan/` | HTML visual planning skill folder | UX/game-feel HTML prototypes with player journeys, wireframes, friction notes, improvement prompts, and playtest checks |

---

## Quick Lookup

| Question | File |
|----------|------|
| What flow state ID should I use? | `core/state/flow/FlowStateIds.gd` (checklist: `godot-echoes-dev.md`) |
| What does `snapshot.actions` look like? | `AGENTS.md` "Action Shape" |
| How do I add a new service / flow state / test? | `godot-echoes-dev.md` |
| How do I export the implemented player journey as a visual prototype? | `echoes-visual-plan/` |
| What is a Calling? A Thread? Storyweight? | `echoes-sankofa-gdd.md` (routes to the GDD) |
| What are the virtue domains? | `echoes-sankofa-gdd.md` (routes to the GDD) |
| Which story is next in a wave? | `echoes-backlog.md` (the CSV gives the `Order`; confirm the live status in Notion, because the CSV can lag) |
| Which shell does this screen belong to? | `game-ui-ux-echoes.md` |
| What touch target size do I use? | `game-ui-ux-echoes.md` |
| How should emotion be displayed? | `game-ui-ux-echoes.md` |
| What design tokens are available? | `docs/Living_Grove_Design_System.md` (still in progress) |
