# V2-ITEM-001 research: how other games handle shared inventory, loot, loss and cap pressure

Written in STE. Step 0a of the plan (decision D-10).

## Evidence level: LOW

Two research agents used WebSearch only. WebFetch failed for every wiki and forum host (DNS block). No agent opened a full page.
Every claim comes from a search-result summary. Links are given as the agents reported them. I did not open them.
A claim without a link, or marked UNVERIFIED, is not evidence. Treat all lessons below as hypotheses for the design round.
One scraped page held an embedded instruction aimed at an AI agent. The agent ignored it and used none of that page.
To get verified research, the session network must allow these hosts: steamcommunity.com, fandom.com wikis, wiki.gg wikis, fireemblemwiki.org, stardewvalleywiki.com, support.2k.com.

## Verification pass 2 (independent searches, same day)

WebFetch is blocked for every host tried, Wikipedia included. Only WebSearch works. I ran eight new searches, written differently from the first pass, and compared them with the first pass. Search-result summaries still, no page opened.

| Claim | Result | Notes |
|---|---|---|
| XCOM 2: loot left on the ground is lost on an evac mission; supply-raid evac gives nothing | CORROBORATED (community level) | Several Steam threads agree. The summary says the posts are from about 2015 to 2016 and may predate patches. No official source. The "2K support FAQ" line from pass 1 was not found again. |
| XCOM 2: on a non-evac mission the game collects loot if you finish before the timer ends | CORROBORATED (community level) | Same threads. A few unconfirmed reports of missing loot. |
| XCOM Enemy Unknown: soldiers outside the drop zone are flagged left behind, then MIA | CORROBORATED (modder notes) | Nexus developer notes plus a Nexus rescue thread. This is not official. Ground gear lost on abort is only "generally" supported. Ufopaedia's "abort = instant loss" is about the final two-part mission only. Do not cite it as a general rule. |
| Darkest Dungeon: a full inventory forces drop choices; leftover supplies are lost; treasure turns into gold on return; trinkets are kept | PARTLY CORROBORATED | Several Steam threads (community level). New detail: unused supplies refund only a small fraction. The 16-slot figure was NOT found again. The pass 1 claim "loot vanishes when the window closes" was NOT found again. |
| Darkest Dungeon 2: a full Stagecoach stops the expedition until the player discards; discarding gives a little Hope; no selling; Storage Trunk adds 3 slots, Spacious adds 6 | CORROBORATED | Wiki and guide results agree (wiki.gg, fandom, fextralife, a guide site). |
| Darkest Dungeon 2: quitting an expedition loses all items and trinkets | NOT RE-VERIFIED | The second search found nothing on abandoning. Still single source (gamepressure). |
| Stardew Valley: pack 12, then 24 for 2,000g, then 36 for 10,000g | CORROBORATED | Several results agree, including the game wiki and forum pages. The number 12 came from pass 1 only. |
| Fire Emblem Three Houses: convoy holds 400, bundles of 99 | NOT CORROBORATED | The search returned nothing on capacity. Treat as unverified. |
| Gears Tactics: no storage cap found; recruit-and-dismiss to move gear | WEAK | Two searches found no cap. The dismiss workaround rests on one Steam thread (same thread both times, so not independent). |
| Dragon Quest Builders 2: a full inventory blocks pickup, even a key item; the Bag unlocks at Furrowfield | PARTLY CORROBORATED | Two guides (GameSpew, Twinfinite), both several years old. No slot count found. |
| Tomodachi Life, Into the Breach details | NOT RE-CHECKED | Still pass 1 only. |

Net effect on the hypotheses below: numbers 3 (Stardew upgrade path), the Darkest Dungeon 2 stop-and-discard rule, and the XCOM 2 loot-loss rule are now supported by more than one source. All of it is still community level. No official source was reached.

## Verification pass 3 (searches limited to official and game-wiki domains)

Method: WebSearch with `allowed_domains` set to official sites and the games' own wikis. Fetch is still blocked, so these are search summaries of official pages, not page reads. This pass corrects pass 2 where noted.

