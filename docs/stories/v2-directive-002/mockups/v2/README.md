# Stop marker mockup, v2 (three options, animated)

The old mockup in `../` is unchanged. This folder replaces it for the review.

## Open it

Open `index.html` in a browser. No server is needed. Fonts and the tile are in `assets/`, copied from the repo.
The page autoplays one Advance. One strip above the frame holds all controls.

| Control | Use |
|---|---|
| Option A / B / C | The three coherent sets of choices (table below). |
| Run | Calm with a named Echo, Directive stop, Shaken, Edge stop. Each is a scripted run. |
| Stop kind | Shows any of the six kinds in the current run. Review tool, not in the game. |
| Replay / Pause / 0.25x | Study the motion. Pause holds everything, including the open card. |
| Size | 1280x720, or 1920x1080 (the wide profile: 1536x864 logical at scale 1.25). |
| Advance (in the frame) | Plays the run again once the screen is calm. |
| Tap the marker | Opens the why card after the marker settles (0.85 s). Tap outside or press Escape to close. |

`prefers-reduced-motion`: the token jumps tile to tile, the marker and the card only fade, and the pulse is skipped. The resting ring (option A) stays.

## Timeline (all PROPOSALS except the walk and the snippet)

| Time | Beat | Source |
|---|---|---|
| 0.00 to 0.50 s | Walk, equal segments, linear. Footprint drops and one diamond spends per tile. The fog lifts around the party at each tile (0.35 s). Green bubble starts. | Shipped: `StageExploreScreen.gd:508-537`. Easing assumed linear (not read from `PresentationState`). |
| 0.60 to 0.85 s | Marker settles once: 0.95 to 1.1 to 1.0, ease out. Shaken run: crossed steps appear in the same 0.2 s. Revealed situation markers fade in. | feel-notes.md |
| 0.90 s | One pulse (0.5 s) on the named Echo card. Snippet fades in 0.4 s, holds 2.1 s, fades out 0.5 s. | Snippet times shipped. Start moved to 0.9 s per feel-notes.md. |
| 1.40 s | Calm. Advance works again. | feel-notes.md |

The snippet line, the HUD text and the badge text are copied from the live screen. They are not new copy. All new text is `[Jeff's wording]`. The Directive cause shows as `Directive` (D-40 item 7).

## The five choices and the three options

| Choice | A: Ring and paper | B: Dark and plain | C: Quiet row |
|---|---|---|---|
| (a) Why card style | Parchment, like the top HUD | Dark modal, like the badge | Parchment |
| (b) Named Echo | Pulse, then a faint ring stays until the next move | Pulse only | Pulse only |
| (c) Journey entry | Only inside the card | Card, plus one quiet row under the top HUD | Card, plus one quiet row |
| (d) Marker form | One head shape per stop kind | One round head, small kind mark inside | One head shape per stop kind |
| (e) Crossed-out steps | Slash across the spent diamond | Hollow diamond with a tick | Hollow diamond with a tick |

Notes that help the choice:
- (b) Pulse only leaves no trace on the Echo card after 0.5 s. A player who looks away sees nothing. The ring is a shape cue and costs one outline.
- (c) The row is text at rest. D-32 says the why is on demand only. The row needs Jeff to accept that. The saved entry can still be read inside the card.
- (d) Per-kind shapes read at a glance only if six silhouettes stay distinct at 56 px. Check this in the Stop kind list. The shared head is calmer but needs a second look at the mark.
- (e) A tick can read as "done". A slash reads as "removed". Both are shape cues.

My preference, one line: A.

## How the three round 1 notes were merged

| Conflict | Resolution |
|---|---|
| Art-notes said terracotta is invisible on clay. UI notes said one gold marker. | One gold marker, charcoal edge. No terracotta on the board. |
| Art-notes put the journey entry in the card. Feel-notes and UI notes cut it from rest. | Not decided here. It is choice (c). |
| UI notes cut the fraction label. The live screen still shows `3/3`. | No fraction in the mockup (design 8 item 5). The build must remove it. |
| Art-notes: ring and head are two things. Feel-notes: merge them. | One object: ring, pole and head, one gold, one outline. |
| Feel-notes asked for a dashed ray and chevrons. | Dropped. The head shape alone carries the kind. |
| The real screenshots override art-notes and UI notes. | Ground `#120E0C`, thick clay slabs from the real atlas, dark navy badge, one centred Echo pill with three Echoes, wide gold Advance bar, green bubble, blue diamond and gold-ring circle markers. |

The tile is the real atlas, drawn at 1.3 scale (matches the screenshots). Fog is the same tile darkened (two shades). Colour is lowered a little to match the screenshot top colour. No slabs were drawn by hand.

## Layout

Only the board (slab tiles, fog, token, markers, ground colour) matches the real screenshots. The UI around the board (HUD, step row, action bar, Echo pill, badge, why card) uses the calmer design from the round 1 notes, in one style with the board. Jeff approved this.

The `Advance` label is a normal dark brown label. The live button has a blank label (a confirmed defect, not part of this mockup).

Region sizes follow uiux-notes.md section 4 and the 1280 screenshot: HUD 620x56 (720 wide at 1920), badge 204x36, step row y504, action bar y548 to 604, Echo pill y616. The Echo bar widens with three Echoes. Marks keep at least 24 px apart. The marker is the one hero mark. The tap area is the token plus the head, at least 48, and is cut back to the safe area (x16 to W-16, y84 to H-228). The Edge run shows this: a caption under the frame prints the result.

## Preview images (1280x720, rendered with headless Firefox)

For each option `a`, `b`, `c`: `preview-<o>-calm.png`, `-calm-why.png`, `-directive-why.png`, `-shaken.png`, `-edge.png`, `-midwalk.png` (frozen at 1.0 s: marker settled, pulse and snippet starting). Also `preview-a-1920.png`. Pulse-only options show no ring in the resting images. That is correct.

Frozen views use a URL hash: `#shot=1&o=A&s=edge&t=1000&why=1&z=1080`.

## Checks done

- Static views: every option and run renders with no script error (an error box would show on screen).
- The autoplay start was rendered once with no error.
- Not tested headless: Pause, 0.25x and tap-to-open by hand. Jeff or `qa-verifier` should click through once.
- No contrast measurement was made. The snippet reads weakly over bright clay. This matches the live screen but is worth a look.

## Assumptions

- Baseline steps are 4 so that lost steps can show. The live screen shows 3 for Scout Carefully.
- The bubble holds about 2.6 s. The real bark time was not read.
- Shaken Echoes show the card status `Shaken` (a label the card scene already has).
- Echo names are first names only, taken from the project's cast.
- The Directive tint and glyph are copied from the live badge. Design 8 item 6 still owns the real rule.

## Needs Jeff

1. Pick one option, or mix choices (a) to (e) from the table.
2. Is the journey row (choice c) acceptable against D-32?
