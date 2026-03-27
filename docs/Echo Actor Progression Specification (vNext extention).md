# Echo / Actor Progression Specification (vNext extention)

Status: v1
Scope: Hero (Echo) identity, progression, emotional evolution, vectors, and Calling system
Alignment: vNext state-first architecture, deterministic simulation, Sanctum extension systems

---

# 1. Design Intent

Echoes must feel like living souls with:

- Identity stability
- Emotional volatility
- Directional growth
- Player influence without full control

The system must:

- Remain deterministic
- Be snapshot-friendly
- Avoid grind-based stat inflation
- Support Sanctum Jobs, Bonds, Vows, Directives
- Support endgame cap at Rank 10

---

# 2. Echo Data Layers

Echo data is divided into three progression layers plus runtime state.

## Layer 1 — Core Identity (Slow Evolution)

Represents the Echo’s soul / climate.

Persistent Fields:

- id
- name
- class_origin (guardian / warrior / archer etc.)
- archetype (birth archetype, fixed)
- traits:
    - courage
    - wisdom
    - faith
- xp_total
- rank (1–10)

Rules:

- Traits only change at Rank-up or major milestone events.
- Trait drift is small (±1–3 per rank).
- Drift direction influenced by:
    - Dominant Vector accumulation (Layer 2)
    - Long-term emotional trend
    - Repeated job role
    - Major sanctum or vow events
- Archetype does NOT automatically change post-birth (MVP rule).

Traits are stable but not frozen.

---

## Layer 2 — Disposition Vectors (Hidden Growth Memory)

Represents medium-term directional identity.

Vectors are NOT shown numerically to player.
One dominant vector may be surfaced descriptively.

Example Vector Types (extensible):

- Protector
- Vanguard
- Seeker
- Pillar
- Opportunist
- Devoted
- Skeptic
- Strategist

Persistent Fields:

- vector_scores: Dictionary<VectorType, float>

Accumulation Rules (per Level or event):
Vectors increase based on:

- Combat behavior (guarding, overextending, retreating)
- Directive alignment (SCOUT, PROTECT, etc.)
- Emotional patterns (high morale boldness, fear retreat)
- Sanctum jobs (Chronicler → Seeker/Strategist bias)
- Bond behaviors (protect bonded ally → Protector weight)

Vectors do NOT directly modify core traits directly.

However, Dominant Vector DOES influence tactical and emotional behavior in MVP.

Tuning Parameter:

- All vector influence weights must be configurable via balance constants.
- Default MVP intent bias target: ~15% weighting adjustment.
- Vector bias should be noticeable but not deterministically overriding core decision logic.
- Designers must be able to tune this from 5%–25% during balance passes without architectural changes.

Tactical Influence (MVP):

- Dominant Vector biases Actor State Machine intent weighting.
    - Protector → higher guard/heal priority, faster ally-response selection.
    - Vanguard → higher aggression weighting, lower retreat likelihood.
    - Seeker → higher objective/inspection priority.
    - Opportunist → higher finishing-blow and risk-reward behavior.
- Dominant Vector may apply small action priority multipliers (not raw stat inflation).

Sanctum Influence (MVP):

- Dominant Vector biases job synergy evaluation.
    - Protector aligns strongly with defensive/support roles.
    - Opportunist aligns better with Mayor/trade/political roles.
    - Seeker aligns with Chronicler/Scout roles.

Emotional Influence (MVP):

- Acting against dominant vector increases emotional strain.
- Acting in alignment slightly improves morale recovery.

Vectors affect behavior and alignment, not raw numeric stat boosts in MVP.

Dominant Vector Switching Rules (MVP):

- A small margin buffer is required to switch dominant vector (3–5% higher than current dominant).
- Switching is evaluated immediately when vector scores change.
- Rapid oscillation is allowed if the margin condition is met.
- No cooldown or lock period in MVP.
- Each switch triggers a player-facing flag/event.
Vectors influence:
- Calling eligibility
- Trait drift bias at Rank-up
- Emotional reaction to Calling decisions

