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

### Emotion changes need an actor beat; barks need spoken timing

**Rule:** Pair visible support or self-regulation outcomes with readable actor movement as well as the emotion chip; reveal barks progressively in the moment.
**Why:** Jeffrey found Feel Section C too dependent on emotion-bar options and asked for more visible Echo movement/action and typewriter speech.
**How to apply:** Give supplied source actions anticipation and commitment, and changed recipients a visible settle without inventing passive actions or healing. Keep unchanged outcomes quiet; drive progressive speech from the shared playback clock and show full text in rest/reduced motion.
**Mistake count:** 1

### Emotion feedback uses the shared Sanctum palette

**Rule:** Flash an emotion change in the matching shared emotion colour, not a generic gold highlight.
**Why:** Jeffrey directed the combat Feel mockup to reuse the Sanctum emotion colours.
**How to apply:** Trace Sanctum's `EmotionPresentation.text_theme()` to `EmotionStatus*/colors/font_color` in `LivingTreeSystem.tres`; use that colour for the transient flash and preserve readable text contrast.
**Mistake count:** 1

### Prototype tokens still need expressive game feel

**Rule:** Combat mockups must show anticipation, commitment, impact and recovery, even while actors remain simple tokens. Keep cards, screens and the board regular, and preserve the requester-selected graphic iteration.
**Why:** Jeffrey found direct token motion and subtle chip changes stiff and emotionally unreadable. Extending organic shapes into cards, screens and the board exceeded the assignment; after reviewing the internal cue changes, he requested restoration of the previous rigid-line iteration.
**How to apply:** Preserve the restored rigid graphic baseline until another visual change is requested. Keep expressive motion and clear damage/recovery feedback; a request for storybook feeling does not make a new silhouette treatment approved.
**Mistake count:** 3

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

### 28 — Isometric art needs one projection contract and uniform sprite scale

**Rule:** Define the tile basis, footprint, foot anchor, and asset camera angle once.
Never make an isometric asset fit the world through nonuniform destination scaling or
screen-space occupancy offsets.
**Why:** The Sanctum prototype used a mathematically 2:1 coordinate transform but
then squeezed square character atlas cells into tall narrow rectangles. The map was
also built mainly from flat polygons and upright primitives, so the character art
and village did not share one believable plane.
**How to apply:** Use a 2:1 tile top, transform every ground and occupancy coordinate
through the same basis, preserve each sprite cell's aspect ratio, anchor characters
at their feet, and depth-sort buildings, foliage, places, and Echoes by their ground
anchor. Validate the generated asset angle against the tile diamond before producing
the full set.
**Mistake count:** 1

---

### 27 — Optional card fields must not reserve empty layout space

**Rule:** Let contextual cards size themselves from the fields they actually show. Hide empty labels and rows, and do not impose a tall minimum height intended for the fullest card variant.
**Why:** Echo Recent cards reused the full village-history card height even though first-person memories omit most metadata. This produced large blank gaps, while wrapped memory text could appear clipped or incomplete.
**How to apply:** Author compact reusable structure in `.tscn`, give wrapped text a real available width, hide absent fields in the renderer, and test both sparse and dense variants with long text at all supported layout profiles.
**Mistake count:** 1

---

### 26 — Seeing an incident does not grant the Keeper permission to intervene

**Rule:** Treat incident visibility and intervention authority as separate simulation states. A warning may be observable while mechanically private; `can_join` must come from authoritative access state, and rejected intervention commands must not mutate the incident.
**Why:** The Sanctum prototype made every warning eventually actionable. Even though ignored incidents resolved autonomously, this still positioned every disagreement as the Keeper's business and made village autonomy feel cosmetic.
**How to apply:** Give social incidents explicit private, open, or appeal access at creation. Show the premise before any decision. Private incidents expose no intervention action and reject direct or stale join commands; open incidents allow optional help; appeals name who asks. All three may resolve without the Keeper and leave consequences the player deals with later.
**Mistake count:** 1

---

### 25 — Realm continuity must be designed as geography, not implied by palette

**Rule:** When a Realm is physically connected to an established location, show the complete entry, traversal, objective, and return geography in the environment itself. Preserve the project's exaggerated storybook proportions at the silhouette stage instead of letting realistic terrain return beneath watercolor rendering.
**Why:** The first starter-Realm pass introduced an unrelated forest, and the improved floating-island pass still began drifting toward realistic cliff proportions and surface density. Jeff clarified that the opening uses an ordinary Sanctum gate, a bridge to a first battle island, a second bound-ember island, and bridge traversal back to the Sanctum so the ember can relight the Ase Flame.
**How to apply:** Before generating a connected Realm, diagram the physical sequence in words and require every transition to appear in the wide shot. Match the established location's architecture, ecology, and floating-island logic; exaggerate plateaus, bridges, structures, trees, and focal objects before adding watercolor and gouache; reject forest or terrestrial-biome substitutions, realistic geology, and micro-stone texture.
**Mistake count:** 2

---

### 24 — The starting Sanctum is dormant, not broken

**Rule:** Communicate the starting Sanctum's inactivity through intact spaces at rest, not through ruins, collapse, or structural damage.
**Why:** The structurally stylized pass still framed the Sanctum as a broken village through missing roofs, lost plaster, a collapsed shelter, shattered pottery, and a snapped tree limb. Jeff clarified that dormancy is the intended state.
**How to apply:** Keep buildings, tree, hearth, vessels, and work structures whole. Use cold ash, closed shutters, covered or stored tools, settled dust, still air, sparse edge growth, and empty gathering space to show a sacred house waiting to wake. The player should anticipate activation and habitation, not reconstruction from destruction.
**Mistake count:** 1

