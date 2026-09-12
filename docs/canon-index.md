# Canon Index — look up, then read only that range

**Grep this file; do not read it.** One lookup costs ~50 tokens:

```bash
grep -i "snapshot" docs/canon-index.md      # find the section
sed -n '412,468p' CONVENTIONS.md            # read only that range
```

**Never read `CONVENTIONS.md` or the Working GDD end to end** — ~43,000 tokens each. They will
exhaust an agent's budget before it does any work. `~tok` below is the cost of one section alone.

## CONVENTIONS.md  (45,351 tokens total)

| lines | ~tok | section |
|---|---|---|
| `1-7` | 51 | Echoes vNext — Conventions & Contracts |
| `8-22` | 182 | &nbsp;&nbsp;V2 Migration in Progress (Alignment Wave — started 2026-04-06) |
| `23-24` | 10 | &nbsp;&nbsp;Architecture Principles (Non-Negotiable) |
| `25-30` | 82 | &nbsp;&nbsp;&nbsp;&nbsp;Determinism |
| `31-35` | 66 | &nbsp;&nbsp;&nbsp;&nbsp;Code Boundaries |
| `36-41` | 76 | &nbsp;&nbsp;&nbsp;&nbsp;Single Choke Points |
| `42-49` | 138 | &nbsp;&nbsp;&nbsp;&nbsp;Save Discipline |
| `50-55` | 58 | &nbsp;&nbsp;&nbsp;&nbsp;Naming Conventions |
| `56-76` | 671 | &nbsp;&nbsp;&nbsp;&nbsp;Reachability (added V2-PROG-012 — every new derived value, config key, or seam) |
| `77-78` | 4 | &nbsp;&nbsp;Core Contracts |
| `79-89` | 82 | &nbsp;&nbsp;&nbsp;&nbsp;Snapshot Shape |
| `90-101` | 90 | &nbsp;&nbsp;&nbsp;&nbsp;Action Shape |
| `102-113` | 139 | &nbsp;&nbsp;&nbsp;&nbsp;Slot-Keyed Actions (Feb 2026 — REQUIRED for all bespoke screens) |
| `114-131` | 236 | &nbsp;&nbsp;&nbsp;&nbsp;Bespoke Screen Contract (UI-001) |
| `132-151` | 282 | &nbsp;&nbsp;&nbsp;&nbsp;Shell Routing Model (INFRA-001) |
| `152-268` | 1628 | &nbsp;&nbsp;&nbsp;&nbsp;Responsive UI, Safe Area, and Layer Contract |
| `269-277` | 68 | &nbsp;&nbsp;&nbsp;&nbsp;State Machine Transition Logging (required for all SM transitions) |
| `278-279` | 4 | &nbsp;&nbsp;System Contracts |
| `280-285` | 102 | &nbsp;&nbsp;&nbsp;&nbsp;CampaignSeed (`core/CampaignSeed.gd`) |
| `286-292` | 235 | &nbsp;&nbsp;&nbsp;&nbsp;FlowRuntime + FlowContext (`core/runtime/FlowRuntime.gd` + `core/state/flow/FlowContext.gd`) |
| `293-320` | 446 | &nbsp;&nbsp;&nbsp;&nbsp;Actor Contract (`core/actors/`) |
| `321-335` | 437 | &nbsp;&nbsp;&nbsp;&nbsp;BehaviorModule (`core/actors/BehaviorModule.gd`) |
| `336-377` | 1152 | &nbsp;&nbsp;&nbsp;&nbsp;MaturityExpressionService — Hidden Autonomy Outputs + Divergence Contract (`core/actors/MaturityExpressionService.gd`, `core/actors/DivergenceDetector.gd`) — V2-PROG-012 |
| `378-417` | 799 | &nbsp;&nbsp;&nbsp;&nbsp;EmotionService (`core/emotion/EmotionService.gd`) |
| `418-438` | 485 | &nbsp;&nbsp;&nbsp;&nbsp;LeadershipEmotionService (`core/combat/LeadershipEmotionService.gd`) |
| `439-441` | 148 | &nbsp;&nbsp;&nbsp;&nbsp;EmotionRecoveryService (`core/emotion/EmotionRecoveryService.gd`) |
| `442-456` | 644 | &nbsp;&nbsp;&nbsp;&nbsp;GridService (`core/grid/GridService.gd`) |
| `457-536` | 3997 | &nbsp;&nbsp;&nbsp;&nbsp;Combat resolution modes & boards (V2-STAGE-004 P3a) |
| `537-598` | 3290 | &nbsp;&nbsp;&nbsp;&nbsp;V2-STAGE-004 Phase 4 — Conversation→Combat Seams, Earned Return Recruitment & Contribution Ledger (STORY NOW DONE) |
| `599-623` | 682 | &nbsp;&nbsp;&nbsp;&nbsp;SanctumLayoutService (`core/sanctum/SanctumLayoutService.gd`) |
| `624-676` | 860 | &nbsp;&nbsp;&nbsp;&nbsp;SocialGraphService (`core/sanctum/SocialGraphService.gd`) |
| `677-709` | 1105 | &nbsp;&nbsp;&nbsp;&nbsp;VowService (`core/sanctum/VowService.gd`) |
| `710-726` | 307 | &nbsp;&nbsp;&nbsp;&nbsp;ThreadService (`core/progression/ThreadService.gd`) |
| `727-739` | 213 | &nbsp;&nbsp;&nbsp;&nbsp;WeavingRiteService (`core/progression/WeavingRiteService.gd`) |
| `740-779` | 649 | &nbsp;&nbsp;&nbsp;&nbsp;CombatState (`core/combat/CombatState.gd`) |
| `780-845` | 4803 | &nbsp;&nbsp;&nbsp;&nbsp;Shared Movement Contract, Pressure + Route-Arbitration Foundation (V2-COMBAT-002 Slices 1–5) |
| `846-890` | 813 | &nbsp;&nbsp;&nbsp;&nbsp;Save Schema (`core/save/SaveSchema.gd` + `SaveService.gd`) |
| `891-917` | 595 | &nbsp;&nbsp;&nbsp;&nbsp;ContinuityService (`core/sanctum/ContinuityService.gd`) — V2-CONTINUITY-001 |
| `918-927` | 270 | &nbsp;&nbsp;&nbsp;&nbsp;Economy Settlement (`core/economy/EconomyService.gd` + `EconomyAccrualService.gd`) |
| `928-957` | 720 | &nbsp;&nbsp;&nbsp;&nbsp;DirectiveService (`core/directives/DirectiveService.gd`) — V2 (V2-DIRECTIVE-001) |
| `958-997` | 5179 | &nbsp;&nbsp;&nbsp;&nbsp;Stage Exploration — Terrain, Traversal & Fog-of-War (V2-STAGE-004 Phase 2 + 2.5 + 5) |
| `998-1021` | 1988 | &nbsp;&nbsp;Per-Screen Snapshot Summaries |
| `1022-1023` | 5 | &nbsp;&nbsp;Flow Architecture |
| `1024-1030` | 42 | &nbsp;&nbsp;&nbsp;&nbsp;Macro Loop |
| `1031-1033` | 44 | &nbsp;&nbsp;&nbsp;&nbsp;Save Triggers (no manual save in MVP) |
| `1034-1042` | 75 | &nbsp;&nbsp;&nbsp;&nbsp;Encounter Resolution |
| `1043-1114` | 2182 | &nbsp;&nbsp;Action Type Registry |
| `1115-1136` | 342 | &nbsp;&nbsp;Log Event Type Registry |
| `1137-1153` | 236 | &nbsp;&nbsp;Summoning Contract |
| `1154-1155` | 7 | &nbsp;&nbsp;Decisions Made vs Deferred |
| `1156-1212` | 5054 | &nbsp;&nbsp;&nbsp;&nbsp;Made (locked) |
| `1213-1304` | 3395 | &nbsp;&nbsp;&nbsp;&nbsp;V2-STAGE-001 + V2-STAGE-002 — Stage Exploration + Objective Taxonomy |
| `1305-1311` | 183 | &nbsp;&nbsp;&nbsp;&nbsp;Deferred |

