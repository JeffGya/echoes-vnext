# UI/UX review: stage stop marker mockup vs the real stage explore screen

Role: ui-ux-designer. Round 1, read-only. No existing file was edited.
All wording in brackets is a placeholder: [Jeff's wording].

Sources read: `ui/screens/venture/StageExploreScreen.tscn` and `.gd`, `StepProgressBar.gd`, `PartyTokenLayer.gd`, `GhostFootprintLayer.gd`, `ui/shells/RealmShell.tscn` and `.gd`, `assets/theme/LivingTreeSystem.tres`, `docs/art-direction.md`, design.md section 8 and 8a, decisions D-32, D-38, D-39, D-40, the mockup HTML, README and preview PNG.

Screenshots: the repo has NO screenshot of the stage explore screen. `find docs -name '*.png'` returns concept art only (character sheets, realms, sanctum tiles, moodboards). The mockup itself says "Not a screenshot". So every fact below comes from scene and script text. Jeff must compare against an in-game capture (see OPEN).

## 1. What the real screen contains today

### 1.1 Layers (back to front)
| Layer | Node | Content |
|---|---|---|
| World (CanvasLayer, follows viewport) | `WorldLayer/BoardRoot` | `Board` TileMapLayer (isometric, tile 128x64, clay floor texture `assets/sanctum/tiles/floor/sanctum_tile_floor_clay_base_128x96.png`), `BridgeLayer` (orange tint 0.87,0.58,0.24 at 55%), `GhostFootprintLayer`, `FogLayer` (black at 65%), `SituationLayer` (marker templates), `PartyTokenLayer` |
| World | `WorldLayer/BoardCamera` | Camera2D, zoom steps 0.5 to 2.5 |
| Control UI | `HudStrip`, `BottomHudRegion`, `DirectiveBadge`, `TravelSnippetLabel`, `BackButton`, `StageInfoPanel`, overlays | See 1.2 |
| Shell chrome (RealmShell, CanvasLayer) | `EchoBarFrame` / `EchoBar` | Capped 88 units high, 16 units from the edges |
| Modal host (AppRoot, layer 40) | `ModalHost` | Blocking modals |

The board has NO drawn background colour in the scene. The mockup's dark `#101713` ground is not verified against the real game (OPEN).

### 1.2 Control regions and sizes
Constants are in `StageExploreScreen.gd` lines 36 to 53. `_apply_responsive_layout()` (line 1588) places them.

| Region | Node | Size and place (all logical units) | 1280x720 | 1920x1080 |
|---|---|---|---|---|
| Top HUD | `HudStrip` (PanelContainer, theme `RealmExploreHudCard`) | 56 high. Width by profile: compact 520, standard 620, wide 720. Left/top at the 16 edge | x16, y16, 56 high | same left/top; wider profile |
| Directive badge | `DirectiveBadge` | 204 x 36. Top right, 16 from the edge, vertically centred on the HUD | top right | top right |
| Bottom HUD | `BottomHudRegion` | 100 high, left/right 16. Bottom edge = 16 + 88 (EchoBar) + 12 above the screen bottom | y504 to 604, x16 to 1264 | y864 to 964 |
| Step row | `StepBudgetRow` | 32 high, top of the bottom HUD, centred. Hidden unless the screen draws it | y504 to 536 | y864 to 896 |
| Action bar | `ActionBar` | 56 high, bottom of the bottom HUD, 12 gap | y548 to 604 | y908 to 964 |
| EchoBar | shell | 88 high, y616 to 704 at 1280x720 | y616 to 704 | y976 to 1064 |
| Board area | `_explore_spatial_rect()` (line 1665) | From y = 16 + 56 + 12 = 84 to the bottom HUD top minus 12; width = screen minus two 16 edges | x16, y84, 1248 x 408 | x16, y84, 1888 x 768 |
| Travel snippet | `TravelSnippetLabel` | Top-centre anchor, 480 wide, offset y140 to 200, font 15. Today it shows a short line after travel | y140 to 200 | same offset |

Buttons in the action bar: `AdvanceButton` min 160 x 56 (expands), theme variation `ButtonPrimary`; `ReturnButton` min 140 x 56, `ButtonGhost`; `StageCompleteButton` 180 x 56 and `BeginButton` 160 x 56 appear only in their modes. Gap 12. Other tap targets: `BackButton` 80 x 48 (preview mode only), `DismissButton` 140 x 56, `IgnoreButton` 120 x 48, choice buttons 200 x 56, `DisengageButton` 140 x 48.

Situation markers: 48 x 48 circles (`HiddenMarkerTemplate`, `RevealedMarkerTemplate`, `ResolvedMarkerTemplate`). The party token is a circle of radius 18 (36 across), see `PartyTokenLayer.gd` line 14. It is smaller than the 48 minimum before board scale (OPEN: confirm the on-screen size after `_preview_scale` and camera zoom).

### 1.3 Fonts (theme `LivingTreeSystem.tres`)
| Role | Font file | Size |
|---|---|---|
| Buttons | Spectral Bold (`assets/fonts/Spectral-Bold.ttf`) | 20 |
| HUD primary label (`RealmExploreHudPrimary`, turn) | Spectral Bold | 16 |
| HUD state label (`RealmExploreHudState`) | Spectral Regular | 15 |
| HUD meta label (`RealmExploreHudMeta`, objectives) | Iosevka Charon (mono) | 15 |
| Modal body (`RealmModalBody`) | Spectral Regular | theme default |
| Modal meta (`RealmModalMeta`) | Iosevka Charon | theme default |
| Step labels, badge text, snippet | theme default font, size override 14, 12, 15 | 14 / 12 / 15 |
| Titles (art direction) | Madimi One 22 to 32 | not used on this screen |

The mockup uses `system-ui`. The real game never does.

### 1.4 Colours and panel styles (hex from the files)
| Item | Value | Source |
|---|---|---|
| HUD card fill (parchment) | `#F3E7D3` at 96% | `StyleBoxFlat_realm_explore_hud`, bg (0.953, 0.906, 0.827) |
| HUD card border | `#A07D3E` at 72%, 2 wide | same |
| HUD card corners | radius 16 / 5 / 12 / 8 (top-left, top-right, bottom-right, bottom-left): an uneven "hand cut" shape | same |
| HUD card margins | 16 sides, 10 top and bottom | same |
| HUD text (dark brown) | `#3D2817` | `RealmExploreHud*` font_color |
| Button fill (gold) | `#D4AF37`, border `#745A27` at 72%, radius 10 | `PrimaryButtonBase.tres` |
| Button text | `#3D2817` (focus text `#D4AF37`) | `Button/colors` |
| Dark modal panel | `#1A271E` at 94%, border gold `#836D31` at 35% | theme sub-resource near line 142 |
| Directive badge fill | `#0A0A14` at 85%, radius 6 | `StyleBoxFlat_dir_badge` |
| Badge text / glyph | `#D0C0A0` size 12 / `#C8A96E` size 15 | `.tscn` |
| Step diamond filled / spent | `#C8A96E` / `#4D4D5C` at 70% | `StepProgressBar.gd` lines 28 to 30 |
| Step diamond size | 28 wide x 18 high, 8 gap | same, lines 25 to 27 |
| Step labels | `#C8A96E`, size 14 | `.tscn` |
| Snippet text | `#F5F1E7` size 15 | `.tscn` |
| Hidden / revealed / resolved marker | `#595973` 90% / `#408CD9` 90% / `#595959` 55% | `.tscn` sub-resources |
| Party token and ghost footprints | `#3373E6` (blue), black 65% outline | `PartyTokenLayer.gd`, `GhostFootprintLayer.gd` |
| Contact panel top border | `#C8A96E` | `.tscn` |
| Palette (art direction) | Akan Gold `#D4AF37`, Deep Forest `#3D5A47`, Terracotta `#C85A54`, Ivory `#F5F0E8`, Shadow Charcoal `#2A2A3A` | `docs/art-direction.md` |

Read of the real look: a calm iso clay board, a small parchment HUD card top left, one gold Advance button, a quiet gold-on-dark step row. Dark panels appear only for badge, contact and situation overlays.

## 2. Where the current mockup departs from the real screen

1. Page chrome: the mockup is a design sheet (swatches, tags, legends, tables, 10+ screens, collapsed options). The game shows one screen. The mockup reads as a spec, not a game.
2. Top HUD is a dark box. Real: parchment `#F3E7D3` card with brown text and a gold hand-cut border.
3. Fonts: `system-ui`. Real: Spectral, Iosevka Charon.
4. Colours: the mockup adds Cream, Mist Blue, Terracotta as stop-marker colours. Real screen uses gold, parchment, blue token. Terracotta is not used on this screen today.
5. The mockup draws the Directive badge as a bright blue-bordered box ("[glyph] [directive]"). Real badge: dark `#0A0A14` pill, gold glyph, 204 x 36.
6. "Last journey" box under the HUD, always on. Real screen has no such box. It adds a permanent second text block, against D-32 (on demand only).
7. Step bar: mockup draws large gold diamonds and a separate "[steps]" label and a repeat of "Advance". Real bar is 28 x 18 diamonds, label "Steps" and "3/5" fraction. The real fraction label still prints a number. Design 8 item 5 says the bar draws no second number (see section 3, row "fraction label").
8. Advance button: the mockup draws it narrow and centred. Real: full width of the action bar, 56 high, shares the row with Return Home.
9. Fog: the mockup uses a hatch pattern. Real: black 65% tile layer. (Colour-only fog is already real; hatch is a mockup extra.)
10. EchoBar: the mockup shows five round portraits with labels and rings. Real EchoBar holds `EchoCardItem` cards (min width 280, from `EchoCardItem.tscn`), capped at 88 high in a scroll container. The portrait pulse must live on those cards. The mockup does not show that card.
11. Touch-map overlay (dashed boxes, dotted thumb areas, hatched safe bands) is on by default. It is a review aid, not part of the game.
12. Extra sizes: phone 1600x720 and tablet 1440x1080 sheets. D-39 asks for 1280x720 and 1920x1080 only.
13. Situation shapes: mockup draws square, triangle, diamond, circle. Real markers are all 48 x 48 circles with a letter ("?" and a type label). The marker-shape language does not exist in the game today. The stop marker must not rely on "differs from a situation shape" until that is decided (OPEN).
14. Spotted-ahead dashed ray and far-cell ring, double rings, chevrons, pole with head: several drawing layers per marker. Real board art is flat and small.
15. The mockup tints and glyphs the Directive in blue. Real tint and glyph come from data keys (design 8 item 6), not chosen here.
16. Why card: five rows with icons in a dark panel, plus a second card variant. Real overlays use `PanelContainer` with a theme panel, one column of `Label` rows.

## 3. Keep, merge or cut: every mockup element

Design requires only four things: persistent stop marker, step bar with crossed-out lost steps, why card on demand (tap the marker), saved journey entry. Everything else is judged against these.

| # | Mockup element | Decision | Reason |
|---|---|---|---|
| 1 | Page header, "decided" tag, swatch row, legends, notes table, "considered" section | CUT | Not the game. Move to README if Jeff wants them. |
| 2 | Light/dark page, grey check, touch map, stop-kind buttons | CUT from the main sheet; KEEP stop-kind switch as ONE small control outside the screen frame | Jeff needs to compare kinds. The game has no such control. Grey check can be a static second image. |
| 3 | 1920x1080 screen | KEEP | D-39 size. |
| 4 | 1280x720 screen | KEEP | D-39 size, the base. |
| 5 | Phone 1600x720 and tablet 1440x1080 | CUT | Not in D-39. The real layout uses the same regions; one safe-edge note covers phone. |
| 6 | Top HUD card | KEEP, redraw as parchment card | Real element, no change. |
| 7 | Directive badge | KEEP, redraw as real pill | Real element. It is also the Directive cause source. No new design. |
| 8 | "Last journey" always-on box | CUT | D-32: why shows on demand only. The saved entry is read inside the why card. |
| 9 | Iso board with clay tiles, path, ghost footprints | KEEP | Real. Fewer cells drawn (see section 4). |
| 10 | Fog hatch pattern | MERGE into real fog: black 65% | Calmer. Hatch adds noise. |
| 11 | Situation shapes (square, triangle, diamond) | CUT; draw real 48 circles with "?" | Not in the game. Avoids a second shape language. |
| 12 | Stop marker ring on the stop cell | KEEP | Core: persistent marker. |
| 13 | Marker head on a pole with a glyph | KEEP as ONE head shape per kind (six shapes, D-38) | Core. Drop the pole detail if the head sits at the ring edge. |
| 14 | Double ring, chevrons, dashed ray, far-cell ring (met / spotted) | MERGE: head shape alone carries the kind; show ray only for spotted | Two cues per kind is enough: shape plus one line cue where the kind needs it. Fewer layers. |
| 15 | Marker colour set (cream, gold, blue, terracotta) | MERGE: one marker colour (gold `#D4AF37`, charcoal edge) | Shape carries meaning (colour never alone). Terracotta question is closed. |
| 16 | Touch-map overlay (tap boxes, thumb areas, safe bands) | CUT from the main sheet; keep as a toggle OFF by default | Review aid only. |
| 17 | Party token | KEEP, real blue circle | Real. Alias for the marker tap (D-40 item 10). |
| 18 | Portrait pulse on the named Echo | KEEP, on the real `EchoCardItem` | Core (D-38 item 1). Draw it on the card, not on a round portrait. |
| 19 | Emotion chip | KEEP only as it is today | Untouched. |
| 20 | Step bar: baseline diamonds | KEEP | D-40 item 8. |
| 21 | Step bar: X on lost diamonds | KEEP | D-40 item 8. A shape cue. |
| 22 | Step bar: three states (calm, shaken, mid-walk) | MERGE to two: calm and shaken | Mid-walk is motion; belongs to game-feel. |
| 23 | Step label "[steps]" and "3/5" fraction | CUT the fraction; KEEP "Steps" label | Design 8 item 5: no second number. Real `StepFractionLabel` still shows one. A code change for the build, listed in OPEN. |
| 24 | Advance button | KEEP, real width, with Return Home beside it | Real. Never narrow or hidden. |
| 25 | EchoBar | KEEP, real card size, capped at 88 | Real shell chrome. |
| 26 | Why card, cause = Echo name variant | KEEP | Core. One card layout. |
| 27 | Why card, cause = Directive variant | MERGE into the same card as a state | Same layout; only the cause row differs. Show it as a small side-by-side inset, not a second full screen. |
| 28 | Why card icons per row | MERGE: one small glyph per row at most, or none | Rows must read without icons. Fewer pictures. |
| 29 | Why card slots: purpose, route character, stop, cause, echo, reason | MERGE to at most four visible rows: what they did, how they went, why they stopped, who decided [Jeff's wording] | Design 8 allows up to six slots. Four rows is calmer. The Echo name and reason class join the "who decided" row. |
| 30 | Second card-open screen at 1280 | CUT | One open state is enough. |
| 31 | "Marker head and ring at 1280" panel | CUT | Engineering note; keep in README. |
| 32 | "Open for Jeff" yellow circles | CUT from screens; move to README | Notes on the picture add noise. |
| 33 | Options 2 and 3 | CUT | Not chosen. Kept in git history. |

## 4. Proposed minimal layout on the real screen

Principle: change as little as possible. Keep every real region. Add only the stop marker (board), the lost-step crosses (step row), the why card (on demand), and a pulse ring (EchoBar card). Add NO new permanent text. Remove the always-on last-journey box.

### 1280x720 (logical base)
| Region | Rect (x, y, w, h) | State |
|---|---|---|
| HudStrip (parchment card) | 16, 16, 620 x 56 | as today |
| DirectiveBadge | 1060, 26, 204 x 36 | as today |
| Board area | 16, 84, 1248 x 408 | iso board, path, fog, token, ONE stop marker |
| Stop marker | on the stop cell; head about 56 units across at this scale | persistent; tap area at least 48 x 48 |
| Why card | 360 wide, up to 4 rows (about 200 high), opens next to the marker, kept inside x16 to 1264 and y84 to 492 | on demand only; closes on a second tap or an outside tap |
| StepBudgetRow | 16, 504, 1248 x 32 | "Steps" label + diamonds, centred; lost diamonds crossed |
| ActionBar | 16, 548, 1248 x 56 | Advance (expand) + Return Home 140 x 56, gap 12 |
| EchoBar | 16, 616, 1248 x 88 | real cards; pulse ring on the named Echo's card |

### 1920x1080
Same regions. Capped readable UI with spare space on the sides, not a bigger copy.
| Region | Rect |
|---|---|
| HudStrip | 16, 16, 720 x 56 (wide profile) |
| DirectiveBadge | top right, 204 x 36 |
| Board area | 16, 84, 1888 x 768 (marker scale follows cell scale, not text scale) |
| Why card | same 360 wide, not larger |
| StepBudgetRow | 16, 864, 1888 x 32 |
| ActionBar | 16, 908, 1888 x 56 (consider a width cap so Advance does not stretch across 1888; profile decision for build, OPEN) |
| EchoBar | 16, 976, 1888 x 88 |

### Why card
Panel style: the dark modal panel `#1A271E` with the gold border, or the parchment HUD card. Pick the parchment card for consistency with the top HUD (OPEN). Rows: four labels, size 15, [Jeff's wording]. No icon is required. A Directive cause shows the real badge pill inline. The card does not cover the EchoBar or the Advance button (design 8 touch rule).

## 5. What the HTML mockup must imitate

### Files and nodes
| What | Path / node |
|---|---|
| Scene | `ui/screens/venture/StageExploreScreen.tscn` |
| Top card | `HudStrip` > `HudContent` > `TurnLabel`, `ObjectivesLabel`, `PartyStateLabel` (theme types `RealmExploreHudCard`, `RealmExploreHudPrimary`, `RealmExploreHudMeta`, `RealmExploreHudState`) |
| Badge | `DirectiveBadge` > `DirectiveBadgeRow` > `DirectiveTintBar` (4 wide), `DirectiveGlyphLabel`, `DirectiveTextLabel` |
| Bottom | `BottomHudRegion` > `StepBudgetRow` (`StepsLabel`, `StepProgressBar`, `StepFractionLabel`), `ActionBar` (`AdvanceButton`, `ReturnButton`) |
| Step bar drawing | `ui/screens/venture/StepProgressBar.gd` |
| Token | `ui/screens/venture/PartyTokenLayer.gd` (radius 18, `#3373E6`) |
| Ghosts | `ui/screens/venture/GhostFootprintLayer.gd` |
| Floor tile | `assets/sanctum/tiles/floor/sanctum_tile_floor_clay_base_128x96.png` (use the PNG itself in the HTML, do not redraw it) |
| Shell chrome | `ui/shells/RealmShell.tscn`: `EchoBarFrame` / `EchoBarScroll` / `EchoBar`; cards `ui/components/EchoCardItem.tscn` |
| Theme | `assets/theme/LivingTreeSystem.tres`; buttons `assets/theme/PrimaryButtonBase.tres` |
| Fonts | `assets/fonts/Spectral-Bold.ttf`, `Spectral-Regular.ttf`, `IosevkaCharon-Regular.ttf`, `MadimiOne-Regular.ttf` (load with `@font-face`) |

### Colours (hex)
| Use | Hex |
|---|---|
| HUD card fill / border / text | `#F3E7D3` (96%) / `#A07D3E` (72%) / `#3D2817` |
| Advance button fill / text | `#D4AF37` / `#3D2817` (radius 10) |
| Step diamond filled / spent / label | `#C8A96E` / `#4D4D5C` (70%) / `#C8A96E` |
| Badge fill / text / glyph | `#0A0A14` (85%) / `#D0C0A0` / `#C8A96E` |
| Dark panel | `#1A271E` (94%), border `#836D31` |
| Fog | `#000000` at 65% |
| Revealed / hidden / resolved situation | `#408CD9` / `#595973` / `#595959` (circles 48 across) |
| Token | `#3373E6`, outline black 65% |
| Snippet text | `#F5F1E7` |
| Stop marker (new, proposed) | gold `#D4AF37` with charcoal `#2A2A3A` edge, from the art-direction palette |

### Rules for the HTML
- One screen frame per size, at true logical pixels, no sheet chrome inside the frame.
- Use the real tile PNG and the real fonts.
- Use the real corner radii (16 / 5 / 12 / 8 on the HUD card).
- Draw the EchoBar with real card widths, not round portraits.
- No hover state anywhere (D-39).
- Mark every text slot [Jeff's wording]; do not invent copy.
- Keep review aids (touch map, safe edges) as a toggle that is OFF by default.

## Skills used
- `game-ui-ux-echoes`: not loaded in this read-only pass; the scene, script and theme files answered the questions directly.
- `accessibility-review`: not run (no new screen built). Checks noted above: 48 unit targets, 8 unit gaps, shape not colour, no hover.

## OPEN — questions and assumptions
ASSUMED: The stage explore screen looks like its scene and script say (parchment HUD card, gold Advance, step row, EchoBar cards). | WHY: no screenshot of it exists in the repo. | WRONG IF: the in-game screen differs (a theme override or runtime style that the scene text hides).
ASSUMED: The board has no fill behind the tiles that the scene shows, so `#101713` in the mockup is an invention. | WHY: no `ColorRect` or clear colour found in the scene or `project.godot` (no `clear_color` line). | WRONG IF: `RealmShell` or `AppRoot` draws a backdrop. I did not read `AppRoot`.
ASSUMED: The profile at 1280x720 is "standard" (HUD 620) and at 1920x1080 is "wide" (HUD 720). | WHY: the three widths exist; I did not read the code that picks the profile. | WRONG IF: the profile thresholds differ.
ASSUMED: The fraction label "3/5" must go to meet design 8 item 5 (no second number). | WHY: design says the bar draws no second number. | WRONG IF: Jeff accepts the fraction because it is not a "second" number.
BLOCKED: Is a screenshot of the real stage explore screen at 1280x720 and 1920x1080 (explore mode, mid-stage) available? | CHECKED: `find docs -name '*.png'`, `docs/stories/v2-directive-002/mockups/`. | NEED: Jeff captures two images; the HTML then matches pixel regions, not scene text.
BLOCKED: Why card style: parchment (HUD card look) or dark `#1A271E` modal look? | CHECKED: theme file shows both exist; design.md does not choose. | NEED: Jeff's choice.
BLOCKED: Does the party token tap area reach 48 units on screen? Radius 18 is 36 across before `_preview_scale` and camera zoom. | CHECKED: `PartyTokenLayer.gd` constants. Did not read the scale code. | NEED: mechanics or a probe of the real on-screen size at 1280x720 and zoom 1.
BLOCKED: Does the marker-shape language (square, triangle, diamond for situations) exist in any plan? Today all situation markers are 48 circles. | CHECKED: `.tscn` marker templates, design 3a. | NEED: sr-game-artist or Jeff to say whether situation shapes are in scope; if not, the stop marker avoids them by default.
BLOCKED: `ButtonGhost` (Return Home, Disengage) is not defined in `LivingTreeSystem.tres` by grep. Where does it come from? | CHECKED: grep of `ui` and `assets` for `ButtonGhost` base type (no hit). | NEED: whoever owns the theme to confirm the style; the mockup draws Return Home as a quiet outlined button until then.
BLOCKED: Does Advance stretch across the full action bar at 1920? | CHECKED: `size_flags_horizontal = 3` on Advance in the `.tscn`. | NEED: Jeff's view on a width cap at wide profile (profile recomposition rule).
