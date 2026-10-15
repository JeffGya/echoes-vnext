# Party card mockup, v4 (decision D-61)

Static sheets for approval. No code is changed. The party card is the first card of the Echo bar.
The stop glyph sits on the named Echo's card, or on the party card when no Echo is named.

## Files

| File | Shows |
|---|---|
| `overview-1280x720.png`, `overview-1920x1080.png` | Three variants side by side. Parties of 1, 3 and 5 Echoes. Four states each. Scaled down (0.5 and 0.4). |
| `detail-<size>-p1/p3/p5.png` | Same content at true size. Variants stacked. Magenta dashed box = tap target. |
| `anatomy.png` | Card sizes, tap targets, glyph corner options, the 5-Echo scroll, the width table. |
| `*.html`, `assets/` | Sources. Fonts come from `../v3/assets/`. Glyphs are copies of `assets/ui/stage_stop_glyphs/`. |

States: (1) no stop yet. (2) stop, no Echo named: glyph on the party card. (3) stop, Echo named: glyph on that Echo's card; the party card has no glyph. (4) why card open from the party card: centred above the card, above the step row, clamped inside the 16 px safe margin.

## Variants

| Variant | Party card width | Portrait | Label |
|---|---|---|---|
| V1 same size | 280 | blue circle with P | `[Jeff's wording]` |
| V2 compact | 120 | blue circle with P, centred | none |
| V3 compact with label | 168 | blue circle with P | `[Jeff's word]` (one word) |

- Card height stays 58 in every variant. The look is the live Echo card (cream `#E0D5C3`, gold `#D4AF37` border, dark portrait square 40x40).
- Name and status lines on Echo cards are grey bars, not text. The sheet shows no player text except the `[Jeff's wording]` marks.
- V3 label room is about 100 px. At 14 px Iosevka that is about 13 characters. The real word must fit.

## Width table (card 280, gap 16, bar = canvas width minus 32)

| Profile | Bar | Variant | Party card | Room for Echo cards | Echo cards visible without scroll |
|---|---|---|---|---|---|
| 1280x720 | 1248 | V1 | 280 | 952 | 3 |
| 1280x720 | 1248 | V2 | 120 | 1112 | 3 |
| 1280x720 | 1248 | V3 | 168 | 1064 | 3 |
| 1920x1080 (1536 logical) | 1504 | V1 | 280 | 1208 | 4 |
| 1920x1080 | 1504 | V2 | 120 | 1368 | 4 |
| 1920x1080 | 1504 | V3 | 168 | 1320 | 4 |

Result: all three variants show the same number of full Echo cards. The width choice does not change when the bar starts to scroll. Parties of 1 and 3 Echoes never scroll. A party of 4 scrolls at 1280 and fits at 1920. A party of 5 scrolls in both.

## Scroll with 5 Echoes (6 cards)

- The party card is pinned first at the left. It does not scroll.
- The scroll area holds the Echo cards only. The scrollbar covers only that width.
- The scrollbar sits below the cards, outside the 58 px card height.
- The last visible card is cut at the right edge. The cut shows that more cards exist.

## Tap targets

- The whole card is the target. V1 280x58, V2 120x58, V3 168x58. All are at least 48 in both directions.
- The 24 px glyph is a mark, not the target. This differs from the live build, where the glyph is the target.

## Preference

V1: one card shape, one tap size, a readable label, and no cost in visible cards.

## OPEN: Jeff decides

1. Width: V1 (280), V2 (120) or V3 (168).
2. Portrait: blue token with P (as on the board) or another icon. No party icon art exists. P is drawn from the board token only.
3. Label text: Jeff's wording (V1 and V3 only).
4. Tap with no stop mark: nothing, or open the last journey entry if one exists.
5. Glyph corner: top-left of the portrait (today, shown on all sheets), top-right or bottom-right (see `anatomy.png`). One corner for every card.
6. Gap between the party card and the first Echo card: this sheet uses 16 (the card gap). Today the chip gap is 58.
