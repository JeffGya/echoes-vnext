# V2-COMBAT-003 — Handoff

> **Status: phases 1 and 2a are complete and committed. Phase 2 continues.**
> Branch `claude/v2-combat-003-arbitration`, cut from `4b45b3e` on `main`.
> Worktree `.claude/worktrees/echoes-vnext-docs-review-e631bf`. Pass this path to `--path`.
> Plan file: `~/.claude/plans/mellow-cuddling-puddle.md`.
> Written 2026-08-31.

---

## 1. What this story is

One deterministic behavior-arbitration and explanation authority, and then the work to make its
output legible. The scope is the **sum** of the prompt scope and the live Notion scope. Jeff
approved that sum, and approved doing Half B first.

**Half A.** One authority resolves Align, Interpret, Hesitate, Object and Refuse. It consumes the
V2-PROG-012 outputs and derives none of them. It emits a typed causal Decision Trace.

**Half B (Movement Model Slice C).** The four deferrals from V2-COMBAT-002: the three inert scorer
fields, PURIFY_SHRINE positioning, the engage-region rule, and the `health_ratio` ladders.

Notion page `339c3d1e-de92-8190-ad52-ce3f2a0620c8`. Spec State **Open**, so the guidance-response
contract is not locked and must be confirmed before implementation.

---

## 2. Current state

| Metric | Value |
|---|---|
| Baseline at branch start | `Tests: 1519 total, 1519 passed, 0 failed`, 94 suites |
| Now | `Tests: 1527 total, 1527 passed, 0 failed`, 95 suites |
| Commits | 4 (2 story, 2 process) |

| Commit | Content |
|---|---|
| `207e5b4` | Phase 1 — characterization of eight defects |
| `6ef736f` | The sub-agent model-tier rule |
| `b04bd12` | The agent orchestration rules |
| `44671aa` | Phase 2a — the fingerprints watch each round's first actor |

**Uncommitted at the time of writing:** the configurable test save directory. It is verified but not
yet committed. Refer to section 7.

---

## 3. Approved decisions

Each decision came from Jeff in this session. Phase 13 writes each one to `ANSWERS.md`.

| # | Decision |
|---|---|
| 1 | **Scope.** Do all the work in one story: the prompt scope plus the Notion scope. Do **Half B first**. |
| 2 | **The five responses** use a **headless guidance source** — an internal contribution that only tests and one debug command operate. V2-COMBAT-004 later connects the real ping UI to the same interface. |
| 3 | **D97.** Limit the Absolute Fear Rule to `faction == "echo"`. An enemy keeps fear as an input to the score and never stops permanently. |
| 4 | **The movement stall** is corrected first, before all other behavior work. |
| 5 | **The visual is temporary.** Show Object and Refuse through the **existing** `BarkPopupDivergence` template. V2-COMBAT-004 removes it and puts a new UI in its place. **Add nothing to the Resolve screen** — it would crowd that screen. |
| 6 | **The bark budget.** Put the two new response contexts in tier 1. Keep `max_barks_per_round` at 3, mark it `PROPOSED DEFAULT`, and Jeff sets the final number during the manual test. Config only, so V2-COMBAT-004 re-tunes rather than deletes. |
| 7 | **The legacy selector.** Keep it, write a clear log for each use, and **make any use fail the test suite**. |
| 8 | **The action vocabulary.** Correct the label, and namespace the two unprefixed strings: `melee_attack` becomes `actor.strike`, `protect_ally` becomes `actor.protect`. |
| 9 | **The baseline may move.** The game is not live and the saves are disposable. Do not pay the additive-only cost. Prefer the correct foundation. |
| 10 | **The stranding defect.** Correct **both** causes — the placement function and the terrain generator — **placement first**, as separate commits. |
| 11 | **The fingerprint blind spot.** Correct it immediately, before phase 3, so no later re-record pins an incomplete guard. |
| 12 | **The Seer aura.** Measure the effect first, then decide. Do not compensate speculatively. |
| 13 | **Orchestration.** Model tier follows the difficulty of the work. Parallelize when safe. Verification is central and never self. Recorded in `AGENTS.md` and both `CLAUDE.md` files. |

---

## 4. Corrections to the source documents

**Read this section before trusting a claim from Notion or the defect register.** Each item below
was verified in the code.

