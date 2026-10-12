# Stage stop marker mockup (V2-DIRECTIVE-002 B+C, design item 1)

Decided by Jeff: option 1 (path, six stop-marker shapes, portrait pulse). Text is on demand only.

## Files
- `stage-stop-marker-mockup.html`: the mockup. Open it in a browser. Buttons: light/dark page, colour check (grey), touch map, stop kind.
- `stage-stop-marker-mockup-preview.png`: Firefox screenshot of the whole page (light page, touch map on, spotted ahead).

## What changed in this revision
- Option 1 is the main sheet. Options 2 and 3 sit in a collapsed "considered, not chosen" section at the bottom.
- The 960x540 screens are removed. Sizes now: 1920x1080, 1280x720, phone landscape 1600x720 (notch, safe edges, home bar), tablet 1440x1080 (4:3).
- Touch map layer: 48-unit tap targets, thumb-reach areas (lower left, lower right), safe-edge bands. Nothing sits in the EchoBar or the safe edges.
- Step bar shows the baseline. Lost steps get an X (shape cue). Three states: calm, shaken, mid-walk.
- Why card: opens on a tap of the marker. The token does the same. No button. The cause slot shows a Directive (tint bar, glyph, name) or a named Echo. Two card variants shown.
- Pole slant: gone at 1280x720 and larger, because the ring scales with the cell and the head sits at 0.9 of the ring radius. This relies on the token and the head being ONE target (alias). Two separate targets 8 units apart need the head 56 units out, and then the ring overhangs the cell at 1280x720.

## Reused from earlier mockups
- `stop-short-pr1-shipped-tell.html`: page frame, swatches, figure cards, "Direction, not built" tag, ground ring with charcoal edge and cream line.
- `combat-feel-mockup.html`: theme button, button size, card rows.
- Concept art and the other visual-plans files were not opened.

## Colours (hex, source)
- Cream #FFF8DC, Charcoal #2A2A3A, Mist Blue #7AB5C8, Akan Gold #D4AF37: stop-short mockup swatches.
- Panel #1A271E, Gold border #A07D3E, Terracotta #C85A54: `assets/theme/LivingTreeSystem.tres`.
- Gold #C8A96E (path, steps): step label in `StageExploreScreen.tscn`. Deep Forest #3D5A47: `docs/art-direction.md`.

## Shape rules
- Situations: square combat, triangle shrine, diamond loot, circle other. Stop heads avoid these: round, rounded tab, hexagon, arrow pennant, dashed capsule, octagon.
- Met something: hexagon, chevrons close in. Spotted ahead: arrow pennant, chevrons point out, dashed ray.
- Colour is never the only carrier. No Adinkra symbol is used. All labels in brackets are placeholders.

## Still open for Jeff
1. Does a faint ring stay on the portrait until the next move?
2. Is terracotta reserved for combat only? (It marks "no way" and lost steps here.)
3. Where does the last-journey entry sit? (Shown under the top HUD, left.)
