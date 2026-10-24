# BattleTeam: Game Overview (working draft)

Status: draft, built through Q&A. Open questions are listed at the end.

## Spec index
- `specs/00-overview.md`: this file, index and record of decisions.
- `specs/10-map-and-terrain.md` with `data/terrain.yaml`: maps, terrain, movement, water, line of sight.
- `specs/20-units-and-progression.md` with `data/units.yaml`: unit stats, XP, skill-point trees, roles.
- `specs/30-special-units-and-victory.md`: the 8 special units, capture and victory.
- `specs/40-newcomers-and-social.md`: newcomer placement, money safety net, communication, players/commanders/sections.
- `specs/50-hq.md`: HQ role, manager, movement, destruction, storage.
- `specs/60-economy.md`: money ownership, earning, spending, transfers.
- `specs/70-combat-and-ap.md` with `data/combat.yaml`: AP, hit resolution, damage, friendly fire, morale, prisoners.
- `specs/90-research-topic-priority.md`: research (industry and academic) on what matters most for success.
- `specs/95-open-questions.md`: master list of open questions (to-do / done of the spec phase).
- Markdown files explain the rules (they teach the game). YAML files hold the numbers (code loads them).

## Decisions so far

### Core
1. Genre: 3D team battle game, several teams at war until one wins.
2. Scale: massive, 100+ players per battle.
3. Persistence: battles are persistent and last days. Players come and go while the battle keeps running on the server.
4. Real time. No turns.
5. Control: players command units from a top-down camera, or enter a unit and play through its eyes.
6. Action points (AP): each unit has a **single AP pool**. Move, attack, build, heal etc. all draw from it. AP regenerate over time up to a per-unit maximum.

### Units and progression (see unit spec)
7. Start: each player starts with 1 commander plus 3 units of another type.
8. XP: each unit earns XP from hits/kills, role actions, objectives, and time survived near the commander.
9. Evolution: a **skill-point tree** per unit type, nodes bought in any order subject to prerequisites.
10. Permanence: units and their XP/evolution persist across the battles of a war, and are lost at the end of the war. Permadeath: a killed unit is lost for good (commander excepted). (Revised: earlier versions said "permanent across battles" without the war limit.)
11. Common stats: HP, AP max and regen, attack, defense, move speed, vision range, movement class, morale.
12. Unit categories: commanders, engineers, scouts, artillery, transports, vehicles, soldiers (plus medics and radios).
12b. **Flying is a capability** of some units, not a unit category, a movement class or an armor type.
13. Engineers build or repair: bridges, ladders, walls, roads, traps.
14. Scouts share positions of spotted enemies.

### Commander and sections
15. A commander and his units form a **section**.
16. The commander always resurrects at the HQ after death.
17. The more XP the commander has, the more troops he can command (section size cap grows with commander XP).
18. A commander gives bonuses to nearby troops of his section: his aura raises their morale.
19. A commander can spend money to buy more troops.

### Controlling units
20. Both modes coexist: the player gives direct orders from the top-down camera, or enters a unit. Units that are not directly controlled follow simple section AI behaviours (follow commander, hold, patrol...).

### Vision
21. Fog of war, **shared per section only**: a section sees what its own units see. Radios extend this sharing (see Radio).
22. Mountains, buildings and trees block line of sight (3D).

### Economy
23. Money is earned from: successful hits, engineer constructions, enemy deaths, enemy HQ hits and HQ destruction.
24. Medics earn money for their section when they heal other units.
25. Money belongs to the section (no team or guild treasury). It is kept between battles of a war.
25b. Money can be transferred between players of the same team with fees (destroyed); fees are lower between sections of the same guild. The transfer + safety-net loop is accepted.
25d. Constructions cost no money, only AP and time.
25c. Newly bought troops appear in storage (homeland), then deploy through the section's portal.