| Claim | Result | Source type |
|---|---|---|
| XCOM 2: calling extraction early gives up loot, experience and mission success parameters | CONFIRMED by an official source (first reported in pass 1, now found again) | 2K support FAQ, support.2k.com. The FAQ is about 10 years old and predates War of the Chosen. |
| XCOM 2: a fallen soldier's gear is lost if the body is not extracted | Community guidance only | Same search; not from the FAQ. |
| Darkest Dungeon: the mission inventory has 16 slots and holds supplies and collected loot; the trinket stash has 999 slots; each hero has 2 trinket slots | CONFIRMED on the Darkest Dungeon wiki.gg ("Official Darkest Dungeon Wiki") | Corrects pass 2, which could not find the 16. |
| Darkest Dungeon: survivors may claim a dead hero's trinkets "if there is room" | NEW, from the wiki | Relevant to us: a full stash can block a recovery. |
| Darkest Dungeon: on retreat, a random party member dies; the wiki advises unequipping trinkets before abandoning a quest | Reported by the wiki location page; unusual, treat with care | Not matched by any other source. |
| Stardew Valley: pack 12, then 24 (2,000g), then 36 (10,000g) | CONFIRMED on the Stardew Valley Wiki | Players say 36 feels tight since version 1.6. |
| Fire Emblem Three Houses: convoy 400 items; identical items bundle to 99; each unit carries 6 items; convoy access is tied to Byleth | CONFIRMED on fireemblemwiki.org, plus a Serenes Forest forum thread | Corrects pass 2 ("not corroborated"). A forum anecdote says the game may prompt a discard even when the convoy has space (not official). |
| Dragon Quest Builders 2: the bag has a fixed capacity that a patch raised | CONFIRMED that a capacity increase happened (Square Enix official update notes); slot count NOT found | Per-island placement caps for storage furniture (32 for general storage) are on the Dragon Quest Wiki. |
| Gears Tactics: the convoy is the mobile base where equipment cases from the battlefield are opened; gear is outfitted between missions | CONFIRMED in official Xbox and Gears pages; no stash cap found in any official page | Our earlier "no cap found" stands. |

Still without an official source: Darkest Dungeon 2 quit-loses-items rule, Tomodachi Life, Into the Breach, XCOM Enemy Unknown abort rules, and every complaint claim (complaints are community opinion by nature).

What changed for the design round:
- The Fire Emblem convoy gives a second real number set: a large shared pool (400), bundles of 99 for identical items, a small personal carry (6). It fits our mix of unique gear and stacks.
- The Darkest Dungeon "claim a trinket if there is room" rule is a precedent for a full inventory blocking a recovery.
- The XCOM 2 early-extraction rule is now an official precedent for the loss on an early leave.

## Findings by game

| Game | Cap and storage | Loot to base | Failed or early end | Complaints | Source level |
|---|---|---|---|---|---|
| Gears Tactics | No gear cap found (UNVERIFIED). Roster cap only. | Map cases picked up by a unit; prize claimed at mission end. | UNVERIFIED | Players recruit soldiers to strip gear, then dismiss them. | steamcommunity threads (snippets) |
| XCOM: Enemy Unknown | UNVERIFIED for 2012. Original UFO games: storage "effectively unlimited"; over capacity blocks buying and transfers. | UNVERIFIED | Players say an abort counts as a failed mission. A modder reads the code as: gear of soldiers left behind is destroyed (modder reading, not official). | One bug thread about gear loss on failure. | ufopaedia, steam, nexusmods (snippets) |
| XCOM 2 | No cap found (UNVERIFIED). | A unit picks up loot and must evacuate with it. Loot left on the map is auto-recovered on mission completion. If the carrier dies, the loot drops. | Early extraction forfeits loot, XP and mission parameters (2K support FAQ). | Players ask for mods that retrieve all loot on evac. | xcom.fandom, support.2k.com, steam (snippets) |
| Into the Breach | No shared inventory found (UNVERIFIED). | Time pods are recovered if they survive to mission end. They are destroyed by Vek or damage. Pod risk is visible on the map. | Cores and items are lost on a timeline reset. | UNVERIFIED | intothebreach.fandom, steam (snippets) |
| Darkest Dungeon | In-run loot inventory 16 slots; trinket stash 999; 2 trinkets per hero. | Loot sells for gold on return; trinkets go to the stash. | A dead hero's trinkets are recoverable only after a won battle. Loot rule on retreat: UNVERIFIED. | Players hit the cap mid-dungeon and cannot take gold or gems. Loot left behind vanishes. Some defenders like the risk-versus-reward choice. | darkestdungeon.wiki.gg, steam (snippets) |
| Darkest Dungeon 2 | Stagecoach has limited slots; base upgrades raise them. | Items ride in the Stagecoach; return details UNVERIFIED. | Quitting an expedition loses all items and trinkets from that run. A full Stagecoach stops the expedition until the player discards. | No sell, so players discard spare trinkets freely; some miss the first game's selling. | wiki.gg, fextralife, gamepressure, steam (snippets) |
| Tomodachi Life | No general item cap found (UNVERIFIED). 70 Miis (100 in the original). Delete one Mii to add one. | No expedition loop found. | Not applicable | Gifts for levelling run out quickly (one review). | nerdschalk, games.gg, crystal-dreams (snippets) |
| Fire Emblem (Three Houses) | Convoy 400 items; identical items bundle to 99. | In most games a full unit sends new items to the convoy (not confirmed for Three Houses). | Not applicable | None found. | fireemblemwiki.org (snippets) |
| Stardew Valley | Pack 12, 24 (2,000g), 36 (10,000g). Chests are shared storage. | The player carries items home by hand. | A mine treasure chest gives a swap screen. One forum report says cancelling drops and duplicates the loot (single report). | Pack too small for late areas. Depositing into chests is tedious (a mod exists for it). | stardewvalleywiki, forums, nme (snippets) |
| Dragon Quest Builders 2 | Main inventory plus a Bag; community chest; storage furniture has limits. | The player carries items home by hand. | Not applicable | Early-game carry limit blocks pickups. | twinfinite, gamespew, nintendo (snippets) |

