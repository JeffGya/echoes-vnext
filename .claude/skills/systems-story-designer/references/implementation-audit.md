# Implementation Audit

Use this when the user wants design analysis grounded in the actual project.

## Allowed Audit Surfaces

- source code
- gameplay scripts and data tables
- scene and UI files
- configs and tuning files
- design docs and technical docs
- mockups, screenshots, and visual assets

Inspect only the slices needed to answer the question.

## Audit Workflow

1. Confirm the design question you are testing.
2. Read the smallest set of files that determines actual player-facing behavior.
3. Separate:
   - intended design
   - implemented behavior
   - player-visible feedback
4. Trace the experience:
   player input -> system state -> feedback -> emotional/strategic consequence.
5. Report where the chain breaks or becomes unreadable.

## What To Look For

### Agency Gaps

- important outcomes happen without readable player influence
- decisions exist in menus but not in play
- the game claims autonomy, strategy, or attachment without enough interaction to support it

### Feedback Gaps

- internal state exists in code but is poorly communicated
- combat or social resolution is hard to parse
- UI fails to explain what changed or why

### Theme Drift

- implemented loops reward behavior that contradicts the stated fantasy
- emotional or narrative framing does not match the actual incentives

### Production Drift

- multiple systems were added, but the core loop became less legible
- placeholder UI or debug-like presentation is actively harming comprehension

## Output Shape

Use this order:

1. What the current build appears to do
2. The highest-impact experience mismatches
3. Concrete design or UI/system fixes
4. Narrow next inspection targets if more evidence is needed
