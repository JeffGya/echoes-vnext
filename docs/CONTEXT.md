# Echoes vNext — Project Context

> This file is the authoritative context document for AI coding sessions on this project.
> It combines working preferences, workflow rules, project identity, and environment notes.
> **Primary canon for design:** `docs/Echoes vNext Working GDD.md` — nothing overrides it.

---

## About the Project

**Echoes vNext** is a mythic house-and-trials strategy game built in **Godot 4.5.1 (GDScript, 100%)**.

The player is the **Ase Keeper** — they run a Sanctum, summon Echoes (returning names / fragments of stolen stories), and lead them through Realm trials to recover Threads and bring stolen stories home. The game is deterministic at its core, with a snapshot-driven UI layer.

- **GitHub:** https://github.com/JeffGya/echoes-vnext (public)
- **Notion workspace:** "Legacy Never Dies Game" → "Echoes vNext V2 Backlog Hub"
- **Notion DB ID (V2 backlog):** `d3dc9cb4-21e9-44fc-9229-238474907ed6`
- **Notion Hub ID:** `339c3d1ede92814da4c2dad94d650e30`
- **Notion Backlog Conventions:** `339c3d1ede9281509bcacb334bce5593`
- **Backlog size:** 168 stories across waves: Alignment / Foundation / Expansion / Full Game

---

## About the User

- **Name:** Jeffrey Gyamfi (Jeff)
- **Primary role:** UX Designer at ABN AMRO bank (~8 years experience)
- **Role on this project:** Designer. AI is the developer.
- **Relevant skills:** Deep UX/product design background; moderate GDScript familiarity.

---

## Working Preferences — ALWAYS FOLLOW THESE

1. **Clarify before assuming.** Never make assumptions. First instinct is to stop and ask, even mid-task.
2. **Confirm before changing.** Always ask for explicit confirmation before patching, editing, or updating any file. Never proceed without approval.
3. **Explain everything.** Beginner-friendly, detailed explanations. Refer back to earlier decisions. Avoid shifting approaches mid-project.
4. **Never skip steps.** Always read the repo before writing subtasks. Jeff will call this out if skipped.
5. **Role separation:** Jeff is the designer; AI is the developer. Only code what Jeff instructs. Never invent variables. Only improve existing code — never delete or change current code without instruction.
6. **Backend-first:** Always complete the backend fully before beginning any frontend work.
7. **No mid-task value changes:** Verify values across all relevant files before making changes. If unsure, ask to see the file first.
8. **Bugs vs. enhancements:** Fix bugs promptly. Track enhancements as new tasks — do not mix them.
9. **Every user story must end with a Docs + Commit subtask** (doc update/check and GitHub commit).
10. **Working GDD is primary canon.** `docs/Echoes vNext Working GDD.md` is the only authoritative design source. No other design document overrides it.
11. **GitHub commits at meaningful milestones** — after major backend work, major frontend work, or full task completion.

---

## Workflow Orchestration

### Planning
- Enter plan mode for ANY non-trivial task (3+ steps, multi-file changes, or architectural decisions).
- If anything goes sideways mid-task, STOP immediately and re-plan — do not keep pushing.
- Use plan mode for verification steps too, not just implementation.

### Subagent Strategy
- Use subagents liberally to keep the main context window clean.
- Offload research, codebase exploration, and parallel analysis to subagents.
- One task per subagent for focused execution.
- For complex problems, use parallel subagents.

### Self-Improvement Loop
- After ANY correction from Jeff: update `docs/LESSONS.md` with the pattern (rule + why + how to apply).
- Write rules that prevent the same mistake from recurring.
- Track mistake patterns so improvement is measurable over time.
- Review `docs/LESSONS.md` at the start of each session for relevant lessons.

### Verification Before Done
- Never mark a task complete without proving it works.
- Run tests, check logs, demonstrate correctness — or explicitly hand off to Jeff with clear instructions.
- Ask: "Would a staff engineer approve this?" before presenting work.

### Story Verification Workflow (every story — never skip or reorder)
1. **Run Godot terminal tests** via headless command:
   ```
   /opt/homebrew/bin/godot --headless --check-only --path /Users/jeffreygyamfi/Sites/echoes-vnext 2>&1
   ```
2. **Pause and ask Jeff to test in-game** — do not proceed until Jeff confirms the change feels correct in the running game.
3. **Docs + Commit** — only after Jeff signs off on the in-game test.

### Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant solution?"
- If a fix feels hacky, rebuild it properly.
- Skip this for simple, obvious fixes — don't over-engineer.

