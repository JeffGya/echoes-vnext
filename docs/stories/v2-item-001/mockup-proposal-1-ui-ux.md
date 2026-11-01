# V2-ITEM-001a mockup proposal 1 of 3: UI/UX (structure, layout, flows)

Author: ui-ux-designer. Written in STE. Proposal only. No mockup and no code exists. Jeff approves this file before any build.
Owned here: structure, layout, flows, components, states, sizes, targets, sheet list. Binding: D-01 to D-30. Every player line is a PROPOSAL or `[wording]`; Jeff owns copy.
`[R6 ARTICLE]` cites `research-ui-best-practices.md`: section, evidence label. Most evidence is COMMUNITY or ARTICLE, so each use is a hypothesis to test.
Checked in code: the Sanctum fingerprint hashes sorted `actions` slot keys (`FlowSnapshotFingerprintTests.gd:194-213`). `InventoryController.handle_discard` accepts a discard only when the last snapshot is `flow.sanctum`.

## 1. Screen list

| # | Surface | Snapshot, shell | Chrome that stays | Data keys read | Decision | Feedback | Failure or disabled |
|---|---|---|---|---|---|---|---|
| S1 | Inventory panel | `flow.sanctum` (also `flow.echo_party`), SanctumShell | BottomRail | `data.inventory`: `items`, `pack`, `stacks`, `unique_count`, `unique_cap`, `sanctum_room`, `pack_count`, `pack_capacity`, `pack_free`, `pack_load`, `warn.room`, `warn.pack`, `discard_blocked` | Which piece to let go | Gauge, outline, strip | `path_open`: button disabled, reason line. Empty: no button. |
| S2 | Discard confirmation | ModalHost, layer 40 | Covered | Selected row (`type_id`, `kind`, `grade`, `mark_index`, carried). `id` only in the payload. | Keep or let go | Panel refresh | Refusal closes the modal; S1 shows the reason. |
| S3 | Party prep pack row | `flow.echo_party`; hub `PartyPanel` | Rail | `pack`, `pack_capacity`, `pack_free`, `pack_load.level` | Depart, or free room first | Socket posture | Empty pack: sockets only. |
| S4 | Departure chip | as S3 | Rail | `pack_load.carried`, `warn.pack` | Open S1 | Gold outline on `warn.pack` | Hidden at 0 carried. |
| S5 | Leave confirmation row | `flow.stage_explore`, RealmShell | EchoBar | `carry_home_preview.items_at_risk` | Leave or stay | None | No key: hidden. |
| S6 | Leave result tiles | `flow.resolve` `scout_return` | EchoBar | `data.items.kept`, `.lost` (`type_id`, `kind`, `grade`, `quantity`, `source`, `mark_index`, `reason_key`, `lost_quantity`) | Continue | Tile fate | No key: no row. |
| S7 | Defeat card tiles | `flow.resolve` defeat | EchoBar | `reward_breakdown[packs_lost].params.items` | Continue | Tiles lost | Ase-only: no row. |
| S8 | Stage-clear preview | `flow.resolve` stage clear | EchoBar | New core key, not yet named (D-30) | Continue | Three groups | No key: no row. |

Read `quantity` and `mark_index` with `int()`. `mark_index` -1 means no notch.

## 2. Placement

| | A. Hub panel, no flow state | B. Rail destination |
|---|---|---|
| Pattern | `SanctumScreen` already has local modes (`EchoDetailPanel`, institutions panel) | Vows and Weaving Rite are states |
| Backend | None; `data.inventory` exists | State id, `FlowInventoryState`, builder, nav action, controller arm, `_gate_state_for_keeper_intro`, `AppRoot.SANCTUM_FAMILY`, shell scene map, AGENTS.md table, tests |
| Recorded value | None moves | Nav slot adds an `actions` key: hash `a26556e1…` re-recorded |
| Discard guard | Works as is | `in_sanctum` must accept the new type |
| Rail | Five buttons | Sixth button in a 980-wide rail |

**Recommend A.** No core work, no hash move. Entry: a `StoragePanel` card on the hub, and the chip (S4). Cost of A: no deep link; Esc closes the panel before the screen. The panel is one component, so it can move to B later (ITEM-003, ITEM-004).

