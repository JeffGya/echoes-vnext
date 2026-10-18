# Stop marker mockup, v3 (round 4)

One animated page. Three modes play the same Advance run on the same real stage map, so you can compare the feel.

## Open it

Open `index.html` in a browser. No server is needed. `assets/` holds the tile, the fonts and `maps.js` (the four real stage maps).
The page plays one Advance on load. One small strip above the frame holds all controls. The frame is 1280x720 at true size.

| Control | Use |
|---|---|
| Mode | Current game, Old mockup, New mockup. |
| Map | The four real stage maps (1 and 2: Vale of Dust. 3 and 4: The Ashen Hollow). |
| Run | Calm with a named Echo, Directive cause, Shaken, Edge stop. |
| Marker style | 1 to 4. Switches the quiet mark of the New mockup live. Works only in the New mockup with improvement 3 on. |
| Stop kind | Shows any of the six stop kinds. Review tool, not in the game. Off in Current game. |
| Replay / Pause / 0.25x | Replay the run, hold it, or play it at quarter speed. Pause also holds the open card. |
| Size | 1280x720, or 1920x1080 (the wide profile: 1536x864 logical at 1.25). |
| Advance (in the frame) | Plays the run again when the screen is calm. |
| Tap the mark or the party token | Opens the why card after the mark settles (0.85 s). Tap outside or press Escape to close. Old and New mockups only. In style 3 the glyph in the Echo bar also opens it. |

`prefers-reduced-motion`: the camera and the token jump, the marker and the card only fade, and the pulse is skipped.

## What each mode shows

| Mode | Content |
|---|---|
| Current game | The stage screen as it is today. Parchment HUD, navy badge, one snippet line, `Steps` with three diamonds and the count, wide gold bar, one Echo pill. No stop marker. No cause. No crossed-out steps. The Advance label is readable here. The live button has a blank label (a known defect). |
| Old mockup | The UI and the marker of the first stop marker mockup (removed on the cleanup, D-92), option 1, unchanged: dark HUD, always-on journey box, blue-outlined badge, big diamonds with red crosses, narrow Advance, dark Echo band with round portraits, six coloured stop-kind markers (ring, pole, head, ray for "spotted ahead"), dark five-slot why card. Fonts are Spectral and Iosevka instead of the sketch font. |
| New mockup | The old mockup plus the 8 improvements below that Jeff kept, plus the shaken beat. It uses the Old mockup's Advance button, step diamonds and Echo band. A checkbox switches each improvement. All off gives exactly the Old mockup. |

## The board (the same in all modes)

- Real map data: `walkable`, `bridge_cells`, `revealed_turn0`, `revealed_after_advance`, the start cell, the real first Advance path (3 tiles), and the content markers the snapshot shows after Advance.
- Projection of the real stage maps: centre x = 64 * (col + row) + 64, y = 32 * (row - col) + 32. One layer of tiles, a second tinted layer for bridges (0.87, 0.58, 0.24, 0.55), fog as black tiles at 65 percent on walkable unrevealed cells. Colours match the real screenshot (checked by pixel average).
- Camera zoom 1.3 (tile 166 px wide, as in `real-screen-1280x720.png`). The camera follows the token with the game's lerp (speed 5 per second, `BoardCamera.gd`), so the token moves tile to tile on screen and the map settles after the walk.
- Fog lifts around the party at each tile (0.35 s). Cells reveal when they are within 3 tiles of the party.
- Ground `#120E0C`. Blue token with "P". Blue ghost footprints. Green bubble. Blue diamond for a content marker, blue circle with gold ring for an objective.
- Maps 2 and 3 show no content marker after the first Advance (the snapshot shows none). Map 1 shows two. Map 4 shows a structure under the token.

## Timeline

| Time | Beat | Source |
|---|---|---|
| 0.00 to 0.50 s | Walk, equal segments, linear. A footprint drops and a step spends per tile. Fog lifts. The bubble starts. | Shipped (`StageExploreScreen.gd`). Linear easing is assumed. |
| 0.00 s | Snippet starts: fade in 0.4, hold 2.1, fade out 0.5. | Shipped. |
| 0.50 s | Old mockup: marker and pulse appear at once. | Old mockup (no motion was defined). |
| 0.60 to 0.85 s | New mockup: the mark settles (0.95, 1.1, 1.0). Lost steps cross out within 0.2 s. | PROPOSAL (approved as starting values in D-57; values in `data.stages.presentation`) |
| 0.60 to 0.82 s | New mockup, Shaken run: token and step bar shake once. | PROPOSAL (this round) |
| 0.90 s | New mockup: pulse on the named Echo (0.5 s), then a faint ring stays (not in style 3). Snippet starts. | PROPOSAL (approved as starting values in D-57; values in `data.stages.presentation`) |
| 1.40 s | Calm. Advance works again. | PROPOSAL (approved as starting values in D-57; values in `data.stages.presentation`) |