Only highest vector is optionally surfaced in UI.

---

## Layer 3 — Derived Growth (Level-Based Adjustments)

Represents incremental capability growth.

Each Rank contains 5–10 Levels.
Levels grant:

- Small derived stat adjustments
- Minor vector accumulation
- Small XP milestone rewards

Derived Stats (example set):

- max_hp
- atk
- def
- agi
- int
- cha

Derived stat growth formula uses:

- Core traits
- Rank scaling
- Emotional baseline trend
- Historical performance (minor weighting)

Level-ups DO NOT modify core traits directly.

---

## Layer 4 — Runtime Combat State (Rebuildable)

Encounter Snapshot Only:

- hp_current
- guard_state
- cooldowns
- temporary modifiers

Recomputed each encounter via deterministic stat pipeline.

---

# 3. Rank Structure

Rank: 1 → 10

Rank 1–3: Identity Forming
Rank 4–6: Consolidation
Rank 7–9: Legacy Shaping
Rank 10: Endgame Tier (Sanctum-defining Echo)

Rules:

- Trait recalculation occurs at each Rank-up.
- Calling Milestones occur at Rank 3, 6, 9.
- Rank 10 represents near-mythic tier; Sanctum should rarely contain more than one Rank 10 Echo.

---

# 4. Calling System (Emergent, Not Chosen Freely)

Calling is determined at Rank 3, 6, 9.

Calling Determination Inputs:

- Dominant Vectors
- Core Traits
- Emotional history
- Role repetition
- Sanctum job patterns

Process:

1. System computes top 2–3 eligible Callings.
2. Echo expresses preference (highest weighted path).
3. Player chooses.

Outcomes:

If Preferred Path Chosen:

- Morale boost
- Faster emotional recovery for next X stages

If Alternative Compatible Path Chosen:

- Minor morale dip
- Temporary emotional friction

If Incompatible Path Forced:

- Fear increase
- Slower morale recovery
- Potential long-term compliance reduction
- Possible permanent emotional scar (post-MVP)

Calling modifies:

- Rank-based stat scaling emphasis
- Future vector weighting
- Directive interpretation bias

Calling never fully overrides identity; it extends it.

Callings happen by a ritual certain calling my require certain items. (for MVP we keep it simpel and do not include that.) A echo can require a calling at anytime they have reached the treshold holding out with the calling to long could affect the emotions of the echo negatively. 

---

# 5. Stats, Emotions, and Vectors (Formal Definitions)

This section formalizes the canonical meaning of Stats, Emotions, and Vectors so implementation aligns with theme and minimizes guesswork.

---

## 5.1 Canonical Core Traits (MVP)

Core Traits are spiritual fundamentals. They are slow-moving identity climate.

### Courage

- Theme: Resolve, nerve, willingness to stand in danger.
- Narrative: How strongly an Echo can hold the line when the world presses.
- Gameplay influence:
    - Increases offensive output potential.
    - Increases likelihood to choose confrontational intents.
    - Supports Protector/Vanguard trajectory when reinforced.

### Wisdom

- Theme: Discernment, pattern recognition, patience, reading the weave.
- Narrative: How well an Echo interprets signs, threats, and consequences.
- Gameplay influence:
    - Improves defensive decision quality and positioning logic.
    - Supports Seeker/Strategist trajectories.
    - In Sanctum, improves planning/intel and craft-like roles.

### Faith

- Theme: Anchoring, ritual confidence, trust in the Keeper’s guidance.
- Narrative: How strongly an Echo stays rooted in meaning and purpose.
- Gameplay influence:
    - Stabilizes morale recovery and reduces emotional volatility.
    - Supports Pillar/Devoted trajectories.
    - In Sanctum, improves institution-building and resilience roles.

Notes:

- Traits are the only direct inputs to archetype mapping at birth (MVP rule).
- Traits drift only at Rank-up or major milestone events.

---