### Safety of units (anti-griefing)
26. A unit is either **on the field** (present on the map, can be attacked and killed) or **stored** (in the HQ or in the guild encampment).
27. Stored units cannot be attacked and are not visible.
28. The **guild encampment** is a special unit that the guild commander can buy and move from the HQ.
29. Units of an offline player that were left on the field stay passive and can be attacked; players are expected to store them before leaving.

### Teams, guilds and HQ
30. Each team has a starting point.
31. A **guild** is a subgroup inside a team. A team contains several guilds. Each guild has a guild commander and can have an encampment.
32. The player of the highest-ranking commander also manages the team HQ and may delegate that role to another player. Powers: see HQ section below.

### Joining and leaving
33. Players can join a running battle at any time, spawning a commander + 3 units at their team's starting point (catch-up mechanics: to be defined).

### Radio (purchasable unit)
34. A **radio** is a special unit that **a commander can buy from the start**.
35. A radio gathers information from the team scouts located in its area. Its **range** is a characteristic that can evolve.
36. The information gathered by a radio is shared with **all the sections** (of the radio's team).
37. A radio is movable but very slow and too big to be carried by a transport. It is a different object from the 8 map special units.

### Combat and AP (see combat spec)
37b. AP regenerate at a constant rate, whatever the unit does.
37c. Hits are hybrid: aim-based when a player is inside a unit, hit chance when units act under orders or AI.
37d. Damage uses a weapon-type vs armor-type table. Friendly fire is on, full damage.
37e. Cover blocks shots and gives damage reduction when partial. Units in a destroyed transport are ejected with heavy damage.
37f. At 0 HP a unit normally dies. Only when a commander deals the final blow himself, low morale and low AP raise the odds that it is taken prisoner, or switches side into the attacker's section if it has room (keeping its XP and evolution). Prisoners can be exchanged or ransomed.
37h. Each weapon has a firing speed, a cartridge (magazine) capacity, a loading speed, an unloading speed, and says whether the unit can move with it loaded.
37g. Morale is changed by the commander aura, nearby kills and ally deaths, and being outnumbered.

### Map and world (see map spec)
38. Maps are **hand-authored**. Team count and map size are **settings of a battle**.
39. Terrain changes persist during a battle: engineer constructions, destructible trees and buildings, craters from weapons.
40. Movement classes: foot, wheeled, tracked (flying units use a flying movement profile). AP cost depends on class, terrain type and a slope factor.
41. Rivers and lakes are impassable for most units; boats, amphibious units, flyers and bridges cross them.
42. Floating islands are reached by flying, or by engineer-built bridges/ladders from nearby terrain.

### Map special units (the 8 objectives) and victory
43. At battle start, 8 special units (name still to be decided) are placed on solid ground.
44. They are movable objects, but move very slowly and are too big to be carried by a transport.
45. Victory: only one HQ remains, OR one team controls 5 special units for 24 hours.
46. Special units are taken by a capture action and stay owned until recaptured. They give nothing besides the victory timer.
46b. The 8 special units are ancient relics. Any unit next to a relic can capture it; a capture is blocked while enemies are near; the previous owner is alerted.
46c. The 24-hour victory timer resets fully as soon as the team holds fewer than 5 relics.
46d. A relic moves only when pushed by units of its controlling team. It cannot fly or cross water, forests, towns or walls. It can fall from a floating island when pushed over the edge. Pushed hard enough, it crushes units in its path.
46e. Pushing needs a minimum number of pushers, costs AP, and moves the relic at a fixed slow speed. Crushed units of any team take heavy damage. A relic falling from an island lands intact below, keeps its owner and crushes what is under. Relics cross water only on reinforced bridges built by engineers.
46f. A relic crushes only when pushed with more than the minimum number of pushers. Slopes change the push effort. Relics are indestructible. A walled-in relic stays stuck until the walls are destroyed.

### HQ (see HQ spec)
46g. HQ manager powers: team-wide orders and map markers, and moving the HQ. The manager is the player with the most medal points (delegation possible).
46h. The HQ is pushed by units like a relic, with the same obstacles. The manager is fixed at battle start (delegation only).
46h1. A pushed HQ does not crush units, it pushes them sideways. No fallback if the manager is offline: he must delegate.
46h3. A section in a guild stores its units in its guild encampment; a section without guild stores them in the HQ. A unit next to its storage place is stored immediately; elsewhere it can be recalled after a long delay that nothing stops. Stored units deploy instantly next to their storage place, except while an enemy is next to it. Storage capacity is limited per section and grows with commander XP.
46h4. A guild without encampment uses the HQ. A blocked encampment does not allow deploying from the HQ instead. An encampment is destroyed like any other unit and can be bought again at any time.
46h5. Lore: storage is the homeland. HQs and encampments hold teleportation portals usable only by authorized units. Destroying an HQ or encampment never affects stored units.
46h2. Engineers can build ordinary walls near the HQ. Eliminated players can join another running battle with another commander.
46i. The HQ has hit points and is destroyed at 0. No repair, no weapons, no HQ-specific defenses: units defend it.
46j. A team whose HQ is destroyed is eliminated. Its stored units are untouched and its units on the field are automatically stored, all available for the next battle of the war.

### Newcomers, social and accounts (see newcomer spec)
47. Each team has a power value combining active players and unit power (unit power = unit XP). A new player lands in the team with the lowest power.
48. The new player chooses among 4 guilds picked at random from the guilds that opted in to accept new players; if fewer than 4 opted in, the list is filled with other guilds of the team picked at random.
49. When a commander dies or loses all his units, his money becomes max(money before the event, war.minStartingMoney). minStartingMoney belongs to the war entity and is defined by the lore.
49b. A war is a series of battles; its settings and lore apply to all of them.
49c. Abusing the money floor (losing units on purpose) is accepted.
49d. An admin starts a war; it ends when the admin has no more battles planned. A section is created when the player enters a war and is lost at the end of it.
49e. Winning a battle gives victoryXp to every unit of every section of the winning team.
49f. Teams are created automatically at the start of each battle (rule to be defined); guild members always stay together in the same team.
49g. War and battle statistics are available during and after the war.
49h. After a war, a player keeps his statistics, war medals and permanent game medals.
49i. Cosmetics for sections and units are bought with real money during a war and kept after it, to be applied to other units.
50b. No in-game spying on communications. Most communication may happen on a Discord server.
50. Team, guild and direct player communication are fundamental features.
51. A section is owned by one commander only. A player can have several sections (commanders), but only one commander per battle; several battles run at the same time.

## Open questions
- Rule for automatic team creation at each battle (balance by power? keep previous teams?).
- War result: is there a war winner, and how is it decided?
- Medals: list and criteria for war medals and game medals.
- Cosmetics: confirm purely visual (no gameplay advantage).
- Team power formula: weights of active players vs total XP.
- Discord: integration level (account linking, automatic team/guild channels, bot) vs minimal in-game chat.
- Map special units (the 8): name, what they are, what "control" means for the 24h timer (capture action? presence? who moves them and how?), can they be destroyed, movement on varied terrain (rivers, mountains, floating islands).
- Radio: cost, whether radios can be destroyed, start range and evolution, how scouts' info is relayed.
- Guild: how a guild commander is chosen, relation guild commander vs highest-ranking commander (team commander), guild size, what a player outside a guild is.
- Storage: recall delay value; capacity formula; "next to" radius; encampment price and hit points.
- HQ: hit points; who can push it.
- Money: prices, earning amounts, fee rates, transfer + safety-net loop (see economy spec).
- Catch-up for late joiners within a war; fairness vs veterans with evolved units.
- AP costs per action (shot, reload, unload); weapon values; confirm the airborne_factor rule for hitting flying units.
- Morale formula and 0-HP odds; prisoner holding, exchange and ransom flow; defection snowball risk.
- Concrete unit list with stats; XP formulas; evolution trees per unit type.
- Tech/stack targets (engine, server architecture) for the build.