## docs/Echoes vNext Working GDD.md  (41,923 tokens total)

| lines | ~tok | section |
|---|---|---|
| `1-14` | 201 | Echoes vNext GDD V2.5 |
| `15-26` | 103 | 1. What This Document Is |
| `27-43` | 316 | &nbsp;&nbsp;1.1 V2.5 amendment scope and evidence |
| `44-47` | 120 | 2. Core Concept |
| `48-55` | 60 | &nbsp;&nbsp;Short player-facing pitch |
| `56-65` | 81 | 3. Story Backbone |
| `66-79` | 87 | &nbsp;&nbsp;Anansi’s role |
| `80-96` | 154 | &nbsp;&nbsp;Cultural intent |
| `97-98` | 7 | 4. Player Role and Fantasy |
| `99-108` | 58 | &nbsp;&nbsp;Player role |
| `109-114` | 40 | &nbsp;&nbsp;Primary fantasy |
| `115-124` | 72 | &nbsp;&nbsp;Secondary fantasies |
| `125-132` | 59 | 5. Sanctum and Realms |
| `133-147` | 102 | &nbsp;&nbsp;Sanctum |
| `148-160` | 92 | &nbsp;&nbsp;Realms |
| `161-173` | 95 | &nbsp;&nbsp;Balance target |
| `174-186` | 79 | 6. Echoes as Returning Names |
| `187-215` | 155 | &nbsp;&nbsp;What “becoming whole” should mean |
| `216-217` | 5 | 7. Design Priorities |
| `218-227` | 103 | &nbsp;&nbsp;7.1 Stolen stories are the true progression spine |
| `228-243` | 105 | &nbsp;&nbsp;7.2 Relationships are core progression, not flavor |
| `244-260` | 239 | &nbsp;&nbsp;7.3 Guidance over control must stay playable |
| `261-272` | 68 | &nbsp;&nbsp;7.4 Myth must be systemic |
| `273-279` | 47 | &nbsp;&nbsp;7.5 The game must steer, not restart |
| `280-295` | 114 | 8. vNext Principles To Preserve |
| `296-299` | 41 | 9. Existing vNext Systems To Keep Available |
| `300-307` | 42 | &nbsp;&nbsp;Flow and UI structure |
| `308-316` | 43 | &nbsp;&nbsp;Sanctum layer |
| `317-324` | 34 | &nbsp;&nbsp;Realm and tactical layer |
| `325-332` | 47 | &nbsp;&nbsp;Echo progression layer |
| `333-344` | 67 | &nbsp;&nbsp;Economy and support systems |
| `345-348` | 22 | 10. Immediate Design Consequences |
| `349-352` | 45 | &nbsp;&nbsp;10.1 Storyweight is no longer generic progression |
| `353-356` | 29 | &nbsp;&nbsp;10.2 Bonds are part of wholeness |
| `357-360` | 27 | &nbsp;&nbsp;10.3 Vectors are part of self-shape |
| `361-364` | 30 | &nbsp;&nbsp;10.4 Callings are remembered or claimed identity |
| `365-368` | 33 | &nbsp;&nbsp;10.5 Mythic status is a narrative-mechanical threshold |
| `369-382` | 57 | &nbsp;&nbsp;10.6 Recovered stories must have visible consequences |
| `383-388` | 64 | 11. The Wholeness Model |
| `389-405` | 98 | &nbsp;&nbsp;11.1 Core principle |
| `406-447` | 497 | &nbsp;&nbsp;11.2 What an Echo is at summon |
| `448-475` | 145 | &nbsp;&nbsp;11.3 What restores wholeness |
| `476-1223` | 7592 | &nbsp;&nbsp;11.4 The six layers of wholeness |
| `1224-1442` | 2703 | &nbsp;&nbsp;11.5 System mapping to current vNext work |
| `1443-1461` | 96 | &nbsp;&nbsp;11.6 Wholeness is social, not only individual |
| `1462-1478` | 128 | &nbsp;&nbsp;11.7 What a “whole” Echo is |
| `1479-1664` | 1712 | &nbsp;&nbsp;11.8 What makes an Echo mythic |
| `1665-1681` | 102 | &nbsp;&nbsp;11.9 Design constraints for implementation |
| `1682-1706` | 100 | &nbsp;&nbsp;11.10 What this means for future sections |
| `1707-1719` | 71 | 12. The Weave System |
| `1720-1787` | 475 | &nbsp;&nbsp;12.1 Core terms |
| `1788-1797` | 67 | &nbsp;&nbsp;12.2 High-level structure |
| `1798-1826` | 130 | &nbsp;&nbsp;12.3 Progression model choice |
| `1827-1832` | 42 | 13. Thread Domains and Structure |
| `1833-1845` | 36 | &nbsp;&nbsp;13.1 Current Thread domains |
| `1846-1875` | 247 | &nbsp;&nbsp;13.2 What a Thread is as a design object |
| `1876-1894` | 166 | &nbsp;&nbsp;13.3 Expression families within a virtue |
| `1895-1907` | 114 | &nbsp;&nbsp;13.4 Why Threads are Realm-aligned |
| `1908-1916` | 54 | &nbsp;&nbsp;13.5 Virtue pattern |
| `1917-1970` | 345 | &nbsp;&nbsp;13.6 Current restore / pressure direction |
| `1971-2019` | 374 | &nbsp;&nbsp;13.7 Working virtue affinity map |
| `2020-2055` | 219 | &nbsp;&nbsp;13.8 Hidden virtue temperament profile |
| `2056-2062` | 61 | 14. Thread Recovery and the Weaving Rite |
| `2063-2081` | 179 | &nbsp;&nbsp;14.1 Realm recovery track |
| `2082-2093` | 105 | &nbsp;&nbsp;14.2 Why partial recoveries are not inventory items |
| `2094-2114` | 222 | &nbsp;&nbsp;14.3 Segment quality and Realm performance |
| `2115-2138` | 226 | &nbsp;&nbsp;14.4 From Realm recovery to full Threads |
| `2139-2162` | 201 | &nbsp;&nbsp;14.5 Omen rites and preview use |
| `2163-2175` | 152 | &nbsp;&nbsp;14.6 High-level flow |
| `2176-2228` | 467 | &nbsp;&nbsp;14.7 Threads in reserve |
| `2229-2250` | 171 | &nbsp;&nbsp;14.8 Resonance and contest |
| `2251-2280` | 284 | &nbsp;&nbsp;14.9 Detrimental effects for non-chosen Echoes |
| `2281-2301` | 122 | 15. Thread Integration Outcomes |
| `2302-2311` | 37 | &nbsp;&nbsp;15.1 Accept |
| `2312-2330` | 116 | &nbsp;&nbsp;15.2 Partially Integrate |
| `2331-2356` | 170 | &nbsp;&nbsp;15.3 Reject |
| `2357-2405` | 454 | &nbsp;&nbsp;15.4 Distort |
| `2406-2424` | 137 | &nbsp;&nbsp;15.4.1 What distortion is allowed to touch |
| `2425-2442` | 108 | &nbsp;&nbsp;15.4.2 Distortion structure per event |
| `2443-2461` | 217 | &nbsp;&nbsp;15.4.3 Distortion severity and persistence |
| `2462-2473` | 106 | &nbsp;&nbsp;15.4.4 Preferred remedy logic |
| `2474-2551` | 310 | &nbsp;&nbsp;15.4.5 Priority distortion families |
| `2552-2569` | 225 | &nbsp;&nbsp;15.4.6 Distortion in ongoing play |
| `2570-2589` | 141 | &nbsp;&nbsp;15.5 Defer |
| `2590-2612` | 189 | &nbsp;&nbsp;15.6 Remedy and recovery direction |
| `2613-2618` | 46 | 16. Readiness, Resolution, and Ambiguity |
| `2619-2627` | 40 | &nbsp;&nbsp;16.1 Why clue-based readability |
| `2628-2656` | 227 | &nbsp;&nbsp;16.2 Rite phases: invitation and resolution |
| `2657-2694` | 254 | &nbsp;&nbsp;16.3 Hidden resolution order |
| `2695-2709` | 151 | &nbsp;&nbsp;16.4 Current readiness factors and priority |
| `2710-2727` | 218 | &nbsp;&nbsp;16.5 Outcome tendencies |
| `2728-2789` | 444 | &nbsp;&nbsp;16.6 Player-facing clue surface |
| `2790-2814` | 131 | &nbsp;&nbsp;16.7 Weaving Rite aftermath |
| `2815-2888` | 582 | &nbsp;&nbsp;16.8 Repeated virtue Threads |
| `2889-2912` | 168 | &nbsp;&nbsp;16.9 What balancing support means |
| `2913-2925` | 152 | &nbsp;&nbsp;16.10 Resistance to balancing Threads |
| `2926-2944` | 140 | &nbsp;&nbsp;16.11 Visible player-facing consequences |
| `2945-2969` | 246 | &nbsp;&nbsp;16.12 Relation to mythic shaping |
| `2970-2975` | 40 | 17. Fear and Morale in the Weave |
| `2976-2985` | 49 | &nbsp;&nbsp;17.1 Fear |
| `2986-2997` | 70 | &nbsp;&nbsp;17.2 Morale |
| `2998-3007` | 43 | &nbsp;&nbsp;17.3 Why this matters |
| `3008-3013` | 42 | 18. Continuity: Sanctum Progression |
| `3014-3034` | 134 | &nbsp;&nbsp;18.1 What Continuity measures |
| `3035-3061` | 221 | &nbsp;&nbsp;18.2 What Continuity should not be |
| `3062-3090` | 254 | &nbsp;&nbsp;18.3 Feed sources currently agreed |
| `3091-3202` | 797 | &nbsp;&nbsp;18.4 One visible spine, hidden sublayers |
| `3203-3226` | 215 | &nbsp;&nbsp;18.5 Buildings, rooms, and institutions |
| `3227-3306` | 821 | &nbsp;&nbsp;18.6 Unlock logic |
| `3307-3324` | 187 | &nbsp;&nbsp;18.7 Virtue-shaped development |
| `3325-3336` | 138 | &nbsp;&nbsp;18.8 High Continuity through different house shapes |
| `3337-3354` | 150 | &nbsp;&nbsp;18.9 Fraying, stagnation, and damage |
| `3355-3366` | 97 | &nbsp;&nbsp;18.10 What Continuity primarily unlocks |
| `3367-3389` | 224 | &nbsp;&nbsp;18.11 Mythic Echoes and Continuity |
| `3390-3403` | 100 | &nbsp;&nbsp;18.12 Open Continuity questions |
| `3404-3414` | 108 | 19. Currencies, Items, and Equipment |
| `3415-3453` | 213 | &nbsp;&nbsp;19.1 Core economy split |
| `3454-3515` | 623 | &nbsp;&nbsp;19.2 Currency roles |
| `3516-3530` | 105 | &nbsp;&nbsp;19.3 Item categories and slots |
| `3531-3575` | 301 | &nbsp;&nbsp;19.4 Item role by category |
| `3576-3595` | 116 | &nbsp;&nbsp;19.5 Item sources and cadence |
| `3596-3614` | 154 | &nbsp;&nbsp;19.6 Crafting and upgrade baseline |
| `3615-3641` | 189 | &nbsp;&nbsp;19.7 Anti-hoarding structure |
| `3642-3656` | 141 | &nbsp;&nbsp;19.8 Claimed gear and emotional attachment |
| `3657-3674` | 161 | &nbsp;&nbsp;19.9 Relics and remembrance |
| `3675-3688` | 74 | &nbsp;&nbsp;19.10 Open economy questions |
| `3689-3699` | 121 | 20. Starter Flow, Tutorial, and Early Game |
| `3700-3719` | 112 | &nbsp;&nbsp;20.1 Opening design goals |
| `3720-3744` | 149 | &nbsp;&nbsp;20.2 Starting state |
| `3745-3761` | 169 | &nbsp;&nbsp;20.3 Opening sequence |
| `3762-3773` | 114 | &nbsp;&nbsp;20.4 First rite and first player choice |
| `3774-3798` | 210 | &nbsp;&nbsp;20.5 Tutorial mini-trial |
| `3799-3818` | 163 | &nbsp;&nbsp;20.6 Starter Realm |
| `3819-3837` | 170 | &nbsp;&nbsp;20.7 First proper Realm stage |
| `3838-4003` | 1744 | &nbsp;&nbsp;20.8 Stage structure, scouting, and reruns |
| `4004-4019` | 111 | &nbsp;&nbsp;20.9 First-stage hidden information |
| `4020-4096` | 524 | &nbsp;&nbsp;20.10 Failure and withdrawal in early stage play |
| `4097-4115` | 128 | &nbsp;&nbsp;20.11 Directives in the opening slice |
| `4116-4135` | 197 | &nbsp;&nbsp;20.12 Summoning unlock timing |
| `4136-4152` | 119 | &nbsp;&nbsp;20.13 First social beat |
| `4153-4172` | 149 | &nbsp;&nbsp;20.14 First 30 minutes target |
| `4173-4189` | 146 | &nbsp;&nbsp;20.15 Early-game unlock layering |
| `4190-4205` | 160 | &nbsp;&nbsp;20.16 Opening slice and foundation implications |
| `4206-4452` | 2790 | &nbsp;&nbsp;20.17 Current foundation cutline |
| `4453-4467` | 99 | 21. Remaining Open Questions |
| `4468-4477` | 55 | &nbsp;&nbsp;21.1 Early economy and inventory pressure |
| `4478-4487` | 100 | &nbsp;&nbsp;21.2 Sanctum incidents, routines, and institutions |
| `4488-4498` | 154 | &nbsp;&nbsp;21.3 Behavior and autonomy pressure-testing |
| `4499-4507` | 99 | &nbsp;&nbsp;21.4 Thread reserve, rite surfacing, and integration tuning |
| `4508-4515` | 91 | &nbsp;&nbsp;21.5 Continuity milestones and institution cadence |
| `4516-4523` | 83 | &nbsp;&nbsp;21.6 Mythic and high-end progression |
| `4524-4537` | 104 | &nbsp;&nbsp;21.7 Final stretch sequence |
| `4538-4557` | 169 | 22. Current Build Reality (April 4, 2026) |
| `4558-4574` | 155 | &nbsp;&nbsp;22.1 Current playable loop in the build |
| `4575-4594` | 290 | &nbsp;&nbsp;22.2 Systems already real enough to design around |
| `4595-4607` | 147 | &nbsp;&nbsp;22.2.1 Technical rails to accept as implementation infrastructure |
| `4608-4626` | 363 | &nbsp;&nbsp;22.3 Highest mismatches between target fantasy and current build |
| `4627-4657` | 394 | &nbsp;&nbsp;22.4 Foundation cutline and first-session proof |
| `4658-4676` | 209 | &nbsp;&nbsp;22.5 Systems that should be treated as post-foundation expansion |
| `4677-4680` | 31 | 23. Immediate Steering Priorities |
| `4681-4699` | 156 | &nbsp;&nbsp;23.1 What should be strengthened first |
| `4700-4714` | 182 | &nbsp;&nbsp;23.2 Current implementation steering rule |
| `4715-4729` | 144 | &nbsp;&nbsp;23.3 Current design warning |

