# V2-DIRECTIVE-002 — Proposed wording for `data/ui/stage_why_text.json`

**PROPOSALS ONLY. Jeff decides all wording.**

Status: FINAL wording is in `data/ui/stage_why_text.json` (D-68). This file keeps the proposals and Jeff's column D for history. The JSON file wins if they differ.

## How to read this file

- The meaning column is written in Simplified Technical English (STE). It explains the key.
- The A, B and C columns are proposed game lines. They are NOT STE. They follow the project voice: short, plain, spoken by a tired person.
- A = plain. B = warmer. C = drier.
- No line contains a number or an id.
- `{name}` is replaced by the Echo's display name. The `{name}: ` prefix is kept exactly where the file has it.
- Lines in the same group are written to differ from each other.
- Each line is under 12 words.

## Where each key is read

| Group | Read by | What the player sees |
|---|---|---|
| `stop` | `ui/components/StageWhyText.gd` (`compose`, title) | The title of the why card. |
| `cause`, `purpose`, `route` | `StageWhyText.gd` (`compose`, rows) | One row each on the why card. |
| `echo_reason` | `StageWhyText.gd` (`compose`, row). `{name}` is replaced here only. | One row on the why card, only when an Echo is named. |
| `ui.echo_named` | `StageWhyText.gd` (fallback to `echo_reason`) | Same row as above. Only used when no reason class is set. |
| `ui.open_why` | `ui/shells/RealmShell.gd:249` | Screen-reader name of the stop mark. Not visible text. |
| `ui.close_why` | `ui/components/StageWhyCard.gd:22` | Screen-reader name of the close control. Not visible text. |
| `ui.party_card_label` | `ui/shells/RealmShell.gd:66` | The party card label. Already decided as "The party" (D-64). Not proposed here. |

## 1. `stop` — card title (why the walk ended)

| key | What it means in plain words | A (plain) | B (warmer) | C (drier) | D my edit |
|---|---|---|---|---|---|
| `stop.arrived_at` | The party reached its target. | They reached the place. | They got where they were going. | This was the place. They stopped. | They have arrived at a destination.
| `stop.capacity_spent` | The party used all its steps for this walk. | They ran out of steps. | Their legs were done for the day. | That was as far as they could go. | No more steps can be taken.
| `stop.interrupted` | The party met a situation it had not resolved. | They ran into something. | They came across something and stopped. | Something was in the way. | Something has stopped them.
| `stop.spotted_ahead` | The walk showed a decisive goal or danger ahead. | They saw something ahead. | Something important was ahead. They stopped. | Something ahead. They had to decide. | They notice something curious.
| `stop.paused_to_read` | The walk showed a minor find, or a risky next step. | They stopped to take a closer look. | Something caught their eye, so they stopped. | They checked it before going on. | Something worth pausing for has been seen.
| `stop.no_route` | No route could be found from this point. | There was no way on from here. | They could not find a way through. | No way through. They stopped. | There is no way on from here.

Note: `spotted_ahead` is the heavier stop. `paused_to_read` is the lighter stop. The lines show that difference.

## 2. `cause` — who decided the way (row on the why card)

| key | What it means in plain words | A (plain) | B (warmer) | C (drier) |D my edit |
|---|---|---|---|---|---|
| `cause.echo` | One named Echo decided the way. The next row names them. | One Echo made the call. | One of them really wanted this way. | One of them chose it. | They are leading the way.
| `cause.terrain` | The ground left only one way to go. | The ground left only one way. | The land gave them no other choice. | There was only one way through. | The path knows only one direction.
| `cause.objective` | The goal of the walk fixed the way. | Their goal lay in this direction. | The goal they came for was this way. | The goal was this way. No other reason. | Their purpose lays before them.
| `cause.situation` | A known situation on the road fixed the way. | Something they already knew about was here. | They knew about trouble on this route. | A known problem shaped the way. | They recall this. This is problem is known.
| `cause.party` | The whole group decided. No single Echo did. | The whole group chose this together. | Everyone in the group leaned this way. | The group went this way. Nobody pushed. | Everyone agrees on this path.
| `cause.directive` | The order alone decided. No Echo did. | They went the way they were asked. | They did what they were told to do. | That was the order. They followed it. | The keeper's direction was honored.

Note on `cause.directive`: the design says this row shows the word "Directive". The voice rule bans that word in player text. The lines above avoid it. Jeff must decide. See OPEN.

## 3. `purpose` — what the party was doing (row on the why card)

| key | What it means in plain words | A (plain) | B (warmer) | C (drier) |D my edit |
|---|---|---|---|---|---|
| `purpose.advance` | The party moved toward its goal. | They pushed on toward the goal. | They were heading for the goal. | They kept moving forward. | They keep moving forward.
| `purpose.reposition` | The party moved to a better spot. | They moved to a better spot. | They were getting into position. | They shifted where they stood. | This is a better place to move from.
| `purpose.read` | The party looked around and searched the area. | They were looking around. | They were looking further ahead. | They were checking the area. | They are looking around.
| `purpose.hold` | The party stayed in place. | They stayed where they were. | They held their ground. | They kept still and waited. | They are holding their ground.

Note on `purpose.hold`: MEANING UNCLEAR. The design (section 8, "Purpose") lists three families: Read, Advance, Reposition. The code allows four values, and `hold` is the fourth. See OPEN.

## 4. `route` — how the party went (row on the why card)

| key | What it means in plain words | A (plain) | B (warmer) | C (drier) | D my edit |
|---|---|---|---|---|---|
| `route.direct` | The party took the straight way. | They took the direct way. | They went straight at it. | No detour. They went straight through. | No hesitation, they are going straight at it.
| `route.skirted` | The party went around a known danger. | They went around the danger. | They went around the trouble carefully. | They avoided the known danger. | It is not worth it, better avoid the known danger.

