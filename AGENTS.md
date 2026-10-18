# Echoes vNext — Agent Instructions

> **For:** OpenAI Codex and any AI coding agent working in this repository.
> **Design canon:** `docs/Echoes vNext Working GDD.md` — nothing overrides it.
> **Architecture reference:** `CONVENTIONS.md` — full contracts, action types, system contracts.
> **Context + workflow:** `docs/CONTEXT.md` — working preferences, role separation, task flow.
> **Lessons learned:** `docs/LESSONS.md` — corrected behaviours. Read before starting any task.

---

## Project Identity

Godot 4 GDScript strategy game (engine version: `config/features` in `project.godot`). Deterministic core simulation with snapshot-driven UI.
The player runs a Sanctum, summons Echoes (returning fragments of stolen stories), and leads them through Realm trials.

**Stack:** 100% GDScript. No web, no TypeScript, no Python. Godot 4 only.

---

## How to Run & Verify

> **`--path` must be the checkout you are editing.** If you work in a git worktree
> (`.claude/worktrees/<branch>/`), pass that path. The literal path below is the main
> checkout and is usually on a different branch — running it verifies the wrong code.

> **Never run Godot on the default Bash timeout.** The tool auto-backgrounds at 120s, and **a
> backgrounded run cannot notify a subagent** — it finishes without waking the agent and the result
> is lost. This has cost this project many agent-hours. Each command below carries the `timeout` and
> `alarm` it needs. Pass them. Never tune one down.
>
> **Backgrounding permission differs by layer.** The MAIN conversation may background freely: it is
> woken when the work finishes and can collect the result. **A SUBAGENT may never background
> anything** — not a Bash command, not another agent. Nothing wakes it. Where work wants parallel
> fan-out, a subagent recommends the fan-out and the main conversation runs it.
>
> **Long runs belong to the main conversation.** A subagent does not run a command that can take
> longer than 2 minutes, and it does not wait on one. This covers every measurement cell, probe
> slice, sharded or full suite run, and any command the tool would move to the background. The
> subagent builds the probe or script, then ends its turn with a RUN REQUEST. The main conversation
> runs it, checks the result, and sends the output back to the subagent or uses it to continue.
> Short filtered runs (`tests <filter>`, the compile check, `--import`) stay with the subagent.
> A RUN REQUEST states: (1) the exact command, with the `timeout` and `alarm` to pass; (2) the
> expected duration; (3) every file the run edits, and the step inside the script that restores it
> (a `trap`); (4) how to verify the restore; (5) which output to read back.

### Compile check (no editor needed)
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --check-only --quit --path <checkout>
```
Run this after every GDScript change. Zero errors expected.

### Rebuild the script class cache — do this FIRST when a new `class_name` file exists
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 400 /opt/homebrew/bin/godot --headless --import --path <checkout>
```
`--check-only` does **not** register a brand-new `class_name`, so you get
`Identifier "X" not declared`. Worse, a stale cache makes **existing fingerprint tests fail
with drifted hashes** — indistinguishable from a real regression. Five agents in a row have
lost a cycle investigating "pre-existing failures" that a rebuild cleared. Rebuild before you
believe any fingerprint failure.

### Tests
Tests run inside Godot via the Debug Panel (`F1` → `tests`) or headlessly. There is no
standalone CLI runner — Godot must execute them.

Full suite — **pass `timeout: 3700000`**, never 300000 or 600000, and the `alarm` below. Its
duration grows with the test count and swings with machine load, so no figure is recorded here:
this file has carried three in turn and each went stale. A too-high timeout costs nothing; a
too-low one loses the whole run:
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests
```
**One suite only (~5s)** — use this while working, and the full suite once at the end:
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests vow
```
The filter is a case-insensitive substring match on the suite name. **A filter that matches nothing prints the
suite list, runs zero tests, and emits NO `Tests:` line — while still exiting 0. Skim past that and
it reads as a pass.** Always confirm a `Tests:` line came back. Suite names are not file names:
`Stage004SeamTests` registers as `seam`, so the filter `stage004` matches nothing.

