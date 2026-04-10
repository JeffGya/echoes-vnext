# Skills Reference — Echoes vNext

Reference documents for all AI agents working on this project. Each file is self-contained knowledge — read directly, no invocation required.

**Claude Code** can also invoke these as skills (slash commands). The invocation shortcut is noted in each file's header.
**Codex and other agents** read the files directly from `docs/skills/`.

---

## Echoes-Specific References

| File | Topic | When to read |
|------|-------|-------------|
| `godot-echoes-dev.md` | GDScript + Godot 4.5 dev patterns | Any implementation work — flow states, services, tests, action types, snapshot shape |
| `echoes-sankofa-gdd.md` | V2 design knowledge base | Design decisions, lore, callings, virtue domains, Weave/Threads, V2 terminology |
| `echoes-backlog.md` | V2 story backlog (168 stories) | Story lookup, pickup order, wave/status, dependencies |
| `game-ui-ux-echoes.md` | Mobile-first UI/UX patterns | New screens, layout, snapshot-to-screen mapping, emotion display, West African aesthetic |

## Design & UX Reference

| File | Topic | When to read |
|------|-------|-------------|
| `ui-ux-skills-reference.md` | User research, critique, handoff, copy, accessibility, Living Grove design system | Any UX process or design system work |

---

## Quick Lookup

| Question | File |
|----------|------|
| What flow state ID should I use? | `godot-echoes-dev.md` |
| What does `snapshot.actions` look like? | `godot-echoes-dev.md` |
| How do I add a new service / flow state / test? | `godot-echoes-dev.md` |
| What is a Calling? A Thread? Storyweight? | `echoes-sankofa-gdd.md` |
| What are the 10 virtue domains? | `echoes-sankofa-gdd.md` |
| What story is next in the backlog? | `echoes-backlog.md` |
| Which shell does this screen belong to? | `game-ui-ux-echoes.md` |
| What touch target size do I use? | `game-ui-ux-echoes.md` |
| How should morale be displayed? | `game-ui-ux-echoes.md` |
| How do I write CTA copy for this screen? | `ui-ux-skills-reference.md` |
| What design tokens are available? | `ui-ux-skills-reference.md` → Living Grove |
