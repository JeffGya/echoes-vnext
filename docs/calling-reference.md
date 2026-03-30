# Calling Reference — Echoes vNext

> AI-readable. Last updated: PROG-009. Maintained alongside `data/balance.json`.

---

## What is a Calling?

A Calling is the role an Echo is confirmed into at Rank 3. It replaces the "Uncalled" state and defines:

- How the Echo behaves in combat (intent weights, passives, emotional signature)
- Which calling skill the Keeper can equip before each encounter
- The Echo's place in the Calling Family Circle (adjacency at Rank 6/9, post-MVP)

Callings are not classes — they are **directional memory**. An Echo's calling reflects the patterns they have been drawn toward, shaped by the Keeper's choices during Ranks 1–2. Once confirmed, the calling is permanent for that Echo.

> "You do not give an Echo a calling. You recognise the one they already have."

---

## Calling Milestones

| Milestone | When | Effect |
|-----------|------|--------|
| **Rank 3 (MVP)** | Echo reaches Rank 3 | Calling confirmed. Passive identity rules activate. Keeper can equip 1 calling skill. |
| **Rank 6 (post-MVP)** | Progression | Second calling skill unlocked. Adjacent calling branch opens. |
| **Rank 9 (post-MVP)** | Progression | Third calling skill unlocked. Deepest identity expression. |

---

## Calling Confirmation Effects

When a calling is confirmed (Rank 3):

| Change | Description |
|--------|-------------|
| `calling_origin` set | Echo's calling_origin field locked to the confirmed calling |
| Passive rules activate | Always-on BehaviorArbiter logic gated on calling_origin begins |
| Skill slot opens | Keeper can equip 1 calling skill via the Skill Loadout screen |
| Emotional thresholds shift | Absolute Fear threshold and morale sensitivity become calling-specific |

---

## Calling Family Circle

Adjacent callings share philosophical kinship. Cross-calling becomes available at Rank 6/9 (post-MVP).

```
        Blade
       /     \
   Ranger   Warder
     |         |
    Seer    Steward
       \     /
        (Seeker siblings)
```

| Adjacency | Connection |
|-----------|------------|
| Blade ↔ Warder | Frontline pivot — decisive aggression meets disciplined defence |
| Warder ↔ Steward | Anchor deepening — protection becomes presence |
| Steward ↔ Seer | Wisdom axis — ground meets vision |
| Seer ↔ Ranger | Seeker siblings — most natural cross-over (both Seeker family) |
| Ranger ↔ Blade | Decisive actors — speed and pressure |

---

## Uncalled State

Echoes at Rank 1–2 are Uncalled. They use default intent weights and have no passive identity rules or skill slot. The Keeper's choices during this phase shape which calling becomes available at Rank 3.

---

## The Five Callings

---

### Blade

**Family:** Vanguard
**Vector:** Vanguard
**Philosophy:** Strike first. Pressure maintained through constant forward momentum. Fear is fuel, not a brake.

#### Intent Profile (Rank 3)
| Action | Base Weight |
|--------|-------------|
| melee_attack | 65 |
| actor.guard | 15 |
| protect_ally | 10 |
| actor.move | 55 |
| actor.idle | 10 |

#### Emotional Signature
- **Absolute Fear threshold:** 75 (lower than default 80 — Blade fights through fear)
- **Broken morale override:** melee_attack +8.0, actor.guard −5.0. Blade in crisis attacks rather than defends.
- No fear dampening on melee — the broken morale override keeps melee viable where others shut down.

#### Always-On Passives
- **Broken morale push:** When morale_tier == "broken", applies `broken_morale_override` from calling_behavior block. Overrides normal morale_bonus for melee_attack and actor.guard.

#### Calling Skill (Rank 3, 1 slot)
| Skill | skill_id | action_type | Condition | Once/Combat |
|-------|----------|-------------|-----------|-------------|
| Blade's Resolve | `blade_resolve` | `actor.press` | Hit same target last round | No |

**actor.press:** Generates an additional melee candidate (+15 base on top of calling weight) when the Blade hits the same target in consecutive rounds. Reward for sustained pressure.

#### Resilience Traits
Blade does not have a defined resilience pool at MVP — iron will manifests as the broken morale override.

#### Leadership Traits
Not applicable at MVP.