**Get the authoritative list from the runner, never from memory or a planning doc.** Regenerate it
(the regex includes `.` so dotted suite names like `sanctum.layout` are not dropped):
```bash
<godot ...> -- tests __nomatch__ 2>&1 | sed -n 's/.*Debug output "  \([a-z0-9_.]*\)"/\1/p'
```
The 131 registered suite names (115 captured 2026-09-20, nine camera and pointer suites, `skill_reach`, `stop_short`, `stop_short_wiring`, `stop_short_search`, `directive_char`, `contact_cfg` and `stage_stop_ui` added since; post-`fingerprint`-suite split — see below.
A `seam`-suite split was also tried, measured to give no speedup, and reverted — `seam` remains
one suite):
```
actor arbiter archetype bark_popup behavior behavior_arbiter behavior_char bond_trigger
bridge calling calling_behavior combat combat_baseline combat_initiative
combat_roundtrip combat_terrain combat_ui consequence contact contact_actor continuity
conversation_repair contact_cfg cooldown derived directive directive_cfg directive_char divergence divergence_bark
echo_party echofactory economy emotion exclusive_action explore explore_p5 expr
fingerprint_combat fingerprint_determinism_combat fingerprint_determinism_endure
fingerprint_determinism_guide_spirit fingerprint_determinism_protect
fingerprint_determinism_purify_shrine fingerprint_determinism_pursue
fingerprint_determinism_recover fingerprint_endure fingerprint_guide_spirit
fingerprint_protect fingerprint_purify_shrine fingerprint_pursue fingerprint_recover
flow_transaction foundation_ui grid guidance guidance_bark identity institution intel
ko_death leadership live_movement_style maturity_baseline melee morale movement
movement_arbiter movement_fallback movement_option movement_path movement_style
objective objective_combat old_echo onboarding passive pending_result prog realm
realm_prog realm_reward realm_ui recruit retreat reward sanctum.layout sanctum.party
sanctum.summon sanctum_pulse save_integrity seam shrine sit_res situational skill
skill_loadout skill_reach skill_unlock stage_stop_ui stop_short stop_short_search stop_short_wiring
snapshot snapshot_contract snapshot_fingerprint snapshot_purity social_graph stage
statinit structure support terrain thread trace traversal unified_resolve vector
venture_char voice vow weave
```
Added since that capture: `board_camera.bounds board_camera.echo_detail board_camera.input
board_camera.view board_camera.zoom board_camera.pointer board_pointer combat_camera stage_camera`,
`directive_char`, `contact_cfg` and `stage_stop_ui`. This list can be stale: run the command above, or
`scripts/check-shard-map.sh`, which compares the live list with the shard map.
Names that look right and are WRONG: `guide_spirit` (it is under `movement`), `stage_explore`
(it is `explore`), `stage_objective` (it is `objective`), `stage004` (it is `seam`),
`fingerprint` (now `fingerprint_combat`, `fingerprint_purify_shrine`, `fingerprint_recover`,
`fingerprint_protect`, `fingerprint_endure`, `fingerprint_pursue`, `fingerprint_guide_spirit`,
plus their determinism-check counterparts `fingerprint_determinism_combat`,
`fingerprint_determinism_purify_shrine`, `fingerprint_determinism_recover`,
`fingerprint_determinism_protect`, `fingerprint_determinism_endure`,
`fingerprint_determinism_pursue`, `fingerprint_determinism_guide_spirit` — no bare `fingerprint`
or `fingerprint_determinism_self_check` suite exists any more).
 `tests snapshot` matches
`snapshot`, `snapshot_contract`, `snapshot_fingerprint` and `snapshot_purity`. An unmatched
filter prints the available suite names and runs nothing.

**Exact-match mode — `tests =<name1>,<name2>,...`.** A leading `=` switches from substring
containment to case-insensitive suite-name EQUALITY, comma-separated, so a caller can isolate a
suite whose name is a literal substring of a sibling's (`tests =combat_roundtrip` runs only that
suite, not `combat`/`combat_terrain`/`combat_baseline` too). Additive: plain `tests <filter>`
substring behaviour is unchanged. Built for scripted/sharded runs; still usable interactively.

### Save isolation — DELETE THE WHOLE SAVE DIRECTORY BEFORE EVERY RUN

Suites write saves into a shared directory under `/tmp`, by default `/tmp/echoes-vnext-tests/`.
**Stale files there silently corrupt results and produce false failures that survive a cache
rebuild.** Always start a verification run with the delete:

```bash
rm -rf /tmp/echoes-vnext-tests && <godot ... -- tests>
```

**The root is configurable.** Set `ECHOES_TEST_SAVE_DIR` to point every save artifact this
project writes during a test or a probe at a directory of your choosing instead of the shared
default (a missing trailing separator is normalized). Leaving it unset reproduces today's
behaviour byte-for-byte — same path, same `rm -rf /tmp/echoes-vnext-tests` cleanup. This is what
makes parallel Godot runs possible: see "Agent Orchestration" below. Delete whichever directory
you used before every run, custom or default — the contamination risk described next applies
equally to both.

**Why the delete matters.** `SaveService` writes six artifacts beside the primary save —
`.pending_a`, `.pending_b`, `.tmp`, `.bak1`, `.bak2`, `.bak3`
([SaveService.gd:173-181](core/save/SaveService.gd:173)). It returns `LOAD_MISSING` only when *no*
artifact exists ([SaveService.gd:116-118](core/save/SaveService.gd:116)). A helper that deletes
only the primary therefore leaves a recoverable backup, `boot()` never reaches
`make_new_save(<pinned seed>)`, and the test **resumes a previous run's campaign** — other
balances, other XP, another map, another hash. The production behaviour is correct; recovering from
a backup is what a crash-safe save system is for. The test harness is what is wrong.

Two tells that you are looking at contamination rather than a real regression:
- the "actual" hash **changes between identical runs**, or differs between a filtered and a full run
- a payload diff shows every integer arrived as a float (`43` → `43.0`) — that is a JSON round-trip,
  so the data was read back off disk instead of generated

**Never run two Godot processes against this project at the same time.** They share that directory
and contaminate each other. This applies to parallel subagents: serialize every test run.

### Reading the result — the runner ALWAYS exits 0
Exit status is not evidence. Only this line is:
```
Tests: 1442 total, 1442 passed, 0 failed
```
Pipe output to a file and grep the file. **Never re-run the suite to read a different field** —
the answer is already in the output you discarded.

**Targeted runs — use these while iterating (V2-INFRA-003).** `tests <filter>` runs only suites
whose reported name matches, case-insensitively, as a substring. `tests prog` runs the progression
suites in seconds instead of the whole 1600+ in minutes. `tests snapshot` catches `snapshot_purity`,
`snapshot_contract` and `snapshot_fingerprint` together. An unmatched filter prints the available
suites.

```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --quit --path "$(git rev-parse --show-toplevel)" -- tests prog
```

**Timing output (2026-10-18).** Every run ends with a timing report after the suite lines: one
`TIMING_SUITE ms=<n> tests=<n> suite=<name>` line per suite (slowest first), then the 20 slowest tests as
`TIMING_TEST ms=<n> name=<name>`. `CoreTestRunner` measures each test with `Time.get_ticks_msec`.
The `Tests:` line is unchanged. The sharded script merges the shard reports into one table of the
20 slowest tests and the 15 slowest suites, and writes `timing-suites.txt` and `timing-tests.txt` to its log directory.
The times are wall-clock inside one process. They grow when processes compete for cores.

