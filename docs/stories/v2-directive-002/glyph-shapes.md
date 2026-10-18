# V2-DIRECTIVE-002 B+C: stop glyph shapes
SVG draft notes below are history; the finished glyphs are 256 px PNG files (D-93).

Author: sr-game-artist. Sources: `design.md` 3a and 8.1, decisions D-36, D-41, D-42, `mockups/v3/index.html`, `ui/components/EchoCardItem.tscn`.
Player wording: [Jeff's wording]. These shapes carry no text.

Files: `assets/ui/stage_stop_glyphs/stop_<kind>.png` (6 files). Finished glyphs: see decision D-93; PNG 256 px with rim.

## 1. The six shapes

All shapes: 48 x 48 viewBox, flat, no gradient. One fill (Akan Gold `#D4AF37`). One outline (dark brown `#3D2817`, 3.5 units, round joins). Inner marks use the same brown, no outline.

| Kind (internal name) | Shape in words | Meaning (plain line) | Why the shape fits |
|---|---|---|---|
| `arrived_at` | Circle with a solid dot in the centre. | The party reached its target. | A circle with a centre mark is a "target hit". Round = whole, finished. |
| `capacity_spent` | Rounded square with three bars, long to short, top to bottom. | The party used all its steps. | The bars shrink like a step bar running down. The square is a full container. |
| `interrupted` (met something) | Hexagon with a small dot. | The party walked into a situation that was not its target. | The hexagon is the situation cell, the dot is the party inside it. Six sides read as "a place". |
| `spotted_ahead` | Arrow-head (pentagon pointing right) with one chevron. | The walk revealed an objective or a threat in front. | The arrow points forward: "look there". |
| `paused_to_read` | Wide capsule with two upright bars. | The party stopped to read a new find. | Two upright bars are the universal "pause" mark. The capsule is flat and calm. |
| `no_route` | Octagon with a thick diagonal slash. | No way forward. | The octagon is a stop sign. The slash means "blocked". |

Ground rule: shape carries the kind. The fill is the same on all six. No kind uses colour to differ.

Pair checks for confusable shapes:

| Pair | Risk | Difference that holds at 20 px |
|---|---|---|
| `capacity_spent` vs `paused_to_read` | Both have bars | Square (1:1) with horizontal bars versus a pill (about 2:1) with upright bars. |
| `interrupted` vs `no_route` | Six or eight sides | The slash on `no_route` is the largest inner mark. `interrupted` has a small dot. |
| `arrived_at` vs `interrupted` | Both have a centre dot | Round outline versus a pointed hexagon outline. The dot is larger on `arrived_at`. |
| `spotted_ahead` vs `paused_to_read` | Both are "find" kinds (D-36) | Pointed arrow versus a round pill. They share nothing. |

## 2. Contact sheet

Contact sheet (removed on the cleanup, D-92). Rows: parchment card `#F3E7D3`, dark card `#2C2E36`, then both in greyscale. Each glyph at 20, 28 and 48 px.

Reading result (my own eye check, not a user test):
- 28 px and 48 px: all six read at once.
- 20 px: all six differ by outline. The inner marks of `capacity_spent` and `paused_to_read` are small but still countable. Use 28 px as the default size and 20 px as the minimum.
- Dark card: the brown outline nearly vanishes on `#2C2E36`. The gold fill still gives a clear edge, so the shape holds.

Contrast (WCAG 1.4.11, 3:1 for graphics):

| Background | Gold fill | Brown outline | Result |
|---|---|---|---|
| Parchment `#F3E7D3` | 1.72 | 11.35 | Pass. The outline carries the edge. |
| Dark `#2C2E36` | 6.44 | 1.02 | Pass. The fill carries the edge. |
| Darker `#1A1A24` | 8.20 | 1.24 | Pass. The fill carries the edge. |
| Inner brown mark on gold | 6.59 | n/a | Pass. |

At least one of the two colours always clears 3:1. That is why one fill plus one outline works on both card types.

## 3. Colour-vision check

The fill is one colour for all six kinds, so a colour-vision difference changes nothing. The greyscale rows on the sheet show the six still differ by outline and inner mark. No kind depends on hue. Pass.

## 4. Party chip (D-42)

| Item | Rule |
|---|---|
| Existence | One chip. It exists only when no Echo is named. It never shows next to a glyph on a card. |
| Content | The same six glyphs. No second set. No text, no number. |
| Look | A rounded plate in the Echo-card style (same panel, same radius, same border as `EchoCardItem`). The glyph sits in the centre at 28 px. No new colour. The plate reads as "the party", not "an Echo". |
| Place | At the end of the Echo card row, same height as a card row. It must not cover a card and must not shrink a card below its minimum width (280). The row keeps its order and its 8 unit gap. |
| Tap area | 48 x 48 units minimum, 8 units gap to the nearest card (D-39). The plate is the tap area. A tap opens the why card. |
| When no Echo is named | The cause is the Directive, the party, terrain, an edge stop, or a shaken party with no deciding Echo. The chip shows the kind glyph. The why card gives the cause. The card row shows no glyph at all. |
| Fade | The glyph fades when the next Advance starts, as in 8.1. The chip fades with it. |

## 5. Card glyph (Echo named)

- Size: 28 px. Tap area: the whole card (it is far above 48 units). The glyph itself is a visual cue only.
- Place: top-right corner of the card, over the card margin, not over the portrait or the HP bar. The card has a 6 unit margin, so place the glyph inside a 28 x 28 slot that `ui-ux-designer` reserves in `BodyRow`, or anchored top-right with an 8 unit inset. `ui-ux-designer` decides and states it.
- Only one card carries a glyph at a time.

## 6. What ui-ux-designer needs

1. Import path: `res://assets/ui/stage_stop_glyphs/stop_<kind>.png`. The main chat runs `--import`. Set the SVG import scale so 48 units import at 48 px. A `Texture2D` is rasterised at import, so 28 px display from a 48 px texture is a downscale. Use linear filter with mipmaps on, or import at scale 2 and display at 28.
2. Map: `kind` string from the stop to the texture. Six `preload` constants or one dictionary in the UI script. The kind names are exactly the file suffix.
3. Node plan, card: one `TextureRect` named `StopGlyph` on `EchoCardItem`, `custom_minimum_size` 28 x 28, `expand_mode` ignore size, `stretch_mode` keep aspect centered, `mouse_filter` ignore (the card takes the tap), `visible` false by default.
4. Node plan, chip: one `PanelContainer` named `PartyStopChip` beside the Echo cards, containing a `MarginContainer` and a `TextureRect` of the same set. `custom_minimum_size` 48 x 48. It takes the tap (`mouse_filter` stop).
5. Tint: none. Leave `modulate` and `self_modulate` at white. The glyph keeps its colours. Fade uses `modulate:a` only.
6. Theme: the chip plate uses the existing card style from `LivingTreeSystem.tres`. Do not add a new style.
7. Accessibility: each tap target needs an accessible name. The name is [Jeff's wording]. No ID or number in it.
8. Reduced motion: the fade may become a hard cut. The glyph stays visible until the next Advance.
9. Check at 1280x720 and 1920x1080 (design 8.1 item 5), on the real card colour. If the real card is parchment, the outline carries. If it is dark, the fill carries. Both pass.

## 7. Do-not list

- Do not tint the glyph by kind, Directive or fear.
- Do not add text, numbers or IDs to the glyph or chip.
- Do not draw the glyph on the board (D-41).
- Do not add a seventh shape for terrain or Directive causes. They use the chip with the kind that ended the walk.
- Do not use these shapes for anything else (Adinkra marks, badges). Hexagon, octagon and arrow already carry other meanings on the board (`SituationMarkerDraw.gd`); keep the glyph set in the Echo bar only.

## OPEN — questions and assumptions
ASSUMED: The folder `assets/ui/stage_stop_glyphs/` is correct as the brief says | WHY: The brief names it. `assets/README_ASSETS.md` suggests `assets/_shared/icons/` or `_shared/ui/`, but `assets/` has no `_shared` or `ui` folder today | WRONG IF: Jeff wants the README layout. Then move the folder to `assets/_shared/icons/stage_stop_glyphs/`. Only the import path in section 6 changes.
ASSUMED: One gold fill for all six kinds | WHY: D-41 and 8.1 say colour never carries the kind. One fill passes contrast on both card colours | WRONG IF: Jeff wants a kind tint. The old mockup used a colour per kind.
ASSUMED: The glyph sits top-right of the card and the chip sits at the end of the card row | WHY: 8.1 leaves placement to `ui-ux-designer` | WRONG IF: the card layout has no free corner. I did not open `EchoCardItem.gd` to measure free space.
ASSUMED: The real Echo card background is parchment or a dark panel; I tested both | WHY: `EchoCardItem.tscn` uses the theme panel; I did not render the real card | WRONG IF: the card uses a mid-tone where both gold and brown fall below 3:1. Then add a light inner edge. Check on the real card.
ASSUMED: Inner marks drawn as solid brown shapes, not cutouts | WHY: Cutouts at 20 px lose their size under the outline stroke | WRONG IF: the import tool needs a single-colour mask. Then use cutouts at 28 px minimum.
BLOCKED: none
