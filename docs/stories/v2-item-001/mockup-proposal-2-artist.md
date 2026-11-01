# V2-ITEM-001a mockup proposal 2 of 3: artist (look, marks, colour, art scope)

Author: sr-game-artist. Written in STE. Proposal only; no mockup or code exists. Builds on proposal 1. Binding: D-01 to D-30. Motion belongs to the game-feel proposal. Player text is `[Jeff's wording]`.
Citations: `[R7 LABEL]` is `research-ui-best-practices.md` section 7 with its evidence label. Most evidence is weak, so each use is a hypothesis.
Contrast numbers are my own WCAG calculation, not copied from the design-system file.

## 0. Findings first

| # | Finding | Effect |
|---|---|---|
| 1 | The design-system file states gold on a warm panel as 4.8:1. Measured: 1.72:1 on `#F5E6D3`, 1.45:1 on `#E0D5C3`. Gold on `#120E0C` is 9.13:1. | A gold outline alone is invisible on a light bed. Every gold mark gets an ink keyline. |
| 2 | The file states warm tan `#8B7355` on the panel as 5.2:1. Measured: 3.66:1. | `#8B7355` never carries item text. |
| 3 | Rarity `Rare` is `#7AB5C8` (`art-direction.md`), the same as Fearful and Info. `Uncommon` `#4CAF72` equals Success. | Grade never uses rarity colour (section 3). |
| 4 | `ThreadSlotItem` is a circle sigil disc. `RealmRecoveryCord` legend uses `●`, `≋`, `✕`. | Item marks use no circle disc, no `●`, no `✕`. |
| 5 | Game-feel section 6 wants a dashed placeholder outline. | Dashed is reserved for the lost state. The placeholder uses hatch. |

## 1. The tile

**Construction (one `ItemTile`, all 8 surfaces).**

| Part | 1280x720 | 1920x1080 | Rule |
|---|---|---|---|
| Bed | 72 | 80 | Rounded square, radius 12. Fill `#DCCEB5`. 1 px inset edge `#785C2B` at 45%. |
| Plate | 64 | 72 | Radius 10, uniform. 2 px border `#785C2B`. Fill `#F5E6D3`. |
| Art slot | 40 | 45 | 62.5% of the plate, centred. Silhouette stays inside the slot with its four corner triangles (8 units) empty. |
| Mark ring | 10 | 11 | Free band around the art. Marks live here. |

The tile brings its own bed, so it reads the same on dark and cream surfaces. The plate edge (4.0:1 on bed), not the fill, carries the shape.

**Two-second read.** (1) Silhouette = kind. (2) Corner marks = which piece, its fate. (3) Bottom row = pips or count. Three marks at most [R7 DEVELOPER].

**Unique piece vs stack.**

| | Unique piece (gear, relic) | Stack (consumable, material) |
|---|---|---|
| Edge | One plate | Two plates: a second plate edge shows 4 units below and 4 right, behind the first |
| Bottom row | Grade pips, left | Count capsule `x7`, right |
| Corner | Twin notch | None |
| Grayscale | One edge, no capsule | Doubled edge, capsule |

**Five states (shape, weight, tone; no motion).**

| State | Shape | Weight | Tone |
|---|---|---|---|
| In the Sanctum | Plain tile, no extra mark | Bed `#DCCEB5` | Full |
| Carried in the pack | Open-leaf glyph, top-left | Bed `#D9C5A0` (darker), socket edge 2 units lower | Full |
| At risk (leave panel S5) | Four corner brackets, 3 units outside the plate, 2 px ink `#3D2817`. Leaf glyph stays. | Plate unchanged | Full |
| Kept (S6, S8) | Brackets and leaf removed. Border grows from 2 to 3 px. | Heavier | Full |
| Lost (S6, S7, S8) | Dashed 2 px outline stays as a ghost. Art and fill fade. | Lightest | Fill and art 35%, kind shape, pips and notch 60%, outline 80% (game-feel owns timing; this is the end state) |