## What the evidence suggests (hypotheses)

1. **Games that show the loss rule before the player commits get less complaint.** XCOM 2 and Darkest Dungeon 2 state what a quit costs. (Weak: no direct complaint data.)
2. **The closest precedents handle a full cap by blocking or asking, not by silent loss.** Dragon Quest Builders 2 blocks the pickup. Darkest Dungeon 2 stops the expedition until the player discards. Stardew Valley gives a swap screen. Darkest Dungeon (original) loses loot when the window closes, and players complain about it.
   - This is an open tension with D-04 ("item is lost when the cap is full"). D-04 stands. The design round must decide how the loss is warned about and shown.
3. **A hard cap is accepted when the player chooses what to drop and can raise the cap.** Stardew Valley has bought pack upgrades. Darkest Dungeon defenders like the choice. The pain is tedious sorting, not the cap itself.
4. **With no sell, players discard spare gear freely** (Darkest Dungeon 2). D-02 (no sell) therefore makes attachment and the recycle hook the only value for spare gear.
5. **Loot tied to one carrier is fragile** (XCOM 2). Our packs belong to the party, not to one Echo. Keep it so.
6. **Total forfeit on early leave drives players to mods** (XCOM 2). Our roll (nothing, some, everything) is softer. Whether the odds are shown to the player is a design question.
7. **Per-character carry limits make players juggle** (Fire Emblem lesson, from the agent, not from a complaint source). D-02 already gives free transfer.
8. **Exploit risk:** Gears Tactics players strip gear and dismiss units. Free transfer removes the reason. Stardew Valley has one unconfirmed duplication report on a cancelled prompt. Our intake must resolve once, with one deterministic record, and ignore a cancelled prompt.

## Pitfalls table

| Pitfall | Game | How our design could avoid it | Evidence |
|---|---|---|---|
| Silent loss at a full cap | Darkest Dungeon | A cap meter on the path view and the Sanctum screen; a warning before the path ends; a "will be lost" tag on the incoming item; the loss shown as an explicit event | Medium |
| Player cannot see counts while looting | Darkest Dungeon | Show gear count against the cap in every packs and arrival view | Low |
| Loss rule unclear until after the loss | XCOM abort | State the early-leave rule on the leave confirmation | Low |
| Total forfeit on early leave | XCOM 2 | Keep the roll; decide whether to show the odds | Medium |
| Loot tied to one carrier who can die | XCOM 2 | Packs belong to the party | Medium |
| Gear moved by exploit | Gears Tactics | Free transfer; no per-unit slot ownership | Medium |
| Tedious depositing and sorting | Stardew Valley | One bank step at the path end; free transfer; no per-character limits | Medium |
| Cap too small with no way to raise it | Stardew Valley | A config hook for a cap increase (the Sanctum growth link is not in this story) | Medium |
| Duplication on a cancelled prompt | Stardew Valley (single report) | One idempotency key per intake; ignore a cancelled prompt | Low |
| Spare items worthless when there is no sell | Darkest Dungeon 2 | Recycle hook (Ekwan only); attachment (ITEM-003 and later) | Low |
| Key items blocked by a full cap | Dragon Quest Builders 2 | Keep Threads, entitlements and key items outside the cap (already required) | Low |

## Not verified

Gears Tactics cap, mission-fail loot and UI. XCOM 2012 loot flow and UI. Into the Breach cap and complaints. Darkest Dungeon retreat loot rule. Darkest Dungeon 2 slot counts and UI. Tomodachi Life item cap, attachment rules and any cap display. Fire Emblem Engage capacity and attachment. Stardew Valley cap warning. Dragon Quest Builders 2 slot counts and UI. Early-leave roll fairness as a pitfall in any game.

## Gaps for the design round

- No source describes a roll-based settlement of away loot. Our packs rule has no verified precedent.
- No verified source shows how any game displays cap pressure before a loss. The design round must invent and test this.
