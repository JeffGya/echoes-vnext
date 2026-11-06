# V2-ITEM-001a inventory screens, mockup set v1

Written in STE by the ui-ux-designer. Static sheets for approval. No code, scene or data is changed. All player text is AGENT-WRITTEN PLACEHOLDER wording from `wording.md` (dotted underline in the sheets). A grey bar remains only where `wording.md` has no slot. Existing game text (rail labels, `Return to the Sanctum`, `Stay`, `To the Sanctum`, `Continue`) is drawn as it is in the game.
Binding: D-30, D-31, D-32 in `../../decisions.md`. Plan: `../../mockup-proposal-merged.md`, `../../mockup-proposal-1-ui-ux.md`.
The feel agent appends a storyboards section at the end of this file.

**Wording status.** All wording in these sheets is AGENT-WRITTEN PLACEHOLDER from `wording.md`. Jeff edits it after the play test. The old `[Jeff's wording]` marks and the grey item-name bars are gone. Each placeholder is a `<span class="wording" data-slot="<slot id>">`. The command `grep -r 'data-slot' *.html` finds every slot. Item names use `<span class="name-ph wording" data-slot="item-...">`. The interactive prototype is `docs/visual-plans/inventory-ui-mockup.html`.

## 1. Files

True-size canvas. Detail sheets stack frames; the overviews scale the canvas (0.3 at 1280, 0.2 at 1920). Magenta dashed box = tap target (48 or more, 8 apart). Fonts load from `../../../v2-directive-002/mockups/v3/assets/`.

| File | Author | Shows |
|---|---|---|
| `wording.md` | agent | Placeholder wording: 42 game-text slots and 6 item names, keyed by `data-slot`. Jeff edits it. |
| `shared/items.css` | artist | All item classes: tile, marks, five states, `CapGauge`, sockets, chip, strip, buttons, modal, `.result-shelf`. Not restyled here. |
| `shared/screens.css` | UI/UX | Existing game chrome only (rail, cards, EchoBar pills, backdrop) and sheet helpers. |
| `anatomy.html`, `anatomy.png` | artist (feel agent adds motion demos) | Swatches, contrast, tile construction, states, twin test, tap targets, 1280 tile. |
| `overview-1280x720`, `overview-1920x1080` (`.html`, `.png`) | UI/UX | S1 to S8 side by side, flow strip, one label block per screen. |
| `detail-<size>-inventory` | UI/UX | 7 frames: normal (2 carried), full (`warn.room`), empty, carried piece selected, `discard_blocked`, stack selected, and the hub entry (count card and chip). |
| `detail-<size>-discard-modal` | UI/UX | 2 frames: Sanctum piece, carried piece (risk line). Layer 40 over all chrome. |
| `detail-<size>-party-prep` | UI/UX | 4 frames: no carried, two carried, pack full (`warn.pack`), Sanctum full and pack full. |
| `detail-<size>-leave-confirm` | UI/UX | 4 frames: no items, one gathered, gathered and held and stack, eight tiles (wrap). Focus `Cancel`. |
| `detail-<size>-leave-result` | UI/UX | 5 frames: mixed, all kept, all lost, carried survivor with a full Sanctum, stack surplus (`lost_quantity`). |
| `detail-<size>-defeat` | UI/UX | 2 frames: gathered and held, held only. |
| `detail-<size>-stage-clear` | UI/UX | 3 frames: three groups, kept only, lost only (`overflow`). |
| `detail-<size>-encounter-parked` | UI/UX | PARKED frame for ITEM-002. |

`<size>` is `1280x720` or `1920x1080`. Each has an `.html` source and a `.png` render.

## 2. Screens: label blocks

| | S1 Inventory screen | S2 Discard confirmation | S3 Pack row, party prep | S4 Hub entry and chip |
|---|---|---|---|---|
| Snapshot type | `flow.inventory` (new, D-31) | ModalHost layer 40 | `flow.echo_party` | `flow.sanctum` |
| Shell | SanctumShell | any | SanctumShell | SanctumShell |
| Persistent chrome | BottomRail, 6 buttons, sixth selected | none (all covered) | BottomRail (Depart is the gold button) | BottomRail |
| Primary decision | Which piece to let go | Keep it or let it go | Depart, or free room first | Open the inventory screen |
| Feedback surface | `CapGauge`, selection ring, detail strip | Screen refreshes after confirm | `LoadMark` level, socket posture | Count card, chip, gold outline on `warn.pack` |
| Failure or disabled | `discard_blocked`: `Let it go` disabled and a reason line. Empty: no button. Stack: no button. | A refusal closes the modal; S1 shows the reason | Empty pack: sockets only | Chip hidden at 0 carried |

