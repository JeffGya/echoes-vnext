# Echoes vNext — Lessons Learned

A living log of corrected behaviours and validated patterns. Updated after any correction from Jeff.
Reviewed at the start of each session.

**Format per entry:**
- **Rule:** what to do / not do
- **Why:** reason Jeff gave or incident that caused the correction
- **How to apply:** when this triggers
- **Mistake count:** running total

---

## Lessons (most recent first)

### 24 — Two similarly-named test files can be silently swapped

**From the test-performance initiative (PRs #70-#72), 2026-09-21.** `tests/FlowFingerprintTests.gd`
(suite `fingerprint_*`) and `tests/FlowSnapshotFingerprintTests.gd` (suites `snapshot_fingerprint`,
`snapshot_purity`) sit one letter apart in an editor file list. Early analysis applied a
fixture-sharing optimization to the wrong one — the file that was never the bottleneck — before the
mistake was caught by directly reading both files' registered `suite()` names and test counts.

**Rule.** Before optimizing or reasoning about a named test file, confirm its registered suite
name(s) and test count against the runner output, not against the filename alone. Two files with
adjacent names are not evidence they cover the same thing.

---

### 23 — A per-shard alarm value is a hang ceiling, not a measured duration

**From the test-performance initiative (PR #71), 2026-09-21.** `wait` in `scripts/run-tests-sharded.sh`
returns as soon as a backgrounded shard process exits on its own; the `perl alarm` only fires if the
shard is still running past that many seconds. Three separate verification passes during this
initiative read a fired-or-not-yet-fired alarm value (e.g. "900s") as if it were the shard's actual
runtime, leading to wrong conclusions about what was slow. This is already documented in the script's
own comments and in `AGENTS.md`'s "Sharded full-suite runs" section — recorded here so it also
appears in the durable mistake log, not only at the site of the code.

**Rule.** An alarm timeout that did not fire tells you the run finished before that ceiling. It never
tells you how long the run actually took. Read the log's own `elapsed_secs=N` line (each shard log's
final line, written by `scripts/run-tests-sharded.sh` from `date +%s` before/after the run), not the
alarm value.

---

### 22 — A shared static-var fixture is unsafe even when every within-run ordering is proven safe

**From the test-performance initiative (PR #71), 2026-09-21.** `FlowSnapshotFingerprintTests.gd`
memoized one shared, mutable `FlowRuntime` across four tests via a static var, to skip a repeated
disk-boot-plus-onboarding setup. Every test that used it was confirmed read-only against the shared
state, or re-verified its own setup afterward — safe for any single run. A Codex review on PR #71
caught the real problem: a static var persists across repeated invocations within the SAME Godot
process (e.g. the Debug Panel's `tests` command run twice without restarting), so a later run can
silently inherit state mutated by an earlier one, even when no test run has ever shown a failure.
This violates `tests/AGENTS.md`'s isolation rule — "Never depend on global state... or test
execution order" — which the within-one-run proof never actually satisfied.

**Rule.** Cross-test shared mutable state (a static var, a cached instance) is unsafe regardless of
how carefully the sharing tests are audited, because the risk is cross-*run*, not cross-test. Prefer
lighter direct construction instead — build the minimal state directly, bypass the expensive setup,
and give every test its own instance.

---

### 21 — Price the sum, not the item

**From V2-COMBAT-003, 2026-09-06.** The story is named "one deterministic behavior-arbitration and
explanation authority". It shipped 49 commits. About 44 % of the code commits were a different
subject: terrain design, a V2 calling migration, and a maturity band remap.

**Every addition was priced to Jeff before he approved it.** The review checked each one and found
the cost stated first. **The running total was never priced at all.** No document said "this story is
now three subjects" until Jeff said it himself.

**Rule.** When a story takes on a second subject, price the **total**, and offer the split at the
moment the second subject appears — not later.

**The split point existed.** Commit `b4dd797` is the line between repairing a defect and authoring a
design. Everything before it protected a measurement. Everything after it created board variety on a
foundation that was already safe.

**Do not read this as "do not fix what you find".** Every detour repaired something the story's own
conclusion depends on. Phase 10 could honestly report that no weight moved only because the inputs
were repaired first. The work was right. The packaging was not.

---

### 20 — A brief written by the orchestrator overrides the repo rules

**From V2-COMBAT-003.** A sub-agent reads `AGENTS.md`, then reads the brief. **The brief is later and
wins on contradiction.**

Restating a repo rule in your own words does not reinforce it. It replaces it, with whatever you got
wrong. I restated the conditional rule "rebuild the import cache *before believing* a fingerprint
failure" as an unconditional step. Agents reimported before every run. One two-function commit cost
five seven-minute suites.

**Rule.** Point briefs at the file. Do not paraphrase it. Never state a conditional rule without its
condition.

**This class repeated after it was written down.** Three of my briefs on one branch carried numbers I
had not checked against the code. Agents caught all three. One error came one day after the entry
about that exact failure.

---

### 19 — A rule written down changes the large cases and not the habit

**From V2-COMBAT-003.** `AGENTS.md` entry 28 says comments must be lean. Measured on the branch:

| Range | Comments | Code | Ratio |
|---|---:|---:|---:|
| Before the rule | 1,934 | 4,104 | 0.47 |
| After the rule | 1,237 | 3,225 | 0.38 |

The aggregate improved. **Four commits after the rule still added more comment than code.** The rule
worked where the work was large and someone was watching. It failed on small commits, which is
exactly where a two-line fix attracts a paragraph.

**Rule.** Writing a rule is the start. Check it on the small cases, where nobody is looking.

---

### 18 — Stop the agent, then its processes

**From V2-COMBAT-003.** An agent stalled. I killed its Godot run. It woke, found no result, and
started another. Three rounds of that.

`TaskStop` ends the agent. Killing a child process does not.

**Rule.** When taking over from a live agent: stop the agent first, then clean up its processes.
Doing it in the other order guarantees a loop.

---

### 17 — Two measurements were reported as fact and both were wrong

**From V2-COMBAT-003.** I told Jeff islands appear on 60-70 % of boards. That figure came from a
probe that built `ConfigService` fresh, which returns an empty balance, so it measured a board type
the game never generates.

I then told him 11 %. That sampled one realm — Courage — which turned out to be one of the two least
island-prone settings in the game.

The real figure, measured across all ten virtue settings, is between 5 % and 71 % depending on realm.

**This repeats a lesson already in memory:** a probe that does not mirror production construction
invalidates its own headline. I repeated it anyway, and a design decision was approved on the wrong
numbers before they were corrected.

**Rule.** Before quoting a probe number, check that the probe builds its inputs the way production
builds them.

---


---

### 16 — CanvasLayer visibility must follow inherited shell visibility

**Rule:** Every shell-owned `CanvasLayer` must mirror `is_visible_in_tree()`, not only the shell Control's local `visible` flag.
**Why:** A hidden Realm shell left its EchoBar layer active over Sanctum, so invisible Realm chrome intercepted Sanctum input.
**How to apply:** Synchronize world, content, chrome, and transient CanvasLayers on shell/ancestor visibility changes; verify the previously hidden shell cannot draw or receive input after cross-shell routing.
**Mistake count:** 1

---

### 15 — Reset full-rect container offsets when applying a responsive profile

**Rule:** When a Control is meant to fill its parent, responsive layout application must restore all four offsets to zero after setting full-rect anchors.
**Why:** Stale authored/runtime offsets survived profile changes and shifted otherwise full-rect content, producing blank or compressed screens after live resize and routing.
**How to apply:** For full-rect responsive roots, set the authored anchors and explicitly clear left/top/right/bottom offsets in the profile application path. Test compact → wide → compact without re-instancing the screen.
**Mistake count:** 1

---

### 14 — Autowrap needs an authored/profile width before first layout

**Rule:** An autowrap label or wrapped container that participates in minimum-size calculation must receive a concrete authored or profile-specific wrap width before the first layout pass.
**Why:** Labels initially measured against tiny intrinsic widths, fed excessively tall minimum sizes back into their containers, and collapsed or overlapped adjacent cards.
**How to apply:** Author the structural width in `.tscn`, update the width value in `set_layout()`, then refresh minimum sizes after snapshot text/visibility changes. Do not fix the symptom with arbitrary height clamps or a new scroll container.
**Mistake count:** 1

---

### 13 — Responsive UI is recomposition, caps, and spatial surplus

**Rule:** Do not uniformly scale every UI element and do not add scroll containers to every primary screen. Recompose by profile, cap readable panels/chrome, and give surplus wide-screen space to the spatial presentation.
**Why:** Uniform scaling made small and large views feel identical while wasting desktop real estate; blanket scrolling narrowed and fragmented the Sanctum overview instead of solving its layout hierarchy.
**How to apply:** Use authored containers, compact/standard/wide columns and visibility states, explicit wrap widths, capped panel sizes, and safe/chrome exclusions. Reserve scrolling for genuinely long bounded content such as modal bodies, lists, or detail pages.
**Mistake count:** 1

---

### 12 — Tests and load failures must never share the production save path

**Rule:** Every runtime test must inject an isolated save path. Persistence must distinguish a genuinely missing save from an unreadable or invalid save, and only the missing case may create a new campaign.
**Why:** Runtime tests could flush controlled test dictionaries into the player's real slot. Separately, any load failure returned `{}`, which boot interpreted as first launch and immediately overwrote with a new campaign.
**How to apply:** Keep production as the default `FlowRuntime` save path, inject `/tmp` paths in tests, validate temporary writes before rotating, retain multiple validated generations, and surface a non-destructive error when no artifact validates.
**Mistake count:** 1

---

### 11 — Grade table lives under `data.summoning`, not `data.economy`

**Rule:** Always verify where `FlowRuntime` actually reads a config key before placing it in `balance.json`. Do not trust Notion story descriptions for key location — read the codebase.
**Why:** A Notion story said to place the grade table under `data.economy`. The codebase reads summoning config from `data.summoning` via `summ_cfg`. Placing it in the wrong location caused a silent config miss.
**How to apply:** Before adding any new key to `balance.json`, grep for where it is read in `core/` and confirm the path matches. Never assume key location from story text alone.
**Mistake count:** 1

---

### 10 — Test isolation: set balance directly, don't use `economy.ase.add`

**Rule:** In tests, set balances directly on the save ref (`save_data["economy"]["ase"] = value`). Never use `economy.ase.add` inside tests.
**Why:** `_make_runtime_env()` loads the real save file. Using `economy.ase.add` adds ON TOP of the existing save balance, making tests non-deterministic and dependent on save state.
**How to apply:** Any test that needs a controlled balance must set it directly. Never call `add_ase()` or `economy.ase.add` in test setup code.
**Mistake count:** 1

---

### 9 — `refresh_snapshot()` does NOT re-call `enter()`

**Rule:** For non-SANCTUM states, `FlowStateMachine._rebuild_snapshot()` reads `ctx.last_snapshot` as-is. To update a mid-state snapshot (e.g. after `grade_select`), use the `static func build_snapshot()` pattern: handler calls the static builder directly, assigns to `ctx.last_snapshot`, then calls `refresh_snapshot()` for validation only.
**Why:** Calling `refresh_snapshot()` on non-SANCTUM states had no effect because the machine just re-read the existing snapshot without re-entering the state. This caused stale UI after grade selection.
**How to apply:** Whenever a state needs to update its snapshot mid-flow (not on entry), use the static builder pattern. Never assume `refresh_snapshot()` will recompute data.
**Mistake count:** 1

---

### 8 — Shell owns shared nav, not the snapshot

**Rule:** When all sanctum-family screens need the same nav bar, put it in the shell with a cached-nav pattern. Do NOT inject nav into every state's snapshot.
**Why:** Injecting nav actions into snapshots creates unnecessary coupling — changing the nav bar requires touching every unrelated state (SummonState, PartyManageState, etc.). Shell-cached nav was the correct pattern.
**How to apply:** Any persistent chrome (nav bars, headers) that appears across multiple screens in a shell family belongs in the shell itself, not the snapshot. Snapshots carry only the content-specific actions.
**Mistake count:** 1

---

### 7 — Every story must end with a visual/playable update

**Rule:** Every story must produce something visible or playable in-game by the time it closes. If a story is purely backend with no in-game manifestation, that is a gap. Find an existing story that can absorb the UI surface — broaden its scope. Only write a new story if no existing one fits.
**Why:** Jeff flagged that backend-only stories leave work invisible and untestable from a player perspective. If you can't see it or play it, you can't verify it really works end-to-end.
**How to apply:** At the end of planning any story, ask: "What does the player or Keeper see or do differently after this ships?" If the answer is "nothing yet," identify which existing story closes that gap and note it explicitly in the plan.
**Mistake count:** 0

---

### 6 — Every story ends with headless Godot test → pause for manual test → commit

**Rule:** The completion workflow for every story is: (1) run headless Godot tests, (2) pause and tell Jeff to test manually in-game, (3) after Jeff approves, create a git commit with only the story's files.
**Why:** Stories were being completed without a defined test → pause → commit ritual, risking untested work being committed.
**How to apply:** Before any story commit: run tests headlessly, confirm pass count, share the output. Explicitly say "pausing for your manual testing." Only commit after Jeff signals approval. Never commit without this sequence.
**Mistake count:** 1

---

### 5 — Build UI structure in .tscn, not .gd — script only sets values

**Rule:** All visual structure (color-coded cells, styled backgrounds, layout hierarchy, default text) must be authored in `.tscn`. `.gd` may render state and set responsive profile values such as margins, columns, visibility, wrap widths, and min/max sizes. Do not construct visual nodes or styles dynamically in `.gd`.
**Why:** Jeff rejected a plan that set cell colors via `StyleBoxFlat.new()` in `.gd`. "Move that to .tscn if possible." Authoring structure in `.gd` bypasses the editor and makes visual tuning impossible without code changes.
**How to apply:** For any new visual component, design the full node tree and theme hooks in `.tscn` first. `.gd` gets `@onready` refs to pre-built nodes, renders snapshot values, and may apply profile-specific values without changing the tree.
**Mistake count:** 1

---

### 4 — Keep pre-stage prep off the stage preview screen

**Rule:** `flow.stage` is the stage preview entry into the exploration flow. Keep party prep and other pre-stage management off this screen; that work belongs on `StageMap`.
**Why:** Jeff clarified that the stage screen should stay focused on the visual entry into exploration/combat. Overloading it with prep UI makes the flow muddier and duplicates StageMap responsibilities.
**How to apply:** Any pre-stage prep (skill selection, party review, broader management) belongs on StageMap. Stage preview may still show the directive confirmation overlay because that is part of entering the stage, not a separate management surface.
**Mistake count:** 1

---

### 3 — Interview Jeff before designing new screens or major UX flows

**Rule:** Do not design or build a new screen, or add a major new UX flow, without first interviewing Jeff about the intended UX. If a screen boundary decision needs to be made, mark it as a gap and raise it explicitly before proceeding.
**Why:** A standalone SkillLoadoutScreen was built without asking where skill selection should live. Jeff's answer was that it belongs embedded in StageMap alongside the future directive system — a completely different shape.
**How to apply:** Any time a task involves adding a new screen or a new flow state with its own navigation, ask: "Where should this live in the player journey? Should this be its own screen or embedded in an existing one?" Flag as a UX gap if not specified.
**Mistake count:** 1

---

### 2 — No UI structure or styling construction in .gd

**Rule:** Never create/reparent UI nodes or construct visual styles programmatically in `.gd` files. Node hierarchy, layout relationships, text defaults, and theme variations live in `.tscn`; responsive scripts may set profile values on those authored nodes.
**Why:** Jeff corrected a plan that created Label nodes and HBoxContainers in `_ready()` via `Node.new()`. Visual structure belongs in `.tscn`; `.gd` is for logic only.
**How to apply:** Any time a new UI element needs to be added: define it in `.tscn` first with `unique_name_in_owner = true`, reference it in `.gd` via `@onready var x = %NodeName`, and update its rendered/profile values there. Never call `add_child(Button.new())`, build StyleBoxes, or dynamically reparent authored UI to solve responsiveness.
**Mistake count:** 1

---

### 1 — Use the vector system (not archetype_birth) for role-affinity lookups

**Rule:** When determining which echo fills a role (purifier, leader, scout, etc.), use `vector_scores` (Pillar/Protector/Seeker/Vanguard) not `archetype_birth`.
**Why:** Jeff corrected an initial plan that used `archetype_birth` to select the purifier. Archetype is birth context — a fixed origin story. Vectors are the echo's living identity, shaped by action and experience. Role affinity must follow identity, not origin.
**How to apply:** For any role-affinity lookup, weight by `vector_scores[dominant_vector]` using the relevant weight config block. Only fall back to archetype if vectors are not meaningful for the specific role.
**Mistake count:** 1

---

## Game Dev Hard Rules

These are architectural invariants derived from painful corrections. Never violate:

1. **Always read the GitHub repo before writing subtasks.** Jeff will correct this if skipped.
2. **Slot-keyed Dictionary for actions — always.** Jeff manually corrected SANCTUM-003. Array-style actions are legacy (UISnapshotRenderer only).
3. **Per-row actions are NOT in snapshot.actions.** Row interactions (toggle, select) are dispatched by UI rows directly.
4. **Confirm contracts in Subtask 1 of every story** before building anything.
5. **Never reorder EchoFactory RNG draws.** Only append new draws at end; bump version string if added.
6. **No IDs in player-facing display.** `party_slots` shows name/level/rank only — no `id` fields shown to player.
7. **Array actions are legacy.** Only UISnapshotRenderer uses them. All flow states now use slot-keyed Dict.