| Claim, and where it is written | The truth |
|---|---|
| Notion: "Do D27 first" — log the movement decision | **Already fixed.** V2-INFRA-003 pass 7 logs `goal_id` and `option_id` on `actor.moved` at `LiveMovementContextService.gd:552-553`. The register, written later, supersedes the Notion note. |
| Register D97: an enemy "never gets a rank" | **Wrong mechanism.** `EnemyActor.gd:56` sets `rank` to 1. The conclusion still holds: rank 1 gives the band `nascent` and therefore the raw threshold 65, against a grounded Echo's 80. |
| Register: the stall happens when a goal is "not routable **within its 2-cell capacity**" | **Wrong mechanism.** The truncation helper is sound. The real cause is that **no route exists at all**, because the actor stands on unreachable ground. Refer to section 5. |
| `CONVENTIONS.md`: `BarkPopupLayer.enqueue_barks(Array)` | **No such function.** The real one is `show_barks(bark_events)`. Phase 13 corrects the document. |
| The prompt: align the action types to `docs/movement-model.md` §9 | **§9 is the PURPOSE vocabulary, not the action vocabulary, and it is already implemented.** All thirteen words are the keys of `_PURPOSE_FALLBACK_ALLOW` at `CombatActivationService.gd:110` and ride live as `movement_purpose`. `action_type` is a different layer: §9 is why the actor moved, `action_type` is what it did on arrival. Renaming one onto the other would collide two vocabularies. One collision already exists — `actor.withdraw` is a Ranger skill and `withdraw` is a §9 purpose. |
| Notion: the 2026-08-29 addendum has three parts | It has **two** findings: the movement stall, and D97. |
| `AGENTS.md`: 90 registered suite names | There are **95** now. |

---

## 5. Measured findings

None of these came from a passing test.

### 5.1 An actor can be placed on ground it can never leave

The chain, each link verified:

1. `StageTerrain.gd:323-334` mints "straggler" cells from the 8-direction neighbours of walkable
   ground, **without applying its own edge rule**.
2. `StageTerrain.is_legal_edge` at `:432-463` rejects a diagonal whose two orthogonal side cells are
   both solid. A straggler placed diagonally off a plateau corner therefore has **no legal edge**.
3. `GridService.place_actors` at `:242-289` fills each faction from walkable cells in sorted order
   **with no connectivity check**, so an Echo takes the leftmost column first — where such a cell
   sits.
4. The movement layer is then **correct**. No route exists, so it truthfully returns no option.

Measurements:

| Measurement | Result |
|---|---|
| Boards with at least one disconnected cell, 60 for each shape | 34 to 46 of 60 |
| Live encounter setups that stranded a real Echo | 2 of 45 |
| The stranded encounter, driven through real dispatch | 15 rounds, `goals=3, options=0`, zero cells moved, morale 41 down to 1 |

**Caution about this measurement.** The component count may have used plain 8-direction adjacency.
If it did, it **structurally could not see** the erosion class below, so the true count may be
higher and the components may be larger than one cell.

### 5.2 Unreachable ground has three sources, not one

| Source | Mechanism |
|---|---|
| Stragglers | `_adjacent_candidates` at `:1035-1058` applies no edge rule |
| Plateau erosion | `_is_8_connected` at `:1002-1028` is a plain flood fill, so erosion can leave two cells joined only by a diagonal with both corners removed |
| Bridging | `_flood_fill_components` at `:807-853` is also plain 8-direction, so two plateaus touching only at a corner count as connected and are never bridged |

Bridges themselves are safe. The "at least two cells wide" guarantee **does** hold in
`_make_bridge_rects` at `:855-914`, and the test that asserts it is a true assertion.

**Phase 2d must not claim that unreachable ground is impossible until all three are addressed.**

### 5.3 Phase 2d moves no RNG draw

Each straggler derives its **own** stream, `prefix + ".straggler.%d" % sk`, at `:328`, and makes
exactly one draw at `:332`. Filtering the candidate list changes which cell that draw selects. It
does not change the number of draws and it does not touch any other stream.

**Therefore: filter the candidates. Never redraw.** A reject-and-redraw loop would consume an
unbounded, data-dependent number of draws and would move the seed sequence.

### 5.4 The `actor.idle` label, separated at last

| Board | Turns labelled `actor.idle` | Turns with no position change |
|---|---|---|
| Healthy | 15 | **6** |
| Stranded | 15 | **15** |

So on a healthy board, 9 of 15 labels are false. The cause is `LiveMovementContextService.gd:556-557`,
which sets `action_type` to `actor.idle` whenever no primary action resolves — even though
`actor.moved` logged a real path ten lines above.

### 5.5 The fingerprints had a blind spot

`combat.confirm_round` resolves the **first** actor of the round itself. `_drive_and_capture`
dispatched it and then sampled only `combat.next_actor`, so the first actor of every round was
simulated and never captured. One Echo was first in initiative every round of a four-round trace
and appeared in **zero** captured turns.

Corrected in `44671aa`. Turns gained: COMBAT +5, PURIFY_SHRINE +4, RECOVER +2, PROTECT +4,
ENDURE +5, PURSUE +5, GUIDE_SPIRIT +9 — one for each round. The move was proven additive.

### 5.6 The four inert scoring terms