| | S5 Leave confirmation | S6 Leave result | S7 Defeat card | S8 Path-end card |
|---|---|---|---|---|
| Snapshot type | `flow.stage_explore`, `ReturnHomeModal` | `flow.resolve`, run_type `scout_return` | `flow.resolve`, defeat | `flow.resolve`, path-end card (D-30) |
| Shell | RealmShell | RealmShell | RealmShell | RealmShell |
| Persistent chrome | EchoBar | EchoBar | EchoBar | EchoBar |
| Primary decision | Leave or stay | Continue | Continue | Continue |
| Feedback surface | None (a list of stakes) | Tile fate: kept, carried, lost | Ghost tiles, no red | Three groups |
| Failure or disabled | No key: row hidden | No key: no row | Ase-only defeat: no row | No key: no row |

## 3. Node-tree outlines (updated for D-31)

**New flow state.** `FlowInventoryState` builds snapshot `flow.inventory` (SanctumShell family). It carries the same `data.inventory` projection as the hub. Core work comes before the UI build (D-31): state id, builder, nav action (new `actions` slot key, one re-record of the Sanctum fingerprint), controller route, keeper-intro gate, `AppRoot.SANCTUM_FAMILY`, SanctumShell scene map, `AGENTS.md` shell table, tests.

**Rail.** `BottomRail > MarginContainer > RailButtons` gets a sixth `Button`, `InventoryButton`, after `WeavingButton`. It binds like `_bind_button(_inventory_button, _action_for_slot(<nav slot>), ...)`. The slot name is for core to set. The rail stays 980 wide: each button is about 143 wide, 56 high. The selected state is a cream fill with ink text and a thin gold underline. No gold fill, because `RealmButton` keeps the only gold fill.

**S1 `InventoryScreen`** (scene in the SanctumShell map): `Margin` > `Panel` (`SanctumCard`) > `Body` (HBox) > [`Main` (VBox) > `Header` (`BackButton`, `TitleLabel`, `CapGauge`), `CarriedBlock` (`CarriedLabel`, `PackSocketRow`), `PieceBlock` (`PieceLabel`, `PieceGrid`), `StackBlock` (`StackLabel`, `StackRow`)], [`ItemDetailStrip` > `DetailTile`, `NameLabel`, `GradePips`, `MarkLegend`, `RiskLine`, `BlockedLine`, `DiscardButton`], `EmptyState`. `BackButton` returns to `flow.sanctum` as Vows does.

**Hub** (`SanctumScreen`): `StoragePanel` (56-high card with `CapGauge` and a chevron) in `RightStack` under `ThreadPanel`. `PackLoadChip` in `PartyPanel/PartyMargin/PartyStack`. Both navigate to S1.

**S2** `ItemDiscardModal` in `ModalHost`: `DetailTile`, `NameLabel`, `GradePips`, `QuestionLabel`, `RiskLine` (carried only), `ButtonRow` (`KeepButton`, `ConfirmDiscardButton`).

**S3** `EchoPartyScreen/RootVBox/ThreePanelRow/PartyPanel` gets a `PackRow` footer: `LoadMark`, `PackSocketRow`, `PackLoadChip`. The chip row keeps its height when the chip is hidden.

**S5** `ReturnHomeModal/SafeFrame/Center/Card/Content` gets `AtRiskTiles` (wrap) and `NameLine` between `GatheredLabel` and `RiskLabel`.

**S6 to S8** `ResolveScreen/.../CardContent` gets `ItemsSection` between `EarningsSummary` and `Ledger`. S6 uses `KeptGroup`, `CarriedGroup`, `LostGroup`; S7 uses `LostGroup`; S8 uses all three. Each group is a label cell and a shelf. One `NameLine` shows a name on focus or tap.