---

### 23 — Environment stylization must change geometry, not only rendering

**Rule:** Stylize buildings, trees, objects, terrain, and perspective at the shape-design stage. A realistic world with flatter paint, ink lines, or paper grain is still a realistic world.
**Why:** The first Dormant Sanctum revision changed the visual layer but kept ordinary house proportions, botanical tree anatomy, natural perspective, and realistic environmental density. It therefore remained outside the approved storybook language despite the new surface treatment.
**How to apply:** Redraw from silhouette outward: exaggerate roof-to-wall ratios, compress and taper structures, group foliage into large masses, simplify roots and branches into calligraphic forms, enlarge focal objects, reduce micro-detail, and stage depth in a few designed layers before applying painterly finish.
**Mistake count:** 1

---

### 22 — Echo settlement reads through coverage and fraying; mood reads through hue

**Rule:** Keep Story-colour coverage, loose-thread count, and patch hue as separate visual channels. Coverage and fraying decrease from Unsettled through Settled; hue may shift with mood; Mythical Echoes have neither patches nor loose Threads.
**Why:** The first identity progression treated colour and woven pattern as a vague transformation effect. It did not communicate the required physical rule: large solid skin-replacement patches whose boundaries unravel, then diminish and settle as the Echo gains Weavings, Storyweight, and Standing.
**How to apply:** Use one solid hue per Echo at a time; allow non-contiguous skin patches; place loose Threads around every unresolved patch boundary; never colour clothing; enforce the coverage bands in `docs/art-direction.md`; and treat Mythical as a rare, separately governed older state rather than an automatic visual rank-up.
**Mistake count:** 1

---

### 21 — North-star art must inherit approved character style and documented material culture

**Rule:** Treat approved character ledgers as hard style constraints in every later concept board, and derive Ghanaian textiles from documented weave and garment construction rather than decorative approximation. Every supporting vignette must also communicate a clear game-world function.
**Why:** The first north-star pass drifted back toward realistic Echoes, invented textile swatches, an ambiguous face-to-face scene, a tree/building hybrid, and generic covered gates that did not express the Sanctum, unresolved identity, or Anansi-web world clearly.
**How to apply:** Before filing a moodboard, check each character against the locked face/body sheets; keep sacred trees and village architecture physically distinct; source kente and fugu through real strip-weave, seam, stripe, and garment structures; and replace generic fantasy portals with world-specific web ruptures or Realm fragments. Preserve successful studies without inheriting rejected panels.
**Mistake count:** 1

---

### 20 — A weapon is defined by combat function, not ceremonial silhouette

**Rule:** Keep regalia, state weapons, office objects, and passive ritual objects out of the ordinary weapon catalogue unless a distinct item definition gives them a concrete combat action. Bells, drums, beads, vessels, and similar forms may be weapons only as explicit spiritual or story-power conduits with targeting, effects, timing, telegraphing, and counterplay.
**Why:** The Calling equipment study blurred ceremonial or state objects into usable weapons, even though the current game has little combat purpose for them. This made the weapon set staff-heavy and visually evocative without establishing how the objects fight.
**How to apply:** Research both an object’s form and documented use. Classify historical regalia separately from combat equipment. Run every proposed weapon through a combat admission test; if it cannot describe its action profile, place it under relic, charm, consumable, regalia, or story item instead.
**Mistake count:** 1

---

### 19 — Calling identity and weapon identity are independent axes

**Rule:** Never assign a canonical or exclusive weapon set to a Calling. Every Calling can equip every weapon; Calling-and-weapon fit is a soft bias that changes fluency, behavior, and expression rather than eligibility.
**Why:** A Calling is a way an Echo becomes and acts, while a weapon changes action profile and tactical opportunity. Treating a resonant concept-art pairing as ownership silently turns soft fit into a class lock and makes Calling diversity depend on equipment.
**How to apply:** Define Calling through posture, decision grammar, garment silhouette, and gear distribution. Define weapon families separately. Test the same weapon across all Callings, showing different grips, timing, stance, and intent. Use resonant/adaptive/tension internally and preferred/disliked in player-facing summaries; never “allowed,” “required,” or “signature weapon.”
**Mistake count:** 1

---

### 18 — Visual plans are UX/game-feel artifacts, not code evidence

**Rule:** Do not include code evidence, route tables, raw scan output, file inventories, or implementation proof in visual-plan prototypes unless Jeff explicitly asks for an engineering audit.
**Why:** Jeff clarified that the visual plan exists to improve game feel, UX, and UI; code evidence is not the desired output.
**How to apply:** Use scans only as internal grounding. The exported artifact should show player journey, wireframes, decision weight, feedback, friction, improvement opportunities, and playtest prompts.
**Mistake count:** 1

---

### 17 — Visual planning must be prototype-first, not code-inventory-first

**Rule:** Visual planning artifacts must lead with user flows, screen wireframes, decisions, feedback, and game-feel questions. Code scan output belongs in collapsed supporting evidence, not the main experience.
**Why:** Jeff rejected the first Echoes visual-plan export because it was a collection of services/code examples rather than a useful prototype, wireframe, or user flow.
**How to apply:** When exporting HTML visual plans, make the first viewport a journey board or screen mockup. Use scanned files, services, routes, and snapshot builders only to ground labels and verify implementation reality.
**Mistake count:** 1

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