`_spatial_utility` has 11 terms. The live producer at `LiveMovementContextService.gd:452-454` sends
literal `0.0` for `exposure`, `congestion` and `cohesion`. That also kills a fourth term, because
`directive_exposure_acceptance` multiplies `exposure`.

Working implementations already exist as `MovementOptionService._exposure`, `._congestion` and
`._cohesion`. **The live path never calls `generate_options`**, so those implementations are unused.
Half B connects them; it does not write new ones.

**One agent reported these terms as live.** It had read the pure service and missed the live
producer. Do not repeat that error.

### 5.7 `terrain_costs` is empty in live combat

`LiveMovementContextService.gd:160` passes `{}` as the 10th argument to `MovementContext.build`,
which is `terrain_costs`. Every cell entry therefore costs the default 1.

**This is not a defect.** `docs/movement-model.md` §15.1 states that production terrain is still
binary walkable, so empty is truthful. It is load-bearing for section 5.3's reasoning, because with
no terrain cost and a capacity floor of 2, the first step of any route is always affordable.

---

## 6. Findings recorded, not yet owned

Each is pre-existing and outside the stated scope. **Do not correct one quietly inside another
change.** Bring the numbers to Jeff and let him place it.

| Finding | Evidence |
|---|---|
| **The contribution ledger counts five action types only.** All eight skill actions, plus `protect_ally`, `actor.purify_shrine`, `actor.taunt` and `actor.retreat`, increment **nothing — not even `total_count`**. A turn spent on a signature calling skill is erased from the denominator of `melee_share` and `guard_share`, which inflates both and distorts courage and wisdom experience. | `ContributionLedgerService.gd:191-196` |
| **The taunt bonus is unreachable.** `CONVENTIONS.md` documents a +25 pull toward a taunting Echo. `taunted_by` is **read** in two places and **written nowhere** in `core/` or `ui/`. | `BehaviorArbiter.gd:2208-2211` |
| **An enemy can be placed on an Echo's cell.** `_assign_walkable_faction` builds a fresh `assigned` dictionary for each call, so the Echo pass and the enemy pass cannot see each other's cells. | `GridService.gd:305` |
| **An actor with a live option can still stand still.** Measured: 3 turns of 19 on a healthy board, with `options=1` every turn. The winning candidate was not isolated. This is a **different defect** from the stranding, and it produces the same screen. It belongs to the phase 8 arbitration work. | Not isolated |
| **`actor.interact` is dead.** Zero producers anywhere in the tree. | `CombatService.gd:58` |
| **Two fixtures are not production-shaped.** They skip `EmotionService.init_echo` and `VectorService.init_vectors`, which is the `ANSWERS.md` entry 50 defect. Phase 2b corrects them. | `FlowFingerprintTests._setup_encounter`, `BehaviorCharacterizationTests._echo_actor` |

---

## 7. The phases

| Phase | Work | Tier | State |
|---|---|---|---|
| 1 | Characterization, eight defects pinned | `sonnet` | **Done** `207e5b4` |
| 2a | The fingerprints watch each round's first actor | `sonnet` | **Done** `44671aa` |
| — | The configurable test save directory | `sonnet` | **Verified, not committed** |
| 2b | Production-shaped fixtures | `sonnet` | Queued |
| 2c | The placement guard | `sonnet` | Designed, queued |
| 2d | The terrain generator | `opus` | Designed. **Measure the provenance split first.** |
| 3 | The Whole-band baseline scenario | `sonnet` | Not started |
| 4 | Limit the refusal to an Echo | `sonnet` | Not started |
| 5 | The action vocabulary | `opus` table, then `haiku` rename | Table produced, needs approval |
| 6 | The three inert terms | `opus` | Not started |
| 7 | Purify, engage region, `health_ratio`, the step before an attack | `opus` | Not started |
| 8 | The arbitration and explanation authority | `opus` | Design produced |
| 9 | The temporary visual and the bark budget | `sonnet` | Not started |
| 10 | Tuning, the legacy selector, D57 | `opus` | Not started |
| 11 | Reviews and the full regression | `opus` | Not started |
| 12 | The manual test with Jeff | — | Blocks the commit |
| 13 | Documentation, Notion, commit, PR | `sonnet` | Not started |

### The immediate next steps

1. **Commit the save directory** once the consolidation agent reports and a cold run confirms it.
2. **Phase 2c, the placement guard.** The design is in section 8.
3. **The provenance probe**, then bring Jeff the split before scoping phase 2d.
4. **Phase 2b**, the production-shaped fixtures.

---

## 8. The phase 2c and 2d designs

### 2c — the placement guard

Use `StageTerrain.legal_neighbors(cell, walkable, bounds)` at `:466-484`. It already delegates to
`is_legal_edge`, and the movement layer already uses it, so a guard built on it cannot disagree with
movement. **Do not write a third helper.**