**Who may run the FULL suite:** only the orchestrator and the QA/verification role. Every other
agent runs the compile check plus a FILTERED run at most, and asks for a full run rather than
starting one. A full run takes minutes and blocks the machine.

### Sharded full-suite runs (parallel, same restriction as the FULL suite)

**Pass `timeout: 3600000` (60 minutes) on the Bash call that runs this script.** The run takes about 18
minutes on 4 cores and about 31 minutes on 2 cores. A shorter timeout risks the failure that is called out
above for the full serial suite: the tool moves the run to the background, a subagent is never notified,
and the work is lost.

```bash
scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"
```

Environment variables (all optional):

| Variable | Meaning | Default |
|---|---|---|
| `GODOT_BIN` | Godot binary | `/opt/homebrew/bin/godot` |
| `SHARD_JOBS` | How many shards run at the same time | number of CPU cores (`getconf _NPROCESSORS_ONLN`) |
| `ALARM_SCALE` | Integer that multiplies every shard alarm. Never below 1. Use a value above 1 on a slower or busier machine, or when `SHARD_JOBS` is above the core count. | 1 |
| `SHARD_MAP_FILE` | Another shard map, for example one suite per shard to measure suite times | `scripts/test-shard-map.sh` |

**`movement_fallback` in a sharded run (changed 2026-10-18).** `MovementFallbackGuardTests` reads a
process-wide ledger of legacy-selector fallbacks (`ActorStateMachine.legacy_selector_uses`). In its
own shard it saw only that shard's suites. It now runs in a separate **merge step** after all shards,
and it judges the ledgers of every shard:
1. Each shard process that has `ECHOES_TEST_SAVE_DIR` set writes its ledger to
   `<save dir>/legacy_selector_ledger.json` after its last test (`tests/LegacyLedgerFile.gd`).
2. The script runs one more Godot process: `tests =movement_fallback` with `ECHOES_LEGACY_LEDGER_IN` set to
   the shard ledger files. The process loads the entries before its first test. The guard test is unchanged.
3. `movement_fallback` is in `MERGE_SUITES` (`scripts/test-shard-map.sh`) and in no shard. The combined total
   still equals the serial total. A shard that writes no ledger makes the run INVALID (exit 1), like a
   missing `Tests:` line. A ledger file that cannot be read fails the guard and names the file.
4. The serial run keeps its in-process guard. Without `ECHOES_TEST_SAVE_DIR` nothing is written.

**What the serial guard really judges (Jeff, 2026-10-18: "match the serial verdict").**
`behavior_char/legacy_selector_fallback_is_loud` calls `take_legacy_selector_uses()` at its start. That
clears every entry that suites registered BEFORE it recorded. The serial guard therefore judges only the
entries recorded at or after that test (today only `pending_result`). On 2026-10-18 `combat_roundtrip`
recorded 57 real fallbacks (`perceived_actor_kind_mismatch`, `guide_spirit_01`) that the serial guard
never sees. The sharded run copies the serial rule: each shard sets aside the entries recorded before
that test as "ignored". The merge step prints them as a WARNING and does not judge them. The sharded verdict
equals the serial verdict. If `behavior_char/legacy_selector_fallback_is_loud` is renamed, change
`LegacyLedgerFile.SERIAL_WIPE_TEST` in the same commit; otherwise the merge step fails and says so.
Whether to remove the clearing is a decision for Jeff (open follow-up).

**How a sharded run works.** The script first runs `scripts/check-shard-map.sh` (see below). Then it starts
the shards of `scripts/test-shard-map.sh` in map order, at most `SHARD_JOBS` at a time. A finished shard frees
its slot for the next one. Each shard is one headless Godot process with its own `ECHOES_TEST_SAVE_DIR`
under `/tmp/echoes-vnext-sharded/saves/` and one call `tests =<exact suite names>`. After the last shard the
script runs the `movement_fallback` merge step, adds up every `Tests: N total, N passed, M failed` line,
and prints the timing tables. Wall-clock time is set by the longest shard, not by `serial time / shard count`.

**Measured on 2026-10-18 (4-core cloud machine, Godot 4.6-stable, 2194 tests):**

| Run | Wall-clock |
|---|---|
| Serial full suite (reported, Oct 2026) | about 53 min |
| Sharded, 9 shards of the Sept 2026 map, all at once | 22m33s |
| Sharded, 12 shards from measured times, 4 at a time | **17m40s** |

All test time added up is 3637 s (60.6 min). The longest suite is `reward` at 1054 s, and one test in it,
`reward/pace_guide_spirit_runtime_escort_vs_protect`, takes 991 s. A suite is never split, so about 1058 s
(17.6 min) is the best wall-clock time for any shard count or core count, until a slow test changes. Five tests
take 2527 s, which is 69% of all test time: `reward/pace_guide_spirit_runtime_escort_vs_protect` (991 s),
`fingerprint_determinism_guide_spirit` (775 s), `combat_baseline/emotion_trace_guide_spirit` (281 s),
`fingerprint_guide_spirit` (279 s) and `fingerprint_determinism_pursue` (201 s). Cutting the cost of these
tests is the next gain. It needs a decision by Jeff and is not part of the runner work.

**Shard map and counts.** The map has 12 shards and one merge suite for the 131 registered suites. The runner
checks the map before it starts a shard (`scripts/check-shard-map.sh`, see above). The comment at the top of
`scripts/test-shard-map.sh` describes how the map was packed and how to pack it again from new timing data
(`scripts/rebalance-shards.sh`). Update the counts in this file in the same commit that changes the map.