Brackets are the only mark outside the plate. No notch shape is a bracket.

## 2. Kind shapes and marks

**Placeholder shapes** (flat `#785C2B`, inside the art slot, plain, no detail):

| Kind | Shape | Why distinct in grayscale |
|---|---|---|
| gear | Portrait rounded rectangle, 40% wide | Straight sides |
| relic | Hexagon | Six facets |
| consumable | Triangle, base down | One apex |
| material | Two short parallel bars | Two parts |

No circle (finding 4) and no diamond (diamonds are pips).

**Final art direction by category** (bible 3.3, 3.4, 3.5, 3.6, 4.5, 4.6). Art is one made, mended object on a transparent ground: matte gouache blocks, dark-brown contour (`art-direction.md`).

| Category | Direction | Avoid |
|---|---|---|
| Weapon (gear) | Documented combat forms only. Show iron, wood, cane, skin, fibre, and the wear on the grip. | Royal `afena`, state swords, openwork gold blades (bible 4.5, 4.6) |
| Charm | One cord knot, one plain bead, or one small unmarked brass or wood token (bible charm language) | Any engraved symbol |
| Armor or clothes (gear) | Quilted cotton, layered strip-woven cloth, leather, basketry, restrained brass at seams. Cloth stays visible. | A generic fantasy breastplate; a printed fugu |
| Relic | Bell, vessel, bead strand, flywhisk-like object as an object, not a weapon (bible 3.6). Fictional in-world form. | Close copies of chiefly regalia |
| Consumable | Leaf wrap, cloth bundle, gourd or clay vessel, woven pouch | Glass potion bottles |
| Material | Raw stock: undyed handspun cotton hank, indigo-dipped strip, camwood cake, wood billet, cane, brass offcut | Gems, crystals, coins (D-06: never a price) |

Art colour follows real pigment: undyed cotton, indigo-black, pale one-dip indigo, camwood, forest-green dye, gold only as small leaf (bible 3.5). Label each item documented, adapted or invented (bible 14). Twi names wait for cultural validation.

**Grade pips.** Small diamonds, ink `#3D2817`, in a row at the bottom-left of the mark ring: 6 units at 64, 7 at 72, gap 3. Filled = grade steps; no hollow pips (the ladder is open, ITEM-005). Maximum 5 drawn. Shape and count carry grade. Realm HUD stage diamonds are 16 units, gold, elsewhere; low risk, checked in the mockup.

**Twin notch.** An ink-filled carved mark in the top-right of the ring, 12 units at 64, 14 at 72, 5 clear of the plate edge, from `mark_index` (`int()`; -1 = none).

| `mark_index` | Shape |
|---|---|
| 0 | Solid square |
| 1 | Corner triangle |
| 2 | Half disc |
| 3 | Two bars |
| 4 | Plus |
| 5 | Two-step stair |

Versus the others: notch = solid, top-right; pips = repeated diamonds, bottom-left; source mark = leaf outline, top-left. Position and form differ. Limit: 1 in 6 twin pairs share a shape.

**Source mark (top-left, 14 units at 64).** Held (carried from an earlier path): open leaf, outline with a gap in the stem side. Gathered (found this path): whole leaf, solid. On the Sanctum grid there is no mark. A plain leaf with a midrib only; no Adinkra form, and no Sankofa bird or heart (bible 3.4).

**Equipped slot (ITEM-003).** A blank 14-unit zone at the bottom-centre of the ring. No outline, no label. It is a layout hold; nothing draws there in 001a.

## 3. Colour use

New tokens: none. `#DCCEB5`, `#D9C5A0` and `#785C2B` already appear in `LivingTreeSystem.tres`.

