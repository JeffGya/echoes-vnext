# UI/UX Design Reference

> General-purpose UX and UI design knowledge for this project. Relevant to both the game design work on Echoes vNext and Jeff's broader UX practice.
>
> **Claude Code:** these topics map to invocable skills (`design:*`, `anthropic-skills:*`). Invoke by name when available.
> **Codex / any agent:** this document is self-contained. Apply the knowledge directly.

---

## Jeff's UX Context

Jeff is a Senior UX Designer with ~8 years of experience. His background is in complex product design (financial services at ABN AMRO) and game UI/UX. He is the designer on this project — the AI is the developer. Only implement what Jeff explicitly instructs.

---

## User Research

**When:** before building a new feature, screen, or system when player intent or behaviour is uncertain.

### Research methods by question type
| Question | Method |
|----------|--------|
| What do players want to do? | Jobs-to-be-done interviews |
| Can players complete a task? | Usability test (think-aloud) |
| How do players feel? | Diary study, emotion mapping |
| What matters most? | Card sort, priority ranking |
| Is this direction right? | Concept test, desirability study |

### Research artefacts to produce
- Research plan (goal, questions, method, participants)
- Interview / test script
- Synthesis: themes, quotes, insight statements
- HMW (How Might We) opportunity areas
- Recommendations ranked by confidence + impact

---

## Research Synthesis

**When:** after collecting research data — turning raw observations into actionable insight.

### Synthesis steps
1. Dump all observations (quotes, behaviours, moments) into a structured list
2. Cluster by theme — look for pattern, not frequency
3. Name each theme with a tension or insight (not a topic label)
4. Write insight statements: "[User type] struggles with [X] because [Y], which means [Z]"
5. Generate HMW questions from each insight
6. Prioritise by: player impact × feasibility × alignment with design pillars

---

## Design Critique

**When:** reviewing a screen design, flow, or component before implementation.

### Critique dimensions
- **Clarity:** does the player know where they are, what they can do, and what matters?
- **Hierarchy:** is the most important thing the most visually prominent?
- **Consistency:** does this match patterns established elsewhere in the game?
- **Feedback:** does every action produce a visible response?
- **Affordance:** do interactive elements look interactive?
- **Edge cases:** empty states, loading, errors, maximum content length

### Format for critique output
1. What works (specific, not generic)
2. What's unclear or broken (with reason)
3. Specific suggestions (actionable, not prescriptive)
4. Open questions for Jeff to decide

---

## Design Handoff

**When:** a screen design is final and needs implementation specs.

### Handoff spec contents
- Screen name + flow state it maps to
- Node hierarchy (what goes in `.tscn`)
- Interactive states per element: default / hover / pressed / disabled / focus
- Animation: duration, easing, trigger
- Spacing: exact dp values for margins, padding, gaps
- Typography: weight, size, line-height per element
- Colour: token names (not hex) — reference Living Grove design system
- Touch targets: confirm all interactive elements meet 48×48dp minimum
- Accessibility notes: contrast ratio, label requirements

---

## UX Copy

**When:** writing or reviewing any text that appears in the UI.

### Principles for Echoes vNext copy
- **Mythic, not mechanical** — "Your echo falls silent" not "Echo HP = 0"
- **Keeper voice** — second person ("Your Sanctum…"), dignified, never gamey
- **Brevity** — every word earns its place; remove adjectives first
- **Emotion over description** — "Broken" not "Low morale state"

### Copy types and guidelines

| Type | Rule |
|------|------|
| CTA labels | Verb + object. Max 3 words. "Summon Echo", "Enter Realm", "Confirm Party" |
| Empty states | Explain what's missing + one action. "No echoes yet. Visit the Sanctum to summon." |
| Error states | Say what happened + what to do. Never blame the player. |
| Confirmation prompts | State the consequence, not the action. "This will spend 50 Ase." |
| Morale tiers | Inspired / Steady / Shaken / Broken — these are canonical, do not rename |
| Calling names | Ward / Break / Veil / Path / Rite / Root — canonical, do not rename |
| Standing / Step | Use these terms, not "rank" or "level" in player-facing copy |

---

## Accessibility Review

**When:** before shipping any new screen or visual component.

### Checklist (WCAG 2.1 AA)
- [ ] Text contrast ≥ 4.5:1 (normal text), ≥ 3:1 (large text / UI components)
- [ ] All interactive elements ≥ 48×48dp touch target
- [ ] Colour is never the only differentiator (always pair with shape, label, or pattern)
- [ ] Focus order is logical (top-to-bottom, left-to-right)
- [ ] All images and icons have text labels or alt descriptions
- [ ] Error messages are not red-only (use icon + text + colour together)
- [ ] Motion can be reduced (respect system reduced-motion settings)

---

## Design System — Living Grove

**Reference:** `docs/DesignSystem_LivingGrove_Complete_Guide.md`

**When:** adding new components, checking token values, ensuring visual consistency.

### Core tokens (reference the full guide for values)
- **Colour:** ochres, deep browns, forest greens, terracotta — warm earthy palette
- **Typography:** weighted, purposeful. Hierarchy via weight and size, not decoration.
- **Spacing:** 4dp base unit. Common values: 4, 8, 12, 16, 24, 32, 48dp
- **Radius:** subtle, not pill-shaped. Components feel grounded, not floaty.
- **Elevation:** minimal shadow use — flat with texture over depth-based hierarchy

### Adding a new component
1. Check the guide first — does this component already exist?
2. If extending: keep all existing tokens; add new ones only if unavoidable
3. Document: name, variants, states, tokens used, usage rules
4. Author in `.tscn` — never create UI structure in `.gd`

---

## When to Use Which Reference

| Situation | Where to look |
|-----------|--------------|
| New game screen design | `docs/skills/game-ui-ux-echoes.md` |
| In-game copy / labels | UX Copy section above |
| Screen critique / review | Design Critique section above |
| Implementation handoff | Design Handoff section above |
| Living Grove design system | `docs/DesignSystem_LivingGrove_Complete_Guide.md` |
| Research for game features | User Research section above |
| Accessibility check | Accessibility Review section above |
| GDD design intent | `docs/Echoes vNext Working GDD.md` |
| Art direction / aesthetic | `docs/art-direction.md` |
