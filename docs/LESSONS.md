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

**Rule:** All visual structure (color-coded cells, styled backgrounds, layout hierarchy, default text) must be authored in `.tscn`. `.gd` may only update values: `modulate`, `text`, `visible`, `disabled`. Do not construct visual nodes dynamically in `.gd`.
**Why:** Jeff rejected a plan that set cell colors via `StyleBoxFlat.new()` in `.gd`. "Move that to .tscn if possible." Authoring structure in `.gd` bypasses the editor and makes visual tuning impossible without code changes.
**How to apply:** For any new visual component, design the full node tree in `.tscn` first. `.gd` gets `@onready` refs to pre-built nodes and only calls `node.modulate = ...` or `node.text = ...`.
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

### 2 — No UI work in .gd files — all visual work belongs in .tscn

**Rule:** Never create, layout, or style UI nodes programmatically in `.gd` files. All visual work (node hierarchy, sizing, text defaults, visibility, theme variations) must live in `.tscn` scene files.
**Why:** Jeff corrected a plan that created Label nodes and HBoxContainers in `_ready()` via `Node.new()`. Visual structure belongs in `.tscn`; `.gd` is for logic only.
**How to apply:** Any time a new UI element needs to be added: define it in `.tscn` first with `unique_name_in_owner = true`, reference it in `.gd` via `@onready var x = %NodeName`. Only update `.text`, `.visible`, `.disabled`, `.modulate` in `.gd`. Never call `add_child(Button.new())` or similar in `.gd` unless it's an overlay/modal with no persistent scene reference.
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