## 3. Layout

Mockup units are canvas pixels. Bottom exclusion about 116 (rail 88, gap 8, inset); verify at build.

| S1 region | 1280x720 | 1920x1080 | Rule |
|---|---|---|---|
| Header: back, title, `CapGauge` | 48 | 56 | Fixed |
| Carried row: label, sockets | 96, tile 64 | 112, tile 72 | Fixed; all `pack_capacity` sockets drawn |
| Piece grid | 12 columns x 4 rows | 18 x 7 | Column count recomposes |
| Stack row | 88 | 104 | Fixed |
| Detail strip (right) | 320 wide | 400 wide | Fixed |
| `Let it go` | Strip bottom, 48 high | 48 | Fixed |

- Tile 64 at 1280, 72 at 1920. Gap 8 and 12. Safe margin 16. Grid draws `unique_cap` cells: pieces, then empty sockets. Cap 8 is one row.
- One grid for pieces, a stack row below [R1 ARTICLE, hybrid]. No sort control in 001a.
- Never scroll: header, gauge, carried row, stack row, strip. The grid scrolls vertically above 48 cells (1280) or 126 (1920).
- Text floor 12 px at 1280x720 for every label, badge and numeral; body 14 or more [R8 OFFICIAL].
- At most 3 marks per tile: grade pips, notch or stack badge, carried glyph [R7 DEVELOPER].
- Gauge: filled pips plus numerals. `warn.room` changes shape and adds a label, never colour alone [R2 COMMUNITY, R7 ARTICLE].
- `Let it go` sits at the strip bottom. `BackButton` is top left. No sort or close control within 24 of it [R6 COMMUNITY, Stardew].

**S1 `.tscn`:** `InventoryPanel` > `Margin` > `Body` (HBox) > [`Main` (VBox) > `Header` (`BackButton`, `TitleLabel`, `CapGauge`), `CarriedBlock` (`CarriedLabel`, `PackSocketRow`), `PieceGrid`, `StackRow`], [`ItemDetailStrip` > `DetailTile`, `NameLabel`, `GradePips`, `RiskLine`, `BlockedLine`, `DiscardButton`], `EmptyState`.
**Hosts:** `SanctumScreen` adds `StoragePanel` (gauge plus 56-high card) in `RightStack` and a mode that hides `OverviewFlow`. `EchoPartyScreen` adds the same panel over `ThreePanelRow`.
**S3, S4:** `PackRow` footer (72 / 88 high) in both `PartyPanel` nodes: `PackRow` > `LoadMark`, `PackSocketRow`, `PackLoadChip`. It never scrolls with the party list.
**S5:** `AtRiskTiles` in `ReturnHomeModal/Content`, between `GatheredLabel` and `RiskLabel`. Tiles 56 / 64, wrap at 8.
**S6 to S8:** `ItemsSection` in `ResolveScreen/CardContent`, between `EarningsSummary` and `Ledger` (above the fold). Groups: S6 `KeptGroup`, `LostGroup`; S7 `LostGroup`; S8 `KeptGroup`, `CarriedGroup`, `LostGroup`. One `NameLine` below shows a name on focus or tap [R4 DEVELOPER]. S8 maps `ok` and `stack_limit` to the Sanctum group, `to_pack` to carried.

| Component | Status |
|---|---|
| `ModalHost`, `ResponsiveLayoutController`, `SafeAreaContainer`, `LivingTreeSystem.tres`, `StopMarkMotion` reduced-motion, `EmotionChip` (pattern for the chip) | Reuse |
| `ItemTile` (one scene, all 8 surfaces), `ItemTileRow`, `PackSocketRow`, `CapGauge`, `PackLoadChip`, `ItemDetailStrip`, `InventoryPanel`, `ItemDiscardModal` | New |

## 4. Flows

