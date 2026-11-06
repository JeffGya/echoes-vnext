# Research: UI best practices for V2-ITEM-001a

Date: 2026-11-01. Method: WebSearch summaries only. WebFetch was blocked. I did not read any page in full.

Evidence labels: OFFICIAL (publisher or platform owner), DEVELOPER (developer talk or post), ARTICLE (third-party analysis), COMMUNITY (forum, wiki, player report), UNVERIFIED (no source found).

Main limit: I found no developer-written source on the XCOM, Gears Tactics, Wartales, Battle Brothers, Fire Emblem or Mutant Year Zero inventory screens. Most evidence is COMMUNITY.

## 1. Armory and inventory layout

| Finding | Evidence | Source |
|---|---|---|
| A grid shows more items on one screen than a list. A list sorts better. | COMMUNITY | https://forum.chaosforge.org/index.php/topic,6927.55/wap2.html ; https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Baldur's Gate 3 uses a grid for equipment slots and a list for general inventory (hybrid). | ARTICLE | https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Grid works when item management is part of the play. List works when inventory is a means to an end. | ARTICLE | https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Grid cursor navigation is harder on a gamepad than with a mouse. Design for both from the start. | ARTICLE | https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Original X-COM forced five screens for one squad decision. The author asks for quick links between related screens. | ARTICLE | https://www.gamedeveloper.com/design/the-ui-missteps-behind-one-of-the-best-games-of-all-time- |
| XCOM 2 modders ask for a link from squad select to soldier loadout, and for armory to show squad membership. Jumping between screens is "cumbersome". | COMMUNITY | https://steamcommunity.com/app/268500/discussions/0/154644705025464376 (via search summary; exact thread not confirmed) |
| Gears Tactics: one review names the between-mission loadout UI as its main criticism. Detail not found. | ARTICLE (mirror site, original not confirmed) | https://wwwrockpapershotgos.pages.dev/posts/gears-tactics-review |
| Darkest Dungeon: unequipped trinkets are one stack per slot. Unique trinkets allow one copy only. | COMMUNITY (official-named wiki, old pages) | https://darkestdungeon.wiki.gg/wiki/Inventory ; https://darkestdungeon.wiki.gg/wiki/Trinkets_(Darkest_Dungeon) |
| Fire Emblem Three Houses: identical items with the same durability bundle into one stack, max 99. Convoy sort uses durability first, then type. | COMMUNITY | https://fireemblemwiki.org/wiki/Supply_convoy ; https://gamefaqs.gamespot.com/boards/204445-fire-emblem-three-houses/77909964 |
| Stardew Valley: inventory rows of 12. An auto-sort button orders by game order and quality. | OFFICIAL-WIKI (fan wiki) so COMMUNITY | https://stardewvalleywiki.com/Inventory |

How identical items are told apart: none of the sources I found shows an explicit "equipped vs spare" mark for twin items. Fire Emblem separates identical items by durability value. This is a gap. See section "Could not verify".

## 2. Capacity display and warnings

| Finding | Evidence | Source |
|---|---|---|
| Darkest Dungeon provisions: 16 slots. Stack sizes differ (torch 8, food 12). | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/Provisions |
| Darkest Dungeon II: the stagecoach has limited slots. A storage trunk adds four. Players discard to make room. | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/Stagecoach_Items ; https://darkestdungeon2.wiki.fextralife.com/Storage+Trunk |
| Battle Brothers: if loot is not clicked on the post-battle screen, it is discarded. One player lost items to a full stash after closing the window early. | COMMUNITY | https://steamcommunity.com/app/365360/discussions/1/1733216261946060355 |
| Battle Brothers mods add loot sort by value on the loot screen. Players wanted it. | COMMUNITY | https://www.nexusmods.com/battlebrothers/mods/960 |
| Stardew Valley: with a full backpack, a fish caught with treasure moves into the chest menu. Closing it early forfeits the rest. | COMMUNITY | https://stardewvalleywiki.com/Fishing |
| Wartales: weight limit per companion. Camp chests still count toward weight. Players find this confusing. | COMMUNITY | https://steamcommunity.com/app/1527950/discussions/0/575994948960165203 (via search summary) |
| A design note suggests sending overflow loot to a "lost items" box, so the player does not manage inventory right after a peak moment. | ARTICLE (weak, vendor-style page) | https://www.agensi.io/skills/game-design-peak-end-audit |

