# Claude Memory — Jeffrey Gyamfi

## About the User
- **Name:** Jeffrey Gyamfi (Jeff)
- **Email:** jeffogya@gmail.com
- **Location:** Amsterdam, Netherlands
- **Primary role:** UX Designer at ABN AMRO bank (~8 years experience); actively looking for a new UX or Product Design position in Amsterdam
- **Side projects:** Game development (Echoes vNext)

---

## Working Preferences — ALWAYS FOLLOW THESE

1. **Clarify before assuming.** Never make assumptions. First instinct should be to stop and ask, even mid-task. Ask before proceeding when anything is unclear.
2. **Confirm before changing.** Always ask for explicit confirmation before patching, editing, or updating any file. Never proceed with changes without approval.
3. **Explain everything.** Maintain beginner-friendly, detailed explanations. Refer back to earlier decisions when helpful. Avoid shifting approaches mid-project.
4. **Never skip steps.** e.g. always read the repo before writing subtasks — Jeff will call this out if skipped.
5. **Role separation:** Jeff is the designer; You are the developer. Only code what Jeff instructs. Never add or invent variables. Only improve existing code — never delete or change current code without instruction.
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
- For complex problems, throw more compute at it via parallel subagents.

### Self-Improvement Loop
- After ANY correction from Jeff: update `~/.claude/lessons.md` with the pattern (rule + why + how to apply).
- Write rules that prevent the same mistake from recurring.
- Track mistake patterns so improvement is measurable over time.
- Review `~/.claude/lessons.md` at the start of each session for relevant lessons.

### Verification Before Done
- Never mark a task complete without proving it works.
- Run tests, check logs, demonstrate correctness — or explicitly hand off to Jeff with clear instructions.
- Ask: "Would a staff engineer approve this?" before presenting work.
- Diff behaviour between main and changed code when relevant.

### Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant solution?"
- If a fix feels hacky, rebuild it: "Knowing everything I know now, implement the elegant solution."
- Skip this for simple, obvious fixes — don't over-engineer.

### Bug Fixing
- **Obvious single-file bugs:** fix immediately without asking for confirmation (overrides Rule #2 for this case only).
- **Multi-file or architectural bugs:** still confirm before changing — scope and risk are too high.
- Point at logs, errors, and failing tests; then resolve them. Zero context-switching required from Jeff.

### Task Flow (every story/task)
1. Plan first — write a plan with checkable items.
2. Verify plan — check in with Jeff before starting implementation.
3. Track progress — mark items complete as you go.
4. Explain changes — high-level summary at each meaningful step.
5. Document results.
6. Capture lessons — update `~/.claude/lessons.md` after any correction.

### Core Quality Principles
- **Simplicity first:** Make every change as simple as possible. Minimal code impact.
- **No laziness:** Find root causes. No temporary fixes. Senior developer standards.
- **Minimal impact:** Changes should only touch what's necessary. Avoid introducing bugs.

---

## Active Projects

### 1. Echoes vNext (Game Dev)

Godot 4 (GDScript, 100%) deterministic mythic house-and-trials strategy game with grid-based combat, emotion mechanics, Sanctum systems, and realm progression.

- **GitHub:** https://github.com/JeffGya/echoes-vnext (public)
- **Notion workspace:** "Legacy Never Dies Game" → "Echoes vNext V2 Backlog Hub"
- **Notion DB ID (V2 backlog):** `d3dc9cb4-21e9-44fc-9229-238474907ed6` | Hub: `339c3d1ede92814da4c2dad94d650e30`
- **Working GDD is primary canon:** `docs/Echoes vNext Working GDD.md`

**Architecture reference:** `CONVENTIONS.md` in repo root — contracts, action types, screen summaries, decisions made vs deferred.
**Project status + file map:** `MEMORY.md` (auto-loaded via memory system) — systems inventory, architecture reference.

#### Skills (use proactively — authoritative project knowledge)

- **`godot-echoes-dev`** — Godot 4.5 + GDScript dev patterns: architectural invariants, all flow state IDs, all action types, naming conventions, checklists for adding new states/services/tests. **Use for any implementation question.**
- **`echoes-sankofa-gdd`** — V2 GDD knowledge base: design pillars, glossary, callings, vectors, skill families, Weave system, Threads, Storyweight, Continuity, Anansi narrative frame. **Use for design decisions, feature scope, lore questions.**
- **`echoes-backlog`** — V2 story backlog via CSV + Notion MCP. 168 stories. **Use to look up stories, pickup order, wave, status.**
- **`game-ui-ux-echoes`** — Mobile-first UI/UX patterns: snapshot-to-screen mapping, touch targets (48×48dp min), screen inventory, West African aesthetic. **Use for new screens, layout decisions, emotion display.**

#### GitHub Access Note
- `raw.githubusercontent.com` is **blocked** by egress proxy in this environment
- Always fetch files via `github.com/JeffGya/echoes-vnext/blob/main/<path>` using WebFetch

---

## Important Lessons Learned (Game Dev)

1. **Always read the GitHub repo before writing subtasks.** Jeff explicitly requires this every time. Never skip it even if Notion context seems sufficient. Jeff will correct this if ignored.
2. **Slot-keyed Dictionary for actions — always.** Jeff had to manually correct SANCTUM-003 because Array-style actions were used. Hard rule for all new code and subtasks.
3. **Per-row actions are NOT in snapshot.actions.** Row interactions (toggle, select) are dispatched by UI rows directly.
4. **Confirm contracts in Subtask 1 of every story** before building anything.
5. **Never reorder EchoFactory RNG draws.** Only append new draws at end; bump version string if added.
6. **No IDs in player-facing display.** `party_slots` shows name/level/rank only — no `id` fields shown to player.
7. **Array actions are legacy.** Only UISnapshotRenderer uses them. All flow states now use slot-keyed Dict.
8. **Shell owns shared nav, not the snapshot.** When all sanctum-family screens need the same nav bar, put it in the shell with a cached-nav pattern. Do NOT inject nav into every state's snapshot — that creates unnecessary coupling and forces changes to unrelated states (SummonState, PartyManageState, etc.).
9. **`refresh_snapshot()` does NOT re-call `enter()`.** For non-SANCTUM states, `FlowStateMachine._rebuild_snapshot()` reads `ctx.last_snapshot` as-is. To update a mid-state snapshot (e.g. after `grade_select`), use the `static func build_snapshot()` pattern: handler calls the static builder directly, assigns to `ctx.last_snapshot`, then calls `refresh_snapshot()` for validation only.
10. **Test isolation: set balance directly, don't use `economy.ase.add`.** `_make_runtime_env()` loads the real save file. Tests that need a controlled balance must set `save_data["economy"]["ase"] = value` directly on the save ref — never via `economy.ase.add` (which adds ON TOP of existing save balance).
11. **Grade table lives under `data.summoning`, not `data.economy`.** Notion story said `data.economy` — codebase reads summoning config from `data.summoning` via `summ_cfg`. Always verify where FlowRuntime actually reads a config key before placing it in balance.json.