**S2 and S5 share** the modal focus rule: S2 default focus `Keep it`; S5 default focus `Cancel`.

## 4. Data keys and what they draw

Key names only. The UI never prints an id. Read `quantity`, `mark_index`, `lost_quantity` with `int()`.

| Key | Drawn as |
|---|---|
| `data.inventory.items` | Pieces in `PieceGrid`. Row keys: `type_id`, `kind`, `grade`, `mark_index`. |
| `data.inventory.pack` | Carried tiles in `PackSocketRow` (darker bed, open leaf). |
| `data.inventory.stacks` | `StackRow` tiles. `quantity` is the capsule, `at_limit` is the gold capsule. |
| `unique_count`, `unique_cap` | Gauge fill and the cell count of `PieceGrid`. |
| `sanctum_room`, `warn.room` | Gauge `near` and `full` state, plus a label. |
| `pack_count`, `pack_capacity`, `pack_free` | Sockets filled and free. |
| `pack_load.level`, `pack_load.carried` | `LoadMark` 0 to 3; chip shown when `carried` > 0. |
| `warn.pack` | Gold outline on the chip. |
| `discard_blocked` | `Let it go` disabled and the reason line. |
| `carry_home_preview.items_at_risk` | `AtRiskTiles` (brackets). Absent key: no row. |
| `data.items.kept`, `data.items.lost` | Groups on S6 and S8. |
| `reason_key` | Group choice on S8: `ok`, `stack_limit` to Sanctum; `to_pack` to carried; `overflow` and other lost reasons to lost. |
| `source` | Leaf: `held` is the open leaf, `gathered` the whole leaf. |
| `mark_index` | Twin notch (six shapes); -1 draws none. |
| `lost_quantity` | Ghost stack tile beside the kept stack. |
| `reward_breakdown[packs_lost].params.items` | Lost tiles on S7. |

## 5. SETTLED

| Ref | Settled |
|---|---|
| D-30 | The path-end item report shows on the path-end card (S8), once, as a read-only preview from `data.items`. |
| D-31 | The inventory is a new BottomRail destination with its own flow state. The hub keeps a count card and the chip as entries. The party-prep chip navigates to the inventory screen. |
| D-32 | Result cards: first tap finishes motion, second continues. Finds with no room are drawn PARKED for ITEM-002. A blocked discard shows `Let it go` disabled with a reason line. Artist and feel defaults accepted. |

## OPEN: Jeff decides

| # | Question | Recommendation |
|---|---|---|
| 1 | Where the sixth rail button sits and what it is called. The sheets put it last. | Keep it last. Use a short label. |
| 2 | Selected look of a rail button. The game has none today. The sheets use a cream fill. | Accept the cream fill. Gold stays for `Choose Realm`. |
| 3 | The result card is 476 high today. Two or three shelves above the fold need 560. | Grow the card to 560 when `ItemsSection` shows. Keep 476 otherwise. |
| 4 | Result tiles use the artist's 72 bed (80 at 1920), not the 56 and 64 of the plan. Eight tiles then fit a 632 row. | Keep 72. It meets the 48 target with margin and the marks stay readable. |
| 5 | Party prep footer: reserve the chip row when the chip is hidden, or let the footer grow. | Reserve it. The sockets then do not jump. |
| 6 | The gauge: `warn.room` is true from room 2 (6 of 8). The sheets draw `near` for 6 and 7 and `full` for 8. | Use `near` for `warn.room` and `full` for room 0. |
| 7 | `BackButton` sits inside the panel header on S1. Echo Party puts it outside, at 16,16. | Keep it inside the header, 48 high, away from `Let it go`. |

## 6. Wording slots (AGENT-WRITTEN placeholder, Jeff edits)

Every line below is a PROPOSAL from the design files. A dash means no proposal exists. `wording.md` holds the placeholder text now drawn in the sheets, one `data-slot` id per line.