Note: the design also lists "cautious" and "only way" as route wording. No key exists for them in the JSON or the code. The "only way" case is covered by `cause.terrain`. See OPEN.

## 5. `echo_reason` — what about the Echo (row, only when an Echo is named)

The `{name}: ` prefix stays on every line.

| key | What it means in plain words | A (plain) | B (warmer) | C (drier) | D my edit |
|---|---|---|---|---|---|
| `echo_reason.calling` | The Echo's calling shaped the choice. | {name}: This is what they are good at. | {name}: This is their kind of work. | {name}: They always go for this sort of thing. | {name} is following their calling.
| `echo_reason.temperament` | The Echo's own nature shaped the choice. | {name}: That is just how they are. | {name}: That is their nature. | {name}: They have always moved like this. | {name} is following their nature.
| `echo_reason.fear` | The Echo's fear shaped the choice. Fear is never the Echo's fault. | {name}: The road made them uneasy. | {name}: Their nerves were on edge. | {name}: They did not like the look of the road. | {name}'s nerves are on edge.
| `echo_reason.morale` | The Echo's low morale shaped the choice. Low morale is never the Echo's fault. | {name}: They were worn down today. | {name}: Their spirits were low. | {name}: They had nothing left for more. | {name}'s spirit is low. 
| `echo_reason.steadied` | The Echo followed the group's mood, not their own. | {name}: The others kept them steady. | {name}: The group's calm rubbed off on them. | {name}: They went along with the group. | The group has given {name} some motivation back.

## 6. `ui` — screen-reader names (not visible text)

| key | What it means in plain words | A (plain) | B (warmer) | C (drier) | D my edit |
|---|---|---|---|---|---|
| `ui.echo_named` | Fallback row. An Echo is named but has no reason class. The design says this should not happen. | {name}: They had a reason for this. | {name}: This one was their call. | {name}: They made this choice. | {name} made this call.
| `ui.open_why` | Screen-reader name of the stop mark. Tapping it opens the why card. | Why did they stop? | Tell me why they stopped. | Why they stopped | Tell me why they stopped.
| `ui.close_why` | Screen-reader name of the close control on the why card. | Close | Hide this | Done | Close

Note: `ui.open_why` and `ui.close_why` are read by a screen reader. They are not printed on screen. Jeff may still want them to match the visible text.

`ui.party_card_label` is not proposed. It is "The party" (D-64).

## MEANING UNCLEAR

| key | Why unclear |
|---|---|
| `purpose.hold` | The design lists three purpose families (Read, Advance, Reposition). The code also allows `hold`. The design does not define it. |

## OPEN — questions and assumptions

ASSUMED: the `{name}` placeholder is not replaced in `cause.*`, `purpose.*`, `route.*` or `stop.*` rows. | WHY: `StageWhyText.compose` replaces `{name}` only on the `echo_reason` row. | WRONG IF: a later change replaces `{name}` in other groups. Then the cause and route lines may use the name.

ASSUMED: `ui.open_why` and `ui.close_why` are screen-reader names only. | WHY: `RealmShell.gd:249` passes `open_why` to the stop mark's accessible name, and `StageWhyCard.gd:22` sets `close_why` as the close button's accessible name. | WRONG IF: either key is later shown as visible text.

ASSUMED: "the Echo's fear" and "the Echo's low morale" lines are safe to show, because they do not blame the Echo. | WHY: design section 8, rule 3, says a fear or morale reason never reads as a fault. | WRONG IF: Jeff wants the Echo named as the cause in these lines.

BLOCKED: `cause.directive`. The design (section 8, the Cause row) says the journey entry shows the word "Directive" when the Directive alone decided. The voice rule bans the word "Directive" in player text. The proposals avoid the word. | CHECKED: `docs/stories/v2-directive-002/design.md` section 4 rule 7 and section 8 Cause row; `AGENTS.md`; the voice rules in the brief. | NEED: Jeff decides. Either (a) the word "Directive" is allowed here, or (b) the proposals stand and the design rule is changed.

BLOCKED: `purpose.hold`. The design names three purpose families. The code allows four. | CHECKED: `design.md` section 8 Purpose row; `core/movement/StageStopPolicy.gd:10`. The only producer found is the goal purpose in `core/realms/StageExploreTurnService.gd:525`. | NEED: Jeff or `mechanics-developer` confirms whether `hold` can reach the player. If it cannot, its line is not needed.

BLOCKED: the design's route wording "cautious / low-exposure" and "only way" has no key. | CHECKED: `data/ui/stage_why_text.json` (route has only `direct` and `skirted`); `StageStopPolicy.gd:11` (`ROUTES`). | NEED: Jeff says whether to add keys. This is a schema change, so it is not made here.

ASSUMED: `ui.echo_named` is a fallback only. | WHY: design section 4 rule 6 says a named Echo always has a reason class. | WRONG IF: a named Echo can reach the card with no reason class. Then this line is shown.

ASSUMED: the stop titles are card titles, and each stop line may be a short phrase. | WHY: `StageWhyText.compose` sets `title` from the `stop` group. | WRONG IF: the title is shown at a size or place that needs fewer words.

ASSUMED: the `echo_reason.temperament` meaning is the Echo's hidden virtue temperament profile. | WHY: GDD section 13.8 "Hidden virtue temperament profile"; `StageCounterfactualService.gd:242` maps `temperament` to the style score. | WRONG IF: the design means something else by temperament. The proposals do not name the profile.