## 5.2 Derived Stats (Persistent Values, Recomputed Deterministically)

Derived Stats represent capability expression. They are computed from traits + progression + context.

MVP Derived Stat Keys:

- max_hp
- atk
- def
- agi
- int
- cha

### max_hp

- Theme: Vitality and spiritual endurance.
- Affects: survival time, risk tolerance.

### atk

- Theme: Ability to project force into the weave.
- Affects: damage output and threat presence.

### def

- Theme: Ability to resist harm, absorb impact, and remain standing.
- Affects: damage mitigation and durability.

### agi

- Theme: Quickness, repositioning, initiative readiness.
- Affects: initiative bias, pursuit/escape likelihood, objective racing.

### int (Intelligence)

- Theme: Structured knowledge, research ability, technical craft.
- Narrative: The Echo’s capacity for study, invention, and material understanding.
- Gameplay:
    - Improves scouting detail depth and research-based outcomes.
    - Influences Sanctum crafting, artificer-style roles, and alchemical development.
    - Supports future non-spiritual advanced roles.

### cha

- Theme: Social gravity, leadership presence, influence on others.
- Affects: Sanctum job outcomes, bond formation likelihood, sacrifice ripple impact.

---

### Wisdom vs Intelligence Clarification

Wisdom (Core Trait):

- Spiritual discernment, intuition, magical interpretation.
- Aligns with mage/wizard/spiritual archetypes.

Intelligence (Derived Stat):

- Academic knowledge, research, structured reasoning.
- Aligns with artificer/alchemist-type identities.

Future Resource (Post-MVP):

- Spirit (consumable resource)
    - Used by spiritually aligned Callings.
    - Separate from Intelligence.
    - Scales primarily with Wisdom and Faith.

This distinction prevents RPG-stat overlap and aligns with thematic intent.

Reserved / Post-MVP Fields (already conceptually reserved by prior design):

- acc, eva, crit
- mag/spirit_pow (name TBD)

MVP Principle:

- Derived stats can shift per Level.
- Core traits shift per Rank.

---

## 5.3 Emotional State (Fast-Moving, Run-to-Run)

Emotions are the weather layer. They change frequently and influence behavior and output.

MVP Emotion Keys:

- morale_base
- morale_current
- fear_current

### Morale

- Theme: Hope, confidence, momentum.
- Narrative: The Echo’s felt belief that the path is meaningful.
- Gameplay:
    - Controls output tiers (Inspired/Steady/Shaken/Broken).
    - Influences directive compliance and job reliability.

morale_base vs morale_current:

- morale_current fluctuates often due to combat and events.
- morale_base shifts slowly through sustained experiences (Sanctum care, victories, betrayals), but still faster than traits.

### Fear

- Theme: Collapse pressure, dread, survival instinct.
- Narrative: The Echo’s proximity to panic and refusal.
- Gameplay:
    - Drives refusal/guard/retreat behaviors.
    - Can override conviction at extreme threshold (Absolute Fear Rule).

MVP Emotional Philosophy:

- Emotions are manageable but not fully beatable.
- Poor management accumulates into catastrophic fear.

---

## 5.4 Disposition Vectors (Hidden Medium-Term Trajectory)

Vectors are directional memory that represents who the Echo is becoming.

Vector Scores:

- Stored internally as continuous weights.
- Not shown numerically.
- Dominant vector is surfaced textually.

Dominant Switching Rules (MVP):

- Requires 3–5% margin over current dominant.
- Evaluated immediately on score change.
- Rapid oscillation allowed.

MVP Vector Set (canonical names + intent meaning):

### Protector

- Theme: Shelter, guardianship, collective survival.
- Typical behavior:
    - Guards allies, intercepts threats, stabilizes the weak.
    - Prefers safe plays and reducing risk to the group.
- Sanctum affinity:
    - Defensive/support jobs, caretaking, training safety.

### Vanguard

- Theme: Momentum, bravery, breaking pressure.
- Typical behavior:
    - Aggressive engagement, first into danger, decisive strikes.
    - Prefers finishing threats quickly.