| Slot | Where | PROPOSAL line | Source |
|---|---|---|---|
| Rail label | `InventoryButton` | - | none |
| Screen title | `TitleLabel` | - | none |
| Gauge label at `near` and `full` | `CapGauge` | `The Sanctum is full. These stay in their packs.` | `design-sr-game-designer-v2.md` line 137 |
| Empty screen | `EmptyState` | `Nothing is stored yet.` | `design-feel-game-feel-developer-v2.md` line 153 |
| Carried risk, strip and modal | `RiskLine` | `It may be lost on a path.` | feel v2 line 127 |
| Blocked reason | `BlockedLine` | - | none |
| Discard question | modal | `Let this go? It cannot be brought back.` | design v2 line 137, feel v2 line 134 |
| Buttons | modal and strip | `Keep it`, `Let it go` | feel v2 lines 127 to 135 |
| Chip tooltip | `PackLoadChip` | `They may lose what they carry.` and, with low room, `They have less room to carry this time.` | feel v2 line 52 |
| Leave row | `AtRiskTiles` | `They may lose 3 pieces. 1 was carried from before.` (second sentence only when a carried piece exists) | feel v2 line 58 |
| Carried survivor | S6 note | `The Sanctum is full. These stay in their packs.` | design v2 line 137 |
| Defeat | S7 | `Lost. The party fell.` | design v2 line 137 |
| No-room find (PARKED) | encounter card | `Lost. There was no room.` (once per path) | feel v2 line 32 |
| Group labels (kept, carried, lost) | `ItemsSection` | - | none |

## 7. Friction notes

1. No real screenshot of the Sanctum, party or result screens is tracked in git. Only concept art exists. The chrome is drawn from the `.tscn` files and `LivingTreeSystem.tres` values. I drew these as labelled blocks: the world layer, `StageExploreScreen`, `CombatBoard`, the Echo Party panel contents, the ledger rows and the EchoBar cards (copied from the v4 pills). `ButtonSecondary` has no style in the theme file; the rail buttons copy the gold-outline secondary style.
2. At 1920 the existing chrome is drawn at 1.25 (the 1536 logical canvas, as in v4). Item sizes follow the artist (bed 72 and 80), so the tile-to-chrome ratio differs a little between the two sizes.
3. `unique_cap` is 8, so `PieceGrid` is one row. The plan's 12 by 4 grid applies only to a larger cap. The screen has much free space at this cap.
4. A 560-high card overlaps the dimmed EchoBar by about 24 (see OPEN 3).
5. At 1280 the third panel of party prep is 380 wide inside. `LoadMark` and four sockets fill it, so the chip goes on its own row.
6. The result footer shows one `Continue`. The real card has `SanctumButton` and `NextStageButton`; the plan says `Continue` only for S6 to S8.
7. Chip and count card are two entries to one screen. Test whether both are needed.
8. Disabled `Let it go` keeps its tap box in the sheets so its size shows. It takes no input.

## 8. Playtest prompts

1. Open the inventory from the rail, then from the hub card, then from the chip. Do all three feel like the same place?
2. Can you tell two twin pieces apart in colour and in grayscale?
3. Can you read the full Sanctum state without the label?
4. Is a disabled `Let it go` with a reason clearer than no button?
5. At party prep, do the sockets tell you the pack is heavy before you depart?
6. On the leave confirmation, does the tile row change your choice?
7. On a result card, do you see kept, carried and lost before you tap?
8. Do eight tiles on S5 still read at 1280?

## 9. Game-feel cards

Each card rates the screen on five points: clarity, motivation, response, satisfaction, fit. A rating is a hypothesis for the play test.

| Screen | Clarity | Motivation | Response | Satisfaction | Fit |
|---|---|---|---|---|---|
| S1 Inventory | Three rows and one strip; the selected tile has a ring. | Free room is visible, so a discard has a reason. | Select shows the strip at once. | The gauge empties by one bar after a discard. | A new rail place like Vows. |
| S2 Discard | One question, two buttons, `Keep it` has focus. | Stakes are clear: the tile is large. | 0.25 s open window guards a stray tap. | A quiet close. | Same modal host as the leave panel. |
| S3 Party prep pack | Sockets show weight by position. | The warning comes before departure. | Chip opens S1. | Depart stays the one gold button. | Sits in the existing panel. |
| S4 Hub entry | Count and chip are small cards. | Shows the spiral cause early. | One tap to S1. | None. | Hub is dense at 1280. |
| S5 Leave confirm | A plain list of stakes with brackets. | Gives a reason to stay or go. | `Cancel` has focus. | None. | Extends the existing modal. |
| S6 Leave result | Three shelves, shelf rule and tile state agree. | Kept tiles feel earned. | The first tap finishes the motion. | A settled tile has a heavier border. | Sits above the ledger. |
| S7 Defeat | Ghost tiles are a record, not an alarm. | None: it is a statement. | Continue only. | None. | Existing `packs_lost` row stays. |
| S8 Path-end | A forecast in three groups. | Shows what the Sanctum will take. | Static preview. | Kept group first. | Beside Ase and Ekwan lines. |

