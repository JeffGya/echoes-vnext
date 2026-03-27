# Echoes vNext: Tactical Expansion — Pre-Positioning & Real-Time Guidance
## High-Level System Overview (Expansion Framework)

**Status:** Post-MVP Feature Unlock Specification  
**Scope:** Optional pre-battle tactical layer + Real-time mentorship moments  
**Architecture Alignment:** Works within existing Directive system and vNext state machine

---

## PART 1: PRE-POSITIONING SYSTEM (Tactical Expansion)

### 1.1 What It Is (High Level)

An **optional tactical planning phase** that unlocks before a stage, allowing the Keeper to suggest initial placement of Echoes before the Directive takes effect.

**Relationship to Directives:**
- Directives (Scout, Protect, etc.) remain the primary tactical intent layer
- Pre-positioning is a *secondary layer* that works alongside Directives
- Directives set "how" Echoes should approach a challenge
- Pre-positioning sets "where" they should start
- Both influence how Echoes behave, but Echoes retain autonomy to adapt

### 1.2 Design Goals

**Player Agency:**
- Gives players another decision point before combat (more agency than pure observation)
- Not about direct control, but about "suggesting" initial formation

**Echo Autonomy:**
- Echoes can refuse placements that contradict their personality, emotional state, or trait profile
- Refusals teach the player about who each Echo is
- Players learn to work *with* Echo nature, not against it

**Engagement Impact:**
- Transforms pre-battle screen from "assign squad + blessing" to "assign squad + plan formation + choose blessing"
- Adds tactical depth without replacing the Directive system
- Reward players who understand their Echoes' personalities and limitations

### 1.3 System Mechanics (Overview Only)

**When It Unlocks:**
- Realm 2–3 (after player understands core loop and Directives)

**How It Works:**
1. Player enters stage
2. Setup screen shows squad and stage conditions (already exists)
3. **NEW:** Pre-positioning phase allows player to suggest where each Echo should be positioned
4. Echoes accept, refuse, or partially adapt to suggested positioning
5. Directive is then applied (how Echoes should approach the challenge)
6. Combat starts with formation intent + directive applied

**Player Choices:**
- Position each Echo in the stage space
- Accept Echo refusals (trust gain) or override them (trust loss)
- Confirm positioning and enter stage

**Echo Responses:**
- **Accept:** Echo respects the suggested positioning; tries to maintain it during combat
- **Refuse:** Echo refuses placement (contradicts their trait/emotional state); player can accept or override
- **Adapt:** Echo understands the intent but repositions during combat based on actual stage conditions

### 1.4 What Pre-Positioning Does NOT Do

- Does NOT replace Directives
- Does NOT give players direct control over combat actions
- Does NOT determine combat outcomes (positioning is intent, not prediction)
- Does NOT require complex formation UI—simple, intuitive placement interface

---

## PART 2: MID-BATTLE GUIDANCE SYSTEM

### 2.1 What It Is (High Level)

A **real-time mentorship interface** that appears at critical combat moments, allowing the Keeper to offer guidance when an Echo is emotionally wavering, facing conflict, or needs direct support.

