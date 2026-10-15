# Art notes: make the stop-marker mockup look like the real game

Author: sr-game-artist. Round 1 (read-only critique). Nothing else was edited.
Placeholders for player text: [Jeff's wording].

Sources read: `ui/screens/venture/StageExploreScreen.tscn` and `.gd`, `PartyTokenLayer.gd`,
`StepProgressBar.gd`, `GhostFootprintLayer.gd`, `SituationMarkerDraw.gd`, `DirectiveBadge.gd`,
`assets/theme/LivingTreeSystem.tres`, `PanelBG.tres`, `PrimaryButtonBase.tres`,
`docs/art-direction.md`, `docs/Living_Grove_Design_System.md`, the old mockup preview png,
and the tile and block PNGs.

## 1. What makes the real screen look like itself

The real explore screen is NOT a dark-green board. Check these facts first.

| Part | Real value | Source |
|---|---|---|
| Board floor | Terracotta clay isometric tiles, red-brown, 128x96 art on a 128x64 cell. Four variants (plain, cracked). Warm dark-brown side wall under each tile. | `assets/sanctum/tiles/floor/sanctum_tile_floor_clay_base_128x96.png` (256x192 atlas, 2x2) |
| Fog | Same tiles, tinted black at 65% opacity. | `StageExploreScreen.tscn` FogLayer `self_modulate` |
| Bridge tiles | Same tiles, amber tint `Color(0.87,0.58,0.24,0.55)`. | BridgeLayer |
| HUD card (top) | Cream parchment `#F3E7D3` at 96%, 2 px gold-brown border `#A07D3E` at 72%, asymmetric corners 16/5/12/8, text dark brown `#3D2817`, 15-16 px. | theme `RealmExploreHudCard`, `RealmExploreHudMeta` |
| Primary button | Akan Gold `#D4AF37`, radius 10, thin dark-gold border `#745A27`, soft shadow (size 5, offset y 2), dark-brown label. | `PrimaryButtonBase.tres` |
| Full panel | Warm panel `#F5E6D3` at 90%, 4 px gold border `#D4AF37`, radius 24. | `PanelBG.tres` |
| Dark overlay cards | Near-black `#0D0D1A` to `#1A1A24` at 90-96%, radius 6-12, gold hairline `#C8A96E`. Used for contact panel, directive badge, NPC zone. | `.tscn` sub-resources |
| Step bar | Filled `#C8A96E`, spent slate `#4D4D5C` at 70%, black 55% outline. Label "Steps" 14 px `#C8A96E`. | `StepProgressBar.gd`, `.tscn` |
| Party token and ghost trail | Echo-faction blue `#3373E6` (token), same blue for ghost footprints. Black 38% shadow, black 65% outline, white label. | `PartyTokenLayer.gd`, `GhostFootprintLayer.gd` |
| Situation markers | Hidden: slate circle `#59596E`. Revealed: blue `#408CD9` with shape. Resolved: grey. Objective ring: Akan Gold. | `SituationMarkerDraw.gd` |
| Directive tints | e.g. Scout carefully = Mist Blue `#7AB5C8`. Neutral `#73738A`. | `DirectiveBadge.gd` |
| Fonts | Spectral (serif) for Label and body. MadimiOne, Jaro, TacOne, Ojuju are display faces. IosevkaCharon (mono) for numbers. Sizes: 14 chip, 16 body, 20 button, 24/32/48 headers. | theme, `assets/fonts/` |
| Icon style | None as image files. Marks are drawn in code: flat fill, one outline, no gradient, no glow. Glyph is one short letter or a tick. | `SituationMarkerDraw.gd` |
| Echo bar portraits | Production shows two initials in a circle (`PortraitLabel`), not painted portraits. | `EchoCardItem.gd` line 91 |

Light vs dark rule in the real game: the world (board) is warm and mid-tone. Parchment cards sit ON it.
Dark cards appear only for on-board overlays (contact, badge). The design system names deep forest
`#3D5A47` the screen base, but the explore board itself is clay.

## 2. Why the current mockup reads as a sketch

1. Wrong ground. It paints a green diamond grid with hatch. The real floor is red clay blocks with a wall.
2. Wrong chrome. Hatched dotted "tap area" boxes, outlined grey rectangles, and `[bracket]` labels dominate the frame.
3. Page furniture competes with the game. Swatch rows, toggle buttons, notes and tables sit around every screen.
4. Too many screens at once. Four device frames plus six marker cards plus two card variants plus pulse strips in one scroll.
5. Everything is the same weight. Path, ring, glyph, chevrons, ray, step bar, pulse, badge and why card all use gold line work at similar strength.
6. Generic type. System sans at tiny sizes, not Spectral and Iosevka.
7. Flat panels. No parchment card, no gold-brown 2 px border, no asymmetric corners, no soft shadow.
8. Dark HUD, wrong. The top HUD is a dark outlined box. The real one is a cream card.
9. Echo bar is empty grey circles with `[name]`. The real bar shows real Echo cards with initials and an emotion chip.
10. Markers are drawn in isolation on flat colour, so shape and scale are not judged on the real tile.
11. Annotation overlays (touch map, safe bands) are on by default or crowd the first read.

## 3. Real assets the HTML can use

Use relative paths from `docs/stories/v2-directive-002/mockups/` (that is `../../../../` to repo root), or base64 copies when the file must travel alone. Use the real files. Do not redraw them.

| Need | File | Note |
|---|---|---|
| Floor tile | `assets/sanctum/tiles/floor/sanctum_tile_floor_clay_base_128x96.png` | 256x192 atlas. Cut 4 tiles of 128x96 with CSS `background-position` (0,0), (-128px,0), (0,-96px), (-128px,-96px). Place on a 128x64 isometric cell, art offset up 16 px. Small file, base64 is fine. |
| Fog look | same tile + `filter: brightness(0)` at 65% opacity layer | matches FogLayer |
| Bridge look | same tile + amber overlay `rgba(222,148,61,.55)` | matches BridgeLayer |
| Fonts | `assets/fonts/Spectral-Regular.ttf`, `Spectral-Bold.ttf`, `IosevkaCharon-Regular.ttf`, `MadimiOne-Regular.ttf` | Use `@font-face` with relative `url()`. Skip the other weights. Base64 only Spectral Regular, Bold and Iosevka if the file must be standalone. |
| Portrait (best available) | `prototypes/sanctum_systems_exploration/assets/portraits/{kweku,yaw,ama,abena,adwoa,esi,kojo,mensah,sena}.png` | About 830 KB each. PROTOTYPE art, not in production. Use only if Jeff accepts it. Downscale to 128 px before base64. Otherwise use the real production look: initials in a circle. |
| Portrait style reference | `docs/concept_art/character_bases/echo_portrait_style_sheet_v01.png` | Reference only. Do not ship in the mockup. |
| Realm block icon | `assets/realms/vale_of_dust_set.png` | 64 px sand block. Can show a realm tag on the stage-info card. Not needed for the stop marker. |
| Colours and radii | values in section 1 | Copy as CSS custom properties. Name them after theme names. |

Not available as files (draw in HTML to match the code): party token (blue circle, 18 px radius, black outline, white label), situation shapes, step diamonds, ghost footprints, directive badge.
Not found: any real screenshot of the explore screen. No png of it exists in `docs/` or `assets/`. The only screenshots are the old mockup preview and concept art.
The north-star moodboard `docs/concept_art/north_star/echoes_north_star_moodboard_v03.png` is the best mood reference (1536x1024). Look at it, do not embed it.

## 4. Reduce density: one hero mark, restraint rules

1. One hero. The stop marker (ground ring plus pole head) is the only element at full strength. Everything else steps down.
2. Hierarchy of weight, strongest to weakest: stop marker, party token, path trail, step bar, situation markers, HUD. Never raise two at once.
3. Show ONE screen state per frame. Show the six stop kinds as a calm strip of six small cards below, each on a real clay tile. Do not repeat them inside every device frame.
4. One device frame in the main view (1280x720). Put 1920x1080, phone and tablet behind a tab or a "sizes" section, closed by default.
5. Path: one thin line in the existing ghost blue or Akan Gold `#C8A96E`. Pick one. No dashed ray unless the kind is "spotted ahead".
6. Chevrons: only on the two kinds that need motion cues (met something, spotted ahead). Max two chevrons.
7. Glyph on head: one glyph, one colour (cream on dark head). No second badge near it.
8. Pulse on portrait: show it in one frame as before/after only. Not in the main screen.
9. Touch map, safe bands, grey colour check: off by default, one toggle "Checks". Never all on.
10. Annotations: numbered dots (1 to 5) on the screen, text in a side column. No labels inside the screen.
11. Why card: shown in its own single frame, not on every device.
12. Step bar: keep the real bar (diamond row plus "n/m"). Show lost steps with the X only in the "shaken" frame.
13. Cream parchment HUD stays small: one card at top left, as in the real game.
14. Whitespace: at least 24 px between any two marks on the board.
15. Colour budget per frame: clay (ground), gold (path and steps), one accent for the hero. Blue only for the party token and ghosts.

## 5. Recommendations on the three open details (recommendations only, Jeff decides)

1. Ring on portrait until next move: YES, keep a faint ring. Reason: it is a shape cue, so it survives colour-vision difference. It also costs nothing on screen because it sits on an element that is already there. Make it fade when the next move starts. Show it in one before/after pair only.
2. Terracotta only for combat: YES in the mockup, as a safe default. Reason: the floor is already terracotta clay, so a terracotta mark on the board vanishes (low contrast). For "no way" and lost steps use a shape cue (X, closed bar) in cream or dark brown, not terracotta. Terracotta stays as the accent for combat, per theme `Accent Terracotta` `#C85A54`. Check contrast with the fog and clay at AA before the final.
3. Where the last-journey entry sits: recommend it NOT on the board and not under the HUD. Put it inside the stage-info card (top left, the cream card) as one quiet row, or inside the "why" card. Reason: keeps the board clear, and a family-record line reads well on parchment. Label: [Jeff's wording].

Contrast note: gold `#C8A96E` on clay `#B0583C` (approx.) is low. Give any path or ring a 2 px dark outline (`rgba(42,42,58,.65)`, charcoal) so it holds on clay. Verify with a real tile before sign-off.

## Do-not list for this mockup

- No green diamond board. No hatch fills.
- No new fonts. No pseudo-Adinkra forms.
- No glow or gradient on marks. The real marks are flat with one outline.
- No colour as the only carrier of a state.
- No IDs or raw numbers in player-facing display (step count `n/m` already exists in the real HUD, keep it).

## Extension rule

A new mark joins by: take a flat shape from the existing set, one outline, one fill from the theme, one glyph. If it needs a new colour, add the theme token first. Do not style it in the scene.

## OPEN — questions and assumptions
ASSUMED: The real explore screen keeps the terracotta clay floor and parchment HUD card at ship time | WHY: the `.tscn` and tile atlas are current in this worktree | WRONG IF: a later story restyles the board to deep forest
ASSUMED: Painted portraits are not in production; initials are the real look | WHY: `EchoCardItem.gd` shows two initials; only prototype PNGs exist | WRONG IF: Jeff has portrait art outside the repo, or wants the prototype portraits shown
ASSUMED: The gold-on-clay contrast is low (colour estimated from the image, not measured) | WHY: visual read of the tile | WRONG IF: a measured ratio is above 3:1 for meaningful UI
BLOCKED: Does Jeff accept the prototype portraits in the mockup? | CHECKED: `assets/`, `ui/`, `docs/concept_art`; only `prototypes/.../portraits` exist | NEED: Jeff yes/no
BLOCKED: Is there a real in-game screenshot of the explore screen? | CHECKED: all png under `docs/`, `assets/`, `ui/` | NEED: Jeff to supply one, or the main chat to capture one (needs a Godot run)
