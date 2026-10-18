# V2-DIRECTIVE-002: AI image prompts for the stop glyphs

Author: sr-game-artist. Status: proposal for Jeff. Nothing here is approved art.
Notes to Jeff are in STE. The prompts are for the image tool and use the tool's own style.
Sources: `glyph-shapes.md`, `design.md` 3a, the six PNGs in `assets/ui/stage_stop_glyphs/`.

## 1. Read this first: what to ask for, what to expect

1. Ask for ONE glyph per image. Never ask for a set of six in one image. Sets come out with six different styles.
2. Ask for a large image on a plain background. The tool cannot draw a good 28 px icon. Generate it large, then shrink it.
3. The tool will add detail you did not ask for: thin lines, shading, a frame, fake text. Use the NEGATIVE LIST in section 5 every time.
4. The tool cannot hold a pixel-exact outline weight. The artist fixes the weight later (section 7).
5. The tool may copy real Adinkra symbols by accident. The prompts say "original forms". Reject any result that looks like a known symbol.
6. Expect 1 good result in 4. Use the variation lines in section 4 to get alternatives.
7. Use the same style direction (section 8) for all six. Pick it before you generate.
8. DALL-E and ChatGPT make a square image by default. Keep it square. Ask for "1024x1024".
9. Transparent background is not reliable. Ask for a flat parchment background. The artist removes it later.
10. Generate the six in ONE chat if you can. Say "same style as the previous image" for glyphs 2 to 6. This helps consistency a little. It does not fix it.

Game reminders for the tool brief (so the results fit):
- The six glyphs must differ by OUTLINE SHAPE alone. Colour does not carry the meaning. All six use the same gold fill.
- The glyph sits on a 28 px slot on an Echo card. Fine detail is lost.
- Only the outline shapes below are fixed by the game today. If the tool gives a better silhouette, tell me. I will judge it.

## 2. STYLE BLOCK (paste this first, in every image request)

```
Create a single flat game icon, centered, on a plain flat parchment background (#F3E7D3). One icon only. Large, 1024x1024.

Style: bold, simple, flat vector look. A thick dark brown outline (#3D2817) with rounded corners and round joins. One flat fill of warm gold (#D4AF37). A few inner marks in the same dark brown, thick and few. Terracotta (#B5543A) only as a tiny accent if the shape needs it.

Mood: hand-made and warm. It should feel like a carved or woven West African craft object seen from the front, with a hint of geometric pattern language (repeating notches, stepped edges, woven diagonal bands). Use these as SHAPE and EDGE detail only. Use original forms. Do not copy any real Adinkra symbol or any existing cultural symbol or logo.

The silhouette must be strong and readable when shrunk to 28 pixels. Thick strokes, large shapes, few details, generous empty space inside the shape.

No text, no letters, no numbers. No gradients, no shadows, no glow, no 3D, no bevel, no texture noise, no thin lines.
```

Short form, for the second to sixth images in the same chat:

```
Same style, same colours, same outline weight, same background as the previous icon. One icon only, centered, 1024x1024. Original forms only. Now draw this one:
```

## 3. THE SIX PROMPTS

Each prompt = the STYLE BLOCK (or the short form) + the text below. Paste the STYLE BLOCK first, then the glyph text.
"Metaphors to try" are choices. Try one per run. Do not put all three in one prompt.

### 3.1 Arrived (`arrived_at`)

- Meaning: the party reached its target.
- Silhouette rule: a full ROUND outline, the only round shape in the set. It must not have corners.
- Metaphors to try:
  1. A round gold seed or kola nut with a single solid centre dot.
  2. A round carved wooden disc, with a stepped ring around a solid centre.
  3. A coiled, closed ring of woven cord with a solid centre.
- Ready-to-paste text:

```
The icon means "arrived, the journey is complete". Silhouette: a perfectly round disc, whole and closed, the only round shape in a set of six. Inside: one large solid dark brown dot in the centre, and one thick ring inside the edge made of simple repeating notches like carved wood. Calm, finished, balanced. No corners anywhere on the outline.
```

