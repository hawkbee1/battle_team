# BattleTeam: Game Overview (working draft)

Status: draft, built through Q&A. Open questions live in `specs/95-open-questions.md`.

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
- `data/battle.yaml`: default values of battle settings.
- `data/economy.yaml`: currency, prices, earnings, transfer fees.
- `data/medals.yaml`: medal tiers and thresholds.
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
11. Common stats: HP, AP max and regen, attack, defense, move speed, vision range, movement class, armor type, morale. (Revised by decisions 57-58: armor type added; attack and defense act on hit chance, not damage.)
12. Unit categories: commanders, engineers, scouts, artillery, transports, vehicles, soldiers, plus radios. (Revised by decision 60: a medic is a soldier with a heal role.)
12b. **Flying is a capability** of some units, not a unit category, a movement class or an armor type.
13. Engineers build or repair: bridges, ladders, walls, roads, traps.
14. Scouts share positions of spotted enemies.

### Commander and sections
15. A commander and his units form a **section**.
16. The commander always resurrects at the HQ after death.
17. The higher the commander level, the more troops he can command and store. (Revised by decision 79: the level comes from section XP, not from the commander's own XP.)
18. A commander gives bonuses to nearby troops of his section: his aura raises their morale.
19. A commander can spend money to buy more troops.

### Controlling units
20. Both modes coexist: the player gives direct orders from the top-down camera, or enters a unit. Units that are not directly controlled follow simple section AI behaviours (follow commander, hold, patrol...).

### Vision
21. Fog of war, **shared per section only**: a section sees what its own units see. Radios extend this sharing (see Radio).
22. Mountains and buildings block line of sight (3D). (Revised by decision 87: forests conceal in proportion to the forest length crossed; destroyed objects stop blocking.)

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
37e. Cover blocks shots; partial cover lowers the chance of being hit (revised by decision 65: no damage reduction). Units in a destroyed transport are ejected with heavy damage.
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
46h3. A section in a guild stores its units in its guild encampment; a section without guild stores them in the HQ. A unit next to its storage place is stored immediately; elsewhere it can be recalled after a long delay that nothing stops. Stored units deploy instantly next to their storage place, except while an enemy is next to it. Storage capacity is limited per section and grows with the commander level (decision 79).
46h4. A guild without encampment uses the HQ. A blocked encampment does not allow deploying from the HQ instead. An encampment is destroyed like any other unit and can be bought again at any time.
46h5. Lore: storage is the homeland. HQs and encampments hold teleportation portals usable only by authorized units. Destroying an HQ or encampment never affects stored units.
46h2. Engineers can build ordinary walls near the HQ. Eliminated players can join another running battle with another commander.
46i. The HQ has hit points and is destroyed at 0. No repair, no weapons, no HQ-specific defenses: units defend it.
46j. A team whose HQ is destroyed is eliminated. Its stored units are untouched and its units on the field are automatically stored, all available for the next battle of the war.

### Newcomers, social and accounts (see newcomer spec)
47. Each team has a power value. A new player lands in the team with the lowest power. (Revised by decision 93: power = unit XP + section XP; there is no notion of active players.)
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
50. Team, guild and direct player communication are fundamental features. (Revised by decision 123: in game only pings and map markers; chat and voice happen on Discord.)
51. A section is owned by one commander only. A player can have several sections (commanders), but only one commander per battle; several battles run at the same time.

### Weapons, AP and vision (rules core, see combat and map specs)
52. Weapons are items. A unit has one weapon slot and a per-type list of allowed weapon types. A newly bought unit comes with its type's default weapon (included in its price); other weapons are bought with section money.
53. Weapons are equipped or swapped only while the unit is stored or next to its storage place. A killed unit drops its weapon; any unit of any team whose allowed list includes it can pick it up on the spot for an AP cost, dropping its own weapon in its place. Dropped weapons vanish after a delay.
54. Ammo is unlimited; only the loaded magazine is limited. A reload always gives a full magazine and discards the rounds left in it.
55. Reloading, unloading and swapping weapons cost time only, no AP. Shots, movement, weapon pick-up and role actions cost AP.
56. A unit with 0 AP is never frozen: it keeps moving as fast as its AP regenerate; a shot or role action waits until it has enough AP.
57. Damage = weapon base damage × weapon-vs-armor multiplier (× airborne_factor against a flying target). Every unit has an armor type. The airborne_factor rule is confirmed (0 = cannot hit flying units).
58. `attack` is accuracy (hit chance under orders/AI, tighter spread in first-person aim). `defense` is evasion (lowers the chance of being hit). Neither changes damage.
59. A unit fires only at targets it sees itself, up to weapon range. Effective vision = vision range × weather factor × terrain factor of the observer's position + height bonus, then hard line-of-sight blockers apply. Weather is a battle state that changes over time.
60. A medic is a soldier with a heal role (category soldier).
61. Roster v1 adds jeep (vehicle, wheeled), tank (vehicle, tracked), truck (transport, wheeled), helicopter (flying capability) and boat (boat capability, water only) to commander, soldier, medic, engineer, scout, artillery and radio. Stats are placeholders.

62. Indirect fire: weapons flagged `indirect_fire` (artillery) may target a ground position that a unit of their section sees, or that a scout reports through a radio in range, with a lower hit chance. All other weapons need their unit's own sight.
63. Picking up a dropped weapon costs AP (the only weapon handling that does; see 55).
64. Prisoners and defectors keep their weapon. Units with no weapon (radio, truck) cannot attack.
65. Hit chance under orders/AI = weapon base accuracy × (1 + (attack − defense)/100) × distance × cover × size × speed factors (× indirect factor), clamped to 5–95 %. Partial cover lowers hit chance only, never damage.
66. Build, repair, heal and capture cost a fixed AP amount paid up front, then take a duration (revised by decision 91: heal is instant; building costs per structure: decision 113); a unit needs the AP to start. Pushing a relic or the HQ costs each pusher AP per metre, like movement, with the slope factor.
67. An interrupted action loses the AP paid but keeps its progress; resuming costs the AP of the remaining part. Exception: a capture interrupted by an arriving enemy loses its progress (decision 97).
68. Flying units can land and take off (time, no AP). Landed, they move with their ground class, are hit as ground targets and can load/unload troops. Each map sets a maximum flying altitude.
69. Weapon values in `data/combat.yaml` are the accepted starting point for the first milestone; they are tuned with headless simulations and playtests.

### Morale, prisoners, defectors, radio (see combat spec)
70. Morale goes from 0 to 100, starts at a base value (50) and changes only through events (commander aura, nearby kills and ally deaths, being outnumbered). No drift.
71. Morale slightly scales the attacker's hit chance (factor 0.9 at morale 0 to 1.1 at 100).
72. 0-HP odds when a commander deals the final blow: p(spared) = 0.6 × ((100 − morale)/100 + (1 − AP/ap_max)) / 2. A spared unit defects or becomes a prisoner, 50/50; defection needs room in the attacking section, else prisoner.
73. A prisoner goes instantly to the captor section's prisoner storage (separate and unlimited, decision 94) and cannot fight or escape. Exchanges and ransoms are negotiated in game between section owners; a ransom goes entirely to the captor section. Prisoners never released are lost at war end.
74. A defector is an ordinary unit of its new section (it can be killed, captured or defect again). Statistics count a defection for the captor and a loss for the previous owner.
75. No extra limit on defections beyond the commander-only rule; watch the snowball effect in playtests.
76. A radio is a normal unit: bought with money, destructible, can be taken prisoner or defect, stored like any unit; unarmed. Its relay range starts at its base value and grows through its skill tree.

### Progression, commander death, between battles (see unit spec)
77. Hit and kill XP is multiplied by 1 + target XP / attacker XP (capped at ×3). Repeated XP from the same target or build spot within a time window shrinks. Hitting allies gives no XP.
78. Each unit spends its own XP on its own skill tree, the commander included. Nodes are permanent (no respec) and never exclude each other.
79. A share of every XP point earned by a unit moves to its section's XP. Section XP sets the commander level, which sets section size cap and storage capacity. Section XP cannot be spent on stats.
80. A dead commander respawns at the HQ at once. He loses a share of his unspent XP, never his level. All units of his section on the field go instantly to storage and lose AP and morale. These losses are battle settings.
81. Units in a transport take a share of every hit on it (with their own armor type) and explosion damage when ejected at its destruction. Stored units can never be harmed.
82. No catch-up mechanism for late joiners in a war; placement in the weakest team is the only compensation.
83. Within a war, sections keep everything from battle to battle; each battle starts with full AP and HP and morale at base. At war end everything is lost; logs, statistics and medals stay available for consultation.

### Map and world (round 3, see map spec)
84. Maps are up to 10,000 × 50,000 m; a battle has 2 to 5 teams.
85. Engineers cannot fill craters. Destroyed trees and structures never regrow. A crater is at most 20 m deep.
86. Water: `sail` is a capability (it replaces `boat`). A boat is a unit with `sail`; an amphibious unit has `sail` and a ground movement class. There are no ports or docks: units board or leave a boat when it is next to the shore. On water, engineers build bridges only.
87. Destroyed objects stop blocking sight. Forests conceal in proportion to the length of forest the sight line crosses, so a flying observer sees into a forest more easily than a ground observer.
88. Floating islands: no height limit for ladders; ground units can be stranded; radios are units like any other there; encampments cannot reach islands.
89. Hit points: tree 100, building 500, wall 200, bridge 200, reinforced bridge 400.
90. Weather changes randomly, per map. There is no day/night: it is always day.

### Units, combat (round 3)
91. Heal is instant: it costs AP and restores the medic's `heal` value in HP. Scouts have an "observe" special action giving temporarily +30 vision. Transports carry by weight: each unit has a weight; a transport has a total weight capacity and a maximum weight per carried unit.
92. victoryXp is 1 XP per unit of the winning team; it counts toward section XP like any XP.
93. Team power = unit XP + section XP. The rules have no notion of active or inactive players.
94. Prisoners are held in a separate, unlimited prisoner storage of the captor section; they never use its storage capacity.
95. Morale also scales weapon spread in first-person aim, with the same factor as the hit chance.

### Relics and victory (round 3, see relic spec)
96. Relics are huge statues of the gods of war from different mythologies.
97. Capture takes 30 min and 50 AP. One radius (default 30 m) is used to capture and to block: every unit inside it counts, whatever its state (carried, flying, offline). A capture interrupted by an enemy entering the radius loses its progress. Duration, AP and radius are battle settings.
98. Pushing needs at least 10 pushers. Slope changes the effort exactly as for movement.
99. Reinforced bridge: 20 AP, 10 min to build, 400 HP. A relic or HQ on a reinforced bridge that is destroyed is lost.
100. The victory countdown is visible. No special playtest is planned for time-zone fairness.

### Teams, guilds, social (round 3, see newcomer spec)
101. A "new player" is anyone joining. A guild can leave the newcomer list at any time, with no reward or penalty.
102. minStartingMoney is 500 w€ and is also the starting money of a new section. The currency is the w€.
103. Teams are balanced by team power at each battle; the number of teams is a battle setting.
104. There is no war winner.
105. Medals are bronze, silver and gold for every kind of action and kill (by target type: units, commanders, jeeps...), earned at thresholds (example: bronze for killing 5 commanders).
106. Cosmetics are purely visual.
107. A player's sections share nothing, except cosmetics bought with a sharing option.
108. Guilds: the creator is the chief (guild commander); he can hand the role to another member and can disband the guild, and cannot leave while chief. Maximum guild size depends on the guild level, which rises with the total XP earned by its sections while in the guild. A guild can have a single section. A section can play without a guild (storage at the HQ).

### HQ, storage, economy (round 3)
109. Any unit of the team can push the HQ. HQ hit points: 1000 (battle setting).
110. Deploying a stored unit costs it 10 AP; it is then fully operational. Stored units regenerate AP up to their maximum. A unit within 10 m of its storage place is stored at once; from anywhere else a recall takes 6 hours. An enemy within 20 m of a storage place blocks deployment.
111. Guild encampment: 500 w€, 300 HP.
112. Default price of anything not priced: 100 w€. Money earned: hit 1, kill 5, construction 5, heal 5, HQ hit 10, HQ destruction 100. Transfer fees: 2 % inside a guild, 7 % outside. XP cannot be bought. No limit against build-and-destroy farming.

### Round 4
113. Constructions cost AP paid up front plus a build time per structure, and no money (confirms 25d).
114. The HQ and the encampment have no numeric armor: their armor types are `hq` and `structure`.
115. Crushing: with 10 + n pushers a relic crushes up to n units in its path; with more blocking units it stops.
116. A relic lost with a destroyed reinforced bridge leaves the battle; a team still needs 5 relics for the timer, so with fewer than 5 left only the HQ victory remains. A lost HQ eliminates its team, as if destroyed.
117. A relic pushed over the edge of a floating island falls (decision 46d confirmed).
118. Skill trees give stat bonuses only, no abilities. Every evolved stat is capped at 300 % of its base value.
119. Scout observe: +30 m vision for 30 minutes, 10 AP; the scout cannot move while observing.
120. A player never leaves a battle and stays in his team for its whole duration. He can store his whole section and deploy again when he wants, but not before 24 hours after his last alive unit was stored.
121. Medal points: bronze 1, silver 3, gold 10. The HQ manager is the player with the most points; ties go to the commander with the most XP.
122. A player can join a running war at any time and enters the current battle.
123. In-game communication is limited to pings and map markers (history kept). Chat and voice happen on Discord.
124. A player has one commander per war and can take part in several wars at the same time.

## Open questions
All open questions are tracked in `specs/95-open-questions.md`.