## 10. Feel: storyboards, motion demos, beats

Written in STE by the game-feel-developer. Source: `../../mockup-proposal-3-game-feel.md`, with D-31 and D-32 applied. Every player line is a PROPOSAL or placeholder wording from `wording.md`. Sound and haptic items are HINTS: the project has no audio layer. `[R<n> LABEL]` cites `../../research-ui-best-practices.md`. Most evidence is COMMUNITY or ARTICLE, so each use is a hypothesis for the play test.

### 10.1 Files

| File | Shows |
|---|---|
| `storyboard-discard-carried.html/.png` | S2 with a carried piece. 6 frames: modal 0.00 s and 0.25 s, then +0.15, +0.50, +0.80, +0.95 s after confirm. Ghost path and ghost box for the glide. |
| `storyboard-leave-result.html/.png` | S6, 4 items, some kept and some lost. 6 frames from 0.00 s to 1.95 s. Kept tiles slide toward a Sanctum glyph (ghost arrow). Lost tiles end at 0.35 with lift 8. |
| `storyboard-defeat.html/.png` | S7, 3 items. 4 frames, 0.00 s to 0.75 s. All tiles together, no stagger. |
| `storyboard-stage-clear.html/.png` | S8 preview, 3 groups. 4 frames, 0.00 s to 0.55 s. |
| `motion-demos.html/.png` | Five CSS-only loop demos: (a) lost motion, (b) leave-result stagger, (c) discard with glide, (d) gauge pip pulse, (e) modal open window. No script. |
| `anatomy.html/.png` | Region "Motion demos": copies of (a) and (c). |

Each storyboard is a 1920x1080 canvas. Each has a timeline bar with the 2.4 s cap marked, and the skip rule note. No 1280x720 version is drawn: no card recomposes for 3 or 4 tiles. A 1280 version is needed only for the 8-tile case (see OPEN 3 above).

**How to use the demos.** Open `motion-demos.html` in a browser. Each demo loops: a lead, the beats, a 1.5 s rest, a reset fade. The time label names each beat. Tick the box "Reduced motion" to test the 0.15 s fade without the OS setting. The page also follows `prefers-reduced-motion`. Add `#still` to the address to freeze every demo at its end state (the PNGs are made this way).

**Frame times.** The proposal lists frame times that mix two clocks. These boards use one clock per board. The leave-result frames use tile start times (0.55, 0.85, 1.15, 1.45 s). The discard frames after confirm use seconds after the press. Fill values come from the QUAD ease-out curve. At 0.50 s of a 0.5 s motion that started at 0.25 s, fill is 0.51, not the 0.6 of the proposal. See OPEN 1.

### 10.2 Per-screen beat table