#### Post-MVP Direction
Blade's Rank 6 branch: **Warder** (pivot toward coordinated frontline) or deeper aggression skills. Rank 9: berserker-state expressions or precision striker.

---

### Warder

**Family:** Protector
**Vector:** Protector
**Philosophy:** Hold the line. The Warder's strength grows the longer they stand still. Movement is a concession.

#### Intent Profile (Rank 3)
| Action | Base Weight |
|--------|-------------|
| melee_attack | 20 |
| actor.guard | 45 |
| protect_ally | 65 |
| actor.move | 25 |
| actor.idle | 10 |

#### Emotional Signature
- **Absolute Fear threshold:** 80 (default)
- Fear contagion from ally KOs is reduced × 0.5 (PROG-011 — no contagion system yet in MVP)
- Broken morale → protect_ally bonus (post-MVP when contagion system exists)

#### Always-On Passives
- **Anchor counter:** `_anchor_rounds` increments each non-move turn (cap 3). Adds `min(_anchor_rounds × 8, 24)` to guard/protect_ally scoring. Resets on any move action.
- Standing still rewards the Warder with increasing defensive effectiveness.

#### Calling Skill (Rank 3, 1 slot)
| Skill | skill_id | action_type | Condition | Once/Combat |
|-------|----------|-------------|-----------|-------------|
| Warder's Vigil | `warders_vigil` | `actor.interpose` | Threatened ally present | No |

**actor.interpose:** Moves to interpose between the threatened ally and the threat. Grants `guard_state` to both Warder and protected ally on resolve. Skill base: protect_ally weight (65) + 15 = 80.

#### Resilience Traits
Pool: `resist_fear` (default balance.json values).

#### Leadership Traits
Pool: `anchor_presence`, `morale_anchor`.

#### Post-MVP Direction
Warder's Rank 6 branch: **Blade** (frontline pivot) or **Steward** (anchor deepening into formation hold).

---

### Steward

**Family:** Pillar
**Vector:** Pillar
**Philosophy:** Presence is power. The Steward does not fight for victory — they fight so others can. Their stillness is not inaction.

#### Intent Profile (Rank 3)
| Action | Base Weight |
|--------|-------------|
| melee_attack | 35 |
| actor.guard | 55 |
| protect_ally | 30 |
| actor.move | 20 |
| actor.idle | 25 |

#### Emotional Signature
- **Absolute Fear threshold:** 85 (high — Steward is emotionally resilient)
- Fear → heavy move penalty; attack/guard remain stable
- Ally morale contagion halved (does not spiral with the group)

#### Always-On Passives
- **Stationary taunt:** `_stationary_rounds >= 1` → soft taunt on adjacent enemies (prefer Steward as target). Enemies within melee range are subtly drawn to attack the Steward rather than weaker allies.
- Fear raises move penalty (Steward holds ground under pressure).

#### Calling Skills (Rank 3, 1 slot — Keeper chooses)
| Skill | skill_id | action_type | Condition | Once/Combat |
|-------|----------|-------------|-----------|-------------|
| Steward's Ground | `stewards_ground` | `actor.hold_ground` | Adjacent to shrine OR 2+ allies within 2 tiles | No |
| Steward's Call | `stewards_call` | `actor.steady_call` | Always (if not used) | Yes |

**actor.hold_ground:** +3 morale to all allies within 2-tile radius. Applies soft taunt on adjacent enemies (they prefer to attack the Steward). Skill base: guard weight (55) + 15 = 70.

**actor.steady_call:** Reduces `fear_current` by 20 on all allies within `leadership_radius`. Once per combat. Skill base: protect_ally weight (30) + 15 = 45.

#### Resilience Traits
Pool: `resist_fear` (3.0), `self_regulate` (3.0), `suppress_panic_spiral` (3.0), `ignore_broken_allies` (3.0) — even weights.

#### Leadership Traits
Pool: `hold_formation`, `morale_anchor`, `steady_presence`, `position_lock`.

#### Post-MVP Direction
Steward's Rank 6 branch: **Warder** (anchor deepening) or **Seer** (wisdom axis).

---

### Ranger

**Family:** Seeker
**Vector:** Seeker
**Philosophy:** Never be where they expect. The Ranger's advantage is distance, angle, and timing. Fear is a signal to move, not to freeze.

#### Intent Profile (Rank 3)
| Action | Base Weight |
|--------|-------------|
| melee_attack | 40 |
| actor.guard | 15 |
| protect_ally | 10 |
| actor.move | 55 |
| actor.idle | 5 |