**Per-shard alarm is a HANG CEILING, not an expected duration.** The runner waits for each shard to exit
on its own. A shard that finishes early does not wait out its alarm. The alarm kills a shard only if it is
still running after that many seconds. Three verification passes on 2026-09-20 mistook an alarm value
for a run time. Read the real duration from the `elapsed_secs=` line at the end of the shard log. Each map
entry has its own alarm in its third field: 4 times its estimated time, never below 600 s.

If any shard's log has no `Tests:` line, the script fails (exit 1) and does not treat it as a pass. This
is the same trap as an unmatched filter, which runs nothing and exits 0.

**Same restriction as the full suite: only the orchestrator and the QA/verification role may run it.** It
starts several Godot processes that write to disk. Do not run it next to anything else that touches
`/tmp/echoes-vnext-*`.

**Always run the FULL suite before committing.** This codebase has cross-cutting guards — a
one-file change has broken tests in unrelated suites more than once (the dispatch-action count
guard, and a UI test that wired nodes from another screen). Filter while iterating; never ship on a
filtered run alone. The sharded run is a full run: since 2026-10-18 it also judges `movement_fallback`
on the ledgers of all shards (see above), with the same verdict as the serial run. Choose one full mode
(sharded or serial) and run it once.

**Only ONE suite run at a time.** Tests share `/tmp/echoes-vnext-tests/`; two concurrent runs
corrupt each other's save fixtures.

**Test suites** (all in `tests/`):
EconomyTests, SanctumSummonTests, PartyTests, ActorTests, EchoSchemaTests, ActorStatInitTests,
DerivedStatTests, BehaviorModuleTests, MeleeTests, BehaviorArbiterTests, StructureTests,
MoraleInfluenceTests, KODeathTests, EmotionTests, VectorTests, DirectiveTests, GridTests,
CombatStateTests, CombatServiceTests, CombatRoundTests, CombatSnapshotTests, RetreatTests,
ArchetypeTests, StageProgressionTests, SkillDefinitionTests, CallingBehaviorTests,
ExclusiveActionTests, CooldownTests, PassiveIdentityTests, SkillLoadoutTests,
MaturityExpressionTests, ThreadServiceTests, VowServiceTests, SocialGraphTests

---

## Repo Structure

```
core/       Deterministic simulation. No UI deps. Pure GDScript.
  actors/       Actor model, behavior, stats, emotion
  combat/       Combat resolution, shrine, retreat
  config/       ConfigService — loads data/balance.json
  directives/   DirectiveService
  economy/      EconomyService
  emotion/      EmotionService
  grid/         GridService (10×10 board)
  log/          StructuredLogger
  progression/  Skill definitions, thread service
  realms/       RealmModel, RealmService, RealmGenerator
  runtime/      FlowRuntime (single dispatch choke point)
  sanctum/      EchoFactory, SanctumService, SummonService, SocialGraphService, VowService
  save/         SaveService + schema
  state/        FlowStateMachine, FlowContext, FlowStateIds, all flow states

ui/         Snapshot renderer. Dispatches actions. No sim state access.
  shells/       SanctumShell, RealmShell
  screens/      One .tscn + .gd per screen. ScreenTemplate.gd is the base.
  components/   Reusable UI components
  overlays/     Modal/overlay nodes

data/       Read-only JSON configs
  balance.json  All tuning values — ConfigService loads this

tests/      Deterministic unit test suites

docs/       Project documentation
  CONTEXT.md          Working preferences + workflow (read first)
  MEMORY.md           Systems inventory + architecture reference
  LESSONS.md          Corrected behaviours — read before starting
  skills/             Skill reference docs (godot-echoes-dev, echoes-sankofa-gdd, etc.)
  Echoes vNext Working GDD.md   Primary design canon
  v2-migration-map.md           V1→V2 migration map

CONVENTIONS.md    Full architecture contracts
```

---

## Non-Negotiable Rules

### Scope Control — never overreach
- Do not perform work beyond the requester-defined scope. Audit findings are not authorization to fix adjacent issues.
- If out-of-scope work appears necessary, useful, or blocking, report it and obtain explicit requester approval before mutating files, external tools, tasks, identifiers, dependencies, or backlog state.

### Determinism — never break these
- No `OS.get_unix_time()`, `randf()`, `randomize()`, `rand()` anywhere in `core/`
- All RNG via `CampaignSeed.derive("dot.separated.path")` → `RandomNumberGenerator`
- Sim tick `t: int` always injected by caller — never generated inside a service
- Never reorder `EchoFactory` RNG draws — only append at end; bump version string

### Single Choke Points — never bypass
- `FlowRuntime.dispatch(action)` — only entry for all state mutations
- `EconomyService` — only entry for Ase/Ekwan mutations
- `EmotionService` — only entry for emotion mutations outside mid-combat direct writes
- `SaveService` — only entry for persistence; one flush per dispatch tick

### Code Boundaries — never cross
- `core/` has zero UI node refs or Godot scene tree calls
- `ui/` never calls `dispatch()` directly, except `AppRoot.gd`, the UI host that dispatches the action requests screens emit; `ui/` never reads `FlowContext`, `SaveService`, or any sim internal
- `data/` is read-only; schema changes are additive only (never remove or rename existing fields)
  - **Exception (V2-PROG-012 precedent):** a rename/removal is permitted when the old name is actively misleading or its value was unreachable (silently falling through to a code default), provided **every** consumer is migrated in the same change and no alias is left behind. V2-PROG-012 renamed four keys under this exception — `presence_dampen_scale` → `composure_dampen_scale`, `directive_band_mul` → `directive_interpretation_mul`, per-calling `absolute_fear_threshold` → `absolute_fear_offset`, `vector_to_virtue_primary` → `virtue_vector_key` — after auditing every `core/`, `ui/`, `tests/`, and `docs/` reference. Default to the additive-only rule; reach for this exception only with the same full-repo audit, and say so in the story writeup.