| Screen and beat | Order, time, easing | Player feels | Sound hint / haptic hint | Reduced motion |
|---|---|---|---|---|
| S1 open | Panel fades in and rises 12 units, 0.25 s. Close: fade 0.18 s. | A drawer opens. | Soft paper slide / none | 0.15 s fade |
| S1 select tile | Press 0.08 s. Outline at once. Strip cross-fades 0.12 s. | The tile answered. | Light tick / light tap | Outline at once, strip 0.15 s fade |
| S1 gauge | Pips step. Numeral eases 0.3 s. On first entry to full, the last pip pulses once (1.0, 1.15, 1.0, 0.4 s). D-32: accepted. | The Sanctum became full. | None / none | Pip changes shape, no pulse |
| S2 open | Backdrop 0.15 s. Card fades and rises 4. Focus on `Keep it`. `Let it go` at 70 percent and no input for 0.25 s (D-32: accepted). | A pause with weight. | Low soft tone / none | 0.15 s fade. The window stays. |
| S2 confirm | Modal closes 0.15 s. Tile: lost motion with lift, 0.35 s, then fade to 0 in 0.15 s. Neighbours shift 0.25 s after the lost motion starts. Selection clears at once. | A leaf let go. The gap closes. | Leaf-fall tone, once / one low thump | Tile fades 0.15 s. Neighbours jump. |
| S2 glide | Only when core moves a carried piece into the freed place. Glides 0.4 s (SINE), starts 0.2 s after the lost motion starts. Carried bed fades 0.2 s on landing. Gauge stays full. | One discard freed one pack socket. | Soft settle / none | Fades out and in, 0.15 s each |
| S3 sockets, S4 chip | Static. 0.15 s cross-fade on change. Carried sockets sit lower and darker. | Weight, then a reminder. | None / light tap on chip | Same |
| S5 leave row | Tiles fade in with the modal, 0.2 s. Focus on `Cancel`. `Confirm` ignores input for 0.25 s (D-32: accepted). | A plain list of stakes. | None / none | 0.15 s fade |
| S6 leave result | Outcome line 0.25 s, hold 0.3 s, then tiles resolve in pack order (carried first), 0.5 s each, 0.3 s apart. Kept: settle and slide to the Sanctum glyph. Lost: fade and lift. Then the shelves show. | Each piece has an answer. | Kept: soft settle, quiet. Lost: leaf-fall, at most 3 per card / light tap on a kept tile | 0.15 s fade per tile, same order, 0.1 s apart |
| S7 defeat | Card text 0.25 s. All tiles use the lost motion together, 0.5 s. No stagger. | Stated, not staged. | None. Never a sting. / none | 0.15 s fade |
| S8 preview | Groups fade in: kept, carried, lost. 0.25 s each, 0.15 s apart. Lost tiles arrive at 0.35 with no lift. Total 0.55 s. | A forecast. | None / none | 0.15 s fade, all groups together |
| No-room find (PARKED, ITEM-002) | Tile in 0.2 s, hold 0.2 s, fade to 0.35 and out 0.5 s. No lift. Once-per-path line (PROPOSAL, Jeff owns the words). | There was no place for it. | Leaf-fall, once per path / none | 0.15 s fade |

**Lost motion (shared).** Fill 0.35. Lift 8 units, only when the piece had a place. Outline and shape mark stay at 1.0. QUAD ease-out. No scale, no rotation, no red, no shake, no strike-through. The faded tile stays on the card as a record [R4 COMMUNITY]. The line states the fact plainly [R5 ARTICLE].

### 10.3 Pacing table

Hard cap for an item sequence: 2.4 s. The first tap finishes the motion. The second tap, or `Continue`, leaves (D-32). `Continue` ignores input for 0.25 s after the final state. Longer sequences shorten the stagger.

| Items at path end | Leave result (S6) | Defeat (S7) | Path end (S8), added before | Typical wait |
|---|---|---|---|---|
| 1 | 1.05 s | 0.75 s | 0.55 s | About 1.6 s |
| 4 | 1.95 s | 0.75 s | 0.55 s | About 2.5 s |
| 8 | 2.10 s | 0.75 s | 0.55 s | About 2.7 s |

Stagger: 0.3 s start to start for 1 to 4 tiles, 0.15 s for 5 to 8 tiles. With the 0.25 s guard, `Continue` is live at 2.20 s for 4 items.

### 10.4 Guard table

| Guard | Spec | Research |
|---|---|---|
| Select, then confirm | A tile tap never discards. `Let it go` sits at the strip bottom, far from `BackButton`. | [R6 COMMUNITY, Stardew] |
| Default focus | `Keep it` on S2. `Cancel` on S5. | [R6 ARTICLE, Primer] |
| Cancel inputs | Esc, Back, B and an outside tap all mean `Keep it`. Cancel never leads to a more destructive prompt. | [R6 COMMUNITY, Fire Emblem] |
| Open window 0.25 s | Modal `Let it go` and leave `Confirm` ignore input. `Let it go` shows at 70 percent until the window ends. Demo (e). | [R6 COMMUNITY, Stardew Switch drift] |
| Lock 0.6 s | After confirm, every discard control ignores input 0.6 s. Selection clears at once. | [R6 COMMUNITY] |
| `Continue` guard 0.25 s | After the final state of S6, S7 and S8. A double tap cannot pass the card. | [R4 ARTICLE, Slay the Spire 2] |
| No hold, swipe or drag | None. No hold-to-confirm. | [R6 ARTICLE, Vercel] |
| No skip of a confirmation | S2 and S5 have no timeout, no auto-close, no skip. | Proposal 3 section 3 |
| Undo | None (D-21). The large tile and the risk line slow a habit click. | [R6 ARTICLE, GNOME] |