**Design Philosophy:**
- Not a "command" system (player doesn't order Echo actions)
- An "encouragement" system (player offers guidance; Echo decides whether to follow)
- Mirrors the core game philosophy: guidance over control

### 2.2 Design Goals

**Mentorship Feeling:**
- Makes the Keeper feel like a mentor, not a tactician
- Guidance moments are about *understanding* the Echo, not directing them
- Player learns who each Echo is through how they respond to guidance

**Real-Time Agency:**
- Adds decision-making moments during combat (not just pre-battle planning)
- Decisions are quick (3–5 options, no time pressure)
- Doesn't interrupt flow or feel intrusive

**Echo Authenticity:**
- Echoes can refuse guidance (maintain autonomy)
- Responses vary based on emotional state, traits, and personality
- No "correct" choice—each option reveals something different about the Echo

### 2.3 System Mechanics (Overview Only)

**When It Unlocks:**
- Realm 4–5 (after player has mastered positioning and understands Echo personalities)

**When Guidance Moments Trigger:**
- Critical emotional thresholds (morale dropping, fear spiking, emotional overwhelm)
- Personality conflicts (two Echoes with opposing needs)
- Moral/tactical decision points (should we protect or push forward?)
- Rare moments where Keeper's voice genuinely matters

**Frequency:**
- 1–3 guidance moments per battle (feel impactful, not intrusive)
- Not every emotion spike triggers one—only truly critical moments

**What Player Sees:**
```
[Echo Name] is [emotional state].

What guidance do you offer?

A) [Trait-resonant guidance option]
B) [Different approach]
C) [Another perspective]
D) [Yet another]
E) [Let them decide alone]
```

**Echo Responses:**
- **Accept:** Echo follows guidance, morale/emotional state shifts, trust increases
- **Partially Accept:** Echo understands intent but adapts to actual combat conditions
- **Refuse:** Echo respectfully declines guidance (contradicts their nature or emotional need), autonomy deepens
- **Independent:** If player chooses "let them decide," Echo acts purely on their personality and state

### 2.4 What Mid-Battle Guidance Does NOT Do

- Does NOT give players tactical commands (can't order "attack here" or "retreat now")
- Does NOT interrupt combat flow (prompts are brief, dismissible)
- Does NOT force Echo obedience (Echo can always refuse)
- Does NOT replace battle log or auto-battle simulation

---

## PART 3: INTEGRATION WITH EXISTING SYSTEMS

### 3.1 Directive System Compatibility

**Current State:**
- Directives (Scout, Protect, etc.) are the primary way players influence Echo behavior
- Directives shape tactical intent before battle

**With Pre-Positioning:**
- Pre-positioning adds formation suggestion before Directive applies
- Player can set "where" Echoes start, then set "how" they approach the stage
- Directive remains the primary influence; positioning is secondary context

**With Mid-Battle Guidance:**
- Guidance doesn't replace Directives; it extends them into real-time
- Directive might say "Scout," but Echo is frozen in fear—guidance helps unfreeze them
- Guidance is tactical support, not strategic override

### 3.2 Echo Refusal System (Already Exists)

Both new systems lean on Echo refusal:

**Pre-Positioning Refusals:**
- Echo refuses a suggested position (it contradicts their trait or state)
- Player learns about Echo through refusal
- Trust/reputation affected by whether player accepts or overrides

**Guidance Refusals:**
- Echo refuses guidance that contradicts their emotional need or nature
- Player must respect; no way to override mid-battle
- Deepens player respect for Echo autonomy

### 3.3 Trust & Relationship Building

Both systems contribute to long-term Echo relationships:
- Accepting Echo refusals builds trust across multiple interactions
- Choosing guidance that matches Echo traits strengthens bonds
- Over time, high-trust Echoes become more responsive; low-trust Echoes more resistant
- This creates emergent long-term mentorship arcs

---

## PART 4: PROGRESSION & UNLOCK SCHEDULE

### Timeline

| Phase | Feature | Why | When |
|-------|---------|-----|------|
| **MVP** | Directives + Pre-Battle Blessing | Core system; proven engagement | Now |
| **Realm 2–3** | **PRE-POSITIONING UNLOCK** | Teach tactical thinking; introduce position/personality relationship | Early game |
| **Realm 4–5** | **MID-BATTLE GUIDANCE UNLOCK** | Reward mastery; add real-time mentorship moments | Mid game |
| **Realm 6–7** | Autonomy Deepens | Echoes increasingly refuse; personality peaks | Late game |

---

## PART 5: ENGAGEMENT IMPACT

### Session Retention

**What It Solves:**
- MVP concern: "I'm just watching; I have no real decisions"
- With expansions: Player has pre-battle choices (positioning) + real-time choices (guidance)
- Creates multiple decision points per session, increasing perceived agency

### Emotional Investment

**What It Deepens:**
- Pre-positioning teaches player to understand Echo personalities (how they refuse, adapt, succeed)
- Guidance moments feel like genuine mentorship (Echo responds emotionally to being understood)
- Refusals become character moments, not frustrations

### Long-Term Retention

**What It Enables:**
- Learning curve: Simple positioning → Master positioning → Add guidance → Master guidance
- Each unlock feels earned and teaches something deeper about Echo autonomy
- Players naturally want to replay to try different mentorship approaches

---

## PART 6: HIGH-LEVEL ARCHITECTURE

### Pre-Positioning System

**State Input:**
- Squad assignment (already exists)
- Echo traits, emotional state, personality vectors
- Stage layout/objectives

**Player Decision:**
- Suggest positioning for each Echo
- Accept/override Echo refusals

**State Output:**
- Formation intent sent to encounter state machine
- Echoes attempt to follow formation but adapt based on combat conditions
- Trust/relationship deltas recorded

**Combat Behavior:**
- Formation is a *context layer* in Echo AI decision-making
- Echoes prioritize stage objectives over formation (autonomy preserved)
- Formation influences initial positioning; real-time conditions override it

---

### Mid-Battle Guidance System

**Trigger Logic:**
- Monitor Echo emotional state during combat
- When threshold crossed (morale drop, fear spike, conflict), pause for guidance moment
- Player chooses guidance option

**Echo AI Response:**
- Evaluate guidance against Echo's personality, traits, emotional state
- Decide: accept, partially accept, refuse, or ignore and act independently
- Next action weighted by guidance choice (but not determined)

**State Output:**
- Emotional state deltas (morale/fear affected by guidance)
- Trust/relationship deltas (guidance acceptance/refusal)
- Dialogue callback (Echo acknowledges guidance in battle log)

---

## PART 7: SUCCESS CRITERIA

### Pre-Positioning System

✓ Players position Echoes based on understanding their **roles and personalities**  
✓ Players **discover Echo traits through refusals** (positioning refusal teaches personality)  
✓ Positioning strategies **feel tactical but optional** (not required to win)  
✓ Players feel **more agency** without feeling they have "control"  

### Mid-Battle Guidance System

✓ Guidance moments feel **surprising and impactful** (not annoying interruptions)  
✓ Players **learn Echo personalities** through guidance responses  
✓ Echo refusals feel **respectful, not punishing** (player discovers depth, not loss)  
✓ Guidance becomes **memorable mentorship moments** (emotional payoff)  

### Overall Integration

✓ Both systems feel like **natural extensions** of Directive system  
✓ Echoes remain **autonomous throughout** (positioning/guidance are influences, not commands)  
✓ Players experience **clear progression**: Directives → Positioning → Guidance  
✓ Long-term retention comes from **mentorship discovery**, not tactical optimization  

---

## PART 8: DESIGN DECISIONS LEFT FOR DEVELOPMENT

### Pre-Positioning Interface

You will determine:
- How positioning interface looks and feels (grid size, visual style, interaction pattern)
- How Echo refusals are presented (modal, inline, tone)
- How trust/reputation feedback is shown (visible, hidden, subtle)
- Integration with your existing grid system

### Mid-Battle Guidance Interface

You will determine:
- How guidance prompts appear (full-screen, overlay, dialogue bubble)
- Button layout and styling
- Accessibility features (narration, haptics, timing)
- Trigger frequency and refinement based on beta feedback

### Balance Tuning

You will determine:
- How often Echoes refuse positioning (~15% baseline, adjustable)
- How often guidance moments trigger (~1–3 per battle, adjustable)
- Trust/reputation gains and losses (player acceptance = trust gain)
- Echo response weights (how likely to accept vs. refuse)

---

## CONCLUSION

**Pre-Positioning + Mid-Battle Guidance** form a progression:

1. **MVP:** Players learn Directive system and core mentorship philosophy
2. **Realm 2–3:** Pre-positioning teaches players to *plan with* Echo personalities (not against them)
3. **Realm 4–5:** Mid-battle guidance teaches players to *understand* Echo emotions in real-time
4. **Realm 6–7:** Full autonomy emerges—Echoes increasingly refuse, showing their true nature

Each unlock teaches the same core philosophy deeper: *You guide; they decide. And that's leadership.*

The systems are **optional expansions** (pre-positioning can be skipped if player wants pure Directive + blessing) but **powerfully rewarding** for players who engage with them.

---

**Spec Version:** 3.0 (High-Level Expansion Framework)  
**Status:** Ready for you to design and flesh out during development  
**Next Step:** You determine visual implementation, balance tuning, and detailed mechanics during dev cycle

