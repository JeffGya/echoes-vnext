# CLAUDE.md — orchestration contract for the main conversation

> **Scope:** this file is for Claude's main chat, which coordinates work rather than doing it.
> Codex and other agents: read `AGENTS.md` — it is the repository contract and it binds everyone.
> Subagent roles live in `.claude/agents/*.md` (gitignored, Claude-only).
>
> **This file points rather than restates.** If a rule is in `AGENTS.md`, it is not repeated here.

---

## Read before acting

1. `AGENTS.md` — the contract. Determinism, choke points, snapshot shape, `core/`↔`ui/` boundaries,
   naming, save discipline, test policy, comment rules. Small enough to read whole.
2. `docs/canon-index.md` — **grep it**, then `sed` the line range it returns. Never read
   `CONVENTIONS.md` or the Working GDD end to end; they are ~43,000 tokens each.
3. `docs/LESSONS.md` — corrected behaviours. Do not repeat them.
4. `ANSWERS.md` — recorded design decisions. Check before re-deciding anything.

Never write a plan or subtasks before reading the relevant files. This is the most frequently
corrected failure on this project.

---

## The roster

Nine subagents in `.claude/agents/`. Each file is the authority on its own role.

| Agent | Owns |
|---|---|
| `game-orchestrator` | Multi-discipline sequencing. Spawn only when work genuinely spans disciplines. |
| `sr-game-designer` | Vision, pillars, system design, GDD changes |
| `mid-game-designer` | Content specs, tuning values, `data/balance.json`, user stories, backlog (has Notion) |
| `mechanics-developer` | `core/` simulation, services, flow states, save schema |
| `game-feel-developer` | Polish, timing, feedback, transitions |
| `sr-game-artist` | Art direction, Living Grove design system |
| `technical-artist` | Shaders, VFX, render performance (GL Compatibility backend) |
| `ui-ux-designer` | `ui/` screens, shells, `.tscn` structure, accessibility |
| `qa-verifier` | Adversarial verification. No write tools, by design. |

**Do not spawn `game-orchestrator` for single-discipline work.** Its own contract says so. Route
straight to the specialist. An orchestrator spawn has cost 90,000–150,000 tokens; a direct dispatch
is a fraction of that.

---

## Sequencing

- **Backend before frontend.** All `core/` work completes and compiles before `ui/` starts.
- **Design before build.** A mechanic without an approved system design is not ready.
- **Polish last.** Never polish a mechanic that is still changing shape.
- **Verification is never self.** The agent that built a thing never verifies it.
- **Merged work gets combined verification.** Where two agents' output meets, one independent agent
  checks the combined tree, so neither can mask the other's mistake.
- **Every story ends with:** compile check → Jeff tests in-game → docs update → commit.

---

## Parallelism

Run agents together only when **all three** hold:

1. **Disjoint files** — neither writes a file or section the other writes.
2. **No shared exclusive resource.** The Godot binary, `/tmp/echoes-vnext-tests/`, and the test suite
   are exclusive. *Two agents ran the suite concurrently on 2026-09-12 and corrupted each other's
   fixtures while pushing load average past 50.*
3. **Disjoint recorded values** — two agents that would both re-record a fixture, golden constant or
   balance baseline stay serial. Parallel re-records destroy attribution.

Read-only research satisfies all three almost always. Parallelise those freely.

---

## Model tiers

**Every agent defaults to `sonnet`.** Opus is opt-in per call via the `model` parameter, which
overrides frontmatter. Never `fable`.

**Escalate to `opus`** only for: determinism or `EchoFactory` draw order · save-schema bridges ·
a moved recorded value needing attribution · diagnosing an unknown mechanism · a green suite that
proves nothing · combined-tree verification where either agent could mask the other.

**Use `haiku`** for text-only work that cannot change behaviour — copy rewrites, label text, doc
reflow, mechanical renames. *Measured limit: on a 23-line bark rewrite haiku produced clean
vocabulary substitution but missed the creative brief, and personas flattened toward each other.
Mechanical and checkable: haiku. "Make this feel different": expect a second pass.*

If unsure, run sonnet first. A sonnet pass that surfaces the real question costs less than an opus
pass that confirms there was none.

---

## Questions from agents reach Jeff through you

Subagents cannot reach him. Their reports return here, so **you are the only channel.**

Every agent ends its report with `## OPEN — questions and assumptions`, carrying `ASSUMED:` and
`BLOCKED:` lines. When one arrives:

1. **Re-check `BLOCKED` lines against the repo first.** If the answer exists, answer it and say
   where. Never spend Jeff's attention on something the repo already settles.
2. **Treat `ASSUMED` lines as questions.** An assumption that survived to the report is a decision
   made on his behalf. Surface any that would change the work if wrong.
3. **Ask one at a time via `AskUserQuestion`**, naming the agent that raised it. The `interview`
   skill runs this flow and accepts relayed questions as input.
4. **Record the answer** in `ANSWERS.md` and feed it into the next dispatch.

Never answer a relayed question on his behalf. Never drop one for looking minor.

---

## Decisions that are Jeff's, never yours

- **Player-facing copy.** Propose, mark clearly as proposals, stop. He is the designer.
- **Design numbers and scope.** Including anything the GDD has not settled.
- **Whether to build an unwired feature** versus delete it.
- **Commits and pushes.** Only when he asks.

---

## Scope control

Findings are not authorisation. If out-of-scope work looks necessary, useful or blocking, report it
and get explicit approval before anything mutates files, tests, identifiers or backlog state.

**One story, one subject.** If a branch grows a second subject, split it. Multi-subject stories are
a named root cause of this project's rework.

---

## Engine version

Read `config/features` in `project.godot` for the live version (4.6.x today; a 4.7 migration is
planned). Never hardcode a patch version. Confirm an engine API against the declared version, and
flag anything deprecated or renamed in 4.7 rather than adopting it silently.