Pattern: players are hurt when loss happens silently at a moment of rush (closing a window, pressing B). The fix in these reports is a visible count before the loss and a safe place for overflow.

## 3. Loadout prep and departure

| Finding | Evidence | Source |
|---|---|---|
| Darkest Dungeon: the wiki advises players to unequip trinkets before fleeing, so they are not lost. This is a player burden, not a game warning. | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/Darkest_Dungeon_(location) |
| Darkest Dungeon: unequipped trinkets in the inventory are lost forever on a party wipe, per the Shrieker page. | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/The_Shrieker |
| XCOM Enemy Unknown: some items are not all available before missions. A 2016 thread calls base menus "unintuitive". | COMMUNITY | https://steamcommunity.com/app/268500/discussions/0/412446292777172546 (via search summary) |
| Stardew Valley: fishing treasure and mine loss rules are explained on the wiki, not in the game at the moment of risk. | COMMUNITY | https://stardewvalleywiki.com/The_Mines |

I found no source about a "warning chip" on a prep screen in any listed game. UNVERIFIED for all games. Our chip is new design work.

## 4. After-action reports

| Finding | Evidence | Source |
|---|---|---|
| Darkest Dungeon: after any exit, a debriefing screen shows. Rewards are greyed out after an unsuccessful run. Unused provisions turn into small gold. | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/Expeditions |
| XCOM 2: gear of dead soldiers is lost on an evac unless a soldier carries the body out. Players learn this from forums. | COMMUNITY | https://steamcommunity.com/app/268500/discussions/0/2789318172117541544 (via search summary) |
| XCOM 2: left-behind soldiers may be recovered on a later rescue mission, with gear. Details conflict between posts. | COMMUNITY | https://cyberpost.co/can-you-recover-captured-soldiers-xcom-2/ |
| A studio moved extra values from a combat report into a detail view opened on tap. | DEVELOPER (small studio blog) | https://millionlords.com/?p=1111 |
| Warframe players: a results screen that fills half the display hides useful information. | COMMUNITY | https://forums.warframe.com/topic/1213187-the-new-mission-endscreen-is-confusing-and-wasting-space/ |
| Short summary first, detail on request, a short delay before the popup. | ARTICLE (weak) | https://www.agensi.io/skills/game-design-peak-end-audit |
| Slay the Spire 2: Mega Crit disabled chest skipping in multiplayer after players confused skip with Proceed. | ARTICLE | https://www.pcgamer.com/games/card-games/slay-the-spire-2-adds-end-of-run-badges-to-let-you-know-what-was-unique-about-each-adventure-in-latest-beta-patch |

Not found: any source on "loot you did not get" display, other than the Darkest Dungeon greyed-out rewards and the XCOM forum explanations. The greyed-out reward is the only visible pattern. It shows what was missed without a text lecture.

## 5. Loss, retreat and failure tone