### Snapshot Shape — always enforce
```gdscript
{
  "type":    String,      # e.g. "flow.sanctum", "flow.encounter"
  "meta":    Dictionary,  # { t: int, ... }
  "data":    Dictionary,  # state-specific payload
  "actions": Dictionary   # slot-keyed — NEVER an Array
}
```
- `snapshot.actions` is always a **slot-keyed Dictionary** — never an Array
- Slot names: `nav.*`, `cta.*`, `overlay.*`, `primary`, `secondary`, `back`
- Per-row UI interactions (toggle, select) are dispatched by the row — never put in `snapshot.actions`

### Action Shape
```gdscript
{
  "type":     String,   # domain.subdomain.verb
  "slot":     String,   # matches key in snapshot.actions
  "label":    String,   # optional UI label
  "disabled": bool,     # optional — slot present but inactive
  "to":       String,   # optional — for flow.go_state
  "payload":  {}        # optional
}
```
Action type format: `domain.subdomain.verb` e.g. `flow.go_state`, `sanctum.party.toggle`

### Save Discipline
- Additive-only — never remove or rename fields in `save_data`
- Add new fields with safe defaults; old fields stay as compatibility aliases
- `flow_ctx.save_request = true` → FlowRuntime flushes once per dispatch tick
- Crash-safe: write to `.tmp` → rename to final path

### Actor Contract
- Actor dicts are **read-only views** — deep-copied at construction
- 18 REQUIRED_FIELDS checked by `ActorSchema.validate()` (see `CONVENTIONS.md`)
- Access top-level fields directly: `actor["speed"]` not `actor["stats"]["speed"]`
- `current_hp`, `speed`, `morale`, `fear` are top-level, NOT inside `stats`

---

## Agent Orchestration

### Pick the model tier from the difficulty of the work

Set the model explicitly on every delegated call. Omitting it silently inherits the session model.

| Tier | Use it for |
|---|---|
| `haiku` | Clear, mechanical work with a checkable result: renames from an approved table, boilerplate, format conversion, log triage, running a given script and copying its output (guardrails in `CLAUDE.md`, Model tiers) |
| `sonnet` | The default. Well-specified implementation with clear acceptance criteria |
| `opus` | Genuinely tricky work: concurrency, subtle algorithms, adversarial verification, gnarly debugging |

Choose by difficulty, not by a fixed build-versus-review split. A diagnosis of an unknown mechanism
is `opus` work even when the fix that follows is `sonnet` work. Split a task across two tiers when
its halves differ.

### Run agents in parallel whenever it is safe

Parallelize by default. Two agents may run together only when all three conditions hold.

1. **Disjoint files.** Neither agent writes a file or a section the other writes.
2. **No shared exclusive resource.** **In this project that means Godot.** Every test run writes
   saves under `/tmp/echoes-vnext-tests/` by default, and that default is a hardcoded absolute
   path, so **a git worktree alone does not isolate two Godot processes** — a worktree changes the
   checkout, not `/tmp`. Two Godot processes that share a save directory corrupt each other's
   saves. **Parallel Godot runs are possible now**, but only when each agent sets its own
   `ECHOES_TEST_SAVE_DIR` (see "Save isolation" above) to a distinct directory before launching.
   Two agents that leave the variable unset, or that set it to the same path, still corrupt each
   other and must run serially.
3. **Disjoint recorded values.** Two agents that would re-record the same fingerprint or baseline
   constant stay serial **even when their files differ**. Parallel re-records destroy attribution:
   you get one large set of moved values and no way to say which change caused which.

Read-only research and design agents satisfy all three almost always. Run those in parallel freely.

### Verification is central, and never self

- A builder never verifies its own work.
- Where the work of two or more agents merges, an independent agent verifies the **combined** tree,
  so the agents cannot mask each other's mistakes.
- The verifier inspects `git diff`, the source and the real `Tests:` line. **Never accept a
  completion report as evidence.** Check the tree yourself.
- Give the verifier the claim to attack, not the answer to confirm. Ask it to prove the builder
  wrong. This works: a `sonnet` agent once concluded a reported defect did not exist, and an `opus`
  verifier then reproduced it and found the real cause.

### After any agent stops, killed or completed, audit the tree read-only before re-dispatching

A killed agent can leave a tree that reads as finished and is not — for example a harness change
whose comment claims constants were re-recorded when the agent died before recording them. Read the
diff. Do not trust the file's own description of itself.

---

## Extraction & Refactor Rules

Learned the hard way during V2-INFRA-003, which took `FlowRuntime.gd` from 10,061 lines to 1,972.

### Extract shared services BEFORE the controllers that need them
Dependencies point from controllers to services, so services must exist first. If you extract a
controller while a helper it needs is still private on `FlowRuntime`, that controller has no legal
option — reaching back is forbidden, and so is duplicating. It will invent a workaround.

### A helper used by two or more domains has an owner. Find it.
- Reads a named subtree of `balance.json` → a static getter on `ConfigService`, beside
  `get_bond_thresholds_cfg` and friends. **Not** on a pure domain service: `EmotionService`,
  `SocialGraphService` and `MaturityExpressionService` all document that they never read
  `ConfigService` and only accept passed-in dicts. Giving them one breaks their own invariant.
- Reads save data for a domain → a **static** function on that domain's service.
- Wraps a domain class → a service placed **beside** that class
  (`VowConsequenceService` with `VowService`, `NarrativeVoiceService` with `ShoutBank`).

