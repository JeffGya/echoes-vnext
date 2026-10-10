---
name: echoes-visual-plan
description: Create UX- and game-feel-focused HTML visual plans for Echoes vNext. Use when Codex needs to inspect the project context and turn current or proposed gameplay, UI, screen, combat, Sanctum, Realm, onboarding, or player-flow work into a standalone HTML prototype with player journey maps, screen wireframes, friction notes, improvement opportunities, playtest prompts, and game-feel checks.
---

# Echoes Visual Plan

Use this skill to make UX- and game-feel-focused HTML planning prototypes for Echoes vNext. The prototype must show how the player moves through the game, what they understand, what they decide, what feedback they receive, and where the experience could feel clearer, stronger, or more emotionally grounded.

## Core Rule

Inspect the project before drawing, but do not turn the scan into the artifact. A valid visual plan is grounded in:

- `docs/Echoes vNext Working GDD.md` for design canon.
- `CONVENTIONS.md`, `docs/CONTEXT.md`, and `docs/LESSONS.md` for contracts and workflow.
- `docs/skills/godot-echoes-dev.md`, `docs/skills/echoes-sankofa-gdd.md`, and `docs/skills/game-ui-ux-echoes.md` for project-specific references.
- current flow, screen, shell, and scene reality as internal context only.

If implementation reality conflicts with the intended player experience, call it out as a UX/game-feel mismatch before proposing changes.

## Workflow

1. Define the player slice.
   - Name the player goal, start state, end state, and emotional or strategic payoff.
   - Keep scope narrow: one screen, one feature, one loop, or one journey.

2. Scan the implementation.
   - Run `python3 docs/skills/echoes-visual-plan/scripts/scan_echoes_flows.py --root .` from the repo root to export the default prototype to `docs/visual-plans/echoes-flow-scan.html`.
   - Use `--html <path>` to place the prototype somewhere else.
   - Use the scan internally to avoid inventing screens or flows.
   - Prefer `rg` for targeted follow-up searches.

3. Build the current-state visual model.
   - Map player moment -> screen family -> primary decision -> expected feedback.
   - Show owned chrome as UX context: Sanctum BottomRail, Realm EchoBar, blocking modals.
   - Include modal/overlay ownership when it affects the player journey.
   - Do not show code evidence, route tables, raw scanner output, or file inventories in the prototype.

4. Extend the HTML prototype for proposed or audited flows.
   - Use real HTML/CSS sections for flow maps, screen wireframes, modal states, UX annotations, friction notes, and improvement prompts.
   - Use SVG or CSS-based diagrams inside the HTML when a relationship needs to be seen spatially.
   - Use UX annotation cards, not code annotation cards.

5. Evaluate game feel.
   - Check clarity, motivation, response, satisfaction, and fit.
   - State what the player sees, chooses, waits for, hears/feels conceptually, and learns.
   - Surface missing feedback, unclear stakes, false agency, weak pacing, or overloaded UI as player-facing issues.

6. End with decisions and questions.
   - Separate settled decisions from open questions.
   - Ask Jeff only for choices that materially change the player journey, screen boundary, or game feel.
   - Do not mutate code from the visual plan unless the user explicitly approves implementation.

## HTML Prototype Output

Do not output visual plans as Markdown. Export a standalone `.html` file and give Jeff the file path.

The prototype should include these sections when relevant:

- Prototype header: scope and player slice.
- Journey canvas: onboarding -> Sanctum -> Realm prep -> Venture -> Combat/pressure -> Resolve/return.
- Screen wireframes: visual boxes for chrome, spatial field, decision panels, modals, and feedback surfaces.
- UX friction notes: what is unclear, weak, slow, low-stakes, or emotionally flat.
- Improvement opportunities: concrete design prompts for better game feel, UI clarity, and feedback.
- Game feel audit: clarity, motivation, response, satisfaction, and fit cards.
- Playtest prompts: checks for player understanding, decision weight, feedback read, and emotional continuity.

For each wireframe, label the snapshot type, shell, persistent chrome, primary player decision, feedback surface, and failure/disabled state.

The first viewport must read like a prototype or user-flow artifact, not a scan report. Do not include service lists, code examples, route tables, file trees, raw scanner output, or visible implementation evidence.

## Echoes-Specific Checks

- Snapshot actions are slot-keyed Dictionaries, never Arrays, except legacy fallback renderer cases that must be named as legacy.
- UI is a renderer of snapshots; it must not inspect `FlowContext`, `SaveService`, or sim internals.
- Per-row interactions are dispatched by rows, not placed in `snapshot.actions`.
- Shell-owned chrome is part of the wireframe, even when the screen does not render it.
- Sanctum plans must account for spatial layer, overlay screen, BottomRail, notifications, and blocking modals.
- Realm plans must account for active screen, EchoBar, resolve modal behavior, and stage/combat transitions.
- No player-facing internal IDs in wireframes or proposed copy.
- Use V2 language: Storyweight, Standing, Step, Thread, Virtue domain, Scout Carefully, Seek Signs.

## Agent Native Plans

If the Agent Native Plan connector is installed, publish the same structure through `/visual-plan`, `/visual-recap`, or `/visualize-repo`. Also export the local HTML prototype so there is always a repo/file artifact independent of the hosted review surface.

## Resources

- `scripts/scan_echoes_flows.py`: internal project scanner and HTML prototype exporter for UX/game-feel review.
- `references/html-prototype.md`: Echoes-specific HTML prototype requirements and extension guidance.