| Finding | Evidence | Source |
|---|---|---|
| Roguelike failure reads as investment when each run banks something (currency, unlocks, knowledge). Show progress on the failure screen. | ARTICLE | https://bugnet.io/blog/designing-failure-how-to-make-losing-fun |
| A game over screen breaks flow. It is a metagame element. | ARTICLE | https://www.gamedeveloper.com/design/alternatives-to-the-game-over-screen |
| Fold failure into the fiction instead of ignoring it. | ARTICLE | https://gamespace.com/all-articles/news/game-over-is-not-the-end-how-games-turn-failure-into-part-of-the-story/ |
| Counterpoint: a reviewer disliked a game that coddled the player and avoided stating that failure happened. | ARTICLE | https://popmatters.com/post/font-can-be-insulting |
| Stardew Valley: after passing out in the mines, lost items can be recovered from Marlon at the Adventurer's Guild. This is a recovery path for loss. | COMMUNITY (wiki) | https://stardewvalleywiki.com/The_Mines |
| Darkest Dungeon II: discarding an item gives a small amount of Hope. Loss is turned into a small gain. | COMMUNITY | https://elevation.propertystream.co/darkest-dungeon-ii-discard-guide.html (low-quality site; treat as weak) |
| Stardew Valley: an upgraded trash can returns 15% to 60% of an item's gold value. | COMMUNITY (wiki) | https://stardewvalleywiki.com/Trash_Cans |

Patterns for "warm loss": a recovery path (Stardew Marlon), a small return for a sacrifice (DD2 Hope, Stardew trash can), a greyed-out view of the reward (DD). State the fact plainly (PopMatters counterpoint).

## 6. Destructive action confirmation

| Finding | Evidence | Source |
|---|---|---|
| Destructive actions need either a confirmation or an undo. Users click through confirmations by habit, so undo is often better. | ARTICLE (GNOME HIG, design system) | https://developer.gnome.org/hig/patterns/feedback/dialogs.html |
| For dangerous actions, put initial focus on Cancel. Escape and outside click must cancel. Return focus to the opener. | ARTICLE (Primer design system) | https://primer.style/product/components/confirmation-dialog/accessibility |
| For irreversible actions, add friction (type-to-confirm). Too heavy for a one-piece discard. | ARTICLE | https://vercel.com/geist/destructive-action-modal |
| Fire Emblem Three Houses: pressing B on the "send to convoy?" prompt turns it into a discard prompt. A later "are you sure" exists (user report). Players lose items by habit. | COMMUNITY | https://gamefaqs.gamespot.com/boards/204445-fire-emblem-three-houses/77904204 |
| Stardew Valley: no confirmation found on the trash can. On Switch, a small stick move toward the trash icon discarded valuable items. | COMMUNITY | https://forums.stardewvalley.net/threads/option-to-remove-auto-sort-button-in-inventory.33757/ ; https://stardewvalleywiki.com/Trash_Cans |
| Stardew Valley: the auto-sort button sits close to the close button. Players press it by accident. | COMMUNITY | https://forums.stardewvalley.net/threads/option-to-remove-auto-sort-button-in-inventory.33757/ |

Lesson: the back or cancel input must never lead toward a more destructive prompt. Keep the discard control away from sort and close.

## 7. Item tile visual language

| Finding | Evidence | Source |
|---|---|---|
| Do not carry information by colour alone. Add shape, pattern or text. | ARTICLE (vendor page citing Xbox guidance; Xbox claim not checked) | https://color-archive.vercel.app/guides/gaming-accessible-color-scheme/ |
| Colour-blind people tell shapes apart more easily than colours. | ARTICLE | https://cacm.acm.org/opinion/color-blind-accessibility-manifesto |
| A rarity gem icon with distinct shapes was praised by players of a card game. | COMMUNITY | https://pol1.lr.ggtyler.dev/r/ColorBlind/comments/1ht4b1c/how_do_these_look |
| Many tiers with one shape each get cluttered (Phasmophobia developer). | DEVELOPER (forum post) | https://lr.eu.psf.lt/r/PhasmophobiaGame/comments/16ccfvp/shop_v31_feedback_time_again/jzj94vy/?context=3 |
| Factorio players complain about items that differ only by colour. | COMMUNITY | https://forums.factorio.com/viewtopic.php?p=591160 |
| Into the Breach: the developers "sacrifice cool ideas for the sake of clarity every time". They limited how many status effects one action can apply. | DEVELOPER | https://gamedeveloper.com/design/-i-into-the-breach-i-dev-on-ui-design-sacrifice-cool-ideas-for-the-sake-of-clarity-every-time- |
| Stardew Valley: right-click takes one from a stack. Shift plus right-click takes half. | COMMUNITY (wiki) | https://stardewvalleywiki.com/Controls |
| Fire Emblem Three Houses: stack cap 99 per bundle. | COMMUNITY | https://fireemblemwiki.org/wiki/Supply_convoy |