#### Emotional Signature
- **Absolute Fear threshold:** 80 (default)
- Fear → `fear_move_bonus` (+12) added to move score. Fear makes Rangers move, not freeze.
- Idle suppressed under any fear level.

#### Always-On Passives
- **Threat-minimizing movement:** When the Ranger's selected intent is `actor.move`, `ActorStateMachine` overrides `target_pos` to a tile that maximises distance from the nearest enemy cluster centroid while remaining within ally radius. The Ranger seeks advantageous position, not just proximity.

#### Calling Skills (Rank 3, 1 slot — Keeper chooses)
| Skill | skill_id | action_type | Condition | Once/Combat | Cooldown |
|-------|----------|-------------|-----------|-------------|----------|
| Ranger's Mark | `rangers_mark` | `actor.mark` | Enemy within 3 tiles AND not already marked | No | — |
| Ranger's Withdraw | `rangers_withdraw` | `actor.withdraw` | Adjacent to 2+ enemies | No | 1 round |

**actor.mark:** Sets `marked_by` on target → +10 to all Echo attack scores vs that target for 2 rounds. Skill base: melee_attack weight (40) + 15 = 55.

**actor.withdraw:** Moves to threat-minimizing tile (same logic as passive move override). Applies −3 to `fear_current` on resolve. Cooldown: 1 round. Skill base: move weight (55) + 15 = 70.

#### Resilience Traits
Pool: `resist_fear` (default). Ranger is not immune to fear — they channel it.

#### Leadership Traits
Pool: `foresight`, `spirit_read` (post-MVP when Seer cross-over is active).

#### Post-MVP Direction
Ranger's Rank 6 branch: **Seer** (Seeker sibling — most natural cross-over, spirit-aligned vision) or **Blade** (decisive actors).

---

### Seer

**Family:** Seeker
**Vector:** Seeker
**Philosophy:** To see is to change what is seen. The Seer does not fight — they reshape the field. Their idleness is not weakness; it is the ground from which everything else grows.

#### Intent Profile (Rank 3)
| Action | Base Weight |
|--------|-------------|
| melee_attack | 25 |
| actor.guard | 30 |
| protect_ally | 20 |
| actor.move | 35 |
| actor.idle | 40 |

#### Emotional Signature
- **Absolute Fear threshold:** 85 (high — Seer reads fear as information, not paralysis)
- Fear → idle score rises (Seer becomes more contemplative under pressure)
- Winning idle applies `idle_fear_aura`: reduces `fear_current` by `idle_fear_aura` (3) on all allies within `leadership_radius` (5). The Seer's calm is contagious.

#### Always-On Passives
- **Directive aura:** When a Seer is present, nearby allies (within 3 tiles) receive the `seer_directive_aura` situational bonus (+3–4 to strategic actions). Computed in `_build_board_summary()` and applied via situational_muls.
- **Read field streak tracking:** `_read_field_streak` increments each time `actor.read_field` fires. After 3 consecutive uses, a 1-round cooldown (`_read_field_cooldown`) activates automatically.

#### Calling Skills (Rank 3, 1 slot — Keeper chooses)
| Skill | skill_id | action_type | Condition | Once/Combat | Streak/Cooldown |
|-------|----------|-------------|-----------|-------------|-----------------|
| Seer's Sight | `seers_sight` | `actor.read_field` | `_read_field_cooldown == 0` | No | Max 3 consecutive, 1-round cooldown after cap |
| Seer's Reveal | `seers_reveal` | `actor.reveal` | `_reveal_used == false` AND target not yet attacked | Yes | — |

**actor.read_field:** Writes `_seers_blessing` to all allies in `leadership_radius` → +10 to next guard/protect_ally action. Streak cap 3, then 1-round cooldown. Skill base: idle weight (40) + 15 = 55.

**actor.reveal:** Sets `revealed_by_seer` on target → +15 to all Echo attack scores vs that target for 3 rounds. Once per combat. Skill base: melee_attack weight (25) + 15 = 40.

#### Resilience Traits
Pool: `resist_fear` (1.0), `self_regulate` (5.0), `suppress_panic_spiral` (5.0), `ignore_broken_allies` (1.0). Self-regulation dominant.

#### Leadership Traits
Pool: `foresight`, `spirit_read`, `calm_transmission`, `directive_echo`.