**Discard.**
1. Open S1 from `StoragePanel` or the chip.
2. Tap a unique tile. Outline and strip show. A stack shows no button. Select first, confirm second [R6 COMMUNITY, R9].
3. Tap `Let it go`. `ItemDiscardModal` opens, focus on `Keep it` [R6 ARTICLE]. Esc, Back, B and an outside tap all mean `Keep it`. Only an explicit press on the modal `Let it go` discards [R6 COMMUNITY, Fire Emblem].
4. Confirm dispatches `inventory.discard.apply { item_id }`. The modal closes. Selection clears and the strip empties, so a double tap finds nothing.
5. The snapshot rebuilds; the panel shows the result in place.
6. A refusal closes the modal and the strip shows `BlockedLine`.

**Party prep to departure.** S3 and S4 show on `flow.echo_party` and the hub. The chip opens S1 in place, no selection, no screen hop [R1 ARTICLE, XCOM]. Party choices are saved state and survive the panel.
**Leave.** S5 lists the tiles at risk before the roll; its existing focus is `Cancel` [R3, R9]. `Confirm` runs the roll. S6 shows each tile kept or lost; `to_pack` stays marked carried.
**Defeat.** S7 shows faded tiles, no red [R4 COMMUNITY, Darkest Dungeon]. `Continue` only; no input skips the tiles.
**Stage clear.** S8 shows once, whatever the destination (D-30).

| Target | Size |
|---|---|
| Tile (button) | 64 / 72 |
| `StoragePanel` card | 56 high |
| `PackLoadChip` hit area | 48 high |
| `PackSocketRow` | Not a target |
| `BackButton`, strip `Let it go`, modal `Let it go` | 48 |
| Modal `Keep it` | 56, primary |
| Gap between modal buttons | 24 or more |
| Result and at-risk tiles (name on focus) | 56 / 64, 8 apart |

**Focus order.** S1: `BackButton`, carried tiles left to right, grid row by row, stack tiles, `DiscardButton`, rail. Modal: `Keep it`, `Let it go`. Close returns focus to `DiscardButton`; after a discard focus goes to the first tile, or `BackButton` when none remain.

## 5. States to draw

| Screen | States |
|---|---|
| S1 | Normal (2 carried). Full (`warn.room`). Empty (no button). Selected carried piece. `discard_blocked`. Stack-only (no button). |
| S2 | Sanctum piece. Carried piece (risk line). |
| S3 | No carried (chip hidden). Two carried, room left. Pack full, `warn.pack` (gold outline). Sanctum full and pack full. |
| S5 | No items. One gathered. Gathered, held and stack. Eight tiles. |
| S6 | Mixed. All kept. All lost. Carried survivor, Sanctum full. Stack surplus (`lost_quantity`). |
| S7 | Gathered and held. Held only. |
| S8 | Three groups. Kept only. Lost only (`overflow`). |

Tile cases on every sheet: gear, relic, twin (same `type_id`, two `mark_index`), `mark_index` -1, stack, stack at limit, material (badge only), carried. Twin test (proposal): show two twins in colour and in grayscale.

## 6. Mockup sheet plan

Folder `docs/stories/v2-item-001/mockups/v1/`. Standalone HTML, no external runtime. Chromium headless PNG at true size, scale 1. Fonts from `v3/assets/`. Detail sheets stack frames: width = profile width, height = n x (profile height + 48). Magenta dashed boxes mark targets. Text shows as grey bars or `[wording]`. Tiles are neutral stand-ins until the artist proposal fixes the look.

| File | Canvas | Shows |
|---|---|---|
| `overview-1280x720`, `overview-1920x1080` | profile size | S1, S3, S5 to S8 at 0.3, flow arrows |
| `detail-<size>-inventory` | 5 frames | S1 normal, full, empty, selected carried, blocked |
| `detail-<size>-prep` | 4 frames | S3, S4 on party prep and hub |
| `detail-1280x720-discard` / `detail-1920x1080-discard` | 3 / 1 frames | S2 both pieces, S1 after / S2 carried |
| `detail-1280x720-leave-confirm` / `detail-1920x1080-leave-confirm` | 4 / 1 frames | S5 |
| `detail-<size>-leave-result` | 5 frames | S6 |
| `detail-<size>-defeat` | 2 frames | S7 |
| `detail-<size>-stage-clear` | 3 frames | S8 |
| `anatomy` | 1920x1080 | Regions, tile sizes, hit areas, focus order, scroll rule |