## 8. Controller, touch and resolution

| Finding | Evidence | Source |
|---|---|---|
| Valve: minimum glyph height 9 px at 1280x800. Valve recommends 12 px. Valve recommends user-adjustable text size. | OFFICIAL | https://partner.steamgames.com/doc/steamdeck/compat |
| Material Design: 48 x 48 dp touch target. Apple: 44 x 44 pt. WCAG 2.2: 24 px minimum, 44 px enhanced. | ARTICLE (secondary summaries; not checked against the primary documents) | https://adrianroselli.com/2019/06/target-size-and-2-5-5.html |
| Grid navigation with a gamepad is harder than with a mouse. | ARTICLE | https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Test UI at arm's length on a 1280x800 reference. | ARTICLE (tutorial) | https://bugnet.io/blog/how-to-fix-steam-deck-ui-too-small-to-read |

Note: our minimum is 1280x720, not 1280x800. The Valve numbers are a guide, not a rule for us.

## 9. Pitfalls players report

| Pitfall | Game | Source |
|---|---|---|
| Silent loss when a window closes with full storage | Battle Brothers, Stardew Valley | see sections 2 |
| Hidden rule: gear lost unless bodies are carried out | XCOM 2 | see section 4 |
| Hidden rule: unequip trinkets before fleeing | Darkest Dungeon | see section 3 |
| Cancel input leads to discard | Fire Emblem Three Houses | see section 6 |
| Accidental discard by stick drift | Stardew Valley (Switch) | see section 6 |
| Inventory chores: scrap and gear pile up unused | Mutant Year Zero (one review) | https://game-wisdom.com/analysis/mutant-year-zero |
| Unclear weight rule (chest still carried) | Wartales | see section 2 |
| Too many screens per decision | X-COM, XCOM 2 | see section 1 |
| Results screen too large, key facts hard to find | Warframe | see section 4 |

---

## (a) Practices

| Practice | Source games | Evidence | How it applies to our screens |
|---|---|---|---|
| Hybrid layout: grid for unique gear and relics, stacked tiles for consumables, one sort button | BG3 (hybrid), Fire Emblem, Stardew | ARTICLE, COMMUNITY | Sanctum view: one grid, two tile types. Add a sort control away from close and discard. |
| Cap gauge shown always, with count and a state change before full | Darkest Dungeon, Battle Brothers (lack of it caused loss) | COMMUNITY | Gauge in the Sanctum header and in party prep. Change mark and motion at near-full. No colour-only state. |
| Overflow goes to a safe place, not to silent loss | Stardew (chest menu), agensi note | COMMUNITY, ARTICLE | "Party pack" overflow row. Say where each overflow item goes. |
| Shape-coded marks plus text in the detail view | Card games, Phasmophobia, ACM | ARTICLE, DEVELOPER | Equipped, spare, at risk: one shape each, plus a short label in the tooltip. |
| Show durability or a stack badge to separate identical items | Fire Emblem | COMMUNITY | Twin gear: add an "equipped on [portrait]" mark on one tile. Spare tile has a different frame. Needs our own test. |
| Back and cancel must never lead to destruction | Fire Emblem Three Houses | COMMUNITY | Discard needs select, then a separate confirm. Cancel is default focus. |
| Undo or recovery when possible, confirm when not | GNOME HIG, Stardew Marlon | ARTICLE, COMMUNITY | Discard is permanent by rule, so confirm with focus on Cancel. State the permanence in the dialog. |
| Summary first, detail on demand | Million Lords, Warframe complaint | DEVELOPER, COMMUNITY | Result card: three groups (kept, stayed in pack, lost) as icon rows. Names appear on focus or tap. |
| Greyed-out view of rewards not earned | Darkest Dungeon | COMMUNITY | Defeat card shows lost items as faded tiles with a soft mark, not red. |
| Small return for sacrifice | DD2 Hope, Stardew trash can | COMMUNITY | Option for design owner: discard gives a small Sanctum benefit. UNVERIFIED as a fit. Jeff decides. |
| Clarity over cleverness | Into the Breach | DEVELOPER | Limit marks per tile to 2 or 3. |
| Text floor and touch floor | Valve, Material | OFFICIAL, ARTICLE | Test 1280x720 at arm's length. Touch targets 48 units. Text at least 12 px, as Valve recommends. |