## Round 4: the quiet mark (4 styles)

Jeff did not like the stick with the icon, and the ring was not needed. All four styles remove both. Each style has no text and no looping motion. Each shows the stop kind by shape. The six shapes are the same six in every style (Arrived: round. Spent: rounded block with three bars. Met something: hexagon. Spotted ahead: arrow-head. Paused to read: capsule with two bars. No way: octagon with a slash).

| Style | What it is | What the player reads |
|---|---|---|
| 1 Rim badge | A small kind shape sits on the rim of the party token. Gold edge. | The party stopped, and the shape says how. |
| 2 Floor stamp | A scuffed kind shape is pressed into the tile beside the party. Flat on the ground, pale line on a dark scuff. | The party stopped here, and the shape says how. |
| 3 Echo bar glyph | The board shows nothing extra. A small kind shape sits on the named Echo card. When no Echo is named it sits on a blue party chip left of the cards. The ring on the portrait is not drawn in this style. | Who held the party, and how it stopped. |
| 4 Last footprint | The last footprint of the trail takes the kind shape (blue, like the trail). | The path ended in this way. |

My preference (one line): style 1. It sits on the thing the player already looks at, needs no new place to learn, and works when no Echo is named.

Facts and weak points per style:

| Style | Tap area | Gap to other marks | Weak point |
|---|---|---|---|
| 1 | Token and badge as one area, at least 48 x 48 units (the page clamps it). | 65 px or more on the four maps (measured by the page). | The badge is small (about 44 px). It hides a little of the token rim. |
| 2 | Token and stamp as one area, at least 48 x 48 units. | 34 px or more (map 1). | Clay and the pale line have lower contrast than the other styles. It sits on the tile edge, so it may cross onto the next tile. Needs a contrast check in the engine. |
| 3 | Two areas: the token (50 x 50) and the glyph (48 x 48). | Not on the board. | With no named Echo it needs the extra party chip, a new element. A player who looks only at the board sees nothing. |
| 4 | Two areas: the token (50 x 50) and the footprint (52 x 52). | 51 px or more. | The mark is about 90 px from the token. A player may not link it to the token. |

How the mark stays and how the player gets it back (all styles):

- The mark is drawn from the result of the last Advance (`stop` and the journey entry). It is not a timer. It stays until the next Advance starts. Then it fades and the new walk starts.
- Tap the party token at any time. It opens the why card. This is the alias in D-40 item 10 and works in every style.
- Tap the mark to open the same card (styles 1, 2, 4). In style 3 tap the glyph in the Echo bar.
- Tap an Echo card does NOT open the why in styles 1, 2 and 4. In the real game an Echo card probably opens that Echo. See OPEN in the report.
- The page cannot prove the "stays until the next Advance" part across a save and load. The journey entry is saved (design 8a). Whether `stop` is saved is open.

## The improvements (New mockup), with the reason for each

Jeff removed improvement 5 (step bar) and improvement 10 (wide Advance bar, Return Home, one Echo pill). It was his choice: he prefers the Old mockup's Advance button, its big step diamonds with red crosses for lost steps (option 1), and its dark Echo band with round portraits. The New mockup now uses those three parts as they are. The numbers 5 and 10 are not reused.

| # | Change | Reason |
|---|---|---|
| 1 | Top bar is the parchment card of the live game. | The dark box is not in the game. Parchment cards sit on the clay board. |
| 2 | No always-on journey box. The entry is in the why card. | D-32: the why shows on demand only. A standing text block adds noise (review notes, removed in D-92). |
| 3 | A quiet mark replaces the old marker. No pole, no ring, one gold edge, clear of other marks. Four styles. | Jeff, round 4. Shape carries the kind, not colour. |
| 4 | The mark settles once in 0.25 s. | Gives "it happened" without a loop (review notes, removed in D-92). |
| 5 | Removed by Jeff. | Old step diamonds stay. |
| 6 | Lost steps scratch in with the mark. In the New mockup the old red-cross diamonds fade in at 0.6 s. | The shaken beat and the step icons say the same fact. One beat, not two (review notes, removed in D-92). |
| 7 | Directive badge is a plain dark pill. | The blue-outlined box is a second accent. The badge stays as shipped (review notes, removed in D-92). |
| 8 | Why card: parchment, four rows, one column. | Same look as the HUD. Fewer rows and icons (review notes, removed in D-92). |
| 9 | Snippet and pulse start at 0.9 s. | Marker first, then text. One new thing at a time (review notes, removed in D-92). |
| 10 | Removed by Jeff. | Old Advance button and old Echo band stay. |
| 11 | Shaken beat: a short small shake. PROPOSAL. | New in round 4. See below. |