| Use | Token | Value | Contrast |
|---|---|---|---|
| Plate fill | Warm panel | `#F5E6D3` | ink 11.3:1 |
| Bed (Sanctum) | Chip tan | `#DCCEB5` | ink 8.9:1 |
| Bed (carried) | Parchment | `#D9C5A0` | ink 8.2:1 |
| Plate border, kind shape | Bronze ink | `#785C2B` | 5.1:1 on plate; 4.0:1 on bed |
| Pips, notch, brackets, tile text | Dark brown | `#3D2817` | 11.3:1 on plate |
| Count capsule (normal) | Plate fill, ink text, ink outline | | 11.3:1 |
| Count capsule (at limit) | Gold `#D4AF37` fill, ink 1.5 px keyline, ink text, underline | | text 6.6:1 |
| Cap gauge full, chip `warn.pack` outline | Gold `#D4AF37` + ink keyline | | gold on dark 9.1:1; keyline carries it on light |
| Text on dark surfaces | Cream `#F5E6D3` | | 15.7:1 on `#120E0C` |
| Secondary text | `#785C2B` on panel only | | 5.1:1 on `#F5E6D3` |

**Forbidden for item marks.**

| Colour | Reason |
|---|---|
| Soft blue `#7AB5C8` | Fearful (emotion), Info, and `Rare`. A blue mark reads as an Echo feeling or a notice. |
| Terracotta `#C85A54` | Inspired (emotion); close to Error `#E8412A`. Loss must not read as an error. |
| Forest `#2D6A4F` and Success green `#4CAF72` | Grieving; Success; `Uncommon`. Kept must not read as a reward flash. |
| Rarity colours for grade | Colour-only, and each one already means something else. |
| Weary tan `#8B7355` for text | 3.66:1. |

**Colour-blind rule.** Every state reads by shape or weight (section 1). Gold never stands alone: it comes with a frame (gauge), an underline (stack limit) or a label (chip). The grayscale check in section 7 is a gate.

**Surfaces.** Dark: canvas `#120E0C`, rail. Light: `SanctumCard`, result cards. Tiles go on either.

## 4. Placeholder look vs final art

| | Placeholder (001a) | Final art (catalogue story) |
|---|---|---|
| Art slot | Hatch (45 degrees, 1 px `#785C2B` at 25%, 6 unit pitch) plus the kind shape | One painted icon per `type_id` |
| Outline | Solid (dashed is lost-only) | Same |
| Name | Grey bar, or `[Jeff's wording]` e.g. `Test piece A` | Display name from catalogue |
| Marks | Real data: pips, notch, leaf, badge | Same code, no change |

**Layout survives the swap** because slot, ring and silhouette rules are fixed now. Rules: one dominant shape, readable at 40 units; no text or symbol in art; contour at least 2 px at master size.

**Catalogue must deliver.**

| Asset | Count | Size |
|---|---|---|
| Item icon, transparent PNG | 1 per `type_id` | 256x256 master, art inside the central 160x160 |
| Category fallback icon | 6 (weapon, charm, armor or clothes, relic, consumable, material) | 256x256 |

The catalogue also supplies name, category, description and the label. No Notion row owns this (decisions OPEN). Pips, notch, leaf, capsule, brackets, kind shapes and `LoadMark` are 001a glyph work, not catalogue art.

## 5. Surfaces