## (b) Pitfalls

| Pitfall | Where seen | How to avoid it for ours |
|---|---|---|
| Item lost with no warning at the moment of risk | Battle Brothers, XCOM 2, Darkest Dungeon | Leave confirmation lists items at risk before the leave. Prep screen shows a chip with the count. |
| Rule known only from a wiki | XCOM 2 gear rule, DD trinket rule | Put the rule in the screen as an icon and one short line. Show it at the point of choice. |
| Back button leads to discard | Fire Emblem Three Houses | Cancel and Back always close. Never map them to discard. |
| Accidental discard by touch or drift | Stardew Valley Switch | Select first, confirm second. Place discard away from sort. Target 48 units or larger. |
| Sort or close pressed by mistake | Stardew Valley | Separate controls by clear space. |
| Result screen too large or too cold | Warframe | Three icon rows. Short warm line. Detail on focus. Allow skip of motion. |
| Two identical items look the same | Not directly seen (gap) | Equipped mark and portrait chip on one tile. Test in grayscale. |
| Colour-only state | ESO, Factorio | Shape plus text for every state. |
| Too many screens per decision | X-COM, XCOM 2 | Link from party prep to the Sanctum view and back. Keep the pack row in prep. |
| Overflow chores | Mutant Year Zero | Stack consumables and materials. Offer sort. Keep cap small but clear. |

## (c) Could not verify

1. Any developer talk or post about inventory, armory or after-action UI for XCOM, XCOM 2, Gears Tactics, Wartales, Battle Brothers, Mutant Year Zero or Fire Emblem. None found.
2. Gears Tactics armory layout detail. Only one mirrored review line found.
3. XCOM debrief and memorial screen order, pacing and animation. Search returned only mission loot pages.
4. Slay the Spire relic and reward screen design rationale. No developer source found. Only the PC Gamer skip-button note.
5. Into the Breach inventory or reward UI. Only general clarity quotes found. GDC Vault talk is members-only and unread.
6. Mutant Year Zero stash limits. No source found.
7. Wartales and Battle Brothers exact capacity numbers and any warning wording.
8. Darkest Dungeon II end-of-run item rules. Search result was cut off.
9. Any warning chip on a party-prep screen in any listed game.
10. How any listed game marks two identical items as equipped vs spare.
11. Primary Apple, Google and W3C documents for touch target sizes. Only secondary summaries read.
12. Xbox Accessibility Guidelines claim on colour. Only a vendor page repeats it.
13. Tone and wording research for loss messages. Only general articles found. No wording standard exists in these sources.
14. Controller-specific lessons for XCOM, Gears Tactics or Fire Emblem armory screens.
15. Grid versus list preference data from controlled studies. Only opinion articles found. The "Tim Cain" grid page could not be attributed.
16. Several cited pages are mirrors or low-quality sites (pages.dev mirror, agensi.io, propertystream.co). Treat them as weak.
