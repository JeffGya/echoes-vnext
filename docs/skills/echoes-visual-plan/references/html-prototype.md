# Echoes HTML Prototype Sections

Use this reference when extending `scan_echoes_flows.py` or hand-authoring a one-off Echoes visual plan prototype.

## Required Sections

Every HTML prototype should include:

- Header with the plan title, repo root, player slice, and generation target.
- Filterable player-facing concepts: screens, feelings, decisions, risks, and feedback moments.
- Visual journey canvas showing how the player moves between meaningful experience moments.
- Screen wireframe cards showing shell chrome, spatial area, decision area, feedback area, and disabled/failure state.
- Game feel cards for clarity, motivation, response, satisfaction, and fit.
- UX improvement opportunities and playtest prompts.

## Visual Rules

- Use HTML/CSS/SVG as the visual medium.
- Do not use Markdown, ASCII wireframes, or prose-only diagrams as the visual artifact.
- Keep the prototype self-contained unless the user explicitly asks for a hosted app.
- Avoid external runtime dependencies so the file opens directly in a browser.
- Use a restrained Echoes-like palette: warm ground, dark ink, leaf green, clay, gold.
- Do not show implementation evidence in the prototype.
- Do not lead with or include services, route tables, raw scan output, file lists, action inventories, or code examples.
- The scan exists only to keep the prototype aligned with the current game surfaces.

## Export Path

Default export:

```bash
python3 docs/skills/echoes-visual-plan/scripts/scan_echoes_flows.py --root .
```

Writes:

```text
docs/visual-plans/echoes-flow-scan.html
```

Custom export:

```bash
python3 docs/skills/echoes-visual-plan/scripts/scan_echoes_flows.py --root . --html /tmp/echoes-flow-scan.html
```

## Extension Guidance

When the user asks for a specific feature plan, extend the generated prototype with:

- A new section for the feature's current-state flow.
- A proposed-state wireframe beside the current-state wireframe.
- UX annotation cards showing player intent, decision weight, feedback, and friction.
- Open question cards only for choices that change screen boundaries, player journey, or game feel.

Do not modify gameplay code from the prototype task unless the user separately approves implementation.