### Never duplicate a helper. Never substitute a lookalike API either.
Copying is banned — two copies drift. But the second-order mistake is worse: when copying is
forbidden, the tempting move is to reach for an existing public API that *looks* equivalent.
A real example: `_get_active_party_echoes()` (a pure `.get()` read, roster order) was swapped for
`SanctumService.new(save_data).get_party_actors()`. That changed iteration order, changed the data
shape, and introduced a **constructor that can write to save data**. Every test still passed.

If a helper has no clean owner, **stop and report a blocker.** Do not work around it.

### Constructing a service can mutate. Prefer static reads.
`SanctumService.new(save_ref)` builds `SanctumState`, which can call
`_ensure_sanctum_dict_exists()` and write to `save_data`. Never construct a service merely to read.
Use a static reader, or add one.

### Controllers vs services
- **Controller** — owns dispatched actions for one domain. Returns a `FlowActionOutcome` describing
  transition / snapshot / save intent. `FlowRuntime.dispatch()` applies that intent. Give it no
  `flow_machine`, so it *cannot* transition by itself.
- **Service** — consequence hooks and shared logic called from several domains. Any controller or
  service may call it.
- **Controllers must never call one another.** If two controllers need the same behaviour, it is a
  service.
- Neither may call `SaveService`. Request a save with `flow_ctx.request_save(reason)`.

### Tests that reach in by string name break silently
`runtime.call("_private_name", …)` is invisible to `--check-only`, so moving that method fails only
at runtime. Find these before extracting, and **rewrite the call site in the same change**. Do not
leave a delegating shim on `FlowRuntime` — a shim keeps the test green while proving nothing.

### File size and comments

**Aim to keep files under ~1,000 lines — and the guard counts CODE, not comments or blanks.**
Measure with `grep -vcE '^\s*(#|$)' <file>`, not `wc -l`.

- **Do not fragment a file to satisfy the number.** A new file must earn its existence by owning
  something. Splitting for a line count produces the same tangle spread across more files, which is
  harder to follow, not easier.
- **Core central files may exceed it**, with a written justification in the header saying why the
  content is one unit.

**Comments: write what a reader needs, not the history of the change.**

| Belongs in the file | Belongs elsewhere |
|---|---|
| What this file owns, in a few lines | How it came to be here — that is the commit message |
| A constraint that prevents a mistake: a determinism hazard, a load-bearing order, a shared-state trap | Alternatives considered and rejected |
| A defect note at the site, one or two lines | The full defect analysis — that belongs in the owning story's record |
| | Slice numbers, phase names and process narrative |

**Verify a claim against the source it cites, not the document repeating it.** A doc that quotes
canon can misquote it, and the misquote then spreads to whoever trusts the doc. When a document
attributes something to the GDD, `CONVENTIONS.md`, a story, or a commit, open that source before you
act on it. If they disagree, the repeating document is the one to fix.

Three instances on this project, all within one session: a code comment describing intent that was
never implemented; `docs/v2-migration-map.md` rendering the GDD's "5 to 10 Steps per Standing" as
"5-10 Standings total", which then reached a commit message and a PR body; and this file's own test
filter reported as nonexistent twice by someone who had read only part of `_run_tests()`.

**Never treat a comment as evidence.** Comments go stale silently; code does not. Verify the
behaviour, then decide whether the comment still describes it. A comment that disagrees with the
code is a finding, not an instruction — and it is usually the comment that is wrong. If you relied
on one to reach a conclusion, say so, because your conclusion is only as good as that comment.

**Delete legacy and superseded comments when you encounter them.** A comment describing code that has
moved, or naming a story that has been renumbered, is not explanation — it is a trap. It also costs
parse time and reader attention for nothing.

### Characterization before behaviour change
Record what the code does today, including its bugs, and label each one
`# KNOWN DEFECT (<story> will change this):`. Invert the assertion in the phase that fixes it.
A probe that asserts the fixed behaviour before the fix exists tempts the next agent to "fix"
production code to make its own test pass.

---

## Naming Conventions

- Folders: `snake_case` (`core/state`, `ui/screens`)
- Scripts: `PascalCase.gd` — one class per file
- Data files: `snake_case.json`
- IDs and action types: `snake_case` strings using `domain.subdomain.verb`
- Logging: use `StructuredLogger.info(t, type, msg, data)` — never `print()`

---

## UI Rules

### Visual-first player communication

- For every player-facing fact, first ask whether world behavior, composition,
  animation, posture, orientation, proximity, lighting, VFX, sound, portraits,
  icons, gauges, or persistent world change can communicate it. Text clarifies the
  visual read; it must not carry the whole system by default.
- Follow this information order: world behavior, spatial UI, compact contextual UI,
  then optional reference UI. Use more than one channel for important outcomes.
- Protect the current critical focus area and arrange supporting information along
  the player's eye flow. Show only what matters in the current context.
- Match visual weight to urgency. A non-actionable signal cannot look blocking, and
  routine information cannot compete with a major beat.
- Judge primary compositions at 1920×1080 and test worst-case density. A short glance
  should reveal participants, direction of change, next action, and unresolved state
  without reading every sentence.
- Apply these rules to all future work, not only Sanctum or prototype UI. Review
  `prototypes/sanctum_systems_exploration/SPEC.md`, section 29, when relevant.