- Variation line (add one to get 4 alternatives):
  - V1: `Make the inner ring a woven cord instead of notches.`
  - V2: `Make it look like a split kola nut with a centre seed.`
  - V3: `Remove the inner ring. Keep only the disc and a big centre dot with a stepped edge.`
  - V4: `Make the outline slightly hand-cut, not perfectly round, but still a circle.`

### 3.2 Capacity spent (`capacity_spent`)

- Meaning: the party used all its steps. The walk ran out of energy.
- Silhouette rule: a ROUNDED SQUARE, 1:1, with a flat top and flat sides. No points. It must not look round, and not wide.
- Metaphors to try:
  1. A rounded block with three horizontal bars that shrink, long to short, top to bottom, like a bar running down.
  2. A carved wooden stool or block with three stepped notches cut into the face.
  3. A folded cloth stack, three layers, each layer shorter than the one above.
- Ready-to-paste text:

```
The icon means "all the steps are used up, nothing left". Silhouette: a chunky rounded square, equal width and height, with flat sides. Inside: exactly three thick horizontal bars, stacked top to bottom, each shorter than the one above (long, medium, short), left aligned, like a bar running down. Heavy, tired, stable. No points, no diagonals on the outline.
```

- Variation line:
  - V1: `Carve the three bars as stepped notches cut into a wooden block.`
  - V2: `Draw the three bars as three layers of folded woven cloth.`
  - V3: `Round the corners more, and make the bars thicker.`
  - V4: `Leave the third bar as a small empty slot instead of a filled bar.`

### 3.3 Met something (`interrupted`)

- Meaning: the party walked into a situation that was not its target.
- Silhouette rule: a HEXAGON, six straight sides, pointed left and right (or top and bottom), no other shape in the set has six sides.
- Metaphors to try:
  1. A hexagonal stone cell with one small solid dot off-centre, a traveller inside the place.
  2. A hexagon made of six woven strands that meet at a centre knot, with a small dot.
  3. A hexagonal carved doorway, small dot in the opening.
- Ready-to-paste text:

```
The icon means "the party walked into a situation". Silhouette: a bold regular hexagon with six straight sides and clear corners, rounded slightly. Inside: one small solid dark brown dot, a little off centre, like a person standing inside a place. Optionally one thin-looking but thick-drawn band along one inside edge, like a woven border. Keep the inside mostly empty. The hexagon outline must be the main feature.
```

- Variation line:
  - V1: `Make the hexagon from six thick woven strands.`
  - V2: `Add a stepped, carved inner border.`
  - V3: `Place the dot slightly lower left and make it a little bigger.`
  - V4: `Make the hexagon taller than wide.`

### 3.4 Spotted ahead (`spotted_ahead`)

- Meaning: a find came into view in front of the party.
- Silhouette rule: a POINTED shape that clearly faces one direction (right). One sharp point. No other glyph points.
- Metaphors to try:
  1. An arrow-head (pentagon) pointing right with one chevron inside.
  2. A stylised eye, almond shape, pointed at both ends, with a big solid pupil (the sharp point is the horizon).
  3. A horizon notch: a flat base with one wedge cut forward, like a gap in a hill.
- Ready-to-paste text:

```
The icon means "something came into view ahead". Silhouette: a bold shape that points to the right with one clear sharp point, like a short arrow-head or a carved pointer. Inside: one thick chevron mark pointing the same way. The left side is flat and heavy, the right side is a clean point. It must be the only icon in a set of six that points in a direction. Simple, forward-looking.
```

- Variation line:
  - V1: `Make it an almond-shaped eye pointing right with a solid pupil, instead of an arrow.`
  - V2: `Make it a flat-based horizon wedge with one notch cut forward.`
  - V3: `Use two chevrons stacked, but keep them very thick.`
  - V4: `Make the arrow-head a carved wooden pointer with stepped edges.`

### 3.5 Paused to read (`paused_to_read`)