## Shaken beat (D-38 item 2) - PROPOSAL, for game-feel-developer and Jeff

| Item | Value |
|---|---|
| What moves | The party token (with its shadow) and the whole step bar row. |
| When | 0.60 to 0.82 s, while the lost steps cross out (the same 0.2 s). Only in the Shaken run. |
| Shape | Left and right shifts of 3, 3, 2, 2 px, then 0. About 2 oscillations. Linear. |
| Length | 0.22 s. Plays once. No loop. Then still. |
| Reduced motion | Not played. The cross-out still appears. |
| Scope | New mockup only. The Old mockup defines no shaken beat (its shaken view is a still picture), so it plays none. The checkbox 11 switches it. |

All values are starting values for a feel test, not decisions.

Not shown because it is not visible: each tap area (at least 48 units) is clamped to the safe area. The Edge run prints its size under the frame.

## Text

All new strings are `[Jeff's wording]`. The Directive cause shows as `Directive` (D-40 item 7). HUD text, badge text, snippet line, Echo status words and the button labels `Advance` are copied from the live screen. `Return Home` is no longer shown in the New mockup.

## Frozen views

The preview images were removed on the cleanup (D-92). Make them again with the URL hash below.
Frozen views use a URL hash, for example `#shot=1&m=new&map=2&s=edge&t=250&why=1&z=1080&ms=3`. Switch off improvements with `&off=hud,journey`.

## What was tested

Test mode (`#test=1`) runs 42 checks inside the page, in real Firefox (headless). Result on the last run: 42 of 42 pass.
The first 16 are the old checks: autoplay; Pause; Play; 0.25x and 1x; mode switch (one selector changed: the New mockup now has a `data-mark` element and no old marker svg); a checkbox toggles the journey box; map 4 builds; the hit area is on after settle; tap opens and tap outside closes the card; the Edge run builds; the 1920 size scales; no page error.
New checks: each marker style builds one mark with no line and no ellipse (no stick, no ring); each style draws six different shapes for six kinds; the gap to other board marks is 24 px or more (styles 1, 2, 4 on all four maps); every tap area is 48 x 48 or larger; a tap on the mark area and a tap on the token each open the card; no animation in the New mockup loops; the shaken run has the shake on the token and the step bar, once, 0.22 s, starting at 0.6 s; the shake moves 1 to 3 px at 0.644 s and is still at 1.0 s and at 5 s; the calm run has no shake; the New mockup has the old Advance, the old 20 px step diamonds and the old Echo band, and no Return Home and no pill; Marker style is off in the Old mockup.

Not tested:

- Animation over real time. Headless Firefox takes the screenshot at load. The checks set `currentTime` by script. I did not watch the shake play at speed.
- The feel of the shake (is 3 px too small or too big on a phone). Only a person can say.
- A real finger tap. The checks call `click()`.
- `prefers-reduced-motion` on. The code skips the shake in that case, but I did not run it.
- Chrome and Safari. Only Firefox.
- The gap check is a circle approximation. A content marker under the party token (map 4) is left out of the gap check, because the token hides it.
- Contrast of the marks on clay. I judged it by eye on the PNGs. No ratio was measured.

## Assumptions

- Tile art sits with the diamond centred on the cell centre. The map notes (removed, D-92) said the art reaches 64 up from the centre. The real screenshot shows the token on the diamond centre, so I followed the screenshot.
- Old and New mockups use 5 baseline steps (3 spent by the walk). Shaken shows 2 lost. The Current game uses 3, as the live screen does.
- In the Current game the step bar stays at 0/3 after the walk. I did not check what the live bar does after the walk.
- Linear walk easing and a bubble of about 2.6 s are assumed.
- The Old mockup keeps its head on the right of the ring and has no motion defined. I gave it the same walk, fog and snippet as the game, with the marker appearing at 0.5 s.
- The Edge run moves the camera so the party sits low and right (as when the camera is held at a map edge). The map itself is not edited.

- The six shapes and glyphs are the ones of the Old mockup (silhouette plus inner glyph), made smaller. No new symbol is invented.
- Style 3 with no named Echo uses a blue party chip. That is my invention to give the style a home.
- Styles 2 and 4 are drawn at the party cell and the arrival cell of the real first Advance path.

## Needs Jeff

1. Pick a marker style (or none) after you try all four on several maps and stop kinds.
2. Try the shaken run in the New mockup at 1x. Say if the shake is too small, too big or not needed.
3. Pick the improvements to keep. Switch each one off and on.
