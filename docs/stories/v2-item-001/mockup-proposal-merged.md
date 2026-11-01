# V2-ITEM-001a mockup proposal (merged, for Jeff)

**STATUS 2026-11-01: Jeff answered decisions 1 to 7 (see D-31 and D-32 in `decisions.md`).** Placement is B: a BottomRail destination with its own flow state. Every other recommendation was accepted. Where this file says "hub panel", read "inventory screen (new rail destination)"; the hub keeps a count card and the chip as entries to it.

Written in STE. Merges `mockup-proposal-1-ui-ux.md`, `mockup-proposal-2-artist.md`, `mockup-proposal-3-game-feel.md`. Proposal only: no mockup and no UI code exists. Jeff approves this file, then the three agents build the mockups, then Jeff approves the mockups, then the UI is built.
Evidence base: `research-ui-best-practices.md` and `research-comparison.md`. Most evidence is community or article level. Treat each use as a hypothesis to test in play.

## 1. What the mockups will show

Eight surfaces, in the project's mockup format (standalone HTML, true-size canvases, Chromium PNG renders, magenta dashed tap targets, grey bars and `[Jeff's wording]` marks instead of final copy, README with OPEN decisions).

| # | Surface | Where | Reads |
|---|---|---|---|
| S1 | Inventory screen with the discard | new BottomRail destination `flow.inventory` (D-31) | `flow.inventory data.inventory` |
| S2 | Discard confirmation | ModalHost | selected row |
| S3 | Pack row at party prep | `flow.echo_party` | `data.inventory` pack and `pack_load` |
| S4 | Departure chip | party prep and hub | `pack_load`, `warn.pack` |
| S5 | Leave confirmation, tiles at risk | `ReturnHomeModal` | `carry_home_preview.items_at_risk` |
| S6 | Leave result, kept and lost tiles | `flow.resolve` | `data.items` |
| S7 | Defeat card, lost tiles | `flow.resolve` | `packs_lost` params items |
| S8 | Stage-clear card, item preview | `flow.resolve` | new key from D-30 (being built) |

17 files in `docs/stories/v2-item-001/mockups/v1/`: an overview and detail sheets per surface at 1280x720 and 1920x1080, plus `anatomy` (tile marks, states, colour tokens with measured contrast, tap targets, storyboards and CSS-only motion demos that respect reduced motion).

## 2. Settled by the three proposals (no decision needed unless you object)

| Area | Proposal |
|---|---|
| Tile | One `ItemTile` for all eight surfaces. Plate 64 (1280) or 72 (1920) on its own bed. At most 3 marks per tile. Stack = doubled plate edge plus count capsule. |
| Kind shapes (placeholder) | gear = portrait rectangle, relic = hexagon, consumable = triangle, material = two bars. No circle, no diamond. |
| Marks | Grade pips (small diamonds, 1 to 3 for now), twin notch (six shapes from `mark_index`), source mark (open leaf = carried from before, whole leaf = found this path), blank reserved zone for ITEM-003's equipped mark. |
| Five states | In the Sanctum, carried in the pack, at risk (four corner brackets), kept (heavier border), lost (ghost outline, art at 35%, marks at 60%). All readable in grayscale. |
| Colour | No new tokens. Soft blue `#7AB5C8`, terracotta, forest green and the rarity colours are forbidden for item marks. Gold only for actionable or full, always with an ink keyline. |
| Placeholder look | Hatch plus kind shape, solid outline. Dashed outline is for the lost state only. Final art (256 px icon per `type_id`, six category fallbacks) comes from a catalogue story. |
| Discard | Select tile, then `Let it go` at the strip bottom, then ModalHost. Default focus `Keep it`. Esc, Back, B and an outside tap all mean `Keep it`. `Let it go` is far from Back and any sort or close control. 0.25 s open window and 0.6 s lock after confirm. No hold, swipe or drag. |
| Loss tone | A leaf let go: fade to 0.35, lift 8 units, 0.5 s. No red, shake, shatter or strike. No sound on defeat. |
| Pacing | Item sequence capped at 2.4 s. Reduced motion = 0.15 s fade. Result is true from frame 0. |
| Text | 12 px floor at 1280x720. Names on focus or tap. Items never shown as ids. |
| Core data the UI needs (small additions) | A display `name` on each row from the item definition; the D-30 stage-clear key. |

## 3. Decisions for Jeff

| # | Decision | Recommendation | Cost of the other |
|---|---|---|---|
| 1 | Where the inventory lives: (A) a hub panel with no new flow state, or (B) a new BottomRail destination | A | B adds a state, controller and nav action, and moves the recorded Sanctum hash |
| 2 | Allow the discard on party prep (`flow.echo_party`) as well as the hub | Yes: widen the core check | Without it the chip must send the player to the hub |
| 3 | Result cards: first tap finishes the motion, second continues | Yes | A card with no skip is 0.75 s on defeat but forces waiting on repeat paths |
| 4 | Show finds that had no room: a tile row on the encounter card plus a mini pack row | Draw it in the mockups as parked for ITEM-002 (which owns find presentation); build only the core keys now | Building it now needs UI on the encounter card and has no real producer to test with |
| 5 | A blocked discard (`path_open`): disabled with a reason, or hidden | Disabled with a reason | A hidden rule cannot be learned |
| 6 | Artist defaults: pips 1 to 3 only and no rarity colour; six twin shapes (1 in 6 twin pairs share one); two leaf glyphs; lost fill 35% and marks 60% | Accept all four | Fewer shapes or one leaf lose information on the leave panel |
| 7 | Feel defaults: 0.25 s open window on modal `Let it go` and on the leave `Confirm`; one pulse on the gauge pip when the Sanctum first becomes full; the carried-piece glide after a discard | Accept all three | The leave `Confirm` change touches an existing modal |

Not proposed (and why): a recovery path or a small return for a discard (D-02, D-04, D-19, D-20, D-21 bar it without new rules; revisit with ITEM-004), a sort button, type-to-confirm (too heavy for one piece), undo (D-21).

## 4. Findings you should know

- The design-system file states wrong contrast numbers: gold on the warm panel is 1.72:1, not 4.8:1, and warm tan is 3.66:1, not 5.2:1 (the artist recomputed them). Every gold mark gets an ink keyline. Fixing the file waits until after this story.
- The spiral (a full Sanctum, so a full pack, so fewer picks) has its cause and symptom minutes apart. The proposal bridges it with the same pack socket row at party prep, on the encounter card and on the stage-clear card. Decision 4 settles how much of that is built.
- No research source shows how a game marks an equipped piece against a spare twin. The twin notch is a proposal to test in play, in colour and in grayscale.
- Sound and haptic items are hints: the project has no audio layer.

## 5. Build plan after approval

1. Mockups, built by the three agents in sequence: UI/UX designer (sheets and layout), artist (tiles, marks, swatches, anatomy), game feel (storyboards and CSS-only motion demos). Chromium renders the PNGs at true size. I view every PNG and fix defects before I show you.
2. You review the mockups and the README's OPEN list.
3. Then step 7: the UI build in `.tscn` (new theme styles in `LivingTreeSystem.tres`), then verification and your play test.