#### Post-MVP Direction
Seer's Rank 6 branch: **Ranger** (Seeker siblings — natural cross-over) or **Steward** (wisdom axis).

---

## Skill System

**PROG-009 (current):**
- 1 skill slot per Echo (unlocked at Rank 3 when calling is confirmed)
- 8 calling skills total, all fully functional from Rank 3 (no tier gates)
- Keeper equips skills via the Skill Loadout screen (before each encounter)
- `action_type` field on skill definition — BehaviorArbiter generates this as a candidate when skill is equipped and condition is met

**PROG-011 (next — investigation story):**
- Full integrated progression design: rank-to-tier mapping, 3-unlock arc, Ase/Ekwan economy
- Remaining 2 calling skills per calling (10 more skills total)
- `tier_gate` field populated for skills requiring Adept or Veteran smartness tier

**Skill Schema (`SkillDefinition.gd`):**
- Required fields (7): `skill_id`, `calling_requirement`, `target_type`, `action_type`, `cooldown_rounds`, `scaling_source`, `intent_weight_tag`
- Optional: `tier_gate` (empty string in PROG-009), `once_per_combat`, `read_field_max_streak`, `read_field_cooldown_rounds`

---

## Implementation Reference

| System | File | Purpose |
|--------|------|---------|
| Calling data | `data/balance.json` → `data.smartness.calling_behavior` | Intent weights, calling_behavior blocks, resilience/leadership pools, 8 skill definitions |
| Skill-gated candidates | `core/actors/behaviors/BehaviorArbiter.gd` → `_generate_candidates()` | Reads `equipped_skills` + `skills_cfg` from context; generates skill candidates |
| Passive identity | `core/actors/behaviors/BehaviorArbiter.gd` → `_score()` | Anchor bonus, broken morale override, mark/reveal bonuses, emotional signatures |
| Passive state updates | `core/actors/ActorStateMachine.gd` → `_update_passive_state()` | Per-turn counters, once-per-combat flags, mark/reveal duration ticks, effect application |
| Calling thresholds | `core/actors/ActorStateMachine.gd` → `advance_turn()` | Per-calling absolute_fear_threshold from calling_behavior block |
| Skill loadout (party prep) | `core/state/flow/states/venture/FlowStageMapState.gd` | `party_prep` section in `flow.stage_map` snapshot; `skill.assign`/`skill.unassign` rebuild STAGE_MAP; skills persisted on `flow.select_stage` (cta.enter_stage) |
| Actor mapping | `core/actors/EchoActor.gd` → `from_echo()` | Passes `equipped_skills` dict through to actor dict for BehaviorArbiter |
| Action type registry | `CONVENTIONS.md` → Action Registry | `actor.press`, `actor.interpose`, `actor.hold_ground`, `actor.steady_call`, `actor.mark`, `actor.withdraw`, `actor.read_field`, `actor.reveal` |

### Runtime-Only Actor Fields (not persisted)
| Field | Set By | Purpose |
|-------|--------|---------|
| `_anchor_rounds` | ActorStateMachine._update_passive_state | Warder stationary counter (0–3) |
| `_stationary_rounds` | ActorStateMachine._update_passive_state | Steward stationary counter |
| `marked_by` | ActorStateMachine._update_passive_state | Set on marked target |
| `_mark_duration` | ActorStateMachine._update_passive_state | Countdown (2 rounds) |
| `revealed_by_seer` | ActorStateMachine._update_passive_state | Set on revealed target |
| `_reveal_duration` | ActorStateMachine._update_passive_state | Countdown (3 rounds) |
| `_seers_blessing` | ActorStateMachine._update_passive_state | +10 next guard/protect_ally |
| `_steady_call_used` | ActorStateMachine._update_passive_state | Once-per-combat flag |
| `_reveal_used` | ActorStateMachine._update_passive_state | Once-per-combat flag |
| `_read_field_streak` | ActorStateMachine._update_passive_state | Consecutive read_field count |
| `_read_field_cooldown` | ActorStateMachine.advance_turn (tick) + _update_passive_state | Countdown from 1 |
| `_withdraw_cooldown` | ActorStateMachine.advance_turn (tick) + _update_passive_state | Countdown from 1 |
| `_last_attack_target_id` | ActorStateMachine (existing) | Used by actor.press condition |