- **Build structure in `.tscn`** — scripts render values and apply profile values such as margins, columns, visibility, wrap widths, and min/max sizes
- Never create/reparent the UI hierarchy or construct visual styles programmatically in `.gd`; layout relationships and theme hooks belong in `.tscn`
- Reusable visual treatments belong in `assets/theme/LivingTreeSystem.tres`; extend the theme instead of restyling the same patterns per scene
- The responsive base is 1280×720 landscape; desktop starts at 1600×900 and may resize down to a minimum layout of 1280×720 logical, with a check at 1920×1080 (decision D-39: the game never runs at 960×540)
- Responsive means profile recomposition, capped readable UI, and spatial surplus on wide views — not uniform root scaling or scroll containers everywhere
- `SanctumShell` owns the inset BottomRail via `_cached_nav` — do NOT inject nav into snapshots
- `RealmShell` owns the inset, capped EchoBar (88 logical units high) — do NOT render it in individual screens
- Screens reserve safe edges and persistent bottom chrome; full-bleed spatial presentation may extend beyond the safe frame, actionable content may not
- AppRoot owns the single layer-40 blocking `ModalHost`; shell screens request modals by id and payload
- Blocking modal roots cover all chrome, stop underlying input, contain focus, and restore prior focus on dismissal
- Minimum target 48×48; primary CTA height 56; adjacent targets keep at least 8 units separation
- Canonical layers: world 0, screen 10, persistent chrome 20, non-modal transient 30, blocking modal 40, recovery/debug 128
- Every shell-owned `CanvasLayer` must mirror inherited shell visibility so hidden Realm/Sanctum layers cannot draw or intercept input
- No IDs in player-facing display — show names, standings, callings only

---

## Shell Routing

| Shell | Snapshot types |
|-------|---------------|
| `SanctumShell` | `flow.sanctum`, `flow.summon`, `flow.echo_party`, `flow.realm_select`, `flow.vow_manage`, `flow.weaving_rite` |
| `RealmShell` | `flow.stage_map`, `flow.stage`, `flow.stage_explore`, `flow.encounter`, `flow.keeper_trial`, `flow.resolve` |

AppRoot routes on `snapshot.type`. Shell routes to bespoke screen.

---

## V2 Terminology (use these, not V1 aliases)

| V2 (use this) | V1 (avoid) |
|---------------|-----------|
| `Storyweight` | `xp_total` |
| `Standing` | `rank` |
| `Step` | `level` |
| Virtue domain (10 domains) | vector (4 legacy) |
| `Scout Carefully` | `directive.scout` |
| `Seek Signs` | `directive.none` |
| Calling milestones at Standing 3/6/9 | rank 3 gate |

V1 aliases still exist in save data as compatibility fields — do not delete them; add V2 keys additively.

---

## V2 Alignment Wave — Current State (2026-04-10)

| Story | Status |
|-------|--------|
| V2-MIG-002 — Save schema bridge | Done |
| V2-PROG-001 — Progression language rename | Done |
| V2-PROG-002 — Calling seam unification | Done |
| V2-PROG-003 — Vector expansion (4→10) | Done |
| V2-PROG-004 — 6-calling set | Done |
| V2-PROG-005 — Skill family foundation | Done |
| V2-PROG-006 — Maturity-expression seam | Done |
| V2-WEAVE-001 — Thread recovery model | Done |
| V2-DIRECTIVE-001 — Directive rewrite | Done |
| V2-DIRECTIVE-002 — Profile-sensitive Directives | Phase A Done (accessor, legacy-key fix, data-only Directives); B+C and D pending |

Read `docs/v2-migration-map.md` before starting any Alignment story.

---

## Common Mistakes — Do Not Repeat

1. Using Array for `snapshot.actions` — always slot-keyed Dictionary
2. Putting per-row actions in `snapshot.actions` — rows dispatch directly
3. Calling `economy.ase.add` in tests — set `save_data["economy"]["ase"] = value` directly
4. Placing config keys in the wrong `balance.json` section — grep where FlowRuntime reads them first
5. Calling `refresh_snapshot()` expecting it to re-run `enter()` — it only re-reads `ctx.last_snapshot`
6. Creating UI nodes in `.gd` — all structure goes in `.tscn`
7. Reordering EchoFactory RNG draws — append only, bump version string
8. Uniformly scaling the whole UI on wide screens — cap UI and expose more spatial field
9. Adding a scroll container to solve every responsive problem — recompose primary layouts first
10. Letting autowrap determine first-pass geometry without authored/profile wrap widths
11. Leaving stale offsets on a full-rect container after changing responsive profiles
12. Hiding a shell Control without synchronizing its independent `CanvasLayer` visibility/input
13. Running Godot on the default Bash timeout — it auto-backgrounds at 120s and a subagent then loses all its work. Use the `timeout` and `alarm` given per command under **Tests**. A subagent may never background anything; the main conversation may.
14. Believing a fingerprint failure before rebuilding the script class cache with `--import`
15. Trusting the runner's exit code — it is always 0; only the `Tests: N total, N passed, M failed` line is evidence
16. Re-running the full suite to read a different field instead of grepping the log you already produced
17. Dispatching `flow.new_game` in a characterization test — `_generate_seed_root_string()` uses `Crypto.generate_random_bytes()`, so the campaign seed differs every run. Drive onboarding from `boot()`, which uses the pinned literal seed when no save exists
18. Constructing a service just to read from it — `SanctumService.new()` can write to `save_data` via `SanctumState._ensure_sanctum_dict_exists()`. Use a static reader
19. Duplicating a shared helper, **or** swapping in a lookalike API to avoid duplicating it. Both drift. If a helper has no clean owner, stop and report a blocker
20. Leaving a delegating shim on `FlowRuntime` so a reflection-based test keeps passing — the shim proves the extraction did *not* happen
21. Diagnosing a fingerprint failure without first deleting the shared `/tmp` save directory — a leftover `.bak1` makes the harness resume an old campaign, and the failure looks exactly like a real regression through a cache rebuild, a clean checkout and four repeat runs
22. Running two Godot test processes concurrently — they share the save directory and corrupt each other's results
23. Re-baselining a fingerprint constant to make the suite green before you can explain what moved — a constant you recalibrated without understanding is worse than no guard, because it still looks like protection
24. Reading a filtered run as green without checking a `Tests:` line came back — an unmatched filter runs nothing, prints nothing, and exits 0. Suite names differ from file names (`Stage004SeamTests` registers as `seam`)