### Bug Fixing
- **Obvious single-file bugs:** fix immediately without asking for confirmation (overrides Rule #2 for this case only).
- **Multi-file or architectural bugs:** confirm before changing — scope and risk are too high.

### Task Flow (every story/task)
1. Plan first — write a plan with checkable items.
2. Verify plan — check in with Jeff before starting implementation.
3. Track progress — mark items complete as you go.
4. Explain changes — high-level summary at each meaningful step.
5. Document results.
6. Capture lessons — update `docs/LESSONS.md` after any correction.

### Core Quality Principles
- **Simplicity first:** Make every change as simple as possible. Minimal code impact.
- **No laziness:** Find root causes. No temporary fixes. Senior developer standards.
- **Minimal impact:** Changes should only touch what's necessary.

---

## Architecture at a Glance

```
core/   — Deterministic sim. No UI deps. Outputs snapshots + logs.
ui/     — Renders snapshots. Dispatches actions. Never touches sim state directly.
data/   — JSON configs (balance, actors, realms). Read-only inputs.
tests/  — Lightweight, deterministic. Run via Debug Panel `tests` command.
```

### Key Architectural Invariants
- Single campaign seed root → all RNG via `CampaignSeed.derive("dot.separated.path")`
- `FlowRuntime.dispatch(action)` is the **single choke point** (tick, logger, save, snapshot)
- Snapshot shape: `{ type, meta, data, actions }` — only source of truth for UI
- `snapshot.actions` is a **slot-keyed Dictionary** (not Array). Per-row actions dispatched by rows, never in snapshot.actions.
- Save: crash-safe (write `.tmp` → rename), additive repairs, schema_version 1
- Economy: settlement model (not frame-based); offline decay applied once per session on Continue
- One save slot forever.

### Coding Conventions
- `snake_case` folders, `PascalCase.gd` classes
- No `randomize()`, `rand()`, `randf()` anywhere in core
- All meaningful logs via `StructuredLogger`, not `print()`
- `t` (sim_tick) always injected by caller, never generated in core
- Action format: `domain.subdomain.verb`
- Snapshot actions in named slots: `primary`, `secondary`, `back`, `nav.*`, `cta.*`, `overlay.*`
- Per-row UI actions dispatched directly by rows — NOT in `snapshot.actions`

### UI Rules
- Build visual structure in `.tscn`, not `.gd`. Scripts only set values: `modulate`, `text`, `visible`, `disabled`.
- Never create, layout, or style UI nodes programmatically in `.gd` files.
- All layout, sizing, text defaults, theme variations belong in `.tscn` so Jeff can style in the Godot editor.

---

## V2 Migration State (Alignment Wave — started 2026-04-06)

Migrating from V1 idioms to V2 canonical design. Read `docs/v2-migration-map.md` before starting any Alignment story.

**V2 terminology is canonical for all new work:**
- `Storyweight` / `Standing` / `Step` — not `xp_total` / `rank` / `level`
- 10 virtue domains (Courage, Wisdom, Leadership, Acceptance, Humility, Forgiveness, Truth, Generosity, Compassion, Empathy) — not 4 legacy vectors
- `Scout Carefully` / `Seek Signs` — not `directive.scout` / `directive.none`
- Calling milestones at Standing 3 / 6 / 9 — not rank 3 gate

**V1 internal aliases still in save data** (`rank`, `level`, `xp_total`, old vector keys) — persist as compatibility fields until V2-MIG-002 ships. Do not delete; add V2 keys additively alongside.

**Alignment wave pickup order:**
1. V2-MIG-002 — Save schema bridge ✓ Done
2. V2-PROG-001 — Progression language rename ✓ Done
3. V2-PROG-002 — Calling seam unification ✓ Done
4. V2-PROG-003 — Vector expansion (4 → 10 virtue domains) ✓ Done
5. V2-PROG-004 — 6-calling set ✓ Done
6. V2-PROG-005 — Skill family foundation ✓ Done
7. V2-PROG-006 — Maturity-expression seam ✓ Done
8. V2-WEAVE-001 — Thread recovery model ✓ Done
9. V2-DIRECTIVE-001 — Directive rewrite (Scout Carefully / Seek Signs) — next
10. V2-SANCTUM-001+ — Building + Continuity system
11. V2-ECONOMY-001+ — Economy expansion

---

## Skills (use proactively — authoritative project knowledge)

Four project-specific skills are installed. Reference docs in `docs/skills/`.

| Skill | When to use |
|-------|-------------|
| `godot-echoes-dev` | Any implementation question — Godot 4.5 + GDScript dev patterns, architectural invariants, flow state IDs, action types, naming conventions |
| `echoes-sankofa-gdd` | Design decisions, feature scope, lore questions — V2 GDD knowledge base: callings, vectors, skill families, Weave system, Threads, Storyweight, Continuity |
| `echoes-backlog` | Look up stories, pickup order, wave, status — 168 stories via CSV + Notion MCP |
| `game-ui-ux-echoes` | New screens, layout decisions, emotion display — mobile-first UI/UX patterns, snapshot-to-screen mapping, touch targets, West African aesthetic |

---

## Environment Notes

- **Godot path:** `/opt/homebrew/bin/godot` (v4.6.1 stable, installed via Homebrew)
- **Headless compile check:** `/opt/homebrew/bin/godot --headless --check-only --path /Users/jeffreygyamfi/Sites/echoes-vnext 2>&1`
- **`raw.githubusercontent.com` is blocked** by egress proxy — always fetch GitHub files via `github.com/JeffGya/echoes-vnext/blob/main/<path>` using WebFetch.

---

## Key Docs Index

| File | Purpose |
|------|---------|
| `docs/Echoes vNext Working GDD.md` | **Primary canon. Only authoritative design source.** |
| `docs/MEMORY.md` | Systems inventory, architecture reference, migration state |
| `docs/LESSONS.md` | Corrected behaviours and validated patterns |
| `docs/CONTEXT.md` | This file — working preferences, workflow, environment |
| `docs/calling-reference.md` | Calling reference (V2-PROG-002; V1 IDs active until V2-PROG-004) |
| `docs/v2-migration-map.md` | V2 migration map — read before any Alignment story |
| `docs/art-direction.md` | Art direction and visual language |
| `docs/DesignSystem_LivingGrove_Complete_Guide.md` | Living Grove design system reference |
| `CONVENTIONS.md` | Contracts, action types, screen summaries, decisions made vs deferred |
| `docs/skills/` | Reference docs for all installed skills |