- Meaning: the party stopped to look closer at a find.
- Silhouette rule: a WIDE CAPSULE or pill, about 2:1, wider than tall. It is the only wide shape. No corners.
- Metaphors to try:
  1. A wide pill with two upright bars, calm, a pause mark.
  2. A carved tablet, wide and rounded, with two upright grooves, like a text board.
  3. An open leaf lying flat, wide and rounded at both ends, with a centre vein and one upright bar on each side.
- Ready-to-paste text:

```
The icon means "stop and look closer". Silhouette: a wide, flat, rounded pill shape, about twice as wide as tall, with fully rounded ends. It is the only wide shape in a set of six. Inside: two thick upright bars side by side, evenly spaced, like a pause mark. Calm and still. No points, no corners.
```

- Variation line:
  - V1: `Make it a carved wooden tablet with two upright grooves.`
  - V2: `Make it a flat open leaf with a centre vein and two upright marks.`
  - V3: `Make the two bars slightly different heights, like a book page.`
  - V4: `Add a stepped carved edge to the capsule, top and bottom.`

### 3.6 No route (`no_route`)

- Meaning: there is no way forward.
- Silhouette rule: an OCTAGON, eight sides, with a thick diagonal slash across it. The slash must be the largest inner mark.
- Metaphors to try:
  1. An octagon (a stop shape) with one thick diagonal bar.
  2. A closed gate: an octagonal frame with one heavy bar across the opening.
  3. A tight knot: eight-sided woven shape with one strand crossing and blocking.
- Ready-to-paste text:

```
The icon means "no way forward, blocked". Silhouette: a bold regular octagon with eight straight sides and slightly rounded corners. Inside: one very thick diagonal bar from the top left to the bottom right, crossing the whole shape, the largest mark in the icon. Heavy, closed, final. Nothing else inside.
```

- Variation line:
  - V1: `Make the diagonal bar a thick wooden beam across a gate frame.`
  - V2: `Make the octagon a woven knot, and the diagonal bar one strand pulled tight across it.`
  - V3: `Slash from the top right to the bottom left instead.`
  - V4: `Make the bar end in squared, carved ends that reach the outline.`

## 4. How to use a variation line

Add ONE variation line at the end of the ready-to-paste text. Run it. Repeat with V2, V3, V4. Do not combine two in one run.

## 5. NEGATIVE LIST (paste at the end of every request)

```
Avoid: photorealistic rendering, 3D, bevel, emboss, drop shadow, inner shadow, glow, gradient, metallic shine, texture noise, paper texture, thin lines, hairlines, fine detail, many small marks, text, letters, numbers, watermark, border or frame around the icon, emoji style, cartoon face, generic gear icon, generic info icon, generic warning triangle, generic checkmark, generic pause button from a media player, real Adinkra symbols, real logos, more than one icon in the image, a set or grid of icons, perspective, a hand or a person, a background scene.
```

## 6. CHECK LIST: how Jeff judges a result

Do the checks in this order. Stop at the first fail.

1. Shrink to 28 px. Can you still see the shape and the inner mark?
2. Shrink to 20 px. Can you still tell what the outline is (round, square, hexagon, point, pill, octagon)?
3. Convert to greyscale. Does it still read?
4. Put all six side by side at 28 px. Are the six outlines different from each other? (Test: cover the inside marks. Can you still tell the six apart?)
5. Is the outline weight the same, or close, across the six?
6. Does it feel like this world: warm, hand-made, West African inspired, not a standard phone-app icon?
7. Does it look like a real Adinkra symbol or a known logo? If yes, reject it.
8. Does it have text, shading, a frame or thin lines? If yes, reject it, or send it to the artist only if the shape is good.

Score each result: keep, maybe, reject. One line of reason.

## 7. How to send results back, and what the artist does next

You do:
1. Save each result as PNG, 1024x1024. Do not edit it.
2. Name each file `<kind>_<style>_<n>.png`. Example: `no_route_carved_2.png`. The kinds are: `arrived_at`, `capacity_spent`, `interrupted`, `spotted_ahead`, `paused_to_read`, `no_route`.
3. Put the files in one folder. Tell me the folder path and the file names you like, with keep, maybe or reject for each.
4. Write down which style direction (section 8) you used.