### 10.5 Spiral and readability

The spiral: Sanctum full at departure, so carried pieces fill the pack, so free room is 0, so finds fade. Cause and symptom sit minutes apart. Each signal needs a shape or position read, never only text.

| Signal | Spatial UI (shape or position) | Compact UI | Reference UI |
|---|---|---|---|
| Sanctum full (cause) | `CapGauge` shape change at full, one pulse on first entry | `StoragePanel` count card | Reason line |
| Pack heavy at departure | Carried sockets lower and darker | `PackLoadChip`, gold outline at low room | Tooltip |
| Pack full on the path (symptom) | PARKED (ITEM-002): mini `PackSocketRow` on the encounter card, old pieces keep the carried glyph | Count on the card | One line, once per path |
| At risk | Corner brackets on the same tile row | Count | Names on focus |
| Lost, kept | Fade 0.35 and dashed outline, heavier border, shelf rule | Group order on S8 | Names on focus |

Never only text: Sanctum full, pack full, carried, kept or lost, blocked discard, twin identity, stack at limit, pack load level.

### 10.6 Sound and haptic hints

No audio layer exists. These are hints for a later story and cannot be tested now.

| Moment | Sound hint | Haptic hint |
|---|---|---|
| Tile select | Light tick | Light tap |
| Modal open | Low soft tone | None |
| Permanent discard | One leaf-fall tone and one low thump, once. No coin sound (D-02). | One low single thump |
| Kept tile settles | Soft settle, quiet | Light tap |
| Lost tile (S6) | Leaf-fall, at most 3 per card | None |
| Defeat | None. Never a sting. | None |

### 10.7 Play-test checklist (real build)

1. Open the panel and select five tiles. Does anything feel slow?
2. Discard a piece. Is the thump and leaf-fall weight right, or too much?
3. Tap `Let it go` twice at the same spot. Does anything discard?
4. Discard with a carried piece. Does the glide explain the freed socket?
5. Leave early with 4 items. Is 2 s right?
6. Tap during the resolve. Does the first tap finish and the second continue?
7. Lose a fight. Does the card feel stated, not staged?
8. Meet a find with a full pack. Do you link the fade to the old pieces?
9. Turn reduced motion on. Is every result clear?
10. At 1280x720, can you see the fade level and the shape mark?

### 10.8 Open feel questions (not answered by D-31 or D-32)

Answered already: first tap finishes, cap 2.4 s, pulse, glide, open window, mini pack row (drawn PARKED).

| # | Question | Recommendation |
|---|---|---|
| 1 | The proposal gave fill 0.6 at 0.50 s of the defeat motion. The QUAD curve gives 0.51. Keep QUAD ease-out, or use a linear fade for the middle? | Keep QUAD. Check in play. |
| 2 | The glide needs core to move a carried piece when room appears (v2 C-8). Core has not confirmed this. Without it, no glide. | Ask core before the S2 build. |
| 3 | Neighbours shift 0.25 s after the lost motion starts, while the tile is still at 0.35. The last tiles overlap the fading tile for about 0.1 s (storyboard F4). Start the shift after the fade instead? | Test both in play. The shift after the fade adds 0.1 s. |
| 4 | When a discard frees a place and a carried piece fills it, the gauge stays full and no pulse plays. Is that clear enough? | Yes. The glide shows the reason. |
| 5 | Nothing sets `StopMarkMotion.reduced` today. Who wires the reduced-motion flag for the item screens? | Owner of the settings screen, before the UI build. |
| 6 | The fade level 0.35 on the cream card may fail contrast. The artist checks it. | Artist, before the UI build. |
| 7 | The Sanctum glyph on S6 is a placeholder drawn for these boards. Final art is a catalogue story. | Keep a placeholder. |
