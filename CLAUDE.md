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

**Parallel fan-out is yours, not a subagent's.** You may background agents and commands freely: you
are woken when they finish and can collect the results. **A subagent may never background anything**
— nothing wakes it, so the result is lost (root `AGENTS.md`). A nested orchestrator therefore cannot
parallelise; it dispatches in the foreground, sequentially. When work genuinely wants fan-out, run it
from here rather than delegating the fan-out itself.

### Long runs: you run them (Jeff, 2026-10-07)

Any command that can run longer than 2 minutes, and any background run, is run by you. This covers
measurement cells, probe slices, the sharded or full suite, and anything the tool would move to the
background. A subagent builds the probe or script, then ends its turn with a RUN REQUEST (the five
items are in root `AGENTS.md`). The subagent `game-orchestrator` follows the same rule: it cannot
run these either, so it hands you the request.

1. Run the command in the background with the `timeout` and `alarm` that `AGENTS.md` gives.
2. When it finishes, read the raw output. Do not rely on a summary.
3. Check that every file the run edits is back to its original (`cmp` against a saved copy).
4. Send the result to the subagent (`SendMessage`) so it can continue, or use it yourself.
5. Do not dispatch a subagent only to wait. A waiting subagent can lose its work when the session
   limit stops it, and it can leave an edited file behind.

*Why: on follow-up #6 two `opus` agents stopped on the session limit in the middle of long runs and
left `data/balance.json` changed. Judgement stays with the agent; the waiting stays with you.*

---

## Model tiers

**Every agent defaults to `sonnet`.** Opus is opt-in per call via the `model` parameter, which
overrides frontmatter. Never `fable`.

**Escalate to `opus`** only for: determinism or `EchoFactory` draw order · save-schema bridges ·
a moved recorded value needing attribution · diagnosing an unknown mechanism · a green suite that
proves nothing · combined-tree verification where either agent could mask the other.

**Use `haiku`** for clear, straightforward work that has a fixed procedure and a checkable
result — running a given script or command list and copying what it prints, log triage, copy
rewrites, label text, doc reflow, mechanical renames. Jeff widened this on 2026-10-07 (long
measurement runs were wasting `opus` budget). It is allowed only with these guardrails:

1. A stronger model writes the procedure first. Any file the run edits is restored by a `trap`
   or an equivalent step inside the script, so a killed run cannot leave it changed.
2. `haiku` judges nothing: no design choice, no attribution, no pass or fail verdict beyond what
   the command itself prints.
3. The main chat reads the raw output before it trusts a number, and checks that every edited
   file is back to its original.
4. New logic, design numbers, determinism, save schema and the analysis of results stay with
   `sonnet` or `opus`.

*Measured limit (older Haiku): on a 23-line bark rewrite haiku produced clean vocabulary
substitution but missed the creative brief, and personas flattened toward each other.
Mechanical and checkable: haiku. "Make this feel different": expect a second pass. Re-check this
limit when a newer Haiku becomes available to the chat.*

If unsure, run sonnet first. A sonnet pass that surfaces the real question costs less than an opus
pass that confirms there was none.

---

## Every agent writes in STE

Every agent communicates and writes in ASD Simplified Technical English (STE): reports, documents,
questions and replies. Put this rule in every brief. The core limits:

- One statement per sentence. Descriptive sentences ≤ 25 words; instructions ≤ 20 words.
- Active voice. One word for one meaning; define a technical term once, then use only that term.
- No idioms or metaphors. Use tables and numbered lists for rules and data.
- Code identifiers and file:line citations stay exactly as they are.

*Jeff, 2026-09-25: text that does double work is open to interpretation. See `docs/LESSONS.md` #26.*

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
4. **Record the answer** and feed it into the next dispatch. A story-specific answer goes to
   `docs/stories/<story-id>/decisions.md` (numbered D-01, D-02, …). Only a project-wide answer, one
   that later stories must follow, goes to `ANSWERS.md`. See `docs/LESSONS.md` #25.

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

Read `config/features` in `project.godot` for the live version (a 4.7 migration is
planned). Never hardcode a patch version. Confirm an engine API against the declared version, and
flag anything deprecated or renamed in 4.7 rather than adopting it silently.