25. **Writing a brief that overrides this file.** An orchestrator's task brief is read *after* AGENTS.md and wins on contradiction. On V2-COMBAT-003 every brief demanded full-suite verification and restated "rebuild the import cache" as an unconditional step, so agents ran five ~7-minute suites per commit and reimported before each one — while line 55 of this file already said "one suite only while working, and the full suite once at the end". The rule did not fail; the brief overrode it. **Point briefs at this file. Do not restate its rules in your own words, and never state a conditional rule (mistake 14) without its condition.**
26. **Reproduction runs on a deterministic suite.** Re-running an identical suite to check a result "is stable" proves nothing here: seeds are pinned, there is no wall clock, and `core/` makes no `randf()` call. Two identical runs cost 14 minutes and carry the information of one. Run the suite again only when the change could move determinism itself — seeding, dispatch order, draw counts.
27. **Rigour that does not scale with risk.** The predict-then-observe attribution method (predict a moved value from the numbers, then observe it, then show a structural invariant held) is mandatory when a change moves recorded values. Applying it to a mechanical rename or a config migration with no new values costs a custom probe, ~200k tokens and ~70 tool calls for a two-function edit. Match the method to the blast radius.
28. **Comments that restate the code, repeat themselves, or narrate history.** Measured on this branch: one ~50-line fix added **61** comment lines, a duplicate-helper fix added **69**, the islands commit added **289**. The failure modes, in order of frequency: the same point made at the call site *and* in the docstring; a sentence that says what the next line plainly says; and story-id narrative ("V2-PROG-003 grew the vectors from 4 to 10") that belongs in the commit message.

    **A comment earns its place only by saying what the code cannot** — a non-obvious constraint, an invariant a future edit would break, a trap, or a decision whose alternative looks equally reasonable. Write it once, at the authority, not at every caller.

    **Where things go:** why the change was made → commit message. Design rationale and measurements → the story's handoff or `docs/`. What a reader needs *at that line* to avoid breaking it → the comment. **A comment block should be shorter than the code it explains**; if it is longer, the reasoning belongs elsewhere and the comment should point there.
29. **Testing real input with `SubViewport.push_input()`.** It does not emulate touch from mouse. For real engine input use `Input.parse_input_event()` and then `Input.flush_buffered_events()` in the root window.
30. **Instantiating `AppRoot` in a test.** Its `_ready` starts the test runner again. Drive the live `AppRoot` that hosts the run, and restore its previous screen.
31. **Rendering screenshots with `--headless`.** The dummy renderer gives a null texture. On macOS, run `scripts/screenshot.gd` from a real window (command in the header of that script).

Full lesson history: `docs/LESSONS.md`

---

## Workflow Expectations

- **Read the repo first** — never write subtasks or a plan without reading relevant files
- **Backend before frontend** — complete all `core/` changes before touching `ui/`
- **Confirm contracts first** — verify snapshot shape, action types, and service interfaces before implementing
- **Sanctum UI overhaul:** visible layers only, one screen story at a time, and use `docs/screens.md` as the authoritative screen ledger
- **If Sanctum implementation reality clashes with the approved screen spec:** stop and re-spec with Jeff before continuing
- **Every story ends with:** compile check → Jeff tests in-game → docs update → git commit
- **No speculative abstractions** — implement exactly what is asked, no more

### Subagent model tiers

Choose a subagent model deliberately from the work, and state the choice in the
handoff when it is useful context:

- **GPT-5.6 Sol:** genuinely high-level or tricky work, including concurrency,
  subtle algorithms, adversarial verification/judge panels, and gnarly debugging.
- **GPT-5.6 Tera:** preferred general default for well-specified implementation
  with clear acceptance criteria, unless the work is genuinely routine.
- **GPT-5.6 Luna:** fast general implementation when the task is clear and less
  tricky than work that warrants Tera.
- **GPT-5.5:** mechanical bulk work such as renames, boilerplate, format conversion,
  and log triage.

Do not default every subagent to the most capable tier. Preserve stable ownership
domains while selecting the least costly tier suited to the actual difficulty.

### Token-efficient delegation

- Centralize repo reading, contract decisions, final integration, capture generation,
  and full-suite verification in the main orchestrator. Do them once per milestone.
- Delegate implementation by exclusive file domain and run those domains
  sequentially when one depends on another. Do not ask every agent to audit the same
  files, rerun the same suite, or regenerate the same captures.
- Use `fork_turns="none"` with a compact task brief that points to the frozen contract.
  Do not copy the full conversation into a subagent unless its task truly requires it.
- Agents run only the smallest targeted check needed for their domain. The main
  orchestrator runs full integration, visual matrices, and repository tests once
  after implementation freezes.
- Agent reports are concise: changed files, unresolved blockers, failing check names,
  and final counts. Do not return long narratives or repeat the contract.
- Prefer one implementation agent and one final adversarial verifier. Add another
  implementation agent only when a separate authoritative domain must change.

---

## Key References

- `CONVENTIONS.md` — full system contracts (read for any implementation work)
- `docs/CONTEXT.md` — working preferences, workflow, environment notes
- `docs/MEMORY.md` — systems inventory, all service interfaces
- `docs/LESSONS.md` — corrected behaviours
- `docs/skills/godot-echoes-dev.md` — implementation patterns, checklists
- `docs/skills/echoes-sankofa-gdd.md` — design knowledge, V2 terminology
- `docs/skills/ponytail.md` — smallest-complete-change coding mode (level `full`); code agents and `qa-verifier` use it
- `docs/Echoes vNext Working GDD.md` — primary design canon