- Sanctum affinity:
    - Training roles, patrol, battle preparation.

### Seeker

- Theme: Curiosity, interpretation, pathfinding.
- Typical behavior:
    - Objective play, recon, information-first decisions.
    - Prefers minimizing unknowns.
- Sanctum affinity:
    - Chronicler/scoutmaster, intel gathering, planning.

### Pillar

- Theme: Institution, stability, leadership by steadiness.
- Typical behavior:
    - Holds positions, protects objectives, resists panic.
    - Prefers consistent value over flashy plays.
- Sanctum affinity:
    - Mayor/warden, governance, morale stabilization.

Optional Post-MVP Vectors (documented for future, not active in MVP):

- Opportunist (risk/reward, political maneuvering)
- Devoted (ritual focus, doctrine)
- Skeptic (questioning, independence)
- Strategist (coordination and planning)
- Rebel (
- more negative ones will be needed later.

MVP Mechanical Role:

- Vectors bias intent weighting (~15% default, tunable).
- Extreme dominance can partially resist fear logic.
- Extreme fear overrides all.

---

## 5.5 Calling Alignment Map (MVP Draft)

Callings are identity milestones expressed primarily through combat capability in MVP, with light Sanctum synergy hooks.

MVP Principle:

- Callings unlock combat skills.
- Sanctum effects are passive synergies, not active skill systems (MVP scope control).

MVP Calling candidates mapped to vectors:

Protector → Calling: Warder

- Combat Focus: Guard skills, ally shielding, interception.
- Sanctum Synergy (Passive): Improves training safety or morale stabilization.

Vanguard → Calling: Blade

- Combat Focus: Aggressive strikes, pressure abilities, finishing skills.
- Sanctum Synergy (Passive): Improves combat training or patrol readiness.

Seeker → Calling: Ranger/Seer

- Combat Focus: Recon, objective manipulation, positioning tools.
- Sanctum Synergy (Passive): Improves intel quality or scouting outcomes.

Pillar → Calling: Steward

- Combat Focus: Objective holding, area control, resilience skills.
- Sanctum Synergy (Passive): Improves institution stability and morale recovery.

Scope Guardrail:

- Active Sanctum-only skills are deferred post-MVP.
- In MVP, skills are combat/battle focused only.
- Sanctum interaction occurs via passive modifiers tied to Calling.

Calling should feel like an Echo’s declared direction, not a player-picked class.

---

# 6. Sanctum Jobs Integration

Jobs influence:

- XP bias
- Vector accumulation
- Emotional recovery or strain
- Event generation

Jobs do NOT directly edit core traits except via:

- Rank milestone recalculation

Example:
Chronicler → increases Seeker/Strategist vector
Mayor → increases Pillar/Opportunist vector
Trainer → increases Vanguard vector

---

# 7. Determinism Rules

The following must be explicit deterministic inputs:

- Campaign seed
- Hero seed
- XP gains
- Behavior logs
- Directive choices
- Job assignments
- Calling decisions

Rank-up recalculation must be:

- Logged
- Replay-safe
- Snapshot-stable

No silent trait mutation allowed.

---

# 8. Endgame Constraint

Rank 10:

- Represents Sanctum-level Echo.
- Sanctum should rarely support more than one Rank 10 at a time.
- Rank 10 may unlock:
    - Pillar state
    - Permanent Sanctum modifier
    - Legacy inheritance

This is endgame territory.

---

# 9. Emotional Philosophy Summary

Emotions = Weather
Vectors = Directional Memory
Traits = Climate
Calling = Identity Milestone
Rank = Life Stage
Level = Experience Step

The Keeper influences.
The Echo interprets.
Growth emerges.

---

# 10. Actor Intent Resolution Order (MVP)

This section formalizes how intent is calculated inside the Actor State Machine.

Intent Calculation Order (deterministic, logged):

1. Core Role Intent
    - Based on role (Echo, Enemy, Ally, Objective, Hazard)
    - Defines baseline priorities (e.g., Echo protects party, Enemy attacks party, Shrine drains morale)
2. Vector Bias (Echoes only in MVP)
    - Apply dominant vector weighting (~15% default).
    - May partially resist fear if extreme dominance threshold met.
3. Emotion Bias
    - Morale tier modifies aggression/confidence.
    - Fear tier modifies retreat/refusal likelihood.
    - Extreme fear overrides all (Absolute Fear Rule).
4. Context Bias
    - Grid position
    - Objective proximity
    - Directive influence
    - Sanctum-wide modifiers
5. Skill Consideration Layer (if skills equipped)
    - Skills compete with basic actions.
    - Weighted by vector alignment, emotion, smartness tier, and context.
6. Final Weighted Action Selection
    - Deterministic resolution
    - Seeded tie-breaking only
    - Logged for replay/debug

Order is fixed and may not be altered without version bump.

---

# 11. Non-Echo Actor Specification (MVP Subset)

Not all actors use the full Echo system.
The following defines which layers apply to which actor types.

## 11.1 Enemy Actors (MVP)

Enemies use a structured subset of the Echo model.

Persistent:

- id
- faction
- role
- base stat template
- level (scaled dynamically per Realm entry)
- behavior profile tag (e.g., aggressive, defensive, swarm, elite)

Progression Model (MVP):

- Enemies do NOT use XP accumulation.
- Level is assigned at encounter generation based on:
    - Realm tier
    - Recommended difficulty
    - Party average Rank
- Level modifies derived stats via scaling multipliers only.

Standard Enemies:

- No vectors
- No emotions
- No Calling

Elite / Boss Enemies (MVP+):

- Use fixed Type Bias (single dominant vector-like bias).
Example Types:
    - Ravager (aggression bias)
    - Sentinel (defensive bias)
    - Manipulator (objective bias)
- Type Bias influences intent weighting similarly to Echo vectors (~10–20%, tunable).
- No emotional override system for enemies in MVP.

Enemy Intent Flow:
Core Role Intent → Type/Behavior Bias → Context Bias → Final Action

Enemies remain deterministic but simpler than Echoes.

---

### 11.1.1 Enemy Level Scaling Model (MVP)

Scaling Model: Hybrid (Realm Tier + Party Rank Adjustment)

1. Realm Tier Base Level
    - Each Realm has an internal tier progression based on the order selected in the campaign.
    - Earlier-chosen Realms receive lower base tier.
    - Later-chosen Realms receive higher base tier.
2. Party Adjustment Band
    - Enemy Level is adjusted within a bounded band based on:
        - Party average Rank
        - Highest Rank Echo in party
    - Adjustment is clamped to prevent extreme scaling spikes.
3. Final Enemy Level Calculation (Conceptual):
Enemy Level = Realm Base Tier
+ AdjustmentFromPartyRank (bounded)
4. Design Goals:
    - Preserve player agency in Realm order.
    - Prevent trivialization via over-leveling.
    - Avoid rubber-band feeling.
    - Maintain deterministic generation.
5. Constraints:
    - Enemy scaling must never fully nullify player progression.
    - High-rank parties should feel stronger, but not invulnerable.
    - Scaling constants must be fully tunable.
6. Behavior Scaling (MVP)
    - Enemy level affects BOTH stats and behavior quality.
    - Smartness scales in DISCRETE tiers rather than continuously.
    
    Smartness Tier Model:
    
    - Every X levels (tunable: 5 or 10), an actor increases its Smartness Tier.
    - Example (if 0–100 scale):
    Tier 1: 1–10
    Tier 2: 11–20
    Tier 3: 21–30
    …
    - Tier thresholds are configurable.
    
    Each Smartness Tier increases:
    
    - Target prioritization accuracy
    - Coordination likelihood (focus fire probability)
    - Objective awareness weighting
    - Reduction in low-value action selection
    
    Allies:
    
    - Follow the same Smartness Tier structure.
    - Apply a global debuff modifier vs Echoes (tunable constant).
    
    Echoes:
    
    - Also benefit from Smartness Tier increases via Rank/Level growth.
    - Echo Smartness Tier may scale slightly faster than enemy base, but enemies receive a challenge modifier (see below).
    
    Challenge Modifier (MVP):
    
    - Enemies receive a configurable global bias multiplier to ensure they remain slightly stronger on average than Echoes.
    - This affects either:
        - Stat multipliers
        - Intent weighting bias
        - Or both (configurable)
    - Must remain tunable and bounded to avoid unfair difficulty spikes.
    
    “Smarter” behavior is implemented as deterministic weighting shifts, not new AI systems.
    Behavior scaling must be tunable and bounded to avoid sudden difficulty cliffs.
    

This ensures free Realm order while preserving challenge integrity.

---

## 11.2 Allied NPC Actors (MVP)

Allied NPCs (escort targets, temporary allies, summons, hired hands) use a subset similar to enemies, but with different biases and generally weaker/less reliable decision quality than Echoes.

Persistent:

- id
- faction
- role
- base stat template
- level (scaled dynamically per Realm/Stage entry)
- ally behavior profile tag (e.g., timid, steady, reckless, support, specialist)

Progression Model (MVP):

- Allies do NOT accumulate XP.
- Level is assigned at encounter generation.
- Level modifies derived stats via scaling multipliers.

Bias Model (MVP):

- Allies use fixed Bias Type (vector-like) but typically debuffed vs Echoes.
- Bias strength is tunable and defaults lower than Echo vector bias.
(Example: Echo ~15% default; Ally ~8–12% default.)

Emotions (MVP):

- Optional simplified morale only (no full fear system).
- Allies may be less resilient and more likely to disengage under pressure depending on profile.

Ally Intent Flow:
Core Role Intent → Ally Type/Profile Bias → (Optional) Simplified Emotion Bias → Context Bias → Final Action

Allies are flavored and scalable, but do not have identity evolution like Echoes.

---

## 11.3 Objective Actors (Shrines, Totems, Hazards)

Objectives:

- No vectors
- No emotions
- No XP
- No progression

They execute scripted deterministic logic:

- Shrine drains morale
- Totem modifies grid
- Hazard applies area effect

Objectives are state-driven entities, not personality-driven.

---

## 11.4 Design Principle

Echoes are the only actors with full identity architecture.

Enemies are systemic adversaries.
Allies are contextual participants.
Objectives are mechanical forces.

This keeps MVP scope controlled while preserving depth for player-controlled heroes.

---

# 12. Skill System Contract (MVP)

This section formalizes how skills function in Echoes vNext.

MVP Design Goal:

- Skills add tactical preparation depth.
- Skills do NOT convert the game into direct control.
- Echoes decide WHEN to use skills via simulation.
- Keeper decides WHICH skills are available before entering a stage.

---

## 12.1 Skill Ownership Rules

Uncalled Echo (Rank 1–2 MVP):

- Has no active skills.
- Can only use:
    - Basic attack
    - Basic defend/guard
    - Movement

Calling Unlock (Rank 3 MVP):

- Grants:
    - 1 Passive modifier
    - 1 Active combat skill

Future Ranks (Post-MVP):

- May unlock additional skills.

---

## 12.2 Keeper Preparation Layer

Before entering a Stage:

- Keeper selects which available skills each Echo equips.
- Skill slots are limited (MVP: 1 slot only).
- Skill loadout becomes part of deterministic encounter input.

This enables:

- Tactical preparation
- Realm-specific adaptation
- Tradeoffs between party members

---

## 12.3 Echo Autonomy Layer

During combat:

- Echo determines whether and when to use a skill.
- Skill usage is resolved via Actor State Machine intent calculation.
- Skill choice is influenced by:
    - Dominant Vector
    - Emotion state
    - Smartness Tier
    - Context (objective, threat, grid position)

Keeper cannot trigger skills directly.

This preserves:

- Simulation integrity
- Guidance > Control philosophy

---

## 12.4 Skill Definition Contract (MVP)

Each skill must define:

- skill_id
- calling_requirement
- target_type (self / ally / enemy / grid / objective)
- action_type (attack / guard / reposition / buff / cleanse)
- cooldown_rounds
- scaling_source (which derived stats influence magnitude)
- intent_weight_tag (how strongly Echo considers this action)

Optional fields (Post-MVP):

- spirit_cost
- conditional_triggers
- multi-stage effects

---

## 12.5 Intent Integration

Skill usage is evaluated inside Intent Resolution Order:

Core Role Intent
→ Vector Bias
→ Emotion Bias
→ Context Bias
→ Skill Consideration Layer
→ Final Weighted Selection

Skill actions compete with basic actions.

Higher Smartness Tier:

- Increases correct timing likelihood.
- Reduces wasted skill use.

---

## 12.6 Scope Guardrails (MVP)

MVP Limits:

- 1 active skill per Calling.
- 1 skill slot per Echo.
- No branching skill trees.
- No Sanctum-only active skills.
- No complex combo systems.

Goal:
Introduce meaningful preparation depth without overwhelming the simulation.

---

# 13. Advanced Skill Architecture (Post-MVP Direction)

This section documents the extended vision for skills beyond MVP. This is NOT required for MVP implementation but defines future architectural intent.

---

## 13.1 Calling as Role Anchor (Not Identity Lock)

Calling defines:
- Preferred skill families
- Alignment bonus weighting
- Trait synergy emphasis
- Passive identity modifier

Calling does NOT:
- Hard-lock skill families
- Prevent cross-family experimentation
- Freeze vector drift

Calling is a directional anchor, not a prison.

---

## 13.2 Skill Families (Parallel System)

Skills exist independently from Callings and are grouped into families.

Example Families:
- Guard Arts
- Blade Arts
- Path Arts
- Ritual Arts
- Command Arts
- Hybrid Arts (multi-vector overlap)
- Craft Arts (future)

Each Skill defines:
- Primary vector alignment
- Optional secondary alignment
- Primary trait scaling
- Optional secondary trait scaling
- Skill family tag

Skill effectiveness depends on alignment, not strict ownership.

---

## 13.3 Alignment Matrix (Hidden Deterministic Layer)

Skill performance is influenced by:
- Dominant Vector match
- Calling affinity
- Trait scaling quality
- Smartness Tier
- Emotional state

Alignment is NOT shown numerically to player.

Outcome Bands:
- High Alignment → Optimal execution
- Medium Alignment → Adequate execution
- Low Alignment → Reduced effectiveness + potential emotional consequence

No RNG involved. All results are deterministic.

---

## 13.4 Skill Misalignment & Failure Model

When alignment is low:

Reduced Effectiveness may include:
- Suboptimal timing
- Lower magnitude
- Poor target choice
- Inefficient cooldown use

Emotional Backlash occurs ONLY IF:
- Alignment is low
AND
- Outcome quality is poor

If outcome is strong despite misalignment:
- No backlash
- Possible pride reinforcement

This prevents obvious mechanical tells and encourages emergent discovery.

Failure is NEVER random.
It is always trait + vector + emotion driven.

---

## 13.5 Skill Use & Vector Drift

Skill usage contributes to vector accumulation.

Repeated aligned skill success:
- Reinforces current vector dominance

Repeated misaligned skill usage:
- May accelerate drift toward alternate vector
- May destabilize emotional state

Behavior → Emotion → Vector Drift → Calling Bias

This creates circular identity evolution.

---

# 14. Calling Reversal System (Post-MVP)

Calling reversal is rare, costly, and narratively meaningful.

Calling is not permanently fixed, but change is limited.

---

## 14.1 Instability Window

After a Calling milestone:
- A limited instability window exists.
- During this window, Calling may change if alignment strongly contradicts it.
- After window closes, Calling becomes stable unless extreme late-game event occurs.

---

## 14.2 Keeper-Initiated Ritual

The Keeper may attempt Calling change if:
- Vector dominance contradicts current Calling
- Trait alignment supports alternative path
- High Sanctum cost is paid

Effects:
- Emotional strain
- Temporary morale instability
- Possible skill suppression period

Calling change does NOT:
- Reset Rank
- Reset traits
- Erase history

---

## 14.3 Echo-Initiated Petition (Preferred Narrative Path)

An Echo may request Calling change if:
- Strong vector conflict exists
- Emotional dissatisfaction persists
- Repeated misaligned behavior observed

Player must choose:
- Accept petition
- Deny petition

Accepting:
- Reduced Sanctum cost
- Emotional relief
- Greater long-term stability

Denying:
- Emotional strain
- Increased drift volatility
- Possible long-term consequences

---

## 14.4 Petition Denial Outcome Model (Trait-Driven)

Denial response depends on trait configuration.

Examples:

High Faith + High Wisdom:
- Stoic endurance
- Reduced future petition frequency

High Courage + Low Faith:
- Defiant drift
- Increased volatility

High Wisdom + Low Courage:
- Quiet withdrawal

Low Wisdom + High Courage:
- Reckless escalation

Outcome is deterministic and trait-weighted.

No fixed universal reaction.

---

# 15. Visibility & Debug Policy

Player Layer (Default):
- No alignment numbers shown
- No explicit “misaligned” warnings
- Feedback only through behavior and emotional shifts

Debug Layer:
- Full alignment score breakdown
- Vector drift delta
- Emotional adjustment triggers
- Calling preference weights

All alignment calculations must be pure, loggable, deterministic functions.

---

# 16. MVP Scope (Finalized & Consolidated)

This section defines the practical implementation boundary for MVP.
Everything above defines long-term architecture. This section defines what is actually built.

---

## 16.1 Core Systems Included in MVP

Echo Progression:
- Rank 1 → 5
- 5 Levels per Rank
- Rank 3 Calling milestone only
- Small trait drift at Rank-up (±1 cap)

Vectors:
- Active vectors: Protector, Vanguard, Seeker, Pillar
- Hidden numeric storage
- Dominant vector surfaced textually
- Immediate switching with 3–5% margin
- ~15% intent bias (tunable)

Emotions:
- morale_base
- morale_current
- fear_current
- Extreme fear override rule
- No permanent emotional scars

Skills:
- Uncalled Echo: no active skills
- Rank 3: 1 passive + 1 active skill
- 1 skill slot only
- No skill trees
- No cross-family penalties exposed
- Skill misalignment only influences execution quality (no advanced backlash modeling yet)

Intent Resolution:
- Core Role → Vector → Emotion → Context → Skill → Final
- Deterministic only

Enemies:
- Level scaled (Realm Tier + Party Adjustment)
- Discrete Smartness Tiers
- Fixed Type Bias for elites
- No emotional system

Allies:
- Subset of enemy scaling
- Lower bias strength
- Optional simplified morale

Sanctum Jobs:
- XP bias
- Vector accumulation
- Minor morale influence
- No trait editing outside Rank recalculation

---

## 16.2 Explicitly Deferred (Post-MVP)

- Skill trees & hybrid families
- Skill-driven vector drift
- Emotional backlash from misaligned skills
- Calling reversal system
- Petition & denial arcs
- Trait-driven denial responses
- Multiple skill slots
- Spirit resource
- Advanced vector types
- Rank 6 & 9 Callings
- Permanent emotional scars

---

## 16.3 MVP Design Philosophy

MVP delivers:
- Identity formation
- Emotional tension
- Deterministic combat bias
- One meaningful Calling choice
- Tactical preparation via 1 skill slot

MVP avoids:
- Systemic bloat
- Identity over-fragmentation
- Multi-branch complexity
- Opaque failure spirals

Rank 5 is MVP cap.
Rank 10 remains long-term vision.