`GridService` already has everything it needs. `walkable` is read at `:242`, and bounds are the two
values already computed at `:220-221`. Note the key names differ: `StageTerrain` uses `w` and `h`,
`board_cfg` uses `board_cols` and `board_rows`.

Change `_assign_walkable_faction` at `:292-336` to a three-pass fill:

1. The existing ordered pass, but skip a cell whose `legal_neighbors` is empty.
2. The existing sorted drain, with the same filter.
3. **A new final pass with no filter**, so an actor is never dropped when every remaining cell is
   isolated. Placing an actor somewhere it cannot walk is bad. Dropping it from the encounter is
   worse.

`GridService` is pure static and has no logger, so the warning belongs at the call site,
`EncounterSetupService.gd:392`, which has `logger` in scope. That warning should be silent in
practice, so it doubles as a live alarm for phase 2d.

**The guard adds zero RNG draws**, so `CONVENTIONS.md`'s guarantee that the walkable branch makes no
draw stays literally true. Assert it directly: record `rng.state` before and after and require it to
be unchanged.

### 2d — the generator

Filter inside `_adjacent_candidates`. Evaluate a candidate against `walkable_cells` **plus the
candidate**, because `is_legal_edge` requires the source cell to be walkable. A post-hoc filter over
the built set is wrong: it would either shrink the straggler count below the authored range, or
require a redraw.

The filter is conservative and never wrong in the unsafe direction, because adding cells only ever
adds edges. A cell accepted at step `k` cannot be made illegal by a later straggler.

**The order is correct as approved, on one condition: phase 2d's probe must measure the terrain,
not a played encounter.** The placement guard sits downstream of generation and cannot influence a
terrain-only probe. Measured the wrong way, the guard would hide the generator defect.

The generator fix alone would **not** make the placement guard unnecessary. `GridService` is a public
pure-static service that accepts any walkable dictionary from any caller, and two of the three
sources of unreachable ground are not addressed by the straggler filter.

---

## 9. Environment facts and traps

- **The suite takes about 7 minutes.** Pass `timeout: 600000` on the Bash call. `300000` truncates a
  healthy run and looks like a hang.
- **The runner always exits 0.** Only the `Tests:` line is evidence, and **the logger adds a prefix
  to it**. Do not anchor a search pattern to the start of the line. I nearly declared a healthy run
  truncated for exactly this reason.
- **Rebuild the import cache before believing any fingerprint failure.**
- **Delete the save directory before every run.**
- **`ECHOES_TEST_SAVE_DIR`** now sets the save root, and the default reproduces today's behavior
  exactly. **It does not make every parallel Godot run safe.** Two processes in one worktree still
  share the `.godot/` import cache, and a run that registers a new `class_name` writes to it. An
  agent that adds a new `class_name` must still run alone.
- **The retreat roll is tick-bound.** Any change to the dispatch count on the path into an encounter
  re-rolls every retreat in the game.
- **Do not drive `flow.new_game` in a test.** It uses `Crypto.generate_random_bytes()`. Drive from
  `boot()`, which uses the pinned seed.

---

## 10. How the work is being run

- **Model tier follows the difficulty of the work**, not a build-versus-review split.
- **Parallelize when three conditions hold:** disjoint files, no shared exclusive resource, and
  disjoint recorded values. The third matters even when the files differ — two agents re-recording
  the same constants destroy attribution.
- **A builder never verifies its own work.** An independent agent verifies where two agents' work
  merges.
- **Never accept a completion report as evidence.** Audit the tree.
- **After any agent stops, killed or completed, audit read-only before re-dispatching.** One agent
  was killed mid-task and left a file whose own comment claimed seven constants had been re-recorded
  when they had not.

### What this produced today

- A `sonnet` agent concluded the reported stall did not exist. An `opus` verifier then reproduced it
  and found the real cause. **Both steps were necessary.**
- An agent reported the three scoring terms as live. It had read the pure service and missed the live
  producer. Verified false.
- Two of the orchestrator's own briefs contained errors that agents caught: phase 5 was sent out on a
  misreading of the movement model, and the phase 2 diagnosis was given to the wrong tier.

---

## 11. Not yet decided

| Question | Who decides |
|---|---|
| The scope of phase 2d — the straggler filter only, or all three sources | Jeff, after the provenance measurement |
| The Seer `idle_fear_aura`, once the label is corrected | Jeff, after the fear measurement |
| Where the contribution-ledger coverage gap belongs | Jeff, when phase 5 reaches that code |
| The final `max_barks_per_round` | Jeff, during the manual test |
| The five `response_thresholds` values | Measure the guidance-contest distribution first |
| The four commitment band cut points | No measured basis exists yet. Flag to the reviewer. |