| Surface | Treatment | Existing style | New style |
|---|---|---|---|
| Inventory panel S1 | Cream card on dark canvas | `SanctumCard`, `SanctumHeaderCard` | None |
| Detail strip | Plaque: cream card, 2 px bronze rule above `Let it go` | `SanctumDetailPanel`, `SanctumRuleSoft` | None |
| Discard modal S2 | Centred cream card. `Keep it` is primary gold. `Let it go` is warm outline, never gold, never terracotta. | `SanctumModalPrimaryButton`, `SanctumModalSecondaryWarmButton` | None |
| Strip `Let it go` | Outline button (bronze border, ink text), 48 high | `SanctumTertiaryButton` | None |
| Result rows (kept, in the pack, lost) | One shelf under each group: kept solid 3 px bronze line, carried solid 1 px, lost dashed 2 px | `SanctumRuleGold` (reuse weight only), `RealmResolveCard` | `ItemShelfLost` (dashed rule) |
| Cap gauge | Row of cap pips; room pips hollow. Near full: ink frame and label. Full: gold fill, ink keyline, thick frame. | `SanctumProgressMarker` | `ItemGaugeFrame`, `ItemGaugeFull` |
| Sockets | Free: bed `#DCCEB5`, flat. Heavy: bed `#D9C5A0`, edge 2 lower. | none | `ItemBedFree`, `ItemBedHeavy` |
| Tile plate | Section 1 | none | `ItemPlate`, `ItemPlateKept`, `ItemPlateLost` |
| `LoadMark` | Satchel outline with 3 weave bands (basketry). Level 0..3 = bands filled 0..3; body sags wider at 2 and 3. No gold. | none | glyph set only |
| `PackLoadChip` | Neutral: `EmotionChip` panel shape, ink text. `warn.pack`: add gold outline with ink keyline. | `EmotionChip*` pattern | `PackLoadChipWarn` |

All new styles go in `assets/theme/LivingTreeSystem.tres`, never in `.gd`. Glyphs use `_draw()` or SVG, as `ThreadSlotItem` does.

## 6. Tone of loss

Loss is a leaf let go: the tile does not break; it leaves a quiet outline.

| Rule | Reason |
|---|---|
| No red, no terracotta, no strike-through, no crack | `art-direction.md` bars shattered objects. The `ThreadSlotItem` crack line is not reused. |
| Ghost outline stays, art fades | Greyed-out reward is the one pattern found for missed loot [R4 COMMUNITY, Darkest Dungeon] |
| Lost beside kept, plain fact line | Warm, not coddling [R5 ARTICLE] |
| Fade to 35%, not 0 | The player can still read what left [R9 no silent loss] |

No recovery exists (D-19, D-20), so the look implies none.

## 7. What the mockups show of my part

`anatomy.html` gets four panels.
1. **Swatch sheet:** every token in section 3 with its hex and measured contrast; the forbidden list with the swatch crossed out by a thin line.
2. **Mark sheet at 64, 72 and 3x:** kind shapes; pips; six notches; leaves; capsules; brackets; `LoadMark` 0 to 3.
3. **State strip:** one piece in the five states; one stack in the same states.
4. **Twin test:** two twins in colour and grayscale; the worst case (same notch).

Checks on the rendered PNGs (Jeff looks at these):

| # | Check |
|---|---|
| 1 | Grayscale: can I name kind, state and stack vs unique with colour removed? |
| 2 | At 64: can I tell all six notches apart, and tell a notch from a pip? |
| 3 | Gold on a light bed: does the keyline show? |
| 4 | Does lost look quiet, not hurt? Does it still show what left? |
| 5 | No soft blue, terracotta or rarity colour appears |
| 6 | Worst density (8 tiles on S5, full pack row): no mark touches an edge; text at least 12 px |

## 8. Risks and questions for Jeff

| # | Question | Recommendation |
|---|---|---|
| A1 | Grade ladder is open (ITEM-005). Pips 1 to 3 only, and no rarity colour for grade? | Yes to both. |
| A2 | Six notch shapes: 1 in 6 twin pairs match. Accept, or raise `mark_count` (D-28)? | Accept; test in play. |
| A3 | Two leaf glyphs (held, gathered), or one? | Two. D-22 makes the line matter on S5. |
| A4 | Lost: fill 35%, marks 60%. Game-feel may want one value. | Two values; the player reads what left. |
| A5 | Fix the wrong contrast numbers in the design-system file? | Yes, after this story. |
| A6 | Who owns catalogue art (256 icon per `type_id`, 6 fallbacks)? | A catalogue story before ITEM-002. |
| A7 | Dashed outline lost-only; placeholder uses hatch. | Yes. |