Both sizes: S1, S3, S4, S6, S7, S8 (cards recompose; items must stay above the fold). S2 and S5 are centred cards: full set at 1280, one frame at 1920. Total 17 files.

## 7. Risks and questions

**Risks**
1. Party prep refuses a discard today (Q1).
2. Rows carry no display name. The UI needs a name from config or a new key. No id may show.
3. The S8 key does not exist; S8 cannot be built until core names it.
4. Finds beyond free room vanish at path end and no key reports them. This is silent loss [R2 COMMUNITY, R9] (Q5).
5. The hub is dense at 1280; check `StoragePanel` against `ThreadPanel` and `ActiveEffectsPanel`.
6. "72 units" may be logical; `v4` lists 1920 as 1536 logical. The mockups use canvas pixels.

| # | Question | Recommendation |
|---|---|---|
| Q1 | May the chip on party prep open a discard that works there, or send the player to the hub? | Widen the core check to `flow.echo_party`. One small change; no screen hop. |
| Q2 | A (hub panel) or B (rail destination)? | A. |
| Q3 | Blocked discard: disabled with a reason, or hidden? | Disabled with a reason; a hidden rule cannot be learned. |
| Q4 | S6 to S8: grouped with headings, or one row with marks? | Groups on S8 (a preview); one marked row on S6 and S7. |
| Q5 | Must the encounter card show a find that had no room? | Yes, one tile row on the existing card. Core adds the keys. |
| Q6 | Small return for a discard, or a recovery path for loss? | No. D-02, D-04, D-19, D-20 bar both without new rules. Revisit with ITEM-004 [R5 COMMUNITY]. |

## What the research changed

| Research point | Answer | Evidence |
|---|---|---|
| Cancel or Back must never lead toward discard | Esc, Back, B and outside tap mean `Keep it`. No third state. | R6 COMMUNITY, ARTICLE |
| `Let it go` away from sort and close | Strip bottom; Back top left; no sort; 24 clear. | R6 COMMUNITY |
| Select, then confirm; focus on `Keep it` | Tile, strip button, modal. Selection clears after a discard. | R6, R9 |
| Text floor 12 px | Rule in section 3; mockups obey. | R8 OFFICIAL |
| Telling twins apart | Notch from `mark_index` on the tile and large in the strip. No source proves it. **Proposal to test** in colour and grayscale. An "equipped on" mark waits for ITEM-003 (`held_by` unused). | R1 gap, R7 ARTICLE |
| Warmer loss | Allowed now: faded lost tiles, kept beside lost on one card, a plain fact line. Barred without new rules: recovery or return (Q6). | R4, R5 |
| No silent loss in a rush | S5 warns first. S6 to S8 show every lost tile. Result cards have `Continue` only. Q5 covers no-room finds. | R2, R9 |
| Gamepad grid | Explicit focus order, section 4. | R1 ARTICLE |
| Summary first | Names on focus or tap. | R4 DEVELOPER |
| Not colour alone | Gauge, chip and carried state use shape plus label. | R7 ARTICLE |

Not used: sort button, lost-items box, type-to-confirm (too heavy for one piece, R6 ARTICLE).

## HAND-OFF TO THE ARTIST AND GAME-FEEL PROPOSALS

**Artist:** tile look (placeholder and final), icon per kind, grade frame; marks (grade pips, twin notch, carried glyph, at-limit capsule, stack badge, `LoadMark` levels 0 to 3); colour use (gold only for actionable or full; info blue is the Fearful colour); gauge shape at full; socket beds; chip with and without gold outline; kept and lost looks (no red); theme variations for `StoragePanel` and `PackRow`; grayscale check of twins.

**Game feel:** selection, strip fill, discard exit, neighbour shift, carried-piece glide, gauge ease; the 0.6 s lock after confirm; result stagger on S6 to S8; reduced-motion path; sound hints (discard, kept, lost, none on defeat); the no-room beat (Q5); panel open and close; focus return; warmth of the second-draw wording and the survivor beat.