I (the artist) do next:
1. Check the silhouettes against the six rules above.
2. Vectorise each kept PNG to an SVG, with a clean tracing and a limited colour count.
3. Normalise each to a 48 x 48 viewBox. One gold fill. One brown outline of 3.5 units. Round joins.
4. Match the outline weight across all six.
5. Redo the contact sheet at 20, 28 and 48 px, on parchment and on dark, in colour and greyscale. Check contrast (3:1 for graphics).
6. Hand the six SVGs to `ui-ux-designer` for import. I do not edit `ui/`.

Rules that stay the same (from `glyph-shapes.md`): shape carries the kind, colour does not. No text, no ID, no number in the glyph.

## 8. THREE QUICK STYLE DIRECTIONS (pick one before you generate)

Pick one. Paste its line directly after the STYLE BLOCK, or replace the "Mood" paragraph with it. Use the same one for all six.

| Direction | What it feels like | One-line style block |
|---|---|---|
| A. Carved wood | Heavy, warm, hand-cut. Closest to the Living Grove look and the clay board. | `Style: a flat vector icon shaped like a hand-carved wooden token, thick dark brown outline, flat gold fill, a few stepped notches and chisel cuts as pattern, chunky and slightly irregular, no wood-grain texture.` |
| B. Woven cloth | Soft, geometric, rhythmic. Strong pattern feel. Risk: busy at 28 px. | `Style: a flat vector icon built from thick woven bands in the style of strip-woven cloth, thick dark brown outline, flat gold fill, simple diagonal band pattern kept very bold and few, no thread detail.` |
| C. Brass inlay | Crisp, formal, jewel-like. Closest to the gold UI. Risk: looks like a standard icon. | `Style: a flat vector icon like a cast brass weight or an inlaid brass plate, thick dark brown outline, flat gold fill, a few bold engraved geometric cuts, solid and symmetrical, no metallic shine.` |

My lean (a proposal, not a decision): A, carved wood. It fits the clay board and the parchment card best, and it keeps the strokes thick. B is the riskiest at 20 px. C is the nearest to what you dislike now.

## OPEN — questions and assumptions
ASSUMED: The tool is ChatGPT image generation (DALL-E style), square output, no transparent background | WHY: Jeff said so; this tool usually cannot make a reliable alpha | WRONG IF: Jeff uses a tool with true transparency or vector output. Then drop the parchment-background line and ask for SVG.
ASSUMED: The six outline shapes in `glyph-shapes.md` (circle, rounded square, hexagon, arrow-head, capsule, octagon) stay fixed, and the AI only changes style and inner marks | WHY: The design (D-36) fixes six shapes and Jeff's complaint is about style, weight and plainness | WRONG IF: Jeff also dislikes the outlines. Then ask the tool for free silhouettes, and keep only the meaning lines and the "must differ by outline" rule.
ASSUMED: One gold fill and one brown outline stay (D-41: colour never carries the kind) | WHY: `glyph-shapes.md` section 3 and the contrast check depend on it | WRONG IF: Jeff wants a colour per kind. That needs a new colour-vision check.
ASSUMED: The eye and horizon metaphors for "spotted ahead", and the leaf and tablet for "paused to read", are acceptable as alternates to the arrow and the pause bars | WHY: The brief gave them as ideas to try | WRONG IF: a metaphor clashes with the board shapes in `SituationMarkerDraw.gd` (hexagon, octagon, arrow already used there). `glyph-shapes.md` section 7 already warns about this overlap.
ASSUMED: "Hint of West African pattern language" is allowed as general geometry (notches, woven bands), with no named real symbol | WHY: Art direction says do not invent pseudo-Adinkra forms and use real symbols only for their real meaning | WRONG IF: Jeff wants a real Adinkra symbol on a glyph. Then he must pick the symbol and its meaning must match the state. I will check the meaning first.
BLOCKED: none
